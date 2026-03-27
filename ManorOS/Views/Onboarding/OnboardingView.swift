import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("userName") private var storedUserName = ""
    @AppStorage("userEmail") private var storedUserEmail = ""
    @AppStorage("notificationsRequested") private var notificationsRequested = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep = 0
    @State private var didFinish = false

    // Data collected across steps
    @State private var homeType: HomeType = .house
    @State private var address: String = ""
    @State private var homeName: String = ""
    @State private var yearBuilt: YearRange = .y1990to2005
    @State private var sqFtText: String = ""
    @State private var climateZone: ClimateZone = .moderate
    @State private var roomCount: Int = 4
    @State private var bedroomCount: Int = 2
    @State private var userName: String = ""
    @State private var userEmail: String = ""

    @StateObject private var locationDetector = ClimateZoneDetector()
    @StateObject private var addressService = AddressSearchService()
    @FocusState private var addressFieldFocused: Bool

    private let totalSteps = 6

    // Direction tracking for transitions
    @State private var movingForward = true

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(
                currentStep: currentStep,
                totalSteps: totalSteps,
                onBack: goBack
            )

            // Step content
            ZStack {
                stepView
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            bottomButton
        }
        .background(Color.manor.onboardingBackground.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: didFinish)
    }

    // MARK: - Step Router

    @ViewBuilder
    private var stepView: some View {
        switch currentStep {
        case 0:
            WelcomeHomeTypeStep(homeType: $homeType)
        case 1:
            AddressEntryStep(
                address: $address,
                addressService: addressService,
                addressFieldFocused: $addressFieldFocused,
                onSkip: { goForward() }
            )
        case 2:
            HomeDetailsStep(
                homeName: $homeName,
                yearBuilt: $yearBuilt,
                sqFtText: $sqFtText,
                climateZone: $climateZone,
                locationDetector: locationDetector
            )
            .onAppear { triggerClimateDetection() }
        case 3:
            RoomsStep(
                roomCount: $roomCount,
                bedroomCount: $bedroomCount,
                generateRoomNames: generateRoomNames
            )
        case 4:
            CreateAccountStep(
                userName: $userName,
                userEmail: $userEmail,
                onSkip: { goForward() }
            )
        case 5:
            NotificationsStep(onRequestPermission: requestNotifications)
        default:
            EmptyView()
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        let buttonDisabled: Bool = {
            if currentStep == 4 {
                // Disabled if email mode is active but fields are empty — but we can't
                // observe that internal state here, so we just never disable step 4
                // (the CreateAccountStep has its own skip button)
                return false
            }
            return false
        }()

        let buttonTitle: String = {
            switch currentStep {
            case 0: return "Get Started"
            case 5: return "Let's Go"
            default: return "Continue"
            }
        }()

        return Button {
            if currentStep < totalSteps - 1 {
                goForward()
            } else {
                createHomeAndFinish()
            }
        } label: {
            Text(buttonTitle)
                .font(.headline)
                .foregroundStyle(Color.manor.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    (buttonDisabled ? Color.manor.textDisabled : Color.manor.primary),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .disabled(buttonDisabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Navigation

    private func goForward() {
        movingForward = true
        withAnimation { currentStep += 1 }
    }

    private func goBack() {
        movingForward = false
        withAnimation { currentStep -= 1 }
    }

    // MARK: - Notifications

    private func requestNotifications() {
        guard !notificationsRequested else { return }
        notificationsRequested = true
        Task {
            let granted = await NotificationPermissionService.requestPermission()
            await MainActor.run {
                notificationsEnabled = granted
            }
        }
    }

    // MARK: - Climate Detection

    private func triggerClimateDetection() {
        if let coord = addressService.selectedCoordinate {
            let lat = coord.latitude
            let zone: ClimateZone
            if lat < 32 { zone = .hot }
            else if lat < 40 { zone = .moderate }
            else { zone = .cold }

            CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: coord.longitude)) { placemarks, _ in
                let city = placemarks?.first.flatMap {
                    [$0.locality, $0.administrativeArea].compactMap { $0 }.joined(separator: ", ")
                }
                Task { @MainActor in
                    if let city, !city.isEmpty { locationDetector.detectedCity = city }
                    climateZone = zone
                }
            }
            return
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedAddress.isEmpty {
            locationDetector.geocodeAddress(trimmedAddress) { zone in
                if let zone {
                    climateZone = zone
                } else {
                    locationDetector.detectClimateZoneViaGPS { gpsZone in
                        if let gpsZone { climateZone = gpsZone }
                    }
                }
            }
        } else {
            locationDetector.detectClimateZoneViaGPS { zone in
                if let zone { climateZone = zone }
            }
        }
    }

    // MARK: - Room Name Generation

    private func generateRoomNames(total: Int, bedrooms: Int) -> [String] {
        if total == 1 { return ["Main Room"] }

        var names: [String] = ["Living Room"]
        let remaining = total - 1 - bedrooms
        if remaining >= 1 && total >= 3 { names.append("Kitchen") }

        for i in 1...max(bedrooms, 1) {
            if names.count >= total { break }
            names.append(bedrooms == 1 ? "Bedroom" : "Bedroom \(i)")
        }

        let extras = ["Bathroom", "Dining Room", "Office", "Laundry Room", "Garage", "Hallway", "Basement", "Attic"]
        var extraIndex = 0
        while names.count < total && extraIndex < extras.count {
            names.append(extras[extraIndex])
            extraIndex += 1
        }
        var suffix = 1
        while names.count < total {
            names.append("Room \(suffix)")
            suffix += 1
        }

        return Array(names.prefix(total))
    }

    // MARK: - Create Home

    private func createHomeAndFinish() {
        let finalName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = Home(
            name: finalName.isEmpty ? "My Home" : finalName,
            address: trimmedAddress.isEmpty ? nil : trimmedAddress,
            yearBuilt: yearBuilt,
            totalSqFt: Double(sqFtText),
            climateZone: climateZone,
            homeType: homeType,
            bedroomCount: bedroomCount
        )
        modelContext.insert(home)

        let roomNames = generateRoomNames(total: roomCount, bedrooms: bedroomCount)
        for name in roomNames {
            let room = Room(name: name, squareFootage: 0, scanWasUsed: false)
            room.home = home
            modelContext.insert(room)
        }

        // Persist account info
        if !userName.isEmpty { storedUserName = userName }
        if !userEmail.isEmpty { storedUserEmail = userEmail }

        AnalyticsService.track(.onboardingCompleted, properties: [
            "hasAddress": (!trimmedAddress.isEmpty).description,
            "roomsPlanned": String(roomCount),
            "bedroomsPlanned": String(bedroomCount)
        ])

        didFinish = true
        hasSeenOnboarding = true
    }
}
