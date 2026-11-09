extends SceneTree
## Iron Front: the fly-over frame test (window, quiet laptop). The camera pans across the map at the WW1 pan speed
## (10 + height x 0.8 m/s) while turning slowly, for 12 s at each of four heights. For each height it prints:
## - the average frame rate;
## - the worst whole second;
## - the longest frame;
## - draw calls;
## - triangles.
## Run:  Godot --path . --resolution 1600x900 --script res://tools/fly_run.gd [-- --seed=N --look=day|night|fog]
## Ends with "FLY RUN DONE".

var main: Node3D


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	while not main.ready_map:
		await process_frame
	var cam: RtsCamera = main.cam
	var view: MapView = main.view
	for a in OS.get_cmdline_user_args():
		if a == "--look=night":
			view.set_look(MapView.Look.NIGHT)
		elif a == "--look=fog":
			view.set_look(MapView.Look.FOG)
	cam.enabled = false
	var sz := view.data.size_m()
	for h: float in [30.0, 120.0, 400.0, 1000.0, 2500.0]:
		cam.height = h
		cam.yaw = 0.0
		cam.target = Vector3(sz.x * 0.2, 0, sz.y * 0.15)
		var dir := Vector3(0.45, 0, 1).normalized()
		for f in 30:
			cam.place()
			view.follow(h)
			await process_frame
		var t0 := Time.get_ticks_usec()
		var last := t0
		var sec_start := t0
		var sec_frames := 0
		var worst_sec := INF
		var longest := 0.0
		var frames := 0
		var draws := 0.0
		var prims := 0.0
		while Time.get_ticks_usec() - t0 < 12000000:
			var now := Time.get_ticks_usec()
			var dt := (now - last) / 1000000.0
			cam.target += dir * (10.0 + h * 0.8) * dt
			if cam.target.z > sz.y * 0.9 or cam.target.x > sz.x * 0.9:
				dir = -dir
			cam.yaw += dt * 0.15
			cam.place()
			view.follow(h)
			await process_frame
			now = Time.get_ticks_usec()
			longest = maxf(longest, (now - last) / 1000.0)
			last = now
			frames += 1
			sec_frames += 1
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			if now - sec_start >= 1000000:
				worst_sec = minf(worst_sec, sec_frames * 1000000.0 / (now - sec_start))
				sec_start = now
				sec_frames = 0
		print("FLY height %5d m  %s  fps %5.1f  worst second %5.1f  longest frame %5.1f ms  draws %4d  triangles %7d" % [
			int(h), view.look_name(), frames / 12.0, worst_sec, longest, int(draws / frames), int(prims / frames)])
	print("FLY RUN DONE")
	quit()
