extends RefCounted
## The troop lorry, built in code in the faceted unit style (Question Chat, 2026-11-09).
## A generic open army lorry: bonnet and radiator, an open-sided cab, a wooden bed with a
## bench down each side (one 12-man squad), a canvas tilt over hoops with the sides rolled up,
## spoked wheels with solid tyres (twin at the back). Not a copy of a real one.
##
## Lorry frame: forward is -Z, right is +X, the ground at y = 0, the origin halfway between
## the axles. Pieces are separate so they can move:
##   body      everything sprung (chassis, cab, bed, tilt)
##   wheel     origin on its hub, turning about X
##   tailgate  origin on its hinge at the rear of the bed floor, standing up when shut
## lod 0 close, 1 mid, 2 far. wreck = burnt out (no canvas, no tyres, charred).

const WHEEL_R := 0.46
const FRONT_Z := -1.95
const REAR_Z := 1.75
const FRONT_X := 0.86
const REAR_X := 0.84
const FLOOR_Y := 1.2  # top of the bed floor
const BED_FRONT := -1.2
const BED_REAR := 2.62
const BED_HALF := 1.1
const BENCH_X := 0.8
const BENCH_TOP := 1.65
const TAILGATE_HINGE := Vector3(0, 1.12, 2.64)
const STEP := Vector3(0, 0.62, 2.78)  # the step iron under the tailgate (top)
const HOOK := Vector3(0, 0.6, 2.84)  # tow hook (a towed gun's eye sits here)
const EXHAUST := Vector3(-0.62, 0.52, 2.5)
const DRIVER := Vector3(0.45, 1.0, -1.42)  # the driver's seat (on the cab floor)
const WHEEL_HUB := Vector3(0.45, 1.72, -1.88)  # the steering wheel centre

const PAINT := Color(0.36, 0.39, 0.25)
const PAINT_DARK := Color(0.28, 0.31, 0.19)
const CHASSIS := Color(0.15, 0.15, 0.14)
const WOOD := Color(0.42, 0.40, 0.27)  # painted bed boards
const WOOD_RAW := Color(0.50, 0.36, 0.21)
const CANVAS := Color(0.60, 0.55, 0.40)
const CANVAS_DARK := Color(0.48, 0.44, 0.31)
const TYRE := Color(0.11, 0.11, 0.11)
const GLASS := Color(0.62, 0.70, 0.72)
const BRASS := Color(0.66, 0.55, 0.30)
const SEAT := Color(0.26, 0.17, 0.11)
const CHAR := Color(0.13, 0.12, 0.11)
const CHAR_BROWN := Color(0.22, 0.15, 0.10)
const RUST := Color(0.38, 0.21, 0.11)
const ASH := Color(0.30, 0.29, 0.27)


static func _palette(wreck: bool) -> Dictionary:
	if not wreck:
		return {"paint": PAINT, "paint_dark": PAINT_DARK, "chassis": CHASSIS, "wood": WOOD, "wood_raw": WOOD_RAW,
			"canvas": CANVAS, "canvas_dark": CANVAS_DARK, "tyre": TYRE, "glass": GLASS, "brass": BRASS, "seat": SEAT}
	return {"paint": CHAR_BROWN, "paint_dark": CHAR, "chassis": CHAR, "wood": CHAR, "wood_raw": CHAR_BROWN,
		"canvas": ASH, "canvas_dark": CHAR, "tyre": CHAR, "glass": CHAR, "brass": RUST, "seat": CHAR}


## Colour for one part of a wreck: rust and char patches picked by a hash of the spot.
static func _w(c: Color, wreck: bool, at: Vector3) -> Color:
	if not wreck:
		return c
	var h := absf(sin(at.x * 12.9898 + at.y * 78.233 + at.z * 37.719) * 43758.5453)
	h -= floorf(h)
	if h < 0.3:
		return RUST
	if h < 0.55:
		return CHAR_BROWN
	return c


## tilt = canvas and hoops on; benches = the two side benches (off for a cargo or gun-carrying lorry).
static func body(lod := 0, wreck := false, tilt := true, benches := true) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var d0 := lod == 0
	if lod >= 2:
		_body_far(g, p, wreck, tilt)
		return g
	var X := Vector3.RIGHT
	var Z := Vector3.BACK
	var ch := 0.25 if d0 else 0.0
	# Chassis rails, cross members, axles (the axles hang with the body; the wheels move).
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.42 * s, 0.70, -0.3), Vector3(0.05, 0.08, 3.0), p["chassis"], 0)
	for z in [-3.0, -1.2, 0.4, 1.75, 2.6]:
		g.box(Vector3(0, 0.70, z), Vector3(0.42, 0.04, 0.04), p["chassis"], 0)
	g.box(Vector3(0, WHEEL_R, FRONT_Z), Vector3(0.78, 0.05, 0.05), p["chassis"], 0)
	g.box(Vector3(0, WHEEL_R, REAR_Z), Vector3(0.72, 0.06, 0.06), p["chassis"], 0)
	g.box(Vector3(0, WHEEL_R, REAR_Z), Vector3(0.14, 0.13, 0.13), p["chassis"], 0, Basis(), ch)  # differential
	if d0:
		# Leaf springs over each axle.
		for s: float in [1.0, -1.0]:
			for az: float in [FRONT_Z, REAR_Z]:
				g.box(Vector3(0.42 * s, 0.57, az), Vector3(0.04, 0.025, 0.5), p["chassis"], 0)
		# Drive shaft, the exhaust pipe along the left.
		g.loft([Vector3(0, 0.62, -1.2), Vector3(0, WHEEL_R + 0.05, REAR_Z - 0.15)], [Vector2(0.035, 0.035), Vector2(0.035, 0.035)],
			Vector3.UP, 6, 0.0, p["chassis"], 0)
		g.loft([Vector3(-0.35, 0.62, -2.3), Vector3(-0.62, 0.52, -1.0), EXHAUST], [Vector2(0.03, 0.03), Vector2(0.03, 0.03),
			Vector2(0.03, 0.03)], Vector3.UP, 6, 0.0, p["chassis"], 0)
	# Front: bumper, radiator with its grille and cap, the bonnet, headlamps.
	g.box(Vector3(0, 0.64, -3.4), Vector3(0.96, 0.05, 0.05), p["chassis"], 0)
	g.box(Vector3(0, 1.15, -3.22), Vector3(0.39, 0.43, 0.07), _w(p["paint_dark"], wreck, Vector3(0, 1.1, -3.2)), 0, Basis(), ch)
	if d0:
		g.box(Vector3(0, 1.12, -3.295), Vector3(0.31, 0.34, 0.01), p["chassis"], 0)
		for k in 7:
			g.box(Vector3(-0.27 + 0.09 * k, 1.12, -3.3), Vector3(0.012, 0.33, 0.006), p["paint_dark"], 0)
		g.loft([Vector3(0, 1.58, -3.22), Vector3(0, 1.64, -3.22)], [Vector2(0.04, 0.04), Vector2(0.035, 0.035)], X, 6, 0.0,
			p["brass"], 0)
	var bon := _w(p["paint"], wreck, Vector3(0.1, 1.2, -2.6))
	g.loft([Vector3(0, 1.12, -3.17), Vector3(0, 1.13, -2.15)], [Vector2(0.37, 0.4), Vector2(0.4, 0.42)], X, 8 if d0 else 4,
		ch, bon, 0)
	if d0:
		for s: float in [1.0, -1.0]:
			for k in 5:
				g.box(Vector3(0.375 * s + 0.02 * s, 1.18, -2.95 + 0.14 * k), Vector3(0.006, 0.12, 0.03), p["paint_dark"], 0)
			# Headlamps on brackets.
			g.loft([Vector3(0.58 * s, 1.32, -3.22), Vector3(0.58 * s, 1.32, -3.42)], [Vector2(0.11, 0.11), Vector2(0.12, 0.12)],
				Vector3.UP, 8, 0.0, p["chassis"], 0)
			g.loft([Vector3(0.58 * s, 1.32, -3.42), Vector3(0.58 * s, 1.32, -3.43)], [Vector2(0.095, 0.095), Vector2(0.095, 0.095)],
				Vector3.UP, 8, 0.0, p["glass"] if not wreck else CHAR, 0)
			g.box(Vector3(0.48 * s, 1.27, -3.3), Vector3(0.1, 0.015, 0.015), p["chassis"], 0)
	# Front wings over the front wheels, running boards along to the bed.
	for s: float in [1.0, -1.0]:
		var wc := _w(p["paint_dark"], wreck, Vector3(s, 1, -2))
		var segs := 5 if d0 else 3
		for k in segs:
			var a0 := lerpf(-0.35, PI * 0.62, float(k) / float(segs))
			var a1 := lerpf(-0.35, PI * 0.62, float(k + 1) / float(segs))
			var r := WHEEL_R + 0.1
			var pa := Vector3(FRONT_X * s, WHEEL_R + r * sin(a0), FRONT_Z + r * cos(a0))
			var pb := Vector3(FRONT_X * s, WHEEL_R + r * sin(a1), FRONT_Z + r * cos(a1))
			g.loft([pa, pb], [Vector2(0.14, 0.012), Vector2(0.14, 0.012)], X, 4, 0.0, wc, 0)
		g.box(Vector3(0.9 * s, 0.66, -1.05), Vector3(0.2, 0.018, 0.75), p["paint_dark"], 0)
	# The cab: floor, dash, windscreen, roof on four posts, back wall, half doors, the seat.
	var cab := _w(p["paint"], wreck, Vector3(0, 2, -1.7))
	g.box(Vector3(0, 0.97, -1.7), Vector3(0.95, 0.03, 0.45), p["chassis"], 0)
	g.box(Vector3(0, 1.3, -2.12), Vector3(0.95, 0.32, 0.03), cab, 0)
	var roof_y := 2.32 if not wreck else 2.18
	var roof_b := Basis() if not wreck else Basis(Vector3.BACK, 0.12) * Basis(Vector3.RIGHT, -0.08)
	for sx: float in [1.0, -1.0]:
		for z: float in [-2.12, -1.28]:
			var top := roof_y - (0.1 * sx if wreck else 0.0)
			g.loft([Vector3(0.93 * sx, 1.0, z), Vector3(0.93 * sx, top, z)], [Vector2(0.03, 0.03), Vector2(0.03, 0.03)],
				Vector3.FORWARD, 4, 0.0, cab, 0)
		g.box(Vector3(0.94 * sx, 1.22, -1.75), Vector3(0.02, 0.22, 0.32), cab, 0)
	g.box(Vector3(0, roof_y, -1.65), Vector3(1.0, 0.03, 0.6), cab, 0, roof_b)
	g.box(Vector3(0, 1.62, -1.29), Vector3(0.95, 0.64, 0.025), cab, 0)
	if not wreck:
		g.box(Vector3(0, 1.98, -2.12), Vector3(0.88, 0.3, 0.008), p["glass"], 0)
	g.box(Vector3(0, 1.67, -2.12), Vector3(0.93, 0.02, 0.025), cab, 0)
	g.box(Vector3(0, 1.32, -1.45), Vector3(0.86, 0.06, 0.18), p["seat"], 0)
	g.box(Vector3(0, 1.62, -1.33), Vector3(0.86, 0.2, 0.05), p["seat"], 0)
	# Steering column and wheel (right-hand drive).
	g.loft([Vector3(WHEEL_HUB.x, 1.05, -2.08), WHEEL_HUB], [Vector2(0.025, 0.025), Vector2(0.025, 0.025)], Vector3.UP, 4, 0.0,
		p["chassis"], 0)
	if d0:
		var wb := Basis(Vector3.RIGHT, -0.75)
		for k in 8:
			var a := TAU * float(k) / 8.0
			g.box(WHEEL_HUB + wb * Vector3(0.19 * cos(a), 0.0, 0.19 * sin(a)), Vector3(0.022, 0.012, 0.08), p["chassis"], 0,
				wb * Basis(Vector3.UP, -a))
	# The bed: floor, sides with plank lines, the front board, rear corner posts, mudguards.
	var bz := (BED_FRONT + BED_REAR) * 0.5
	var bh := (BED_REAR - BED_FRONT) * 0.5
	g.box(Vector3(0, FLOOR_Y - 0.05, bz), Vector3(BED_HALF, 0.05, bh), p["wood_raw"], 0)
	for z in [BED_FRONT + 0.3, bz, BED_REAR - 0.3]:
		g.box(Vector3(0, FLOOR_Y - 0.14, z), Vector3(BED_HALF, 0.04, 0.05), p["chassis"], 0)
	for s: float in [1.0, -1.0]:
		g.box(Vector3((BED_HALF - 0.03) * s, FLOOR_Y + 0.26, bz), Vector3(0.03, 0.26, bh), _w(p["wood"], wreck, Vector3(s, 1.4, 0.3)), 0)
		if d0:
			for k in 2:
				g.box(Vector3((BED_HALF + 0.003) * s, FLOOR_Y + 0.17 + 0.17 * k, bz), Vector3(0.003, 0.008, bh), p["paint_dark"], 0)
			for z in [BED_FRONT + 0.05, bz, BED_REAR - 0.05]:
				g.box(Vector3((BED_HALF + 0.01) * s, FLOOR_Y + 0.26, z), Vector3(0.012, 0.27, 0.03), p["chassis"], 0)
		g.box(Vector3(REAR_X * s, 0.99, REAR_Z), Vector3(0.24, 0.015, 0.55), p["paint_dark"], 0)
	g.box(Vector3(0, FLOOR_Y + 0.3, BED_FRONT + 0.02), Vector3(BED_HALF, 0.3, 0.03), _w(p["wood"], wreck, Vector3(0, 1.5, -1.2)), 0)
	# Benches down each side.
	if benches:
		_benches(g, p, d0, bz, bh)
	# Step iron under the tailgate, a tow hook, a jerrican and a tool box on the right board.
	g.box(STEP + Vector3(0, -0.01, 0), Vector3(0.22, 0.012, 0.07), p["chassis"], 0)
	g.loft([Vector3(0, FLOOR_Y - 0.1, BED_REAR - 0.05), STEP + Vector3(0, 0, -0.02)], [Vector2(0.015, 0.015), Vector2(0.015, 0.015)],
		X, 4, 0.0, p["chassis"], 0)
	if d0:
		g.box(Vector3(0, 0.62, 2.78), Vector3(0.04, 0.04, 0.06), p["chassis"], 0)
		g.box(Vector3(0.92, 0.82, -0.85), Vector3(0.07, 0.15, 0.11), p["paint_dark"], 0, Basis(), 0.2)
		g.box(Vector3(0.92, 0.76, -0.45), Vector3(0.09, 0.09, 0.2), p["chassis"], 0)
	if tilt:
		_tilt(g, p, lod, wreck)
	return g


## The canvas tilt: hoops, a roof that drops to the eaves, the sides rolled up, the front closed.
static func _tilt(g: UnitGeo, p: Dictionary, lod: int, wreck: bool) -> void:
	var d0 := lod == 0
	var hoops := [BED_FRONT + 0.06, -0.05, 1.25, BED_REAR - 0.06]
	var prof: Array[Vector2] = [Vector2(-1.09, 2.2), Vector2(-1.07, 2.6), Vector2(-0.72, 2.88), Vector2(0.0, 2.96),
		Vector2(0.72, 2.88), Vector2(1.07, 2.6), Vector2(1.09, 2.2)]
	for i in hoops.size():
		var z: float = hoops[i]
		var bend: float = 0.0 if not wreck else [0.0, 0.25, -0.35, 0.1][i]
		var pts: Array = [Vector3(-1.09, FLOOR_Y + 0.5, z)]
		for pr in prof:
			var drop: float = bend * (1.0 - absf(pr.x))
			pts.append(Vector3(pr.x, pr.y - drop, z + drop * 0.4))
		pts.append(Vector3(1.09, FLOOR_Y + 0.5, z))
		var sz: Array = []
		for k in pts.size():
			sz.append(Vector2(0.02, 0.02))
		g.loft(pts, sz, Vector3.BACK, 4, 0.0, p["chassis"] if not wreck else RUST, 0, null, 0)
	if wreck:
		return
	# Roof canvas between the profile points, from the first hoop to the last.
	var z0: float = hoops[0] - 0.03
	var z1: float = hoops[hoops.size() - 1] + 0.05
	for k in prof.size() - 1:
		var a := Vector3(prof[k].x, prof[k].y + 0.02, z0)
		var b := Vector3(prof[k + 1].x, prof[k + 1].y + 0.02, z0)
		var c := Vector3(prof[k + 1].x, prof[k + 1].y + 0.02, z1)
		var e := Vector3(prof[k].x, prof[k].y + 0.02, z1)
		var col: Color = p["canvas"] if (k % 2 == 0 or not d0) else p["canvas"].darkened(0.06)
		_quad2(g, a, b, c, e, col)
	# The rolled-up sides along the eaves, tie straps, the closed front.
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(1.1 * s, 2.16, z0), Vector3(1.1 * s, 2.16, z1)], [Vector2(0.07, 0.07), Vector2(0.07, 0.07)], Vector3.UP,
			6 if d0 else 4, 0.0, p["canvas_dark"], 0)
		if d0:
			for z in [0.4, 2.0]:
				g.box(Vector3(1.17 * s, 2.16, z), Vector3(0.005, 0.08, 0.02), p["chassis"], 0)
	var fz: float = hoops[0] - 0.035
	var centre := Vector3(0, 2.3, fz)
	var ring: Array = [Vector3(-1.09, FLOOR_Y + 0.6, fz)]
	for pr in prof:
		ring.append(Vector3(pr.x, pr.y + 0.02, fz))
	ring.append(Vector3(1.09, FLOOR_Y + 0.6, fz))
	for k in ring.size() - 1:
		g.emit(centre, ring[k], ring[k + 1], p["canvas"], 0)
		g.emit(centre, ring[k + 1], ring[k], p["canvas"], 0)
	g.emit(centre, ring[ring.size() - 1], ring[0], p["canvas"], 0)
	g.emit(centre, ring[0], ring[ring.size() - 1], p["canvas"], 0)


static func _quad2(g: UnitGeo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	g.emit(a, b, c, col, 0)
	g.emit(a, c, d, col, 0)
	g.emit(a, c, b, col, 0)
	g.emit(a, d, c, col, 0)


## Far look: a handful of boxes (about 150 triangles).
static func _body_far(g: UnitGeo, p: Dictionary, wreck: bool, tilt := true) -> void:
	g.box(Vector3(0, 0.7, -0.3), Vector3(0.45, 0.08, 3.0), p["chassis"], 0)
	g.box(Vector3(0, 1.13, -2.68), Vector3(0.4, 0.43, 0.55), p["paint"], 0)
	g.box(Vector3(0, 1.62, -1.7), Vector3(0.95, 0.66, 0.43), p["paint"], 0)
	g.box(Vector3(0, FLOOR_Y + 0.12, 0.71), Vector3(BED_HALF, 0.17, 1.91), p["wood"], 0)
	if not wreck and tilt:
		g.loft([Vector3(0, 2.2, BED_FRONT), Vector3(0, 2.2, BED_REAR)], [Vector2(1.1, 0.78), Vector2(1.1, 0.78)], Vector3.RIGHT,
			6, 0.0, p["canvas"], 0)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.9 * s, 0.66, -1.05), Vector3(0.2, 0.018, 0.75), p["paint_dark"], 0)


## One wheel (or a twin pair) on its hub: solid tyre, wooden felloe and spokes, hub cap.
static func wheel(lod := 0, twin := false, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var offs: Array = [-0.075, 0.075] if twin else [0.0]
	var n := 14 if lod == 0 else (8 if lod == 1 else 6)
	for ox: float in offs:
		if lod >= 2:
			g.loft([Vector3(ox - 0.06, 0, 0), Vector3(ox + 0.06, 0, 0)], [Vector2(WHEEL_R, WHEEL_R), Vector2(WHEEL_R, WHEEL_R)],
				Vector3.UP, 6, 0.0, p["tyre"], 0)
			continue
		var chord := TAU * WHEEL_R / float(n) * 0.56
		for k in n:
			var a := TAU * float(k) / float(n)
			var b := Basis(Vector3.RIGHT, a)
			if not wreck:
				g.box(b * Vector3(ox, WHEEL_R - 0.045, 0), Vector3(0.065, 0.046, chord), p["tyre"], 0, b)
			if lod == 0:
				g.box(b * Vector3(ox, WHEEL_R - 0.115, 0), Vector3(0.05, 0.03, chord * 0.86), p["wood_raw"] if not wreck else CHAR, 0, b)
		var ns := 10 if lod == 0 else 4
		for k in ns:
			if wreck and k % 3 == 1:
				continue
			var a := TAU * float(k) / float(ns)
			var b := Basis(Vector3.RIGHT, a)
			g.box(b * Vector3(ox, 0.21, 0), Vector3(0.025, 0.13, 0.022), p["wood_raw"] if not wreck else CHAR_BROWN, 0, b)
	g.loft([Vector3(-0.1 if twin else -0.07, 0, 0), Vector3(0.1 if twin else 0.07, 0, 0)], [Vector2(0.09, 0.09), Vector2(0.09, 0.09)],
		Vector3.UP, 8 if lod == 0 else 5, 0.0, p["chassis"], 0)
	return g


## The tailgate on its hinge (standing up when shut): boards, irons, the stencilled number.
static func tailgate(lod := 0, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	g.box(Vector3(0, 0.27, 0.0), Vector3(BED_HALF - 0.02, 0.27, 0.028), _w(p["wood"], wreck, Vector3(0, 0.3, 2.6)), 0)
	if lod == 0:
		for x in [-0.8, 0.0, 0.8]:
			g.box(Vector3(x, 0.27, 0.032), Vector3(0.03, 0.27, 0.006), p["chassis"], 0)
		if not wreck:
			for k in 3:
				g.box(Vector3(-0.35 + 0.12 * k, 0.32, 0.034), Vector3(0.04, 0.07, 0.003), Color(0.82, 0.80, 0.70), 0)
	return g


## Triangle counts for the report.
static func tri_counts(lod: int) -> int:
	return body(lod).tri_count() + 2 * wheel(lod).tri_count() + 2 * wheel(lod, true).tri_count() + tailgate(lod).tri_count()


static func _benches(g: UnitGeo, p: Dictionary, d0: bool, bz: float, bh: float) -> void:
	for s: float in [1.0, -1.0]:
		g.box(Vector3(BENCH_X * s, BENCH_TOP - 0.025, bz + 0.05), Vector3(0.17, 0.025, bh - 0.15), p["wood_raw"], 0)
		if d0:
			for z in [BED_FRONT + 0.4, bz, BED_REAR - 0.35]:
				g.box(Vector3(BENCH_X * s, (BENCH_TOP + FLOOR_Y) * 0.5, z), Vector3(0.14, (BENCH_TOP - FLOOR_Y) * 0.5, 0.02),
					p["wood_raw"], 0)
