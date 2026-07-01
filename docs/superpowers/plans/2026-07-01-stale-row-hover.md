# Stale Row & Hover Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop menu rows from reflowing on hover, and replace the noisy Stale badge + Postpone sub-row with a subtle hourglass indicator plus Postpone menu entries.

**Architecture:** Presentation-only changes confined to `App/Views/TodoRowView.swift`. The trailing control cluster permanently reserves the bookmark button's space (fading it in on hover) so title width never changes; the stale sub-row is removed in favor of a small always-visible hourglass glyph in that cluster, with the Postpone action relocated to the "…" menu and the right-click context menu. No changes to `StaleRule`, `TodoStore`, or anything in `Core/`.

**Tech Stack:** Swift / SwiftUI (macOS menu-bar app), xcodebuild, just.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-01-stale-row-hover-design.md`
- Only `App/Views/TodoRowView.swift` may change. No Core changes.
- Build with the scheme, never the target: `xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build` (the scheme carries the DoableCore SwiftPM dependency; `-target` fails with "no such module 'DoableCore'"). Every build auto-installs + ad-hoc re-signs into `/Applications`.
- There is no UI-test harness in this repo; view changes are verified by building and visually checking `/Applications/Doable.app`. Core tests (`cd Core && swift test`) must stay green (they are untouched by this plan).
- Stale tooltip copy, verbatim: `Stale — untouched for N workdays` (N = `staleThresholdWorkdays`, singular "workday" when N is 1).

---

### Task 1: Reserve the bookmark slot (hover fix)

**Files:**
- Modify: `App/Views/TodoRowView.swift:93-130` (the trailing `HStack` in `rowContent`)

**Interfaces:**
- Consumes: existing `@State private var hovering`, `item.isPinned`, `store.togglePin(_:in:)`.
- Produces: the bookmark `Button` is now an unconditional child of the trailing `HStack(spacing: 10)`; Task 2 inserts the stale glyph immediately before it inside the same `HStack`.

- [ ] **Step 1: Make the bookmark button a permanent, fading member of the trailing cluster**

In `App/Views/TodoRowView.swift`, inside the `else` branch of the `isPendingDone` check, replace the conditional bookmark block:

```swift
                HStack(spacing: 10) {
                    // Pinned items always show the (filled) pin so the state is visible; unpinned
                    // items reveal the pin button on hover.
                    if item.isPinned || hovering {
                        Button { store.togglePin(item, in: context) } label: {
                            Image(systemName: item.isPinned ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Unpin" : "Pin to top")
                    }
```

with an always-present button that reserves its layout slot and only toggles visibility:

```swift
                HStack(spacing: 10) {
                    // The bookmark always occupies its slot so the title never rewraps
                    // (and the click target never shifts) when it fades in on hover.
                    // Pinned items keep it visible; unpinned items reveal it on hover.
                    Button { store.togglePin(item, in: context) } label: {
                        Image(systemName: item.isPinned ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "Unpin" : "Pin to top")
                    .opacity(item.isPinned || hovering ? 1 : 0)
                    .allowsHitTesting(item.isPinned || hovering)
```

Also update the now-stale comment above the `Menu` that follows. Replace:

```swift
                    // The "…" menu is always present, anchoring the right edge so the bookmark's
                    // position never shifts on hover. It folds in the deadline, pin, and delete
                    // actions that used to be split between the inline clock and the context menu.
```

with:

```swift
                    // The "…" menu folds in the deadline, pin, and delete actions that used to
                    // be split between the inline clock and the context menu.
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Visual verification**

Run: `open /Applications/Doable.app`, open the menu, and check with an item whose title wraps (e.g. "Stale test item (created 7 days ago)"):
- Unhovered and hovered layouts are identical — the title wraps the same way in both states; only the bookmark's visibility changes.
- Hovering an unpinned item fades the bookmark in; clicking it pins (fills + accent color).
- Unpinned, unhovered rows have no invisible click-dead zone surprises: clicking where the hidden bookmark sits does not toggle pin (hit testing is off).
- Pinned items show the filled bookmark at all times.

- [ ] **Step 4: Commit**

```bash
git add App/Views/TodoRowView.swift
git commit -m "fix(menu): reserve bookmark slot so rows never reflow on hover"
```

---

### Task 2: Subtle stale indicator + Postpone in menus

**Files:**
- Modify: `App/Views/TodoRowView.swift` (title `VStack` in `rowContent`, trailing `HStack` from Task 1, `Menu` content, and `.contextMenu` content)

**Interfaces:**
- Consumes: existing `isStale` computed property, `staleThreshold` (`@AppStorage("staleThresholdWorkdays")`), `store.postponeStale(_:now:thresholdWorkdays:calendar:in:)`, and Task 1's always-present bookmark `Button` inside the trailing `HStack(spacing: 10)`.
- Produces: nothing consumed by later tasks (final task).

- [ ] **Step 1: Remove the stale badge + Postpone sub-row**

In `App/Views/TodoRowView.swift`, inside the title `VStack`, delete this entire block:

```swift
                if isStale {
                    HStack(spacing: 6) {
                        Text("Stale")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2), in: Capsule())
                            .foregroundStyle(.secondary)
                        Button("Postpone") {
                            store.postponeStale(item, now: Date(), thresholdWorkdays: staleThreshold, calendar: .current, in: context)
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                    }
                }
```

- [ ] **Step 2: Add the hourglass glyph to the trailing cluster**

In the trailing `HStack(spacing: 10)` (from Task 1), insert this immediately **before** the bookmark `Button`:

```swift
                    // Stale items get a quiet, always-visible glyph instead of a badge row,
                    // so stale rows stay the same height as normal rows.
                    if isStale {
                        Image(systemName: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Stale — untouched for \(staleThreshold) workday\(staleThreshold == 1 ? "" : "s")")
                    }
```

- [ ] **Step 3: Add Postpone to the "…" menu**

In the `Menu { ... }` content, insert this **above** the "Set deadline" button:

```swift
                        if isStale {
                            Button {
                                store.postponeStale(item, now: Date(), thresholdWorkdays: staleThreshold, calendar: .current, in: context)
                            } label: {
                                Label("Postpone", systemImage: "hourglass")
                            }
                            Divider()
                        }
```

- [ ] **Step 4: Add Postpone to the right-click context menu**

In the `.contextMenu { ... }` block, insert the same conditional button **above** the existing Pin button:

```swift
            if isStale {
                Button {
                    store.postponeStale(item, now: Date(), thresholdWorkdays: staleThreshold, calendar: .current, in: context)
                } label: {
                    Label("Postpone", systemImage: "hourglass")
                }
                Divider()
            }
```

- [ ] **Step 5: Build and run Core tests**

Run: `xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`

Run: `cd Core && swift test`
Expected: all tests pass (Core is untouched; this confirms nothing regressed).

- [ ] **Step 6: Visual verification**

Run: `open /Applications/Doable.app` and check with a stale item (either use an existing one, or set the stale threshold to 1 workday in Settings → General so an older item qualifies):
- The stale row is the same height as a normal row — no badge, no inline Postpone.
- A small gray hourglass sits in the trailing cluster before the bookmark slot; hovering it shows the tooltip "Stale — untouched for N workdays".
- The title keeps its normal color (or red/orange if overdue/due-soon — stale-ness must not override it).
- "…" menu on a stale item shows Postpone (hourglass icon) above "Set deadline", separated by a divider; clicking it clears the hourglass (item snoozed).
- Right-click on a stale item shows the same Postpone entry above Pin; non-stale items show neither.
- A pending-done (checked) stale item shows Undo only — no hourglass.

- [ ] **Step 7: Commit**

```bash
git add App/Views/TodoRowView.swift
git commit -m "feat(menu): subtle hourglass stale indicator, Postpone moves to menus"
```
