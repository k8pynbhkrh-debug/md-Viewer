# Kritische Prüfung: App-Store-Konformität, DSGVO, rechtliche Risiken

Stand: 20.08.2026 · Diese Prüfung basiert auf aktuell recherchierten Apple-Richtlinien und deutschem Recht (Stand August 2026), ersetzt aber keine Rechtsberatung im Einzelfall.

## 1. Größtes Risiko: Guideline 4.2 "Minimum Functionality"

Das ist der Punkt, bei dem ich am meisten Vorsicht empfehle. Apple lehnt Apps ab, die "keine ausreichend andere Erfahrung als eine Web-Browsing-Erfahrung" bieten oder schlicht zu simpel sind, um als eigenständiges Produkt zu gelten. Unsere App macht bewusst nur eine einzige Sache — genau das ist konzeptionell die Stärke der App, aber auch der Punkt, an dem ein Reviewer im Zweifel "zu wenig App" sehen könnte.

Wichtig zur Einordnung: Das Kernrisiko unter 4.2 sind vor allem Web-View-Wrapper (Apps, die nur eine Website in einer Box zeigen). Das trifft auf uns nicht zu — wir bauen eine echte native SwiftUI-App mit eigenem Rendering, keine Webview. Das reduziert das Risiko schon deutlich. Trotzdem sollten wir das Risiko nicht ignorieren, sondern aktiv entschärfen:

- **Store-Beschreibung so formulieren, dass die Absicht klar wird.** Nicht "macht nichts" verkaufen, sondern die bewusste Reduktion als Feature: "Ein fokussierter, werbefreier Markdown-Viewer für Leute, die .md-Dateien einfach nur lesen wollen — kein Editor, keine Ablenkung." Das nimmt dem Reviewer den Eindruck von "unfertiger App".
- **Native Qualität sichtbar machen, ohne UI hinzuzufügen:** Dark/Light Mode (kommt mit SwiftUI automatisch), Dynamic Type/VoiceOver-Unterstützung (Barrierefreiheit — kostet uns kaum Aufwand, zeigt aber "echte" App-Qualität), sauberes Verhalten bei Rotation/verschiedenen Displaygrößen (iPhone/iPad).
- **Optionale, risikoarme Erweiterung, die ich empfehlen würde:** Die App zusätzlich als Ziel im **Share Sheet** registrieren (z. B. für .md-Anhänge aus Mail oder AirDrop), nicht nur über "Öffnen mit" in der Dateien-App. Das ist technisch eine kleine Ergänzung (eine Extension oder `NSExtensionActivationRule`), verstößt nicht gegen "kein eigenes Menü" (es bleibt ja derselbe Viewer-Screen), erhöht aber den wahrgenommenen Nutzwert deutlich. Ich würde das als Plan-B in der Tasche behalten, falls die App beim ersten Review als "zu simpel" zurückkommt — muss nicht von Anfang an rein.
- **Realistische Erwartung:** Auch mit allen Vorkehrungen ist ein Reject unter 4.2 bei so einer minimalistischen App nicht auszuschließen. Apples Reviewer haben Ermessensspielraum. Falls es passiert, ist die Standard-Reaktion ein Einspruch über App Store Connect mit Verweis auf den klaren Nutzenfall — das ist normal und kein Drama, sollte aber im Zeitplan als möglicher zusätzlicher Tag eingeplant werden.

## 2. Privacy Manifest (PrivacyInfo.xcprivacy)

Apple verlangt seit 2024 für Apps, die bestimmte "Required Reason APIs" nutzen (u. a. Dateizeitstempel, Speicherplatz-Abfragen, UserDefaults, Systemstartzeit, aktive Tastatur), eine explizite Deklaration in einer `PrivacyInfo.xcprivacy`-Datei. Fehlt sie trotz Nutzung dieser APIs, blockiert App Store Connect die Einreichung mit einer klaren Fehlermeldung — kein Show-Stopper, aber ein Punkt, den wir vorher sauber machen sollten statt bei der Einreichung zu stolpern.

Für unsere App konkret: Sobald wir Dateimetadaten lesen (z. B. um Dateigröße vor dem Öffnen zu prüfen, was ich für die Fehlerbehandlung "Datei zu groß" ohnehin vorgesehen hatte), zählt das als "File Timestamp API" bzw. vergleichbare Kategorie. Meine Empfehlung: Wir bauen die Manifest-Datei von Anfang an mit ein (dauert als eigener Schritt nur wenige Minuten), unabhängig davon ob sie technisch zwingend nötig ist — sie deklariert dann einfach "keine Datensammlung, kein Tracking", was auch als Beleg für den App-Privacy-Fragebogen später nützlich ist.

## 3. Datenschutzerklärung (Pflicht — unabhängig von der DSGVO-Frage)

Das ist unabhängig davon zu sehen, ob die App überhaupt personenbezogene Daten verarbeitet: **Apple verlangt für jede App im App Store Connect eine funktionierende Privacy-Policy-URL** (Guideline 5.1.1), auch wenn dort nur steht "diese App erhebt keinerlei Daten". Ohne diese URL lässt sich die App gar nicht erst einreichen. Das ist technisch kein Aufwand (eine einfache Textseite reicht, z. B. per GitHub Pages aus genau diesem Repo gehostet — kostenlos, keine zusätzliche Infrastruktur), aber ein Schritt, den wir in den Phasenplan mit aufnehmen sollten, bevor wir bei Phase 7 stehen und merken, dass die URL fehlt.

## 4. DSGVO-Risiko selbst: real gering

Die App verarbeitet nach aktuellem Konzept keine personenbezogenen Daten (kein Netzwerkzugriff im Code, keine Analyse-/Tracking-SDKs, keine Accounts, keine Cloud-Synchronisation). Damit ist das DSGVO-Risiko der App selbst sehr gering — es gibt schlicht keine Verarbeitung, die eine Rechtsgrundlage bräuchte. Zwei Dinge trotzdem im Hinterkopf behalten:

- **Apple selbst** sammelt als eigener Verantwortlicher gewisse technische Daten (Absturzberichte, falls Du sie über Xcode Organizer/App Store Connect einsiehst, App-Store-Analytics). Das betrifft uns als Entwickler nicht direkt haftungsrechtlich, sollte aber in der Datenschutzerklärung kurz erwähnt werden ("Apple erhebt ggf. aggregierte, anonyme Nutzungsstatistiken über den App Store — siehe Apples eigene Datenschutzerklärung").
- **Falls wir später doch eine dritte Bibliothek einbauen** (z. B. für Absturzberichte oder Analytics), ändert sich diese Einschätzung sofort — dann bräuchten wir eine echte Datenschutzprüfung der jeweiligen Bibliothek. Für den aktuellen Plan (nur swift-markdown-ui als reine Rendering-Library ohne Netzwerkzugriff) ist das kein Thema.

## 5. Impressumspflicht (Deutschland) — rechtliche Grauzone, aber günstige Absicherung möglich

Hier ist die Rechtslage tatsächlich nicht ganz eindeutig, und ich will das nicht als "sicher unnötig" verkaufen, nur weil es bequemer wäre. Nach dem Digitale-Dienste-Gesetz (Nachfolger des TMG) greift die Impressumspflicht grundsätzlich für "geschäftsmäßige" Angebote — das ist nicht zwingend gleichbedeutend mit "kostenpflichtig" oder "gewerblich" im engeren Sinn; auch ein dauerhaft, planmäßig im App Store öffentlich angebotenes kostenloses Produkt kann je nach Auslegung darunterfallen, während ein rein privates Projekt ohne jede Außenwirkung typischerweise ausgenommen ist. Da unsere App aber öffentlich im App Store für jeden verfügbar sein soll, bewegen wir uns nicht mehr im eindeutig privaten Bereich.

Meine Empfehlung: **Ein Impressum kostet uns fast nichts und schließt das Risiko komplett aus** (Name, Kontakt-E-Mail reichen im Kern; App Store Connect verlangt ohnehin eine Support-URL, die wir für Impressum + Datenschutzerklärung gemeinsam nutzen können, z. B. wieder als GitHub-Pages-Seite). Angesichts von Abmahnrisiken, die in diesem Bereich real vorkommen, sehe ich keinen Grund, hier zu sparen — es ist ein einziger zusätzlicher Textblock auf derselben Seite wie die Datenschutzerklärung.

## 6. Sonstige App-Store-Praxispunkte, die sonst gern übersehen werden

- **Exportkontrolle (Verschlüsselung):** Bei der Einreichung fragt Apple, ob die App Verschlüsselung nutzt. Unsere App tut das nicht (außer Standard-iOS-Transportverschlüsselung, die nicht zählt) — einfache "Nein"-Antwort, aber gut, das vorher zu wissen statt in Phase 7 zu stoppen.
- **UTI-Deklaration für .md:** Es gibt keine von Apple vordefinierte System-UTI für Markdown. Wir müssen eine eigene *importierte* UTI deklarieren (conforming zu `public.plain-text`), die die Endung `.md` beansprucht. Falls andere installierte Apps (iA Writer, Obsidian, Working Copy o. ä.) dieselbe Datei-Endung ebenfalls registriert haben, zeigt iOS bei mehreren Kandidaten einen Auswahldialog statt automatisch zu öffnen — das ist normales iOS-Verhalten, kein Bug und kein Review-Problem, aber gut zu wissen, damit es beim Testen nicht verwirrt.
- **Barrierefreiheit:** Kein Muss für Review-Bestehen, aber VoiceOver-Grundunterstützung ist mit SwiftUI-Standardkomponenten praktisch kostenlos und senkt das 4.2-Risiko zusätzlich (Punkt 1).
- **App-Name/Metadaten dürfen nicht irreführend sein** (Guideline 2.3) — bei einer so klar beschriebenen Funktion kein praktisches Risiko, nur der Vollständigkeit halber erwähnt.

## 7. Angepasster Phasenplan (Ergänzung)

Ich würde die bestehende Phasenliste um zwei kleine, aber notwendige Schritte ergänzen:

- **Neue Phase 2b** (vor dem Store-Eintrag): Datenschutzerklärung + Impressum als einfache GitHub-Pages-Seite aus diesem Repo erstellen — liefert gleichzeitig die von Apple zwingend geforderte Privacy-Policy-URL.
- **Neue Phase 3b:** `PrivacyInfo.xcprivacy` als Teil des Xcode-Projekts anlegen, sobald der Code steht, der Dateimetadaten liest.

## 8. Fazit

Rechtlich/datenschutzrechtlich ist das Projekt in der aktuellen Form unkritisch — die einzig relevante Grauzone ist die Impressumspflicht, und die lässt sich mit einer einzigen zusätzlichen Textseite vollständig absichern. Das eigentliche Risiko liegt nicht bei DSGVO oder Recht, sondern beim App-Store-Review selbst (Guideline 4.2) — dem begegnen wir am besten durch saubere native Umsetzung, eine ehrliche, selbstbewusste Store-Beschreibung und eine Share-Sheet-Erweiterung als Rückfalloption, falls der erste Einreichungsversuch als "zu simpel" zurückkommt.

---

**Offene Entscheidung an Dich:** Sollen wir die Share-Sheet-Erweiterung (Punkt 1) von Anfang an mitbauen, oder erst als Plan B, falls Apple beim Review tatsächlich "zu simpel" sagt?

**Entschieden (30.08.2026): von Anfang an mitgebaut.** Target `ShareExtension` (`com.eribert.md-Viewer.ShareExtension`), `com.apple.share-services`, aktiviert für Markdown-/Text-Anhänge. Rendert das geteilte Dokument direkt im Teilen-Menü (eigenes Blatt mit „Fertig") — kein Umweg über die Haupt-App. Nutzt dieselbe `loadMarkdown(from:)`-Logik (jetzt in `Shared/MarkdownDocument.swift`) und MarkdownUI, aber ohne Highlightr, um im Speicherbudget der Extension zu bleiben. Simulator-Test + Unit-Tests grün. Damit ist das Guideline-4.2-Risiko deutlich kleiner.
