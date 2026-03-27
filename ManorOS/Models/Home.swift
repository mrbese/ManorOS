import Foundation
import SwiftData

enum HomeType: String, CaseIterable, Codable, Identifiable {
    case house = "House"
    case townhouse = "Townhouse"
    case apartment = "Apartment/Condo"
    var id: String { rawValue }
}

enum YearRange: String, CaseIterable, Codable, Identifiable {
    case pre1970 = "Pre-1970"
    case y1970to1989 = "1970 to 1989"
    case y1990to2005 = "1990 to 2005"
    case y2006to2015 = "2006 to 2015"
    case y2016plus = "2016+"

    var id: String { rawValue }
}

@Model
final class Home {
    var id: UUID
    var name: String
    var address: String?
    var yearBuilt: String // YearRange.rawValue
    var totalSqFt: Double?
    var climateZone: String // ClimateZone.rawValue
    @Relationship(deleteRule: .cascade, inverse: \Room.home) var rooms: [Room]
    @Relationship(deleteRule: .cascade, inverse: \Equipment.home) var equipment: [Equipment]
    @Relationship(deleteRule: .cascade, inverse: \Appliance.home) var appliances: [Appliance]
    @Relationship(deleteRule: .cascade, inverse: \EnergyBill.home) var energyBills: [EnergyBill]
    @Relationship(deleteRule: .cascade, inverse: \AuditProgress.home) var auditProgress: [AuditProgress]
    var envelopeData: Data?
    var homeType: String?        // HomeType.rawValue (nil for legacy homes)
    var bedroomCount: Int?       // from onboarding (nil for legacy homes)
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String = "",
        address: String? = nil,
        yearBuilt: YearRange = .y1990to2005,
        totalSqFt: Double? = nil,
        climateZone: ClimateZone = .moderate,
        homeType: HomeType? = nil,
        bedroomCount: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.yearBuilt = yearBuilt.rawValue
        self.totalSqFt = totalSqFt
        self.climateZone = climateZone.rawValue
        self.homeType = homeType?.rawValue
        self.bedroomCount = bedroomCount
        self.rooms = []
        self.equipment = []
        self.appliances = []
        self.energyBills = []
        self.auditProgress = []
        self.envelopeData = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var homeTypeEnum: HomeType? {
        guard let homeType else { return nil }
        return HomeType(rawValue: homeType)
    }

    var yearBuiltEnum: YearRange {
        YearRange(rawValue: yearBuilt) ?? .y1990to2005
    }

    var climateZoneEnum: ClimateZone {
        ClimateZone(rawValue: climateZone) ?? .moderate
    }

    var computedTotalSqFt: Double {
        if let manual = totalSqFt, manual > 0 { return manual }
        return rooms.reduce(0) { $0 + $1.squareFootage }
    }

    var totalBTU: Double {
        rooms.reduce(0) { $0 + $1.calculatedBTU }
    }

    // MARK: - Appliance Aggregates

    /// Total annual kWh from all tracked appliances (active use only)
    var totalApplianceAnnualKWh: Double {
        appliances.reduce(0) { $0 + $1.annualKWh }
    }

    /// Total phantom/standby watts across all appliances right now
    var totalPhantomLoadWatts: Double {
        appliances.reduce(0) { $0 + $1.categoryEnum.phantomWatts * Double($1.quantity) }
    }

    /// Total annual kWh wasted on phantom/standby loads
    var totalPhantomAnnualKWh: Double {
        appliances.reduce(0) { $0 + $1.phantomAnnualKWh }
    }

    // MARK: - Bill Aggregates

    /// Annual kWh from bills (average of all uploaded bills, annualized)
    var billBasedAnnualKWh: Double? {
        let annualized = energyBills.compactMap(\.annualizedKWh)
        guard !annualized.isEmpty else { return nil }
        return annualized.reduce(0, +) / Double(annualized.count)
    }

    /// Actual electricity rate derived from bills, then user-set rate in Settings, then app default
    var actualElectricityRate: Double {
        let rates = energyBills.map(\.computedRate).filter { $0 > 0 }
        if !rates.isEmpty {
            return rates.reduce(0, +) / Double(rates.count)
        }
        let userRate = UserDefaults.standard.double(forKey: "electricityRate")
        return userRate > 0 ? userRate : Constants.defaultElectricityRate
    }

    /// Gas rate from user Settings or app default
    var actualGasRate: Double {
        let userRate = UserDefaults.standard.double(forKey: "gasRate")
        return userRate > 0 ? userRate : Constants.defaultGasRate
    }

    // MARK: - Audit

    /// Current audit progress (first, since there's one per home)
    var currentAudit: AuditProgress? {
        auditProgress.first
    }

    // MARK: - Envelope

    var envelope: EnvelopeInfo? {
        get {
            guard let data = envelopeData else { return nil }
            return try? JSONDecoder().decode(EnvelopeInfo.self, from: data)
        }
        set {
            envelopeData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}

// MARK: - EnvelopeInfo

struct EnvelopeInfo: Codable, Equatable {
    var atticInsulation: InsulationQuality
    var wallInsulation: InsulationQuality
    var basementInsulation: String // "Uninsulated", "Partial", "Full"
    var airSealing: String // "Good", "Fair", "Poor"
    var weatherstripping: String // "Good", "Fair", "Poor"
    var notes: String?

    static let basementOptions = ["Uninsulated", "Partial", "Full"]
    static let sealingOptions = ["Good", "Fair", "Poor"]

    init(
        atticInsulation: InsulationQuality = .average,
        wallInsulation: InsulationQuality = .average,
        basementInsulation: String = "Uninsulated",
        airSealing: String = "Fair",
        weatherstripping: String = "Fair",
        notes: String? = nil
    ) {
        self.atticInsulation = atticInsulation
        self.wallInsulation = wallInsulation
        self.basementInsulation = basementInsulation
        self.airSealing = airSealing
        self.weatherstripping = weatherstripping
        self.notes = notes
    }
}
