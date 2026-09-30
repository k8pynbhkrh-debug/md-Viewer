# Test- und Release-Checkliste md Viewer

Vor jedem Upload zu TestFlight bzw. vor dem Einreichen durchgehen. Den Ablauf in App Store
Connect beschreibt der globale Skill `app-store-release`, die Texte stehen in
`App-Store-Texte.md`, die Abhängigkeiten in `docs/dependencies.md`. Gebaut wird mit
`ci/testflight.sh` bzw. `ci/testflight-mac.sh`, eingereicht mit `ci/asc-submit.sh`.

Legende: **[auto]** deckt ein Unit-Test ab (`driver.sh test`). Es reicht, dass die Tests
grün sind. **[manuell]** heißt: am Gerät bzw. im Simulator ausprobieren.

## 1. Automatische Tests

- [ ] `.claude/skills/run-md-viewer/driver.sh test` ist grün, alle Suiten.
- [ ] Build ohne neue Warnungen: iOS-Simulator und Mac Catalyst.

## 2. Bilder (Image-Loader)

- [ ] **[auto]** Relative Bilder ohne Ordnerfreigabe zeigen „Ordner wählen". Mit Freigabe
      erscheint das Bild (`MarkdownImageLoaderTests`).
- [ ] **[auto]** http/https-Bilder werden nie geladen, es erscheint der Platzhalter
      „Externes Bild".
- [ ] **[auto]** Große Bilder werden auf max. 4096 px (längere Seite) verkleinert.
- [ ] **[auto]** data-URI über 10 MB Nutzlast wird abgewiesen. Kaputtes Base64 und
      Nicht-Bild-Daten ergeben einen Platzhalter, keinen Absturz.
- [ ] **[manuell]** Dokument mit Bild in Unterordner, Bild mit Leerzeichen im Namen und
      fehlendem Bild: Jeder Fall zeigt sichtbar Bild oder Platzhalter, keine stille Lücke.
- [ ] **[manuell]** Dokument mit sehr großem Bild (z. B. 12.000 px) bleibt flüssig
      scrollbar.

## 3. Ordnerzugriffe

- [ ] **[auto]** Eine doppelte Freigabe desselben Ordners erzeugt nur einen Eintrag
      (`ImageFolderAccessTests`).
- [ ] **[auto]** Nach dem Entfernen (einzeln/alle) löst der Ordner nicht mehr auf, auch
      nicht nach einem Neustart.
- [ ] **[auto]** Freigaben gelöschter Ordner werden bereinigt. Alte Einträge mit
      vollem Pfad werden auf den Ordnernamen umgestellt.
- [ ] **[manuell]** Startbildschirm → „Ordnerzugriffe": Liste zeigt nur Ordnernamen,
      Wischen entfernt einen Ordner, „Alle entfernen" fragt nach und leert die Liste.
- [ ] **[manuell]** Mac: App-Menü → „Ordnerzugriffe …" funktioniert mit und ohne offenes
      Dokument. Das Entfernen eines Ordners lässt dessen Bilder im offenen Dokument
      sofort zu „Ordner wählen" wechseln.

## 4. Mermaid

- [ ] **[auto]** Gültiges Diagramm rendert. Fehlerhaftes Diagramm zeigt Codeblock
      mit „Diagramm konnte nicht gerendert werden" (`MermaidRendererTests`).
- [ ] **[auto]** Quelltext über 20.000 Zeichen und Grafik über 4096 pt ergeben den
      Codeblock mit „Diagramm zu groß".
- [ ] **[auto]** Bleibt die Antwort aus, greift der Timeout. Danach rendert das nächste
      Diagramm wieder, die Sperre hängt nicht.
- [ ] **[auto]** Navigationsversuche aus der Seite (https, file) werden abgebrochen. Der
      Harness nutzt `securityLevel: 'strict'` und gibt keinen Fehlertext weiter.
- [ ] **[manuell]** Demo-Dokument `App-Store-Screenshots/demo-dokumente/de/Diagramme-Bilder.md`
      in Hell und Dunkel: Diagramme scharf, Farben passend.
- [ ] **[auto, Mac]** Mermaid-Tests zusätzlich als Mac Catalyst laufen lassen. Der
      iOS-Simulator merkt nicht, wenn WebKit in der Mac-Sandbox nicht startet:
      `xcodebuild test -project "md Viewer/md Viewer.xcodeproj" -scheme "md Viewer" -destination "platform=macOS,variant=Mac Catalyst" -only-testing:"md ViewerTests/MermaidRendererTests"`
- [ ] **[manuell, Mac]** Im TestFlight-Build ein Dokument mit Diagramm öffnen: Die Grafik
      erscheint nach wenigen Sekunden, kein „braucht zu lange". Voraussetzung ist die
      Berechtigung `com.apple.security.network.client`.
- [ ] **[manuell]** Nach einem Mermaid-Update: SHA-256 in `docs/dependencies.md`
      nachtragen und Abschnitt 4 komplett durchgehen.

## 5. Privacy Manifest (Smoke-Check)

- [ ] **[auto]** Test-Suite „Privacy manifest" ist grün.
- [ ] **[manuell]** Release-Archiv → Xcode Organizer → „Generate Privacy Report":
      Haupt-App zeigt „User Defaults — CA92.1", keine Tracking-Domains und kein
      Tracking. Die Share Extension ist konsistent dazu.
- [ ] **[manuell]** App Privacy in App Store Connect steht weiter auf „Keine Daten
      erfasst".

## 6. Schreiben und Export (Fehlerpfade)

- [ ] **[manuell]** Datei in iCloud Drive bearbeiten und speichern. Danach in der
      Dateien-App öffnen: Inhalt ist aktuell.
- [ ] **[manuell]** Schreibgeschützte Datei (z. B. aus einem geteilten Ordner mit
      Leserecht) speichern: verständliche Fehlermeldung, Entwurf bleibt erhalten.
- [ ] **[manuell]** „Als .md speichern" und „Neues Dokument aus Text": Dialog abbrechen
      lässt den Entwurf unverändert. Speichern in iCloud Drive und „Auf meinem iPhone"
      funktioniert.
- [ ] **[manuell]** Datei während des Bearbeitens in der Dateien-App löschen oder
      umbenennen, dann speichern: Fehler statt stiller Datenverlust.
- [ ] **[manuell]** Undo/Redo nach Speichern und Zurücksetzen verhält sich wie erwartet.

## 7. Share Extension

- [ ] **[manuell]** Leere Datei teilen: Hinweis „leer", kein Absturz.
- [ ] **[manuell]** Datei über 5 MB teilen: Hinweis „zu groß".
- [ ] **[manuell]** Datei mit ungültigem UTF-8 (z. B. Latin-1-Text) teilen: Hinweis zur
      Kodierung.
- [ ] **[manuell]** Sehr langes Dokument (knapp 5 MB) teilen: Vorschau lädt, bleibt
      scrollbar, die Extension wird nicht vom System beendet.
- [ ] **[manuell]** Dokument mit externen Bildern teilen: Platzhalter, kein Abruf.

## 8. Gerätecheck

- [ ] **iPhone** (echtes Gerät): Öffnen über Dateien und Teilen, Bearbeiten, Speichern,
      Bilder, Mermaid, Ordnerzugriffe.
- [ ] **iPad**: dasselbe, dazu Querformat und Split View. Wo es Hover gibt: Tastatur
      und Trackpad.
- [ ] **Mac (Catalyst)**: Öffnen per Doppelklick und ⌘O, formatierte bzw. auswählbare
      Vorschau, Menü „Ordnerzugriffe …", Fenster frei skalierbar.
- [ ] Hell/Dunkel sowie Deutsch/Englisch je einmal kurz ansehen.

## 9. Texte und Abschluss

- [ ] Release Notes und Review Notes in `App-Store-Texte.md` passen zu dem, was
      tatsächlich im Build ist.
- [ ] Datenschutzseite `docs/index.html` ist aktuell (geht mit dem Merge auf `main` live).
- [ ] Build-Nummer erhöht. Einreichen erst nach ausdrücklichem Ja mit
      `ci/asc-submit.sh <id>` (vorher `--dry-run`).
