extends SceneTree
## Renders the rifleman pictures for the user's look (Question Chat, 2026-11-09).
## Run with a window (pictures need the GPU):
##   Godot --path iron_front --resolution 1600x900 -s res://tools/unit_pictures.gd
## Writes results/units/: rifleman_turntable.png, rifleman_poses.png,
## rifleman_squad.png, rifleman_lods.png, rifleman_closeup.png

const OUT := "res://results/units/"
const W := 1600
const H := 900

var stage: Node3D
var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_setup_world()
	var counts: Array[int] = []
	for l in 3:
		var s := Soldier.new().setup(1, l)
		counts.append(s.tri_count())
		s.free()
	print("UNIT TRIS lod0=%d lod1=%d lod2=%d" % [counts[0], counts[1], counts[2]])
	await _turntable()
	await _poses()
	await _squad()
	await _lods()
	await _closeup()
	print("UNIT PICTURES OK")
	quit()


func _setup_world() -> void:
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
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.70, 0.62, 0.46)
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	root.add_child(ground)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	stage = Node3D.new()
	root.add_child(stage)


func _clear() -> void:
	for c in stage.get_children():
		c.free()


func _man(seed_value: int, lod: int, pose: String, at: Vector3, yaw_deg: float) -> Soldier:
	var s := Soldier.new().setup(seed_value, lod)
	s.position = at
	s.rotation.y = deg_to_rad(yaw_deg)
	stage.add_child(s)
	s.set_pose(pose)
	return s


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


func _shot() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _sheet(parts: Array[Image], cols: int) -> Image:
	var pw := parts[0].get_width()
	var ph := parts[0].get_height()
	var rows := int(ceil(float(parts.size()) / float(cols)))
	var out := Image.create(pw * cols, ph * rows, false, Image.FORMAT_RGBA8)
	for i in parts.size():
		out.blit_rect(parts[i], Rect2i(0, 0, pw, ph), Vector2i((i % cols) * pw, (i / cols) * ph))
	return out


func _save(img: Image, file: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + file))
	print("saved ", file)


## Eight views, 45 degrees apart, starting from the front.
func _turntable() -> void:
	var parts: Array[Image] = []
	for i in 8:
		_clear()
		_man(1, 0, "stand", Vector3.ZERO, 180.0 + 45.0 * i)
		_look(Vector3(0, 1.0, 5.2), Vector3(0, 0.95, 0), 28.0)
		var img: Image = await _shot()
		parts.append(img.get_region(Rect2i(W / 2 - 260, 0, 520, H)))
	_save(_sheet(parts, 4), "rifleman_turntable.png")


func _poses() -> void:
	var parts: Array[Image] = []
	for p in Soldier.POSE_NAMES:
		_clear()
		_man(1, 0, p, Vector3.ZERO, 180.0 - 55.0)
		if p == "prone":
			_look(Vector3(0, 1.7, 4.6), Vector3(0, 0.25, 0), 30.0)
		else:
			_look(Vector3(0, 1.1, 5.4), Vector3(0, 0.85, 0), 28.0)
		var img: Image = await _shot()
		parts.append(img.get_region(Rect2i(W / 2 - 320, 0, 640, H)))
	_save(_sheet(parts, 5), "rifleman_poses.png")


func _squad() -> void:
	_clear()
	var poses: Array[String] = ["stand", "run", "run", "kneel", "aim", "stand", "run", "prone", "kneel", "aim", "prone", "stand"]
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for i in 12:
		var at := Vector3((i % 4) * 1.7 - 2.55 + r.randf_range(-0.3, 0.3), 0, (i / 4) * 2.0 - 2.0 + r.randf_range(-0.3, 0.3))
		_man(i + 1, 0, poses[i], at, 180.0 - 40.0 + r.randf_range(-15, 15))
	_look(Vector3(5.5, 4.2, 9.0), Vector3(0, 0.6, 0), 34.0)
	_save(await _shot(), "rifleman_squad.png")


func _lods() -> void:
	_clear()
	for l in 3:
		_man(3, l, "stand", Vector3((l - 1) * 1.3, 0, 0), 180.0 - 25.0)
	_look(Vector3(0, 1.0, 6.6), Vector3(0, 0.95, 0), 30.0)
	_save(await _shot(), "rifleman_lods.png")


func _closeup() -> void:
	_clear()
	_man(2, 0, "stand", Vector3(-0.35, 0, 0), 180.0 - 25.0)
	_man(5, 0, "aim", Vector3(0.75, 0, -0.4), 180.0 - 70.0)
	_look(Vector3(0.35, 1.55, 2.6), Vector3(0.15, 1.38, 0), 32.0)
	_save(await _shot(), "rifleman_closeup.png")
