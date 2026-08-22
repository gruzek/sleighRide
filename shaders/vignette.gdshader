shader_type canvas_item;

/* The oval, in fractions of the viewport's width. Both radii scale from the same
   number, which is what holds the proportion fixed on any screen. */
uniform vec2 oval_center = vec2(0.5, 0.0881856);
uniform vec2 oval_radius = vec2(0.6496701, 0.4997526);

/* The look */
uniform vec3 vignette_color : source_color = vec3(0.07450980, 0.10196078, 0.16862746);
uniform float peak_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float core_radius : hint_range(0.0, 1.0) = 0.45;
uniform float edge_softness : hint_range(0.1, 4.0) = 1.0;

/* Written by app/vignette.gd whenever the rectangle resizes. The rectangle is
   anchored to the whole viewport, so this is the viewport's size in design-canvas
   units. A fragment shader has no way to read it for itself: UV runs 0 to 1 down
   the rectangle however tall the rectangle is. */
uniform vec2 viewport_size = vec2(1080.0, 1920.0);

void fragment() {
	float w = max(viewport_size.x, 1.0);
	vec2 here = UV * viewport_size;
	vec2 offset = (here - oval_center * w) / (oval_radius * w);

	// Distance from the centre as a fraction of the distance to the oval's own edge:
	// 0 at the centre, 1 everywhere on the boundary, whatever the oval's proportions.
	float elliptical_radius = length(offset);

	float fade = smoothstep(core_radius, 1.0, elliptical_radius);
	float alpha = pow(1.0 - fade, edge_softness);

	// The colour is constant and only the alpha varies. The image this replaced was
	// flattened onto white before its alpha channel was written, so its fade carried
	// white in the colour channels; holding one colour is what makes that impossible.
	COLOR = vec4(vignette_color, peak_alpha * alpha);
}
