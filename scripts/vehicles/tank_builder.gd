extends RefCounted
## The tanks, built in code in the faceted unit style (Tanks Chat, 2026-11-09).
## Two generic WW1-era kinds, not copies of real ones, at true size, plain olive:
##   heavy  a rhomboid tank: the track runs right round a tall side frame, a sponson on each
##          side, a driver's cab at the front, an unditching beam on rails, a fascine bundle
##          and a two-wheel steering tail. "heavy_male" has a short gun in each sponson,
##          "heavy_female" a machine gun. Crew of 8. About 8.3 m long (10 m with the tail).
##   light  a small turret tank: running gear with a big front idler, a turret that turns
##          right round, a tail skid. "light_gun" has a short gun, "light_mg" a machine gun.
##          Crew of 2. About 5 m long with the skid.
##
## Tank frame: forward is -Z, right is +X, the ground at y = 0, the origin on the ground
## under the middle of the tank. Pieces are separate so they can move:
##   hull     everything rigid (frames, body, cab, sponsons, gear on the roof)
##   track    one side's track loop, centred on x = 0 (placed at +-TRACK_X); scrolls by phase
##   wheel    origin on its hub, turning about X
##   turret / gun / barrel, sponson guns, hatches and doors, the tail
## lod 0 close, 1 mid, 2 far. wreck = burnt out.

const PAINT := Color(0.36, 0.39, 0.25)
const PAINT_DARK := Color(0.28, 0.31, 0.19)
const PAINT_LIGHT := Color(0.42, 0.44, 0.30)
const STEEL := Color(0.19, 0.19, 0.18)
const TRACK_A := Color(0.21, 0.19, 0.16)
const TRACK_B := Color(0.27, 0.23, 0.18)
const WOOD := Color(0.47, 0.35, 0.21)
const BRUSH := Color(0.46, 0.38, 0.22)
const BRUSH_DARK := Color(0.36, 0.29, 0.16)
const GLASS := Color(0.06, 0.06, 0.06)
const MARK := Color(0.86, 0.84, 0.75)
const MARK_RED := Color(0.62, 0.16, 0.12)
const BRASS := Color(0.66, 0.55, 0.30)
const CHAR := Color(0.13, 0.12, 0.11)
const CHAR_BROWN := Color(0.22, 0.15, 0.10)
const RUST := Color(0.38, 0.21, 0.11)
const ASH := Color(0.30, 0.29, 0.27)

# ---------------------------------------------------------------- heavy numbers
const H_TRACK_X := 1.35  # track centre line, either side
const H_TRACK_HW := 0.3
const H_THICK := 0.1
const H_PITCH := 0.34
const H_FRAME_IN := 1.03  # frame plates run from x = 1.03 to 1.67
const H_FRAME_OUT := 1.67
const H_ROOF := 2.3
const H_ROOF_HATCH := Vector3(0, 2.33, 0.75)  # hinge (rear edge) of the roof hatch
const H_SPON_GUN := Vector3(2.08, 1.36, -0.84)  # right sponson gun pivot (x mirrors)
const H_FRONT_MG := Vector3(0.45, 2.58, -3.62)
const H_DOOR_HINGE := Vector3(2.22, 0.78, 0.72)  # right sponson door, outer hinge at its foot
const H_DOOR_END := Vector3(1.95, 0.78, 1.18)  # the door's other edge
const H_DOOR_H := 0.98
const H_SPON_FLOOR := 0.74
const H_TAIL_PIVOT := Vector3(0, 1.15, 3.7)  # hull frame
const H_TAIL_LEN := 1.9
const H_TAIL_R := 0.62
const H_TAIL_X := 0.55
const H_EXHAUST := Vector3(0.55, 2.86, 3.45)
const H_COM := Vector3(0, 1.1, 0.2)

# ---------------------------------------------------------------- light numbers
const L_TRACK_X := 0.68
const L_TRACK_HW := 0.16
const L_THICK := 0.06
const L_PITCH := 0.2
const L_TURRET := Vector3(0, 1.5, -0.45)
const L_GUN := Vector3(0, 0.33, -0.5)  # turret frame: the gun's elevation pivot
const L_HATCH := Vector3(0, 0.84, 0.16)  # turret frame: cupola lid hinge (rear edge)
const L_DRIVER_HINGE := Vector3(0, 1.47, -1.36)  # top edge of the driver's hatch
const L_EXHAUST := Vector3(-0.42, 1.3, 1.95)
const L_COM := Vector3(0, 0.85, -0.1)
const L_WHEEL_R := 0.14
const L_IDLER := Vector2(-1.72, 0.62)
const L_IDLER_R := 0.4
const L_SPROCKET := Vector2(1.8, 0.52)
const L_SPROCKET_R := 0.32


static func is_heavy(kind: String) -> bool:
	return kind.begins_with("heavy")


static func _palette(wreck: bool) -> Dictionary:
	if not wreck:
		return {"paint": PAINT, "dark": PAINT_DARK, "light": PAINT_LIGHT, "steel": STEEL, "ta": TRACK_A, "tb": TRACK_B,
			"wood": WOOD, "brush": BRUSH, "brush_dark": BRUSH_DARK, "glass": GLASS, "mark": MARK, "red": MARK_RED,
			"brass": BRASS}
	return {"paint": CHAR_BROWN, "dark": CHAR, "light": ASH, "steel": CHAR, "ta": CHAR, "tb": Color(0.27, 0.17, 0.11), "wood": CHAR,
		"brush": ASH, "brush_dark": CHAR, "glass": CHAR, "mark": ASH, "red": CHAR_BROWN, "brass": RUST}


## Colour for one part of a wreck: rust and char patches picked by a hash of the spot.
static func _w(c: Color, wreck: bool, at: Vector3) -> Color:
	if not wreck:
		return c
	var h := absf(sin(at.x * 12.9898 + at.y * 78.233 + at.z * 37.719) * 43758.5453)
	h -= floorf(h)
	if h < 0.3:
		return RUST
	if h < 0.55:
		return CHAR_BROWN
	return c


# ---------------------------------------------------------------- shape helpers

## A triangle facing along n.
static func tri_n(g: UnitGeo, a: Vector3, b: Vector3, c: Vector3, col: Color, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) < 0.0:
		g.emit(a, c, b, col, 0)
	else:
		g.emit(a, b, c, col, 0)


static func quad_n(g: UnitGeo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, n: Vector3) -> void:
	tri_n(g, a, b, c, col, n)
	tri_n(g, a, c, d, col, n)


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		s += p.x * q.y - q.x * p.y
	return s * 0.5


## A flat 2D outline pushed out along w from w0 to w1. A point p of the outline sits at
## u * p.x + v * p.y. cols: one colour, or [side colour, cap colour].
static func prism(g: UnitGeo, poly: PackedVector2Array, u: Vector3, v: Vector3, w: Vector3, w0: float, w1: float,
		col: Color, cap: Variant = null) -> void:
	var cap_col: Color = col if cap == null else cap
	var sgn := 1.0 if _area(poly) > 0.0 else -1.0
	var n := poly.size()
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		var e := q - p
		var n2 := Vector2(e.y, -e.x) * sgn
		var n3 := u * n2.x + v * n2.y
		quad_n(g, u * p.x + v * p.y + w * w0, u * q.x + v * q.y + w * w0, u * q.x + v * q.y + w * w1,
			u * p.x + v * p.y + w * w1, col, n3)
	var idx := Geometry2D.triangulate_polygon(poly)
	var dn := w * signf(w1 - w0)
	for k in range(0, idx.size(), 3):
		var a := poly[idx[k]]
		var b := poly[idx[k + 1]]
		var c := poly[idx[k + 2]]
		tri_n(g, u * a.x + v * a.y + w * w0, u * b.x + v * b.y + w * w0, u * c.x + v * c.y + w * w0, cap_col, -dn)
		tri_n(g, u * a.x + v * a.y + w * w1, u * b.x + v * b.y + w * w1, u * c.x + v * c.y + w * w1, cap_col, dn)


## The outline round a set of circles ([[Vector2 centre, radius], ...]) in the (z, y) plane.
static func outline(circles: Array, per := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c: Array in circles:
		var r: float = c[1]
		for k in per:
			var a := TAU * float(k) / float(per)
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * r)
	var h := Geometry2D.convex_hull(pts)
	if h.size() > 1 and h[0].is_equal_approx(h[h.size() - 1]):
		h.remove_at(h.size() - 1)
	return h


static func inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var r := Geometry2D.offset_polygon(poly, -d)
	return r[0] if not r.is_empty() else poly


## Drops the extra corner points offset_polygon adds (for far looks).
static func _coarse(poly: PackedVector2Array) -> PackedVector2Array:
	var h := Geometry2D.convex_hull(poly)
	if h.size() > 1 and h[0].is_equal_approx(h[h.size() - 1]):
		h.remove_at(h.size() - 1)
	var out := PackedVector2Array()
	for p in h:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.12:
			out.append(p)
	return out


## Cumulative lengths of a closed outline (first entry 0, last = perimeter).
static func _lengths(poly: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0])
	for i in poly.size():
		out.append(out[i] + poly[i].distance_to(poly[(i + 1) % poly.size()]))
	return out


## Point and unit tangent at arc length s along a closed outline.
static func _along(poly: PackedVector2Array, lens: PackedFloat32Array, s: float) -> Array:
	var per := lens[lens.size() - 1]
	s = fposmod(s, per)
	var i := 0
	while i < poly.size() - 1 and lens[i + 1] < s:
		i += 1
	var p := poly[i]
	var q := poly[(i + 1) % poly.size()]
	var seg := lens[i + 1] - lens[i]
	var u := 0.0 if seg <= 0.0 else (s - lens[i]) / seg
	return [p.lerp(q, u), (q - p).normalized()]


static func zy(p: Vector2, x := 0.0) -> Vector3:
	return Vector3(x, p.y, p.x)


## Block digits (seven segments) painted on a face: origin = bottom left of the first digit,
## right/up = directions on the face, out = its outward normal, h = digit height.
static func digits(g: UnitGeo, text: String, origin: Vector3, right: Vector3, up: Vector3, out: Vector3, h: float, col: Color) -> void:
	const SEG := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc",
		"7": "abc", "8": "abcdefg", "9": "abcdfg"}
	var w := h * 0.55
	var t := h * 0.13
	var b := Basis(right, out, up)
	for i in text.length():
		var segs: String = SEG.get(text[i], "")
		var o := origin + right * (w + h * 0.22) * float(i) + out * 0.006
		for sg in segs:
			var c: Vector2
			var hs: Vector2
			match sg:
				"a": c = Vector2(w * 0.5, h); hs = Vector2(w * 0.5, t * 0.5)
				"g": c = Vector2(w * 0.5, h * 0.5); hs = Vector2(w * 0.5, t * 0.5)
				"d": c = Vector2(w * 0.5, 0.0); hs = Vector2(w * 0.5, t * 0.5)
				"b": c = Vector2(w, h * 0.75); hs = Vector2(t * 0.5, h * 0.25)
				"c": c = Vector2(w, h * 0.25); hs = Vector2(t * 0.5, h * 0.25)
				"f": c = Vector2(0.0, h * 0.75); hs = Vector2(t * 0.5, h * 0.25)
				"e": c = Vector2(0.0, h * 0.25); hs = Vector2(t * 0.5, h * 0.25)
			g.box(o + right * c.x + up * c.y, Vector3(hs.x, 0.004, hs.y), col, 0, b)


## The tactical sign: a white diamond with a red bar across it.
static func sign_mark(g: UnitGeo, at: Vector3, right: Vector3, up: Vector3, out: Vector3, s: float, p: Dictionary) -> void:
	var o := at + out * 0.006
	var pts := [o + up * s, o + right * s, o - up * s, o - right * s]
	quad_n(g, pts[0], pts[1], pts[2], pts[3], p["mark"], out)
	g.box(o + out * 0.004, Vector3(s * 0.62, 0.004, s * 0.12), p["red"], 0, Basis(right, out, up))


## A spoked wheel on its hub (axis X): rim, spokes, hub; teeth for a sprocket.
static func spoke_wheel(r: float, hw: float, spokes: int, lod: int, wreck: bool, teeth := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var n := 12 if lod == 0 else 6
	g.loft([Vector3(-hw, 0, 0), Vector3(hw, 0, 0)], [Vector2(r, r), Vector2(r, r)], Vector3.UP, n, 0.0, p["steel"], 0)
	if lod == 0:
		g.loft([Vector3(-hw - 0.01, 0, 0), Vector3(hw + 0.01, 0, 0)], [Vector2(r * 0.32, r * 0.32), Vector2(r * 0.32, r * 0.32)],
			Vector3.UP, 8, 0.0, p["dark"], 0)
		for k in spokes:
			var a := TAU * float(k) / float(spokes)
			var b := Basis(Vector3.RIGHT, a)
			g.box(b * Vector3(hw + 0.006, r * 0.6, 0), Vector3(0.006, r * 0.3, r * 0.09), p["paint"], 0, b)
			g.box(b * Vector3(-hw - 0.006, r * 0.6, 0), Vector3(0.006, r * 0.3, r * 0.09), p["paint"], 0, b)
		for k in teeth:
			var a := TAU * (float(k) + 0.5) / float(teeth)
			var b := Basis(Vector3.RIGHT, a)
			g.box(b * Vector3(0, r + 0.03, 0), Vector3(hw * 0.6, 0.035, 0.03), p["steel"], 0, b)
	return g


# ---------------------------------------------------------------- the track loops

## Outer outline of the track (the ground contact side), in the (z, y) plane.
static func track_outline(kind: String, coarse := false) -> PackedVector2Array:
	if is_heavy(kind):
		return outline([[Vector2(-3.75, 1.75), 0.7], [Vector2(-2.8, 0.55), 0.55], [Vector2(2.9, 0.55), 0.55],
			[Vector2(3.35, 1.95), 0.5]], 6 if coarse else 24)
	return outline([[L_IDLER, L_IDLER_R + L_THICK], [Vector2(-1.15, 0.2), 0.2], [Vector2(1.3, 0.2), 0.2],
		[L_SPROCKET, L_SPROCKET_R + L_THICK]], 6 if coarse else 20)


## Points the tank rests on (the outline's lower half plus the tail skid), (z, y).
static func contact(kind: String) -> PackedVector2Array:
	var o := track_outline(kind)
	var out := PackedVector2Array()
	for p in o:
		if p.y < (1.3 if is_heavy(kind) else 0.75):
			out.append(p)
	if not is_heavy(kind):
		out.append(Vector2(3.12, 0.24))
		out.append(Vector2(2.9, 0.33))
	return out


## Track loop for one side (centred on x = 0), its links moved on by phase (0..1 of a link).
## broken: a run of links missing (a wreck's broken track).
static func track(kind: String, lod: int, phase: float, wreck := false, broken := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var heavy := is_heavy(kind)
	var o := track_outline(kind, lod >= 2)
	var hw: float = H_TRACK_HW if heavy else L_TRACK_HW
	var th: float = H_THICK if heavy else L_THICK
	if lod >= 2:
		# Far: a plain band round the outline.
		prism(g, o, Vector3.BACK, Vector3.UP, Vector3.RIGHT, -hw, hw, p["ta"])
		return g
	var lens := _lengths(o)
	var per := lens[lens.size() - 1]
	var pitch0: float = (H_PITCH if heavy else L_PITCH) * (1.0 if lod == 0 else 2.0)
	var nl := maxi(8, int(round(per / pitch0)))
	var pitch := per / float(nl)
	# Which way the links run when driving forward: backwards (+z) along the bottom.
	var lowest := 0
	for i in o.size():
		if o[i].y < o[lowest].y - 1e-4 or (absf(o[i].y - o[lowest].y) < 1e-4 and absf(o[i].x) < absf(o[lowest].x)):
			lowest = i
	var dir := 1.0 if (o[(lowest + 1) % o.size()] - o[lowest]).x > 0.0 else -1.0
	var sgn := 1.0 if _area(o) > 0.0 else -1.0
	for k in nl:
		var s := (float(k) + phase * dir) * pitch
		if broken and fposmod(s, per) > per * 0.08 and fposmod(s, per) < per * 0.2:
			continue
		var at: Array = _along(o, lens, s)
		var pt: Vector2 = at[0]
		var tg: Vector2 = at[1]
		var n2 := Vector2(tg.y, -tg.x) * sgn
		var n3 := zy(n2)
		var t3 := zy(tg)
		var b := Basis(Vector3.RIGHT, n3, t3)
		var col: Color = p["ta"] if k % 2 == 0 else p["tb"]
		g.box(zy(pt) - n3 * th * 0.5, Vector3(hw, th * 0.5, pitch * 0.43), col, 0, b)
		if lod == 0:
			g.box(zy(pt) + n3 * 0.006, Vector3(hw * 0.92, 0.014, pitch * 0.12), p["steel"], 0, b)
	return g


# ---------------------------------------------------------------- heavy hull

static func _heavy_hull(g: UnitGeo, kind: String, lod: int, wreck: bool, p: Dictionary) -> void:
	var d0 := lod == 0
	var male := kind == "heavy_male"
	var Z := Vector3.BACK
	var Y := Vector3.UP
	var X := Vector3.RIGHT
	var o := track_outline(kind, lod >= 2)
	var plate := inset(o, H_THICK + 0.05)
	if lod >= 2:
		plate = _coarse(plate)
	var body_poly := PackedVector2Array([Vector2(-3.4, 0.55), Vector2(-3.58, 1.5), Vector2(-3.42, H_ROOF),
		Vector2(3.5, H_ROOF), Vector2(3.68, 1.25), Vector2(3.35, 0.55)])
	if lod >= 2:
		for s: float in [1.0, -1.0]:
			prism(g, plate, Z, Y, X, s * (H_FRAME_IN + 0.02), s * (H_FRAME_OUT - 0.02), p["paint"])
			g.box(Vector3(s * 1.95, 1.35, -0.1), Vector3(0.3, 0.6, 1.1), p["paint"], 0)
		prism(g, body_poly, Z, Y, X, -H_FRAME_IN, H_FRAME_IN, p["dark"])
		g.box(Vector3(0, 2.6, -2.95), Vector3(0.9, 0.32, 0.6), p["paint"], 0)
		return
	# The side frames: tall plates the track runs round.
	for s: float in [1.0, -1.0]:
		var fc := _w(p["paint"], wreck, Vector3(s, 1.3, 0.4))
		prism(g, plate, Z, Y, X, s * H_FRAME_IN, s * H_FRAME_OUT, fc, p["dark"] if d0 else null)
		if d0:
			# A raised strip along the outer plate and the mud chutes along the bottom.
			var strip := inset(plate, 0.22)
			for i in strip.size():
				var a := strip[i]
				var b := strip[(i + 1) % strip.size()]
				if a.y > 0.9 and b.y > 0.9:
					continue
				var mid := (a + b) * 0.5
				var e := (b - a)
				g.box(zy(mid, s * (H_FRAME_OUT + 0.01)), Vector3(0.012, 0.03, e.length() * 0.5), p["dark"], 0,
					Basis(X, Vector3(0, e.normalized().x, -e.normalized().y), zy(e.normalized())))
			for k in 6:
				g.box(Vector3(s * (H_FRAME_OUT + 0.004), 0.42, -2.0 + 0.8 * k), Vector3(0.006, 0.09, 0.16), p["steel"], 0)
	# The body between the frames, the front plate, the cab.
	prism(g, body_poly, Z, Y, X, -H_FRAME_IN, H_FRAME_IN, _w(p["paint"], wreck, Vector3(0, 2, 0)))
	var cab := PackedVector2Array([Vector2(-3.62, 2.25), Vector2(-3.5, 2.95), Vector2(-2.35, 2.95), Vector2(-2.3, 2.25)])
	prism(g, cab, Z, Y, X, -0.95, 0.95, _w(p["paint"], wreck, Vector3(0, 2.7, -3)))
	# Vision slits and visors on the cab front and sides.
	for x in [-0.45, 0.0]:
		g.box(Vector3(x, 2.66, -3.585), Vector3(0.16, 0.025, 0.02), p["glass"], 0)
		if d0:
			g.box(Vector3(x, 2.72, -3.6), Vector3(0.2, 0.03, 0.03), p["dark"], 0, Basis(), 0.3)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(s * 0.955, 2.62, -2.9), Vector3(0.012, 0.022, 0.14), p["glass"], 0)
	# Front MG in a ball mount (both versions).
	var bm := H_FRONT_MG
	g.loft([bm + Vector3(0, 0, 0.08), bm + Vector3(0, 0, -0.06)], [Vector2(0.12, 0.12), Vector2(0.1, 0.1)], Y, 8 if d0 else 5, 0.0,
		p["dark"], 0)
	g.loft([bm + Vector3(0, 0, -0.06), bm + Vector3(0, 0, -0.55)], [Vector2(0.045, 0.045), Vector2(0.045, 0.045)], Y, 6, 0.0,
		p["steel"], 0)
	# Roof: the hatch coaming, a vent, the exhaust stack running back.
	g.box(Vector3(0, H_ROOF + 0.02, H_ROOF_HATCH.z - 0.36), Vector3(0.42, 0.03, 0.42), p["dark"], 0)
	if d0:
		g.box(Vector3(-0.5, H_ROOF + 0.08, 1.8), Vector3(0.22, 0.08, 0.3), p["dark"], 0, Basis(), 0.3)
		for k in 4:
			g.box(Vector3(-0.5, H_ROOF + 0.165, 1.58 + 0.15 * k), Vector3(0.2, 0.006, 0.03), p["steel"], 0)
	var ex := H_EXHAUST
	g.loft([Vector3(ex.x, H_ROOF, 1.5), Vector3(ex.x, ex.y - 0.06, 1.55), Vector3(ex.x, ex.y - 0.06, ex.z - 0.05)],
		[Vector2(0.07, 0.07), Vector2(0.07, 0.07), Vector2(0.07, 0.07)], Vector3.RIGHT, 6, 0.0, p["steel"], 0)
	if d0:
		g.loft([Vector3(ex.x, ex.y - 0.06, 2.1), Vector3(ex.x, ex.y - 0.06, 3.0)], [Vector2(0.12, 0.12), Vector2(0.12, 0.12)],
			Vector3.UP, 8, 0.0, p["dark"], 0)
	# Rear: a towing eye, the tail mounting.
	g.box(Vector3(0, 1.15, 3.66), Vector3(0.7, 0.12, 0.08), p["steel"], 0)
	# Unditching rails, the beam resting on them, its chains.
	for s: float in [1.0, -1.0]:
		g.box(Vector3(s * 0.98, 2.64, 1.35), Vector3(0.05, 0.05, 2.0), p["steel"], 0)
		for z in [-0.4, 1.4, 3.2]:
			g.box(Vector3(s * 0.98, (H_ROOF + 2.6) * 0.5, z), Vector3(0.04, (2.6 - H_ROOF) * 0.5, 0.04), p["steel"], 0)
	var beam_z := 3.05
	if not wreck:
		g.box(Vector3(0, 2.86, beam_z), Vector3(1.62, 0.17, 0.17), p["wood"], 0, Basis(), 0.25 if d0 else 0.0)
		if d0:
			for s: float in [1.0, -1.0]:
				g.box(Vector3(s * 1.2, 2.86, beam_z), Vector3(0.02, 0.19, 0.19), p["steel"], 0)
	# The fascine: a bundle of brushwood across the roof behind the cab, chained down.
	if not wreck:
		var fz := -1.55
		var fy := 2.55 + 0.62
		g.loft([Vector3(-1.5, fy, fz), Vector3(1.5, fy, fz)], [Vector2(0.62, 0.62), Vector2(0.62, 0.62)], Vector3.UP,
			12 if d0 else 6, 0.0, p["brush"], 0, p["brush_dark"] if d0 else null)
		if d0:
			for x in [-1.0, 0.0, 1.0]:
				g.loft([Vector3(x - 0.03, fy, fz), Vector3(x + 0.03, fy, fz)], [Vector2(0.64, 0.64), Vector2(0.64, 0.64)],
					Vector3.UP, 12, 0.0, p["steel"], 0)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for s: float in [1.0, -1.0]:
				for k in 9:
					var a := rng.randf() * TAU
					var r := rng.randf_range(0.05, 0.5)
					g.box(Vector3(s * (1.52 + rng.randf_range(0.0, 0.1)), fy + sin(a) * r, fz + cos(a) * r),
						Vector3(0.09, 0.02, 0.02), p["brush_dark"], 0, Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)))
	# Sponsons.
	for s: float in [1.0, -1.0]:
		var u := Vector3(s, 0, 0)
		var sp := PackedVector2Array([Vector2(1.66, -1.35), Vector2(2.05, -1.08), Vector2(2.22, -0.6), Vector2(2.22, 0.72),
			Vector2(1.95, 1.18), Vector2(1.66, 1.18)])
		var y0 := 0.72 if male else 0.6
		var y1 := 1.95 if male else 2.02
		prism(g, sp, u, Z, Y, y0, y1, _w(p["paint"], wreck, Vector3(s * 2, 1.4, 0)), p["dark"] if d0 else null)
		if d0:
			# A lip round the top, pistol ports, a vision slit.
			g.box(Vector3(s * 2.0, y1 + 0.02, 0.0), Vector3(0.24, 0.02, 1.05), p["dark"], 0)
			for z in [-0.2, 0.35]:
				g.loft([Vector3(s * 2.22, 1.42, z), Vector3(s * 2.235, 1.42, z)], [Vector2(0.045, 0.045), Vector2(0.045, 0.045)],
					Vector3.UP, 6, 0.0, p["glass"], 0)
		if not male:
			# The MG ball's housing on the sponson front.
			g.box(Vector3(s * 2.1, 1.36, -0.92), Vector3(0.16, 0.2, 0.08), p["dark"], 0, Basis(Vector3.UP, s * 0.55))
	# Markings: the number on each side of the frames, the sign on the cab front and the rear.
	for s: float in [1.0, -1.0]:
		var out := Vector3(s, 0, 0)
		var right := Vector3(0, 0, -s)
		var num := "214" if male else "209"
		var w := 0.38 * (0.55 + 0.22)
		var start := Vector3(s * (H_FRAME_OUT + 0.002), 1.45, 2.3 + s * w * 1.5)
		digits(g, num, start, right, Vector3.UP, out, 0.38, p["mark"])
		sign_mark(g, Vector3(s * (H_FRAME_OUT + 0.002), 1.65, -1.9), right, Vector3.UP, out, 0.2, p)
	sign_mark(g, Vector3(0.5, 2.48, -3.61), Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1), 0.13, p)
	if wreck:
		# Scorch round the hit, a hole in the left frame.
		g.loft([Vector3(-H_FRAME_OUT - 0.01, 1.2, -0.6), Vector3(-H_FRAME_OUT - 0.02, 1.2, -0.6)], [Vector2(0.3, 0.26), Vector2(0.3, 0.26)],
			Vector3.UP, 8, 0.0, CHAR, 0)
		g.loft([Vector3(-H_FRAME_OUT - 0.02, 1.2, -0.6), Vector3(-H_FRAME_OUT - 0.03, 1.2, -0.6)], [Vector2(0.14, 0.12), Vector2(0.14, 0.12)],
			Vector3.UP, 7, 0.0, Color(0.02, 0.02, 0.02), 0)


## The male's short gun (pivot at its origin, barrel to -Z): mantlet and, as the "barrel"
## piece, the tube that recoils.
static func sponson_mount(kind: String, lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	if kind == "heavy_male":
		g.loft([Vector3(0, -0.32, 0), Vector3(0, 0.32, 0)], [Vector2(0.3, 0.3), Vector2(0.3, 0.3)], Vector3.FORWARD, 10 if lod == 0 else 6,
			0.0, p["paint"], 0)
		g.box(Vector3(0, 0, -0.27), Vector3(0.13, 0.15, 0.06), p["dark"], 0)
	else:
		g.loft([Vector3(0, -0.15, 0), Vector3(0, 0.15, 0)], [Vector2(0.15, 0.15), Vector2(0.15, 0.15)], Vector3.FORWARD, 8 if lod == 0 else 5,
			0.0, p["dark"], 0)
	return g


static func sponson_barrel(kind: String, lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var n := 8 if lod == 0 else 5
	if kind == "heavy_male":
		g.loft([Vector3(0, 0, -0.25), Vector3(0, 0, -1.25), Vector3(0, 0, -1.6)], [Vector2(0.075, 0.075), Vector2(0.06, 0.06),
			Vector2(0.055, 0.055)], Vector3.UP, n, 0.0, p["steel"], 0)
		if lod == 0:
			g.loft([Vector3(0, 0, -1.55), Vector3(0, 0, -1.62)], [Vector2(0.07, 0.07), Vector2(0.07, 0.07)], Vector3.UP, n, 0.0, p["steel"], 0)
	else:
		g.loft([Vector3(0, 0, -0.1), Vector3(0, 0, -0.7)], [Vector2(0.065, 0.065), Vector2(0.065, 0.065)], Vector3.UP, n, 0.0, p["paint"], 0)
		g.loft([Vector3(0, 0, -0.7), Vector3(0, 0, -0.85)], [Vector2(0.025, 0.025), Vector2(0.025, 0.025)], Vector3.UP, 6, 0.0, p["steel"], 0)
		if lod == 0:
			for k in 6:
				g.box(Vector3(0, 0.066, -0.18 - 0.09 * k), Vector3(0.02, 0.004, 0.025), p["dark"], 0)
	return g


static func sponson_muzzle(kind: String) -> Vector3:
	return Vector3(0, 0, -1.62) if kind == "heavy_male" else Vector3(0, 0, -0.85)


## The roof hatch (origin on its rear hinge, lying flat toward -Z).
static func roof_hatch(lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	g.box(Vector3(0, 0.03, -0.36), Vector3(0.36, 0.03, 0.36), p["paint"], 0)
	if lod == 0:
		g.box(Vector3(0, 0.07, -0.55), Vector3(0.1, 0.012, 0.02), p["steel"], 0)
	return g


## A sponson door (right side; mirrored by x): origin on the outer hinge at the foot.
static func door(lod: int, wreck: bool, s := 1.0) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var a := Vector3(0, 0, 0)
	var e := Vector3(H_DOOR_END.x - H_DOOR_HINGE.x, 0, H_DOOR_END.z - H_DOOR_HINGE.z)
	e.x *= s
	var len := e.length()
	var dx := e / len
	var n := Vector3(dx.z, 0, -dx.x)
	# Outward: away from the sponson's inside (toward +z and out).
	if n.dot(Vector3(s * 0.6, 0, 1.0)) < 0.0:
		n = -n
	g.box(a + dx * len * 0.5 + Vector3(0, H_DOOR_H * 0.5, 0) + n * 0.025, Vector3(len * 0.48, 0.025, H_DOOR_H * 0.5), p["dark"], 0,
		Basis(dx, n, Vector3.UP))
	if lod == 0:
		g.box(a + dx * len * 0.8 + Vector3(0, H_DOOR_H * 0.55, 0) + n * 0.06, Vector3(0.02, 0.02, 0.08), p["steel"], 0,
			Basis(dx, n, Vector3.UP))
	return g


## The steering tail (origin on its pivot, arms back along +Z), without its wheels.
static func tail(lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(s * 0.35, 0, 0), Vector3(s * H_TAIL_X * 0.9, -0.05, H_TAIL_LEN)], [Vector2(0.06, 0.09), Vector2(0.06, 0.09)],
			Vector3.UP, 4, 0.0, p["dark"], 0)
	g.box(Vector3(0, 0, 0.05), Vector3(0.45, 0.07, 0.07), p["steel"], 0)
	g.box(Vector3(0, -0.05, H_TAIL_LEN), Vector3(H_TAIL_X + 0.1, 0.05, 0.05), p["steel"], 0)
	if lod == 0:
		g.box(Vector3(0, 0.08, H_TAIL_LEN * 0.55), Vector3(0.3, 0.05, 0.08), p["steel"], 0)
		g.loft([Vector3(0, 0.08, H_TAIL_LEN * 0.55), Vector3(0, 0.4, -0.05)], [Vector2(0.025, 0.025), Vector2(0.025, 0.025)], Vector3.RIGHT,
			4, 0.0, p["steel"], 0)
	return g


# ---------------------------------------------------------------- light hull

static func _light_hull(g: UnitGeo, kind: String, lod: int, wreck: bool, p: Dictionary) -> void:
	var d0 := lod == 0
	var Z := Vector3.BACK
	var Y := Vector3.UP
	var X := Vector3.RIGHT
	var hull := PackedVector2Array([Vector2(-1.6, 0.4), Vector2(-2.02, 0.72), Vector2(-1.95, 1.04), Vector2(-1.36, 1.48),
		Vector2(0.55, 1.5), Vector2(1.95, 1.22), Vector2(2.05, 0.66), Vector2(1.6, 0.4)])
	if lod >= 2:
		prism(g, hull, Z, Y, X, -0.52, 0.52, p["paint"])
		for s: float in [1.0, -1.0]:
			g.box(Vector3(s * L_TRACK_X, 0.62, 0.0), Vector3(0.03, 0.12, 1.75), p["dark"], 0)
		return
	prism(g, hull, Z, Y, X, -0.52, 0.52, _w(p["paint"], wreck, Vector3(0, 1.2, 0)), p["dark"] if d0 else null)
	# Side girders joining idler and sprocket, the bogie beams over the road wheels.
	for s: float in [1.0, -1.0]:
		var gx := s * (L_TRACK_X + L_TRACK_HW + 0.03)
		g.box(Vector3(gx, 0.66, 0.05), Vector3(0.025, 0.13, 1.72), _w(p["paint"], wreck, Vector3(s, 0.6, 0)), 0)
		g.box(Vector3(gx, 0.38, 0.1), Vector3(0.025, 0.05, 1.3), p["dark"], 0)
		g.box(Vector3(s * L_TRACK_X, 0.38, 0.1), Vector3(L_TRACK_HW + 0.02, 0.03, 1.3), p["dark"], 0)
		# Stub axles from the hull through to the girder.
		for z in [L_IDLER.x, L_SPROCKET.x]:
			g.box(Vector3(s * 0.62, (L_IDLER.y if z < 0.0 else L_SPROCKET.y), z), Vector3(0.12, 0.05, 0.05), p["steel"], 0)
		if d0:
			for k in 5:
				g.box(Vector3(gx + s * 0.027, 0.66, -1.4 + 0.7 * k), Vector3(0.004, 0.1, 0.012), p["dark"], 0)
	# The driver's hatch frame, vision slits, engine deck louvres, exhaust, the tail skid.
	g.box(Vector3(0, 1.27, -1.67), Vector3(0.36, 0.02, 0.32), p["dark"], 0, Basis(Vector3.RIGHT, -0.62))
	g.box(Vector3(0.0, 1.3, -1.665), Vector3(0.25, 0.018, 0.012), p["glass"], 0, Basis(Vector3.RIGHT, -0.62))
	if d0:
		for k in 5:
			g.box(Vector3(0, 1.47 - 0.055 * k, 0.9 + 0.2 * k), Vector3(0.38, 0.006, 0.03), p["steel"], 0, Basis(Vector3.RIGHT, 0.2))
	g.loft([Vector3(-0.42, 1.3, 0.95), L_EXHAUST], [Vector2(0.07, 0.07), Vector2(0.07, 0.07)], Vector3.UP, 6, 0.0, p["steel"], 0)
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(s * 0.4, 0.95, 1.95), Vector3(s * 0.4, 0.42, 2.95), Vector3(s * 0.4, 0.27, 3.12)],
			[Vector2(0.03, 0.06), Vector2(0.03, 0.06), Vector2(0.03, 0.04)], Vector3.UP, 4, 0.0, p["dark"], 0)
	g.box(Vector3(0, 0.45, 2.9), Vector3(0.4, 0.035, 0.035), p["steel"], 0)
	if d0:
		g.box(Vector3(0, 0.62, 2.5), Vector3(0.4, 0.025, 0.025), p["steel"], 0)
	# The turret ring.
	g.loft([L_TURRET + Vector3(0, -0.02, 0), L_TURRET + Vector3(0, 0.03, 0)], [Vector2(0.6, 0.6), Vector2(0.6, 0.6)], Vector3.FORWARD,
		8, 0.0, p["dark"], 0)
	# Markings: the sign on the hull sides at the back, the number on the rear plate.
	for s: float in [1.0, -1.0]:
		sign_mark(g, Vector3(s * 0.522, 1.2, 1.25), Vector3(0, 0, -s), Vector3.UP, Vector3(s, 0, 0), 0.13, p)
	var num := "37" if kind == "light_gun" else "41"
	digits(g, num, Vector3(-0.18, 0.78, 2.05), Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, 1), 0.22, p["mark"])
	if wreck:
		g.loft([Vector3(0.53, 1.0, -0.6), Vector3(0.54, 1.0, -0.6)], [Vector2(0.22, 0.2), Vector2(0.22, 0.2)], Vector3.UP, 8, 0.0, CHAR, 0)


## The turret (origin on the ring, centre of the turn).
static func turret(kind: String, lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var d0 := lod == 0
	var tc := _w(p["paint"], wreck, Vector3(0.3, 2, -0.4))
	if lod >= 2:
		g.loft([Vector3(0, 0, 0), Vector3(0, 0.62, 0)], [Vector2(0.55, 0.55), Vector2(0.47, 0.47)], Vector3.FORWARD, 6, 0.0, tc, 0)
		return g
	g.loft([Vector3(0, 0.0, 0), Vector3(0, 0.5, 0), Vector3(0, 0.64, 0)], [Vector2(0.56, 0.56), Vector2(0.5, 0.5), Vector2(0.42, 0.42)],
		Vector3.FORWARD, 8, 0.0, tc, 0)
	# The cupola under the lid, vision slits round it.
	g.loft([Vector3(0, 0.62, 0), Vector3(0, 0.8, 0)], [Vector2(0.21, 0.21), Vector2(0.2, 0.2)], Vector3.FORWARD, 8 if d0 else 6, 0.0,
		p["paint"], 0)
	if d0:
		for k in 6:
			var a := TAU * float(k) / 6.0 + 0.3
			g.box(Vector3(sin(a) * 0.205, 0.73, cos(a) * 0.205), Vector3(0.05, 0.012, 0.006), p["glass"], 0, Basis(Vector3.UP, a))
		for s: float in [1.0, -1.0]:
			g.box(Vector3(s * 0.5, 0.36, -0.12), Vector3(0.006, 0.02, 0.1), p["glass"], 0, Basis(Vector3.UP, -s * 0.36))
	# The number on both sides of the turret.
	var num := "37" if kind == "light_gun" else "41"
	for s: float in [1.0, -1.0]:
		var dirr := Vector3(0, 0, -s)
		var w := 0.2 * 0.77
		digits(g, num, Vector3(s * 0.53, 0.18, s * w), dirr, Vector3.UP, Vector3(s, 0, 0).rotated(Vector3.UP, 0.0), 0.2, p["mark"])
	return g


## The light tank's gun on its elevation pivot: the mantlet (fixed) ...
static func light_mantlet(kind: String, lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	if kind == "light_gun":
		g.box(Vector3(0, 0, -0.05), Vector3(0.18, 0.15, 0.08), p["dark"], 0, Basis(), 0.3 if lod == 0 else 0.0)
	else:
		g.loft([Vector3(0, -0.13, 0), Vector3(0, 0.13, 0)], [Vector2(0.13, 0.13), Vector2(0.13, 0.13)], Vector3.FORWARD, 8 if lod == 0 else 5,
			0.0, p["dark"], 0)
	return g


## ... and the tube that recoils.
static func light_barrel(kind: String, lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var n := 8 if lod == 0 else 5
	if kind == "light_gun":
		g.loft([Vector3(0, 0, -0.1), Vector3(0, 0, -0.95)], [Vector2(0.05, 0.05), Vector2(0.042, 0.042)], Vector3.UP, n, 0.0, p["steel"], 0)
		if lod == 0:
			g.loft([Vector3(0, 0, -0.92), Vector3(0, 0, -0.98)], [Vector2(0.055, 0.055), Vector2(0.055, 0.055)], Vector3.UP, n, 0.0, p["steel"], 0)
	else:
		g.loft([Vector3(0, 0, -0.05), Vector3(0, 0, -0.6)], [Vector2(0.06, 0.06), Vector2(0.06, 0.06)], Vector3.UP, n, 0.0, p["paint"], 0)
		g.loft([Vector3(0, 0, -0.6), Vector3(0, 0, -0.74)], [Vector2(0.022, 0.022), Vector2(0.022, 0.022)], Vector3.UP, 6, 0.0, p["steel"], 0)
	return g


static func light_muzzle(kind: String) -> Vector3:
	return Vector3(0, 0, -0.98) if kind == "light_gun" else Vector3(0, 0, -0.74)


## The cupola lid (origin on its rear hinge, lying toward -Z).
static func cupola_lid(lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	g.loft([Vector3(0, 0, -0.16), Vector3(0, 0.07, -0.16), Vector3(0, 0.1, -0.16)], [Vector2(0.23, 0.23), Vector2(0.2, 0.2),
		Vector2(0.1, 0.1)], Vector3.FORWARD, 8 if lod == 0 else 6, 0.0, p["paint"], 0)
	return g


## The driver's hatch (origin on its top hinge, lying down the glacis).
static func driver_hatch(lod: int, wreck: bool) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	var b := Basis(Vector3.RIGHT, -0.62)
	g.box(b * Vector3(0, 0.03, -0.3), Vector3(0.33, 0.025, 0.3), _w(p["paint"], wreck, Vector3(0, 1.3, -1.7)), 0, b)
	if lod == 0:
		g.box(b * Vector3(0, 0.06, -0.33), Vector3(0.25, 0.012, 0.012), p["glass"], 0, b)
	return g


# ---------------------------------------------------------------- the whole hull

static func hull(kind: String, lod := 0, wreck := false) -> UnitGeo:
	var g := UnitGeo.new()
	var p := _palette(wreck)
	if is_heavy(kind):
		_heavy_hull(g, kind, lod, wreck, p)
	else:
		_light_hull(g, kind, lod, wreck, p)
	return g


## Wheels that show and turn: [[centre (z, y), radius, kind]] per side ("road", "idler", "sprocket", "roller").
static func wheel_stations(kind: String) -> Array:
	if is_heavy(kind):
		return []
	var out := [[L_IDLER, L_IDLER_R, "idler"], [L_SPROCKET, L_SPROCKET_R, "sprocket"]]
	for k in 6:
		out.append([Vector2(lerpf(-1.12, 1.27, float(k) / 5.0), L_THICK + L_WHEEL_R), L_WHEEL_R, "road"])
	var top_a := L_IDLER + Vector2(0, L_IDLER_R)
	var top_b := L_SPROCKET + Vector2(0, L_SPROCKET_R)
	for k in 3:
		var u := 0.25 + 0.25 * k
		var tp := top_a.lerp(top_b, u)
		out.append([tp - Vector2(0, 0.075), 0.07, "roller"])
	return out


static func wheel_geo(st: Array, lod: int, wreck: bool) -> UnitGeo:
	var r: float = st[1]
	match st[2]:
		"idler":
			return spoke_wheel(r, L_TRACK_HW * 0.8, 6, lod, wreck)
		"sprocket":
			return spoke_wheel(r, L_TRACK_HW * 0.7, 5, lod, wreck, 10)
		"roller":
			return spoke_wheel(r, L_TRACK_HW * 0.5, 0, mini(lod + 1, 2), wreck)
	return spoke_wheel(r, L_TRACK_HW * 0.85, 0, lod, wreck)
