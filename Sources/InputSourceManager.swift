import Cocoa
import Carbon

final class InputSourceManager {
    func getAllInputSources() -> [TISInputSource] {
        let conditions = [
            kTISPropertyInputSourceCategory!: kTISCategoryKeyboardInputSource!
        ] as CFDictionary

        guard let sources = TISCreateInputSourceList(conditions, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        return sources
    }

    func getCurrentInputSourceId() -> String? {
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        return getInputSourceId(from: currentSource)
    }

    func getInputSourceId(from source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }

        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    func getInputSourceName(from source: TISInputSource) -> String {
        if let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
        }

        if let id = getInputSourceId(from: source) {
            return id.components(separatedBy: ".").last ?? id
        }

        return "Bilinmeyen"
    }

    func getInputSourceName(for sourceId: String) -> String? {
        let sources = getAllInputSources()

        for source in sources {
            if let id = getInputSourceId(from: source), id == sourceId {
                return getInputSourceName(from: source)
            }
        }

        return nil
    }

    func selectInputSource(withId sourceId: String) {
        let sources = getAllInputSources()

        for source in sources {
            if let id = getInputSourceId(from: source), id == sourceId {
                TISSelectInputSource(source)
                return
            }
        }

        print("Input source bulunamadı: \(sourceId)")
    }
}
