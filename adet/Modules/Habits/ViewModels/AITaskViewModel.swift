import Foundation
import Combine
import SwiftUI

@MainActor
class AITaskViewModel: ObservableObject {
    private let aiTaskService: AITaskService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    @Published var currentTask: TaskEntry?
    @Published var pendingTasks: [TaskEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var successMessage = ""

    // MARK: - Task Generation State
    @Published var isGeneratingTask = false
    @Published var selectedMotivationLevel = "medium"
    @Published var selectedAbilityLevel = "medium"

    // MARK: - Proof Submission State
    @Published var isSubmittingProof = false
    @Published var selectedProofType: TaskProofType = .text
    @Published var proofContent = ""
    @Published var showProofSubmission = false

    // MARK: - Performance Analysis
    @Published var performanceAnalysis: PerformanceAnalysis?
    @Published var improvementSuggestions: ImprovementSuggestions?
    @Published var isLoadingAnalysis = false

    init(aiTaskService: AITaskService = AITaskService()) {
        self.aiTaskService = aiTaskService
    }

    // MARK: - Task Generation

    func generateTaskForHabit(_ habit: Habit) {
        guard !isGeneratingTask else { return }

        isGeneratingTask = true
        errorMessage = nil

        Task {
            do {
                let response = try await aiTaskService.generateTaskForHabit(habit, motivationLevel: selectedMotivationLevel, abilityLevel: selectedAbilityLevel)
                await MainActor.run {
                    self.currentTask = response.task
                    self.showSuccess = true
                    self.successMessage = "Task generated successfully! 🎉"
                    self.isGeneratingTask = false
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                    self.isGeneratingTask = false
                }
            }
        }
    }

    func checkTodayTask(for habit: Habit) async throws -> TaskEntry? {
        return try await aiTaskService.checkTodayTask(for: habit)
    }

    // MARK: - Task Management

    func loadPendingTasks() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let tasks = try await aiTaskService.getPendingTasks()
                await MainActor.run {
                    self.pendingTasks = tasks
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                    self.isLoading = false
                }
            }
        }
    }

    func submitTaskProof() {
        guard let task = currentTask, !proofContent.isEmpty else {
            errorMessage = "Please provide proof content"
            showError = true
            return
        }

        isSubmittingProof = true
        errorMessage = nil

        let proof = TaskProofSubmissionData(proof_type: selectedProofType.rawValue, proof_content: proofContent)

        Task {
            do {
                let response = try await aiTaskService.submitTaskProof(taskId: task.id, proof: proof)
                await MainActor.run {
                    self.currentTask = response.task
                    self.proofContent = ""
                    self.showProofSubmission = false
                    self.showSuccess = true
                    self.successMessage = response.message
                    self.isSubmittingProof = false
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                    self.isSubmittingProof = false
                }
            }
        }
    }

    func updateTaskStatus(_ status: TaskStatus) {
        guard let task = currentTask else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await aiTaskService.updateTaskStatus(taskId: task.id, status: status)
                await MainActor.run {
                    self.currentTask = response.task
                    self.showSuccess = true
                    self.successMessage = response.message
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Performance Analysis

    func analyzePerformance(for habitId: Int) {
        isLoadingAnalysis = true
        errorMessage = nil

        Task {
            do {
                let response = try await aiTaskService.analyzePerformance(for: habitId)
                await MainActor.run {
                    if response.success, let data = response.data {
                        self.performanceAnalysis = data
                    } else {
                        self.errorMessage = response.error ?? "Failed to analyze performance"
                        self.showError = true
                    }
                    self.isLoadingAnalysis = false
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                    self.isLoadingAnalysis = false
                }
            }
        }
    }

    func getImprovementSuggestions(for habitId: Int) {
        isLoadingAnalysis = true
        errorMessage = nil

        Task {
            do {
                let response = try await aiTaskService.getImprovementSuggestions(for: habitId)
                await MainActor.run {
                    if response.success, let data = response.data {
                        self.improvementSuggestions = data
                    } else {
                        self.errorMessage = response.error ?? "Failed to get suggestions"
                        self.showError = true
                    }
                    self.isLoadingAnalysis = false
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                    self.isLoadingAnalysis = false
                }
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .requestFailed(let statusCode, let body):
                switch statusCode {
                case 404:
                    errorMessage = "Task not found"
                case 400:
                    errorMessage = body ?? "Invalid request"
                case 500:
                    errorMessage = "Server error. Please try again."
                default:
                    errorMessage = "Network request failed with status code: \(statusCode)"
                }
            case .unauthorized:
                errorMessage = "User is not authenticated"
            case .timeout:
                errorMessage = "Request timed out. Please try again."
            case .connectionLost, .noInternet:
                errorMessage = "Network error. Check your connection."
            case .decodeError:
                errorMessage = "Data format error"
            case .invalidURL:
                errorMessage = "Invalid URL"
            case .unknown:
                errorMessage = "An unknown error occurred"
            }
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }

    // MARK: - Helper Methods

    func resetState() {
        currentTask = nil
        pendingTasks = []
        errorMessage = nil
        showError = false
        showSuccess = false
        successMessage = ""
        proofContent = ""
        showProofSubmission = false
    }

    func formatDifficulty(_ difficulty: Double) -> String {
        switch difficulty {
        case 0.5...1.0:
            return "Ultra-Tiny"
        case 1.0...1.5:
            return "Tiny"
        case 1.5...2.0:
            return "Small"
        case 2.0...2.5:
            return "Medium"
        case 2.5...3.0:
            return "Hard"
        default:
            return "Unknown"
        }
    }

    func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }

    func getStatusColor(_ status: String) -> Color {
        guard let taskStatus = TaskStatus(rawValue: status) else {
            return .gray
        }

        switch taskStatus {
        case .pending:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .missed:
            return .gray
        case .pendingReview:
            return .blue
        }
    }
}