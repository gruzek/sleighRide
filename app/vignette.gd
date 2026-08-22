# vignette.gd (app) - hands the shader the size of the area it is drawing into.
#
# The oval's geometry is stated in fractions of the viewport's width, so the shader has
# to convert a vertical position into that same unit. UV cannot do it alone: it runs 0
# to 1 down the rectangle however tall the rectangle is. This rectangle is anchored to
# the whole viewport, so its own size is the number the shader needs, and a fragment
# shader has no way to read it. This script is that one wire.
@tool
extends ColorRect

func _ready() -> void:
	resized.connect(_publish_size)
	_publish_size()

func _publish_size() -> void:
	# Typed deliberately. A vignette without a ShaderMaterial is a broken scene, and
	# this raises rather than quietly drawing nothing.
	var shader_material: ShaderMaterial = material
	shader_material.set_shader_parameter("viewport_size", size)
	# A rectangle with no width rasterizes no pixels, so the shader never runs and the
	# vignette is silently absent while every file on disk looks correct. It happens when
	# a parent scene overrides the anchors this scene sets for itself. Say so.
	if not Engine.is_editor_hint() and size.x <= 0.0:
		push_error("Vignette is %s and draws nothing. Its parent scene has overridden the full-rect anchors this scene defines; remove layout_mode and anchors_preset from the Vignette instance." % size)
