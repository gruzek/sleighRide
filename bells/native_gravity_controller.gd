# NativeGravityController.gd (Godot 4.4.1)
extends Node

@export var gravity_strength: float = 1200.0
@export_range(0.0, 1.0, 0.01) var smoothing: float = 0.2
@export var shake_gain: float = 70.0
@export var shake_deadzone: float = 0.25
@export var shake_max_impulse_per_kg: float = 120.0
@export_range(0.0, 1.0, 0.01) var shake_smoothing: float = 0.35

var _lin_acc_smooth: Vector2 = Vector2.ZERO
var _g: Vector2 = Vector2.DOWN
var _shake: Vector2 = Vector2.ZERO

func _gravity_process(_dt: float) -> void:
	var gv: Vector3 = Input.get_gravity()

	# Map device gravity -> 2D screen gravity (+x right, +y down)
	var target := Vector2(gv.x, -gv.y)
	if target.length() < 0.01:
		return

	target = target.normalized()
	_g = _g.lerp(target, smoothing)
	
func _shake_process(dt: float) -> void:
	if Engine.get_physics_frames() % 30 == 0:
		print("accel=", Input.get_accelerometer(), " grav=", Input.get_gravity())
	
	# Total accel (gravity + user motion)
	var av: Vector3 = Input.get_accelerometer()

	# Gravity vector (so we can subtract it)
	var gv: Vector3 = Input.get_gravity()

	# Estimate linear acceleration
	var lin: Vector3 = av - gv

	# Map to 2D (+x right, +y down)
	var lin2: Vector2 = Vector2(lin.x, lin.y)

	# Smooth noise
	_lin_acc_smooth = _lin_acc_smooth.lerp(lin2, shake_smoothing)

	# Deadzone + magnitude
	var mag: float = _lin_acc_smooth.length()
	if mag <= shake_deadzone:
		_shake = Vector2.ZERO
		return

	# Bells should lag opposite the phone’s acceleration
	var dir: Vector2 = -_lin_acc_smooth / mag

	# Convert motion magnitude to an impulse-per-frame (per kg)
	var strength: float = (mag - shake_deadzone) * shake_gain
	var impulse_per_kg: float = clamp(strength * dt, 0.0, shake_max_impulse_per_kg)

	_shake = dir * impulse_per_kg
	
func _apply_forces(_dt: float) -> void:
	# Apply force to each bell
	for n in get_tree().get_nodes_in_group("bells"):
		var body := n as RigidBody2D
		if body == null:
			continue
		# F = m * a  (so heavier bells feel consistent)
		body.apply_central_force(_g * gravity_strength * body.mass)
		# Shake (impulse): already “per kg”, so scale by mass
		if _shake != Vector2.ZERO:
			body.apply_central_impulse(_shake * body.mass)
			
func _physics_process(_dt: float) -> void:
	_gravity_process(_dt)
	_shake_process(_dt)
	_apply_forces(_dt)
