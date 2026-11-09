class_name TrainParts
extends RefCounted
## Iron Front: builds the train cars in code, in the rifleman's low-poly style.
## - engine: a WW1 0-6-0 tender engine (three coupled driving axles, outside cylinders, rods);
## - tender: three axles, water tank and coal;
## - van: stand-in covered van with sliding doors both sides (the real wagons replace it later);
## - gunflat: stand-in flat wagon with low armour sides and a gun mount that turns, lifts and recoils.
## Every car has a near look (the parts) and a far look (a few boxes), split at TrainCar.NEAR_END.

const BODY := Color(0.28, 0.34, 0.29)
const BODY_LIGHT := Color(0.36, 0.42, 0.36)
const BLACK := Color(0.09, 0.09, 0.10)
const SMOKEBOX := Color(0.13, 0.13, 0.14)
const RED := Color(0.58, 0.14, 0.10)
const BRASS := Color(0.66, 0.52, 0.28)
const STEEL := Color(0.40, 0.40, 0.42)
const ROD := Color(0.58, 0.58, 0.60)
const WHEEL := Color(0.13, 0.13, 0.14)
const SPOKE := Color(0.27, 0.31, 0.27)
const GLASS := Color(0.06, 0.08, 0.10)
const COAL := Color(0.07, 0.07, 0.08)
const LAMP := Color(0.90, 0.88, 0.80)
const WOOD := Color(0.47, 0.31, 0.18)
const WOOD_LIGHT := Color(0.55, 0.38, 0.23)
const WOOD_DARK := Color(0.33, 0.21, 0.12)
const ROOF := Color(0.52, 0.52, 0.49)
const OLIVE := Color(0.36, 0.40, 0.24)
const OLIVE_DARK := Color(0.28, 0.32, 0.19)
const SANDBAG := Color(0.62, 0.56, 0.40)
const RUST := Color(0.40, 0.24, 0.15)
const BALLAST := Color(0.48, 0.46, 0.42)
const SLEEPER := Color(0.30, 0.22, 0.15)
const RAIL := Color(0.36, 0.33, 0.31)

const GAUGE_X := 0.72            # wheel centre line (x)
const BUF_X := 0.88
const BUF_Y := 1.05

static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.8
		_mat.metallic_specular = 0.35
	return _mat


static func make(kind: String) -> TrainCar:
	var car := TrainCar.new()
	car.kind = kind
	car.name = kind.capitalize()
	car.body = Node3D.new()
	car.body.name = "Body"
	car.add_child(car.body)
	match kind:
		"engine":
			_engine(car)
		"tender":
			_tender(car)
		"van":
			_van(car)
		"gunflat":
			_gunflat(car)
	car.finish_lod()
	return car


# ------------------------------------------------------------------ shared bits

static func _wheelset(car: TrainCar, z: float, r: float, driver: bool) -> void:
	var n := Node3D.new()
	n.name = "Wheels%d" % car.wheels.size()
	n.position = Vector3(0, r, z)
	car.body.get_parent().add_child(n)
	var g := TrainGeo.new()
	var sides := 16 if driver else 12
	g.cyl(Vector3(-GAUGE_X + 0.06, 0, 0), Vector3(GAUGE_X - 0.06, 0, 0), 0.08, 6, STEEL)
	for s: float in [-1.0, 1.0]:
		var x0 := s * (GAUGE_X - 0.06)
		var x1 := s * (GAUGE_X + 0.06)
		g.cyl(Vector3(x0 - s * 0.03, 0, 0), Vector3(x0, 0, 0), r + 0.035, sides, STEEL)       # flange
		g.cyl(Vector3(x0, 0, 0), Vector3(x1, 0, 0), r, sides, WHEEL)
		g.cyl(Vector3(x1, 0, 0), Vector3(x1 + s * 0.04, 0, 0), r * 0.2, 8, STEEL)          # hub
		var spokes := 3 if driver else 2
		for k in spokes:
			var a := PI * float(k) / float(spokes)
			var d := Vector3(0, sin(a), cos(a))
			var b := Basis(Vector3(1, 0, 0), d.cross(Vector3(1, 0, 0)).normalized(), d)
			g.box(Vector3(x1 + s * 0.012, 0, 0), Vector3(0.012, 0.045 if driver else 0.035, r * 0.86), SPOKE, b)
		if driver:
			# counterweight opposite the crank, and the crank pin
			g.box(Vector3(x1 + s * 0.015, 0, -car.crank * 1.25), Vector3(0.02, r * 0.42, r * 0.2), SPOKE)
			g.cyl(Vector3(x1, 0, car.crank), Vector3(s * 0.99, 0, car.crank), 0.055, 6, ROD)
	var mi := g.make(n, "Mesh", material())
	mi.name = "Mesh"
	if driver:
		car.drivers.append(car.wheels.size())
	car.wheels.append(n)
	car.wheel_r.append(r)


static func _buffers(car: TrainCar, g: TrainGeo, beam_f: float, beam_r: float) -> void:
	# housings on the beams, heads as moving nodes
	for e: float in [-1.0, 1.0]:
		var beam := beam_f if e < 0.0 else beam_r
		var face := car.front_z if e < 0.0 else car.rear_z
		for s: float in [-1.0, 1.0]:
			var a := Vector3(s * BUF_X, BUF_Y, beam)
			var b := Vector3(s * BUF_X, BUF_Y, beam + e * 0.22)
			g.cyl(a, b, 0.11, 8, BLACK)
			var head := Node3D.new()
			head.name = "Buffer%s%s" % ["F" if e < 0.0 else "R", "L" if s < 0.0 else "R"]
			head.position = Vector3(s * BUF_X, BUF_Y, face)
			car.add_child(head)
			var hg := TrainGeo.new()
			hg.cyl(Vector3(0, 0, 0), Vector3(0, 0, -e * 0.06), 0.2, 10, STEEL)
			hg.cyl(Vector3(0, 0, -e * 0.06), Vector3(0, 0, -e * 0.42), 0.06, 6, STEEL)
			hg.make(head, "Mesh", material())
			car.buffers.append(head)
		# coupling hook
		g.box(Vector3(0, BUF_Y, face - e * 0.12), Vector3(0.06, 0.08, 0.12), BLACK)
	# order: front left, front right, rear left, rear right
	car.buffers = [car.buffers[0], car.buffers[1], car.buffers[2], car.buffers[3]]


static func _wagon_frame(car: TrainCar, g: TrainGeo, beam: float, axles: Array, deck_y: float) -> void:
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 1.26, deck_y - 0.16, 0), Vector3(0.05, 0.15, beam), BLACK)                  # solebar
		for z: float in axles:
			g.box(Vector3(s * 0.98, 0.62, z), Vector3(0.04, 0.3, 0.42), BLACK)                       # axle guard
			g.box(Vector3(s * 0.98, 0.52, z), Vector3(0.09, 0.1, 0.13), STEEL)                       # axle box
			g.box(Vector3(s * 0.98, 0.78, z), Vector3(0.06, 0.04, 0.55), BLACK)                      # spring
	for e: float in [-1.0, 1.0]:
		g.box(Vector3(0, BUF_Y, e * beam), Vector3(1.3, 0.19, 0.07), WOOD_DARK)                      # headstock


static func _far_box(fg: TrainGeo, c: Vector3, h: Vector3, color: Color) -> void:
	fg.box(c, h, color)


# ------------------------------------------------------------------ engine

static func _engine(car: TrainCar) -> void:
	car.front_z = -4.95
	car.rear_z = 4.5
	car.pivot_f = -2.4
	car.pivot_r = 2.4
	car.mass = 55000.0
	car.col_box = AABB(Vector3(-1.4, 0.0, -4.95), Vector3(2.8, 4.1, 9.45))
	car.com_y = 1.7
	car.crank = 0.3
	car.conn_len = 2.6
	car.cyl_y = 0.72
	var r := 0.72
	for z: float in [-1.9, 0.0, 1.9]:
		_wheelset(car, z, r, true)

	var m := material()
	# frame, running boards, cab floor, rear beam and buffers
	var g := TrainGeo.new()
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 0.58, 0.98, -0.2), Vector3(0.03, 0.5, 4.3), BLACK)
		g.box(Vector3(s * 0.98, 1.54, -1.3), Vector3(0.4, 0.04, 3.2), BODY)
		g.box(Vector3(s * 1.36, 1.44, -1.3), Vector3(0.02, 0.1, 3.2), BODY_LIGHT)
		# splashers over the driving wheels
		for z: float in [-1.9, 0.0, 1.9]:
			g.box(Vector3(s * 0.74, 1.62, z), Vector3(0.08, 0.06, 0.72), BODY, Basis(), 0.0)
		# slide bars
		g.box(Vector3(s * 1.03, 0.72 + 0.15, -2.6), Vector3(0.025, 0.02, 0.45), STEEL)
		g.box(Vector3(s * 1.03, 0.72 - 0.15, -2.6), Vector3(0.025, 0.02, 0.45), STEEL)
		# sand boxes
		g.box(Vector3(s * 0.95, 1.78, -0.95), Vector3(0.18, 0.22, 0.3), BODY, Basis(), 0.06)
	g.box(Vector3(0, 1.54, 3.0), Vector3(1.35, 0.04, 1.1), BODY)
	g.box(Vector3(0, BUF_Y, 4.08), Vector3(1.3, 0.25, 0.08), RED)
	_buffers(car, g, -4.5, 4.12)
	var frame := g.make(car.body, "Frame", m)

	# front beam with lamps
	var fb := TrainGeo.new()
	fb.box(Vector3(0, BUF_Y, -4.5), Vector3(1.35, 0.27, 0.09), RED)
	for x: float in [-0.5, 0.5]:
		fb.box(Vector3(x, 1.48, -4.48), Vector3(0.11, 0.15, 0.1), LAMP)
		fb.box(Vector3(x, 1.48, -4.59), Vector3(0.07, 0.08, 0.01), BRASS)
	fb.make(car.body, "FrontBeam", m)

	# cylinders
	var cg := TrainGeo.new()
	for s: float in [-1.0, 1.0]:
		cg.cyl(Vector3(s * 1.03, 0.72, -4.05), Vector3(s * 1.03, 0.72, -3.05), 0.3, 10, BODY)
		cg.cyl(Vector3(s * 1.03, 0.72, -4.1), Vector3(s * 1.03, 0.72, -4.02), 0.32, 10, STEEL)
		cg.cyl(Vector3(s * 1.03, 0.72, -3.08), Vector3(s * 1.03, 0.72, -3.0), 0.32, 10, STEEL)
		cg.box(Vector3(s * 0.82, 1.05, -3.55), Vector3(0.2, 0.33, 0.45), BODY)         # steam chest
	cg.make(car.body, "Cylinders", m)

	# smokebox and door
	var sb := TrainGeo.new()
	sb.cyl(Vector3(0, 2.4, -4.2), Vector3(0, 2.4, -2.9), 0.86, 14, SMOKEBOX)
	sb.cyl(Vector3(0, 2.4, -4.26), Vector3(0, 2.4, -4.2), 0.74, 14, BLACK)
	sb.cyl(Vector3(0, 2.4, -4.32), Vector3(0, 2.4, -4.26), 0.12, 6, STEEL)
	sb.box(Vector3(0, 1.62, -3.6), Vector3(0.75, 0.12, 0.65), SMOKEBOX)              # saddle
	sb.make(car.body, "Smokebox", m)

	var ch := TrainGeo.new()
	ch.cyl(Vector3(0, 3.1, -3.55), Vector3(0, 3.95, -3.55), 0.24, 10, SMOKEBOX, 0.26)
	ch.cyl(Vector3(0, 3.95, -3.55), Vector3(0, 4.1, -3.55), 0.31, 10, BLACK)
	ch.make(car.body, "Chimney", m)
	car.marks["chimney"] = Vector3(0, 4.15, -3.55)

	# boiler with bands and hand rails
	var bo := TrainGeo.new()
	bo.cyl(Vector3(0, 2.4, -2.9), Vector3(0, 2.4, 1.95), 0.8, 14, BODY)
	for z: float in [-1.6, -0.2, 1.2]:
		bo.cyl(Vector3(0, 2.4, z - 0.04), Vector3(0, 2.4, z + 0.04), 0.82, 14, BLACK)
	for s: float in [-1.0, 1.0]:
		bo.box(Vector3(s * 0.88, 2.62, -1.1), Vector3(0.02, 0.02, 2.9), BRASS)
	bo.box(Vector3(0, 1.75, 0.0), Vector3(0.62, 0.22, 1.9), BODY)                     # lower boiler cladding
	bo.make(car.body, "Boiler", m)

	var dm := TrainGeo.new()
	dm.dome(Vector3(0, 3.05, -0.55), 0.44, 0.5, 12, BODY)
	dm.cyl(Vector3(0, 3.05, 1.35), Vector3(0, 3.35, 1.35), 0.12, 8, BRASS)            # safety valves
	dm.make(car.body, "Dome", m)

	# cab: front plate with spectacle windows, sides, posts, arched roof
	var cb := TrainGeo.new()
	cb.box(Vector3(0, 2.6, 1.97), Vector3(1.36, 1.04, 0.03), BODY)
	for x: float in [-0.78, 0.78]:
		cb.box(Vector3(x, 3.2, 1.935), Vector3(0.24, 0.2, 0.01), GLASS)
		cb.box(Vector3(x, 3.2, 1.925), Vector3(0.27, 0.23, 0.005), BRASS)
	for s: float in [-1.0, 1.0]:
		cb.box(Vector3(s * 1.34, 2.15, 3.02), Vector3(0.03, 0.6, 1.05), BODY)
		cb.box(Vector3(s * 1.34, 2.78, 3.02), Vector3(0.05, 0.04, 1.08), BODY_LIGHT)
		cb.box(Vector3(s * 1.34, 3.2, 2.1), Vector3(0.03, 0.42, 0.13), BODY)
		cb.box(Vector3(s * 1.34, 3.2, 3.95), Vector3(0.03, 0.42, 0.1), BODY)
		cb.box(Vector3(s * 1.30, 2.95, 3.2), Vector3(0.01, 0.2, 0.4), GLASS)           # side window glimpse
	var roof := PackedVector2Array()
	var arc := 7
	for i in arc:
		var t := float(i) / float(arc - 1)
		var x := lerpf(-1.48, 1.48, t)
		roof.append(Vector2(x, 3.62 + 0.26 * (1.0 - pow(2.0 * t - 1.0, 2.0)) + 0.06))
	for i in arc:
		var t := 1.0 - float(i) / float(arc - 1)
		var x := lerpf(-1.48, 1.48, t)
		roof.append(Vector2(x, 3.62 + 0.26 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
	roof.reverse()
	cb.extrude(roof, Vector3(0, 0, 1.85), Vector3(0, 0, 4.2), SMOKEBOX, Basis(), 3, BODY_LIGHT)
	cb.cyl(Vector3(0, 3.62, 1.75), Vector3(0, 3.92, 1.75), 0.05, 6, BRASS)            # whistle
	cb.box(Vector3(0, 2.1, 2.3), Vector3(0.7, 0.5, 0.3), BLACK)                      # backhead / firebox door
	cb.box(Vector3(0, 2.25, 2.04), Vector3(0.22, 0.16, 0.02), Color(0.95, 0.55, 0.2))  # firehole glow
	cb.make(car.body, "Cab", m)
	car.marks["whistle"] = Vector3(0, 3.95, 1.75)
	car.marks["cock_l"] = Vector3(-1.03, 0.42, -3.95)
	car.marks["cock_r"] = Vector3(1.03, 0.42, -3.95)
	car.marks["fire"] = Vector3(0, 2.6, -0.5)
	car.marks["blast"] = Vector3(0, 2.4, -0.3)

	# rods: per side, coupling rod (all three drivers), connecting rod, crosshead and piston rod
	for s: int in [1, -1]:
		var set_ := {}
		var cr := Node3D.new()
		cr.name = "CouplingRod%s" % ("R" if s > 0 else "L")
		cr.position = Vector3(s * 0.95, r, 0)
		car.add_child(cr)
		var rg := TrainGeo.new()
		rg.box(Vector3(0, 0, 0), Vector3(0.03, 0.065, 2.0), ROD)
		for z: float in [-1.9, 0.0, 1.9]:
			rg.cyl(Vector3(-0.035, 0, z), Vector3(0.035, 0, z), 0.1, 8, ROD)
		rg.make(cr, "Mesh", m)
		set_["coupling"] = cr
		var cn := Node3D.new()
		cn.name = "ConnRod%s" % ("R" if s > 0 else "L")
		cn.position = Vector3(s * 1.03, car.cyl_y, -2.6)
		car.add_child(cn)
		var ng := TrainGeo.new()
		ng.box(Vector3(0, 0, car.conn_len * 0.5), Vector3(0.03, 0.07, car.conn_len * 0.5), ROD)
		ng.cyl(Vector3(-0.04, 0, car.conn_len), Vector3(0.04, 0, car.conn_len), 0.13, 8, ROD)
		ng.make(cn, "Mesh", m)
		set_["conn"] = cn
		var xh := Node3D.new()
		xh.name = "Crosshead%s" % ("R" if s > 0 else "L")
		xh.position = Vector3(s * 1.03, car.cyl_y, -2.6)
		car.add_child(xh)
		var xg := TrainGeo.new()
		xg.box(Vector3(0, 0, 0), Vector3(0.06, 0.12, 0.13), STEEL)
		xg.make(xh, "Mesh", m)
		set_["cross"] = xh
		var pr := Node3D.new()
		pr.name = "PistonRod%s" % ("R" if s > 0 else "L")
		pr.position = Vector3(s * 1.03, car.cyl_y, -2.6)
		car.add_child(pr)
		var pg := TrainGeo.new()
		pg.cyl(Vector3(0, 0, 0), Vector3(0, 0, -1.2), 0.045, 6, ROD)
		pg.make(pr, "Mesh", m)
		set_["piston"] = pr
		car.rods[s] = set_
	car.roll(0.0)

	# far look
	var fg := TrainGeo.new()
	fg.box(Vector3(0, 0.75, -0.2), Vector3(0.9, 0.7, 4.4), BLACK)
	fg.cyl(Vector3(0, 2.4, -4.2), Vector3(0, 2.4, 1.95), 0.82, 6, BODY)
	fg.box(Vector3(0, 2.75, 3.0), Vector3(1.38, 1.15, 1.15), BODY)
	fg.box(Vector3(0, 3.6, -3.55), Vector3(0.25, 0.5, 0.25), BLACK)
	fg.box(Vector3(0, BUF_Y, -4.6), Vector3(1.35, 0.25, 0.1), RED)
	car.far = fg.make(car, "Far", m)


# ------------------------------------------------------------------ tender

static func _tender(car: TrainCar) -> void:
	car.front_z = -3.4
	car.rear_z = 3.4
	car.pivot_f = -1.9
	car.pivot_r = 1.9
	car.mass = 35000.0
	car.col_box = AABB(Vector3(-1.4, 0.0, -3.4), Vector3(2.8, 3.3, 6.8))
	car.com_y = 1.4
	for z: float in [-1.9, 0.0, 1.9]:
		_wheelset(car, z, 0.5, false)
	var m := material()
	var g := TrainGeo.new()
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 0.98, 0.78, 0), Vector3(0.03, 0.42, 2.95), BLACK)
		for z: float in [-1.9, 0.0, 1.9]:
			g.box(Vector3(s * 1.03, 0.55, z), Vector3(0.08, 0.12, 0.15), STEEL)
			g.box(Vector3(s * 1.03, 0.82, z), Vector3(0.06, 0.05, 0.5), BLACK)
	for e: float in [-1.0, 1.0]:
		g.box(Vector3(0, BUF_Y, e * 2.98), Vector3(1.3, 0.24, 0.07), RED)
	g.box(Vector3(0, 1.24, 0), Vector3(1.32, 0.04, 2.95), BLACK)
	_buffers(car, g, -2.98, 2.98)
	g.make(car.body, "Frame", m)

	var t := TrainGeo.new()
	t.box(Vector3(0, 2.0, 0.08), Vector3(1.32, 0.76, 2.82), BODY, Basis(), 0.12)
	t.box(Vector3(0, 2.86, 0.08), Vector3(1.42, 0.1, 2.86), BODY_LIGHT)
	t.box(Vector3(0, 1.72, 0.08), Vector3(1.335, 0.04, 2.83), BLACK)
	t.cyl(Vector3(0, 2.96, 2.25), Vector3(0, 3.15, 2.25), 0.28, 8, BLACK)            # water filler
	t.box(Vector3(0, 3.05, 2.75), Vector3(0.7, 0.12, 0.18), BODY)                   # tool box
	t.box(Vector3(0, 2.4, -2.78), Vector3(1.0, 0.35, 0.06), BODY_LIGHT)             # coal plate
	t.make(car.body, "Tank", m)

	var c := TrainGeo.new()
	var lumps := [[-0.7, -1.9, 0.62], [0.65, -2.0, 0.6], [0.0, -1.2, 0.7], [-0.6, -0.3, 0.6], [0.6, -0.2, 0.62],
		[0.0, 0.6, 0.66], [-0.65, 1.2, 0.5], [0.6, 1.25, 0.52], [0.0, -2.35, 0.5]]
	for l: Array in lumps:
		c.lump(Vector3(l[0], 2.98, l[1]), l[2], COAL, Vector3(1.0, 0.45, 1.0))
	c.make(car.body, "Coal", m)
	car.marks["fire"] = Vector3(0, 2.9, -1.0)

	var fg := TrainGeo.new()
	fg.box(Vector3(0, 0.6, 0), Vector3(1.0, 0.55, 3.0), BLACK)
	fg.box(Vector3(0, 2.0, 0.08), Vector3(1.38, 0.95, 2.86), BODY)
	fg.box(Vector3(0, 3.0, -0.8), Vector3(1.0, 0.15, 1.8), COAL)
	car.far = fg.make(car, "Far", m)


# ------------------------------------------------------------------ van (stand-in)

static func _van(car: TrainCar) -> void:
	car.front_z = -3.45
	car.rear_z = 3.45
	car.pivot_f = -1.9
	car.pivot_r = 1.9
	car.mass = 18000.0
	car.col_box = AABB(Vector3(-1.4, 0.0, -3.45), Vector3(2.8, 3.5, 6.9))
	car.com_y = 1.6
	car.door_open_z = -1.65
	for z: float in [-1.9, 1.9]:
		_wheelset(car, z, 0.48, false)
	var m := material()
	var g := TrainGeo.new()
	_wagon_frame(car, g, 3.0, [-1.9, 1.9], 1.06)
	_buffers(car, g, -3.07, 3.07)
	g.make(car.body, "Frame", m)

	var b := TrainGeo.new()
	b.box(Vector3(0, 2.1, 0), Vector3(1.27, 1.04, 2.95), WOOD)
	# planks: slightly proud lighter bands
	for k in 4:
		var y := 1.3 + float(k) * 0.52
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(s * 1.275, y, 0), Vector3(0.004, 0.11, 2.94), WOOD_LIGHT)
	for s: float in [-1.0, 1.0]:
		for z: float in [-2.92, -0.88, 0.88, 2.92]:
			b.box(Vector3(s * 1.29, 2.1, z), Vector3(0.03, 1.04, 0.07), WOOD_DARK)      # posts
		for zr: Array in [[-2.9, -0.95], [0.95, 2.9]]:
			var p0 := Vector3(s * 1.295, 1.12, zr[0])
			var p1 := Vector3(s * 1.295, 3.08, zr[1])
			var d := (p1 - p0)
			var bz := d.normalized()
			var bb := Basis(Vector3(1, 0, 0), bz.cross(Vector3(1, 0, 0)).normalized(), bz)
			b.box((p0 + p1) * 0.5, Vector3(0.02, 0.06, d.length() * 0.5), WOOD_DARK, bb)
		b.box(Vector3(s * 1.282, 2.06, 0), Vector3(0.004, 0.94, 0.84), GLASS)           # doorway (seen when open)
		b.box(Vector3(s * 1.34, 3.1, -0.85), Vector3(0.02, 0.03, 1.8), BLACK)           # door rail
	for e: float in [-1.0, 1.0]:
		var p0 := Vector3(-1.2, 1.12, e * 2.97)
		var p1 := Vector3(1.2, 3.08, e * 2.97)
		var d := p1 - p0
		var bz := d.normalized()
		var bb := Basis(Vector3(0, 0, 1), bz.cross(Vector3(0, 0, 1)).normalized(), bz)
		b.box((p0 + p1) * 0.5 + Vector3(0, 0, e * 0.02), Vector3(0.02, 0.06, d.length() * 0.5), WOOD_DARK, bb)
	var roof := PackedVector2Array()
	var arc := 7
	for i in arc:
		var t := float(i) / float(arc - 1)
		roof.append(Vector2(lerpf(-1.38, 1.38, t), 3.14 + 0.3 * (1.0 - pow(2.0 * t - 1.0, 2.0)) + 0.06))
	for i in arc:
		var t := 1.0 - float(i) / float(arc - 1)
		roof.append(Vector2(lerpf(-1.38, 1.38, t), 3.14 + 0.3 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
	roof.reverse()
	b.extrude(roof, Vector3(0, 0, -3.05), Vector3(0, 0, 3.05), ROOF)
	b.make(car.body, "Box", m)

	for s: float in [-1.0, 1.0]:
		var d := Node3D.new()
		d.name = "Door%s" % ("R" if s > 0 else "L")
		d.position = Vector3.ZERO
		car.add_child(d)
		var dg := TrainGeo.new()
		dg.box(Vector3(s * 1.315, 2.08, 0), Vector3(0.025, 0.98, 0.84), WOOD_LIGHT)
		dg.box(Vector3(s * 1.345, 2.08, 0), Vector3(0.008, 0.95, 0.06), WOOD_DARK)
		dg.box(Vector3(s * 1.345, 2.08, -0.78), Vector3(0.008, 0.95, 0.05), WOOD_DARK)
		dg.box(Vector3(s * 1.345, 2.08, 0.78), Vector3(0.008, 0.95, 0.05), WOOD_DARK)
		dg.box(Vector3(s * 1.35, 2.05, 0.6), Vector3(0.02, 0.12, 0.03), STEEL)        # handle
		dg.make(d, "Mesh", m)
		car.doors.append(d)
	car.marks["door_l"] = Vector3(-2.2, 0, 0)
	car.marks["door_r"] = Vector3(2.2, 0, 0)
	car.marks["fire"] = Vector3(0, 2.2, 0)

	var fg := TrainGeo.new()
	fg.box(Vector3(0, 0.6, 0), Vector3(1.0, 0.5, 3.0), BLACK)
	fg.box(Vector3(0, 2.1, 0), Vector3(1.3, 1.05, 2.98), WOOD)
	fg.box(Vector3(0, 3.3, 0), Vector3(1.38, 0.15, 3.05), ROOF)
	car.far = fg.make(car, "Far", m)


# ------------------------------------------------------------------ gun flat (stand-in)

static func _gunflat(car: TrainCar) -> void:
	car.front_z = -4.05
	car.rear_z = 4.05
	car.pivot_f = -2.3
	car.pivot_r = 2.3
	car.mass = 22000.0
	car.col_box = AABB(Vector3(-1.4, 0.0, -4.05), Vector3(2.8, 2.5, 8.1))
	car.com_y = 1.2
	for z: float in [-2.3, 2.3]:
		_wheelset(car, z, 0.48, false)
	var m := material()
	var g := TrainGeo.new()
	_wagon_frame(car, g, 3.6, [-2.3, 2.3], 1.06)
	_buffers(car, g, -3.67, 3.67)
	for k in 9:
		var z := -3.4 + float(k) * 0.85
		g.box(Vector3(0, 1.13, z), Vector3(1.34, 0.07, 0.41), WOOD if k % 2 == 0 else WOOD_LIGHT)
	g.make(car.body, "Frame", m)

	var a := TrainGeo.new()
	for s: float in [-1.0, 1.0]:
		a.box(Vector3(s * 1.31, 1.62, 0), Vector3(0.035, 0.42, 3.5), OLIVE, Basis(Vector3(0, 0, 1), s * 0.12))
	for e: float in [-1.0, 1.0]:
		a.box(Vector3(0, 1.6, e * 3.48), Vector3(1.3, 0.4, 0.035), OLIVE)
	for p: Array in [[-0.9, -2.9], [0.9, -2.9], [-0.9, 2.9], [0.9, 2.9], [0.0, 3.0], [-0.95, -2.2], [0.95, 2.2]]:
		a.lump(Vector3(p[0], 1.42, p[1]), 0.32, SANDBAG, Vector3(1.0, 0.55, 0.8))
	for z: float in [2.2, 2.6]:
		a.box(Vector3(0.75, 1.35, z), Vector3(0.22, 0.13, 0.16), OLIVE_DARK)        # ammunition boxes
	a.make(car.body, "Armour", m)

	var mount := Node3D.new()
	mount.name = "GunMount"
	mount.position = Vector3(0, 1.2, 0.2)
	car.add_child(mount)
	var mg := TrainGeo.new()
	mg.cyl(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 0.95, 12, BLACK)
	for s: float in [-1.0, 1.0]:
		mg.box(Vector3(s * 0.3, 0.55, 0.15), Vector3(0.05, 0.43, 0.55), OLIVE)
	var shield_b := Basis(Vector3(1, 0, 0), -0.18)
	mg.box(Vector3(-0.55, 1.0, -0.55), Vector3(0.38, 0.62, 0.025), OLIVE, shield_b)
	mg.box(Vector3(0.55, 1.0, -0.55), Vector3(0.38, 0.62, 0.025), OLIVE, shield_b)
	mg.box(Vector3(0, 1.48, -0.63), Vector3(0.18, 0.14, 0.025), OLIVE, shield_b)
	mg.box(Vector3(0, 0.32, -0.6), Vector3(0.18, 0.2, 0.025), OLIVE, shield_b)
	mg.make(mount, "Mesh", m)
	var cradle := Node3D.new()
	cradle.name = "Cradle"
	cradle.position = Vector3(0, 0.95, 0.0)
	mount.add_child(cradle)
	var cg := TrainGeo.new()
	cg.box(Vector3(0, -0.1, -0.2), Vector3(0.13, 0.09, 0.85), OLIVE_DARK)
	cg.cyl(Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0), 0.07, 6, STEEL)                  # trunnions
	cg.make(cradle, "Mesh", m)
	var barrel := Node3D.new()
	barrel.name = "Barrel"
	cradle.add_child(barrel)
	var bg := TrainGeo.new()
	bg.cyl(Vector3(0, 0.04, 0.55), Vector3(0, 0.04, -2.7), 0.085, 8, OLIVE_DARK, 0.07)
	bg.cyl(Vector3(0, 0.04, -2.7), Vector3(0, 0.04, -2.85), 0.095, 8, BLACK)
	bg.box(Vector3(0, 0.04, 0.72), Vector3(0.14, 0.14, 0.18), STEEL)
	bg.make(barrel, "Mesh", m)
	car.gun_mount = mount
	car.gun_cradle = cradle
	car.gun_barrel = barrel
	car.marks["muzzle"] = Vector3(0, 2.2, -2.7)
	car.marks["fire"] = Vector3(0, 1.6, 0)

	var fg := TrainGeo.new()
	fg.box(Vector3(0, 0.75, 0), Vector3(1.0, 0.6, 3.6), BLACK)
	fg.box(Vector3(0, 1.6, 0), Vector3(1.34, 0.42, 3.5), OLIVE)
	fg.box(Vector3(0, 2.2, -0.6), Vector3(0.55, 0.4, 0.1), OLIVE)
	fg.box(Vector3(0, 2.15, -1.5), Vector3(0.08, 0.08, 1.3), OLIVE_DARK)
	car.far = fg.make(car, "Far", m)


# ------------------------------------------------------------------ track and things on it

## Track along a path from d0 to d1 (metres). broken: [from, to] ranges with torn-up rails and scattered sleepers.
static func track(path: TrackPath, d0: float, d1: float, broken: Array = []) -> MeshInstance3D:
	var g := TrainGeo.new()
	var step := 0.7
	var d := d0
	var k := 0
	while d < d1:
		var gone := false
		for br: Array in broken:
			if d >= br[0] and d <= br[1]:
				gone = true
		var xf := path.frame(d)
		var bs := xf.basis
		var o := xf.origin
		# ballast (trapezoid slab under this step)
		var seg := minf(step, d1 - d)
		var a := o
		var b := path.frame(d + seg).origin
		if not gone:
			var half_top := 1.65
			var half_bot := 2.3
			var r0 := PackedVector3Array([a + bs.x * half_top + Vector3(0, -0.27, 0), a - bs.x * half_top + Vector3(0, -0.27, 0),
				a - bs.x * half_bot + Vector3(0, -0.62, 0), a + bs.x * half_bot + Vector3(0, -0.62, 0)])
			var b1 := path.frame(d + seg).basis
			var r1 := PackedVector3Array([b + b1.x * half_top + Vector3(0, -0.27, 0), b - b1.x * half_top + Vector3(0, -0.27, 0),
				b - b1.x * half_bot + Vector3(0, -0.62, 0), b + b1.x * half_bot + Vector3(0, -0.62, 0)])
			g.prism([r0, r1], BALLAST, 0)
			# sleeper
			g.box(o + Vector3(0, -0.21, 0), Vector3(1.3, 0.07, 0.13), SLEEPER if k % 3 else SLEEPER.darkened(0.12), bs)
			# rails (this step)
			for s: float in [-1.0, 1.0]:
				var ra := a + bs.x * s * 0.7175
				var rb := b + b1.x * s * 0.7175
				var mid := (ra + rb) * 0.5 + Vector3(0, -0.075, 0)
				var rz := (rb - ra)
				var rbas := Basis(rz.normalized().cross(Vector3.UP).normalized() * -1.0, Vector3.UP, rz.normalized())
				g.box(mid, Vector3(0.035, 0.075, rz.length() * 0.5 + 0.01), RAIL, rbas)
		else:
			# torn up: a few skewed, charred sleepers and twisted rail ends lying about
			var h := hash(Vector2i(k, 77))
			if h % 3 != 0:
				var yaw := float(h % 100) / 100.0 - 0.5
				var off := Vector3(float((h / 100) % 100) / 100.0 - 0.5, 0, 0) * 1.6
				g.box(o + bs * off + Vector3(0, -0.55, 0), Vector3(1.3, 0.07, 0.13), SLEEPER.darkened(0.45), bs * Basis(Vector3.UP, yaw))
		k += 1
		d += step
	# bent rail ends either side of each break
	for br: Array in broken:
		for e: float in [-1.0, 1.0]:
			var at: float = br[0] if e < 0.0 else br[1]
			var xf := path.frame(at)
			for s: float in [-1.0, 1.0]:
				var base := xf.origin + xf.basis.x * s * 0.7175 + Vector3(0, -0.07, 0)
				var dir := (xf.basis.z * e + xf.basis.x * s * 0.6 + Vector3(0, 0.5, 0)).normalized()
				var bz := dir
				var bx := Vector3.UP.cross(bz).normalized()
				g.box(base + dir * 0.9, Vector3(0.035, 0.075, 0.9), RAIL.darkened(0.2), Basis(bx, bz.cross(bx), bz))
	var mi := MeshInstance3D.new()
	mi.name = "Track"
	mi.mesh = g.to_mesh(material())
	return mi


## A pit blown in the track bed (seen from above as a dark scorched hollow), centred at a path distance.
static func crater(path: TrackPath, at: float, length_m: float) -> MeshInstance3D:
	var g := TrainGeo.new()
	var xf := path.frame(at)
	var n := 10
	var rim := PackedVector3Array()
	var bottom := PackedVector3Array()
	for i in n:
		var t := TAU * float(i) / float(n)
		var j := 1.0 + 0.12 * sin(t * 3.0 + 1.0)
		var p := xf.origin + xf.basis.z * cos(t) * length_m * 0.5 * j + xf.basis.x * sin(t) * 3.2 * j
		rim.append(p + Vector3(0, -0.58, 0))
		bottom.append(xf.origin + xf.basis.z * cos(t) * length_m * 0.3 + xf.basis.x * sin(t) * 1.8 + Vector3(0, -1.6, 0))
	var lip := PackedVector3Array()
	for i in n:
		var t := TAU * float(i) / float(n)
		lip.append(xf.origin + xf.basis.z * cos(t) * (length_m * 0.5 + 1.2) + xf.basis.x * sin(t) * 4.4 + Vector3(0, -0.35, 0))
	for i in n:
		var i1 := (i + 1) % n
		g.emit(lip[i], rim[i], rim[i1], Color(0.36, 0.30, 0.22))
		g.emit(lip[i], rim[i1], lip[i1], Color(0.36, 0.30, 0.22))
		g.emit(rim[i], bottom[i], bottom[i1], Color(0.18, 0.15, 0.12))
		g.emit(rim[i], bottom[i1], rim[i1], Color(0.18, 0.15, 0.12))
	var c := xf.origin + Vector3(0, -1.6, 0)
	for i in n:
		g.emit(c, bottom[(i + 1) % n], bottom[i], Color(0.12, 0.10, 0.09))
	var mi := MeshInstance3D.new()
	mi.name = "Crater"
	var mesh := g.to_mesh(material())
	mi.mesh = mesh
	# winding may face either way for this hand-made bowl: draw both sides
	var m2: StandardMaterial3D = material().duplicate()
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, m2)
	return mi


## A Czech hedgehog tank trap (three crossed steel beams), standing on the ground at its origin.
static func hedgehog(g: TrainGeo, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(deg_to_rad(35.26), deg_to_rad(45.0), 0.0))
	var low := 0.0
	for ax: Vector3 in [b.x, b.y, b.z]:
		low = minf(low, -absf(ax.y) * 1.0)
	var c := at + Vector3(0, -low, 0)
	for i in 3:
		var ax: Vector3 = [b.x, b.y, b.z][i]
		var bx := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
		g.box(c, Vector3(0.07, 0.07, 1.0), RUST, Basis(bx, ax.cross(bx), ax))


## The block across the line: hedgehogs and a log pile. Returns the mesh; its solid size is BLOCK_SIZE.
static func blockade(at: Vector3, yaw: float) -> MeshInstance3D:
	var g := TrainGeo.new()
	var b := Basis(Vector3.UP, yaw)
	for x: float in [-1.6, 0.0, 1.6]:
		hedgehog(g, at + b * Vector3(x, -0.15, 0.4), yaw + x * 0.5)
	for i in 4:
		var y := -0.05 + float(i % 2) * 0.28 + float(i / 2) * 0.05
		var z := -0.75 - float(i) * 0.0
		var l0 := at + b * Vector3(-2.2, y, z - float(i % 2) * 0.12)
		var l1 := at + b * Vector3(2.2, y + 0.04, z + float(i % 2) * 0.1)
		g.cyl(l0, l1, 0.16, 7, WOOD_DARK if i % 2 else WOOD)
	var mi := MeshInstance3D.new()
	mi.name = "Blockade"
	mi.mesh = g.to_mesh(material())
	return mi
