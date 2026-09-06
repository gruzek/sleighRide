---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Ship the Same App on Android, Without Touching the iPhone
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.2
AUTHOR: George Ruzek
VALUE STATEMENT: Doubles the audience the sleigh bells can reach by putting the identical experience on Android phones and into the Google Play Store, while proving the iPhone build comes through untouched.
LAST UPDATED: September, 3, 2026 12:28
---

# Ship the Same App on Android, Without Touching the iPhone

## Summary

The Android Build and Play Store Release feature (C1_20) takes Holiday Sleigh Bells from an iPhone-only application to one that runs identically on Android, and puts a signed build into the Google Play Store's internal testing track. It covers the whole path: standing up the Android toolchain on the development machine, configuring the export preset, porting the three parts of the application that were written iOS-shaped and will not work on Android as they stand, generating the signing keys, proving the result on an Android handset, proving the iPhone build's behaviour is unchanged, correcting two wrong permission descriptions on the iPhone, drafting a privacy policy for the Richmond Symphony to publish, and creating the application in the Play Console. An Android audience member gets the same four screens, the same shake instrument, the same snow, and the same Jingle Cam that an iPhone audience member gets.

## Background

Holiday Sleigh Bells has been built, from the beginning, on one platform. Every feature from the Responsive Screen Layout feature (C1_07) through the Tap to Choose Your Bell feature (C1_19) was written, measured, and verified on an iPhone. The system design says so plainly under its platform notes: **Android is unverified**, and no Android hardware has ever been measured for anything on this project. The two roadmap tasks that carry the delivery of this application, the TestFlight release task (`C1_T01`) and the App Store release task (`C1_T02`), are both Apple channels.

That is a real gap in reach. Android is roughly half of the handsets in a concert hall, and an audience member holding one currently cannot participate at all. The application asks nothing of the network, stores nothing, and needs no account, so there is no product reason it should be an iPhone application. The reason it is one is that nobody has done the work.

The work is more than flipping a switch, and three specific things in the repository will not survive the port untouched.

**The camera is found by an Apple name.** `app/camera_feed_view.gd` locates a camera by matching the literal strings `"Front Camera"` and `"Back Camera"`. That was a correct and deliberate decision: the camera probe found **eight feeds on a single iPhone**, including the fused Dual, Dual Wide, Triple and TrueDepth virtual cameras, several of which report themselves as front-facing. Choosing the first front-facing feed would have worked on the handset in hand and handed back the TrueDepth camera on a handset that enumerates differently, so the file chooses by name and its comments say why. On Android there are no such names. The engine's Android backend, `modules/camera/camera_android.cpp`, identifies cameras by their Camera2 identifier, and every diagnostic string in the shipped Android library takes the form `Camera %s` with a bare identifier such as `0` or `1` substituted in. The strings `"Front Camera"` and `"Back Camera"` do not appear in that library at all. The name match does not pick the wrong camera on Android; it finds nothing, and the Jingle Cam screen comes up dead.

**The Android camera refuses to start until it is told what format to use.** The same library carries the error `CameraFeed format needs to be set before activating. Selected format index: %d (formats size: %d)`. The Android backend will not activate a feed whose format has not been chosen, and `set_format()` itself fails once a feed is already active, so the order is fixed and mandatory: pick a format, set it, then activate. The current code never calls `set_format()` at all, because on iOS it does not have to.

**Gravity points the opposite way.** The system design records that the engine reports the gravity vector in opposite directions on the two platforms, and names the two live copies of the iOS-shaped mapping so that whoever fixes one finds the other: `snow/snow.gd`, which steers the snowfall, and `app/phone_tilt.gd`, which the tilt sway and tilt drift behaviours read through. Left alone on Android, the snow falls upward and the red tree leans the wrong way. The shake detector itself works on linear acceleration, where the difference cancels when gravity is subtracted, which is why the detector was built on that quantity and nothing else, but that reasoning has never been checked against a handset.

Beyond the code, the delivery machinery does not exist. The export presets file carries an Android preset, but it is Godot's skeleton: the package name still holds the `$genname` placeholder, the version name is empty, there are no launcher icons, no splash, no export path, and the Gradle build is switched off. There is no signing key of any kind. The Richmond Symphony's Google Play organization account is created and validated but holds no application yet.

One further constraint shapes the whole feature. The Jingle Cam screen hands its photograph to the phone's share sheet through `addons/SharePlugin`, which ships an Android archive alongside its iOS framework. An Android archive can only be packaged by a custom Gradle build rather than by Godot's pre-built template, and that is what pulls in the Java Development Kit (JDK), the Android Software Development Kit (SDK) platform, and the in-project build template. Shipping the Jingle Cam on Android and standing up a Gradle build are therefore the same decision, taken deliberately: the Android build carries everything the iPhone build carries, not a reduced version of it.

The iPhone build's behaviour does not change, and that is a requirement of this feature rather than a hope. There is one deliberate exception, and it is a correction rather than a change of behaviour: two of the iPhone's permission descriptions are wrong today. One names an application that does not exist and claims the application stores photographs in the photo library, which it does not do, and the other contains an editing error that reads as broken English. Both are shown verbatim to an audience member and read by an Apple reviewer, and both contradict the privacy policy this feature drafts, so both are fixed here.

## Value Delivered

- **Twice the audience can play.** Roughly half the phones in the hall run Android, and today every one of them is locked out of the moment the application exists to create.
- **The same experience, not a lesser one.** Bell selection, the shake instrument, the snow, the fun facts, and the Jingle Cam all ship on Android. There is no cut-down Android edition to explain or apologize for.
- **A second store, and a faster one.** The Play Store's internal testing track publishes with no review wait, so Android testers can be holding the application while the Apple review queue is still moving.
- **The iPhone build is proven, not assumed, to be untouched.** Every platform difference is answered behind an explicit check, and an iPhone regression pass is a completion criterion rather than an afterthought.
- **The gravity question is finally settled with a measurement.** A doubt recorded in the system design since the project began is replaced with a reading taken off real hardware and archived beside the existing motion data.
- **The Symphony gets a privacy policy it can actually publish.** Drafted against Google's stated requirements and written to cover the microphone and video capture that are coming, so the same document does not have to be renegotiated at the next release.
- **The toolchain is written down.** The Android setup becomes a reproducible list of commands rather than an afternoon somebody has to repeat from memory on the next machine.

## Terms

- **Android Application Bundle (AAB).** The publishing format the Play Store requires. Google generates the per-device installable packages from it, so an application bundle is uploaded rather than an installable package.
- **Gradle build.** Android's build system. Godot can either export using a pre-built template package or run a real Gradle build from source installed into the project. Only the second can package a plugin's Android archive.
- **Android archive (AAR).** The packaging format for an Android library, which is how the share plugin ships its Android half.
- **Camera2.** Android's camera application programming interface, which the engine's Android camera backend is built on. It identifies cameras by short numeric identifiers rather than by human-readable names.
- **Feed.** One camera as the engine presents it, which is not the same as one lens. A single iPhone offers eight feeds across four lenses.
- **Upload key and Play App Signing.** The Play Store holds the key that signs what users install. The developer holds a separate upload key, used only to prove that an uploaded bundle is genuinely theirs. Losing the upload key is recoverable; it is not the key users' installations depend on.
- **Internal testing track.** The Play Store release channel that publishes to a named list of testers with no review wait.
- **Minimum and target Software Development Kit (SDK) level.** The oldest Android version the application will install on, and the Android version it declares itself built against. The Play Store enforces a floor on the second.
- **Android Debug Bridge (adb).** The command-line tool that talks to a tethered Android handset, used here to retrieve recorded sensor data.
- **Design pixels.** Positions and sizes expressed against the 1080 by 1920 reference canvas every screen in this application is drawn in, rather than against the physical screen.

## Requirements Summary

- **1. Stand up the Android development toolchain.** Install and record the Java Development Kit, Android Software Development Kit, and in-project build template the Android export needs.
- **2. Configure the Android export preset.** Give the skeleton preset its permanent package name, version, icons, permissions, and Gradle build setting.
- **3. Choose the camera by which way it points.** Replace the Apple-only name match with a position filter that works on both platforms, keeping the name as the iPhone's tie-breaker.
- **4. Tell the Android camera its format before starting it.** Choose and set a preview format, without which the Android camera refuses to activate.
- **5. Wait for the Android camera permission answer.** Handle Android's asynchronous permission grant so the camera works on the first launch, not only on later ones.
- **6. Mirror the selfie preview on Android.** Supply the horizontal flip that the Android backend, unlike the Apple one, does not apply.
- **7. Keep the snow falling down and the artwork leaning the right way.** Correct the gravity sign on Android in both places it is read, leaving the iPhone reading unchanged.
- **8. Hand the photograph to the Android share sheet.** Package and configure the share plugin's Android archive so the Jingle Cam's shutter works on Android.
- **9. Create and safeguard the Android signing keys.** Generate the debug and upload keys, enrol in Play App Signing, and record where the upload key lives.
- **10. Prove it on an Android handset.** Walk the whole audience flow on real hardware, take the gravity and shake readings, and archive them beside the existing motion data.
- **11. Prove the iPhone is unchanged.** Re-export and re-walk the iPhone build against the behaviour it has today.
- **12. Draft the privacy policy for the Symphony to publish.** Write a policy covering the camera now and the microphone and video capture that are coming, against Google's stated requirements.
- **13. Create the application in Play Console and release to internal testing.** Complete the declarations Google demands and get a signed bundle installable by invited testers.
- **14. Correct the iPhone's permission prompts.** Fix a permission description that claims something the application does not do, and a second that reads as broken English.

## Requirements

### 1. Stand up the Android development toolchain

The development machine gains everything the Android export needs, and the steps are recorded in the repository so they can be repeated on another machine without rediscovery.

Four things are required, and their versions are not a matter of preference. They are read from the Gradle configuration inside the `android_source.zip` that Godot 4.7.2 ships:

- **Java Development Kit 17.** The configuration declares `javaVersion: JavaVersion.VERSION_17`, the Android Gradle Plugin it pins is 8.6.1, and the Gradle wrapper is 8.11.1. A newer Java Development Kit is not an upgrade here; Gradle 8.11.1 predates support for Java 24 and 25 and fails outright rather than degrading.
- **Android Software Development Kit platform 36 and matching build tools.** The configuration declares `compileSdk: 36`, `minSdk: 24`, and `targetSdk: 36`.
- **The Godot Android build template**, installed into `res://android/` from within the editor.
- **The editor's own paths**, pointing at the Java Development Kit and the Android Software Development Kit.

The minimum Software Development Kit level of 24 is not to be lowered. The engine's Android camera backend is built on Camera2, which requires level 24, and lowering the floor removes the camera silently rather than with an error.

The generated build template is not committed. `android/build/` and `android/.build_version` are added to the ignore list, because the template is regenerated from the editor and is roughly two hundred megabytes of Gradle source. Anything hand-authored under `res://android/`, such as the plugin configuration requirement 8 adds, is committed.

### 2. Configure the Android export preset

The existing Android preset in `export_presets.cfg` is Godot's untouched skeleton and is filled in.

**The package name is `com.richmondsymphony.holidaysleighbells`**, all lowercase, which is both the Java package convention and Android's own guidance. This value is permanent: once a bundle carrying it has been uploaded to the Play Store, it can never be changed for the life of the application. It deliberately differs in casing from the iOS bundle identifier `com.richmondsymphony.holidaySleighBells`, which stays as it is.

The preset also gains a launcher label, launcher icons including the adaptive foreground and background layers Android requires, a splash screen consistent with the iPhone build's, and an export path under `exports/`. The architecture stays `arm64-v8a` alone, matching the existing preset and the iOS build.

`gradle_build/use_gradle_build` is switched **on**, which requirement 8 depends on. The export format is the Android Application Bundle, because that is what the Play Store accepts.

`permissions/camera` is already enabled in the preset and stays enabled. No other permission is added. The application makes no network request, so the network permissions stay off, and their absence is a claim the privacy policy in requirement 12 makes.

**Version numbering.** The version name matches the iPhone build's short version, so the two stores describe the same release with the same number. The version code is a plain integer that increments on every upload to the Play Store, independently of the version name, because the Play Store rejects a version code it has already seen.

### 3. Choose the camera by which way it points

`app/camera_feed_view.gd` currently finds a camera by matching the literal name `"Front Camera"` or `"Back Camera"`. That is replaced by a single selection path that works on both platforms, structured in two stages.

**The first stage is portable.** Feeds are filtered to those reporting the wanted position, `FEED_FRONT` or `FEED_BACK`. Position is the one concept both platforms express the same way.

**The second stage is the tie-breaker, and it is the only part that differs by platform.** On iOS, the wanted feed is selected from the filtered set by its name, `"Front Camera"` or `"Back Camera"` — exactly today's behaviour, preserved deliberately. The camera probe's finding that one iPhone offers eight feeds, several of them front-facing virtual cameras including TrueDepth, has not stopped being true, and a position filter alone would reintroduce the hazard the name match was written to close. On Android, the first feed of the filtered set is taken, since Camera2 enumerates the primary rear camera and the primary front camera as its first identifiers.

The existing constants `SELFIE_FEED_NAME` and `REAR_FEED_NAME` are retained and used as the iOS tie-breaker rather than deleted, and the comment block at the top of the file explaining the eight-feed finding is kept and extended rather than replaced.

A device that offers no feed matching the wanted position emits the existing `camera_unavailable` signal, which the Jingle Cam screen already handles. Nothing substitutes a different camera, in keeping with the repository's convention that a missing value fails with a message naming what is missing rather than falling back.

### 4. Tell the Android camera its format before starting it

Before a feed is activated on Android, a format is chosen from that feed's own format list and set on it. The order is fixed and cannot be varied: choose, set, then activate. `set_format()` returns false on a feed that is already active, and the Android backend refuses to activate a feed whose format has not been chosen, failing with `CameraFeed format needs to be set before activating`.

The format chosen is the one closest to what the screen actually needs rather than the largest the handset offers. The design canvas is 1080 pixels wide, the preview is drawn behind artwork, and the photograph is a capture of the viewport, so a preview substantially larger than the canvas costs frame time and memory and buys nothing visible. A phone will readily offer far more.

This step is skipped on iOS, where the Apple backend selects a format itself and the current code has never needed to. The check is one of the explicit platform branches this feature introduces.

### 5. Wait for the Android camera permission answer

Android's permission grant is asynchronous, and the engine's Android backend opens `activate_feed()` by requesting the camera permission and returning false immediately when it is not yet held. There is no retry inside the engine. Code that reads that false as "this device has no camera" gives a dead Jingle Cam screen on first launch and a working one on every launch afterwards.

The screen therefore requests the camera permission, waits for the answer, and only then activates a feed.

This sits alongside behaviour the file already has for a related but distinct iOS fault. `_await_activation` exists because the Apple backend starts its permission request and returns before it is answered, never marking the feed active afterwards, and it cures that by deactivating and reactivating until a picture arrives. That loop stays exactly as it is for iOS. The Android path is its own, using Android's permission-result signal rather than a retry loop, because Android reports its answer and iOS does not.

The existing `activation_timeout_seconds` behaviour is preserved on both platforms: after the timeout with no picture, `camera_unavailable` is emitted, since neither platform can distinguish a person who has declined from one who has not yet answered.

### 6. Mirror the selfie preview on Android

The Android backend applies rotation to a feed, combining the hardware's sensor orientation, the current display rotation, and which way the lens faces, but it does **not** apply a horizontal flip to a front-facing camera. An unmirrored selfie preview feels wrong to anyone who has used a phone camera.

The existing `_apply_mirror` behaviour therefore applies on Android as it does on iOS, including its rule about which axis to flip depending on how far the picture has been turned, so that a mirrored preview never stands the person on their head.

The mirror stays confined to the camera layer, as it is today. Mirroring the composed screen would reverse the hand-drawn lettering and the Richmond Symphony's name in every photograph, which is the reason the mirror was put on the camera layer in the first place.

### 7. Keep the snow falling down and the artwork leaning the right way

The gravity vector is reported in opposite directions on the two platforms. The iOS-shaped mapping is read in two places, named together in the system design so that whoever fixes one finds the other:

- `app/phone_tilt.gd`, which the tilt sway and tilt drift artwork behaviours read through.
- `snow/snow.gd`, which carries its own copy of the same mapping and steers the falling snow.

Both are corrected so that on Android the snow falls downward and the artwork leans in the same direction it leans on an iPhone. **The iPhone reading is unchanged**, and the correction is applied behind an explicit platform check so that the iPhone path is provably the path it is today.

The true sign is established by measurement on the handset rather than assumed from documentation, and recorded so the next person does not repeat the measurement.

The shake detector is expected to need no change, because it works on linear acceleration, where the platform difference cancels when gravity is subtracted, and that is the reason it was built on that quantity. That expectation is **verified on the handset** under requirement 10 rather than taken on trust, since it has never been checked against Android hardware.

### 8. Hand the photograph to the Android share sheet

The Jingle Cam's shutter writes the photograph to `user://jingle_cam.png` and hands it to the phone's share sheet through `addons/SharePlugin`. The plugin already carries its Android archives, `SharePlugin-debug.aar` and `SharePlugin-release.aar`, but nothing configures them: only the iOS plugin definition at `ios/plugins/SharePlugin.gdip` exists, and there is no Android equivalent anywhere in the repository.

The Android plugin configuration is added under `res://android/plugins/`, naming the archives and any dependencies the plugin declares, and is committed. Packaging it is what the Gradle build enabled in requirement 2 is for.

The photograph's location is reviewed for Android. On iOS, `user://` resolves to the application's Documents directory, and the export preset opens that directory to the Files application, so a photograph survives a dismissed share sheet and remains retrievable. On Android, `user://` is application-private storage that the person cannot browse. This changes nothing about how the share sheet is invoked, and the file continues to be written before sharing, but the comment in `app/jingle_cam.gd` that explains the choice in iOS terms is corrected so it does not assert something untrue of Android.

### 9. Create and safeguard the Android signing keys

Two keys are needed and they are not the same thing.

The **debug key** signs builds installed directly on a tethered handset during development. Godot's editor settings already point at a debug keystore path, and this is the one that requires no ceremony.

The **upload key** signs the bundle uploaded to the Play Store. The Symphony's Play account enrols in **Play App Signing**, under which Google holds the key that signs what users actually install and the upload key serves only to prove an upload is genuine. This matters for a volunteer-supported organization: an upload key that is lost can be reset by Google, whereas a lost application signing key outside Play App Signing would end the ability to update the application at all.

The upload keystore, its passwords, and its alias are **not committed to the repository**. Where the keystore lives and who else holds a copy is recorded, because a key held by exactly one person on exactly one laptop is a single point of failure for a Symphony application. The keystore path is supplied to the export preset by a method that keeps the secret out of version control.

### 10. Prove it on an Android handset

The application is walked end to end on a real Android handset. The system design's testing position is unchanged by this feature: there is no test framework, verification is manual and performed on hardware, and the parts most worth testing are precisely the parts that only exist on a device. Sensors and cameras return nothing in the editor, the desktop build, or an emulator.

The walk covers the full audience flow — title, instructions, bell selection with its carousel and fun facts, and the play screen — plus the shake instrument sounding each of the three bells across its dynamic range, the snow, the artwork tilt behaviours, and the Jingle Cam through preview, camera switch, shutter, and share sheet.

Two measurements are taken and archived rather than merely observed:

- **The gravity sign**, which requirement 7 depends on.
- **A set of shake recordings**, made with the capture harness in `capture/`, confirming that the detector's measured constants hold on Android hardware. This is the first time the shake instrument has run on the platform at all.

Recordings are retrieved with the Android Debug Bridge, needing no code, and archived in a new `Android/` folder under `features/data/C1_09/`, which is the structure that directory's own guidance already prescribes for a new device. The handset's model, Android version, and achieved sample rate are recorded with them, since the existing data is organised by device precisely because the same motion produces different numbers on different hardware.

Reaching the capture harness means pointing `run/main_scene` at it, and **restoring the title screen afterwards is a completion criterion of this feature**, as it is of any feature that changes that setting.

### 11. Prove the iPhone is unchanged

The iPhone build is re-exported and walked through the same flow as requirement 10, and compared against the behaviour it has today.

This is a requirement rather than an assumption because this feature edits files the iPhone build depends on: `app/camera_feed_view.gd`, `app/phone_tilt.gd`, `snow/snow.gd`, and `app/jingle_cam.gd`. Every one of them is load-bearing on iOS.

The check covers the camera selecting the correct lens on a handset offering many feeds, the first-launch permission behaviour that `_await_activation` exists to cure, the selfie mirror, the snow direction, the artwork tilt, the shake instrument, and the share sheet.

The iOS export preset is modified by exactly one requirement, requirement 14, and by nothing else. Every other value in it — the bundle identifier, the team identifier, the signing settings, the plugin and camera module switches, and the additional property list content — is confirmed unchanged.

### 12. Draft the privacy policy for the Symphony to publish

A privacy policy is drafted for the Richmond Symphony to publish on `richmondsymphony.com`, and the draft is a deliverable of this feature rather than a follow-on.

Google requires a privacy policy link for every application, and the camera permission makes it unambiguous. The Symphony's existing policy describes the website and ticketing and says nothing about an application or a camera; a policy that does not describe the application's actual behaviour is a rejection risk at review. The draft is therefore written as a new page for this application, to be linked from the existing policy rather than to replace it.

**The policy covers the microphone and video capture as forthcoming**, not only the camera as it stands today. Video recording is a planned enhancement, and an undisclosed microphone is treated by Google as a serious violation. Naming it now costs a sentence; adding it later costs a further review cycle and a fresh conversation with the Symphony.

The draft states plainly what is true of this application: it collects nothing, transmits nothing, contains no analytics and no advertising, makes no network request, requires no account, and shares nothing with third parties. The camera is used on the device only, a photograph is written to the device, and it leaves the phone only when the person chooses to share it themselves. The draft also carries the contact point and effective date that Google's requirements call for, and the disclosures needed to complete the Play Console data safety declaration, so that the published page and the declaration agree with each other.

The draft is written for the Symphony's review and publication. Publishing it is the Symphony's action, not this feature's.

### 13. Create the application in Play Console and release to internal testing

The application is created in the Richmond Symphony's Google Play organization account, which is already created and validated but holds no application yet, and a signed Android Application Bundle is released to the **internal testing track**.

The internal testing track is the target because it publishes with no review wait, which makes it the Android counterpart of the TestFlight release task (`C1_T01`) rather than of the App Store release task (`C1_T02`).

Google requires the application content declarations to be complete before **any** release, internal included. These are part of this feature: the privacy policy link from requirement 12, the content rating questionnaire, the data safety form, the target audience and content declaration, the advertising declaration (the application carries none), and the application access declaration (no account or login is required to use any part of it). The store listing itself is completed to the minimum the internal track demands.

Because the Symphony holds an **organization** account rather than a personal one, the requirement that new personal accounts run a twelve-tester, fourteen-day closed test before production does not apply. This is recorded because it materially shortens the path from this feature to a public release.

**The target audience declaration is a decision to be taken deliberately rather than a form field to be filled in passing.** Google states that an application not primarily designed for children under thirteen, whose listing carries marketing elements suggesting otherwise — it names youthful animation and young characters specifically — may be rejected, and that Google reserves the right to conduct its own review of the declared audience. Holiday Sleigh Bells is hand-drawn cartoon artwork with a named character, and it is handed out at a family concert. Declaring thirteen and over may therefore draw a challenge; declaring an audience that includes children brings the application under Google Play's Families policy.

The application already satisfies most of what that policy asks, because it carries no advertising, no analytics, and no data collection of any kind, so neither answer is blocked. The declaration is made with the Symphony rather than chosen by the developer, and whichever is chosen, the answer and its reasoning are recorded so a later reviewer's challenge can be answered from the record rather than re-argued.

A full production store listing — feature graphic, screenshots, full description, and production rollout — is **not** part of this feature. It is named in Future work.

### 14. Correct the iPhone's permission prompts

Two of the iOS permission descriptions in `export_presets.cfg` are wrong, and both are read by an Apple reviewer and shown verbatim to an audience member in the system permission prompt.

**The photo library description claims behaviour the application does not have.** It reads `Symphony Sleigh Bells stores stylized user photos in their Photos library`. Two things are wrong with it. The application is called Holiday Sleigh Bells, not Symphony Sleigh Bells. And the application does not write to the photo library at all: `app/jingle_cam.gd` saves the photograph to `user://jingle_cam.png` and hands that file to the share sheet, so a photograph reaches the photo library only if the person chooses the Photos application from the share sheet themselves. The description is therefore removed, since the application does not use the permission it describes. Declaring a permission that is never exercised is a rejection risk in its own right, and describing behaviour the application does not have is worse.

**The camera description reads as broken English.** It reads `Holiday Sleigh Bells uses the camera so you can take a stylized photo of yourself with during the concert`, where "with during" is left over from an edit. It is rewritten as a clean sentence that states plainly what the camera is for.

Both corrections are also a consistency matter rather than only a tidiness one. The privacy policy drafted in requirement 12 states that photographs are saved to the person's own device and leave it only when the person chooses to share them. A permission description asserting that the application stores photographs in the photo library contradicts the policy, and Apple and Google both require an application's stated behaviour and its policy to agree.

This is the only requirement in this feature that modifies the iOS export preset, and requirement 11 confirms that nothing else in that file changes.

## Token and design considerations

This feature builds no skill, so there is no skill token cost to account for.

## Teaching topic

**Topic: the Android build and release toolchain.** The competency it grants is the ability to take this repository from a clean machine to a signed Android Application Bundle in the Play Store without rediscovering the toolchain: which Java Development Kit version the installed Godot pins and why a newer one fails, how to read the required Software Development Kit, build tools, and Android Gradle Plugin versions out of `android_source.zip` rather than guessing them, why the Android build needs a Gradle build at all rather than the pre-built template, the difference between the upload key and the application signing key under Play App Signing, and which declarations the Play Console demands before even an internal release will publish.

This is a genuine teaching topic where the Tap to Choose Your Bell feature (C1_19) had none, because this feature changes the developer's environment and workflow rather than what an audience member does on a screen. Every one of the facts above cost time to establish during ideation, and several of them are the kind that are re-derived painfully rather than remembered — the Java Development Kit version pin in particular, where the newest release is the wrong answer.

## Future work

**A full production release to the Play Store.** This feature ends at the internal testing track. A production release additionally needs the complete store listing — a 512 by 512 icon, a 1024 by 500 feature graphic, screenshots, and the full description — together with the Symphony having actually published the privacy policy drafted in requirement 12. Because the Symphony holds an organization account, production can be reached directly from internal testing without an intervening closed test.

**Microphone and video capture in the Jingle Cam.** The privacy policy drafted in requirement 12 discloses these ahead of their being built, so that the feature which builds them does not require the policy to be renegotiated with the Symphony and re-reviewed by Google.

**Android on the roadmap.** Android does not appear in `features/mvp1_roadmap.md` at all, as either a feature or a task, and the two delivery tasks it does carry are both Apple channels. Reconciling the roadmap with a two-platform delivery is Gill's work, done when the developer asks for it.
