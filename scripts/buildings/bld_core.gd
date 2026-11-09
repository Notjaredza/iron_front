class_name BldCore
extends RefCounted
## Iron Front buildings, the core set (Asset Builder Chat): the HQ, the barracks and the depot.
## Each builder records its shapes into b.g and adds its moving parts, lights, men and marks to b.

const P := preload("res://scripts/buildings/bld_parts.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")


## The HQ, 3x3 tiles: a brick command post of two storeys with sandbagged front, a map room lit at night,
## a telegraph and radio mast, a flag, the staff car, and a sick-bay tent where the officer recovers.
static func hq(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(11.6, 0.03, 11.6), P.GRAVEL)
	g.box(Vector3(0, 0.05, -9), Vector3(1.6, 0.05, 3.0), P.STONE_DARK)              # the path to the door
	var c := Vector3(0, 0, -1)
	var hx := 7.0
	var hz := 5.0
	P.plinth(g, c, hx + 0.2, hz + 0.2, 0.5, P.STONE_DARK)
	g.tier = 1
	P.block(g, c, hx, hz, 7.0, P.BRICK, 0.5)
	g.tier = 3
	g.box(c + Vector3(0, 3.9, 0), Vector3(hx + 0.08, 0.12, hz + 0.08), P.STONE)     # string course
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			g.box(c + Vector3(sx * hx, 3.75, sz * hz), Vector3(0.25, 3.25, 0.25), P.BRICK_DARK)  # corner quoins
	g.tier = 2
	g.gable(c + Vector3(0, 7.5, 0), hx, hz, 3.2, P.SLATE, 0.45, true, P.BRICK)
	var s1 := P.chimney(g, c + Vector3(-4.0, 0, 1.5), 8.5, 11.6)
	var s2 := P.chimney(g, c + Vector3(4.0, 0, 1.5), 8.5, 11.6)
	b.life.append({"type": "smoke", "at": s1})
	b.life.append({"type": "smoke", "at": s2})
	g.tier = 1
	for row: float in [2.3, 5.6]:
		P.windows(g, c + Vector3(-hx * 0.85, row, -hz - 0.01), c + Vector3(-1.6, row, -hz - 0.01), Vector3(0, 0, -1), 2, 1.0, 1.4)
		P.windows(g, c + Vector3(1.6, row, -hz - 0.01), c + Vector3(hx * 0.85, row, -hz - 0.01), Vector3(0, 0, -1), 2, 1.0, 1.4)
		P.windows(g, c + Vector3(-hx * 0.85, row, hz + 0.01), c + Vector3(hx * 0.85, row, hz + 0.01), Vector3(0, 0, 1), 5, 1.0, 1.4)
		for s: float in [-1.0, 1.0]:
			P.windows(g, c + Vector3(s * (hx + 0.01), row, -hz * 0.6), c + Vector3(s * (hx + 0.01), row, hz * 0.6), Vector3(s, 0, 0), 2, 1.0, 1.4)
	P.window(g, c + Vector3(0, 5.6, -hz - 0.01), Vector3(0, 0, -1), 1.0, 1.4)
	# the porch: steps, two columns and a little roof over the door
	P.door(g, c + Vector3(0, 0.5, -hz - 0.01), Vector3(0, 0, -1), 1.5, 2.4)
	g.tier = 3
	for k in 3:
		g.box(c + Vector3(0, 0.1 + float(k) * 0.15, -hz - 0.6 - float(2 - k) * 0.3), Vector3(1.4, 0.08 + float(k) * 0.08, 0.15 + float(2 - k) * 0.15), P.STONE)
	for sx: float in [-1.0, 1.0]:
		g.cyl(c + Vector3(sx * 1.2, 0.5, -hz - 1.3), c + Vector3(sx * 1.2, 3.2, -hz - 1.3), 0.14, 8, P.STONE)
	g.tier = 2
	g.box(c + Vector3(0, 3.3, -hz - 0.75), Vector3(1.6, 0.1, 0.85), P.SLATE)
	g.tier = 3
	g.box(c + Vector3(0, 3.1, -hz - 0.03), Vector3(1.1, 0.25, 0.04), P.CREAM)         # the HQ board over the door
	P.lamp(b, c + Vector3(0, 2.9, -hz - 1.4))
	# sandbags across the front, leaving the path open
	P.sandbags(g, Vector3(-10.5, 0, -9.0), Vector3(-2.2, 0, -9.0), 4, 2)
	P.sandbags(g, Vector3(2.2, 0, -9.0), Vector3(10.5, 0, -9.0), 4, 2)
	P.sandbags(g, Vector3(-10.5, 0, -8.6), Vector3(-10.5, 0, -4.0), 4, 2)
	P.sandbags(g, Vector3(10.5, 0, -8.6), Vector3(10.5, 0, -4.0), 4, 2)
	# the mast: three legs to 17 m, cross braces, a top arm, guys to the ground and a wire to the house
	g.tier = 1
	var m0 := Vector3(8.6, 0, 7.6)
	var top := m0 + Vector3(0, 17, 0)
	var legs: Array[Vector3] = []
	for k in 3:
		var a := TAU * float(k) / 3.0
		legs.append(m0 + Vector3(cos(a), 0, sin(a)) * 1.1)
	for l in legs:
		g.cyl(l, top, 0.07, 5, P.METAL)
	g.tier = 3
	g.tag = "detail"
	for h in [3.0, 6.5, 10.0, 13.5]:
		for k in 3:
			var p0 := legs[k].lerp(top, h / 17.0)
			var p1 := legs[(k + 1) % 3].lerp(top, h / 17.0)
			g.cyl(p0, p1, 0.035, 4, P.METAL)
	g.cyl(top + Vector3(-1.8, -0.3, 0), top + Vector3(1.8, -0.3, 0), 0.05, 4, P.METAL)
	for sx: float in [-1.0, 1.0]:
		g.cyl(top + Vector3(sx * 1.8, -0.3, 0), c + Vector3(sx * 5.0, 10.2, 0), 0.015, 3, P.WIRE)   # aerial wires
	for k in 3:
		var a := TAU * (float(k) + 0.5) / 3.0
		g.cyl(top.lerp(m0, 0.35), m0 + Vector3(cos(a), 0, sin(a)) * 6.0, 0.012, 3, P.WIRE)
		g.box(m0 + Vector3(cos(a), 0, sin(a)) * 6.0 + Vector3(0, 0.15, 0), Vector3(0.2, 0.15, 0.2), P.CONCRETE)
	g.tag = ""
	b.marks["mast_top"] = top
	# a signals hut at the foot of the mast
	g.tier = 1
	P.block(g, Vector3(9.2, 0, 3.6), 1.4, 1.2, 2.4, P.PLANK, 0.0)
	g.tier = 2
	g.lean(Vector3(9.2, 2.55, 3.6), 1.4, 1.2, 0.4, P.IRON, 0.2)
	g.tier = 1
	P.window(g, Vector3(9.2, 1.5, 2.39), Vector3(0, 0, -1), 0.7, 0.6)
	# the sick-bay tent where the wounded officer recovers: a canvas ridge tent with a cot and a stretcher
	var tc := Vector3(-8.4, 0, 6.6)
	g.tier = 1
	g.box(tc + Vector3(0, 0.55, 0), Vector3(2.4, 0.55, 3.3), P.CANVAS)
	g.tier = 2
	g.gable(tc + Vector3(0, 1.1, 0), 2.4, 3.3, 1.5, P.CANVAS.darkened(0.06), 0.12, false, P.CANVAS)
	g.tier = 3
	g.box(tc + Vector3(0, 1.0, -3.31), Vector3(0.8, 1.0, 0.02), P.BLACK)                 # the open flap
	g.box(tc + Vector3(-0.9, 1.1, -3.6), Vector3(0.6, 1.1, 0.03), P.CANVAS.darkened(0.1), Basis(Vector3.UP, 0.7))
	g.cyl(tc + Vector3(0, 0, -3.4), tc + Vector3(0, 2.7, -3.4), 0.05, 5, P.TIMBER)
	g.cyl(tc + Vector3(0, 2.6, -3.4), tc + Vector3(0, 0, -5.0), 0.01, 3, P.WIRE)
	# cot inside the door and a stretcher outside
	g.box(tc + Vector3(0.5, 0.45, -1.6), Vector3(0.4, 0.06, 1.0), P.CANVAS.lightened(0.15))
	g.box(tc + Vector3(0.5, 0.56, -2.3), Vector3(0.3, 0.06, 0.18), P.WHITE)
	for sx: float in [-1.0, 1.0]:
		g.cyl(tc + Vector3(-2.8 + sx * 0.3, 0.12, -4.8), tc + Vector3(-2.8 + sx * 0.3, 0.12, -2.4), 0.03, 4, P.TIMBER)
	g.box(tc + Vector3(-2.8, 0.13, -3.6), Vector3(0.27, 0.02, 0.9), P.CANVAS)
	P.lamp(b, tc + Vector3(0.9, 2.0, -3.5))
	b.marks["officer_bed"] = tc + Vector3(0.5, 0.5, -1.6)
	# the flag and the staff car
	P.flagpole(b, Vector3(-4.0, 0, -10.2), 9.0)
	var car := b.part_mesh("StaffCar", Vector3(-7.4, 0, -11.0), P.staff_car())
	car.rotation.y = -0.35
	# lamps by the gap in the sandbags
	P.lamp(b, Vector3(-2.4, 2.6, -9.6), 2.4)
	P.lamp(b, Vector3(2.4, 2.6, -9.6), 2.4)
	# a sentry at the gap
	b.add_man(Vector3(2.9, 0, -10.0), 0.0, R.poses()["stand"], 11)
	b.marks["door"] = c + Vector3(0, 0, -hz - 1.8)
	b.marks["entry"] = Vector3(0, 0, -12.0)
	b.marks["car"] = Vector3(-7.4, 0, -11.0)


## The barracks, 2x3 tiles: two timber huts with iron roofs and stove pipes, a drill square with a flag,
## and a squad drilling on it.
static func barracks(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(7.8, 0.03, 11.8), P.EARTH)
	g.box(Vector3(0, 0.05, 7.4), Vector3(7.2, 0.05, 4.0), P.GRAVEL)                  # the drill square
	for k in 2:
		var hc := Vector3(0, 0, -8.2 + float(k) * 6.8)
		P.hut(g, hc, 7.0, 2.6, 2.6, P.IRON, true, P.PLANK, false, 4)
		P.door(g, hc + Vector3(-1.2, 0.35, 2.61), Vector3(0, 0, 1))
		P.door(g, hc + Vector3(1.2, 0.35, -2.61), Vector3(0, 0, -1))
		g.tier = 3
		g.box(hc + Vector3(-1.2, 0.2, 3.1), Vector3(0.7, 0.15, 0.45), P.TIMBER_DARK)    # step
		# stove pipe
		g.cyl(hc + Vector3(3.0, 3.6, 0.9), hc + Vector3(3.0, 5.6, 0.9), 0.13, 6, P.METAL)
		g.box(hc + Vector3(3.0, 5.7, 0.9), Vector3(0.22, 0.05, 0.22), P.METAL)
		b.life.append({"type": "smoke", "at": hc + Vector3(3.0, 5.9, 0.9)})
		P.lamp(b, hc + Vector3(-1.2, 2.7, 2.75))
	# rifle racks and a water butt by the square
	g.tier = 3
	g.cyl(Vector3(6.6, 0, 3.6), Vector3(6.6, 1.2, 3.6), 0.45, 8, P.TIMBER_DARK)
	g.box(Vector3(-6.4, 0.6, 4.2), Vector3(0.12, 0.6, 1.4), P.TIMBER)
	P.flagpole(b, Vector3(-6.8, 0, 11.0), 8.0)
	# the squad: two ranks of four, the corporal facing them; they come to the ready and back
	var men: Array[Soldier] = []
	for r in 2:
		for k in 4:
			men.append(b.add_man(Vector3(-3.0 + float(k) * 1.8, 0.1, 8.0 + float(r) * 1.6), PI, R.poses()["stand"], 30 + r * 4 + k))
	b.add_man(Vector3(0.0, 0.1, 5.0), 0.0, Body.body("stand"), 41)
	var drill := func(tt: float, _dt: float) -> void:
		var ph := int(tt / 2.5) % 2
		if ph == int(b.get_meta("drill_ph", -1)):
			return
		b.set_meta("drill_ph", ph)
		for m in men:
			m.pose_spec_world(R.poses()["ready" if ph == 1 else "stand"])
	b.life.append({"type": "call", "fn": drill})
	b.marks["door_a"] = Vector3(-1.2, 0, -5.0)
	b.marks["door_b"] = Vector3(-1.2, 0, 1.8)
	b.marks["muster"] = Vector3(0, 0, 7.4)
	b.marks["entry"] = Vector3(0, 0, -12.0)


## The depot, 3x2 tiles: an open shed with an iron roof over stacked crates and fuel drums, a loading
## platform on a rail siding at the back, a truck apron at the front and a hand crane that swings loads.
static func depot(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, -1.5), Vector3(11.8, 0.03, 6.4), P.GRAVEL)
	P.track(g, Vector3(-12, 0, 5.4), Vector3(12, 0, 5.4))
	g.tier = 0
	g.box(Vector3(0, 0.55, 2.6), Vector3(10.5, 0.55, 1.6), P.CONCRETE)                # the platform
	g.box(Vector3(0, 0.55, -2.0), Vector3(10.0, 0.55, 3.2), P.CONCRETE_DARK)          # the shed floor
	# the shed frame and roof
	g.tier = 1
	for k in 6:
		var x := -10.0 + float(k) * 4.0
		for z: float in [-5.0, 0.0, 4.0]:
			g.box(Vector3(x, 3.3, z), Vector3(0.15, 2.2, 0.15), P.TIMBER)
		g.box(Vector3(x, 5.45, -0.5), Vector3(0.12, 0.15, 4.7), P.TIMBER_DARK)
	g.box(Vector3(0, 5.5, -5.0), Vector3(10.2, 0.15, 0.12), P.TIMBER_DARK)
	g.box(Vector3(0, 5.5, 4.0), Vector3(10.2, 0.15, 0.12), P.TIMBER_DARK)
	# a back wall of planks on the left third (the office), the rest open
	P.block(g, Vector3(-8.0, 0, -2.0), 2.0, 3.0, 4.2, P.PLANK, 1.1)
	P.window(g, Vector3(-5.99, 3.2, -2.0), Vector3(1, 0, 0), 0.8, 0.8)
	P.door(g, Vector3(-8.0, 1.1, -5.01), Vector3(0, 0, -1))
	g.tier = 2
	g.box(Vector3(0, 5.85, -0.5), Vector3(10.9, 0.08, 5.6), P.IRON, Basis(Vector3.RIGHT, 0.05))
	# crate stacks and drums under the roof and on the platform
	var rng_cols := [P.OLIVE, P.PLANK, Color(0.62, 0.52, 0.34), P.OLIVE.darkened(0.15)]
	for k in 14:
		var x := -4.5 + float(k % 7) * 2.0
		var z := -3.6 + float(k / 7) * 2.6
		var hgt := 1 + int(BGeo._h(k, 11) * 3.0)
		for l in hgt:
			g.box(Vector3(x + (BGeo._h(k * 5 + l, 2) - 0.5) * 0.2, 1.1 + 0.4 + float(l) * 0.8, z), Vector3(0.75, 0.4, 0.55),
				rng_cols[(k + l) % 4], Basis(Vector3.UP, (BGeo._h(k, l) - 0.5) * 0.2))
	for k in 9:
		var x := -9.0 + float(k % 3) * 0.75
		var z := 1.8 + float(k / 3) * 0.75
		g.cyl(Vector3(x, 1.1, z), Vector3(x, 2.0, z), 0.32, 8, Color(0.42, 0.20, 0.14) if k % 4 else P.OLIVE)
	for k in 6:
		g.box(Vector3(2.0 + float(k) * 1.4, 1.5, 2.8), Vector3(0.6, 0.4, 0.5), rng_cols[k % 4])
	# the hand crane on the platform: a post with a swinging jib and a crate on the hook
	g.tier = 1
	g.cyl(Vector3(8.6, 1.1, 3.2), Vector3(8.6, 5.2, 3.2), 0.16, 6, P.TIMBER_DARK)
	var jg := TrainGeo.new()
	jg.cyl(Vector3(0, 0, 0), Vector3(0, 0.5, 3.6), 0.11, 5, P.TIMBER_DARK)
	jg.cyl(Vector3(0, -1.6, 0.2), Vector3(0, 0.5, 3.4), 0.06, 4, P.METAL)
	jg.cyl(Vector3(0, 0.5, 3.6), Vector3(0, -1.6, 3.6), 0.015, 3, P.WIRE)
	jg.box(Vector3(0, -2.0, 3.6), Vector3(0.5, 0.35, 0.4), P.OLIVE)
	jg.cyl(Vector3(0.25, -1.2, 0.2), Vector3(-0.25, -1.2, 0.2), 0.25, 8, P.METAL)      # winch drum
	var jib := b.part_mesh("Jib", Vector3(8.6, 4.8, 3.2), jg)
	b.life.append({"type": "wave", "node": jib, "axis": Vector3(0, 1, 0), "amp": 1.2, "f": 0.35, "base": Vector3(0, 0.6, 0)})
	# lamps
	P.lamp(b, Vector3(-4.0, 5.1, 3.9))
	P.lamp(b, Vector3(4.0, 5.1, 3.9))
	P.lamp(b, Vector3(0.0, 5.1, -4.9))
	b.marks["truck_bay"] = Vector3(0, 0, -7.5)
	b.marks["rail"] = Vector3(0, 0, 5.4)
	b.marks["platform"] = Vector3(0, 1.1, 2.6)
