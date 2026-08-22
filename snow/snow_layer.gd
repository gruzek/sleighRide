# snow_layer.gd (C1_12 snow) - one depth layer of falling snow.
#
# A layer owns how heavy its flakes are and how fast they fall; the driver owns which way
# down is and where the flakes come in from. Everything this script writes is derived
# output recomputed every frame, so nothing accumulates and nothing authored in the
# inspector is overwritten.
#
# The values authored in the scene file are not arbitrary. preprocess runs during _ready,
# before the driver's first frame, so the band geometry and gravity a layer opens with are
# the ones the scene file carries. They are authored at their design-canvas values - the
# band a half-diagonal plus a margin above centre, pointing straight down - so the screen
# opens on a full field of snow rather than on a narrow column.
#
# How a flake turns briskly without falling faster and faster: a flake travelling at speed
# v under a sideways pull g turns at g / v, so brisk turning wants a large pull, and a
# large pull with nothing opposing it has a flake leaving the screen many times faster
# than it entered. The layer's material therefore carries damping in its friction form,
# where the damping value is a rate that pulls the flake toward a terminal speed rather
# than a deceleration subtracted from it. This is why the driver writes gravity and never
# touches damping: a fixed rate means the terminal speed follows the pull, so a phone
# tilted back gives slower snow rather than snow that stalls.
#
# Both numbers were measured on screen rather than derived, because neither form of
# damping behaves the way its documentation reads. Damping in its default form, a constant
# deceleration, does not trim acceleration at all: at eight tenths of the pull it stops the
# snow dead and nothing reaches the screen. Friction damping does give a terminal speed,
# but it is roughly thirty times stronger than treating the rate as per-second would
# predict, which is why the rate here is hundredths rather than units, and why the pull is
# in the high hundreds rather than the low hundreds. Change either and check on screen that
# snow still reaches the bottom of the frame; the arithmetic will not tell you.
class_name SnowLayer
extends GPUParticles2D

# How hard this layer's flakes are pulled. Large, deliberately: it is what turns a flake,
# and the material's friction damping is what keeps it from running away. The terminal
# speed is this divided by the material's damping rate.
@export var fall_strength: float = 520.0

func apply(direction: Vector2, fall_scale: float, band_position: Vector2, band_length: float, cull_span: float) -> void:
	position = band_position
	# The node's local +X points downwind, so the emission box's x extent is the band's
	# thickness and its y extent is the band's length.
	rotation = direction.angle()

	# Typed deliberately. A snow layer without a ParticleProcessMaterial is a broken
	# scene, and this raises rather than quietly emitting nothing.
	var process: ParticleProcessMaterial = process_material
	process.gravity = Vector3(direction.x, direction.y, 0.0) * fall_strength * fall_scale
	process.emission_box_extents = Vector3(process.emission_box_extents.x, band_length * 0.5, 0.0)

	# The node spends its whole life outside the viewport, and this rectangle is measured
	# in the node's own space. At the default the system is culled and no snow is drawn
	# anywhere, which looks like a broken shader rather than like a culling rectangle.
	visibility_rect = Rect2(-cull_span * 0.5, -cull_span * 0.5, cull_span, cull_span)
