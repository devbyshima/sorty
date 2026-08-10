import Foundation

/// The questions, and the answers.
///
/// Here rather than typed into the view, for the reason `EmptyState` and
/// `SettingsText` are: these sentences carry every constraint Spotify's API puts
/// on this app, and three of them name dates. A claim about November 2024 that
/// no test can reach is a claim that quietly goes stale.
///
/// The arrangements are *not* here - they come from `Arrangement.Basis`, which
/// already carries its own name and explanation, and duplicating them would be
/// two places for one sentence to drift.
public enum FAQText {
    public static let title = "FAQ"

    public struct Entry: Identifiable, Equatable, Sendable {
        public let question: String
        public let answer: String
        public var id: String { question }

        public init(question: String, answer: String) {
            self.question = question
            self.answer = answer
        }
    }

    public static let arrangementsHeading = "The arrangements"

    /// What the app is and what it does with an account.
    public static let basics: [Entry] = [
        Entry(
            question: "How does it work?",
            answer: "Connect Spotify, pick a playlist, tap an arrangement to reorder it, then save the new order back."
        ),
        Entry(
            question: "Does it overwrite my playlist?",
            answer: "Only if you choose Overwrite This Playlist. The default saves a new playlist named after the arrangement you applied, and that option only appears for playlists you own."
        ),
        Entry(
            question: "Is my data safe?",
            answer: "Sorty never sees your Spotify password. Sign-in runs in Apple's own web authentication sheet. Your tokens live in the device Keychain and never leave it. There is no Sorty server, no account and no analytics."
        ),
    ]

    /// What Spotify will and will not do, which is most of what a listener runs
    /// into.
    public static let limits: [Entry] = [
        Entry(
            question: "Why are BPM and Energy sometimes blank?",
            answer: """
                Spotify shut off its audio-features endpoint in November 2024 for every app \
                registered after that date, and never shipped a replacement. Sorty gets those \
                numbers from ReccoBeats instead, whose catalogue is strong for music released up \
                to 2024 and patchy for newer releases. Anything it can't find shows a dash and \
                sorts to the bottom.
                """
        ),
        Entry(
            question: "Why do I need my own Client ID?",
            answer: "Spotify caps a development-mode app at five authorised listeners. A Client ID baked into Sorty would be full after five people, so everyone brings their own."
        ),
        Entry(
            question: "Why can't I open Discover Weekly?",
            answer: """
                Spotify stopped letting apps read its own playlists in November 2024 - the ones it \
                builds for you, like Discover Weekly and your Daily Mixes, and its editorial and \
                chart lists too. It applies to every app registered since, Sorty included, and \
                there is no permission that lifts it. Spotify sometimes lists those playlists \
                without describing them at all, which is what the note at the foot of your library \
                is counting.
                """
        ),
        Entry(
            question: "Can I arrange someone else's playlist?",
            answer: "Only if you're a collaborator on it. Since February 2026 Spotify sends a playlist's tracks to the people who own it or collaborate on it and to nobody else, so the rest are marked Can't open in your library. Ask for a collaborator's invite, or add the tracks to a playlist of your own and arrange that one."
        ),
        Entry(
            question: "What about podcast episodes?",
            answer: "Playlists can hold episodes alongside music. They appear in grey, have no acoustic attributes, and are preserved in place when you save."
        ),
        Entry(
            question: "What does Artist Separation do?",
            answer: "It rearranges the playlist so each artist's tracks are spread as evenly as possible, so you never hear the same artist twice in a row. It's computed on device, not fetched from anywhere."
        ),
        Entry(
            question: "Can I preview a track?",
            answer: "Not in Sorty. Spotify stopped serving 30-second preview clips to new apps at the same time it withdrew audio features. Swipe a row to open the track in Spotify instead."
        ),
    ]
}
