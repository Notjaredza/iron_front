class_name TroopKit
extends RefCounted
## Kit for the four troop types (Question Chat, 2026-11-09): the assault section, the
## sniper pair, the light machine gun team and the light mortar team. Generic pieces in
## the faceted style, not copies of real ones.
## Weapons go on the soldier's item bone in the rifle's frame (barrel -Z, grips at
## SoldierBuilder.GRIP_R / GRIP_L / BUTT), so every rifle carry and move works with them.
## Props are static meshes in their own frames (turn them into meshes with MG.mesh):
##   drum        the LMG's pan magazine; origin bottom centre, flat in XZ
##   bipod_legs  the LMG's bipod legs between a hinge point and two feet (any frame)
##   plate       the mortar baseplate; origin bottom centre, the socket at PLATE_SOCKET
##   tube        the mortar tube along +Y from its base; bipod open 0..1 (MORTAR frame legs)
##   bomb        a mortar bomb; origin at its middle, nose +Y, fins -Y
##   grenade     a stick grenade; origin at the grip, the head toward +Y

const W := SoldierBuilder.RIFLE
const CAPE_A := Color(0.38, 0.40, 0.25)
const CAPE_B := Color(0.47, 0.44, 0.28)
const CAPE_C := Color(0.30, 0.31, 0.20)
const CANVAS := Color(0.55, 0.50, 0.35)
const CANVAS_DARK := Color(0.44, 0.40, 0.27)
const STEEL := Color(0.21, 0.22, 0.21)
const STEEL_DARK := Color(0.13, 0.13, 0.14)
const JACKET := Color(0.27, 0.30, 0.22)
const PAINT := Color(0.34, 0.38, 0.23)
const BOMB_RING := Color(0.62, 0.52, 0.30)
const NAILS := Color(0.45, 0.45, 0.44)

## Weapon points (rifle frame, relative to the item bone's rest).
const CARBINE_MUZZLE := Vector3(0, 0.03, -0.63)
const SCOPE_EYE := Vector3(0, 0.105, 0.10)
const LMG_MUZZLE := Vector3(0, 0.01, -0.82)
const LMG_DRUM := Vector3(0, 0.05, -0.09)  # the drum's bottom centre on the gun
const LMG_HINGE := Vector3(0, -0.03, -0.56)  # the bipod's hinge under the jacket
const LMG_FOLDED := [Vector3(0.025, -0.045, -0.24), Vector3(-0.025, -0.045, -0.24)]  # folded feet
const CLUB_HEAD := Vector3(0, -0.015, -0.36)

## The assembled mortar (its frame: the plate on the ground at the origin, firing toward -Z).
const PLATE_SOCKET := Vector3(0, 0.045, 0.02)
const ELEV := 0.96  # tube elevation (radians, about 55 degrees)
const TUBE_LEN := 0.78
const TUBE_R := 0.032
const COLLAR := 0.50  # how far up the tube the bipod clamps
const MORTAR_FEET := [Vector3(0.21, 0.0, -0.56), Vector3(-0.21, 0.0, -0.56)]
const BOMB_LEN := 0.30


# ---------------------------------------------------------------- on the body

## Kit flags on the soldier: grenade bags, the sniper's cape, drum pouches, bomb bags,
## the baseplate man's straps.
static func body_kit(g: UnitGeo, look: Dictionary, d0: bool, w: float) -> void:
	var B := SoldierBuilder
	var X := Vector3.RIGHT
	if look.get("grenade_bags", false):
		# Two canvas bags on the hips, stick grenade handles showing; the straps cross the chest.
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.19 * s * w, 0.97, 0.01), Vector3(0.035, 0.075, 0.075), CANVAS, B.HIPS, Basis(), 0.2 if d0 else 0.0)
			if d0:
				g.box(Vector3(0.19 * s * w, 1.04, 0.01), Vector3(0.038, 0.012, 0.078), CANVAS_DARK, B.HIPS)
				for k in 3:
					var z := -0.045 + 0.045 * k
					g.loft([Vector3(0.19 * s * w, 1.04, z), Vector3(0.19 * s * w + 0.01 * s, 1.13, z + 0.01)],
						[Vector2(0.011, 0.011), Vector2(0.011, 0.011)], X, 4, 0.0, B.WOOD, B.HIPS)
				g.loft([Vector3(0.19 * s * w, 1.04, -0.06), Vector3(-0.06 * s, 1.30, -0.15 * w), Vector3(-0.12 * s, 1.51, -0.02)],
					[Vector2(0.018, 0.005), Vector2(0.018, 0.005), Vector2(0.018, 0.005)], X, 4, 0.0, CANVAS_DARK, B.CHEST, null, 0)
	if look.get("cape", false):
		# A short hooded cape over the shoulders and a long back panel, mottled.
		var cs := 10 if d0 else 6
		g.loft([Vector3(0, 1.53, 0.015), Vector3(0, 1.46, 0.02), Vector3(0, 1.30, 0.03)],
			[Vector2(0.13, 0.10) * w, Vector2(0.26, 0.16) * w, Vector2(0.27, 0.17) * w], X, cs, 0.0, CAPE_A, B.CHEST,
			CAPE_B if d0 else null, 0)
		g.loft([Vector3(0, 1.40, 0.13 * w), Vector3(0, 1.10, 0.16 * w), Vector3(0, 0.80, 0.17 * w)],
			[Vector2(0.24, 0.035) * w, Vector2(0.25, 0.035) * w, Vector2(0.23, 0.03) * w], X, 6 if d0 else 4, 0.0, CAPE_A,
			B.CHEST, CAPE_C if d0 else null, 2)
		if d0:
			# Torn scrim strips hanging at the hem.
			for k in 5:
				var x := (-0.2 + 0.1 * k) * w
				g.box(Vector3(x, 0.76, 0.17 * w), Vector3(0.018, 0.05, 0.006), [CAPE_B, CAPE_C][k % 2], B.CHEST)
	if look.get("drum_pouches", false):
		# Square canvas carriers for two spare drums on each hip.
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.2 * s * w, 0.98, 0.03), Vector3(0.045, 0.095, 0.095), CANVAS, B.HIPS, Basis(), 0.25 if d0 else 0.0)
			if d0:
				g.box(Vector3(0.2 * s * w, 1.07, 0.03), Vector3(0.048, 0.014, 0.098), CANVAS_DARK, B.HIPS)
				g.loft([Vector3(0.2 * s * w, 1.07, 0.03), Vector3(0.0, 1.30, -0.15 * w * s), Vector3(-0.12 * s, 1.51, 0.0)],
					[Vector2(0.02, 0.005), Vector2(0.02, 0.005), Vector2(0.02, 0.005)], X, 4, 0.0, CANVAS_DARK, B.CHEST, null, 0)
	if look.get("bomb_bags", false):
		# Front and back carriers, the bombs' tails showing over the top of the back one.
		g.box(Vector3(0, 1.22, -0.165 * w), Vector3(0.12 * w, 0.1, 0.04), CANVAS, B.CHEST, Basis(), 0.2 if d0 else 0.0)
		g.box(Vector3(0, 1.25, 0.17 * w), Vector3(0.13 * w, 0.14, 0.05), CANVAS, B.CHEST, Basis(), 0.2 if d0 else 0.0)
		if d0:
			g.box(Vector3(0, 1.31, -0.165 * w), Vector3(0.122 * w, 0.014, 0.042), CANVAS_DARK, B.CHEST)
			for k in 3:
				var x := (-0.07 + 0.07 * k) * w
				g.loft([Vector3(x, 1.38, 0.17 * w), Vector3(x, 1.46, 0.17 * w)], [Vector2(0.03, 0.03), Vector2(0.03, 0.03)],
					X, 6, 0.0, STEEL, B.CHEST)
			for s: float in [1.0, -1.0]:
				g.loft([Vector3(0.1 * s * w, 1.13, -0.17 * w), Vector3(0.12 * s, 1.51, -0.02), Vector3(0.11 * s * w, 1.38, 0.16 * w)],
					[Vector2(0.022, 0.006), Vector2(0.022, 0.006), Vector2(0.022, 0.006)], X, 4, 0.0, CANVAS_DARK, B.CHEST, null, 0)
	if look.get("plate_straps", false) and d0:
		for s: float in [1.0, -1.0]:
			g.loft([Vector3(0.09 * s * w, 1.08, -0.13 * w), Vector3(0.11 * s * w, 1.34, -0.14 * w), Vector3(0.12 * s, 1.51, -0.02),
					Vector3(0.10 * s * w, 1.40, 0.13 * w)],
				[Vector2(0.024, 0.006), Vector2(0.024, 0.006), Vector2(0.024, 0.006), Vector2(0.024, 0.006)], X, 4, 0.0,
				B.LEATHER, B.CHEST, null, 0)


## The sniper pair's hood (in place of the helmet), open at the face.
static func hood(g: UnitGeo, d0: bool) -> void:
	var B := SoldierBuilder
	var hs := 10 if d0 else 6
	g.loft([Vector3(0, 1.56, 0.05), Vector3(0, 1.66, 0.04), Vector3(0, 1.76, 0.03), Vector3(0, 1.83, 0.035), Vector3(0, 1.86, 0.04)],
		[Vector2(0.105, 0.11), Vector2(0.118, 0.135), Vector2(0.12, 0.138), Vector2(0.095, 0.11), Vector2(0.0, 0.0)],
		Vector3.RIGHT, hs, 0.0, CAPE_A, B.HEAD, CAPE_B if d0 else null, 0)
	g.box(Vector3(0, 1.80, -0.075), Vector3(0.1, 0.022, 0.03), CAPE_C, B.HEAD, Basis(Vector3.RIGHT, -0.3))


# ---------------------------------------------------------------- weapons

static func weapon(g: UnitGeo, kind: String, lod: int) -> void:
	match kind:
		"carbine":
			_carbine(g, lod)
		"scoped":
			SoldierBuilder._build_rifle(g, lod)
			_scope(g, lod)
		"lmg":
			_lmg(g, lod)
		"club":
			_club(g, lod)
		_:
			SoldierBuilder._build_rifle(g, lod)


static func _carbine(g: UnitGeo, lod: int) -> void:
	var B := SoldierBuilder
	var o: Vector3 = B.REST[W]
	var X := Vector3.RIGHT
	if lod >= 1:
		g.loft([o + Vector3(0, -0.04, 0.335), o + Vector3(0, 0.0, -0.38)], [Vector2(0.021, 0.05), Vector2(0.019, 0.026)],
			X, 4, 0.0, B.WOOD_DARK, W)
		if lod == 1:
			g.loft([o + Vector3(0, 0.03, -0.36), o + CARBINE_MUZZLE], [Vector2(0.011, 0.011), Vector2(0.011, 0.011)],
				X, 4, 0.0, B.METAL, W, null, 2)
		return
	g.loft([o + Vector3(0, -0.045, 0.335), o + Vector3(0, -0.02, 0.12), o + Vector3(0, 0.0, 0.0)],
		[Vector2(0.022, 0.064), Vector2(0.02, 0.044), Vector2(0.019, 0.03)], X, 6, 0.0, B.WOOD_DARK, W, null, 1)
	g.loft([o + Vector3(0, 0.0, 0.0), o + Vector3(0, 0.006, -0.40)], [Vector2(0.019, 0.03), Vector2(0.019, 0.026)],
		X, 6, 0.0, B.WOOD_DARK, W, null, 2)
	g.box(o + Vector3(0, 0.036, -0.08), Vector3(0.018, 0.1, 0.024), B.METAL, W, Basis(Vector3.RIGHT, PI / 2))
	g.box(o + Vector3(0.034, 0.042, -0.02), Vector3(0.02, 0.008, 0.008), B.METAL, W)
	g.loft([o + Vector3(0, 0.03, -0.38), o + CARBINE_MUZZLE], [Vector2(0.011, 0.011), Vector2(0.011, 0.011)],
		X, 4, 0.0, B.METAL, W, null, 2)
	g.loft([o + Vector3(0, 0.012, -0.30), o + Vector3(0, 0.012, -0.325)], [Vector2(0.023, 0.038), Vector2(0.023, 0.038)],
		X, 4, 0.0, B.METAL, W, null, 0)
	# A short sling, and the turned-down bolt knob that marks it out.
	g.loft([o + Vector3(0, -0.06, 0.25), o + Vector3(0, -0.09, -0.04), o + Vector3(0, -0.035, -0.31)],
		[Vector2(0.012, 0.004), Vector2(0.012, 0.004), Vector2(0.012, 0.004)], X, 4, 0.0, SoldierBuilder.LEATHER, W, null, 0)


static func _scope(g: UnitGeo, lod: int) -> void:
	if lod >= 2:
		return
	var o: Vector3 = SoldierBuilder.REST[W]
	var X := Vector3.RIGHT
	var sd := 8 if lod == 0 else 4
	g.loft([o + Vector3(0, 0.105, 0.12), o + Vector3(0, 0.105, 0.08), o + Vector3(0, 0.105, -0.16), o + Vector3(0, 0.105, -0.21)],
		[Vector2(0.021, 0.021), Vector2(0.016, 0.016), Vector2(0.016, 0.016), Vector2(0.022, 0.022)], X, sd, 0.0, STEEL_DARK, W)
	if lod == 0:
		for z: float in [-0.12, 0.03]:
			g.box(o + Vector3(0, 0.075, z), Vector3(0.012, 0.022, 0.012), STEEL, W)
		g.box(o + Vector3(0.0, 0.13, -0.04), Vector3(0.01, 0.01, 0.012), STEEL, W)  # the turret on top


static func _lmg(g: UnitGeo, lod: int) -> void:
	var B := SoldierBuilder
	var o: Vector3 = B.REST[W]
	var X := Vector3.RIGHT
	if lod >= 2:
		g.loft([o + Vector3(0, -0.04, 0.335), o + Vector3(0, 0.0, -0.1)], [Vector2(0.022, 0.05), Vector2(0.03, 0.04)], X, 4, 0.0, B.WOOD, W)
		g.loft([o + Vector3(0, 0.01, -0.1), o + Vector3(0, 0.01, -0.7)], [Vector2(0.034, 0.034), Vector2(0.03, 0.03)], X, 4, 0.0, JACKET, W)
		return
	var d0 := lod == 0
	g.loft([o + Vector3(0, -0.045, 0.335), o + Vector3(0, -0.02, 0.12), o + Vector3(0, -0.005, 0.03)],
		[Vector2(0.022, 0.06), Vector2(0.02, 0.04), Vector2(0.02, 0.032)], X, 6 if d0 else 4, 0.0, B.WOOD, W, null, 1)
	# Receiver, the pistol grip and trigger guard, the cocking handle.
	g.box(o + Vector3(0, 0.012, -0.09), Vector3(0.03, 0.038, 0.12), STEEL, W, Basis(), 0.2 if d0 else 0.0)
	g.box(o + Vector3(0, -0.06, 0.035), Vector3(0.014, 0.045, 0.02), B.WOOD_DARK, W, Basis(Vector3.RIGHT, 0.3))
	if d0:
		g.box(o + Vector3(0, -0.035, -0.005), Vector3(0.006, 0.014, 0.03), STEEL, W)
		g.box(o + Vector3(0.04, 0.02, -0.13), Vector3(0.014, 0.008, 0.008), STEEL, W)
		g.box(o + Vector3(0, 0.054, 0.05), Vector3(0.006, 0.012, 0.006), STEEL, W)  # rear sight
	# The finned cooling jacket (the fins as a checker of dark rings), the barrel, front sight.
	var jc: Array = []
	var js: Array = []
	var nr := 7 if d0 else 2
	for k in nr:
		jc.append(o + Vector3(0, 0.01, lerpf(-0.21, -0.62, float(k) / float(nr - 1))))
		js.append(Vector2(0.036, 0.036))
	g.loft(jc, js, X, 8 if d0 else 4, 0.0, JACKET, W, STEEL_DARK if d0 else null)
	g.loft([o + Vector3(0, 0.01, -0.62), o + LMG_MUZZLE], [Vector2(0.013, 0.013), Vector2(0.013, 0.013)], X, 4, 0.0, STEEL, W, null, 2)
	if d0:
		g.loft([o + Vector3(0, 0.01, -0.77), o + LMG_MUZZLE], [Vector2(0.02, 0.02), Vector2(0.02, 0.02)], X, 6, 0.0, STEEL_DARK, W)
		g.box(o + Vector3(0, 0.05, -0.6), Vector3(0.005, 0.012, 0.006), STEEL, W)
		g.box(o + LMG_HINGE + Vector3(0, 0.005, 0), Vector3(0.03, 0.012, 0.02), STEEL, W)


static func _club(g: UnitGeo, lod: int) -> void:
	var B := SoldierBuilder
	var o: Vector3 = B.REST[W]
	var X := Vector3.RIGHT
	var y := -0.015
	g.loft([o + Vector3(0, y, 0.14), o + Vector3(0, y, 0.07), o + Vector3(0, y, -0.28)],
		[Vector2(0.017, 0.017), Vector2(0.015, 0.015), Vector2(0.026, 0.026)], X, 6 if lod == 0 else 4, 0.0, B.WOOD_DARK, W)
	g.loft([o + Vector3(0, y, -0.28), o + Vector3(0, y, -0.32), o + CLUB_HEAD + Vector3(0, 0, -0.06)],
		[Vector2(0.036, 0.036), Vector2(0.04, 0.04), Vector2(0.034, 0.034)], X, 6 if lod == 0 else 4, 0.0, B.WOOD, W)
	if lod == 0:
		# An iron band and nail heads round the head, a wrist loop at the grip.
		g.loft([o + Vector3(0, y, -0.335), o + Vector3(0, y, -0.355)], [Vector2(0.043, 0.043), Vector2(0.043, 0.043)],
			X, 6, 0.0, STEEL, W, null, 0)
		for k in 6:
			var a := TAU * k / 6.0
			g.box(o + Vector3(cos(a) * 0.041, y + sin(a) * 0.041, -0.31 - 0.04 * (k % 2)), Vector3(0.008, 0.008, 0.008), NAILS, W)
		g.loft([o + Vector3(0, y, 0.13), o + Vector3(0, y - 0.07, 0.17), o + Vector3(0, y, 0.10)],
			[Vector2(0.004, 0.004), Vector2(0.004, 0.004), Vector2(0.004, 0.004)], X, 4, 0.0, B.LEATHER, W, null, 0)


# ---------------------------------------------------------------- LMG props

static func drum() -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	g.loft([Vector3(0, 0, 0), Vector3(0, 0.012, 0), Vector3(0, 0.04, 0)], [Vector2(0.03, 0.03), Vector2(0.115, 0.115), Vector2(0.115, 0.115)],
		X, 12, 0.0, STEEL, 0, STEEL_DARK)
	g.loft([Vector3(0, 0.04, 0), Vector3(0, 0.055, 0)], [Vector2(0.03, 0.03), Vector2(0.022, 0.022)], X, 8, 0.0, STEEL_DARK, 0)
	return g


## Two legs from the hinge to the feet, with a cross brace and small spade feet.
static func bipod_legs(hinge: Vector3, foot_r: Vector3, foot_l: Vector3) -> UnitGeo:
	var g := UnitGeo.new()
	for f: Vector3 in [foot_r, foot_l]:
		var d := (f - hinge).normalized()
		var side := d.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		g.loft([hinge, f], [Vector2(0.008, 0.008), Vector2(0.008, 0.008)], side.normalized(), 4, 0.0, STEEL, 0)
		g.box(f, Vector3(0.016, 0.004, 0.016), STEEL_DARK, 0)
	var mid_r := hinge.lerp(foot_r, 0.45)
	var mid_l := hinge.lerp(foot_l, 0.45)
	g.loft([mid_r, mid_l], [Vector2(0.005, 0.005), Vector2(0.005, 0.005)], Vector3.UP, 4, 0.0, STEEL, 0)
	return g


# ---------------------------------------------------------------- mortar props

static func plate(lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	g.box(Vector3(0, 0.012, 0), Vector3(0.23, 0.012, 0.19), PAINT, 0, Basis(), 0.25 if lod == 0 else 0.0)
	if lod == 0:
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.11 * s, 0.03, 0.0), Vector3(0.01, 0.012, 0.17), STEEL_DARK, 0)  # ribs
			g.box(Vector3(0.0, 0.03, 0.09 * s), Vector3(0.21, 0.012, 0.01), STEEL_DARK, 0)
			g.loft([Vector3(0.24 * s, 0.024, -0.06), Vector3(0.28 * s, 0.03, 0.0), Vector3(0.24 * s, 0.024, 0.06)],
				[Vector2(0.006, 0.006), Vector2(0.006, 0.006), Vector2(0.006, 0.006)], X, 4, 0.0, STEEL, 0, null, 0)
	g.loft([PLATE_SOCKET + Vector3(0, -0.02, 0), PLATE_SOCKET + Vector3(0, 0.01, 0)], [Vector2(0.05, 0.05), Vector2(0.042, 0.042)],
		X, 8, 0.0, STEEL, 0)
	return g


## The tube's frame inside the assembled mortar (base on the socket, +Y up the bore).
static func tube_xf() -> Transform3D:
	var up := Vector3(0, sin(ELEV), -cos(ELEV))
	var right := Vector3.RIGHT
	return Transform3D(Basis(right, up, right.cross(up)), PLATE_SOCKET + Vector3(0, 0.01, 0))


static func muzzle() -> Vector3:
	return tube_xf() * Vector3(0, TUBE_LEN, 0)


## The tube with its bipod: open 0 = folded along the tube (carried), 1 = feet on the
## ground when the tube is in the plate.
static func tube(open := 1.0, lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	var sd := 8 if lod == 0 else 5
	g.loft([Vector3(0, -0.03, 0), Vector3(0, 0.02, 0), Vector3(0, 0.06, 0)], [Vector2(0.02, 0.02), Vector2(0.04, 0.04), Vector2(TUBE_R, TUBE_R)],
		X, sd, 0.0, STEEL_DARK, 0)
	g.loft([Vector3(0, 0.06, 0), Vector3(0, TUBE_LEN, 0)], [Vector2(TUBE_R, TUBE_R), Vector2(TUBE_R, TUBE_R)], X, sd, 0.0, PAINT, 0, null, 0)
	g.loft([Vector3(0, TUBE_LEN - 0.03, 0), Vector3(0, TUBE_LEN, 0)], [Vector2(TUBE_R + 0.006, TUBE_R + 0.006), Vector2(TUBE_R + 0.006, TUBE_R + 0.006)],
		X, sd, 0.0, STEEL, 0, null, 0)
	# Bore (dark) at the muzzle.
	g.box(Vector3(0, TUBE_LEN + 0.001, 0), Vector3(TUBE_R * 0.8, 0.001, TUBE_R * 0.8), Color(0.05, 0.05, 0.05), 0)
	# The collar, the elevating screw and the sight on the left.
	var c := Vector3(0, COLLAR, 0)
	g.box(c, Vector3(TUBE_R + 0.012, 0.03, TUBE_R + 0.012), STEEL, 0)
	if lod == 0:
		g.box(c + Vector3(-0.07, 0.02, -0.02), Vector3(0.02, 0.03, 0.025), STEEL_DARK, 0)
		g.box(c + Vector3(-0.07, 0.06, -0.02), Vector3(0.008, 0.015, 0.012), Color(0.15, 0.15, 0.15), 0)
	var inv := tube_xf().affine_inverse()
	var hinge := c + Vector3(0, 0, 0.05)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var open_f: Vector3 = inv * (MORTAR_FEET[i] as Vector3)
		var fold_f := Vector3(0.045 * s, 0.12, 0.05)
		var f := fold_f.lerp(open_f, clampf(open, 0.0, 1.0))
		var d := (f - hinge).normalized()
		var side := d.cross(Vector3.BACK)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		g.loft([hinge + Vector3(0.02 * s, 0, 0), f], [Vector2(0.011, 0.011), Vector2(0.011, 0.011)], side.normalized(), 4, 0.0, STEEL, 0)
		g.box(f, Vector3(0.02, 0.008, 0.02), STEEL_DARK, 0)
		if i == 0 and open > 0.5 and lod == 0:
			# The spreader chain between the legs, halfway down.
			var other: Vector3 = (fold_f * Vector3(-1, 1, 1)).lerp(inv * (MORTAR_FEET[1] as Vector3), clampf(open, 0.0, 1.0))
			g.loft([hinge.lerp(f, 0.55), hinge.lerp(other, 0.55)], [Vector2(0.004, 0.004), Vector2(0.004, 0.004)], Vector3.UP, 4, 0.0, STEEL_DARK, 0)
	return g


static func bomb() -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	var h := BOMB_LEN * 0.5
	g.loft([Vector3(0, -h + 0.08, 0), Vector3(0, -h + 0.12, 0), Vector3(0, 0.02, 0), Vector3(0, h - 0.05, 0), Vector3(0, h, 0)],
		[Vector2(0.016, 0.016), Vector2(0.03, 0.03), Vector2(0.03, 0.03), Vector2(0.02, 0.02), Vector2(0.008, 0.008)], X, 8, 0.0, PAINT, 0)
	g.loft([Vector3(0, 0.0, 0), Vector3(0, 0.015, 0)], [Vector2(0.031, 0.031), Vector2(0.031, 0.031)], X, 8, 0.0, BOMB_RING, 0, null, 0)
	g.loft([Vector3(0, -h, 0), Vector3(0, -h + 0.09, 0)], [Vector2(0.011, 0.011), Vector2(0.011, 0.011)], X, 6, 0.0, STEEL, 0)
	for k in 4:
		var b := Basis(Vector3.UP, PI * 0.5 * k)
		g.box(b * Vector3(0.02, -h + 0.035, 0), Vector3(0.02, 0.035, 0.002), STEEL, 0, b)
	g.box(Vector3(0, h + 0.004, 0), Vector3(0.006, 0.006, 0.006), BOMB_RING, 0)
	return g


static func grenade() -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	g.loft([Vector3(0, -0.07, 0), Vector3(0, 0.16, 0)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)], X, 6, 0.0, SoldierBuilder.WOOD, 0)
	g.loft([Vector3(0, 0.16, 0), Vector3(0, 0.25, 0)], [Vector2(0.033, 0.033), Vector2(0.033, 0.033)], X, 8, 0.0, PAINT, 0)
	g.box(Vector3(0, -0.075, 0), Vector3(0.012, 0.006, 0.012), STEEL, 0)
	return g
