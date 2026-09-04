#if targetEnvironment(macCatalyst)
import CoreServices
import Foundation

// Nur unter Mac Catalyst: macOS lässt eine App die Standard-Zuordnung eines
// Dateityps per LaunchServices setzen. Der moderne Ersatz
// `NSWorkspace.setDefaultApplication(at:toOpen:)` fehlt unter Catalyst, daher
// die (unter macOS „deprecated", aber weiterhin funktionsfähige) C-API
// `LSSetDefaultRoleHandlerForContentType`.

/// Der Markdown-UTI, für den md Viewer sich als Standard-App eintragen kann.
/// Identisch mit dem Eintrag in `md Viewer/Info.plist`.
private let markdownContentType = "net.daringfireball.markdown"

/// Fehler beim Setzen / Prüfen der Standard-App-Zuordnung für `.md`.
enum DefaultMarkdownAppError: LocalizedError {
    /// `Bundle.main.bundleIdentifier` ist `nil` — dann lässt sich kein Handler
    /// benennen (Vorbedingungsverletzung).
    case missingBundleIdentifier
    /// LaunchServices hat den Aufruf mit einem OSStatus ≠ 0 abgelehnt.
    case launchServicesFailure(OSStatus)
    /// Der Aufruf meldete Erfolg, die Zuordnung greift danach aber nicht.
    case notAppliedAfterCall

    var errorDescription: String? {
        switch self {
        case .missingBundleIdentifier:
            "Die App-Kennung konnte nicht ermittelt werden."
        case .launchServicesFailure(let status):
            "macOS hat die Änderung abgelehnt (Fehler \(status))."
        case .notAppliedAfterCall:
            "Die Zuordnung wurde nicht übernommen."
        }
    }
}

/// Registrierung von md Viewer als Standard-App für Markdown-Dateien (Catalyst).
enum DefaultMarkdownAppRegistration {

    /// `true`, wenn md Viewer aktuell der Standard-Handler für den Markdown-UTI
    /// ist. Bei fehlender Bundle-Kennung oder ohne eingetragenen Handler `false`.
    static var isDefault: Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        guard let handler = LSCopyDefaultRoleHandlerForContentType(
            markdownContentType as CFString, .all
        )?.takeRetainedValue() else {
            return false
        }
        return (handler as String).caseInsensitiveCompare(bundleID) == .orderedSame
    }

    /// Trägt md Viewer als Standard-App für den Markdown-UTI ein.
    ///
    /// ## Vertrag
    ///
    /// - **Vorbedingung:** `Bundle.main.bundleIdentifier != nil`. Bei Verletzung
    ///   `DefaultMarkdownAppError.missingBundleIdentifier`, ohne Systemänderung.
    /// - **Nachbedingung (Erfolg):** `isDefault == true` — der Standard-Handler
    ///   für `net.daringfireball.markdown` (Rolle `.all`) ist die eigene
    ///   Bundle-Kennung.
    /// - **Nachbedingung (Fehler):** wirft `.launchServicesFailure(status)` bei
    ///   OSStatus ≠ 0 bzw. `.notAppliedAfterCall`, wenn der Aufruf Erfolg meldet,
    ///   `isDefault` danach aber `false` bleibt. In beiden Fällen bleibt der
    ///   bisherige System-Handler unverändert.
    /// - **Invariante:** verändert ausschließlich die Zuordnung für den
    ///   Markdown-UTI (Rolle `.all`); andere Dateitypen bleiben unberührt.
    ///
    /// Beim ersten Aufruf kann macOS einen Bestätigungsdialog zeigen — erwartet.
    static func makeDefault() throws {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            throw DefaultMarkdownAppError.missingBundleIdentifier
        }

        let status = LSSetDefaultRoleHandlerForContentType(
            markdownContentType as CFString, .all, bundleID as CFString
        )
        guard status == noErr else {
            throw DefaultMarkdownAppError.launchServicesFailure(status)
        }
        guard isDefault else {
            throw DefaultMarkdownAppError.notAppliedAfterCall
        }
    }
}
#endif
