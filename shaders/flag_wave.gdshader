shader_type spatial;
// Red jackets (2026-11-10): the colour's cloth waving. The mesh is flat (x away from the pole, z down it); waves run
// out from the pole and grow toward the fly, the cloth sags a little at the fly. Normals come from the screen
// derivatives, so every small square is its own flat facet, like the troops. t_wave is set per figure (frame-exact
// clips); wind 0 hangs it limp, 1 is a good breeze.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

instance uniform float t_wave = 0.0;
instance uniform float wind = 1.0;
varying vec3 v_col;

void vertex() {
	float u = UV.x;
	float v = UV.y;
	float t = t_wave;
	float a = u * (0.06 + 0.16 * wind);
	float wave = sin(u * 7.0 - t * 5.2 + v * 1.6) * a + sin(u * 12.0 - t * 8.3 - v * 2.4) * a * 0.35;
	VERTEX.y += wave;
	// Limp: the fly droops toward the pole and down; in a breeze it streams out.
	float limp = 1.0 - clamp(wind, 0.0, 1.0);
	VERTEX.x *= 1.0 - limp * 0.55 * u;
	VERTEX.z += limp * u * u * 0.9 + (1.0 - limp) * u * u * 0.12;
	VERTEX.x -= abs(wave) * 0.25 * u;
	v_col = COLOR.rgb;
}

void fragment() {
	vec3 n = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	NORMAL = dot(n, VIEW) < 0.0 ? -n : n;
	ALBEDO = pow(v_col, vec3(2.2));
	ROUGHNESS = 0.9;
}
