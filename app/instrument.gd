# instrument.gd (play screen) - draws the bell chosen on the selection screen.
extends Control

@onready var holder: Node2D = $InstrumentHolder
@onready var back_button: Button = $BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	var chosen := InstrumentSelection.chosen
	if chosen == null:
		push_error("instrument: no bell has been chosen, so there is nothing to draw. Reach this screen through the flow, which starts at res://app/main.tscn.")
		return
	holder.add_child(chosen.artwork.instantiate())

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://app/instrument_select.tscn")
