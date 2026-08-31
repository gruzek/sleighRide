# jingle_cam.gd (C1_16 Jingle Cam screen) - a live camera behind the season's artwork, and a
# shutter that hands the photograph to the phone's own share sheet.
#
# The screen owns three things: getting a camera on screen, taking the picture, and leaving.
# How the camera is chosen and drawn is app/camera_feed_view.gd's business, and this screen
# never touches CameraServer except to ask for the feed list.
#
# The camera list is built here rather than earlier in the flow, so that nothing about the
# camera happens until somebody has actually pressed the Jingle Cam button. Enumerating feeds
# raises no permission prompt; activating one does, and that is camera_feed_view's doing.
extends Control

const BELL_SELECTION_SCENE: String = "res://app/instrument_select.tscn"

# Where the photograph is written before it is handed to the share sheet. The share plugin
# requires the file to live under user://, which on iOS is the application's Documents
# directory - so a photograph is retrievable through the Files application even if the person
# dismisses the share sheet without choosing anything.
const PHOTO_PATH: String = "user://jingle_cam.png"

@onready var camera: Control = $CameraFeedView
@onready var snap_button: Button = $SnapButton
@onready var switch_button: Button = $SwitchCameraButton
@onready var back_button: Button = $BackButton
@onready var share: Share = $Share

func _ready() -> void:
	if camera == null:
		push_error("jingle_cam: no node named `CameraFeedView`. The screen has no camera to show without it.")
		return
	if snap_button == null or switch_button == null or back_button == null:
		push_error("jingle_cam: the screen needs Button nodes named `SnapButton`, `SwitchCameraButton` and `BackButton`. One or more is missing.")
		return
	if share == null:
		push_error("jingle_cam: no `Share` node. The photograph cannot reach the phone's share sheet without it.")
		return
	snap_button.pressed.connect(_on_snap_pressed)
	switch_button.pressed.connect(_on_switch_pressed)
	back_button.pressed.connect(_on_back_pressed)
	camera.camera_unavailable.connect(_on_camera_unavailable)
	# Hidden until the feed list says the phone has two cameras to switch between.
	switch_button.visible = false
	CameraServer.camera_feeds_updated.connect(_on_feeds_updated)
	CameraServer.monitoring_feeds = true
	# `monitoring_feeds` belongs to the server rather than to this screen, so it is still true
	# when the screen is entered a second time. Setting it again changes nothing and emits no
	# `camera_feeds_updated`, which would leave the camera unopened and the switch control
	# hidden for the rest of the session. The list is already built by then, so read it.
	if not CameraServer.feeds().is_empty():
		_on_feeds_updated()

# The feed list arrives some frames after monitoring is enabled rather than immediately, which
# is why this waits on the signal instead of reading CameraServer.feeds() in _ready.
func _on_feeds_updated() -> void:
	if CameraServer.feeds().is_empty():
		return
	if CameraServer.camera_feeds_updated.is_connected(_on_feeds_updated):
		CameraServer.camera_feeds_updated.disconnect(_on_feeds_updated)
	switch_button.visible = camera.has_both_cameras()
	camera.open_selfie()

func _on_switch_pressed() -> void:
	camera.switch()

func _on_back_pressed() -> void:
	camera.close()
	get_tree().change_scene_to_file(BELL_SELECTION_SCENE)

# Requirement 10: a person who declines the camera is returned to the bell selection screen
# rather than left looking at artwork with a hole where their face should be.
func _on_camera_unavailable() -> void:
	camera.close()
	get_tree().change_scene_to_file(BELL_SELECTION_SCENE)

# Requirement 7: no control appears in the photograph.
#
# The photograph is a capture of this screen's viewport and the controls are on that screen, so
# they are hidden, the frame is allowed to actually draw, and only then is the image taken.
# Hiding and capturing in the same call captures the frame that was already drawn, with the
# buttons still in it - permanently, in the file the person keeps and sends.
func _on_snap_pressed() -> void:
	snap_button.disabled = true
	_set_controls_visible(false)
	await RenderingServer.frame_post_draw
	var photograph: Image = get_viewport().get_texture().get_image()
	_set_controls_visible(true)
	snap_button.disabled = false
	var error: int = photograph.save_png(PHOTO_PATH)
	if error != OK:
		push_error("jingle_cam: the photograph could not be written to `%s` (error %d). The share sheet needs a file on disk, so nothing is shared." % [PHOTO_PATH, error])
		return
	share.share_image(
		ProjectSettings.globalize_path(PHOTO_PATH),
		"Holiday Sleigh Bells",
		"My Jingle Cam photo",
		"Taken at the Richmond Symphony's Holiday Sleigh Bells."
	)

func _set_controls_visible(shown: bool) -> void:
	snap_button.visible = shown
	back_button.visible = shown
	# The switch control is only ever on screen when there are two cameras, so showing it again
	# reads its own visibility rule rather than assuming it was visible before.
	switch_button.visible = shown and camera.has_both_cameras()
