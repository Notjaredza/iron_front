// Iron Front: the map's one material. Flat vertex colours with a little tone change per 8 m cell and over large
// patches. Vertex alpha tags: 1 plain, 0.75 grass ground (painted patches), 0.5 water, 0.25 a window that glows at night.
// mood 0 is bright day and 1 is night (cool, darker, less colour). haze greys the colours for fog.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float mood : hint_range(0.0, 1.0) = 0.0;
uniform float haze : hint_range(0.0, 1.0) = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// A hash that stays steady at large world coordinates (a sine hash breaks into straight bands there).
float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	float a = COLOR.a;
	bool water = a > 0.4 && a < 0.6;
	bool shallow = a > 0.52 && a < 0.6;
	bool marsh = a > 0.6 && a < 0.7;
	bool grass = a > 0.7 && a < 0.8;
	bool field = a > 0.85 && a < 0.95;
	bool win = a < 0.4;
	float rough = 0.93;
	float spec = 0.2;
	if (water) {
		vec2 p = wpos.xz;
		// One slow broad layer (also breaks up the depth bands) and one layer of drifting streaks for ripples.
		float r = vnoise(p * 0.03 + vec2(TIME * 0.06, TIME * 0.04));
		float rip = vnoise(vec2(p.x * 0.3 + TIME * 0.5, p.y * 0.1 - TIME * 0.3));
		c *= 0.86 + 0.2 * r + 0.18 * smoothstep(0.55, 0.8, rip);
		if (COLOR.r > 0.6) {
			// Foam at the banks: broken, slowly moving.
			float fo = vnoise(p * 1.1 + vec2(TIME * 0.3, -TIME * 0.2));
			c = mix(to_linear(vec3(0.27, 0.52, 0.65)) * (0.95 + 0.1 * r), c, smoothstep(0.38, 0.6, fo));
		}
		if (shallow) {
			// The ford: pebbles showing through shallow, quick water.
			c *= 0.95 + 0.1 * h2(floor(p * 2.6));
			c = mix(c, to_linear(vec3(0.75, 0.85, 0.88)), 0.18 * smoothstep(0.65, 0.85, rip));
		}
		rough = 0.55;
		spec = 0.28;
	} else if (marsh) {
		// Bog: mottled mud and wet grass with pools of still water.
		vec2 p = wpos.xz;
		float m1 = vnoise(p * 0.11);
		float m2 = vnoise(p * 0.37 + 9.0);
		c *= 0.86 + 0.24 * m2;
		c = mix(c, to_linear(vec3(0.40, 0.33, 0.22)), 0.35 * smoothstep(0.5, 0.75, m2));
		float pool = smoothstep(0.58, 0.62, m1 * 0.75 + m2 * 0.25);
		c = mix(c, to_linear(vec3(0.24, 0.40, 0.44)) * (0.95 + 0.1 * m1), pool);
		rough = mix(0.9, 0.3, pool);
		spec = mix(0.2, 0.45, pool);
	} else if (field) {
		// Crop rows, along x or z by the tag; a little tone change per field patch.
		vec2 p = wpos.xz;
		float along = a < 0.9 ? p.y : p.x;
		float row = 0.5 + 0.5 * sin(along * 3.1416 * 0.9);
		float patch = vnoise(p * 0.03);
		c *= 0.86 + 0.16 * row + 0.08 * (patch - 0.5);
	} else if (!win) {
		float cell = h2(floor(wpos.xz / 8.0) + vec2(floor(wpos.y * 0.25)));
		float big = vnoise(wpos.xz * 0.005);
		c *= 0.97 + 0.035 * cell + 0.1 * (big - 0.5);
		if (grass) {
			// Painted ground (light): soft darker and lighter patches, dry yellow spots and a few worn dirt patches.
			vec2 p = wpos.xz;
			float n1 = vnoise(p * 0.014);
			float n2 = vnoise(p * 0.05 + 17.0);
			float n3 = vnoise(p * 0.16 + 41.0);
			c *= 0.93 + 0.14 * n1 + 0.05 * (n3 - 0.5);
			float dry = smoothstep(0.70, 0.75, n2 * 0.72 + n3 * 0.28);
			c = mix(c, to_linear(vec3(0.70, 0.66, 0.38)) * (0.95 + 0.1 * n3), dry * 0.36);
			float worn = smoothstep(0.83, 0.86, vnoise(p * 0.022 + 73.0) * 0.85 + n3 * 0.15);
			c = mix(c, to_linear(vec3(0.55, 0.43, 0.29)) * (0.92 + 0.12 * n3), worn * 0.85);
		}
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 cool = mix(vec3(l), c, 0.32) * vec3(0.82, 0.88, 1.02);
	vec3 grey = mix(vec3(l), c, 0.6);
	c = mix(c, grey, haze * 0.5);
	c = mix(c, cool, mood * 0.85);
	if (win) {
		EMISSION = to_linear(COLOR.rgb) * 2.6 * mood;
		c = mix(c, c * 0.25, mood);
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
