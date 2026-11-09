class_name AirParts
extends RefCounted
## Iron Front: builds the aircraft in code, in the rifleman's and trains' low-poly style (Asset Builder Chat).
## - fighter: single-seat scout biplane, rotary engine, one synchronised MG on the nose;
## - spotter: two-seat biplane, inline engine with radiator, fixed MG, observer with a ring-mounted MG;
## - bomber: twin-engine biplane bomber, nose and rear gunners on rings, bombs hung under the fuselage.
## Forward is -Z, up is +Y, the origin is at the centre of gravity. Markings are generic (a cream-edged diamond).
##
## Every plane is made of groups (Fuselage, WingL, WingR, Tail, Gear, Nose), so a crash can break them apart.
## Moving parts: propellers (with a blur disc), ailerons (on the wings), elevator and rudder (on the tail),
## wheels, gunner rings and their guns, bombs.

const TOP := Color(0.47, 0.49, 0.31)
const TOP_DARK := Color(0.33, 0.36, 0.22)
const UNDER := Color(0.80, 0.76, 0.62)
const BOMBER_TOP := Color(0.36, 0.39, 0.28)
const BOMBER_UNDER := Color(0.62, 0.60, 0.50)
const WOOD := Color(0.55, 0.34, 0.17)
const WOOD_DARK := Color(0.40, 0.24, 0.12)
const COWL := Color(0.58, 0.58, 0.56)
const METAL := Color(0.22, 0.22, 0.23)
const BLACK := Color(0.09, 0.09, 0.10)
const LEATHER := Color(0.36, 0.22, 0.13)
const SKIN := Color(0.86, 0.66, 0.50)
const CREAM := Color(0.80, 0.76, 0.62)
const MARK := Color(0.20, 0.22, 0.15)
const TYRE := Color(0.12, 0.12, 0.12)
const GLASS := Color(0.55, 0.65, 0.70)
const BOMB := Color(0.30, 0.32, 0.28)
const STRUT := Color(0.50, 0.38, 0.24)

static var _mat: StandardMaterial3D
static var _blur_mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	return TrainParts.material()


static func blur_material() -> StandardMaterial3D:
	if _blur_mat == null:
		_blur_mat = StandardMaterial3D.new()
		_blur_mat.vertex_color_use_as_albedo = true
		_blur_mat.vertex_color_is_srgb = true
		_blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blur_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _blur_mat


## The three planes' sizes and layout.
static func spec(kind: String) -> Dictionary:
	match kind:
		"fighter":
			return {
				"span_u": 8.4, "span_l": 7.8, "chord_u": 1.5, "chord_l": 1.35, "y_u": 1.05, "y_l": -0.45,
				"z_u": -0.45, "z_l": -0.15, "ail": [2.4, 4.1], "struts": [2.9],
				"fus": [[-2.65, 0.40, 0.40, 0.0], [-2.35, 0.47, 0.47, 0.0], [-1.7, 0.45, 0.52, 0.02], [0.4, 0.40, 0.48, 0.05],
					[1.8, 0.27, 0.34, 0.08], [3.45, 0.06, 0.1, 0.15]],
				"nose": "rotary", "prop_r": 1.25, "props": [Vector3(0, 0, -2.9)],
				"tail": [3.05, 2.9, 0.75], "fin": [3.0, 0.75, 0.6], "twin_fin": false,
				"gear": [-0.85, -1.3, 0.75, 0.36, 1], "skid": [3.2, -0.55],
				"seats": [[0.0, "pilot"]], "fixed_mg": [Vector3(0.13, 0.55, -1.0)], "rings": [], "bombs": 0,
				"top": TOP, "under": UNDER, "mass": 650.0, "cruise": 45.0, "stall": 22.0,
			}
		"spotter":
			return {
				"span_u": 12.0, "span_l": 11.2, "chord_u": 1.75, "chord_l": 1.6, "y_u": 1.25, "y_l": -0.55,
				"z_u": -0.6, "z_l": -0.3, "ail": [3.6, 5.8], "struts": [2.6, 5.0],
				"fus": [[-3.4, 0.45, 0.55, 0.05], [-2.9, 0.50, 0.60, 0.05], [-1.8, 0.50, 0.62, 0.05], [1.2, 0.46, 0.55, 0.08],
					[2.8, 0.30, 0.38, 0.12], [4.8, 0.07, 0.11, 0.22]],
				"nose": "inline", "prop_r": 1.4, "props": [Vector3(0, 0.05, -3.6)],
				"tail": [4.35, 3.6, 0.9], "fin": [4.3, 0.95, 0.75], "twin_fin": false,
				"gear": [-1.3, -1.5, 0.85, 0.4, 1], "skid": [4.5, -0.6],
				"seats": [[-0.6, "pilot"], [0.85, "observer"]], "fixed_mg": [Vector3(-0.2, 0.6, -2.0)],
				"rings": [[0.85, 0.62]], "bombs": 0,
				"top": TOP, "under": UNDER, "mass": 1200.0, "cruise": 40.0, "stall": 20.0,
			}
		"bomber":
			return {
				"span_u": 22.0, "span_l": 20.0, "chord_u": 2.6, "chord_l": 2.4, "y_u": 1.9, "y_l": -0.7,
				"z_u": -0.3, "z_l": -0.1, "ail": [7.5, 10.8], "struts": [3.6, 6.8, 9.8],
				"fus": [[-6.0, 0.35, 0.45, -0.05], [-5.6, 0.62, 0.72, 0.0], [-4.2, 0.72, 0.85, 0.0], [0.0, 0.70, 0.85, 0.0],
					[3.5, 0.48, 0.62, 0.1], [7.2, 0.12, 0.2, 0.3]],
				"nose": "glass", "prop_r": 1.6, "props": [Vector3(-3.6, 0.55, -2.95), Vector3(3.6, 0.55, -2.95)],
				"nacelles": [Vector3(-3.6, 0.55, -1.0), Vector3(3.6, 0.55, -1.0)],
				"tail": [6.4, 6.2, 1.3], "fin": [6.3, 1.3, 1.1], "twin_fin": true,
				"gear": [-0.9, -2.05, 3.6, 0.55, 2], "skid": [6.8, -1.15],
				"seats": [[-5.1, "gunner"], [-2.9, "pilot"], [2.4, "gunner"]], "fixed_mg": [],
				"rings": [[-5.1, 0.75], [2.4, 0.72]], "bombs": 10,
				"top": BOMBER_TOP, "under": BOMBER_UNDER, "mass": 4200.0, "cruise": 36.0, "stall": 21.0,
			}
		"transport":
			# three engines (nose and two nacelles), a deep boxy cabin for a stick of 12, a door on the left
			return {
				"span_u": 26.0, "span_l": 23.5, "chord_u": 3.0, "chord_l": 2.7, "y_u": 2.55, "y_l": -0.95,
				"z_u": -0.9, "z_l": -0.6, "ail": [9.0, 12.8], "struts": [4.2, 8.0, 11.4],
				"fus": [[-7.6, 0.45, 0.5, 0.15], [-7.1, 0.8, 0.95, 0.2], [-5.2, 0.95, 1.15, 0.2], [2.8, 0.95, 1.15, 0.2],
					[6.0, 0.55, 0.75, 0.35], [10.6, 0.14, 0.22, 0.6]],
				"nose": "inline", "prop_r": 1.5,
				"props": [Vector3(0, 0.15, -7.75), Vector3(-4.2, 0.55, -3.35), Vector3(4.2, 0.55, -3.35)],
				"nacelles": [Vector3(-4.2, 0.55, -1.4), Vector3(4.2, 0.55, -1.4)],
				"tail": [9.6, 7.6, 1.6], "fin": [9.5, 1.6, 1.4], "twin_fin": true,
				"gear": [-1.3, -2.45, 4.2, 0.6, 2], "skid": [10.2, -1.55],
				"seats": [[-6.0, "pilot"]], "fixed_mg": [], "rings": [], "bombs": 0,
				"cabin": {"door_z": 3.0, "door_w": 0.95, "door_h": 1.6, "windows": [-4.4, -3.2, -2.0, -0.8, 0.4, 1.6], "seats": 12},
				"top": BOMBER_TOP, "under": BOMBER_UNDER, "mass": 5600.0, "cruise": 34.0, "stall": 19.0,
			}
	return {}


static func is_big(kind: String) -> bool:
	return float(spec(kind).get("span_u", 0.0)) > 18.0


static func make(kind: String) -> Aircraft:
	var s := spec(kind)
	var a := Aircraft.new()
	a.kind = kind
	a.name = kind.capitalize()
	a.spec = s
	a.mass = s["mass"]
	a.cruise = s["cruise"]
	a.stall = s["stall"]
	var m := material()
	var groups := {}
	for g: String in ["Fuselage", "WingL", "WingR", "Tail", "Gear"]:
		var n := Node3D.new()
		n.name = g
		a.add_child(n)
		groups[g] = n
	a.groups = groups
	_fuselage(a, s, groups["Fuselage"])
	_wings(a, s, groups)
	_tail(a, s, groups["Tail"])
	_gear(a, s, groups["Gear"])
	_props(a, s, groups)
	if s.has("cabin"):
		_cabin(a, s, groups["Fuselage"])
	_far(a, s)
	a.finish()
	return a


# ------------------------------------------------------------------ fuselage, cockpits, guns, bombs

static func _ring(z: float, hw: float, hh: float, y: float, x := 0.0) -> PackedVector3Array:
	# chamfered box section, 8 sides
	var k := minf(hw, hh) * 0.35
	var pts := [Vector2(hw, hh - k), Vector2(hw - k, hh), Vector2(-hw + k, hh), Vector2(-hw, hh - k),
		Vector2(-hw, -hh + k), Vector2(-hw + k, -hh), Vector2(hw - k, -hh), Vector2(hw, -hh + k)]
	var out := PackedVector3Array()
	for p: Vector2 in pts:
		out.append(Vector3(x + p.x, y + p.y, z))
	return out


## A tube through rings, faces above the middle coloured top, below coloured under.
static func _loft2(g: TrainGeo, rings: Array, top: Color, under: Color, caps := 3, cap_col := Color.BLACK) -> void:
	for i in rings.size() - 1:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var mid := (TrainGeo._mid(r0) + TrainGeo._mid(r1)) * 0.5
		for j in r0.size():
			var j1 := (j + 1) % r0.size()
			var cy := (r0[j].y + r0[j1].y + r1[j].y + r1[j1].y) * 0.25
			var c := top if cy >= mid.y - 0.02 else under
			g.quad_out(r0[j], r0[j1], r1[j1], r1[j], c, mid)
	for e in 2:
		if caps & (1 << e):
			var r: PackedVector3Array = rings[0] if e == 0 else rings[rings.size() - 1]
			var other := TrainGeo._mid(rings[1] if e == 0 else rings[rings.size() - 2])
			var cm := TrainGeo._mid(r)
			for j in r.size():
				g.tri_out(cm, r[j], r[(j + 1) % r.size()], cap_col, other)


static func _fuselage(a: Aircraft, s: Dictionary, grp: Node3D) -> void:
	var m := material()
	var g := TrainGeo.new()
	var rings: Array = []
	for f: Array in s["fus"]:
		rings.append(_ring(f[0], f[1], f[2], f[3]))
	_loft2(g, rings, s["top"], s["under"], 3, METAL)
	var f0: Array = s["fus"][0]
	match s["nose"]:
		"rotary":
			g.cyl(Vector3(0, 0, f0[0] - 0.05), Vector3(0, 0, f0[0] + 0.45), 0.52, 12, COWL, 0.49)
			g.cyl(Vector3(0, 0, f0[0] - 0.08), Vector3(0, 0, f0[0] - 0.02), 0.3, 10, BLACK)
		"inline":
			g.box(Vector3(0, f0[3], f0[0] - 0.05), Vector3(f0[1] * 0.9, f0[2] * 0.9, 0.08), METAL)      # radiator
			for k in 5:
				g.box(Vector3(0, f0[3] - f0[2] * 0.7 + float(k) * f0[2] * 0.35, f0[0] - 0.14), Vector3(f0[1] * 0.85, 0.02, 0.01), BLACK)
			g.box(Vector3(0, f0[3] + f0[2] + 0.12, f0[0] + 0.9), Vector3(0.08, 0.14, 0.35), COWL)       # exhaust stack
		"glass":
			# open nose gunner pit with a ring (the ring itself is a moving part)
			g.cyl(Vector3(0, f0[3], f0[0] - 0.02), Vector3(0, f0[3], f0[0] + 0.02), f0[1] * 0.9, 8, METAL)
	# markings: cream-edged dark diamonds on the fuselage sides
	var mz: float = lerpf(float(s["fus"][3][0]), float(s["fus"][4][0]), 0.5)
	var hw := _hw_at(s, mz)
	var slope := (_hw_at(s, mz + 0.2) - _hw_at(s, mz - 0.2)) / 0.4          # the side tapers in towards the tail
	var msz := _hh_at(s, mz) * 0.55
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * (hw - _hw_at(s, mz) * 0.35 * 0.0 + 0.008), _y_at(s, mz), mz)
		var face := Basis(Vector3.UP, side * atan(slope))
		var bas := face * Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)) * Basis(Vector3(0, 0, 1), PI * 0.25)
		g.box(c, Vector3(msz, msz, 0.006), CREAM, bas)
		g.box(c + face * Vector3(side * 0.007, 0, 0), Vector3(msz * 0.66, msz * 0.66, 0.006), MARK, bas)
	# cockpits: dark openings, airmen, a windscreen
	for seat: Array in s["seats"]:
		var z: float = seat[0]
		var top_y := _y_at(s, z) + _hh_at(s, z)
		g.box(Vector3(0, top_y + 0.005, z), Vector3(0.32, 0.01, 0.42), BLACK)
		g.box(Vector3(0, top_y + 0.02, z - 0.5), Vector3(0.34, 0.03, 0.06), LEATHER)          # coaming
		if seat[1] == "pilot":
			airman(g, Vector3(0, top_y - 0.12, z + 0.05))
		if seat[1] == "pilot":
			g.box(Vector3(0, top_y + 0.17, z - 0.55), Vector3(0.18, 0.11, 0.01), GLASS, Basis(Vector3.RIGHT, -0.35))
	# fixed forward guns
	for p: Vector3 in s["fixed_mg"]:
		g.box(p, Vector3(0.06, 0.07, 0.45), METAL)
		g.cyl(p + Vector3(0, 0, -0.45), p + Vector3(0, 0, -0.75), 0.03, 6, BLACK)
		a.muzzles.append(p + Vector3(0, 0, -0.8))
	var mi := g.make(grp, "Mesh", m)
	mi.name = "Mesh"
	a.marks["cockpit"] = Vector3(0, _y_at(s, 0.0) + 0.6, float(s["seats"][0][0]))
	a.marks["tail_end"] = Vector3(0, float(s["fus"][5][3]), float(s["fus"][5][0]))
	# gunner rings: ring (turns) -> gun (lifts)
	for r: Array in s["rings"]:
		var z: float = r[0]
		var ring := Node3D.new()
		ring.name = "Ring%d" % a.rings.size()
		ring.position = Vector3(0, r[1] + _y_at(s, z) * 0.0, z)
		grp.add_child(ring)
		var rg := TrainGeo.new()
		var n := 12
		for i in n:
			var t0 := TAU * float(i) / float(n)
			var t1 := TAU * float(i + 1) / float(n)
			rg.cyl(Vector3(cos(t0) * 0.5, 0.0, sin(t0) * 0.5), Vector3(cos(t1) * 0.5, 0.0, sin(t1) * 0.5), 0.03, 4, METAL)
		rg.box(Vector3(0, 0.17, -0.42), Vector3(0.025, 0.17, 0.025), METAL)                   # gun post
		airman(rg, Vector3(0, -0.12, 0.12))                                                     # the gunner stands
		rg.make(ring, "Mesh", m)
		var gun := Node3D.new()
		gun.name = "Gun"
		gun.position = Vector3(0, 0.36, -0.42)
		ring.add_child(gun)
		var gg := TrainGeo.new()
		gg.cyl(Vector3(0, 0, 0.35), Vector3(0, 0, -0.75), 0.055, 8, METAL)                    # Lewis barrel jacket
		gg.cyl(Vector3(0, 0.1, -0.1), Vector3(0, 0.13, -0.1), 0.17, 10, BLACK)                 # drum
		gg.box(Vector3(0, -0.06, 0.4), Vector3(0.03, 0.06, 0.12), WOOD_DARK)                  # stock
		gg.make(gun, "Mesh", m)
		a.rings.append(ring)
		a.ring_guns.append(gun)
	# bombs under the fuselage
	var nb: int = s["bombs"]
	for i in nb:
		var row := i / 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var b := Node3D.new()
		b.name = "Bomb%d" % i
		var bz := -1.4 + float(row) * 0.75
		b.position = Vector3(side * 0.28, _y_at(s, bz) - _hh_at(s, bz) - 0.2, bz)
		grp.add_child(b)
		bomb_mesh(b)
		a.bombs.append(b)


## A flier from the waist up at base, facing -Z: leather coat, scarf, face, leather helmet and goggles.
static func airman(g: TrainGeo, base: Vector3) -> void:
	g.box(base + Vector3(0, 0.17, 0), Vector3(0.17, 0.17, 0.11), LEATHER, Basis(), 0.04)                  # coat
	g.box(base + Vector3(0, 0.33, -0.01), Vector3(0.1, 0.035, 0.08), CREAM)                              # scarf
	for side: float in [-1.0, 1.0]:
		g.cyl(base + Vector3(side * 0.19, 0.3, 0.0), base + Vector3(side * 0.15, 0.17, -0.22), 0.045, 5, LEATHER)   # arms forward
		g.lump(base + Vector3(side * 0.13, 0.16, -0.25), 0.04, LEATHER)                                     # gloves
	g.lump(base + Vector3(0, 0.45, 0), 0.095, SKIN, Vector3(0.95, 1.1, 1.0))                             # face
	g.lump(base + Vector3(0, 0.49, 0.025), 0.1, LEATHER, Vector3(1.05, 0.95, 1.05))                      # helmet
	g.box(base + Vector3(0, 0.47, -0.085), Vector3(0.08, 0.022, 0.015), GLASS)                           # goggles


static func bomb_mesh(parent: Node3D) -> void:
	var g := TrainGeo.new()
	g.cyl(Vector3(0, 0, -0.45), Vector3(0, 0, 0.25), 0.13, 8, BOMB)
	g.cyl(Vector3(0, 0, -0.55), Vector3(0, 0, -0.45), 0.06, 8, BOMB, 0.13)
	g.cyl(Vector3(0, 0, 0.25), Vector3(0, 0, 0.5), 0.13, 8, BOMB, 0.05)
	for k in 4:
		var b := Basis(Vector3(0, 0, 1), PI * 0.5 * float(k))
		g.box(Vector3(0, 0, 0.52) + b * Vector3(0, 0.12, 0), Vector3(0.01, 0.1, 0.1), BLACK, b)
	g.make(parent, "Mesh", material())


static func _interp(s: Dictionary, z: float, idx: int) -> float:
	var f: Array = s["fus"]
	if z <= float(f[0][0]):
		return float(f[0][idx])
	for i in f.size() - 1:
		var z0: float = f[i][0]
		var z1: float = f[i + 1][0]
		if z >= z0 and z <= z1:
			return lerpf(float(f[i][idx]), float(f[i + 1][idx]), (z - z0) / maxf(z1 - z0, 0.001))
	return float(f[f.size() - 1][idx])


static func _hw_at(s: Dictionary, z: float) -> float:
	return _interp(s, z, 1)


static func _hh_at(s: Dictionary, z: float) -> float:
	return _interp(s, z, 2)


static func _y_at(s: Dictionary, z: float) -> float:
	return _interp(s, z, 3)


# ------------------------------------------------------------------ wings

## A wing panel from x0 to x1 (|x| grows outward), chord c centred on z, at height y. Tip rounded at the far end
## if tip. Leading edge at -Z.
static func _panel(g: TrainGeo, x0: float, x1: float, y: float, z: float, c: float, t: float, top: Color, under: Color, tip: bool, chord_cut := 0.0) -> void:
	var prof := [Vector2(-0.5, 0.0), Vector2(-0.44, 0.75), Vector2(-0.22, 1.0), Vector2(0.15, 0.8), Vector2(0.5, 0.15),
		Vector2(0.5, -0.05), Vector2(0.15, -0.12), Vector2(-0.22, -0.22), Vector2(-0.44, -0.2)]
	var stations: Array = [[x0, 1.0]]
	if tip:
		stations.append([lerpf(x0, x1, 0.86), 1.0])
		stations.append([x1, 0.72])
	else:
		stations.append([x1, 1.0])
	var rings: Array = []
	for st: Array in stations:
		var k: float = st[1]
		var r := PackedVector3Array()
		var cc := c * k
		for p: Vector2 in prof:
			var px := p.x
			# cut away the trailing part where an aileron sits
			if chord_cut > 0.0 and px > 0.5 - chord_cut / c:
				px = 0.5 - chord_cut / c
			var zz := z - c * 0.5 + (px + 0.5) * cc + (c - cc) * 0.15
			r.append(Vector3(st[0], y + p.y * t * k, zz))
		rings.append(r)
	_loft2(g, rings, top, under, 3, under)


static func _wings(a: Aircraft, s: Dictionary, groups: Dictionary) -> void:
	var m := material()
	var top: Color = s["top"]
	var under: Color = s["under"]
	# centre section (upper wing middle over the fuselage) with cabane struts: part of the fuselage group
	var cg := TrainGeo.new()
	var hu: float = float(s["span_u"]) * 0.5
	var hl: float = float(s["span_l"]) * 0.5
	var cu: float = s["chord_u"]
	var cl: float = s["chord_l"]
	var yu: float = s["y_u"]
	var yl: float = s["y_l"]
	var zu: float = s["z_u"]
	var zl: float = s["z_l"]
	var root := 0.7
	_panel(cg, -root, root, yu, zu, cu, 0.12, top, under, false)
	_panel(cg, -root * 0.8, root * 0.8, yl, zl, cl, 0.11, top, under, false)
	for side: float in [-1.0, 1.0]:
		for dz: float in [-cu * 0.3, cu * 0.25]:
			var p0 := Vector3(side * 0.32, _y_at(s, zu + dz) + _hh_at(s, zu + dz) * 0.6, zu + dz)
			var p1 := Vector3(side * 0.55, yu - 0.02, zu + dz)
			cg.cyl(p0, p1, 0.035, 5, STRUT)
	cg.make(groups["Fuselage"], "Centre", m)
	var ail: Array = s["ail"]
	var ail_c := cu * 0.26
	for side: float in [-1.0, 1.0]:
		var grp: Node3D = groups["WingL" if side < 0 else "WingR"]
		var g := TrainGeo.new()
		# upper wing: inner part full chord, outer part with the aileron cut out
		_panel_side(g, side, root, float(ail[0]), yu, zu, cu, 0.12, top, under, false, 0.0)
		_panel_side(g, side, float(ail[0]), hu, yu, zu, cu, 0.12, top, under, true, ail_c)
		_panel_side(g, side, root * 0.8, hl, yl, zl, cl, 0.11, top, under, true, 0.0)
		# markings on the upper wing tops
		var mx := side * (hu - 1.2 * (hu / 4.2) * 0.6)
		var bas := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)) * Basis(Vector3(0, 0, 1), PI * 0.25)
		g.box(Vector3(mx, yu + 0.125, zu - cu * 0.05), Vector3(cu * 0.3, cu * 0.3, 0.004), CREAM, bas)
		g.box(Vector3(mx, yu + 0.13, zu - cu * 0.05), Vector3(cu * 0.2, cu * 0.2, 0.004), MARK, bas)
		# interplane struts and a pair of bracing wires per bay
		for x: float in s["struts"]:
			var zs := [-cu * 0.28, cu * 0.22]
			for dz: float in zs:
				var p0 := Vector3(side * x, yl + 0.05, lerpf(zl, zu, 0.0) + dz + (zu - zl) * 0.0)
				var p1 := Vector3(side * x, yu - 0.05, zu + dz)
				g.cyl(p0, p1, 0.04, 5, STRUT)
		var xs: Array = [0.6]
		xs.append_array(s["struts"])
		for i in xs.size() - 1:
			var xa: float = xs[i]
			var xb: float = xs[i + 1]
			g.cyl(Vector3(side * xa, yl + 0.05, zl), Vector3(side * xb, yu - 0.05, zu), 0.008, 3, METAL)
			g.cyl(Vector3(side * xa, yu - 0.05, zu), Vector3(side * xb, yl + 0.05, zl), 0.008, 3, METAL)
		# engine nacelle on this wing (bomber)
		if s.has("nacelles"):
			for nc: Vector3 in s["nacelles"]:
				if signf(nc.x) != side:
					continue
				var nr := [[nc.z - 1.9, 0.32, 0.38], [nc.z - 1.6, 0.42, 0.5], [nc.z + 0.6, 0.4, 0.48], [nc.z + 1.6, 0.14, 0.16]]
				var rr: Array = []
				for q: Array in nr:
					rr.append(_ring(q[0], q[1], q[2], nc.y, nc.x))
				_loft2(g, rr, top, under, 3, METAL)
				g.box(Vector3(nc.x, nc.y, nc.z - 1.97), Vector3(0.36, 0.42, 0.04), METAL)          # radiator face
				for dz: float in [-0.6, 0.6]:
					g.cyl(Vector3(nc.x - 0.3, nc.y - 0.4, nc.z + dz), Vector3(nc.x - 0.3, yl + 0.05, nc.z + dz), 0.05, 5, STRUT)
					g.cyl(Vector3(nc.x + 0.3, nc.y - 0.4, nc.z + dz), Vector3(nc.x + 0.3, yl + 0.05, nc.z + dz), 0.05, 5, STRUT)
					g.cyl(Vector3(nc.x, nc.y + 0.55, nc.z + dz), Vector3(nc.x, yu - 0.05, nc.z + dz), 0.05, 5, STRUT)
				a.marks["exhaust%d" % (0 if side < 0 else 1)] = Vector3(nc.x, nc.y + 0.5, nc.z + 0.3)
		var wm := g.make(grp, "Mesh", m)
		wm.name = "Mesh"
		# aileron: hinged on the upper wing's cut line, outer part
		var hinge_z := zu - cu * 0.5 + (cu - ail_c) + (cu - cu) * 0.15
		var aileron := Node3D.new()
		aileron.name = "Aileron"
		aileron.position = Vector3(0, yu, hinge_z)
		grp.add_child(aileron)
		var ag := TrainGeo.new()
		var x0: float = ail[0]
		var x1: float = minf(float(ail[1]), hu * 0.98)
		var outline := PackedVector2Array([Vector2(0.0, 0.05), Vector2(ail_c, 0.01), Vector2(ail_c, -0.01), Vector2(0.0, -0.03)])
		var b := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0))
		ag.extrude(outline, Vector3(side * x0, 0, 0), Vector3(side * x1, 0, 0), top, b, 3, null)
		ag.box(Vector3(side * (x0 + x1) * 0.5, -0.025, ail_c * 0.5), Vector3((x1 - x0) * 0.5, 0.004, ail_c * 0.45), under)
		ag.make(aileron, "Mesh", m)
		a.ailerons.append(aileron)
		a.aileron_side.append(side)


static func _panel_side(g: TrainGeo, side: float, x0: float, x1: float, y: float, z: float, c: float, t: float, top: Color, under: Color, tip: bool, cut: float) -> void:
	if side > 0.0:
		_panel(g, x0, x1, y, z, c, t, top, under, tip, cut)
	else:
		_panel(g, -x0, -x1, y, z, c, t, top, under, tip, cut)


# ------------------------------------------------------------------ tail

static func _tail(a: Aircraft, s: Dictionary, grp: Node3D) -> void:
	var m := material()
	var t: Array = s["tail"]
	var f: Array = s["fin"]
	var top: Color = s["top"]
	var under: Color = s["under"]
	var g := TrainGeo.new()
	var tz: float = t[0]
	var span: float = t[1]
	var chord: float = t[2]
	var ty := _y_at(s, tz) + 0.02
	var fixed_c := chord * 0.55
	# tailplane (fixed part), rounded-ish tips
	var outline := PackedVector2Array([Vector2(-span * 0.5, 0), Vector2(-span * 0.5 + 0.25, -fixed_c * 0.6), Vector2(-0.2, -fixed_c),
		Vector2(0.2, -fixed_c), Vector2(span * 0.5 - 0.25, -fixed_c * 0.6), Vector2(span * 0.5, 0)])
	_flat(g, outline, tz, ty, top, under)
	# fins and fixed fin parts
	var fins: Array = [0.0]
	if s["twin_fin"]:
		fins = [-span * 0.3, span * 0.3]
	var fh: float = f[1]
	var fc: float = f[2]
	for fx: float in fins:
		var fo := PackedVector2Array([Vector2(0, 0), Vector2(-fc, 0), Vector2(-fc * 0.35, fh * 0.8), Vector2(0, fh)])
		var fb := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0))
		var zf: float = f[0] + 0.15
		var r0 := PackedVector3Array()
		var r1 := PackedVector3Array()
		for p in fo:
			r0.append(Vector3(fx - 0.025, ty + p.y, zf + p.x))
			r1.append(Vector3(fx + 0.025, ty + p.y, zf + p.x))
		g.prism([r0, r1], top)
	var tm := g.make(grp, "Mesh", m)
	tm.name = "Mesh"
	# elevator, hinged at the back of the tailplane
	var elev := Node3D.new()
	elev.name = "Elevator"
	elev.position = Vector3(0, ty, tz)
	grp.add_child(elev)
	var eg := TrainGeo.new()
	var ec := chord - fixed_c
	var eo := PackedVector2Array([Vector2(-span * 0.48, 0), Vector2(span * 0.48, 0), Vector2(span * 0.42, ec), Vector2(-span * 0.42, ec)])
	_flat(eg, eo, 0.0, 0.0, top, under, true)
	eg.make(elev, "Mesh", m)
	a.elevator = elev
	# rudder(s), hinged at the back of each fin
	for fx: float in fins:
		var rud := Node3D.new()
		rud.name = "Rudder"
		rud.position = Vector3(fx, ty, float(f[0]) + 0.15)
		grp.add_child(rud)
		var rg := TrainGeo.new()
		var rc := fc * 0.75
		var ro := PackedVector2Array([Vector2(0, -0.15), Vector2(rc * 0.9, -0.1), Vector2(rc, fh * 0.75), Vector2(rc * 0.5, fh * 1.08), Vector2(0, fh)])
		var r0 := PackedVector3Array()
		var r1 := PackedVector3Array()
		for p in ro:
			r0.append(Vector3(-0.02, p.y, p.x))
			r1.append(Vector3(0.02, p.y, p.x))
		rg.prism([r0, r1], top)
		rg.make(rud, "Mesh", m)
		a.rudders.append(rud)


## A thin flat surface from a 2D outline (x across, y = -forward/back offset) at z, height y.
static func _flat(g: TrainGeo, o: PackedVector2Array, z: float, y: float, top: Color, under: Color, back := false) -> void:
	var r0 := PackedVector3Array()
	var r1 := PackedVector3Array()
	for p in o:
		var zz := z + (p.y if back else -p.y) * (1.0 if back else -1.0)
		zz = z + p.y if back else z + p.y
		r0.append(Vector3(p.x, y - 0.025, zz))
		r1.append(Vector3(p.x, y + 0.025, zz))
	# sides
	for j in o.size():
		var j1 := (j + 1) % o.size()
		g.quad_out(r0[j], r0[j1], r1[j1], r1[j], top, Vector3(0, y, z + (0.0 if not back else 0.2)))
	var c0 := TrainGeo._mid(r0)
	var c1 := TrainGeo._mid(r1)
	for j in o.size():
		var j1 := (j + 1) % o.size()
		g.tri_out(c1, r1[j], r1[j1], top, c1 + Vector3(0, -1, 0))
		g.tri_out(c0, r0[j], r0[j1], under, c0 + Vector3(0, 1, 0))


# ------------------------------------------------------------------ gear

static func _gear(a: Aircraft, s: Dictionary, grp: Node3D) -> void:
	var m := material()
	var ge: Array = s["gear"]
	var gz: float = ge[0]
	var gy: float = ge[1]
	var track: float = ge[2]
	var wr: float = ge[3]
	var per: int = ge[4]
	var g := TrainGeo.new()
	var legs: Array = [0.0]
	if s.has("nacelles"):
		legs = []
		for nc: Vector3 in s["nacelles"]:
			legs.append(nc.x)
	for lx: float in legs:
		var bottom := _y_at(s, gz) - _hh_at(s, gz) if lx == 0.0 else float(s["y_l"])
		var axle_half := track if lx == 0.0 else 0.55
		g.cyl(Vector3(lx - axle_half, gy, gz), Vector3(lx + axle_half, gy, gz), 0.04, 5, METAL)
		for side: float in [-1.0, 1.0]:
			var top_x := lx + side * (0.3 if lx == 0.0 else 0.35)
			g.cyl(Vector3(top_x, bottom, gz - 0.55), Vector3(lx + side * axle_half * 0.6, gy, gz), 0.04, 5, STRUT)
			g.cyl(Vector3(top_x, bottom, gz + 0.45), Vector3(lx + side * axle_half * 0.6, gy, gz), 0.04, 5, STRUT)
	# tail skid
	var sk: Array = s["skid"]
	var sy := _y_at(s, sk[0]) - _hh_at(s, sk[0])
	g.box(Vector3(0, (sy + float(sk[1])) * 0.5, float(sk[0])), Vector3(0.025, absf(sy - float(sk[1])) * 0.5 + 0.02, 0.06), WOOD_DARK, Basis(Vector3.RIGHT, 0.4))
	var gm := g.make(grp, "Mesh", m)
	gm.name = "Mesh"
	for lx: float in legs:
		var axle_half := track if lx == 0.0 else 0.55
		var xs: Array = []
		if per == 1:
			xs = [lx - axle_half, lx + axle_half]
		else:
			xs = [lx - axle_half, lx - axle_half + 0.32, lx + axle_half - 0.32, lx + axle_half]
		for x: float in xs:
			var w := Node3D.new()
			w.name = "Wheel%d" % a.wheels.size()
			w.position = Vector3(x, gy, gz)
			grp.add_child(w)
			var wg := TrainGeo.new()
			wg.cyl(Vector3(-0.07, 0, 0), Vector3(0.07, 0, 0), wr, 12, TYRE)
			wg.cyl(Vector3(-0.08, 0, 0), Vector3(0.08, 0, 0), wr * 0.7, 10, CREAM)
			wg.box(Vector3(0.085, 0, 0), Vector3(0.005, 0.04, wr * 0.65), METAL)
			wg.make(w, "Mesh", m)
			a.wheels.append(w)
	a.wheel_r = wr
	# resting on the ground: main wheels and tail skid both touching
	var ground_w := gy - wr
	var ground_t: float = sk[1]
	var dz: float = float(sk[0]) - gz
	a.sit_pitch = atan2(ground_t - ground_w, dz)        # nose up angle (radians) when the tail skid is down
	a.gear_low = ground_w
	a.gear_z = gz
	a.skid = Vector3(0, ground_t, sk[0])


# ------------------------------------------------------------------ propellers

static func _props(a: Aircraft, s: Dictionary, groups: Dictionary) -> void:
	var m := material()
	var props: Array = s["props"]
	for i in props.size():
		var at: Vector3 = props[i]
		var parent: Node3D = groups["Fuselage"]
		if absf(at.x) > 0.5:
			parent = groups["WingL" if at.x < 0.0 else "WingR"]
		var hub := Node3D.new()
		hub.name = "Prop%d" % i
		hub.position = at
		parent.add_child(hub)
		var spin := Node3D.new()
		spin.name = "Spin"
		hub.add_child(spin)
		var r: float = s["prop_r"]
		var g := TrainGeo.new()
		for blade: float in [1.0, -1.0]:
			var tw := Basis(Vector3(0, blade, 0), 0.0)
			var pts := [Vector3(0, 0.12, 0), Vector3(0, r * 0.45, 0), Vector3(0, r, 0)]
			var w := [0.07, 0.11, 0.06]
			for k in 2:
				var p0: Vector3 = pts[k] * blade
				var p1: Vector3 = pts[k + 1] * blade
				var c := (p0 + p1) * 0.5
				var len_ := p0.distance_to(p1)
				var twist := Basis(Vector3(0, 1, 0), 0.35 * blade * (1.0 - float(k) * 0.4))
				g.box(c, Vector3(float(w[k]) + float(w[k + 1]) * 0.25, len_ * 0.5, 0.025), WOOD if k == 0 else WOOD_DARK, twist)
		g.cyl(Vector3(0, 0, -0.18), Vector3(0, 0, 0.05), 0.11, 8, COWL if s["nose"] != "rotary" else METAL)
		g.make(spin, "Blades", m)
		# the blur disc for speed
		var bg := TrainGeo.new()
		var n := 20
		for k in n:
			var t0 := TAU * float(k) / float(n)
			var t1 := TAU * float(k + 1) / float(n)
			bg.emit(Vector3.ZERO, Vector3(cos(t0) * r, sin(t0) * r, 0), Vector3(cos(t1) * r, sin(t1) * r, 0), Color(0.42, 0.36, 0.30, 0.55))
		var blur := bg.make(hub, "Blur", blur_material())
		blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.props.append(spin)
		a.blurs.append(blur)


# ------------------------------------------------------------------ far look

static func _far(a: Aircraft, s: Dictionary) -> void:
	var g := TrainGeo.new()
	var f: Array = s["fus"]
	var z0: float = f[0][0]
	var z1: float = f[5][0]
	g.box(Vector3(0, 0, (z0 + z1) * 0.5), Vector3(float(f[2][1]), float(f[2][2]), (z1 - z0) * 0.5), s["top"])
	g.box(Vector3(0, s["y_u"], s["z_u"]), Vector3(float(s["span_u"]) * 0.5, 0.06, float(s["chord_u"]) * 0.5), s["top"])
	g.box(Vector3(0, s["y_l"], s["z_l"]), Vector3(float(s["span_l"]) * 0.5, 0.06, float(s["chord_l"]) * 0.5), s["top"])
	var t: Array = s["tail"]
	g.box(Vector3(0, _y_at(s, t[0]), float(t[0]) + float(t[2]) * 0.3), Vector3(float(t[1]) * 0.5, 0.04, float(t[2]) * 0.5), s["top"])
	g.box(Vector3(0, _y_at(s, t[0]) + float(s["fin"][1]) * 0.5, float(t[0]) + 0.3), Vector3(0.04, float(s["fin"][1]) * 0.5, float(s["fin"][2]) * 0.5), s["top"])
	if s.has("nacelles"):
		for nc: Vector3 in s["nacelles"]:
			g.box(nc, Vector3(0.45, 0.5, 1.7), s["top"])
	a.far = g.make(a, "Far", material())


## A weighted message bag with a long streamer (four segments that the falling bag trails).
static func message_bag() -> Node3D:
	var n := Node3D.new()
	n.name = "MessageBag"
	var g := TrainGeo.new()
	g.lump(Vector3.ZERO, 0.12, LEATHER, Vector3(1.0, 1.3, 1.0))
	g.box(Vector3(0, 0.16, 0), Vector3(0.04, 0.03, 0.04), BLACK)
	g.make(n, "Mesh", material())
	var s := Node3D.new()
	s.name = "Streamer"
	n.add_child(s)
	for i in 4:
		var seg := Node3D.new()
		seg.name = "S%d" % i
		s.add_child(seg)
		var sg := TrainGeo.new()
		var c := CREAM if i % 2 == 0 else Color(0.55, 0.16, 0.12)
		sg.box(Vector3(0, 0, -0.225), Vector3(0.07, 0.006, 0.225), c)
		sg.make(seg, "Mesh", material())
		seg.position = Vector3(0, 0.2 + 0.45 * float(i), 0)
		seg.rotation.x = PI * 0.5
	return n


## Transport cabin: windows down both sides, a sliding door on the left with a dark doorway behind it,
## a hanging ladder, and the marks the paratroopers use (door sill, static-line anchor, inside the door).
static func _cabin(a: Aircraft, s: Dictionary, grp: Node3D) -> void:
	var m := material()
	var cab: Dictionary = s["cabin"]
	var dz: float = cab["door_z"]
	var dw: float = cab["door_w"]
	var dh: float = cab["door_h"]
	var g := TrainGeo.new()
	var floor_y := _y_at(s, dz) - _hh_at(s, dz) + 0.25
	for wz: float in cab["windows"]:
		for side: float in [-1.0, 1.0]:
			var hw := _hw_at(s, wz)
			g.box(Vector3(side * (hw + 0.01), floor_y + 1.25, wz), Vector3(0.01, 0.16, 0.24), GLASS)
			g.box(Vector3(side * (hw + 0.012), floor_y + 1.25, wz), Vector3(0.008, 0.2, 0.28), BLACK)
	# the doorway (dark) and its frame
	var dhw := _hw_at(s, dz)
	g.box(Vector3(-dhw - 0.012, floor_y + dh * 0.5, dz), Vector3(0.006, dh * 0.5, dw * 0.5), BLACK)
	g.box(Vector3(-dhw - 0.03, floor_y + dh + 0.04, dz), Vector3(0.03, 0.04, dw * 0.5 + 0.06), METAL)
	g.box(Vector3(-dhw - 0.03, floor_y - 0.03, dz), Vector3(0.05, 0.03, dw * 0.5 + 0.06), METAL)
	# sliding rail aft of the door
	g.box(Vector3(-dhw - 0.03, floor_y + dh + 0.1, dz + dw), Vector3(0.02, 0.02, dw), METAL)
	g.make(grp, "Cabin", m)
	# the door panel (slides aft along the rail)
	var door := Node3D.new()
	door.name = "Door"
	door.position = Vector3(-dhw - 0.05, floor_y + dh * 0.5, dz)
	grp.add_child(door)
	var dg := TrainGeo.new()
	dg.box(Vector3.ZERO, Vector3(0.025, dh * 0.5, dw * 0.5 + 0.03), s["top"])
	dg.box(Vector3(-0.03, 0.0, -dw * 0.3), Vector3(0.02, 0.05, 0.03), METAL)
	dg.make(door, "Mesh", m)
	a.door = door
	a.door_closed_z = dz
	a.door_open_z = dz + dw + 0.05
	# a short ladder hung from the sill for loading on the ground
	var ladder := Node3D.new()
	ladder.name = "Ladder"
	ladder.position = Vector3(-dhw - 0.15, floor_y, dz)
	grp.add_child(ladder)
	var lg := TrainGeo.new()
	for sz: float in [-0.25, 0.25]:
		lg.cyl(Vector3(-0.05, 0.0, sz), Vector3(-0.35, -1.25, sz), 0.025, 4, WOOD_DARK)
	for k in 3:
		var u := (float(k) + 1.0) / 4.0
		lg.cyl(Vector3(-0.05 - 0.3 * u, -1.25 * u, -0.25), Vector3(-0.05 - 0.3 * u, -1.25 * u, 0.25), 0.02, 4, WOOD)
	lg.make(ladder, "Mesh", m)
	a.ladder = ladder
	a.marks["door_sill"] = Vector3(-dhw - 0.05, floor_y, dz)           # where a jumper stands to go
	a.marks["door_in"] = Vector3(-dhw + 0.5, floor_y, dz)              # just inside
	a.marks["line_anchor"] = Vector3(-dhw + 0.15, floor_y + dh + 0.05, dz - dw * 0.3)
	a.marks["ladder_foot"] = Vector3(-dhw - 0.6, floor_y - 1.3, dz)
	a.seats_n = cab["seats"]
