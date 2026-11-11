extends "res://tools/fight_shots.gd"
## Iron Front: pictures of the comms round (needs a screen or xvfb), saved to results/comms/:
##   comms_officer.png   the officer and his two guards behind the rifle squads
##   comms_runner.png    a runner carrying an order out to a far squad
##   comms_map.png       the comms map (O): the officer's reach, the HQ and telegraph posts on their wire, a runner's way
##   comms_wire.png      telegraph poles and wire running out from the HQ
##   comms_cut.png       a cut wire (marked) and engineers splicing it
##   comms_cards.png     a far squad's card saying "order coming", and reports at the top right
##   comms_carried.png   the wounded officer carried back by his guards
##   comms_over.png      the end of the run
## Run:  xvfb-run -s "-screen 0 1600x900x24" Godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##       --script res://tools/comms_shots.gd
## Ends with "COMMS SHOTS DONE".

const OUT2 := "res://results/comms/"
var cm: CommsControl
var bc: BuildControl


func _fast(secs: float, done: Callable = Callable()) -> void:
	_hold(true)
	cm.set_process(false)
	bc.set_process(false)
	var t := 0.0
	while t < secs:
		for s in sc.squads + cc.enemies:
			s._step(DT)
			s._place_men(DT)
		cc.step(DT)
		bc.step(DT)
		cm.step(DT)
		for s in sc.squads + cc.enemies:
			for ap in s.players:
				ap.advance(DT)
		for n in cm._runners.get_children():
			for ap in n.get_children():
				if ap is AnimationPlayer:
					(ap as AnimationPlayer).advance(DT)
		t += DT
		if done.is_valid() and done.call():
			break
	_hold(false)
	cm.set_process(true)
	bc.set_process(true)


func _shot2(nm: String, frames := 6) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT2 + nm + ".png")
	print("saved ", nm)


func _site(kind: String, near: Vector2) -> BuildSite:
	var cell: Vector2i = main.nav.cell_of(near)
	for k in 120:
		var s := bc.place(kind, cell + Vector2i(k % 11 - 5, k / 11 - 5), 0, bc.men_cells())
		if s != null:
			bc._finish(s)
			return s
	return null


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT2))
	while not main.ready_map:
		await process_frame
	cc = main.combat
	sc = main.squads
	cm = main.comms
	bc = main.build
	cam = main.cam
	cam.enabled = false
	bc.menu.visible = false
	var off := cm.officer
	var start: Vector2 = off.at
	_fast(3.0)
	# 1. The officer and his guards.
	_look(off.center(), off.center() + Vector2(6, -7), 2.6)
	await _shot2("comms_officer")

	# The network: an HQ by the officer, a telegraph post half way and one out by a far squad.
	var hq := _site("hq", start + Vector2(30, 10))
	var far_spot: Vector2 = main.nav.nearest_open(start + Vector2(0, -380))
	if cc.route_ratio(far_spot, start) > 1.6:
		far_spot = cc.spawn_point(start, 380.0)
	var tp1 := _site("telegraph", start.lerp(far_spot, 0.5) + Vector2(20, 0))
	var tp2 := _site("telegraph", far_spot + Vector2(25, 10))
	print("sites ", hq != null, " ", tp1 != null, " ", tp2 != null)
	if hq and tp1:
		cm.lay_wire(hq, tp1)
	if tp1 and tp2:
		cm.lay_wire(tp1, tp2)
	var rp := _site("runner_post", start + Vector2(-35, 0))
	var far: Squad = sc.squads[2]
	far.at = far_spot
	far.path.clear()
	for i in far.men.size():
		far.mpos[i] = far_spot + Vector2(float(i % 6) * 2.2 - 5.5, float(i / 6) * 2.5)
	var mid: Squad = sc.squads[1]
	var fd: Vector2 = (far_spot - start).normalized()
	var mid_spot: Vector2 = main.nav.nearest_open(start.lerp(far_spot, 0.6) + Vector2(-fd.y, fd.x) * 60.0)
	print("mid squad %d m from the officer" % int(mid_spot.distance_to(start)))
	mid.at = mid_spot
	for i in mid.men.size():
		mid.mpos[i] = mid_spot + Vector2(float(i % 6) * 2.2 - 5.5, float(i / 6) * 2.5)
	_fast(1.0)
	# An order to the mid squad (no wire near it: a runner) and one to the far squad (down the wire).
	var mids: Array[Squad] = [mid]
	sc._order(mid_spot + Vector2(-40, -30), false, mids)
	var fars: Array[Squad] = [far]
	sc._order(far_spot + Vector2(30, -20), false, fars)
	_fast(6.5)
	# 2. The comms map from above.
	cm.overlay = true
	_fast(0.1)
	var c := start.lerp(far_spot, 0.5)
	_look(c, c + Vector2(260, 330), 330.0)
	await _shot2("comms_map")
	cm.overlay = false
	# 3. A runner on his way (a fresh order to the far squad's neighbour, well out of the officer's reach).
	var mids2: Array[Squad] = [mid]
	sc._order(mid.at + Vector2(25, 25), false, mids2)
	var got := {"runner": null, "first": Vector2.INF}     # (a lambda cannot set the outer variables)
	_fast(60.0, func() -> bool:
		for m in cm.messages:
			if m.has("runner") and m["kind"] == "order":
				if got["first"] == Vector2.INF:
					got["first"] = m["runner"]["at"]
				if (m["runner"]["at"] as Vector2).distance_to(got["first"]) > 45.0:
					got["runner"] = m["runner"]
					return true
		return false)
	var runner: Variant = got["runner"]
	if runner != null:
		var rp2: Vector2 = runner["at"]
		var man: Node3D = runner["man"]
		var fwd := Vector2(-sin(man.rotation.y), -cos(man.rotation.y))
		_look(rp2 + fwd * 1.0, rp2 + fwd * 5.0 + Vector2(-fwd.y, fwd.x) * 8.0, 2.5)
		await _shot2("comms_runner")
	# 4. The cards: the mid squad selected while its order is still coming; and reports at the top right.
	var mids3: Array[Squad] = [mid]
	sc._order(mid.at + Vector2(-25, 20), false, mids3)
	_fast(1.0)
	for s in sc.squads:
		s.selected = s == mid
	cm._arrived_report("Rifles 3: enemy in sight, Red coats 1, 240 m north", far.center(), cm.t - 41.0)
	cm._arrived_report("Rifles 3: under fire", far.center(), cm.t - 38.0)
	_look(mid.center(), mid.center() + Vector2(18, 16), 11.0)
	await _shot2("comms_cards", 8)
	for s in sc.squads:
		s.selected = false
	# 5. Poles and wire from the HQ.
	if hq and tp1:
		var a: Vector2 = hq.center()
		var dir: Vector2 = (tp1.center() - a).normalized()
		_look(a + dir * 70.0, a - dir * 25.0 + Vector2(-dir.y, dir.x) * 30.0, 14.0)
		await _shot2("comms_wire")
	# 6. Cut by a shell, and engineers splicing it.
	if hq and tp1:
		var cut_p: Vector2 = hq.center().lerp(tp1.center(), 0.4)
		cm.cut_near(cut_p, 10.0)                   # (a shell does the same; this keeps its smoke out of the picture)
		var w: Variant = cm.cut_wire_at(cut_p, 20.0)
		var eng: Squad = null
		for s in sc.squads:
			if s.is_engineers():
				eng = s
				break
		if w != null and eng != null:
			cm.fix(eng, w)
			_fast(240.0, func() -> bool: return eng.working and eng.men_at_work() >= 3)
			_fast(2.0)
			var at: Vector2 = w["cut_at"]
			_look(at, at + Vector2(10, 9), 6.0)
			await _shot2("comms_cut")
	# 7. The officer wounded and carried.
	cm.messages.clear()
	for r in cm._runners.get_children():
		r.queue_free()
	off.at = main.nav.nearest_open(start + Vector2(0, -90))
	for i in off.men.size():
		off.mpos[i] = off.at + Vector2(float(i) * 1.5, 0)
	_fast(0.5)
	cc.wound(off, off.officer_index())
	_fast(9.0)
	var oc: Vector2 = off.mpos[off.officer_index()]
	var hd: Vector2 = off.heading
	_look(oc, oc + Vector2(-hd.y, hd.x) * 6.0 + hd * 3.0, 2.0)
	await _shot2("comms_carried")
	# 8. Hit again: the end of the run.
	cc.wound(off, off.officer_index())
	_look(oc, oc + Vector2(20, 20), 18.0)
	await _shot2("comms_over", 8)
	print("COMMS SHOTS DONE")
	quit()
