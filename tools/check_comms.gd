extends "res://tools/check_combat.gd"
## Iron Front: the comms round check (headless), on the same open ground as check_combat.gd (a long flat strip).
## 1. The officer: three men (him and two guards); he does not fire, the guards do.
## 2. Near him (150 m) an order is taken at once; far away a runner carries it, and it arrives about when the
##    card said it would. While it is on the way the squad's card says "order coming".
## 3. A newer order beats an older one: the old one arriving late is dropped.
## 4. Telegraph wire: with the HQ by the officer and a telegraph post by the far squad, wired, an order gets there
##    much sooner, down the wire and then a short run.
## 5. A shell near the wire cuts it; the next order goes by runner again; engineers splice it and it works again.
## 6. A runner post: its runners run faster.
## 7. A runner who runs past the enemy can be shot; another is sent and the order still arrives.
## 8. Reports: a far squad that sees the enemy reports it, and the report arrives late; a near one at once.
## 9. Near the officer squads hit more and are pinned less.
## 10. The officer hit: wounded, carried to the HQ, recovers; hit again while wounded he dies and the run is over.
## 11. A wave whose last man falls counts as beaten off.
## Run:  Godot --headless --path . --script res://tools/check_comms.gd [-- --seed=N]
## Ends with "COMMS CHECK DONE <fails>".

var cm: CommsControl


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
	cm = CommsControl.new()
	root.add_child(cm)
	cm.squads = sc
	cm.build = bc
	cm.combat = cc
	cm.reset(nav, d)
	cm.set_process(false)
	sc.combat = cc
	sc.build = bc
	sc.comms = cm
	cc.comms = cm
	bc.comms = cm
	var spot: Variant = _flat(240)
	_ok(spot != null, "found open flat ground")
	if spot == null:
		print("COMMS CHECK DONE %d" % fails)
		quit()
		return
	c = spot

	# 1. The officer.
	var off := cm.spawn_officer(c + Vector2(0, 200))
	off.set_process(false)
	_ok(off.men.size() == 3 and off.officer_index() == 0 and off.carriers() == Vector2i(1, 2), "the officer comes with two guards")
	_ok(not off.has_clip(0, "fire") and off.has_clip(1, "fire") and off.has_clip(2, "fire"), "he does not fire; his guards do")
	_ok(off.has_clip(0, "carried") and off.has_clip(1, "carry_front") and off.has_clip(2, "carry_rear"), "and they have the carry clips")

	# 2. Near: at once. Far: a runner.
	var near := _rifles(c + Vector2(0, 110), Vector2(0, -1), "Near")
	var far := _rifles(c + Vector2(0, -200), Vector2(0, -1), "Far")
	_ok(cm.near_officer(near) and not cm.near_officer(far), "one squad is near the officer, one far (%d m)" % int(far.center().distance_to(cm.officer_at())))
	_select([near])
	sc._order(near.at + Vector2(30, 0), false, sc.selected())
	_ok(near.moving(), "a near squad moves at once")
	_select([far])
	var goal := far.at + Vector2(25, 0)
	var sent_at := cm.t
	sc._order(goal, false, sc.selected())
	_ok(not far.moving() and cm.messages.size() == 1, "a far squad waits for the order")
	_step(0.5)
	var eta := float(far.get_meta("order_eta", -1.0))
	_ok(eta > sent_at + 60.0, "its card says the order is coming in about %d s" % int(eta - sent_at))
	_ok(far.comms_tag.begins_with("order coming"), "the banner and card say \"%s\"" % far.comms_tag)
	_ok(cm.messages[0].has("runner") and is_instance_valid(cm.messages[0]["runner"]["man"]), "a runner sets off")
	var took := _step(400.0, func() -> bool: return far.moving())
	var arrived := sent_at + took + 0.5
	_ok(far.moving(), "the order arrives after %d s and the squad moves" % int(arrived - sent_at))
	_ok(absf(arrived - eta) < (eta - sent_at) * 0.35, "about when it said (said %d s)" % int(eta - sent_at))
	var left_r := cm._runners.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	_ok(cm.messages.is_empty() and left_r.is_empty(), "the runner is gone once he has delivered it")
	var by_runner := eta - sent_at
	_step(60.0, func() -> bool: return not far.moving())

	# 3. A newer order beats an older one.
	var g1 := far.at + Vector2(-30, 0)
	var g2 := far.at + Vector2(30, 0)
	sc._order(g1, false, [far] as Array[Squad])
	var old: Dictionary = cm.messages[0]
	sc._order(g2, false, [far] as Array[Squad])
	cm._deliver(cm.messages[1])                # the newer one gets there first
	var went := far.path[far.path.size() - 1] if far.moving() else far.at
	cm._deliver(old)                            # then the old one, late
	var still := far.path[far.path.size() - 1] if far.moving() else far.at
	_ok(went.distance_to(g2) < 6.0 and still.distance_to(g2) < 6.0, "the newer order holds; the late old one is dropped")
	_step(60.0, func() -> bool: return not far.moving())

	# 4. Telegraph wire.
	var hq := bc.place("hq", nav.cell_of(c + Vector2(40, 200)) + Vector2i(-1, -1), 0)
	var tp := bc.place("telegraph", nav.cell_of(c + Vector2(30, -190)), 0)
	_ok(hq != null and tp != null, "an HQ by the officer and a telegraph post by the far squad")
	if hq == null or tp == null:
		_end()
		return
	bc._finish(hq)
	bc._finish(tp)
	_ok(cm.lay_wire(hq, tp) and cm.live(cm.wires[0]), "a wire between them (%d m)" % int(hq.center().distance_to(tp.center())))
	_ok(not cm.lay_wire(hq, tp), "the same wire twice is refused")
	sent_at = cm.t
	sc._order(far.at + Vector2(0, 20), false, [far] as Array[Squad])
	var legs: Array = cm.messages[0]["legs"]
	var types := legs.map(func(l: Dictionary) -> String: return l["type"])
	_ok(types.has("wire"), "the order goes down the wire (%s)" % ", ".join(types))
	var wire_eta := float(cm.messages[0]["eta"]) - sent_at
	took = _step(200.0, func() -> bool: return far.moving())
	_ok(far.moving() and took < 40.0 and took < by_runner * 0.4, "and gets there in %d s instead of %d s (said %d s)" % [int(took), int(by_runner), int(wire_eta)])
	_step(60.0, func() -> bool: return not far.moving())

	# 5. Cut and spliced.
	var mid := (hq.center() + tp.center()) * 0.5
	cc.shell(mid + Vector2(3, 0))
	_ok(bool(cm.wires[0]["cut"]) and not cm.live(cm.wires[0]), "a shell next to the wire cuts it")
	sc._order(far.at + Vector2(0, -20), false, [far] as Array[Squad])
	types = (cm.messages[0]["legs"] as Array).map(func(l: Dictionary) -> String: return l["type"])
	_ok(not types.has("wire"), "the next order goes on foot (%s)" % ", ".join(types))
	cm.messages.clear()
	for r in cm._runners.get_children():
		r.free()
	far.remove_meta("order_eta")
	var eng := Squad.new()
	sc.add_child(eng)
	eng.setup(nav, mid + Vector2(-30, 15), Vector2(0, -1), 41, "Engineers", "engineers")
	eng.set_process(false)
	sc.squads.append(eng)
	_select([eng])
	var w: Variant = cm.cut_wire_at(cm.wires[0]["cut_at"])
	_ok(w != null, "the break can be clicked")
	cm.send([eng] as Array[Squad], func(got: Array[Squad]) -> void: cm.fix(got[0], w), "splice")
	took = _step(300.0, func() -> bool: return not bool(cm.wires[0]["cut"]))
	_ok(not bool(cm.wires[0]["cut"]) and cm.live(cm.wires[0]), "engineers walk out and splice it (%d s)" % int(took))

	# 6. A runner post: faster runners.
	var rp := bc.place("runner_post", nav.cell_of(c + Vector2(-30, 180)), 0)
	_ok(rp != null, "a runner post by the officer")
	if rp != null:
		bc._finish(rp)
		cm.wires[0]["cut"] = true                 # no wire this time
		var plain := {"kind": "order", "to": [far] as Array[Squad], "src": cm.officer_at(), "sent": cm.t}
		cm._plan(plain)
		var by_post: Array = plain["legs"]
		var from_post := false
		for l: Dictionary in by_post:
			if l["type"] == "run" and l["from"] is BuildSite and (l["from"] as BuildSite).kind == "runner_post":
				from_post = true
		var slow: float = (cm.officer_at() as Vector2).distance_to(far.center()) * CommsControl.ROUTE_F / CommsControl.RUNNER_V
		_ok(from_post and float(plain["eta"]) - cm.t < slow * 0.9, "the order goes via the runner post: %d s, not %d s" % [int(float(plain["eta"]) - cm.t), int(slow)])
		cm._drop_runner(plain)
		cm.wires[0]["cut"] = false

	# 7. A runner shot on the way.
	cm.wires[0]["cut"] = true
	if rp != null:
		bc._remove(rp)
	var rc := cc.spawn("redcoats", far.center() + Vector2(0, 300), 0.0)
	for e in rc:
		e.set_process(false)
		e.at = nav.nearest_open(c + Vector2(60, 0))
		e.path.clear()
		for i in e.mpos.size():
			e.mpos[i] = e.at + Vector2(float(i % 6) * 2.0, float(i / 6) * 2.0)
	var lost0 := int(cm.stats["runners_lost"])
	for k in 6:
		if int(cm.stats["runners_lost"]) > lost0:
			break
		sc._order(far.at + Vector2(0, 10 * (k % 2 * 2 - 1)), false, [far] as Array[Squad])
		_step(200.0, func() -> bool: return int(cm.stats["runners_lost"]) > lost0 or cm.messages.is_empty(), func() -> void:
			for e in rc:
				e.path.clear())
	_ok(int(cm.stats["runners_lost"]) > lost0, "a runner running past red coats is shot (%d lost of %d sent)" % [int(cm.stats["runners_lost"]), int(cm.stats["runners_sent"])])
	_step(6.0, func() -> bool: return cm.messages.any(func(m: Dictionary) -> bool: return m.has("runner")))
	_ok(cm.messages.any(func(m: Dictionary) -> bool: return m.has("runner")), "and another is sent with the order")
	for e in rc:
		e.free()
	cc.enemies.clear()
	cc._pending.clear()
	took = _step(300.0, func() -> bool: return cm.messages.is_empty())
	_ok(cm.messages.is_empty(), "the order still gets there")
	cm.wires[0]["cut"] = false

	# 8. Reports.
	cm.reports.clear()
	var zs := cc.spawn("zombies", far.center(), 200.0)
	for e in zs:
		e.set_process(false)
	var sent_r := cm.t
	_step(30.0, func() -> bool: return not cm.messages.filter(func(m: Dictionary) -> bool: return m["kind"] == "report").is_empty())
	var rep := cm.messages.filter(func(m: Dictionary) -> bool: return m["kind"] == "report")
	_ok(not rep.is_empty() and String(rep[0]["text"]).contains("enemy in sight"), "the far squad sends a report: \"%s\"" % (rep[0]["text"] if not rep.is_empty() else "none"))
	for e in zs:
		e.free()
	cc.enemies.clear()
	cc._pending.clear()
	_step(200.0, func() -> bool: return not cm.reports.is_empty())
	_ok(not cm.reports.is_empty() and float(cm.reports[0]["late"]) > 2.0, "it arrives %d s late (down the wire)" % int(float(cm.reports[0]["late"]) if not cm.reports.is_empty() else -1))
	cm.reports.clear()
	cm.report(near, "Near: test", near.center())
	_ok(not cm.reports.is_empty() and float(cm.reports[0]["late"]) == 0.0, "a report from near the officer is in at once")

	# 9. Steadier near the officer.
	var dummy := _rifles(c + Vector2(0, 0), Vector2(0, -1), "Target")
	dummy.side = 1
	var p_near := cc.hit_chance(near, dummy, 100.0, dummy.center())
	var p_far := cc.hit_chance(far, dummy, 100.0, dummy.center())
	_ok(p_near > p_far * 1.2, "near the officer a squad hits more (%.3f against %.3f)" % [p_near, p_far])
	_ok(cc._calm(near) < 1.0 and cc._calm(far) == 1.0, "and is pinned less")
	sc.squads.erase(dummy)
	dummy.free()

	# 10. The officer hit.
	var oj := off.officer_index()
	cc.wound(off, oj)
	_ok(cm.wounded and off.men.size() == 3, "hit once, the officer is wounded, not dead")
	_ok(off.carried and off.moving(), "his guards carry him towards the HQ")
	var before := off.center().distance_to(hq.center())
	_step(5.0)
	_ok(off.center().distance_to(hq.center()) < before, "they are on their way")
	var ok_pos := absf(off.men[oj].position.y - nav.height(off.mpos[oj]) - 0.72) < 0.05
	_ok(ok_pos, "he is held up between them")
	sc._order(off.at + Vector2(50, 0), false, [off] as Array[Squad])
	_ok(sc.orderable([off] as Array[Squad]).is_empty(), "the wounded officer takes no orders")
	took = _step(300.0, func() -> bool: return off.lying)
	_ok(off.lying and off.center().distance_to(hq.center()) <= CommsControl.AID_R + 5.0, "carried to the HQ, he lies there (%d s)" % int(took))
	took = _step(120.0, func() -> bool: return not cm.wounded)
	_ok(not cm.wounded and not off.lying, "and is back on his feet after %d s" % int(took))
	cc.wound(off, off.officer_index())
	_ok(cm.wounded, "hit again: wounded again")
	cc.wound(off, off.officer_index())
	_ok(cm.run_over and off.officer_index() < 0, "hit while wounded he dies and the run is over")
	_ok(cm._over_box.visible and cm._over_text.text.contains("run is over"), "the end of the run shows")
	sc._order(near.at + Vector2(0, 30), false, [near] as Array[Squad])
	_ok(not near.moving() or near.path.is_empty(), "no more orders go out")

	# 11. A wave beaten off.
	var wb := int(cc.get_meta("waves_beaten", 0))
	var zz := cc.spawn("zombies", c, 100.0)
	for e in zz:
		while not e.men.is_empty():
			e.md[0]["hp"] = 1
			cc.wound(e, 0)
	cc._tidy()
	_ok(int(cc.get_meta("waves_beaten", 0)) == wb + 1, "a wave whose last man falls counts as beaten off")
	_end()


func _end() -> void:
	print("COMMS CHECK DONE %d" % fails)
	quit()


func _select(list: Array) -> void:
	for s in sc.squads:
		s.selected = list.has(s)


## Steps the world with the comms (and the build sites).
func _step(secs: float, done: Callable = Callable(), watch: Callable = Callable()) -> float:
	var tt := 0.0
	while tt < secs:
		for s in sc.squads + cc.enemies:
			s._step(DT)
			s._place_men(DT)
		cc.step(DT)
		bc.step(DT)
		cm.step(DT)
		tt += DT
		if watch.is_valid():
			watch.call()
		if done.is_valid() and done.call():
			break
	return tt
