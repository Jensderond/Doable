# Settings window: sidebar with categories

## Goal

Replace the single-form Settings window with a larger, sidebar-based window
organized into categories: **General**, **Developer**, and **About**. About is
pinned to the bottom of the sidebar. Also make `cmd+,` open the Settings window
while the menu-bar popover is open.

## Current state

- `App/DoableApp.swift` declares a standard `Settings { SettingsView() }` scene.
- `App/Views/SettingsView.swift` is a single grouped `Form` (380×240) holding:
  launch-at-login toggle, due-soon picker, stale-after stepper, and the
  "Install doable command" button with its `installCLI()` logic and result
  message.
- `App/Views/MenuContentView.swift` already opens Settings from a gear button via
  `@Environment(\.openSettings)` + `NSApp.activate(ignoringOtherApps:)`.
- App is a menu-bar app (`LSUIElement`), macOS 14+. Version lives in
  `App/Resources/Info.plist` (`CFBundleShortVersionString` = 1.0,
  `CFBundleVersion` = 1). GitHub repo: `github.com/Jensderond/Doable`.

## Design

### Layout

Use `NavigationSplitView` (chosen over `TabView`, which gives top toolbar tabs
rather than a left sidebar and cannot pin About to the bottom).

```
┌──────────────┬────────────────────────────┐
│ ⚙ General    │                            │
│ </> Developer │   (selected pane content)  │
│              │                            │
│   (spacer)   │                            │
│ ───────────   │                            │
│ ⓘ About      │                            │
└──────────────┴────────────────────────────┘
   ~180pt               ~440pt
```

- Default window roughly **640×420**, set via `.frame(minWidth/idealWidth…)` on
  the split view (Settings scene needs an explicit frame).
- Sidebar is a `List` bound to a `@State` selection enum. General and Developer
  are top items; a `Spacer()` pushes About to the bottom so it reads as a
  separate, lower group.

### Components

A shell view plus one small file per pane:

| File | Responsibility |
|------|----------------|
| `App/Views/SettingsView.swift` | `NavigationSplitView` shell: selection enum (`general`, `developer`, `about`), sidebar list, routes detail to the selected pane. Window frame. |
| `App/Views/Settings/GeneralSettingsView.swift` | Launch-at-login toggle, Due-soon picker, Stale-after stepper. Owns the related `@AppStorage`/`@State`. |
| `App/Views/Settings/DeveloperSettingsView.swift` | "Install doable command" button, `installCLI()` logic, result message, and the `realHome`/`binDir`/`linkURL`/`bundledTool` helpers — moved verbatim from today's `SettingsView`. |
| `App/Views/Settings/AboutSettingsView.swift` | App icon, name, version + build (read from `Bundle.main.infoDictionary`), "by Jens de Rond · redkiwi", "View on GitHub" link to `https://github.com/Jensderond/Doable`. |

Selection enum:

```swift
private enum SettingsSection: String, CaseIterable, Identifiable {
    case general, developer, about
    var id: String { rawValue }
    var label: String { … }       // "General", "Developer", "About"
    var systemImage: String { … } // "gearshape", "hammer"/"terminal", "info.circle"
}
```

Each pane keeps the existing `Form { … }.formStyle(.grouped)` styling so the
panes look consistent with today's window.

### About pane content

- App icon (`NSImage(named: NSImage.applicationIconName)` or app bundle icon).
- "Doable" name, version line: `Version <CFBundleShortVersionString> (<CFBundleVersion>)`.
- Developer line: "by Jens de Rond · redkiwi".
- `Link("View on GitHub", destination: …)` to the repo.
- Laid out (e.g. a trailing `VStack`/`Section`) so a future **Check for
  Updates** button drops in without restructuring. No network calls in this pass.

### `cmd+,` from the menu popover

Add a hidden, zero-size button inside `MenuContentView`'s `listScreen` (and
ideally the shared root so it also works on the archive screen) with
`.keyboardShortcut(",", modifiers: .command)` whose action mirrors the existing
gear button:

```swift
NSApp.activate(ignoringOtherApps: true)
openSettings()
```

Hide it with `.frame(width: 0, height: 0).opacity(0)` (or `.hidden()`) and
`.accessibilityHidden(true)` so it only contributes the shortcut.

## Out of scope

- GitHub Releases update check / auto-download (link only this pass; About is
  structured to accept a Check-for-Updates button later).
- Any change to settings *values*, storage keys, or `installCLI()` behavior —
  this is a reorganization of presentation only.

## Testing

- Existing `DoableCoreTests` (incl. `PathCheckTests`) are unaffected; the moved
  CLI logic is unchanged, so they should continue to pass.
- Manual verification: open Settings via gear and via `cmd+,` while the popover
  is open; switch between all three sidebar sections; confirm About shows the
  correct version; confirm "View on GitHub" opens the repo; confirm CLI install
  still works from the Developer pane.
