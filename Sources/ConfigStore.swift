import Foundation

final class ConfigStore {
    private let configDir: URL
    private let configFile: URL
    private var assignments: [String: String] = [:]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDir = appSupport.appendingPathComponent("KeyPilot")
        configFile = configDir.appendingPathComponent("config.json")

        load()
    }

    var configFilePath: String {
        return configFile.path
    }

    func load() {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: configFile)
            assignments = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("Config yüklenemedi: \(error)")
        }
    }

    func save() {
        do {
            // Dizini oluştur
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

            let data = try JSONEncoder().encode(assignments)
            try data.write(to: configFile, options: .atomic)
        } catch {
            print("Config kaydedilemedi: \(error)")
        }
    }

    func getInputSource(for bundleId: String) -> String? {
        return assignments[bundleId]
    }

    func setInputSource(for bundleId: String, sourceId: String) {
        assignments[bundleId] = sourceId
        save()
    }

    func removeInputSource(for bundleId: String) {
        assignments.removeValue(forKey: bundleId)
        save()
    }

    func getAllAssignments() -> [String: String] {
        return assignments
    }
}
