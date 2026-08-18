# Sleigh Ride App — Requirements Meeting with Symphony Lead

**Purpose:** Align on scope and decisions for the "Sleigh Ride" audience-participation app so George can write a light product brief.
**End goal:** Patrons download the app at the late-November holiday concert and shake their phones during the performance of *Sleigh Ride*.
**Meeting length:** ~60–75 min. **Output:** A short decision log that feeds directly into the brief.

---

## Where the project actually stands (pre-read)

A working prototype already exists (Godot 4.4, portrait, **native iOS target**). It reads the phone's accelerometer/gravity sensor so that shaking the phone jingles on-screen bells, with several jingle-bell sound variations, a holiday font (Mountains of Christmas), AI-generated background/foreground art, a "Tap to Start" overlay, and an iOS/Xcode export in place. A web/HTML5 build via Firebase Hosting was tried earlier and abandoned (browser motion-sensor access was unreliable), so the path forward is the native iOS app.

**Why this matters for the meeting:** This isn't a from-scratch design conversation. The core mechanic is built. The meeting is about confirming the name, platforms, look-and-feel direction, and the *real* product decision below — then locking enough to write the brief.

**The one decision that drives everything else:** When a patron shakes their phone during the song, what happens — **sound through the phone speaker, a silent on-screen visual, or both?** Hundreds of phones playing bell audio in a concert hall is a very different product (and risk) than a silent visual shimmer that adds to the stage. Resolve this first; most other requirements follow from it.

---

## Desired outcomes (what we leave the meeting with)

1. **Name locked** — "Sleigh Ride" vs. "RVA Sleigh Ride" (or alternative), with App Store searchability/uniqueness noted.
2. **Platform scope + order confirmed** — iPhone first, Android second; agreement on whether Android is in-scope for *this* concert or a later one.
3. **Core interaction defined** — the sound vs. visual vs. both decision above, settled.
4. **Look-and-feel direction** — keep current AI-generated art, refine it, or align to Symphony brand; who provides assets.
5. **Feature list, ranked** — a must-have / nice-to-have / out-of-scope split for v1.
6. **Distribution plan** — how patrons discover and download it that night (QR in program, signage, stage announcement).
7. **Timeline working back from the concert** — including App Store review and a rehearsal test.
8. **Roles & ownership** — who does what between George and the Symphony (content, branding, approvals, on-site rollout).
9. **Success measures** — what "it worked" looks like.
10. **Open questions + owners** — anything unresolved, assigned with a due date.

---

## Agenda

**1. Framing & goal (5 min)**
Restate the vision and show the prototype live so everyone reacts to something real, not a description.

**2. Name (5–10 min)**
Decide "Sleigh Ride" vs. "RVA Sleigh Ride." Consider App Store uniqueness/searchability, ties to the Symphony's branding, and whether the name should read as Richmond-specific. *Outcome: name locked.*

**3. Platforms (5 min)**
Confirm **native iOS as the target.** A web/HTML5 build (Firebase Hosting) was already attempted and did not work — browser access to the motion sensors proved unreliable — so that route is ruled out. Remaining question: is Android needed for *this* November, or acceptable as a fast-follow? Note the App Store / Play Store review lead times. *Outcome: scope + order confirmed.*

**4. Core interaction — the big one (10–15 min)**
Sound vs. visual vs. both. Discuss: disruption risk, "magical moment" upside, whether the conductor/performance needs phones silent, latency/sync, and whether timing is free-for-all or cued. *Outcome: core mechanic defined.*

**5. Look & feel (10 min)**
React to the current AI-generated art. Keep / refine / rebrand to Symphony identity? Who supplies logo, colors, fonts, imagery? *Outcome: visual direction + asset owner.*

**6. Featureset — open discussion (10–15 min)**
Brainstorm, then sort into must-have / nice-to-have / later. Candidates to put on the board:
- Onboarding (how a first-timer knows what to do in seconds)
- A conductor or staff "go" cue vs. patrons starting on their own
- Multiple bell sounds / instruments / colors
- Leaderboard, counter, or collective on-screen effect
- Works fully offline (no reliance on venue wifi/cell)
- Accessibility (one-handed use, low vision, no audio dependency)
- Analytics (download count, participation) and what data, if any, is collected
- Privacy posture (ideally no logins, no personal data)
*Outcome: ranked feature list for v1.*

**7. Distribution & the night-of experience (5–10 min)**
How patrons download in the moment: QR code in the printed program, lobby signage, a line in the pre-concert announcement. Account for slow venue connectivity and last-minute downloads. *Outcome: distribution plan.*

**8. Timeline & ownership (5–10 min)**
Work backward from the concert date: App Store submission/review buffer, a beta via TestFlight, and at least one rehearsal-hall test with real phones. Assign owners. *Outcome: dated milestones + responsibilities.*

**9. Success & wrap (5 min)**
Define what success looks like (e.g., participation feel in the room, # downloads, no technical failures). Confirm open questions and owners. *Outcome: success measures + action items.*

---

## Open questions to surface

- Concert date and venue (drives the entire backward timeline).
- Is there a budget or is this volunteer/in-kind?
- Does the Symphony have a brand/style guide the app should match?
- Who has final approval on name, art, and App Store listing (and under whose developer account is it published)?
- Any sponsor or marketing tie-ins that affect the look or the listing?
- Is a one-time concert moment the whole goal, or a reusable asset for future seasons?

## Parking lot (don't solve in the meeting)
Android build specifics, future seasons/reuse, advanced features (multiplayer effects, AR), monetization. Note and move on.
