extends SceneTree
## Iron Front: the map's automatic check (headless). For each seed it:
## 1. Reach: every flat area of 16 cells or more can be reached from the main base area by walking and ramps. Water
##    and shore count as crossable until bridges come; cliffs don't.
## 2. Walls: every cliff wall corner is shared by exactly two wall pieces (one at the map edge), and the chunks on
##    each side of a chunk border build it at the same place. This means no gaps in the cliffs.
## 3. Holes: rays straight down at thousands of points, near chunk borders too, all hit ground at the right height.
## 4. Shape: the share of high ground, ramps (wide and narrow), rail lines and places.
## Run:  Godot --headless --path . --script res://tools/check_map.gd [-- --seeds=1,2,3 --size=1000x1500]
## Ends with "MAP CHECK DONE <seeds> <fails>".

var fails := 0


func _initialize() -> void:
	var seeds := [1, 2, 3]
	var w := 1000
	var h := 1500
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.substr(8).split(","):
				seeds.append(int(s))
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			w = int(p[0]) / 4 * 4
			h = int(p[1]) / 4 * 4
	for s in seeds:
		_check(s, w, h)
	print("MAP CHECK DONE %d %d" % [seeds.size(), fails])
	quit()


func _ok(cond: bool, what: String) -> void:
	print("CHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func _check(seed: int, w: int, h: int) -> void:
	var t0 := Time.get_ticks_msec()
	var d := MapGen.generate(seed, w, h)
	print("--- seed %d (%d x %d cells), generated in %d ms" % [seed, w, h, Time.get_ticks_msec() - t0])
	for n in d.notes:
		print("  note: ", n)
	_shape(d)
	_reach(d)
	var t1 := Time.get_ticks_msec()
	var ncx := MapMesher.chunks_x(d)
	var ncz := MapMesher.chunks_z(d)
	var res: Array = []
	res.resize(ncx * ncz)
	var mutex := Mutex.new()
	var job := func(i: int) -> void:
		var r := MapMesher.build(d, i % ncx, i / ncx, true)
		mutex.lock()
		res[i] = r
		mutex.unlock()
	var task := WorkerThreadPool.add_group_task(job, ncx * ncz, -1, true, "check chunks")
	WorkerThreadPool.wait_for_group_task_completion(task)
	var tris := 0
	for r: Dictionary in res:
		tris += int(r["tris"])
	print("  meshes: %d chunks, %d triangles, built in %d ms" % [res.size(), tris, Time.get_ticks_msec() - t1])
	_walls(d, res)
	_holes(d, res, ncx, ncz)


func _shape(d: MapData) -> void:
	var n := (d.w + 1) * (d.h + 1)
	var count := [0, 0, 0, 0]
	for i in n:
		count[d.field[i]] += 1
	var high := float(count[2] + count[3]) / n
	print("  ground: water %.1f %%, base %.1f %%, level 2 %.1f %%, level 3 %.1f %%" % [100.0 * count[0] / n, 100.0 * count[1] / n, 100.0 * count[2] / n, 100.0 * count[3] / n])
	_ok(high > 0.22 and high < 0.42, "high ground about a third: %.0f %%" % (high * 100.0))
	var wide := 0
	var narrow := 0
	for r in d.ramps:
		if int(r["w"]) == 1:
			narrow += 1
		else:
			wide += 1
	_ok(wide > narrow and narrow > 0, "ramps mostly wide, some narrow: %d wide, %d narrow" % [wide, narrow])
	var broken := 0.0
	var total := 0.0
	for rl in d.rails:
		for s in rl["sections"]:
			var ln: float = float(s["to"]) - float(s["from"])
			total += ln
			if s["broken"]:
				broken += ln
	_ok(d.rails.size() >= 2, "old rail lines: %d, %.1f km, %.0f %% broken" % [d.rails.size(), total / 1000.0, 100.0 * broken / maxf(1.0, total)])
	var vil := 0
	var ruin := 0
	var st := 0
	for p in d.places:
		if p["kind"] == "village":
			vil += 1
		else:
			ruin += 1
		if p["station"]:
			st += 1
	var want_v := maxi(2, roundi(d.size_m().x * d.size_m().y / 1.0e6 / 9.6 * 0.7))
	_ok(vil >= want_v and ruin >= 2, "places: %d villages (%d with a station), %d ruins" % [vil, st, ruin])


## Walking areas: flat cells by level (water and shore count as the base for now); ramps join areas.
func _reach(d: MapData) -> void:
	var n := d.w * d.h
	var lvl := PackedInt32Array()
	lvl.resize(n)
	for z in d.h:
		for x in d.w:
			var f := d.walk[z * d.w + x]
			var v := -1
			if f == MapData.FLAT_NONE:
				var hi := maxi(maxi(d.corner(x, z), d.corner(x + 1, z)), maxi(d.corner(x, z + 1), d.corner(x + 1, z + 1)))
				if hi <= 1:
					v = 1
			else:
				v = maxi(1, f)
			lvl[z * d.w + x] = v
	var lab := PackedInt32Array()
	lab.resize(n)
	lab.fill(-1)
	var sizes := PackedInt32Array()
	var levels := PackedInt32Array()
	var q := PackedInt32Array()
	for i in n:
		if lvl[i] < 0 or lab[i] >= 0:
			continue
		var c := sizes.size()
		sizes.append(0)
		levels.append(lvl[i])
		q.clear()
		q.append(i)
		lab[i] = c
		var head := 0
		while head < q.size():
			var j := q[head]
			head += 1
			sizes[c] += 1
			var x := j % d.w
			var z := j / d.w
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var nz: int = z + o.y
				if nx < 0 or nz < 0 or nx >= d.w or nz >= d.h:
					continue
				var k := nz * d.w + nx
				if lab[k] < 0 and lvl[k] == lvl[i]:
					lab[k] = c
					q.append(k)
	var parent := PackedInt32Array()
	parent.resize(sizes.size())
	for i in parent.size():
		parent[i] = i
	var bad_ramps := 0
	for r in d.ramps:
		var s: int = r["s"]
		var ec := int(floor(float(r["e"])))
		for l in range(int(r["a"]), int(r["a"]) + int(r["w"])):
			var top := _cell(d, r, ec - s, l)
			var foot := _cell(d, r, ec + 4 * s, l)
			if top < 0 or foot < 0 or lab[top] < 0 or lab[foot] < 0 or levels[lab[top]] != levels[lab[foot]] + 1:
				bad_ramps += 1
				continue
			_union(parent, lab[top], lab[foot])
	var main := -1
	for c in sizes.size():
		if levels[c] == 1 and (main < 0 or sizes[c] > sizes[main]):
			main = c
	var cut := 0
	var cut_cells := 0
	var bits := 0
	var plateaus := 0
	for c in sizes.size():
		if levels[c] >= 2 and sizes[c] >= 16:
			plateaus += 1
		if _find(parent, c) == _find(parent, main):
			continue
		if sizes[c] >= 16:
			cut += 1
			cut_cells += sizes[c]
		else:
			bits += 1
	_ok(bad_ramps == 0, "every ramp runs from a flat top one level down to flat ground (%d ramps)" % d.ramps.size())
	_ok(cut == 0, "every area reachable: %d plateau areas, %d cut off (%d cells); %d tiny corner bits under 16 cells" % [plateaus, cut, cut_cells, bits])


func _cell(d: MapData, r: Dictionary, along: int, across: int) -> int:
	var x := along if int(r["axis"]) == 0 else across
	var z := across if int(r["axis"]) == 0 else along
	if x < 0 or z < 0 or x >= d.w or z >= d.h:
		return -1
	return z * d.w + x


static func _find(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i


static func _union(p: PackedInt32Array, a: int, b: int) -> void:
	p[_find(p, a)] = _find(p, b)


func _walls(d: MapData, res: Array) -> void:
	var count: Dictionary = {}
	var where: Dictionary = {}
	var moved := 0
	for r: Dictionary in res:
		var wk: Dictionary = r["walls"]
		for k: int in wk:
			var e: Array = wk[k]
			count[k] = int(count.get(k, 0)) + int(e[1])
			if where.has(k):
				var a: Array = where[k]
				var b: Array = e[0]
				for i in a.size():
					if (a[i] as Vector3).distance_to(b[i]) > 0.001:
						moved += 1
						break
			else:
				where[k] = e[0]
	var open := 0
	var edge := 0
	for k: int in count:
		var c: int = count[k]
		if c == 2:
			continue
		var p: Vector3 = where[k][0]
		var on_edge := p.x < 0.01 or p.z < 0.01 or p.x > d.w * MapData.CELL - 0.01 or p.z > d.h * MapData.CELL - 0.01
		if c == 1 and on_edge:
			edge += 1
		else:
			open += 1
	_ok(open == 0, "cliff walls closed: %d wall corners, %d open (%d end at the map edge)" % [count.size(), open, edge])
	_ok(moved == 0, "wall corners on chunk borders match from both sides (%d differ)" % moved)


func _holes(d: MapData, res: Array, ncx: int, ncz: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = d.seed
	var picks: Array = []
	for i in res.size():
		if i % 7 == d.seed % 7:
			picks.append(i)
	var missed := 0
	var low := 0
	var samples := 0
	for ci: int in picks:
		var r: Dictionary = res[ci]
		var arr: Array = r["arrays"]
		if arr.is_empty():
			missed += 1
			continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cx := ci % ncx
		var cz := ci / ncx
		var x0 := cx * MapMesher.CHUNK * MapData.CELL
		var z0 := cz * MapMesher.CHUNK * MapData.CELL
		var sx := minf(MapMesher.CHUNK, d.w - cx * MapMesher.CHUNK) * MapData.CELL
		var sz := minf(MapMesher.CHUNK, d.h - cz * MapMesher.CHUNK) * MapData.CELL
		# Bucket the upward-facing triangles by 8 m cell.
		var nbx := int(sx / MapData.CELL) + 1
		var nbz := int(sz / MapData.CELL) + 1
		var buckets: Array = []
		buckets.resize(nbx * nbz)
		for t in v.size() / 3:
			var a := v[t * 3]
			var b := v[t * 3 + 1]
			var c := v[t * 3 + 2]
			var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
			if absf(area) < 1e-6:
				continue
			var bx0 := clampi(int((minf(a.x, minf(b.x, c.x)) - x0) / MapData.CELL), 0, nbx - 1)
			var bx1 := clampi(int((maxf(a.x, maxf(b.x, c.x)) - x0) / MapData.CELL), 0, nbx - 1)
			var bz0 := clampi(int((minf(a.z, minf(b.z, c.z)) - z0) / MapData.CELL), 0, nbz - 1)
			var bz1 := clampi(int((maxf(a.z, maxf(b.z, c.z)) - z0) / MapData.CELL), 0, nbz - 1)
			for bz in range(bz0, bz1 + 1):
				for bx in range(bx0, bx1 + 1):
					var k := bz * nbx + bx
					var bl: PackedInt32Array = PackedInt32Array() if buckets[k] == null else buckets[k]
					bl.append(t)
					buckets[k] = bl
		for s in 2500:
			var px: float
			var pz: float
			if s < 400:
				# Along the chunk's borders, just inside.
				var along := rng.randf() * (sx if s % 2 == 0 else sz)
				var side := 0.02 if rng.randf() < 0.5 else (sz - 0.02 if s % 2 == 0 else sx - 0.02)
				px = x0 + (along if s % 2 == 0 else side)
				pz = z0 + (side if s % 2 == 0 else along)
			else:
				px = x0 + rng.randf() * sx
				pz = z0 + rng.randf() * sz
			samples += 1
			var k := clampi(int((pz - z0) / MapData.CELL), 0, nbz - 1) * nbx + clampi(int((px - x0) / MapData.CELL), 0, nbx - 1)
			var best := -INF
			if buckets[k] != null:
				for t: int in buckets[k]:
					var y := _hit(v[t * 3], v[t * 3 + 1], v[t * 3 + 2], px, pz)
					if y > best:
						best = y
			var cx_ := clampi(int(px / MapData.CELL), 0, d.w - 1)
			var cz_ := clampi(int(pz / MapData.CELL), 0, d.h - 1)
			var f := d.walk[cz_ * d.w + cx_]
			var want: float
			if f == MapData.FLAT_NONE:
				var lo := mini(mini(d.corner(cx_, cz_), d.corner(cx_ + 1, cz_)), mini(d.corner(cx_, cz_ + 1), d.corner(cx_ + 1, cz_ + 1)))
				want = MapData.WATER_Y if lo == 0 else MapData.level_y(lo)
			else:
				want = MapData.WATER_Y if f == 0 else MapData.level_y(f)
			if best == -INF:
				missed += 1
				if missed <= 5:
					print("  hole at %.2f, %.2f" % [px, pz])
			elif best < want - 0.02:
				low += 1
				if low <= 5:
					print("  too low at %.2f, %.2f: %.2f (want %.2f)" % [px, pz, best, want])
	_ok(missed == 0 and low == 0, "no holes: %d rays in %d chunks, %d found nothing, %d too low" % [samples, picks.size(), missed, low])


## Height where a vertical line at (x, z) meets the triangle, or -INF.
static func _hit(a: Vector3, b: Vector3, c: Vector3, x: float, z: float) -> float:
	var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(d) < 1e-9:
		return -INF
	var l1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
	var l2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
	var l3 := 1.0 - l1 - l2
	if l1 < -1e-5 or l2 < -1e-5 or l3 < -1e-5:
		return -INF
	return l1 * a.y + l2 * b.y + l3 * c.y
