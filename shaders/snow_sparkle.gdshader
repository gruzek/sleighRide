shader_type canvas_item;

/* The sparkle: how far the brightness swings, how fast, and how much that rate varies
   from flake to flake. */
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.35;
uniform float sparkle_rate : hint_range(0.0, 8.0) = 1.6;
uniform float sparkle_rate_spread : hint_range(0.0, 1.0) = 0.6;

/* The tumble. These images are radial gradients, symmetric about their own centres, so
   rotating one changes nothing a viewer can see. A real flake turning edge-on gets
   narrower and dimmer, and that is what is done here instead: the quad is squashed on
   its own x axis and dimmed by the same factor. tumble_amount is how narrow it gets at
   its narrowest; at 0.55 a flake never falls below 0.45 of its width, so it thins to a
   paper edge rather than disappearing. */
uniform float tumble_amount : hint_range(0.0, 1.0) = 0.55;
uniform float tumble_rate : hint_range(0.0, 8.0) = 1.8;
uniform float tumble_rate_spread : hint_range(0.0, 1.0) = 0.7;

varying float flake_alpha;

void vertex() {
	/* One number per flake, constant for its whole life, different for every flake. It
	   comes from the process material's animation offset, which is randomised per
	   particle and which nothing here uses for animation, so it is free to carry the
	   seed. Every rhythm below is derived from it, which is what stops the whole
	   snowfall pulsing in lockstep. */
	float seed = INSTANCE_CUSTOM.z;

	float tumble_speed = tumble_rate * mix(1.0 - tumble_rate_spread, 1.0 + tumble_rate_spread, seed);
	float width = mix(1.0, abs(sin(TIME * tumble_speed + seed * TAU)), tumble_amount);
	VERTEX.x *= width;

	float sparkle_speed = sparkle_rate * mix(1.0 - sparkle_rate_spread, 1.0 + sparkle_rate_spread, seed);
	float twinkle = 0.5 + 0.5 * sin(TIME * sparkle_speed + seed * TAU * 3.0);

	// Multiplied together deliberately: a flake edge-on is both narrower and dimmer, and
	// the two happening at once is what reads as a turn rather than as a flicker.
	flake_alpha = mix(1.0 - sparkle_amount, 1.0, twinkle) * width;
}

void fragment() {
	COLOR.a *= flake_alpha;
}
