extends SceneTree
## Iron Front: pictures of the fighting round in the real game scene (needs a window or a virtual screen).
## Fast-forwards each fight with the clock stepped by hand, then lets a few real frames run and saves:
##   fight_redcoats_volley.png   red coats halted, firing a volley at a rifle squad
##   fight_redcoats_charge.png   the bayonet charge reaching the rifles
##   fight_zombies.png           a zombie horde closing on a rifle squad
##   fight_host.png              the medieval foot running in, the archers shooting behind them
##   fight_mg.png                a manned MG nest firing tracers into a horde
##   fight_pinned.png            a rifle squad pinned flat under fire
## to results/fight/.
## Run:  xvfb-run -s "-screen 0 1600x900x24" Godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##       --script res://tools/fight_shots.gd
## Ends with "FIGHT SHOTS DONE".

const OUT := "res://results/fight/"
const DT := 1.0 / 30.0
var main: Node3D
var cc: CombatControl
var sc: SquadControl
var cam: RtsCamera


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _hold(on: bool) -> void:
	for s in sc.squads + cc.enemies:
		s.set_process(not on)
	cc.set_process(not on)


func _fast(secs: float, done: Callable = Callable()) -> void:
	_hold(true)
	var t := 0.0
	while t < secs:
		for s in sc.squads + cc.enemies:
			s._step(DT)
			s._place_men(DT)
		cc.step(DT)
		for s in sc.squads + cc.enemies:
			for ap in s.players:
				ap.advance(DT)
		t += DT
		if done.is_valid() and done.call():
			break
	_hold(false)


func _look(at: Vector2, from: Vector2, h: float) -> void:
	var y: float = main.nav.height(at)
	var y0: float = maxf(y, main.nav.height(from))
	cam.position = Vector3(from.x, y0 + h, from.y)
	cam.look_at(Vector3(at.x, y + 1.0, at.y), Vector3.UP)


func _shot(nm: String, frames := 6) -> void:
	for k in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + nm + ".png")
	print("saved ", nm)


func _clear() -> void:
	for s in cc.enemies:
		s.queue_free()
	cc.enemies.clear()
	for b in cc.corpses.get_children():
		b.queue_free()
	cc._dead.clear()
	cc._pending.clear()


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
	var home := r.at
	# 1-2. Red coats: the volley, then the charge.
	for s in sc.squads.slice(1):
		s.order_move(home + Vector2(0, 160))     # only one rifle squad faces each wave
	_fast(70.0)
	var reds := cc.spawn("redcoats", home, 150.0)
	var red: Squad = reds[0]
	_fast(120.0, func() -> bool: return not is_instance_valid(red) or (red.mode == "halt" and not red.moving() and red.acting(5)))
	_fast(0.3)
	if is_instance_valid(red):
		var rc: Vector2 = red.center()
		var side := Vector2(-(rc - home).normalized().y, (rc - home).normalized().x)
		_look(rc + (home - rc).normalized() * 6.0, rc + side * 14.0 + (rc - home).normalized() * 4.0, 3.0)
		await _shot("fight_redcoats_volley")
	_fast(60.0, func() -> bool:
		for e in cc.enemies:
			if e.melee_on:
				return true
		return cc.enemies.is_empty())
	_fast(1.2)
	_look(r.center(), r.center() + Vector2(12, 8), 4.0)
	await _shot("fight_redcoats_charge")
	_clear()
	# 3. Zombies.
	for s in sc.squads:
		s.supp = 0.0
	var zs := cc.spawn("zombies", home, 90.0)
	_fast(60.0, func() -> bool:
		for s in cc.enemies:
			for p in s.mpos:
				if p.distance_to(home) < 25.0:
					return true
		return false)
	_look(home + Vector2(0, -14), home + Vector2(14, 8), 4.5)
	await _shot("fight_zombies")
	_clear()
	# 4. The host.
	var host := cc.spawn("medieval", home, 180.0)
	var foot: Squad = host[0]
	_fast(120.0, func() -> bool: return not is_instance_valid(foot) or (foot.center().distance_to(home) < 45.0 and foot.running))
	var hc: Vector2 = foot.center() if is_instance_valid(foot) else home + Vector2(0, -40)
	_look(hc + (home - hc) * 0.3, hc + Vector2(-16, -6), 4.0)
	await _shot("fight_host")
	_clear()
	# 5. A manned MG nest.
	var cell: Vector2i = main.nav.cell_of(home + Vector2(0, -30))
	var nest: BuildSite = null
	for k in 40:
		nest = bc.place("mg_nest", cell + Vector2i(k % 7 - 3, -(k / 7)), 0, bc.men_cells())
		if nest:
			break
	if nest:
		bc._finish(nest)
		cc.man_post(sc.squads[1], nest)
		_fast(60.0, func() -> bool: return sc.squads[1].in_post)
		cc.spawn("zombies", nest.center(), 150.0)
		_fast(12.0)
		var nc := nest.center()
		_look(nc + Vector2(0, -40), nc + Vector2(6, 10), 3.5)
		await _shot("fight_mg", 2)
		_clear()
	# 6. Pinned.
	var p: Squad = sc.squads[2]
	p.supp = 1.8
	_fast(0.5)
	_fast(1.5)
	_look(p.center(), p.center() + Vector2(7, 6), 3.0)
	await _shot("fight_pinned")
	print("FIGHT SHOTS DONE")
	quit()
