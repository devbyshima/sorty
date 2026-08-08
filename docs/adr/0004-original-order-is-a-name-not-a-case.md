# 4. Original order is a name, not a case

Date: 2026-08-05

## Status

Accepted. Amends one sentence of `.scratch/ui-redesign/spec.md`; implemented by
ticket 02.

## Context

The redesign spec describes the new ordering type as *"an **Arrangement** type
whose cases are Attribute-derived orderings (carrying an Attribute and a
direction) plus the computed ones - Artist separation, Shuffle, Original
order."* Read literally, that asks for three computed cases, one of them
`originalOrder`.

The same spec also fixes the size of the Attribute type: ticket 02 says
*"**Attribute** covers the thirteen measurable properties."* Today's
`SortColumn` has fifteen cases; removing artist separation and shuffle leaves
exactly thirteen - and that thirteen **includes** `order`, the track's position
in the playlist. So position is an Attribute.

Those two readings collide. If `order` is an Attribute and `originalOrder` is
also a case, then `.attribute(.order, .ascending)` and `.originalOrder` are two
values denoting one ordering. They compare unequal, and `TrackTableModel.canSave`
decides whether anything has changed by comparing the applied arrangement
against the saved one. Two spellings of "unchanged" would make Save offer itself
on a playlist nobody rearranged - and the redesign's active-chip highlight and
reorder animation would inherit the same fault.

`CONTEXT.md`, which is authoritative on vocabulary, names only Artist separation
and Shuffle as computed. Those two are computed because *no track carries the
value*. A track does carry its position, exactly as it carries its date added.

## Decision

`Arrangement` has three cases - `.attribute(Attribute, Direction)`,
`.artistSeparation`, `.shuffle` - and **Original order is
`Arrangement.attribute(.order, .ascending)`, exposed as `static let
originalOrder`**.

It reads as a case at every use site (`case .originalOrder:` still pattern-matches
via `Equatable`) while being one value.

## Consequences

Every distinct ordering has exactly one value, so `canSave` is correct rather
than approximately correct.

Reversed original order stays representable as
`.attribute(.order, .descending)`. This is not academic: the fifteen-column
table's `#` header reverses the playlist on a second tap, and a payload-free
`case originalOrder` would have made that behaviour impossible to express.
A `case originalOrder(Direction)` would have re-created the duplicate.

Nothing suppresses the duplicate spelling, because it does not exist - there is
no normalizing initializer for a future caller to route around. The two reasons
someone would reach for the case are pre-empted: `Basis.originalOrder.name`
already gives the label "Original order", and `Arrangement.direction` is an
`Optional`, which is how artist separation and shuffle drop the direction arrow.
Adding a duplicating case would break every exhaustive switch over `Arrangement`
at once.

Ticket 03's chip set still presents Original order as one of the five pinned
peers. A chip is a `Basis`; `Basis.attribute(.order)` is a peer of
`.artistSeparation` and `.shuffle` there, so the spec's intent survives at the
layer it was actually about.

**Amended by ticket 03.** When this was written the invariant held in one
direction only: `.shuffle` was a single value standing for whichever order the
current random values happened to produce, so re-rolling did not re-arm Save.
Ticket 03 gave it the seed payload - `case shuffle(seed: UInt64)`, keyed through
SplitMix64 rather than `Hasher`, which is seeded per process and would make a
shuffled screenshot unreproducible. The invariant now holds both ways: no two
values denote the same ordering, and every value determines its ordering
completely.
