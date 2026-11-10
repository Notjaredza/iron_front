class_name EngineerWorks
extends RefCounted
## The engineers' work pieces (Building Chat 1, 2026-11-10), each built for how far the work has got (p 0..1), so it
## grows as the men work. Each is a UnitGeo in its own frame: the work's origin on the ground (y = 0), the work line
## along X. Turn into meshes with geo.to_mesh(Soldier.material()).
##   spoil(p, length)   the thrown-up earth along a trench's front lip (-Z side), rising and widening
##   trench_tape(length, width)   the white tape and pegs marking the trench out
##   duckboards(length)  slatted boards for the finished trench floor
##   plank_wall(p)      posts, and planks nailed on from the bottom up (up to 8 planks)
##   plank_stack(p)     the stack of new planks by the wall, going down as the wall goes up
##   trestle(cut)       a trestle with a plank on it, cut part way
##   wire(p)            pickets every 2.5 m and two barbed strands strung on as far as the work has got, with the
##                      newest picket half driven
##   wreck(p)           a crate-like steel hull (frame ribs inside), its side panels gone one by one
##   panel_pile(p)      the stripped panels piling up
##   track(stage)       two rails on sleepers. stage: "broken" (a split sleeper in the middle), "out" (the bay empty, the
##                      broken one cast aside), "new" (the new sleeper in, spikes loose), "spiked" (spiked home)
##   sleeper()          one loose sleeper along X, its middle at the origin

const B := preload("res://scripts/units/soldier_builder.gd")
const EARTH := Color(0.42, 0.34, 0.24)
const EARTH_FRESH := Color(0.35, 0.27, 0.18)
const TIMBER := Color(0.50, 0.38, 0.24)
const TIMBER_NEW := Color(0.66, 0.52, 0.33)
const TIMBER_OLD := Color(0.30, 0.25, 0.19)
const TAPE := Color(0.92, 0.91, 0.86)
const STEEL := Color(0.24, 0.25, 0.24)
const RUST := Color(0.40, 0.27, 0.17)
const HULL := Color(0.36, 0.38, 0.30)
const HULL_DARK := Color(0.22, 0.23, 0.19)
const RAIL := Color(0.30, 0.29, 0.28)
const BALLAST := Color(0.38, 0.36, 0.33)
const PICKET_GAP := 2.5
const WALL_POSTS := 4
const WALL_PLANKS := 8
const SLEEPER_GAP := 0.7
const SLEEPER_LEN := 2.4
const GAUGE := 1.435


static func spoil(p: float, length: float) -> UnitGeo:
	var g := UnitGeo.new()
	if p <= 0.01:
		return g
	var h := 0.08 + 0.5 * p
	var w := 0.25 + 0.45 * p
	var n := 8
	var cs: Array = []
	var sz: Array = []
	for k in n + 1:
		var x := -length * 0.5 + length * k / float(n)
		var bump := 0.06 * sin(k * 2.3) * p
		cs.append(Vector3(x, 0.0, -w * 0.5))
		sz.append(Vector2(w * 0.5, h + bump))
	# A ridge: a loft along X with a flat 4-sided section, its top pulled in by the chamfer.
	g.loft(cs, sz, Vector3.BACK, 6, 0.0, EARTH_FRESH, 0, EARTH)
	return g


static func trench_tape(length: float, width: float) -> UnitGeo:
	var g := UnitGeo.new()
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0, 0.012, width * 0.5 * s), Vector3(length * 0.5, 0.004, 0.02), TAPE, 0)
		g.box(Vector3(length * 0.5 * s, 0.012, 0), Vector3(0.02, 0.004, width * 0.5), TAPE, 0)
		for e: float in [1.0, -1.0]:
			g.box(Vector3(length * 0.5 * s, 0.1, width * 0.5 * e), Vector3(0.02, 0.1, 0.02), TIMBER, 0)
	return g


static func duckboards(length: float) -> UnitGeo:
	var g := UnitGeo.new()
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0, 0.04, 0.22 * s), Vector3(length * 0.5, 0.03, 0.03), TIMBER_OLD, 0)
	var n := int(length / 0.18)
	for k in n:
		g.box(Vector3(-length * 0.5 + 0.09 + 0.18 * k, 0.08, 0), Vector3(0.05, 0.012, 0.3), TIMBER, 0)
	return g


static func plank_wall(p: float) -> UnitGeo:
	var g := UnitGeo.new()
	var span := 0.9
	var x0 := -span * (WALL_POSTS - 1) * 0.5
	for k in WALL_POSTS:
		g.box(Vector3(x0 + span * k, 0.85, 0.06), Vector3(0.06, 0.85, 0.06), TIMBER_OLD, 0, Basis(), 0.2)
	var n := int(round(p * WALL_PLANKS))
	for k in n:
		var y := 0.1 + 0.2 * k
		var col := TIMBER_NEW.darkened(0.05 * (k % 3))
		g.box(Vector3(0, y, 0.0), Vector3(span * (WALL_POSTS - 1) * 0.5 + 0.12, 0.095, 0.015), col, 0)
		for j in WALL_POSTS:
			g.box(Vector3(x0 + span * j, y, -0.018), Vector3(0.008, 0.008, 0.004), STEEL, 0)
	return g


static func plank_stack(p: float) -> UnitGeo:
	var g := UnitGeo.new()
	var n := int(round((1.0 - p) * WALL_PLANKS))
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.7 * s, 0.04, 0), Vector3(0.05, 0.04, 0.2), TIMBER_OLD, 0)
	for k in n:
		g.box(Vector3(0.02 * (k % 2), 0.09 + 0.03 * k, 0.0), Vector3(1.4, 0.015, 0.11), TIMBER_NEW.darkened(0.04 * (k % 3)), 0)
	return g


static func trestle(cut: float) -> UnitGeo:
	var g := UnitGeo.new()
	for s: float in [1.0, -1.0]:
		var x := 0.55 * s
		g.box(Vector3(x, 0.6, 0), Vector3(0.04, 0.03, 0.22), TIMBER_OLD, 0)
		for e: float in [1.0, -1.0]:
			g.loft([Vector3(x, 0.0, 0.25 * e), Vector3(x, 0.58, 0.08 * e)], [Vector2(0.025, 0.025), Vector2(0.025, 0.025)],
				Vector3.RIGHT, 4, 0.0, TIMBER_OLD, 0)
	# The plank across, and its offcut end hanging as the cut goes through (the cut at x 0.85, across Z).
	g.box(Vector3(0.1, 0.645, 0), Vector3(0.75, 0.015, 0.11), TIMBER_NEW, 0)
	var off := Basis(Vector3.BACK, -0.5 * clampf((cut - 0.8) / 0.2, 0.0, 1.0))
	g.box(Vector3(1.0, 0.645, 0) + off * Vector3(0.15, 0, 0), Vector3(0.15, 0.015, 0.11), TIMBER_NEW, 0, off)
	if cut > 0.0:
		g.box(Vector3(0.85, 0.645, 0.11 - 0.22 * cut * 0.5), Vector3(0.006, 0.017, 0.11 * cut), TIMBER_OLD, 0)
	g.box(Vector3(0.85, 0.0, 0.0), Vector3(0.18, 0.005 + 0.01 * cut, 0.14), TIMBER_NEW.lightened(0.2), 0)  # sawdust
	return g


static func _strand(g: UnitGeo, a: Vector3, b: Vector3, sag: float) -> void:
	var n := maxi(2, int(a.distance_to(b) / 0.4))
	var cs: Array = []
	var sz: Array = []
	for k in n + 1:
		var u := float(k) / n
		cs.append(a.lerp(b, u) + Vector3(0, -sag * 4.0 * u * (1.0 - u), 0))
		sz.append(Vector2(0.006, 0.006))
	g.loft(cs, sz, Vector3.UP, 4, 0.0, RUST, 0)
	for k in range(1, n):
		var c: Vector3 = cs[k]
		g.box(c, Vector3(0.022, 0.004, 0.004), STEEL, 0, Basis(Vector3.BACK, 0.8 + k))
		g.box(c, Vector3(0.004, 0.022, 0.004), STEEL, 0, Basis(Vector3.RIGHT, 0.7 + k))


static func _picket(g: UnitGeo, at: Vector3, h: float) -> void:
	# An iron screw picket: the shaft, the eyes for the wire.
	g.box(at + Vector3(0, h * 0.5, 0), Vector3(0.018, h * 0.5, 0.018), STEEL, 0)
	for y: float in [0.45, 0.85]:
		if y < h:
			g.loft([at + Vector3(0, y, 0), at + Vector3(0, y + 0.03, 0)], [Vector2(0.03, 0.03), Vector2(0.03, 0.03)],
				Vector3.RIGHT, 6, 0.0, STEEL, 0, null, 0)


## p 0..1: how far along the line (5 bays). The newest picket stands half driven while the mallet works on it.
static func wire(p: float) -> UnitGeo:
	var g := UnitGeo.new()
	var bays := 5
	var done := p * bays
	var full := int(floor(done))
	var part := done - full
	var tops: Array = []
	for k in mini(full, bays) + 1:
		var at := Vector3(PICKET_GAP * k, 0, 0)
		var h := 1.0
		if k == full and k < bays:
			h = 1.0 + 0.5 * (1.0 - clampf(part * 2.0, 0.0, 1.0))  # being driven
		_picket(g, at, h)
		tops.append(at)
	# Strands on the finished bays; on the bay being worked, they reach as far as the work.
	for k in range(1, tops.size()):
		var a: Vector3 = tops[k - 1]
		var b: Vector3 = tops[k]
		var reach := 1.0 if (k < full or p >= 1.0) else clampf((part - 0.5) * 2.0, 0.0, 1.0)
		if k > full and p < 1.0:
			continue
		if reach <= 0.0:
			continue
		for y: float in [0.46, 0.86]:
			_strand(g, a + Vector3(0, y, 0), a.lerp(b, reach) + Vector3(0, y, 0), 0.04)
		# A diagonal from the top of one picket to the foot of the next.
		if reach >= 1.0:
			_strand(g, a + Vector3(0, 0.86, 0), b + Vector3(0, 0.08, 0), 0.02)
	return g


static func hull_size() -> Vector3:
	return Vector3(3.0, 1.5, 1.7)


## A crate-like hull (a wrecked lorry body / tank stand-in), its near side (+Z) made of 6 panels that come off in
## order with p, showing the dark ribs and the inside.
static func wreck(p: float) -> UnitGeo:
	var g := UnitGeo.new()
	var s := hull_size() * 0.5
	var y0 := 0.25
	# Inside and the far side, the roof, the ends.
	g.box(Vector3(0, y0 + s.y, -s.z + 0.03), Vector3(s.x, s.y, 0.03), HULL, 0)
	g.box(Vector3(0, y0 + 0.03, 0), Vector3(s.x, 0.03, s.z), HULL_DARK, 0)
	g.box(Vector3(0, y0 + 2.0 * s.y - 0.03, -0.1), Vector3(s.x, 0.03, s.z - 0.1), HULL.darkened(0.1), 0, Basis(Vector3.RIGHT, 0.08))
	for e: float in [1.0, -1.0]:
		g.box(Vector3(e * (s.x - 0.03), y0 + s.y, 0), Vector3(0.03, s.y, s.z), HULL.darkened(0.05), 0)
	# The skids it sits on, and the ribs on the open side.
	for e: float in [1.0, -1.0]:
		g.box(Vector3(0, 0.12, e * 0.6), Vector3(s.x + 0.1, 0.12, 0.08), RUST, 0)
	for k in 4:
		var x := -s.x + 2.0 * s.x * k / 3.0
		g.box(Vector3(x, y0 + s.y, s.z - 0.04), Vector3(0.04, s.y, 0.04), HULL_DARK, 0)
	g.box(Vector3(0, y0 + s.y, s.z - 0.04), Vector3(s.x, 0.035, 0.04), HULL_DARK, 0)
	# Some wreckage inside (an engine block, a burst drum).
	g.box(Vector3(-0.7, y0 + 0.35, -0.1), Vector3(0.35, 0.3, 0.4), Color(0.18, 0.18, 0.18), 0, Basis(), 0.2)
	g.loft([Vector3(0.6, y0 + 0.06, 0.1), Vector3(0.6, y0 + 0.6, 0.1)], [Vector2(0.22, 0.22), Vector2(0.22, 0.22)],
		Vector3.RIGHT, 8, 0.0, RUST, 0)
	# The six side panels (3 along x 2 high); the ones taken so far are gone.
	var gone := int(round(p * 6.0))
	var order := [4, 3, 5, 1, 0, 2]
	for i in 6:
		if order.find(i) < gone:
			continue
		var cx := -s.x + s.x / 3.0 + 2.0 * s.x / 3.0 * (i % 3)
		var cy := y0 + s.y * 0.5 + s.y * (i / 3)
		g.box(Vector3(cx, cy, s.z), Vector3(s.x / 3.0 - 0.01, s.y * 0.5 - 0.01, 0.025), HULL.darkened(0.04 * (i % 2)), 0)
		for k in 5:
			g.box(Vector3(cx - s.x / 3.0 + 0.06 + (2.0 * s.x / 3.0 - 0.12) * k / 4.0, cy + s.y * 0.5 - 0.05, s.z + 0.03),
				Vector3(0.012, 0.012, 0.008), HULL_DARK, 0)
	return g


static func panel_pile(p: float) -> UnitGeo:
	var g := UnitGeo.new()
	var n := int(round(p * 6.0))
	for k in n:
		var b := Basis(Vector3.UP, 0.15 * sin(k * 1.7))
		g.box(Vector3(0.03 * k, 0.03 + 0.05 * k, 0.02 * (k % 2)), Vector3(0.5, 0.025, 0.37), HULL.darkened(0.05 * (k % 3)), 0, b)
	return g


static func sleeper(col := TIMBER_OLD) -> UnitGeo:
	var g := UnitGeo.new()
	g.box(Vector3(0, 0.075, 0), Vector3(SLEEPER_LEN * 0.5, 0.075, 0.12), col, 0, Basis(), 0.15)
	return g


## The track runs along X; the bay being mended is the one at x = 0.
static func track(stage: String) -> UnitGeo:
	var g := UnitGeo.new()
	var n := 9
	# Ballast bed.
	g.box(Vector3(0, 0.03, 0), Vector3(SLEEPER_GAP * n * 0.5 + 0.4, 0.03, SLEEPER_LEN * 0.5 + 0.35), BALLAST, 0, Basis(), 0.3)
	for k in n:
		var x := (k - (n - 1) * 0.5) * SLEEPER_GAP
		if k == (n - 1) / 2:
			continue
		g.box(Vector3(x, 0.1, 0), Vector3(0.12, 0.075, SLEEPER_LEN * 0.5), TIMBER_OLD.darkened(0.05 * (k % 3)), 0, Basis(), 0.15)
		_spikes(g, x, true)
	# The bay at x = 0.
	match stage:
		"broken":
			for e: float in [1.0, -1.0]:
				var b := Basis(Vector3.RIGHT, 0.06 * e) * Basis(Vector3.UP, 0.05 * e)
				g.box(Vector3(0.02 * e, 0.08, 0.6 * e), Vector3(0.12, 0.06, 0.58), TIMBER_OLD.darkened(0.25), 0, b, 0.15)
		"out":
			g.box(Vector3(0, 0.02, 0), Vector3(0.18, 0.02, SLEEPER_LEN * 0.5), EARTH.darkened(0.15), 0)
			for e: float in [1.0, -1.0]:
				g.box(Vector3(0.0, 0.07, 2.0 + 0.3 * e), Vector3(0.6, 0.06, 0.12), TIMBER_OLD.darkened(0.25), 0, Basis(Vector3.UP, 0.2 * e), 0.15)
		"new", "spiked":
			g.box(Vector3(0, 0.1, 0), Vector3(0.12, 0.075, SLEEPER_LEN * 0.5), TIMBER_NEW.darkened(0.15), 0, Basis(), 0.15)
			_spikes(g, 0.0, stage == "spiked")
			for e: float in [1.0, -1.0]:
				g.box(Vector3(0.0, 0.07, 2.0 + 0.3 * e), Vector3(0.6, 0.06, 0.12), TIMBER_OLD.darkened(0.25), 0, Basis(Vector3.UP, 0.2 * e), 0.15)
	# The rails over everything.
	for e: float in [1.0, -1.0]:
		var z := GAUGE * 0.5 * e
		var L := SLEEPER_GAP * n * 0.5 + 0.3
		g.box(Vector3(0, 0.185, z), Vector3(L, 0.01, 0.06), RAIL, 0)
		g.box(Vector3(0, 0.23, z), Vector3(L, 0.035, 0.012), RAIL, 0)
		g.box(Vector3(0, 0.27, z), Vector3(L, 0.012, 0.032), RAIL.lightened(0.15), 0)
	return g


static func _spikes(g: UnitGeo, x: float, home: bool) -> void:
	for e: float in [1.0, -1.0]:
		for f: float in [1.0, -1.0]:
			var z := GAUGE * 0.5 * e + 0.09 * f
			var h := 0.19 if home else 0.3
			g.box(Vector3(x + 0.04 * f, h, z), Vector3(0.012, 0.012 if home else 0.07, 0.012), STEEL, 0)
			if home:
				g.box(Vector3(x + 0.04 * f, h + 0.012, z - 0.012 * f), Vector3(0.016, 0.006, 0.022), STEEL, 0)
