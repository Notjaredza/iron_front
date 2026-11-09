extends SceneTree
## Iron Front trains: videos for the user's look (Asset Builder Chat).
## Run with a window at a fixed 30 fps so every frame is one 30th of a second of game time:
##   Godot --path iron_front --resolution 1280x720 --fixed-fps 30 -s res://tools/train_videos.gd -- <clips>
## Clips: run, couplers, doors_gun, crashes (all 12 crash clips) or one crash such as tip_5.
## Frames go to results/trains/frames/<clip>/ as JPEG; ffmpeg makes results/trains/<clip>.mp4.

const OUT := "res://results/trains/"
const FPS := 30.0

var cam: Camera3D
var stage: Node3D
var label: Label
var clips: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "crashes":
			for k: String in TrainCrashes.KINDS:
				for n in [3, 4, 5]:
					clips.append("%s_%d" % [k, n])
		else:
			clips.append(a)
	_run.call_deferred()


func _run() -> void:
	_world()
	for c in clips:
		await _clip(c)
	print("TRAIN VIDEOS DONE")
	quit()


func _world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.55, 0.88)
	sm.sky_horizon_color = Color(0.74, 0.84, 0.93)
	sm.ground_bottom_color = Color(0.35, 0.33, 0.28)
	sm.ground_horizon_color = Color(0.74, 0.82, 0.88)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.62, 0.30)
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	ground.position.y = -0.6
	root.add_child(ground)
	cam = Camera3D.new()
	cam.far = 3000.0
	root.add_child(cam)
	cam.current = true
	var ui := CanvasLayer.new()
	root.add_child(ui)
	label = Label.new()
	label.position = Vector2(20, 14)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	ui.add_child(label)


func _look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.fov = fov
	cam.global_transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


## Records a clip: step(t) is called every frame before the picture is taken; the clip lasts secs.
func _record(nm: String, secs: float, step: Callable) -> void:
	var dir := ProjectSettings.globalize_path(OUT + "frames/" + nm + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(ProjectSettings.globalize_path(OUT + "frames/.gdignore"), FileAccess.WRITE).store_string("")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	var frames := int(secs * FPS)
	for i in frames:
		step.call(float(i) / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(dir + "%05d.jpg" % i, 0.9)
	var mp4 := ProjectSettings.globalize_path(OUT + nm + ".mp4")
	var out := []
	var code := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", "30", "-i", dir + "%05d.jpg",
		"-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", mp4], out, true)
	print("TRAIN VIDEO %s frames=%d ffmpeg=%d" % [nm, frames, code])


func _new_stage() -> void:
	if stage:
		stage.free()
	stage = Node3D.new()
	root.add_child(stage)


func _clip(nm: String) -> void:
	_new_stage()
	match nm:
		"run":
			await _run_clip()
		"couplers":
			await _couplers_clip()
		"doors_gun":
			await _doors_gun_clip()
		_:
			await _crash_clip(nm)


# ------------------------------------------------------------------ running

func _run_clip() -> void:
	var path := TrackPath.line(Vector3(0, 0, 60), Vector3(0, 0, -900))
	stage.add_child(TrainParts.track(path, 0.0, 960.0))
	var t := Train.make(["engine", "tender", "van", "gunflat", "van"], path, 80.0)
	stage.add_child(t)
	await _record("run", 30.0, func(s: float) -> void:
		if s < 3.0:
			label.text = "Standing, whistle"
			t.target_speed = 0.0
			if s > 1.0 and s < 1.05:
				t.whistle(1.2)
		elif s < 17.0:
			label.text = "Pulling away, up to 15 m/s (54 km/h)   %.1f m/s" % t.speed()
			t.target_speed = 15.0
		else:
			label.text = "Braking to a stop   %.1f m/s" % t.speed()
			t.target_speed = 0.0
		var ep := t.cars[0].global_position
		# a chase camera that swings from the front three-quarter to alongside as the train gets going
		var u := clampf((s - 4.0) / 6.0, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		var off := Vector3(10, 3.2, -9.0).lerp(Vector3(14, 4.5, 2.0), u)
		_look(Vector3(off.x, off.y, ep.z + off.z), Vector3(0, 1.8, ep.z + lerpf(3.0, 8.0, u)), 45)
	)
	t.queue_free()


func _couplers_clip() -> void:
	var path := TrackPath.line(Vector3(0, 0, 60), Vector3(0, 0, -900))
	stage.add_child(TrainParts.track(path, 0.0, 960.0))
	var t := Train.make(["engine", "tender", "van", "gunflat", "van"], path, 80.0)
	stage.add_child(t)
	t.max_force = 120000.0
	await _record("couplers", 16.0, func(s: float) -> void:
		if s < 1.0:
			t.target_speed = 0.0
			label.text = "Couplings slack, buffers touching"
		elif s < 7.0:
			t.target_speed = 3.0
			label.text = "Starting: the slack runs out car by car   gaps %s" % _gaps(t)
		else:
			t.target_speed = 0.0
			t.brake_decel = 2.2
			label.text = "Hard stop: buffers squash, the train bunches up   gaps %s" % _gaps(t)
		var c := t.cars[2].global_position
		_look(Vector3(5.5, 2.0, c.z + 1.0), Vector3(0, 1.1, c.z - 3.6), 50)
	)
	t.queue_free()


func _gaps(t: Train) -> String:
	var s := ""
	for i in range(1, t.cars.size()):
		s += "%+.2f " % t._gap(i)
	return s


func _doors_gun_clip() -> void:
	var path := TrackPath.line(Vector3(0, 0, 40), Vector3(0, 0, -100))
	stage.add_child(TrainParts.track(path, 0.0, 140.0))
	var t := Train.make(["engine", "tender", "van", "gunflat", "van"], path, 40.0)
	stage.add_child(t)
	var van := t.cars[2]
	var gun := t.cars[3]
	await _record("doors_gun", 14.0, func(s: float) -> void:
		if s < 5.0:
			label.text = "Van doors: open, shut"
			var u := clampf((s - 0.5) / 1.6, 0.0, 1.0) if s < 3.0 else 1.0 - clampf((s - 3.2) / 1.6, 0.0, 1.0)
			van.set_doors(u)
			var vp := van.global_position
			_look(vp + Vector3(8.5, 2.6, 3.5), vp + Vector3(0, 1.9, -0.6), 45)
		else:
			label.text = "Gun: turn, lift, fire twice"
			var g := s - 5.0
			var yaw := -1.1 * clampf(g / 2.0, 0.0, 1.0)
			var pitch := 0.3 * clampf((g - 1.5) / 1.2, 0.0, 1.0)
			gun.aim(yaw, pitch)
			gun.recoil(g - 3.2 if g < 6.0 else g - 6.0)
			if absf(g - 3.2) < 0.02 or absf(g - 6.0) < 0.02:
				var muzzle := gun.gun_barrel.to_global(Vector3(0, 0.04, -2.9))
				for k in 10:
					t.smoke.add("smoke", muzzle, gun.gun_barrel.global_basis.z * -9.0 + t.smoke.jitter(2.0), 0.7)
				for k in 5:
					t.fire.add("flame", muzzle, gun.gun_barrel.global_basis.z * -6.0 + t.fire.jitter(1.0), 1.5)
			var gp := gun.global_position
			_look(gp + Vector3(-9.5, 5.0, 6.5), gp + Vector3(-1.0, 1.8, -0.8), 45)
	)
	t.queue_free()


# ------------------------------------------------------------------ crashes

func _crash_clip(nm: String) -> void:
	var parts := nm.split("_")
	var kind := parts[0]
	var n := int(parts[1])
	var lib := TrainCrashes.library()
	var t := TrainCrashes.stage_for(kind, n, stage)
	var clip_len := lib.get_animation(nm).length
	t.player.add_animation_library("", lib)
	t.crash(nm)
	var titles := {"tip": "Tips over on a curve", "track": "Track torn up ahead", "block": "Hits a tank-trap block",
		"blast": "Boiler hit: blown apart"}
	var e := t.cars[0]
	await _record(nm, clip_len + 3.0, func(s: float) -> void:
		label.text = "%s   (%d cars, 18 m/s)" % [titles[kind], n]
		var focus := Vector3(0, 1.5, 8.0)
		var from := Vector3(24, 9, 28)
		match kind:
			"tip":
				from = Vector3(-22, 9, -4)
				focus = Vector3(0, 1.0, -14)
			"track":
				from = Vector3(22, 8, 14)
				focus = Vector3(0, 0.5, 2)
			"block":
				from = Vector3(26, 10, 26)
				focus = Vector3(0, 1.2, 13)
			"blast":
				from = Vector3(28, 12, 22)
				focus = Vector3(0, 2.0, 4)
		if s < 1.0:
			focus = focus.lerp(e.global_position + Vector3(0, 1.5, 0), 0.4)
		_look(from, focus, 50)
	)
	t.queue_free()
