import Foundation
import Clerk
import OSLog

// MARK: - Motivation & Ability Tracking (move these to file scope)

actor APIService {
    static let shared = APIService()
    private let networkService = NetworkService.shared
    private let logger = Logger(subsystem: "com.adet.api", category: "APIService")

    private init() {}

    // MARK: - User API Operations

    /// Fetches the backend health status.
    func healthCheck() async throws -> HealthResponse {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/health", method: "GET", body: (nil as String?))
    }

    /// Fetches the currently authenticated user's data.
    func getCurrentUser() async throws -> User {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me", method: "GET", body: (nil as String?))
    }

    /// Syncs user data from Clerk to update email and profile information.
    func syncUserFromClerk() async throws -> User {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me/sync", method: "POST", body: (nil as String?))
    }

    /// Updates the user's username.
    func updateUsername(_ username: String) async throws {
        let requestBody = UsernameUpdateRequest(username: username)
        let _: EmptyResponse = try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me/username", method: "PATCH", body: requestBody)
    }

    /// Deletes the user's account from the backend.
    func deleteAccount() async throws {
        try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me", method: "DELETE")
    }

    /// Uploads a profile image for the user.
    func uploadProfileImage(_ imageData: Data, fileName: String, mimeType: String) async throws -> User {
        return try await networkService.uploadFile(
            endpoint: "/api/v1/users/me/profile-image",
            fileData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "file"
        )
    }

    /// Updates the user's profile image URL.
    func updateProfileImageUrl(_ imageUrl: String) async throws -> User {
        let requestBody = ProfileImageUpdateRequest(profileImageUrl: imageUrl)
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me/profile-image", method: "PATCH", body: requestBody)
    }

    /// Deletes the user's profile image.
    func deleteProfileImage() async throws -> User {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me/profile-image", method: "DELETE", body: (nil as String?))
    }

    /// Submits the user's onboarding answers.
    func submitOnboarding(answers: OnboardingAnswers) async throws {
        let _: OnboardingAnswer = try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/onboarding/", method: "POST", body: answers)
    }

    /// Fetches the user's onboarding answers.
    func getOnboardingAnswers() async throws -> OnboardingAnswer {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/onboarding/", method: "GET", body: (nil as String?))
    }

    /// Tests network connectivity to the backend
    func testConnectivity() async throws -> Bool {
        do {
            let _: HealthResponse = try await networkService.makeAuthenticatedRequest(endpoint: "/health", method: "GET", body: (nil as String?))
            return true
        } catch {
            logger.error("API connectivity test failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Habit API Operations

    func fetchHabits() async throws -> [Habit] {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/habits/", method: "GET", body: (nil as String?))
    }

    func createHabit(_ habit: Habit) async throws -> Habit {
        let requestBody = HabitCreateRequest(
            name: habit.name,
            description: habit.description,
            frequency: habit.frequency,
            validationTime: habit.validationTime,
            difficulty: habit.difficulty,
            proofStyle: habit.proofStyle
        )
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/",
            method: "POST",
            body: requestBody
        )
    }

    func createHabit(from onboardingAnswer: OnboardingAnswer) async throws -> Habit {
        let requestBody = HabitCreateRequest(
            name: onboardingAnswer.habit_name,
            description: onboardingAnswer.habit_description,
            frequency: onboardingAnswer.frequency,
            validationTime: onboardingAnswer.validation_time,
            difficulty: onboardingAnswer.difficulty,
            proofStyle: onboardingAnswer.proof_style
        )
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/",
            method: "POST",
            body: requestBody
        )
    }

    func updateHabit(id: Int, data: Habit) async throws -> Habit {
        let requestBody = HabitCreateRequest(
            name: data.name,
            description: data.description,
            frequency: data.frequency,
            validationTime: data.validationTime,
            difficulty: data.difficulty,
            proofStyle: data.proofStyle
        )
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(id)",
            method: "PUT",
            body: requestBody
        )
    }

    func deleteHabit(id: Int) async throws {
        let _: EmptyResponse = try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(id)",
            method: "DELETE",
            body: (nil as String?)
        )
    }

    // MARK: - Motivation & Ability API Operations

    func submitMotivationEntry(habitId: Int, date: String, level: String) async throws -> MotivationEntryResponse {
        let req = MotivationEntryRequest(habit_id: habitId, date: date, level: level)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/motivation",
            method: "POST",
            body: req
        )
    }

    func getTodayMotivationEntry(habitId: Int, userDate: String? = nil) async throws -> MotivationEntryResponse {
        var endpoint = "/api/v1/habits/\(habitId)/motivation/today"
        if let userDate = userDate {
            endpoint += "?user_date=\(userDate)"
        }
        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    func submitAbilityEntry(habitId: Int, date: String, level: String) async throws -> AbilityEntryResponse {
        let req = AbilityEntryRequest(habit_id: habitId, date: date, level: level)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/ability",
            method: "POST",
            body: req
        )
    }

    func getTodayAbilityEntry(habitId: Int, userDate: String? = nil) async throws -> AbilityEntryResponse {
        var endpoint = "/api/v1/habits/\(habitId)/ability/today"
        if let userDate = userDate {
            endpoint += "?user_date=\(userDate)"
        }
        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    func updateMotivationEntry(habitId: Int, date: String, level: String) async throws -> MotivationEntryResponse {
        let req = MotivationEntryRequest(habit_id: habitId, date: date, level: level)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/motivation/today",
            method: "PATCH",
            body: req
        )
    }

    func updateAbilityEntry(habitId: Int, date: String, level: String) async throws -> AbilityEntryResponse {
        let req = AbilityEntryRequest(habit_id: habitId, date: date, level: level)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/ability/today",
            method: "PATCH",
            body: req
        )
    }

    // MARK: - Task Management API Operations

    func generateAndCreateTask(habitId: Int, request: AITaskGenerationRequest) async throws -> TaskCreationResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/generate-and-create-task",
            method: "POST",
            body: request
        )
    }

    func getTodayTask(habitId: Int, userDate: String? = nil) async throws -> TaskEntry {
        var endpoint = "/api/v1/habits/\(habitId)/today-task"
        if let userDate = userDate {
            endpoint += "?user_date=\(userDate)"
        }
        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    func getPendingTasks(limit: Int = 10) async throws -> [TaskEntry] {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/pending-tasks?limit=\(limit)",
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Fetch a fresh SAS URL for a proof image for a given task_id
    func getFreshProofUrl(taskId: Int) async throws -> String {
        struct ProofUrlResponse: Codable { let url: String }
        let response: ProofUrlResponse = try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/\(taskId)/proof-url",
            method: "GET",
            body: (nil as String?)
        )
        return response.url
    }

    // NOTE: The response for submitTaskProof and submitTaskProofWithFile must match TaskSubmissionResponse (with TaskEntry as 'task')
    func submitTaskProof(taskId: Int, proofData: TaskProofSubmissionData) async throws -> TaskSubmissionResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/\(taskId)/submit-proof",
            method: "POST",
            body: proofData
        )
    }

    func submitTaskProofWithFile(
        taskId: Int,
        proofType: String,
        proofContent: String,
        fileData: Data? = nil,
        fileName: String? = nil,
        mimeType: String? = nil
    ) async throws -> TaskSubmissionResponse {
        let textFields = [
            "proof_type": proofType,
            "proof_content": proofContent
        ]

        return try await networkService.submitMultipartForm(
            endpoint: "/api/v1/habits/tasks/\(taskId)/submit-proof",
            textFields: textFields,
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            fileFieldName: "file"
        )
    }

    func updateTaskStatus(taskId: Int, status: String) async throws -> TaskStatusResponse {
        let request = TaskStatusUpdateRequest(status: status)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/\(taskId)/status",
            method: "PUT",
            body: request
        )
    }

    func markTaskMissed(taskId: Int) async throws -> TaskStatusResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/\(taskId)/mark-missed",
            method: "PUT",
            body: (nil as String?)
        )
    }

    struct ExpiredTasksResponse: Codable {
        let success: Bool
        let expired_tasks: [TaskEntry]?
        let count: Int
    }

    func checkAndMarkExpiredTasks() async throws -> ExpiredTasksResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/check-expired",
            method: "POST",
            body: (nil as String?)
        )
    }

    // MARK: - Post API Operations

    func createPost(taskDescription: String, proof: HabitProofState, description: String, visibility: String, habitId: Int? = nil, proofInputType: ProofInputType? = nil, textProof: String? = nil, todayTask: TaskEntry? = nil, autoCreatedPostId: Int? = nil) async throws -> Post {
        // Prevent duplicate post creation
        if let existingId = autoCreatedPostId {
            throw NetworkError.requestFailed(statusCode: 409, body: "Post already created with id \(existingId)")
        }
        // Map visibility to PostPrivacy
        let privacy: PostPrivacy
        switch visibility.lowercased() {
        case "friends": privacy = .friends
        case "close friends": privacy = .closeFriends
        default: privacy = .private
        }

        var proofType: ProofType = .image
        var proofUrls: [String] = []
        var proofContent: String? = nil
        if let inputType = proofInputType {
            switch inputType {
            case .text:
                proofType = .text
                proofUrls = []
                proofContent = textProof ?? todayTask?.proofContent ?? ""
                print("[DEBUG] createPost: proofType .text, proofContent=\(String(describing: proofContent))")
            default:
                proofType = .image
                proofUrls = [todayTask?.proofContent].compactMap { $0 }
                proofContent = nil
                print("[DEBUG] createPost: proofType .image, proofUrls=\(proofUrls)")
            }
        }
        print("[DEBUG] Final createPost values: proofType=\(proofType), proofUrls=\(proofUrls), proofContent=\(String(describing: proofContent))")

        let assignedDate: String = todayTask?.assignedDate ?? DateFormatter.yyyyMMdd.string(from: Date())

        let postCreate = PostCreate(
            habitId: habitId,
            proofUrls: proofUrls,
            proofType: proofType,
            proofContent: proofContent,
            description: description,
            privacy: privacy,
            assignedDate: assignedDate
        )

        let url = URL(string: "\(APIConfig.apiBaseURL)/posts/")! // Trailing slash to avoid 307 redirect
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(postCreate)
        print("[DEBUG] PostCreate JSON body:\n" + (String(data: jsonData, encoding: .utf8) ?? "<invalid json>"))
        print("[DEBUG] PostCreate request headers: \(request.allHTTPHeaderFields ?? [:])")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }
        if (200...299).contains(httpResponse.statusCode) {
            do {
                let postResponse = try JSONDecoder().decode(PostResponse.self, from: data)
                return postResponse.post
            } catch {
                print("[WARNING] Decoding PostResponse failed but status was \(httpResponse.statusCode): \(error)")
                throw NetworkError.decodeError(error)
            }
        } else if httpResponse.statusCode == 409 {
            // Backend upsert: treat as success, decode and return existing post
            let postResponse = try JSONDecoder().decode(PostResponse.self, from: data)
            return postResponse.post
        } else {
            let body = String(data: data, encoding: .utf8) ?? "N/A"
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: body)
        }
    }

    // MARK: - Proof File Upload

    func uploadProofFile(data: Data, fileName: String, mimeType: String) async throws -> String {
        // Endpoint for proof file upload (adjust as needed)
        let url = URL(string: "\(APIConfig.apiBaseURL)/api/v1/proofs/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, body: nil)
        }
        // Assume response is { "url": "..." }
        let result = try JSONDecoder().decode([String: String].self, from: responseData)
        guard let urlString = result["url"] else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid upload response")
        }
        return urlString
    }

    // MARK: - Streak Freezer API Operations

    struct UserStreakFreezersResponse: Codable {
        let streak_freezers: Int
    }

    func getUserStreakFreezers() async throws -> UserStreakFreezersResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/user/streak-freezers",
            method: "GET",
            body: (nil as String?)
        )
    }

    func useUserStreakFreezer() async throws -> UserStreakFreezersResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/user/use-streak-freezer",
            method: "POST",
            body: (nil as String?)
        )
    }

    func awardUserStreakFreezer() async throws -> UserStreakFreezersResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/user/award-streak-freezer",
            method: "POST",
            body: (nil as String?)
        )
    }

    // MARK: - Profile/Post Count API Operations
    func fetchMyPostCount() async throws -> Int {
        struct PostCountResponse: Codable { let post_count: Int }
        let response: PostCountResponse = try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/users/me/post-count",
            method: "GET",
            body: (nil as String?)
        )
        return response.post_count
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()
}
