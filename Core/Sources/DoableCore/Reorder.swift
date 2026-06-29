import Foundation

/// Pure index math for the manually-ordered active list. Operates on a list of pin flags
/// in current visual order (pinned-first) and returns the new ordering as indices into the
/// input, so the SwiftData layer can apply `sortIndex`/`isPinned` without any ordering logic.
public enum Reorder {

    public struct Plan: Equatable {
        /// New visual order, as indices into the input `pinFlags`.
        public let order: [Int]
        /// Post-move pin state, indexed by the item's ORIGINAL index in `pinFlags`.
        public let pinned: [Bool]

        public init(order: [Int], pinned: [Bool]) {
            self.order = order
            self.pinned = pinned
        }
    }

    /// Move the item at `from` to post-removal insertion index `to`.
    ///
    /// Pinned items always remain above unpinned. The moved item flips its pin state when it
    /// lands strictly inside the opposite section: dropped above the pinned/unpinned boundary
    /// it becomes pinned, dropped below it becomes unpinned, dropped exactly at the boundary it
    /// keeps its state. With no other pinned items there is no boundary, so the state is kept.
    public static func move(pinFlags: [Bool], from: Int, to: Int) -> Plan {
        var pinned = pinFlags
        var others = Array(0..<pinFlags.count)
        others.remove(at: from)

        // Boundary = number of pinned items among the *other* items. others[0..<p] are pinned.
        let p = others.filter { pinFlags[$0] }.count
        let d = max(0, min(to, others.count))

        if d < p { pinned[from] = true }
        else if d > p { pinned[from] = false }
        // d == p → boundary, keep existing state.

        var order = others
        order.insert(from, at: d)
        return Plan(order: order, pinned: pinned)
    }

    /// Place `moving` at the top of the section matching `pinFlags[moving]`, keeping all other
    /// items in their current relative order and pinned-first overall. Used for new-item
    /// placement (append the new item to `pinFlags` as `false`, pass its index) and for
    /// repositioning an item right after its pin state was toggled.
    public static func placeAtTopOfSection(pinFlags: [Bool], moving: Int) -> [Int] {
        var others = Array(0..<pinFlags.count)
        others.remove(at: moving)

        if pinFlags[moving] {
            return [moving] + others
        }
        let pinnedOthers = others.filter { pinFlags[$0] }
        let unpinnedOthers = others.filter { !pinFlags[$0] }
        return pinnedOthers + [moving] + unpinnedOthers
    }
}
