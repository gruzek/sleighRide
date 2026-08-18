---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Puts Christopher's design in the sponsor's hand as a real app on a real phone, and proves the whole audience experience can be delivered without an app store.
LAST UPDATED: August, 3, 2026 15:51
---

# Single-Page App Mockup of the Holiday Sleigh Bells Audience Experience

## Summary

This feature builds a five-screen mockup of the Holiday Sleigh Bells audience app as a single-page application (SPA) in Godot, exported for the web and installable to a phone's home screen. It realizes the flow Christopher drew in the RS 2026-27 Season Design System file: a welcome screen, an instructions screen, a bell-selection screen, and a play screen, plus an information overlay. Tap is the only wired interaction; tapping the play screen sounds a bell and animates the instrument. The motion-driven bell physics built for the native prototype are retired for this build, and the two camera screens in the design are removed from scope entirely.

## Background

The Holiday Sleigh Bells app exists today as a native iOS prototype: one screen, a "Tap to Start" overlay, and a set of loose bells that tumble under the phone's accelerometer and gravity sensors. At the 2026-08-03 sponsor meeting the direction changed. The app is now aiming at a single-page application delivered through the web rather than a native iOS build, tap replaces shake as the lead interaction, and a mockup of the finished experience is the next visible deliverable, due before the 2026-09-02 sponsor meeting.

Two things make this more than a port. First, there is no concept of a screen in the current build: the entire application flow is a pause overlay that hides itself when pressed, so a multi-screen experience has nothing to build on. Second, Christopher's design is not the current app. It replaces the placeholder art and typography with real Richmond Symphony brand assets, and its play screen shows a single large instrument rather than a box of tumbling bells. The accelerometer-driven force model that drives those bells has no input at all once motion sensors are removed, so it does not survive into this build.

Three capabilities visible in the design or the roadmap are deliberately excluded here and are detailed in Future work: the Jingle Jam Cam camera screens, shake-to-jingle, and the professionally recorded bell audio.

## Value Delivered

- **A real app in the sponsor's hand.** The sponsor can install the mockup on their own phone from a link and see the designed experience running full-screen with no browser address bar, which is the question the SPA direction has been gated on.
- **Proof the web path is viable.** A working installed build settles whether the audience app can be delivered without an app store, and therefore whether App Store review lead time still constrains the November concert.
- **Christopher's design made real.** The design moves from a static Figma board to something the room can hold and tap, which is a far better basis for the remaining look-and-feel decisions than a screen share.
- **A foundation the remaining features attach to.** The screen flow, the tap interaction, and the installable shell are the scaffolding every stretch feature would later plug into.

## Terms

- **Single-page application (SPA).** A web application that loads once and changes what it displays without navigating to new web pages. Here, the entire Godot export is the single page.
- **Progressive web app (PWA).** A web application packaged so a phone can install it to the home screen and launch it like an installed app.
- **Standalone display mode.** The presentation a progressive web app gets when launched from the home screen: no address bar and no browser toolbar, with its own entry in the phone's app switcher.
- **Safe area.** The region of a phone screen not covered by the status bar, the camera notch or Dynamic Island, or the home indicator.
- **Jingle Jam Cam.** The two camera-and-record screens in Christopher's design, excluded from this feature.

## Requirements Summary

- **1. Move through the experience one screen at a time.** A screen flow that presents five distinct screens in order and lets the audience member move forward through them.
- **2. Open on a welcome screen that invites a tap.** The branded opening screen with the title treatment and a single call to action.
- **3. Tell the audience member what to do before the music starts.** The instructions screen, with its wording corrected to describe tapping rather than shaking.
- **4. Let the audience member choose which bell to play.** The selection screen with three bells, a swipe between them, and the fun-fact bubble.
- **5. Sound a bell when the screen is tapped.** The play screen, where a tap anywhere sounds a randomly chosen recording for the chosen bell and animates the instrument.
- **6. Offer more information without leaving the bell.** The information overlay opened from the icon on the play screen.
- **7. Retire the motion-driven bell physics for this build.** The accelerometer and gravity force model is taken out of the delivered experience.
- **8. Present as a real app on the phone, and still work in a browser tab.** Installable to the home screen in standalone display mode, degrading gracefully when opened as an ordinary web page.
- **9. Fit any phone screen in portrait, clear of the notch and home indicator.** Portrait layout that respects the safe area on every screen.
- **10. Drop in the real brand assets when they arrive.** The build is structured so supplied artwork, typography, colour, and copy replace placeholders without rework.

## Requirements

### 1. Move through the experience one screen at a time

The mockup presents five screens: Welcome, Instructions, Instrument Select, Instrument, and an Information overlay. A screen flow shows exactly one screen at a time and advances forward when the audience member acts: the welcome screen's call to action leads to instructions, the instructions screen's continue action leads to bell selection, and the bell selection screen's confirm action leads to the play screen. The information overlay is not a destination in this sequence; it is covered by requirement 6.

Nothing in the current build provides this. The application flow today consists of a single overlay that pauses the scene tree on load and hides itself when its button is pressed, so the screen flow is new work rather than a modification.

Backward navigation between the four sequential screens is not required. The audience member moves forward through the flow once, at the start of the concert.

### 2. Open on a welcome screen that invites a tap

The first screen presents the Richmond Symphony identity, the "Holiday Sleigh Bells" title treatment with its per-word colouring, the seasonal background composition, the mascot illustration, and a single prominent call-to-action control that advances to the instructions screen. This screen is the audience member's first impression and carries the strongest branding in the flow.

### 3. Tell the audience member what to do before the music starts

The second screen presents the short list of instructions from the design, covering turning up the volume, holding the phone securely, how to play, and waiting for the conductor's cue, with the conductor's cue line emphasised as the design shows. A single control advances to bell selection.

The design's instruction line reads "Shake gently or tap to play." Because this build has no motion input, that line is reworded to describe tapping only. Telling an audience to shake a phone that will not respond to shaking is worse than saying nothing.

### 4. Let the audience member choose which bell to play

The third screen presents three bells side by side and lets the audience member swipe between them to choose one, with a confirm control that carries the chosen bell forward to the play screen. The chosen bell determines both the instrument shown on the play screen and the set of recordings that screen draws from.

This screen also carries the "Did you know?" bubble from the design. The bubble and its presentation are built in this feature; the fun-fact copy itself is supplied with the brand assets under requirement 10, because the design carries only the placeholder text "Insert fun facts" and placeholder copy visible during a sponsor demonstration reads as unfinished work.

Bell selection does not appear anywhere on the current roadmap. It is included here because it is central to Christopher's flow and because requirement 5 depends on it.

### 5. Sound a bell when the screen is tapped

The fourth screen presents the chosen bell as a single large instrument, centred, as the design shows. Tapping anywhere on the screen sounds one recording chosen at random from the set belonging to that bell, and animates the instrument with a short shake or wiggle. The on-screen control that the design places on this screen remains visible as a hint about what to do, but the whole screen is the tap target: hunting for a button in a darkened concert hall is a worse experience than tapping anywhere.

Each bell has multiple recordings so that repeated taps do not sound mechanically identical.

### 6. Offer more information without leaving the bell

The information icon on the play screen opens an overlay drawn on top of that screen. The overlay is dismissed by an explicit close action or by tapping outside it, returning the audience member directly to the bell with no navigation and no loss of their chosen instrument.

The design shows this state as a separate board, but it depicts the same instrument and the same controls underneath, so it is built as an overlay rather than as a fifth destination in the sequence.

The overlay's container, its opening, and its dismissal are built in this feature. Its written content is supplied with the brand assets under requirement 10.

### 7. Retire the motion-driven bell physics for this build

The bell behaviour in the current build reads the device gravity and accelerometer vectors each physics frame, converts them into a two-dimensional gravity direction and a shake impulse, and applies both as forces to physics bodies, with sound triggered by collision impacts and loudness derived from impact speed. None of this is carried into the mockup.

Two reasons. The design's play screen shows one static, centred instrument rather than loose bells tumbling in a box, so the simulation does not describe what is being built. And with motion input removed, the force model has no input at all: the gravity direction settles to a constant and the shake impulse is permanently zero.

The random-selection-with-pitch-variation behaviour that the existing sound code performs when it plays a jingle is the part worth carrying forward into requirement 5. The collision trigger and the impact-speed-to-loudness mapping are not, because a tap has neither a collision nor an impact speed.

This requirement retires the physics from the delivered mockup. It does not delete the work, which remains available to the native path.

### 8. Present as a real app on the phone, and still work in a browser tab

The build is exported as an installable progressive web app so that, once added to the home screen, it launches in standalone display mode with no address bar and no browser toolbar. This is the presentation the sponsor asked to see and the reason the mockup is the deliverable that settles the SPA direction.

The mockup must also remain a good experience when opened as an ordinary web page with the address bar visible. Installation to the home screen is a manual, multi-step action performed once by an audience member in a darkened hall, and a meaningful share of the audience will never complete it. Installed standalone presentation is therefore the enhanced path, not a precondition for the experience working.

### 9. Fit any phone screen in portrait, clear of the notch and home indicator

Every screen lays out in portrait and fills the display edge to edge, extending behind the status bar and the camera notch or Dynamic Island so the composition reads as an app rather than as a web page. Controls and tap targets stay clear of the safe area at the top and bottom of the screen, so that no control sits under the home indicator where the phone intercepts touches.

### 10. Drop in the real brand assets when they arrive

The brand assets are supplied separately: the Richmond Symphony identity, the title and seasonal typography, the colour values, the mascot illustrations, the bell artwork, the fun-fact copy for requirement 4, and the information overlay copy for requirement 6. The build is structured so these replace placeholders as a mechanical substitution rather than a rework, which keeps progress on the flow and the interaction independent of when the assets arrive.

## Future work

**Jingle Jam Cam.** Christopher's design includes two camera-and-record screens, which are removed from this feature and are the natural next reach once the flow exists. They are substantially harder than the rest of the design for two reasons that only became clear on investigation. Godot's camera classes have no web implementation at all, so the camera can never be an object inside the game; it has to be a video element composited with the game canvas in the surrounding web page, which makes the camera screens structurally a second application joined to the first. More seriously, every known camera defect on iPhone is specific to the standalone display mode that requirement 8 adopts: camera permission is not remembered between launches so the audience member is asked every time, a regression reported from iOS 18 leaves the camera never loading in an installed app even after permission is granted while working normally in a browser tab, an open defect reported in September 2025 and unaddressed rotates the camera image ninety degrees in installed apps on current iPhones, and the browser's recording interface has been reported to work on an installed app's first launch and then fail silently until the phone is restarted. The tension is worth stating plainly: the presentation mode chosen to make the app feel native is the same one that breaks the camera. A future feature should settle whether the camera screens open in a browser tab instead, and should budget for device testing rather than desk research.

**Shake-to-Jingle.** The Shake-to-Jingle interaction (`C1_02`) remains on the roadmap for the native path. Bringing it to the web would require replacing the engine's absent motion-sensor support with a bridge to the browser's own motion events, and would reopen the sensor-permission questions that led the project away from the web in the first place. Requirement 7 retires the physics from this build without deleting it.

**Professionally recorded bell audio.** Julie is producing professional recordings of the sleigh bells (`C1_T04`). Requirement 5 draws from whatever recordings are supplied for each bell, so those recordings replace the placeholders without changing the interaction.
