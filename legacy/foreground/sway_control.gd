# SwayControl.gd (Godot 4.x)
# Attach to each TextureRect (or any Control). Uses the node's current rotation as the default pose.
extends Control

@export_range(0.0, 10.0, 0.01) var sway_speed: float = 0.2          # cycles per second-ish
@export_range(0.0, 10.0, 0.01) var sway_speed_variation: float = 0.1

@export_range(0.0, 60.0, 0.1) var sway_size_deg: float = 2.0        # max rotation offset (degrees)
@export_range(0.0, 60.0, 0.1) var sway_size_variation_deg: float = 0.5

@export_range(0.0, 10.0, 0.01) var sway_delay: float = 0.5          # seconds between sway "bursts"
@export_range(0.0, 10.0, 0.01) var sway_delay_variation: float = 2.0

@export_range(0.0, 10.0, 0.01) var settle_time: float = 1.0         # ease back to default between bursts

var _base_rotation: float
var _phase: float = 0.0

var _current_speed: float
var _current_amp_rad: float
var _next_delay: float
var _timer: float = 0.0
var _burst_time_left: float = 0.0
var _burst_duration: float = 0.0

func _ready() -> void:
	_base_rotation = rotation
	randomize()
	_pick_new_cycle(true)

func _process(delta: float) -> void:
	_timer -= delta

	if _burst_time_left > 0.0:
		_burst_time_left -= delta
		_phase += delta * _current_speed * TAU
		rotation = _base_rotation + sin(_phase) * _current_amp_rad

		# End of burst: schedule next burst delay (we'll settle while waiting)
		if _burst_time_left <= 0.0:
			_timer = _next_delay
	else:
		# Settle back to default while waiting
		if settle_time > 0.0:
			rotation = lerp_angle(rotation, _base_rotation, clamp(delta / settle_time, 0.0, 1.0))
		else:
			rotation = _base_rotation

		# Time to start the next burst
		if _timer <= 0.0:
			_pick_new_cycle(false)

func _pick_new_cycle(initial: bool) -> void:
	_current_speed = max(0.0, sway_speed + randf_range(-sway_speed_variation, sway_speed_variation))

	var amp_deg: float = max(0.0, sway_size_deg + randf_range(-sway_size_variation_deg, sway_size_variation_deg))
	_current_amp_rad = deg_to_rad(amp_deg)

	# --- CHANGE: pick a phase that matches the current rotation so there is no snap ---
	var offset: float = rotation - _base_rotation
	if _current_amp_rad > 0.00001:
		var x: float = clamp(offset / _current_amp_rad, -1.0, 1.0)
		_phase = asin(x)
	else:
		_phase = 0.0

	# Small nudge for variety (won't cause visible jerk)
	_phase += randf_range(-0.15, 0.15)
	# -------------------------------------------------------------------------------

	# How long this sway "burst" lasts (slightly varied, tied to speed so it feels natural)
	_burst_duration = randf_range(0.7, 1.5) * (1.0 / max(0.05, _current_speed))
	_burst_time_left = _burst_duration

	# Delay until next burst
	_next_delay = max(0.0, sway_delay + randf_range(-sway_delay_variation, sway_delay_variation))

	# For the first cycle, start immediately unless you want otherwise
	if initial:
		_timer = 0.0
