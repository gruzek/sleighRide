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

# The tilt in screen coordinates - +x to the right, +y down - with each component a fraction of
# total gravity, so the result is the same number whatever units the platform reports gravity in.
#
# neutral is what the caller considers level, and it is returned unchanged where there is no
# reading at all: the editor, the desktop build, and the simulator. Returning it rather than zero
# is what makes the caller's own deviation from neutral come out at zero there, which is the rest
# pose requirement 7 asks for. Returning zero would be indistinguishable from a phone lying flat,
# which is a real reading and a large deviation from a non-zero neutral.
static func read(neutral: Vector2, noise_floor: float) -> Vector2:
	var gravity := Input.get_gravity()
	var magnitude := gravity.length()
	if magnitude == 0.0:
		return neutral
	# +x to the right, +y down, matching the screen and matching snow/snow.gd.
	var in_plane := Vector2(gravity.x, -gravity.y) / magnitude
	# A phone lying flat and face up puts almost all of gravity through the screen, and what is
	# left in the plane of it is sensor noise. This is the pose where a raw reading shimmers; a
	# phone held upright has a large, steady in-plane component and does not need the guard.
	if in_plane.length() < noise_floor:
		return Vector2.ZERO
	return in_plane
