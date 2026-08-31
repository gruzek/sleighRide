# sleighRide

Holiday Sleigh Bells: a phone becomes a sleigh bell an audience shakes along with a live
performance of "Sleigh Ride".

## Repository structure

| Directory | What it holds |
|---|---|
| `app/` | The audience flow: title, instructions, bell selection, and play screens |
| `shake/` | The shake instrument: motion detection and the effects that respond to it |
| `capture/` | The motion capture harness used to calibrate the shake instrument, and the camera probe |
| `snow/` | The snow effect: one scene any screen adds to get snow that falls the way the phone is held |
| `docs/` | The system design |
| `features/` | Feature specifications, implementation plans, and the roadmap |
| `shaders/` | Shared shaders |
| `sounds/`, `images/` | Assets the application uses |
| `legacy/` | The abandoned version 1 build and every asset belonging only to it. Not imported, never shipped |

## The shake instrument

`shake/` detects the moment a real sleigh bell would sound and lets any number of effects respond
to it, without those effects knowing how detection works.

- `shake_event_bus.gd` is autoloaded as `ShakeEvents` and declares one signal, `jingled`. It is
  the whole of the coupling between detection and response.
- `shake_detector.tscn` reads the motion sensors, applies the firing rules, and emits. Add it to
  a screen that wants an instrument; it is deliberately not global.
- `shake_event.gd` is the payload: the peak magnitude of the stop, its intensity on a 0 to 1
  perceptual scale, its level, its direction, and when it happened.
- `responses/` holds effects. Each connects to `ShakeEvents.jingled` in its own `_ready` and
  reads only what it needs, so adding or replacing an effect is adding or deleting a node.

Every constant in the detector was measured rather than guessed. The measurements come from the
Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09), whose capture
harness is in `capture/` and whose specification and plan are in `features/`.

## The snow

`snow/` is falling snow that any screen gains by adding one node. `snow.tscn` carries three
`GPUParticles2D` layers that differ in weight, speed, size, and opacity, and that draw at two
different depths: the nearest passes over the screen's artwork and text, the other two behind
them but still in front of the vignette.

- `snow.gd` is the driver, and the only part of the effect that reads a sensor. It takes the
  device's gravity vector, projects it into the plane of the screen, smooths it, and writes each
  layer's gravity from it. A phone lying flat holds the heading it had and slows to a drift
  rather than spinning on sensor noise.
- It reads the accelerometer too, for the snow-globe response: shaking throws the flakes against
  the hand's motion, suppresses the fall so they tumble in place, drives the noise field harder,
  and blooms the flake count, all from one agitation value whose slow release is the settle. The
  snow neither emits on `ShakeEvents` nor listens to it, so it works on screens with no
  instrument and can never double-fire a bell.
- `snow_layer.gd` is one depth layer. It owns how heavy its flakes are, how fast they fall, and
  how wildly they answer a shake; the driver owns which way down is and where flakes come in
  from.
- New flakes are born on a thin band just outside the viewport that orbits as the direction
  changes, so snow always arrives from off screen whichever way the phone is held. Flakes already
  in flight curve onto a new heading, because the direction is carried on gravity rather than on
  a spawn velocity.
- `shaders/snow_sparkle.gdshader` gives every flake its own rhythm from a per-flake seed: a
  brightness that oscillates, and a width that narrows to a paper edge and back.

Three settings are load-bearing and have no visual symptom that points at them. `local_coords`
must stay off, or the live snow sweeps bodily across the screen when the band swings.
`visibility_rect` must stay large, because the node spends most of its life outside the viewport
and at the default the whole system is culled and nothing is drawn. And damping must stay in its
friction form: in its default form it stops the snow dead rather than trimming its acceleration.

The one thing the effect asks of a host is draw order. The host's own backdrop must sit below the
back snow - on the instructions screen that is `z_index` -3 on the background and -2 on the
vignette, leaving the content at its default 0. A screen that skips this gets its back snow
hidden behind its own background.

## The title animation

The three words of the title artwork arrive one at a time on a beat and then go on breathing on
it. `app/holiday_sleigh_bells.tscn` holds `Holiday`, `Sleigh`, and `Bells` as three sprites, and
`app/holiday_sleigh_bells.gd` animates them: the screen holds still for a second, then each word
grows from nothing, past its resting size, and settles back onto it, one word every quarter note.

- The pattern is two bars of 4/4 at 80 beats per minute - three words on beats one, two, and
  three, then five beats of rest - repeating for as long as the screen is shown. The first loop
  is the entrance; every loop after it is the same phrase as a slight pulse, with no overshoot to
  correct.
- The loop is exported in beats rather than seconds, so changing `beat_seconds` moves the whole
  pattern together and the loop can never be set to a length that is out of time with the beat.
- Every animated size is a multiplier on the scale each word is authored at, read from the scene
  in `_ready`. The three words are hand-sized differently, so resizing one in the editor is
  picked up on the next run rather than fought.
- The animation travels inside the artwork scene, so any screen that instances it gets the
  entrance and the pulse without doing anything. `animate` unticked leaves the three words at
  their authored scales and nothing moves at all.

Nothing runs in the editor, where all three words stay at their authored scales so the
composition can still be authored. The script extends `app/sprite_position.gd` rather than
replacing it, because the title screen places this scene through that script's exported
properties and a node holds only one script. The bell carousel is built the same way, for the
same reason.

## The artwork behaviours

Three small scripts in `app/` give a still sprite motion. Each attaches to the sprite it animates
and nothing else has to be wired up; a piece of artwork gains a behaviour by having a script added
to it and its numbers set. The title screen carries all three, through the two artwork scenes it
already instances rather than through any edit of its own.

- `tilt_sway.gd` leans a sprite the way the phone is tilted side to side, smoothed so a hand that
  is never quite still does not make it tremble, and clamped so no amount of tilt leans it further.
  The red tree carries it.
- `continuous_spin.gd` turns a sprite at a constant rate, forever. It reads no sensor, so it runs
  the same on a handset and on the desktop. The blue snowflake carries it.
- `tilt_drift.gd` slides a sprite a short way from where it is authored as the phone tilts, clamped
  independently on each axis. The green halo behind the snowflake carries it.

Two things about them are load-bearing and easy to undo by accident.

**They carry no pivot.** `tilt_sway.gd` and `continuous_spin.gd` rotate the node they are attached
to, about that node's own origin, and neither holds a pivot value. Where a sprite turns is set in
the scene by `centered` and `offset`, so it is positioned by eye in the editor. That is what makes
the tree bend rather than spin: `app/straight_red_tree.tscn` moves the origin down to the foot of
the trunk, with a compensating `position` so the artwork does not move. A script that owned its own
pivot would take that adjustment away from the editor.

**They attach to child sprites, never to an artwork scene's root.** `app/sprite_position.gd` owns
the root's `position`, overwrites it on ready, on resize, and on every exported-property change,
and strips it from storage. A drift written there is discarded. Unlike `instrument_carousel.gd` and
`holiday_sleigh_bells.gd`, which extend the placement script because they live on the root, these
sit on children that no other script touches, so they extend nothing.

Reading the tilt is shared. `app/phone_tilt.gd` projects the device's gravity vector into the plane
of the screen and rejects a reading too small to be anything but noise, and both tilt behaviours go
through it. Where there is no sensor at all - the editor, the desktop build, the simulator - it
returns the caller's own idea of level, so the tree stands upright and the halo sits exactly where
it was placed rather than drifting to a clamp.

The one number that is not obvious is `vertical_neutral_tilt` on `tilt_drift.gd`. Side to side,
level is genuinely no roll. Front to back it is not: the reading runs 1.0 with the phone upright
down to 0.0 with it flat, so a phone being held normally sits near the top of that range, and
treating zero as level would pin the halo at its clamp the whole time anyone is holding the thing.

Nothing runs in the editor. None of the three is a `@tool` script, so a screen can be composed
without a snowflake turning underneath the work.

## Winnie's fun fact bubble

`app/fun_fact_bubble.tscn` is the speech bubble on the bell selection screen. It shows one fun
fact, drawn when the screen is entered and held until the screen is left.

- The facts are an exported list of text on the scene's root, edited in the inspector. Adding a
  fact is adding an entry; there is no fixed count and no file to maintain. An empty list hides
  the bubble at runtime rather than showing a heading over nothing, and does not hide it in the
  editor, where the composition still has to be authorable.
- Facts come from a shuffle bag rather than a random pick, so every fact is shown once before
  any is repeated. The bag is a static variable, which is what lets it survive the scene change
  the play screen's Back button causes; nothing is written to disk and no autoload is involved.
  It refills from the pool as it stands when it empties, so a fact added between visits arrives
  at the next refill rather than mid-shuffle.
- Both pieces of text are live `Label` nodes, and they are the only live text in the application
  outside a button label. The typeface is one exported property both of them take from, unset
  today, so the engine's default face is what renders until a brand font is licensed. The fact is
  measured and stepped down from its starting size until it fits the label's box, and never below
  an exported floor; a fact that will not fit even there is reported by name.
- **The entrance scales the whole node and the pulse scales the sprite alone.** There is nothing
  to read while the bubble is arriving, so the pop carries the text with it. Once the fact is
  legible only the white shape keeps the beat, because a five percent wobble resamples the glyphs
  on the one thing on that screen anybody is reading.
- The rhythm is the title animation's, reusing its numbers: an entrance that overshoots and
  settles, then the same gesture at a smaller peak once every eight beats at 80 beats per minute.
- **The pop grows from the tip of the tail, and the script carries no pivot.** The origin is set
  in the scene by the sprite's `centered` and `offset`, at texture coordinates `(30, 402)`, which
  is where the supplied artwork's tail meets Winnie's mouth. Moving it is a scene edit, the same
  arrangement the red tree's bend uses.
- Both labels ignore mouse and touch input. The bubble sits inside the carousel's drag band, so a
  label left at its default would carve a dead zone out of the middle of the swipe region on the
  screen whose whole purpose is swiping — invisible on a desktop and only found under a thumb.

## The Jingle Cam

`app/jingle_cam.tscn` is a fifth screen, reached from the bell-selection screen by the red
"Jingle Cam" button rather than as a step in the flow. It puts the phone's live camera behind
the season's artwork and takes a photograph of the whole composition, which it hands to the
phone's own share sheet.

- `app/camera_feed_view.gd` owns the camera: which one is running, and how the picture is drawn.
  A screen gains a camera by adding this node, the way a screen gains weather by adding
  `snow/snow.tscn`.
- **The picture arrives as two textures, not one.** On iOS a feed reports `FEED_YCBCR_SEP`, so a
  luma plane and a chroma plane arrive separately and `shaders/ycbcr_to_rgb.gdshader` combines
  them. A single `CameraTexture` on a `TextureRect` draws a green picture, which reads as a
  broken exposure rather than as missing colour.
- **Feeds are chosen by name.** An iPhone reports eight of them, including the fused Dual, Triple
  and TrueDepth virtual cameras. "The first feed whose position matches" gives the right answer
  on one handset and the TrueDepth camera on another.
- **The first activation always fails**, on the launch where camera permission is first granted.
  The engine starts the permission request, returns before it is answered, and never marks the
  feed active afterwards - so the camera runs while the engine believes it does not.
  `_await_activation` deactivates and reactivates until the picture arrives.
- **The mirror is on the camera layer alone.** Mirroring the composed screen would reverse the
  lettering and the Richmond Symphony's name in every photograph. Which axis is flipped depends
  on the rotation, because a mirror has to be a left-right flip on the screen, not in the texture.
- **The controls are hidden for the captured frame**, because the photograph is a capture of the
  viewport and the buttons are in it.

Everything measured on a handset to build this, including what differs on Android, is in
`features/jingle_jam_cam_camera_exploration.md` section 6a.

## The camera probe

`capture/camera_probe.tscn` reports what a phone's cameras actually are - how many feeds, what
each is called, which way each points, what image format each delivers - and draws its findings
on screen so they can be read without attaching the phone to Xcode. Like the motion capture
harness it is reached only by pointing `run/main_scene` at it, and restoring the title screen
afterwards is part of finishing with it.

It exists because there is no camera in the editor or the simulator, and because every value a
feed reports before it has been activated is a placeholder rather than a measurement.

## The capture harness

`capture/shake_capture.tscn` records every motion sample the engine sees to one comma-separated
file per run, for calibrating the detector against real hand motion. It is reached by being run
directly as the main scene and is not part of the audience flow. The recorded runs are analysed
off the device; nothing in the harness judges what it records.
