---
name: run-md-viewer
description: Build, launch, and drive the "md Viewer" SwiftUI iOS app in the iOS Simulator — open markdown files, take screenshots, verify rendering. Use when asked to run, build, test, or screenshot the md Viewer app, or to confirm a change works in the simulator.
---

Paths below are relative to the repo root (`<unit>` = `/Users/eric/Projekte/md Viewer`).
The app is a plain SwiftUI `WindowGroup` (no `DocumentGroup`) that opens
`.md` files via `onOpenURL` — files are handed to it by the OS (Files app
Share Sheet, or a registered UTI), not browsed from inside the app. The
driver simulates that hand-off with `simctl openurl`.

Since v1.1 the app also has an **edit mode**: `DocumentView` shows a
"Bearbeiten" (pencil) button top-right; tapping it swaps the `Markdown`
preview for a `TextEditor`, and "Speichern" (checkmark) writes the text
back to `fileURL` via `saveMarkdown(text:to:)`. "Vorschau" (eye) returns
to a rendered preview of the *draft* without saving; closing with unsaved
changes shows a confirmation dialog. The Share extension is unaffected —
it stays read-only display (no edit button).

There is also a **Share extension** target `ShareExtension`
(`com.eribert.md-Viewer.ShareExtension`, `com.apple.share-services`) that
renders a shared Markdown/text file in a sheet right inside the share
sheet. It's built + embedded automatically as a dependency of the app
target (`PlugIns/ShareExtension.appex`). `DocumentError` / `maxFileSize` /
`loadMarkdown(from:)` / `saveMarkdown(text:to:)` moved to
`md Viewer/Shared/MarkdownDocument.swift`, which is a member of both the
app and the extension target (added as explicit file refs — it lives
outside the app's synchronized root folder).
The extension can't be driven from the CLI (no way to invoke a share
sheet); test it by hand: Files → long-press a `.md` → Teilen → top icon
row → "md Viewer" (enable via "Mehr" first if hidden). It should show a
sheet with "Fertig" top-right (the main app instead shows an "X" /
"Schließen" top-left).

## Run (agent path)

Use the driver at `.claude/skills/run-md-viewer/driver.sh`. It resolves a
named simulator (default `"iPhone 17"`), builds with a local, gitignored
`DerivedData` path (`build/DerivedData-sim`), and wraps `simctl`.

If the driver reports `No simulator named 'iPhone 17' found` (a fresh
machine may have the iOS runtime installed but zero devices), create one
and pass its UDID via `MD_VIEWER_SIM_UDID`:

```bash
xcrun simctl create "iPhone 17" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17 \
  com.apple.CoreSimulator.SimRuntime.iOS-26-4      # -> prints a UDID
export MD_VIEWER_SIM_UDID=<that-udid>
```

```bash
DRIVER=".claude/skills/run-md-viewer/driver.sh"

"$DRIVER" full                          # build + boot simulator + install + launch
"$DRIVER" open /path/to/some.md         # simulate opening a markdown file (Share Sheet equivalent)
"$DRIVER" screenshot out.png            # save a PNG of the simulator screen
"$DRIVER" terminate                     # stop the app
"$DRIVER" test                          # run the md ViewerTests unit test target
```

Individual steps (`build`, `boot`, `install`, `launch`, `device-id`) are
also available — see `"$DRIVER"` with no args for the full list.

Screenshots must actually be looked at (Read tool) — a blank or
empty-state screen when you expected rendered markdown means the open
didn't reach the app.

## Build (what `full`/`build` does)

```bash
cd "md Viewer"
xcodebuild -project "md Viewer.xcodeproj" -scheme "md Viewer" \
  -destination "id=<SIMULATOR_UDID>" \
  -derivedDataPath "../build/DerivedData-sim" \
  -configuration Debug build
```

First build resolves 3 SPM packages (`swift-markdown-ui`, `NetworkImage`,
`swift-cmark`) — takes longer the first time, cached after.

## Test

`"$DRIVER" test` runs `xcodebuild test -scheme "md Viewer"`, which builds
and executes the `md ViewerTests` target (Swift Testing framework, not
XCTest) on the same simulator. The target was added by script
(`xcodeproj` Ruby gem — Xcode.app was never opened), so there's no
`.xcscheme` committed; the default scheme picks up the test target via
the `TestTargetID` project attribute. Covers `loadMarkdown(from:)` (all
its `DocumentError` cases, including the `size > maxFileSize` vs
`size >= maxFileSize` boundary — verified by temporarily flipping that
operator and confirming `exactlyAtSizeLimit()` fails, then reverting) and
`saveMarkdown(text:to:)` (round-trip, round-trip back through
`loadMarkdown`, file creation, and the `.empty` / `.tooLarge` /
`.notWritable` rejections). Both live in
`md Viewer/Shared/MarkdownDocument.swift`.

`loadMarkdown` / `saveMarkdown` / `maxFileSize` are intentionally not
`private` (plain `internal`) so `@testable import md_Viewer` can see
them — note the module name is `md_Viewer` (underscore), not `md Viewer`.

The edit-mode UI wiring in `DocumentView` (button → `save()` →
`saveMarkdown`) is **not** covered by an automated test — there is no
UITest target and synthetic taps are unreliable here (see Gotchas). Smoke
-test the Bearbeiten → type → Speichern loop by hand in Xcode.

## App-Store-Screenshot vom Editor

Synthetic taps can't reliably open the editor, so `DocumentView` has a
`#if DEBUG` launch-argument hook: launch with `-mdviewerScreenshotEdit`,
then `openurl` a file, and the view opens straight in edit mode with one
demo edit applied (so the red Save checkmark and "Zurücksetzen" are
active) and no keyboard. Used for `App-Store-Screenshots/*/02-bearbeiten.png`.

```bash
xcrun simctl launch <udid> com.eribert.md-Viewer -mdviewerScreenshotEdit
xcrun simctl openurl <udid> "file://<abs path to a .md>"   # abs path, spaces ok
# software keyboard: it stays hidden under simctl until you toggle it —
open -a Simulator --args -CurrentDeviceUDID <udid>
osascript -e 'tell application "Simulator" to activate' \
  -e 'delay 0.7' \
  -e 'tell application "System Events" to keystroke "k" using command down'  # I/O ▸ Keyboard ▸ Toggle Software Keyboard
xcrun simctl io <udid> screenshot out.png
```

For `02-bearbeiten.png` the keyboard is shown (Cmd+K above). The demo edit
in the hook flips `- [ ] Release-Notes schreiben` → `- [x] …` in
`demo-dokumente/Notiz.md`, which is short enough that the heading stays
visible above the keyboard and the red Save checkmark is active.

Gotchas that cost time here:
- `@FocusState = true` alone does **not** raise the software keyboard under
  `simctl`; the sim treats a hardware keyboard as connected. Cmd+K via
  System Events (a keystroke, not a click — those work) toggles it.
- A fresh sim shows a "Type Deutsch und Englisch" onboarding sheet over the
  keyboard on first use. Force a single language first:
  `xcrun simctl spawn <udid> defaults write "Apple Global Domain" AppleKeyboards -array "de_DE@hw=German-Standard;sw=QWERTZ-German"` then reboot.
- iOS renames on Inbox collision (`Notiz-1.md`); `simctl uninstall` +
  reinstall between runs to keep the title clean.

Screenshot sim sizes: iPhone 6.9" = iPhone 17 Pro Max (1320×2868), iPad
13" = iPad Pro 13-inch (2064×2752). Clean status bar via
`xcrun simctl status_bar <udid> override --time 09:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode notSupported`.

## Mutation testing

`muter` (`brew install muter-mutation-testing/formulae/muter`) is set up
via `md Viewer/muter.conf.yml`. Run it with:

```bash
"$DRIVER" mutate --files-to-mutate "md Viewer/DocumentView.swift" --format plain --skip-update-check
```

(omit `--files-to-mutate` to scan the whole project; a full run takes
noticeably longer). It leaves a `md Viewer_mutated/` working copy and
`md Viewer/muter_logs/` behind — both gitignored, safe to `rm -rf` after
inspecting a report; `cmd_mutate` doesn't clean these up itself.

**Known broken with muter 16 (2026-09):** the run discovers files and
mutants fine, then aborts with `Could not find xctestrun file at path:
.../md Viewer_mutated/Debug` — muter looks for the `.xctestrun` in
`<project>/Debug` instead of the DerivedData `Build/Products` dir, so no
mutants are ever tested. Not caused by the source under test. Until
muter is fixed or the driver works around it, rely on the unit tests for
the save/load paths.

**Requires a persisted shared scheme to actually work.** Muter uses
"mutant schemata": it builds once with every mutation embedded behind
`if ProcessInfo.processInfo.environment["<mutant-id>"] != nil { ... }`
checks, then activates one mutant per test run via an environment
variable — no rebuild between mutants (confirmed by checking the built
binary's mtime, which never changes across a run). That env var can only
be injected through a real `.xcscheme`'s `TestAction` — Xcode's
autogenerated default scheme (which is all this project had until now)
isn't a file muter can edit. Without a committed scheme, the env var
never gets set, the schemata's `if` is always false, and **every mutant
silently "survives" — 0% mutation score — regardless of how good the
tests are.** This is exactly what happened on the first run here.

Fixed by committing
`md Viewer.xcodeproj/xcshareddata/xcschemes/md Viewer.xcscheme` (a
standard Build+Test scheme referencing both targets). After adding it,
the same 2 mutants in `loadMarkdown` went from "survived" to "killed"
— 100%. If mutation score is suspiciously 0% (or suspiciously 100% with
"could not gather coverage data" in the report) after a project or
scheme change, check the scheme still exists and still lists the test
target before trusting the score.

## Run (human path)

Open `md Viewer/md Viewer.xcodeproj` in Xcode, select a simulator, Cmd-R.
Only useful when a human is watching; the agent path above is
non-interactive and scriptable.

## Gotchas

- **`GENERATE_INFOPLIST_FILE = NO` silently breaks installation.** This
  project's `Info.plist` only contains UTI/document-type keys — it never
  had `CFBundleIdentifier`, `CFBundleExecutable`, etc. If someone flips
  `GENERATE_INFOPLIST_FILE` back to `NO` in `project.pbxproj`,
  `simctl install` fails with `Missing bundle ID`. Keep it `YES` (merged
  mode: Xcode generates the standard keys from `INFOPLIST_KEY_*` build
  settings and merges in the custom `Info.plist`'s UTI keys). See commit
  `14f3d2c`.
- **The app has no in-app file browser.** `simctl openurl <udid> file://<path>`
  is the only way to get a document in front of it from the CLI — there is
  no `DocumentGroup`, so copying a file into the app's container
  `Documents/` folder does nothing by itself.
- **iOS renames imported files on collision.** Opening a file named
  `test.md` twice produces `test-1.md`, `test-2.md`, etc. inside the app's
  Inbox — expected OS behavior, not a bug. The screenshot's title bar
  shows the *imported* name, which may differ from your source file.
- **Edit mode saves to whatever URL `onOpenURL` handed over.** `simctl
  openurl file://…` and the Files-app "Öffnen mit" flow both copy the
  file into `…/Documents/Inbox/` first, so "Speichern" writes to that
  Inbox copy, not your original on disk — the original is untouched. A
  true in-place edit (original updated) only happens for documents opened
  from a provider that supports it (iCloud Drive, "On My iPhone", another
  app's shared container) where the URL is security-scoped and outside
  the sandbox; `saveMarkdown` coordinates that write with
  `NSFileCoordinator` + `replaceItemAt`. `saveMarkdown` refuses empty /
  whitespace-only and >5 MB input (throws `.empty` / `.tooLarge`) so it
  never produces a file `loadMarkdown` would then reject.
- **Bundle ID:** `com.eribert.md-Viewer` (extension:
  `com.eribert.md-Viewer.ShareExtension`). **Scheme:** `md Viewer` (there's
  also an `MarkdownUI` scheme from the SPM package — don't use that one).
- **Archiving needs `-allowProvisioningUpdates`** now that the extension
  target exists — its App ID/profile must be registered with Apple once
  (Xcode "Distribute App" does it, or pass the flag to `xcodebuild archive`).
  Simulator builds and `xcodebuild test` are unaffected.
- No GUI-click harness is wired up (no `cliclick`/`idb` in this
  environment) — the driver can launch, install, open documents, and
  screenshot, but not tap buttons like the empty-state's close (X). To
  test dismiss/close flows, terminate + relaunch instead (`driver.sh
  terminate && driver.sh launch`), which returns the app to its initial
  empty state.
- **`LSSupportsOpeningDocumentsInPlace` alone does not make the app's
  Documents folder show up in Files → "Auf meinem iPhone"/"On My
  iPhone".** Needed `UIFileSharingEnabled = YES` too (see commit
  `d809233`). Without it, Files' "On My iPhone" section stays empty even
  though `simctl openurl` handoff (the app's actual designed opening path)
  works fine regardless.
- **Wide markdown tables need an explicit horizontal `ScrollView`.**
  `swift-markdown-ui`'s default table style squeezes columns to fit the
  screen width instead of scrolling, which mangles anything with more
  than ~4 columns (word-by-word wrapping inside cells). Fixed in
  `DocumentView.swift` via `.markdownBlockStyle(\.table) { configuration in
  ScrollView(.horizontal) { configuration.label } }`.
- **AppleScript/System Events GUI automation is unreliable here for
  clicks specifically.** `tell application "System Events" to click at
  {x,y}` worked a few times after granting Terminal Accessibility access,
  then started failing with "osascript hat keine Berechtigung für den
  Hilfszugriff" (-25211) with no clear trigger, and didn't recover even
  after re-confirming the permission was still granted. Plain AX queries
  (`position of window`, `UI elements of ...`) and `keystroke` commands
  (e.g. Cmd+Shift+H for Home) kept working throughout — only synthetic
  `click`/`click at` broke. `screencapture` also needs a separate Screen
  Recording grant for Terminal (untested whether that would have helped
  the click issue). Net effect: don't rely on tap-driven UI testing here;
  use `simctl openurl` (functionally equivalent to the Files-app/Share
  Sheet hand-off) and `simctl` install/launch/screenshot instead.

## Troubleshooting

- `Missing bundle ID` from `simctl install` → `GENERATE_INFOPLIST_FILE`
  reverted to `NO`; see Gotchas above.
- `Unable to create '.../index.lock': File exists` or `.../HEAD.lock`
  during git operations in this repo → stale lock from a crashed prior
  git process, not a real lock (check `ps aux | grep git` to confirm
  nothing is running, then `rm` the specific `.lock` file named in the
  error).
- `xcrun simctl bootstatus` hangs or the simulator never appears →
  `open -a Simulator` first (the driver's `boot` step does this), give
  it a few seconds before `bootstatus`.
