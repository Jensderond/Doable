# Fix Report: Orphaned Editor State

## Changes

### `App/Views/MenuContentView.swift`
Added `.onChange(of: screen) { _, _ in editingItemID = nil }` on the outer `Group` in `body`, immediately after the existing `.onDisappear` modifier. This clears the editing state whenever the user navigates between the list and archive screens.

### `App/Views/TodoRowView.swift`
Expanded the `else` branch in `toggleDone()` to also clear `editingItemID` when the item being marked done is the one currently being edited. The undo branch is unchanged.

```swift
private func toggleDone() {
    if isPendingDone { store.undo(item) } else {
        store.markDone(item)
        if editingItemID == item.id { editingItemID = nil }
    }
}
```

## Build Result
`** BUILD SUCCEEDED **`
