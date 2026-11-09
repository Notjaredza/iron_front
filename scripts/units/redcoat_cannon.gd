class_name FieldCannon
extends Node3D
## Red coats round 2: a bronze 6-pounder field gun on a grey wooden carriage (Building Chat 1, 2026-11-10).
## The gun faces -Z. Parts: the carriage (cheeks, axle tree, trail), the barrel (turns on its trunnions to
## elevate), the two wheels (turn as the gun rolls). recoil moves the whole gun back along +Z.
## Gun-frame points for the crew's hands: muzzle_at(), vent_at(), trail_at(), wheel_top(side).

const RB := preload("res://scripts/units/redcoat_builder.gd")

const WOOD := Color(0.42, 0.45, 0.47)       # carriage painted lead grey
const WOOD_DARK := Color(0.30, 0.32, 0.34)
const IRON := Color(0.16, 0.16, 0.17)
const BRONZE := Color(0.62, 0.45, 0.22)
const BRONZE_DARK := Color(0.44, 0.31, 0.15)
const BORE := Color(0.03, 0.03, 0.03)

const WHEEL_R := 0.66
const WHEEL_X := 0.80
const TRUNNION := Vector3(0, 0.96, 0.0)
const BREECH_Z := 0.62
const MUZZLE_Z := -1.18
const TRAIL_END := Vector3(0, 0.1, 2.35)

var carriage: MeshInstance3D
var barrel: Node3D
var wheels: Array[Node3D] = []
var elevation := 0.0      # degrees, + = muzzle up
var recoil := 0.0         # metres back along +Z
static var _meshes := {}


func setup(lod := 0) -> FieldCannon:
	var key := "c%d" % lod
	if not _meshes.has(key):
		_meshes[key] = [_carriage(lod).to_mesh(Soldier.material()), _barrel(lod).to_mesh(Soldier.material()),
			_wheel(lod).to_mesh(Soldier.material())]
	var ms: Array = _meshes[key]
	carriage = MeshInstance3D.new()
	carriage.mesh = ms[0]
	add_child(carriage)
	barrel = Node3D.new()
	barrel.position = TRUNNION
	add_child(barrel)
	var bm := MeshInstance3D.new()
	bm.mesh = ms[1]
	barrel.add_child(bm)
	for s: float in [1.0, -1.0]:
		var w := Node3D.new()
		w.position = Vector3(WHEEL_X * s, WHEEL_R, 0)
		add_child(w)
		var wm := MeshInstance3D.new()
		wm.mesh = ms[2]
		wm.scale = Vector3(s, 1, 1)
		w.add_child(wm)
		wheels.append(w)
	return self


func tri_count() -> int:
	var n := 0
	for k in 3:
		n += (_meshes["c0"][k] as ArrayMesh).surface_get_array_len(0) / 3 * (2 if k == 2 else 1)
	return n


## Puts the gun at a recoil distance (m, back along +Z) and an elevation (deg); the wheels turn with the roll.
func set_state(recoil_m: float, elev_deg: float) -> void:
	recoil = recoil_m
	elevation = elev_deg

	var roll := recoil_m / WHEEL_R
	for w in wheels:
		w.rotation.x = roll
	barrel.rotation.x = deg_to_rad(elev_deg)
	# The recoil shifts the gun's own parts; the node stays where it was put.
	carriage.position.z = recoil_m
	barrel.position = TRUNNION + Vector3(0, 0, recoil_m)
	for i in wheels.size():
		wheels[i].position = Vector3(WHEEL_X * (1.0 if i == 0 else -1.0), WHEEL_R, recoil_m)


## Gun-frame points (this node's local space), with the recoil and elevation.
func muzzle_at(back := 0.0) -> Vector3:
	return barrel.transform * Vector3(0, 0, MUZZLE_Z + back)


func vent_at() -> Vector3:
	return barrel.transform * Vector3(0, 0.125, BREECH_Z - 0.17)


func bore_dir() -> Vector3:
	return barrel.transform.basis * Vector3.FORWARD


func trail_at() -> Vector3:
	return TRAIL_END + Vector3(0, 0.1, recoil)


func wheel_top(side: float) -> Vector3:
	return Vector3(WHEEL_X * side, WHEEL_R * 1.75, recoil - 0.25)


# ---------------------------------------------------------------- the meshes

static func _carriage(lod: int) -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	# The two cheeks: from just ahead of the axle up under the trunnions and down to the trail on the ground.
	for s: float in [1.0, -1.0]:
		var x := 0.17 * s
		var a := Vector3(x, 0.78, -0.35)
		var b := Vector3(x, 0.92, 0.05)
		var c := Vector3(x * 0.55, 0.12, TRAIL_END.z - 0.05)
		g.loft([a, b, Vector3(x * 0.9, 0.7, 0.8), c], [Vector2(0.045, 0.11), Vector2(0.045, 0.13), Vector2(0.045, 0.11),
			Vector2(0.045, 0.08)], X, 4, 0.0, WOOD, 0)
		# Trunnion cap squares and iron bands.
		g.box(Vector3(x, 0.99, 0.0), Vector3(0.05, 0.02, 0.07), IRON, 0)
		if lod == 0:
			for z: float in [0.45, 1.2, 1.9]:
				var t := (z - 0.8) / (TRAIL_END.z - 0.85)
				var y := lerpf(0.7, 0.12, clampf(t, 0.0, 1.0)) if z > 0.8 else lerpf(0.92, 0.7, (z - 0.05) / 0.75)
				var xx := lerpf(x * 0.9, x * 0.55, clampf(t, 0.0, 1.0))
				g.box(Vector3(xx, y, z), Vector3(0.05, 0.12, 0.015), IRON, 0)
	# Transoms between the cheeks, the trail plate and its ring, the elevating quoin under the breech.
	g.box(Vector3(0, 0.78, -0.25), Vector3(0.13, 0.05, 0.06), WOOD_DARK, 0)
	g.box(Vector3(0, 0.62, 0.95), Vector3(0.12, 0.05, 0.08), WOOD_DARK, 0)
	g.box(Vector3(0, 0.1, TRAIL_END.z - 0.02), Vector3(0.11, 0.05, 0.1), IRON, 0)
	g.box(Vector3(0, 0.76, 0.58), Vector3(0.09, 0.06, 0.16), WOOD_DARK, 0, Basis(Vector3.RIGHT, 0.15))
	# The axle tree and its iron arms.
	g.loft([Vector3(-WHEEL_X - 0.08, WHEEL_R, 0), Vector3(WHEEL_X + 0.08, WHEEL_R, 0)], [Vector2(0.05, 0.06), Vector2(0.05, 0.06)],
		Vector3.UP, 4, 0.0, WOOD_DARK, 0)
	g.box(Vector3(0, WHEEL_R + 0.09, 0), Vector3(0.3, 0.035, 0.06), WOOD, 0)
	if lod == 0:
		# Ammunition boxes on the axle tree, handles on the trail.
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.45 * s, WHEEL_R + 0.17, 0.0), Vector3(0.14, 0.08, 0.13), WOOD, 0, Basis(), 0.15)
			g.loft([Vector3(0.12 * s, 0.32, 1.85), Vector3(0.32 * s, 0.36, 1.85)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)],
				Vector3.UP, 4, 0.0, IRON, 0)
	return g


static func _barrel(lod: int) -> UnitGeo:
	var g := UnitGeo.new()
	var s := 10 if lod == 0 else 6
	var up := Vector3.UP
	# Cascabel knob, breech, reinforces, chase, muzzle swell (in the barrel's frame, the trunnions at the origin).
	g.loft([Vector3(0, 0, BREECH_Z + 0.14), Vector3(0, 0, BREECH_Z + 0.08), Vector3(0, 0, BREECH_Z + 0.03)],
		[Vector2(0.035, 0.035), Vector2(0.04, 0.04), Vector2(0.025, 0.025)], up, s, 0.0, BRONZE, 0, null, 1)
	g.loft([Vector3(0, 0, BREECH_Z + 0.03), Vector3(0, 0, BREECH_Z), Vector3(0, 0, 0.2), Vector3(0, 0, 0.12)],
		[Vector2(0.1, 0.1), Vector2(0.135, 0.135), Vector2(0.128, 0.128), Vector2(0.118, 0.118)], up, s, 0.0, BRONZE, 0, null, 1)
	g.loft([Vector3(0, 0, 0.12), Vector3(0, 0, -0.35), Vector3(0, 0, MUZZLE_Z + 0.18), Vector3(0, 0, MUZZLE_Z + 0.12)],
		[Vector2(0.11, 0.11), Vector2(0.1, 0.1), Vector2(0.085, 0.085), Vector2(0.09, 0.09)], up, s, 0.0, BRONZE, 0, null, 0)
	g.loft([Vector3(0, 0, MUZZLE_Z + 0.12), Vector3(0, 0, MUZZLE_Z + 0.05), Vector3(0, 0, MUZZLE_Z)],
		[Vector2(0.09, 0.09), Vector2(0.108, 0.108), Vector2(0.1, 0.1)], up, s, 0.0, BRONZE, 0, null, 1)
	g.loft([Vector3(0, 0, MUZZLE_Z + 0.01), Vector3(0, 0, MUZZLE_Z - 0.002)], [Vector2(0.046, 0.046), Vector2(0.046, 0.046)],
		up, s, 0.0, BORE, 0, null, 2)
	# Trunnions and the rings (darker bronze bands).
	g.loft([Vector3(-0.2, 0, 0), Vector3(0.2, 0, 0)], [Vector2(0.042, 0.042), Vector2(0.042, 0.042)], up, 6, 0.0, BRONZE_DARK, 0)
	if lod == 0:
		for z: float in [0.2, -0.3, MUZZLE_Z + 0.2]:
			var r := 0.12 if z > 0.0 else (0.106 if z > -0.5 else 0.092)
			g.loft([Vector3(0, 0, z + 0.015), Vector3(0, 0, z - 0.015)], [Vector2(r, r), Vector2(r, r)], up, s, 0.0, BRONZE_DARK, 0, null, 0)
		# The dolphins (lifting handles) and the vent's touch hole.
		for sx: float in [1.0, -1.0]:
			g.loft([Vector3(0.05 * sx, 0.11, 0.1), Vector3(0.06 * sx, 0.17, -0.02), Vector3(0.05 * sx, 0.11, -0.12)],
				[Vector2(0.016, 0.016), Vector2(0.018, 0.018), Vector2(0.016, 0.016)], Vector3.RIGHT, 4, 0.0, BRONZE_DARK, 0)
		g.box(Vector3(0, 0.128, BREECH_Z - 0.17), Vector3(0.022, 0.006, 0.022), BRONZE_DARK, 0)
		g.box(Vector3(0, 0.133, BREECH_Z - 0.17), Vector3(0.007, 0.003, 0.007), BORE, 0)
	return g


static func _wheel(lod: int) -> UnitGeo:
	var g := UnitGeo.new()
	var n := 24 if lod == 0 else 12
	var spokes := 12 if lod == 0 else 6
	var X := Vector3.RIGHT
	# The felloes (rim) and the iron tyre, as a ring of short segments round the X axis.
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var p0 := Vector3(0, cos(a0), sin(a0))
		var p1 := Vector3(0, cos(a1), sin(a1))
		g.loft([p0 * (WHEEL_R - 0.045), p1 * (WHEEL_R - 0.045)], [Vector2(0.04, 0.045), Vector2(0.04, 0.045)], X, 4, 0.0, WOOD, 0, null, 0)
		g.loft([p0 * (WHEEL_R - 0.006), p1 * (WHEEL_R - 0.006)], [Vector2(0.042, 0.008), Vector2(0.042, 0.008)], X, 4, 0.0, IRON, 0, null, 0)
	for i in spokes:
		var a := TAU * (float(i) + 0.5) / float(spokes)
		var d := Vector3(0, cos(a), sin(a))
		g.loft([d * 0.1 + Vector3(-0.03, 0, 0), d * (WHEEL_R - 0.08)], [Vector2(0.02, 0.028), Vector2(0.016, 0.022)],
			X, 4, 0.0, WOOD, 0, null, 0)
	g.loft([Vector3(-0.1, 0, 0), Vector3(-0.02, 0, 0), Vector3(0.12, 0, 0)], [Vector2(0.1, 0.1), Vector2(0.12, 0.12), Vector2(0.07, 0.07)],
		Vector3.UP, 8 if lod == 0 else 6, 0.0, WOOD_DARK, 0)
	g.loft([Vector3(0.12, 0, 0), Vector3(0.15, 0, 0)], [Vector2(0.04, 0.04), Vector2(0.04, 0.04)], Vector3.UP, 6, 0.0, IRON, 0)
	return g
