# instrument.gd (v2 play screen) - draws the bell chosen on the selection screen.
extends Control

@onready var holder: Node2D = $InstrumentHolder

func _ready() -> void:
	var chosen := InstrumentSelection.chosen
	if chosen == null:
		push_error("instrument: no bell has been chosen, so there is nothing to draw. Reach this screen through the flow, which starts at v2/main.tscn.")
		return
	holder.add_child(chosen.artwork.instantiate())
