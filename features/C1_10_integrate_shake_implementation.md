---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Giving Each Chosen Bell Its Own Voice and Closing the Audience Flow
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: A five-phase route from a silent play screen to an instrument that sounds the bell the audience member chose, ending with the architecture written down so the next developer does not have to derive it.
LAST UPDATED: August, 22, 2026 12:03
---

# Implementation Plan for Giving Each Chosen Bell Its Own Voice and Closing the Audience Flow

This plan implements the Give Each Chosen Bell Its Own Voice and Close the Audience Flow feature (C1_10). It adds one field to a resource, assigns three recordings, adds two nodes and one button to the play screen, changes where the bell carousel opens, and writes the repository's first system design document. Its first phase, the repository restructure, is already complete and is recorded here for the record rather than planned.

## Design decisions carried in from the specification conversation

These were settled during ideation and planning and are implemented rather than re-opened.

- **The three recordings are assigned to the three bells as the specification's table states**, keyed to what each artwork pictures. Which recording goes with which bell is settled and is not revisited.
- **The system design lives at `docs/system_design.md`.** The developer's decision. The `manta-rai` project subdirectory named in the skill's project instructions belongs to a different product, and this repository holds one product, so no subdirectory is used.
- **The voice pool is sized from the recording's own length** against the highest event rate the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) measured, rather than against the tightest gap it measured. This is described under "Sizing the voice pool" below.
- **The sound responder reads the chosen bell itself** rather than having the play screen push a recording into it, so the play screen knows nothing about how sound is produced.
- **No automated tests are created.** This follows the precedent recorded in the plans for the Fit the Audience Flow to Any Phone Screen feature (C1_07) and the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09). This repository has no test framework and introducing one is outside this feature's scope. The verification burden falls entirely on the manual steps in §4 and the acceptance table in the final section.
- **The application coding standards and implementation plan requirements named in the skill's project instructions do not exist in this repository.** This plan follows the conventions the repository actually demonstrates, listed in §5. Creating those documents is not in this feature's scope; §3 records that they are still missing.

## Phase 1 is already complete

Specification requirement 1 — restructure the repository and open the application at the title screen — was performed and validated on the handset before this plan was written. It is recorded here so the plan describes the whole feature, and no step below repeats it.

What was done: the application moved from `v2/` to `app/`; the abandoned first version moved to `legacy/` carrying a `.gdignore` marker so the engine does not import it and no build can include it; `background/transparent_cloud.gdshader` moved to `shaders/`; artwork belonging only to the abandoned version moved to `legacy/images/`; and `run/main_scene` returned to `uid://bpebykdxeem4`, the title screen. Every `res://v2/` reference became `res://app/`, and the archive's internal references were repointed so it stays coherent. `images/` fell from 37 megabytes to 1.8.

Two findings from that work bear on everything below. `images/RichmondSymphonyLogo.png` is the project's boot splash and is referenced only by the abandoned version's background scene, so a filename search would have archived it and broken every launch — resource identifiers, not filenames, decide what is in use. And the archive is unimportable rather than merely separate, which means the abandoned application no longer runs until that marker is removed.

## Sizing the voice pool

Specification requirement 3 asks that the pool of voices be sized for the recording actually loaded rather than for a fixed number. Two rules are defensible and they differ by a factor of two and a half, so the choice is recorded here rather than left to the build.

The Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) measured two relevant figures across sixteen runs: the tightest gap between two consecutive events is 50 milliseconds, and the highest sustained event rate in any run is 6.77 per second. Sizing against the tightest gap gives twenty-four voices for a recording that sounds for 1.2 seconds. Sizing against the highest sustained rate gives nine.

**The pool is sized from the sustained rate, with a margin**: the number of voices is the recording's length in seconds multiplied by eight events per second, rounded up, with a floor of four. For the three bell recordings being assigned, whose streams report two seconds, that is sixteen voices. The 50-millisecond gap is a transient between two adjacent stops rather than a rate anything sustains, and provisioning for it as though it were sustained would allocate audio players that can never all be needed at once.

The consequence is accepted and stated: in the worst case a burst of stops closer together than the pool can hold will reuse its oldest voice and cut off a recording still sounding. With sixteen voices and a two-second stream that requires eight stops per second sustained for two seconds, which is faster than any measured run.

## Implementation Steps and Phases

### Phase 2: Give each bell its own recording

1. Add an exported `AudioStream` field to `app/instrument_definition.gd` alongside the existing `artwork` field. The script's own comment already reserves a place for this and reads "Each bell's set of recordings is added here when that feature is built"; update that sentence to describe what the field now holds rather than leaving it describing an intention.

2. Assign a recording to each of the three definitions in `app/instruments/`, per the specification's table:

   | Definition | Recording |
   |---|---|
   | `sleighbells_01.tres` | `res://sounds/bright_jingle_bells.mp3` |
   | `sleighbells_02.tres` | `res://sounds/airy_jingle_bells.mp3` |
   | `sleighbells_03.tres` | `res://sounds/deep_jingle_bells.mp3` |

   Each `.tres` gains an external resource entry for its recording and a property line assigning it. No new audio is produced or edited; `sounds/` is unchanged.

### Phase 3: Sound the chosen bell on the play screen

3. Change `shake/responses/jingle_response.gd` so its recording can come from the chosen bell rather than only from an exported field. The responder gains a boolean export selecting which source it uses, defaulting to the exported stream so the capture harness's existing instance keeps behaving exactly as it does today. When the flag selects the chosen bell, the responder reads `InstrumentSelection.chosen.sound` in its own `_ready()`.

   The responder reads the selection itself rather than the play screen assigning a stream into it, because both nodes run `_ready()` and the order between a parent and its child is fixed in a direction that would make the assignment arrive too late. Reading it in the responder removes the ordering question entirely and keeps the play screen from knowing anything about how sound is produced.

   Both failure paths fail loudly with an actionable message, per the no-fallbacks rule: no bell chosen, and a chosen bell carrying no recording. Neither substitutes a default recording.

4. Replace the responder's fixed `voice_count` export with the sizing rule described above, computed from the loaded stream's `get_length()`. The existing export is removed rather than retained alongside, so there is one definition of how many voices exist.

5. Add the shake detector and a sound responder to `app/instrument.tscn`, the play screen. The detector is an instance of `shake/shake_detector.tscn` with its calibrated exports untouched. The responder is an instance of `shake/responses/jingle_response.tscn` with its source flag set to the chosen bell. No flash responder is added, per the specification.

### Phase 4: Close the loop between the play screen and the selection screen

6. Add a back button to `app/instrument.tscn`, styled to match the selection screen's continue button exactly: fill `Color(0.2509804, 0.56078434, 0.8392157, 1)`, pressed fill `Color(0.83137256, 0.20392157, 0.15686275, 1)`, 55-pixel corner radius on all four corners with corner detail 12, white font in all four states, font size 44, and the same 660 by 110 geometry bottom-anchored through `app/safe_area_margin.gd` so it clears the home indicator. Its text is "Back".

   The two style boxes are declared as sub-resources of the play screen in the same form the other two screens declare theirs. The repository has no shared theme and no button scene; matching by duplicating the style box is the pattern both existing screens already use, and introducing a shared button resource is an enhancement this feature has not been asked for.

7. Connect the button in `app/instrument.gd`'s `_ready()`, changing the scene to `res://app/instrument_select.tscn`. Signals are connected in `_ready()` rather than in the scene file, matching every other screen; connecting in both places raises a duplicate-connection error at runtime.

8. Change `app/instrument_carousel.gd` so the carousel opens on the bell already chosen. After the slots are built, if `InstrumentSelection.chosen` is one of the active instruments, set the carousel's offset to that instrument's index before the first render; otherwise leave it at zero, which is the first entry into the flow where nothing has been chosen yet.

   The offset must be set before `_publish_selection()` runs, or the carousel will overwrite the audience member's choice with the first bell in the instant between building and positioning — which is the exact failure requirement 5 exists to prevent.

9. Correct the stale comment in `app/instrument_selection.gd`, which states that "there is no backward navigation" and that "the audience member moves forward through the four screens once". Requirement 4 makes both false. This is an automatic fix on a file this plan touches, not an enhancement.

### Phase 5: Write the system design

10. Create `docs/` and write `docs/system_design.md`, covering what specification requirement 7 lists: the four screens and how each advances to the next, the two autoloads and what each carries across a scene change, the shake instrument's separation of detection from response through a signal bus, the capture harness and its relationship to the instrument it calibrates, how a chosen bell reaches a sound, and the repository layout as phase 1 leaves it.

11. Include in that document the hard rule governing assets, stated so it cannot be read as advisory: **a media file is never deleted.** Artwork, audio, fonts, and any other media determined to be unused are moved into `legacy/`, never removed, and this holds for automated work and hand edits alike regardless of how confident anyone is that a file is unused. The document carries the reasoning, that the two mistakes cost wildly different amounts and that an asset never committed to version control leaves no trace once removed, and cites the boot splash as the demonstration that a filename search can condemn a file that is genuinely in use.

12. Update the Key documents list in the skill's project instructions so the system design path points at `docs/system_design.md` rather than at the `manta-rai` path that does not resolve. Record in the same place that the application coding standards and the implementation plan requirements are still absent, so a later audit knows it is substituting rather than reading the real thing.

## Test Cases

**No automated tests are created or changed by this plan**, following the precedent recorded in the plans for the Fit the Audience Flow to Any Phone Screen feature (C1_07) and the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09). This repository has no test framework and introducing one is outside this feature's scope.

The acceptance table in the final section of this plan replaces the unit-test table. It is a verification artefact rather than a test suite, and every row in it is checked by hand.

The consequence worth recording: **the sound path cannot be exercised anywhere but a real handset.** The three motion calls the detector depends on return a zero vector in the editor, on the desktop build, and in the iOS simulator, which is documented engine behaviour rather than a fault. What can be checked off-device is that the project loads with no errors, that every resource reference resolves, and that the scripts parse — which the build should do after each phase and which catches a mistyped path or a broken scene long before a handset is involved.

## README and Documentation Updates

`README.md` exists and describes the repository structure and the shake instrument. It gains no new directory from this feature except `docs/`, which is added to its structure table.

Three pieces of knowledge introduced here are not evident from reading the code and are recorded as comments where someone changing them will be looking: in `shake/responses/jingle_response.gd`, why the responder reads the selection itself rather than receiving a stream, and how the voice count is derived and what it trades away; and in `app/instrument_carousel.gd`, why the opening offset must be set before the first selection is published.

`docs/system_design.md` is itself the documentation this feature produces, and is written as step 10 rather than as an afterthought here.

The application coding standards and the implementation plan requirements named in the skill's project instructions do not exist in this repository and are not created by this plan. Their absence weakens every code violation review run against this repository, which has to substitute the conventions in §5 for the real documents. That is worth a feature of its own and is not this one.

## Manual Verification Steps

Because there are no automated tests, these steps are the verification. The first group runs anywhere; the rest need the handset.

**Off the device, after each phase.** Open the project and confirm it loads with no errors in the output panel, that `app/instrument.tscn` opens with every node present, and that the three bell definitions each show their recording in the inspector. A missing recording or a broken path shows here rather than on the phone.

**On the handset, the sound.** Run the flow from the title screen to the play screen and shake the phone. Confirm a bell sounds on each stop, that shaking harder is louder than shaking gently, and that repeated stops overlap rather than cutting each other off. Confirm the phone is silent when held still — the detector fires zero times on both still runs recorded in the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09), so any sound at rest is a fault.

**On the handset, that the bell matters.** Choose each of the three bells in turn and confirm each sounds different from the other two, and that the sound matches the assignment: the wooden paddle sounds bright, the green stick airy, the leather strap deep. Choosing a bell and hearing the previous one is the failure this step exists to catch.

**On the handset, the back control.** Confirm the back button appears on the play screen in the same blue as the selection screen's continue button, sits clear of the home indicator, and returns to the selection screen when pressed. Confirm it does not intercept a drag that begins on it.

**On the handset, that going back keeps the choice.** Choose the third bell, continue, press back, and confirm the carousel is showing the third bell rather than the first. Continue again and confirm the third bell still sounds. This is the requirement most easily broken without noticing, because a carousel that resets looks perfectly normal.

**On the handset, that nothing else changed.** Confirm the title, instructions, and selection screens behave exactly as they did before, and that the capture harness still records when the main scene is pointed at it.

**Before finishing.** Confirm `run/main_scene` still points at the title screen and that `docs/system_design.md` exists and describes the architecture as built.

## Coding Standards Compliance Checklist

The application coding standards document named in the skill's project instructions does not exist in this repository. The following are the conventions this codebase demonstrates, and this plan conforms to each.

- Tab indentation in GDScript, matching every script in `app/` and `shake/`.
- A one-line comment at the top of each script naming the file and its role.
- Static typing on declarations and return types, including `-> void` on functions that return nothing.
- Signals connected in `_ready()` rather than in the scene file. Connecting in both places raises a duplicate-connection error at runtime.
- Scene and script files named in lower snake case.
- Exported values that act as divisors, bounds, or loop counts are validated in `_ready()` with a message naming the value, its permitted range, and the correct default — the pattern established in `shake/shake_detector.gd`.
- A node dependency reached by scene path is validated in `_ready()` rather than at its first use, so a misconfiguration surfaces at load rather than inside a branch that runs rarely — the pattern established in `capture/shake_capture.gd`.
- No fallbacks. A missing chosen bell or a bell with no recording fails with an actionable error naming what is missing and how to reach the screen correctly; neither substitutes a default.
- User-facing errors name the file, the property, and what to do about it.

## File-Level Compliance Review

| File | Change |
|---|---|
| `app/instrument_definition.gd` | An exported `AudioStream` field added; the comment reserving a place for it updated to describe what it holds |
| `app/instruments/sleighbells_01.tres` | `bright_jingle_bells.mp3` assigned |
| `app/instruments/sleighbells_02.tres` | `airy_jingle_bells.mp3` assigned |
| `app/instruments/sleighbells_03.tres` | `deep_jingle_bells.mp3` assigned |
| `shake/responses/jingle_response.gd` | A source flag selecting the exported stream or the chosen bell; the fixed voice count replaced by the sizing rule; both failure paths made actionable |
| `app/instrument.tscn` | The shake detector and a sound responder instanced; a back button added with the flow's blue styling |
| `app/instrument.gd` | The back button connected in `_ready()` |
| `app/instrument_carousel.gd` | The opening offset set from the chosen bell before the first selection is published |
| `app/instrument_selection.gd` | The comment asserting there is no backward navigation corrected |
| `README.md` | `docs/` added to the structure table |
| `docs/system_design.md` | New. The architecture document, including the rule that media files are never deleted |

Nothing else is touched. In particular `capture/` and its instanced responders are left exactly as they are, per specification requirement 6, and `shake/shake_detector.gd` is not modified — its constants are settled by the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) and this feature consumes them.

The Draw the Vignette in Code So Its Glow Is Clean and Fits Every Screen feature (C1_11) also modifies `app/instrument.tscn`, removing the vignette's placement override. The two changes touch different nodes of the same scene and do not conflict, but whichever lands second should be applied to the scene as the first left it rather than to a copy taken beforehand.

## Metric Consistency Audit

Three measurements appear in this feature and each is defined in exactly one place.

| Measurement | Single definition | Where it is computed |
|---|---|---|
| Intensity | The peak magnitude of linear acceleration projected onto the motion axis, normalized logarithmically between 6.0 and 102.6 metres per second squared | Once, in `shake/shake_detector.gd`, and carried on the event. No responder recomputes it |
| Loudness | Linear interpolation from the quietest to the loudest decibel setting across the event's intensity | Once, in `shake/responses/jingle_response.gd` |
| Voice count | The loaded recording's length in seconds times eight, rounded up, with a floor of four | Once, in `shake/responses/jingle_response.gd`, at the moment the pool is built |

The intensity range and the event rate the voice count derives from are quoted from `features/C1_09_shake_it_discovery_findings.md` and appear nowhere else in this feature, so a number here cannot disagree with the finding it came from.

## Completion Criteria

1. Each of the three bell definitions carries a recording, and the three assignments match the specification's table.
2. Shaking the phone on the play screen sounds the chosen bell, louder for a harder shake, and is silent when the phone is held still.
3. Each of the three bells sounds audibly different from the other two on the handset.
4. The play screen carries a back button in the flow's blue styling that returns to the selection screen and sits clear of the home indicator.
5. Returning to the selection screen shows the bell that was already chosen, and continuing forward again sounds that same bell.
6. `capture/shake_capture.tscn` and the scripts it instances are unchanged, and the capture harness still records when the main scene is pointed at it.
7. `docs/system_design.md` exists, covers each of the six areas requirement 7 lists, and states the rule that media files are never deleted.
8. The skill's project instructions point at `docs/system_design.md`, and the absence of the other two governing documents is recorded.
9. `run/main_scene` points at the title screen, and the title, instructions, and selection screens behave exactly as they did before this work.

## Token and Design Considerations

This feature builds no skill, so there is no `input_limits` value to declare, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed. This feature joins existing components through patterns the repository already demonstrates and adds no capability the tutor covers.

## Acceptance Table

This replaces the unit-test table, for the reason given in §2. Every row is verified by hand, and the rows marked handset cannot be checked anywhere else.

| Behavior under test | Concrete input | Expected result |
|---|---|---|
| A bell carries its recording | Open `sleighbells_01.tres` in the inspector | The sound field shows `bright_jingle_bells.mp3`; the same for `sleighbells_02` with `airy` and `sleighbells_03` with `deep` |
| Voice pool sizing | A recording whose stream reports 2.0 seconds | Sixteen voices are built. A 0.46-second recording builds four, the floor |
| No bell chosen | Open `app/instrument.tscn` directly rather than through the flow | An error names that no bell has been chosen and says to reach the screen through the flow starting at the title. No sound plays and nothing crashes |
| Bell with no recording | Temporarily clear the sound field on one definition and choose that bell | An error names the definition and the missing field. No substitute recording plays |
| Sound on a stop, handset | Shake the phone on the play screen | A bell sounds on each stop; harder shaking is louder; consecutive stops overlap rather than cutting off |
| Silence at rest, handset | Hold the phone still on the play screen for thirty seconds | No sound at all. The detector fires zero times on both still runs in `features/data/C1_09/` |
| The bell matters, handset | Choose each of the three bells in turn and shake | Three audibly different sounds, each matching its artwork per the specification's table |
| Back returns, handset | Press the back button on the play screen | The selection screen appears. The button sits clear of the home indicator and matches the continue button's blue |
| The choice survives going back, handset | Choose the third bell, continue, press back | The carousel shows the third bell, not the first. Continuing again sounds the third bell |
| First entry is unchanged, handset | Launch the application and reach the selection screen for the first time | The carousel opens on the first bell, as it does today |
| Drag still works, handset | Swipe the carousel after returning to it from the play screen | The carousel drags, settles, and publishes selection exactly as before |
| The harness is untouched | Point `run/main_scene` at `capture/shake_capture.tscn` and record a run | A file is written with the same header and columns as the runs in `features/data/C1_09/` |
| The flow is unchanged | Run the title, instructions, and selection screens | Each behaves exactly as it did before this feature |
| The architecture is written down | Open `docs/system_design.md` | It covers the four screens, both autoloads, the shake instrument's signal bus, the capture harness, how a chosen bell reaches a sound, the repository layout, and the rule that media files are never deleted |
