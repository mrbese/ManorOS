import SwiftUI
import SwiftData
import UIKit

enum UsageMode: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
}

struct ApplianceDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let home: Home
    var room: Room? = nil
    var prefilledCategory: ApplianceCategory? = nil
    var prefilledWattage: Double? = nil
    var prefilledImage: UIImage? = nil
    var detectionMethod: String = "manual"
    var existingAppliance: Appliance? = nil
    var onComplete: (() -> Void)? = nil

    @State private var category: ApplianceCategory = .other
    @State private var name: String = ""
    @State private var wattage: String = ""
    @State private var hoursPerDay: String = ""
    @State private var quantity: Int = 1
    @State private var selectedRoom: Room?
    @State private var showingResult = false
    @State private var savedAppliance: Appliance?
    @State private var hoursError: String? = nil
    @State private var wattageError: String? = nil
    @State private var usageMode: UsageMode = .daily
    @State private var usesPerWeek: String = ""
    @State private var minutesPerUse: String = ""

    private var isEditing: Bool { existingAppliance != nil }

    private var isLightingCategory: Bool {
        [.ledBulb, .cflBulb, .incandescentBulb].contains(category)
    }

    private var isIntermittentCategory: Bool {
        [.dishwasher, .oven, .coffeeMaker, .toaster, .microwave].contains(category)
    }

    private static let alwaysOnCategories: Set<ApplianceCategory> = [
        .refrigerator, .freezer, .router
    ]

    private var calculatedDailyHours: Double? {
        guard usageMode == .weekly,
              let uses = Double(usesPerWeek), uses > 0,
              let mins = Double(minutesPerUse), mins > 0 else { return nil }
        return (uses * mins) / (7.0 * 60.0)
    }

    var body: some View {
        NavigationStack {
            Form {
                categorySection
                if isLightingCategory {
                    bulbQuantitySection
                }
                detailsSection
                usageSection
                roomSection
                previewSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Appliance" : "Add Appliance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAppliance() }
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
            .onAppear {
                applyPrefills()
                prefillFromExisting()
            }
            .navigationDestination(isPresented: $showingResult) {
                if let appliance = savedAppliance {
                    ApplianceResultView(appliance: appliance, home: home, onComplete: onComplete ?? { dismiss() })
                }
            }
        }
    }

    // MARK: - Sections

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $category) {
                ForEach(groupedCategories, id: \.key) { group, categories in
                    Section(group) {
                        ForEach(categories) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
            }
            .pickerStyle(.navigationLink)
            .onChange(of: category) { _, newValue in
                if name.isEmpty || name == category.rawValue {
                    name = newValue.rawValue
                }
                if wattage.isEmpty {
                    wattage = String(Int(newValue.defaultWattage))
                }
                if hoursPerDay.isEmpty {
                    hoursPerDay = formatHours(newValue.defaultHoursPerDay)
                }
                let intermittent: Set<ApplianceCategory> = [.dishwasher, .oven, .coffeeMaker, .toaster, .microwave]
                usageMode = intermittent.contains(newValue) ? .weekly : .daily
            }

            if let image = prefilledImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var bulbQuantitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("How many of these bulbs?")
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    ForEach([1, 2, 3, 4, 5, 6], id: \.self) { count in
                        Button {
                            quantity = count
                        } label: {
                            Text(count == 6 ? "6+" : "\(count)")
                                .font(.headline)
                                .frame(width: 48, height: 48)
                                .background(
                                    quantity == count
                                        ? Color.manor.primary
                                        : Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .foregroundStyle(quantity == count ? Color.manor.onPrimary : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if quantity >= 6 {
                    Stepper("Exact count: \(quantity)", value: $quantity, in: 6...50)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Quantity")
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $name)

            HStack {
                Text("Wattage")
                Spacer()
                TextField("W", text: $wattage)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("W")
                    .foregroundStyle(.secondary)
            }

            if wattage.isEmpty {
                Text("Default: \(Int(category.defaultWattage))W for \(category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = wattageError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var usageSection: some View {
        Section("Usage") {
            if isIntermittentCategory {
                Picker("Usage Pattern", selection: $usageMode) {
                    ForEach(UsageMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if usageMode == .weekly && isIntermittentCategory {
                HStack {
                    Text("Uses per week")
                    Spacer()
                    TextField("times", text: $usesPerWeek)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }

                HStack {
                    Text("Duration per use")
                    Spacer()
                    TextField("min", text: $minutesPerUse)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("min")
                        .foregroundStyle(.secondary)
                }

                if let daily = calculatedDailyHours {
                    HStack(spacing: 4) {
                        Image(systemName: "equal.circle")
                            .font(.caption)
                            .foregroundStyle(Color.manor.primary)
                        Text(String(format: "≈ %.1f hrs/day average", daily))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("Hours per day")
                    Spacer()
                    TextField("hrs", text: $hoursPerDay)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("hrs")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = hoursError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !isLightingCategory {
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...50)
            }
        }
    }

    private var roomSection: some View {
        Section("Room (Optional)") {
            if home.rooms.isEmpty {
                Text("No rooms added yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Assign to room", selection: $selectedRoom) {
                    Text("None").tag(nil as Room?)
                    ForEach(home.rooms) { r in
                        Text(r.name.isEmpty ? "Unnamed Room" : r.name).tag(r as Room?)
                    }
                }
                .pickerStyle(.navigationLink)
            }
        }
    }

    private var effectiveHoursPerDay: Double {
        if usageMode == .weekly && isIntermittentCategory, let daily = calculatedDailyHours {
            return daily
        }
        return Double(hoursPerDay) ?? category.defaultHoursPerDay
    }

    private var previewSection: some View {
        Section("Energy Preview") {
            let w = Double(wattage) ?? category.defaultWattage
            let h = effectiveHoursPerDay
            let annualKWh = w * h * 365.0 / 1000.0 * Double(quantity)
            let annualCost = annualKWh * home.actualElectricityRate

            HStack {
                Text("Annual Energy")
                Spacer()
                Text("\(Int(annualKWh)) kWh/yr")
                    .font(.subheadline.bold().monospacedDigit())
            }

            HStack {
                Text("Annual Cost")
                Spacer()
                Text("$\(Int(annualCost))/yr")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(Color.manor.primary)
            }

            if category.isPhantomLoadRelevant {
                HStack {
                    Text("Standby Power")
                    Spacer()
                    Text("\(Int(category.phantomWatts))W when off")
                        .font(.caption)
                        .foregroundStyle(Color.manor.warning)
                }
            }
        }
    }

    // MARK: - Helpers

    private var groupedCategories: [(key: String, value: [ApplianceCategory])] {
        let grouped = Dictionary(grouping: ApplianceCategory.allCases, by: \.categoryGroup)
        return grouped.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }
    }

    private func formatHours(_ hours: Double) -> String {
        if hours == floor(hours) {
            return String(Int(hours))
        }
        return String(format: "%.1f", hours)
    }

    private func applyPrefills() {
        guard existingAppliance == nil else { return }
        if let cat = prefilledCategory {
            category = cat
            name = cat.rawValue
            wattage = String(Int(cat.defaultWattage))
            hoursPerDay = formatHours(cat.defaultHoursPerDay)
        } else if wattage.isEmpty {
            wattage = String(Int(category.defaultWattage))
        }
        if let w = prefilledWattage {
            wattage = String(Int(w))
        }
        if let r = room {
            selectedRoom = r
        }
        let intermittent: Set<ApplianceCategory> = [.dishwasher, .oven, .coffeeMaker, .toaster, .microwave]
        usageMode = intermittent.contains(category) ? .weekly : .daily
    }

    private func prefillFromExisting() {
        guard let appliance = existingAppliance else { return }
        category = appliance.categoryEnum
        name = appliance.name
        wattage = String(Int(appliance.estimatedWattage))
        hoursPerDay = formatHours(appliance.hoursPerDay)
        quantity = appliance.quantity
        if let r = appliance.room {
            selectedRoom = r
        }
    }

    private func saveAppliance() {
        let w = Double(wattage) ?? category.defaultWattage
        let h = effectiveHoursPerDay

        var hasError = false
        if w <= 0 {
            wattageError = "Wattage must be greater than 0"
            hasError = true
        } else {
            wattageError = nil
        }
        if h > 24 {
            hoursError = "Hours per day cannot exceed 24"
            hasError = true
        } else if usageMode == .weekly && isIntermittentCategory && calculatedDailyHours == nil {
            hoursError = "Enter uses per week and duration"
            hasError = true
        } else {
            hoursError = nil
        }
        guard !hasError else { return }

        let clampedH = min(h, 24.0)

        if let existing = existingAppliance {
            existing.category = category.rawValue
            existing.name = name.isEmpty ? category.rawValue : name
            existing.estimatedWattage = w
            existing.hoursPerDay = clampedH
            existing.quantity = quantity
            home.updatedAt = Date()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onComplete?()
            dismiss()
            return
        }

        guard savedAppliance == nil else {
            showingResult = true
            return
        }

        let validPhoto: Data? = {
            guard let img = prefilledImage, img.size.width > 1 else { return nil }
            return img.jpegData(compressionQuality: 0.7)
        }()

        let appliance = Appliance(
            category: category,
            name: name.isEmpty ? category.rawValue : name,
            estimatedWattage: w,
            hoursPerDay: clampedH,
            quantity: quantity,
            detectionMethod: detectionMethod,
            photoData: validPhoto
        )

        appliance.home = home
        appliance.room = selectedRoom
        modelContext.insert(appliance)
        home.updatedAt = Date()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        savedAppliance = appliance
        showingResult = true
    }
}
