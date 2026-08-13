# 25. Fetched covers are held, and the demo catalogue was hiding that they weren't

Date: 2026-08-13

## Status

Accepted. Reverses a decision recorded only as a comment in
`CoverImageLoader`, and fixes the snap on collapsing a playlist that
[ADR-0024](0024-the-zoom-grows-from-the-cover.md) made more visible by aiming the
zoom at a cover.

## Context

`CoverImageLoader` held drawn covers and deliberately held no fetched ones:

> Fetched covers are deliberately absent: `URLSession` already caches the bytes,
> and a second cache of decoded images would grow with the size of the
> listener's library.

The premise is true and the conclusion does not follow. An *unbounded* cache
grows with the library. What was built instead was no cache at all, so every
appearance of every cover ran a fresh `CGImageSourceCreateImageAtIndex` - not
only the first sight of it, but every scroll back up the library, and every
return from a playlist.

**Nothing in this repository could see it.** Demo covers are drawn on device and
were always cached, so the entire harness - every screenshot, every ad-hoc
capture, every test - went down the `drawn` branch. The fetched branch is reached
only by a listener with a Spotify account, and it is the branch that ships.

The visible symptom was reported as the library "snapping in place" on collapsing
a playlist, and it is exactly what the code produces. Coming back rebuilds the
cells; `CoverImage`'s `image` is `@State` and starts nil; the shimmer draws; the
decode finishes in well under the 100ms that `wasWaited` uses to decide whether
anybody saw the wait - so the artwork replaces the placeholder with no fade at
all. A hard cut on every cover at once, at the moment the zoom is collapsing into
one of them.

## Decision

**Decoded fetched covers are held in `CoverImageCache`, bounded by bytes.**

Bytes rather than count, because that is the axis that actually threatened
memory: a 640x640 cover is about 1.6MB, so the 240 entries the drawn cache allows
would be nearly 400MB at that size. 48MB holds roughly thirty full-size covers or
a great many thumbnails - more than a library screen and a playlist screen need
at once.

**The cache is readable synchronously, and that is why it is not inside the
actor.** An actor can only be asked with `await`, and `CoverImage` asks from
`.task(id:)`, which runs after the view has already drawn once. So even a perfect
cache behind an actor leaves the first frame of every cover as a placeholder. A
cover the app already holds must be on screen in the first frame that shows it,
and that requires a question that does not suspend. `CoverImage` reads the cache
in its body; `load` adopts the same value and returns without an actor hop.

**Reading does not promote the entry.** The read happens in a view body, which
runs for reasons unrelated to what the listener is looking at, so letting reads
reorder the LRU would make eviction a function of SwiftUI's invalidation. `store`
promotes; `image(for:)` does not.

## Consequences

**A `file:` URL is now a test seam for the fetched path.** `URLSession` serves
them, so `FetchedCoverTests` takes the real branch: it writes a PNG, resolves it,
deletes the file, and resolves it again. The second answer can only have come
from the cache. That test exists because the absence of one is how this survived
- the drawn path had five tests and the fetched path had none.

**The demo catalogue is a good harness and a poor witness.** It made Demo Mode
offline and deterministic, which is what it is for, and in doing so it routed
every observation in this repo away from the code a listener actually runs. Worth
remembering the next time something is "verified" against it: `-demo` proves the
drawn branch works.

**Nothing about the compliance boundary moves.** Held artwork is still drawn in
its original form, unmodified, with the shimmer strictly on the placeholder
(ADR-0015, ADR-0020). Caching a decoded image is not a transformation of it.

**48MB is a budget, not a measurement.** It was chosen from the arithmetic above
rather than from a memory trace on a real library. If Sorty is ever jettisoned in
the background while a large library is loaded, this is the first number to look
at.
