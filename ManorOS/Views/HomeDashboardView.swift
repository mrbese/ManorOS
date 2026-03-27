import SwiftUI
import SwiftData
import UIKit

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var home: Home
    @State private var showingScan = false
    @State private var showingManualRoom = false
    @State private var editingPlaceholderRoom: Room?
    @State private var showingEquipmentScan = false
    @State private var showingApplianceScan = false
    @State private var showingApplianceManual = false
    @State private var showingLightingScan = false
    @State private var showingBillScan = false
    @State private var showingBillManual = false
    @State private var showingBillDetails = false
    @State private var showingBillDetailsPrefill: (ParsedBillResult, UIImage)?
    @State private var showingAuditFlow = false

    // Delete confirmation state
    @State private var roomToDelete: Room?
    @State private var equipmentToDelete: Equipment?
    @State private var applianceToDelete: Appliance?
    @State private var billToDelete: EnergyBill?

    // Edit state
    @State private var editingRoom: Room?
    @State private var editingEquipment: Equipment?
    @State private var editingAppliance: Appliance?

    private var isAuditComplete: Bool {
        home.currentAudit?.isComplete ?? false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                auditBanner
                summaryCard
                roomsSection
                equipmentSection
                appliancesSection
                billsSection
                reportButton
            }
            .padding()
        }
        .navigationTitle(home.name.isEmpty ? "Home" : home.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingScan) {
            ScanView(home: home)
        }
        .sheet(isPresented: $showingManualRoom) {
            DetailsView(squareFootage: nil, home: home, onComplete: {
                showingManualRoom = false
            })
        }
        .sheet(item: $editingPlaceholderRoom) { room in
            DetailsView(squareFootage: nil, home: home, existingRoom: room, onComplete: {
                editingPlaceholderRoom = nil
            })
        }
        .sheet(isPresented: $showingEquipmentScan) {
            EquipmentDetailsView(home: home, onComplete: {
                showingEquipmentScan = false
            })
        }
        .sheet(isPresented: $showingApplianceScan, onDismiss: {
            if showingApplianceDetailsPrefill != nil {
                showingApplianceDetails = true
            }
        }) {
            ApplianceScanView { result, image in
                showingApplianceDetailsPrefill = (result.category, image)
                showingApplianceScan = false
            }
        }
        .sheet(isPresented: $showingApplianceManual) {
            ApplianceDetailsView(home: home, onComplete: {
                showingApplianceManual = false
            })
        }
        .sheet(isPresented: $showingApplianceDetails, onDismiss: { showingApplianceDetailsPrefill = nil }) {
            if let (category, image) = showingApplianceDetailsPrefill {
                ApplianceDetailsView(
                    home: home,
                    prefilledCategory: category,
                    prefilledImage: image,
                    detectionMethod: "camera",
                    onComplete: { showingApplianceDetails = false }
                )
            }
        }
        .sheet(isPresented: $showingLightingScan, onDismiss: {
            if showingLightingDetailsPrefill != nil {
                showingLightingDetails = true
            }
        }) {
            LightingCloseupView { result, image in
                showingLightingDetailsPrefill = (result, image)
                showingLightingScan = false
            }
        }
        .sheet(isPresented: $showingLightingDetails, onDismiss: { showingLightingDetailsPrefill = nil }) {
            if let (result, image) = showingLightingDetailsPrefill {
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
        .sheet(isPresented: $showingBillScan, onDismiss: {
            if showingBillDetailsPrefill != nil {
                showingBillDetails = true
            } else if pendingBillManual {
                pendingBillManual = false
                showingBillManual = true
            }
        }) {
            BillUploadView(
                onResult: { result, image in
                    showingBillDetailsPrefill = (result, image)
                    showingBillScan = false
                },
                onManual: {
                    pendingBillManual = true
                    showingBillScan = false
                }
            )
        }
        .sheet(isPresented: $showingBillManual) {
            BillDetailsView(home: home, onComplete: {
                showingBillManual = false
            })
        }
        .sheet(isPresented: $showingBillDetails, onDismiss: { showingBillDetailsPrefill = nil }) {
            if let (result, image) = showingBillDetailsPrefill {
                BillDetailsView(
                    home: home,
                    prefilledResult: result,
                    prefilledImage: image,
                    onComplete: { showingBillDetails = false }
                )
            }
        }
        .sheet(isPresented: $showingAuditFlow) {
            AuditFlowView(home: home)
        }
        .sheet(item: $editingRoom) { room in
            DetailsView(squareFootage: nil, home: home, existingRoom: room, onComplete: {
                editingRoom = nil
            })
        }
        .sheet(item: $editingEquipment) { item in
            EquipmentDetailsView(home: home, existingEquipment: item, onComplete: {
                editingEquipment = nil
            })
        }
        .sheet(item: $editingAppliance) { appliance in
            ApplianceDetailsView(home: home, existingAppliance: appliance, onComplete: {
                editingAppliance = nil
            })
        }
        .confirmationDialog(
            "Delete Room",
            isPresented: Binding(get: { roomToDelete != nil }, set: { if !$0 { roomToDelete = nil } }),
            presenting: roomToDelete
        ) { room in
            Button("Delete \"\(room.name.isEmpty ? "Unnamed Room" : room.name)\"", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                home.updatedAt = Date()
                modelContext.delete(room)
                roomToDelete = nil
            }
        } message: { _ in
            Text("This will permanently delete this room and its data.")
        }
        .confirmationDialog(
            "Delete Equipment",
            isPresented: Binding(get: { equipmentToDelete != nil }, set: { if !$0 { equipmentToDelete = nil } }),
            presenting: equipmentToDelete
        ) { item in
            Button("Delete \"\(item.typeEnum.rawValue)\"", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                home.updatedAt = Date()
                modelContext.delete(item)
                equipmentToDelete = nil
            }
        } message: { _ in
            Text("This will permanently delete this equipment and its data.")
        }
        .confirmationDialog(
            "Delete Appliance",
            isPresented: Binding(get: { applianceToDelete != nil }, set: { if !$0 { applianceToDelete = nil } }),
            presenting: applianceToDelete
        ) { appliance in
            Button("Delete \"\(appliance.name)\"", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                home.updatedAt = Date()
                modelContext.delete(appliance)
                applianceToDelete = nil
            }
        } message: { _ in
            Text("This will permanently delete this appliance and its data.")
        }
        .confirmationDialog(
            "Delete Bill",
            isPresented: Binding(get: { billToDelete != nil }, set: { if !$0 { billToDelete = nil } }),
            presenting: billToDelete
        ) { bill in
            Button("Delete \"\(bill.utilityName ?? "Utility Bill")\"", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                home.updatedAt = Date()
                modelContext.delete(bill)
                billToDelete = nil
            }
        } message: { _ in
            Text("This will permanently delete this bill and its data.")
        }
    }

    // Additional state for camera→details flow
    @State private var showingApplianceDetails = false
    @State private var showingApplianceDetailsPrefill: (ApplianceCategory, UIImage)?
    @State private var showingLightingDetails = false
    @State private var showingLightingDetailsPrefill: (BulbOCRResult, UIImage)?
    @State private var pendingBillManual = false

    // MARK: - Audit Banner

    private var auditBanner: some View {
        Group {
            if let audit = home.currentAudit {
                if audit.isComplete {
                    // Completed audit badge
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(Color.manor.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Audit Complete")
                                .font(.subheadline.bold())
                            Text("All steps finished")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(audit.progressPercentage))%")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(Color.manor.primary)
                    }
                    .padding(14)
                    .background(Color.manor.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                } else {
                    // In-progress audit
                    Button { showingAuditFlow = true } label: {
                        HStack(spacing: 12) {
                            // Mini progress ring
                            ZStack {
                                Circle()
                                    .stroke(Color.manor.outlineVariant, lineWidth: 3)
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .trim(from: 0, to: audit.progressPercentage / 100)
                                    .stroke(Color.manor.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 36, height: 36)
                                    .rotationEffect(.degrees(-90))
                                Text("\(Int(audit.progressPercentage))%")
                                    .font(.caption2.bold().monospacedDigit())
                            }
                            .accessibilityLabel("Audit progress: \(Int(audit.progressPercentage)) percent complete")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Continue Audit")
                                    .font(.subheadline.bold())
                                Text("Step \(audit.currentStepEnum.stepNumber): \(audit.currentStepEnum.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color.manor.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Continue audit, \(Int(audit.progressPercentage)) percent complete, step \(audit.currentStepEnum.stepNumber): \(audit.currentStepEnum.rawValue)")
                }
            } else {
                // No audit yet — start CTA
                Button { showingAuditFlow = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.title2)
                            .foregroundStyle(Color.manor.onPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Full Audit")
                                .font(.subheadline.bold())
                            Text("Guided energy assessment")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    .foregroundStyle(Color.manor.onPrimary)
                    .padding(14)
                    .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    if !home.equipment.isEmpty {
                        let grade = GradingEngine.grade(for: home.equipment)
                        Text(grade.rawValue)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.manor.onPrimary)
                        Text("Efficiency")
                            .font(.caption)
                            .foregroundStyle(Color.manor.onPrimary.opacity(0.8))
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.manor.onPrimary.opacity(0.5))
                        Text("No Data")
                            .font(.caption)
                            .foregroundStyle(Color.manor.onPrimary.opacity(0.6))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if home.computedTotalSqFt > 0 {
                        Label("\(Int(home.computedTotalSqFt)) sq ft", systemImage: "square.dashed")
                    }
                    Label("\(home.rooms.count) room\(home.rooms.count == 1 ? "" : "s")", systemImage: "square.split.2x2")
                    Label("\(home.equipment.count) equipment", systemImage: "wrench")
                    if !home.appliances.isEmpty {
                        Label("\(home.appliances.count) appliance\(home.appliances.count == 1 ? "" : "s")", systemImage: "tv")
                    }
                    if !home.energyBills.isEmpty {
                        Label("\(home.energyBills.count) bill\(home.energyBills.count == 1 ? "" : "s")", systemImage: "doc.text")
                    }
                    Label(home.climateZoneEnum.rawValue, systemImage: "thermometer")
                }
                .font(.subheadline)
                .foregroundStyle(Color.manor.onPrimary.opacity(0.9))

                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Rooms

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rooms")
                    .font(.headline)
                Spacer()
                if isAuditComplete {
                    Menu {
                        if RoomCaptureService.isLiDARAvailable {
                            Button(action: { showingScan = true }) {
                                Label("Scan Room (LiDAR)", systemImage: "camera.viewfinder")
                            }
                        }
                        Button(action: { showingManualRoom = true }) {
                            Label("Enter Manually", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.manor.primary)
                    }
                    .accessibilityLabel("Add room")
                }
            }

            if home.rooms.isEmpty {
                Text("No rooms scanned yet. Add a room to start your assessment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                    let completedRooms = home.rooms.filter { $0.squareFootage > 0 }
                    let placeholderRooms = home.rooms.filter { $0.squareFootage == 0 }

                    if !placeholderRooms.isEmpty {
                        HStack(spacing: 8) {
                            Text("\(completedRooms.count) of \(home.rooms.count) rooms set up")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    ForEach(home.rooms) { room in
                        if room.squareFootage > 0 {
                            // Completed room — navigate to results
                            NavigationLink {
                                ResultsView(room: room)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                            .font(.subheadline.bold())
                                        Text("\(Int(room.squareFootage)) sq ft")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(room.calculatedBTU).formatted()) BTU")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Color.manor.primary)
                                }
                                .padding(12)
                                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                                .shadow(color: Color.manor.background.opacity(0.08), radius: 4, y: 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(room.name.isEmpty ? "Unnamed Room" : room.name), \(Int(room.squareFootage)) square feet, \(Int(room.calculatedBTU)) BTU")
                            .contextMenu {
                            Button {
                                editingRoom = room
                            } label: {
                                Label("Edit Details", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                roomToDelete = room
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        Button {
                            editingPlaceholderRoom = room
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                        .font(.subheadline.bold())
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right.circle")
                                            .font(.caption2)
                                        Text("Ready to set up")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.manor.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.manor.primary)
                            }
                            .padding(12)
                            .background(.background, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color.manor.background.opacity(0.08), radius: 4, y: 1)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                home.updatedAt = Date()
                                modelContext.delete(room)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Equipment

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Equipment")
                    .font(.headline)
                Spacer()
                if isAuditComplete {
                    Button(action: { showingEquipmentScan = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.manor.primary)
                    }
                    .accessibilityLabel("Add equipment")
                }
            }

            if home.equipment.isEmpty {
                Text("No equipment logged yet. Add your HVAC, water heater, and more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(home.equipment) { item in
                    NavigationLink {
                        EquipmentResultView(equipment: item, home: home)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.typeEnum.icon)
                                .font(.title3)
                                .foregroundStyle(Color.manor.primary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.typeEnum.rawValue)
                                    .font(.subheadline.bold())
                                HStack(spacing: 4) {
                                    Text(item.ageRangeEnum.shortLabel)
                                    if let mfr = item.manufacturer {
                                        Text("| \(mfr)")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(String(format: "%.1f", item.estimatedEfficiency)) \(item.typeEnum.efficiencyUnit)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.manor.primary)
                        }
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.manor.background.opacity(0.08), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.typeEnum.rawValue), efficiency \(String(format: "%.1f", item.estimatedEfficiency)) \(item.typeEnum.efficiencyUnit)")
                    .contextMenu {
                        Button {
                            editingEquipment = item
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            equipmentToDelete = item
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Appliances

    private var appliancesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Appliances")
                    .font(.headline)
                Spacer()
                if isAuditComplete {
                    Menu {
                        Button(action: { showingApplianceScan = true }) {
                            Label("Scan with Camera", systemImage: "camera.fill")
                        }
                        Button(action: { showingLightingScan = true }) {
                            Label("Scan Bulb Label", systemImage: "lightbulb")
                        }
                        Button(action: { showingApplianceManual = true }) {
                            Label("Enter Manually", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.manor.primary)
                    }
                    .accessibilityLabel("Add appliance")
                }
            }

            if home.appliances.isEmpty {
                Text("No appliances tracked yet. Scan or add appliances, lighting, and electronics.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                // Summary row
                let totalKWh = home.totalApplianceAnnualKWh
                let totalCost = totalKWh * home.actualElectricityRate
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(totalKWh)) kWh/yr")
                            .font(.subheadline.bold().monospacedDigit())
                        Text("Total usage")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("$\(Int(totalCost))/yr")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(Color.manor.primary)
                        Text("Total cost")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if home.totalPhantomLoadWatts > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(home.totalPhantomLoadWatts))W")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(Color.manor.warning)
                            Text("Standby")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.manor.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                ForEach(home.appliances) { appliance in
                    NavigationLink {
                        ApplianceResultView(appliance: appliance, home: home)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: appliance.categoryEnum.icon)
                                .font(.title3)
                                .foregroundStyle(Color.manor.primary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appliance.name)
                                    .font(.subheadline.bold())
                                HStack(spacing: 4) {
                                    Text("\(Int(appliance.estimatedWattage))W")
                                    Text("·")
                                    Text(formatHours(appliance.hoursPerDay) + " hrs/day")
                                    if appliance.quantity > 1 {
                                        Text("· x\(appliance.quantity)")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$\(Int(appliance.annualCost()))/yr")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.manor.primary)
                        }
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.manor.background.opacity(0.08), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editingAppliance = appliance
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            applianceToDelete = appliance
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Energy Bills

    private var billsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Energy Bills")
                    .font(.headline)
                Spacer()
                if isAuditComplete {
                    Menu {
                        Button(action: { showingBillScan = true }) {
                            Label("Scan Bill", systemImage: "camera.fill")
                        }
                        Button(action: { showingBillManual = true }) {
                            Label("Enter Manually", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.manor.primary)
                    }
                    .accessibilityLabel("Add energy bill")
                }
            }

            if home.energyBills.isEmpty {
                Text("No bills uploaded yet. Add utility bills to improve cost estimates.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                // Summary row
                let avgRate = home.actualElectricityRate
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "$%.3f/kWh", avgRate))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(Color.manor.primary)
                        Text("Avg rate")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let annualKWh = home.billBasedAnnualKWh {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(annualKWh)) kWh/yr")
                                .font(.subheadline.bold().monospacedDigit())
                            Text("Annualized")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(home.energyBills.count) bill\(home.energyBills.count == 1 ? "" : "s")")
                            .font(.subheadline.bold().monospacedDigit())
                        Text("Uploaded")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.manor.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                ForEach(home.energyBills) { bill in
                    NavigationLink {
                        BillSummaryView(bill: bill)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.title3)
                                .foregroundStyle(Color.manor.primary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                if let name = bill.utilityName {
                                    Text(name)
                                        .font(.subheadline.bold())
                                } else {
                                    Text("Utility Bill")
                                        .font(.subheadline.bold())
                                }
                                if let start = bill.billingPeriodStart {
                                    Text(Self.billDateFormatter.string(from: start))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(bill.totalKWh)) kWh")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.manor.primary)
                                Text(String(format: "$%.2f", bill.totalCost))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.manor.background.opacity(0.08), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            billToDelete = bill
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Report

    private var reportButton: some View {
        Group {
            if !home.equipment.isEmpty || !home.rooms.isEmpty {
                NavigationLink {
                    HomeReportView(home: home)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Full Report").fontWeight(.semibold)
                            Text("Assessment summary with upgrade plan").font(.caption).opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    .foregroundStyle(Color.manor.onPrimary)
                    .padding()
                    .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private static let billDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private func formatHours(_ hours: Double) -> String {
        if hours == floor(hours) { return String(Int(hours)) }
        return String(format: "%.1f", hours)
    }
}
