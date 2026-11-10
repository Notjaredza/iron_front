class_name MedievalBuilder
extends RefCounted
## The medieval host (Building Chat 1, 2026-11-10): the ancient enemy's feudal muster on the rifleman's body. Bright
## heraldry: every lord has his arms (two tinctures, a division and a charge, from a seed), his men wear his livery,
## knights and the captain bear their own. The arms are painted on surcoats, shields, banners and pavises.
## Roles:
##   man_at_arms  mail and surcoat, nasal or kettle helm, sword and heater shield
##   spearman     padded jack and surcoat, kettle hat, spear and heater shield
##   crossbow     padded jack, kettle hat, crossbow (the rifle's grips: aims and carries like one), pavise on the back
##   longbow      padded jack or tunic, cap or hood, the longbow (held in the left hand), quiver, a falchion
##   captain      plate over mail, surcoat, crested great helm, sword and shield
##   banner       mail and surcoat, kettle hat, the lord's banner on a crossbar pole
##   heavy        full plate, visored bascinet, two-handed sword, pole-axe or halberd
##   levy         tunic or bare shirt, hood or bare head; pitchfork, flail or billhook
##   knight       (mounted) plate over mail, surcoat, crested great helm, lance, sword, shield
##   scout        (mounted) padded jack, kettle hat, javelin, small shield
## Items are built in the item bone's frame (grip at SoldierBuilder.GRIP_R, along -Z) except the bow (along +Y, its
## grip at GRIP_R, the belly toward +Z). The shield is placed by Medieval each skeleton update.

const B := preload("res://scripts/units/soldier_builder.gd")
const OR := Color(0.88, 0.70, 0.20)
const ARGENT := Color(0.90, 0.90, 0.86)
const GULES := Color(0.72, 0.10, 0.10)
const AZURE := Color(0.13, 0.26, 0.66)
const VERT := Color(0.13, 0.45, 0.20)
const SABLE := Color(0.08, 0.08, 0.09)
const PURPURE := Color(0.42, 0.16, 0.45)
const METALS: Array[Color] = [OR, ARGENT]
const COLOURS: Array[Color] = [GULES, AZURE, VERT, SABLE, PURPURE, GULES, AZURE]
const DIVS: Array[String] = ["plain", "per_pale", "per_fess", "quarterly", "chevron", "bend", "chief", "per_pale", "quarterly"]
const CHARGES: Array[String] = ["none", "cross", "roundels", "beast", "beast", "cross", "roundels", "star"]
const MAIL := Color(0.46, 0.47, 0.48)
const MAIL_DARK := Color(0.30, 0.31, 0.32)
const PLATE := Color(0.68, 0.69, 0.71)
const PLATE_DARK := Color(0.42, 0.43, 0.45)
const PADDED := Color(0.78, 0.71, 0.55)
const PADDED_DARK := Color(0.62, 0.55, 0.40)
const LEATHER := Color(0.38, 0.24, 0.13)
const LEATHER_DARK := Color(0.22, 0.14, 0.08)
const WOOD := Color(0.52, 0.36, 0.20)
const WOOD_DARK := Color(0.36, 0.24, 0.13)
const STEEL := Color(0.70, 0.71, 0.73)
const IRON := Color(0.28, 0.28, 0.29)
const DRAB: Array[Color] = [Color(0.48, 0.40, 0.28), Color(0.42, 0.44, 0.34), Color(0.55, 0.50, 0.40), Color(0.40, 0.30, 0.24),
	Color(0.33, 0.36, 0.40)]
const HOSE: Array[Color] = [Color(0.45, 0.12, 0.10), Color(0.20, 0.25, 0.42), Color(0.30, 0.32, 0.22), Color(0.48, 0.40, 0.28),
	Color(0.15, 0.15, 0.16)]
const HEAVY_WEAPONS: Array[String] = ["greatsword", "poleaxe", "halberd"]
const LEVY_WEAPONS: Array[String] = ["pitchfork", "flail", "billhook"]
const LORDS := 6
## Shield (its frame: the hand grip at the origin, face toward -Z, top +Y).
const SHIELD_W := 0.31
const SHIELD_TOP := 0.34
const SHIELD_BOT := -0.42
const BOW_HALF := 0.86
const BOW_DEPTH := 0.13
const LANCE_TIP := Vector3(0, -0.015, -2.85)
const BANNER_TOP := Vector3(0, -0.015, -2.3)
const HEATER: Array[Vector2] = [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -0.1), Vector2(0.62, -0.62), Vector2(0, -1),
	Vector2(-0.62, -0.62), Vector2(-1, -0.1)]
const RECT: Array[Vector2] = [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]


# ---------------------------------------------------------------- heraldry

## A lord's arms from his number (or a knight's own from his seed).
static func arms(seed_value: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 7717 + 211
	var metal := METALS[r.randi() % 2]
	var colour := COLOURS[r.randi() % COLOURS.size()]
	var swap := r.randf() < 0.5
	var div := DIVS[r.randi() % DIVS.size()]
	var charge := CHARGES[r.randi() % CHARGES.size()]
	if div == "plain" and charge == "none":
		charge = "beast"
	var field := colour if swap else metal
	var second := metal if swap else colour
	# The charge goes in the tincture that stands out on the field (a metal on a colour and the other way round).
	return {"field": field, "second": second, "div": div, "charge": charge,
		"charge_col": (metal if field == colour else colour) if div == "plain" or div == "chief" else (OR if colour != SABLE and field != OR and second != OR else ARGENT if field != ARGENT and second != ARGENT else SABLE)}


static func lord_arms(lord: int) -> Dictionary:
	return arms(1000 + lord * 37)


## Clips a convex polygon to a convex one (Sutherland-Hodgman, both counter-clockwise or both clockwise).
static func _clip(poly: Array, clip: Array) -> Array:
	var out := poly.duplicate()
	var n := clip.size()
	var sgn := _area(clip)
	for i in n:
		var a: Vector2 = clip[i]
		var b: Vector2 = clip[(i + 1) % n]
		var inp := out
		out = []
		if inp.is_empty():
			break
		for j in inp.size():
			var p: Vector2 = inp[j]
			var q: Vector2 = inp[(j + 1) % inp.size()]
			var pin := _side(a, b, p) * sgn >= 0.0
			var qin := _side(a, b, q) * sgn >= 0.0
			if pin:
				out.append(p)
			if pin != qin:
				var dp := _side(a, b, p)
				var dq := _side(a, b, q)
				out.append(p + (q - p) * (dp / (dp - dq)))
	return out


static func _side(a: Vector2, b: Vector2, p: Vector2) -> float:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)


static func _area(poly: Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return signf(s)


static func _bar(a: Vector2, b: Vector2, w: float) -> Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w
	return [a + n, b + n, b - n, a - n]


static func _ngon(c: Vector2, r: Vector2, k: int) -> Array:
	var out := []
	for i in k:
		var a := TAU * i / float(k)
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out


static func _box2(c: Vector2, h: Vector2) -> Array:
	return [c + Vector2(-h.x, h.y), c + Vector2(h.x, h.y), c + Vector2(h.x, -h.y), c + Vector2(-h.x, -h.y)]


## The arms as a list of [polygon (2D, -1..1), colour] layers, in painting order, clipped to the shape.
static func layers(a: Dictionary, shape: Array, detail := true) -> Array:
	var out: Array = [[shape, a["field"]]]
	var s2: Color = a["second"]
	var parts: Array = []
	match a["div"]:
		"per_pale":
			parts = [[Vector2(0, 1.2), Vector2(1.2, 1.2), Vector2(1.2, -1.2), Vector2(0, -1.2)]]
		"per_fess":
			parts = [[Vector2(-1.2, 0), Vector2(1.2, 0), Vector2(1.2, -1.2), Vector2(-1.2, -1.2)]]
		"quarterly":
			parts = [[Vector2(0, 1.2), Vector2(1.2, 1.2), Vector2(1.2, 0), Vector2(0, 0)],
				[Vector2(-1.2, 0), Vector2(0, 0), Vector2(0, -1.2), Vector2(-1.2, -1.2)]]
		"chevron":
			parts = [_bar(Vector2(-1.1, -0.85), Vector2(0, 0.25), 0.2), _bar(Vector2(0, 0.25), Vector2(1.1, -0.85), 0.2)]
		"bend":
			parts = [_bar(Vector2(1.1, 1.1), Vector2(-1.1, -1.1), 0.26)]
		"chief":
			parts = [[Vector2(-1.2, 1.2), Vector2(1.2, 1.2), Vector2(1.2, 0.45), Vector2(-1.2, 0.45)]]
	for p: Array in parts:
		out.append([p, s2])
	if not detail:
		return _clip_all(out, shape)
	var cc: Color = a["charge_col"]
	var cy := -0.2 if a["div"] == "chief" else 0.0
	match a["charge"]:
		"cross":
			out.append([_box2(Vector2(0, cy), Vector2(0.17, 1.2)), cc])
			out.append([_box2(Vector2(0, cy + 0.2), Vector2(1.2, 0.15)), cc])
		"roundels":
			for c: Vector2 in [Vector2(-0.4, 0.45), Vector2(0.4, 0.45), Vector2(0, -0.25)]:
				out.append([_ngon(c + Vector2(0, cy), Vector2(0.22, 0.2), 8), cc])
		"star":
			for k in 3:
				out.append([_bar(Vector2(0, cy).lerp(Vector2(0, cy) + Vector2(cos(k * PI / 3.0), sin(k * PI / 3.0)) * 0.45, -1.0),
					Vector2(0, cy) + Vector2(cos(k * PI / 3.0), sin(k * PI / 3.0)) * 0.45, 0.08), cc])
		"beast":
			# A rampant beast, rough: body, head, legs up and down, a tail.
			var o := Vector2(0.0, cy - 0.05)
			out.append([_bar(o + Vector2(-0.1, -0.35), o + Vector2(0.12, 0.3), 0.22), cc])
			out.append([_ngon(o + Vector2(0.2, 0.47), Vector2(0.19, 0.16), 6), cc])
			out.append([_bar(o + Vector2(0.1, 0.2), o + Vector2(0.45, 0.42), 0.08), cc])
			out.append([_bar(o + Vector2(0.05, 0.05), o + Vector2(0.42, 0.05), 0.08), cc])
			out.append([_bar(o + Vector2(-0.1, -0.3), o + Vector2(0.2, -0.7), 0.09), cc])
			out.append([_bar(o + Vector2(-0.15, -0.35), o + Vector2(-0.35, -0.72), 0.09), cc])
			out.append([_bar(o + Vector2(-0.2, -0.2), o + Vector2(-0.5, 0.35), 0.035), cc])
	return _clip_all(out, shape)


static func _clip_all(ls: Array, shape: Array) -> Array:
	var out := []
	for l: Array in ls:
		var c := _clip(l[0], shape)
		if c.size() >= 3:
			out.append([c, l[1]])
	return out


## Paints arms on a flat panel: centre c, half sizes hw / hh along right / up, facing normal (both faces when two).
static func paint(g: UnitGeo, a: Dictionary, shape: Array, c: Vector3, right: Vector3, up: Vector3, hw: float, hh: float,
		bone: int, two := false, detail := true) -> void:
	var nrm := right.cross(up).normalized()
	var ls := layers(a, shape, detail)
	for side in (2 if two else 1):
		var sgn := 1.0 if side == 0 else -1.0
		for i in ls.size():
			var poly: Array = ls[i][0]
			var col: Color = ls[i][1]
			var off := nrm * (0.0012 * i + 0.0005) * sgn
			var pts: Array[Vector3] = []
			for p: Vector2 in poly:
				pts.append(c + right * (p.x * hw * (sgn if side == 1 else 1.0)) + up * (p.y * hh) + off)
			for k in range(1, pts.size() - 1):
				_tri2(g, pts[0], pts[k], pts[k + 1], col, bone, nrm * sgn)


## A triangle facing along n.
static func _tri2(g: UnitGeo, a: Vector3, b: Vector3, c: Vector3, col: Color, bone: int, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) >= 0.0:
		g.emit(a, b, c, col, bone)
	else:
		g.emit(a, c, b, col, bone)


# ---------------------------------------------------------------- looks

static func look_for_role(seed_value: int, role: String, lord := -1) -> Dictionary:
	var lk := B.look_from_seed(seed_value)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 313 + 17
	var ld := lord if lord >= 0 else r.randi() % LORDS
	lk.merge({"role": role, "rifle": false, "pistol": false, "pack": false, "roll": 0, "shovel": false, "canteen": 0,
		"webbing": false, "bare": true, "net": false, "gloves": false, "lord": ld, "arms": lord_arms(ld),
		"hose": HOSE[r.randi() % HOSE.size()], "drab": DRAB[r.randi() % DRAB.size()],
		"hair": [Color(0.16, 0.11, 0.07), Color(0.30, 0.20, 0.11), Color(0.45, 0.31, 0.16), Color(0.55, 0.45, 0.30)][r.randi() % 4]}, true)
	match role:
		"man_at_arms":
			lk.merge({"body": "mail", "surcoat": true, "helm": ["nasal", "kettle", "nasal"][r.randi() % 3], "weapon": "sword",
				"shield": true, "gloves": true}, true)
		"spearman":
			lk.merge({"body": "padded", "surcoat": r.randf() < 0.6, "helm": "kettle", "weapon": "spear", "shield": true}, true)
		"crossbow":
			lk.merge({"body": "padded", "surcoat": false, "helm": "kettle", "weapon": "crossbow", "pavise": true, "sword_hip": true}, true)
		"longbow":
			lk.merge({"body": ["padded", "tunic"][r.randi() % 2], "surcoat": false, "helm": ["cap", "hood", "bare"][r.randi() % 3],
				"weapon": "bow", "quiver": true, "sword_hip": true}, true)
		"captain":
			lk.merge({"body": "plate", "surcoat": true, "helm": "great", "crest": true, "weapon": "sword", "shield": true,
				"gloves": true, "arms": arms(seed_value * 3 + 5)}, true)
		"banner":
			lk.merge({"body": "mail", "surcoat": true, "helm": "kettle", "weapon": "banner", "gloves": true, "sword_hip": true}, true)
		"heavy":
			lk.merge({"body": "plate", "surcoat": r.randf() < 0.4, "helm": "bascinet", "gloves": true,
				"weapon": HEAVY_WEAPONS[r.randi() % HEAVY_WEAPONS.size()]}, true)
		"levy":
			lk.merge({"body": ["tunic", "shirt", "tunic"][r.randi() % 3], "surcoat": false, "helm": ["hood", "bare", "cap", "hood"][r.randi() % 4],
				"weapon": LEVY_WEAPONS[r.randi() % LEVY_WEAPONS.size()], "build": r.randf_range(0.88, 1.06)}, true)
		"knight":
			lk.merge({"body": "plate", "surcoat": true, "helm": "great", "crest": true, "weapon": "lance", "shield": true,
				"gloves": true, "sword_hip": true, "arms": arms(seed_value * 11 + 3)}, true)
		"scout":
			lk.merge({"body": "padded", "surcoat": false, "helm": "kettle", "weapon": "javelin", "shield": true, "small_shield": true}, true)
	return lk


# ---------------------------------------------------------------- the body

static func build(look: Dictionary, lod: int) -> UnitGeo:
	var g := B.build(look, lod)
	var body: String = look.get("body", "tunic")
	var w: float = look.get("build", 1.0)
	var d0 := lod == 0
	var X := Vector3.RIGHT
	var a: Dictionary = look["arms"]
	var hose: Color = look["hose"]
	var drab: Color = look["drab"]
	# Recolour the uniform to the body kind: the jacket and sleeves, the trousers to hose (or mail / plate), the boots
	# to shoes, the belt to leather.
	var top: Color = {"mail": MAIL, "plate": MAIL, "padded": PADDED, "tunic": drab, "shirt": Color(0.80, 0.76, 0.66)}[body]
	var legs: Color = MAIL if body == "mail" else PLATE if body == "plate" else hose
	var map := {B.OLIVE: top, B.OLIVE_DARK: top.darkened(0.15), B.TROUSER: legs, B.BOOT: LEATHER_DARK if body != "plate" else PLATE_DARK,
		B.BOOT_DARK: LEATHER_DARK, B.KHAKI: LEATHER, B.KHAKI_DARK: LEATHER_DARK}
	for i in g.col.size():
		var c: Color = g.col[i]
		if map.has(c):
			g.col[i] = map[c]
	if lod >= 2:
		_far(g, look)
		return g
	var sides := 8 if d0 else 4
	# Body layers.
	match body:
		"padded":
			# The quilted jack: horizontal quilting as alternating bands; puffed sleeves.
			g.loft([Vector3(0, 0.84, 0.0), Vector3(0, 1.0, 0.0), Vector3(0, 1.22, -0.004), Vector3(0, 1.4, -0.004), Vector3(0, 1.5, 0.012)],
				[Vector2(0.2, 0.135) * w, Vector2(0.196, 0.132) * w, Vector2(0.2, 0.138) * w, Vector2(0.216, 0.14) * w, Vector2(0.13, 0.095) * w],
				X, sides, 0.0, PADDED, B.CHEST, PADDED_DARK if d0 else null, 2)
		"mail", "plate":
			g.loft([Vector3(0, 0.8, 0.0), Vector3(0, 1.0, 0.0), Vector3(0, 1.3, -0.004), Vector3(0, 1.5, 0.012)],
				[Vector2(0.2, 0.13) * w, Vector2(0.195, 0.13) * w, Vector2(0.21, 0.135) * w, Vector2(0.13, 0.095) * w],
				X, sides, 0.0, MAIL, B.CHEST, MAIL_DARK if d0 else null, 2)
		"shirt":
			g.box(Vector3(0, 1.2, -0.122 * w), Vector3(0.02, 0.1, 0.005), Color(0.55, 0.45, 0.35), B.CHEST)
	if body == "plate":
		_plate(g, w, d0)
	if look.get("surcoat", false):
		_surcoat(g, a, w, d0, sides)
	elif body in ["tunic", "padded"] or body == "shirt":
		# A belt with a pouch; the tunic's skirt over the thighs.
		for s: float in [1.0, -1.0]:
			g.loft([Vector3(0.1 * s * 1.05, 0.98, 0.0), Vector3(0.1 * s * 1.18, 0.74, 0.0)],
				[Vector2(0.1, 0.118) * w, Vector2(0.104, 0.122) * w], X, sides, 0.0, top, B.bone_side(s, B.THIGH_R, B.THIGH_L), null, 2)
	g.box(Vector3(-0.16 * w, 0.92, -0.06), Vector3(0.03, 0.05, 0.04), LEATHER, B.HIPS)
	_helm(g, look, d0, sides)
	if look.get("pavise", false):
		var bas := Basis(Vector3.RIGHT, 0.12)
		var c := Vector3(0, 1.08, 0.2 * w)
		g.box(c, Vector3(0.26, 0.42, 0.02), WOOD_DARK, B.CHEST, bas)
		paint(g, a, RECT, c + bas * Vector3(0, 0, 0.022), X, bas * Vector3.UP, 0.24, 0.4, B.CHEST, false, d0)
	if look.get("quiver", false):
		g.loft([Vector3(0.2 * w, 0.78, 0.08), Vector3(0.22 * w, 1.06, 0.1)], [Vector2(0.05, 0.05), Vector2(0.055, 0.055)], X, 6, 0.0,
			LEATHER, B.HIPS, null, 1)
		if d0:
			for k in 6:
				var o := Vector3(0.2 * w + 0.025 * cos(k * 1.1), 1.07, 0.1 + 0.025 * sin(k * 1.1))
				g.loft([o, o + Vector3(0.0, 0.13, 0.02)], [Vector2(0.006, 0.006), Vector2(0.006, 0.006)], X, 4, 0.0, WOOD, B.HIPS)
				g.box(o + Vector3(0, 0.12, 0.02), Vector3(0.002, 0.03, 0.012), ARGENT, B.HIPS)
	if look.get("sword_hip", false) and look.get("weapon", "") != "sword":
		var sb := Basis(Vector3.RIGHT, 0.35)
		g.loft([Vector3(-0.2 * w, 0.95, -0.02), Vector3(-0.21 * w, 0.95, 0.0) + sb * Vector3(0, -0.72, 0)],
			[Vector2(0.02, 0.035), Vector2(0.018, 0.03)], X, 4, 0.0, LEATHER_DARK, B.HIPS)
		g.box(Vector3(-0.2 * w, 1.0, -0.04), Vector3(0.06, 0.01, 0.012), IRON, B.HIPS)
		g.loft([Vector3(-0.2 * w, 1.0, -0.04), Vector3(-0.2 * w, 1.1, -0.07)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)], X, 4, 0.0,
			LEATHER_DARK, B.HIPS)
	return g


static func _surcoat(g: UnitGeo, a: Dictionary, w: float, d0: bool, sides: int) -> void:
	var X := Vector3.RIGHT
	var f: Color = a["field"]
	# The coat over the body (sleeveless), then the skirt split on the thighs (per pale shows on the two legs).
	g.loft([Vector3(0, 0.96, 0.0), Vector3(0, 1.22, -0.004), Vector3(0, 1.42, -0.004), Vector3(0, 1.5, 0.012)],
		[Vector2(0.208, 0.142) * w, Vector2(0.214, 0.146) * w, Vector2(0.22, 0.142) * w, Vector2(0.15, 0.1) * w],
		X, sides, 0.0, f, B.CHEST, null, 0)
	g.loft([Vector3(0, 0.84, 0.0), Vector3(0, 1.0, 0.0)], [Vector2(0.21, 0.142) * w, Vector2(0.21, 0.144) * w], X, sides, 0.0, f, B.HIPS,
		null, 0)
	for s: float in [1.0, -1.0]:
		var col: Color = a["second"] if (a["div"] in ["per_pale", "quarterly"] and s > 0.0) else f
		g.loft([Vector3(0.1 * s * 1.05, 0.9, 0.0), Vector3(0.1 * s * 1.25, 0.6, 0.0)],
			[Vector2(0.108, 0.128) * w, Vector2(0.115, 0.135) * w], X, sides, 0.0, col, B.bone_side(s, B.THIGH_R, B.THIGH_L), null, 2)
	# The arms on the breast and the back.
	for side: float in [-1.0, 1.0]:
		var c := Vector3(0, 1.24, side * 0.147 * w + side * 0.003)
		var right := X if side > 0.0 else -X
		paint(g, a, RECT, c, right, Vector3.UP, 0.15 * w, 0.2, B.CHEST, false, d0)
	g.loft([Vector3(0, 0.96, 0.0), Vector3(0, 1.0, 0.0)], [Vector2(0.215, 0.148) * w, Vector2(0.215, 0.148) * w], X, sides, 0.0,
		LEATHER, B.HIPS, null, 0)


static func _plate(g: UnitGeo, w: float, d0: bool) -> void:
	var X := Vector3.RIGHT
	var n := 6 if d0 else 4
	for s: float in [1.0, -1.0]:
		# Pauldrons, couters, vambraces, gauntlet cuffs; cuisses, poleyns, greaves.
		var ua := B.bone_side(s, B.UARM_R, B.UARM_L)
		var fa := B.bone_side(s, B.FARM_R, B.FARM_L)
		g.loft([Vector3(0.17 * s, 1.52, 0.0), Vector3(0.24 * s, 1.47, 0.0), Vector3(0.25 * s, 1.36, 0.0)],
			[Vector2(0.06, 0.1), Vector2(0.095, 0.11), Vector2(0.09, 0.1)], X, n, 0.0, PLATE, ua)
		g.loft([Vector3(0.215 * s, 1.34, 0.0), Vector3(0.222 * s, 1.17, 0.0)], [Vector2(0.07, 0.074), Vector2(0.065, 0.07)], X, n, 0.0,
			PLATE, ua, null, 0)
		g.box(Vector3(0.226 * s, 1.13, 0.03), Vector3(0.055, 0.05, 0.045), PLATE_DARK, fa)
		g.loft([Vector3(0.228 * s, 1.08, 0.0), Vector3(0.24 * s, 0.9, 0.0)], [Vector2(0.06, 0.064), Vector2(0.055, 0.058)], X, n, 0.0,
			PLATE, fa, null, 0)
		var th := B.bone_side(s, B.THIGH_R, B.THIGH_L)
		var sh := B.bone_side(s, B.SHIN_R, B.SHIN_L)
		g.loft([Vector3(0.1 * s, 0.9, -0.01), Vector3(0.1 * s, 0.56, -0.015)], [Vector2(0.088, 0.09), Vector2(0.07, 0.075)], X, n, 0.0,
			PLATE, th, null, 0)
		g.box(Vector3(0.1 * s, 0.51, -0.06), Vector3(0.05, 0.05, 0.03), PLATE_DARK, sh)
		g.loft([Vector3(0.1 * s, 0.47, 0.0), Vector3(0.1 * s, 0.14, 0.0)], [Vector2(0.066, 0.07), Vector2(0.056, 0.06)], X, n, 0.0,
			PLATE, sh, null, 0)
	# Breastplate with a ridge (under the surcoat when worn; it shows when not).
	g.loft([Vector3(0, 1.0, -0.01), Vector3(0, 1.26, -0.03), Vector3(0, 1.45, -0.012)],
		[Vector2(0.2, 0.13) * w, Vector2(0.21, 0.15) * w, Vector2(0.17, 0.1) * w], X, 8 if d0 else 4, 0.3 if d0 else 0.0, PLATE, B.CHEST, null, 0)
	g.loft([Vector3(0, 0.88, 0.0), Vector3(0, 1.0, 0.0)], [Vector2(0.205, 0.135) * w, Vector2(0.2, 0.13) * w], X, 8 if d0 else 4, 0.0,
		PLATE_DARK, B.HIPS, null, 0)


static func _helm(g: UnitGeo, look: Dictionary, d0: bool, sides: int) -> void:
	var X := Vector3.RIGHT
	var H := B.HEAD
	var hair: Color = look["hair"]
	var body: String = look.get("body", "tunic")
	var helm: String = look.get("helm", "bare")
	# A mail coif under the war helms; hair otherwise.
	if helm in ["nasal", "kettle", "great", "bascinet"] and body in ["mail", "plate"]:
		g.loft([Vector3(0, 1.47, 0.01), Vector3(0, 1.56, 0.015), Vector3(0, 1.7, 0.012), Vector3(0, 1.8, 0.01)],
			[Vector2(0.13, 0.11), Vector2(0.1, 0.11), Vector2(0.104, 0.115), Vector2(0.08, 0.09)], X, sides, 0.0, MAIL, H,
			MAIL_DARK if d0 else null, 0)
		g.box(Vector3(0, 1.66, -0.1), Vector3(0.07, 0.07, 0.02), look["skin"], H)
	elif helm != "hood":
		g.loft([Vector3(0, 1.73, 0.02), Vector3(0, 1.8, 0.012), Vector3(0, 1.84, 0.0)],
			[Vector2(0.1, 0.11), Vector2(0.088, 0.1), Vector2(0.04, 0.05)], X, sides, 0.0, hair, H)
	match helm:
		"nasal":
			g.loft([Vector3(0, 1.74, 0.0), Vector3(0, 1.82, 0.0), Vector3(0, 1.93, 0.01)], [Vector2(0.108, 0.118), Vector2(0.09, 0.1),
				Vector2(0.0, 0.0)], X, sides, 0.0, STEEL, H)
			g.box(Vector3(0, 1.69, -0.118), Vector3(0.012, 0.05, 0.008), STEEL, H)
		"kettle":
			g.loft([Vector3(0, 1.74, 0.0), Vector3(0, 1.84, 0.0), Vector3(0, 1.9, 0.0)], [Vector2(0.106, 0.116), Vector2(0.095, 0.105),
				Vector2(0.04, 0.045)], X, sides, 0.0, STEEL, H)
			g.loft([Vector3(0, 1.74, 0.0), Vector3(0, 1.755, 0.0)], [Vector2(0.18, 0.19), Vector2(0.17, 0.18)], X, sides, 0.0, STEEL, H)
		"great":
			g.loft([Vector3(0, 1.55, 0.0), Vector3(0, 1.7, 0.0), Vector3(0, 1.86, 0.0), Vector3(0, 1.9, 0.0)],
				[Vector2(0.115, 0.125), Vector2(0.12, 0.13), Vector2(0.118, 0.128), Vector2(0.08, 0.09)], X, sides, 0.0, STEEL, H)
			g.box(Vector3(0, 1.74, -0.128), Vector3(0.1, 0.008, 0.006), SABLE, H)
			if d0:
				g.box(Vector3(0, 1.65, -0.126), Vector3(0.008, 0.08, 0.008), PLATE_DARK, H)
				for k in 6:
					g.box(Vector3(0.03 * (k % 3 - 1), 1.6 + 0.03 * (k / 3), -0.127), Vector3(0.006, 0.006, 0.004), SABLE, H)
			if look.get("crest", false):
				# A crest in the arms' colours: a fan or a pair of horns.
				var a: Dictionary = look["arms"]
				if int(look.get("lord", 0)) % 2 == 0:
					g.box(Vector3(0, 2.0, 0.0), Vector3(0.012, 0.1, 0.12), a["field"], H)
					g.box(Vector3(0, 2.04, 0.0), Vector3(0.013, 0.04, 0.09), a["second"], H)
				else:
					for s: float in [1.0, -1.0]:
						g.loft([Vector3(0.06 * s, 1.88, 0.0), Vector3(0.14 * s, 1.98, 0.0), Vector3(0.12 * s, 2.12, -0.02)],
							[Vector2(0.025, 0.025), Vector2(0.018, 0.018), Vector2(0.0, 0.0)], Vector3.BACK, 4, 0.0, a["second"], H)
				g.loft([Vector3(0, 1.88, 0.0), Vector3(0, 1.92, 0.0)], [Vector2(0.09, 0.1), Vector2(0.09, 0.1)], X, sides, 0.0, a["field"], H)
		"bascinet":
			g.loft([Vector3(0, 1.58, 0.02), Vector3(0, 1.74, 0.01), Vector3(0, 1.88, 0.0), Vector3(0, 1.98, 0.03)],
				[Vector2(0.11, 0.12), Vector2(0.112, 0.124), Vector2(0.09, 0.1), Vector2(0.0, 0.0)], X, sides, 0.0, STEEL, H)
			# The pig-snout visor.
			g.loft([Vector3(0, 1.7, -0.08), Vector3(0, 1.66, -0.2)], [Vector2(0.09, 0.1), Vector2(0.025, 0.03)], X, sides, 0.0, PLATE, H)
			g.box(Vector3(0, 1.73, -0.13), Vector3(0.08, 0.006, 0.01), SABLE, H, Basis(Vector3.RIGHT, -0.5))
			g.loft([Vector3(0, 1.46, 0.0), Vector3(0, 1.56, 0.0)], [Vector2(0.15, 0.13), Vector2(0.11, 0.11)], X, sides, 0.0, MAIL, H, null, 0)
		"cap":
			g.loft([Vector3(0, 1.76, 0.01), Vector3(0, 1.85, 0.02), Vector3(0, 1.88, 0.06)], [Vector2(0.105, 0.115), Vector2(0.09, 0.1),
				Vector2(0.03, 0.03)], X, sides, 0.0, look["drab"].darkened(0.2), H)
			if d0:
				g.loft([Vector3(0.06, 1.85, 0.03), Vector3(0.1, 1.95, 0.1)], [Vector2(0.008, 0.002), Vector2(0.004, 0.001)], X, 4, 0.0, ARGENT, H)
		"hood":
			var hc: Color = look["drab"].darkened(0.1)
			g.loft([Vector3(0, 1.44, 0.03), Vector3(0, 1.56, 0.04), Vector3(0, 1.7, 0.03), Vector3(0, 1.82, 0.03), Vector3(0, 1.88, 0.08),
				Vector3(0, 1.84, 0.2)], [Vector2(0.2, 0.15), Vector2(0.12, 0.13), Vector2(0.12, 0.137), Vector2(0.1, 0.115), Vector2(0.05, 0.05),
				Vector2(0.015, 0.015)], X, sides, 0.0, hc, H, null, 2)


static func _far(g: UnitGeo, look: Dictionary) -> void:
	var a: Dictionary = look["arms"]
	if look.get("surcoat", false):
		g.box(Vector3(0, 1.18, 0.0), Vector3(0.21, 0.28, 0.15), a["field"], B.CHEST)
		g.box(Vector3(0, 1.22, -0.152), Vector3(0.1, 0.12, 0.004), a["second"], B.CHEST)
	var helm: String = look.get("helm", "bare")
	if helm in ["great", "bascinet", "kettle", "nasal"]:
		g.box(Vector3(0, 1.79, 0.0), Vector3(0.12, 0.1 if helm != "kettle" else 0.05, 0.13), STEEL, B.HEAD)
	if look.get("pavise", false):
		g.box(Vector3(0, 1.08, 0.2), Vector3(0.25, 0.4, 0.02), a["field"], B.CHEST)


# ---------------------------------------------------------------- shields, banners, pavises (their own frames)

## The heater shield: its frame has the hand grip at the origin, the face toward -Z.
static func shield(a: Dictionary, lod := 0, small := false) -> UnitGeo:
	var g := UnitGeo.new()
	var k := 0.72 if small else 1.0
	var hw := SHIELD_W * k
	var top := SHIELD_TOP * k
	var bot := SHIELD_BOT * k
	var hh := (top - bot) * 0.5
	var cy := (top + bot) * 0.5
	var c := Vector3(0, cy, -0.06)
	# The board (a thin slab in the heater outline), the arms on the face, a rim, the straps behind.
	var pts: Array[Vector3] = []
	for p: Vector2 in HEATER:
		pts.append(c + Vector3(p.x * hw, p.y * hh, 0))
	for e: float in [-0.012, 0.012]:
		for i in range(1, pts.size() - 1):
			_tri2(g, pts[0] + Vector3(0, 0, e), pts[i] + Vector3(0, 0, e), pts[i + 1] + Vector3(0, 0, e), WOOD_DARK, 0, Vector3(0, 0, signf(e)))
	for i in pts.size():
		var p0 := pts[i]
		var p1 := pts[(i + 1) % pts.size()]
		var mid := (p0 + p1) * 0.5
		var out := Vector3(mid.x - c.x, mid.y - c.y, 0).normalized()
		g.emit(p0 + Vector3(0, 0, -0.012), p1 + Vector3(0, 0, -0.012), p1 + Vector3(0, 0, 0.012), WOOD_DARK, 0)
		g.emit(p0 + Vector3(0, 0, -0.012), p1 + Vector3(0, 0, 0.012), p0 + Vector3(0, 0, 0.012), WOOD_DARK, 0)
		if (p1 - p0).cross(Vector3(0, 0, 0.024)).dot(out) < 0.0:
			pass
	paint(g, a, HEATER, c + Vector3(0, 0, -0.013), Vector3.LEFT, Vector3.UP, hw, hh, 0, false, lod == 0)
	if lod == 0:
		g.box(Vector3(0, 0, 0.0), Vector3(0.07, 0.015, 0.02), LEATHER, 0)
		g.box(Vector3(0, 0.18 * k, 0.0), Vector3(0.04, 0.02, 0.02), LEATHER, 0)
	return g


## A lord's banner on its pole (item frame: grip at GRIP_R, the pole along -Z; the cloth hangs from a crossbar at the
## top, toward +Y of the item frame when the pole is upright... built so with the pole upright (dir up, up toward the
## man's back) the cloth hangs down from the bar, face forward).
static func banner_pole(a: Dictionary, lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	var y := -0.015
	g.loft([Vector3(0, y, 0.7), Vector3(0, y, BANNER_TOP.z)], [Vector2(0.02, 0.02), Vector2(0.018, 0.018)], X, 6 if lod == 0 else 4,
		0.0, WOOD, 0)
	g.loft([BANNER_TOP, BANNER_TOP + Vector3(0, 0, -0.18)], [Vector2(0.025, 0.025), Vector2(0.0, 0.0)], X, 4, 0.0, OR, 0)
	var bar := BANNER_TOP + Vector3(0, 0, 0.08)
	g.loft([bar + Vector3(-0.4, 0, 0), bar + Vector3(0.4, 0, 0)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)], Vector3.UP, 4, 0.0, WOOD_DARK, 0)
	# The cloth: from the bar back along the pole (+Z), in a gentle wave across X... it hangs in the item's X-Z plane,
	# face toward -Y? The carry turns the item so that its +Y faces forward, then the cloth (in X-Z) faces forward.
	var hh := 0.55
	var c := bar + Vector3(0, 0, hh)
	paint(g, a, RECT, c, Vector3.RIGHT, Vector3(0, 0, -1), 0.4, hh, 0, true, lod == 0)
	# Tails at the fly.
	if lod == 0:
		for s: float in [1.0, -1.0]:
			var t0 := c + Vector3(0.25 * s, 0, hh)
			paint(g, a, [Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1)], t0 + Vector3(0, 0, 0.1), Vector3.RIGHT, Vector3(0, 0, -1), 0.12, 0.1,
				0, true, false)
	return g


## The pavise standing on its foot (world prop: bottom centre at the origin, face toward -Z, leaning back a little).
static func pavise(a: Dictionary, lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var bas := Basis(Vector3.RIGHT, -0.18)
	var c := bas * Vector3(0, 0.62, 0)
	g.box(c, Vector3(0.3, 0.025, 0.6), WOOD_DARK, 0, bas * Basis(Vector3.RIGHT, PI * 0.5))
	paint(g, a, RECT, c + bas * Vector3(0, 0, -0.027), Vector3.LEFT, bas * Vector3.UP, 0.28, 0.58, 0, false, lod == 0)
	g.box(Vector3(0, 0.3, 0.18), Vector3(0.02, 0.3, 0.02), WOOD, 0, Basis(Vector3.RIGHT, 0.5))  # the prop stick
	return g


## A sharpened archer's stake (world prop: driven in at the origin, leaning toward -Z by its angle).
static func stake(height := 1.2, lean := 0.6) -> UnitGeo:
	var g := UnitGeo.new()
	var d := Vector3(0, cos(lean), -sin(lean))
	g.loft([Vector3.ZERO - d * 0.1, d * (height - 0.18), d * height], [Vector2(0.035, 0.035), Vector2(0.035, 0.035), Vector2(0.0, 0.0)],
		Vector3.RIGHT, 5, 0.0, WOOD, 0)
	return g


## An arrow (its frame: nock at the origin, the head along -Z).
static func arrow(bolt := false) -> UnitGeo:
	var g := UnitGeo.new()
	var L := 0.36 if bolt else 0.78
	g.loft([Vector3.ZERO, Vector3(0, 0, -L)], [Vector2(0.005, 0.005), Vector2(0.005, 0.005)], Vector3.RIGHT, 4, 0.0, WOOD, 0)
	g.loft([Vector3(0, 0, -L), Vector3(0, 0, -L - 0.05)], [Vector2(0.01, 0.004), Vector2(0.0, 0.0)], Vector3.RIGHT, 4, 0.0, IRON, 0)
	g.box(Vector3(0, 0.008, -0.06), Vector3(0.001, 0.008, 0.05), ARGENT if not bolt else LEATHER, 0)
	return g


# ---------------------------------------------------------------- weapons (item frame)

static func weapon(kind: String, lod := 0, a: Dictionary = {}) -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	var y := -0.015
	var n := 6 if lod == 0 else 4
	match kind:
		"sword", "greatsword":
			var big := kind == "greatsword"
			var bl := 1.05 if big else 0.78
			var grip := 0.28 if big else 0.12
			g.loft([Vector3(0, y, 0.06 + grip), Vector3(0, y, -0.03)], [Vector2(0.016, 0.016), Vector2(0.016, 0.016)], X, n, 0.0,
				LEATHER_DARK, 0)
			g.box(Vector3(0, y, 0.08 + grip), Vector3(0.026, 0.026, 0.024), IRON, 0)
			g.box(Vector3(0, y, -0.04), Vector3(0.012, 0.016, 0.12 if not big else 0.16), IRON, 0, Basis(Vector3.UP, PI * 0.5))
			g.loft([Vector3(0, y, -0.05), Vector3(0, y, -0.05 - bl * 0.8), Vector3(0, y, -0.05 - bl)],
				[Vector2(0.026 if big else 0.022, 0.005), Vector2(0.02, 0.004), Vector2(0.0, 0.0)], X, 4, 0.0, STEEL, 0)
		"spear", "javelin":
			var back := 0.7 if kind == "spear" else 0.4
			var fwd := 1.55 if kind == "spear" else 0.9
			g.loft([Vector3(0, y, back), Vector3(0, y, -fwd)], [Vector2(0.016, 0.016), Vector2(0.014, 0.014)], X, n, 0.0, WOOD, 0)
			g.loft([Vector3(0, y, -fwd), Vector3(0, y, -fwd - 0.08), Vector3(0, y, -fwd - 0.26)],
				[Vector2(0.012, 0.012), Vector2(0.03, 0.006), Vector2(0.0, 0.0)], X, 4, 0.0, STEEL, 0)
		"lance":
			g.loft([Vector3(0, y, 0.5), Vector3(0, y, 0.0), Vector3(0, y, -0.4), LANCE_TIP + Vector3(0, 0, 0.2)],
				[Vector2(0.025, 0.025), Vector2(0.022, 0.022), Vector2(0.035, 0.035), Vector2(0.014, 0.014)], X, n, 0.0, a.get("field", WOOD), 0,
				a.get("second", WOOD_DARK) if lod == 0 else null)
			g.loft([LANCE_TIP + Vector3(0, 0, 0.2), LANCE_TIP], [Vector2(0.014, 0.014), Vector2(0.0, 0.0)], X, 4, 0.0, STEEL, 0)
			g.loft([Vector3(0, y, -0.02), Vector3(0, y, -0.2)], [Vector2(0.09, 0.09), Vector2(0.03, 0.03)], X, n, 0.0, STEEL, 0)
		"halberd", "poleaxe", "billhook", "pitchfork":
			var top: float = {"halberd": -1.55, "poleaxe": -1.15, "billhook": -1.4, "pitchfork": -1.15}[kind]
			var butt: float = {"halberd": 0.35, "poleaxe": 0.3, "billhook": 0.3, "pitchfork": 0.45}[kind]
			g.loft([Vector3(0, y, butt), Vector3(0, y, top)], [Vector2(0.018, 0.018), Vector2(0.016, 0.016)], X, n, 0.0,
				WOOD if kind != "pitchfork" else Color(0.6, 0.5, 0.32), 0)
			match kind:
				"halberd":
					g.box(Vector3(0, y + 0.1, top + 0.1), Vector3(0.006, 0.11, 0.12), STEEL, 0)
					g.loft([Vector3(0, y - 0.02, top + 0.1), Vector3(0, y - 0.14, top + 0.05)], [Vector2(0.008, 0.02), Vector2(0.0, 0.0)], X, 4, 0.0, STEEL, 0)
					g.loft([Vector3(0, y, top), Vector3(0, y, top - 0.3)], [Vector2(0.015, 0.012), Vector2(0.0, 0.0)], X, 4, 0.0, STEEL, 0)
				"poleaxe":
					g.box(Vector3(0, y + 0.06, top + 0.05), Vector3(0.006, 0.07, 0.07), STEEL, 0)
					g.box(Vector3(0, y - 0.06, top + 0.05), Vector3(0.03, 0.05, 0.03), IRON, 0)
					g.loft([Vector3(0, y, top), Vector3(0, y, top - 0.22)], [Vector2(0.014, 0.014), Vector2(0.0, 0.0)], X, 4, 0.0, STEEL, 0)
				"billhook":
					g.loft([Vector3(0, y, top + 0.1), Vector3(0, y + 0.02, top - 0.15), Vector3(0, y + 0.1, top - 0.22)],
						[Vector2(0.006, 0.05), Vector2(0.006, 0.04), Vector2(0.004, 0.01)], X, 4, 0.0, IRON, 0)
					g.box(Vector3(0, y - 0.05, top + 0.0), Vector3(0.005, 0.04, 0.012), IRON, 0)
				"pitchfork":
					for k in 3:
						var xo := 0.05 * (k - 1)
						g.loft([Vector3(0, y, top), Vector3(xo, y, top - 0.05), Vector3(xo, y, top - 0.3)],
							[Vector2(0.007, 0.007), Vector2(0.007, 0.007), Vector2(0.0, 0.0)], Vector3.UP, 4, 0.0, IRON, 0)
					g.box(Vector3(0, y, top - 0.04), Vector3(0.06, 0.008, 0.008), IRON, 0)
		"flail":
			g.loft([Vector3(0, y, 0.12), Vector3(0, y, -0.55)], [Vector2(0.018, 0.018), Vector2(0.016, 0.016)], X, n, 0.0, WOOD, 0)
			# The swingle hanging off the end on its leather link, angled back and down.
			var s0 := Vector3(0, y - 0.03, -0.6)
			g.loft([Vector3(0, y, -0.55), s0], [Vector2(0.008, 0.008), Vector2(0.008, 0.008)], X, 4, 0.0, LEATHER, 0)
			g.loft([s0, s0 + Vector3(0, -0.35, 0.15)], [Vector2(0.02, 0.02), Vector2(0.024, 0.024)], X, n, 0.0, WOOD_DARK, 0)
			if lod == 0:
				for k in 3:
					g.box(s0 + Vector3(0, -0.12 - 0.08 * k, 0.05 + 0.035 * k), Vector3(0.028, 0.008, 0.028), IRON, 0)
		"crossbow":
			# The tiller (stock) along the rifle's line, the steel prod across at the front, the stirrup, the string.
			g.loft([Vector3(0, -0.035, 0.33), Vector3(0, -0.01, 0.05), Vector3(0, 0.0, -0.4)],
				[Vector2(0.025, 0.04), Vector2(0.022, 0.03), Vector2(0.024, 0.03)], X, n, 0.0, WOOD, 0)
			var pz := -0.38
			g.loft([Vector3(-0.36, 0.02, pz + 0.1), Vector3(0, 0.02, pz), Vector3(0.36, 0.02, pz + 0.1)],
				[Vector2(0.015, 0.02), Vector2(0.02, 0.025), Vector2(0.015, 0.02)], Vector3.UP, 4, 0.0, IRON, 0)
			g.loft([Vector3(-0.36, 0.02, pz + 0.1), Vector3(0, 0.02, -0.05), Vector3(0.36, 0.02, pz + 0.1)],
				[Vector2(0.003, 0.003), Vector2(0.003, 0.003), Vector2(0.003, 0.003)], Vector3.UP, 4, 0.0, ARGENT, 0)
			g.loft([Vector3(0, 0.0, -0.42), Vector3(0, -0.02, -0.52)], [Vector2(0.05, 0.008), Vector2(0.05, 0.008)], X, 4, 0.0, IRON, 0)
			if lod == 0:
				g.box(Vector3(0, 0.03, -0.12), Vector3(0.004, 0.004, 0.16), WOOD_DARK, 0)  # the bolt in its groove
		"bow":
			# The longbow along +Y through the grip (GRIP_R), the limbs curving back toward +Z.
			var gp := B.GRIP_R
			var pts := [gp + Vector3(0, -BOW_HALF, BOW_DEPTH), gp + Vector3(0, -0.45, 0.04), gp, gp + Vector3(0, 0.45, 0.04),
				gp + Vector3(0, BOW_HALF, BOW_DEPTH)]
			g.loft(pts, [Vector2(0.008, 0.01), Vector2(0.014, 0.018), Vector2(0.02, 0.022), Vector2(0.014, 0.018), Vector2(0.008, 0.01)],
				X, 4, 0.0, Color(0.62, 0.46, 0.24), 0)
			g.loft([gp + Vector3(0, -0.06, 0), gp + Vector3(0, 0.06, 0)], [Vector2(0.024, 0.026), Vector2(0.024, 0.026)], X, 4, 0.0, LEATHER_DARK, 0)
		"banner":
			return banner_pole(a, lod)
	return g


## The bow's two tips (item frame) for the string.
static func bow_tips() -> Array[Vector3]:
	return [B.GRIP_R + Vector3(0, -BOW_HALF, BOW_DEPTH), B.GRIP_R + Vector3(0, BOW_HALF, BOW_DEPTH)]


# ---------------------------------------------------------------- the horse's barding

## A caparison over the horse (on its own skeleton's bones): the skirt round the barrel to the knees, the crinet over
## the neck, the steel chanfron on the face. Quartered in the knight's arms.
static func barding(a: Dictionary, lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var BODY := Horse.BODY
	var NECK := Horse.NECK
	var HEAD := Horse.HEAD
	var X := Vector3.RIGHT
	var f: Color = a["field"]
	var s2: Color = a["second"]
	var segs := 8 if lod == 0 else 4
	# The skirt: one panel down each side and round the chest and rump, split into fore and hind halves in the two
	# tinctures (quarterly read).
	for side: float in [1.0, -1.0]:
		for half in 2:
			var z0 := -0.9 if half == 0 else 0.05
			var z1 := 0.05 if half == 0 else 0.95
			var col := f if (half == 0) == (side > 0.0) else s2
			for k in segs:
				var za := lerpf(z0, z1, float(k) / segs)
				var zb := lerpf(z0, z1, float(k + 1) / segs)
				var wa := 0.36 - 0.12 * pow(absf(za) / 0.95, 3.0)
				var wb := 0.36 - 0.12 * pow(absf(zb) / 0.95, 3.0)
				var ya := 0.8 + 0.04 * sin(za * 9.0)
				var yb := 0.8 + 0.04 * sin(zb * 9.0)
				var t0 := Vector3(0.2 * side, 1.5, za)
				var t1 := Vector3(0.2 * side, 1.5, zb)
				var b0 := Vector3(wa * side, ya, za)
				var b1 := Vector3(wb * side, yb, zb)
				_tri2(g, t0, t1, b1, col, BODY, Vector3(side, 0, 0))
				_tri2(g, t0, b1, b0, col, BODY, Vector3(side, 0, 0))
				_tri2(g, t0, b1, t1, col.darkened(0.3), BODY, Vector3(-side, 0, 0))
				_tri2(g, t0, b0, b1, col.darkened(0.3), BODY, Vector3(-side, 0, 0))
	# Front and back drapes across the chest and the rump.
	for e: float in [-1.0, 1.0]:
		var z := 0.95 * e
		var col := f if e < 0.0 else s2
		var pts := [Vector3(-0.2, 1.45, z), Vector3(0.2, 1.45, z), Vector3(0.3, 0.82, z), Vector3(-0.3, 0.82, z)]
		_tri2(g, pts[0], pts[1], pts[2], col, BODY, Vector3(0, 0, e))
		_tri2(g, pts[0], pts[2], pts[3], col, BODY, Vector3(0, 0, e))
	# The arms painted large on both flanks.
	for side: float in [1.0, -1.0]:
		# On the skirt's slope (top x 0.2 at y 1.5, bottom x 0.36 at y 0.8), just proud of it.
		var up := Vector3(-0.16 * side, 0.7, 0).normalized()
		var right := Vector3(0, 0, -side)
		var c := Vector3(lerpf(0.2, 0.36, (1.5 - 1.12) / 0.7) * side, 1.12, -0.42) + right.cross(up) * 0.006
		paint(g, a, HEATER, c, right, up, 0.17, 0.22, BODY, false, lod == 0)
		paint(g, a, HEATER, c + Vector3(0, 0, 0.84), right, up, 0.17, 0.22, BODY, false, lod == 0)
	# The crinet over the neck in the field colour, the chanfron, a plume.
	g.loft([Vector3(0, 1.42, -0.6), Vector3(0, 1.66, -0.84), Vector3(0, 1.93, -1.0)],
		[Vector2(0.165, 0.3), Vector2(0.135, 0.23), Vector2(0.1, 0.14)], X, 8, 0.3 if lod == 0 else 0.0, f, NECK, s2 if lod == 0 else null, 0)
	g.loft([Vector3(0, 1.99, -1.0), Vector3(0, 1.9, -1.1), Vector3(0, 1.72, -1.3), Vector3(0, 1.62, -1.4)],
		[Vector2(0.08, 0.085), Vector2(0.105, 0.128), Vector2(0.08, 0.1), Vector2(0.07, 0.08)], X, 8, 0.3 if lod == 0 else 0.0, PLATE, HEAD,
		null, 0)
	if lod == 0:
		g.loft([Vector3(0, 1.98, -1.04), Vector3(0, 2.15, -0.98), Vector3(0.0, 2.2, -0.86)], [Vector2(0.03, 0.03), Vector2(0.04, 0.04),
			Vector2(0.01, 0.01)], X, 4, 0.0, s2, HEAD)
	return g
