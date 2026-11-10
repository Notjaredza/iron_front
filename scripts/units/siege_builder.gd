extends RefCounted
## The medieval host's siege engines (Building Chat 1, 2026-11-10): the geometry of every part. Each engine is built as
## parts, each in its own frame with its pivot at the origin; SiegeEngine hangs them on nodes and moves them.
## Every engine faces -Z (it throws, shoots or rolls toward -Z). lod 0 close, 1 mid, 2 far.
##   trebuchet  frame, arm (on the axle), cw (the counterweight box, hung from the short end), winch, pouch, stone
##   mangonel   frame, arm (rooted in the twisted skein; the cup at the tip), winch, stone
##   ballista   frame (the wheeled trestle), mount (turns), cradle (tilts: the stock, the torsion frame), arm_l, arm_r,
##              slider (with its claw), bolt, winch (the crank)
##   tower      body (frame, hides, wheels, push bars, banner), bridge (hinged at its foot)
##   ram        body (the roofed penthouse on wheels), ram (the log with its iron head, hung on ropes)
##   ladder, mantlet, fascine: one part, body

const MB := preload("res://scripts/units/medieval_builder.gd")

const TIMBER := Color(0.50, 0.36, 0.21)
const TIMBER_DARK := Color(0.36, 0.25, 0.14)
const TIMBER_PALE := Color(0.62, 0.48, 0.31)
const IRON := Color(0.26, 0.26, 0.27)
const ROPE := Color(0.72, 0.62, 0.43)
const LEATHER := Color(0.36, 0.22, 0.12)
const STONE := Color(0.63, 0.61, 0.56)
const STRAW := Color(0.78, 0.68, 0.38)
const BRUSH := Color(0.38, 0.35, 0.20)
const BRUSH_DARK := Color(0.27, 0.25, 0.14)
const WITHY := Color(0.52, 0.42, 0.24)
const SLIT := Color(0.06, 0.05, 0.04)
const HIDES: Array[Color] = [Color(0.52, 0.38, 0.25), Color(0.44, 0.31, 0.20), Color(0.60, 0.47, 0.32), Color(0.38, 0.27, 0.18),
	Color(0.56, 0.43, 0.33), Color(0.47, 0.36, 0.27)]

## Trebuchet: the axle, the arm, the windlass, the sling.
const T_AXLE := Vector3(0, 5.0, 0)
const T_SHORT := 2.0          # axle to the counterweight pin
const T_LONG := 7.2           # axle to the tip
const T_WINCH := Vector3(0, 0.95, 6.2)
const T_SPOKE_X := 1.2
const T_SPOKE_R := 0.9
const T_SLING := 3.3
## Mangonel.
const M_SKEIN := Vector3(0, 0.6, -0.9)
const M_ARM := 2.85           # skein to the cup
const M_WINCH := Vector3(0, 0.75, 2.0)
const M_SPOKE_X := 0.92
const M_SPOKE_R := 0.5
## Ballista.
const BA_MOUNT := Vector3(0, 1.0, 0)
const BA_CRADLE := Vector3(0, 0.22, 0)   # in the mount
const BA_SKEIN_X := 0.32
const BA_SKEIN_Z := -0.82
const BA_ARM := 0.72
const BA_WINCH := Vector3(0, -0.02, 1.2) # in the cradle
const BA_CRANK := 0.22
## Tower.
const TW_HALF := Vector3(1.6, 0, 1.7)
const TW_FLOORS: Array[float] = [0.6, 2.7, 4.8, 6.9]
const TW_BRIDGE := 2.9
## Ram.
const R_PIVOT_Y := 2.53
const R_HANG := 1.35
const R_PIVOT_Z: Array[float] = [-1.5, 1.5]
const R_HEAD_Z := -4.45      # the iron head's face, in the ram's frame
const R_HANDLES: Array[float] = [-0.9, 0.3, 1.2]
## Ladder.
const L_LEN := 5.0
const L_HALF := 0.24
const L_RUNG := 0.33


static func sides(lod: int) -> int:
	return [12, 8, 6][mini(lod, 2)]


## A squared beam from a to b (half widths w, h).
static func beam(g: UnitGeo, a: Vector3, b: Vector3, w: float, col: Color, h := -1.0) -> void:
	var ax := (b - a).normalized()
	var hint := Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT
	g.loft([a, b], [Vector2(w, w if h < 0.0 else h), Vector2(w, w if h < 0.0 else h)], hint, 4, 0.0, col, 0)


## A round rod or drum from a to b.
static func rod(g: UnitGeo, a: Vector3, b: Vector3, r: float, col: Color, n := 8) -> void:
	var ax := (b - a).normalized()
	var hint := Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT
	g.loft([a, b], [Vector2(r, r), Vector2(r, r)], hint, n, 0.0, col, 0)


## A solid plank wheel on an axis, with an iron tyre and a hub (close: cross battens on the faces).
static func wheel(g: UnitGeo, c: Vector3, axis: Vector3, r: float, hw: float, lod: int) -> void:
	var n := sides(lod)
	rod(g, c - axis * hw, c + axis * hw, r, TIMBER_DARK, n)
	if lod == 0:
		rod(g, c - axis * hw * 0.7, c + axis * hw * 0.7, r + 0.025, IRON, n)
		var up := Vector3.UP
		var fw := axis.cross(up).normalized()
		for s: float in [-1.0, 1.0]:
			var f := c + axis * (hw + 0.012) * s
			for k in 2:
				var d := (up if k == 0 else fw) * r * 0.85
				beam(g, f - d, f + d, 0.04, TIMBER, 0.012)
	rod(g, c - axis * (hw + 0.07), c + axis * (hw + 0.07), r * 0.22, IRON, maxi(6, n - 4))


## A rough ball (a stone shot).
static func ball(g: UnitGeo, c: Vector3, r: float, col: Color, lod := 0) -> void:
	var cs: Array = []
	var sz: Array = []
	var ys: Array = [-0.96, -0.6, 0.0, 0.6, 0.96] if lod == 0 else [-0.9, 0.0, 0.9]
	for y: float in ys:
		cs.append(c + Vector3(0, y * r, 0))
		var w := sqrt(maxf(1.0 - y * y, 0.04)) * r
		sz.append(Vector2(w, w * 0.96))
	g.loft(cs, sz, Vector3.RIGHT, 8 if lod == 0 else 6, 0.0, col, 0)


static func stone(lod := 0, r := 0.24) -> UnitGeo:
	var g := UnitGeo.new()
	ball(g, Vector3.ZERO, r, STONE, lod)
	return g


## A run of hide panels over a face: the face spans c +- right * hw and c +- up * hh, its outside along n.
static func hides(g: UnitGeo, c: Vector3, right: Vector3, up: Vector3, n: Vector3, hw: float, hh: float, cols: int, rows: int,
		seed_value: int, lod: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if lod >= 2:
		g.box(c, Vector3(hw, hh, 0.03), HIDES[0], 0, Basis(right, up, n))
		return
	for i in cols:
		for j in rows:
			var u := -1.0 + (2.0 * i + 1.0) / cols
			var v := -1.0 + (2.0 * j + 1.0) / rows
			var p := c + right * (u * hw + rng.randf_range(-0.04, 0.04)) + up * (v * hh) + n * (0.01 * ((i + j) % 2))
			var bas := Basis(right, up, n).rotated(n, rng.randf_range(-0.05, 0.05))
			g.box(p, Vector3(hw / cols + 0.04, hh / rows + 0.05, 0.025), HIDES[rng.randi() % HIDES.size()], 0, bas)


# ---------------------------------------------------------------- the trebuchet

static func trebuchet(lod: int) -> Dictionary:
	var f := UnitGeo.new()
	var z0 := -3.4
	var z1 := 6.6
	for s: float in [-1.0, 1.0]:
		var x := s * 1.0
		beam(f, Vector3(x, 0.2, z0), Vector3(x, 0.2, z1), 0.14, TIMBER_DARK, 0.15)
		beam(f, Vector3(x, 0.3, 0), Vector3(x, 5.2, 0), 0.15, TIMBER)
		beam(f, Vector3(x, 0.3, -2.8), Vector3(x, 4.85, -0.12), 0.12, TIMBER)
		beam(f, Vector3(x, 0.3, 2.8), Vector3(x, 4.85, 0.12), 0.12, TIMBER)
		beam(f, Vector3(s * 2.6, 0.25, 0), Vector3(x, 3.2, 0), 0.1, TIMBER_PALE)
		f.box(Vector3(x, 5.1, 0), Vector3(0.2, 0.14, 0.24), TIMBER_DARK, 0)
		f.box(Vector3(x, 5.0, 0), Vector3(0.21, 0.04, 0.25), IRON, 0)
		# the windlass posts
		beam(f, Vector3(x, 0.3, T_WINCH.z), Vector3(x, T_WINCH.y + 0.25, T_WINCH.z), 0.1, TIMBER)
		beam(f, Vector3(x, 0.3, T_WINCH.z + 0.7), Vector3(x, T_WINCH.y, T_WINCH.z + 0.05), 0.07, TIMBER_PALE)
		if lod == 0:
			for zz: float in [-2.8, 2.8]:
				f.box(Vector3(x, 0.38, zz), Vector3(0.17, 0.05, 0.17), IRON, 0)
	for zz: float in [z0, -2.8, 0.0, 2.8, z1]:
		beam(f, Vector3(-1.15, 0.2, zz), Vector3(1.15, 0.2, zz), 0.12, TIMBER_DARK)
	beam(f, Vector3(-2.7, 0.15, 0), Vector3(2.7, 0.15, 0), 0.12, TIMBER_DARK)
	# the trough the sling lies in
	f.box(Vector3(0, 0.12, 3.4), Vector3(0.32, 0.04, 2.9), TIMBER_PALE, 0)
	if lod == 0:
		for s: float in [-1.0, 1.0]:
			f.box(Vector3(s * 0.34, 0.2, 3.4), Vector3(0.03, 0.08, 2.9), TIMBER, 0)
		# a heap of shot by the frame
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for k in 6:
			ball(f, Vector3(-2.0 + rng.randf_range(-0.4, 0.4), 0.22 + (0.3 if k > 3 else 0.0), 4.2 + rng.randf_range(-0.6, 0.6)), 0.22, STONE.darkened(rng.randf_range(0.0, 0.15)), 1)
	# The arm, on its axle.
	var a := UnitGeo.new()
	rod(a, Vector3(-1.1, 0, 0), Vector3(1.1, 0, 0), 0.075, IRON)
	a.loft([Vector3(0, 0, -T_SHORT - 0.15), Vector3(0, 0, 0), Vector3(0, 0, T_LONG)],
		[Vector2(0.17, 0.2), Vector2(0.19, 0.24), Vector2(0.075, 0.085)], Vector3.RIGHT, 4, 0.0, TIMBER, 0)
	if lod < 2:
		for zz: float in [-1.0, 1.1, 3.0, 5.2]:
			var k := 1.0 - maxf(zz, 0.0) / T_LONG * 0.6
			a.box(Vector3(0, 0, zz), Vector3(0.2 * k + 0.012, 0.24 * k + 0.012, 0.05), IRON, 0)
		rod(a, Vector3(-0.32, 0, -T_SHORT), Vector3(0.32, 0, -T_SHORT), 0.05, IRON)
	beam(a, Vector3(0, 0.0, T_LONG), Vector3(0, 0.3, T_LONG + 0.25), 0.025, IRON)
	# The counterweight box, on its pin.
	var w := UnitGeo.new()
	for s: float in [-1.0, 1.0]:
		beam(w, Vector3(s * 0.26, 0, 0), Vector3(s * 0.55, -1.08, 0), 0.06, TIMBER_DARK)
	w.box(Vector3(0, -1.78, 0), Vector3(0.72, 0.72, 0.62), TIMBER_DARK, 0)
	if lod < 2:
		for k in 5:
			w.box(Vector3(0, -1.2 - 0.28 * k, -0.625), Vector3(0.7, 0.012, 0.01), TIMBER, 0)
			w.box(Vector3(0, -1.2 - 0.28 * k, 0.625), Vector3(0.7, 0.012, 0.01), TIMBER, 0)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				w.box(Vector3(sx * 0.72, -1.78, sz * 0.62), Vector3(0.03, 0.74, 0.03), IRON, 0)
		for k in 4:
			ball(w, Vector3(-0.35 + 0.24 * k, -1.02, 0.1 * float(k % 2) - 0.05), 0.2, STONE.darkened(0.06 * k), 1)
	# The windlass: the drum and its two spoke wheels.
	var wi := UnitGeo.new()
	rod(wi, Vector3(-0.95, 0, 0), Vector3(0.95, 0, 0), 0.2, TIMBER, sides(lod))
	if lod == 0:
		rod(wi, Vector3(-0.4, 0, 0), Vector3(0.4, 0, 0), 0.215, ROPE, 10)
	for s: float in [-1.0, 1.0]:
		var x := s * T_SPOKE_X
		rod(wi, Vector3(s * 0.9, 0, 0), Vector3(x + s * 0.06, 0, 0), 0.07, IRON, 6)
		for k in 2:
			var d := Vector3(0, T_SPOKE_R, 0) if k == 0 else Vector3(0, 0, T_SPOKE_R)
			beam(wi, Vector3(x, 0, 0) - d, Vector3(x, 0, 0) + d, 0.035, TIMBER_PALE)
	# The sling's pouch and the shot.
	var p := UnitGeo.new()
	p.loft([Vector3(0, 0.02, -0.3), Vector3(0, -0.06, 0), Vector3(0, 0.02, 0.3)], [Vector2(0.2, 0.05), Vector2(0.24, 0.07), Vector2(0.2, 0.05)],
		Vector3.RIGHT, 4, 0.0, LEATHER, 0)
	return {"frame": f, "arm": a, "cw": w, "winch": wi, "pouch": p, "stone": stone(lod)}


# ---------------------------------------------------------------- the mangonel

static func mangonel(lod: int) -> Dictionary:
	var f := UnitGeo.new()
	for s: float in [-1.0, 1.0]:
		var x := s * 0.75
		beam(f, Vector3(x, 0.32, -2.2), Vector3(x, 0.32, 2.4), 0.12, TIMBER_DARK, 0.15)
		beam(f, Vector3(x, 0.32, -1.25), Vector3(x, 2.1, -1.25), 0.1, TIMBER)
		beam(f, Vector3(x, 0.32, -2.15), Vector3(x, 1.75, -1.32), 0.07, TIMBER_PALE)
		beam(f, Vector3(x, 0.32, -0.2), Vector3(x, 1.6, -1.18), 0.07, TIMBER_PALE)
		beam(f, Vector3(x, 0.32, M_WINCH.z), Vector3(x, M_WINCH.y + 0.18, M_WINCH.z), 0.08, TIMBER)
		f.box(Vector3(s * 0.86, M_SKEIN.y, M_SKEIN.z), Vector3(0.05, 0.2, 0.2), TIMBER_DARK, 0)
		rod(f, Vector3(s * 0.88, M_SKEIN.y, M_SKEIN.z), Vector3(s * 0.94, M_SKEIN.y, M_SKEIN.z), 0.24, IRON, sides(lod))
		if lod < 2:
			beam(f, Vector3(s * 0.97, M_SKEIN.y - 0.3, M_SKEIN.z - 0.2), Vector3(s * 0.97, M_SKEIN.y + 0.3, M_SKEIN.z + 0.2), 0.03, IRON)
		for zz: float in [-1.6, 1.6]:
			wheel(f, Vector3(s * 1.0, 0.35, zz), Vector3(s, 0, 0), 0.35, 0.07, lod)
	for zz: float in [-2.2, -0.2, 1.2, 2.4]:
		beam(f, Vector3(-0.85, 0.32, zz), Vector3(0.85, 0.32, zz), 0.1, TIMBER_DARK)
	beam(f, Vector3(-0.85, 1.95, -1.25), Vector3(0.85, 1.95, -1.25), 0.1, TIMBER)
	f.box(Vector3(0, 1.82, -1.1), Vector3(0.34, 0.2, 0.08), STRAW, 0, Basis(), 0.3)
	# the skein of twisted rope the arm is rooted in
	rod(f, Vector3(-0.82, M_SKEIN.y, M_SKEIN.z), Vector3(0.82, M_SKEIN.y, M_SKEIN.z), 0.2, ROPE, sides(lod))
	if lod == 0:
		for k in 6:
			var x := -0.7 + 0.28 * k
			rod(f, Vector3(x - 0.03, M_SKEIN.y, M_SKEIN.z), Vector3(x + 0.03, M_SKEIN.y, M_SKEIN.z), 0.21, ROPE.darkened(0.2), 8)
	var a := UnitGeo.new()
	a.loft([Vector3(0, 0, -0.18), Vector3(0, 0, M_ARM - 0.1)], [Vector2(0.09, 0.1), Vector2(0.065, 0.07)], Vector3.RIGHT, 4, 0.0, TIMBER, 0)
	# the cup, open to local +Y
	a.box(Vector3(0, 0.08, M_ARM), Vector3(0.23, 0.035, 0.25), TIMBER_DARK, 0)
	for s: float in [-1.0, 1.0]:
		a.box(Vector3(s * 0.22, 0.17, M_ARM), Vector3(0.025, 0.07, 0.25), TIMBER_DARK, 0)
		a.box(Vector3(0, 0.17, M_ARM + s * 0.24), Vector3(0.23, 0.07, 0.025), TIMBER_DARK, 0)
	if lod == 0:
		for zz: float in [0.5, 1.4, 2.2]:
			a.box(Vector3(0, 0, zz), Vector3(0.095, 0.105, 0.04), IRON, 0)
	var wi := UnitGeo.new()
	rod(wi, Vector3(-0.72, 0, 0), Vector3(0.72, 0, 0), 0.12, TIMBER, sides(lod))
	for s: float in [-1.0, 1.0]:
		var x := s * M_SPOKE_X
		rod(wi, Vector3(s * 0.7, 0, 0), Vector3(x + s * 0.05, 0, 0), 0.05, IRON, 6)
		for k in 2:
			var d := Vector3(0, M_SPOKE_R, 0) if k == 0 else Vector3(0, 0, M_SPOKE_R)
			beam(wi, Vector3(x, 0, 0) - d, Vector3(x, 0, 0) + d, 0.03, TIMBER_PALE)
	return {"frame": f, "arm": a, "winch": wi, "stone": stone(lod, 0.2)}


# ---------------------------------------------------------------- the ballista

static func ballista(lod: int) -> Dictionary:
	var f := UnitGeo.new()
	for s: float in [-1.0, 1.0]:
		beam(f, Vector3(s * 0.55, 0.32, -0.8), Vector3(s * 0.55, 0.32, 0.8), 0.07, TIMBER_DARK, 0.09)
		for zz: float in [-0.6, 0.6]:
			wheel(f, Vector3(s * 0.7, 0.26, zz), Vector3(s, 0, 0), 0.26, 0.06, lod)
		beam(f, Vector3(s * 0.5, 0.36, s * 0.6), Vector3(0, BA_MOUNT.y - 0.1, 0), 0.05, TIMBER_PALE)
		beam(f, Vector3(s * 0.5, 0.36, -s * 0.6), Vector3(0, BA_MOUNT.y - 0.1, 0), 0.05, TIMBER_PALE)
	for zz: float in [-0.8, 0.0, 0.8]:
		beam(f, Vector3(-0.6, 0.32, zz), Vector3(0.6, 0.32, zz), 0.06, TIMBER_DARK)
	beam(f, Vector3(0, 0.32, 0), Vector3(0, BA_MOUNT.y - 0.04, 0), 0.09, TIMBER)
	var m := UnitGeo.new()
	rod(m, Vector3(0, -0.06, 0), Vector3(0, 0.02, 0), 0.26, TIMBER_DARK, sides(lod))
	for s: float in [-1.0, 1.0]:
		m.box(Vector3(s * 0.13, 0.13, 0), Vector3(0.035, 0.13, 0.12), TIMBER, 0)
	var c := UnitGeo.new()
	c.box(Vector3(0, 0, 0.18), Vector3(0.075, 0.065, 1.18), TIMBER, 0)
	c.box(Vector3(0, 0.067, 0.1), Vector3(0.02, 0.003, 1.05), TIMBER_DARK, 0)
	rod(c, Vector3(-0.14, 0, 0), Vector3(0.14, 0, 0), 0.035, IRON, 6)
	# the torsion frame and its two skeins
	var fz := BA_SKEIN_Z
	for y: float in [-0.26, 0.26]:
		c.box(Vector3(0, y, fz), Vector3(0.5, 0.045, 0.08), TIMBER_DARK, 0)
	for x: float in [-0.48, -0.17, 0.17, 0.48]:
		c.box(Vector3(x, 0, fz), Vector3(0.035, 0.24, 0.07), TIMBER_DARK, 0)
	for s: float in [-1.0, 1.0]:
		rod(c, Vector3(s * BA_SKEIN_X, -0.24, fz), Vector3(s * BA_SKEIN_X, 0.24, fz), 0.07, ROPE, sides(lod))
		if lod < 2:
			for y: float in [-0.3, 0.3]:
				rod(c, Vector3(s * BA_SKEIN_X, y - 0.02, fz), Vector3(s * BA_SKEIN_X, y + 0.02, fz), 0.1, IRON, 8)
	# tiller pegs at the tail
	for s: float in [-1.0, 1.0]:
		rod(c, Vector3(s * 0.07, 0, 1.3), Vector3(s * 0.2, -0.04, 1.32), 0.025, TIMBER_DARK, 6)
	var arms := {}
	for s: float in [-1.0, 1.0]:
		var ag := UnitGeo.new()
		ag.loft([Vector3(0, 0, 0), Vector3(s * BA_ARM, 0, 0)], [Vector2(0.04, 0.045), Vector2(0.022, 0.026)], Vector3.UP, 4, 0.0, TIMBER_DARK, 0)
		ag.box(Vector3(s * BA_ARM, 0, 0), Vector3(0.03, 0.03, 0.03), IRON, 0)
		arms[s] = ag
	var sl := UnitGeo.new()
	sl.box(Vector3(0, 0.085, 0), Vector3(0.05, 0.02, 0.3), TIMBER_PALE, 0)
	sl.box(Vector3(0, 0.12, 0.28), Vector3(0.04, 0.035, 0.03), IRON, 0)
	var bo := UnitGeo.new()
	bo.loft([Vector3(0, 0.14, 0.26), Vector3(0, 0.14, -1.0)], [Vector2(0.018, 0.018), Vector2(0.018, 0.018)], Vector3.UP, 6, 0.0, TIMBER_PALE, 0)
	bo.loft([Vector3(0, 0.14, -0.98), Vector3(0, 0.14, -1.18)], [Vector2(0.03, 0.03), Vector2(0.003, 0.003)], Vector3.UP, 4, 0.0, IRON, 0)
	for k in 3:
		var ang := TAU * k / 3.0
		var d := Vector3(cos(ang), sin(ang), 0) * 0.04
		bo.box(Vector3(0, 0.14, 0.14) + d, Vector3(0.004, 0.004, 0.1) + d.abs() * 0.5, TIMBER, 0)
	var wi := UnitGeo.new()
	rod(wi, Vector3(-0.28, 0, 0), Vector3(0.28, 0, 0), 0.045, TIMBER, 8)
	for s: float in [-1.0, 1.0]:
		beam(wi, Vector3(s * 0.29, 0, 0), Vector3(s * 0.29, BA_CRANK, 0), 0.018, IRON)
		rod(wi, Vector3(s * 0.29, BA_CRANK, 0), Vector3(s * 0.42, BA_CRANK, 0), 0.022, TIMBER_DARK, 6)
	return {"frame": f, "mount": m, "cradle": c, "arm_l": arms[-1.0], "arm_r": arms[1.0], "slider": sl, "bolt": bo, "winch": wi}


## The ballista's bolt on its own (for flights and hits).
static func bolt() -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(0, 0, 0.6), Vector3(0, 0, -0.62)], [Vector2(0.018, 0.018), Vector2(0.018, 0.018)], Vector3.UP, 6, 0.0, TIMBER_PALE, 0)
	g.loft([Vector3(0, 0, -0.6), Vector3(0, 0, -0.8)], [Vector2(0.03, 0.03), Vector2(0.003, 0.003)], Vector3.UP, 4, 0.0, IRON, 0)
	for k in 3:
		var ang := TAU * k / 3.0
		var d := Vector3(cos(ang), sin(ang), 0) * 0.04
		g.box(Vector3(0, 0, 0.48) + d, Vector3(0.004, 0.004, 0.1) + d.abs() * 0.5, TIMBER, 0)
	return g


# ---------------------------------------------------------------- the siege tower

static func tower(lod: int, a: Dictionary, seed_value: int) -> Dictionary:
	var g := UnitGeo.new()
	var hx := TW_HALF.x
	var hz := TW_HALF.z
	var top := TW_FLOORS[3]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			beam(g, Vector3(sx * hx, 0.5, sz * hz), Vector3(sx * hx, top + 0.9, sz * hz), 0.11, TIMBER)
	for y: float in TW_FLOORS:
		for sz: float in [-1.0, 1.0]:
			beam(g, Vector3(-hx, y, sz * hz), Vector3(hx, y, sz * hz), 0.09, TIMBER_DARK)
		for sx: float in [-1.0, 1.0]:
			beam(g, Vector3(sx * hx, y, -hz), Vector3(sx * hx, y, hz), 0.09, TIMBER_DARK)
		g.box(Vector3(0, y + 0.02, 0), Vector3(hx - 0.05, 0.04, hz - 0.05), TIMBER_PALE, 0)
	# the undercarriage
	for sx: float in [-1.0, 1.0]:
		beam(g, Vector3(sx * 1.45, 0.5, -hz - 0.25), Vector3(sx * 1.45, 0.5, hz + 0.25), 0.12, TIMBER_DARK)
		for sz: float in [-1.0, 1.0]:
			wheel(g, Vector3(sx * 1.84, 0.55, sz * 1.15), Vector3(sx, 0, 0), 0.55, 0.1, lod)
	for sz: float in [-1.0, 1.0]:
		rod(g, Vector3(-1.95, 0.55, sz * 1.15), Vector3(1.95, 0.55, sz * 1.15), 0.06, IRON, 6)
	# hides: the front up to the bridge, the sides up to the top storey's rail
	var hb := TW_FLOORS[0] + 0.1
	hides(g, Vector3(0, (hb + TW_FLOORS[2]) * 0.5, -hz - 0.06), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, hx + 0.05,
		(TW_FLOORS[2] - hb) * 0.5, 3, 4, seed_value, lod)
	for sx: float in [-1.0, 1.0]:
		hides(g, Vector3(sx * (hx + 0.06), (hb + top - 0.6) * 0.5, 0), Vector3.BACK, Vector3.UP, Vector3(sx, 0, 0), hz + 0.05,
			(top - 0.6 - hb) * 0.5, 3, 5, seed_value + int(sx * 7.0), lod)
	# the top: a fighting platform with wooden merlons
	for k in 5:
		var x := -hx + 0.3 + (2.0 * hx - 0.6) * k / 4.0
		for sz: float in [-1.0, 1.0]:
			g.box(Vector3(x, top + 0.45, sz * (hz - 0.02)), Vector3(0.22, 0.42, 0.05), HIDES[k % 3], 0)
		g.box(Vector3(-hx + 0.02 if k % 2 == 0 else hx - 0.02, top + 0.45, -hz + 0.35 + (2.0 * hz - 0.7) * k / 4.0),
			Vector3(0.05, 0.42, 0.22), HIDES[(k + 1) % 3], 0)
		g.box(Vector3(hx - 0.02 if k % 2 == 0 else -hx + 0.02, top + 0.45, -hz + 0.35 + (2.0 * hz - 0.7) * k / 4.0),
			Vector3(0.05, 0.42, 0.22), HIDES[(k + 2) % 3], 0)
	# the lord's arms painted on the hides, loopholes
	MB.paint(g, a, MB.HEATER, Vector3(0, 2.9, -hz - 0.11), Vector3(-1, 0, 0), Vector3.UP, 0.8, 0.95, 0, false, lod == 0)
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(sx * 1.0, 4.1, -hz - 0.1), Vector3(0.05, 0.22, 0.012), SLIT, 0)
		g.box(Vector3(sx * (hx + 0.1), 3.8, -0.6), Vector3(0.012, 0.22, 0.05), SLIT, 0)
		g.box(Vector3(sx * (hx + 0.1), 5.7, 0.4), Vector3(0.012, 0.22, 0.05), SLIT, 0)
	# inside: ladders between floors (seen from behind)
	if lod == 0:
		for i in 3:
			var x := 1.1 if i % 2 == 0 else -1.1
			var y0 := TW_FLOORS[i]
			var y1 := TW_FLOORS[i + 1]
			for s: float in [-1.0, 1.0]:
				beam(g, Vector3(x + s * 0.2, y0, 1.2), Vector3(x + s * 0.2, y1 + 0.4, 0.8), 0.03, TIMBER_PALE)
			var n := int((y1 - y0) / 0.33)
			for k in n:
				var t := (k + 0.6) / float(n)
				beam(g, Vector3(x - 0.2, lerpf(y0, y1 + 0.4, t), lerpf(1.2, 0.8, t)), Vector3(x + 0.2, lerpf(y0, y1 + 0.4, t), lerpf(1.2, 0.8, t)), 0.018, TIMBER_PALE)
	# the push bars behind
	for sx: float in [-1.0, 1.0]:
		beam(g, Vector3(sx * 1.0, 1.0, hz - 0.1), Vector3(sx * 1.0, 1.0, hz + 1.5), 0.07, TIMBER_DARK)
	beam(g, Vector3(-1.4, 1.0, hz + 1.42), Vector3(1.4, 1.0, hz + 1.42), 0.07, TIMBER_DARK)
	# the banner on the back corner
	var pole := Vector3(hx - 0.1, top, hz - 0.1)
	rod(g, pole, pole + Vector3(0, 2.8, 0), 0.035, TIMBER_DARK, 6)
	g.box(pole + Vector3(-0.62, 2.35, 0), Vector3(0.6, 0.38, 0.012), (a["field"] as Color), 0)
	MB.paint(g, a, MB.RECT, pole + Vector3(-0.62, 2.35, -0.016), Vector3(-1, 0, 0), Vector3.UP, 0.58, 0.36, 0, false, lod == 0)
	MB.paint(g, a, MB.RECT, pole + Vector3(-0.62, 2.35, 0.016), Vector3(1, 0, 0), Vector3.UP, 0.58, 0.36, 0, false, lod == 0)
	# the bridge, hinged at its foot (open = flat along -Z)
	var b := UnitGeo.new()
	var L := TW_BRIDGE
	var nplank := 6 if lod == 0 else 3
	for k in nplank:
		var x := -1.25 + 2.5 * (k + 0.5) / nplank
		b.box(Vector3(x, 0.0, -L * 0.5), Vector3(1.25 / nplank - 0.01, 0.04, L * 0.5), TIMBER_PALE.darkened(0.06 * (k % 3)), 0)
	for zz: float in [-0.4, -1.4, -2.4]:
		b.box(Vector3(0, -0.07, zz), Vector3(1.3, 0.04, 0.07), TIMBER_DARK, 0)
	if lod == 0:
		for k in 8:
			b.box(Vector3(0, 0.05, -0.2 - 0.35 * k), Vector3(1.1, 0.012, 0.025), TIMBER_DARK, 0)
	for sx: float in [-1.0, 1.0]:
		beam(b, Vector3(sx * 0.9, -0.02, -L + 0.05), Vector3(sx * 0.9, -0.3, -L - 0.08), 0.03, IRON)
		b.box(Vector3(sx * 1.27, 0.06, -L * 0.5), Vector3(0.04, 0.06, L * 0.5), TIMBER_DARK, 0)
	return {"body": g, "bridge": b}


# ---------------------------------------------------------------- the ram

static func ram(lod: int, a: Dictionary, seed_value: int) -> Dictionary:
	var g := UnitGeo.new()
	var hz := 3.0
	var eave := 2.1
	var ridge := 3.05
	for sx: float in [-1.0, 1.0]:
		beam(g, Vector3(sx * 1.2, 0.55, -hz), Vector3(sx * 1.2, 0.55, hz), 0.11, TIMBER_DARK)
		beam(g, Vector3(sx * 1.25, eave, -hz - 0.1), Vector3(sx * 1.25, eave, hz + 0.1), 0.08, TIMBER_DARK)
		for zz: float in [-2.8, 0.0, 2.8]:
			beam(g, Vector3(sx * 1.2, 0.55, zz), Vector3(sx * 1.2, eave, zz), 0.09, TIMBER)
		for zz: float in [-2.1, 2.1]:
			wheel(g, Vector3(sx * 1.47, 0.45, zz), Vector3(sx, 0, 0), 0.45, 0.09, lod)
	for zz: float in [-2.1, 2.1]:
		rod(g, Vector3(-1.6, 0.45, zz), Vector3(1.6, 0.45, zz), 0.05, IRON, 6)
	for zz: float in [-hz, hz]:
		beam(g, Vector3(-1.25, 0.55, zz), Vector3(1.25, 0.55, zz), 0.09, TIMBER_DARK)
	beam(g, Vector3(0, ridge, -hz - 0.15), Vector3(0, ridge, hz + 0.15), 0.08, TIMBER_DARK)
	for zz: float in [-2.8, -1.4, 0.0, 1.4, 2.8]:
		for sx: float in [-1.0, 1.0]:
			beam(g, Vector3(sx * 1.32, eave - 0.05, zz), Vector3(0, ridge, zz), 0.06, TIMBER)
	for pz: float in R_PIVOT_Z:
		beam(g, Vector3(-0.66, R_PIVOT_Y + 0.08, pz), Vector3(0.66, R_PIVOT_Y + 0.08, pz), 0.07, TIMBER_DARK)
	# the roof hides on both slopes, and a short skirt below the eaves
	for sx: float in [-1.0, 1.0]:
		var lo := Vector3(sx * 1.42, eave - 0.08, 0)
		var hi := Vector3(0, ridge + 0.08, 0)
		var up := (hi - lo).normalized()
		var nn := Vector3(sx * absf(up.y), absf(up.x), 0).normalized()
		hides(g, (lo + hi) * 0.5 + nn * 0.04, Vector3.BACK, up, nn, hz + 0.15, (hi - lo).length() * 0.5, 4, 2, seed_value + int(sx * 3.0), lod)
		hides(g, Vector3(sx * 1.33, eave - 0.16, 0), Vector3.BACK, Vector3.UP, Vector3(sx, 0, 0), hz + 0.1, 0.15, 4, 1, seed_value + 11 + int(sx), lod)
	# the front gable, boarded, with the lord's arms
	for sx: float in [-1.0, 1.0]:
		g.tri_out(Vector3(0, ridge, -hz - 0.12), Vector3(sx * 1.3, eave, -hz - 0.12), Vector3(0, eave, -hz - 0.12), TIMBER_PALE, 0, Vector3(0, 2.5, 0))
	MB.paint(g, a, MB.HEATER, Vector3(0, 2.42, -hz - 0.14), Vector3(-1, 0, 0), Vector3.UP, 0.28, 0.33, 0, false, lod == 0)
	beam(g, Vector3(-1.3, eave, -hz - 0.1), Vector3(1.3, eave, -hz - 0.1), 0.07, TIMBER_DARK)
	# The ram: the log and its head (in its own frame, the log along Z at y 0).
	var r := UnitGeo.new()
	r.loft([Vector3(0, 0, R_HEAD_Z + 0.4), Vector3(0, 0, -1.0), Vector3(0, 0, 2.7)], [Vector2(0.2, 0.2), Vector2(0.21, 0.21), Vector2(0.18, 0.18)],
		Vector3.UP, 8, 0.0, TIMBER, 0)
	r.loft([Vector3(0, 0, R_HEAD_Z + 0.45), Vector3(0, 0, R_HEAD_Z + 0.1), Vector3(0, 0, R_HEAD_Z)],
		[Vector2(0.23, 0.23), Vector2(0.21, 0.21), Vector2(0.15, 0.15)], Vector3.UP, 8, 0.3, IRON, 0)
	if lod < 2:
		for zz: float in [-3.5, -1.5, 0.5, 2.3]:
			r.loft([Vector3(0, 0, zz - 0.05), Vector3(0, 0, zz + 0.05)], [Vector2(0.225, 0.225), Vector2(0.225, 0.225)], Vector3.UP, 8, 0.0, IRON, 0)
		# horns on the head
		for s: float in [-1.0, 1.0]:
			r.loft([Vector3(s * 0.18, 0.12, R_HEAD_Z + 0.3), Vector3(s * 0.3, 0.22, R_HEAD_Z + 0.5), Vector3(s * 0.28, 0.05, R_HEAD_Z + 0.62)],
				[Vector2(0.05, 0.05), Vector2(0.04, 0.04), Vector2(0.015, 0.015)], Vector3.UP, 6, 0.0, IRON, 0)
	for hz2: float in R_HANDLES:
		for s: float in [-1.0, 1.0]:
			r.box(Vector3(s * 0.25, -0.05, hz2), Vector3(0.025, 0.09, 0.05), ROPE, 0)
	for pz: float in R_PIVOT_Z:
		r.loft([Vector3(0, 0, pz - 0.06), Vector3(0, 0, pz + 0.06)], [Vector2(0.235, 0.235), Vector2(0.235, 0.235)], Vector3.UP, 8, 0.0, ROPE, 0)
	return {"body": g, "ram": r}


# ---------------------------------------------------------------- the approach kit

## A scaling ladder: its foot at the origin, up +Y, the rungs across X; hooks at the top.
static func ladder(lod: int) -> Dictionary:
	var g := UnitGeo.new()
	for s: float in [-1.0, 1.0]:
		g.loft([Vector3(s * L_HALF, 0, 0), Vector3(s * L_HALF * 0.82, L_LEN, 0)], [Vector2(0.035, 0.03), Vector2(0.03, 0.025)], Vector3.RIGHT, 4, 0.0, TIMBER, 0)
		beam(g, Vector3(s * L_HALF * 0.82, L_LEN - 0.05, 0), Vector3(s * L_HALF * 0.82, L_LEN + 0.12, -0.18), 0.018, IRON)
	var n := int(L_LEN / L_RUNG)
	for k in n:
		var y := 0.3 + L_RUNG * k
		if y > L_LEN - 0.1:
			break
		var w := L_HALF * (1.0 - 0.18 * y / L_LEN)
		g.box(Vector3(0, y, 0), Vector3(w, 0.018, 0.022), TIMBER_PALE, 0)
	return {"body": g}


## A wheeled mantlet: a plank screen leaning back, in the lord's arms, on two wheels with handles behind.
static func mantlet(lod: int, a: Dictionary) -> Dictionary:
	var g := UnitGeo.new()
	var tilt := 0.21
	var up := Vector3(0, cos(tilt), sin(tilt))
	var base := Vector3(0, 0.25, 0)
	var c := base + up * 1.0
	var bas := Basis(Vector3.RIGHT, up, Vector3.RIGHT.cross(up))
	var n := 8 if lod == 0 else 2
	for k in n:
		var x := -1.1 + 2.2 * (k + 0.5) / n
		g.box(c + Vector3(x, 0, 0), Vector3(1.1 / n - 0.008, 1.0, 0.045), TIMBER.darkened(0.05 * (k % 3)), 0, bas)
	for y: float in [0.3, 1.6]:
		g.box(base + up * y + bas.z * 0.07, Vector3(1.08, 0.06, 0.03), TIMBER_DARK, 0, bas)
	MB.paint(g, a, MB.RECT, c - bas.z * 0.05, Vector3(-1, 0, 0), up, 1.06, 0.96, 0, false, lod == 0)
	g.box(c + up * 0.45 + Vector3(0.35, 0, 0) - bas.z * 0.07, Vector3(0.16, 0.035, 0.03), SLIT, 0, bas)
	rod(g, Vector3(-1.2, 0.3, 0.05), Vector3(1.2, 0.3, 0.05), 0.04, IRON, 6)
	for s: float in [-1.0, 1.0]:
		wheel(g, Vector3(s * 1.2, 0.3, 0.05), Vector3(s, 0, 0), 0.3, 0.05, lod)
		beam(g, Vector3(s * 0.45, 0.95, 0.28), Vector3(s * 0.45, 0.78, 1.4), 0.035, TIMBER_DARK)
	return {"body": g}


## A fascine: a bundle of brushwood bound with withies, along X.
static func fascine(lod: int, seed_value := 1) -> Dictionary:
	var g := UnitGeo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cs: Array = []
	var sz: Array = []
	for k in 5:
		cs.append(Vector3(-1.3 + 0.65 * k, rng.randf_range(-0.02, 0.02), 0))
		var r := 0.3 + rng.randf_range(-0.03, 0.03)
		sz.append(Vector2(r, r * 0.95))
	g.loft(cs, sz, Vector3.UP, 8 if lod == 0 else 6, 0.0, BRUSH, 0, BRUSH_DARK if lod == 0 else null)
	if lod < 2:
		for x: float in [-0.9, -0.3, 0.3, 0.9]:
			g.loft([Vector3(x - 0.035, 0, 0), Vector3(x + 0.035, 0, 0)], [Vector2(0.325, 0.31), Vector2(0.325, 0.31)], Vector3.UP, 8, 0.0, WITHY, 0)
	if lod == 0:
		for k in 14:
			var ang := rng.randf() * TAU
			var r := rng.randf_range(0.05, 0.27)
			var p := Vector3(0, sin(ang) * r, cos(ang) * r)
			var s := 1.0 if k % 2 == 0 else -1.0
			var x0 := s * rng.randf_range(0.9, 1.25)
			beam(g, p + Vector3(x0, 0, 0), p + Vector3(s * rng.randf_range(1.35, 1.6), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08)),
				0.012, BRUSH_DARK if k % 3 == 0 else WITHY)
	return {"body": g}
