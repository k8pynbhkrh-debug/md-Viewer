import Foundation

/// Snapshot-based undo history for the Markdown editor.
///
/// `TextEditor` here does not receive SwiftUI's `@Environment(\.undoManager)`
/// reliably, so the editor keeps its own stack of `editedText` values captured
/// *before* each typing burst.
///
/// ## Contract
///
/// - `record(before:at:)` is called for every change of the edited text, with
///   the value *before* that change. Consecutive calls closer together than
///   `coalesceInterval` collapse into a single undo step (so one tap of
///   "Rückgängig" removes a burst of typing, not one character). The single
///   change that `undo()` itself causes is skipped.
/// - `undo()` returns the text to restore (the most recent checkpoint) and
///   removes it, or `nil` when `canUndo` is `false`. The caller assigns the
///   result to the edited text; the resulting `record(before:)` is the one that
///   gets skipped.
/// - Invariant: `stack.count <= maxSteps` and `canUndo == !stack.isEmpty`.
struct EditorUndoHistory {
    private(set) var stack: [String] = []
    private var lastPush: Date = .distantPast
    private var skipNextRecord = false

    /// Upper bound on retained checkpoints. Notes are tiny; this only guards
    /// against pathological input.
    var maxSteps = 50
    /// Keystrokes recorded within this window of each other become one step.
    var coalesceInterval: TimeInterval = 0.6

    var canUndo: Bool { !stack.isEmpty }

    /// Records `text` as the state before the current change.
    ///
    /// - Parameter now: injectable clock; defaults to the current time.
    mutating func record(before text: String, at now: Date = Date()) {
        if skipNextRecord {
            skipNextRecord = false
            lastPush = now
            return
        }
        defer { lastPush = now }
        guard now.timeIntervalSince(lastPush) > coalesceInterval else { return }
        stack.append(text)
        if stack.count > maxSteps {
            stack.removeFirst(stack.count - maxSteps)
        }
    }

    /// - Returns: the checkpoint to restore, or `nil` if there is nothing to
    ///   undo. On a non-`nil` return the very next `record(before:)` is ignored.
    mutating func undo() -> String? {
        guard let previous = stack.popLast() else { return nil }
        skipNextRecord = true
        lastPush = .distantPast
        return previous
    }

    /// Clears the history (on entering the editor, discarding, or saving).
    mutating func reset() {
        stack.removeAll()
        lastPush = .distantPast
        skipNextRecord = false
    }
}
