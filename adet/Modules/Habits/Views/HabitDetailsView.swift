import SwiftUI

struct HabitDetailsView: View {
    @State var habit: Habit // Use @State to make it mutable for editing
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    // To be replaced with a ViewModel
    private let apiService = APIService.shared

    var body: some View {
        Form {
            Section(header: Text("Habit Info")) {
                if isEditing {
                    TextField("Habit Name", text: $habit.name)
                    TextField("Description", text: Binding($habit.description, replacingNilWith: ""))
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
                    // Replace with proper pickers later
                    TextField("Frequency", text: $habit.frequency)
                    TextField("Validation Time", text: $habit.validationTime)
                    TextField("Difficulty", text: $habit.difficulty)
                    TextField("Proof Style", text: $habit.proofStyle)
                } else {
                    DetailRow(title: "Frequency", value: habit.frequency)
                    DetailRow(title: "Validation Time", value: habit.validationTime)
                    DetailRow(title: "Difficulty", value: habit.difficulty)
                    DetailRow(title: "Proof Style", value: habit.proofStyle)
                }
            }

            Section(header: Text("Stats")) {
                DetailRow(title: "Current Streak", value: "\(habit.streak) days")
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
