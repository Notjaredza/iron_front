shader_type spatial;
// Explosion round A: thrown earth. Faceted clods from crumbs to big blocks on real arcs; they tumble, land and stay,
// then sink away near the end of their life. Some carry grass on top; some glow hot for the first second.
render_mode skip_vertex_transform, cull_back, depth_draw_opaque, specular_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform vec3 grass_col : source_color = vec3(0.40, 0.53, 0.26);
uniform float night = 0.0;

varying flat vec3 v_col;
varying flat float v_hot;

void vertex() {
	vec3 p0 = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	float t0 = MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	float k = MODEL_MATRIX[1].z;
	float ay = MODEL_MATRIX[2].x;
	float size = MODEL_MATRIX[2].z;
	float age = t_now - t0;
	if (age < 0.0 || age > life) {
		VERTEX = vec3(0.0);
		NORMAL = vec3(0.0, 0.0, 1.0);
		v_col = vec3(0.0);
		v_hot = 0.0;
	} else {
		float seed = INSTANCE_CUSTOM.x;
		float land = INSTANCE_CUSTOM.z;
		float fa = min(age, land);
		vec3 p = fx_pos(p0, v0, k, vec3(0.0, ay, 0.0), fa);
		vec3 h = fx_hash3(seed);
		mat3 R = fx_rot(h * 2.0 - 1.0 + vec3(0.01), seed * 6.283 + INSTANCE_CUSTOM.y * fa);
		// Slabs and lumps: each clod squashed its own way.
		vec3 sq = 0.55 + 0.9 * fx_hash3(seed + 1.3);
		float sink = smoothstep(life - 4.0, life, age);
		p.y -= sink * size * 1.2;
		if (age >= land) {
			p.y += size * sq.y * 0.25;
		}
		vec3 wv = p + R * (VERTEX * sq * size);
		vec3 wn = normalize(R * (NORMAL / sq));
		vec3 c = fx_lin(COLOR.rgb) * (0.85 + 0.3 * fx_hash1(NORMAL + vec3(seed)));
		// Grass on the clod's top side (COLOR.a: how many clods carry turf).
		if (h.z < COLOR.a && NORMAL.y > 0.5) {
			c = grass_col * (0.85 + 0.25 * h.x);
		}
		v_col = c;
		v_hot = INSTANCE_CUSTOM.w * exp(-age * (1.6 - 0.9 * night));
		VERTEX = (VIEW_MATRIX * vec4(wv, 1.0)).xyz;
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}

void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.95;
	EMISSION = fx_heat(0.35 + 0.4 * v_hot) * v_hot * 0.6;
}
