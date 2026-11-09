extends RefCounted
## The light field gun, built in code in the faceted unit style (Question Chat, 2026-11-09).
## A generic WW1-era quick-firing field gun of about 75 mm: two big spoked wheels, a box
## trail with a spade, a steel shield, the barrel on a recoil cradle. Not a copy of a real one.
##
## Gun frame: the barrel points -Z, right is +X, the ground at y = 0, the origin on the
## ground under the axle. Pieces are separate so they can move:
##   carriage   origin on the axle centre: axle, trail, spade, shield (tips up when the trail is lifted)
##   cradle     origin on the trunnions (TRUNNION in the carriage frame), turns about X to elevate
##   barrel     in the cradle frame, slides back +Z on recoil
##   block      the breech block, origin on the breech face, slides down to open
##   wheel      origin on its hub, turning about X
##   handwheel  the elevating wheel (HANDWHEEL in the carriage frame), turning about X
## lod 0 close, 1 mid, 2 far. wreck = knocked out (charred, shield torn).

const WHEEL_R := 0.62
const TRACK := 0.74  # wheel centre, either side
const TRUNNION := Vector3(0, 0.2, 0.02)  # carriage frame
const BORE_Y := 0.1  # bore above the trunnions, cradle frame
const MUZZLE := Vector3(0, BORE_Y, -2.1)  # barrel frame
const BREECH := Vector3(0, BORE_Y, 0.5)  # rear face of the breech, barrel frame
const RECOIL := 0.85
const TRAIL_END := Vector3(0, -0.56, 2.85)  # spade foot, carriage frame (on the ground when level)
const LUNETTE := Vector3(0, -0.40, 3.02)  # towing eye, carriage frame
const HANDLE_R := Vector3(0.24, -0.40, 2.5)  # trail handles, carriage frame
const HANDLE_L := Vector3(-0.24, -0.40, 2.5)
const SPIKE_SOCKET := Vector3(0, -0.34, 2.7)
const HANDWHEEL := Vector3(-0.28, 0.14, 0.02)  # carriage frame
const SIGHT_EYE := Vector3(-0.22, 0.33, 0.24)  # cradle frame: where the layer's eye goes
const SEAT_L := Vector3(-0.42, 0.02, 0.36)  # axle seats (carriage frame, top of seat)
const SEAT_R := Vector3(0.42, 0.02, 0.36)

const PAINT := Color(0.38, 0.40, 0.29)
const PAINT_DARK := Color(0.29, 0.31, 0.22)
const STEEL := Color(0.20, 0.21, 0.20)
const BRIGHT := Color(0.46, 0.46, 0.43)
const WOOD := Color(0.47, 0.35, 0.21)
const BRASS := Color(0.72, 0.58, 0.28)
const SHELL_PAINT := Color(0.42, 0.42, 0.30)
const CHAR := Color(0.13, 0.12, 0.11)
const CHAR_BROWN := Color(0.22, 0.15, 0.10)
const RUST := Color(0.38, 0.21, 0.11)


static func _pal(wreck: bool) -> Dictionary:
	if not wreck:
		return {"paint": PAINT, "dark": PAINT_DARK, "steel": STEEL, "bright": BRIGHT, "wood": WOOD}
	return {"paint": CHAR_BROWN, "dark": CHAR, "steel": CHAR, "bright": RUST, "wood": CHAR}


static func _w(c: Color, wreck: bool, at: Vector3) -> Color:
	if not wreck:
		return c
	var h := absf(sin(at.x * 12.9898 + at.y * 78.233 + at.z * 37.719) * 43758.5453)
	h -= floorf(h)
	return RUST if h < 0.35 else (CHAR_BROWN if h < 0.6 else c)


## Axle, trail, spade, shield, seats, the elevating gear housing.
static func carriage(lod := 0, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _pal(wreck)
	var X := Vector3.RIGHT
	var U := Vector3.UP
	if lod >= 2:
		g.box(Vector3(0, 0, 0), Vector3(TRACK, 0.05, 0.05), p["steel"], 0)
		g.loft([Vector3(0, -0.02, 0.1), TRAIL_END + Vector3(0, 0.12, 0)], [Vector2(0.16, 0.1), Vector2(0.1, 0.07)], X, 4, 0.0,
			p["paint"], 0)
		g.box(Vector3(0, 0.3, -0.3), Vector3(0.66, 0.5, 0.02), p["paint"], 0, Basis(X, 0.12))
		return g
	var d0 := lod == 0
	var ch := 0.2 if d0 else 0.0
	# Axle tree and its hubs' collars.
	g.loft([Vector3(-TRACK + 0.06, 0, 0), Vector3(TRACK - 0.06, 0, 0)], [Vector2(0.045, 0.045), Vector2(0.045, 0.045)], U,
		8 if d0 else 5, 0.0, p["steel"], 0)
	g.box(Vector3(0, 0.02, 0.02), Vector3(0.3, 0.07, 0.1), _w(p["paint"], wreck, Vector3(0, 0, 0)), 0, Basis(), ch)
	# The box trail: two side plates closing in toward the spade, top and bottom flanges.
	for s: float in [1.0, -1.0]:
		var a := Vector3(0.19 * s, -0.02, 0.12)
		var b := Vector3(0.11 * s, TRAIL_END.y + 0.17, TRAIL_END.z - 0.05)
		g.loft([a, b], [Vector2(0.012, 0.13), Vector2(0.012, 0.075)], X, 4, 0.0, _w(p["paint"], wreck, a + b), 0)
		if d0:
			for k in 6:
				var u := (float(k) + 0.5) / 6.0
				var pt := a.lerp(b, u) + Vector3(0.014 * s, 0, 0)
				g.box(pt, Vector3(0.004, lerpf(0.11, 0.065, u), 0.006), p["dark"], 0)
	g.loft([Vector3(0, 0.1, 0.12), Vector3(0, TRAIL_END.y + 0.25, TRAIL_END.z - 0.1)], [Vector2(0.2, 0.01), Vector2(0.12, 0.01)],
		X, 4, 0.0, p["dark"], 0)
	g.loft([Vector3(0, -0.15, 0.2), Vector3(0, TRAIL_END.y + 0.1, TRAIL_END.z - 0.1)], [Vector2(0.2, 0.01), Vector2(0.12, 0.01)],
		X, 4, 0.0, p["dark"], 0)
	# Trail end: the spade, the towing eye, handles, the handspike socket.
	g.box(TRAIL_END + Vector3(0, 0.13, -0.05), Vector3(0.13, 0.06, 0.1), p["paint"], 0, Basis(), ch)
	g.box(TRAIL_END + Vector3(0, 0.02, 0.02), Vector3(0.2, 0.12, 0.012), p["steel"], 0, Basis(X, 0.35))
	if d0:
		var eye := LUNETTE
		for k in 8:
			var an := TAU * float(k) / 8.0
			g.box(eye + Vector3(0.045 * cos(an), 0, 0.045 * sin(an)), Vector3(0.018, 0.014, 0.012), p["steel"], 0, Basis(U, -an))
		g.box((eye + TRAIL_END) * 0.5 + Vector3(0, 0.12, -0.04), Vector3(0.025, 0.02, 0.12), p["steel"], 0)
		for hp: Vector3 in [HANDLE_R, HANDLE_L]:
			g.loft([Vector3(signf(hp.x) * 0.11, hp.y, hp.z), hp + Vector3(signf(hp.x) * 0.04, 0, 0)],
				[Vector2(0.018, 0.018), Vector2(0.018, 0.018)], U, 6, 0.0, p["steel"], 0)
		g.box(SPIKE_SOCKET, Vector3(0.05, 0.03, 0.04), p["steel"], 0)
	else:
		g.box(LUNETTE, Vector3(0.05, 0.015, 0.05), p["steel"], 0)
		for hp: Vector3 in [HANDLE_R, HANDLE_L]:
			g.box(hp, Vector3(0.06, 0.015, 0.015), p["steel"], 0)
	# Trunnion brackets the cradle sits in.
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.17 * s, 0.11, 0.02), Vector3(0.025, 0.11, 0.09), p["paint"], 0, Basis(), ch)
		if d0:
			g.loft([Vector3(0.14 * s, TRUNNION.y, TRUNNION.z), Vector3(0.2 * s, TRUNNION.y, TRUNNION.z)],
				[Vector2(0.04, 0.04), Vector2(0.04, 0.04)], U, 8, 0.0, p["steel"], 0)
	# Elevating gear: housing and shaft to the handwheel on the left.
	g.box(Vector3(-0.2, 0.1, 0.02), Vector3(0.04, 0.06, 0.05), p["dark"], 0, Basis(), ch)
	g.loft([Vector3(-0.2, HANDWHEEL.y, HANDWHEEL.z), HANDWHEEL], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)], U, 4, 0.0,
		p["steel"], 0)
	# Axle seats with foot rests (crew ride them on the march).
	for sp: Vector3 in [SEAT_L, SEAT_R]:
		g.box(sp + Vector3(0, -0.015, 0), Vector3(0.1, 0.015, 0.09), p["dark"], 0)
		g.box(sp + Vector3(0, 0.09, 0.09), Vector3(0.1, 0.08, 0.01), p["dark"], 0, Basis(X, 0.2))
		if d0:
			g.loft([sp + Vector3(0, -0.02, 0), Vector3(sp.x, -0.02, 0)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)], X, 4,
				0.0, p["steel"], 0)
	_shield(g, p, lod, wreck)
	return g


static func _shield(g: UnitGeo, p: Dictionary, lod: int, wreck: bool) -> void:
	var d0 := lod == 0
	var b := Basis(Vector3.RIGHT, 0.12)
	var z := -0.3
	var col: Color = _w(p["paint"], wreck, Vector3(0.3, 0.4, -0.3))
	# Upper shield in three plates around the barrel slot (top plate missing on a wreck).
	var plates := [[Vector3(-0.41, 0.36, z), Vector3(0.28, 0.4, 0.008)], [Vector3(0.41, 0.36, z), Vector3(0.28, 0.4, 0.008)],
		[Vector3(0, 0.07, z), Vector3(0.14, 0.11, 0.008)]]
	if not wreck:
		plates.append([Vector3(0, 0.66, z + 0.03), Vector3(0.14, 0.1, 0.008)])
	for i in plates.size():
		var pl: Array = plates[i]
		var bb := b
		var c: Vector3 = pl[0]
		if wreck and i == 1:
			bb = Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, -0.3) * b
			c += Vector3(0.08, -0.06, -0.1)
		g.box(c, pl[1], col, 0, bb)
	# Lower apron hung below the axle, between the wheels.
	g.box(Vector3(0, -0.26, -0.2), Vector3(0.52, 0.17, 0.007), col, 0, Basis(Vector3.RIGHT, -0.05))
	if d0:
		# Rolled edge along the top, a sighting port with its flap, stays to the axle.
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.41 * s, 0.76, z + 0.095), Vector3(0.28, 0.012, 0.014), p["dark"], 0, b)
			g.loft([Vector3(0.5 * s, 0.25, z + 0.06), Vector3(0.3 * s, 0.0, 0.0)], [Vector2(0.01, 0.01), Vector2(0.01, 0.01)],
				Vector3.UP, 4, 0.0, p["steel"], 0)
		if not wreck:
			g.box(Vector3(-0.25, 0.42, z + 0.07), Vector3(0.05, 0.035, 0.006), p["steel"], 0, b)
		for k in 10:
			var x := -0.62 + 0.1375 * k
			if absf(x) < 0.15:
				continue
			g.box(Vector3(x, 0.72, z + 0.098), Vector3(0.008, 0.008, 0.004), p["steel"], 0, b)


## Cradle: the recoil cylinder under the barrel, guides, the sight on the left.
static func cradle(lod := 0, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _pal(wreck)
	if lod >= 2:
		g.box(Vector3(0, 0.0, -0.15), Vector3(0.08, 0.06, 0.75), p["paint"], 0)
		return g
	var d0 := lod == 0
	g.loft([Vector3(0, -0.02, -1.05), Vector3(0, -0.02, 0.62)], [Vector2(0.075, 0.07), Vector2(0.075, 0.07)], Vector3.RIGHT,
		8 if d0 else 4, 0.02 if d0 else 0.0, _w(p["paint"], wreck, Vector3(0, 0, -0.4)), 0)
	g.box(Vector3(0, 0.04, -0.2), Vector3(0.1, 0.02, 0.8), p["dark"], 0)
	g.box(Vector3(0, -0.02, 0.0), Vector3(0.14, 0.05, 0.06), p["paint"], 0)
	if d0:
		g.loft([Vector3(0, -0.02, -1.08), Vector3(0, -0.02, -1.12)], [Vector2(0.06, 0.06), Vector2(0.05, 0.05)], Vector3.RIGHT, 8,
			0.0, p["steel"], 0)
		for zz in [-0.8, -0.4, 0.0, 0.4]:
			g.box(Vector3(0, -0.02, zz), Vector3(0.078, 0.073, 0.01), p["dark"], 0)
	# The sight: bracket, telescope, eyepiece toward the layer.
	g.box(Vector3(-0.16, 0.16, 0.06), Vector3(0.05, 0.02, 0.05), p["dark"], 0)
	g.loft([Vector3(-0.22, 0.31, -0.06), Vector3(-0.22, 0.31, 0.2)], [Vector2(0.025, 0.025), Vector2(0.03, 0.03)], Vector3.UP,
		6 if d0 else 4, 0.0, p["steel"], 0)
	g.box(Vector3(-0.22, 0.23, 0.06), Vector3(0.012, 0.08, 0.012), p["steel"], 0)
	return g


## The barrel, its breech ring and the breech lever.
static func barrel(lod := 0, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _pal(wreck)
	var B := BORE_Y
	if lod >= 2:
		g.loft([Vector3(0, B, MUZZLE.z), Vector3(0, B, 0.5)], [Vector2(0.05, 0.05), Vector2(0.09, 0.09)], Vector3.UP, 4, 0.0,
			p["steel"], 0)
		return g
	var d0 := lod == 0
	var n := 10 if d0 else 6
	var tube: Array = [Vector3(0, B, MUZZLE.z), Vector3(0, B, MUZZLE.z + 0.06), Vector3(0, B, -1.0), Vector3(0, B, -0.2),
		Vector3(0, B, 0.2)]
	var sz: Array = [Vector2(0.06, 0.06), Vector2(0.052, 0.052), Vector2(0.062, 0.062), Vector2(0.085, 0.085), Vector2(0.09, 0.09)]
	if wreck:
		tube[0] = Vector3(0.03, B + 0.05, MUZZLE.z + 0.15)
		sz[0] = Vector2(0.09, 0.06)
	g.loft(tube, sz, Vector3.UP, n, 0.0, p["steel"], 0)
	g.box(Vector3(0, B, 0.35), Vector3(0.11, 0.11, 0.15), _w(p["steel"], wreck, Vector3(0, 0.1, 0.35)), 0, Basis(), 0.25 if d0 else 0.0)
	# The bore (a dark disc at the muzzle) and the breech opening.
	g.loft([Vector3(0, B, MUZZLE.z - 0.001), Vector3(0, B, MUZZLE.z - 0.002)], [Vector2(0.04, 0.04), Vector2(0.04, 0.04)],
		Vector3.UP, n, 0.0, Color(0.05, 0.05, 0.05), 0, null, 1)
	g.box(BREECH + Vector3(0, 0, 0.001), Vector3(0.04, 0.04, 0.002), Color(0.05, 0.05, 0.05), 0)
	if d0:
		g.loft([Vector3(0, B, -0.25), Vector3(0, B, -0.15)], [Vector2(0.095, 0.095), Vector2(0.095, 0.095)], Vector3.UP, n, 0.0,
			p["dark"], 0)
		g.loft([Vector3(0.11, B - 0.04, 0.45), Vector3(0.2, B - 0.1, 0.55)], [Vector2(0.012, 0.012), Vector2(0.015, 0.015)],
			Vector3.UP, 4, 0.0, p["bright"], 0)
	return g


## Breech block: a plate that slides down out of the ring to open.
static func block(lod := 0, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _pal(wreck)
	g.box(Vector3(0, 0, 0.02), Vector3(0.085, 0.08, 0.02), p["bright"] if not wreck else CHAR, 0)
	if lod == 0:
		g.box(Vector3(0.05, -0.03, 0.045), Vector3(0.015, 0.015, 0.012), p["steel"], 0)
	return g


## A gun wheel: iron tyre on a wooden felloe, twelve spokes, a big hub.
static func wheel(lod := 0, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _pal(wreck)
	if lod >= 2:
		g.loft([Vector3(-0.04, 0, 0), Vector3(0.04, 0, 0)], [Vector2(WHEEL_R, WHEEL_R), Vector2(WHEEL_R, WHEEL_R)], Vector3.UP, 6,
			0.0, p["wood"], 0)
		return g
	var n := 16 if lod == 0 else 10
	var chord := TAU * WHEEL_R / float(n) * 0.56
	for k in n:
		var a := TAU * float(k) / float(n)
		var b := Basis(Vector3.RIGHT, a)
		g.box(b * Vector3(0, WHEEL_R - 0.012, 0), Vector3(0.045, 0.013, chord), p["steel"], 0, b)
		g.box(b * Vector3(0, WHEEL_R - 0.06, 0), Vector3(0.035, 0.036, chord * 0.95), p["wood"], 0, b)
	var ns := 12 if lod == 0 else 6
	for k in ns:
		if wreck and k % 4 == 1:
			continue
		var a := TAU * float(k) / float(ns)
		var b := Basis(Vector3.RIGHT, a)
		g.box(b * Vector3(0, 0.33, 0), Vector3(0.018, 0.22, 0.016), p["wood"], 0, b)
	g.loft([Vector3(-0.11, 0, 0), Vector3(0.09, 0, 0)], [Vector2(0.075, 0.075), Vector2(0.09, 0.09)], Vector3.UP,
		8 if lod == 0 else 5, 0.0, p["steel"], 0)
	return g


## The elevating handwheel (turns about X).
static func handwheel(lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var n := 8 if lod == 0 else 4
	for k in n:
		var a := TAU * float(k) / float(n)
		var b := Basis(Vector3.RIGHT, a)
		g.box(b * Vector3(0, 0.1, 0), Vector3(0.01, 0.01, 0.042), STEEL, 0, b)
	g.box(Vector3.ZERO, Vector3(0.008, 0.1, 0.008), STEEL, 0)
	g.box(Vector3(-0.03, 0.1, 0), Vector3(0.03, 0.012, 0.012), WOOD, 0)
	return g


## A complete round (case + shell), base at the origin, nose along -Z.
static func round_mesh(with_shell := true) -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(0, 0, 0), Vector3(0, 0, -0.3)], [Vector2(0.044, 0.044), Vector2(0.04, 0.04)], Vector3.UP, 8, 0.0, BRASS, 0)
	g.loft([Vector3(0, 0, 0.0), Vector3(0, 0, 0.008)], [Vector2(0.05, 0.05), Vector2(0.05, 0.05)], Vector3.UP, 8, 0.0, BRASS, 0)
	if with_shell:
		g.loft([Vector3(0, 0, -0.3), Vector3(0, 0, -0.42), Vector3(0, 0, -0.49), Vector3(0, 0, -0.53)],
			[Vector2(0.038, 0.038), Vector2(0.038, 0.038), Vector2(0.024, 0.024), Vector2(0.008, 0.008)], Vector3.UP, 8, 0.0,
			SHELL_PAINT, 0)
		g.loft([Vector3(0, 0, -0.33), Vector3(0, 0, -0.35)], [Vector2(0.04, 0.04), Vector2(0.04, 0.04)], Vector3.UP, 8, 0.0,
			Color(0.55, 0.32, 0.18), 0)
	return g


## A wooden ammunition box holding four rounds (lid hinged at the back, open 0..1).
static func ammo_box(open := 0.0, rounds := 4) -> UnitGeo:
	var g := UnitGeo.new()
	g.box(Vector3(0, 0.08, 0), Vector3(0.3, 0.08, 0.17), WOOD, 0, Basis(), 0.1)
	g.box(Vector3(0, 0.161, 0), Vector3(0.28, 0.002, 0.15), Color(0.2, 0.15, 0.1), 0)
	for k in rounds:
		var r := round_mesh()
		var x := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.26, 0.13, -0.11 + 0.075 * k))
		for i in range(0, r.pos.size(), 3):
			g.emit(x * r.pos[i], x * r.pos[i + 2], x * r.pos[i + 1], r.col[i], 0)
	var lid := Basis(Vector3.RIGHT, -open * 1.9)
	var hinge := Vector3(0, 0.16, 0.17)
	g.box(hinge + lid * Vector3(0, 0.012, -0.17), Vector3(0.3, 0.012, 0.17), WOOD.darkened(0.08), 0, lid)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.31 * s, 0.1, 0), Vector3(0.01, 0.02, 0.06), STEEL, 0)
	return g


## A loading ramp plank (length along -Z from the origin, up to the bed).
static func ramp(length: float) -> UnitGeo:
	var g := UnitGeo.new()
	g.box(Vector3(0, 0.03, -length * 0.5), Vector3(0.16, 0.03, length * 0.5), WOOD, 0)
	for k in 6:
		g.box(Vector3(0, 0.065, -length * (k + 0.5) / 6.0), Vector3(0.15, 0.008, 0.015), WOOD.darkened(0.2), 0)
	return g


## The handspike: a wooden pole with an iron end that fits the trail socket.
static func handspike() -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(0, 0, 0), Vector3(0, 0, 1.3)], [Vector2(0.022, 0.022), Vector2(0.018, 0.018)], Vector3.UP, 6, 0.0, WOOD, 0)
	g.box(Vector3(0, 0, 0.0), Vector3(0.024, 0.024, 0.05), STEEL, 0)
	return g


static func tri_counts(lod: int, wreck := false) -> int:
	return carriage(lod, wreck).tri_count() + cradle(lod, wreck).tri_count() + barrel(lod, wreck).tri_count() \
		+ block(lod, wreck).tri_count() + 2 * wheel(lod, wreck).tri_count() + (handwheel(lod).tri_count() if lod < 2 else 0)
