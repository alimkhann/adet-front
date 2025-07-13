import SwiftUI
import PhotosUI

private func proofInputType(from requirements: String) -> ProofInputType {
    let lower = requirements.lowercased()
    if lower.contains("photo") { return .photo }
    if lower.contains("video") { return .video }
    if lower.contains("audio") { return .audio }
    if lower.contains("text") { return .text }
    return .photo // default fallback
}

struct HabitTaskSectionView: View {
    let state: HabitTaskState
    let isTaskInProgress: Bool
    let onSetMotivation: (String) -> Void
    let onSetAbility: (String) -> Void
    let onGenerateTask: () -> Void
    let onSubmitProof: (ProofInputType, Data?, String?) -> Void
    let onRetry: () -> Void
    let onShowMotivationStep: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: HabitViewModel
    @State private var forceMotivationStep: Bool = false
    @State private var currentTaskDescription: String? = nil
    @State private var selectedAlternative: String? = nil
    @State private var showProofModal: Bool = false
    @State private var shownTaskDescription: String? = nil
    @State private var shownProofRequirements: String? = nil
    @State private var lastTaskId: Int? = nil
    @State private var lastProofRequirements: String? = nil
    @State private var showShareModal: Bool = false

    var body: some View {
        GeometryReader { geometry in
            switch state {
            case .empty:
                EmptyView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)

            case .notToday(let nextTaskDate):
                TaskCardContainer { NotTodayView(nextTaskDate: nextTaskDate) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)

            case .waitingForValidationTime(_, _, _):
                TaskCardContainer {
                    WaitingForValidationTimeView(
                        viewModel: viewModel,
                        onValidationTimeArrived: {
                            Task { await viewModel.updateTaskStateAsync() }
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .validationTime(_, _, _):
                TaskCardContainer {
                    validationTimeView(
                        viewModel: viewModel,
                        onValidationTimeArrived: {
                            Task { await viewModel.updateTaskStateAsync() }
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .setMotivation:
                TaskCardContainer {
                    VStack(alignment: .leading, spacing: 20) {
                        // Timer
                        HStack {
                            Image(systemName: "clock")
                            let timeLeft = viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime).timeIntervalSince(Date()) } ?? 0
                            let hours = Int(timeLeft / 3600)
                            let minutes = Int(timeLeft.truncatingRemainder(dividingBy: 3600) / 60)
                            Text("\(hours)h \(minutes)m left")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        // Chips
                        HStack(spacing: 16) {
                            MotivationAbilityChip(value: viewModel.todayMotivation?.level, isMotivation: true)
                            MotivationAbilityChip(value: viewModel.todayAbility?.level, isMotivation: false)
                        }
                        .padding(.vertical)
                        // Stepper
                        MotivationStepperView(current: viewModel.todayMotivation?.level, onSet: onSetMotivation, onBack: onRetry)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .setAbility:
                TaskCardContainer {
                    VStack(alignment: .leading, spacing: 20) {
                        // Timer
                        HStack {
                            Image(systemName: "clock")
                            let timeLeft = viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime).timeIntervalSince(Date()) } ?? 0
                            let hours = Int(timeLeft / 3600)
                            let minutes = Int(timeLeft.truncatingRemainder(dividingBy: 3600) / 60)
                            Text("\(hours)h \(minutes)m left")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        // Chips
                        HStack(spacing: 16) {
                            MotivationAbilityChip(value: viewModel.todayMotivation?.level, isMotivation: true)
                            MotivationAbilityChip(value: viewModel.todayAbility?.level, isMotivation: false)
                        }
                        .padding(.vertical)
                        // Stepper
                        AbilityStepperView(current: viewModel.todayAbility?.level, onSet: onSetAbility, onBack: onShowMotivationStep)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .readyToGenerateTask:
                TaskCardContainer {
                    if let error = viewModel.taskGenerationError {
                        TaskGenerationErrorView(errorMessage: error) {
                            Task {
                                await viewModel.generateTask()
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Task")
                                .font(.headline)

                            Text("Ready to generate your task.")
                                .foregroundStyle(.secondary)

                            HStack(spacing: 16) {
                                MotivationAbilityChip(value: viewModel.todayMotivation?.level.capitalized, isMotivation: true)
                                    .frame(maxWidth: .infinity)

                                MotivationAbilityChip(value: viewModel.todayAbility?.level.capitalized, isMotivation: false)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical)

                            OutlinedBox {
                                Text("Awesome! Our AI will generate a task according to your motivation and ability levels. You've got this!")
                                    .font(.body)
                                    .frame(maxHeight: .infinity, alignment: .topLeading)
                            }

                            Spacer()

                            Button(action: onGenerateTask) {
                                Label("Generate Task", systemImage: "wand.and.stars")
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .generatingTask:
                VStack(spacing: 16) {
                    TaskCardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                Text("Today's Task")
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 8) {
                                    MotivationAbilityChip(value: viewModel.todayMotivation?.level.capitalized, isMotivation: true)
                                    MotivationAbilityChip(value: viewModel.todayAbility?.level.capitalized, isMotivation: false)
                                }
                            }
                            .padding(.bottom, 8)
                            OutlinedBox {
                                TypingText(text: "Generating Task", animatedDots: true)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    ProofCardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Proof")
                                .font(.headline)
                            if state != .readyToGenerateTask {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    let timeLeft = Int(viewModel.timeUntilExpiration)
                                    let hours = timeLeft / 3600
                                    let minutes = (timeLeft % 3600) / 60
                                    Text("Closes in \(hours)h \(minutes)m")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            ProofSectionView(
                                proof: $viewModel.proofState,
                                onSubmitProof: onSubmitProof,
                                isGenerating: true,
                                validationTime: viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime) },
                                onRetry: {
                                    viewModel.proofState = .notStarted
                                    viewModel.lastValidationResult = nil
                                    viewModel.updateTaskState()
                                }
                            )
                            .environmentObject(viewModel)
                        }
                        .id("proof-\(viewModel.todayTask?.proofRequirements ?? "")-\(selectedAlternative ?? "original")")
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .showTask(let task, _):
                VStack(spacing: 16) {
                    TaskCardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                Text("Today's Task")
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 8) {
                                    MotivationAbilityChip(value: task.motivation.capitalized, isMotivation: true)
                                    MotivationAbilityChip(value: task.ability.capitalized, isMotivation: false)
                                }
                            }
                            OutlinedBox {
                                TypingText(text: currentTaskDescription ?? task.description)
                                    .id("task-\(currentTaskDescription ?? task.description)-\(selectedAlternative ?? "original")")
                                    .frame(maxHeight: .infinity, alignment: .topLeading)
                            }
                            HStack(spacing: 12) {
                                if selectedAlternative == nil {
                                    Button {
                                        if let easier = task.easierAlternative {
                                            currentTaskDescription = easier
                                            selectedAlternative = "easier"
                                        }
                                    } label: {
                                        Text("Easier").frame(minHeight: 44)
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .disabled(task.easierAlternative == nil)
                                    Button {
                                        if let harder = task.harderAlternative {
                                            currentTaskDescription = harder
                                            selectedAlternative = "harder"
                                        }
                                    } label: {
                                        Text("Harder").frame(minHeight: 44)
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .disabled(task.harderAlternative == nil)
                                } else {
                                    Button {
                                        currentTaskDescription = nil
                                        selectedAlternative = nil
                                    } label: {
                                        Text("Original").frame(minHeight: 44)
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .disabled(task.easierAlternative == nil && task.harderAlternative == nil)
                                }
                            }
                        }
                    }

                    ProofCardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Proof")
                                .font(.headline)
                            if state != .readyToGenerateTask {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    let timeLeft = Int(viewModel.timeUntilExpiration)
                                    let hours = timeLeft / 3600
                                    let minutes = (timeLeft % 3600) / 60
                                    Text("Closes in \(hours)h \(minutes)m")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            ProofSectionView(
                                proof: $viewModel.proofState,
                                onSubmitProof: { _, _, _ in showProofModal = true },
                                isGenerating: false,
                                validationTime: viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime) },
                                onRetry: {
                                    viewModel.proofState = .notStarted
                                    viewModel.lastValidationResult = nil
                                    viewModel.updateTaskState()
                                    showProofModal = false
                                }
                            )
                            .environmentObject(viewModel)
                            .id("proof-\(viewModel.todayTask?.proofRequirements ?? "")-\(selectedAlternative ?? "original")")
                        }
                        .id("proof-\(viewModel.todayTask?.proofRequirements ?? "")-\(selectedAlternative ?? "original")")
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(.vertical)
                .sheet(isPresented: $showProofModal, onDismiss: {
                    // Reset modal state if needed
                }) {
                    SubmitProofModalView(
                        proofState: $viewModel.proofState,
                        instruction: viewModel.todayTask?.proofRequirements ?? "",
                        validationTime: viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime) } ?? Date(),
                        proofType: proofInputType(from: viewModel.todayTask?.proofRequirements ?? "photo"),
                        onSubmit: { type, data, text in
                            Task {
                                await viewModel.submitProof(type: type, data: data, text: text)
                            }
                        },
                        image: nil
                    )
                    .presentationDetents([.fraction(0.65), .large])
                }
                .onChange(of: viewModel.proofState) {
                    if case .submitted = viewModel.proofState {
                        showProofModal = false
                    }
                    if case .error = viewModel.proofState {
                        showProofModal = false
                    }
                }

            case .successShare(let task, let proof):
                TaskCardContainer {
                    VStack(spacing: 0) {
                        SuccessShareView(task: task)

                        if let validation = viewModel.lastValidationResult {
                            OutlinedBox {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Success!").font(.headline).foregroundColor(Color.green)
                                    Text(validation.feedback ?? "Feedback not available").font(.body).foregroundColor(.primary)
                                    if let reasoning = validation.reasoning, !reasoning.isEmpty {
                                        Text(reasoning).font(.subheadline).foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        Button(action: { showShareModal = true }) {
                            Text("Share With Friends")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Text("Note: Your streak only grows when you share your win with friends. If you have no friends yet, you can still increase your streak.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)
                .onAppear {
                    Task {
                        await viewModel.fetchCloseFriends()
                    }
                }
                .sheet(isPresented: $showShareModal) {
                    if let todayTask = viewModel.todayTask {
                        // Reload the post if needed when the sheet appears
                        ShareProofModalSheetLoader(viewModel: viewModel, todayTask: todayTask, proof: viewModel.lastSuccessShareProof ?? proof)
                    }
                }

            case .successDone:
                TaskCardContainer { SuccessDoneView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)

            case .missed(let nextTaskDate):
                TaskCardContainer { MissedTaskView(nextTaskDate: nextTaskDate) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)

            case .failed(let attemptsLeft):
                TaskCardContainer {
                    FailedTaskView(
                        attemptsLeft: attemptsLeft,
                        onRetry: onRetry,
                        validation: viewModel.lastValidationResult
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .failedNoAttempts(let nextTaskDate):
                TaskCardContainer { FailedNoAttemptsView(nextTaskDate: nextTaskDate) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)

            case .dismissableMissed(let nextTaskDate):
                TaskCardContainer {
                    DismissableMissedTaskView(nextTaskDate: nextTaskDate, onDismiss: {
                        viewModel.handleDismissedMissedOrFailed()
                    })
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)
            case .dismissableFailedNoAttempts(let nextTaskDate):
                TaskCardContainer {
                    DismissableFailedNoAttemptsView(nextTaskDate: nextTaskDate, onDismiss: {
                        viewModel.handleDismissedMissedOrFailed()
                    })
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .error(let message):
                TaskCardContainer { ErrorView(message: message, onRetry: onRetry) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)
            }
        }
    }
}

// MARK: - Subviews

struct NotTodayView: View {
    let nextTaskDate: Date
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Task is Not Today").font(.title2).fontWeight(.semibold)

            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(nextTaskMessage(for: nextTaskDate))
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public struct WaitingForValidationTimeView: View {
    @ObservedObject public var viewModel: HabitViewModel
    public var onValidationTimeArrived: (() -> Void)? = nil

    public init(viewModel: HabitViewModel, onValidationTimeArrived: (() -> Void)? = nil) {
        self._viewModel = ObservedObject(initialValue: viewModel)
        self.onValidationTimeArrived = onValidationTimeArrived
    }

    private var hours: Int { Int(viewModel.timeUntilValidation) / 3600 }
    private var minutes: Int { (Int(viewModel.timeUntilValidation) % 3600) / 60 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Task")
                .font(.headline)

            HStack {
                Image(systemName: "clock")
                Text("Opens in \(hours)h \(minutes)m")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Text("It's not the time yet but let's set your motivation & ability levels in advance.")
                .font(.body)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                MotivationAbilityChip(value: viewModel.todayMotivation?.level, isMotivation: true)
                MotivationAbilityChip(value: viewModel.todayAbility?.level, isMotivation: false)
            }
            .padding(.vertical)

            // Show the stepper if not set
            if viewModel.todayMotivation == nil {
                MotivationStepperView(current: nil, onSet: { level in Task { await viewModel.setMotivation(level) } }, onBack: {})
            } else if viewModel.todayAbility == nil {
                AbilityStepperView(current: nil, onSet: { level in Task { await viewModel.setAbility(level) } }, onBack: {})
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    OutlinedBox {
                        Text("Awesome! Now let's wait for the validation time. You can come back later.")
                            .font(.headline)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public struct validationTimeView: View {
    @ObservedObject public var viewModel: HabitViewModel
    public var onValidationTimeArrived: (() -> Void)? = nil

    public init(viewModel: HabitViewModel, onValidationTimeArrived: (() -> Void)? = nil) {
        self._viewModel = ObservedObject(initialValue: viewModel)
        self.onValidationTimeArrived = onValidationTimeArrived
    }

    private var hours: Int { Int(viewModel.timeUntilExpiration) / 3600 }
    private var minutes: Int { (Int(viewModel.timeUntilExpiration) % 3600) / 60 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Task")
                .font(.headline)

            HStack {
                Image(systemName: "clock")
                Text("Closes in \(hours)h \(minutes)m")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Text("It's time! Set your motivation & ability levels.")
                .font(.body)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                MotivationAbilityChip(value: viewModel.todayMotivation?.level, isMotivation: true)
                MotivationAbilityChip(value: viewModel.todayAbility?.level, isMotivation: false)
            }
            .padding(.vertical)

            // Show the stepper if not set
            if viewModel.todayMotivation == nil {
                MotivationStepperView(current: nil, onSet: { level in Task { await viewModel.setMotivation(level) } }, onBack: {})
            } else if viewModel.todayAbility == nil {
                AbilityStepperView(current: nil, onSet: { level in Task { await viewModel.setAbility(level) } }, onBack: {})
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    OutlinedBox {
                        Text("Awesome! You're ready to generate your task.")
                            .font(.headline)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}


struct ReadyToGenerateTaskView: View {
    @ObservedObject public var viewModel: HabitViewModel
    let onGenerateTask: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Task")
                .font(.headline)

            Text("Ready to generate your task.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                MotivationAbilityChip(value: viewModel.todayMotivation?.level, isMotivation: true)
                .frame(maxWidth: .infinity)

                MotivationAbilityChip(value: viewModel.todayAbility?.level, isMotivation: false)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical)

            OutlinedBox {
                Text("Awesome! Our AI will generate a task according to your motivation and ability levels. You've got this!")
                    .font(.body)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }

            Spacer()

            Button(action: onGenerateTask) {
                Label("Generate Task", systemImage: "wand.and.stars")
                    .frame(minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct TaskDetailView: View {
    let task: HabitTaskDetails?
    let isGenerating: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Task").font(.headline)

            if isGenerating {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .background(Color.clear)
                        .frame(height: 60)
                    Text("Generating Task...")
                        .font(.body)
                        .foregroundColor(.primary)
                }
            } else if let task = task {
                Text(task.description).font(.body)

                HStack {
                    if task.easierAlternative != nil {
                        Button("Easier") {}
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    if task.harderAlternative != nil {
                        Button("Harder") {}
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    if task.easierAlternative != nil || task.harderAlternative != nil {
                        Button("Original") {}
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SuccessShareView: View {
    let task: HabitTaskDetails

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Success!").font(.title2).fontWeight(.bold)

            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct SuccessDoneView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Success!").font(.title2).fontWeight(.bold)

            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Come back tomorrow for the next task!")

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct MissedTaskView: View {
    let nextTaskDate: Date
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Task Missed").font(.title2).fontWeight(.bold)

            Image(systemName: "xmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(nextTaskMessage(for: nextTaskDate))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct FailedTaskView: View {
    let attemptsLeft: Int
    let onRetry: () -> Void
    let validation: TaskValidationResult?
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Task Failed").font(.title2).fontWeight(.bold)

            Image(systemName: "xmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("You've got \(attemptsLeft) attempts left.")

            if let validation = validation {
                OutlinedBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(validation.feedback ?? "Feedback not available").font(.body).foregroundColor(.red)
                        if let reasoning = validation.reasoning, !reasoning.isEmpty {
                            Text(reasoning).font(.footnote).foregroundColor(.secondary)
                        }
                    }
                }
            }

            Button {
                onRetry()
            } label: {
                Text("Try Again")
                    .frame(minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct FailedNoAttemptsView: View {
    let nextTaskDate: Date
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Task Failed").font(.title2).fontWeight(.bold)

            Image(systemName: "xmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("You've got 0 attempts left.")

            Text(nextTaskMessage(for: nextTaskDate))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct DismissableMissedTaskView: View {
    let nextTaskDate: Date
    let onDismiss: () -> Void
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            MissedTaskView(nextTaskDate: nextTaskDate)
            Spacer()
            Button(action: onDismiss) {
                Text("Next")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

struct DismissableFailedNoAttemptsView: View {
    let nextTaskDate: Date
    let onDismiss: () -> Void
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            FailedNoAttemptsView(nextTaskDate: nextTaskDate)
            Spacer()
            Button(action: onDismiss) {
                Text("Next")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

private func nextTaskMessage(for date: Date) -> String {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let next = calendar.startOfDay(for: date)
    let diff = calendar.dateComponents([.day], from: today, to: next).day ?? 0
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "EEEE, d MMMM"
    switch diff {
    case 1:
        return "Come back tomorrow for the task!"
    case 2:
        return "Come back the day after tomorrow!"
    case let d where d > 2:
        return "Come back on \(formatter.string(from: date))!"
    default:
        return "Come back soon!"
    }
}

#Preview("Generating Task") {
    HabitTaskSectionView(
        state: .generatingTask,
        isTaskInProgress: false,
        onSetMotivation: { _ in },
        onSetAbility: { _ in },
        onGenerateTask: { },
        onSubmitProof: { _, _, _ in },
        onRetry: { },
        onShowMotivationStep: { },
        viewModel: HabitViewModel()
    )
}

// Loader view to ensure post is loaded before showing ShareProofModalView
struct ShareProofModalSheetLoader: View {
    @ObservedObject var viewModel: HabitViewModel
    let todayTask: TaskEntry
    let proof: HabitProofState
    @State private var didLoad = false
    @State private var didShare = false

    var body: some View {
        Group {
            if viewModel.lastCreatedPost != nil || viewModel.autoCreatedPostId == nil {
                ShareProofModalView(
                    task: todayTask,
                    proof: proof,
                    post: viewModel.lastCreatedPost,
                    freshProofUrl: viewModel.freshProofUrl,
                    onShareSuccess: {
                        didShare = true
                        viewModel.currentTaskState = .successDone
                    },
                    closeFriendsCount: viewModel.closeFriendsCount
                )
                .presentationDetents([.large])
                .task(id: todayTask.id) {
                    await viewModel.fetchFreshProofUrl()
                }
            } else {
                ProgressView("Loading proof...")
                    .task {
                        if !didLoad {
                            didLoad = true
                            await viewModel.reloadLastCreatedPost()
                        }
                    }
            }
        }
    }
}
