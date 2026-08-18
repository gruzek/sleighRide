---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Fitting the Audience Flow to Any Phone Screen
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: A five-phase route from a layout nailed to one imaginary screen to one that composes itself on every device in the hall, with the artwork left exactly where it was drawn.
LAST UPDATED: August, 18, 2026 11:42
---

# Implementation Plan for Fitting the Audience Flow to Any Phone Screen

This plan implements the Fit the Audience Flow to Any Phone Screen feature (C1_07). It changes one project setting, adds two small shared scripts, extracts six new scenes, normalizes four existing ones, and rewires the four screens of the version 2 flow to place their contents relative to the device screen rather than to fixed coordinates.

## Design decisions carried in from the specification conversation

These were settled during ideation and planning and are implemented rather than re-opened.

- The anchor is expressed as **two independent enumerations**, horizontal and vertical, rather than a single nine-point value or a pair of normalized floats. All three compute identically underneath; two enumerations read clearly in the inspector and cannot express an invalid state.
- The **title block stays a single scene** containing both the vignette glow and the logo, because both are to be animated later and may carry a particle effect. It therefore takes one anchor and one safe-area setting for the pair.
- **No automated tests are written.** This is the developer's decision, recorded in §2, and it moves the entire verification burden onto the manual steps in §4.
- The **governing documents named in the skill's project instructions do not exist in this repository**, and the shared web component library it references does not apply to a Godot project. This plan follows the conventions already established by the Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05).

## The placement rule

Every piece of artwork resolves its position from four inputs: its authored coordinate in the design canvas, a horizontal anchor, a vertical anchor, and whether it respects the safe area.

```
ax, ay      = normalized anchor from the two enumerations (LEFT/TOP = 0.0, CENTER = 0.5, RIGHT/BOTTOM = 1.0)
D           = design canvas size, read from the project's viewport width and height settings
R           = the reference rectangle: the viewport rectangle, or the safe-area rectangle when respected
anchor_in_R = R.position + Vector2(ax * R.size.x, ay * R.size.y)
anchor_in_D = Vector2(ax * D.x, ay * D.y)
position    = anchor_in_R + (design_position - anchor_in_D)
```

Where the viewport equals the design canvas, the result is identical to the authored coordinate. Where the viewport has grown, the piece keeps its measured distance from the edge it is anchored to.

**The authored coordinate lives in an exported `design_position` property, not in the node's own `position`.** This matters because the script runs in the editor: a script that derived placement from `position` and then wrote back to `position` would overwrite the authored coordinate every time a scene was opened, and the original values would be lost on the next save. Keeping `design_position` as input and `position` as pure output makes the script safe to run in the editor. The working consequence is that artwork is repositioned by editing `design_position`, not by dragging the node; dragging produces a change the script will discard on its next recompute.

## Implementation Steps and Phases

### Phase 1: Project configuration and backgrounds

1. Add `window/stretch/aspect="expand"` to the `[display]` section of `project.godot`, alongside the `window/stretch/mode="canvas_items"` already present. This is the whole of requirement 1.
2. Re-anchor the `background` ColorRect in each of the four screens to the full-rect preset with zero offsets, replacing the current hand-placed offsets of `-8, 2, 1084, 1915`. Under the expand aspect the viewport is taller or wider than the design canvas, and the current rectangle would leave an uncovered strip along the grown edge. The four screens are `v2/main.tscn`, `v2/instructions.tscn`, `v2/instrument_select.tscn`, and `v2/instrument.tscn`.

### Phase 2: The shared scripts

3. Create `v2/sprite_position.gd`, a `@tool` script extending `Node2D`, which is the shared placement script of requirements 2, 3, and 4. Because `Sprite2D` extends `Node2D`, the one script attaches both to an extracted scene's root and to a loose sprite that has not been extracted yet.

   Exported properties: `design_position` (Vector2, the authored coordinate), `horizontal_anchor` (enum LEFT, CENTER, RIGHT), `vertical_anchor` (enum TOP, CENTER, BOTTOM), and `respect_safe_area` (bool).

   Behavior: compute and assign `position` per the placement rule on `_ready()`, on the viewport's `size_changed` signal, and whenever an exported property is set while running in the editor. Reads the design canvas from `ProjectSettings` rather than holding its own copy of 1080 by 1920.

   Safe-area handling: `DisplayServer.get_display_safe_area()` returns a rectangle in screen pixels, which is not the same space as the viewport once the stretch settings are applied. Convert by the ratio of the viewport size to the window size before use. On a desktop or a browser the call returns the full screen, so the conversion yields the full viewport and the setting has no effect there; this is the API reporting the truth, not a fallback.

4. Create `v2/safe_area_margin.gd`, a `@tool` script extending `Control`, which holds a bottom-anchored control clear of the home indicator. This is the control-side half of requirement 5, and it exists because Godot's Control anchoring measures from the physical window edge with no awareness of the safe area. It adjusts the node's bottom offset by the safe-area inset, converted to viewport space by the same ratio as above, and recomputes on `size_changed`.

### Phase 3: Scene extraction and origin normalization

5. Extract six new scenes, each a `Node2D` root carrying `v2/sprite_position.gd`, with the sprite offset so that the artwork's visual center sits on the root's origin:

   | New scene | Contents | Extracted from |
   |---|---|---|
   | `v2/straight_red_tree.tscn` | StraightRedTree | `v2/main.tscn` |
   | `v2/blue_snowflake.tscn` | BlueSnowflake | `v2/main.tscn` |
   | `v2/holiday_sleigh_bells.tscn` | HolidaySleighBells | `v2/main.tscn` |
   | `v2/play_along.tscn` | PlayAlongAtLetItSnow | `v2/main.tscn` |
   | `v2/instruction_list.tscn` | TurnUpYourVolume, HoldYourPhoneSecurely, ShakeGentlyOrTapToPlay, WaitForTheConductorsCue | `v2/instructions.tscn` |
   | `v2/swipe_to_select.tscn` | SwipeToSelectYourBells | `v2/instrument_select.tscn` |

   The instruction list is one scene holding all four lines, per requirement 6, so the stack cannot drift apart. Its four sprites keep their relative spacing exactly as authored, at (533, 409), (561, 565), (564, 746), and (560, 922), rebased so their combined visual center sits on the root.

6. Normalize the four scenes already extracted by hand to the same convention, giving each root the placement script and moving its children to root-relative coordinates centered on that root:

   - `v2/title.tscn` is the significant one. Its children currently sit at absolute design coordinates, the vignette glow at (532.5, 466.4) and the logo at (523, 163), with the root left at the origin, which is why anchoring the block has no meaning today. Both children move to coordinates relative to a root placed at the combined artwork's visual center. The scene keeps both children so it can be animated as one, per the decision above.
   - `v2/winnie.tscn`, whose child sits at (66, 30).
   - `v2/instrument_selector.tscn`, whose child sits at (0, 4).
   - `v2/instrument_01.tscn`, whose child sits at (0, 14).

   Because `v2/title.tscn` is instanced in all four screens with no position override, every screen that instances it gains an explicit `design_position` in this step.

### Phase 4: Apply placement across the four screens

7. Replace the loose sprites in each screen with instances of the new scenes, and set each instance's `design_position` to the coordinate that sprite carries today, so that no artwork is repositioned by hand. This is requirement 2 in practice: the migration copies existing coordinates, it does not re-derive them.

8. Set the anchor and safe-area settings per instance. The intent, from requirement 5, is that structural content stays clear of the Dynamic Island and the home indicator while decorative artwork runs past the edge:

   | Instance | Horizontal | Vertical | Respects safe area |
   |---|---|---|---|
   | Title block (all four screens) | CENTER | TOP | yes |
   | Holiday Sleigh Bells title art | CENTER | TOP | yes |
   | Play-along line | CENTER | TOP | yes |
   | Instruction list | CENTER | TOP | yes |
   | Swipe-to-select line | CENTER | TOP | yes |
   | Instrument selector, first instrument | CENTER | CENTER | yes |
   | Winnie (all three screens) | CENTER | BOTTOM | no |
   | Straight red tree | LEFT | BOTTOM | no |
   | Blue snowflake | RIGHT | CENTER | no |

9. Confirm each screen's node order still places the button above the artwork it overlaps, since extraction rewrites the scene files. On `v2/main.tscn` the start button currently sits above Winnie in the tree, which is what keeps it legible against the mascot.

### Phase 5: Button anchoring

10. Re-anchor the three buttons to the bottom edge, converting their current absolute offsets to bottom-relative ones. All three carry identical geometry today at `220, 1713, 880, 1823` within the 1920-tall design canvas, which becomes `anchor_top` and `anchor_bottom` of 1.0 with offsets of `-207` and `-97`, and `anchor_left` and `anchor_right` of 0.5 with offsets of `-320` and `340`. The horizontal offsets preserve the existing centre of 550 rather than correcting it to 540, because requirement 2 keeps authored composition intact.

11. Attach `v2/safe_area_margin.gd` to each of the three buttons, so the 97-pixel bottom margin is measured from the safe area rather than the physical screen edge. The three buttons are the start button on `v2/main.tscn` and the continue buttons on `v2/instructions.tscn` and `v2/instrument_select.tscn`.

12. Leave the buttons' styling untouched, per requirement 7. The duplicated `StyleBoxFlat` sub-resources across the three screens are deliberately not consolidated and no shared button scene is created.

## Test Cases

**No automated tests are created or changed by this plan.** The developer has elected to verify this feature manually and has asked that no test scripts be written. There is accordingly no test-case table; the verification matrix in §4 carries the full burden, and the completion criteria in §7 depend on those manual checks rather than on a passing suite.

The consequence worth recording: requirements 1 and 2 are the two most likely to regress silently, because a layout that is wrong at a viewport size nobody has opened looks perfectly correct at every size somebody has. Any later change to the stretch settings, the placement rule, or the design canvas dimensions should be re-verified against the full matrix below rather than against a single device.

## README and Documentation Updates

No README exists in this repository and none is created by this plan. The one piece of knowledge this feature introduces that is not evident from reading the code is the authoring rule: artwork is repositioned by editing `design_position`, never by dragging the node. That rule is recorded as a comment block at the top of `v2/sprite_position.gd`, which is where someone changing a layout will be looking.

## Manual Verification Steps

Because there are no automated tests, these steps are the verification. Work through the matrix rather than checking a single device, since the whole point of the feature is behavior at sizes that cannot be eyeballed from one screen.

**In the Godot editor.** Open each of the four screens and confirm the composition matches what it looked like before this work, since at the design canvas size the placement rule resolves to the authored coordinate exactly. Any visible shift at design size means the placement rule or a migrated coordinate is wrong. Confirm the placement script is running in the editor by changing a `design_position` and watching the node move.

**Verification matrix.** For each combination below, confirm every listed condition.

| Target | Viewport | What to confirm |
|---|---|---|
| Design canvas | 1080 × 1920 | Composition identical to before the change, on all four screens |
| iPhone 13 Pro | 1080 × 2337 | No black bands; background covers edge to edge; logo clear of the Dynamic Island; buttons clear of the home indicator; Winnie and the trees run off the bottom edge rather than stopping short |
| iPad Air 11-inch | 1334 × 1920 | No black bands; buttons still on screen and bottom-anchored; centered content still centered against the wider viewport |
| Browser, resized | arbitrary | Layout recomputes as the window is dragged, rather than only on load |

**On the device.** Build and run on the iPhone and walk the full flow: welcome, instructions, bell selection, bell. On each screen confirm the button sits comfortably above the home indicator and is comfortable to reach, and that no artwork is clipped in a way it was not before. This is also the step that confirms the safe-area conversion is correct, since the simulator and the editor both report a full-screen safe area and cannot exercise that code path.

## Coding Standards Compliance Checklist

The application coding standards document named in the skill's project instructions does not exist in this repository. The following are the conventions this codebase actually demonstrates, and this plan conforms to each.

- Tab indentation in GDScript, matching `start_overlay.gd`, `v2/main.gd`, and `v2/instructions.gd`.
- A one-line comment at the top of each script naming the file and its role, matching the existing scripts.
- Static typing on declarations and return types, including `-> void` on functions that return nothing, as the existing scripts do.
- Signals connected in `_ready()` rather than in the scene file, matching `v2/main.gd` and `v2/instructions.gd`. Connecting in both places raises a duplicate-connection error at runtime.
- Scene and script files named in lower snake case under `v2/`, matching `instrument_select.tscn` and `instrument_select.gd`.
- No fallbacks. The safe-area code path uses whatever `DisplayServer.get_display_safe_area()` reports, with no substituted default when the rectangle equals the full screen.

## File-Level Compliance Review

| File | Change |
|---|---|
| `project.godot` | Add `window/stretch/aspect="expand"` |
| `v2/sprite_position.gd` | New. The shared placement script |
| `v2/safe_area_margin.gd` | New. Control-side safe-area inset for the buttons |
| `v2/straight_red_tree.tscn`, `v2/blue_snowflake.tscn`, `v2/holiday_sleigh_bells.tscn`, `v2/play_along.tscn`, `v2/instruction_list.tscn`, `v2/swipe_to_select.tscn` | New. Extracted artwork scenes |
| `v2/title.tscn` | Root moved to visual center, children rebased, placement script attached |
| `v2/winnie.tscn`, `v2/instrument_selector.tscn`, `v2/instrument_01.tscn` | Same normalization |
| `v2/main.tscn` | Background re-anchored, four sprites replaced by instances, button bottom-anchored |
| `v2/instructions.tscn` | Background re-anchored, four instruction sprites replaced by one instance, button bottom-anchored |
| `v2/instrument_select.tscn` | Background re-anchored, one sprite replaced by an instance, button bottom-anchored |
| `v2/instrument.tscn` | Background re-anchored, instance placement settings applied |
| `v2/main.gd`, `v2/instructions.gd`, `v2/instrument_select.gd` | Unchanged. Screen navigation is out of scope |

Nothing in the version 1 build is touched, per requirement 8: `main.tscn`, `start_overlay.gd`, `bells/`, `foreground/`, and `background/` are all outside this plan.

## Completion Criteria

1. `project.godot` carries both `window/stretch/mode="canvas_items"` and `window/stretch/aspect="expand"`.
2. `v2/sprite_position.gd` exists, runs in the editor, and drives every piece of artwork across the four screens.
3. All nine previously loose sprites are gone from the screen files, replaced by instances of six new scenes.
4. All four previously extracted scenes carry the placement script with their roots at the artwork's visual center.
5. The three buttons are bottom-anchored and hold their margin above the home indicator.
6. Every condition in the §4 verification matrix passes, including the on-device walk of all four screens.
7. The composition at the design canvas size is visually identical to the composition before this work.

## Token and Design Considerations

This feature builds no skill, so there is no `input_limits` value, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed; this feature adds no capability the tutor covers.
