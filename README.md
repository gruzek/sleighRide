# sleighRide

Holiday Sleigh Bells: a phone becomes a sleigh bell an audience shakes along with a live
performance of "Sleigh Ride".

## Repository structure

| Directory | What it holds |
|---|---|
| `v2/` | The audience flow: title, instructions, bell selection, and play screens |
| `shake/` | The shake instrument: motion detection and the effects that respond to it |
| `capture/` | The motion capture harness used to calibrate the shake instrument |
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

## The capture harness

`capture/shake_capture.tscn` records every motion sample the engine sees to one comma-separated
file per run, for calibrating the detector against real hand motion. It is reached by being run
directly as the main scene and is not part of the audience flow. The recorded runs are analysed
off the device; nothing in the harness judges what it records.
