import SwiftUI

/// Presentation of the fifteen-column table, which the redesign replaces
/// wholesale — this file is deleted along with it.
///
/// A header label and a fixed cell width are properties of *a table*, not of a
/// track or of an ordering, so they live in the app target rather than in
/// `SortifyKit`. `CONTEXT.md` lists "Column" under _Avoid_ for exactly this
/// reason: the domain has Attributes and Arrangements, and a column is a thing
/// the old screen happened to draw.
///
/// Nothing new belongs here. When the table goes, so does all of it.
extension Arrangement.Basis {
    /// Column header text.
    var legacyLabel: String {
        switch self {
        case .attribute(let attribute):
            switch attribute {
            case .order: "#"
            case .title: "Title"
            case .artist: "Artist"
            case .release: "Release"
            case .added: "Added"
            case .bpm: "BPM"
            case .energy: "Energy"
            case .dance: "Dance"
            case .loud: "Loud"
            case .valence: "Valence"
            case .length: "Length"
            case .acoustic: "Acoustic"
            case .pop: "Pop."
            }
        case .artistSeparation: "A.Sep"
        case .shuffle: "Rnd"
        }
    }

    /// Fixed cell width in points. The table scrolls horizontally rather than
    /// compressing, so header and body cells must agree on a single number.
    var legacyWidth: Double {
        switch self {
        case .attribute(.order): 40
        case .attribute(.title): 168
        case .attribute(.artist): 132
        case .attribute(.release), .attribute(.added): 96
        case .attribute(.length): 64
        case .attribute(.acoustic), .attribute(.valence), .attribute(.energy): 72
        default: 60
        }
    }

    /// Numeric cells are right-aligned, except the position column, which reads
    /// as a label rather than a measurement. Header and body cells share this
    /// so they cannot disagree.
    var legacyAlignment: Alignment {
        isNumeric && self != .attribute(.order) ? .trailing : .leading
    }
}

extension TrackRow {
    /// Cell text for the fifteen-column table. The two computed Arrangements
    /// have no Attribute to read, so the table shows the working values they
    /// order by.
    func legacyCellText(for basis: Arrangement.Basis) -> String {
        switch basis {
        case .attribute(let attribute): displayValue(for: attribute)
        case .artistSeparation: artistSeparationIndex.map(String.init) ?? ""
        case .shuffle: String(randomValue)
        }
    }
}
