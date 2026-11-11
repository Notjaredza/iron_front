extends SceneTree
## Iron Front: pictures of the building round in the real game scene (needs a window or a virtual screen).
## It finds flat ground near the squads, places an HQ, barracks, depot, a wall with a tower, a sandbag line and
## wire, lets the engineers work a while, then saves:
##   build_menu.png       the build menu with its pictures, over the map
##   build_ghosts.png     a green ghost where a barracks fits, a red one where it does not, and a wire line
##   build_work.png       engineers at work on the HQ (frame and scaffold) with the other buildings around
##   build_crew.png       close in on the HQ's engineers at work
##   build_done.png       the same base later, everything finished
##   build_night.png      the finished base at night
## to results/build/.
## Run:  xvfb-run -s "-screen 0 1600x900x24" Godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##       --script res://tools/build_shots.gd [-- --seed=N]
## Ends with "BUILD SHOTS DONE".

const OUT := "res://results/build/"
var main: Node3D


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _shot(nm: String) -> void:
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + nm + ".png")
	print("saved ", nm)


func _fast(bc: BuildControl, secs: float) -> void:
	var dt := 1.0 / 30.0
	var t := 0.0
	while t < secs:
		for sq in bc.squads.squads:
			sq._step(dt)
			sq._place_men(dt)
		bc.step(dt)
		t += dt


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	while not main.ready_map:
		await process_frame
	var cam: RtsCamera = main.cam
	var bc: BuildControl = main.build
	var sc: SquadControl = main.squads
	var d: MapData = main.view.data
	cam.enabled = false
	# flat ground near the squads
	var start := sc.squads[0].at
	var c := Vector2i(-1, -1)
	for r in range(0, 60):
		for k in 64:
			var a := float(k) / 64.0 * TAU
			var cc := bc.nav.cell_of(start + Vector2(cos(a), sin(a)) * float(r) * 8.0)
			if bc.fits(cc - Vector2i(8, 8), Vector2i(17, 12), bc.men_cells()):
				c = cc
				break
		if c.x >= 0:
			break
	if c.x < 0:
		print("no flat ground found")
		quit()
		return
	var cm := (Vector2(c) + Vector2(0.5, 0.5)) * MapData.CELL
	for sq in sc.squads:
		sq.cancel_job()
	# The menu, with its pictures drawn.
	while bc.menu.pics.size() < 29:
		await process_frame
	bc.menu._show_tab(0)
	cam.target = Vector3(cm.x, 0, cm.y)
	cam.height = 110.0
	cam.yaw = 0.4
	cam.place()
	await _shot("build_menu")
	# Ghosts: a barracks that fits, one that does not (half on the HQ plot), a wire line.
	var hq := bc.place("hq", c + Vector2i(-2, -2), 0, bc.men_cells())
	bc.set_process(false)                  # the ghosts below are placed by hand, not by the mouse
	bc.start_placing("barracks")
	bc._show_ghosts(2)
	bc._ghost_at(0, c + Vector2i(3, -2), Vector2i(2, 3), 0, bc.fits(c + Vector2i(3, -2), Vector2i(2, 3)))
	bc._ghost_at(1, c + Vector2i(-1, -1), Vector2i(3, 2), 1, bc.fits(c + Vector2i(-1, -1), Vector2i(3, 2)))
	await _shot("build_ghosts_a")
	bc.stop_placing()
	bc.start_placing("wire_belt")
	var cells := BuildControl.line_cells(c + Vector2i(-6, 5), c + Vector2i(4, 5))
	bc._show_ghosts(cells.size())
	for i in cells.size():
		bc._ghost_at(i, cells[i], Vector2i.ONE, 0, bc.cell_ok(cells[i]))
	await _shot("build_ghosts")
	bc.stop_placing()
	bc.set_process(true)
	# A base: everything placed, the engineers sent.
	var placed: Array[BuildSite] = [hq]
	for p: Array in [["barracks", c + Vector2i(3, -2), 0], ["depot", c + Vector2i(-6, -2), 1], ["mg_nest", c + Vector2i(1, 3), 0]]:
		var s := bc.place(p[0], p[1], p[2], bc.men_cells())
		if s:
			placed.append(s)
	var lines: Array[BuildSite] = []
	lines.append_array(bc.place_line("wall", c + Vector2i(-7, -5), c + Vector2i(6, -5), bc.men_cells()))
	lines.append_array(bc.place_line("wall", c + Vector2i(6, -4), c + Vector2i(6, 2), bc.men_cells()))
	var tw := bc.place("tower", c + Vector2i(-8, -5), 0, bc.men_cells())
	if tw:
		lines.append(tw)
	lines.append_array(bc.place_line("sandbag_line", c + Vector2i(-4, 4), c + Vector2i(-1, 4), bc.men_cells()))
	lines.append_array(bc.place_line("wire_belt", c + Vector2i(-6, 6), c + Vector2i(5, 6), bc.men_cells()))
	sc.squads[3].jobs.append(hq)
	for s in placed.slice(1):
		sc.squads[4].jobs.append(s)
	for s in lines:
		sc.squads[4].jobs.append(s)
	# walk them over and work until the HQ is about half built
	_fast(bc, 1.0)
	var guard := 0
	while hq.progress < 0.35 and guard < 20000:
		_fast(bc, 1.0)
		guard += 1
	cam.target = Vector3(cm.x - 4, 0, cm.y - 6)
	cam.height = 34.0
	cam.yaw = 0.5
	cam.place()
	await _shot("build_work")
	var e: Squad = sc.squads[3]
	var m := e.mpos[1]
	var f := e.work_face[1] if e.work_face.size() > 1 else Vector2(0, -1)
	var y := bc.nav.height(m)
	var side := Vector2(-f.y, f.x)
	var eye := m - f * 7.0 + side * 3.0
	cam.position = Vector3(eye.x, y + 3.2, eye.y)
	cam.look_at(Vector3(m.x, y + 1.0, m.y) + Vector3(f.x, 0, f.y) * 1.5, Vector3.UP)
	await _shot("build_crew")
	cam.height = 95.0
	cam.place()
	await _shot("build_work_wide")
	# finish everything
	guard = 0
	while guard < 4000:
		var all_done := true
		for s in bc.sites:
			if not s.done:
				all_done = false
				# both sections help with whatever is left
				for sq in [sc.squads[3], sc.squads[4]]:
					if sq.job == null and sq.jobs.is_empty():
						sq.jobs.append(s)
		if all_done:
			break
		_fast(bc, 2.0)
		guard += 1
	await _shot("build_done")
	main.view.set_look(MapView.Look.NIGHT)
	await _shot("build_night")
	print("sites %d, done %d" % [bc.sites.size(), bc.sites.filter(func(s: BuildSite) -> bool: return s.done).size()])
	print("BUILD SHOTS DONE")
	quit()
