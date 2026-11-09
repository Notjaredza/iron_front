class_name MapCraters
extends Node3D
## Explosion round B (Building Chat 1, 2026-11-09): craters that stay, on the real map. The map's ground is flat
## terraces built in big chunk meshes, so a crater is not dug into it. Instead each crater is three pieces:
##   a mask    the hole's outline lying on the ground; it draws nothing but marks the stencil where it is seen;
##   a bowl    the inside of the crater, below the ground; drawn only where the mask marked, so it shows through the
##             ground like a real hole (a bowl is convex, so it never covers itself);
##   a rim     the thrown-up lip of earth and the scorched ring round it, ordinary solid ground.
## Four ragged shapes, each piece one MultiMesh, so a thousand craters are still twelve draw calls.

const VARIANTS := 4
const SEG := 14
const STENCIL := 32

var _mm: Array[MultiMesh] = []        # [variant * 3 + piece]: 0 mask, 1 bowl, 2 rim
var _xf: Array = []                   # per MultiMesh: Array of Transform3D
var _n := 0
static var _meshes: Array[ArrayMesh] = []


func _ready() -> void:
	_ensure()


func _ensure() -> void:
	if not _mm.is_empty():
		return
	var mats := [_mask_mat(), _bowl_mat(), _rim_mat()]
	if _meshes.is_empty():
		for v in VARIANTS:
			_meshes.append_array(_build(v))
	for v in VARIANTS:
		for piece in 3:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _meshes[v * 3 + piece]
			mm.instance_count = 0
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = mats[piece]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if piece == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_mm.append(mm)
			_xf.append([])


## A crater of radius r and depth d at ground point p (p.y the ground height there).
func add(p: Vector3, r: float, d: float, seed_value: int) -> void:
	_ensure()
	var v := absi(seed_value) % VARIANTS
	var b := Basis(Vector3.UP, float(seed_value % 628) * 0.01)
	var lifts := [0.03, 0.0, 0.0]
	var scales := [Vector3(r, 1.0, r), Vector3(r, d, r), Vector3(r, r * 0.9, r)]
	for piece in 3:
		var i := v * 3 + piece
		(_xf[i] as Array).append(Transform3D(b.scaled_local(scales[piece]), p + Vector3(0, lifts[piece], 0)))
		var mm := _mm[i]
		mm.instance_count = (_xf[i] as Array).size()
		for k in mm.instance_count:
			mm.set_instance_transform(k, _xf[i][k])
	_n += 1


func count() -> int:
	return _n


func clear() -> void:
	for i in _mm.size():
		(_xf[i] as Array).clear()
		_mm[i].instance_count = 0
	_n = 0


## The three unit meshes (radius 1, depth 1) of one ragged shape.
static func _build(variant: int) -> Array[ArrayMesh]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711 + variant * 31
	var edge: Array[float] = []                 # the ragged outline, radius per segment
	for s in SEG:
		edge.append(rng.randf_range(0.86, 1.1))
	var ang := func(s: int) -> float: return TAU * float(s % SEG) / float(SEG)
	var at := func(s: int, rr: float, y: float) -> Vector3:
		var a: float = ang.call(s)
		return Vector3(cos(a) * rr, y, sin(a) * rr)
	# Mask: a flat fan of the outline.
	var mask := _Tris.new()
	for s in SEG:
		mask.tri(Vector3.ZERO, at.call(s + 1, edge[(s + 1) % SEG], 0.0), at.call(s, edge[s], 0.0), Color.BLACK, Vector3.UP)
	# Bowl: rings down to the floor; a paraboloid, so convex. Scorched dark at the bottom, earth higher up.
	var bowl := _Tris.new()
	var rings := [1.0, 0.72, 0.42, 0.16]
	var ys := []
	for rr: float in rings:
		ys.append(-(1.0 - rr * rr))
	for ri in rings.size() - 1:
		for s in SEG:
			var o0: float = rings[ri]
			var o1: float = rings[ri + 1]
			var e0 := edge[s] if ri == 0 else 1.0
			var e1 := edge[(s + 1) % SEG] if ri == 0 else 1.0
			var j := rng.randf_range(-0.03, 0.03)
			var a0: Vector3 = at.call(s, o0 * e0, ys[ri])
			var a1: Vector3 = at.call(s + 1, o0 * e1, ys[ri])
			var b0: Vector3 = at.call(s, o1, ys[ri + 1])
			var b1: Vector3 = at.call(s + 1, o1, ys[ri + 1])
			var c := Color(0.4, 0.3, 0.2).lerp(Color(0.27, 0.2, 0.14), float(ri) / 2.0)
			c = Color(c.r + j, c.g + j, c.b + j)
			bowl.tri(a0, b0, a1, c, Vector3.UP)
			bowl.tri(a1, b0, b1, c.darkened(0.06), Vector3.UP)
	var floor_y: float = ys[rings.size() - 1]
	for s in SEG:
		bowl.tri(Vector3(0, -1.0 + 0.02, 0), at.call(s + 1, rings[3], floor_y), at.call(s, rings[3], floor_y),
			Color(0.24, 0.18, 0.13), Vector3.UP)
	# Rim: from just inside the edge up to a ragged crest and down outside, then a scorched skirt on the ground.
	var rim := _Tris.new()
	var crest: Array[float] = []
	var skirt: Array[float] = []
	for s in SEG:
		crest.append(rng.randf_range(0.08, 0.17))
		skirt.append(rng.randf_range(1.6, 2.3))
	for s in SEG:
		var s1 := (s + 1) % SEG
		var i0: Vector3 = at.call(s, edge[s] * 0.97, -0.02)
		var i1: Vector3 = at.call(s + 1, edge[s1] * 0.97, -0.02)
		var c0: Vector3 = at.call(s, edge[s] * 1.18, crest[s])
		var c1: Vector3 = at.call(s + 1, edge[s1] * 1.18, crest[s1])
		var o0: Vector3 = at.call(s, edge[s] * 1.5, 0.0)
		var o1: Vector3 = at.call(s + 1, edge[s1] * 1.5, 0.0)
		var k0: Vector3 = at.call(s, skirt[s], 0.012)
		var k1: Vector3 = at.call(s + 1, skirt[s1], 0.012)
		var j := rng.randf_range(-0.03, 0.03)
		var earth := Color(0.42 + j, 0.32 + j, 0.21 + j)
		rim.tri(i0, c0, i1, earth.darkened(0.12), Vector3.UP)
		rim.tri(i1, c0, c1, earth.darkened(0.08), Vector3.UP)
		rim.tri(c0, o0, c1, earth, Vector3.UP)
		rim.tri(c1, o0, o1, earth.lightened(0.04), Vector3.UP)
		var sc := Color(0.2 + j, 0.17 + j, 0.13 + j)
		rim.tri(o0, k0, o1, sc, Vector3.UP)
		rim.tri(o1, k0, k1, sc.lightened(0.05), Vector3.UP)
	return [mask.mesh(), bowl.mesh(), rim.mesh()]


static func _mask_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/fx_crater_mask.gdshader")
	m.render_priority = 0
	return m


static func _bowl_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/fx_crater_bowl.gdshader")
	m.render_priority = 1
	return m


static func _rim_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	return m


## Flat-shaded triangles with a colour each (faces turned to face `want`).
class _Tris:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()

	func tri(a: Vector3, b: Vector3, c: Vector3, k: Color, want := Vector3.ZERO) -> void:
		var n := (b - a).cross(c - a)
		if want != Vector3.ZERO and n.dot(want) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		pos.append_array([a, c, b])        # Godot's front faces wind clockwise
		nrm.append_array([n, n, n])
		col.append_array([k, k, k])

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_COLOR] = col
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return am
