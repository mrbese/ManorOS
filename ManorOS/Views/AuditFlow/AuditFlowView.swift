import SwiftUI
import SwiftData
import UIKit

struct AuditFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var home: Home
    var isEmbedded: Bool = false

    @State private var currentStep: AuditStep = .roomScanning
    @State private var audit: AuditProgress?

    // Sub-view presentation states
    @State private var showingScan = false
    @State private var showingApplianceScan = false
    @State private var showingLightingScan = false
    @State private var showingBillScan = false

    // Camera → details hand-off
    @State private var showingApplianceDetails = false
    @State private var appliancePrefill: (ApplianceCategory, UIImage)?
    @State private var showingLightingDetails = false
    @State private var lightingPrefill: (BulbOCRResult, UIImage)?
    @State private var showingBillDetails = false
    @State private var billPrefill: (ParsedBillResult, UIImage)?

    private let hvacTypes: [EquipmentType] = [.centralAC, .heatPump, .furnace, .windowUnit]
    private let waterTypes: [EquipmentType] = [.waterHeater, .waterHeaterTankless]

    var body: some View {
        if isEmbedded {
            flowContent
                .navigationTitle("Home Audit")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            NavigationStack {
                flowContent
                    .navigationTitle("Home Audit")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") { dismiss() }
                        }
                    }
            }
        }
    }

    private var flowContent: some View {
        VStack(spacing: 0) {
            if let audit {
                AuditProgressBar(auditProgress: audit, currentStep: currentStep)
            }

            // Step content
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: currentStep)

            bottomBar
        }
        .onAppear { setupAudit() }
        // Camera sheets
        .sheet(isPresented: $showingScan) {
            ScanView(home: home)
        }
        .sheet(isPresented: $showingApplianceScan) {
            ApplianceScanView { result, image in
                showingApplianceScan = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appliancePrefill = (result.category, image)
                    showingApplianceDetails = true
                }
            }
        }
        .sheet(isPresented: $showingApplianceDetails) {
            if let (category, image) = appliancePrefill {
                ApplianceDetailsView(
                    home: home,
                    prefilledCategory: category,
                    prefilledImage: image,
                    detectionMethod: "camera",
                    onComplete: { showingApplianceDetails = false }
                )
            }
        }
        .sheet(isPresented: $showingLightingScan) {
            LightingCloseupView { result, image in
                showingLightingScan = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    lightingPrefill = (result, image)
                    showingLightingDetails = true
                }
            }
        }
        .sheet(isPresented: $showingLightingDetails) {
            if let (result, image) = lightingPrefill {
                ApplianceDetailsView(
                    home: home,
                    prefilledCategory: result.bulbType ?? .ledBulb,
                    prefilledWattage: result.wattage,
                    prefilledImage: image,
                    detectionMethod: "ocr",
                    onComplete: { showingLightingDetails = false }
                )
            }
        }
        .sheet(isPresented: $showingBillScan) {
            BillUploadView(
                onResult: { result, image in
                    showingBillScan = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        billPrefill = (result, image)
                        showingBillDetails = true
                    }
                },
                onManual: {
                    showingBillScan = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingBillDetails = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingBillDetails) {
            if let (result, image) = billPrefill {
                BillDetailsView(
                    home: home,
                    prefilledResult: result,
                    prefilledImage: image,
                    onComplete: { showingBillDetails = false }
                )
            } else {
                BillDetailsView(home: home, onComplete: { showingBillDetails = false })
            }
        }
        // Equipment & room sheets (moved from bottom bar background)
        .sheet(isPresented: $showingEquipmentSheet) {
            EquipmentDetailsView(
                home: home,
                allowedTypes: pendingEquipmentTypes.isEmpty ? nil : pendingEquipmentTypes,
                onComplete: { showingEquipmentSheet = false }
            )
        }
        .sheet(isPresented: $showingManualRoom) {
            DetailsView(squareFootage: nil, home: home, onComplete: {
                showingManualRoom = false
            })
        }
        .sheet(isPresented: $showingApplianceManual) {
            ApplianceDetailsView(home: home, onComplete: { showingApplianceManual = false })
        }
        .sheet(isPresented: $showingLightingManual) {
            ApplianceDetailsView(
                home: home,
                prefilledCategory: .ledBulb,
                onComplete: { showingLightingManual = false }
            )
        }
        .sheet(item: $windowEditRoom) { room in
            DetailsView(squareFootage: nil, home: home, existingRoom: room, onComplete: {
                windowEditRoom = nil
            })
        }
        .sheet(item: $auditEditingRoom) { room in
            DetailsView(squareFootage: nil, home: home, existingRoom: room, onComplete: {
                auditEditingRoom = nil
            })
        }
        .sheet(item: $scanningPlaceholderRoom) { room in
            ScanView(home: home, existingRoom: room)
        }
    }

    // MARK: - Setup

    private func setupAudit() {
        if let existing = home.currentAudit {
            audit = existing
            migrateOldSteps(existing)
            currentStep = existing.currentStepEnum
        } else {
            let newAudit = AuditProgress(home: home)
            modelContext.insert(newAudit)
            audit = newAudit
            currentStep = .roomScanning
        }
        autoCompleteCurrentStep()
    }

    private func migrateOldSteps(_ audit: AuditProgress) {
        if AuditStep(rawValue: audit.currentStep) == nil,
           let migrated = AuditStep.migrateRawValue(audit.currentStep) {
            audit.currentStep = migrated
        }
        // Re-encode completedSteps through the getter/setter to trigger migration
        let migrated = audit.completedSteps
        audit.completedSteps = migrated
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .roomScanning:
            roomScanningStep
        case .equipment:
            equipmentCombinedStep
        case .appliancesAndLighting:
            appliancesAndLightingStep
        case .buildingEnvelope:
            buildingEnvelopeStep
        case .billUpload:
            billStep
        case .review:
            reviewStep
        }
    }

    // MARK: - Step 1: Room Scanning

    private var roomScanningStep: some View {
        let completedRooms = home.rooms.filter { $0.squareFootage > 0 }
        let placeholderRooms = home.rooms.filter { $0.squareFootage == 0 }

        return ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "camera.viewfinder",
                    title: "Room Scanning",
                    subtitle: "Add rooms to your home. Use LiDAR scanning or enter manually."
                )

                if !completedRooms.isEmpty {
                    completedBadge("\(completedRooms.count) room\(completedRooms.count == 1 ? "" : "s") scanned")
                    ForEach(completedRooms) { room in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.manor.success)
                            Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(room.squareFootage)) sq ft")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                if !placeholderRooms.isEmpty {
                    ForEach(placeholderRooms) { room in
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Color.manor.warning)
                                Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("Needs details")
                                    .font(.caption)
                                    .foregroundStyle(Color.manor.warning)
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                            HStack(spacing: 8) {
                                if RoomCaptureService.isLiDARAvailable {
                                    Button {
                                        scanningPlaceholderRoom = room
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "camera.viewfinder")
                                            Text("Scan")
                                        }
                                        .font(.caption.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(Color.manor.primary)
                                        .background(Color.manor.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    auditEditingRoom = room
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                        Text("Enter Manually")
                                    }
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(Color.manor.primary)
                                    .background(Color.manor.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                HStack(spacing: 12) {
                    if RoomCaptureService.isLiDARAvailable {
                        actionButton(icon: "camera.viewfinder", label: "Scan Room") {
                            showingScan = true
                        }
                    }
                    actionButton(icon: "pencil", label: "Enter Manually") {
                        showingManualRoom = true
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Step 2: Equipment (HVAC + Water Heating combined)

    private var equipmentCombinedStep: some View {
        let hvac = home.equipment.filter { hvacTypes.contains($0.typeEnum) }
        let water = home.equipment.filter { waterTypes.contains($0.typeEnum) }

        return ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "wrench.and.screwdriver",
                    title: "Equipment",
                    subtitle: "Log your HVAC systems and water heater."
                )

                if hvac.isEmpty && water.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.manor.primary.opacity(0.6))
                        Text("No equipment added yet")
                            .font(.headline)
                        Text("Add your heating/cooling systems and water heater. Check the equipment label for model and efficiency information.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                } else {
                    if !hvac.isEmpty {
                        Text("HVAC")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(hvac) { eq in equipmentRow(eq) }
                    }
                    if !water.isEmpty {
                        Text("Water Heating")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(water) { eq in equipmentRow(eq) }
                    }
                }

                actionButton(icon: "plus.circle.fill", label: "Add Equipment") {
                    showingEquipmentSheet = true
                    pendingEquipmentTypes = []
                }
            }
            .padding(20)
        }
    }

    private func equipmentRow(_ eq: Equipment) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.manor.success)
            Text(eq.typeEnum.rawValue)
                .font(.subheadline)
            Spacer()
            Text("\(String(format: "%.1f", eq.estimatedEfficiency)) \(eq.typeEnum.efficiencyUnit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @State private var showingEquipmentSheet = false
    @State private var pendingEquipmentTypes: [EquipmentType] = []
    @State private var showingManualRoom = false
    @State private var windowEditRoom: Room?
    @State private var auditEditingRoom: Room?
    @State private var scanningPlaceholderRoom: Room?


    // MARK: - Step 3: Appliances & Lighting (combined)

    private var appliancesAndLightingStep: some View {
        let nonLighting = home.appliances.filter { !$0.categoryEnum.isLighting }
        let lighting = home.appliances.filter { $0.categoryEnum.isLighting }

        return ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "powerplug",
                    title: "Appliances & Lighting",
                    subtitle: "Scan or add your appliances and lighting fixtures."
                )

                if nonLighting.isEmpty && lighting.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "powerplug")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.manor.primary.opacity(0.6))
                        Text("No appliances or lighting added yet")
                            .font(.headline)
                        Text("Add your major appliances and lighting. Scan labels with the camera or enter details manually.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                } else {
                    if !nonLighting.isEmpty {
                        Text("Appliances")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(nonLighting) { appliance in
                            applianceRow(appliance)
                        }
                    }
                    if !lighting.isEmpty {
                        Text("Lighting")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(lighting) { appliance in
                            applianceRow(appliance)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text("Appliances")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 12) {
                        actionButton(icon: "camera.fill", label: "Scan") {
                            showingApplianceScan = true
                        }
                        actionButton(icon: "pencil", label: "Manual") {
                            showingApplianceManual = true
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text("Lighting")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 12) {
                        actionButton(icon: "camera.fill", label: "Scan Label") {
                            showingLightingScan = true
                        }
                        actionButton(icon: "pencil", label: "Manual") {
                            showingLightingManual = true
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    @State private var showingApplianceManual = false
    @State private var showingLightingManual = false

    // MARK: - Step 4: Building Envelope (Windows + Envelope combined)

    @State private var showingEnvelopeAssessment = false

    private var buildingEnvelopeStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "house.and.flag",
                    title: "Building Envelope",
                    subtitle: "Assess windows in each room and your home's insulation and air sealing."
                )

                // Windows section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Windows")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let roomsWithWindows = home.rooms.filter { !$0.windows.isEmpty }
                    if !roomsWithWindows.isEmpty {
                        completedBadge("\(roomsWithWindows.count) room\(roomsWithWindows.count == 1 ? "" : "s") assessed")
                    }

                    if home.rooms.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "window.casement")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.manor.primary.opacity(0.6))
                            Text("No rooms added yet")
                                .font(.headline)
                            Text("Add rooms first (Step 1) before assessing windows.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    } else {
                        if roomsWithWindows.isEmpty {
                            Text("Tap a room below to add window types and note any drafts.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(home.rooms) { room in
                            Button {
                                windowEditRoom = room
                            } label: {
                                HStack {
                                    Image(systemName: room.windows.isEmpty ? "circle" : "checkmark.circle.fill")
                                        .foregroundStyle(room.windows.isEmpty ? Color.secondary : Color.manor.success)
                                    Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(room.windows.count) window\(room.windows.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Envelope section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Envelope Assessment")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if home.envelope != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.manor.success)
                            Text("Envelope assessment complete")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.manor.success)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.manor.success.opacity(0.1), in: Capsule())
                    }

                    actionButton(icon: "house.and.flag", label: home.envelope != nil ? "Update Envelope" : "Assess Envelope") {
                        showingEnvelopeAssessment = true
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showingEnvelopeAssessment) {
            NavigationStack {
                EnvelopeAssessmentView(home: home, onComplete: {
                    showingEnvelopeAssessment = false
                })
                .navigationTitle("Envelope Assessment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { showingEnvelopeAssessment = false }
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Bill Upload

    private var billStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "doc.text",
                    title: "Bill Upload",
                    subtitle: "Upload utility bills to calibrate energy cost estimates."
                )

                if home.energyBills.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.manor.primary.opacity(0.6))
                        Text("No bills uploaded yet")
                            .font(.headline)
                        Text("Upload recent utility bills to calibrate energy cost estimates and improve accuracy. You can scan a paper bill or enter usage manually.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                } else {
                    completedBadge("\(home.energyBills.count) bill\(home.energyBills.count == 1 ? "" : "s") uploaded")
                    ForEach(home.energyBills) { bill in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.manor.success)
                            Text(bill.utilityName ?? "Utility Bill")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(bill.totalKWh)) kWh")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                HStack(spacing: 12) {
                    actionButton(icon: "camera.fill", label: "Scan Bill") {
                        showingBillScan = true
                    }
                    actionButton(icon: "pencil", label: "Manual") {
                        billPrefill = nil
                        showingBillDetails = true
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Step 6: Review

    private var reviewStep: some View {
        VStack(spacing: 20) {
            stepHeader(
                icon: "checkmark.seal",
                title: "Review",
                subtitle: "Your audit is complete! View your full home energy report."
            )

            NavigationLink {
                HomeReportView(home: home)
                    .onAppear { completeCurrentStep() }
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("View Full Report")
                            .fontWeight(.semibold)
                        Text("Assessment summary with upgrade plan")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .opacity(0.7)
                }
                .foregroundStyle(Color.manor.onPrimary)
                .padding()
                .background(Color.manor.secondary, in: RoundedRectangle(cornerRadius: 14))
            }

            if let audit, audit.isComplete {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.manor.primary)
                    Text("Audit Complete!")
                        .font(.title2.bold())
                    Text("All steps finished.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if currentStep != .roomScanning {
                Button {
                    moveToPreviousStep()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if currentStep == .review {
                Button {
                    audit?.markComplete(.review)
                    AnalyticsService.track(.auditCompleted, properties: [
                        "homeName": home.name.isEmpty ? "Unnamed" : home.name
                    ])
                    dismiss()
                } label: {
                    Text("Finish")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.manor.onPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.manor.primary, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    Button {
                        moveToNextStep()
                    } label: {
                        Text("Skip")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        completeCurrentStep()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(Color.manor.onPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(isCurrentStepSatisfied ? Color.manor.primary : Color.gray, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isCurrentStepSatisfied)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Navigation Logic

    private var isCurrentStepSatisfied: Bool {
        switch currentStep {
        case .roomScanning: return home.rooms.contains { $0.squareFootage > 0 }
        case .equipment: return !home.equipment.isEmpty
        case .appliancesAndLighting: return !home.appliances.isEmpty
        case .buildingEnvelope: return home.envelope != nil || home.rooms.contains { !$0.windows.isEmpty }
        case .billUpload: return !home.energyBills.isEmpty
        case .review: return true
        }
    }

    private func autoCompleteCurrentStep() {
        // Auto-complete any steps that already have data
        for step in AuditStep.allCases where step != .review {
            if stepHasData(step) && !(audit?.isStepComplete(step) ?? true) {
                audit?.markComplete(step)
            }
        }
        // Skip to first incomplete step
        if let audit,
           let firstIncomplete = AuditStep.allCases.first(where: { !audit.isStepComplete($0) }) {
            currentStep = firstIncomplete
            audit.currentStep = firstIncomplete.rawValue
        }
    }

    private func stepHasData(_ step: AuditStep) -> Bool {
        switch step {
        case .roomScanning: return home.rooms.contains { $0.squareFootage > 0 }
        case .equipment: return !home.equipment.isEmpty
        case .appliancesAndLighting: return !home.appliances.isEmpty
        case .buildingEnvelope: return home.envelope != nil || home.rooms.contains { !$0.windows.isEmpty }
        case .billUpload: return !home.energyBills.isEmpty
        case .review: return false
        }
    }

    private func completeCurrentStep() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        audit?.markComplete(currentStep)
        if currentStep == .review {
            AnalyticsService.track(.auditCompleted, properties: [
                "homeName": home.name.isEmpty ? "Unnamed" : home.name
            ])
        }
        moveToNextStep()
    }

    private func moveToNextStep() {
        let allSteps = AuditStep.allCases
        guard let idx = allSteps.firstIndex(of: currentStep),
              idx + 1 < allSteps.count else { return }
        currentStep = allSteps[idx + 1]
        audit?.currentStep = currentStep.rawValue
    }

    private func moveToPreviousStep() {
        let allSteps = AuditStep.allCases
        guard let idx = allSteps.firstIndex(of: currentStep),
              idx > 0 else { return }
        currentStep = allSteps[idx - 1]
        audit?.currentStep = currentStep.rawValue
    }

    // MARK: - Shared Components

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.manor.primary)
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private func completedBadge(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.manor.success)
            Text(text)
                .font(.subheadline.bold())
                .foregroundStyle(Color.manor.success)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.manor.success.opacity(0.1), in: Capsule())
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.manor.primary)
            .background(Color.manor.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    private func applianceRow(_ appliance: Appliance) -> some View {
        HStack(spacing: 12) {
            Image(systemName: appliance.categoryEnum.icon)
                .foregroundStyle(Color.manor.primary)
                .frame(width: 24)
            Text(appliance.name)
                .font(.subheadline)
            Spacer()
            Text("\(Int(appliance.estimatedWattage))W")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
