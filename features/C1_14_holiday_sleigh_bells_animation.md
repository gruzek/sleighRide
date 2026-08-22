---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: A Title That Arrives in Time
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Gives the application its first musical gesture, so the title lands one word at a time on a beat an audience can feel and then keeps breathing on that beat for as long as anyone is looking at it.
LAST UPDATED: August, 22, 2026 15:09
---

# A Title That Arrives in Time

## Summary

A Title That Arrives in Time feature (C1_14) animates the three words of the title artwork, `Holiday`, `Sleigh`, and `Bells`, so they arrive one at a time on a musical beat and then go on breathing on that same beat. The screen holds still for one second, then each word zooms up from nothing, overshoots its size, and settles back, one word every quarter note at 80 beats per minute. After the three words have landed the pattern repeats every two bars, but as a slight pulse rather than an entrance: the same three words, the same quarter-note stagger, growing a little and coming back. The animation lives inside `app/holiday_sleigh_bells.tscn` itself, so any screen that instances the artwork gets it without doing anything.

## Background

The title artwork is three static sprites. `app/holiday_sleigh_bells.tscn` is a `Node2D` carrying `Holiday`, `Sleigh`, and `Bells` as three `Sprite2D` children, each placed and hand-sized at roughly 2.1 times its source artwork, and nothing about it has ever moved. The title screen that hosts it, `app/main.tscn`, now has falling snow behind and over it from the Snow That Falls the Way the Phone Is Held feature (C1_12), which means the title is currently the only thing on a moving screen that is standing still. It reads as artwork pasted onto a live background rather than as part of it.

The application is about a piece of music. An audience member opens it in a concert hall in the minutes before a live performance of "Sleigh Ride," and every interaction the product is built around, tapping and shaking to jingle, is a rhythmic one. Nothing in the application has yet expressed that. The snow answers to how the phone is held; nothing yet answers to a beat. A title that assembles itself in time is the cheapest possible way to say what kind of application this is before a single instruction has been read.

Two pieces of the repository already decide how this has to be built. The root node of the title scene runs `app/sprite_position.gd`, the shared placement script that derives the node's `position` from an authored `design_position` on ready and on every viewport resize, and a Godot node holds only one script. The Instrument Carousel feature (C1_08) met this same collision, a placed artwork scene that also needed behaviour, and resolved it by having the behaviour script extend the placement script rather than displace it. That precedent governs here. Separately, the Snow That Falls the Way the Phone Is Held feature (C1_12) established the shape of a self-contained visual effect in this repository: one scene, its own exported tunables, and a host that gains the effect by adding a node. This feature applies that same shape to artwork the application already owns.

No capability is deliberately deferred from this feature.

## Value Delivered

- **The title stops being a poster.** The one static element on a screen that already has moving snow starts moving with it, and the title screen becomes a composition rather than artwork laid over a background.
- **The application declares itself musical in its first two seconds.** Three words landing on three quarter notes tells an audience member what kind of application they are holding before they have read a word of instruction.
- **The screen stays alive while it is being read.** The pulse repeats every six seconds for as long as the title screen is up, so a person waiting for a concert to begin is never looking at something frozen.
- **One gesture, reusable.** The animation travels inside the artwork scene, so any screen that later shows the title gets the entrance and the pulse at the cost of instancing a node it was already instancing.
- **Tuning happens on the phone, not in the code.** Every duration and every size in the gesture is exported, so getting "snappy" right is a matter of adjusting values against a real device rather than editing and rebuilding.

## Terms

- **Beat.** One quarter note, 0.75 seconds, which is 80 beats per minute. Every timing in this feature is expressed against it.
- **Bar.** Four beats, 3.0 seconds, the 4/4 measure the pattern is written in.
- **Loop.** The repeating two-bar, eight-beat unit of the pattern, 6.0 seconds: three words on beats one, two, and three, then five beats of rest.
- **Entrance.** The gesture the first loop uses: a word grows from nothing, past its resting size, and settles back onto it.
- **Pulse.** The gesture every loop after the first uses: a word grows slightly above its resting size and returns, with no overshoot to correct.
- **Overshoot.** The amount by which the entrance carries a word past its resting size before it comes back, expressed as a percentage of that resting size.
- **Authored scale.** The scale a word is saved at in the scene file, roughly 2.1 and different for each of the three words. It is the word's resting size and the base every animated size multiplies against.

## Requirements Summary

- **1. Hold the title still for a full second before anything moves.** The screen appears complete and motionless, and only then does the first word arrive.
- **2. Bring each word in from nothing, overshooting its size and settling back.** A word grows from invisible past its resting size and returns to it, fast enough to read as a hit and slow enough to read as two motions.
- **3. Land the three words one beat apart so they read as "Holiday, Sleigh, Bells."** The stagger is what turns three animations into one sentence.
- **4. Pulse the words on the same rhythm once they have arrived.** The same three words on the same stagger, growing slightly and coming back, with no overshoot.
- **5. Repeat the pattern every two bars for as long as the screen is shown.** Three beats of words, five beats of rest, forever.
- **6. Grow each word about its own centre, against the size it was authored at.** Nothing moves and nothing is retyped: the animation multiplies whatever scale the word is saved at.
- **7. Make every timing and size adjustable on the device, and allow the animation to be switched off.** All of it exported, including an off switch for a screen that wants the title to sit still.
- **8. Keep the artwork visible and still while it is being authored.** The animation never runs in the editor, so the layout can still be composed.
- **9. Let the animation travel with the scene to any screen that uses it.** The gesture belongs to the artwork, not to the title screen.

## Requirements

### 1. Hold the title still for a full second before anything moves

The title screen appears with all three words absent, and one full second passes before the first word arrives. The delay is measured from the moment the screen is shown, and nothing about the title moves during it. The screen is not empty in that second: the background, the vignette, the logo, the other artwork, and the falling snow are all present and doing what they already do. Only the three title words are held back, so the entrance reads as something arriving into a scene that was already there rather than as a screen still loading.

### 2. Bring each word in from nothing, overshooting its size and settling back

A word enters by growing from a scale of zero to 112 percent of its authored scale over 0.12 seconds, then returning to 100 percent of its authored scale over 0.18 seconds. The total gesture is 0.30 seconds, well inside one beat, so each word is finished and still for nearly half a beat before the next one starts.

The word begins at a scale of exactly zero, which means it occupies no pixels and is genuinely absent rather than transparent. There is no fade and no change of opacity anywhere in this feature; scale is the only property animated. Because the resting state is the artwork at full size, the words must be scaled to zero before the screen's first frame is drawn, not when the one-second delay expires. A word that sits at its authored scale for even a single frame produces a visible flash of the finished title before it collapses and pops, which is the one failure mode this requirement exists to prevent.

The overshoot and the settle are two distinct motions and must read as two. The values above are the fastest at which that is still true. Faster than this and the eye takes the whole gesture as a single snap to size, losing the "went too far and came back" that the entrance is for.

### 3. Land the three words one beat apart so they read as "Holiday, Sleigh, Bells"

The three entrances are staggered by one beat, 0.75 seconds, in the reading order of the artwork: `Holiday` first, then `Sleigh`, then `Bells`. With the one-second delay, `Holiday` begins at 1.00 seconds, `Sleigh` at 1.75 seconds, and `Bells` at 2.50 seconds. Each word is a hit on a quarter note, on beats one, two, and three of the first bar.

The stagger is the point of the feature. Three words appearing together is a title fading in; three words appearing a beat apart is a title being spoken. The interval is identical between the first and second words and between the second and third, so the phrase has an even meter rather than a rushed or dragged middle.

### 4. Pulse the words on the same rhythm once they have arrived

Every set of three after the first is a pulse, not an entrance. A word grows from 100 percent of its authored scale to 105 percent over 0.12 seconds, then returns to 100 percent over 0.20 seconds. The gesture is 0.32 seconds, and there is no overshoot to correct, because 105 percent is the peak rather than a value passed through.

The pulse uses the same one-beat stagger and the same word order as the entrance, so the second set reads as the same phrase spoken again more quietly. This is the whole reason the intervals match: an audience member who saw the words arrive recognises the pulse as the same gesture, and the title appears to be keeping time rather than twitching.

The magnitude is deliberately small. This runs for as long as the title screen is up, and a larger pulse on three stacked words makes the layout look unstable rather than alive.

### 5. Repeat the pattern every two bars for as long as the screen is shown

The pattern is two bars of 4/4 at 80 beats per minute: words on beats one, two, and three, then five beats of rest, being the fourth beat of the first bar and the whole of the second. The loop is eight beats, 6.0 seconds, and it repeats without end while the title screen is displayed.

The first loop is the entrance. Every loop after it is the pulse. Nothing else about the two differs: the same three words, the same order, the same one-beat stagger, the same loop boundary. With the one-second delay, the first word of each set falls at 1.00, 7.00, 13.00, and 19.00 seconds, and so on.

The animation stops when the screen goes away and starts again from the entrance when the title screen is next shown. A person who leaves the title screen and comes back sees the words arrive again, because arriving is what the screen does.

### 6. Grow each word about its own centre, against the size it was authored at

Each word scales about its own centre and does not move. No word's position changes at any point in the entrance or the pulse, and the group as a whole is never scaled or moved. A word appears at exactly the place it will rest and grows there.

Every size in this feature is a multiplier on the word's authored scale, captured when the scene is ready, never an absolute value. The three words are hand-sized differently, currently 2.1309524 for `Holiday`, 2.1103897 for `Sleigh`, and 2.1027396 for `Bells`, and those numbers are composition decisions that will be adjusted again. An animation that names them, rather than multiplying against whatever it finds, silently resizes the artwork the first time a word is nudged in the editor. The resting state of every word after the entrance completes is its authored scale exactly.

The root node's own position and scale are left alone. `app/sprite_position.gd` owns the root's position and derives it from `design_position`, and this feature must not interfere with that: the animation touches only the three children's scales.

### 7. Make every timing and size adjustable on the device, and allow the animation to be switched off

Every number in the gesture is exported and adjustable without editing code: the initial delay, the beat interval, the loop length, the entrance overshoot and its two durations, and the pulse peak and its two durations. Getting "snappy" right is a judgement made watching a real phone, in the same way the snow's density and speed were tuned, and the values in this specification are a starting point rather than a commitment.

A single exported switch disables the whole animation, leaving the three words at their authored scales, motionless, exactly as the scene renders today. A screen that wants the title to sit still gets that by unticking a box rather than by maintaining a second copy of the artwork.

### 8. Keep the artwork visible and still while it is being authored

The animation never runs in the editor. The placement script the title scene's root already carries is a `@tool` script, and any script extending it inherits that, which means the animation code would otherwise run while the scene is open for editing. If it did, the words would be scaled to zero on ready and vanish from the 2D editor, and the layout could no longer be composed.

In the editor the three words are always at their authored scales, still, and fully visible. This is not a preference; the artwork is positioned and sized by eye against the design canvas, and that work is impossible if the words are not on screen.

### 9. Let the animation travel with the scene to any screen that uses it

The animation belongs to `app/holiday_sleigh_bells.tscn` and is delivered by it. A screen gains the entrance and the pulse by instancing the title artwork, which the title screen already does; there is nothing for a host to call, connect, or configure. This follows the pattern the snow established, where an effect is a scene and a host opts in by adding a node.

The behaviour extends `app/sprite_position.gd` rather than replacing it, following the Instrument Carousel feature (C1_08), which met the same constraint. The title screen places this scene through that script's exported `design_position` and `respect_safe_area` properties and must go on doing so unchanged. The title screen, `app/main.tscn`, is the first host and the test that the animation really does travel with the scene.

## Token and design considerations

This feature builds no skill; it is application code in a Godot project, and the token and design considerations that section is for do not apply.

## Teaching topic

No teaching topic is needed. This feature adds one animated behaviour to one existing artwork scene using tweening and script inheritance that the repository already demonstrates in the Instrument Carousel feature (C1_08), and it grants no competency a developer working in this repository does not already have from that feature and from the Snow That Falls the Way the Phone Is Held feature (C1_12).
