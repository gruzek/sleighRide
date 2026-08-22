# instrument_select.gd (v2 bell selection screen)
extends Control

@onready var continue_button: Button = $ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://app/instrument.tscn")
