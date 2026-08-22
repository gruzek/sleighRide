# Holiday Sleigh Bells MVP 1 Roadmap

The Holiday Sleigh Bells app is a single capability: an app in symphony-goers' hands that
produces jingles during the performance of "Sleigh Ride," with additional interactions layered
on over time.

This roadmap has one capability (`C1`). The **MVP1 line** falls right after the two core
jingle interactions - tap and shake - delivered in the native build. Everything below that
line is a **stretch goal** - attempted as time allows before the late-November 2026 concert,
not a hard commitment for it.

**Direction as of 2026-08-22.** The project is a **native Godot mobile application**, built
and exported for iOS. This supersedes the single-page-app direction taken at the 2026-08-03
sponsor meeting, which was reversed. **Shake** and **tap** are both carried by the native
build; the accelerometer is available and load-bearing, and the shake instrument in `shake/`
is built and working. `C1_T05` and `C1_T06`, both of which existed only to serve the SPA
direction, are **superseded**. `C1_T01 TestFlight release`, deferred on 2026-08-03 pending
the SPA outcome, is **live again**.

> **Two things George needs to confirm here.** The date the reversal was decided is not
> recorded anywhere in the repository - the roadmap kept asserting the SPA while every
> feature built from 2026-08-18 onward (C1_07 through C1_14) was native-only work. And
> whether a sponsor-facing mockup deliverable still exists in some native form, or whether
> `C1_T05` is simply dead, is a scope call that has not been written down.

**Hard dates.** App Store publication (`C1_T02`) carries **2026-11-01** and is back in force
now that the native build is the delivery vehicle; allow for review lead time. The concert is
late November 2026. The 2026-09-02 dates on `C1_T05` and `C1_T06` lapse with those tasks.

**Legend.** Capabilities are numbered `C1`-`Cn`. Two kinds of work item appear under a
capability: **features**, identified by their `C<n>_NN_name` (capability number, then
sequence within the capability), which is also the feature filename and may change if
priorities shift, listed as numbered entries; and **tasks**, identified by their
`C<n>_T<NN>_name`, which are a roadmap entry plus a tracker issue only (no feature spec,
no implementation plan), listed under a **Tasks** sub-list. Each item carries a metadata
line: `depends on` (the `C<n>_NN` / `C<n>_T<NN>` names that must be `done` first, or
`none`), `effort` (S, M, or L), `value` (a tier plus a one-line statement), `due` (an ISO
date, or `none`), and `status` (`not started`, `in progress`, or `done`). A **quick win**
is any not-yet-done item with `effort: S` and `value: High or Medium` whose dependencies
are all `done`. The `next-up` skill reads this file as the single source of truth and uses
`due` to drive urgency; keep statuses, due dates, priorities, and ids current here.

> **Grounding note.** No product brief exists yet. This roadmap was captured from the
> sponsor meeting (`meeting-symphony-requirements.md`, product context only), the planning
> session, and the 2026-08-03 sponsor meeting (`meeting_recap_2026-08-03.md`). Authoring the
> product brief remains the outstanding foundation step - see the `/product-brief` call at
> the end.

## Ready to Validate

Nothing is deployed yet. Once a native build reaches testers through `C1_T01` (TestFlight),
it moves here for **playtesting** - the field-validation activity for the jingle experience
(does the moment land in a real room, on real phones, offline).

## C1 - Holiday Sleigh Bells Audience App

Capability detail: to be written (see the `/product-brief` call below). For now, grounded
in `meeting-symphony-requirements.md`, `meeting_recap_2026-08-03.md`, and the planning session.

An app symphony-goers hold during the performance of "Sleigh Ride" to produce on-screen
jingles. Built in Godot, portrait, delivered as a native mobile application. The shake
mechanic (accelerometer to jingle, with holiday art, font, sounds, and a Tap to Start overlay)
is built and working; MVP1 is shake and tap together in the native build. Clap mode, confetti,
selfie mode, and the QR collection are stretch goals on top of it.

1. **Tap-to-Jingle** (`C1_01`) - tap the screen and the on-screen bells jingle during "Sleigh Ride." A second way in for anyone not shaking, and the interaction that works with the phone held still. *(MVP1)*
   *depends on: none · effort: M · value: High, a second route into the moment that asks nothing of the phone's sensors · due: none · status: not started*
2. **Shake-to-Jingle** (`C1_02`) - shake the phone and the on-screen bells jingle. The original magical moment, and the richer of the two interactions. Built: the detector in `shake/` fires on measured constants (C1_09) and is integrated into the play screen (C1_10). *(MVP1)*
   *depends on: none · effort: M · value: High, the original magical moment and the interaction the product was conceived around · due: none · status: in progress*

> **MVP1 cutoff.** The line falls here. MVP1 = the native build carrying `C1_01` tap and
> `C1_02` shake, in testers' hands before the concert. Everything below is a stretch goal: in
> scope for the season, attempted as time allows, but not required for the concert.

3. [Clap Mode](C1_03_clap_mode.md) (`C1_03`) - a second crowd interaction alongside tap and shake. *(stretch)*
   *depends on: C1_01 · effort: S · value: Medium, a third way for the audience to participate · due: none · status: not started*
4. [Snow Confetti](C1_04_snow_confetti.md) (`C1_04`) - festive snow/confetti visual on the moment. *(stretch)*
   *depends on: C1_01 · effort: S · value: Medium, visual polish that adds to the on-screen effect · due: none · status: not started*
5. [Holiday Selfie](C1_05_holiday_selfie.md) (`C1_05`) - take a selfie with a holiday vignette and background overlay. *(stretch)*
   *depends on: C1_01 · effort: L · value: Medium, a shareable keepsake from the concert · due: none · status: not started*
6. [QR Collection and Unlocks](C1_06_qr_collection_unlocks.md) (`C1_06`) - "Pokemon Go" style: staff place QR codes around the lobby; patrons collect them to unlock backgrounds and selfie vignettes; supports donor-level branding and a possible merch tie-in. *(stretch)*
   *depends on: C1_05 · effort: L · value: Medium, drives lobby engagement and gives sponsors/donors a branded surface · due: none · status: not started*

**Tasks**

- **`C1_T05` SPA mockup** (George) - **SUPERSEDED 2026-08-22.** Would have built the audience flow as a single-page app exported for the web; never started. The SPA direction was reversed and this task dies with it, but its five-screen flow specification was the source the native screens were built against and remains readable in `features/C1_T05_spa_mockup.md`. *(superseded)*
  *depends on: n/a · effort: n/a · value: n/a · due: none · status: superseded*
- **`C1_T06` SPA native-presentation research** (George) - **SUPERSEDED 2026-08-22.** Asked whether a web app could present identically to a native app. Moot: the app is native. The research that was done is in `features/iphone_spa_exploration.md`. *(superseded)*
  *depends on: n/a · effort: n/a · value: n/a · due: none · status: superseded*
- **`C1_T04` Professional audio recording** (Julie) - professionally recorded jingle/bell audio to replace the prototype sounds. Julie is producing these, targeting before the 2026-09-02 meeting though not committed to that date. *(stretch)*
  *depends on: none · effort: M · value: Medium, raises audio quality above the placeholder sounds · due: none · status: in progress*
- **`C1_T03` Figma design and functionality options** (Christopher) - mock up design/functionality options to direct the look-and-feel and the stretch features. *(stretch-supporting)*
  *depends on: none · effort: M · value: Medium, gives the stretch work a design direction before it is built · due: none · status: not started*
- **`C1_T01` TestFlight release** (George) - get a native build into TestFlight so people can download and try it ahead of the concert. Deferred on 2026-08-03 pending the SPA outcome; **live again as of 2026-08-22** now that native is the delivery vehicle. Needs a new due date. *(MVP1)*
  *depends on: C1_02 · effort: S · value: High, opens early, wide playtesting before the night-of, and it is the only way the moment gets tested in a real room · due: none · status: not started*
- **`C1_T02` App Store release** (George) - publish to the App Store so patrons can download it at (and before) the concert. No longer under review: with the native build as the delivery vehicle, this is the channel. *(MVP1)*
  *depends on: C1_T01 · effort: M · value: High, the channel patrons download from; allow for App Store review lead time · due: 2026-11-01 · status: not started*

> **Status and Next Steps.** The native build carries `C1_02 Shake-to-Jingle` already, and
> the audience flow, snow, and title animation are built (C1_07 through C1_14). The immediate
> path is `C1_01 Tap-to-Jingle` to give the moment a second way in, then `C1_T01 TestFlight
> release` to get it into real hands, then `C1_T02 App Store release` against its 2026-11-01
> date. Julie's audio (`C1_T04`) runs in parallel. **This roadmap is behind the code**: several
> features built between 2026-08-18 and 2026-08-22 are not listed here at all, and the item
> statuses below have not been reconciled against what actually shipped.
> After MVP1, pick up the stretch goals as time allows - `C1_T03` (Figma) first to set
> direction, then `C1_03` clap mode and `C1_04` snow confetti (both small), with
> `C1_05` holiday selfie and `C1_06` QR collection as the larger reaches. Each stretch feature
> needs its spec (`/feature`), then a plan (`/plan`), then a build (`/build`).
>
> **Foundation gap.** There is still no product brief. Run `/product-brief` for
> Holiday Sleigh Bells so these items have a real foundation.
