# camera_feed_view.gd (C1_16) - one camera, drawn as the backmost layer of a screen.
#
# A screen gains a live camera by adding this node, the way a screen gains weather by adding
# snow/snow.tscn. It owns which camera is running and how the picture is drawn, and it tells the
# screen nothing about either.
#
# Two things measured on a handset on 2026-08-23 shape this file, both recorded in
# features/jingle_jam_cam_camera_exploration.md section 6a.
#
# The first is that a phone offers far more cameras than it has lenses. The probe found eight
# feeds on one iPhone - the plain front and back cameras, the telephoto, the ultra wide, and the
# fused Dual, Dual Wide, Triple and TrueDepth virtual cameras. Choosing "the first one whose
# position matches" happens to give the right answer on that handset and would give the
# TrueDepth camera on one that enumerates differently, so on iOS the feed is chosen by name.
#
# Android has no such names. Its backend, modules/camera/camera_android.cpp, identifies a camera
# by its Camera2 identifier, so every diagnostic it logs reads "Camera 0" or "Camera 1" and the
# strings "Front Camera" and "Back Camera" appear nowhere in the shipped library. A name match
# does not pick the wrong camera there; it finds nothing at all.
#
# Selection is therefore in two stages. The position filter is portable and runs on both
# platforms; the tie-break within it is the part that differs, and it is the only part that
# needed a platform test. See _find_feed.
#
# The second is that the first activation always fails when camera permission has not yet been
# answered. modules/camera/camera_apple.mm starts the permission request and returns false
# without waiting, and servers/camera/camera_feed.cpp only marks a feed active when that call
# returns true - so nothing marks it active when the person taps Allow, and the camera runs with
# the engine believing it does not. The cure is to deactivate and activate again once the answer
# has arrived, which is what _await_activation does. Deactivating first matters: the permission
# callback has already built a capture session, and activating over the top of it would overwrite
# the reference to a session still running.
#
# Android has a permission fault of its own, and it is not the same one. Its backend requests the
# permission inside activate_feed() and returns false immediately when it is not yet held, with no
# retry - but it does report the answer, on the main loop's on_request_permissions_result. So
# Android waits for the answer rather than retrying blind, which is _await_camera_permission, and
# _await_activation stays iOS-only. Treating either fault with the other's cure leaves the Jingle
# Cam dead on the launch where permission is first granted and working on every launch after.
extends Control

# The plain cameras, not the fused virtual ones and not TrueDepth. On iOS these are the tie-break
# within the position filter; on Android no feed carries a name like these and they are unused.
const SELFIE_FEED_NAME: String = "Front Camera"
const REAR_FEED_NAME: String = "Back Camera"

# The only Camera2 image format this screen can draw. The Android backend hands a feed's frames
# over as two planes and sets the FEED_YCBCR_SEP datatype when the chosen format is this one, and
# as a single plane with the FEED_RGB datatype when it is RGBA_8888 or RGB_888. shaders/
# ycbcr_to_rgb.gdshader converts two planes and nothing else, so an RGB format would be drawn as
# though it were luma and chroma and come out as garbage colour with no error anywhere. The format
# is chosen, not reported by the handset, so this is settled here rather than guarded downstream.
const ANDROID_PREVIEW_FORMAT: String = "YUV_420_888"

# The Android permission this screen needs. OS.get_granted_permissions() reports it in its fully
# qualified form, which is why the check below matches on the suffix rather than on equality.
const ANDROID_CAMERA_PERMISSION: String = "CAMERA"

# How long to keep asking before giving up on a camera. The engine cannot distinguish "the
# person has not answered yet" from "the person said no", so this doubles as the answer to
# both: after this long with no picture, there is no camera to be had.
@export var activation_timeout_seconds: float = 8.0

# How often to try again while waiting. Each attempt deactivates first, so a permission callback
# that built a session has that session released rather than leaked.
@export var activation_retry_seconds: float = 0.5

# The selfie camera is mirrored so a photograph matches what the person framed.
@export var mirror_selfie: bool = true

# Added to whatever rotation the engine reports, in quarter turns, so the picture can be stood
# upright against a real phone without editing this file.
#
# Zero is correct and measured on both platforms. On an iPhone in portrait the feed's own transform
# reports 90 degrees and applying exactly that stands the picture upright, on both cameras. On a
# Galaxy A11 on 2026-09-08 the rear camera reports the same 90 degrees and the front camera reports
# minus 90, and applying each verbatim is upright as well.
#
# There is deliberately no platform correction. One was written, on the evidence that Android's
# picture came out a quarter turn out, and it was wrong: the rotation was being read before the
# camera had delivered a frame and reported as zero, so the correction was compensating for a stale
# reading rather than for a difference between the platforms. See _follow_late_rotation. The value
# is kept exported because none of this was obvious - several builds were spent on the assumption
# that the engine's figure needed correcting - and a handset that genuinely disagrees can be
# answered here instead of in this file's logic.
@export var extra_quarter_turns: int = 0

# The narrowest preview this screen will settle for, in pixels, on Android only. A phone offers
# formats far larger than anything this screen draws: the design canvas is 1080 wide, the preview
# sits behind artwork, and the photograph is a capture of the viewport rather than of the feed.
# The smallest format at least this wide is taken, so the picture is never softer than the canvas
# and never larger than it needs to be. iOS chooses its own format and ignores this.
@export var preferred_preview_width: int = 1080

# How long to wait for the person to answer the Android permission prompt before giving up. It is
# separate from activation_timeout_seconds because a person reading a permission dialog is slower
# than a camera starting, and eight seconds is the wrong budget for a decision.
@export var permission_timeout_seconds: float = 30.0

# How long to keep watching the feed's rotation after it starts, on Android only. The rotation is
# written when frames begin arriving rather than when the feed reports itself active, so a value
# read at activation can still change. Long enough to catch that, short enough that it is over
# before anyone has framed a photograph.
@export var rotation_settle_seconds: float = 2.0

# How often to look during that window.
@export var rotation_settle_poll_seconds: float = 0.1

signal camera_ready()
signal camera_unavailable()

@onready var display: TextureRect = $Display

var _feed: CameraFeed = null

func _ready() -> void:
	if display == null:
		push_error("camera_feed_view: no TextureRect node named `Display`. The camera picture is drawn into that node and cannot be shown without it.")
		return
	if activation_timeout_seconds <= 0.0:
		push_error("camera_feed_view: `activation_timeout_seconds` is %f. It must be greater than zero, and the default is 8.0." % activation_timeout_seconds)
		return
	if activation_retry_seconds <= 0.0:
		push_error("camera_feed_view: `activation_retry_seconds` is %f. It must be greater than zero, and the default is 0.5." % activation_retry_seconds)
		return
	if extra_quarter_turns < 0 or extra_quarter_turns > 3:
		push_error("camera_feed_view: `extra_quarter_turns` is %d. It must be 0, 1, 2 or 3, and the default is 0, which trusts the rotation the engine reports." % extra_quarter_turns)
		return
	if preferred_preview_width <= 0:
		push_error("camera_feed_view: `preferred_preview_width` is %d. It must be greater than zero, and the default is 1080, which is the width of the design canvas." % preferred_preview_width)
		return
	if permission_timeout_seconds <= 0.0:
		push_error("camera_feed_view: `permission_timeout_seconds` is %f. It must be greater than zero, and the default is 30.0." % permission_timeout_seconds)
		return
	if rotation_settle_seconds <= 0.0:
		push_error("camera_feed_view: `rotation_settle_seconds` is %f. It must be greater than zero, and the default is 2.0." % rotation_settle_seconds)
		return
	if rotation_settle_poll_seconds <= 0.0 or rotation_settle_poll_seconds > rotation_settle_seconds:
		push_error("camera_feed_view: `rotation_settle_poll_seconds` is %f. It must be greater than zero and no larger than `rotation_settle_seconds`, and the default is 0.1." % rotation_settle_poll_seconds)
		return
	# A CameraTexture with no frames yet hands back the engine's placeholder image, which is
	# drawn full-screen and looks like a fault. The picture stays hidden until the feed is
	# genuinely delivering, so the screen holds its own background and artwork in the meantime
	# rather than flashing something that reads as broken.
	display.visible = false
	get_viewport().size_changed.connect(_fit_display)
	_fit_display()

# Opens the selfie camera. The screen calls this; everything after it is this node's business.
func open_selfie() -> void:
	_open(SELFIE_FEED_NAME)

# Swaps to whichever camera is not running. Returns false when the phone has only one of them,
# which is what tells the screen not to draw a switch control.
func switch() -> bool:
	var wanted := REAR_FEED_NAME if _is_selfie() else SELFIE_FEED_NAME
	if _find_feed(wanted) == null:
		return false
	close()
	_open(wanted)
	return true

# True when the phone offers both cameras this screen switches between.
func has_both_cameras() -> bool:
	return _find_feed(SELFIE_FEED_NAME) != null and _find_feed(REAR_FEED_NAME) != null

# Stops the camera. Called when the screen is left, so the phone's camera indicator goes out
# rather than staying lit behind a scene change.
func close() -> void:
	if display != null:
		display.visible = false
	if _feed != null:
		_feed.set_active(false)
		_feed = null

func _open(feed_name: String) -> void:
	_feed = _find_feed(feed_name)
	if _feed == null:
		var facing: String = "front" if feed_name == SELFIE_FEED_NAME else "rear"
		push_error("camera_feed_view: this phone reports no usable %s-facing camera, out of %d feeds. The screen that opened it has no picture to show and should return to the bell selection screen." % [facing, CameraServer.feeds().size()])
		camera_unavailable.emit()
		return
	display.visible = false
	# The wait below yields, so the feed this call opened is held locally. A switch or a departure
	# during the prompt reassigns or clears `_feed`, and carrying on afterwards would open a camera
	# for a screen nobody is looking at.
	var feed := _feed
	if _is_android():
		if not await _await_camera_permission():
			if not is_inside_tree() or _feed != feed:
				return
			push_error("camera_feed_view: camera permission was not granted within %.1f seconds. Either it was declined or the prompt went unanswered, and either way there is no camera to show." % permission_timeout_seconds)
			camera_unavailable.emit()
			return
		if not is_inside_tree() or _feed != feed:
			return
		# The feed list is built before the permission is answered, and a feed built without the
		# permission carries an empty format list: Camera2 will name its cameras to anyone, and
		# describe them to nobody. Reading formats straight after the grant therefore finds none,
		# which on the first launch of a fresh install sent the person back to the bell selection
		# and worked on every launch after. Wait for the list to be rebuilt, then take the feed
		# again, because the object standing for this camera is replaced when it is.
		feed = await _await_described_feed(feed_name, feed)
		if feed == null:
			return
		if not _set_android_format(feed):
			camera_unavailable.emit()
			return
	_feed = feed
	_bind_textures(feed.get_id())
	# The picture is not fitted or mirrored here. Both read the feed's rotation, and a feed that
	# has not been activated yet has not been given one, so doing it now would place the picture
	# against whatever the last camera left behind. Activation is what settles the rotation, and
	# both are done there.
	if _is_android():
		_await_android_activation(feed)
	else:
		_await_activation(feed)

# Android activation: ask once, then wait.
#
# Deliberately not _await_activation. That function cures an Apple fault by deactivating and
# reactivating until a picture arrives, and on Android each of those cycles moves the feed's
# rotation - so switching between the cameras turned the picture a further quarter turn every
# time, which on a Galaxy A11 on 2026-09-08 read as "the back camera was fine, then upright became
# upside down became sideways". Android has no fault to cure here: permission has already been
# waited for by the time this is reached, so one activation is enough and any cycling is damage.
func _await_android_activation(feed: CameraFeed) -> void:
	feed.set_active(true)
	var waited: float = 0.0
	while not feed.feed_is_active and waited < activation_timeout_seconds:
		await get_tree().create_timer(activation_retry_seconds).timeout
		waited += activation_retry_seconds
		if not is_inside_tree() or _feed != feed:
			return
	if feed.feed_is_active:
		_settle_picture()
		return
	push_error("camera_feed_view: `%s` did not start within %.1f seconds, with camera permission already granted. The camera was described and its format accepted, so this is the phone declining to hand the camera over." % [feed.get_name(), activation_timeout_seconds])
	camera_unavailable.emit()

# Places the picture once the feed is running and its rotation is settled. Both platforms end here.
func _settle_picture() -> void:
	_fit_display()
	_apply_mirror()
	display.visible = true
	camera_ready.emit()
	if _is_android():
		_follow_late_rotation(_feed)

# Android does not have the feed's rotation ready when it says the feed is active.
#
# `feed_is_active` turns true when the capture session starts; the rotation is written when frames
# begin arriving, which is later. Reading it at activation therefore catches it part-settled, and
# reading it at a different moment on each camera switch is what produced a picture that was
# upright, then upside down, then a quarter turn out, and finally stable at a quarter turn out.
#
# So the rotation is watched for a short while rather than sampled once, and the picture is placed
# again whenever it changes. On a feed whose rotation was already settled this loop changes
# nothing and ends quietly.
func _follow_late_rotation(feed: CameraFeed) -> void:
	var applied := _quarter_turns()
	print("camera_feed_view: `%s` activated. feed rotation %.1f degrees, quarter turns applied %d." % [feed.get_name(), rad_to_deg(feed.feed_transform.get_rotation()), applied])
	var waited: float = 0.0
	while waited < rotation_settle_seconds:
		await get_tree().create_timer(rotation_settle_poll_seconds).timeout
		waited += rotation_settle_poll_seconds
		if not is_inside_tree() or _feed != feed:
			return
		var current := _quarter_turns()
		if current == applied:
			continue
		applied = current
		_fit_display()
		_apply_mirror()
		print("camera_feed_view: `%s` rotation settled late, %.2f seconds in. feed rotation %.1f degrees, quarter turns now %d." % [feed.get_name(), waited, rad_to_deg(feed.feed_transform.get_rotation()), applied])

# Waits until the wanted camera reports the formats it can deliver, and returns it. Returns null
# when the screen was left while waiting, or when the wait ran out, in which case it has already
# said why. The feed is looked up again on each attempt rather than held, because rebuilding the
# list replaces the objects in it and the one this started with goes stale.
func _await_described_feed(feed_name: String, started_with: CameraFeed) -> CameraFeed:
	var waited: float = 0.0
	var found := started_with
	while waited < activation_timeout_seconds:
		if not (found.formats as Array).is_empty():
			return found
		await get_tree().create_timer(activation_retry_seconds).timeout
		waited += activation_retry_seconds
		if not is_inside_tree() or _feed != started_with:
			return null
		var refreshed := _find_feed(feed_name)
		if refreshed != null:
			found = refreshed
	push_error("camera_feed_view: `%s` never reported the formats it can deliver, %.1f seconds after camera permission was granted. Without them there is no way to choose what the preview should look like, and the camera cannot be started." % [found.get_name(), activation_timeout_seconds])
	camera_unavailable.emit()
	return null

func _is_android() -> bool:
	return OS.get_name() == "Android"

func _has_camera_permission() -> bool:
	for permission in OS.get_granted_permissions():
		if permission.ends_with(ANDROID_CAMERA_PERMISSION):
			return true
	return false

# Asks for the camera permission and waits for the answer, which is the whole of the difference
# between this platform and the other one. The answer arrives on the main loop rather than from
# the request, so the request is fired once and the grant polled on the same cadence the
# activation retry already uses; the signal is connected so that an answer is acted on within a
# frame rather than at the end of the next poll.
func _await_camera_permission() -> bool:
	if _has_camera_permission():
		return true
	var tree := get_tree()
	if not tree.on_request_permissions_result.is_connected(_on_permission_result):
		tree.on_request_permissions_result.connect(_on_permission_result)
	OS.request_permission(ANDROID_CAMERA_PERMISSION)
	var waited: float = 0.0
	while waited < permission_timeout_seconds:
		await tree.create_timer(activation_retry_seconds).timeout
		waited += activation_retry_seconds
		if not is_inside_tree():
			return false
		if _has_camera_permission():
			return true
	return false

# The engine reports the answer here. Nothing is decided in this handler: the waiting loop reads
# the granted list, which is the authority, and this only exists so a grant is noticed promptly.
func _on_permission_result(permission: String, granted: bool) -> void:
	if granted and permission.ends_with(ANDROID_CAMERA_PERMISSION):
		var tree := get_tree()
		if tree != null and tree.on_request_permissions_result.is_connected(_on_permission_result):
			tree.on_request_permissions_result.disconnect(_on_permission_result)

# Chooses a preview format and sets it, which Android requires and iOS does not. The order is
# fixed: choose, set, then activate. set_format() fails on a feed that is already active, and the
# backend refuses to activate a feed whose format was never chosen, so getting this the wrong way
# round gives a black rectangle rather than an error a person would notice.
func _set_android_format(feed: CameraFeed) -> bool:
	var index := _choose_android_format(feed)
	if index < 0:
		push_error("camera_feed_view: `%s` offers no %s format, which is the only format this screen can draw. The %d formats it does offer are all single-plane, and the two-plane shader would draw them as garbage." % [feed.get_name(), ANDROID_PREVIEW_FORMAT, (feed.formats as Array).size()])
		return false
	# The backend refuses to change the format of a feed that is already active, and on Android a
	# feed can already be active by the time this screen asks: reading a camera's characteristics
	# is what fills in its format list, and doing so opens the camera. Measured on a Galaxy A11 on
	# 2026-09-08, where the first entry to the screen failed here and the second succeeded, which
	# is what "it takes two presses" looked like from the outside. Deactivating first is harmless
	# on a feed that was not active and is the whole fix on one that was.
	feed.set_active(false)
	if not feed.set_format(index, {}):
		push_error("camera_feed_view: `%s` refused format %d. A feed that is already active refuses to change format, so this means the feed was activated before its format was chosen." % [feed.get_name(), index])
		return false
	return true

# The smallest format at least `preferred_preview_width` wide, falling back to the widest offered
# when none reaches it. Only the two-plane format is considered, for the reason on
# ANDROID_PREVIEW_FORMAT. Returns -1 when the feed offers none, which is not a fallback: it is the
# absence of the one thing this screen can draw, and the caller says so and stops.
func _choose_android_format(feed: CameraFeed) -> int:
	var formats: Array = feed.formats
	var chosen: int = -1
	var chosen_width: int = 0
	var widest: int = -1
	var widest_width: int = 0
	for index in formats.size():
		var format: Dictionary = formats[index]
		if format["format"] != ANDROID_PREVIEW_FORMAT:
			continue
		var width: int = format["width"]
		if width > widest_width:
			widest_width = width
			widest = index
		if width >= preferred_preview_width and (chosen < 0 or width < chosen_width):
			chosen_width = width
			chosen = index
	if chosen >= 0:
		return chosen
	return widest

# The retry the engine does not do for itself. See the note at the top of this file.
func _await_activation(feed: CameraFeed) -> void:
	feed.set_active(true)
	var waited: float = 0.0
	while not feed.feed_is_active and waited < activation_timeout_seconds:
		await get_tree().create_timer(activation_retry_seconds).timeout
		waited += activation_retry_seconds
		# The feed may have been closed while this was waiting, by a switch, or the whole screen
		# may have been left. Pressing Back during the wait is the ordinary way to reach the
		# second case, and carrying on would activate a camera for a screen nobody is looking at.
		if not is_inside_tree() or _feed != feed:
			return
		feed.set_active(false)
		feed.set_active(true)
	if feed.feed_is_active:
		_settle_picture()
	else:
		push_error("camera_feed_view: `%s` did not start within %.1f seconds. Either camera permission was declined or this phone will not give the camera up." % [feed.get_name(), activation_timeout_seconds])
		camera_unavailable.emit()

# Two stages, and only the second one differs by platform.
#
# The position filter is the portable part: both backends report which way a lens faces, and it is
# the only thing about a camera the two platforms describe the same way.
#
# The tie-break is where they part. An iPhone reports several feeds as front-facing - the plain
# camera, TrueDepth, and the fused virtual ones - so the name picks the plain one out of them, and
# that is exactly the behaviour this file has always had. Android names a feed after its Camera2
# identifier and enumerates the primary rear camera and the primary front camera first, so the
# first match is the plain one there.
func _find_feed(feed_name: String) -> CameraFeed:
	var wanted := CameraFeed.FEED_FRONT if feed_name == SELFIE_FEED_NAME else CameraFeed.FEED_BACK
	var candidates: Array[CameraFeed] = []
	for feed in CameraServer.feeds():
		if feed.get_position() == wanted:
			candidates.append(feed)
	if candidates.is_empty():
		return null
	if _is_android():
		return candidates[0]
	for feed in candidates:
		if feed.get_name() == feed_name:
			return feed
	return null

# Asked by the mirror and by the switch control, so it has to be right on both platforms. It reads
# the position rather than the name because the name is an Apple one: comparing it on Android
# returns false for every feed, which would silently unmirror the selfie preview there.
func _is_selfie() -> bool:
	return _feed != null and _feed.get_position() == CameraFeed.FEED_FRONT

# The feed arrives as two images rather than one, so the luma plane becomes this node's own
# texture and the chroma plane a shader uniform.
#
# Both CameraTexture resources are built here rather than authored in the scene. A texture set
# on a shader uniform in a .tscn is stored against the shader's uniform list, and when that list
# is not yet known at save time the entry is silently dropped - which leaves the chroma plane
# unbound and reading as zero. Zero chroma through the BT.709 matrix is not a subtle fault: it
# takes 0.79 off red and 0.93 off blue while adding 0.33 to green, so the whole picture comes
# out green. Building both in code removes the possibility.
func _bind_textures(feed_id: int) -> void:
	var material := display.material as ShaderMaterial
	if material == null:
		push_error("camera_feed_view: the Display node has no ShaderMaterial. Without it the two camera planes are never combined and the picture comes out green.")
		return
	var luma := CameraTexture.new()
	luma.which_feed = CameraServer.FEED_Y_IMAGE
	luma.camera_feed_id = feed_id
	display.texture = luma
	var chroma := CameraTexture.new()
	chroma.which_feed = CameraServer.FEED_CBCR_IMAGE
	chroma.camera_feed_id = feed_id
	material.set_shader_parameter("cbcr_texture", chroma)

# Which axis the mirror flips depends on how far the picture has been turned. At no turn or a
# half turn the texture's horizontal axis still runs left to right across the screen; at a
# quarter or three-quarter turn it runs up and down, and flipping it would stand the person on
# their head rather than mirror them.
func _apply_mirror() -> void:
	var material := display.material as ShaderMaterial
	if material == null:
		return
	var mirroring: bool = mirror_selfie and _is_selfie()
	var turned_onto_its_side: bool = _quarter_turns() % 2 == 1
	material.set_shader_parameter("mirror_u", mirroring and not turned_onto_its_side)
	material.set_shader_parameter("mirror_v", mirroring and turned_onto_its_side)

# The camera sensor is landscape and this screen is portrait, so the picture arrives on its side.
#
# modules/camera/camera_apple.mm works the correction out for us - handle_rotation_change()
# combines the sensor's own orientation with the current interface orientation and writes the
# result into the feed's transform - but that transform is only applied automatically when a
# feed is used as a 3D environment background. A CameraTexture on a TextureRect ignores it, so
# the rotation is applied to the node here.
#
# Rotating by a quarter turn transposes the rectangle, so the node is sized to the viewport with
# its axes swapped and shifted back over the screen. Half turns keep the rectangle as it is.
func _fit_display() -> void:
	if display == null or not is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	var quarter_turns := _quarter_turns()
	display.pivot_offset = Vector2.ZERO
	display.rotation = float(quarter_turns) * PI / 2.0
	match quarter_turns:
		1:
			display.size = Vector2(viewport_size.y, viewport_size.x)
			display.position = Vector2(viewport_size.x, 0.0)
		2:
			display.size = viewport_size
			display.position = viewport_size
		3:
			display.size = Vector2(viewport_size.y, viewport_size.x)
			display.position = Vector2(0.0, viewport_size.y)
		_:
			display.size = viewport_size
			display.position = Vector2.ZERO

# The engine's own correction, plus a nudge that can be set on the device without a code change.
# The repository already tunes this way: every constant in the tilt behaviours of the Artwork
# That Answers the Tilt of the Phone feature (C1_15) is exported for the same reason.
func _quarter_turns() -> int:
	var from_feed: int = 0
	if _feed != null:
		from_feed = int(round(_feed.feed_transform.get_rotation() / (PI / 2.0)))
	return posmod(from_feed + extra_quarter_turns, 4)

