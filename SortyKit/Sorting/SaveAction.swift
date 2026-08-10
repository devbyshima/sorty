import Foundation

/// One way of committing an Arrangement, and the words on it.
///
/// Computed rather than assembled in the toolbar, because the two things that
/// distinguish these actions are both rules worth asserting: **what each one is
/// allowed to write** (ADR-0002) and **whether it has anything to write yet**.
/// The count in "Save These 20 as a New Playlist" is the first of those made
/// visible at the moment of choosing - the difference from the whole playlist,
/// stated before the write rather than discovered after it.
public struct SaveAction: Identifiable, Sendable, Hashable {
    /// Not a Bool and not a payload flag. The two kinds are two code paths, and
    /// this is the value the toolbar dispatches on to reach the right one.
    public enum Kind: String, Sendable, Hashable {
        /// Writes every track in the playlist, reordered. Never a subset.
        case overwrite
        /// Writes what is on screen, which may be a subset.
        case newPlaylist
    }

    public let kind: Kind
    public let title: String
    /// False when the action would write what is already there. Offered but
    /// dimmed rather than absent: a listener who can't find Save at all has no
    /// way to learn that nothing has changed.
    public let isEnabled: Bool

    public var id: String { kind.rawValue }

    /// The safe action first. Overwrite is the one that touches a playlist the
    /// listener already has, so it is never the one under the thumb by default.
    public static func actions(
        writtenCount: Int,
        isFiltered: Bool,
        canCreate: Bool,
        canOverwrite: Bool,
        mayOverwriteThisPlaylist: Bool,
        savesACopy: Bool = false
    ) -> [SaveAction] {
        var actions = [
            SaveAction(
                kind: .newPlaylist,
                // Only counts when a filter is on. Unfiltered, the number would
                // be the whole playlist's, which says nothing the listener
                // can't already see and turns a stable menu item into one whose
                // label changes every time a track loads.
                //
                // "Copy" on a playlist that isn't the listener's, because that
                // is what it is and the word carries the reason: there is no
                // Overwrite beside it and there never will be. Keyed on
                // ownership rather than on whether anything has changed, so the
                // label does not rename itself the moment a chip is tapped.
                title: newPlaylistTitle(
                    writtenCount: writtenCount, isFiltered: isFiltered, savesACopy: savesACopy
                ),
                isEnabled: canCreate
            )
        ]
        if mayOverwriteThisPlaylist {
            actions.append(
                SaveAction(kind: .overwrite, title: "Overwrite This Playlist", isEnabled: canOverwrite)
            )
        }
        return actions
    }

    private static func newPlaylistTitle(
        writtenCount: Int, isFiltered: Bool, savesACopy: Bool
    ) -> String {
        switch (savesACopy, isFiltered) {
        case (true, true): "Save These \(writtenCount) as a Copy"
        case (true, false): "Save a Copy"
        case (false, true): "Save These \(writtenCount) as a New Playlist"
        case (false, false): "Save as New Playlist"
        }
    }
}
