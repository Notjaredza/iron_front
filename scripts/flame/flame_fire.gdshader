shader_type spatial;
// Flamethrower round (Question Chat, 2026-11-10): the fire billows. The same faceted look as the explosions
// (fx_fire): lumpy flat-faced shapes, every face its own heat, white-hot through yellow and orange to dark red and
// soot. The heat comes from FlameFx each frame (INSTANCE_CUSTOM.y), so the jet, licks and ground fires cool as they go.
// INSTANCE_CUSTOM: x seed, y heat (1 white-hot ... 0 cold soot), z how much the faces differ.
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

varying flat vec3 v_col;

float fl_hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// HDR fire colour, so the glow picks the hot part up.
vec3 fl_heat(float h) {
	h = clamp(h, 0.0, 1.0);
	vec3 c0 = vec3(0.035, 0.028, 0.024);
	vec3 c1 = vec3(0.70, 0.12, 0.025) * 1.3;
	vec3 c2 = vec3(1.0, 0.40, 0.07) * 2.0;
	vec3 c3 = vec3(1.0, 0.64, 0.24) * 2.9;
	vec3 c4 = vec3(1.0, 0.88, 0.62) * 4.2;
	if (h < 0.22) return mix(c0, c1, h / 0.22);
	if (h < 0.48) return mix(c1, c2, (h - 0.22) / 0.26);
	if (h < 0.75) return mix(c2, c3, (h - 0.48) / 0.27);
	return mix(c3, c4, (h - 0.75) / 0.25);
}

void vertex() {
	float fh = fl_hash(NORMAL + vec3(INSTANCE_CUSTOM.x));
	// The underside of a billow (towards the fuel) burns hotter than its top.
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float heat = INSTANCE_CUSTOM.y + (fh - 0.5) * INSTANCE_CUSTOM.z - wn.y * 0.08;
	v_col = fl_heat(heat);
}

void fragment() {
	ALBEDO = v_col;
}
