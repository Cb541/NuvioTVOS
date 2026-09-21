#if DEBUG
import Foundation

/// Applies preference overrides handed in on the command line, before any store hydrates.
///
/// `PreferenceStore` reads typed values out of `UserDefaults` — `storage[key] as? Bool` — and a
/// plain `-namespace.key 0` launch argument lands in the argument domain as a **string**, which
/// that cast rejects. So a UI test that means to launch with a setting off silently launches
/// with it on, and the test passes while proving nothing. This writes the real typed value
/// instead, which is the only way to put a store into a known state from outside the app.
///
/// Usage: `-nuvioSetting layout.poster_labels_enabled=false`, repeatable.
enum SettingsHarness {
    static let launchArgument = "-nuvioSetting"

    static func applyOverrides(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        for (index, argument) in arguments.enumerated()
        where argument == launchArgument && index + 1 < arguments.count {
            apply(arguments[index + 1])
        }
    }

    private static func apply(_ assignment: String) {
        let parts = assignment.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { return }
        let key = String(parts[0])
        let raw = String(parts[1])

        switch raw {
        case "true", "false":
            UserDefaults.standard.set(raw == "true", forKey: key)
        default:
            if let number = Int(raw) {
                UserDefaults.standard.set(number, forKey: key)
            } else {
                UserDefaults.standard.set(raw, forKey: key)
            }
        }
    }
}
#endif
