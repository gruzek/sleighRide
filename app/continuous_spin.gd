# continuous_spin.gd (C1_15 artwork behaviours) - turns a sprite slowly and forever.
#
# The one behaviour in this feature that reads no sensor. It runs identically on a handset and on
# the desktop, and it has no rest state to return to - only a rest pose it counts up from.
#
# Elapsed time is accumulated and the rotation derived from it, rather than the rotation being
# added to directly. That keeps the authored rotation as the rest pose and keeps this script the
# same shape as the other two: what it writes every frame is derived output, recomputed rather
# than adjusted in place.
#
# It rotates about the node's own origin, like tilt_sway.gd and for the same reason: where a
# sprite turns is set in the scene by centered and offset, not here.
extends Sprite2D

# Degrees per second. A negative value turns the other way. Slow is the intent - the default is
# one full turn a minute.
@export var rotation_degrees_per_second: float = 6.0

var _rest_rotation: float = 0.0
var _elapsed_seconds: float = 0.0

func _ready() -> void:
	_rest_rotation = rotation

func _process(delta: float) -> void:
	_elapsed_seconds += delta
	rotation = _rest_rotation + deg_to_rad(rotation_degrees_per_second) * _elapsed_seconds
