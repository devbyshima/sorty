import Foundation
import Testing

/// The design invariant the whole redesign rests on: an Arrangement value *is*
/// an ordering. Two values that produce the same order would make `canSave`
/// (which compares the applied arrangement against the saved one), the active
/// chip and the reorder diff all wrong in the same way, so it is pinned here
/// rather than left to review.
@Suite("Arrangement")
struct ArrangementTests {

    @Test("Original order is a name for an Arrangement, not a second spelling of one")
    func originalOrderIsNotADuplicate() {
        #expect(Arrangement.originalOrder == .attribute(.order, .ascending))
        #expect(Set([Arrangement.originalOrder, .attribute(.order, .ascending)]).count == 1)
    }

    @Test("Every distinct ordering has exactly one value")
    func arrangementsAreFaithful() {
        // 12 attributes × 2 directions + artist separation + shuffle.
        #expect(Arrangement.all.count == 26)
        #expect(Set(Arrangement.all).count == Arrangement.all.count)
    }

    @Test("Reversing original order is representable - the # header still flips")
    func originalOrderReverses() {
        #expect(Arrangement.originalOrder.reversed == .attribute(.order, .descending))
        #expect(Arrangement.originalOrder.reversed != Arrangement.originalOrder)
    }

    @Test("Artist separation and Shuffle carry no direction to reverse")
    func computedArrangementsAreDirectionless() {
        for arrangement in [Arrangement.artistSeparation, .shuffled] {
            #expect(arrangement.direction == nil)
            #expect(arrangement.reversed == arrangement)
        }
    }

    @Test("An Attribute-derived Arrangement always has a direction")
    func attributeArrangementsHaveDirection() {
        for attribute in Attribute.allCases {
            #expect(Arrangement.attribute(attribute, .ascending).direction == .ascending)
            #expect(Arrangement.attribute(attribute, .descending).direction == .descending)
        }
    }

    @Test("A Basis is an Arrangement with the direction stripped off")
    func basisIsTheDirectionlessIdentity() {
        #expect(Arrangement.attribute(.bpm, .ascending).basis == .attribute(.bpm))
        #expect(Arrangement.attribute(.bpm, .descending).basis == .attribute(.bpm))
        #expect(Arrangement.artistSeparation.basis == .artistSeparation)
        #expect(Arrangement.shuffled.basis == .shuffle)
    }

    @Test("The fourteen choosable orderings keep the order the table presented them in")
    func basisOrdering() {
        #expect(Arrangement.Basis.allCases.map(\.rawValue) == [
            "order", "title", "artist", "release", "added",
            "bpm", "energy", "dance", "loud", "valence", "length", "acoustic",
            "artist-separation", "shuffle",
        ])
    }

    /// Twelve since ADR-0026 removed Popularity. The count is asserted rather
    /// than derived on purpose: adding or dropping an Attribute changes the
    /// picker, the chip row, the FAQ and the detail sheet all at once, and this
    /// is the one place that has to be edited deliberately when it happens.
    @Test("There are exactly twelve Attributes")
    func twelveAttributes() {
        #expect(Attribute.allCases.count == 12)
    }

    @Test("Explanation copy has one source - a Basis defers to its Attribute")
    func explanationIsNotDuplicated() {
        for attribute in Attribute.allCases {
            #expect(Arrangement.Basis.attribute(attribute).explanation == attribute.explanation)
        }
    }

    // MARK: - Launch argument

    @Test("Every Arrangement round-trips through its launch argument", arguments: Arrangement.all)
    func argumentRoundTrips(arrangement: Arrangement) {
        #expect(Arrangement(argument: arrangement.argument) == arrangement)
    }

    @Test("A bare Basis argument means ascending")
    func bareArgumentIsAscending() {
        #expect(Arrangement(argument: "bpm") == .attribute(.bpm, .ascending))
        #expect(Arrangement(argument: "artist-separation") == .artistSeparation)
        #expect(Arrangement(argument: "shuffle") == .shuffled)
    }

    @Test("A direction is rejected where no direction can be carried")
    func directionOnADirectionlessArrangementIsRejected() {
        #expect(Arrangement(argument: "artist-separation-ascending") == nil)
        #expect(Arrangement(argument: "shuffle-descending") == nil)
    }

    @Test("Nonsense arguments are rejected rather than silently defaulted")
    func badArgumentsAreRejected() {
        #expect(Arrangement(argument: "bpm-sideways") == nil)
        #expect(Arrangement(argument: "tempo") == nil)
        #expect(Arrangement(argument: "") == nil)
        #expect(Arrangement(argument: "-") == nil)
    }

    // MARK: - Naming

    @Test("An Arrangement names itself, and the name carries its direction")
    func arrangementNames() {
        #expect(Arrangement.attribute(.bpm, .ascending).name == "increasing BPM")
        #expect(Arrangement.attribute(.energy, .descending).name == "decreasing Energy")
        #expect(Arrangement.originalOrder.name == "increasing Original order")
    }

    @Test("The directionless Arrangements name themselves without one")
    func directionlessNames() {
        #expect(Arrangement.artistSeparation.name == "Artist separation")
        #expect(Arrangement.shuffled.name == "Shuffle")
    }
}
