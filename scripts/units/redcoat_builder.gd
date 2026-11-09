class_name RedcoatBuilder
extends RefCounted
## The first enemy type (Building Chat 1, 2026-11-10): musket-era line infantry, "a few red jackets", in the
## troops' faceted low-poly look. Plain living soldiers. Same skeleton, bones and rest pose as the rifleman
## (SoldierBuilder), so every body clip, IK move, death and blast throw works on them.
## Roles:
##   musketeer  tricorne, red coat with facings and white lace, white cross-belts, cartridge box, bayonet
##              scabbard, haversack, musket with fixed bayonet (on the item bone, rifle frame)
##   officer    scarlet coat with gold lace, crimson sash, gorget, epaulette, tall boots, drawn sword
##   drummer    "reversed colours": a coat in the facing colour with red facings, laced sleeves, the drum
##              on the left thigh, a stick in each hand
##   ensign     the flag bearer: an officer's coat, sash and gorget, the colour belt; the pole is on the item
##              bone and the cloth is its own waving mesh (RedcoatBuilder.flag_mesh, shaders/flag_wave)
## He faces -Z, his right is +X, metres. lod 0 close (~1.3k triangles), 1 mid (~350), 2 far (~150).

const SB := preload("res://scripts/units/soldier_builder.gd")
const HIPS := SB.HIPS
const SPINE := SB.SPINE
const CHEST := SB.CHEST
const NECK := SB.NECK
const HEAD := SB.HEAD
const ITEM := SB.RIFLE

const RED := Color(0.64, 0.11, 0.09)
const RED_DARK := Color(0.47, 0.08, 0.07)
const SCARLET := Color(0.76, 0.13, 0.10)            # officers' finer cloth
const FACINGS := {"buff": Color(0.82, 0.69, 0.43), "blue": Color(0.14, 0.20, 0.42), "green": Color(0.16, 0.33, 0.20),
	"yellow": Color(0.86, 0.72, 0.22)}
const WHITE := Color(0.90, 0.88, 0.82)              # belts, lace, breeches
const WAISTCOAT := Color(0.86, 0.83, 0.74)
const GAITER := Color(0.10, 0.10, 0.11)
const SHOE := Color(0.08, 0.08, 0.08)
const HAT := Color(0.085, 0.085, 0.095)
const LEATHER_BLK := Color(0.11, 0.10, 0.10)
const CANVAS := Color(0.78, 0.74, 0.62)
const BRASS := Color(0.78, 0.62, 0.30)
const GOLD := Color(0.86, 0.68, 0.30)
const SASH := Color(0.58, 0.07, 0.17)
const STEEL := Color(0.60, 0.61, 0.63)
const STEEL_DARK := Color(0.30, 0.31, 0.33)
const WALNUT := Color(0.46, 0.25, 0.12)
const WALNUT_DARK := Color(0.34, 0.18, 0.09)
const SKIN_DRUM := Color(0.90, 0.84, 0.68)
const HAIRS: Array[Color] = [Color(0.16, 0.11, 0.07), Color(0.30, 0.20, 0.11), Color(0.45, 0.31, 0.16),
	Color(0.10, 0.08, 0.07), Color(0.62, 0.50, 0.30), Color(0.80, 0.78, 0.74)]

## Musket points in the item frame (barrel -Z, sights +Y). GRIP_R and BUTT are the rifle's, so the aim mode fits.
const MUZZLE := Vector3(0, 0.022, -1.25)
const PAN := Vector3(0.026, 0.035, -0.07)            # the priming pan, by the lock
const GRIP_L := Vector3(0, -0.012, -0.36)           # the left hand under the fore stock
const RAMROD_TIP := Vector3(0, -0.012, -1.235)       # where the rammer's head sits stowed
const BAYONET_TIP := Vector3(0.0, -0.012, -1.68)
## The colour: the pole along -Z through the item frame's axis, the cloth's top corner by the pole.
const POLE_BUTT := Vector3(0, 0, 0.55)
const POLE_TOP := Vector3(0, 0, -2.45)
const FLAG_AT := Vector3(0.02, 0, -2.28)
const FLAG_W := 1.7
const FLAG_H := 1.5
## The drum on the hips (rest model space): its middle and its axis (the batter head is +axis).
const DRUM_C := Vector3(-0.17, 0.80, -0.25)
const DRUM_AX := Vector3(0.34, 0.93, -0.12)
const DRUM_R := 0.19
const DRUM_H := 0.17
## Gunner tools along the item frame's Z.
const STAFF_RAM_Z := 1.15
const STAFF_SPONGE_Z := -1.25
const LINSTOCK_TIP_Z := -0.75


static func look_for_role(seed_value: int, role: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 6151 + 29
	var lk := {
		"role": role,
		"skin": SB.SKINS[[0, 0, 1, 1, 2][r.randi() % 5]],
		"hair": HAIRS[r.randi() % HAIRS.size()],
		"build": r.randf_range(0.93, 1.1),
		"facing": "buff",
		"pack": r.randf() < 0.45,
		"canteen": r.randf() < 0.7,
		"stubble": r.randf() < 0.3,
	}
	match role:
		"officer":
			lk.merge({"build": 1.0, "pack": false, "canteen": false, "hair": Color(0.62, 0.58, 0.52)}, true)
		"ensign":
			lk.merge({"build": r.randf_range(0.93, 0.98), "pack": false, "canteen": false}, true)
		"drummer":
			lk.merge({"build": r.randf_range(0.92, 0.97), "pack": false}, true)
		"grenadier":
			lk.merge({"build": r.randf_range(1.06, 1.13)}, true)
		"light":
			lk.merge({"build": r.randf_range(0.93, 1.02), "pack": false, "facing": "green"}, true)
		"dragoon":
			lk.merge({"build": r.randf_range(0.97, 1.05), "pack": false, "canteen": false}, true)
		_:
			if role.begins_with("gunner"):
				lk.merge({"pack": false, "facing": "blue"}, true)
	return lk


static func _officer(look: Dictionary) -> bool:
	return look["role"] in ["officer", "ensign"]


static func _side(s: float, right: int, left: int) -> int:
	return right if s > 0.0 else left


static func _t(a: Array, thin: bool) -> Array:
	return [a[0], a[a.size() - 1]] if thin and a.size() > 2 else a


## Both sides of a triangle (hat brims, open shapes).
static func _two(g: UnitGeo, a: Vector3, b: Vector3, c: Vector3, col: Color, bn: int) -> void:
	g.emit(a, b, c, col, bn)
	g.emit(a, c, b, col, bn)


static func _quad2(g: UnitGeo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, bn: int) -> void:
	_two(g, a, b, c, col, bn)
	_two(g, a, c, d, col, bn)


## A strap through points (belts), flat: width w, thickness 0.006.
static func _strap(g: UnitGeo, pts: Array, w: float, col: Color, bn: int) -> void:
	var sz: Array = []
	for p in pts:
		sz.append(Vector2(w, 0.006))
	g.loft(pts, sz, Vector3.RIGHT, 4, 0.0, col, bn, null, 0)


static func build(look: Dictionary, lod: int) -> UnitGeo:
	var g := UnitGeo.new()
	if lod >= 2:
		_build_far(g, look)
		return g
	var d0 := lod == 0
	var thin := not d0
	var sides := 8 if d0 else 4
	var ch := 0.35 if d0 else 0.0
	var ls := 6 if d0 else 4
	var w: float = look.get("build", 1.0)
	var wl := lerpf(1.0, w, 0.6)
	var role: String = look["role"]
	var off := _officer(look)
	var skin: Color = look["skin"]
	var facing: Color = FACINGS[look.get("facing", "buff")]
	var coat: Color = SCARLET if off else RED
	var cuff: Color = facing
	var lace: Color = GOLD if off else WHITE
	if role == "drummer":
		coat = facing
		cuff = RED
	var X := Vector3.RIGHT

	# ---- legs: white breeches, black gaiters to above the knee (officers: tall boots), black shoes.
	for s: float in [1.0, -1.0]:
		var x := 0.10 * s
		var th := _side(s, SB.THIGH_R, SB.THIGH_L)
		var sh := _side(s, SB.SHIN_R, SB.SHIN_L)
		var ft := _side(s, SB.FOOT_R, SB.FOOT_L)
		g.loft(_t([Vector3(x, 0.98, 0), Vector3(x, 0.74, -0.01), Vector3(x, 0.55, 0)], thin),
			_t([Vector2(0.085, 0.092) * wl, Vector2(0.073, 0.079) * wl, Vector2(0.062, 0.066) * wl], thin),
			X, ls, 0.0, WHITE, th, null, 0)
		var booted := off or role == "dragoon"
		var leg_col := LEATHER_BLK if booted else GAITER
		# Gaiter / boot top, flared over the knee.
		g.loft([Vector3(x, 0.62, 0.0), Vector3(x, 0.53, -0.005)], [Vector2(0.07, 0.074) * wl, Vector2(0.066, 0.07) * wl],
			X, ls, 0.0, leg_col, th if d0 else sh, null, 1)
		g.loft(_t([Vector3(x, 0.54, 0), Vector3(x, 0.33, 0.01), Vector3(x, 0.10, 0)], thin),
			_t([Vector2(0.063, 0.067) * wl, Vector2(0.057, 0.063) * wl, Vector2(0.052, 0.056)], thin),
			X, ls, 0.0, leg_col, sh, null, 0)
		if d0 and not booted:
			# The gaiter's buttons down the outside, and its strap under the knee.
			for k in 4:
				g.box(Vector3(x + 0.058 * s * wl, 0.46 - 0.095 * k, 0.0), Vector3(0.004, 0.006, 0.006), LEATHER_BLK.lightened(0.25), sh)
			g.loft([Vector3(x, 0.56, 0), Vector3(x, 0.545, 0)], [Vector2(0.068, 0.072) * wl, Vector2(0.068, 0.072) * wl],
				X, ls, 0.0, LEATHER_BLK.lightened(0.15), sh, null, 0)
		g.loft([Vector3(x, 0.115, 0.005), Vector3(x, 0.07, 0.01)], [Vector2(0.054, 0.058), Vector2(0.058, 0.064)],
			X, ls if d0 else 4, 0.0, leg_col, ft, null, 0)
		g.loft([Vector3(x, 0.045, 0.075), Vector3(x, 0.04, -0.165)], [Vector2(0.056, 0.045), Vector2(0.046, 0.032)],
			X, sides, ch, SHOE, ft)
		if d0:
			g.box(Vector3(x, 0.072, -0.1), Vector3(0.022, 0.012, 0.012), STEEL if off else BRASS, ft, Basis(Vector3.RIGHT, 0.5))
		# Coat tails, behind and to the side of each thigh, so the legs stride free; the white turnback.
		var tail_y := 0.50 if off else (0.84 if role == "light" else 0.60)
		g.loft(_t([Vector3(x * 1.05, 1.0, 0.035), Vector3(x * 1.12, 0.80, 0.06), Vector3(x * 1.18, tail_y, 0.085)], thin),
			_t([Vector2(0.09, 0.062) * w, Vector2(0.092, 0.064) * w, Vector2(0.09, 0.06) * w], thin),
			X, sides, 0.0, coat, th, null, 2)
		if d0:
			g.box(Vector3(x * 1.2 + 0.035 * s, tail_y + 0.075, 0.14 * w), Vector3(0.045, 0.07, 0.006), lace if off else WHITE, th,
				Basis(Vector3.UP, -0.35 * s))

	# ---- body: hips and waistcoat, the coat, lapels, collar, black stock.
	g.loft([Vector3(0, 0.86, 0.005), Vector3(0, 1.06, 0)], [Vector2(0.17, 0.108) * w, Vector2(0.172, 0.11) * w],
		X, sides, ch, WAISTCOAT, HIPS, null, 1)
	g.loft([Vector3(0, 0.98, 0.0), Vector3(0, 1.22, 0)], [Vector2(0.172, 0.116) * w, Vector2(0.178, 0.118) * w],
		X, sides, ch, coat, SPINE, null, 0)
	var chest_c: Array = [Vector3(0, 1.20, 0), Vector3(0, 1.34, -0.008), Vector3(0, 1.44, 0.0), Vector3(0, 1.50, 0.012)]
	var chest_s: Array = [Vector2(0.178, 0.118) * w, Vector2(0.198, 0.128) * w, Vector2(0.205, 0.118) * w, Vector2(0.12, 0.085) * w]
	if thin:
		chest_c = [chest_c[0], chest_c[2], chest_c[3]]
		chest_s = [chest_s[0], chest_s[2], chest_s[3]]
	g.loft(chest_c, chest_s, X, sides, ch, coat, CHEST, null, 2)
	# The coat hangs open below the chest: the white waistcoat shows at the front.
	g.box(Vector3(0, 1.08, -0.119 * w), Vector3(0.075, 0.12, 0.006), WAISTCOAT, SPINE)
	for s: float in [1.0, -1.0]:
		# Lapels in the facing colour, narrowing to the waist.
		g.box(Vector3(0.066 * s * w, 1.355, -0.131 * w), Vector3(0.042, 0.105, 0.007), cuff, CHEST, Basis(Vector3.FORWARD, 0.10 * s))
		if d0:
			for k in 4:
				var y := 1.425 - 0.05 * k
				g.box(Vector3((0.07 - 0.003 * k) * s * w, y, -0.139 * w), Vector3(0.026, 0.006, 0.003), lace, CHEST)
			# The coat's front edges below the lapels, curving back to the tails.
			g.box(Vector3(0.105 * s * w, 1.06, -0.11 * w), Vector3(0.03, 0.09, 0.008), coat, SPINE, Basis(Vector3.UP, 0.5 * s))
		# Shoulder straps (white worsted; the officer's right one is a gold epaulette).
		var epaulette := off and s > 0.0
		g.box(Vector3(0.15 * s * w, 1.495, 0.0), Vector3(0.055, 0.008 if not epaulette else 0.014, 0.034), GOLD if epaulette else lace, CHEST)
		if epaulette and d0:
			g.loft([Vector3(0.205, 1.47, 0.0), Vector3(0.21, 1.40, 0.0)], [Vector2(0.082, 0.088) * wl, Vector2(0.084, 0.09) * wl],
				X, 8, 0.0, GOLD, SB.UARM_R, Color(0.72, 0.55, 0.22), 0)
	g.loft([Vector3(0, 1.46, 0.012), Vector3(0, 1.525, 0.018)], [Vector2(0.11, 0.088) * w, Vector2(0.098, 0.082) * w],
		X, sides, 0.0, cuff, CHEST, null, 0)
	g.loft([Vector3(0, 1.49, 0.005), Vector3(0, 1.56, 0.0)], [Vector2(0.06, 0.06), Vector2(0.058, 0.058)],
		X, ls, 0.0, HAT, NECK, null, 0)
	if off:
		# The crimson sash round the waist, its knot and tassels on the left hip; the gilt gorget at the throat.
		g.loft([Vector3(0, 0.99, 0), Vector3(0, 1.075, 0)], [Vector2(0.184, 0.124) * w, Vector2(0.186, 0.126) * w],
			X, sides, ch, SASH, HIPS, SASH.darkened(0.2) if d0 else null, 0)
		g.box(Vector3(-0.17 * w, 1.0, -0.06), Vector3(0.03, 0.035, 0.03), SASH.darkened(0.1), HIPS)
		if d0:
			for k in 2:
				g.loft([Vector3(-0.175 * w - 0.01 * k, 0.97, -0.07 + 0.03 * k), Vector3(-0.18 * w - 0.015 * k, 0.78, -0.06 + 0.03 * k)],
					[Vector2(0.012, 0.012), Vector2(0.022, 0.022)], X, 4, 0.0, SASH, HIPS, null, 2)
		g.box(Vector3(0, 1.445, -0.112 * w), Vector3(0.05, 0.026, 0.008), GOLD, CHEST, Basis(Vector3.RIGHT, -0.35), 0.4 if d0 else 0.0)
	# ---- belts and kit.
	if role in ["musketeer", "grenadier", "light"]:
		_cross_belts(g, w, d0)
	elif role == "ensign":
		# The colour belt: right shoulder to left hip... the socket for the pole's butt at the right hip front.
		_strap(g, [Vector3(-0.13 * w, 1.02, -0.13 * w), Vector3(0.0, 1.26, -0.152 * w), Vector3(0.13, 1.51, -0.02),
			Vector3(0.04, 1.30, 0.14 * w), Vector3(-0.13 * w, 1.04, 0.13 * w)], 0.03, WHITE, CHEST)
		g.loft([Vector3(0.12 * w, 0.93, -0.135 * w), Vector3(0.12 * w, 1.0, -0.15 * w)], [Vector2(0.026, 0.026), Vector2(0.03, 0.03)],
			X, 6 if d0 else 4, 0.0, LEATHER_BLK, HIPS, null, 1)
		_strap(g, [Vector3(0.12 * w, 1.0, -0.15 * w), Vector3(0.0, 1.16, -0.156 * w), Vector3(-0.1 * w, 1.15, -0.14 * w)], 0.012, WHITE, SPINE)
	elif role == "drummer":
		_drum(g, w, d0, facing)
	elif role.begins_with("gunner") or role == "dragoon":
		# A white waist belt over the coat; gunners have a small pouch and a priming horn, the dragoon a carbine belt.
		g.loft([Vector3(0, 1.0, 0), Vector3(0, 1.05, 0)], [Vector2(0.186 * w, 0.126 * w), Vector2(0.186 * w, 0.126 * w)],
			X, sides, ch, WHITE, HIPS, null, 0)
		if role == "dragoon":
			_strap(g, [Vector3(0.15 * w, 0.98, -0.11 * w), Vector3(0.0, 1.25, -0.152 * w), Vector3(-0.13, 1.51, -0.02),
				Vector3(-0.03, 1.30, 0.138 * w), Vector3(0.15 * w, 1.0, 0.12 * w)], 0.034, WHITE, CHEST)
			g.box(Vector3(0.16 * w, 0.98, -0.1 * w), Vector3(0.02, 0.03, 0.008), STEEL, HIPS)
		else:
			g.box(Vector3(0.12 * w, 0.97, 0.12 * w), Vector3(0.06, 0.045, 0.03), LEATHER_BLK, HIPS, Basis(Vector3.UP, -0.35))
			if d0:
				g.loft([Vector3(-0.16 * w, 1.0, -0.07), Vector3(-0.19 * w, 0.88, -0.05), Vector3(-0.17 * w, 0.82, -0.02)],
					[Vector2(0.02, 0.02), Vector2(0.03, 0.03), Vector2(0.01, 0.01)], X, 6, 0.0, Color(0.82, 0.74, 0.55), HIPS)
	if role == "grenadier":
		# The grenade pouch on the left hip, the match case (a brass tube) on the right cross-belt, laced shoulder wings.
		g.box(Vector3(-0.16 * w, 0.96, -0.06), Vector3(0.03, 0.07, 0.075), LEATHER_BLK, HIPS, Basis(), 0.2 if d0 else 0.0)
		g.loft([Vector3(-0.07 * w, 1.40, -0.15 * w), Vector3(-0.05 * w, 1.33, -0.158 * w)], [Vector2(0.014, 0.014), Vector2(0.014, 0.014)],
			X, 6 if d0 else 4, 0.0, BRASS, CHEST)
		for s: float in [1.0, -1.0]:
			g.loft([Vector3(0.2 * s, 1.49, 0.0), Vector3(0.215 * s, 1.43, 0.0)], [Vector2(0.084, 0.09) * wl, Vector2(0.086, 0.092) * wl],
				X, ls, 0.0, coat, _side(s, SB.UARM_R, SB.UARM_L), WHITE if d0 else null, 0)
	elif role == "light":
		# A powder horn on its cord at the right hip.
		g.loft([Vector3(0.17 * w, 1.0, -0.05), Vector3(0.2 * w, 0.9, -0.02), Vector3(0.17 * w, 0.84, 0.03)],
			[Vector2(0.022, 0.022), Vector2(0.03, 0.03), Vector2(0.008, 0.008)], X, 6 if d0 else 4, 0.0, Color(0.82, 0.74, 0.55), HIPS)
	if role in ["officer", "ensign", "drummer", "dragoon"]:
		# A sword in its scabbard on the left hip, hung back (the drummer's is a short hanger).
		var long := role != "drummer"
		var tip := Vector3(-0.22 * w, 0.42 if long else 0.62, 0.28 if long else 0.18)
		g.loft([Vector3(-0.19 * w, 0.98, 0.0), tip], [Vector2(0.012, 0.022), Vector2(0.01, 0.016)], X, 4, 0.0, LEATHER_BLK, HIPS, null, 3)
		if d0:
			g.box(tip + (Vector3(-0.19 * w, 0.98, 0.0) - tip) * 0.04, Vector3(0.013, 0.02, 0.024), BRASS, HIPS,
				Basis(Vector3.RIGHT, -0.4))
			# The hilt sticking out above the belt.
			g.loft([Vector3(-0.185 * w, 0.99, -0.005), Vector3(-0.175 * w, 1.10, -0.06)], [Vector2(0.01, 0.01), Vector2(0.012, 0.012)],
				X, 4, 0.0, BRASS, HIPS)
	if look.get("pack", false):
		# Knapsack of painted canvas, the blanket rolled on top, its white straps.
		g.box(Vector3(0, 1.26, 0.172 * w), Vector3(0.13 * w, 0.14, 0.05), Color(0.30, 0.27, 0.22), CHEST, Basis(), 0.2 if d0 else 0.0)
		if d0:
			g.loft([Vector3(-0.15, 1.43, 0.17 * w), Vector3(0.15, 1.43, 0.17 * w)], [Vector2(0.048, 0.048), Vector2(0.048, 0.048)],
				Vector3.UP, 6, 0.0, Color(0.62, 0.20, 0.16) if look["build"] > 1.0 else Color(0.70, 0.68, 0.62), CHEST)
	if role != "officer" and role != "ensign" and d0:
		# Haversack on the left hip, and the canteen.
		g.box(Vector3(-0.15 * w, 0.93, 0.085 * w), Vector3(0.075, 0.075, 0.028), CANVAS, HIPS, Basis(Vector3.UP, 0.5), 0.25)
		if look.get("canteen", false):
			g.loft([Vector3(-0.2 * w, 0.95, 0.0), Vector3(-0.24 * w, 0.95, 0.0)], [Vector2(0.06, 0.06), Vector2(0.06, 0.06)],
				Vector3.UP, 8, 0.0, Color(0.33, 0.38, 0.45), HIPS)

	# ---- neck, head, hair, face.
	g.loft([Vector3(0, 1.54, 0.01), Vector3(0, 1.60, 0.0)], [Vector2(0.054, 0.054), Vector2(0.053, 0.053)],
		X, ls, 0.0, skin, NECK, null, 0)
	var head_c: Array = [Vector3(0, 1.555, -0.005), Vector3(0, 1.62, -0.012), Vector3(0, 1.735, 0.0), Vector3(0, 1.815, 0.005)]
	var head_s: Array = [Vector2(0.062, 0.07), Vector2(0.09, 0.102), Vector2(0.096, 0.108), Vector2(0.06, 0.068)]
	if thin:
		head_c = [head_c[0], head_c[2], head_c[3]]
		head_s = [head_s[0], head_s[2], head_s[3]]
	g.loft(head_c, head_s, X, sides, ch, skin, HEAD)
	if look.get("stubble", false) and d0:
		g.loft([Vector3(0, 1.56, -0.006), Vector3(0, 1.625, -0.014)], [Vector2(0.066, 0.074), Vector2(0.092, 0.104)],
			X, sides, ch, skin.darkened(0.14), HEAD, null, 0)
	g.box(Vector3(0, 1.71, -0.101), Vector3(0.077, 0.016, 0.008), skin.darkened(0.36), HEAD)
	if d0:
		g.loft([Vector3(0, 1.705, -0.108), Vector3(0, 1.662, -0.143)], [Vector2(0.017, 0.013), Vector2(0.013, 0.006)],
			X, 4, 0.0, skin.darkened(0.06), HEAD, null, 2)
		g.box(Vector3(0, 1.735, -0.111), Vector3(0.088, 0.009, 0.009), skin.darkened(0.2), HEAD)
	var hair: Color = look["hair"]
	g.box(Vector3(0, 1.69, 0.062), Vector3(0.1, 0.08, 0.052), hair, HEAD)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.09 * s, 1.70, 0.035), Vector3(0.014, 0.04, 0.05), hair, HEAD)
	if d0:
		# The queue, tied with a black ribbon.
		g.loft([Vector3(0, 1.66, 0.11), Vector3(0, 1.53, 0.115)], [Vector2(0.018, 0.014), Vector2(0.013, 0.01)], X, 4, 0.0, hair, HEAD)
		g.box(Vector3(0, 1.645, 0.112), Vector3(0.022, 0.012, 0.017), HAT, HEAD)
	match role:
		"grenadier":
			_mitre(g, d0, facing)
		"light":
			_light_cap(g, d0)
		"dragoon":
			_helmet(g, d0)
		_:
			_tricorne(g, d0, lace, off)

	# ---- arms: red sleeves, cuffs in the facing colour (laced for the drummer), hands.
	for s: float in [1.0, -1.0]:
		var ua := _side(s, SB.UARM_R, SB.UARM_L)
		var fa := _side(s, SB.FARM_R, SB.FARM_L)
		var hb := _side(s, SB.HAND_R, SB.HAND_L)
		g.loft(_t([Vector3(0.205 * s, 1.475, 0.0), Vector3(0.215 * s, 1.29, 0.0), Vector3(0.225 * s, 1.14, 0.0)], thin),
			_t([Vector2(0.074, 0.08) * wl, Vector2(0.064, 0.07) * wl, Vector2(0.058, 0.063) * wl], thin),
			X, ls, 0.0, coat, ua, null, 1)
		g.loft([Vector3(0.225 * s, 1.15, 0.0), Vector3(0.237 * s, 0.97, 0.0)],
			[Vector2(0.058, 0.062) * wl, Vector2(0.054, 0.058) * wl], X, ls, 0.0, coat, fa, null, 0)
		g.loft([Vector3(0.237 * s, 0.975, 0.0), Vector3(0.242 * s, 0.875, 0.0)],
			[Vector2(0.064, 0.068) * wl, Vector2(0.066, 0.07) * wl], X, ls, 0.0, cuff, fa, null, 2)
		if d0:
			for k in 2:
				g.box(Vector3(0.24 * s + 0.062 * s * wl, 0.95 - 0.04 * k, 0.0), Vector3(0.004, 0.006, 0.008), GOLD if off else BRASS.lightened(0.2), fa)
			if role == "drummer":
				# Lace chevrons up the sleeves.
				for k in 4:
					var y := 1.06 + 0.075 * k
					g.loft([Vector3(0.226 * s, y + 0.012, 0.0), Vector3(0.226 * s, y - 0.012, 0.0)],
						[Vector2(0.061, 0.066) * wl, Vector2(0.061, 0.066) * wl], X, ls, 0.0, WHITE, ua if y > 1.14 else fa, RED, 0)
		g.loft([Vector3(0.242 * s, 0.88, 0.0), Vector3(0.246 * s, 0.755, -0.008)],
			[Vector2(0.03, 0.048), Vector2(0.025, 0.044)], X, 4, 0.0, skin, hb, null, 2)
		if d0:
			g.box(Vector3(0.226 * s, 0.825, -0.042), Vector3(0.016, 0.03, 0.016), skin, hb)

	# ---- what each holds on the item bone.
	match role:
		"musketeer", "grenadier", "light":
			_musket(g, lod)
		"officer", "dragoon":
			_sword(g, lod)
		"drummer":
			_stick_r(g)
			# The left stick rides on the left hand, pointing forward from the fist.
			g.loft([Vector3(-0.245, 0.80, 0.05), Vector3(-0.245, 0.80, -0.34)], [Vector2(0.008, 0.008), Vector2(0.006, 0.006)],
				X, 4, 0.0, WALNUT.lightened(0.35), SB.HAND_L)
		"ensign":
			_pole(g, lod)
		"gunner_sponge":
			_staff(g, lod)
		"gunner_fire":
			_linstock(g, lod)
		"gunner_aim":
			_handspike(g)
	return g


## The two white cross-belts (the bayonet's on the right shoulder, the cartridge box's on the left), the brass plate
## where they cross, the cartridge box on the right hip behind, the bayonet scabbard on the left hip.
static func _cross_belts(g: UnitGeo, w: float, d0: bool) -> void:
	for s: float in [1.0, -1.0]:
		_strap(g, [Vector3(-0.15 * s * w, 1.04, -0.128 * w), Vector3(0.0, 1.31, -0.153 * w), Vector3(0.145 * s, 1.505, -0.02),
			Vector3(0.03 * s, 1.30, 0.138 * w), Vector3(-0.13 * s * w, 1.04, 0.13 * w)], 0.03, WHITE, CHEST)
	g.box(Vector3(0, 1.31, -0.161 * w), Vector3(0.026, 0.032, 0.006), BRASS, CHEST, Basis(), 0.4 if d0 else 0.0)
	g.box(Vector3(0.12 * w, 1.0, 0.125 * w), Vector3(0.085, 0.055, 0.035), LEATHER_BLK, HIPS, Basis(Vector3.UP, -0.35), 0.2 if d0 else 0.0)
	if d0:
		g.box(Vector3(0.122 * w, 1.025, 0.159 * w), Vector3(0.022, 0.018, 0.004), BRASS, HIPS, Basis(Vector3.UP, -0.35))
	var top := Vector3(-0.2 * w, 1.0, 0.02)
	var tip := Vector3(-0.215 * w, 0.62, 0.15)
	g.box(top + Vector3(0, -0.02, 0), Vector3(0.016, 0.05, 0.03), WHITE, HIPS)
	g.loft([top, tip], [Vector2(0.01, 0.018), Vector2(0.006, 0.01)], Vector3.RIGHT, 4, 0.0, LEATHER_BLK, HIPS)
	if d0:
		g.box(tip + (top - tip).normalized() * 0.02, Vector3(0.008, 0.02, 0.013), BRASS, HIPS, Basis(Vector3.RIGHT, -0.33))


## The tricorne: a round crown and a brim cocked up on three sides into a triangle, its point to the front.
## The top edge of each cocked side is laced (white, gold for officers), a black cockade on the left.
static func _tricorne(g: UnitGeo, d0: bool, lace: Color, off: bool) -> void:
	var X := Vector3.RIGHT
	var hs := 10 if d0 else 6
	g.loft([Vector3(0, 1.735, 0.01), Vector3(0, 1.80, 0.012), Vector3(0, 1.835, 0.015)],
		[Vector2(0.1, 0.112), Vector2(0.098, 0.11), Vector2(0.084, 0.094)], X, hs, 0.0, HAT, HEAD)
	var c := Vector3(0, 1.745, 0.02)
	var k := 1.12 if off else 1.0
	var corners: Array[Vector3] = [Vector3(0, 1.765, -0.225) * Vector3(1, 1, k), Vector3(0.205 * k, 1.775, 0.13),
		Vector3(-0.205 * k, 1.775, 0.13)]
	for i in 3:
		var p: Vector3 = corners[i]
		var q: Vector3 = corners[(i + 1) % 3]
		var m := (p + q) * 0.5
		var out := Vector3(m.x - c.x, 0, m.z - c.z).normalized()
		var mb := Vector3(m.x, 1.745, m.z) + out * 0.035                        # the brim's bottom edge, bowed out
		var mt := c.lerp(Vector3(m.x, c.y, m.z), 0.62) + Vector3(0, 0.115, 0)    # the cocked side's top, leaning in
		var pt := p + (c - p) * 0.12 + Vector3(0, 0.04, 0)
		var qt := q + (c - q) * 0.12 + Vector3(0, 0.04, 0)
		var lt := 0.82                                                         # where the lace band starts
		for half in 2:
			var b0 := p if half == 0 else mb
			var b1 := mb if half == 0 else q
			var t0 := pt if half == 0 else mt
			var t1 := mt if half == 0 else qt
			var l0 := b0.lerp(t0, lt)
			var l1 := b1.lerp(t1, lt)
			_quad2(g, b0, b1, l1, l0, HAT, HEAD)
			_quad2(g, l0, l1, t1, t0, lace if d0 else HAT, HEAD)
			_two(g, c, b0, b1, HAT.darkened(0.2), HEAD)                         # the brim's underside
	if d0:
		var side := corners[0].lerp(corners[2], 0.5)
		g.box(side.lerp(c, 0.5) + Vector3(-0.012, 0.085, -0.03), Vector3(0.006, 0.028, 0.028), HAT.lightened(0.04), HEAD,
			Basis(Vector3.UP, 0.55))
		g.box(side.lerp(c, 0.5) + Vector3(-0.02, 0.085, -0.035), Vector3(0.004, 0.008, 0.008), lace, HEAD, Basis(Vector3.UP, 0.55))



## The grenadier's mitre cap: a tall red cloth cap tapering up, a tall front plate in the facing colour with a
## white badge, a small red flap at its foot, a white tuft on top.
static func _mitre(g: UnitGeo, d0: bool, facing: Color) -> void:
	var X := Vector3.RIGHT
	var hs := 8 if d0 else 5
	g.loft([Vector3(0, 1.735, 0.01), Vector3(0, 1.84, 0.02), Vector3(0, 1.97, 0.03), Vector3(0, 2.04, 0.035)],
		[Vector2(0.102, 0.112), Vector2(0.094, 0.1), Vector2(0.07, 0.07), Vector2(0.035, 0.035)], X, hs, 0.0, RED, HEAD)
	g.loft([Vector3(0, 1.73, 0.01), Vector3(0, 1.765, 0.01)], [Vector2(0.106, 0.116), Vector2(0.106, 0.116)], X, hs, 0.0,
		WHITE if d0 else facing, HEAD, null, 0)
	# The front plate: a shield shape, flat, leaning back a little, both sides drawn.
	var b0 := Vector3(-0.1, 1.74, -0.105)
	var b1 := Vector3(0.1, 1.74, -0.105)
	var m0 := Vector3(-0.085, 1.93, -0.07)
	var m1 := Vector3(0.085, 1.93, -0.07)
	var top := Vector3(0, 2.09, -0.025)
	_quad2(g, b0, b1, m1, m0, facing, HEAD)
	_two(g, m0, m1, top, facing, HEAD)
	if d0:
		# The badge (a white oval with a crown block), the red flap with its white edge, the tuft.
		g.box(Vector3(0, 1.88, -0.087), Vector3(0.04, 0.05, 0.004), WHITE, HEAD, Basis(Vector3.RIGHT, -0.19))
		g.box(Vector3(0, 1.955, -0.068), Vector3(0.025, 0.018, 0.004), GOLD, HEAD, Basis(Vector3.RIGHT, -0.19))
		g.box(Vector3(0, 1.765, -0.112), Vector3(0.09, 0.022, 0.004), RED, HEAD, Basis(Vector3.RIGHT, -0.19))
		g.box(Vector3(0, 1.79, -0.11), Vector3(0.09, 0.004, 0.005), WHITE, HEAD, Basis(Vector3.RIGHT, -0.19))
		g.loft([Vector3(0, 2.035, 0.035), Vector3(0, 2.075, 0.04)], [Vector2(0.03, 0.03), Vector2(0.018, 0.018)], X, 6, 0.0, WHITE, HEAD)


## The light infantry cap: a low round black leather crown, the front flap turned up, a green tuft on the left.
static func _light_cap(g: UnitGeo, d0: bool) -> void:
	var X := Vector3.RIGHT
	var hs := 10 if d0 else 6
	g.loft([Vector3(0, 1.735, 0.01), Vector3(0, 1.80, 0.012), Vector3(0, 1.85, 0.015)],
		[Vector2(0.102, 0.112), Vector2(0.1, 0.11), Vector2(0.075, 0.085)], X, hs, 0.0, HAT, HEAD)
	# The upturned front flap.
	_quad2(g, Vector3(-0.1, 1.74, -0.1), Vector3(0.1, 1.74, -0.1), Vector3(0.08, 1.9, -0.085), Vector3(-0.08, 1.9, -0.085), HAT, HEAD)
	if d0:
		g.box(Vector3(0, 1.82, -0.096), Vector3(0.03, 0.03, 0.004), FACINGS["green"].lightened(0.1), HEAD, Basis(Vector3.RIGHT, 0.1))
		g.loft([Vector3(-0.09, 1.82, -0.02), Vector3(-0.1, 1.94, -0.02)], [Vector2(0.018, 0.018), Vector2(0.026, 0.026)],
			X, 6, 0.0, FACINGS["green"], HEAD)
		g.loft([Vector3(0, 1.735, -0.02), Vector3(0, 1.75, -0.02)], [Vector2(0.104, 0.114), Vector2(0.104, 0.114)], X, hs, 0.0,
			HAT.lightened(0.12), HEAD, null, 0)


## The dragoon's helmet: a black leather skull, a brass comb front to back with a black horsehair crest falling
## behind, a brass front plate, a short peak.
static func _helmet(g: UnitGeo, d0: bool) -> void:
	var X := Vector3.RIGHT
	var hs := 10 if d0 else 6
	g.loft([Vector3(0, 1.725, 0.01), Vector3(0, 1.80, 0.012), Vector3(0, 1.855, 0.015), Vector3(0, 1.875, 0.015)],
		[Vector2(0.104, 0.114), Vector2(0.104, 0.112), Vector2(0.08, 0.088), Vector2(0.03, 0.04)], X, hs, 0.0, HAT, HEAD)
	_quad2(g, Vector3(-0.09, 1.735, -0.1), Vector3(0.09, 1.735, -0.1), Vector3(0.08, 1.725, -0.16), Vector3(-0.08, 1.725, -0.16),
		HAT, HEAD)
	# The comb: a brass ridge over the top from the brow to the nape.
	g.loft([Vector3(0, 1.82, -0.1), Vector3(0, 1.9, -0.03), Vector3(0, 1.905, 0.04), Vector3(0, 1.85, 0.11)],
		[Vector2(0.012, 0.03), Vector2(0.012, 0.04), Vector2(0.012, 0.04), Vector2(0.012, 0.03)], X, 4, 0.0, BRASS, HEAD)
	# The crest of horsehair, from the comb's top down the back.
	g.loft([Vector3(0, 1.93, -0.01), Vector3(0, 1.92, 0.08), Vector3(0, 1.82, 0.16), Vector3(0, 1.66, 0.17)],
		[Vector2(0.02, 0.03), Vector2(0.03, 0.04), Vector2(0.026, 0.035), Vector2(0.01, 0.015)], X, 4, 0.0, Color(0.06, 0.05, 0.05), HEAD)
	if d0:
		g.box(Vector3(0, 1.79, -0.106), Vector3(0.06, 0.04, 0.004), BRASS, HEAD, Basis(Vector3.RIGHT, -0.2))
		g.box(Vector3(0, 1.79, -0.109), Vector3(0.022, 0.022, 0.004), RED, HEAD, Basis(Vector3.RIGHT, -0.2))


## The gunner's staff: rammer head at one end (+Z, behind the hands), the sheepskin sponge at the other (-Z).
## 2.4 m long; the hands hold it near the middle.
static func _staff(g: UnitGeo, lod: int) -> void:
	var o: Vector3 = SB.REST[ITEM]
	var X := Vector3.RIGHT
	var s := 6 if lod == 0 else 4
	g.loft([o + Vector3(0, 0, STAFF_RAM_Z), o + Vector3(0, 0, STAFF_SPONGE_Z)], [Vector2(0.018, 0.018), Vector2(0.018, 0.018)],
		X, 4, 0.0, WALNUT.lightened(0.15), ITEM)
	g.loft([o + Vector3(0, 0, STAFF_RAM_Z - 0.03), o + Vector3(0, 0, STAFF_RAM_Z + 0.16)], [Vector2(0.05, 0.05), Vector2(0.05, 0.05)],
		X, s, 0.0, WALNUT, ITEM)
	g.loft([o + Vector3(0, 0, STAFF_SPONGE_Z + 0.02), o + Vector3(0, 0, STAFF_SPONGE_Z - 0.24)], [Vector2(0.055, 0.055), Vector2(0.05, 0.05)],
		X, s, 0.0, Color(0.78, 0.74, 0.66) if lod == 0 else CANVAS, ITEM)


## The linstock: a 1 m staff with a brass forked head holding the smouldering slow match.
static func _linstock(g: UnitGeo, lod: int) -> void:
	var o: Vector3 = SB.REST[ITEM]
	var X := Vector3.RIGHT
	g.loft([o + Vector3(0, 0, 0.3), o + Vector3(0, 0, LINSTOCK_TIP_Z + 0.08)], [Vector2(0.014, 0.014), Vector2(0.012, 0.012)],
		X, 4, 0.0, WALNUT, ITEM)
	if lod >= 2:
		return
	for s: float in [1.0, -1.0]:
		g.loft([o + Vector3(0, 0, LINSTOCK_TIP_Z + 0.08), o + Vector3(0.035 * s, 0, LINSTOCK_TIP_Z)], [Vector2(0.006, 0.006),
			Vector2(0.005, 0.005)], X, 4, 0.0, BRASS, ITEM)
		g.loft([o + Vector3(0.035 * s, 0, LINSTOCK_TIP_Z), o + Vector3(0.04 * s, -0.05, LINSTOCK_TIP_Z - 0.01)],
			[Vector2(0.007, 0.007), Vector2(0.006, 0.006)], X, 4, 0.0, Color(0.55, 0.48, 0.36), ITEM)
	g.box(o + Vector3(0.04, -0.055, LINSTOCK_TIP_Z - 0.01), Vector3(0.009, 0.009, 0.009), Color(1.0, 0.45, 0.12), ITEM)


## The handspike: a 1.5 m ash lever, squared, its foot shod with iron (+Z end goes under the trail).
static func _handspike(g: UnitGeo) -> void:
	var o: Vector3 = SB.REST[ITEM]
	g.loft([o + Vector3(0, 0, 0.9), o + Vector3(0, 0, -0.6)], [Vector2(0.025, 0.032), Vector2(0.018, 0.02)], Vector3.RIGHT, 4, 0.0,
		WALNUT.lightened(0.25), ITEM)
	g.loft([o + Vector3(0, 0, 0.9), o + Vector3(0, 0, 0.78)], [Vector2(0.027, 0.034), Vector2(0.027, 0.034)], Vector3.RIGHT, 4, 0.0,
		STEEL_DARK, ITEM, null, 1)

## The musket with its bayonet fixed: long walnut stock almost to the muzzle, brass butt plate, guard and pipes,
## the lock and cock on the right, a white sling. The rammer is its own prop (RedcoatBuilder.rammer), drawn in the reload.
static func _musket(g: UnitGeo, lod: int) -> void:
	var o: Vector3 = SB.REST[ITEM]
	var X := Vector3.RIGHT
	if lod >= 1:
		g.loft([o + Vector3(0, -0.045, 0.33), o + Vector3(0, -0.005, 0.0), o + Vector3(0, 0.004, -1.10)],
			[Vector2(0.02, 0.06), Vector2(0.018, 0.028), Vector2(0.015, 0.018)], X, 4, 0.0, WALNUT, ITEM, null, 3)
		if lod == 1:
			g.loft([o + Vector3(0, 0.022, -1.0), o + MUZZLE], [Vector2(0.011, 0.011), Vector2(0.011, 0.011)], X, 4, 0.0, STEEL, ITEM)
			g.loft([o + Vector3(0, -0.012, -1.24), o + BAYONET_TIP], [Vector2(0.01, 0.01), Vector2(0.002, 0.002)], X, 4, 0.0, STEEL, ITEM, null, 0)
		return
	g.loft([o + Vector3(0, -0.05, 0.33), o + Vector3(0, -0.03, 0.18), o + Vector3(0, -0.008, 0.04)],
		[Vector2(0.022, 0.075), Vector2(0.02, 0.05), Vector2(0.018, 0.028)], X, 6, 0.0, WALNUT, ITEM, null, 2)
	g.loft([o + Vector3(0, -0.05, 0.336), o + Vector3(0, -0.05, 0.33)], [Vector2(0.023, 0.077), Vector2(0.023, 0.077)],
		X, 6, 0.0, BRASS, ITEM, null, 1)
	g.loft([o + Vector3(0, -0.008, 0.04), o + Vector3(0, 0.0, -0.3), o + Vector3(0, 0.004, -1.10)],
		[Vector2(0.018, 0.028), Vector2(0.019, 0.025), Vector2(0.016, 0.018)], X, 6, 0.0, WALNUT, ITEM, null, 2)
	g.loft([o + Vector3(0, 0.022, -0.06), o + MUZZLE], [Vector2(0.0115, 0.0115), Vector2(0.011, 0.011)], X, 6, 0.0, STEEL, ITEM)
	# Lock plate, cock, frizzen and pan on the right.
	g.box(o + Vector3(0.02, 0.012, -0.07), Vector3(0.004, 0.017, 0.06), STEEL_DARK, ITEM)
	g.box(o + Vector3(0.024, 0.045, -0.02), Vector3(0.004, 0.022, 0.008), STEEL_DARK, ITEM, Basis(Vector3.RIGHT, -0.35))
	g.box(o + Vector3(0.024, 0.045, -0.085), Vector3(0.004, 0.018, 0.006), STEEL_DARK, ITEM, Basis(Vector3.RIGHT, 0.2))
	g.box(o + Vector3(0, -0.03, 0.0), Vector3(0.006, 0.008, 0.055), BRASS, ITEM)
	for z: float in [-0.55, -0.8, -1.02]:
		g.loft([o + Vector3(0, -0.012, z + 0.015), o + Vector3(0, -0.012, z - 0.015)], [Vector2(0.008, 0.008), Vector2(0.008, 0.008)],
			X, 4, 0.0, BRASS, ITEM)
	g.loft([o + Vector3(0, -0.012, -1.10), o + Vector3(0, -0.012, -1.12)], [Vector2(0.017, 0.02), Vector2(0.017, 0.02)],
		X, 4, 0.0, BRASS, ITEM)
	g.loft([o + Vector3(0, -0.06, 0.24), o + Vector3(0, -0.1, -0.2), o + Vector3(0, -0.03, -0.75)],
		[Vector2(0.012, 0.004), Vector2(0.012, 0.004), Vector2(0.012, 0.004)], X, 4, 0.0, WHITE, ITEM, null, 0)
	# The socket bayonet: a ring on the muzzle, the neck down and to the right, the three-sided blade under the barrel.
	g.loft([o + Vector3(0, 0.022, -1.17), o + Vector3(0, 0.022, -1.252)], [Vector2(0.015, 0.015), Vector2(0.015, 0.015)],
		X, 6, 0.0, STEEL_DARK, ITEM)
	g.loft([o + Vector3(0.012, 0.012, -1.24), o + Vector3(0.006, -0.012, -1.255)], [Vector2(0.005, 0.005), Vector2(0.005, 0.005)],
		X, 4, 0.0, STEEL, ITEM)
	g.loft([o + Vector3(0, -0.012, -1.25), o + BAYONET_TIP], [Vector2(0.012, 0.012), Vector2(0.0015, 0.0015)],
		X, 3, 0.0, STEEL, ITEM, null, 1)


## The rammer, its own small mesh (rest model space of the item bone): along -Z from its head (z 0) to its tail.
static func rammer() -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(0, 0, 0), Vector3(0, 0, 1.03)], [Vector2(0.005, 0.005), Vector2(0.004, 0.004)], Vector3.RIGHT, 4, 0.0, STEEL, 0)
	g.loft([Vector3(0, 0, -0.008), Vector3(0, 0, 0.03)], [Vector2(0.008, 0.008), Vector2(0.008, 0.008)], Vector3.RIGHT, 4, 0.0, STEEL, 0)
	return g


## A paper cartridge (bitten open in the reload), centred, along +Y.
static func cartridge() -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(0, -0.035, 0), Vector3(0, 0.035, 0)], [Vector2(0.009, 0.009), Vector2(0.008, 0.008)], Vector3.RIGHT, 4, 0.0,
		Color(0.92, 0.9, 0.84), 0)
	return g



## The grenade: an iron ball a little bigger than a fist's grip, a wooden fuse plug on top.
static func grenade() -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(0, -0.05, 0), Vector3(0, -0.03, 0), Vector3(0, 0.03, 0), Vector3(0, 0.05, 0)],
		[Vector2(0.02, 0.02), Vector2(0.046, 0.046), Vector2(0.046, 0.046), Vector2(0.02, 0.02)], Vector3.RIGHT, 8, 0.0,
		Color(0.1, 0.1, 0.11), 0)
	g.loft([Vector3(0, 0.045, 0), Vector3(0, 0.075, 0)], [Vector2(0.012, 0.012), Vector2(0.009, 0.009)], Vector3.RIGHT, 5, 0.0, WALNUT, 0)
	return g


## The burning fuse's spark, shown once it is lit.
static func fuse_spark() -> UnitGeo:
	var g := UnitGeo.new()
	g.box(Vector3(0, 0.085, 0), Vector3(0.014, 0.014, 0.014), Color(1.0, 0.62, 0.2), 0, Basis(Vector3(1, 1, 0).normalized(), 0.7))
	g.box(Vector3(0.01, 0.1, 0), Vector3(0.006, 0.006, 0.006), Color(1.0, 0.9, 0.5), 0)
	return g


## The gun's round, carried by the loader: the flannel powder bag with the ball strapped to its end (along X).
static func round_shot() -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(-0.06, 0, 0), Vector3(0.1, 0, 0)], [Vector2(0.045, 0.045), Vector2(0.045, 0.045)], Vector3.UP, 8, 0.0,
		Color(0.80, 0.72, 0.58), 0)
	g.loft([Vector3(-0.13, 0, 0), Vector3(-0.1, 0, 0), Vector3(-0.06, 0, 0), Vector3(-0.03, 0, 0)],
		[Vector2(0.015, 0.015), Vector2(0.044, 0.044), Vector2(0.044, 0.044), Vector2(0.015, 0.015)], Vector3.UP, 8, 0.0,
		Color(0.14, 0.14, 0.15), 0)
	return g

## The officer's sword: grip at GRIP_R, the blade along -Z.
static func _sword(g: UnitGeo, lod: int) -> void:
	var o: Vector3 = SB.REST[ITEM] + SB.GRIP_R
	var X := Vector3.RIGHT
	g.loft([o + Vector3(0, 0, 0.05), o + Vector3(0, 0, -0.045)], [Vector2(0.012, 0.014), Vector2(0.012, 0.014)], X, 4, 0.0,
		Color(0.2, 0.15, 0.1), ITEM)
	g.box(o + Vector3(0, 0, 0.06), Vector3(0.014, 0.014, 0.012), GOLD, ITEM)
	g.box(o + Vector3(0, 0, -0.05), Vector3(0.042, 0.007, 0.007), GOLD, ITEM)
	if lod == 0:
		g.loft([o + Vector3(0.0, -0.01, -0.05), o + Vector3(0.0, -0.045, 0.0), o + Vector3(0, -0.02, 0.055)],
			[Vector2(0.004, 0.004), Vector2(0.004, 0.004), Vector2(0.004, 0.004)], X, 4, 0.0, GOLD, ITEM, null, 0)
	g.loft([o + Vector3(0, 0, -0.055), o + Vector3(0, 0, -0.55), o + Vector3(0, 0, -0.86)],
		[Vector2(0.004, 0.015), Vector2(0.0035, 0.012), Vector2(0.001, 0.002)], X, 4, 0.0, STEEL.lightened(0.15), ITEM, null, 0)


## The drummer's right stick on the item bone (held at GRIP_R, the tip forward along -Z).
static func _stick_r(g: UnitGeo) -> void:
	var o: Vector3 = SB.REST[ITEM] + SB.GRIP_R
	g.loft([o + Vector3(0, 0, 0.06), o + Vector3(0, 0, -0.34)], [Vector2(0.008, 0.008), Vector2(0.006, 0.006)],
		Vector3.RIGHT, 4, 0.0, WALNUT.lightened(0.35), ITEM)


## The colour's pole: ash with a brass spear-head and a gold cord and tassels under it.
static func _pole(g: UnitGeo, lod: int) -> void:
	var o: Vector3 = SB.REST[ITEM]
	var X := Vector3.RIGHT
	g.loft([o + POLE_BUTT, o + POLE_TOP], [Vector2(0.017, 0.017), Vector2(0.015, 0.015)], X, 6 if lod == 0 else 4, 0.0,
		Color(0.55, 0.40, 0.24), ITEM)
	g.loft([o + POLE_TOP, o + POLE_TOP + Vector3(0, 0, -0.05), o + POLE_TOP + Vector3(0, 0, -0.17)],
		[Vector2(0.016, 0.016), Vector2(0.04, 0.012), Vector2(0.001, 0.001)], X, 4, 0.0, BRASS, ITEM, null, 1)
	if lod == 0:
		for s: float in [1.0, -1.0]:
			g.loft([o + FLAG_AT + Vector3(-0.02, 0.0, 0.0), o + Vector3(-0.07 * s, 0.03 * s, -2.0), o + Vector3(-0.09 * s, 0.05 * s, -1.75)],
				[Vector2(0.004, 0.004), Vector2(0.004, 0.004), Vector2(0.004, 0.004)], X, 4, 0.0, GOLD, ITEM, null, 0)
			g.loft([o + Vector3(-0.09 * s, 0.05 * s, -1.76), o + Vector3(-0.09 * s, 0.05 * s, -1.66)],
				[Vector2(0.01, 0.01), Vector2(0.022, 0.022)], X, 6, 0.0, GOLD, ITEM, null, 3)


## The drum on its carriage strap: shell in the facing colour, red hoops, the white cord laced between them.
static func _drum(g: UnitGeo, w: float, d0: bool, facing: Color) -> void:
	var X := Vector3.RIGHT
	var ax := DRUM_AX.normalized()
	var c := DRUM_C * Vector3(w, 1, 1)
	var hs := 12 if d0 else 6
	var hint := ax.cross(Vector3.FORWARD).normalized()
	g.loft([c - ax * DRUM_H, c + ax * DRUM_H], [Vector2(DRUM_R, DRUM_R), Vector2(DRUM_R, DRUM_R)], hint, hs, 0.0, facing, HIPS, null, 0)
	for e: float in [-1.0, 1.0]:
		g.loft([c + ax * (DRUM_H - 0.035) * e, c + ax * (DRUM_H + 0.006) * e], [Vector2(DRUM_R + 0.012, DRUM_R + 0.012), Vector2(DRUM_R + 0.012, DRUM_R + 0.012)],
			hint, hs, 0.0, RED, HIPS, null, 0)
		g.loft([c + ax * (DRUM_H + 0.006) * e, c + ax * (DRUM_H + 0.008) * e], [Vector2(DRUM_R - 0.004, DRUM_R - 0.004), Vector2(DRUM_R - 0.004, DRUM_R - 0.004)],
			hint, hs, 0.0, SKIN_DRUM, HIPS, null, 2 if e > 0.0 else 1)
	if d0:
		var bx := hint
		var by := ax.cross(bx).normalized()
		for i in 10:
			var a0 := TAU * float(i) / 10.0
			var a1 := TAU * (float(i) + 0.5) / 10.0
			var r := DRUM_R + 0.008
			var p0 := c - ax * (DRUM_H - 0.04) + (bx * cos(a0) + by * sin(a0)) * r
			var p1 := c + ax * (DRUM_H - 0.04) + (bx * cos(a1) + by * sin(a1)) * r
			var a2 := TAU * (float(i) + 1.0) / 10.0
			var p2 := c - ax * (DRUM_H - 0.04) + (bx * cos(a2) + by * sin(a2)) * r
			_strap(g, [p0, p1], 0.004, WHITE, HIPS)
			_strap(g, [p1, p2], 0.004, WHITE, HIPS)
	# The carriage strap from the right shoulder to the drum's hook, and over the back.
	var hook := c + ax * (DRUM_H - 0.02) + Vector3(0.12, 0.0, 0.08)
	_strap(g, [hook, Vector3(0.06 * w, 1.25, -0.152 * w), Vector3(0.125, 1.512, -0.02), Vector3(0.03, 1.30, 0.138 * w),
		Vector3(-0.13 * w, 1.04, 0.13 * w)], 0.028, WHITE, CHEST)


## The far version: one simple shape per part (~150 triangles); the coat, belts and hat read as colour blocks.
static func _build_far(g: UnitGeo, look: Dictionary) -> void:
	var X := Vector3.RIGHT
	var role: String = look["role"]
	var off := _officer(look)
	var facing: Color = FACINGS[look.get("facing", "buff")]
	var coat: Color = facing if role == "drummer" else (SCARLET if off else RED)
	for s: float in [1.0, -1.0]:
		var x := 0.10 * s
		g.loft([Vector3(x, 0.98, 0), Vector3(x, 0.55, 0)], [Vector2(0.08, 0.085), Vector2(0.062, 0.066)], X, 4, 0.0, WHITE,
			_side(s, SB.THIGH_R, SB.THIGH_L), null, 0)
		g.loft([Vector3(x, 0.56, 0), Vector3(x, 0.1, 0)], [Vector2(0.064, 0.068), Vector2(0.055, 0.06)], X, 4, 0.0, GAITER,
			_side(s, SB.SHIN_R, SB.SHIN_L), null, 0)
		g.box(Vector3(x, 0.045, -0.045), Vector3(0.055, 0.045, 0.12), SHOE, _side(s, SB.FOOT_R, SB.FOOT_L))
		g.loft([Vector3(x * 1.1, 1.0, 0.04), Vector3(x * 1.18, 0.6, 0.08)], [Vector2(0.09, 0.06), Vector2(0.09, 0.06)], X, 4, 0.0, coat,
			_side(s, SB.THIGH_R, SB.THIGH_L))
		g.loft([Vector3(0.205 * s, 1.475, 0), Vector3(0.225 * s, 1.14, 0)], [Vector2(0.07, 0.075), Vector2(0.058, 0.062)], X, 4, 0.0, coat,
			_side(s, SB.UARM_R, SB.UARM_L))
		g.loft([Vector3(0.225 * s, 1.15, 0), Vector3(0.245 * s, 0.76, -0.008)], [Vector2(0.055, 0.058), Vector2(0.035, 0.045)], X, 4, 0.0,
			coat, _side(s, SB.FARM_R, SB.FARM_L))
	g.loft([Vector3(0, 0.86, 0), Vector3(0, 1.08, 0)], [Vector2(0.175, 0.112), Vector2(0.18, 0.115)], X, 4, 0.0, WAISTCOAT, HIPS)
	g.loft([Vector3(0, 1.06, 0), Vector3(0, 1.5, 0)], [Vector2(0.18, 0.118), Vector2(0.2, 0.12)], X, 4, 0.0, coat, CHEST)
	if role in ["musketeer", "grenadier", "light"]:
		g.box(Vector3(0, 1.27, -0.125), Vector3(0.11, 0.07, 0.006), WHITE, CHEST)
	elif off:
		g.loft([Vector3(0, 0.99, 0), Vector3(0, 1.07, 0)], [Vector2(0.186, 0.124), Vector2(0.186, 0.124)], X, 4, 0.0, SASH, HIPS)
	g.box(Vector3(0, 1.68, -0.005), Vector3(0.09, 0.12, 0.1), look["skin"], HEAD)
	# The hat: one flat triangle and a block.
	g.loft([Vector3(0, 1.74, 0.01), Vector3(0, 1.84, 0.015)], [Vector2(0.15, 0.15), Vector2(0.09, 0.09)], X, 3, 0.0, HAT, HEAD)
	match role:
		"musketeer", "grenadier", "light":
			_musket(g, 2)
		"officer", "dragoon":
			_sword(g, 2)
		"ensign":
			_pole(g, 2)
		"gunner_sponge":
			_staff(g, 2)
		"gunner_fire":
			_linstock(g, 2)
		"drummer":
			var ax := DRUM_AX.normalized()
			g.loft([DRUM_C - ax * DRUM_H, DRUM_C + ax * DRUM_H], [Vector2(DRUM_R, DRUM_R), Vector2(DRUM_R, DRUM_R)],
				ax.cross(Vector3.FORWARD).normalized(), 6, 0.0, facing, HIPS)


## The colour's cloth, flat in its own frame: x from the pole (0) to FLAG_W, z down from the top (0) to FLAG_H,
## made of small squares so the wave shader folds it into facets. A generic regimental colour: a field in the
## facing colour, a red border, a red roundel in a gold ring with a white middle. UV.x = distance from the pole (0..1).
static func flag_mesh(facing_name := "buff", nx := 26, nz := 22) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var field: Color = FACINGS[facing_name]
	for i in nx:
		for j in nz:
			var u0 := float(i) / nx
			var u1 := float(i + 1) / nx
			var v0 := float(j) / nz
			var v1 := float(j + 1) / nz
			var cx := (u0 + u1) * 0.5 * FLAG_W
			var cz := (v0 + v1) * 0.5 * FLAG_H
			var col := field
			var border := minf(minf(cx, FLAG_W - cx), minf(cz, FLAG_H - cz))
			var r := Vector2(cx - FLAG_W * 0.5, cz - FLAG_H * 0.5).length()
			if border < 0.09:
				col = RED
			elif r < 0.12:
				col = WHITE
			elif r < 0.30:
				col = RED
			elif r < 0.36:
				col = GOLD
			var pts: Array[Vector3] = [Vector3(u0 * FLAG_W, 0, v0 * FLAG_H), Vector3(u1 * FLAG_W, 0, v0 * FLAG_H),
				Vector3(u1 * FLAG_W, 0, v1 * FLAG_H), Vector3(u0 * FLAG_W, 0, v1 * FLAG_H)]
			var uvs: Array[Vector2] = [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(col)
				st.set_uv(uvs[k])
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[k])
	return st.commit()
