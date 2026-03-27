import Foundation

enum AnalyticsEvent: String {
    case appOpen = "app_open"
    case onboardingCompleted = "onboarding_completed"
    case auditCompleted = "audit_completed"
    case reportViewed = "report_viewed"
    case pdfExported = "pdf_exported"
}

enum AnalyticsService {
    static func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        #if DEBUG
        if properties.isEmpty {
            print("[Analytics] \(event.rawValue)")
        } else {
            print("[Analytics] \(event.rawValue) \(properties)")
        }
        #else
        // No-op by default for launch. Hook a provider here if needed.
        _ = event
        _ = properties
        #endif
    }
}

