---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for Ship the Same App on Android, Without Touching the iPhone
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: The order the Android work has to happen in, the four places the two platforms genuinely diverge, and the one place the specification asks for a file the engine no longer reads, all settled here rather than discovered on a handset at eleven at night.
LAST UPDATED: September, 3, 2026 15:42
---

# Implementation Plan for Ship the Same App on Android, Without Touching the iPhone

This plan implements the Android Build and Play Store Release feature (C1_20). The specification carries fourteen requirements; requirement 1, the toolchain, and requirement 12, the privacy policy draft, are already complete, and a fifteenth requirement is added below by decision during planning.

## Design decisions carried in from the specification and planning conversations

These are settled. They are recorded so that nothing below re-opens them.

- **Full parity.** The Android build carries the Jingle Cam, the share sheet, the snow, and the shake instrument. There is no reduced Android edition.
- **The iPhone's behaviour does not change.** Every platform difference sits behind an explicit check. The one iPhone file that changes is the export preset, and only for the two wrong permission descriptions in requirement 14.
- **Feed selection is position-filtered with an iOS name tie-breaker**, not a platform fork. One selection function.
- **The package name is `com.richmondsymphony.holidaysleighbells`**, all lowercase, permanent from the first upload.
- **The privacy policy link goes at the bottom of the instructions screen** (planning question 1a), opened with `OS.shell_open()`.
- **The Android launcher icons are derived from `images/v2/ios_icon.png`** (planning question 2a), with a flat brand-colour background layer, to be replaced if Christopher's Figma work (`C1_T03`) lands first.
- **The gravity sign correction goes in one shared helper both callers use** (planning question 3b). Neither `snow/snow.gd` nor `app/phone_tilt.gd` has its own logic restructured.
- **The feature completes at a verified handset build, not at a Play upload** (planning question 4a). The Play Console phase runs last and is gated on the Symphony publishing the policy.
- **Android motion recordings come off the handset with `adb pull`.** No code.
- **The upload keystore never enters version control.** Godot writes keystore passwords to `export_credentials.cfg`, which `.gitignore` already excludes at line 8. No new mechanism is needed.

## One correction to the specification

Requirement 8 says the Android plugin configuration "is added under `res://android/plugins/`" as a plugin definition file. **That is how Godot 3 and early Godot 4 loaded an Android plugin, and it is not how this plugin works.**

`addons/SharePlugin/SharePlugin.gd` is an `EditorPlugin` that registers an `AndroidExportPlugin extends EditorExportPlugin` (line 124) and implements three methods the modern export path calls directly:

- `_get_android_libraries()` returns the archive path, choosing `bin/debug/SharePlugin-debug.aar` or `bin/release/SharePlugin-release.aar` by build type.
- `_get_android_dependencies()` returns `androidx.appcompat:appcompat:1.7.1`.
- `_get_android_manifest_application_element_contents()` injects the `ShareFileProvider` provider element and the share-target activity.

The plugin is already enabled in `project.godot`. **Writing a plugin definition file would add a second, competing declaration of the same archive.** Requirement 8 is therefore implemented by making the export work rather than by authoring that file, and the plan proceeds on that basis.

One consequence is load-bearing and is why the ordering below matters. The file provider's authority string is built from `get_option("package/unique_name")`. **The package name must be correct in the preset before the share sheet can work at all**, because an authority that disagrees with the manifest makes every share attempt fail at the Android permission layer rather than in code.

## Implementation Steps and Phases

Nine phases. Each ends at something observable, and the early ones end at something installable, so a toolchain fault is found before any code has been written against it.

### Phase 1 — Configure the export preset and take a first build to a handset

Requirement 2, and the smoke test for requirement 1.

1. In `export_presets.cfg` under `[preset.2.options]`, set `package/unique_name="com.richmondsymphony.holidaysleighbells"`, replacing the `$genname` placeholder.
2. Set `package/name="Holiday Sleigh Bells"`, the launcher label.
3. Set `version/name="0.02"`, matching the iOS preset's `application/short_version`, and leave `version/code=1` for now. The code increments on every Play upload and is the developer's to raise; the Play Store rejects a code it has already seen.
4. Set `export_path="exports/android/HolidaySleighBells.aab"`.
5. Set `gradle_build/use_gradle_build=true`.
6. Set `gradle_build/export_format` to the Android Application Bundle.
7. Leave `gradle_build/min_sdk` and `gradle_build/target_sdk` **empty**, so the values in the build template's `config.gradle` govern — 24 and 36. Setting a minimum below 24 removes the camera silently, because the Android camera backend is built on Camera2 and Camera2 requires 24.
8. Confirm `architectures/arm64-v8a=true` and every other architecture false, matching the iOS build.
9. Confirm `permissions/camera=true` and that no other permission is enabled. The application makes no network request; the absence of the network permissions is a claim the privacy policy makes.
10. Add `exports/android/` to `.gitignore`. The existing rule ignores `exports/` and un-ignores only the iOS Xcode project, so the bundle is already excluded; the explicit line is for the reader.
11. Export a debug build and install it on the handset with `adb install`.

**Phase 1 ends when the application launches on Android and the four audience screens can be walked.** The camera, the share sheet, and the snow direction are all expected to be wrong at this point. Nothing in later phases is worth starting until this passes, because everything after it assumes the toolchain, the signing, and the Gradle build work.

### Phase 2 — Derive the Android launcher icons

The remainder of requirement 2.

1. Create `images/v2/android/` and generate three assets from `images/v2/ios_icon.png` (1024 by 1024):
   - `launcher_192.png` at 192 by 192, the whole icon.
   - `adaptive_foreground_432.png` at 432 by 432, carrying the photograph. A launcher masks this layer to a circle, squircle, or teardrop and shows only the inner 66 per cent, roughly 288 pixels, so the artwork is scaled to 360 and offset to put Winnie's face at the layer's centre. **Filling the layer at 432 was tried first and is wrong**: the mask took the ears and the muzzle and left an unreadable brown field.
   - `adaptive_background_432.png` at 432 by 432, a flat fill in the green sampled from the photograph's own ground, `(47, 143, 112)`.

   **This is a deviation from the plan as first written**, which called for the flow's blue as the background with the icon on the foreground. That split suits a logo on transparency; `images/v2/ios_icon.png` is a fully opaque photograph of Winnie with a green ground, and a blue field behind it would have shown as a coloured band wherever the mask or a parallax animation exposed the layer beneath. Sampling the photograph's own ground makes the seam invisible instead.
2. Point `launcher_icons/main_192x192`, `launcher_icons/adaptive_foreground_432x432`, and `launcher_icons/adaptive_background_432x432` at them.
3. Leave `launcher_icons/adaptive_monochrome_432x432` empty. A monochrome layer drives Android 13's themed icons and is optional; supplying a poor one is worse than supplying none.
4. Leave the splash configuration alone. `splash_screen/disable_godot_boot_splash=false` keeps the engine's boot splash, which already draws `images/RichmondSymphonyLogo.png` through `boot_splash/image` in `project.godot` and is therefore the same splash the iPhone shows.

**No media file is deleted or replaced.** Nothing here engages the repository's rule about archiving to `legacy/`, because every asset is new.

**Phase 2 ends when the launcher icon reads correctly on the handset's home screen under a circular mask and a squircle mask.**

### Phase 3 — Port the camera

Requirements 3, 4, 5, and 6, all in `app/camera_feed_view.gd`.

1. **Replace `_find_feed` with a position-filtered selection.** Filter `CameraServer.feeds()` to those whose `get_position()` matches the wanted position, `FEED_FRONT` for the selfie camera and `FEED_BACK` for the rear. Then, on iOS only, select from that filtered set the feed whose `get_name()` matches `SELFIE_FEED_NAME` or `REAR_FEED_NAME`; on Android, take the first of the filtered set. Return `null` when the filtered set is empty.

   `SELFIE_FEED_NAME` and `REAR_FEED_NAME` are kept and are now the iOS tie-breaker rather than the whole rule. The comment block at the top of the file recording the eight-feed finding is extended rather than replaced, because that finding is still why the tie-breaker exists.

   `_is_selfie()` currently compares `_feed.get_name()` against `SELFIE_FEED_NAME`, which is an Apple name and is false on every Android feed. It is rewritten to compare `_feed.get_position()` against `FEED_FRONT`, which is correct on both platforms and is what the mirror in requirement 6 depends on.

2. **Add a format selection, Android only.** Before activation, when the platform is Android, read `_feed.get_formats()`, choose a format, and call `_feed.set_format()`. The order is fixed: choose, set, then activate. `set_format()` fails on a feed that is already active, and the Android backend refuses to activate a feed whose format was never chosen.

   **The format is filtered by image format first, and only then by width.** Each entry in `feed.formats` is a Dictionary of `width`, `height`, and `format`, where `format` is one of the strings `"YUV_420_888"`, `"RGBA_8888"`, or `"RGB_888"`. The backend calls `set_ycbcr_images()` and reports `FEED_YCBCR_SEP` when the chosen format is the first of those, and `set_rgb_image()` reporting `FEED_RGB` when it is either of the others. `shaders/ycbcr_to_rgb.gdshader` converts two planes and nothing else, so choosing an RGB format would draw its bytes as though they were luma and chroma and produce garbage colour with no error anywhere.

   The datatype is therefore a consequence of the format chosen rather than a property of the handset, and selecting `"YUV_420_888"` makes it deterministic and identical to the iOS path. Only entries carrying that format are considered.

   Within them, the choice is the smallest whose width is at least an exported `preferred_preview_width`, defaulting to 1080 to match the design canvas, taking the widest of the filtered set when none reaches it. A phone offers formats far larger than the canvas, and a preview larger than the canvas costs frame time and memory for a picture that is drawn behind artwork and captured at viewport size.

   A feed offering no `"YUV_420_888"` entry at all fails with a message naming the feed and how many formats it did offer. That is not a fallback; it is the absence of the one format this screen can draw.

   `preferred_preview_width` is validated in `_ready()` with a message naming the value, its permitted range, and the correct default, as the repository's convention requires of an exported value used as a bound.

3. **Add the Android permission wait.** On Android, request the camera permission and wait for the answer before opening a feed. The engine's Android backend requests the permission inside `activate_feed()` and returns false immediately when it is not yet held, with no retry, so a first launch that treats that false as "no camera" gives a dead screen once and a working screen forever after.

   This is a separate path from `_await_activation`, which stays exactly as it is and stays iOS-only. The two faults look alike and are not alike: Apple never reports its answer, so iOS retries blind; Android reports its answer on a signal, so Android waits for it. The existing `activation_timeout_seconds` still bounds the wait on both platforms, and a timeout still emits `camera_unavailable`.

4. **Requirement 6 needs no code.** `_apply_mirror` already runs on both platforms and already chooses its flip axis from the rotation. It works on Android once `_is_selfie()` is correct, which step 1 does. This is verified on the handset rather than assumed.

5. **Rotation is not touched.** `_quarter_turns` reads `feed_transform`, which the Android backend populates from sensor orientation, display rotation, and lens facing. `extra_quarter_turns` remains the exported escape hatch if a handset disagrees.

**Phase 3 ends when the Jingle Cam shows an upright, correctly mirrored selfie preview on Android and still does on the iPhone.**

### Phase 4 — Correct the gravity sign

Requirement 7.

1. Add to `app/phone_tilt.gd` a shared function returning the platform-corrected gravity vector, applying the sign inversion on Android and returning the reading unchanged on iOS and everywhere else.
2. Have `PhoneTilt.read()` call it in place of reading `Input.get_gravity()` directly.
3. Have `snow/snow.gd:116` call it in place of reading `Input.get_gravity()` directly, at line 116 only.

`snow.gd` keeps its own normalization, its `lerp_angle` smoothing, and its `direction_floor` guard. It needs the raw in-plane vector for `.angle()` and cannot use `PhoneTilt.read()`, which returns a normalized vector with a noise-floor guard of its own. Routing only the gravity read through the shared helper puts the platform decision in one place without editing either file's working logic.

`snow.gd:138` reads `Input.get_accelerometer() - Input.get_gravity()` for linear acceleration. **That line is not changed.** The platform difference cancels in the subtraction, which is the reason the shake detector was built on linear acceleration and nothing else.

**The true sign is established by measurement in Phase 8, not assumed here.** The helper is written so that flipping the Android branch is a one-line change once the handset has answered.

**Phase 4 ends when the snow falls downward on Android and still falls downward on the iPhone.**

### Phase 5 — Make the share sheet work on Android

Requirement 8.

1. Verify the export includes the archive. `_get_android_libraries()` resolves `SharePlugin/bin/release/SharePlugin-release.aar` relative to the addons directory, and a Gradle build is what packages it. No plugin definition file is authored, for the reason given above.
2. Verify the injected manifest carries a file provider authority of `com.richmondsymphony.holidaysleighbells.sharefileprovider`, derived from the package name set in Phase 1.
3. Correct the comment on `PHOTO_PATH` in `app/jingle_cam.gd`. It explains the choice of `user://` in iOS terms — that it resolves to the Documents directory and is reachable through the Files application. That is untrue on Android, where `user://` is application-private storage the person cannot browse. The behaviour does not change and the file is still written before sharing; only the comment is corrected so it does not assert something false.

**Phase 5 ends when the shutter opens the Android share sheet and the photograph arrives intact in a chosen application.**

### Phase 6 — Add the in-app privacy policy link

Requirement 15, added by planning decision 1a. Both stores require a privacy policy link inside the application, not only in the store listing, and no screen carries one.

1. Add a `Button` to `app/instructions.tscn`, below the instruction list and clear of the Continue button, styled as a quiet text link rather than as one of the flow's blue buttons.
2. Carry `app/safe_area_margin.gd` on it with authored base offsets, as every bottom-anchored control in this flow does, so it stays clear of the home indicator.
3. In `app/instructions.gd`, hold the node in an `@onready` reference, validate it in `_ready()` with a message naming the missing node, connect its `pressed` signal in `_ready()` rather than in the scene file, and open the policy with `OS.shell_open()`.
4. Hold the address in one exported constant so it is changed in one place when the Symphony publishes.

**Phase 6 ends when the link opens the policy in the system browser on both platforms.**

### Phase 7 — Correct the iPhone's permission prompts

Requirement 14. This is the only change to the iOS preset.

1. **Remove `privacy/photolibrary_usage_description` entirely.** It reads `Symphony Sleigh Bells stores stylized user photos in their Photos library`, which names an application that does not exist and describes behaviour the application does not have: `app/jingle_cam.gd` writes to `user://jingle_cam.png` and hands that file to the share sheet, so a photograph reaches the photo library only when the person picks Photos from the sheet themselves. Declaring an unused permission is a rejection risk, and describing behaviour the application lacks contradicts the privacy policy.
2. **Rewrite `privacy/camera_usage_description`.** It currently reads `...take a stylized photo of yourself with during the concert`, where "with during" is an editing leftover. The replacement states plainly that the camera is used so the person can take a festive photograph at the concert.

Both strings are shown verbatim in the system permission prompt and are read by an Apple reviewer.

### Phase 8 — Signing keys, then prove it on both handsets

Requirements 9, 10, and 11.

1. Generate the upload keystore with `keytool`. Record its location and who else holds a copy; a key on one laptop is a single point of failure for a Symphony application. The passwords go to `export_credentials.cfg`, already gitignored.
2. Export a signed release bundle and install it.
3. Walk the whole Android flow: title, instructions, bell selection with the carousel and fun facts, the play screen, all three bells across their dynamic range, the snow, the artwork tilt, and the Jingle Cam through preview, switch, shutter, and share.
4. Point `run/main_scene` at `capture/shake_capture.tscn`, record shake runs on the handset, and `adb pull` them.
5. **Restore `run/main_scene` to the title screen.** This is a completion criterion of any feature that changes it.
6. Archive the recordings in a new `features/data/C1_09/Android/` folder with the handset model, Android version, and achieved sample rate in the header, as that directory's own guidance prescribes for a new device.
7. Confirm the detector's measured constants hold on Android. If they do not, that is a finding to record, not a change to make inside this feature.
8. Re-export the iPhone build and walk the same flow, checking the camera picks the right lens among many feeds, the first-launch permission behaviour, the selfie mirror, the snow direction, the artwork tilt, the shake instrument, and the share sheet.

### Phase 9 — Play Console, gated on the Symphony

Requirement 13. **Entry condition: the privacy policy is live at a public address on `richmondsymphony.com`.** Nothing in this phase can start before that.

1. Create the application in the Richmond Symphony's Play organization account.
2. Enrol in Play App Signing.
3. Complete App Content: the privacy policy address, the content rating questionnaire, the data safety form declaring no data collected, the target audience declaration, the advertising declaration of none, and the application access declaration of no login.
4. Complete the store listing to the minimum the internal track requires.
5. Upload the signed bundle to the internal testing track and confirm a tester can install it.

**The target audience declaration is made with the Symphony, and the answer and its reasoning are written down.** Google states that an application whose listing carries youthful animation or young characters may have a thirteen-and-over declaration challenged, and reserves the right to review the declared audience itself. This application is hand-drawn cartoon artwork with a named character, handed out at a family concert. Either answer is available, because there is no advertising, no analytics, and no data collection.

## Test Cases

**No automated tests are created or changed by this plan.** §"Testing" in `docs/system_design.md` records that this repository has no test framework and that three consecutive features have declined to introduce one.

That reasoning is at its strongest here. This feature's subject is a platform, and every claim it makes is about hardware: whether a camera enumerates a front-facing feed, whether gravity points the way the engine says, whether an archive was packaged into a bundle, whether a launcher mask crops an icon. None of it exists in the editor, the desktop build, or an emulator. The acceptance table at the end of this plan carries the whole burden.

Six failure modes worth naming, because each looks like something other than its cause:

- **The Jingle Cam is a black rectangle on Android, with no error.** `set_format()` was never called, or was called after `set_active()`. The engine logs `CameraFeed format needs to be set before activating`, which is easy to miss among Gradle output.
- **The Jingle Cam is dead on first launch and works on every launch after.** The Android permission answer was not waited for. This is the single most likely defect in Phase 3 and it hides from anyone who tests on a handset that has already granted the permission. Testing it means uninstalling first.
- **The selfie preview is not mirrored on Android.** `_is_selfie()` is still comparing names rather than positions, so it returns false on every Android feed. The same fault also disables the mirror on a correctly selected camera, which makes it look like a mirror bug rather than a selection bug.
- **The share sheet does nothing, or the photograph arrives empty.** The file provider authority disagrees with the package name. This is why the package name is set in Phase 1 and not later.
- **The snow falls upward on Android.** The sign in the shared helper is inverted. Expected on the first build, and the whole reason Phase 8 measures before Phase 4 is called finished.
- **The launcher icon has its edges cut off.** The adaptive foreground artwork sits outside the inner 66 per cent safe zone. It looks correct in the editor and wrong on the home screen, because the mask is the launcher's, not the application's.

## README and Documentation Updates

- **`README.md`** gains the Android build steps: the toolchain versions and where they came from, the `sdkmanager` line with its `--sdk_root`, the Godot editor paths, and the note that the build template is installed from the editor and not committed.
- **`docs/system_design.md`** has three statements this feature makes untrue and they are corrected rather than left:
  - The platform notes say **"Android is unverified"** and that no Android hardware has been measured. After Phase 8 this is false, and the section is rewritten around what was measured.
  - The same section names `snow/snow.gd` and `app/phone_tilt.gd` as two live copies of an iOS-shaped mapping, "named together here so whoever fixes one finds the other." After Phase 4 there is one shared helper, and the note becomes a record of what was done.
  - The repository layout table gains `android/` and notes that `android/build/` is generated and ignored.
- **`features/data/C1_09/README.md`** gains the `Android/` folder in its directory layout, beside `iPad/` and `iPhone/`.
- **`features/jingle_jam_cam_camera_exploration.md`** §2b says "we have no Android export preset at all" and that none of the Android work "has ever been exercised." A short note records that it has been.

## Manual Verification Steps

Every step is performed on hardware. Steps 1 through 8 are Android; step 9 is the iPhone.

1. The application installs and launches, and the four audience screens can be walked forward.
2. The launcher icon reads correctly on the home screen under both a circular and a squircle mask.
3. **On a handset that has never granted camera permission**, opening the Jingle Cam shows the permission prompt, and granting it brings the preview up without leaving the screen. This step is void on a handset that has already granted it; uninstall first.
4. The selfie preview is upright and mirrored. Lettering drawn over it is not reversed.
5. The camera switch control appears only when the handset offers two cameras, and switching gives an upright, correctly unmirrored rear picture.
6. The shutter opens the share sheet, and the photograph arrives intact in a chosen application with the artwork over it and no controls in it.
7. The snow falls downward when the phone is held upright, and drifts with a tilt rather than against it. The red tree leans the way the phone leans.
8. Each of the three bells sounds across its dynamic range, with a soft shake and a hard shake producing different recordings rather than the same recording at two volumes.
9. On the iPhone, every one of steps 3 through 8 behaves exactly as it does today, and the camera selects the plain front and rear cameras rather than a fused or TrueDepth feed.
10. The privacy policy link opens the policy in the system browser on both platforms.
11. `run/main_scene` points at the title screen.

## Coding Standards Compliance Checklist

There is no application coding standards document; `docs/system_design.md` §"Conventions" is what a review here audits against, as that document instructs.

- Tab indentation in every changed GDScript file.
- A one-line comment at the top of each changed script naming the file and its role, with the platform-divergence reasoning recorded where the branch lives.
- Static typing on every new declaration and return type, including `-> void`.
- Signals connected in `_ready()` and not in the scene file. The privacy policy button in Phase 6 is the only new connection.
- Scene and script files named in lower snake case. New icon assets under `images/v2/android/` follow the same.
- `preferred_preview_width` is validated in `_ready()` with a message naming the value, its permitted range, and the correct default.
- The privacy policy button is reached by scene path and validated in `_ready()` rather than at first use.
- **No fallbacks.** A camera with no matching feed emits `camera_unavailable` and says what is missing; nothing substitutes a different lens. The format choice falls back to the widest offered format, which is a documented selection rule over a non-empty list rather than a substitute for a missing value.

## File-Level Compliance Review

| File | Change |
|---|---|
| `export_presets.cfg` | Android preset filled in; two iOS permission descriptions corrected, one removed |
| `app/camera_feed_view.gd` | Position-filtered selection, `_is_selfie()` by position, Android format selection, Android permission wait, exported `preferred_preview_width` |
| `app/phone_tilt.gd` | Shared platform-corrected gravity read; `read()` routed through it |
| `snow/snow.gd` | Gravity read at line 116 routed through the shared helper. Line 138 untouched |
| `app/jingle_cam.gd` | `PHOTO_PATH` comment corrected for Android |
| `app/instructions.tscn` | Privacy policy button added |
| `app/instructions.gd` | Button reference, validation, connection, and `OS.shell_open()` |
| `images/v2/android/` | Three new launcher icon assets |
| `.gitignore` | `exports/android/` made explicit |
| `README.md`, `docs/system_design.md`, `features/data/C1_09/README.md`, `features/jingle_jam_cam_camera_exploration.md` | Documentation corrections above |
| `features/data/C1_09/Android/` | New handset recordings |

No file is deleted. No media file is deleted, replaced, or moved to `legacy/`; every asset added is new.

## Completion Criteria

1. The application runs on an Android handset and every step in Manual Verification passes.
2. The iPhone build passes step 9 with no observable change from today, and the iOS preset differs from today only by the two permission-description corrections.
3. Android shake recordings are archived under `features/data/C1_09/Android/` with their handset identified.
4. The gravity sign is settled by measurement and recorded.
5. `run/main_scene` points at the title screen.
6. The upload keystore exists, its location is recorded, and no key or password is in version control.
7. The four documentation corrections are made.
8. The project loads with no errors and every resource reference resolves.

**Phase 9 is not a completion criterion**, per planning decision 4a. It runs when the Symphony publishes the policy.

## Token and Design Considerations

This feature builds no skill, so there is no skill token cost to account for.

## Teaching Topic

Add to the tutor's `references/topics.md` an entry for **the Android build and release toolchain**, granting the ability to take this repository from a clean machine to a signed bundle in the Play Store without rediscovering the toolchain. It covers: reading the pinned Java Development Kit, Software Development Kit, Android Gradle Plugin, and Gradle versions out of `android_source.zip`'s `config.gradle` rather than guessing them, and why a newer Java Development Kit fails rather than degrading; why the Android build needs a Gradle build at all, which is the share plugin's archive; why a modern Godot plugin needs no plugin definition file; the difference between the upload key and the application signing key under Play App Signing; and which App Content declarations Play demands before even an internal release publishes.

## Acceptance Table

This replaces the unit-test table, for the reason given in Test Cases. Every row is verified by hand on a handset.

| Behaviour under test | Concrete input | Expected result |
|---|---|---|
| Application launches on Android | Install the debug build, tap the icon | Title screen draws, "Tap to start" responds |
| Launcher icon under a mask | View the home screen icon under circular and squircle masks | Artwork fully visible, nothing cropped at the edges |
| Camera permission, first ever launch | Uninstall, reinstall, open Jingle Cam | Permission prompt appears; granting brings the preview up without leaving the screen |
| Camera permission, declined | Decline the prompt | Preview does not appear, the screen reports it cannot get a camera, no crash |
| Feed selection on Android | Open Jingle Cam on a multi-lens Android handset | The plain front camera opens, not a wide or depth sensor |
| Feed selection on iPhone | Open Jingle Cam on the iPhone 13 Pro | The plain "Front Camera" opens, not TrueDepth, Dual, or Triple |
| Selfie mirroring on Android | Raise a hand to one side in the preview | The hand appears on the same side as in a mirror; overlaid lettering is not reversed |
| Camera switch | Tap the switch control | The rear camera opens upright and unmirrored |
| Switch control on a one-camera handset | Open Jingle Cam where only one camera exists | The switch control is not drawn |
| Share sheet on Android | Tap the shutter, choose an application | The photograph arrives intact, artwork over it, no on-screen controls in it |
| Snow direction on Android | Hold the phone upright | Snow falls downward and drifts with the tilt, not against it |
| Artwork tilt on Android | Lean the phone left, then right | The red tree leans the way the phone leans |
| Snow and tilt on the iPhone | Repeat the two rows above on the iPhone | Identical to today's behaviour |
| Shake instrument on Android | Shake each of the three bells softly, then hard | Each bell sounds; soft and hard draw different recordings, not one recording at two volumes |
| Privacy policy link | Tap the link on the instructions screen, both platforms | The policy opens in the system browser |
| iPhone permission prompt text | Fresh install on the iPhone, open Jingle Cam | The camera prompt reads as a clean sentence; no photo library prompt appears at any point |
| Main scene restored | Read `run/main_scene` in `project.godot` | It points at the title screen |
