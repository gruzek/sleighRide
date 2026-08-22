# sleighRide

Holiday Sleigh Bells: a phone becomes a sleigh bell an audience shakes along with a live
performance of "Sleigh Ride".

## Repository structure

| Directory | What it holds |
|---|---|
| `v2/` | The audience flow: title, instructions, bell selection, and play screens |
| `shake/` | The shake instrument: motion detection and the effects that respond to it |
| `capture/` | The motion capture harness used to calibrate the shake instrument |
| `snow/` | The snow effect: one scene any screen adds to get snow that falls the way the phone is held |
| `features/` | Feature specifications, implementation plans, and the roadmap |
| `sounds/`, `images/`, `background/`, `foreground/`, `bells/` | Assets and the version 1 build |

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

`snow/` is falling snow that any screen gains by adding one node. `snow.tscn` is a `CanvasLayer`
carrying three `GPUParticles2D` layers, so it draws above whatever the host screen puts on the
default layer and needs nothing from it.

- `snow.gd` is the driver, and the only part of the effect that reads a sensor. It takes the
  device's gravity vector, projects it into the plane of the screen, smooths it, and writes each
  layer's gravity and damping from it. A phone lying flat holds the heading it had and slows to a
  drift rather than spinning on sensor noise.
- `snow_layer.gd` is one depth layer. It owns how heavy its flakes are and how fast they fall;
  the driver owns which way down is and where the flakes come in from. The three layers differ
  only in weight, speed, size, and opacity.
- New flakes are born on a thin band just outside the viewport that orbits as the direction
  changes, so snow always arrives from off screen whichever way the phone is held. Flakes already
  in flight curve onto a new heading, because the direction is carried on gravity rather than on
  a spawn velocity.
- `shaders/snow_sparkle.gdshader` gives every flake its own rhythm from a per-flake seed: a
  brightness that oscillates, and a width that narrows to a paper edge and back.

Two settings in `snow.tscn` are load-bearing and have no visual symptom that points at them.
`local_coords` must stay off, or the live snow sweeps bodily across the screen when the band
swings. `visibility_rect` must stay large, because the node spends its whole life outside the
viewport and at the default the whole system is culled and nothing is drawn.

## The capture harness

`capture/shake_capture.tscn` records every motion sample the engine sees to one comma-separated
file per run, for calibrating the detector against real hand motion. It is reached by being run
directly as the main scene and is not part of the audience flow. The recorded runs are analysed
off the device; nothing in the harness judges what it records.
