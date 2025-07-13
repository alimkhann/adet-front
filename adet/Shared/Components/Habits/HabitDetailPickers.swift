import SwiftUI

// MARK: - Enhanced Weekday Picker for Habit Details
struct HabitWeekdayPicker: View {
    @Binding var frequency: String
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDays: [Bool] = Array(repeating: false, count: 7)
    @State private var frequencyType: FrequencyType = .custom

    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    private let fullWeekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    enum FrequencyType: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case everyOtherDay = "Alt. Days"
        case weekdays = "Weekdays"
        case weekends = "Weekends"
        case custom = "Custom"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Frequency Type Picker
            Picker("Frequency", selection: $frequencyType) {
                ForEach(FrequencyType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: frequencyType) { _, newValue in
                updateDaysForFrequencyType(newValue)
            }

            // Weekday Picker
            HStack {
                ForEach(0..<7, id: \.self) { index in
                    Button(action: {
                        selectedDays[index].toggle()
                        frequencyType = .custom // Set to custom on manual toggle
                        updateFrequency()
                    }) {
                        VStack(spacing: 4) {
                            Text(weekdays[index])
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 32, height: 32)
                                .foregroundColor(selectedDays[index] ? (colorScheme == .dark ? .black : .white) : .primary)
                                .background(
                                    Circle()
                                        .fill(selectedDays[index] ? Color.primary : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                                )

                            Text(fullWeekdays[index])
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .onAppear(perform: parseCurrentFrequency)
        }
    }

    private func updateDaysForFrequencyType(_ type: FrequencyType) {
        switch type {
        case .daily:
            selectedDays = Array(repeating: true, count: 7)
        case .weekly:
            // Select today's weekday
            let today = Calendar.current.component(.weekday, from: Date())
            let adjustedIndex = (today + 5) % 7 // Convert Sunday=1 to Monday=0
            selectedDays = Array(repeating: false, count: 7)
            selectedDays[adjustedIndex] = true
        case .everyOtherDay:
            // Start from today and select every other day
            let today = Calendar.current.component(.weekday, from: Date())
            let adjustedIndex = (today + 5) % 7
            selectedDays = Array(repeating: false, count: 7)
            for i in stride(from: adjustedIndex, to: 7, by: 2) {
                selectedDays[i] = true
            }
            for i in stride(from: adjustedIndex - 2, through: 0, by: -2) {
                selectedDays[i] = true
            }
        case .weekdays:
            selectedDays = [true, true, true, true, true, false, false]
        case .weekends:
            selectedDays = [false, false, false, false, false, true, true]
        case .custom:
            // Keep current selection
            break
        }
        updateFrequency()
    }

    private func updateFrequency() {
        let selected = selectedDays.indices.filter { selectedDays[$0] }.map { fullWeekdays[$0] }

        if selected.isEmpty {
            frequency = ""
        } else if selected.count == 7 {
            frequency = "Every day"
        } else if selected == ["Sat", "Sun"] {
            frequency = "Weekends"
        } else if selected == ["Mon", "Tue", "Wed", "Thu", "Fri"] {
            frequency = "Weekdays"
        } else {
            frequency = selected.joined(separator: ", ")
        }
    }

    private func parseCurrentFrequency() {
        let components = frequency.components(separatedBy: ", ")

        // Determine frequency type
        if frequency == "Every day" {
            frequencyType = .daily
        } else if frequency == "Weekends" {
            frequencyType = .weekends
        } else if frequency == "Weekdays" {
            frequencyType = .weekdays
        } else if components.count == 1 && components[0].contains("Weekly") {
            frequencyType = .weekly
        } else if components.count >= 3 && components.count <= 4 {
            // Check if it's every other day pattern
            let selectedIndices = components.compactMap { day in
                fullWeekdays.firstIndex(of: day)
            }
            if isEveryOtherDayPattern(selectedIndices) {
                frequencyType = .everyOtherDay
            } else {
                frequencyType = .custom
            }
        } else {
            frequencyType = .custom
        }

        // Update selected days
        selectedDays = Array(repeating: false, count: 7)
        for (index, day) in fullWeekdays.enumerated() {
            if components.contains(day) {
                selectedDays[index] = true
            }
        }
    }

    private func isEveryOtherDayPattern(_ indices: [Int]) -> Bool {
        guard indices.count >= 3 else { return false }
        let sorted = indices.sorted()
        for i in 1..<sorted.count {
            if sorted[i] - sorted[i-1] != 2 {
                return false
            }
        }
        return true
    }
}

// MARK: - Enhanced Time Picker for Habit Details
struct HabitTimePicker: View {
    @Binding var validationTime: String
    @State private var selectedTime = Date()

    var body: some View {
        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 120)
            .clipped()
            .onChange(of: selectedTime) { _, _ in
                updateValidationTime()
            }
            .onAppear(perform: parseCurrentTime)
    }

    private func updateValidationTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        validationTime = formatter.string(from: selectedTime)
    }

    private func parseCurrentTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if let time = formatter.date(from: validationTime) {
            selectedTime = time
        } else {
            // Default to current time if parsing fails
            updateValidationTime()
        }
    }
}

// MARK: - Difficulty Picker
struct HabitDifficultyPicker: View {
    @Binding var difficulty: String

    private let difficulties = ["Easy", "Medium", "Hard"]

    var body: some View {
        Picker("Difficulty", selection: $difficulty) {
            ForEach(difficulties, id: \.self) { diff in
                Text(diff).tag(diff)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Proof Style Picker
struct HabitProofStylePicker: View {
    @Binding var proofStyle: String

    private let allowedStyles = ["Photo", "Text"]
    private let proofStyles = ["Photo", "Video (Coming soon)", "Audio (Coming soon)", "Text"]

    var body: some View {
        Picker("Proof Style", selection: Binding(
            get: { proofStyle },
            set: { newValue in
                // Only allow valid selections
                if allowedStyles.contains(newValue) {
                    proofStyle = newValue
                }
            }
        )) {
            Text("Photo").tag("Photo")
            Text("Video").tag("Video")
            Text("Audio").tag("Audio")
            Text("Text").tag("Text")
        }
        .pickerStyle(.segmented)
    }
}
