import Foundation

enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case centralAC = "Central AC"
    case heatPump = "Heat Pump"
    case furnace = "Furnace"
    case waterHeater = "Water Heater (Tank)"
    case waterHeaterTankless = "Water Heater (Tankless)"
    case windowUnit = "Window AC Unit"
    case thermostat = "Thermostat"
    case insulation = "Insulation"
    case windows = "Windows"
    case washer = "Washer"
    case dryer = "Dryer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .centralAC, .windowUnit: return "snowflake"
        case .heatPump: return "arrow.left.arrow.right"
        case .furnace: return "flame"
        case .waterHeater, .waterHeaterTankless: return "drop.fill"
        case .thermostat: return "thermometer"
        case .insulation: return "house.and.flag"
        case .windows: return "window.casement"
        case .washer: return "washer"
        case .dryer: return "dryer"
        }
    }

    var efficiencyUnit: String {
        switch self {
        case .centralAC: return "SEER"
        case .windowUnit: return "EER"
        case .heatPump: return "SEER"
        case .furnace: return "% AFUE"
        case .waterHeater, .waterHeaterTankless: return "UEF"
        case .thermostat: return "type"
        case .insulation: return "R-value"
        case .windows: return "U-factor"
        case .washer: return "IMEF"
        case .dryer: return "CEF"
        }
    }

    var cameraPrompt: String {
        switch self {
        case .centralAC, .heatPump:
            return "Point camera at the rating plate on your outdoor unit"
        case .furnace:
            return "Photograph the yellow EnergyGuide label or rating plate on your furnace"
        case .waterHeater, .waterHeaterTankless:
            return "Capture the EnergyGuide label on your water heater"
        case .windowUnit:
            return "Photograph the rating label on the side of the unit"
        case .thermostat:
            return "Photograph your thermostat display"
        case .insulation:
            return "Photograph the insulation label or packaging"
        case .windows:
            return "Capture the NFRC sticker on your window"
        case .washer:
            return "Photograph the EnergyGuide label on your washer"
        case .dryer:
            return "Photograph the EnergyGuide label on your dryer"
        }
    }

    var energyShareWeight: Double {
        switch self {
        case .centralAC, .heatPump, .furnace: return 0.45
        case .waterHeater, .waterHeaterTankless: return 0.18
        case .insulation, .windows: return 0.25
        case .thermostat, .windowUnit, .washer, .dryer: return 0.12
        }
    }
}
