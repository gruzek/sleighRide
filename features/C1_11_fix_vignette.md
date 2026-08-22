---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Draw the Vignette in Code So Its Glow Is Clean and Fits Every Screen
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Turns a washed-out exported image into a shape the application draws for itself, so the glow behind the logo is the right color on every phone and becomes the surface the next visual effect is built on.
LAST UPDATED: August, 22, 2026 11:31
---

# Draw the Vignette in Code So Its Glow Is Clean and Fits Every Screen

## Summary

The Draw the Vignette in Code So Its Glow Is Clean and Fits Every Screen feature (C1_11) replaces the vignette's exported image with an oval the application draws for itself in a shader. The oval fades from the primary color, `#131A2B`, to fully transparent with no white anywhere in the fade, takes the shape and placement of the oval in the design file, and holds that composition on any screen by sizing and positioning itself against the viewport rather than sitting at a fixed size. The look is exposed as adjustable settings so it can be tuned without editing the shader, and so the visual effect planned for the vignette has somewhere to attach. The retired image is archived rather than deleted, and nothing else on any screen changes.

## Background

The vignette is the soft glow that sits behind the logo at the top of all four screens of the audience flow — the title screen, the instructions screen, the bell selection screen, and the play screen. Every one of them instances the same scene, so whatever the vignette does, it does four times.

It currently does the wrong thing, and the reason is in the file rather than in the code. Sampling `images/v2/vignette_glow.png` across a grid shows its alpha channel falling from 255 to 0 down the image while the color it carries brightens from a dark navy to pure white in lockstep. The image was flattened onto a white background before its alpha channel was written, so every partly transparent pixel literally holds white in its color channels, and the engine blends that white onto the screen wherever the image is fading out. This is not a setting that was chosen incorrectly. No import option in the engine recovers a color that was overwritten before the file was saved, and the option that sounds as though it might — treating the image as having premultiplied alpha — makes the wash worse rather than better. The white can only be removed by not using the file.

The image is also not the shape the design calls for. Despite its name, it is the full rectangle: fully opaque across roughly the top half, feathering to nothing by the bottom. That is a scrim across the top of the screen, not an oval. The design file specifies an ellipse, wider than the screen it sits on, centered horizontally and hanging off the top edge, and no adjustment to the exported image produces that shape.

Two smaller problems come with it. The image is a fixed 970 by 827 pixels scaled by a constant, so its size has no relationship to the screen it is drawn on; and the vignette is a piece of artwork the project intends to animate, which an exported image gives no way to do.

One capability is deliberately deferred from this feature and is detailed under Future work: the visual effect the shader is being introduced to host.

## Value Delivered

- **The glow is the color it was designed to be.** The white haze that currently sits over the top of every screen in the audience flow disappears, on all four screens at once, because all four instance the same scene.
- **The composition survives an unanticipated screen.** ~~The application is now aimed at a single-page app, where the window is whatever size the person's browser happens to be.~~ *(Corrected 2026-08-22: the SPA direction was reversed; this is a native application and there is no browser window. The requirement still stands on its own merits — a vignette sized against the viewport keeps the designer's composition on any phone, and phones vary in aspect ratio.)* A vignette sized against the viewport keeps the designer's composition on a screen nobody anticipated; a fixed-size image does not.
- **The next visual effect has a place to live.** The project intends to animate the vignette. A shader with named settings is the surface that work attaches to, and this feature delivers it as a byproduct of fixing the color.
- **A 470-kilobyte image leaves the build.** The oval is drawn from a handful of numbers, so the retired file stops being downloaded by every audience member who opens the app.

## Terms

- **Design canvas.** The 1080 by 1920 coordinate space the application is authored in. The engine stretches this to the real screen, expanding the longer axis rather than distorting the artwork, so on any screen at least as tall as it is wide by the same proportion the canvas stays 1080 units across and grows taller.
- **Viewport width.** The width of the drawable area in design-canvas units at the moment of drawing. On a portrait phone this is 1080; in a wide browser window it is larger.
- **Normalized elliptical radius.** A single number describing how far a point is from the center of the oval, measured as a fraction of the distance to the oval's own edge along that same direction. It is 0 at the center and 1 everywhere on the boundary, whatever the oval's proportions, which is what lets one falloff rule apply evenly around a shape that is wider than it is tall.
- **Primary color.** `#131A2B`, the color the vignette fades from.

## Requirements Summary

- **1. Draw the vignette as an oval in code instead of loading a picture.** The vignette scene stops using an exported image and draws an ellipse in a fragment shader of its own.
- **2. Fade from the primary color to transparent with no white in between.** The color is held constant across the whole oval and only its transparency varies, which removes the wash by construction rather than by correction.
- **3. Hold the design's composition on any screen size.** The oval's size and position are expressed as fractions of the viewport width, so its proportions, its overhang past the screen edges, and its distance from the top are the same everywhere.
- **4. Expose the look as settings that can be adjusted without editing the shader.** The color, the solid core, the softness of the edge, and the peak opacity are named parameters, which is also where the planned effect attaches.
- **5. Archive the retired image rather than delete it.** The exported image and its import companion move into the repository's archive directory, where the engine will not import them and no build can include them.
- **6. Change nothing on the four screens beyond the vignette itself.** Backgrounds, logos, buttons, and every other element are untouched, including the title screen's background color.

## Requirements

### 1. Draw the vignette as an oval in code instead of loading a picture

The vignette scene draws an ellipse in a fragment shader instead of drawing an exported image. The shader is a file of its own, in the style the repository already uses for `background/transparent_cloud.gdshader`, so it can be read, edited, and reused without opening a scene.

The scene's structure changes to suit. The oval must re-derive its size and position whenever the drawable area changes, which the shader can do for itself if it is given the whole viewport to draw into. The vignette therefore becomes a rectangle anchored to the full viewport, carrying the shader, with the shader deciding which of those pixels belong to the oval and how opaque each one is. This has a consequence worth stating plainly rather than discovering during the build: the scene's root node changes kind, it no longer uses the shared placement script `v2/sprite_position.gd`, and the `design_position` override that currently appears on the vignette in all four screens becomes meaningless and is removed from each of them. Placement now belongs to the shader, in one place, rather than being repeated four times.

Drawing a rectangle the size of the screen and discarding most of it is the deliberate choice. The alternative — sizing a smaller rectangle to the oval's bounding box and moving it on every resize — needs a script to keep two things in agreement and gains nothing, because the fragment work outside the oval is a single comparison that resolves to fully transparent.

Paths in this requirement name the repository as it stands today. The Give Each Chosen Bell Its Own Voice and Close the Audience Flow feature (C1_10) restructures these directories; if that restructure lands first, the vignette scene, the shader, and the four screens move with it and this feature follows the new layout rather than recreating the old one.

### 2. Fade from the primary color to transparent with no white in between

The shader emits the primary color, `#131A2B`, in its color channels at every pixel of the oval, and varies only the transparency. Nothing in the fade is any other color, so the white haze cannot reappear: there is no second color present for the fade to travel through.

The transparency follows the normalized elliptical radius. From the center out to 0.45 of that radius the oval is at full opacity, and from 0.45 out to 1.0 it eases smoothly to fully transparent, reaching zero exactly on the boundary. The solid core is what carries the density the current artwork has; a fade that begins at the very center reads as far thinner than the design over a shape this large. The easing is smooth rather than linear so the edge has no visible band where the falloff begins.

The oval is drawn on top of whatever the screen already shows and blends with it in the ordinary way. On the three screens whose background is the near-black `#05070C`, the result is a lifted navy halo behind the logo; on the title screen, whose background is unchanged by this feature, it is whatever `#131A2B` over that background produces.

### 3. Hold the design's composition on any screen size

The oval's geometry is expressed as fractions of the viewport width, and is recomputed whenever that width changes, so the composition in the design file is reproduced at any size rather than only at the size it was drawn.

The design file places the oval in a frame 485 units wide: 630.18 wide by 484.76 tall, with its left edge at −72.71 and its top edge at −199.61. Dividing through by the frame width gives the constants the shader holds:

| Quantity | Fraction of viewport width | At a viewport width of 1080 |
|---|---|---|
| Center, horizontal | 0.5 | 540 |
| Center, vertical | 0.0881856 | 95.2 |
| Radius, horizontal | 0.6496701 | 701.6 |
| Radius, vertical | 0.4997526 | 539.7 |
| Overhang past each side edge | 0.1496701 | 161.6 |

The horizontal center is 0.5 exactly. The design file gives 0.4997526, which is the drawing tool's rounding rather than an intended offset; the oval is centered. The resulting proportion is 1.2999835 to 1, and it is held on every screen because both radii scale from the same number.

Width is the axis everything scales from, including the vertical placement. Scaling both axes from one number is what keeps the oval's proportion fixed, and width is the axis the design's own relationships are stated against: the oval overhangs the side edges by a fraction of the width, and its height happens to equal the frame's width almost exactly. The consequence is accepted deliberately: in a window much wider than it is tall the oval grows very large, because its width follows the window's width and the window is wide. That case is a desktop browser rather than the portrait phone this application is for, and the alternative rules trade an exact reproduction of the design for a vaguer one in order to improve a case that mostly does not arise.

It is worth recording what this rule does and does not change in practice. Because the engine expands the design canvas rather than stretching it, the canvas stays 1080 units wide on every portrait phone regardless of how tall the phone is. On those screens this requirement produces exactly the same result as a fixed size would. It earns its place on viewports wider than the design's own proportion. *(Corrected 2026-08-22: the original text cited "a browser window on a laptop" here, on the since-reversed SPA direction. On the native build the wide case is an iPad or the editor, not a browser.)*

### 4. Expose the look as settings that can be adjusted without editing the shader

The shader's behavior is controlled by named parameters rather than by numbers written into its body, so the look is adjusted in the editor's inspector and seen immediately. The parameters are the color, the peak opacity, the fraction of the radius that stays fully opaque, and the softness of the edge, alongside the geometry constants from requirement 3. Each carries the default given in this specification, so a scene that overrides nothing draws what is specified here.

This is the reason the vignette is a shader rather than a drawn gradient. The project intends to add a visual effect to the vignette, and a shader with a named parameter block is the surface that effect attaches to. This feature adds no effect and no motion; it establishes the parameters the effect will extend.

### 5. Archive the retired image rather than delete it

`images/v2/vignette_glow.png` and its import companion `images/v2/vignette_glow.png.import` move to `legacy/images/v2/`, which mirrors the path they came from. Nothing is deleted.

The archive directory already carries the marker that tells the engine to skip it, so a file placed there is not imported, cannot be referenced by any scene, and cannot reach an export bundle. The image is preserved in the repository's history and on disk as the record of what the vignette used to be, without costing anything in a build.

### 6. Change nothing on the four screens beyond the vignette itself

The title screen, the instructions screen, the bell selection screen, and the play screen change in exactly one respect: the vignette they instance no longer carries a placement override, because placement moved into the shader. Nothing else on those screens is touched.

This is stated as a requirement because one tempting change is explicitly out of scope. The title screen's background is a teal that the other three screens no longer use, and it will read differently under the new vignette than the near-black the others carry. That difference is not this feature's to resolve. The background stays as it is.

## Token and design considerations

This feature builds no skill, so there is no input limit to declare, no deterministic work to absorb into a script, and no skill body to split into reference files.

## Teaching topic

No teaching topic is needed. This feature replaces one drawing method with another using a shader pattern the repository already demonstrates, and adds no capability the tutor covers.

## Future work

**A visual effect on the vignette.** The vignette is being moved into a shader because the project intends the glow to do something — to breathe, to pulse, or to respond to the instrument — rather than to sit still. This feature deliberately adds none of that: it delivers a still oval of the right shape and the right color, with a parameter block a later feature extends with whatever the effect needs. Doing the effect and the color fix together would make it impossible to tell which of the two was responsible for a change in how the screen looks.
