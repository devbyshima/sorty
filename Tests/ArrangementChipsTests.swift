import Foundation
import Testing

/// The chip row is the primary control of the redesigned screen, so its
/// composition is computed rather than laid out by hand: the view renders what
/// it is handed and contains no branch worth asserting.
@Suite("Arrangement chips")
struct ArrangementChipsTests {

    private func bases(_ chips: [ArrangementChip]) -> [Arrangement.Basis] {
        chips.map(\.basis)
    }

    @Test("Five chips are pinned, in one fixed order")
    func fivePinnedInFixedOrder() {
        let expected: [Arrangement.Basis] = [
            .attribute(.order), .attribute(.bpm), .attribute(.energy),
            .artistSeparation, .shuffle,
        ]
        #expect(ArrangementChip.pinned == expected)
        #expect(bases(ArrangementChip.row(for: .originalOrder)) == expected)
    }

    @Test("The five never move, whatever is applied", arguments: Arrangement.all)
    func pinnedChipsNeverReorder(arrangement: Arrangement) {
        let row = ArrangementChip.row(for: arrangement)
        #expect(Array(bases(row).prefix(5)) == ArrangementChip.pinned)
    }

    @Test("Applying a pinned Arrangement adds no chip")
    func pinnedArrangementsAddNothing() {
        for basis in ArrangementChip.pinned {
            let row = ArrangementChip.row(for: basis.arrangement())
            #expect(row.count == 5, "\(basis.name) grew the row to \(row.count)")
        }
    }

    @Test("An off-piste Arrangement appears as a trailing chip while it is active")
    func offPisteArrangementTrails() {
        let row = ArrangementChip.row(for: .attribute(.valence, .ascending))
        #expect(row.count == 6)
        #expect(row.last?.basis == .attribute(.valence))
        #expect(row.last?.isPinned == false)
        #expect(row.last?.isActive == true)
    }

    @Test("The trailing chip retires when another Arrangement is applied")
    func trailingChipRetires() {
        let valence = ArrangementChip.row(for: .attribute(.valence, .ascending))
        #expect(valence.count == 6)

        let replaced = ArrangementChip.row(for: .attribute(.loud, .ascending))
        #expect(replaced.count == 6)
        #expect(replaced.last?.basis == .attribute(.loud), "valence should not linger")

        let backToPinned = ArrangementChip.row(for: .attribute(.bpm, .ascending))
        #expect(backToPinned.count == 5, "no trailing chip once a pinned one is active")
    }

    @Test("Exactly one chip is active, and it is the applied Arrangement's")
    func exactlyOneActive() {
        for arrangement in Arrangement.all {
            let row = ArrangementChip.row(for: arrangement)
            let active = row.filter(\.isActive)
            #expect(active.count == 1, "\(arrangement.name) has \(active.count) active chips")
            #expect(active.first?.basis == arrangement.basis)
        }
    }

    // MARK: - Direction

    @Test("Direction shows on the active chip and nowhere else")
    func directionShowsOnlyOnTheActiveChip() {
        let row = ArrangementChip.row(for: .attribute(.bpm, .descending))
        for chip in row {
            if chip.basis == .attribute(.bpm) {
                #expect(chip.direction == .descending)
            } else {
                #expect(chip.direction == nil, "\(chip.basis.name) should not show a direction")
            }
        }
    }

    @Test("The computed Arrangements never show a direction")
    func computedChipsHaveNoDirection() {
        for arrangement in [Arrangement.artistSeparation, .shuffled] {
            let row = ArrangementChip.row(for: arrangement)
            let chip = row.first { $0.basis == arrangement.basis }
            #expect(chip?.isActive == true)
            #expect(chip?.direction == nil)
        }
    }

    @Test("Tapping the active chip flips its direction")
    func tappingActiveChipFlips() {
        let row = ArrangementChip.row(for: .attribute(.bpm, .ascending))
        let bpm = row.first { $0.basis == .attribute(.bpm) }
        #expect(bpm?.tapped == .attribute(.bpm, .descending))
    }

    @Test("Tapping an inactive chip applies it ascending, whatever was applied before")
    func tappingInactiveChipApplies() {
        let row = ArrangementChip.row(for: .attribute(.bpm, .descending))
        let energy = row.first { $0.basis == .attribute(.energy) }
        #expect(energy?.tapped == .attribute(.energy, .ascending), "direction must not carry over")
    }

    // MARK: - Shuffle

    @Test("Tapping the active Shuffle chip does not re-roll - that is its own control")
    func shuffleDoesNotRerollFromTheChipBody() {
        let row = ArrangementChip.row(for: .shuffled)
        let shuffle = row.first { $0.basis == .shuffle }

        #expect(shuffle?.isActive == true)
        #expect(shuffle?.tapped == .shuffled, "tapping twice must not mean two different things")
        #expect(shuffle?.showsReroll == true)
    }

    @Test("Only the active Shuffle chip offers a re-roll")
    func rerollOnlyWhenShuffleIsActive() {
        for arrangement in Arrangement.all where arrangement != .shuffled {
            let row = ArrangementChip.row(for: arrangement)
            #expect(row.allSatisfy { !$0.showsReroll }, "\(arrangement.name) offered a re-roll")
        }
    }

    @Test("Artist separation offers no re-roll - one arrangement, one result")
    func artistSeparationHasNoReroll() {
        let row = ArrangementChip.row(for: .artistSeparation)
        #expect(row.first { $0.basis == .artistSeparation }?.showsReroll == false)
    }

    // MARK: - Identity and copy

    @Test("Chips are uniquely identifiable, so the row animates rather than rebuilding")
    func chipsAreUniquelyIdentified() {
        for arrangement in Arrangement.all {
            let row = ArrangementChip.row(for: arrangement)
            #expect(Set(row.map(\.id)).count == row.count)
        }
    }

    @Test("A chip's name is the Arrangement's, not a bespoke label")
    func chipNamesComeFromTheDomain() {
        let row = ArrangementChip.row(for: .originalOrder)
        #expect(row.map(\.basis.name) == [
            "Original order", "BPM", "Energy", "Artist separation", "Shuffle",
        ])
    }
}

/// The picker sheet is where a listener who doesn't know what valence means gets
/// told, so its copy has to come from the same place the FAQ reads.
@Suite("Arrangement picker")
struct ArrangementPickerTests {

    @Test("The picker offers every Arrangement the app can produce")
    func offersEverything() {
        #expect(ArrangementChip.pickerBases == Arrangement.Basis.allCases)
        #expect(ArrangementChip.pickerBases.count == 15)
    }

    @Test("Every entry carries an explanation from the one source")
    func everyEntryIsExplained() {
        for basis in ArrangementChip.pickerBases {
            #expect(!basis.explanation.isEmpty, "\(basis.name) has no explanation")
            if let attribute = basis.attribute {
                #expect(basis.explanation == attribute.explanation)
            }
        }
    }
}
