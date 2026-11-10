import Foundation
import SwiftData

enum Persistence {
    static let cloudContainerID = "iCloud.com.abdersrdi.voiceinvoice"

    static var schema: Schema {
        Schema([
            StoreProfile.self,
            Employee.self,
            Customer.self,
            Invoice.self,
            InvoiceLine.self
        ])
    }

    /// Syncs through the owner's private iCloud database. If CloudKit is unavailable
    /// (no entitlement, unsigned build) the app falls back to a local store so it never fails to launch.
    static func makeContainer() -> ModelContainer {
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
