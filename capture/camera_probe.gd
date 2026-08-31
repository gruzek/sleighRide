# camera_probe.gd (C1_16 device probe) - reports what this phone's cameras actually are, on screen.
#
# There is no camera in the editor and none in the simulator, so the only way to learn what a
# handset reports is to run this on one. It answers the questions the Jingle Cam feature's
# display path depends on: how many feeds there are, what each one is called, which way each
# points, what image format each delivers, and whether a format list came back at all.
#
# It reports twice, and the second report is the one that matters. A feed that has never been
# activated has not yet been asked for a frame, so its data type is whatever the feed was
# constructed with and its format list may be empty. Both can change the moment the camera is
# actually turned on, and a display path built against the values read before activation is
# built against placeholders.
#
# It draws its findings onto the screen rather than printing them, so they can be read without
# attaching the phone to Xcode. It is reached by pointing run/main_scene at it, the same way
# capture/shake_capture.tscn is reached, and restoring the title screen afterwards is part of
# finishing with it.
#
# The feed list itself is built asynchronously: enabling monitoring starts the enumeration and
# the feeds arrive some frames later on camera_feeds_updated. Reading the list straight after
# enabling monitoring reports no cameras on a phone that has eight.
extends Control

# Long enough for the iOS permission prompt to be answered and for frames to start arriving.
# The activation report is taken once, after this, rather than polled.
const SECONDS_BEFORE_ACTIVATION_REPORT: float = 6.0

# Shorter than the first wait: by the time the retry runs, permission has already been answered
# and there is no dialog to wait on, only frames to start arriving.
const SECONDS_BEFORE_RETRY_REPORT: float = 3.0

@onready var report: Label = $Report

var _inventory: PackedStringArray = PackedStringArray()
var _activation: PackedStringArray = PackedStringArray()
var _activation_started: bool = false

func _ready() -> void:
	if report == null:
		push_error("camera_probe: no Label node named `Report`. The probe draws its findings into that node and has nowhere to write without it.")
		return
	CameraServer.camera_feeds_updated.connect(_on_feeds_updated)
	_activation.append("Waiting for the camera list...")
	_redraw()
	CameraServer.monitoring_feeds = true

func _on_feeds_updated() -> void:
	var feeds: Array[CameraFeed] = CameraServer.feeds()
	_inventory = PackedStringArray()
	_inventory.append("Godot %s" % Engine.get_version_info()["string"])
	_inventory.append("Cameras found: %d" % feeds.size())
	_inventory.append("")
	for index in feeds.size():
		var feed: CameraFeed = feeds[index]
		_inventory.append("[%d] %s  %s" % [index, _position_name(feed.get_position()), feed.get_name()])
		_inventory.append("     %s  formats: %d" % [_datatype_name(feed.get_datatype()), (feed.formats as Array).size()])
	_redraw()
	if not _activation_started and feeds.size() > 0:
		_activation_started = true
		_activate_first_selfie(feeds)

# The whole point of the second report: turn one camera on and read the same values again.
func _activate_first_selfie(feeds: Array[CameraFeed]) -> void:
	var chosen: CameraFeed = null
	var chosen_index: int = -1
	for index in feeds.size():
		if feeds[index].get_position() == CameraFeed.FEED_FRONT:
			chosen = feeds[index]
			chosen_index = index
			break
	if chosen == null:
		_activation = PackedStringArray(["No FRONT feed to activate."])
		_redraw()
		return
	_activation = PackedStringArray(["Activating [%d] %s ..." % [chosen_index, chosen.get_name()], "Allow the camera when asked."])
	_redraw()
	# set_active is the setter for feed_is_active and returns nothing, so whether the camera
	# actually came on is read back from the property rather than from a return value.
	chosen.set_active(true)
	var accepted_immediately: bool = chosen.feed_is_active
	await get_tree().create_timer(SECONDS_BEFORE_ACTIVATION_REPORT).timeout
	_activation = PackedStringArray()
	_activation.append("AFTER ACTIVATING [%d] %s" % [chosen_index, chosen.get_name()])
	_activation.append("  active immediately: %s" % str(accepted_immediately))
	_activation.append("  active now: %s" % str(chosen.feed_is_active))
	_activation.append("  datatype: %s" % _datatype_name(chosen.get_datatype()))
	var formats: Array = chosen.formats
	_activation.append("  formats: %d" % formats.size())
	if formats.size() > 0:
		_activation.append("  first: %s" % str(formats[0]))
	_redraw()
	if not chosen.feed_is_active:
		await _retry_activation(chosen, chosen_index)

# The retry the engine does not do for itself.
#
# modules/camera/camera_apple.mm returns false from activate_feed() when camera permission has
# not yet been answered, having started the permission request and left a completion handler to
# build the capture session later. servers/camera/camera_feed.cpp only marks a feed active when
# that call returns true, and nothing runs again once the person taps Allow - so on the launch
# where permission is first granted the camera really is running and the feed reports inactive
# for the rest of the session.
#
# Deactivating first rather than simply asking again: the completion handler has already built
# a capture session and assigned it, and activating over the top of that would overwrite the
# pointer to a session still running.
func _retry_activation(feed: CameraFeed, index: int) -> void:
	_activation.append("")
	_activation.append("RETRYING (permission should now be answered)")
	_redraw()
	feed.set_active(false)
	feed.set_active(true)
	await get_tree().create_timer(SECONDS_BEFORE_RETRY_REPORT).timeout
	_activation.append("AFTER RETRY [%d] %s" % [index, feed.get_name()])
	_activation.append("  active now: %s" % str(feed.feed_is_active))
	_activation.append("  datatype: %s" % _datatype_name(feed.get_datatype()))
	var formats: Array = feed.formats
	_activation.append("  formats: %d" % formats.size())
	if formats.size() > 0:
		_activation.append("  first: %s" % str(formats[0]))
	_redraw()

func _redraw() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append_array(_inventory)
	lines.append("")
	lines.append("----------------")
	lines.append_array(_activation)
	report.text = "\n".join(lines)

# Both names carry the raw number as well as the reading, so a value this probe does not know
# about is shown rather than hidden. A probe that quietly renders an unexpected enum as one of
# the expected ones is worse than no probe.
func _position_name(position: int) -> String:
	match position:
		CameraFeed.FEED_UNSPECIFIED:
			return "UNSPEC"
		CameraFeed.FEED_FRONT:
			return "FRONT "
		CameraFeed.FEED_BACK:
			return "BACK  "
	return "UNRECOGNISED (%d)" % position

func _datatype_name(datatype: int) -> String:
	match datatype:
		CameraFeed.FEED_NOIMAGE:
			return "NOIMAGE (%d)" % datatype
		CameraFeed.FEED_RGB:
			return "RGB (%d)" % datatype
		CameraFeed.FEED_YCBCR:
			return "YCBCR (%d)" % datatype
		CameraFeed.FEED_YCBCR_SEP:
			return "YCBCR_SEP (%d)" % datatype
		CameraFeed.FEED_EXTERNAL:
			return "EXTERNAL (%d)" % datatype
	return "UNRECOGNISED (%d)" % datatype
