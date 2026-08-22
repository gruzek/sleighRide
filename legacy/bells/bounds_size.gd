# Bounds2D.gd (Godot 4.4.x)
# Attach to: Bounds (StaticBody2D)
extends StaticBody2D

# Distance from each screen edge inward (pixels)
@export_range(0.0, 500.0, 1.0) var inset_top: float = 48.0
@export_range(0.0, 500.0, 1.0) var inset_bottom: float = 48.0
@export_range(0.0, 500.0, 1.0) var inset_left: float = 48.0
@export_range(0.0, 500.0, 1.0) var inset_right: float = 48.0

# Wall thickness (pixels)
@export_range(1.0, 300.0, 1.0) var thickness: float = 24.0

@onready var ceiling: CollisionShape2D = $Ceiling
@onready var floor: CollisionShape2D = $Floor
@onready var left: CollisionShape2D = $Left
@onready var right: CollisionShape2D = $Right

func _ready() -> void:
	_update_bounds()
	get_viewport().size_changed.connect(_update_bounds)

func _update_bounds() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	# Ceiling (inset from top)
	_apply_wall(
		ceiling,
		Vector2(vp_size.x - inset_left - inset_right, thickness),
		Vector2(vp_size.x * 0.5, inset_top + thickness * 0.5)
	)

	# Floor (inset from bottom)
	_apply_wall(
		floor,
		Vector2(vp_size.x - inset_left - inset_right, thickness),
		Vector2(vp_size.x * 0.5, vp_size.y - inset_bottom - thickness * 0.5)
	)

	# Left wall (inset from left)
	_apply_wall(
		left,
		Vector2(thickness, vp_size.y - inset_top - inset_bottom),
		Vector2(inset_left + thickness * 0.5, vp_size.y * 0.5)
	)

	# Right wall (inset from right)
	_apply_wall(
		right,
		Vector2(thickness, vp_size.y - inset_top - inset_bottom),
		Vector2(vp_size.x - inset_right - thickness * 0.5, vp_size.y * 0.5)
	)

func _apply_wall(wall: CollisionShape2D, size: Vector2, center: Vector2) -> void:
	if wall == null:
		return

	var rect := wall.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		wall.shape = rect

	rect.size = Vector2(max(1.0, size.x), max(1.0, size.y))
	wall.position = center
