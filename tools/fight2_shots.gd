extends "res://tools/fight_shots.gd"
## Iron Front: pictures of fighting round 2 (needs a screen or xvfb), saved to results/fight/:
##   fight_garrison.png   a rifle squad in a village house firing on red coats
##   fight_wounded.png    wounded men getting up and walking back to the HQ
##   fight_cards.png      the unit card with men left of full strength and ammo
## Run:  xvfb-run -s "-screen 0 1600x900x24" Godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##       --script res://tools/fight2_shots.gd
## Ends with "FIGHT2 SHOTS DONE".


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	while not main.ready_map:
		await process_frame
	cc = main.combat
	sc = main.squads
	cam = main.cam
	cam.enabled = false
	var bc: BuildControl = main.build
	bc.menu.visible = false
	var r: Squad = sc.squads[0]
	# the nearest house with open ground north of it
	var house: Garrison = null
	var bd := INF
	for g in cc.garrisons:
		var d: float = g.at.distance_to(r.at)
		if g.kind == "house" and d < bd and cc.route_ratio(g.door(main.nav), r.at) < 2.0:
			bd = d
			house = g
	if house == null:
		print("no house")
		quit()
		return
	# teleport the squad next to it, then send it in
	r.at = house.door(main.nav)
	for i in r.men.size():
		r.mpos[i] = r.at + Vector2(float(i % 4), float(i / 4))
	cc.garrison(r, house)
	_fast(20.0, func() -> bool: return r.in_post)
	var reds := cc.spawn("redcoats", house.at, 160.0)
	_fast(120.0, func() -> bool: return cc.stats["shots"][1] > 4 and cc.stats["shots"][0] > 10)
	_fast(0.4)
	_look(house.at + Vector2(0, -20), house.at + Vector2(22, 18), 7.0)
	await _shot("fight_garrison")
	_clear()
	# wounded walking back to an HQ
	var hq: BuildSite = null
	var cell: Vector2i = main.nav.cell_of(sc.squads[2].at + Vector2(0, 40))
	for k in 60:
		hq = bc.place("hq", cell + Vector2i(k % 9 - 4, k / 9), 0, bc.men_cells())
		if hq:
			break
	if hq:
		bc._finish(hq)
		var w: Squad = sc.squads[2]
		for k in 4:
			cc.rng.seed = 11 + k
			var tries := 0
			var before := cc.wounded.size()
			while cc.wounded.size() == before and tries < 10 and w.men.size() > 3:
				w.md[0]["hp"] = 1
				cc.wound(w, 0)
				tries += 1
		_fast(16.0)
		var wp: Vector3 = (cc.wounded[0]["body"] as Node3D).global_position if not cc.wounded.is_empty() else Vector3(w.at.x, 0, w.at.y)
		_look(Vector2(wp.x, wp.z), Vector2(wp.x, wp.z) + Vector2(9, -7), 3.0)
		await _shot("fight_wounded")
		# the card: that squad selected
		for s in sc.squads:
			s.selected = s == w
		for m in w.md:
			m["ammo"] = 31
		_look(w.center(), w.center() + Vector2(16, 14), 9.0)
		await _shot("fight_cards", 8)
	print("FIGHT2 SHOTS DONE")
	quit()
