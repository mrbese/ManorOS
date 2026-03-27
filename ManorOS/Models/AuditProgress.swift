import Foundation
import SwiftData

enum AuditStep: String, CaseIterable, Codable, Identifiable {
    case roomScanning = "Room Scanning"
    case equipment = "Equipment"
    case appliancesAndLighting = "Appliances & Lighting"
    case buildingEnvelope = "Building Envelope"
    case billUpload = "Bill Upload"
    case review = "Review"

    var id: String { rawValue }

    var stepNumber: Int {
        Self.allCases.firstIndex(of: self)! + 1
    }

    var icon: String {
        switch self {
        case .roomScanning: return "camera.viewfinder"
        case .equipment: return "wrench.and.screwdriver"
        case .appliancesAndLighting: return "powerplug"
        case .buildingEnvelope: return "house.and.flag"
        case .billUpload: return "doc.text"
        case .review: return "checkmark.seal"
        }
    }

    var shortLabel: String {
        switch self {
        case .roomScanning: return "Rooms"
        case .equipment: return "Equipment"
        case .appliancesAndLighting: return "Appliances"
        case .buildingEnvelope: return "Envelope"
        case .billUpload: return "Bills"
        case .review: return "Review"
        }
    }

    /// Maps old 10-step rawValues to new 6-step rawValues for migration.
    static func migrateRawValue(_ oldRaw: String) -> String? {
        switch oldRaw {
        case "Home Basics", "Room Scanning":
            return AuditStep.roomScanning.rawValue
        case "HVAC Equipment", "Water Heating":
            return AuditStep.equipment.rawValue
        case "Appliance Inventory", "Lighting Audit":
            return AuditStep.appliancesAndLighting.rawValue
        case "Window Assessment", "Envelope Assessment":
            return AuditStep.buildingEnvelope.rawValue
        case "Bill Upload":
            return AuditStep.billUpload.rawValue
        case "Review":
            return AuditStep.review.rawValue
        default:
            return AuditStep(rawValue: oldRaw)?.rawValue
        }
    }
}

@Model
final class AuditProgress {
    var id: UUID
    var completedStepsData: Data? // JSON-encoded [String] of AuditStep rawValues
    var currentStep: String // AuditStep.rawValue
    var home: Home?
    var startedAt: Date
    var lastUpdatedAt: Date

    init(home: Home? = nil) {
        self.id = UUID()
        self.completedStepsData = try? JSONEncoder().encode([String]())
        self.currentStep = AuditStep.roomScanning.rawValue
        self.home = home
        self.startedAt = Date()
        self.lastUpdatedAt = Date()
    }

    var completedSteps: [AuditStep] {
        get {
            guard let data = completedStepsData,
                  let rawValues = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            var seen = Set<AuditStep>()
            var result = [AuditStep]()
            for raw in rawValues {
                let mapped = AuditStep.migrateRawValue(raw) ?? raw
                if let step = AuditStep(rawValue: mapped), !seen.contains(step) {
                    seen.insert(step)
                    result.append(step)
                }
            }
            return result
        }
        set {
            completedStepsData = try? JSONEncoder().encode(newValue.map(\.rawValue))
            lastUpdatedAt = Date()
        }
    }

    var currentStepEnum: AuditStep {
        if let step = AuditStep(rawValue: currentStep) {
            return step
        }
        if let migrated = AuditStep.migrateRawValue(currentStep),
           let step = AuditStep(rawValue: migrated) {
            return step
        }
        return .roomScanning
    }

    func isStepComplete(_ step: AuditStep) -> Bool {
        completedSteps.contains(step)
    }

    func markComplete(_ step: AuditStep) {
        var steps = completedSteps
        if !steps.contains(step) {
            steps.append(step)
            completedSteps = steps
        }
    }

    var progressPercentage: Double {
        let total = Double(AuditStep.allCases.count)
        return total > 0 ? Double(completedSteps.count) / total * 100.0 : 0
    }

    var isComplete: Bool {
        completedSteps.count == AuditStep.allCases.count
    }
}
