import SwiftUI

struct EquipmentResultView: View {
    @Environment(\.dismiss) private var dismiss

    let equipment: Equipment
    let home: Home
    var onComplete: (() -> Void)? = nil

    private var spec: EfficiencySpec {
        EfficiencyDatabase.lookup(type: equipment.typeEnum, age: equipment.ageRangeEnum)
    }

    private var upgrades: [UpgradeRecommendation] {
        UpgradeEngine.generateUpgrades(
            for: equipment,
            climateZone: home.climateZoneEnum,
            homeSqFt: home.computedTotalSqFt > 0 ? home.computedTotalSqFt : 1500,
            electricityRate: home.actualElectricityRate,
            gasRate: home.actualGasRate
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                efficiencyComparisonCard
                if !upgrades.isEmpty {
                    upgradeOptionsSection
                }
            }
            .padding()
        }
        .navigationTitle(equipment.typeEnum.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    if let onComplete {
                        onComplete()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 12) {
            Image(systemName: equipment.typeEnum.icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.manor.onPrimary)

            Text(equipment.typeEnum.rawValue)
                .font(.title2.bold())
                .foregroundStyle(Color.manor.onPrimary)

            if let mfr = equipment.manufacturer {
                Text(mfr)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", equipment.estimatedEfficiency))
                        .font(.title.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("Current \(equipment.typeEnum.efficiencyUnit)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                VStack(spacing: 2) {
                    Text(equipment.ageRangeEnum.shortLabel)
                        .font(.title3.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("Age")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Comparison

    private var isInvertedScale: Bool {
        equipment.typeEnum == .windows
    }

    private var efficiencyComparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Efficiency Comparison")
                .font(.headline)

            comparisonRow(label: "Your Equipment", value: equipment.estimatedEfficiency, unit: equipment.typeEnum.efficiencyUnit, highlight: false)
            comparisonRow(label: "Current Code Minimum", value: equipment.currentCodeMinimum, unit: equipment.typeEnum.efficiencyUnit, highlight: false)
            comparisonRow(label: "Best in Class", value: equipment.bestInClass, unit: equipment.typeEnum.efficiencyUnit, highlight: true)

            // Efficiency bar
            let ratio = GradingEngine.weightedEfficiencyRatio(for: [equipment])
            VStack(alignment: .leading, spacing: 4) {
                Text("Efficiency Rating")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.2))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(ratio: ratio))
                            .frame(width: geo.size.width * ratio, height: 8)
                    }
                }
                .frame(height: 8)
            }

            if isInvertedScale {
                Text("For U-factor, lower values indicate better insulation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func comparisonRow(label: String, value: Double, unit: String, highlight: Bool) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(highlight ? Color.manor.success : .primary)
            Spacer()
            Text("\(String(format: "%.1f", value)) \(unit)")
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(highlight ? Color.manor.success : .primary)
        }
    }

    // MARK: - Upgrade Options

    private var upgradeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upgrade Options")
                .font(.headline)

            Text("Good \u{2192} Better \u{2192} Best")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(upgrades) { rec in
                upgradeRecommendationCard(rec)
            }
        }
    }

    private func upgradeRecommendationCard(_ rec: UpgradeRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tier badge + title
            HStack(spacing: 8) {
                tierBadge(rec.tier)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.title)
                        .font(.subheadline.bold())
                    Text(rec.upgradeTarget)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if rec.alreadyMeetsThisTier {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Your current equipment meets this tier")
                        .font(.caption)
                }
                .foregroundStyle(Color.manor.success)
            }

            // Cost range
            HStack {
                Text("Estimated Cost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$\(Int(rec.costLow).formatted()) – $\(Int(rec.costHigh).formatted())")
                    .font(.subheadline.bold())
            }

            // Annual savings
            if rec.annualSavings > 0 {
                HStack {
                    Text("Annual Savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(Int(rec.annualSavings))/yr")
                        .font(.title3.bold())
                        .foregroundStyle(Color.manor.success)
                }

                // Payback
                if let pb = rec.paybackYears {
                    HStack {
                        Text("Simple Payback")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f years", pb))
                            .font(.caption.bold())
                            .foregroundStyle(pb < 3 ? Color.manor.success : pb < 7 ? Color.manor.warning : .secondary)
                    }
                }
            }

            // Tax credit
            if rec.taxCreditEligible && rec.taxCreditAmount > 0 {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.manor.info)
                    Text("Tax Credit: $\(Int(rec.taxCreditAmount))")
                        .font(.caption.bold())
                        .foregroundStyle(Color.manor.info)
                    Spacer()
                    if let epb = rec.effectivePaybackYears, let pb = rec.paybackYears, epb < pb {
                        Text("Effective payback: \(String(format: "%.1f yr", epb))")
                            .font(.caption)
                            .foregroundStyle(Color.manor.info)
                    }
                }
                .padding(8)
                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            // Technology note
            if let note = rec.technologyNote {
                DisclosureGroup {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } label: {
                    Text("Technology Details")
                        .font(.caption)
                        .foregroundStyle(Color.manor.primary)
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func tierBadge(_ tier: UpgradeTier) -> some View {
        let (label, color): (String, Color) = {
            switch tier {
            case .good: return ("Good", Color.manor.info)
            case .better: return ("Better", Color.manor.accent)
            case .best: return ("Best", Color.manor.success)
            }
        }()

        return Text(label)
            .font(.caption2.bold())
            .foregroundStyle(Color.manor.onPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }

    private func barColor(ratio: Double) -> Color {
        if ratio >= 0.7 { return Color.manor.success }
        if ratio >= 0.4 { return Color.manor.warning }
        return .red
    }
}
