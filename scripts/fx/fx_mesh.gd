class_name FxMesh
extends RefCounted
## Explosion round A (Building Chat 1, 2026-11-09): the few meshes every blast is drawn with, in the troops'
## faceted low-poly look. Each face gets its own flat normal (vertices are not shared), like UnitGeo.
## The particles move on the GPU (shaders/fx_*.gdshader), so these are built once and shared by every blast.

static var _cache := {}


## A lumpy faceted ball: an icosphere split once (80 faces), each corner pushed in or out a little,
## so no two faces are the same size. Fire, smoke, dust and the earth dome are all made of these.
static func blob() -> ArrayMesh:
	if _cache.has("blob"):
		return _cache["blob"]
	var t := (1.0 + sqrt(5.0)) * 0.5
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in v.size():
		v[i] = v[i].normalized()
	var mid := {}
	var f2: Array = []
	for tri: Array in f:
		var m: Array[int] = []
		for e in 3:
			var a: int = tri[e]
			var b: int = tri[(e + 1) % 3]
			var key := mini(a, b) * 1000 + maxi(a, b)
			if not mid.has(key):
				mid[key] = v.size()
				v.append(((v[a] + v[b]) * 0.5).normalized())
			m.append(mid[key])
		f2.append([tri[0], m[0], m[2]])
		f2.append([tri[1], m[1], m[0]])
		f2.append([tri[2], m[2], m[1]])
		f2.append([m[0], m[1], m[2]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in v.size():
		v[i] *= rng.randf_range(0.82, 1.12)
	var am := _flat(v, f2)
	_cache["blob"] = am
	return am


## An earth clod: a squashed box with its eight corners moved, 12 faces. The shader scales it per clod,
## from crumbs to car-sized blocks.
static func clod() -> ArrayMesh:
	if _cache.has("clod"):
		return _cache["clod"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var v: Array[Vector3] = []
	for i in 8:
		var c := Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1) * 0.5
		v.append(c + Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.14, 0.14), rng.randf_range(-0.14, 0.14)))
	# Faces of the box, outward.
	var q: Array = [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	var f: Array = []
	for s: Array in q:
		f.append([s[0], s[1], s[2]])
		f.append([s[0], s[2], s[3]])
	var am := _flat(v, f, true)
	_cache["clod"] = am
	return am


## A camera-facing square for the soft smoke (the shader turns it to the camera).
static func quad() -> ArrayMesh:
	if _cache.has("quad"):
		return _cache["quad"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_uv(c[i] * 0.5 + Vector2(0.5, 0.5))
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(c[i].x, c[i].y, 0))
	var am := st.commit()
	_cache["quad"] = am
	return am


## A spark: a thin 4-sided stick along +z from 0 to 1, stretched along its flight by the shader.
static func spark() -> ArrayMesh:
	if _cache.has("spark"):
		return _cache["spark"]
	var w := 0.5
	var v: Array[Vector3] = [Vector3(-w, 0, 0), Vector3(0, w, 0), Vector3(w, 0, 0), Vector3(0, -w, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -0.2)]
	var f: Array = [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4], [1, 0, 5], [2, 1, 5], [3, 2, 5], [0, 3, 5]]
	var am := _flat(v, f, true)
	_cache["spark"] = am
	return am


## Shells round (2026-11-10): a shell, 8-sided and faceted, along +z from its base (0) to its nose (1).
static func shell() -> ArrayMesh:
	if _cache.has("shell"):
		return _cache["shell"]
	var v: Array[Vector3] = []
	var rings := [[0.0, 0.17], [0.08, 0.2], [0.6, 0.2], [0.82, 0.13], [0.94, 0.05]]
	for r: Array in rings:
		for i in 8:
			var a := TAU * (float(i) + 0.5) / 8.0
			v.append(Vector3(cos(a) * float(r[1]), sin(a) * float(r[1]), float(r[0])))
	v.append(Vector3(0, 0, 1.0))      # nose
	v.append(Vector3(0, 0, 0.0))      # base centre
	var f: Array = []
	for ri in rings.size() - 1:
		for i in 8:
			var a := ri * 8 + i
			var b := ri * 8 + (i + 1) % 8
			f.append([a, b, a + 8])
			f.append([b, b + 8, a + 8])
	var last := (rings.size() - 1) * 8
	for i in 8:
		f.append([last + i, last + (i + 1) % 8, 40])
		f.append([(i + 1) % 8, i, 41])
	var c := Vector3(0, 0, 0.5)
	var vv: Array[Vector3] = []
	for p in v:
		vv.append(p - c)
	var am := _flat(vv, f, true)
	# Move it back so the base sits at z = 0 (the check above needed it centred).
	var arr := am.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in pos.size():
		pos[i] += c
	arr[Mesh.ARRAY_VERTEX] = pos
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache["shell"] = out
	return out


## Flat-shaded mesh from corners and faces. Each face's three corners are emitted with the face normal,
## wound so the outside is the front (Godot: clockwise seen from outside). check_out: fix each face to face
## away from the middle (for the irregular shapes).
static func _flat(v: Array[Vector3], faces: Array, check_out := true) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	for tri: Array in faces:
		var a: Vector3 = v[tri[0]]
		var b: Vector3 = v[tri[1]]
		var c: Vector3 = v[tri[2]]
		var n := (b - a).cross(c - a)
		if check_out and n.dot((a + b + c) / 3.0) < 0.0:
			var tmp := b
			b = c
			c = tmp
			n = -n
		n = n.normalized()
		pos.append_array([a, c, b])
		nrm.append_array([n, n, n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am
