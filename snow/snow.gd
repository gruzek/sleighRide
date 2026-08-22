# snow.gd (C1_12 snow) - reads which way the phone says down is, and steers the snow by it.
#
# This is the only place in the effect that touches a sensor. It reads two things from it and
# writes only world state to each layer: which way the snow is being pulled, and how hard the
# phone is being shaken. What a layer does with either is the layer's business.
#
# Nothing here listens for a resize, deliberately. Every geometric quantity - the centre, the
# diagonal, where the band sits, how long it is, how large the culling rectangle has to be -
# is re-derived from the viewport every frame, so a window that changed size is simply a
# different rectangle on the next one.
#
# The snow never emits on ShakeEvents and never listens to it. It reads the accelerometer for
# itself so that a screen gains the whole effect by adding one node, including screens with no
# instrument on them - the instructions screen has no shake detector, and the detector is
# deliberately not global, so adding one there would put a second detector in the flow and
# double-fire the bells on the play screen.
#
# This is a Node2D rather than a CanvasLayer because the layers draw at two different depths:
# the nearest passes over the screen's artwork and text, the other two behind them but still in
# front of the vignette. A CanvasLayer cannot do that - its number beats any z-ordering inside
# it, so it lands wholly in front of the screen's canvas or wholly behind it. Living in the
# same canvas as the artwork means the layers sort against it by z_index, which is authored on
# each layer in snow.tscn.
#
# The cost is the one thing the effect asks of a host: the host's own backdrop must sit below
# the back snow. On the instructions screen that is z_index -3 on the background and -2 on the
# vignette, leaving the content at its default 0. A screen that skips this gets its back snow
# hidden behind its own background, because "behind the content but in front of the vignette"
# is a claim about the host's stack that the snow cannot make on its own.
class_name SnowDriver
extends Node2D

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

# The shake, on the scale the C1_09 measurements established: 6.0 metres per second squared
# sits above the largest sample a still hand produced and below the gentlest real jingle, and
# 102.6 is the hardest shake recorded. Spaced by ratio rather than by difference, so that
# equal ratios of acceleration are equal steps of agitation, exactly as the detector's own
# intensity scale is. A shake that sounds a bell and a shake that stirs the snow are the same
# shake, and these are the numbers that make that true.
@export var shake_floor: float = 6.0
@export var shake_ceiling: float = 102.6

# Agitation rises fast and falls slowly. The fall is the settle: it is the whole of what makes
# a shaken globe look like it is coming to rest, and every other shake response is derived
# from it, so there is one timing here rather than four.
@export var agitation_attack_seconds: float = 0.12
@export var agitation_release_seconds: float = 1.6

# How far the flakes are thrown against the hand's motion, in multiples of a layer's own pull.
# This is the inertia that reads as a globe rather than as wind, and it is smoothed only
# lightly: the reversal at each end of a stroke is the sloshing and must survive.
@export var swing_gain: float = 1.8
@export var swing_time_constant_seconds: float = 0.08

# What the fall is reduced to at full agitation, so a hard shake stops the snow falling and
# leaves it tumbling in place. Proportional, so a gentle shake only disturbs.
@export var hang_floor: float = 0.15

# Straight down, at full strength, unshaken. These are the values that stand wherever there is
# no gravity sensor to read - the editor, and any desktop run.
var _angle: float = PI * 0.5
var _tilt: float = 1.0
var _agitation: float = 0.0
var _swing: Vector2 = Vector2.ZERO
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
	_read_shake(delta)
	var direction := Vector2.from_angle(_angle)
	var viewport := get_viewport().get_visible_rect()
	var centre := viewport.size * 0.5
	var diagonal := viewport.size.length()
	# The pull, in multiples of each layer's own fall strength: the steady fall, reduced by
	# how flat the phone is and again by how hard it is being shaken, plus the swing.
	var fall_scale := lerpf(minimum_fall_fraction, 1.0, _tilt) * lerpf(1.0, hang_floor, _agitation)
	var fall := direction * fall_scale + _swing
	# As the snow is agitated the source slides in from the band to the middle of the screen,
	# so that the flakes the bloom adds appear in view rather than off it - snow kicked up off
	# the base of a globe, rather than more snow arriving from the sky.
	var band := centre - direction * (diagonal * 0.5 + band_margin)
	var source := band.lerp(centre, _agitation)
	for layer in _layers:
		layer.apply(direction, fall, _agitation, source, diagonal * band_length_factor, diagonal * cull_factor)

func _read_gravity(delta: float) -> void:
	var gravity := Input.get_gravity()
	var magnitude := gravity.length()
	# No reading at all, which is every desktop run. The held angle and tilt stand, and those
	# are the authored straight-down at full strength. This is the same hold rule requirement 3
	# specifies, arriving at its starting value.
	if magnitude == 0.0:
		return
	# +x to the right, +y down, matching the screen.
	var in_plane := Vector2(gravity.x, -gravity.y)
	var alpha := clampf(delta / response_time_constant_seconds, 0.0, 1.0)
	# The angle is smoothed rather than the vector: lerp_angle takes the shorter way round and
	# has no degenerate case, where lerping two unit vectors and re-normalising has one when
	# they are opposed.
	if in_plane.length() >= magnitude * direction_floor:
		_angle = lerp_angle(_angle, in_plane.angle(), alpha)
	# The ratio, not a length against 9.80665. It is exactly the sine of the tilt angle, and it
	# is the same number whatever units the platform reports gravity in.
	_tilt = lerpf(_tilt, clampf(in_plane.length() / magnitude, 0.0, 1.0), alpha)

func _read_shake(delta: float) -> void:
	# Gravity subtracted out leaves the hand's own motion. This is the same isolation
	# shake/shake_detector.gd performs, and for the same reason.
	var linear := Input.get_accelerometer() - Input.get_gravity()
	var magnitude := linear.length()
	var target := 0.0
	if magnitude > shake_floor:
		target = clampf(log(magnitude / shake_floor) / log(shake_ceiling / shake_floor), 0.0, 1.0)
	var rise := target > _agitation
	var constant := agitation_attack_seconds if rise else agitation_release_seconds
	_agitation = lerpf(_agitation, target, clampf(delta / constant, 0.0, 1.0))
	# Against the motion, not with it: the flakes are what stays put while the phone moves.
	var throw := Vector2(-linear.x, linear.y) / shake_ceiling * swing_gain
	_swing = _swing.lerp(throw, clampf(delta / swing_time_constant_seconds, 0.0, 1.0))
