# shake_event.gd (C1_02 shake instrument) - one detected stop, and how hard it was.
#
# A class rather than loose signal arguments so that adding a field later does not break every
# responder already connected to the signal. Every quantity here is computed once, in
# shake_detector.gd; no responder recomputes intensity from magnitude.
class_name ShakeEvent
extends RefCounted

# Peak projected linear acceleration at the stop, in metres per second squared. The measurement.
var magnitude: float

# The same stop placed on a 0 to 1 scale, spaced perceptually rather than linearly.
var intensity: float

# The same stop quantised to a level, counting from 1.
var level: int

# Which end of the stroke this was: +1 or -1 along the current motion axis.
var direction: float

# Engine milliseconds at the moment the stop was detected.
var at_msec: int

func _init(p_magnitude: float, p_intensity: float, p_level: int, p_direction: float, p_at_msec: int) -> void:
	magnitude = p_magnitude
	intensity = p_intensity
	level = p_level
	direction = p_direction
	at_msec = p_at_msec
