# snow.gd (C1_12 snow) - reads which way the phone says down is, and steers the snow by it.
#
# This is the only place in the effect that touches a sensor, and gravity and damping on
# each layer's material are the only things it writes.
#
# Nothing here listens for a resize, deliberately. Every geometric quantity - the centre,
# the diagonal, where the band sits, how long it is, how large the culling rectangle has
# to be - is re-derived from the viewport every frame, so a window that changed size is
# simply a different rectangle on the next one.
class_name SnowDriver
extends CanvasLayer

# How quickly the snow follows the phone. Snow has inertia and a hand is never still, so a
# direction that tracked the sensor exactly would jitter with every small movement.
@export var response_time_constant_seconds: float = 0.35

# The direction stops updating below this fraction of gravity. Face up on a table, almost
# all of gravity points through the screen and what is left in the plane of it is sensor
# noise; without this the snowfall spins while the phone lies perfectly still.
@export var direction_floor: float = 0.12

# A flat phone still gets this fraction of the fall. At exactly zero, new flakes stall
# outside the screen and the sky empties out over one lifetime.
@export var minimum_fall_fraction: float = 0.15

# How far past the circle that circumscribes the viewport the band sits, and how long it is
# as a multiple of the viewport's diagonal. The diagonal is the widest the viewport ever
# projects onto an axis perpendicular to the fall, so a band that long is never short.
@export var band_margin: float = 60.0
@export var band_length_factor: float = 1.0

# The culling rectangle handed to each layer, as a multiple of the diagonal.
@export var cull_factor: float = 1.5

# Straight down, at full strength. These are the values that stand wherever there is no
# gravity sensor to read - the editor, and any desktop run.
var _angle: float = PI * 0.5
var _tilt: float = 1.0
var _layers: Array[SnowLayer] = []

func _ready() -> void:
	for child in get_children():
		var layer := child as SnowLayer
		if layer != null:
			_layers.append(layer)
	if _layers.is_empty():
		push_error("snow.gd found no SnowLayer children. The snow scene draws nothing without them; add a GPUParticles2D running snow/snow_layer.gd as a child of this node.")

func _process(delta: float) -> void:
	_read_gravity(delta)
	var direction := Vector2.from_angle(_angle)
	var viewport := get_viewport().get_visible_rect()
	var diagonal := viewport.size.length()
	var band_position := viewport.size * 0.5 - direction * (diagonal * 0.5 + band_margin)
	var fall_scale := lerpf(minimum_fall_fraction, 1.0, _tilt)
	for layer in _layers:
		layer.apply(direction, fall_scale, band_position, diagonal * band_length_factor, diagonal * cull_factor)

func _read_gravity(delta: float) -> void:
	var gravity := Input.get_gravity()
	var magnitude := gravity.length()
	# No reading at all, which is every desktop run. The held angle and tilt stand, and
	# those are the authored straight-down at full strength. This is the same hold rule
	# that governs a phone lying flat, arriving at its starting value.
	if magnitude == 0.0:
		return
	# +x to the right, +y down, matching the screen.
	var in_plane := Vector2(gravity.x, -gravity.y)
	var alpha := clampf(delta / response_time_constant_seconds, 0.0, 1.0)
	# The angle is smoothed rather than the vector: lerp_angle takes the shorter way round
	# and has no degenerate case, where lerping two unit vectors and re-normalising has one
	# when they are opposed.
	if in_plane.length() >= magnitude * direction_floor:
		_angle = lerp_angle(_angle, in_plane.angle(), alpha)
	# The ratio, not a length against 9.80665. It is exactly the sine of the tilt angle,
	# and it is the same number whatever units the platform reports gravity in.
	_tilt = lerpf(_tilt, clampf(in_plane.length() / magnitude, 0.0, 1.0), alpha)
