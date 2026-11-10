class_name ZombieBuilder
extends RefCounted
## The zombies (Question Chat, 2026-11-10): fallen soldiers back on their feet, on the soldier skeleton.
## The body is SoldierBuilder's (same bones, so every pose, clip and IK works), then:
##   - the cloth is faded and dirtied, the lower legs caked with mud, stains spattered over it;
##   - grey-green dead skin, pale staring eyes, a dark open mouth;
##   - wounds and rags: a torn-open chest with ribs showing, a bare torn forearm, hanging rags;
##   - kit by kind: shambler (helmet or bare, some in gas masks), runner (bare, thin, fresher),
##     brute (big and broad, scrap-iron plates riveted on, a bucket helm, a nailed timber club).
## kinds: "shambler", "runner", "brute". lod as the soldier's.

const B := preload("res://scripts/units/soldier_builder.gd")

const SKINS: Array[Color] = [Color(0.56, 0.60, 0.50), Color(0.49, 0.53, 0.45), Color(0.62, 0.62, 0.55),
	Color(0.43, 0.47, 0.40), Color(0.52, 0.50, 0.46)]
const BONE := Color(0.84, 0.80, 0.68)
const STAIN := Color(0.27, 0.13, 0.10)
const WOUND := Color(0.36, 0.10, 0.09)
const MUD := Color(0.34, 0.27, 0.18)
const EYE := Color(0.96, 0.92, 0.62)
const MOUTH := Color(0.12, 0.06, 0.05)
const HAIR := Color(0.17, 0.14, 0.11)
const RUST := Color(0.44, 0.27, 0.16)
const IRON := Color(0.30, 0.29, 0.28)
const MASK := Color(0.30, 0.31, 0.26)
const LENS := Color(0.55, 0.62, 0.60)
const BRUTE_SCALE := 1.25


static func look_for_kind(seed_value: int, kind: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 104729 + 71
	var lk := B.look_from_seed(seed_value)
	lk.merge({"role": "zombie", "kind": kind, "rifle": false, "pistol": false, "pack": false, "roll": 0, "shovel": false,
		"skin": SKINS[r.randi() % SKINS.size()], "net": r.randf() < 0.4, "stain_seed": r.randi() % 1000,
		"ribs": r.randf() < 0.5, "bare_arm": [1, -1, 0][r.randi() % 3], "rags": r.randf() < 0.7}, true)
	match kind:
		"shambler":
			var mask := r.randf() < 0.3
			lk.merge({"bare": r.randf() < 0.4 and not mask, "gas_mask": mask, "canteen": [-1, 0][r.randi() % 2],
				"build": r.randf_range(0.95, 1.1)}, true)
		"runner":
			lk.merge({"bare": true, "webbing": r.randf() < 0.5, "canteen": 0, "build": r.randf_range(0.9, 0.98),
				"skin": SKINS[[0, 2][r.randi() % 2]]}, true)
		"brute":
			lk.merge({"bare": true, "webbing": false, "canteen": 0, "build": 1.32, "ribs": false, "bare_arm": 1,
				"bucket": true}, true)
	return lk


static func build(look: Dictionary, lod: int) -> UnitGeo:
	var g := B.build(look, lod)
	_weather(g, look)
	var d0 := lod == 0
	var w: float = look.get("build", 1.0)
	var skin: Color = look["skin"]
	var X := Vector3.RIGHT
	if lod >= 2:
		if look.get("kind", "") == "brute":
			g.box(Vector3(0, 1.3, -0.12 * w), Vector3(0.17 * w, 0.17, 0.03), RUST, B.CHEST)
			g.box(Vector3(0, 1.79, 0.0), Vector3(0.11, 0.09, 0.12), IRON, B.HEAD)
			_club(g, false)
		elif look.get("bare", false):
			g.box(Vector3(0, 1.80, 0.01), Vector3(0.088, 0.03, 0.1), HAIR, B.HEAD)
		return g
	# The face: pale eyes in the shadowed band, the jaw hanging open.
	if not look.get("gas_mask", false):
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.034 * s, 1.708, -0.106), Vector3(0.013, 0.008, 0.006), EYE, B.HEAD)
		g.box(Vector3(0, 1.618, -0.093), Vector3(0.03, 0.022 if d0 else 0.018, 0.012), MOUTH, B.HEAD)
		if d0:
			g.box(Vector3(0, 1.638, -0.098), Vector3(0.026, 0.004, 0.006), BONE, B.HEAD)  # the top teeth
	else:
		_gas_mask(g, d0)
	# Bare heads: patchy hair, a pale scalp wound.
	if look.get("bare", false) and not look.get("bucket", false):
		g.loft([Vector3(0, 1.74, 0.012), Vector3(0, 1.80, 0.012), Vector3(0, 1.825, 0.01)],
			[Vector2(0.1, 0.112), Vector2(0.088, 0.1), Vector2(0.05, 0.06)], X, 8 if d0 else 4, 0.0, HAIR, B.HEAD)
		if d0:
			g.box(Vector3(0.05, 1.80, -0.02), Vector3(0.03, 0.012, 0.035), WOUND, B.HEAD, Basis(Vector3.FORWARD, 0.5))
	# The torn-open chest: a dark hole with ribs across it.
	if look.get("ribs", false):
		var s := 1.0 if int(look.get("stain_seed", 0)) % 2 == 0 else -1.0
		g.box(Vector3(0.075 * s * w, 1.28, -0.124 * w), Vector3(0.06, 0.07, 0.012), WOUND.darkened(0.3), B.CHEST)
		if d0:
			for k in 3:
				g.box(Vector3(0.075 * s * w, 1.235 + 0.04 * k, -0.135 * w), Vector3(0.055, 0.007, 0.006), BONE, B.CHEST,
					Basis(Vector3.FORWARD, 0.18 * s))
	# One bare, torn forearm: the sleeve ripped off, the flesh grey with a dark gash.
	var ba: int = look.get("bare_arm", 0)
	if ba != 0:
		var fa := B.bone_side(float(ba), B.FARM_R, B.FARM_L)
		g.loft([Vector3(0.226 * ba, 1.10, 0.0), Vector3(0.24 * ba, 0.885, 0.0)],
			[Vector2(0.062, 0.066) * lerpf(1.0, w, 0.6), Vector2(0.054, 0.058) * lerpf(1.0, w, 0.6)], X, 6 if d0 else 4, 0.0,
			skin, fa, null, 0)
		g.loft([Vector3(0.226 * ba, 1.155, 0.0), Vector3(0.226 * ba, 1.10, 0.0)],
			[Vector2(0.066, 0.07) * lerpf(1.0, w, 0.6), Vector2(0.06, 0.064) * lerpf(1.0, w, 0.6)], X, 6 if d0 else 4, 0.0,
			B.OLIVE.darkened(0.3).lerp(Color(0.5, 0.5, 0.45), 0.3), fa, null, 0)
		if d0:
			g.box(Vector3(0.24 * ba + 0.0, 1.0, -0.055), Vector3(0.025, 0.05, 0.006), WOUND, fa)
	# Rags hanging from the tunic hem.
	if look.get("rags", false) and d0:
		var r := RandomNumberGenerator.new()
		r.seed = int(look.get("stain_seed", 0)) + 3
		for k in 4:
			var a := r.randf_range(-PI, PI)
			var p := Vector3(sin(a) * 0.17 * w, 0.88, cos(a) * 0.115 * w)
			g.box(p, Vector3(0.025, r.randf_range(0.04, 0.08), 0.004), B.OLIVE.darkened(0.35), B.HIPS,
				Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, r.randf_range(-0.3, 0.3)))
	if look.get("kind", "") == "brute":
		_brute_kit(g, d0, w)
	return g


## Faded, dirtied cloth; mud on the legs; stains. Skin and the added kit keep their colours.
static func _weather(g: UnitGeo, look: Dictionary) -> void:
	var skin: Color = look["skin"]
	var sd: int = look.get("stain_seed", 0)
	var fresh: bool = look.get("kind", "") == "runner"
	var n := g.col.size() / 3
	for i in n:
		var c := g.col[i * 3]
		var p := (g.pos[i * 3] + g.pos[i * 3 + 1] + g.pos[i * 3 + 2]) / 3.0
		var out: Color
		if c.is_equal_approx(skin):
			out = skin
			if sin(p.x * 61.0 + p.y * 37.0 + p.z * 53.0 + float(sd)) > 0.85:
				out = skin.darkened(0.25).lerp(WOUND, 0.3)
		else:
			var grey := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			out = c.lerp(Color(grey, grey, grey), 0.38 if not fresh else 0.25).darkened(0.18 if not fresh else 0.1)
			var mud := clampf((0.55 - p.y) / 0.45, 0.0, 1.0) * (0.75 if not fresh else 0.5)
			out = out.lerp(MUD, mud)
			var h := sin(p.x * 47.0 + float(sd) * 0.37) * sin(p.y * 29.0 + float(sd)) * sin(p.z * 41.0 + 1.7)
			if h > 0.28 and p.y > 0.8:
				out = out.lerp(STAIN, 0.7)
			elif h < -0.4:
				out = out.darkened(0.2)
		for k in 3:
			g.col[i * 3 + k] = out


static func _gas_mask(g: UnitGeo, d0: bool) -> void:
	var X := Vector3.RIGHT
	g.loft([Vector3(0, 1.73, -0.07), Vector3(0, 1.66, -0.11), Vector3(0, 1.60, -0.10)],
		[Vector2(0.088, 0.03), Vector2(0.075, 0.035), Vector2(0.06, 0.03)], Vector3.BACK, 8 if d0 else 4, 0.0, MASK, B.HEAD, null, 0)
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(0.037 * s, 1.706, -0.1), Vector3(0.037 * s, 1.706, -0.118)],
			[Vector2(0.024, 0.024), Vector2(0.024, 0.024)], X, 8 if d0 else 4, 0.0, LENS if d0 else MASK, B.HEAD)
	g.loft([Vector3(0, 1.62, -0.11), Vector3(0, 1.585, -0.16)], [Vector2(0.026, 0.026), Vector2(0.03, 0.03)],
		X, 8 if d0 else 4, 0.0, B.METAL, B.HEAD)
	if d0:
		# The hose down to the canister at the chest.
		g.loft([Vector3(0, 1.57, -0.165), Vector3(0.02, 1.45, -0.16), Vector3(0.03, 1.33, -0.15)],
			[Vector2(0.014, 0.014), Vector2(0.014, 0.014), Vector2(0.014, 0.014)], X, 4, 0.0, MASK.darkened(0.3), B.CHEST, null, 0)
		g.box(Vector3(0.03, 1.27, -0.16), Vector3(0.05, 0.06, 0.03), MASK, B.CHEST, Basis(), 0.25)
		for s: float in [1.0, -1.0]:
			g.loft([Vector3(0.088 * s, 1.72, -0.06), Vector3(0.1 * s, 1.73, 0.05)], [Vector2(0.008, 0.003), Vector2(0.008, 0.003)],
				X, 4, 0.0, B.LEATHER, B.HEAD, null, 0)


## The brute: scrap plates riveted over chest and belly, a shoulder plate, a bucket helm, the club.
static func _brute_kit(g: UnitGeo, d0: bool, w: float) -> void:
	g.box(Vector3(0, 1.32, -0.135 * w), Vector3(0.165 * w, 0.14, 0.018), RUST, B.CHEST, Basis(Vector3.RIGHT, -0.08))
	g.box(Vector3(0.02, 1.07, -0.125 * w), Vector3(0.14 * w, 0.08, 0.016), IRON, B.SPINE, Basis(Vector3.FORWARD, 0.06))
	g.box(Vector3(0, 1.32, 0.13 * w), Vector3(0.15 * w, 0.13, 0.015), IRON, B.CHEST)
	g.box(Vector3(-0.24 * lerpf(1.0, w, 0.6), 1.43, 0.0), Vector3(0.075, 0.02, 0.09), RUST, B.UARM_L, Basis(Vector3.FORWARD, -0.45))
	# Bucket helm with eye slit.
	g.loft([Vector3(0, 1.58, 0.005), Vector3(0, 1.86, 0.005)], [Vector2(0.105, 0.115), Vector2(0.098, 0.108)],
		Vector3.RIGHT, 8 if d0 else 4, 0.0, IRON, B.HEAD, null, 1)
	g.box(Vector3(0, 1.705, -0.112), Vector3(0.07, 0.012, 0.01), MOUTH, B.HEAD)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.03 * s, 1.705, -0.118), Vector3(0.012, 0.006, 0.004), EYE, B.HEAD)
	if d0:
		for k in 6:
			var x := -0.13 * w + 0.052 * w * k
			g.box(Vector3(x, 1.44, -0.152 * w), Vector3(0.01, 0.01, 0.006), IRON.darkened(0.3), B.CHEST)
			g.box(Vector3(x, 1.20, -0.142 * w), Vector3(0.01, 0.01, 0.006), IRON.darkened(0.3), B.CHEST)
		g.box(Vector3(0, 1.83, 0.005), Vector3(0.11, 0.008, 0.12), RUST, B.HEAD)
		# Chain across the chest.
		for k in 5:
			g.box(Vector3(-0.15 + 0.07 * k, 1.47 - 0.035 * k, -0.15 * w), Vector3(0.022, 0.012, 0.008), IRON, B.CHEST,
				Basis(Vector3.FORWARD, -0.45))
	_club(g, d0)


## A heavy timber with nails and an iron band, held at GRIP_R on the item bone, head forward (-Z).
static func _club(g: UnitGeo, d0: bool) -> void:
	var o: Vector3 = B.REST[B.RIFLE] + B.GRIP_R
	var X := Vector3.RIGHT
	g.loft([o + Vector3(0, 0, 0.12), o + Vector3(0, 0, -0.35), o + Vector3(0, 0, -1.0)],
		[Vector2(0.03, 0.03), Vector2(0.04, 0.045), Vector2(0.07, 0.075)], X, 6 if d0 else 4, 0.0, B.WOOD_DARK, B.RIFLE)
	g.loft([o + Vector3(0, 0, -0.7), o + Vector3(0, 0, -0.78)], [Vector2(0.065, 0.07), Vector2(0.067, 0.072)],
		X, 6 if d0 else 4, 0.0, IRON, B.RIFLE, null, 0)
	if d0:
		for k in 8:
			var a := TAU * k / 8.0
			var z := -0.85 - 0.05 * (k % 3)
			var d := Vector3(cos(a), sin(a), 0)
			g.box(o + Vector3(0, 0, z) + d * 0.08, Vector3(0.005, 0.03, 0.005), IRON, B.RIFLE,
				Basis(Vector3.BACK, a - PI * 0.5))
