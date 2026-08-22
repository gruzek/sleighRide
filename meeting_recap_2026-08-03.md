# Holiday Sleigh Bells - Meeting Recap, 2026-08-03

Notes from the sponsor meeting held 2026-08-03. Decisions and commitments below are the
source for the roadmap changes applied the same day to `features/mvp1_roadmap.md`.

**Next meeting: 2026-09-02, 10:00 AM.**

> **Later note, added 2026-08-22.** The SPA direction decided at this meeting was subsequently
> **reversed**; Holiday Sleigh Bells is a native Godot mobile application. This recap is left
> exactly as written because it is the record of what was decided on 2026-08-03, and a record
> is not improved by editing it to match what happened next. The reversal itself is not
> recorded anywhere - no meeting recap covers it - which is how `features/mvp1_roadmap.md`
> came to keep asserting the SPA for three weeks while native features were being built
> against it. The open question below, "Do we need the accelerometer?", is answered: yes, and
> it works.

## Decisions

**Name is set: "Holiday Sleigh Bells."**
The name question is closed. Christopher's research settled it. All project documents,
including the roadmap, now use this name.

**Direction shifts to a SPA.**
George will produce a mockup of the final app built as a single-page app in Godot, rather
than continuing straight down the native iOS path. The mockup is the next visible
deliverable and is expected before the 2026-09-02 meeting.

**Tap becomes the focus; shake stays in the background.**
The primary interaction in the mockup is tap. The existing shake-to-jingle mechanic is kept
rather than dropped, but it is no longer the lead experience. This reorders the roadmap: tap
is now `C1_01`, shake is now `C1_02`.

**TestFlight release is deferred.**
`C1_T01 TestFlight release` was due 2026-07-13 and never started. It is deferred rather than
rescheduled, pending the outcome of the SPA direction. Its due date is cleared.

## Commitments

| Who | What | When |
|---|---|---|
| Julie | Produce recordings of the sleigh bells | Potentially before 2026-09-02 |
| George | SPA mockup of the final app, tap-focused, built in Godot | Before 2026-09-02 |
| George | Research whether a SPA can present identically to a native app | Before 2026-09-02 |
| Christopher | Figma design and functionality options | No date set |

## Open research question

**Can the SPA look exactly the same as a native app on the phone, with no browser search bar?**
This needs validation and testing across browsers and phones. It gates the SPA direction: if
a SPA cannot present as a real app, the native path comes back into play. Tracked as
`C1_T06 SPA native-presentation research`.

## Still open after this meeting

- **Do we need the accelerometer?** Keeping shake "in the background" implies yes, but a SPA
  makes browser access to motion sensors uncertain. A web build was already attempted once
  and abandoned for exactly this reason (see `meeting-symphony-requirements.md`). `C1_T06`
  is what settles this.
- **Is `C1_T02 App Store release` still real?** It carries a hard date of 2026-11-01, but if
  the SPA becomes the delivery vehicle, an App Store release may not be needed at all. Not
  changed at this meeting.
- **Feature ranking for v1.** The must-have / nice-to-have / out-of-scope split was on the
  agenda and is not recorded as settled here.
- **No product brief exists.** The roadmap has been running without one since it was created.
