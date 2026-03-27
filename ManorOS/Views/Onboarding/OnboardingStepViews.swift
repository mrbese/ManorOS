import SwiftUI
import MapKit
import AuthenticationServices

// MARK: - Step 0: Welcome / Home Type

struct WelcomeHomeTypeStep: View {
    @Binding var homeType: HomeType

    private var icon: (HomeType) -> String {
        { type in
            switch type {
            case .house: return "house.fill"
            case .townhouse: return "building.2.fill"
            case .apartment: return "building.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Welcome to Manor OS!")
                    .font(.title.bold())
                    .foregroundStyle(Color.manor.textPrimary)
                Text("Let's begin here")
                    .font(.title3)
                    .foregroundStyle(Color.manor.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(HomeType.allCases) { type in
                    OnboardingIconCard(
                        icon: icon(type),
                        title: type.rawValue,
                        isSelected: homeType == type,
                        action: { homeType = type }
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Step 1: Address Entry

struct AddressEntryStep: View {
    @Binding var address: String
    @ObservedObject var addressService: AddressSearchService
    @FocusState.Binding var addressFieldFocused: Bool
    var onSkip: () -> Void

    @State private var showWhySheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 32)

                Text("Setting up home")
                    .font(.title.bold())
                    .foregroundStyle(Color.manor.textPrimary)

                VStack(alignment: .leading, spacing: 12) {
                    // Address field with location button
                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.manor.textTertiary)
                            .padding(.leading, 14)
                        TextField("Enter your address", text: $address)
                            .textFieldStyle(.plain)
                            .textContentType(.fullStreetAddress)
                            .focused($addressFieldFocused)
                            .padding(12)
                            .foregroundStyle(Color.manor.textPrimary)
                            .onChange(of: address) { _, newValue in
                                addressService.updateQuery(newValue)
                                if newValue != addressService.selectedAddress {
                                    addressService.selectedCoordinate = nil
                                }
                            }
                    }
                    .background(Color.manor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 12))

                    // Find my address button
                    Button {
                        Task {
                            await addressService.useCurrentLocation()
                            if let resolved = addressService.selectedAddress {
                                address = resolved
                            }
                            addressFieldFocused = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if addressService.isResolving {
                                ProgressView().tint(Color.manor.primary)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("Find my address")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(Color.manor.primary)
                    }
                    .disabled(addressService.isResolving)
                    .padding(.leading, 4)

                    // Suggestions
                    if !addressService.suggestions.isEmpty && addressFieldFocused {
                        VStack(spacing: 0) {
                            ForEach(addressService.suggestions.prefix(4), id: \.self) { suggestion in
                                Button {
                                    Task {
                                        await addressService.selectSuggestion(suggestion)
                                        if let resolved = addressService.selectedAddress {
                                            address = resolved
                                        }
                                        addressFieldFocused = false
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.manor.textPrimary)
                                            .lineLimit(1)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(Color.manor.textTertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }
                                if suggestion != addressService.suggestions.prefix(4).last {
                                    Divider().background(Color.manor.outlineVariant)
                                }
                            }
                        }
                        .background(Color.manor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Map preview
                    if let coordinate = addressService.selectedCoordinate {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        ))) {
                            Marker("", coordinate: coordinate)
                                .tint(Color.manor.primary)
                        }
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)
                    }

                    // Why + Skip row
                    HStack {
                        Button {
                            showWhySheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle")
                                Text("Why?")
                            }
                            .font(.caption)
                            .foregroundStyle(Color.manor.textTertiary)
                        }
                        Spacer()
                        Button(action: onSkip) {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.manor.textTertiary)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 80)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showWhySheet) {
            VStack(spacing: 16) {
                Image(systemName: "location.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.manor.primary)
                Text("Why we ask for your address")
                    .font(.headline)
                    .foregroundStyle(Color.manor.textPrimary)
                Text("Your address helps us automatically detect your climate zone, which affects heating and cooling calculations for your energy audit.")
                    .font(.subheadline)
                    .foregroundStyle(Color.manor.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Got it") { showWhySheet = false }
                    .font(.headline)
                    .foregroundStyle(Color.manor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(32)
            .presentationDetents([.height(300)])
            .presentationBackground(Color.manor.surfaceContainerHighest)
        }
    }
}

// MARK: - Step 2: Home Details

struct HomeDetailsStep: View {
    @Binding var homeName: String
    @Binding var yearBuilt: YearRange
    @Binding var sqFtText: String
    @Binding var climateZone: ClimateZone
    @ObservedObject var locationDetector: ClimateZoneDetector

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 32)

                Text("Home Details")
                    .font(.title.bold())
                    .foregroundStyle(Color.manor.textPrimary)

                VStack(spacing: 20) {
                    // Home name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Home Name")
                            .font(.caption.bold())
                            .foregroundStyle(Color.manor.textSecondary)
                        TextField("My Home", text: $homeName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.manor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color.manor.textPrimary)
                    }

                    // Year built
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Year Built")
                            .font(.caption.bold())
                            .foregroundStyle(Color.manor.textSecondary)
                        HStack(spacing: 6) {
                            ForEach(YearRange.allCases) { yr in
                                Button {
                                    yearBuilt = yr
                                } label: {
                                    Text(yr == .pre1970 ? "<1970" : yr == .y2016plus ? "2016+" : String(yr.rawValue.prefix(4)))
                                        .font(.caption2.bold())
                                        .foregroundStyle(yearBuilt == yr ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            yearBuilt == yr ? Color.manor.primary : Color.manor.surfaceContainerHigh,
                                            in: RoundedRectangle(cornerRadius: 8)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Square footage
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total Sq Ft (optional)")
                            .font(.caption.bold())
                            .foregroundStyle(Color.manor.textSecondary)
                        TextField("e.g. 1800", text: $sqFtText)
                            .textFieldStyle(.plain)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color.manor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color.manor.textPrimary)
                    }

                    // Climate zone
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Climate Zone")
                            .font(.caption.bold())
                            .foregroundStyle(Color.manor.textSecondary)

                        if let city = locationDetector.detectedCity {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.manor.primary)
                                Text("Detected: \(city)")
                                    .foregroundStyle(Color.manor.textSecondary)
                            }
                            .font(.subheadline)
                        }

                        VStack(spacing: 8) {
                            ForEach(ClimateZone.allCases) { zone in
                                OnboardingCard(isSelected: climateZone == zone, action: { climateZone = zone }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(zone.rawValue)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(Color.manor.textPrimary)
                                            Text(zone.description)
                                                .font(.caption)
                                                .foregroundStyle(Color.manor.textTertiary)
                                        }
                                        Spacer()
                                        if climateZone == zone {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.manor.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 80)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Step 3: Rooms

struct RoomsStep: View {
    @Binding var roomCount: Int
    @Binding var bedroomCount: Int
    let generateRoomNames: (Int, Int) -> [String]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("How many rooms?")
                .font(.title.bold())
                .foregroundStyle(Color.manor.textPrimary)

            Text("We'll create placeholders you can scan later.")
                .font(.subheadline)
                .foregroundStyle(Color.manor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 16) {
                stepperRow(label: "Total Rooms", value: $roomCount, range: 1...20)
                stepperRow(label: "Bedrooms", value: $bedroomCount, range: 0...roomCount)
            }
            .padding(.horizontal, 24)
            .onChange(of: roomCount) {
                if bedroomCount > roomCount { bedroomCount = roomCount }
            }

            // Room name pills
            let names = generateRoomNames(roomCount, bedroomCount)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(Color.manor.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.manor.primary.opacity(0.3), in: Capsule())
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.manor.textPrimary)
            Spacer()
            HStack(spacing: 16) {
                Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value.wrappedValue > range.lowerBound ? Color.manor.primary : .gray)
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(Color.manor.textPrimary)
                    .frame(width: 36)

                Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value.wrappedValue < range.upperBound ? Color.manor.primary : .gray)
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
        .padding(14)
        .background(Color.manor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Step 4: Create Account

struct CreateAccountStep: View {
    @Binding var userName: String
    @Binding var userEmail: String
    @StateObject private var signInCoordinator = AppleSignInCoordinator()
    @State private var showEmailFields = false
    @State private var signedInWithApple = false
    var onSkip: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 32)

                Text("Create your account")
                    .font(.title.bold())
                    .foregroundStyle(Color.manor.textPrimary)

                Text("Save your audit and sync across devices.")
                    .font(.subheadline)
                    .foregroundStyle(Color.manor.textSecondary)

                VStack(spacing: 14) {
                    // Apple Sign In
                    if signedInWithApple {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.manor.primary)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Signed in with Apple")
                                    .font(.headline)
                                    .foregroundStyle(Color.manor.textPrimary)
                                if !userName.isEmpty {
                                    Text(userName)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.manor.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.manor.primary.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.manor.primary, lineWidth: 2)
                        )
                    } else {
                        OnboardingIconCard(
                            icon: "apple.logo",
                            title: "Sign in with Apple",
                            subtitle: "Quick and private",
                            isSelected: false
                        ) {
                            signInCoordinator.onSuccess = { name, email in
                                if let name, !name.isEmpty { userName = name }
                                if let email, !email.isEmpty { userEmail = email }
                                signedInWithApple = true
                                showEmailFields = false
                            }
                            signInCoordinator.startSignIn()
                        }
                    }

                    // Email option
                    if !signedInWithApple {
                        OnboardingIconCard(
                            icon: "envelope.fill",
                            title: "Continue with Email",
                            isSelected: showEmailFields
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showEmailFields.toggle()
                            }
                        }

                        if showEmailFields {
                            VStack(spacing: 12) {
                                TextField("Name", text: $userName)
                                    .textFieldStyle(.plain)
                                    .textContentType(.name)
                                    .padding(12)
                                    .background(Color.manor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(Color.manor.textPrimary)

                                TextField("Email", text: $userEmail)
                                    .textFieldStyle(.plain)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(12)
                                    .background(Color.manor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(Color.manor.textPrimary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.horizontal, 24)

                if !signedInWithApple {
                    Button(action: onSkip) {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(Color.manor.textTertiary)
                    }
                }

                Spacer(minLength: 80)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Step 5: Notifications

struct NotificationsStep: View {
    var onRequestPermission: () -> Void
    @State private var didRequest = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Stay on top of your\nhome's energy")
                .font(.title.bold())
                .foregroundStyle(Color.manor.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                notificationPreview(
                    icon: "bolt.fill",
                    color: Color.manor.warning,
                    title: "Energy Spike Alert",
                    subtitle: "Your HVAC used 40% more energy today"
                )
                notificationPreview(
                    icon: "calendar.badge.clock",
                    color: Color.manor.primary,
                    title: "Monthly Audit Reminder",
                    subtitle: "Time to review your energy profile"
                )
                notificationPreview(
                    icon: "lightbulb.fill",
                    color: Color.manor.accent,
                    title: "Savings Tip",
                    subtitle: "Switch to LED — save $120/year"
                )
            }
            .padding(.horizontal, 24)

            Text("We'll only send useful updates, never spam.")
                .font(.caption)
                .foregroundStyle(Color.manor.textTertiary)

            Button {
                guard !didRequest else { return }
                didRequest = true
                onRequestPermission()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                    Text("Enable Notifications")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.manor.onPrimary)
                .background(Color.manor.primary, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .accessibilityLabel("Enable notifications")

            Spacer()
            Spacer()
        }
    }

    private func notificationPreview(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.manor.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.manor.textTertiary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.manor.surfaceContainer, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.manor.outlineVariant, lineWidth: 1)
        )
    }
}
