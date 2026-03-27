import Foundation
import SwiftData

// MARK: - Appliance Category

enum ApplianceCategory: String, CaseIterable, Codable, Identifiable {
    // Entertainment
    case television = "Television"
    case gamingConsole = "Gaming Console"
    case soundbar = "Soundbar"
    case streamingDevice = "Streaming Device"

    // Computing
    case desktop = "Desktop Computer"
    case laptop = "Laptop"
    case monitor = "Monitor"
    case router = "Router/Modem"

    // Kitchen
    case refrigerator = "Refrigerator"
    case freezer = "Freezer"
    case dishwasher = "Dishwasher"
    case microwave = "Microwave"
    case oven = "Oven/Range"
    case coffeeMaker = "Coffee Maker"
    case toaster = "Toaster/Toaster Oven"

    // Lighting
    case ledBulb = "LED Bulb"
    case cflBulb = "CFL Bulb"
    case incandescentBulb = "Incandescent Bulb"
    case floodlight = "Floodlight"
    case lampFixture = "Lamp/Fixture"

    // Other
    case ceilingFan = "Ceiling Fan"
    case portableHeater = "Portable Heater"
    case dehumidifier = "Dehumidifier"
    case poolPump = "Pool Pump"
    case evCharger = "EV Charger"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .television: return "tv"
        case .gamingConsole: return "gamecontroller"
        case .soundbar: return "hifispeaker"
        case .streamingDevice: return "appletv"
        case .desktop: return "desktopcomputer"
        case .laptop: return "laptopcomputer"
        case .monitor: return "display"
        case .router: return "wifi.router"
        case .refrigerator: return "refrigerator"
        case .freezer: return "snowflake"
        case .dishwasher: return "dishwasher"
        case .microwave: return "microwave"
        case .oven: return "oven"
        case .coffeeMaker: return "cup.and.saucer"
        case .toaster: return "toaster"
        case .ledBulb, .cflBulb, .incandescentBulb: return "lightbulb"
        case .floodlight: return "light.recessed"
        case .lampFixture: return "lamp.desk"
        case .ceilingFan: return "fan.ceiling"
        case .portableHeater: return "heater.vertical"
        case .dehumidifier: return "dehumidifier"
        case .poolPump: return "water.waves"
        case .evCharger: return "ev.charger"
        case .other: return "ellipsis.circle"
        }
    }

    var defaultWattage: Double {
        switch self {
        case .television: return 100
        case .gamingConsole: return 150
        case .soundbar: return 30
        case .streamingDevice: return 5
        case .desktop: return 200
        case .laptop: return 50
        case .monitor: return 30
        case .router: return 12
        case .refrigerator: return 150
        case .freezer: return 100
        case .dishwasher: return 1800
        case .microwave: return 1100
        case .oven: return 2500
        case .coffeeMaker: return 900
        case .toaster: return 1200
        case .ledBulb: return 9
        case .cflBulb: return 13
        case .incandescentBulb: return 60
        case .floodlight: return 65
        case .lampFixture: return 60
        case .ceilingFan: return 75
        case .portableHeater: return 1500
        case .dehumidifier: return 300
        case .poolPump: return 1500
        case .evCharger: return 7200
        case .other: return 100
        }
    }

    var defaultHoursPerDay: Double {
        switch self {
        case .television: return 5
        case .gamingConsole: return 2
        case .soundbar: return 4
        case .streamingDevice: return 5
        case .desktop: return 6
        case .laptop: return 6
        case .monitor: return 6
        case .router: return 24
        case .refrigerator: return 24
        case .freezer: return 24
        case .dishwasher: return 1
        case .microwave: return 0.3
        case .oven: return 1
        case .coffeeMaker: return 0.5
        case .toaster: return 0.2
        case .ledBulb: return 5
        case .cflBulb: return 5
        case .incandescentBulb: return 5
        case .floodlight: return 4
        case .lampFixture: return 5
        case .ceilingFan: return 8
        case .portableHeater: return 4
        case .dehumidifier: return 12
        case .poolPump: return 8
        case .evCharger: return 3
        case .other: return 2
        }
    }

    var isPhantomLoadRelevant: Bool {
        switch self {
        case .television, .gamingConsole, .soundbar, .streamingDevice,
             .desktop, .laptop, .monitor, .router,
             .microwave, .coffeeMaker, .toaster:
            return true
        default:
            return false
        }
    }

    var phantomWatts: Double {
        switch self {
        case .television: return 5
        case .gamingConsole: return 10
        case .soundbar: return 3
        case .streamingDevice: return 2
        case .desktop: return 5
        case .laptop: return 2
        case .monitor: return 2
        case .router: return 0 // always on, no phantom
        case .microwave: return 3
        case .coffeeMaker: return 2
        case .toaster: return 1
        default: return 0
        }
    }

    var categoryGroup: String {
        switch self {
        case .television, .gamingConsole, .soundbar, .streamingDevice:
            return "Entertainment"
        case .desktop, .laptop, .monitor, .router:
            return "Computing"
        case .refrigerator, .freezer, .dishwasher, .microwave, .oven, .coffeeMaker, .toaster:
            return "Kitchen"
        case .ledBulb, .cflBulb, .incandescentBulb, .floodlight, .lampFixture:
            return "Lighting"
        case .ceilingFan, .portableHeater, .dehumidifier, .poolPump, .evCharger, .other:
            return "Other"
        }
    }

    var isLighting: Bool {
        switch self {
        case .ledBulb, .cflBulb, .incandescentBulb, .floodlight, .lampFixture:
            return true
        default:
            return false
        }
    }
}

// MARK: - Appliance Model

@Model
final class Appliance {
    var id: UUID
    var category: String // ApplianceCategory.rawValue
    var name: String
    var estimatedWattage: Double
    var hoursPerDay: Double
    var quantity: Int
    var detectionMethod: String // "manual", "camera", "ocr"
    var photoData: Data?
    var room: Room?
    var home: Home?
    var createdAt: Date

    init(
        category: ApplianceCategory = .other,
        name: String = "",
        estimatedWattage: Double? = nil,
        hoursPerDay: Double? = nil,
        quantity: Int = 1,
        detectionMethod: String = "manual",
        photoData: Data? = nil
    ) {
        self.id = UUID()
        self.category = category.rawValue
        self.name = name.isEmpty ? category.rawValue : name
        self.estimatedWattage = estimatedWattage ?? category.defaultWattage
        self.hoursPerDay = hoursPerDay ?? category.defaultHoursPerDay
        self.quantity = quantity
        self.detectionMethod = detectionMethod
        self.photoData = photoData
        self.createdAt = Date()
    }

    var categoryEnum: ApplianceCategory {
        ApplianceCategory(rawValue: category) ?? .other
    }

    /// Annual energy consumption in kWh
    var annualKWh: Double {
        estimatedWattage * hoursPerDay * 365.0 / 1000.0 * Double(quantity)
    }

    /// Annual cost at the given electricity rate
    func annualCost(rate: Double = Constants.defaultElectricityRate) -> Double {
        annualKWh * rate
    }

    /// Annual phantom/standby energy in kWh
    var phantomAnnualKWh: Double {
        let cat = categoryEnum
        guard cat.isPhantomLoadRelevant else { return 0 }
        let standbyHours = max(24.0 - hoursPerDay, 0)
        return cat.phantomWatts * standbyHours * 365.0 / 1000.0 * Double(quantity)
    }

    /// Total annual kWh including phantom load
    var totalAnnualKWh: Double {
        annualKWh + phantomAnnualKWh
    }
}
