class_name TreeKit
extends RefCounted
## Iron Front map round 3: low-poly tree meshes for the woods and lone trees (drawn as MultiMeshes per chunk).
## Flat-shaded, vertex coloured, alpha 1 (plain) so the ground shader's day/night/fog looks apply.
## Kinds: 0 round broadleaf (dark), 1 round broadleaf (light), 2 tall broadleaf, 3 pine (dark), 4 pine (light).

const KINDS := 5
const TRUNK := Color(0.36, 0.26, 0.18)


static func pick(pine: bool, r: float) -> int:
	if pine:
		return 3 if r < 0.55 else 4
	return 0 if r < 0.4 else (1 if r < 0.75 else 2)


static func meshes() -> Array[Mesh]:
	var out: Array[Mesh] = []
	out.append(_broadleaf(Color(0.22, 0.40, 0.16), 9.0, 3.6, 11))
	out.append(_broadleaf(Color(0.33, 0.50, 0.20), 8.0, 3.2, 23))
	out.append(_tall(Color(0.28, 0.46, 0.18), 12.0, 2.2, 37))
	out.append(_pine(Color(0.16, 0.31, 0.17), 13.0, 3.0))
	out.append(_pine(Color(0.22, 0.38, 0.20), 11.0, 2.6))
	return out


static func _h(k: int) -> float:
	return float(hash(k) % 10007) / 10007.0


## A round tree: a trunk and a canopy of two overlapping lumps.
static func _broadleaf(leaf: Color, h: float, r: float, k: int) -> ArrayMesh:
	var st := _St.new()
	st.prism(Vector3.ZERO, 0.32, 0.22, h * 0.5, 5, TRUNK)
	st.lump(Vector3(0, h * 0.45, 0), r, h * 0.55, k, leaf)
	st.lump(Vector3(r * 0.35, h * 0.62, r * 0.2), r * 0.65, h * 0.38, k + 50, leaf.lightened(0.07))
	return st.mesh()


## A tall narrow broadleaf (poplar-like).
static func _tall(leaf: Color, h: float, r: float, k: int) -> ArrayMesh:
	var st := _St.new()
	st.prism(Vector3.ZERO, 0.26, 0.18, h * 0.35, 5, TRUNK)
	st.lump(Vector3(0, h * 0.25, 0), r, h * 0.78, k, leaf)
	return st.mesh()


## A pine: a trunk and three stacked cones.
static func _pine(leaf: Color, h: float, r: float) -> ArrayMesh:
	var st := _St.new()
	st.prism(Vector3.ZERO, 0.28, 0.18, h * 0.3, 5, TRUNK)
	for i in 3:
		var y0 := h * (0.2 + 0.24 * i)
		var rr := r * (1.0 - 0.25 * i)
		st.cone(Vector3(0, y0, 0), rr, h * 0.42, 7, leaf.lightened(0.04 * i))
	return st.mesh()


class _St:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

	func tri(a: Vector3, b: Vector3, e: Vector3, col: Color, want: Vector3) -> void:
		var nn := (b - a).cross(e - a)
		if nn.length_squared() < 1e-10:
			return
		if nn.dot(want) > 0.0:
			var t := b
			b = e
			e = t
			nn = -nn
		nn = -nn.normalized()
		v.append_array([a, b, e])
		n.append_array([nn, nn, nn])
		c.append_array([col, col, col])

	func prism(p: Vector3, r0: float, r1: float, h: float, sides: int, col: Color) -> void:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var b0 := p + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var b1 := p + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var t0 := p + Vector3(cos(a0) * r1, h, sin(a0) * r1)
			var t1 := p + Vector3(cos(a1) * r1, h, sin(a1) * r1)
			var out := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
			tri(b0, b1, t1, col.darkened(0.05 * (i % 2)), out)
			tri(b0, t1, t0, col.darkened(0.05 * (i % 2)), out)

	func cone(p: Vector3, r: float, h: float, sides: int, col: Color) -> void:
		var top := p + Vector3(0, h, 0)
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var b0 := p + Vector3(cos(a0) * r, 0, sin(a0) * r)
			var b1 := p + Vector3(cos(a1) * r, 0, sin(a1) * r)
			var out := Vector3(cos((a0 + a1) * 0.5), 0.5, sin((a0 + a1) * 0.5))
			tri(b0, b1, top, col.darkened(0.06 * (i % 2)), out)
			tri(b0, b1, p + Vector3(0, h * 0.12, 0), col.darkened(0.25), Vector3.DOWN)

	## A low-poly lump: apex, a jittered ring of 6 and a base ring of 6 and a bottom point.
	func lump(p: Vector3, r: float, h: float, k: int, col: Color) -> void:
		var top := p + Vector3(0, h, 0)
		var bot := p + Vector3(0, h * 0.05, 0)
		var mid := []
		var low := []
		for i in 6:
			var a := TAU * i / 6.0 + TreeKit._h(k + i) * 0.3
			var rr := r * (0.85 + 0.3 * TreeKit._h(k + 10 + i))
			mid.append(p + Vector3(cos(a) * rr, h * (0.55 + 0.15 * TreeKit._h(k + 20 + i)), sin(a) * rr))
			var b := a + TAU / 12.0
			low.append(p + Vector3(cos(b) * r * 0.75, h * 0.2, sin(b) * r * 0.75))
		var cen := p + Vector3(0, h * 0.5, 0)
		for i in 6:
			var m0: Vector3 = mid[i]
			var m1: Vector3 = mid[(i + 1) % 6]
			var l0: Vector3 = low[i]
			var lp: Vector3 = low[(i + 5) % 6]
			tri(top, m0, m1, col.lightened(0.06), (top + m0 + m1) / 3.0 - cen)
			tri(m0, m1, l0, col, (m0 + m1 + l0) / 3.0 - cen)
			tri(m0, lp, l0, col.darkened(0.05), (m0 + lp + l0) / 3.0 - cen)
			tri(l0, low[(i + 1) % 6], bot, col.darkened(0.2), Vector3.DOWN)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m
