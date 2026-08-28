import Highlightr
import MarkdownUI
import SwiftUI

/// Bridges [Highlightr](https://github.com/raspu/Highlightr) — highlight.js
/// running in JavaScriptCore, fully offline, no network — into
/// swift-markdown-ui's `CodeSyntaxHighlighter`.
///
/// If the `Highlightr` engine can't be created, or a code block's language
/// isn't recognised, the code is shown as plain (unstyled) text instead of
/// failing.
struct HighlightrSyntaxHighlighter: CodeSyntaxHighlighter {
    let highlightr: Highlightr?

    func highlightCode(_ content: String, language: String?) -> Text {
        guard let highlightr else { return Text(content) }

        // Markdown code blocks arrive with a trailing newline; dropping it
        // avoids an empty last line inside the rendered block.
        let code = content.hasSuffix("\n") ? String(content.dropLast()) : content

        let normalized = language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let highlighted: NSAttributedString?
        if let normalized, !normalized.isEmpty,
           highlightr.supportedLanguages().contains(normalized) {
            highlighted = highlightr.highlight(code, as: normalized)
        } else {
            highlighted = highlightr.highlight(code) // language auto-detection
        }

        guard let highlighted else { return Text(code) }
        return Text(AttributedString(highlighted))
    }
}
