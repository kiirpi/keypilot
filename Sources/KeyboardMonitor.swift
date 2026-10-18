import Cocoa

final class KeyboardMonitor {
    var onAppActivated: ((NSRunningApplication) -> Void)?

    private var observer: NSObjectProtocol?

    func start() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        observer = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            self?.onAppActivated?(app)
        }
    }

    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
