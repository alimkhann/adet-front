import SwiftUI

struct HabitDetailsView: View {
    @State var habit: Habit
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isDescriptionEditorFocused: Bool
    @EnvironmentObject var habitViewModel: HabitViewModel

    var body: some View {
        Form {
            Section(header: Text("Habit Info")) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Habit Name", text: $habit.name)
                            .textFieldStyle(.roundedBorder)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $habit.description)
                                .frame(minHeight: 100)
                                .focused($isDescriptionEditorFocused)
                                .padding(.top, 4)
                                .padding(.leading, 4)

                            if habit.description.isEmpty {
                                Text("Describe your habit and what your goal is...")
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .onTapGesture {
                                        isDescriptionEditorFocused = true
                                    }
                            }
                        }
                        .padding(EdgeInsets(top: -4, leading: -4, bottom: -4, trailing: -4))
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                        )
                    }
                } else {
                    Text(habit.name)
                    if !habit.description.isEmpty {
                        Text(habit.description)
                    }
                }
            }

            Section(header: Text("Configuration")) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 10) {
                        HabitWeekdayPicker(frequency: $habit.frequency)
                            .padding(.bottom, 8)

                        VStack {
                            HStack {
                                Text("Validation Time")

                                Spacer()
                            }

                            HabitTimePicker(validationTime: $habit.validationTime)
                        }
                        .padding(.bottom, 8)

                        VStack {
                            HStack {
                                Text("Difficulty")

                                Spacer()
                            }

                            HabitDifficultyPicker(difficulty: $habit.difficulty)
                        }
                        .padding(.bottom, 8)

                        VStack {
                            HStack {
                                Text("Proof Style")

                                Spacer()
                            }

                            HabitProofStylePicker(proofStyle: $habit.proofStyle)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    DetailRow(title: "Frequency", value: habit.frequency)
                    DetailRow(title: "Validation Time", value: habit.validationTime)
                    DetailRow(title: "Difficulty", value: habit.difficulty)
                    DetailRow(title: "Proof Style", value: habit.proofStyle)
                }
            }

            if !isEditing {
                Section(header: Text("Stats")) {
                    DetailRow(title: "Current Streak", value: "\(habit.streak) days")
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Habit" : "Habit Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        // TODO: Reset changes if any
                        isEditing = false
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        Task {
                            await saveHabit()
                        }
                    }
                } else {
                    Button {
                        isEditing = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isEditing {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        if habitViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(habitViewModel.isLoading)
                }
            }
        }
        .alert("Delete Habit", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteHabit()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(habit.name)'? This action cannot be undone.")
        }
        .navigationBarBackButtonHidden(isEditing)
    }

    private func saveHabit() async {
        if let updatedHabit = await habitViewModel.updateHabit(habit) {
            self.habit = updatedHabit
            isEditing = false
        }
    }

    private func deleteHabit() async {
        await habitViewModel.deleteHabit(habit)

        // Show appropriate feedback based on the result
        if let errorMessage = habitViewModel.errorMessage {
            ToastManager.shared.showError(errorMessage)
        } else {
            ToastManager.shared.showSuccess("Habit deleted successfully")
        }

        dismiss()
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

