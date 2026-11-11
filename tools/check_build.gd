extends SceneTree
## Iron Front: the building round's automatic check (headless). On a generated map it:
## 1. Placing rules: a building fits on flat open ground; not on a cliff, deep water, a ramp, woods, another
##    building or men; a turned building swaps its footprint.
## 2. Placing marks out a plot (stage 0) and closes its cells to walkers; cancelling opens them again.
## 3. Lines: a dragged wall joins up (ends, straights, a corner, a T); a cell that does not fit is left out.
## 4. Engineers: the nearest section walks over, its four men take their spots outside the footprint and build;
##    the stages run plot, frame, half built, finished in order, in about the building's work time. Two
##    sections on one building build it faster. A section that finishes helps the nearest unbuilt building.
## Run:  Godot --headless --path . --script res://tools/check_build.gd [-- --seeds=1,2]
## Ends with "BUILD CHECK DONE <seeds> <fails>".

const DT := 1.0 / 30.0
var fails := 0


func _initialize() -> void:
	var seeds := [1]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.substr(8).split(","):
				seeds.append(int(s))
	for s in seeds:
		_check(s)
	print("BUILD CHECK DONE %d %d" % [seeds.size(), fails])
	quit()


func _ok(cond: bool, what: String) -> void:
	print("CHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


## A flat open square about `half` metres each way, all buildable.
func _flat_spot(bc: BuildControl, d: MapData, rng: RandomNumberGenerator, half: int) -> Variant:
	for t in 6000:
		var c := Vector2i(rng.randi_range(40, d.w - 40), rng.randi_range(40, d.h - 40))
		var good := true
		var lvl := d.walk[c.y * d.w + c.x]
		var r := half / 8
		for z in range(-r, r + 1):
			for x in range(-r, r + 1):
				if not bc.cell_ok(c + Vector2i(x, z), lvl):
					good = false
					break
			if not good:
				break
		if good:
			return c
	return null


func _find_cell(d: MapData, nav: NavGrid, test: Callable) -> Variant:
	for z in range(10, d.h - 10, 3):
		for x in range(10, d.w - 10, 3):
			if test.call(x, z, z * d.w + x):
				return Vector2i(x, z)
	return null


## Runs the world for up to `secs` seconds (squads and building), until done() is true. Returns the seconds taken.
func _run(sc: SquadControl, bc: BuildControl, secs: float, done: Callable, watch: Callable = Callable()) -> float:
	var t := 0.0
	while t < secs:
		for sq in sc.squads:
			sq._step(DT)
			sq._place_men(DT)
		bc.step(DT)
		t += DT
		if watch.is_valid():
			watch.call()
		if done.call():
			break
	return t


func _check(seed: int) -> void:
	print("== seed %d" % seed)
	var d := MapGen.generate(seed, 1000, 1500)
	var nav := NavGrid.new().build(d)
	var sc := SquadControl.new()
	root.add_child(sc)
	var bc := BuildControl.new()
	root.add_child(bc)
	bc.squads = sc
	sc.build = bc
	bc.reset(nav, d)
	bc.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var spot: Variant = _flat_spot(bc, d, rng, 96)
	_ok(spot != null, "found flat open ground for the test")
	if spot == null:
		return
	var c: Vector2i = spot
	var cm := (Vector2(c) + Vector2(0.5, 0.5)) * MapData.CELL
	sc.spawn(nav, cm + Vector2(0, 60), 1, 2)
	for sq in sc.squads:
		sq.set_process(false)

	# 1. Placing rules.
	var hq_o := c + Vector2i(-6, -6)
	_ok(bc.fits(hq_o, Vector2i(3, 3)), "the HQ fits on flat open ground")
	var cliff: Variant = _find_cell(d, nav, func(x: int, z: int, i: int) -> bool: return d.walk[i] == MapData.FLAT_NONE)
	var water: Variant = _find_cell(d, nav, func(x: int, z: int, i: int) -> bool: return d.walk[i] == 0 and (d.feat[i] & MapData.F_FORD) == 0)
	var ramp: Variant = _find_cell(d, nav, func(x: int, z: int, i: int) -> bool: return nav.ramp_at.has(i) and d.walk[i] != MapData.FLAT_NONE)
	var wood: Variant = _find_cell(d, nav, func(x: int, z: int, i: int) -> bool: return (d.feat[i] & MapData.F_WOOD) != 0 and d.walk[i] != 0 and d.walk[i] != MapData.FLAT_NONE)
	_ok(cliff != null and not bc.cell_ok(cliff), "not on a cliff %s" % str(cliff))
	_ok(water != null and not bc.cell_ok(water), "not in deep water %s" % str(water))
	_ok(ramp == null or not bc.cell_ok(ramp), "not on a ramp %s" % str(ramp))
	_ok(wood != null and not bc.cell_ok(wood), "not in woods %s" % str(wood))
	var men := bc.men_cells()
	var man_cell := nav.cell_of(sc.squads[0].mpos[0])
	_ok(not bc.fits(man_cell - Vector2i(1, 1), Vector2i(3, 3), men), "not on top of men")
	_ok(BuildControl.footprint("barracks", 0) == Vector2i(2, 3) and BuildControl.footprint("barracks", 1) == Vector2i(3, 2),
		"R turns the barracks: 2x3 becomes 3x2")

	# 2. A plot, its cells closed; cancelling opens them.
	var hq := bc.place("hq", hq_o, 0, men)
	_ok(hq != null and hq.node.stage == 0, "the HQ is placed as a marked-out plot")
	var all_closed := true
	for cc in hq.cells():
		if nav.open[cc.y * d.w + cc.x] != 0 or not nav.astar.is_point_solid(cc):
			all_closed = false
	_ok(all_closed, "the HQ's 9 cells are closed to walkers")
	_ok(bc.place("hq", hq_o + Vector2i(1, 1), 0, men) == null, "a second HQ can't overlap the first")
	var dep := bc.place("depot", c + Vector2i(3, -6), 0, men)
	var dep_cells := dep.cells() if dep else []
	if dep:
		bc.cancel(dep)
	var reopened := dep != null
	for cc in dep_cells:
		if nav.open[cc.y * d.w + cc.x] != 1 or nav.astar.is_point_solid(cc) or bc.at_cell.has(cc):
			reopened = false
	_ok(reopened, "cancelling the depot opens its cells again")

	# 3. Walls join up: a line of 5 east-west, then 3 south from its middle (a T) and 2 north from its end (a corner).
	var w0 := c + Vector2i(-6, 2)
	bc.place_line("wall", w0, w0 + Vector2i(4, 0), men)
	bc.place_line("wall", w0 + Vector2i(2, 1), w0 + Vector2i(2, 3), men)
	bc.place_line("wall", w0 + Vector2i(4, -1), w0 + Vector2i(4, -2), men)
	var mask := func(cc: Vector2i) -> int: return int((bc.at_cell[cc] as BuildSite).node.get_meta("mask", -1)) if bc.at_cell.has(cc) else -1
	var N := BldWalls.N
	var E := BldWalls.E
	var S := BldWalls.S
	var W := BldWalls.W
	_ok(mask.call(w0) == E, "wall: the west end is an end piece (%d)" % mask.call(w0))
	_ok(mask.call(w0 + Vector2i(1, 0)) == (E | W), "wall: a straight piece (%d)" % mask.call(w0 + Vector2i(1, 0)))
	_ok(mask.call(w0 + Vector2i(2, 0)) == (E | W | S), "wall: the T where the south arm joins (%d)" % mask.call(w0 + Vector2i(2, 0)))
	_ok(mask.call(w0 + Vector2i(4, 0)) == (W | N), "wall: the corner where it turns north (%d)" % mask.call(w0 + Vector2i(4, 0)))
	_ok(mask.call(w0 + Vector2i(2, 3)) == N, "wall: the south arm's end (%d)" % mask.call(w0 + Vector2i(2, 3)))
	# A wire line across the HQ: the HQ's cells are left out, the rest is placed.
	var wire := bc.place_line("wire_belt", hq_o + Vector2i(-2, 1), hq_o + Vector2i(4, 1), men)
	_ok(wire.size() == 4, "a wire line across the HQ skips the HQ's 3 cells (%d of 7 placed)" % wire.size())
	for s in wire:
		bc.cancel(s)

	# 4. Engineers build the HQ.
	var walls: Array[BuildSite] = []
	for s in bc.sites:
		if s.family == "wall":
			walls.append(s)
	for s in walls:
		bc.cancel(s)
	var e1: Squad = sc.squads[1]
	var e2: Squad = sc.squads[2]
	var hqs: Array[BuildSite] = [hq]
	bc._give_out(hqs)
	_ok(e1.jobs.has(hq) or e2.jobs.has(hq), "the nearest engineer section takes the HQ")
	var crew: Squad = e1 if e1.jobs.has(hq) else e2
	var stages: Array[int] = [hq.node.stage]
	var most_at_work := [0]
	var inside := [0]
	var t_walk := _run(sc, bc, 300.0, func() -> bool: return crew.men_at_work() == crew.count)
	_ok(crew.men_at_work() == crew.count, "all 4 men reach their spots and work (after %.0f s)" % t_walk)
	var p0 := hq.progress
	var t_build := _run(sc, bc, 400.0, func() -> bool: return hq.done, func() -> void:
		if hq.node.stage != stages[-1]:
			stages.append(hq.node.stage)
		most_at_work[0] = maxi(most_at_work[0], crew.men_at_work())
		for p in crew.mpos:
			if hq.has_cell(nav.cell_of(p)):
				inside[0] += 1)
	_ok(hq.done and hq.node.stage == 3, "the HQ is finished")
	_ok(stages == [0, 1, 2, 3], "stages in order: %s" % str(stages))
	var want := hq.work_time * (1.0 - p0)
	_ok(absf(t_build - want) < want * 0.15, "built in %.0f s (work time %.0f s)" % [t_build, want])
	_ok(inside[0] == 0, "no man ever stood inside the footprint (%d frames)" % inside[0])
	_ok(crew.job == null and not crew.working, "the section stops working when it's done")

	# Two sections on one building build faster than one.
	var bar := bc.place("barracks", c + Vector2i(3, -6), 0, bc.men_cells())
	_ok(bar != null, "the barracks is placed")
	if bar == null:
		return
	# Bring the other section over first, so both work on it together.
	e2.order_move(bar.approach(nav) + Vector2(10, 0))
	_run(sc, bc, 300.0, func() -> bool: return not e2.moving())
	for sq in [e1, e2]:
		bc.assign(sq, bar)
	_run(sc, bc, 300.0, func() -> bool: return bar.done or (e1.men_at_work() == 4 and e2.men_at_work() == 4))
	var pa := bar.progress
	var t2 := _run(sc, bc, 10.0, func() -> bool: return bar.done)
	var rate := (bar.progress - pa) / t2 * bar.work_time
	_ok(absf(rate - 2.0) < 0.1, "two sections together build at %.2f times one section's speed" % rate)
	_run(sc, bc, 300.0, func() -> bool: return bar.done)
	_ok(bar.done, "the barracks is finished")

	# Auto help: with nothing to do, a finishing section moves on to the nearest unbuilt building.
	var mg := bc.place("mg_nest", c + Vector2i(-6, 4), 0, bc.men_cells())
	var pit := bc.place("gun_pit", c + Vector2i(-2, 4), 0, bc.men_cells())
	_ok(mg != null and pit != null, "an MG nest and a gun pit are placed")
	if mg == null or pit == null:
		return
	bc.assign(e1, mg)
	var t3 := _run(sc, bc, 300.0, func() -> bool: return mg.done and pit.done)
	_ok(mg.done and pit.done, "after the MG nest the section builds the gun pit nobody was given (%.0f s)" % t3)
	sc.free()
	bc.free()
