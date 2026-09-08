# App Store Connect — Texte für "md Viewer"

Stand: 08.09.2026 · Alle Felder unten sind copy-paste-fertig für App Store Connect. Zeichenlimits sind Apples aktuelle Vorgaben (Stand August 2026).

> **Version 1.1 (02.09.2026):** Optionaler Edit-Modus (Datei direkt bearbeiten und
> überspeichern). **Am 04.09.2026 von Apple genehmigt und im Store** (Auto-Release).
> Editor-Bedienung final: **X** verwirft (mit Rückfrage), **Pfeil** (uturn) macht
> einzelne Tipp-Bursts schrittweise rückgängig, **roter Haken** speichert (mit
> Rückfrage).
>
> **Version 1.2: am 04.09.2026 von Apple genehmigt und im Store** (Auto-Release,
> `currentVersionReleaseDate` 2026-09-04). Neues Dokument aus eingefügtem Text +
> „Als .md speichern", `.txt`-Support. In ASC: Beschreibung, Werbetext, Keywords,
> „Neues in dieser Version", Untertitel („lesen, bearbeiten, erstellen"); 9er-
> Screenshot-Satz iPhone 6,9" + iPad 13"; Build 10. Prüf-Video + Übersicht:
> `docs/videos/` (`README.md`).
>
> **Version 1.3 / macOS 1.1 (in Arbeit, 08.09.2026) — Englische Lokalisierung.**
> Die App wird zweisprachig (Deutsch + Englisch, String Catalog, en als Basis;
> siehe `docs/archiv/` bzw. Memory `md-viewer-localization`). Anlass: der US-Store
> hatte keine „English (U.S.)"-Lokalisierung, zeigte im Untertitel-Slot die
> Kategorie („Productivity") statt eines Untertitels (30 indexierte Zeichen
> ungenutzt, am 08.09.2026 im Live-Store bestätigt). Mit 1.3 kommt eine
> vollständige **English (U.S.)**-ASC-Lokalisierung dazu (Untertitel, Keywords,
> Werbetext, Beschreibung). Mac-Polish in derselben Runde: Catalyst-Ersatz für den
> `PasteButton` im Leerzustand. Deutsche Store-Texte bleiben unverändert; nur die
> neue en-US-Lokalisierung + Build-/Versionsnummer ändern sich.
> Englische Felder: Abschnitt **„English (U.S.) — 1.3 / macOS 1.1"** unten.
>
> **08.09.2026 — ASC eingerichtet (per ASC-REST-API, Chrome-Login war nicht möglich).**
> Beide Builds verarbeitet: iOS **1.3 (11)** und macOS **1.1 (16)**, beide „VALID",
> Export-Compliance automatisch (`usesNonExemptEncryption` = false).
> - **en-US App-Name musste geändert werden:** „md Viewer" ist im englischen
>   Store-Namespace von einer fremden Entwickler-ID belegt (Apple prüft ohne
>   Rücksicht auf Groß/Klein + Leerzeichen: „md Viewer" = „MDViewer" = „MD Viewer").
>   Gewählt: **„md Viewer: Markdown"** (nur en-US; deutscher Name bleibt „md Viewer").
>   Untertitel en-US: „Read, edit & create Markdown".
> - **iOS 1.3:** Build 11 verknüpft. de-DE „Neu in Version" gesetzt (war leer),
>   de-DE Werbetext = 1.2-Wert wiederhergestellt (war beim Anlegen nicht mitgekommen),
>   sonst deutsche Felder unangetastet. en-US-Lokalisierung komplett (Beschreibung
>   ohne „ON THE MAC", Keywords, Werbetext, „Neu in Version"). Screenshots: de 9+9
>   (aus 1.2), en 7 iPhone 6,9" + 7 iPad 13". Prüf-Notizen enthalten bereits den
>   1.3-Abschnitt.
> - **macOS 1.1:** Version angelegt, Build 16 verknüpft. de-DE aus 1.0 automatisch
>   übernommen + nur „Neu in Version" ergänzt. en-US-Lokalisierung komplett
>   (Beschreibung **mit** „ON THE MAC"). Screenshots: de 6 (aus 1.0), en 6 Mac
>   (2560×1600), Reihenfolge wie de-Satz (Übersicht zuerst). Prüf-Notizen für
>   macOS 1.1 gesetzt.
> - **Offen:** nur noch „Zur Prüfung einreichen" für beide (Erics Freigabe).
>   Kleine offene Frage: die en-US-Mac-Beschreibung übernimmt den geteilten
>   „CREATE, EDIT, SAVE"-Block wortgleich von iOS und sagt dort „tap" statt „click"
>   (die deutsche Mac-Fassung wurde angepasst). Kosmetisch, kein Blocker.

---

## English (U.S.) — 1.3 / macOS 1.1

Neue ASC-Lokalisierung **English (U.S.)** für beide Plattformen. `en` ist die
Basissprache der App; diese Texte sind die englischen Store-Felder. Deutsche
Felder bleiben wie in 1.2 / macOS 1.0.

### App Name (max. 30)

```
md Viewer: Markdown
```
(19 Zeichen; nur en-US. „md Viewer" allein ist im englischen Store-Namespace von
einer fremden Entwickler-ID belegt — Apple prüft case-/whitespace-insensitiv, also
sind auch „MDViewer"/„MD Viewer" gesperrt. Der deutsche Name bleibt „md Viewer".)

### Subtitle (max. 30)

```
Read, edit & create Markdown
```
(28 Zeichen — nennt die drei Kernfunktionen direkt neben dem Namen; deckt
„read", „edit", „create", „Markdown" für die Suche ab. Deutsches Gegenstück:
„lesen, bearbeiten, erstellen".)

### Promotional Text (max. 170)

```
Read, edit and re-save Markdown files. New: start a document from clipboard text and save it as .md. Opens .txt too. No account, no cloud, works fully offline.
```
(157 Zeichen; jederzeit ohne Review änderbar)

### Keywords (max. 100, kommagetrennt, keine Leerzeichen)

```
markdown,editor,edit,paste,clipboard,txt,notes,readme,reader,table,code,offline,preview
```
(87 Zeichen — „viewer"/„md" weggelassen, stehen schon im App-Namen.)

### What's New / Release Notes — 1.3 (iOS) und macOS 1.1

```
md Viewer is now fully available in English.

This version adds a complete English localization of the app and the App Store listing. There are no functional changes.
```

Deutsche Fassung desselben Feldes (für die de-Lokalisierung von 1.3 / 1.1):

```
md Viewer gibt es jetzt vollständig auf Englisch.

Diese Version ergänzt eine komplette englische Lokalisierung der App und des Store-Eintrags. Es gibt keine funktionalen Änderungen.
```

(macOS 1.1 ist das erste Mac-Update, „Neues in dieser Version" ist dort also
nutzbar — anders als bei macOS 1.0.)

### Description (max. 4000) — English (U.S.)

Für **iOS 1.3**: der Text ohne den Abschnitt „ON THE MAC".
Für **macOS 1.1**: mit dem Abschnitt „ON THE MAC" (nach dem Intro, vor
„CREATE, EDIT, SAVE").

```
md Viewer opens Markdown files, shows them cleanly formatted right away, and lets you edit that same text in place, create new documents, and save them back to the file.

No file browser. No account. No cloud. No tracking. Open a .md or .txt file from the Files app or the share menu. md Viewer renders headings, lists, tables, bold/italic, code blocks with syntax highlighting, and quotes. No raw text, no characters to decode.

ON THE MAC

md Viewer runs on iPhone, iPad, and Mac — one purchase for all three. On the Mac you can make md Viewer the default app for .md files with one click in the start window. After that, double-clicking a Markdown file in the Finder opens it directly in md Viewer instead of Preview or TextEdit. Use the File menu to start a draft with New Document (Cmd-N) or open a file with Open (Cmd-O). The window resizes freely.

CREATE, EDIT, SAVE

Start without a file: tap Paste on the start screen to take text from the clipboard, or choose Blank Document. The draft opens straight in the editor. The red checkmark saves it as a new .md file; you pick the folder and name in the Files dialog. After that, the checkmark writes to that same file as usual.

Existing files: tap Edit in the top right. The preview turns into a text editor. Save with the red checkmark; after a short confirmation the original file is overwritten. The X discards your changes (after a confirmation), and the arrow steps back through individual changes. No autosave, no export, no second copy.

.txt files open in the app and in the share extension too. When you edit a .txt, the app also offers Save as Markdown.

If you only want to read, none of this gets in the way. Every file opens in the formatted preview first.

WHY SO MINIMAL?

Most Markdown apps today are full editors with file management, cloud sync, and menus. Handy, but too much when you just want to read a file quickly, jot down a quick note, or fix a typo now and then. md Viewer deliberately does only that: tap a file, read, change or create if needed, done.

FEATURES

- Open via Open With in the Files app or straight from the share menu (mail attachments, AirDrop). The share extension shows the document formatted right away, without switching apps
- Create a new document from pasted or typed text and save it as a .md file
- Opens .md and .txt
- Clean Markdown rendering: headings, lists, task lists, tables (scroll horizontally), code blocks with syntax highlighting, quotes, links, images
- Edit and save in place in the open file, with a confirmation before overwriting and before closing with unsaved changes
- Full Unicode support: emoji, Arabic and Hebrew (right-to-left), Chinese, Japanese, and Korean characters
- Supports Dynamic Type and VoiceOver
- Automatic Dark Mode / Light Mode
- Runs entirely offline, no network access in the code

PRIVACY

md Viewer collects no data at all. No analytics, no tracking, no account, no cloud sync. Files you open, edit, and create are processed only locally on your device. The clipboard is read only when you explicitly tap Paste.

Who is it for? Anyone who regularly receives or manages .md or .txt files (notes, READMEs, technical docs, meeting notes) and wants to read them quickly and cleanly, edit them now and then, or jot down a new one, without opening a full editor.
```

### App Review notes — 1.3 / macOS 1.1 (englisch, ans bestehende Notes-Feld anhängen)

```
Version 1.3 (iOS) / 1.1 (macOS) adds a full English (en) localization of the app UI via a String Catalog; English is now the base development language and German is a complete translation. No functional or behavioral changes, no new permissions, no new network access.

On Mac Catalyst only: the empty-state "Paste" button is now a standard button instead of SwiftUI's PasteButton (which does not render under Mac Catalyst). It reads UIPasteboard only on an explicit tap, same as before.
```

### Screenshots — English (U.S.), 1.3

Eigener englischer Satz unter `App-Store-Screenshots/en/`, erzeugt mit
`.claude/skills/run-md-viewer/screenshots-ios.sh` (Sim auf `en`, Demo-Dokumente aus `demo-dokumente/en/`).
Der deutsche Satz (`App-Store-Screenshots/de/`, 9 Bilder aus 1.2) bleibt für die
de-Lokalisierung.

- **iPhone 6,9"** (1320×2868) und **iPad 13"** (2064×2752): je 7 Bilder
  `01-empty-state` (Leerzustand, „Paste" aktiv), `02-new-from-text` (Entwurf im
  Editor), `03-editing` (`Note.md` im Editor, Tastatur), `04-overview`
  (`Team-Note.md` gerendert), `05-table` (`Release-Matrix.md`), `06-code`
  (`Code-Examples.md`), `07-languages` (`Languages & Emoji.md`).
- Die Files-App-/Share-Extension-Bilder (`08/09` im de-Satz) sind nicht
  CLI-scriptbar und im en-Satz weggelassen (Apple erlaubt 1–10).
- **Mac** (2560×1600): 6 Bilder analog zum de-Mac-Satz, englische Demos.

---

## macOS 1.0 — Mac-Version (Mac Catalyst) + .md-Standard-App

> **macOS-Version 1.0: von Apple genehmigt und im Mac App Store** (eingereicht
> 04.09.2026 15:19, danach freigegeben; auf der iOS-Store-Seite erscheint der
> Button „Anzeigen in: Mac App Store"). Der Mac App Store bekommt einen **eigenen
> Versions-Strang ab 1.0** (erste Mac-Version); iOS/iPadOS bleibt bei 1.2. md Viewer
> läuft jetzt auch auf dem Mac (Mac Catalyst) — gleiches Listing / Universal Purchase,
> ein Kauf für iPhone, iPad und Mac. Auf dem Mac lässt sich md Viewer per Klick im
> Startfenster zur **Standard-App für `.md`** machen
> (`LSSetDefaultRoleHandlerForContentType`); danach öffnet ein Doppelklick im Finder
> die Datei in md Viewer. Menü „Ablage → Neues Dokument (⌘N) / Öffnen … (⌘O)", Fenster
> frei skalierbar. App sandboxed (Pflicht Mac App Store). Eingereichter Mac-Build
> **1.0 (15)** (inkl. Fenster-Skalier-Fix) — im Xcode-Projekt bleibt `MARKETING_VERSION`
> beim iOS-Strang (1.2), der Mac-Build überschreibt per `ci/testflight-mac.sh`.
> Vor der Einreichung auf echtem Mac getestet und von Eric bestätigt.
>
> **In ASC bereits eingetragen** (weitgehend per App-Store-Connect-REST-API,
> `scratchpad/asc.py`): macOS-Plattform (durch Build-Upload automatisch);
> `appStoreVersion` **1.0** (MAC_OS); de-DE-Beschreibung (mit „AUF DEM MAC"-Abschnitt,
> unten), Keywords, Werbetext, URLs; 6 Mac-Screenshots (2560×1600); Prüf-Notizen
> mit „FIRST macOS release (1.0)" + „HOW TO TEST (Mac)". „Neues in dieser Version"
> ist bei der ersten Mac-Version von ASC gesperrt (normal, keiner nötig).
>
> **Signing** (einmalig, per API): zwei `MAC_CATALYST_APP_STORE`-Profile +
> „Mac Installer Distribution"-Zertifikat. `ExportOptions-mac.plist` pinnt beide
> Zertifikate per SHA-1 (Xcode-`-exportArchive`-Bug). Details:
> `docs/archiv/mac-catalyst-feature-plan.md`.
>
> **iOS 1.2 ≠ macOS 1.0:** getrennte Review-Warteschlangen, blockierten sich nicht —
> beide Versionen sind inzwischen genehmigt und im Store.
>
> Optionaler Polish für ein späteres Update (kein Blocker): „Einsetzen"-Button fehlt im Mac-Empty-State
> (Catalyst rendert `PasteButton` dort nicht).

### Neu in dieser Version / Release Notes — macOS 1.0

Bei der **ersten Mac-Version** ist „Neues in dieser Version" in ASC gesperrt
(kein Vorgänger auf der Plattform). Der folgende Text wird daher **nicht**
verwendet, ist aber für ein späteres Mac-Update aufgehoben:

```
md Viewer für den Mac

• md Viewer gibt es jetzt auch auf dem Mac – im selben Kauf wie iPhone und iPad (Universal Purchase).
• Auf dem Mac: im Startfenster „md Viewer als Standard für .md festlegen" – danach öffnet ein Doppelklick im Finder deine Markdown-Datei direkt in md Viewer.
• Menü „Ablage": Neues Dokument (⌘N) und Öffnen … (⌘O). Fenster frei in der Größe verstellbar.
```

### Werbetext / Promotional Text (max. 170) — macOS 1.0, in ASC eingetragen

```
md Viewer jetzt auch für den Mac – ein Kauf für iPhone, iPad und Mac. Auf dem Mac Standard-App für .md. Lesen, bearbeiten, neu anlegen. Offline, kein Konto.
```

### Untertitel / Subtitle (max. 30 Zeichen) — macOS 1.0

Unverändert zur iOS-Fassung. Die Mac-Version ändert keine Kernfunktion, nur die Plattform.

### Beschreibung — macOS 1.0, „AUF DEM MAC"-Abschnitt (in ASC eingetragen)

Die Mac-Beschreibung ist die iOS-1.2-Beschreibung plus dieser Abschnitt (nach dem
Intro, vor „ERSTELLEN, BEARBEITEN, SPEICHERN") und „Finder" in der Aufzählung:

```
AUF DEM MAC

md Viewer läuft auf iPhone, iPad und Mac – ein Kauf für alle drei. Auf dem Mac kannst du md Viewer im Startfenster mit einem Klick zur Standard-App für .md-Dateien machen. Danach öffnet ein Doppelklick im Finder deine Markdown-Datei direkt in md Viewer, statt in Vorschau oder TextEdit. Über das Menü „Ablage" legst du mit „Neues Dokument" (⌘N) einen Entwurf an oder öffnest eine Datei mit „Öffnen …" (⌘O). Das Fenster ist frei skalierbar.
```

### Mac-Screenshots — macOS 1.0 (in ASC hochgeladen)

6 Stück, **2560×1600** (APP_DESKTOP), im Simulator-losen Catalyst-Lauf auf dem
Mac erzeugt (`scratchpad/macshots.py`: App starten, Fenster mittig auf
2560×1600-Leinwand komponiert). Reihenfolge:

1. `02-uebersicht` — Team-Notiz.md gerendert (Überschriften, Aufgabenliste, Tabelle mit Emoji)
2. `01-mac-standard-app` — Startfenster mit Button „md Viewer als Standard für .md festlegen"
3. `03-tabelle` — Release-Matrix.md (breite Tabelle)
4. `04-code` — Code-Beispiele.md (Syntax-Hervorhebung Swift/Python/Shell/JSON)
5. `05-sprachen` — Sprachen & Emoji.md (RTL, CJK, Emoji, Symbole)
6. `06-bearbeiten` — Editor mit Rohtext, Toolbar (X / Rückgängig / roter Haken)

### App-Prüfungs-Anmerkungen — macOS 1.0 (in ASC eingetragen)

Steht im **Notes-Feld** der macOS-1.0-Version: App Store Connect → md Viewer →
**Vertrieb** → **macOS 1.0** → Abschnitt **„App-Prüfungsinformationen"** → Feld
**„Anmerkungen"**. Direktlink-Muster:
`https://appstoreconnect.apple.com/apps/6806814038/distribution/macos/version/inflight`

Wortlaut (englisch, für Apples Prüfer):

```
ABOUT THE APP
md Viewer displays Markdown (.md / .markdown) and .txt files and lets the user edit and re-save them in place, or create a new document from pasted/typed text and save it as a .md file. No file manager, no account, no cloud, no backend, no analytics, no tracking, no in-app purchases, no ads, no user-generated content shared with anyone. Bundled open-source rendering libraries only (swift-markdown-ui, swift-cmark, Highlightr, NetworkImage), MIT-licensed, running on device. The only network request is if an opened Markdown file references a remote image URL. No AI services. No ATT prompt. No location/contacts/camera prompts.

This is the FIRST macOS release (version 1.0). The same app already ships on iOS/iPadOS (currently 1.2); this is a Mac Catalyst build distributed via Universal Purchase (one App Store listing).

MAC-SPECIFIC IN 1.0
On the empty-state screen the Mac build has one button not present on iOS: "md Viewer als Standard fuer .md festlegen". It calls LaunchServices (LSSetDefaultRoleHandlerForContentType) to register md Viewer as the default handler for the Markdown UTI net.daringfireball.markdown. macOS shows its own confirmation the first time; on failure the app shows an alert pointing to Finder > Get Info > Open With. The File menu has "Neues Dokument" (Cmd-N) and "Oeffnen ..." (Cmd-O); the window is resizable. The bundled Share extension also runs under Mac Catalyst. The app is sandboxed (com.apple.security.app-sandbox) with com.apple.security.files.user-selected.read-write for the save dialog; files opened by double-click get sandbox access via LaunchServices.

HOW TO TEST (Mac)
1. Launch the app. On the empty state, click "md Viewer als Standard fuer .md festlegen" (macOS may ask to confirm). 2. Double-click any .md file in Finder - it opens in md Viewer, rendered. 3. Click "Bearbeiten" (top right), change the text, click the red checkmark, confirm - the original file is overwritten. 4. File > Neues Dokument, type text, red checkmark, choose a location - a new .md file is written.

REGIONAL DIFFERENCES / REGULATED CONTENT
None. Identical behavior in all regions. The app only displays and edits files supplied by the user; no protected third-party content.

DEVICES TESTED
Mac (Apple silicon, macOS 26, Mac Catalyst); iPhone (physical device) and iPhone 17 Pro Max / iPad Pro 13-inch simulators, iOS/iPadOS 26.
```

---

## Version 1.2 — geänderte Texte (final, 04.09.2026)

> **Version 1.2:** Neues Dokument ohne Ausgangsdatei — im leeren Startbildschirm
> Text aus der Zwischenablage einfügen („Einsetzen") oder ein leeres Dokument
> beginnen, dann über den System-Dialog als neue `.md`-Datei sichern. Danach
> schreibt der rote Haken wie gewohnt in dieselbe Datei. Zusätzlich öffnen jetzt
> auch `.txt`-Dateien in der App und der Teilen-Erweiterung; beim Bearbeiten einer
> `.txt` gibt es „Als Markdown speichern".

### Neu in dieser Version / Release Notes (max. 4000 Zeichen) — 1.2

```
Neu in 1.2: Ohne Datei anfangen

• Auf dem Startbildschirm „Einsetzen" tippen: Text aus der Zwischenablage wird sofort als Markdown angezeigt und ist bearbeitbar. Oder „Leeres Dokument" für einen leeren Start.
• Mit dem roten Haken als neue .md-Datei sichern; du wählst Ordner und Name im Dateien-Dialog. Danach speichert der Haken wie gewohnt in diese Datei.
• .txt-Dateien lassen sich jetzt ebenfalls öffnen, in der App und über das Teilen-Menü. Beim Bearbeiten einer .txt gibt es „Als Markdown speichern".
```

### Schlüsselwörter / Keywords (max. 100 Zeichen) — 1.2

```
markdown,editor,bearbeiten,einfügen,zwischenablage,txt,notizen,readme,reader,tabelle,code,offline
```
(97 Zeichen — „leser", „dokument", „vorschau" raus; „einfügen", „zwischenablage",
„txt" rein für die neue Funktion.)

### Werbetext / Promotional Text (max. 170 Zeichen) — 1.2

```
Markdown lesen, bearbeiten und überspeichern. Neu: Text aus der Zwischenablage einfügen und als .md-Datei sichern. Auch .txt. Kein Konto, keine Cloud, offline.
```
(157 Zeichen, ohne Gedankenstriche)

### Untertitel / Subtitle (max. 30 Zeichen) — 1.2

```
lesen, bearbeiten, erstellen
```
(28 Zeichen — nennt alle drei Kernfunktionen. Ersetzt die 1.1-Fassung
„Markdown lesen & bearbeiten". Kleinschreibung ist Absicht.)

### Beschreibung (max. 4000 Zeichen) — 1.2

```
md Viewer öffnet Markdown-Dateien, zeigt sie sofort sauber formatiert an und lässt dich denselben Text direkt bearbeiten, neu anlegen und zurück in die Datei speichern.

Kein Datei-Browser. Kein Konto. Keine Cloud. Kein Tracking. Öffne eine .md- oder .txt-Datei über die Dateien-App oder das Teilen-Menü. md Viewer rendert Überschriften, Listen, Tabellen, fett/kursiv, Codeblöcke mit Syntax-Hervorhebung und Zitate. Kein Rohtext, keine Zeichen zum Entziffern.

ERSTELLEN, BEARBEITEN, SPEICHERN

Ohne Datei anfangen: auf dem Startbildschirm „Einsetzen" tippen und Text aus der Zwischenablage übernehmen, oder „Leeres Dokument" wählen. Der Entwurf öffnet direkt im Editor. Mit dem roten Haken sicherst du ihn als neue .md-Datei; Ordner und Name wählst du im Dateien-Dialog. Danach schreibt der Haken wie gewohnt in genau diese Datei.

Bestehende Dateien: oben rechts auf „Bearbeiten" tippen. Aus der Vorschau wird ein Texteditor. Mit dem roten Haken speichern, nach einer kurzen Rückfrage wird die Originaldatei überschrieben. Mit dem X verwirfst du die Änderungen (nach Rückfrage), mit dem Pfeil machst du einzelne Änderungen schrittweise rückgängig. Kein Zwischenspeichern, kein Export, keine zweite Kopie.

Auch .txt-Dateien öffnen jetzt in der App und in der Teilen-Erweiterung. Beim Bearbeiten einer .txt gibt es „Als Markdown speichern".

Wer nur lesen will, merkt davon nichts. Jede Datei öffnet zuerst in der formatierten Vorschau.

WARUM SO REDUZIERT?

Die meisten Markdown-Apps sind heute vollwertige Editoren mit Dateiverwaltung, Cloud-Sync und Menüs. Praktisch, aber überladen, wenn man eine Datei nur schnell lesen, kurz notieren oder gelegentlich korrigieren will. md Viewer macht bewusst nur das: Datei antippen, lesen, bei Bedarf ändern oder neu anlegen, fertig.

FUNKTIONEN

• Öffnen über „Öffnen mit" in der Dateien-App oder direkt aus dem Teilen-Menü (z. B. Mail-Anhänge, AirDrop). Die Teilen-Erweiterung zeigt das Dokument sofort formatiert an, ohne die App zu wechseln
• Neues Dokument aus eingefügtem oder eingetipptem Text erstellen und als .md-Datei sichern
• Öffnet .md und .txt
• Sauberes Markdown-Rendering: Überschriften, Listen, Aufgabenlisten, Tabellen (horizontal scrollbar), Codeblöcke mit Syntax-Hervorhebung, Zitate, Links, Bilder
• Bearbeiten und Überspeichern direkt in der geöffneten Datei, mit Rückfrage vor dem Überschreiben und beim Schließen mit ungespeicherten Änderungen
• Volle Unicode-Unterstützung: Emoji, arabische und hebräische Schrift (rechts-nach-links), chinesische, japanische und koreanische Zeichen
• Unterstützt Dynamic Type und VoiceOver
• Automatisches Dark Mode / Light Mode
• Läuft komplett offline, keine Netzwerkzugriffe im Code

DATENSCHUTZ

md Viewer erhebt keinerlei Daten. Keine Analyse-Software, kein Tracking, kein Konto, keine Cloud-Synchronisation. Geöffnete, bearbeitete und neu erstellte Dateien werden ausschließlich lokal auf deinem Gerät verarbeitet. Die Zwischenablage wird nur gelesen, wenn du ausdrücklich auf „Einsetzen" tippst.

Für wen ist die App? Für alle, die regelmäßig .md- oder .txt-Dateien bekommen oder verwalten (Notizen, READMEs, technische Doku, Protokolle) und sie schnell und sauber lesen, ab und zu bearbeiten oder kurz neu anlegen wollen, ohne einen vollen Editor zu öffnen.
```
(ohne Gedankenstriche; nur Bindestriche in zusammengesetzten Wörtern)

### Kategorie / Altersfreigabe — 1.2

Unverändert: Primär Produktivität, sekundär Dienstprogramme, Altersfreigabe **4+**.
Die Zwischenablage wird nur auf ausdrücklichen Tipp des System-PasteButtons
gelesen, kein Hintergrundzugriff, kein UGC im Sinne geteilter/öffentlicher Inhalte.

### App-Prüfungs-Anmerkungen — 1.2

Ergänzen (englisch, ans bestehende Notes-Feld anhängen): „Version 1.2 adds a
system PasteButton on the empty state to start a new document from clipboard
text, a 'save as' dialog (`.fileExporter`) to write it as a new .md file, and
`.txt` support (`public.plain-text` document type). No background pasteboard
access; the clipboard is only read on an explicit tap of the system PasteButton.
A short screen recording of the new-document / save / .txt flow is attached, plus
`sample-markdown-files.zip` with test documents (incl. a .txt)."

### Screenshots — 1.2

Neuer Satz, **9 Bilder** je iPhone 6,9" (1320×2868) und iPad 13" (2064×2752),
feste Reihenfolge. Am 04.09.2026 im Simulator erzeugt (iPhone 17 Pro Max /
iPad Pro 13", Light Mode, Statusleiste 09:41). Grund für den kompletten Neu-Satz:
die alten Bilder 3–7 stammten vom 29.08. — **vor** dem Edit-Modus, zeigten also
`DocumentView` ohne den „Bearbeiten"-Stift oben rechts; der Leerzustand hatte
noch keine „Einsetzen"/„Leeres Dokument"-Buttons.

1. `01-leerzustand.png` — Startbildschirm v1.2: „Einsetzen" (System-PasteButton, aktiv) + „Leeres Dokument" + Datenschutz-Link. **Neu an Position 1**, weil hier sichtbar ist, dass man ohne Datei anfangen kann.
2. `02-neu-aus-text.png` — frischer Entwurf im Editor („Neues Dokument", Monospace, Toolbar X / Rückgängig / roter Haken = „als .md sichern"). Über DEBUG-Arg `-mdviewerDraft "<text>"`.
3. `03-bearbeiten.png` — bestehende `.md` im Editor (`Notiz.md`), Bearbeiten-Modus mit sichtbarer Änderung, roter Haken aktiv, **eingeblendete Tastatur** (iPhone + iPad). Über DEBUG-Arg `-mdviewerScreenshotEdit` + `openurl` + Software-Tastatur-Toggle.
4. `04-uebersicht.png` — gerendertes Dokument: Überschriften, Aufgabenliste, Tabelle, Zitat, Link — **mit Stift oben rechts**.
5. `05-tabelle.png` — breite Tabelle (auf iPhone horizontal scrollbar) + Kennzahlen-Tabelle.
6. `06-code.png` — Codeblöcke mit Syntax-Hervorhebung (Swift, Python, Shell, JSON).
7. `07-sprachen.png` — Emoji, Arabisch/Hebräisch (RTL), CJK, Devanagari, Thai, Mathe-Symbole.
8. `08-oeffnen-mit.png` — „Öffnen mit → md Viewer" in der Dateien-App. **Aus 1.1 übernommen** (zeigt die Dateien-App, keine veraltete App-UI).
9. `09-teilen-extension.png` — Teilen-Erweiterung rendert ein geteiltes Dokument („Fertig"-Blatt). **Aus 1.1 übernommen** (Extension unverändert, read-only).

iPad-Hinweis: der M5-iPad-Simulator zeichnet einen kleinen grauen Bogen in der
unteren rechten Ecke (Bezel-Artefakt, kein UI-Element); er wird beim Erzeugen
per Skript mit weißem Rand übermalt.

---

## Version 1.1 — geänderte Texte

### Neu in dieser Version / Release Notes (max. 4000 Zeichen)

```
Neu in 1.1: Bearbeiten-Modus

• Markdown-Dateien lassen sich jetzt direkt in der App bearbeiten. Oben rechts auf „Bearbeiten" tippen, Text ändern, mit dem roten Haken speichern. Nach einer kurzen Rückfrage wird die Originaldatei überschrieben.
• Mit dem X verwirfst du die Änderungen (nach Rückfrage), mit dem Pfeil machst du einzelne Änderungen schrittweise rückgängig.
• Wer nur lesen will, merkt nichts davon — jede Datei öffnet zuerst in der Vorschau.

(ASC-Fassung 03.09.2026; ohne Gedankenstriche.)
```

### Untertitel / Subtitle (max. 30 Zeichen) — 1.1

```
Markdown lesen & bearbeiten
```
(27 Zeichen — nennt beide Kernfunktionen direkt neben dem Namen. In ASC gesetzt
(03.09.2026); ersetzt die 1.0-Fassung „Reiner Markdown-Betrachter".)

### Werbetext / Promotional Text (max. 170 Zeichen) — 1.1

```
Markdown-Dateien schön formatiert lesen, mit Tabellen, Code und Listen. Und bei Bedarf direkt in der App bearbeiten und überspeichern. Kein Konto, keine Cloud, offline.
```
(163 Zeichen — ohne Gedankenstriche)

### Beschreibung (max. 4000 Zeichen) — 1.1

```
md Viewer öffnet Markdown-Dateien, zeigt sie sofort sauber formatiert an und lässt dich denselben Text direkt bearbeiten und zurück in die Datei speichern.

Kein Datei-Browser. Kein Konto. Keine Cloud. Kein Tracking. Öffne eine .md-Datei über die Dateien-App oder das Teilen-Menü. md Viewer rendert Überschriften, Listen, Tabellen, fett/kursiv, Codeblöcke mit Syntax-Hervorhebung und Zitate. Kein Rohtext, keine Zeichen zum Entziffern.

BEARBEITEN UND ÜBERSPEICHERN

Oben rechts auf „Bearbeiten" tippen. Aus der Vorschau wird ein Texteditor. Text ändern, mit dem roten Haken speichern. Nach einer kurzen Rückfrage wird die Originaldatei überschrieben. Mit dem X verwirfst du die Änderungen (nach Rückfrage), mit dem Pfeil machst du einzelne Änderungen schrittweise rückgängig. Kein Zwischenspeichern, kein Export, keine zweite Kopie. Die Änderung landet in genau der Datei, die du geöffnet hast.

Wer nur lesen will, merkt davon nichts. Jede Datei öffnet zuerst in der formatierten Vorschau.

WARUM SO REDUZIERT?

Die meisten Markdown-Apps sind heute vollwertige Editoren mit Dateiverwaltung, Cloud-Sync und Menüs. Praktisch, aber überladen, wenn man eine Datei nur schnell lesen und gelegentlich korrigieren will. md Viewer macht bewusst nur das: Datei antippen, lesen, bei Bedarf ändern, fertig.

FUNKTIONEN

• Öffnen über „Öffnen mit" in der Dateien-App oder direkt aus dem Teilen-Menü (z. B. Mail-Anhänge, AirDrop). Die Teilen-Erweiterung zeigt das Dokument sofort formatiert an, ohne die App zu wechseln
• Sauberes Markdown-Rendering: Überschriften, Listen, Aufgabenlisten, Tabellen (horizontal scrollbar), Codeblöcke mit Syntax-Hervorhebung, Zitate, Links, Bilder
• Bearbeiten und Überspeichern direkt in der geöffneten Datei, mit Rückfrage vor dem Überschreiben und beim Schließen mit ungespeicherten Änderungen
• Volle Unicode-Unterstützung: Emoji, arabische und hebräische Schrift (rechts-nach-links), chinesische, japanische und koreanische Zeichen
• Unterstützt Dynamic Type und VoiceOver
• Automatisches Dark Mode / Light Mode
• Läuft komplett offline, keine Netzwerkzugriffe im Code

DATENSCHUTZ

md Viewer erhebt keinerlei Daten. Keine Analyse-Software, kein Tracking, kein Konto, keine Cloud-Synchronisation. Geöffnete und bearbeitete Dateien werden ausschließlich lokal auf deinem Gerät verarbeitet.

Für wen ist die App? Für alle, die regelmäßig .md-Dateien bekommen oder verwalten (Notizen, READMEs, technische Doku, Protokolle) und sie schnell und sauber lesen und ab und zu bearbeiten wollen, ohne einen vollen Editor zu öffnen.
```
(ohne Gedankenstriche; nur Bindestriche in zusammengesetzten Wörtern)

### Schlüsselwörter / Keywords (max. 100 Zeichen) — 1.1

```
markdown,editor,bearbeiten,reader,leser,notizen,readme,text,dokument,tabelle,code,offline,vorschau
```
(98 Zeichen — „md" und „viewer" raus, weil im App-Namen schon indexiert; „editor" und „bearbeiten" neu für die Editier-Funktion)

### Kategorie — 1.1

Unverändert (Primär: Produktivität, Sekundär optional: Dienstprogramme). Die
Bearbeiten-Funktion erlaubt weiterhin die Altersfreigabe 4+ (kein UGC im Sinne
von geteilten/öffentlichen Inhalten — rein lokale Dateibearbeitung).

---

## Version 1.0 — Originaltexte (Referenz)

## App-Name (max. 30 Zeichen)

```
md Viewer
```
(9 Zeichen)

## Untertitel / Subtitle (max. 30 Zeichen)

```
Reiner Markdown-Betrachter
```
(26 Zeichen)

Alternative, falls ein zweiter Test gewünscht ist:
```
Schnell. Fokussiert. Privat.
```
(29 Zeichen)

## Werbetext / Promotional Text (max. 170 Zeichen, jederzeit ohne neues Review änderbar)

```
Fokussierter, werbefreier Markdown-Viewer: .md-Datei öffnen, sofort schön formatiert lesen — Tabellen, Code, Listen. Kein Editor, keine Ablenkung.
```
(146 Zeichen)

## Beschreibung (max. 4000 Zeichen)

```
md Viewer macht genau eine Sache richtig gut: Markdown-Dateien lesbar anzeigen.

Kein Editor. Kein Datei-Browser. Kein Konto. Keine Cloud. Kein Tracking. Öffne eine .md-Datei über die Dateien-App oder das Teilen-Menü — md Viewer zeigt sie sofort schön formatiert an: Überschriften, Listen, Tabellen, fett/kursiv, Codeblöcke mit Syntax-Hervorhebung und Zitate. Kein Rohtext, keine Symbole zum Entziffern.

WARUM SO REDUZIERT?

Weil die meisten Markdown-Viewer heute vollwertige Editoren mit Dateiverwaltung, Cloud-Sync und Menüs sind — praktisch, aber überladen, wenn man einfach nur eine Datei lesen will, die einem gerade geschickt wurde. md Viewer macht bewusst nichts anderes. Datei antippen, lesen, fertig.

FUNKTIONEN

• Öffnen über "Öffnen mit" in der Dateien-App oder direkt aus dem Teilen-Menü (z. B. aus Mail-Anhängen oder AirDrop) — die Teilen-Erweiterung zeigt das Dokument sofort formatiert an, ohne die App zu wechseln
• Sauberes Markdown-Rendering: Überschriften, Listen, Aufgabenlisten, Tabellen (horizontal scrollbar), Codeblöcke mit Syntax-Hervorhebung, Zitate, Links, Bilder
• Volle Unicode-Unterstützung: Emoji, arabische und hebräische Schrift (rechts-nach-links), chinesische, japanische und koreanische Zeichen
• Unterstützt Dynamic Type und VoiceOver
• Automatisches Dark Mode / Light Mode
• Läuft komplett offline, keine Netzwerkzugriffe im Code

DATENSCHUTZ

md Viewer erhebt keinerlei Daten. Keine Analyse-Software, kein Tracking, kein Konto, keine Cloud-Synchronisation. Geöffnete Dateien werden ausschließlich lokal auf deinem Gerät verarbeitet.

Für wen ist die App? Für alle, die regelmäßig .md-Dateien bekommen oder verwalten — Notizen, READMEs, technische Doku, Protokolle — und sie einfach nur schnell und sauber lesen wollen, ohne einen vollen Editor zu öffnen.
```
(1.664 Zeichen — deutlich unter dem 4000-Limit, Puffer für spätere Ergänzungen)

## Schlüsselwörter / Keywords (max. 100 Zeichen, kommagetrennt, keine Leerzeichen nach Komma)

```
markdown,md,viewer,reader,leser,text,dokument,tabelle,code,notizen,offline,privat,readme
```
(88 Zeichen)

## Kategorie

- **Primär:** Produktivität (Productivity)
- **Sekundär (optional):** Dienstprogramme (Utilities)

## Altersfreigabe

4+ — keine anstößigen Inhalte, alle Fragebogen-Punkte mit "Nein"/"Keine" beantwortbar (kein UGC, keine Werbung, keine Gewalt, kein Glücksspiel etc.)

## Copyright

```
© 2026 Eric Bertrand
```

## Support-URL

```
https://k8pynbhkrh-debug.github.io/md-Viewer/
```
(dieselbe Seite dient auch als Marketing-URL und Privacy-Policy-URL)

## Datenschutz-Fragebogen (App Privacy)

Bei allen Kategorien **"Nicht erfasst"** — die App hat keinen Netzwerkzugriff und sammelt nichts. Siehe `Projektplan-Markdown-Viewer.md` Abschnitt 2 für die Begründung.

## Exportkontrolle (bei Einreichung abgefragt)

Frage "Verwendet die App Verschlüsselung?" → **Nein** (nur Standard-iOS-Transportverschlüsselung, die nicht zählt).

---

## App Icon — final

`AppIcon.appiconset` enthält das finale Icon (Light/Dark/Tinted, 1024×1024, Primary ohne Alpha-Kanal): weiße Fläche, schwarzes Dokument-Glyph mit „MD" und Unterstrich. Erzeugt aus Erics Vorlage `App Icon.png` (Repo-Wurzel) — vollflächig zugeschnitten, ohne vorgerenderte Ecken/Schatten/Glow (die Apple ablehnt).

## Screenshots — vorhanden

In `App-Store-Screenshots/` (iPhone 6,9″: 1320×2868, iPad 13″: 2064×2752 — exakt Apples aktuelle Pflichtgrößen, geprüft per Pixelmaß). Light Mode, im Simulator (iPhone 17 Pro Max / iPad Pro 13″) aufgenommen. iPhone- und iPad-Set am 29.08.2026 komplett neu erzeugt (aktueller Build, saubere Statusleiste 09:41 / voller Akku / WLAN):

Reihenfolge (identisch für iPhone und iPad, je 8) — „Öffnen mit" an Position 1 (Einstieg in die App), der neue **Bearbeiten**-Screenshot an Position 2, damit die Editier-Funktion im Store sofort sichtbar ist:

- `01-oeffnen-mit.png` — „Öffnen mit → md Viewer" in der Dateien-App (Ordner „Downloads", Listenansicht). Zeigt den Einstieg in die App. Am 29.08.2026 im Simulator neu aufgenommen (iPhone **und** iPad, nativ, Light Mode, saubere Statusleiste, aktuelles App-Icon in der App-Liste) — ersetzt beim iPhone das alte hochskalierte Gerätefoto mit dem veralteten blauen Icon.
- `02-bearbeiten.png` — **NEU (1.1)**: Editor-Modus mit eingeblendeter Tastatur (inkl. Vorschlagszeile), monospace-Rohtext, Toolbar mit Auge (Vorschau), Kreispfeil (Zurücksetzen) und **rotem Haken** (Speichern/Überschreiben). Am 02.09.2026 im Simulator aufgenommen (Startargument `-mdviewerScreenshotEdit` `#if DEBUG`, Software-Tastatur per Cmd+K).
- `03-empty-state.png` — Startbildschirm mit Hinweis „Öffne über Teilen oder die Dateien-App" + Datenschutz-Link
- `04-uebersicht.png` — Dokument mit Überschriften, Aufgabenliste, Tabelle (Status-Emoji), Zitat, Links
- `05-tabelle.png` — breite 7-Spalten-Tabelle (horizontal scrollbar) + Kennzahlen-Tabelle
- `06-code.png` — Codeblöcke mit Syntax-Hervorhebung (Swift, Python, Shell, JSON)
- `07-sprachen.png` — Emoji (farbig), Arabisch/Hebräisch (RTL), CJK, Kyrillisch, Devanagari, Thai, Mathe-Symbole
- `08-teilen-extension.png` — die Teilen-Erweiterung zeigt ein geteiltes Dokument direkt im Teilen-Menü formatiert an („Fertig"-Blatt). Am 30.08.2026 im Simulator aufgenommen (iPhone + iPad).

Beispieldateien: `App-Store-Screenshots/demo-dokumente/` (reiner Show-Content, jetzt im Repo, damit ein Screenshot-Lauf reproduzierbar ist). Der Text füllt auf iPhone wie iPad die volle Breite (~24 pt Rand); MarkdownUI würde sonst auf die natürliche Inhaltsbreite schrumpfen und links kleben.

Der Kontextmenü-Flow für `06-oeffnen-mit.png` wurde manuell im Simulator geklickt (synthetische Klicks sind hier unzuverlässig): Demo-Dateien nach `<md-Viewer-Container>/Documents/Downloads/` legen (erscheint über `UIFileSharingEnabled` als „Auf meinem iPhone/iPad → md Viewer → Downloads"), Dateien-App → gedrückt halten → „Öffnen mit".
