shader_type spatial;
// Explosion round A, style 1: faceted billows. Smoke, dust and thrown earth as lumpy flat-shaded shapes, like the
// soldiers, lit as one mass: each face's light normal is bent towards the cloud's own outward direction (and up),
// faces turned into the cloud are darkened (its creases), and the cloud casts and takes real shadows.
// The underside is lit by the fire while it burns. Old smoke shrinks away rather than fading (no see-through).
render_mode skip_vertex_transform, cull_back, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/fx_common.gdshaderinc"

instance uniform float fire_glow = 0.0;
instance uniform float glow_r = 10.0;
instance uniform float fire_h = 2.0;
uniform vec3 glow_col : source_color = vec3(1.0, 0.42, 0.12);
uniform float night = 0.0;

varying flat vec3 v_col;
varying flat float v_ao;
varying flat float v_fire;

void vertex() {
	vec3 raw;
	float u;
	vec4 ps = fx_smoke(MODEL_MATRIX, INSTANCE_CUSTOM, raw, u);
	float size = ps.w * (1.0 - smoothstep(0.62, 1.0, u));
	if (size <= 0.0) {
		VERTEX = vec3(0.0);
		NORMAL = vec3(0.0, 0.0, 1.0);
		v_col = vec3(0.0);
		v_ao = 0.0;
		v_fire = 0.0;
	} else {
		float seed = INSTANCE_CUSTOM.x;
		float age = t_now - MODEL_MATRIX[1].x;
		vec3 h = fx_hash3(seed);
		mat3 R = fx_rot(h * 2.0 - 1.0 + vec3(0.01), seed * 6.283 + INSTANCE_CUSTOM.y * age);
		vec3 sq = 0.82 + 0.36 * fx_hash3(seed + 3.1);
		sq.y *= COLOR.a;
		sq.xz *= 1.4 - COLOR.a * 0.4;
		vec3 wv = ps.xyz + R * (VERTEX * sq * size);
		vec3 wn = normalize(R * (NORMAL / sq));
		// The cloud's outward direction here: out from the blast's upright axis, plus up.
		vec3 rad = raw - blast_p;
		rad.y = 0.0;
		float rl = length(rad);
		vec3 mass = normalize((rl > 0.001 ? rad / rl : vec3(0.0)) * min(rl / max(size, 0.5), 1.2) + vec3(0.0, 0.75, 0.0));
		v_ao = clamp(dot(wn, mass) * 0.5 + 0.5, 0.0, 1.0);
		vec3 ln = normalize(mix(wn, mass, 0.5));
		// Colour: sRGB in, linear out; smoke thins to a lighter grey as it ages (INSTANCE_CUSTOM.z: how much).
		vec3 c = fx_lin(COLOR.rgb);
		c = mix(c, c * 1.12 + vec3(0.06, 0.055, 0.05), smoothstep(0.05, 0.75, u) * INSTANCE_CUSTOM.z);
		v_col = c;
		// The fire's light on faces turned towards it.
		vec3 fp = blast_p + vec3(0.0, fire_h, 0.0);
		vec3 tf = fp - wv;
		float df = length(tf);
		v_fire = fire_glow * clamp(dot(wn, tf / max(df, 0.01)) * 0.6 + 0.4, 0.0, 1.0) * exp(-df / glow_r);
		VERTEX = (VIEW_MATRIX * vec4(wv, 1.0)).xyz;
		NORMAL = normalize((VIEW_MATRIX * vec4(ln, 0.0)).xyz);
	}
}

void fragment() {
	vec3 c = v_col * (0.55 + 0.45 * v_ao);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = glow_col * v_fire * (1.4 + 1.6 * night) * (0.5 + 0.5 * dot(v_col, vec3(0.6)));
}
