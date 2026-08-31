---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for The Real Bells You Hear, and the Real Bells You See
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Two scripts, one new scene, and a careful retirement — with the three things nobody would guess, the draw that cannot spin, the pair geometry the two artworks already half-arrange for you, and the bundle cost that is a fifth of what the specification assumed, worked out here rather than discovered on the device.
LAST UPDATED: August, 31, 2026 12:20
---

# Implementation Plan for The Real Bells You Hear, and the Real Bells You See

This plan implements the Recorded Bell Samples feature (C1_18). It rewrites `app/instrument_definition.gd` and `shake/responses/jingle_response.gd`, adds one scene and one resource to `app/`, edits the two surviving instrument resources and `app/instrument_carousel.tscn`, and retires the green shaker and the five placeholder recordings to `legacy/`. No screen scene is edited, no autoload is registered, the detector is untouched, and `project.godot` is untouched.

## Design decisions carried in from the specification and planning conversations

- **Two banks on the bell, not an array indexed by level.** `piano_samples` and `forte_samples`, each an `Array[AudioStream]` of any length. The single `sound` property is removed rather than kept alongside them.
- **Levels 1 and 2 draw piano, levels 3 to 5 draw forte.** The boundary is one exported integer, `piano_top_level`, defaulting to 2.
- **An empty forte bank means the bell sounds its piano bank at every level.** This is how the strap bells are configured, and it is not a fallback: the bell has one bank because one bank was recorded.
- **The loudness ramp is unchanged.** Negative twenty-four to zero decibels across `ShakeEvent.intensity`, applied on top of whichever recording was drawn.
- **Never the same recording twice in a row**, carried on the responder as one field holding the last stream played.
- **The paddle bells are Type A, the strap bells are Type B, the pair is Type C.** Settled in ideation on 2026-08-31.
- **The pair is a scene instancing the two bell scenes**, not a scene referring to their two textures, so a later change to either instrument flows into the pair without editing it.
- **The pair is authored to about the footprint of one bell.** Settled in ideation as option (a): overlap and a modest scale on the pair as a whole, so neither the carousel nor the play screen needs a special case.
- **The green shaker and the five placeholder recordings move to `legacy/`, never deleted**, per §"The hard rule about assets" in `docs/system_design.md`.

## Why the exported stream becomes a one-entry bank

The responder serves two callers. The play screen sets `use_chosen_bell` and reads the bell from `InstrumentSelection`; the capture harness leaves it unticked and uses the exported `stream`. Written naively, the new code carries that split all the way down and needs a branch at every step: one shape that draws from banks, another that plays the one stream it has.

It does not have to. The exported stream resolves into a **one-entry piano bank with an empty forte bank**, and from that point there is one code path. Requirement 3's empty-forte rule sounds it at every level. Requirement 4's single-entry guard lets it repeat, which is the only thing a bank of one can do. Requirement 6's pool sizing takes the longest of a list of one. The harness behaves exactly as it does today, and no function below `_resolve_banks()` knows there were ever two cases.

This is worth stating because the alternative is the kind of branch that looks harmless when it is written and is the reason a later change breaks the harness that nobody runs between features.

## Why the draw cannot spin

The obvious way to write "random, but not the one that just played" is to draw and retry:

```
var pick := bank[randi() % bank.size()]
while pick == _last_played:
	pick = bank[randi() % bank.size()]
```

That loop is correct only while the bank holds at least two *distinct* streams. An exported array is edited by hand in the inspector, and the same recording assigned to two entries is an easy mistake to make and an invisible one to spot — twenty-five near-identical filenames in a list, two of them the same. In a bank of two identical entries this loop never exits, and it hangs the application on the first shake with no error and nothing on screen to suggest why.

The draw is therefore written to exclude by **index**, in one pass, with no retry:

```
var last_index := bank.find(_last_played)
if bank.size() == 1 or last_index < 0:
	return bank[randi() % bank.size()]
var pick := randi() % (bank.size() - 1)
if pick >= last_index:
	pick += 1
return bank[pick]
```

It picks among the `size - 1` entries that are not the excluded index and steps past it, so it terminates by construction whatever the array holds. A bank of one returns its only entry. A last-played stream that is not in this bank — which is every crossing from piano to forte — gives `find` a result of negative one and a free draw across the whole bank, which satisfies the specification's requirement 4 vacuously: a recording that is not in the bank being drawn from cannot be repeated by it.

## The pair geometry, in the pair scene's own pixels

The two artworks half-arrange themselves, and it is worth knowing that before anybody starts dragging nodes.

Each bell scene already offsets its sprite inside itself. `app/sleighbells_01.tscn` places its 597 by 878 texture at `(-143, 3)`, so the paddle bells span x from **-441.5 to 155.5** about the instance origin. `app/sleighbells_03.tscn` places its 484 by 618 texture at `(62, 1)`, so the strap bells span x from **-180 to 304**. Instanced at the same origin they therefore already overlap, by 335.5 pixels, with the paddle to the left and the strap to the right.

That is too much overlap for the reading the feature wants — George's words were "overlapping only slightly" — so the strap is pushed right. The trade is the whole of the geometry decision and it has exactly two ends: **more overlap keeps each bell bigger; less overlap reads more clearly as two instruments.** The starting point below sits in the middle of it.

| Quantity | Starting value | Where it comes from |
|---|---|---|
| Strap position | `Vector2(100, 40)` | Leaves 215.5 pixels of overlap, about a third of the paddle's width. The vertical offset stops the two sharing a baseline, which is what makes one read as behind the other |
| Paddle rotation | `-0.1047` radians (-6°) | Slight, and away from the strap |
| Strap rotation | `0.1222` radians (+7°) | Slight, and deliberately not the mirror of the paddle's, so the pair does not read as one symmetrical object |
| Draw order | Paddle listed **after** the strap | Later siblings draw in front at equal `z_index`, so the paddle is the one in front. No `z_index` is set on either |
| Pair root scale | `Vector2(0.72, 0.72)` | With the strap at +100 the pair spans x from -441.5 to 404, which is 845.5 wide. At 0.72 that is 609, against the paddle's own 597. The pair therefore occupies about one bell's footprint, which is the specification's requirement 7 |

Vertically the pair spans -436 to 442, which is 878, the same as the paddle alone; at 0.72 it is 632, so the pair is shorter than a single paddle and nothing overflows the slot.

Every one of these is a scene property with no code behind it. They are a principled starting point, not a result: requirement 7 puts the arrangement in the editor precisely so it can be nudged against the real screen, exactly as the tree's pivot was in the Artwork That Answers the Tilt of the Phone feature (C1_15) and the bubble's tail in the Fun Facts Bubble feature (C1_17).

## What the recordings actually cost the bundle

The feature specification's Future work section says the recordings are "twenty-five megabytes of uncompressed audio" and that "the bundle carries them". **That is wrong, and it is worth correcting rather than carrying forward.**

The export ships the imported samples, not the source files. Every delivered recording imports with `compress/mode=2`, which is Quite OK Audio, and the sixty-one one-shots resolve to **5.1 megabytes** in `.godot/imported/`, against 25 megabytes of source. All sixty-one also carry `edit/loop_mode=0`, so none can import as a loop and hang a voice.

No import setting is changed by this plan. The correction is recorded here and the specification's Future work paragraph should be amended to match; the future feature it describes is now a much smaller question than the specification makes it sound.

## Implementation Steps and Phases

### Phase 1: The instrument definition

Rewrite `app/instrument_definition.gd`. The `sound` property is removed and two banks take its place. `artwork` is unchanged.

```
# instrument_definition.gd (v2) - one bell the audience can choose.
#
# An instrument is the artwork scene that draws it and the recordings it sounds. How large the
# artwork is and where it sits relative to its own origin are authored in that scene, so the
# carousel scales and places a slot rather than correcting the artwork.
#
# The recordings live on the bell rather than on the play screen because the bell is already the
# thing that travels between screens: the selection screen publishes it, an autoload carries it
# across the scene change, and the play screen reads it.
#
# Two banks rather than one list indexed by level. The delivered recordings are split by how hard
# the instrument was struck, not by five gradations of it, and a struck bell changes timbre with
# force rather than only amplitude - which is the whole reason the choice is a recording and not
# a volume. Which levels take which bank is the responder's business, not the bell's.
@tool
class_name InstrumentDefinition
extends Resource

@export var artwork: PackedScene

# Softly struck recordings. A bell sounds these at every level when it has no forte bank, so this
# is the bank a bell cannot be without.
@export var piano_samples: Array[AudioStream] = []

# Hard struck recordings. Left empty for a bell whose recordings carry no dynamic layers, which
# is the strap bells: twenty-five takes were delivered for it, none of them split by dynamic.
@export var forte_samples: Array[AudioStream] = []
```

### Phase 2: The jingle response

Rewrite `shake/responses/jingle_response.gd`. The structure is the same as today's — resolve what to play, build a pool, connect to the bus — with the single recording replaced by two banks and the per-play stream assignment described above.

```
# jingle_response.gd (C1_02 shake instrument) - sounds a bell on every detected stop.
#
# Which recording sounds is chosen by how hard the stop was, and how loudly it sounds is scaled
# by the same stop on a continuous scale. Both act at once and they are doing different jobs: the
# bank choice gives the change of character between a soft strike and a hard one, which volume
# cannot produce, and the ramp gives the continuous response inside each band, so a shake at the
# bottom of the piano range is still softer than one at the top of it.
#
# The recordings come from one of two places, chosen by use_chosen_bell. On the play screen they
# come from the bell the audience member picked, which this node reads for itself rather than
# having the screen assign it: both this node and its parent run _ready, and the order between
# them is fixed in the direction that would make an assignment from the screen arrive too late.
# Everywhere else the recording is the exported stream, which is how the capture harness uses it.
#
# The exported stream resolves into a one-entry piano bank with an empty forte bank, so there is
# one code path below _resolve_banks rather than a bank-driven shape and a single-stream shape
# with a branch between them at every step. The harness sounds exactly as it did before.
extends Node

# When true the recordings are the chosen bell's, read from the InstrumentSelection autoload.
# When false they are the exported stream below. False is the default so a node that predates
# this option keeps behaving as it did.
@export var use_chosen_bell: bool = false

@export var stream: AudioStream

# The highest level that draws from the piano bank; every level above it draws from the forte
# bank. The detector quantises a stop into five levels, so this is the boundary between "a light
# shake" and "a hard one" and it is the one number to move when that boundary is wrong.
@export var piano_top_level: int = 2

# Intensity 0 sounds at the quietest, intensity 1 at the loudest.
@export var quietest_db: float = -24.0
@export var loudest_db: float = 0.0

# Voices are sized from the longest recording the bell carries against the highest sustained
# event rate the C1_09 measurements found, 6.77 stops per second, rounded up to eight for margin.
# The longest is the right measure because the pool exists to stop a recording being cut short by
# reuse of its voice, and the longest is the one most at risk of it. The tightest measured gap
# between two stops is 50 milliseconds, but that is a transient between one pair of stops rather
# than a rate anything sustains. The trade is stated plainly: a burst faster than the pool holds
# reuses its oldest voice and cuts a recording short.
const EVENTS_PER_SECOND: float = 8.0
const MINIMUM_VOICES: int = 4

var _piano: Array[AudioStream] = []
var _forte: Array[AudioStream] = []
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

# The recording that sounded last, excluded from the next draw. Held across bank changes, so a
# stop crossing from piano to forte is not treated as a fresh start.
var _last_played: AudioStream = null

func _ready() -> void:
	if piano_top_level < 1 or piano_top_level > 4:
		push_error("jingle_response piano_top_level is %d and must be between 1 and 4, so that at least one level draws from each bank. The default is 2." % piano_top_level)
		return
	if not _resolve_banks():
		return
	for index in _voice_count():
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)
	ShakeEvents.jingled.connect(_on_jingled)

# Returns false after reporting why, in which case this node connects to nothing and is inert.
# Nothing is substituted: a silent bell is a fault to be fixed, not a case to be handled.
func _resolve_banks() -> bool:
	if not use_chosen_bell:
		if stream == null:
			push_error("jingle_response has no stream assigned, so it is inert. Set its Stream property to a recording in res://sounds/v2/, or tick Use Chosen Bell to sound the bell the audience member picked.")
			return false
		_piano = [stream]
		_forte = []
		return true
	var chosen: InstrumentDefinition = InstrumentSelection.chosen
	if chosen == null:
		push_error("jingle_response is set to sound the chosen bell, but no bell has been chosen, so it is inert. Reach this screen through the flow, which starts at res://app/main.tscn.")
		return false
	if chosen.piano_samples.is_empty():
		push_error("jingle_response is set to sound the chosen bell, but that bell's Piano Samples bank is empty, so it is inert. Every bell sounds its piano bank at some level. Assign recordings to the InstrumentDefinition in res://app/instruments/.")
		return false
	if not _bank_is_complete(chosen.piano_samples, "Piano Samples"):
		return false
	if not _bank_is_complete(chosen.forte_samples, "Forte Samples"):
		return false
	_piano = chosen.piano_samples
	_forte = chosen.forte_samples
	return true

# An empty entry in an exported array is one click to make and invisible to read past in a list
# of twenty-five, so it is caught here by name rather than as a null at the moment of playing.
func _bank_is_complete(bank: Array[AudioStream], bank_name: String) -> bool:
	for index in bank.size():
		if bank[index] == null:
			push_error("jingle_response: entry %d of the chosen bell's %s bank is empty, so it is inert. Assign a recording to it in res://app/instruments/." % [index, bank_name])
			return false
	return true

func _voice_count() -> int:
	var longest: float = 0.0
	for sample in _piano:
		longest = maxf(longest, sample.get_length())
	for sample in _forte:
		longest = maxf(longest, sample.get_length())
	return maxi(int(ceilf(longest * EVENTS_PER_SECOND)), MINIMUM_VOICES)

func _on_jingled(event: ShakeEvent) -> void:
	var sample: AudioStream = _draw_from(_bank_for(event.level))
	_last_played = sample
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = sample
	voice.volume_db = lerpf(quietest_db, loudest_db, event.intensity)
	voice.play()

# An empty forte bank is a bell with no dynamic layers, which sounds its piano bank at every
# level. That is not a fallback: the bell has one bank because one bank was recorded, and it
# still answers how hard it was shaken through the loudness ramp.
func _bank_for(level: int) -> Array[AudioStream]:
	if _forte.is_empty() or level <= piano_top_level:
		return _piano
	return _forte

# Random within the bank, excluding whatever sounded last. Excluding by index in one pass rather
# than drawing and retrying: a retry loop never exits on a bank holding the same recording twice,
# which is an easy assignment to make by hand and an invisible one to read, and it would hang the
# application on the first shake with nothing on screen to say why.
#
# A bank of one repeats, because there is no alternative to draw. A last-played recording that is
# not in this bank gives find a result of -1 and a free draw, which is the crossing from one bank
# to the other: a recording that is not in the bank cannot be repeated by it.
func _draw_from(bank: Array[AudioStream]) -> AudioStream:
	var last_index: int = bank.find(_last_played)
	if bank.size() == 1 or last_index < 0:
		return bank[randi() % bank.size()]
	var pick: int = randi() % (bank.size() - 1)
	if pick >= last_index:
		pick += 1
	return bank[pick]
```

### Phase 3: The pair scene

Add `app/sleighbells_pair.tscn`, a plain `Node2D` with no script, instancing the two bell scenes at the geometry worked out above. The strap is listed first so the paddle draws in front of it.

```
[gd_scene format=3]

[ext_resource type="PackedScene" path="res://app/sleighbells_01.tscn" id="1_paddle"]
[ext_resource type="PackedScene" path="res://app/sleighbells_03.tscn" id="2_strap"]

[node name="SleighbellsPair" type="Node2D"]
scale = Vector2(0.72, 0.72)

[node name="Strap" parent="." instance=ExtResource("2_strap")]
position = Vector2(100, 40)
rotation = 0.1222

[node name="Paddle" parent="." instance=ExtResource("1_paddle")]
rotation = -0.1047
```

No script is added. Nothing about the arrangement is computed at run time, which is requirement 7's point: the pair is a scene so that it is tuned by opening it.

### Phase 4: The instrument resources

Add `app/instruments/sleighbells_pair.tres` and rewrite the two surviving resources against the new property names. Every `sound = ExtResource(...)` line goes; `piano_samples` and `forte_samples` arrays take their place. The assignment is fastest done in the editor by selecting a folder's worth of recordings and dropping them onto the array, rather than by hand-writing sixty-one `ext_resource` lines.

| Resource | Artwork | Piano bank | Forte bank |
|---|---|---|---|
| `sleighbells_01.tres` | `app/sleighbells_01.tscn` | 14 files, `sounds/v2/Type A/RS_SleighBell_A_Piano_000` to `_013` | 14 files, `Type A/RS_SleighBell_A_Forte_000` to `_013` |
| `sleighbells_03.tres` | `app/sleighbells_03.tscn` | 25 files, `sounds/v2/Type B/RS_SleighBell_B_000` to `_024` | **empty** |
| `sleighbells_pair.tres` | `app/sleighbells_pair.tscn` | 3 files, `sounds/v2/Type C/RS_SleighBell_C_Piano_000` to `_002` | 5 files, `Type C/RS_SleighBell_C_Forte_000` to `_004` |

Then edit `app/instrument_carousel.tscn`: drop the `ext_resource` line for `sleighbells_02.tres`, add one for `sleighbells_pair.tres`, and set the `instruments` array to the paddle, the strap, and the pair in that order. The carousel stays at three entries, which matters — `_rebuild_slots()` rejects a carousel of exactly two, and `invisible_distance` is documented as correct at 1.5 precisely because three instruments put the far side of the cycle there.

### Phase 5: Retire the shaker and the placeholder recordings

Nothing is deleted. Each file moves under `legacy/` mirroring the path it came from, and its `.import` sidecar moves with it.

| From | To |
|---|---|
| `images/v2/sleighbells_02.png` (+ `.import`) | `legacy/images/v2/sleighbells_02.png` |
| `app/sleighbells_02.tscn` | `legacy/app/sleighbells_02.tscn` |
| `app/instruments/sleighbells_02.tres` | `legacy/app/instruments/sleighbells_02.tres` |
| `sounds/bright_jingle_bells.mp3` (+ `.import`) | `legacy/sounds/bright_jingle_bells.mp3` |
| `sounds/airy_jingle_bells.mp3` (+ `.import`) | `legacy/sounds/airy_jingle_bells.mp3` |
| `sounds/deep_jingle_bells.mp3` (+ `.import`) | `legacy/sounds/deep_jingle_bells.mp3` |
| `sounds/light_jingle_bells.mp3` (+ `.import`) | `legacy/sounds/light_jingle_bells.mp3` |
| `sounds/single_jingle.mp3` (+ `.import`) | `legacy/sounds/single_jingle.mp3` |

All five placeholder recordings go, which is the whole point of the feature: they are superseded, and nothing in the live tree should still be sounding one.

That includes the one the capture harness uses. `shake/responses/jingle_response.tscn` carries `res://sounds/single_jingle.mp3` as its exported default and the harness instances that scene, so the reference is repointed — **to one of the delivered recordings, not to a legacy path.** `legacy/` carries a `.gdignore` and the engine does not import it, so a `res://legacy/...` reference resolves to nothing; the harness would be silent. The replacement is:

```
res://sounds/v2/Type A/RS_SleighBell_A_Piano_000.wav
```

That file is the shortest recording delivered, at 1.092 seconds. The harness wants one short dry click per detected stop so that stops are countable by ear while a run is being recorded, and the shortest piano take of the paddle bells is the closest thing in the new set to what `single_jingle.mp3` was doing. Its voice pool comes out at 9, against the 4-voice floor.

Four references inside `legacy/` will stop resolving once these files move, and all four are left exactly as they are: `legacy/instrument_carosel.tscn` points at the shaker's texture, and `legacy/bells/bell-01.tscn`, `bell-02.tscn`, and `bell-03.tscn` each point at `res://sounds/single_jingle.mp3`. Every one of them sits inside the ignored directory, alongside the files they name, and nothing loads any of it — §"Repository layout" in `docs/system_design.md` records that the first version of the application deliberately no longer runs. These are dead references inside dead artwork. **Do not repoint them**, and do not treat them as a reason to leave a superseded recording in `sounds/`.

### Phase 6: Tune on the handset

The two things that cannot be judged anywhere else, in this order:

1. **`piano_top_level`.** Shake gently and confirm the soft recordings sound; shake as an audience member actually would and confirm the hard ones do. If the boundary feels wrong, it is one integer on the `JingleResponse` node in `app/instrument.tscn`.
2. **The pair's geometry.** Open `app/sleighbells_pair.tscn` beside the carousel and settle the overlap, the two rotations, and the pair scale against a real screen at the carousel's centre-slot size.

### Phase 7: Documentation

`README.md` and `docs/system_design.md` as described in §3 below.

## Test Cases

**No automated tests are created or changed by this plan.** §"Testing" in `docs/system_design.md` records that this repository has no test framework and that three consecutive features have declined to introduce one, on the grounds that the parts of this application most worth testing are the parts that only exist on a real device.

That reasoning is weaker here than usual and it is worth saying so rather than inheriting the decision silently. `_draw_from()` and `_bank_for()` are pure functions of their arguments and would test perfectly well on a desktop, and `_draw_from()` in particular has a termination property that a test would pin down permanently. It is nonetheless followed, because introducing a framework is a change to the repository's shape that belongs to a feature about testing rather than to a feature about bell recordings. Both functions are written small and free of node state so that a later feature which does introduce a framework can reach them without restructuring anything.

There is accordingly no unit-test table. The verification table in §4 and the acceptance table at the end of this plan carry the whole burden.

Four failure modes worth naming here, because each looks like something other than its cause:

- **The application hangs on the first shake** is two entries of one bank holding the same recording, under a draw written as a retry loop. This plan's draw cannot produce it; a build that reintroduces the loop can.
- **Every shake sounds soft, however hard the phone is shaken**, on the strap bells only, is correct and is requirement 3. On the paddle bells or the pair it is `forte_samples` left empty by a missed assignment.
- **A recording audibly cut off under fast shaking** is the voice pool wrapping, not a truncated file. The pool is sized from the longest recording, so it is the shortest gap between stops that produced it, not the sample.
- **The pair rendering larger than the other two in the carousel** is the pair root's `scale` lost in an edit. The carousel scales the slot, not the artwork, so nothing downstream corrects it.

## README and Documentation Updates

**`README.md`**, §"The shake instrument", is rewritten where it describes the sound. It should say that a bell carries two banks of recordings rather than one, that the level of a detected stop chooses the bank and the intensity scales the volume, that a bell with an empty forte bank sounds its piano bank at every level, that no recording sounds twice in a row, and that the voice pool is sized from the longest recording the bell carries.

**`README.md`**, §"Repository structure", gains the pair scene and its resource where the bell scenes are listed.

**`docs/system_design.md`**, §"The sound responder", is rewritten for the same content. The existing paragraph "Voices are a pool, sized from the recording's own length … cuts a recording short" becomes the longest-recording form, and its worked example — "A two-second recording therefore builds sixteen" — is updated: the paddle bells build 18, the strap bells 23, the pair 24.

**`docs/system_design.md`**, §"The audience flow", is checked for any statement of which three bells the carousel offers, and corrected if one is there.

§"The hard rule about assets", §"Conventions", and §"Testing" are not edited. Neither document gains a claim about testing.

The feature specification's Future work paragraph on bundle size should be corrected to 5.1 megabytes of imported audio, per the measurement above. That is an edit to `features/C1_18_jingle_bell_samples.md`, not to either document here.

## Manual Verification Steps

Everything is done on a handset unless marked otherwise. The editor and desktop checks come first because they are fast and they catch the assignment mistakes.

1. **Editor.** The project opens with no import errors and no script errors. `run/main_scene` in `project.godot` still points at the title screen.
2. **Editor.** Open each of the three resources in `app/instruments/`. The banks hold the counts in the Phase 4 table, and no entry in any bank is empty.
3. **Editor.** Open `app/sleighbells_pair.tscn`. Both instruments are visible, overlapping, each turned slightly, with the paddle in front.
4. **Editor.** Open `app/instrument_carousel.tscn`. Three slots build: paddle, strap, pair. The green shaker is absent and no error mentions a missing resource.
5. **Desktop build.** Run the flow to the bell selection screen. Swipe through all three. The pair is about the size of the other two in the centre slot, and swiping wraps in both directions with no bell popping into view mid-drag.
6. **Desktop build.** Choose the paddle bells. Shake gently, repeatedly. Soft recordings sound and vary; no recording sounds twice in a row.
7. **Desktop build.** Same bell. Shake hard. Recordings are audibly different in character, not merely louder.
8. **Desktop build.** Choose the strap bells. Shake gently, then hard. The recordings vary and change in volume; they do not change in character. This is requirement 3 and it is correct.
9. **Desktop build.** Choose the pair. Shake gently, repeatedly. With only three piano recordings, all three are heard and none repeats back to back.
10. **Desktop build.** Empty one bell's `piano_samples` and run to the play screen with it chosen. An error names the bank and the resource, no sound plays, and the rest of the screen is unaffected.
11. **Desktop build.** Set `piano_top_level` to 0 and run. An error names the value, its permitted range, and the default, and the node is inert.
12. **Desktop build.** Clear one entry of a bank and run. An error names the entry's index and its bank.
13. **Desktop build.** Open `capture/shake_capture.tscn` and run it. The harness sounds its new short click on every stop, one per stop and countable by ear, and its readout is unchanged.
14. **Handset.** Shake at the range an audience member actually uses. The boundary between soft and hard falls where it should; this is the check `piano_top_level` exists for and it cannot be made anywhere else.
15. **Handset.** Shake as fast as possible for twenty seconds. No recording is audibly cut short, and nothing stutters or hangs.
16. **Handset.** Confirm the pair reads as two instruments being shaken rather than as one object or as two pictures set side by side, at the carousel's centre-slot size and on the play screen.

## Coding Standards Compliance Checklist

There is no application coding standards document for this repository; §"Where the governing documents live" in `docs/system_design.md` says so explicitly and names §"Conventions" as what a review audits against. Each item below is one of those conventions.

- Tab indentation in GDScript.
- A one-line comment at the top of each script naming the file and its role, followed by what a reader needs that the code cannot tell them.
- Static typing on every declaration and return type, including `-> void`.
- Signals connected in `_ready()` rather than in a scene file. `ShakeEvents.jingled` is connected in `_ready()` and only after the banks resolve, so a bell that cannot sound connects to nothing.
- Scene and script files named in lower snake case: `sleighbells_pair.tscn`, `sleighbells_pair.tres`.
- Exported values used as divisors, bounds, or loop counts are validated in `_ready()` with a message naming the value, its permitted range, and the correct default: `piano_top_level`.
- Node dependencies reached by path are validated at load. This feature reaches none; its dependencies are resource properties and they are validated in `_resolve_banks()` before anything is built.
- **No fallbacks.** A missing stream, an empty piano bank, an empty entry in a bank, or an out-of-range boundary produces an error naming what is wrong and what to do, and the node goes inert. The empty forte bank is not a fallback and must not be written as one: nothing is substituted, the bell has one bank because one bank was recorded, and that is requirement 3.
- **No media file is deleted.** §"The hard rule about assets".

## File-Level Compliance Review

| File | Change | Review points |
|---|---|---|
| `app/instrument_definition.gd` | Rewritten | `sound` removed, not left alongside the banks. `@tool` and `class_name` kept |
| `shake/responses/jingle_response.gd` | Rewritten | `_draw_from()` excludes by index and cannot loop. Voices carry no stream until played. `_last_played` survives a bank change |
| `shake/responses/jingle_response.tscn` | Exported default repointed | To `sounds/v2/Type A/RS_SleighBell_A_Piano_000.wav`, never to a `legacy/` path, which cannot resolve. Nothing else in the file changes |
| `app/sleighbells_pair.tscn` | New | Instances the two bell scenes, never their textures. No script. Root `scale` is load-bearing; the paddle is listed last so it draws in front |
| `app/instruments/sleighbells_pair.tres` | New | Type C recordings, 3 piano and 5 forte |
| `app/instruments/sleighbells_01.tres` | Rewritten | Type A, 14 and 14. Artwork unchanged |
| `app/instruments/sleighbells_03.tres` | Rewritten | Type B, 25 piano, forte deliberately empty |
| `app/instrument_carousel.tscn` | Two lines changed | Three entries: paddle, strap, pair. Never two, which `_rebuild_slots()` rejects |
| `images/v2/sleighbells_02.png`, `app/sleighbells_02.tscn`, `app/instruments/sleighbells_02.tres` | Moved to `legacy/` | With `.import` sidecars. Not deleted |
| `sounds/*.mp3` | Moved to `legacy/` | All five, with `.import` sidecars. Not deleted |
| `README.md` | Two sections edited | §"The shake instrument" and §"Repository structure" |
| `docs/system_design.md` | Two sections edited | §"The sound responder" and §"The audience flow". §"Conventions", §"Testing", and §"The hard rule about assets" untouched |

## Completion Criteria

1. The project opens with no import errors and no script errors, and every resource reference resolves.
2. `run/main_scene` in `project.godot` still points at the title screen, and `project.godot` is otherwise unmodified.
3. All sixteen manual verification steps in §4 pass, including the three that require a handset.
4. Every row of the acceptance table passes.
5. The three instrument resources carry the bank contents in the Phase 4 table, with no empty entry in any bank.
6. Every file in the Phase 5 table exists under `legacy/`, no media file has been deleted, and no scene in the live tree holds a `res://legacy/` reference.
7. `README.md` and `docs/system_design.md` carry the updates in §3.
8. No file outside those named in §6 is modified.

## Token and Design Considerations

This feature builds no skill. There is no `input_limits` value to declare, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

**Topic:** why the strength of a shake should choose a recording rather than only a volume. **Competency:** a developer who can explain that a struck instrument changes timbre with force and not just amplitude, and that this is why the detector has published a quantised level alongside a continuous intensity since the Shake It Discovery feature (C1_09), will reach for the right one of the two when adding any future response — a recording bank from the level, a continuous parameter from the intensity — instead of scaling one asset and calling it dynamics.

This is a new entry for the tutor's `references/topics.md`. That file does not exist in this repository and no tutor runs here, so the entry is recorded in this plan and added if and when the tutor arrives.

## Acceptance Table

This replaces the unit-test table, for the reason given in §2. Every row is verified by hand, and the rows marked handset cannot be checked anywhere else.

| Behaviour under test | Concrete input | Expected result |
|---|---|---|
| Bank choice, low | Paddle bells, `piano_top_level` 2, a stop at level 1 | A recording from `Type A/…_Piano_…` sounds |
| Bank choice, boundary | Paddle bells, a stop at level 2, then one at level 3 | Level 2 sounds a Piano recording; level 3 sounds a Forte one |
| Bank choice, high | Paddle bells, a stop at level 5 | A recording from `Type A/…_Forte_…` sounds |
| Empty forte bank | Strap bells, stops at levels 1 and 5 | Both sound a `Type B` recording. The two differ in volume and not in character |
| No immediate repeat, large bank | Strap bells, 30 stops in a row | No recording sounds twice consecutively at any point |
| No immediate repeat, small bank | The pair, 12 gentle stops (3-entry piano bank) | All three are heard, and no two consecutive stops sound the same one |
| Bank of one repeats | Capture harness, its single exported recording, 10 stops | The one recording sounds every time, with no error |
| Crossing banks | The pair, a gentle stop then a hard one | Both sound; the exclusion does not suppress or error on the crossing |
| Loudness ramp preserved | Any bell, a level-1 stop and a level-2 stop | Both draw piano; the harder of the two is audibly louder |
| Voice pool size, paddle | Paddle bells (longest recording 2.250 s) | 18 `AudioStreamPlayer` children on the `JingleResponse` node |
| Voice pool size, strap | Strap bells (longest 2.771 s) | 23 children |
| Voice pool size, pair | The pair (longest 2.918 s) | 24 children |
| Draw terminates on duplicates | A bank with the same recording in two entries, 20 stops | Sound plays on every stop and the application does not hang |
| Empty piano bank | A bell with `piano_samples` cleared | An error names the bank and `res://app/instruments/`; no sound; nothing else affected |
| Empty entry in a bank | Entry 4 of a bank cleared | An error names index 4 and the bank by name; the node is inert |
| Boundary out of range | `piano_top_level` set to 0, and again to 5 | Both error, naming the value, the range 1 to 4, and the default 2 |
| Carousel contents | The bell selection screen | Three bells: paddle, strap, pair. No green shaker anywhere |
| Pair footprint | The pair in the carousel centre slot | About the width of the paddle bells alone; the slot needs no adjustment |
| Pair draw order | `app/sleighbells_pair.tscn` | The paddle overlaps in front of the strap, both turned slightly, neither `z_index` set |
| Harness repointed | `capture/shake_capture.tscn`, run directly | Sounds `RS_SleighBell_A_Piano_000` on every stop, one per stop, with 9 voices built |
| No media deleted | The Phase 5 table | Every listed file exists under `legacy/` |
| Handset: boundary feel | Shaking at an audience member's natural range | The soft-to-hard boundary lands where it should, or `piano_top_level` is retuned until it does |
| Handset: sustained shaking | 20 seconds as fast as possible | No recording audibly cut short; no stutter; no hang |
| Handset: the pair reads | The bell selection and play screens | Two instruments being shaken, not one object and not two pictures side by side |
