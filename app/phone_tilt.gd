# phone_tilt.gd (C1_15 artwork behaviours) - the one place the device's gravity vector becomes a
# tilt in screen coordinates.
#
# Two behaviour scripts need the same reading and the same rejection rule, and the mapping they
# share is iOS-shaped. docs/system_design.md records that the engine reports the gravity vector
# in opposite directions on iOS and Android and that no Android handset has been measured; when
# that sign is settled it is settled here for both callers.
#
# snow/snow.gd carries its own copy of the same mapping and is deliberately not routed through
# this. Editing a working sensor path is not this feature's business, and the two copies are
# named together in the platform notes so whoever fixes one finds the other.
class_name PhoneTilt
extends Object

# Whether Android reports gravity the opposite way round from iOS.
#
# **Measured on 2026-09-08 and the answer is no.** docs/system_design.md had recorded the opposite
# since the project began, on documentation rather than on a handset, and it was wrong: with this
# set to true the snow on a Galaxy A11 fell upward. Godot hands the same vector up from both
# platforms, so nothing needs correcting and this stays false.
#
# It is kept rather than deleted because the claim outlived several features and would be made
# again by the next person to read the engine's Android notes. This is the record that it was
# tested. If a handset ever does disagree, this is still the one line to change, because every
# caller reads gravity through gravity() below rather than reading the sensor itself.
const ANDROID_GRAVITY_IS_INVERTED: bool = false

# The device's gravity vector, corrected for the platform.
#
# This is the single place the platform difference lives. snow/snow.gd needs the raw in-plane
# vector for its own angle smoothing and cannot use read() below, so it calls this instead: the
# correction is shared, and neither caller's own logic is disturbed by sharing it.
#
# Linear acceleration is deliberately not routed through here. shake/ and snow/ both compute it as
# accelerometer minus gravity, where the platform difference cancels, and that cancellation is the
# reason the shake detector was built on that quantity and nothing else.
static func gravity() -> Vector3:
	var reading := Input.get_gravity()
	# A phone with no gyroscope cannot supply the fused gravity sensor and returns a zero vector
	# rather than an error, which would leave the snow falling in its authored direction forever.
	# app/derived_gravity.gd estimates it from the accelerometer instead. Asking only when the
	# sensor has come back empty is what keeps a phone that has the sensor on exactly the path it
	# has always been on.
	if reading.length() == 0.0:
		reading = DerivedGravity.read()
	if ANDROID_GRAVITY_IS_INVERTED and OS.get_name() == "Android":
		return -reading
	return reading

# Linear acceleration: what the hand is doing, with gravity taken out.
#
# This is the second half of the same problem. shake/shake_detector.gd and snow/snow.gd both wrote
# `Input.get_accelerometer() - Input.get_gravity()` directly, which subtracts nothing on a phone
# whose gravity sensor reads zero and hands the detector a signal with 9.8 metres per second
# squared still in it - against constants that were every one of them measured on gravity-subtracted
# data. Routing the subtraction through here gives those callers the estimate as well.
#
# The platform sign is deliberately not applied. It cancels in the subtraction, which is the reason
# the shake detector was built on this quantity and nothing else, and applying it to one term of a
# difference would break exactly the property that makes it portable.
static func linear_acceleration() -> Vector3:
	var accelerometer := Input.get_accelerometer()
	var reading := Input.get_gravity()
	if reading.length() == 0.0:
		reading = DerivedGravity.read()
	return accelerometer - reading

# The tilt in screen coordinates - +x to the right, +y down - with each component a fraction of
# total gravity, so the result is the same number whatever units the platform reports gravity in.
#
# neutral is what the caller considers level, and it is returned unchanged where there is no
# reading at all: the editor, the desktop build, and the simulator. Returning it rather than zero
# is what makes the caller's own deviation from neutral come out at zero there, which is the rest
# pose requirement 7 asks for. Returning zero would be indistinguishable from a phone lying flat,
# which is a real reading and a large deviation from a non-zero neutral.
static func read(neutral: Vector2, noise_floor: float) -> Vector2:
	var reading := PhoneTilt.gravity()
	var magnitude := reading.length()
	if magnitude == 0.0:
		return neutral
	# +x to the right, +y down, matching the screen and matching snow/snow.gd.
	var in_plane := Vector2(reading.x, -reading.y) / magnitude
	# A phone lying flat and face up puts almost all of gravity through the screen, and what is
	# left in the plane of it is sensor noise. This is the pose where a raw reading shimmers; a
	# phone held upright has a large, steady in-plane component and does not need the guard.
	if in_plane.length() < noise_floor:
		return Vector2.ZERO
	return in_plane
