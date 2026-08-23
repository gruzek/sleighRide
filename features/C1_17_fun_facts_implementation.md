---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for A Fun Fact Winnie Tells While You Choose Your Bells
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: One scene, one script, and one line added to a screen — with the two things nobody would guess, the pivot hidden inside the artwork's own path data and the character budget the bubble's size imposes on the copy, worked out here rather than discovered on the device.
LAST UPDATED: August, 23, 2026 10:07
---

# Implementation Plan for A Fun Fact Winnie Tells While You Choose Your Bells

This plan implements the Fun Facts Bubble feature (C1_17). It adds one scene and one script to `app/`, imports the supplied bubble artwork already placed in `images/v2/`, and adds one node to `app/instrument_select.tscn`. No other screen is edited, no autoload is registered, no existing script is changed, and `project.godot` is untouched.

## Design decisions carried in from the specification and planning conversations

- **The facts are one exported list of text on the bubble scene.** One global pool; no fact belongs to a bell, so `app/instrument_definition.gd` and the three resources in `app/instruments/` are untouched.
- **A shuffle bag held in a static variable, written nowhere.** Every fact is shown once before any repeats; when the bag empties the pool is reshuffled into it. It is not an autoload and it does not touch the disk.
- **One fact per entry to the screen.** Drawn when the node is ready and held until the screen is left.
- **The bubble rests at scale 1.35, giving a fact budget of roughly 90 characters.** Settled in planning: at the design's own size the budget is about 50 characters, which is a fortune cookie rather than a fun fact.
- **The entrance pops the whole bubble; the pulse breathes the shape alone.** Settled in planning. There is nothing to read while the bubble is arriving, so the entrance carries the text with it. Once the fact is legible, the text holds still and only the white shape keeps the beat, because a 5 percent wobble resamples the glyphs on the one thing on this screen a person is actually reading.
- **The rhythm is the title's rhythm, reusing its numbers.** A beat of 0.75 seconds, a loop of eight beats, an entrance overshoot of 1.12, and a pulse peak of 1.05, all from `app/holiday_sleigh_bells.gd`.
- **The typeface is the engine's default, set in one overridable place.** One exported `Font` property that both labels take from. When it is unset, nothing is applied and the default face is used, which is the state the specification's requirement 6 describes.
- **The bubble is inert.** Both labels ignore input, so a swipe that starts on the bubble reaches the carousel underneath it.

## Where the pivot is, and how it was found

The pop scales from the tip of the tail, and the tip is not a value anybody can eyeball off a rendered image accurately enough to matter. It is read out of the supplied artwork's own path data.

`images/v2/thought_bubble.svg` declares `viewBox="0, 0, 428, 407.733"` and wraps its two paths in a group carrying `transform="translate(-170.333, -408.356)"`. Every coordinate in the path is therefore offset by that translation to give a position inside the texture. The tail is the stretch of the path running from `263.833,799.856` through the curve controlled by `248.168,815.882` and `201.833,820.858` to `200.5,809.19`, and its outermost point — the corner that touches Winnie's mouth — resolves to texture coordinates of approximately **(30, 402)**.

That is placed on the node's origin by setting `centered = false` and `offset = Vector2(-30, -402)` on the `Sprite2D`. Godot applies `offset` in the sprite's own local space before the node's scale, so the tail tip lands exactly on the origin at any scale, and both the entrance and the pulse grow the bubble away from a point that does not move.

The value is a starting point in the same sense the tree's pivot was in the Artwork That Answers the Tilt of the Phone feature (C1_15): it is set in the scene by `centered` and `offset`, so nudging it by eye against Winnie's actual mouth is a scene edit with no code behind it.

## Why the bubble sprite and the labels are scaled separately

Two different things scale, at two different times, and keeping them on separate nodes is what makes that possible without a special case in the animation.

The scene's root is a `Node2D` carrying a script that extends `app/sprite_position.gd`, exactly as `app/holiday_sleigh_bells.gd` and `app/instrument_carousel.gd` do, and for the same reason: the bell selection screen places this scene through that script's exported properties, and a node holds only one script. `sprite_position.gd` owns the root's `position` and strips it from storage, but it does not touch `scale`, so the root's scale is free for the entrance to animate.

- **The root scales for the entrance**, from zero to 1.12 and back to 1.0, carrying the sprite and both labels with it.
- **The `Sprite2D` carries the resting size of 1.35 and scales for the pulse**, from 1.35 to 1.4175 and back, alone.

Because the sprite's origin is the tail tip and the root's origin is the same point, both motions grow from the same place and neither disturbs where the labels sit.

## The interior geometry, in root-local pixels

The labels are positioned against the scaled bubble, so their rectangles are worked out once here rather than nudged into place by trial.

A text-safe rectangle inside the blob and clear of the tail runs from texture (50, 55) to (378, 300). Converting to root-local coordinates — subtract the pivot at (30, 402), multiply by the resting scale of 1.35 — gives a box from **(27, -468) to (470, -138)**, which is 443 wide and 330 tall. The header takes the top of it and the fact takes the rest:

| Node | Rect in root-local pixels | Notes |
|---|---|---|
| `Header` | position (27, -455), size (443, 70) | "DID YOU KNOW?" at a fixed 44 pixels, centred |
| `Fact` | position (27, -375), size (443, 230) | Word-wrapped and centred, 40 pixels shrinking to a floor of 26 |

At 40 pixels in a 443-wide box the fact runs to roughly 22 characters a line over 4 lines, which is the 90-character budget the resting scale was chosen for.

## The header's wording

The specification's requirement 1 gives the header as "Did you know?" and the design draws it as "DID YOU KNOW?" in capitals. The design governs the rendering and the header is exported as a string defaulting to `"DID YOU KNOW?"`, so the two are reconciled without either being contradicted and the wording can be changed without touching the scene.

## Implementation Steps and Phases

### Phase 1: Import the artwork

`images/v2/thought_bubble.svg` is already in place. Opening the project in the editor imports it and writes `images/v2/thought_bubble.svg.import` beside it, at the default `svg/scale=1.0`, producing a 428 by 408 texture. That default is correct here and is not changed: unlike the other artwork in `images/v2/`, which is exported at half size and instanced at `scale = Vector2(2, 2)`, this file is exported at very nearly its final size.

Two properties of the supplied file are used exactly as they are. It carries a second path with `fill-opacity="0"` and `stroke-width="1"` over the white fill, so the bubble renders with a hairline dark outline. Its group is named `BlueSnowflake`, which is a leftover from whatever it was copied from and has no effect on the rasterized texture.

### Phase 2: The bubble script

New file, `app/fun_fact_bubble.gd`.

```gdscript
# fun_fact_bubble.gd (C1_17 fun facts) - Winnie's speech bubble, and the fact inside it.
#
# One fact is drawn when the screen is entered and held until the screen is left. Facts come
# from a shuffle bag rather than a random pick, because the play screen's Back button rebuilds
# this screen from nothing and somebody trying all three bells passes through it three times in
# under a minute. Independent draws from a small pool repeat inside that, and a repeat reads as
# the application having very little to say rather than as chance.
#
# The bag is a static variable. It survives the scene change that destroys this node, for as
# long as the application is running, and it is written nowhere. An autoload would do the same
# job and is deliberately not used: there are two in this application and each is needed by more
# than one screen, which a bag belonging to one node on one screen is not.
#
# The entrance scales this node and carries the text with it; the pulse scales the bubble sprite
# alone. There is nothing to read while the bubble is arriving, but once the fact is legible a
# five percent wobble resamples the glyphs on the one thing on this screen anybody is reading.
#
# This extends sprite_position.gd rather than replacing it because the bell selection screen
# places this scene through that script's exported properties, and a node holds only one script.
# The title animation and the bell carousel both met the same collision and resolved it the
# same way.
@tool
extends "res://app/sprite_position.gd"

# Unticked, the bubble sits at its authored size showing whatever the scene holds, and nothing
# moves. This is the scene exactly as it renders in the editor.
@export var animate: bool = true

# The pool. Any length; adding a fact is adding an entry. An empty pool hides the bubble at
# runtime, because a heading over an empty white shape is worse than no bubble at all.
@export_multiline var facts: Array[String] = []

@export_group("Text")
@export var header_text: String = "DID YOU KNOW?"
# The one place the typeface is set. Both labels take it from here, so the brand face arriving
# later is this one property. Unset, nothing is applied and the engine's default face is used,
# which is the state the feature specification's requirement 6 describes rather than a fallback.
@export var typeface: Font = null
@export var header_font_size: int = 44
# The fact starts here and is stepped down until it fits the label's box.
@export var fact_font_size: int = 40
# and never below here, because text too small to read in a darkened hall has failed its only job.
@export var minimum_fact_font_size: int = 26

@export_group("Rhythm")
# Stillness after the screen appears, so the bubble does not arrive on top of the carousel
# building itself. One beat.
@export var initial_delay_seconds: float = 0.75
# One quarter note, from the title animation. 0.75 seconds is 80 beats per minute.
@export var beat_seconds: float = 0.75
# The repeating unit, in beats. Two bars of 4/4, matching the title.
@export var loop_beats: int = 8

@export_group("Entrance")
# How far past its resting size the bubble carries before coming back, as a multiple of it.
@export var entrance_overshoot: float = 1.12
@export var entrance_grow_seconds: float = 0.12
@export var entrance_settle_seconds: float = 0.18

@export_group("Pulse")
# The peak, not a value passed through: the pulse has no overshoot to correct.
@export var pulse_peak: float = 1.05
@export var pulse_grow_seconds: float = 0.12
@export var pulse_return_seconds: float = 0.20

# Shuffled facts not yet shown, newest draw taken from the end. Static, so it outlives this node
# and every scene change, and is refilled from the pool when it empties.
static var _bag: Array[String] = []

var _bubble: Sprite2D = null
var _header: Label = null
var _fact: Label = null
var _bubble_resting_scale: Vector2 = Vector2.ONE
```

`_ready` runs `super()` first, so the placement script positions the root in the editor as well as at runtime, then stops in the editor. The bubble must stay visible and at its authored size while a screen is being composed, so nothing after the editor check runs there — no fact is drawn, the pool is not consulted, and the bubble is not hidden when the pool is empty.

```gdscript
func _ready() -> void:
	super()
	if Engine.is_editor_hint() or not animate:
		return
	if not _collect_nodes():
		return
	if not _validate_exports():
		return
	_bubble_resting_scale = _bubble.scale
	_apply_typeface()
	_header.text = header_text
	if facts.is_empty():
		visible = false
		return
	_fact.text = _draw_fact()
	_fit_fact()
	# Before the first frame is drawn, not when the delay expires. A bubble left at its authored
	# scale for even one frame is a flash of the finished thing before the entrance collapses it.
	scale = Vector2.ZERO
	_conduct()
```

`_collect_nodes` reaches the three children by name and fails with a message naming the missing one, as the repository's convention for a scene-path dependency requires. `_validate_exports` checks the four values used as a divisor, a bound, or a loop count — `beat_seconds` above zero, `loop_beats` at least one, `minimum_fact_font_size` at least one, and `fact_font_size` not below it — each with a message naming the value, its permitted range, and the correct default, and each stopping the node rather than substituting anything.

The bag is the whole of requirement 3:

```gdscript
# Refilled and reshuffled when it empties, so every fact is shown once before any is repeated.
# It refills from the pool as it stands at that moment, so editing the facts takes effect at the
# next refill rather than being remembered from a previous shuffle.
static func _draw_fact_from(pool: Array[String]) -> String:
	if _bag.is_empty():
		_bag = pool.duplicate()
		_bag.shuffle()
	return _bag.pop_back()
```

The shrink-to-fit steps the font size down until the wrapped text fits the label's authored box, and stops at the floor:

```gdscript
# Label has no fit-to-box mode, so the size is found by measuring. The label's box is authored in
# the scene, so moving the text around is a scene edit and the arithmetic here does not change.
func _fit_fact() -> void:
	var font := _fact.get_theme_font("font")
	var box := _fact.size
	for size in range(fact_font_size, minimum_fact_font_size - 1, -1):
		var needed := font.get_multiline_string_size(
			_fact.text, HORIZONTAL_ALIGNMENT_CENTER, box.x, size)
		if needed.y <= box.y:
			_fact.add_theme_font_size_override("font_size", size)
			return
	_fact.add_theme_font_size_override("font_size", minimum_fact_font_size)
	push_error("fun_fact_bubble: a fact does not fit the bubble at the %d-pixel floor and is clipped. Shorten it, or raise `minimum_fact_font_size` knowing it becomes harder to read. The fact is: %s" % [minimum_fact_font_size, _fact.text])
```

The animation is the title's, with two tweens that only schedule. The opening plays the delay and the entrance and hands over to the pulse, which repeats for as long as the screen is up. Both are bound to this node and are killed with it, so a scene change needs no cleanup.

```gdscript
func _conduct() -> void:
	var opening := create_tween()
	opening.tween_interval(initial_delay_seconds)
	opening.tween_property(self, "scale", Vector2.ONE * entrance_overshoot, entrance_grow_seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	opening.tween_property(self, "scale", Vector2.ONE, entrance_settle_seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	opening.tween_interval(_loop_seconds() - entrance_grow_seconds - entrance_settle_seconds)
	opening.tween_callback(_start_pulsing)

# The shape alone. _bubble is the Sprite2D, whose origin is also the tail tip, so the pulse and
# the entrance grow from the same point and the labels are left where they are.
func _start_pulsing() -> void:
	var pulsing := create_tween().set_loops()
	pulsing.tween_property(_bubble, "scale", _bubble_resting_scale * pulse_peak, pulse_grow_seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulsing.tween_property(_bubble, "scale", _bubble_resting_scale, pulse_return_seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pulsing.tween_interval(_loop_seconds() - pulse_grow_seconds - pulse_return_seconds)

func _loop_seconds() -> float:
	return beat_seconds * float(loop_beats)
```

`_apply_typeface` applies the exported font to both labels when one is set, and does nothing when it is not.

### Phase 3: The bubble scene

New file, `app/fun_fact_bubble.tscn`. Four nodes.

| Node | Type | Properties |
|---|---|---|
| `FunFactBubble` | `Node2D` | `app/fun_fact_bubble.gd` |
| `Bubble` | `Sprite2D` | texture `images/v2/thought_bubble.svg`, `centered = false`, `offset = Vector2(-30, -402)`, `scale = Vector2(1.35, 1.35)` |
| `Header` | `Label` | position (27, -455), size (443, 70), centred both ways, `mouse_filter = MOUSE_FILTER_IGNORE`, black text |
| `Fact` | `Label` | position (27, -375), size (443, 230), centred both ways, `autowrap_mode = AUTOWRAP_WORD_SMART`, `mouse_filter = MOUSE_FILTER_IGNORE`, black text |

Both labels are set to ignore mouse and touch input in the scene rather than in code, because that is where the property lives and because getting it wrong produces a dead zone in the carousel's drag band that is invisible on a desktop and only shows up under a thumb.

The `Fact` label is authored with a placeholder line of about ninety characters, so the composition can be judged in the editor at the length the copy is actually written to. It is overwritten at runtime on the first frame.

### Phase 4: Add the bubble to the bell selection screen

`app/instrument_select.tscn` gains one instance of `app/fun_fact_bubble.tscn`, inserted immediately after `Winnie` so it draws over her, with:

```
design_position = Vector2(396, 1667)
vertical_anchor = 2
```

The vertical anchor is `BOTTOM`, matching Winnie, so the bubble stays with her rather than with the top of the screen as the canvas grows taller on a longer phone. The position places the tail tip 396 pixels from the left and 253 above the bottom of the design canvas, derived from the design mockup, and is a starting point to be dragged onto Winnie's mouth in the editor by editing `design_position`.

Nothing else in the file changes. `app/instrument_select.gd` is untouched, because a bubble that draws its own fact needs nothing from the screen that hosts it.

### Phase 5: Seed the pool and tune on the handset

The facts are supplied by George and typed into the `facts` list in the editor. Everything else in this phase is done on a handset, because it is where the judgements are:

- Drag `design_position` until the tail tip meets Winnie's mouth.
- Confirm the resting scale of 1.35 reads well against the bells above it, and adjust if the bubble crowds them.
- Confirm the longest supplied fact fits above the shrink floor, and shorten it if the error in `_fit_fact` fires.
- Confirm the pulse reads as a heartbeat rather than as a distraction next to three bells being swiped.

### Phase 6: Documentation

`README.md` gains a short section on the bubble, and `docs/system_design.md` gains the bubble to its account of the bell selection screen. The specifics are in §3 below.

## Test Cases

**No automated tests are created or changed by this plan.** This repository has no test framework, and §"Testing" in `docs/system_design.md` records that consecutive features have declined to introduce one on the grounds that the parts of this application most worth testing are the parts that only exist on a real device.

That reasoning is weaker for this feature than for most — the shuffle bag and the shrink-to-fit measurement are both ordinary functions that would test perfectly well on a desktop — and it is worth saying so plainly rather than inheriting the decision silently. It is nonetheless followed here, because introducing a framework is a change to the repository's shape that belongs to a feature about testing rather than to a feature about a speech bubble. The two functions that would benefit are written as small, self-contained pieces so that a later feature which does introduce a framework can reach them without restructuring anything.

There is accordingly no unit-test table. The verification table in §4 and the acceptance table at the end of this plan carry the whole burden.

Three failure modes worth naming here, because each looks like something other than its cause:

- **A bubble that swells from the middle of the screen** is `centered` left at its default `true`, or the `offset` lost. It looks like an animation error and it is a scene property.
- **A carousel that ignores a swipe started on the bubble** is a label left at its default `mouse_filter`. It is invisible on a desktop, where the pointer is precise and nobody drags from the middle of the text.
- **Every fact rendering at the floor size** is the label's box being read before layout has given it one, so `_fact.size` is near zero and no size ever fits. It looks like facts that are all too long.

## README and Documentation Updates

**`README.md`** gains a short section after "The artwork behaviours" covering the bubble: that the fact pool is an exported list on `app/fun_fact_bubble.tscn`, that facts are drawn from a shuffle bag in a static variable so nothing repeats until all have been shown and nothing is written to disk, that the entrance scales the whole node and the pulse scales the sprite alone, and that the pivot is the tail tip set by `centered` and `offset` in the scene rather than by any value in the script.

**`docs/system_design.md`** gains the bubble in two places: §"The audience flow" notes that the bell selection screen carries it, and §"Screen composition" gains it to the list of small scenes screens are assembled from. The §"Where the governing documents live" and §"Conventions" sections are untouched.

Neither document gains a claim about testing, and §"Testing" is not edited.

## Manual Verification Steps

Everything here is done on a handset unless marked otherwise. The editor and desktop checks are worth doing first because they are fast and they catch the scene-property mistakes.

1. **Editor.** Open `app/fun_fact_bubble.tscn`. The bubble is visible at its authored size, showing the placeholder fact. Nothing moves.
2. **Editor.** Open `app/instrument_select.tscn`. The bubble sits above Winnie with its tail at her mouth, clear of the bells and the Continue button.
3. **Desktop build.** Run the flow to the bell selection screen. The bubble is absent for the first three quarters of a second, then grows from Winnie's mouth, overshoots slightly, and settles. A fact is legible.
4. **Desktop build.** Watch for twenty seconds. The white shape breathes once every six seconds. The text does not change size and does not move.
5. **Desktop build.** Drag across the bubble. The bells move exactly as they do when the drag starts anywhere else.
6. **Desktop build.** Continue to the play screen, then Back, six times in a row with a pool of five facts. Five different facts appear before any repeats, then a sixth appears from a fresh shuffle.
7. **Desktop build.** Empty the `facts` list and run. No bubble appears, no error is printed, and the rest of the screen is unaffected.
8. **Desktop build.** Set `beat_seconds` to 0 and run. An error names the value, its permitted range, and the default, and the bubble does not animate.
9. **Desktop build.** Add a fact of about two hundred characters. It renders smaller than the others and an error names it as not fitting at the floor.
10. **Handset.** The fact is readable at arm's length in a dark room. This is the check the shrink floor exists for and it cannot be made anywhere else.
11. **Handset.** Tilt and shake the phone. The snow responds, the bubble does not move relative to Winnie, and the bells still swipe.
12. **Handset.** Confirm the tail meets Winnie's mouth on a real screen rather than on the design canvas, and that the bubble clears the home indicator and the Continue button.

## Coding Standards Compliance Checklist

There is no application coding standards document for this repository; §"Conventions" in `docs/system_design.md` is what a review here audits against, and each item below is one of those conventions.

- Tab indentation in GDScript.
- A one-line comment at the top of the script naming the file and its role, followed by what a reader needs that the code cannot tell them.
- Static typing on every declaration and return type, including `-> void`.
- No signals are connected by this feature. Nothing is connected in a scene file.
- Scene and script files named in lower snake case: `fun_fact_bubble.gd`, `fun_fact_bubble.tscn`.
- Exported values used as divisors, bounds, or loop counts are validated in `_ready()`, with a message naming the value, its permitted range, and the correct default: `beat_seconds`, `loop_beats`, `fact_font_size`, and `minimum_fact_font_size`.
- The three child nodes are reached by scene path and validated in `_ready()`, so a rename surfaces at load rather than inside the animation.
- **No fallbacks.** A missing child, a bad export, or a fact that will not fit produces an error naming what is wrong. The hidden bubble on an empty pool is not a fallback: nothing is substituted and nothing carries on pretending, the feature has no content and presents none, which is the specification's requirement 2.

## File-Level Compliance Review

| File | Change | Review points |
|---|---|---|
| `images/v2/thought_bubble.svg` | Supplied, imported | Import at the default `svg/scale=1.0`. The file is not edited, including its leftover `BlueSnowflake` group name and its hairline stroke |
| `app/fun_fact_bubble.gd` | New | Extends `app/sprite_position.gd` and calls `super()` first. `@tool`, and stops after the editor check so the composition stays authorable. The static bag is the only state that outlives the node |
| `app/fun_fact_bubble.tscn` | New | `centered = false` and `offset = Vector2(-30, -402)` on the sprite are load-bearing. Both labels ignore input |
| `app/instrument_select.tscn` | One node added | Inserted after `Winnie`. `design_position` and `vertical_anchor` only. No other node in the file is touched |
| `README.md` | Section added | Placed after "The artwork behaviours" |
| `docs/system_design.md` | Two mentions added | §"The audience flow" and §"Screen composition". Nothing else edited |

## Completion Criteria

1. The project opens with no import errors and no script errors, and `images/v2/thought_bubble.svg.import` exists.
2. `run/main_scene` in `project.godot` still points at the title screen.
3. All twelve manual verification steps in §4 pass, including the four that require a handset.
4. Every row of the acceptance table passes.
5. `facts` is populated with the supplied copy, and every entry fits above the shrink floor.
6. `README.md` and `docs/system_design.md` carry the updates in §3.
7. No file outside the six in §6 is modified.

## Token and Design Considerations

This feature builds no skill. There is no `input_limits` value to declare, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed, and no entry is added to the tutor's `references/topics.md`. This feature composes patterns the repository already demonstrates: the artwork scene placed by `app/sprite_position.gd`, the exported-tunable convention, and the tween-driven entrance and pulse of the Title Words That Arrive on the Beat feature (C1_14).

## Acceptance Table

This replaces the unit-test table, for the reason given in §2. Every row is verified by hand, and the rows marked handset cannot be checked anywhere else.

| Behaviour under test | Concrete input | Expected result |
|---|---|---|
| Pivot placement | `Bubble` with `centered = false`, `offset = Vector2(-30, -402)` | The tail tip sits exactly on the node origin. Setting the root's scale to 0.1 shrinks the bubble toward the tail, not toward its middle |
| Entrance shape | Desktop build, defaults | Nothing for 0.75 seconds, then zero to 1.12 over 0.12 seconds, then to 1.0 over 0.18 seconds |
| Entrance carries the text | Desktop build, defaults | The header and the fact grow with the bubble and are legible from the moment it settles |
| Pulse shape | Desktop build, defaults | The sprite goes 1.35 to 1.4175 to 1.35, once every 6.0 seconds, indefinitely |
| Pulse leaves the text alone | Desktop build, watched for one minute | Neither label changes size or position at any point |
| Pulse timing matches the title | `beat_seconds` 0.75 and `loop_beats` 8 on both scenes | Both loops are 6.0 seconds |
| Bag exhausts before repeating | Pool of 5 facts, screen entered 5 times | 5 distinct facts, no repeat |
| Bag refills | The same pool, screen entered a 6th time | A fact appears, drawn from a fresh shuffle of all 5 |
| Bag survives the scene change | Enter, Continue, Back | The second entry draws the next fact from the same bag rather than starting over |
| Bag writes nothing | Any number of entries | No file appears under `user://`, and nothing is added to the autoload list |
| Bag picks up an edited pool | Drain the bag, add a 6th fact, enter again | The refill contains all 6 |
| One fact per visit | Enter and wait two minutes | The fact does not change |
| Empty pool | `facts` set to `[]` | The bubble is not visible. No error is printed. The rest of the screen is unaffected |
| Empty pool in the editor | `facts` set to `[]`, scene open in the editor | The bubble is still visible with its placeholder, so the composition can be authored |
| Header wording | `header_text` at its default | Renders "DID YOU KNOW?" |
| Fact that fits | A 60-character fact, defaults | Renders at the full 40 pixels |
| Fact that must shrink | A 140-character fact, defaults | Renders at the largest size between 40 and 26 whose wrapped height fits 230 pixels |
| Fact that cannot fit | A 400-character fact, defaults | Renders at 26 and an error names the floor and quotes the fact |
| Typeface unset | `typeface` left null | Both labels render on the engine's default face. No error |
| Typeface set | Any `Font` assigned to `typeface` | Both labels render in it. It is the only property changed |
| Bad beat | `beat_seconds` set to 0 | An error names `fun_fact_bubble.gd`, the value 0, the permitted range, and the default 0.75. The bubble does not animate |
| Bad loop | `loop_beats` set to 0 | An error names the value, the range, and the default 8. The bubble does not animate |
| Bad font floor | `minimum_fact_font_size` set above `fact_font_size` | An error names both values and the defaults. The bubble does not animate |
| Missing child | `Fact` renamed in the scene | An error names the missing node and the three the bubble needs. Nothing else on the screen is affected |
| Swipe passes through | Drag begun on the middle of the fact text | The carousel moves exactly as it does from a drag begun elsewhere |
| No dismissal | Tap the bubble | Nothing happens. The bubble stays and the fact does not change |
| Draw order | Bubble instanced after `Winnie` | The bubble draws over Winnie and under the near snow layer |
| Anchoring, handset | A phone taller than the design canvas | The bubble stays with Winnie at the bottom rather than drifting up with the top of the canvas |
| Readability, handset | The longest supplied fact, dark room, arm's length | Legible |
| No regression, handset | Shake the phone on the bell selection screen | The snow responds as before and the bubble is unaffected |
