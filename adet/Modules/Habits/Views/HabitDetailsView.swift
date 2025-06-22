import SwiftUI

struct HabitDetailsView: View {
    @State var habit: Habit
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isDescriptionEditorFocused: Bool

    // To be replaced with a ViewModel
    private let apiService = APIService.shared

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
                        .font(.headline)
                    if !habit.description.isEmpty {
                        Text(habit.description)
                            .foregroundColor(.secondary)
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
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
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
        do {
            let updatedHabit = try await apiService.updateHabit(id: habit.id, data: habit)
            self.habit = updatedHabit
            isEditing = false
        } catch {
            // Handle error appropriately
            print("Failed to update habit: \(error.localizedDescription)")
        }
    }

    private func deleteHabit() async {
        do {
            try await apiService.deleteHabit(id: habit.id)
            dismiss()
        } catch {
            // Handle error appropriately
            print("Failed to delete habit: \(error.localizedDescription)")
        }
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

