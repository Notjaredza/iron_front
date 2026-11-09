shader_type spatial;
// Explosion round A: sparks and burning bits. A thin faceted stick drawn along its flight, longer the faster it
// goes, cooling from white-yellow to dull orange.
render_mode skip_vertex_transform, unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

varying flat vec3 v_col;

void vertex() {
	vec3 p0 = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	float t0 = MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	float k = MODEL_MATRIX[1].z;
	float ay = MODEL_MATRIX[2].x;
	float w = MODEL_MATRIX[2].y;
	float len0 = MODEL_MATRIX[2].z;
	float age = t_now - t0;
	float u = age / life;
	vec3 acc = vec3(0.0, ay, 0.0);
	vec3 p = fx_pos(p0, v0, k, acc, age);
	if (age < 0.0 || u > 1.0 || p.y < blast_p.y - 0.5) {
		VERTEX = vec3(0.0);
		v_col = vec3(0.0);
	} else {
		vec3 vel = fx_vel(v0, k, acc, age);
		float sp = length(vel);
		vec3 z = sp > 0.01 ? vel / sp : vec3(0.0, 1.0, 0.0);
		vec3 x = normalize(cross(abs(z.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0), z));
		vec3 y = cross(z, x);
		float len = len0 + sp * 0.035;
		float ww = w * (1.0 - 0.6 * u);
		vec3 wv = p + x * VERTEX.x * ww + y * VERTEX.y * ww - z * VERTEX.z * len;
		v_col = fx_heat(1.0 - u * 0.75) * (1.0 - smoothstep(0.7, 1.0, u)) * 0.8;
		VERTEX = (VIEW_MATRIX * vec4(wv, 1.0)).xyz;
	}
}

void fragment() {
	if (dot(v_col, vec3(1.0)) <= 0.0) {
		discard;
	}
	ALBEDO = v_col;
}
