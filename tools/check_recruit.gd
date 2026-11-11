extends "res://tools/check_combat.gd"
## Iron Front: the recruitment round check (headless), on the open ground check_combat.gd finds.
## 1. Supply: starts at RecruitControl.START, comes in by itself and faster with a finished HQ and depot; a buy
##    that is too dear is refused; a cancelled building gives its supply back, one taken down half.
## 2. Recruiting: the barracks trains rifles, assault, LMG, snipers and mortar (not engineers); the HQ engineers and
##    linemen. Queuing pays; taking off the queue pays back; at most 5. Training takes the unit's time, then the
##    squad comes out by the door and walks to the rally point.
## 3. The new troops: each comes with its men and moves (assault grenades, the LMG gunner and marksman prone).
## 4. The LMG gunner fires far faster than a rifleman and pins harder.
## 5. The marksman picks leaders first; the spotter sees half as far again.
## 6. An assault section throws grenades when the enemy is close, and they hurt.
## 7. A mortar crew sets up when halted and lobs bombs at enemies we can see, using its bombs.
## 8. Linemen lay a planned wire (it works once they reach the far end) and mend a cut by themselves.
## 9. Chained orders: a squad goes through each point in turn.
## 10. The officer's powers: Rally frees pinned squads near him (and then must wait); Hold the line stops pinning.
## Run:  Godot --headless --path . --script res://tools/check_recruit.gd [-- --seed=N]
## Ends with "RECRUIT CHECK DONE <fails>".

var cm: CommsControl
var rc: RecruitControl


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
	rc = RecruitControl.new()
	root.add_child(rc)
	rc.squads = sc
	rc.build = bc
	rc.reset(nav)
	rc.set_process(false)
	sc.combat = cc
	sc.build = bc
	sc.comms = cm
	cc.comms = cm
	bc.comms = cm
	bc.economy = rc
	var spot: Variant = _flat(240)
	_ok(spot != null, "found open flat ground")
	if spot == null:
		_end()
		return
	c = spot

	# 1. Supply.
	_ok(int(rc.supply) == int(RecruitControl.START), "supply starts at %d" % int(rc.supply))
	var s0 := rc.supply
	_step(10.0)
	_ok(absf(rc.supply - s0 - RecruitControl.BASE * 10.0) < 0.5, "it comes in by itself (%.1f a second)" % RecruitControl.BASE)
	var hq := _site("hq", c + Vector2(50, 190))
	var bar := _site("barracks", c + Vector2(-50, 170))
	var dep := _site("depot", c + Vector2(50, 140))
	_ok(hq != null and bar != null and dep != null, "an HQ, a barracks and a depot")
	if hq == null or bar == null or dep == null:
		_end()
		return
	for s in [hq, bar, dep]:
		bc._finish(s)
	_ok(absf(rc.income() - (RecruitControl.BASE + 1.0 + 1.5)) < 0.01, "with them it comes in faster (%.1f a second)" % rc.income())
	rc.supply = 50.0
	_ok(not rc.pay(100.0) and int(rc.supply) == 50, "a buy that is too dear is refused")
	rc.supply = 1000.0
	var plot := _site("runner_post", c + Vector2(-60, 120))
	plot.set_meta("paid", bc.cost_of("runner_post"))
	rc.supply -= bc.cost_of("runner_post")
	bc.cancel(plot)
	_ok(int(rc.supply) == 1000, "a building cancelled before it is finished gives its supply back")
	var lab := _site("depot", c + Vector2(60, 100))
	bc._finish(lab)
	lab.set_meta("paid", 150.0)
	bc._taken_down(lab)
	_ok(int(rc.supply) == 1075, "one taken down gives half back")

	# 2. Recruiting.
	rc.supply = 2000.0
	_ok(not rc.recruit(bar, "engineers") and rc.recruit(hq, "engineers") and rc.recruit(hq, "linemen"), "the barracks does not train engineers; the HQ does, and linemen")
	rc.unqueue(hq, 0)
	rc.unqueue(hq, 0)
	_ok(int(rc.supply) == 2000, "taken off the queue, the supply comes back")
	var before := int(rc.supply)
	_ok(rc.recruit(bar, "rifles"), "a rifle squad is queued at the barracks")
	_ok(int(rc.supply) == before - 100, "and paid for (100)")
	for k in 4:
		rc.recruit(bar, "rifles")
	_ok(not rc.recruit(bar, "rifles") and (rc.queues[bar] as Array).size() == 5, "the queue holds 5")
	for k in 4:
		rc.unqueue(bar, 1)
	var flag := c + Vector2(-40, 60)
	rc.set_rally(bar, flag)
	var n0 := sc.squads.size()
	var took := _step(80.0, func() -> bool: return sc.squads.size() > n0)
	var new_sq: Squad = sc.squads.back()
	_ok(sc.squads.size() == n0 + 1 and new_sq.kind == "rifles" and new_sq.men.size() == 12, "after %d s a rifle squad of 12 comes out (%s)" % [int(took), new_sq.title])
	_ok(absf(took - 45.0) < 1.0, "training took the rifle squad's 45 s")
	_step(90.0, func() -> bool: return not new_sq.moving())
	_ok(new_sq.at.distance_to(flag) < 15.0, "it walks to the rally point")

	# 3. The new troops.
	var made := {}
	var kinds := {"assault": [bar, 8], "lmg": [bar, 4], "snipers": [bar, 2], "mortar": [bar, 3], "engineers": [hq, 4], "linemen": [hq, 2]}
	for k: String in kinds:
		var e := rc._turn_out(kinds[k][0], k)
		e.set_process(false)
		made[k] = e
		_ok(e.men.size() == int(kinds[k][1]), "%s: %d men" % [e.title, e.men.size()])
	var asl: Squad = made["assault"]
	_ok(asl.has_clip(1, "throw") and asl.has_clip(0, "melee") and not asl.has_clip(3, "fire"), "assault: grenades and bayonets; the club men do not fire")
	var lmg: Squad = made["lmg"]
	_ok(lmg.clip_for(0, "ready") == "prone" and lmg.clip_for(0, "fire") == "fire_prone", "the LMG gunner lies behind his gun")
	var sn: Squad = made["snipers"]
	_ok(sn.has_clip(0, "fire") and not sn.has_clip(1, "fire") and sn.clip_for(1, "ready") == "prone", "the marksman fires, the spotter watches, both prone")

	# 4. LMG against riflemen: shots in 30 s at the same target.
	_clear_enemies()
	for s in sc.squads.duplicate():
		if s != lmg:
			_park(s)
	var rif := _rifles(c + Vector2(30, 0), Vector2(0, -1), "Rifles test")
	_put(lmg, c + Vector2(-30, 0))
	var tgt := _enemy("redcoats", c + Vector2(0, -110))
	_step(30.0, func() -> bool: return false, func() -> void: _hold_still(tgt))
	var g_shots := int(lmg.md[0]["shots"]) if lmg.md.size() > 0 and String(lmg.md[0]["role"]) == "lmg_gunner" else 0
	var r_shots := int(rif.md[0]["shots"]) if not rif.md.is_empty() else 0
	_ok(g_shots > r_shots * 4, "in 30 s the LMG gunner fired %d rounds, a rifleman %d" % [g_shots, r_shots])
	_ok(float(TroopKinds.man_spec("lmg", "lmg_gunner")["supp"]) > float(TroopKinds.SPEC["rifles"]["supp"]) * 2.0, "and each round pins harder")
	_clear_enemies()
	_park(lmg)
	_park(rif)

	# 5. Marksman and spotter.
	_put(sn, c + Vector2(0, 100))
	var red := _enemy("redcoats", c + Vector2(0, -150))
	var j := cc._pick_leader(red, sn.mpos[0], 400.0)
	_ok(j >= 0 and String(red.md[j]["role"]) in TroopKinds.LEADERS, "the marksman picks the %s first" % String(red.md[j]["role"]))
	_clear_enemies()
	var far_e := _enemy("zombies", c + Vector2(0, 100 - 340))
	for s in sc.squads:
		if s != sn:
			_park(s)
	cc._fog()
	var seen_by_pair := cc.seen.has(far_e)
	_park(sn)
	_put(rif, c + Vector2(0, 100))
	cc._fog()
	_ok(seen_by_pair and not cc.seen.has(far_e), "the sniper pair sees an enemy 340 m off; a rifle squad there does not")
	_clear_enemies()
	_park(rif)

	# 6. Grenades.
	_put(asl, c)
	var z := _enemy("zombies", c + Vector2(0, -26))
	var men0 := z.men.size()
	var g0 := int(cc.stats.get("grenades", 0))
	_step(8.0, func() -> bool: return int(cc.stats.get("grenades", 0)) > g0 + 1, func() -> void: _hold_still(z))
	_ok(int(cc.stats.get("grenades", 0)) > g0, "the assault section throws grenades at enemies 26 m off (%d)" % (int(cc.stats.get("grenades", 0)) - g0))
	_step(3.0, func() -> bool: return false, func() -> void: _hold_still(z))
	_ok(z.men.size() < men0, "and they hurt (%d of %d left)" % [z.men.size(), men0])
	_clear_enemies()
	_park(asl)

	# 7. The mortar.
	var mo: Squad = made["mortar"]
	_put(mo, c + Vector2(0, 10))
	for m in mo.md:
		m["ammo"] = 10                           # (parked, it may already have fired at the earlier tests' enemies)
	_ok(cc._near_kind(mo.center(), ["depot", "hq"], CombatControl.RESUPPLY_R) == null, "(the mortar is away from any depot)")
	_put(rif, c + Vector2(0, -40))
	var m_e := _enemy("medieval", c + Vector2(0, -170))
	_step(3.0, func() -> bool: return false, func() -> void: _hold_still(m_e))
	_ok(not mo.deployed, "the mortar is not set up at once")
	var b0 := int(cc.stats.get("bombs", 0))
	_step(25.0, func() -> bool: return false, func() -> void: _hold_still(m_e))
	var fired := int(cc.stats.get("bombs", 0)) - b0
	_ok(mo.deployed and fired >= 2, "halted, it sets up and lobs bombs at an enemy we see %d m off (%d)" % [int(mo.center().distance_to(m_e.center())), fired])
	var left := 0
	for m in mo.md:
		left += int(m["ammo"])
	_ok(left == 30 - fired, "using its bombs (%d left)" % left)
	mo.order_move(c + Vector2(40, 10))
	_step(0.5)
	_ok(not mo.deployed, "on the move it packs up")
	_clear_enemies()
	_park(mo)
	_park(rif)

	# 8. Linemen.
	var tp := _site("telegraph", c + Vector2(30, -120))
	bc._finish(tp)
	var ln: Squad = made["linemen"]
	_put(ln, hq.center() + Vector2(-25, 20))
	cm.lay_wire(hq, tp, false)
	var w: Dictionary = cm.wires.back()
	_ok(not cm.live(w), "a planned wire does not work yet")
	_step(4.0)
	_ok(w["crew"] == ln, "free linemen take it")
	var half := _step(400.0, func() -> bool: return float(w["laid"]) > 0.4)
	_ok(float(w["laid"]) > 0.4 and not cm.live(w), "they lay it as they go (%d%% after %d s)" % [int(float(w["laid"]) * 100.0), int(half)])
	_step(400.0, func() -> bool: return cm.live(w))
	_ok(cm.live(w), "and it works once they reach the far end")
	cm.cut_near(hq.center().lerp(tp.center(), 0.5), 5.0)
	_ok(bool(w["cut"]), "a cut")
	took = _step(400.0, func() -> bool: return not bool(w["cut"]))
	_ok(not bool(w["cut"]), "the linemen mend it by themselves (%d s)" % int(took))
	_park(ln)

	# 9. Chained orders.
	_put(rif, c + Vector2(0, 0))
	var p1 := c + Vector2(0, -60)
	var p2 := c + Vector2(30, -60)
	rif.queue_move(p1)
	rif.queue_move(p2)
	_ok(rif.queue.size() == 1, "two points chained")
	var seen1 := {"near": false}                # (a lambda cannot set outer variables)
	_step(200.0, func() -> bool: return not rif.moving() and rif.queue.is_empty(), func() -> void:
		if rif.at.distance_to(p1) < 6.0:
			seen1["near"] = true)
	var near1: bool = seen1["near"]
	_ok(near1 and rif.at.distance_to(p2) < 4.0, "it goes through the first and ends at the second (%s, %d m off)" % [near1, int(rif.at.distance_to(p2))])

	# 10. The officer's powers.
	var off := cm.spawn_officer(c + Vector2(0, -20))
	off.set_process(false)
	rif.supp = 1.5
	rif.pinned = true
	_ok(cm.rally() > 0 and not rif.pinned and rif.supp == 0.0, "Rally frees a pinned squad near the officer")
	_ok(cm.rally() == 0 and cm.rally_wait() > 80.0, "and then must wait")
	_ok(cm.hold(), "Hold the line")
	rif.supp = 3.0
	cc._suppression(0.1)
	_ok(not rif.pinned and cc.holding(rif), "while it lasts a squad near him cannot be pinned")
	_step(31.0)
	_ok(not cm.hold_on(), "it ends after 30 s")
	_end()


## A site of this kind on the first free spot near p (not finished).
func _site(kind: String, p: Vector2) -> BuildSite:
	var cell := nav.cell_of(p)
	for k in 200:
		var st := bc.place(kind, cell + Vector2i(k % 13 - 6, k / 13 - 7), 0)
		if st != null:
			return st
	return null


func _end() -> void:
	print("RECRUIT CHECK DONE %d" % fails)
	quit()


func _step(secs: float, done: Callable = Callable(), watch: Callable = Callable()) -> float:
	var tt := 0.0
	while tt < secs:
		for s in sc.squads + cc.enemies:
			s._step(DT)
			s._place_men(DT)
		cc.step(DT)
		bc.step(DT)
		cm.step(DT)
		rc.step(DT)
		tt += DT
		if watch.is_valid():
			watch.call()
		if done.is_valid() and done.call():
			break
	return tt


## Puts a squad at p, halted.
func _put(s: Squad, p: Vector2) -> void:
	s.path.clear()
	s.queue.clear()
	s.at = nav.nearest_open(p)
	for i in s.mpos.size():
		s.mpos[i] = s.at + Vector2(float(i % 6) * 2.2 - 5.5, float(i / 6) * 2.5)
	s.supp = 0.0
	s.pinned = false
	s.set_meta("still", 0.0)
	cc._set_mortar(s, false)


## Out of the way, far to the south.
func _park(s: Squad) -> void:
	_put(s, c + Vector2(0, 230) + Vector2(float(s.get_instance_id() % 7) * 12.0 - 36.0, 0))


func _enemy(what: String, p: Vector2) -> Squad:
	var es := cc.spawn(what, p, 0.0)
	for e in es:
		e.set_process(false)
		_put(e, p)
	for k in range(1, es.size()):
		es[k].free()
	cc.enemies.assign([es[0]])
	return es[0]


func _hold_still(e: Squad) -> void:
	if is_instance_valid(e):
		e.path.clear()


func _clear_enemies() -> void:
	for e in cc.enemies:
		if is_instance_valid(e):
			e.free()
	cc.enemies.clear()
	cc._pending.clear()
	cc.seen.clear()
