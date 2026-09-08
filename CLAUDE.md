# Arbeiten in diesem Repo

- Nach jedem `git commit` automatisch `git push origin main` ausführen, ohne vorher nachzufragen. Gilt nur für normale Commits auf `main` — destruktive/history-verändernde Operationen (force-push, reset, etc.) bleiben zustimmungspflichtig.
- App-Store-Einreichung (Build hochladen, Screenshots/Texte, Review): der globale Skill **`app-store-release`** beschreibt die Abfolge. Projektspezifisch: `ci/testflight.sh`, `App-Store-Texte.md`, Skill `run-md-viewer` (Screenshots).

## Design by Contract

Für den reinen Anzeige-Teil bringen Contracts wenig — eine Ausnahme ist
`md Viewer/Shared/MarkdownDocument.swift` (`loadMarkdown` / `maxFileSize` /
`DocumentError`): dort Vor-/Nachbedingungen als `precondition`/`guard` sauber halten.

Für den **Schreibpfad** (Editier-Funktion, ausgeliefert in iOS 1.1; „Neues Dokument aus
Text" / „Als .md speichern" in 1.2) gilt Design by Contract voll: Speichern/Zurücksetzen,
Undo/Redo und Datei-Ersetzung sind zustands- und datenkritisch. Pro Operation
Vor-/Nachbedingungen + Invarianten zuerst benennen, mit `precondition`/`guard` absichern
und Tests daraus ableiten. Details: `~/.claude/CLAUDE.md` (globaler Abschnitt „Design by
Contract"). Historische Feature-Pläne: `docs/archiv/`.
