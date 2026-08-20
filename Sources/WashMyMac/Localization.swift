import Foundation

/// A thin wrapper over Localizable.strings.
///
/// The system picks the language: Russian when the macOS interface is Russian,
/// English otherwise (English is also the development region).
enum L {
    /// The language the system resolved for this app.
    /// Honours the per-app language override in System Settings too.
    static var language: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    static var isRussian: Bool { language.hasPrefix("ru") }

    static func t(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
    }

    /// "5 minutes" / «5 минут», with Russian plural forms.
    static func minutes(_ value: Int) -> String {
        guard isRussian else {
            return f(value == 1 ? "units.minute.one" : "units.minute.other", value)
        }
        switch (value % 100, value % 10) {
        case (11...14, _): return f("units.minute.other", value)
        case (_, 1): return f("units.minute.one", value)
        case (_, 2...4): return f("units.minute.few", value)
        default: return f("units.minute.other", value)
        }
    }

    /// Comma as the decimal separator in Russian, dot in English.
    static func decimal(_ value: TimeInterval) -> String {
        let text = String(format: "%.1f", value)
        return isRussian ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
