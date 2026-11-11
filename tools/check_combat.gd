extends SceneTree
## Iron Front: the fighting round's automatic check (headless). On flat open ground of a generated map it:
## 1. Every kind of troop is made, and every clip its men use is in its library.
## 2. Cover: a man behind finished sandbags is much harder to hit than one in the open, in woods a bit harder,
##    pinned (prone) harder again.
## 3. Pinned: heavy fire pins a rifle squad: it goes prone and does not move on an order until it is free again.
## 4. Red coats against a rifle squad: they march up, halt and fire a volley, then charge with bayonets into hand
##    to hand; men fall on both sides and the bookkeeping stays right.
## 5. Zombies against a rifle squad: the rifles shoot them as they come; zombies need two hits; they get in close.
## 6. The medieval host: the archers halt at bow range and shoot; the foot run in and fight hand to hand.
## 7. Posts: a rifle squad mans a finished MG nest (its men go inside, the nest's crew shows) and cuts down a
##    zombie horde; a move order brings it out. A gun pit's shell kills men round the burst.
## Run:  Godot --headless --path . --script res://tools/check_combat.gd [-- --seed=N]
## Ends with "COMBAT CHECK DONE <fails>".

const DT := 1.0 / 30.0
var fails := 0
var d: MapData
var nav: NavGrid
var sc: SquadControl
var bc: BuildControl
var cc: CombatControl
var c := Vector2.ZERO


func _ok(cond: bool, what: String) -> void:
	print("CHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _flat(half: int) -> Variant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 8000:
		var cell := Vector2i(rng.randi_range(60, d.w - 60), rng.randi_range(60, d.h - 60))
		var lvl := d.walk[cell.y * d.w + cell.x]
		var good := true
		var r := half / 8
		for z in range(-r, r + 1, 2):
			for x in range(-r / 3, r / 3 + 1, 2):
				if not bc.cell_ok(cell + Vector2i(x, z), lvl) or nav.astar.get_point_weight_scale(cell + Vector2i(x, z)) > 1.0:
					good = false
					break
			if not good:
				break
		if good:
			return (Vector2(cell) + Vector2(0.5, 0.5)) * MapData.CELL
	return null


## Runs the world (all squads, the fighting, the building) for up to secs, until done(); returns the time taken.
func _world(secs: float, done: Callable = Callable(), watch: Callable = Callable()) -> float:
	var tt := 0.0
	while tt < secs:
		for s in sc.squads + cc.enemies:
			s._step(DT)
			s._place_men(DT)
		cc.step(DT)
		bc.step(DT)
		tt += DT
		if watch.is_valid():
			watch.call()
		if done.is_valid() and done.call():
			break
	return tt


func _clear() -> void:
	for s in sc.squads + cc.enemies:
		s.free()
	sc.squads.clear()
	cc.enemies.clear()
	cc._pending.clear()


func _rifles(at: Vector2, face := Vector2(0, -1), title := "Rifles") -> Squad:
	var s := Squad.new()
	sc.add_child(s)
	s.setup(nav, at, face, 7 + sc.squads.size(), title)
	s.set_process(false)
	sc.squads.append(s)
	return s


func _consistent(s: Squad) -> bool:
	var n := s.men.size()
	return s.players.size() == n and s.rings.size() == n and s.mpos.size() == n and s.mface.size() == n and s.md.size() == n and s.count == n


func _run() -> void:
	var seed := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
	d = MapGen.generate(seed, 1000, 1500)
	nav = NavGrid.new().build(d)
	sc = SquadControl.new()
	root.add_child(sc)
	sc.nav = nav
	bc = BuildControl.new()
	root.add_child(bc)
	bc.squads = sc
	bc.reset(nav, d)
	bc.set_process(false)
	var bl := MapBlasts.new()
	root.add_child(bl)
	cc = CombatControl.new()
	root.add_child(cc)
	cc.squads = sc
	cc.build = bc
	cc.reset(nav, d)
	cc.set_process(false)
	sc.combat = cc
	sc.build = bc
	var spot: Variant = _flat(240)
	_ok(spot != null, "found open flat ground for the fights")
	if spot == null:
		print("COMBAT CHECK DONE %d" % fails)
		quit()
		return
	c = spot

	# 1. Every kind, every clip.
	var missing := []
	for k: Array in [["rifles", ""], ["engineers", ""], ["redcoats", ""], ["medieval", ""], ["archers", ""], ["zombies", "shambler"],
			["zombies", "runner"], ["zombies", "brute"]]:
		var s := Squad.new()
		root.add_child(s)
		s.setup(nav, c, Vector2(0, 1), 3, k[0], k[0], -1, k[1])
		for i in s.men.size():
			for what: String in s.md[i]["clips"]:
				var v: Variant = s.md[i]["clips"][what]
				for nm in (v if v is Array else [v]):
					if not s.players[i].has_animation(nm):
						missing.append("%s/%s:%s" % [k[0], k[1], nm])
		s.free()
	_ok(missing.is_empty(), "every kind's men have all their clips %s" % str(missing.slice(0, 6)))

	# 2. Cover.
	var r := _rifles(c)
	var e := Squad.new()
	cc.add_child(e)
	e.setup(nav, c + Vector2(0, -80), Vector2(0, 1), 9, "Red coats", "redcoats")
	e.set_process(false)
	cc.enemies.append(e)
	var open_p := cc.hit_chance(e, r, 80.0, r.mpos[0])
	var bag := bc.place("sandbag_line", nav.cell_of(r.mpos[0]) + Vector2i(0, -1), 0)
	if bag:
		bag.done = true
		bag.progress = 1.0
	var bag_p := cc.hit_chance(e, r, 80.0, r.mpos[0])
	r.pinned = true
	var pin_p := cc.hit_chance(e, r, 80.0, r.mpos[0])
	r.pinned = false
	var wood: Variant = null
	for z in range(10, d.h - 10, 7):
		for x in range(10, d.w - 10, 7):
			if (d.feat[z * d.w + x] & MapData.F_WOOD) != 0:
				wood = (Vector2(x, z) + Vector2(0.5, 0.5)) * MapData.CELL
				break
		if wood != null:
			break
	var wood_p := cc.hit_chance(e, r, 80.0, wood) if wood != null else -1.0
	_ok(bag_p < open_p * 0.5 and wood_p > bag_p and wood_p < open_p and pin_p < bag_p,
		"cover: open %.3f, woods %.3f, sandbags %.3f, sandbags and prone %.3f" % [open_p, wood_p, bag_p, pin_p])
	if bag:
		bc.cancel(bag) if not bag.done else bc._remove(bag)

	# 3. Pinned.
	r.supp = 1.6
	cc._suppression(0.0)
	_ok(r.pinned, "heavy fire pins the rifle squad")
	var before := r.at
	r.order_move(r.at + Vector2(40, 0))
	for k2 in 60:
		r._step(DT)
		r._place_men(DT)
	_ok(r.at.distance_to(before) < 0.01, "pinned, it does not move on an order")
	_ok(r._clip[0] == "pinned" or r._clip[0].begins_with("act:stand_to_prone"), "its men go prone (%s)" % r._clip[0])
	_world(8.0, func() -> bool: return not r.pinned)
	_ok(not r.pinned, "with no more fire it is free again")
	_clear()

	# 4. Red coats against rifles.
	r = _rifles(c + Vector2(0, 60))
	r.files = 12
	var reds := cc.spawn("redcoats", c + Vector2(0, 60), 230.0)
	for s in reds:
		s.set_process(false)
	var halted := [false]
	var halt_d := [0.0]
	var charged := [false]
	var hand := [false]
	var ok_books := [true]
	var t4 := _world(300.0, func() -> bool: return r.men.is_empty() or cc.enemies.is_empty(), func() -> void:
		for s in cc.enemies:
			if s.mode == "halt" and not halted[0] and not s.moving():
				halted[0] = true
				halt_d[0] = s.center().distance_to(r.center()) if not r.men.is_empty() else 0.0
			if s.mode == "charge":
				charged[0] = true
			if s.melee_on:
				hand[0] = true
			if not _consistent(s):
				ok_books[0] = false
		if not r.men.is_empty() and not _consistent(r):
			ok_books[0] = false)
	var red_left := 0
	for s in cc.enemies:
		red_left += s.men.size()
	_ok(halted[0] and halt_d[0] > 50.0 and halt_d[0] < 95.0, "red coats halt at musket range to fire (%.0f m)" % halt_d[0])
	var vol := 0
	for s in reds:
		if is_instance_valid(s):
			vol = maxi(vol, s.volleys)
	_ok(charged[0], "they fix bayonets and charge")
	_ok(hand[0], "it comes to hand to hand")
	_ok(red_left < 24 and r.men.size() < 12, "men fall on both sides: rifles %d of 12 left, red coats %d of 24 (after %.0f s)" % [r.men.size(), red_left, t4])
	_ok(ok_books[0], "every squad's men, clips and places stay in step as men fall")
	_ok(cc.corpses.get_child_count() == (12 - r.men.size()) + (24 - red_left), "the fallen lie where they fell (%d)" % cc.corpses.get_child_count())
	_clear()

	# 5. Zombies against rifles.
	r = _rifles(c + Vector2(0, 60))
	var zs := cc.spawn("zombies", c + Vector2(0, 60), 110.0)
	for s in zs:
		s.set_process(false)
	var z_total := 0
	for s in zs:
		z_total += s.men.size()
	var two_hits := [false]
	var close := [false]
	_world(200.0, func() -> bool: return r.men.is_empty() or cc.enemies.is_empty(), func() -> void:
		for s in cc.enemies:
			for i in s.men.size():
				if int(s.md[i]["hp"]) == 1 and s.sub != "brute":
					two_hits[0] = true
				if not r.men.is_empty() and s.mpos[i].distance_to(r.center()) < 10.0:
					close[0] = true)
	var z_left := 0
	for s in cc.enemies:
		z_left += s.men.size()
	_ok(z_left < z_total, "the rifles shoot zombies down as they come (%d of %d left, rifles %d left)" % [z_left, z_total, r.men.size()])
	_ok(two_hits[0], "a zombie takes a hit and keeps coming (two hits to kill)")
	_ok(close[0], "the zombies get in close")
	_clear()

	# 6. The medieval host.
	r = _rifles(c + Vector2(0, 60))
	var host := cc.spawn("medieval", c + Vector2(0, 60), 230.0)
	for s in host:
		s.set_process(false)
	var arch: Squad = host[2]
	var arch_halt := [0.0]
	var arch_shot := [false]
	var foot_hand := [false]
	_world(200.0, func() -> bool: return r.men.is_empty() or cc.enemies.is_empty(), func() -> void:
		if is_instance_valid(arch) and not arch.men.is_empty() and not arch.moving() and arch_halt[0] == 0.0 and arch.center().distance_to(r.center()) < 125.0:
			arch_halt[0] = arch.center().distance_to(r.center())
		if is_instance_valid(arch) and not arch.men.is_empty():
			for i in arch.men.size():
				if int(arch.md[i]["shots"]) > 0:
					arch_shot[0] = true
		for s in host:
			if is_instance_valid(s) and s.kind == "medieval" and s.melee_on:
				foot_hand[0] = true)
	_ok(arch_halt[0] > 70.0 and arch_halt[0] < 125.0, "the archers halt at bow range (%.0f m)" % arch_halt[0])
	_ok(arch_shot[0], "and shoot")
	_ok(foot_hand[0], "the host's foot run in to hand to hand")
	_clear()

	# 7. Posts: an MG nest against zombies, then a gun pit's shell.
	var nest_cell := nav.cell_of(c)
	var nest := bc.place("mg_nest", nest_cell, 0)
	_ok(nest != null, "an MG nest is placed")
	if nest:
		bc._finish(nest)
		r = _rifles(c + Vector2(0, 40))
		cc.man_post(r, nest)
		_world(60.0, func() -> bool: return r.in_post)
		_world(0.5)
		_ok(r.in_post and not r.men[0].visible, "the rifle squad mans the MG nest (its men go inside)")
		var crew_seen := false
		for s3: Node3D in nest.node.get_meta("crew", []):
			crew_seen = crew_seen or s3.visible
		_ok(crew_seen, "the nest's own crew shows")
		zs = cc.spawn("zombies", c, 200.0)
		for s in zs:
			s.set_process(false)
		z_total = 0
		for s in zs:
			z_total += s.men.size()
		_world(40.0)
		z_left = 0
		for s in cc.enemies:
			z_left += s.men.size()
		_ok(z_left < z_total - 4, "the MG cuts zombies down at range (%d of %d left after 40 s)" % [z_left, z_total])
		sc.squads[0].selected = true
		sc._order(c + Vector2(30, 60), false)
		_world(1.0)
		_ok(not r.in_post and r.men[0].visible, "a move order brings the squad out of the nest")
		_clear()
	r = _rifles(c + Vector2(0, 60))
	var n0 := r.men.size()
	cc.shell(r.center())
	_ok(r.men.size() < n0 and r.pinned == false, "a shell bursting in a squad kills men round it (%d of %d left)" % [r.men.size(), n0])
	_ok(r.supp > 1.0, "and shakes the rest (suppression %.1f)" % r.supp)
	print("COMBAT CHECK DONE %d" % fails)
	quit()
