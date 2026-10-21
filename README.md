# sleighRide

Holiday Sleigh Bells turns a phone into a sleigh bell that an audience shakes along with a live
performance of "Sleigh Ride".

## Repository structure

| Directory | What it holds |
|---|---|
| `app/` | The audience flow: title, instructions, bell selection, and play screens |
| `shake/` | The shake instrument: motion detection and the effects that respond to a detected stop |
| `capture/` | The motion capture harness that calibrates the shake instrument, and the camera probe |
| `snow/` | The snow effect: one scene a screen adds to get snow that falls the way the phone is held |
| `docs/` | The system design |
| `features/` | Feature specifications, implementation plans, and the roadmap |
| `shaders/` | Shared shaders |
| `sounds/`, `images/` | Assets the application uses. The bell recordings are in `sounds/v2/`, one folder per instrument |
| `legacy/` | The abandoned version 1 build and each asset belonging only to it. The engine does not import it, and no build ships it |
| `android/` | The Gradle build template for the Android export. The editor generates it, and `.gitignore` excludes it |

## Building for Android

Holiday Sleigh Bells ships on iPhone and Android from the same source. iOS exports through Xcode
from `exports/ios2/`. Android needs a toolchain set up once, at fixed versions. The versions come
from `config.gradle` inside the `android_source.zip` that Godot 4.7.2 ships, and a newer version
fails instead of degrading: the Android Gradle Plugin is 8.6.1, the Gradle wrapper is 8.11.1, and
neither runs on a Java Development Kit past 17.

```bash
brew install --cask temurin@17
brew install --cask android-commandlinetools
sdkmanager --sdk_root="$HOME/Library/Android/sdk" "platforms;android-36" "build-tools;36.0.0"
sdkmanager --sdk_root="$HOME/Library/Android/sdk" --licenses
```

`sdkmanager` needs the `--sdk_root` flag. Without the flag, `sdkmanager` installs into Homebrew's
own SDK directory instead of the directory the editor points at, and the export then reports a
missing platform while the packages sit in the other directory.

In the editor, set the Java Development Kit path (`/usr/libexec/java_home -v 17`) and the Software
Development Kit path under **Godot → Editor Settings → Export → Android**, then run **Project →
Install Android Build Template** to write `android/build/`.

The Android export requires a Gradle build, because `addons/SharePlugin` ships its Android half as
an archive and Godot's pre-built template cannot package an archive. The plugin declares its own
packaging through an `EditorExportPlugin`, so the project needs no plugin definition file.

**Do not lower the minimum Software Development Kit level below 24.** The engine's Android camera
backend runs on Camera2, which requires level 24, and a lower floor removes the camera without an
error. Leave `gradle_build/min_sdk` and `gradle_build/target_sdk` empty so the build template keeps
its own values, which are already correct.

## The shake instrument

`shake/` detects the moment a real sleigh bell would sound and lets any number of effects respond
to that moment without knowing how detection works.

- `shake_event_bus.gd` runs as the `ShakeEvents` autoload and declares one signal, `jingled`. The
  `jingled` signal is the only coupling between detection and response.
- `shake_detector.tscn` reads the motion sensors, applies the firing rules, and emits `jingled`.
  Add the detector to a screen that wants an instrument; the detector is not global, by design.
- `shake_event.gd` defines the payload: the peak magnitude of the stop, the stop's intensity on a
  0 to 1 perceptual scale, the stop's level, the stop's direction, and the time of the stop.
- `responses/` holds the effects. Each effect connects to `ShakeEvents.jingled` in its own
  `_ready` and reads only the fields it needs, so adding or replacing an effect means adding or
  deleting a node.

Each constant in the detector comes from measurement. The Measure a Real Shake So the Bells Sound
When a Real Bell Would feature (C1_09) produced the measurements; the feature's capture harness is
in `capture/`, and the feature's specification and plan are in `features/`.

### How a bell sounds

Each bell's resource in `app/instruments/` sets two banks of recordings: a piano bank of soft
takes and a forte bank of hard ones. The strength of the shake picks the bank and also scales the
volume, because a bell struck hard sounds brighter and busier than a soft strike, and volume
cannot produce that change in character.

- Levels 1 and 2 of the detector's five draw from the piano bank, and levels 3 to 5 draw from the
  forte bank. One number, `piano_top_level` on the `JingleResponse` node, sets the boundary.
- A bell with an empty forte bank sounds its piano bank at every level. The strap bells have an
  empty forte bank because their twenty-five takes arrived with no soft-and-hard split, and the
  strap bells still get louder as you shake harder.
- No recording sounds twice in a row: within a bank, the responder draws at random and excludes
  the last recording.
- The responder sizes the voice pool from the longest recording the bell carries, so voice reuse
  does not clip a recording. Shaking faster than the pool holds still cuts a recording short, and
  the project accepts that trade.

The selection screen offers three choices: the two instruments the project recorded, and a scene
that shows both instruments together, since the third set of recordings is of the two together.
`app/sleighbells_pair.tscn` holds the pair and instances the two bell scenes instead of their
images, so re-cutting either instrument updates the pair with no edit to the pair scene. A
developer sets the pair's overlap, angles and scale in `app/sleighbells_pair.tscn` and tunes them
by opening the scene.

## The snow

`snow/` provides falling snow that a screen gains by adding one node. `snow.tscn` carries three
`GPUParticles2D` layers that differ in weight, speed, size and opacity and draw at two depths: the
nearest layer passes over the screen's artwork and text, and the other two layers pass behind the
artwork and text but in front of the vignette.

- `snow.gd` is the driver and the only part of the effect that reads a sensor. The driver takes
  the device's gravity vector, projects the vector into the plane of the screen, smooths the
  result, and writes each layer's gravity from the smoothed vector. When the phone lies flat, the
  driver holds the last heading and slows the snow to a drift instead of spinning the snow on
  sensor noise.
- `snow.gd` also reads the accelerometer for the snow-globe response. Shaking throws the flakes
  against the hand's motion, suppresses the fall so the flakes tumble in place, drives the noise
  field harder, and blooms the flake count, all from one agitation value whose slow release
  produces the settle. The snow neither emits on `ShakeEvents` nor listens to `ShakeEvents`, so the
  snow works on screens with no instrument and cannot double-fire a bell.
- `snow_layer.gd` is one depth layer. Each layer owns the weight of its flakes, their fall speed,
  and how hard they answer a shake; the driver owns which way is down and where flakes enter.
- New flakes start on a thin band just outside the viewport, and the band orbits as the direction
  changes, so snow arrives from off screen whichever way the phone is held. Flakes already in
  flight curve onto a new heading, because the driver carries the direction on gravity instead of
  on a spawn velocity.
- `shaders/snow_sparkle.gdshader` gives each flake its own rhythm from a per-flake seed: a
  brightness that oscillates, and a width that narrows to a paper edge and back.

Three snow settings are load-bearing, and a wrong value in any of the three produces a symptom
that does not point back at the setting. `local_coords` must stay off, or the live snow sweeps
across the screen as a block when the band swings. `visibility_rect` must stay large, because the
node spends most of its life outside the viewport, and at the default size the engine culls the
whole system and draws nothing. Damping must stay in its friction form, because the default form
stops the snow dead instead of trimming its acceleration.

The snow effect asks a host screen for one thing: draw order. The host's own backdrop must sit
below the back snow. On the instructions screen, the background sits at `z_index` -3 and the
vignette at -2, with the content at its default 0. A screen that skips the draw order hides its
back snow behind its own background.

## The title animation

The title artwork's three words arrive one at a time on a beat and then keep breathing on the
beat. `app/holiday_sleigh_bells.tscn` holds `Holiday`, `Sleigh` and `Bells` as three sprites, and
`app/holiday_sleigh_bells.gd` animates the sprites: the screen holds still for a second, then each
word grows from nothing, past its resting size, and settles back, one word every quarter note.

- The pattern is two bars of 4/4 at 80 beats per minute: three words on beats one, two and three,
  then five beats of rest, repeating while the screen stays up. The first loop is the entrance,
  and each later loop repeats the phrase as a slight pulse with no overshoot to correct.
- The script exports the loop in beats instead of seconds, so changing `beat_seconds` moves the
  whole pattern together, and no loop length can fall out of time with the beat.
- Each animated size is a multiplier on the scale the word is authored at, which the script reads
  from the scene in `_ready`. The three words have different hand-set sizes, so the next run picks
  up a resize made in the editor instead of fighting it.
- The animation travels inside the artwork scene, so a screen that instances the scene gets the
  entrance and the pulse with no extra work. With `animate` unticked, the three words stay at
  their authored scales and nothing moves.

The animation does not run in the editor, where the three words stay at their authored scales so
a developer can still compose the screen. `holiday_sleigh_bells.gd` extends
`app/sprite_position.gd` instead of replacing `sprite_position.gd`, because the title screen places
the scene through the placement script's exported properties and a node holds only one script.
The bell carousel extends the placement script on the same grounds: a node holds only one script.

## The artwork behaviours

Three small scripts in `app/` give a still sprite motion. Each script attaches to the sprite it
animates and needs no other wiring; a piece of artwork gains a behaviour when a developer adds the
script and sets its numbers. The title screen carries all three behaviours through the two artwork
scenes the title screen already instances, with no edit to the title screen itself.

- `tilt_sway.gd` leans a sprite the way the phone tilts side to side. The script smooths the lean
  so a hand that is never quite still does not make the sprite tremble, and clamps the lean so
  extra tilt adds nothing past the limit. The red tree carries `tilt_sway.gd`.
- `continuous_spin.gd` turns a sprite at a constant rate without end. The script reads no sensor,
  so the spin runs the same on a handset and on the desktop. The blue snowflake carries
  `continuous_spin.gd`.
- `tilt_drift.gd` slides a sprite a short way from its authored position as the phone tilts, with
  a separate clamp on each axis. The green halo behind the snowflake carries `tilt_drift.gd`.

Two properties of the behaviour scripts are load-bearing and easy to undo by accident.

**The behaviour scripts carry no pivot.** `tilt_sway.gd` and `continuous_spin.gd` rotate the node
they attach to about the node's own origin, and neither script holds a pivot value. The scene sets
a sprite's turning point through `centered` and `offset`, so a developer positions the turning
point by eye in the editor. The scene-set origin makes the tree bend instead of spin:
`app/straight_red_tree.tscn` moves the origin down to the foot of the trunk, with a compensating
`position` that keeps the artwork in place. A script that owned its own pivot would take the
origin adjustment away from the editor.

**The behaviour scripts attach to child sprites and never to an artwork scene's root.**
`app/sprite_position.gd` owns the root's `position`: the placement script overwrites `position` on
ready, on resize and on each exported-property change, and strips `position` from storage. The
placement script discards a drift written to the root. `instrument_carousel.gd` and
`holiday_sleigh_bells.gd` extend the placement script because they live on the root. The behaviour
scripts sit on children that no other script touches, so the behaviour scripts extend nothing.

`app/phone_tilt.gd` holds the shared tilt reading: the script projects the device's gravity vector
into the plane of the screen and rejects a reading too small to be anything but noise, and both
tilt behaviours read through `phone_tilt.gd`. In the editor, the desktop build and the simulator,
which have no sensor, `phone_tilt.gd` returns the caller's own idea of level, so the tree stands
upright and the halo sits where the developer placed it instead of drifting to a clamp.

`vertical_neutral_tilt` on `tilt_drift.gd` is the one setting a developer would not guess. Side to
side, level means no roll. Front to back, level means something else: the reading runs from 1.0
with the phone upright to 0.0 with the phone flat, so a phone held in the hand sits near the top of
the range. Treating zero as level would pin the halo at its clamp the whole time someone holds the
phone.

None of the three behaviour scripts is a `@tool` script, so the behaviours do not run in the
editor, and a developer can compose a screen without a snowflake turning underneath the work.

## Winnie's fun fact bubble

`app/fun_fact_bubble.tscn` is the speech bubble on the bell selection screen. The bubble draws one
fun fact when the audience member enters the screen and holds the fact until the audience member
leaves.

- A developer edits the facts in the inspector, as an exported list of text on the scene's root.
  Adding a fact means adding an entry; the list has no fixed count and no file to maintain. At
  runtime, an empty list hides the bubble instead of showing a heading over nothing. In the
  editor, an empty list leaves the bubble visible, because a developer still has to compose the
  screen around the bubble.
- The bubble takes facts from a shuffle bag instead of a random pick, so the bubble shows each fact
  once before repeating any. The bag is a static variable, so the bag survives the scene change
  that the play screen's Back button causes, with nothing written to disk and no autoload. When
  the bag empties, the bag refills from the pool as the pool stands, so a fact added between
  visits arrives at the next refill instead of mid-shuffle.
- The bubble's two pieces of text are live `Label` nodes, the only live text in the application
  outside button labels. Both labels take their typeface from one exported property, unset today,
  so the engine's default face renders until the project licenses a brand font. The script
  measures the fact and steps the size down from its starting size until the fact fits the
  label's box, stopping at an exported floor, and the script reports by name a fact that still
  does not fit at the floor.
- **The entrance scales the whole node, and the pulse scales the sprite alone.** The audience has
  nothing to read while the bubble arrives, so the pop carries the text with the bubble. Once the
  fact is legible, only the white shape keeps the beat, because a five percent wobble would
  resample the glyphs on the one thing on that screen the audience reads.
- The bubble reuses the title animation's rhythm and numbers: an entrance that overshoots and
  settles, then the same gesture at a smaller peak once every eight beats at 80 beats per minute.
- **The pop grows from the tip of the tail, and the script carries no pivot.** The sprite's
  `centered` and `offset` in the scene set the origin at texture coordinates `(30, 402)`, where the
  supplied artwork's tail meets Winnie's mouth. Moving the origin is a scene edit, the same
  arrangement the red tree's bend uses.
- Both labels ignore mouse and touch input. The bubble sits inside the carousel's drag band, so a
  label left at the default input setting would carve a dead zone out of the middle of the swipe
  region on a screen built for swiping. A desktop would hide the dead zone, and only a thumb on a
  handset would find it.

## The Jingle Cam

`app/jingle_cam.tscn` is a fifth screen, reached from the bell selection screen by the red
"Jingle Cam" button instead of as a step in the flow. The Jingle Cam screen puts the phone's live
camera behind the season's artwork, takes a photograph of the whole composition, and hands the
photograph to the phone's share sheet.

- `app/camera_feed_view.gd` owns the camera: which camera runs, and how the script draws the
  picture. A screen gains a camera by adding the `camera_feed_view.gd` node, the way a screen
  gains weather by adding `snow/snow.tscn`.
- **The camera picture arrives as two textures.** On iOS a feed reports `FEED_YCBCR_SEP`, so a
  luma plane and a chroma plane arrive separately, and `shaders/ycbcr_to_rgb.gdshader` combines
  the two planes. A single `CameraTexture` on a `TextureRect` draws a green picture, and a
  developer reads the green picture as a broken exposure instead of missing colour.
- **The script chooses feeds by name.** An iPhone reports eight feeds, including the fused Dual,
  Triple and TrueDepth virtual cameras. Picking "the first feed whose position matches" gives the
  right camera on one handset and the TrueDepth camera on another.
- **The first activation fails** on the launch where the audience member first grants camera
  permission. The engine starts the permission request, returns before the audience member
  answers, and does not mark the feed active afterwards, so the camera runs while the engine
  believes the camera is off. `_await_activation` deactivates and reactivates the feed until the
  picture arrives.
- **The mirror applies to the camera layer alone.** Mirroring the composed screen would reverse
  the lettering and the Richmond Symphony's name in each photograph. The flipped axis depends on
  the rotation, because the mirror has to flip left to right on the screen and not in the texture.
- **The screen hides the controls for the captured frame**, because the photograph captures the
  viewport and the buttons sit in the viewport.

`features/jingle_jam_cam_camera_exploration.md` section 6a records each handset measurement behind
the Jingle Cam, including the Android differences.

## The camera probe

`capture/camera_probe.tscn` reports what a phone's cameras are: how many feeds, each feed's name,
which way each feed points and which image format each feed delivers. The probe draws the findings
on screen so a developer can read them without attaching the phone to Xcode. Like the motion
capture harness, the probe runs only when `run/main_scene` points at the probe, and restoring the
title screen afterwards is part of finishing with the probe.

The probe exists because the editor and the simulator have no camera, and because each value a
feed reports before activation is a placeholder instead of a measurement.

## The capture harness

`capture/shake_capture.tscn` records each motion sample the engine sees to one comma-separated
file per run, for calibrating the detector against real hand motion. A developer reaches the
harness by running the harness as the main scene, and the harness sits outside the audience flow.
Analysis of the recorded runs happens off the device; the harness passes no judgement on what it
records.
