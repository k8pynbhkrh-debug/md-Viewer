# Plan: „Neues Dokument aus Text" für md Viewer (Version 1.2)

## Ziel

Bisher braucht md Viewer immer eine bestehende `.md`-Datei (via „Öffnen mit" oder
Teilen). Version 1.2 erlaubt, **ohne Ausgangsdatei** anzufangen:

- Im leeren Startbildschirm **Text aus der Zwischenablage einfügen** → er wird
  sofort gerendert und ist bearbeitbar.
- Optional ein **leeres neues Dokument** beginnen.
- Das Ergebnis lässt sich **als neue `.md`-Datei speichern** (Zielordner + Name
  wählt der Nutzer über den System-Dialog „In Dateien sichern").
- Danach verhält sich das Dokument wie eine geöffnete Datei — weiteres
  „Speichern" schreibt in place.

Nebeneffekt-Nutzen: Man bekommt Text in Markdown-Syntax (aus Mail, Chat, einer
`.txt`) und macht mit zwei Tipps eine echte `.md`-Datei daraus.

## Nicht in diesem Schritt

- Kein Datei-Browser / keine Dokumentliste in der App.
- Kein Mehrfach-Tab / mehrere offene Dokumente.
- Keine Vorlagen.

---

## Was sich ändert

### 1. `md Viewer/md_ViewerApp.swift` — zweiter Einstiegsweg

Heute: `@State private var fileURL: URL?` + `.fullScreenCover(item: $fileURL)`.

Neu: die Präsentation über einen kleinen Enum modellieren, damit „Datei" und
„Entwurf ohne URL" denselben `DocumentView` öffnen.

```swift
enum DocumentSource: Identifiable {
    case existing(URL)
    case draft(initialText: String)   // "" == leeres neues Dokument

    var id: String {
        switch self {
        case .existing(let url): url.absoluteString
        case .draft:             "draft"
        }
    }
}

@State private var document: DocumentSource?
```

- `.onOpenURL { document = .existing($0) }`
- `.fullScreenCover(item: $document) { DocumentView(source: $0).id($0.id) }`
- Der Empty-State-Button (siehe 4.) setzt `document = .draft(initialText:)`.

### 2. `md Viewer/DocumentView.swift` — Entwurf + „Speichern unter"

**Init:** `let source: DocumentSource` statt `let fileURL: URL`.

**Neue/geänderte State-Variablen:**
```swift
@State private var fileURL: URL?          // nil, solange der Entwurf ungespeichert ist
@State private var showExporter = false
```

**Laden (`.task`):**
- `.existing(let url)`: wie bisher `fileURL = url; content = loadMarkdown(from: url)`.
- `.draft(let text)`: `fileURL = nil`, `content = .success(text)`,
  `editedText = text`, `hasDraft = true`, direkt in den Edit-Modus
  (`isEditing = true`), Fokus in den Editor.

**Speichern verzweigt:**
- `fileURL != nil` → wie in 1.1: `saveMarkdown(text: editedText, to: url)` in place.
- `fileURL == nil` → `showExporter = true`. Der `.fileExporter` schreibt die
  Datei; im `onCompletion` die zurückgegebene URL übernehmen
  (`fileURL = url`), `content = .success(editedText)`, `hasDraft = false`,
  `isEditing = false`. Ab jetzt speichert der rote Haken wieder in place.

**`.fileExporter`:**
```swift
.fileExporter(
    isPresented: $showExporter,
    document: MarkdownFileDocument(text: editedText),
    contentType: UTType(filenameExtension: "md") ?? .plainText,
    defaultFilename: suggestedFilename(from: editedText)
) { result in
    switch result {
    case .success(let url): adoptSavedFile(at: url)
    case .failure(let error): saveError = "Speichern fehlgeschlagen."
    }
}
```

**`MarkdownFileDocument` (neuer Typ, `Shared/`):**
```swift
struct MarkdownFileDocument: FileDocument {
    static let readableContentTypes: [UTType] =
        [UTType(filenameExtension: "md") ?? .plainText, .plainText]
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else { throw DocumentError.invalidEncoding }
        text = string
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
```

**`suggestedFilename(from:)`:** erste `# …`-Überschrift nehmen, auf
Datei­namen-taugliche Zeichen reduzieren, sonst `„Dokument"`. Endung `.md`
hängt der Exporter an.

**Titel in der Navigationsleiste:** `fileURL?.lastPathComponent ?? "Neues Dokument"`.

**Schließen ohne gespeicherte Datei:** `hasUnsavedChanges` gilt für den Entwurf
immer, solange `fileURL == nil` und `editedText` nicht leer ist →
Bestätigungsdialog „Verwerfen?" (nicht „ungespeicherte Änderungen", sondern
„Dieses Dokument wurde noch nicht gespeichert").

### 3. Empty-State — `md Viewer/ContentView.swift`

Aktuell nur Erklärtext + Datenschutz-Link. Ergänzen:

- **`PasteButton(payloadType: String.self)`** — Apples System-Button; der Nutzer
  tippt bewusst, **keine** „… hat aus … eingefügt"-Meldung, kein
  Pasteboard-Zugriff im Hintergrund. Callback liefert die Strings →
  `document = .draft(initialText: strings.first ?? "")`.
- Darunter ein unauffälliger Button **„Leeres Dokument"**
  (`document = .draft(initialText: "")`).
- `ContentView` bekommt dafür einen Callback/Binding nach oben zu
  `md_ViewerApp` (z. B. `let onNewDocument: (String) -> Void`).

### 4. `.txt` mitöffnen (im selben Release sinnvoll)

- `md Viewer/Info.plist` und `ShareExtension/Info.plist`:
  `public.plain-text` zu `LSItemContentTypes` der `CFBundleDocumentTypes`
  hinzufügen. Dann öffnen `.txt`-Dateien in der App / der Erweiterung.
- Kein weiterer Code nötig — `loadMarkdown` liest schon jeden UTF-8-Text.
- „Als .md speichern" ist für eine geöffnete `.txt` derselbe Weg wie für einen
  Entwurf (`fileURL` zeigt auf die `.txt`; ein „Speichern unter" mit `.md`-Typ
  erzeugt die neue Datei). → kleiner Zusatz-Button „Als Markdown speichern"
  im Edit-Modus, wenn `fileURL?.pathExtension != "md"`.

### 5. Design by Contract (Pflicht laut `CLAUDE.md` für den Schreibpfad)

- **`MarkdownFileDocument.fileWrapper`** — Nachbedingung: die erzeugte
  `FileWrapper` enthält exakt `Data(text.utf8)`.
- **Zustandsübergang „Entwurf → gespeichert" (`adoptSavedFile(at:)`)**
  - Vorbedingung: `fileURL == nil`, `content` ist `.success`.
  - Nachbedingung: `fileURL != nil`, Datei an der URL decodiert zu `editedText`,
    `!hasDraft`, `!isEditing`; ab jetzt schreibt `save()` in place.
  - `precondition`/`assert` an beiden Enden.
- **Invariante:** `fileURL == nil` ⟹ das Dokument war noch nie auf Platte ⟹
  „Schließen" muss den Verwerfen-Dialog zeigen, sobald `editedText` nicht leer.
- **`suggestedFilename(from:)`** — Nachbedingung: Ergebnis ist nicht leer,
  enthält kein `/` und keine Steuerzeichen.
- Tests direkt aus diesen Verträgen (siehe 6.).

### 6. Tests — `md ViewerTests/`

- `MarkdownFileDocument`: Text → `fileWrapper` → zurücklesen == Text; leerer
  Text; Nicht-UTF-8 beim Lesen → `invalidEncoding`.
- `suggestedFilename(from:)`: `"# Titel\n…"` → `"Titel"`; kein Heading →
  `"Dokument"`; `"# a/b:c"` → ohne `/` und `:`; sehr lange Überschrift wird
  gekürzt.
- Entwurf-Zustandsautomat (leichtgewichtig, wie in 1.1): nach `adoptSavedFile`
  gilt `fileURL != nil && !hasDraft && !isEditing`.
- `loadMarkdown` mit `.txt`-Endung (nur UTF-8-Text, kein `.md`) → `.success`.

### 7. `md Viewer.xcodeproj` — Version

- `MARKETING_VERSION`: `1.1` → `1.2`
- `CURRENT_PROJECT_VERSION`: nächste freie Build-Nummer

### 8. App Store

- **Screenshot** ergänzen: Empty-State mit „Einfügen"-Button (Position 2 oder 3).
- **Beschreibung** (`App-Store-Texte.md`, neuer 1.2-Abschnitt): einen Satz zu
  „aus Zwischenablage ein neues Dokument anlegen und als `.md` speichern";
  Keyword-Kandidaten `einfügen`, `zwischenablage`, `txt`, `konvertieren`.
- **App-Prüfungs-Anmerkungen** aktualisieren (neuer Speichern-unter-Dialog).
- **Release Notes 1.2**.

---

## Reihenfolge der Umsetzung

1. `DocumentSource`-Enum + `md_ViewerApp` + `DocumentView(source:)` umstellen
   (bestehendes „Öffnen mit" muss unverändert weiterlaufen — Regressionstest).
2. `MarkdownFileDocument` + `suggestedFilename` + Tests.
3. `.fileExporter` + `adoptSavedFile` + Verträge in `DocumentView`.
4. Empty-State: `PasteButton` + „Leeres Dokument".
5. `.txt`-UTI in beiden Info.plists + „Als Markdown speichern"-Zusatz.
6. Design-by-Contract-Durchsicht, Tests grün, Simulator-Smoke-Test.
7. Version 1.2, Screenshots, Store-Texte.
8. TestFlight-Build → Testrunde → einreichen.

---

## Entschieden (02.09.2026)

1. **„Einfügen" und „Leeres Dokument"** — beide Buttons im Empty-State.
2. **`.txt` mitöffnen ist Teil von 1.2** (`public.plain-text` in beiden
   Info.plists + „Als Markdown speichern").
3. **Default-Dateiname aus der ersten `#`-Überschrift**, sonst `„Dokument"`.
4. **Speicherort wird nicht gemerkt** — der Exporter-Dialog pro Speicherung
   genügt. Security-Scoped Bookmarks / „zuletzt genutzt" erst in einem späteren
   Release, falls gewünscht.
