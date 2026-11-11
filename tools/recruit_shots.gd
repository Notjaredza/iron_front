extends "res://tools/comms_shots.gd"
## Iron Front: pictures of the recruitment round (needs a screen or xvfb), saved to results/recruit/:
##   recruit_panel.png     a barracks selected: the recruit panel, the queue with its training bar, the rally flag,
##                         the supply line, and the build menu with prices
##   recruit_troops.png    the new troops: assault section, LMG team, sniper pair, mortar crew (set up), linemen
##   recruit_fight.png     an LMG team and an assault section against a zombie horde, grenades bursting
##   recruit_mortar.png    the mortar crew set up and firing
##   recruit_linemen.png   linemen laying telegraph wire, the poles going up behind them
##   recruit_chain.png     a squad with chained orders (the dotted route)
##   recruit_officer.png   the officer holding the line, his card with Rally and Hold the line
## Run:  xvfb-run -s "-screen 0 1600x900x24" Godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##       --script res://tools/recruit_shots.gd
## Ends with "RECRUIT SHOTS DONE".

const OUT3 := "res://results/recruit/"
var rc: RecruitControl


func _fast(secs: float, done: Callable = Callable()) -> void:
	rc.set_process(false)
	var t := 0.0
	while t < secs:
		var step := minf(1.0, secs - t)
		super._fast(step, done)
		rc.step(step)
		t += step
		if done.is_valid() and done.call():
			break
	rc.set_process(true)


func _shot3(nm: String, frames := 6) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT3 + nm + ".png")
	print("saved ", nm)


func _place_at(s: Squad, p: Vector2, face := Vector2(0, -1)) -> void:
	s.path.clear()
	s.at = main.nav.nearest_open(p)
	s.heading = face
	for i in s.mpos.size():
		s.mpos[i] = s.at + Vector2(float(i % 4) * 2.2 - 3.3, float(i / 4) * 2.5)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT3))
	while not main.ready_map:
		await process_frame
	cc = main.combat
	sc = main.squads
	cm = main.comms
	bc = main.build
	rc = main.recruit
	cam = main.cam
	cam.enabled = false
	var off := cm.officer
	var start: Vector2 = off.at
	rc.supply = 2500.0
	var bar := _site("barracks", start + Vector2(-50, 30))
	var hq := _site("hq", start + Vector2(50, 30))
	print("sites ", bar != null, " ", hq != null)
	# 1. The panel.
	for k in ["rifles", "assault", "lmg"]:
		rc.recruit(bar, k)
	rc.set_rally(bar, start + Vector2(-50, -30))
	_fast(20.0)
	rc.select_site(bar)
	bc.menu.visible = true
	bc.menu._show_tab(0)
	_fast(0.2)
	_look(bar.center(), bar.center() + Vector2(35, 60), 40.0)
	await _shot3("recruit_panel", 10)
	rc.select_site(null)
	bc.menu.visible = false
	# 2. The new troops, side by side, halted (the mortar set up).
	var row := start + Vector2(0, -60)
	var troops := {}
	var x := -30.0
	for k: String in ["assault", "lmg", "snipers", "mortar", "linemen"]:
		var s := rc._turn_out(bar if k != "linemen" else hq, k)
		_place_at(s, row + Vector2(x, 0))
		troops[k] = s
		x += 15.0
	_fast(6.0)
	for q in sc.squads:
		if not troops.values().has(q) and q.center().distance_to(row) < 60.0:
			_place_at(q, q.at + Vector2(0, 90))
	_fast(1.0)
	_look(row + Vector2(0, -2), row + Vector2(0, 30), 12.0)
	await _shot3("recruit_troops")
	# 3. The fight: an LMG team and the assault section against zombies.
	var lmg: Squad = troops["lmg"]
	var asl: Squad = troops["assault"]
	_place_at(lmg, row + Vector2(-20, 0))
	_place_at(asl, row + Vector2(10, -5))
	var zs := cc.spawn("zombies", row, 70.0)
	_fast(40.0, func() -> bool: return int(cc.stats.get("grenades", 0)) >= 2)
	_fast(1.6)
	_look(row + Vector2(0, -20), row + Vector2(-26, 22), 9.0)
	await _shot3("recruit_fight")
	_clear()
	# 4. The mortar firing on a red coat company we can see.
	var mo: Squad = troops["mortar"]
	cc._set_mortar(mo, false)                  # (teleported: pack up first, so it sets up again where it now is)
	mo.set_meta("still", 0.0)
	_place_at(mo, row + Vector2(0, 40))
	_fast(5.0)
	cc.spawn("redcoats", row, 160.0)
	_fast(30.0, func() -> bool: return int(cc.stats.get("bombs", 0)) >= 1)
	var gp: Vector2 = mo.at + mo.heading * 1.2
	var side := Vector2(-mo.heading.y, mo.heading.x)
	_look(gp, gp + mo.heading * 3.2 + side * 1.6, 0.9)
	await _shot3("recruit_mortar")
	_clear()
	# 5. Linemen laying wire from the HQ to a telegraph post.
	var tp: BuildSite = null
	for ang: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.2, -2.2, 3.1]:
		var cand := _site("telegraph", hq.center() + Vector2(0, -240).rotated(ang))
		if cand == null:
			continue
		if cc.route_ratio(cm._wire_side(hq, cand), cm._wire_side(cand, hq)) < 1.2:
			tp = cand
			break
		bc._remove(cand)                         # a long way round from the HQ: try another spot
	if hq and tp:
		var ln: Squad = troops["linemen"]
		_place_at(ln, hq.center() + Vector2(-20, -20))
		cm.lay_wire(hq, tp, false)
		var w: Dictionary = cm.wires.back()
		_fast(400.0, func() -> bool: return float(w["laid"]) > 0.45)
		var lp := ln.center()
		var dir: Vector2 = (tp.center() - hq.center()).normalized()
		_look(lp - dir * 30.0, lp + dir * 10.0 + Vector2(-dir.y, dir.x) * 10.0, 5.0)
		await _shot3("recruit_linemen")
	# 6. Chained orders.
	var r: Squad = sc.squads[0]
	_place_at(r, start + Vector2(0, -20))
	r.queue.clear()
	r.queue_move(start + Vector2(-40, -70))
	r.queue_move(start + Vector2(30, -110))
	r.queue_move(start + Vector2(70, -60))
	for s in sc.squads:
		s.selected = s == r
	_fast(2.0)
	_look(start + Vector2(15, -60), start + Vector2(15, 60), 110.0)
	await _shot3("recruit_chain")
	# 7. The officer holding the line.
	for s in sc.squads:
		s.selected = s == off
	cm.hold()
	_fast(1.5)
	var oc: Vector2 = off.mpos[off.officer_index()]
	_look(oc, oc + Vector2(4, -5), 1.8)
	await _shot3("recruit_officer", 8)
	print("RECRUIT SHOTS DONE")
	quit()
