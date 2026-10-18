import Cocoa
import Carbon

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Menu bar app olarak çalış - dock'ta görünme
NSApp.setActivationPolicy(.accessory)

app.run()
