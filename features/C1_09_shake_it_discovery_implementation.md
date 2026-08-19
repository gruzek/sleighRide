---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Measuring a Real Shake So the Bells Sound When a Real Bell Would
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: A five-phase route from a guessed shake threshold to a measured one, taking a phone from a silent capture screen to sixteen recorded runs to a written answer the next feature can build from.
LAST UPDATED: August, 19, 2026 08:31
---

# Implementation Plan for Measuring a Real Shake So the Bells Sound When a Real Bell Would

This plan implements the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09). It adds one scene and one script in a new directory outside the audience flow, adds two property-list entries to the existing iOS export preset, records sixteen capture runs on an iPhone, and ends with a written finding naming the detection technique and its constants. It changes no existing scene, no existing script, and nothing in the four screens of the version 2 flow.

## Design decisions carried in from the specification conversation

These were settled during ideation and planning and are implemented rather than re-opened.

- **The sample rate is 60 samples per second and cannot be raised.** This is the one place the specification could not be executed as written, and it is described in full under "The sample rate is fixed" below. Requirement 2 is implemented as recording the rate achieved and proving it was stable, rather than requesting a higher one.
- **No analysis script is committed.** The developer's decision. The captured runs are read and analysed conversationally, and the findings document is the only analysis artefact this feature produces.
- **The captured runs are committed to the repository**, under `features/data/C1_09/`, because they are the evidence the finding rests on and because the specification's future-work section promises they can be refitted later against a technique nobody has proposed yet. Sixteen ten-second runs come to roughly one megabyte.
- **No automated tests are created.** This follows the precedent set by the Fit the Audience Flow to Any Phone Screen feature (C1_07), whose plan recorded the same decision. This repository has no test framework, and introducing one is not in the scope of this feature. The verification burden moves entirely onto the manual steps in §4.
- **The governing documents named in the skill's project instructions do not exist in this repository**, and the shared web component library it references does not apply to a Godot project. This plan follows the conventions already established by the Fit the Audience Flow to Any Phone Screen feature (C1_07).

## The sample rate is fixed

Specification requirement 2 asks the harness to request the highest frame rate the device supports, on the reasoning that a display capable of 120 frames per second would halve the interval between samples. Godot 4.6 does not permit this. In `drivers/apple_embedded/godot_view_apple_embedded.mm`, `godot_commonInit` assigns `self.preferredFrameRate = 60` as a literal, and `startRendering` passes that value straight into `displayLink.preferredFramesPerSecond`. The only related project setting selects between the display link and a timer, and the timer path uses the same hard-coded value. Neither `Engine.max_fps` nor the `CADisableMinimumFrameDurationOnPhone` property-list key can raise it, because the ceiling belongs to the engine rather than to the operating system.

The interval between samples is therefore 16.7 milliseconds, which places roughly eight samples across a typical 130 millisecond stroke, with the deceleration at the stop spanning perhaps two or three of them. This is enough to establish that a stop occurred and marginal for establishing exactly when, which raises the likelihood that the chosen technique has to interpolate the peak between samples rather than take the largest sample as the peak. That determination belongs to the analysis in Phase 5 and is one of the findings requirement 9 asks for.

What requirement 2 becomes in practice is the second half of what it asked for: the harness records the rate it actually achieved, and the per-sample frame delta makes any variation visible sample by sample rather than only in an average. This matters more than it might appear. Because the sample clock is the frame clock, a dropped frame during a vigorous shake is indistinguishable from a slower shake unless the frame delta is recorded alongside every sample. Two consequences follow and are built in rather than left to care: the capture screen carries nothing that animates, and samples are held in memory and written to disk only when the run stops, never during it. Writing a line per frame would introduce file system latency into the very clock being measured.

Should the analysis conclude that 60 samples per second is insufficient, the escalation is a native plugin running `CMMotionManager` on its own handler queue at 100 samples per second, decoupled from the render loop entirely. That is named here as the known route forward and is not part of this plan.

## The capture record

Each run produces one file. The header records the conditions, written at the moment the run stops so that the achieved rate is known and can be recorded alongside the requested one. The sample rows follow, one per rendered frame, in capture order.

```
# holiday_sleigh_bells_shake_capture v1
# recorded_at=2026-08-19T08:31:04
# device_model=iPhone15,2
# os_name=iOS
# os_version=18.5
# engine_version=4.6.stable
# target_frame_rate=60
# sample_count=602
# duration_s=10.033
# achieved_rate_hz=60.00
# longest_frame_ms=17.9
sample,t_ms,dt_ms,accel_x,accel_y,accel_z,grav_x,grav_y,grav_z,gyro_x,gyro_y,gyro_z
0,0.000,16.667,0.31042,-9.60113,-1.84420,0.29981,-9.58840,-1.83002,0.00412,-0.01180,0.00233
```

| Column | Source | Unit |
|---|---|---|
| `sample` | Index from zero within the run | count |
| `t_ms` | Monotonic clock, `Time.get_ticks_usec()`, rebased to the run's first sample | milliseconds |
| `dt_ms` | The frame delta the engine reported for this frame | milliseconds |
| `accel_x`, `accel_y`, `accel_z` | `Input.get_accelerometer()` | metres per second squared |
| `grav_x`, `grav_y`, `grav_z` | `Input.get_gravity()` | metres per second squared |
| `gyro_x`, `gyro_y`, `gyro_z` | `Input.get_gyroscope()` | radians per second |

Both `t_ms` and `dt_ms` are recorded because they answer different questions and their disagreement is itself diagnostic: `t_ms` places a sample absolutely, `dt_ms` is what the engine believed the interval to be, and a divergence between the accumulated deltas and the elapsed monotonic time indicates the engine's timing was not telling the truth about the frame.

Nothing derived is stored. Linear acceleration, jerk, magnitude, and any projection onto a motion axis are all computable from these twelve columns, and computing any of them during capture would embed a choice this feature exists to make. Values are written with five decimal places, which resolves far below the sensor's own noise floor of roughly 0.02 metres per second squared.

## Implementation Steps and Phases

### Phase 1: The capture harness

1. Create the directory `capture/`, outside `v2/` and outside the version 1 build. This is requirement 6 expressed in the file layout: the harness is not part of the audience flow and is not reachable from it, and putting it in its own directory makes that visible rather than a matter of discipline.

2. Create `capture/shake_capture.gd`, a script extending `Control`, holding the whole of the harness. Its responsibilities:

   Sampling happens in `_process(delta)`, never in `_physics_process`. The engine refreshes the motion values once per rendered frame, immediately before the main loop iterates, so `_process` maps one to one onto the available data. A physics callback runs on its own clock and would read the same value more than once or skip one entirely, manufacturing samples that do not correspond to anything measured. The existing prototype `bells/native_gravity_controller.gd` samples in `_physics_process`, and that is the pattern this deliberately does not follow.

   While a run is active, each frame appends one record to an in-memory array: the monotonic timestamp from `Time.get_ticks_usec()`, the frame delta, and the three vectors from `Input.get_accelerometer()`, `Input.get_gravity()`, and `Input.get_gyroscope()`. Nothing is filtered, clamped, smoothed, or skipped, per requirement 1.

   Starting a run clears the array and records the wall-clock time for the file name and the header. Stopping a run computes the achieved rate and the longest frame from the collected samples, formats the header and the rows, and writes the whole file in one operation to `user://`, per the buffering decision above.

   The file name is the run's start time in the form `YYYY-MM-DD_HH-MM-SS.csv`, which sorts chronologically. Hyphens rather than colons in the time portion, because a colon is not safe in a file name on every platform the file may later be copied to. No label, category, or description is collected on the device, per requirement 3.

3. Create `capture/shake_capture.tscn`, a `Control` scene with a plain background and the readout of requirement 5: a single large control that starts a run and stops it, and four labels showing the elapsed time, the number of samples recorded, the achieved rate over the last second, and the current magnitude of linear acceleration computed as the length of `Input.get_accelerometer()` minus `Input.get_gravity()`. A fifth label shows the path of the most recently written file, so that a failed write is visible on the phone rather than discovered later on the desk.

   Nothing on this screen animates, has a texture, or moves. The screen is the sample clock, and a decorative element that costs a millisecond of frame time is a decorative element that corrupts the measurement.

   The readout is a liveness check and not a detector. No threshold is displayed, no candidate technique runs, and no event is indicated, per requirement 5. The current linear acceleration magnitude is shown for one reason only: on a working handset it sits near zero at rest and rises visibly when the phone moves, which distinguishes a live sensor from a dead one at a glance. The same field reads a flat zero in the editor and on the simulator, which is the documented behaviour of these calls off-device and is what makes the harness untestable anywhere but a real handset.

4. Confirm `display/window/energy_saving/keep_screen_on` is left at its default of enabled. A capture run receives no touch input between the start press and the stop press, which is precisely the condition under which a phone dims and locks its screen. No project setting is added; this step is a check that none needs to be.

### Phase 2: Desktop shakedown

5. Run the capture scene in the editor and record a short run. Every motion column will read zero, because `Input.get_accelerometer()`, `Input.get_gravity()`, and `Input.get_gyroscope()` all return a zero vector off-device by design. This is not a failure and no substitute value is generated for it, per the no-fallbacks rule.

   What this step does verify is everything except the sensor: that the file is created, that the header carries a plausible device, operating system, engine version, sample count, duration, achieved rate, and longest frame, that the row count matches the sample count in the header, that `t_ms` increases monotonically, that the accumulated `dt_ms` agrees with the elapsed `t_ms`, and that the file opens cleanly in a spreadsheet. Getting the file format wrong is the one mistake that would invalidate an entire capture session, and it is far cheaper to find here than on the handset.

### Phase 3: Device build and file retrieval

6. Add the two property-list entries to `application/additional_plist_content` in the iOS preset of `export_presets.cfg`, which currently holds an empty string:

   ```xml
   <key>UIFileSharingEnabled</key>
   <true/>
   <key>LSSupportsOpeningDocumentsInPlace</key>
   <true/>
   ```

   This is requirement 8. On iOS, Godot's `user://` resolves to the application's Documents directory, confirmed in `drivers/apple_embedded/os_apple_embedded.mm`, where `get_user_data_dir` returns the first path from `NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)`. These two keys are what make that directory visible in the phone's Files application, so the captured runs can be copied off without attaching the phone to the development machine.

7. Temporarily point `run/main_scene` in `project.godot` at `capture/shake_capture.tscn`, export an iOS build, and install it on the handset. **Restoring `run/main_scene` to the version 2 title screen afterwards is a completion criterion**, listed in §7, because leaving it pointed at the capture harness would ship the measurement tool as the audience experience. This swap is the mechanism because the phone has to be untethered while it is being shaken, which rules out running the scene from the editor over a debug connection.

8. Confirm the retrieval path before recording anything worth keeping: record one throwaway run on the handset, open the Files application, find the application's folder, and copy the file to the development machine. A capture session that discovers at the end that the files cannot be reached is a capture session performed twice.

### Phase 4: Perform the runs

9. Record the eight motions of requirement 7, twice each, for sixteen runs, each held for approximately ten seconds. In catalogue order: still, gentle, normal, vigorous, in tempo, single stops, jerky drive, and rotation only. The two repetitions of a motion are recorded in the same session, so that variation between them reflects the hand rather than the day.

   Two procedural points that the data cannot recover from if they are ignored. **Hold the phone still for about a second after pressing start, and again before pressing stop**, because the button press is itself a motion transient and would otherwise appear at the head and tail of every run as an event no shaking produced. And **perform the in-tempo run against an actual metronome at 100 to 105 beats per minute**, one stroke per eighth note, rather than an estimate, because that run's value lies entirely in its rate being known independently of what the analysis measures.

10. Record which file corresponds to which motion, outside the application, as the runs are performed. The file names carry timestamps only, by design, so this note is the sole link between a file and what the hand was doing.

11. Copy the sixteen files into `features/data/C1_09/` in the repository.

### Phase 5: Analysis and the finding

12. Analyse the runs and compare candidate detection techniques against them, per requirement 9. The techniques compared, at minimum:

    | Technique | Signal it works on | What it fires on |
    |---|---|---|
    | Jerk threshold | Rate of change of linear acceleration | Any change fast enough to throw the bells, reversal or not |
    | Deceleration peak | Linear acceleration projected onto the dominant motion axis | The negative-going peak that follows a drive |
    | Axis reversal | Linear acceleration projected onto the dominant motion axis | The sign change at the end of a stroke |
    | Magnitude peak with refractory | Magnitude of linear acceleration | The largest sample in a window, then a forced gap |

    Each is evaluated on the magnitude of linear acceleration and on its projection onto a dominant motion axis estimated from recent samples, and the gyroscope is evaluated as both an additional and an alternative signal. Linear acceleration throughout is `accel` minus `grav` from the captured columns, which is the one quantity whose sign convention is the same on both target platforms.

13. Judge each technique against what the runs are known to contain. A technique that fails any of these is eliminated regardless of how it performs elsewhere:

    | Run | What a correct technique must do |
    |---|---|
    | Still | Fire never |
    | In tempo | Produce a steady train at approximately 3.5 events per second, matching the metronome |
    | Single stops | Produce exactly one event per stroke, with nothing between strokes |
    | Jerky drive | Produce events, since a real bell sounds here and silence would be wrong |
    | Gentle and vigorous | Produce events across both, with a separable intensity range between them |

14. Fix the intensity scale. The candidate measures compared are the peak magnitude of linear acceleration within the stroke, the root mean square energy over a short window, the peak jerk, and the change in speed across the stop obtained by integrating linear acceleration through it. The chosen measure is reported with the range it actually spans between the gentle and vigorous runs, and with a mapping from that range onto intensity levels spaced perceptually rather than evenly in raw acceleration.

15. Settle the two remaining findings requirement 9 asks for: whether 60 samples per second locates the stop adequately or whether the peak must be interpolated between samples, and what refractory period, if any, prevents one stop from registering twice.

16. Write `features/C1_09_shake_it_discovery_findings.md`, carrying the chosen technique and why the others were rejected, every constant with its measured value, the intensity measure with its observed range and its mapping onto levels, the refractory period, the sample-rate conclusion, and the conditions the runs were recorded under. This is requirement 10 and the deliverable the feature exists to produce. The number of intensity levels it names determines how many recordings each bell needs at each level, which is information the audio work being produced separately as task `C1_T04` depends on.

## Test Cases

**No automated tests are created or changed by this plan**, following the precedent recorded in the plan for the Fit the Audience Flow to Any Phone Screen feature (C1_07). This repository has no test framework, and introducing one is outside this feature's scope. There is accordingly no unit-test table; the run acceptance table in the final section of this plan is the closest equivalent, and it is a verification artefact rather than a test suite.

The consequence worth recording: the harness cannot be exercised anywhere except a physical handset. The editor, the desktop build, and the iOS simulator all return a zero vector from the three motion calls, which is documented behaviour and not a fault. Phase 2 therefore verifies everything about the file that does not require a sensor, and the sensor itself is verified only in Phase 3 and only by eye, through the liveness readout of requirement 5. That division is deliberate and is the reason Phase 2 exists as a separate step rather than being folded into the device work.

## README and Documentation Updates

No README exists in this repository and none is created by this plan. Two pieces of knowledge introduced here are not evident from reading the code, and both are recorded as comment blocks at the top of `capture/shake_capture.gd`, which is where someone changing this will be looking: that sampling must happen in `_process` and why `_physics_process` would fabricate data, and that the sample clock is the frame clock, so nothing on the capture screen may animate and nothing may be written to disk during a run.

The findings document written in step 16 is itself the documentation this feature produces, and it is the artefact the Shake-to-Jingle interaction (C1_02) reads.

## Manual Verification Steps

Because there are no automated tests, these steps are the verification.

**In the editor, before the device.** Run the capture scene, record a run of roughly ten seconds, stop it, and open the written file. Confirm the header carries every field listed in "The capture record" and that none is blank. Confirm the row count equals the header's `sample_count`. Confirm `t_ms` increases monotonically from zero. Confirm the sum of the `dt_ms` column agrees with the final `t_ms` to within a few milliseconds. Confirm all nine motion columns read zero, which is correct off-device. Confirm the on-screen readout shows a rising sample count and elapsed time while the run is active, and that the file path label updates when the run stops.

**On the handset, before the real runs.** Install the capture build and confirm the liveness readout responds: the linear acceleration magnitude should sit near zero when the phone is held still and rise visibly when it is moved. A flat zero here means the sensor is not reaching the engine, and no run recorded in that state is worth keeping. Confirm the screen does not dim or lock during a ten-second run with no touch input. Confirm the achieved rate reads approximately 60 and holds there during a vigorous shake rather than sagging.

**Retrieval, before the real runs.** Record a throwaway run, open the Files application on the phone, locate the application's folder, and copy the file off. Open it and confirm it is the same format the editor produced, now with non-zero motion columns.

**After the runs.** Confirm sixteen files are present, that each covers approximately ten seconds, and that the note linking files to motions is complete and unambiguous. Spot-check the still run: its linear acceleration magnitude should stay below roughly 0.8 metres per second squared throughout, and a still run that does not is a still run that was not still. Spot-check the vigorous run for sensor saturation, visible as a column pinning at a repeated extreme value rather than varying, since a saturated run cannot support an intensity measurement at its top end.

**Before finishing.** Confirm `run/main_scene` in `project.godot` points at the version 2 title screen again, and that the four screens of the audience flow run exactly as they did before this work.

## Coding Standards Compliance Checklist

The application coding standards document named in the skill's project instructions does not exist in this repository. The following are the conventions this codebase actually demonstrates, and this plan conforms to each.

- Tab indentation in GDScript, matching `start_overlay.gd`, `v2/main.gd`, `v2/instructions.gd`, and `v2/sprite_position.gd`.
- A one-line comment at the top of each script naming the file and its role, matching the existing scripts.
- Static typing on declarations and return types, including `-> void` on functions that return nothing, as the existing scripts do.
- Signals connected in `_ready()` rather than in the scene file, matching `v2/main.gd` and `v2/instrument_select.gd`. Connecting in both places raises a duplicate-connection error at runtime.
- Scene and script files named in lower snake case, matching `instrument_select.tscn` and `instrument_select.gd`.
- No fallbacks. The motion calls return a zero vector off-device and that zero is recorded as measured, with no substituted value, no simulated shaking, and no synthetic data path for desktop testing.

## File-Level Compliance Review

| File | Change |
|---|---|
| `capture/shake_capture.gd` | New. The capture harness, holding sampling, buffering, and file writing |
| `capture/shake_capture.tscn` | New. The capture screen: one control and five labels, nothing animated |
| `export_presets.cfg` | Two property-list entries added to `application/additional_plist_content` in the iOS preset, which is currently an empty string |
| `project.godot` | `run/main_scene` temporarily repointed for the capture build, and restored afterwards. No permanent change |
| `features/data/C1_09/` | New. The sixteen captured runs |
| `features/C1_09_shake_it_discovery_findings.md` | New. The finding, per requirement 10 |

Nothing else is touched. The four screens of the version 2 flow, their scripts, the shared placement scripts, and the entire version 1 build under `main.tscn`, `start_overlay.gd`, `bells/`, `foreground/`, and `background/` are all outside this plan. In particular `bells/native_gravity_controller.gd` is left exactly as it is: it is referenced twice in this plan as a pattern not to follow, and correcting it belongs to the Shake-to-Jingle interaction (C1_02), not here.

## Metric Consistency Audit

Four measurements appear in this feature and each is defined in exactly one place, so that a number in the findings document cannot disagree with a number in a captured file.

| Measurement | Single definition | Where it is computed |
|---|---|---|
| Linear acceleration | `Input.get_accelerometer()` minus `Input.get_gravity()`, in metres per second squared | Never at capture time; only during analysis, from the recorded columns. The on-screen liveness readout displays its magnitude but does not record it |
| Achieved rate | Sample count divided by elapsed monotonic time across the run, in samples per second | Once, at the moment a run stops, written into the header |
| Longest frame | The maximum `dt_ms` across the run, in milliseconds | Once, at the moment a run stops, written into the header |
| Intensity | Chosen in step 14 from four candidates and reported with its observed range | Only in the findings document |

The unit of every recorded column is fixed by the engine and stated in "The capture record" above. No column is rescaled, normalized, or converted at any point between the sensor and the file, so a value in a captured run is directly comparable to a value in any other captured run and to the ranges quoted in the specification's research.

## Completion Criteria

1. `capture/shake_capture.gd` and `capture/shake_capture.tscn` exist, and the capture screen is reachable only by being run directly, never from the four screens of the audience flow.
2. A run recorded in the editor produces a file whose header is complete, whose row count matches its header, and whose timing columns are self-consistent.
3. The iOS export preset carries both property-list entries, and a run recorded on the handset is retrievable through the phone's Files application without a development machine.
4. The liveness readout responds to real motion on the handset, and the achieved rate holds at approximately 60 samples per second through a vigorous shake.
5. Sixteen runs exist in `features/data/C1_09/`, two for each of the eight named motions, each approximately ten seconds, each linked to its motion by the note taken during the session.
6. Every check in the §4 verification steps passes, including the still-run and vigorous-run spot checks.
7. `features/C1_09_shake_it_discovery_findings.md` exists and states the chosen technique, the rejected alternatives with reasons, every constant with its measured value, the intensity measure with its range and its mapping onto levels, the refractory period, and the sample-rate conclusion.
8. `run/main_scene` in `project.godot` points at the version 2 title screen, and the four screens of the audience flow behave exactly as they did before this work.

## Token and Design Considerations

This feature builds no skill, so there is no `input_limits` value, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed; this feature adds no capability the tutor covers.

## Run Acceptance Table

This replaces the unit-test table, for the reason given in §2. It is the check applied to each captured run before it is accepted into `features/data/C1_09/`, and a run that fails its row is re-recorded rather than analysed. The expected values are what the run must exhibit for the analysis in Phase 5 to be able to use it.

| Run | Recorded input | Expected result |
|---|---|---|
| Still, both takes | Phone held in the hand, no deliberate motion, ten seconds | Magnitude of linear acceleration stays below approximately 0.8 m/s² for the whole run. This run defines the noise floor, so any threshold chosen in Phase 5 must sit above what this run contains |
| Gentle, both takes | Soft wrist jingle, ten seconds | Clear periodic structure; peak linear acceleration in the region of 5 to 15 m/s². No column saturates |
| Normal, both takes | Ordinary shaking, ten seconds | Peak linear acceleration in the region of 15 to 30 m/s², separable from the gentle run's range |
| Vigorous, both takes | As hard as anyone would reasonably shake, ten seconds | Peak linear acceleration of 30 m/s² or above. No column pins at a repeated extreme, which would indicate sensor saturation and make the top of the intensity range unmeasurable |
| In tempo, both takes | Metronome at 100 to 105 beats per minute, one stroke per eighth note, ten seconds | Approximately 35 strokes, giving a rate near 3.5 per second that is known independently of anything the analysis measures. This is the run that validates a technique's timing |
| Single stops, both takes | Isolated deliberate strokes with a hard stop and a clear pause between, ten seconds | Individual stroke shapes fully separated, with the drive and the stop visible as distinct features within one stroke. This is the run the technique's shape is derived from |
| Jerky drive, both takes | Rough stuttering drive with no hard stop at the end, ten seconds | Substantial high-frequency content during the drive with no reversal at the end, so that a reversal-based technique produces nothing here and a jerk-based one does. This run is what discriminates between those two families |
| Rotation only, both takes | Wrist twist with as little travel as the hand can manage, ten seconds | Gyroscope columns carry clear periodic structure while the linear acceleration columns stay comparatively small, establishing whether rotation predicts a stop that translation misses |
| Every run | Any of the above | Header complete with all eleven fields; row count equal to `sample_count`; `t_ms` monotonically increasing from zero; accumulated `dt_ms` agreeing with final `t_ms`; achieved rate approximately 60; longest frame not materially above 17 ms, since a long frame during a shake is the one artefact that cannot be distinguished from a slower shake after the fact |
