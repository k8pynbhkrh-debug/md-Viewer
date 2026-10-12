#if DEBUG
import UIKit
import notify

/// Fernsteuerung für Simulator-Nachweise. Synthetische Taps sind im Simulator
/// unzuverlässig (und bei gesperrtem Mac-Bildschirm gar nicht möglich), daher
/// lauscht die DEBUG-Fassung auf Darwin-Notifications:
///
///     xcrun simctl spawn <udid> notifyutil -p mdviewer.debug.<befehl>
///
/// Befehle: `scroll0` … `scroll100` (in 5er-Schritten: sichtbare Ansicht auf
/// diesen Anteil scrollen), `edit`, `discard`, `select`, `read`, `formatted`
/// (Mac-Umschalter), `tabnext`, `type` (hängt im Editor eine Zeile an der
/// Schreibmarke an). Nur DEBUG — im Release-Build nicht enthalten.
@MainActor
enum DebugRemote {
    private static var tokens: [Int32] = []

    static func start(store: OpenDocumentsStore) {
        guard tokens.isEmpty else { return }
        var commands: [String: @MainActor () -> Void] = [
            "edit": { if let s = store.active, s.isLoaded, !s.isEditing { s.beginEditing() } },
            "discard": { if let s = store.active, s.isEditing, !s.isSaving { s.discardEditing() } },
            "select": { store.active?.isSelectingText = true },
            "read": { store.active?.isSelectingText = false },
            "formatted": { store.active?.showFormattedPreview.toggle() },
            "tabnext": { store.activateNeighbor(offset: 1) },
            "type": { focusedTextView()?.insertText("\nNeue Zeile vom Testlauf") },
            "fakekeyboard": { fakeKeyboard() },
        ]
        for percent in stride(from: 0, through: 100, by: 5) {
            commands["scroll\(percent)"] = { scroll(to: CGFloat(percent) / 100) }
        }
        for (name, action) in commands {
            var token: Int32 = 0
            notify_register_dispatch("mdviewer.debug.\(name)", &token, .main) { _ in
                MainActor.assumeIsolated { action() }
            }
            tokens.append(token)
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    /// Die größte vertikal scrollbare Ansicht im Fenster — der Dokumentinhalt.
    private static func documentScrollView() -> UIScrollView? {
        var best: UIScrollView?
        func visit(_ view: UIView) {
            if let scroll = view as? UIScrollView, !scroll.isHidden,
               scroll.contentSize.height > scroll.bounds.height,
               scroll.bounds.height * scroll.bounds.width
                > (best.map { $0.bounds.height * $0.bounds.width } ?? 0) {
                best = scroll
            }
            view.subviews.forEach(visit)
        }
        keyWindow.map(visit)
        return best
    }

    private static func focusedTextView() -> UITextView? {
        var found: UITextView?
        func visit(_ view: UIView) {
            if let text = view as? UITextView, text.isFirstResponder { found = text }
            view.subviews.forEach(visit)
        }
        keyWindow.map(visit)
        return found
    }

    /// Meldet eine Tastatur über den unteren 336 pt, *ohne* dass das System
    /// den Editor verkleinert, und malt dort eine graue Fläche — der Fall aus
    /// T-2026-337 (Tastatur verdeckt die Schreibzeile), der sich im Simulator
    /// sonst nicht herstellen lässt.
    private static func fakeKeyboard() {
        guard let window = keyWindow else { return }
        let height: CGFloat = 336
        let frame = CGRect(x: 0, y: window.bounds.height - height,
                           width: window.bounds.width, height: height)
        let cover = UIView(frame: frame)
        cover.backgroundColor = .systemGray3
        cover.isUserInteractionEnabled = false
        window.addSubview(cover)
        NotificationCenter.default.post(
            name: UIResponder.keyboardDidChangeFrameNotification, object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey:
                        NSValue(cgRect: window.convert(frame, to: window.screen.coordinateSpace))])
    }

    private static func scroll(to fraction: CGFloat) {
        guard let scroll = documentScrollView() else { return }
        let inset = scroll.adjustedContentInset
        let minY = -inset.top
        let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x,
                                        y: minY + (maxY - minY) * fraction), animated: false)
    }
}
#endif
