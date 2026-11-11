shader_type spatial;
// Shells round (2026-11-10): a shell in flight. A faceted body turned along its flight (closed-form path, as the blast
// particles), dark steel, never smaller than a few pixels so you can follow it. Its base glows like a tracer: a little
// by day, brightly at night.
//   numbers: p0 start, v0 start velocity, (born, flight time, 0), (pull, length, 0), COLOR body colour,
//   INSTANCE_CUSTOM (seed, spin, day glow, night glow)
render_mode skip_vertex_transform, cull_back, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/fx_common.gdshaderinc"

uniform float night = 0.0;
varying vec3 v_col;
varying float v_glow;

void vertex() {
	vec3 p0 = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	float t0 = MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	float ay = MODEL_MATRIX[2].x;
	float len0 = MODEL_MATRIX[2].y;
	float age = t_now - t0;
	if (age < 0.0 || age > life) {
		VERTEX = vec3(0.0);
		v_glow = 0.0;
		v_col = vec3(0.0);
	} else {
		vec3 acc = vec3(0.0, ay, 0.0);
		vec3 p = fx_pos(p0, v0, 0.0, acc, age);
		vec3 vel = fx_vel(v0, 0.0, acc, age);
		vec3 z = normalize(vel + vec3(0.0, 1e-4, 0.0));
		vec3 x = normalize(cross(abs(z.y) < 0.98 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0), z));
		vec3 y = cross(z, x);
		// Spin about its flight, and never smaller than ~8 pixels long (0.007 of its distance).
		float spin = INSTANCE_CUSTOM.y * age;
		vec3 xs = x * cos(spin) + y * sin(spin);
		vec3 ys = cross(z, xs);
		vec3 cam = INV_VIEW_MATRIX[3].xyz;
		float len = max(len0, distance(cam, p) * 0.007);
		vec3 wv = p + (xs * VERTEX.x + ys * VERTEX.y + z * VERTEX.z) * len;
		vec3 wn = xs * NORMAL.x + ys * NORMAL.y + z * NORMAL.z;
		NORMAL = (VIEW_MATRIX * vec4(wn, 0.0)).xyz;
		VERTEX = (VIEW_MATRIX * vec4(wv, 1.0)).xyz;
		v_col = fx_lin(COLOR.rgb);
		// The base (z near 0) glows; the nose does not.
		v_glow = (1.0 - smoothstep(0.0, 0.35, VERTEX_ID >= 0 ? 0.0 : 0.0)) * (1.0 - smoothstep(0.02, 0.3, dot(wv - p, z) / len));
		v_glow *= mix(INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w, night);
	}
}

void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.45;
	METALLIC = 0.6;
	EMISSION = vec3(1.0, 0.5, 0.16) * v_glow;
}
