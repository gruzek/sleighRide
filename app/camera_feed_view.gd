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
# fused Dual, Dual Wide, Triple and TrueDepth virtual cameras. Feeds are therefore chosen by
# name and never by "the first one whose position matches", which happens to give the right
# answer on that handset and would give the TrueDepth camera on one that enumerates differently.
#
# The second is that the first activation always fails when camera permission has not yet been
# answered. modules/camera/camera_apple.mm starts the permission request and returns false
# without waiting, and servers/camera/camera_feed.cpp only marks a feed active when that call
# returns true - so nothing marks it active when the person taps Allow, and the camera runs with
# the engine believing it does not. The cure is to deactivate and activate again once the answer
# has arrived, which is what _await_activation does. Deactivating first matters: the permission
# callback has already built a capture session, and activating over the top of it would overwrite
# the reference to a session still running.
extends Control

# The plain cameras, not the fused virtual ones and not TrueDepth.
const SELFIE_FEED_NAME: String = "Front Camera"
const REAR_FEED_NAME: String = "Back Camera"

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
# Zero is correct and measured: on an iPhone in portrait the feed's own transform reports 90
# degrees and applying exactly that stands the picture upright, on both cameras. The value is
# kept exported rather than removed because it was not obvious - two builds were spent on the
# assumption that the engine's figure needed correcting, and a handset that disagrees can be
# answered here instead of in this file's logic.
@export var extra_quarter_turns: int = 0

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
		push_error("camera_feed_view: this phone reports no camera named `%s`. The screen that opened it has no picture to show and should return to the bell selection screen." % feed_name)
		camera_unavailable.emit()
		return
	display.visible = false
	_bind_textures(_feed.get_id())
	_fit_display()
	_apply_mirror()
	_await_activation(_feed)

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
		_fit_display()
		_apply_mirror()
		display.visible = true
		camera_ready.emit()
	else:
		push_error("camera_feed_view: `%s` did not start within %.1f seconds. Either camera permission was declined or this phone will not give the camera up." % [feed.get_name(), activation_timeout_seconds])
		camera_unavailable.emit()

func _find_feed(feed_name: String) -> CameraFeed:
	for feed in CameraServer.feeds():
		if feed.get_name() == feed_name:
			return feed
	return null

func _is_selfie() -> bool:
	return _feed != null and _feed.get_name() == SELFIE_FEED_NAME

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
