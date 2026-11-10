class_name ArmourBuilder
extends RefCounted
## Heavy armoured trench troops (Building Chat 1, 2026-11-10): our melee unit, a WW1 "riot police" look.
## The rifleman's body (SoldierBuilder) under full trench armour: overlapping belly lames and a breastplate, a
## gorget, shoulder plates, armoured forearms, thigh tassets, knee plates, and a deep steel helmet with a heavy brow
## plate and a slit visor. Gloved, no pack, a holster on the right hip.
## Two roles:
##   shield  the tall slit shield (a separate node, see Armoured) and a club in the right hand
##   club    a trench club, flanged mace or sharpened spade in the right hand, the left hand free
## Hand items are props on the item bone (built here in the item bone's own frame, grip at B.GRIP_R, head along -Z).

const B := preload("res://scripts/units/soldier_builder.gd")

const STEEL := Color(0.40, 0.41, 0.34)
const STEEL_DARK := Color(0.25, 0.27, 0.23)
const STEEL_EDGE := Color(0.47, 0.49, 0.44)
const RIVET := Color(0.58, 0.58, 0.54)
const SLIT := Color(0.05, 0.05, 0.05)
const PAINT := Color(0.86, 0.84, 0.76)  # the white unit chevron
const IRON := Color(0.2, 0.2, 0.21)
const WEAPONS: Array[String] = ["club", "mace", "spade"]

## The shield (its own frame: the handle at the origin, the face towards -Z, up +Y).
const SHIELD_W := 0.31      # half width of the centre panel and wings together
const SHIELD_TOP := 0.6
const SHIELD_BOT := -0.62
const SHIELD_X := 0.08      # the shield's centre sits this far to the hand's right
const SLIT_Y := 0.47


static func look_for_role(seed_value: int, role: String) -> Dictionary:
	var lk := B.look_from_seed(seed_value)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 131 + 7
	lk.merge({"role": role, "rifle": false, "pistol": false, "pack": false, "roll": 0, "shovel": false, "canteen": 0,
		"webbing": false, "gloves": true, "bare": true, "net": false, "build": r.randf_range(1.04, 1.14),
		"weapon": "club" if role == "shield" else WEAPONS[r.randi() % WEAPONS.size()],
		"visor_up": false, "chevron": r.randf() < 0.5}, true)
	return lk


static func build(look: Dictionary, lod: int) -> UnitGeo:
	var g := B.build(look, lod)
	var w: float = look.get("build", 1.0)
	if lod >= 2:
		_far(g, w)
		return g
	var d0 := lod == 0
	var sides := 8 if d0 else 4
	var X := Vector3.RIGHT
	# Belly lames (each flares at its lower edge so they read as overlapping bands) and the breastplate.
	var lames: Array = [[0.975, 1.06, B.HIPS], [1.045, 1.13, B.SPINE], [1.115, 1.2, B.SPINE]]
	if not d0:
		lames = [[0.975, 1.2, B.SPINE]]
	for i in lames.size():
		var L: Array = lames[i]
		g.loft([Vector3(0, L[0], 0.0), Vector3(0, L[1], 0.0)],
			[Vector2(0.205, 0.142) * w, Vector2(0.192, 0.132) * w], X, sides, 0.3 if d0 else 0.0,
			STEEL if i % 2 == 0 else STEEL.darkened(0.06), L[2], STEEL_DARK if d0 else null, 1)
	g.loft([Vector3(0, 1.19, 0.0), Vector3(0, 1.34, -0.012), Vector3(0, 1.45, 0.0), Vector3(0, 1.5, 0.012)],
		[Vector2(0.198, 0.146) * w, Vector2(0.222, 0.152) * w, Vector2(0.225, 0.14) * w, Vector2(0.14, 0.1) * w],
		X, sides, 0.3 if d0 else 0.0, STEEL, B.CHEST, null, 2)
	# Gorget.
	g.loft([Vector3(0, 1.46, 0.008), Vector3(0, 1.55, 0.004)], [Vector2(0.13, 0.11) * w, Vector2(0.085, 0.08)],
		X, sides, 0.0, STEEL_DARK, B.CHEST, null, 0)
	if d0:
		# The breastplate's middle ridge, its rolled lower edge, rivets; a leather belt over the lames.
		g.box(Vector3(0, 1.33, -0.163 * w), Vector3(0.012, 0.11, 0.008), STEEL_EDGE, B.CHEST)
		g.loft([Vector3(0, 1.19, 0.0), Vector3(0, 1.21, 0.0)], [Vector2(0.204, 0.15) * w, Vector2(0.204, 0.15) * w],
			X, sides, 0.3, STEEL_EDGE, B.CHEST, null, 0)
		for s: float in [1.0, -1.0]:
			for k in 3:
				g.box(Vector3(0.15 * s * w, 1.25 + 0.08 * k, -0.15 * w + 0.01 * k), Vector3(0.009, 0.009, 0.006), RIVET, B.CHEST)
			for k in 3:
				var L2: Array = lames[k]
				g.box(Vector3(0.16 * s * w, float(L2[0]) + 0.03, -0.128 * w), Vector3(0.008, 0.008, 0.008), RIVET, L2[2])
		g.loft([Vector3(0, 0.955, 0.0), Vector3(0, 0.995, 0.0)], [Vector2(0.21, 0.15) * w, Vector2(0.21, 0.15) * w],
			X, sides, 0.3, B.LEATHER, B.HIPS, null, 0)
		g.box(Vector3(0, 0.975, -0.152 * w), Vector3(0.03, 0.024, 0.006), B.BRASS, B.HIPS)
	# Shoulder plates (two lames each), armoured forearms, thigh tassets, knee plates.
	for s: float in [1.0, -1.0]:
		var ua := B.bone_side(s, B.UARM_R, B.UARM_L)
		g.loft([Vector3(0.19 * s, 1.535, 0.0), Vector3(0.235 * s, 1.47, 0.0), Vector3(0.255 * s, 1.38, 0.0)],
			[Vector2(0.06, 0.07), Vector2(0.1, 0.105), Vector2(0.098, 0.104)], X, sides, 0.0, STEEL, ua, null, 2)
		if d0:
			g.loft([Vector3(0.25 * s, 1.385, 0.0), Vector3(0.255 * s, 1.31, 0.0)],
				[Vector2(0.09, 0.096), Vector2(0.086, 0.092)], X, sides, 0.0, STEEL.darkened(0.06), ua, null, 0)
			if look.get("chevron", false) and s > 0.0:
				for e: float in [-1.0, 1.0]:
					g.loft([Vector3(0.335, 1.42, 0.045 * e), Vector3(0.343, 1.37, 0.0)],
						[Vector2(0.005, 0.012), Vector2(0.005, 0.012)], X, 4, 0.0, PAINT, ua)
		var fa := B.bone_side(s, B.FARM_R, B.FARM_L)
		g.loft([Vector3(0.226 * s, 1.1, 0.0), Vector3(0.238 * s, 0.92, 0.0)],
			[Vector2(0.07, 0.075), Vector2(0.064, 0.068)], X, 6 if d0 else 4, 0.0, STEEL, fa, STEEL_DARK if d0 else null, 1)
		var th := B.bone_side(s, B.THIGH_R, B.THIGH_L)
		var tb := Basis(Vector3.RIGHT, 0.12) * Basis(Vector3.FORWARD, 0.1 * s)
		g.box(Vector3(0.105 * s, 0.86, -0.1), Vector3(0.085, 0.1, 0.014), STEEL, th, tb, 0.3 if d0 else 0.0)
		if d0:
			g.box(Vector3(0.105 * s, 0.755, -0.098), Vector3(0.08, 0.04, 0.012), STEEL.darkened(0.06), th, tb)
			g.box(Vector3(0.105 * s, 0.94, -0.112), Vector3(0.008, 0.008, 0.006), RIVET, th)
		var sh := B.bone_side(s, B.SHIN_R, B.SHIN_L)
		g.box(Vector3(0.1 * s, 0.51, -0.07), Vector3(0.065, 0.06, 0.02), STEEL, sh, Basis(), 0.3 if d0 else 0.0)
		if d0:
			g.box(Vector3(0.1 * s, 0.33, -0.068), Vector3(0.05, 0.12, 0.012), STEEL_DARK, sh)
	# Holster on the right hip, outside the lames.
	g.box(Vector3(0.215 * w, 0.95, -0.05), Vector3(0.028, 0.065, 0.045), B.LEATHER, B.HIPS, Basis(Vector3.FORWARD, 0.15), 0.2 if d0 else 0.0)
	_helmet(g, look, d0)
	return g


## The deep helmet: a steel dome sweeping down at the back and sides, a heavy brow plate bolted on the front,
## and the visor (a face plate with an eye slit and breathing holes).
static func _helmet(g: UnitGeo, look: Dictionary, d0: bool) -> void:
	var X := Vector3.RIGHT
	var hs := 10 if d0 else 6
	var H := B.HEAD
	# The dome, and the skirt flaring over the neck and ears.
	g.loft([Vector3(0, 1.68, 0.012), Vector3(0, 1.76, 0.005), Vector3(0, 1.84, 0.006), Vector3(0, 1.89, 0.008), Vector3(0, 1.905, 0.01)],
		[Vector2(0.142, 0.154), Vector2(0.138, 0.15), Vector2(0.118, 0.13), Vector2(0.07, 0.078), Vector2(0.0, 0.0)],
		X, hs, 0.0, STEEL, H, null, 1)
	g.loft([Vector3(0, 1.58, 0.04), Vector3(0, 1.69, 0.016)], [Vector2(0.16, 0.15), Vector2(0.142, 0.152)],
		X, hs, 0.0, STEEL.darkened(0.05), H, null, 0)
	# Brow plate.
	g.box(Vector3(0, 1.77, -0.152), Vector3(0.11, 0.045, 0.014), STEEL_DARK, H, Basis(Vector3.RIGHT, -0.18), 0.3 if d0 else 0.0)
	# The visor.
	var up: bool = look.get("visor_up", false)
	var vb := Basis(Vector3.RIGHT, -1.2) if up else Basis(Vector3.RIGHT, 0.08)
	var vc := Vector3(0, 1.79, -0.15) if up else Vector3(0, 1.655, -0.135)
	g.box(vc, Vector3(0.092, 0.078, 0.012), STEEL, H, vb, 0.3 if d0 else 0.0)
	g.box(vc + vb * Vector3(0, 0.035, -0.012), Vector3(0.072, 0.008, 0.005), SLIT, H, vb)
	if d0:
		g.box(vc + vb * Vector3(0, -0.02, -0.016), Vector3(0.008, 0.045, 0.008), STEEL_EDGE, H, vb)
		for k in 4:
			for s: float in [1.0, -1.0]:
				g.box(vc + vb * Vector3(s * (0.025 + 0.012 * (k % 2)), -0.015 - 0.016 * k, -0.013), Vector3(0.004, 0.004, 0.004), SLIT, H, vb)
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.112 * s, 1.765, -0.13), Vector3(0.012, 0.012, 0.008), RIVET, H)
		g.box(Vector3(0, 1.84, -0.125), Vector3(0.012, 0.012, 0.006), RIVET, H)


## The far version: a steel cuirass, the helmet and visor as plain shapes.
static func _far(g: UnitGeo, w: float) -> void:
	var X := Vector3.RIGHT
	g.loft([Vector3(0, 0.98, 0), Vector3(0, 1.48, 0)], [Vector2(0.205, 0.14) * w, Vector2(0.22, 0.14) * w], X, 4, 0.0, STEEL, B.CHEST)
	g.loft([Vector3(0, 1.6, 0.03), Vector3(0, 1.75, 0.005), Vector3(0, 1.9, 0.01)],
		[Vector2(0.16, 0.15), Vector2(0.14, 0.15), Vector2(0.06, 0.07)], X, 4, 0.0, STEEL, B.HEAD)
	g.box(Vector3(0, 1.66, -0.135), Vector3(0.09, 0.09, 0.012), STEEL_DARK, B.HEAD)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.235 * s, 1.45, 0), Vector3(0.09, 0.07, 0.1), STEEL, B.bone_side(s, B.UARM_R, B.UARM_L))


# ---------------------------------------------------------------- the shield

## The tall shield: a centre panel and two wings bent back (it reads curved), a rolled rim, the vision slit
## under a little hood, a firing port, rivets, the white chevron; the handle and arm strap behind.
static func shield(lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var d0 := lod == 0
	var c := Vector3(SHIELD_X, (SHIELD_TOP + SHIELD_BOT) * 0.5, -0.085)
	var hh := (SHIELD_TOP - SHIELD_BOT) * 0.5
	var cw := 0.15
	g.box(c, Vector3(cw, hh, 0.01), STEEL, 0, Basis(), 0.0)
	for s: float in [1.0, -1.0]:
		var wb := Basis(Vector3.UP, -0.42 * s)
		var wc := c + Vector3(cw * s, 0, 0) + wb * Vector3((SHIELD_W - cw) * 0.5 * s, 0, 0)
		g.box(wc, Vector3((SHIELD_W - cw) * 0.5, hh, 0.01), STEEL.darkened(0.04), 0, wb)
		if d0:
			var ec := c + Vector3(cw * s, 0, 0) + wb * Vector3((SHIELD_W - cw) * s, 0, 0)
			g.box(ec, Vector3(0.012, hh, 0.016), STEEL_DARK, 0, wb)
	if lod >= 2:
		return g
	# Top and bottom rims.
	for e: float in [1.0, -1.0]:
		g.box(c + Vector3(0, hh * e, 0), Vector3(cw, 0.014, 0.016), STEEL_DARK, 0)
	# Vision slit and its hood.
	var sy := SLIT_Y
	g.box(Vector3(SHIELD_X, sy, -0.096), Vector3(0.075, 0.01, 0.004), SLIT, 0)
	g.box(Vector3(SHIELD_X, sy + 0.03, -0.11), Vector3(0.09, 0.008, 0.028), STEEL_DARK, 0, Basis(Vector3.RIGHT, 0.25))
	if d0:
		# Firing port with its swivel cover, rivets round the edge, the chevron, the handle and strap behind.
		g.box(Vector3(SHIELD_X + 0.07, 0.12, -0.096), Vector3(0.028, 0.028, 0.004), SLIT, 0)
		g.box(Vector3(SHIELD_X + 0.07, 0.07, -0.1), Vector3(0.036, 0.034, 0.006), STEEL_DARK, 0, Basis(Vector3.FORWARD, 0.4))
		for k in 7:
			var y := SHIELD_BOT + 0.08 + (SHIELD_TOP - SHIELD_BOT - 0.16) * k / 6.0
			for s: float in [1.0, -1.0]:
				g.box(Vector3(SHIELD_X + 0.13 * s, y, -0.097), Vector3(0.007, 0.007, 0.004), RIVET, 0)
		for e: float in [-1.0, 1.0]:
			g.loft([Vector3(SHIELD_X + 0.11 * e, -0.2, -0.097), Vector3(SHIELD_X, -0.32, -0.097)],
				[Vector2(0.004, 0.018), Vector2(0.004, 0.018)], Vector3.BACK, 4, 0.0, PAINT, 0)
			g.loft([Vector3(SHIELD_X + 0.11 * e, -0.3, -0.097), Vector3(SHIELD_X, -0.42, -0.097)],
				[Vector2(0.004, 0.018), Vector2(0.004, 0.018)], Vector3.BACK, 4, 0.0, PAINT, 0)
	g.box(Vector3(0, 0, -0.045), Vector3(0.05, 0.012, 0.012), B.LEATHER if d0 else IRON, 0)
	for e: float in [-1.0, 1.0]:
		g.box(Vector3(0.05 * e, 0, -0.06), Vector3(0.008, 0.012, 0.02), IRON, 0)
	if d0:
		g.box(Vector3(0.0, 0.2, -0.06), Vector3(0.07, 0.018, 0.012), B.LEATHER, 0)
	return g


# ---------------------------------------------------------------- hand items (item bone frame)

static func _shifted(g: UnitGeo) -> UnitGeo:
	var o: Vector3 = B.REST[B.RIFLE]
	for k in g.pos.size():
		g.pos[k] -= o
	return g


static func weapon(kind: String, lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var o: Vector3 = B.REST[B.RIFLE]
	var X := Vector3.RIGHT
	var y := -0.015
	var R := B.RIFLE
	var n := 6 if lod == 0 else 4
	match kind:
		"club":
			TroopKit.weapon(g, "club", lod)
		"mace":
			# A steel-shod haft and a flanged iron head with a spike on top.
			g.loft([o + Vector3(0, y, 0.14), o + Vector3(0, y, -0.34)], [Vector2(0.016, 0.016), Vector2(0.019, 0.019)],
				X, n, 0.0, B.WOOD_DARK, R)
			g.loft([o + Vector3(0, y, 0.15), o + Vector3(0, y, 0.11)], [Vector2(0.02, 0.02), Vector2(0.02, 0.02)], X, n, 0.0, IRON, R)
			g.loft([o + Vector3(0, y, -0.33), o + Vector3(0, y, -0.47)], [Vector2(0.03, 0.03), Vector2(0.03, 0.03)], X, n, 0.0, IRON, R)
			for k in (6 if lod == 0 else 4):
				var a := TAU * k / float(6 if lod == 0 else 4)
				var b := Basis(Vector3.BACK, a)
				g.box(o + Vector3(0, y, -0.4) + b * Vector3(0, 0.042, 0), Vector3(0.006, 0.026, 0.06), STEEL_DARK, R, b)
			g.loft([o + Vector3(0, y, -0.47), o + Vector3(0, y, -0.55)], [Vector2(0.018, 0.018), Vector2(0.0, 0.0)], X, 4, 0.0, IRON, R)
		"spade":
			# A short entrenching spade, its edges ground sharp (the bright rim).
			g.loft([o + Vector3(0, y, 0.12), o + Vector3(0, y, -0.32)], [Vector2(0.016, 0.016), Vector2(0.017, 0.017)],
				X, n, 0.0, B.WOOD, R)
			g.box(o + Vector3(0, y, 0.13), Vector3(0.045, 0.012, 0.012), B.WOOD_DARK, R)
			g.box(o + Vector3(0, y, -0.34), Vector3(0.022, 0.022, 0.04), IRON, R)
			g.box(o + Vector3(0, y, -0.47), Vector3(0.085, 0.006, 0.1), STEEL_DARK, R)
			if lod == 0:
				g.box(o + Vector3(0, y, -0.572), Vector3(0.08, 0.007, 0.006), STEEL_EDGE, R)
				for s: float in [1.0, -1.0]:
					g.box(o + Vector3(0.087 * s, y, -0.47), Vector3(0.005, 0.007, 0.09), STEEL_EDGE, R)
	return _shifted(g)


static func pistol(lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	B._build_pistol(g, lod)
	return _shifted(g)
