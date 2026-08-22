---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Give Each Chosen Bell Its Own Voice and Close the Audience Flow
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.2
AUTHOR: George Ruzek
VALUE STATEMENT: Turns four screens and a measured shake algorithm into one instrument, so that the bell an audience member picks is the bell they hear when they shake the phone.
LAST UPDATED: August, 22, 2026 11:29
---

# Give Each Chosen Bell Its Own Voice and Close the Audience Flow

## Summary

The Give Each Chosen Bell Its Own Voice and Close the Audience Flow feature (C1_10) joins the two halves of the application that have been built separately. The audience flow draws a bell the audience member chose but makes no sound; the shake instrument makes a sound but is wired to a measurement harness rather than to the flow. This feature first restructures the repository so the current application stands on its own and the abandoned first version is archived out of the way, then carries the chosen bell's recording through to the play screen, adds the shake detector to that screen so shaking the phone sounds that bell, adds a back control returning to the selection screen with the previous choice intact, and writes the system design document that describes how the whole of it fits together.

## Background

Two pieces of work have run in parallel and have not met. The Fit the Audience Flow to Any Phone Screen feature (C1_07) and the Swipe Between the Bells feature (C1_08) produced a four-screen flow — title, instructions, bell selection, and play — in which an audience member swipes through three sleigh bells and continues to a screen that draws the one they chose. That screen is silent. Separately, the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) measured hand motion on an iPhone and produced a shake detector whose every constant comes from recorded data rather than from guesswork. That detector currently lives on the capture harness screen, which is a measurement tool and not part of the audience flow.

Nothing connects them. An `InstrumentDefinition` describes a bell as artwork and nothing else, so there is no place for a recording to live. The play screen instantiates that artwork and stops. The application's main scene still points at the capture harness from the previous feature's device builds, so launching the application opens a measurement tool rather than the title screen. And there is no way back from the play screen, because the flow was built as a one-way path through four screens and the autoload that carries the chosen bell says so in its own comment.

The repository's layout is the other thing standing in the way. An abandoned first version of the application — a tumbling-physics prototype with its own title overlay, background, foreground, and bells — still occupies the repository root and five directories, and a reference analysis confirms nothing in the current application touches any of it. The current application lives in a directory named for a version number, which distinguishes it from a version nobody is building. Thirty-one megabytes of artwork belong to the abandoned version and thirty-two megabytes of the repository is material no build should ever include.

The system design is the final absence. This repository has no architecture document at all — no `docs/` directory, and none of the governing documents the development skills expect. The shake instrument introduced a signal bus, a detector, and a family of interchangeable responders, which is a real architectural pattern that currently exists only as source comments and as knowledge in one person's head. A second developer reading this repository would have to derive it.

Two capabilities are deliberately deferred from this feature and are detailed under Future work: per-bell one-shot recordings at several intensity levels, and any visual response to a shake.

## Value Delivered

- **The application becomes demonstrable end to end.** An audience member can open it, read the instructions, choose a bell, shake the phone, and hear that bell. That is the product, and until this feature it cannot be shown to a sponsor in one sitting.
- **The measured work pays off.** The Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) produced a detector nobody outside a test harness has heard. This puts it in the audience's hands.
- **Choosing a bell starts to matter.** Three bells that look different but sound identical are three pictures. Giving each its own recording is what makes the selection screen a choice rather than a decoration.
- **A wrong choice stops being permanent.** An audience member who picks the wrong bell currently has no way back short of restarting the application, which during a live performance means missing the piece.
- **The repository stops carrying a dead application.** Everything in it becomes something the current product uses, so a developer opening it does not have to work out which of two applications they are looking at, and no build can ship the abandoned one.
- **The architecture stops living in one person's head.** A written system design lets a second developer join the work without reverse-engineering the signal bus from source comments.

## Terms

- **Shaker.** One of the three sleigh bell instruments an audience member can choose. Used interchangeably with "bell" where the context is the choice rather than the object.
- **Responder.** A node that connects to the shake signal and does something when a stop is detected, without knowing how detection works. The sound is one responder; the flash used during calibration is another.
- **Stop.** The abrupt end of a hand's stroke, where a real sleigh bell's loose bells strike the shell. This is what the detector locates and what sounds a recording.
- **Intensity.** How hard a stop was, carried on the shake signal as a number from zero to one, spaced perceptually rather than linearly.
- **Voice.** One audio player in the pool that sounds recordings. Several voices overlap so that a new stop does not cut off the recording still sounding from the previous one.

## Requirements Summary

- **1. Restructure the repository and open the application at the title screen.** The current application stands on its own, the abandoned first version is archived where no build can reach it, and launching the application opens the audience flow again.
- **2. Give each bell its own recording.** A bell becomes artwork and a sound rather than artwork alone, with each of the three bells assigned one of the three recordings already in the repository.
- **3. Sound the chosen bell when the phone is shaken.** The play screen carries the shake detector and sounds the chosen bell's recording at each detected stop, at a volume matching how hard the stop was.
- **4. Let an audience member go back and change their bell.** A back control on the play screen returns to the selection screen, styled to match the flow's existing buttons.
- **5. Return to the bell that was already chosen.** The selection screen opens on the audience member's previous choice rather than resetting it.
- **6. Leave the capture harness untouched.** The measurement screen keeps its detector and its effects, so the algorithm can be revisited without rebuilding anything.
- **7. Write the system design.** An architecture document describing the flow, the autoloads, the shake instrument, the capture harness, and how a chosen bell reaches a sound.

## Requirements

### 1. Restructure the repository and open the application at the title screen

The current application moves out of its version-numbered directory into one named for what it is, the abandoned first version moves into an archive directory that no build can reach, the shader is kept in a directory of its own, artwork belonging only to the abandoned version moves with it, and the application's main scene points at the title screen so launching the application opens the audience flow.

This is the feature's first phase and is verified on the handset before any other work begins, because everything that follows is easier to diagnose against a repository whose layout is settled. The restructure changes where files live and what paths refer to them; it changes no behaviour, so the check is simply that the four screens run exactly as they did before.

The archive is made unreachable rather than merely separate. A directory the engine declines to import cannot be referenced, cannot be exported, and cannot be shipped by accident, which is a stronger guarantee than an export filter that has to be correct in every preset. The consequence is accepted deliberately: the abandoned application no longer runs, and bringing it back means undoing that first. Nothing is deleted. Every file of the first version is preserved, including the prototype motion controller that the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) cites as the illustration of the Android gravity sign-convention trap.

Artwork is separated by what actually references it rather than by where it sits. The distinction is not obvious by inspection: an image referenced only by the abandoned version's background scene is nonetheless the project's boot splash, and archiving it on the strength of a filename search would break the launch of every build. What belongs to the current application is what the application's own scenes reach, traced through both direct paths and resource identifiers.

### 2. Give each bell its own recording

An `InstrumentDefinition` describes a bell as its artwork and its recording, rather than as its artwork alone. Each of the three bells in the repository is assigned one of the three bell recordings already present, chosen to suit the instrument pictured:

| Bell | What the artwork shows | Recording |
|---|---|---|
| `sleighbells_01` | A wooden paddle carrying twelve small bright bells in two rows | `bright_jingle_bells` |
| `sleighbells_02` | A green stick with eight small bells, the lightest of the three | `airy_jingle_bells` |
| `sleighbells_03` | A leather strap carrying twelve large bells | `deep_jingle_bells` |

The recording belongs on the bell rather than on the play screen because the bell is already the thing that travels between screens. The selection screen publishes a chosen bell, an autoload carries it across the scene change, and the play screen reads it — so a recording attached to the bell arrives where it is needed without any screen having to know which bell was picked. The definition that describes a bell was written with this in mind and says so in its own comment, which reserves a place for each bell's recordings.

No new audio is produced or edited by this feature. The recordings used are the ones the repository already holds, and replacing them with better ones later requires changing an assignment rather than changing any code.

### 3. Sound the chosen bell when the phone is shaken

The play screen carries the shake detector built by the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09), and a responder that sounds the chosen bell's recording at each stop the detector reports. The volume of each sounding follows the intensity carried on that stop, so a gentle shake is quieter than a hard one across the measured range.

The detector's constants are settled and are not revisited here. They were measured from eight recorded runs on an iPhone and validated by replaying those runs through the detector itself; this feature consumes that result rather than reopening it.

The pool of voices is sized for the recording actually loaded rather than for a fixed number. The detector can report stops as little as fifty milliseconds apart, so a recording that sounds for over a second needs more voices than a short one if a new stop is not to cut off the recording still sounding. Sizing the pool to the recording rather than to a constant is what keeps this correct when the recordings are replaced.

No visual response is added to the play screen. The screen sounds the chosen bell and does nothing else; the flash used during calibration is not carried over.

### 4. Let an audience member go back and change their bell

The play screen carries a back control that returns to the bell selection screen. It is styled to match the flow's existing buttons: the same blue fill, corner radius, text size, white lettering, and red pressed state as the selection screen's continue button, and held clear of the home indicator by the same shared placement script the flow already uses for its buttons.

Matching the existing styling exactly rather than introducing a new button treatment matters because this is the first control in the flow that moves backwards, and it should read as part of the same application rather than as a developer's addition. The flow's buttons are the only styling precedent the repository has, so they are the standard.

### 5. Return to the bell that was already chosen

The bell selection screen opens showing the bell the audience member chose most recently, rather than always opening on the first of the three.

Without this, requirement 4 quietly destroys the thing it exists to fix. The carousel publishes a chosen bell as it moves and does so as soon as it is built, so a selection screen that always opens on the first bell would overwrite the audience member's choice with `sleighbells_01` the instant they pressed back — and they would have to notice that and correct it. The autoload that carries the choice already holds everything needed to open on it; what is missing is the carousel consulting it. The first entry into the flow, where nothing has been chosen yet, opens on the first bell as it does today.

### 6. Leave the capture harness untouched

The capture harness screen and its scripts are not modified by this feature. It keeps the shake detector, the sound responder, and the flash responder that were added to it during calibration.

The harness is the only way to record motion from a real hand, and the ability to record again is what makes a change to the detector's constants cheap rather than expensive. A harness that has had its instrument stripped out is a harness that needs reassembling before the next question can be answered. The cost of leaving it is that its recordings are no longer measurement-grade, because audio and a fading rectangle both consume frame time on the clock those recordings measure — an acceptable trade now that the calibration data has been captured and the detector settled.

### 7. Write the system design

A system design document is written describing the application's architecture as it stands after this feature. It covers the four screens of the audience flow and how each advances to the next, the two autoloads and what each carries across a scene change, the shake instrument's separation of detection from response through a signal bus, the capture harness and its relationship to the instrument it calibrates, how a chosen bell reaches a sound, and the layout of the repository as requirement 1 leaves it.

This is written as part of this feature rather than separately because this feature is what makes the architecture whole. Until the flow and the instrument are joined and the repository's layout is settled, a system design would describe two disconnected halves in a structure about to change, and would need rewriting the moment either happened. Writing it now records the architecture at the first point it is worth recording.

The document is the reference a second developer reads before touching this repository, and the reference the development skills read for architectural context. The pattern most in need of writing down is the shake instrument's: a stateless signal bus that any number of responders connect to, a detector that emits without knowing what listens, and responders that read only what they need — which is what allows the sound to exist on the play screen and the flash to exist on the capture harness without either screen knowing about the other.

The document also states one hard rule governing assets, in terms that leave no room for interpretation: **a media file is never deleted.** Artwork, audio, fonts, and any other media determined to be unused are moved into the archive directory, never removed from the repository. This applies to automated work and to hand edits alike, and it holds regardless of how confident anyone is that a file is unused. The reasoning is that the cost of the two mistakes is wildly asymmetric. An archived file that turns out to be needed costs one move to recover. A deleted file that turns out to be needed may be unrecoverable — an asset never committed to version control leaves no trace once removed, and the analysis that declares a file unused is exactly the kind of analysis that can be wrong, as the project's boot splash demonstrates: it is referenced by a scene belonging to the abandoned first version and by nothing in the current application, and a filename search would have condemned it.

## Token and design considerations

This feature builds no skill, so there is no input limit to declare, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching topic

No teaching topic is needed. This feature joins existing components through the patterns the repository already demonstrates and adds no capability the tutor covers.

## Future work

**Per-bell one-shot recordings at several intensity levels.** The three recordings this feature assigns are each roughly a second of sustained rattling rather than a single bell strike, so at the rate the detector reports stops they will overlap into a continuous wash rather than answering each stroke individually. The Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) produced the information a proper recording set needs: how many intensity levels to record at, and what range of shaking each covers. A later feature commissions or edits one-shot recordings per bell per level and assigns them in place of the ones used here, which is a change of assignment rather than a change of code.

**A visual response to a shake.** The instrument on the play screen does not move when it sounds. Animating it in response to a detected stop, at a scale matching the intensity carried on that stop, is a separate piece of work that connects a new responder to the same signal this feature already uses.
