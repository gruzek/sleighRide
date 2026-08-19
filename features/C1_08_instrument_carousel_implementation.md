---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Swiping Between Bells to Choose the One You Play
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.2
AUTHOR: George Ruzek
VALUE STATEMENT: A four-phase route from a screen showing one bell to a carousel the audience pushes around with a thumb, with the bell they land on carried through to the one they play.
LAST UPDATED: August, 19, 2026 07:41
---

# Implementation Plan for Swiping Between Bells to Choose the One You Play

This plan implements the Swipe Between Bells to Choose the One You Play feature (C1_08). It adds one resource type, three resource files, one autoload, and two scripts; rewrites `v2/instrument_carousel.tscn` from a single sprite into a carousel; rewires `v2/instrument.tscn` to show the chosen bell; and retires `v2/instrument_01.tscn`. The bell selection screen itself is left alone.

## Design decisions carried in from the specification and planning conversations

These were settled during ideation and planning and are implemented rather than re-opened.

- **The instrument list lives on the carousel**, as an exported array on `v2/instrument_carousel.tscn`, because that is where the developer wants to edit it, and the **autoload carries the chosen instrument itself rather than an index**. Version 0.1 of the specification put the list on the autoload, which also contradicted its own requirement 11; requirement 7 was rewritten in version 0.2 to match this decision, so the two documents now agree. Carrying the resource rather than an index is what makes the arrangement work: the play screen needs the chosen instrument, never the list, so the list can live wherever it is most convenient to edit.
- **The drag is handled inside the carousel scene**, against a rectangle computed from the viewport, with no node added to the bell selection screen.
- **No automated tests are written.** This is the developer's decision, consistent with the plan for the Fit the Audience Flow to Any Phone Screen feature (C1_07), and it moves the entire verification burden onto the manual steps in §4.
- **The scene has been renamed `v2/instrument_carousel.tscn`** by the developer, as more descriptive of what it now is, and version 0.2 of the specification carries the new name. Its script takes the matching name `v2/instrument_carousel.gd`, and the scene's own root node is renamed to `InstrumentCarousel` to agree with its file. The instance node inside the bell selection screen keeps the name `InstrumentSelector`, so that requirement 10's "the screen is left as it is" stays literally true; renaming it is cosmetic and nothing references it.
- The **governing documents named in the skill's project instructions do not exist in this repository**, and the shared web component library it references does not apply to a Godot project. This plan follows the conventions already established by the plan for the Fit the Audience Flow to Any Phone Screen feature (C1_07).

## The carousel model

The carousel is one continuous number, the carousel offset. Everything visible is a function of each instrument's signed cyclic distance from it.

```
n           = number of instruments
offset      = the carousel's continuous position; a whole number means an instrument is centred
d           = cyclic distance for instrument i: fposmod(i - offset, n), minus n when it exceeds n / 2
ad          = abs(d)

position    = Vector2(side_slot_distance * d, 0)
scale       = pow(side_slot_scale, ad)
opacity     = 1.0                                        when ad <= full_opacity_distance
              0.0                                        when ad >= invisible_distance
              1.0 - smoothstep(...)                      between the two
depth       = greater for smaller ad, so the centre draws in front
```

Three properties of this model are worth stating, because each is a requirement falling out of the model rather than a rule enforced on top of it.

**Three visible, and never a fourth.** With the opacity band ending at 1.5 and three instruments, the far side of the cycle is at exactly 1.5, so the instrument travelling from one side slot around to the other crosses over at zero opacity and the wrap is never seen. With four or five instruments the extras rest beyond 1.5 and are not drawn. This is requirement 4 in its entirety.

**Twice the size.** With `side_slot_scale` at 0.5, an instrument at a cyclic distance of one is exactly half the centre, which is requirement 5. The exponential form keeps scale continuous through and past the side slots, so a bell on its way out recedes rather than stopping at a fixed size and dissolving.

**Dragging and resting are the same state.** A drag sets the offset directly and a settle animates it to a whole number. There is no separate resting arrangement to reconcile with an animation, which is what makes requirement 2's drag-and-reverse and catch-mid-settle behaviour fall out for free rather than needing to be handled.

**The scale is applied to a slot, not to the artwork.** Each instrument is instanced under its own slot node, and the carousel drives the slot. This is what keeps requirement 5's division intact: whatever transform the developer authors on an artwork scene's own root composes with the carousel's, rather than being overwritten by it.

## Implementation Steps and Phases

### Phase 1: The instrument and the selection carrier

1. Create `v2/instrument_definition.gd`, a `Resource` with `class_name InstrumentDefinition`, holding one exported property: `artwork` (`PackedScene`), the artwork scene that draws this bell. It holds nothing about size or position, because requirement 5 places those in the artwork scene, and nothing about sound, which is Future work. It is named `instrument_definition` rather than `instrument` so that the play screen's script can take the name `v2/instrument.gd`, matching `v2/instrument.tscn` the way `v2/main.gd` matches `v2/main.tscn`.

2. Create three resource files under `v2/instruments/`: `sleighbells_01.tres`, `sleighbells_02.tres`, and `sleighbells_03.tres`, each an `InstrumentDefinition` pointing at the matching artwork scene in `v2/`. Separate files rather than sub-resources embedded in the carousel scene, because each bell's set of recordings will be added to its own file later, and because a bell is then a thing that can be pointed at.

3. Create `v2/instrument_selection.gd`, a plain script holding one variable: `chosen` (`InstrumentDefinition`), initially null. Register it in the `[autoload]` section of `project.godot` under the name `InstrumentSelection`. There is no autoload in this project today, so this section is new.

   This exists because the bell selection screen advances with `change_scene_to_file`, which destroys the scene tree and everything held in it. Nothing is written to disk: the choice lasts for the session, which is all the flow needs, since the audience member moves forward through the four screens once and there is no backward navigation.

### Phase 2: The carousel

4. Create `v2/instrument_carousel.gd`, a `@tool` script extending `v2/sprite_position.gd` by path.

   It extends the placement script rather than replacing it because the bell selection screen positions this scene through that script's exported properties, and it already carries `design_position` of 532 by 931 with centre anchoring and safe-area respect. A node can hold only one script, so inheriting is what lets the carousel be both a placed piece of screen furniture and a carousel. `_ready()` calls `super()` so the placement behaviour still runs.

   Exported properties, which together are requirement 11:

   | Property | Default | What it does |
   |---|---|---|
   | `instruments` | empty | The ordered list, `Array[InstrumentDefinition]` |
   | `side_slot_distance` | 170.0 | Design pixels from the centre slot to a side slot |
   | `side_slot_scale` | 0.5 | Scale at a cyclic distance of one; 0.5 is requirement 5's doubling |
   | `full_opacity_distance` | 1.0 | Cyclic distance out to which nothing is dimmed |
   | `invisible_distance` | 1.5 | Cyclic distance at which an instrument is fully invisible |
   | `drag_distance_per_position` | 420.0 | Design pixels of finger travel that equal one position |
   | `commit_threshold` | 0.5 | Fraction of a position a drag must pass to commit |
   | `flick_sensitivity` | 0.22 | How much release speed contributes to the committed target |
   | `settle_duration` | 0.32 | Seconds for the settle animation |
   | `drag_band_top_inset` | 300.0 | Design pixels below the top of the viewport where the drag band starts |
   | `drag_band_bottom_inset` | 230.0 | Design pixels above the bottom of the viewport where it ends |

   The numeric defaults are the values the motion prototype at `features/mockups/C1_08_instrument_carousel.html` runs at. They are a starting point for tuning in the editor, not a specification. The two band insets place the band below the Richmond Symphony logo, whose lower edge sits about 279 design pixels down, and above the continue button, whose upper edge sits 207 design pixels above the bottom.

5. Build the slots. For each instrument, add a `Node2D` slot as a child of the carousel and instance that instrument's artwork scene beneath it. Rebuild whenever `instruments` changes.

   **The slots must not be saved into the scene file.** A `@tool` script that adds children in the editor will have those children serialized into `v2/instrument_carousel.tscn` unless their `owner` is left unset. Add them without setting `owner`, so the scene file continues to hold nothing but the root.

6. Implement the carousel model above as the render step: for each slot, set `position`, `scale`, `modulate.a`, `z_index`, and `visible` from that instrument's cyclic distance. Transparency is set through `modulate` rather than `self_modulate` because it must reach the artwork scene's sprite, which is a child rather than the slot itself.

7. Implement the drag in `_unhandled_input`, handling `InputEventMouseButton` and `InputEventMouseMotion`.

   Mouse events rather than screen touch events, because Godot's `emulate_mouse_from_touch` setting is on by default, so a finger on the phone produces the same events as a mouse on the desktop and one code path serves both. Handling both families would process every touch twice.

   A press is ignored unless it falls inside the drag band, which is `get_viewport_rect()` reduced by the two band insets. This is requirement 9: because the rectangle is derived from the viewport rather than from the design canvas, it tracks the logo and the button as the screen grows, exactly as those two are anchored. Under the `canvas_items` stretch mode an input event's position is already in the same space as the viewport rectangle, so no conversion is needed.

   Requirement 9's rule that the continue button keeps its own rectangle needs no code. A `Button` marks a press inside itself as handled during interface input, which runs before unhandled input, so the carousel never sees it, never begins a drag, and therefore ignores the motion that follows.

   While dragging, `offset = drag_start_offset - (x - drag_start_x) / drag_distance_per_position`, so moving the finger left advances the carousel. Keep the last several time-and-offset samples so a release speed can be measured.

8. Implement the settle, which is requirement 3. On release, predict where the carousel is heading by adding the release speed scaled by `flick_sensitivity`, clamped so a single flick cannot skip more than one position; take the fractional part of that prediction; commit to the next position when it has passed `commit_threshold` and fall back otherwise. Animate to that whole number with a `Tween` over `settle_duration`, eased out.

   A press arriving while the tween is running kills the tween and begins a drag from the current offset. This is requirement 2's catch-mid-settle behaviour, and it is one line because the offset is a single number rather than an animation state.

9. Write the selection through. Whenever the nearest whole position changes, set `InstrumentSelection.chosen` to that instrument. Requirement 8 asks for the instrument centred at the moment the continue control is pressed, and keeping the autoload current as the carousel moves satisfies that without `v2/instrument_select.gd` having to change at all.

10. Guard the unsupported case. A list of exactly two is not supported by requirement 4, so `_ready()` raises an engine error naming the problem when `instruments.size() == 2`. This is a refusal, not a fallback: nothing is substituted and no default arrangement is drawn. A list of one instrument is supported and simply does not respond to dragging, since there is nowhere to go.

11. Rewrite `v2/instrument_carousel.tscn`: the root is renamed `InstrumentCarousel` to agree with the file and gains `v2/instrument_carousel.gd` in place of `v2/sprite_position.gd`, its `Sprite2D` child is removed, and the three instrument resources are assigned to `instruments`. Renaming a scene's root does not rename an existing instance of it, so the bell selection screen's node keeps its current name and its instance settings are untouched.

### Phase 3: The play screen

12. Create `v2/instrument.gd`, extending `Control`, and attach it to the root of `v2/instrument.tscn`, which carries no script today. On ready it instances `InstrumentSelection.chosen.artwork` beneath the holder node added in the next step.

    When `chosen` is null it raises an engine error and draws no instrument. This is the case of opening `v2/instrument.tscn` directly in the editor rather than reaching it through the flow, and no preview instrument is substituted, per the no-fallbacks rule. The flow's entry point is `v2/main.tscn`, and reaching the play screen through it always leaves a chosen instrument behind.

13. In `v2/instrument.tscn`, replace the `Instrument01` instance with a `Node2D` named `InstrumentHolder` carrying `v2/sprite_position.gd`, taking over the settings that instance holds today: `design_position` of 559 by 1247, centre anchoring on both axes, and safe-area respect. Give it `scale` of 2 by 2, which is the play screen's own size multiplier under requirement 8 and is where the retired scene's sprite scale of 2 goes. The holder's scale composes with whatever the artwork scene carries, so both remain the developer's to tune.

14. Delete `v2/instrument_01.tscn`, per requirement 6. It is a second copy of one bell's artwork carrying the placement script, and everything it does is now done by the artwork scene plus the holder.

### Phase 4: Tuning

15. Open `v2/instrument_carousel.tscn` and confirm the carousel draws in the editor, then tune the eleven exported properties by eye against the composition. This is the working step requirement 11 exists to enable, and the numeric defaults in step 4 are the starting point rather than the answer.

## Test Cases

**No automated tests are created or changed by this plan.** The developer has elected to verify this feature manually, as on the Fit the Audience Flow to Any Phone Screen feature (C1_07). There is accordingly no test-case table of unit or interface tests; the verification table in §4 carries the full burden, and the completion criteria in §7 depend on those manual checks rather than on a passing suite.

The consequence worth recording: the carousel's three pure calculations — cyclic distance, the opacity ramp, and the settle target — are the parts most likely to be wrong in ways that are invisible at rest. A carousel whose opacity band ends anywhere other than exactly 1.5 looks perfectly correct with three bells standing still and reveals itself only during a slow drag. Any later change to those three calculations should be re-verified against the full table below rather than by glancing at the screen.

## README and Documentation Updates

No README exists in this repository and none is created by this plan. Two pieces of knowledge introduced here are not evident from reading the code, and both are recorded as comment blocks where someone changing this behaviour will be looking:

- At the top of `v2/instrument_carousel.gd`, that the carousel is a single continuous offset and that every visible property is derived from cyclic distance, together with the reason the opacity band ending at 1.5 is what hides the wrap.
- At the top of `v2/instrument_selection.gd`, that it exists solely because `change_scene_to_file` destroys the tree, and that nothing is persisted to disk.

## Manual Verification Steps

Because there are no automated tests, these steps are the verification. Work through the table rather than glancing at the screen, since several of the behaviours are only visible mid-drag.

| Behaviour under test | How to exercise it | Expected result |
|---|---|---|
| Three bells visible at rest | Open the bell selection screen | Chosen bell centred, one neighbour each side, both half its size, both drawn behind it, none dimmed |
| Doubling | Compare centre against side | The centre bell is exactly twice the size of each neighbour |
| Advance | Drag right to left across one position | The right bell becomes centre, the centre bell moves to the left slot, the left bell arrives at the right slot |
| Wrap is invisible | Drag slowly, right to left, and watch the left slot | The bell leaving the left slot fades to nothing before it reappears at the right; no bell is ever seen crossing the middle or popping into place |
| Reverse mid-drag | Drag halfway, then drag back without lifting | The bells return to where they started; nothing commits |
| Catch mid-settle | Release mid-position, then press again while it is still moving | The carousel is caught where it is and follows the finger from there; it does not jump or restart |
| Double flick | Flick twice quickly in the same direction | The carousel advances two positions rather than dropping the second flick |
| Commit threshold | Drag just past half a position and release | Commits to the next bell |
| Fall back | Drag less than half a position, slowly, and release | Returns to the current bell |
| Flick override | Flick a short distance quickly and release | Commits to the next bell despite the short drag |
| Drag band, top | Begin a drag on the Richmond Symphony logo | Nothing moves |
| Drag band, bottom | Begin a drag on the continue button | The button behaves normally; the carousel does not move |
| Drag band, inside | Begin a drag on the "Swipe to Select Your Bells!" line, and again on Winnie | The carousel moves in both cases |
| Only the bells move | Drag anywhere in the band | Logo, instruction line, vignette, Winnie and the button all hold still |
| Selection carries through | Choose each of the three bells in turn and press continue | The play screen shows the bell that was centred, at the play screen's larger size |
| One instrument | Temporarily assign a single instrument | It is centred, and dragging does nothing |
| Four instruments | Temporarily assign four | Exactly three are visible at any moment; the fourth is not drawn |
| Two instruments | Temporarily assign two | An engine error naming the unsupported count appears; nothing is silently substituted |
| Editor preview | Change `side_slot_distance` in the inspector | The arrangement redraws in the editor viewport |
| Scene file stays clean | Change a property, save, and inspect `v2/instrument_carousel.tscn` | The file holds only the root node; no slots or artwork instances have been serialized into it |
| Placement still works | Change the instance's `design_position` on the bell selection screen | The whole carousel moves, keeping its arrangement |

**Devices and viewports.** Repeat the advance, wrap and drag-band rows at the design canvas size of 1080 by 1920, on an iPhone 13 Pro at 1080 by 2337, and in a browser window resized while running. The drag band is the row that matters most across sizes, because its rectangle is derived from the viewport and a mistake there shows up as a dead zone only on a taller screen.

**On the device.** Build and run on the iPhone and walk the full flow. Confirm the drag responds to a finger, since this is the step that exercises the touch-to-mouse emulation the input handling depends on, and confirm the continue button is still comfortable to press without nudging the carousel.

## Coding Standards Compliance Checklist

The application coding standards document named in the skill's project instructions does not exist in this repository. The following are the conventions this codebase actually demonstrates, and this plan conforms to each.

- Tab indentation in GDScript, matching `v2/main.gd`, `v2/instructions.gd`, and `v2/sprite_position.gd`.
- A one-line comment at the top of each script naming the file and its role, matching the existing scripts.
- Static typing on declarations and return types, including `-> void` on functions that return nothing, as the existing scripts do.
- Signals connected in `_ready()` rather than in the scene file, matching `v2/main.gd` and `v2/instructions.gd`.
- Scene, script and resource files named in lower snake case under `v2/`, matching `instrument_select.tscn` and `instrument_select.gd`.
- Exported properties for anything art-directed, with the value authored in the scene rather than compiled into the script, matching `v2/sprite_position.gd` and `v2/safe_area_margin.gd`.
- `@tool` scripts recompute rather than adjust in place, so repeated recomputes never compound, matching the note at the top of `v2/safe_area_margin.gd`.
- No fallbacks. The play screen raises an error when no instrument has been chosen rather than substituting one, and the carousel raises an error on an unsupported instrument count rather than drawing something approximate.

## File-Level Compliance Review

| File | Change |
|---|---|
| `v2/instrument_definition.gd` | New. The `InstrumentDefinition` resource, holding one artwork scene |
| `v2/instruments/sleighbells_01.tres`, `sleighbells_02.tres`, `sleighbells_03.tres` | New. One resource per bell |
| `v2/instrument_selection.gd` | New. The autoload carrying the chosen instrument across the scene change |
| `v2/instrument_carousel.gd` | New. The carousel, extending `v2/sprite_position.gd` |
| `v2/instrument.gd` | New. The play screen script that instances the chosen bell |
| `v2/instrument_carousel.tscn` | Sprite child removed, carousel script attached, instrument list assigned |
| `v2/instrument.tscn` | `Instrument01` instance replaced by `InstrumentHolder`, root script attached |
| `v2/instrument_01.tscn` | Deleted |
| `project.godot` | New `[autoload]` section registering `InstrumentSelection` |
| `v2/sleighbells_01.tscn`, `sleighbells_02.tscn`, `sleighbells_03.tscn` | Unchanged. The developer authors size and position in these |
| `v2/instrument_select.tscn`, `v2/instrument_select.gd` | Unchanged, per requirement 10 |
| `v2/sprite_position.gd`, `v2/safe_area_margin.gd` | Unchanged. Extended by the carousel, not modified |
| `v2/main.tscn`, `v2/main.gd`, `v2/instructions.tscn`, `v2/instructions.gd` | Unchanged. The welcome and instructions screens are outside this feature |

Nothing in the version 1 build is touched: `main.tscn`, `start_overlay.gd`, `bells/`, `foreground/`, and `background/` are all outside this plan.

## Completion Criteria

1. `v2/instrument_carousel.tscn` holds a carousel of three bells, with the list assigned in the inspector and no sprite of its own.
2. Dragging inside the band moves the bells continuously with the finger, can be reversed mid-gesture, and can be caught while settling.
3. Releasing settles onto one bell, judged by both drag distance and release speed.
4. Exactly three bells are visible at any moment, the wrap is never seen, and the centre bell is exactly twice the size of its neighbours.
5. The bell centred when continue is pressed is the bell drawn on the play screen.
6. `v2/instrument_01.tscn` is gone and nothing references it.
7. `v2/instrument_select.tscn` and `v2/instrument_select.gd` are unchanged.
8. Saving `v2/instrument_carousel.tscn` leaves the file holding only its root node.
9. Every row in the §4 verification table passes, including the on-device walk of the flow.

## Token and Design Considerations

This feature builds no skill, so there is no `input_limits` value, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed; this feature adds no capability the tutor covers.
