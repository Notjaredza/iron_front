extends RefCounted
## The rocket lorry's rack, built in code in the faceted unit style (Tanks Chat, 2026-11-10).
## A generic WW1-era rocket battery on the troop lorry (tilt and benches off): a steel blast
## shield behind the cab, a turntable on the bed, a lattice cradle of 16 open launch rails
## (4 across, 4 high) on trunnions, a fold-down crew seat at the back, two screw jacks at the
## rear corners. Rockets are finned tubes. Not a copy of a real one.
##
## Lorry frame as in lorry_builder.gd (forward -Z, ground y = 0). Pieces:
##   shield, seat      fixed on the lorry body
##   base              origin on the turntable centre, turns about Y (train)
##   cradle            origin on the trunnions (TRUNNION in the base frame), turns about X (elevation)
##   rocket            origin on its rail at its tail, nose to -Z (one per rail, and the flying ones)
##   jack_sleeve/leg   sleeve fixed on the body at JACK_*, leg slides down (origin at its foot)
##   box               the ammunition box on the ground, origin at its foot

const L := preload("res://scripts/vehicles/lorry_builder.gd")

const TURNTABLE := Vector3(0, L.FLOOR_Y + 0.06, 0.8)
const TRUNNION := Vector3(0, 0.45, 0)  # base frame
const RAIL_FRONT := -1.4  # cradle frame, along z
const RAIL_REAR := 0.5
const RAIL_X: Array[float] = [-0.33, -0.11, 0.11, 0.33]
const RAIL_Y: Array[float] = [0.1, 0.3, 0.5, 0.7]
const ROCKET_LEN := 1.15
const ROCKET_R := 0.055
const SEAT_Z := 0.4  # a seated rocket's tail sits this far forward of the rail's rear end
const JACK_R := Vector3(0.98, 0.95, 2.45)  # right jack sleeve (x mirrors)
const SHIELD_Z := -1.17
const BOX_AT := Vector3(-1.6, 0, 4.4)  # where the crew put the ammunition box (lorry frame)

const STEEL := Color(0.20, 0.21, 0.20)
const STEEL_DARK := Color(0.14, 0.14, 0.14)
const PAINT := Color(0.36, 0.39, 0.25)
const PAINT_DARK := Color(0.28, 0.31, 0.19)
const ROCKET := Color(0.44, 0.45, 0.36)
const ROCKET_BAND := Color(0.62, 0.20, 0.14)
const NOSE := Color(0.58, 0.48, 0.26)
const WOOD := Color(0.47, 0.35, 0.21)
const MARK := Color(0.86, 0.84, 0.75)
const CHAR := Color(0.13, 0.12, 0.11)
const CHAR_BROWN := Color(0.22, 0.15, 0.10)
const RUST := Color(0.38, 0.21, 0.11)


static func _p(wreck: bool) -> Dictionary:
	if not wreck:
		return {"steel": STEEL, "dark": STEEL_DARK, "paint": PAINT, "paint_dark": PAINT_DARK, "rocket": ROCKET,
			"band": ROCKET_BAND, "nose": NOSE, "wood": WOOD, "mark": MARK}
	return {"steel": CHAR, "dark": CHAR, "paint": CHAR_BROWN, "paint_dark": CHAR, "rocket": CHAR_BROWN, "band": RUST,
		"nose": RUST, "wood": CHAR, "mark": CHAR_BROWN}


## The rail's world-free position in the cradle frame: rail i (0..15), slide = how far the
## rocket's tail sits forward of the rail's rear end (m).
static func rail_point(i: int, slide := SEAT_Z) -> Vector3:
	return Vector3(RAIL_X[i % 4], RAIL_Y[i / 4] + ROCKET_R + 0.02, RAIL_REAR - slide)


## Steel blast shield behind the cab, with a sight slot (fixed on the body).
static func shield(lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _p(wreck)
	g.box(Vector3(0, L.FLOOR_Y + 0.68, SHIELD_Z), Vector3(1.0, 0.68, 0.025), p["paint"], 0)
	if lod == 0:
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.62 * s, L.FLOOR_Y + 0.5, SHIELD_Z + 0.2), Vector3(0.03, 0.03, 0.2), p["steel"], 0,
				Basis(Vector3.RIGHT, 0.6))
		g.box(Vector3(0, L.FLOOR_Y + 1.3, SHIELD_Z - 0.03), Vector3(0.25, 0.025, 0.006), CHAR, 0)
		# Painted warning band along the top.
		g.box(Vector3(0, L.FLOOR_Y + 1.33, SHIELD_Z + 0.028), Vector3(1.0, 0.03, 0.003), p["mark"], 0)
	if lod >= 2:
		return g
	# The crew seat folded down at the back of the bed, its two legs.
	g.box(Vector3(0, L.FLOOR_Y + 0.42, L.BED_REAR - 0.35), Vector3(0.75, 0.025, 0.17), p["wood"], 0)
	g.box(Vector3(0, L.FLOOR_Y + 0.65, L.BED_REAR - 0.18), Vector3(0.75, 0.2, 0.02), p["wood"], 0)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.65 * s, L.FLOOR_Y + 0.2, L.BED_REAR - 0.35), Vector3(0.025, 0.2, 0.025), p["steel"], 0)
	# A rack of spare-rocket clips along the right board.
	if lod == 0:
		for k in 3:
			g.box(Vector3(1.0, L.FLOOR_Y + 0.35, -0.6 + 0.9 * k), Vector3(0.05, 0.05, 0.05), p["steel"], 0)
	# Jack sleeves at the rear corners.
	for s: float in [1.0, -1.0]:
		var j := JACK_R * Vector3(s, 1, 1)
		g.loft([j + Vector3(0, 0.2, 0), j - Vector3(0, 0.25, 0)], [Vector2(0.06, 0.06), Vector2(0.06, 0.06)], Vector3.FORWARD,
			6 if lod == 0 else 4, 0.0, p["steel"], 0)
		g.box(j + Vector3(-0.08 * s, 0.17, 0), Vector3(0.08, 0.03, 0.04), p["steel"], 0)
	return g


## The turntable and the two cheeks that hold the trunnions (origin on the turntable).
static func base(lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _p(wreck)
	g.loft([Vector3(0, 0.0, 0), Vector3(0, 0.07, 0)], [Vector2(0.72, 0.72), Vector2(0.7, 0.7)], Vector3.FORWARD,
		12 if lod == 0 else 6, 0.0, p["paint_dark"], 0)
	for s: float in [1.0, -1.0]:
		var poly := PackedVector2Array([Vector2(-0.45, 0.07), Vector2(0.45, 0.07), Vector2(0.12, TRUNNION.y + 0.08),
			Vector2(-0.12, TRUNNION.y + 0.08)])
		for k in poly.size():
			pass
		_plate(g, poly, 0.5 * s, 0.03, p["paint"])
		if lod >= 2:
			continue
		g.loft([Vector3(0.47 * s, TRUNNION.y, 0), Vector3(0.56 * s, TRUNNION.y, 0)], [Vector2(0.07, 0.07), Vector2(0.07, 0.07)],
			Vector3.UP, 8 if lod == 0 else 5, 0.0, p["steel"], 0)
	if lod == 0:
		# The training handwheel on the left cheek and the elevating arc on the right.
		g.loft([Vector3(-0.58, 0.28, 0.3), Vector3(-0.62, 0.28, 0.3)], [Vector2(0.13, 0.13), Vector2(0.13, 0.13)], Vector3.UP, 10, 0.0,
			p["steel"], 0)
		for k in 6:
			var a := -0.6 + 0.24 * k
			g.box(Vector3(0.55, TRUNNION.y + 0.28 * sin(a) - 0.05, 0.28 * cos(a) - 0.02), Vector3(0.012, 0.02, 0.03), p["dark"], 0)
	return g


## A flat plate in the (z, y) plane at x, half thick t.
static func _plate(g: UnitGeo, poly: PackedVector2Array, x: float, t: float, col: Color) -> void:
	var TB := load("res://scripts/vehicles/tank_builder.gd")
	TB.prism(g, poly, Vector3.BACK, Vector3.UP, Vector3.RIGHT, x - t, x + t, col)


## The cradle: 16 open rails in a lattice frame (origin on the trunnions).
static func cradle(lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _p(wreck)
	var d0 := lod == 0
	var zf := RAIL_FRONT
	var zr := RAIL_REAR
	var zm := (zf + zr) * 0.5
	var hl := (zr - zf) * 0.5
	if lod >= 2:
		g.box(Vector3(0, 0.42, zm), Vector3(0.44, 0.38, hl), p["steel"], 0)
		return g
	# The rails: a flat bar with a raised guide down its middle.
	for i in 16:
		var c := Vector3(RAIL_X[i % 4], RAIL_Y[i / 4], zm)
		g.box(c, Vector3(0.05, 0.008, hl), p["steel"], 0)
		if d0:
			g.box(c + Vector3(0, 0.02, 0), Vector3(0.008, 0.014, hl), p["dark"], 0)
	# Side frames: top and bottom chords, uprights, diagonals.
	for s: float in [1.0, -1.0]:
		var x := 0.44 * s
		for y in [0.02, RAIL_Y[3] + 0.04]:
			g.box(Vector3(x, y, zm), Vector3(0.02, 0.025, hl), p["paint"], 0)
		var posts := [zf + 0.05, zm - 0.45, zm + 0.45, zr - 0.05] if d0 else [zf + 0.05, zr - 0.05]
		for z: float in posts:
			g.box(Vector3(x, (0.02 + RAIL_Y[3] + 0.04) * 0.5, z), Vector3(0.02, (RAIL_Y[3] + 0.02) * 0.5, 0.025), p["paint"], 0)
		if d0:
			for k in 3:
				var a: float = posts[k]
				var b: float = posts[k + 1]
				var lo := Vector3(x, 0.04, a)
				var hi := Vector3(x, RAIL_Y[3] + 0.02, b)
				if k % 2 == 1:
					lo = Vector3(x, 0.04, b)
					hi = Vector3(x, RAIL_Y[3] + 0.02, a)
				g.loft([lo, hi], [Vector2(0.015, 0.015), Vector2(0.015, 0.015)], Vector3.RIGHT, 4, 0.0, p["paint"], 0)
	# Cross members under each row at front and back, the trunnion bar.
	for y: float in RAIL_Y:
		for z in [zf + 0.08, zr - 0.08]:
			g.box(Vector3(0, y - 0.015, z), Vector3(0.44, 0.012, 0.02), p["paint_dark"], 0)
	g.box(Vector3(0, 0.0, 0.0), Vector3(0.47, 0.04, 0.04), p["steel"], 0)
	if d0:
		# The firing cable junction box on the left frame, the number on both sides.
		g.box(Vector3(-0.47, 0.3, zr - 0.25), Vector3(0.03, 0.08, 0.1), p["paint_dark"], 0)
	return g


## One rocket: a finned tube, its tail at the origin, nose to -Z.
static func rocket(lod: int, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _p(wreck)
	var r := ROCKET_R
	var n := 8 if lod == 0 else 5
	var L1 := ROCKET_LEN
	if lod >= 2:
		g.box(Vector3(0, 0, -L1 * 0.5), Vector3(r, r, L1 * 0.5), p["rocket"], 0)
		return g
	g.loft([Vector3(0, 0, -0.02), Vector3(0, 0, -L1 + 0.22)], [Vector2(r, r), Vector2(r, r)], Vector3.UP, n, 0.0, p["rocket"], 0, null, 1)
	g.loft([Vector3(0, 0, -L1 + 0.22), Vector3(0, 0, -L1 + 0.05), Vector3(0, 0, -L1)], [Vector2(r, r), Vector2(r * 0.55, r * 0.55),
		Vector2(0.008, 0.008)], Vector3.UP, n, 0.0, p["nose"], 0, null, 2)
	if lod >= 1:
		return g
	g.loft([Vector3(0, 0, -L1 + 0.26), Vector3(0, 0, -L1 + 0.22)], [Vector2(r + 0.003, r + 0.003), Vector2(r + 0.003, r + 0.003)],
		Vector3.UP, n, 0.0, p["band"], 0)
	# The nozzle and four fins.
	g.loft([Vector3(0, 0, 0.0), Vector3(0, 0, 0.04)], [Vector2(r * 0.6, r * 0.6), Vector2(r * 0.7, r * 0.7)], Vector3.UP, n, 0.0, p["steel"], 0)
	for k in 4:
		var a := TAU * (float(k) + 0.5) / 4.0
		var b := Basis(Vector3.BACK, a)
		g.box(b * Vector3(0, r + 0.04, -0.12), Vector3(0.004, 0.04, 0.1), p["steel"], 0, b)
	return g


## A jack leg: origin at its foot pad, the screw up from it.
static func jack_leg(lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _p(wreck)
	g.loft([Vector3(0, 0.03, 0), Vector3(0, 0.9, 0)], [Vector2(0.04, 0.04), Vector2(0.04, 0.04)], Vector3.FORWARD,
		6 if lod == 0 else 4, 0.0, p["steel"], 0)
	g.box(Vector3(0, 0.02, 0), Vector3(0.15, 0.02, 0.15), p["dark"], 0)
	return g


## The ammunition box: a wooden crate, lid open, a row of rockets lying in it (shown count).
static func box(lod: int, shown: int, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _p(wreck)
	var w := 0.45
	var lng := 0.68
	g.box(Vector3(0, 0.02, 0), Vector3(w, 0.02, lng), p["wood"], 0)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(w * s, 0.16, 0), Vector3(0.02, 0.16, lng), p["wood"], 0)
		g.box(Vector3(0, 0.16, lng * s), Vector3(w, 0.16, 0.02), p["wood"], 0)
	g.box(Vector3(w + 0.2, 0.3, 0), Vector3(0.02, 0.2, lng), p["wood"], 0, Basis(Vector3.BACK, -0.5))
	if lod == 0:
		g.box(Vector3(0, 0.2, lng + 0.025), Vector3(0.2, 0.05, 0.003), p["mark"], 0)
	var rg := rocket(lod, wreck)
	for k in mini(shown, 6):
		var x := -0.35 + 0.14 * k
		var xf := Transform3D(Basis(), Vector3(x, 0.1, ROCKET_LEN * 0.5))
		for v in rg.pos.size() / 3:
			g.emit(xf * rg.pos[v * 3], xf * rg.pos[v * 3 + 2], xf * rg.pos[v * 3 + 1], rg.col[v * 3], 0)
	return g
