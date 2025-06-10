import XCTest

final class AuthenticationUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Reset app state
        app.launchArguments = ["UI-Testing"]
        app.launch()

        // Ensure we're signed out
        if app.tabBars["Tab Bar"].exists {
            navigateToSettingsAndSignOut()
        }
    }

    override func tearDownWithError() throws {
        // Clean up after each test
        if app.tabBars["Tab Bar"].exists {
            navigateToSettingsAndSignOut()
        }
    }

    // MARK: - Sign In Tests

    func testSignInWithValidCredentials() throws {
        print("Starting test: testSignInWithValidCredentials")

        // First, create a test user
        try createTestUser()

        // Navigate to Sign In
        print("Navigating to Sign In")
        app.buttons["I already have an account"].tap()

        // Enter valid credentials
        print("Entering credentials")
        let emailTextField = app.textFields["Email"]
        let passwordSecureTextField = app.secureTextFields["Password"]

        XCTAssertTrue(emailTextField.waitForExistence(timeout: 2), "Email text field not found")
        XCTAssertTrue(passwordSecureTextField.waitForExistence(timeout: 2), "Password text field not found")

        emailTextField.tap()
        emailTextField.typeText("test@example.com")

        passwordSecureTextField.tap()
        passwordSecureTextField.typeText("Test123!@#")

        // Tap Sign In button
        print("Tapping Sign In button")
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 2), "Sign In button not found")
        signInButton.tap()

        // Verify navigation to TabBar
        print("Verifying navigation to TabBar")
        XCTAssertTrue(app.tabBars["Tab Bar"].waitForExistence(timeout: 5), "Tab Bar not found after sign in")
    }

    func testSignInWithInvalidCredentials() throws {
        print("Starting test: testSignInWithInvalidCredentials")

        // Navigate to Sign In
        print("Navigating to Sign In")
        app.buttons["I already have an account"].tap()

        // Enter invalid credentials
        print("Entering invalid credentials")
        let emailTextField = app.textFields["Email"]
        let passwordSecureTextField = app.secureTextFields["Password"]

        XCTAssertTrue(emailTextField.waitForExistence(timeout: 2), "Email text field not found")
        XCTAssertTrue(passwordSecureTextField.waitForExistence(timeout: 2), "Password text field not found")

        emailTextField.tap()
        emailTextField.typeText("invalid@example.com")

        passwordSecureTextField.tap()
        passwordSecureTextField.typeText("wrongpassword")

        // Tap Sign In button
        print("Tapping Sign In button")
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 2), "Sign In button not found")
        signInButton.tap()

        // Verify error message
        print("Verifying error message")
        let errorMessage = app.staticTexts["Invalid credentials"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 2), "Error message not found")
    }

    func testSignInWithEmptyFields() throws {
        print("Starting test: testSignInWithEmptyFields")

        // Navigate to Sign In
        print("Navigating to Sign In")
        app.buttons["I already have an account"].tap()

        // Tap Sign In button without entering any data
        print("Tapping Sign In button without entering data")
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 2), "Sign In button not found")
        signInButton.tap()

        // Verify error message
        print("Verifying error message")
        let errorMessage = app.staticTexts["All fields are required."]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 2), "Error message not found")
    }

    // MARK: - Sign Up Tests

    func testSignUpWithValidData() throws {
        print("Starting test: testSignUpWithValidData")

        // Navigate to Sign Up
        print("Navigating to Sign Up")
        app.buttons["Get Started"].tap()

        // Complete onboarding
        print("Completing onboarding")
        try completeOnboarding()

        // Enter valid sign up data
        print("Entering sign up data")
        let usernameTextField = app.textFields["Username"]
        let emailTextField = app.textFields["Email"]
        let passwordSecureTextField = app.secureTextFields["Password"]

        XCTAssertTrue(usernameTextField.waitForExistence(timeout: 2), "Username text field not found")
        XCTAssertTrue(emailTextField.waitForExistence(timeout: 2), "Email text field not found")
        XCTAssertTrue(passwordSecureTextField.waitForExistence(timeout: 2), "Password text field not found")

        usernameTextField.tap()
        usernameTextField.typeText("testuser")

        emailTextField.tap()
        emailTextField.typeText("test@example.com")

        passwordSecureTextField.tap()
        passwordSecureTextField.typeText("Test123!@#")

        // Tap Sign Up button
        print("Tapping Sign Up button")
        let signUpButton = app.buttons["Sign Up"]
        XCTAssertTrue(signUpButton.waitForExistence(timeout: 2), "Sign Up button not found")
        signUpButton.tap()

        // Verify navigation to TabBar
        print("Verifying navigation to TabBar")
        XCTAssertTrue(app.tabBars["Tab Bar"].waitForExistence(timeout: 5), "Tab Bar not found after sign up")
    }

    func testSignUpWithInvalidEmail() throws {
        // Navigate to Sign Up
        app.buttons["Get Started"].tap()

        // Complete onboarding
        try completeOnboarding()

        // Enter invalid email
        let usernameTextField = app.textFields["Username"]
        let emailTextField = app.textFields["Email"]
        let passwordSecureTextField = app.secureTextFields["Password"]

        usernameTextField.tap()
        usernameTextField.typeText("testuser")

        emailTextField.tap()
        emailTextField.typeText("invalid-email")

        passwordSecureTextField.tap()
        passwordSecureTextField.typeText("Test123!@#")

        // Tap Sign Up button
        app.buttons["Sign Up"].tap()

        // Verify error message
        XCTAssertTrue(app.staticTexts["Please enter a valid email address"].waitForExistence(timeout: 2))
    }

    func testSignUpWithWeakPassword() throws {
        // Navigate to Sign Up
        app.buttons["Get Started"].tap()

        // Complete onboarding
        try completeOnboarding()

        // Enter weak password
        let usernameTextField = app.textFields["Username"]
        let emailTextField = app.textFields["Email"]
        let passwordSecureTextField = app.secureTextFields["Password"]

        usernameTextField.tap()
        usernameTextField.typeText("testuser")

        emailTextField.tap()
        emailTextField.typeText("test@example.com")

        passwordSecureTextField.tap()
        passwordSecureTextField.typeText("weak")

        // Tap Sign Up button
        app.buttons["Sign Up"].tap()

        // Verify error message
        XCTAssertTrue(app.staticTexts["Password is too weak"].waitForExistence(timeout: 2))
    }

    // MARK: - Helper Methods

    private func navigateToSettingsAndSignOut() {
        print("Navigating to Settings and signing out")
        app.tabBars["Tab Bar"].buttons["Profile"].tap()
        app.buttons["gearshape.fill"].tap()
        app.buttons["Sign Out"].tap()
    }

    private func createTestUser() throws {
        print("Creating test user")
        app.buttons["Get Started"].tap()
        try completeOnboarding()

        let usernameTextField = app.textFields["Username"]
        let emailTextField = app.textFields["Email"]
        let passwordSecureTextField = app.secureTextFields["Password"]

        usernameTextField.tap()
        usernameTextField.typeText("testuser")

        emailTextField.tap()
        emailTextField.typeText("test@example.com")

        passwordSecureTextField.tap()
        passwordSecureTextField.typeText("Test123!@#")

        app.buttons["Sign Up"].tap()

        // Wait for sign up to complete
        XCTAssertTrue(app.tabBars["Tab Bar"].waitForExistence(timeout: 5))

        // Sign out to prepare for sign in test
        navigateToSettingsAndSignOut()
    }

    private func completeOnboarding() throws {
        print("Starting onboarding completion")

        // Answer first question
        let firstAnswerField = app.textFields["Enter your answer…"]
        XCTAssertTrue(firstAnswerField.waitForExistence(timeout: 2), "First answer field not found")
        firstAnswerField.tap()
        firstAnswerField.typeText("Daily journaling")

        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 2), "Next button not found")
        nextButton.tap()

        // Answer second question
        let dailyButton = app.buttons["Daily"]
        XCTAssertTrue(dailyButton.waitForExistence(timeout: 2), "Daily button not found")
        dailyButton.tap()
        nextButton.tap()

        // Answer third question
        let morningButton = app.buttons["Morning"]
        XCTAssertTrue(morningButton.waitForExistence(timeout: 2), "Morning button not found")
        morningButton.tap()
        nextButton.tap()

        // Answer fourth question
        let mediumButton = app.buttons["Medium"]
        XCTAssertTrue(mediumButton.waitForExistence(timeout: 2), "Medium button not found")
        mediumButton.tap()
        nextButton.tap()

        // Answer fifth question
        let photoButton = app.buttons["Photo"]
        XCTAssertTrue(photoButton.waitForExistence(timeout: 2), "Photo button not found")
        photoButton.tap()
        nextButton.tap()

        // Answer sixth question
        let yesButton = app.buttons["Yes"]
        XCTAssertTrue(yesButton.waitForExistence(timeout: 2), "Yes button not found")
        yesButton.tap()

        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 2), "Create Account button not found")
        createAccountButton.tap()

        print("Onboarding completed")
    }
}
