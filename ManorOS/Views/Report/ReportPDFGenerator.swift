import SwiftUI
import UIKit

enum ReportPDFGenerator {

    // US Letter size in points
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 50
    private static let contentWidth: CGFloat = 612 - 100 // pageWidth - 2 * margin

    struct BreakdownSnapshot: Sendable {
        let name: String
        let annualCost: Double
        let percentage: Double
    }

    struct UpgradeSnapshot: Sendable {
        let equipmentLabel: String
        let title: String
        let savingsPerYear: Int
        let costRange: String
        let payback: String
        let taxCredit: String?
    }

    struct Snapshot: Sendable {
        let generatedAt: Date
        let homeName: String
        let address: String?
        let climateZone: String
        let totalSqFt: Int?
        let roomsCount: Int
        let equipmentCount: Int
        let grade: String
        let gradeSummary: String

        let currentAnnualCost: Int?
        let upgradedAnnualCost: Int?
        let potentialSavings: Int?

        let breakdown: [BreakdownSnapshot]
        let billComparison: String?
        let envelopeSummaryLines: [String]
        let topConsumers: [String]
        let upgrades: [UpgradeSnapshot]
        let quickWins: [String]

        let taxCredit25C: Int
        let taxCredit25D: Int
        let taxCreditTotal: Int
    }

    @MainActor
    static func savePDFAsync(for home: Home) async -> URL? {
        let snapshot = makeSnapshot(for: home)
        return await Task.detached(priority: .userInitiated) {
            savePDF(from: snapshot)
        }.value
    }

    // MARK: - Snapshot

    @MainActor
    private static func makeSnapshot(for home: Home) -> Snapshot {
        let grade = GradingEngine.grade(for: home)
        let profile = EnergyProfileService.generateProfile(for: home)
        let homeRecs = RecommendationEngine.generateHomeRecommendations(for: home)
        let sqFt = home.computedTotalSqFt > 0 ? home.computedTotalSqFt : 1500

        let allUpgradesByEquipment: [(equipment: Equipment, upgrades: [UpgradeRecommendation])] = home.equipment.compactMap { eq in
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

        let totalCurrentCost: Double = home.equipment.reduce(0) { sum, eq in
            sum + EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum,
                efficiency: eq.estimatedEfficiency,
                homeSqFt: sqFt,
                climateZone: home.climateZoneEnum,
                electricityRate: home.actualElectricityRate,
                gasRate: home.actualGasRate
            )
        }
        let totalUpgradedCost: Double = home.equipment.reduce(0) { sum, eq in
            let spec = EfficiencyDatabase.lookup(type: eq.typeEnum, age: eq.ageRangeEnum)
            return sum + EfficiencyDatabase.estimateAnnualCost(
                type: eq.typeEnum,
                efficiency: spec.bestInClass,
                homeSqFt: sqFt,
                climateZone: home.climateZoneEnum,
                electricityRate: home.actualElectricityRate,
                gasRate: home.actualGasRate
            )
        }
        let totalSavings = max(totalCurrentCost - totalUpgradedCost, 0)
        let taxCredits = UpgradeEngine.aggregateTaxCredits(from: allUpgradesByEquipment.map(\.upgrades))

        let billComparison = profile.billComparison.map {
            "Actual (from bills): \(Int($0.billBasedAnnualKWh)) kWh/yr\nEstimated (from audit): \(Int($0.estimatedAnnualKWh)) kWh/yr\nAccuracy: \($0.accuracyLabel) (\(Int($0.gapPercentage))% gap)"
        }

        let envelopeLines: [String] = profile.envelopeScore?.details ?? []
        let envelopeHeader: String? = profile.envelopeScore.map { "BUILDING ENVELOPE: \($0.grade) (\(Int($0.score))/100)" }

        let upgrades: [UpgradeSnapshot] = allUpgradesByEquipment.compactMap { group in
            guard let best = group.upgrades.first(where: { $0.tier == .best }) else { return nil }
            let pb = best.paybackYears.map { String(format: "%.1f yr payback", $0) } ?? "N/A"
            let credit = best.taxCreditEligible ? "$\(Int(best.taxCreditAmount))" : nil
            return UpgradeSnapshot(
                equipmentLabel: group.equipment.typeEnum.rawValue,
                title: best.title,
                savingsPerYear: Int(best.annualSavings),
                costRange: "$\(Int(best.costLow))-$\(Int(best.costHigh))",
                payback: pb,
                taxCredit: credit
            )
        }

        let topConsumers = profile.topConsumers.prefix(5).enumerated().map { idx, c in
            "#\(idx + 1) \(c.name): $\(Int(c.annualCost))/yr"
        }

        let breakdown = profile.breakdown.map { BreakdownSnapshot(name: $0.name, annualCost: $0.annualCost, percentage: $0.percentage) }

        let homeName = home.name.isEmpty ? "Unnamed Home" : home.name

        let gradeValue = home.equipment.isEmpty ? "N/A" : grade.rawValue
        let gradeSummary = home.equipment.isEmpty ? "Add equipment to get an efficiency grade." : grade.summary

        return Snapshot(
            generatedAt: Date(),
            homeName: homeName,
            address: (home.address?.isEmpty == false) ? home.address : nil,
            climateZone: home.climateZoneEnum.rawValue,
            totalSqFt: home.computedTotalSqFt > 0 ? Int(home.computedTotalSqFt) : nil,
            roomsCount: home.rooms.count,
            equipmentCount: home.equipment.count,
            grade: gradeValue,
            gradeSummary: gradeSummary,
            currentAnnualCost: home.equipment.isEmpty ? nil : Int(totalCurrentCost),
            upgradedAnnualCost: (home.equipment.isEmpty || totalSavings <= 0) ? nil : Int(totalUpgradedCost),
            potentialSavings: (home.equipment.isEmpty || totalSavings <= 0) ? nil : Int(totalSavings),
            breakdown: breakdown,
            billComparison: billComparison,
            envelopeSummaryLines: (envelopeHeader.map { [$0] } ?? []) + envelopeLines,
            topConsumers: topConsumers,
            upgrades: upgrades,
            quickWins: homeRecs.map(\.title),
            taxCredit25C: Int(taxCredits.total25C),
            taxCredit25D: Int(taxCredits.total25D),
            taxCreditTotal: Int(taxCredits.grandTotal)
        )
    }

    // MARK: - Public sync API (legacy)

    @MainActor
    static func savePDF(for home: Home) -> URL? {
        let snapshot = makeSnapshot(for: home)
        return savePDF(from: snapshot)
    }

    // MARK: - Rendering

    private static func savePDF(from snapshot: Snapshot) -> URL? {
        guard let data = generatePDF(from: snapshot) else { return nil }
        let fileName = "\(snapshot.homeName)_Report.pdf".replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func generatePDF(from snapshot: Snapshot) -> Data? {
        let text = buildReportText(from: snapshot)
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { context in
            drawPages(context: context, text: text, pageRect: pageRect)
        }
        return data.isEmpty ? nil : data
    }

    // MARK: - Text Building

    private static func buildReportText(from snapshot: Snapshot) -> NSAttributedString {
        let result = NSMutableAttributedString()

        result.append(styled("MANOR OS HOME ENERGY REPORT\n", style: .title))
        result.append(styled("\n", style: .body))
        result.append(styled("Generated: ", style: .label))
        result.append(styled("\(formattedDate(snapshot.generatedAt))\n\n", style: .body))

        // Summary
        result.append(styled("Home: ", style: .label))
        result.append(styled("\(snapshot.homeName)\n", style: .body))
        if let addr = snapshot.address {
            result.append(styled("Address: ", style: .label))
            result.append(styled("\(addr)\n", style: .body))
        }
        if let sq = snapshot.totalSqFt {
            result.append(styled("Total Area: ", style: .label))
            result.append(styled("\(sq) sq ft\n", style: .body))
        }
        result.append(styled("Climate Zone: ", style: .label))
        result.append(styled("\(snapshot.climateZone)\n", style: .body))
        result.append(styled("Rooms: ", style: .label))
        result.append(styled("\(snapshot.roomsCount)    ", style: .body))
        result.append(styled("Equipment: ", style: .label))
        result.append(styled("\(snapshot.equipmentCount)\n", style: .body))
        result.append(styled("Efficiency Grade: ", style: .label))
        result.append(styled("\(snapshot.grade)\n", style: .gradeValue))
        result.append(styled("\(snapshot.gradeSummary)\n\n", style: .caption))

        // Energy Cost
        if let current = snapshot.currentAnnualCost {
            result.append(styled("ENERGY COST ESTIMATE\n", style: .heading))
            result.append(styled("Current Annual Cost: $\(current)/yr\n", style: .body))
            if let upgraded = snapshot.upgradedAnnualCost, let savings = snapshot.potentialSavings {
                result.append(styled("After All Upgrades: $\(upgraded)/yr\n", style: .body))
                result.append(styled("Potential Annual Savings: $\(savings)/yr\n", style: .highlight))
            }
            result.append(styled("\n", style: .body))
        }

        // Energy Breakdown
        if snapshot.breakdown.count > 1 {
            result.append(styled("ENERGY BREAKDOWN\n", style: .heading))
            for cat in snapshot.breakdown {
                result.append(styled("  \(cat.name): $\(Int(cat.annualCost))/yr (\(Int(cat.percentage))%)\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Bill Comparison
        if let comparison = snapshot.billComparison {
            result.append(styled("BILL VS. ESTIMATE\n", style: .heading))
            result.append(styled("\(comparison)\n\n", style: .body))
        }

        // Envelope
        if !snapshot.envelopeSummaryLines.isEmpty {
            result.append(styled(snapshot.envelopeSummaryLines[0] + "\n", style: .heading))
            for line in snapshot.envelopeSummaryLines.dropFirst() {
                result.append(styled("  \(line)\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Consumers
        if !snapshot.topConsumers.isEmpty {
            result.append(styled("TOP ENERGY CONSUMERS\n", style: .heading))
            for line in snapshot.topConsumers {
                result.append(styled("  \(line)\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Upgrades
        if !snapshot.upgrades.isEmpty {
            result.append(styled("PRIORITIZED UPGRADES\n", style: .heading))
            for up in snapshot.upgrades.prefix(8) {
                let credit = up.taxCredit.map { " (tax credit: \($0))" } ?? ""
                result.append(styled("  \(up.equipmentLabel): \(up.title)\n", style: .label))
                result.append(styled("    $\(up.savingsPerYear)/yr savings, \(up.costRange) cost, \(up.payback)\(credit)\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Quick Wins
        if !snapshot.quickWins.isEmpty {
            result.append(styled("QUICK WINS & TIPS\n", style: .heading))
            for title in snapshot.quickWins.prefix(10) {
                result.append(styled("  \(title)\n", style: .body))
            }
            result.append(styled("\n", style: .body))
        }

        // Tax Credits
        if snapshot.taxCreditTotal > 0 {
            result.append(styled("TAX CREDITS\n", style: .heading))
            if snapshot.taxCredit25C > 0 { result.append(styled("  Section 25C: $\(snapshot.taxCredit25C)\n", style: .body)) }
            if snapshot.taxCredit25D > 0 { result.append(styled("  Section 25D: $\(snapshot.taxCredit25D)\n", style: .body)) }
            result.append(styled("  Total Potential Credits: $\(snapshot.taxCreditTotal)\n\n", style: .highlight))
        }

        // Footer
        result.append(styled("\nGenerated by Manor OS | Built by Omer Bese\n", style: .caption))
        return result
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Drawing

    private static func drawPages(context: UIGraphicsPDFRendererContext, text: NSAttributedString, pageRect: CGRect) {
        let textRect = CGRect(
            x: margin,
            y: margin,
            width: contentWidth,
            height: pageHeight - 2 * margin
        )

        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        var currentRange = CFRange(location: 0, length: 0)
        var pageNumber = 1

        while currentRange.location < text.length {
            context.beginPage()

            // Draw header line on each page
            let headerY: CGFloat = 30
            let headerFont = UIFont.systemFont(ofSize: 8, weight: .regular)
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.gray
            ]
            let headerText = "Manor OS Home Energy Report — Page \(pageNumber)"
            (headerText as NSString).draw(at: CGPoint(x: margin, y: headerY), withAttributes: headerAttrs)

            // Draw content
            let path = CGPath(rect: textRect, transform: nil)
            _ = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            let ctx = context.cgContext
            ctx.saveGState()
            ctx.translateBy(x: 0, y: pageRect.height)
            ctx.scaleBy(x: 1.0, y: -1.0)

            let flippedRect = CGRect(
                x: textRect.origin.x,
                y: pageRect.height - textRect.origin.y - textRect.height,
                width: textRect.width,
                height: textRect.height
            )
            let flippedPath = CGPath(rect: flippedRect, transform: nil)
            let flippedFrame = CTFramesetterCreateFrame(framesetter, currentRange, flippedPath, nil)
            CTFrameDraw(flippedFrame, ctx)

            ctx.restoreGState()

            let visibleRange = CTFrameGetVisibleStringRange(flippedFrame)
            currentRange = CFRange(location: visibleRange.location + visibleRange.length, length: 0)
            pageNumber += 1
        }
    }

    // MARK: - Styles

    private enum TextStyle {
        case title, heading, label, body, caption, highlight, gradeValue
    }

    private static func styled(_ string: String, style: TextStyle) -> NSAttributedString {
        let font: UIFont
        let color: UIColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2

        switch style {
        case .title:
            font = UIFont.systemFont(ofSize: 22, weight: .bold)
            color = ManorColors.pdf.title
            paragraphStyle.lineSpacing = 6
        case .heading:
            font = UIFont.systemFont(ofSize: 14, weight: .bold)
            color = ManorColors.pdf.heading
            paragraphStyle.paragraphSpacingBefore = 8
        case .label:
            font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            color = .darkGray
        case .body:
            font = UIFont.systemFont(ofSize: 11, weight: .regular)
            color = ManorColors.pdf.body
        case .caption:
            font = UIFont.systemFont(ofSize: 9, weight: .regular)
            color = .gray
        case .highlight:
            font = UIFont.systemFont(ofSize: 11, weight: .bold)
            color = ManorColors.pdf.highlight
        case .gradeValue:
            font = UIFont.systemFont(ofSize: 18, weight: .bold)
            color = ManorColors.pdf.grade
        }

        return NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ])
    }
}
