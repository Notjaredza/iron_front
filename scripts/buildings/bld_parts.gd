class_name BldParts
extends RefCounted
## Iron Front buildings: the palette and the shared pieces every building set uses (Asset Builder Chat).
## Field-army mix: timber huts, sandbags, corrugated iron, a few brick and stone halls; flat shaded like the
## trains and planes. All pieces write into a BGeo (or a TrainGeo for moving parts) in the building frame.

const BRICK := Color(0.55, 0.30, 0.22)
const BRICK_DARK := Color(0.42, 0.22, 0.17)
const STONE := Color(0.60, 0.58, 0.52)
const STONE_DARK := Color(0.46, 0.45, 0.41)
const CONCRETE := Color(0.62, 0.61, 0.57)
const CONCRETE_DARK := Color(0.48, 0.48, 0.45)
const TIMBER := Color(0.45, 0.33, 0.21)
const TIMBER_DARK := Color(0.33, 0.24, 0.15)
const TIMBER_NEW := Color(0.72, 0.58, 0.38)
const PLANK := Color(0.52, 0.42, 0.30)
const IRON := Color(0.47, 0.49, 0.48)
const IRON_RUST := Color(0.50, 0.36, 0.26)
const TARPAPER := Color(0.20, 0.20, 0.21)
const SLATE := Color(0.30, 0.32, 0.35)
const TILE_RED := Color(0.55, 0.27, 0.20)
const CANVAS := Color(0.62, 0.58, 0.44)
const SANDBAG := Color(0.66, 0.58, 0.42)
const SANDBAG_DARK := Color(0.55, 0.48, 0.34)
const EARTH := Color(0.40, 0.33, 0.24)
const EARTH_DARK := Color(0.30, 0.25, 0.19)
const GRAVEL := Color(0.52, 0.50, 0.46)
const OLIVE := Color(0.36, 0.40, 0.24)
const METAL := Color(0.22, 0.22, 0.23)
const STEEL := Color(0.40, 0.41, 0.42)
const BLACK := Color(0.09, 0.09, 0.10)
const WHITE := Color(0.88, 0.87, 0.82)
const CREAM := Color(0.80, 0.76, 0.62)
const WINDOW := Color(0.20, 0.24, 0.28)        # glass by day (glow op: lit warm at night)
const DOOR := Color(0.30, 0.22, 0.15)
const RED := Color(0.62, 0.14, 0.11)
const COAL := Color(0.12, 0.12, 0.13)
const STRANGE := Color(0.35, 0.95, 0.85)       # the strange tech glow
const WIRE := Color(0.18, 0.18, 0.17)

static var _glow: StandardMaterial3D


static func material() -> StandardMaterial3D:
	return TrainParts.material()


static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.vertex_color_use_as_albedo = true
		_glow.vertex_color_is_srgb = true
		_glow.roughness = 0.4
		_glow.emission = Color(1.0, 0.72, 0.38)
		_glow.emission_energy_multiplier = 2.2
	return _glow


# ------------------------------------------------------------------ walls, windows, doors

## A plain rectangular block (walls) from the ground (or y0) up to h, half sizes hx, hz.
static func block(g: BGeo, c: Vector3, hx: float, hz: float, h: float, col: Color, y0 := 0.0) -> void:
	g.box(Vector3(c.x, y0 + h * 0.5, c.z), Vector3(hx, h * 0.5, hz), col)


## A raised floor or foundation plinth.
static func plinth(g: BGeo, c: Vector3, hx: float, hz: float, h: float, col: Color) -> void:
	var tr := g.tier
	g.tier = 0
	g.box(Vector3(c.x, h * 0.5, c.z), Vector3(hx, h * 0.5, hz), col)
	g.tier = tr


## A window on a wall face: at is the centre on the face, n the outward normal (axis aligned), w x h.
static func window(g: BGeo, at: Vector3, n: Vector3, w := 0.9, h := 1.1, frame := WHITE) -> void:
	var side := Vector3(-n.z, 0, n.x)
	var tr := g.tier
	var tg := g.tag
	g.tier = 3
	g.tag = "detail"
	var hx := Vector3(absf(side.x), 0, absf(side.z)) * (w * 0.5 + 0.08) + Vector3(absf(n.x), 0, absf(n.z)) * 0.05
	g.box(at + n * 0.02 + Vector3(0, -h * 0.5 - 0.06, 0), hx + Vector3(absf(n.x), 0, absf(n.z)) * 0.08 + Vector3(0, 0.05, 0), frame)
	g.box(at + n * 0.03 + Vector3(0, h * 0.5 + 0.05, 0), hx + Vector3(0, 0.05, 0), frame)
	g.tier = 1
	g.tag = "glow"
	g.box(at + n * 0.01, Vector3(absf(side.x), 0, absf(side.z)) * (w * 0.5) + Vector3(absf(n.x), 0, absf(n.z)) * 0.04 + Vector3(0, h * 0.5, 0), WINDOW)
	g.tier = 3
	g.tag = "detail"
	# glazing bars
	g.box(at + n * 0.05, Vector3(absf(side.x), 0, absf(side.z)) * 0.03 + Vector3(absf(n.x), 0, absf(n.z)) * 0.03 + Vector3(0, h * 0.5, 0), frame)
	g.box(at + n * 0.05, Vector3(absf(side.x), 0, absf(side.z)) * (w * 0.5) + Vector3(absf(n.x), 0, absf(n.z)) * 0.03 + Vector3(0, 0.03, 0), frame)
	g.tier = tr
	g.tag = tg


## A door on a wall face (bottom centre at at).
static func door(g: BGeo, at: Vector3, n: Vector3, w := 1.1, h := 2.1, col := DOOR) -> void:
	var side := Vector3(-n.z, 0, n.x)
	var tr := g.tier
	g.tier = 3
	var sx := Vector3(absf(side.x), 0, absf(side.z))
	var nx := Vector3(absf(n.x), 0, absf(n.z))
	g.box(at + n * 0.03 + Vector3(0, h * 0.5, 0), sx * (w * 0.5) + nx * 0.05 + Vector3(0, h * 0.5, 0), col)
	g.box(at + n * 0.05 + Vector3(0, h + 0.08, 0), sx * (w * 0.5 + 0.12) + nx * 0.07 + Vector3(0, 0.08, 0), TIMBER_DARK)
	g.tier = tr


## A row of windows along a face from a to b (both on the face), n outward.
static func windows(g: BGeo, a: Vector3, b: Vector3, n: Vector3, count: int, w := 0.9, h := 1.1, frame := WHITE) -> void:
	for k in count:
		var u := (float(k) + 0.5) / float(count)
		window(g, a.lerp(b, u), n, w, h, frame)


## A timber hut: plank walls on a low plinth, a gable roof (corrugated iron or tar paper), door on the
## front (-Z) and windows down both long sides. Long axis along x when along_x.
static func hut(g: BGeo, c: Vector3, hx: float, hz: float, wall_h: float, roof_col: Color, along_x := true,
		wall_col := PLANK, door_front := true, n_win := 3) -> void:
	plinth(g, c, hx + 0.15, hz + 0.15, 0.35, CONCRETE_DARK)
	g.tier = 1
	block(g, c, hx, hz, wall_h, wall_col, 0.35)
	# corner posts and a dark sill line
	g.tier = 3
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			g.box(c + Vector3(sx * hx, 0.35 + wall_h * 0.5, sz * hz), Vector3(0.1, wall_h * 0.5, 0.1), TIMBER_DARK)
	g.tier = 2
	var top := c + Vector3(0, 0.35 + wall_h, 0)
	g.gable(top, hx, hz, (hz if along_x else hx) * 0.55, roof_col, 0.35, along_x, wall_col.darkened(0.1))
	g.tier = 1
	var wy := 0.35 + wall_h * 0.58
	if along_x:
		for s: float in [-1.0, 1.0]:
			windows(g, c + Vector3(-hx * 0.8, wy, s * (hz + 0.01)), c + Vector3(hx * 0.8, wy, s * (hz + 0.01)), Vector3(0, 0, s), n_win)
		if door_front:
			door(g, c + Vector3(-hx - 0.01, 0.35, 0), Vector3(-1, 0, 0))
	else:
		for s: float in [-1.0, 1.0]:
			windows(g, c + Vector3(s * (hx + 0.01), wy, -hz * 0.8), c + Vector3(s * (hx + 0.01), wy, hz * 0.8), Vector3(s, 0, 0), n_win)
		if door_front:
			door(g, c + Vector3(0, 0.35, -hz - 0.01), Vector3(0, 0, -1))


## A low wall of sandbags from a to b, rows high (each row 0.28 m), as squashed lumps.
static func sandbags(g: BGeo, a: Vector3, b: Vector3, rows := 3, thick := 1) -> void:
	var tr := g.tier
	g.tier = 1
	var d := b - a
	var len := d.length()
	var dir := d / maxf(len, 0.01)
	var side := Vector3(-dir.z, 0, dir.x)
	var n := maxi(1, int(len / 0.62))
	var yaw := atan2(dir.x, dir.z)
	for r in rows:
		for k2 in thick:
			for k in n + (r % 2):
				var u := (float(k) + (0.0 if r % 2 == 0 else -0.5) + 0.5) / float(n)
				if u < 0.0 or u > 1.0:
					continue
				var p := a + d * u + side * ((float(k2) - float(thick - 1) * 0.5) * 0.42) + Vector3(0, 0.14 + float(r) * 0.26, 0)
				var col := SANDBAG if (k + r) % 3 != 0 else SANDBAG_DARK
				g.lump(p, 1.0, col, (Basis(Vector3.UP, yaw) * Vector3(0.22, 0.14, 0.34)).abs())
	g.tier = tr


## A chimney stack at the roof (bottom at the eaves at y0, to top y1). Returns the smoke point.
static func chimney(g: BGeo, at: Vector3, y0: float, y1: float, col := BRICK_DARK) -> Vector3:
	var tr := g.tier
	g.tier = 2
	g.box(Vector3(at.x, (y0 + y1) * 0.5, at.z), Vector3(0.32, (y1 - y0) * 0.5, 0.32), col)
	g.box(Vector3(at.x, y1 + 0.06, at.z), Vector3(0.38, 0.06, 0.38), col.darkened(0.2))
	g.tier = tr
	return Vector3(at.x, y1 + 0.3, at.z)


## A flagpole with a flag that waves (a moving part on the building).
static func flagpole(b: Building, at: Vector3, h := 9.0, col := Color(0.25, 0.32, 0.55)) -> void:
	var g := b.g
	var tr := g.tier
	g.tier = 3
	g.cyl(at, at + Vector3(0, h, 0), 0.06, 6, WHITE)
	g.lump(at + Vector3(0, h + 0.05, 0), 0.1, CREAM)
	g.tier = tr
	var fg := TrainGeo.new()
	# two panels so the wave bends it
	fg.box(Vector3(0.45, -0.45, 0), Vector3(0.45, 0.45, 0.02), col)
	fg.box(Vector3(0.45, -0.45, 0), Vector3(0.12, 0.45, 0.025), CREAM)
	var f1 := b.part_mesh("Flag", at + Vector3(0.05, h - 0.1, 0), fg)
	var fg2 := TrainGeo.new()
	fg2.box(Vector3(0.45, -0.45, 0), Vector3(0.45, 0.45, 0.02), col.darkened(0.08))
	var f2 := b.part_mesh("Flag2", Vector3(0.9, 0, 0), fg2)
	f2.reparent(f1, false)
	f2.position = Vector3(0.9, 0, 0)
	b.life.append({"type": "wave", "node": f1, "axis": Vector3(0, 1, 0), "amp": 0.35, "f": 1.7, "base": Vector3(0, -0.6, 0)})
	b.life.append({"type": "wave", "node": f2, "axis": Vector3(0, 1, 0), "amp": 0.5, "f": 2.3, "p": 1.0})


## A lamp on a bracket or post: the bulb is a glow op and an omni light on the building's switch.
static func lamp(b: Building, at: Vector3, post_h := 0.0, rng := 9.0) -> void:
	var g := b.g
	var tr := g.tier
	var tg := g.tag
	g.tier = 3
	if post_h > 0.0:
		g.cyl(at - Vector3(0, post_h, 0), at - Vector3(0, 0.2, 0), 0.06, 5, METAL)
	g.box(at + Vector3(0, 0.12, 0), Vector3(0.16, 0.04, 0.16), METAL)
	g.tag = "glow"
	g.box(at - Vector3(0, 0.05, 0), Vector3(0.1, 0.12, 0.1), Color(0.75, 0.72, 0.6))
	g.tier = tr
	g.tag = tg
	b.lamp(at - Vector3(0, 0.25, 0), Color(1.0, 0.78, 0.45), rng, 1.4)


## Corrugated iron: a slab with ribs (light lines across it).
static func iron_sheet(g: BGeo, c: Vector3, h: Vector3, col := IRON, b := Basis()) -> void:
	g.box(c, h, col, b)


# ------------------------------------------------------------------ construction and ruin looks

## The marked-out plot: dug brown ground inside the footprint, pegs at the corners, string lines.
static func plot(tg: TrainGeo, hs: Vector2) -> void:
	tg.box(Vector3(0, 0.03, 0), Vector3(hs.x * 0.9, 0.03, hs.y * 0.9), EARTH)
	for k in 6:
		var u := BGeo._h(k, 3) - 0.5
		var v := BGeo._h(k, 5) - 0.5
		tg.lump(Vector3(u * hs.x * 1.6, 0.1, v * hs.y * 1.6), 0.5, EARTH_DARK, Vector3(1.4, 0.4, 1.0))
	var c := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var a: Vector2 = c[i] * hs * 0.92
		var b: Vector2 = c[(i + 1) % 4] * hs * 0.92
		tg.box(Vector3(a.x, 0.45, a.y), Vector3(0.05, 0.45, 0.05), TIMBER_NEW)
		tg.cyl(Vector3(a.x, 0.8, a.y), Vector3(b.x, 0.8, b.y), 0.015, 3, WHITE)
	# a pile of planks and a barrow of bricks waiting
	for k in 5:
		tg.box(Vector3(-hs.x * 0.6, 0.08 + float(k) * 0.12, hs.y + 1.4), Vector3(1.8, 0.05, 0.14 + 0.02 * k), TIMBER_NEW, Basis(Vector3.UP, 0.05 * k))
	for k in 3:
		tg.box(Vector3(hs.x * 0.5, 0.2 + float(k) * 0.25, hs.y + 1.3), Vector3(0.6, 0.12, 0.3), BRICK)


## Scaffolding round the footprint up to top: poles, ledgers and plank decks every 2 m.
static func scaffold(tg: TrainGeo, rect: Array[float], top: float) -> void:
	var h := top + 0.8
	var off := 0.9
	var cx := rect[0]
	var cz := rect[1]
	var ax := rect[2] + off
	var az := rect[3] + off
	var nx := maxi(2, int(ax * 2.0 / 2.5))
	var nz := maxi(2, int(az * 2.0 / 2.5))
	var pts: Array[Vector2] = []
	for k in nx + 1:
		var x := -ax + float(k) * ax * 2.0 / float(nx)
		pts.append(Vector2(x, -az))
		pts.append(Vector2(x, az))
	for k in range(1, nz):
		var z := -az + float(k) * az * 2.0 / float(nz)
		pts.append(Vector2(-ax, z))
		pts.append(Vector2(ax, z))
	for p in pts:
		tg.cyl(Vector3(p.x + cx, 0, p.y + cz), Vector3(p.x + cx, h, p.y + cz), 0.05, 4, TIMBER_NEW)
	var levels := maxi(1, int(top / 2.0))
	for l in levels + 1:
		var y := minf(float(l) * 2.0 + 1.0, h - 0.2)
		for s: float in [-1.0, 1.0]:
			tg.cyl(Vector3(-ax + cx, y, s * az + cz), Vector3(ax + cx, y, s * az + cz), 0.04, 4, TIMBER_NEW)
			tg.cyl(Vector3(s * ax + cx, y, -az + cz), Vector3(s * ax + cx, y, az + cz), 0.04, 4, TIMBER_NEW)
			if l > 0:
				tg.box(Vector3(0 + cx, y + 0.05, s * (az - 0.35) + cz), Vector3(ax, 0.03, 0.35), PLANK)
				tg.box(Vector3(s * (ax - 0.35) + cx, y + 0.05, 0 + cz), Vector3(0.35, 0.03, az - 0.7), PLANK)
	# diagonal braces on the long faces
	for s: float in [-1.0, 1.0]:
		tg.cyl(Vector3(-ax + cx, 0, s * az + cz), Vector3(-ax + 3.0 + cx, minf(h, 4.0), s * az + cz), 0.04, 4, TIMBER_NEW)
		tg.cyl(Vector3(ax + cx, 0, s * az + cz), Vector3(ax - 3.0 + cx, minf(h, 4.0), s * az + cz), 0.04, 4, TIMBER_NEW)


## Broken stuff round a ruin: brick and plank rubble heaps.
static func rubble(tg: TrainGeo, hs: Vector2, seed_value: int) -> void:
	var n := int(hs.x * hs.y / 3.0) + 6
	for k in n:
		var u := BGeo._h(k, seed_value) - 0.5
		var v := BGeo._h(k, seed_value + 1) - 0.5
		var r := 0.4 + BGeo._h(k, seed_value + 2) * 0.9
		var col: Color = [BRICK_DARK, STONE_DARK, EARTH_DARK, TIMBER_DARK, CONCRETE_DARK][k % 5]
		tg.lump(Vector3(u * hs.x * 2.1, r * 0.25, v * hs.y * 2.1), r, col, Vector3(1.3, 0.55, 1.1))
	for k in 6:
		var u := BGeo._h(k, seed_value + 3) - 0.5
		var v := BGeo._h(k, seed_value + 4) - 0.5
		tg.box(Vector3(u * hs.x * 1.6, 0.3, v * hs.y * 1.6), Vector3(1.4, 0.06, 0.12), TIMBER_DARK,
			Basis(Vector3.UP, u * 6.0) * Basis(Vector3(0, 0, 1), 0.3 + v))


## A straight piece of track on the ground from a to b (ballast, sleepers, two rails), standard gauge.
static func track(g: BGeo, a: Vector3, b: Vector3) -> void:
	var tr := g.tier
	g.tier = 0
	var d := b - a
	var len := d.length()
	var dir := d / len
	var side := Vector3(-dir.z, 0, dir.x)
	var yaw := atan2(dir.x, dir.z)
	var bb := Basis(Vector3.UP, yaw)
	g.box((a + b) * 0.5 + Vector3(0, 0.08, 0), Vector3(1.6, 0.08, len * 0.5), GRAVEL, bb)
	var n := int(len / 0.7)
	for k in n:
		var p := a + dir * ((float(k) + 0.5) * len / float(n))
		g.box(p + Vector3(0, 0.2, 0), Vector3(1.25, 0.06, 0.12), TIMBER_DARK, bb)
	for s: float in [-1.0, 1.0]:
		g.box((a + b) * 0.5 + side * (s * 0.72) + Vector3(0, 0.31, 0), Vector3(0.04, 0.06, len * 0.5), STEEL, bb)
	g.tier = tr


## A simple open staff car as a prop mesh (front -Z), for the HQ.
static func staff_car() -> TrainGeo:
	var c := TrainGeo.new()
	var paint := Color(0.30, 0.33, 0.24)
	c.box(Vector3(0, 0.75, 0.3), Vector3(0.78, 0.32, 1.45), paint, Basis(), 0.08)
	c.box(Vector3(0, 0.82, -1.55), Vector3(0.5, 0.3, 0.6), paint, Basis(), 0.06)        # bonnet
	c.box(Vector3(0, 0.85, -2.17), Vector3(0.52, 0.34, 0.04), METAL)                   # radiator
	c.box(Vector3(0, 1.25, -0.85), Vector3(0.74, 0.22, 0.02), Color(0.6, 0.7, 0.75))   # screen
	for z: float in [-0.1, 1.0]:
		c.box(Vector3(0, 0.98, z), Vector3(0.7, 0.12, 0.35), Color(0.32, 0.2, 0.12))    # seats
		c.box(Vector3(0, 1.2, z + 0.33), Vector3(0.7, 0.25, 0.06), Color(0.32, 0.2, 0.12))
	for sx: float in [-1.0, 1.0]:
		for z: float in [-1.45, 1.25]:
			c.cyl(Vector3(sx * 0.72, 0.42, z), Vector3(sx * 0.88, 0.42, z), 0.42, 10, BLACK)
			c.cyl(Vector3(sx * 0.73, 0.42, z), Vector3(sx * 0.9, 0.42, z), 0.2, 8, STEEL)
			c.box(Vector3(sx * 0.8, 0.86, z), Vector3(0.14, 0.04, 0.5), paint)          # mudguards
		c.box(Vector3(sx * 0.82, 0.5, -0.1), Vector3(0.1, 0.03, 1.0), paint)            # running boards
		c.cyl(Vector3(sx * 0.4, 0.95, -2.15), Vector3(sx * 0.4, 0.95, -2.3), 0.12, 8, CREAM)  # lamps
	c.cyl(Vector3(0, 0.95, 1.8), Vector3(0, 0.95, 1.95), 0.4, 10, BLACK)                 # spare
	return c
