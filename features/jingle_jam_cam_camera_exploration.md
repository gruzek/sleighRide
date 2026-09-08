# Can Holiday Sleigh Bells Get at the Camera?

**Status:** research notes for the Jingle Jam Cam screens. Working document, not a sponsor deliverable.
**Audience:** George + Claude.
**Last verified:** 2026-08-22 against Godot 4.6 (`4.6.stable.official.89cea1439`), iOS 26, Android 16.

> Desk research only. Nothing below has been run on a handset. Every claim that needs a device
> test is labelled **NEEDS DEVICE TEST**.

---

> ## Superseding note - 2026-08-23
>
> **The project is now on Godot 4.7.2, and the camera is built into the engine on iOS.** Sections 0, 1 and 3 below were written against 4.6, where it was not, and they recommend a GDExtension that is **no longer needed**. They are kept because the Android half of section 1 and the whole of section 2 remain accurate, and because the reasoning about how to tell what the engine actually supports is worth keeping.
>
> For what the camera really does on a handset, read **section 6a**, which is measurement rather than research. Where 6a and any earlier section disagree, 6a is right.

## 0. The short answer

**Yes — but the platform that works today is the one we are not building.**

| Build | Camera in Godot 4.6? | How hard |
|---|---|---|
| **Android** | **Yes, in the engine.** Shipped in 4.5. | Moderate — three gotchas, all known |
| **iOS** | **Yes — built in as of 4.7**, which is what this project now runs. On 4.6 it was absent from the stock template and needed a GDExtension. | Moderate — see section 6a for what it actually took |
| Web / SPA | No, and not ever soon | N/A — we are not a web app |

**iOS is not blocked, it is just not free.** Verified against the export templates installed on
this machine (§1a): the stock 4.6 iOS template has no camera backend in it at all, so
`CameraServer.feeds` comes back empty. The fix is a drop-in GDExtension (§3), not an engine fork.

The Godot documentation's platform note —
[*"currently only implemented on Linux, Android, macOS, and iOS"*](https://docs.godotengine.org/en/stable/classes/class_cameraserver.html)
— is **wrong in both directions** for 4.6, and following it is how the earlier draft went astray.
Section 1 shows the receipts.

---

## 1. Where the camera actually lives in Godot 4.6

The camera is an engine module, `modules/camera/`. Its `config.py` decides which platforms it
builds on, and on the **4.6 branch** that line reads:

```python
return platform == "macos" or platform == "windows" or platform == "linuxbsd" or platform == "android"
```

The files in `modules/camera/` on 4.6 are `camera_android.cpp`, `camera_macos.mm`,
`camera_win.cpp`, and `camera_linux.cpp`. **There is no iOS file.** `platform/ios/` on the 4.6
branch contains no camera source either.

On `master` (4.7-dev) that same directory has gained `camera_apple.h` / `camera_apple.mm` — a
unified Apple backend covering macOS *and* iOS. That is the change the demo author refers to when
[shiena/godot-camerafeed-demo](https://github.com/shiena/godot-camerafeed-demo) lists its
platform requirements as:

> macOS: Godot Engine 4.0 or later · Linux: Godot Engine 4.4 or later ·
> **Android: Godot Engine 4.5 or later** · **iOS: Godot Engine 4.7 dev 4 or later**

So: the docs undersell 4.6 (Windows is supported and unlisted) and oversell it (iOS is listed and
absent). Take `config.py` as the authority, not the class reference.

### 1a. Confirmed against the templates on this machine

Source-branch reading is one thing; what actually ships is another. Both 4.6 export templates in
`~/Library/Application Support/Godot/export_templates/4.6.stable/` were unpacked and inspected.

**iOS (`ios.zip` → `libgodot.ios.release.xcframework/ios-arm64/libgodot.a`):**

- Camera-related object files present: `camera_feed.o`, `camera_server.o`, `camera_texture.o`,
  plus the unrelated `camera_2d.o` / `camera_3d.o`. These are the **platform-independent base
  classes** from `servers/`, and they are compiled in unconditionally.
- Camera **backend** object files: none. No `camera_apple.o`, no `camera_ios.o`.
- References to `AVCaptureSession` or `AVCaptureDevice`: **zero**.
- Objective-C camera classes: **none**.

**Android (`android_release.apk` → `lib/arm64-v8a/libgodot_android.so`):**

- `CameraAndroid` and `CameraFeedAndroid` symbols present.
- `ACameraManager_create`, `ACameraManager_openCamera`, `ACameraManager_getCameraIdList`,
  `ACameraManager_getCameraCharacteristics` present.
- Links `libcamera2ndk.so`.

That is the whole question settled empirically. `CameraServer` and `CameraFeed` **exist** as
classes on iOS — which is exactly why this is easy to get wrong, since the API is there and the
autocomplete works — but nothing implements them, so the feed list is permanently empty.

One more confirmation from our own file: `export_presets.cfg` lists every option for our iOS
preset, and there is **no `modules/` section in it at all**. The `EditorExportPlatformIOS.modules/camera`
checkbox the class reference describes is not present in 4.6's iOS preset. (It was real in Godot
3.x, where [PR #33992](https://github.com/godotengine/godot/pull/33992) shipped Camera and ARKit
as separate `libgodot_camera_module.iphone.*.a` static libs so apps could exclude the camera API
and avoid App Store rejection. That mechanism is gone in 4.x.)

---

## 2. Android — the section this was written for

### 2a. It is in the build we have

Android camera support landed in **Godot 4.5** via
[PR #106094](https://github.com/godotengine/godot/pull/106094) (merged 2025-05-13), written by
the same author as the demo above. We are on 4.6, so `camera_android.cpp` is compiled into the
Android template we would export with. Nothing to install, no plugin, no custom engine build.

It uses the **Camera2 NDK**, which requires **API level 24**. The same PR raised Godot's Android
minimum from 21 to 24 for exactly this reason, and Godot 4.6's `config.gradle` now defaults to
`minSdk 24` / `targetSdk 36`. **The floor and the requirement are the same number, so there is
nothing to configure** — but do not lower `gradle_build/min_sdk` below 24 or the camera goes away
silently.

### 2b. We have no Android export preset at all

> **Done as of 2026-09-06.** The Android Build and Play Store Release feature (C1_20) stood up the target: a configured `preset.2`, the Java Development Kit and Software Development Kit versions Godot 4.7.2 pins, the in-project Gradle build template, and the camera port itself. What this section predicted the work would cost was accurate, including the Gradle build. The section is kept because its reasoning is still the reason the work was shaped that way.

`export_presets.cfg` contains exactly two presets: `preset.0` "Web" and `preset.1` "iOS". There is
no Android preset, which means none of the Android work below has ever been exercised, and the
first step is creating one. That also drags in the Android SDK / JDK setup and, if the share
plugin in §5 is used, a **custom Gradle build**.

This is worth being honest about in a plan: "add the camera to Android" is really "stand up an
Android target for a project that has never had one, then add the camera."

### 2c. Permission: declare it, then request it, then wait

Two separate things, and both are needed.

1. **Manifest.** Tick `permissions/camera` in the Android export preset — the docs describe it as
   *"Required to be able to access the camera device."* Without it the runtime request can never
   succeed.
2. **Runtime.** The engine asks for it itself. `CameraFeedAndroid::activate_feed()` opens with:

   ```cpp
   if (!OS::get_singleton()->request_permission("CAMERA")) {
       return false;
   }
   ```

The trap is in that `return false`. The Android permission dialog is **asynchronous** — the first
`activate_feed()` call fires the prompt and then returns false, because the answer has not arrived
yet. There is no retry inside the engine and no graceful degradation: the feed just stays
inactive. If the code treats that false as "no camera on this device," the Jingle Jam Cam screen
comes up dead on every first launch and works on every launch after.

The correct shape is to request first, wait for the answer, and only then activate. The answer
arrives on a `MainLoop` signal:

```
on_request_permissions_result(permission: String, granted: bool)
```

`OS.get_granted_permissions()` reads the current state, and this is the one part of the camera
work that can be built and tested before any camera code exists.

### 2d. `set_format()` before `set_active()`, or nothing happens

This is the single most likely way to lose an afternoon. The Android backend refuses to activate a
feed whose format has not been chosen:

```cpp
ERR_FAIL_INDEX_V_MSG(selected_format, formats.size(), false,
    vformat("CameraFeed format needs to be set before activating..."))
```

`set_format()` also returns false if the feed is already active, so the order is fixed: pick a
format from the feed's `formats` array, `set_format()`, then `set_active(true)`. On iOS-shaped
example code this step is usually absent, which is why copying an iOS snippet onto Android
produces a black rectangle and no obvious error.

Choosing the format is also where the preview resolution gets decided. A phone will happily offer
something enormous; the design canvas is 1080 wide and the composite only needs to look good at
phone-screen and share-sheet sizes.

### 2e. Rotation is handled; mirroring is not

Android's implementation does the hard part for us. `calculate_rotation()` combines three things —
the **sensor orientation** baked into the camera hardware, the **current display rotation**, and
whether the lens is **front or back facing** — and writes the result into the feed's `Transform2D`.
Sensor orientation varies between handset models, so this is genuinely the part you would not want
to write yourself, and it is the clearest advantage Android currently has over the iOS plugin
(§3), where rotation handling comes from whichever backend you bolt on rather than from the engine.

What it does **not** do is mirror the front camera. Reading the implementation, only rotation is
applied — there is no horizontal flip for front-facing lenses. So for a selfie we have to flip it
ourselves, and the flip is a preview-only concern:

- **Mirror the preview.** A selfie preview that is not mirrored feels wrong to anyone who has used
  a phone camera.
- **Do not mirror the saved image.** Text in the shot — a programme, a t-shirt, the Richmond
  Symphony logo on a tote bag — comes out backwards if you do.

Since the artwork overlay is drawn in Godot in front of the feed, take care that the flip applies
to the camera layer only and not to the "LET'S SLEIGH BELLS" lettering.

### 2f. Formats: expect YCbCr, not RGB

Android exposes `FEED_RGB` and `FEED_YCBCR_SEP`, and the PR notes that **`YCBCR_SEP` is used in
most cases**. `FEED_YCBCR_SEP` means the frame arrives as two separate textures — a Y plane and a
CbCr plane — that have to be combined and converted to RGB in a shader. The engine only does that
conversion automatically when the feed is used as a 3D environment background, which is not our
case; we want it as a texture behind 2D artwork.

So a conversion shader is required. shiena's demo ships one (`ycbcr_to_rgb.gdshader`) that can be
read as a reference. This repository already owns a shader (`shaders/snow_sparkle.gdshader`), so
it is a familiar kind of work rather than a new one — but it is real work, and it is the piece
most likely to be missed when estimating.

### 2g. Ask for the feed list properly

`CameraServer.feeds` is not populated the instant you ask. Set `monitoring_feeds = true` and then
wait — [PR #108165](https://github.com/godotengine/godot/pull/108165) (merged for 4.5) added a
`feeds_updated` signal precisely because feeds appear a few frames later on mobile, and documents
the async behaviour. Connect to `feeds_updated`; do not read `feeds` in `_ready()` and conclude
there is no camera.

Each feed's `get_position()` returns `FEED_FRONT`, `FEED_BACK`, or `FEED_UNSPECIFIED`, which is
how the mockup's "could be front or back" gets implemented — pick a feed, offer a flip button.

### 2h. And a caution from elsewhere in this repository

`docs/system_design.md` records that **no Android hardware has been measured for anything on this
project**, and that the engine reports the gravity vector in opposite directions on the two
platforms. That is a sensor note, not a camera note, and the camera work does not depend on it —
but it means an Android build is not just a camera question. The first Android build will be the
first time the shake instrument and the snow have ever run on the platform.

---

## 3. iOS — yes, via a GDExtension

**The stock 4.6 iOS template has no camera backend** (§1a). `CameraServer.feeds` returns an empty
list, and no export setting changes that, because the code is not in the binary. That is the fact
an earlier draft of this document got wrong in the opposite direction — it read the class
reference and reported a one-checkbox job.

**But "not in the engine" is not "not available."** There is a maintained, drop-in path.

### 3a. The recommended path: CameraServerExtension

[godot-cameraserver-extension](https://github.com/j20001970/godot-cameraserver-extension) is a
**GDExtension** that supplies camera backends for the platforms the engine has not got round to.
It requires **Godot 4.4+**, so 4.6 is in range, and its support table lists **iOS on AVFoundation
delivering RGBA**.

Why this is the right shape of dependency:

- **It is a GDExtension, not an engine patch.** Drop it in the project. No custom engine build, no
  patched export template, no forked toolchain — which is the difference between a dependency the
  project can carry and one it cannot.
- **It extends `CameraServer` rather than replacing it.** Feeds it creates appear in the ordinary
  `CameraServer.feeds`, so every line of code in §4 stays the same and nothing in the design is
  extension-shaped. If 4.7 later makes it redundant, deleting it should be close to a no-op.
- **It is alive and it has been fixing exactly our problem.** The most recent release, **2026-03-27**,
  reads *"Fix iOS camera format selection, BGRA conversion, and camera feed activation."* Eight
  releases since March 2025.
- **It carries permission handling**, with `permission_granted()` and a `permission_result` signal
  — which on iOS means the `privacy/camera_usage_description` string in the export preset (ours is
  present and empty) must be written properly, since that is the sentence iOS shows in the prompt.
- **RGBA on iOS means no conversion shader**, unlike Android's YCbCr (§2f). The iOS display path
  is simpler than the Android one.

**NEEDS DEVICE TEST.** Releases are all marked pre-release, and no version compatibility matrix is
published per release. Confirm the 2026-03-27 binaries load under 4.6 and that a feed comes up on
a real iPhone before this is planned around.

### 3b. The alternatives, for completeness

- **Wait for 4.7.** `camera_apple.mm` — a unified Apple backend covering macOS and iOS — is on
  `master` now, and iOS then becomes what Android already is: built in, no dependency. Cleanest
  outcome, and it costs an engine upgrade on a project heading for a late-November concert. Worth
  noting that the **share plugin story points at 4.7 as well** (§5), so one upgrade settles both.
- **Build godot-ios-plugins from PR #89.**
  [PR #89](https://github.com/godot-sdk-integrations/godot-ios-plugins/pull/89) brings that
  package's camera plugin up to Godot 4.x — `get_formats()` / `set_format()`, display-rotation
  callbacks, lazy feed init. It is **open, not merged**, and its own notes say the plugin is
  absorbed into engine core at 4.7+. Depending on an unmerged branch of a third-party package for
  a shipping app is strictly worse than 3a.
- **Custom engine build.** Backport `camera_apple.mm` to 4.6 and build your own iOS template.
  Possible, and disproportionate.

This also retires
[Godot issue #79551](https://github.com/godotengine/godot/issues/79551) — "CameraServer.feeds in
iOS returns nothing" — as a mystery. It is still open, and it is not a bug so much as a missing
implementation.

## 4. Compositing and snapping — the same on both platforms

This part is nearly free, because it is the pattern the application already uses.

A `CameraTexture` bound to the feed id is an ordinary texture. Put it on a `TextureRect` at the
back of the screen and the artwork, the vignette, the snow, and the title all draw in front of it
by `z_index`, exactly as they already draw in front of the background. The Jingle Jam Cam screen
becomes another screen in `app/`, composed like the other four, with `app/sprite_position.gd`
placing its elements against the same 1080-by-1920 design canvas.

The snap is then one line, because the overlay is already composited — it is all one viewport:

```gdscript
var image := get_viewport().get_texture().get_image()
```

Two details to get right: the capture must happen at the end of a frame, and the record button
must not be in the shot — hide the UI for one frame, capture on the next.

---

## 5. Getting the photo to the audience member

Godot has no photo-library API on either platform;
[issue #34007](https://github.com/godotengine/godot/issues/34007) is the standing gap. The route is
the **share sheet**, from which the audience member taps "Save Image" — and the same sheet is how
they text it to whoever they came with, which is arguably the better product. A photo that saves
silently to the camera roll is a photo nobody sees again.

`save_png` to `user://` first; every plugin below requires the file to be under `user://`. On iOS
that is the app's Documents directory, and the export preset already sets `UIFileSharingEnabled`
and `LSSupportsOpeningDocumentsInPlace` for the capture harness — so on iOS a saved photo is
already retrievable through the Files app, which is a usable fallback if nothing else lands in time.
Android has no equivalent freebie; without a share plugin the file is stuck in app-private storage.

**Plugin options, and none is clean on 4.6:**

| Option | Platforms | Godot version | Verdict |
|---|---|---|---|
| [iOS Share Plugin, asset 2907](https://godotengine.org/asset-library/asset/2907) | iOS only | v5.2, **targets 4.6** | The one that actually matches our engine — but iOS only, and moot until §3 is resolved |
| [godot-share](https://github.com/godot-sdk-integrations/godot-share) (moved from cengiz-pz, archived 2026-02-01) | Android + iOS | **unconfirmed** | The natural choice for Android. `share_image()`, `share_texture()`, `share_viewport()` |
| [Share Plugin, asset store listing](https://store.godotengine.org/asset/cengiz/share-plugin/) | Android + iOS | **4.7+** | Same lineage, but the published listing requires 4.7 |
| [Shin-NiL/Godot-Share](https://github.com/Shin-NiL/Godot-Share) | Android + iOS | Godot 2 & 3 only | Dead for our purposes |

**NEEDS VERIFY:** which release of `godot-share` runs on 4.6. The store listing says 4.7+ and the
repository does not state a version; that gap has to be closed by reading the release tags before
anyone plans around it. Note the pattern: **the share story and the iOS camera story both point at
4.7.** If a 4.7 upgrade is happening anyway, doing it once resolves both.

Android setup also needs a **custom Gradle build**, and the `$genname` token must be removed from
`package/unique_name` in the export preset — the default `com.example.$genname` is not substituted
before export and breaks the plugin.

`privacy/photolibrary_usage_description` needs filling in on iOS if a save path is used.

This is the only part of the whole feature requiring a third-party dependency, and it is worth
weighing against the **"No fallbacks"** convention in `docs/system_design.md` before committing.

---

## 6. What to check on a phone, in order

Desk research cannot settle any of these, and each is cheap enough that guessing costs more.

1. **iOS, an hour.** Print `CameraServer.feeds.size()` on the iPhone with the stock template
   first — expect zero, and that confirms §1a on our own hardware rather than on my reading of it.
   Then add the CameraServerExtension release from 2026-03-27, write a real
   `privacy/camera_usage_description`, and print it again. A non-zero number there is the whole
   question answered, and it decides between §3a and waiting for 4.7.
2. **Android, an afternoon.** Create the Android export preset, tick `permissions/camera`, and get
   a feed on screen: request permission → wait for `on_request_permissions_result` → `set_format()`
   → `set_active(true)` → `CameraTexture` on a `TextureRect`. Confirm the rotation is right in
   portrait, confirm `get_datatype()` returns `FEED_YCBCR_SEP`, and see how bad it looks before the
   conversion shader.
3. **Then the shader**, then the mirror-the-preview-not-the-save rule, then sharing.

Do step 1 and step 2 before writing a feature spec. Together they cost a day and they decide the
platform, the engine version, and whether this is a stretch goal or a real one.

---

## 6a. Measured on the handset, 2026-08-23

Everything above this point was desk research. This section is what an iPhone actually did, recorded because the Android build will need it and because two of the assumptions the desk research produced were wrong.

The harness is `capture/camera_probe.gd`, kept in the repository. It is reached the same way the motion-capture harness is, and it reports on screen rather than to a console so it can be read without attaching the phone to Xcode.

### What the phone reported

**Eight feeds, not two.** An iPhone enumerates its physical cameras *and* the fused virtual ones as separate feeds:

| Index | Position | Name |
|---|---|---|
| 0 | BACK | Back Camera |
| 1 | FRONT | Front Camera |
| 2 | BACK | Back Telephoto Camera |
| 3 | BACK | Back Dual Camera |
| 4 | FRONT | Front TrueDepth Camera |
| 5 | BACK | Back Ultra Wide Camera |
| 6 | BACK | Back Dual Wide Camera |
| 7 | BACK | Back Triple Camera |

The consequence for any code that wants "the selfie camera": **select by name, not by the first matching position.** Two feeds report FRONT and six report BACK. Taking the first match happens to give `Front Camera` on this handset and would give `Front TrueDepth Camera` on one that enumerates differently.

**Every value read before activation is a placeholder.** All eight feeds reported `datatype: RGB (1)` and `formats: 0` before activation. After activation the same feed reported `datatype: YCBCR_SEP (3)`. A display path built against the pre-activation reading is built against a constructor default. This cost two probe runs to discover and is the single most useful thing in this section.

**`formats` stays empty even when the feed is live.** `formats: 0` before activation and `formats: 0` after, on a feed delivering frames. On iOS no format is selected and none can be.

### The activation defect

On the launch where camera permission is first granted, the camera runs and the engine does not know it.

`modules/camera/camera_apple.mm` `activate_feed()` returns `true` when permission is already granted. When permission is undetermined it calls `requestAccessForMediaType`, whose completion handler builds the capture session later, and **returns `false` immediately**. `servers/camera/camera_feed.cpp` marks a feed active only when that call returns true:

```cpp
} else if (p_is_active) {
    if (activate_feed()) { active = true; }
}
```

Nothing runs again when the person taps Allow. Measured result: the phone's green camera indicator came on and stayed on, and `feed_is_active` read `false` six seconds later. The application was holding the camera while believing it was not.

**Confidence in calling this a defect.** The half that is not arguable is the state disagreeing with the hardware — a running camera reported as inactive is wrong on any reading. The half that could be argued as intended is `activate_feed()` returning false while a prompt is outstanding, on the view that the caller should try again. But the engine exposes **no signal, callback, or status query** to try again *on*: there is no `permission_result`, no `permission_granted()`, nothing. That the [CameraServerExtension](https://github.com/j20001970/godot-cameraserver-extension) adds exactly those two things is evidence other people found the same gap. **No existing Godot issue was found describing it**, which given that the iOS backend shipped only in 4.7 more likely means few people have reached it than that it is not real.

### The cure, measured

Deactivating and reactivating once permission has been answered brings the feed up — `active now: true`, `datatype: YCBCR_SEP (3)`.

Deactivating first is not decoration. The completion handler has already built a capture session and assigned it; activating over the top overwrites that pointer while the session it referred to is still running. `set_active(false)` runs `deactivate_feed()`, which releases it.

Note also that **`set_active()` returns `void`** — it is the setter for `feed_is_active`. Success is read back from the property, never from a return value.

### Rotation and mirroring, as built

**Apply the engine's rotation exactly, and add nothing to it.** On an iPhone held in portrait the
feed's transform reports **90 degrees**, and applying precisely that stands the picture upright on
both cameras. Two builds were spent on the assumption that the figure needed correcting by a half
turn; it does not. `app/camera_feed_view.gd` keeps an exported `extra_quarter_turns` for a handset
that disagrees, and its correct value here is zero.

The transform is not applied for you on this path. `feed_transform` is honoured automatically only
when a feed is used as a 3D environment background; a `CameraTexture` on a `TextureRect` ignores
it, so the rotation is applied to the node that draws the picture. Rotating by a quarter turn
transposes the rectangle, so the node is sized to the viewport with its axes swapped and shifted
back over the screen.

**Mirroring has to be a left-right flip on the screen, not in the texture.** After a quarter or
three-quarter turn the texture's own horizontal axis is running up and down the screen, so
flipping it there stands the person on their head instead of mirroring them. The shader takes a
flag per axis and the caller sets whichever is screen-horizontal at the current rotation: `u` at
no turn or a half turn, `v` at a quarter or three-quarter turn.

**Hide the picture until the feed is genuinely delivering.** A `CameraTexture` with no frames yet
returns the engine's placeholder image, which draws full-screen and reads as a fault.

### What is different on Android, for the build that comes later

Each row is a place where iOS-shaped camera code will not work unaltered.

| | iOS (measured) | Android (from the source and PR #106094) |
|---|---|---|
| Where the backend lives | `modules/camera/camera_apple.mm`, since 4.7 | `modules/camera/camera_android.cpp`, since 4.5 |
| `set_format()` before `set_active()` | **Not required, and impossible** — `formats` is empty | **Required.** `ERR_FAIL_INDEX_V_MSG` reading "CameraFeed format needs to be set before activating" |
| Data type | `FEED_YCBCR_SEP` | `FEED_RGB` and `FEED_YCBCR_SEP`; the PR notes YCBCR_SEP is usual |
| Feed count | 8, including fused virtual cameras | Not measured. No Android handset has been tested for anything on this project |
| Permission request | Engine calls `requestAccessForMediaType` inside `activate_feed()` | Engine calls `OS::request_permission("CAMERA")` inside `activate_feed()` |
| Permission also needs | `privacy/camera_usage_description` in the export preset | `permissions/camera` ticked in the export preset, for the manifest |
| Retrying after the grant | Poll, because nothing reports the answer | **Event-driven.** `MainLoop`'s `on_request_permissions_result(permission, granted)` fires, so the retry keys off a signal rather than a timer |
| Rotation | Handled in-engine, `handle_rotation_change()` | Handled in-engine, `calculate_rotation()` |
| Front-camera mirroring | **Not applied.** Ours to do | **Not applied.** Ours to do |
| Minimum platform version | — | API 24, matching Godot 4.7's `minSdk 24` default. Camera2 NDK requires it |

The activation defect is the same shape on both — `activate_feed()` returns false while the permission answer is outstanding — but Android is the better-served platform for recovering from it, because `on_request_permissions_result` tells you exactly when to retry. An Android port should key the retry off that signal and keep the timed poll for iOS only.

One thing that is not a camera question but will bite the same build: `docs/system_design.md` records that the engine reports the gravity vector in **opposite directions** on the two platforms and that no Android handset has been measured. The first Android build will be the first time the shake instrument and the snow have ever run on the platform.

## 7. Note on the web

Recorded only so the question is not re-asked. Godot has **no web camera implementation**, and the
[CameraServerExtension GDExtension](https://github.com/j20001970/godot-cameraserver-extension) that
exists to widen platform coverage lists Web as unsupported. On the web the camera can never be an
object inside the game — it has to be a `<video>` element behind a transparent canvas, with the
snapshot composited by hand in JavaScript. On top of that, every known iPhone camera defect is
specific to installed-web-app standalone mode: permission not persisted across launches
([WebKit 215884](https://bugs.webkit.org/show_bug.cgi?id=215884)), and a feed that arrives rotated
90° in home-screen apps but not in Safari
([Apple Developer Forums 801146](https://developer.apple.com/forums/thread/801146), September 2025,
no response).

None of it applies to us. Holiday Sleigh Bells is a native application.
