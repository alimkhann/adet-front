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
    case registrationFailed(String)
    case loginFailed(String)
    case authorizationFailed
    case userUpdateFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network error occurred. Please check your connection."
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password is too weak"
        case .invalidUsername:
            return "Invalid username format"
        case .unknown(let error):
            return error.localizedDescription
        case .registrationFailed(let message):
            return "Registration failed: \(message)"
        case .loginFailed(let message):
            return "Login failed: \(message)"
        case .authorizationFailed:
            return "Authorization failed. Please log in again."
        case .userUpdateFailed(let message):
            return "User update failed: \(message)"
        }
    }
}

protocol AuthenticationServiceProtocol {
    var currentUser: User? { get async }

    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, username: String, password: String) async throws -> User
    func signOut() async throws
    func fetchCurrentUserProfile() async throws -> User
    func updateUsername(newUsername: String) async throws -> User
}

actor AuthenticationService: AuthenticationServiceProtocol {
    private let logger = Logger(subsystem: "com.adet.auth", category: "Authentication")
    private let userDefaults = UserDefaults.standard
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    private var currentAccessToken: String? { userDefaults.string(forKey: accessTokenKey) }

    var currentUser: User? {
        get async {
            if currentAccessToken != nil {
                return try? await fetchCurrentUserProfile()
            } else {
                return nil
            }
        }
    }

    init() {}

    func signIn(email: String, password: String) async throws -> User {
        logger.info("Attempting to sign in user with email: \(email)")

        do {
            try ValidationService.validateEmail(email)
            guard !password.isEmpty else {
                logger.error("Empty password")
                throw AuthenticationError.invalidCredentials
            }
        } catch {
            logger.error("Login validation error: \(error.localizedDescription)")
            if let validationError = error as? ValidationError {
                switch validationError {
                case .invalidEmail:
                    throw AuthenticationError.invalidEmail
                default:
                    throw AuthenticationError.invalidCredentials
                }
            } else {
                throw AuthenticationError.unknown(error)
            }
        }

        let loginPayload = "username=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        do {
            let token: Token = try await APIManager.shared.request(
                endpoint: "auth/token",
                method: "POST",
                body: loginPayload,
                headers: ["Content-Type": "application/x-www-form-urlencoded"]
            )
            userDefaults.set(token.accessToken, forKey: accessTokenKey)
            userDefaults.set(token.refreshToken, forKey: refreshTokenKey)
            logger.info("User signed in successfully. Access token stored.")

            return try await fetchCurrentUserProfile()
        } catch let apiError as APIError {
            if case .requestFailed(let statusCode) = apiError, statusCode == 401 {
                logger.error("Login failed: Invalid credentials.")
                throw AuthenticationError.invalidCredentials
            } else {
                logger.error("API Error during sign-in: \(apiError.localizedDescription)")
                throw AuthenticationError.loginFailed(apiError.localizedDescription)
            }
        } catch {
            logger.error("Unknown error during sign-in: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }
    }

    func signUp(email: String, username: String, password: String) async throws -> User {
        logger.info("Attempting to sign up user with email: \(email)")

        do {
            try ValidationService.validateEmail(email)
            try ValidationService.validateUsername(username)
            try ValidationService.validatePassword(password)
        } catch let error as ValidationError {
            logger.error("Sign-up validation error: \(error.localizedDescription)")
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
            logger.error("Unknown validation error during sign-up: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }

        let registrationPayload = ["email": email, "username": username, "password": password]
        do {
            let token: Token = try await APIManager.shared.request(
                endpoint: "auth/register",
                method: "POST",
                body: registrationPayload
            )
            userDefaults.set(token.accessToken, forKey: accessTokenKey)
            userDefaults.set(token.refreshToken, forKey: refreshTokenKey)
            logger.info("User registered successfully. Access token stored.")

            return try await fetchCurrentUserProfile()
        } catch let apiError as APIError {
            logger.error("API Error during sign-up: \(apiError.localizedDescription)")
            throw AuthenticationError.registrationFailed(apiError.localizedDescription)
        } catch {
            logger.error("Unknown error during sign-up: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }
    }

    func signOut() async throws {
        logger.info("Signing out user and clearing tokens.")
        userDefaults.removeObject(forKey: accessTokenKey)
        userDefaults.removeObject(forKey: refreshTokenKey)
    }

    func fetchCurrentUserProfile() async throws -> User {
        guard let accessToken = currentAccessToken else {
            logger.error("No access token found for fetching user profile.")
            throw AuthenticationError.authorizationFailed
        }

        let headers = ["Authorization": "Bearer \(accessToken)"]
        do {
            let user: User = try await APIManager.shared.request(
                endpoint: "auth/me",
                method: "GET",
                headers: headers
            )
            logger.info("Successfully fetched current user profile.")
            return user
        } catch let apiError as APIError {
            if case .requestFailed(let statusCode) = apiError, statusCode == 401 {
                logger.error("Authorization failed when fetching user profile.")
                throw AuthenticationError.authorizationFailed
            } else {
                logger.error("API Error during fetch user profile: \(apiError.localizedDescription)")
                throw AuthenticationError.networkError
            }
        } catch {
            logger.error("Unknown error during fetch user profile: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }
    }

    func updateUsername(newUsername: String) async throws -> User {
        guard let accessToken = currentAccessToken else {
            logger.error("No access token found for updating username.")
            throw AuthenticationError.authorizationFailed
        }

        let headers = ["Authorization": "Bearer \(accessToken)"]
        let updatePayload = ["username": newUsername]

        do {
            let updatedUser: User = try await APIManager.shared.request(
                endpoint: "auth/me",
                method: "PUT",
                body: updatePayload,
                headers: headers
            )
            logger.info("Username updated successfully.")
            return updatedUser
        } catch let apiError as APIError {
            if case .requestFailed(let statusCode) = apiError {
                logger.error("API Error during username update: \(statusCode). Response: \(apiError.localizedDescription)")
                throw AuthenticationError.userUpdateFailed(apiError.localizedDescription)
            } else {
                logger.error("Unknown API Error during username update: \(apiError.localizedDescription)")
                throw AuthenticationError.unknown(apiError)
            }
        } catch {
            logger.error("Unknown error during username update: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }
    }
}
