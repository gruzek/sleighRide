# sprite_position.gd (v2) - shared placement for artwork scenes and loose sprites.
#
# Artwork is repositioned by editing design_position, never by dragging the node.
# The node's own position is derived output: this script overwrites it on ready, on
# viewport resize, and on every exported-property change in the editor, so a drag is
# discarded at the next recompute.
#
# In the editor the reference rectangle is the design canvas, which is the frame the
# 2D editor draws. Godot's own Control anchors resolve the same way, so what you see
# while authoring is the composition at design size.
@tool
extends Node2D

enum HorizontalAnchor { LEFT, CENTER, RIGHT }
enum VerticalAnchor { TOP, CENTER, BOTTOM }

# LEFT and TOP are 0, CENTER is 1, RIGHT and BOTTOM are 2, so one table serves both axes.
const ANCHOR_RATIOS: Array[float] = [0.0, 0.5, 1.0]

@export var design_position: Vector2 = Vector2.ZERO:
	set(value):
		design_position = value
		_apply()

@export var horizontal_anchor: HorizontalAnchor = HorizontalAnchor.CENTER:
	set(value):
		horizontal_anchor = value
		_apply()

@export var vertical_anchor: VerticalAnchor = VerticalAnchor.TOP:
	set(value):
		vertical_anchor = value
		_apply()

@export var respect_safe_area: bool = false:
	set(value):
		respect_safe_area = value
		_apply()

func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()

# position is derived from design_position, so it is never written into a scene file.
# Without this the editor saves the computed value alongside the authored one, where it
# is indistinguishable from input and goes stale the moment design_position changes.
func _validate_property(property: Dictionary) -> void:
	if property.name == "position":
		property.usage &= ~PROPERTY_USAGE_STORAGE

func _apply() -> void:
	if not is_inside_tree():
		return
	position = _resolve_position()

func _resolve_position() -> Vector2:
	var design_canvas := _design_canvas()
	var reference := _reference_rect(design_canvas)
	var ratio := Vector2(ANCHOR_RATIOS[horizontal_anchor], ANCHOR_RATIOS[vertical_anchor])
	var anchor_in_reference := reference.position + reference.size * ratio
	var anchor_in_design := design_canvas * ratio
	return anchor_in_reference + (design_position - anchor_in_design)

func _design_canvas() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)

func _reference_rect(design_canvas: Vector2) -> Rect2:
	if Engine.is_editor_hint():
		return Rect2(Vector2.ZERO, design_canvas)
	var viewport_rect := get_viewport_rect()
	if not respect_safe_area:
		return viewport_rect
	return safe_area_rect(viewport_rect)

# The safe area is reported in screen coordinates, so it is intersected with the window
# in that same space and then carried across as a fraction of the window. On a phone the
# window is the whole screen and the fractions are the notch and home-indicator insets;
# on a desktop the window sits inside the safe area, the fractions are 0 and 1, and the
# result is the viewport rectangle unchanged.
static func safe_area_rect(viewport_rect: Rect2) -> Rect2:
	var window_position := Vector2(DisplayServer.window_get_position())
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_area := Rect2(DisplayServer.get_display_safe_area()).intersection(Rect2(window_position, window_size))
	var offset_fraction := (safe_area.position - window_position) / window_size
	var size_fraction := safe_area.size / window_size
	return Rect2(viewport_rect.position + viewport_rect.size * offset_fraction, viewport_rect.size * size_fraction)
