---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Snow That Falls the Way the Phone Is Held
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Turns the phone in an audience member's hand into weather, so that tilting it steers the snowfall on screen and the app is alive before a single bell is shaken.
LAST UPDATED: August, 22, 2026 11:43
---

# Snow That Falls the Way the Phone Is Held

## Summary

The Snow That Falls the Way the Phone Is Held feature (C1_12) adds a self-contained snowfall scene that any screen in the application can instantiate and immediately get falling snow. The snow reads the phone's sense of down from the gravity sensor every frame and steers itself by it, so tilting the phone turns the snowfall and the flakes already in flight curve onto the new heading rather than waiting to be replaced. Snow enters from off screen on whichever side is currently upwind, three snowflake images fall at three depths, each flake flutters and tumbles as it descends, and each catches the light on its own rhythm. The instructions screen is the first host and the test of the whole thing.

## Background

The audience flow is four static screens. The title, instructions, bell selection, and play screens each draw artwork on a near-black background and none of it moves. An audience member sitting in a concert hall before "Sleigh Ride" begins is holding a phone that senses exactly how it is being held, and until the play screen the application ignores that entirely. The instructions screen is the worst of the four in this respect: it is a title, a piece of artwork, four lines of instruction, and a button, and it is the screen an audience member spends the longest reading.

There is no ambient motion of any kind in the application today, and no reusable visual effect. The Measure a Real Shake So the Bells Sound When a Real Bell Would feature (C1_09) established the pattern for a self-contained instrument a screen can add — the shake detector is a scene deliberately kept off the autoload list so that a screen opts into it — but nothing in the repository yet applies that pattern to a purely visual effect. The one snowflake asset in the repository, `blue_snowflake.png`, is a decorative column of flakes used as artwork on the title screen; it is not a particle and does not move.

The device's own sensors are already enabled and already understood. The gravity sensor is switched on in the project settings and the archived first version of the application read it to tumble its bells, so mapping the device's gravity vector into screen coordinates is ground the repository has covered before. What has never been done is using it to steer something continuously.

One capability is deliberately deferred from this feature and is detailed under Future work: a per-flake pendulum flutter driven by a custom particle process shader.

## Value Delivered

- **The application starts moving.** Every screen it is added to gains ambient motion, which is the difference between a poster and an application in the hand.
- **The phone becomes part of the picture before a bell is ever shaken.** Tilting the phone visibly steers the weather, so an audience member discovers that the application is watching how they hold it on the instructions screen rather than on the play screen.
- **One effect serves every screen.** The snow is authored once and added anywhere, so the title, selection, and play screens can each carry it later at the cost of dropping in a node.
- **The instructions screen stops being a wall of text.** The screen an audience member reads the longest gains something to look at while they read it.
- **Tuning happens on the device, not in the code.** Density, speed, opacity, flutter, and sparkle are exported per layer, so getting "subtle" right is a matter of adjusting values against a real phone in a real room.

## Terms

- **Driver.** The single node that reads the gravity sensor, works out which way is down in screen coordinates and how strongly, and writes that to each emitter. It is the only thing in the feature that touches a sensor.
- **In-plane gravity.** The part of the device's gravity vector that lies in the plane of the screen. It is what a tilt reveals: near zero when the phone lies flat and face up, near full gravity when the phone is held upright.
- **Emission band.** The thin strip, positioned just outside the viewport on the upwind side and perpendicular to the current fall direction, from which new flakes are born. It orbits the viewport as the direction changes.
- **Depth layer.** One emitter and its snowflake image, given a scale, speed, and opacity that place it near to or far from the viewer.
- **Flutter.** The wandering, tumbling path a flake takes as it falls, as distinct from the direction it is falling in.
- **Sparkle.** The gentle oscillation of a flake's brightness while it is on screen, so that flakes catch the light at different moments.

## Requirements Summary

- **1. Make the snow something any screen can drop in.** A self-contained scene with its own directory, exported tunables, a screen that opens with snow already falling, and correct behaviour when the viewport changes size.
- **2. Steer the snow by the way the phone is held.** One driver reads the gravity sensor each frame and turns the snowfall, curving the flakes already in flight rather than only the new ones.
- **3. Hold the heading when the phone lies flat, and slow the fall with it.** The direction freezes below a minimum tilt so a flat phone does not spin the snowfall on sensor noise, and the fall strength scales with the tilt so a flat phone gives slow, hanging snow.
- **4. Bring snow in from off screen, wherever off screen currently is.** The emission band orbits the viewport so that new flakes always arrive from the upwind side, at any angle.
- **5. Fall three snowflakes at three depths.** Each of the three snowflake images gets its own emitter, assigned to a near, middle, or far layer by its softness.
- **6. Make each flake flutter and tumble as it falls.** A shared, slowly drifting noise field and a randomised per-flake spin, both subtle.
- **7. Make each flake sparkle on its own rhythm.** A small shader gives every flake its own phase and rate, so they catch the light independently and repeatedly.
- **8. Render the snow in front of the screen's content.** Flakes pass over the artwork and the text, without obscuring what is being read and without intercepting a button press.
- **9. Add the snow to the instructions screen.** The first host, and the test that the scene really is a drop-in.

## Requirements

### 1. Make the snow something any screen can drop in

The snowfall is one scene that a screen instantiates and nothing more. It brings its own driver, its own emitters, its own materials, and its own shader; the host screen adds a node and gets snow.

It lives in its own directory at the top level of the repository, alongside the shake instrument rather than inside the application's screen directory. The reason is the precedent the shake instrument already sets: an effect that any screen may opt into is not part of any one screen, and burying it among the screens would say the opposite. It is also, like the shake detector, deliberately not an autoload — a screen that wants snow asks for it.

Every value that shapes the effect is exported and adjustable per depth layer: how many flakes, how fast they fall, how large they are, how opaque, how much they flutter, and how strongly they sparkle. Nothing that a person will want to look at on a phone and change is a constant in code. The tuning that matters here is perceptual and has to be done against a real device, so the values are reachable from the inspector.

A screen carrying the snow opens with snow already on it rather than with an empty sky that fills in over the first several seconds. Particle systems begin empty, and on a screen an audience member may look at for only a few seconds, an empty sky is most of what they would see.

The scene re-fits itself when the viewport changes size, in the same way the rest of the audience flow already does. The emission band's position and length are both derived from the viewport rectangle, so a scene that does not respond to a resize would emit from the wrong place on any phone whose screen differs from the one it was authored against — which is every phone.

### 2. Steer the snow by the way the phone is held

One driver node reads the device's gravity vector each frame, projects it into the plane of the screen, and writes the resulting direction and strength to every emitter's particle material as its gravity. It is the only part of the feature that reads a sensor, and gravity is the only property it writes.

The sensor is the gravity sensor, not the gyroscope. The gyroscope reports angular velocity — how fast the phone is rotating — which does not describe which way down is and cannot be integrated into an orientation without drifting. The gravity sensor reports the gravity vector directly. It is already enabled in the project settings, and the archived first version of the application already mapped it into screen coordinates, so the conversion is established rather than novel.

Writing the direction to the material's gravity, rather than to each flake's spawn velocity, is what makes the flakes already in flight change course. Gravity applies to every live particle on every frame, so a phone that turns turns the whole visible snowfall, and a flake that was heading down when the phone was upright curves as the phone tilts. A spawn velocity would only affect flakes not yet born, and the screen would take a full flake lifetime to answer.

The direction is smoothed rather than snapped to the sensor reading. Snow has inertia and a hand is never still; a direction that tracks the sensor exactly would jitter with every small movement of the hand and would swing instantly on a deliberate turn, neither of which reads as weather. How quickly the direction follows is one of the exported values.

### 3. Hold the heading when the phone lies flat, and slow the fall with it

The driver governs the fall direction and the fall strength by two separate rules, both derived from the in-plane gravity.

**Direction.** Below a minimum in-plane magnitude, the direction stops updating and the snow keeps falling the way it last was. When a phone lies flat and face up, almost all of gravity points through the screen rather than across it, so what remains in the plane is small enough to be dominated by sensor noise — and a direction taken from it would spin the snowfall wildly while the phone sits perfectly still on a table. Freezing the last good heading is what the archived first version of the application did for the same reason, and it is the correct answer here: a phone laid down keeps the weather it had.

**Strength.** The strength of the fall scales with the in-plane magnitude, independently of the direction rule. A phone held upright gets the full fall speed; a phone tilted back toward flat gets progressively slower snow, until a phone lying flat gives snow that hangs and drifts almost in place. This turns the one pose where the direction reading is useless into a deliberate effect rather than a defect to be worked around, and it costs a single multiplication.

The two rules are stated separately because they are separate. The direction freezes at a threshold; the strength is continuous. A phone tilted to flat therefore slows to a drift while still travelling the way it last was, which is the intended behaviour and not an interaction to be resolved.

### 4. Bring snow in from off screen, wherever off screen currently is

New flakes are born on a thin band positioned just outside the viewport on the upwind side, oriented perpendicular to the current fall direction. As the direction changes, the band orbits the viewport so that it is always the side the snow is coming from.

A band fixed above the top edge would work only while down is down. Tilt the phone far enough and the snow travels across the screen rather than down it — but the source would still be sitting above the top edge, with nothing upstream of the visible area, and the screen would empty out from the new upwind side while flakes piled off the new downwind one. The band has to know where upwind currently is, because the whole point of the feature is that upwind moves.

The band's length is derived from the diagonal of the viewport rather than from its width or its height. At any angle other than square-on, a band only as long as the screen is wide leaves the corners unfed; sized to the diagonal, it spans the visible area whichever way it is turned. Some of the band therefore sits outside the visible area much of the time, which is the correct trade — it is a line rather than an area, so the flakes it wastes are few compared with emitting throughout a box large enough to cover every direction at once.

### 5. Fall three snowflakes at three depths

Each of the three snowflake images in the repository gets its own emitter, and each emitter is a depth layer with its own scale, fall speed, and opacity. Three emitters rather than one sprite sheet, because the images arrived as three separate files and because separating them is what allows each to be tuned on its own.

The three images are all soft white radial gradients of the same size, differing only in how the gradient falls off, which is exactly the difference that reads as depth:

| Image | How it falls off | Layer |
|---|---|---|
| `snowflake_03` | An opaque core holding most of its brightness to nearly half the radius before fading | Near — largest, fastest, most opaque |
| `snowflake_02` | Fading to nothing by roughly two thirds of the radius, a tighter dot with a soft edge | Middle |
| `snowflake_01` | Fading to nothing across the full radius, the most diffuse of the three | Far — smallest, slowest, faintest |

The assignment is authored rather than computed, and it is adjustable; what matters is that the brightest-cored flake reads as nearest and the most diffuse as furthest, which is how a real depth of field behaves.

The three images are vector files that rasterise to roughly eleven pixels square at the repository's current import scale, against a design canvas that is 1080 pixels wide. The emitters therefore scale them up substantially, which is acceptable precisely because they are soft gradients with no detail to lose, or the import scale is raised so the rasterisation happens at a useful size. Either resolution is fine; what is not acceptable is authoring an eleven-pixel flake and discovering on a phone that the snow is invisible.

### 6. Make each flake flutter and tumble as it falls

A flake does not fall in a straight line. Two things are added so that these do not either.

**A shared noise field.** The particle material carries a turbulence field at low strength, scrolling slowly, that the flakes wander through as they descend. Because the field is shared and continuous, flakes near one another drift together — which reads as a faint breeze moving through the snow rather than as a defect, and is a better result than each flake wandering in isolation would give.

**A per-flake tumble.** Each flake rotates at its own randomised rate as it falls, so no two are turning together.

Both are built from the particle material's own properties rather than from a custom particle process shader. The alternative — a custom process shader giving each flake an independent sine sway perpendicular to its fall — produces a truer pendulum flutter, but a custom process shader replaces the standard material outright, which would move the fall gravity, the emission along the orbiting band, the spawn velocities, and the lifetimes all into shader code. The two mechanisms this feature is actually about, the rotating gravity of requirement 2 and the orbiting band of requirement 4, would become shader uniforms rather than inspector fields, and both are things that will want adjusting against a real device. The subtle effect asked for here does not justify that cost. It is named under Future work as the follow-on if the result reads too uniform once the real flakes are moving.

### 7. Make each flake sparkle on its own rhythm

A small shader on the flakes gives each one its own phase and its own rate, seeded from per-particle random data, and oscillates its brightness gently while it is on screen. Flakes therefore catch the light at different moments, repeatedly, for as long as they are visible.

The alternative of a brightness ramp over each flake's lifetime, which needs no shader at all, was considered and rejected: a ramp brightens and dims each flake exactly once across its whole life, which at the lifetimes this snowfall needs is a slow fade rather than a sparkle, and it would barely register.

The amplitude of the oscillation is one exported value. "Subtle" is a judgement that has to be made looking at a phone in a dark room, not decided in advance, and the whole cost of getting it wrong should be changing a number.

### 8. Render the snow in front of the screen's content

The snow renders above the host screen's artwork, text, and controls, so flakes pass over Winnie and over the instruction lines rather than behind them.

The near layer's opacity is held low enough that text underneath it stays readable. This is the cost of rendering in front, and it is paid deliberately: snow that falls behind everything puts the artwork in front of the weather instead of in it, which is the wrong relationship for an effect meant to make the screen feel like a place.

The snow does not intercept input. A screen carrying it must have every button still pressable exactly as before, with no dead area where a flake happens to be.

### 9. Add the snow to the instructions screen

The instructions screen carries the snow, and is the first screen to do so.

It is the right first host on both counts that matter. It is the screen an audience member spends the longest on, reading four lines of instruction, so it is where ambient motion is worth the most and where the readability constraint of requirement 8 is tested hardest. And its near-black background and existing vignette give white flakes the contrast to read at all, which a lighter screen would not.

No other screen is changed by this feature. Adding the snow to the title, selection, or play screens is a matter of dropping the same node in, and is deliberately left until this one has been looked at on a real phone.

## Token and design considerations

This feature builds no skill, so there is no input limit to declare, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching topic

No teaching topic is needed. This feature applies the self-contained-effect pattern the repository already demonstrates in its shake instrument, and adds no capability the tutor covers.

## Future work

**A per-flake pendulum flutter.** Requirement 6 produces flutter from a shared noise field, which means flakes near one another wander together. If the result reads too uniform once the three real flakes are falling on a phone, the follow-on is a custom particle process shader giving each flake an independent sine sway perpendicular to its fall — the true flutter of a real snowflake. It is a contained change but not a small one, because a custom process shader takes over the whole of the particle material and the fall gravity, emission band, spawn velocity, and lifetime all move into it.

**Snow on the moment, as distinct from snow in the room.** The roadmap already carries the Snow Confetti item (C1_04) as a stretch goal: a festive burst on the moment the audience plays. That is a different effect from this one — a punctuation rather than an atmosphere — but it is adjacent enough that whichever is built second should reuse the flake images and the shader this feature establishes rather than introducing a second set.
