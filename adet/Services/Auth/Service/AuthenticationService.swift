import Foundation
import OSLog

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case networkError
    case invalidEmail
    case weakPassword
    case invalidUsername
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network error occurred"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password is too weak"
        case .invalidUsername:
            return "Invalid username format"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

protocol AuthenticationServiceProtocol {
    var currentUser: User? { get async }

    func signIn(email: String, password: String) async throws -> User
    func signUp(user: User) async throws -> User
    func signOut() async throws
}

actor AuthenticationService: AuthenticationServiceProtocol {
    private let logger = Logger(subsystem: "com.adet.auth", category: "Authentication")
    private let userKey = "currentUser"

    var currentUser: User? {
        get async {
            await fetchUser()
        }
    }

    init() {}

    func signIn(email: String, password: String) async throws -> User {
        logger.info("Attempting to sign in user with email: \(email)")

        do {
            try ValidationService.validateEmail(email)
        } catch {
            logger.error("Invalid email format: \(error.localizedDescription)")
            throw AuthenticationError.invalidEmail
        }

        guard !password.isEmpty else {
            logger.error("Empty password")
            throw AuthenticationError.invalidCredentials
        }

        guard let data = UserDefaults.standard.data(forKey: userKey),
              let savedUser = try? JSONDecoder().decode(User.self, from: data) else {
            logger.error("User not found")
            throw AuthenticationError.userNotFound
        }

        if savedUser.email == email && savedUser.password == password {
            logger.info("User signed in successfully")
            return savedUser
        } else {
            logger.error("Invalid credentials")
            throw AuthenticationError.invalidCredentials
        }
    }

    func signUp(user: User) async throws -> User {
        logger.info("Attempting to sign up user with email: \(user.email)")

        do {
            try ValidationService.validateEmail(user.email)
            try ValidationService.validateUsername(user.username)
            try ValidationService.validatePassword(user.password)
        } catch let error as ValidationError {
            logger.error("Validation error: \(error.localizedDescription)")
            switch error {
            case .invalidEmail:
                throw AuthenticationError.invalidEmail
            case .invalidUsername:
                throw AuthenticationError.invalidUsername
            case .invalidPassword:
                throw AuthenticationError.weakPassword
            case .emptyField:
                throw AuthenticationError.invalidCredentials
            }
        } catch {
            logger.error("Unknown validation error: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }

        try await saveUser(user)
        logger.info("User signed up successfully")
        return user
    }

    func signOut() async throws {
        logger.info("Signing out user")
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    private func saveUser(_ user: User) async throws {
        guard let encoded = try? JSONEncoder().encode(user) else {
            logger.error("Failed to encode user data")
            throw AuthenticationError.unknown(NSError(domain: "", code: -1))
        }
        UserDefaults.standard.set(encoded, forKey: userKey)
    }

    private func fetchUser() async -> User? {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let decodedUser = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return decodedUser
    }
}
