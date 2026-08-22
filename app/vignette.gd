# vignette.gd (app) - sizes the vignette to the screen and tells the shader how big it is.
#
# Two jobs, both forced rather than inherited.
#
# The rectangle takes the whole drawable area. It sets its own position and size instead
# of relying on anchors, because an anchor preset applied to the instance in a parent
# scene collapses the rectangle to nothing, and a rectangle with no area rasterizes no
# pixels: the vignette vanishes with every file on disk still looking correct and no
# error reported anywhere. Placement is derived output, recomputed on ready and on every
# viewport resize, the same arrangement sprite_position.gd uses for the artwork scenes.
#
# The oval's geometry is stated in fractions of that area's width, so the shader needs the
# width in pixels. UV cannot supply it: it runs 0 to 1 down the rectangle however tall the
# rectangle is. This script is the only wire that can carry it.
@tool
extends ColorRect

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()

# position, size and the anchors are all derived from the viewport, so they are never
# written into a scene file. Without this the editor saves the computed values alongside
# the authored ones, where they are indistinguishable from input and go stale.
func _validate_property(property: Dictionary) -> void:
	if property.name in ["position", "size", "anchor_left", "anchor_top", "anchor_right",
			"anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE

func _fit() -> void:
	if not is_inside_tree():
		return
	var reference := _reference_rect()
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	global_position = reference.position
	size = reference.size
	# Typed deliberately. A vignette without a ShaderMaterial is a broken scene, and this
	# raises rather than quietly drawing nothing.
	var shader_material: ShaderMaterial = material
	shader_material.set_shader_parameter("viewport_size", size)

# In the editor the reference is the design canvas, which is the frame the 2D editor
# draws, so what is authored is the composition at design size. At runtime it is whatever
# the device actually gave us.
func _reference_rect() -> Rect2:
	if Engine.is_editor_hint():
		return Rect2(Vector2.ZERO, Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width")),
			float(ProjectSettings.get_setting("display/window/size/viewport_height"))))
	return get_viewport_rect()
