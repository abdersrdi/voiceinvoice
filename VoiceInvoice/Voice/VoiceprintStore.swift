import Foundation

/// Where voiceprints live. With sync on, the voiceprint is stored in the synced Employee record
/// (shop iCloud). With sync off, it stays in a file on this device only.
enum VoiceprintStore {
    private static var folder: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base.appendingPathComponent("Voiceprints", isDirectory: true)
    }

    private static func localURL(for employee: Employee) -> URL? {
        folder?.appendingPathComponent("\(employee.uid).bin")
    }

    static func save(_ voiceprint: Voiceprint, for employee: Employee) {
        let data = voiceprint.data
        if employee.voiceSyncEnabled {
            employee.voiceprint = data
            removeLocal(for: employee)
        } else {
            employee.voiceprint = nil
            if let folder, let url = localURL(for: employee) {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    static func load(for employee: Employee) -> Voiceprint? {
        if let data = employee.voiceprint, let print = Voiceprint(data: data) {
            return print
        }
        if let url = localURL(for: employee), let data = try? Data(contentsOf: url) {
            return Voiceprint(data: data)
        }
        return nil
    }

    static func hasVoiceprint(_ employee: Employee) -> Bool {
        load(for: employee) != nil
    }

    /// Removes the voiceprint everywhere (synced record and this device).
    static func delete(for employee: Employee) {
        employee.voiceprint = nil
        removeLocal(for: employee)
    }

    /// Moves an existing voiceprint when the sync setting changes.
    static func setSync(_ enabled: Bool, for employee: Employee) {
        let existing = load(for: employee)
        employee.voiceSyncEnabled = enabled
        if let existing { save(existing, for: employee) }
    }

    private static func removeLocal(for employee: Employee) {
        if let url = localURL(for: employee) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func profiles(for employees: [Employee]) -> [VoiceProfile] {
        employees.compactMap { employee in
            load(for: employee).map {
                VoiceProfile(id: employee.uid, centroid: $0.centroid, radius: $0.radius)
            }
        }
    }
}
