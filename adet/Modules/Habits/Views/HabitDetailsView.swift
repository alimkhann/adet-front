import SwiftUI

struct HabitDetailsView: View {
    @State var habit: Habit
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    // To be replaced with a ViewModel
    private let apiService = APIService.shared

    var body: some View {
        Form {
            Section(header: Text("Habit Info")) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Habit Name", text: $habit.name)
                            .textFieldStyle(.roundedBorder)

                        TextEditor(text: Binding($habit.description, replacingNilWith: ""))
                            .frame(height: 100)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                    }
                } else {
                    Text(habit.name)
                        .font(.headline)
                    if let description = habit.description, !description.isEmpty {
                        Text(description)
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

// Binding extension to handle optional strings in TextFields
extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith nilValue: String) {
        self.init(
            get: { source.wrappedValue ?? nilValue },
            set: { newValue in
                if newValue == nilValue {
                    source.wrappedValue = nil
                } else {
                    source.wrappedValue = newValue
                }
            }
        )
    }
}
