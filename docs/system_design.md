---
DOCUMENT TYPE: Holiday Sleigh Bells System Design
DOCUMENT TITLE: How Holiday Sleigh Bells Is Put Together
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 1.0
AUTHOR: George Ruzek
VALUE STATEMENT: The one document a developer reads before touching this repository, so the architecture is inherited rather than reverse-engineered from source comments.
LAST UPDATED: August, 22, 2026 12:31
---

# How Holiday Sleigh Bells Is Put Together

Holiday Sleigh Bells turns an audience member's phone into a sleigh bell they shake along with a live orchestral performance of "Sleigh Ride". This document describes how the application is built: what the screens are, what carries state between them, how a shake becomes a sound, and where everything lives.

It is written for a developer arriving at this repository for the first time, and for the development skills that need architectural context. It describes the system as built, not as intended.

## The hard rule about assets

**A media file is never deleted.**

Artwork, audio, fonts, and any other media determined to be unused are moved into `legacy/`, mirroring the path they came from. They are never removed from the repository. This applies to automated work and to hand edits alike, and it holds regardless of how confident anyone is that a file is unused.

The reasoning is that the two possible mistakes cost wildly different amounts. An archived file that turns out to be needed costs one move to recover. A deleted file that turns out to be needed may be unrecoverable, because an asset never committed to version control leaves no trace once removed.

And the analysis that declares a file unused is exactly the kind of analysis that can be wrong. `images/RichmondSymphonyLogo.png` is referenced by the abandoned first version's background scene and by no scene in the current application, so a search for which scenes name it condemns it — yet it is the project's boot splash, reached through `project.godot` by resource identifier rather than by path. Archiving it would have broken the launch of every build. What is in use is decided by tracing both file paths and resource identifiers from the main scene, never by a filename search.

## Repository layout

| Directory | What it holds |
|---|---|
| `app/` | The application: the four screens of the audience flow, their shared placement scripts, and the bell definitions |
| `shake/` | The shake instrument: the signal bus, the detector, and the responders that react to a detected stop |
| `snow/` | The snow effect, which reads the phone's orientation and shake energy to steer falling snow |
| `capture/` | The motion capture harness used to calibrate the shake instrument. Not part of the audience flow |
| `shaders/` | Shared shaders |
| `sounds/`, `images/` | Assets the current application uses |
| `docs/` | This document |
| `features/` | Feature specifications, implementation plans, findings, and the captured motion data under `features/data/` |
| `legacy/` | The abandoned first version of the application and every asset belonging only to it |
| `exports/` | Build output, including the iOS Xcode project. Gitignored apart from that project |

`legacy/` carries a `.gdignore` marker. The engine does not import that directory at all, so nothing in it can be referenced by a scene, reached by a resource identifier, or included in an export bundle. **The consequence is deliberate: the first version of the application no longer runs.** Bringing it back means removing that marker and reimporting.

### Where the governing documents live

The development skills read a project instructions file that names an application called `manta-rai` and places its governing documents under `docs/manta-rai/`. That is a different product. For this repository:

- **System design** — this document, `docs/system_design.md`.
- **Application coding standards** — **does not exist.** The conventions the repository actually demonstrates are listed under "Conventions" below, and a code violation review run here has to substitute them.
- **Implementation plan requirements** — **does not exist.**

The project instructions file is not in this repository. It is injected into each development skill at deploy time from the plugin source, and six copies of it exist, so it cannot be corrected from here.

## The audience flow

Four screens, each advancing to the next with `change_scene_to_file`, which frees the entire scene tree including everything held in it.

```
app/main.tscn            Title. "Tap to start"
        ↓
app/instructions.tscn    How to play. "Continue"
        ↓
app/instrument_select.tscn   Swipe between three bells, and one fun fact. "Continue"
                             The three are the paddle bells, the strap bells, and both together
        ↓
app/instrument.tscn      Play. Shake to sound the chosen bell. "Back" returns to selection
```

`run/main_scene` in `project.godot` points at the title screen by resource identifier. Pointing it at `capture/shake_capture.tscn` instead produces a capture build; that is the only way the harness is reached, and restoring the title screen afterwards is a completion criterion of any feature that changes it.

The play screen is the only screen with backward navigation. The other three move forward only.

### Screen composition

Screens are assembled from small scenes rather than authored as one tree. `title.tscn`, `vignette.tscn`, `winnie.tscn`, and the rest are each a sprite plus a placement script, instanced into whichever screens need them. Two shared scripts do the placing:

- **`app/sprite_position.gd`** positions a node against the design canvas — 1080 by 1920 — with an anchor per axis and an option to respect the device's safe area. The engine expands this canvas rather than stretching it, so on any portrait phone the canvas stays 1080 units wide and grows taller.
- **`app/safe_area_margin.gd`** holds a bottom-anchored control clear of the home indicator. Godot's anchoring measures from the physical window edge and knows nothing about the safe area, so every button in the flow carries this script. It derives its offsets from authored base values rather than adjusting them in place, so repeated recomputes never compound.

`app/fun_fact_bubble.tscn` is one of these small scenes, instanced once on the bell selection screen. It is the only one carrying live text: two `Label` nodes drawing a fun fact from an exported list, which is why it is also the only place in the application where a typeface is configured. The list is served by a shuffle bag held in a static variable, so no fact repeats until all have been shown and the sequence survives the scene change without an autoload or a file.

A composition scene that needs behaviour of its own extends the placement script rather than replacing it, because a node holds only one script. `app/instrument_carousel.gd`, `app/holiday_sleigh_bells.gd`, and `app/fun_fact_bubble.gd` are all built that way: each extends `app/sprite_position.gd`, calls `super()` from its own `_ready`, and goes on carrying the exported placement properties the hosting screen sets on it.

A second family of shared scripts gives a sprite motion rather than a place: `app/tilt_sway.gd` leans one with the phone's side-to-side tilt, `app/continuous_spin.gd` turns one at a constant rate, and `app/tilt_drift.gd` slides one a short way as the phone tilts, all three reading the tilt through `app/phone_tilt.gd`. These attach to the **child sprites** inside an artwork scene rather than to its root, which is why they extend nothing: the root is where the placement script lives and owns `position`, and a child's transform is its own. They also carry no pivot — a sprite's origin is set in the scene by `centered` and `offset`, so where the red tree bends is authored in `app/straight_red_tree.tscn` by eye rather than written into the sway.

Buttons are styled per screen with inline `StyleBoxFlat` sub-resources. There is no shared theme and no shared button scene; the flow's blue is `Color(0.2509804, 0.56078434, 0.8392157, 1)` with a red pressed state, 55-pixel corner radius, and 44-point white text, duplicated in each screen that needs it.

## What crosses a scene change

`change_scene_to_file` destroys everything on the screen, so anything that must outlive it is an autoload. There are two, and they carry very different things.

| Autoload | Script | What it carries |
|---|---|---|
| `InstrumentSelection` | `app/instrument_selection.gd` | The chosen bell, as an `InstrumentDefinition`. Nothing is written to disk; the choice lasts for the session |
| `ShakeEvents` | `shake/shake_event_bus.gd` | One signal, `jingled`. No state at all |

A bell is an `InstrumentDefinition` resource — `app/instrument_definition.gd` — holding two things: the artwork scene that draws it and the recording it sounds. Three exist, in `app/instruments/`. Putting the recording on the bell rather than on the play screen is what lets the sound follow the choice without any screen knowing which bell was picked: the selection screen publishes a bell, the autoload carries it, the play screen and the sound responder each read what they need from it.

The bell selection screen's carousel publishes the chosen bell continuously as it moves, so the choice is already correct the moment Continue is pressed and the button needs no code of its own. It also **opens on the bell already chosen**, which is what makes the play screen's Back button safe: a carousel that always opened on the first bell would overwrite the audience member's choice in the instant between being built and being positioned.

## The shake instrument

The instrument separates detecting a stop from responding to one, and the separation is the whole design.

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

A detector emits without knowing what listens. A responder connects to the bus in its own `_ready()` and never refers to the detector. **Adding, removing, or replacing an effect is therefore adding or deleting a node**, with no wiring to change anywhere else — which is what lets the sound live on the play screen and the flash live on the capture harness without either screen knowing the other exists.

The bus is global because it is stateless and costs nothing when nothing is shaking. The detector is deliberately **not** global: it belongs to a screen that wants an instrument, not to the title and instructions screens.

### What a detected stop carries

`ShakeEvent` — `shake/shake_event.gd` — is a small object rather than a set of loose signal arguments, so adding a field later does not break every responder already connected. It carries the peak magnitude of the stop in metres per second squared, that same stop normalized to a 0-to-1 intensity spaced perceptually, its quantized level, which end of the stroke it was, and when it happened. **Every one of those is computed once, in the detector.** No responder recomputes intensity from magnitude.

### How the detector works, and why

Once per rendered frame it computes linear acceleration, updates a rolling estimate of the dominant motion axis, projects onto that axis, tracks the running peak, and fires when the projection falls a set fraction below that peak or reverses direction.

**Every constant in it was measured**, not chosen. `features/C1_09_shake_it_discovery_findings.md` states each value, the run it came from, and why the four alternative techniques were rejected; the sixteen recordings behind it are in `features/data/C1_09/`. Three design points are worth carrying in your head, because each replaced an approach that looked obviously correct:

- **The projection onto a motion axis, not the magnitude.** Magnitude does not fall back between the two ends of a stroke when shaking is hard, so a magnitude-based detector merged 52 real stops into 3 on the vigorous runs.
- **Firing at the peak's release, not at the first turnover.** A vigorous stroke is noisy while accelerating, and the first dip is usually noise partway up. Firing there reported 13 metres per second squared where the true peak was 53.
- **Re-arming on a change of direction as well as on falling near zero.** On hard shaking the projection never returns to the release level between stops, so a gate waiting only for that found 20 events where there were 52.

There is no refractory period. The tightest measured gap between two real stops is 50 milliseconds, and any fixed refractory long enough to be useful would start swallowing them; the arming gate does the same job without a timer.

### The sound responder

`shake/responses/jingle_response.gd` sounds a recording on every stop. **Two things about the stop are used, and they do different jobs.** Its level chooses which recording plays, and its intensity scales how loudly that recording plays. A struck bell changes timbre with force rather than only amplitude, so the change of character between a soft strike and a hard one has to come from a different recording; volume alone cannot produce it. The intensity ramp then gives the continuous response inside each band, so a shake at the bottom of the soft range is still quieter than one at the top of it.

A bell carries two banks of recordings, a piano bank and a forte bank, declared on `app/instrument_definition.gd`. Levels at or below the responder's exported `piano_top_level`, which defaults to 2 of the detector's 5, draw from the piano bank; every level above it draws from the forte bank. **A bell whose forte bank is empty sounds its piano bank at every level.** That is not a fallback: the bell has one bank because only one was recorded, and it still answers how hard it was shaken through the volume ramp. The strap bells are the case, delivered as twenty-five takes with no dynamic split.

Within a bank the draw is random, excluding whatever sounded last, so no recording is heard twice in a row. The exclusion is by index in a single pass rather than a draw-and-retry loop: a retry loop never terminates on a bank holding the same recording in two entries, which is one mis-click to create in a list of twenty-five near-identical filenames and would hang the application on the first shake.

It reads the selection rather than having the play screen assign a stream because both the screen and the responder run `_ready()`, in an order that would make an assignment from the screen arrive too late. Reading it in the responder removes the ordering question and keeps the play screen ignorant of how sound is produced. The exported stream the capture harness uses resolves into a one-entry piano bank with an empty forte bank, so there is one code path rather than two shapes with a branch between them at every step.

Voices are a pool, sized from the **longest** recording the bell carries against eight events per second, with a floor of four. The longest is the right measure because the pool exists to stop a recording being cut short by reuse of its voice, and the longest is the one most at risk of it. The paddle bells therefore build 18 voices, the strap bells 23, and the pair 24. Each voice is assigned its recording at the moment it is played rather than when the pool is built, since any voice can now play anything in either bank. Voices are taken in turn, so the one reused is always the oldest. The trade is explicit: a burst faster than the pool holds cuts a recording short.

## The capture harness

`capture/shake_capture.tscn` records every motion sample the engine sees to one comma-separated file per run. It exists to calibrate the detector against real hand motion, and it is reached only by pointing `run/main_scene` at it.

Two constraints shape it, both stemming from one fact: **the sample clock is the frame clock.** Nothing on that screen may animate, and nothing is written to disk while a run is active — samples are held in memory and the whole file written in one operation at the end, because a write inside the run would put file system latency into the interval being measured. Sampling happens in `_process` and never in `_physics_process`, which runs on its own clock and would read the same sensor value twice or skip one entirely.

On iOS `user://` resolves to the application's Documents directory, and the export preset sets `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` so recorded runs are retrievable through the phone's Files application without attaching it to a development machine.

The harness currently also carries a detector and both responders, added during calibration so the algorithm could be heard as it was tuned. That makes its recordings no longer measurement-grade, since audio and a fading rectangle both consume frame time on the clock being measured — an accepted trade now that the calibration data is captured.

## Platform notes

**This is a native mobile application.** It is built and exported natively for iOS; the Xcode
project is in `exports/ios2/`. It is not a web export, not a single-page app, and not a
progressive web app. This is stated explicitly because it was not, and the omission cost
something: a direction taken at the 2026-08-03 sponsor meeting to deliver a Godot SPA was
later reversed, nothing recorded the reversal, and `features/mvp1_roadmap.md` went on
asserting the SPA for three weeks while native features were built against it. The documents
from that direction — `features/C1_T05_spa_mockup.md` and
`features/iphone_spa_exploration.md` — are kept and carry superseded banners. Anything else
in `features/` that frames the web as the target is stale by the same cause.

**Sensors only exist on a real device.** The three motion calls return a zero vector in the editor, in the desktop build, and in the iOS simulator. This is documented engine behaviour rather than a fault, and it means nothing about the shake instrument or the capture harness can be meaningfully exercised anywhere but a handset.

**The sample rate is the frame rate**, because the engine refreshes the motion values once per rendered frame. On an iPhone 13 Pro that is 120 samples per second, not the 60 that reading the engine source suggests.

**`dt_ms` is not a measurement.** Godot on iOS reports the display link's nominal interval, so any per-frame delta reads as a constant while the real intervals vary by a factor of two. The monotonic timestamp is the only real clock.

**Android is unverified.** The engine reports the gravity vector in opposite directions on the two platforms. Linear acceleration is unaffected, since the difference cancels when gravity is subtracted, which is why the detector works on that quantity and nothing else — but no Android hardware has been measured. `features/data/C1_09/README.md` records what to check first. `legacy/bells/native_gravity_controller.gd` is the illustration of what goes wrong when this is assumed: its mapping is iOS-shaped, and on Android its bells would fall upward. Two live copies of that same iOS-shaped mapping exist and are named together here so whoever measures an Android handset finds both: `snow/snow.gd`, which steers the snowfall, and `app/phone_tilt.gd`, which the artwork behaviours read through.

## Conventions

There is no application coding standards document. These are the conventions the repository demonstrates, and a review run here audits against them.

- Tab indentation in GDScript.
- A one-line comment at the top of each script naming the file and its role, followed by whatever a reader needs that the code cannot tell them.
- Static typing on declarations and return types, including `-> void`.
- Signals connected in `_ready()` rather than in the scene file. Connecting in both places raises a duplicate-connection error at runtime.
- Scene and script files named in lower snake case.
- Exported values used as divisors, bounds, or loop counts are validated in `_ready()`, with a message naming the value, its permitted range, and the correct default.
- A node dependency reached by scene path is validated in `_ready()` rather than at its first use, so a misconfiguration surfaces at load rather than inside a branch that runs rarely.
- **No fallbacks.** A missing value fails with a message naming what is missing and what to do about it. Nothing substitutes a default and carries on.

## Testing

**This repository has no test framework.** Three consecutive features have recorded the decision not to introduce one, and verification rests on manual steps performed on a handset, supported by a check that the project loads with no errors and every resource reference resolves.

That is a deliberate position rather than an oversight, and it rests on the platform note above: the parts of this application most worth testing are the parts that only exist on a real device.
