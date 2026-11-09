extends SceneTree
## Explosion round B: blasts and craters on the real Iron Front map (window run).
##   Godot --path . --resolution 1280x720 -s res://tools/map_blast_clips.gd [-- day|night|still]
## Finds a flat field, then steps the clock frame by frame: a medium shell, a barrage walking across, an anti-tank mine,
## a size 6 behind, (at night a light flare first). JPEG frames in results/fx/frames/map_<look>/ at 30 fps, and a
## close still of the craters left behind: results/fx/map_craters_<look>.png.

const OUT := "res://results/fx/"
const FPS := 30.0

var main: Node3D


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	while not main.ready_map:
		await process_frame
	var args := OS.get_cmdline_user_args()
	var looks: Array = []
	for a in args:
		if a in ["day", "night"]:
			looks.append(a)
	if looks.is_empty():
		looks = ["day", "night"]
	for look in looks:
		await _clip(look, not args.has("still"))
	print("MAP BLAST CLIPS OK")
	quit()


## The flattest open spot near the middle: a 160 m square all on one level.
func _flat_spot(d: MapData) -> Vector3:
	var sz := d.size_m()
	var best := Vector3(sz.x * 0.5, 0, sz.y * 0.5)
	var best_s := 1e9
	for i in 400:
		var x := sz.x * (0.2 + 0.6 * float(i % 20) / 19.0)
		var z := sz.y * (0.2 + 0.6 * float(i / 20) / 19.0)
		var y0 := d.ground_y(Vector2(x, z))
		if y0 <= MapData.WATER_Y + 0.01:
			continue
		var bad := 0.0
		for gx in range(-4, 5):
			for gz in range(-4, 5):
				bad += absf(d.ground_y(Vector2(x + gx * 20.0, z + gz * 20.0)) - y0)
		var dc := Vector2(x - sz.x * 0.5, z - sz.y * 0.5).length() * 0.001
		if bad + dc < best_s:
			best_s = bad + dc
			best = Vector3(x, y0, z)
	return best


func _clip(look: String, video: bool) -> void:
	var view: MapView = main.view
	var cam: RtsCamera = main.cam
	var mb: MapBlasts = main.blasts
	mb.auto_craters = false
	main.hud.visible = false
	mb.craters.clear()
	view.set_look(MapView.Look.DAY if look == "day" else MapView.Look.NIGHT)
	Blast.set_night(look != "day")
	var c := _flat_spot(view.data)
	cam.enabled = false
	cam.target = c + Vector3(0, 0, -10)
	cam.yaw = 0.0
	cam.height = 72.0
	cam.height_goal = 72.0
	for i in 3:
		cam.place()
		view.follow(cam.height)
		await process_frame
	# [time, what, offset across (x) and away (z, + = away from the camera)]
	var ev: Array = [[0.0, 4, Vector2(0, 20)]]
	if look == "night":
		ev = [[0.0, "flare_light", Vector2(-30, 10)], [2.5, 4, Vector2(0, 20)]]
	var t0: float = ev[ev.size() - 1][0] + 1.2
	for i in 12:
		ev.append([t0 + float(i) * 0.33, [1, 2, 3, 2][i % 4], Vector2(-50 + i * 8.5, 5 + (i % 3) * 14)])
	ev.append([t0 + 4.6, "mine_at", Vector2(28, 0)])
	ev.append([t0 + 6.2, 6, Vector2(-25, 75)])
	var length := t0 + 13.0
	var live: Array = []                 # [Blast, start, crater done]
	var dir := ProjectSettings.globalize_path(OUT + "frames/map_%s/" % look)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	var frames := int(length * FPS)
	var vs := root.get_visible_rect().size
	var fwd := Vector3(sin(cam.yaw), 0, cos(cam.yaw))
	var right := Vector3(-cos(cam.yaw), 0, sin(cam.yaw))
	for fi in frames:
		var t := float(fi) / FPS
		while not ev.is_empty() and float(ev[0][0]) <= t:
			var e: Array = ev.pop_front()
			var off: Vector2 = e[2]
			var p := c + right * off.x + fwd * off.y
			var b := mb.fire(e[1], p.x, p.z, 900 + fi)
			b.auto = false
			live.append([b, float(e[0]), false])
		for l: Array in live:
			var b: Blast = l[0]
			if not is_instance_valid(b):
				continue
			b.set_time(t - float(l[1]))
			if not l[2] and b.t >= float(b.spec.get("crater_t", 0.05)) and float(b.spec["crater_r"]) > 0.0:
				l[2] = true
				mb.try_crater(b.origin, b.spec["crater_r"], b.spec["crater_d"], int(b.origin.x * 7.0 + b.origin.z))
		cam.place()
		view.follow(cam.height)
		await process_frame
		await RenderingServer.frame_post_draw
		if video:
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_jpg(dir + "f%04d.jpg" % fi, 0.9)
	print("frames map_%s %d, craters %d" % [look, frames if video else 0, mb.craters.count()])
	# The field afterwards, close: the craters that stay.
	for l: Array in live:
		if is_instance_valid(l[0]):
			(l[0] as Blast).queue_free()
	cam.target = c + fwd * 14.0
	cam.height = 48.0
	for i in 4:
		cam.place()
		view.follow(cam.height)
		await process_frame
	await RenderingServer.frame_post_draw
	var still := root.get_texture().get_image()
	still.save_png(ProjectSettings.globalize_path(OUT + "map_craters_%s.png" % look))
