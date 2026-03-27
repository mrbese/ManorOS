import SwiftUI
import SwiftData

@MainActor
final class AppBootstrap: ObservableObject {
    let modelContainer: ModelContainer
    @Published var storeUnavailable: Bool

    init() {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        func buildVersionedContainer() throws -> ModelContainer {
            try ModelContainer(
                for: schema,
                migrationPlan: ManorOSMigrationPlan.self,
                configurations: [config]
            )
        }

        // Attempt 1: Versioned schema with migration plan
        do {
            self.modelContainer = try buildVersionedContainer()
            self.storeUnavailable = false
            return
        } catch {
            #if DEBUG
            print("[ManorOS] Versioned container failed: \(error)")
            print("[ManorOS] Attempting legacy store upgrade...")
            #endif
        }

        // Attempt 2: Existing store was created without VersionedSchema.
        // Load it unversioned to stamp version metadata, then retry.
        do {
            let legacyConfig = ModelConfiguration(cloudKitDatabase: .none)
            let legacyContainer = try ModelContainer(
                for: Home.self, Room.self, Equipment.self,
                     Appliance.self, EnergyBill.self, AuditProgress.self,
                configurations: legacyConfig
            )
            try legacyContainer.mainContext.save()
            #if DEBUG
            print("[ManorOS] Legacy store stamped, retrying versioned...")
            #endif

            self.modelContainer = try buildVersionedContainer()
            self.storeUnavailable = false
            return
        } catch {
            #if DEBUG
            print("[ManorOS] Legacy upgrade failed: \(error)")
            print("[ManorOS] Deleting store and starting fresh...")
            #endif
        }

        // Attempt 3: Delete corrupted store and recreate
        let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path() + suffix))
        }

        do {
            self.modelContainer = try buildVersionedContainer()
            self.storeUnavailable = false
        } catch {
            #if DEBUG
            print("[ManorOS] FATAL: Cannot create ModelContainer even after store reset: \(error)")
            #endif
            // Last-resort fallback: run in-memory so the app can still open and show a recovery UI.
            self.storeUnavailable = true
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                self.modelContainer = try ModelContainer(
                    for: schema,
                    migrationPlan: ManorOSMigrationPlan.self,
                    configurations: [inMemory]
                )
            } catch {
                fatalError("Cannot create any ModelContainer: \(error)")
            }
        }
    }
}

@main
struct ManorOSApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            Group {
                if bootstrap.storeUnavailable {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text("Storage Unavailable")
                            .font(.title2.bold())
                        Text("ManorOS couldn't open its local database. You can continue in a temporary session, but your changes won't be saved. Try reinstalling the app if this persists.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button("Continue (Temporary Session)") {
                            bootstrap.storeUnavailable = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    if hasSeenOnboarding {
                        MainTabView()
                    } else {
                        OnboardingView()
                    }
                }
            }
            .onAppear {
                AnalyticsService.track(.appOpen)
            }
        }
        .modelContainer(bootstrap.modelContainer)
    }
}
