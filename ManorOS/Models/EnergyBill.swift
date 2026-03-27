import Foundation
import SwiftData

@Model
final class EnergyBill {
    var id: UUID
    var billingPeriodStart: Date?
    var billingPeriodEnd: Date?
    var totalKWh: Double
    var totalCost: Double
    var ratePerKWh: Double?
    var utilityName: String?
    var photoData: Data?
    var rawOCRText: String?
    var home: Home?
    var createdAt: Date

    init(
        billingPeriodStart: Date? = nil,
        billingPeriodEnd: Date? = nil,
        totalKWh: Double = 0,
        totalCost: Double = 0,
        ratePerKWh: Double? = nil,
        utilityName: String? = nil,
        photoData: Data? = nil,
        rawOCRText: String? = nil
    ) {
        self.id = UUID()
        self.billingPeriodStart = billingPeriodStart
        self.billingPeriodEnd = billingPeriodEnd
        self.totalKWh = totalKWh
        self.totalCost = totalCost
        self.ratePerKWh = ratePerKWh
        self.utilityName = utilityName
        self.photoData = photoData
        self.rawOCRText = rawOCRText
        self.createdAt = Date()
    }

    /// Number of days in the billing period
    var billingDays: Int? {
        guard let start = billingPeriodStart, let end = billingPeriodEnd else { return nil }
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }

    /// Daily average kWh usage
    var dailyAverageKWh: Double? {
        guard let days = billingDays, days > 0 else { return nil }
        return totalKWh / Double(days)
    }

    /// Annualized kWh based on this billing period
    var annualizedKWh: Double? {
        guard let daily = dailyAverageKWh else { return nil }
        return daily * 365.0
    }

    /// Computed rate: explicit rate, or derived from total cost / kWh, or default
    var computedRate: Double {
        if let explicit = ratePerKWh, explicit > 0 { return explicit }
        if totalKWh > 0 && totalCost > 0 { return totalCost / totalKWh }
        return Constants.defaultElectricityRate
    }
}
