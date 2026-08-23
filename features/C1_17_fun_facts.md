---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: A Fun Fact Winnie Tells While You Choose Your Bells
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Turns the pause where an audience member picks a bell into the moment they learn something about the orchestra they came to hear.
LAST UPDATED: August, 23, 2026 09:39
---

# A Fun Fact Winnie Tells While You Choose Your Bells

## Summary

The Fun Facts Bubble feature (C1_17) gives Winnie a speech bubble on the bell selection screen. The bubble carries a fixed "Did you know?" header and one fun fact drawn from a list that can hold any number of facts and is extended by typing into it. Every fact is shown once before any is repeated; when the list is exhausted it begins again in a fresh order. The bubble pops into place the way the three words of the title arrive on the title screen — growing from nothing, past its resting size, and settling back — and then breathes on the same beat for as long as the screen is shown. It is artwork and text only: it is not tapped, it is not dismissed, and it takes nothing away from the swipe that chooses a bell.

## Background

The bell selection screen is where an audience member stops moving. The title screen and the instructions screen are both read and passed through in a few seconds, and the play screen is where the shaking happens, but the selection screen is a decision — three bells, a swipe between them, and however long someone takes to pick one. Today that pause is filled with a title, a swipe instruction, three bells, falling snow, and Winnie standing silently in the bottom-left corner. It is the one screen in the flow with room on it and nothing to read.

This bubble has been on the books since before the native build. The Instrument Carousel feature (C1_08) named it as one of four capabilities deliberately deferred, recording that "the 'Did you know?' bubble… is not built here, and if its content ever varies by bell it becomes another field on the instrument resource". The Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05) placed it on this screen in the design and observed that the design carries only the placeholder text "Insert fun facts", which reads as unfinished work in front of a sponsor. That mockup feature is superseded — the application is a native build, not a single-page app — but the design it describes is the design this screen is still built to, and the bubble in it has simply never been built.

There is one thing this feature does that nothing in the application has done before, and it is worth naming before the requirements rather than discovering during the build. **Every word currently on screen is artwork.** The Richmond Symphony title, "Swipe to Select Your Bells!", every line of the instructions list — all of them are Scalable Vector Graphics (SVG) files in `images/v2/`, drawn as sprites. The only live text anywhere in the application is the label on a button, and those are running the engine's default typeface because the repository contains no font file at all. A pool of facts that can be extended by typing into a list cannot be artwork, by definition, so this feature is where the application starts rendering real text. It does so on the default face, which is a knowingly temporary state described in requirement 6.

Two capabilities are deliberately deferred and detailed under Future work: the brand typeface, and any fact that belongs to a particular bell rather than to the screen.

## Value Delivered

- **The waiting turns into an impression.** The one screen where an audience member pauses now tells them something about the orchestra they are sitting in front of, instead of showing them an empty corner.
- **Winnie starts talking.** The mascot has stood mute in every screen she appears on. A bubble growing out of her mouth is the cheapest character work available and it costs no new artwork beyond one shape.
- **The facts are yours to change, forever, without a developer.** Adding, cutting, or rewriting a fact is typing into a list in the editor. There is no file format to learn, no code to touch, and no rebuild of anything but the application itself.
- **Nobody reads the same fact twice.** Every fact is shown before any is repeated, so an audience member who moves between the bells and the play screen four times reads four different facts rather than the same one four times.
- **A design promise made a year ago is kept.** The bubble has been in the design and deferred by two prior features. This is the one that builds it.
- **Nothing that works is disturbed.** The bubble is inert artwork and text. The swipe that chooses a bell, the snow, the carousel, and the shake instrument are all left exactly as they are.

## Terms

- **Fun fact pool.** The full list of facts the bubble can draw from, held on the bubble scene and extended by adding entries to it.
- **Shuffle bag.** The mechanism that guarantees no fact repeats until all have been shown: the pool is shuffled into a bag, facts are drawn from it one at a time, and when the bag is empty the pool is shuffled into it again.
- **Resting scale.** The size the bubble is authored at in its scene. Every size in the pop is a multiple of it, so resizing the bubble in the editor is picked up on the next run rather than fought.
- **Pop.** The entrance gesture established by the Title Words That Arrive on the Beat feature (C1_14): growing from nothing to slightly past the resting scale, then settling back onto it.
- **Pulse.** The repeating gesture that follows the pop in that same feature: the same shape at a smaller peak with no overshoot, once every eight beats.
- **Tail pivot.** The point on the bubble the pop scales from, placed at the tip of the tail so the bubble inflates out of Winnie's mouth rather than swelling from its own centre.
- **Drag band.** The full-width region of the bell selection screen in which a touch is read as a swipe between bells, defined by `instrument_carousel.gd` between insets measured from the safe area.

## Requirements Summary

- **1. Give Winnie a speech bubble on the bell selection screen.** A supplied bubble shape with its tail at Winnie's mouth, carrying a fixed header and one fun fact.
- **2. Hold the facts in one list anyone can extend.** An exported list of any length, edited in the editor, shared by the whole screen rather than by any one bell, and with an empty list hiding the bubble entirely.
- **3. Show every fact once before any is repeated, then begin again.** A shuffle bag held in memory that survives moving between screens and refills when it empties.
- **4. Show one fact for the whole visit.** The fact is drawn when the screen is entered and does not change while the audience member is on it.
- **5. Pop the bubble the way the title words arrive.** The entrance and the eight-beat pulse of the title animation, scaled from the tail, after a short delay.
- **6. Set the words in live text the brand typeface can replace later.** Real text on the engine's default face, with the typeface set in exactly one overridable place, and the fact shrinking within a floor to fit the fixed bubble.
- **7. Leave the swipe between bells untouched.** The bubble is inert: no tap target, no dismissal, and no dead zone in the carousel's drag band.
- **8. Add the bubble to the bell selection screen and nothing else.** One new scene, one new script, one supplied image, and one instance on one screen.

## Requirements

### 1. Give Winnie a speech bubble on the bell selection screen

A speech bubble appears on the bell selection screen, above and to the right of Winnie, with its tail pointing down and to the left at her mouth. It carries two pieces of text: a fixed header reading "Did you know?", identical on every appearance, and beneath it one fun fact drawn from the pool.

The bubble shape is a single supplied image placed in `images/v2/`, drawn as a sprite. It is a fixed size: the artwork does not stretch, tile, or grow to accommodate a longer fact, and requirement 6 covers what happens to text that would not otherwise fit. A fixed shape is what keeps the bubble exactly as the design draws it, including the organic curve of the tail, which is the part of the shape a nine-sliced or code-drawn substitute would show its seams on.

The bubble is built as its own scene in `app/`, positioned by `app/sprite_position.gd` through the exported `design_position` and anchor properties, the same as Winnie, the title, the swipe line, and every other piece of artwork on this screen. It is not authored directly into the screen. That is what lets the bubble be moved by editing one property against the design canvas, and it is what would let another screen carry the bubble later by instancing one node.

It sits above Winnie in draw order and above the falling snow's rear layers, so the bubble is never a text panel with snow drawn through the middle of it. The snow's nearest layer passes over everything on the screen by design, and it passes over the bubble too.

### 2. Hold the facts in one list anyone can extend

The facts live in one exported list of text on the bubble scene, edited from the Godot inspector. Adding a fact is adding an entry to that list. There is no fixed count: the list holds as many facts as are typed into it, and nothing in the feature assumes a particular number.

An exported list is chosen over a resource file or an external data file because it is what this repository already does with everything a person is expected to change. Every constant in the snow, every value in the carousel, and every timing in the title animation is exported and tuned from the inspector against a real phone. A separate facts file would introduce a format to maintain, a load path to validate, and a failure mode — a missing or malformed file — that a list in the inspector simply cannot have.

**The pool belongs to the screen, not to a bell.** Which bell is centred in the carousel has no effect on which fact is shown. This is the question the Instrument Carousel feature (C1_08) left open when it recorded that a fact varying by bell would become another field on `InstrumentDefinition`, and the answer here is that it does not vary, so `app/instrument_definition.gd` and the three resources in `app/instruments/` are untouched by this feature.

**An empty list hides the bubble.** With no facts in the pool the bubble does not appear at all — no shape, no header, and no pop. An empty white shape with a heading and nothing under it is worse than an absence, and this is also what keeps a half-configured scene from being demonstrated by accident. The bubble hiding itself is not a fallback in the sense the repository's conventions forbid; nothing is substituted and nothing carries on pretending, the feature simply has no content to present and presents none.

### 3. Show every fact once before any is repeated, then begin again

Facts are drawn from a shuffle bag. The pool is shuffled into a bag, each entry to the screen takes the next fact from it, and when the bag empties the whole pool is shuffled into it again in a fresh order. Across a pool of twelve facts, an audience member sees twelve different facts before seeing any of them a second time.

The reason this is worth building rather than drawing at random is the shape of the flow. The play screen's Back button returns to bell selection, and `change_scene_to_file` destroys the entire scene tree and rebuilds it, so every return is a fresh entry and a fresh draw. Somebody who tries all three bells passes through this screen three times in under a minute. Independent random draws from a pool of eight facts would repeat within those three visits about one time in three, and the repeat is the thing a person notices — it reads as the application having very little to say rather than as chance.

**The bag is held in memory and written nowhere.** It lives in a static variable on the bubble's script rather than in an autoload or a saved file. A static variable persists for as long as the script class is loaded, which is for as long as the application is running, so it survives the scene change that destroys the bubble itself. That is the whole of the requirement: nothing is written to disk, no save file is created, and no user data is stored.

An autoload would also survive the scene change, and is deliberately not used. There are exactly two autoloads in this application, `InstrumentSelection` and `ShakeEvents`, and each earns its place by being needed by more than one screen. A fact-shuffling bag needed by one node on one screen does not, and adding it to the global namespace would make the autoload list a place where small things accumulate.

Relaunching the application starts over with a full bag. This is correct rather than a limitation: a fresh launch is, in a concert hall, a fresh audience member.

### 4. Show one fact for the whole visit

One fact is drawn when the screen is entered, and that fact stays in the bubble until the screen is left. The text does not rotate, cycle, or refresh while the audience member is on the screen, however long they linger.

The screen's job is choosing a bell. A fact that swapped itself out every few seconds would put a second thing in motion next to three bells someone is actively swiping through, and would drain the bag during a single visit rather than across the several visits requirement 3 is designed around.

### 5. Pop the bubble the way the title words arrive

The bubble arrives with the gesture the Title Words That Arrive on the Beat feature (C1_14) established, and then goes on breathing on the same beat, exactly as the three words of the title do on the title screen.

The entrance is the pop: the bubble starts at nothing, grows past its resting scale, and settles back onto it. What follows is the pulse: the same shape at a smaller peak with no overshoot to correct, repeating once every eight beats for as long as the screen is shown. The tempo, the loop length, and the peaks come from `app/holiday_sleigh_bells.gd`, which sets a beat at 0.75 seconds — 80 beats per minute — a loop of eight beats, an entrance that overshoots to 1.12 of resting, and a pulse that peaks at 1.05. This feature reuses those numbers rather than choosing its own, because a second tempo on a second screen is two things to keep in agreement and there is nothing here that wants a different one.

**The pop scales from the tail, not from the centre.** The bubble's origin is placed at the tip of its tail, at Winnie's mouth, so growing from nothing reads as the bubble inflating out of her rather than as a shape swelling in mid-air. As with the sway of the Artwork That Answers the Tilt of the Phone feature (C1_15), that origin is established in the scene by the sprite's `centered` and `offset` properties and positioned by eye in the editor against the artwork, not written into the script as a number. Moving Winnie later, or being handed a bubble whose tail sits somewhere else, is then a scene edit with no code change behind it.

A short delay holds the bubble back after the screen appears, so it does not arrive on top of the carousel building itself and the rest of the screen resolving. The delay, like every other timing here, is exported.

Everything the animation touches is a multiple of the scale the bubble is authored at, captured when the node is ready. The bubble will be resized in the editor once it is seen on a handset, and an animation that named absolute sizes would silently undo that the next time the screen was run.

### 6. Set the words in live text the brand typeface can replace later

Both the header and the fact are rendered as live text rather than as artwork. This is the first live text in the application beyond a button label, and it is unavoidable: a pool of facts extended by typing into a list cannot be a set of images.

**The typeface is the engine's default for now, and it is set in exactly one place.** The repository contains no font file. Both pieces of text therefore render on the default face, which will not match the branded artwork it sits inside, and that is a known and accepted temporary state rather than an oversight. What the requirement demands is that replacing it later costs one change: the font is configured in a single overridable place that both pieces of text take it from, not set separately on each label and not scattered through a scene file. When the brand typeface is licensed and added, swapping it in is that one property.

**The fact shrinks to fit rather than overflowing.** The bubble is a fixed size, so text is fitted to the space the artwork gives it: a fact that would not fit at the authored size is rendered smaller, down to a floor below which it is not shrunk further, because text too small to read in a darkened hall has failed at the only job it has. Both the authored size and the floor are exported. This makes fact length a real constraint on the copy, which is a constraint worth having — a fun fact that has to fit in a speech bubble is a better fun fact.

The header's size is fixed and does not participate in the shrinking. It is the same three words on every appearance, so it is sized once against the artwork and left alone.

### 7. Leave the swipe between bells untouched

The bubble is inert. It is not a button, it does not respond to a tap, it cannot be dismissed, and it does not advance to the next fact when touched. A touch that starts on the bubble passes through it to the carousel underneath and moves the bells exactly as a touch anywhere else would.

This is a deliberate trade against an obvious feature, and the reason is where the bubble sits. `instrument_carousel.gd` defines its drag band as the full width of the screen between a top inset of 300 design pixels and a bottom inset of 230, measured from the safe area, which is to say almost the entire screen between the logo and the Continue button. The bubble lands inside it. A tappable bubble would therefore carve a dead zone out of the middle of the swipe region on the screen whose entire purpose is swiping, and the audience member who happens to start their swipe on the bubble would find the bells did not move — a defect they would read as the application being broken rather than as a feature they had failed to notice.

Concretely, this means every node in the bubble scene ignores mouse and touch input rather than consuming it. It is stated as a requirement rather than left to the build because the engine's defaults do not give it: a `Control` node accepts input unless told otherwise, and getting this wrong produces exactly the dead zone described above, which is invisible on a desktop and only shows up under a thumb.

### 8. Add the bubble to the bell selection screen and nothing else

The whole change surface is one new scene and one new script in `app/`, the supplied bubble image in `images/v2/`, and one instance of the bubble scene added to `app/instrument_select.tscn`.

Nothing else in the repository changes. `app/instrument_select.gd` is untouched, because a bubble that draws its own fact needs nothing from the screen that hosts it. `app/instrument_carousel.gd` is untouched, and so is its drag band — requirement 7 is satisfied by the bubble refusing input, not by the carousel making room. `app/instrument_definition.gd` and the three bell resources are untouched, per requirement 2. The autoload list, the snow, the shake instrument, and every other screen are untouched.

The bell selection screen is the only screen that carries the bubble. Winnie also appears on the title screen, and this feature does not give her a bubble there. The title screen already carries the title animation, the tree, the snowflake, the halo, and the snow, and it is the screen an audience member passes through in seconds; the bubble belongs on the screen where they stop.

## Token and design considerations

This feature builds no skill. There is no input limit to declare, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching topic

No teaching topic is needed. This feature composes patterns the repository already demonstrates: the self-contained artwork scene placed by `app/sprite_position.gd`, the exported-tunable convention, and the tween-driven entrance and pulse of the Title Words That Arrive on the Beat feature (C1_14). It adds no capability the tutor covers.

## Future work

**The brand typeface.** Requirement 6 renders both pieces of text on the engine's default face because no font file exists in the repository. When the brand typeface is licensed and added, it replaces the default in the single place requirement 6 establishes, and the bubble's text matches the artwork around it. Whether the header is then kept as live text or replaced with a supplied image is a decision worth taking at that point rather than now, since a header that already sits in the right typeface has little left to gain from becoming artwork.
