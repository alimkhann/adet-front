import SwiftUI

struct AddHabitView: View {
    @EnvironmentObject var habitViewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newHabit = Habit(
        id: 0,
        userId: 0,
        name: "",
        description: "",
        frequency: "Daily",
        validationTime: "12:00 PM",
        difficulty: "Medium",
        proofStyle: "Photo",
        streak: 0
    )
    @FocusState private var isDescriptionEditorFocused: Bool

    private var isFormValid: Bool {
        !newHabit.name.isEmpty && !newHabit.description.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Info")) {
                    TextField("Habit Name", text: $newHabit.name)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $newHabit.description)
                            .frame(minHeight: 100)
                            .focused($isDescriptionEditorFocused)

                        if newHabit.description.isEmpty {
                            Text("Describe your habit and what your goal is...")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .onTapGesture {
                                    isDescriptionEditorFocused = true
                                }
                        }
                    }
                }

                Section(header: Text("Configuration")) {
                    HabitWeekdayPicker(frequency: $newHabit.frequency)
                        .padding(.bottom, 8)

                    VStack {
                        HStack {
                            Text("Validation Time")

                            Spacer()
                        }

                        HabitTimePicker(validationTime: $newHabit.validationTime)
                    }
                    .padding(.bottom, 8)

                    VStack {
                        HStack {
                            Text("Difficulty")

                            Spacer()
                        }

                        HabitDifficultyPicker(difficulty: $newHabit.difficulty)
                    }
                    .padding(.bottom, 8)

                    VStack {
                        HStack {
                            Text("Proof Style")

                            Spacer()
                        }

                        HabitProofStylePicker(proofStyle: $newHabit.proofStyle)
                    }
                }
            }
            .navigationTitle("Add New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveHabit()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveHabit() async {
        await habitViewModel.createHabit(newHabit)
        dismiss()
    }
}

#Preview {
    AddHabitView()
        .environmentObject(HabitViewModel())
}
