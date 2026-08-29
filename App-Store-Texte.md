# App Store Connect — Texte für "md Viewer"

Stand: 25.08.2026 · Alle Felder unten sind copy-paste-fertig für App Store Connect. Zeichenlimits sind Apples aktuelle Vorgaben (Stand August 2026).

---

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

• Öffnen über "Öffnen mit" in der Dateien-App oder direkt aus dem Teilen-Menü (z. B. aus Mail-Anhängen oder AirDrop)
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

- `01-empty-state.png` — Startbildschirm mit Hinweis „Öffne über Teilen oder die Dateien-App" + Datenschutz-Link
- `02-uebersicht.png` — Dokument mit Überschriften, Aufgabenliste, Tabelle (Status-Emoji), Zitat, Links
- `03-tabelle.png` — breite 7-Spalten-Tabelle (horizontal scrollbar) + Kennzahlen-Tabelle
- `04-code.png` — Codeblöcke mit Syntax-Hervorhebung (Swift, Python, Shell, JSON)
- `05-sprachen.png` — Emoji (farbig), Arabisch/Hebräisch (RTL), CJK, Kyrillisch, Devanagari, Thai, Mathe-Symbole
- `06-oeffnen-mit.png` — „Öffnen mit → md Viewer" in der Dateien-App (Ordner „Downloads", Listenansicht). Zeigt den Einstieg in die App. Am 29.08.2026 im Simulator neu aufgenommen (iPhone **und** iPad, nativ, Light Mode, saubere Statusleiste, aktuelles App-Icon in der App-Liste) — ersetzt beim iPhone das alte hochskalierte Gerätefoto mit dem veralteten blauen Icon.

Beispieldateien: `App-Store-Screenshots/demo-dokumente/` (reiner Show-Content, jetzt im Repo, damit ein Screenshot-Lauf reproduzierbar ist). Der Text füllt auf iPhone wie iPad die volle Breite (~24 pt Rand); MarkdownUI würde sonst auf die natürliche Inhaltsbreite schrumpfen und links kleben.

Der Kontextmenü-Flow für `06-oeffnen-mit.png` wurde manuell im Simulator geklickt (synthetische Klicks sind hier unzuverlässig): Demo-Dateien nach `<md-Viewer-Container>/Documents/Downloads/` legen (erscheint über `UIFileSharingEnabled` als „Auf meinem iPhone/iPad → md Viewer → Downloads"), Dateien-App → gedrückt halten → „Öffnen mit".
