---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Snow That Falls the Way the Phone Is Held
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: A four-phase route from three static gradient dots to weather the audience steers with their own hands, with the arithmetic that makes a flake turn quickly without falling faster and faster written down rather than guessed at.
LAST UPDATED: August, 22, 2026 12:06
---

# Implementation Plan for Snow That Falls the Way the Phone Is Held

This plan implements the Snow That Falls the Way the Phone Is Held feature (C1_12). It adds one new top-level directory holding a scene and two scripts, one shader in `shaders/`, raises the import scale on the three snowflake images, and adds a single node to `app/instructions.tscn`. Nothing else in the audience flow is touched, and no existing script or scene is modified apart from that one added node.

## Design decisions carried in from the specification and planning conversations

These were settled during ideation and planning and are implemented rather than re-opened.

- **The tumble is a width oscillation, not a rotation.** All three snowflake images are white radial gradients, symmetric about their own centres, so a particle angular velocity would spin them to a pixel-identical result. The developer chose instead to squash each flake on one axis on its own rhythm, in the vertex stage of the shader that requirement 7 already calls for, reusing the same per-flake seed. The developer's words on the look this gives were "it might look like paper and that's ok." A per-flake angular velocity is **also** authored, at a small value, because it costs one inspector field and becomes real the day a shaped flake replaces one of these.
- **The shader lives in `shaders/`, not in the snow directory.** The specification says the snow scene brings its own shader; the repository's convention, established by `shaders/transparent_cloud.gdshader` and followed by the Draw the Vignette in Code So Its Glow Is Clean and Fits Every Screen feature (C1_11), is that shaders live in `shaders/` whatever uses them. The developer chose the repository's convention. The specification's actual point — that a host screen adds one node and needs to know nothing else — holds either way.
- **The vignette work has landed since the specification was written.** `shaders/vignette.gdshader` exists, `app/vignette.tscn` is now a full-viewport `ColorRect`, and `app/instructions.tscn` no longer carries placement overrides on its vignette instance. This plan targets the tree as it now stands. The Give Each Chosen Bell Its Own Voice and Close the Audience Flow feature (C1_10) is still in flight; this plan touches nothing it touches.
- **No automated tests are written.** The developer's decision, carried forward from the plans for the Fit the Audience Flow to Any Phone Screen feature (C1_07), the Swipe Between Bells to Choose the One You Play feature (C1_08), the Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09), and the vignette feature (C1_11). It moves the entire verification burden onto the manual steps in §4.
- **The fall never scales all the way to zero.** Requirement 3's word is that a flat phone gives snow that hangs and drifts "almost in place," and a scale that reached exactly zero would stop feeding the screen: new flakes would stall just outside it and the visible snow would age out over a lifetime, leaving an empty sky that only refills when the phone is picked up. An exported floor, defaulting to 0.15 of full fall, keeps the sky feeding while still reading as a hang. Setting it to zero is available to anyone who wants the harder reading.
- **This plan targets the Mobile renderer the project is configured for.** Whether the turbulence field and the particle system survive a Compatibility export for the single-page app is a question for that work and is not settled here.
- The **governing documents named in the skill's project instructions do not exist in this repository**, and the shared web component library it references does not apply to a Godot project. This plan follows the conventions the four earlier plans in `features/` establish.

## The driver

Everything geometric is derived every frame from the viewport's own rectangle, so there is no resize wiring at all: a window that changes size is simply a different rectangle on the next frame.

### Which way is down, and how much of it

`Input.get_gravity()` returns the device's gravity vector. Mapping it into screen coordinates is the conversion the archived first version of the application already used, `Vector2(g.x, -g.y)`, which puts positive x to the right and positive y down.

Two quantities come out of it, governed separately:

```
in_plane   = Vector2(g.x, -g.y)
tilt       = clamp(in_plane.length() / g.length(), 0, 1)   // 0 flat, 1 upright
```

The tilt is the **ratio** of the in-plane part to the whole vector, not the in-plane length against a constant 9.80665. Two reasons. It is exactly the sine of the tilt angle, which is the quantity actually wanted. And it is independent of the units the platform reports gravity in, so a platform that reports a normalised vector of magnitude 1.0 rather than an acceleration in metres per second squared produces an identical tilt.

The direction updates only while the in-plane part is a meaningful fraction of the whole:

```
if in_plane.length() >= g.length() * direction_floor:
    angle = lerp_angle(angle, in_plane.angle(), alpha)
tilt_smoothed = lerp(tilt_smoothed, tilt, alpha)
alpha         = clamp(delta / response_time_constant_seconds, 0, 1)
```

The angle is smoothed rather than the vector, using `lerp_angle`, which takes the shorter way round and has no degenerate case; smoothing two unit vectors by lerping and re-normalising has one when they are opposed. The `alpha` form is the same one `shake/shake_detector.gd` and `app/safe_area_margin.gd` already use.

Where there is no sensor at all — the editor, and any desktop run — `Input.get_gravity()` returns a zero vector, the whole update is skipped, and the initial values stand: an angle of straight down and a tilt of 1.0. That is not a guarded alternative path; it is the same hold rule requirement 3 specifies, arriving at the value the scene was authored with.

### Where the flakes come from

```
centre         = viewport.size * 0.5
diagonal       = viewport.size.length()
band_position  = centre - direction * (diagonal * 0.5 + band_margin)
band_length    = diagonal * band_length_factor
```

The band sits just beyond the circle that circumscribes the viewport, so it is off screen at every angle rather than only at the ones tested. Its length is the diagonal because the diagonal is the widest the viewport ever projects onto an axis perpendicular to the fall, which happens at exactly one angle and is the angle that would otherwise leave two corners unfed. On the design canvas the diagonal is 2,203 units and the band sits 1,161 units from the centre.

Each layer sets its own node's `position` to the band position and its `rotation` to the fall direction's angle, so the node's local +X axis points downwind. The emission box's extents then read as thickness along local X and length along local Y, and the process material's initial-velocity direction stays `Vector3(1, 0, 0)`: a flake is born on the band and set moving inward, whichever way the band has swung to.

### Turning quickly without falling faster and faster

This is the one piece of arithmetic worth writing down, because the obvious settings fail in opposite directions.

A flake travelling at speed `v` under a sideways acceleration `g` turns at `g / v` radians per second. So responsive turning wants **large** gravity. But a flake under constant gravity for its whole life accelerates the whole time, and a lifetime long enough to cross the screen with a gentle gravity ends with the flake moving several times faster than it started — snow that visibly speeds up as it falls, which is what it must not do.

Damping resolves both at once, because Godot's particle damping is a constant deceleration opposing the direction of travel:

```
net acceleration = fall_strength * fall_scale * (1 - damping_fraction)
turning rate     = fall_strength * fall_scale / speed
```

Gravity governs the turn; what is left after damping governs the speed. A large `fall_strength` with `damping_fraction` just under 1.0 gives a flake that turns briskly and still barely gains speed over its life. At the defaults below the near layer turns ninety degrees in about a second and a quarter while its speed grows from 260 to about 700 over five and a half seconds.

The damping is set by the driver alongside the gravity, scaled by the same fall scale, rather than authored as a fixed number. A fixed damping would exceed the gravity as soon as the phone tilted back — and a flake whose damping exceeds its gravity decelerates to a standstill, which is how the sky would stop feeding.

```
fall_scale = lerp(minimum_fall_fraction, 1.0, tilt_smoothed)
gravity    = direction * fall_strength * fall_scale
damping    = fall_strength * fall_scale * damping_fraction
```

### The two settings that are load-bearing and invisible

**`local_coords` must be false on every layer.** The band orbits the viewport, and a particle system in local coordinates carries its live particles with its node — so the snow already on screen would sweep around with the band, and the material's gravity would be rotated by the node's rotation on top of the direction the driver already put into it. With `local_coords` false the particles live in global space, the node's rotation orients only the emission, and the gravity the driver writes is the gravity that applies.

**`visibility_rect` must be large.** It is the rectangle, in the node's own local space, that has to intersect the screen for the system to be drawn at all, and the node itself spends its whole life outside the viewport. At the default it would be culled and no snow would appear anywhere. The driver sizes it from the diagonal each frame.

## Correction from the build

The section above is wrong about damping, and the build measured it rather than inheriting it. It is left in place because it states the problem correctly; only its solution failed.

**Godot's default damping does not trim acceleration.** The section reasons that a constant deceleration subtracts from the pull, leaving `fall_strength * (1 - damping_fraction)` to accelerate the flake. Measured on screen, it does not: at a damping of eight tenths of the pull, no snow reaches the screen at all — the flakes emit and stop dead just outside it. Sweeping the fraction from 0.0 to 0.8 moved the deepest visible flake steadily up the frame and then to nothing, with no value giving a full field.

**Friction damping does work, and is what the build uses.** `particle_flag_damping_as_friction` changes the damping value from a deceleration into a rate that pulls a flake toward a terminal speed, which is the behaviour the section wanted. The driver therefore writes gravity alone and never touches damping: the rate is authored per layer and constant, so the terminal speed follows the pull, and a phone tilted back gives slower snow rather than snow that stalls. This is simpler than the plan's arrangement, not more complex.

**Both numbers were measured, not derived.** Friction damping is roughly thirty times stronger than reading its rate as per-second would predict, so the authored rate is 0.02 rather than about 1.2, and the pull is 720, 1,080, and 1,560 rather than 240, 360, and 520. The lifetimes rose with them, to 13.5, 9.5, and 7.0 seconds. These were arrived at by running the instructions screen and measuring how far down the frame the deepest flake reached; the arithmetic in the section above predicts none of them.

The consequence for anyone tuning this later is recorded in `snow/snow_layer.gd`: change the pull or the rate and check on screen that snow still reaches the bottom of the frame, because the arithmetic will not tell you.

## Implementation Steps and Phases

### Phase 1: The images

1. **Raise the import scale on the three snowflake images.** `images/v2/snowflake_01.svg`, `snowflake_02.svg`, and `snowflake_03.svg` are 11.392 units square and import at `svg/scale = 1.0`, so each becomes a texture roughly eleven pixels square against a design canvas 1,080 units wide. Set `svg/scale` to 4.0 on all three in the Import dock and reimport, giving textures of about forty-six pixels that the layer scales down rather than up. This writes `svg/scale=4.0` into the three `.import` files and is the whole of the change; the source files are untouched.

### Phase 2: The shader

2. **Write `shaders/snow_sparkle.gdshader`**, in the style of `shaders/vignette.gdshader` and `shaders/transparent_cloud.gdshader`: a commented uniform block, then the two stages.

```glsl
shader_type canvas_item;

/* The sparkle: how far the brightness swings, how fast, and how much that rate
   varies from flake to flake. */
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.35;
uniform float sparkle_rate : hint_range(0.0, 8.0) = 1.6;
uniform float sparkle_rate_spread : hint_range(0.0, 1.0) = 0.6;

/* The tumble. These images are radial gradients, symmetric about their own centres,
   so rotating one changes nothing a viewer can see. A real flake turning edge-on
   gets narrower and dimmer, and that is what is done here instead: the quad is
   squashed on its own x axis and dimmed by the same factor. tumble_amount is how
   narrow it gets at its narrowest; at 0.55 a flake never falls below 0.45 of its
   width, so it thins to a paper edge rather than disappearing. */
uniform float tumble_amount : hint_range(0.0, 1.0) = 0.55;
uniform float tumble_rate : hint_range(0.0, 8.0) = 0.9;
uniform float tumble_rate_spread : hint_range(0.0, 1.0) = 0.7;

varying float flake_alpha;

void vertex() {
	/* One number per flake, constant for its whole life, different for every flake.
	   It comes from the process material's animation offset, which is randomised
	   per particle and which nothing here uses for animation, so it is free to
	   carry the seed. Every rhythm below is derived from it, which is what stops
	   the whole snowfall pulsing in lockstep. */
	float seed = INSTANCE_CUSTOM.z;

	float tumble_speed = tumble_rate * mix(1.0 - tumble_rate_spread, 1.0 + tumble_rate_spread, seed);
	float width = mix(1.0, abs(sin(TIME * tumble_speed + seed * TAU)), tumble_amount);
	VERTEX.x *= width;

	float sparkle_speed = sparkle_rate * mix(1.0 - sparkle_rate_spread, 1.0 + sparkle_rate_spread, seed);
	float twinkle = 0.5 + 0.5 * sin(TIME * sparkle_speed + seed * TAU * 3.0);

	// Multiplied together deliberately: a flake edge-on is both narrower and dimmer,
	// and the two happening at once is what reads as a turn rather than as a flicker.
	flake_alpha = mix(1.0 - sparkle_amount, 1.0, twinkle) * width;
}

void fragment() {
	COLOR.a *= flake_alpha;
}
```

3. **Confirm the seed channel before building the rest on it.** Put the shader on a single test emitter with the animation offset randomised across its full range, and watch. Flakes must twinkle and thin out of step with one another. If they move in lockstep, `INSTANCE_CUSTOM.z` is not carrying the animation offset in this engine version and the correct channel must be found before phase 3 depends on it. This is the one assumption in the plan that rests on an engine detail rather than on something in this repository, so it is checked first and alone.

### Phase 3: The snow scene

4. **Write `snow/snow_layer.gd`**, one depth layer. It owns its own look and applies what the driver hands it.

```gdscript
# snow_layer.gd (C1_12 snow) - one depth layer of falling snow.
#
# A layer owns how heavy its flakes are and how fast they fall; the driver owns which
# way down is and where the flakes come in from. Everything this script writes is
# derived output recomputed every frame, so nothing accumulates and nothing that is
# authored in the inspector is overwritten.
class_name SnowLayer
extends GPUParticles2D

# How hard this layer's flakes are pulled. Large, deliberately: this number sets how
# quickly a flake in flight turns onto a new heading, and the damping the driver
# applies alongside it is what stops the same number making the flake accelerate away.
@export var fall_strength: float = 520.0

func apply(direction: Vector2, fall_scale: float, band_position: Vector2, band_length: float, cull_span: float) -> void:
	position = band_position
	# The node's local +X points downwind, so the emission box's x extent is the
	# band's thickness and its y extent is the band's length.
	rotation = direction.angle()

	# Typed deliberately. A snow layer without a ParticleProcessMaterial is a broken
	# scene, and this raises rather than quietly emitting nothing.
	var process: ParticleProcessMaterial = process_material
	var pull: float = fall_strength * fall_scale
	process.gravity = Vector3(direction.x, direction.y, 0.0) * pull
	process.damping_min = pull * SnowDriver.DAMPING_FRACTION
	process.damping_max = process.damping_min
	process.emission_box_extents = Vector3(process.emission_box_extents.x, band_length * 0.5, 0.0)

	# The node lives outside the viewport for its whole life, so without a rect this
	# large the system is culled and no snow is drawn anywhere. See the plan.
	visibility_rect = Rect2(-cull_span * 0.5, -cull_span * 0.5, cull_span, cull_span)
```

5. **Write `snow/snow.gd`**, the driver.

```gdscript
# snow.gd (C1_12 snow) - reads which way the phone says down is, and steers the snow by it.
#
# This is the only place in the effect that touches a sensor, and gravity and damping on
# each layer's material are the only things it writes. Every geometric quantity is
# re-derived from the viewport every frame, which is why nothing here listens for a
# resize: a window that changed size is simply a different rectangle next frame.
class_name SnowDriver
extends CanvasLayer

# What is left of the pull after damping is what makes a flake gain speed; the pull
# itself is what turns it. Holding damping at a fixed fraction of the pull rather than
# at a fixed number is what keeps a tilted-back phone from damping its flakes to a
# standstill, which is how the sky would stop feeding.
const DAMPING_FRACTION: float = 0.85

# How quickly the snow follows the phone. Snow has inertia and a hand is never still.
@export var response_time_constant_seconds: float = 0.35

# The direction stops updating below this fraction of gravity. Face-up on a table almost
# all of gravity points through the screen, and what is left in the plane of it is sensor
# noise; without this the snowfall spins while the phone lies perfectly still.
@export var direction_floor: float = 0.12

# A flat phone still gets this fraction of the fall. Requirement 3's word is "almost" in
# place: at exactly zero, new flakes stall outside the screen and the sky empties out
# over one lifetime.
@export var minimum_fall_fraction: float = 0.15

# How far past the circumscribing circle the band sits, and how long it is as a multiple
# of the viewport's diagonal.
@export var band_margin: float = 60.0
@export var band_length_factor: float = 1.0

# The culling rectangle, as a multiple of the diagonal.
@export var cull_factor: float = 1.5

# Straight down, at full strength. These are the values that stand wherever there is no
# gravity sensor to read - the editor, and any desktop run.
var _angle: float = PI * 0.5
var _tilt: float = 1.0
var _layers: Array[SnowLayer] = []

func _ready() -> void:
	for child in get_children():
		var layer := child as SnowLayer
		if layer != null:
			_layers.append(layer)
	if _layers.is_empty():
		push_error("snow.gd found no SnowLayer children; the snow scene draws nothing without them.")

func _process(delta: float) -> void:
	_read_gravity(delta)
	var direction := Vector2.from_angle(_angle)
	var viewport := get_viewport().get_visible_rect()
	var diagonal := viewport.size.length()
	var band_position := viewport.size * 0.5 - direction * (diagonal * 0.5 + band_margin)
	var fall_scale := lerpf(minimum_fall_fraction, 1.0, _tilt)
	for layer in _layers:
		layer.apply(direction, fall_scale, band_position, diagonal * band_length_factor, diagonal * cull_factor)

func _read_gravity(delta: float) -> void:
	var gravity := Input.get_gravity()
	var magnitude := gravity.length()
	# No reading at all. The held angle and tilt stand, which on a desktop is the
	# authored straight-down at full strength.
	if magnitude == 0.0:
		return
	# +x right, +y down, matching the screen.
	var in_plane := Vector2(gravity.x, -gravity.y)
	var alpha := clampf(delta / response_time_constant_seconds, 0.0, 1.0)
	if in_plane.length() >= magnitude * direction_floor:
		_angle = lerp_angle(_angle, in_plane.angle(), alpha)
	# The ratio, not a length against 9.80665, so the tilt is the sine of the angle and
	# is the same whatever units the platform reports gravity in.
	_tilt = lerpf(_tilt, clampf(in_plane.length() / magnitude, 0.0, 1.0), alpha)
```

6. **Build `snow/snow.tscn`.** A `CanvasLayer` root named `Snow` running `snow/snow.gd`, with `layer = 1` so it draws above everything the host screen puts in the default layer. Three `GPUParticles2D` children running `snow/snow_layer.gd`, named `Far`, `Middle`, and `Near` in that tree order so the near layer draws last. Each carries its own `ParticleProcessMaterial` — three separate resources, not one shared — and a `ShaderMaterial` holding `shaders/snow_sparkle.gdshader`.

   On every one of the three:
   - `local_coords` off, for the reason in the plan above. This is the single most important switch in the scene.
   - `preprocess` set to the layer's lifetime, so the screen opens with snow on it rather than filling in.
   - `emission_shape` set to Box, with the x extent authored as the band's thickness (start at 30) and the y extent left alone, since the driver derives it.
   - `direction` `Vector3(1, 0, 0)` with a `spread` of about 8 degrees.
   - `angle` randomised across the full turn and a small `angular_velocity`, which does nothing visible on these symmetric images and is authored so it works the day a shaped flake replaces one.
   - `anim_offset_min` 0 and `anim_offset_max` 1, which is where the shader's per-flake seed comes from.
   - Turbulence enabled, at the strengths in the table.
   - `damping_min` and `damping_max` left at whatever value; the driver overwrites both every frame.

   Starting values, all of them to be tuned in phase 4 rather than trusted:

   | Layer | Image | Amount | Scale | `fall_strength` | Initial velocity | Lifetime | Modulate alpha | Turbulence strength | Turbulence scale |
   |---|---|---|---|---|---|---|---|---|---|
   | `Near` | `snowflake_03` | 45 | 0.75–1.05 | 520 | 260 | 5.5 | 0.85 | 3.0 | 2.0 |
   | `Middle` | `snowflake_02` | 80 | 0.45–0.65 | 360 | 170 | 7.5 | 0.55 | 2.2 | 2.8 |
   | `Far` | `snowflake_01` | 130 | 0.26–0.40 | 240 | 110 | 10.0 | 0.30 | 1.5 | 3.6 |

   The image assignment is requirement 5's: `snowflake_03` holds an opaque core to nearly half its radius and reads as nearest; `snowflake_01` fades across its whole radius and reads as furthest. Each lifetime is longer than the crossing time its own row implies — on the design canvas a flake has 2,263 units to cover, and the near row reaches that in about 4.9 seconds against a lifetime of 5.5 — so no flake expires in view.

7. **Confirm the scene on its own** by opening `snow/snow.tscn` and running it. Snow falls straight down at full strength, because there is no gravity sensor on the desktop and the held values stand. This is the check that the band, the culling rectangle, and the local-coordinates switch are all right before a screen depends on them.

### Phase 4: The instructions screen, and tuning

8. **Add the snow to `app/instructions.tscn`.** One instance of `snow/snow.tscn` as a child of the root. Its position in the tree does not affect what it draws over, because a `CanvasLayer` renders by its layer number rather than by tree order; adding it last keeps the file readable.

9. **Confirm the Continue button still works.** The snow renders above it. A `CanvasLayer` is not a `Control` and a `GPUParticles2D` is a `Node2D`, so neither can take a touch, but this is the same class of invisible regression the vignette's mouse filter was, and it is checked rather than assumed.

10. **Tune by eye, on the device, against the near-black background.** Density, scale, fall strength, initial velocity, lifetime, opacity, turbulence, sparkle amount, and tumble amount are all exported for this reason. The two judgements that matter most: whether the near layer's opacity leaves the four instruction lines readable, and whether "subtle" has been reached on the sparkle and the tumble. Anything settled on is written into the scene and the shader's defaults rather than left as a per-screen override.

11. **Work through the verification table in §4**, including the resized-window rows and the on-device pass.

## Test Cases

**No automated tests are created or changed by this plan.** The developer has elected to verify this feature manually, as on the four features preceding it. There is accordingly no test-case table of unit or interface tests; the verification table in §4 carries the full burden, and the completion criteria in §7 depend on those manual checks rather than on a passing suite.

The consequence worth recording is that three of the things most likely to be wrong here have no visual symptom that points at their cause. A `local_coords` left on shows up as snow that sweeps sideways across the screen when the phone turns, which looks like a physics problem rather than a checkbox. A `visibility_rect` left at its default shows up as no snow at all, which looks like a broken shader. And a wrong seed channel shows up as a snowfall that pulses in unison, which looks like a deliberate choice. Each has its own row below, and each should be re-checked after any later change to this scene.

## README and Documentation Updates

This feature adds a new top-level directory, so `snow/` gets a row in the README's repository-structure table. The rest of that table is still stale from the restructure — it shows `v2/`, and lists `background/`, `foreground/`, and `bells/` as live — and correcting it belongs to the Give Each Chosen Bell Its Own Voice and Close the Audience Flow feature (C1_10), whose build is still in flight. Adding one correct row is worth a trivial collision; rewriting the other four here is not.

A short **The snow** section is added after **The shake instrument**, modelled on it: what the effect is, that a screen adds one node to get it, that one driver reads the gravity sensor and writes gravity and damping to each layer, and that the three layers differ only in weight and speed.

Three pieces of knowledge introduced here are not evident from reading the code, and each is recorded as a comment where someone changing that behaviour will be looking:

- At the top of `snow/snow.gd`, why nothing listens for a resize: every geometric quantity is re-derived from the viewport each frame.
- On `DAMPING_FRACTION` in the same file, that the pull turns a flake and only what survives damping accelerates it, which is why the pull is large and why damping is a fraction of it rather than a fixed number.
- In `snow/snow_layer.gd`, on `visibility_rect`, that the node spends its life outside the viewport and the default rectangle would cull the whole system.
- In the uniform block of `shaders/snow_sparkle.gdshader`, that these images are rotationally symmetric so the tumble is a width oscillation rather than a rotation, and where the per-flake seed comes from.

## Manual Verification Steps

Because there are no automated tests, these steps are the verification. Four rows exercise behaviour whose failure mode points somewhere other than its cause.

| Behaviour under test | How to exercise it | Expected result |
|---|---|---|
| Snow appears at all | Open the instructions screen | Snow is falling from the moment the screen appears, not building up from an empty sky over several seconds |
| **The system is not culled** | Open the screen and watch for a full ten seconds | Snow keeps arriving continuously. If snow never appears at all, `visibility_rect` is the first thing to check, not the shader |
| Falls the way the phone is held | Tilt the phone left, then right, then back upright | The snowfall turns to follow, taking roughly a third of a second to commit rather than snapping |
| **Flakes in flight curve** | Watch a single flake near the middle of the screen while turning the phone | That flake bends onto the new heading. It does not continue on its old one until it expires |
| **Live flakes stay put when the band swings** | Turn the phone briskly through ninety degrees | The snow already on screen changes heading in place. It does not sweep bodily sideways across the screen — that is `local_coords` left on |
| Snow enters from off screen at any angle | Hold the phone tilted about forty-five degrees for several seconds | Flakes arrive from the upwind corner and cross the view. No edge of the screen is left bare, and no flakes pop into existence inside the view |
| Flat phone holds its heading | Lay the phone face up on a table and watch for fifteen seconds | The snowfall keeps the direction it had. It does not spin, wander, or jitter |
| Flat phone still feeds | Keep it flat for a full minute | Snow slows to a drift but keeps arriving; the screen does not empty out |
| Tilt controls speed | Raise the phone from flat to upright slowly | The fall speeds up smoothly across the movement |
| Snow does not accelerate visibly | Follow one near-layer flake from entry to exit | It is faster at the bottom than the top, but not dramatically; it does not streak |
| **Flakes sparkle out of step** | Watch a patch of a dozen flakes | They brighten and dim at different moments and different rates. A snowfall pulsing in unison means the per-flake seed is not reaching the shader |
| Flakes tumble | Watch a single near-layer flake | It narrows to a thin edge and widens again on its own rhythm, dimming as it narrows |
| The sparkle is subtle | Look at the screen as a whole | The twinkling reads as texture, not as flashing |
| Three depths are visible | Look at the screen as a whole | Large bright flakes fall faster in front, small faint ones drift slower behind |
| Snow is in front | Look at the title, Winnie, the instruction lines, and the button | Flakes pass over all of them |
| The instructions stay readable | Read all four instruction lines | Every line is legible with snow crossing it |
| **The Continue button still works** | Press Continue, by finger on the device and by mouse on the desktop | It advances to the bell selection screen exactly as before |
| Desktop with no sensor | Run on the desktop | Snow falls straight down at full strength and stays steady |
| Editor preview | Open `app/instructions.tscn` in the editor | The scene loads with no error; the particle nodes are present |
| Resized window, wider | Run in a window and drag it wider than it is tall | The band re-derives itself; snow still enters from off screen on the upwind side and no edge is left bare |
| Live resize | Resize the window while running | The snowfall re-fits continuously, not only on scene change |
| Nothing else changed | Compare the instructions screen against its previous state | The background, vignette, title, Winnie, instruction lines, and button are all exactly as they were |
| No other screen has snow | Open the title, bell selection, and play screens | None of them shows snow |
| The images are not blurry | Look closely at a near-layer flake | It is a clean soft gradient, not a visibly pixelated one — the import scale took effect |

**On the device.** Build and run on the iPhone and walk the full flow. The rows that only the handset can answer are every one involving a tilt, since there is no gravity sensor on the desktop, and the readability judgement, which depends on a real display in a dark room. Watch the frame rate on the instructions screen while tilting; two hundred and fifty-five particles across three systems with turbulence is the heaviest thing the application draws.

## Coding Standards Compliance Checklist

The application coding standards document named in the skill's project instructions does not exist in this repository. The following are the conventions this codebase actually demonstrates, and this plan conforms to each.

- Tab indentation in GDScript, matching `app/main.gd`, `app/sprite_position.gd`, and `shake/shake_detector.gd`.
- A one-line comment at the top of each script naming the file, the feature it belongs to, and its role, matching `shake/shake_detector.gd` and `app/vignette.gd`.
- Static typing on declarations, parameters, and return types, including `-> void`, as every existing script does.
- `class_name` on a script another script refers to by type, matching `ShakeEvent` and `InstrumentDefinition`.
- Scene, script, and shader files named in lower snake case, with the shader named for what it does and living in `shaders/`, matching `vignette.gdshader` and `transparent_cloud.gdshader`.
- A commented uniform block grouping the shader's parameters by what they control, matching `shaders/vignette.gdshader`.
- Exported values for anything art-directed, authored outside the code that consumes it, matching `app/sprite_position.gd`, `app/safe_area_margin.gd`, and `shake/shake_detector.gd`.
- Derived output recomputed from its inputs rather than adjusted in place, so repeated recomputes never compound, matching `app/sprite_position.gd` and `app/safe_area_margin.gd`. Position, rotation, gravity, damping, band length, and culling rectangle are all rewritten from scratch every frame.
- Why a measured or reasoned constant has the value it does, written where the constant is, matching `shake/shake_detector.gd`. `DAMPING_FRACTION`, `direction_floor`, and `minimum_fall_fraction` each carry their reason.
- No fallbacks. `snow/snow_layer.gd` assigns the process material to a typed variable and raises if it is not a `ParticleProcessMaterial`; `snow/snow.gd` raises if it finds no layers. Neither substitutes a working-looking alternative.

## File-Level Compliance Review

| File | Change |
|---|---|
| `snow/snow.tscn` | New. The `CanvasLayer`, its three emitters, their process materials, and the shader material |
| `snow/snow.gd` | New. Reads the gravity sensor, derives the direction, the fall scale, and the band, and drives every layer |
| `snow/snow_layer.gd` | New. One depth layer; applies what the driver hands it and owns its own fall strength |
| `shaders/snow_sparkle.gdshader` | New. Per-flake tumble in the vertex stage, per-flake sparkle carried to the fragment stage |
| `images/v2/snowflake_01.svg.import`, `snowflake_02.svg.import`, `snowflake_03.svg.import` | `svg/scale` raised from 1.0 to 4.0 and reimported. The `.svg` sources are untouched |
| `app/instructions.tscn` | One instance of `snow/snow.tscn` added as a child of the root. Nothing else altered |
| `README.md` | One row added for `snow/`; a **The snow** section added after **The shake instrument**. The stale rows are left to C1_10 |
| `app/main.tscn`, `app/instrument_select.tscn`, `app/instrument.tscn` | Unchanged. No screen but the instructions screen gets snow |
| `app/vignette.tscn`, `shaders/vignette.gdshader`, `app/vignette.gd` | Unchanged. The snow draws above the vignette by virtue of its layer number, and needs nothing from it |
| `app/sprite_position.gd`, `app/safe_area_margin.gd` | Unchanged. The snow derives its own geometry from the viewport and does not use the design-canvas placement helpers |
| `images/v2/snowflake_01.svg`, `snowflake_02.svg`, `snowflake_03.svg` | Unchanged. Only their import settings move |
| Everything under `shake/`, `capture/`, and `legacy/` | Unchanged |
| `project.godot` | Unchanged. The gravity sensor is already enabled and the snow is not an autoload |

No background, logo, button, layout, or scene outside the instructions screen is touched.

## Completion Criteria

1. `snow/snow.tscn` is a `CanvasLayer` carrying three `GPUParticles2D` layers, and a screen gains falling snow by instancing it and doing nothing else.
2. The snowfall's direction follows the phone's gravity vector, smoothed, and flakes already in flight curve onto the new heading rather than only newly born ones.
3. The direction holds steady when the phone lies face up, and the fall speed scales with tilt down to the exported floor without the sky ceasing to feed.
4. New flakes enter from off screen on the upwind side at every angle, with no bare edge and no flake appearing inside the view.
5. Each of `snowflake_01`, `snowflake_02`, and `snowflake_03` has its own emitter, at its own scale, speed, and opacity, reading as far, middle, and near respectively.
6. Flakes wander through a shared noise field and each narrows and widens on its own rhythm, dimming as it narrows.
7. Flakes brighten and dim independently of one another, repeatedly, for as long as they are on screen, with the amplitude adjustable in the inspector.
8. Snow renders above the instructions screen's artwork, text, and button, all four instruction lines remain readable, and the Continue button still advances the flow by finger and by mouse.
9. `local_coords` is off and `visibility_rect` is sized from the diagonal on all three layers, verified by the two rows in §4 that test them.
10. Density, scale, fall strength, initial velocity, lifetime, opacity, turbulence, sparkle amount, and tumble amount are all exported and adjustable without editing code.
11. The three snowflake images import at `svg/scale = 4.0` and are scaled down rather than up by every layer.
12. The title, bell selection, and play screens are unchanged and carry no snow.
13. Every row in the §4 verification table passes, including the on-device walk of the flow.

## Token and Design Considerations

This feature builds no skill, so there is no `input_limits` value, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching Topic

No teaching topic is needed; this feature applies the self-contained-effect pattern the shake instrument already demonstrates and the shader pattern the vignette already demonstrates, and adds no capability the tutor covers.
