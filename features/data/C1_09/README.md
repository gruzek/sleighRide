# Shake capture runs — Measure a Real Shake So the Bells Sound When a Real Bell Would (C1_09)

Sixteen recordings of a hand shaking a device, made on 2026-08-22 with the capture harness in `capture/`. These are the evidence behind every constant in `shake/shake_detector.gd`. They are kept so that a later change of detection technique costs an afternoon of analysis rather than another session of shaking a phone.

Every run was recorded with a recording of "Sleigh Ride" playing, so the shaking rates in them reflect the piece rather than a metronome.

## Directory layout

Runs are grouped by the device that recorded them, because the same motion produces materially different numbers on different hardware — a 460-gram tablet and a 170-gram phone do not stop with the same force. **Add a new device as a new folder**, for example `Android/`, rather than mixing recordings from different hardware in one place. The device model is also written into each file's header, so a file separated from this directory can still be identified.

```
iPad/     iPad13,16 (iPad Air, 5th generation), iOS 18.6.2 — 60 samples per second
iPhone/   iPhone14,2 (iPhone 13 Pro), iOS 26.6.0 — 120 samples per second
```

The iPad runs were exploratory and established the shape of a stroke. **The iPhone runs are the ones the detector's constants come from**, because the iPhone is the target device.

## File format

Each file is one continuous recording. The name is the wall-clock time the run started, so files sort chronologically and no label can be mistyped during capture. A header of comment lines records the conditions, then one row per rendered frame.

Columns: `sample`, `t_ms`, `dt_ms`, `accel_x/y/z`, `grav_x/y/z`, `gyro_x/y/z`, and — in version 2 files only — `hit`, `hit_magnitude`, `hit_intensity`, `hit_level`.

Nothing is smoothed, filtered, or derived on the way to disk. Linear acceleration is `accel` minus `grav`, computed during analysis and never stored. The `hit` columns record what the detector did on that frame, so the algorithm can be diagnosed against the raw signal that produced it; they are additive evidence and do not replace any measurement.

Two format notes that matter when reading these files:

- **`dt_ms` is not a measurement.** Godot on iOS reports the display link's nominal interval, so it reads a constant 16.667 or 8.333 on almost every frame regardless of what the clock actually did. `t_ms` is the only real timing source. This holds even in the files whose header says `delta_smoothing=false`.
- **The header grew during the session.** The earliest files carry `target_frame_rate=60`, which was wrong — the iPhone runs at 120. Later files replace it with `screen_refresh_hz`, `engine_max_fps`, and `delta_smoothing`, read from the engine at run time. A file carrying `target_frame_rate` should be read as version 1 of the format; trust its `achieved_rate_hz` and ignore its target.

## The runs

Vocabulary used below, which is the developer's rather than the specification's:

- **Single stop** — shaking so the jingle lands on the downstroke only, one hard stop per cycle.
- **Double stop** — shaking so the jingle lands on both the downstroke and the upstroke, two stops per cycle at half the stroke rate.
- **Double down** — a single stop pattern alternating heavy and light: heavy, light, heavy, light.

"Events" below are what the detector in `shake/shake_detector.gd` finds in each run at its committed settings, and "peak" is the projected linear acceleration at those events, in metres per second squared.

### iPad — exploratory, 60 samples per second

| File | What it is | Events | Peak min / median / max | Notes |
|---|---|---|---|---|
| `2026-08-22_09-00-44.csv` | First run ever recorded. Unstructured shaking | 22 | 6.9 / 9.5 / 17.4 | Proved the file format and the retrieval path. Its `dt_ms` is a flat constant, which is what first exposed that the column is not a measurement |
| `2026-08-22_09-12-11.csv` | Throwaway, recorded to check whether disabling delta smoothing had any effect | 27 | 6.1 / 10.5 / 18.8 | The only file in the set containing a genuinely dropped frame, at 31.3 ms |
| `2026-08-22_09-12-36.csv` | Single stop | 83 | 7.3 / 18.6 / 35.8 | The run the stroke shape was derived from. Drive and stop separate cleanly: the stop is 1.65 times the amplitude of the drive and half its duration |
| `2026-08-22_09-12-58.csv` | Double stop | 40 | 9.9 / 22.1 / 35.5 | Roughly symmetric lobes at half the stroke rate, which is what distinguishes it from the single-stop run |
| `2026-08-22_09-13-16.csv` | Still — device held in the hand, no deliberate motion | **0** | — | The noise floor. 99th percentile 3.01, absolute maximum 4.90. Every threshold has to clear this |
| `2026-08-22_09-13-30.csv` | Rotation-weighted shaking, a wrist twist | 104 | 6.1 / 23.1 / 47.7 | Highest gyroscope content of the iPad set at 11.21 rad/s, but the linear columns are large too, so it does **not** isolate rotation the way the specification's "rotation only" motion asks for |

### iPhone — the calibration set, 120 samples per second

| File | What it is | Events | Peak min / median / max | Notes |
|---|---|---|---|---|
| `2026-08-22_09-29-05.csv` | Single stop | 69 | 8.2 / 23.9 / 50.2 | First iPhone run. Revealed that the device samples at 120 rather than the 60 the implementation plan assumed |
| `2026-08-22_09-29-19.csv` | Double stop | 40 | 12.8 / 19.3 / 37.1 | Stroke cycle of 530 ms against the single-stop run's 250 ms, both landing jingles about a quarter-second apart |
| `2026-08-22_09-43-15.csv` | Light single stop | 61 | 6.7 / 14.1 / 27.3 | **The decisive run.** Its recovery lobe is what must stay quiet, and it overlaps the light double-stop run's intended jingles on every absolute measure |
| `2026-08-22_09-43-31.csv` | Light double stop | 36 | 9.5 / 14.3 / 18.1 | **The other half of the decisive pair.** Its jingles must sound, and they are smaller than the recovery above that must not |
| `2026-08-22_09-43-45.csv` | Light double down | 64 | 6.6 / 17.6 / 33.3 | Heavy-light alternation visible directly in the event amplitudes |
| `2026-08-22_09-44-04.csv` | Vigorous single stop | 52 | 10.7 / 53.2 / 102.6 | Sets the top of the intensity range. No sensor saturation: the extreme occurs once, and the sensor's ±16 g ceiling is about 157 m/s² |
| `2026-08-22_09-44-16.csv` | Vigorous double stop | 37 | 8.4 / 39.2 / 59.8 | |
| `2026-08-22_09-44-27.csv` | Vigorous double down | 75 | 7.1 / 38.3 / 91.3 | Widest spread within a single run, from 7.1 to 91.3, which is what a heavy-light pattern shaken hard produces |
| `2026-08-22_09-44-40.csv` | Rough shove — a stuttering push with no hard stop | 2 | 10.5 / 12.1 / 13.7 | **Too short to conclude from, at 2.6 seconds.** It is the run that decides whether a stop detector goes silent where a real bell would rattle, and it needs re-recording at ten seconds |
| `2026-08-22_09-44-47.csv` | Still — phone held in the hand, no deliberate motion | **0** | — | The iPhone noise floor. 99th percentile 2.71, maximum 4.33 |

## Recording more runs

The harness is `capture/shake_capture.tscn`. Point `run/main_scene` at it, export to the device, and record; the file lands in the app's Documents folder, reachable through the phone's Files application because the iOS export preset sets `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`.

Four things to hold to, each of which cost a run to learn:

1. **Hold the device still for about a second after pressing start and again before pressing stop.** The button press is itself a motion transient and otherwise appears at both ends of every run as an event no shaking produced.
2. **Note which file is which as you record.** File names carry timestamps only, by design, so a note outside the app is the sole link between a file and what the hand was doing. Then add the run to the table above.
3. **Record on the device you intend to quote.** The same motion reads about 40 percent higher on the iPhone than on the iPad.
4. **Check the header before trusting the run.** `achieved_rate_hz` should sit near the device's refresh rate, and the motion columns should carry varying values rather than zeros. The three sensor calls return a zero vector in the editor and on the simulator by design, so a run recorded anywhere but a real handset is empty.

## A note for the Android runs

The engine converts iOS motion values to the same units Android reports but not to the same sign convention: a device lying flat and face up reads positive on the vertical axis on Android and negative on iOS, because the two platforms report the gravity vector in opposite directions. Linear acceleration is unaffected, since the difference cancels when gravity is subtracted — which is the reason the detector works on that quantity and nothing else.

Nothing in this directory verifies that on real Android hardware. Before trusting Android motion data, record a still run and confirm that the gravity columns behave as expected for the device's resting orientation, then re-check the noise floor and the intensity range against the iPhone figures above. `legacy/bells/native_gravity_controller.gd` is the illustration of what goes wrong when this is assumed rather than checked: its mapping of the gravity vector to screen space is iOS-shaped, and on Android its bells would fall upward.
