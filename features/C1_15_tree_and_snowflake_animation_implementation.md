---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Artwork That Answers the Tilt of the Phone
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Four new scripts and two scene edits that turn three still images into artwork with a pulse, with the one piece of arithmetic nobody expects — that a phone held normally is nowhere near level — worked out rather than discovered on the device.
LAST UPDATED: August, 22, 2026 15:31
---

# Implementation Plan for Artwork That Answers the Tilt of the Phone

This plan implements the Artwork That Answers the Tilt of the Phone feature (C1_15). It adds four new scripts to `app/` and attaches three of them inside two existing artwork scenes. No screen file is edited, no asset is added, no autoload is registered, and `project.godot` is untouched.

## Design decisions carried in from the specification and planning conversations

These were settled during ideation and planning and are implemented rather than re-opened.

- **Gravity, not linear acceleration.** The tree answers how the phone is *held*, not how it is *swung*. A tilt gives a pose that persists and needs no spring-back rule, and it makes the tree and the halo answer the same gesture.
- **The sway script carries no pivot.** It rotates the node it is attached to, about that node's own origin. `app/straight_red_tree.tscn` now sets `offset` `(20.19, -418.03)` with a compensating `position` of `(-214, 498)`, which puts that origin at the foot of the trunk without moving the artwork by a pixel. Moving the pivot later is a scene edit that needs no code change.
- **The halo's drift is a direct map, not a lagging one.** A given pose always puts the halo in the same place, and it stops when the phone stops. The sway is smoothed; the drift is not. This asymmetry is deliberate and is not an oversight to be tidied up.
- **The vertical neutral is exported and defaults to 0.75**, resolved during planning. See "What counts as level" below; this is the decision the specification was silent on.
- **A fourth file carries the shared tilt reading**, resolved during planning. `app/phone_tilt.gd` holds the gravity projection both tilt behaviours need, so the Android sign correction lands in one place for both. `snow/snow.gd` keeps its own copy and is not routed through it.
- **The behaviours live in `app/`**, not in a top-level directory of their own. They are small scripts that decorate existing artwork rather than a self-contained effect a screen adds as a unit.
- **None of the four is a `@tool` script.** A snowflake spinning in the 2D editor while a screen is being laid out makes composing harder, not easier.

## What counts as level

The specification's requirement 4 asks the halo to slide "vertically with the front-to-back tilt", and left the neutral for that axis unstated. The two axes are not symmetric, and this is the piece of arithmetic the build would otherwise discover on the handset.

The horizontal axis has an honest zero. `gravity.x` is zero when the phone is not rolled left or right, so "no roll" and "halo centred" are the same pose, and the horizontal neutral is a constant zero that is not exported.

The vertical axis does not. Using the same projection `snow/snow.gd` uses, the vertical component of in-plane gravity runs **1.0 with the phone upright** down to **0.0 with it flat and face up**, and a phone held at a normal reading angle sits around 0.9. Treating zero as neutral would therefore pin the halo at its maximum downward travel for the entire time anyone is holding the phone, and return it to its authored position only when the phone is laid on a seat — making the authored composition the one pose nobody ever sees.

The drift therefore measures deviation from an exported `vertical_neutral_tilt`, defaulting to **0.75**. At that default, holding the phone upright pushes the halo half its travel one way, and tipping it back toward flat pushes it to the clamp the other way, so both directions are real. The number is meant to be adjusted once the phone is in hand.

## Where the noise floor works and where it does not

The noise floor is applied to the length of the in-plane vector before either behaviour sees it, and this is the right place for it rather than a per-axis deadband. A phone lying flat and face up puts almost all of gravity through the screen; what is left in the plane of it is small enough to be dominated by sensor noise, so that is the pose where a raw reading shimmers. A phone held upright has a large, stable in-plane component and a low noise-to-signal ratio.

What the floor does **not** cover is hand tremor at a held pose, and this plan is explicit about it because the direct map of requirement 4 has no smoothing to absorb it. A tremor of a few hundredths of gravity, at the default `tilt_at_maximum_drift` of 0.5 and 40 pixels of horizontal travel, moves the halo by a few pixels — against a disc roughly 554 pixels across, under one percent of its size. The expectation is that this is invisible. If it reads as shimmer on the device, the smallest change that fixes it is adding a response time constant to the drift, which is the field the sway already has and a one-line addition. That is a decision for the developer with the phone in hand, not one this plan makes in advance.

The floor also produces a small step as it is crossed: the reading snaps between zero and the floor value rather than easing through it. At the default floor of 0.05 that step is a tenth of full travel — four pixels of drift, and 0.3 degrees of sway, which the sway's smoothing absorbs entirely. Rescaling the reading above the floor to remove the step is not worth the arithmetic at these magnitudes.

## The no-sensor case, and why the neutral is passed in

Requirement 7 asks the two tilt behaviours to hold the neutral pose wherever no gravity is reported, which is the editor, the desktop build, and the simulator. This interacts with the vertical neutral in a way worth stating, because the obvious implementation gets it wrong.

A reading of exactly zero and a phone lying perfectly flat both produce an in-plane vector of zero, but they must not produce the same result. A flat phone is a real reading of 0.0 on the vertical axis, which against a neutral of 0.75 is a large deviation and correctly drives the halo to its clamp. No reading at all must produce no deviation and leave the halo where it was authored.

`app/phone_tilt.gd` therefore takes the caller's own neutral as an argument and returns it unchanged when there is no reading, so the caller's `tilt - neutral` is exactly zero in that case. The sway passes `Vector2.ZERO` and gets the same behaviour for free.

## Implementation Steps and Phases

### Phase 1: The shared tilt reading

Create `app/phone_tilt.gd`.

```gdscript
# phone_tilt.gd (C1_15 artwork behaviours) - the one place the device's gravity vector becomes a
# tilt in screen coordinates.
#
# Two behaviour scripts need the same reading and the same rejection rule, and the mapping they
# share is iOS-shaped. docs/system_design.md records that the engine reports the gravity vector
# in opposite directions on iOS and Android and that no Android handset has been measured; when
# that sign is settled it is settled here for both callers.
#
# snow/snow.gd carries its own copy of the same mapping and is deliberately not routed through
# this. Editing a working sensor path is not this feature's business, and the two copies are
# named together in the platform notes so whoever fixes one finds the other.
class_name PhoneTilt
extends Object

# The tilt in screen coordinates - +x to the right, +y down - with each component a fraction of
# total gravity, so the result is the same number whatever units the platform reports gravity in.
#
# neutral is what the caller considers level, and it is returned unchanged where there is no
# reading at all: the editor, the desktop build, and the simulator. Returning it rather than zero
# is what makes the caller's own deviation from neutral come out at zero there, which is the rest
# pose requirement 7 asks for. Returning zero would be indistinguishable from a phone lying flat,
# which is a real reading and a large deviation from a non-zero neutral.
static func read(neutral: Vector2, noise_floor: float) -> Vector2:
	var gravity := Input.get_gravity()
	var magnitude := gravity.length()
	if magnitude == 0.0:
		return neutral
	# +x to the right, +y down, matching the screen and matching snow/snow.gd.
	var in_plane := Vector2(gravity.x, -gravity.y) / magnitude
	# A phone lying flat and face up puts almost all of gravity through the screen, and what is
	# left in the plane of it is sensor noise. This is the pose where a raw reading shimmers; a
	# phone held upright has a large, steady in-plane component and does not need the guard.
	if in_plane.length() < noise_floor:
		return Vector2.ZERO
	return in_plane
```

### Phase 2: The three behaviour scripts

Each attaches to a `Sprite2D` and works as an offset from the pose that sprite is authored with, captured in `_ready()`. Every frame writes the rest pose plus the offset rather than adjusting the current value, so repeated frames never compound and an edit to the authored value in the inspector is respected rather than overwritten.

Create `app/tilt_sway.gd`.

```gdscript
# tilt_sway.gd (C1_15 artwork behaviours) - leans a sprite the way the phone is tilted side to side.
#
# It rotates the node it is attached to, about that node's own origin, and carries no pivot of
# its own. That is deliberate: a Sprite2D's origin is established in the scene by centered and
# offset, so where the artwork bends is positioned by eye in the editor rather than typed in
# here. app/straight_red_tree.tscn sets that origin at the foot of the trunk, which is what makes
# the tree bend rather than spin.
extends Sprite2D

# How far the sprite may ever lean. A negative value leans it the other way.
@export var maximum_sway_degrees: float = 3.0

# The side-to-side tilt, as a fraction of total gravity, at which the full lean is reached. 0.5
# is the phone rolled halfway onto its side; a lower number makes a smaller wrist movement do more.
@export var tilt_at_maximum_sway: float = 0.5

# How quickly the lean follows the phone. A hand is never still, and a sprite this large tracking
# a raw gravity reading would visibly tremble while the phone was held steady.
@export var response_time_constant_seconds: float = 0.35

# Below this fraction of total gravity the reading is taken as no tilt at all.
@export var noise_floor: float = 0.05

var _rest_rotation: float = 0.0
var _sway_radians: float = 0.0

func _ready() -> void:
	if tilt_at_maximum_sway <= 0.0:
		push_error("tilt_sway.gd on '%s': tilt_at_maximum_sway is %f. It divides the tilt reading and must be greater than 0. The default is 0.5." % [name, tilt_at_maximum_sway])
		set_process(false)
		return
	if response_time_constant_seconds <= 0.0:
		push_error("tilt_sway.gd on '%s': response_time_constant_seconds is %f. It divides the frame delta and must be greater than 0. The default is 0.35." % [name, response_time_constant_seconds])
		set_process(false)
		return
	_rest_rotation = rotation

func _process(delta: float) -> void:
	var tilt := PhoneTilt.read(Vector2.ZERO, noise_floor)
	var target := clampf(tilt.x / tilt_at_maximum_sway, -1.0, 1.0) * deg_to_rad(maximum_sway_degrees)
	_sway_radians = lerpf(_sway_radians, target, clampf(delta / response_time_constant_seconds, 0.0, 1.0))
	rotation = _rest_rotation + _sway_radians
```

Create `app/continuous_spin.gd`.

```gdscript
# continuous_spin.gd (C1_15 artwork behaviours) - turns a sprite slowly and forever.
#
# The one behaviour in this feature that reads no sensor. It runs identically on a handset and on
# the desktop, and it has no rest state to return to - only a rest pose it counts up from.
#
# Elapsed time is accumulated and the rotation derived from it, rather than the rotation being
# added to directly. That keeps the authored rotation as the rest pose and keeps this script the
# same shape as the other two: what it writes every frame is derived output, recomputed rather
# than adjusted in place.
extends Sprite2D

# Degrees per second. A negative value turns the other way. Slow is the intent - the default is
# one full turn a minute.
@export var rotation_degrees_per_second: float = 6.0

var _rest_rotation: float = 0.0
var _elapsed_seconds: float = 0.0

func _ready() -> void:
	_rest_rotation = rotation

func _process(delta: float) -> void:
	_elapsed_seconds += delta
	rotation = _rest_rotation + deg_to_rad(rotation_degrees_per_second) * _elapsed_seconds
```

Create `app/tilt_drift.gd`.

```gdscript
# tilt_drift.gd (C1_15 artwork behaviours) - slides a sprite a short way as the phone is tilted.
#
# It offsets the node's position from the one it is authored with. It stays off an artwork
# scene's root node deliberately: app/sprite_position.gd owns that node's position, overwrites it
# on ready, on viewport resize, and on every exported-property change, and strips it from storage
# so a drag is discarded. A child sprite's position is its own and nothing else writes it.
#
# The map is direct rather than lagging, so a given pose always puts the sprite in the same place
# and it stops when the phone stops. That is the opposite choice from tilt_sway.gd, and it is
# deliberate rather than an inconsistency.
extends Sprite2D

# How far the sprite may ever travel, in pixels of its parent's space. A negative value reverses
# that axis. The two are separate rather than one radius because the halo has more room sideways
# than it has vertically before it slides out from behind the flake it belongs to.
@export var maximum_horizontal_drift_pixels: float = 40.0
@export var maximum_vertical_drift_pixels: float = 28.0

# The deviation from neutral, as a fraction of total gravity, at which full travel is reached on
# either axis.
@export var tilt_at_maximum_drift: float = 0.5

# What counts as level, front to back. Side to side, level is genuinely no roll, so the
# horizontal neutral is a constant zero and is not exported. Front to back it is not: the
# vertical reading runs 1.0 with the phone upright down to 0.0 with it flat and face up, so a
# phone being held normally sits near the top of that range. At 0.75 the authored position falls
# between the two, and the sprite has travel in both directions rather than being pinned at its
# clamp the whole time the phone is held.
@export var vertical_neutral_tilt: float = 0.75

# Below this fraction of total gravity the reading is taken as no tilt at all.
@export var noise_floor: float = 0.05

var _rest_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if tilt_at_maximum_drift <= 0.0:
		push_error("tilt_drift.gd on '%s': tilt_at_maximum_drift is %f. It divides the tilt reading and must be greater than 0. The default is 0.5." % [name, tilt_at_maximum_drift])
		set_process(false)
		return
	_rest_position = position

func _process(_delta: float) -> void:
	var neutral := Vector2(0.0, vertical_neutral_tilt)
	var deviation := (PhoneTilt.read(neutral, noise_floor) - neutral) / tilt_at_maximum_drift
	position = _rest_position + Vector2(
		clampf(deviation.x, -1.0, 1.0) * maximum_horizontal_drift_pixels,
		clampf(deviation.y, -1.0, 1.0) * maximum_vertical_drift_pixels
	)
```

### Phase 3: Attach the behaviours to the two artwork scenes

`app/straight_red_tree.tscn`: attach `app/tilt_sway.gd` to the **`StraightRedTree` `Sprite2D` child**, not to the root `Node2D`. The root carries `app/sprite_position.gd` and does not carry the pivot. Leave the exported values at their defaults for the first run.

`app/blue_snowflake.tscn`: attach `app/continuous_spin.gd` to the **`BlueSnowflake` `Sprite2D`** and `app/tilt_drift.gd` to the **`GreenCircle` `Sprite2D`**. Leave the exported values at their defaults for the first run.

Nothing else in either scene changes. In particular the tree's `offset` and `position`, which the developer set to place the pivot, are left exactly as they are.

### Phase 4: Tune on the handset

Export and run on the iPhone, walk to the title screen, and adjust the eleven exported values against a real display. The starting values in Phase 2 are a place to begin and nothing more; the whole reason they are exported is that "ever so slightly" cannot be judged anywhere but here.

The specific judgements to make, in this order, because each changes how the next one reads:

1. **The sway's reach and sensitivity.** `maximum_sway_degrees` first, then `tilt_at_maximum_sway`. Three degrees may prove too timid on a tree this tall.
2. **The sway's weight.** `response_time_constant_seconds`. Too short and the tree twitches; too long and it feels disconnected from the wrist.
3. **The spin's rate.** `rotation_degrees_per_second`. The test is whether it reads as calming or as distracting when it is not being looked at directly.
4. **The halo's travel and neutral.** The two travel clamps, then `vertical_neutral_tilt`, held at a comfortable reading angle. The halo should be at or near its authored position in that pose.
5. **Whether the halo shimmers.** If it does, see "Where the noise floor works and where it does not" above; the remedy is a response time constant, and it is the developer's call.
6. **Whether the artwork and the weather agree.** The title screen already carries the snow, so this is the first time both answer the same tilt. Watch them together and judge whether they read as one response.

### Phase 5: Documentation

Add a short **The artwork behaviours** section to `README.md`, after **The snow**, modelled on it: what the three scripts are, that a sprite gains a behaviour by having a script added and its numbers set, that the sway carries no pivot because the scene sets it, and that the shared gravity reading lives in `app/phone_tilt.gd`.

Add a paragraph to §"Screen composition" in `docs/system_design.md`, where the two shared placement scripts are already described, naming this second family of shared artwork scripts and the rule that they attach to child sprites rather than to the roots `app/sprite_position.gd` owns.

Add one sentence to §"Platform notes" in `docs/system_design.md`, where the Android gravity-sign warning already lives, naming `app/phone_tilt.gd` and `snow/snow.gd` as the two live copies of the iOS-shaped mapping, so whoever measures an Android handset finds both.

## Test Cases

**No automated tests are created or changed by this plan.** This repository has no test framework, and §"Testing" in `docs/system_design.md` records that four consecutive features have declined to introduce one, on the grounds that the parts of this application most worth testing are the parts that only exist on a real device. That reasoning applies to this feature more completely than to any before it: every behaviour here except the spin is a function of a sensor that returns a zero vector in the editor, in the desktop build, and in the simulator.

There is accordingly no unit-test table. The verification table in §4 and the acceptance table at the end of this plan carry the whole burden, and the completion criteria depend on those manual checks rather than on a passing suite.

Two failure modes worth naming here, because each looks like something other than its cause:

- **A tree that spins rather than bends** is the script attached to the root `Node2D` instead of to the `Sprite2D`, or the scene's `offset` reverted. It looks like a maths error in the sway.
- **A halo pinned at the edge of its travel whenever the phone is held** is `vertical_neutral_tilt` left at zero. It looks like a clamp that is too small, and the instinct to widen the clamp makes it worse.

## README and Documentation Updates

Covered as Phase 5 above. In summary: one new **The artwork behaviours** section in `README.md`; one new paragraph in §"Screen composition" and one new sentence in §"Platform notes" in `docs/system_design.md`.

No new row is needed in either repository-structure table. This feature adds no directory.

Three pieces of knowledge introduced here are not evident from reading the code, and each is recorded as a comment where someone changing that behaviour will be looking: in `app/phone_tilt.gd`, why the neutral is passed in rather than the function returning zero when there is no reading; in `app/tilt_sway.gd`, why the script carries no pivot; and in `app/tilt_drift.gd`, why `vertical_neutral_tilt` exists at all and why there is no horizontal equivalent.

## Manual Verification Steps

Because there are no automated tests, these steps are the verification. The rows marked **handset** cannot be checked anywhere else, since there is no gravity sensor on the desktop.

| Behaviour under test | How to exercise it | Expected result |
|---|---|---|
| The scenes still load | Open `app/main.tscn` in the editor | It loads with no error. The tree, snowflake, and halo are exactly where they were, and nothing is rotated or displaced |
| The composition at rest is the authored one | Compare the running desktop build against the editor view | Identical. The tree stands upright and the halo sits where it was placed |
| **The tree bends rather than spins**, handset | Roll the phone left and watch the base of the trunk | The trunk foot stays put and the treetop swings. If the whole tree pivots about its middle and the base lifts off the bottom edge, the script is on the root node or the scene's `offset` was lost |
| The tree follows the roll, handset | Roll left, then right, then back to level | The tree leans the way the phone is rolled and returns to upright when it is levelled |
| The tree holds its lean, handset | Roll and hold that angle for ten seconds | The tree stays leaning. It does not creep back toward upright or drift further over |
| The lean is clamped, handset | Roll the phone all the way onto its side | The lean stops at the exported maximum. It does not keep going with the phone |
| The lean is smoothed, handset | Flick the phone quickly from one roll to the other | The tree takes about a third of a second to commit rather than snapping across |
| The tree ignores front-to-back tilt, handset | Tip the phone forward and back with no roll | The tree does not move |
| **The snowflake turns on the desktop** | Run the desktop build and watch the blue snowflake for a minute | It rotates slowly and continuously. This is the one behaviour the desktop can verify |
| The snowflake ignores the phone, handset | Roll, tip, and shake the phone | The snowflake keeps turning at exactly the same rate throughout, including while it is being shaken |
| The snowflake does not turn in the editor | Open `app/blue_snowflake.tscn` | It sits still. The script is not a `@tool` script |
| The halo slides sideways, handset | Roll the phone left and right | The halo slides horizontally and returns to centre when the roll is levelled |
| **The halo is near its authored spot at a normal hold**, handset | Hold the phone at a comfortable reading angle and look at the halo against the flake | It sits at or near where it was authored. If it is pinned at the bottom of its travel, `vertical_neutral_tilt` is wrong |
| The halo slides up and down, handset | From that hold, tip the phone toward upright, then back toward flat | The halo travels in one direction and then the other, reaching its clamp toward flat |
| The halo does not lag, handset | Move the phone and stop abruptly | The halo stops when the phone stops. It does not glide on |
| The halo does not shimmer, handset | Hold the phone as still as a hand can, at a normal reading angle, for fifteen seconds | The halo sits still. Visible jitter means adding a response time constant, per §"Where the noise floor works and where it does not" |
| A flat phone is steady, handset | Lay the phone face up on a table for fifteen seconds | Nothing jitters. The tree is upright and the halo is pinned steadily at its vertical clamp; the snowflake keeps turning |
| **No sensor means the rest pose** | Run the desktop build | The tree is upright and the halo is at its authored position, indefinitely. Neither drifts to a clamp |
| The clamps are honest, handset | Move the phone through every orientation you can while holding it | The halo never slides out from behind the flake far enough to look detached, and the tree never leans far enough to look broken |
| A bad divisor fails loudly | Set `tilt_at_maximum_drift` to 0 in the inspector and run | An error names the script, the node, the value, and the default. The halo sits at its authored position and nothing crashes or divides by zero |
| The buttons still work | Press "Tap to start", by finger on the device and by mouse on the desktop | It advances to the instructions screen exactly as before |
| The snow is unaffected | Watch the falling snow on the title screen while tilting, handset | It behaves exactly as it did before this feature |
| **Artwork and weather agree**, handset | Tilt slowly and watch the tree, the halo, and the snow together | They read as one response to one gesture rather than as separate effects |
| No other screen changed | Walk the instructions, bell selection, and play screens | Nothing on any of them moves that did not move before |
| The play screen still sounds bells, handset | Reach the play screen and shake | Bells sound exactly as before. The shake instrument is untouched |
| The tuning is reachable | Select each of the three sprites in the editor | All eleven exported values are visible in the inspector and editable without touching code |

## Coding Standards Compliance Checklist

The application coding standards document named in the skill's project instructions does not exist in this repository, as §"Where the governing documents live" in `docs/system_design.md` records. The following are the conventions this codebase actually demonstrates, and this plan conforms to each.

- Tab indentation in GDScript, matching `app/main.gd`, `app/sprite_position.gd`, and `snow/snow.gd`.
- A one-line comment at the top of each script naming the file, the feature it belongs to, and its role, followed by what a reader needs that the code cannot tell them. All four new scripts carry one.
- Static typing on declarations, parameters, and return types, including `-> void`, as every existing script does.
- `class_name` on a script another script refers to by type. `PhoneTilt` gets one; the three behaviour scripts are never referred to by type and do not.
- Script files named in lower snake case, matching every script in the repository.
- Exported values for anything art-directed, authored outside the code that consumes it, matching `app/sprite_position.gd`, `shake/shake_detector.gd`, and `snow/snow.gd`. Every constraint, rate, neutral, and floor in this feature is exported.
- Why a reasoned constant has the value it does, written where the constant is, matching `shake/shake_detector.gd` and `snow/snow.gd`. `vertical_neutral_tilt`, `noise_floor`, `tilt_at_maximum_sway`, and `response_time_constant_seconds` each carry their reason.
- Exported values used as divisors validated in `_ready()`, with a message naming the value, its permitted range, and the correct default. `tilt_at_maximum_sway`, `response_time_constant_seconds`, and `tilt_at_maximum_drift` are the three divisors and all three are checked.
- Derived output recomputed from its inputs rather than adjusted in place, so repeated recomputes never compound, matching `app/sprite_position.gd` and `app/safe_area_margin.gd`. All three behaviours capture a rest pose in `_ready()` and write rest-plus-offset every frame. `continuous_spin.gd` accumulates elapsed seconds rather than accumulating rotation for exactly this reason.
- **No fallbacks.** A bad divisor raises an error naming what is wrong and stops that node processing. Nothing substitutes a working-looking default and carries on. `PhoneTilt.read` returning the caller's neutral where there is no sensor is not a fallback: no reading is a real, expected state on three of the four places this application runs, and the neutral is the specified behaviour for it rather than a stand-in for a value that failed to arrive.

One convention is deliberately departed from and is named here rather than left to be found. `snow/snow.gd` contains its own copy of the gravity projection that `app/phone_tilt.gd` now also holds, so the repository carries the same six lines twice. Consolidating them would mean editing a working sensor path this feature has no other reason to touch. The two copies are named together in §"Platform notes" instead, so the Android sign correction finds both.

## File-Level Compliance Review

| File | Change |
|---|---|
| `app/phone_tilt.gd` | New. The gravity projection, the noise floor, and the no-reading rule, shared by both tilt behaviours |
| `app/tilt_sway.gd` | New. Leans a sprite with the side-to-side tilt, smoothed and clamped, about the sprite's own origin |
| `app/continuous_spin.gd` | New. Turns a sprite at a constant rate, reading no sensor |
| `app/tilt_drift.gd` | New. Slides a sprite from its authored position with the tilt, clamped independently per axis |
| `app/straight_red_tree.tscn` | `app/tilt_sway.gd` attached to the `StraightRedTree` `Sprite2D` child, with its exported defaults. The `offset` and `position` that place the pivot are untouched |
| `app/blue_snowflake.tscn` | `app/continuous_spin.gd` attached to the `BlueSnowflake` `Sprite2D` and `app/tilt_drift.gd` to the `GreenCircle` `Sprite2D`, each with its exported defaults. Nothing else altered |
| `README.md` | A **The artwork behaviours** section added after **The snow** |
| `docs/system_design.md` | One paragraph added to §"Screen composition"; one sentence added to §"Platform notes" naming the two copies of the gravity mapping |
| `app/main.tscn` | **Unchanged.** It instances both artwork scenes, so the behaviours and their values arrive through those instances |
| `app/instructions.tscn`, `app/instrument_select.tscn`, `app/instrument.tscn` | Unchanged. Neither artwork scene is instanced on any of them |
| `app/sprite_position.gd`, `app/safe_area_margin.gd` | Unchanged. The behaviours attach to child sprites, which neither script touches |
| `snow/snow.gd`, `snow/snow_layer.gd`, `snow/snow.tscn` | Unchanged. The duplicate gravity mapping is left in place deliberately |
| Everything under `shake/`, `capture/`, `shaders/`, and `legacy/` | Unchanged |
| `images/` and `sounds/` | Unchanged. No asset is added, altered, or archived |
| `project.godot` | Unchanged. The gravity sensor is already enabled and none of these scripts is an autoload |

No background, vignette, logo, button, layout, screen, or asset is touched.

## Completion Criteria

1. `app/phone_tilt.gd`, `app/tilt_sway.gd`, `app/continuous_spin.gd`, and `app/tilt_drift.gd` exist in `app/`, and no other new file is added.
2. The tree leans in the direction the phone is rolled, smoothed, clamped to the exported maximum, and holds its lean while the roll is held.
3. The tree rotates about its `Sprite2D`'s own origin, and neither `app/tilt_sway.gd` nor any other script in this feature contains a pivot value.
4. The blue snowflake turns at a constant rate on both the handset and the desktop, unchanged by tilt or shake, and does not turn in the editor.
5. The green halo slides on both axes with the tilt, clamped independently, directly rather than laggingly, and returns to its authored position at the exported vertical neutral.
6. Holding the phone at a normal reading angle puts the halo at or near its authored position, not pinned at a clamp.
7. All eleven exported values are adjustable from the inspector, and the three divisors raise a named error and stop their node rather than dividing by zero.
8. The desktop build, which has no gravity sensor, shows the tree upright and the halo at its authored position indefinitely, while the snowflake still turns.
9. `app/main.tscn` is not edited, and the behaviours reach the title screen through the two artwork scenes it instances.
10. The instructions, bell selection, and play screens are unchanged and carry none of these behaviours.
11. The snow, the vignette, the shake instrument, and the "Tap to start" button all behave exactly as they did before.
12. `README.md` and `docs/system_design.md` carry the additions listed in Phase 5.
13. Every row in the §4 verification table passes, including the handset rows.

## Token and Design Considerations

This feature builds no skill, so there is no `input_limits` value to set, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed. This feature applies the sensor-reading and exported-tunable patterns `snow/snow.gd` already demonstrates and the derived-output pattern `app/sprite_position.gd` already demonstrates, and adds no capability the tutor covers.

## Acceptance Table

This replaces the unit-test table, for the reason given in §2. Every row is verified by hand, and the rows marked handset cannot be checked anywhere else.

| Behaviour under test | Concrete input | Expected result |
|---|---|---|
| Tilt reading, no sensor | `PhoneTilt.read(Vector2(0.0, 0.75), 0.05)` with `Input.get_gravity()` returning a zero vector, which is the desktop build | Returns `(0.0, 0.75)`, the neutral passed in, so the caller's deviation is exactly zero |
| Tilt reading, phone upright, handset | Phone held with the screen vertical | Returns approximately `(0.0, 1.0)` |
| Tilt reading, phone flat, handset | Phone lying face up on a table | Returns `(0.0, 0.0)`, the in-plane length having fallen below the 0.05 floor |
| Tilt reading, phone rolled left, handset | Phone rolled roughly 30 degrees to the left | Returns approximately `(-0.5, 0.87)` |
| Sway at rest | Desktop build, tree at its authored rotation of 0 | Rotation stays 0 indefinitely |
| Sway at half sensitivity | Tilt reading `x = 0.25`, defaults of 3.0 degrees and 0.5 | Settles at 1.5 degrees of lean, half the maximum |
| Sway clamped | Tilt reading `x = 0.9`, defaults of 3.0 degrees and 0.5 | Settles at exactly 3.0 degrees, not 5.4 |
| Sway ignores the vertical | Tilt reading `(0.0, 1.0)` | Rotation stays at the rest pose. Only the `x` component is read |
| Sway smoothing | A step change in `x` from 0 to 0.5 | Reaches roughly 63 percent of the new lean after 0.35 seconds, the exported time constant |
| Sway bad divisor | `tilt_at_maximum_sway` set to 0 | An error names `tilt_sway.gd`, the node, the value 0, and the default 0.5. The node stops processing and the tree stays at its rest rotation |
| Spin rate | Desktop build, default 6.0 degrees per second, observed over 60 seconds | The snowflake completes one full turn |
| Spin direction | `rotation_degrees_per_second` set to -6.0 | It turns the other way at the same rate |
| Spin ignores everything | Handset, phone rolled, tipped, and shaken hard | The rate does not change at any point |
| Drift at the neutral pose | Tilt reading `(0.0, 0.75)`, `vertical_neutral_tilt` at its default 0.75 | Position is exactly the authored `(317.125, -288.0868)` |
| Drift horizontal, half travel | Tilt reading `(0.25, 0.75)`, defaults of 40 pixels and 0.5 | Position is the authored one plus `(20.0, 0.0)` |
| Drift horizontal clamped | Tilt reading `(0.9, 0.75)` | Position is the authored one plus `(40.0, 0.0)`, not `(72.0, 0.0)` |
| Drift vertical, phone upright | Tilt reading `(0.0, 1.0)`, defaults of 28 pixels and 0.5 | Position is the authored one plus `(0.0, 14.0)` — half travel, in one direction |
| Drift vertical, phone flat | Tilt reading `(0.0, 0.0)` | Position is the authored one plus `(0.0, -28.0)` — the clamp, in the other direction. Both directions are real |
| Drift, no sensor | Desktop build | Position is exactly the authored one, indefinitely. It does not sit at the vertical clamp |
| Drift bad divisor | `tilt_at_maximum_drift` set to 0 | An error names `tilt_drift.gd`, the node, the value 0, and the default 0.5. The node stops processing and the halo stays at its authored position |
| Rest pose is not overwritten | Change the tree `Sprite2D`'s authored rotation to 2 degrees in the inspector and run | It sways about 2 degrees rather than about 0. The authored value is the rest pose, not a value the script consumes |
| The root nodes are untouched | Inspect `app/straight_red_tree.tscn` and `app/blue_snowflake.tscn` after a run | Neither root `Node2D` has a stored `position`, exactly as `app/sprite_position.gd` requires. No behaviour script is attached to either root |
| The title screen is not edited | `git diff app/main.tscn` after the build | No change |
| The flow is unchanged | Walk title to instructions to bell selection to play, handset | Every screen behaves exactly as it did before this feature, and the play screen still sounds the chosen bell on a shake |
