import Foundation

/// A named way of ordering a playlist — the first-class thing a user picks.
/// Attribute-derived orderings carry the Attribute and a direction; artist
/// separation and shuffle are peers that compute their own order.
///
/// FAITHFULNESS INVARIANT: no two values denote the same ordering. `canSave`
/// compares the applied Arrangement against the saved one, so a second spelling
/// of an existing ordering would make it quietly wrong. In particular
/// **Original order is `.attribute(.order, .ascending)` — a name, not a
/// case**; adding a case for it would give one ordering two unequal values.
///
/// The converse does not hold for `.shuffle`, which is one value standing for
/// whichever order the current random values produce. That is why re-rolling
/// does not re-arm Save today. Ticket 03 gives shuffle its own control and
/// should give it a seed payload at the same time, which closes the gap.
public enum Arrangement: Sendable, Hashable {
    case attribute(Attribute, Direction)
    case artistSeparation
    case shuffle

    /// Reachable only as a payload of `.attribute`, so an Arrangement that has
    /// no meaningful direction has nowhere to put one.
    public enum Direction: String, Sendable, Hashable {
        case ascending, descending

        public var reversed: Direction { self == .ascending ? .descending : .ascending }

        /// Word used when naming a saved playlist ("increasing BPM"). Not
        /// public: `Arrangement.name` is the only supported way to render an
        /// Arrangement, so nothing re-assembles the phrase by hand.
        var word: String { self == .ascending ? "increasing" : "decreasing" }

        var multiplier: Int { self == .ascending ? 1 : -1 }
    }

    /// The playlist as Spotify returned it. A constant, not a case — see the
    /// faithfulness invariant above.
    public static let originalOrder = Arrangement.attribute(.order, .ascending)

    /// One value per distinct ordering. Derived by value equality, so the
    /// directionless Arrangements contribute one entry each without anyone
    /// having to declare that they are directionless.
    public static let all: [Arrangement] = Basis.allCases.flatMap { basis -> [Arrangement] in
        let forward = basis.arrangement(.ascending)
        let backward = basis.arrangement(.descending)
        return forward == backward ? [forward] : [forward, backward]
    }

    public var basis: Basis {
        switch self {
        case .attribute(let attribute, _): .attribute(attribute)
        case .artistSeparation: .artistSeparation
        case .shuffle: .shuffle
        }
    }

    /// Nil where direction is meaningless. This *replaces* the old
    /// `directionMatters` flag: a Bool a caller could forget to consult becomes
    /// an Optional it cannot.
    public var direction: Direction? {
        if case .attribute(_, let direction) = self { direction } else { nil }
    }

    /// Total — the directionless Arrangements reverse to themselves, so callers
    /// need no guard.
    public var reversed: Arrangement {
        switch self {
        case .attribute(let attribute, let direction): .attribute(attribute, direction.reversed)
        case .artistSeparation, .shuffle: self
        }
    }

    /// "increasing BPM", "Artist separation". The single source: the header
    /// summary and the saved-playlist name both read this, so they cannot
    /// drift apart.
    public var name: String {
        switch self {
        case .attribute(let attribute, let direction): "\(direction.word) \(attribute.name)"
        case .artistSeparation, .shuffle: basis.name
        }
    }
}

// MARK: - Basis

extension Arrangement {
    /// An Arrangement with its direction stripped off: the identity that
    /// survives a direction flip, and therefore what the user thinks of as
    /// "which arrangement is selected".
    ///
    /// Always derived (`arrangement.basis`), never stored beside an
    /// Arrangement — the app's single piece of ordering state is the
    /// Arrangement, and a stored Basis would be the parallel state this type
    /// exists to remove.
    public enum Basis: RawRepresentable, CaseIterable, Sendable, Hashable, Identifiable {
        case attribute(Attribute)
        case artistSeparation
        case shuffle

        /// Derived from `Attribute.allCases`, so the choosable orderings can
        /// never drift out of step with the Attributes they are derived from.
        public static var allCases: [Basis] {
            Attribute.allCases.map(Basis.attribute) + [.artistSeparation, .shuffle]
        }

        public static let originalOrder = Basis.attribute(.order)

        public var rawValue: String {
            switch self {
            case .attribute(let attribute): attribute.rawValue
            case .artistSeparation: "artist-separation"
            case .shuffle: "shuffle"
            }
        }

        public init?(rawValue: String) {
            switch rawValue {
            case "artist-separation": self = .artistSeparation
            case "shuffle": self = .shuffle
            default:
                guard let attribute = Attribute(rawValue: rawValue) else { return nil }
                self = .attribute(attribute)
            }
        }

        public var id: String { rawValue }

        public var name: String {
            switch self {
            case .attribute(let attribute): attribute.name
            case .artistSeparation: "Artist separation"
            case .shuffle: "Shuffle"
            }
        }

        /// Forwards to the one source of explanation copy for the thirteen
        /// Attributes; owns copy only for the two orderings that no Attribute
        /// describes.
        public var explanation: String {
            switch self {
            case .attribute(let attribute): attribute.explanation
            case .artistSeparation:
                "Not an attribute of the music — Sortify computes this. It rearranges the playlist so tracks by the same artist land as far apart as possible."
            case .shuffle:
                "A random value per track. Tap the column again to reshuffle."
            }
        }

        public var isNumeric: Bool {
            switch self {
            case .attribute(let attribute): attribute.isNumeric
            case .artistSeparation, .shuffle: true
            }
        }

        /// Pairs a Basis with a direction. Not a normalizing factory — every
        /// case constructor stays directly writable and every directly-written
        /// value is legal. This exists so generic code (the launch argument,
        /// the table header, tests) can ask for "this ordering, that way round"
        /// without knowing whether the direction applies.
        public func arrangement(_ direction: Direction = .ascending) -> Arrangement {
            switch self {
            case .attribute(let attribute): .attribute(attribute, direction)
            case .artistSeparation: .artistSeparation
            case .shuffle: .shuffle
            }
        }
    }
}

// MARK: - Launch argument

extension Arrangement {
    /// Round-trips through `init?(argument:)`. Reuses `Basis.rawValue`, so the
    /// launch argument and the view's element identity are one spelling rather
    /// than two.
    public var argument: String {
        guard let direction else { return basis.rawValue }
        return "\(basis.rawValue)-\(direction.rawValue)"
    }

    /// `bpm-descending`, `bpm` (ascending implied), `artist-separation`,
    /// `shuffle`, `order-descending`.
    ///
    /// The whole string is tried as a Basis first, so `artist-separation`
    /// survives its own hyphen; a direction suffix is then accepted only where
    /// one can actually be carried.
    public init?(argument: String) {
        if let basis = Basis(rawValue: argument) {
            self = basis.arrangement()
            return
        }
        guard let dash = argument.lastIndex(of: "-"),
              let direction = Direction(rawValue: String(argument[argument.index(after: dash)...])),
              let attribute = Attribute(rawValue: String(argument[..<dash]))
        else { return nil }
        self = .attribute(attribute, direction)
    }
}
