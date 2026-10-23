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
    
    private var assignmentsWindow: NSWindow?
    private var assignmentsData: [(bundleId: String, sourceId: String)] = []

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
        assignmentsData = assignments
            .sorted(by: { $0.key < $1.key })
            .map { (bundleId: $0.key, sourceId: $0.value) }

        if let existingWindow = assignmentsWindow {
            if let tableView = findTableView(in: existingWindow) {
                tableView.reloadData()
            }
            updateRowCountLabel(in: existingWindow, count: assignmentsData.count)
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = createAssignmentsWindow()
        assignmentsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createAssignmentsWindow() -> NSWindow {
        let windowWidth: CGFloat = 680
        let windowHeight: CGFloat = 440
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let originX = screenRect.midX - windowWidth / 2
        let originY = screenRect.midY - windowHeight / 2

        let window = NSPanel(
            contentRect: NSRect(x: originX, y: originY, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tüm Klavye Atamaları"
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))

        guard let contentView = window.contentView else { return window }

        // Başlık
        let headerLabel = NSTextField(labelWithString: "Uygulama Bazlı Klavye Atamaları")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 14)
        headerLabel.frame = NSRect(x: 20, y: windowHeight - 40, width: 400, height: 20)
        contentView.addSubview(headerLabel)

        // Satır sayısı
        let countLabel = NSTextField(labelWithString: "\(assignmentsData.count) atama")
        countLabel.font = NSFont.systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .right
        countLabel.frame = NSRect(x: windowWidth - 140, y: windowHeight - 40, width: 120, height: 20)
        countLabel.identifier = NSUserInterfaceItemIdentifier("rowCountLabel")
        contentView.addSubview(countLabel)

        // Tablo alanı
        let tableTop: CGFloat = windowHeight - 60
        let tableBottom: CGFloat = 60
        let tableHeight = tableTop - tableBottom

        let scrollView = NSScrollView(frame: NSRect(x: 20, y: tableBottom, width: windowWidth - 40, height: tableHeight))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .bezelBorder

        let tableView = NSTableView(frame: scrollView.contentView.bounds)
        tableView.identifier = NSUserInterfaceItemIdentifier("assignmentsTable")
        tableView.headerView = NSTableHeaderView(frame: NSRect(x: 0, y: 0, width: 1, height: 17))
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 24
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.delegate = self
        tableView.dataSource = self

        // Uygulama Adı kolonu
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "Uygulama"
        appColumn.width = 200
        appColumn.minWidth = 120
        tableView.addTableColumn(appColumn)

        // Bundle ID kolonu
        let bundleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bundle"))
        bundleColumn.title = "Bundle ID"
        bundleColumn.width = 260
        bundleColumn.minWidth = 150
        tableView.addTableColumn(bundleColumn)

        // Klavye kolonu
        let keyboardColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("keyboard"))
        keyboardColumn.title = "Atanan Klavye"
        keyboardColumn.width = 180
        keyboardColumn.minWidth = 100
        tableView.addTableColumn(keyboardColumn)

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // Alt butonlar
        let buttonY: CGFloat = 15
        let buttonHeight: CGFloat = 32

        // Sil butonu
        let deleteButton = NSButton(frame: NSRect(x: 20, y: buttonY, width: 120, height: buttonHeight))
        deleteButton.title = "Seçileni Sil"
        deleteButton.bezelStyle = .rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelectedAssignment)
        deleteButton.identifier = NSUserInterfaceItemIdentifier("deleteButton")
        deleteButton.isEnabled = false
        contentView.addSubview(deleteButton)

        // Tümünü Temizle butonu
        let clearAllButton = NSButton(frame: NSRect(x: 150, y: buttonY, width: 120, height: buttonHeight))
        clearAllButton.title = "Tümünü Temizle"
        clearAllButton.bezelStyle = .rounded
        clearAllButton.target = self
        clearAllButton.action = #selector(clearAllAssignments)
        contentView.addSubview(clearAllButton)

        // Kapat butonu
        let closeButton = NSButton(frame: NSRect(x: windowWidth - 100, y: buttonY, width: 80, height: buttonHeight))
        closeButton.title = "Kapat"
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.target = window
        closeButton.action = #selector(NSWindow.close)
        contentView.addSubview(closeButton)

        return window
    }

    private func findTableView(in window: NSWindow) -> NSTableView? {
        guard let contentView = window.contentView else { return nil }
        for subview in contentView.subviews {
            if let scrollView = subview as? NSScrollView,
               let tableView = scrollView.documentView as? NSTableView {
                return tableView
            }
        }
        return nil
    }

    private func updateRowCountLabel(in window: NSWindow, count: Int) {
        guard let contentView = window.contentView else { return }
        for subview in contentView.subviews {
            if let label = subview as? NSTextField,
               label.identifier?.rawValue == "rowCountLabel" {
                label.stringValue = "\(count) atama"
                break
            }
        }
    }

    @objc private func deleteSelectedAssignment() {
        guard let tableView = assignmentsWindow.flatMap({ findTableView(in: $0) }) else { return }
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < assignmentsData.count else { return }

        let item = assignmentsData[selectedRow]
        configStore.removeInputSource(for: item.bundleId)
        assignmentsData.remove(at: selectedRow)
        tableView.reloadData()

        if let window = assignmentsWindow {
            updateRowCountLabel(in: window, count: assignmentsData.count)
        }
        updateMenu()
    }

    @objc private func clearAllAssignments() {
        let alert = NSAlert()
        alert.messageText = "Tüm atamaları sil"
        alert.informativeText = "\(assignmentsData.count) atama kalıcı olarak silinecek. Devam etmek istiyor musunuz?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sil")
        alert.addButton(withTitle: "İptal")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        for item in assignmentsData {
            configStore.removeInputSource(for: item.bundleId)
        }
        assignmentsData.removeAll()

        if let tableView = assignmentsWindow.flatMap({ findTableView(in: $0) }) {
            tableView.reloadData()
        }
        if let window = assignmentsWindow {
            updateRowCountLabel(in: window, count: assignmentsData.count)
        }
        updateMenu()
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

// MARK: - NSTableViewDataSource

extension AppDelegate: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return assignmentsData.count
    }
}

// MARK: - NSTableViewDelegate

extension AppDelegate: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < assignmentsData.count else { return nil }
        let item = assignmentsData[row]
        let columnId = tableColumn?.identifier.rawValue ?? ""

        let cellIdentifier = "Cell_\(columnId)"
        var cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(cellIdentifier), owner: self) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = NSUserInterfaceItemIdentifier(cellIdentifier)

            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingTail
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView?.addSubview(textField)
            cellView?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        switch columnId {
        case "app":
            let appName = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleId).first?.localizedName
            cellView?.textField?.stringValue = appName ?? item.bundleId.components(separatedBy: ".").last ?? item.bundleId
            cellView?.textField?.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        case "bundle":
            cellView?.textField?.stringValue = item.bundleId
            cellView?.textField?.textColor = .secondaryLabelColor
            cellView?.textField?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        case "keyboard":
            let sourceName = inputSourceManager.getInputSourceName(for: item.sourceId) ?? item.sourceId
            cellView?.textField?.stringValue = sourceName
            cellView?.textField?.textColor = .controlAccentColor
            cellView?.textField?.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        default:
            break
        }

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView,
              let window = assignmentsWindow else { return }

        guard let contentView = window.contentView else { return }
        for subview in contentView.subviews {
            if let button = subview as? NSButton,
               button.identifier?.rawValue == "deleteButton" {
                button.isEnabled = tableView.selectedRow >= 0
                break
            }
        }
    }
}

