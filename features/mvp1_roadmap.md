# Holiday Sleigh Bells MVP 1 Roadmap

The Holiday Sleigh Bells app is a single capability: an app in symphony-goers' hands that
produces jingles during the performance of "Sleigh Ride," with additional interactions layered
on over time.

This roadmap has one capability (`C1`). The **MVP1 line** falls right after the two core
jingle interactions - tap and shake - delivered through the SPA mockup. Everything below that
line is a **stretch goal** - attempted as time allows before the late-November 2026 concert,
not a hard commitment for it.

**Direction as of 2026-08-03.** The project is now aiming at a single-page app built in Godot
rather than a native iOS build. **Tap** is the focus interaction; **shake** is kept in the
background rather than dropped. The native path is not deleted, but `C1_T01 TestFlight release`
is deferred pending the SPA outcome. See `meeting_recap_2026-08-03.md`.

**Hard dates.** The SPA mockup (`C1_T05`) and the presentation research (`C1_T06`) are due
before the **2026-09-02** sponsor meeting. App Store publication (`C1_T02`) still carries
**2026-11-01**, though whether an App Store release is needed at all depends on the SPA
outcome. The concert is late November 2026.

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

Nothing is deployed yet. Once `C1_T05` (SPA mockup) lands, the build moves here for
**playtesting** - the field-validation activity for the jingle experience (does the moment land
in a real room, on real phones, offline).

## C1 - Holiday Sleigh Bells Audience App

Capability detail: to be written (see the `/product-brief` call below). For now, grounded
in `meeting-symphony-requirements.md`, `meeting_recap_2026-08-03.md`, and the planning session.

An app symphony-goers hold during the performance of "Sleigh Ride" to produce on-screen
jingles. Built in Godot, portrait, now targeting a single-page app. The shake mechanic
(accelerometer to jingle, with holiday art, font, sounds, and a Tap to Start overlay) is
already built as a native iOS prototype; MVP1 is the tap-focused SPA mockup with shake
retained. Clap mode, confetti, selfie mode, and the QR collection are stretch goals on top of it.

1. **Tap-to-Jingle (focus)** (`C1_01`) - tap the screen and the on-screen bells jingle during "Sleigh Ride." The lead interaction as of 2026-08-03; needs no accelerometer, so it survives a SPA delivery. *(MVP1)*
   *depends on: none · effort: M · value: High, the interaction the app now leads with, and the one that works without native sensor access · due: 2026-09-02 · status: not started*
2. **Shake-to-Jingle (background)** (`C1_02`) - shake the phone and the on-screen bells jingle. Already built as a native iOS prototype; kept alongside tap rather than dropped, pending the accelerometer question in `C1_T06`. *(MVP1)*
   *depends on: none · effort: M · value: High, the original magical moment, retained as the richer interaction where the platform supports it · due: 2026-09-02 · status: in progress*

> **MVP1 cutoff.** The line falls here. MVP1 = the tap-focused SPA mockup (`C1_T05`) carrying
> `C1_01` tap and `C1_02` shake, in hand before the 2026-09-02 meeting. Everything below is a
> stretch goal: in scope for the season, attempted as time allows, but not required for the
> concert.

3. [Clap Mode](C1_03_clap_mode.md) (`C1_03`) - a second crowd interaction alongside tap and shake. *(stretch)*
   *depends on: C1_01 · effort: S · value: Medium, a third way for the audience to participate · due: none · status: not started*
4. [Snow Confetti](C1_04_snow_confetti.md) (`C1_04`) - festive snow/confetti visual on the moment. *(stretch)*
   *depends on: C1_01 · effort: S · value: Medium, visual polish that adds to the on-screen effect · due: none · status: not started*
5. [Holiday Selfie](C1_05_holiday_selfie.md) (`C1_05`) - take a selfie with a holiday vignette and background overlay. *(stretch)*
   *depends on: C1_01 · effort: L · value: Medium, a shareable keepsake from the concert · due: none · status: not started*
6. [QR Collection and Unlocks](C1_06_qr_collection_unlocks.md) (`C1_06`) - "Pokemon Go" style: staff place QR codes around the lobby; patrons collect them to unlock backgrounds and selfie vignettes; supports donor-level branding and a possible merch tie-in. *(stretch)*
   *depends on: C1_05 · effort: L · value: Medium, drives lobby engagement and gives sponsors/donors a branded surface · due: none · status: not started*

**Tasks**

- **`C1_T05` SPA mockup** (George) - build a mockup of the final app as a single-page app in Godot, leading with the tap experience and keeping shake in the background. The next visible deliverable. *(MVP1)*
  *depends on: C1_T06 · effort: M · value: High, puts a real, shareable app in the sponsor's hands and proves out the SPA direction · due: 2026-09-02 · status: not started*
- **`C1_T06` SPA native-presentation research** (George) - validate whether a SPA can present exactly like a native app on the phone, with no browser search bar, and test that across browsers and phones. Gates the SPA direction: a negative result puts the native path back in play. *(MVP1)*
  *depends on: none · effort: S · value: High, settles whether the whole SPA direction is viable before effort is spent building on it · due: 2026-09-02 · status: not started*
- **`C1_T04` Professional audio recording** (Julie) - professionally recorded jingle/bell audio to replace the prototype sounds. Julie is producing these, targeting before the 2026-09-02 meeting though not committed to that date. *(stretch)*
  *depends on: none · effort: M · value: Medium, raises audio quality above the placeholder sounds · due: none · status: in progress*
- **`C1_T03` Figma design and functionality options** (Christopher) - mock up design/functionality options to direct the look-and-feel and the stretch features. *(stretch-supporting)*
  *depends on: none · effort: M · value: Medium, gives the stretch work a design direction before it is built · due: none · status: not started*
- **`C1_T01` TestFlight release** (George) - get a native build into TestFlight so people can download and try it ahead of the concert. **Deferred 2026-08-03** pending the SPA direction; the original 2026-07-13 date passed without a start. *(deferred)*
  *depends on: C1_02 · effort: S · value: High, opens early, wide playtesting before the night-of, if the native path is resumed · due: none · status: not started*
- **`C1_T02` App Store release** (George) - publish to the App Store so patrons can download it at (and before) the concert. Whether this is still needed depends on the SPA outcome; unchanged at the 2026-08-03 meeting. *(under review)*
  *depends on: C1_T01 · effort: M · value: High, the channel patrons download from on the native path; allow for App Store review lead time · due: 2026-11-01 · status: not started*

> **Status and Next Steps.** The immediate path runs through the 2026-09-02 sponsor meeting:
> answer `C1_T06` (can a SPA present as a real app), then build `C1_T05` (the tap-focused SPA
> mockup) carrying `C1_01 Tap-to-Jingle` and `C1_02 Shake-to-Jingle`. Julie's audio (`C1_T04`)
> runs in parallel and may land before the meeting. `C1_T01 TestFlight release` is deferred and
> `C1_T02 App Store release` is under review; both depend on whether the native path resumes.
> After MVP1, pick up the stretch goals as time allows - `C1_T03` (Figma) first to set
> direction, then `C1_03` clap mode and `C1_04` snow confetti (both small), with
> `C1_05` holiday selfie and `C1_06` QR collection as the larger reaches. Each stretch feature
> needs its spec (`/feature`), then a plan (`/plan`), then a build (`/build`).
>
> **Foundation gap.** There is still no product brief. Run `/product-brief` for
> Holiday Sleigh Bells so these items have a real foundation.
