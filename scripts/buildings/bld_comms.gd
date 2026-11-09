class_name BldComms
extends RefCounted
## Iron Front comms buildings (Asset Builder Chat): runner post, telegraph post, lamp tower and pigeon loft.

const P := preload("res://scripts/buildings/bld_parts.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")


## A runner post, 1x1 tile: a sandbagged dugout entry under a timber frame, a message board, a bench,
## a bicycle against the bags and a runner waiting by the door.
static func runner_post(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(3.6, 0.03, 3.6), P.EARTH)
	g.tier = 1
	# the dugout mound with its timber door frame
	g.lump(Vector3(0, 0.4, 1.2), 1.0, P.EARTH_DARK, Vector3(3.0, 1.1, 2.2))
	P.sandbags(g, Vector3(-2.6, 0, -0.6), Vector3(-0.9, 0, -0.6), 4)
	P.sandbags(g, Vector3(0.9, 0, -0.6), Vector3(2.6, 0, -0.6), 4)
	g.box(Vector3(0, 1.4, 0.4), Vector3(1.6, 1.4, 1.6), P.TIMBER_DARK)
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 0.85, 1.1, -1.25), Vector3(0.12, 1.1, 0.12), P.TIMBER)
	g.box(Vector3(0, 2.25, -1.25), Vector3(1.05, 0.14, 0.14), P.TIMBER)
	g.tier = 2
	g.box(Vector3(0, 2.95, 0.3), Vector3(1.9, 0.08, 2.0), P.IRON, Basis(Vector3.RIGHT, 0.12))
	g.tier = 3
	g.box(Vector3(0, 1.0, -1.22), Vector3(0.72, 1.0, 0.03), P.BLACK)
	# the message board with pinned notes
	g.box(Vector3(2.2, 1.6, -1.0), Vector3(0.7, 0.5, 0.04), P.PLANK)
	for k in 5:
		g.box(Vector3(1.75 + float(k) * 0.22, 1.6 + (BGeo._h(k, 9) - 0.5) * 0.5, -1.05), Vector3(0.08, 0.1, 0.01), P.CREAM)
	g.cyl(Vector3(2.2, 0, -0.98), Vector3(2.2, 1.2, -0.98), 0.05, 4, P.TIMBER)
	# a bench and a bicycle
	g.box(Vector3(-2.1, 0.45, -1.4), Vector3(0.8, 0.04, 0.2), P.TIMBER)
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(-2.1 + s * 0.65, 0.22, -1.4), Vector3(0.04, 0.22, 0.18), P.TIMBER)
	var bk := Vector3(1.6, 0, -1.6)
	for s: float in [-1.0, 1.0]:
		var w := bk + Vector3(s * 0.55, 0.35, 0)
		g.cyl(w + Vector3(0, 0, -0.02), w + Vector3(0, 0, 0.02), 0.35, 10, P.METAL)
	g.cyl(bk + Vector3(-0.55, 0.35, 0), bk + Vector3(0.1, 0.85, 0), 0.025, 4, P.OLIVE)
	g.cyl(bk + Vector3(0.55, 0.35, 0), bk + Vector3(0.1, 0.85, 0), 0.025, 4, P.OLIVE)
	g.cyl(bk + Vector3(0.1, 0.85, 0), bk + Vector3(0.5, 1.0, 0), 0.025, 4, P.OLIVE)
	g.box(bk + Vector3(-0.15, 0.95, 0), Vector3(0.14, 0.03, 0.06), P.BLACK)
	g.tier = 1
	P.flagpole(b, Vector3(2.9, 0, 2.9), 4.5, Color(0.85, 0.75, 0.2))
	P.lamp(b, Vector3(0, 2.3, -1.45), 0.0, 7.0)
	b.add_man(Vector3(-0.9, 0.06, -2.2), 0.3, R.poses()["stand"], 51)
	b.add_man(Vector3(-2.1, 0.06, -1.9), PI * 0.1, R.poses()["kneel"], 52)
	b.marks["door"] = Vector3(0, 0, -1.8)


## A telegraph post, 1x1 tile: a timber hut with a key desk window, a line of poles with insulators carrying
## the wires off the tile, a battery box, a hand generator, and a lamp over the door.
static func telegraph(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(3.6, 0.03, 3.6), P.GRAVEL)
	P.hut(g, Vector3(-0.8, 0, 0.6), 2.0, 1.6, 2.5, P.TARPAPER, true, P.PLANK, false, 0)
	g.tier = 1
	P.door(g, Vector3(-1.6, 0, -1.02), Vector3(0, 0, -1), 0.9, 2.0)
	P.window(g, Vector3(0.0, 1.5, -1.02), Vector3(0, 0, -1), 1.0, 0.8)
	# the poles: one at the hut, three marching out to the tile edge and the wires sagging between them
	var poles := [Vector3(1.6, 0, 1.8), Vector3(3.6, 0, 1.8), Vector3(5.6, 0, 1.8)]
	var top := 6.0
	for p: Vector3 in poles:
		g.tier = 1
		g.cyl(p, p + Vector3(0, top, 0), 0.12, 6, P.TIMBER_DARK)
		g.tier = 3
		g.box(p + Vector3(0, top - 0.4, 0), Vector3(0.06, 0.06, 0.8), P.TIMBER)
		for s: float in [-1.0, -0.33, 0.33, 1.0]:
			g.cyl(p + Vector3(0, top - 0.34, s * 0.7), p + Vector3(0, top - 0.2, s * 0.7), 0.05, 5, P.WHITE)
	g.tier = 3
	g.tag = "detail"
	var ends := [Vector3(-0.2, 2.9, 0.6)] + poles + [Vector3(9.0, 0, 1.8)]
	for i in ends.size() - 1:
		var a: Vector3 = ends[i] + (Vector3(0, top - 0.2, 0) if i > 0 else Vector3.ZERO)
		var e: Vector3 = ends[i + 1] + Vector3(0, top - 0.2, 0)
		for s: float in ([-1.0, -0.33, 0.33, 1.0] if i > 0 else [0.0]):
			var o := Vector3(0, 0, s * 0.7)
			var mid := (a + e) * 0.5 + Vector3(0, -0.35, 0)
			g.cyl(a + o, mid + o, 0.012, 3, P.WIRE)
			g.cyl(mid + o, e + o, 0.012, 3, P.WIRE)
	g.tag = ""
	# batteries and the hand generator
	g.box(Vector3(1.6, 0.4, -1.5), Vector3(0.6, 0.4, 0.4), P.OLIVE)
	for k in 3:
		g.cyl(Vector3(1.2 + float(k) * 0.4, 0.8, -1.5), Vector3(1.2 + float(k) * 0.4, 0.9, -1.5), 0.08, 6, P.METAL)
	g.box(Vector3(2.8, 0.5, -0.6), Vector3(0.3, 0.5, 0.3), P.OLIVE.darkened(0.2))
	var crank := TrainGeo.new()
	crank.box(Vector3(0, 0.18, 0), Vector3(0.03, 0.18, 0.03), P.METAL)
	crank.box(Vector3(0.08, 0.34, 0), Vector3(0.08, 0.03, 0.03), P.TIMBER)
	var cr := b.part_mesh("Crank", Vector3(3.12, 0.7, -0.6), crank)
	cr.rotation.y = PI * 0.5
	b.life.append({"type": "call", "fn": func(tt: float, _dt: float) -> void: cr.rotation.x = tt * 4.0})
	g.tier = 1
	P.lamp(b, Vector3(-1.6, 2.4, -1.2), 0.0, 6.0)
	b.life.append({"type": "smoke", "at": P.chimney(g, Vector3(-2.2, 0, 1.2), 2.5, 4.0)})
	b.add_man(Vector3(0.3, 0.06, -2.0), PI * 0.85, R.poses()["stand"], 61)
	b.marks["door"] = Vector3(-1.6, 0, -1.8)
	b.marks["wire_out"] = Vector3(9.0, top - 0.2, 1.8)


## A lamp tower, 1x1 tile: a timber lattice tower with a railed platform, a signal lamp whose shutters flash
## in long and short, a ladder, and a sandbag ring at its feet.
static func lamp_tower(b: Building) -> void:
	var g := b.g
	var h := 9.0
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(3.6, 0.03, 3.6), P.EARTH)
	g.tier = 1
	g.tag = "keep"
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			g.cyl(Vector3(sx * 1.8, 0, sz * 1.8), Vector3(sx * 1.0, h, sz * 1.0), 0.16, 6, P.TIMBER)
	g.tag = ""
	g.tier = 3
	for k in 3:
		var y0 := 0.6 + float(k) * 2.8
		var y1 := y0 + 2.8
		var w0 := 1.8 - 0.8 * y0 / h
		var w1 := 1.8 - 0.8 * y1 / h
		for f in 4:
			var d := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)][f] as Vector3
			var side := Vector3(-d.z, 0, d.x)
			g.cyl(d * w0 + side * w0 + Vector3(0, y0, 0), d * w1 - side * w1 + Vector3(0, y1, 0), 0.05, 4, P.TIMBER_DARK)
			g.cyl(d * w0 - side * w0 + Vector3(0, y0, 0), d * w1 + side * w1 + Vector3(0, y1, 0), 0.05, 4, P.TIMBER_DARK)
	g.tier = 1
	g.box(Vector3(0, h + 0.08, 0), Vector3(1.5, 0.08, 1.5), P.PLANK)
	g.tier = 3
	for f in 4:
		var d := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)][f] as Vector3
		var hs := Vector3(absf(d.z) * 1.5 + 0.04, 0.04, absf(d.x) * 1.5 + 0.04)
		g.box(d * 1.48 + Vector3(0, h + 1.1, 0), hs, P.TIMBER)
		g.box(d * 1.48 + Vector3(0, h + 0.6, 0), hs, P.TIMBER)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			g.cyl(Vector3(sx * 1.48, h, sz * 1.48), Vector3(sx * 1.48, h + 1.15, sz * 1.48), 0.04, 4, P.TIMBER)
	# a hood over the platform
	g.tier = 2
	for sx: float in [-1.0, 1.0]:
		g.cyl(Vector3(sx * 1.2, h, 1.2), Vector3(sx * 1.2, h + 2.4, 1.2), 0.05, 4, P.TIMBER)
	g.box(Vector3(0, h + 2.5, 0.4), Vector3(1.4, 0.05, 1.1), P.IRON, Basis(Vector3.RIGHT, -0.15))
	# ladder up the south face
	g.tier = 3
	for s: float in [-1.0, 1.0]:
		g.cyl(Vector3(s * 0.3, 0, -2.05), Vector3(s * 0.3, h, -1.55), 0.03, 4, P.TIMBER)
	for k in 15:
		var y := 0.4 + float(k) * 0.6
		g.box(Vector3(0, y, -2.05 + 0.5 * y / h), Vector3(0.3, 0.025, 0.025), P.TIMBER)
	# sandbags round the feet
	for f in 4:
		var a := Vector3([-2.6, 2.6, 2.6, -2.6][f], 0, [-2.6, -2.6, 2.6, 2.6][f])
		var e := Vector3([2.6, 2.6, -2.6, -2.6][f], 0, [-2.6, 2.6, 2.6, -2.6][f])
		if f == 0:
			P.sandbags(g, a, a + (e - a) * 0.35, 2)
			P.sandbags(g, a + (e - a) * 0.65, e, 2)
		else:
			P.sandbags(g, a, e, 2)
	g.tier = 1
	# the signal lamp: a box on a yoke, its lens and the shutter slats in front
	var lamp := b.part("SignalLamp", Vector3(0, h + 0.9, -0.4))
	var lg := TrainGeo.new()
	lg.box(Vector3(0, 0.45, 0.2), Vector3(0.45, 0.45, 0.45), P.OLIVE.darkened(0.3))
	lg.cyl(Vector3(0, 0.45, 0.65), Vector3(0, 0.45, 0.95), 0.12, 6, P.METAL)
	lg.box(Vector3(0, -0.3, 0.2), Vector3(0.06, 0.3, 0.06), P.METAL)
	lg.make(lamp, "Mesh", P.material())
	var lens := TrainGeo.new()
	lens.cyl(Vector3(0, 0.45, -0.24), Vector3(0, 0.45, -0.27), 0.38, 12, Color(0.75, 0.72, 0.6))
	lens.make(lamp, "Lens", P.material())
	var lit := TrainGeo.new()
	lit.cyl(Vector3(0, 0.45, -0.26), Vector3(0, 0.45, -0.29), 0.37, 12, Color(1.0, 0.93, 0.75))
	lit.make(lamp, "LensLit", b._glow_mat)
	var ln: Node3D = lamp.get_node("LensLit")
	var slats: Array[Node3D] = []
	for k in 4:
		var sg := TrainGeo.new()
		sg.box(Vector3(0, 0, 0), Vector3(0.44, 0.1, 0.012), P.METAL)
		var sl := Node3D.new()
		sl.position = Vector3(0, 0.15 + float(k) * 0.2, -0.32)
		lamp.add_child(sl)
		sg.make(sl, "Mesh", P.material())
		slats.append(sl)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 0.45, -0.35)
	spot.light_color = Color(1.0, 0.92, 0.75)
	spot.spot_range = 90.0
	spot.spot_angle = 6.0
	spot.light_energy = 0.0
	lamp.add_child(spot)
	# morse: "... --- " style, a long and short pattern on a 6 s loop
	var pattern := [0.3, 0.3, 0.3, 0.9, 0.9, 0.9]
	var fn := func(tt: float, _dt: float) -> void:
		lamp.rotation.y = sin(tt * 0.15) * 0.6
		var t := fmod(tt, 7.0)
		var open := false
		var at := 0.0
		for d: float in pattern:
			if t >= at and t < at + d:
				open = true
				break
			at += d + 0.35
		for sl: Node3D in slats:
			sl.rotation.x = lerpf(sl.rotation.x, 1.45 if open else 0.0, 0.5)
		var on := open and b.lights_on
		ln.visible = b.lights_on and open
		spot.light_energy = 6.0 if on else 0.0
	b.life.append({"type": "call", "fn": fn})
	b.add_man(Vector3(0.7, h + 0.16, 0.6), PI, R.poses()["stand"], 71)
	b.marks["door"] = Vector3(0, 0, -2.6)
	b.marks["lamp"] = Vector3(0, h + 1.35, -0.4)


## A pigeon loft, 1x1 tile: a timber loft raised on posts with a pitched roof, a landing board and holes,
## a hatch ladder, baskets for the runners, and a few birds wheeling over it.
static func pigeon_loft(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(3.6, 0.03, 3.6), P.EARTH)
	g.tier = 1
	var y0 := 1.8
	g.tag = "keep"
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			g.box(Vector3(sx * 1.7, y0 * 0.5, sz * 1.3), Vector3(0.12, y0 * 0.5, 0.12), P.TIMBER_DARK)
	g.tag = ""
	g.box(Vector3(0, y0 + 0.06, 0), Vector3(1.95, 0.06, 1.55), P.PLANK)
	P.block(g, Vector3.ZERO, 1.85, 1.45, 1.9, P.PLANK, y0 + 0.12)
	g.tier = 3
	g.tag = "detail"
	for k in 10:
		g.box(Vector3(-1.7 + float(k) * 0.38, y0 + 1.07, -1.47), Vector3(0.03, 0.95, 0.02), P.TIMBER_DARK)
	g.tag = ""
	g.tier = 2
	g.gable(Vector3(0, y0 + 2.02, 0), 1.85, 1.45, 1.3, P.TARPAPER, 0.35, true, P.PLANK)
	g.tier = 3
	# the landing board and the bird holes, a little cupola on the ridge
	g.box(Vector3(0, y0 + 1.3, -1.75), Vector3(1.4, 0.04, 0.3), P.TIMBER)
	for k in 5:
		g.box(Vector3(-1.0 + float(k) * 0.5, y0 + 1.55, -1.47), Vector3(0.12, 0.16, 0.02), P.BLACK)
	g.box(Vector3(0, y0 + 3.55, 0), Vector3(0.35, 0.3, 0.35), P.PLANK)
	g.box(Vector3(0, y0 + 3.9, 0), Vector3(0.48, 0.05, 0.48), P.TARPAPER)
	# hatch ladder, baskets
	for s: float in [-1.0, 1.0]:
		g.cyl(Vector3(1.2 + s * 0.25, 0, 2.6), Vector3(1.2 + s * 0.25, y0 + 0.1, 1.6), 0.03, 4, P.TIMBER)
	for k in 5:
		var u := float(k + 1) / 6.0
		g.box(Vector3(1.2, u * y0, 2.6 - u), Vector3(0.25, 0.025, 0.025), P.TIMBER)
	for k in 3:
		var at := Vector3(-2.4 + float(k) * 0.5, 0.25, -2.4)
		g.box(at, Vector3(0.2, 0.25, 0.16), P.CANVAS.darkened(0.15))
		g.box(at + Vector3(0, 0.27, 0), Vector3(0.21, 0.02, 0.17), P.TIMBER)
	g.tier = 1
	P.lamp(b, Vector3(-1.9, y0 + 1.6, -1.6), 0.0, 6.0)
	# the birds: small grey bodies with wings out, wheeling over the loft
	for k in 6:
		var bg := TrainGeo.new()
		bg.lump(Vector3.ZERO, 0.11, Color(0.55, 0.57, 0.6), Vector3(0.8, 0.7, 1.6))
		bg.box(Vector3(0, 0.02, 0), Vector3(0.32, 0.01, 0.07), Color(0.48, 0.5, 0.54), Basis(Vector3.FORWARD, 0.25))
		var bird := b.part_mesh("Bird%d" % k, Vector3.ZERO, bg)
		b.life.append({"type": "orbit", "node": bird, "c": Vector3(0, 7.5 + float(k) * 0.4, 0), "r": 3.0 + float(k) * 0.9,
			"f": 0.7 + float(k % 3) * 0.12, "p": float(k) * 1.1})
	b.add_man(Vector3(-1.4, 0.06, -2.4), 0.4, R.poses()["stand"], 81)
	b.marks["door"] = Vector3(1.2, 0, 2.8)
