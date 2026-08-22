---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for A Title That Arrives in Time
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: One script, one scene edit, and the only still thing on a moving screen starts keeping time, with the rhythm written as beats and bars rather than as a list of durations nobody can check against a metronome.
LAST UPDATED: August, 22, 2026 15:18
---

# Implementation Plan for A Title That Arrives in Time

This plan implements A Title That Arrives in Time feature (C1_14), which animates the three words of the title artwork so they arrive one per quarter note and then pulse on that same beat for as long as the title screen is shown.

The whole of it is one new script and one line changed in one scene. Everything difficult about it is in three places: making the words absent before the first frame is drawn without breaking the editor, expressing the rhythm so it cannot be set to something that is not in time, and animating against sizes that are authored rather than named.

## Design decisions carried in from the specification and planning conversations

- **The rhythm is 4/4 at 80 beats per minute.** A beat is 0.75 seconds, a bar is 3.0 seconds, and the loop is two bars: three words on beats one, two, and three, then five beats of rest. One second of stillness precedes the first word.
- **The first loop is the entrance; every loop after it is the pulse.** Nothing else about the two differs — same words, same order, same one-beat stagger, same loop boundary.
- **The loop is exported in beats, not seconds.** `loop_beats: int = 8`, with the loop duration derived as `beat_seconds × loop_beats`. Exported independently in seconds the two values could disagree and put the pattern out of time with nothing to catch it; expressed this way the tempo is one number and the musically-broken state is unrepresentable.
- **The ease curves are hard-coded, not exported.** Each gesture grows with `TRANS_CUBIC` and `EASE_OUT`, so it leaves zero fast and decelerates into its peak, and returns with `TRANS_CUBIC` and `EASE_IN_OUT`, so it eases off the peak and onto the resting size. That reads as a hit followed by a settle. Requirement 7 asks for every timing and size to be adjustable; these are four enum values that make the gesture either right or wrong, not numbers to dial against a phone.
- **The three words are found by name.** `Holiday`, `Sleigh`, and `Bells`, validated in `_ready` with a message naming the missing one. This is the repository's stated convention for a node dependency reached by scene path, and its no-fallbacks rule means a missing word stops the animation rather than bringing the title in as two words with nothing to say why. Animating every `Sprite2D` child in tree order would need no configuration but has no failure mode at all.
- **The behaviour extends the placement script rather than replacing it.** The title screen places this scene through `app/sprite_position.gd`'s exported `design_position` and `respect_safe_area`, and a Godot node holds one script. The Instrument Carousel feature (C1_08) met the same collision and resolved it by subclassing; this follows it exactly, including calling `super()` from `_ready`.

## The three things worth getting right

### The words must be absent before the first frame, and present in the editor

Requirement 2 starts each word at a scale of zero, and requirement 8 keeps all three at their authored scale while the scene is being composed. Both are satisfied by the same guard, but the ordering inside `_ready` matters and is easy to get subtly wrong.

`super()` runs first, so the placement script still connects its resize handler and positions the root — in the editor as well as at runtime, because that is what draws the composition at design size. Only then does `Engine.is_editor_hint()` return, leaving the editor with three words at their authored scales and no tweens. At runtime the scales are zeroed inside that same `_ready`, which is before the first frame is drawn. Deferring the zeroing to the moment the one-second delay expires would show a full-size title for a second and then collapse it, which is the opposite of an entrance.

The placement script's `_validate_property` strips `position` from storage on the root only. The three words' `scale` values are ordinary stored properties and are what this feature animates, so nothing about that mechanism interferes.

### Every size is a multiplier on a scale that is captured, never named

`Holiday` is saved at 2.1309524, `Sleigh` at 2.1103897, and `Bells` at 2.1027396 — three numbers fitted by eye that will be fitted again. Each word's resting scale is read from the scene in `_ready`, before anything is zeroed, and every animated size is that value multiplied by `entrance_overshoot` or `pulse_peak`. A plan that wrote those three numbers into the code would silently resize the artwork the first time a word is nudged in the editor, and the symptom would be a title that looks slightly wrong with nothing pointing at why.

The root's own position and scale are left entirely alone. The animation touches the three children's `scale` and nothing else, so `design_position` goes on owning where the block sits.

### The pattern is scheduled, not clocked

Two tweens carry the whole thing and neither animates a property. The first is the one-off opening: wait the initial delay, play the entrance set, wait out the rest of that loop, and hand over. The second repeats forever, playing one pulse set at the top of every loop. Each set in turn creates three short tweens, one per word, the second and third delayed by one and two beats.

Tweens created through `Node.create_tween()` are bound to the node and are killed when it leaves the tree, so a scene change needs no cleanup of its own. Because the loop is a chain of intervals rather than a reading of a clock, it can drift by a fraction of a frame over a long run; nothing here is synchronised to audio or to anything else, so that drift has no consequence and is not corrected for.

## Implementation Steps and Phases

### Phase 1: The script

Create `app/holiday_sleigh_bells.gd`.

```gdscript
# holiday_sleigh_bells.gd (C1_14 title animation) - the three words arrive on the beat, then breathe on it.
#
# The gesture is written as a rhythm rather than as a list of durations: one beat is a quarter
# note, a loop is eight of them, and the three words fire on the first three beats of every
# loop. The first loop is the entrance, where a word grows from nothing past its resting size
# and settles back onto it; every loop after it is the pulse, the same phrase spoken quietly.
#
# Every size here is a multiplier on the scale each word is saved at, captured once in _ready.
# The three words are hand-sized differently and will be sized again, so an animation naming
# those numbers would quietly undo the next composition change made in the editor.
#
# This extends sprite_position.gd rather than replacing it because the title screen places this
# scene through that script's exported properties, and a node holds only one script. The
# Instrument Carousel feature (C1_08) met the same collision and resolved it the same way.
@tool
extends "res://app/sprite_position.gd"

# The words, in reading order, which is also their order in the scene. The names are written
# here rather than inferred from the children so that a missing or renamed word stops the
# animation with a message, instead of bringing the title in as two words and saying nothing.
const WORD_NAMES: Array[String] = ["Holiday", "Sleigh", "Bells"]

# Unticked, the three words sit at their authored scales and nothing moves, which is the scene
# exactly as it rendered before this feature.
@export var animate: bool = true

@export_group("Rhythm")
# Stillness after the screen appears, before the first word arrives.
@export var initial_delay_seconds: float = 1.0
# One quarter note. 0.75 seconds is 80 beats per minute, and a bar is 3.0 seconds.
@export var beat_seconds: float = 0.75
# The repeating unit, in beats: two bars of 4/4, being three words and then five beats of rest.
# In beats rather than seconds so that changing the tempo moves the whole pattern together and
# the loop cannot be set to a length that is not in time with the beat.
@export var loop_beats: int = 8

@export_group("Entrance")
# How far past its resting size a word carries before coming back, as a multiple of it.
@export var entrance_overshoot: float = 1.12
@export var entrance_grow_seconds: float = 0.12
@export var entrance_settle_seconds: float = 0.18

@export_group("Pulse")
# The peak, not a value passed through: the pulse has no overshoot to correct.
@export var pulse_peak: float = 1.05
@export var pulse_grow_seconds: float = 0.12
@export var pulse_return_seconds: float = 0.20

var _words: Array[Sprite2D] = []
var _resting_scales: Array[Vector2] = []

# super() first, so the placement script positions the root in the editor as well as at
# runtime. The editor stops there: scaling the words to zero while the scene is open would
# take the artwork off the 2D editor and make the composition impossible to author.
func _ready() -> void:
	super()
	if Engine.is_editor_hint() or not animate:
		return
	if not _collect_words():
		return
	if loop_beats < WORD_NAMES.size():
		push_error("holiday_sleigh_bells: `loop_beats` is %d. It must be at least %d, one beat for each word, and the default is 8." % [loop_beats, WORD_NAMES.size()])
		return
	# Before the first frame is drawn, not when the delay expires. A word left at its authored
	# scale for even one frame is a flash of the finished title before the entrance collapses it.
	for word in _words:
		word.scale = Vector2.ZERO
	_conduct()

# The resting scales are captured before anything is scaled, because a resting scale is
# authored in the scene and exists nowhere else once the words have been zeroed.
func _collect_words() -> bool:
	_words.clear()
	_resting_scales.clear()
	for word_name in WORD_NAMES:
		var word := get_node_or_null(NodePath(word_name)) as Sprite2D
		if word == null:
			push_error("holiday_sleigh_bells: no Sprite2D child named `%s`. The title animation needs all three of %s, in that order." % [word_name, ", ".join(WORD_NAMES)])
			return false
		_words.append(word)
		_resting_scales.append(word.scale)
	return true

# Two tweens carry the pattern and neither animates anything itself; both only schedule. The
# opening is played once - the delay, the entrance, and the rest of that first loop - and hands
# over to the pulse, which repeats for as long as the screen is up.
func _conduct() -> void:
	var opening := create_tween()
	opening.tween_interval(initial_delay_seconds)
	opening.tween_callback(_play_set.bind(true))
	opening.tween_interval(_loop_seconds())
	opening.tween_callback(_start_pulsing)

func _start_pulsing() -> void:
	var pulsing := create_tween().set_loops()
	pulsing.tween_callback(_play_set.bind(false))
	pulsing.tween_interval(_loop_seconds())

# One set of three: the same gesture on each word, one beat apart, in reading order. The
# stagger is the point of the feature - three words together is a title appearing, three words
# a beat apart is a title being spoken.
func _play_set(entrance: bool) -> void:
	for index in _words.size():
		var word := _words[index]
		var resting := _resting_scales[index]
		var peak := resting * (entrance_overshoot if entrance else pulse_peak)
		var grow_seconds := entrance_grow_seconds if entrance else pulse_grow_seconds
		var return_seconds := entrance_settle_seconds if entrance else pulse_return_seconds
		var word_tween := create_tween()
		if index > 0:
			word_tween.tween_interval(beat_seconds * float(index))
		# Off the mark fast and decelerating into the peak, then eased at both ends coming off
		# it, so the two motions read as a hit followed by a settle rather than as two hits.
		word_tween.tween_property(word, "scale", peak, grow_seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		word_tween.tween_property(word, "scale", resting, return_seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _loop_seconds() -> float:
	return beat_seconds * float(loop_beats)
```

One engine behaviour to confirm on the first run rather than assume: `Node2D` guards its transform against a zero scale component internally, so a word at `Vector2.ZERO` is invisible rather than degenerate. Watch the output for a transform warning on launch. If one appears, the zeroed scale becomes an explicit small epsilon and the reason is written at that line.

### Phase 2: The scene

Open `app/holiday_sleigh_bells.tscn` in the editor and change the root node's script from `res://app/sprite_position.gd` to `res://app/holiday_sleigh_bells.gd`. Doing it in the editor rather than by hand-editing the scene file is what gets the script's resource identifier written correctly and drops the now-unreferenced external resource entry for the placement script.

Nothing else in that scene changes. The three `Sprite2D` children keep their names, positions, scales, and textures exactly as they are, and the root keeps its `uid://n6lxwfwn1621` so the title screen's reference to it is untouched.

Then confirm the title screen's instance overrides survive. `app/main.tscn` sets `design_position = Vector2(524, 568)` and `respect_safe_area = true` on its `HolidaySleighBells` instance, and both properties are inherited from the placement script by the new subclass. Open `app/main.tscn` and check that both values are still shown as overridden on the instance and the artwork is still where it was.

### Phase 3: Tuning on the device

Build and run on the iPhone and watch the entrance several times over. The four numbers most likely to want moving are `entrance_overshoot`, the two entrance durations, and `pulse_peak`; the values in this plan are a starting point agreed during ideation, not a commitment.

Two things to judge that a desktop run cannot answer. Whether the overshoot reads as two motions or as one snap, which depends on the display's refresh rate and on how large the artwork actually is in the hand. And whether the pulse is subtle enough to live on screen indefinitely — 105% was chosen so that three stacked words breathing every six seconds reads as alive rather than as a layout that will not settle, and that judgement needs a real phone in a dark room.

## Test Cases

**No automated tests are created or changed by this plan.** The developer has elected to verify this feature manually, as on the five features preceding it. The repository has no test framework, and the system design records that as a deliberate position rather than an oversight. There is accordingly no test-case table of unit or interface tests; the verification table in the next section but one carries the full burden, and the completion criteria depend on those manual checks rather than on a passing suite.

The consequence worth recording is that two of the failures most likely here look like something other than their cause. A word left at its authored scale for one frame before the zeroing appears as a flicker at launch, which reads as a loading artefact rather than as an ordering mistake inside `_ready`. And an animation that names the three authored scales rather than multiplying against them shows no symptom at all until somebody resizes a word in the editor, months later, and finds their change silently undone. Each has its own row below, and both should be re-checked after any later change to this script.

## README and Documentation Updates

This feature adds no directory, so the README's repository-structure table needs no new row.

A short **The title animation** section is added to `README.md` after **The snow**, modelled on the sections already there: that the three words of the title artwork arrive one per quarter note and then pulse on the same beat, that the whole pattern is two bars of 4/4 and is exported in beats so the tempo is one number, that every size is a multiplier on the scale each word is authored at, and that the animation travels inside `app/holiday_sleigh_bells.tscn` so any screen instancing the artwork gets it.

`docs/system_design.md` gains one addition under **Screen composition**, which currently names `app/sprite_position.gd` and `app/safe_area_margin.gd` as the two shared placement scripts. A sentence records that a screen-composition scene needing behaviour of its own subclasses the placement script rather than replacing it, because a node holds one script, and that both `app/instrument_carousel.gd` and `app/holiday_sleigh_bells.gd` are built that way. The system design describes the application as built, and after this feature two scenes follow that pattern rather than one.

Three pieces of knowledge introduced here are not evident from reading the code, and each is recorded as a comment where someone changing that behaviour will be looking:

- At the top of `app/holiday_sleigh_bells.gd`, why every size is a multiplier on a captured scale rather than a number: the three words are hand-sized and will be sized again.
- On the zeroing loop in `_ready`, why it happens there and not when the delay expires: a word at its authored scale for one frame is a flash of the finished title.
- On `loop_beats`, why the loop is expressed in beats rather than seconds: so that changing the tempo moves the whole pattern together and the loop cannot be set out of time with the beat.

## Manual Verification Steps

Because there are no automated tests, these steps are the verification. The rows in bold exercise behaviour whose failure mode points somewhere other than its cause.

| Behaviour under test | How to exercise it | Expected result |
|---|---|---|
| **No flash of the finished title** | Launch the application and watch the first half-second closely, several times | The three words are never seen at full size before the entrance. A single frame of the complete title means the zeroing is happening after the delay rather than in `_ready` |
| The screen holds still first | Launch and count one second | Background, vignette, logo, tree, snowflake, Winnie, Play Along, button, and snow are all present and behaving normally, and the three title words are absent |
| The words arrive in order | Watch the entrance | `Holiday` first, then `Sleigh`, then `Bells`, top to bottom |
| The stagger is even | Watch the entrance several times | The gap between the first and second words is the same as between the second and third. Neither a rushed nor a dragged middle |
| Each word overshoots and comes back | Watch a single word, say `Sleigh`, through its entrance | It grows past its final size and settles back onto it. Two distinct motions, not one snap |
| **The words land at their authored size** | Untick `animate` in the inspector, run, and screenshot; retick it, run, and screenshot the resting state after the entrance | The two are identical. A difference means the animation is not returning to the captured resting scale |
| Nothing moves | Watch all three words through an entrance and a pulse | No word changes position at any point. Each grows about its own centre |
| The second set is a pulse | Watch from launch to about eight seconds | The set at roughly seven seconds is a slight swell, not another entrance from nothing |
| The loop repeats | Watch for a full minute | A set of three every six seconds, indefinitely, with five beats of rest between |
| The pulse is subtle | Look at the screen as a whole for a minute | It reads as the title breathing, not as the layout shifting |
| The pulse keeps the entrance's rhythm | Watch several loops | The three words pulse one beat apart, in the same order, at the same interval as they arrived |
| **The editor still shows the artwork** | Open `app/holiday_sleigh_bells.tscn` and `app/main.tscn` in the editor | All three words are visible at their authored scales and can be selected and moved. Nothing animates, and no error appears |
| Placement still works | In `app/main.tscn`, check the `HolidaySleighBells` instance in the inspector | `design_position` is `Vector2(524, 568)` and `respect_safe_area` is on, both still shown as instance overrides |
| Placement survives a resize | Run in a window and drag it taller, then wider | The title block stays where `design_position` puts it, during and after the resize, exactly as before this feature |
| Tempo moves everything together | Set `beat_seconds` to 0.5 and run | The words arrive faster, the stagger tightens to match, and the loop shortens in proportion. The pattern stays in time with itself |
| `loop_beats` is validated | Set `loop_beats` to 2 and run | An error names the value, the minimum of 3, and the default of 8, and no animation runs |
| A missing word is reported | Rename `Bells` to something else and run | An error names the missing child and lists the three words the animation needs. Nothing animates. Rename it back |
| The off switch is complete | Untick `animate` and run | All three words sit at their authored scales, motionless, for as long as the screen is up |
| The entrance replays | Quit and relaunch | The full entrance plays again from nothing. The title screen is never navigated back to in the current flow, so relaunching is the only way to exercise this |
| **The Tap to start button still works** | Press it, by finger on the device and by mouse on the desktop | It advances to the instructions screen exactly as before |
| The rest of the screen is untouched | Compare the title screen against its previous state | Background, vignette, logo, tree, snowflake, Play Along, Winnie, button, and falling snow are all exactly as they were |
| No other screen is affected | Walk the instructions, bell selection, and play screens | All three are unchanged. None of them instances the title artwork |
| The project is clean | Open the project and watch the output panel | No errors, no warnings, and every resource reference resolves |

**On the device.** Build and run on the iPhone and watch the entrance several times before walking the full flow. The desktop answers every row above, since nothing here reads a sensor, but the two judgements that decide whether the tuning is right — whether the overshoot reads as two motions, and whether the pulse is subtle enough to live on screen indefinitely — need a real display at its real size.

## Coding Standards Compliance Checklist

The application coding standards document named in the skill's project instructions does not exist in this repository. The following are the conventions this codebase actually demonstrates, and this plan conforms to each.

- Tab indentation in GDScript, matching `app/instrument_carousel.gd` and `app/sprite_position.gd`.
- A one-line comment at the top of the script naming the file, the feature it belongs to, and its role, followed by what a reader needs that the code cannot tell them, matching `snow/snow.gd` and `shake/shake_detector.gd`.
- Static typing on declarations, parameters, and return types, including `-> void` and `-> bool`, as every existing script does.
- Scene and script files named in lower snake case, and the script named for the scene it drives, matching `app/instrument_carousel.gd` against `app/instrument_carousel.tscn`.
- Exported values for anything art-directed, authored outside the code that consumes it, grouped with `@export_group`, matching `app/instrument_carousel.gd` and `snow/snow.gd`.
- An exported value used as a loop count validated in `_ready`, with a message naming the value, its permitted range, and the correct default. `loop_beats` carries this; the durations and multipliers are neither divisors, bounds, nor counts, and are left unguarded rather than given checks the convention does not call for.
- A node dependency reached by scene path validated in `_ready` rather than at first use, matching the same convention, so a renamed word surfaces at load.
- Why a reasoned constant has the value it does, written where the constant is, matching `shake/shake_detector.gd`. `beat_seconds` carries its tempo, `loop_beats` its two bars, and `pulse_peak` the reason it is small.
- Behaviour that a placed scene needs added by subclassing `app/sprite_position.gd` and calling `super()` from `_ready`, matching `app/instrument_carousel.gd`.
- Work skipped in the editor behind `Engine.is_editor_hint()`, matching `app/instrument_carousel.gd`, which guards `_open_on_chosen`, `_publish_selection`, and its input handling the same way.
- **No fallbacks.** A missing word raises and stops. An out-of-range `loop_beats` raises and stops. Neither substitutes a default, animates the words it did find, or carries on with a corrected value.

## File-Level Compliance Review

| File | Change |
|---|---|
| `app/holiday_sleigh_bells.gd` | New. The rhythm, the entrance, the pulse, and the validation. Extends `app/sprite_position.gd` |
| `app/holiday_sleigh_bells.tscn` | The root node's script changes from `app/sprite_position.gd` to `app/holiday_sleigh_bells.gd`. The three `Sprite2D` children and the scene's `uid` are untouched |
| `README.md` | A **The title animation** section added after **The snow**. The repository-structure table is unchanged |
| `docs/system_design.md` | One sentence under **Screen composition** recording that a composition scene needing behaviour subclasses the placement script, with both scenes that do so named |
| `app/main.tscn` | Unchanged. Its instance overrides are inherited properties and resolve against the subclass |
| `app/sprite_position.gd` | Unchanged. It is extended, not edited |
| `app/instrument_carousel.gd` | Unchanged. It is the precedent, not a participant |
| `images/v2/holiday.svg`, `sleigh.svg`, `bells.svg` | Unchanged, including their import settings |
| `app/instructions.tscn`, `app/instrument_select.tscn`, `app/instrument.tscn` | Unchanged. No screen but the title screen instances this artwork |
| `snow/`, `shake/`, `capture/`, `shaders/`, `legacy/` | Unchanged |
| `project.godot` | Unchanged. Nothing here is an autoload and no project setting is involved |

No background, logo, button, layout, artwork, asset, or screen outside `app/holiday_sleigh_bells.tscn` is touched. No media file is moved or deleted.

## Completion Criteria

1. `app/holiday_sleigh_bells.gd` exists, extends `app/sprite_position.gd`, calls `super()` from `_ready`, and is the root script of `app/holiday_sleigh_bells.tscn`.
2. The title screen shows no title words for one second after it appears, and the complete title is never visible at full size before the entrance.
3. `Holiday`, `Sleigh`, and `Bells` each enter by growing from a scale of zero to `entrance_overshoot` of their authored scale and settling back onto it, one beat apart, in that order.
4. Every set after the first is a pulse to `pulse_peak` and back, on the same one-beat stagger and in the same order, with no overshoot.
5. A set of three plays at the top of every loop of `beat_seconds × loop_beats`, indefinitely, for as long as the title screen is shown.
6. No word's position changes at any point, and the root's `design_position` and `respect_safe_area` go on placing the block exactly as before, including across a live resize.
7. Every animated size is a multiplier on the scale captured from the scene in `_ready`, and no authored scale appears as a number anywhere in the script.
8. `animate`, the three rhythm values, the three entrance values, and the three pulse values are all exported and adjustable without editing code, and unticking `animate` leaves the scene rendering exactly as it did before this feature.
9. In the editor, all three words are visible at their authored scales in both `app/holiday_sleigh_bells.tscn` and `app/main.tscn`, nothing animates, and no error appears.
10. `loop_beats` below three, and a missing or renamed word, each raise an error naming what is wrong and stop, animating nothing.
11. `README.md` carries a **The title animation** section, and `docs/system_design.md` records the subclassing pattern under **Screen composition**.
12. The instructions, bell selection, and play screens are unchanged, and the Tap to start button still advances the flow by finger and by mouse.
13. The project loads with no errors or warnings and every resource reference resolves.
14. Every row in the verification table passes, including the on-device watch of the entrance.

## Token and Design Considerations

This feature builds no skill, so there is no `input_limits` value, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed. This feature combines two patterns the repository already demonstrates — subclassing `app/sprite_position.gd` to give a placed scene behaviour, as `app/instrument_carousel.gd` does, and driving motion with a `Tween`, as that same script's settle does — and adds no capability the tutor covers.
