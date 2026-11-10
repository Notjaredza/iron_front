class_name GeneralKit
extends RefCounted
## Iron Front: the General and his bodyguards (Asset Builder Chat, 2026-11-10).
## The General is an original, made-up strongman, not anyone real. He is built on the approved
## officer (SoldierBuilder role "officer", read only). His tunic is recoloured to a dressed-up
## olive, and his own kit goes on top:
##   - a tall peaked cap with a red band, a gold visor braid, a chin cord and a big star badge;
##   - gold-fringed epaulettes, red collar tabs, a gold aiguillette, a red sash, rows of ribbons and medals;
##   - a dark greatcoat worn over the shoulders;
##   - a heavy moustache and hard brows;
##   - polished black boots and breeches with a red stripe;
##   - a swagger stick in the left hand.
## The guards are approved riflemen, smartened up: white belts and a cross strap, a red armband,
## a fixed bayonet, and no pack.
## Both are plain Soldier nodes (same skeleton, poses and clips), only the mesh differs.

const B := preload("res://scripts/units/soldier_builder.gd")

const TUNIC := Color(0.35, 0.40, 0.22)       # the dressed-up olive
const TUNIC_DARK := Color(0.27, 0.31, 0.17)
const GREATCOAT := Color(0.22, 0.25, 0.15)
const GREATCOAT_DARK := Color(0.16, 0.18, 0.11)
const BREECHES := Color(0.30, 0.34, 0.19)
const CAP := Color(0.33, 0.37, 0.21)
const RED := Color(0.64, 0.12, 0.10)
const RED_DARK := Color(0.45, 0.08, 0.07)
const GOLD := Color(0.86, 0.68, 0.26)
const GOLD_DARK := Color(0.62, 0.46, 0.16)
const BOOT_BLACK := Color(0.11, 0.10, 0.10)
const HAIR := Color(0.16, 0.12, 0.10)
const WHITE := Color(0.93, 0.92, 0.88)
const STEEL := Color(0.62, 0.63, 0.64)
const RIBBONS: Array[Color] = [Color(0.64, 0.12, 0.10), Color(0.15, 0.28, 0.55), Color(0.86, 0.68, 0.26),
	Color(0.20, 0.42, 0.22), Color(0.93, 0.92, 0.88), Color(0.45, 0.15, 0.42)]

const STICK_TIP := Vector3(-0.24, 0.84, -0.56)   # rest model space, the stick's far end (left hand bone)


## The General as a Soldier node. lod 0 close, 1 mid, 2 far.
static func general(lod := 0) -> Soldier:
	var s := Soldier.new().setup(61, lod, "officer")
	var look := s.look.duplicate()
	look["skin"] = B.SKINS[1]
	look["build"] = 1.1
	look["whistle"] = false
	look["map_case"] = false
	var g := B.build(look, lod)
	_recolour(g, {B.COAT: TUNIC, B.COAT_DARK: TUNIC_DARK, B.BREECHES: BREECHES, B.CAP: CAP, B.CAP_BAND: RED,
		B.BOOT: BOOT_BLACK, B.BOOT_DARK: BOOT_BLACK})
	if lod < 2:
		_general_kit(g, lod == 0, 1.1)
	else:
		_general_far(g)
	_swap_mesh(s, look, g)
	s.name = "General"
	return s


## A bodyguard: an approved rifleman, smartened up.
static func guard(seed_value: int, lod := 0) -> Soldier:
	var s := Soldier.new().setup(seed_value, lod)
	var look := s.look.duplicate()
	look.merge({"pack": false, "roll": 0, "shovel": false, "net": false, "canteen": 0, "webbing": false, "build": 1.04}, true)
	var g := B.build(look, lod)
	if lod < 2:
		_guard_kit(g, lod == 0, 1.04)
	_swap_mesh(s, look, g)
	s.name = "Guard"
	return s


static func _swap_mesh(s: Soldier, look: Dictionary, g: UnitGeo) -> void:
	s.look = look
	s.geo = g
	s.mesh_inst.mesh = g.to_mesh(Soldier.material())


static func _recolour(g: UnitGeo, map: Dictionary) -> void:
	for i in g.col.size():
		var c: Color = g.col[i]
		for k: Color in map:
			if c.is_equal_approx(k):
				g.col[i] = map[k]
				break


# ---------------------------------------------------------------- the General's kit

static func _general_kit(g: UnitGeo, d0: bool, w: float) -> void:
	var X := Vector3.RIGHT
	var hs := 12 if d0 else 6
	# The cap: a tall saddle crown over the officer's cap, raised at the front, with a gold braid on the visor,
	# a chin cord and a big badge (a star in a wreath).
	g.loft([Vector3(0, 1.80, 0.004), Vector3(0, 1.845, -0.004), Vector3(0, 1.885, -0.018), Vector3(0, 1.9, -0.02)],
		[Vector2(0.118, 0.13), Vector2(0.15, 0.162), Vector2(0.158, 0.17), Vector2(0.14, 0.15)], X, hs, 0.0, CAP, B.HEAD)
	g.box(Vector3(0, 1.744, -0.153), Vector3(0.082, 0.007, 0.012), GOLD, B.HEAD, Basis(Vector3.RIGHT, -0.22))
	g.box(Vector3(0, 1.758, -0.121), Vector3(0.096, 0.006, 0.006), GOLD, B.HEAD)
	g.box(Vector3(0, 1.80, -0.13), Vector3(0.028, 0.028, 0.008), GOLD, B.HEAD)
	if d0:
		g.box(Vector3(0, 1.80, -0.136), Vector3(0.028, 0.028, 0.006), GOLD, B.HEAD, Basis(Vector3.BACK, PI / 4))
		for s: float in [1.0, -1.0]:
			g.box(Vector3(0.045 * s, 1.79, -0.128), Vector3(0.018, 0.008, 0.006), GOLD_DARK, B.HEAD, Basis(Vector3.BACK, 0.5 * s))
			g.box(Vector3(0.1 * s, 1.756, -0.075), Vector3(0.012, 0.012, 0.012), GOLD, B.HEAD)  # cord buttons
	# The face: a heavy moustache with drooping ends, hard brows pulled down at the middle.
	var hair := HAIR
	g.box(Vector3(0, 1.652, -0.142), Vector3(0.052, 0.013, 0.012), hair, B.HEAD)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.055 * s, 1.638, -0.136), Vector3(0.016, 0.018, 0.01), hair, B.HEAD, Basis(Vector3.BACK, 0.5 * s))
		g.box(Vector3(0.04 * s, 1.724, -0.114), Vector3(0.036, 0.009, 0.01), hair, B.HEAD, Basis(Vector3.BACK, -0.2 * s))
	# Collar tabs and the gold edge of the collar.
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.045 * s, 1.475, -0.078 * w), Vector3(0.028, 0.02, 0.006), RED, B.CHEST)
		if d0:
			g.box(Vector3(0.045 * s, 1.475, -0.081 * w), Vector3(0.01, 0.008, 0.004), GOLD, B.CHEST)
	# Epaulettes with a gold fringe, on the upper arms.
	for s: float in [1.0, -1.0]:
		var ua := B.UARM_R if s > 0.0 else B.UARM_L
		g.box(Vector3(0.205 * s, 1.545, 0.0), Vector3(0.075, 0.016, 0.06), GOLD, ua)
		g.box(Vector3(0.215 * s, 1.554, 0.0), Vector3(0.05, 0.008, 0.042), RED, ua)
		if d0:
			for k in 7:
				var a := lerpf(-1.2, 1.2, float(k) / 6.0)
				var p := Vector3(0.205 * s + 0.07 * s * cos(a), 1.52, 0.06 * sin(a))
				g.box(p, Vector3(0.006, 0.03, 0.006), GOLD_DARK, ua)
	# A red sash from the right shoulder to the left hip.
	g.loft([Vector3(0.15, 1.49, -0.03), Vector3(0.06, 1.33, -0.152 * w), Vector3(-0.08, 1.16, -0.15 * w),
			Vector3(-0.17, 1.03, -0.1 * w)],
		[Vector2(0.006, 0.035), Vector2(0.006, 0.04), Vector2(0.006, 0.04), Vector2(0.006, 0.035)], X, 4, 0.0, RED, B.CHEST, null, 0)
	# Gold aiguillette loops from the right shoulder to a chest button.
	if d0:
		for k in 2:
			g.loft([Vector3(0.19, 1.47, -0.04), Vector3(0.16, 1.37 - 0.03 * k, -0.15 * w), Vector3(0.09, 1.40, -0.155 * w)],
				[Vector2(0.004, 0.004), Vector2(0.004, 0.004), Vector2(0.004, 0.004)], X, 4, 0.0, GOLD, B.CHEST, null, 0)
	# Ribbons and medals on the left breast: three rows of ribbons, four medals hanging below.
	for r in 3:
		for k in 4:
			var c := Vector3(-0.045 - 0.026 * float(k) + 0.013 * float(r % 2), 1.40 - 0.02 * float(r), -0.153 * w)
			g.box(c, Vector3(0.012, 0.008, 0.004), RIBBONS[(r * 4 + k) % RIBBONS.size()], B.CHEST)
	for k in 4:
		var c := Vector3(-0.05 - 0.028 * float(k), 1.31, -0.155 * w)
		g.box(c + Vector3(0, 0.022, 0), Vector3(0.01, 0.014, 0.003), RIBBONS[k + 1], B.CHEST)
		if d0:
			g.loft([c + Vector3(0, 0, 0.001), c + Vector3(0, 0, -0.005)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)],
				Vector3.UP, 8, 0.0, GOLD if k != 2 else STEEL, B.CHEST, null, 3)
		else:
			g.box(c, Vector3(0.011, 0.011, 0.003), GOLD, B.CHEST)
	# A great star on the right breast.
	g.box(Vector3(0.08, 1.33, -0.154 * w), Vector3(0.022, 0.022, 0.004), GOLD, B.CHEST, Basis(Vector3.BACK, PI / 4))
	g.box(Vector3(0.08, 1.33, -0.156 * w), Vector3(0.022, 0.022, 0.004), GOLD_DARK, B.CHEST)
	# Breeches stripe.
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(0.10 * s + 0.083 * s, 0.97, 0.0), Vector3(0.10 * s + 0.077 * s, 0.56, 0.0)],
			[Vector2(0.006, 0.012), Vector2(0.006, 0.012)], Vector3.BACK, 4, 0.0, RED, B.THIGH_R if s > 0.0 else B.THIGH_L, null, 0)
	# The greatcoat worn over the shoulders (a cape-like shell, open at the front, red lined), and a turned-up collar.
	_cape(g, w, d0)
	# The swagger stick in the left hand: dark cane with a gold cap at each end.
	var h: Vector3 = B.REST[B.HAND_L] + Vector3(0.0, -0.02, 0.0)
	g.loft([h + Vector3(0, 0, 0.14), STICK_TIP], [Vector2(0.009, 0.009), Vector2(0.008, 0.008)], X, 4, 0.0,
		Color(0.26, 0.15, 0.09), B.HAND_L)
	g.box(STICK_TIP, Vector3(0.012, 0.012, 0.016), GOLD, B.HAND_L)
	g.box(h + Vector3(0, 0, 0.145), Vector3(0.012, 0.012, 0.014), GOLD, B.HAND_L)


static func _general_far(g: UnitGeo) -> void:
	# Far: the cap crown, the coat over the shoulders and a gold flash on each shoulder.
	g.box(Vector3(0, 1.85, -0.01), Vector3(0.14, 0.04, 0.15), CAP, B.HEAD)
	g.box(Vector3(0, 1.48, 0.02), Vector3(0.31, 0.06, 0.18), GREATCOAT, B.CHEST)
	g.box(Vector3(0, 1.08, 0.2), Vector3(0.29, 0.37, 0.02), GREATCOAT, B.CHEST)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.21 * s, 1.52, 0.0), Vector3(0.07, 0.02, 0.06), GOLD, B.UARM_R if s > 0.0 else B.UARM_L)


# ---------------------------------------------------------------- the guards' kit

static func _guard_kit(g: UnitGeo, d0: bool, w: float) -> void:
	var X := Vector3.RIGHT
	# White waist belt over the webbing, a white cross strap from the left shoulder to the right hip.
	g.loft([Vector3(0, 0.985, 0.0), Vector3(0, 1.035, 0.0)], [Vector2(0.178, 0.148) * w, Vector2(0.176, 0.146) * w],
		X, 8 if d0 else 4, 0.0, WHITE, B.HIPS, null, 0)
	if d0:
		g.box(Vector3(0, 1.01, -0.146 * w), Vector3(0.028, 0.022, 0.006), STEEL, B.HIPS)
	g.loft([Vector3(-0.13, 1.5, -0.02), Vector3(-0.06, 1.38, -0.15 * w), Vector3(0.1, 1.15, -0.15 * w), Vector3(0.16, 1.04, -0.11 * w)],
		[Vector2(0.005, 0.03), Vector2(0.005, 0.032), Vector2(0.005, 0.032), Vector2(0.005, 0.03)], X, 4, 0.0, WHITE, B.CHEST, null, 0)
	g.loft([Vector3(-0.13, 1.5, -0.02), Vector3(-0.08, 1.4, 0.15 * w), Vector3(0.1, 1.15, 0.15 * w), Vector3(0.16, 1.04, 0.11 * w)],
		[Vector2(0.005, 0.03), Vector2(0.005, 0.032), Vector2(0.005, 0.032), Vector2(0.005, 0.03)], X, 4, 0.0, WHITE, B.CHEST, null, 0)
	# The red armband with a white stripe on the left upper arm.
	for k in 3:
		var y := 1.345 - 0.025 * float(k)
		g.loft([Vector3(-0.212, y + 0.0125, 0.0), Vector3(-0.213, y - 0.0125, 0.0)],
			[Vector2(0.071, 0.077) * w, Vector2(0.07, 0.076) * w], X, 6 if d0 else 4, 0.0, [RED, WHITE, RED][k], B.UARM_L, null, 0)
	# A fixed bayonet on the rifle (rifle frame: barrel along -Z, muzzle at -0.82).
	var o: Vector3 = B.REST[B.RIFLE]
	g.box(o + Vector3(0, 0.012, -0.84), Vector3(0.014, 0.02, 0.025), STEEL.darkened(0.3), B.RIFLE)
	g.loft([o + Vector3(0, 0.012, -0.86), o + Vector3(0, 0.012, -1.2)], [Vector2(0.004, 0.016), Vector2(0.002, 0.004)],
		X, 4, 0.0, STEEL, B.RIFLE)


# ---------------------------------------------------------------- props

## The flare pistol (prop): a wide brass-and-steel barrel. Frame: grip at the origin, barrel along -Z.
static func flare_pistol() -> UnitGeo:
	var g := UnitGeo.new()
	g.box(Vector3(0, -0.04, 0.02), Vector3(0.016, 0.055, 0.024), Color(0.35, 0.22, 0.12), 0, Basis(Vector3.RIGHT, -0.25))
	g.loft([Vector3(0, 0.035, 0.05), Vector3(0, 0.035, -0.17)], [Vector2(0.024, 0.024), Vector2(0.026, 0.026)],
		Vector3.RIGHT, 8, 0.0, Color(0.55, 0.45, 0.25), 0)
	g.box(Vector3(0, 0.035, 0.07), Vector3(0.02, 0.02, 0.02), Color(0.17, 0.17, 0.18), 0)
	return g


## A speaking podium with two banners on poles behind. Frame: the podium's front faces -Z, the speaker
## stands at the origin; the podium top is at y 1.12 just in front of him.
static func podium() -> TrainGeo:
	var t := TrainGeo.new()
	var wood := Color(0.36, 0.22, 0.13)
	# The platform he stands on and its steps.
	t.box(Vector3(0, 0.25, 0.4), Vector3(1.6, 0.25, 1.4), Color(0.5, 0.48, 0.44), Basis(), 0.0)
	for k in 2:
		t.box(Vector3(0, 0.08 + 0.085 * float(k), 2.0 + 0.3 * float(1 - k)), Vector3(0.7, 0.085 + 0.085 * float(k), 0.15), Color(0.46, 0.44, 0.4))
	# The lectern, draped in red with a gold fringe and a gold star.
	t.box(Vector3(0, 1.05, -0.42), Vector3(0.38, 0.55, 0.2), wood)
	t.box(Vector3(0, 1.62, -0.45), Vector3(0.42, 0.025, 0.25), wood.darkened(0.2), Basis(Vector3.RIGHT, -0.12))
	t.box(Vector3(0, 1.17, -0.63), Vector3(0.33, 0.4, 0.01), RED)
	t.box(Vector3(0, 0.78, -0.635), Vector3(0.33, 0.02, 0.01), GOLD)
	t.box(Vector3(0, 1.3, -0.642), Vector3(0.08, 0.08, 0.008), GOLD, Basis(Vector3.BACK, PI / 4))
	t.box(Vector3(0, 1.3, -0.644), Vector3(0.08, 0.08, 0.008), GOLD)
	# Two tall banners behind: red with a gold border and a gold star in a wreath.
	for s: float in [1.0, -1.0]:
		var x := 1.3 * s
		t.cyl(Vector3(x, 0.5, 1.4), Vector3(x, 4.6, 1.4), 0.04, 6, Color(0.2, 0.2, 0.2))
		t.lump(Vector3(x, 4.65, 1.4), 0.07, GOLD)
		t.box(Vector3(x, 4.42, 1.4), Vector3(0.5, 0.02, 0.02), Color(0.2, 0.2, 0.2))
		t.box(Vector3(x, 3.2, 1.38), Vector3(0.46, 1.2, 0.01), RED)
		t.box(Vector3(x, 3.2, 1.372), Vector3(0.48, 1.22, 0.004), GOLD)
		t.box(Vector3(x, 3.2, 1.368), Vector3(0.42, 1.16, 0.004), RED)
		t.box(Vector3(x, 3.5, 1.364), Vector3(0.15, 0.15, 0.004), GOLD, Basis(Vector3.BACK, PI / 4))
		t.box(Vector3(x, 3.5, 1.362), Vector3(0.15, 0.15, 0.004), GOLD)
		for k in 8:
			var a := TAU * float(k) / 8.0
			t.box(Vector3(x + cos(a) * 0.28, 3.5 + sin(a) * 0.28, 1.364), Vector3(0.05, 0.02, 0.004), GOLD_DARK,
				Basis(Vector3.BACK, a + PI / 2))
		for k in 10:
			t.box(Vector3(x - 0.45 + float(k) * 0.1, 1.94, 1.38), Vector3(0.012, 0.05, 0.006), GOLD)
	return t


## The General's car: the HQ staff car with the hood down, two pennants on the wings and a grab rail
## behind the front seat so he can stand in the back. He stands at STAND_AT (car frame, front -Z).
const CAR_STAND_AT := Vector3(0, 0.62, 0.75)


static func car() -> TrainGeo:
	var t := BldParts.staff_car()
	t.cyl(Vector3(-0.7, 1.4, 0.3), Vector3(0.7, 1.4, 0.3), 0.025, 6, GOLD)
	for s: float in [1.0, -1.0]:
		t.cyl(Vector3(0.7 * s, 1.0, 0.3), Vector3(0.7 * s, 1.4, 0.3), 0.025, 6, GOLD)
		t.cyl(Vector3(0.72 * s, 0.98, -2.0), Vector3(0.72 * s, 1.45, -2.0), 0.012, 4, Color(0.7, 0.7, 0.7))
		t.box(Vector3(0.72 * s + 0.0, 1.36, -1.86), Vector3(0.006, 0.08, 0.13), RED)
		t.box(Vector3(0.72 * s, 1.36, -1.86), Vector3(0.008, 0.03, 0.05), GOLD)
	# The folded hood at the back.
	t.box(Vector3(0, 1.12, 1.62), Vector3(0.72, 0.1, 0.18), Color(0.18, 0.18, 0.16), Basis(), 0.04)
	return t


## The greatcoat over the shoulders: a shell in rows (shoulders to hem) and columns (round the back from
## the left front edge to the right), outer face greatcoat, inner face red lining; and a stand-up collar.
static func _cape(g: UnitGeo, w: float, d0: bool) -> void:
	var ys := [1.535, 1.47, 1.3, 1.02, 0.74]
	var rx := [0.17, 0.31, 0.335, 0.355, 0.385]
	var rz := [0.12, 0.165, 0.18, 0.21, 0.25]
	var cz := [0.0, 0.005, 0.015, 0.03, 0.05]
	var n := 12 if d0 else 6
	var pts: Array = []
	for r in ys.size():
		var row: Array = []
		for k in n + 1:
			var a := deg_to_rad(lerpf(-148.0, 148.0, float(k) / float(n)))
			row.append(Vector3(sin(a) * float(rx[r]) * w, float(ys[r]), float(cz[r]) + cos(a) * float(rz[r]) * w))
		pts.append(row)
	for r in ys.size() - 1:
		var mid := Vector3(0, (float(ys[r]) + float(ys[r + 1])) * 0.5, float(cz[r]))
		for k in n:
			var a: Vector3 = pts[r][k]
			var b: Vector3 = pts[r][k + 1]
			var c: Vector3 = pts[r + 1][k + 1]
			var d: Vector3 = pts[r + 1][k]
			var col := GREATCOAT if r > 0 or k % 2 == 0 else GREATCOAT
			g.tri_out(a, b, c, col, B.CHEST, mid)
			g.tri_out(a, c, d, col, B.CHEST, mid)
			# The lining, a little inside, facing in.
			var ia := a.lerp(mid, 0.04)
			var ib := b.lerp(mid, 0.04)
			var ic := c.lerp(mid, 0.04)
			var id := d.lerp(mid, 0.04)
			var out := (a + c) * 0.5 + ((a + c) * 0.5 - mid) * 4.0
			g.tri_out(ia, ib, ic, RED_DARK, B.CHEST, out)
			g.tri_out(ia, ic, id, RED_DARK, B.CHEST, out)
	# A dark hem and dark front edges.
	for k in n:
		var a: Vector3 = pts[ys.size() - 1][k]
		var b: Vector3 = pts[ys.size() - 1][k + 1]
		g.tri_out(a, b, b + Vector3(0, 0.03, 0), GREATCOAT_DARK, B.CHEST, Vector3(0, 0.75, 0.05))
		g.tri_out(a, b + Vector3(0, 0.03, 0), a + Vector3(0, 0.03, 0), GREATCOAT_DARK, B.CHEST, Vector3(0, 0.75, 0.05))
	# The collar: a short stand-up band round the back of the neck, open at the throat.
	var m := 8 if d0 else 4
	for k in m:
		var a0 := deg_to_rad(lerpf(-120.0, 120.0, float(k) / float(m)))
		var a1 := deg_to_rad(lerpf(-120.0, 120.0, float(k + 1) / float(m)))
		var p0 := Vector3(sin(a0) * 0.15 * w, 1.52, 0.01 + cos(a0) * 0.12 * w)
		var p1 := Vector3(sin(a1) * 0.15 * w, 1.52, 0.01 + cos(a1) * 0.12 * w)
		var q0 := Vector3(sin(a0) * 0.135 * w, 1.62, 0.03 + cos(a0) * 0.11 * w)
		var q1 := Vector3(sin(a1) * 0.135 * w, 1.62, 0.03 + cos(a1) * 0.11 * w)
		var cen := Vector3(0, 1.57, 0.02)
		g.tri_out(p0, p1, q1, GREATCOAT_DARK, B.CHEST, cen)
		g.tri_out(p0, q1, q0, GREATCOAT_DARK, B.CHEST, cen)
		g.tri_out(p0, p1, q1, RED_DARK, B.CHEST, cen + (p0 - cen) * 3.0)
		g.tri_out(p0, q1, q0, RED_DARK, B.CHEST, cen + (p0 - cen) * 3.0)
	# Two gold buttons and a gold chain across the open front.
	if d0:
		var l: Vector3 = pts[1][0]
		var rr: Vector3 = pts[1][n]
		g.loft([l + Vector3(0, -0.03, -0.01), Vector3(0, 1.38, -0.17 * w), rr + Vector3(0, -0.03, -0.01)],
			[Vector2(0.004, 0.004), Vector2(0.004, 0.004), Vector2(0.004, 0.004)], Vector3.UP, 4, 0.0, GOLD, B.CHEST, null, 0)
		for p: Vector3 in [l, rr]:
			g.box(p + Vector3(0, -0.03, -0.012), Vector3(0.014, 0.014, 0.008), GOLD, B.CHEST)
