import SwiftUI
import SwiftData

struct ResultsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let room: Room
    var onComplete: (() -> Void)? = nil

    private var breakdown: BTUBreakdown {
        EnergyCalculator.calculate(
            squareFootage: room.squareFootage,
            ceilingHeight: room.ceilingHeightOption,
            climateZone: room.climateZoneEnum,
            insulation: room.insulationEnum,
            windows: room.windows
        )
    }

    private var recommendations: [Recommendation] {
        RecommendationEngine.generate(
            squareFootage: room.squareFootage,
            ceilingHeight: room.ceilingHeightOption,
            insulation: room.insulationEnum,
            windows: room.windows,
            breakdown: breakdown
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                breakdownCard
                recommendationsSection
            }
            .padding()
        }
        .navigationTitle(room.name.isEmpty ? "Results" : room.name)
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
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(spacing: 8) {
            if room.scanWasUsed {
                Label("LiDAR Scan", systemImage: "camera.viewfinder")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text("\(Int(breakdown.finalBTU).formatted())")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Color.manor.onPrimary)

            Text("BTU/hr Required")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Divider()
                .background(.white.opacity(0.3))
                .padding(.vertical, 4)

            HStack(spacing: 32) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", breakdown.tonnage))
                        .font(.title2.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("Tons")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                VStack(spacing: 2) {
                    Text("\(Int(room.squareFootage))")
                        .font(.title2.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("Sq Ft")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                VStack(spacing: 2) {
                    Text(room.climateZoneEnum.rawValue)
                        .font(.title3.bold())
                        .foregroundStyle(Color.manor.onPrimary)
                    Text("Climate")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Text(btuTranslation(tonnage: breakdown.tonnage))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 20))
    }

    private func btuTranslation(tonnage: Double) -> String {
        if tonnage < 0.5 {
            return "A small portable AC unit would handle this room"
        } else if tonnage <= 1.0 {
            return "Equivalent to one mini-split or a 12,000 BTU window unit"
        } else if tonnage <= 2.0 {
            return "Needs a 1.5-2 ton central AC zone or two mini-splits"
        } else if tonnage <= 3.0 {
            return "Requires a 2.5-3 ton central AC system"
        } else if tonnage <= 5.0 {
            return "Requires a 4-5 ton central AC system"
        } else {
            return "Very high load — may need multiple HVAC zones"
        }
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Load Breakdown")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            VStack(spacing: 0) {
                breakdownRow(
                    label: "Base Load",
                    detail: "\(room.ceilingHeightOption.label) ceiling × \(room.climateZoneEnum.rawValue)",
                    value: breakdown.baseBTU,
                    sign: "+"
                )
                breakdownRow(
                    label: "Window Heat Gain",
                    detail: "\(room.windows.count) window(s)",
                    value: breakdown.windowHeatGain,
                    sign: "+"
                )
                breakdownRow(
                    label: "Insulation Factor",
                    detail: room.insulationEnum.rawValue,
                    value: breakdown.insulationAdjustment,
                    sign: breakdown.insulationAdjustment >= 0 ? "+" : ""
                )
                breakdownRow(
                    label: "Safety Buffer",
                    detail: "10% industry standard",
                    value: breakdown.safetyBuffer,
                    sign: "+"
                )

                Divider().padding(.horizontal, 16)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Final Requirement")
                            .font(.headline)
                        Text("BTU/hr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(breakdown.finalBTU).formatted())")
                        .font(.headline)
                        .foregroundStyle(Color.manor.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 8, y: 2)
    }

    private func breakdownRow(label: String, detail: String, value: Double, sign: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(sign)\(Int(abs(value)).formatted())")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(value < 0 ? Color.manor.success : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Efficiency Tips")
                .font(.headline)

            ForEach(recommendations) { rec in
                RecommendationCard(recommendation: rec)
            }
        }
    }

    // MARK: - Share

    private var shareText: String {
        var parts: [String] = []
        parts.append("Manor OS -- Room Assessment")
        if !room.name.isEmpty { parts.append("Room: \(room.name)") }
        parts.append("Floor Area: \(Int(room.squareFootage)) sq ft")
        parts.append("Climate Zone: \(room.climateZoneEnum.rawValue)")
        parts.append("Insulation: \(room.insulationEnum.rawValue)")
        parts.append("")
        parts.append("Required BTU/hr: \(Int(breakdown.finalBTU).formatted())")
        parts.append("HVAC Tonnage: \(String(format: "%.1f", breakdown.tonnage)) tons")
        parts.append("")
        parts.append("Breakdown:")
        parts.append("  Base Load: \(Int(breakdown.baseBTU).formatted()) BTU")
        parts.append("  Window Heat Gain: \(Int(breakdown.windowHeatGain).formatted()) BTU")
        parts.append("  Insulation Adj: \(Int(breakdown.insulationAdjustment).formatted()) BTU")
        parts.append("  Safety Buffer: \(Int(breakdown.safetyBuffer).formatted()) BTU")
        parts.append("")
        parts.append("Generated by Manor OS | Built by Omer Bese")
        return parts.joined(separator: "\n")
    }
}

// MARK: - Recommendation card

private struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: recommendation.icon)
                    .font(.title3)
                    .foregroundStyle(Color.manor.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.subheadline.bold())
                    Text(recommendation.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let savings = recommendation.estimatedSavings {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text(savings)
                        .font(.caption)
                }
                .foregroundStyle(Color.manor.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.manor.success.opacity(0.1), in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.manor.background.opacity(0.06), radius: 6, y: 2)
    }
}
