# NativeGravityController.gd (Godot 4.4.1)
extends Node

@export var gravity_strength: float = 1200.0
@export_range(0.0, 1.0, 0.01) var smoothing: float = 0.2

var _g: Vector2 = Vector2.DOWN

func _physics_process(_dt: float) -> void:
	var gv: Vector3 = Input.get_gravity()

	# Quick sanity check (remove later)
	if Engine.get_physics_frames() % 30 == 0:
		print("Input.get_gravity() = ", gv)

	# Map device gravity -> 2D screen gravity (+x right, +y down)
	var target := Vector2(gv.x, -gv.y)
	if target.length() < 0.01:
		return

	target = target.normalized()
	_g = _g.lerp(target, smoothing)

	# Apply force to each bell
	for n in get_tree().get_nodes_in_group("bells"):
		var body := n as RigidBody2D
		if body == null:
			continue
		# F = m * a  (so heavier bells feel consistent)
		body.apply_central_force(_g * gravity_strength * body.mass)
