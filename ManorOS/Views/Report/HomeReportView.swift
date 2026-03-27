import SwiftUI
import UIKit

struct HomeReportView: View {
    let home: Home
    var isEmbedded: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var gradeRevealed = false
    @State private var showingPDFShare = false
    @State private var pdfURL: URL?
    @StateObject private var stateDetector = StateDetectionService()
    @State private var isGeneratingPDF = false

    // Cached computations (refresh when `home.updatedAt` changes)
    @State private var cachedGrade: EfficiencyGrade?
    @State private var cachedProfile: EnergyProfile?
    @State private var cachedUpgradesByEquipment: [(equipment: Equipment, upgrades: [UpgradeRecommendation])] = []

    private var grade: EfficiencyGrade {
        cachedGrade ?? GradingEngine.grade(for: home)
    }

    private var profile: EnergyProfile {
        cachedProfile ?? EnergyProfileService.generateProfile(for: home)
    }

    private var homeRecommendations: [Recommendation] {
        RecommendationEngine.generateHomeRecommendations(for: home)
    }

    private var sqFt: Double {
        home.computedTotalSqFt > 0 ? home.computedTotalSqFt : 1500
    }

    private var isUsingSqFtFallback: Bool {
        home.computedTotalSqFt <= 0
    }

    // All upgrade recommendations grouped by equipment
    private var allUpgradesByEquipment: [(equipment: Equipment, upgrades: [UpgradeRecommendation])] {
        cachedUpgradesByEquipment
    }

    // Best-tier recommendations only (for summary stats)
    private var bestTierRecommendations: [UpgradeRecommendation] {
        allUpgradesByEquipment.compactMap { $0.upgrades.first(where: { $0.tier == .best }) }
    }

    private func refreshCaches() {
        cachedGrade = GradingEngine.grade(for: home)
        cachedProfile = EnergyProfileService.generateProfile(for: home)
        cachedUpgradesByEquipment = home.equipment.compactMap { eq in
            let ups = UpgradeEngine.generateUpgrades(
                for: eq,
                climateZone: home.climateZoneEnum,
                homeSqFt: sqFt,
                electricityRate: home.actualElectricityRate,
                gasRate: home.actualGasRate
            )
            guard !ups.isEmpty else { return nil }
            let bestTier = ups.first(where: { $0.tier == .best })
            guard (bestTier?.annualSavings ?? 0) > 10 else { return nil }
            return (equipment: eq, upgrades: ups)
        }.sorted { a, b in
            let aPB = a.upgrades.first(where: { $0.tier == .best })?.paybackYears ?? 999
            let bPB = b.upgrades.first(where: { $0.tier == .best })?.paybackYears ?? 999
            return aPB < bPB
        }
    }

    private var totalCurrentCost: Double {
        home.equipment.reduce(0) { sum, eq in
            sum + EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum, efficiency: eq.estimatedEfficiency,
                homeSqFt: sqFt, climateZone: home.climateZoneEnum
            )
        }
    }

    private var totalUpgradedCost: Double {
        home.equipment.reduce(0) { sum, eq in
            let spec = EfficiencyDatabase.lookup(type: eq.typeEnum, age: eq.ageRangeEnum)
            return sum + EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum, efficiency: spec.bestInClass,
                homeSqFt: sqFt, climateZone: home.climateZoneEnum
            )
        }
    }

    private var totalSavings: Double {
        max(totalCurrentCost - totalUpgradedCost, 0)
    }

    private var taxCredits: (total25C: Double, total25D: Double, grandTotal: Double) {
        UpgradeEngine.aggregateTaxCredits(from: allUpgradesByEquipment.map(\.upgrades))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summarySection
                if home.equipment.isEmpty && !home.rooms.isEmpty {
                    roomsOnlySummarySection
                }
                if !home.equipment.isEmpty {
                    costSection
                }
                if !profile.breakdown.isEmpty {
                    energyProfileSection
                }
                if profile.billComparison != nil {
                    billReconciliationSection
                }
                if !profile.topConsumers.isEmpty {
                    applianceHighlightsSection
                }
                if profile.envelopeScore != nil {
                    envelopeSummarySection
                }
                if !allUpgradesByEquipment.isEmpty {
                    upgradeSummaryStats
                    upgradesSection
                }
                if !homeRecommendations.isEmpty {
                    quickWinsSection
                }
                if taxCredits.grandTotal > 0 {
                    taxCreditSection
                }
                if stateDetector.isDetecting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Detecting your state for rebates...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
                }
                if let state = stateDetector.detectedState {
                    rebateSection(state: state)
                }
                if !home.equipment.isEmpty {
                    batterySynergySection
                }
                shareSection
                if !isEmbedded {
                    doneSection
                }
            }
            .padding()
        }
        .navigationTitle("Home Report")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            gradeRevealed = true
            refreshCaches()
            stateDetector.detectState()
            AnalyticsService.track(.reportViewed, properties: [
                "homeName": home.name.isEmpty ? "Unnamed" : home.name
            ])
        }
        .onChange(of: home.updatedAt) { _, _ in
            refreshCaches()
        }
        .sensoryFeedback(.success, trigger: gradeRevealed)
        .sheet(isPresented: $showingPDFShare) {
            if let url = pdfURL {
                ShareSheetView(items: [url])
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(home.name.isEmpty ? "Home Assessment" : home.name)
                        .font(.title3.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    if home.computedTotalSqFt > 0 {
                        Text("\(Int(home.computedTotalSqFt)) sq ft")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    if home.equipment.isEmpty {
                        Text("N/A")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.manor.onPrimary.opacity(0.6))
                            .accessibilityLabel("Efficiency grade not available — add equipment to get a grade")
                        Text("Add equipment")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text(grade.rawValue)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.manor.onPrimary)
                            .accessibilityLabel("Efficiency grade \(grade.rawValue)")
                        Text("Grade")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            Divider().background(.white.opacity(0.3))

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(home.rooms.count)")
                        .font(.title2.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("Rooms")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                VStack(spacing: 2) {
                    Text("\(home.equipment.count)")
                        .font(.title2.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("Equipment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if home.totalBTU > 0 {
                    VStack(spacing: 2) {
                        Text("\(Int(home.totalBTU / 12000))")
                            .font(.title2.bold())
                            .foregroundStyle(Color.manor.onPrimary)
                        Text("Tons HVAC")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            if !home.equipment.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(gradeConfidence.color)
                        .frame(width: 6, height: 6)
                    Text(gradeConfidence.label)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(grade.summary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 20))
    }

    private var gradeConfidence: (label: String, color: Color) {
        var sources = 0
        if !home.equipment.isEmpty { sources += 1 }
        if !home.appliances.isEmpty { sources += 1 }
        if home.envelope != nil { sources += 1 }

        switch sources {
        case 3: return ("High confidence", Color.manor.success)
        case 2: return ("Medium confidence", Color.manor.warning)
        case 1: return ("Low confidence", Color.manor.warning)
        default: return ("Incomplete data", .secondary)
        }
    }

    // MARK: - Rooms-Only Summary (shown when rooms exist but no equipment)

    private var roomsOnlySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.split.2x2")
                    .foregroundStyle(Color.manor.primary)
                Text("Room Summary")
                    .font(.headline)
            }

            if home.computedTotalSqFt > 0 {
                infoRow("Total square footage", "\(Int(home.computedTotalSqFt)) sq ft")
            }

            if home.totalBTU > 0 {
                infoRow("Total BTU load", "\(Int(home.totalBTU / 1000))k BTU")
                infoRow("Estimated HVAC tonnage", String(format: "%.1f tons", home.totalBTU / 12000))
            }

            infoRow("Rooms scanned", "\(home.rooms.filter { $0.squareFootage > 0 }.count) of \(home.rooms.count)")

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Color.manor.primary)
                Text("Add your HVAC equipment to see energy cost estimates and upgrade recommendations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Cost

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Cost Estimate")
                .font(.headline)

            if isUsingSqFtFallback {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.manor.info)
                    Text("Estimates assume 1,500 sq ft. Scan your rooms for more accurate results.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.manor.info.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Text("Current Annual Cost")
                    .font(.subheadline)
                Spacer()
                Text("$\(Int(totalCurrentCost).formatted())/yr")
                    .font(.title3.bold())
            }

            if totalSavings > 0 {
                HStack {
                    Text("After All Upgrades")
                        .font(.subheadline)
                    Spacer()
                    Text("$\(Int(totalUpgradedCost).formatted())/yr")
                        .font(.subheadline)
                        .foregroundStyle(Color.manor.success)
                }

                Divider()

                HStack {
                    Text("Potential Annual Savings")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("$\(Int(totalSavings).formatted())/yr")
                        .font(.title2.bold())
                        .foregroundStyle(Color.manor.success)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Upgrade Summary Stats

    private var upgradeSummaryStats: some View {
        let totalSav = bestTierRecommendations.reduce(0.0) { $0 + $1.annualSavings }
        let totalCostLow = bestTierRecommendations.reduce(0.0) { $0 + $1.costLow }
        let totalCostHigh = bestTierRecommendations.reduce(0.0) { $0 + $1.costHigh }
        let totalCredits = taxCredits.grandTotal
        let afterCreditsLow = max(totalCostLow - totalCredits, 0)
        let afterCreditsHigh = max(totalCostHigh - totalCredits, 0)
        let avgPayback = totalSav > 0 ? ((totalCostLow + totalCostHigh) / 2) / totalSav : 0
        let afterCreditsPayback = totalSav > 0 ? ((afterCreditsLow + afterCreditsHigh) / 2) / totalSav : 0

        return VStack(alignment: .leading, spacing: 10) {
            Text("Upgrade Investment Summary")
                .font(.headline)

            statRow("Total potential savings", "$\(Int(totalSav).formatted())/yr", color: Color.manor.success)
            statRow("Total investment range", "$\(Int(totalCostLow).formatted()) – $\(Int(totalCostHigh).formatted())", color: .primary)
            statRow("Average payback period", String(format: "%.1f years", avgPayback), color: avgPayback < 5 ? Color.manor.success : Color.manor.warning)

            if totalCredits > 0 {
                Divider()
                statRow("After tax credits", "$\(Int(afterCreditsLow).formatted()) – $\(Int(afterCreditsHigh).formatted())", color: Color.manor.info)
                statRow("Effective payback", String(format: "%.1f years", afterCreditsPayback), color: afterCreditsPayback < 5 ? Color.manor.success : Color.manor.warning)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    private func statRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }

    // MARK: - Upgrades

    private var upgradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prioritized Upgrades")
                .font(.headline)

            Text("Sorted by payback period. Tap to see all tiers.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(allUpgradesByEquipment.enumerated()), id: \.offset) { _, item in
                upgradeEquipmentRow(item.equipment, upgrades: item.upgrades)
            }
        }
    }

    private func upgradeEquipmentRow(_ eq: Equipment, upgrades: [UpgradeRecommendation]) -> some View {
        let best = upgrades.first(where: { $0.tier == .best })

        return DisclosureGroup {
            VStack(spacing: 8) {
                ForEach(upgrades) { rec in
                    tierCard(rec)
                }
            }
            .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: eq.typeEnum.icon)
                        .foregroundStyle(Color.manor.primary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eq.typeEnum.rawValue)
                            .font(.subheadline.bold())
                        Text("Current: \(String(format: "%.1f", eq.estimatedEfficiency)) \(eq.typeEnum.efficiencyUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let b = best, let pb = b.paybackYears {
                        priorityBadge(payback: pb)
                    }
                }

                if let b = best {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Best Savings")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("$\(Int(b.annualSavings))/yr")
                                .font(.caption.bold())
                                .foregroundStyle(Color.manor.success)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Cost Range")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("$\(Int(b.costLow).formatted())–$\(Int(b.costHigh).formatted())")
                                .font(.caption.bold())
                        }
                        if let pb = b.paybackYears {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Payback")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f yr", pb))
                                    .font(.caption.bold())
                            }
                        }
                        if b.taxCreditEligible && b.taxCreditAmount > 0 {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Credit")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("$\(Int(b.taxCreditAmount))")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.manor.info)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 6, y: 2)
    }

    private func tierCard(_ rec: UpgradeRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                tierBadge(rec.tier)
                Text(rec.title)
                    .font(.caption.bold())
                Spacer()
            }

            if rec.alreadyMeetsThisTier {
                Text("Your equipment already meets this tier")
                    .font(.caption2)
                    .foregroundStyle(Color.manor.success)
            }

            Text(rec.explanation)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Cost")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("$\(Int(rec.costLow).formatted())–$\(Int(rec.costHigh).formatted())")
                        .font(.caption2.bold())
                }
                if rec.annualSavings > 0 {
                    VStack(alignment: .leading) {
                        Text("Savings")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("$\(Int(rec.annualSavings))/yr")
                            .font(.caption2.bold()).foregroundStyle(Color.manor.success)
                    }
                }
                if let pb = rec.paybackYears {
                    VStack(alignment: .leading) {
                        Text("Payback")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(String(format: "%.1f yr", pb))
                            .font(.caption2.bold())
                    }
                }
                if rec.taxCreditEligible && rec.taxCreditAmount > 0 {
                    VStack(alignment: .leading) {
                        Text("Tax Credit")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("$\(Int(rec.taxCreditAmount))")
                            .font(.caption2.bold()).foregroundStyle(Color.manor.info)
                    }
                }
            }
        }
        .padding(10)
        .background(tierBackgroundColor(rec.tier).opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func tierBadge(_ tier: UpgradeTier) -> some View {
        Text(tier.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(Color.manor.onPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tierBackgroundColor(tier), in: Capsule())
    }

    private func tierBackgroundColor(_ tier: UpgradeTier) -> Color {
        switch tier {
        case .good: return Color.manor.info
        case .better: return Color.manor.accent
        case .best: return Color.manor.success
        }
    }

    private func priorityBadge(payback: Double) -> some View {
        let (label, color): (String, Color) = {
            if payback < 3 { return ("Quick Win", .green) }
            if payback < 7 { return ("Strong Investment", .orange) }
            return ("Long Term", .secondary)
        }()

        return Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Energy Profile Breakdown

    @ViewBuilder
    private var energyProfileSection: some View {
        let bp = profile.breakdown
        let total = profile.totalEstimatedAnnualCost

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.manor.primary)
                Text("Energy Breakdown")
                    .font(.headline)
            }

            // Stacked bar
            if total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(bp) { cat in
                            let width = max(geo.size.width * cat.percentage / 100, 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(categoryColor(cat.name))
                                .frame(width: width, height: 20)
                                .accessibilityLabel("\(cat.name): \(Int(cat.percentage)) percent, $\(Int(cat.annualCost)) per year")
                        }
                    }
                }
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityElement(children: .combine)
            }

            // Legend
            ForEach(bp) { cat in
                HStack(spacing: 8) {
                    Circle()
                        .fill(categoryColor(cat.name))
                        .frame(width: 10, height: 10)
                    Image(systemName: cat.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(cat.name)
                        .font(.subheadline)
                    Spacer()
                    Text("$\(Int(cat.annualCost))/yr")
                        .font(.subheadline.bold())
                    Text("(\(Int(cat.percentage))%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(cat.name): $\(Int(cat.annualCost)) per year, \(Int(cat.percentage)) percent of total")
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    private func categoryColor(_ name: String) -> Color {
        switch name {
        case "HVAC": return .blue
        case "Water Heating": return .cyan
        case "Appliances": return .orange
        case "Lighting": return .yellow
        case "Standby": return .gray
        default: return .secondary
        }
    }

    // MARK: - Bill Reconciliation

    @ViewBuilder
    private var billReconciliationSection: some View {
        if let comparison = profile.billComparison {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(Color.manor.primary)
                    Text("Bill vs. Estimate")
                        .font(.headline)
                }

                HStack {
                    Text("Actual (from bills)")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(comparison.billBasedAnnualKWh).formatted()) kWh/yr")
                        .font(.subheadline.bold())
                }
                HStack {
                    Text("Estimated (from audit)")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(comparison.estimatedAnnualKWh).formatted()) kWh/yr")
                        .font(.subheadline.bold())
                }

                Divider()

                HStack {
                    Text("Accuracy")
                        .font(.subheadline)
                    Spacer()
                    Text(comparison.accuracyLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(accuracyColor(comparison.accuracyLabel))
                    Text("(\(Int(comparison.gapPercentage))% gap)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if comparison.gapPercentage >= 25 {
                    Text("A large gap may indicate untracked loads (pool pump, workshop, etc.) or seasonal variation. Adding more bills improves accuracy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
        }
    }

    private func accuracyColor(_ label: String) -> Color {
        switch label {
        case "Excellent": return .green
        case "Good": return .blue
        case "Fair": return .orange
        default: return .red
        }
    }

    // MARK: - Appliance Highlights

    @ViewBuilder
    private var applianceHighlightsSection: some View {
        let consumers = profile.topConsumers
        let phantomKWh = home.totalPhantomAnnualKWh
        let phantomCost = phantomKWh * profile.electricityRate

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.manor.primary)
                Text("Top Energy Consumers")
                    .font(.headline)
            }

            ForEach(Array(consumers.enumerated()), id: \.element.id) { index, consumer in
                HStack(spacing: 10) {
                    Text("#\(index + 1)")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                        .frame(width: 22, height: 22)
                        .background(Color.manor.primary.opacity(0.8), in: Circle())
                    Image(systemName: consumer.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(consumer.name)
                        .font(.subheadline)
                    Spacer()
                    Text("$\(Int(consumer.annualCost))/yr")
                        .font(.subheadline.bold())
                }
            }

            if phantomKWh > 50 {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Phantom/Standby Waste")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(phantomKWh)) kWh · $\(Int(phantomCost))/yr")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.manor.warning)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Envelope Summary

    @ViewBuilder
    private var envelopeSummarySection: some View {
        if let envScore = profile.envelopeScore {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(Color.manor.primary)
                    Text("Building Envelope")
                        .font(.headline)
                    Spacer()
                    Text(envScore.grade)
                        .font(.title2.bold())
                        .foregroundStyle(envelopeGradeColor(envScore.grade))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(envelopeGradeColor(envScore.grade).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }

                ForEach(envScore.details, id: \.self) { detail in
                    let parts = detail.split(separator: ":", maxSplits: 1)
                    HStack {
                        Text(String(parts.first ?? ""))
                            .font(.subheadline)
                        Spacer()
                        Text(String(parts.last ?? "").trimmingCharacters(in: .whitespaces))
                            .font(.subheadline.bold())
                            .foregroundStyle(envelopeDetailColor(String(parts.last ?? "")))
                    }
                }

                if let weakest = envScore.weakestArea {
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Color.manor.warning)
                        Text("Priority: \(weakest)")
                            .font(.caption)
                            .foregroundStyle(Color.manor.warning)
                    }
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
        }
    }

    private func envelopeGradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .yellow
        case "D": return .orange
        default: return .red
        }
    }

    private func envelopeDetailColor(_ value: String) -> Color {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        switch trimmed {
        case "Good", "Full": return .green
        case "Average", "Fair", "Partial": return .orange
        default: return .red
        }
    }

    // MARK: - Quick Wins

    @ViewBuilder
    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.manor.primary)
                Text("Quick Wins & Tips")
                    .font(.headline)
            }

            ForEach(homeRecommendations) { rec in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: rec.icon)
                        .font(.subheadline)
                        .foregroundStyle(Color.manor.primary)
                        .frame(width: 24, alignment: .center)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rec.title)
                            .font(.subheadline.bold())
                        Text(rec.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let savings = rec.estimatedSavings {
                            Text(savings)
                                .font(.caption.bold())
                                .foregroundStyle(Color.manor.success)
                        }
                    }
                }
                if rec.id != homeRecommendations.last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Tax Credit Summary

    private var taxCreditSection: some View {
        let credits = taxCredits

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .foregroundStyle(Color.manor.info)
                Text("Federal Tax Credits")
                    .font(.headline)
            }

            if credits.total25C > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IRS Section 25C — Energy Efficient Home Improvement")
                        .font(.caption.bold())
                    Text("Eligible credits: $\(Int(credits.total25C))")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.manor.info)
                    Text("Annual cap: $3,200 per year")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if credits.total25D > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IRS Section 25D — Residential Clean Energy (30%)")
                        .font(.caption.bold())
                    Text("Eligible credits: $\(Int(credits.total25D))")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.manor.info)
                    Text("No annual cap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text("Total Potential Credits")
                    .font(.subheadline.bold())
                Spacer()
                Text("$\(Int(credits.grandTotal).formatted())")
                    .font(.title3.bold())
                    .foregroundStyle(Color.manor.info)
            }

            Text("Tax credits are subject to eligibility requirements and may change. Consult a qualified tax professional before making purchasing decisions based on tax incentives.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Link(destination: URL(string: "https://www.irs.gov/credits-deductions/energy-efficient-home-improvement-credit")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                        Text("Learn more at IRS.gov")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.manor.primary)
                }

                Text("Federal tax credits available through 2032 under the Inflation Reduction Act.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Rebates

    private func rebateSection(state: USState) -> some View {
        let matched = RebateService.matchRebates(for: home, state: state)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.arrow.circlepath")
                    .foregroundStyle(Color.manor.success)
                Text("State & Utility Rebates")
                    .font(.headline)
            }

            Text("Available in \(state.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if matched.isEmpty {
                Text("No matching rebates found for your equipment in \(state.rawValue). Check DSIRE for the latest programs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matched) { rebate in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rebate.title)
                            .font(.subheadline.bold())
                        Text(rebate.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text(rebate.amountDescription)
                                .font(.caption.bold())
                                .foregroundStyle(Color.manor.success)
                            Spacer()
                            Text(rebate.programName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let url = URL(string: rebate.url) {
                            Link("View Program Details", destination: url)
                                .font(.caption)
                        }
                        if let expNote = rebate.expirationNote {
                            Text(expNote)
                                .font(.caption2)
                                .foregroundStyle(Color.manor.warning)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            Divider()

            // dsireusa.org is a known-good URL
            Link(destination: URL(string: "https://www.dsireusa.org")!) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("Search All Programs on DSIRE")
                        .font(.subheadline.bold())
                }
            }

            Text("Rebate availability and amounts change frequently. Always verify eligibility directly with the program administrator before making purchasing decisions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Battery Synergy

    private var batterySynergySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "battery.100.bolt")
                    .foregroundStyle(Color.manor.primary)
                Text("Battery Synergy")
                    .font(.headline)
            }

            let currentBaseLoad = sqFt * 5.0 / 1500.0
            let savingsRatio = totalSavings > 0 ? totalSavings / max(totalCurrentCost, 1) : 0.15

            // Factor in insulation + HVAC upgrade load reductions from recommendations
            let hasInsulationUpgrade = allUpgradesByEquipment.contains { $0.equipment.typeEnum == .insulation }
            let hasHVACUpgrade = allUpgradesByEquipment.contains { [.centralAC, .heatPump, .furnace].contains($0.equipment.typeEnum) }
            let bonusReduction = (hasInsulationUpgrade ? 0.05 : 0) + (hasHVACUpgrade ? 0.08 : 0)
            let totalReduction = min(savingsRatio * 0.6 + bonusReduction, 0.5)
            let upgradedBaseLoad = currentBaseLoad * (1.0 - totalReduction)
            let exportGain = currentBaseLoad - upgradedBaseLoad

            VStack(alignment: .leading, spacing: 8) {
                infoRow("Current estimated base load", "\(String(format: "%.1f", currentBaseLoad)) kW")
                infoRow("Estimated base load after upgrades", "\(String(format: "%.1f", upgradedBaseLoad)) kW")
                infoRow("Additional battery export capacity", "\(String(format: "%.1f", exportGain)) kW")

                let lowRevenue = Int(exportGain * 50) // ~50 hours at $2/kWh
                let highRevenue = Int(exportGain * 250) // ~50 hours at $5/kWh
                if lowRevenue > 0 {
                    infoRow("Additional grid export revenue", "$\(lowRevenue) to $\(highRevenue)/yr per battery")
                }
            }

            Text("Reducing your home's energy waste frees up more battery capacity for grid export during high-demand events when electricity prices spike to $2,000-$5,000/MWh. This makes home battery systems (Pila Energy, Tesla Powerwall, Base Power) significantly more valuable.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    // MARK: - Share

    private var shareSection: some View {
        VStack(spacing: 12) {
            ShareLink(item: generateReportText()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Report")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color.manor.onPrimary)
            }
            .accessibilityLabel("Share report as text")

            Button {
                guard !isGeneratingPDF else { return }
                isGeneratingPDF = true
                Task {
                    let url = await ReportPDFGenerator.savePDFAsync(for: home)
                    await MainActor.run {
                        isGeneratingPDF = false
                        if let url {
                            pdfURL = url
                            showingPDFShare = true
                            AnalyticsService.track(.pdfExported, properties: [
                                "homeName": home.name.isEmpty ? "Unnamed" : home.name
                            ])
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "doc.richtext")
                    if isGeneratingPDF {
                        Text("Generating PDF…")
                    } else {
                        Text("Share as PDF")
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.primary)
            }
            .accessibilityLabel("Export PDF report")
            .disabled(isGeneratingPDF)
        }
    }

    private var doneSection: some View {
        Button {
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle")
                Text("Back to Home")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Color.manor.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.manor.primary, lineWidth: 1.5)
            )
        }
        .padding(.top, 8)
    }

    private func generateReportText() -> String {
        var parts: [String] = []
        parts.append("MANOR OS HOME ENERGY REPORT")
        parts.append("=".repeated(40))
        parts.append("")
        parts.append("Home: \(home.name)")
        if let addr = home.address { parts.append("Address: \(addr)") }
        if home.computedTotalSqFt > 0 { parts.append("Total Area: \(Int(home.computedTotalSqFt)) sq ft") }
        parts.append("Climate Zone: \(home.climateZoneEnum.rawValue)")
        parts.append("Efficiency Grade: \(grade.rawValue)")
        parts.append("")

        if !home.equipment.isEmpty {
            parts.append("ENERGY COST ESTIMATE")
            parts.append("-".repeated(30))
            parts.append("Current Annual Cost: $\(Int(totalCurrentCost))")
            parts.append("After Upgrades: $\(Int(totalUpgradedCost))")
            parts.append("Potential Savings: $\(Int(totalSavings))/yr")
            parts.append("")
        }

        // Energy breakdown
        let bp = profile.breakdown
        if bp.count > 1 {
            parts.append("ENERGY BREAKDOWN")
            parts.append("-".repeated(30))
            for cat in bp {
                parts.append("- \(cat.name): $\(Int(cat.annualCost))/yr (\(Int(cat.percentage))%)")
            }
            parts.append("")
        }

        // Bill comparison
        if let comparison = profile.billComparison {
            parts.append("BILL VS. ESTIMATE")
            parts.append("-".repeated(30))
            parts.append("Actual (from bills): \(Int(comparison.billBasedAnnualKWh)) kWh/yr")
            parts.append("Estimated (from audit): \(Int(comparison.estimatedAnnualKWh)) kWh/yr")
            parts.append("Accuracy: \(comparison.accuracyLabel) (\(Int(comparison.gapPercentage))% gap)")
            parts.append("")
        }

        // Envelope
        if let envScore = profile.envelopeScore {
            parts.append("BUILDING ENVELOPE: \(envScore.grade) (\(Int(envScore.score))/100)")
            parts.append("-".repeated(30))
            for detail in envScore.details {
                parts.append("- \(detail)")
            }
            parts.append("")
        }

        if !allUpgradesByEquipment.isEmpty {
            parts.append("PRIORITIZED UPGRADES (Best Tier)")
            parts.append("-".repeated(30))
            for item in allUpgradesByEquipment {
                if let best = item.upgrades.first(where: { $0.tier == .best }) {
                    let pb = best.paybackYears.map { String(format: "%.1f yr payback", $0) } ?? "N/A"
                    let credit = best.taxCreditEligible ? " (tax credit: $\(Int(best.taxCreditAmount)))" : ""
                    parts.append("- \(item.equipment.typeEnum.rawValue): \(best.title)")
                    parts.append("  $\(Int(best.annualSavings))/yr savings, $\(Int(best.costLow))-$\(Int(best.costHigh)) cost, \(pb)\(credit)")
                }
            }
            parts.append("")
        }

        // Quick wins
        if !homeRecommendations.isEmpty {
            parts.append("QUICK WINS & TIPS")
            parts.append("-".repeated(30))
            for rec in homeRecommendations {
                let savings = rec.estimatedSavings.map { " (\($0))" } ?? ""
                parts.append("- \(rec.title)\(savings)")
            }
            parts.append("")
        }

        let credits = taxCredits
        if credits.grandTotal > 0 {
            parts.append("TAX CREDITS")
            parts.append("-".repeated(30))
            if credits.total25C > 0 { parts.append("Section 25C: $\(Int(credits.total25C))") }
            if credits.total25D > 0 { parts.append("Section 25D: $\(Int(credits.total25D))") }
            parts.append("Total Potential Credits: $\(Int(credits.grandTotal))")
            parts.append("")
        }

        if let state = stateDetector.detectedState {
            let matched = RebateService.matchRebates(for: home, state: state)
            if !matched.isEmpty {
                parts.append("STATE & UTILITY REBATES (\(state.rawValue))")
                parts.append("-".repeated(30))
                for rebate in matched {
                    parts.append("- \(rebate.title): \(rebate.amountDescription)")
                    parts.append("  \(rebate.programName) — \(rebate.url)")
                }
                parts.append("")
            }
        }

        parts.append("Generated by Manor OS | manoros.com | Built by Omer Bese")
        return parts.joined(separator: "\n")
    }
}

// MARK: - Share Sheet

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - String helper

private extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
