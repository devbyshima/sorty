import Foundation

/// The span of one Attribute across a playlist, and where a given track sits
/// inside it.
///
/// The range is the *playlist's*, not the Attribute's theoretical scale. A
/// playlist of uniformly fast tracks measured against 0–200 BPM would bunch
/// every bar at the same length and say nothing; measured against its own
/// 170–180 it shows which track is the fastest. That is the whole point of the
/// bar - the shape of an arrangement, legible while scrolling, without reading
/// the numbers.
public struct AttributeRange: Equatable, Sendable {
    public let attribute: Attribute
    public let minimum: Double
    public let maximum: Double

    /// Every track scored the same, so there is nothing to place anything
    /// within. No track is higher than another, and no bar is drawn - see
    /// `fraction(for:)`.
    public var isDegenerate: Bool { minimum == maximum }

    /// Nil when there is nothing to measure: an Attribute with no magnitude has
    /// no line for a value to sit on, and an Attribute no track has a value for
    /// has no range at all.
    public init?(attribute: Attribute, rows: [TrackRow]) {
        guard attribute.isPlottable else { return nil }

        var low = Double.infinity
        var high = -Double.infinity
        for row in rows {
            guard let value = row.plottableValue(for: attribute) else { continue }
            low = Swift.min(low, value)
            high = Swift.max(high, value)
        }
        guard low <= high else { return nil }

        self.attribute = attribute
        self.minimum = low
        self.maximum = high
    }

    /// Where this track sits, 0 at the playlist's lowest and 1 at its highest.
    ///
    /// Nil means "draw no bar", and it covers both ways a bar can have nothing
    /// to say: the track has no value, or every track has the same one. Absence
    /// is the honest rendering for both - a full bar on every row of a
    /// single-value playlist asserts a ranking nobody measured, and an empty
    /// one asserts the opposite.
    public func fraction(for row: TrackRow) -> Double? {
        guard !isDegenerate, let value = row.plottableValue(for: attribute) else { return nil }
        let fraction = (value - minimum) / (maximum - minimum)
        return Swift.min(Swift.max(fraction, 0), 1)
    }
}
