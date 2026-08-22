# Can Holiday Sleigh Bells Get at the Camera?

**Status:** research notes for the Jingle Jam Cam screens. Working document, not a sponsor deliverable.
**Audience:** George + Claude.
**Last verified:** 2026-08-22 against Godot 4.6 (`4.6.stable.official.89cea1439`) and iOS 26.

> Desk research only. Nothing below has been run on a handset. Every claim that needs a device
> test is labelled **NEEDS DEVICE TEST**.

---

## 0. The short answer

**Yes. The engine does this itself, and on the native build it is close to easy.**

`CameraServer` / `CameraFeed` / `CameraTexture` are
[implemented on Linux, Android, macOS and iOS](https://docs.godotengine.org/en/stable/classes/class_cameraserver.html).
The docs give the platform list verbatim: *"This class is currently only implemented on Linux,
Android, macOS, and iOS."* We ship native iOS. We are on the supported list.

The mockup's composition — graphics in front of a live face, a button that snaps — maps onto
things this repository already does. A camera feed becomes an ordinary texture, the artwork sits
in front of it in the same viewport, and the snap is a viewport capture. There is one genuine
gap, and it is at the end: getting the finished picture out of the app and into the audience
member's photos.

---

## 1. Turning the camera on

**iOS.** The camera module is in the engine now — the old external `godot-ios-plugins` camera
plugin is no longer the route, and any advice that says otherwise is pre-4.2. It is an
export-preset checkbox,
[`EditorExportPlatformIOS.modules/camera`](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformios.html),
and turning it on requires `privacy/camera_usage_description` to be filled in — that string is
what iOS shows in the permission prompt, so it is worth writing properly ("so you can take a
photo with your bells").

Our `export_presets.cfg` currently has the `privacy/camera_usage_description` key present and
**empty**, and no `modules/camera` line at all. That is the expected untouched state, not a
fault. Two edits turn the camera on.

**Android.** Camera feed support landed in **Godot 4.5** via
[PR #106094](https://github.com/godotengine/godot/pull/106094), merged 2025-05-13: Camera2
backend, front and back cameras, `FEED_RGB` and `FEED_YCBCR_SEP`, API level 24+, and the camera
permission is requested on demand rather than at startup. We are on 4.6, so it is in the build
we have. Worth knowing, though `docs/system_design.md` records that no Android hardware has been
measured for anything yet.

---

## 2. Front or back, and getting it the right way up

A [`CameraFeed`](https://docs.godotengine.org/en/stable/classes/class_camerafeed.html) is
activated with `set_active(true)` and reports its position from `get_position()` as `FEED_FRONT`,
`FEED_BACK`, or `FEED_UNSPECIFIED`. Both cameras are therefore available, and the mockup's
"could be front or back" is a matter of picking a feed out of `CameraServer.feeds` and offering
a flip button, not a matter of platform support.

The feed carries a `transform` property, which is the correction point for orientation and for
mirroring the front camera — a selfie preview that is not mirrored reads as wrong to everyone
who has ever used a phone, and a saved image that *is* mirrored reads as wrong to everyone who
has ever read a t-shirt. Those two wants conflict, and the usual resolution is to mirror the
preview and save unmirrored.

**Most phone cameras deliver YCbCr, not RGB.** `get_datatype()` returns `FEED_RGB`,
`FEED_YCBCR`, `FEED_YCBCR_SEP`, or `FEED_EXTERNAL`, and Android's own PR notes that
`FEED_YCBCR_SEP` "is used in most cases". The engine converts automatically only when the feed
is used as a camera background; anywhere else the display path needs the standard conversion
shader. This repository already carries a shader (`shaders/snow_sparkle.gdshader`), so it is a
known kind of work rather than a new one.

---

## 3. Compositing and snapping

This is the part that is nearly free, because it is the pattern the application already uses
everywhere.

A `CameraTexture` bound to the feed id is an ordinary texture. Put it on a `TextureRect` at the
back of the play screen and the artwork, the vignette, the snow, and the title all draw in front
of it by `z_index`, exactly as they already draw in front of the background. The Jingle Jam Cam
screen becomes another screen in `app/`, composed the same way as the other four, with
`app/sprite_position.gd` placing its elements against the same 1080-by-1920 design canvas.

The snap is then one line, because the overlay is already composited — it is all one viewport:

```gdscript
var image := get_viewport().get_texture().get_image()
```

`save_png` to `user://` writes it. Note that on iOS `user://` is the app's Documents directory,
and the export preset already sets `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`
for the capture harness — so a saved photo is already retrievable through the Files app, which
is a usable fallback if nothing else lands in time.

One thing to get right: the capture has to happen at the end of a frame, and the record button
itself must not be in the shot. Hiding the UI for one frame and capturing on the next is the
standard shape.

---

## 4. The one real gap: getting the photo to the audience member

Godot has no photo-library API.
[Issue #34007](https://github.com/godotengine/godot/issues/34007) is the standing gap on iOS.

The route is the **share sheet**, via the
[iOS Share Plugin](https://godotengine.org/asset-library/asset/2907) (asset library, submitted
February 2026) or [Shin-NiL/Godot-Share](https://github.com/Shin-NiL/Godot-Share), which covers
Android and iOS behind one GDScript interface. From the share sheet the audience member taps
"Save Image" — and the same sheet is how they text it to whoever they came with, which is
arguably the better product anyway. A photo that saves silently to the camera roll is a photo
nobody sees again; a share sheet is the moment it gets sent.

`privacy/photolibrary_usage_description` needs filling in as well if the save path is used.

This is the only piece requiring a third-party dependency, and it is worth evaluating both
options against the "no fallbacks" convention in `docs/system_design.md` before committing.

---

## 5. What has to be checked on a phone

**NEEDS DEVICE TEST, and this one is not optional.**
[Godot issue #79551](https://github.com/godotengine/godot/issues/79551) — "CameraServer.feeds in
iOS returns nothing" — is **still open**. It was filed in 2023, predates the built-in camera
module, and the reporter was using the abandoned external plugin, so it may well be stale. But
it is the exact failure that would sink this, and it costs fifteen minutes to settle:

1. Tick `modules/camera` in the iOS export preset.
2. Write a real string into `privacy/camera_usage_description`.
3. A throwaway scene that prints `CameraServer.feeds.size()` and each feed's `get_position()`.
4. Run it on the iPhone. A non-zero count ends the question.

Everything else in this document follows from that number. Do this before writing a feature spec.

The second and third things to check, once feeds exist, are both about how the image arrives:
whether the feed comes up rotated or mirrored in our portrait-locked orientation, and whether
`get_datatype()` returns a YCbCr variant that needs the conversion shader. Both are fixable;
both are easier to answer with a live feed on screen than by reading.

---

## 6. Note on the web

An earlier draft of this document was written on the assumption that this project was a
single-page web app, and reached the opposite conclusion — Godot has **no web camera
implementation at all**, and the
[CameraServerExtension GDExtension](https://github.com/j20001970/godot-cameraserver-extension)
that exists to widen platform coverage lists Web as unsupported. On the web the camera can never
be an object inside the game; it has to be a `<video>` element behind a transparent canvas, with
the snapshot composited by hand in JavaScript. On top of that, every known iPhone camera defect
is specific to installed-web-app standalone mode: permission not persisted across launches
([WebKit 215884](https://bugs.webkit.org/show_bug.cgi?id=215884)), and a feed that arrives
rotated 90° in home-screen apps but not in Safari
([Apple Developer Forums 801146](https://developer.apple.com/forums/thread/801146), September
2025, no response).

**None of that applies to us.** It is recorded here only so the question does not get re-asked,
and as one more piece of evidence for why the native direction is the right one: the camera
screens are straightforward natively and close to unshippable on an installed iPhone web app.
