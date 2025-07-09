import SwiftUI
import PhotosUI

struct TaskCardContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(colorScheme == .dark ? .black : .white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            .padding(.horizontal)
    }
}

struct ProofCardContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(colorScheme == .dark ? Color(.systemGray5) : .white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            .padding(.horizontal)
    }
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

            case .waitingForValidationTime(let timeLeft, _, _):
                TaskCardContainer {
                    WaitingForValidationTimeView(
                        timeLeft: timeLeft,
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
                    VStack(spacing: 32) {
                        WaitingForValidationTimeView(
                            timeLeft: viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime).timeIntervalSince(Date()) } ?? 0,
                            viewModel: viewModel,
                            onValidationTimeArrived: {
                                Task { await viewModel.updateTaskStateAsync() }
                            }
                        )
                        MotivationStepperView(current: viewModel.todayMotivation?.level, onSet: onSetMotivation, onBack: onRetry)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .setAbility:
                TaskCardContainer {
                    VStack(spacing: 32) {
                        WaitingForValidationTimeView(
                            timeLeft: viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime).timeIntervalSince(Date()) } ?? 0,
                            viewModel: viewModel,
                            onValidationTimeArrived: {
                                Task { await viewModel.updateTaskStateAsync() }
                            }
                        )
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
                                CapsuleChip(
                                    label: "Motivation:",
                                    value: viewModel.todayMotivation != nil ? (viewModel.todayMotivation?.level.capitalized ?? "") : "Not set",
                                    color: chipColor(for: viewModel.todayMotivation?.level, isMotivation: true),
                                    textColor: chipTextColor(for: viewModel.todayMotivation?.level)
                                )
                                .frame(maxWidth: .infinity)

                                CapsuleChip(
                                    label: "Ability:",
                                    value: viewModel.todayAbility != nil ? (viewModel.todayAbility?.level.capitalized ?? "") : "Not set",
                                    color: chipColor(for: viewModel.todayAbility?.level, isMotivation: false),
                                    textColor: chipTextColor(for: viewModel.todayAbility?.level)
                                )
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
                                    CapsuleChipVertical (
                                        label: "Motivation:",
                                        value: viewModel.todayMotivation?.level.capitalized ?? "",
                                        color: chipColor(for: viewModel.todayMotivation?.level, isMotivation: true),
                                        textColor: chipTextColor(for: viewModel.todayMotivation?.level)
                                    )
                                    CapsuleChipVertical (
                                        label: "Ability:",
                                        value: viewModel.todayAbility?.level.capitalized ?? "",
                                        color: chipColor(for: viewModel.todayAbility?.level, isMotivation: false),
                                        textColor: chipTextColor(for: viewModel.todayAbility?.level)
                                    )
                                }
                            }
                            .padding(.bottom, 8)
                            OutlinedBox {
                                TypingText(text: "Generating your task", animatedDots: true)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    ProofCardContainer {
                        ProofSectionView(
                            proof: .notStarted,
                            onSubmitProof: onSubmitProof,
                            isGenerating: true,
                            validationTime: viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime) }
                        )
                        .environmentObject(viewModel)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.vertical)

            case .showTask(let task, let proof):
                VStack(spacing: 16) {
                    TaskCardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                Text("Today's Task")
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 8) {
                                    CapsuleChipVertical(
                                        label: "Motivation",
                                        value: task.motivation.capitalized,
                                        color: chipColor(for: task.motivation, isMotivation: true),
                                        textColor: chipTextColor(for: task.motivation)
                                    )
                                    CapsuleChipVertical(
                                        label: "Ability",
                                        value: task.ability.capitalized,
                                        color: chipColor(for: task.ability, isMotivation: false),
                                        textColor: chipTextColor(for: task.ability)
                                    )
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
                        ProofSectionView(
                            proof: proof,
                            onSubmitProof: { _, _, _ in showProofModal = true },
                            isGenerating: false,
                            validationTime: viewModel.selectedHabit.map { viewModel.parseValidationTime($0.validationTime) }
                        )
                        .environmentObject(viewModel)
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
                        instruction: currentTaskDescription ?? task.description,
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
                        Button(action: { showShareModal = true }) {
                            Text("Share With Friends")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical)
                .sheet(isPresented: $showShareModal) {
                    ShareProofModalView(task: task, proof: proof, onShare: { visibility, description, proofInputType, textProof in
                        Task {
                            await viewModel.shareProof(
                                visibility: visibility,
                                description: description,
                                task: task,
                                proof: proof,
                                proofInputType: proofInputType,
                                textProof: textProof
                            )
                            showShareModal = false
                            if visibility == "Friends" || visibility == "Close Friends" {
                                await MainActor.run {
                                    viewModel.currentTaskState = .successDone
                                }
                            }
                        }
                    })
                    .presentationDetents([.fraction(0.65), .large])
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
                TaskCardContainer { FailedTaskView(attemptsLeft: attemptsLeft, onRetry: onRetry) }
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

            case .needMotivationAbility:
                TaskCardContainer { Text("Please set your motivation and ability levels.") }
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

struct CapsuleChip: View {
    let label: String
    let value: String
    let color: Color
    let textColor: Color
    var body: some View {
        VStack(spacing: 0) {
            Text("\(label) \(value)")
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
        }
        .background(color)
        .foregroundColor(textColor)
        .clipShape(Capsule())
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct CapsuleChipVertical: View {
    let label: String
    let value: String
    let color: Color
    let textColor: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(textColor)

            Text(value)
                .font(.subheadline)
                .foregroundColor(textColor)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .background(color)
        .clipShape(Capsule())
        .fixedSize()
    }
}

public struct WaitingForValidationTimeView: View {
    public let timeLeft: TimeInterval
    @ObservedObject public var viewModel: HabitViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var now: Date = Date()
    private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    public var onValidationTimeArrived: (() -> Void)? = nil

    public init(timeLeft: TimeInterval, viewModel: HabitViewModel, onValidationTimeArrived: (() -> Void)? = nil) {
        self.timeLeft = timeLeft
        self._viewModel = ObservedObject(initialValue: viewModel)
        self.onValidationTimeArrived = onValidationTimeArrived
    }

    private var computedTimeLeft: TimeInterval {
        // Recompute time left based on now
        if let habit = viewModel.selectedHabit {
            let validationTime = viewModel.parseValidationTime(habit.validationTime)
            return max(0, validationTime.timeIntervalSince(now))
        }
        return max(0, timeLeft)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Task")
                .font(.headline)

            HStack {
                Image(systemName: "clock")
                let hours = Int(computedTimeLeft / 3600)
                let minutes = Int(computedTimeLeft.truncatingRemainder(dividingBy: 3600) / 60)
                Text("\(hours)h \(minutes)m left")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Text("It's not the time yet but let's set your motivation & ability levels in advance.")
                .font(.body)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                CapsuleChip(
                    label: "Motivation:",
                    value: viewModel.todayMotivation != nil ? (viewModel.todayMotivation?.level.capitalized ?? "") : "Not set",
                    color: chipColor(for: viewModel.todayMotivation?.level, isMotivation: true),
                    textColor: chipTextColor(for: viewModel.todayMotivation?.level)
                )

                CapsuleChip(
                    label: "Ability:",
                    value: viewModel.todayAbility != nil ? (viewModel.todayAbility?.level.capitalized ?? "") : "Not set",
                    color: chipColor(for: viewModel.todayAbility?.level, isMotivation: false),
                    textColor: chipTextColor(for: viewModel.todayAbility?.level)
                )
            }
            .padding(.vertical)
            .onReceive(timer) { _ in
                now = Date()
                if computedTimeLeft <= 0 {
                    onValidationTimeArrived?()
                }
            }
            .onAppear { now = Date() }

            if viewModel.todayMotivation != nil && viewModel.todayAbility != nil {
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

struct MotivationStepperView: View {
    let current: String?
    let onSet: (String) -> Void
    let onBack: () -> Void
    @State private var selected: String? = nil
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("How motivated are you?")
                .font(.headline)

            ForEach(["low", "medium", "high"], id: \.self) { level in
                Button(action: { selected = level }) {
                    Text(level.capitalized)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background((selected ?? current)?.lowercased() == level ? Color.black : .white)
                        .foregroundColor((selected ?? current)?.lowercased() == level ? .white : .primary)
                        .cornerRadius(10)
                }
            }

            Spacer()

            HStack {
                Button {
                    if let c = selected ?? current {
                        onSet(c.lowercased())
                    }
                } label: {
                    Text("Set Motivation")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((selected ?? current) == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct AbilityStepperView: View {
    let current: String?
    let onSet: (String) -> Void
    let onBack: () -> Void
    @State private var selected: String? = nil
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("How able are you to do this?").font(.headline)

            ForEach(["hard", "medium", "easy"], id: \.self) { level in
                Button(action: { selected = level }) {
                    Text(level.capitalized)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background((selected ?? current)?.lowercased() == level ? Color.black : .white)
                        .foregroundColor((selected ?? current)?.lowercased() == level ? .white : .primary)
                        .cornerRadius(10)
                }
            }

            Spacer()

            HStack {
                Button(action: onBack) {
                    Text("Back")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    if let c = selected ?? current {
                        onSet(c.lowercased())
                    }
                } label: {
                    Text("Set Ability")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((selected ?? current) == nil)
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
                CapsuleChip(
                    label: "Motivation:",
                    value: viewModel.todayMotivation != nil ? (viewModel.todayMotivation?.level.capitalized ?? "") : "Not set",
                    color: chipColor(for: viewModel.todayMotivation?.level, isMotivation: true),
                    textColor: chipTextColor(for: viewModel.todayMotivation?.level)
                )

                CapsuleChip(
                    label: "Ability:",
                    value: viewModel.todayAbility != nil ? (viewModel.todayAbility?.level.capitalized ?? "") : "Not set",
                    color: chipColor(for: viewModel.todayAbility?.level, isMotivation: false),
                    textColor: chipTextColor(for: viewModel.todayAbility?.level)
                )
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

public struct ProofSectionView: View {
    let proof: HabitProofState
    let onSubmitProof: (ProofInputType, Data?, String?) -> Void
    let isGenerating: Bool
    let validationTime: Date?
    @EnvironmentObject var viewModel: HabitViewModel
    @State private var now: Date = Date()
    private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    public init(
        proof: HabitProofState,
        onSubmitProof: @escaping (ProofInputType, Data?, String?) -> Void,
        isGenerating: Bool,
        validationTime: Date?
    ) {
        self.proof = proof
        self.onSubmitProof = onSubmitProof
        self.isGenerating = isGenerating
        self.validationTime = validationTime
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proof").font(.headline)
            if let validationTime = validationTime, viewModel.currentTaskState.isShowTask {
                ProofWindowTimerView(validationTime: validationTime)
            }
            if isGenerating {
                OutlinedBox {
                    TypingText(text: "Generating Proof", animatedDots: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                switch proof {
                case .notStarted:
                    OutlinedBox {
                        TypingText(text: viewModel.todayTask?.proofRequirements ?? "")
                            .id(viewModel.typingTextProofKey)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    Button(action: { onSubmitProof(.photo, nil, nil) }) {
                        Text("Submit Proof")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                default:
                    Text("Proof not started")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

            Text("You've done a great job!")
                .padding(.bottom)

            Text("Note: You should share with your friends or close friends for your streak to grow. If not, then the streak will stay the same and the post will be saved to your own profile and you can share it later.")
                .font(.callout)
                .foregroundStyle(.secondary)

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
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Task Failed").font(.title2).fontWeight(.bold)

            Image(systemName: "xmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("You've got \(attemptsLeft) attempts left.")

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

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Error").font(.title2).fontWeight(.bold).foregroundColor(.red)

            Text(message).multilineTextAlignment(.center)

            Button {
                onRetry()
            } label: {
                Text("Retry")
                    .frame(minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public func chipColor(for value: String?, isMotivation: Bool) -> Color {
    guard let value = value?.lowercased() else { return Color.gray.opacity(0.2) }
    if isMotivation {
        switch value {
        case "high": return .green
        case "medium": return .yellow
        case "low": return .red
        default: return Color.gray.opacity(0.2)
        }
    } else {
        switch value {
        case "easy": return .green
        case "medium": return .yellow
        case "hard": return .red
        default: return Color.gray.opacity(0.2)
        }
    }
}

public func chipTextColor(for value: String?) -> Color {
    guard let value = value?.lowercased() else { return .secondary }
    switch value {
    case "high", "easy": return .white
    case "medium": return .black
    case "low", "hard": return .white
    default: return .secondary
    }
}

struct OutlinedBox<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        HStack(alignment: .top) {
            content
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.4), lineWidth: 2)
        )
    }
}

private func proofInputType(from requirements: String) -> ProofInputType {
    let lower = requirements.lowercased()
    if lower.contains("photo") { return .photo }
    if lower.contains("video") { return .video }
    if lower.contains("audio") { return .audio }
    if lower.contains("text") { return .text }
    return .photo // default fallback
}

struct ProofWindowTimerView: View {
    public let validationTime: Date
    @State private var now: Date = Date()
    private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    public init(validationTime: Date) {
        self.validationTime = validationTime
    }

    var body: some View {
        let endTime = validationTime.addingTimeInterval(4 * 3600)
        let timeLeft = max(0, endTime.timeIntervalSince(now))
        let hours = Int(timeLeft) / 3600
        let minutes = (Int(timeLeft) % 3600) / 60
        HStack {
            Image(systemName: "clock")
            Text(String(format: "%02dh %02dm left", hours, minutes))
        }
        .onReceive(timer) { _ in now = Date() }
        .onAppear { now = Date() }
    }
}

// Add HabitTaskState extension for isShowTask
extension HabitTaskState {
    var isShowTask: Bool {
        if case .showTask = self { return true }
        return false
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

struct GeneratingTaskView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            TypingText(
                text: "Generating your task...",
                animatedDots: true,
                typingSpeed: 0.05
            )
            .font(.title2)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TaskGenerationErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Generation Failed")
                .font(.title2)
                .fontWeight(.semibold)
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//#Preview {
//    HabitTaskSectionView(
//        state: .successShare(
//            task:
//                HabitTaskDetails(
//                    description: "crazy habit",
//                    easierAlternative: "easy",
//                    harderAlternative: "hard",
//                    motivation: "high",
//                    ability: "easy",
//                    timeLeft: TimeInterval(0)
//                ),
//            proof:
//                .submitted
//        ),
//        isTaskInProgress: false,
//        onSetMotivation: { _ in },
//        onSetAbility: { _ in },
//        onGenerateTask: { },
//        onSubmitProof: { _, _, _ in },
//        onRetry: { },
//        onShowMotivationStep: { },
//        viewModel: HabitViewModel()
//    )
//}

//#Preview("Generating Task") {
//    HabitTaskSectionView(
//        state: .successDone,
//        isTaskInProgress: false,
//        onSetMotivation: { _ in },
//        onSetAbility: { _ in },
//        onGenerateTask: { },
//        onSubmitProof: { _, _, _ in },
//        onRetry: { },
//        onShowMotivationStep: { },
//        viewModel: HabitViewModel()
//    )
//}

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
