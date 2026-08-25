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
• Sauberes Markdown-Rendering: Überschriften, Listen, Tabellen (horizontal scrollbar), Codeblöcke, Zitate, Links, Bilder
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

## App Icon — Platzhalter vorhanden

`AppIcon.appiconset` enthält jetzt ein programmatisch generiertes Icon (Light/Dark/Tinted, 1024×1024, kein Alpha-Kanal): blauer Farbverlauf, weiße Karte, "M↓"-Markdown-Mark. Kein KI-Bildmodell in dieser Umgebung verfügbar, daher mit Pillow gezeichnet statt "echt" designt. Reicht zum Archivieren/Testen, ist aber ausdrücklich ein Platzhalter — vor der finalen Einreichung von dir/einem Designer gegenprüfen oder ersetzen lassen.

## Screenshots — vorhanden

In `App-Store-Screenshots/` (iPhone 6,9″: 1320×2868, iPad 13″: 2064×2752 — exakt Apples aktuelle Pflichtgrößen, geprüft per Pixelmaß):

- `01-empty-state.png` — Empty State mit App-Icon-Symbol und Datenschutz-Link
- `02-dokument.png` — offenes Dokument mit Überschriften, Task-Liste, Tabelle (mit Status-Emoji), Codeblock, Zitat

Beide mit derselben Beispieldatei erzeugt (nicht Teil des Repos, da nur Show-Content — bei Bedarf sag Bescheid, dann lege ich sie auch ab). Auf dem iPad nutzt der Inhalt nicht die volle Breite (kein iPad-optimiertes Layout) — funktional korrekt, aber optisch nicht ideal für ein Marketing-Bild; bei Bedarf separat nachbessern.
