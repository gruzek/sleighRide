---
DOCUMENT TYPE: Holiday Sleigh Bells Finding
DOCUMENT TITLE: How to Tell When a Sleigh Bell Would Sound, and How Hard
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 1.0
AUTHOR: George Ruzek
VALUE STATEMENT: Replaces every guessed constant in the shake interaction with a number measured from a hand holding a phone, so the bells ring where the hand expects them to.
LAST UPDATED: August, 22, 2026 11:42
---

# How to Tell When a Sleigh Bell Would Sound, and How Hard

This is the finding produced by the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09), and it is that feature's reason for existing. It states which detection technique was chosen, why each alternative was rejected, every constant the chosen technique needs with the value measured for it, the intensity measure with its observed range and its mapping onto levels, and the conditions the measurements were made under. The Shake-to-Jingle interaction (C1_02) and the Give Each Chosen Bell Its Own Voice and Close the Audience Flow feature (C1_10) implement directly from this document.

Every number here comes from the sixteen runs committed under `features/data/C1_09/`, which are described in that directory's own README. Where a number is quoted, the run it came from is named, so any claim in this document can be checked against the data rather than taken on trust.

## Conditions the measurements were made under

| | |
|---|---|
| Device the constants come from | iPhone14,2 — iPhone 13 Pro — running iOS 26.6.0 |
| Engine | Godot 4.6.stable |
| Sample rate achieved | 119.7 to 120.5 samples per second across ten runs |
| Quantity measured | Linear acceleration: `Input.get_accelerometer()` minus `Input.get_gravity()`, in metres per second squared |
| Music playing | A recording of "Sleigh Ride" throughout, so shaking rates reflect the piece |
| Runs | Ten on the iPhone, six exploratory on an iPad13,16 |

The iPad runs established the shape of a stroke and are retained, but no constant below is taken from them. The same motion reads roughly 40 percent higher on the iPhone than on the iPad, because a 170-gram phone stops harder than a 460-gram tablet.

## The chosen technique

**Detect every local extremum of linear acceleration projected onto a rolling estimate of the dominant motion axis, fire at the peak, and carry the peak's magnitude as intensity.**

Stated as the runtime performs it, once per rendered frame:

1. Compute linear acceleration as accelerometer minus gravity.
2. Update a rolling covariance estimate of that vector, but only while its magnitude exceeds a motion floor, and take one power-iteration step toward the dominant eigenvector. That eigenvector is the motion axis.
3. Project linear acceleration onto the axis, giving one signed number.
4. While armed, track the largest absolute value the projection reaches in the current direction.
5. Fire when the projection falls a set fraction below that tracked peak, or reverses direction. The event carries the tracked peak as its magnitude.
6. Re-arm when the projection falls back near zero **or** when it changes direction.

### The constants

| Constant | Value | Where it came from |
|---|---|---|
| Fire threshold | **6.0 m/s²** | Above the still run's largest sample of 4.33, below the smallest real jingle at 6.6 |
| Release fraction | **0.4** | The projection must fall under 2.4 m/s² to re-arm by the ordinary path |
| Peak drop fraction | **0.85** | Fire once the projection has fallen 15 percent below the tracked peak |
| Intensity floor | **6.0 m/s²** | Same as the fire threshold |
| Intensity ceiling | **102.6 m/s²** | The largest event in any run, from the vigorous single-stop run |
| Intensity levels | **5** | See the intensity section below |
| Axis time constant | **0.5 s** | Insensitive: 0.15 and 0.5 give the same events on every run |
| Axis motion floor | **1.0 m/s²** | Below this a sample does not influence the axis, so a device at rest cannot let its own noise define which way the hand is travelling |

### Why each part of it is there

**The projection onto a motion axis, rather than the magnitude.** Magnitude is the obvious simplification and it fails. On the vigorous runs the magnitude never falls back between one end of a stroke and the next, so consecutive stops merge into one long event: a magnitude-based detector found **3 events where the projection found 52** in the vigorous single-stop run, and 4 where the projection found 37 in the vigorous double-stop run. The two ends of a stroke have opposite sign along the axis, which is exactly what separates them.

**Firing at the peak's release rather than at the first turnover.** A vigorous stroke is noisy while accelerating, and the first sample that dips is usually noise partway up rather than the peak. Firing there reported a peak of about 13 m/s² where the true one was 53 — every vigorous stop misread as a light one. Tracking the running peak and firing when the signal falls 15 percent below it fixes this; any drop fraction between 0.5 and 0.95 behaves identically on the recorded runs, so the value matters only in that it must not be 1.0.

**Re-arming on a change of direction as well as on falling near zero.** This is what makes hard shaking work. On the vigorous runs the projection never returns to the release level between one stop and the next, so a gate that waited only for that would sleep through most of a stroke: 20 events found where there were 52. Consecutive stops have opposite sign, so a sign change is the natural second way to re-arm.

**A gate rather than a refractory period.** The tightest gap between two real events measured across all runs is **50 milliseconds**. Any fixed refractory period long enough to suppress a double-fire would begin swallowing real stops, so no refractory period is used. The arming gate does the same job without a timer.

### Validation

The runtime algorithm was ported and replayed over all eight late iPhone runs, and compared against a whole-run principal-axis analysis of the same data. The two agree:

| Run | Offline reference | Runtime algorithm |
|---|---|---|
| Light single stop | 61 events, median 14.1 | 61 events, median 13.9 |
| Light double stop | 36, median 14.3 | 36, median 14.4 |
| Light double down | 64, median 17.6 | 65, median 19.3 |
| Vigorous single stop | 52, median 53.2 | 52, median 52.7 |
| Vigorous double stop | 37, median 39.2 | 38, median 39.4 |
| Vigorous double down | 75, median 38.3 | 74, median 42.1 |
| Rough shove | 2 | 3 |
| **Still** | **0** | **0** |

## Why the four candidate techniques were rejected

The implementation plan named four candidates. All four are absolute thresholds on some quantity, and **every one of them fails on the same measurement**, which is the central finding of this work.

The decisive comparison is between two light runs. In the light single-stop run, the recovery lobe **must not** sound — that is what makes it a single stop. In the light double-stop run, both lobes **must** sound. Measured:

| | Light single, driven end (must fire) | Light single, recovery (must **not** fire) | Light double, both ends (must fire) |
|---|---|---|---|
| Peak | 20.5 m/s² | **12.3** | **14.6 / 14.3** |
| Peak jerk | 701 m/s³ | **460** | **382 / 357** |
| Rise rate | 241 m/s²/s | **105** | **79 / 83** |
| Duration | 83 ms | 117 ms | 175 ms |

Read the bold columns against each other. The lobe that must stay silent is **larger** than the lobes that must sound — on peak it overlaps, and on jerk and on rise rate it is higher. No absolute threshold on any of those three quantities can separate them, and no amount of tuning changes that, because the two events are physically the same event. Only the performer's intention differs, and an accelerometer cannot see intention.

| Candidate | Verdict |
|---|---|
| **Jerk threshold** | Rejected. Inverted on the decisive pair: the lobe that must stay silent has a median jerk of 460 m/s³ against 357 and 382 for the lobes that must sound. Also fails on its own: a threshold of 700 collapses the double-stop run to 0.13 events per second |
| **Deceleration peak following a drive** | Rejected. Requires classifying a lobe as drive or stop before firing, which is the classification the table above shows cannot be made from the signal |
| **Axis reversal** | Rejected. The rough-shove run produces events with no reversal at all, and a reversal criterion would go silent exactly where a real bell rattles |
| **Magnitude peak with refractory** | Rejected twice over. Magnitude merges consecutive stops on the vigorous runs, and the 50 ms minimum gap leaves no room for a workable refractory period |

**What replaced them.** Fire on every deceleration and let intensity carry the difference. A real box of loose bells jingles on the recovery too, just more quietly, so the single, double, and double-down feels emerge from the amplitudes the hand produces rather than from a detector deciding what the player meant. This is both simpler and more faithful than any of the four.

Checked against every run at the committed settings:

| Run | Events per second | Intensity min / median / max |
|---|---|---|
| **Still** | **0.00** | silent |
| Light single stop | 5.88 | 6.7 / 14.1 / 27.3 |
| Light double stop | 3.53 | 9.5 / 14.3 / 18.1 |
| Light double down | 4.25 | 6.6 / 17.6 / 33.3 |
| Vigorous single stop | 5.76 | 10.7 / 53.2 / 102.6 |
| Vigorous double stop | 3.95 | 8.4 / 39.2 / 59.8 |
| Vigorous double down | 6.77 | 7.1 / 38.3 / 91.3 |
| Rough shove | 0.76 | 10.5 / 12.1 / 13.7 |

Silent on still, alive on everything else including the rough shove where no reversal exists.

## Intensity

**The measure is the peak magnitude of linear acceleration projected onto the motion axis at the detected stop** — the same number the detector already computes to find the event, so nothing additional is measured and there is only one definition of how hard a stop was.

The three alternatives in the plan were not adopted. Root-mean-square energy over a window blurs the distinction between a hard stop and sustained shaking, which is precisely the distinction being carried. Peak jerk was eliminated with the jerk threshold above. Change in speed across the stop requires integrating through the event, which cannot be done until the event has finished — and the event has to sound as it happens.

**Observed range: 6.6 to 102.6 m/s²**, a factor of 15.5, across 327 events in the six musical iPhone runs.

**Mapping onto levels.** Equal ratios of acceleration map to equal steps of intensity, so the levels are perceptually spaced rather than evenly spaced in raw acceleration. Normalised intensity is the logarithm of the ratio to the floor, divided by the logarithm of the ratio of ceiling to floor, clamped to the range zero to one. A shake harder than anything yet measured is the loudest the instrument has, which is correct behaviour for a normalised scale rather than an error.

| Level | Range | Share of the 327 measured events |
|---|---|---|
| 1 | 6.6 – 11.4 m/s² | 11% |
| 2 | 11.4 – 19.7 | 34% |
| 3 | 19.7 – 34.2 | 27%¹ |
| 4 | 34.2 – 59.2 | 17%¹ |
| 5 | 59.2 – 102.6 | 12% |

¹ No level is starved and none is swamped, which is what makes five a workable number.

**Five levels is the answer the audio work needs.** The number of recordings each bell requires is five per bell, and the Shake-to-Jingle interaction (C1_02) selects among several takes at the matched level so that repeated strokes do not sound identical.

**One judgment call is left open deliberately.** On this mapping, the light single stop puts its driven end at level 3 and its recovery at level 2 — one level of contrast. That may under-deliver the accent a player is going for. Making loudness rise faster than intensity would exaggerate it at the cost of making gentle shaking quieter overall. That is a taste decision that cannot be made without sound to listen to, and it belongs to the Shake-to-Jingle interaction (C1_02), not here.

## The sample rate

**120 samples per second on the target device, and it is sufficient. No interpolation is needed and no native plugin is needed.**

The implementation plan argued from the engine source that `preferredFrameRate` is assigned 60 as a literal and cannot be raised, concluded that 16.7 milliseconds was the floor, and named a native `CMMotionManager` plugin at 100 samples per second as the escalation route if that proved inadequate. **That premise is wrong.** Godot 4.6 on iOS 26.6 delivers 120 samples per second on a ProMotion display with no coaxing — measured at 119.67 to 120.46 across ten runs — and the `CADisableMinimumFrameDurationOnPhone` property-list key was never added, so the export template is handling it.

At 120 samples per second a stop spans **11 samples above half its height**, about 83 milliseconds, which places the peak to within about ±4 milliseconds. The plan's concern was that a stop might span two or three samples and require interpolating the peak between them; at 60 samples per second on the iPad the same physical event spanned 5 samples, which was already adequate, and on the iPhone it spans 11. **The escalation route can be struck.**

### A note on the timing columns

`dt_ms` in a captured file is not a measurement. Godot on iOS reports the display link's nominal interval, so the column reads a constant 8.333 on almost every frame while the real intervals between samples range from about 4.7 to 12.2 milliseconds. Disabling the engine's delta smoothing does not change this — files carrying `delta_smoothing=false` still show the constant. **`t_ms` is the only real clock in a capture file**, and any analysis of these runs should use it.

## The noise floor

Measured on the still runs, with the device held in a hand and music playing:

| | iPhone | iPad |
|---|---|---|
| 50th percentile | 0.62 m/s² | 0.68 |
| 95th percentile | 1.87 | 1.72 |
| 99th percentile | 2.71 | 3.01 |
| Maximum | **4.33** | 4.90 |

The specification's run acceptance table expected a still run to stay below roughly 0.8 m/s² throughout. Half the samples do, and the estimate was right about a hand at rest and wrong about a hand holding a device for several seconds. **Any threshold has to clear about 5 m/s², not 0.8**, which is a difference of a factor of six and rules out a whole band of sensitive settings that would have looked reasonable on paper.

## Sensor headroom

No saturation anywhere. The largest single-axis reading across all runs is −51.7 m/s², each extreme value occurs exactly once rather than pinning at a repeated ceiling, and the sensor's ±16 g range is about 157 m/s². A genuinely violent shake has roughly three times the headroom of the hardest measured stroke, so the intensity ceiling is a property of the hand rather than of the hardware.

## What this finding does not cover

**The rough-shove case is not settled.** That run is 2.6 seconds long and contains two events, which is not enough to conclude from. It is the run that decides whether a stop detector goes silent where a real bell would rattle, and it should be re-recorded at ten seconds of repeated rough shoves before anyone relies on the detector's behaviour there. The chosen technique does produce events in it, which is the right sign, but the sample is too small to call it verified.

**No Android hardware was measured.** The engine reports the gravity vector in opposite directions on the two platforms, which is why every technique here is confined to linear acceleration: the difference cancels when gravity is subtracted. That reasoning is sound but unverified on a real Android device, and `features/data/C1_09/README.md` records what to check before trusting Android motion data.

**Rotation was not isolated.** The specification asked for a wrist twist with as little travel as possible, to reveal what the gyroscope captures that the accelerometer misses. The run recorded under that name has the highest gyroscope content of its set but also the largest linear acceleration, so it does not answer the question. The gyroscope columns are recorded in every run and remain available to a technique that wants them; the chosen technique does not use them.
