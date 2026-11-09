extends SceneTree
## Red jackets round 1 pictures (Building Chat 1, 2026-11-10). Needs a window (the GPU):
##   Godot --path iron_front --resolution 1600x900 -s res://tools/redcoat_pictures.gd -- look
##   ... -- pose <role> <pose> [<pose> ...]     one pose from four sides, for tuning
##   ... -- sheet <clip> [frames]               a contact sheet of a clip (the role from the clip's name)
## Writes results/units/redcoats/*.png.

const M := preload("res://scripts/units/anim/clips_musket.gd")
const Anim := preload("res://scripts/units/anim/anim.gd")
const B := preload("res://scripts/units/soldier_builder.gd")
const OUT := "res://results/units/redcoats/"
const ROLES: Array[String] = ["musketeer", "officer", "drummer", "ensign"]

var stage: Node3D
var cam: Camera3D
var ui: CanvasLayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_setup_world()
	var args := OS.get_cmdline_user_args()
	var mode := "look" if args.is_empty() else args[0]
	match mode:
		"look":
			await _look_set()
		"pose":
			await _poses(args[1], args.slice(2))
		"sheet":
			await _sheet(args[1], int(args[2]) if args.size() > 2 else 10)
	print("REDCOAT PICTURES OK")
	quit()


func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.52, 0.72)
	sm.sky_horizon_color = Color(0.74, 0.80, 0.84)
	sm.ground_bottom_color = Color(0.32, 0.31, 0.27)
	sm.ground_horizon_color = Color(0.72, 0.77, 0.80)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.47, 0.32)
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	root.add_child(ground)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	stage = Node3D.new()
	root.add_child(stage)
	ui = CanvasLayer.new()
	root.add_child(ui)


func _clear() -> void:
	for c in stage.get_children():
		c.free()
	for c in ui.get_children():
		c.free()


func _label(text: String, pos: Vector2, size := 22) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	ui.add_child(l)


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


func _grab() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)


func _man(role: String, seed_value: int, lod: int, at: Vector3, yaw_deg: float, pose := "stand") -> Redcoat:
	var r := Redcoat.new()
	r.setup(seed_value, lod, role)
	r.position = at
	r.rotation.y = deg_to_rad(yaw_deg)
	stage.add_child(r)
	r.set_pose(pose)
	r.set_time(1.3)
	return r


## Four views side by side in one picture (front, three-quarter, side, back).
func _four(target: Vector3, dist: float, h: float, fov: float) -> Image:
	var tiles: Array[Image] = []
	for a: float in [0.0, 40.0, 90.0, 180.0]:
		var r := deg_to_rad(a)
		_look(target + Vector3(sin(r) * dist, h, -cos(r) * dist), target, fov)
		tiles.append(await _grab())
	return _tile(tiles, 4)


func _tile(tiles: Array[Image], cols: int) -> Image:
	var w := tiles[0].get_width()
	var hh := tiles[0].get_height()
	var tw := w / 2
	var th := hh / 2
	var rows := ceili(float(tiles.size()) / cols)
	var out := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		var t := tiles[i]
		t.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(t, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	return out


func _look_set() -> void:
	# The four roles, front and back, close.
	_clear()
	for i in ROLES.size():
		_man(ROLES[i], 3 + i, 0, Vector3(-1.95 + 1.3 * i, 0, 0), 0.0)
	_look(Vector3(0, 1.4, -6.2), Vector3(0, 1.15, 0), 36.0)
	_save(await _grab(), "look_front")
	_look(Vector3(-4.2, 1.6, -4.6), Vector3(-0.3, 1.1, 0), 36.0)
	_save(await _grab(), "look_three_quarter")
	_look(Vector3(0, 1.5, 6.2), Vector3(0, 1.15, 0), 36.0)
	_save(await _grab(), "look_back")
	# A line of musketeers: the faces and builds vary.
	_clear()
	for i in 8:
		_man("musketeer", 20 + i, 0, Vector3(-3.15 + 0.9 * i, 0, 0), 0.0, "shoulder")
	_look(Vector3(-1.5, 1.6, -6.8), Vector3(0, 1.2, 0), 42.0)
	_save(await _grab(), "line_shouldered")
	# Close-ups: the head and hat, the musket, the drum, the colour.
	_clear()
	_man("musketeer", 3, 0, Vector3.ZERO, 0.0)
	_look(Vector3(0.45, 1.75, -0.95), Vector3(0, 1.62, 0), 30.0)
	var a := await _grab()
	_look(Vector3(1.0, 1.0, -0.6), Vector3(0.25, 0.95, -0.1), 40.0)
	var b := await _grab()
	_clear()
	_man("drummer", 5, 0, Vector3.ZERO, 0.0)
	_look(Vector3(-0.9, 1.3, -1.4), Vector3(-0.1, 1.0, -0.1), 34.0)
	var c := await _grab()
	_clear()
	_man("ensign", 6, 0, Vector3.ZERO, 0.0)
	_look(Vector3(1.4, 2.4, -4.2), Vector3(0.5, 2.1, 0), 40.0)
	var d := await _grab()
	_save(_tile([a, b, c, d], 2), "closeups")
	# Close, mid and far meshes.
	_clear()
	for lod in 3:
		for i in ROLES.size():
			_man(ROLES[i], 3 + i, lod, Vector3(-4.0 + 0.9 * i + 3.6 * lod, 0, 0), 0.0)
	_look(Vector3(1.4, 1.6, -9.5), Vector3(1.4, 1.0, 0), 46.0)
	var tris := ""
	for lod in 3:
		var parts: Array[String] = []
		for i in ROLES.size():
			var r := Redcoat.new()
			r.setup(3 + i, lod, ROLES[i])
			parts.append("%d" % r.tri_count())
			r.free()
		tris += "lod %d: %s   " % [lod, " / ".join(parts)]
	_label("close / mid / far   triangles  " + tris, Vector2(20, 16), 20)
	_save(await _grab(), "lods")


func _poses(role: String, names: Array) -> void:
	var tiles: Array[Image] = []
	for n: String in names:
		_clear()
		_man(role, 3, 0, Vector3.ZERO, 0.0, n)
		var img := await _four(Vector3(0, 1.0, 0), 3.4, 0.4, 40.0)
		_save(img, "pose_%s_%s" % [role, n])


func _sheet(clip_name: String, frames: int) -> void:
	_clear()
	var role := "musketeer"
	for r in ["officer", "drummer", "ensign"]:
		if clip_name.begins_with(r):
			role = r
	var lib := Redcoat.library()
	var c: Dictionary = lib[clip_name]
	var man := _man(role, 3, 0, Vector3.ZERO, 0.0)
	var tiles: Array[Image] = []
	for i in frames:
		var t := float(c["len"]) * float(i) / float(frames - 1)
		man.show_clip(c, t)
		man.set_time(t)
		_look(Vector3(2.6, 1.5, -2.2), Vector3(0, 1.05, 0), 42.0)
		var img := await _grab()
		tiles.append(img)
	_save(_tile(tiles, 5), "sheet_" + clip_name)
