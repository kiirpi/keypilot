import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var app: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Başlık
            if let appName = app.currentAppName {
                Text("Uygulama: \(appName)")
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Text("Uygulama seçilmedi")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Atanan / aktif bilgi
            VStack(alignment: .leading, spacing: 2) {
                if let assigned = app.assignedSourceName {
                    Text("Atanan: \(assigned)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Atama yok")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let active = app.activeSourceName {
                    Text("Aktif: \(active)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Klavye ata
            Menu("Klavye Ata") {
                if app.inputSources.isEmpty {
                    Text("Klavye düzeni bulunamadı")
                }
                ForEach(app.inputSources) { source in
                    Button(source.name) {
                        app.assignInputSource(sourceId: source.id)
                    }
                }
            }
            .disabled(app.currentBundleId == nil)

            // Atamayı kaldır
            if app.hasAssignmentForCurrentApp {
                Button("Atamayı Kaldır") {
                    app.removeCurrentAssignment()
                }
            }

            Divider()

            Button("Tüm Atamalar...") {
                openWindow(id: "assignments")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Config Dosyasını Aç") {
                app.openConfigFile()
            }

            Divider()

            Toggle("Açılışta Başlat", isOn: Binding(
                get: { app.launchAtStartup },
                set: { _ in app.toggleLaunchAtStartup() }
            ))

            Divider()

            Button("Çık") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
