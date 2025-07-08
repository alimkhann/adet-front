import SwiftUI

@MainActor
public class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var selectedHabit: Habit?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var todayMotivation: MotivationEntryResponse? = nil
    @Published var todayAbility: AbilityEntryResponse? = nil

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

    @Published var typingTextProofKey: String = ""
    private var pollingTask: Task<Void, Never>? = nil

    private let apiService = APIService.shared

    // Remove expiryTimer and foregroundObserver
    // Remove startExpiryTimer and deinit observer logic

    // Remove checkForTaskExpiry and all timer logic

    /// Called by the UI when the timer hits 0
    func handleTaskExpired() async {
        guard let habit = selectedHabit, let task = todayTask, task.status.lowercased() == "pending" else { return }
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

    public init() {
        // No longer needed
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
            // Fallback: check for expiry after fetching habits
            await handleTaskExpired()
        } catch {
            errorMessage = "Failed to fetch habits: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    func selectHabit(_ habit: Habit) {
        selectedHabit = habit
        updateTypingTextProofKey()
    }

    func deleteHabit(_ habit: Habit) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await apiService.deleteHabit(id: habit.id)
            print("Successfully deleted habit: \(habit.name)")

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
            let entry = try await apiService.getTodayMotivationEntry(habitId: habitId)
            todayMotivation = entry
            return entry
        } catch {
            todayMotivation = nil
            return nil
        }
    }

    func submitMotivationEntry(for habitId: Int, level: String) async -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        do {
            _ = try await apiService.submitMotivationEntry(habitId: habitId, date: String(today), level: level)
            return true
        } catch let error as NSError {
            if error.localizedDescription.contains("already exists") {
                // Already exists, treat as success
                return true
            }
            ToastManager.shared.showError(error.localizedDescription)
            return false
        }
    }

    func updateMotivationEntry(for habitId: Int, level: String) async -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        do {
            _ = try await apiService.updateMotivationEntry(habitId: habitId, date: String(today), level: level)
            return true
        } catch {
            ToastManager.shared.showError(error.localizedDescription)
            return false
        }
    }

    func getTodayAbilityEntry(for habitId: Int) async -> AbilityEntryResponse? {
        do {
            let entry = try await apiService.getTodayAbilityEntry(habitId: habitId)
            todayAbility = entry
            return entry
        } catch {
            todayAbility = nil
            return nil
        }
    }

    func submitAbilityEntry(for habitId: Int, level: String) async -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        do {
            _ = try await apiService.submitAbilityEntry(habitId: habitId, date: String(today), level: level)
            return true
        } catch {
            return false
        }
    }

    func updateAbilityEntry(for habitId: Int, level: String) async -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        do {
            _ = try await apiService.updateAbilityEntry(habitId: habitId, date: String(today), level: level)
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
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            let userDate = formatter.string(from: Date())
            let task = try await apiService.getTodayTask(habitId: habit.id, userDate: String(userDate))
            await MainActor.run {
                self.todayTask = task
                self.updateTypingTextProofKey()
            }
            // Fallback: check for expiry after fetching today's task
            await handleTaskExpired()
        } catch {
            await MainActor.run {
                self.todayTask = nil
                self.updateTypingTextProofKey()
            }
        }
    }

    // MARK: - Task State Machine
    func updateTaskState() {
        guard let habit = selectedHabit else {
            currentTaskState = .empty
            return
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
                    currentTaskState = .successShare(task: makeTaskDetails(), proof: proofState)
                    return
                case .pending:
                    currentTaskState = .showTask(task: makeTaskDetails(), proof: proofState)
                    return
                default:
                    break
                }
            } else {
                todayTask = nil
            }
        }

        // Not validation time yet
        let now = Date()
        let validationTime = parseValidationTime(habit.validationTime)
        let timeLeft = validationTime.timeIntervalSince(now)
        let isValidationTime = timeLeft <= 0

        let motivationSet = todayMotivation != nil
        let abilitySet = todayAbility != nil

        if !isValidationTime {
            if !motivationSet {
                currentTaskState = .setMotivation(current: nil)
                return
            }
            if !abilitySet {
                currentTaskState = .setAbility(current: nil)
                return
            }
            currentTaskState = .waitingForValidationTime(timeLeft: timeLeft, motivationSet: motivationSet, abilitySet: abilitySet)
            return
        }
        if !motivationSet {
            currentTaskState = .setMotivation(current: nil)
            return
        }
        if !abilitySet {
            currentTaskState = .setAbility(current: nil)
            return
        }

        // Only allow .readyToGenerateTask if no todayTask exists
        if todayTask == nil {
            currentTaskState = .readyToGenerateTask
        } else {
            // If a task exists, always show it
            currentTaskState = .showTask(task: makeTaskDetails(), proof: proofState)
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
        let isoDueDate = task.dueDate.hasSuffix("Z") ? task.dueDate : task.dueDate + "Z"
        let dueDate = formatter.date(from: isoDueDate)
        let timeLeft = dueDate.map { $0.timeIntervalSince(Date()) }
        return HabitTaskDetails(
            description: task.taskDescription,
            easierAlternative: task.easierAlternative,
            harderAlternative: task.harderAlternative,
            motivation: todayMotivation?.level ?? "",
            ability: todayAbility?.level ?? "",
            timeLeft: timeLeft
        )
    }

    // Helper: Find next scheduled date for a habit
    func nextScheduledDate(for habit: Habit) -> Date {
        // Implement logic to find the next date this habit is scheduled for
        // For now, just return tomorrow
        return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    // Helper: Parse validation time string to Date
    func parseValidationTime(_ timeString: String) -> Date {
        let today = Date()
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
        guard let parsedTime = time else { return today }
        let components = calendar.dateComponents([.year, .month, .day], from: today)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
        var merged = DateComponents()
        merged.year = components.year
        merged.month = components.month
        merged.day = components.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged) ?? today
    }

    // MARK: - Actions (called by the view)
    func setMotivation(_ level: String) async {
        _ = await submitMotivationEntry(for: selectedHabit?.id ?? 0, level: level)
        // Fetch the latest motivation entry so state machine can advance
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
        guard let habit = selectedHabit else { return }
        isGeneratingTask = true
        updateTaskState()
        do {
            let request = AITaskGenerationRequest(
                base_difficulty: habit.difficulty.lowercased(),
                motivation_level: todayMotivation?.level.lowercased() ?? "",
                ability_level: todayAbility?.level.lowercased() ?? "",
                proof_style: habit.proofStyle.lowercased(),
                user_language: "en",
                user_timezone: TimeZone.current.identifier
            )
            _ = try await apiService.generateAndCreateTask(habitId: habit.id, request: request)
            // Start polling for the generated task
            startPollingForTodayTask(habit: habit)
        } catch {
            await fetchTodayTask(for: habit)
            await MainActor.run {
                self.isGeneratingTask = false
                self.updateTaskStateAfterGeneration()
            }
        }
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

    // New helper: After generating, never allow .readyToGenerateTask again for today
    private func updateTaskStateAfterGeneration() {
        guard let task = todayTask else { return }
        // If the task is pending, always show the task
        if let status = TaskStatus(rawValue: task.status), status == .pending {
            self.currentTaskState = .showTask(task: makeTaskDetails(), proof: proofState)
        } else {
            self.updateTaskState()
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
            await MainActor.run {
                self.proofState = .submitted
                self.isSubmittingProof = false
                self.todayTask = updatedTask
                self.updateTaskState()
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
            try await apiService.createPost(
                taskDescription: task.description,
                proof: proof,
                description: description,
                visibility: visibility,
                habitId: habitId,
                proofInputType: proofInputType,
                textProof: textProof
            )
            if shouldIncreaseStreak, let habit = selectedHabit {
                let newStreak = habit.streak + 1
                await MainActor.run {
                    selectedHabit?.streak = newStreak
                }
                // Award streak freezer is now backend-driven and handled automatically
                await fetchStreakFreezers()
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.showError("Failed to share proof: \(error.localizedDescription)")
            }
        }
    }

    // Add this helper for assigned_date string parsing
    private var isoFormatter: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }
}

// Add this extension to TaskEntry
extension TaskEntry {
    var assignedDateString: String {
        return assignedDate
    }
}

// Add this to HabitViewModel
extension HabitViewModel {
    func handleDismissedMissedOrFailed() {
        // After dismiss, update to the correct state for today
        updateTaskState()
    }
}
