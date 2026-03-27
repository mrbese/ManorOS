import Foundation
import SwiftData

@Model
final class Equipment {
    var id: UUID
    var type: String // EquipmentType.rawValue
    var manufacturer: String?
    var modelNumber: String?
    var ageRange: String // AgeRange.rawValue
    var estimatedEfficiency: Double
    var currentCodeMinimum: Double
    var bestInClass: Double
    var photoData: Data?
    var notes: String?
    var home: Home?
    var createdAt: Date

    init(
        type: EquipmentType = .centralAC,
        manufacturer: String? = nil,
        modelNumber: String? = nil,
        ageRange: AgeRange = .years5to10,
        estimatedEfficiency: Double = 0,
        currentCodeMinimum: Double = 0,
        bestInClass: Double = 0,
        photoData: Data? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.type = type.rawValue
        self.manufacturer = manufacturer
        self.modelNumber = modelNumber
        self.ageRange = ageRange.rawValue
        self.estimatedEfficiency = estimatedEfficiency
        self.currentCodeMinimum = currentCodeMinimum
        self.bestInClass = bestInClass
        self.photoData = photoData
        self.notes = notes
        self.createdAt = Date()
    }

    var typeEnum: EquipmentType {
        EquipmentType(rawValue: type) ?? .centralAC
    }

    var ageRangeEnum: AgeRange {
        AgeRange(rawValue: ageRange) ?? .years5to10
    }
}
