---
DOCUMENT TYPE: Holiday Sleigh Bells System Design
DOCUMENT TITLE: How Holiday Sleigh Bells Is Put Together
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 1.1
AUTHOR: George Ruzek
VALUE STATEMENT: The one document a developer reads before touching this repository, so the architecture is inherited rather than reverse-engineered from source comments.
LAST UPDATED: September, 1, 2026 13:52
---

# Overview

Holiday Sleigh Bells turns an audience member's phone into a sleigh bell that the audience member shakes along with a live orchestral performance of "Sleigh Ride". This system design describes how the application is built: the screens, the autoloads that carry state between the screens, the path from a shake to a sound, and where each file lives.

This system design serves two readers: a developer arriving at the repository for the first time, and the development skills that need architectural context. The document describes the system as built.

## About Assets

**Media files leave the application only by moving into `legacy/`.**

A person or tool that finds artwork, audio, fonts or other media to be unused moves the file into `legacy/`, mirroring the path the file came from, and keeps the file in the repository. The rule binds automated work and hand edits alike, however confident anyone is that the file is unused.

Archiving a file by mistake costs one move to recover, while deleting a file by mistake may lose the file for good. A deleted asset that nobody committed to version control leaves no trace.

A filename search would have condemned `images/RichmondSymphonyLogo.png`, which is the project's boot splash. The abandoned first version's background scene references the logo and no scene in the current application does, so a search for scenes that name the file marks the logo unused. `project.godot` reaches the logo by resource identifier instead of by path. Archiving the logo would have broken the launch of every build. To decide what is in use, trace both file paths and resource identifiers from the main scene; a filename search cannot answer the question.

## Repository layout

| Directory | What it holds |
|---|---|
| `app/` | The application: the four screens of the audience flow, their shared placement scripts, and the bell definitions |
| `shake/` | The shake instrument: the signal bus, the detector, and the responders that react to a detected stop |
| `snow/` | The snow effect, which reads the phone's orientation and shake energy to steer falling snow |
| `capture/` | The motion capture harness that calibrates the shake instrument. Outside the audience flow |
| `shaders/` | Shared shaders |
| `sounds/`, `images/` | Assets the current application uses |
| `docs/` | This document |
| `features/` | Feature specifications, implementation plans, findings, and the captured motion data under `features/data/` |
| `legacy/` | The abandoned first version of the application and each asset belonging only to it |
| `android/` | The Gradle build template Godot installs for the Android export. The editor generates it, and `.gitignore` excludes it |
| `exports/` | Build output, including the iOS Xcode project. `.gitignore` excludes everything except the Xcode project |

A `.gdignore` marker in `legacy/` stops the engine from importing the directory, so no scene, resource identifier or export bundle can reach a file in `legacy/`. **The marker stops the first version of the application from running, by design.** Restoring the first version means removing the marker and reimporting.

The editor's Project menu writes `android/build/`, and `.gitignore` excludes `android/build/` along with `android/.build_version`. The directory holds about two hundred megabytes of Gradle source, and reinstalling the build template regenerates the directory. Git would commit a hand-authored file under `android/`, but `android/` holds none: the share plugin declares its own Android packaging through an `EditorExportPlugin` instead of a plugin definition file, so `android/` needs no authored file.

### Governing documents

The development skills read a project instructions file that names an application called `manta-rai` and places the `manta-rai` governing documents under `docs/manta-rai/`. `manta-rai` is a different product. For this repository:

- **System design**: this document, `docs/system_design.md`.
- **Application coding standards**: **does not exist.** The "Conventions" section below lists the conventions the repository demonstrates, and a code violation review in this repository has to substitute those conventions.
- **Implementation plan requirements**: **does not exist.**

The project instructions file lives outside this repository. The plugin source injects the file into each development skill at deploy time, and six copies of the file exist, so no edit in this repository can correct the file.

## The audience flow

The audience flow runs through four screens, and each screen advances to the next with `change_scene_to_file`, which frees the entire scene tree and everything the tree holds.

```
app/main.tscn            Title. "Tap to start"
        ↓
app/instructions.tscn    How to play. "Continue"
        ↓
app/instrument_select.tscn   Swipe or tap between three bells, and one fun fact.
                             Tap the centred bell to advance; the screen has no continue button
                             The three are the paddle bells, the strap bells, and both together
        ↓
app/instrument.tscn      Play. Shake to sound the chosen bell. "Back" returns to selection
```

`run/main_scene` in `project.godot` points at the title screen by resource identifier. Pointing `run/main_scene` at `capture/shake_capture.tscn` produces a capture build, the only route to the harness. Any feature that changes `run/main_scene` carries restoring the title screen as a completion criterion.

The play screen is the only screen with backward navigation; the title, instructions and bell selection screens move forward only.

### Screen composition

Each screen instances small scenes instead of holding one authored tree. `title.tscn`, `vignette.tscn`, `winnie.tscn`, `shake_to_jingle.tscn` and the other small scenes are each a sprite or a label plus a placement script, instanced into the screens that need them. Two shared scripts do the placing:

- **`app/sprite_position.gd`** positions a node against the 1080 by 1920 design canvas, with an anchor per axis and an option to respect the device's safe area. The engine expands the canvas instead of stretching it, so on a portrait phone the canvas stays 1080 units wide and grows taller.
- **`app/safe_area_margin.gd`** holds a bottom-anchored control clear of the home indicator. Godot's anchoring measures from the physical window edge and ignores the safe area, so each button in the flow carries `safe_area_margin.gd`. The script derives its offsets from authored base values instead of adjusting the offsets in place, so repeated recomputes do not compound.

`app/fun_fact_bubble.tscn`, instanced once on the bell selection screen, is the one small scene that carries live text: two `Label` nodes that draw a fun fact from an exported list. `app/shake_to_jingle.tscn`, instanced once on the play screen, is the other small scene built around a `Label` instead of a sprite, and its `Label` shows the fixed string "Shake to Jingle". Both scenes use a `Node2D` root that carries the placement script, with the `Label` as a child, because the placement script extends `Node2D` and cannot attach to a `Control` node. A shuffle bag held in a static variable serves the fun fact list, so no fact repeats until the bubble has shown every fact in the list, and the sequence survives the scene change without an autoload or a file.

A composition scene that needs behaviour of its own extends the placement script instead of replacing the placement script, because a node holds only one script. `app/instrument_carousel.gd`, `app/holiday_sleigh_bells.gd` and `app/fun_fact_bubble.gd` each extend `app/sprite_position.gd`, call `super()` from their own `_ready`, and keep the exported placement properties that the hosting screen sets.

A second family of shared scripts gives a sprite motion instead of a place. `app/tilt_sway.gd` leans a sprite with the phone's side-to-side tilt, `app/continuous_spin.gd` turns a sprite at a constant rate, and `app/tilt_drift.gd` slides a sprite a short way as the phone tilts. `tilt_sway.gd` and `tilt_drift.gd` read the tilt through `app/phone_tilt.gd`. The motion scripts attach to the **child sprites** inside an artwork scene instead of the scene's root, and so extend nothing: the placement script lives on the root and owns `position`, while each child owns its own transform. The motion scripts carry no pivot either. The scene sets a sprite's origin through `centered` and `offset`, so a developer sets the red tree's bend point by eye in `app/straight_red_tree.tscn`, and the sway script holds no bend point.

Each screen styles its own buttons with inline `StyleBoxFlat` sub-resources; the project has no shared theme and no shared button scene. The flow's blue is `Color(0.2509804, 0.56078434, 0.8392157, 1)` with a red pressed state, a 55-pixel corner radius and 44-point white text, and each screen that needs the style duplicates those values.

The Jingle Cam button on the bell selection screen leaves its own `text` and `icon` properties unused, and this section records the reason so nobody reverts the button. Godot's `Button` places an icon at the left margin and centres the text independently of the icon, and on a wide button Godot's layout strands the icon in the corner. Godot's documentation rules out the alternative: a button with an icon centred both horizontally and vertically draws the text on top of the icon. The Jingle Cam button therefore holds a full-rect `HBoxContainer` with a `TextureRect` and a `Label`, and all three nodes ignore mouse input so the press still reaches the button. A button that needs a centred icon beside its lettering has to copy the Jingle Cam button's construction.

**No node touches its own viewport after dispatching a gesture.** The carousel marks a touch handled before emitting the signal, and `app/instrument_select.gd` defers the scene change that `instrument_select.gd` makes in response. A listener can answer a signal emitted from `_unhandled_input` by replacing the scene, and code that runs after the replacement reaches into a tree the engine is already tearing down. The application then crashes instead of failing cleanly. A button's `pressed` signal needs no deferral, because `pressed` fires after the viewport has finished with the event, so only the tap path defers.

## What crosses a scene change

`change_scene_to_file` destroys everything on the screen, so state that must outlive a scene change lives in an autoload. The project has two autoloads:

| Autoload | Script | What it carries |
|---|---|---|
| `InstrumentSelection` | `app/instrument_selection.gd` | The chosen bell, as an `InstrumentDefinition`. The autoload writes nothing to disk, and the choice lasts for the session |
| `ShakeEvents` | `shake/shake_event_bus.gd` | One signal, `jingled`. No state at all |

A bell is an `InstrumentDefinition` resource, defined in `app/instrument_definition.gd`, that holds two things: the artwork scene that draws the bell and the recording the bell sounds. Three bells exist, in `app/instruments/`. Storing the recording on the bell instead of on the play screen lets the sound follow the audience member's choice without any screen knowing which bell the audience member picked. The selection screen publishes a bell, the autoload carries the bell, and the play screen and the sound responder each read what they need from the bell.

The bell selection screen's carousel publishes the chosen bell on each move, so the choice is already correct when the audience member taps the centred bell, and the `centre_tapped` signal carries no payload. Publishing on each move made the continue button redundant, because the button confirmed a decision the carousel had already recorded, so the project removed the button. The carousel also **opens on the bell already chosen**, and opening there makes the play screen's Back button safe. A carousel that opened on the first bell each time would overwrite the audience member's choice in the instant between being built and being positioned.

## The shake instrument

The shake instrument keeps the code that detects a stop apart from the code that responds to a stop.

```
    Input.get_accelerometer() − Input.get_gravity()
                    ↓
        shake/shake_detector.tscn        ← added to any screen that wants an instrument
                    ↓  emits
        ShakeEvents.jingled(ShakeEvent)  ← autoload, one signal, no state
                    ↓  connected by each responder in its own _ready
    ┌───────────────┼───────────────┐
    ↓               ↓               ↓
 jingle_response  flash_response  (an animation, later)
```

The shake detector emits without knowing what listens. A responder connects to the bus in its own `_ready()` and holds no reference to the detector. **Adding, removing or replacing an effect therefore means adding or deleting a node**, with no wiring to change elsewhere. The play screen carries the sound and the capture harness carries the flash, and neither screen knows the other exists.

The `ShakeEvents` bus is global because the bus is stateless and costs nothing while no one shakes the phone. The detector is **not** global, by design: the detector belongs to a screen that wants an instrument, and the title and instructions screens want none.

### What a detected stop carries

`ShakeEvent`, defined in `shake/shake_event.gd`, is a small object instead of a set of loose signal arguments, so adding a field later does not break the responders already connected. A `ShakeEvent` carries the peak magnitude of the stop in metres per second squared, that peak normalized to a 0-to-1 intensity on a perceptual scale, the quantized level, which end of the stroke the stop was, and when the stop happened. **The detector computes each of those values once.** No responder recomputes intensity from magnitude.

### How the detector works, and why

Once per rendered frame, the detector computes linear acceleration, updates a rolling estimate of the dominant motion axis, projects the acceleration onto that axis, and tracks the running peak. The detector fires when the projection falls a set fraction below the peak or reverses direction.

**Each constant in the detector comes from measurement.** `features/C1_09_shake_it_discovery_findings.md` states each value, the run that produced the value, and the reasons the project rejected four alternative techniques; the sixteen recordings behind the findings are in `features/data/C1_09/`. Three design points each replaced an approach that looked correct, and a developer working on the detector should keep all three in mind:

- **The detector projects onto a motion axis instead of using magnitude.** During hard shaking, magnitude does not fall back between the two ends of a stroke, so a magnitude-based detector merged 52 real stops into 3 on the vigorous runs.
- **The detector fires at the peak's release instead of at the first turnover.** A vigorous stroke is noisy while accelerating, and the first dip is most often noise partway up the stroke. Firing at the first dip reported 13 metres per second squared where the true peak was 53.
- **The detector re-arms on a change of direction as well as on falling near zero.** During hard shaking the projection does not return to the release level between stops, so a gate that waited for the release level alone found 20 events where there were 52.

The detector has no refractory period, because the tightest measured gap between two real stops is 50 milliseconds, and a fixed refractory period long enough to help would start swallowing real stops. The arming gate does the same job without a timer.

### The sound responder

`shake/responses/jingle_response.gd` sounds a recording on each stop and uses two values from the stop for different jobs: the level chooses which recording plays, and the intensity scales the recording's volume. A struck bell changes timbre with force as well as amplitude, so the difference in character between a soft strike and a hard strike has to come from a different recording, and volume cannot produce that difference. The intensity ramp then gives a continuous response inside each band, so a shake at the bottom of the soft range still plays quieter than a shake at the top of the soft range.

`app/instrument_definition.gd` gives each bell two banks of recordings, a piano bank and a forte bank. Levels at or below the responder's exported `piano_top_level`, which defaults to 2 of the detector's 5, draw from the piano bank, and levels above `piano_top_level` draw from the forte bank. **A bell with an empty forte bank sounds its piano bank at every level.** The single bank follows the recordings and is no fallback: the strap bells arrived as twenty-five takes with no dynamic split, so the strap bells have one bank, and the strap bells still answer shake strength through the volume ramp.

Within a bank the responder draws at random and excludes the recording that sounded last, so no recording plays twice in a row. The responder excludes by index in a single pass instead of drawing and retrying, because a retry loop does not terminate on a bank that holds the same recording in two entries. One mis-click in a list of twenty-five near-identical filenames can create a duplicate entry, and a retry loop would then hang the application on the first shake.

The responder reads the bell from `InstrumentSelection` instead of waiting for the play screen to assign a stream, because the play screen and the responder both run `_ready()` in an order that would deliver the screen's assignment too late. Reading the selection in the responder removes the ordering question and keeps the play screen ignorant of how the responder produces sound. The capture harness's exported stream resolves into a one-entry piano bank with an empty forte bank, so the responder runs one code path instead of handling two data shapes with a branch at each step.

The responder builds a pool of voices sized from the **longest** recording the bell carries against eight events per second, with a floor of four voices. The pool exists to stop voice reuse from cutting a recording short, and the longest recording runs the most risk of being cut, so the longest recording sets the size. The paddle bells build 18 voices, the strap bells 23, and the pair 24. The responder assigns each voice its recording at play time instead of at pool build time, since any voice can play any recording in either bank. Voices go out in turn, so the reused voice is the oldest one. The project accepts one cost: a burst faster than the pool holds cuts a recording short.

## The capture harness

`capture/shake_capture.tscn` records each motion sample the engine sees to one comma-separated file per run. The harness calibrates the detector against real hand motion, and only a build with `run/main_scene` pointed at the harness reaches the harness.

**The sample clock is the frame clock**, and that fact sets two constraints on the harness. Nothing on the harness screen may animate. The harness writes nothing to disk during a run: the harness holds samples in memory and writes the whole file in one operation at the end, because a write during the run would add file system latency to the interval under measurement. The harness samples in `_process` and not in `_physics_process`, because `_physics_process` runs on its own clock and would read one sensor value twice or skip a value.

On iOS, `user://` resolves to the application's Documents directory. The export preset sets `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`, so a developer can retrieve recorded runs through the phone's Files application without attaching the phone to a development machine.

The harness carries a detector and both responders today, because a developer added them during calibration to hear the algorithm while tuning the algorithm. The extra nodes make the harness recordings no longer measurement-grade: audio and a fading rectangle both consume frame time on the clock under measurement. The project accepts that cost now that the calibration recordings exist.

## Platform notes

**Holiday Sleigh Bells is a native mobile application.** The project builds a native iOS export, and the Xcode project is in `exports/ios2/`. The application is not a web export, a single-page app or a progressive web app. This section states the native target because the documents once omitted the native target, at a cost. The 2026-08-03 sponsor meeting took a direction to deliver a Godot SPA, a later decision reversed that direction, and nobody recorded the reversal, so `features/mvp1_roadmap.md` went on asserting the SPA for three weeks while developers built native features against the roadmap. The project keeps the two documents from the SPA direction, `features/C1_T05_spa_mockup.md` and `features/iphone_spa_exploration.md`, under superseded banners. Any other file in `features/` that frames the web as the target is stale because of the unrecorded reversal.

**Motion sensors exist only on a real device.** The three motion calls return a zero vector in the editor, in the desktop build and in the iOS simulator. The engine documents the zero-vector behaviour, so the zero vector is no fault, and a developer can exercise the shake instrument and the capture harness only on a handset.

**The sample rate equals the frame rate**, because the engine refreshes the motion values once per rendered frame. An iPhone 13 Pro delivers 120 samples per second, not the 60 that the engine source suggests.

**`dt_ms` is no measurement.** Godot on iOS reports the display link's nominal interval, so a per-frame delta reads as a constant while the real intervals vary by a factor of two. The monotonic timestamp is the only real clock.

**The project builds for Android, and one place holds the gravity correction.** The engine reports the gravity vector in opposite directions on iOS and Android. Linear acceleration stays unaffected, because the difference cancels when the detector subtracts gravity, so the detector works on linear acceleration alone.

The Android Build and Play Store Release feature (C1_20) removed the duplicated gravity correction that this section used to warn about. `app/phone_tilt.gd` now carries `PhoneTilt.gravity()`, which applies the platform correction once, and both callers read the sensor through `PhoneTilt.gravity()`: `snow/snow.gd`, which steers the snowfall, and `PhoneTilt.read()`, which the artwork behaviours use. `snow/snow.gd` keeps its own un-normalised in-plane vector and its own angle smoothing, so the two callers share the read and not the logic. **`PhoneTilt.ANDROID_GRAVITY_IS_INVERTED` is the one line that decides the correction.** `legacy/bells/native_gravity_controller.gd` remains the example of a sign assumed instead of routed: the script's mapping is iOS-shaped, and on Android the script's bells would fall upward.

`features/data/C1_09/README.md` records the handset measurements and lists each value not yet measured on Android hardware.

## Conventions

The repository has no application coding standards document, so a review in this repository audits against the conventions the code demonstrates:

- Tab indentation in GDScript.
- A one-line comment at the top of each script naming the file and the script's role, followed by anything a reader needs that the code cannot show.
- Static typing on declarations and return types, including `-> void`.
- Signals connected in `_ready()` instead of in the scene file. Connecting a signal in both places raises a duplicate-connection error at runtime.
- Scene and script files named in lower snake case.
- Exported values used as divisors, bounds or loop counts validated in `_ready()`, with a message naming the value, its permitted range and the correct default.
- A node dependency reached by scene path validated in `_ready()` instead of at first use, so a misconfiguration surfaces at load instead of inside a branch that seldom runs.
- **No fallbacks.** A missing value fails with a message naming what is missing and what to do about it. No code substitutes a default and carries on.

## Testing

**This repository has no test framework.** Three consecutive features recorded the decision not to introduce one. Verification rests on manual steps a developer performs on a handset, supported by a check that the project loads with no errors and that each resource reference resolves.

The project chose to go without a test framework because of the sensor constraint in the platform notes: the parts of the application most worth testing exist only on a real device.
