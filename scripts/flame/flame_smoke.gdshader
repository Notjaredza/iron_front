shader_type spatial;
// Flamethrower round (Question Chat, 2026-11-10): the black oily smoke. Lit, faceted, opaque (old smoke shrinks
// away instead of fading, like the explosion smoke). The undersides glow orange while the fire under them is close.
// INSTANCE_CUSTOM: x seed, y fire glow 0..1, z grey (linear), w warmth.
render_mode cull_back, depth_draw_opaque;

varying flat vec3 v_col;
varying flat float v_glow;

float fl_hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	float fh = fl_hash(NORMAL + vec3(INSTANCE_CUSTOM.x));
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = vec3(1.0, 0.93 - 0.05 * INSTANCE_CUSTOM.w, 0.86 - 0.1 * INSTANCE_CUSTOM.w) * INSTANCE_CUSTOM.z * (0.7 + 0.6 * fh);
	v_glow = INSTANCE_CUSTOM.y * clamp(-0.15 - wn.y * 1.1, 0.0, 1.0) * (0.5 + 0.8 * fh);
}

void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
	EMISSION = vec3(1.0, 0.36, 0.07) * 1.6 * v_glow;
}
