shader_type spatial;
// Explosion round A, style 2: soft puffs. The same cloud as the faceted style (same particles, same motion), drawn as
// round soft-edged puffs turned to the camera, each lit like a ball and bent towards the whole cloud's shape.
// Old smoke thins out (fades) instead of shrinking. Only the debris and the fire stay faceted in this style.
render_mode skip_vertex_transform, blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/fx_common.gdshaderinc"

instance uniform float fire_glow = 0.0;
instance uniform float glow_r = 10.0;
instance uniform float fire_h = 2.0;
uniform vec3 glow_col : source_color = vec3(1.0, 0.42, 0.12);
uniform float night = 0.0;

varying vec3 v_col;
varying float v_alpha;
varying vec3 v_mass;
varying float v_fire;

void vertex() {
	vec3 raw;
	float u;
	vec4 ps = fx_smoke(MODEL_MATRIX, INSTANCE_CUSTOM, raw, u);
	if (ps.w <= 0.0) {
		VERTEX = vec3(0.0);
		v_alpha = 0.0;
		v_col = vec3(0.0);
		v_mass = vec3(0.0, 0.0, 1.0);
		v_fire = 0.0;
	} else {
		float size = ps.w * 1.3;
		vec3 rad = raw - blast_p;
		rad.y = 0.0;
		float rl = length(rad);
		vec3 mass = normalize((rl > 0.001 ? rad / rl : vec3(0.0)) * min(rl / max(ps.w, 0.5), 1.2) + vec3(0.0, 0.75, 0.0));
		v_mass = normalize((VIEW_MATRIX * vec4(mass, 0.0)).xyz);
		vec3 c = fx_lin(COLOR.rgb);
		c = mix(c, c * 1.12 + vec3(0.06, 0.055, 0.05), smoothstep(0.05, 0.75, u) * INSTANCE_CUSTOM.z);
		v_col = c;
		v_alpha = (1.0 - smoothstep(0.5, 1.0, u)) * 0.92;
		vec3 fp = blast_p + vec3(0.0, fire_h, 0.0);
		v_fire = fire_glow * exp(-distance(ps.xyz, fp) / glow_r);
		// A turn of the square per puff, so the round edges don't line up.
		float a = INSTANCE_CUSTOM.x * 6.283;
		vec2 q = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
		VERTEX = (VIEW_MATRIX * vec4(ps.xyz, 1.0)).xyz + vec3(q * size, 0.0);
	}
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d2 = dot(q, q);
	if (d2 > 1.0 || v_alpha <= 0.0) {
		discard;
	}
	vec3 sn = vec3(q.x, -q.y, sqrt(1.0 - d2));
	NORMAL = normalize(mix(sn, v_mass, 0.45));
	float rim = sqrt(d2);
	ALBEDO = v_col * (0.62 + 0.38 * sn.z);
	ROUGHNESS = 1.0;
	ALPHA = smoothstep(1.0, 0.45, rim) * v_alpha;
	EMISSION = glow_col * v_fire * (0.9 + 1.2 * night) * (0.5 + 0.5 * sn.z) * ALPHA;
}
