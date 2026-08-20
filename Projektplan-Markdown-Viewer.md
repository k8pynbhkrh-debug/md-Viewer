# Projektplan: Markdown-Viewer für iOS

Stand: 20.08.2026 · Zielplattform: App Store Veröffentlichung · Mac/Xcode: vorhanden

Kurz vorweg zu Deiner Frage nach einem Skill: Ich habe keinen fertigen Skill, der "komplettes Projekt durchplanen inkl. Datenschutz, mit mehreren Agenten" als Paket anbietet. Für ein Projekt dieser Größe (eine einzelne, bewusst minimalistische App) würde ein Multi-Agenten-Setup auch eher Overhead erzeugen als helfen — die Arbeit ist im Kern sequenziell (Architektur festlegen → Code schreiben → in Xcode testen), nicht parallelisierbar auf mehrere Gewerke. Ich plane das Projekt deshalb direkt hier als einen zusammenhängenden Plan; wenn wir an den Code gehen, schreibe ich ihn Datei für Datei, damit Du in Xcode jederzeit nachvollziehen kannst, was reinkommt.

---

## 1. Architekturentscheidungen (vor dem Coden zu klären)

**a) Markdown-Rendering.** Apples natives `AttributedString(markdown:)` beherrscht nur Fett/Kursiv/Links/einfache Listen — keine Tabellen, keine Codeblöcke mit Hintergrund, keine verschachtelten Listen zuverlässig. Da die Anforderungen ausdrücklich Tabellen und Codeblöcke verlangen, empfehle ich die Open-Source-Library **swift-markdown-ui** (MIT-Lizenz, per Swift Package Manager einbindbar, keine Cloud-Abhängigkeit, keine Telemetrie) statt Eigenbau. Alternative wäre ein selbstgeschriebener Parser — mehr Aufwand, kein Zusatznutzen für diesen Anwendungsfall.

**b) "Öffnen mit"-Registrierung.** Zwei Apple-Mechanismen sind nötig:
- `CFBundleDocumentTypes` in der Info.plist, damit iOS die App als Handler für `.md`-Dateien anbietet
- `UTImportedTypeDeclarations` für den UTI `net.daringfireball.markdown` (der Standard-UTI für Markdown-Dateien, den auch andere Apps nutzen)

**c) App-Struktur.** Kein Tab-Bar, keine Navigation, kein Onboarding. Einziger Screen: `DocumentView`, der beim Start per `onOpenURL` die übergebene Datei liest und rendert. Schließen-Button oben links (Apple-Pflicht bei App-Übernahme des ganzen Bildschirms) — schließt die App per `exit(0)` oder Rücksprung, je nachdem was Apple aktuell im Review akzeptiert (das prüfe ich beim Coden gegen die aktuellen HIG).

**d) Fehlerfälle**, die der Code abfangen muss: Datei nicht lesbar, Datei zu groß, ungültiges Encoding, leere Datei. Statt Crash: einfache Fehlermeldung im selben Screen.

## 2. Datenschutz — konkret für den App-Store-Fragebogen

Die Anforderungen sagen "keine Datenerfassung" — das lässt sich technisch auch belegen:
- Keine Netzwerkzugriffe im Code (kein `URLSession`, kein Analytics-SDK, kein Crash-Reporter von Drittanbietern)
- Keine Persistenz außer dem, was iOS selbst für "zuletzt geöffnete Datei" cached (das kann und sollte deaktiviert werden)
- App-Privacy-Fragebogen in App Store Connect: bei allen Kategorien ("Kontaktdaten", "Standort", "Nutzungsdaten" etc.) "Nicht erfasst" ankreuzbar — ich formuliere Dir die Begründungstexte, wenn wir bei Schritt 7 sind

## 3. Phasenplan

| Phase | Inhalt | Wer | Ergebnis |
|---|---|---|---|
| 1 | Architektur final abstimmen (Punkt 1 oben, insb. swift-markdown-ui ja/nein) | Gemeinsam | Freigabe |
| 2 | Xcode-Projekt anlegen, Package hinzufügen, Info.plist konfigurieren | Claude schreibt Anleitung + Config, Du führst in Xcode aus | Lauffähiges Grundgerüst |
| 3 | `DocumentView` + Rendering-Logik + Fehlerbehandlung | Claude | Kompletter Quellcode |
| 4 | Auf eigenem iPhone testen (verschiedene .md-Dateien: Tabellen, Codeblöcke, lange Dateien, Sonderzeichen) | Du, Claude hilft bei Fehlermeldungen | Funktionsfähige App |
| 5 | App Icon + Screenshots + Store-Texte | Claude liefert Texte/Vorschläge, Du/Designer macht Icon | Store-Material komplett |
| 6 | Apple Developer Account anlegen (99€/Jahr) | Du | Account aktiv |
| 7 | App Store Connect Eintrag + Privacy-Fragebogen + Einreichung | Du, Claude liefert Formulierungen | Eingereicht |
| 8 | Apple Review abwarten (1-3 Tage), ggf. auf Rückfragen reagieren | Apple / Du+Claude | App live |

## 4. Offene Punkte, die wir vor Phase 2 klären sollten

- Bestätigung: swift-markdown-ui als Rendering-Library ok, oder lieber möglichst wenig Abhängigkeiten (dann Eigenbau mit Einschränkungen bei Tabellen)?
- App-Name und Bundle-Identifier (z.B. `com.deinname.mdviewer`) für die Xcode-Projektanlage
- Minimale unterstützte iOS-Version (z.B. iOS 16+, betrifft welche SwiftUI-APIs nutzbar sind)

## 5. Risiken

- **Apple Review:** Apps mit sehr minimalem UI werden manchmal zurückgewiesen mit der Begründung "zu wenig Funktionalität". Der Schließen-Button und eine klare, einfache Store-Beschreibung ("bewusst minimalistischer Viewer") sollten das absichern — im Zweifel Reaktion auf Rückfrage einplanen.
- **UTI-Konflikte:** Falls bereits andere Apps auf dem Gerät als .md-Handler registriert sind, entscheidet iOS per Auswahldialog — kein Blocker, aber gut zu wissen für den Test in Phase 4.

---

**Nächster Schritt:** Wenn Du mit Punkt 1 (Architektur) und den offenen Punkten in Abschnitt 4 einverstanden bist, starte ich mit Phase 2/3 und schreibe den Code.
