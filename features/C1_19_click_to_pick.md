---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Tap the Bell You Want, Then Tap It Again to Play
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.2
AUTHOR: George Ruzek
VALUE STATEMENT: Removes the button nobody presses and makes the bells themselves the controls, so the way the audience already behaves becomes the way the screen actually works.
LAST UPDATED: September, 1, 2026 14:49
---

# Tap the Bell You Want, Then Tap It Again to Play

## Summary

The Tap to Choose Your Bell feature (C1_19) makes the bells on the bell selection screen into the controls of that screen. A tap on one of the two side bells settles it to the centre and chooses it. A tap on the centred bell advances to the play screen, which is the job the Continue button has been doing. The Continue button is retired, and the Jingle Cam button grows leftward into the space it vacates so that its lettering fits on one line, with a camera icon to the left of the words. On the play screen, a "Shake to Jingle" prompt is added below the title and above the bell, so an audience member arriving there is told what to do with the phone in their hand.

## Background

The bell selection screen has always asked the audience member to do two things: swipe between three bells, and then press a blue Continue button in the bottom right corner to carry the chosen bell to the play screen. In practice people do the first and skip the second. Having pushed the bell they want into the middle of the screen, they tap the bell, because the bell is the thing they have been touching and the thing the screen is about. The button in the corner goes unpressed, and the screen appears not to respond.

The mechanism that makes tapping the bell the right answer is already built. The carousel in `app/instrument_carousel.gd` publishes the centred bell into the `InstrumentSelection` autoload continuously as it moves, so the chosen bell is already correct at every instant rather than being read at the moment a button is pressed. That was a deliberate decision in the Swipe Between Bells to Choose the One You Play feature (C1_08), recorded in its own comments: the selection screen's Continue button "needs no code of its own" because the choice is never stale. The consequence, which was not visible until people used the screen, is that Continue contributes nothing except a second tap in a place nobody is looking. It is a confirmation step for a decision that has already been made and already been recorded.

What the carousel does not have is any notion of a tap. `_pointer_button` begins a drag on any press inside the drag band, and `_end_drag` settles on release. A press and release with no movement between them is therefore a drag of zero distance, which settles back to exactly where it started. The screen does receive the audience member's tap; it simply has nothing to do with it. That is the hook this feature attaches to, and it is why the change is small.

Two things inside the carousel are written against the Continue button and become untrue when it goes. The comment block above `_unhandled_input` explains that a press landing inside Continue is marked handled during interface input before the carousel ever sees it, and the `drag_band_bottom_inset` property is documented as placing the bottom of the drag band "above the continue button". Neither is a behaviour that changes, but both are statements about a control that will no longer exist.

Removing Continue leaves the Jingle Cam button alone at the bottom of the screen, with a strip of empty space to its right. That button carries its text as the literal two-line string `"Jingle\nCam"`, which was the only way to fit the words into 246 design pixels beside Continue. With Continue gone there is room for the words on one line, and room for an icon that says what the button opens before the words are read.

The play screen has the opposite problem to the selection screen. It has no instruction on it at all. The instructions screen earlier in the flow tells the audience member to shake gently, but that screen is several taps behind them by the time the bell is in front of them, and an audience member who reaches the play screen during a performance has no reminder of what to do.

One thing is deliberately not changed here. The "Swipe to Select Your Bells!" lettering on the selection screen keeps its current wording even though tapping is now a second way to use the screen. Adding tapping to that instruction would mean drawing new lettering in the hand-drawn style every instruction in this application uses, and the tap is discoverable enough on its own that the screen is better left uncluttered while the wording is considered separately.

## Value Delivered

- **The screen answers the tap people already make.** The single most common gesture on this screen currently does nothing, and after this feature it is the gesture that advances the flow.
- **One less thing between the audience and the bell.** Choosing and playing collapse from a swipe plus a hunt for a corner button into a swipe and a tap on the thing being chosen.
- **Nothing is left on screen that does not work.** A visible button that nobody presses reads as a broken screen to the person testing it and as clutter to the person using it, and it is now gone.
- **The Jingle Cam button reads at a glance.** A camera icon and one line of lettering is recognised without being read, which matters on a screen an audience member sees for a few seconds in a darkening hall.
- **The play screen tells you what to do.** An audience member reaching the bell mid performance is told to shake, rather than being expected to remember an instruction from three screens earlier.
- **No new mechanism is introduced to keep in step.** The chosen bell is still published by the carousel as it moves and still carried by the same autoload, so nothing about how a choice reaches the play screen changes.

## Terms

- **Drag band.** The horizontal region of the selection screen in which a press begins a carousel drag, measured from the safe area so it sits below the logo and above the buttons.
- **Settle.** The short animation that carries the carousel from wherever a gesture left it to a whole position, so exactly one bell ends up centred.
- **Design pixels.** Positions and sizes expressed against the 1080 by 1920 reference canvas every screen in this application is drawn in, rather than against the physical screen.
- **Chosen bell.** The bell currently centred in the carousel, which the carousel publishes into the `InstrumentSelection` autoload continuously and which the play screen draws.
- **Tap.** A press and release whose finger travel stays below a threshold, as distinct from a drag or a flick.

## Requirements Summary

- **1. Tap a side bell to choose it.** A tap on either neighbouring bell settles it to the centre without leaving the screen.
- **2. Tap the chosen bell to play it.** A tap on the centred bell advances to the play screen, which is what the Continue button did.
- **3. Tell a tap apart from a swipe.** Finger travel decides whether a gesture is a tap or a drag, so a flick is never mistaken for a tap.
- **4. Ignore taps that miss the bells.** A tap in the drag band that lands on none of the bells does nothing at all.
- **5. Retire the Continue button.** The button, its styling, and its handler are removed from the selection screen, and the comments describing the screen around it are corrected.
- **6. Widen the Jingle Cam button to fit one line.** The button keeps its corner and grows left into the space Continue vacates.
- **7. Put a camera icon on the Jingle Cam button.** The supplied camera artwork sits to the left of the lettering at a size that matches it.
- **8. Tell the audience to shake, on the screen where they shake.** A "Shake to Jingle" prompt is added to the play screen below the title and above the bell.

## Requirements

### 1. Tap a side bell to choose it

A tap landing on either of the two visible side bells settles the carousel so that the tapped bell becomes the centred one. The audience member stays on the selection screen. This is the same outcome a swipe in that direction produces, reached by touching the bell directly rather than by pushing the carousel.

Whether a tap has landed on a bell is decided by an exported hit radius in design pixels, measured horizontally from the slot's centre. The radius is one value covering all three slots, and it is validated in `_ready()` with a message naming the value, its permitted range, and the correct default, in keeping with the repository's convention for exported values used as bounds.

Settling uses the carousel's existing settle animation and its existing duration, so a bell brought to the centre by a tap moves exactly as a bell brought to the centre by a released drag. A tap arriving while a settle is already running catches it in place and settles from there, which is how the carousel already treats a press during a settle.

### 2. Tap the chosen bell to play it

A tap landing on the centred bell advances to the play screen, `res://app/instrument.tscn`. This is the behaviour the Continue button carried, reached by tapping the bell the audience member has just chosen.

The carousel does not perform the navigation. It has never known that screens exist, and putting a scene change inside it would be the first time it did. Instead the carousel emits a signal when the centred bell is tapped, and `app/instrument_select.gd` connects that signal in `_ready()` and performs the scene change, which is the role that script already plays for the screen's buttons. Signals are connected in `_ready()` rather than in the scene file, as the repository requires.

No selection work happens on the way out. The chosen bell is already published into the `InstrumentSelection` autoload and is already correct, which is the property that made the Continue button unnecessary in the first place.

### 3. Tell a tap apart from a swipe

A gesture is a tap when the total finger travel between press and release stays below an exported threshold in design pixels. Anything above it is a drag and is handled exactly as drags are handled today, including the flick contribution that release speed makes to the committed target.

The threshold is exported so it can be tuned by eye on a handset, and it is validated in `_ready()` with a message naming the value, its permitted range, and the correct default.

The decision is made at release rather than at press, because a press cannot yet know which gesture it is. A gesture judged to be a tap does not run the settle logic that a released drag runs, so a tap on a side bell settles to that bell rather than to the nearest one, and a tap on the centred bell leaves the carousel where it is.

### 4. Ignore taps that miss the bells

The drag band spans the full width of the viewport, so a tap can land inside it and nowhere near a bell. Such a tap does nothing: the carousel does not move, no signal is emitted, and the screen does not advance.

This is stated as a requirement rather than left implied because the alternative behaviour, treating any tap in the left or right region as a request to move that way, is a reasonable design that is deliberately not chosen. Only the artwork is a control.

### 5. Retire the Continue button

The `ContinueButton` node is removed from `app/instrument_select.tscn`, along with the two `StyleBoxFlat` sub-resources that exist only to style it. In `app/instrument_select.gd`, the `continue_button` reference, its validation in `_ready()`, its signal connection, and the `_on_continue_pressed` handler are all removed. The screen's remaining validation for the Jingle Cam button is unchanged.

Two comments in `app/instrument_carousel.gd` describe the screen in terms of the Continue button and are corrected to describe the screen as it will then be. The comment block above `_unhandled_input` explains that a press inside the Continue button is marked handled before the carousel sees it, and the `drag_band_bottom_inset` property is documented as placing the bottom of the drag band above the Continue button.

The drag band's own geometry does not change. Its bottom inset of 230 design pixels was set to clear the buttons at the bottom of the screen, and the Jingle Cam button's top edge sits 155 design pixels above the safe area's bottom, which is the higher of the two edges the band was already clearing. The band therefore continues to clear the only button that remains, and no numeric adjustment is required.

### 6. Widen the Jingle Cam button to fit one line

The Jingle Cam button keeps its bottom right anchor, its vertical position, its height of 122 design pixels, its red styling, and its 44 point white lettering. Its left edge stays where it is and its right edge moves out to where the Continue button's right edge was, giving it a width of roughly 498 design pixels in place of 246.

Its text becomes the single-line string `Jingle Cam` in place of the two-line `"Jingle\nCam"` it carries today.

The button continues to carry `app/safe_area_margin.gd` and its authored base offsets, so it stays clear of the home indicator exactly as it does now.

### 7. Put a camera icon on the Jingle Cam button

The supplied camera artwork is added to the repository under `images/v2/` and drawn to the left of the lettering, with the icon and the text together centred in the button. It is not set as the button's own `icon` property: Godot places a button icon at the left margin and centres the button's text independently of it, so on a button this wide the icon would sit alone in the corner. The button carries neither `text` nor `icon` and holds its contents in a centred container instead.

The artwork is a 24 pixel Material Symbols camera glyph filled white, which is far too small to sit beside 44 point lettering at its authored size. It is scaled on import rather than by scaling the button's contents, so the icon is rasterised at the size it is drawn at and stays crisp. The target is an icon that reads as the same visual weight as the lettering beside it, tuned by eye on a handset.

No existing artwork is removed by this requirement. The repository's rule that a media file is never deleted is not engaged, because nothing is being replaced.

### 8. Tell the audience to shake, on the screen where they shake

A "Shake to Jingle" prompt is added to `app/instrument.tscn`, positioned below the title and above the bell.

It is a `Label` rather than drawn lettering. Every instruction in this application is currently a designed scalable vector graphic of hand-drawn letterforms, and there is no such artwork for these words. Rather than hold the prompt until artwork can be drawn, or misuse an existing instruction that says something else, the prompt is built as text now.

The prompt is not a bare `Label`, because `app/sprite_position.gd` extends `Node2D` and a `Label` is a `Control`, so the shared placement script cannot attach to one directly. It follows the shape `app/fun_fact_bubble.tscn` already uses: a `Node2D` root carrying the placement script, with the `Label` as a child at an authored offset. The prompt is therefore positioned by editing `design_position` like every other piece of composition on every screen, and needs no script of its own.

The label is white, 58 point, and horizontally centred. White is what the play screen's near black background requires, and 58 point is the size the instruction screen's own label was authored at. Its `mouse_filter` is set to ignore, so it can never consume a touch intended for the screen beneath it, matching how the fun fact labels are configured.

## Token and design considerations

This feature builds no skill, so there is no skill token cost to account for.

## Teaching topic

No teaching topic is needed. This feature changes what an audience member does on two screens of a Godot application; it does not change the developer's tooling, scripts, environment, or workflow, which is what the Mrs Puff Developer Teaching Assistant feature (C3_06) exists to teach.
