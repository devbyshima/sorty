# 11. Glass is edged in light

Date: 2026-08-08

## Status

Accepted. Completes the light Appearance work `SortifyTheme` began.

## Context

`SortifyTheme` already authors both Appearances. Its own doc comment states the
principle: light carries elevation with **edges** where dark carries it with
**luminance**, which is why light has a hairline, a pure white card on a tinted
field, and a card shadow that dark does not get.

Liquid Glass never got that edge, and it is the material the app's primary
control is made of: the Arrangement chips, the category chips, the search field,
the top bar buttons and the Save circle are all `.glassEffect(.regular, in:)`.

Measured from the harness set, sampling the chip row on both the library and the
playlist screens, and converted to CIE L\* because relative-luminance *ratios*
compress badly near white:

| | glass at rest | field | separation |
| --- | --- | --- | --- |
| Light | L\* 97.3 | L\* 96.3 | **ΔL\* 1.0** |
| Dark | L\* 15.2 | L\* 3.6 | **ΔL\* 11.6** |

Liquid Glass lifts off its background by lightening. A near-white field gives it
nowhere to lift to, so the same control that reads as a raised capsule in dark
reads in light as a label floating on the page. The active state was never the
problem: an applied chip is filled with the accent and is unmistakable in both.
What light lost was the resting state, so **which chips exist** was hard to see
while **which chip is applied** was obvious.

## Decision

**Every glass surface draws `SortifyTheme.glassEdge` in its own shape**, through
one `View.glassEdge(in:)` helper, at all ten call sites. The token is black at
12% in light and white at 6% in dark, so the Appearance that needs the edge gets
it and the Appearance that does not is left as it was.

Measured after: the boundary in light sits at L\* 76.7 against the L\* 96.3
field, moving the resting capsule from ΔL\* 1.0 to **ΔL\* 19.6**. Dark is
unchanged within measurement noise.

**This deliberately does not meet WCAG 1.4.11's 3:1 boundary contrast**, and the
choice is considered rather than missed. That criterion applies to visual
information *required to identify* a component or its state. These capsules are
identified by their label, which clears AA against the field, and their applied
state by an accent fill at 5.4:1. Reaching 3:1 on the outline alone would need
roughly a 58% grey, which turns a row of light capsules into a row of bordered
buttons and changes what the screen is. The edge exists so a capsule reads as an
object, not to carry meaning.

## Consequences

**Light and dark now express the same elevation two different ways**, which is
the intent: neither is the real design with the other derived from it
(`CONTEXT.md`, Appearance).

**Ten call sites gained a line, and none of them chose a value.** A call site
that wants a different edge is a change to the token, not to the site. If glass
ever appears on a *dark* surface inside light Appearance the token will be wrong
there, because it resolves on the Appearance rather than on what is behind it.
Nothing does that today.

**The Save circle is edged in both its states**, including armed, where the
accent already carries the shape and the edge is nearly invisible against it.
Exempting it would have made the one control the screen exists for the only
glass in the app that behaves differently.

**If reopened:** the alternative considered and not taken was deepening the
light field so the material has somewhere to lift to. It is a single token
change and it would raise the separation everywhere at once, but it moves the
ground under every screen to fix one family of surfaces, and a near-white field
is what makes the pure white cards read as raised at all.
