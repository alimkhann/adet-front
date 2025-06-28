import SwiftUI

struct HabitsView: View {
    @StateObject private var viewModel = HabitViewModel()
    @StateObject private var aiTaskViewModel = AITaskViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingHabitDetails = false
    @State private var showingAddHabitSheet = false
    @State private var showMotivationAbilityModal = false
    @State private var motivationAnswer: String? = nil
    @State private var abilityAnswer: String? = nil
    @State private var isLoadingMotivation = false
    @State private var isLoadingAbility = false
    @State private var showToast: Bool = false
    @State private var isGeneratingTask: [Int: Bool] = [:]
    @State private var generatedTaskText: [Int: String] = [:]
    @State private var showTaskAnimation: [Int: Bool] = [:]
    @State private var taskDifficulty: [Int: String] = [:]
    @State private var currentTaskRequest: [Int: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Carousel for Habits
                    ScrollView(.horizontal, showsIndicators: false) {
                        let habitCards = viewModel.habits.map { habit in
                            HabitCardView(
                                habit: habit,
                                isSelected: viewModel.selectedHabit?.id == habit.id,
                                onTap: {
                                    viewModel.selectHabit(habit)
                                    Task {
                                        await checkAndHandleHabitSelection(habit)
                                    }
                                },
                                onLongPress: {
                                    print("Long press detected for habit: \(habit.name)")
                                    viewModel.selectHabit(habit)
                                    showingHabitDetails = true
                                }
                            )
                        }
                        HStack(spacing: 15) {
                            ForEach(Array(habitCards.enumerated()), id: \.element.habit.id) { _, card in
                                card
                            }
                            AddHabitCardView(onTap: {
                                showingAddHabitSheet = true
                            })
                        }
                    }
                    .frame(height: 100)
                    .clipped()
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .padding(.top)

                    // Dynamic Bottom Section based on selected habit and task state
                    if let selectedHabit = viewModel.selectedHabit {
                        bottomSection(for: selectedHabit)
                    } else {
                        placeholderSection
                    }

                    Spacer()
                }
            }
            .refreshable {
                await refreshData()
            }
            .padding(.horizontal)
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await viewModel.fetchHabits()
                    // After fetching, check if modal should show for default habit
                    if let habit = viewModel.selectedHabit {
                        await checkAndHandleHabitSelection(habit)
                    }
                }
            }
            .navigationDestination(isPresented: $showingHabitDetails) {
                if let selectedHabit = viewModel.selectedHabit {
                    HabitDetailsView(habit: selectedHabit)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showingAddHabitSheet) {
                AddHabitView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showMotivationAbilityModal) {
                if let habit = viewModel.selectedHabit {
                    MotivationAbilityModal(
                        isPresented: $showMotivationAbilityModal,
                        isLoading: $isLoadingMotivation,
                        habitName: habit.name,
                        todayMotivation: viewModel.todayMotivation,
                        todayAbility: viewModel.todayAbility,
                        onSubmitMotivation: { answer in
                            if let existing = viewModel.todayMotivation, existing.level.capitalized != answer {
                                return await viewModel.updateMotivationEntry(for: habit.id, level: answer.lowercased())
                            } else if viewModel.todayMotivation == nil {
                                return await viewModel.submitMotivationEntry(for: habit.id, level: answer.lowercased())
                            }
                            return true
                        },
                        onSubmitAbility: { answer in
                            let success = await viewModel.submitAbilityEntry(for: habit.id, level: answer.replacingOccurrences(of: " ", with: "_").lowercased())
                            if success {
                                // Refresh the entries after successful submission
                                await refreshMotivationAbilityEntries(for: habit)
                            }
                            return success
                        }
                    )
                    .presentationDetents([.fraction(0.7)])
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func checkAndHandleHabitSelection(_ habit: Habit) async {
        // Don't automatically show motivation/ability modal anymore
        // Just check for existing entries and tasks
        if viewModel.isTodayIntervalDay(for: habit) && isValidationTimeReached(for: habit) {
            let motivation = await viewModel.getTodayMotivationEntry(for: habit.id)
            let ability = await viewModel.getTodayAbilityEntry(for: habit.id)

            // Store the entries for display without showing modal
            viewModel.todayMotivation = motivation
            viewModel.todayAbility = ability
        }

        // Always check for today's task
        await checkTodayTask(for: habit)
    }

    private func isValidationTimeReached(for habit: Habit) -> Bool {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        guard let validationTime = formatter.date(from: habit.validationTime) else {
            return true // If we can't parse, assume it's time
        }

        let now = Date()
        let calendar = Calendar.current

        // Create today's validation time
        let todayValidation = calendar.date(bySettingHour: calendar.component(.hour, from: validationTime),
                                          minute: calendar.component(.minute, from: validationTime),
                                          second: 0,
                                          of: now) ?? now

        return now >= todayValidation
    }

    private func timeUntilValidation(for habit: Habit) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        guard let validationTime = formatter.date(from: habit.validationTime) else {
            return "Soon"
        }

        let now = Date()
        let calendar = Calendar.current

        // Create today's validation time
        let todayValidation = calendar.date(bySettingHour: calendar.component(.hour, from: validationTime),
                                          minute: calendar.component(.minute, from: validationTime),
                                          second: 0,
                                          of: now) ?? now

        let timeInterval = todayValidation.timeIntervalSince(now)

        if timeInterval <= 0 {
            return "Now"
        }

        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func checkTodayTask(for habit: Habit) async {
        do {
            let task = try await aiTaskViewModel.checkTodayTask(for: habit)
            aiTaskViewModel.currentTask = task
        } catch {
            // Task not found or error - this is expected for new habits
            aiTaskViewModel.currentTask = nil
        }
    }

    private func refreshMotivationAbilityEntries(for habit: Habit) async {
        let motivation = await viewModel.getTodayMotivationEntry(for: habit.id)
        let ability = await viewModel.getTodayAbilityEntry(for: habit.id)

        viewModel.todayMotivation = motivation
        viewModel.todayAbility = ability
    }

    private func refreshData() async {
        await viewModel.fetchHabits()
        if let habit = viewModel.selectedHabit {
            await checkAndHandleHabitSelection(habit)
        }
    }

    private func generateTask(for habit: Habit) async {
        guard let motivation = viewModel.todayMotivation?.level,
              let ability = viewModel.todayAbility?.level else {
            return
        }

        isGeneratingTask[habit.id] = true
        currentTaskRequest[habit.id] = taskDifficulty[habit.id] ?? "original"
        showTaskAnimation[habit.id] = true
        generatedTaskText[habit.id] = ""

        // Simulate typing animation
        let placeholderText = "Generating your personalized task..."
        await animateText(placeholderText, for: habit)

        // Set the motivation and ability levels in the viewModel
        aiTaskViewModel.selectedMotivationLevel = motivation
        aiTaskViewModel.selectedAbilityLevel = ability

        // Use the existing generateTaskForHabit method
        aiTaskViewModel.generateTaskForHabit(habit)

        // Wait for the task to be generated or timeout
        var attempts = 0
        let maxAttempts = 100 // 10 second timeout

        while attempts < maxAttempts {
            // Check if we have a task (success case)
            if let task = aiTaskViewModel.currentTask {
                // Clear placeholder and show real task
                generatedTaskText[habit.id] = ""
                await animateText(task.taskDescription, for: habit)
                taskDifficulty[habit.id] = "original"

                // Add a small delay before showing the proof section
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showTaskAnimation[habit.id] = false // Reset animation state
                    }
                }
                isGeneratingTask[habit.id] = false
                return
            }

            // Check if generation is complete but failed
            if !aiTaskViewModel.isGeneratingTask {
                break
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }

        // If we get here, either timed out or generation failed
        generatedTaskText[habit.id] = ""
        if aiTaskViewModel.currentTask != nil {
            // Task exists but we somehow missed it in the loop
            await animateText(aiTaskViewModel.currentTask!.taskDescription, for: habit)
            taskDifficulty[habit.id] = "original"
            showTaskAnimation[habit.id] = false
        } else {
            // No task found
            await animateText("Failed to generate task. Please try again.", for: habit)
            showTaskAnimation[habit.id] = false
        }

        isGeneratingTask[habit.id] = false
    }

    private func generateEasierTask(for habit: Habit) async {
        guard let currentTask = aiTaskViewModel.currentTask,
              let easierAlternative = currentTask.easierAlternative,
              !easierAlternative.isEmpty else { return }

        isGeneratingTask[habit.id] = true
        showTaskAnimation[habit.id] = true
        generatedTaskText[habit.id] = ""

        // Check current difficulty to determine what to show
        let currentDifficulty = taskDifficulty[habit.id] ?? "original"

        if currentDifficulty == "harder" {
            // If currently showing harder, go back to original
            await animateText(currentTask.taskDescription, for: habit)
            taskDifficulty[habit.id] = "original"
        } else {
            // If currently showing original, go to easier
            await animateText(easierAlternative, for: habit)
            taskDifficulty[habit.id] = "easier"
        }

        showTaskAnimation[habit.id] = false // Reset animation state
        isGeneratingTask[habit.id] = false
    }

    private func generateHarderTask(for habit: Habit) async {
        guard let currentTask = aiTaskViewModel.currentTask,
              let harderAlternative = currentTask.harderAlternative,
              !harderAlternative.isEmpty else { return }

        isGeneratingTask[habit.id] = true
        showTaskAnimation[habit.id] = true
        generatedTaskText[habit.id] = ""

        // Check current difficulty to determine what to show
        let currentDifficulty = taskDifficulty[habit.id] ?? "original"

        if currentDifficulty == "easier" {
            // If currently showing easier, go back to original
            await animateText(currentTask.taskDescription, for: habit)
            taskDifficulty[habit.id] = "original"
        } else {
            // If currently showing original, go to harder
            await animateText(harderAlternative, for: habit)
            taskDifficulty[habit.id] = "harder"
        }

        showTaskAnimation[habit.id] = false // Reset animation state
        isGeneratingTask[habit.id] = false
    }

    private func animateText(_ text: String, for habit: Habit) async {
        let words = text.components(separatedBy: " ")

        for (index, word) in words.enumerated() {
            await MainActor.run {
                if index == 0 {
                    generatedTaskText[habit.id] = word
                } else {
                    generatedTaskText[habit.id] = (generatedTaskText[habit.id] ?? "") + " " + word
                }
            }

            // Vary the delay for more natural typing
            let delay = Double.random(in: 0.05...0.15)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    // MARK: - UI Sections

    private func bottomSection(for habit: Habit) -> some View {
        VStack(spacing: 12) {
            // Task Generation Section - Always present
            taskGenerationSection(for: habit)

            // Upload Proof Section - Animated appearance when task exists
            if aiTaskViewModel.currentTask != nil {
                uploadProofSection(for: habit)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.5), value: aiTaskViewModel.currentTask != nil)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func taskGenerationSection(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with motivation and ability levels - moved higher
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Task")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Only show status text when no task exists
                    if aiTaskViewModel.currentTask == nil {
                        if viewModel.isTodayIntervalDay(for: habit) {
                            if isValidationTimeReached(for: habit) {
                                Text("Ready to generate your task")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Available in \(timeUntilValidation(for: habit))")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("This habit is scheduled for \(habit.frequency)")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Motivation & Ability Display - Always show when it's the habit day
                if viewModel.isTodayIntervalDay(for: habit) {
                    HStack(spacing: 20) {
                        // Motivation
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text(motivationEmoji(viewModel.todayMotivation?.level))
                                    .font(.caption)
                                Text("Motivation")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(viewModel.todayMotivation?.level.capitalized ?? "Not Set")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.todayMotivation != nil ? .primary : .secondary)
                        }

                        // Ability
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text(abilityEmoji(viewModel.todayAbility?.level))
                                    .font(.caption)
                                Text("Ability")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(viewModel.todayAbility?.level.capitalized ?? "Not Set")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.todayAbility != nil ? .primary : .secondary)
                        }
                    }
                }
            }

            // Task Display or Generation
            if showTaskAnimation[habit.id] == true {
                // AI Chat Animation
                VStack(alignment: .leading, spacing: 12) {
                    Text(generatedTaskText[habit.id] ?? "")
                        .font(.body)
                        .foregroundColor(.primary)
                        .animation(.easeInOut, value: generatedTaskText[habit.id])
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(colorScheme == .dark ? Color.black : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            } else if let currentTask = aiTaskViewModel.currentTask {
                // Generated Task Display
                taskDisplayView(for: habit, currentTask: currentTask)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.4), value: showTaskAnimation[habit.id])
            }

            // Action Buttons
            if viewModel.isTodayIntervalDay(for: habit) && isValidationTimeReached(for: habit) {
                if viewModel.todayMotivation != nil && viewModel.todayAbility != nil {
                    if aiTaskViewModel.currentTask == nil && !(isGeneratingTask[habit.id] ?? false) {
                        // Generate Task Button
                        Button(action: {
                            Task {
                                await generateTask(for: habit)
                            }
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Generate AI Task")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else if aiTaskViewModel.currentTask != nil && !(isGeneratingTask[habit.id] ?? false) {
                        // Easier/Harder Buttons - Show both at original, single "Original" button otherwise
                        let currentDifficulty = taskDifficulty[habit.id] ?? "original"

                        HStack(spacing: 12) {
                            if currentDifficulty == "original" {
                                // Show both buttons when at original difficulty
                                if aiTaskViewModel.currentTask?.easierAlternative != nil && !(aiTaskViewModel.currentTask?.easierAlternative?.isEmpty ?? true) {
                                    Button(action: {
                                        Task {
                                            await generateEasierTask(for: habit)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.down.circle")
                                            Text("Easier")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)
                                    ))
                                }

                                if aiTaskViewModel.currentTask?.harderAlternative != nil && !(aiTaskViewModel.currentTask?.harderAlternative?.isEmpty ?? true) {
                                    Button(action: {
                                        Task {
                                            await generateHarderTask(for: habit)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.up.circle")
                                            Text("Harder")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)
                                    ))
                                }
                            } else {
                                // Show single "Original" button when at easier or harder difficulty
                                Button(action: {
                                    Task {
                                        if currentDifficulty == "easier" {
                                            await generateHarderTask(for: habit) // This will go back to original
                                        } else if currentDifficulty == "harder" {
                                            await generateEasierTask(for: habit) // This will go back to original
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise.circle")
                                        Text("Original")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                ))
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: currentDifficulty)
                    }
                } else {
                    // Need Motivation & Ability - show different states based on completion
                    let hasMotivation = viewModel.todayMotivation != nil
                    let hasAbility = viewModel.todayAbility != nil

                    Button(action: {
                        showMotivationAbilityModal = true
                    }) {
                        HStack {
                            Image(systemName: "heart.circle")
                            if !hasMotivation && !hasAbility {
                                Text("Set Motivation & Ability")
                                    .fontWeight(.semibold)
                            } else if hasMotivation && !hasAbility {
                                Text("Complete Ability Assessment")
                                    .fontWeight(.semibold)
                            } else if !hasMotivation && hasAbility {
                                Text("Complete Motivation Assessment")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else if !viewModel.isTodayIntervalDay(for: habit) {
                // Not Today - styled like primary button
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text("Come back soon!")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(colorScheme == .dark ? Color.white : Color.black)
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .cornerRadius(12)
            } else {
                // Waiting for validation time - Just the button
                Button(action: {
                    showMotivationAbilityModal = true
                }) {
                    HStack {
                        Image(systemName: "heart.circle")
                        Text("Set Motivation & Ability")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal, 0)
    }

    // Helper functions for emojis
    private func motivationEmoji(_ level: String?) -> String {
        switch level?.lowercased() {
        case "high": return "🟢"
        case "medium": return "🟡"
        case "low": return "🔴"
        default: return "⚪"
        }
    }

    private func abilityEmoji(_ level: String?) -> String {
        switch level?.lowercased() {
        case "easy": return "🟢"
        case "medium": return "🟡"
        case "hard": return "🔴"
        default: return "⚪"
        }
    }

    private func timeRemainingForTask(assignedDate: Date) -> String {
        let now = Date()
        let fourHoursLater = assignedDate.addingTimeInterval(4 * 60 * 60) // 4 hours in seconds
        let timeRemaining = fourHoursLater.timeIntervalSince(now)

        if timeRemaining <= 0 {
            return "Expired"
        }

        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func uploadProofSection(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with timer
            VStack(alignment: .leading, spacing: 8) {
                Text("Upload Proof")
                    .font(.title2)
                    .fontWeight(.bold)

                if let currentTask = aiTaskViewModel.currentTask {
                    // 4-hour countdown timer
                    if !currentTask.assignedDate.isEmpty {
                        let parsedDate = parseTaskDate(from: currentTask.assignedDate)

                        if let date = parsedDate {
                            let timeRemaining = timeRemainingForTask(assignedDate: date)
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text("Time remaining: \(timeRemaining)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            // Show debug info if date parsing fails
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.red)
                                Text("Timer: Unable to parse date (\(currentTask.assignedDate))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                } else {
                    Text("Proof submission will be available after task generation")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            // Proof Requirements - only show when task exists
            if let currentTask = aiTaskViewModel.currentTask {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentTask.proofRequirements)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(colorScheme == .dark ? Color.black : Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                        )
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3).delay(0.1), value: aiTaskViewModel.currentTask != nil)

                // Action Buttons - only show when task exists
                Button(action: {
                    // Handle proof submission
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Submit Proof")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryButtonStyle())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal, 0)
    }

    private func parseTaskDate(from dateString: String) -> Date? {
        // Try parsing as current date first (common case for new tasks)
        let now = Date()
        let calendar = Calendar.current

        // If the string looks like today's date, use current time
        let todayString = ISO8601DateFormatter().string(from: now).prefix(10) // "2024-12-19"
        if dateString.hasPrefix(todayString) || dateString == "today" {
            return now
        }

        // Try ISO8601 first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try common formats
        let dateFormatter = DateFormatter()
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]

        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }

        // If all else fails, return current time for debugging
        print("Could not parse date: \(dateString), using current time")
        return now
    }

    private var placeholderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select a Habit")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose a habit from above to see today's AI-generated task")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal, 0)
    }

    private func taskDisplayView(for habit: Habit, currentTask: TaskEntry) -> some View {
        // Calculate values outside the VStack
        let currentDifficulty = taskDifficulty[habit.id] ?? "original"
        let displayText: String

        switch currentDifficulty {
        case "easier":
            displayText = currentTask.easierAlternative ?? currentTask.taskDescription
        case "harder":
            displayText = currentTask.harderAlternative ?? currentTask.taskDescription
        default:
            displayText = currentTask.taskDescription
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(displayText)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(colorScheme == .dark ? Color.black : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }
}
