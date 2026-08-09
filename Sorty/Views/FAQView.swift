import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FAQItem(
                        question: "How does it work?",
                        answer: "Connect Spotify, pick a playlist, tap an arrangement to reorder it, then save the new order back."
                    )
                    FAQItem(
                        question: "Does it overwrite my playlist?",
                        answer: "Only if you choose “Overwrite This Playlist”. The default saves a new playlist named after the arrangement you applied, and that option only appears for playlists you own."
                    )
                    FAQItem(
                        question: "Is my data safe?",
                        answer: "Sorty never sees your Spotify password. Sign-in runs in Apple's own web authentication sheet. Your tokens live in the device Keychain and never leave it. There is no Sorty server, no account and no analytics."
                    )
                }

                Section("The arrangements") {
                    ForEach(Arrangement.Basis.allCases) { basis in
                        FAQItem(question: basis.name, answer: basis.explanation)
                    }
                }

                Section {
                    FAQItem(
                        question: "Why are BPM and Energy sometimes blank?",
                        answer: """
                            Spotify shut off its audio-features endpoint in November 2024 for every \
                            app registered after that date, and never shipped a replacement. Sorty \
                            gets those numbers from ReccoBeats instead, whose catalogue is strong for \
                            music released up to 2024 and patchy for newer releases. Anything it \
                            can't find shows a dash and sorts to the bottom.
                            """
                    )
                    FAQItem(
                        question: "Why do I need my own Client ID?",
                        answer: "Spotify caps a development-mode app at five authorised listeners. A Client ID baked into Sorty would be full after five people, so everyone brings their own."
                    )
                    FAQItem(
                        question: "Can I arrange someone else's playlist?",
                        answer: "Only if you're a collaborator on it. Since February 2026 Spotify sends a playlist's tracks to the people who own it or collaborate on it and to nobody else, so the rest are marked “Can't open” in your library. Ask for a collaborator's invite, or add the tracks to a playlist of your own and arrange that one."
                    )
                    FAQItem(
                        question: "What about podcast episodes?",
                        answer: "Playlists can hold episodes alongside music. They appear in grey, have no acoustic attributes, and are preserved in place when you save."
                    )
                    FAQItem(
                        question: "What does Artist Separation do?",
                        answer: "It rearranges the playlist so each artist's tracks are spread as evenly as possible, so you never hear the same artist twice in a row. It's computed on device, not fetched from anywhere."
                    )
                    FAQItem(
                        question: "Can I preview a track?",
                        answer: "Not in Sorty. Spotify stopped serving 30-second preview clips to new apps at the same time it withdrew audio features. Swipe a row to open the track in Spotify instead."
                    )
                }

                Section("Credits") {
                    Text("Sorty is an iOS port of Paul Lamere's Sort Your Music, which has been sorting playlists on the web since 2012.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Sort Your Music on GitHub", destination: URL(string: "https://github.com/plamere/SortYourMusic")!)
                        .font(.footnote)
                    Text("Not affiliated with or endorsed by Spotify.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
}

private struct FAQItem: View {
    let question: String
    let answer: String

    var body: some View {
        DisclosureGroup {
            Text(answer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        } label: {
            Text(question)
                .font(.subheadline.weight(.medium))
        }
    }
}
