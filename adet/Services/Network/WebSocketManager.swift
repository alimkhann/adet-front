import Foundation
import Combine
import OSLog

// For now, we'll create a protocol that can be implemented with Starscream later
protocol WebSocketProtocol {
    func connect()
    func disconnect()
    func send(text: String)
    var delegate: WebSocketDelegate? { get set }
}

protocol WebSocketDelegate: AnyObject {
    func webSocketDidConnect()
    func webSocketDidDisconnect(error: Error?)
    func webSocketDidReceiveMessage(text: String)
    func webSocketDidReceiveData(data: Data)
}

@MainActor
class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    private let logger = Logger(subsystem: "com.adet.websocket", category: "WebSocketManager")

    // Published properties for UI updates
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: ChatError?

    // Private properties
    private var webSocket: WebSocketProtocol?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 2.0

    // WebSocket connection details
    private var conversationId: Int?
    private var authToken: String?
    private var baseURL: String

    // Combine subjects for event handling
    private let messageSubject = PassthroughSubject<Message, Never>()
    private let typingSubject = PassthroughSubject<TypingEvent, Never>()
    private let presenceSubject = PassthroughSubject<PresenceEvent, Never>()
    private let messageStatusSubject = PassthroughSubject<MessageStatusEvent, Never>()
    private let connectionSubject = PassthroughSubject<ConnectionEvent, Never>()

    // Public publishers
    var messagePublisher: AnyPublisher<Message, Never> { messageSubject.eraseToAnyPublisher() }
    var typingPublisher: AnyPublisher<TypingEvent, Never> { typingSubject.eraseToAnyPublisher() }
    var presencePublisher: AnyPublisher<PresenceEvent, Never> { presenceSubject.eraseToAnyPublisher() }
    var messageStatusPublisher: AnyPublisher<MessageStatusEvent, Never> { messageStatusSubject.eraseToAnyPublisher() }
    var connectionPublisher: AnyPublisher<ConnectionEvent, Never> { connectionSubject.eraseToAnyPublisher() }

    private init() {
        // TODO: Get this from environment/config
        self.baseURL = "ws://localhost:8000" // Will be updated with proper config

        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        disconnect()
    }

    // MARK: - Public Interface

    func connect(to conversationId: Int, with token: String) {
        logger.info("Attempting to connect to conversation \(conversationId)")

        self.conversationId = conversationId
        self.authToken = token

        guard connectionState != .connected else {
            logger.info("Already connected to WebSocket")
            return
        }

        connectionState = .connecting
        lastError = nil

        // Create WebSocket URL with auth token
        let wsURL = "\(baseURL)/api/v1/chats/ws/\(conversationId)?token=\(token)"

        // TODO: Implement with Starscream when added
        // For now, simulate connection for development
        simulateConnection()
    }

    func disconnect() {
        logger.info("Disconnecting WebSocket")

        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0

        webSocket?.disconnect()
        webSocket = nil

        conversationId = nil
        authToken = nil

        connectionState = .disconnected
    }

    func sendMessage(_ content: String) {
        guard connectionState == .connected else {
            logger.error("Cannot send message: WebSocket not connected")
            lastError = .connectionFailed
            return
        }

        let eventData = SendMessageEventData(content: content)
        let message = WebSocketMessage(
            eventType: WebSocketEventType.sendMessage.rawValue,
            data: eventData.dictionary
        )

        sendWebSocketMessage(message)
    }

    func sendTypingIndicator(isTyping: Bool) {
        guard connectionState == .connected else { return }

        let eventData = TypingEventData(isTyping: isTyping)
        let message = WebSocketMessage(
            eventType: WebSocketEventType.typing.rawValue,
            data: eventData.dictionary
        )

        sendWebSocketMessage(message)
    }

    func markMessagesAsRead(lastMessageId: Int) {
        guard connectionState == .connected else { return }

        let eventData = MarkReadEventData(lastMessageId: lastMessageId)
        let message = WebSocketMessage(
            eventType: WebSocketEventType.markRead.rawValue,
            data: eventData.dictionary
        )

        sendWebSocketMessage(message)
    }

    // MARK: - Private Methods

    private func sendWebSocketMessage(_ message: WebSocketMessage) {
        do {
            let jsonData = try JSONEncoder().encode(message)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                webSocket?.send(text: jsonString)
                logger.debug("Sent WebSocket message: \(message.eventType)")
            }
        } catch {
            logger.error("Failed to encode WebSocket message: \(error)")
            lastError = .invalidData
        }
    }

    private func handleIncomingMessage(_ text: String) {
        logger.debug("Received WebSocket message: \(text)")

        guard let data = text.data(using: .utf8) else {
            logger.error("Failed to convert message to data")
            return
        }

        do {
            // Try to decode as WebSocketMessage first
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let socketMessage = try decoder.decode(WebSocketMessage.self, from: data)
            processWebSocketEvent(socketMessage)

        } catch {
            logger.error("Failed to decode WebSocket message: \(error)")
            lastError = .invalidData
        }
    }

    private func processWebSocketEvent(_ socketMessage: WebSocketMessage) {
        guard let eventType = WebSocketEventType(rawValue: socketMessage.eventType) else {
            logger.warning("Unknown WebSocket event type: \(socketMessage.eventType)")
            return
        }

        do {
            let eventData = try JSONSerialization.data(withJSONObject: socketMessage.data)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            switch eventType {
            case .message:
                let messageEvent = try decoder.decode(MessageEvent.self, from: eventData)
                messageSubject.send(messageEvent.message)

            case .typingIndicator:
                let typingEvent = try decoder.decode(TypingEvent.self, from: eventData)
                typingSubject.send(typingEvent)

            case .presence:
                let presenceEvent = try decoder.decode(PresenceEvent.self, from: eventData)
                presenceSubject.send(presenceEvent)

            case .messageStatus:
                let statusEvent = try decoder.decode(MessageStatusEvent.self, from: eventData)
                messageStatusSubject.send(statusEvent)

            case .connection:
                let connectionEvent = try decoder.decode(ConnectionEvent.self, from: eventData)
                connectionSubject.send(connectionEvent)

            case .error:
                if let errorMessage = socketMessage.data["message"] as? String {
                    lastError = .webSocketError(errorMessage)
                }

            case .messageSent:
                // Handle message sent confirmation
                logger.info("Message sent confirmation received")

            default:
                logger.debug("Unhandled event type: \(eventType)")
            }

        } catch {
            logger.error("Failed to process WebSocket event: \(error)")
            lastError = .invalidData
        }
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            logger.error("Max reconnect attempts reached")
            connectionState = .failed
            lastError = .connectionFailed
            return
        }

        connectionState = .reconnecting
        reconnectAttempts += 1

        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        logger.info("Scheduling reconnect attempt \(reconnectAttempts) in \(delay) seconds")

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.attemptReconnect()
            }
        }
    }

    private func attemptReconnect() {
        guard let conversationId = conversationId,
              let authToken = authToken else {
            logger.error("Cannot reconnect: missing conversation ID or auth token")
            connectionState = .failed
            return
        }

        logger.info("Attempting to reconnect...")
        connect(to: conversationId, with: authToken)
    }

    // MARK: - App Lifecycle

    @objc private func appDidEnterBackground() {
        logger.info("App entered background, maintaining WebSocket connection")
        // Keep connection alive in background for real-time notifications
    }

    @objc private func appWillEnterForeground() {
        logger.info("App entering foreground")

        // Check connection health and reconnect if needed
        if connectionState == .disconnected,
           let conversationId = conversationId,
           let authToken = authToken {
            connect(to: conversationId, with: authToken)
        }
    }

    // MARK: - Development Simulation (Remove when Starscream is added)

    private func simulateConnection() {
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connectionState = .connected
            self.reconnectAttempts = 0
            self.logger.info("WebSocket simulation connected")

            // Send connection event
            let connectionEvent = ConnectionEvent(
                type: "connection",
                status: "connected",
                message: "Successfully connected to chat"
            )
            self.connectionSubject.send(connectionEvent)
        }
    }
}

// MARK: - WebSocketDelegate Implementation

extension WebSocketManager: WebSocketDelegate {
    func webSocketDidConnect() {
        logger.info("WebSocket connected successfully")
        connectionState = .connected
        reconnectAttempts = 0
        lastError = nil
    }

    func webSocketDidDisconnect(error: Error?) {
        logger.info("WebSocket disconnected")

        if let error = error {
            logger.error("WebSocket disconnection error: \(error)")
            lastError = .networkError(error)

            // Attempt to reconnect on unexpected disconnection
            if connectionState == .connected {
                scheduleReconnect()
            }
        } else {
            connectionState = .disconnected
        }
    }

    func webSocketDidReceiveMessage(text: String) {
        handleIncomingMessage(text)
    }

    func webSocketDidReceiveData(data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            handleIncomingMessage(text)
        } else {
            logger.error("Received binary data that could not be converted to text")
        }
    }
}