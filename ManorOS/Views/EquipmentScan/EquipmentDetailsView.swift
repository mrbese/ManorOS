import SwiftUI
import SwiftData
import UIKit

struct EquipmentDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let home: Home
    var allowedTypes: [EquipmentType]? = nil
    var existingEquipment: Equipment? = nil
    var onComplete: (() -> Void)? = nil

    @State private var equipmentType: EquipmentType = .centralAC
    @State private var manufacturer: String = ""
    @State private var modelNumber: String = ""
    @State private var ageRange: AgeRange = .years5to10
    @State private var manualEfficiency: String = ""
    @State private var notes: String = ""
    @State private var capturedImage: UIImage?
    @State private var ocrResult: OCRResult?
    @State private var showingCamera = false
    @State private var showingResult = false
    @State private var savedEquipment: Equipment?
    @State private var isProcessingOCR = false
    @State private var efficiencyError: String? = nil

    private var isEditing: Bool { existingEquipment != nil }

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                photoSection
                detailsSection
                ageSection
                notesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Equipment" : "Add Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { prefillFromExisting() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEquipment() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.manor.primary)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                EquipmentCameraView(equipmentType: equipmentType) { image in
                    showingCamera = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        capturedImage = image
                        processOCR(image: image)
                    }
                }
            }
            .navigationDestination(isPresented: $showingResult) {
                if let eq = savedEquipment {
                    EquipmentResultView(equipment: eq, home: home, onComplete: onComplete ?? { dismiss() })
                }
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section("Equipment Type") {
            Picker("Type", selection: $equipmentType) {
                ForEach(allowedTypes ?? Array(EquipmentType.allCases)) { type in
                    Label(type.rawValue, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.navigationLink)
        }
        .onAppear {
            if let types = allowedTypes, let first = types.first, !types.contains(equipmentType) {
                equipmentType = first
            }
        }
    }

    private var photoSection: some View {
        Section {
            if let image = capturedImage {
                VStack(spacing: 8) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if isProcessingOCR {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading label...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let ocr = ocrResult, ocr.manufacturer != nil || ocr.efficiencyValue != nil {
                        Label("Label data detected and pre-filled below", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.manor.success)
                    }

                    Button("Retake Photo") {
                        showingCamera = true
                    }
                    .font(.caption)
                }
            } else {
                Button(action: { showingCamera = true }) {
                    Label("Photograph Equipment Label", systemImage: "camera.fill")
                        .foregroundStyle(Color.manor.primary)
                }

                Text("Optional. Take a photo of the rating plate or EnergyGuide label for automatic data extraction.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Photo (Optional)")
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Manufacturer (optional)", text: $manufacturer)
            TextField("Model Number (optional)", text: $modelNumber)

            HStack {
                let spec = EfficiencyDatabase.lookup(type: equipmentType, age: ageRange)
                Text("Efficiency (\(equipmentType.efficiencyUnit))")
                Spacer()
                TextField("~\(String(format: "%.1f", spec.estimated))", text: $manualEfficiency)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            if let error = efficiencyError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if manualEfficiency.isEmpty {
                let spec = EfficiencyDatabase.lookup(type: equipmentType, age: ageRange)
                Text("Will estimate \(String(format: "%.1f", spec.estimated)) \(equipmentType.efficiencyUnit) based on age")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let explanation = efficiencyExplanation(for: equipmentType)
            if !explanation.isEmpty {
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func efficiencyExplanation(for type: EquipmentType) -> String {
        switch type {
        case .centralAC, .heatPump: return "SEER measures cooling efficiency. Higher is better. New systems are typically 14-22 SEER."
        case .furnace: return "AFUE measures heating efficiency as a percentage. Higher is better. Modern furnaces are 90-98%."
        case .waterHeater: return "UEF (Uniform Energy Factor) measures water heating efficiency. Higher is better."
        case .waterHeaterTankless: return "UEF for tankless heaters. Higher is better. Typical range: 0.82-0.97."
        case .windowUnit: return "EER measures cooling efficiency at a specific temperature. Higher is better."
        case .windows: return "U-factor measures heat transfer. Lower is better (less heat loss)."
        case .insulation: return "R-value measures thermal resistance. Higher is better (more insulation)."
        default: return ""
        }
    }

    private var ageSection: some View {
        Section("Equipment Age") {
            Picker("Age", selection: $ageRange) {
                ForEach(AgeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Any additional notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Prefill from Existing

    private func prefillFromExisting() {
        guard let eq = existingEquipment else { return }
        equipmentType = eq.typeEnum
        manufacturer = eq.manufacturer ?? ""
        modelNumber = eq.modelNumber ?? ""
        ageRange = eq.ageRangeEnum
        manualEfficiency = String(format: "%.1f", eq.estimatedEfficiency)
        notes = eq.notes ?? ""
        if let data = eq.photoData {
            capturedImage = UIImage(data: data)
        }
    }

    // MARK: - OCR Processing

    private func processOCR(image: UIImage) {
        isProcessingOCR = true
        Task {
            let result = await OCRService.recognizeText(from: image)
            ocrResult = result
            if let mfr = result.manufacturer, manufacturer.isEmpty {
                manufacturer = mfr
            }
            if let model = result.modelNumber, modelNumber.isEmpty {
                modelNumber = model
            }
            if let value = result.efficiencyValue, manualEfficiency.isEmpty {
                manualEfficiency = String(format: "%.1f", value)
            }
            isProcessingOCR = false
        }
    }

    // MARK: - Validation

    private func efficiencyRange(for type: EquipmentType) -> ClosedRange<Double> {
        switch type {
        case .centralAC, .heatPump: return 8...30
        case .furnace: return 50...100
        case .waterHeater: return 0.3...4.0
        case .waterHeaterTankless: return 0.5...1.0
        case .windowUnit: return 5...15
        case .windows: return 0.1...2.0
        case .insulation: return 1...60
        default: return 0.1...200
        }
    }

    // MARK: - Save

    private func saveEquipment() {
        if !manualEfficiency.isEmpty {
            if let parsed = Double(manualEfficiency) {
                let range = efficiencyRange(for: equipmentType)
                if !range.contains(parsed) {
                    efficiencyError = "Expected \(equipmentType.efficiencyUnit) between \(String(format: "%.1f", range.lowerBound)) and \(String(format: "%.1f", range.upperBound))"
                    return
                } else {
                    efficiencyError = nil
                }
            } else {
                efficiencyError = "Enter a valid number for efficiency"
                return
            }
        } else {
            efficiencyError = nil
        }

        let spec = EfficiencyDatabase.lookup(type: equipmentType, age: ageRange)
        let efficiency = Double(manualEfficiency) ?? spec.estimated

        if let existing = existingEquipment {
            // Edit existing
            existing.type = equipmentType.rawValue
            existing.manufacturer = manufacturer.isEmpty ? nil : manufacturer
            existing.modelNumber = modelNumber.isEmpty ? nil : modelNumber
            existing.ageRange = ageRange.rawValue
            existing.estimatedEfficiency = efficiency
            existing.currentCodeMinimum = spec.codeMinimum
            existing.bestInClass = spec.bestInClass
            existing.notes = notes.isEmpty ? nil : notes
            if let img = capturedImage {
                existing.photoData = img.jpegData(compressionQuality: 0.7)
            }
            home.updatedAt = Date()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onComplete?()
            dismiss()
        } else {
            guard savedEquipment == nil else {
                showingResult = true
                return
            }
            let eq = Equipment(
                type: equipmentType,
                manufacturer: manufacturer.isEmpty ? nil : manufacturer,
                modelNumber: modelNumber.isEmpty ? nil : modelNumber,
                ageRange: ageRange,
                estimatedEfficiency: efficiency,
                currentCodeMinimum: spec.codeMinimum,
                bestInClass: spec.bestInClass,
                photoData: capturedImage?.jpegData(compressionQuality: 0.7),
                notes: notes.isEmpty ? nil : notes
            )
            eq.home = home
            modelContext.insert(eq)
            home.updatedAt = Date()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            savedEquipment = eq
            showingResult = true
        }
    }
}
