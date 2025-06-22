import Foundation

struct OnboardingStep: Identifiable {
    var id = UUID()
    var title: String
    var subtitle: String
    let options: [String]?
}

let onboardingSteps: [OnboardingStep] = [
    .init(
        title: "What habit do you want to build?",
        subtitle: "e.g. Daily journaling, morning run",
        options: nil
    ),
    .init(
        title: "Habit task frequency?",
        subtitle: "Daily, every 2 days, weekly…",
        options: ["Daily", "Every other day", "Weekly", "Other"]
    ),
    .init(
        title: "Preferred validation/proof time?",
        subtitle: "Morning, afternoon, evening or pick a time",
        options: ["Morning", "Afternoon", "Evening", "Other"]
    ),
    .init(
        title: "Prefered task difficulty?",
        subtitle: "Easy, Medium, Hard",
        options: ["Easy", "Medium", "Hard"]
    ),
    .init(
        title: "Validation/proof style preference?",
        subtitle: "Photo, video, audio or text",
        options: ["Photo", "Video", "Audio", "Text"]
    ),
    .init(
        title: "Share your progress?",
        subtitle: "Would you like to share your progress with your friends?",
        options: ["Yes", "No"]
    )
]
