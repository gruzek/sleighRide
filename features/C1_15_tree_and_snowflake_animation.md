---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Artwork That Answers the Tilt of the Phone
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.2
AUTHOR: George Ruzek
VALUE STATEMENT: Gives the title screen a heartbeat, so the first thing an audience member sees is artwork that already knows how their phone is being held.
LAST UPDATED: August, 22, 2026 15:36
---

# Artwork That Answers the Tilt of the Phone

## Summary

The Artwork That Answers the Tilt of the Phone feature (C1_15) makes three pieces of the title screen's artwork move. The red tree sways from side to side as the phone is tilted, rotating about the pivot the scene sets and clamped to a small maximum angle. The blue snowflake turns slowly and continuously on its own, reading no sensor at all. The green halo behind that snowflake slides a short distance up, down, left, and right as the phone tilts, clamped independently on each axis. Each motion is a small reusable script attached to the sprite it animates, with every constraint, rate, and response value exported so it can be adjusted from the editor against a real phone.

## Background

The title screen is where an audience member meets this application. It carries a title, a red tree, a blue snowflake with a green halo behind it, the Holiday Sleigh Bells wordmark, the play-along line, Winnie, and a start button. Since the Snow That Falls the Way the Phone Is Held feature (C1_12) it also carries falling snow, and that snow is currently the only thing on the screen that moves. Everything else is a still image on a coloured background.

The snow proved something worth building on. It reads the device's gravity vector every frame and steers itself by it, so tilting the phone visibly turns the weather, and the discovery that the application is watching how the phone is held now happens on a screen with no instrument on it. What the snow does not do is involve the artwork. The tree, the snowflake, and the halo sit perfectly still inside moving weather, which is the arrangement that most draws attention to their stillness.

The pieces needed to fix that are already in place. Gravity is enabled in the project settings, `snow/snow.gd` has established and proved on a handset how to project the device's gravity vector into the plane of the screen, how to smooth it, and how to reject the sensor noise a phone lying flat produces. The Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) and the snow between them have established the repository's shape for an effect: a self-contained piece a screen or a scene opts into, with everything a person would want to look at and change exported rather than written as a constant. What has not been done is applying either to a piece of static artwork.

There is one structural trap this feature has to stay clear of, and it is worth naming before the requirements rather than discovering during the build. `app/sprite_position.gd` owns the root node's `position` in every artwork scene: it overwrites it on ready, on viewport resize, and on every exported-property change in the editor, and it strips `position` from storage so that a drag in the editor is discarded at the next recompute. Anything in this feature that animates a position must therefore stay off those root nodes. Every piece this feature moves is a child sprite, which `sprite_position.gd` does not touch, so the two never contend — but only because the feature is built that way deliberately.

## Value Delivered

- **The first screen stops being a poster.** The screen an audience member sees before anything else gains motion in the artwork itself, not only in the weather passing over it.
- **The phone becomes part of the picture immediately.** Tilting the phone leans the tree and slides the halo, so the discovery that the application responds to how it is held happens on the very first screen.
- **Three motions become three reusable parts.** Each behaviour is a small script any sprite in the application can carry, so giving Winnie a sway later costs adding a script rather than writing one.
- **Subtlety is tuned on the device, not guessed in code.** Every clamp, rate, and response value is exported, so the difference between "ever so slightly" and "too much" is settled by looking at a phone in a dark room.
- **Nothing is disturbed that already works.** The behaviours attach to child sprites and leave the placement system, the snow, and the shake instrument exactly as they are.

## Terms

- **In-plane gravity.** The part of the device's gravity vector that lies in the plane of the screen. Near zero when the phone lies flat and face up, near full gravity when the phone is held upright.
- **Tilt fraction.** In-plane gravity expressed as a fraction of total gravity, so it is the same number whatever units the platform reports gravity in, and it does not need a fixed value for gravity written down anywhere.
- **Rest pose.** The rotation and position a sprite is authored with in its scene. Every motion in this feature is an offset from the rest pose, never an absolute value written over it.
- **Pivot origin.** A `Sprite2D` node's own transform origin, established in the scene by its `centered` and `offset` properties. Rotating the node rotates the artwork about this point.
- **Clamp.** The maximum excursion a motion is allowed, in degrees for a rotation and in pixels for a drift. The motion reaches the clamp and goes no further however far the phone is tilted.

## Requirements Summary

- **1. Sway the red tree with the tilt of the phone.** The tree leans in the direction the phone is tilted side to side, smoothed, and clamped to a small maximum angle.
- **2. Rotate the tree about the pivot the scene sets, never one the script invents.** The sway script rotates the node it is attached to and carries no pivot of its own.
- **3. Turn the blue snowflake slowly and continuously, on its own.** A constant rate of rotation that reads no sensor and never stops.
- **4. Slide the green halo with the tilt of the phone.** A short drift up, down, left, and right, mapped directly from tilt and clamped independently on each axis.
- **5. Build the three motions as reusable behaviours any artwork can carry.** Three small scripts in `app/`, each attached to the sprite it animates, plus a fourth holding the gravity reading the two tilt behaviours share.
- **6. Make every constraint and rate adjustable from the editor.** Exported values with starting points that are meant to be argued with, and validation on the ones that could break the arithmetic.
- **7. Hold the neutral pose where there is no sensor.** The editor, the desktop build, and the simulator report no gravity, and the two tilt behaviours must sit still rather than drift or spin.
- **8. Bring the three behaviours to the title screen without editing the screen.** The motion arrives through the two artwork scenes the title screen already instances, so the screen itself is not touched.

## Requirements

### 1. Sway the red tree with the tilt of the phone

The red tree leans in the direction the phone is tilted from side to side, and returns as the phone is levelled. Tilt the top of the phone to the left and the tree leans left; hold that tilt and the tree holds the lean.

The signal is the gravity sensor, not linear acceleration. This is the distinction between a tree that answers how the phone is *held* and one that answers how the phone is *swung*, and this feature is the former. Gravity gives a pose that persists: an audience member can tilt the phone, look at the leaning tree, and see it stay leaning. Linear acceleration would give a kick that decays, which would need a spring-back rule and a rest state that gravity does not, and would make the tree answer a different gesture from the halo of requirement 4. One gesture, answered coherently by the whole screen, is the intent.

The horizontal component of in-plane gravity is what drives the lean, expressed as a tilt fraction so it carries no assumption about the units the platform reports. That fraction is mapped to a rotation offset from the rest pose, scaled so that a nameable amount of tilt produces the full sway, and clamped so no amount of tilt produces more. Both the maximum angle and the tilt fraction at which it is reached are exported, because they are two independent halves of what "ever so slightly" means: how far the tree can ever lean, and how much wrist movement it takes to get there.

The lean is smoothed rather than snapped to the sensor reading, on the same time-constant model `snow/snow.gd` uses for its direction. A hand is never perfectly still, and a large piece of artwork that tracked a raw gravity reading would visibly tremble while the phone was held steady. A reading below a small floor of total gravity is ignored entirely, which is the same rule and the same reason: a phone lying flat and face up puts almost all of gravity through the screen rather than across it, and what remains in the plane is noise.

The mapping from the device's gravity vector into screen coordinates matches the one `snow/snow.gd` already uses, which is iOS-shaped. §"Platform notes" in `docs/system_design.md` records that the engine reports the gravity vector in opposite directions on iOS and Android and that no Android hardware has been measured. That remains true after this feature. A tree that leans the wrong way on Android is the same single sign error the snow would have, in the same place, and is fixed once for both when Android is measured.

### 2. Rotate the tree about the pivot the scene sets, never one the script invents

The sway script rotates the node it is attached to, about that node's own pivot origin. It carries no pivot property, no offset value, and no knowledge of where the trunk is.

This is the decision that makes the difference between a tree that bends and a tree that spins, and it is deliberately not the script's to make. A `Sprite2D`'s origin is established in the scene by its `centered` and `offset` properties, which means the pivot is something a person positions by eye in the editor, watching the artwork, rather than a number typed into code. `app/straight_red_tree.tscn` now carries `offset` `(20.19, -418.03)` with a compensating `position` of `(-214, 498)`, which moves the origin down to the foot of the trunk without moving the artwork on screen by so much as a pixel. That is the pivot the sway uses, and moving it later is a scene edit that needs no code change.

The script attaches to the `Sprite2D` rather than to the scene's root `Node2D` for the same reason. The root is where `app/sprite_position.gd` lives and where the pivot is not.

### 3. Turn the blue snowflake slowly and continuously, on its own

The blue snowflake rotates at a constant rate, in one direction, for as long as the screen is up. It reads no sensor, responds to no shake, and has no rest state to return to. Whichever way the phone is held and however it is moved, the snowflake keeps turning at the same speed.

The rate is one exported value in degrees per second, and its sign chooses the direction, so reversing the spin is changing a minus sign in the editor. A slow rate is the intent: a full turn measured in tens of seconds, not in seconds.

This is the one behaviour of the three that is deliberately independent of everything else on the screen, and that independence is the point. The tilt behaviours give the screen a pose it holds; the spin gives it something that is always moving even when the phone is set down on a seat and left alone.

### 4. Slide the green halo with the tilt of the phone

The green halo drawn behind the blue snowflake slides a short distance from its authored position as the phone tilts, horizontally with the side-to-side tilt and vertically with the front-to-back tilt, clamped independently on each axis.

The mapping is direct rather than lagging. A given phone pose always puts the halo in the same place, and the halo stops when the phone stops rather than continuing to glide. What is still applied is the noise floor of requirement 1: a translucent disc roughly five hundred pixels across, mapped to a raw gravity reading, would shimmer visibly from ordinary hand tremor while the phone was held perfectly still. Rejecting the noise is not the same as adding lag, and only the first is wanted here.

The two clamps are separate exported values rather than one radius. The halo has more room to travel horizontally than vertically before it slides out from behind the flake it belongs to, and a single circular limit would either waste the horizontal room or overrun the vertical.

The drift is an offset from the sprite's rest pose, captured when the node is ready. The authored position stays the neutral, so nudging the halo in the editor moves the centre of its travel rather than the whole range, and nothing accumulates across frames.

**The halo moves and the snowflake does not.** They are siblings in `app/blue_snowflake.tscn`, offset from each other by about `(115, -48)`, and today they read as one composed object: a soft green disc sitting behind and up-right of a blue flake. After this feature the flake turns in place while the halo slides around underneath it, so the composition comes apart and reassembles as the phone moves. That is intended, and it is stated here so it is not read as a defect when it is first seen on a phone. The clamps of this requirement are what keep it from coming apart too far.

### 5. Build the three motions as reusable behaviours any artwork can carry

Three scripts, one per motion: a tilt sway, a continuous spin, and a tilt drift. Each attaches to the sprite it animates. Any sprite in the application gains a behaviour by having the script added to it and its values set, with nothing else to wire up.

A fourth file holds the one piece the two tilt behaviours share: reading the device's gravity vector, projecting it into the plane of the screen, and rejecting a reading too small to be anything but noise. It carries no behaviour of its own and is attached to nothing. The reason it exists rather than the six lines being written twice is Android: §"Platform notes" in `docs/system_design.md` records that the engine reports the gravity vector in opposite directions on the two platforms and that no Android handset has been measured, so this projection carries a known sign correction waiting to be made. One file means one place to make it for both behaviours. `snow/snow.gd` keeps its own copy and is not routed through this one, because editing a working sensor path is not this feature's business.

They live in `app/`, alongside the artwork scenes they serve. This is a departure from where the snow and the shake instrument live, and the reason is what they are. The snow is a self-contained effect with its own driver, its own emitters, and its own shader, which a screen adds as a unit; a top-level directory says that correctly. These are three small scripts that decorate existing artwork and produce nothing on their own. `app/` is where that artwork is and where `app/sprite_position.gd`, the script these most resemble, already sits.

They are separate scripts rather than additions to `app/sprite_position.gd`, which is shared by Winnie, the title, the play-along line, the instruction list, and the instrument selector. Adding sway properties there would grow tilt controls on every piece of artwork in the application, most of which will never use them.

None of the three is a `@tool` script. `app/sprite_position.gd` is one because its whole purpose is to show the composition correctly while a screen is being authored. A snowflake spinning in the 2D editor while a screen is being laid out is the opposite: motion that makes composing harder rather than easier, and that shows nothing a person needs to see at author time.

### 6. Make every constraint and rate adjustable from the editor

Every value that shapes any of the three motions is exported. Nothing a person will want to look at on a phone and change is written as a constant.

For the tilt sway: the maximum angle, the tilt fraction at which that angle is reached, the response time constant, and the noise floor. For the spin: the rate in degrees per second. For the tilt drift: the maximum horizontal travel, the maximum vertical travel, the tilt fraction at which each is reached, and the noise floor.

Starting values are proposed with the plan as somewhere to begin and nothing more. The judgement this feature turns on — whether a lean is "ever so slightly" or too much, whether a spin is slow enough to be calming rather than distracting — cannot be made anywhere but on a handset in a dark room, and the entire cost of getting it wrong should be changing a number in the inspector.

The exported values used as divisors or bounds are validated when the node is ready, with a message naming the value, its permitted range, and the correct default, as the repository's conventions require. The tilt fractions are the ones that matter: a value of zero divides by zero and a negative value inverts the motion, and both are easy to type by accident while adjusting a value in the inspector. Consistent with the repository's no-fallbacks convention, a bad value fails with a message naming what is wrong rather than quietly substituting a default and carrying on.

### 7. Hold the neutral pose where there is no sensor

The two tilt behaviours sit at their rest pose wherever no gravity is reported. §"Platform notes" in `docs/system_design.md` records that the motion calls return a zero vector in the editor, in the desktop build, and in the iOS simulator, which is documented engine behaviour rather than a fault. The tree therefore stands upright and the halo stays where it was placed in every one of those environments, which is also exactly how the artwork is composed and therefore what a person authoring a screen should see.

This is the same hold rule `snow/snow.gd` applies, arriving at its starting value rather than at a held one, and it means the composition in the editor is the composition at rest on a phone held level.

The continuous spin is unaffected. It reads no sensor, so it turns identically on a phone and in a desktop build. It does not turn in the editor, because it is not a `@tool` script.

### 8. Bring the three behaviours to the title screen without editing the screen

The title screen, `app/main.tscn`, carries all three motions, and is the only screen affected. It is not itself edited.

The whole of this feature's change surface is two scene files and four new scripts: the sway script attaches to the `Sprite2D` inside `app/straight_red_tree.tscn`, the spin and drift scripts attach to the two `Sprite2D` children inside `app/blue_snowflake.tscn`, and those three scripts plus the shared tilt reading of requirement 5 are new files in `app/`. Nothing else in the repository changes. Gravity is already enabled in `project.godot`, `app/sprite_position.gd` is untouched, the snow and the shake instrument are untouched, and no asset is added.

The title screen inherits the motion because it instances those two artwork scenes, and a script added to a node inside a scene reaches every instance of it. That is also why the title screen is the only screen affected: `app/straight_red_tree.tscn` and `app/blue_snowflake.tscn` are each instanced in exactly one place in the application, and that place is the title screen. Any screen that instances either scene later inherits the motion, and its exported values, with nothing further to do — which is the same drop-in property the snow has, arrived at from the other direction.

The title screen already carries the snow, so this feature is the first time the artwork and the weather answer the same tilt at the same time. Confirming that the tree leaning one way and the snow falling that way read as one coherent response rather than as two effects competing is part of the tuning this feature exists to make possible, and it is done on a handset.

## Token and design considerations

This feature builds no skill. There is no input limit to declare, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching topic

No teaching topic is needed. This feature applies the sensor-reading and exported-tunable patterns the repository already demonstrates in `snow/snow.gd`, and the self-contained-behaviour pattern its shake responders demonstrate. It adds no capability the tutor covers.
