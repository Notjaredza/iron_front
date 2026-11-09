class_name UnitGeo
extends RefCounted
## Collects flat-shaded, rigidly skinned triangles for one figure (Iron Front units).
## Every triangle belongs to one bone. Each face gets its own flat normal, which gives
## the faceted low-poly look. Faces are stored clockwise when seen from outside
## (Godot's front-face winding).

var pos := PackedVector3Array()
var nrm := PackedVector3Array()
var col := PackedColorArray()
var bone := PackedInt32Array()


func tri_count() -> int:
	return pos.size() / 3


## Adds a triangle whose outward side is the side (b - a) x (c - a) points to.
func emit(a: Vector3, b: Vector3, c: Vector3, color: Color, b_id: int) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	# Stored as a, c, b so it reads clockwise from outside.
	pos.append(a)
	pos.append(c)
	pos.append(b)
	for i in 3:
		nrm.append(n)
		col.append(color)
		bone.append(b_id)


## Adds a triangle facing away from the point ref.
func tri_out(a: Vector3, b: Vector3, c: Vector3, color: Color, b_id: int, ref: Vector3) -> void:
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - ref) < 0.0:
		emit(a, c, b, color, b_id)
	else:
		emit(a, b, c, color, b_id)


## One cross-section. sides 4 = rectangle, 8 with ch > 0 = chamfered rectangle,
## anything else = an n-sided ellipse.
static func ring(c: Vector3, rx: Vector3, ry: Vector3, hw: float, hd: float, sides: int, ch: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if sides == 4:
		for s: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
			out.append(c + rx * hw * s.x + ry * hd * s.y)
	elif sides == 8 and ch > 0.0:
		var k: float = ch * minf(hw, hd)
		var pts: Array[Vector2] = [
			Vector2(hw, hd - k), Vector2(hw - k, hd), Vector2(-hw + k, hd), Vector2(-hw, hd - k),
			Vector2(-hw, -hd + k), Vector2(-hw + k, -hd), Vector2(hw - k, -hd), Vector2(hw, -hd + k)]
		for p in pts:
			out.append(c + rx * p.x + ry * p.y)
	else:
		for i in sides:
			var a := TAU * (float(i) + 0.5) / float(sides)
			out.append(c + rx * cos(a) * hw + ry * sin(a) * hd)
	return out


## A tube through the centres cs, with half sizes sz (x along the hint side, y across).
## color2, if given, alternates with color on the side faces (helmet net).
## caps: 1 = start end, 2 = far end, 3 = both, 0 = open (hidden joints).
func loft(cs: Array, sz: Array, hint: Vector3, sides: int, ch: float, color: Color, b_id: int, color2: Variant = null, caps := 3) -> void:
	var n := cs.size()
	if n < 2:
		return
	var rings: Array[PackedVector3Array] = []
	for i in n:
		var ax: Vector3
		if i == 0:
			ax = cs[1] - cs[0]
		elif i == n - 1:
			ax = cs[n - 1] - cs[n - 2]
		else:
			ax = cs[i + 1] - cs[i - 1]
		ax = ax.normalized()
		var rx: Vector3 = hint - ax * hint.dot(ax)
		if rx.length_squared() < 1e-8:
			rx = ax.cross(Vector3.FORWARD)
		rx = rx.normalized()
		var ry := rx.cross(ax).normalized()
		var s: Vector2 = sz[i]
		rings.append(ring(cs[i], rx, ry, s.x, s.y, sides, ch))
	var m := rings[0].size()
	# One winding for the whole tube, picked by the faces that point clearly outward.
	var score := 0.0
	for i in n - 1:
		var ref: Vector3 = (cs[i] + cs[i + 1]) * 0.5
		for j in m:
			var j1 := (j + 1) % m
			var p00 := rings[i][j]
			var p01 := rings[i][j1]
			var p11 := rings[i + 1][j1]
			score += (p01 - p00).cross(p11 - p00).dot((p00 + p01 + p11) / 3.0 - ref)
	var flip := score < 0.0
	for i in n - 1:
		for j in m:
			var j1 := (j + 1) % m
			var p00 := rings[i][j]
			var p01 := rings[i][j1]
			var p11 := rings[i + 1][j1]
			var p10 := rings[i + 1][j]
			var c: Color = color
			if color2 != null and (i + j) % 2 == 1:
				c = color2
			if flip:
				emit(p00, p11, p01, c, b_id)
				emit(p00, p10, p11, c, b_id)
			else:
				emit(p00, p01, p11, c, b_id)
				emit(p00, p11, p10, c, b_id)
	for j in m:
		var j1 := (j + 1) % m
		if caps & 1:
			tri_out(cs[0], rings[0][j], rings[0][j1], color, b_id, cs[1])
		if caps & 2:
			tri_out(cs[n - 1], rings[n - 1][j], rings[n - 1][j1], color, b_id, cs[n - 2])


## A box with half sizes h in the frame b (its height along b.y).
func box(center: Vector3, h: Vector3, color: Color, b_id: int, b: Basis = Basis(), ch := 0.0) -> void:
	var sides := 8 if ch > 0.0 else 4
	loft([center - b.y * h.y, center + b.y * h.y], [Vector2(h.x, h.z), Vector2(h.x, h.z)], b.x, sides, ch, color, b_id)


func to_mesh(mat: Material) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = col
	var bones := PackedInt32Array()
	bones.resize(bone.size() * 4)
	var w := PackedFloat32Array()
	w.resize(bone.size() * 4)
	for i in bone.size():
		bones[i * 4] = bone[i]
		w[i * 4] = 1.0
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = w
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	return m
