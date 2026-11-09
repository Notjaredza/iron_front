extends SceneTree
## Iron Front: frame-rate run of the map test (window, quiet laptop). For each camera height it holds 3 s and
## prints the average and worst frame rate, draw calls, triangles and GPU time, with shadows on and then off.
## Run:  Godot --path . --resolution 1600x900 --script res://tools/fps_run.gd [-- --seed=N]
## Ends with "FPS RUN DONE".

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
	cam.enabled = false
	var rid := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var sz := view.data.size_m()
	for h: float in [60.0, 160.0, 400.0, 900.0, 1600.0, 4000.0]:
		for shadows in [true, false]:
			cam.target = Vector3(sz.x * 0.5, 0, sz.y * 0.5)
			cam.height = h
			cam.yaw = 0.3
			var frames := 0
			var worst := 0.0
			var gpu := 0.0
			var draws := 0.0
			var prims := 0.0
			var t0 := Time.get_ticks_usec()
			var last := t0
			while Time.get_ticks_usec() - t0 < 3000000:
				cam.target.z += 0.6 * h * 0.016           # drift, so new chunks come into view
				cam.place()
				view.follow(h)
				if not shadows:
					view.sun.shadow_enabled = false
				await process_frame
				var now := Time.get_ticks_usec()
				if Time.get_ticks_usec() - t0 > 500000:   # skip the first half second
					frames += 1
					worst = maxf(worst, (now - last) / 1000.0)
					gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
					draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
					prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
				last = now
			print("FPS height %5d m  shadows %-5s  fps %5.1f  worst frame %5.1f ms  GPU %5.1f ms  draws %5d  triangles %8d" % [
				int(h), str(shadows), frames / 2.5, worst, gpu / maxf(1, frames), int(draws / maxf(1, frames)), int(prims / maxf(1, frames))])
	print("FPS RUN DONE")
	quit()
