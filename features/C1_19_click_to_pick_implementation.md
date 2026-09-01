---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Tap the Bell You Want, Then Tap It Again to Play
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: One script gains a tap, one screen loses a button, and one scene gains a sentence, with the tap rectangle's numbers, the settle that must still run after a tap that hit nothing, and the reason the icon is resized in the file rather than in the Import dock all worked out here rather than found on the handset.
LAST UPDATED: September, 1, 2026 13:24
---

# Implementation Plan for Tap the Bell You Want, Then Tap It Again to Play

This plan implements the Tap to Choose Your Bell feature (C1_19). It adds tap handling to `app/instrument_carousel.gd`, removes the Continue button from `app/instrument_select.tscn` and `app/instrument_select.gd`, widens the Jingle Cam button and gives it an icon, resizes `images/v2/photo_camera.svg`, adds one new scene to `app/`, and instances it into `app/instrument.tscn`. No autoload is registered, no resource is edited, the shake instrument is untouched, no media file is moved or deleted, and `project.godot` is untouched.

## Design decisions carried in from the specification and planning conversations

- **The tap target is a rectangle with both bounds, not a horizontal band.** The specification's requirement 1 measured the hit radius horizontally only, which would have made the full height of the drag band a target at the centre column and turned the "Swipe to Select Your Bells!" lettering into a control. The target is a rectangle around the artwork instead, with an exported half-width and half-height.
- **The rectangle is scaled by the same factor the slot is drawn at.** Side slots are drawn at half size, so a fixed rectangle would overshoot them. Each slot's target is the authored rectangle multiplied by that slot's own `scale`, which is already computed in `_render()`. The target and the artwork therefore agree by construction rather than by two values being kept in step.
- **One-bell carousels are not supported.** With Continue gone the carousel is the only control that leaves the bell selection screen, and `_unhandled_input` returns immediately below two slots. Rather than leave a configuration that traps the audience member on a screen with no way forward, the configuration check in `_rebuild_slots()` is raised from rejecting exactly two instruments to rejecting fewer than three. Two remains rejected for its original reason, which is that a two-instrument cycle puts the far side at a cyclic distance of exactly 1.0 and the opacity ramp has no room to hide the wrap.
- **The camera artwork is resized in the file, not in the Import dock.** `images/v2/photo_camera.svg.import` already exists and carries `svg/scale=1.0`. Changing that number is an editor action that cannot be performed from a plan step, and it is stored in a sidecar the editor regenerates whenever import settings are reset. Editing the scalable vector graphic's own `width` and `height` attributes while leaving its `viewBox` alone produces an identical texture at the default import scale, is visible in the asset itself, and survives a sidecar regeneration.
- **The carousel emits, the screen navigates.** Tapping the centred bell changes scenes, but the carousel has never known that screens exist. It emits a signal and `app/instrument_select.gd` performs the scene change, which is the role that script already plays for the screen's buttons.
- **The shake prompt is a `Label` inside a `Node2D`.** `app/sprite_position.gd` extends `Node2D` and a `Label` is a `Control`, so the placement script cannot attach to a label directly. The new scene follows the shape `app/fun_fact_bubble.tscn` already uses.

## The tap rectangle, in the numbers the artwork actually occupies

The defaults below are authored so that the target covers the artwork on the first run rather than being discovered on the handset. All figures are design pixels on the 1080 by 1920 canvas. The carousel sits at `design_position` (532, 613) with a bottom anchor, and its slots are drawn at that origin with no scale of their own, so the artwork's own extents are the extents on screen.

| Artwork | Horizontal extent about the slot origin | Vertical extent about the slot origin |
|---|---|---|
| `sleighbells_01.tscn`, the paddle bells | -108 to +108 | -291 to +389 |
| `sleighbells_03.tscn`, the strap bells | -69 to +59 | -290 to +292 |
| `sleighbells_pair.tscn`, both together | -85 to +114 | -210 to +280 |

`tap_half_width` defaults to 110 and `tap_half_height` to 400, both measured from the slot origin. The vertical default is deliberately generous, because the artwork is not symmetric about its origin: the paddle bells reach 389 pixels below it and only 291 above. A rectangle of 400 covers every artwork's full height with margin, and the part of it that reaches above design y 213 is unreachable anyway, since the drag band starts 300 pixels below the safe top and a press outside the band never begins a gesture.

The horizontal default is bounded by the slot geometry rather than by the artwork. The side slots sit `side_slot_distance` away at `side_slot_scale`, so the centre rectangle and a side rectangle first touch when the half-width reaches `side_slot_distance / (1.0 + side_slot_scale)`, which is 113.3 at the shipped values of 170 and 0.5. Above that the side targets fall inside the centre one and are shadowed by it, because overlaps resolve to the nearest slot. `tap_half_width` is therefore validated against that bound in `_ready()`.

One consequence is worth naming so it is not mistaken for a defect: the pair artwork reaches 114 pixels to the right of its origin, four pixels past the target, so the outermost sliver of the strap bell in the pair scene is outside the tap rectangle. Widening the target to reach it would shadow the side slots, which is the worse trade.

## Implementation Steps and Phases

### Phase 1: Tap handling in the carousel

All changes in this phase are to `app/instrument_carousel.gd`. Nothing else is touched.

**1.1 Declare the signal.** Add `signal centre_tapped` near the top of the script, above the exported properties, with a one-line comment saying that the bell selection screen connects it and performs the navigation, and that the carousel deliberately does not.

**1.2 Add the exported tap group.** After the existing `Drag feel` group and before `Drag band`, add:

```
@export_group("Tap")
# Design pixels of finger travel below which a released gesture is a tap.
@export var tap_travel_limit: float = 24.0
# Half-width of the tap rectangle around a centred instrument, in design pixels.
@export var tap_half_width: float = 110.0
# Half-height of the tap rectangle around a centred instrument, in design pixels.
@export var tap_half_height: float = 400.0
```

**1.3 Validate the three values in `_ready()`.** `_ready()` currently calls `super()` and `_rebuild_slots()`. Add validation before `_rebuild_slots()`, following the repository's convention that each message names the value, its permitted range, and the correct default:

- `tap_travel_limit` must be greater than zero. Default 24.0.
- `tap_half_height` must be greater than zero. Default 400.0.
- `tap_half_width` must be greater than zero and less than `side_slot_distance / (1.0 + side_slot_scale)`. The message states the computed bound and says that above it the side slots are shadowed by the centre one. Default 110.0.

A failed check calls `push_error` and returns without building slots, so the screen is visibly inert rather than quietly mis-targeted. Nothing substitutes a default value, in keeping with the repository's no-fallbacks rule.

**1.4 Track finger travel.** Add `var _press_at: Vector2 = Vector2.ZERO` and `var _max_travel: float = 0.0` to the state block. In `_pointer_button`, on a press that begins a drag, set `_press_at` to the pointer position and `_max_travel` to zero. In `_pointer_moved`, before `_continue_drag`, set `_max_travel` to the larger of itself and `_press_at.distance_to(at)`.

Travel is measured in two dimensions rather than on the horizontal axis alone, so a vertical drag that moves the carousel not at all is still not a tap. It is tracked as the maximum distance reached rather than the distance at release, so a finger that travels out and comes back is not a tap either.

**1.5 Pass the release position into `_end_drag`.** `_end_drag()` becomes `_end_drag(at: Vector2)` and `_pointer_button` passes the release position. Its first action becomes the tap branch:

```
func _end_drag(at: Vector2) -> void:
	_dragging = false
	if _max_travel <= tap_travel_limit:
		_handle_tap(at)
		return
```

The existing flick prediction and settle follow unchanged below.

**1.6 Add `_handle_tap`.** Three outcomes, decided by which slot the point falls in:

- **No slot.** Call `_settle_to(roundf(_offset))`. This looks like a contradiction of the specification's requirement 4, and it is not: `_begin_drag` kills any running settle, so a press that turns out to be a tap on nothing would otherwise leave the carousel stranded between two bells. Settling to the nearest whole position finishes the animation the press interrupted. It changes no selection, emits no signal, and does nothing at all when the carousel was already at rest, because `_settle_to` returns immediately when the offset already equals the target.
- **The centred slot.** Emit `centre_tapped`. The carousel does not move and does not change scenes.
- **A side slot.** Call `_settle_to(_offset + cyclic_distance(float(index) - _offset, _slots.size()))`, which carries the tapped slot to the centre the short way around the cycle. This reuses the existing settle, so a bell brought in by a tap moves exactly as a bell brought in by a released drag, and `_set_offset` publishes the selection as it goes.

The centred slot is `int(fposmod(roundf(_offset), float(_slots.size())))`, which is the same expression `_publish_selection` already uses to decide which bell is chosen. Using the same expression is what keeps the bell that advances the screen and the bell that is published from ever disagreeing.

**1.7 Add `_slot_at`.** Returns the index of the slot whose rectangle contains a viewport point, or -1.

```
func _slot_at(at: Vector2) -> int:
	var count := _slots.size()
	var best := -1
	var best_spread := INF
	for index in count:
		var slot := _slots[index]
		if not slot.visible:
			continue
		var half := Vector2(tap_half_width, tap_half_height) * slot.scale
		if not Rect2(slot.global_position - half, half * 2.0).has_point(at):
			continue
		var spread := absf(cyclic_distance(float(index) - _offset, count))
		if spread < best_spread:
			best_spread = spread
			best = index
	return best
```

Three things this does on purpose. Invisible slots are skipped, so the slot sitting at the wrap point behind the others is never tapped. Overlapping rectangles resolve to the smallest cyclic distance, which is the same ordering `_render` uses to set `z_index`, so the slot that receives the tap is the slot drawn in front of the others. And the rectangle is scaled by the slot's own `scale`, so it matches what is drawn at every point of a drag rather than only at rest.

The comparison mixes `slot.global_position`, which is a canvas coordinate, with `at`, which is a viewport coordinate. They coincide because these screens carry no camera and no canvas transform, and this is the same assumption `drag_band_rect()` already makes when it tests `event.position` against a rectangle built from `get_viewport_rect()`. A comment records it.

**1.8 Raise the configuration floor in `_rebuild_slots`.** Replace the `instruments.size() == 2` check with a check for fewer than three, with a message naming the count given, saying that three or more are required, and giving both reasons: below two the carousel is the only control that advances the screen and there would be no way forward, and at exactly two the far side of the cycle falls at a cyclic distance of 1.0 where the opacity ramp cannot hide the wrap.

The `_slots.size() < 2` guard at the top of `_unhandled_input` stays exactly as it is. It is now unreachable in a valid configuration, and it stays as the second line of defence for a carousel whose slots failed to build.

**1.9 Correct the three comments that describe the Continue button.** These are statements about a control that Phase 2 removes, and correcting them is part of this feature rather than a separate tidy:

- The comment block above `_unhandled_input` says a press inside the Continue button is marked handled during interface input and that the band is measured to end above the button. It becomes a statement about the Jingle Cam button, which is the control that now bounds the band.
- The `drag_band_bottom_inset` comment says the inset places the band above the continue button. It becomes the Jingle Cam button.
- The comment above `_publish_selection` says the choice is already correct the moment Continue is pressed and that the button needs no code of its own. It becomes a statement about the tap: the choice is already correct the moment the centred bell is tapped, which is what lets `centre_tapped` carry no payload.

### Phase 2: Retire the Continue button

**2.1 `app/instrument_select.tscn`.** Remove the `ContinueButton` node in full. Remove the two sub-resources it alone uses, `StyleBoxFlat_31ns7` and `StyleBoxFlat_3rpyo`. The Jingle Cam button's two sub-resources, `StyleBoxFlat_0c8ss` and `StyleBoxFlat_nex8d`, stay.

**2.2 `app/instrument_select.gd`.** Remove the `continue_button` member, its null check in `_ready()`, its signal connection, and `_on_continue_pressed`. Add an `@onready var carousel: Node2D = $InstrumentSelector`, validate it in `_ready()` with a message naming the node and saying the screen cannot advance without it, connect `carousel.centre_tapped` to a new `_on_centre_tapped`, and have that handler call `get_tree().change_scene_to_file("res://app/instrument.tscn")`.

The node dependency is validated in `_ready()` rather than at first use, and the signal is connected in `_ready()` rather than in the scene file, both per the repository's conventions. The existing validation of `jingle_cam_button` is unchanged.

The script's header comment, which explains that nothing here touches `CameraServer`, stays as it is and remains true.

**2.3 The drag band needs no change.** `drag_band_bottom_inset` is 230 design pixels above the safe area's bottom. The Jingle Cam button's top edge is 155 above it, which is the higher of the two edges the band was clearing, so the band still ends above the only button that remains. Phase 1.9 corrects the comment; the number stays.

### Phase 3: The Jingle Cam button

**3.1 Resize the artwork.** In `images/v2/photo_camera.svg`, change `height="24px"` to `height="72px"` and `width="24px"` to `width="72px"`. Leave the `viewBox="0 -960 960 960"`, the `fill="#ffffff"`, and the path data untouched. The existing `images/v2/photo_camera.svg.import` keeps `svg/scale=1.0` and is not edited; the engine reimports on the next editor open because the source file changed, and the result is a 72 by 72 texture.

72 design pixels is the starting value, sized to read as the same visual weight as the 44 point lettering beside it. It is tuned by eye in Phase 5 by changing the same two attributes.

**3.2 `app/instrument_select.tscn`, the button itself.** Add an `ext_resource` line for the camera texture, using its existing identifier `uid://0cpccdmhiae0` and path `res://images/v2/photo_camera.svg`. On `JingleCamButton`:

- `offset_right` moves from -290.0 to -38.0, which is where the Continue button's right edge was. The button becomes 498 design pixels wide.
- `text` becomes the single-line `Jingle Cam` in place of the two-line `"Jingle\nCam"`.
- `icon` is set to the new external resource.
- `theme_override_constants/h_separation` is set to 24, because the default separation of 4 sits the icon against the lettering.

Everything else is unchanged: the bottom-right anchors, `offset_left` at -536.0, `offset_top` at -155.0 and `offset_bottom` at -33.0, the red styles, the 44 point white lettering, `app/safe_area_margin.gd`, and its `base_offset_top` and `base_offset_bottom`.

`expand_icon` is deliberately left off and `icon_max_width` is deliberately not set. Both scale the imported texture rather than change what is rasterised, which on an upscale produces a soft icon. Sizing the source is what keeps it sharp.

### Phase 4: The shake prompt on the play screen

**4.1 New scene `app/shake_to_jingle.tscn`.** Named for its words, as `app/swipe_to_select.tscn` is. A `Node2D` root named `ShakeToJingle` carrying `app/sprite_position.gd`, with a single `Label` child named `Prompt`:

- `text` is `Shake to Jingle`
- `theme_override_font_sizes/font_size` is 58, the size the instruction screen's own label was authored at
- `theme_override_colors/font_color` is `Color(1, 1, 1, 1)`, which the play screen's near-black background requires
- `offset_left` -400, `offset_right` 400, `offset_top` -40, `offset_bottom` 40
- `horizontal_alignment` and `vertical_alignment` both 1, which centres the text on the node's origin
- `mouse_filter` is 2

The label ignores input for the same reason the fun fact bubble's two labels do, recorded in `README.md`: a label left at its default carves a dead rectangle out of whatever is behind it, which is invisible on a desktop and only found under a thumb. The play screen has no drag band today, and the Tap-to-Jingle roadmap item (`C1_01`) would put one there.

**4.2 Instance it into `app/instrument.tscn`.** Placed immediately after the `Title` node so it draws above the vignette and below the bell, with `design_position` (540, 470), `respect_safe_area` set true, and both anchors left at their defaults of horizontal centre and vertical top.

470 centres the prompt in the gap the screen already has. The logo is 759 by 253 drawn at 0.915 scale centred on design y 163, so its lower edge is at 279. The paddle bells are the tallest artwork and reach 389 pixels below their own origin, drawn at scale 2 from a holder at design y 1247, so the artwork's opaque top edge is at 665. The midpoint of 279 and 665 is 472.

The top anchor is chosen over a centre anchor so the prompt holds its relationship to the title. On a taller phone the canvas grows downward, the title stays where it is, and the centre-anchored bell moves further down, which widens the gap rather than closing it.

### Phase 5: Tune on the handset

Sensors and the safe area only exist on a real device, and the icon and the prompt are both judged by eye. On an iPhone:

- `tap_travel_limit`, raised if a deliberate tap sometimes reads as a small drag, lowered if a short flick reads as a tap.
- `tap_half_width` and `tap_half_height`, checked against all three bells including the pair.
- The camera icon's size, by changing the two attributes in `images/v2/photo_camera.svg`.
- The prompt's `design_position`, checked against the notch, since it respects the safe area and the title above it does too.

### Phase 6: Documentation

**6.1 `docs/system_design.md`.** Three places name the Continue button or the flow it belongs to:

- §"The audience flow" ASCII diagram, whose `app/instrument_select.tscn` line ends with `"Continue"`. It becomes the tap on the chosen bell.
- §"What crosses a scene change", which says the carousel publishes continuously "so the choice is already correct the moment Continue is pressed and the button needs no code of its own." The sentence keeps its point and changes its subject to the tap.
- §"Screen composition", which describes buttons styled per screen with inline `StyleBoxFlat` sub-resources and names the flow's blue. The blue survives on the instructions and play screens, so the paragraph stands; it is re-read to confirm it does not claim a blue button on the selection screen.

The new scene is added to the list of small composition scenes in §"Screen composition", beside `title.tscn`, `vignette.tscn`, and `winnie.tscn`, and noted as the second place in the application where a label carries live text.

**6.2 `README.md`.** §"The Jingle Cam" describes the screen as reached "by the red Jingle Cam button". That stays true and needs no edit; it is re-read to confirm it does not describe the button as sharing the corner with another.

**6.3 The roadmap is not touched.** `features/mvp1_roadmap.md` is project tracking, which this cycle does not write to.

## Test Cases

**No automated tests are created or changed by this plan.** §"Testing" in `docs/system_design.md` records that this repository has no test framework and that three consecutive features have declined to introduce one.

That reasoning is stronger here than it was for the bell recordings. Every behaviour this feature adds is a gesture: the distinction between a tap and a flick, whether a rectangle covers the artwork a thumb is aiming at, and whether an icon reads at a glance. None of those can be judged anywhere but a handset. Two functions are nonetheless written as pure functions of their arguments so that a later feature introducing a framework can reach them without restructuring anything: `cyclic_distance` already is one, and `_slot_at` depends only on the slot transforms and the point.

There is accordingly no unit-test table. The verification steps below and the acceptance table at the end of this plan carry the whole burden.

Four failure modes worth naming, because each looks like something other than its cause:

- **Tapping a bell does nothing at all** is `tap_half_width` or `tap_half_height` failing validation in `_ready()`, which returns before slots are built. The screen shows no bells at all in that case, so an empty carousel is the symptom to look for before suspecting the rectangle.
- **Tapping the centre bell moves the carousel instead of advancing** is `_max_travel` not being reset on press, so the first gesture after a drag inherits the previous one's travel and is judged a drag.
- **The carousel sits between two bells after a tap on empty space** is the missed-tap branch returning without calling `_settle_to`. The press killed a settle and nothing restarted it.
- **A side bell cannot be tapped near its inner edge** is `tap_half_width` tuned above `side_slot_distance / (1.0 + side_slot_scale)`, where the centre rectangle shadows it. The validation in `_ready()` is what makes this loud rather than mysterious.

## README and Documentation Updates

| File | Change |
|---|---|
| `docs/system_design.md` | §"The audience flow" diagram line for the selection screen; §"What crosses a scene change" Continue sentence; §"Screen composition" gains the new scene and is re-read for the button paragraph |
| `README.md` | §"The Jingle Cam" re-read only; no edit expected |
| `features/mvp1_roadmap.md` | Not touched. Tracking is not written by this cycle |

## Manual Verification Steps

On a handset, launched from the title screen so the flow is entered properly:

1. **Swipe still works.** Drag the bells left and right. They track the finger, can be pushed part way and pulled back, and settle on release exactly as before.
2. **Tap a side bell.** It settles to the centre with the same animation a released drag produces, and the screen does not change.
3. **Tap the centred bell.** The play screen opens showing that bell.
4. **The bell that opens is the bell that was tapped.** Repeat step 2 and step 3 for each of the three bells in turn, including the pair.
5. **Tap empty space inside the drag band.** Nothing happens: no movement, no navigation.
6. **Tap empty space mid-settle.** Flick the carousel and tap empty space while it is still moving. It finishes onto a whole position rather than stopping between two bells.
7. **A flick is not a tap.** Flick quickly and release with the finger still moving. The carousel advances and the screen does not change.
8. **The instruction lettering is inert.** Tap directly on "Swipe to Select Your Bells!". Nothing happens.
9. **The fun fact bubble is still inert.** Tap the bubble text. Nothing happens, and no dead zone appears in the swipe region around it.
10. **There is no Continue button.** The bottom of the screen carries the Jingle Cam button alone.
11. **The Jingle Cam button reads on one line** with the camera icon to its left, both centred in the button, and the button clears the home indicator.
12. **The Jingle Cam button still works.** Press it; the camera screen opens.
13. **The play screen carries the prompt.** "Shake to Jingle" sits below the logo and above the bell, in white, centred, and clear of the notch.
14. **Shaking still sounds the bell**, and the prompt does not interfere with it.
15. **Back still returns to the selection screen**, and the carousel opens on the bell that was being played rather than on the first bell.

## Coding Standards Compliance Checklist

There is no application coding standards document for this repository; §"Where the governing documents live" in `docs/system_design.md` says so explicitly and names §"Conventions" as what a review audits against. Each item below is one of those conventions.

- Tab indentation in GDScript.
- A one-line comment at the top of each script naming the file and its role. No new script is added by this plan; the two scripts edited keep their headers, and `app/instrument_select.gd`'s header remains accurate.
- Static typing on every declaration and return type, including `-> void`: `_handle_tap`, `_slot_at`, the changed `_end_drag`, `_on_centre_tapped`, and the two new state members.
- Signals connected in `_ready()` rather than in a scene file: `centre_tapped` is connected in `app/instrument_select.gd`'s `_ready()`, never in `app/instrument_select.tscn`.
- Scene and script files named in lower snake case: `shake_to_jingle.tscn`.
- Exported values used as divisors, bounds, or loop counts are validated in `_ready()` with a message naming the value, its permitted range, and the correct default: `tap_travel_limit`, `tap_half_width`, `tap_half_height`.
- Node dependencies reached by scene path are validated in `_ready()` rather than at first use: `$InstrumentSelector` in `app/instrument_select.gd`, alongside the existing `$JingleCamButton` check.
- **No fallbacks.** A failed validation calls `push_error` with what is wrong and what to do, and the node goes inert. No value is substituted. A carousel configured with fewer than three instruments fails loudly rather than presenting a screen with no way forward.
- **No media file is deleted.** §"The hard rule about assets". This plan moves and deletes nothing; it edits two attributes of one asset added this session.

## File-Level Compliance Review

| File | Change | Review points |
|---|---|---|
| `app/instrument_carousel.gd` | Signal, three exported values, three validations, two state members, `_handle_tap`, `_slot_at`, `_end_drag` signature | Travel is tracked in two dimensions and as a maximum. The missed-tap branch still settles. `_slot_at` skips invisible slots and resolves overlaps by cyclic distance. The three Continue comments are corrected. The configuration floor is three |
| `app/instrument_select.tscn` | `ContinueButton` and its two sub-resources removed; `JingleCamButton` widened, retexted, given an icon and a separation | The Jingle Cam sub-resources `StyleBoxFlat_0c8ss` and `StyleBoxFlat_nex8d` are kept. `base_offset_top` and `base_offset_bottom` are untouched, so the safe-area script keeps working |
| `app/instrument_select.gd` | Continue members and handler removed; carousel reference, validation, connection, and handler added | The header comment about `CameraServer` stays true. The Jingle Cam validation is unchanged |
| `app/instrument.tscn` | One node instanced after `Title` | Draws below the bell. No existing node's properties change |
| `app/shake_to_jingle.tscn` | New | Node2D root with the shared placement script, one Label child, `mouse_filter` ignore. No script of its own |
| `images/v2/photo_camera.svg` | Two attributes changed | `viewBox`, `fill`, and path data untouched. The `.import` sidecar is not edited and keeps `svg/scale=1.0` |
| `docs/system_design.md` | Three sections edited | §"The hard rule about assets", §"Conventions", §"Testing", and §"Platform notes" untouched |

The files read while planning this feature and found compliant, with no remediation required, are `app/sprite_position.gd`, `app/safe_area_margin.gd`, `app/instrument.gd`, `app/fun_fact_bubble.tscn`, `app/instruction_list.tscn`, `app/swipe_to_select.tscn`, `app/title.tscn`, and the three artwork scenes.

## Completion Criteria

1. The project opens with no import errors and no script errors, and every resource reference resolves.
2. `run/main_scene` in `project.godot` still points at the title screen, and `project.godot` is unmodified.
3. All fifteen manual verification steps have been executed on a handset and confirmed.
4. Every row of the acceptance table has been observed.
5. A search of the repository outside `legacy/` for `ContinueButton`, `_on_continue_pressed`, and `continue_button` returns nothing, and a search for `continue button` in comments returns nothing in `app/`.
6. The documentation updates in Phase 6 are complete.
7. The conventions checklist is satisfied for every touched file.

## Token and Design Considerations

This feature builds no skill, so there is no skill token cost to account for and no `input_limits` value to set.

## Teaching Topic

No teaching topic is needed and no entry is added to the tutor's `references/topics.md`. This feature changes what an audience member does on two screens of a Godot application; it does not change the developer's tooling, scripts, environment, or workflow, which is what the Mrs Puff Developer Teaching Assistant feature (C3_06) exists to teach.

## Acceptance Table

This replaces the unit-test table, for the reason given in §2. Every row is verified by hand on a handset.

| Behaviour under test | Concrete input | Expected result |
|---|---|---|
| Tap the centred bell | Paddle bells centred, one tap on the artwork | The play screen opens showing the paddle bells |
| Tap a side bell | Paddle bells centred, one tap on the strap bells at the right slot | The strap bells settle to the centre. The screen does not change |
| Tap the far side bell | Paddle bells centred, one tap on the pair at the left slot | The pair settles to the centre the short way. The screen does not change |
| Selection follows a tapped side bell | Tap the strap bells to the centre, then tap the centre | The play screen shows the strap bells |
| Tap that hits nothing | One tap 300 pixels right of the carousel, inside the drag band | No movement, no navigation |
| Tap that hits nothing mid-settle | Flick, then tap empty space while the carousel is still moving | The carousel settles onto a whole position. No navigation |
| Tap above the target rectangle | One tap on the "Swipe to Select Your Bells!" lettering | Nothing happens |
| Tap on the fun fact bubble | One tap on the bubble text | Nothing happens, and the swipe still works through that region |
| A flick is not a tap | A fast short drag released while still moving | The carousel advances one bell. No navigation |
| A slow drag is not a tap | A drag of 200 pixels released at rest | The carousel settles. No navigation |
| Travel measured in two dimensions | A press, 100 pixels of vertical movement, release | Treated as a drag. The carousel does not move and does not navigate |
| Out-and-back is not a tap | A press, 200 pixels right, back to the start, release | Treated as a drag. No navigation |
| Continue is gone | The bell selection screen at rest | One button at the bottom. No blue button in the bottom-right corner |
| Jingle Cam on one line | The bell selection screen at rest | Camera icon and "Jingle Cam" on one line, centred, clear of the home indicator |
| Jingle Cam still opens | One press on the widened button | The camera screen opens |
| The shake prompt is present | The play screen, any bell | "Shake to Jingle" in white below the logo and above the bell, clear of the notch |
| The shake prompt is inert | One tap on the prompt text | Nothing happens |
| Shaking is unaffected | A shake on the play screen | The chosen bell sounds as it did before |
| Back preserves the choice | Choose the pair, tap it, press Back | The selection screen opens with the pair centred |
| Fewer than three instruments is refused | Remove one entry from `instruments` in `app/instrument_carousel.tscn` and run | An error names the count and says three or more are required. No bells are drawn. Restore the third entry afterwards |
