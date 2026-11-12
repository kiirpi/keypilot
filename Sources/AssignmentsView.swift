import SwiftUI

struct AssignmentsView: View {
    @EnvironmentObject var app: AppDelegate
    @State private var showClearAllAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Uygulama Bazlı Klavye Atamaları")
                    .font(.headline)
                Spacer()
                Text("\(app.assignments.count) atama")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            if app.assignments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Atama yok")
                        .font(.title2)
                    Text("Menü bar'dan bir uygulamaya klavye atayın")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(app.assignments) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.appName(for: item.bundleId))
                                    .font(.system(size: 13, weight: .medium))
                                Text(item.bundleId)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(app.sourceName(for: item.sourceId))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            app.deleteAssignment(bundleId: app.assignments[index].bundleId)
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Button("Tümünü Temizle") {
                    showClearAllAlert = true
                }
                .disabled(app.assignments.isEmpty)

                Spacer()

                Button("Kapat") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 360)
        .alert("Tüm atamaları sil", isPresented: $showClearAllAlert) {
            Button("Sil", role: .destructive) {
                app.clearAllAssignments()
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("\(app.assignments.count) atama kalıcı olarak silinecek. Devam etmek istiyor musunuz?")
        }
    }
}
