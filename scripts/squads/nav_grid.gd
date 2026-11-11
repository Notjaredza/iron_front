class_name NavGrid
extends RefCounted
## Iron Front: where troops can walk, and the way between two points (squads round 1).
##
## Built from a MapData on the 8 m grid:
## - Flat cells are walkable. Cliff cells are not, so each level is walled off from the others by its cliffs.
## - Deep water is not walkable. Fords, streams and marsh are, but slowly; woods are a little slow.
## - Ramps: the cliff cell at the top of each ramp lane is opened, which joins the two levels there. The ground
##   under a ramp follows its slope (height()).
## The search itself is Godot's AStarGrid2D (fast, in the engine), with eight directions and no corner cutting.
## Paths are then pulled straight where the ground between two points is clear.

const SLOW := 1.7                              # streams, fords, marsh
const WOOD := 1.25                             # woods and tall grass

var data: MapData
var astar := AStarGrid2D.new()
var open := PackedByteArray()                  # w * h: 1 where a man can stand
var ramp_at := {}                              # cell index -> ramp index, for cells the ramp surface covers
var build_ms := 0


func build(d: MapData) -> NavGrid:
	var t0 := Time.get_ticks_msec()
	data = d
	var w := d.w
	var h := d.h
	open.resize(w * h)
	open.fill(0)
	for z in h:
		for x in w:
			var i := z * w + x
			var f := d.walk[i]
			var ford := (d.feat[i] & MapData.F_FORD) != 0
			if f == MapData.FLAT_NONE:
				# A cliff cell, except at a ford's bank (the gravel slope down to the water).
				var hi := maxi(maxi(d.corner(x, z), d.corner(x + 1, z)), maxi(d.corner(x, z + 1), d.corner(x + 1, z + 1)))
				if ford and hi <= 1:
					open[i] = 1
			elif f == 0:
				if ford:
					open[i] = 1
			else:
				open[i] = 1
	ramp_at.clear()
	for ri in d.ramps.size():
		var r: Dictionary = d.ramps[ri]
		var s: int = r["s"]
		var ec := int(floor(float(r["e"])))
		for l in range(int(r["a"]), int(r["a"]) + int(r["w"])):
			for k in 5:
				var c := _ramp_cell(r, ec + s * k, l)
				if c >= 0:
					ramp_at[c] = ri
					open[c] = 1
		# Close the low ground beside the ramp, so men only get on and off at its top and foot.
		for l in [int(r["a"]) - 1, int(r["a"]) + int(r["w"])]:
			for k in range(1, 5):
				var c := _ramp_cell(r, ec + s * k, l)
				if c >= 0 and not ramp_at.has(c):
					open[c] = 0
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(MapData.CELL, MapData.CELL)
	astar.offset = Vector2(MapData.CELL * 0.5, MapData.CELL * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for z in h:
		for x in w:
			var i := z * w + x
			if open[i] == 0:
				astar.set_point_solid(Vector2i(x, z), true)
				continue
			var ft := d.feat[i]
			if (ft & (MapData.F_STREAM | MapData.F_FORD | MapData.F_MARSH)) != 0:
				astar.set_point_weight_scale(Vector2i(x, z), SLOW)
			elif (ft & (MapData.F_WOOD | MapData.F_TALL)) != 0:
				astar.set_point_weight_scale(Vector2i(x, z), WOOD)
	build_ms = Time.get_ticks_msec() - t0
	return self


func _ramp_cell(r: Dictionary, along: int, across: int) -> int:
	var x := along if int(r["axis"]) == 0 else across
	var z := across if int(r["axis"]) == 0 else along
	if x < 0 or z < 0 or x >= data.w or z >= data.h:
		return -1
	return z * data.w + x


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / MapData.CELL), 0, data.w - 1), clampi(int(p.y / MapData.CELL), 0, data.h - 1))


func is_open(p: Vector2) -> bool:
	var c := cell_of(p)
	return open[c.y * data.w + c.x] == 1


## The open cell nearest to p (searched in growing squares), as a point in metres, or p itself if none is near.
func nearest_open(p: Vector2, max_r := 40) -> Vector2:
	var c := cell_of(p)
	if open[c.y * data.w + c.x] == 1:
		return p
	for r in range(1, max_r):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := c.x + dx
				var z := c.y + dz
				if x < 0 or z < 0 or x >= data.w or z >= data.h or open[z * data.w + x] == 0:
					continue
				var dd := float(dx * dx + dz * dz)
				if dd < best_d:
					best_d = dd
					best = Vector2i(x, z)
		if best.x >= 0:
			return (Vector2(best) + Vector2(0.5, 0.5)) * MapData.CELL
	return p


## Ground height for troops (metres): the map's ground, plus the slope of a ramp where one covers the cell.
func height(p: Vector2) -> float:
	var c := cell_of(p)
	var i := c.y * data.w + c.x
	if ramp_at.has(i):
		var r: Dictionary = data.ramps[ramp_at[i]]
		var t: int = r["t"]
		var along := (p.x if int(r["axis"]) == 0 else p.y) / MapData.CELL
		var u := clampf((along - float(r["e"])) * float(r["s"]) / 4.0, 0.0, 1.0)
		return lerpf(MapData.level_y(t), MapData.level_y(t - 1), u)
	var f := data.walk[i]
	if f == 0 and (data.feat[i] & MapData.F_FORD) != 0:
		return MapData.WATER_Y - 0.5                # wading through a ford
	return data.ground_y(p)


## A walking route from a to b (metres), as points from just after a to b. Empty if b cannot be reached.
## b is moved to the nearest open cell first.
func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var ca := cell_of(nearest_open(a))
	var bb := nearest_open(b)
	var cb := cell_of(bb)
	if astar.is_point_solid(ca) or astar.is_point_solid(cb):
		return out
	var cells := astar.get_id_path(ca, cb)
	if cells.is_empty():
		return out
	# Pull the path straight: from each kept point, jump to the furthest later cell that is clear in a line.
	var pts := PackedVector2Array()
	pts.append(a)
	for c in cells:
		pts.append((Vector2(c) + Vector2(0.5, 0.5)) * MapData.CELL)
	pts[pts.size() - 1] = bb
	var i := 0
	while i < pts.size() - 1:
		var j := mini(pts.size() - 1, i + 60)
		while j > i + 1 and not clear_line(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


## True if every cell a straight walk from a to b crosses is open and no slower than where it starts.
## Ramp cells count as clear only along the ramp (so lines never cut across a ramp's side).
func clear_line(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := int(ceil(dist / (MapData.CELL * 0.25))) + 1
	var w0 := astar.get_point_weight_scale(cell_of(a))
	var on_ramp := false
	for k in steps + 1:
		var p := a.lerp(b, float(k) / float(steps))
		for o in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0.8), Vector2(0.8, 0.8)]:
			var c := cell_of(p + o)
			var i := c.y * data.w + c.x
			if open[i] == 0 or astar.get_point_weight_scale(c) > w0:
				return false
			if ramp_at.has(i):
				on_ramp = true
	if on_ramp:
		# Only straight up or down the ramp.
		var dv := (b - a).normalized()
		if absf(dv.x) > 0.2 and absf(dv.y) > 0.2:
			return false
	return true
