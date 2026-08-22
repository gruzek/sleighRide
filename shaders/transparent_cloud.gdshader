shader_type canvas_item;

/* Motion / scale */
uniform vec2 cloud_direction = vec2(1.0, 0.0); // direction of drift
uniform float cloud_speed = 0.05;              // how fast it moves
uniform float cloud_scale = 1.8;               // larger = bigger clouds

/* Alpha range */
uniform float min_alpha = 0.25;                // minimum visibility (0..1)
uniform float max_alpha = 1.0;                 // maximum visibility (0..1)

/* Look shaping */
uniform float softness = 0.7;                  // 0..1 (higher = smoother)
uniform float contrast = 1.2;                  // 0.5..3 (higher = more defined patches)
uniform float detail = 2.0;                    // 1..6 (more octaves-ish feel)

/* ---- Simple procedural noise (no textures) ---- */
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	// Smooth interpolation
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	// Lightweight fBm using value noise; 'detail' controls how many layers contribute.
	float sum = 0.0;
	float amp = 0.55;
	float freq = 1.0;

	// Unrolled-ish loop (Godot shaders allow constant loops; keep small for mobile)
	for (int i = 0; i < 6; i++) {
		float layer_on = step(float(i), detail - 1.0); // enables layers up to 'detail'
		sum += layer_on * amp * value_noise(p * freq);
		freq *= 2.0;
		amp *= 0.55;
	}
	return sum; // ~0..1-ish
}

void fragment() {
	vec4 logo = texture(TEXTURE, UV);

	// Animate the noise field
	vec2 p = UV * cloud_scale + TIME * cloud_direction * cloud_speed;

	// Base noise + shaping
	float n = fbm(p);

	// Contrast shaping around mid
	n = pow(clamp(n, 0.0, 1.0), 1.0 / max(0.001, contrast));

	// Softness controls how gently n maps into alpha (higher softness = smoother transitions)
	float s = clamp(softness, 0.0, 1.0);
	n = smoothstep(0.5 - 0.5 * s, 0.5 + 0.5 * s, n);

	// Map to alpha range
	float alpha_mul = mix(min_alpha, max_alpha, n);

	COLOR = vec4(logo.rgb, logo.a * alpha_mul);
}