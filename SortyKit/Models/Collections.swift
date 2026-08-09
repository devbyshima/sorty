import Foundation

extension Array {
    /// Splits into fixed-size batches. Every Spotify and ReccoBeats bulk
    /// endpoint caps how many IDs one request may carry.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return isEmpty ? [] : [self] }
        guard !isEmpty else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
