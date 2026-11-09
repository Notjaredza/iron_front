// Iron Front: the map's one material. Flat vertex colours with a little tone change per 8 m cell and over large
// patches. Vertex alpha tags: 1 plain, 0.5 water, 0.25 a window that glows at night.
// mood 0 is bright day and 1 is night (cool, darker, less colour). haze greys the colours for fog.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float mood : hint_range(0.0, 1.0) = 0.0;
uniform float haze : hint_range(0.0, 1.0) = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float a = COLOR.a;
	bool water = a > 0.4 && a < 0.6;
	bool win = a < 0.4;
	float rough = 0.93;
	float spec = 0.2;
	if (water) {
		float r = vnoise(wpos.xz * 0.06 + vec2(TIME * 0.12, TIME * 0.08));
		float r2 = vnoise(wpos.xz * 0.21 - vec2(TIME * 0.2, 0.0));
		c *= 0.9 + 0.12 * r + 0.06 * r2;
		rough = 0.22;
		spec = 0.55;
	} else if (!win) {
		float cell = h2(floor(wpos.xz / 8.0) + vec2(floor(wpos.y * 0.25)));
		float big = vnoise(wpos.xz * 0.005);
		c *= 0.955 + 0.06 * cell + 0.1 * (big - 0.5);
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 cool = mix(vec3(l), c, 0.45) * vec3(0.80, 0.90, 1.06);
	vec3 grey = mix(vec3(l), c, 0.6);
	c = mix(c, grey, haze * 0.5);
	c = mix(c, cool, mood * 0.85);
	if (win) {
		EMISSION = COLOR.rgb * 2.6 * mood;
		c = mix(c, c * 0.25, mood);
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
