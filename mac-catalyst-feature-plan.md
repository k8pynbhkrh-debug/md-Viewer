# md Viewer 1.3 — Mac-Version (Mac Catalyst) + .md-Standard-App

> **Stand 2026-09-04 (Schritt 6 fast fertig):** Code (Schritte 1–5) umgesetzt,
> Mac-Catalyst-Build zu App Store Connect hochgeladen (aktuell **Build 13**),
> macOS-Version 1.3 in ASC angelegt und befüllt. **Es fehlt nur noch Erics
> „Submit for Review".**
>
> **Schritt 6 — erledigt (überwiegend per App-Store-Connect-REST-API automatisiert,
> Skript-Reste unter `scratchpad/asc.py`):**
> - Signing komplett per API eingerichtet (kein developer.apple.com nötig): zwei
>   `MAC_CATALYST_APP_STORE`-Profile „md Viewer Mac App Store" /
>   „md Viewer ShareExtension Mac App Store"; „Mac Installer Distribution"-Zertifikat
>   (CSR → API → legacy-p12 → `security import`, von Eric bestätigt).
> - `ExportOptions-mac.plist`: Zertifikate per SHA-1 gepinnt (Xcode-Bug-Umgehung, s. u.).
> - Build 11/12/13 als Mac Catalyst archiviert, signiert, hochgeladen
>   (`xcodebuild -exportArchive`, „EXPORT SUCCEEDED"). Build 13 = aktueller Stand,
>   an die Version geheftet.
> - ASC: macOS-Plattform (durch Upload automatisch), `appStoreVersion` 1.3 (MAC_OS)
>   angelegt; de-DE-Localization gefüllt (Beschreibung mit „AUF DEM MAC"-Abschnitt,
>   Keywords, Werbetext, URLs; „Neues in dieser Version" bei der ersten Mac-Version
>   von ASC gesperrt = normal); **6 Mac-Screenshots** (2560×1600, APP_DESKTOP)
>   hochgeladen und sortiert; Prüf-Notizen um „VERSION 1.3" + „HOW TO TEST (Mac)" +
>   „DEVICES TESTED" ergänzt.
>
> **Noch offen:**
> - **Eric: in ASC „Zur Prüfung einreichen"** (macOS-Version 1.3) — bewusst nicht
>   automatisch ausgelöst. Danach separate Mac-Review (parallel zur iOS-Prüfung).
> - Alterseinstufung: bei Universal Purchase app-weit; ASC meldet beim Submit, falls
>   für macOS noch etwas fehlt.
> - Manuelle Funktionsprüfung auf einem echten Mac (Standard setzen → Doppelklick aus
>   Finder → Bearbeiten/Speichern) — empfohlen vor dem Submit.
> - Optionaler Polish (kein Blocker): `PasteButton`/„Einsetzen" fehlt im Mac-Empty-State
>   (Catalyst rendert `PasteButton` dort nicht); Fenster-Startgröße/`.contentMinSize`
>   auf großen Displays feinjustieren.
>
> **Xcode-Bug bei `-exportArchive` (Mac App Store):** „Provisioning profile … doesn't
> include signing certificate '3rd Party Mac Developer Installer'" — trotz korrektem
> Profil. Lösung: in `ExportOptions-mac.plist` **beide** Zertifikate per SHA-1-Hash
> pinnen (`signingCertificate` = Apple Distribution, `installerSigningCertificate` =
> Installer). Dann läuft Export + Upload durch.
>
> **Umgesetzt (Code, Schritte 1–5):**
> - `project.pbxproj`: `SUPPORTS_MACCATALYST = YES` + `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`
>   + `DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = NO` für Target **md Viewer** und
>   **ShareExtension** (Debug+Release); `MARKETING_VERSION` 1.2 → **1.3**,
>   `CURRENT_PROJECT_VERSION` 10 → **11** (alle 4 Configs); `CODE_SIGN_ENTITLEMENTS` gesetzt;
>   `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.productivity`; neue Dateien
>   in Projekt/Sources aufgenommen.
> - **NEU** `md Viewer/md Viewer/md Viewer.entitlements` — App Sandbox + user-selected files.
> - **NEU** `md Viewer/ShareExtension/ShareExtension.entitlements` — App Sandbox.
> - `Info.plist`: Markdown-`CFBundleDocumentTypes` `LSHandlerRank` `Alternate` → **`Owner`**,
>   Rolle `Viewer` → **`Editor`**; Endungen `mdown`, `mkd` ergänzt. Plain-Text bleibt `Alternate`.
> - **NEU** `md Viewer/Shared/DefaultMarkdownAppRegistration.swift` — LaunchServices-Wrapper
>   mit vollem Vertrag (`#if targetEnvironment(macCatalyst)`).
> - `ContentView.swift`: Catalyst-only Zeile/Button „md Viewer als Standard für .md festlegen"
>   im Empty State + Fehler-Alert mit Finder-Fallbacktext.
> - `md_ViewerApp.swift`: Catalyst-only `.commands` (Neues Dokument ⌘N / Öffnen … ⌘O via
>   `.fileImporter`), `.defaultSize(1200×820)`, `.windowResizability(.contentMinSize)`.
> - `ci/testflight-mac.sh` + `md Viewer/ExportOptions-mac.plist` (Catalyst-Archive + Upload).

## Context

`md Viewer` ist heute eine reine iOS/iPadOS-App (`TARGETED_DEVICE_FAMILY = "1,2"`,
`SDKROOT = iphoneos`). 1.1 ist live, 1.2 (Build 10) wartet auf Prüfung.

Ziel von **1.3**: die App auf dem Mac verfügbar machen und dort `.md`-Dateien direkt
aus dem Finder öffnen können — inklusive der Möglichkeit, md Viewer per Klick zur
**Standard-App für `.md`** zu machen (wie die Dateizuordnung unter Windows), statt dass
Doppelklick in Vorschau/TextEdit landet.

Bestätigte Entscheidungen:
- **Mac Catalyst** ("Optimize interface for Mac"), nicht "Designed for iPad", nicht natives AppKit.
- In-App-**Button** "md Viewer als Standard für .md festlegen" zusätzlich zur Registrierung.
- **Universal Purchase / gleiches App-Store-Listing** — ein Eintrag für iPhone, iPad, Mac.

Der Code ist klein (~1060 Zeilen) und weitgehend portabel: die einzigen iOS-Eigenheiten
(`fullScreenCover`, `navigationBarTitleDisplayMode`, `PasteButton`, `UIFont`,
`UIAccessibility`, `Color(uiColor:)`) kompilieren alle unter Mac Catalyst. Es gibt heute
**keine** `.entitlements`-Datei.

## Machbarkeit "Standard-App für .md" (kurz)

Ja, möglich — mit einer Einschränkung: macOS lässt eine App sich **nicht** automatisch
beim Start zur Standard-App machen. Der übliche Weg ist ein Klick des Nutzers. Der Plan
deckt beides ab:
1. **Registrierung** als möglicher Handler über `Info.plist` (`CFBundleDocumentTypes` +
   `UTExportedTypeDeclarations`, `LSHandlerRank`).
2. **Ein-Klick-Umstellung** in der App über `LSSetDefaultRoleHandlerForContentType`
   (LaunchServices, C-API — unter Catalyst nutzbar, da `NSWorkspace.setDefaultApplication`
   dort fehlt). Fallback-Hinweis auf Finder → "Informationen" → "Öffnen mit" → "Alle ändern".

## Approach

### 1. Mac-Catalyst-Target aktivieren
Datei: `md Viewer/md Viewer.xcodeproj/project.pbxproj` (Target **"md Viewer"**, Debug+Release,
Build-Configs `07113519…` / `0711351A…`).
- `SUPPORTS_MACCATALYST = YES`
- `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`
- `DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = NO` (Mac nutzt denselben Bundle-Id
  `com.eribert.md-Viewer` → Universal Purchase)
- `MARKETING_VERSION` 1.2 → **1.3**, `CURRENT_PROJECT_VERSION` 10 → **11** (auch in den
  ShareExtension-Configs `27B6B451…` / `A800C207…` gleichziehen)
- `CODE_SIGN_ENTITLEMENTS = "md Viewer/md Viewer.entitlements"`
- `INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity"` (Mac App Store)
- Catalyst-Mindestversion = macOS 14 (aus `IPHONEOS_DEPLOYMENT_TARGET = 17.0` abgeleitet, ok).
- **ShareExtension:** entweder ebenfalls `SUPPORTS_MACCATALYST = YES` (Share-Extensions
  laufen unter Catalyst; `ShareViewController`/`ShareMarkdownView` sind portabel) — **oder**
  Embed/Dependency für den Mac-Build bedingt machen. Empfehlung: Catalyst auch für die
  Extension aktivieren, ist der geringere Aufwand. Vor dem Bau prüfen, ob der Mac-Build
  die Extension sonst als „does not support Mac Catalyst" ablehnt.

### 2. Entitlements (neue Datei)
Neu: `md Viewer/md Viewer/md Viewer.entitlements`
- `com.apple.security.app-sandbox` = `true` (Pflicht Mac App Store)
- `com.apple.security.files.user-selected.read-write` = `true` (für `.fileExporter`,
  `DocumentView.swift:144`)
- Doppelklick-geöffnete Dateien bekommen Sandbox-Zugriff automatisch über LaunchServices.
- `CODE_SIGN_ENTITLEMENTS` im "md Viewer"-Target (Debug+Release) setzen.
- Prüfen: `loadMarkdown` / `saveMarkdown` (`Shared/MarkdownDocument.swift`) laufen unter
  Sandbox+Catalyst weiter (nutzen bereits `startAccessingSecurityScopedResource()` +
  `NSFileCoordinator`, erwartet ok).
- Falls die Extension Catalyst bekommt: eigene `.entitlements` mit App-Sandbox für sie.

### 3. Dateityp-Registrierung schärfen
Datei: `md Viewer/md Viewer/Info.plist`
- Markdown-`CFBundleDocumentTypes`-Eintrag: `LSHandlerRank` `Alternate` → **`Owner`**,
  `CFBundleTypeRole` → `Editor` (App kann bearbeiten/speichern).
- Plain-Text-Eintrag bleibt `Alternate` (kein Anspruch auf `.txt` als Standard).
- Optional weitere Endungen in `UTTypeTagSpecification`: `mdown`, `mkd`.
- `LSSupportsOpeningDocumentsInPlace` (schon `true`) bleibt.

### 4. In-App "Als Standard für .md festlegen"
Neu: `md Viewer/Shared/DefaultMarkdownAppRegistration.swift` — dünner LaunchServices-Wrapper.

Vertrag (Design by Contract — Systemänderung):
- **Vorbedingung:** `Bundle.main.bundleIdentifier != nil`.
- **Nachbedingung (Erfolg):** `LSCopyDefaultRoleHandlerForContentType("net.daringfireball.markdown", .all)`
  == eigener Bundle-Identifier.
- **Nachbedingung (Fehler):** OSStatus ≠ 0 → typisierter Fehler, keine Systemänderung,
  UI zeigt Fallback-Anleitung.
- API: `LSSetDefaultRoleHandlerForContentType(_:_:_:)`, `LSRolesMask.all`, `import CoreServices`.
  Status via `LSCopyDefaultRoleHandlerForContentType` lesen.
- Nur unter `#if targetEnvironment(macCatalyst)` kompilieren/anzeigen.

UI: Zeile/Button in `ContentView.swift` (Empty State), nur auf dem Mac sichtbar:
- Zustand "md Viewer ist Standard für .md" ✓ / Button "Als Standard festlegen".
- Bei Fehler Alert mit Finder-Fallbacktext.
- Erster Aufruf: macOS kann eine Bestätigung zeigen — erwartet.

### 5. Kleine Mac-UI-Anpassungen
Datei: `md Viewer/md Viewer/md_ViewerApp.swift`
- `.commands { }`: `CommandGroup(replacing: .newItem)` mit "Öffnen …" (Flow setzt
  `document = .existing(url)`) und "Neues Dokument". `.onOpenURL` (vorhanden) deckt
  Doppelklick / „Öffnen mit" ab.
- Fenstergröße: `.defaultSize(width: 800, height: 900)` + `.windowResizability(.contentSize)`
  am `WindowGroup`.
- `fullScreenCover` (`md_ViewerApp.swift:24`) läuft unter Catalyst (Vollfenster-Sheet) —
  für 1.3 ok, kein Umbau.
- `navigationBarTitleDisplayMode(.inline)` (`DocumentView.swift:113`) kompiliert unter
  Catalyst; optional per `#if !targetEnvironment(macCatalyst)` kapseln, nicht zwingend.

### 6. App Store Connect / Release (Skill `app-store-release`)
- Im App-Eintrag Plattform **macOS** aktivieren (gleiche App, Universal Purchase).
- Eigener **Mac-Screenshot-Satz** (z. B. 1440×900) — `App-Store-Screenshots/` um Mac-Ordner
  erweitern; ggf. `run-md-viewer`-Skill um Catalyst-Lauf ergänzen.
- Archiv/Upload: `ci/testflight.sh` um Catalyst-Pfad erweitern oder `ci/testflight-mac.sh` —
  `xcodebuild archive -destination 'generic/platform=macOS,variant=Mac Catalyst'`, Export
  mit macOS-App-Store-Methode.
- Mac-Build braucht **eigene Review** (parallel zur iOS-Review möglich).
- `App-Store-Texte.md`: 1.3-Release-Notes + Mac-Hinweise ergänzen.
- `zeiterfassung.csv` nach Projektkonvention nachführen.
- `PrivacyInfo.xcprivacy` vorhanden und ausreichend.

## Kritische Dateien

| Datei | Änderung |
|---|---|
| `md Viewer/md Viewer.xcodeproj/project.pbxproj` | Catalyst an, Versionen, Entitlements-Ref, ShareExtension-Catalyst |
| `md Viewer/md Viewer/Info.plist` | `LSHandlerRank` → `Owner`, Rolle `Editor`, ggf. weitere Endungen |
| `md Viewer/md Viewer/md Viewer.entitlements` | **NEU** — App Sandbox + user-selected files |
| `md Viewer/Shared/DefaultMarkdownAppRegistration.swift` | **NEU** — LaunchServices-Wrapper mit Vertrag |
| `md Viewer/md Viewer/ContentView.swift` | "Als Standard für .md festlegen" (Catalyst-only) |
| `md Viewer/md Viewer/md_ViewerApp.swift` | Menü-Commands (Öffnen/Neu), Fenstergröße |
| `ci/testflight.sh` (o. Mac-Variante), `App-Store-Texte.md`, `zeiterfassung.csv` | Release-Assets |

## Verifikation

1. **Build:** `xcodebuild -scheme "md Viewer" -destination 'platform=macOS,variant=Mac Catalyst' build` grün.
2. **iOS-Regression:** `xcodebuild test -scheme "md Viewer" -destination 'platform=iOS Simulator,name=iPhone 16'`
   (`md ViewerTests`) bleibt grün; iOS-Screenshots via `run-md-viewer` unverändert.
3. **Öffnen aus Finder:** Catalyst-App starten, `.md` per Rechtsklick → "Öffnen mit" → md Viewer → wird gerendert.
4. **Standard setzen:** Button klicken → `LSCopyDefaultRoleHandlerForContentType("net.daringfireball.markdown", .all)`
   gibt `com.eribert.md-Viewer` → Doppelklick auf `.md` im Finder öffnet md Viewer.
5. **Bearbeiten/Speichern:** `.md` öffnen → bearbeiten → in Datei speichern → Inhalt auf Platte stimmt.
6. **Fehlerpfad:** Wrapper mit ungültigem Bundle-Id → typisierter Fehler, Alert mit Finder-Fallback, keine Systemänderung.
