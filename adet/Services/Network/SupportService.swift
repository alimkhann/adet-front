import Foundation
import UIKit
import OSLog

class SupportService: ObservableObject {
    static let shared = SupportService()
    
    private let baseURL = APIConfig.apiBaseURL
    private let session = URLSession.shared
    private let logger = Logger(subsystem: "com.adet.support", category: "SupportService")
    
    private init() {}
    
    // MARK: - Submit Support Request
    
    func submitSupportRequest(
        category: String,
        subject: String,
        message: String,
        includeSystemInfo: Bool
    ) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/support/request")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let systemInfo = includeSystemInfo ? getSystemInfo() : nil
            let requestBody = SupportRequest(
                category: category,
                subject: subject,
                message: message,
                systemInfo: systemInfo
            )
            
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to submit support request - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return false
            }
            
            logger.info("Successfully submitted support request")
            return true
            
        } catch {
            logger.error("Failed to submit support request: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Submit Bug Report
    
    func submitBugReport(
        category: String,
        severity: String,
        title: String,
        description: String,
        stepsToReproduce: String,
        expectedBehavior: String,
        actualBehavior: String,
        includeSystemInfo: Bool,
        includeScreenshots: Bool
    ) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/support/bug-report")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let systemInfo = includeSystemInfo ? getSystemInfo() : nil
            let requestBody = BugReport(
                category: category,
                severity: severity,
                title: title,
                description: description,
                stepsToReproduce: stepsToReproduce.isEmpty ? nil : stepsToReproduce,
                expectedBehavior: expectedBehavior.isEmpty ? nil : expectedBehavior,
                actualBehavior: actualBehavior.isEmpty ? nil : actualBehavior,
                systemInfo: systemInfo,
                includeScreenshots: includeScreenshots
            )
            
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to submit bug report - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return false
            }
            
            logger.info("Successfully submitted bug report")
            return true
            
        } catch {
            logger.error("Failed to submit bug report: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Get Support History
    
    func getSupportHistory() async -> [SupportTicket] {
        do {
            let url = URL(string: "\(baseURL)/support/history")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to get support history - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return []
            }
            
            let decoder = JSONDecoder()
            let history = try decoder.decode(SupportHistoryResponse.self, from: data)
            logger.info("Successfully loaded \(history.tickets.count) support tickets")
            return history.tickets
            
        } catch {
            logger.error("Failed to get support history: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSystemInfo() -> SystemInfo {
        return SystemInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            iosVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            deviceName: UIDevice.current.name,
            language: Locale.current.language.languageCode?.identifier ?? "en",
            timezone: TimeZone.current.identifier,
            timestamp: Date()
        )
    }
}

// MARK: - Request Models

struct SupportRequest: Codable {
    let category: String
    let subject: String
    let message: String
    let systemInfo: SystemInfo?
}

struct BugReport: Codable {
    let category: String
    let severity: String
    let title: String
    let description: String
    let stepsToReproduce: String?
    let expectedBehavior: String?
    let actualBehavior: String?
    let systemInfo: SystemInfo?
    let includeScreenshots: Bool
}

struct SystemInfo: Codable {
    let appVersion: String
    let buildNumber: String
    let iosVersion: String
    let deviceModel: String
    let deviceName: String
    let language: String
    let timezone: String
    let timestamp: Date
}

// MARK: - Response Models

struct SupportHistoryResponse: Codable {
    let tickets: [SupportTicket]
    let count: Int
}

struct SupportTicket: Codable, Identifiable {
    let id: Int
    let category: String
    let subject: String
    let message: String
    let status: TicketStatus
    let createdAt: Date
    let updatedAt: Date
    let systemInfo: SystemInfo?
    
    enum CodingKeys: String, CodingKey {
        case id, category, subject, message, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case systemInfo = "system_info"
    }
}

enum TicketStatus: String, Codable, CaseIterable {
    case open = "open"
    case inProgress = "in_progress"
    case resolved = "resolved"
    case closed = "closed"
    
    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }
    
    var color: String {
        switch self {
        case .open: return "blue"
        case .inProgress: return "orange"
        case .resolved: return "green"
        case .closed: return "gray"
        }
    }
}
