class_name BldRail
extends RefCounted
## Iron Front rail buildings (Asset Builder Chat): halt, station, engine shed, water tower, coal stage and
## signal box. Tracks inside a building's tile run along x unless said; marks "rail" give the track centre.

const P := preload("res://scripts/buildings/bld_parts.gd")


static func _platform(g: BGeo, c: Vector3, hx: float, hz: float) -> void:
	g.tier = 0
	g.box(c + Vector3(0, 0.45, 0), Vector3(hx, 0.45, hz), P.CONCRETE)
	g.box(c + Vector3(0, 0.92, hz - 0.2), Vector3(hx, 0.03, 0.2), P.WHITE)          # the white edge line
	g.tier = 1


static func _bench(g: BGeo, at: Vector3, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	g.tier = 3
	g.tag = "detail"
	g.box(at + b * Vector3(0, 0.45, 0), Vector3(0.9, 0.04, 0.22), P.TIMBER, b)
	g.box(at + b * Vector3(0, 0.75, 0.2), Vector3(0.9, 0.2, 0.03), P.TIMBER, b)
	for s: float in [-1.0, 1.0]:
		g.box(at + b * Vector3(s * 0.75, 0.22, 0.05), Vector3(0.04, 0.22, 0.2), P.METAL, b)
	g.tag = ""
	g.tier = 1


static func _nameboard(g: BGeo, at: Vector3) -> void:
	g.tier = 3
	g.box(at + Vector3(0, 2.0, 0), Vector3(1.4, 0.32, 0.05), P.CREAM)
	g.box(at + Vector3(0, 2.0, -0.01), Vector3(1.5, 0.38, 0.04), P.BLACK)
	for s: float in [-1.0, 1.0]:
		g.cyl(at + Vector3(s * 1.2, 0, 0), at + Vector3(s * 1.2, 2.3, 0), 0.05, 5, P.METAL)
	g.tier = 1


## A halt, 2x1 tiles: a short platform, a timber shelter, a name board, two lamps and a bench.
static func halt(b: Building) -> void:
	var g := b.g
	P.track(g, Vector3(-8, 0, 2.4), Vector3(8, 0, 2.4))
	_platform(g, Vector3(0, 0, -0.6), 7.0, 1.6)
	g.tag = "keep"
	g.tier = 1
	g.box(Vector3(-2.0, 0.9 + 1.25, -1.9), Vector3(1.8, 1.25, 0.08), P.PLANK)
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(-2.0 + s * 1.8, 0.9 + 1.25, -1.2), Vector3(0.08, 1.25, 0.7), P.PLANK)
	g.tag = ""
	g.tier = 2
	g.box(Vector3(-2.0, 3.45, -1.0), Vector3(2.1, 0.06, 1.2), P.IRON, Basis(Vector3.RIGHT, -0.12))
	_bench(g, Vector3(-2.0, 0.9, -1.4))
	_nameboard(g, Vector3(3.2, 0.9, -1.9))
	for x: float in [-5.5, 5.5]:
		P.lamp(b, Vector3(x, 0.9 + 3.2, -1.6), 3.2, 8.0)
	b.marks["rail"] = Vector3(0, 0, 2.4)
	b.marks["platform"] = Vector3(0, 0.9, -0.6)


## A station, 3x2 tiles: a brick booking hall with a tiled roof, a clock and chimneys, a long platform
## under an iron canopy on columns, benches and luggage trolleys, the track along the back.
static func station(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, -7.2), Vector3(11.8, 0.03, 1.6), P.GRAVEL)
	P.track(g, Vector3(-12, 0, 5.4), Vector3(12, 0, 5.4))
	_platform(g, Vector3(0, 0, 2.2), 11.5, 2.2)
	# the hall
	var c := Vector3(0, 0, -2.6)
	P.plinth(g, c, 7.2, 3.2, 0.9, P.STONE_DARK)
	g.tier = 1
	P.block(g, c, 7.0, 3.0, 4.2, P.BRICK, 0.9)
	g.tier = 3
	g.box(c + Vector3(0, 3.0, 0), Vector3(7.05, 0.1, 3.05), P.STONE)
	g.tier = 2
	g.gable(c + Vector3(0, 5.1, 0), 7.0, 3.0, 2.4, P.TILE_RED, 0.5, true, P.BRICK)
	# a front gable with the clock over the door
	g.tier = 1
	g.box(c + Vector3(0, 3.5, -3.25), Vector3(1.9, 2.6, 0.3), P.BRICK)
	g.tier = 2
	g.extrude(PackedVector2Array([Vector2(2.2, 0), Vector2(0, 1.6), Vector2(-2.2, 0)]), c + Vector3(0, 6.1, -3.6), c + Vector3(0, 6.1, -2.9), P.TILE_RED)
	g.tier = 3
	g.cyl(c + Vector3(0, 5.2, -3.56), c + Vector3(0, 5.2, -3.66), 0.6, 12, P.CREAM)
	g.cyl(c + Vector3(0, 5.2, -3.52), c + Vector3(0, 5.2, -3.57), 0.68, 12, P.BLACK)
	g.box(c + Vector3(0, 5.4, -3.68), Vector3(0.04, 0.24, 0.02), P.BLACK)
	g.box(c + Vector3(0.14, 5.2, -3.68), Vector3(0.16, 0.04, 0.02), P.BLACK)
	g.tier = 1
	P.door(g, c + Vector3(0, 0.9, -3.56), Vector3(0, 0, -1), 1.6, 2.5)
	for s: float in [-1.0, 1.0]:
		P.windows(g, c + Vector3(s * 2.6, 2.6, -3.01), c + Vector3(s * 6.4, 2.6, -3.01), Vector3(0, 0, -1), 2, 1.0, 1.5)
		P.windows(g, c + Vector3(s * 1.0, 2.6, 3.01), c + Vector3(s * 6.4, 2.6, 3.01), Vector3(0, 0, 1), 3, 1.0, 1.5)
	b.life.append({"type": "smoke", "at": P.chimney(g, c + Vector3(-4.5, 0, 0.8), 6.0, 8.2)})
	b.life.append({"type": "smoke", "at": P.chimney(g, c + Vector3(4.5, 0, 0.8), 6.0, 8.2)})
	# the canopy: iron columns, a ridged roof with a fretted valance along the track edge
	g.tier = 1
	for k in 6:
		var x := -10.0 + float(k) * 4.0
		g.cyl(Vector3(x, 0.9, 3.4), Vector3(x, 4.4, 3.4), 0.1, 8, P.OLIVE.darkened(0.3))
		g.box(Vector3(x, 4.35, 2.5), Vector3(0.08, 0.1, 1.0), P.OLIVE.darkened(0.3))
	g.tier = 2
	g.box(Vector3(0, 4.6, 2.3), Vector3(11.0, 0.08, 1.8), P.IRON, Basis(Vector3.RIGHT, 0.08))
	g.tier = 3
	g.tag = "detail"
	for k in 44:
		var x := -10.75 + float(k) * 0.5
		g.box(Vector3(x, 4.25, 4.1), Vector3(0.18, 0.2 if k % 2 == 0 else 0.12, 0.02), P.CREAM)
	g.tag = ""
	g.tier = 1
	for x: float in [-7.0, 0.0, 7.0]:
		_bench(g, Vector3(x + 1.5, 0.9, 1.2))
		P.lamp(b, Vector3(x, 4.1, 2.6), 0.0, 9.0)
	# luggage trolleys
	g.tier = 3
	for x: float in [-4.0, 4.6]:
		g.box(Vector3(x, 1.35, 2.0), Vector3(0.9, 0.05, 0.45), P.TIMBER)
		for s: float in [-1.0, 1.0]:
			g.cyl(Vector3(x + s * 0.6, 1.1, 1.5), Vector3(x + s * 0.6, 1.1, 2.5), 0.18, 8, P.METAL)
		g.box(Vector3(x - 0.3, 1.65, 2.0), Vector3(0.4, 0.25, 0.3), P.PLANK)
	g.tier = 1
	_nameboard(g, Vector3(-10.5, 0.9, 1.0))
	b.marks["rail"] = Vector3(0, 0, 5.4)
	b.marks["platform"] = Vector3(0, 0.9, 2.2)
	b.marks["door"] = c + Vector3(0, 0, -4.2)


## An engine shed, 2x3 tiles: a long brick shed over two roads, big open doorways at the front, smoke
## vents along the ridge, the two tracks running out of it along z.
static func engine_shed(b: Building) -> void:
	var g := b.g
	for x: float in [-2.6, 2.6]:
		P.track(g, Vector3(x, 0, -12), Vector3(x, 0, 12))
	g.tier = 0
	g.box(Vector3(0, 0.04, 2.0), Vector3(7.2, 0.04, 9.6), P.CONCRETE_DARK)
	g.tier = 1
	var hz := 9.5
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 7.0, 3.2, 2.0), Vector3(0.35, 3.2, hz), P.BRICK)
		g.tier = 3
		for k in 5:
			g.box(Vector3(s * 7.4, 3.2, -6.0 + float(k) * 4.0), Vector3(0.12, 3.2, 0.4), P.BRICK_DARK)  # pilasters
		g.tier = 1
		P.windows(g, Vector3(s * 7.36, 3.6, -5.5), Vector3(s * 7.36, 3.6, 9.5), Vector3(s, 0, 0), 5, 1.2, 2.2)
	# the back wall and the front with two big doorways
	g.box(Vector3(0, 3.2, 11.3), Vector3(7.3, 3.2, 0.3), P.BRICK)
	for x: float in [-6.4, 0.0, 6.4]:
		g.box(Vector3(x, 3.2, -7.3), Vector3(0.7 if x != 0.0 else 0.45, 3.2, 0.35), P.BRICK)
	g.box(Vector3(0, 5.75, -7.3), Vector3(7.3, 0.65, 0.35), P.BRICK)
	g.tier = 3
	for x: float in [-2.6, 2.6]:
		g.box(Vector3(x, 2.55, -7.0), Vector3(2.1, 2.55, 0.05), P.BLACK)                 # the dark inside
	g.tier = 2
	g.gable(Vector3(0, 6.4, 2.0), 7.0, 9.3, 3.0, P.SLATE, 0.4, false, P.BRICK)
	g.tier = 3
	# smoke vents on the ridge
	for k in 4:
		var z := -4.0 + float(k) * 4.5
		g.box(Vector3(0, 9.65, z), Vector3(0.6, 0.35, 0.9), P.TIMBER_DARK)
		g.box(Vector3(0, 10.05, z), Vector3(0.85, 0.06, 1.1), P.SLATE)
		b.life.append({"type": "smoke", "at": Vector3(0, 10.3, z)})
	g.tier = 1
	for x: float in [-4.4, 4.4]:
		P.lamp(b, Vector3(x, 5.0, -7.8), 0.0, 10.0)
	b.marks["rail_a"] = Vector3(-2.6, 0, -12)
	b.marks["rail_b"] = Vector3(2.6, 0, -12)


## A water tower, 1x1 tile: a riveted steel tank on four braced legs, a ladder, and a swinging spout that
## swings out over the track (along x at z = 2.8) when an engine takes water.
static func water_tower(b: Building) -> void:
	var g := b.g
	P.track(g, Vector3(-4, 0, 2.8), Vector3(4, 0, 2.8))
	g.tier = 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			g.box(Vector3(sx * 1.6, 0.25, -1.0 + sz * 1.6), Vector3(0.35, 0.25, 0.35), P.CONCRETE)
	g.tier = 1
	var c := Vector3(0, 0, -1.0)
	g.tag = "keep"
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			g.cyl(c + Vector3(sx * 1.6, 0.5, sz * 1.6), c + Vector3(sx * 1.3, 6.0, sz * 1.3), 0.13, 6, P.METAL)
	g.tag = ""
	g.tier = 3
	for y in [2.0, 4.2]:
		for k in 4:
			var a := Vector3([-1.6, 1.6, 1.6, -1.6][k], y, [-1.6, -1.6, 1.6, 1.6][k]) * Vector3(0.9, 1, 0.9)
			var e := Vector3([1.6, 1.6, -1.6, -1.6][k], y + 1.8, [-1.6, 1.6, 1.6, -1.6][k]) * Vector3(0.85, 1, 0.85)
			g.cyl(c + a, c + e, 0.04, 4, P.METAL)
	g.tier = 1
	g.cyl(c + Vector3(0, 6.0, 0), c + Vector3(0, 9.4, 0), 2.2, 14, P.OLIVE.darkened(0.25))
	g.tier = 3
	for y in [6.6, 7.7, 8.8]:
		g.cyl(c + Vector3(0, y, 0), c + Vector3(0, y + 0.08, 0), 2.24, 14, P.METAL)
	g.tier = 2
	g.cyl(c + Vector3(0, 9.4, 0), c + Vector3(0, 10.0, 0), 2.3, 14, P.METAL, 0.4)
	g.tier = 3
	for k in 14:
		g.box(c + Vector3(-2.3 - 0.06, 0.4 + float(k) * 0.65, 0.0), Vector3(0.04, 0.03, 0.25), P.METAL)
	g.cyl(c + Vector3(-2.35, 0.2, -0.25), c + Vector3(-2.35, 9.4, -0.25), 0.03, 4, P.METAL)
	g.cyl(c + Vector3(-2.35, 0.2, 0.25), c + Vector3(-2.35, 9.4, 0.25), 0.03, 4, P.METAL)
	# the spout: pivots at the tank side, swings over the track
	var sg := TrainGeo.new()
	sg.cyl(Vector3.ZERO, Vector3(0, -0.6, 2.8), 0.2, 8, P.METAL)
	sg.cyl(Vector3(0, -0.6, 2.8), Vector3(0, -1.6, 3.2), 0.16, 8, Color(0.25, 0.22, 0.2))
	sg.cyl(Vector3(0, 0.2, 0.3), Vector3(0, 0.3, 2.6), 0.015, 3, P.WIRE)
	var spout := b.part_mesh("Spout", c + Vector3(0, 6.6, 2.1), sg)
	b.life.append({"type": "wave", "node": spout, "axis": Vector3(0, 1, 0), "amp": 0.5, "f": 0.3, "base": Vector3(0, -0.5, 0)})
	P.lamp(b, c + Vector3(1.8, 5.6, 1.8), 0.0, 8.0)
	b.marks["rail"] = Vector3(0, 0, 2.8)


## A coal stage, 2x1 tiles: a raised timber stage of coal beside the track, coal heaps, baskets and a
## jib crane with a bucket that swings coal over to the tenders.
static func coal_stage(b: Building) -> void:
	var g := b.g
	P.track(g, Vector3(-8, 0, 2.6), Vector3(8, 0, 2.6))
	g.tier = 0
	g.box(Vector3(0, 0.03, -1.4), Vector3(7.6, 0.03, 2.4), P.EARTH_DARK)
	g.tier = 1
	g.box(Vector3(0, 1.4, -1.0), Vector3(6.5, 1.4, 1.5), P.TIMBER_DARK)
	g.tier = 3
	g.tag = "detail"
	for k in 14:
		g.box(Vector3(-6.5 + float(k), 1.4, 0.52), Vector3(0.06, 1.4, 0.03), P.TIMBER)
	g.tag = ""
	g.tier = 1
	g.box(Vector3(0, 2.85, -1.0), Vector3(6.7, 0.06, 1.7), P.PLANK)
	g.tier = 3
	# a low heap along the stage, small lumps on it
	var coal := Color(0.16, 0.15, 0.14)
	g.lump(Vector3(-0.8, 2.9, -1.3), 1.0, coal, Vector3(5.2, 0.55, 1.2))
	for k in 22:
		var x := -5.6 + BGeo._h(k, 1) * 10.0
		g.lump(Vector3(x, 3.1 + BGeo._h(k, 2) * 0.25, -1.3 + (BGeo._h(k, 3) - 0.5) * 1.6), 0.28 + BGeo._h(k, 4) * 0.2,
			coal.lightened(BGeo._h(k, 5) * 0.08))
	for k in 3:
		g.cyl(Vector3(-4.0 + float(k) * 0.7, 2.9, 0.2), Vector3(-4.0 + float(k) * 0.7, 3.4, 0.2), 0.3, 8, P.TIMBER, 0.36)
		g.lump(Vector3(-4.0 + float(k) * 0.7, 3.4, 0.2), 0.3, P.COAL, Vector3(1, 0.5, 1))
	# steps up to the stage
	for k in 5:
		g.box(Vector3(7.0 + float(k) * 0.0, 0.28 + float(k) * 0.56, -1.0 - 0.0), Vector3(0.5, 0.06, 0.8), P.TIMBER, Basis())
	g.tier = 1
	g.cyl(Vector3(5.4, 2.9, 0.1), Vector3(5.4, 7.4, 0.1), 0.14, 6, P.METAL)
	var jg := TrainGeo.new()
	jg.cyl(Vector3(0, 0, 0), Vector3(0, 0.6, 3.4), 0.1, 5, P.METAL)
	jg.cyl(Vector3(0, -2.2, 0.2), Vector3(0, 0.6, 3.2), 0.05, 4, P.METAL)
	jg.cyl(Vector3(0, 0.6, 3.4), Vector3(0, -1.2, 3.4), 0.015, 3, P.WIRE)
	jg.cyl(Vector3(0, -1.2, 3.4), Vector3(0, -1.9, 3.4), 0.45, 8, P.METAL, 0.3)
	jg.lump(Vector3(0, -1.2, 3.4), 0.4, P.COAL, Vector3(1, 0.4, 1))
	var jib := b.part_mesh("Jib", Vector3(5.4, 7.0, 0.1), jg)
	b.life.append({"type": "wave", "node": jib, "axis": Vector3(0, 1, 0), "amp": 1.3, "f": 0.4, "base": Vector3(0, -0.4, 0)})
	P.lamp(b, Vector3(-5.6, 6.0, 0.4), 3.0, 9.0)
	b.marks["rail"] = Vector3(0, 0, 2.6)


## A signal box, 1x1 tile: a brick base, a timber operating room glazed all round, a stair up the side, and
## two signal posts whose arms drop to clear and rise to danger.
static func signal_box(b: Building) -> void:
	var g := b.g
	P.track(g, Vector3(-4, 0, 2.9), Vector3(4, 0, 2.9))
	var c := Vector3(0, 0, -1.2)
	P.plinth(g, c, 2.2, 1.6, 0.3, P.STONE_DARK)
	g.tier = 1
	P.block(g, c, 2.0, 1.4, 2.8, P.BRICK, 0.3)
	P.block(g, c, 2.1, 1.5, 2.4, P.PLANK, 3.1)
	g.tier = 3
	g.box(c + Vector3(0, 3.12, 0), Vector3(2.2, 0.1, 1.6), P.TIMBER_DARK)
	g.tier = 1
	P.windows(g, c + Vector3(-1.6, 4.4, 1.51), c + Vector3(1.6, 4.4, 1.51), Vector3(0, 0, 1), 4, 0.7, 1.3)
	P.windows(g, c + Vector3(-1.6, 4.4, -1.51), c + Vector3(1.6, 4.4, -1.51), Vector3(0, 0, -1), 4, 0.7, 1.3)
	for s: float in [-1.0, 1.0]:
		P.windows(g, c + Vector3(s * 2.11, 4.4, -1.0), c + Vector3(s * 2.11, 4.4, 1.0), Vector3(s, 0, 0), 2, 0.7, 1.3)
	P.window(g, c + Vector3(0, 1.6, 1.41), Vector3(0, 0, 1), 0.8, 0.8)
	g.tier = 2
	g.gable(c + Vector3(0, 5.5, 0), 2.1, 1.5, 1.2, P.SLATE, 0.35, true, P.PLANK)
	b.life.append({"type": "smoke", "at": P.chimney(g, c + Vector3(1.3, 0, -0.6), 6.0, 7.2)})
	# the stair up the left end
	g.tier = 3
	for k in 8:
		g.box(c + Vector3(-2.4 - 0.0, 0.2 + float(k) * 0.37, 1.1 - float(k) * 0.33), Vector3(0.4, 0.04, 0.16), P.TIMBER)
	g.box(c + Vector3(-2.4, 3.05, -1.75), Vector3(0.45, 0.05, 0.4), P.TIMBER)
	g.cyl(c + Vector3(-2.8, 0.2, 1.3), c + Vector3(-2.8, 3.9, -1.6), 0.03, 4, P.TIMBER_DARK)
	P.door(g, c + Vector3(-2.11, 3.1, -1.0), Vector3(-1, 0, 0), 0.8, 1.9)
	g.tier = 1
	P.lamp(b, c + Vector3(-2.5, 5.2, -1.7), 0.0, 6.0)
	# two signal posts beside the track with arms (pivot at the post) on the life loop
	for k in 2:
		var px := -3.3 if k == 0 else 3.3
		g.tier = 1
		g.cyl(Vector3(px, 0, 1.4), Vector3(px, 7.2, 1.4), 0.1, 6, P.WHITE)
		g.tier = 3
		g.box(Vector3(px, 7.3, 1.4), Vector3(0.14, 0.1, 0.14), P.METAL)
		g.tag = "glow"
		g.box(Vector3(px + 0.18, 6.0, 1.4), Vector3(0.08, 0.08, 0.08), Color(0.3, 0.6, 0.3))
		g.tag = ""
		var ag := TrainGeo.new()
		ag.box(Vector3(0.75, 0, 0), Vector3(0.75, 0.13, 0.03), P.RED)
		ag.box(Vector3(1.0, 0, -0.035), Vector3(0.06, 0.13, 0.01), P.WHITE)
		ag.box(Vector3(-0.15, -0.05, 0), Vector3(0.16, 0.2, 0.05), P.METAL)
		var arm := b.part_mesh("Arm%d" % k, Vector3(px + 0.12, 6.6, 1.4), ag)
		if k == 1:
			arm.rotation.y = PI
		var fn := func(tt: float, _dt: float) -> void:
			var ph := fmod(tt + float(k) * 3.0, 8.0)
			var u := smoothstep(0.0, 0.6, ph) - smoothstep(4.0, 4.6, ph)
			arm.rotation.z = (-0.7 if k == 0 else 0.7) * u
		b.life.append({"type": "call", "fn": fn})
	b.marks["rail"] = Vector3(0, 0, 2.9)
	b.marks["door"] = c + Vector3(-2.4, 0, 1.6)
