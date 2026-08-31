# instrument_select.gd (v2 bell selection screen)
#
# Nothing here touches CameraServer. Enumerating feeds and activating one is the Jingle Cam
# screen's business, so no camera permission is requested until the Jingle Cam button has
# actually been pressed.
extends Control

@onready var continue_button: Button = $ContinueButton
@onready var jingle_cam_button: Button = $JingleCamButton

func _ready() -> void:
	if continue_button == null:
		push_error("instrument_select: no Button node named `ContinueButton`. The screen cannot advance to the play screen without it.")
		return
	if jingle_cam_button == null:
		push_error("instrument_select: no Button node named `JingleCamButton`. The screen cannot reach the Jingle Cam without it.")
		return
	continue_button.pressed.connect(_on_continue_pressed)
	jingle_cam_button.pressed.connect(_on_jingle_cam_pressed)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://app/instrument.tscn")

func _on_jingle_cam_pressed() -> void:
	get_tree().change_scene_to_file("res://app/jingle_cam.tscn")
