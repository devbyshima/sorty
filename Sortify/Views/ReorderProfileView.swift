#if DEBUG
import SwiftUI

/// Drives the real track list through a series of reorders and reports what
/// each one cost. `-screen profile -count 400`.
///
/// The output is the evidence behind `ReorderAnimation.rowLimit`. It prints
/// rather than renders, because it is read from `devicectl … --console` on a
/// phone, and the phone is the only place the numbers mean anything.
struct ReorderProfileView: View {
    let count: Int

    @State private var model: TrackListModel
    @State private var profiler = ReorderProfiler()
    @State private var report: [String] = []
    @State private var done = false

    init(count: Int) {
        self.count = count
        _model = State(
            initialValue: TrackListModel(
                playlist: Playlist(
                    id: "profile", name: "Profile \(count)", uri: "spotify:playlist:profile",
                    owner: PlaylistOwner(id: "profile"),
                    tracks: PlaylistTrackCount(total: count)
                ),
                service: ProfilingMusicService(count: count),
                featureProvider: ProfilingFeatureProvider(),
                currentUserID: nil
            )
        )
    }

    /// Six reorders, each moving every row: the Attributes are generated on
    /// coprime strides so no two agree on an order, and a reorder that moved
    /// nothing would measure nothing.
    private let sequence: [Arrangement] = [
        .attribute(.bpm, .descending),
        .attribute(.energy, .ascending),
        .attribute(.valence, .descending),
        .artistSeparation,
        .shuffled,
        .originalOrder,
    ]

    var body: some View {
        NavigationStack {
            TrackListView(model: model)
        }
        .task { await run() }
    }

    private func run() async {
        await model.load()
        // One settling second before measuring, so the load's own work isn't
        // counted as the reorder's.
        try? await Task.sleep(for: .seconds(1))

        print("REORDER-PROFILE rows=\(count) limit=\(ReorderAnimation.rowLimit)")

        // Three passes. A single reorder produces one number, and one number
        // off a 60Hz sampler is noise — the pass that happens to miss the spike
        // reports zero and would argue the cost had vanished.
        for arrangement in sequence + sequence + sequence {
            profiler.start()
            withAnimation(.snappy) { model.apply(arrangement) }
            // Longer than `.snappy` takes to settle, so the tail of the spring
            // is measured too — that is where a struggling list gives up.
            try? await Task.sleep(for: .milliseconds(900))
            let result = profiler.stop()

            let line = String(
                format: "REORDER-PROFILE rows=%d arrangement=%@ frames=%d late=%d worst=%.2fx",
                count, arrangement.argument, result.frames, result.late, result.worst
            )
            print(line)
            report.append(line)
        }

        await measureRapidSwitching()

        print("REORDER-PROFILE done rows=\(count)")
        done = true
    }

    /// Six Arrangements in half a second — faster than anyone can tap, and the
    /// case the ticket asks about: do the springs queue, or does one spring
    /// keep changing its mind?
    ///
    /// If they queued, the sampling window would show sustained late frames
    /// rather than the same one-or-two spikes a single reorder produces.
    private func measureRapidSwitching() async {
        profiler.start()
        for arrangement in sequence {
            withAnimation(.snappy) { model.apply(arrangement) }
            try? await Task.sleep(for: .milliseconds(80))
        }
        try? await Task.sleep(for: .milliseconds(900))
        let result = profiler.stop()

        print(
            String(
                format: "REORDER-PROFILE rows=%d arrangement=RAPID-BURST frames=%d late=%d worst=%.2fx",
                count, result.frames, result.late, result.worst
            )
        )
    }
}
#endif
