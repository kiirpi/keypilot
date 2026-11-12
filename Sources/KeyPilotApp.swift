import SwiftUI

@main
struct KeyPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("KeyPilot", systemImage: "keyboard") {
            MenuBarView()
                .environmentObject(appDelegate)
        }
        .menuBarExtraStyle(.window)

        Window("Tüm Klavye Atamaları", id: "assignments") {
            AssignmentsView()
                .environmentObject(appDelegate)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 680, height: 440)
    }
}
