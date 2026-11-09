extends RefCounted
## Hand kit for the officer and the signallers, built in code in the faceted style
## (Question Chat, 2026-11-09). Generic pieces, not copies of real ones. Every piece
## is a static mesh in its own frame (turn it into a mesh with MG.mesh):
##   phone     the field telephone box; origin bottom centre, front toward -Z
##   crank     the phone's crank; origin on its axle (turns about X)
##   handset   origin at the grip, ear cup toward -X, mouthpiece toward +X
##   reel      the wire drum; origin on its axle (turns about X)
##   lamp      the signal lamp; origin at the handle grip, lens toward -Z
##   flag      origin at the hand on the pole, the pole up +Y, the cloth toward +X
##   map       the open map; origin at its centre, flat in XZ, read from +Z
##   binoculars origin between the eyepieces, looking toward -Z
##   whistle   origin at the mouthpiece, pointing -Z
##   magazine  origin at its top

const B := preload("res://scripts/units/soldier_builder.gd")

## Phone points (phone frame).
const CRANK_AXLE := Vector3(0.14, 0.075, 0.02)
const LID_HINGE := Vector3(0, 0.15, 0.09)
const HANDSET_REST := Vector3(0.0, 0.17, -0.03)
const TERMINAL := Vector3(-0.1, 0.12, -0.095)  # where the line wire clips on
const CORD_OUT := Vector3(0.06, 0.13, -0.09)
## Handset points.
const EAR := Vector3(-0.1, 0.0, 0.0)
const MOUTH := Vector3(0.1, -0.02, 0.0)
## Reel.
const REEL_R := 0.13
## Lamp.
const LENS := Vector3(0, -0.075, -0.1)
## Map (both hands hold the bottom corners).
const MAP_R := Vector3(0.2, 0.0, 0.13)
const MAP_L := Vector3(-0.2, 0.0, 0.13)

const WOOD := Color(0.47, 0.30, 0.17)
const WOOD_DARK := Color(0.33, 0.21, 0.12)
const BLACK := Color(0.08, 0.08, 0.09)
const STEEL := Color(0.21, 0.22, 0.21)
const BRASS := Color(0.70, 0.58, 0.30)
const OLIVE_PAINT := Color(0.34, 0.38, 0.23)
const CABLE := Color(0.12, 0.11, 0.10)
const CABLE_WOUND := Color(0.20, 0.18, 0.15)
const PAPER := Color(0.86, 0.82, 0.68)
const INK := Color(0.42, 0.36, 0.28)
const INK_BLUE := Color(0.38, 0.48, 0.62)
const INK_RED := Color(0.62, 0.22, 0.18)
const FLAG_RED := Color(0.78, 0.16, 0.12)
const FLAG_YELLOW := Color(0.92, 0.78, 0.18)
const GLASS := Color(0.75, 0.80, 0.70)


## The field phone. open: the lid, 0 shut .. 1 open (swung back on its hinge).
static func phone(open := 0.0) -> UnitGeo:
	var g := UnitGeo.new()
	# The box, its brass corners, the leather carry strap loops.
	g.box(Vector3(0, 0.07, 0), Vector3(0.13, 0.07, 0.09), WOOD, 0, Basis(), 0.15)
	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			g.box(Vector3(0.125 * sx, 0.015, 0.085 * sz), Vector3(0.01, 0.015, 0.01), BRASS, 0)
		g.box(Vector3(0.132 * sx, 0.1, 0.0), Vector3(0.004, 0.015, 0.03), B.LEATHER, 0)
	# Front panel: two terminals, a small bell plate.
	g.box(Vector3(0, 0.08, -0.092), Vector3(0.115, 0.055, 0.004), WOOD_DARK, 0)
	for k in 2:
		g.loft([Vector3(-0.1 + 0.04 * k, 0.12, -0.094), Vector3(-0.1 + 0.04 * k, 0.12, -0.11)],
			[Vector2(0.008, 0.008), Vector2(0.008, 0.008)], Vector3.RIGHT, 6, 0.0, BRASS, 0)
	g.loft([Vector3(0.05, 0.07, -0.094), Vector3(0.05, 0.07, -0.104)], [Vector2(0.035, 0.035), Vector2(0.03, 0.03)],
		Vector3.RIGHT, 8, 0.0, STEEL, 0)
	# The lid (hinged at the back top edge), with the handset cradle inside.
	var lid := Transform3D(Basis(Vector3.RIGHT, -1.9 * clampf(open, 0.0, 1.0)), LID_HINGE)
	var lg := UnitGeo.new()
	lg.box(Vector3(0, 0.0, -0.09), Vector3(0.132, 0.012, 0.092), WOOD, 0, Basis(), 0.15)
	lg.box(Vector3(0, -0.014, -0.09), Vector3(0.11, 0.003, 0.075), WOOD_DARK, 0)
	lg.box(Vector3(0, 0.014, -0.17), Vector3(0.025, 0.006, 0.008), BRASS, 0)  # catch
	_merge(g, lg, lid)
	return g


static func crank() -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	g.loft([Vector3(0, 0, 0), Vector3(0.025, 0, 0)], [Vector2(0.008, 0.008), Vector2(0.008, 0.008)], Vector3.UP, 6, 0.0, STEEL, 0)
	g.box(Vector3(0.028, 0.0, 0.03), Vector3(0.005, 0.008, 0.035), STEEL, 0)
	g.loft([Vector3(0.028, 0, 0.06), Vector3(0.06, 0, 0.06)], [Vector2(0.009, 0.009), Vector2(0.009, 0.009)], Vector3.UP, 6, 0.0,
		BLACK, 0)
	return g


static func handset() -> UnitGeo:
	var g := UnitGeo.new()
	var Y := Vector3.UP
	g.loft([Vector3(-0.08, 0, 0), Vector3(0.08, -0.01, 0)], [Vector2(0.014, 0.016), Vector2(0.014, 0.016)], Y, 6, 0.0, BLACK, 0)
	g.loft([Vector3(-0.085, 0, 0), Vector3(-0.1, 0.012, 0), Vector3(-0.11, 0.03, 0)],
		[Vector2(0.018, 0.018), Vector2(0.03, 0.03), Vector2(0.032, 0.032)], Vector3.FORWARD, 8, 0.0, BLACK, 0)
	g.loft([Vector3(0.085, -0.012, 0), Vector3(0.1, 0.0, 0), Vector3(0.11, 0.018, 0)],
		[Vector2(0.018, 0.018), Vector2(0.026, 0.026), Vector2(0.028, 0.028)], Vector3.FORWARD, 8, 0.0, BLACK, 0)
	return g


## The wire drum: two wooden cheeks and the wound line, a handle through the axle.
static func reel(full := 1.0) -> UnitGeo:
	var g := UnitGeo.new()
	var Y := Vector3.UP
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(0.085 * s, 0, 0), Vector3(0.1 * s, 0, 0)], [Vector2(REEL_R, REEL_R), Vector2(REEL_R, REEL_R)],
			Y, 10, 0.0, WOOD, 0)
		g.box(Vector3(0.1 * s, 0, 0), Vector3(0.004, REEL_R * 0.9, 0.012), WOOD_DARK, 0)  # a spoke: shows it turning
	var r := lerpf(0.05, 0.115, clampf(full, 0.0, 1.0))
	g.loft([Vector3(-0.085, 0, 0), Vector3(0.085, 0, 0)], [Vector2(r, r), Vector2(r, r)], Y, 10, 0.0, CABLE_WOUND, 0)
	g.loft([Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)], Y, 6, 0.0, STEEL, 0)
	return g


## Field wire along points (laid on the ground, or hanging from the drum).
static func wire(points: PackedVector3Array, r := 0.006) -> UnitGeo:
	var g := UnitGeo.new()
	if points.size() < 2:
		return g
	var sz: Array = []
	var cs: Array = []
	for p in points:
		cs.append(p)
		sz.append(Vector2(r, r))
	g.loft(cs, sz, Vector3.UP, 4, 0.0, CABLE, 0)
	return g


## The signal lamp: a box with the lens forward, a sighting tube on top, a handle.
static func lamp() -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	g.box(Vector3(0, -0.075, 0.0), Vector3(0.06, 0.07, 0.09), OLIVE_PAINT, 0, Basis(), 0.15)
	g.loft([Vector3(0, -0.075, -0.09), Vector3(0, -0.075, -0.11)], [Vector2(0.055, 0.055), Vector2(0.058, 0.058)],
		X, 10, 0.0, STEEL, 0)
	g.loft([Vector3(0, -0.075, -0.11), Vector3(0, -0.075, -0.112)], [Vector2(0.045, 0.045), Vector2(0.045, 0.045)],
		X, 10, 0.0, GLASS, 0)
	g.loft([Vector3(0, 0.005, 0.07), Vector3(0, 0.005, -0.08)], [Vector2(0.011, 0.011), Vector2(0.011, 0.011)], X, 6, 0.0,
		STEEL, 0)
	# The handle across the top (the hand holds it at the origin).
	g.box(Vector3(0, 0.0, 0.0), Vector3(0.012, 0.012, 0.05), BLACK, 0)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0, -0.005, 0.05 * s), Vector3(0.01, 0.012, 0.006), STEEL, 0)
	# The shutter key at the side.
	g.box(Vector3(0.068, -0.05, 0.03), Vector3(0.008, 0.02, 0.012), BRASS, 0)
	return g


## A semaphore-style hand flag, cut corner to corner in two colours.
static func flag() -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(0, -0.12, 0), Vector3(0, 0.52, 0)], [Vector2(0.01, 0.01), Vector2(0.009, 0.009)],
		Vector3.RIGHT, 6, 0.0, WOOD, 0)
	var a := Vector3(0.01, 0.52, 0)
	var b := Vector3(0.39, 0.52, 0)
	var c := Vector3(0.39, 0.14, 0)
	var d := Vector3(0.01, 0.14, 0)
	for side: float in [0.004, -0.004]:
		var o := Vector3(0, 0, side)
		_tri2(g, a + o, b + o, c + o, FLAG_RED)
		_tri2(g, a + o, c + o, d + o, FLAG_YELLOW)
	return g


static func map_sheet() -> UnitGeo:
	var g := UnitGeo.new()
	g.box(Vector3(0, 0, 0), Vector3(0.21, 0.002, 0.15), PAPER, 0)
	# Fold lines, a road, a river, contour marks, a red front line.
	for k in [-1, 1]:
		g.box(Vector3(0.07 * k, 0.003, 0), Vector3(0.002, 0.001, 0.15), PAPER.darkened(0.15), 0)
	g.box(Vector3(-0.02, 0.003, 0.02), Vector3(0.18, 0.001, 0.004), INK, 0, Basis(Vector3.UP, 0.3))
	g.box(Vector3(0.05, 0.003, -0.05), Vector3(0.006, 0.001, 0.13), INK_BLUE, 0, Basis(Vector3.UP, -0.5))
	g.box(Vector3(0.0, 0.003, -0.08), Vector3(0.17, 0.001, 0.004), INK_RED, 0, Basis(Vector3.UP, 0.08))
	for k in 4:
		g.box(Vector3(-0.12 + 0.03 * k, 0.003, 0.08 - 0.02 * k), Vector3(0.025, 0.001, 0.002), INK.lightened(0.3), 0)
	return g


static func binoculars() -> UnitGeo:
	var g := UnitGeo.new()
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(0.032 * s, 0, 0.0), Vector3(0.032 * s, 0, -0.06), Vector3(0.036 * s, 0.006, -0.13)],
			[Vector2(0.016, 0.016), Vector2(0.022, 0.022), Vector2(0.026, 0.026)], Vector3.RIGHT, 8, 0.0, BLACK, 0)
	g.box(Vector3(0, 0, -0.05), Vector3(0.025, 0.01, 0.015), STEEL, 0)
	return g


static func whistle() -> UnitGeo:
	var g := UnitGeo.new()
	g.loft([Vector3(0, 0, 0), Vector3(0, 0, 0.03), Vector3(0, -0.005, 0.05)],
		[Vector2(0.006, 0.004), Vector2(0.01, 0.01), Vector2(0.012, 0.012)], Vector3.RIGHT, 6, 0.0, BRASS, 0)
	g.loft([Vector3(-0.012, -0.005, 0.05), Vector3(0.012, -0.005, 0.05)], [Vector2(0.013, 0.013), Vector2(0.013, 0.013)],
		Vector3.UP, 8, 0.0, BRASS, 0)
	return g


static func magazine() -> UnitGeo:
	var g := UnitGeo.new()
	g.box(Vector3(0, -0.045, 0), Vector3(0.01, 0.045, 0.016), STEEL, 0)
	return g


static func _tri2(g: UnitGeo, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	g.emit(a, b, c, col, 0)
	g.emit(a, c, b, col, 0)


## Adds piece p to g, moved by xf.
static func _merge(g: UnitGeo, p: UnitGeo, xf: Transform3D) -> void:
	for i in range(0, p.pos.size(), 3):
		g.emit(xf * p.pos[i], xf * p.pos[i + 2], xf * p.pos[i + 1], p.col[i], 0)  # emit stores a, c, b
