import Cocoa
import Carbon
import UserNotifications
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private let monitor = KeyboardMonitor()
    private let inputSourceManager = InputSourceManager()
    private let configStore = ConfigStore()

    // MARK: - SwiftUI'ye sunulan durum

    struct InputSourceItem: Identifiable {
        let id: String
        let name: String
    }

    struct AssignmentItem: Identifiable {
        let bundleId: String
        let sourceId: String
        var id: String { bundleId }
    }

    @Published var currentAppName: String?
    @Published var currentBundleId: String?
    @Published var assignedSourceName: String?
    @Published var activeSourceName: String?
    @Published var inputSources: [InputSourceItem] = []
    @Published var assignments: [AssignmentItem] = []
    @Published var launchAtStartup: Bool = false

    // MARK: - Uygulama yaşam döngüsü

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMonitor()
        // Notification izni iste (macOS 10.14+)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        refreshState()
    }

    private func setupMonitor() {
        monitor.onAppActivated = { [weak self] app in
            self?.handleAppActivation(app)
        }
        monitor.start()
    }

    private func handleAppActivation(_ app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else { return }

        // Kendi uygulamamızı atla (menü bar'a tıklanınca aktif olabilir)
        if bundleId == Bundle.main.bundleIdentifier {
            return
        }

        if let inputSourceId = configStore.getInputSource(for: bundleId) {
            inputSourceManager.selectInputSource(withId: inputSourceId)
        }

        refreshState()
    }

    // MARK: - Durum yenileme

    func refreshState() {
        if let currentApp = NSWorkspace.shared.frontmostApplication,
           currentApp.bundleIdentifier != Bundle.main.bundleIdentifier,
           let appName = currentApp.localizedName,
           let bundleId = currentApp.bundleIdentifier {
            currentAppName = appName
            currentBundleId = bundleId
        }

        // Atanan kaynak
        if let bundleId = currentBundleId,
           let assignedId = configStore.getInputSource(for: bundleId) {
            assignedSourceName = inputSourceManager.getInputSourceName(for: assignedId) ?? assignedId
        } else {
            assignedSourceName = nil
        }

        // Aktif kaynak
        if let currentId = inputSourceManager.getCurrentInputSourceId() {
            activeSourceName = inputSourceManager.getInputSourceName(for: currentId) ?? currentId
        } else {
            activeSourceName = nil
        }

        // Klavye listesi
        inputSources = inputSourceManager.getAllInputSources().compactMap { source in
            guard let id = inputSourceManager.getInputSourceId(from: source) else { return nil }
            return InputSourceItem(id: id, name: inputSourceManager.getInputSourceName(from: source))
        }

        // Atamalar
        assignments = configStore.getAllAssignments()
            .sorted(by: { $0.key < $1.key })
            .map { AssignmentItem(bundleId: $0.key, sourceId: $0.value) }

        // Açılışta başlatma
        launchAtStartup = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Aksiyonlar

    var hasAssignmentForCurrentApp: Bool {
        guard let bundleId = currentBundleId else { return false }
        return configStore.getInputSource(for: bundleId) != nil
    }

    func assignInputSource(sourceId: String) {
        guard let bundleId = currentBundleId else { return }
        configStore.setInputSource(for: bundleId, sourceId: sourceId)
        refreshState()

        let appName = currentAppName ?? bundleId
        showNotification(title: "Klavye Atandı", message: "\(appName): \(sourceId)")
    }

    func removeCurrentAssignment() {
        guard let bundleId = currentBundleId else { return }
        configStore.removeInputSource(for: bundleId)
        refreshState()
        showNotification(title: "Atama Kaldırıldı", message: bundleId)
    }

    func openConfigFile() {
        let configPath = configStore.configFilePath
        if !FileManager.default.fileExists(atPath: configPath) {
            configStore.save()
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    func toggleLaunchAtStartup() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            launchAtStartup = SMAppService.mainApp.status == .enabled
        } catch {
            print("Açılışta başlat ayarı değiştirilemedi: \(error)")
        }
    }

    func deleteAssignment(bundleId: String) {
        configStore.removeInputSource(for: bundleId)
        refreshState()
    }

    func clearAllAssignments() {
        for item in assignments {
            configStore.removeInputSource(for: item.bundleId)
        }
        refreshState()
    }

    // MARK: - Yardımcılar

    func appName(for bundleId: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
           let name = app.localizedName {
            return name
        }
        return bundleId.components(separatedBy: ".").last ?? bundleId
    }

    func sourceName(for sourceId: String) -> String {
        return inputSourceManager.getInputSourceName(for: sourceId) ?? sourceId
    }

    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Bildirim gösterilemedi: \(error)")
            }
        }
    }
}
