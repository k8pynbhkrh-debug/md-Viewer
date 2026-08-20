# Projektplan: Markdown-Viewer für iOS

Stand: 20.08.2026 · Zielplattform: App Store Veröffentlichung · Mac/Xcode: vorhanden · Repo: lokal unter `/Users/eric/Projekte/md Viewer`, verknüpft mit GitHub (`md-Viewer.git`)

Dieser Plan ersetzt die erste Version vollständig und integriert die Ergebnisse der rechtlichen/App-Store-Prüfung (siehe `Rechtliche-Pruefung-und-App-Store-Risiken.md` im selben Ordner) direkt in den Ablauf. Entscheidung dazu: Die Share-Sheet-Erweiterung wird von Anfang an mitgebaut, nicht erst als Plan B.

---

## 1. Architekturentscheidungen

**a) Markdown-Rendering.** Library **swift-markdown-ui** (MIT-Lizenz, per Swift Package Manager, keine Cloud-/Netzwerkabhängigkeit, keine Telemetrie) statt Eigenbau, da Apples natives `AttributedString(markdown:)` keine Tabellen und keine formatierten Codeblöcke unterstützt.

**b) "Öffnen mit"-Registrierung (Hauptweg).**
- `CFBundleDocumentTypes` in der Info.plist, damit iOS die App als Handler für `.md`-Dateien in der Dateien-App anbietet
- Eigene *importierte* UTI (Apple hat keine System-UTI für Markdown), conforming zu `public.plain-text`, mit Endungszuordnung `.md`
- Zu erwartendes, normales Verhalten: Sind mehrere Apps für `.md` registriert (z. B. iA Writer, Obsidian), zeigt iOS einen Auswahldialog statt automatisch zu öffnen — kein Bug, nur beim Testen nicht verwirren lassen

**c) Share-Sheet-Erweiterung (neu, von Anfang an mit drin).** Zusätzlich zum "Öffnen mit"-Weg wird die App als Ziel im iOS-Share-Sheet registriert, sodass `.md`-Dateien auch direkt aus Mail-Anhängen, AirDrop oder anderen Apps heraus geöffnet werden können, ohne den Umweg über die Dateien-App. Technisch über `NSExtensionActivationRule` in der Haupt-App (kein separates Extension-Target nötig, da wir keinen eigenen UI-Kontext für die Extension brauchen — die Datei wird direkt an die Haupt-App durchgereicht). Zweck: erhöht den wahrgenommenen Nutzwert für den Reviewer (Guideline-4.2-Absicherung) und ist für den Nutzer im Alltag tatsächlich praktisch.

**d) App-Struktur.** Kein Tab-Bar, keine Navigation, kein Onboarding. Einziger Screen: `DocumentView`, der die Datei per `onOpenURL` (Öffnen-mit-Weg) oder aus der Share-Extension-Weitergabe liest und rendert. Schließen-Button oben links (Apple-Pflicht bei vollflächiger App-Übernahme).

**e) Barrierefreiheit als Qualitätsmerkmal (neu).** Dynamic Type und VoiceOver-Grundunterstützung werden von Anfang an mitgezogen — kostet mit SwiftUI-Standardkomponenten kaum Zusatzaufwand, senkt aber zusätzlich das Guideline-4.2-Risiko, weil die App dadurch spürbar "fertiger" wirkt. Dark/Light Mode kommt mit SwiftUI automatisch mit.

**f) Fehlerfälle**, die der Code abfangen muss: Datei nicht lesbar, Datei zu groß, ungültiges Encoding, leere Datei. Statt Crash: einfache Fehlermeldung im selben Screen. (Das Prüfen der Dateigröße vor dem Öffnen ist der Grund, warum wir eine Privacy-Manifest-Datei brauchen — siehe Abschnitt 3.)

## 2. Datenschutz — konkret für den App-Store-Fragebogen

- Keine Netzwerkzugriffe im Code (kein `URLSession`, kein Analytics-SDK, kein Crash-Reporter von Drittanbietern)
- Keine Persistenz außer dem, was iOS selbst cached — "zuletzt geöffnete Datei"-Caching wird bewusst deaktiviert
- App-Privacy-Fragebogen in App Store Connect: bei allen Kategorien "Nicht erfasst"
- Apple selbst erhebt als eigener Verantwortlicher ggf. aggregierte App-Store-Analytics/Absturzberichte — das betrifft uns nicht direkt, wird aber in der Datenschutzerklärung kurz erwähnt

## 3. Neu: Privacy Manifest (`PrivacyInfo.xcprivacy`)

Seit 2024 von Apple verlangt, sobald die App bestimmte "Required Reason APIs" nutzt (u. a. Dateizeitstempel/-metadaten, Speicherplatz-Abfragen). Da wir Dateigröße/-metadaten für die Fehlerbehandlung lesen, betrifft uns das. Wird unabhängig von strikter Notwendigkeit von Anfang an eingebaut — deklariert "keine Datensammlung, kein Tracking" und dient zugleich als Beleg für den App-Privacy-Fragebogen. Ohne diese Datei blockiert App Store Connect sonst die Einreichung mit einer klaren Fehlermeldung, wenn Required-Reason-APIs erkannt werden.

## 4. Neu: Datenschutzerklärung + Impressum (eine gemeinsame Seite)

Apple verlangt für **jede** App eine funktionierende Privacy-Policy-URL (Guideline 5.1.1) — Pflichtfeld bei der Einreichung, unabhängig davon, ob überhaupt Daten erhoben werden. Zusätzlich: Da die App öffentlich im Store steht, ist die Impressumspflicht nach deutschem Recht keine ganz klare "nein"-Antwort (rechtliche Grauzone bei kostenlosen, aber öffentlich angebotenen Apps) — ein Impressum auf derselben Seite schließt dieses Risiko praktisch vollständig aus, bei minimalem Zusatzaufwand.

Umsetzung: Eine einfache statische Seite (Name, Kontakt-E-Mail, Kurz-Impressum + "Diese App erhebt keinerlei Daten"-Datenschutzerklärung), gehostet über **GitHub Pages** direkt aus diesem Repo — kostenlos, keine zusätzliche Infrastruktur, und die URL kann gleichzeitig als Support-URL in App Store Connect verwendet werden.

## 5. Phasenplan (aktualisiert, inkl. neuer Schritte)

| Phase | Inhalt | Wer | Ergebnis |
|---|---|---|---|
| 1 | Architektur final bestätigt (Rendering-Library, Share-Sheet, Barrierefreiheit) | Gemeinsam | ✅ erledigt mit diesem Plan |
| 2 | Xcode-Projekt anlegen, swift-markdown-ui-Package hinzufügen, Info.plist mit Dateityp-/UTI-Registrierung konfigurieren | Claude schreibt Code/Config direkt in den Projektordner, Du öffnest in Xcode | Lauffähiges Grundgerüst |
| 2a *(neu)* | Datenschutzerklärung + Impressum als Seite erstellen, GitHub Pages im Repo aktivieren | Claude erstellt Text + Seite, Du aktivierst GitHub Pages einmalig in den Repo-Einstellungen | Öffentliche Privacy-Policy-URL vorhanden |
| 3 | `DocumentView` + Markdown-Rendering + Fehlerbehandlung (inkl. Dateigrößen-/Metadaten-Check) | Claude | Kernfunktion fertig |
| 3a *(neu)* | `PrivacyInfo.xcprivacy` anlegen, Required-Reason-APIs korrekt deklarieren | Claude | Manifest-Datei im Projekt |
| 3b *(neu)* | Share-Sheet-Erweiterung einbauen (`NSExtensionActivationRule`, Weiterleitung an `DocumentView`) | Claude | App auch aus Mail/AirDrop/Share-Sheet nutzbar |
| 3c *(neu)* | Dynamic Type + VoiceOver-Grundunterstützung auf `DocumentView` prüfen/ergänzen | Claude | Barrierefreiheit gegeben |
| 4 | Auf eigenem iPhone testen: "Öffnen mit"-Weg, Share-Sheet-Weg, Tabellen/Codeblöcke/lange Dateien/Sonderzeichen, Fehlerfälle, VoiceOver-Durchlauf | Du, Claude hilft bei Xcode-Fehlermeldungen | Funktionsfähige, geprüfte App |
| 5 | App Icon + Screenshots + Store-Texte (inkl. selbstbewusster Beschreibung der bewussten Reduktion, siehe Rechtsprüfung Punkt 1) | Claude liefert Texte/Vorschläge, Du/Designer macht Icon | Store-Material komplett |
| 6 | Apple Developer Account anlegen (99 €/Jahr) | Du | Account aktiv |
| 7 | App Store Connect Eintrag: Privacy-Policy-URL, Support-URL, App-Privacy-Fragebogen, Exportkontroll-Frage ("Nein", keine Verschlüsselung), Einreichung | Du, Claude liefert Formulierungen und geht die Fragebogen-Punkte mit Dir durch | Eingereicht |
| 8 | Apple Review abwarten (1–3 Tage) | Apple | — |
| 8a *(neu, nur falls nötig)* | Falls Reject unter Guideline 4.2: Einspruch mit Verweis auf Share-Sheet-Nutzwert + Store-Beschreibung, ggf. erneute Einreichung | Du + Claude | Erneute Prüfung |
| 9 | App ist live | — | fertig |

## 6. Sonstige Punkte aus der Rechtsprüfung, die im Ablauf berücksichtigt sind

- Exportkontrolle: App nutzt keine relevante Verschlüsselung → einfache "Nein"-Antwort bei Einreichung (Phase 7)
- UTI-Konflikte mit anderen installierten Markdown-Apps sind normales iOS-Verhalten, kein Blocker (Phase 4 beim Testen im Hinterkopf behalten)
- Store-Metadaten müssen die Funktion akkurat beschreiben (Guideline 2.3) — bei dieser klar umrissenen App unkritisch, aber in Phase 5 mit einplanen

## 7. Offene Punkte vor Codebeginn

- App-Name und Bundle-Identifier (z. B. `com.deinname.mdviewer`) für die Xcode-Projektanlage
- Minimale unterstützte iOS-Version (z. B. iOS 16+)
- Für die Datenschutz-/Impressum-Seite (Phase 2a): welcher Name/welche Kontakt-E-Mail sollen dort stehen?

---

**Nächster Schritt:** Sobald die drei offenen Punkte in Abschnitt 7 stehen, starte ich mit Phase 2.
