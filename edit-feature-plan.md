# Plan: Edit-Funktion für md Viewer (Version 1.1)

## Ziel
Die App bekommt einen Edit-Modus: Nutzer können Markdown-Dateien direkt in der App bearbeiten und mit einem "Speichern"-Button oben rechts überspeichern.

## Was sich ändert

### 1. `Shared/MarkdownDocument.swift` — Speichern-Funktion hinzufügen

Neue Funktion `saveMarkdown(text:to:)` ergänzen (analog zu `loadMarkdown`):
- Security-scoped resource access starten
- Text als UTF-8 in die Datei schreiben
- Fehlerbehandlung mit neuem `DocumentError`-Case `.notWritable`

```swift
/// Saves the given text back to the file at `url`, overwriting its current content.
nonisolated func saveMarkdown(text: String, to url: URL) throws {
    let isSecurityScoped = url.startAccessingSecurityScopedResource()
    defer {
        if isSecurityScoped { url.stopAccessingSecurityScopedResource() }
    }
    guard let data = text.data(using: .utf8) else { throw DocumentError.invalidEncoding }
    try data.write(to: url, options: .atomic)
}
```

`DocumentError` um `.notWritable` erweitern:
```swift
case notWritable
// errorDescription: "Die Datei konnte nicht gespeichert werden."
```

### 2. `md Viewer/DocumentView.swift` — Edit-Modus einbauen

**Neue State-Variablen:**
```swift
@State private var isEditing = false
@State private var editedText = ""
@State private var isSaving = false
@State private var saveError: String? = nil
```

**Body-Logik:**
- Wenn `isEditing == true`: statt `Markdown(markdown)` einen `TextEditor(text: $editedText)` anzeigen
  - Monospaced Font (`.font(.system(.body, design: .monospaced))`)
  - `.padding(.horizontal, 24).padding(.vertical)`
- Wenn `isEditing == false`: bisherige Markdown-Vorschau wie gehabt

**Toolbar erweitern:**
- Im View-Modus (isEditing == false): Button "Bearbeiten" (`pencil`-Icon) oben rechts (`.primaryAction`)
  - Aktion: `editedText = markdown; isEditing = true`
- Im Edit-Modus (isEditing == true):
  - Links: Button "Vorschau" (`eye`-Icon) — Aktion: `isEditing = false` (Änderungen bleiben in `editedText`)
  - Rechts: Button "Speichern" (`checkmark`-Icon, disabled wenn `isSaving`) — Aktion: speichern + zurück zu Vorschau

**Speichern-Aktion:**
```swift
func save() {
    isSaving = true
    do {
        try saveMarkdown(text: editedText, to: fileURL)
        content = .success(editedText)
        isEditing = false
    } catch {
        saveError = "Speichern fehlgeschlagen."
    }
    isSaving = false
}
```

**Alert bei Fehler:** `.alert("Fehler", isPresented: .constant(saveError != nil)) { Button("OK") { saveError = nil } } message: { Text(saveError ?? "") }`

**Schließen-Button:** Wenn ungespeicherte Änderungen vorhanden (`isEditing == true && editedText != (try? content?.get() ?? "")`), einen Bestätigungs-Dialog zeigen (`.confirmationDialog`).

### 3. `md Viewer.xcodeproj` — Versionsnummer erhöhen

In `Info.plist` bzw. den Build-Settings:
- `CFBundleShortVersionString`: `1.0` → `1.1`
- `CFBundleVersion`: auf nächste Build-Nummer erhöhen

### 4. Tests aktualisieren (`md ViewerTests/DocumentViewTests.swift`)

Vorhandene Tests prüfen, ob sie noch passen. Ggf. Test für `saveMarkdown` ergänzen:
- Temp-Datei anlegen, speichern, zurücklesen, Inhalt vergleichen.

---

## Reihenfolge der Umsetzung

1. `MarkdownDocument.swift` — `saveMarkdown` + `notWritable` Error
2. `DocumentView.swift` — Edit-Modus + Toolbar + Save-Logik
3. Tests anpassen/ergänzen
4. Versionsnummer auf 1.1 setzen
5. Kurzer Build-Test im Simulator

---

## Prompt für Claude Code CLI

Folgenden Text ins Terminal eingeben nach `claude` im Projektordner:

```
Implementiere die Edit-Funktion für md Viewer Version 1.1. Halte dich exakt an diesen Plan:

1. Öffne Shared/MarkdownDocument.swift und ergänze:
   - Einen neuen DocumentError-Case `notWritable` mit localizedDescription "Die Datei konnte nicht gespeichert werden."
   - Eine neue nonisolated Funktion `saveMarkdown(text: String, to url: URL) throws` die:
     * Security-scoped resource access startet (wie in loadMarkdown)
     * Den Text als UTF-8 Data kodiert (bei Fehler: throw DocumentError.invalidEncoding)
     * Die Data mit .atomic Option in die URL schreibt (bei Fehler: throw DocumentError.notWritable)

2. Öffne md Viewer/DocumentView.swift und:
   - Füge diese State-Variablen hinzu: @State private var isEditing = false, @State private var editedText = "", @State private var isSaving = false, @State private var saveError: String? = nil
   - Ersetze im .success(let markdown)-Branch: wenn isEditing == true, zeige statt Markdown(markdown) einen TextEditor(text: $editedText) mit .font(.system(.body, design: .monospaced)), gleichen Paddings wie die Markdown-View
   - Erweitere die Toolbar:
     * Wenn isEditing == false: ToolbarItem(placement: .primaryAction) mit Button "Bearbeiten" (pencil-Icon), Aktion: editedText = markdown; isEditing = true
     * Wenn isEditing == true: ToolbarItem(placement: .cancellationAction) mit Button "Vorschau" (eye-Icon, neben dem Schließen-Button), Aktion: isEditing = false; und ToolbarItem(placement: .primaryAction) mit Button "Speichern" (checkmark-Icon), disabled wenn isSaving, Aktion: save()
   - Füge eine private func save() hinzu die: isSaving = true setzt, saveMarkdown(text: editedText, to: fileURL) aufruft, bei Erfolg content = .success(editedText) und isEditing = false setzt, bei Fehler saveError setzt, danach isSaving = false
   - Füge ein .alert für saveError hinzu

3. Setze die CFBundleShortVersionString in md Viewer/Info.plist auf 1.1

4. Prüfe ob die bestehenden Tests noch kompilieren und laufen. Falls ein Test für saveMarkdown sinnvoll ist, füge ihn in md ViewerTests/DocumentViewTests.swift hinzu.

Mache alle Änderungen in einem Zug, erkläre jeden Schritt kurz und führe am Ende `xcodebuild -scheme "md Viewer" -destination "platform=iOS Simulator,name=iPhone 16" build` aus um zu prüfen ob alles kompiliert.
```
