class_name BGeo
extends RefCounted
## Iron Front buildings: records a building's shapes as a list of ops (Asset Builder Chat), so the same
## building can be replayed into every look it needs: finished, half built, frame, damaged, ruin, the
## collapse chunks and the far look. Each op has a tier:
##   0 ground and foundations, 1 walls and structure, 2 roofs, 3 small details
## and an optional tag: "glow" (windows and lamps: drawn in the emissive Glow mesh), "detail" (left out
## of the far look), "keep" (never dropped by damage or the far filter), "far" (a stand-in drawn only in the far look).
## Shapes use TrainGeo's calls (box with half sizes, cyl, extrude, lump), all in the building's frame:
## the ground at y = 0, the footprint centred on the origin.

var ops: Array[Dictionary] = []
var tier := 1
var tag := ""


func box(c: Vector3, h: Vector3, col: Color, b := Basis(), ch := 0.0) -> void:
	ops.append({"t": "box", "c": c, "h": h, "col": col, "b": b, "ch": ch, "tier": tier, "tag": tag})


func cyl(a: Vector3, b: Vector3, r: float, sides: int, col: Color, r2 := -1.0) -> void:
	ops.append({"t": "cyl", "a": a, "b": b, "r": r, "sides": sides, "col": col, "r2": r2, "tier": tier, "tag": tag,
		"c": (a + b) * 0.5})


func extrude(outline: PackedVector2Array, p0: Vector3, p1: Vector3, col: Color, b := Basis()) -> void:
	ops.append({"t": "ext", "o": outline, "p0": p0, "p1": p1, "col": col, "b": b, "tier": tier, "tag": tag,
		"c": (p0 + p1) * 0.5})


func lump(c: Vector3, r: float, col: Color, s := Vector3.ONE) -> void:
	ops.append({"t": "lump", "c": c, "r": r, "col": col, "s": s, "tier": tier, "tag": tag})


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, ref: Vector3) -> void:
	ops.append({"t": "quad", "p": [a, b, c, d], "col": col, "ref": ref, "tier": tier, "tag": tag,
		"c": (a + b + c + d) * 0.25})


## A gable roof over a rectangle: centre of the eaves line c (at the top of the walls), half sizes hx, hz,
## ridge along z (or x when along_x), rising rise, overhang ov, roof skin thickness th.
func gable(c: Vector3, hx: float, hz: float, rise: float, col: Color, ov := 0.3, along_x := false, gable_col: Variant = null) -> void:
	var ax := hx + ov
	var lz := hz + ov
	var b := Basis() if not along_x else Basis(Vector3.UP, PI * 0.5)
	if along_x:
		ax = hz + ov
		lz = hx + ov
	# the gable ends (a triangle, wall coloured) and the two roof slopes as thin slabs
	var gc: Color = gable_col if gable_col != null else col.darkened(0.15)
	var tri := PackedVector2Array([Vector2(ax - ov, 0), Vector2(0, rise), Vector2(-ax + ov, 0)])
	extrude(tri, c - b.z * (lz - ov), c + b.z * (lz - ov), gc, b)
	var slope := atan2(rise, ax)
	var half := Vector2(ax, rise).length() * 0.5
	for s: float in [-1.0, 1.0]:
		var sb := b * Basis(Vector3(0, 0, 1), -s * slope)
		var mid := c + b.x * (s * ax * 0.5) + Vector3(0, rise * 0.5 + 0.06, 0)
		box(mid, Vector3(half + 0.05, 0.06, lz), col, sb)


## A lean-to roof: high side at -x (or -z when along_x), from h0 to h1 over the half sizes.
func lean(c: Vector3, hx: float, hz: float, drop: float, col: Color, ov := 0.3) -> void:
	var slope := atan2(drop, hx * 2.0)
	box(c + Vector3(0, -drop * 0.5, 0), Vector3(hx + ov, 0.06, hz + ov), col, Basis(Vector3(0, 0, 1), -slope))


# ------------------------------------------------------------------ replay

## Height of the top of the highest tier-1 op (used to cut the half-built look).
func top_y() -> float:
	var y := 0.0
	for o in ops:
		if int(o["tier"]) == 1 and o["t"] == "box" and o["tag"] != "glow":
			y = maxf(y, _top(o))
	return y


static func _top(o: Dictionary) -> float:
	match o["t"]:
		"box":
			return (o["c"] as Vector3).y + (o["h"] as Vector3).y
		"cyl":
			return maxf((o["a"] as Vector3).y, (o["b"] as Vector3).y)
	return (o["c"] as Vector3).y


static func _h(i: int, salt: int) -> float:
	# a small deterministic hash in 0..1 per op
	var x := (i * 73856093) ^ (salt * 19349663)
	x = (x ^ (x >> 13)) * 1274126177
	return float((x >> 4) & 0xFFFF) / 65535.0


## Replays the ops into g. mode: full, glow, half, damaged, ruin, far, chunk (with chunk index 0..3).
func replay(g: TrainGeo, mode: String, chunk := -1, seed_value := 0) -> void:
	var cut := top_y() * 0.55
	var ruin_max := top_y() * 0.6
	for i in ops.size():
		var o: Dictionary = ops[i]
		var tr := int(o["tier"])
		var tg: String = o["tag"]
		var col: Color = o["col"]
		var r := _h(i, seed_value)
		if tg == "far" and mode != "far":
			continue
		match mode:
			"full":
				if tg == "glow":
					continue
			"glow":
				if tg != "glow":
					continue
			"half":
				if tr >= 2 or tg == "glow":
					continue
				if tr == 1:
					if not _clip(g, o, cut, col):
						continue
					continue
			"damaged":
				if tg == "glow":
					col = Color(0.08, 0.07, 0.06)
				elif tr == 2 and r < 0.45 and tg != "keep":
					continue
				if r > 0.5:
					col = col.darkened(0.25 + (r - 0.5))
				if tr == 1 and o["t"] == "box" and (o["h"] as Vector3).y > 0.9 and tg == "":
					_holes(g, o, i, seed_value)
			"ruin":
				if tr >= 2:
					continue
				if tg == "glow":
					continue
				if tr == 1:
					var keep := lerpf(0.25, 0.7, _h(i, seed_value + 7))
					var t := _top(o)
					var bot := _bottom(o)
					col = col.darkened(0.3 + r * 0.3)
					if tg == "glow":
						col = Color(0.06, 0.05, 0.05)
					_clip(g, o, minf(bot + (t - bot) * keep, ruin_max), col)
					continue
			"ground":
				if tr != 0 or tg == "glow":
					continue
			"far":
				if tr >= 3 or tg == "detail":
					continue
				if tg != "keep" and tg != "far" and o["t"] == "box" and (o["h"] as Vector3).x * (o["h"] as Vector3).y * (o["h"] as Vector3).z < 0.2:
					continue
				if tg != "keep" and tg != "far" and o["t"] == "cyl" and (o["r"] as float) < 0.2:
					continue
				if o["t"] == "lump":
					continue
			"chunk":
				if tr == 0:
					continue
				if tg == "glow":
					col = Color(0.08, 0.07, 0.06)
				var c: Vector3 = o["c"]
				var q := (1 if c.x >= 0.0 else 0) + (2 if c.z >= 0.0 else 0)
				if q != chunk:
					continue
		_emit(g, o, col, mode == "far")


static func _bottom(o: Dictionary) -> float:
	match o["t"]:
		"box":
			return (o["c"] as Vector3).y - (o["h"] as Vector3).y
		"cyl":
			return minf((o["a"] as Vector3).y, (o["b"] as Vector3).y)
	return (o["c"] as Vector3).y


## Emits o with its top cut at y (boxes with no turn and upright bars are cut; others are kept whole if their
## centre is below y). Returns false if nothing was emitted.
func _clip(g: TrainGeo, o: Dictionary, y: float, col: Color) -> bool:
	if _bottom(o) >= y:
		return false
	if o["t"] == "box" and (o["b"] as Basis).is_equal_approx(Basis()):
		var c: Vector3 = o["c"]
		var h: Vector3 = o["h"]
		var top := minf(c.y + h.y, y)
		var bot := c.y - h.y
		g.box(Vector3(c.x, (top + bot) * 0.5, c.z), Vector3(h.x, (top - bot) * 0.5, h.z), col, Basis(), o["ch"])
		return true
	if o["t"] == "cyl":
		var a: Vector3 = o["a"]
		var b: Vector3 = o["b"]
		if absf(a.x - b.x) < 0.01 and absf(a.z - b.z) < 0.01:
			var lo := a if a.y < b.y else b
			var hi := b if a.y < b.y else a
			hi.y = minf(hi.y, y)
			g.cyl(lo, hi, o["r"], o["sides"], col)
			return true
	if (o["c"] as Vector3).y < y:
		_emit(g, o, col, false)
		return true
	return false


static func _emit(g: TrainGeo, o: Dictionary, col: Color, far: bool) -> void:
	match o["t"]:
		"box":
			g.box(o["c"], o["h"], col, o["b"], 0.0 if far else float(o["ch"]))
		"cyl":
			g.cyl(o["a"], o["b"], o["r"], 4 if far else int(o["sides"]), col, o["r2"])
		"ext":
			g.extrude(o["o"], o["p0"], o["p1"], col, o["b"])
		"lump":
			g.lump(o["c"], o["r"], col, o["s"])
		"quad":
			var p: Array = o["p"]
			g.quad_out(p[0], p[1], p[2], p[3], col, o["ref"])
		"prism":
			g.prism(o["rings"], col)


## The walls' footprint: [centre x, centre z, half x, half z] of the tier-1 boxes taller than 1.6 m.
func core_rect() -> Array[float]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for o in ops:
		if int(o["tier"]) == 1 and o["t"] == "box" and (o["h"] as Vector3).y > 0.8 and o["tag"] != "glow":
			var c: Vector3 = o["c"]
			var h: Vector3 = (o["b"] as Basis).get_scale() * 0.0 + o["h"]
			lo = lo.min(Vector2(c.x - h.x, c.z - h.z))
			hi = hi.max(Vector2(c.x + h.x, c.z + h.z))
	if lo.x == INF:
		return [0.0, 0.0, 2.0, 2.0]
	return [(lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (hi.x - lo.x) * 0.5, (hi.y - lo.y) * 0.5]


## Shell holes and scorch on a wall box: dark ragged patches standing just proud of a face.
func _holes(g: TrainGeo, o: Dictionary, i: int, seed_value: int) -> void:
	var c: Vector3 = o["c"]
	var h: Vector3 = o["h"]
	var b: Basis = o["b"]
	for k in 2:
		var r := _h(i * 3 + k, seed_value + 21)
		if r > 0.75:
			continue
		var face := int(_h(i * 3 + k, seed_value + 22) * 4.0)
		var n := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][face] as Vector3
		var along := Vector3(absf(n.z), 0, absf(n.x))
		var span := (h.x if n.z != 0.0 else h.z)
		var u := (_h(i, seed_value + 23 + k) - 0.5) * 1.4 * span
		var y := (_h(i, seed_value + 24 + k) - 0.3) * h.y
		var face_d := (h.x if n.x != 0.0 else h.z)
		var p := c + b * (n * (face_d + 0.03) + along * u + Vector3(0, y, 0))
		var s := 0.5 + r * 0.9
		g.box(p, (b * (along * s + Vector3(0, s * 0.8, 0))).abs() + (b * n).abs() * 0.04, Color(0.07, 0.06, 0.06))
		g.box(p + b * n * 0.01, (b * (along * s * 1.6 + Vector3(0, s * 1.2, 0))).abs() + (b * n).abs() * 0.02, Color(0.2, 0.17, 0.15))
