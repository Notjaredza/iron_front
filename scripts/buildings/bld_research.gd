class_name BldResearch
extends RefCounted
## Iron Front research buildings and the wreck yard (Asset Builder Chat). WW1 with a hint: each lab is a
## plain field-army building with one piece of strange tech on it (a coil or pylon that glows teal and hums).

const P := preload("res://scripts/buildings/bld_parts.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")

static var _strange_mat: StandardMaterial3D


## The teal strange-tech glow (always on: it is not on the lights switch).
static func strange_material() -> StandardMaterial3D:
	if _strange_mat == null:
		_strange_mat = StandardMaterial3D.new()
		_strange_mat.vertex_color_use_as_albedo = true
		_strange_mat.emission_enabled = true
		_strange_mat.emission = P.STRANGE
		_strange_mat.emission_energy_multiplier = 2.6
	return _strange_mat


## A coil on an insulated stand: a copper drum wound with rings, a teal glowing core above, a soft light,
## and a slow pulse. Returns the core node.
static func coil(b: Building, at: Vector3, h := 2.4, r := 0.5) -> Node3D:
	var g := b.g
	var tr := g.tier
	g.tier = 3
	g.cyl(at, at + Vector3(0, h * 0.35, 0), r * 0.5, 8, P.WHITE)
	for k in 3:
		var y := h * 0.08 + float(k) * h * 0.1
		g.cyl(at + Vector3(0, y, 0), at + Vector3(0, y + 0.06, 0), r * 0.7, 10, Color(0.45, 0.42, 0.38))
	g.cyl(at + Vector3(0, h * 0.35, 0), at + Vector3(0, h * 0.85, 0), r, 12, Color(0.62, 0.38, 0.2))
	for k in 6:
		var y := h * 0.38 + float(k) * h * 0.08
		g.cyl(at + Vector3(0, y, 0), at + Vector3(0, y + 0.04, 0), r + 0.04, 12, Color(0.5, 0.3, 0.16))
	g.tier = tr
	var cg := TrainGeo.new()
	cg.lump(Vector3.ZERO, r * 0.55, P.STRANGE)
	cg.cyl(Vector3(0, -r * 0.6, 0), Vector3(0, r * 0.6, 0), r * 0.18, 6, P.STRANGE)
	var core := b.part("Core", at + Vector3(0, h * 0.85 + r * 0.6, 0))
	cg.make(core, "Mesh", strange_material())
	var l := OmniLight3D.new()
	l.light_color = P.STRANGE
	l.omni_range = 6.0
	l.light_energy = 1.2
	core.add_child(l)
	b.life.append({"type": "call", "fn": func(tt: float, _dt: float) -> void:
		var u := 0.85 + 0.15 * sin(tt * 3.1) + 0.08 * sin(tt * 17.0)
		core.scale = Vector3.ONE * u
		core.rotation.y = tt * 0.8
		l.light_energy = 0.8 + 0.6 * u})
	return core


## A lit work torch: a flickering blue-white light and sparks (the wreck yard's cutters).
static func torch(b: Building, at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = Color(0.75, 0.85, 1.0)
	l.omni_range = 7.0
	l.light_energy = 2.0
	b.parts.add_child(l)
	b.life.append({"type": "flicker", "light": l, "e": 2.4, "at": at})


static func _fence(g: BGeo, a: Vector3, e: Vector3, h := 2.2) -> void:
	var tr := g.tier
	var n := maxi(1, int(a.distance_to(e) / 3.0))
	g.tier = 3
	for k in n + 1:
		var p := a.lerp(e, float(k) / float(n))
		g.cyl(p, p + Vector3(0, h, 0), 0.05, 4, P.TIMBER_DARK)
	g.tag = "detail"
	for y in [0.5, 1.1, 1.7, 2.1]:
		g.cyl(a + Vector3(0, y, 0), e + Vector3(0, y, 0), 0.012, 3, P.WIRE)
	g.tag = ""
	g.tier = tr


## The comms lab, 2x2 tiles: a brick lab with a wireless mast and aerials, an aerial wire to a second
## pole, and a coil in a fenced pen that pulses.
static func lab_comms(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(7.6, 0.03, 7.6), P.GRAVEL)
	var c := Vector3(-1.5, 0, 1.5)
	P.plinth(g, c, 4.2, 3.2, 0.4, P.STONE_DARK)
	g.tier = 1
	P.block(g, c, 4.0, 3.0, 3.4, P.BRICK, 0.4)
	g.tier = 2
	g.gable(c + Vector3(0, 3.8, 0), 4.0, 3.0, 1.8, P.SLATE, 0.4, true, P.BRICK)
	g.tier = 1
	P.door(g, c + Vector3(-1.0, 0.4, -3.01), Vector3(0, 0, -1), 1.2, 2.2)
	P.windows(g, c + Vector3(0.4, 2.2, -3.01), c + Vector3(3.6, 2.2, -3.01), Vector3(0, 0, -1), 2, 1.0, 1.3)
	P.windows(g, c + Vector3(-3.6, 2.2, 3.01), c + Vector3(3.6, 2.2, 3.01), Vector3(0, 0, 1), 4, 1.0, 1.3)
	b.life.append({"type": "smoke", "at": P.chimney(g, c + Vector3(2.8, 0, 1.0), 4.2, 6.6)})
	# the mast: a tapering lattice with stays and a spinning direction-finder loop on top
	var m := Vector3(4.6, 0, 4.4)
	var mh := 16.0
	g.tier = 1
	g.tag = "keep"
	for sx: float in [-1.0, 1.0]:
		g.cyl(m + Vector3(sx * 0.6, 0, -0.4), m + Vector3(sx * 0.1, mh, 0), 0.08, 5, P.METAL)
	g.cyl(m + Vector3(0, 0, 0.6), m + Vector3(0, mh, 0.05), 0.08, 5, P.METAL)
	g.tag = ""
	g.tier = 3
	for k in 7:
		var y := 1.0 + float(k) * 2.1
		var w := 0.6 * (1.0 - y / mh) + 0.1
		g.cyl(m + Vector3(-w, y, -w * 0.6), m + Vector3(w, y + 1.0, -w * 0.6), 0.025, 3, P.METAL)
	g.tag = "detail"
	for a: Vector3 in [Vector3(-6, 0, -3), Vector3(3, 0, 3), Vector3(-1, 0, 4)]:
		g.cyl(m + Vector3(0, mh * 0.8, 0), m + a, 0.012, 3, P.WIRE)
	# the aerial wire from the mast to the lab roof
	g.cyl(m + Vector3(0, mh - 0.4, 0), c + Vector3(-3.8, 6.0, 0), 0.015, 3, P.WIRE)
	g.tag = ""
	g.cyl(c + Vector3(-3.8, 5.0, 0), c + Vector3(-3.8, 6.2, 0), 0.05, 4, P.METAL)
	var lg := TrainGeo.new()
	lg.cyl(Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0), 0.04, 4, P.METAL)
	lg.cyl(Vector3(-0.5, 0.5, 0), Vector3(0, 1.0, 0), 0.04, 4, P.METAL)
	lg.cyl(Vector3(0.5, 0.5, 0), Vector3(0, 1.0, 0), 0.04, 4, P.METAL)
	lg.cyl(Vector3(-0.5, 0.5, 0), Vector3(0, 0, 0), 0.04, 4, P.METAL)
	lg.cyl(Vector3(0.5, 0.5, 0), Vector3(0, 0, 0), 0.04, 4, P.METAL)
	var loop := b.part_mesh("Loop", m + Vector3(0, mh, 0), lg)
	b.life.append({"type": "spin", "node": loop, "f": 0.6})
	# the coil pen
	var pen := Vector3(-4.4, 0, -4.8)
	_fence(g, pen + Vector3(-2, 0, -2), pen + Vector3(2, 0, -2), 1.6)
	_fence(g, pen + Vector3(2, 0, -2), pen + Vector3(2, 0, 2), 1.6)
	_fence(g, pen + Vector3(-2, 0, -2), pen + Vector3(-2, 0, 2), 1.6)
	coil(b, pen, 2.8, 0.55)
	g.tier = 3
	g.cyl(pen + Vector3(0, 0.1, 0), c + Vector3(-4.0, 0.5, -1.0), 0.05, 4, P.BLACK)
	g.tier = 1
	P.lamp(b, c + Vector3(-1.0, 3.0, -3.2), 0.0, 8.0)
	b.add_man(c + Vector3(1.4, 0.4, -3.8), PI * 0.8, R.poses()["stand"], 91)
	b.marks["door"] = c + Vector3(-1.0, 0, -4.0)


## The weapons lab, 2x2 tiles: a concrete test bunker with a slit, an earth berm and target boards down
## a short range, and a prototype coil gun on a test stand (barrel wrapped with glowing rings).
static func lab_weapons(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(7.6, 0.03, 7.6), P.EARTH)
	var c := Vector3(3.6, 0, 3.6)
	g.tier = 1
	g.box(c + Vector3(0, 1.5, 0), Vector3(3.0, 1.5, 2.6), P.CONCRETE, Basis(), 0.25)
	g.box(c + Vector3(0, 3.15, 0), Vector3(3.3, 0.18, 2.9), P.CONCRETE_DARK)
	g.tier = 3
	g.box(c + Vector3(0, 2.2, -2.62), Vector3(1.8, 0.16, 0.04), P.BLACK)
	g.box(c + Vector3(0, 3.42, 0), Vector3(3.1, 0.12, 2.7), P.EARTH)
	P.door(g, c + Vector3(-3.01, 0, -1.0), Vector3(-1, 0, 0), 1.0, 2.0, P.IRON)
	g.tier = 1
	P.sandbags(g, c + Vector3(-3.2, 0, 1.0), c + Vector3(-3.2, 0, 2.8), 4)
	# the range: a berm at the far end, three target boards
	g.box(Vector3(-4.8, 0.45, -5.6), Vector3(3.2, 0.45, 1.2), P.EARTH_DARK)
	g.box(Vector3(-4.8, 1.15, -5.7), Vector3(2.7, 0.3, 0.8), P.EARTH_DARK.darkened(0.1))
	g.tier = 3
	for k in 3:
		var at := Vector3(-6.8 + float(k) * 2.0, 0, -3.4)
		g.cyl(at + Vector3(-0.5, 0, 0), at + Vector3(-0.5, 1.6, 0), 0.04, 4, P.TIMBER)
		g.cyl(at + Vector3(0.5, 0, 0), at + Vector3(0.5, 1.6, 0), 0.04, 4, P.TIMBER)
		g.box(at + Vector3(0, 1.4, 0), Vector3(0.6, 0.6, 0.03), P.CREAM)
		g.box(at + Vector3(0, 1.4, -0.03), Vector3(0.18, 0.18, 0.01), P.RED)
	# the prototype on its stand, aimed down the range at the berm
	var s := Vector3(0.6, 0, 0.4)
	g.tier = 1
	g.box(s + Vector3(0, 0.5, 0), Vector3(0.9, 0.5, 0.9), P.TIMBER_DARK)
	g.box(s + Vector3(0, 1.1, 0), Vector3(0.6, 0.1, 0.6), P.METAL)
	var gg := TrainGeo.new()
	gg.box(Vector3(0, 0.35, 0), Vector3(0.45, 0.35, 0.7), P.OLIVE.darkened(0.2))
	gg.cyl(Vector3(0, 0.45, 0.6), Vector3(0, 0.45, 4.0), 0.12, 8, P.METAL)
	gg.cyl(Vector3(-0.2, 0.0, -0.4), Vector3(-0.2, 0.0, -1.4), 0.04, 4, P.METAL)
	gg.cyl(Vector3(0.2, 0.0, -0.4), Vector3(0.2, 0.0, -1.4), 0.04, 4, P.METAL)
	var gun := b.part_mesh("Proto", s + Vector3(0, 1.2, 0), gg)
	var rings := TrainGeo.new()
	for k in 5:
		var z := 1.2 + float(k) * 0.6
		rings.cyl(Vector3(0, 0.45, z), Vector3(0, 0.45, z + 0.12), 0.24, 10, P.STRANGE)
	var rn := Node3D.new()
	rn.name = "Rings"
	gun.add_child(rn)
	rings.make(rn, "Mesh", strange_material())
	gun.rotation.y = -2.3
	b.life.append({"type": "call", "fn": func(tt: float, _dt: float) -> void:
		var u := fmod(tt, 4.0) / 4.0
		rn.visible = u < 0.75 or fmod(tt * 12.0, 1.0) < 0.5
		rn.scale = Vector3(1.0 + 0.15 * u, 1.0 + 0.15 * u, 1.0)})
	g.cyl(s + Vector3(0.9, 0.1, 0), c + Vector3(-3.0, 0.4, 0.0), 0.05, 4, P.BLACK)
	coil(b, s + Vector3(1.8, 0, -1.4), 1.8, 0.35)
	g.tier = 1
	P.flagpole(b, c + Vector3(2.6, 3.33, -2.4), 3.0, P.RED)
	P.lamp(b, c + Vector3(-3.2, 2.4, -1.0), 0.0, 7.0)
	b.add_man(s + Vector3(-1.4, 0.0, -0.8), PI * 0.6, R.poses()["kneel"], 101)
	b.marks["door"] = c + Vector3(-3.8, 0, -1.0)


## The rail lab, 3x2 tiles: a big corrugated workshop with a track running in, an open end showing a
## strange bogie on trestles, a travelling crane over the track outside, and a coil on the roof ridge.
static func lab_rail(b: Building) -> void:
	var g := b.g
	P.track(g, Vector3(-12, 0, 3.0), Vector3(12, 0, 3.0))
	g.tier = 0
	g.box(Vector3(3.0, 0.04, 0), Vector3(8.6, 0.04, 6.2), P.CONCRETE_DARK)
	g.tier = 1
	var c := Vector3(3.0, 0, 0)
	# the walls: three closed sides, the +x end open with a high door frame
	g.box(c + Vector3(0, 3.0, -6.0), Vector3(8.4, 3.0, 0.15), P.IRON)
	g.box(c + Vector3(0, 3.0, 6.0), Vector3(8.4, 3.0, 0.15), P.IRON)
	g.box(c + Vector3(8.4, 3.0, 0), Vector3(0.15, 3.0, 6.0), P.IRON)
	g.box(c + Vector3(-8.4, 5.4, 0), Vector3(0.18, 0.6, 6.0), P.IRON)
	for s: float in [-1.0, 1.0]:
		g.box(c + Vector3(-8.4, 2.4, s * 5.2), Vector3(0.18, 2.4, 0.8), P.IRON)
	g.tier = 3
	g.tag = "detail"
	for k in 17:
		var x := -8.0 + float(k)
		for s: float in [-1.0, 1.0]:
			g.box(c + Vector3(x, 3.0, s * 6.17), Vector3(0.04, 3.0, 0.03), P.IRON.darkened(0.15))
	g.tag = ""
	g.tier = 1
	P.windows(g, c + Vector3(-7.0, 4.4, -6.16), c + Vector3(6.0, 4.4, -6.16), Vector3(0, 0, -1), 5, 1.4, 1.0)
	g.tier = 2
	g.gable(c + Vector3(0, 6.0, 0), 8.4, 6.0, 2.4, P.IRON_RUST, 0.4, true, P.IRON)
	g.tier = 3
	g.box(c + Vector3(0, 8.5, 0), Vector3(6.0, 0.25, 0.7), P.WINDOW)
	# the strange bogie on trestles inside the open end
	for x: float in [-2.0, -5.6]:
		for s: float in [-1.0, 1.0]:
			g.box(c + Vector3(x, 0.45, 3.0 + s * 1.0), Vector3(0.15, 0.45, 0.15), P.TIMBER)
	g.box(c + Vector3(-3.8, 1.1, 3.0), Vector3(2.4, 0.2, 1.1), P.METAL)
	for x: float in [-2.4, -5.2]:
		for s: float in [-1.0, 1.0]:
			g.cyl(c + Vector3(x, 0.95, 3.0 + s * 0.85), c + Vector3(x, 0.95, 3.0 + s * 1.05), 0.5, 12, P.STEEL)
	g.tier = 1
	var bog := TrainGeo.new()
	for k in 3:
		bog.cyl(Vector3(-0.9 + float(k) * 0.9, 0, -0.5), Vector3(-0.9 + float(k) * 0.9, 0, 0.5), 0.3, 10, P.STRANGE)
	var bn := b.part("BogieGlow", c + Vector3(-3.8, 1.6, 3.0))
	bog.make(bn, "Mesh", strange_material())
	coil(b, c + Vector3(2.0, 8.6, 0), 1.6, 0.35)
	# the travelling crane over the track outside: two A frames and a beam, a hook trolley on a loop
	var cx := -9.0
	g.tier = 1
	for s: float in [-1.0, 1.0]:
		g.cyl(Vector3(cx + s * 1.8, 0, 0.4), Vector3(cx + s * 1.8, 7.0, 3.0), 0.14, 6, P.OLIVE.darkened(0.3))
		g.cyl(Vector3(cx + s * 1.8, 0, 5.6), Vector3(cx + s * 1.8, 7.0, 3.0), 0.14, 6, P.OLIVE.darkened(0.3))
	g.box(Vector3(cx, 7.1, 3.0), Vector3(2.2, 0.2, 0.2), P.OLIVE.darkened(0.3))
	var hg := TrainGeo.new()
	hg.box(Vector3(0, 0, 0), Vector3(0.35, 0.18, 0.3), P.METAL)
	hg.cyl(Vector3(0, 0, 0), Vector3(0, -3.2, 0), 0.015, 3, P.WIRE)
	hg.box(Vector3(0, -3.3, 0), Vector3(0.12, 0.12, 0.06), P.METAL)
	var hook := b.part_mesh("Trolley", Vector3(cx, 6.8, 3.0), hg)
	b.life.append({"type": "call", "fn": func(tt: float, _dt: float) -> void:
		hook.position.x = cx + sin(tt * 0.35) * 1.6})
	P.lamp(b, c + Vector3(-8.6, 5.0, -4.6), 0.0, 10.0)
	b.add_man(c + Vector3(-7.0, 0.04, 0.6), PI * 0.5, R.poses()["stand"], 111)
	b.marks["rail"] = Vector3(0, 0, 3.0)
	b.marks["door"] = c + Vector3(-9.0, 0, 0)


## The defences lab, 2x2 tiles: a squat concrete blockhouse with a periscope tower, test wall slabs
## (one cracked through), a shell crater in front of them, and a field pylon that glows between two posts.
static func lab_defences(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(7.6, 0.03, 7.6), P.GRAVEL)
	var c := Vector3(-3.2, 0, 3.0)
	g.tier = 1
	g.box(c + Vector3(0, 1.6, 0), Vector3(3.6, 1.6, 3.2), P.CONCRETE, Basis(), 0.3)
	g.box(c + Vector3(0, 3.35, 0), Vector3(3.9, 0.15, 3.5), P.CONCRETE_DARK)
	g.box(c + Vector3(1.8, 4.6, 1.2), Vector3(0.8, 1.2, 0.8), P.CONCRETE)
	g.tier = 3
	g.box(c + Vector3(1.8, 5.0, 0.38), Vector3(0.6, 0.1, 0.03), P.BLACK)
	g.cyl(c + Vector3(1.6, 5.8, 1.2), c + Vector3(1.6, 6.8, 1.2), 0.07, 6, P.METAL)
	g.box(c + Vector3(1.6, 6.85, 1.1), Vector3(0.08, 0.08, 0.15), P.METAL)
	for k in 3:
		g.box(c + Vector3(-2.4 + float(k) * 1.6, 2.2, -3.22), Vector3(0.45, 0.12, 0.03), P.BLACK)
	P.door(g, c + Vector3(3.61, 0, 1.6), Vector3(1, 0, 0), 1.0, 2.0, P.IRON)
	g.tier = 1
	# test walls: three slabs of concrete, timber and plate, the middle one cracked through
	for k in 3:
		var at := Vector3(-3.6 + float(k) * 3.0, 0, -4.6)
		var col: Color = [P.CONCRETE, P.TIMBER, P.STEEL][k]
		if k == 1:
			g.box(at + Vector3(-0.7, 1.1, 0), Vector3(0.55, 1.1, 0.25), col, Basis(Vector3.FORWARD, 0.06))
			g.box(at + Vector3(0.75, 0.8, 0), Vector3(0.5, 0.8, 0.25), col, Basis(Vector3.FORWARD, -0.12))
		else:
			g.box(at + Vector3(0, 1.2, 0), Vector3(1.2, 1.2, 0.25), col)
		g.tier = 3
		g.box(at + Vector3(0.2, 1.3, -0.27), Vector3(0.3, 0.3, 0.02), Color(0.1, 0.09, 0.08))
		g.tier = 1
	g.tier = 3
	g.lump(Vector3(-0.6, 0.0, -6.6), 1.0, P.EARTH_DARK, Vector3(1.6, 0.25, 1.2))
	for k in 6:
		g.lump(Vector3(-2.0 + float(k) * 0.6, 0.1, -6.0 + BGeo._h(k, 3) * 1.2), 0.25, P.CONCRETE_DARK)
	# the pylon: two posts with a glowing sheet between that flickers
	var py := Vector3(4.4, 0, -1.0)
	for s: float in [-1.0, 1.0]:
		g.cyl(py + Vector3(0, 0, s * 1.6), py + Vector3(0, 3.6, s * 1.6), 0.15, 8, P.METAL)
		g.cyl(py + Vector3(0, 3.6, s * 1.6), py + Vector3(0, 3.8, s * 1.6), 0.3, 8, P.WHITE)
	var sg := TrainGeo.new()
	sg.box(Vector3.ZERO, Vector3(0.02, 1.5, 1.45), P.STRANGE)
	var sheet := b.part("Field", py + Vector3(0, 1.9, 0))
	var sm := strange_material().duplicate() as StandardMaterial3D
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 1, 1, 0.35)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sg.make(sheet, "Mesh", sm)
	b.life.append({"type": "call", "fn": func(tt: float, _dt: float) -> void:
		sm.albedo_color.a = 0.22 + 0.15 * absf(sin(tt * 2.3)) + 0.08 * sin(tt * 19.0)})
	coil(b, py + Vector3(-1.0, 0, 2.6), 1.6, 0.3)
	g.tier = 1
	P.lamp(b, c + Vector3(3.8, 2.6, 1.6), 0.0, 8.0)
	b.add_man(Vector3(0.0, 0.0, -2.6), PI, R.poses()["stand"], 121)
	b.marks["door"] = c + Vector3(4.4, 0, 1.6)


## The wreck yard, 3x3 tiles: a fenced yard where enemy walkers are cut up: a gantry crane on rails
## across the yard with a hook trolley, a walker hull on blocks, loose legs and plates in heaps, a
## cutting shed, torches that spark, and a coil test rig for the strange parts.
static func wreck_yard(b: Building) -> void:
	var g := b.g
	g.tier = 0
	g.box(Vector3(0, 0.03, 0), Vector3(11.6, 0.03, 11.6), P.EARTH_DARK)
	for k in 9:
		g.lump(Vector3(-10 + BGeo._h(k, 1) * 20.0, 0.0, -10 + BGeo._h(k, 2) * 20.0), 0.6, Color(0.24, 0.2, 0.16),
			Vector3(2.0, 0.1, 1.4))
	# the fence, gate gap on the south side
	_fence(g, Vector3(-11.5, 0, -11.5), Vector3(-3, 0, -11.5))
	_fence(g, Vector3(3, 0, -11.5), Vector3(11.5, 0, -11.5))
	_fence(g, Vector3(11.5, 0, -11.5), Vector3(11.5, 0, 11.5))
	_fence(g, Vector3(11.5, 0, 11.5), Vector3(-11.5, 0, 11.5))
	_fence(g, Vector3(-11.5, 0, 11.5), Vector3(-11.5, 0, -11.5))
	# the gantry: two rails along x, two legs per side, a beam across z, a trolley that runs along it
	g.tier = 1
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(0, 0.12, s * 7.5), Vector3(10.5, 0.12, 0.25), P.METAL)
	var gn := b.part("Gantry", Vector3(0, 0, 0))
	var gg := TrainGeo.new()
	for s: float in [-1.0, 1.0]:
		gg.cyl(Vector3(-0.8, 0.3, s * 7.5), Vector3(0, 8.5, s * 7.5), 0.18, 6, P.OLIVE.darkened(0.3))
		gg.cyl(Vector3(0.8, 0.3, s * 7.5), Vector3(0, 8.5, s * 7.5), 0.18, 6, P.OLIVE.darkened(0.3))
		gg.box(Vector3(0, 0.3, s * 7.5), Vector3(1.0, 0.18, 0.35), P.METAL)
	gg.box(Vector3(0, 8.7, 0), Vector3(0.35, 0.35, 8.0), P.OLIVE.darkened(0.3))
	gg.make(gn, "Mesh", P.material())
	var tg := TrainGeo.new()
	tg.box(Vector3(0, 0, 0), Vector3(0.6, 0.3, 0.5), P.METAL)
	tg.cyl(Vector3(0, 0, 0), Vector3(0, -4.0, 0), 0.02, 3, P.WIRE)
	tg.box(Vector3(0, -4.1, 0), Vector3(0.15, 0.15, 0.08), P.METAL)
	var tn := Node3D.new()
	tn.position = Vector3(0, 8.2, 0)
	gn.add_child(tn)
	tg.make(tn, "Mesh", P.material())
	b.life.append({"type": "call", "fn": func(tt: float, _dt: float) -> void:
		gn.position.x = sin(tt * 0.12) * 4.0 - 1.0
		tn.position.z = sin(tt * 0.31) * 4.5})
	# a walker hull on blocks: a squashed drum body, a cab, a broken leg still on
	var h := Vector3(-3.0, 0, 1.0)
	g.tier = 1
	for s: float in [-1.0, 1.0]:
		g.box(h + Vector3(s * 1.4, 0.4, 0), Vector3(0.4, 0.4, 1.2), P.TIMBER)
	g.cyl(h + Vector3(0, 2.0, -2.0), h + Vector3(0, 2.0, 2.0), 1.6, 10, Color(0.34, 0.32, 0.30), 1.3)
	g.box(h + Vector3(0, 3.6, 0.6), Vector3(1.0, 0.6, 0.9), Color(0.3, 0.28, 0.27), Basis(Vector3.RIGHT, 0.2))
	g.tier = 3
	for k in 6:
		g.cyl(h + Vector3(-1.6, 1.1 + float(k) * 0.32, -2.0), h + Vector3(-1.6, 1.1 + float(k) * 0.32, 2.0), 0.03, 4, P.IRON_RUST)
	g.box(h + Vector3(1.3, 2.2, -0.4), Vector3(0.05, 0.5, 0.6), Color(0.08, 0.07, 0.06))
	g.cyl(h + Vector3(1.6, 1.4, 1.2), h + Vector3(3.4, 0.2, 2.4), 0.25, 6, P.IRON_RUST)
	g.cyl(h + Vector3(3.4, 0.2, 2.4), h + Vector3(4.6, 0.25, 0.6), 0.2, 6, P.IRON_RUST)
	# heaps of legs and plates
	for k in 3:
		var at := Vector3([5.0, 7.0, -7.4][k], 0, [-4.0, 4.0, -5.6][k])
		for j in 6:
			var r := BGeo._h(k * 10 + j, 5)
			var bb := Basis(Vector3.UP, r * TAU) * Basis(Vector3.RIGHT, (BGeo._h(k * 10 + j, 6) - 0.5) * 0.8)
			g.box(at + Vector3((r - 0.5) * 2.0, 0.2 + float(j) * 0.12, (BGeo._h(k * 10 + j, 7) - 0.5) * 2.0),
				Vector3(0.9, 0.05, 0.6), P.IRON_RUST.darkened(r * 0.3), bb)
		g.cyl(at + Vector3(-1.4, 0.3, 0), at + Vector3(1.6, 0.9, 0.6), 0.22, 6, P.IRON.darkened(0.2))
		g.lump(at + Vector3(0.4, 0.4, -0.6), 0.5, P.IRON_RUST)
	# the cutting shed: open front, lean-to roof
	var s0 := Vector3(6.6, 0, -8.4)
	g.tier = 1
	g.box(s0 + Vector3(0, 1.6, 1.6), Vector3(3.0, 1.6, 0.1), P.IRON)
	for s: float in [-1.0, 1.0]:
		g.box(s0 + Vector3(s * 3.0, 1.6, 0), Vector3(0.1, 1.6, 1.6), P.IRON)
	g.tier = 2
	g.lean(s0 + Vector3(0, 3.4, 0), 3.0, 1.6, 0.5, P.IRON_RUST)
	g.tier = 3
	g.box(s0 + Vector3(0, 0.45, 0.8), Vector3(1.6, 0.45, 0.5), P.TIMBER_DARK)
	for k in 3:
		g.cyl(s0 + Vector3(-2.4 + float(k) * 0.5, 0, 1.1), s0 + Vector3(-2.4 + float(k) * 0.5, 1.3, 1.1), 0.18, 8,
			[P.RED, P.OLIVE, P.RED][k])
	g.tier = 1
	torch(b, h + Vector3(1.8, 1.6, -0.6))
	torch(b, s0 + Vector3(0.6, 1.1, 0.3))
	b.add_man(h + Vector3(2.4, 0.0, -0.6), -PI * 0.5, R.poses()["kneel"], 131)
	b.add_man(s0 + Vector3(0.6, 0.0, -0.6), 0.0, R.poses()["stand"], 132)
	b.add_man(Vector3(1.5, 0.0, -10.5), PI, R.poses()["stand"], 133)
	coil(b, Vector3(7.6, 0, 8.6), 2.0, 0.4)
	for at: Vector3 in [Vector3(-3.4, 0, -11.2), Vector3(3.4, 0, -11.2), Vector3(-10.8, 0, 10.8), Vector3(10.8, 0, 10.8)]:
		P.lamp(b, at + Vector3(0, 4.0, 0), 4.0, 12.0)
	b.marks["entry"] = Vector3(0, 0, -12.0)
	b.marks["drop"] = h
