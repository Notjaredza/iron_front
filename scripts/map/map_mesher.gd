class_name MapMesher
extends RefCounted
## Iron Front: builds the mesh of one map chunk (CHUNK x CHUNK cells, 512 m) from MapData.
## - Ground in one surface with vertex colours. Every face has its own normal, so the shading is flat (low poly).
## - Flat cells are merged into rectangles.
## - A cell that holds a cliff edge is cut by marching squares through its edge midpoints, which gives square and
##   45 degree edges.
## - A cliff wall drops from each edge: a grass lip, two dirt bands that lean out (the bank), and a dirt apron below.
## - The wall's corner points are shared with the next cell (the normals of both neighbours are added together), so
##   the walls close up, across chunk borders too.
## - Also built here: ramps, the old rail lines (ballast, sleepers, rails, bridges), house and ruin stand-ins, and
##   the map-edge skirt.
## The vertex colour's alpha tags the material for the shader: 1 is plain, 0.5 is water, 0.25 is a lit window.

const CHUNK := 64
const BANK := 2.6
const LIP := 0.35
const LIP_DROP := 0.9
const APRON := 3.2
const SKIRT_Y := -14.0
const PIECE := 2.4                 # rail piece length (m)
const WATER_A := 0.5
const WINDOW_A := 0.25

const C_WATER := Color(0.23, 0.46, 0.66, WATER_A)
const C_LEVEL := [Color(0.23, 0.46, 0.66), Color(0.40, 0.60, 0.24), Color(0.45, 0.64, 0.26), Color(0.50, 0.67, 0.29)]
const C_LIP := Color(0.32, 0.49, 0.19)
const C_DIRT_HI := Color(0.57, 0.41, 0.25)
const C_DIRT_LO := Color(0.49, 0.34, 0.20)
const C_APRON := Color(0.60, 0.47, 0.30)
const C_SAND := Color(0.68, 0.60, 0.42)
const C_TRACK := Color(0.64, 0.51, 0.34)
const C_SKIRT := Color(0.40, 0.30, 0.20)
const C_BALLAST := Color(0.50, 0.47, 0.43)
const C_BALLAST_OLD := Color(0.42, 0.45, 0.33)
const C_SLEEPER := Color(0.36, 0.26, 0.18)
const C_RAIL := Color(0.42, 0.41, 0.40)
const C_RUST := Color(0.48, 0.31, 0.21)
const C_DECK := Color(0.38, 0.32, 0.28)
const C_STONE := Color(0.56, 0.54, 0.50)
const C_RUBBLE := Color(0.47, 0.45, 0.42)
const WALLS := [Color(0.88, 0.82, 0.70), Color(0.92, 0.90, 0.84), Color(0.80, 0.68, 0.50), Color(0.74, 0.70, 0.62)]
const ROOFS := [Color(0.66, 0.28, 0.18), Color(0.56, 0.31, 0.21), Color(0.40, 0.39, 0.42), Color(0.60, 0.36, 0.20)]

var d: MapData
var vt := PackedVector3Array()
var nm := PackedVector3Array()
var co := PackedColorArray()
var x0 := 0
var z0 := 0
var x1 := 0
var z1 := 0
var miter: Dictionary = {}
var debug := false
var wall_keys: Dictionary = {}     # debug: key -> [points, segment ends]


## Arrays for ArrayMesh.add_surface_from_arrays (empty if the chunk is empty), plus debug wall data when asked.
static func build(data: MapData, cx: int, cz: int, want_debug := false) -> Dictionary:
	var m := MapMesher.new()
	m.d = data
	m.debug = want_debug
	return m._build(cx, cz)


static func chunks_x(data: MapData) -> int:
	return ceili(float(data.w) / CHUNK)


static func chunks_z(data: MapData) -> int:
	return ceili(float(data.h) / CHUNK)


func _build(cx: int, cz: int) -> Dictionary:
	x0 = cx * CHUNK
	z0 = cz * CHUNK
	x1 = mini(d.w, x0 + CHUNK)
	z1 = mini(d.h, z0 + CHUNK)
	_miters()
	_flats()
	for z in range(z0, z1):
		for x in range(x0, x1):
			if d.walk[z * d.w + x] == MapData.FLAT_NONE:
				_edge_cell(x, z)
	_ramps()
	_skirt()
	_rails()
	_houses()
	var arrays := []
	if vt.size() > 0:
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vt
		arrays[Mesh.ARRAY_NORMAL] = nm
		arrays[Mesh.ARRAY_COLOR] = co
	return {"arrays": arrays, "tris": vt.size() / 3, "walls": wall_keys,
		"aabb": AABB(Vector3(x0 * MapData.CELL, SKIRT_Y, z0 * MapData.CELL), Vector3((x1 - x0) * MapData.CELL, 40.0, (z1 - z0) * MapData.CELL))}


# ------------------------------------------------------------------------------------------------------- helpers

## A triangle facing `want` (Godot draws clockwise faces as the front, so the order is fixed to suit).
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, want: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot(want) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = -n.normalized()
	vt.append(a)
	vt.append(b)
	vt.append(c)
	nm.append(n)
	nm.append(n)
	nm.append(n)
	co.append(col)
	co.append(col)
	co.append(col)


func quad(a: Vector3, b: Vector3, c: Vector3, e: Vector3, col: Color, want: Vector3) -> void:
	tri(a, b, c, col, want)
	tri(a, c, e, col, want)


## A box on the ground (no bottom), turned by rot about Y round its centre.
func box(centre: Vector3, size: Vector3, rot: float, col: Color, top_col := Color(-1, 0, 0)) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var p := []
	for k in 4:
		var lx := -hx if (k == 0 or k == 3) else hx
		var lz := -hz if k < 2 else hz
		p.append(centre + _rot(Vector3(lx, 0, lz), rot))
	var up := Vector3(0, size.y, 0)
	var tc := col if top_col.r < 0.0 else top_col
	quad(p[0] + up, p[1] + up, p[2] + up, p[3] + up, tc, Vector3.UP)
	for k in 4:
		var a: Vector3 = p[k]
		var b: Vector3 = p[(k + 1) % 4]
		var out := ((a + b) * 0.5 - centre)
		out.y = 0.0
		quad(a, b, b + up, a + up, col, out)


static func _rot(v: Vector3, rot: float) -> Vector3:
	var c := cos(rot)
	var s := sin(rot)
	return Vector3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)


static func _h01(k: int) -> float:
	return float(hash(k) % 10007) / 10007.0


func _corner(x: int, z: int) -> int:
	return d.field[z * (d.w + 1) + x]


func _ly(level: int) -> float:
	return MapData.WATER_Y if level == 0 else MapData.level_y(level)


# --------------------------------------------------------------------------------------------------------- flats

func _flats() -> void:
	var cw := x1 - x0
	var chh := z1 - z0
	var seen := PackedByteArray()
	seen.resize(cw * chh)
	for z in range(z0, z1):
		for x in range(x0, x1):
			var li := (z - z0) * cw + (x - x0)
			if seen[li] == 1:
				continue
			var v := d.walk[z * d.w + x]
			if v == MapData.FLAT_NONE:
				continue
			var xe := x + 1
			while xe < x1 and seen[(z - z0) * cw + xe - x0] == 0 and d.walk[z * d.w + xe] == v:
				xe += 1
			var ze := z + 1
			while ze < z1:
				var ok := true
				for xx in range(x, xe):
					if seen[(ze - z0) * cw + xx - x0] == 1 or d.walk[ze * d.w + xx] != v:
						ok = false
						break
				if not ok:
					break
				ze += 1
			for zz in range(z, ze):
				for xx in range(x, xe):
					seen[(zz - z0) * cw + xx - x0] = 1
			var y := _ly(v)
			var col: Color = C_WATER if v == 0 else C_LEVEL[v]
			var c := MapData.CELL
			quad(Vector3(x * c, y, z * c), Vector3(xe * c, y, z * c), Vector3(xe * c, y, ze * c), Vector3(x * c, y, ze * c), col, Vector3.UP)


# --------------------------------------------------------------------------------------------- cliff edge cells

## The polygon (corner and edge-midpoint points, clockwise from a) of the part of a cell at level t or above.
## Each entry is [Vector2 local point, edge index 0-3 or -1 for a corner].
static func ms_poly(v: Array, t: int) -> Array:
	const CP := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	const MP := [Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)]
	var out := []
	for k in 4:
		var a: bool = int(v[k]) >= t
		var b: bool = int(v[(k + 1) % 4]) >= t
		if a:
			out.append([CP[k], -1])
		if a != b:
			out.append([MP[k], k])
	return out


## The key of an edge midpoint: edge k of cell (x, z) at threshold t (shared with the neighbouring cell).
func _mkey(x: int, z: int, k: int, t: int) -> int:
	var hx := x
	var hz := z
	var vert := 0
	match k:
		0:
			pass
		1:
			hx = x + 1
			vert = 1
		2:
			hz = z + 1
		3:
			vert = 1
	return ((hz * (d.w + 1) + hx) * 2 + vert) * 4 + t


func _cell_vals(x: int, z: int) -> Array:
	return [_corner(x, z), _corner(x + 1, z), _corner(x + 1, z + 1), _corner(x, z + 1)]


## The cliff lines of one cell at threshold t: [p, q (metres), outward normal, key p, key q].
func _segments(x: int, z: int, v: Array, t: int) -> Array:
	var poly := ms_poly(v, t)
	var out := []
	var inside := Vector2.ZERO
	var ni := 0
	for k in 4:
		if int(v[k]) >= t:
			inside += [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)][k]
			ni += 1
	if ni == 0 or ni == 4:
		return out
	inside /= ni
	var n := poly.size()
	for i in n:
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % n]
		if int(a[1]) < 0 or int(b[1]) < 0:
			continue
		var pa: Vector2 = a[0]
		var pb: Vector2 = b[0]
		var dv := pb - pa
		var nn := Vector2(dv.y, -dv.x).normalized()
		if nn.dot(inside - (pa + pb) * 0.5) > 0.0:
			nn = -nn
		var base := Vector2(x, z)
		out.append([(base + pa) * MapData.CELL, (base + pb) * MapData.CELL, nn, _mkey(x, z, int(a[1]), t), _mkey(x, z, int(b[1]), t)])
	return out


## Shared corner normals of the walls: summed over this chunk's cells and a one-cell ring round it.
func _miters() -> void:
	for z in range(maxi(0, z0 - 1), mini(d.h, z1 + 1)):
		for x in range(maxi(0, x0 - 1), mini(d.w, x1 + 1)):
			if d.walk[z * d.w + x] != MapData.FLAT_NONE:
				continue
			var v := _cell_vals(x, z)
			var lo: int = v.min()
			var hi: int = v.max()
			for t in range(lo + 1, hi + 1):
				for s in _segments(x, z, v, t):
					for kk in [3, 4]:
						var key: int = s[kk]
						miter[key] = miter.get(key, Vector2.ZERO) + (s[2] as Vector2)


func _edge_cell(x: int, z: int) -> void:
	var v := _cell_vals(x, z)
	var lo: int = v.min()
	var hi: int = v.max()
	var c := MapData.CELL
	var base_y := _ly(lo)
	var col: Color = C_WATER if lo == 0 else C_LEVEL[lo]
	quad(Vector3(x * c, base_y, z * c), Vector3((x + 1) * c, base_y, z * c), Vector3((x + 1) * c, base_y, (z + 1) * c), Vector3(x * c, base_y, (z + 1) * c), col, Vector3.UP)
	for t in range(lo + 1, hi + 1):
		var poly := ms_poly(v, t)
		var y := MapData.level_y(t)
		var pts := []
		for e in poly:
			var p: Vector2 = (Vector2(x, z) + (e[0] as Vector2)) * c
			pts.append(Vector3(p.x, y, p.y))
		for i in range(1, pts.size() - 1):
			tri(pts[0], pts[i], pts[i + 1], C_LEVEL[t], Vector3.UP)
		for s in _segments(x, z, v, t):
			_wall(s, t)


## The wall profile at one corner point: [offset out, height] pairs, top to bottom.
func _profile(t: int, key: int) -> Array:
	if t == 1:
		return [[0.0, 0.0], [0.2, -0.35], [0.6, -1.5], [1.2, MapData.LEVEL_Y[0]]]
	var h1: float = MapData.level_y(t)
	var h0: float = MapData.level_y(t - 1)
	var j1 := _h01(key) - 0.5
	var j2 := _h01(key * 31 + 7) - 0.5
	return [[0.0, h1], [LIP, h1 - LIP_DROP], [BANK * 0.5 + j1 * 1.0, h0 + (h1 - h0) * 0.42 + j2 * 1.4], [BANK, h0]]


func _wall(s: Array, t: int) -> void:
	var p: Vector2 = s[0]
	var q: Vector2 = s[1]
	var kp: int = s[3]
	var kq: int = s[4]
	var np_: Vector2 = (miter.get(kp, s[2]) as Vector2).normalized()
	var nq: Vector2 = (miter.get(kq, s[2]) as Vector2).normalized()
	var pp := _profile(t, kp)
	var pq := _profile(t, kq)
	var ap := []
	var aq := []
	for i in 4:
		ap.append(Vector3(p.x + np_.x * float(pp[i][0]), float(pp[i][1]), p.y + np_.y * float(pp[i][0])))
		aq.append(Vector3(q.x + nq.x * float(pq[i][0]), float(pq[i][1]), q.y + nq.y * float(pq[i][0])))
	var n2: Vector2 = s[2]
	var out := Vector3(n2.x, 0.4, n2.y)
	var cols := [C_SAND, C_DIRT_HI, C_DIRT_LO] if t == 1 else [C_LIP, C_DIRT_HI, C_DIRT_LO]
	for i in 3:
		quad(ap[i], ap[i + 1], aq[i + 1], aq[i], cols[i], out)
	if t >= 2:
		var y := MapData.level_y(t - 1) + 0.1
		var wp := BANK + APRON * (0.6 + 0.8 * _h01(kp * 13 + 3))
		var wq := BANK + APRON * (0.6 + 0.8 * _h01(kq * 13 + 3))
		var a0 := Vector3(p.x + np_.x * (BANK - 0.4), y, p.y + np_.y * (BANK - 0.4))
		var b0 := Vector3(q.x + nq.x * (BANK - 0.4), y, q.y + nq.y * (BANK - 0.4))
		var a1 := Vector3(p.x + np_.x * wp, y, p.y + np_.y * wp)
		var b1 := Vector3(q.x + nq.x * wq, y, q.y + nq.y * wq)
		quad(a0, a1, b1, b0, C_APRON, Vector3.UP)
	if debug:
		for e in [[kp, ap], [kq, aq]]:
			var k: int = e[0]
			if not wall_keys.has(k):
				wall_keys[k] = [e[1], 0]
			wall_keys[k][1] += 1


# --------------------------------------------------------------------------------------------------------- ramps

func _ramps() -> void:
	var c := MapData.CELL
	for r in d.ramps:
		var t: int = r["t"]
		var s: int = r["s"]
		var e: float = r["e"]
		var a: int = r["a"]
		var wd: int = r["w"]
		var mid_along := e + 2.0 * s
		var mid_across := a + wd * 0.5
		var mx := mid_along if int(r["axis"]) == 0 else mid_across
		var mz := mid_across if int(r["axis"]) == 0 else mid_along
		if mx < x0 or mx >= x1 or mz < z0 or mz >= z1:
			continue
		var h1 := MapData.level_y(t)
		var h0 := MapData.level_y(t - 1)
		var f := e + 4.0 * s
		var pts := {}
		for k in [["t0", e, a, h1], ["t1", e, a + wd, h1], ["f0", f, a, h0], ["f1", f, a + wd, h0], ["b0", e, a, h0], ["b1", e, a + wd, h0]]:
			var al: float = k[1]
			var ac: float = k[2]
			pts[k[0]] = Vector3(al * c, k[3], ac * c) if int(r["axis"]) == 0 else Vector3(ac * c, k[3], al * c)
		quad(pts["t0"], pts["t1"], pts["f1"], pts["f0"], C_TRACK, Vector3.UP)
		var side := Vector3(0, 0, 1) if int(r["axis"]) == 0 else Vector3(1, 0, 0)
		tri(pts["t0"], pts["f0"], pts["b0"], C_DIRT_HI, -side)
		tri(pts["t1"], pts["f1"], pts["b1"], C_DIRT_HI, side)


# ------------------------------------------------------------------------------------------------------ map edge

func _skirt() -> void:
	var c := MapData.CELL
	if z0 == 0:
		for x in range(x0, x1):
			_skirt_cell(Vector2(x, 0), Vector2(x + 1, 0), _corner(x, 0), _corner(x + 1, 0), Vector3(0, 0, -1))
	if z1 == d.h:
		for x in range(x0, x1):
			_skirt_cell(Vector2(x, d.h), Vector2(x + 1, d.h), _corner(x, d.h), _corner(x + 1, d.h), Vector3(0, 0, 1))
	if x0 == 0:
		for z in range(z0, z1):
			_skirt_cell(Vector2(0, z), Vector2(0, z + 1), _corner(0, z), _corner(0, z + 1), Vector3(-1, 0, 0))
	if x1 == d.w:
		for z in range(z0, z1):
			_skirt_cell(Vector2(d.w, z), Vector2(d.w, z + 1), _corner(d.w, z), _corner(d.w, z + 1), Vector3(1, 0, 0))


func _skirt_cell(a: Vector2, b: Vector2, la: int, lb: int, out: Vector3) -> void:
	var c := MapData.CELL
	var m := (a + b) * 0.5
	for seg in [[a, m, la], [m, b, lb]]:
		var p: Vector2 = seg[0] * c
		var q: Vector2 = seg[1] * c
		var y := _ly(int(seg[2]))
		quad(Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), Vector3(q.x, SKIRT_Y, q.y), Vector3(p.x, SKIRT_Y, p.y), C_SKIRT, out)
	if la != lb:
		var y0 := _ly(la)
		var y1 := _ly(lb)
		var mp := m * c
		quad(Vector3(mp.x, minf(y0, y1), mp.y), Vector3(mp.x, maxf(y0, y1), mp.y), Vector3(mp.x, maxf(y0, y1), mp.y) + out * 0.01, Vector3(mp.x, minf(y0, y1), mp.y) + out * 0.01, C_SKIRT, out)


# ---------------------------------------------------------------------------------------------------- rail lines

func _in_chunk(p: Vector2) -> bool:
	var c := MapData.CELL
	return p.x >= x0 * c and p.x < x1 * c and p.y >= z0 * c and p.y < z1 * c


## A point and its direction at distance s along a line (cum = distance at each point).
static func _along(pts: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	s = clampf(s, 0.0, cum[cum.size() - 1])
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var m := (lo + hi) / 2
		if cum[m] <= s:
			lo = m
		else:
			hi = m
	var span := cum[hi] - cum[lo]
	var t := 0.0 if span <= 0.0 else (s - cum[lo]) / span
	return pts[lo].lerp(pts[hi], t)


func _rails() -> void:
	var c := MapData.CELL
	var lo := Vector2(x0 * c, z0 * c) - Vector2(8, 8)
	var hi := Vector2(x1 * c, z1 * c) + Vector2(8, 8)
	for li in d.rails.size():
		var rl: Dictionary = d.rails[li]
		var pts: PackedVector2Array = rl["pts"]
		var cum := PackedFloat32Array()
		cum.resize(pts.size())
		for k in range(1, pts.size()):
			cum[k] = cum[k - 1] + pts[k].distance_to(pts[k - 1])
		var total := cum[pts.size() - 1]
		var sections: Array = rl["sections"]
		for k in range(1, pts.size()):
			var a := pts[k - 1]
			var b := pts[k]
			if maxf(a.x, b.x) < lo.x or minf(a.x, b.x) > hi.x or maxf(a.y, b.y) < lo.y or minf(a.y, b.y) > hi.y:
				continue
			var i0 := int(floor(cum[k - 1] / PIECE))
			var i1 := int(ceil(cum[k] / PIECE))
			for i in range(i0, i1):
				var s := i * PIECE
				if s < cum[k - 1] or s >= cum[k] or s + PIECE > total:
					continue
				var mid := _along(pts, cum, s + PIECE * 0.5)
				if not _in_chunk(mid):
					continue
				var broken := false
				for sec in sections:
					if s >= float(sec["from"]) and s < float(sec["to"]):
						broken = sec["broken"]
				_piece(pts, cum, s, broken, li * 100003 + i)


func _side(pts: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	var t := (_along(pts, cum, s + 1.2) - _along(pts, cum, s - 1.2)).normalized()
	return Vector2(-t.y, t.x)


func _wet(p: Vector2) -> bool:
	var x := clampi(int(p.x / MapData.CELL), 0, d.w - 1)
	var z := clampi(int(p.y / MapData.CELL), 0, d.h - 1)
	return _corner(x, z) == 0 or _corner(x + 1, z) == 0 or _corner(x, z + 1) == 0 or _corner(x + 1, z + 1) == 0


func _piece(pts: PackedVector2Array, cum: PackedFloat32Array, s: float, broken: bool, seed_k: int) -> void:
	var pa := _along(pts, cum, s)
	var pb := _along(pts, cum, s + PIECE)
	var na := _side(pts, cum, s)
	var nb := _side(pts, cum, s + PIECE)
	var mid := (pa + pb) * 0.5
	var tng := (pb - pa).normalized()
	var rot := atan2(tng.x, tng.y)
	var wet := _wet(mid) or _wet(pa) or _wet(pb)
	var base := 0.0
	var r1 := _h01(seed_k)
	var r2 := _h01(seed_k * 7 + 1)
	var run := _h01(seed_k / 5 + 99991)
	if wet:
		# Bridge deck, with a stone pier every 8 pieces.
		var dw := 2.4
		quad(_v(pa + na * dw, 0.0), _v(pb + nb * dw, 0.0), _v(pb - nb * dw, 0.0), _v(pa - na * dw, 0.0), C_DECK, Vector3.UP)
		quad(_v(pa + na * dw, 0.0), _v(pb + nb * dw, 0.0), _v(pb + nb * dw, -0.7), _v(pa + na * dw, -0.7), C_DECK, _v(na, 0.0))
		quad(_v(pa - na * dw, 0.0), _v(pb - nb * dw, 0.0), _v(pb - nb * dw, -0.7), _v(pa - na * dw, -0.7), C_DECK, _v(-na, 0.0))
		if seed_k % 8 == 0:
			box(_v(mid, -3.0), Vector3(4.0, 2.3, 1.4), rot, C_STONE)
	else:
		# Ballast bed: a flat top and two sloping sides, joined to the next piece.
		var bc := C_BALLAST_OLD if broken else C_BALLAST
		var top := 0.18
		quad(_v(pa + na * 1.6, top), _v(pb + nb * 1.6, top), _v(pb - nb * 1.6, top), _v(pa - na * 1.6, top), bc, Vector3.UP)
		quad(_v(pa + na * 1.6, top), _v(pb + nb * 1.6, top), _v(pb + nb * 2.3, 0.0), _v(pa + na * 2.3, 0.0), bc, _v(na, 0.6))
		quad(_v(pa - na * 1.6, top), _v(pb - nb * 1.6, top), _v(pb - nb * 2.3, 0.0), _v(pa - na * 2.3, 0.0), bc, _v(-na, 0.6))
		base = top
	# Sleeper.
	if not (broken and r1 < 0.25):
		var srot := rot + (r2 - 0.5) * 0.5 if broken else rot
		box(_v(mid, base), Vector3(2.5, 0.12, 0.28), srot, C_SLEEPER)
	# Rails: missing in runs on broken lines.
	if broken and run < 0.55:
		return
	var rc := C_RUST if broken else C_RAIL
	for side: float in [-0.72, 0.72]:
		var a := pa + na * side
		var b := pb + nb * side
		var y0 := base + 0.12
		var y1 := y0 + 0.14
		var o := 0.04
		quad(_v(a + na * o, y1), _v(b + nb * o, y1), _v(b - nb * o, y1), _v(a - na * o, y1), rc, Vector3.UP)
		quad(_v(a + na * o, y1), _v(b + nb * o, y1), _v(b + nb * o, y0), _v(a + na * o, y0), rc, _v(na, 0.0))
		quad(_v(a - na * o, y1), _v(b - nb * o, y1), _v(b - nb * o, y0), _v(a - na * o, y0), rc, _v(-na, 0.0))


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


# ------------------------------------------------------------------------------------------- villages and ruins

func _houses() -> void:
	for pi in d.places.size():
		var pl: Dictionary = d.places[pi]
		var hs: Array = pl["houses"]
		for hi in hs.size():
			var hd: Dictionary = hs[hi]
			var p: Vector3 = hd["pos"]
			if not _in_chunk(Vector2(p.x, p.z)):
				continue
			var k := pi * 1009 + hi
			match String(hd["kind"]):
				"house":
					_house(p, hd["size"], hd["rot"], WALLS[k % WALLS.size()], ROOFS[(k / 3) % ROOFS.size()], k)
				"station":
					_house(p, hd["size"], hd["rot"], Color(0.62, 0.36, 0.27), ROOFS[2], k)
				"platform":
					var sz: Vector2 = hd["size"]
					box(p, Vector3(sz.x, 0.9, sz.y), hd["rot"], Color(0.52, 0.50, 0.47), Color(0.66, 0.64, 0.60))
				"ruin":
					_ruin(p, hd["size"], hd["rot"], k)


func _house(p: Vector3, size: Vector2, rot: float, wall: Color, roof: Color, k: int) -> void:
	var wh := 3.4
	box(p, Vector3(size.x, wh, size.y), rot, wall)
	# Gable roof along the length (local z), with a small overhang.
	var hx := size.x * 0.5 + 0.4
	var hz := size.y * 0.5 + 0.4
	var ridge := 2.6
	var e0 := p + _rot(Vector3(-hx, wh - 0.2, -hz), rot)
	var e1 := p + _rot(Vector3(-hx, wh - 0.2, hz), rot)
	var f0 := p + _rot(Vector3(hx, wh - 0.2, -hz), rot)
	var f1 := p + _rot(Vector3(hx, wh - 0.2, hz), rot)
	var r0 := p + _rot(Vector3(0, wh + ridge, -hz), rot)
	var r1 := p + _rot(Vector3(0, wh + ridge, hz), rot)
	var left := _rot(Vector3(-1, 1.2, 0), rot)
	var right := _rot(Vector3(1, 1.2, 0), rot)
	quad(e0, e1, r1, r0, roof, left)
	quad(f0, f1, r1, r0, roof, right)
	var g0 := p + _rot(Vector3(-size.x * 0.5, wh, -size.y * 0.5), rot)
	var g1 := p + _rot(Vector3(size.x * 0.5, wh, -size.y * 0.5), rot)
	var g2 := p + _rot(Vector3(0, wh + ridge - 0.25, -size.y * 0.5), rot)
	tri(g0, g1, g2, wall, _rot(Vector3(0, 0, -1), rot))
	g0 = p + _rot(Vector3(-size.x * 0.5, wh, size.y * 0.5), rot)
	g1 = p + _rot(Vector3(size.x * 0.5, wh, size.y * 0.5), rot)
	g2 = p + _rot(Vector3(0, wh + ridge - 0.25, size.y * 0.5), rot)
	tri(g0, g1, g2, wall, _rot(Vector3(0, 0, 1), rot))
	# Windows on the long sides; some glow at night.
	var nwin := maxi(1, int(size.y / 4.5))
	for side: float in [-1.0, 1.0]:
		for i in nwin:
			var lz := -size.y * 0.5 + (i + 0.5) * size.y / nwin
			var lit := _h01(k * 17 + i * 3 + int(side + 1.0)) < 0.45
			var col := Color(0.95, 0.66, 0.30, WINDOW_A) if lit else Color(0.20, 0.21, 0.24)
			var lx: float = side * (size.x * 0.5 + 0.03)
			var a := p + _rot(Vector3(lx, 1.3, lz - 0.45), rot)
			var b := p + _rot(Vector3(lx, 1.3, lz + 0.45), rot)
			var c := p + _rot(Vector3(lx, 2.4, lz + 0.45), rot)
			var e := p + _rot(Vector3(lx, 2.4, lz - 0.45), rot)
			quad(a, b, c, e, col, _rot(Vector3(side, 0, 0), rot))


func _ruin(p: Vector3, size: Vector2, rot: float, k: int) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var walls := [[Vector3(0, 0, -hz), Vector3(size.x, 0, 0.5)], [Vector3(0, 0, hz), Vector3(size.x, 0, 0.5)],
		[Vector3(-hx, 0, 0), Vector3(0.5, 0, size.y)], [Vector3(hx, 0, 0), Vector3(0.5, 0, size.y)]]
	for i in 4:
		var r := _h01(k * 11 + i)
		if r < 0.22:
			continue
		var wdat: Array = walls[i]
		var sz: Vector3 = wdat[1]
		sz.y = 0.8 + r * 2.8
		box(p + _rot(wdat[0], rot), sz, rot, C_STONE)
	for i in 3:
		var o := Vector3((_h01(k * 5 + i) - 0.5) * size.x * 0.7, 0, (_h01(k * 9 + i) - 0.5) * size.y * 0.7)
		box(p + _rot(o, rot), Vector3(1.6, 0.5 + _h01(k + i) * 0.6, 1.3), rot + i, C_RUBBLE)
