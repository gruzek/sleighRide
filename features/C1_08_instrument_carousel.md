---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Swipe Between Bells to Choose the One You Play
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.3
AUTHOR: George Ruzek
VALUE STATEMENT: Turns the bell selection screen from a picture of one bell into something an audience member pushes around with a thumb, and makes the bell they land on the bell they play.
LAST UPDATED: August, 19, 2026 07:41
---

# Swipe Between Bells to Choose the One You Play

## Summary

The Swipe Between Bells to Choose the One You Play feature (C1_08) turns the bell selection screen from a picture of a single bell into a carousel the audience member drags with a finger. Three bells are visible at once: the chosen one centred at full size, and its two neighbours half that size, centred on the same line and drawn behind it. Dragging moves the bells continuously with the finger rather than stepping between fixed positions, so the audience member can drag halfway, change their mind, and drag back. Releasing settles onto whichever bell the drag and its speed indicate. The carousel wraps, so it never runs out in either direction. The bell centred when the continue action is taken becomes the bell shown on the play screen. Each bell is defined once, in one place, as a reusable instrument that carries its artwork today and will carry its sounds later.

## Background

The bell selection screen is one of the four screens of the version 2 audience flow, and it currently shows one bell. `v2/instrument_carousel.tscn`, renamed from `v2/instrument_selector.tscn` while this feature was being planned, is a single sprite: one `Node2D` carrying the shared placement script with one `Sprite2D` beneath it. There is nothing to choose between and nothing to swipe, even though the screen already carries the instruction "Swipe to Select Your Bells!" and the roadmap already promises the interaction. Requirement 4 of the Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05) reads "Let the audience member choose which bell to play," and describes three bells with a swipe between them and a confirm control that carries the chosen bell forward. That requirement states the outcome; this feature builds the mechanism.

The play screen has the mirror-image problem. `v2/instrument.tscn` hard-wires `v2/instrument_01.tscn`, so it shows the same bell no matter what happens on the selection screen. Even if the selection screen offered a choice today, the choice would be discarded: `v2/instrument_select.gd` advances by calling `change_scene_to_file`, which destroys the current scene tree and everything held in it. There is no autoload in the project and therefore nowhere for a choice to survive the transition.

The artwork is ready. Three genuinely different sleigh bell instruments are in the repository, and each has been given its own scene: `v2/sleighbells_01.tscn`, `v2/sleighbells_02.tscn`, and `v2/sleighbells_03.tscn`. Each is a bare `Node2D` with a `Sprite2D` beneath it, positioned so the artwork sits where the developer wants it relative to the scene's origin. Critically, none of them carries the shared placement script, which matters because that script overwrites a node's position whenever the viewport changes and would fight a carousel that is animating the same property.

Four capabilities are deliberately deferred from this feature and are detailed under Future work: the set of sounds belonging to each bell, the "Did you know?" bubble, per-bell behaviour beyond artwork, and support for a two-bell carousel.

## Value Delivered

- **The selection screen finally does what it tells the audience to do.** The screen says "Swipe to Select Your Bells!" and today nothing happens when they try. Closing that gap removes the single most obvious unfinished thing in the flow before it goes in front of the sponsor.
- **The choice reaches the bell they play.** The instrument shown on the play screen becomes the one the audience member picked, which is the whole point of asking them to pick and the precondition for each bell sounding different.
- **A toy rather than a picker.** Because the bells track the finger and can be pushed back and forth before committing, the screen rewards fiddling with it. That is worth a great deal in the minutes before a concert starts, which is exactly when this screen is on screen.
- **The place sounds will attach to.** Each bell becomes a defined thing rather than a loose sprite, so adding its recordings later is a field on an existing object rather than a rework of how selection travels through the flow.

## Terms

- **Carousel offset.** The single continuous number that describes where the carousel currently sits. Zero means the first instrument is centred, one means the carousel has advanced exactly one position, and a half means it is midway between two.
- **Cyclic distance.** How far an instrument sits from the carousel offset, measured the short way around the cycle, so that the instrument before the first one is the last one.
- **Slot.** One of the three visible positions: the centre, the left, and the right.
- **Settle.** The short animation that runs when the finger lifts, carrying the carousel offset from wherever the drag left it to a whole number.
- **Flick.** A drag released while still moving quickly, which commits to the next instrument even when the drag itself was short.
- **Design canvas.** The 1080 by 1920 reference space every screen is drawn in, taken from the project's viewport width and height settings.
- **Autoload.** A Godot script instanced once at startup and reachable from every scene, which therefore survives a scene change.
- **Tool script.** A script marked to run inside the Godot editor as well as at runtime, so its effect is visible while a scene is being edited rather than only when the game is played.

## Requirements Summary

- **1. Turn the single bell into a carousel of bells.** The bell selection screen's selector becomes a carousel holding a list of instruments rather than one sprite.
- **2. Move the bells with the finger rather than in steps.** Dragging moves the carousel continuously, so it can be pushed forward, pulled back, and caught mid-settle.
- **3. Settle on one bell when the finger lifts.** Release commits to the next instrument or falls back, judged by how far the drag went and how fast it was released.
- **4. Show three bells at a time, and never a fourth.** The opacity rule that makes three visible and hides the rest, including the wrap.
- **5. Make the chosen bell twice the size of its neighbours.** One uniform scaling rule across all instruments, with the artwork's own size authored in its scene.
- **6. Take each bell's artwork from its own scene.** The three artwork scenes are the source of what the carousel and the play screen draw.
- **7. Define the set of bells once, and remember which was chosen.** An instrument definition and a single registry that survives the scene change.
- **8. Show the chosen bell on the play screen.** The play screen stops hard-wiring one bell and shows the selection.
- **9. Confine dragging to the space between the logo and the button.** The drag region, and what happens to a drag that begins on the continue control.
- **10. Move nothing on the screen except the bells.** Dragging affects the carousel and nothing else on the selection screen.
- **11. Tune the carousel by eye in the editor.** Every value that shapes the carousel is an editor-visible property with the composition drawn live.

## Requirements

### 1. Turn the single bell into a carousel of bells

`v2/instrument_carousel.tscn` becomes the carousel. It holds a list of instruments rather than one sprite, draws three of them at a time, tracks which one is chosen, and interprets the drag. The bell selection screen instances it exactly where it does today, at design position 532 by 931 with centre anchoring and safe-area respect, so nothing about how the screen positions the selector changes.

The carousel is described by a single continuous number, the carousel offset. Every instrument's position, size, depth, and transparency is derived from its cyclic distance from that number, so a whole number means an instrument is exactly centred and everything between whole numbers is a valid intermediate state. This is the reason the carousel can be dragged rather than stepped, and it is the reason there is no separate animation state to reconcile with the resting arrangement: the resting arrangement is simply the case where the offset happens to be whole.

The carousel is continuous in both directions. Advancing past the last instrument arrives at the first, and going back past the first arrives at the last, so the audience member can never reach an end and be stopped.

### 2. Move the bells with the finger rather than in steps

While a finger is down inside the drag region, the carousel offset follows it directly: moving the finger a set distance across the screen advances the carousel exactly one position, and the bells take their intermediate sizes and positions the whole way. Dragging halfway and reversing returns the bells to where they started, because the offset simply moves back; there is no committed step that has to be undone.

A touch that begins while a settle animation is running takes the carousel over from wherever it currently sits rather than waiting for it to finish or restarting it. The audience member catches a moving object rather than interrupting an animation, and a fast repeated flick therefore carries the carousel further rather than being discarded.

This is what makes the screen read as something being pushed around rather than a control being operated, which is the behaviour this screen is meant to have.

### 3. Settle on one bell when the finger lifts

When the finger lifts, the carousel animates from wherever the drag left it to a whole number, and the instrument at that number is the chosen one. Which whole number is decided by two things together. The distance dragged is compared against a commit threshold, so a drag that has carried the carousel past that fraction of a position commits to the next instrument and one that has not falls back to the current one. A release that is still moving quickly commits regardless, because a short, confident flick that snapped back would read as the app refusing the gesture.

The settle is a short eased animation rather than an instant jump, and its duration is one of the tunable values under requirement 11.

### 4. Show three bells at a time, and never a fourth

Transparency is a function of cyclic distance and nothing else. An instrument is fully opaque out to a cyclic distance of one, which covers the centre and both side slots, so none of the three visible bells is dimmed and the difference between chosen and unchosen is size and depth alone. Past that distance transparency ramps smoothly to nothing, reaching fully invisible at a cyclic distance of one and a half. Beyond that an instrument is not drawn. Position and size continue to vary smoothly across that whole range, so a bell on its way out is visibly receding rather than dissolving where it stands.

This single rule produces every case the carousel needs. With three instruments the far side of the cycle falls at exactly one and a half, so the bell travelling from one side slot around to the other crosses over at precisely the moment it is invisible, and the wrap is never seen. With four or five instruments the extras rest beyond one and a half and are simply not drawn, so three visible is what the rule yields rather than a limit imposed on top of it.

The carousel supports a list of one instrument, or of three or more. With a single instrument there is nowhere to go, so dragging does not move the carousel. A list of exactly two is not supported by this feature; the reason and the deferral are under Future work.

### 5. Make the chosen bell twice the size of its neighbours

Scaling is uniform across all instruments: the carousel multiplies whatever the artwork scene already is by one at the centre slot and by one half at the side slots, so the chosen bell is exactly twice the size of each neighbour. The multiplier varies smoothly between and beyond those points in step with the position and transparency described in requirement 4.

The carousel applies no per-instrument size correction and no per-instrument vertical correction. Each artwork's own size and its position relative to its scene's origin are authored in that scene, by eye, in the Godot editor. This is a deliberate division: the carousel is responsible for the arrangement, and the scene is responsible for how its own artwork sits. Every slot is placed on one horizontal line and one common vertical line through the carousel's origin, and any deviation from that is something the artwork scene is expressing on purpose.

### 6. Take each bell's artwork from its own scene

The three artwork scenes are `v2/sleighbells_01.tscn`, `v2/sleighbells_02.tscn`, and `v2/sleighbells_03.tscn`. Each is a `Node2D` with a `Sprite2D` beneath it, and each is used unmodified by both the carousel and the play screen: the carousel instances one into each slot and drives the slot, and the play screen instances the chosen one.

None of these scenes carries the shared placement script `v2/sprite_position.gd`, and none may. That script derives a node's position from an authored design position and rewrites it whenever the viewport changes or an exported property is edited, which is correct for a fixed piece of screen furniture and wrong for a node whose position is the output of a drag. The carousel positions its slots itself.

`v2/instrument_01.tscn` is retired. It is a second copy of one bell's artwork carrying the placement script, and everything it does is done by the artwork scene plus the play screen's own placement.

### 7. Define the set of bells once, and remember which was chosen

An instrument is a reusable resource. It holds the artwork scene that draws it, and it is the object each bell's set of recordings will later be added to. It holds nothing about size or position, because requirement 5 places those in the artwork scene.

The ordered list of instruments is held by the carousel, assigned to it rather than compiled into it, so that adding, removing, or reordering bells is one edit in one place. A single autoload holds the chosen instrument itself. The carousel writes the chosen instrument there as the selection changes, and the play screen reads it. Because what travels is the instrument rather than a position in a list, the play screen never needs the list at all, and the list therefore exists in exactly one place rather than once in the selection screen and again in the play screen.

The autoload is what makes the choice survive the flow. The bell selection screen advances with `change_scene_to_file`, which destroys the scene tree and everything in it, and the project has no autoload today, so this is new. Nothing is written to disk: the choice lasts for the session, which is all the flow needs, because the audience member moves forward through the four screens once and there is no backward navigation.

### 8. Show the chosen bell on the play screen

`v2/instrument.tscn` stops instancing one fixed bell and instead instances the artwork scene of the chosen instrument, at the position and with the presentation the screen carries today. The play screen applies its own size multiplier, separate from the carousel's, because it shows the bell larger than the selection screen does; this is the role the existing `scale = Vector2(2, 2)` plays on the retired `v2/instrument_01.tscn`.

The instrument centred at the moment the continue control is pressed is the chosen one. There is no separate confirmation step and no way to choose a bell other than by bringing it to the centre.

### 9. Confine dragging to the space between the logo and the button

The drag region is a band running from below the Richmond Symphony logo at the top of the screen to above the continue button at the bottom. It spans the full width. The "Swipe to Select Your Bells!" instruction, the carousel, and the Winnie illustration all fall inside it, which is correct: the line instructing the audience member to swipe should itself be draggable.

The band is expressed against the same anchored, safe-area-aware positions the rest of the screen uses, so it tracks the logo and the button on a taller or shorter screen rather than being a fixed rectangle in the design canvas.

The continue button keeps its own rectangle outright. A press that begins on the button belongs to the button and does not move the carousel.

### 10. Move nothing on the screen except the bells

Dragging inside the band moves the carousel and nothing else. The logo, the instruction line, the vignette, the Winnie illustration, and the continue button all hold still. There is no parallax, no drag-following on any other element, and no response from the screen background.

Beyond that, the bell selection screen is left as it is. The screen's existing composition, its artwork, its instruction text, and its continue button and styling are unchanged, and no screen is added or removed from the flow.

### 11. Tune the carousel by eye in the editor

Every value that shapes the carousel is an exported property on the carousel, not a constant inside its script: the distance from the centre slot to the side slots, the side slot scale, the cyclic distance at which transparency begins and the distance at which it reaches nothing, the drag distance that equals one position, the commit threshold, the flick sensitivity, and the settle duration. The list of instruments is likewise assigned rather than compiled in.

The carousel runs as a tool script, so the arrangement is drawn in the Godot editor as the properties are changed and the composition visible while the screen is being edited is the composition the device will render. This follows the precedent set by the Fit the Audience Flow to Any Phone Screen feature (C1_07), whose requirement 4 makes the same argument for the shared placement script: this layout is art-directed by eye, and a rule whose effect is only visible after export cannot be judged while it is being authored.

A working prototype of the carousel's motion, built with the three real bell artworks, is at `features/mockups/C1_08_instrument_carousel.html`. Its starting values are a side slot distance of 170 design pixels, a side slot scale of 0.50, full opacity to a cyclic distance of 1.00 ramping to nothing at 1.50, a drag distance of 420 design pixels per position, a commit threshold of 0.50, and a settle of 320 milliseconds. These are a starting point for tuning in the editor, not a specification.

## Future work

**Each bell's own sounds.** Every bell is meant to carry its own set of recordings, with repeated taps drawing from that set at random so they do not sound mechanically identical. This is the reason requirement 7 defines an instrument as a resource rather than leaving the carousel to hold a bare list of artwork scenes: the recordings become a field on an object that already exists and that the play screen already reads, rather than a second selection mechanism bolted alongside the first. Requirement 5 of the Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05) describes the interaction, and the professional recordings are being produced separately as task `C1_T04`.

**The "Did you know?" bubble.** Requirement 4 of the Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05) places a fun-fact bubble on this screen. It is not built here, and if its content ever varies by bell it becomes another field on the instrument resource that requirement 7 establishes.

**Per-bell behaviour beyond artwork.** Because the carousel instances a scene rather than drawing a texture, a bell can later be more than a still image: an animation, a reaction when it is brought to the centre, or a flourish when it is tapped on the play screen. Nothing of the kind is built here, and no bell behaves differently from any other.

**A two-bell carousel.** A list of exactly two instruments is not supported. Two is the one count a cycle cannot express cleanly, because the second instrument sits the same distance away in both directions and there is no honest answer to which side it should approach from. Every rule in this feature holds for one instrument and for three or more. Should a two-bell arrangement ever be wanted, it needs its own decision about how the pair exchanges places, and it would be a small, self-contained addition to requirement 4.
