import Foundation

/// User settings, stored in UserDefaults.
final class Settings {
    static let shared = Settings()

    private enum Key {
        static let autoUnlockMinutes = "autoUnlockMinutes"
        static let hintSeconds = "hintSeconds"
        static let holdSeconds = "holdSeconds"
    }

    /// Allowed auto-exit values. There is deliberately no "never" option:
    /// it is the one guarantee that cleaning mode can always be left.
    static let autoUnlockChoices = [1, 3, 5, 10, 30]

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.autoUnlockMinutes: 5,
            Key.hintSeconds: 6.0,
            Key.holdSeconds: 1.5,
        ])
    }

    var autoUnlockMinutes: Int {
        get {
            let value = defaults.integer(forKey: Key.autoUnlockMinutes)
            return Self.autoUnlockChoices.contains(value) ? value : 5
        }
        set { defaults.set(newValue, forKey: Key.autoUnlockMinutes) }
    }

    /// How long the hint stays on screen before it goes fully black.
    var hintSeconds: TimeInterval {
        get { defaults.double(forKey: Key.hintSeconds) }
        set { defaults.set(newValue, forKey: Key.hintSeconds) }
    }

    /// How long the unlock combination has to be held.
    var holdSeconds: TimeInterval {
        get { max(0.5, defaults.double(forKey: Key.holdSeconds)) }
        set { defaults.set(newValue, forKey: Key.holdSeconds) }
    }
}
