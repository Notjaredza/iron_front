extends SceneTree
## Iron Front trains: stills for the user's look (Asset Builder Chat).
## Run with a window (pictures need the GPU):
##   Godot --path iron_front --resolution 1600x900 -s res://tools/train_pictures.gd [-- --only=name]
## Writes results/trains/: engine_side.png, engine_three_quarter.png, engine_front.png, engine_rods.png,
## tender.png, van.png, van_doors.png, gunflat.png, train_5.png, train_far.png, train_night.png

const OUT := "res://results/trains/"

var cam: Camera3D
var stage: Node3D
var sun: DirectionalLight3D
var env: Environment
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_world()
	for k: String in ["engine", "tender", "van", "gunflat"]:
		var c := TrainParts.make(k)
		print("TRAIN TRIS %s near=%d far=%d" % [k, c.tri_count(true), c.tri_count(false)])
		c.free()
	var shots := ["engine_side", "engine_three_quarter", "engine_front", "engine_rods", "tender", "van", "van_doors",
		"gunflat", "train_5", "train_far", "train_night"]
	for s: String in shots:
		if only != "" and not s.begins_with(only):
			continue
		await _shot(s)
	print("TRAIN PICTURES DONE")
	quit()


func _world() -> void:
	env = Environment.new()
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
	env.ssao_radius = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
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


func _clear() -> void:
	if stage:
		stage.free()
	stage = Node3D.new()
	root.add_child(stage)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	env.ambient_light_energy = 0.9
	env.background_energy_multiplier = 1.0


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


func _track(len_m: float) -> TrackPath:
	var p := TrackPath.line(Vector3(0, 0, len_m * 0.5), Vector3(0, 0, -len_m * 0.5))
	stage.add_child(TrainParts.track(p, 0.0, len_m))
	return p


func _car(kind: String, z: float) -> TrainCar:
	var c := TrainParts.make(kind)
	stage.add_child(c)
	c.position = Vector3(0, 0, z)
	return c


func _train(kinds: Array, path: TrackPath, front_d: float) -> Array[TrainCar]:
	var out: Array[TrainCar] = []
	var d := front_d
	for k: String in kinds:
		var c := TrainParts.make(k)
		stage.add_child(c)
		var dc := d + c.front_z          # car centre: its front face is at d
		c.transform = path.car_frame(dc, c)
		d = dc - c.rear_z                # the next car's front face meets this car's back
		out.append(c)
	return out


func _shot(nm: String) -> void:
	_clear()
	match nm:
		"engine_side":
			_track(40)
			_car("engine", 0)
			_look(Vector3(16, 2.2, 0), Vector3(0, 1.9, 0), 40)
		"engine_three_quarter":
			_track(40)
			var e := _car("engine", 0)
			e.roll(0.4)
			_look(Vector3(11, 4.5, -11), Vector3(0, 1.8, -0.5), 40)
		"engine_front":
			_track(40)
			_car("engine", 0)
			_look(Vector3(-2.5, 2.5, -13), Vector3(0, 2.0, 0), 40)
		"engine_rods":
			_track(40)
			var e := _car("engine", 0)
			e.roll(0.8)
			_look(Vector3(5.5, 1.3, -2.0), Vector3(0.9, 0.8, -1.5), 50)
		"tender":
			_track(40)
			_car("tender", 0)
			_look(Vector3(8, 4.0, -7), Vector3(0, 1.6, 0), 40)
		"van":
			_track(40)
			_car("van", 0)
			_look(Vector3(8, 3.5, -7), Vector3(0, 1.8, 0), 40)
		"van_doors":
			_track(40)
			var v := _car("van", 0)
			v.set_doors(1.0)
			_look(Vector3(8, 2.8, 4), Vector3(0, 1.8, -0.5), 40)
		"gunflat":
			_track(40)
			var g := _car("gunflat", 0)
			g.aim(0.6, 0.25)
			_look(Vector3(8, 5.5, -7), Vector3(0, 1.6, 0), 40)
		"train_5":
			var p := _track(80)
			_train(["engine", "tender", "van", "gunflat", "van"], p, 55.0)
			_look(Vector3(20, 9, -22), Vector3(0, 1.5, 4), 45)
		"train_far":
			var p := _track(600)
			_train(["engine", "tender", "van", "gunflat", "van"], p, 290.0)
			_look(Vector3(250, 260, -150), Vector3(0, 0, 0), 30)
		"train_night":
			var p := _track(80)
			_train(["engine", "tender", "van", "gunflat", "van"], p, 55.0)
			sun.light_energy = 0.35
			sun.light_color = Color(0.6, 0.7, 1.0)
			env.ambient_light_energy = 0.35
			env.background_energy_multiplier = 0.25
			_look(Vector3(14, 6, -20), Vector3(0, 1.5, 0), 45)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + nm + ".png"))
	print("TRAIN PICTURE ", nm)
