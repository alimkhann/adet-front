import SwiftUI
import Combine
import UIKit

@MainActor
public class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var selectedHabit: Habit?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var todayMotivation: MotivationEntryResponse? = nil
    @Published var todayAbility: AbilityEntryResponse? = nil
    @Published var userPlan: String = "free" // Add this line
    @Published var autoCreatedPostId: Int? = nil

    // --- Add for proof feedback/reasoning ---
    @Published var lastValidationResult: TaskValidationResult? = nil

    // MARK: - Task State Machine
    @Published var currentTaskState: HabitTaskState = .empty

    // MARK: - Task/Proof State
    @Published var todayTask: TaskEntry? = nil
    @Published var isGeneratingTask: Bool = false
    @Published var isSubmittingProof: Bool = false
    @Published var proofState: HabitProofState = .notStarted

    /// True if a task is in progress (generating, proof submitting, or task is pending)
    var isTaskInProgress: Bool {
        isGeneratingTask || isSubmittingProof || (TaskStatus(rawValue: todayTask?.status ?? "") == .pending)
    }

    @Published var streakFreezers: Int = 0 // Always backend-driven
    @Published var closeFriendsCount: Int = 0
    private var closeFriendsCancellable: AnyCancellable?

    @Published var typingTextProofKey: String = ""
    private var pollingTask: Task<Void, Never>? = nil
    @Published var taskGenerationError: String?
    private var pollAttempts = 0
    private let maxPollAttempts = 10 // 10 attempts = ~50 seconds

    // --- SuccessShare Persistence ---
    @Published var isInSuccessShare: Bool = false
    private var lastSuccessShareTask: HabitTaskDetails? = nil
    var lastSuccessShareProof: HabitProofState? = nil
    private var lastSuccessShareDate: Date? = nil

    // --- SuccessDone Persistence ---
    @Published var isInSuccessDone: Bool = false
    private var lastSuccessDoneDate: Date? = nil

    // --- Failed/Missed Persistence ---
    @Published var isInFailed: Bool = false
    private var lastFailedAttemptsLeft: Int? = nil
    private var lastFailedDate: Date? = nil
    @Published var isInMissed: Bool = false
    private var lastMissedNextTaskDate: Date? = nil
    private var lastMissedDate: Date? = nil

    @Published var timeUntilValidation: TimeInterval = 0
    @Published var timeUntilExpiration: TimeInterval = 0

    private var timerCancellable: AnyCancellable?
    private var significantChangeCancellable: AnyCancellable?

    private let apiService = APIService.shared

    // Remove expiryTimer and foregroundObserver
    // Remove startExpiryTimer and deinit observer logic

    // Remove checkForTaskExpiry and all timer logic

    /// Called by the UI when the timer hits 0
    func handleTaskExpired() async {
        guard let habit = selectedHabit, let task = todayTask, task.status.lowercased() == "pending" else { return }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard
            let dueDateString = task.dueDate,
            let due = iso.date(from: dueDateString),
            Date() > due
        else {
            return
        }

        do {
            // Mark as missed in backend
            _ = try await apiService.checkAndMarkExpiredTasks()
            // Refetch today's task and update state
            await fetchTodayTask(for: habit)
            await MainActor.run {
                self.updateTaskState()
            }
        } catch {
            print("Failed to mark task as missed: \(error.localizedDescription)")
        }
    }

    func fetchHabits() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            habits = try await apiService.fetchHabits()

            // Select the first habit by default
            if selectedHabit == nil && !habits.isEmpty {
                selectedHabit = habits.first
            }
        } catch {
            errorMessage = "Failed to fetch habits: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    func selectHabit(_ habit: Habit) {
        selectedHabit = habit
        resetMotivationAndAbility()
        updateTypingTextProofKey()
    }

    func deleteHabit(_ habit: Habit) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await apiService.deleteHabit(id: habit.id)
            print("Successfully deleted habit: \(habit.name)")

            // Reset motivation and ability after deletion
            resetMotivationAndAbility()

            // Refresh the habits list from the server to ensure consistency
            await fetchHabits()

        } catch NetworkError.unauthorized {
            errorMessage = "Authentication failed. Please try again."
            print("Authentication failed for habit deletion")

            // Try to refresh authentication and retry once
            do {
                // Wait a moment for network to recover
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                try await apiService.deleteHabit(id: habit.id)
                print("Successfully deleted habit on retry: \(habit.name)")

                // Refresh the habits list from the server after successful retry
                await fetchHabits()

                // Clear error message on success
                errorMessage = nil
                // Reset motivation and ability after deletion
                resetMotivationAndAbility()
            } catch {
                errorMessage = "Failed to delete habit after retry: \(error.localizedDescription)"
                print("Failed to delete habit on retry: \(error.localizedDescription)")
            }
        } catch {
            errorMessage = "Failed to delete habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    /// Manually creates a habit from onboarding data
    func createHabitFromOnboarding() async {
        do {
            let onboardingAnswers = try await apiService.getOnboardingAnswers()
            let newHabit = try await apiService.createHabit(from: onboardingAnswers)
            print("Created habit from onboarding: \(newHabit.name)")

            // Reset motivation and ability after creating a new habit
            resetMotivationAndAbility()

            // Refresh habits list
            habits = try await apiService.fetchHabits()
        } catch {
            errorMessage = "Failed to create habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    func createHabit(_ habit: Habit) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let newHabit = try await apiService.createHabit(habit)
            // Reset motivation and ability after creating a new habit
            resetMotivationAndAbility()
            await fetchHabits() // Refresh the list

            // Select the newly created habit
            selectedHabit = habits.first { $0.id == newHabit.id }
        } catch {
            errorMessage = "Failed to create habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    func updateHabit(_ habit: Habit) async -> Habit? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let updatedHabit = try await apiService.updateHabit(id: habit.id, data: habit)
            print("Successfully updated habit: \(updatedHabit.name)")

            // Update the habit in the local array
            if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                habits[index] = updatedHabit
            }

            // Update selected habit if it's the one being updated
            if selectedHabit?.id == habit.id {
                selectedHabit = updatedHabit
            }

            return updatedHabit
        } catch {
            errorMessage = "Failed to update habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
            return nil
        }
    }

    // MARK: - Motivation & Ability Tracking
    func getTodayMotivationEntry(for habitId: Int) async -> MotivationEntryResponse? {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            let userDate = formatter.string(from: Date())
            let entry = try await apiService.getTodayMotivationEntry(habitId: habitId, userDate: userDate)
            todayMotivation = entry
            return entry
        } catch {
            todayMotivation = nil
            return nil
        }
    }

    func submitMotivationEntry(for habitId: Int, level: String) async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let today = formatter.string(from: Date())
        do {
            _ = try await apiService.submitMotivationEntry(habitId: habitId, date: today, level: level)
            return true
        } catch let error as NSError {
            if error.localizedDescription.contains("already exists") {
                // Already exists, treat as failure so updateMotivationEntry will be called
                return false
            }
            ToastManager.shared.showError(error.localizedDescription)
            return false
        }
    }

    func updateMotivationEntry(for habitId: Int, level: String) async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let today = formatter.string(from: Date())
        do {
            _ = try await apiService.updateMotivationEntry(habitId: habitId, date: today, level: level)
            return true
        } catch {
            ToastManager.shared.showError(error.localizedDescription)
            return false
        }
    }

    func getTodayAbilityEntry(for habitId: Int) async -> AbilityEntryResponse? {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            let userDate = formatter.string(from: Date())
            let entry = try await apiService.getTodayAbilityEntry(habitId: habitId, userDate: userDate)
            todayAbility = entry
            return entry
        } catch {
            todayAbility = nil
            return nil
        }
    }

    func submitAbilityEntry(for habitId: Int, level: String) async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let today = formatter.string(from: Date())
        do {
            _ = try await apiService.submitAbilityEntry(habitId: habitId, date: today, level: level)
            return true
        } catch {
            return false
        }
    }

    func updateAbilityEntry(for habitId: Int, level: String) async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let today = formatter.string(from: Date())
        do {
            _ = try await apiService.updateAbilityEntry(habitId: habitId, date: today, level: level)
            return true
        } catch {
            ToastManager.shared.showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - Interval Day Logic
    func isTodayIntervalDay(for habit: Habit) -> Bool {
        let frequency = habit.frequency.lowercased()

        // Handle special frequency formats
        if frequency == "every day" || frequency == "daily" {
            return true
        }

        if frequency == "weekdays" {
            let todayIndex = Calendar.current.component(.weekday, from: Date())
            return todayIndex >= 2 && todayIndex <= 6 // Monday(2) to Friday(6)
        }

        if frequency == "weekends" {
            let todayIndex = Calendar.current.component(.weekday, from: Date())
            return todayIndex == 1 || todayIndex == 7 // Sunday(1) or Saturday(7)
        }

        // Handle comma-separated weekday abbreviations like "Mon, Wed, Fri"
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1 // Sunday = 0
        let formatter = DateFormatter()
        let todayAbbr = formatter.shortWeekdaySymbols[todayIndex] // e.g. "Mon"

        return habit.frequency.contains(todayAbbr)
    }

    // MARK: - Fetch Today's Task
    func fetchTodayTask(for habit: Habit) async {
        print("[HabitViewModel] fetchTodayTask called for habit id \(habit.id)")
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            let userDate = formatter.string(from: Date())
            let task = try await apiService.getTodayTask(habitId: habit.id, userDate: String(userDate))
            await MainActor.run {
                print("[HabitViewModel] fetchTodayTask: Got task with status \(task.status)")
                self.todayTask = task
                self.lastValidationResult = task.validationResult // <-- always update from backend
                self.updateTypingTextProofKey()
            }
            // Always fetch motivation and ability entries for today from backend
            _ = await getTodayMotivationEntry(for: habit.id)
            _ = await getTodayAbilityEntry(for: habit.id)
            // Fallback: check for expiry after fetching today's task
            await handleTaskExpired()
        } catch {
            await MainActor.run {
                print("[HabitViewModel] fetchTodayTask: Failed to fetch task: \(error.localizedDescription)")
                self.todayTask = nil
                self.lastValidationResult = nil // clear if no task
                self.updateTypingTextProofKey()
            }
            // Always clear motivation/ability if no task
            _ = await getTodayMotivationEntry(for: habit.id)
            _ = await getTodayAbilityEntry(for: habit.id)
        }
    }

    // MARK: - Task State Machine
    func updateTaskState() {
        print("[HabitViewModel] updateTaskState called. Current todayTask status: \(todayTask?.status ?? "nil")")
        // make sure our countdowns are fresh before deciding state
        recomputeCountdowns()

        guard let habit = selectedHabit else {
            currentTaskState = .empty
            return
        }

        // Persist .successDone if set and day hasn't changed
        if isInSuccessDone, let date = lastSuccessDoneDate {
            let today = Calendar.current.startOfDay(for: Date())
            let last = Calendar.current.startOfDay(for: date)
            if today == last {
                currentTaskState = .successDone
                return
            } else {
                isInSuccessDone = false
                lastSuccessDoneDate = nil
            }
        }
        // Persist .successShare if set and day hasn't changed
        if isInSuccessShare, let task = lastSuccessShareTask, let proof = lastSuccessShareProof, let date = lastSuccessShareDate {
            let today = Calendar.current.startOfDay(for: Date())
            let last = Calendar.current.startOfDay(for: date)
            if today == last {
                currentTaskState = .successShare(task: task, proof: proof)
                return
            } else {
                isInSuccessShare = false
                lastSuccessShareTask = nil
                lastSuccessShareProof = nil
                lastSuccessShareDate = nil
            }
        }
        // Persist .failed if set and day hasn't changed
        if isInFailed, let attempts = lastFailedAttemptsLeft, let date = lastFailedDate {
            let today = Calendar.current.startOfDay(for: Date())
            let last = Calendar.current.startOfDay(for: date)
            if today == last {
                currentTaskState = .failed(attemptsLeft: attempts)
                return
            } else {
                isInFailed = false
                lastFailedAttemptsLeft = nil
                lastFailedDate = nil
            }
        }
        // Persist .missed if set and day hasn't changed
        if isInMissed, let nextDate = lastMissedNextTaskDate, let date = lastMissedDate {
            let today = Calendar.current.startOfDay(for: Date())
            let last = Calendar.current.startOfDay(for: date)
            if today == last {
                currentTaskState = .missed(nextTaskDate: nextDate)
                return
            } else {
                isInMissed = false
                lastMissedNextTaskDate = nil
                lastMissedDate = nil
            }
        }

        if !isTodayIntervalDay(for: habit) {
            let nextDate = nextScheduledDate(for: habit)
            currentTaskState = .notToday(nextTaskDate: nextDate)
            return
        }

        // Check for task in progress
        if isGeneratingTask {
            currentTaskState = .generatingTask
            return
        }
        if isSubmittingProof {
            print("[HabitViewModel] updateTaskState: isSubmittingProof, transitioning to .showTask")
            currentTaskState = .showTask(task: makeTaskDetails(), proof: proofState)
            return
        }

        // Check today's task status
        if let task = todayTask, let status = TaskStatus(rawValue: task.status) {
            let today = Calendar.current.startOfDay(for: Date())
            let assignedDate = ISO8601DateFormatter().date(from: task.assignedDateString) ?? today // assignedDateString is a helper for assigned_date as string
            let isToday = assignedDate == today
            if isToday {
                switch status {
                case .missed:
                    Task {
                        let nextDate = nextScheduledDate(for: habit)
                        await fetchStreakFreezers()
                        await MainActor.run {
                            self.currentTaskState = .missed(nextTaskDate: nextDate)
                        }
                    }
                    return
                case .failed:
                    let attemptsLeft = todayTask?.attemptsLeft ?? 1
                    if attemptsLeft > 0 {
                        currentTaskState = .failed(attemptsLeft: attemptsLeft)
                    } else {
                        Task {
                            let nextDate = nextScheduledDate(for: habit)
                            await fetchStreakFreezers()
                            await MainActor.run {
                                self.currentTaskState = .failedNoAttempts(nextTaskDate: nextDate)
                            }
                        }
                    }
                    return
                case .completed:
                    // Only create if not already created
                    if self.autoCreatedPostId == nil {
                        Task {
                            await self.createPrivatePostForSuccessShare(task: makeTaskDetails(), proof: proofState)
                        }
                    }
                    currentTaskState = .successShare(task: makeTaskDetails(), proof: proofState)
                    return
                case .pending:
                    print("[HabitViewModel] updateTaskState: transitioning to .showTask")
                    currentTaskState = .showTask(task: makeTaskDetails(), proof: proofState)
                    return
                default:
                    break
                }
            } else {
                todayTask = nil
            }
        }

        // FALLBACK: handle “today’s interval day” & “no existing task”
        let tOpen  = timeUntilValidation
        let tClose = timeUntilExpiration

        let motivationSet = todayMotivation != nil
        let abilitySet   = todayAbility   != nil

        if tOpen > 0 {
            // still waiting for window to open
            currentTaskState = .waitingForValidationTime(
                timeLeft: tOpen,
                motivationSet: motivationSet,
                abilitySet: abilitySet
            )
            return
        } else if tClose > 0 {
            // we’re inside the 4h window → validationTime state
            if motivationSet && abilitySet {
                currentTaskState = .readyToGenerateTask
            } else {
                currentTaskState = .validationTime(
                    timeLeft: tClose,
                    motivationSet: motivationSet,
                    abilitySet: abilitySet
                )
            }
            return
        } else {
            // both are zero → window expired;
            let next = nextScheduledDate(for: habit)
            // Always show missed if the window expired and no task was completed
            currentTaskState = .missed(nextTaskDate: next)
            return
        }
    }

    // Helper to build HabitTaskDetails from todayTask and state
    private func makeTaskDetails() -> HabitTaskDetails {
        guard let task = todayTask else {
            return HabitTaskDetails(description: "", easierAlternative: nil, harderAlternative: nil, motivation: todayMotivation?.level ?? "", ability: todayAbility?.level ?? "", timeLeft: nil)
        }
        // Parse dueDate string to Date and calculate timeLeft
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let dueDateString = task.dueDate else {
            return HabitTaskDetails(description: task.taskDescription ?? "No description available", easierAlternative: task.easierAlternative, harderAlternative: task.harderAlternative, motivation: todayMotivation?.level ?? "", ability: todayAbility?.level ?? "", timeLeft: nil)
        }
        let isoDueDate = dueDateString.hasSuffix("Z") ? dueDateString : dueDateString + "Z"
        let dueDate = formatter.date(from: isoDueDate)
        let timeLeft = dueDate.map { $0.timeIntervalSince(Date()) }
        return HabitTaskDetails(
            description: task.taskDescription ?? "No description available",
            easierAlternative: task.easierAlternative,
            harderAlternative: task.harderAlternative,
            motivation: todayMotivation?.level ?? "",
            ability: todayAbility?.level ?? "",
            timeLeft: timeLeft
        )
    }

    // Helper: Find next scheduled date for a habit
    func nextScheduledDate(for habit: Habit) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let frequency = habit.frequency.lowercased()
        _ = calendar.weekdaySymbols // Sunday = 1
        let shortWeekdaySymbols = calendar.shortWeekdaySymbols // e.g. "Mon"
        _ = calendar.component(.weekday, from: today) // 1 = Sunday

        // Every day
        if frequency == "every day" || frequency == "daily" {
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        // Weekdays
        if frequency == "weekdays" {
            _ = today
            for i in 1...7 {
                let candidate = calendar.date(byAdding: .day, value: i, to: today)!
                let candidateIndex = calendar.component(.weekday, from: candidate)
                if candidateIndex >= 2 && candidateIndex <= 6 { // Mon-Fri
                    return candidate
                }
            }
        }
        // Weekends
        if frequency == "weekends" {
            _ = today
            for i in 1...7 {
                let candidate = calendar.date(byAdding: .day, value: i, to: today)!
                let candidateIndex = calendar.component(.weekday, from: candidate)
                if candidateIndex == 1 || candidateIndex == 7 { // Sun/Sat
                    return candidate
                }
            }
        }
        // Comma-separated days (e.g. "Mon, Wed, Fri")
        let days = frequency.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let validShorts = Set(shortWeekdaySymbols.map { $0.lowercased() })
        let selectedDays = days.compactMap { d in
            let lower = d.prefix(3).lowercased()
            return validShorts.contains(lower) ? lower : nil
        }
        if !selectedDays.isEmpty {
            for i in 1...7 {
                let candidate = calendar.date(byAdding: .day, value: i, to: today)!
                let candidateIndex = calendar.component(.weekday, from: candidate) - 1 // 0 = Sunday
                let candidateShort = shortWeekdaySymbols[candidateIndex].lowercased()
                if selectedDays.contains(candidateShort) {
                    return candidate
                }
            }
        }
        // Fallback: tomorrow
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    // Helper: Parse validation time string to Date
    func parseValidationTime(_ timeString: String) -> Date {
        let now = Date()
        let calendar = Calendar.current
        let formatter24 = DateFormatter()
        formatter24.dateFormat = "HH:mm"
        let formatter12 = DateFormatter()
        formatter12.dateFormat = "h:mm a"
        var time: Date?
        if let t = formatter24.date(from: timeString) {
            time = t
        } else if let t = formatter12.date(from: timeString) {
            time = t
        }
        guard let parsedTime = time else { return now }
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
        var merged = DateComponents()
        merged.year = todayComponents.year
        merged.month = todayComponents.month
        merged.day = todayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        let todayValidation = calendar.date(from: merged) ?? now
        return todayValidation
    }

    // MARK: - Actions (called by the view)
    func setMotivation(_ level: String) async {
        let habitId = selectedHabit?.id ?? 0
        let didSubmit = await submitMotivationEntry(for: habitId, level: level)
        if !didSubmit {
            // Try update if submit failed (likely already exists)
            _ = await updateMotivationEntry(for: habitId, level: level)
        }
        // Always fetch the latest motivation entry so state machine can advance
        if let habitId = selectedHabit?.id {
            _ = await getTodayMotivationEntry(for: habitId)
        }
        await updateTaskStateAsync()
    }

    func setAbility(_ level: String) async {
        _ = await submitAbilityEntry(for: selectedHabit?.id ?? 0, level: level)
        // Fetch the latest ability entry so state machine can advance and chip updates
        if let habitId = selectedHabit?.id {
            _ = await getTodayAbilityEntry(for: habitId)
        }
        await updateTaskStateAsync()
    }

    func generateTask() async {
        guard let selectedHabit = selectedHabit else { return }

        await MainActor.run {
            currentTaskState = .generatingTask
            taskGenerationError = nil
            pollAttempts = 0
        }

        let success = await generateAndCreateTask(for: selectedHabit.id)
        if success {
            await pollForGeneratedTask()
        } else {
            // Try to fetch today's task in case it was created but POST failed
            let fetchedTask = await getTodayTask(for: selectedHabit.id)
            await MainActor.run {
                if let task = fetchedTask {
                    self.todayTask = task
                    self.taskGenerationError = nil
                    self.currentTaskState = .showTask(task: makeTaskDetails(), proof: proofState)
                    self.updateTaskState() // Ensure state machine is up to date
                } else {
                    self.currentTaskState = .readyToGenerateTask
                    self.taskGenerationError = "Failed to generate task. Please try again."
                }
            }
        }
    }

    private func generateAndCreateTask(for habitId: Int) async -> Bool {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            let userDate = formatter.string(from: Date())

            guard let habit = selectedHabit else { return false }

            let request = AITaskGenerationRequest(
                base_difficulty: habit.difficulty.lowercased(),
                motivation_level: todayMotivation?.level.lowercased() ?? "",
                ability_level: todayAbility?.level.lowercased() ?? "",
                proof_style: habit.proofStyle.lowercased(),
                user_language: "en",
                user_timezone: TimeZone.current.identifier,
                user_date: userDate
            )

            _ = try await apiService.generateAndCreateTask(habitId: habitId, request: request)
            return true
        } catch {
            print("Task generation failed: \(error)")
            return false
        }
    }

    // MARK: - Polling for Task Generation
    private func pollForGeneratedTask() async {
        guard let selectedHabit = selectedHabit else { return }

        // Check if we've exceeded max polling attempts
        if pollAttempts >= maxPollAttempts {
            await MainActor.run {
                currentTaskState = .readyToGenerateTask
                taskGenerationError = "Task generation timed out. Please try again."
                isGeneratingTask = false
            }
            return
        }

        pollAttempts += 1

        // Try to fetch today's task
        if let task = await getTodayTask(for: selectedHabit.id) {
            await MainActor.run {
                todayTask = task
                isGeneratingTask = false
                currentTaskState = .showTask(task: makeTaskDetails(), proof: proofState)
                taskGenerationError = nil
                updateTaskState() // Ensure state machine is up to date
            }
        } else {
            // Wait 2 seconds and try again
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await pollForGeneratedTask()
        }
    }

    /// Cancel polling if user leaves the Habits tab or view disappears
    func cancelPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isGeneratingTask = false
    }

    /// Polls for today's task after generation, stops when found or after maxAttempts
    func startPollingForTodayTask(habit: Habit, maxAttempts: Int = 20, interval: TimeInterval = 2.0) {
        pollingTask?.cancel()
        pollingTask = Task {
            for _ in 0..<maxAttempts {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                do {
                    let task = try await apiService.getTodayTask(habitId: habit.id)
                    await MainActor.run {
                        self.todayTask = task
                        self.isGeneratingTask = false
                        self.updateTaskStateAfterGeneration()
                        self.updateTypingTextProofKey()
                    }
                    pollingTask = nil
                    return
                } catch {
                    // Not found yet, keep polling
                }
            }
            // Timeout
            await MainActor.run {
                self.isGeneratingTask = false
                self.errorMessage = "Task generation timed out. Please try again."
                self.updateTaskState()
            }
            pollingTask = nil
        }
    }

    /// Call this when switching habits/tabs to update TypingText key
    func updateTypingTextProofKey() {
        let habitId = selectedHabit?.id ?? 0
        let proofReq = todayTask?.proofRequirements ?? ""
        typingTextProofKey = "proof-\(habitId)-\(proofReq)"
    }

    // After completing a task, reset motivation and ability for the next day
    private func resetMotivationAndAbility() {
        todayMotivation = nil
        todayAbility = nil
    }

    // Update in updateTaskStateAfterGeneration and after proof submission
    private func updateTaskStateAfterGeneration() {
        guard let task = todayTask else { return }
        // If the task is pending, always show the task
        if let status = TaskStatus(rawValue: task.status), status == .pending {
            self.currentTaskState = .showTask(task: makeTaskDetails(), proof: proofState)
        } else {
            self.updateTaskState()
            self.resetMotivationAndAbility()
        }
    }

    func submitProof(type: ProofInputType, data: Data?, text: String?) async {
        guard let task = todayTask else { return }
        isSubmittingProof = true
        proofState = .uploading
        updateTaskState()
        do {
            let response: TaskSubmissionResponse
            switch type {
            case .photo:
                guard let imageData = data else { throw NSError(domain: "No photo data", code: 0) }
                response = try await apiService.submitTaskProofWithFile(
                    taskId: task.id,
                    proofType: "photo",
                    proofContent: "photo",
                    fileData: imageData,
                    fileName: "proof.jpg",
                    mimeType: "image/jpeg"
                )
            case .video:
                guard let videoData = data else { throw NSError(domain: "No video data", code: 0) }
                response = try await apiService.submitTaskProofWithFile(
                    taskId: task.id,
                    proofType: "video",
                    proofContent: "video",
                    fileData: videoData,
                    fileName: "proof.mov",
                    mimeType: "video/quicktime"
                )
            case .audio:
                guard let audioData = data else { throw NSError(domain: "No audio data", code: 0) }
                response = try await apiService.submitTaskProofWithFile(
                    taskId: task.id,
                    proofType: "audio",
                    proofContent: "audio",
                    fileData: audioData,
                    fileName: "proof.m4a",
                    mimeType: "audio/mp4"
                )
            case .text:
                guard let textProof = text else { throw NSError(domain: "No text proof", code: 0) }
                let proofData = TaskProofSubmissionData(proof_type: "text", proof_content: textProof)
                response = try await apiService.submitTaskProof(taskId: task.id, proofData: proofData)
            }
            let updatedTask = response.task
            let validation = response.validation
            let attemptsLeft = updatedTask.attemptsLeft // fixed property name
            let nextTaskDateString = updatedTask.dueDate // fixed property name
            // Parse dueDate string to Date
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoDueDate = (nextTaskDateString ?? "").hasSuffix("Z") ? (nextTaskDateString ?? "") : (nextTaskDateString ?? "") + "Z"
            let nextTaskDate = formatter.date(from: isoDueDate)
            await MainActor.run {
                // Store the actual proof state for preview
                let proofForShare: HabitProofState
                switch type {
                case .photo:
                    if let data = data {
                        proofForShare = .readyToSubmit(.image(data))
                    } else {
                        proofForShare = .submitted
                    }
                case .video:
                    if let data = data {
                        proofForShare = .readyToSubmit(.video(data))
                    } else {
                        proofForShare = .submitted
                    }
                case .audio:
                    if let data = data {
                        proofForShare = .readyToSubmit(.audio(data))
                    } else {
                        proofForShare = .submitted
                    }
                case .text:
                    if let text = text {
                        proofForShare = .readyToSubmit(.text(text))
                    } else {
                        proofForShare = .submitted
                    }
                }
                self.proofState = .submitted
                self.isSubmittingProof = false
                self.todayTask = updatedTask
                self.lastValidationResult = validation
                // Handle state transitions based on validation
                if let validation = validation, validation.isValid ?? false {
                    let details = self.makeTaskDetails()
                    // Save private post immediately
                    Task {
                        await self.createPrivatePostForSuccessShare(task: details, proof: proofForShare)
                    }
                    self.currentTaskState = .successShare(task: details, proof: proofForShare)
                    self.isInSuccessShare = true
                    self.lastSuccessShareTask = details
                    self.lastSuccessShareProof = proofForShare
                    self.lastSuccessShareDate = Date()
                    // Reset failed/missed persistence
                    self.isInFailed = false
                    self.lastFailedAttemptsLeft = nil
                    self.lastFailedDate = nil
                    self.isInMissed = false
                    self.lastMissedNextTaskDate = nil
                    self.lastMissedDate = nil
                } else if (attemptsLeft ?? 0) > 0 {
                    self.currentTaskState = .failed(attemptsLeft: attemptsLeft ?? 0)
                    self.isInFailed = true
                    self.lastFailedAttemptsLeft = attemptsLeft
                    self.lastFailedDate = Date()
                    // Reset others
                    self.isInSuccessShare = false
                    self.lastSuccessShareTask = nil
                    self.lastSuccessShareProof = nil
                    self.lastSuccessShareDate = nil
                    self.isInMissed = false
                    self.lastMissedNextTaskDate = nil
                    self.lastMissedDate = nil
                } else {
                    self.currentTaskState = .failedNoAttempts(nextTaskDate: nextTaskDate ?? Date())
                    // Reset all persistence for failedNoAttempts
                    self.isInFailed = false
                    self.lastFailedAttemptsLeft = nil
                    self.lastFailedDate = nil
                    self.isInSuccessShare = false
                    self.lastSuccessShareTask = nil
                    self.lastSuccessShareProof = nil
                    self.lastSuccessShareDate = nil
                    self.isInMissed = false
                    self.lastMissedNextTaskDate = nil
                    self.lastMissedDate = nil
                }
                self.resetMotivationAndAbility()
            }
            if let autoPost = response.autoCreatedPost {
                self.autoCreatedPostId = autoPost.id
            } else {
                self.autoCreatedPostId = nil as Int?
            }
        } catch {
            await MainActor.run {
                self.proofState = .error(message: error.localizedDescription)
                self.isSubmittingProof = false
                self.updateTaskState()
            }
        }
    }

    // Helper to update state on main actor
    func updateTaskStateAsync() async {
        await MainActor.run {
            self.updateTaskState()
        }
    }

    // MARK: - Streak Freezer Logic (Backend-Driven)
    /// Fetch the user's current streak freezer count from the backend
    func fetchStreakFreezers() async {
        do {
            let response = try await apiService.getUserStreakFreezers()
            await MainActor.run {
                self.streakFreezers = response.streak_freezers
            }
        } catch {
            // Optionally show error, but don't block UI
            print("Failed to fetch streak freezers: \(error.localizedDescription)")
        }
    }

    /// Use a streak freezer (if available) via backend
    func useStreakFreezer() async -> Bool {
        do {
            let response = try await apiService.useUserStreakFreezer()
            await MainActor.run {
                self.streakFreezers = response.streak_freezers
            }
            return true
        } catch {
            print("Failed to use streak freezer: \(error.localizedDescription)")
            return false
        }
    }

    /// Award a streak freezer (for milestone, if needed) via backend
    func awardStreakFreezer() async {
        do {
            let response = try await apiService.awardUserStreakFreezer()
            await MainActor.run {
                self.streakFreezers = response.streak_freezers
            }
        } catch {
            print("Failed to award streak freezer: \(error.localizedDescription)")
        }
    }

    // Share proof logic
    func shareProof(visibility: String, description: String, task: HabitTaskDetails, proof: HabitProofState, proofInputType: ProofInputType? = nil, textProof: String? = nil) async {
        let shouldIncreaseStreak = (visibility == "Friends" || visibility == "Close Friends")
        do {
            let habitId = selectedHabit?.id
            if autoCreatedPostId == nil {
                let post = try await apiService.createPost(
                    taskDescription: task.description,
                    proof: proof,
                    description: description,
                    visibility: visibility,
                    habitId: habitId,
                    proofInputType: proofInputType,
                    textProof: textProof,
                    todayTask: todayTask,
                    autoCreatedPostId: autoCreatedPostId
                )
                autoCreatedPostId = post.id
            }
            if shouldIncreaseStreak, let habit = selectedHabit {
                let newStreak = habit.streak + 1
                await MainActor.run {
                    selectedHabit?.streak = newStreak
                }
                await fetchStreakFreezers()
            }
            // --- Reset successShare state after sharing ---
            await MainActor.run {
                self.isInSuccessShare = false
                self.lastSuccessShareTask = nil
                self.lastSuccessShareProof = nil
                self.lastSuccessShareDate = nil
                // --- Set persistent successDone state ---
                self.isInSuccessDone = true
                self.lastSuccessDoneDate = Date()
                // --- Reset private post state ---
                self.autoCreatedPostId = nil as Int?
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.showError("Failed to share proof: \(error.localizedDescription)")
            }
        }
    }

    private func createPrivatePostForSuccessShare(task: HabitTaskDetails, proof: HabitProofState, proofInputType: ProofInputType? = nil, textProof: String? = nil) async {
        if autoCreatedPostId != nil { return }
        let habitId = selectedHabit?.id
        do {
            let post = try await apiService.createPost(
                taskDescription: task.description,
                proof: proof,
                description: "",
                visibility: "Private",
                habitId: habitId,
                proofInputType: proofInputType,
                textProof: textProof,
                todayTask: todayTask,
                autoCreatedPostId: autoCreatedPostId
            )
            autoCreatedPostId = post.id
        } catch {
            print("[HabitViewModel] Failed to create private post: \(error)")
        }
    }

    // Add this helper for assigned_date string parsing
    private var isoFormatter: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }

    private func getTodayTask(for habitId: Int) async -> TaskEntry? {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            let userDate = formatter.string(from: Date())
            let task = try await apiService.getTodayTask(habitId: habitId, userDate: userDate)
            return task
        } catch {
            return nil
        }
    }

    // When marking missed, persist missed state
    func markTaskMissed(nextTaskDate: Date) {
        self.currentTaskState = .missed(nextTaskDate: nextTaskDate)
        self.isInMissed = true
        self.lastMissedNextTaskDate = nextTaskDate
        self.lastMissedDate = Date()
        // Reset others
        self.isInFailed = false
        self.lastFailedAttemptsLeft = nil
        self.lastFailedDate = nil
        self.isInSuccessShare = false
        self.lastSuccessShareTask = nil
        self.lastSuccessShareProof = nil
        self.lastSuccessShareDate = nil
    }
    // When user retries or dismisses, reset failed/missed persistence
    func resetFailedMissedPersistence() {
        self.isInFailed = false
        self.lastFailedAttemptsLeft = nil
        self.lastFailedDate = nil
        self.isInMissed = false
        self.lastMissedNextTaskDate = nil
        self.lastMissedDate = nil
    }

    /// Call this when entering successShare state to fetch close friends
    func fetchCloseFriends() async {
        let response = await FriendsAPIService.shared.getCloseFriends()
        await MainActor.run {
            self.closeFriendsCount = response.count
        }
    }

    // Add a method to fetch user profile and update userPlan
    public func fetchUserAndHabits() async {
        isLoading = true
        do {
            let user = try await APIService.shared.getCurrentUser()
            self.userPlan = user.plan
            self.habits = try await APIService.shared.fetchHabits()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Call this once in your View’s onAppear
    func startCountdownTimer() {
        cancelCountdownTimer()

        // 1) any “significant” jump in the system clock/time-zone should re-compute immediately
        let clocks = [
            UIApplication.significantTimeChangeNotification,
            .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange
        ].map { NotificationCenter.default.publisher(for: $0) }

        significantChangeCancellable = Publishers.MergeMany(clocks)
            .sink { [weak self] _ in
                self?.recomputeCountdowns()
            }

        // 2) every second tick to update countdown
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.recomputeCountdowns()
            }
    }

    /// Cancel everything in your View’s onDisappear
    func cancelCountdownTimer() {
        timerCancellable?.cancel()
        significantChangeCancellable?.cancel()
    }

    private func recomputeCountdowns() {
        guard let habit = selectedHabit else {
            timeUntilValidation = 0
            timeUntilExpiration = 0
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let window: TimeInterval = 4 * 3600
        let (hour, minute) = parseHourMinute(from: habit.validationTime)
        guard
            let todayValidation = calendar.date(
                bySettingHour:   hour,
                minute:          minute,
                second:          0,
                of:               now
            ),
            let yesterdayValidation = calendar.date(
                byAdding:        .day,
                value:          -1,
                to:               todayValidation
            )
        else {
            timeUntilValidation = 0
            timeUntilExpiration = 0
            return
        }

        let expToday     = todayValidation.addingTimeInterval(window)
        let expYesterday = yesterdayValidation.addingTimeInterval(window)

        let (activeValidation, activeExpiration): (Date, Date) = {
            if now >= yesterdayValidation && now <= expYesterday {
                return (yesterdayValidation, expYesterday)
            } else if now >= todayValidation && now <= expToday {
                return (todayValidation, expToday)
            } else if now < todayValidation {
                return (todayValidation, expToday)
            } else {
                let tomorrowValidation = calendar.date(
                    byAdding: .day,
                    value:    1,
                    to:       todayValidation
                )!
                return (tomorrowValidation, tomorrowValidation.addingTimeInterval(window))
            }
        }()

        // --- PATCH: If today is an interval day and the window has expired, force countdowns to zero ---
        if isTodayIntervalDay(for: habit) {
            if now > expToday {
                timeUntilValidation = 0
                timeUntilExpiration = 0
                return
            }
        }
        // --- END PATCH ---

        timeUntilValidation = max(0, activeValidation.timeIntervalSince(now))
        timeUntilExpiration = max(0, activeExpiration.timeIntervalSince(now))

        // If we just crossed into the validation window, advance your state
        if case .waitingForValidationTime = currentTaskState, now >= activeValidation {
            Task { await updateTaskStateAsync() }
        }
    }

    /// Helper: parse “9:20 PM” / “21:00” etc. into (hour, minute)
    private func parseHourMinute(from s: String) -> (Int, Int) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["h:mm a", "H:mm", "ha", "H"] {
            df.dateFormat = fmt
            if let d = df.date(from: s) {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: d)
                return (comps.hour ?? 0, comps.minute ?? 0)
            }
        }
        return (0, 0)
    }

    /// Called by the UI when the user taps "Try Again" in the failed state
    public func retryAfterFailure() async {
        print("[HabitViewModel] retryAfterFailure called")
        guard let habit = selectedHabit else {
            print("[HabitViewModel] retryAfterFailure: No selected habit")
            return
        }

        print("[HabitViewModel] retryAfterFailure: Fetching today's task for habit id \(habit.id)")

        self.isInFailed = false
        self.lastFailedAttemptsLeft = nil
        self.lastFailedDate = nil
        await fetchTodayTask(for: habit)
        await MainActor.run {
            print("[HabitViewModel] retryAfterFailure: Resetting proof state and updating task state")
            self.proofState = .notStarted
            self.lastValidationResult = nil
            self.updateTaskState()
        }
    }
}

// Add this extension to TaskEntry
extension TaskEntry {
    var assignedDateString: String {
        return assignedDate ?? "No date"
    }
}

// Add this to HabitViewModel
extension HabitViewModel {
    func handleDismissedMissedOrFailed() {
        // After dismiss, update to the correct state for today
        updateTaskState()
    }
}
