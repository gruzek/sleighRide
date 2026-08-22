# shake_detector.gd (C1_02 shake instrument) - turns hand motion into ShakeEvents.jingled.
#
# This is the only place the firing rules live. Every constant below was measured from the eight
# iPhone 13 Pro runs recorded on 2026-08-22 and analysed for the C1_09 finding; none is guessed.
#
# Why the projection onto a motion axis, rather than the magnitude of linear acceleration: the
# magnitude does not fall back to zero between the two ends of a stroke when the shaking is hard.
# Measured on the vigorous runs, a magnitude-based detector merged 52 real stops into 3. The
# signed projection separates them because the two ends of a stroke have opposite sign.
#
# Why the peak is tracked and released rather than taken at the first turnover: a vigorous stroke
# is noisy on the way up, and firing at the first sample that dips reports a peak of about 13
# m/s2 where the real one is 53. Replaying the eight recorded runs through this algorithm against
# a whole-run principal-axis analysis of the same data gave 61/61, 36/36, 52/52 and 74/75 events
# once the peak was tracked to its release instead.
extends Node

# Above the still run's largest sample of 4.33, below the smallest real jingle at 6.6.
@export var fire_threshold: float = 6.0

# A stop re-arms once the projection falls back under this fraction of the threshold. A gate
# rather than a timer, because the tightest measured gap between two real stops is 50 ms and any
# fixed refractory period long enough to be useful would start swallowing them.
@export var release_fraction: float = 0.4

# The stop fires once the projection has fallen this far below the peak it reached. Anything
# above about 0.5 behaves identically on the recorded runs; the value matters only in that it
# must not be 1.0, which is the first-dip behaviour that misreads a vigorous stroke.
@export var peak_drop_fraction: float = 0.85

# The measured range of a real stop: 6.6 m/s2 at the gentlest, 102.6 at the hardest.
@export var intensity_floor: float = 6.0
@export var intensity_ceiling: float = 102.6
@export var level_count: int = 5

# How quickly the motion axis follows the hand, and how much motion is required before a sample
# is allowed to influence it. The floor keeps a phone at rest from letting its own sensor noise
# define which way the hand is travelling.
@export var axis_time_constant_seconds: float = 0.5
@export var axis_motion_floor: float = 1.0

# The rolling covariance of linear acceleration, held as three rows.
var _covariance_rows: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _axis: Vector3 = Vector3(0.0, 0.0, 1.0)
var _peak: float = 0.0
var _peak_sign: float = 0.0
var _armed: bool = true
var _last_fired_sign: float = 0.0

# The exported calibration is validated here because three of these values are divisors or
# bounds, and the inspector will accept a value that makes the arithmetic undefined just as
# readily as one that is merely unusual. Each message names the value and the range it must lie
# in, so a mis-set field is fixed rather than diagnosed.
func _ready() -> void:
	if intensity_floor <= 0.0:
		push_error("shake_detector intensity_floor is %f and must be greater than zero; it is the divisor of the intensity scale. The measured value is 6.0." % intensity_floor)
	if intensity_ceiling <= intensity_floor:
		push_error("shake_detector intensity_ceiling is %f and must be greater than intensity_floor, which is %f. The measured values are 102.6 and 6.0." % [intensity_ceiling, intensity_floor])
	if level_count < 1:
		push_error("shake_detector level_count is %d and must be at least 1. The measured value is 5." % level_count)
	if axis_time_constant_seconds <= 0.0:
		push_error("shake_detector axis_time_constant_seconds is %f and must be greater than zero; it is the divisor of the motion-axis smoothing. The measured value is 0.5." % axis_time_constant_seconds)

func _process(delta: float) -> void:
	var linear: Vector3 = Input.get_accelerometer() - Input.get_gravity()
	_update_axis(linear, delta)
	var projection: float = linear.dot(_axis)
	var projection_sign: float = signf(projection)
	# Two ways to re-arm. Falling back near zero is the ordinary one. The second is a change of
	# direction, and it is what makes hard shaking work: on the vigorous runs the projection never
	# returns to the release level between one stop and the next, so without this the detector
	# would stay shut through most of a stroke and report 20 stops where there were 52.
	if absf(projection) < fire_threshold * release_fraction:
		_rearm()
	elif not _armed and projection_sign != _last_fired_sign:
		_rearm()
	if not _armed:
		return
	if absf(projection) >= fire_threshold and (_peak_sign == 0.0 or projection_sign == _peak_sign):
		if absf(projection) > _peak:
			_peak = absf(projection)
			_peak_sign = projection_sign
	if _peak > 0.0 and (projection_sign != _peak_sign or absf(projection) < _peak * peak_drop_fraction):
		_armed = false
		_last_fired_sign = _peak_sign
		_emit(_peak, _peak_sign)
		_peak = 0.0
		_peak_sign = 0.0

func _rearm() -> void:
	_armed = true
	_peak = 0.0
	_peak_sign = 0.0

# One power-iteration step per frame toward the dominant eigenvector of the covariance. The axis
# moves far more slowly than the frame rate, so a single step tracks it, at a cost of about
# fifteen multiply-adds per frame.
func _update_axis(linear: Vector3, delta: float) -> void:
	if linear.length() <= axis_motion_floor:
		return
	var alpha: float = clampf(delta / axis_time_constant_seconds, 0.0, 1.0)
	_covariance_rows[0] = _covariance_rows[0].lerp(linear * linear.x, alpha)
	_covariance_rows[1] = _covariance_rows[1].lerp(linear * linear.y, alpha)
	_covariance_rows[2] = _covariance_rows[2].lerp(linear * linear.z, alpha)
	var next: Vector3 = Vector3(
		_covariance_rows[0].dot(_axis),
		_covariance_rows[1].dot(_axis),
		_covariance_rows[2].dot(_axis))
	# A zero-length result means the iteration has nothing to point at yet; the previous axis is
	# kept rather than normalising a zero vector. This is a degeneracy in the arithmetic, not a
	# missing measurement being papered over.
	if next.length_squared() == 0.0:
		return
	next = next.normalized()
	# The eigenvector is defined only up to sign. Holding it to the side it was already on keeps
	# the direction carried on a ShakeEvent from flipping meaning halfway through a run.
	if next.dot(_axis) < 0.0:
		next = -next
	_axis = next

func _emit(magnitude: float, direction: float) -> void:
	var intensity: float = _intensity_for(magnitude)
	ShakeEvents.jingled.emit(ShakeEvent.new(
		magnitude, intensity, _level_for(intensity), direction, Time.get_ticks_msec()))

# Equal ratios of acceleration map to equal steps of intensity, which is what makes the levels
# perceptually spaced rather than evenly spaced in raw acceleration. Clamping at the ends is the
# correct behaviour for a normalised scale: a shake harder than anything yet measured is the
# loudest the instrument has, not an error.
func _intensity_for(magnitude: float) -> float:
	var span: float = log(intensity_ceiling / intensity_floor)
	return clampf(log(magnitude / intensity_floor) / span, 0.0, 1.0)

func _level_for(intensity: float) -> int:
	return clampi(int(intensity * float(level_count)) + 1, 1, level_count)
