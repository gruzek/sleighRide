---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Fit the Audience Flow to Any Phone Screen
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Turns a layout drawn for one imaginary screen into one that looks composed on every phone in the concert hall, and gives the artwork a home it can be animated from.
LAST UPDATED: August, 18, 2026 11:26
---

# Fit the Audience Flow to Any Phone Screen

## Summary

The Fit the Audience Flow to Any Phone Screen feature (C1_07) makes the four screens of the version 2 audience flow adapt to whatever device they run on, rather than being drawn at one fixed size and then cropped or letterboxed. It sets the project to expand into the available screen, introduces a single shared script that positions a piece of artwork relative to a chosen screen edge, extracts the remaining loose artwork into individual scenes so each piece can be placed and later animated on its own, and holds the three existing buttons against the bottom of their screens clear of the home indicator. The existing composition is preserved exactly: no artwork is repositioned by hand and no coordinate is re-authored.

## Background

The four screens of the version 2 flow - the welcome screen, the instructions screen, the bell selection screen, and the bell screen - were each drawn at a fixed 1080 by 1920 canvas, with every sprite carrying a hand-placed coordinate in that space. The project carried no stretch configuration at all until 2026-08-18, which meant those coordinates were interpreted as literal device pixels: on an iPhone 13 Pro, a 1170 by 2532 screen, the whole composition rendered into the top-left corner with dead space along the right edge and the bottom. Setting the stretch mode to `canvas_items` corrected the scale but left the aspect at its default, so the screens now letterbox instead - correctly framed, but with black bands above and below and still not filling the display.

Adaptation is not solely a project-settings problem. The artwork is nine loose sprites spread across the four screen files, with no shared mechanism for expressing where a piece of art belongs when the screen is a different shape than the canvas it was drawn on. Four scenes have already been extracted by hand - the title block, Winnie, the instrument selector, and the first instrument - and they disagree about where their own origin sits, which is precisely the inconsistency that prevents any shared placement rule from working across them.

This need is already recorded elsewhere. Requirement 9 of the Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05) reads "Fit any phone screen in portrait, clear of the notch and home indicator." That requirement states the outcome; this feature builds the mechanism that delivers it, and adds the structural work - individual scenes per artwork, a shared placement script - that the mockup specification does not cover.

Two capabilities are deliberately deferred from this feature and are detailed under Future work: splitting the Holiday Sleigh Bells title artwork into three separately positioned words, and animating the title block.

## Value Delivered

- **The app looks composed on the sponsor's own phone.** The welcome screen fills a real device edge to edge instead of sitting in a corner or floating between black bands, which is the difference between a demonstration that reads as finished and one that reads as a work in progress.
- **One layout system in place of nine hand-placed sprites.** Every piece of artwork declares where it belongs once, and the same rule governs every screen, so a new device shape is absorbed rather than being a round of manual repositioning.
- **Artwork ready to be animated and rearranged.** Each piece of art becomes its own scene with a predictable origin, which is the precondition for animating the title block and for splitting the title artwork into three moving words later.
- **A layout that survives the tablet and the browser.** The same mechanism that handles a taller phone handles a wider iPad and a resized browser window, which matters because the delivery target is still an open question between a native build and a single-page application.

## Terms

- **Design canvas.** The 1080 by 1920 reference space every screen is drawn in, taken from the project's viewport width and height settings.
- **Viewport.** The drawing area the game actually renders into on a given device, which is the design canvas on one axis and larger on the other once the expand aspect is set.
- **Anchor.** The screen edge, corner, or center a piece of artwork is measured from, so that the artwork keeps its relationship to that reference when the viewport grows.
- **Expand aspect.** The stretch setting under which one axis of the viewport always equals the design canvas and the other grows to fill the device, with no black bands and no distortion.
- **Safe area.** The region of a device screen not covered by the status bar, the camera notch or Dynamic Island, or the home indicator.
- **Tool script.** A script marked to run inside the Godot editor as well as at runtime, so its effect is visible while a scene is being edited rather than only when the game is played.

## Requirements Summary

- **1. Fill the whole screen on any phone or tablet.** The project stretch configuration is set so the flow expands into the device screen instead of letterboxing.
- **2. Keep the artwork exactly where it was drawn.** Placement is computed from each piece's existing authored coordinate and its anchor, so no coordinate is re-authored.
- **3. Position every piece of art with one shared script.** A single reusable script drives placement, attachable both to an extracted scene's root and to a loose sprite.
- **4. Show the real layout while the screen is being designed.** The placement script runs in the editor, so composition is visible during authoring rather than only when running.
- **5. Keep the logo, text, and buttons clear of the notch and home indicator.** Each piece of artwork declares whether it respects the safe area or bleeds past it.
- **6. Give each piece of artwork its own reusable scene.** The nine remaining loose sprites become individual scenes with a consistent origin, and the four already extracted are brought to the same convention.
- **7. Hold the buttons against the bottom of every screen.** The three existing buttons anchor to the bottom edge, with their present styling untouched.
- **8. Convert only the four screens that exist today.** Scope is the existing version 2 flow, with no new screens, no flow changes, and nothing in the version 1 build.

## Requirements

### 1. Fill the whole screen on any phone or tablet

The project's stretch aspect is set to expand, alongside the `canvas_items` stretch mode already in place. Under this configuration the viewport matches the design canvas exactly on one axis and grows on the other to fill the device, so nothing is distorted, nothing is cropped, and no black bands appear. On an iPhone 13 Pro the viewport becomes 1080 by 2337, keeping the authored width and gaining vertical space. On an 11-inch iPad Air it becomes 1334 by 1920, keeping the authored height and gaining horizontal space. The height never falls below the 1920 of the design canvas, which is the property that keeps bottom-anchored content on screen; the alternative keep-width setting would reduce an iPad viewport to 1554 tall and push the buttons off the bottom entirely.

### 2. Keep the artwork exactly where it was drawn

Placement is computed from the coordinate a piece of artwork already carries, not from a new coordinate authored for the purpose. For each piece, the position is derived as its anchor point in the current viewport, plus the offset between its authored position and that same anchor point in the design canvas. Where the viewport equals the design canvas the result is identical to the authored position, and where the viewport has grown the piece keeps its measured distance from the edge it is anchored to. The existing composition is therefore preserved without any artwork being repositioned by hand, and the slack the expand aspect introduces is distributed according to each piece's declared anchor rather than being absorbed silently at one edge.

### 3. Position every piece of art with one shared script

A single reusable placement script serves every piece of artwork in the flow. It attaches to any node it is placed on and positions that node, which means it works on the root of an extracted scene and equally on a loose sprite that has not been extracted yet - so a sprite can be given correct placement behavior before it is converted into a scene, and converted later without its placement changing. Its settings are exported properties, so an instanced scene can be anchored differently in each screen that uses it while sharing one scene file; Winnie appears on three screens at three different positions and must remain a single scene. The script reads the design canvas dimensions from the project's viewport settings rather than carrying its own copy of them.

### 4. Show the real layout while the screen is being designed

The placement script runs inside the Godot editor as well as at runtime, so the composition visible while a screen is being edited is the composition the device will render. This matters because the layout is art-directed by eye rather than derived from a specification, and a placement rule whose effect is only visible after export cannot be judged during authoring.

### 5. Keep the logo, text, and buttons clear of the notch and home indicator

Each piece of artwork declares, as one setting, whether its anchor is measured against the physical viewport edge or against the safe area. This is a per-piece choice because the screens genuinely need both behaviors: Winnie, the trees, and the snowflake are meant to run past the edge of the screen and would leave a dead band if held inside the safe area, while the logo, the instruction lines, and the buttons must stay clear of the Dynamic Island at the top and the home indicator at the bottom. This requirement is the mechanism behind requirement 9 of the Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05).

### 6. Give each piece of artwork its own reusable scene

The nine sprites still sitting loose in screen files become individual scenes: the straight red tree, the blue snowflake, the Holiday Sleigh Bells title artwork, and the play-along line on the welcome screen; the four instruction lines on the instructions screen; and the swipe-to-select line on the bell selection screen. Every extracted scene places its root at the visual center of its artwork, with the sprite offset to sit centered on that root, so that placement can be expressed as a position for the artwork's center. The four scenes already extracted by hand are brought to the same convention; the title block scene in particular currently holds its children at absolute design coordinates with its root left at the origin, and its children move to root-relative coordinates so that anchoring the block has meaning. The title block remains a scene of sprites rather than becoming interface controls, so that it can be animated later. The four instruction lines are grouped into a single scene rather than becoming four independent ones, because they are one design element delivered as four images and anchoring them separately would allow the stack to drift apart. The Holiday Sleigh Bells title artwork becomes one scene from its single existing image, centered and correctly placed on the device.

### 7. Hold the buttons against the bottom of every screen

The three buttons - the start button on the welcome screen and the continue buttons on the instructions and bell selection screens - anchor to the bottom edge of the screen, so they hold a fixed margin above the bottom regardless of viewport height and stay clear of the home indicator. They remain interface controls and their current styling is left exactly as it is: no shared button scene is created, and the duplicated style resources across the three screens are not consolidated.

### 8. Convert only the four screens that exist today

Scope is the four screens of the existing version 2 flow and the scenes they instance. No screen is added, no screen is removed, and the order in which the screens follow one another is unchanged. Nothing in the version 1 build is touched, including its main scene, its bells, its foreground and background scenes, and its motion-driven physics.

## Future work

The Holiday Sleigh Bells title artwork is a single image today and is intended to become three separately positioned words. A future feature will split it, which requires three artwork exports that do not exist yet - only the combined image and its source file are in the repository. Extracting the artwork as its own scene under requirement 6 is what makes that split a scene replacement rather than a rework of the welcome screen.

The title block is kept as a scene of sprites rather than being converted to interface controls specifically so that it can be animated. A future feature will animate it; this feature delivers the structure that animation attaches to.
