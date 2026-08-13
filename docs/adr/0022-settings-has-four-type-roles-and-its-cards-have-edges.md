# 22. Settings has four type roles, and its cards have edges

Date: 2026-08-13

## Status

Accepted. Refines [ADR-0017](0017-collaboration-is-a-fact-not-a-feature.md)'s
settings rebuild rather than reversing it: the card-and-dotted-divider idiom, the
absence of section headers, and the largeTitle-root/inline-sub-page split all
stand.

## Context

The settings screens were rebuilt as pages of cards and stopped looking like
`Form`, which was the whole of ADR-0017's goal and which it achieved. What it did
not do was give the type inside those cards any roles, and the result read as
congested even where the information architecture was sound.

Measured on the shipped screens:

- **Three unrelated jobs collided at `.caption`.** A select row's per-option
  explanation, a page-level footnote, and a credential field's label were all
  12pt secondary. So on the Audio features screen, a paragraph you had to read in
  order to make a choice was set identically to the footer under it.
- **The Audio features screen was 62% one size.** 21 of its 24 lines were 12pt
  secondary grey. Three levels of importance existed in the content and one
  existed on screen.
- **Cards had no edges in light Appearance.** `SortyTheme.surface` is pure white
  and `background` is rgb(0.957, 0.957, 0.969) - about 1.09:1. Every other
  card-like surface in the app already takes `SortyTheme.cardShadow`;
  settings cards were the only ones without it, so the grouping the whole design
  rests on was invisible on the Appearance the app mostly ships in.
- **Cards were closer to each other than rows were to their neighbours.**
  `cardSpacing` was 20 while two rows inside one card sat 26pt apart. Proximity
  argued against the grouping the cards existed to express.
- **Dividers were inset past an icon column on screens whose rows have no
  icons.** All 22 dotted rules on the FAQ floated 40pt right of the questions they
  divide, aligned with nothing.

Two of the findings were not typographic at all and are the reason this is an ADR
rather than a commit message. The FAQ's disclosure rows padded *outside* their
`Button`, so 25 rows had a tap target of roughly 22pt against the 44pt minimum;
and the Appearance row's `Menu` wrapped only its trailing value, so tapping the
word "Appearance" or its glyph did nothing.

## Decision

**Four type roles, each with exactly one job across all five screens.**

| Role | Style | Where |
|---|---|---|
| Page title | `.largeTitle.bold()` / `.title3` inline | the bar |
| Row title | `.body` primary | every row on every screen, including an FAQ question |
| Paragraph | `.footnote` secondary | anything 2+ lines that must be read |
| Note | `.caption` secondary | `SettingsExplainer`, and nothing else |

`.footnote` and `.caption2` are retired as *text* roles and survive only as glyph
sizes, where they are not read as words.

**`SettingsCard` takes `SortyTheme.cardShadow`**, at the radius and offset
`PlaylistTile` already uses, so a settings card sits at the same elevation as a
playlist card. Dark is unaffected; `cardShadow` returns `.clear` there.

**`cardSpacing` is 30 and attached things sit at `attachedGap`, which is 8.** A
note or a heading that belongs to a card bonds to it - the note upward, the
heading downward - and unrelated cards stand well clear. The ratio, not either
number, is what makes ownership unambiguous.

**Dividers take an inset the card is told, not one it assumes.**
`SettingsCard(dividerInset: 0)` on the FAQ and on the credential fields.

**Prose gets `.lineSpacing(2)`**, taking the paragraph roles to about 1.5 from
iOS's default 1.33, which is tuned for labels rather than for the four-to-eight
line blocks these screens carry.

**The "why" goes above the choice.** `SettingsLead` is a new component for the
one paragraph a screen needs before its card, replacing a footer that was read
after the decision it explained.

## Consequences

**Copy was cut, not just restyled, and that is most of the win.** The Audio
features footer restated three facts the rows above it already stated and named
the six audio columns a second time in a different vocabulary ("Dance, Loud,
Acoustic" against the rows' "Danceability, Loudness, Acousticness"). It is gone,
replaced by a two-line lead-in that names them once. The three option
explanations went from 25-29 words each to at most two lines. `spotifyAppLimits`
went from 52 words to 12, with its redirect-URI troubleshooting moved to the FAQ
where a reader arrives *after* hitting the problem.

**One number was quietly wrong and is now absent.** "The other nine columns come
straight from Spotify" is not checkable against the model - `Attribute` has 13
cases, 6 of them audio features, which leaves 7. Nine was the count of
non-feature *arrangements*, a different thing wearing the word "columns". The
replacement states no count.

**`openDashboard` lost the word "Open".** It measured about 269pt at `.body`
against roughly 263pt of title width, so it wrapped at the *default* text size
and `SettingsRowLabel` centred its leading glyph in the gutter beside neither
line. The trailing `SettingsExternalIcon` already says the row leaves the app.

**The Client ID field is `.subheadline`, sized against the string it holds.** A
Spotify Client ID is 32 hex characters; at `.body` monospaced that needs 326pt
against the 314pt the field has, so the value this stacked layout exists to show
in full was truncating - and so was its own prompt.

**Two touch targets were under the HIG minimum and are not any more**, which is
the finding that would have justified this work on its own.

**`SettingsRowLabel` aligns its glyph to the first text baseline rather than to
the row's centre.** At the default text size every title fits one line and the
two are indistinguishable; at an accessibility size a title that breaks onto
three lines left a centred glyph floating in the gutter beside the middle of a
word. The accessibility sizes are where a settings screen's layout decisions get
tested, and they are worth re-shooting after any change here.

**Settings' root went from five cards to four.** Appearance joined the card
holding Spotify app and Audio features - all three are things you set, all three
carry a trailing value. Sign out keeps a card to itself, which is the one
single-row card that earns one.

**The FAQ's 15-row arrangements card is unchanged and remains the longest thing
in Settings.** Pushing it to its own destination was considered and not done: it
is a reference list a reader scrolls deliberately, and the fix that mattered -
dividers aligned to the text, questions at the row-title size, and a real section
heading above it - is applied.
