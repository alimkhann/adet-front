import Foundation

enum ValidationError: LocalizedError {
    case invalidEmail
    case invalidUsername
    case invalidPassword
    case emptyField

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidUsername:
            return "Username must be 3-20 characters and can only contain letters, numbers, and underscores"
        case .invalidPassword:
            return "Password must be at least 8 characters and contain at least one uppercase letter, one lowercase letter, one number, and one special character"
        case .emptyField:
            return "This field cannot be empty"
        }
    }
}

struct ValidationService {
    static func validateEmail(_ email: String) throws {
        guard !email.isEmpty else {
            throw ValidationError.emptyField
        }

        // RFC 5322 compliant email regex
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard emailPredicate.evaluate(with: email) else {
            throw ValidationError.invalidEmail
        }
    }

    static func validateUsername(_ username: String) throws {
        guard !username.isEmpty else {
            throw ValidationError.emptyField
        }

        // Username must be 3-20 characters and can only contain letters, numbers, and underscores
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)

        guard usernamePredicate.evaluate(with: username) else {
            throw ValidationError.invalidUsername
        }
    }

    static func validatePassword(_ password: String) throws {
        guard !password.isEmpty else {
            throw ValidationError.emptyField
        }

        // Password must be at least 8 characters and contain:
        // - At least one uppercase letter
        // - At least one lowercase letter
        // - At least one number
        // - At least one special character
        let passwordRegex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)

        guard passwordPredicate.evaluate(with: password) else {
            throw ValidationError.invalidPassword
        }
    }
}