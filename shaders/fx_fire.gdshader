shader_type spatial;
// Explosion round A: the fireball. Lumpy faceted shapes that flash white, then cool through yellow and orange to
// dark red and soot; every face has its own heat, so the facets read inside the glow. No shadows (it is the light).
render_mode skip_vertex_transform, unshaded, cull_back, depth_draw_opaque, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

varying flat vec3 v_col;

void vertex() {
	vec3 p0 = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	float t0 = MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	float k = MODEL_MATRIX[1].z;
	float ay = MODEL_MATRIX[2].x;
	float s0 = MODEL_MATRIX[2].y;
	float s1 = MODEL_MATRIX[2].z;
	float age = t_now - t0;
	float u = age / life;
	if (age < 0.0 || u > 1.0) {
		VERTEX = vec3(0.0);
		v_col = vec3(0.0);
	} else {
		float seed = INSTANCE_CUSTOM.x;
		vec3 p = fx_pos(p0, v0, k, vec3(0.0, ay, 0.0), age);
		float size = mix(s0, s1, 1.0 - pow(1.0 - min(u * 3.5, 1.0), 2.0));
		size *= 1.0 - 0.75 * smoothstep(0.55, 1.0, u);
		vec3 h = fx_hash3(seed);
		mat3 R = fx_rot(h * 2.0 - 1.0 + vec3(0.01), seed * 6.283 + INSTANCE_CUSTOM.y * age);
		vec3 sq = 0.8 + 0.4 * fx_hash3(seed + 5.7);
		vec3 wv = p + R * (VERTEX * sq * size);
		// Heat: falls with age, each face a little different, the core (INSTANCE_CUSTOM.w) hotter.
		float fh = fx_hash1(NORMAL + vec3(seed));
		float heat = 1.0 - u * 1.1 + (fh - 0.5) * 0.4 + INSTANCE_CUSTOM.w * 0.25;
		v_col = fx_heat(heat);
		VERTEX = (VIEW_MATRIX * vec4(wv, 1.0)).xyz;
	}
}

void fragment() {
	if (dot(v_col, vec3(1.0)) <= 0.0) {
		discard;
	}
	ALBEDO = v_col;
}
