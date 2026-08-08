import Foundation

/// Source of the acoustic attributes the BPM / Energy / Dance / Loud / Valence /
/// Acoustic columns are sorted by.
///
/// This is a protocol because Spotify closed the door on the endpoint the
/// original app was built around: `GET /v1/audio-features` returns 403 for every
/// app registered on or after 27 Nov 2024, extended quota now requires 250k MAU,
/// and Spotify has shipped no replacement. Sortify therefore treats the feature
/// source as swappable and degrades honestly when it has none.
public protocol AudioFeatureProviding: Sendable {
    /// Features for as many of `trackIDs` as the source knows about, keyed by
    /// Spotify track ID. Missing IDs are simply absent - never an error.
    func features(forTrackIDs trackIDs: [String]) async throws -> [String: AudioFeatures]

    /// Shown in Settings so the user knows where the numbers came from.
    var displayName: String { get }

    /// Set once the provider has proved it can't serve this account, so the UI
    /// can explain the blank columns instead of looking broken.
    var unavailabilityReason: String? { get async }
}

/// Used when no source is configured: every acoustic column is simply empty and
/// the remaining eight columns still sort.
public struct NoAudioFeatureProvider: AudioFeatureProviding {
    public let displayName = "None"
    private let reason: String

    public init(reason: String = "No audio-feature source is configured, so BPM, Energy, Dance, Loud, Valence and Acoustic are unavailable. Everything else still sorts.") {
        self.reason = reason
    }

    public func features(forTrackIDs trackIDs: [String]) async throws -> [String: AudioFeatures] { [:] }
    public var unavailabilityReason: String? { get async { reason } }
}
