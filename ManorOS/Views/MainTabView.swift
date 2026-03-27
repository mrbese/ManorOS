import SwiftUI
import SwiftData

enum AppTab: Int, Hashable {
    case home, report, settings
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Home.updatedAt, order: .reverse) private var homes: [Home]
    @State private var selectedTab: AppTab = .home
    @AppStorage("selectedHomeID") private var selectedHomeIDString: String = ""
    @State private var showingAddHome = false

    private var selectedHomeID: UUID? {
        get { UUID(uuidString: selectedHomeIDString) }
        nonmutating set { selectedHomeIDString = newValue?.uuidString ?? "" }
    }

    private var activeHome: Home? {
        if let id = selectedHomeID, let match = homes.first(where: { $0.id == id }) {
            return match
        }
        return homes.first
    }

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        if homes.isEmpty {
            emptyState
        } else if let home = activeHome {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeDashboardView(home: home)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                HStack(spacing: 12) {
                                    if homes.count > 1 {
                                        homePickerMenu
                                    }
                                    Button(action: { showingAddHome = true }) {
                                        Image(systemName: "plus")
                                            .fontWeight(.semibold)
                                    }
                                    .accessibilityLabel("Add new home")
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

                NavigationStack {
                    ReportTabView(home: home)
                }
                .tabItem {
                    Label("Report", systemImage: "doc.text.fill")
                }
                .tag(AppTab.report)

                NavigationStack {
                    SettingsView(home: home)
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
            }
            .tint(Color.manor.primary)
            .sheet(isPresented: $showingAddHome) {
                AddHomeSheet { home in
                    modelContext.insert(home)
                    selectedHomeID = home.id
                }
            }
            .onChange(of: homes.count) { oldCount, newCount in
                // If all homes deleted, selectedHomeID becomes stale — reset
                if newCount == 0 {
                    selectedHomeID = nil
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.manor.primary)

                    VStack(spacing: 8) {
                        Text("Manor OS")
                            .font(.largeTitle.bold())

                        Text("Your home energy audit,\nright in your pocket")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Button(action: { showingAddHome = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Your Home").fontWeight(.semibold)
                            Text("Start your energy assessment").font(.caption).opacity(0.8)
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
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Manor OS")
            .sheet(isPresented: $showingAddHome) {
                AddHomeSheet { home in
                    modelContext.insert(home)
                    selectedHomeID = home.id
                }
            }
        }
    }

    // MARK: - Home Picker

    private var homePickerMenu: some View {
        Menu {
            ForEach(homes) { home in
                Button {
                    selectedHomeID = home.id
                } label: {
                    HStack {
                        Text(home.name.isEmpty ? "Unnamed Home" : home.name)
                        if home.id == activeHome?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.up.chevron.down")
                .fontWeight(.semibold)
                .font(.caption)
        }
        .accessibilityLabel("Switch home")
    }
}
