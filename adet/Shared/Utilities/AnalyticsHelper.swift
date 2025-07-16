import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

// MARK: - Analytics Helper
struct AnalyticsHelper {
    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
    static func logError(_ error: Error, userInfo: [String: Any]? = nil) {
        Crashlytics.crashlytics().record(error: error)
        if let info = userInfo {
            for (key, value) in info {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
        }
    }
    static func setUserId(_ id: String) {
        Analytics.setUserID(id)
        Crashlytics.crashlytics().setUserID(id)
    }
}