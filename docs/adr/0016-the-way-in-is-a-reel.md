# 16. The way in is a reel, and the connect flow stands under a glyph

Date: 2026-08-09

## Status

Accepted.

## Context

Sorty's onboarding is two screens and `CONTEXT.md` is explicit that they are one
thing: the way-in screen, and the connect flow whose four steps *are* the
onboarding - "the two words name one thing".

Both were built to be read rather than to be arrived at. The way-in screen was a
mark, a title, a tagline and three points in a bulleted list. The connect flow
was a spine, then left-aligned prose, four times, distinguishable only by reading
it.

The instruction was to bring both closer to Beam
(`~/Dev/apps/beam/Apps/iOS/BeamiOS/OnboardingView.swift`), whose onboarding is
already the reference the splash was rebuilt against in ADR-0015.

## Decision

**The way in is Beam's reel. The connect flow keeps its structure and adopts
Beam's posture.**

- **`OnboardingReel`** ports Beam's `LoopOnBoarding`: three staggered pulse rings
  behind a symbol that bounces in time with them, the value props pushing up and
  blur-replacing beneath, phases advancing on a `TimelineView`.
- **`SignedOutView`** puts the three points through it, over `SplashBackdrop` -
  the same bloom the splash rises from, so launch and way-in read as one screen
  continuing rather than two screens meeting.
- **The connect flow** gains that backdrop, a per-step glyph, centred type, and a
  button that floats rather than sitting on a bar.
- **It is not a modal that rises.** Neither `sheet` nor `fullScreenCover`: both
  animate up from the bottom and iOS offers no way to change that, and a card
  also spent the top of every step on the inset and grabber. It is an overlay,
  which is the only way to choose the transition at all. It pushed in from the
  right for a while and now **cross-fades** - see the addendum below.

## What was deliberately *not* taken from Beam

Three things, because "similar to Beam" is not "identical to Beam" and the
differences are the interesting part.

**The four-step spine stays.** Beam has no equivalent - its stages simply
succeed one another. Sorty cannot afford that: it is about to ask someone to
register a developer application, and the spine's whole job is to show *the
shape of the ask before any of it is asked*. Removing it to match Beam would
have removed the one thing that makes four screens tolerable.

**The navigation title goes, but Back and Not Now stay.** Beam's onboarding
screens carry no chrome and offer exactly two buttons. Sorty needs three
affordances - advance, go back, and leave - because ADR-0007 made connecting the
only way in, and a modal nobody can escape is a worse first impression than the
way-in screen. So the toolbar survives with its title dropped: "Connect Spotify"
above "Sorty needs your own Spotify app" was the same sentence twice.

**No pulse rings on the connect steps.** Beam puts them on the screen that is
*searching* - actively scanning the network, with the rings saying so. Sorty's
last step is not searching; it is a button waiting for a finger. Rings there
would claim the app is working while it is idle. The one moment that screen
genuinely waits is after the tap, and the advance button already carries a
spinner for it (ADR-0015's test: did the listener do something, and are they
waiting to find out whether it worked?).

## Reduce Motion gets the old screen back

The reel does not run, and `SignedOutView` shows the three points as a still
list instead - which is exactly what this screen was before today.

This is not laziness about the reduced path, it is the honest reading of it. A
reel with its animation removed is still three lines of text replacing each other
on a timer, which is still movement, and it still hides two thirds of the content
behind a wait. Someone who has asked for less motion should not have to wait
nine seconds to learn what the app does. So the reduced form is not a quieter
reel; it is no reel.

## The bug this cost, and why it is worth writing down

The first build clipped the value props and the Connect button off both edges of
the display, and the cause was a piece of Beam I had "cleaned up".

Beam draws its pulse rings inside `Rectangle().foregroundStyle(.clear).overlay
{ … }`, which looks like a redundant wrapper. It is not. **A ring grows to twelve
times its own size - about 600pt - and a laid-out view that wide sizes everything
above it.** The reel became 600pt across, then so did the screen's stack, and
every child was laid out to a width half of which was off-screen. An overlay
never reports a size to its parent; a `ZStack` sibling does.

The same rule caught `SplashBackdrop`, whose blurred circle is also far wider
than the screen: it belongs in `.background { }`, never as a stack sibling. Both
call sites now say so in a comment, because the wrapper reads as noise and will
invite the same simplification again.

The general lesson: **in a ported layout, the odd-looking wrapper is load-bearing
until proven otherwise.** Beam's author did not write `Rectangle().overlay` for
fun.

## The onboarding travels one way, sideways

Both halves now move horizontally, and a step is a *page* rather than a screen
rearranging itself.

**In the reel, the props still rise from the bottom**, as Beam has them, and
that is deliberately a *different* axis from the pages. The two are different
kinds of movement: a page replaces what came before it and slides in from the
side to say so, while the three props are one screen's worth of copy rotating in
place with nothing being navigated. They were briefly moved sideways to match the
pages, which made the way-in screen look like it was advancing through something
it was not.

**In the connect flow**, the glyph, the words and the controls now travel
together under one `.id(step)`. Only the two `Text`s carried the transition
before, so a step change slid the heading sideways while the symbol above it and
the field below it were replaced in place. The error row deliberately stays put:
a failure belongs to the attempt, not to the step it happened on, and sliding it
away would take the explanation with it.

**`push(from:)` describes both halves of a transition, not one.** It enters from
the named edge and exits to the *opposite* one, so
`insertion: .trailing, removal: .leading` reads like "in from the right, out to
the left" and means the reverse - the outgoing prop left rightwards, into the one
arriving. One edge for both is correct, which is exactly what Beam wrote and what
I "improved" into an asymmetric pair.

This was caught by shooting ten frames 0.35s apart across a phase change and
stacking the crops, not by reading the code, which looked right. **A transition
is not verifiable from a still**, and the burst is the cheapest thing that makes
it verifiable at all.

## Consequences

**The app's name no longer appears on the way in.** The reel replaced the title
and tagline, as Beam's does. The mark carries identity, and the name is on the
icon the listener just tapped. If that turns out to be wrong, the reel is not
what needs undoing - a title above it is.

**One shot was added**, `37-connect-authorize`. The last step was the only one of
four the set never photographed, which is how it went unnoticed that it had
nothing to distinguish it from step three. It is appended rather than filed
beside `11`-`13`, because inserting it there collided with `14-playlists-two-up`
and would have renumbered half the set for one addition - the same reason the
withheld shots sit at the end.

**One button, and it is a back button all the way down.** `chevron.left`, with
its word kept as an accessibility label - a bare glyph with no accessible name is
a button that announces itself as "button".

The `xmark` beside it is gone, and pushing is what removed the need for it. A
modal that rises needs a dismiss affordance because there is no "back" from a
thing that came from nowhere. Pages that push have exactly one way back, and
going back off the first page is how you leave. So the chevron pops a step until
there are none, then closes.

The flow stays leavable at every step, which ADR-0007 requires - a way in nobody
can escape is a worse first impression than the way-in screen. It now takes the
number of taps the depth implies rather than one, which is the ordinary cost of a
stack and the reason iOS does not put an X on pushed screens either.

**Pushing costs the free `dismiss()`**, since nothing is being presented. Leaving
is handed in as a closure so the animation out matches the animation in.

**The spine is pinned, and sits *on* its blur rather than under it.**

It used to scroll with the page beneath a `TopBlur` overlay, and an overlay draws
above everything - so the only way to keep the progress track sharp was to push
it down until it cleared the band. That number was 76 points, measured against
step 1 because it is the only step with no Back button and so the tightest case,
and it left the track most of a thumb's width below the chevron.

Backing the spine with the blur instead is the library header's arrangement
(`PlaylistsView`): the track stays crisp on top, content passes under it, and it
can sit as high as it likes. The blur is trimmed eight points shorter than the
header it backs, so the fade starts just below the track rather than level with
it - the same trim, and the same reasoning, as the library's.

The general shape: **if something has to be pushed away from a blur to stay
legible, it belongs on top of the blur, not below it.**

## The onboarding travels one way, sideways

Both halves now move horizontally, and a step is a *page* rather than a screen
rearranging itself.

**In the reel, the props still rise from the bottom**, as Beam has them, and
that is deliberately a *different* axis from the pages. The two are different
kinds of movement: a page replaces what came before it and slides in from the
side to say so, while the three props are one screen's worth of copy rotating in
place with nothing being navigated. They were briefly moved sideways to match the
pages, which made the way-in screen look like it was advancing through something
it was not.

**In the connect flow**, the glyph, the words and the controls now travel
together under one `.id(step)`. Only the two `Text`s carried the transition
before, so a step change slid the heading sideways while the symbol above it and
the field below it were replaced in place. The error row deliberately stays put:
a failure belongs to the attempt, not to the step it happened on, and sliding it
away would take the explanation with it.

**`push(from:)` describes both halves of a transition, not one.** It enters from
the named edge and exits to the *opposite* one, so
`insertion: .trailing, removal: .leading` reads like "in from the right, out to
the left" and means the reverse - the outgoing prop left rightwards, into the one
arriving. One edge for both is correct, which is exactly what Beam wrote and what
I "improved" into an asymmetric pair.

This was caught by shooting ten frames 0.35s apart across a phase change and
stacking the crops, not by reading the code, which looked right. **A transition
is not verifiable from a still**, and the burst is the cheapest thing that makes
it verifiable at all.

## Consequences

**The app's name no longer appears on the way in.** The reel replaced the title
and tagline, as Beam's does. The mark carries identity, and the name is on the
icon the listener just tapped. If that turns out to be wrong, the reel is not
what needs undoing - a title above it is.

**One shot was added**, `37-connect-authorize`. The last step was the only one of
four the set never photographed, which is how it went unnoticed that it had
nothing to distinguish it from step three. It is appended rather than filed
beside `11`-`13`, because inserting it there collided with `14-playlists-two-up`
and would have renumbered half the set for one addition - the same reason the
withheld shots sit at the end.

**One button, and it is a back button all the way down.** `chevron.left`, with
its word kept as an accessibility label - a bare glyph with no accessible name is
a button that announces itself as "button".

The `xmark` beside it is gone, and pushing is what removed the need for it. A
modal that rises needs a dismiss affordance because there is no "back" from a
thing that came from nowhere. Pages that push have exactly one way back, and
going back off the first page is how you leave. So the chevron pops a step until
there are none, then closes.

The flow stays leavable at every step, which ADR-0007 requires - a way in nobody
can escape is a worse first impression than the way-in screen. It now takes the
number of taps the depth implies rather than one, which is the ordinary cost of a
stack and the reason iOS does not put an X on pushed screens either.

**Pushing costs the free `dismiss()`**, since nothing is being presented. Leaving
is handed in as a closure so the animation out matches the animation in.

**`padding(.top, 76)` on the flow's content is a measurement**, not a margin.
Dropping the navigation title raised the spine into `TopBlur`'s band - 44pt solid
plus a 20pt fade - and a smeared progress track reads as a rendering fault on the
one element whose whole job is to be legible at a glance.

It is measured **against step 1**, which is the tightest case: it is the only
step with no Back button, so its content starts higher than any other's. Going
full-screen looked like it should allow less - the card was insetting the content
and now the navigation bar does it - and 24 did look right on step 2. On step 1
it put the spine straight back under the blur. Any future adjustment gets checked
there, not on whichever step happens to be open.

## Addendum, 2026-08-09: the pages fit, and they smear

Two changes once the flow became a pushed page rather than a card.

**The page fills the space it is given.** As a sheet this was never visible,
because a card is only as tall as its content. A full-screen page is not: step 1
is a heading and two short paragraphs, and top-aligned on a 6.3" display that
left a hand's depth of nothing between the last line and Continue - which reads
as a screen that failed to finish loading. The content is centred between the
spine and the button now, via `minHeight` on the scroll content rather than a
plain centre, so the two steps that genuinely overflow still scroll.

**A page blurs while it travels**, through a shader driven by an `Animatable`
modifier - because a shader argument is not animatable on its own.
`.float(progress)` is read once when SwiftUI builds the view; `animatableData` is
what makes SwiftUI drive it frame by frame.

### Two things this cost, both worth keeping

**A `layerEffect` is not free when it is doing nothing.** Its presence forces an
offscreen pass, and SwiftUI cannot rasterize a UIKit-backed view that way - it
draws a yellow hatched placeholder with a prohibition sign instead. The Client ID
`TextField` is exactly that, so step 3 rendered its only control as a warning
label. `layerEffect(isEnabled: false)` did **not** fix it; the pass belongs to
the wrapper, not the shader.

The fix is structural rather than a gate: the controls travel with the page -
same distance, same fade, same timing - and never go under the shader at all.
Gating on progress would have fixed the resting case and still flashed the
placeholder through every transition into and out of that step. Nothing is lost,
because a text field smeared during a 250ms slide is not a legible text field
either.

**A transition cannot be photographed at the speed it runs.** `simctl io
screenshot` takes about 0.25s to return and the animation is 0.25s long, so a
burst lands on either side of it - measured, twice. `-advanceAfter N` drives one
step change and animates it over 1.6s, which is a DEBUG-only argument whose whole
purpose is to make the effect visible. What is verified is that `pageSmear`
resolves and draws; the duration has no bearing on that, and stretching it is the
difference between a photograph and a guess.

It is deliberately **not** in the screenshot set. A transition is not a screen,
and a single appended frame would be whichever moment the timing happened to land
on and would differ every run. The recipe is in `scripts/screenshots.sh` instead.

**The blur's strength was anchored rather than picked.** In the sideways version
a page travelled 120 points in 0.25s, about 8 points per frame at 60Hz, so 8 was
the physically honest smear; 18 was a little over twice that, and the first
attempt at 34 streaked the heading into ribbons, which at a glance reads as a
rendering fault rather than as motion. The radial version that replaced it keeps
the same discipline: its reach is 7.5% of each pixel's distance from the centre,
so the blur lengthens toward the edges as real radial motion does rather than
fogging the middle as hard as the corners.

## Addendum, 2026-08-10: dots, and depth instead of sideways

**The progress track is four dots in the toolbar**, level with the chevron. It
was four capsules stretched across the width, which drew a *bar* - and a bar
reads as a measure of how much work is left, which four short screens do not need
and which made the flow look longer than it is.

Moving it into the toolbar also retires the blur problem for good. Toolbar
content draws above the scroll view's overlay, so the dots stay sharp with
nothing pushing anything down - the pinned-header arrangement above was the right
fix for a spine that had to live *in* the page, and the better fix was for it not
to.

**Pages now arrive through depth rather than from the side.** The incoming one
grows in from slightly behind while the outgoing one carries on past the viewer,
both blurring radially. Two reasons beyond taste: four steps are a stack you
advance through rather than a filmstrip you pan along, and the sideways version
made a page change the same gesture as the flow's own arrival, which pushes in
from the right. A screen that enters exactly like the thing inside it changes is
a screen whose two motions say nothing different.

The blur had to change with it. Directional smearing suits a page with one
direction of travel; a page that *scales* has none - every pixel moves along its
own line out from the centre, and blurring along that line is what makes a scale
read as movement instead of as a resize.

**The scale is 6%, and small on purpose.** A page is a screenful of type, and
type that grows or shrinks by more than a few percent stops reading as
approaching and starts reading as a zoom effect applied to a document.


## Addendum, 2026-08-10: five screens, one screen

The four connect steps now look like the way-in screen, because they *are* it
with different words: `OnboardingGlyph` was lifted out of `OnboardingReel` and is
drawn by both. Before it, the reel led with a 100pt symbol ringed with pulses and
the steps led with a 44pt one with nothing behind it, and the two halves of one
flow looked like two apps.

**The rings are back on the connect steps**, which reverses a call made above.
That call was that rings imply *searching* and a step waiting for a tap is not
searching - true, and outweighed: consistency across five screens buys more than
the precision of one metaphor, and Beam puts the same treatment on screens that
are not searching either. What survives of the argument is `bounces`, which stays
off outside the reel: a glyph that bounces forever on a screen waiting for a
decision does read as something loading.

**One transition, everywhere.** Every page - the reel's props and all four steps
- now pushes up from the bottom and blur-replaces. A flow whose pages each arrive
differently reads as several flows.

That retires the depth transition and its shader, both deleted rather than left
to rot. They were good and they were the wrong answer to "make these look like
one thing": a bespoke motion on four of five screens is precisely the seam this
was meant to close.

**Text-heavy steps were cut to two lines with an info button beside them.** The
pages lead with a large glyph now, and that shape only works while the words can
be taken in at a glance - a paragraph under a 100pt symbol is a paragraph wearing
a hat. What did not fit moved to `ConnectStep.detail` rather than being deleted:
the arithmetic behind the cap, the PKCE explanation, the Keychain promise. A
listener in ten wants it and none of the other nine should have to read past it.

Two tests moved with the words. `firstStepNamesTheCap` and
`clientIDStepDisownsTheSecret` now assert against `body + detail` rather than
`body`, because what they protect is that the flow *answers* the question, not
which of its two surfaces answers it. A third was added: every step's `detail`
must say more than its `body`, or the info button is furniture that teaches
people to ignore it.


## Addendum, 2026-08-10: levelled by construction

The five screens looked alike and did not line up. The reel centred its glyph
with a fixed gap beneath it; the steps floated theirs between two `Spacer`s. So
the symbol and the heading sat at different heights on either side of one flow,
and moved again between steps as each page's text changed length.

`OnboardingPage` is now the only layout, used by the reel's three screens and the
flow's four.

**The first attempt at it did the levelling backwards** and is worth recording,
because it is the obvious mistake. Asked to make four screens match a fifth, it
conformed the fifth to the four: the reel was flattened into a top-anchored stack
with its words directly under its glyph, which levelled everything and threw away
the composition that was worth keeping - a glyph floating in the middle of the
screen with the words low, near the thing you tap. **The page that is liked is the
specification, not a participant in the negotiation.**

What the layout does now:

- **The words keep the reel's placement**, pinned to the bottom of whatever space
  a screen has, in a block of fixed height.
- **The glyph is pinned to the top**, at a fixed distance rather than centred.

Both are measured from an edge rather than from the content between them, which
is the whole reason they hold still while a page's text changes length.

**Nothing a step adds under the words may grow.** The spacer above the words is
what puts them on the bottom edge, and it can only do that while it is the one
view on the page that claims the leftover. A second flexible view anywhere below
it splits that space instead, and the whole block floats up into the middle of
the screen. A `Spacer` added to centre one step's button did exactly that to all
four steps, and it read as correct in review because the two views fighting over
the space are in different files. `OnboardingPage` now holds `extra` to its own
height so a caller cannot make that trade by accident. A step with controls still
pushes its words up by exactly the controls' height, which is the one intended
difference between a step and the first page.

**Centring cannot level these screens, and that is not obvious.** The reel and
the flow centre in different amounts of room - the flow loses a toolbar off the
top and carries a shorter footer than the way-in screen's button-plus-small-print
- so identical centring code put the glyph 35pt lower on the four steps than on
the first page. The two fixed values in `OnboardingMetrics` differ by exactly
that arithmetic.

It took stacking the same horizontal band from all five screenshots on top of
each other to see any of this. Side by side, five screens that are each internally
plausible look fine; stacked, a 35pt drift is unmissable. **Use the band stack
whenever the complaint is "these do not line up".**

**The reel's glyph holds still while its words move**, and that is the one place
the first screen differs from a connect step on purpose.

It was briefly made to travel with them, on the reasoning that half a screen
pushing while the other half cross-dissolved is a difference you feel without
being able to name. True, and wrong here: a step is a page you have moved to, so
the whole page arrives, but the reel is one screen talking and its glyph is
*mid-animation* - bouncing in time with its own rings. Sliding it off every three
seconds interrupts an animation meant to be continuous and restarts it from
nothing. `OnboardingWords` exists so the reel can transition the words alone
while the connect flow transitions the whole page, with one block of type serving
both.

**The way-in screen no longer names the cost.** A line of small print under the
button used to say that Spotify requires each listener to register a free
developer app. The first connect step still opens on exactly that, so the fact
arrives one tap later rather than not at all - which is what a clean foot costs
here, and worth knowing if that step's copy is ever cut further.

## Addendum, 2026-08-10: setup never leaves the app

Connecting an account means visiting Spotify's developer dashboard, creating an
application, copying a Client ID out of it, and pasting that into a field on the
screen you just left. Handed to Safari, that was a three-app errand - Sorty,
Safari, back to Sorty - across which the listener holds a string in their head
and the redirect URI they were told to copy *exactly* is two apps away.

**`InAppBrowser` keeps it here**, in both places setup reaches for the dashboard:
the connect flow's second step and Settings' Client ID section, which sits
directly above the field the dashboard exists to fill.

`SFSafariViewController`, not `WKWebView`. This is somebody's account and a login
form deserves the browser's own chrome saying whose site it is; a web view we
drew ourselves would ask them to trust an address bar we control. It also
**shares cookies and website data with Safari**, so anyone already signed in to
Spotify stays signed in.

**What still leaves, and should.** The attribution mark, Open on Spotify in the
track sheet, and the way out of a withheld playlist all hand off deliberately -
they exist to put the listener in Spotify, and Spotify's own guidelines ask for
the app where it is installed (ADR-0013). The rule is about *setup*: nothing
Sorty needs in order to work should require another app.

The dashboard button is Spotify's green in glass, prominent, with `arrow.up.right`
beside it - the glyph iOS uses wherever a control leads somewhere web-shaped. It
says a page opens without promising to leave, which is now the truth.


## Addendum, 2026-08-10: the flow fades in, and the link says what it is

**Way-in to first step is a cross-fade**, not a push from the right.

The push was right about one thing - this is not a modal rising from the bottom -
and wrong about another. By the time the two screens had been made to match, they
*were* matching: the same glyph in the same place over the same bloom, differing
only in their words. Sliding one off to reveal the other animated a journey
between two screens that mostly agree, and the parts that agree jumped. A
dissolve lets those parts hold still and changes only what actually changed.

It also needs no Reduce Motion branch, being already the reduced form of every
other transition here.

One thing to keep an eye on: the argument for dropping the `xmark` was that
"pages that push have one way back". A fade is not a push, so that sentence no
longer carries the decision on its own. The chevron-that-closes-from-step-one
still stands up by itself - four steps are a stack, and going back off the first
one is how you leave - but if a second way out is ever wanted again, this is the
paragraph that stopped justifying its absence.

**The link glyph is `arrow.up.forward.square`.** The same box as this app's own
save symbol on the way-in screen, inverted so the arrow leaves rather than
enters, and turned diagonal. `arrow.up.right` before it was a direction; this is
a thing being opened out of, which is what a link is - and it rhymes with a
symbol the listener met one screen earlier.

## Addendum, 2026-08-10: the info sheet is Beam's

`ConnectDetailSheet` was a `NavigationStack` with a title bar and a scroll of
prose on the default opaque panel. It is now Beam's sheet pattern:

- **A real Liquid Glass presentation background**, so the step underneath shows
  through refracted rather than being replaced by a grey slab. That matters more
  here than it would elsewhere - what the sheet explains is on the page directly
  behind it, and hiding that page to explain it is the wrong way round.
- **No navigation bar.** A centred bold title with a glass circle close on the
  trailing edge, which is what Beam's `BeamSheetHeader` does.
- **One surface card per paragraph.** `ConnectStep.detail` is written as
  blank-line-separated paragraphs, each answering a different question, and
  splitting them is the difference between a reference and a wall. Solid rows
  also stand out against glass in a way bare text on a translucent panel does
  not - which is Beam's reason for `beamRowCard`, and the same reason applies.

`-connectDetail` arrives with the sheet open, for the same reason `-sheet` exists:
it opens on a tap and this harness never taps. Shot over step 1, whose answer is
the longest of the four, so the set carries the shape at its most demanding.

## Addendum, 2026-08-10: one button, and one foot

The five screens were levelled by their glyphs and their words, and still did
not match at the bottom. The way-in screen drew a solid accent capsule -
`.buttonStyle(.plain)`, headline label, 15pt of air above and below. The four
connect steps drew `.glassProminent` at `.controlSize(.large)`. Different
material, different height, different corner, one tap apart.

**The button is now a `ButtonStyle`, `OnboardingButton`, and there is one of
it.** The way-in screen's, unchanged - it is the specification. Its only
parameter is the tint, because the tint is the only thing that ever legitimately
differs: Spotify's green on the two controls whose next stop is Spotify's own
site. Disabled and pressed faces belong to the style, so a caller says
`.disabled()` and gets the right one.

**A screen's foot is what levels it, and the foot is `buttonBottom` and nothing
else.** A screen's own space ends where its foot begins, so two screens whose
feet are the same depth put their words on the same line - and every unit of
padding added below the page comes back as drift above it. Three things were
quietly making the flow's foot deeper than the first page's, none of them
visible as a number anyone had chosen:

- 16pt of padding above the advance button, which is foot depth spelled
  differently. A step wanting air between its last control and the button now
  takes `buttonClearance` *inside* the page, where it pushes only its own words.
- `safeAreaInset(edge:)`'s **default spacing**, which is not zero. It held the
  words 12pt high with the buttons already levelled to the pixel and nothing in
  the source to point at. Pass `spacing: 0`.
- 4 and 16 points of padding on a control block that, on two of the four steps,
  **contains nothing**. An empty view still takes its padding.

Measured by stacking the same band from all five shots, per the practice above:
heading at 1958px and button at 2325px on the way-in screen and on every step
that carries no controls of its own.

**The create-app step has only buttons on it now.** The redirect URI was printed
in a box above the button, which made it the one step in the flow wearing a form.
The value moved into the ⓘ sheet, first card, above the prose that tells you what
to do with it - a tap away for the listener who wants to check it character by
character, which is the only reason to look at a URI at all, and out of the way
of everyone else, who copies it with the button and never needs to see it. There
is deliberately no copy control in the sheet: the page's button is how it is
copied, and a second one is the choice that button exists to remove.

The step's words changed with it. They read "add the redirect URI below", which
pointed at the box; they now name the two taps under them in order. **A line of
copy that points at something no longer on the screen is worse than one that says
nothing**, and it is invisible in a diff that only moved a view.

`39-connect-app-detail` shoots that sheet. The URI is in exactly one place in the
whole interface now, so a change that loses it has to be visible in the set.
