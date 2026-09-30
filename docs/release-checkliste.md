# Test- und Release-Checkliste md Viewer

Vor jedem Upload zu TestFlight bzw. vor dem Einreichen durchgehen. Den Ablauf in App Store
Connect beschreibt der globale Skill `app-store-release`, die Texte stehen in
`App-Store-Texte.md`, die Abhängigkeiten in `docs/dependencies.md`. Gebaut wird mit
`ci/testflight.sh` bzw. `ci/testflight-mac.sh`, eingereicht mit `ci/asc-submit.sh`.

Legende: **[auto]** deckt ein Unit-Test ab (`driver.sh test`). **[UI-Test]** deckt ein
UI-Test ab (Target `md ViewerUITests`, tippt im Simulator). Es reicht jeweils, dass die
Tests grün sind. **[manuell]** heißt: am Gerät bzw. im Simulator ausprobieren.

## 1. Automatische Tests

- [ ] `.claude/skills/run-md-viewer/driver.sh test` ist grün, alle Suiten.
- [ ] UI-Tests grün (`MdViewerUITests`, `ShareExtensionUITests`; laufen im selben
      Schema mit). Die Share-Tests steuern die Dateien-App und brauchen einen Simulator
      mit **Systemsprache Englisch**. Ein eigenes Gerät ist sinnvoll, damit parallele
      Sessions nicht dazwischenfunken:
      `xcrun simctl create "md UITest" "iPhone 17"`, dann
      `xcrun simctl spawn <id> defaults write -g AppleLanguages -array en` und neu booten.
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
- [ ] **[UI-Test]** Startbildschirm → „Ordnerzugriffe": Liste zeigt nur Ordnernamen,
      Wischen entfernt einen Ordner, „Alle entfernen" fragt nach, leert die Liste und
      bleibt nach einem Neustart leer. iPhone mit offenem Dokument: erreichbar über die
      Dokumentliste.
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
- [ ] **[auto]** fetch, XHR und `<img>` auf eine https-Adresse werden von der CSP der
      Diagrammseite blockiert (Laufzeit-Test, auch als Mac Catalyst).
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
- [ ] **[UI-Test]** Bearbeiten → Speichern schreibt die Datei, die Vorschau zeigt den
      neuen Text.
- [ ] **[UI-Test]** Speichern in einen schreibgeschützten Ordner: Fehlermeldung, der
      getippte Text bleibt im Editor erhalten.
- [ ] **[manuell]** „Als .md speichern" und „Neues Dokument aus Text": Dialog abbrechen
      lässt den Entwurf unverändert. Speichern in iCloud Drive und „Auf meinem iPhone"
      funktioniert.
- [ ] **[auto]** Datei während des Bearbeitens gelöscht: Speichern legt sie neu an, der
      Text geht nicht verloren (`saveMarkdown` „creates the file if it does not exist yet").
- [ ] **[manuell]** Datei während des Bearbeitens in der Dateien-App umbenennen, dann
      speichern: kein Datenverlust.
- [ ] **[manuell]** Undo/Redo nach Speichern und Zurücksetzen verhält sich wie erwartet.

## 7. Share Extension

Alle Punkte per **[UI-Test]** (`ShareExtensionUITests`: Dateien-App → lange drücken →
Teilen → md Viewer):

- [ ] Normale Datei teilen: Inhalt wird angezeigt.
- [ ] Leere Datei teilen: Hinweis „leer", kein Absturz.
- [ ] Datei über 5 MB teilen: Hinweis „zu groß".
- [ ] Datei mit ungültigem UTF-8 (Latin-1-Text) teilen: Hinweis zur Kodierung.
- [ ] Sehr langes Dokument (4,5 MB) teilen: Vorschau lädt, die Extension bleibt offen.
      **Bekannter Fehler T-2026-328:** Das Blatt bleibt leer. Der Test ist bis zur Lösung
      mit `XCTExpectFailure` markiert.
- [ ] Dokument mit externem Bild teilen: Platzhalter „wird nicht geladen", den auch
      VoiceOver vorliest.

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
