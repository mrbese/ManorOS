import Foundation

// MARK: - Window Enums

enum CardinalDirection: String, CaseIterable, Codable, Identifiable {
    case north = "N"
    case south = "S"
    case east = "E"
    case west = "W"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .north: return "North"
        case .south: return "South"
        case .east: return "East"
        case .west: return "West"
        }
    }

    var btuPerSqFt: Double {
        switch self {
        case .north: return Constants.WindowBTUPerSqFt.north
        case .south: return Constants.WindowBTUPerSqFt.south
        case .east: return Constants.WindowBTUPerSqFt.east
        case .west: return Constants.WindowBTUPerSqFt.west
        }
    }
}

enum WindowSize: String, CaseIterable, Codable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var sqFt: Double {
        switch self {
        case .small: return Constants.WindowSizeSqFt.small
        case .medium: return Constants.WindowSizeSqFt.medium
        case .large: return Constants.WindowSizeSqFt.large
        }
    }

    var description: String {
        switch self {
        case .small: return "Small (~10 sq ft)"
        case .medium: return "Medium (~20 sq ft)"
        case .large: return "Large (~35 sq ft)"
        }
    }
}

enum PaneType: String, CaseIterable, Codable, Identifiable {
    case notAssessed = "Not Assessed"
    case single = "Single"
    case double = "Double"
    case triple = "Triple"

    var id: String { rawValue }

    var isAssessed: Bool { self != .notAssessed }

    /// Cases available for user selection (excludes notAssessed)
    static var selectableCases: [PaneType] { [.single, .double, .triple] }

    var uFactor: Double {
        switch self {
        case .notAssessed: return 0.30 // assume double-pane for calc
        case .single: return 1.10
        case .double: return 0.30
        case .triple: return 0.22
        }
    }

    var label: String {
        switch self {
        case .notAssessed: return "Not Assessed"
        case .single: return "Single Pane"
        case .double: return "Double Pane"
        case .triple: return "Triple Pane"
        }
    }

    var description: String {
        switch self {
        case .notAssessed: return "Tap the info button to assess pane type."
        case .single: return "One layer of glass. Common in pre-1980 homes. Poor insulator."
        case .double: return "Two layers with air/gas gap. Standard in modern homes. Good insulator."
        case .triple: return "Three layers with dual gas gaps. Best insulation, common in cold climates."
        }
    }

    var tip: String {
        "Put a pencil tip against the glass and count the reflections. 1 = single, 2 = double, 3 = triple."
    }
}

enum FrameMaterial: String, CaseIterable, Codable, Identifiable {
    case notAssessed = "Not Assessed"
    case aluminum = "Aluminum"
    case wood = "Wood"
    case vinyl = "Vinyl"
    case fiberglass = "Fiberglass"
    case composite = "Composite"

    var id: String { rawValue }

    var isAssessed: Bool { self != .notAssessed }

    static var selectableCases: [FrameMaterial] { [.aluminum, .wood, .vinyl, .fiberglass, .composite] }

    /// Thermal factor multiplier — higher = more heat transfer (worse)
    var thermalFactor: Double {
        switch self {
        case .notAssessed: return 1.00 // neutral default for calc
        case .aluminum: return 1.30
        case .wood: return 1.00
        case .vinyl: return 0.95
        case .fiberglass: return 0.92
        case .composite: return 0.90
        }
    }

    var description: String {
        switch self {
        case .notAssessed: return "Tap the info button to assess frame material."
        case .aluminum: return "Metal frames feel cold in winter. Common in older or budget homes."
        case .wood: return "Traditional frames with decent insulation. Requires maintenance."
        case .vinyl: return "Plastic frames with good insulation. Low maintenance, affordable."
        case .fiberglass: return "Strong and excellent insulation. Premium option."
        case .composite: return "Mix of materials for best thermal performance. Top tier."
        }
    }

    var icon: String {
        switch self {
        case .notAssessed: return "questionmark.circle"
        case .aluminum: return "rectangle.inset.filled"
        case .wood: return "tree"
        case .vinyl: return "square.dashed"
        case .fiberglass: return "shield.lefthalf.filled"
        case .composite: return "square.stack.3d.up"
        }
    }
}

enum WindowCondition: String, CaseIterable, Codable, Identifiable {
    case notAssessed = "Not Assessed"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var id: String { rawValue }

    var isAssessed: Bool { self != .notAssessed }

    static var selectableCases: [WindowCondition] { [.good, .fair, .poor] }

    /// Air leakage multiplier — higher = more leakage (worse)
    var leakageFactor: Double {
        switch self {
        case .notAssessed: return 1.00 // neutral default for calc
        case .good: return 1.00
        case .fair: return 1.15
        case .poor: return 1.35
        }
    }

    var description: String {
        switch self {
        case .notAssessed: return "Tap the info button to assess window condition."
        case .good: return "Seals tight, no drafts, glass is clear."
        case .fair: return "Minor drafts, some fog between panes, or doesn't close perfectly."
        case .poor: return "Drafty, foggy between panes, doesn't latch, or visible gaps."
        }
    }
}

// MARK: - WindowInfo

struct WindowInfo: Codable, Identifiable {
    var id: UUID = UUID()
    var direction: CardinalDirection = .east
    var size: WindowSize = .medium
    var paneType: PaneType = .double
    var frameMaterial: FrameMaterial = .vinyl
    var condition: WindowCondition = .good

    var isFullyAssessed: Bool {
        paneType.isAssessed && frameMaterial.isAssessed && condition.isAssessed
    }

    /// Effective U-factor combining pane type, frame material, and condition
    var effectiveUFactor: Double {
        paneType.uFactor * frameMaterial.thermalFactor * condition.leakageFactor
    }

    /// Heat gain BTU factoring in pane type, frame, and condition.
    /// Single-pane windows with aluminum frames in poor condition let through much more heat
    /// than triple-pane with composite frames in good condition.
    var heatGainBTU: Double {
        let baseHeatGain = direction.btuPerSqFt * size.sqFt
        // Normalize against a "standard" double-pane vinyl window (U=0.30 * 0.95 * 1.0 = 0.285)
        let standardUFactor: Double = 0.285
        let adjustmentRatio = effectiveUFactor / standardUFactor
        return baseHeatGain * adjustmentRatio
    }
}
