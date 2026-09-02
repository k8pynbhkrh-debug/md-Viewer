# Arbeiten in diesem Repo

- Nach jedem `git commit` automatisch `git push origin main` ausführen, ohne vorher nachzufragen. Gilt nur für normale Commits auf `main` — destruktive/history-verändernde Operationen (force-push, reset, etc.) bleiben zustimmungspflichtig.

## Design by Contract

Der aktuelle Viewer ist zu klein/read-only, als dass Contracts viel bringen würden — eine
Ausnahme ist `md Viewer/Shared/MarkdownDocument.swift` (`loadMarkdown` / `maxFileSize` /
`DocumentError`): dort Vor-/Nachbedingungen als `precondition`/`guard` sauber halten.

Für die **Editier-Funktion** (`edit-feature-plan.md`, bereits im Bau) gilt Design by
Contract voll: Schreibpfad, Speichern/Zurücksetzen, Undo/Redo und Datei-Ersetzung sind
zustands- und datenkritisch. Pro Operation Vor-/Nachbedingungen + Invarianten zuerst
benennen, mit `precondition`/`guard` absichern und Tests daraus ableiten. Details:
`~/.claude/CLAUDE.md` (globaler Abschnitt „Design by Contract").
