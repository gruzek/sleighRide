# safe_area_margin.gd (v2) - holds a bottom-anchored control clear of the home indicator.
#
# Godot's Control anchoring measures from the physical window edge and knows nothing
# about the safe area, so a bottom-anchored button can land under the home indicator.
#
# The base offsets are the authored values, measured from the bottom of the design
# canvas. offset_top and offset_bottom are derived output: this script sets them from
# the base plus the current inset rather than adjusting them in place, so repeated
# recomputes never compound and the control keeps its authored height.
@tool
extends Control

const SpritePosition := preload("res://v2/sprite_position.gd")

@export var base_offset_top: float = -207.0:
	set(value):
		base_offset_top = value
		_apply()

@export var base_offset_bottom: float = -97.0:
	set(value):
		base_offset_bottom = value
		_apply()

func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()

func _apply() -> void:
	if not is_inside_tree():
		return
	var inset := _safe_area_bottom_inset()
	offset_top = base_offset_top - inset
	offset_bottom = base_offset_bottom - inset

func _safe_area_bottom_inset() -> float:
	if Engine.is_editor_hint():
		return 0.0
	var viewport_rect := get_viewport_rect()
	var safe_area := SpritePosition.safe_area_rect(viewport_rect)
	return viewport_rect.size.y - (safe_area.position.y + safe_area.size.y)
