---
DOCUMENT TYPE: Holiday Sleigh Bells Implementation Plan
DOCUMENT TITLE: Implementation Plan for A Photo the Audience Takes Home
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.1
AUTHOR: George Ruzek
VALUE STATEMENT: Puts a live camera behind artwork the application already knows how to compose, so the first thing this product ever hands an audience member to keep is built out of parts that were already there.
LAST UPDATED: August, 23, 2026 10:49
---

# Implementation Plan for A Photo the Audience Takes Home

This plan implements the Jingle Cam feature (C1_16), whose specification is `features/C1_16_jingle_cam.md`. It adds a fifth screen to the audience flow, a red button on the bell-selection screen that reaches it, a live camera layer behind the season's artwork, and a shutter that hands a photograph to the phone's own share sheet.

## Design decisions carried in from the specification and planning conversations

These were settled before this plan was written and are implemented rather than reconsidered.

- **The camera lives on the bell-selection screen's button**, `app/instrument_select.tscn`, alongside the existing "Continue" rather than replacing it.
- **A photograph, not a video.** The shutter reads "Press to Snap".
- **The photograph goes to the phone's share sheet**, through a third-party share plugin, rather than being saved silently.
- **The screen opens on the selfie camera** and a switch-camera button toggles to the camera on the back of the phone and back again.
- **The camera layer is mirrored; the artwork layer never is.**
- **No control appears in the photograph.**
- **No camera means no button and no screen**, in the editor and the simulator exactly as on a phone with no camera.
- **A declined permission returns the person to the bell-selection screen**, where the button is now absent.
- **No snow on this screen**; the tilt behaviours from the Artwork That Answers the Tilt of the Phone feature (C1_15) arrive with the artwork scenes and stay.
- **The lettering animates like the title.** The three new pieces get the gesture from the Title That Arrives in Time feature (C1_14), by generalising that script rather than copying it, **and with no initial delay** — the entrance begins the moment the screen opens.
- **The camera list is built when the bell-selection screen loads**, not earlier in the flow.

Two decisions this plan makes that the specification does not name, because they follow from repository convention rather than from the design:

- **The back control is a text button reading "Back"**, styled like the existing buttons on the other screens. Every control in this application is a text button; introducing an icon-only control here would be the first.
- **The supplied switch-camera icon is copied into the repository** as `images/v2/cameraswitch.svg`. Nothing is referenced from a path outside the project.

## The four things worth getting right

### The camera image arrives as two textures, not one

`modules/camera/camera_apple.mm` calls `feed->set_ycbcr_images(img[0], img[1])`, so on iOS `get_datatype()` returns `FEED_YCBCR_SEP`: the frame is a luma image and a chroma image, in two separate textures, not one picture. The engine combines them for you **only** when the feed is used as a three-dimensional environment background, which is not what this screen does.

So the display path is two `CameraTexture` nodes on one `TextureRect`, one bound to `CameraServer.FEED_Y_IMAGE` and one to `CameraServer.FEED_CBCR_IMAGE`, combined by a shader. A single `CameraTexture` on a `TextureRect` produces a grey, washed-out image that looks like a broken exposure rather than like a missing colour conversion, which is why this is named first: the symptom does not point at the cause.

### A format must be selected before the feed is activated

The engine refuses to activate a feed whose format has not been chosen. On Android this is an explicit `ERR_FAIL_INDEX_V_MSG` reading "CameraFeed format needs to be set before activating"; the Apple backend exposes `get_formats()` and `set_format()` on the same contract. The order is fixed and is not a matter of taste: read `formats`, call `set_format()`, then `set_active(true)`. `set_format()` on an already-active feed returns false.

Most published example code predates format selection and omits the step entirely, which produces a black rectangle and no error visible on the device.

### The controls are on the screen the photograph is a capture of

Requirement 7 of the specification exists because the naive implementation is wrong in a way that is permanent. The photograph is `get_viewport().get_texture().get_image()`, and the shutter, the switch-camera button, and the back button are all in that viewport. Capturing straightforwardly puts a red button across the bottom of every keepsake anybody sends to anybody.

The shape is: hide the three controls, wait for the frame to actually be drawn, capture, restore. The waiting is the part that is easy to get wrong — setting `visible = false` and capturing in the same call captures the frame that was already drawn, with the controls still in it.

### Mirroring the wrong node reverses the Symphony's name

Requirement 5 is emphatic for a reason. The mirror is a negative horizontal scale, and it must be applied to the camera layer alone. Applied to the screen root, or to the captured image, it reverses "LET IT SNOW!", the Richmond Symphony logo, and the conductor — in every photograph, permanently, in files that travel to people who were not in the room.

## Implementation Steps and Phases

### Phase 1: Turn the camera on and prove it exists

1. In the Godot editor, import the three lettering assets. `images/v2/let_it.svg`, `images/v2/snow_!.svg`, and `images/v2/2026.svg` are present but have no `.import` files, so nothing can reference them until the editor has imported them once.

2. Copy the supplied switch-camera icon into the repository as `images/v2/cameraswitch.svg` and let the editor import it.

3. In the iOS export preset, set `modules/camera=true`.

4. In the same preset, write `privacy/camera_usage_description`. This is the sentence iOS shows in the permission prompt and the only explanation an audience member is ever given; a vague one is a documented cause of App Store rejection. Suggested text: `Holiday Sleigh Bells uses the camera so you can take a photo of yourself with the Richmond Symphony's holiday artwork.`

5. In the same preset, write `privacy/photolibrary_usage_description`, which iOS requires before the share sheet's "Save Image" will work. Suggested text: `Holiday Sleigh Bells saves your Jingle Cam photo to your photo library.`

6. **Prove the feed exists on the handset before writing anything else.** A throwaway scene that sets `CameraServer.monitoring_feeds = true`, connects `camera_feeds_updated`, and prints the feed count, each feed's `get_position()`, each feed's `get_datatype()`, and the contents of `formats`. Deploy to the iPhone and read the output.

   This step gates the rest of the plan. Everything below assumes two feeds, a `FEED_YCBCR_SEP` datatype, and a non-empty format list. If the count is zero, stop and revisit `features/jingle_jam_cam_camera_exploration.md` §3 rather than proceeding.

### Phase 2: Generalise the staggered-word animation

7. Rename `app/holiday_sleigh_bells.gd` to `app/staggered_words.gd`, carrying its `.uid` file with it, and update the header comment: it is no longer the title's animation but the gesture the title uses, named for what it does rather than for its first caller.

8. Change `WORD_NAMES` from a `const` to an exported property, `word_names`, typed `Array[String]`. Everything else about the collection logic is unchanged, including the `push_error` on a missing or renamed child — an exported list checks the same way a constant one did, and that check is the reason the names are listed rather than inferred from the children.

9. Validate `word_names` in `_ready()` alongside the existing `loop_beats` check: an empty list is a configuration error and fails with a message naming the property and what it is for. Update the `loop_beats` validation to compare against `word_names.size()` rather than the removed constant, and update its error message accordingly.

10. Update `app/holiday_sleigh_bells.tscn` to reference the renamed script by its new path and unchanged `uid://dss8vbivsc4ry`, and to set `word_names = ["Holiday", "Sleigh", "Bells"]` on the root node.

11. Confirm the title screen still animates exactly as it did. This is a refactor of shipped, working code from the Title That Arrives in Time feature (C1_14); a difference visible on the title screen is a defect in this step, not a design change.

### Phase 3: The lettering scene

12. Create `app/let_it_snow.tscn`: a `Node2D` root carrying `app/staggered_words.gd`, with three `Sprite2D` children named `LetIt`, `Snow`, and `Year`, textured from `images/v2/let_it.svg`, `images/v2/snow_!.svg`, and `images/v2/2026.svg`.

    The children are named in that order because the animation fires them in list order, one beat apart, and "LET IT / SNOW! / 2026" is the reading order. `Year` rather than `2026` because a node name that begins with a digit is a poor identifier and the lettering may change year to year while the node name should not.

13. On the root node, set `word_names = ["LetIt", "Snow", "Year"]` and `initial_delay_seconds = 0.0`.

    The zero is the decision made during planning: the entrance begins the moment the screen opens rather than after the title screen's one-second hold. The accepted consequence, recorded once here and not revisited: the three words still arrive one beat apart, so the lettering is not complete until roughly 1.8 seconds after the screen opens, and a photograph taken inside that window catches it mid-arrival.

14. Position and scale the three sprites in the editor against the mockup — lower left of the design canvas, with "SNOW!" overlapping "LET IT" as drawn. Positions are authored on the children; the root's placement is `design_position` on the placement script, as everywhere else.

### Phase 4: The camera layer

15. Create `shaders/ycbcr_to_rgb.gdshader`: a canvas-item shader taking the luma texture as its albedo and the chroma texture as a uniform `sampler2D`, and producing red-green-blue output by the standard conversion. Keep it a shader over a full-rect `TextureRect` rather than anything more elaborate; this is a colour conversion and nothing else.

16. Create `app/camera_feed_view.gd` and `app/camera_feed_view.tscn`, a self-contained scene that owns one camera and draws it. This is the shape the Snow That Falls the Way the Phone Is Held feature (C1_12) established for an effect: a scene a screen gains by adding a node.

    The script:

    - Exports `mirror_selfie: bool = true`, so the mirroring rule of requirement 5 is a property rather than a constant.
    - Holds the feeds it found, and the index of the one in use.
    - `open(position)` selects the feed whose `get_position()` matches, selects a format from its `formats`, activates it, and binds the two `CameraTexture` nodes to `FEED_Y_IMAGE` and `FEED_CBCR_IMAGE`.
    - `switch()` deactivates the current feed and opens the other, returning false where there is no other.
    - `close()` deactivates whatever is active. Called when the screen is left, so the camera is not left running behind a scene change.
    - Applies the mirror as a negative horizontal scale on the display node when the active feed is `FEED_FRONT` and `mirror_selfie` is true, and never anywhere else.
    - Scales the display to cover the viewport: the larger of the two axis ratios between the viewport and the feed's format dimensions, so the image fills the screen and the overflow is cropped. Recomputed on `size_changed` like every other responsive piece in this application.
    - Validates its two `CameraTexture` node dependencies in `_ready()` by scene path, per the repository convention that a misconfiguration surfaces at load rather than inside a branch that runs rarely.

    The feed's own `feed_transform` is left alone. `camera_apple.mm` writes device rotation into it, and that is the platform's business rather than this scene's.

17. Create `app/valentina.tscn`: a `Node2D` carrying `app/sprite_position.gd` with one `Sprite2D` child textured from `images/v2/valentina.svg`. The asset is in the repository and referenced by nothing; this is its first use.

### Phase 5: The Jingle Cam screen

18. Create `app/jingle_cam.tscn`. Composition from back to front:

    | Layer | Node | Notes |
    |---|---|---|
    | Camera | `app/camera_feed_view.tscn` | Backmost, fills the screen |
    | Logo | `app/title.tscn` | `respect_safe_area = true`, clear of the Dynamic Island |
    | Tree | `app/straight_red_tree.tscn` | Anchored to the physical edge; runs off-screen left |
    | Snowflake | `app/blue_snowflake.tscn` | Anchored to the physical edge; runs off-screen right |
    | Lettering | `app/let_it_snow.tscn` | Lower left |
    | Conductor | `app/valentina.tscn` | Lower right |
    | Controls | Three `Button` nodes | Each carrying `app/safe_area_margin.gd` |

    **No `snow.tscn` node and no `vignette.tscn` node.** The absence of snow is requirement 12 and is deliberate. The vignette is omitted because it exists to sit over a flat background colour, and there is no flat background on this screen.

    The tree and the snowflake bring the sway, the spin, and the halo drift with them, because the Artwork That Answers the Tilt of the Phone feature (C1_15) placed those behaviours inside the artwork scenes. Nothing is added to obtain them and nothing is switched off.

19. The three controls, all bottom-anchored and all carrying `app/safe_area_margin.gd`:

    - `SwitchCameraButton`, bottom-left, an icon button using `images/v2/cameraswitch.svg`.
    - `SnapButton`, bottom-centre, red, reading "Press to Snap", styled with the `StyleBoxFlat` pattern the other screens use — 55-pixel corner radius, 44-point white text, the flow's red `Color(0.83137256, 0.20392157, 0.15686275, 1)` as its normal state.
    - `BackButton`, bottom-right, reading "Back", styled like the other screens' buttons.

20. Create `app/jingle_cam.gd`. In `_ready()`, per repository convention, connect all three button signals and validate all three node dependencies by scene path. Then open the camera on the selfie feed.

21. Hide `SwitchCameraButton` where the phone reports fewer than two feeds. Requirement 4: a control that cannot do anything is not drawn.

22. `_on_back_pressed()` closes the camera and returns to `res://app/instrument_select.tscn`.

23. Handle the declined permission. Where opening the selfie feed does not produce an active feed, close the camera and change scene straight back to `res://app/instrument_select.tscn`. Requirement 10: the person lands back on the selection screen, where the button is now absent because the camera is now unavailable, and the state is consistent the moment they arrive.

    Note for the build: the iOS permission answer is asynchronous. `camera_apple.mm` requests access via `requestAccessForMediaType` inside activation, so the first activation attempt can return before the person has answered. The build confirms the actual sequencing on the device in Phase 8 and drives the return from the point where the answer is known, not from the first false.

### Phase 6: The shutter and the share sheet

24. Install the Share Plugin (Android and iOS, minimum Godot 4.7) into the project, and enable it in the iOS export preset. Do **not** enable `share_target/enable_share_target`; this application shares outward and is not a destination for other applications' content.

25. Implement the capture in `app/jingle_cam.gd`:

    1. Hide all three control buttons.
    2. Await the frame actually being drawn, so the captured frame is the one without the controls rather than the one already on screen.
    3. `get_viewport().get_texture().get_image()`.
    4. Restore the three buttons to visible.
    5. `save_png` the image to a fixed path under `user://`, which is where the share plugin requires the file to be.
    6. Hand that path to the plugin's `share_image()`.

    The lettering is not touched by this sequence. Whatever scale the entrance or the pulse has it at when the shutter is pressed is the scale in the photograph, which is the decision recorded in Phase 3.

26. Disable the shutter for the duration of the capture and re-enable it after, so a double-tap cannot start a second capture inside the first one's hidden frame.

### Phase 7: The way in

27. In `app/instrument_select.tscn`, add `JingleCamButton`: a red button reading "JINGLE CAM", bottom right, carrying `app/safe_area_margin.gd`, styled with the same `StyleBoxFlat` pattern as the screen's existing controls but using the flow's red as its normal state rather than as its pressed state. The existing centred "Continue" is unchanged.

28. Set `visible = false` on that button in the scene file, so it is absent on the first frame and appears only when a camera has actually been reported. A button that is drawn and then removed is worse than one that arrives.

29. In `app/instrument_select.gd`: set `CameraServer.monitoring_feeds = true` in `_ready()`, connect `camera_feeds_updated`, and show the button when the signal reports at least one feed. Connect the button to a handler that changes scene to `res://app/jingle_cam.tscn`.

    The feed list is built asynchronously — the engine populates it a few frames after monitoring is enabled, which is why the `camera_feeds_updated` signal exists. Reading `CameraServer.feeds` directly in `_ready()` returns an empty list on a phone that has two cameras, and is the single most likely way to implement requirement 9 backwards.

30. Leave `monitoring_feeds` on for the rest of the session. It is enabled on the screen that needs it rather than at application start, which was the decision made during planning.

### Phase 8: Tuning and confirmation on the device

31. Everything about this feature exists only on a handset. The camera returns no feeds in the editor and the simulator, exactly as the motion sensors return a zero vector there, so this phase is where the feature is actually seen for the first time.

32. Confirm on the iPhone, in order: the button appears on the bell-selection screen; the permission prompt shows the sentence written in Phase 1; the selfie camera comes up the right way round and the right way up in portrait; the artwork composes over it as the mockup draws it; the switch button reaches the back camera and returns; the photograph contains no buttons; the photograph's lettering reads forwards; the share sheet appears and "Save Image" writes a file to the photo library.

33. Tune the lettering's placement and scale against the real screen, and the camera layer's cover-scaling against the real feed dimensions.

## Test Cases

**No automated tests are created or changed by this plan.** The repository has no test framework, and `docs/system_design.md` records that as a deliberate position rather than an oversight, resting on the observation that the parts of this application most worth testing are the parts that only exist on a real device. The Jingle Cam feature (C1_16) is the strongest case yet made for that position: there is no camera in the editor, none in the simulator, and no way to assert anything about a photograph of a room.

There is accordingly no table of unit or interface tests. The verification table below carries the full burden, and the completion criteria depend on those manual checks rather than on a passing suite.

Three of the failures most likely here look like something other than their cause, and each has its own row below:

- A single `CameraTexture` instead of the luma-and-chroma pair reads as a broken exposure, not as a missing colour conversion.
- A feed activated without a format selected reads as a dead camera, not as a missing call.
- A mirror applied one node too high reverses the Richmond Symphony's name in every saved photograph, and is invisible on screen because the person looking at it is looking at themselves.

## README and Documentation Updates

- **`README.md`** — add the Jingle Cam to the repository structure table and add a short section describing the screen, in the manner of the existing sections on the shake instrument and the snow. Name the two-texture camera path and the reason snow is absent from that one screen.
- **`docs/system_design.md`** — extend the audience flow diagram from four screens to five, showing the Jingle Cam as a branch off bell selection rather than a step in the sequence. Add to the Platform notes that the camera, like the motion sensors, exists only on a real device, and that the camera module is enabled through the iOS export preset rather than through project settings. Record the Share Plugin as the application's first third-party dependency.
- **`features/jingle_jam_cam_camera_exploration.md`** — mark the research as carried into the Jingle Cam feature (C1_16), so a later reader finds the built answer rather than re-deciding the question.

## Manual Verification Steps

Every check is performed on a physical iPhone unless the row says otherwise.

| # | What is checked | How | Expected |
|---|---|---|---|
| 1 | The title screen is unchanged by the refactor | Open the title screen after Phase 2 | The three words arrive and pulse exactly as before, with the one-second hold intact |
| 2 | A renamed lettering child still fails loudly | Rename `Snow` in `app/let_it_snow.tscn`, run, then undo | An error naming the missing child; the animation does not run |
| 3 | The button is absent where there is no camera | Run in the editor and in the simulator | No JINGLE CAM button on the bell-selection screen |
| 4 | The button appears where there is a camera | Reach bell selection on the iPhone | The button appears bottom right; no visible pop against the scene change |
| 5 | The permission sentence is the one written | First launch after install, tap JINGLE CAM | The prompt shows the Phase 1 text, not a system default |
| 6 | A declined permission returns cleanly | Tap "Don't Allow" | Returned to bell selection; the JINGLE CAM button is now absent |
| 7 | The selfie camera opens by default | Tap JINGLE CAM and allow | The person's own face, right way up, in portrait |
| 8 | The camera image is in colour | Look at the screen | Natural colour, not grey or washed out — a grey image means one `CameraTexture` rather than the luma-and-chroma pair |
| 9 | The camera is not dead | Look at the screen | A live moving image — a black rectangle means no format was selected before activation |
| 10 | The image fills the screen | Look at the screen edges | No band of background anywhere behind the artwork |
| 11 | The artwork composes as drawn | Compare against the mockup | Logo clear of the Dynamic Island; tree off the left edge; snowflake off the right; lettering lower left; conductor lower right |
| 12 | The lettering animates on arrival | Open the screen and watch | The three pieces arrive one beat apart, beginning immediately with no hold |
| 13 | The tilt behaviours arrived with the artwork | Tilt the phone | The tree sways, the snowflake spins, the halo drifts |
| 14 | No snow falls | Watch the screen | No falling snow anywhere |
| 15 | The switch button reaches the other camera | Press it | The back camera; press again for the selfie |
| 16 | The back camera is not mirrored | Point at something with writing on it | The writing reads forwards on screen |
| 17 | The selfie preview is mirrored | Raise one hand | The hand on the same side as in a mirror |
| 18 | No control is in the photograph | Take one and inspect it | No shutter, no switch button, no back button |
| 19 | **The lettering reads forwards in the photograph** | Take a selfie and inspect it | "LET IT SNOW! 2026" and the Richmond Symphony logo read correctly, not reversed |
| 20 | The selfie photograph matches the framing | Take a selfie | The saved image agrees with what was on screen while framing |
| 21 | The share sheet appears | Take a photograph | The phone's own share panel, with Save Image among the options |
| 22 | Save Image works | Tap it | The photograph is in the photo library, complete with artwork |
| 23 | A double-tap does not double-capture | Tap the shutter twice quickly | One photograph, one share sheet |
| 24 | Back leaves without capturing | Press Back | Bell selection, nothing saved, nothing shared |
| 25 | The camera stops when the screen is left | Press Back and watch the camera indicator | The indicator goes out |
| 26 | The flow is otherwise untouched | Walk title to instructions to selection to play | Unchanged, including Continue |

## Coding Standards Compliance Checklist

There is no application coding standards document in this repository. `docs/system_design.md` records that absence and lists the conventions the repository demonstrates, which this plan is audited against.

- [ ] Tab indentation in every GDScript file.
- [ ] A one-line header comment on each new script naming the file and its role, followed by whatever a reader needs that the code cannot tell them.
- [ ] Static typing on every declaration and every return type, including `-> void`.
- [ ] Signals connected in `_ready()` and not in the scene files. Connecting in both raises a duplicate-connection error at runtime.
- [ ] Scene and script files named in lower snake case.
- [ ] Exported values used as bounds or counts validated in `_ready()`, with a message naming the value, its permitted range, and the correct default. Applies to `word_names` and to the existing `loop_beats`.
- [ ] Node dependencies reached by scene path validated in `_ready()` rather than at first use. Applies to the two `CameraTexture` nodes and to the three buttons.
- [ ] **No fallbacks.** A missing feed, a missing format, or a missing node fails with a message naming what is missing and what to do about it. Nothing substitutes a default and carries on.
- [ ] No media file deleted. Nothing in this plan removes an asset; `images/v2/valentina.svg` moves from unused to used.

## File-Level Compliance Review

| File | Change | Points of attention |
|---|---|---|
| `app/staggered_words.gd` | Renamed from `app/holiday_sleigh_bells.gd`, `word_names` exported | The `.uid` travels with the rename; the header comment stops naming the title; `loop_beats` validation compares against the exported list |
| `app/holiday_sleigh_bells.tscn` | Script path updated, `word_names` set | Must render identically to before; a visible difference is a defect in Phase 2 |
| `app/let_it_snow.tscn` | New | Children named `LetIt`, `Snow`, `Year`; `initial_delay_seconds = 0.0` |
| `app/camera_feed_view.gd` | New | Format before activation; two `CameraTexture` nodes; mirror on the display node only; cover-scaling recomputed on resize; `close()` on leaving |
| `app/camera_feed_view.tscn` | New | Two `CameraTexture` nodes bound to `FEED_Y_IMAGE` and `FEED_CBCR_IMAGE` |
| `shaders/ycbcr_to_rgb.gdshader` | New | Colour conversion and nothing else |
| `app/valentina.tscn` | New | First use of an asset already in the repository |
| `app/jingle_cam.gd` | New | Buttons hidden for the captured frame; shutter disabled during capture; declined permission returns to bell selection |
| `app/jingle_cam.tscn` | New | No snow node, no vignette node; controls carry `app/safe_area_margin.gd` |
| `app/instrument_select.gd` | Modified | `monitoring_feeds` on; button shown from `camera_feeds_updated`, never from a direct read of `feeds` |
| `app/instrument_select.tscn` | Modified | New button starts `visible = false`; Continue unchanged |
| `images/v2/cameraswitch.svg` | New | Copied into the repository from the supplied file |
| `export_presets.cfg` | Modified | `modules/camera`, both usage descriptions, Share Plugin enabled |
| `README.md`, `docs/system_design.md` | Modified | Five screens, camera platform note, first third-party dependency |

## Completion Criteria

1. Every row of the verification table passes on a physical iPhone, with rows 8, 9, 18, and 19 confirmed by inspecting saved photographs rather than the screen.
2. The title screen is visually identical to its pre-refactor behaviour.
3. The project loads with no errors and every resource reference resolves.
4. The four screens of the existing audience flow behave exactly as they did.
5. `run/main_scene` still points at the title screen.
6. The documentation updates are made.
7. No media file has been deleted.

## Token and Design Considerations

This feature builds no skill. It adds one screen, one shader, three scenes, two scripts, and one button to a Godot application, so there is no prompt to size, nothing loaded into a model's context, and no per-run cost to account for.

## Teaching Topic

Add to the tutor's `references/topics.md`:

**Topic:** how a camera becomes a layer in a Godot scene. **Competency:** a developer who can explain why the photograph needs no compositing step — that the camera feed is a texture in the same viewport as the artwork, that the ordering on screen is therefore the ordering in the file, and that this is the same layering rule already governing the vignette, the snow, and the buttons — can extend this screen without reintroducing an assembly step the architecture does not need. The competency is demonstrated by naming why the mirror is applied to the camera node rather than to the screen, and why the controls must be hidden a frame before the capture rather than during it.
