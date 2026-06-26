# Doable

A tiny, native macOS menu bar todo app. Click the menu bar icon, type a task, press **Enter** — it's captured. No window to manage, no Dock icon; it just lives in your menu bar and stays out of the way until something needs your attention.

## Features

- **Instant capture** — click the icon, type, press Enter. The input is focused the moment the popover opens, so you can add several tasks in a row without touching the mouse.
- **One-click complete** — click the circle to check a task off. It stays visible (with an **Undo**) while the popover is open, then moves to the archive when you close it.
- **Optional deadlines** — hover a task and click the clock to set a date and time. Tasks are ordered by deadline (soonest first), with undated tasks below and newest first.
- **Due-soon & overdue at a glance** — tasks turn **orange** when they're due soon and **red** when overdue. The menu bar icon picks up the same color and shows a **count** of pressing tasks (red wins over orange), so you know without even opening it.
- **Configurable "due soon"** — choose what "soon" means: today only, within 1 hour, within 24 hours, or within 3 days.
- **Stale reminders** — undated tasks that have been sitting untouched for too long (a configurable number of workdays, weekends excluded) get a **Stale** badge with a one-click **Postpone**.
- **Completed archive** — a separate screen lists everything you've finished, newest first.
- **Native Settings window** — toggle **Launch at login**, set the due-soon window, and set the stale threshold.

## Installing

There's no prebuilt download yet, so you build it from source. You'll need **macOS 14 or later**, **Xcode**, and **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** (`brew install xcodegen`).

```bash
git clone https://github.com/Jensderond/Doable.git
cd Doable
xcodegen generate
xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build
```

Then launch it:

```bash
open build/Build/Products/Debug/Doable.app
```

To keep it around, drag `Doable.app` into your **Applications** folder, and turn on **Launch at login** in Settings so it starts with your Mac.

## Using it

- **Add a task:** click the checklist icon in the menu bar, type, and press **Enter**.
- **Set a deadline:** hover a task and click the **clock**, then pick a date and time. Clear it any time from the same editor.
- **Complete a task:** click the **circle** on its left. Changed your mind? Click **Undo** before closing the popover.
- **See finished tasks:** click **Completed** at the bottom of the list.
- **Open settings:** click the **gear**, then adjust launch-at-login, the due-soon window, and the stale threshold.

The menu bar icon is your ambient cue: plain when nothing's pressing, orange with a count when something's due soon, red with a count when something's overdue.
