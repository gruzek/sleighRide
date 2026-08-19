---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Measure a Real Shake So the Bells Sound When a Real Bell Would
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Replaces a guessed shake threshold with measured hand motion, so the moment an audience member feels the bells stop is the moment they hear them ring.
LAST UPDATED: August, 19, 2026 08:12
---

# Measure a Real Shake So the Bells Sound When a Real Bell Would

## Summary

The Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) is a calibration exercise. It builds a capture harness that records every motion sample the engine sees while a person deliberately shakes the phone, writes one timestamped file per run, and gets those files off the device. Eight named motions are performed, from holding the phone still to shaking it in the tempo of "Sleigh Ride." The recorded runs are then analysed off the device to choose which detection technique locates the moment a real sleigh bell would sound, and to fix the numeric constants that technique needs. The feature ends with that answer written down. It plays no sound, runs no detection on the phone, and changes nothing in the audience flow.

## Background

The Shake-to-Jingle interaction (C1_02) is on the MVP1 roadmap and is the original magical moment of this app, but nothing in the repository establishes when a shake should sound. The existing prototype, `bells/native_gravity_controller.gd`, converts motion into a continuous force on loose physics bodies and sounds bells on collision, with every constant in it guessed: a shake gain of 4000, a deadzone of 0, a maximum impulse of 400, a smoothing factor of 0.5. Those numbers were tuned by feel against a tumbling-bells simulation that the Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05) has since retired in favour of a single centred instrument. There is no collision left to sound a bell, and therefore no answer at all to the question of when to play one.

The interaction being built is not a gesture but an instrument. A jingle bell is a shell with loose bells inside it; the bells only strike the shell when the shell abruptly changes velocity. During the drive portion of a stroke the bells travel with the shell and are quiet. The sound belongs to the stop. This rules out the whole family of published shake detectors, which answer a different question: Square's Seismic library, the most widely copied of them, declares a shake when three quarters of the samples in a half-second window exceed roughly 1.3 times the force of gravity, then clears its queue and refuses to fire again. That is a correct design for "the user shook their phone to undo something" and a wrong one here, because it emits a debounced boolean about four times a second, carries no intensity, and fires nowhere near the stop.

What the correct technique is cannot be settled from the literature, because the shape of a hand's stroke is not a documented constant. Three questions in particular have no answer without measurement. The stop and the drive are separate peaks in the same signal, separated by roughly the length of the drive, so a technique aimed at the wrong one fires consistently early. Both ends of a stroke can be hard stops, so a technique cannot assume one sound per cycle. And a drive rough enough to rattle the bells sounds without any reversal at all, which means the criterion is more likely a threshold on jerk than on reversal, and the value of that threshold is exactly the kind of number that has to come from data.

The engine's own behaviour also needs measuring rather than assuming. Godot reads the motion sensors once per rendered frame on both target platforms, so the sample rate is the frame rate: about one sample every 16.7 milliseconds at 60 frames per second, or every 8.3 milliseconds on a display that runs at 120. The deceleration at a stop is the sharpest feature in the entire signal and the one the technique has to locate precisely, so whether that rate is sufficient is itself a finding this feature has to produce.

Three capabilities are deliberately deferred from this feature and are detailed under Future work: the sound response itself, verification of the platform difference on Android hardware, and a continuous stochastic texture layer.

## Value Delivered

- **The interaction stops being a guess.** Every constant governing shake today was invented, and the simulation they were invented for no longer exists. This replaces them with numbers measured from a hand holding a phone.
- **The moment lands where the hand expects it.** Sounding a bell at the drive rather than at the stop is the specific error that makes an app feel fake, and it is invisible in code review and obvious in a concert hall. Measuring the two separately is the only way to tell them apart.
- **Shake-to-Jingle becomes buildable.** The Shake-to-Jingle interaction (C1_02) currently has no specified trigger and no intensity scale. This hands it both, so that work becomes implementation rather than further discovery.
- **The data outlives this decision.** Recorded runs can be replayed against a technique nobody has thought of yet, so a later change of approach costs an afternoon of analysis rather than another round of shaking a phone.

## Terms

- **Stroke.** One complete out-and-back motion of the hand, made of a recovery, a drive, and a stop.
- **Recovery.** The slower portion of a stroke that returns the hand to where the next drive begins.
- **Drive.** The portion of a stroke where the hand accelerates the phone in the direction of travel. The loose bells travel with the shell and are quiet.
- **Stop.** The abrupt end of a drive, where the shell changes velocity fast enough to throw the loose bells against it. This is what sounds a real bell, and it is the event this feature exists to locate.
- **Proper acceleration.** What an accelerometer physically measures, which includes the constant contribution of gravity. A phone lying still on a table reads about 9.81 metres per second squared, not zero.
- **Linear acceleration.** Proper acceleration with the gravity contribution removed, so a phone lying still reads approximately zero. On both target platforms this is `Input.get_accelerometer()` minus `Input.get_gravity()`.
- **Jerk.** The rate of change of acceleration. A stop is a large jerk regardless of which direction the phone was travelling.
- **Dominant motion axis.** The direction the hand is currently moving along, estimated from recent samples rather than fixed in advance, because the direction a person chooses to shake in is arbitrary.
- **Refractory period.** A minimum enforced gap after a detection during which a technique refuses to fire again.
- **Capture run.** One continuous recording of one named, deliberately-performed motion, producing exactly one file.
- **Frame delta.** The elapsed time the engine reports for the frame a sample was taken on, which is the interval between that sample and the one before it.

## Requirements Summary

- **1. Record every motion sample the engine sees, unaltered.** The accelerometer, gravity, and gyroscope vectors captured each frame with their timing, with nothing smoothed, decimated, or derived on the way to the file.
- **2. Sample as fast as the device will allow, and record what was actually achieved.** The harness asks for the highest frame rate available and writes down what it got, so the sufficiency of the sample rate becomes a measurement rather than an assumption.
- **3. Write one timestamped file for each run.** One capture run produces exactly one file, named by the moment it was recorded.
- **4. Make each file interpretable on its own.** A header recording the device, the operating system, and the capture conditions, so a file read months later needs no outside context.
- **5. Show enough on screen to know the capture is working.** A start and stop control and a small readout confirming that samples are arriving and the sensor is alive.
- **6. Keep the harness out of the audience flow.** The capture screen is its own scene used as the main scene of a capture build, and is not reachable from the four-screen experience.
- **7. Perform the eight named motions.** The catalogue of deliberately-performed runs the analysis is done against.
- **8. Get the files off the phone.** The recorded runs are retrievable from the device without a development machine in the loop.
- **9. Choose the detection technique from the recorded data.** Candidate techniques are fitted to the runs off the device and judged against what the runs were known to contain.
- **10. Write the answer down where the next feature can build from it.** The chosen technique, its constants, and the intensity scale, recorded as the finding this feature exists to produce.

## Requirements

### 1. Record every motion sample the engine sees, unaltered

On each rendered frame the harness records the accelerometer vector, the gravity vector, and the gyroscope vector, together with a monotonic timestamp and the frame delta for that frame. These are `Input.get_accelerometer()`, `Input.get_gravity()`, and `Input.get_gyroscope()`, written as they are returned.

Nothing is smoothed, averaged, decimated, thresholded, or clamped before it reaches the file, and no derived quantity is stored in place of a measured one. Linear acceleration, jerk, magnitude, and any projection onto a motion axis are all computable from what is recorded, and are computed during analysis rather than during capture. The reason is that this feature is choosing between techniques that disagree about which part of the signal matters, and a capture that has already made that choice cannot be used to test it. A recording that is smoothed on the way to disk cannot be un-smoothed afterwards, and the stop is precisely the feature that smoothing destroys.

The gyroscope is recorded even though no technique under consideration currently uses it. A wrist flick pivots the phone as much as it moves it, and angular motion throws the loose bells just as translation does, so rotation may predict a stop better than translation. That possibility can only be examined if the column exists, and it costs one additional vector per sample to keep.

### 2. Sample as fast as the device will allow, and record what was actually achieved

Because the engine reads the motion sensors once per rendered frame, the sample rate is the frame rate. The harness therefore requests the highest frame rate the device supports rather than accepting a default, which on a display capable of 120 frames per second halves the interval between samples across a stroke.

Requesting a rate does not guarantee it. The harness records both the rate it asked for and the rate it actually achieved, and the per-sample frame delta required by requirement 1 makes any variation visible sample by sample rather than only in an average. This is what turns the adequacy of the sample rate into a finding: if the deceleration at a stop is spanned by too few samples to locate reliably, the data will show it, and requirement 9 can conclude that the technique must interpolate the peak between samples rather than take the largest sample as the peak.

### 3. Write one timestamped file for each run

Each capture run produces exactly one file, named from the date and time the run was recorded, in a form that sorts chronologically. No label, category, or description is entered on the device, and the harness offers no list of motions to choose from. The developer records which file corresponds to which motion outside the app.

This is deliberate. The alternative, a picker on the capture screen, adds an interface to a tool whose entire job is to start and stop, and it introduces a way for a run to be mislabelled during capture, which is unrecoverable. A timestamp cannot be wrong.

### 4. Make each file interpretable on its own

Each file opens with a header recording the device model, the operating system and its version, the frame rate requested and the frame rate achieved, the engine version, and the time the run began. The sample rows follow, one per frame, in the order they were captured, in a comma-separated form that opens directly in a spreadsheet or an analysis script.

The header exists because these files will be read after the memory of the session that produced them has gone, and because the analysis in requirement 9 has to be able to distinguish a difference caused by the motion from a difference caused by the device or the frame rate it ran at. A file that does not say what recorded it cannot support that distinction.

### 5. Show enough on screen to know the capture is working

The capture screen carries a control that starts a run and a control that stops it, and while a run is in progress it displays the elapsed time, the number of samples recorded so far, the achieved sample rate, and the current magnitude of linear acceleration.

The readout is a liveness check and nothing more. Its purpose is to make a dead sensor, a stalled frame rate, or a run that was never actually started visible while the phone is still in hand, rather than after the files have been retrieved. It is explicitly not a detector: the harness runs no candidate detection technique, displays no threshold, and indicates no event. All such judgement happens off the device under requirement 9, so that a technique can be revised and re-tested against the same recordings without shaking the phone again.

### 6. Keep the harness out of the audience flow

The capture screen is its own scene, and a capture build is produced by making that scene the main scene. It is not reachable from the title screen, the instructions screen, the bell selection screen, or the play screen, and none of those screens is modified by this feature.

The audience flow is the artefact shown to the sponsor, and a measurement tool that can be reached from it is a measurement tool that can be reached during a demonstration. Keeping the two separate costs nothing, because the harness needs none of the flow and the flow needs none of the harness.

### 7. Perform the eight named motions

The recorded runs are these eight motions, each held for approximately ten seconds and each performed more than once so that variation between runs of the same motion is visible:

- **Still.** The phone held in the hand without deliberate motion. This establishes the noise floor, and therefore the smallest value any threshold can meaningfully take.
- **Gentle.** A soft wrist jingle, as though playing quietly.
- **Normal.** Ordinary shaking, as an audience member would do without being asked for anything in particular.
- **Vigorous.** As hard as anyone can reasonably be expected to shake, which is also the case most likely to saturate the sensor.
- **In tempo.** Shaking in the tempo of "Sleigh Ride", roughly 100 to 105 beats per minute with one stroke per eighth note, or about three and a half strokes per second. This is the case that matters most, because it is the concert.
- **Single stops.** Deliberate, isolated strokes with a clear hard stop and a pause between them, so that one complete stroke can be seen with nothing overlapping it. This is the run that shows the shape the technique is looking for.
- **Jerky drive.** A rough, stuttering drive with no hard stop at the end, which is the case where a real bell sounds without any reversal to detect.
- **Rotation only.** A wrist twist with as little travel as the hand can manage, to reveal what the gyroscope captures that the accelerometer does not.

### 8. Get the files off the phone

The recorded runs are retrievable from the device by the developer without attaching it to a development machine, by exposing the harness's output folder so that the files appear among the phone's documents and can be copied or transferred from there.

The alternative, downloading the application container through the development environment after each session, works but scales badly against a catalogue of eight motions each performed more than once, and it puts a desk between the shaking and the analysis. This requirement covers the capture build only; nothing about the audience flow's packaging changes.

### 9. Choose the detection technique from the recorded data

The recorded runs are analysed off the device, and candidate techniques are fitted to them and compared. At minimum the comparison covers a threshold on jerk, detection of the deceleration peak following a drive, and detection of a reversal in the dominant motion axis, evaluated both on the magnitude of linear acceleration and on its projection onto an estimated motion axis, and with the gyroscope considered as an additional or alternative signal.

Each candidate is judged against what the runs are known to contain rather than against ground truth from a real instrument, since no real sleigh bells are available for recording. The named motions of requirement 7 are what makes that judgement possible: a technique must be silent throughout the still run, must produce a steady train at about three and a half events per second through the in-tempo run, must produce one clean event per stroke in the single-stops run, and must produce something in the jerky-drive run rather than nothing. A technique that fails one of those is eliminated regardless of how it looks elsewhere.

The analysis also fixes the intensity scale, since a detected event has to carry how hard it was as well as when it happened. The candidate measures compared are the peak magnitude of linear acceleration within the stroke, the root mean square energy over a short window, the peak jerk, and the change in speed across the stop obtained by integrating linear acceleration through it. The chosen measure is accompanied by the range it actually spans between the gentle and vigorous runs, and by a mapping from that range onto intensity levels, expressed so that the levels are perceptually spaced rather than evenly spaced in raw acceleration.

Two further findings come out of the same analysis: whether the sample rate is sufficient to locate a stop or whether the peak has to be interpolated between samples, and what refractory period, if any, is needed to stop one stop from registering twice.

### 10. Write the answer down where the next feature can build from it

The outcome of requirement 9 is recorded in a written finding placed alongside this specification: which technique was chosen and why the others were rejected, every constant it needs with the value measured for it, the intensity measure with its observed range and its mapping onto intensity levels, the refractory period, the sample-rate conclusion, and the conditions the runs were recorded under.

This is the deliverable the feature exists to produce. The Shake-to-Jingle interaction (C1_02) implements from it directly, and the number of intensity levels it names is what determines how many recordings each bell needs at each level, which is information the audio work depends on.

## Future work

**The sound response itself.** This feature detects nothing on the phone and plays nothing. Sounding a bell at each detected stop, choosing among several recordings at the matched intensity so that repeated strokes do not sound identical, and animating the instrument in response all belong to the Shake-to-Jingle interaction (C1_02), which implements the finding produced by requirement 10.

**Verifying the platform difference on Android hardware.** The engine converts the iOS motion values to the same units Android reports, but not to the same sign convention: a phone lying flat and face up reads a positive value on the vertical axis on Android and a negative one on iOS, because the two platforms report the gravity vector in opposite directions. Linear acceleration is unaffected, since the difference cancels when gravity is subtracted, which is the reason requirement 9 confines every candidate technique to that quantity. The runs in this feature are recorded on an iPhone only, so nothing here verifies the behaviour on Android, and the first Android build needs a check before the motion data from it is trusted. The existing prototype's `bells/native_gravity_controller.gd` is an illustration of what goes wrong: its mapping of the gravity vector to screen space is iOS-shaped, and on Android its bells would fall upward.

**A continuous stochastic texture layer.** A different approach to the same instrument drives a stochastic model of many colliding bells continuously from shake energy, so that gentle motion yields sparse quiet jingles and hard motion yields dense loud ones with no threshold anywhere. It is the approach behind the physically informed stochastic models built for exactly this family of instrument, and it would sound more like a real box of loose bells than any number of discrete samples. It is set aside as disproportionate to the value here, and this feature's recorded runs would support fitting it later without new capture, should it ever be wanted.
