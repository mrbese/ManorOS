import SwiftUI

struct ApplianceResultView: View {
    let appliance: Appliance
    var home: Home? = nil
    var onComplete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    private var electricityRate: Double {
        home?.actualElectricityRate ?? Constants.defaultElectricityRate
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                energyBreakdownCard
                if appliance.categoryEnum.isPhantomLoadRelevant {
                    phantomLoadCard
                }
                upgradeTipCard
            }
            .padding()
        }
        .navigationTitle(appliance.name)
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
            Image(systemName: appliance.categoryEnum.icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.manor.onPrimary)

            Text(appliance.name)
                .font(.title2.bold())
                .foregroundStyle(Color.manor.onPrimary)

            Text(appliance.categoryEnum.categoryGroup)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(Int(appliance.estimatedWattage))W")
                        .font(.title.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("Power")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                VStack(spacing: 2) {
                    Text(formatHours(appliance.hoursPerDay))
                        .font(.title.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("hrs/day")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if appliance.quantity > 1 {
                    VStack(spacing: 2) {
                        Text("x\(appliance.quantity)")
                            .font(.title.bold())
                            .foregroundStyle(Color.manor.onPrimary)
                        Text("Qty")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Energy Breakdown

    private var energyBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Usage")
                .font(.headline)

            HStack {
                Text("Annual Energy")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(appliance.annualKWh)) kWh/yr")
                    .font(.title3.bold().monospacedDigit())
            }

            HStack {
                Text("Annual Cost")
                    .font(.subheadline)
                Spacer()
                Text("$\(Int(appliance.annualCost(rate: electricityRate)))/yr")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Color.manor.primary)
            }

            // Monthly breakdown
            let monthlyCost = appliance.annualCost(rate: electricityRate) / 12.0
            HStack {
                Text("Monthly Cost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$\(String(format: "%.2f", monthlyCost))/mo")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Daily usage
            let dailyKWh = appliance.estimatedWattage * appliance.hoursPerDay / 1000.0 * Double(appliance.quantity)
            HStack {
                Text("Daily Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(String(format: "%.2f", dailyKWh)) kWh/day")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Phantom Load

    private var phantomLoadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(Color.manor.warning)
                Text("Phantom Load")
                    .font(.headline)
            }

            let cat = appliance.categoryEnum
            HStack {
                Text("Standby Power")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(cat.phantomWatts))W")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.manor.warning)
            }

            HStack {
                Text("Annual Standby Cost")
                    .font(.subheadline)
                Spacer()
                let phantomCost = appliance.phantomAnnualKWh * electricityRate
                Text("$\(String(format: "%.0f", phantomCost))/yr")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.manor.warning)
            }

            Text("This device draws \(Int(cat.phantomWatts))W even when \"off.\" A smart power strip can eliminate 75% of this standby waste.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Upgrade Tips

    private var upgradeTipCard: some View {
        Group {
            let cat = appliance.categoryEnum
            if let tip = upgradeTip(for: cat) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.max")
                            .foregroundStyle(Color.manor.success)
                        Text("Savings Tip")
                            .font(.headline)
                    }

                    Text(tip.title)
                        .font(.subheadline.bold())

                    Text(tip.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let savings = tip.savings {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.manor.success)
                            Text(savings)
                                .font(.caption.bold())
                                .foregroundStyle(Color.manor.success)
                        }
                    }
                }
                .padding(16)
                .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Helpers

    private func formatHours(_ hours: Double) -> String {
        if hours == floor(hours) {
            return String(Int(hours))
        }
        return String(format: "%.1f", hours)
    }

    private struct UpgradeTip {
        let title: String
        let detail: String
        let savings: String?
    }

    private func upgradeTip(for category: ApplianceCategory) -> UpgradeTip? {
        switch category {
        case .incandescentBulb:
            let ledWatts = appliance.estimatedWattage * 0.15
            let savedKWh = (appliance.estimatedWattage - ledWatts) * appliance.hoursPerDay * 365 / 1000 * Double(appliance.quantity)
            let savedCost = savedKWh * electricityRate
            return UpgradeTip(
                title: "Switch to LED",
                detail: "Replace this \(Int(appliance.estimatedWattage))W incandescent with a \(Int(ledWatts))W LED bulb for the same brightness.",
                savings: "Save ~$\(Int(savedCost))/yr and the bulb lasts 25x longer"
            )

        case .cflBulb:
            let ledWatts = appliance.estimatedWattage * 0.7
            let savedKWh = (appliance.estimatedWattage - ledWatts) * appliance.hoursPerDay * 365 / 1000 * Double(appliance.quantity)
            let savedCost = savedKWh * electricityRate
            return UpgradeTip(
                title: "Upgrade to LED",
                detail: "LEDs use 30% less energy than CFLs, turn on instantly, and contain no mercury.",
                savings: "Save ~$\(Int(savedCost))/yr per bulb"
            )

        case .refrigerator:
            if appliance.estimatedWattage > 120 {
                return UpgradeTip(
                    title: "ENERGY STAR Refrigerator",
                    detail: "If your fridge is 15+ years old, it may use 800+ kWh/yr. New ENERGY STAR models use ~400 kWh/yr.",
                    savings: "Save ~$64/yr with a new ENERGY STAR model"
                )
            }
            return nil

        case .poolPump:
            return UpgradeTip(
                title: "Variable-Speed Pool Pump",
                detail: "Single-speed pool pumps are the second-largest energy user in many homes. A variable-speed pump runs slower for longer, using 70% less energy.",
                savings: "Save $500–$1,200/yr"
            )

        case .portableHeater:
            return UpgradeTip(
                title: "Heating Zone Strategy",
                detail: "Portable heaters at 1,500W are expensive to run. Use them to heat only occupied rooms and lower the central thermostat by 5-10\u{00B0}F.",
                savings: nil
            )

        default:
            if category.isPhantomLoadRelevant && category.phantomWatts > 3 {
                let stripSavings = appliance.phantomAnnualKWh * 0.75 * electricityRate
                return UpgradeTip(
                    title: "Smart Power Strip",
                    detail: "Use a smart power strip to cut standby power when devices are off.",
                    savings: "Save ~$\(Int(stripSavings))/yr across your \(category.categoryGroup.lowercased()) setup"
                )
            }
            return nil
        }
    }
}
