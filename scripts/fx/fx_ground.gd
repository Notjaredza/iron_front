class_name FxGround
extends Node3D
## Explosion round A (Building Chat 1, 2026-11-09): a faceted grass field for the blast test, where craters stay.
## A crater pushes the ground down into a bowl with a raised rim, browns the thrown earth round it and scorches it
## black near the middle. Only the chunks a crater touches are rebuilt. (Craters on the real stepped map are round B.)

const CELL := 1.5
const HALF := 120                         # cells from the middle to each edge (180 m)
const CHUNK := 20                         # cells per chunk side

var h := PackedFloat32Array()             # height at each grid corner
var burn := PackedFloat32Array()          # 0 grass .. 1 black scorch
var earth := PackedFloat32Array()         # 0 grass .. 1 thrown earth
var chunks := {}                          # Vector2i -> MeshInstance3D
var mat: StandardMaterial3D
var n := HALF * 2 + 1


func _ready() -> void:
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	h.resize(n * n)
	burn.resize(n * n)
	earth.resize(n * n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n * n:
		h[i] = rng.randf_range(-0.04, 0.04)
	for cz in range(0, HALF * 2, CHUNK):
		for cx in range(0, HALF * 2, CHUNK):
			_build(Vector2i(cx, cz))
	# Beyond the grid: one wide plain plane in the same green.
	var far := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.55, 0.28)
	fm.roughness = 0.95
	pm.material = fm
	far.mesh = pm
	far.position.y = -0.06
	add_child(far)


func clear() -> void:
	for i in n * n:
		h[i] = clampf(h[i], -0.04, 0.04)
		burn[i] = 0.0
		earth[i] = 0.0
	for key: Vector2i in chunks.keys():
		_build(key)


func _idx(x: int, z: int) -> int:
	return z * n + x


## A crater of radius r and depth d at world point p (x, z).
func crater(p: Vector3, r: float, d: float) -> void:
	var cx := int(roundf(p.x / CELL)) + HALF
	var cz := int(roundf(p.z / CELL)) + HALF
	var reach := int(ceilf(r * 2.6 / CELL)) + 1
	var touched := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p)
	var lumpy := rng.randf() * 10.0
	for z in range(maxi(cz - reach, 0), mini(cz + reach, n - 1) + 1):
		for x in range(maxi(cx - reach, 0), mini(cx + reach, n - 1) + 1):
			var wx := float(x - HALF) * CELL
			var wz := float(z - HALF) * CELL
			var dx := wx - p.x
			var dz := wz - p.z
			var ang := atan2(dz, dx)
			# A slightly ragged edge: the radius wobbles round the crater.
			var rr := r * (1.0 + 0.12 * sin(ang * 3.0 + lumpy) + 0.07 * sin(ang * 7.0 + lumpy * 2.0))
			var q := sqrt(dx * dx + dz * dz) / rr
			var i := _idx(x, z)
			var dh := 0.0
			if q < 1.0:
				dh = -d * (1.0 - q * q)
			dh += d * 0.28 * exp(-pow((q - 1.0) / 0.32, 2.0))
			h[i] = minf(h[i], h[i] * 0.3 + dh) if q < 1.0 else h[i] + dh * 0.7
			var noise := 0.75 + 0.5 * fmod(absf(sin(wx * 1.7 + wz * 2.3) * 43758.5), 1.0)
			burn[i] = maxf(burn[i], clampf((1.45 - q) / 0.9, 0.0, 1.0) * noise)
			earth[i] = maxf(earth[i], clampf((2.6 - q) / 1.4, 0.0, 1.0) * noise)
			touched[Vector2i((x / CHUNK) * CHUNK, (z / CHUNK) * CHUNK)] = true
	for key: Vector2i in touched.keys():
		if key.x < HALF * 2 and key.y < HALF * 2:
			_build(key)


## Ground height at a world point (for setting things on it).
func height(x: float, z: float) -> float:
	var gx := clampi(int(roundf(x / CELL)) + HALF, 0, n - 1)
	var gz := clampi(int(roundf(z / CELL)) + HALF, 0, n - 1)
	return h[_idx(gx, gz)]


func _build(key: Vector2i) -> void:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var grass := Color(0.42, 0.55, 0.28)
	var dirt := Color(0.45, 0.35, 0.24)
	var scorch := Color(0.10, 0.085, 0.07)
	for z in range(key.y, mini(key.y + CHUNK, n - 1)):
		for x in range(key.x, mini(key.x + CHUNK, n - 1)):
			var c: Array[Vector3] = []
			var b := 0.0
			var e := 0.0
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var i := _idx(x + o.x, z + o.y)
				c.append(Vector3(float(x + o.x - HALF) * CELL, h[i], float(z + o.y - HALF) * CELL))
				b += burn[i] * 0.25
				e += earth[i] * 0.25
			var shade := 0.94 + 0.12 * fmod(absf(sin(float(x) * 12.9898 + float(z) * 78.233) * 43758.5453), 1.0)
			var base := grass.lerp(dirt, smoothstep(0.0, 1.0, e)).lerp(scorch, smoothstep(0.0, 1.0, b))
			# Alternate the split so the facets don't all lean one way.
			var tris: Array = [[0, 1, 2], [0, 2, 3]] if (x + z) % 2 == 0 else [[0, 1, 3], [1, 2, 3]]
			for tri: Array in tris:
				var a: Vector3 = c[tri[0]]
				var bb: Vector3 = c[tri[1]]
				var cc: Vector3 = c[tri[2]]
				var nn := (cc - a).cross(bb - a).normalized()
				var fc := base * (shade + 0.04 * float(tri[0]))
				fc.a = 1.0
				pos.append_array([a, bb, cc])
				nrm.append_array([nn, nn, nn])
				col.append_array([fc, fc, fc])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = col
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mat)
	var mi: MeshInstance3D = chunks.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		add_child(mi)
		chunks[key] = mi
	mi.mesh = am
