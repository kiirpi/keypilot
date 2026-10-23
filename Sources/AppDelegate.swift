import Cocoa
import Carbon
import UserNotifications
import ServiceManagement

/// Bir uygulama-klavye atamasını temsil eden basit sınıf (ObjC bridge uyumlu)
private final class AssignmentInfo {
    let bundleId: String
    let sourceId: String
    init(bundleId: String, sourceId: String) {
        self.bundleId = bundleId
        self.sourceId = sourceId
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = KeyboardMonitor()
    private let inputSourceManager = InputSourceManager()
    private let configStore = ConfigStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupMonitor()

        // Notification izni iste (macOS 10.14+)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        updateMenu()
    }

    private func setupMonitor() {
        monitor.onAppActivated = { [weak self] app in
            self?.handleAppActivation(app)
        }
        monitor.start()
    }

    private func handleAppActivation(_ app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else { return }

        if let inputSourceId = configStore.getInputSource(for: bundleId) {
            inputSourceManager.selectInputSource(withId: inputSourceId)
        }

        updateMenu()
    }

    private func updateMenu() {
        let menu = NSMenu()

        // Mevcut uygulama bilgisi
        if let currentApp = NSWorkspace.shared.frontmostApplication,
           let appName = currentApp.localizedName,
           let bundleId = currentApp.bundleIdentifier {

            let currentInputSource = inputSourceManager.getCurrentInputSourceId()
            let assignedInputSource = configStore.getInputSource(for: bundleId)

            let headerItem = NSMenuItem(title: "Uygulama: \(appName)", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            if let assigned = assignedInputSource,
               let sourceName = inputSourceManager.getInputSourceName(for: assigned) {
                let assignedItem = NSMenuItem(title: "Atanan: \(sourceName)", action: nil, keyEquivalent: "")
                assignedItem.isEnabled = false
                menu.addItem(assignedItem)
            } else {
                let noAssignmentItem = NSMenuItem(title: "Atama yok", action: nil, keyEquivalent: "")
                noAssignmentItem.isEnabled = false
                menu.addItem(noAssignmentItem)
            }

            if let current = currentInputSource,
               let sourceName = inputSourceManager.getInputSourceName(for: current) {
                let currentItem = NSMenuItem(title: "Aktif: \(sourceName)", action: nil, keyEquivalent: "")
                currentItem.isEnabled = false
                menu.addItem(currentItem)
            }

            menu.addItem(.separator())

            // Klavye atama menüsü
            let assignMenu = NSMenu()
            let inputSources = inputSourceManager.getAllInputSources()

            for source in inputSources {
                guard let sourceId = inputSourceManager.getInputSourceId(from: source) else { continue }
                let sourceName = inputSourceManager.getInputSourceName(from: source)

                let item = NSMenuItem(title: sourceName, action: #selector(assignInputSource(_:)), keyEquivalent: "")
                item.representedObject = AssignmentInfo(bundleId: bundleId, sourceId: sourceId)
                item.target = self
                assignMenu.addItem(item)
            }

            let assignItem = NSMenuItem(title: "Klavye Ata", action: nil, keyEquivalent: "")
            assignItem.submenu = assignMenu
            menu.addItem(assignItem)

            // Atamayı kaldır
            if configStore.getInputSource(for: bundleId) != nil {
                let removeItem = NSMenuItem(title: "Atamayı Kaldır", action: #selector(removeAssignment(_:)), keyEquivalent: "")
                removeItem.representedObject = bundleId
                removeItem.target = self
                menu.addItem(removeItem)
            }
        }

        menu.addItem(.separator())

        // Tüm atamaları göster
        let allAssignmentsItem = NSMenuItem(title: "Tüm Atamalar...", action: #selector(showAllAssignments), keyEquivalent: "a")
        allAssignmentsItem.target = self
        menu.addItem(allAssignmentsItem)

        // Config dosyasını aç
        let openConfigItem = NSMenuItem(title: "Config Dosyasını Aç", action: #selector(openConfigFile), keyEquivalent: "o")
        openConfigItem.target = self
        menu.addItem(openConfigItem)

        menu.addItem(.separator())

        // Açılışta başlat toggle
        let launchItem = NSMenuItem(title: "Açılışta Başlat", action: #selector(toggleLaunchAtStartup), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchItem)

        // Çıkış
        let quitItem = NSMenuItem(title: "Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func assignInputSource(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? AssignmentInfo else { return }

        configStore.setInputSource(for: info.bundleId, sourceId: info.sourceId)
        updateMenu()

        // Bildirim göster
        let appName = NSRunningApplication.current.localizedName ?? "Uygulama"
        showNotification(title: "Klavye Atandı", message: "\(appName): \(info.sourceId)")
    }

    @objc private func removeAssignment(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }

        configStore.removeInputSource(for: bundleId)
        updateMenu()

        showNotification(title: "Atama Kaldırıldı", message: bundleId)
    }

    @objc private func showAllAssignments() {
        let assignments = configStore.getAllAssignments()

        let alert = NSAlert()
        alert.messageText = "Tüm Klavye Atamaları"

        var message = ""
        if assignments.isEmpty {
            message = "Henüz atama yapılmamış."
        } else {
            for (bundleId, sourceId) in assignments.sorted(by: { $0.key < $1.key }) {
                let appName = bundleId.components(separatedBy: ".").last ?? bundleId
                message += "\(appName): \(sourceId)\n"
            }
        }
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Tamam")

        alert.runModal()
    }

    @objc private func openConfigFile() {
        let configPath = configStore.configFilePath

        if !FileManager.default.fileExists(atPath: configPath) {
            // Config dosyası yoksa oluştur
            configStore.save()
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    @objc private func toggleLaunchAtStartup() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            updateMenu()
        } catch {
            print("Açılışta başlat ayarı değiştirilemedi: \(error)")
        }
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
