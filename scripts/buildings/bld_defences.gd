class_name BldDefences
extends RefCounted
## Iron Front field defences (Asset Builder Chat): sandbag lines that join up as they are dragged, wire
## belts, concertina coils, hedgehogs and concrete teeth, an MG nest and a field gun pit. The nest and the
## pit are crewed with the approved heavy MG team and field gun crew (their models and poses are read only;
## they are placed and posed from here). BldDefences.set_crew(b, on) shows or hides a crew.

const P := preload("res://scripts/buildings/bld_parts.gd")
const W := preload("res://scripts/buildings/bld_walls.gd")
const MG := preload("res://scripts/units/mg_builder.gd")
const CM := preload("res://scripts/units/anim/clips_mg.gd")
const GB := preload("res://scripts/vehicles/field_gun_builder.gd")
const GC := preload("res://scripts/units/anim/clips_gun.gd")

const LINE_H := 1.25    # sandbag breastwork height (rows of 0.28 m)
const DIRS := {1: Vector3(0, 0, -1), 2: Vector3(1, 0, 0), 4: Vector3(0, 0, 1), 8: Vector3(-1, 0, 0)}


## A far-look stand-in (drawn only in the far look).
static func _far(g: BGeo, c: Vector3, h: Vector3, col: Color, bb := Basis()) -> void:
	var tr := g.tier
	var tg := g.tag
	g.tier = 2
	g.tag = "far"
	g.box(c, h, col, bb)
	g.tier = tr
	g.tag = tg


## A far ring of sandbag stand-ins along pts.
static func _far_ring(g: BGeo, pts: Array[Vector3]) -> void:
	for k in pts.size() - 1:
		var a := pts[k]
		var e := pts[k + 1]
		var d := e - a
		_far(g, (a + e) * 0.5 + Vector3(0, 0.55, 0), Vector3(0.5, 0.55, d.length() * 0.5 + 0.2), P.SANDBAG_DARK,
			Basis(Vector3.UP, atan2(d.x, d.z)))


static func set_crew(b: Building, on: bool) -> void:
	for s: Node3D in b.get_meta("crew", []):
		s.visible = on


## A sandbag line piece for one 8 m cell, its arms out to the sides in mask (bits as BldWalls: N 1 = -Z,
## E 2, S 4, W 8). Use BldWalls.solve on the dragged cells to get each cell's mask.
static func line(mask: int) -> Building:
	var b := Building.new()
	b.kind = "sandbag_line"
	b.name = "SandbagLine_%d" % mask
	b.tiles = Vector2i.ONE
	b.set_meta("mask", mask)
	var g := b.g
	if mask == 0:
		mask = 1 | 4
	var n := 0
	for bit: int in DIRS:
		if mask & bit:
			n += 1
			var d: Vector3 = DIRS[bit]
			var side := Vector3(-d.z, 0, d.x)
			# the bags, a duckboard firing step behind (on the +side), a revetment post every 2 m
			P.sandbags(g, Vector3.ZERO + d * 0.0, d * 4.0, 5, 2)
			_far(g, d * 2.0 + Vector3(0, 0.6, 0), Vector3(absf(d.x) * 2.0 + absf(side.x) * 0.55, 0.6, absf(d.z) * 2.0 + absf(side.z) * 0.55), P.SANDBAG_DARK)
			g.tier = 3
			g.box(d * 2.1 + side * 1.0 + Vector3(0, 0.22, 0), Vector3(absf(d.x) * 2.1 + absf(side.x) * 0.3, 0.06,
				absf(d.z) * 2.1 + absf(side.z) * 0.3), P.TIMBER)
			g.tag = "detail"
			for k in 2:
				var p := d * (1.0 + float(k) * 2.0) + side * 0.62
				g.cyl(p, p + Vector3(0, LINE_H + 0.1, 0), 0.05, 4, P.TIMBER_DARK)
			g.tag = ""
			g.tier = 1
	if n != 2 or mask in [3, 6, 12, 9]:
		g.tier = 1
		g.lump(Vector3(0, 0.6, 0), 0.9, P.SANDBAG_DARK, Vector3(1.2, 0.8, 1.2))
	b.finish()
	return b


## A wire belt, 1x1 tile: two rows of iron pickets with barbed wire strung criss-cross between them.
static func wire_belt(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.02, 0), Vector3(4.0, 0.02, 2.4), P.EARTH)
	g.tier = 1
	g.tag = "keep"
	for r in 2:
		var z := -1.2 + float(r) * 2.4
		for k in 5:
			var x := -3.6 + float(k) * 1.8 + float(r) * 0.9
			if x > 3.9:
				continue
			g.cyl(Vector3(x, 0, z), Vector3(x, 1.3, z + (BGeo._h(k + r * 7, 3) - 0.5) * 0.2), 0.035, 4, P.IRON_RUST)
	g.tag = ""
	g.tier = 3
	g.tag = "detail"
	for y in [0.25, 0.6, 0.95, 1.25]:
		for r in 2:
			var z := -1.2 + float(r) * 2.4
			g.cyl(Vector3(-4.0, y, z), Vector3(4.0, y, z), 0.01, 3, P.WIRE)
	for k in 9:
		var x := -4.0 + float(k)
		g.cyl(Vector3(x, 1.2, -1.2), Vector3(x + 1.0, 0.1, 1.2), 0.01, 3, P.WIRE)
		g.cyl(Vector3(x, 0.1, -1.2), Vector3(x + 1.0, 1.2, 1.2), 0.01, 3, P.WIRE)
	g.tag = ""
	b.marks["blocks"] = true


## Concertina coils, 1x1 tile: two coils side by side and one on top, each a run of wire loops.
static func concertina(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.02, 0), Vector3(4.0, 0.02, 1.6), P.EARTH)
	g.tier = 1
	for c in 3:
		var cz := [-0.45, 0.45, 0.0][c] as float
		var cy := [0.42, 0.42, 1.1][c] as float
		_far(g, Vector3(0, [0.42, 0.42, 1.1][c], [-0.45, 0.45, 0.0][c]), Vector3(3.9, 0.4, 0.4), Color(0.25, 0.24, 0.22))
		var r := 0.42
		for k in 22:
			var x := -3.9 + float(k) * 0.37
			var tilt := Basis(Vector3.FORWARD, 0.35 * (1.0 if k % 2 == 0 else -1.0))
			g.tier = 3
			g.tag = "detail"
			for s in 8:
				var a0 := TAU * float(s) / 8.0
				var a1 := TAU * float(s + 1) / 8.0
				var p0 := Vector3(x, cy, cz) + tilt * Vector3(0, sin(a0) * r, cos(a0) * r)
				var p1 := Vector3(x, cy, cz) + tilt * Vector3(0, sin(a1) * r, cos(a1) * r)
				g.cyl(p0, p1, 0.012, 3, P.WIRE)
		g.tag = ""
	g.tier = 1
	g.tag = "keep"
	for x: float in [-3.6, 0.0, 3.6]:
		g.cyl(Vector3(x, 0, -0.9), Vector3(x, 1.5, -0.9), 0.035, 4, P.IRON_RUST)
		g.cyl(Vector3(x, 0, 0.9), Vector3(x, 1.5, 0.9), 0.035, 4, P.IRON_RUST)
	g.tag = ""
	b.marks["blocks"] = true


## Hedgehogs, 1x1 tile: steel beam crosses (three beams through one point) set in a staggered row.
static func hedgehogs(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.02, 0), Vector3(4.0, 0.02, 3.0), P.EARTH)
	g.tier = 1
	for k in 5:
		var c := Vector3(-3.0 + float(k) * 1.5, 0.75, -1.2 if k % 2 == 0 else 1.0)
		var yaw := BGeo._h(k, 4) * PI
		var bb := Basis(Vector3.UP, yaw)
		_far(g, c, Vector3(0.6, 0.7, 0.6), P.STEEL.darkened(0.3), bb)
		for axis in 3:
			var d := [Vector3(1, 1, 0), Vector3(-1, 1, 0.6), Vector3(0, 1, -1)][axis] as Vector3
			d = bb * d.normalized()
			g.box(c, Vector3(0.09, 0.09, 1.05), P.STEEL.darkened(0.2), Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT))
	b.marks["blocks_vehicles"] = true


## Concrete teeth, 1x1 tile: two staggered rows of stepped concrete pyramids.
static func teeth(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.02, 0), Vector3(4.0, 0.02, 2.4), P.EARTH)
	g.tier = 1
	for r in 2:
		for k in 5:
			var x := -3.4 + float(k) * 1.7 + float(r) * 0.85
			if x > 3.6:
				continue
			var c := Vector3(x, 0, -1.0 + float(r) * 2.0)
			var col := P.CONCRETE.darkened(BGeo._h(k + r * 5, 2) * 0.15)
			g.box(c + Vector3(0, 0.35, 0), Vector3(0.6, 0.35, 0.6), col)
			_far(g, c + Vector3(0, 0.7, 0), Vector3(0.5, 0.7, 0.5), col)
			g.box(c + Vector3(0, 0.95, 0), Vector3(0.42, 0.25, 0.42), col)
			g.box(c + Vector3(0, 1.38, 0), Vector3(0.22, 0.18, 0.22), col)
	b.marks["blocks_vehicles"] = true


## An MG nest, 1x1 tile: a horseshoe of sandbags open at the back, the heavy MG on its tripod at the
## front, ammunition boxes, a dugout entry and the two-man team at the gun (gunner on the grips, loader
## feeding the belt).
static func mg_nest(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.02, 0), Vector3(3.6, 0.02, 3.6), P.EARTH)
	g.lump(Vector3(0, -0.05, 0.2), 1.0, P.EARTH_DARK, Vector3(2.4, 0.1, 2.2))
	g.tier = 1
	var pts: Array[Vector3] = []
	for k in 8:
		var a := lerpf(-PI * 0.75, PI * 0.75, float(k) / 7.0)
		pts.append(Vector3(sin(a) * 2.4, 0, -cos(a) * 2.4 + 0.4))
	for k in 7:
		P.sandbags(g, pts[k], pts[k + 1], 3, 2)
	# the firing platform the team stands on
	g.box(Vector3(0, 0.2, -0.55), Vector3(1.3, 0.2, 1.1), P.EARTH_DARK)
	g.tier = 3
	g.box(Vector3(0, 0.42, -0.55), Vector3(1.2, 0.03, 1.0), P.PLANK)
	g.tier = 1
	_far_ring(g, pts)
	_far(g, Vector3(0, 0.5, -1.1), Vector3(0.3, 0.3, 0.6), MG.STEEL)
	g.tier = 3
	g.box(Vector3(0, 0.88, -1.95), Vector3(1.0, 0.05, 0.3), P.PLANK)   # the gun's sill board
	for k in 3:
		g.box(Vector3(-1.4 + float(k) * 0.42, 0.18, 0.9), Vector3(0.17, 0.18, 0.3), MG.BOX)
	g.box(Vector3(1.6, 0.35, 1.9), Vector3(0.7, 0.35, 0.5), P.TIMBER_DARK)
	g.box(Vector3(1.6, 0.36, 1.38), Vector3(0.45, 0.32, 0.02), P.BLACK)
	g.tier = 1
	# the gun, set up at the front sill, aiming north (-Z)
	var at := Vector3(0, 0.45, -1.0)
	var mg := MG.set_up(false)
	mg.position = at
	b.part("MG", Vector3.ZERO).add_child(mg)
	var box := MeshInstance3D.new()
	box.mesh = MG.mesh(MG.ammo_box(true))
	box.position = at + CM_FEED_BOX
	b.parts.add_child(box)
	var gx := Transform3D(Basis(), at + Vector3(0, MG.PIN_H, 0))
	var crew: Array = []
	crew.append(b.add_man(at + Vector3(0, 0, 0.80), 0.0, CM.gunner(0.0), 2,
		{"hand_r": gx * MG.GRIP_R, "hand_l": gx * MG.GRIP_L}, "gunner"))
	var box_top := at + CM_FEED_BOX + Vector3(0, 0.2, 0)
	crew.append(b.add_man(at + Vector3(0.55, 0, 0.30), PI / 2, CM.loader(), 7,
		{"hand_l": gx * MG.FEED + Vector3(0.06, -0.03, 0), "hand_r": box_top + Vector3(0, 0.05, 0)}, "loader"))
	b.set_meta("crew", crew)
	b.marks["gun"] = at
	b.marks["entry"] = Vector3(0, 0, 3.0)
	b.marks["fire_dir"] = Vector3(0, 0, -1)


const CM_FEED_BOX := Vector3(0.66, 0, -0.18)   # the open ammunition box beside the feed (as the MG team clips)


## A gun pit, 2x2 tiles: a shallow round pit with a sandbag parapet open at the back, the light field gun in
## it aiming north, shell racks and cartridge boxes, a camouflage net on poles over the back half, and the
## crew at their posts (layer and breech man on the axle seats, loader and two ammunition numbers kneeling,
## the NCO at the side).
static func gun_pit(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.02, 0), Vector3(7.6, 0.02, 7.6), P.EARTH)
	g.lump(Vector3(0, -0.05, 0.6), 1.0, P.EARTH_DARK, Vector3(5.2, 0.1, 5.4))
	g.tier = 1
	var pts: Array[Vector3] = []
	for k in 12:
		var a := lerpf(-PI * 0.78, PI * 0.78, float(k) / 11.0)
		pts.append(Vector3(sin(a) * 5.4, 0, -cos(a) * 5.4 + 0.6))
	for k in 11:
		P.sandbags(g, pts[k], pts[k + 1], 4, 2)
	_far_ring(g, pts)
	_far(g, Vector3(0, 0.8, 0.4), Vector3(0.9, 0.8, 1.8), GB.PAINT)
	# shell racks and boxes
	g.tier = 3
	for k in 2:
		var r := Vector3(3.0 + float(k) * 0.9, 0, 3.2)
		g.box(r + Vector3(0, 0.45, 0), Vector3(0.4, 0.45, 0.3), P.TIMBER)
		for j in 6:
			g.cyl(r + Vector3(-0.3 + float(j % 3) * 0.3, 0.3 + float(j / 3) * 0.4, -0.3),
				r + Vector3(-0.3 + float(j % 3) * 0.3, 0.3 + float(j / 3) * 0.4, -0.05), 0.05, 6, MG.BRASS)
	for k in 4:
		g.box(Vector3(-3.6 + float(k) * 0.55, 0.2, 3.4), Vector3(0.24, 0.2, 0.4), GB.PAINT_DARK)
	# the net: four poles, a sagging dark green sheet with lumps of scrim
	var net := [Vector3(-4.0, 0, 1.8), Vector3(4.0, 0, 1.8), Vector3(4.0, 0, 5.6), Vector3(-4.0, 0, 5.6)]
	g.tier = 1
	for p: Vector3 in net:
		g.cyl(p, p + Vector3(0, 2.6, 0), 0.06, 4, P.TIMBER)
	g.tier = 2
	var nc := Color(0.27, 0.32, 0.2)
	g.quad(net[0] + Vector3(0, 2.6, 0), net[1] + Vector3(0, 2.6, 0), Vector3(4.0, 2.2, 3.7), Vector3(-4.0, 2.2, 3.7), nc,
		Vector3(0, -10, 0))
	g.quad(Vector3(-4.0, 2.2, 3.7), Vector3(4.0, 2.2, 3.7), net[2] + Vector3(0, 2.6, 0), net[3] + Vector3(0, 2.6, 0), nc,
		Vector3(0, -10, 0))
	g.tier = 3
	g.tag = "detail"
	for k in 10:
		g.lump(Vector3(-3.5 + BGeo._h(k, 1) * 7.0, 2.35, 2.2 + BGeo._h(k, 2) * 3.2), 0.35, nc.darkened(0.15),
			Vector3(1.4, 0.3, 1.0))
	g.tag = ""
	g.tier = 1
	# the gun, the trail back, aiming north (-Z)
	var gun := FieldGun.new().setup()
	gun.position = Vector3(0, 0, -0.4)
	b.part("Gun", Vector3.ZERO).add_child(gun)
	var seat := func(s: float) -> Vector3:
		var sp: Vector3 = GB.SEAT_R if s > 0.0 else GB.SEAT_L
		return gun.position + Vector3(sp.x, GB.WHEEL_R + sp.y - GC.SIT_H, sp.z + 0.02)
	var crew: Array = []
	crew.append(b.add_man(seat.call(-1.0), 0.0, GC.layer(), 201, func() -> Dictionary:
		return {"hand_r": gun.handwheel.global_transform * Vector3(-0.06, 0.1, 0.0),
			"hand_l": gun.cradle.global_transform * Vector3(-0.27, 0.27, 0.06)}))
	crew.append(b.add_man(seat.call(1.0), 0.0, GC.breech_man(), 202, func() -> Dictionary:
		return {"hand_l": gun.barrel.global_transform * Vector3(0.2, GB.BORE_Y - 0.1, 0.55),
			"hand_r": gun.carriage.global_transform * Vector3(0.5, 0.12, 0.25)}))
	crew.append(b.add_man(gun.position + Vector3(0.58, 0, 1.45), 0.45, GC.kneel(8.0), 203))
	crew.append(b.add_man(gun.position + Vector3(1.3, 0, 2.35), 0.55, GC.kneel(8.0), 204))
	crew.append(b.add_man(gun.position + Vector3(1.75, 0, 1.4), 1.25, GC.kneel(8.0), 205))
	crew.append(b.add_man(gun.position + Vector3(-1.55, 0, 0.7), -0.25, GC.nco_order(1.0).merged({"hand_r": null}, true), 206))
	b.set_meta("crew", crew)
	b.marks["gun"] = gun.position
	b.marks["entry"] = Vector3(0, 0, 6.6)
	b.marks["fire_dir"] = Vector3(0, 0, -1)
