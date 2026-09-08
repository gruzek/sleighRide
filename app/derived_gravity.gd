# derived_gravity.gd (C1_20 Android build) - gravity for a phone that has no gravity sensor.
#
# Android's TYPE_GRAVITY is a fused sensor: the platform derives it by combining the
# accelerometer with a gyroscope. A phone with no gyroscope cannot supply it, and `Input.get_gravity()`
# returns a zero vector there rather than an error. The Galaxy A11 measured on 2026-09-08 is such a
# phone - `dumpsys sensorservice` lists an accelerometer and nothing else - and every effect that
# reads the tilt goes still on it while every effect that subtracts gravity gets a reading with 9.8
# metres per second squared still in it.
#
# This file exists so that answering that is one concern in one place. It does not know what the
# tilt is for, it does not know about platforms, and it never decides whether it should be used.
# app/phone_tilt.gd asks it only when the sensor has come back empty.
#
# The estimate is the accelerometer under a low-pass filter. An accelerometer reports gravity plus
# whatever the hand is doing, and the hand's contribution averages to nothing over a second or two
# while gravity does not - so what survives a long enough filter is gravity. That is the same
# technique the platform's own fused sensor falls back on without a gyroscope, and its weakness is
# the same: a sustained acceleration in one direction is indistinguishable from a tilt, and a
# vigorous shake drags the estimate before it settles. Neither matters here, because what reads
# this is snowfall direction and artwork lean rather than anything a person would call precise.
class_name DerivedGravity
extends Object

# How long the filter takes to follow a change, in seconds. Long enough that a shake does not drag
# the estimate around, short enough that turning the phone over is answered while the person is
# still watching. Tuned by eye on a handset, like every other constant in the artwork behaviours.
const SMOOTHING_TIME_CONSTANT_SECONDS: float = 0.6

# Below this, the accelerometer is reporting nothing at all rather than a small reading, which is
# what the editor, the desktop build, and the simulator all do. There is no estimate to be made
# from it and none is offered.
const NO_SENSOR_FLOOR: float = 0.01

static var _estimate: Vector3 = Vector3.ZERO
static var _last_frame: int = -1
static var _last_ticks_msec: int = 0

# The estimated gravity vector, in the accelerometer's own frame and units, so a caller can use it
# exactly where it would have used Input.get_gravity(). Returns a zero vector where there is no
# accelerometer either, matching what the engine does and leaving the caller's own no-reading path
# to handle it.
#
# The filter advances once per rendered frame no matter how many callers ask. Several nodes read
# the tilt on the same frame - the snow, the tree, the drifting artwork - and advancing the filter
# once per caller would make its time constant depend on how many things happened to be on screen.
static func read() -> Vector3:
	var frame := Engine.get_process_frames()
	if frame == _last_frame:
		return _estimate
	var raw := Input.get_accelerometer()
	var now := Time.get_ticks_msec()
	if raw.length() < NO_SENSOR_FLOOR:
		_last_frame = frame
		_last_ticks_msec = now
		return Vector3.ZERO
	# The first reading is taken whole. Filtering up from zero would spend the first second of the
	# screen's life reporting a gravity that points nowhere and a tilt that is wrong.
	if _estimate.length() < NO_SENSOR_FLOOR:
		_estimate = raw
		_last_frame = frame
		_last_ticks_msec = now
		return _estimate
	var delta := float(now - _last_ticks_msec) / 1000.0
	_last_frame = frame
	_last_ticks_msec = now
	# A frame that took an absurd time is a resumed application rather than a slow one, and
	# following it would snap the estimate to whatever the phone happened to be doing at that
	# instant. Clamping is what makes the time constant mean what it says.
	var alpha := clampf(delta / SMOOTHING_TIME_CONSTANT_SECONDS, 0.0, 1.0)
	_estimate = _estimate.lerp(raw, alpha)
	return _estimate
