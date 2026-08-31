# Apple App Review — Antwort auf Guideline 2.1 (Information Needed)

Submission ID: 6a374ee4-56f5-4868-a026-ba0e2d84d054 · Version 1.0 (1) · abgelehnt 31.08.2026

## Status

- [x] Notes-Feld ("Anmerkungen") in App Store Connect ausgefüllt und gesichert (31.08.2026)
- [x] TestFlight: interne Gruppe "Intern" angelegt, Eric als Tester eingetragen, Build 1.0 (1) "Bereit zum Testen" (31.08.2026)
- [x] TestFlight-App aufs iPhone geladen, md Viewer installiert
- [x] Bildschirmaufnahme erstellt: `Bildschirmaufnahme md Viewer.MP4` (53 s, iPhone 16 Pro)
- [x] Video komprimiert fuer den Upload: `docs/apple-review-video.mp4` (3,5 MB, gut lesbar) <- DIESE Datei anhaengen
- [x] Antworttext + Anhaenge (`apple-review-video.mp4`, `sample-markdown-files.zip`) im Resolution Center GESENDET (31.08.2026, 13:12)
- [x] Version "Pruefung aktualisieren" + Uebermittlung "Erneut zur App-Pruefung uebermitteln" -> Status "Warten auf Pruefung"
- [ ] Auf Apples neue Entscheidung warten (~24-48h). Ergebnis in ASC -> Vertrieb -> App-Pruefung, bzw. Mail an eric.bertrand90@outlook.de

## Bildschirmaufnahme — was rein muss (~30–60 s, physisches Gerät, aktuelles iOS)

1. App vom Home-Bildschirm starten → Empty State zeigen
2. Zur Dateien-App wechseln, eine `.md`-Datei lange drücken → "Öffnen mit" → "md Viewer" → gerendertes Dokument zeigen (nach unten scrollen: Überschriften, Tabelle horizontal scrollen, Codeblock, RTL/CJK-Abschnitt)
3. Zurück, eine `.md` per Teilen-Menü teilen → "md Viewer" wählen → Share-Extension rendert inline → "Fertig"
4. Kein Ton nötig. Keine Login-/Berechtigungs-Dialoge (die gibt es in der App nicht).

Aufnahme: Einstellungen → Kontrollzentrum → "Bildschirmaufnahme" hinzufügen; im Kontrollzentrum starten. Datei per AirDrop auf den Mac, dann im Resolution Center anhängen.

Beispieldateien zum Anhängen: `App-Store-Screenshots/demo-dokumente/Release-Matrix.md` und `Sprachen & Emoji.md` (oder `Code-Beispiele.md`).

## Antworttext für das Resolution Center (englisch, copy-paste)

---

Thank you for the review. Please find the requested information below; the same details have also been added to the Notes field of the App Review Information section.

**1. Screen recording**
A screen recording captured on a physical iPhone 16 Pro running iOS 26 is attached. It starts with launching the app and shows: the empty state, opening a .md file from the Files app via "Open With", scrolling through the rendered document (headings, a horizontally scrollable table, a syntax-highlighted code block, right-to-left and CJK text), and rendering a shared .md file through the Share Extension. The app has no account registration/login/deletion flow, no paid content or purchases, no user-generated content, and it never prompts for location, contacts, camera or App Tracking Transparency.

**2. Devices and operating systems tested**
- iPhone 16 Pro, iOS 26 (physical device)
- Simulator: iPhone 17 Pro Max (iOS 26), iPad Pro 13-inch (iPadOS 26)

**3. App function and target audience**
md Viewer is a read-only viewer for Markdown (.md / .markdown) files. It has no editor, no file manager, no account, no cloud and no backend. The user opens a Markdown file and the app renders it: headings, lists, task lists, tables, fenced code with syntax highlighting, block quotes, links and images. Target audience: people who regularly receive Markdown files (notes, READMEs, technical documentation, meeting minutes) and want to read them cleanly without opening a full editor. The value is a focused, ad-free, fully offline and private reading experience.

**4. Setup and access instructions**
No setup, no account and no login of any kind are required. To exercise the core features:
- Files app: place a .md file in Files, long-press it, choose "Open With" > "md Viewer". It renders full screen.
- Share sheet: from Mail, AirDrop or Files, share a .md file and pick "md Viewer". The Share Extension renders the document inline (a sheet with a "Done" button).
- Launching the app directly shows an empty state describing these two entry points plus a link to the privacy policy.
Sample Markdown files are attached to this message.

**5. External services, tools and platforms**
None. The app has no server, no analytics, no tracking, no authentication and no payment processing. It bundles only open-source rendering libraries, all running entirely on-device: swift-markdown-ui and swift-cmark (parsing and rendering), Highlightr (code syntax highlighting), and NetworkImage (a transitive dependency of swift-markdown-ui). The only situation in which the app performs a network request is when a Markdown file opened by the user references an image by a remote URL (standard Markdown image rendering). No user data is transmitted in any case. No AI services are used.

**6. Regional differences**
None. The app behaves identically in all regions. There is no region-specific content or functionality.

**7. Regulated industry / protected third-party material**
Not applicable. The app only displays files supplied by the user and contains no protected third-party content. All bundled libraries are MIT-licensed open source.

---
