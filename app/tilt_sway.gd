# tilt_sway.gd (C1_15 artwork behaviours) - leans a sprite the way the phone is tilted side to side.
#
# It rotates the node it is attached to, about that node's own origin, and carries no pivot of
# its own. That is deliberate: a Sprite2D's origin is established in the scene by centered and
# offset, so where the artwork bends is positioned by eye in the editor rather than typed in
# here. app/straight_red_tree.tscn sets that origin at the foot of the trunk, which is what makes
# the tree bend rather than spin.
#
# The authored rotation is the rest pose and is never consumed. Every frame writes rest plus the
# lean rather than adjusting the current value, so repeated frames never compound.
extends Sprite2D

# How far the sprite may ever lean. A negative value leans it the other way.
@export var maximum_sway_degrees: float = 3.0

# The side-to-side tilt, as a fraction of total gravity, at which the full lean is reached. 0.5
# is the phone rolled halfway onto its side; a lower number makes a smaller wrist movement do more.
@export var tilt_at_maximum_sway: float = 0.5

# How quickly the lean follows the phone. A hand is never still, and a sprite this large tracking
# a raw gravity reading would visibly tremble while the phone was held steady.
@export var response_time_constant_seconds: float = 0.35

# Below this fraction of total gravity the reading is taken as no tilt at all.
@export var noise_floor: float = 0.05

var _rest_rotation: float = 0.0
var _sway_radians: float = 0.0

func _ready() -> void:
	if tilt_at_maximum_sway <= 0.0:
		push_error("tilt_sway.gd on '%s': tilt_at_maximum_sway is %f. It divides the tilt reading and must be greater than 0. The default is 0.5." % [name, tilt_at_maximum_sway])
		set_process(false)
		return
	if response_time_constant_seconds <= 0.0:
		push_error("tilt_sway.gd on '%s': response_time_constant_seconds is %f. It divides the frame delta and must be greater than 0. The default is 0.35." % [name, response_time_constant_seconds])
		set_process(false)
		return
	_rest_rotation = rotation

func _process(delta: float) -> void:
	var tilt := PhoneTilt.read(Vector2.ZERO, noise_floor)
	var target := clampf(tilt.x / tilt_at_maximum_sway, -1.0, 1.0) * deg_to_rad(maximum_sway_degrees)
	_sway_radians = lerpf(_sway_radians, target, clampf(delta / response_time_constant_seconds, 0.0, 1.0))
	rotation = _rest_rotation + _sway_radians
