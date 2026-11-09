class_name BldWalls
extends RefCounted
## Iron Front walls and gates (Asset Builder Chat). One concrete wall type, dragged out on the 8 m grid.
## Each wall cell is a Building (kind "wall") of one tile, built from the cell's connection mask:
##   N = 1 (-Z), E = 2 (+X), S = 4 (+Z), W = 8 (-X)
## so straight, corner, T, cross and end pieces all come from the same code and join up as you drag.
## Variants on a cell: "" plain, "tower", "bastion", "gate" (road gate, straight cells only), "rail_gate"
## (placed by solve() wherever a track crosses a straight wall, whichever was built second).
## foot: how far the footing runs down below the cell (for walls on a cliff edge, the cliff height).
##
## The wall: 2.6 m walkway on top of a 3.4 m body, parapets both sides to 4.6 m with firing gaps and a
## firing step behind each, a lamp on every cell. Towers are 9 m with a searchlight; bastions are low wide
## gun platforms with a searchlight and sandbagged MG.

const P := preload("res://scripts/buildings/bld_parts.gd")
const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := {1: Vector3(0, 0, -1), 2: Vector3(1, 0, 0), 4: Vector3(0, 0, 1), 8: Vector3(-1, 0, 0)}
const DIR_CELL := {1: Vector2i(0, -1), 2: Vector2i(1, 0), 4: Vector2i(0, 1), 8: Vector2i(-1, 0)}

const BODY_H := 3.4
const TOP_H := 4.6
const HALF_W := 1.3
const PAR := 0.32
const HALF := 4.0
## A basis whose x/y plane is the ground (x, z), extruding upward: for outlines drawn on the ground.
const HB := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))


static func make(mask: int, variant := "", foot := 0.0) -> Building:
	var b := Building.new()
	b.kind = "wall"
	b.name = "Wall_%d_%s" % [mask, variant]
	b.tiles = Vector2i.ONE
	b.set_meta("mask", mask)
	b.set_meta("variant", variant)
	match variant:
		"tower":
			_arms(b, mask, foot)
			_tower(b, foot)
		"bastion":
			_arms(b, mask, foot)
			_bastion(b, foot)
		"gate":
			_gate(b, mask, foot)
		"rail_gate":
			_rail_gate(b, mask, foot)
		_:
			_arms(b, mask, foot)
			_hub(b, mask)
	b.finish()
	return b


## Picks each cell's piece. walls: Dictionary of Vector2i -> true; tracks: Vector2i -> track mask (bits as
## above; a track running north-south through a cell is N | S); gates: Vector2i -> "gate"/"tower"/"bastion"
## chosen by the player. Returns Vector2i -> [mask, variant].
## A track crossing a straight wall at right angles gets a rail gate on its own. A track crossing a corner,
## T or cross can't have a gate: those cells come back with the variant "blocked" so the game can refuse it.
static func solve(walls: Dictionary, tracks := {}, chosen := {}) -> Dictionary:
	var out := {}
	for c: Vector2i in walls:
		var m := 0
		for d: int in DIR_CELL:
			if walls.has(c + (DIR_CELL[d] as Vector2i)):
				m |= d
		var v: String = chosen.get(c, "")
		if tracks.has(c):
			var tm: int = tracks[c]
			var straight_ns := m == (N | S) or m == N or m == S
			var straight_ew := m == (E | W) or m == E or m == W
			if (straight_ns and tm == (E | W)) or (straight_ew and tm == (N | S)):
				v = "rail_gate"
				m = (N | S) if straight_ns else (E | W)
			else:
				v = "blocked"
		elif v == "gate" and m != (N | S) and m != (E | W):
			v = ""
		out[c] = [m, v]
	return out


# ------------------------------------------------------------------ the wall

## The wall run along one arm, from the hub edge (at r0 from the centre) to the cell edge.
static func _run(b: Building, d: Vector3, r0: float, r1: float, foot: float, loops := true) -> void:
	var g := b.g
	var side := Vector3(-d.z, 0, d.x)
	var mid := d * ((r0 + r1) * 0.5)
	var hl := (r1 - r0) * 0.5
	var along := Vector3(absf(d.x), 0, absf(d.z))
	var across := Vector3(absf(side.x), 0, absf(side.z))
	if foot > 0.0:
		g.tier = 0
		g.box(mid + Vector3(0, -foot * 0.5, 0), along * hl + across * (HALF_W + 0.25) + Vector3(0, foot * 0.5 + 0.02, 0), P.CONCRETE_DARK)
	g.tier = 0
	g.box(mid + Vector3(0, 0.3, 0), along * hl + across * (HALF_W + 0.25) + Vector3(0, 0.3, 0), P.CONCRETE_DARK)
	g.tier = 1
	g.box(mid + Vector3(0, BODY_H * 0.5, 0), along * hl + across * HALF_W + Vector3(0, BODY_H * 0.5, 0), P.CONCRETE)
	# parapets with firing gaps, and a firing step behind each
	for s: float in [-1.0, 1.0]:
		var pc := mid + side * (s * (HALF_W - PAR * 0.5))
		g.box(pc + Vector3(0, BODY_H + 0.4, 0), along * hl + across * (PAR * 0.5) + Vector3(0, 0.4, 0), P.CONCRETE)
		if loops:
			var n := maxi(1, int(hl * 2.0 / 1.6))
			for k in n:
				var u := (float(k) + 0.5) / float(n) - 0.5
				var a := pc + d * (u * hl * 2.0)
				g.box(a + Vector3(0, BODY_H + 0.8 + 0.2, 0), along * 0.5 + across * (PAR * 0.5) + Vector3(0, 0.2, 0), P.CONCRETE)
		else:
			g.box(pc + Vector3(0, BODY_H + 1.0, 0), along * hl + across * (PAR * 0.5) + Vector3(0, 0.2, 0), P.CONCRETE)
		g.tier = 3
		g.tag = "detail"
		g.box(mid + side * (s * (HALF_W - PAR - 0.3)) + Vector3(0, BODY_H + 0.17, 0), along * hl + across * 0.3 + Vector3(0, 0.17, 0), P.CONCRETE_DARK)
		g.tag = ""
		g.tier = 1
	# panel joints down both faces and a dark base band
	g.tier = 3
	g.tag = "detail"
	var nj := int(hl * 2.0 / 2.0)
	for k in nj + 1:
		var a := mid + d * (-hl + float(k) * hl * 2.0 / float(maxi(1, nj)))
		for s: float in [-1.0, 1.0]:
			g.box(a + side * (s * (HALF_W + 0.01)) + Vector3(0, BODY_H * 0.5, 0), along * 0.03 + across * 0.02 + Vector3(0, BODY_H * 0.5, 0), P.CONCRETE_DARK)
	for s: float in [-1.0, 1.0]:
		g.box(mid + side * (s * (HALF_W + 0.015)) + Vector3(0, 0.9, 0), along * hl + across * 0.02 + Vector3(0, 0.3, 0), P.CONCRETE_DARK.darkened(0.1))
	g.tag = ""
	g.tier = 1


static func _arms(b: Building, mask: int, foot: float) -> void:
	for d: int in DIRS:
		if mask & d:
			_run(b, DIRS[d], HALF_W, HALF, foot)
	# the hub under every piece (and the footing under it)
	var g := b.g
	if foot > 0.0:
		g.tier = 0
		g.box(Vector3(0, -foot * 0.5, 0), Vector3(HALF_W + 0.25, foot * 0.5 + 0.02, HALF_W + 0.25), P.CONCRETE_DARK)
	g.tier = 0
	g.box(Vector3(0, 0.3, 0), Vector3(HALF_W + 0.25, 0.3, HALF_W + 0.25), P.CONCRETE_DARK)
	b.marks["walkway"] = Vector3(0, BODY_H, 0)


## The hub of a plain piece: a pillar where arms meet, an end buttress on an end, a lamp on every cell.
static func _hub(b: Building, mask: int) -> void:
	var g := b.g
	var n_arms := 0
	for d: int in DIRS:
		if mask & d:
			n_arms += 1
	g.tier = 1
	var straight := mask == (N | S) or mask == (E | W)
	if straight:
		g.box(Vector3(0, BODY_H * 0.5, 0), Vector3(HALF_W, BODY_H * 0.5, HALF_W), P.CONCRETE)
		for s: float in [-1.0, 1.0]:
			var side := Vector3(1, 0, 0) if mask == (N | S) else Vector3(0, 0, 1)
			var along := Vector3(0, 0, 1) if mask == (N | S) else Vector3(1, 0, 0)
			g.box(side * (s * (HALF_W - PAR * 0.5)) + Vector3(0, BODY_H + 0.6, 0), along * HALF_W + side.abs() * (PAR * 0.5) + Vector3(0, 0.6, 0), P.CONCRETE)
	else:
		# a pillar a little taller than the wall where it turns, ends or branches
		g.box(Vector3(0, (TOP_H + 0.4) * 0.5, 0), Vector3(HALF_W + 0.2, (TOP_H + 0.4) * 0.5, HALF_W + 0.2), P.CONCRETE)
		g.box(Vector3(0, TOP_H + 0.5, 0), Vector3(HALF_W + 0.3, 0.12, HALF_W + 0.3), P.CONCRETE_DARK)
		if n_arms <= 1:
			# an end: a sloped buttress on the open side
			for d: int in DIRS:
				if not (mask & d):
					var v: Vector3 = DIRS[d]
					if n_arms == 1 and (mask & _opp(d)):
						g.box(v * (HALF_W + 0.6) + Vector3(0, 1.4, 0), Vector3(absf(v.x), 0, absf(v.z)) * 0.6 + Vector3(absf(v.z), 0, absf(v.x)) * (HALF_W - 0.2) + Vector3(0, 1.4, 0), P.CONCRETE_DARK)
	P.lamp(b, Vector3(0.0, TOP_H + 0.9 + (0.4 if not straight else 0.0), 0.0), 0.0, 11.0)
	if straight:
		b.g.tier = 3
		b.g.cyl(Vector3(0, BODY_H, 0), Vector3(0, TOP_H + 0.9, 0), 0.06, 5, P.METAL)
		b.g.tier = 1


static func _opp(d: int) -> int:
	return {1: 4, 2: 8, 4: 1, 8: 2}[d]


# ------------------------------------------------------------------ towers and bastions

static func _tower(b: Building, foot: float) -> void:
	var g := b.g
	var h := 9.0
	var hw := 2.3
	if foot > 0.0:
		g.tier = 0
		g.box(Vector3(0, -foot * 0.5, 0), Vector3(hw + 0.3, foot * 0.5, hw + 0.3), P.CONCRETE_DARK)
	g.tier = 0
	g.box(Vector3(0, 0.3, 0), Vector3(hw + 0.3, 0.3, hw + 0.3), P.CONCRETE_DARK)
	g.tier = 1
	g.box(Vector3(0, h * 0.5, 0), Vector3(hw, h * 0.5, hw), P.CONCRETE)
	g.box(Vector3(0, h + 0.15, 0), Vector3(hw + 0.35, 0.15, hw + 0.35), P.CONCRETE_DARK)
	# the fighting top: parapet with gaps on all four sides
	for d: int in DIRS:
		var v: Vector3 = DIRS[d]
		var sd := Vector3(absf(v.z), 0, absf(v.x))
		for k in 3:
			var u := (float(k) - 1.0) * 1.7
			g.box(v * (hw + 0.2) + sd * u + Vector3(0, h + 0.85, 0), sd * 0.55 + Vector3(absf(v.x), 0, absf(v.z)) * 0.15 + Vector3(0, 0.55, 0), P.CONCRETE)
		g.box(v * (hw + 0.2) + Vector3(0, h + 0.45, 0), sd * (hw + 0.35) + Vector3(absf(v.x), 0, absf(v.z)) * 0.15 + Vector3(0, 0.15, 0), P.CONCRETE)
		# MG slits on the two floors below
		g.tier = 3
		g.tag = "glow"
		for y in [3.0, 6.3]:
			g.box(v * (hw + 0.01) + Vector3(0, y, 0), sd * 0.6 + Vector3(absf(v.x), 0, absf(v.z)) * 0.03 + Vector3(0, 0.12, 0), P.WINDOW)
		g.tag = ""
		g.tier = 1
	# a steel door at the foot and a ladder hatch on top
	P.door(g, Vector3(0, 0.6, hw + 0.01), Vector3(0, 0, 1), 1.0, 2.0, P.STEEL)
	g.tier = 3
	g.box(Vector3(1.2, h + 0.35, 1.2), Vector3(0.5, 0.05, 0.5), P.STEEL)
	g.tier = 1
	var head := b.searchlight(Vector3(0, h + 1.4, 0))
	b.g.tier = 3
	b.g.cyl(Vector3(0, h + 0.3, 0), Vector3(0, h + 1.0, 0), 0.12, 6, P.METAL)
	b.g.tier = 1
	head.rotation.y = 0.6
	P.lamp(b, Vector3(0, 2.9, hw + 0.4), 0.0, 8.0)
	b.marks["top"] = Vector3(0, h + 0.3, 0)
	b.marks["door"] = Vector3(0, 0, hw + 1.0)


static func _bastion(b: Building, foot: float) -> void:
	var g := b.g
	var r := 3.9
	var oct := PackedVector2Array()
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		oct.append(Vector2(cos(a), sin(a)) * r / cos(PI / 8.0))
	if foot > 0.0:
		g.tier = 0
		g.extrude(oct, Vector3(0, -foot, 0), Vector3(0, 0.0, 0), P.CONCRETE_DARK, HB)
	g.tier = 1
	# battered (sloped) sides: a wider base ring up to a narrower top
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for o in oct:
		lo.append(Vector3(o.x * 1.08, 0.0, o.y * 1.08))
		hi.append(Vector3(o.x * 0.94, BODY_H + 0.6, o.y * 0.94))
	var rings: Array = [lo, hi]
	g.ops.append({"t": "prism", "rings": rings, "col": P.CONCRETE, "tier": 1, "tag": "", "c": Vector3(0, BODY_H * 0.5, 0)})
	# low parapet round the gun platform, gaps toward the outside
	for k in 8:
		var a0 := TAU * float(k) / 8.0
		var p := Vector3(cos(a0), 0, sin(a0)) * (r * 0.9)
		g.box(p + Vector3(0, BODY_H + 1.1, 0), Vector3(1.1, 0.5, 0.18), P.CONCRETE, Basis(Vector3.UP, -a0 + PI * 0.5))
	# a sandbagged MG and a searchlight on its post
	P.sandbags(g, Vector3(-1.2, BODY_H + 0.6, -1.4), Vector3(1.2, BODY_H + 0.6, -1.4), 2, 1)
	var mg := MG_.set_up(true)
	var holder := b.part("MG", Vector3(0, BODY_H + 0.6, -0.9))
	holder.add_child(mg)
	var head := b.searchlight(Vector3(1.8, BODY_H + 2.7, 1.6))
	head.rotation.y = 2.4
	g.tier = 3
	g.cyl(Vector3(1.8, BODY_H + 0.6, 1.6), Vector3(1.8, BODY_H + 2.2, 1.6), 0.1, 6, P.METAL)
	g.tier = 1
	P.lamp(b, Vector3(-2.0, BODY_H + 1.9, 1.8), 1.2, 10.0)
	b.marks["platform"] = Vector3(0, BODY_H + 0.6, 0)

const MG_ := preload("res://scripts/units/mg_builder.gd")


# ------------------------------------------------------------------ gates

## A road gate on a straight cell: the wall bridges a 4.6 m opening; two plated leaves swing inward (+side).
static func _gate(b: Building, mask: int, foot: float) -> void:
	var ns := mask == (N | S)
	var d := Vector3(0, 0, 1) if ns else Vector3(1, 0, 0)
	var side := Vector3(1, 0, 0) if ns else Vector3(0, 0, 1)
	# the two wall stubs either side of the opening, and the bridge over it
	for s: float in [-1.0, 1.0]:
		_run(b, d * s, 2.6, HALF, foot)
	var g := b.g
	g.tier = 1
	for s: float in [-1.0, 1.0]:
		g.box(d * (s * 2.55) + Vector3(0, (TOP_H + 0.8) * 0.5, 0), d.abs() * 0.3 + side.abs() * (HALF_W + 0.25) + Vector3(0, (TOP_H + 0.8) * 0.5, 0), P.CONCRETE)
		g.box(d * (s * 2.55) + Vector3(0, TOP_H + 0.9, 0), d.abs() * 0.4 + side.abs() * (HALF_W + 0.35) + Vector3(0, 0.1, 0), P.CONCRETE_DARK)
	g.box(Vector3(0, BODY_H + 0.05, 0), d.abs() * 2.3 + side.abs() * HALF_W + Vector3(0, 0.35, 0), P.CONCRETE)
	for s: float in [-1.0, 1.0]:
		g.box(side * (s * (HALF_W - PAR * 0.5)) + Vector3(0, BODY_H + 0.8, 0), d.abs() * 2.3 + side.abs() * (PAR * 0.5) + Vector3(0, 0.4, 0), P.CONCRETE)
	g.tier = 0
	g.box(Vector3(0, 0.04, 0), d.abs() * 2.3 + side.abs() * 4.0 + Vector3(0, 0.04, 0), P.GRAVEL)
	# the leaves: hinged at each post, closing across the opening
	var leaves: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		var lg := TrainGeo.new()
		var w := 2.2
		lg.box(d * (-s * w * 0.5) + Vector3(0, 1.6, 0), d.abs() * (w * 0.5) + side.abs() * 0.08 + Vector3(0, 1.5, 0), P.TIMBER)
		for y in [0.5, 1.6, 2.7]:
			lg.box(d * (-s * w * 0.5) + side * 0.1 + Vector3(0, y, 0), d.abs() * (w * 0.5) + side.abs() * 0.03 + Vector3(0, 0.12, 0), P.STEEL)
		lg.box(d * (-s * w * 0.5) + side * 0.1 + Vector3(0, 1.6, 0), d.abs() * 0.08 + side.abs() * 0.03 + Vector3(0, 1.4, 0), P.STEEL)
		var leaf := b.part_mesh("Leaf%d" % int(s + 1.0), d * (s * 2.3) + side * (HALF_W * 0.3), lg)
		leaves.append(leaf)
	b.set_meta("leaves", leaves)
	b.set_meta("gate_axis", 1.0 if ns else -1.0)
	for s: float in [-1.0, 1.0]:
		P.lamp(b, d * (s * 2.55) + side * (HALF_W + 0.5) + Vector3(0, 3.6, 0), 0.0, 10.0)
		P.lamp(b, d * (s * 2.55) - side * (HALF_W + 0.5) + Vector3(0, 3.6, 0), 0.0, 10.0)
	b.marks["through_a"] = side * -6.0
	b.marks["through_b"] = side * 6.0
	set_gate(b, 0.0)


## The rail gate on a straight cell: a gatehouse with taller posts carries the walkway over a 5.6 m opening
## for the track; two heavy plated doors slide sideways into pockets along the wall. It opens as a train
## comes (update_rail_gate) and shuts behind it. A red warning lamp lights while the doors move.
static func _rail_gate(b: Building, mask: int, foot: float) -> void:
	var ns := mask == (N | S)
	var d := Vector3(0, 0, 1) if ns else Vector3(1, 0, 0)       # along the wall
	var side := Vector3(1, 0, 0) if ns else Vector3(0, 0, 1)    # along the track
	var g := b.g
	for s: float in [-1.0, 1.0]:
		_run(b, d * s, 3.2, HALF, foot, false)
	g.tier = 1
	var gh := 7.0
	for s: float in [-1.0, 1.0]:
		g.box(d * (s * 3.2) + Vector3(0, gh * 0.5, 0), d.abs() * 0.45 + side.abs() * (HALF_W + 0.5) + Vector3(0, gh * 0.5, 0), P.CONCRETE)
		g.box(d * (s * 3.2) + Vector3(0, gh + 0.12, 0), d.abs() * 0.6 + side.abs() * (HALF_W + 0.6) + Vector3(0, 0.12, 0), P.CONCRETE_DARK)
	# the head beam and the walkway bridge across the top
	g.box(Vector3(0, 6.1, 0), d.abs() * 2.8 + side.abs() * (HALF_W + 0.2) + Vector3(0, 0.5, 0), P.CONCRETE)
	for s: float in [-1.0, 1.0]:
		g.box(side * (s * (HALF_W + 0.1)) + Vector3(0, 6.95, 0), d.abs() * 2.8 + side.abs() * 0.15 + Vector3(0, 0.35, 0), P.CONCRETE)
	g.tier = 3
	g.tag = "detail"
	# hazard stripes on the head beam
	for k in 6:
		var u := (float(k) - 2.5) * 0.95
		for s: float in [-1.0, 1.0]:
			g.box(d * u + side * (s * (HALF_W + 0.22)) + Vector3(0, 5.85, 0), d.abs() * 0.24 + side.abs() * 0.02 + Vector3(0, 0.22, 0),
				Color(0.85, 0.7, 0.15) if k % 2 == 0 else P.BLACK, Basis(side, 0.0))
	g.tag = ""
	# the track through it
	BldParts.track(g, side * -4.0, side * 4.0)
	# the doors: steel plated, sliding along the wall into pockets behind the posts
	var doors: Array[Node3D] = []
	for s: float in [-1.0, 1.0]:
		var dg := TrainGeo.new()
		dg.box(Vector3(0, 2.7, 0), d.abs() * 1.42 + side.abs() * 0.12 + Vector3(0, 2.6, 0), P.OLIVE.darkened(0.2))
		for y in [0.6, 2.0, 3.4, 4.8]:
			dg.box(side * 0.13 + Vector3(0, y, 0), d.abs() * 1.42 + side.abs() * 0.03 + Vector3(0, 0.08, 0), P.STEEL)
			dg.box(side * -0.13 + Vector3(0, y, 0), d.abs() * 1.42 + side.abs() * 0.03 + Vector3(0, 0.08, 0), P.STEEL)
		for k in 5:
			var u := (float(k) - 2.0) * 0.6
			dg.box(d * u + side * 0.14 + Vector3(0, 2.7, 0), d.abs() * 0.05 + side.abs() * 0.02 + Vector3(0, 2.5, 0), P.STEEL)
		dg.cyl(d * -0.9 + Vector3(0, 5.35, 0), d * 0.9 + Vector3(0, 5.35, 0), 0.08, 6, P.METAL)   # top rollers
		var door := b.part_mesh("Door%d" % int(s + 1.0), d * (s * 1.4) + side * (HALF_W - 0.25), dg)
		doors.append(door)
	b.set_meta("doors", doors)
	b.set_meta("door_axis", d)
	# a warning lamp on each side (red, part of the lights switch) and work lamps
	g.tier = 3
	g.tag = "glow"
	for s: float in [-1.0, 1.0]:
		g.box(d * 3.2 + side * (s * (HALF_W + 0.55)) + Vector3(0, 6.3, 0), Vector3(0.18, 0.18, 0.18), Color(0.7, 0.12, 0.08))
	g.tag = ""
	g.tier = 1
	for s: float in [-1.0, 1.0]:
		P.lamp(b, d * (-3.2) + side * (s * (HALF_W + 0.7)) + Vector3(0, 5.0, 0), 0.0, 12.0)
	b.marks["track_a"] = side * -6.0
	b.marks["track_b"] = side * 6.0
	set_rail_gate(b, 0.0)


## Road gate: 0 shut, 1 open (the leaves swing to the +side).
static func set_gate(b: Building, u: float) -> void:
	var leaves: Array = b.get_meta("leaves", [])
	var ax: float = b.get_meta("gate_axis", 1.0)
	for i in leaves.size():
		var s := -1.0 if i == 0 else 1.0
		(leaves[i] as Node3D).rotation.y = s * ax * u * 1.45


## Rail gate: 0 shut, 1 open (each door slides 2.9 m into its pocket).
static func set_rail_gate(b: Building, u: float) -> void:
	var doors: Array = b.get_meta("doors", [])
	var d: Vector3 = b.get_meta("door_axis", Vector3(0, 0, 1))
	for i in doors.size():
		var s := -1.0 if i == 0 else 1.0
		var n: Node3D = doors[i]
		var p := n.position
		var along := d * (s * (1.4 + 2.9 * clampf(u, 0.0, 1.0)))
		n.position = Vector3(along.x if d.x != 0.0 else p.x, p.y, along.z if d.z != 0.0 else p.z)
	b.set_meta("open", u)


## Game hook: call every frame with the distance (m) of the nearest train on this gate's track (INF if
## none). Opens when a train is within 120 m, at 0.35 per second, and shuts once it has gone 40 m past.
static func update_rail_gate(b: Building, train_dist: float, dt: float) -> void:
	var u: float = b.get_meta("open", 0.0)
	var want := 1.0 if train_dist < 120.0 else 0.0
	set_rail_gate(b, move_toward(u, want, 0.35 * dt))
