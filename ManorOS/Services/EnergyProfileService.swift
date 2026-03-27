import Foundation

// MARK: - Data Structures

struct EnergyBreakdownCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let annualCost: Double
    let percentage: Double
}

struct TopConsumer: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let annualCost: Double
    let source: String // "equipment" or "appliance"
}

struct BillComparison {
    let billBasedAnnualKWh: Double
    let estimatedAnnualKWh: Double
    let gapPercentage: Double
    let accuracyLabel: String // "Excellent"/"Good"/"Fair"/"Review Needed"
}

struct EnvelopeScore {
    let score: Double // 0-100
    let grade: String // A-F
    let details: [String] // ["Attic: Good", "Walls: Average", ...]
    let weakestArea: String?
}

struct EnergyProfile {
    let totalEstimatedAnnualCost: Double
    let electricityRate: Double
    let breakdown: [EnergyBreakdownCategory]
    let topConsumers: [TopConsumer]
    let billComparison: BillComparison?
    let envelopeScore: EnvelopeScore?
}

// MARK: - Service

enum EnergyProfileService {

    static func generateProfile(for home: Home) -> EnergyProfile {
        let rate = home.actualElectricityRate
        let gasRate = home.actualGasRate
        let sqFt = home.computedTotalSqFt > 0 ? home.computedTotalSqFt : 1500

        // --- Equipment costs grouped by category ---
        var hvacCost: Double = 0
        var waterHeatingCost: Double = 0
        var equipmentConsumers: [TopConsumer] = []

        for eq in home.equipment {
            let cost = EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum, efficiency: eq.estimatedEfficiency,
                homeSqFt: sqFt, climateZone: home.climateZoneEnum,
                electricityRate: rate, gasRate: gasRate
            )
            guard cost > 0 else { continue }

            switch eq.typeEnum {
            case .centralAC, .heatPump, .furnace, .windowUnit, .thermostat, .insulation, .windows:
                hvacCost += cost
            case .waterHeater, .waterHeaterTankless:
                waterHeatingCost += cost
            case .washer, .dryer:
                break // minimal — not categorized separately
            }

            if cost > 10 {
                equipmentConsumers.append(TopConsumer(
                    name: eq.typeEnum.rawValue,
                    icon: eq.typeEnum.icon,
                    annualCost: cost,
                    source: "equipment"
                ))
            }
        }

        // --- Appliance costs split into non-lighting / lighting ---
        var applianceCost: Double = 0
        var lightingCost: Double = 0
        var applianceConsumers: [TopConsumer] = []

        for appliance in home.appliances {
            let cost = appliance.annualCost(rate: rate)
            if appliance.categoryEnum.isLighting {
                lightingCost += cost
            } else {
                applianceCost += cost
            }

            if cost > 10 {
                applianceConsumers.append(TopConsumer(
                    name: appliance.name,
                    icon: appliance.categoryEnum.icon,
                    annualCost: cost,
                    source: "appliance"
                ))
            }
        }

        // --- Phantom load cost ---
        let phantomCost = home.totalPhantomAnnualKWh * rate

        // --- Build breakdown categories ---
        let totalCost = hvacCost + waterHeatingCost + applianceCost + lightingCost + phantomCost

        var breakdown: [EnergyBreakdownCategory] = []
        if hvacCost > 0 {
            breakdown.append(EnergyBreakdownCategory(
                name: "HVAC", icon: "snowflake",
                annualCost: hvacCost,
                percentage: totalCost > 0 ? hvacCost / totalCost * 100 : 0
            ))
        }
        if waterHeatingCost > 0 {
            breakdown.append(EnergyBreakdownCategory(
                name: "Water Heating", icon: "drop.fill",
                annualCost: waterHeatingCost,
                percentage: totalCost > 0 ? waterHeatingCost / totalCost * 100 : 0
            ))
        }
        if applianceCost > 0 {
            breakdown.append(EnergyBreakdownCategory(
                name: "Appliances", icon: "powerplug",
                annualCost: applianceCost,
                percentage: totalCost > 0 ? applianceCost / totalCost * 100 : 0
            ))
        }
        if lightingCost > 0 {
            breakdown.append(EnergyBreakdownCategory(
                name: "Lighting", icon: "lightbulb",
                annualCost: lightingCost,
                percentage: totalCost > 0 ? lightingCost / totalCost * 100 : 0
            ))
        }
        if phantomCost > 5 {
            breakdown.append(EnergyBreakdownCategory(
                name: "Standby", icon: "moon.zzz",
                annualCost: phantomCost,
                percentage: totalCost > 0 ? phantomCost / totalCost * 100 : 0
            ))
        }

        // --- Top consumers (merged, sorted, top 5) ---
        let allConsumers = (equipmentConsumers + applianceConsumers)
            .sorted { $0.annualCost > $1.annualCost }
        let topConsumers = Array(allConsumers.prefix(5))

        // --- Bill comparison ---
        let billComparison = buildBillComparison(for: home, estimatedTotalCost: totalCost, rate: rate)

        // --- Envelope score ---
        let envelopeScore = scoreEnvelope(for: home)

        return EnergyProfile(
            totalEstimatedAnnualCost: totalCost,
            electricityRate: rate,
            breakdown: breakdown,
            topConsumers: topConsumers,
            billComparison: billComparison,
            envelopeScore: envelopeScore
        )
    }

    // MARK: - Bill Comparison

    private static func buildBillComparison(for home: Home, estimatedTotalCost: Double, rate: Double) -> BillComparison? {
        guard let billKWh = home.billBasedAnnualKWh, billKWh > 0 else { return nil }

        // Convert estimated cost to kWh (approximate — ignores gas equipment, but close enough for comparison)
        let estimatedKWh = rate > 0 ? estimatedTotalCost / rate : 0
        guard estimatedKWh > 0 else { return nil }

        let gap = abs(billKWh - estimatedKWh) / billKWh * 100
        let label: String
        switch gap {
        case 0..<10: label = "Excellent"
        case 10..<25: label = "Good"
        case 25..<40: label = "Fair"
        default: label = "Review Needed"
        }

        return BillComparison(
            billBasedAnnualKWh: billKWh,
            estimatedAnnualKWh: estimatedKWh,
            gapPercentage: gap,
            accuracyLabel: label
        )
    }

    // MARK: - Envelope Scoring

    static func scoreEnvelope(for home: Home) -> EnvelopeScore? {
        guard let env = home.envelope else { return nil }

        // 5 factors x 20 points each = 100 max
        var total: Double = 0
        var details: [String] = []
        var weakest: (String, Double)? = nil

        let atticScore = insulationScore(env.atticInsulation)
        total += atticScore
        details.append("Attic: \(env.atticInsulation.rawValue)")
        if weakest == nil || atticScore < (weakest?.1 ?? .greatestFiniteMagnitude) {
            weakest = ("Attic Insulation", atticScore)
        }

        let wallScore = insulationScore(env.wallInsulation)
        total += wallScore
        details.append("Walls: \(env.wallInsulation.rawValue)")
        if wallScore < (weakest?.1 ?? 999) { weakest = ("Wall Insulation", wallScore) }

        let basementScore = basementInsulationScore(env.basementInsulation)
        total += basementScore
        details.append("Basement: \(env.basementInsulation)")
        if basementScore < (weakest?.1 ?? 999) { weakest = ("Basement Insulation", basementScore) }

        let airScore = sealingScore(env.airSealing)
        total += airScore
        details.append("Air Sealing: \(env.airSealing)")
        if airScore < (weakest?.1 ?? 999) { weakest = ("Air Sealing", airScore) }

        let weatherScore = sealingScore(env.weatherstripping)
        total += weatherScore
        details.append("Weatherstripping: \(env.weatherstripping)")
        if weatherScore < (weakest?.1 ?? 999) { weakest = ("Weatherstripping", weatherScore) }

        let grade: String
        switch total {
        case 85...100: grade = "A"
        case 70..<85: grade = "B"
        case 55..<70: grade = "C"
        case 40..<55: grade = "D"
        default: grade = "F"
        }

        return EnvelopeScore(
            score: total,
            grade: grade,
            details: details,
            weakestArea: weakest?.0
        )
    }

    private static func insulationScore(_ quality: InsulationQuality) -> Double {
        switch quality {
        case .good: return 20
        case .average, .unknown: return 12
        case .poor: return 5
        }
    }

    private static func basementInsulationScore(_ value: String) -> Double {
        switch value {
        case "Full": return 20
        case "Partial": return 12
        default: return 5 // "Uninsulated"
        }
    }

    private static func sealingScore(_ value: String) -> Double {
        switch value {
        case "Good": return 20
        case "Fair": return 12
        default: return 5 // "Poor"
        }
    }
}
