# sleighRide

Holiday Sleigh Bells: a phone becomes a sleigh bell an audience shakes along with a live
performance of "Sleigh Ride".

## Repository structure

| Directory | What it holds |
|---|---|
| `app/` | The audience flow: title, instructions, bell selection, and play screens |
| `shake/` | The shake instrument: motion detection and the effects that respond to it |
| `capture/` | The motion capture harness used to calibrate the shake instrument |
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

## The capture harness

`capture/shake_capture.tscn` records every motion sample the engine sees to one comma-separated
file per run, for calibrating the detector against real hand motion. It is reached by being run
directly as the main scene and is not part of the audience flow. The recorded runs are analysed
off the device; nothing in the harness judges what it records.
