---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Drawing the Vignette in Code So Its Glow Is Clean and Fits Every Screen
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: A four-phase route from a washed-out exported image to an oval the application draws for itself, in the right color, at the right proportion, on any screen it is opened on.
LAST UPDATED: August, 22, 2026 11:44
---

# Implementation Plan for Drawing the Vignette in Code So Its Glow Is Clean and Fits Every Screen

This plan implements the Draw the Vignette in Code So Its Glow Is Clean and Fits Every Screen feature (C1_11). It adds one shader and one script, rewrites `app/vignette.tscn` from a sprite into a shaded rectangle, removes the placement overrides that rewrite leaves stranded on four screens, and archives the retired image. No screen's background, logo, button, or layout is touched.

## Design decisions carried in from the specification and planning conversations

These were settled during ideation and planning and are implemented rather than re-opened.

- **The restructure has landed since the specification was written.** The specification named paths under `v2/`, and anticipated that the Give Each Chosen Bell Its Own Voice and Close the Audience Flow feature (C1_10) would move them. It has: `v2/` is now `app/`, and `shaders/` exists holding `transparent_cloud.gdshader`. This plan therefore targets `app/vignette.tscn` and `shaders/vignette.gdshader`. `images/v2/` was not renamed by the restructure, so the archive destination `legacy/images/v2/` still mirrors the path the image came from, and that directory already exists.
- **A small script hands the shader the size of the area it draws into.** The specification's requirement 1 puts placement in the shader, and mechanically the shader cannot get all the way there: a fragment shader on a `ColorRect` receives `UV`, which runs 0 to 1 down the rect however tall the rect is, and the oval's geometry is stated in fractions of the viewport's *width*. Reading the ratio from `SCREEN_PIXEL_SIZE` is correct at runtime but reports whatever viewport is rendering, which while authoring is the editor's own, so the preview would show the wrong shape. The script is the smaller cost, and the editor preview is the point of exposing the look as tunable parameters at all.
- **The vignette rectangle carries `mouse_filter = MOUSE_FILTER_IGNORE`, and this is load-bearing rather than tidiness.** `ColorRect` defaults to `MOUSE_FILTER_STOP` in Godot 4.6, confirmed by inspection, and `app/instrument_carousel.gd` reads its drag through `_unhandled_input`. A full-viewport control set to stop would consume the touch on the bell selection screen before it ever became unhandled, and the carousel would stop responding. `app/instrument_select.tscn` already sets `mouse_filter = 2` on both its root and its background for exactly this reason; the vignette joins them.
- **No automated tests are written.** This is the developer's decision, carried forward from the plans for the Fit the Audience Flow to Any Phone Screen feature (C1_07), the Swipe Between Bells to Choose the One You Play feature (C1_08), and the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09). It moves the entire verification burden onto the manual steps in §4.
- **The README's structure table is left alone.** It is stale from the restructure: it still shows `v2/`, lists `background/`, `foreground/` and `bells/` as live, and has no row for `app/`, `shaders/`, or `legacy/`. Correcting it belongs to the Give Each Chosen Bell Its Own Voice and Close the Audience Flow feature (C1_10), whose build is evidently still in flight, and rewriting it here risks colliding with that work.
- **The pixels outside the oval are not discarded.** The rectangle covers the viewport on all four screens, so there is a real fill-rate cost to blending fully transparent pixels. Adding `discard` is an optimization nobody asked for and would complicate the shader that the later effect has to build on. The cost is accepted.
- The **governing documents named in the skill's project instructions do not exist in this repository**, and the shared web component library it references does not apply to a Godot project. This plan follows the conventions already established by the earlier plans in `features/`.

## The oval

The oval is defined once, in fractions of the viewport's width, and every visible property is derived from a single number: how far a pixel is from the center as a fraction of the distance to the oval's own edge along that same direction.

The design file places the oval in a frame 485 units wide, at 630.18 by 484.76, with its left edge at −72.71 and its top edge at −199.61. Dividing through by the frame width gives the constants the shader holds. The horizontal center is 0.5 exactly; the design file's 0.4997526 is the drawing tool's rounding, and the developer confirmed the oval is centered.

| Quantity | Fraction of viewport width | At width 1080 | At width 3413 |
|---|---|---|---|
| Center, horizontal | 0.5 | 540.0 | 1706.7 |
| Center, vertical | 0.0881856 | 95.2 | 301.0 |
| Radius, horizontal | 0.6496701 | 701.6 | 2217.5 |
| Radius, vertical | 0.4997526 | 539.7 | 1705.9 |
| Overhang past each side edge | 0.1496701 | 161.6 | 510.9 |

Both radii scale from the same number, which is what holds the proportion at 1.2999835 to 1 on every screen. The second column is a portrait phone, where the engine's canvas stays 1080 units wide however tall the phone is. The third is a landscape desktop window, which is where the rule earns its place.

Given a pixel's position `here` inside the rectangle and the viewport width `w`:

```
offset             = (here - center * w) / (radius * w)
elliptical_radius  = length(offset)          // 0 at the centre, 1 on the boundary
fade               = smoothstep(core_radius, 1.0, elliptical_radius)
alpha              = pow(1.0 - fade, edge_softness)
```

`core_radius` defaults to 0.45, so the oval is fully opaque out to 0.45 and eases to nothing at the boundary. `edge_softness` defaults to 1.0, the plain smooth ease; the specification pins the outer stop at the boundary and the inner stop is already `core_radius`, so an exponent is what is left to shape the fade with. Values above 1.0 fade sooner, below 1.0 hold opacity further out. At the defaults the alpha runs 1.000 at 0.45, 0.817 at 0.60, 0.301 at 0.80, and 0.000 at 1.00.

The color is emitted unchanged at every pixel and only the alpha varies. That is the whole of the fix for the white haze: there is no second color present for the fade to travel through, so the wash cannot reappear.

## Implementation Steps and Phases

### Phase 1: The shader and the scene

1. **Write `shaders/vignette.gdshader`**, in the style of `shaders/transparent_cloud.gdshader`: a commented uniform block, then a short `fragment()`.

```glsl
shader_type canvas_item;

/* The oval, in fractions of the viewport's width. Both radii scale from the same
   number, which is what holds the proportion fixed on any screen. */
uniform vec2 oval_center = vec2(0.5, 0.0881856);
uniform vec2 oval_radius = vec2(0.6496701, 0.4997526);

/* The look */
uniform vec3 vignette_color : source_color = vec3(0.07450980, 0.10196078, 0.16862746);
uniform float peak_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float core_radius : hint_range(0.0, 1.0) = 0.45;
uniform float edge_softness : hint_range(0.1, 4.0) = 1.0;

/* Written by app/vignette.gd whenever the rectangle resizes. The rectangle is
   anchored to the whole viewport, so this is the viewport's size in design-canvas
   units. A fragment shader has no way to read it for itself: UV runs 0 to 1 down
   the rectangle however tall the rectangle is. */
uniform vec2 viewport_size = vec2(1080.0, 1920.0);

void fragment() {
	float w = max(viewport_size.x, 1.0);
	vec2 here = UV * viewport_size;
	vec2 offset = (here - oval_center * w) / (oval_radius * w);

	// Distance from the centre as a fraction of the distance to the oval's own edge:
	// 0 at the centre, 1 everywhere on the boundary, whatever the oval's proportions.
	float elliptical_radius = length(offset);

	float fade = smoothstep(core_radius, 1.0, elliptical_radius);
	float alpha = pow(1.0 - fade, edge_softness);

	// The colour is constant and only the alpha varies. The image this replaced was
	// flattened onto white before its alpha channel was written, so its fade carried
	// white in the colour channels; holding one colour is what makes that impossible.
	COLOR = vec4(vignette_color, peak_alpha * alpha);
}
```

2. **Write `app/vignette.gd`**, a `@tool` script extending `ColorRect`. It exists for one reason, stated at the top of the file, and does one thing.

```gdscript
# vignette.gd (app) - hands the shader the size of the area it is drawing into.
#
# The oval's geometry is stated in fractions of the viewport's width, so the shader has
# to convert a vertical position into that same unit. UV cannot do it alone: it runs 0
# to 1 down the rectangle however tall the rectangle is. This rectangle is anchored to
# the whole viewport, so its own size is the number the shader needs, and a fragment
# shader has no way to read it. This script is that one wire.
@tool
extends ColorRect

func _ready() -> void:
	resized.connect(_publish_size)
	_publish_size()

func _publish_size() -> void:
	# Typed deliberately. A vignette without a ShaderMaterial is a broken scene, and
	# this raises rather than quietly drawing nothing.
	var shader_material: ShaderMaterial = material
	shader_material.set_shader_parameter("viewport_size", size)
```

3. **Rewrite `app/vignette.tscn`.** The root node changes from a `Node2D` running `app/sprite_position.gd` to a `ColorRect` running `app/vignette.gd`, anchored to the full rectangle, with `mouse_filter` set to ignore and a `ShaderMaterial` carrying the new shader. The `Sprite` child and the texture reference are removed. The rectangle's own `color` is left at opaque white and is irrelevant, since `fragment()` overwrites `COLOR` outright; it is not a value to tune.

4. **Confirm the preview in the editor.** Open `app/main.tscn` and check that the oval draws at the design canvas size, centered horizontally, hanging off the top, with a solid core behind the logo. This is the check that the `@tool` script and the size wire work before four scenes depend on them.

### Phase 2: The four screens

5. **Remove the stranded placement overrides.** Every screen that instances the vignette carries properties belonging to `app/sprite_position.gd`, which the root no longer runs. Remove `design_position` from `app/main.tscn`, `app/instructions.tscn`, `app/instrument_select.tscn`, and `app/instrument.tscn`, and additionally remove `horizontal_anchor`, `vertical_anchor`, and `respect_safe_area` from `app/instrument.tscn`.

6. **Open and re-save each of the four scenes.** Changing the root node type of an instanced scene leaves the parent scenes holding property overrides that no longer exist, which the engine reports on load. Opening and saving each scene is what clears them from the files rather than leaving them to be reported on every future load.

7. **Confirm the draw order is unchanged.** The vignette stays the second child on all four screens, drawn above `background` and below `Title`. Nothing about the change of node type alters this, since draw order follows tree order either way, but it is worth looking at rather than assuming.

### Phase 3: Archive the retired image

8. **Move `images/v2/vignette_glow.png` and `images/v2/vignette_glow.png.import` into `legacy/images/v2/`.** Nothing is deleted. The directory exists and already carries the marker at `legacy/.gdignore` that tells the engine to skip it, so the moved image is not imported, cannot be referenced, and cannot reach an export bundle.

9. **Confirm nothing else referenced it.** `app/vignette.tscn` was the only reference in the repository, by both path and resource identifier, and phase 1 removed it. Reopen the project and confirm it loads with no missing-resource error; this also clears the stale entry the import cache holds under `.godot/`.

### Phase 4: Tune and verify

10. **Tune `core_radius` and `edge_softness` by eye** in the inspector, on the instructions screen against its near-black background. The defaults in this plan are the specification's; adjusting them is the reason they are parameters. Anything settled on is written into the shader's defaults rather than left as a per-screen override, so all four screens stay identical.

11. **Work through the verification table in §4**, including the run at a resized window, and build to the handset for the on-device pass.

## Test Cases

**No automated tests are created or changed by this plan.** The developer has elected to verify this feature manually, as on the three features preceding it. There is accordingly no test-case table of unit or interface tests; the verification table in §4 carries the full burden, and the completion criteria in §7 depend on those manual checks rather than on a passing suite.

The consequence worth recording: the two things most likely to be wrong here are invisible at rest on a phone. The proportion rule only diverges from a fixed size on a viewport wider than the design's own, so a shader that ignores `viewport_size` entirely would look perfectly correct on every handset and reveal itself only in a resized browser window. And the `mouse_filter` setting has no visual symptom at all — it shows up as a carousel that has silently stopped responding to a finger, two screens away from anything this feature changed. Both have their own row below, and both should be re-checked after any later change to this scene.

## README and Documentation Updates

The README's repository-structure table is stale from the restructure and is deliberately not corrected here, for the reason recorded among the design decisions above. This feature adds no directory of its own — `shaders/` already exists — so the table needs no new row on this feature's account.

Two pieces of knowledge introduced here are not evident from reading the code, and both are recorded as comment blocks where someone changing this behaviour will be looking:

- At the top of `app/vignette.gd`, why the script exists at all: that the geometry is stated in fractions of the viewport's width and that a fragment shader cannot read the rectangle's size for itself.
- In the uniform block of `shaders/vignette.gdshader`, that holding one colour and varying only alpha is the fix rather than an incidental choice, and what went wrong with the image it replaced.

## Manual Verification Steps

Because there are no automated tests, these steps are the verification. Two rows exercise behaviour that cannot be seen on a handset at all.

| Behaviour under test | How to exercise it | Expected result |
|---|---|---|
| The white is gone | Open the instructions screen and sample pixels down a vertical line through the middle, from the top of the screen to y = 800 | Every sample lies between `#131A2B` and the background `#05070C`; no pixel anywhere is lighter than `#131A2B` in any channel |
| The colour is right | Sample a pixel inside the solid core, for instance at (540, 150) on the instructions screen | Exactly `#131A2B` |
| The core is solid | Look at the region roughly x 224 to 856, y 0 to 338 on the instructions screen | Flat, with no gradient visible inside it |
| The fade has no band | Look along the boundary of the core, all the way round | The transition out of the core is smooth; no ring or step where the falloff begins |
| The shape is an oval | Look at the whole vignette | An ellipse wider than it is tall, centred horizontally, running off the top of the screen; not the full-width scrim it used to be |
| Overhang at design size | Run at 1080 by 1920 | The oval's left and right edges are off-screen; the fade reaches the side edges of the screen rather than ending inside them |
| Proportion holds when wider | Run in a window and drag it wider than it is tall | The oval grows with the width, keeps its shape, and keeps running off both side edges by the same proportion; it does not stretch |
| Proportion holds when taller | Run on a handset taller than 16 by 9, for instance an iPhone 13 Pro at 1080 by 2337 | The oval is unchanged from the design size, since the canvas stays 1080 units wide |
| Live resize | Resize the window while the application is running | The oval re-derives itself continuously; it does not snap only on scene change or stay at the old size |
| Editor preview | Open each of the four screens in the editor | The oval draws in the 2D viewport at the design canvas size, matching what runs |
| Parameters are live | Change `core_radius` in the inspector | The oval redraws in the editor viewport immediately |
| **The carousel still drags** | Open the bell selection screen and drag across the bells with a finger and with a mouse | The carousel moves exactly as before. This is the `mouse_filter` regression check; if it fails, the vignette rectangle is stopping input |
| Buttons still work | Press the start button, the continue button, and the back control | Each responds normally |
| Draw order | Look at all four screens | The vignette is above the background and behind the logo, Winnie, the bells, and every button |
| No stale properties | Load each of the four screens and watch the output | No error reporting a property that does not exist on the vignette instance |
| The image is gone from the build | Search the project for `vignette_glow` | The only occurrences are under `legacy/` and in `features/` |
| The project still opens | Reopen the project after the move | No missing-resource error |
| Title screen unchanged otherwise | Compare the title screen against its previous state | The teal background is exactly as it was; only the vignette differs |

**On the device.** Build and run on the iPhone and walk the full flow. The rows that matter most here are the carousel drag, since touch input is what the `mouse_filter` setting governs, and a look at the fade on a real display, where banding in a gradient this large shows up more readily than it does on a desktop monitor.

## Coding Standards Compliance Checklist

The application coding standards document named in the skill's project instructions does not exist in this repository. The following are the conventions this codebase actually demonstrates, and this plan conforms to each.

- Tab indentation in GDScript, matching `app/main.gd`, `app/instructions.gd`, and `app/sprite_position.gd`.
- A one-line comment at the top of each script naming the file and its role, matching the existing scripts.
- Static typing on declarations and return types, including `-> void` on functions that return nothing, as the existing scripts do.
- Signals connected in `_ready()` rather than in the scene file, matching `app/main.gd` and `app/instructions.gd`.
- Scene, script, and resource files named in lower snake case, matching `instrument_select.tscn` and `instrument_select.gd`; the shader takes the name of the scene it serves, matching `transparent_cloud.gdshader` beside its own.
- A commented uniform block grouping the shader's parameters by what they control, matching `shaders/transparent_cloud.gdshader`.
- Exported or uniform values for anything art-directed, with the value authored outside the code that consumes it, matching `app/sprite_position.gd` and `app/safe_area_margin.gd`.
- `@tool` scripts recompute rather than adjust in place, so repeated recomputes never compound. The size is republished from the rectangle's current size every time, never accumulated.
- No fallbacks. `app/vignette.gd` assigns the material to a typed variable and raises if it is not a `ShaderMaterial`, rather than guarding and silently drawing nothing.

## File-Level Compliance Review

| File | Change |
|---|---|
| `shaders/vignette.gdshader` | New. The oval, its falloff, and its tunable parameters |
| `app/vignette.gd` | New. Publishes the rectangle's size to the shader on resize |
| `app/vignette.tscn` | Rewritten. `Node2D` with a `Sprite2D` becomes a full-rectangle `ColorRect` carrying the shader |
| `app/main.tscn` | `design_position` removed from the vignette instance |
| `app/instructions.tscn` | `design_position` removed from the vignette instance |
| `app/instrument_select.tscn` | `design_position` removed from the vignette instance |
| `app/instrument.tscn` | `design_position`, `horizontal_anchor`, `vertical_anchor`, and `respect_safe_area` removed from the vignette instance |
| `images/v2/vignette_glow.png`, `images/v2/vignette_glow.png.import` | Moved to `legacy/images/v2/`. Not deleted |
| `app/sprite_position.gd` | Unchanged. The vignette stops using it; the title, the tree, the snowflake, and the carousel still do |
| `app/instrument_carousel.gd` | Unchanged. Named here because the `mouse_filter` setting exists for its sake |
| `shaders/transparent_cloud.gdshader` | Unchanged. The style reference, not a dependency |
| `README.md` | Unchanged, deliberately |
| Everything under `shake/`, `capture/`, and `legacy/` | Unchanged |

No background, logo, button, layout, or scene outside the four listed is touched. The title screen's teal background is explicitly left alone, per the specification's requirement 6.

## Completion Criteria

1. `shaders/vignette.gdshader` draws an ellipse from `#131A2B` to fully transparent, with the colour held constant and only the alpha varying.
2. No pixel of the vignette, on any screen, is lighter than `#131A2B` in any channel.
3. The oval's proportion is 1.2999835 to 1 and its overhang past each side edge is 0.1496701 of the viewport's width, at any viewport size, verified by resizing a running window.
4. Colour, peak opacity, core radius, and edge softness are shader parameters adjustable in the inspector, and the editor viewport redraws when they change.
5. `app/vignette.tscn` holds a single `ColorRect` node anchored to the full rectangle with `mouse_filter` set to ignore, and no texture.
6. The bell selection carousel still responds to a drag, by finger on the device and by mouse on the desktop.
7. All four screens load with no error reporting a property that does not exist, and the vignette still draws above the background and behind everything else.
8. `vignette_glow.png` and its import companion are under `legacy/images/v2/`, nothing references them, and the project opens without a missing-resource error.
9. The title screen's background colour is byte-for-byte what it was.
10. Every row in the §4 verification table passes, including the on-device walk of the flow.

## Token and Design Considerations

This feature builds no skill, so there is no `input_limits` value, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed; this feature replaces one drawing method with another using a shader pattern the repository already demonstrates, and adds no capability the tutor covers.
