extends SceneTree
## Iron Front air: stills for the user's look (Asset Builder Chat).
## Run with a window (pictures need the GPU):
##   Godot --path iron_front --resolution 1600x900 -s res://tools/air_pictures.gd [-- --only=name]
## Writes results/air/*.png

const OUT := "res://results/air/"

var cam: Camera3D
var stage: Node3D
var sun: DirectionalLight3D
var env: Environment
var ground: MeshInstance3D
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_world()
	for k: String in ["fighter", "spotter", "bomber"]:
		var a := AirParts.make(k)
		print("AIR TRIS %s near=%d far=%d" % [k, a.tri_count(true), a.tri_count(false)])
		a.free()
	var shots := ["fighter_three_quarter", "fighter_side", "fighter_top", "fighter_front", "spotter_three_quarter", "spotter_gunner",
		"bomber_three_quarter", "bomber_side", "bomber_under", "bomber_gunners", "planes_flying", "planes_ground",
		"planes_far", "planes_night", "balloon", "balloon_basket", "winch_lorry", "balloon_far", "balloon_night"]
	for s: String in shots:
		if only != "" and not s.begins_with(only):
			continue
		await _shot(s)
	print("AIR PICTURES DONE")
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
	sun.directional_shadow_max_distance = 200.0
	root.add_child(sun)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.62, 0.30)
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	root.add_child(ground)
	cam = Camera3D.new()
	cam.far = 5000.0
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
	ground.visible = true


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


func _plane(k: String, at: Vector3, heading := 0.0, climb := 0.0, bank := 0.0, rpm := 0.0) -> Aircraft:
	var a := AirParts.make(k)
	stage.add_child(a)
	a.fly_pose(at, heading, climb, bank)
	a.rpm = rpm
	a.spin(0.013)
	return a


func _on_ground(k: String, at: Vector3, heading := 0.0) -> Aircraft:
	var a := AirParts.make(k)
	stage.add_child(a)
	a.ground_pose(at, 0.0, heading, 0.0)
	return a


func _balloon(at: Vector3, h: float) -> Balloon:
	var b := Balloon.make()
	stage.add_child(b)
	b.position = at
	b.rotation.y = 0.5
	b.wind(1.3)
	b.set_height(h)
	return b


func _night() -> void:
	sun.light_energy = 0.3
	sun.light_color = Color(0.6, 0.7, 1.0)
	env.ambient_light_energy = 0.3
	env.background_energy_multiplier = 0.22


func _shot(nm: String) -> void:
	_clear()
	match nm:
		"fighter_three_quarter":
			_on_ground("fighter", Vector3.ZERO, 0.0)
			_look(Vector3(7, 3.0, -7), Vector3(0, 0.0, 0), 40)
		"fighter_side":
			_on_ground("fighter", Vector3.ZERO, 0.0)
			_look(Vector3(13, 0.6, 0), Vector3(0, 0.0, 0), 40)
		"fighter_top":
			var a := _plane("fighter", Vector3(0, 30, 0), 0.0, 0.0, 0.0, 0.0)
			a.set_surfaces(1.0, 0.6, 0.5)
			_look(Vector3(0, 44, 0.01), Vector3(0, 30, 0), 40)
		"fighter_front":
			_on_ground("fighter", Vector3.ZERO, 0.0)
			_look(Vector3(-2, 1.0, -10), Vector3(0, 0.3, 0), 45)
		"spotter_three_quarter":
			_on_ground("spotter", Vector3.ZERO, 0.0)
			_look(Vector3(9, 3.5, -9), Vector3(0, 0.0, 0), 40)
		"spotter_gunner":
			var a := _on_ground("spotter", Vector3.ZERO, 0.0)
			a.aim_gunner(0, 2.3, 0.4)
			_look(Vector3(3.5, 3.2, 4.0), Vector3(0, 1.0, 0.5), 45)
		"bomber_three_quarter":
			_on_ground("bomber", Vector3.ZERO, 0.0)
			_look(Vector3(17, 6, -17), Vector3(0, 0.5, 0), 40)
		"bomber_side":
			_on_ground("bomber", Vector3.ZERO, 0.0)
			_look(Vector3(26, 1.5, 0), Vector3(0, 0.5, 0), 40)
		"bomber_under":
			var a := _plane("bomber", Vector3(0, 30, 0))
			_look(Vector3(8, 14, 12), Vector3(0, 30, 0), 45)
		"bomber_gunners":
			var a := _on_ground("bomber", Vector3.ZERO, 0.0)
			a.aim_gunner(0, 0.5, 0.3)
			a.aim_gunner(1, 2.6, 0.5)
			_look(Vector3(10, 7.5, -4), Vector3(0, 1.5, -1), 45)
		"planes_flying":
			_plane("bomber", Vector3(0, 60, 0), 0.0, 0.0, 0.0, 1400.0)
			_plane("fighter", Vector3(-18, 66, 12), 0.25, 0.08, -0.6, 1400.0)
			_plane("spotter", Vector3(20, 56, 18), -0.15, 0.0, 0.35, 1400.0)
			_look(Vector3(40, 72, -45), Vector3(0, 60, 8), 42)
		"planes_ground":
			_on_ground("bomber", Vector3(0, 0, 0), 0.3)
			_on_ground("spotter", Vector3(-20, 0, -4), 0.3)
			_on_ground("fighter", Vector3(-34, 0, -8), 0.3)
			_look(Vector3(18, 8, -30), Vector3(-12, 0, 0), 45)
		"balloon":
			var b := _balloon(Vector3.ZERO, 35.0)
			_look(Vector3(38, 22, -42), Vector3(0, 26, 4), 50)
		"balloon_basket":
			var b := _balloon(Vector3.ZERO, 30.0)
			var kp := b.kite.global_position
			_look(kp + Vector3(4.5, 2.5, -5.5), kp + Vector3(0, 2.0, 0), 50)
		"winch_lorry":
			var b := _balloon(Vector3.ZERO, 30.0)
			_look(Vector3(7, 4.5, -8), Vector3(0, 1.6, 0.8), 45)
		"balloon_far":
			_balloon(Vector3.ZERO, 300.0)
			_look(Vector3(700, 450, -700), Vector3(0, 250, 0), 20)
		"balloon_night":
			_night()
			_balloon(Vector3.ZERO, 35.0)
			_look(Vector3(38, 22, -42), Vector3(0, 26, 4), 50)
		"planes_far":
			_plane("bomber", Vector3(0, 300, 0), 0.0, 0.0, 0.0, 1400.0)
			_plane("fighter", Vector3(-40, 310, 30), 0.3, 0.0, -0.5, 1400.0)
			_plane("spotter", Vector3(50, 290, 30), 0.0, 0.0, 0.3, 1400.0)
			_look(Vector3(400, 600, -300), Vector3(0, 300, 0), 15)
		"planes_night":
			_night()
			_plane("bomber", Vector3(0, 60, 0), 0.0, 0.0, 0.0, 1400.0)
			_plane("fighter", Vector3(-18, 66, 12), 0.25, 0.08, -0.6, 1400.0)
			_look(Vector3(40, 72, -45), Vector3(0, 60, 8), 42)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + nm + ".png"))
	print("AIR PICTURE ", nm)
