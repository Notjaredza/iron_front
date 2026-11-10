class_name MapNature
extends RefCounted
## Iron Front map round 3 (Asset Builder Chat, 2026-11-10): what grows and flows on the stepped map.
## Runs after MapGen has made the ground, rivers, ramps, rails, places and the keep-clear mask (MapData.busy).
## - Water depth: wdepth, the distance of each water cell from its bank (1 to 7 cells).
## - Fords: 3-5 per river where a straight crossing fits, plus more if a stretch of land is still cut off.
##   Deep water blocks armies; fords, streams and marsh are walkable (slow).
## - Streams: small (1-2 cells), from high in the base land down to the nearest water.
## - Marsh: boggy shores round some lakes.
## - Fields round the villages (wheat, green crop, ploughed, hay), some with hedgerows, and hedgerows across the land.
## - Woods (about 20 % of the land), tall grass patches and lone trees.
## Everything is flags in MapData.feat (+ crop); the mesher and the views draw them.

const FORD_W := 3                 # cells wide
const FORD_MAX_SPAN := 22         # cells, bank to bank
const STREAMS := 14
const WOOD_SHARE := 0.20
const TALL_SHARE := 0.08
const MARSH_REACH := 5            # cells from the lake
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var d: MapData
var rng: RandomNumberGenerator
var river_paths: Array
var river_mask := PackedByteArray()    # coarse blocks on a river


static func run(data: MapData, r: RandomNumberGenerator, paths: Array) -> void:
	var m := MapNature.new()
	m.d = data
	m.rng = r
	m.river_paths = paths
	m._run()


func _run() -> void:
	var n := d.w * d.h
	d.feat = PackedByteArray()
	d.feat.resize(n)
	d.crop = PackedByteArray()
	d.crop.resize(n)
	d.fords.clear()
	d.streams.clear()
	river_mask.resize(d.cw * d.ch)
	for p: PackedInt32Array in river_paths:
		for i in p:
			river_mask[i] = 1
	var t := Time.get_ticks_msec()
	_depth()
	var s := "depth %d" % (Time.get_ticks_msec() - t)
	t = Time.get_ticks_msec()
	_fords()
	s += ", fords %d" % (Time.get_ticks_msec() - t)
	t = Time.get_ticks_msec()
	_streams()
	s += ", streams %d" % (Time.get_ticks_msec() - t)
	t = Time.get_ticks_msec()
	_marsh()
	s += ", marsh %d" % (Time.get_ticks_msec() - t)
	t = Time.get_ticks_msec()
	_fields()
	s += ", fields %d" % (Time.get_ticks_msec() - t)
	t = Time.get_ticks_msec()
	_woods()
	s += ", woods %d" % (Time.get_ticks_msec() - t)
	d.notes.append("nature ms: " + s)


func _i(x: int, z: int) -> int:
	return z * d.w + x


func _in(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < d.w and z < d.h


## Dry flat open ground: not water, cliff, busy, or any feature in mask.
func _open(i: int, mask: int) -> bool:
	var f := d.walk[i]
	return f != 0 and f != MapData.FLAT_NONE and d.busy[i] == 0 and (d.feat[i] & mask) == 0


# ------------------------------------------------------------------------------------------------- water depth

func _depth() -> void:
	var n := d.w * d.h
	d.wdepth = PackedByteArray()
	d.wdepth.resize(n)
	var q := PackedInt32Array()
	for z in d.h:
		var row := z * d.w
		for x in d.w:
			if d.walk[row + x] != 0:
				continue
			var shore := false
			for o: Vector2i in DIRS4:
				var nx := x + o.x
				var nz := z + o.y
				if _in(nx, nz) and d.walk[nz * d.w + nx] != 0:
					shore = true
					break
			if shore:
				d.wdepth[row + x] = 1
				q.append(row + x)
	var head := 0
	while head < q.size():
		var j := q[head]
		head += 1
		var dv := d.wdepth[j]
		if dv >= 7:
			continue
		var x := j % d.w
		var z := j / d.w
		for o: Vector2i in DIRS4:
			var nx := x + o.x
			var nz := z + o.y
			if not _in(nx, nz):
				continue
			var k := nz * d.w + nx
			if d.walk[k] == 0 and d.wdepth[k] == 0:
				d.wdepth[k] = dv + 1
				q.append(k)
	# Water cells nothing reached (open water far from any bank) are deep.
	for i in n:
		if d.walk[i] == 0 and d.wdepth[i] == 0:
			d.wdepth[i] = 7


# ------------------------------------------------------------------------------------------------------- fords

## A ford across the river at block (bx, by): axis 0 crosses along x, 1 along z. Returns the ford or {}.
func _try_ford(bx: int, by: int, axis: int, river: int) -> Dictionary:
	return _try_ford_at(Vector2i(bx * MapData.BLOCK + 2, by * MapData.BLOCK + 2), axis, river, 600.0)


## A ford whose middle lane crosses water cell c. Fords keep gap metres apart.
func _try_ford_at(c: Vector2i, axis: int, river: int, gap: float) -> Dictionary:
	var a0 := (c.y if axis == 0 else c.x) - 1
	var e_lo := -1
	var e_hi := -1
	for l in range(a0, a0 + FORD_W):
		var mid := c.x if axis == 0 else c.y
		if _cell(axis, mid, l) != 0:
			return {}
		var hi := _bank(axis, mid, l, 1)
		var lo := _bank(axis, mid, l, -1)
		if hi < 0 or lo < 0:
			return {}
		if e_hi < 0:
			e_hi = hi
			e_lo = lo
		elif hi != e_hi or lo != e_lo:
			return {}
	if e_hi - e_lo > FORD_MAX_SPAN or e_hi - e_lo < 3:
		return {}
	# Keep fords apart.
	var mid_m := (Vector2(float(e_lo + e_hi) * 0.5 + 0.5, float(a0) + FORD_W * 0.5)) * MapData.CELL
	if axis == 1:
		mid_m = Vector2(mid_m.y, mid_m.x)
	for f: Dictionary in d.fords:
		if ((f["p0"] as Vector2) + (f["p1"] as Vector2)).distance_to(mid_m * 2.0) < 2.0 * gap:
			return {}
	var cc := MapData.CELL
	var p0 := Vector2((e_lo + 0.5) * cc, (a0 + FORD_W * 0.5) * cc)
	var p1 := Vector2((e_hi + 0.5) * cc, (a0 + FORD_W * 0.5) * cc)
	if axis == 1:
		p0 = Vector2(p0.y, p0.x)
		p1 = Vector2(p1.y, p1.x)
	var ford := {"p0": p0, "p1": p1, "dir": (p1 - p0).normalized(), "w": FORD_W * cc, "river": river,
		"axis": axis, "a": a0, "e0": e_lo, "e1": e_hi}
	for l in range(a0 - 1, a0 + FORD_W + 1):
		for k in range(e_lo - 1, e_hi + 2):
			var x := k if axis == 0 else l
			var z := l if axis == 0 else k
			if _in(x, z):
				d.feat[_i(x, z)] |= MapData.F_FORD
	return ford


func _cell(axis: int, along: int, across: int) -> int:
	var x := along if axis == 0 else across
	var z := across if axis == 0 else along
	if not _in(x, z):
		return -1
	return d.walk[_i(x, z)]


func _busy_at(axis: int, along: int, across: int) -> bool:
	var x := along if axis == 0 else across
	var z := across if axis == 0 else along
	return not _in(x, z) or d.busy[_i(x, z)] == 1


## From a water cell, steps along the axis (dir +1/-1) to the bank: water, then exactly one cliff cell, then at
## least 3 flat base cells clear of rails and houses. Returns the cliff cell's index along the axis, or -1.
func _bank(axis: int, from: int, across: int, dir: int) -> int:
	var k := from
	for step in FORD_MAX_SPAN:
		k += dir
		var v := _cell(axis, k, across)
		if v == 0:
			continue
		if v != MapData.FLAT_NONE:
			return -1
		for j in range(1, 4):
			if _cell(axis, k + dir * j, across) != 1 or _busy_at(axis, k + dir * j, across):
				return -1
		return k
	return -1


func _fords() -> void:
	# 3-5 per river, spread along it.
	for r in river_paths.size():
		var path: PackedInt32Array = river_paths[r]
		var want := 3 + (1 if path.size() > 180 else 0) + (1 if path.size() > 300 else 0)
		for k in want:
			var target := int((float(k) + 0.5) / float(want) * path.size())
			for off in [0, 4, -4, 8, -8, 12, -12, 16, -16, 20, -20, 26, -26]:
				var j: int = target + off
				if j < 3 or j >= path.size() - 3:
					continue
				var f := _ford_at(path, j, r)
				if not f.is_empty():
					d.fords.append(f)
					break
	# Then join any land the rivers still cut off.
	var extra := 0
	for pass_n in 12:
		var lab := _land_comps()
		var labels: PackedInt32Array = lab[0]
		var count: int = lab[1]
		if count <= 1:
			break
		var sizes := PackedInt32Array()
		sizes.resize(count)
		for v in labels:
			if v >= 0:
				sizes[v] += 1
		var main := 0
		for c in count:
			if sizes[c] > sizes[main]:
				main = c
		var added := false
		for r in river_paths.size():
			var path: PackedInt32Array = river_paths[r]
			for j in range(3, path.size() - 3, 2):
				var pair := _sides(path, j, labels)
				if pair.is_empty() or pair[0] == pair[1] or (pair[0] != main and pair[1] != main):
					continue
				var f := _ford_at(path, j, r)
				if not f.is_empty():
					d.fords.append(f)
					extra += 1
					added = true
					break
			if added:
				break
		if not added:
			d.notes.append("fords: %d land areas still cut off by water" % (count - 1))
			break
	var isl := _islands()
	if isl > 0:
		d.notes.append("fords: %d more to reach small islands" % isl)
	d.notes.append("fords: %d (%d extra to join the land)" % [d.fords.size(), extra])


## Small base-level land areas that water still cuts off (islands in lakes, or between river arms) get a ford of
## their own to the land beside them. Base land here is walk 1, shore cells that are flat at level 1, and ford cells,
## the same rule the map check uses. Returns how many fords it added.
func _islands() -> int:
	var added := 0
	# One pass: each island joins straight to big land, so nothing needs a second look.
	for pass_n in 1:
		var n := d.w * d.h
		var lab := PackedInt32Array()
		lab.resize(n)
		lab.fill(-1)
		var base := PackedByteArray()
		base.resize(n)
		var walk := d.walk
		var feat := d.feat
		for i in n:
			var f := walk[i]
			if f == 1 or (feat[i] & MapData.F_FORD) != 0:
				base[i] = 1
			elif f == MapData.FLAT_NONE:
				var x := i % d.w
				var z := i / d.w
				var hi := maxi(maxi(d.corner(x, z), d.corner(x + 1, z)), maxi(d.corner(x, z + 1), d.corner(x + 1, z + 1)))
				var lo := mini(mini(d.corner(x, z), d.corner(x + 1, z)), mini(d.corner(x, z + 1), d.corner(x + 1, z + 1)))
				if hi <= 1 and lo >= 1:
					base[i] = 1
		var sizes := PackedInt32Array()
		var q := PackedInt32Array()
		var cells: Array = []
		for i in n:
			if base[i] == 0 or lab[i] >= 0:
				continue
			var c := sizes.size()
			q.clear()
			q.append(i)
			lab[i] = c
			var head := 0
			while head < q.size():
				var j := q[head]
				head += 1
				var x := j % d.w
				var z := j / d.w
				for o: Vector2i in DIRS4:
					var nx := x + o.x
					var nz := z + o.y
					if nx < 0 or nz < 0 or nx >= d.w or nz >= d.h:
						continue
					var k := nz * d.w + nx
					if base[k] == 1 and lab[k] < 0:
						lab[k] = c
						q.append(k)
			sizes.append(q.size())
			cells.append(q.duplicate() if q.size() < 4000 else PackedInt32Array())
		var made := false
		for c in sizes.size():
			# Only real areas (16+ cells) that are small; big ones are joined by ramps or river fords.
			if sizes[c] < 16 or sizes[c] >= 4000:
				continue
			var f := _island_ford(cells[c], lab, c, sizes)
			if not f.is_empty():
				d.fords.append(f)
				added += 1
				made = true
		if not made:
			break
	return added


## A ford from one of the island's shore cells straight across the water to other land, or {}.
func _island_ford(cells: PackedInt32Array, lab: PackedInt32Array, own: int, sizes: PackedInt32Array) -> Dictionary:
	for i in cells:
		var x := i % d.w
		var z := i / d.w
		for o: Vector2i in DIRS4:
			# Walk out over the shore cell(s) to the first water cell, two cells out from the bank.
			var k := 1
			while k < 4 and _in(x + o.x * k, z + o.y * k) and d.walk[_i(x + o.x * k, z + o.y * k)] != 0:
				k += 1
			var wx := x + o.x * (k + 1)
			var wz := z + o.y * (k + 1)
			if not _in(wx, wz) or d.walk[_i(wx, wz)] != 0:
				continue
			var axis := 0 if o.x != 0 else 1
			var f := _try_ford_at(Vector2i(wx, wz), axis, -1, 120.0)
			if f.is_empty():
				continue
			# The far end must be other land, not the island itself.
			var e: int = f["e1"] if (o.x + o.y) > 0 else f["e0"]
			var far_c := Vector2i(e + (o.x + o.y) * 2, int(f["a"]) + 1) if axis == 0 else Vector2i(int(f["a"]) + 1, e + (o.x + o.y) * 2)
			if not _in(far_c.x, far_c.y) or lab[_i(far_c.x, far_c.y)] < 0 or lab[_i(far_c.x, far_c.y)] == own or sizes[lab[_i(far_c.x, far_c.y)]] < 4000:
				_unmark_ford(f)
				continue
			return f
	return {}


func _unmark_ford(f: Dictionary) -> void:
	var ax: int = f["axis"]
	for l in range(int(f["a"]) - 1, int(f["a"]) + FORD_W + 1):
		for k in range(int(f["e0"]) - 1, int(f["e1"]) + 2):
			var x := k if ax == 0 else l
			var z := l if ax == 0 else k
			if _in(x, z):
				d.feat[_i(x, z)] &= ~MapData.F_FORD


func _axis_at(path: PackedInt32Array, j: int) -> int:
	var a := path[maxi(0, j - 3)]
	var b := path[mini(path.size() - 1, j + 3)]
	var dx := absi(b % d.cw - a % d.cw)
	var dy := absi(b / d.cw - a / d.cw)
	return 1 if dx > dy else 0


func _ford_at(path: PackedInt32Array, j: int, r: int) -> Dictionary:
	var i := path[j]
	return _try_ford(i % d.cw, i / d.cw, _axis_at(path, j), r)


## The land areas on the two sides of the river at path index j (coarse labels), or [].
func _sides(path: PackedInt32Array, j: int, labels: PackedInt32Array) -> Array:
	var i := path[j]
	var bx := i % d.cw
	var by := i / d.cw
	var ax := _axis_at(path, j)
	var dv := Vector2i(1, 0) if ax == 0 else Vector2i(0, 1)
	var out := []
	for s in [-1, 1]:
		var got := -1
		for k in range(1, 4):
			var x: int = bx + dv.x * k * s
			var y: int = by + dv.y * k * s
			if x < 0 or y < 0 or x >= d.cw or y >= d.ch:
				break
			if labels[y * d.cw + x] >= 0:
				got = labels[y * d.cw + x]
				break
		if got < 0:
			return []
		out.append(got)
	return out


## Coarse land areas (any level; ramps join the levels) with the fords counted as land. [labels, count].
func _land_comps() -> Array:
	var n := d.cw * d.ch
	var land := PackedByteArray()
	land.resize(n)
	for i in n:
		land[i] = 1 if d.coarse[i] != 0 else 0
	for f: Dictionary in d.fords:
		var steps := int((f["p0"] as Vector2).distance_to(f["p1"]) / 8.0) + 2
		for k in steps + 1:
			var p: Vector2 = (f["p0"] as Vector2).lerp(f["p1"], float(k) / float(steps))
			var bx := clampi(int(p.x / (MapData.CELL * MapData.BLOCK)), 0, d.cw - 1)
			var by := clampi(int(p.y / (MapData.CELL * MapData.BLOCK)), 0, d.ch - 1)
			land[by * d.cw + bx] = 1
	var labels := PackedInt32Array()
	labels.resize(n)
	labels.fill(-1)
	var count := 0
	var q := PackedInt32Array()
	for i in n:
		if land[i] == 0 or labels[i] >= 0:
			continue
		q.clear()
		q.append(i)
		labels[i] = count
		var head := 0
		while head < q.size():
			var j := q[head]
			head += 1
			var x := j % d.cw
			var y := j / d.cw
			for o: Vector2i in DIRS4:
				var nx := x + o.x
				var ny := y + o.y
				if nx < 0 or ny < 0 or nx >= d.cw or ny >= d.ch:
					continue
				var k := ny * d.cw + nx
				if land[k] == 1 and labels[k] < 0:
					labels[k] = count
					q.append(k)
		count += 1
	return [labels, count]


# ----------------------------------------------------------------------------------------------------- streams

func _streams() -> void:
	var n := d.cw * d.ch
	# Coarse distance to water over base-level land.
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var q := PackedInt32Array()
	for i in n:
		if d.coarse[i] == 0:
			dist[i] = 0
			q.append(i)
	var head := 0
	while head < q.size():
		var j := q[head]
		head += 1
		var x := j % d.cw
		var y := j / d.cw
		for o: Vector2i in DIRS4:
			var nx := x + o.x
			var ny := y + o.y
			if nx < 0 or ny < 0 or nx >= d.cw or ny >= d.ch:
				continue
			var k := ny * d.cw + nx
			if dist[k] < 0 and d.coarse[k] == 1:
				dist[k] = dist[j] + 1
				q.append(k)
	var starts: Array[int] = []
	for i in n:
		if dist[i] >= 7 and dist[i] <= 22:
			starts.append(i)
	var made := 0
	var used := PackedByteArray()
	used.resize(n)
	for tries in 400:
		if made >= STREAMS or starts.is_empty():
			break
		var i: int = starts[rng.randi() % starts.size()]
		if used[i] == 1:
			continue
		# Walk down the distance field to the water, wandering a little.
		var path: Array[int] = [i]
		var cur := i
		var last := Vector2i.ZERO
		var ok := true
		while dist[cur] > 0:
			var x := cur % d.cw
			var y := cur / d.cw
			var best := -1
			var best_s := INF
			for o: Vector2i in DIRS4:
				var nx := x + o.x
				var ny := y + o.y
				if nx < 0 or ny < 0 or nx >= d.cw or ny >= d.ch:
					continue
				var k := ny * d.cw + nx
				if dist[k] < 0 or dist[k] >= dist[cur]:
					continue
				var sc := rng.randf() + (0.0 if o == last else 0.35)
				if sc < best_s:
					best_s = sc
					best = k
					if dist[k] == 0:
						best_s = -1.0
			if best < 0:
				ok = false
				break
			last = Vector2i(best % d.cw - x, best / d.cw - y)
			cur = best
			if used[cur] == 1:
				break
			path.append(cur)
		if not ok or path.size() < 6:
			continue
		for k in path:
			used[k] = 1
		# A wavy line through the block centres, smoothed, then cut into the cells.
		var pts := PackedVector2Array()
		var bm := MapData.CELL * MapData.BLOCK
		for k in path.size():
			var b: int = path[k]
			var jit := Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * bm if k > 0 and k < path.size() - 1 else Vector2.ZERO
			pts.append((Vector2(b % d.cw, b / d.cw) + Vector2(0.5, 0.5)) * bm + jit)
		for it in 3:
			pts = _chaikin(pts)
		var wide := rng.randf() < 0.4
		_cut_stream(pts, 0.75 if wide else 0.45)
		d.streams.append(pts)
		made += 1
	d.notes.append("streams: %d" % made)


static func _chaikin(p: PackedVector2Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	o.append(p[0])
	for k in p.size() - 1:
		o.append(p[k].lerp(p[k + 1], 0.25))
		o.append(p[k].lerp(p[k + 1], 0.75))
	o.append(p[p.size() - 1])
	return o


## Marks the cells within r cells of the line as stream (dry flat base ground only, clear of rails and houses).
func _cut_stream(pts: PackedVector2Array, r: float) -> void:
	var c := MapData.CELL
	for k in range(1, pts.size()):
		var a := pts[k - 1]
		var b := pts[k]
		var steps := int(a.distance_to(b) / 2.0) + 1
		for s in steps + 1:
			var p := a.lerp(b, float(s) / float(steps)) / c
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var x := int(floor(p.x)) + dx
					var z := int(floor(p.y)) + dz
					if not _in(x, z):
						continue
					if Vector2(x + 0.5, z + 0.5).distance_to(p) > r + 0.5:
						continue
					var i := _i(x, z)
					if d.walk[i] == 1 and d.busy[i] == 0:
						d.feat[i] |= MapData.F_STREAM


# ------------------------------------------------------------------------------------------------------- marsh

func _marsh() -> void:
	var nz := _noise_img(31, 0.012)
	# Land within MARSH_REACH cells of lake water (not river), where the patch noise says so.
	var reach := PackedByteArray()
	reach.resize(d.w * d.h)
	var q := PackedInt32Array()
	for z in d.h:
		for x in d.w:
			var i := _i(x, z)
			if d.walk[i] == 0 and d.wdepth[i] == 1:
				var b := (z / MapData.BLOCK) * d.cw + x / MapData.BLOCK
				if river_mask[b] == 0:
					reach[i] = 1
					q.append(i)
	var head := 0
	while head < q.size():
		var j := q[head]
		head += 1
		if reach[j] > MARSH_REACH:
			continue
		var x := j % d.w
		var z := j / d.w
		for o: Vector2i in DIRS4:
			var nx := x + o.x
			var nzz := z + o.y
			if not _in(nx, nzz):
				continue
			var k := _i(nx, nzz)
			if reach[k] == 0 and d.walk[k] != 0 and d.walk[k] != 2 and d.walk[k] != 3:
				reach[k] = reach[j] + 1
				q.append(k)
	var count := 0
	for i in d.w * d.h:
		if reach[i] >= 2 and d.walk[i] == 1 and d.busy[i] == 0:
			var v := float(nz[i]) / 255.0
			if v - 0.08 * float(reach[i]) > 0.25:
				d.feat[i] |= MapData.F_MARSH
				count += 1
	d.notes.append("marsh: %d cells" % count)


func _noise_img(add: int, freq: float) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.seed = d.seed * 13 + add
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	n.frequency = freq
	var img := n.get_image(d.w, d.h, false, false, true)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


# ------------------------------------------------------------------------------------------------------ fields

func _fields() -> void:
	var nf := 0
	for p: Dictionary in d.places:
		if p["kind"] != "village":
			continue
		var c: Vector2 = p["pos"]
		var cx := int(c.x / MapData.CELL)
		var cz := int(c.y / MapData.CELL)
		var lvl: int = p["level"]
		var want := rng.randi_range(5, 9)
		for tries in 60:
			if want <= 0:
				break
			var a := rng.randf() * TAU
			var r := rng.randf_range(9.0, 22.0)
			var fw := rng.randi_range(5, 11)
			var fh := rng.randi_range(4, 9)
			var x0 := cx + int(cos(a) * r) - fw / 2
			var z0 := cz + int(sin(a) * r) - fh / 2
			if _field_ok(x0, z0, fw, fh, lvl):
				var kind := rng.randi_range(1, 4)
				var hedge := rng.randf() < 0.45
				for z in range(z0, z0 + fh):
					for x in range(x0, x0 + fw):
						var i := _i(x, z)
						d.feat[i] |= MapData.F_FIELD
						d.crop[i] = kind
						if hedge and (x == x0 or z == z0 or x == x0 + fw - 1 or z == z0 + fh - 1):
							d.feat[i] |= MapData.F_HEDGE
				want -= 1
				nf += 1
	# Hedgerows across the open base land: short wandering lines.
	var hedges := 0
	for tries in 900:
		if hedges >= 90:
			break
		var x := rng.randi_range(4, d.w - 5)
		var z := rng.randi_range(4, d.h - 5)
		if not _open(_i(x, z), MapData.F_STREAM | MapData.F_MARSH | MapData.F_FIELD) or d.walk[_i(x, z)] != 1:
			continue
		var dir := DIRS4[rng.randi() % 4] as Vector2i
		var len := rng.randi_range(10, 30)
		for k in len:
			if not _in(x, z) or not _open(_i(x, z), MapData.F_STREAM | MapData.F_MARSH | MapData.F_FIELD):
				break
			d.feat[_i(x, z)] |= MapData.F_HEDGE
			if rng.randf() < 0.12:
				dir = Vector2i(dir.y, dir.x) * (1 if rng.randf() < 0.5 else -1)
			x += dir.x
			z += dir.y
		hedges += 1
	d.notes.append("fields: %d, hedgerows: %d" % [nf, hedges])


func _field_ok(x0: int, z0: int, fw: int, fh: int, lvl: int) -> bool:
	for z in range(z0 - 1, z0 + fh + 1):
		for x in range(x0 - 1, x0 + fw + 1):
			if not _in(x, z):
				return false
			var i := _i(x, z)
			if d.walk[i] != lvl or d.busy[i] == 1 or (d.feat[i] & (MapData.F_STREAM | MapData.F_MARSH | MapData.F_FIELD | MapData.F_FORD)) != 0:
				return false
	return true


# ------------------------------------------------------------------------------------------------------- woods

func _woods() -> void:
	var n := d.w * d.h
	var wn := _noise_img(41, 0.006)
	var tn := _noise_img(53, 0.02)
	var blocked := MapData.F_STREAM | MapData.F_FIELD | MapData.F_FORD | MapData.F_MARSH
	# Local copies: reading arrays through the MapData object for 1.5 M cells is slow.
	var walk := d.walk
	var busy := d.busy
	var feat := d.feat
	var open := PackedByteArray()
	open.resize(n)
	# Thresholds that give the wanted shares of the open land.
	var hist := PackedInt32Array()
	hist.resize(256)
	var hist2 := PackedInt32Array()
	hist2.resize(256)
	var land := 0
	for i in n:
		var f := walk[i]
		if f != 0 and f != MapData.FLAT_NONE and busy[i] == 0 and (feat[i] & blocked) == 0:
			open[i] = 1
			hist[wn[i]] += 1
			hist2[tn[i]] += 1
			land += 1
	var tw := _cut(hist, land, WOOD_SHARE)
	var tt := _cut(hist2, land, TALL_SHARE)
	var wood := 0
	var tall := 0
	var lone := 0
	var seed := d.seed
	for i in n:
		if open[i] == 0:
			continue
		# Woods keep a cell off the houses and rails (busy is already off), and off the hedge lines.
		var k := hash(i * 7 + seed)
		var ft := feat[i]
		if wn[i] + (k % 1000) * 6 / 1000 - 3 >= tw and (ft & MapData.F_HEDGE) == 0:
			ft |= MapData.F_WOOD
			wood += 1
		elif tn[i] >= tt:
			ft |= MapData.F_TALL
			tall += 1
		if (ft & MapData.F_WOOD) == 0 and (k / 1000) % 1000 < 4:
			ft |= MapData.F_TREE
			lone += 1
		feat[i] = ft
	# Trees along the streams.
	for i in n:
		if (feat[i] & MapData.F_STREAM) == 0:
			continue
		var x := i % d.w
		var z := i / d.w
		for o: Vector2i in DIRS4:
			var nx := x + o.x * 2
			var nz := z + o.y * 2
			if not _in(nx, nz):
				continue
			var j := _i(nx, nz)
			if open[j] == 1 and (feat[j] & MapData.F_WOOD) == 0 and hash(i * 13 + o.x * 5 + o.y) % 100 < 6:
				feat[j] |= MapData.F_TREE
				lone += 1
	d.feat = feat
	d.notes.append("woods %.1f %% of open land, tall grass %.1f %%, %d lone trees" % [100.0 * wood / maxf(land, 1), 100.0 * tall / maxf(land, 1), lone])


static func _cut(hist: PackedInt32Array, total: int, share: float) -> int:
	var acc := 0
	for v in range(255, -1, -1):
		acc += hist[v]
		if acc >= total * share:
			return v
	return 0
