// Explosion round A (Building Chat 1, 2026-11-09): shared particle motion for the blast shaders.
// Each particle is one MultiMesh instance whose 20 numbers are its whole life, so the GPU works out where it is
// at any time with no work on the CPU each frame:
//   MODEL_MATRIX[3].xyz  start position p0          MODEL_MATRIX[0].xyz  start velocity v0
//   MODEL_MATRIX[1].xyz  (born, life, drag k)        MODEL_MATRIX[2].xyz  (up/down pull ay, size at birth, full size)
//   INSTANCE_CUSTOM      (seed, spin, landing age or lighten, extra)   COLOR  colour (sRGB) and one more number
// The MultiMeshInstance3D sits at the world origin, so MODEL_MATRIX is the instance's numbers unchanged.
// Motion with linear drag k and a constant pull a:  p(t) = p0 + v0 (1 - e^-kt)/k + a/k (t - (1 - e^-kt)/k).
// A particle with no pull comes to rest at p0 + v0/k, so v0 = (target - p0) k sends it to a sculpted point.

instance uniform float t_now = 0.0;
instance uniform vec3 blast_p = vec3(0.0);

vec3 fx_hash3(float s) {
	return fract(sin(vec3(s * 12.9898, s * 78.233, s * 37.719)) * 43758.5453);
}

float fx_hash1(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

mat3 fx_rot(vec3 axis, float a) {
	vec3 n = normalize(axis);
	float c = cos(a);
	float s = sin(a);
	float t = 1.0 - c;
	return mat3(vec3(t * n.x * n.x + c, t * n.x * n.y + s * n.z, t * n.x * n.z - s * n.y),
		vec3(t * n.x * n.y - s * n.z, t * n.y * n.y + c, t * n.y * n.z + s * n.x),
		vec3(t * n.x * n.z + s * n.y, t * n.y * n.z - s * n.x, t * n.z * n.z + c));
}

vec3 fx_pos(vec3 p0, vec3 v0, float k, vec3 acc, float age) {
	if (k < 0.0001) {
		return p0 + v0 * age + 0.5 * acc * age * age;
	}
	float e = (1.0 - exp(-k * age)) / k;
	return p0 + v0 * e + acc / k * (age - e);
}

vec3 fx_vel(vec3 v0, float k, vec3 acc, float age) {
	if (k < 0.0001) {
		return v0 + acc * age;
	}
	float x = exp(-k * age);
	return v0 * x + acc / k * (1.0 - x);
}

vec3 fx_lin(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

// Fire colour by heat (1 white-hot ... 0 cold soot), in HDR so the glow picks the hot part up.
vec3 fx_heat(float h) {
	h = clamp(h, 0.0, 1.0);
	vec3 c0 = vec3(0.045, 0.035, 0.03);
	vec3 c1 = vec3(0.75, 0.14, 0.03) * 1.3;
	vec3 c2 = vec3(1.0, 0.42, 0.08) * 1.9;
	vec3 c3 = vec3(1.0, 0.66, 0.26) * 2.7;
	vec3 c4 = vec3(1.0, 0.88, 0.62) * 4.0;
	if (h < 0.22) return mix(c0, c1, h / 0.22);
	if (h < 0.48) return mix(c1, c2, (h - 0.22) / 0.26);
	if (h < 0.75) return mix(c2, c3, (h - 0.48) / 0.27);
	return mix(c3, c4, (h - 0.75) / 0.25);
}

// The smoke and dust motion shared by the faceted and the soft style, so the two looks are the same cloud.
// Returns the particle centre (xyz) and its size (w); size 0 = not alive now. raw: the centre before the wind.
uniform vec2 wind = vec2(2.6, 0.9);

vec4 fx_smoke(mat4 mm, vec4 custom, out vec3 raw, out float u) {
	vec3 p0 = mm[3].xyz;
	vec3 v0 = mm[0].xyz;
	float t0 = mm[1].x;
	float life = mm[1].y;
	float k = mm[1].z;
	float ay = mm[2].x;
	float s0 = mm[2].y;
	float s1 = mm[2].z;
	float age = t_now - t0;
	u = age / life;
	raw = p0;
	if (age < 0.0 || age > life) {
		return vec4(0.0);
	}
	vec3 p = fx_pos(p0, v0, k, vec3(0.0, ay, 0.0), age);
	float grow = 1.0 - pow(1.0 - min(age / max(life * 0.22, 0.05), 1.0), 3.0);
	float size = mix(s0, s1, grow);
	p.y = max(p.y, blast_p.y + size * 0.3);
	raw = p;
	// Wind: more drift higher up, so tall columns lean over at the top.
	p.xz += wind * custom.w * age * (0.3 + clamp((p.y - blast_p.y) / 140.0, 0.0, 2.2));
	return vec4(p, size);
}
