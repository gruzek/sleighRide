# instrument_select.gd (v2 bell selection screen)
#
# Nothing here touches CameraServer. Enumerating feeds and activating one is the Jingle Cam
# screen's business, so no camera permission is requested until the Jingle Cam button has
# actually been pressed.
#
# There is no continue button. The carousel's centred bell is the control that advances the
# flow, and it reports a tap on itself through `centre_tapped`; the navigation is done here
# rather than in the carousel, which has never known that screens exist.
extends Control

@onready var carousel: InstrumentCarousel = $InstrumentSelector
@onready var jingle_cam_button: Button = $JingleCamButton

func _ready() -> void:
	if carousel == null:
		push_error("instrument_select: no node named `InstrumentSelector` carrying instrument_carousel.gd. Tapping the centred bell is what advances to the play screen, so the screen has no way forward without it.")
		return
	if jingle_cam_button == null:
		push_error("instrument_select: no Button node named `JingleCamButton`. The screen cannot reach the Jingle Cam without it.")
		return
	carousel.centre_tapped.connect(_on_centre_tapped)
	jingle_cam_button.pressed.connect(_on_jingle_cam_pressed)

# Deferred, and the Jingle Cam handler below is not, because the two arrive by different
# routes. A button's `pressed` fires once the viewport has finished with the event, but
# `centre_tapped` is emitted from the carousel's _unhandled_input while the engine is still
# walking that event through the tree. Replacing the scene there tears down the node the
# engine is about to return into.
func _on_centre_tapped() -> void:
	get_tree().change_scene_to_file.call_deferred("res://app/instrument.tscn")

func _on_jingle_cam_pressed() -> void:
	get_tree().change_scene_to_file("res://app/jingle_cam.tscn")
