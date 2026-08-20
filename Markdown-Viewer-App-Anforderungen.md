# Projekt: Reiner Markdown-Viewer für iOS

## Ziel
Eine minimalistische iOS-App, die ausschließlich Markdown-Dateien (.md) lesbar anzeigt — kein Editor, kein Menü, keine Cloud.

---

## Funktionale Anforderungen

- **Kein eigenes UI/Menü/Startbildschirm.** Die App hat keinen Hauptbildschirm, keine Einstellungen, keine Liste "Zuletzt verwendet".
- **Einziger Zweck:** Als Standard-App ("Öffnen mit") für .md-Dateien bei iOS registrierbar sein.
- **Ablauf für den Nutzer:**
  1. .md-Datei in der Dateien-App antippen
  2. App öffnet sich automatisch und zeigt den Inhalt sofort schön formatiert an (Überschriften, Listen, Tabellen, fett/kursiv, Codeblöcke — kein Rohtext/Code-Ansicht)
  3. Um die nächste Datei zu sehen: App schließen, zurück in die Dateien-App, nächste Datei antippen
- **Eine Ausnahme von "kein UI":** Apple verlangt bei vollflächig geöffneten Apps mindestens ein Bedienelement zum Schließen (Zurück-Pfeil oder Schließen-Button) — reine Nutzerfreundlichkeits-/Review-Vorgabe von Apple, kein zusätzliches Feature.

## Sprache / Lokalisierung

- **Keine Lokalisierung nötig.** Da die App keine eigene Bedienoberfläche mit Menütexten hat, gibt es nichts zu übersetzen.
- Der Dateiinhalt selbst wird unabhängig von der Sprache einfach gerendert (Markdown-Syntax ist sprachunabhängig — `#`, `*`, `-` funktionieren identisch in jeder Sprache).
- iOS bringt automatisch passende Systemschriften für alle Sprachen mit (inkl. asiatische Zeichen, Umlaute, Sonderzeichen).

## Datenschutz-Anforderungen

- Keine Anmeldung
- Keine Cloud-Speicherung
- Keine Datenerfassung
- Keine Nutzereingaben erforderlich
- Reiner, lokaler Viewer

---

## Was Claude übernehmen kann

- Kompletten Swift/SwiftUI-Quellcode schreiben (Markdown-Rendering, Dateityp-Registrierung/Info.plist-Konfiguration, Schließen-Button)
- Texte für die App-Store-Seite formulieren (Beschreibung, Keywords)
- Datenschutzangaben für den App-Store-Fragebogen vorformulieren
- Bei Bugs/Anpassungen im Code helfen (bei Fehlermeldungen aus Xcode)

## Was der Nutzer (oder jemand mit Mac) übernehmen muss

- Zugriff auf einen **Mac** (Xcode gibt es nur für macOS)
- Xcode installieren (kostenlos, ca. 10–15 GB)
- Code in Xcode kompilieren, testen, ggf. Fehler beheben
- Einen **Apple Developer Account** anlegen (99 €/Jahr, Pflicht für Store-Veröffentlichung — unabhängig davon, ob die App kostenlos oder kostenpflichtig ist)
- App-Store-Eintrag anlegen: Screenshots, Beschreibung, App-Icon
- Einreichung bei Apple über App Store Connect
- Auf Apples Review-Feedback reagieren, falls Änderungen verlangt werden

---

## Ablauf Schritt für Schritt

| Schritt | Wer macht's | Dauer/Kosten |
|---|---|---|
| 1. Anforderungen festlegen | Gemeinsam | erledigt |
| 2. Code schreiben | Claude | ~1 Sitzung |
| 3. Mac + Xcode besorgen | Nutzer | einmalig |
| 4. Apple Developer Account anlegen | Nutzer | 99 €/Jahr |
| 5. Code in Xcode öffnen & kompilieren | Nutzer (Claude hilft bei Fehlern) | 1–2 Stunden |
| 6. Auf eigenem iPhone testen | Nutzer | sofort, kostenlos |
| 7. App-Store-Eintrag anlegen | Nutzer (Claude liefert Texte) | 1–2 Stunden |
| 8. Bei Apple einreichen | Nutzer | im Jahresbeitrag enthalten |
| 9. Apple-Review abwarten | Apple | 1–3 Tage |
| 10. App ist live | — | fertig |

---

## Kosten im Überblick

- **Apple Developer Account:** 99 €/Jahr (Pflicht für Veröffentlichung im Store)
- **Mac:** falls nicht vorhanden — Kauf, Leihen, oder Mac in der Cloud (z. B. MacInCloud, ca. 30 €/Monat)
- **Icon-Design:** selbst erstellbar oder günstig beauftragen

## Wichtiger Hinweis: Nur für den Eigengebrauch

Falls die App **nur auf dem eigenen iPhone** laufen soll (keine Veröffentlichung für andere):

- Kein 99-€-Account nötig, nur eine kostenlose Apple-ID
- Kein Store-Review nötig
- Installation direkt über Xcode aufs eigene Gerät
- Hält sich 7 Tage, danach erneutes Installieren über Xcode nötig (dauert ca. 2 Minuten)

---

## Offene Frage

Hat der Nutzer Zugriff auf einen Mac, oder soll die Lösung auf "nur eigenes iPhone" statt auf Store-Veröffentlichung ausgelegt werden?
