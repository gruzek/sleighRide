---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: A Photo the Audience Takes Home
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Turns a concert moment into something an audience member can send to somebody before the interval, carrying the Richmond Symphony's artwork with it.
LAST UPDATED: August, 23, 2026 09:36
---

# A Photo the Audience Takes Home

## Summary

The Jingle Cam feature (C1_16) adds a fifth screen to the audience flow: a camera screen reached from the bell-selection screen by a red "JINGLE CAM" button in the bottom right corner. The screen shows the phone's live camera behind the season's holiday artwork — the Richmond Symphony logo, the red tree, the blue snowflake with its green halo, the conductor illustration, and the "LET IT SNOW! 2026" lettering — and a press of the button at the bottom takes a photograph of the whole composition and hands it to the phone's own share sheet. The screen opens on the selfie camera, and a switch-camera button changes to the camera on the back of the phone and back again. The camera image is mirrored so the photograph matches what the person framed; the artwork over it never is.

## Background

The audience flow is four screens — title, instructions, bell selection, play — and every one of them is something the audience member looks at rather than something they keep. The application's whole reach into the evening ends when the performance of "Sleigh Ride" ends. Nothing an audience member does in it produces anything they still have the next morning, and nothing in it travels to a person who was not in the hall.

The camera screens have been in the design from the beginning and have been deferred twice. Christopher's Richmond Symphony 2026-27 Season Design System file drew two of them. The Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience feature (C1_T05) removed them from its scope entirely and recorded why: at that time the application was aimed at the web, where the Godot engine has no camera implementation at all and every known camera defect on iPhone is specific to the presentation mode that mockup had adopted. That direction was reversed and the application is a native build, but the engine still had no iOS camera implementation of its own as recently as version 4.6 — the camera module was compiled for macOS, Windows, Linux, and Android, and not for iOS.

That changed with the upgrade to Godot 4.7.2. The camera module now builds for iOS, and a camera feed is an ordinary texture that a scene can place behind other artwork. The research behind this is recorded in `features/jingle_jam_cam_camera_exploration.md`. The consequence for this feature is that the camera is not a foreign object bolted onto the application: it is one more layer in the same viewport as everything else, drawn behind the artwork by the same ordering rule that already puts the vignette behind the buttons and the snow in front of the background. The photograph is therefore a capture of the viewport, already composited, with no assembly step of any kind.

Two capabilities visible in the supplied design are deliberately not built here and are detailed in Future work: video recording, and the camera on a phone running Android.

## Value Delivered

- **The evening leaves the hall.** An audience member walks out with a photograph of themselves inside the Richmond Symphony's own artwork, which is the first thing this application has ever produced that outlasts the performance.
- **The Symphony's artwork travels with it.** Every photograph carries the logo, the season's lettering, and the conductor illustration into a text message or a social feed, reaching people who were never in the room.
- **A reason to open the application before the music starts.** The audience arrives, sits, and waits; a camera screen gives them something to do in that gap that is still about the concert they came for.
- **A keepsake, not a file.** The photograph goes to the phone's own share sheet, so it reaches whoever the person came with in the same gesture that saves it — rather than landing in a folder nobody opens again.
- **The next screen is cheap.** The camera arrives as one more layer in a viewport the application already composes, so the artwork, the placement system, and the safe-area handling all work exactly as they already do.

## Terms

- **Selfie camera.** The camera on the same side of the phone as the screen, which points at the person holding it. This is the camera the screen opens on.
- **Camera feed.** The engine's live connection to one physical camera. The phone offers one feed per camera it has.
- **Mirroring.** Flipping an image left-to-right, so that raising your right hand raises the hand on the right of the picture, the way a bathroom mirror behaves.
- **Share sheet.** The panel the phone raises when an application hands it something to share, offering Save Image, Messages, Mail, and whatever else the person has installed.
- **Safe area.** The region of a phone screen not covered by the status bar, the camera notch or Dynamic Island, or the home indicator.
- **Design canvas.** The 1080 by 1920 reference frame every screen in this application is composed against, which the engine expands rather than stretches on a taller phone.

## Requirements Summary

- **1. Reach the Jingle Cam from the bell-selection screen.** A red "JINGLE CAM" button in the bottom right corner opens the camera screen.
- **2. Show the live camera behind the holiday artwork.** The camera fills the screen and the season's artwork is composed over it.
- **3. Open on the selfie camera.** The screen comes up pointing at the person holding the phone.
- **4. Switch between the two cameras.** A button carrying the supplied switch-camera icon changes to the camera on the back of the phone, and back again.
- **5. Mirror the selfie, never the artwork.** The camera image is flipped so the photograph matches what the person framed; the lettering and the logo over it are never flipped.
- **6. Take the photograph with one press.** The button at the bottom of the screen captures the whole composition as a single image.
- **7. Keep the controls out of the photograph.** No button on the screen appears in the captured image.
- **8. Hand the photograph to the phone's share sheet.** The person saves it or sends it from the phone's own panel.
- **9. Offer the Jingle Cam only when there is a camera to offer.** Where the phone reports no camera, no button appears anywhere.
- **10. Leave the screen when camera access is declined.** A person who declines the permission is returned to the bell-selection screen, where the button is now gone.
- **11. Leave the screen by choice.** A back control returns to the bell-selection screen with nothing captured.
- **12. Keep the artwork alive and the weather out.** The tree, snowflake, and halo move as they do elsewhere; no snow falls on this screen.

## Requirements

### 1. Reach the Jingle Cam from the bell-selection screen

The bell-selection screen, `app/instrument_select.tscn`, gains a red button reading "JINGLE CAM" in the bottom right corner of the screen. Pressing it opens the Jingle Cam screen.

The button sits alongside the screen's existing "Continue" control rather than replacing it, so the path forward into the performance is never obstructed by the path sideways into the camera. It is red, matching the pressed state already defined on that screen's buttons, which distinguishes it from the blue "Continue" and marks it as a different kind of action rather than a step in the sequence.

Like every bottom-anchored control in this application, it is held clear of the home indicator, because Godot's own anchoring measures from the physical edge of the window and knows nothing about the safe area.

### 2. Show the live camera behind the holiday artwork

The Jingle Cam screen fills with the live camera image, and the season's artwork is composed over it. The artwork is, from the top of the screen down: the Richmond Symphony logo, the red tree entering from the left, the blue snowflake with its green halo entering from the right, the "LET IT SNOW! 2026" lettering at the lower left, and the conductor illustration standing at the lower right.

The camera image is the backmost layer on the screen, behind everything. The artwork is composed over it using the same placement mechanism every other screen uses, so each piece is positioned against the 1080 by 1920 design canvas and declares for itself whether it is anchored to the physical edge of the screen or to the safe area. Pieces that run past the edge of the screen — the tree, the snowflake — anchor to the edge; the logo anchors to the safe area so it is never under the Dynamic Island.

Four of these pieces already exist in the repository as scenes or artwork and are instanced rather than rebuilt: the logo as `app/title.tscn`, the tree as `app/straight_red_tree.tscn`, the snowflake and halo as `app/blue_snowflake.tscn`, and the conductor as `images/v2/valentina.svg`, which is present in the repository and currently used by no scene. The "LET IT SNOW! 2026" lettering is supplied separately as artwork and dropped in as a mechanical substitution.

The camera image fills the screen rather than being letterboxed inside it. Where the camera's own proportions do not match the phone's screen, the image is scaled to cover and the overflow is cropped, so no band of background is ever visible behind the artwork.

### 3. Open on the selfie camera

The screen comes up showing the camera on the same side of the phone as the screen, pointing at the person holding it. This is the expected shot and the one the design is composed for: the conductor illustration stands at the lower right of the frame as though beside the person, which only reads correctly when there is a person in the frame.

No interaction is required to reach this state. The screen opens, the selfie camera is live, and the person is looking at themselves inside the artwork.

### 4. Switch between the two cameras

A button carrying the supplied switch-camera icon changes the screen from the selfie camera to the camera on the back of the phone, and pressing it again changes back. It toggles in both directions from the same control, because a person who turns the camera around to photograph the stage needs a way back to their own face.

The icon is the supplied Material Symbols cameraswitch artwork, white, and the button sits in a bottom corner of the screen where a thumb already rests, clear of the safe area at the bottom.

Where the phone offers only one camera, this button does not appear at all. This follows the same rule as requirement 9: a control that cannot do anything is not drawn.

### 5. Mirror the selfie, never the artwork

The selfie camera image is mirrored left-to-right, both in what the person sees while framing and in the photograph that is taken, so that the photograph matches what they composed. A person who tilts their head to the left sees the head tilt to the left, and the saved photograph agrees.

**The artwork over the camera is never mirrored, under any circumstances.** The "LET IT SNOW! 2026" lettering, the Richmond Symphony logo, and the conductor illustration must read correctly in every photograph this feature produces. This is the reason the mirroring is applied to the camera layer alone and never to the screen as a whole: flipping the composed image would reverse the lettering and produce a photograph carrying the Symphony's name backwards.

The camera on the back of the phone is not mirrored, in the preview or in the photograph, because a person pointing it away from themselves is photographing the world as they see it rather than as a mirror shows it.

The known consequence, accepted deliberately: writing that happens to be in a selfie — a programme, a t-shirt — reads backwards in the saved photograph. This is the ordinary behaviour of a selfie and is preferred to a photograph that does not match the framing.

### 6. Take the photograph with one press

A button at the bottom centre of the screen, styled as the red control in the supplied design, takes a photograph when pressed. One press produces one photograph of the entire composition — the camera image and every piece of artwork over it — as a single image, exactly as it appeared on screen.

The button reads "Press to Snap". The supplied design labels it "Press to Record", which describes a video; this feature takes a photograph, and the label says so.

Nothing is assembled after the fact. The camera and the artwork are already drawn together in one viewport, so the photograph is a capture of that viewport and the layering in the file is by construction the layering on the screen.

### 7. Keep the controls out of the photograph

No control drawn on the Jingle Cam screen appears in the captured image. The shutter button, the switch-camera button, and the back control are all absent from every photograph this feature produces.

This is a requirement rather than a detail because the photograph is a capture of the screen, and the controls are on the screen. Capturing naively produces a picture of the artwork with a red button across the bottom of it and a back arrow in the corner — permanently, in the file the person keeps and sends.

The artwork is not affected. Every piece named in requirement 2 appears in the photograph; only the controls are withheld.

### 8. Hand the photograph to the phone's share sheet

Once taken, the photograph is handed to the phone's own share sheet, from which the person saves it to their photographs, sends it in a message, or posts it wherever they like.

The share sheet is the destination rather than a silent save because it is the same gesture in both directions: the person who wants to keep the photograph taps Save Image, and the person who wants to send it to whoever they came with does so without leaving the application. A photograph saved silently is a photograph nobody looks at again, which forfeits the value in the fourth bullet of Value Delivered.

The phone asks for permission the first time a photograph is saved to the photograph library, so the application declares in plain language why it wants that access, as it does for the camera in requirement 10.

### 9. Offer the Jingle Cam only when there is a camera to offer

Where the phone reports no camera, the "JINGLE CAM" button does not appear on the bell-selection screen, and the Jingle Cam screen is unreachable. No message is shown, no disabled control is drawn, and nothing explains the absence.

The rule is: **no camera, no button, no screen.** A control that leads somewhere broken is worse than no control, and an audience member in a dark hall minutes before a performance is not an audience for an error message about hardware.

This requirement also covers the two cases where the application runs with no camera as a matter of course — in the Godot editor and in the iOS Simulator — in exactly the same way it covers a phone with no camera. This mirrors the way the application already treats the motion sensors, which return a zero vector everywhere but a real handset. Nothing about this screen can be meaningfully exercised anywhere but on a phone, and nothing about it breaks anywhere else.

### 10. Leave the screen when camera access is declined

The phone asks for camera permission when the application first turns a camera on, which happens when the Jingle Cam screen opens. A person who declines is returned immediately to the bell-selection screen, where the "JINGLE CAM" button is now gone.

This keeps one rule instead of two. Requirement 9 says the button is drawn only when a camera is available; a declined permission makes the camera unavailable, so the button is not drawn, and the person is not left looking at artwork with a hole where their face should be. The state is consistent the moment they arrive back.

The permission prompt carries a sentence the application supplies, explaining why the camera is wanted. That sentence is written for the audience member rather than for the developer, because it is the only explanation they will ever be given and because a vague one is a documented reason for rejection at App Store review.

Permission is asked for on this screen and not earlier in the flow. Asking an audience member for camera access before they have seen anything that explains why is how a decline is produced.

### 11. Leave the screen by choice

A back control returns from the Jingle Cam screen to the bell-selection screen, taking no photograph and keeping none.

It sits in the bottom corner opposite the switch-camera button of requirement 4, with the shutter button of requirement 6 centred between the two. This is the ordinary arrangement of a camera application: the shutter in the middle where it is found without looking, and the two secondary controls under the thumbs. Both corner controls are held clear of the home indicator.

The Godot application on iOS has no reliable system back gesture, so this control is the only way off the screen and is not optional.

### 12. Keep the artwork alive and the weather out

The tree, the snowflake, and the green halo move on this screen as they do on the title screen — the tree swaying with the tilt of the phone, the snowflake turning slowly on its own, the halo sliding as the phone tilts. This costs nothing to obtain: the Artwork That Answers the Tilt of the Phone feature (C1_15) placed those behaviours inside the artwork scenes themselves, so instancing the scenes brings the motion with them.

**No snow falls on this screen.** Every other screen in the flow carries the falling snow from the Snow That Falls the Way the Phone Is Held feature (C1_12), and this one deliberately does not. Snow drifting across a person's face reads as dirt on the lens, and unlike everything else on the screen it would be captured into the photograph permanently, in a different arrangement in every shot.

## Token and design considerations

This feature builds no skill. It adds one screen, one button on an existing screen, and a small number of scenes and scripts to a Godot application, so there is no prompt to size, nothing loaded into a model's context, and no per-run cost to account for.

## Teaching topic

**Topic:** how a camera becomes a layer in a Godot scene. **Competency:** a developer who can explain why the photograph in this feature needs no compositing step — that the camera feed is a texture in the same viewport as the artwork, that the ordering on screen is therefore the ordering in the file, and that this is the same layering rule already governing the vignette, the snow, and the buttons — can extend this screen without reintroducing an assembly step that the architecture does not need.

## Future work

**Video recording.** The supplied design labels the shutter "Press to Record", and a moving Jingle Cam is the natural next reach. It is a substantially larger feature than this one and not a variation on it: the Godot engine's own movie writer renders offline rather than capturing a running application, so recording the screen on a phone means either capturing and encoding every frame, which a handset will not sustain alongside a live camera and moving artwork, or reaching Apple's ReplayKit through a plugin that does not yet exist for this engine version. A future feature should settle which, and budget for device testing rather than desk research.

**The camera on Android.** The Godot engine has had a camera on Android since version 4.5, longer than it has had one on iOS, so this screen is available on that platform for less work than it took here. What is not available is anything else: the repository has no Android export preset at all, no Android build has ever been made, and no Android handset has been measured for the motion sensors the rest of the application depends on. A future feature that brings the Jingle Cam to Android is really a feature that brings the application to Android.

**The information overlay and the fun-fact bubble.** The supplied design of the bell-selection screen shows an information button in the top right corner and a "Did you know?" bubble beside Winnie, neither of which is built and neither of which is part of this feature. The bubble was already deferred once by the Instrument Carousel feature (C1_08), which established the instrument resource that its content would hang from if it ever varies by bell.
