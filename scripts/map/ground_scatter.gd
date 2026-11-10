class_name GroundScatter
extends Node3D
## Iron Front: grass tufts and flowers near the camera (light). The ground round the camera is cut into 64 m
## tiles. Each tile gets a MultiMesh of tufts and two of flowers (white and yellow), placed on a 4 m grid with a hash,
## so a tile always looks the same. Tiles are built as the camera comes near (two a frame) and freed when it leaves.
## They fade out by about 170 m, and from high up there are none.

const TILE := 64.0
const STEP := 4.0
const RADIUS := 200.0
const SHOW_H := 260.0          # camera height above which there are no tufts
const TUFT_P := 0.16            # spots with a little cluster of tufts
const FLOWER_P := 0.035
const ROW := 2.0 / 0.9           # crop row spacing, matches the ground shader rows

var data: MapData
var mat: Material
var _tiles: Dictionary = {}    # Vector2i -> Node3D
var _meshes: Array[Mesh] = []


func _ready() -> void:
	_meshes = [_tuft_mesh(), _flower_mesh(Color(0.95, 0.95, 0.90)), _flower_mesh(Color(0.96, 0.80, 0.26)),
		_tall_mesh(), _wheat_mesh()]


func clear() -> void:
	for t in _tiles.values():
		(t as Node).queue_free()
	_tiles.clear()


func update(target: Vector3, height: float) -> void:
	if data == null:
		return
	visible = height < SHOW_H
	if not visible:
		return
	var centre := Vector2i(floori(target.x / TILE), floori(target.z / TILE))
	var reach := ceili(RADIUS / TILE)
	var built := 0
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := centre + Vector2i(dx, dz)
			if _tiles.has(key) or built >= 2:
				continue
			var mid := (Vector2(key) + Vector2(0.5, 0.5)) * TILE
			if mid.distance_to(Vector2(target.x, target.z)) > RADIUS + TILE * 0.7:
				continue
			_tiles[key] = _build(key)
			built += 1
	for key: Vector2i in _tiles.keys():
		var mid := (Vector2(key) + Vector2(0.5, 0.5)) * TILE
		if mid.distance_to(Vector2(target.x, target.z)) > RADIUS + TILE * 2.0:
			(_tiles[key] as Node).queue_free()
			_tiles.erase(key)


func _build(key: Vector2i) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	var lists: Array = [[], [], [], [], []]
	var n := int(TILE / STEP)
	for gz in n:
		for gx in n:
			var wx := key.x * TILE + (gx + 0.5) * STEP
			var wz := key.y * TILE + (gz + 0.5) * STEP
			var k := hash(Vector3i(int(wx), int(wz), data.seed))
			var r := float(k % 10007) / 10007.0
			if r >= TUFT_P + FLOWER_P:
				continue
			var j1 := float((k / 7) % 1000) / 1000.0
			var j2 := float((k / 13) % 1000) / 1000.0
			var p := Vector2(wx + (j1 - 0.5) * STEP * 0.8, wz + (j2 - 0.5) * STEP * 0.8)
			var cx := int(p.x / MapData.CELL)
			var cz := int(p.y / MapData.CELL)
			if cx < 0 or cz < 0 or cx >= data.w or cz >= data.h:
				continue
			var f := data.walk[cz * data.w + cx]
			if f == 0 or f == MapData.FLAT_NONE or data.busy[cz * data.w + cx] == 1:
				continue
			if (data.feat[cz * data.w + cx] & (MapData.F_FIELD | MapData.F_STREAM)) != 0:
				continue
			var which := 0 if r < TUFT_P else 1 + (k / 19) % 2
			var count := (2 + (k / 23) % 4) if which == 0 else (1 + (k / 29) % 3)
			for q in count:
				var kq := hash(Vector2i(k, q))
				var off := Vector2(float(kq % 100) / 100.0 - 0.5, float((kq / 100) % 100) / 100.0 - 0.5) * (1.4 if q > 0 else 0.0)
				var s := 0.85 + 0.6 * float((kq / 7) % 100) / 100.0
				var b := Basis(Vector3.UP, float((kq / 3) % 628) / 100.0).scaled(Vector3(s, s, s))
				lists[which].append(Transform3D(b, Vector3(p.x + off.x, MapData.level_y(f), p.y + off.y)))
	_patches(key, lists)
	for i in lists.size():
		var l: Array = lists[i]
		if l.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[i]
		mm.instance_count = l.size()
		for q in l.size():
			mm.set_instance_transform(q, l[q])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 170.0
		mi.visibility_range_end_margin = 30.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(mi)
	return node


## Map round 3: tall grass clumps on F_TALL cells and wheat on wheat fields (crop 1), per 8 m cell.
func _patches(key: Vector2i, lists: Array) -> void:
	var cn := int(TILE / MapData.CELL)
	var cx0 := int(key.x * TILE / MapData.CELL)
	var cz0 := int(key.y * TILE / MapData.CELL)
	for gz in cn:
		for gx in cn:
			var cx := cx0 + gx
			var cz := cz0 + gz
			if cx < 0 or cz < 0 or cx >= data.w or cz >= data.h:
				continue
			var i := cz * data.w + cx
			var f := data.walk[i]
			if f == 0 or f == MapData.FLAT_NONE or data.busy[i] == 1:
				continue
			var ft := data.feat[i]
			var which := -1
			var count := 0
			if (ft & MapData.F_FIELD) != 0 and data.crop[i] == 1:
				which = 4
				count = 14
			elif (ft & MapData.F_TALL) != 0:
				which = 3
				count = 7
			if which < 0:
				continue
			var y := MapData.level_y(f)
			for q in count:
				var kq := hash(Vector3i(cx, cz, q * 31 + data.seed))
				var px := (cx + float(kq % 1000) / 1000.0) * MapData.CELL
				var pz := (cz + float((kq / 1000) % 1000) / 1000.0) * MapData.CELL
				if which == 4:
					# Wheat in rows: snap across the rows so the field reads as planted.
					var along_x := data.crop[i] % 2 == 1
					if along_x:
						pz = (floorf(pz / ROW) + 0.25) * ROW
					else:
						px = (floorf(px / ROW) + 0.25) * ROW
				var s := 0.8 + 0.5 * float((kq / 7) % 100) / 100.0
				var b := Basis(Vector3.UP, float((kq / 3) % 628) / 100.0).scaled(Vector3(s, s * (0.9 + 0.2 * float((kq / 11) % 10) / 10.0), s))
				lists[which].append(Transform3D(b, Vector3(px, y, pz)))


## A tall grass clump: nine long bending blades, dry tips.
func _tall_mesh() -> ArrayMesh:
	var st := _St.new()
	for i in 9:
		var a := i * TAU / 9.0 + 0.4 * sin(i * 1.7)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * 0.07
		var root := dir * (0.1 + 0.08 * (i % 3))
		var h := 0.95 + 0.35 * ((i * 5) % 4) / 3.0
		var mid := dir * 0.3 + Vector3(0, h * 0.55, 0)
		var tip := dir * 0.62 + Vector3(0, h, 0)
		var col := Color(0.46, 0.58, 0.24) if i % 2 == 0 else Color(0.56, 0.62, 0.30)
		st.two_sided(root - side, root + side, mid, col)
		st.two_sided(mid - side * 0.8, mid + side * 0.8, tip, Color(0.70, 0.68, 0.40) if i % 3 == 0 else col.lightened(0.1))
	return st.mesh()


## A wheat clump: seven upright stalks with golden ears.
func _wheat_mesh() -> ArrayMesh:
	var st := _St.new()
	var stalk := Color(0.80, 0.68, 0.34)
	var ear := Color(0.90, 0.76, 0.38)
	for i in 7:
		var a := i * TAU / 7.0
		var r := 0.12 + 0.1 * (i % 3)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var lean := Vector3(cos(a), 0, sin(a)) * 0.06
		var h := 0.9 + 0.15 * ((i * 3) % 4) / 3.0
		var side := Vector3(-sin(a), 0, cos(a)) * 0.025
		var top := p + lean + Vector3(0, h, 0)
		st.two_sided(p - side, p + side, top, stalk)
		var e0 := top - Vector3(0, 0.2, 0)
		st.two_sided(e0 - side * 2.2, e0 + side * 2.2, top + Vector3(0, 0.06, 0), ear)
	return st.mesh()


## Five thin blades, each drawn on both sides.
func _tuft_mesh() -> ArrayMesh:
	var st := _St.new()
	for i in 5:
		var a := i * TAU / 5.0 + 0.3 * sin(i * 2.1)
		var dir := Vector3(cos(a), 0, sin(a))
		var side_w := 0.1
		var side := Vector3(-dir.z, 0, dir.x) * side_w
		var root := dir * 0.08
		var tip := dir * (0.26 + 0.08 * (i % 2)) + Vector3(0, 0.55 + 0.2 * ((i * 3) % 4) / 3.0, 0)
		var col := Color(0.40, 0.60, 0.22) if i % 2 == 0 else Color(0.50, 0.68, 0.28)
		st.two_sided(root - side, root + side, tip, col)
	return st.mesh()


## A stem blade with a little star of petals and a centre.
func _flower_mesh(petal: Color) -> ArrayMesh:
	var st := _St.new()
	var stem := Color(0.34, 0.52, 0.2)
	st.two_sided(Vector3(-0.04, 0, 0), Vector3(0.04, 0, 0), Vector3(0, 0.5, 0), stem)
	var c := Vector3(0, 0.5, 0)
	for i in 5:
		var a := i * TAU / 5.0
		var p0 := c + Vector3(cos(a - 0.35), 0.02, sin(a - 0.35)) * 0.07
		var p1 := c + Vector3(cos(a + 0.35), 0.02, sin(a + 0.35)) * 0.07
		var tip := c + Vector3(cos(a) * 0.17, 0.0, sin(a) * 0.17)
		st.two_sided(p0, p1, tip, petal)
	st.two_sided(c + Vector3(-0.03, 0.03, -0.02), c + Vector3(0.03, 0.03, -0.02), c + Vector3(0, 0.03, 0.035), Color(0.9, 0.62, 0.15))
	return st.mesh()


class _St:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

	func two_sided(a: Vector3, b: Vector3, t: Vector3, col: Color) -> void:
		var nn := (b - a).cross(t - a).normalized()
		for s in [1.0, -1.0]:
			var tri: Array = [a, b, t] if s > 0.0 else [a, t, b]
			for p: Vector3 in tri:
				v.append(p)
				n.append(-nn * s)
				c.append(col)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m
