# tilt_drift.gd (C1_15 artwork behaviours) - slides a sprite a short way as the phone is tilted.
#
# It offsets the node's position from the one it is authored with. It stays off an artwork
# scene's root node deliberately: app/sprite_position.gd owns that node's position, overwrites it
# on ready, on viewport resize, and on every exported-property change, and strips it from storage
# so a drag is discarded. A child sprite's position is its own and nothing else writes it.
#
# The map is direct rather than lagging, so a given pose always puts the sprite in the same place
# and it stops when the phone stops. That is the opposite choice from tilt_sway.gd, and it is
# deliberate rather than an inconsistency.
extends Sprite2D

# How far the sprite may ever travel, in pixels of its parent's space. A negative value reverses
# that axis. The two are separate rather than one radius because the halo has more room sideways
# than it has vertically before it slides out from behind the flake it belongs to.
@export var maximum_horizontal_drift_pixels: float = 40.0
@export var maximum_vertical_drift_pixels: float = 28.0

# The deviation from neutral, as a fraction of total gravity, at which full travel is reached on
# either axis.
@export var tilt_at_maximum_drift: float = 0.5

# What counts as level, front to back. Side to side, level is genuinely no roll, so the
# horizontal neutral is a constant zero and is not exported. Front to back it is not: the
# vertical reading runs 1.0 with the phone upright down to 0.0 with it flat and face up, so a
# phone being held normally sits near the top of that range. At 0.75 the authored position falls
# between the two, and the sprite has travel in both directions rather than being pinned at its
# clamp the whole time the phone is held.
@export var vertical_neutral_tilt: float = 0.75

# Below this fraction of total gravity the reading is taken as no tilt at all.
@export var noise_floor: float = 0.05

var _rest_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if tilt_at_maximum_drift <= 0.0:
		push_error("tilt_drift.gd on '%s': tilt_at_maximum_drift is %f. It divides the tilt reading and must be greater than 0. The default is 0.5." % [name, tilt_at_maximum_drift])
		set_process(false)
		return
	_rest_position = position

func _process(_delta: float) -> void:
	var neutral := Vector2(0.0, vertical_neutral_tilt)
	var deviation := (PhoneTilt.read(neutral, noise_floor) - neutral) / tilt_at_maximum_drift
	position = _rest_position + Vector2(
		clampf(deviation.x, -1.0, 1.0) * maximum_horizontal_drift_pixels,
		clampf(deviation.y, -1.0, 1.0) * maximum_vertical_drift_pixels
	)
