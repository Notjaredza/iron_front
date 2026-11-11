extends "res://tools/check_combat.gd"
## Iron Front: the fighting round 2 check (headless), on the same open ground as check_combat.gd:
## 1. Ammo: every shot uses a round; a man with none does not fire; a squad with none says so and still fights
##    hand to hand. Near a finished depot (or HQ) our squads fill up again; far from one they do not.
## 2. Posts: an MG nest uses its rounds and stops when they run out; a finished depot near it fills it again.
## 3. Wounded: some of our men who fall are wounded, not killed. With a finished HQ they get up, walk to it, heal,
##    and join a squad of their kind that comes near; the squad grows back.
## 4. Garrisons: a rifle squad goes into a village house, its men out of sight; it fires from inside, and is much
##    harder to hit there; a move order brings it out.
## 5. Line of sight: a cliff (higher ground) between two squads blocks seeing and shooting; higher up a squad
##    shoots further.
## 6. Fog of war: a far enemy is hidden; one that comes into sight shows; one that fires gives himself away.
## Run:  Godot --headless --path . --script res://tools/check_combat2.gd [-- --seed=N]
## Ends with "COMBAT2 CHECK DONE <fails>".


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
	cc = CombatControl.new()
	root.add_child(cc)
	cc.squads = sc
	cc.build = bc
	cc.reset(nav, d)
	cc.set_process(false)
	sc.combat = cc
	sc.build = bc
	var spot: Variant = _flat(240)
	_ok(spot != null, "found open flat ground")
	if spot == null:
		print("COMBAT2 CHECK DONE %d" % fails)
		quit()
		return
	c = spot

	# 1. Ammo.
	var r := _rifles(c + Vector2(0, 60))
	var full_ammo := int(r.md[0]["ammo"])
	_ok(full_ammo == 50 and r.ammo_frac() == 1.0, "a rifleman starts with 50 rounds")
	var zs := cc.spawn("zombies", c + Vector2(0, 60), 140.0)
	for s in zs:
		s.set_process(false)
	_world(20.0)
	var used := 0
	var shots := 0
	for m in r.md:
		used += full_ammo - int(m["ammo"])
		shots += int(m["shots"])
	_ok(used > 0 and used == shots, "every shot uses a round (%d shots, %d rounds)" % [shots, used])
	for m in r.md:
		m["ammo"] = 0
	var shots_before := 0
	for m in r.md:
		shots_before += int(m["shots"])
	_world(10.0)
	var shots_after := 0
	for m in r.md:
		shots_after += int(m["shots"])
	_ok(shots_after == shots_before and r.out_of_ammo(), "out of ammo it does not fire")
	_ok(r.banner.text.contains("OUT OF AMMO"), "and its banner says so")
	_world(120.0, func() -> bool: return r.men.is_empty() or cc.enemies.is_empty() or r.melee_on)
	_ok(r.melee_on or r.men.is_empty(), "with no ammo it still fights hand to hand")
	_clear()
	r = _rifles(c + Vector2(0, 30))
	for m in r.md:
		m["ammo"] = 5
	_world(10.0)
	_ok(r.ammo_frac() < 0.2, "far from a depot it does not fill up")
	var dep := bc.place("depot", nav.cell_of(c) + Vector2i(-1, -1), 0)
	_ok(dep != null, "a depot is placed")
	if dep:
		bc._finish(dep)
		r.order_move(dep.approach(nav))
		_world(60.0, func() -> bool: return r.ammo_frac() >= 1.0)
		_ok(r.ammo_frac() >= 1.0, "near the finished depot it fills up again")

	# 2. An MG nest's rounds (the depot goes first: one near the nest would keep it full).
	if dep:
		bc._remove(dep)
	var nest := bc.place("mg_nest", nav.cell_of(c) + Vector2i(8, 12), 0)
	_ok(nest != null, "an MG nest is placed")
	if nest:
		bc._finish(nest)
		var crew := _rifles(c + Vector2(64, 120))
		cc.man_post(crew, nest)
		_world(60.0, func() -> bool: return crew.in_post)
		_world(0.5)
		var a0 := cc.post_ammo(nest)
		zs = cc.spawn("zombies", nest.center(), 150.0)
		for s in zs:
			s.set_process(false)
		_world(10.0)
		var a1 := cc.post_ammo(nest)
		_ok(a0 == float(CombatControl.MG_AMMO) and a1 < a0, "the MG uses its rounds (%.0f to %.0f)" % [a0, a1])
		(cc._posts[nest] as Dictionary)["ammo"] = 0.0
		_world(5.0)
		_ok(cc.post_ammo(nest) < 1.0, "with no depot near, an empty MG stays empty")
		var dep2 := bc.place("depot", nav.cell_of(nest.center()) + Vector2i(2, -4), 0)
		if dep2:
			bc._finish(dep2)
			_world(5.0)
			_ok(cc.post_ammo(nest) > 100.0, "a finished depot near the nest fills it again (%.0f rounds)" % cc.post_ammo(nest))
		_clear()
		for s2 in bc.sites.duplicate():
			bc._remove(s2)

	# 3. Wounded.
	var hq := bc.place("hq", nav.cell_of(c) + Vector2i(-1, -12), 0)
	_ok(hq != null, "an HQ (the aid post) is placed")
	if hq:
		bc._finish(hq)
		r = _rifles(c + Vector2(0, 40))
		cc.rng.seed = 3
		var n_hit := 0
		while cc.wounded.is_empty() and n_hit < 12 and not r.men.is_empty():
			r.md[0]["hp"] = 1
			cc.wound(r, 0)
			n_hit += 1
		_ok(not cc.wounded.is_empty(), "a man who falls is wounded, not killed, about a third of the time (%d hits for one wounded)" % n_hit)
		var left := r.men.size()
		_world(DOWN_WAIT)
		_ok(not cc.wounded.is_empty() and cc.wounded[0]["state"] == "walk", "after lying a while he gets up and walks to the aid post")
		_world(240.0, func() -> bool: return cc.wounded.is_empty())
		_ok(cc.wounded.is_empty() and cc.healed_waiting() >= 1, "he reaches the HQ to heal (%d there)" % cc.healed_waiting())
		r.order_move(hq.approach(nav))
		_world(120.0, func() -> bool: return r.men.size() > left)
		_ok(r.men.size() == left + 1 and _consistent(r), "healed, he joins the squad when it comes to the HQ (%d to %d men)" % [left, r.men.size()])
		_clear()
		for s2 in bc.sites.duplicate():
			bc._remove(s2)

	# 4. Garrisons.
	var house: Garrison = null
	for g in cc.garrisons:
		if g.kind == "house" and cc.route_ratio(g.door(nav), nav.nearest_open(g.door(nav) + Vector2(0, 60))) < 2.0:
			house = g
			break
	_ok(house != null, "a village house to garrison (%d houses and ruins on the map)" % cc.garrisons.size())
	if house:
		_ok(cc.garrison_at(house.at) == house, "a click on the house finds it")
		var door := house.door(nav)
		r = _rifles(nav.nearest_open(door + Vector2(0, 40)))
		cc.garrison(r, house)
		_world(90.0, func() -> bool: return r.in_post)
		_world(0.5)
		_ok(r.in_post and house.crew == r and not r.men[0].visible, "the squad goes into the house, out of sight")
		_ok(r.banner.text.contains("in the house"), "its banner says where it is")
		var e := Squad.new()
		cc.add_child(e)
		e.setup(nav, nav.nearest_open(door + Vector2(0, -80)), Vector2(0, 1), 9, "Red coats", "redcoats")
		e.set_process(false)
		cc.enemies.append(e)
		var inside := cc.hit_chance(e, r, 70.0, r.mpos[0])
		r.in_post = false
		var outside := cc.hit_chance(e, r, 70.0, r.mpos[0])
		r.in_post = true
		_ok(inside <= outside * 0.3, "inside it is much harder to hit (%.3f, in the open %.3f)" % [inside, outside])
		var s0: int = cc.stats["shots"][0]
		_world(15.0)
		_ok(int(cc.stats["shots"][0]) > s0, "it fires from inside the house")
		sc.squads[0].selected = true
		sc._order(nav.nearest_open(door + Vector2(20, 30)), false)
		_world(1.0)
		_ok(not r.in_post and r.men[0].visible and house.crew == null, "a move order brings it out")
		_clear()

	# 5. Line of sight and high ground: two squads on either side of a cliff edge, one on the plateau.
	var low: Variant = null
	var high: Variant = null
	for z in range(40, d.h - 40, 5):
		for x in range(40, d.w - 40, 5):
			var i := z * d.w + x
			if d.walk[i] == 1 and x + 6 < d.w and d.walk[z * d.w + x + 6] == 2 and nav.is_open((Vector2(x, z) + Vector2(0.5, 0.5)) * 8.0) \
					and nav.is_open((Vector2(x + 6, z) + Vector2(0.5, 0.5)) * 8.0):
				low = (Vector2(x, z) + Vector2(0.5, 0.5)) * 8.0
				high = (Vector2(x + 6, z) + Vector2(0.5, 0.5)) * 8.0
				break
		if low != null:
			break
	_ok(low != null, "found a cliff edge (base level next to a plateau)")
	if low != null:
		var a := _rifles(low)
		var far_hi := Vector2(high) + Vector2(60, 0)
		var b := Squad.new()
		cc.add_child(b)
		b.setup(nav, far_hi, Vector2(-1, 0), 9, "Red coats", "redcoats")
		b.set_process(false)
		cc.enemies.append(b)
		var blocked := not cc.clear_sight(a.center(), cc.eye(a), b.center(), cc.eye(b))
		var open_ := cc.clear_sight(Vector2(high), cc.eye(b) , b.center(), cc.eye(b))
		_ok(blocked and open_, "the cliff edge blocks sight from below to well back on the plateau; on the plateau it is clear")
		var up := cc.eff_range(b, a)
		var flat := float(b.spec["range"])
		_ok(up > flat, "from higher up the red coats shoot further (%.0f m, on the flat %.0f m)" % [up, flat])
		_clear()

	# 6. Fog of war.
	r = _rifles(c + Vector2(0, 60))
	var foe := Squad.new()
	cc.add_child(foe)
	foe.setup(nav, nav.nearest_open(c + Vector2(0, 60 - 600)), Vector2(0, 1), 9, "Red coats", "redcoats")
	foe.set_process(false)
	cc.enemies.append(foe)
	cc._fog()
	_ok(not cc.seen.has(foe) and not foe.visible, "an enemy 600 m off is hidden")
	_ok(not cc.can_shoot(r, foe), "and cannot be fired on")
	foe.at = nav.nearest_open(c + Vector2(0, 60 - 150))
	for i in foe.men.size():
		foe.mpos[i] = foe.at + Vector2(float(i % 6) * 2.0, float(i / 6) * 2.0)
	cc._fog()
	_ok(cc.seen.has(foe) and foe.visible, "at 150 m in the open it shows")
	foe.at = nav.nearest_open(c + Vector2(0, 60 - 350))
	for i in foe.men.size():
		foe.mpos[i] = foe.at + Vector2(float(i % 6) * 2.0, float(i / 6) * 2.0)
	cc._fog()
	var hid := not cc.seen.has(foe)
	cc._fired[foe] = cc.t
	cc._fog()
	_ok(hid and cc.seen.has(foe), "at 350 m it is hidden until it fires, then it gives itself away")
	print("COMBAT2 CHECK DONE %d" % fails)
	quit()


const DOWN_WAIT := 13.0
