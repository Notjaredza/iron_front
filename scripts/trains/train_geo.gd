class_name TrainGeo
extends RefCounted
## Iron Front trains: collects flat-shaded triangles for one rigid train part (the same faceted look as the
## rifleman). Every face gets its own normal. Faces are stored clockwise seen from outside (Godot's front face).

var pos := PackedVector3Array()
var nrm := PackedVector3Array()
var col := PackedColorArray()


func tri_count() -> int:
	return pos.size() / 3


## A triangle whose outward side is the one (b - a) x (c - a) points to.
func emit(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	pos.append(a)
	pos.append(c)
	pos.append(b)
	for i in 3:
		nrm.append(n)
		col.append(color)


## A triangle facing away from the point ref.
func tri_out(a: Vector3, b: Vector3, c: Vector3, color: Color, ref: Vector3) -> void:
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - ref) < 0.0:
		emit(a, c, b, color)
	else:
		emit(a, b, c, color)


## A quad a b c d (in order round its edge) facing away from ref.
func quad_out(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, ref: Vector3) -> void:
	tri_out(a, b, c, color, ref)
	tri_out(a, c, d, color, ref)


## A prism through the rings: each ring is a closed outline; sides join ring i to ring i + 1. Caps on the ends.
func prism(rings: Array, color: Color, caps := 3, side_color: Variant = null) -> void:
	var n := rings.size()
	var centre := Vector3.ZERO
	var cnt := 0
	for r: PackedVector3Array in rings:
		for p in r:
			centre += p
			cnt += 1
	centre /= float(cnt)
	for i in n - 1:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var m := r0.size()
		var mid := Vector3.ZERO
		for p in r0:
			mid += p
		for p in r1:
			mid += p
		mid /= float(m * 2)
		for j in m:
			var j1 := (j + 1) % m
			var c: Color = color if side_color == null else side_color
			quad_out(r0[j], r0[j1], r1[j1], r1[j], c, mid)
	for e in 2:
		if not (caps & (1 << e)):
			continue
		var r: PackedVector3Array = rings[0] if e == 0 else rings[n - 1]
		var other: Vector3 = _mid(rings[1] if e == 0 else rings[n - 2])
		var cm := _mid(r)
		for j in r.size():
			tri_out(cm, r[j], r[(j + 1) % r.size()], color, other)


static func _mid(r: PackedVector3Array) -> Vector3:
	var m := Vector3.ZERO
	for p in r:
		m += p
	return m / float(r.size())


## A box with half sizes h, centred at c, turned by b. ch > 0 cuts the four long edges (along b.z) at 45 degrees.
func box(c: Vector3, h: Vector3, color: Color, b := Basis(), ch := 0.0) -> void:
	var outline := PackedVector2Array()
	if ch > 0.0:
		var k := ch
		outline = PackedVector2Array([Vector2(h.x, h.y - k), Vector2(h.x - k, h.y), Vector2(-h.x + k, h.y),
			Vector2(-h.x, h.y - k), Vector2(-h.x, -h.y + k), Vector2(-h.x + k, -h.y), Vector2(h.x - k, -h.y),
			Vector2(h.x, -h.y + k)])
	else:
		outline = PackedVector2Array([Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y), Vector2(h.x, -h.y)])
	extrude(outline, c - b.z * h.z, c + b.z * h.z, color, b)


## Extrudes a 2D outline (x, y in the frame b) from point p0 to p1 along b.z.
func extrude(outline: PackedVector2Array, p0: Vector3, p1: Vector3, color: Color, b := Basis(), caps := 3, side_color: Variant = null) -> void:
	var r0 := PackedVector3Array()
	var r1 := PackedVector3Array()
	for o in outline:
		r0.append(p0 + b.x * o.x + b.y * o.y)
		r1.append(p1 + b.x * o.x + b.y * o.y)
	prism([r0, r1], color, caps, side_color)


## A round bar (n sides) from a to b with radius r (r2 at b if given).
func cyl(a: Vector3, b: Vector3, r: float, sides: int, color: Color, r2 := -1.0, caps := 3) -> void:
	var ax := (b - a).normalized()
	var hint := Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT
	var rx := ax.cross(hint).normalized()
	var ry := ax.cross(rx).normalized()
	var rr := r if r2 < 0.0 else r2
	var r0 := PackedVector3Array()
	var r1 := PackedVector3Array()
	for i in sides:
		var t := TAU * (float(i) + 0.5) / float(sides)
		var d := rx * cos(t) + ry * sin(t)
		r0.append(a + d * r)
		r1.append(b + d * rr)
	prism([r0, r1], color, caps)


## A low dome or cap: a ring of radius r at c, rising h along up, closed at the top.
func dome(c: Vector3, r: float, h: float, sides: int, color: Color) -> void:
	var r0 := PackedVector3Array()
	var r1 := PackedVector3Array()
	for i in sides:
		var t := TAU * (float(i) + 0.5) / float(sides)
		r0.append(c + Vector3(cos(t) * r, 0, sin(t) * r))
		r1.append(c + Vector3(cos(t) * r * 0.6, h * 0.7, sin(t) * r * 0.6))
	prism([r0, r1], color, 0)
	var top := c + Vector3(0, h, 0)
	for i in sides:
		tri_out(top, r1[i], r1[(i + 1) % sides], color, c)


## Low-poly lump (puffs, coal, sand bags): an icosahedron-ish blob of radius r, squashed by s.
func lump(c: Vector3, r: float, color: Color, s := Vector3.ONE) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for tri: Array in f:
		var p: Array[Vector3] = []
		for k: int in tri:
			p.append(c + (v[k].normalized() * r) * s)
		tri_out(p[0], p[1], p[2], color, c)


func to_mesh(mat: Material) -> ArrayMesh:
	var m := ArrayMesh.new()
	if pos.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = col
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	return m


## A MeshInstance3D holding this part, named, placed at xf under parent.
func make(parent: Node3D, part_name: String, mat: Material, xf := Transform3D()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = to_mesh(mat)
	mi.transform = xf
	parent.add_child(mi)
	return mi
