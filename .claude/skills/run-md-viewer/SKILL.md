---
name: run-md-viewer
description: Build, launch, and drive the "md Viewer" SwiftUI iOS app in the iOS Simulator — open markdown files, take screenshots, verify rendering. Use when asked to run, build, test, or screenshot the md Viewer app, or to confirm a change works in the simulator.
---

Paths below are relative to the repo root (`<unit>` = `/Users/eric/Projekte/md Viewer`).
The app is a plain SwiftUI `WindowGroup` (no `DocumentGroup`) that opens
`.md` files via `onOpenURL` — files are handed to it by the OS (Files app
Share Sheet, or a registered UTI), not browsed from inside the app. The
driver simulates that hand-off with `simctl openurl`.

## Run (agent path)

Use the driver at `.claude/skills/run-md-viewer/driver.sh`. It resolves a
named simulator (default `"iPhone 17"`), builds with a local, gitignored
`DerivedData` path (`build/DerivedData-sim`), and wraps `simctl`.

```bash
DRIVER=".claude/skills/run-md-viewer/driver.sh"

"$DRIVER" full                          # build + boot simulator + install + launch
"$DRIVER" open /path/to/some.md         # simulate opening a markdown file (Share Sheet equivalent)
"$DRIVER" screenshot out.png            # save a PNG of the simulator screen
"$DRIVER" terminate                     # stop the app
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
- **Bundle ID:** `com.eribert.md-Viewer`. **Scheme:** `md Viewer` (there's
  also an `MarkdownUI` scheme from the SPM package — don't use that one).
- No GUI-click harness is wired up (no `cliclick`/`idb` in this
  environment) — the driver can launch, install, open documents, and
  screenshot, but not tap buttons like the empty-state's close (X). To
  test dismiss/close flows, terminate + relaunch instead (`driver.sh
  terminate && driver.sh launch`), which returns the app to its initial
  empty state.

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
