class_name SoldierBuilder
extends RefCounted
## Builds the Iron Front rifleman in code: a faceted low-poly soldier in the
## "basic army" look (round helmet with net, olive uniform, khaki webbing, brown
## boots, a long bolt-action rifle). Same height for everyone; skin, build and kit vary.
## He faces -Z, his right is +X. Units are metres; he stands 1.80 m (1.89 m with helmet).
## lod 0 = close (about 1k triangles), 1 = mid (about 250), 2 = far (simple boxes).

enum { ROOT, HIPS, SPINE, CHEST, NECK, HEAD, UARM_R, FARM_R, HAND_R, UARM_L, FARM_L, HAND_L,
		THIGH_R, SHIN_R, FOOT_R, THIGH_L, SHIN_L, FOOT_L, RIFLE }

const BONE_NAMES: Array[String] = ["root", "hips", "spine", "chest", "neck", "head",
	"upper_arm.R", "forearm.R", "hand.R", "upper_arm.L", "forearm.L", "hand.L",
	"thigh.R", "shin.R", "foot.R", "thigh.L", "shin.L", "foot.L", "rifle"]
const BONE_PARENT: Array[int] = [-1, 0, 1, 2, 3, 4, 3, 6, 7, 3, 9, 10, 1, 12, 13, 1, 15, 16, 3]
## Rest positions in model space. Every rest basis is the identity.
const REST: Array[Vector3] = [
	Vector3(0, 0, 0), Vector3(0, 0.95, 0), Vector3(0, 1.06, 0), Vector3(0, 1.24, 0),
	Vector3(0, 1.48, 0), Vector3(0, 1.57, 0),
	Vector3(0.20, 1.44, 0), Vector3(0.225, 1.13, 0), Vector3(0.24, 0.86, 0),
	Vector3(-0.20, 1.44, 0), Vector3(-0.225, 1.13, 0), Vector3(-0.24, 0.86, 0),
	Vector3(0.10, 0.93, 0), Vector3(0.10, 0.51, 0), Vector3(0.10, 0.09, 0),
	Vector3(-0.10, 0.93, 0), Vector3(-0.10, 0.51, 0), Vector3(-0.10, 0.09, 0),
	Vector3(0.36, 0.95, 0.05)]
## Rifle grip points in the rifle's own frame (barrel along -Z, sights up +Y).
const GRIP_R := Vector3(0, -0.015, 0.06)
const GRIP_L := Vector3(0, -0.02, -0.18)
const BUTT := Vector3(0, -0.035, 0.33)
const PALM := 0.055

# Colours (sRGB).
const OLIVE := Color(0.40, 0.44, 0.25)
const OLIVE_DARK := Color(0.33, 0.37, 0.21)
const TROUSER := Color(0.37, 0.41, 0.24)
const KHAKI := Color(0.66, 0.59, 0.41)
const KHAKI_DARK := Color(0.52, 0.47, 0.32)
const BOOT := Color(0.40, 0.25, 0.15)
const BOOT_DARK := Color(0.22, 0.15, 0.10)
const LEATHER := Color(0.33, 0.21, 0.13)
const HELMET := Color(0.34, 0.39, 0.22)
const HELMET_NET := Color(0.24, 0.28, 0.16)
const BLANKET := Color(0.46, 0.44, 0.34)
const WOOD := Color(0.55, 0.32, 0.16)
const WOOD_DARK := Color(0.42, 0.24, 0.12)
const METAL := Color(0.17, 0.17, 0.18)
const BRASS := Color(0.62, 0.52, 0.30)
const SKINS: Array[Color] = [Color(0.95, 0.78, 0.64), Color(0.87, 0.66, 0.50),
	Color(0.74, 0.53, 0.37), Color(0.56, 0.38, 0.26), Color(0.40, 0.27, 0.18)]


## A random but repeatable look from a seed.
static func look_from_seed(seed_value: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 7919 + 13
	var pack := r.randf() < 0.75
	return {
		"skin": SKINS[r.randi() % SKINS.size()],
		"build": r.randf_range(0.92, 1.12),
		"pack": pack,
		"roll": (r.randi() % 3) if pack else 0,  # 0 none, 1 on top of the pack, 2 under it
		"shovel": pack and r.randf() < 0.35,
		"canteen": [-1, 1, 0][r.randi() % 3],  # which hip, 0 = none
		"net": r.randf() < 0.8,
	}


static func bone_side(s: float, right: int, left: int) -> int:
	return right if s > 0.0 else left


static func _t(a: Array, thin: bool) -> Array:
	return [a[0], a[a.size() - 1]] if thin and a.size() > 2 else a


static func build(look: Dictionary, lod: int) -> UnitGeo:
	var g := UnitGeo.new()
	if lod >= 2:
		_build_far(g, look)
		return g
	var d0 := lod == 0
	var sides := 8 if d0 else 4
	var ch := 0.35 if d0 else 0.0
	var ls := 6 if d0 else 4  # limb sides
	var thin := not d0  # the mid version keeps only the end rings of long parts
	var w: float = look.get("build", 1.0)
	var wl := lerpf(1.0, w, 0.6)
	var skin: Color = look.get("skin", SKINS[1])
	var X := Vector3.RIGHT
	var Z := Vector3.BACK

	# Legs and boots. The mid version runs the shin down into the boot.
	for s: float in [1.0, -1.0]:
		var x := 0.10 * s
		g.loft(_t([Vector3(x, 0.98, 0), Vector3(x, 0.74, -0.01), Vector3(x, 0.52, 0)], thin),
			_t([Vector2(0.085, 0.092) * wl, Vector2(0.072, 0.078) * wl, Vector2(0.06, 0.064) * wl], thin),
			X, ls, 0.0, TROUSER, bone_side(s, THIGH_R, THIGH_L), null, 0)
		var foot := bone_side(s, FOOT_R, FOOT_L)
		if d0:
			g.loft([Vector3(x, 0.53, 0), Vector3(x, 0.33, 0.01), Vector3(x, 0.17, 0)],
				[Vector2(0.06, 0.064) * wl, Vector2(0.056, 0.062) * wl, Vector2(0.05, 0.054) * wl],
				X, ls, 0.0, TROUSER, bone_side(s, SHIN_R, SHIN_L), null, 0)
			g.loft([Vector3(x, 0.19, 0.005), Vector3(x, 0.07, 0.01)],
				[Vector2(0.056, 0.06), Vector2(0.06, 0.066)], X, ls, 0.0, BOOT, foot, null, 0)
		else:
			g.loft([Vector3(x, 0.53, 0), Vector3(x, 0.08, 0.01)], [Vector2(0.06, 0.064) * wl, Vector2(0.058, 0.062)],
				X, 4, 0.0, TROUSER, bone_side(s, SHIN_R, SHIN_L), null, 0)
		g.loft([Vector3(x, 0.05, 0.08), Vector3(x, 0.045, -0.165)], [Vector2(0.06, 0.05), Vector2(0.054, 0.04)],
			X, sides, ch, BOOT, foot)

	# Hips, tunic, belt.
	g.loft([Vector3(0, 0.86, 0.005), Vector3(0, 1.06, 0)], [Vector2(0.17, 0.108) * w, Vector2(0.172, 0.11) * w],
		X, sides, ch, TROUSER, HIPS, null, 1)
	g.loft([Vector3(0, 0.98, 0), Vector3(0, 1.22, 0)], [Vector2(0.172, 0.116) * w, Vector2(0.178, 0.118) * w],
		X, sides, ch, OLIVE, SPINE, null, 0)
	var chest_c: Array = [Vector3(0, 1.20, 0), Vector3(0, 1.34, -0.008), Vector3(0, 1.44, 0.0), Vector3(0, 1.50, 0.012)]
	var chest_s: Array = [Vector2(0.178, 0.118) * w, Vector2(0.198, 0.128) * w, Vector2(0.205, 0.118) * w, Vector2(0.12, 0.085) * w]
	if thin:
		chest_c = [chest_c[0], chest_c[2], chest_c[3]]
		chest_s = [chest_s[0], chest_s[2], chest_s[3]]
	g.loft(chest_c, chest_s, X, sides, ch, OLIVE, CHEST, null, 2)
	g.loft([Vector3(0, 0.995, 0), Vector3(0, 1.06, 0)],
		[Vector2(0.19, 0.127) * w, Vector2(0.19, 0.127) * w], X, sides, ch, KHAKI, HIPS, null, 0)
	if d0:
		g.box(Vector3(0, 1.028, -0.13 * w), Vector3(0.026, 0.021, 0.006), BRASS, HIPS)
		for s: float in [1.0, -1.0]:
			# Chest pocket (the flap is its darker top), webbing strap, one big ammo pouch.
			g.box(Vector3(0.085 * s * w, 1.345, -0.133 * w), Vector3(0.052, 0.06, 0.01), OLIVE_DARK, CHEST)
			g.loft([Vector3(0.09 * s * w, 1.03, -0.132 * w), Vector3(0.11 * s * w, 1.32, -0.142 * w),
					Vector3(0.12 * s, 1.51, -0.02), Vector3(0.11 * s * w, 1.34, 0.128 * w), Vector3(0.09 * s * w, 1.05, 0.128 * w)],
				[Vector2(0.022, 0.006), Vector2(0.022, 0.006), Vector2(0.022, 0.006), Vector2(0.022, 0.006), Vector2(0.022, 0.006)],
				X, 4, 0.0, KHAKI, CHEST, null, 0)
			g.box(Vector3(s * 0.1 * w, 1.022, -0.135 * w), Vector3(0.06, 0.038, 0.024), KHAKI_DARK, HIPS,
				Basis(Vector3.UP, -0.25 * s))

	# Pack, blanket roll, shovel, canteen (the close version only carries the small kit).
	if look.get("pack", true):
		g.box(Vector3(0, 1.28, 0.168 * w), Vector3(0.125 * w, 0.13, 0.055), KHAKI_DARK, CHEST, Basis(), 0.25 if d0 else 0.0)
		var roll: int = look.get("roll", 0)
		if roll > 0 and d0:
			var y := 1.445 if roll == 1 else 1.12
			var z := 0.17 * w
			g.loft([Vector3(-0.155, y, z), Vector3(0.155, y, z)], [Vector2(0.052, 0.052), Vector2(0.052, 0.052)],
				Vector3.UP, 6, 0.0, BLANKET, CHEST)
		if look.get("shovel", false) and d0:
			g.box(Vector3(0.07, 1.20, 0.232 * w), Vector3(0.013, 0.14, 0.013), WOOD, CHEST)
			g.box(Vector3(0.07, 1.02, 0.235 * w), Vector3(0.065, 0.075, 0.008), METAL, CHEST)
	var cs: int = look.get("canteen", 0)
	if cs != 0 and d0:
		var cx := 0.168 * cs * w
		g.loft([Vector3(cx, 0.955, 0.06), Vector3(cx, 1.065, 0.06)], [Vector2(0.045, 0.04), Vector2(0.045, 0.04)],
			X, 6, 0.0, OLIVE_DARK, HIPS)

	# Neck, head, face.
	g.loft([Vector3(0, 1.47, 0.01), Vector3(0, 1.59, 0.0)], [Vector2(0.056, 0.056), Vector2(0.054, 0.054)],
		X, ls, 0.0, skin, NECK, null, 0)
	var head_c: Array = [Vector3(0, 1.555, -0.005), Vector3(0, 1.62, -0.012), Vector3(0, 1.735, 0.0), Vector3(0, 1.815, 0.005)]
	var head_s: Array = [Vector2(0.062, 0.07), Vector2(0.09, 0.102), Vector2(0.096, 0.108), Vector2(0.06, 0.068)]
	if thin:
		head_c = [head_c[0], head_c[2], head_c[3]]
		head_s = [head_s[0], head_s[2], head_s[3]]
	g.loft(head_c, head_s, X, sides, ch, skin, HEAD)
	# The shadowed eye band under the brow (no eyes drawn), the brow, the wedge nose.
	g.box(Vector3(0, 1.71, -0.101), Vector3(0.077, 0.016, 0.008), skin.darkened(0.36), HEAD)
	if d0:
		g.loft([Vector3(0, 1.705, -0.108), Vector3(0, 1.662, -0.143)], [Vector2(0.017, 0.013), Vector2(0.013, 0.006)],
			X, 4, 0.0, skin.darkened(0.06), HEAD, null, 2)
		g.box(Vector3(0, 1.735, -0.111), Vector3(0.088, 0.009, 0.009), skin.darkened(0.2), HEAD)

	# Helmet: brim, dome (with the net pattern), chin strap.
	var hs := 10 if d0 else 6
	g.loft([Vector3(0, 1.733, 0.0), Vector3(0, 1.748, 0.0)], [Vector2(0.168, 0.18), Vector2(0.164, 0.176)],
		X, hs, 0.0, HELMET, HEAD)
	var net: Variant = HELMET_NET if (d0 and look.get("net", true)) else null
	var dome_c: Array = [Vector3(0, 1.745, 0.004), Vector3(0, 1.80, 0.004), Vector3(0, 1.85, 0.006), Vector3(0, 1.888, 0.008)]
	var dome_s: Array = [Vector2(0.132, 0.142), Vector2(0.128, 0.138), Vector2(0.095, 0.103), Vector2(0.0, 0.0)]
	if thin:
		dome_c = [dome_c[0], dome_c[2], dome_c[3]]
		dome_s = [Vector2(0.132, 0.142), Vector2(0.11, 0.118), Vector2(0.0, 0.0)]
	g.loft(dome_c, dome_s, X, hs, 0.0, HELMET, HEAD, net, 0)
	if d0:
		for s: float in [1.0, -1.0]:
			g.loft([Vector3(0.127 * s, 1.742, 0.0), Vector3(0.06 * s, 1.575, -0.052)],
				[Vector2(0.011, 0.004), Vector2(0.011, 0.004)], Z, 4, 0.0, LEATHER, HEAD, null, 0)
		g.box(Vector3(0, 1.566, -0.056), Vector3(0.058, 0.005, 0.011), LEATHER, HEAD)

	# Arms and hands (hanging at rest; poses move them).
	for s: float in [1.0, -1.0]:
		g.loft(_t([Vector3(0.205 * s, 1.475, 0.0), Vector3(0.215 * s, 1.29, 0.0), Vector3(0.225 * s, 1.14, 0.0)], thin),
			_t([Vector2(0.074, 0.08) * wl, Vector2(0.064, 0.07) * wl, Vector2(0.058, 0.063) * wl], thin),
			X, ls, 0.0, OLIVE, bone_side(s, UARM_R, UARM_L), null, 1)
		var fa := bone_side(s, FARM_R, FARM_L)
		g.loft([Vector3(0.225 * s, 1.15, 0.0), Vector3(0.24 * s, 0.875, 0.0)],
			[Vector2(0.058, 0.062) * wl, Vector2(0.052, 0.056) * wl], X, ls, 0.0, OLIVE, fa, null, 0)
		var hb := bone_side(s, HAND_R, HAND_L)
		g.loft([Vector3(0.241 * s, 0.88, 0.0), Vector3(0.246 * s, 0.755, -0.008)],
			[Vector2(0.03, 0.048), Vector2(0.025, 0.044)], X, 4, 0.0, skin, hb, null, 2)
		if d0:
			g.box(Vector3(0.226 * s, 0.825, -0.042), Vector3(0.016, 0.03, 0.016), skin, hb)

	_build_rifle(g, lod)
	return g


static func _build_rifle(g: UnitGeo, lod: int) -> void:
	var o: Vector3 = REST[RIFLE]
	var X := Vector3.RIGHT
	if lod >= 1:
		# Mid and far: stock and barrel as two simple pieces.
		g.loft([o + Vector3(0, -0.04, 0.335), o + Vector3(0, 0.0, -0.56)], [Vector2(0.021, 0.05), Vector2(0.019, 0.026)],
			X, 4, 0.0, WOOD, RIFLE)
		if lod == 1:
			g.loft([o + Vector3(0, 0.03, -0.54), o + Vector3(0, 0.03, -0.82)], [Vector2(0.011, 0.011), Vector2(0.011, 0.011)],
				X, 4, 0.0, METAL, RIFLE, null, 2)
		return
	# Butt stock and wrist.
	g.loft([o + Vector3(0, -0.045, 0.335), o + Vector3(0, -0.02, 0.12), o + Vector3(0, 0.0, 0.0)],
		[Vector2(0.022, 0.066), Vector2(0.02, 0.044), Vector2(0.019, 0.03)], X, 6, 0.0, WOOD, RIFLE, null, 1)
	# Fore stock.
	g.loft([o + Vector3(0, 0.0, 0.0), o + Vector3(0, 0.004, -0.56)], [Vector2(0.019, 0.03), Vector2(0.019, 0.025)],
		X, 6, 0.0, WOOD, RIFLE, null, 2)
	# Receiver with bolt handle, barrel, a band, the sling.
	g.box(o + Vector3(0, 0.036, -0.08), Vector3(0.018, 0.1, 0.024), METAL, RIFLE, Basis(Vector3.RIGHT, PI / 2))
	g.box(o + Vector3(0.034, 0.042, -0.02), Vector3(0.02, 0.008, 0.008), METAL, RIFLE)
	g.loft([o + Vector3(0, 0.03, -0.54), o + Vector3(0, 0.03, -0.82)], [Vector2(0.011, 0.011), Vector2(0.011, 0.011)],
		X, 4, 0.0, METAL, RIFLE, null, 2)
	g.loft([o + Vector3(0, 0.01, -0.39), o + Vector3(0, 0.01, -0.415)], [Vector2(0.023, 0.038), Vector2(0.023, 0.038)],
		X, 4, 0.0, METAL, RIFLE, null, 0)
	g.loft([o + Vector3(0, -0.06, 0.25), o + Vector3(0, -0.1, -0.08), o + Vector3(0, -0.04, -0.46)],
		[Vector2(0.012, 0.004), Vector2(0.012, 0.004), Vector2(0.012, 0.004)], X, 4, 0.0, LEATHER, RIFLE, null, 0)


## The far version: one simple shape per body part (about 150 triangles).
static func _build_far(g: UnitGeo, look: Dictionary) -> void:
	var skin: Color = look.get("skin", SKINS[1])
	var X := Vector3.RIGHT
	for s: float in [1.0, -1.0]:
		var x := 0.10 * s
		g.loft([Vector3(x, 0.98, 0), Vector3(x, 0.52, 0)], [Vector2(0.08, 0.085), Vector2(0.06, 0.064)],
			X, 4, 0.0, TROUSER, bone_side(s, THIGH_R, THIGH_L), null, 0)
		g.loft([Vector3(x, 0.53, 0), Vector3(x, 0.12, 0)], [Vector2(0.06, 0.064), Vector2(0.055, 0.06)],
			X, 4, 0.0, TROUSER, bone_side(s, SHIN_R, SHIN_L), null, 0)
		g.box(Vector3(x, 0.06, -0.04), Vector3(0.06, 0.06, 0.12), BOOT, bone_side(s, FOOT_R, FOOT_L))
		g.loft([Vector3(0.205 * s, 1.475, 0), Vector3(0.225 * s, 1.14, 0)], [Vector2(0.07, 0.075), Vector2(0.058, 0.062)],
			X, 4, 0.0, OLIVE, bone_side(s, UARM_R, UARM_L))
		g.loft([Vector3(0.225 * s, 1.15, 0), Vector3(0.245 * s, 0.76, -0.008)], [Vector2(0.055, 0.058), Vector2(0.035, 0.045)],
			X, 4, 0.0, OLIVE, bone_side(s, FARM_R, FARM_L))
	g.loft([Vector3(0, 0.86, 0), Vector3(0, 1.08, 0)], [Vector2(0.175, 0.112), Vector2(0.18, 0.115)], X, 4, 0.0, TROUSER, HIPS)
	g.loft([Vector3(0, 1.06, 0), Vector3(0, 1.48, 0)], [Vector2(0.18, 0.118), Vector2(0.2, 0.12)], X, 4, 0.0, OLIVE, CHEST)
	if look.get("pack", true):
		g.box(Vector3(0, 1.28, 0.16), Vector3(0.12, 0.13, 0.05), KHAKI_DARK, CHEST)
	g.box(Vector3(0, 1.68, -0.005), Vector3(0.09, 0.12, 0.1), skin, HEAD)
	g.loft([Vector3(0, 1.735, 0), Vector3(0, 1.75, 0), Vector3(0, 1.885, 0.006)],
		[Vector2(0.168, 0.178), Vector2(0.13, 0.14), Vector2(0.06, 0.065)], X, 4, 0.0, HELMET, HEAD)
	_build_rifle(g, 2)
