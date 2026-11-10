import Foundation
import SwiftData

enum Persistence {
    static let cloudContainerID = "iCloud.cc.voiceinvoice.app"

    static var schema: Schema {
        Schema([
            StoreProfile.self,
            Employee.self,
            Invoice.self,
            InvoiceLine.self
        ])
    }

    /// Syncs through the owner's private iCloud database. If CloudKit is unavailable
    /// (no entitlement, unsigned build) the app falls back to a local store so it never fails to launch.
    static func makeContainer() -> ModelContainer {
        // Unit tests launch the app as a host; give them a throwaway store.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
           let container = try? makeInMemoryContainer() {
            return container
        }
        // SwiftData does not always create this folder on a fresh install or simulator.
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        }
        do {
            let cloud = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(cloudContainerID)
            )
            return try ModelContainer(for: schema, configurations: [cloud])
        } catch {
            do {
                let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [local])
            } catch {
                fatalError("Could not create the data store: \(error)")
            }
        }
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
