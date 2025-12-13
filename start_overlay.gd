# StartOverlay.gd (Godot 4.4.1)
extends Control

@onready var start_button: Button = $StartButton

func _ready() -> void:
	# Pause the whole game immediately
	get_tree().paused = true

	# Make sure THIS overlay continues processing while paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Wire up the button
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:

	# Unpause game and hide overlay
	get_tree().paused = false
	visible = false
