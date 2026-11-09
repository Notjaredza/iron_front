extends RefCounted
## The heavy machine gun team's gear, built in code in the rifleman's faceted style
## (Question Chat, 2026-11-09). A generic water-cooled tripod gun, not a copy of a
## real one. Every piece is a static mesh in its own frame:
##   gun     barrel along -Z, origin at the trunnion pin it pivots on
##   tripod  origin on the ground under the pin; the pin sits at PIN_H
##   box     origin at the bottom centre, the handle on top
##   shield  origin at the bottom centre of the plate
## Points other code (grips, IK) needs are constants below.

const B := preload("res://scripts/units/soldier_builder.gd")

const PIN_H := 0.52  # trunnion height above the ground when set up
## Gun frame points.
const GRIP_R := Vector3(0.075, -0.03, 0.40)  # spade grips at the back
const GRIP_L := Vector3(-0.075, -0.03, 0.40)
const FEED := Vector3(0.09, 0.03, 0.10)  # where the belt goes in (right side)
const MUZZLE := Vector3(0, 0.02, -0.86)
const CARRY := Vector3(0, 0.09, 0.05)  # the top handle, for carrying
## Box frame points.
const BOX_HANDLE := Vector3(0, 0.215, 0)

const STEEL := Color(0.21, 0.22, 0.21)
const STEEL_DARK := Color(0.13, 0.13, 0.14)
const JACKET := Color(0.30, 0.33, 0.24)  # painted water jacket
const BRASS := Color(0.70, 0.58, 0.30)
const BOX := Color(0.36, 0.40, 0.24)
const BOX_DARK := Color(0.26, 0.29, 0.17)
const STENCIL := Color(0.80, 0.77, 0.62)
const CANVAS := Color(0.55, 0.49, 0.34)


static func gun(lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	var d0 := lod == 0
	var js := 10 if d0 else 6
	# Receiver: the boxy body, with the cover on top and the trunnion block under.
	g.box(Vector3(0, 0.0, 0.14), Vector3(0.062, 0.075, 0.2), STEEL, 0, Basis(), 0.2 if d0 else 0.0)
	g.box(Vector3(0, 0.083, 0.16), Vector3(0.055, 0.012, 0.15), STEEL_DARK, 0)
	g.box(Vector3(0, -0.07, 0.0), Vector3(0.05, 0.035, 0.05), STEEL_DARK, 0)
	# Water jacket with two rings, the muzzle booster, the steam pipe on the left.
	g.loft([Vector3(0, 0.02, -0.06), Vector3(0, 0.02, -0.70)], [Vector2(0.06, 0.06), Vector2(0.06, 0.06)],
		X, js, 0.0, JACKET, 0)
	if d0:
		for z in [-0.12, -0.64]:
			g.loft([Vector3(0, 0.02, z + 0.015), Vector3(0, 0.02, z - 0.015)], [Vector2(0.066, 0.066), Vector2(0.066, 0.066)],
				X, js, 0.0, STEEL_DARK, 0)
		g.loft([Vector3(-0.06, -0.01, -0.62), Vector3(-0.075, -0.05, -0.62), Vector3(-0.075, -0.08, -0.56)],
			[Vector2(0.011, 0.011), Vector2(0.011, 0.011), Vector2(0.011, 0.011)], X, 4, 0.0, STEEL_DARK, 0)
		g.box(Vector3(0, 0.085, -0.66), Vector3(0.008, 0.02, 0.008), STEEL_DARK, 0)  # front sight
	g.loft([Vector3(0, 0.02, -0.70), Vector3(0, 0.02, -0.80), Vector3(0, 0.02, -0.86)],
		[Vector2(0.04, 0.04), Vector2(0.03, 0.03), Vector2(0.022, 0.022)], X, 6 if d0 else 4, 0.0, STEEL_DARK, 0)
	# Spade grips and the thumb trigger between them.
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(0.04 * s, 0.0, 0.34), Vector3(0.075 * s, -0.03, 0.40)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)],
			X, 4, 0.0, STEEL, 0)
		g.loft([Vector3(0.075 * s, 0.02, 0.40), Vector3(0.075 * s, -0.09, 0.40)], [Vector2(0.018, 0.018), Vector2(0.018, 0.018)],
			Vector3.FORWARD, 6 if d0 else 4, 0.0, B.WOOD_DARK, 0)
	g.box(Vector3(0, -0.01, 0.37), Vector3(0.02, 0.025, 0.012), BRASS, 0)
	# Rear sight leaf and the carrying handle.
	if d0:
		g.box(Vector3(0, 0.12, 0.26), Vector3(0.012, 0.03, 0.006), STEEL_DARK, 0)
		g.loft([Vector3(0, 0.09, -0.02), Vector3(0, 0.13, 0.05), Vector3(0, 0.09, 0.12)],
			[Vector2(0.01, 0.008), Vector2(0.01, 0.008), Vector2(0.01, 0.008)], X, 4, 0.0, STEEL_DARK, 0)
	# Belt feed block on the right with a short length of belt hanging out.
	g.box(Vector3(0.085, 0.03, 0.10), Vector3(0.03, 0.03, 0.035), STEEL_DARK, 0)
	if d0:
		for i in 5:
			var y := 0.0 - 0.035 * i
			var x := 0.12 + 0.012 * i
			g.box(Vector3(x, y, 0.10), Vector3(0.016, 0.012, 0.03), CANVAS, 0)
			g.box(Vector3(x, y + 0.004, 0.10), Vector3(0.007, 0.007, 0.034), BRASS, 0)
	return g


## The tripod set up (open) or folded for carrying.
static func tripod(folded := false, lod := 0) -> UnitGeo:
	return tripod_at(0.0 if folded else 1.0, lod)


## The tripod part way open: 0 = folded flat (legs together along Z), 1 = set up.
static func tripod_at(open: float, lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var o := clampf(open, 0.0, 1.0)
	var top := Vector3(0, 0.03, 0).lerp(Vector3(0, PIN_H - 0.08, 0), o)
	var f0: Array[Vector3] = [Vector3(0, 0.03, -0.75), Vector3(0.05, 0.03, 0.7), Vector3(-0.05, 0.03, 0.7)]
	var f1: Array[Vector3] = [Vector3(0, 0.0, -0.62), Vector3(0.42, 0.0, 0.5), Vector3(-0.42, 0.0, 0.5)]
	var ls := 6 if lod == 0 else 4
	for i in 3:
		var f := f0[i].lerp(f1[i], o)
		g.loft([top, f], [Vector2(0.022, 0.022), Vector2(0.017, 0.017)], Vector3.UP if o > 0.2 else Vector3.RIGHT,
			ls, 0.0, STEEL, 0)
		if o > 0.9:
			g.box(f + Vector3(0, 0.012, 0), Vector3(0.035, 0.012, 0.035), STEEL_DARK, 0)  # foot pad
	g.box(top, Vector3(0.08, 0.035, 0.07), STEEL_DARK, 0, Basis(), 0.25 if lod == 0 else 0.0)
	if o > 0.6:
		var ph := top.y + 0.08
		g.loft([top, Vector3(0, ph - 0.03, 0)], [Vector2(0.03, 0.03), Vector2(0.03, 0.03)], Vector3.RIGHT, 6, 0.0, STEEL, 0)
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.05 * s, ph - 0.02, 0), Vector3(0.012, 0.04, 0.04), STEEL_DARK, 0)
		if lod == 0:
			g.loft([Vector3(0.2, top.y - 0.02, 0.14), Vector3(0, top.y - 0.02, 0.2), Vector3(-0.2, top.y - 0.02, 0.14)],
				[Vector2(0.012, 0.006), Vector2(0.012, 0.006), Vector2(0.012, 0.006)], Vector3.UP, 4, 0.0, STEEL_DARK, 0)
	return g


## A length of belt through the given points (canvas with brass rounds), for the feed.
static func belt(points: PackedVector3Array) -> UnitGeo:
	var g := UnitGeo.new()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var d := b - a
		var n := maxi(1, int(d.length() / 0.035))
		var dir := d.normalized()
		var side := dir.cross(Vector3.UP)
		if side.length_squared() < 1e-4:
			side = Vector3.RIGHT
		var bas := Basis(side.normalized(), dir, side.normalized().cross(dir)).orthonormalized()
		for k in n:
			var p := a + d * ((float(k) + 0.5) / float(n))
			g.box(p, Vector3(0.03, 0.012, 0.004), CANVAS, 0, bas)
			g.box(p + bas.z * 0.006, Vector3(0.026, 0.006, 0.006), BRASS, 0, bas)
	return g


## A sagging curve from a to b (for the belt).
static func sag(a: Vector3, b: Vector3, drop: float, n := 8) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n + 1:
		var u := float(i) / float(n)
		out.append(a.lerp(b, u) + Vector3(0, -drop * 4.0 * u * (1.0 - u), 0))
	return out


static func ammo_box(open := false) -> UnitGeo:
	var g := UnitGeo.new()
	g.box(Vector3(0, 0.095, 0), Vector3(0.05, 0.095, 0.14), BOX, 0, Basis(), 0.15)
	g.box(Vector3(0, 0.196, 0), Vector3(0.053, 0.008, 0.143), BOX_DARK, 0)  # lid
	g.box(Vector3(0.051, 0.12, 0), Vector3(0.002, 0.018, 0.1), STENCIL, 0)  # stencil band
	g.box(Vector3(-0.051, 0.12, 0), Vector3(0.002, 0.018, 0.1), STENCIL, 0)
	g.loft([Vector3(0, 0.204, -0.05), Vector3(0, 0.222, -0.03), Vector3(0, 0.222, 0.03), Vector3(0, 0.204, 0.05)],
		[Vector2(0.008, 0.006), Vector2(0.008, 0.006), Vector2(0.008, 0.006), Vector2(0.008, 0.006)],
		Vector3.RIGHT, 4, 0.0, STEEL_DARK, 0)
	if open:
		for i in 4:
			g.box(Vector3(0, 0.205, -0.09 + 0.06 * i), Vector3(0.03, 0.01, 0.012), BRASS, 0)
	return g


## A plain steel shield with a notch for the barrel (optional extra).
static func shield() -> UnitGeo:
	var g := UnitGeo.new()
	var plate := Color(0.32, 0.35, 0.25)
	g.box(Vector3(-0.17, 0.22, 0), Vector3(0.12, 0.22, 0.008), plate, 0)
	g.box(Vector3(0.17, 0.22, 0), Vector3(0.12, 0.22, 0.008), plate, 0)
	g.box(Vector3(0, 0.08, 0), Vector3(0.05, 0.08, 0.008), plate, 0)
	g.box(Vector3(0, 0.40, 0), Vector3(0.05, 0.04, 0.008), plate, 0)
	return g


## A static mesh for a piece (no bones).
static func mesh(g: UnitGeo) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = g.pos
	arr[Mesh.ARRAY_NORMAL] = g.nrm
	arr[Mesh.ARRAY_COLOR] = g.col
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, Soldier.material())
	return m


## The whole gun set up on its tripod (with the shield if asked), as one node.
static func set_up(with_shield := false, lod := 0) -> Node3D:
	var n := Node3D.new()
	n.name = "HeavyMG"
	var tri := MeshInstance3D.new()
	tri.mesh = mesh(tripod(false, lod))
	n.add_child(tri)
	var gm := MeshInstance3D.new()
	gm.name = "Gun"
	gm.mesh = mesh(gun(lod))
	gm.position = Vector3(0, PIN_H, 0)
	n.add_child(gm)
	if with_shield:
		var sh := MeshInstance3D.new()
		sh.mesh = mesh(shield())
		sh.position = Vector3(0, 0.3, -0.2)
		n.add_child(sh)
	return n
