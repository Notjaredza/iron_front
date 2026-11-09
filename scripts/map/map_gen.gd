class_name MapGen
extends RefCounted
## Iron Front: makes a stepped map from a seed (MAP_PLAN.md).
## 1. The rough shape on 32 m blocks: plateaus (level 2) on about a third of the map, level 3 inside them, and lakes
##    and rivers on the base.
## 2. Chamfer it into the 8 m corner field: block corners are cut or filled by 1-3 cells, which gives 45 degree edges.
## 3. Ramps join every area. Unjoinable areas are lowered or filled, then the field is rebuilt.
## 4. The old rail lines (A* on blocks, pulled straight, curved at the bends), then villages, ruins and stations.

const PLATEAU_SHARE := 0.33
const L3_SHARE := 0.3            # share of the plateau area raised to level 3
const LAKE_SHARE := 0.03
const MIN_PLATEAU := 10          # blocks
const MIN_L3 := 6
const MIN_LAKE := 5
const RAMP_SPACING := 6          # blocks between ramps
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var d: MapData
var rng := RandomNumberGenerator.new()
var lv := PackedByteArray()      # coarse levels with water counted as the base (1)
var comp := PackedInt32Array()
var comp_size := PackedInt32Array()
var comp_level := PackedByteArray()
var rail_mask := PackedByteArray()
var lowered := Rect2i()            # blocks lowered or filled by the last _ramps()


static func generate(seed: int, w := 1000, h := 1500) -> MapData:
	var g := MapGen.new()
	return g._run(seed, w, h)


func _run(seed: int, w: int, h: int) -> MapData:
	var t0 := Time.get_ticks_msec()
	d = MapData.new()
	d.seed = seed
	d.w = w
	d.h = h
	d.cw = w / MapData.BLOCK
	d.ch = h / MapData.BLOCK
	rng.seed = seed
	var tt := Time.get_ticks_msec()
	_shape()
	_water()
	var stages := "shape+water %d" % (Time.get_ticks_msec() - tt)
	tt = Time.get_ticks_msec()
	var joined := false
	var region := Rect2i(-1, -1, 0, 0)
	for attempt in 8:
		tt = Time.get_ticks_msec()
		_fine_field(region)
		stages += ", field %d" % (Time.get_ticks_msec() - tt)
		tt = Time.get_ticks_msec()
		var ok_r := _ramps()
		stages += ", ramps %d" % (Time.get_ticks_msec() - tt)
		if ok_r:
			joined = true
			break
		region = lowered
	if not joined:
		d.notes.append("ramps: areas still unjoined after 8 tries")
	tt = Time.get_ticks_msec()
	_rails()
	stages += ", rails %d" % (Time.get_ticks_msec() - tt)
	tt = Time.get_ticks_msec()
	_places()
	_busy()
	stages += ", places %d" % (Time.get_ticks_msec() - tt)
	d.notes.append("stages ms: " + stages)
	d.gen_ms = Time.get_ticks_msec() - t0
	d.notes.append("generated in %d ms: %d ramps, %d rail lines, %d places" % [d.gen_ms, d.ramps.size(), d.rails.size(), d.places.size()])
	return d


# ---------------------------------------------------------------------------------------------------- coarse shape

func _noise(seed_add: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = d.seed * 7 + seed_add
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.frequency = freq
	return n


func _shape() -> void:
	var n := d.cw * d.ch
	d.coarse.resize(n)
	var nz := _noise(1, 0.02, 4)
	var nz2 := _noise(2, 0.05, 2)
	var vals := PackedFloat32Array()
	vals.resize(n)
	for y in d.ch:
		for x in d.cw:
			vals[y * d.cw + x] = nz.get_noise_2d(x, y) + 0.25 * nz2.get_noise_2d(x, y)
	var s := vals.duplicate()
	s.sort()
	var t2: float = s[int(n * (1.0 - PLATEAU_SHARE))]
	for i in n:
		d.coarse[i] = 2 if vals[i] >= t2 else 1
	_clean(2, MIN_PLATEAU)
	# Level 3: the highest ground inside the plateaus, kept at least one block in from their edge.
	var dist := _cheb_dist(func(i: int) -> bool: return d.coarse[i] < 2)
	var elig := PackedFloat32Array()
	var area2 := 0
	for i in n:
		if d.coarse[i] >= 2:
			area2 += 1
			if dist[i] >= 2:
				elig.append(vals[i])
	if elig.size() > 0:
		elig.sort()
		var keep := minf(1.0, L3_SHARE * area2 / float(elig.size()))
		var t3: float = elig[clampi(int(elig.size() * (1.0 - keep)), 0, elig.size() - 1)]
		for i in n:
			if d.coarse[i] >= 2 and dist[i] >= 2 and vals[i] >= t3:
				d.coarse[i] = 3
	_clean(3, MIN_L3)


## Small areas of level >= t go down to t - 1, and small enclosed holes below t are filled up to t.
func _clean(t: int, min_size: int) -> void:
	var lab := _label(func(i: int) -> bool: return d.coarse[i] >= t)
	var labels: PackedInt32Array = lab[0]
	var sizes: PackedInt32Array = lab[1]
	for i in labels.size():
		if labels[i] >= 0 and sizes[labels[i]] < min_size:
			d.coarse[i] = t - 1
	lab = _label(func(i: int) -> bool: return d.coarse[i] < t)
	labels = lab[0]
	sizes = lab[1]
	var border: PackedByteArray = lab[2]
	for i in labels.size():
		var c := labels[i]
		if c >= 0 and sizes[c] < min_size and border[c] == 0:
			d.coarse[i] = t


## 4-connected areas of the blocks where pred is true: [labels (-1 outside), sizes, touches the map edge].
func _label(pred: Callable) -> Array:
	var n := d.cw * d.ch
	var labels := PackedInt32Array()
	labels.resize(n)
	labels.fill(-1)
	var inside := PackedByteArray()
	inside.resize(n)
	for i in n:
		inside[i] = 1 if pred.call(i) else 0
	var sizes := PackedInt32Array()
	var border := PackedByteArray()
	var q := PackedInt32Array()
	for i in n:
		if inside[i] == 0 or labels[i] >= 0:
			continue
		var c := sizes.size()
		sizes.append(0)
		border.append(0)
		q.clear()
		q.append(i)
		labels[i] = c
		var head := 0
		while head < q.size():
			var j := q[head]
			head += 1
			sizes[c] += 1
			var x := j % d.cw
			var y := j / d.cw
			if x == 0 or y == 0 or x == d.cw - 1 or y == d.ch - 1:
				border[c] = 1
			for dv: Vector2i in DIRS4:
				var nx := x + dv.x
				var ny := y + dv.y
				if nx < 0 or ny < 0 or nx >= d.cw or ny >= d.ch:
					continue
				var k := ny * d.cw + nx
				if inside[k] == 1 and labels[k] < 0:
					labels[k] = c
					q.append(k)
	return [labels, sizes, border]


## Chebyshev distance (in blocks) to the nearest block where src is true (8-neighbour flood).
func _cheb_dist(src: Callable) -> PackedInt32Array:
	var n := d.cw * d.ch
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(1 << 20)
	var q := PackedInt32Array()
	for i in n:
		if src.call(i):
			dist[i] = 0
			q.append(i)
	var head := 0
	while head < q.size():
		var j := q[head]
		head += 1
		var x := j % d.cw
		var y := j / d.cw
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= d.cw or ny >= d.ch:
					continue
				var k := ny * d.cw + nx
				if dist[k] > dist[j] + 1:
					dist[k] = dist[j] + 1
					q.append(k)
	return dist


# ---------------------------------------------------------------------------------------------------------- water

func _water() -> void:
	var n := d.cw * d.ch
	var dist := _cheb_dist(func(i: int) -> bool: return d.coarse[i] >= 2)
	# Lakes: blobs on the base, at least one block clear of any plateau.
	var nz := _noise(3, 0.045, 3)
	var vals := PackedFloat32Array()
	var idx := PackedInt32Array()
	for i in n:
		if d.coarse[i] == 1 and dist[i] >= 2:
			vals.append(nz.get_noise_2d(i % d.cw, i / d.cw))
			idx.append(i)
	if vals.size() > 0:
		var s := vals.duplicate()
		s.sort()
		var keep := minf(1.0, LAKE_SHARE * n / float(vals.size()))
		var t: float = s[clampi(int(s.size() * (1.0 - keep)), 0, s.size() - 1)]
		for k in vals.size():
			if vals[k] >= t:
				d.coarse[idx[k]] = 0
	var lab := _label(func(i: int) -> bool: return d.coarse[i] == 0)
	var labels: PackedInt32Array = lab[0]
	var sizes: PackedInt32Array = lab[1]
	for i in n:
		if labels[i] >= 0 and sizes[labels[i]] < MIN_LAKE:
			d.coarse[i] = 1
	# Rivers: a meandering 4-way path across the map that keeps a block clear of the plateaus.
	var mz := _noise(4, 0.08, 2)
	var cost := PackedFloat32Array()
	cost.resize(n)
	for i in n:
		cost[i] = -1.0 if dist[i] < 2 else 1.0 + 3.0 * (mz.get_noise_2d(i % d.cw, i / d.cw) + 1.0)
	var rivers := 2 if d.ch > 100 else 1
	for r in rivers:
		var vertical := r == 0
		var path := PackedInt32Array()
		for tries in 12:
			var start := -1
			if vertical:
				var x := rng.randi_range(d.cw / 5, d.cw * 4 / 5)
				start = x
			else:
				var y := rng.randi_range(d.ch / 5, d.ch * 4 / 5)
				start = y * d.cw
			if cost[start] < 0.0:
				continue
			var goal := PackedByteArray()
			goal.resize(n)
			for i in n:
				if (vertical and i / d.cw == d.ch - 1) or (not vertical and i % d.cw == d.cw - 1):
					goal[i] = 1
			path = _astar(start, goal, -1 if vertical else d.cw - 1, d.ch - 1 if vertical else -1, cost, false)
			if path.size() > 0:
				break
		var wide := false
		for k in path.size():
			var i := path[k]
			d.coarse[i] = 0
			if k % 40 == 0:
				wide = rng.randf() < 0.35
			if wide:
				var side := i + (1 if vertical else d.cw)
				if side < n and cost[side] >= 0.0 and (not vertical or side % d.cw != 0):
					d.coarse[side] = 0
		if path.size() > 0:
			d.notes.append("river %d: %d blocks" % [r, path.size()])


## A* on the blocks. cost < 0 blocks the way. The goal is a mask; the heuristic aims at column hx and/or row hy (-1
## ignores that axis). With diag, moves can be diagonal but never cut a blocked corner. Returns the path of indices.
func _astar(start: int, goal: PackedByteArray, hx: int, hy: int, cost: PackedFloat32Array, diag: bool) -> PackedInt32Array:
	var n := d.cw * d.ch
	var g := PackedFloat32Array()
	g.resize(n)
	g.fill(INF)
	var from := PackedInt32Array()
	from.resize(n)
	from.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n)
	var heap_k := PackedFloat32Array()
	var heap_v := PackedInt32Array()
	g[start] = 0.0
	_push(heap_k, heap_v, _heur(start, hx, hy), start)
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	if diag:
		dirs += [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	var found := -1
	while heap_v.size() > 0:
		var cur := _pop(heap_k, heap_v)
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		if goal[cur] == 1:
			found = cur
			break
		var x := cur % d.cw
		var y := cur / d.cw
		for dv: Vector2i in dirs:
			var nx := x + dv.x
			var ny := y + dv.y
			if nx < 0 or ny < 0 or nx >= d.cw or ny >= d.ch:
				continue
			var k := ny * d.cw + nx
			if cost[k] < 0.0 or closed[k] == 1:
				continue
			var step := 1.0
			if dv.x != 0 and dv.y != 0:
				if cost[y * d.cw + nx] < 0.0 or cost[ny * d.cw + x] < 0.0:
					continue
				step = 1.4142
			var ng := g[cur] + step * cost[k]
			if ng < g[k]:
				g[k] = ng
				from[k] = cur
				_push(heap_k, heap_v, ng + _heur(k, hx, hy), k)
	var path := PackedInt32Array()
	if found < 0:
		return path
	var c := found
	while c >= 0:
		path.append(c)
		c = from[c]
	path.reverse()
	return path


func _heur(i: int, hx: int, hy: int) -> float:
	var dx := 0 if hx < 0 else absi(i % d.cw - hx)
	var dy := 0 if hy < 0 else absi(i / d.cw - hy)
	return float(maxi(dx, dy)) + 0.4142 * float(mini(dx, dy))


static func _push(hk: PackedFloat32Array, hv: PackedInt32Array, k: float, v: int) -> void:
	hk.append(k)
	hv.append(v)
	var i := hk.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if hk[p] <= hk[i]:
			break
		var tk := hk[p]
		hk[p] = hk[i]
		hk[i] = tk
		var tv := hv[p]
		hv[p] = hv[i]
		hv[i] = tv
		i = p


static func _pop(hk: PackedFloat32Array, hv: PackedInt32Array) -> int:
	var top := hv[0]
	var last := hk.size() - 1
	hk[0] = hk[last]
	hv[0] = hv[last]
	hk.resize(last)
	hv.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < last and hk[l] < hk[m]:
			m = l
		if r < last and hk[r] < hk[m]:
			m = r
		if m == i:
			break
		var tk := hk[m]
		hk[m] = hk[i]
		hk[i] = tk
		var tv := hv[m]
		hv[m] = hv[i]
		hv[i] = tv
		i = m
	return top


# ----------------------------------------------------------------------------------------------------- fine field

func _cv(x: int, y: int, fallback: int) -> int:
	if x < 0 or y < 0 or x >= d.cw or y >= d.ch:
		return fallback
	return d.coarse[y * d.cw + x]


## The cut (or fill) size, 1-3 cells, of a block corner for threshold t.
func _cham(bx: int, by: int, k: int, t: int) -> int:
	var hv := hash(Vector4i(bx, by, k * 4 + t, d.seed)) % 100
	return 1 if hv < 35 else (2 if hv < 78 else 3)


func _fine_field(r0 := Rect2i(-1, -1, 0, 0)) -> void:
	var W1 := d.w + 1
	var cw := d.cw
	var chh := d.ch
	var coarse := d.coarse
	# The whole field, or just the blocks in r0 (grown by one) after areas were lowered or filled.
	var whole := r0.position.x < 0
	var field := PackedByteArray()
	if whole:
		field.resize(W1 * (d.h + 1))
	else:
		field = d.field
	var rb := Rect2i(0, 0, cw, chh) if whole else r0.grow(1).intersection(Rect2i(0, 0, cw, chh))
	var corners := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	# The 4 x 4 points each corner cut of size c covers (index k * 4 + c).
	var masks: Array[PackedByteArray] = []
	for k in 4:
		var s: Vector2i = corners[k]
		for c in 4:
			var m := PackedByteArray()
			m.resize(16)
			for ly in 4:
				for lx in 4:
					var ddx := lx if s.x < 0 else 3 - lx
					var ddy := ly if s.y < 0 else 3 - ly
					m[ly * 4 + lx] = 1 if ddx + ddy < c else 0
			masks.append(m)
	var pts := PackedByteArray()
	pts.resize(16)
	for by in range(rb.position.y, rb.end.y):
		for bx in range(rb.position.x, rb.end.x):
			var v := coarse[by * cw + bx]
			var x0 := bx * MapData.BLOCK
			var y0 := by * MapData.BLOCK
			var same := true
			for dy in range(-1, 2):
				var ny := by + dy
				if ny < 0 or ny >= chh:
					continue
				for dx in range(-1, 2):
					var nx := bx + dx
					if nx >= 0 and nx < cw and coarse[ny * cw + nx] != v:
						same = false
			if not same:
				# Per threshold, the corners cut (inside) or filled (outside); level = how many thresholds hold, in order.
				pts.fill(0)
				var any := false
				var member: Array[PackedByteArray] = []
				for t in range(1, 4):
					var inside := v >= t
					var m := PackedByteArray()
					m.resize(16)
					m.fill(1 if inside else 0)
					for k in 4:
						var s: Vector2i = corners[k]
						var a := _cv(bx + s.x, by, v) >= t
						var b := _cv(bx, by + s.y, v) >= t
						var c := _cv(bx + s.x, by + s.y, v) >= t
						if (inside and not a and not b and not c) or (not inside and a and b and c):
							any = true
							var mk: PackedByteArray = masks[k * 4 + _cham(bx, by, k, t)]
							for p in 16:
								if mk[p] == 1:
									m[p] = 0 if inside else 1
					member.append(m)
				if any:
					for p in 16:
						var level := 0
						for ti in 3:
							if member[ti][p] == 0:
								break
							level = ti + 1
						field[(y0 + p / 4) * W1 + x0 + p % 4] = level
					continue
			for ly in 4:
				var row := (y0 + ly) * W1 + x0
				for lx in 4:
					field[row + lx] = v
	# The last corner row and column copy their neighbours.
	for y in d.h:
		field[y * W1 + d.w] = field[y * W1 + d.w - 1]
	for x in W1:
		field[d.h * W1 + x] = field[(d.h - 1) * W1 + x]
	var walk := PackedByteArray()
	if whole:
		walk.resize(d.w * d.h)
	else:
		walk = d.walk
	var zy0 := maxi(0, rb.position.y * MapData.BLOCK - 1)
	var zy1 := mini(d.h, rb.end.y * MapData.BLOCK + 1)
	var xx0 := maxi(0, rb.position.x * MapData.BLOCK - 1)
	var xx1 := mini(d.w, rb.end.x * MapData.BLOCK + 1)
	for y in range(zy0, zy1):
		var q0 := y * W1
		var q1 := q0 + W1
		var wr := y * d.w
		for x in range(xx0, xx1):
			var a := field[q0 + x]
			if a == field[q0 + x + 1] and a == field[q1 + x] and a == field[q1 + x + 1]:
				walk[wr + x] = a
			else:
				walk[wr + x] = MapData.FLAT_NONE
	d.field = field
	d.walk = walk


# --------------------------------------------------------------------------------------------------------- ramps

## Places ramps so every area joins the main base area. Returns false (after lowering or filling the areas it could
## not join) when the field must be rebuilt.
func _ramps() -> bool:
	var n := d.cw * d.ch
	lv.resize(n)
	for i in n:
		lv[i] = maxi(1, d.coarse[i])
	var lab := _label_levels()
	comp = lab[0]
	comp_size = lab[1]
	comp_level = lab[2]
	var main := -1
	for c in comp_size.size():
		if comp_level[c] == 1 and (main < 0 or comp_size[c] > comp_size[main]):
			main = c
	# Every possible ramp site: a straight cliff edge between two blocks, with flat ground below for the run.
	var cands: Array = []
	for i in n:
		if lv[i] < 2:
			continue
		var ax := i % d.cw
		var ay := i / d.cw
		for dv: Vector2i in DIRS4:
			if _site_ok(ax, ay, dv):
				cands.append([i, dv, comp[i], comp[(ay + dv.y) * d.cw + ax + dv.x]])
	_shuffle(cands)
	d.ramps.clear()
	var placed: Array[Vector2i] = []
	var link: Array = []                                # pairs of areas joined
	# Flow ramps: a few down from each plateau area, by its size.
	var per: Dictionary = {}
	for c in cands:
		var ca: int = c[2]
		if not per.has(ca):
			per[ca] = []
		per[ca].append(c)
	for ca: int in per:
		var want := clampi(int(sqrt(float(comp_size[ca])) / 5.0) + 1, 1, 6)
		for c in per[ca]:
			if want <= 0:
				break
			if _add_ramp(c, placed, RAMP_SPACING):
				link.append([c[2], c[3]])
				want -= 1
	# Then join whatever is still cut off, area by area.
	var reached := _reach(main, link)
	var changed := true
	while changed:
		changed = false
		for c in cands:
			var a: int = c[2]
			var b: int = c[3]
			if reached[a] != reached[b] and _add_ramp(c, placed, 2):
				link.append([a, b])
				reached = _reach(main, link)
				changed = true
	var cut := 0
	lowered = Rect2i()
	for c in comp_size.size():
		if reached[c] == 0:
			cut += 1
			_flatten(c)
	if cut > 0:
		d.notes.append("ramps: %d areas could not be joined, lowered or filled" % cut)
		return false
	return true


func _label_levels() -> Array:
	var n := d.cw * d.ch
	var labels := PackedInt32Array()
	labels.resize(n)
	labels.fill(-1)
	var sizes := PackedInt32Array()
	var levels := PackedByteArray()
	var q := PackedInt32Array()
	for i in n:
		if labels[i] >= 0:
			continue
		var c := sizes.size()
		sizes.append(0)
		levels.append(lv[i])
		q.clear()
		q.append(i)
		labels[i] = c
		var head := 0
		while head < q.size():
			var j := q[head]
			head += 1
			sizes[c] += 1
			var x := j % d.cw
			var y := j / d.cw
			for dv: Vector2i in DIRS4:
				var nx := x + dv.x
				var ny := y + dv.y
				if nx < 0 or ny < 0 or nx >= d.cw or ny >= d.ch:
					continue
				var k := ny * d.cw + nx
				if labels[k] < 0 and lv[k] == lv[i]:
					labels[k] = c
					q.append(k)
	return [labels, sizes, levels]


func _lvq(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= d.cw or y >= d.ch:
		return -1
	return lv[y * d.cw + x]


func _site_ok(ax: int, ay: int, dv: Vector2i) -> bool:
	var t := _lvq(ax, ay)
	var p := Vector2i(dv.y, dv.x)
	for s in [-1, 0, 1]:
		var o: Vector2i = p * s
		if _lvq(ax + o.x, ay + o.y) != t:
			return false
		for k in [1, 2]:
			var bx: int = ax + dv.x * k + o.x
			var by: int = ay + dv.y * k + o.y
			if _lvq(bx, by) != t - 1 or d.coarse[by * d.cw + bx] == 0:
				return false
	# The fine field must agree: flat above, one clean edge cell, flat below for the whole run.
	return _fine_ok(_ramp_of(ax, ay, dv, 0, 4))


func _ramp_of(ax: int, ay: int, dv: Vector2i, off: int, wd: int) -> Dictionary:
	var axis := 0 if dv.x != 0 else 1
	var s := dv.x + dv.y
	var along := ax if axis == 0 else ay
	var across := ay if axis == 0 else ax
	return {"t": int(lv[ay * d.cw + ax]), "axis": axis, "s": s,
		"e": float(MapData.BLOCK * (along + (1 if s > 0 else 0))) - 0.5,
		"a": MapData.BLOCK * across + off, "w": wd}


func _fine_ok(r: Dictionary) -> bool:
	var t: int = r["t"]
	var s: int = r["s"]
	var ec := int(floor(float(r["e"])))
	for l in range(int(r["a"]), int(r["a"]) + int(r["w"])):
		if _walk_at(r, ec - s, l) != t:
			return false
		for k in range(1, 5):
			if _walk_at(r, ec + s * k, l) != t - 1:
				return false
	return true


func _walk_at(r: Dictionary, along: int, across: int) -> int:
	var x := along if int(r["axis"]) == 0 else across
	var z := across if int(r["axis"]) == 0 else along
	if x < 0 or z < 0 or x >= d.w or z >= d.h:
		return -1
	return d.walk[z * d.w + x]


func _add_ramp(c: Array, placed: Array[Vector2i], spacing: int) -> bool:
	var i: int = c[0]
	var at := Vector2i(i % d.cw, i / d.cw)
	for p in placed:
		if maxi(absi(p.x - at.x), absi(p.y - at.y)) < spacing:
			return false
	var wd := 1 if rng.randf() < 0.25 else rng.randi_range(2, 3)
	var off := rng.randi_range(0, MapData.BLOCK - wd)
	d.ramps.append(_ramp_of(at.x, at.y, c[1], off, wd))
	placed.append(at)
	return true


func _reach(main: int, link: Array) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(comp_size.size())
	if main < 0:
		return r
	r[main] = 1
	var changed := true
	while changed:
		changed = false
		for l in link:
			var a: int = l[0]
			var b: int = l[1]
			if r[a] != r[b]:
				r[a] = 1
				r[b] = 1
				changed = true
	return r


## An area no ramp can reach: a plateau goes down a level (with anything higher inside it), a hollow is filled.
func _flatten(c: int) -> void:
	var t := int(comp_level[c])
	var n := d.cw * d.ch
	if t == 1:
		for i in n:
			if comp[i] == c:
				d.coarse[i] = 2
				_mark(i)
		return
	var seen := PackedByteArray()
	seen.resize(n)
	var q := PackedInt32Array()
	for i in n:
		if comp[i] == c:
			q.append(i)
			seen[i] = 1
	var head := 0
	while head < q.size():
		var j := q[head]
		head += 1
		d.coarse[j] -= 1
		_mark(j)
		var x := j % d.cw
		var y := j / d.cw
		for dv: Vector2i in DIRS4:
			var nx := x + dv.x
			var ny := y + dv.y
			if nx < 0 or ny < 0 or nx >= d.cw or ny >= d.ch:
				continue
			var k := ny * d.cw + nx
			if seen[k] == 0 and lv[k] > t:
				seen[k] = 1
				q.append(k)


func _mark(i: int) -> void:
	var p := Vector2i(i % d.cw, i / d.cw)
	lowered = Rect2i(p, Vector2i.ONE) if lowered.size == Vector2i.ZERO else lowered.merge(Rect2i(p, Vector2i.ONE))


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# --------------------------------------------------------------------------------------------------------- rails

## Blocks an old line can use: the base all round (water counts, for bridges), off every ramp.
func _rail_cost() -> PackedFloat32Array:
	var n := d.cw * d.ch
	var cost := PackedFloat32Array()
	cost.resize(n)
	for i in n:
		var x := i % d.cw
		var y := i / d.cw
		var ok := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var v := _cv(x + dx, y + dy, 1)
				if v >= 2:
					ok = false
		cost[i] = (40.0 if d.coarse[i] == 0 else 1.0) if ok else -1.0     # bridges only where a line must cross
	return cost


func _rails() -> void:
	var n := d.cw * d.ch
	var cost := _rail_cost()
	rail_mask.resize(n)
	rail_mask.fill(0)
	d.rails.clear()
	var lines := [["ns", 0.35], ["we", 0.5], ["ns", 0.72]]
	var first_we := PackedInt32Array()
	for li in lines.size():
		var kind: String = lines[li][0]
		var frac: float = lines[li][1]
		var path := PackedInt32Array()
		for tries in 16:
			var start := -1
			var jitter := rng.randf_range(-0.12, 0.12)
			if kind == "ns":
				start = clampi(int(d.cw * (frac + jitter)), 1, d.cw - 2)
			else:
				start = clampi(int(d.ch * (frac + jitter)), 1, d.ch - 2) * d.cw
			if cost[start] < 0.0:
				continue
			var goal := PackedByteArray()
			goal.resize(n)
			var hx := -1
			var hy := -1
			if li == 2 and first_we.size() > 0:
				for i in first_we:
					goal[i] = 1
				hy = first_we[first_we.size() / 2] / d.cw
			elif kind == "ns":
				for x in d.cw:
					goal[(d.ch - 1) * d.cw + x] = 1
				hy = d.ch - 1
			else:
				for y in d.ch:
					goal[y * d.cw + d.cw - 1] = 1
				hx = d.cw - 1
			path = _astar(start, goal, hx, hy, cost, true)
			if path.size() > 0:
				break
		if path.size() < 2:
			d.notes.append("rail line %d: no way through" % li)
			continue
		if kind == "we" and first_we.size() == 0:
			first_we = path
		var pts := _pull(path, cost)
		pts = _curves(pts)
		var total := 0.0
		for k in range(1, pts.size()):
			total += pts[k].distance_to(pts[k - 1])
		var sections: Array = []
		var at := 0.0
		while at < total:
			var ln := rng.randf_range(300.0, 1200.0)
			sections.append({"from": at, "to": minf(total, at + ln), "broken": rng.randf() < 0.4})
			at += ln
		d.rails.append({"pts": pts, "sections": sections, "length": total})
		for i in path:
			rail_mask[i] = 1


## Pulls a block path straight: from each point, jump to the furthest later point in plain sight.
func _pull(path: PackedInt32Array, cost: PackedFloat32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := 0
	out.append(_bc(path[0]))
	while i < path.size() - 1:
		var best := i + 1
		var j := i + 2
		while j < path.size():
			if _sight(path[i], path[j], cost):
				best = j
			elif j - i > 6:
				break
			j += 1
		out.append(_bc(path[best]))
		i = best
	# Run the ends off the map edge so lines leave it cleanly.
	if out.size() >= 2:
		out[0] = _to_edge(out[0], out[0] - out[1])
		var last := out.size() - 1
		var to := path[path.size() - 1]
		var ex := to % d.cw
		var ey := to / d.cw
		if ex == d.cw - 1 or ey == d.ch - 1:
			out[last] = _to_edge(out[last], out[last] - out[last - 1])
	return out


func _bc(i: int) -> Vector2:
	var s := MapData.CELL * MapData.BLOCK
	return Vector2((i % d.cw + 0.5) * s, (i / d.cw + 0.5) * s)


func _to_edge(p: Vector2, dir: Vector2) -> Vector2:
	var sz := d.size_m()
	if absf(dir.x) > absf(dir.y):
		return Vector2(0.0 if dir.x < 0.0 else sz.x, p.y)
	return Vector2(p.x, 0.0 if dir.y < 0.0 else sz.y)


func _sight(a: int, b: int, cost: PackedFloat32Array) -> bool:
	var pa := Vector2(a % d.cw + 0.5, a / d.cw + 0.5)
	var pb := Vector2(b % d.cw + 0.5, b / d.cw + 0.5)
	var steps := int(pa.distance_to(pb) * 4.0) + 1
	for k in steps + 1:
		var p := pa.lerp(pb, float(k) / steps)
		for o in [Vector2(-0.3, -0.3), Vector2(0.3, 0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3)]:
			var q: Vector2 = p + o
			var x := int(q.x)
			var y := int(q.y)
			if x < 0 or y < 0 or x >= d.cw or y >= d.ch or cost[y * d.cw + x] < 0.0:
				return false
	return true


## Rounds each bend into a curve (a quadratic curve of up to about 350 m radius), checked against the fine ground.
func _curves(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i in range(1, pts.size() - 1):
		var a := pts[i - 1]
		var v := pts[i]
		var b := pts[i + 1]
		var u1 := (v - a).normalized()
		var u2 := (b - v).normalized()
		var ang := acos(clampf(u1.dot(u2), -1.0, 1.0))
		if ang < 0.02:
			out.append(v)
			continue
		var tl := minf(350.0 * tan(ang * 0.5), 0.45 * minf(a.distance_to(v), v.distance_to(b)))
		var arc := PackedVector2Array()
		for attempt in 4:
			arc.clear()
			var s := v - u1 * tl
			var e := v + u2 * tl
			var steps := clampi(int(tl / 12.0), 3, 24)
			var ok := true
			for k in steps + 1:
				var t := float(k) / steps
				var p := s.lerp(v, t).lerp(v.lerp(e, t), t)
				if not _rail_ground_ok(p):
					ok = false
					break
				arc.append(p)
			if ok:
				break
			tl *= 0.5
			arc.clear()
		if arc.size() == 0:
			out.append(v)
		else:
			out.append_array(arc)
	out.append(pts[pts.size() - 1])
	return out


func _rail_ground_ok(p: Vector2) -> bool:
	for o in [Vector2.ZERO, Vector2(3, 3), Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3)]:
		var q: Vector2 = p + o
		var x := clampi(int(q.x / MapData.CELL), 0, d.w - 1)
		var z := clampi(int(q.y / MapData.CELL), 0, d.h - 1)
		for cz in [z, z + 1]:
			for cx in [x, x + 1]:
				if d.field[mini(cz, d.h) * (d.w + 1) + mini(cx, d.w)] >= 2:
					return false
	return true


# ------------------------------------------------------------------------------------------------- places on the map

func _places() -> void:
	var n := d.cw * d.ch
	d.places.clear()
	# Blocks kept clear: ramps and their run, and rail blocks.
	var reserved := PackedByteArray()
	reserved.resize(n)
	for r in d.ramps:
		var ca := int(float(r["e"]) + 0.5) / MapData.BLOCK
		var cb := int(r["a"]) / MapData.BLOCK
		for k in range(-2, 3):
			for s in range(-1, 2):
				var along: int = ca + k
				var x := along if int(r["axis"]) == 0 else cb + s
				var y := cb + s if int(r["axis"]) == 0 else along
				if x >= 0 and y >= 0 and x < d.cw and y < d.ch:
					reserved[y * d.cw + x] = 1
	var rail_dist := _cheb_dist(func(i: int) -> bool: return rail_mask[i] == 1)
	var cands: Array = []
	for y in range(2, d.ch - 2):
		for x in range(2, d.cw - 2):
			var i := y * d.cw + x
			var v := d.coarse[i]
			if v == 0 or v == 3 or reserved[i] == 1 or rail_dist[i] < 2:
				continue
			var ok := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var k := (y + dy) * d.cw + x + dx
					if d.coarse[k] != v or reserved[k] == 1 or rail_mask[k] == 1:
						ok = false
			if ok:
				cands.append(i)
	_shuffle(cands)
	var area_km2 := d.size_m().x * d.size_m().y / 1.0e6
	var n_vil := maxi(2, roundi(area_km2 / 9.6))
	var n_ruin := maxi(2, roundi(area_km2 / 12.0))
	var taken: Array[Vector2i] = []
	# Villages by the rails first (they get a station), then anywhere; then ruins.
	for pass_i in 3:
		var want := n_vil / 2 if pass_i == 0 else (n_vil - _count("village") if pass_i == 1 else n_ruin)
		for i: int in cands:
			if want <= 0:
				break
			var at := Vector2i(i % d.cw, i / d.cw)
			if pass_i == 0 and (rail_dist[i] > 6 or d.coarse[i] != 1):
				continue
			var far := true
			for p in taken:
				if maxi(absi(p.x - at.x), absi(p.y - at.y)) < (28 if pass_i < 2 else 22):
					far = false
					break
			if not far:
				continue
			var kind := "ruin" if pass_i == 2 else "village"
			if _settle(at, kind, rail_dist[i] <= 6 and d.coarse[i] == 1 and kind == "village"):
				taken.append(at)
				want -= 1


## Cells ground detail keeps off: along the rail lines, round houses and platforms, and on the ramps.
func _busy() -> void:
	_bz = PackedByteArray()
	_bz.resize(d.w * d.h)
	for rl in d.rails:
		var pts: PackedVector2Array = rl["pts"]
		for k in range(1, pts.size()):
			var a := pts[k - 1]
			var b := pts[k]
			var n := int(a.distance_to(b) / 4.0) + 1
			for i in n + 1:
				_mark_busy(a.lerp(b, float(i) / n), 0)
	for p in d.places:
		for hd in p["houses"]:
			var hp: Vector3 = hd["pos"]
			var sz: Vector2 = hd["size"]
			_mark_busy(Vector2(hp.x, hp.z), 1 if maxf(sz.x, sz.y) < 20.0 else 3)
	for r in d.ramps:
		var e: float = r["e"]
		var s: int = r["s"]
		for k in range(-1, 6):
			for l in range(int(r["a"]) - 1, int(r["a"]) + int(r["w"]) + 1):
				var along := int(floor(e)) + s * k
				var x := along if int(r["axis"]) == 0 else l
				var z := l if int(r["axis"]) == 0 else along
				if x >= 0 and z >= 0 and x < d.w and z < d.h:
					_bz[z * d.w + x] = 1
	d.busy = _bz
	_bz = PackedByteArray()


var _bz := PackedByteArray()


func _mark_busy(p: Vector2, r: int) -> void:
	var cx := int(p.x / MapData.CELL)
	var cz := int(p.y / MapData.CELL)
	for z in range(cz - r, cz + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and z >= 0 and x < d.w and z < d.h:
				_bz[z * d.w + x] = 1


func _count(kind: String) -> int:
	var c := 0
	for p in d.places:
		if p["kind"] == kind:
			c += 1
	return c


## Lays out one settlement on the 3 x 3 blocks round `at` (houses on the 8 m grid), with a station by the nearest
## rail line when asked.
func _settle(at: Vector2i, kind: String, station: bool) -> bool:
	var level := int(d.coarse[at.y * d.cw + at.x])
	var gy := MapData.level_y(level)
	var x0 := (at.x - 1) * MapData.BLOCK
	var z0 := (at.y - 1) * MapData.BLOCK
	var span := 3 * MapData.BLOCK
	var occ := PackedByteArray()
	occ.resize(span * span)
	var houses: Array = []
	var want := rng.randi_range(6, 12) if kind == "village" else rng.randi_range(4, 8)
	var tries := 0
	while houses.size() < want and tries < 80:
		tries += 1
		var lx := rng.randi_range(1, span - 2)
		var lz := rng.randi_range(1, span - 2)
		var long := rng.randf() < 0.4
		var along_x := rng.randf() < 0.5
		var cells := [Vector2i(lx, lz)]
		if long:
			cells.append(Vector2i(lx + (1 if along_x else 0), lz + (0 if along_x else 1)))
		var ok := true
		for c: Vector2i in cells:
			if c.x >= span - 1 or c.y >= span - 1 or occ[c.y * span + c.x] == 1:
				ok = false
			elif d.walk[(z0 + c.y) * d.w + x0 + c.x] != level:
				ok = false
		if not ok:
			continue
		var centre := Vector2.ZERO
		for c: Vector2i in cells:
			occ[c.y * span + c.x] = 1
			centre += Vector2(x0 + c.x + 0.5, z0 + c.y + 0.5) * MapData.CELL
		centre /= cells.size()
		if _rail_near(centre, 10.0):
			continue
		# A one-cell gap round each house keeps lanes open.
		for c: Vector2i in cells:
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var ox: int = c.x + dx
					var oz: int = c.y + dz
					if ox >= 0 and oz >= 0 and ox < span and oz < span and rng.randf() < 0.6:
						occ[oz * span + ox] = 1
		var size := Vector2(6.0, 13.0 if long else 6.5)
		var rot := 0.0 if (long and not along_x) or (not long and rng.randf() < 0.5) else PI * 0.5
		houses.append({"pos": Vector3(centre.x, gy, centre.y), "size": size, "rot": rot,
			"kind": "ruin" if kind == "ruin" else "house"})
	if houses.size() < 3:
		return false
	var place := {"kind": kind, "pos": Vector2((at.x + 0.5), (at.y + 0.5)) * MapData.CELL * MapData.BLOCK,
		"level": level, "station": false, "houses": houses}
	if station:
		_station(place)
	d.places.append(place)
	return true


func _rail_near(p: Vector2, r: float) -> bool:
	for rl in d.rails:
		var pts: PackedVector2Array = rl["pts"]
		for k in range(1, pts.size()):
			if Geometry2D.get_closest_point_to_segment(p, pts[k - 1], pts[k]).distance_to(p) < r:
				return true
	return false


func _station(place: Dictionary) -> void:
	var c: Vector2 = place["pos"]
	var best := INF
	var bp := Vector2.ZERO
	var bt := Vector2.RIGHT
	for rl in d.rails:
		var pts: PackedVector2Array = rl["pts"]
		for k in range(1, pts.size()):
			var q := Geometry2D.get_closest_point_to_segment(c, pts[k - 1], pts[k])
			var dd := q.distance_to(c)
			if dd < best:
				best = dd
				bp = q
				bt = (pts[k] - pts[k - 1]).normalized()
	if best > 260.0:
		return
	var nrm := Vector2(-bt.y, bt.x)
	if nrm.dot(c - bp) < 0.0:
		nrm = -nrm
	var rot := atan2(bt.x, bt.y)
	var plat := bp + nrm * 4.6
	var hall := bp + nrm * 12.0
	for p in [plat, hall, plat + bt * 18.0, plat - bt * 18.0, hall + bt * 6.0, hall - bt * 6.0]:
		var x := clampi(int(p.x / MapData.CELL), 0, d.w - 1)
		var z := clampi(int(p.y / MapData.CELL), 0, d.h - 1)
		if d.walk[z * d.w + x] != 1:
			return
	var hs: Array = place["houses"]
	hs.append({"pos": Vector3(plat.x, 0.0, plat.y), "size": Vector2(4.0, 40.0), "rot": rot, "kind": "platform"})
	hs.append({"pos": Vector3(hall.x, 0.0, hall.y), "size": Vector2(7.0, 14.0), "rot": rot, "kind": "station"})
	place["station"] = true
