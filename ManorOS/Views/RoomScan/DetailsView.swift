import SwiftUI
import SwiftData
import CoreLocation

struct DetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Input from scan (nil = manual entry)
    let scannedSqFt: Double?
    let windowsFromScan: Bool   // true when windows were auto-populated
    var home: Home? = nil
    var existingRoom: Room? = nil  // non-nil = editing an existing room
    var onComplete: (() -> Void)? = nil

    // Form state
    @State private var roomName: String = ""
    @State private var squareFootage: String = ""
    @State private var ceilingHeight: CeilingHeightOption = .eight
    @State private var climateZone: ClimateZone = .moderate
    @State private var insulation: InsulationQuality = .unknown
    @State private var windows: [WindowInfo] = []
    @State private var showingResults = false
    @State private var savedRoom: Room?
    @State private var windowQuestionnaireIndex: WindowEditID?
    @State private var sqFtError: String? = nil

    @StateObject private var locationDetector = ClimateZoneDetector()

    init(squareFootage: Double?, scannedWindows: [WindowInfo] = [], home: Home? = nil, existingRoom: Room? = nil, onComplete: (() -> Void)? = nil) {
        self.scannedSqFt = squareFootage
        self.windowsFromScan = !scannedWindows.isEmpty
        self.home = home
        self.existingRoom = existingRoom
        self.onComplete = onComplete

        // Pre-populate from existing room if editing
        if let room = existingRoom {
            _roomName = State(initialValue: room.name)
            if room.squareFootage > 0 {
                _squareFootage = State(initialValue: "\(Int(room.squareFootage))")
            }
            _ceilingHeight = State(initialValue: room.ceilingHeightOption)
            _climateZone = State(initialValue: room.climateZoneEnum)
            _insulation = State(initialValue: room.insulationEnum)
            _windows = State(initialValue: room.windows)
        } else if let sqFt = squareFootage {
            _squareFootage = State(initialValue: "\(Int(sqFt))")
            // Mark scanned windows as unassessed — LiDAR can detect count/size/direction
            // but not pane type, frame material, or condition
            let preparedWindows = scannedWindows.map { w in
                var copy = w
                copy.paneType = .notAssessed
                copy.frameMaterial = .notAssessed
                copy.condition = .notAssessed
                return copy
            }
            _windows = State(initialValue: preparedWindows)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                roomSection
                windowsSection
                environmentSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Room Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Calculate") {
                        saveAndCalculate()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.manor.primary)
                    .disabled(!isFormValid)
                }
            }
            .navigationDestination(isPresented: $showingResults) {
                if let room = savedRoom {
                    ResultsView(room: room, onComplete: onComplete)
                }
            }
            .sheet(item: $windowQuestionnaireIndex) { editID in
                if editID.index >= 0 && editID.index < windows.count {
                    WindowQuestionnaireView(window: $windows[editID.index])
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
                // Default to home's climate zone if available; fall back to GPS detection
                if let homeZone = home?.climateZoneEnum {
                    climateZone = homeZone
                } else {
                    locationDetector.detectClimateZoneViaGPS { zone in
                        if let zone { climateZone = zone }
                    }
                }
            }
        }
    }

    // MARK: - Form sections

    private var roomSection: some View {
        Section("Room Info") {
            TextField("Room Name (e.g. Living Room)", text: $roomName)

            if roomName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Room name is required")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Floor Area")
                Spacer()
                TextField("sq ft", text: $squareFootage)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("sq ft")
                    .foregroundStyle(.secondary)
            }

            if let error = sqFtError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if scannedSqFt != nil {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .foregroundStyle(Color.manor.primary)
                    Text("Detected by LiDAR scan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Ceiling Height", selection: $ceilingHeight) {
                ForEach(CeilingHeightOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        }
    }

    private var windowsSection: some View {
        Section {
            ForEach(Array(windows.enumerated()), id: \.element.id) { index, _ in
                WindowRowView(window: $windows[index]) {
                    windowQuestionnaireIndex = WindowEditID(index: index)
                }
            }
            .onDelete { indexSet in
                windows.remove(atOffsets: indexSet)
            }

            Button(action: { windows.append(WindowInfo()) }) {
                Label("Add Window", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color.manor.primary)
            }
        } header: {
            Text("Windows (\(windows.count))")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if windowsFromScan && !windows.isEmpty {
                    Label("Count, size, and direction detected by LiDAR. Pane type, frame, and condition need manual assessment.", systemImage: "camera.viewfinder")
                        .font(.caption)
                        .foregroundStyle(Color.manor.primary)
                }
                if !windows.isEmpty {
                    Text("Tap the info button on each window to assess pane type, frame, and condition.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var environmentSection: some View {
        Section {
            Picker("Climate Zone", selection: $climateZone) {
                ForEach(ClimateZone.allCases) { zone in
                    VStack(alignment: .leading) {
                        Text(zone.rawValue)
                        Text(zone.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(zone)
                }
            }
            .pickerStyle(.navigationLink)

            if let city = locationDetector.detectedCity {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(Color.manor.primary)
                    Text("Based on your location (\(city))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if locationDetector.locationDenied {
                Text("Location unavailable. Select your climate zone manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Climate zone affects heating/cooling load calculations.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Insulation Quality", selection: $insulation) {
                Text("Select...").tag(InsulationQuality.unknown)
                ForEach(InsulationQuality.selectableCases) { quality in
                    VStack(alignment: .leading) {
                        Text(quality.rawValue)
                        Text(quality.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(quality)
                }
            }
            .pickerStyle(.navigationLink)

            if !insulation.isSelected {
                Text("How would you rate your insulation? Check your attic or ask your home inspector.")
                    .font(.caption)
                    .foregroundStyle(Color.manor.warning)
            }
        } header: {
            Text("Environment")
        }
    }

    // MARK: - Logic

    private var isFormValid: Bool {
        guard !roomName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let sqFt = Double(squareFootage), sqFt > 0, sqFt <= 10000 else { return false }
        return true
    }

    private func saveAndCalculate() {
        guard let sqFt = Double(squareFootage), sqFt > 0, sqFt <= 10000 else {
            sqFtError = "Please enter a valid square footage (1–10,000 sq ft)"
            return
        }
        sqFtError = nil

        let breakdown = EnergyCalculator.calculate(
            squareFootage: sqFt,
            ceilingHeight: ceilingHeight,
            climateZone: climateZone,
            insulation: insulation,
            windows: windows
        )

        if let existing = savedRoom {
            existing.name = roomName
            existing.squareFootage = sqFt
            existing.ceilingHeight = ceilingHeight.feet
            existing.climateZone = climateZone.rawValue
            existing.insulation = insulation.rawValue
            existing.windows = windows
            existing.calculatedBTU = breakdown.finalBTU
            existing.calculatedTonnage = breakdown.tonnage
            existing.scanWasUsed = scannedSqFt != nil
            if let home { home.updatedAt = Date() }
        } else if let existingRoom {
            existingRoom.name = roomName
            existingRoom.squareFootage = sqFt
            existingRoom.ceilingHeight = ceilingHeight.feet
            existingRoom.climateZone = climateZone.rawValue
            existingRoom.insulation = insulation.rawValue
            existingRoom.windows = windows
            existingRoom.calculatedBTU = breakdown.finalBTU
            existingRoom.calculatedTonnage = breakdown.tonnage
            existingRoom.scanWasUsed = scannedSqFt != nil
            if let home { home.updatedAt = Date() }
            savedRoom = existingRoom
        } else {
            let room = Room(
                name: roomName,
                squareFootage: sqFt,
                ceilingHeight: ceilingHeight.feet,
                climateZone: climateZone,
                insulation: insulation,
                windows: windows,
                calculatedBTU: breakdown.finalBTU,
                calculatedTonnage: breakdown.tonnage,
                scanWasUsed: scannedSqFt != nil
            )

            if let home {
                room.home = home
                home.updatedAt = Date()
            }
            modelContext.insert(room)
            savedRoom = room
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showingResults = true
    }
}

// MARK: - Window row (enhanced)

private struct WindowRowView: View {
    @Binding var window: WindowInfo
    var onAssess: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "window.casement")
                .foregroundStyle(Color.manor.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Picker("Direction", selection: $window.direction) {
                        ForEach(CardinalDirection.allCases) { dir in
                            Text(dir.fullName).tag(dir)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Picker("Size", selection: $window.size) {
                        ForEach(WindowSize.allCases) { size in
                            Text(size.description).tag(size)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .font(.caption)
                }

                // Enhanced info line
                if window.isFullyAssessed {
                    HStack(spacing: 6) {
                        Text(window.paneType.label)
                        Text("·")
                        Text(window.frameMaterial.rawValue)
                        Text("·")
                        Text(window.condition.rawValue)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption2)
                        Text("Needs assessment — tap")
                        Image(systemName: "info.circle")
                            .font(.caption2)
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.manor.warning)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(Int(window.heatGainBTU).formatted()) BTU")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                // Info/assess button
                Button(action: onAssess) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(Color.manor.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wrapper to make an index Identifiable for sheet(item:) presentation
struct WindowEditID: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Location-based climate zone detection

@MainActor
final class ClimateZoneDetector: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var completion: ((ClimateZone?) -> Void)?

    @Published var detectedCity: String?
    @Published var locationDenied: Bool = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func detectClimateZoneViaGPS(completion: @escaping (ClimateZone?) -> Void) {
        self.completion = completion
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            locationDenied = true
            completion(nil)
        }
    }

    func geocodeAddress(_ address: String, completion: @escaping (ClimateZone?) -> Void) {
        CLGeocoder().geocodeAddressString(address) { placemarks, error in
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                Task { @MainActor in
                    completion(nil)
                }
                return
            }
            let lat = location.coordinate.latitude
            let zone: ClimateZone
            if lat < 32 { zone = .hot }
            else if lat < 40 { zone = .moderate }
            else { zone = .cold }

            let city = [placemark.locality, placemark.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")

            Task { @MainActor [weak self] in
                if !city.isEmpty { self?.detectedCity = city }
                completion(zone)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        let lat = location.coordinate.latitude
        let zone: ClimateZone
        if lat < 32 { zone = .hot }
        else if lat < 40 { zone = .moderate }
        else { zone = .cold }

        // Reverse geocode for city name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            let city = placemarks?.first.flatMap { placemark in
                [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
            }
            Task { @MainActor [weak self] in
                self?.detectedCity = city
                self?.completion?(zone)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.locationDenied = true
            self?.completion?(nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
            manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            Task { @MainActor [weak self] in
                self?.locationDenied = true
                self?.completion?(nil)
            }
        }
    }
}
