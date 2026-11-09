extends SceneTree
## Heavy MG team pictures for the user's look (Question Chat, 2026-11-09).
##   Godot --path iron_front --resolution 1600x900 -s res://tools/mg_pictures.gd
## Writes results/units/mg/: mg_gun.png, mg_parts.png, mg_crew.png, mg_team.png, mg_carry.png

const MG := preload("res://scripts/units/mg_builder.gd")
const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
const OUT := "res://results/units/mg/"
const W := 1600
const H := 900
const ROLES := ["nco", "gunner", "loader", "carrier", "carrier", "carrier"]
const NAMES := ["NCO", "Gunner", "Loader", "Ammo carrier", "Ammo carrier", "Ammo carrier"]
const SEEDS := [11, 2, 7, 4, 9, 13]

var stage: Node3D
var cam: Camera3D
var ui: CanvasLayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_setup_world()
	print("MG TRIS gun=%d tripod=%d folded=%d box=%d shield=%d gun_mid=%d" % [MG.gun().tri_count(), MG.tripod().tri_count(),
		MG.tripod(true).tri_count(), MG.ammo_box().tri_count(), MG.shield().tri_count(), MG.gun(1).tri_count()])
	for r in ["nco", "gunner", "loader", "carrier"]:
		var s := Soldier.new().setup(3, 0, r)
		print("CREW TRIS %s=%d" % [r, s.tri_count()])
		s.free()
	await _gun()
	await _parts()
	await _crew()
	await _team()
	await _carry()
	print("MG PICTURES OK")
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
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.66, 0.60, 0.45)
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


func _label(text: String, at: Vector3, size := 20) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	ui.add_child(l)
	var sp := cam.unproject_position(at)
	l.position = sp - Vector2(l.get_minimum_size().x * 0.5, 0)


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


func _shot() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(img: Image, file: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + file))
	print("saved ", file)


func _sheet(parts: Array[Image], cols: int) -> Image:
	var pw := parts[0].get_width()
	var ph := parts[0].get_height()
	var rows := int(ceil(float(parts.size()) / float(cols)))
	var out := Image.create(pw * cols, ph * rows, false, Image.FORMAT_RGB8)
	for i in parts.size():
		out.blit_rect(parts[i], Rect2i(0, 0, pw, ph), Vector2i((i % cols) * pw, (i / cols) * ph))
	return out


func _piece(g: UnitGeo, at: Vector3, yaw := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = MG.mesh(g)
	m.position = at
	m.rotation.y = deg_to_rad(yaw)
	stage.add_child(m)
	return m


func _man(i: int, at: Vector3, yaw: float) -> Soldier:
	var s := Soldier.new().setup(SEEDS[i], 0, ROLES[i])
	s.position = at
	s.rotation.y = deg_to_rad(yaw)
	stage.add_child(s)
	return s


# ---------------------------------------------------------------- carries

const FREE := {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
	"rot": {B.UARM_R: Vector3(2, 0, 5), B.FARM_R: Vector3(8, 0, 0)}}
const BOXES := {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
	"rot": {B.UARM_R: Vector3(0, 0, 14), B.FARM_R: Vector3(4, 0, -6), B.UARM_L: Vector3(0, 0, -14),
		B.FARM_L: Vector3(4, 0, 6)}}


static func _palm_box() -> Transform3D:
	var palm := (B.REST[B.HAND_R] - B.REST[B.FARM_R]).normalized() * B.PALM
	return Transform3D(Basis(), palm - MG.BOX_HANDLE - Vector3(0, 0.005, 0))


func _boxes(s: Soldier) -> void:
	for hb in [B.HAND_R, B.HAND_L]:
		var m := MeshInstance3D.new()
		m.mesh = MG.mesh(MG.ammo_box())
		s.attach(hb, m, _palm_box())


func _stand_spec(role: String) -> Dictionary:
	if role == "carrier":
		return Rig.over(Body.body("stand"), BOXES)
	return Rig.over(Body.body("stand"), FREE)


# ---------------------------------------------------------------- pictures

func _gun() -> void:
	var parts: Array[Image] = []
	for i in 4:
		_clear()
		var n := MG.set_up(i == 3)
		n.rotation.y = deg_to_rad([200.0, 120.0, 30.0, 215.0][i])
		stage.add_child(n)
		_look(Vector3(0, 1.0, 2.6), Vector3(0, 0.35, 0), 34.0)
		var img: Image = await _shot()
		parts.append(img.get_region(Rect2i(W / 2 - 400, 100, 800, 700)))
	_save(_sheet(parts, 2), "mg_gun.png")


func _parts() -> void:
	_clear()
	_piece(MG.gun(), Vector3(-0.9, 0.1, 0), 120.0)
	_piece(MG.tripod(true), Vector3(0.1, 0.03, 0), 70.0)
	_piece(MG.ammo_box(), Vector3(0.8, 0, -0.1), 30.0)
	_piece(MG.ammo_box(true), Vector3(1.15, 0, 0.15), 20.0)
	_piece(MG.shield(), Vector3(1.5, 0, -0.4), -20.0)
	_look(Vector3(0.3, 1.5, 2.8), Vector3(0.3, 0.1, 0), 40.0)
	await _shot()
	_label("Gun", Vector3(-0.9, 0.45, 0))
	_label("Tripod, folded", Vector3(0.1, 0.25, 0))
	_label("Ammo boxes", Vector3(0.95, 0.4, 0))
	_label("Shield (optional)", Vector3(1.5, 0.6, -0.4))
	_save(await _shot(), "mg_parts.png")


func _crew() -> void:
	var parts: Array[Image] = []
	for view in 2:
		_clear()
		for i in 6:
			var s := _man(i, Vector3(-3.0 + 1.2 * i, 0, 0), 180.0 if view == 0 else 0.0)
			s.pose_spec_world(_stand_spec(ROLES[i]))
			if ROLES[i] == "carrier":
				_boxes(s)
		_look(Vector3(0, 1.2, 6.2), Vector3(0, 0.95, 0), 42.0)
		await _shot()
		if view == 0:
			for i in 6:
				_label(NAMES[i], Vector3(-3.0 + 1.2 * i, 2.1, 0))
		var im: Image = await _shot()
		parts.append(im.get_region(Rect2i(0, 120, W, 600)))
	_save(_sheet(parts, 1), "mg_crew.png")


func _team() -> void:
	_clear()
	var gun := MG.set_up(false)
	stage.add_child(gun)
	var gx := Transform3D(Basis(), Vector3(0, MG.PIN_H, 0))
	for k in 3:
		_piece(MG.ammo_box(k == 0), Vector3(0.62 + 0.13 * k, 0, -0.2 + 0.05 * k), 90.0 + 8.0 * k)
	# Gunner kneeling square behind the grips.
	var gunner := _man(1, Vector3(0, 0, 0.78), 0.0)
	var gspec := Rig.over(Body.body("kneel"), FREE)
	gspec = Rig.over(gspec, {"add": {B.HIPS: Vector3(0, 28, 0), B.SPINE: Vector3(-14, 0, 0), B.CHEST: Vector3(-6, 8, 0),
		B.NECK: Vector3(18, -16, 0), B.HEAD: Vector3(8, -10, 14)},
		"pole_r": Vector3(0.5, -0.6, 0.2), "pole_l": Vector3(-0.5, -0.6, 0.2)})
	gunner.pose_spec_world(gspec, {"hand_r": gx * MG.GRIP_R, "hand_l": gx * MG.GRIP_L})
	# Loader on the right, feeding the belt.
	var loader := _man(2, Vector3(0.5, 0, 0.32), 90.0)
	var lspec := Rig.over(Body.body("kneel"), FREE)
	lspec = Rig.over(lspec, {"add": {B.SPINE: Vector3(-12, 0, 0), B.NECK: Vector3(14, 0, 0)},
		"pole_r": Vector3(0.3, -0.7, 0.3), "pole_l": Vector3(-0.3, -0.7, 0.3)})
	loader.pose_spec_world(lspec, {"hand_l": gx * MG.FEED + Vector3(0.03, -0.02, 0), "hand_r": Vector3(0.62, 0.3, -0.2)})
	# NCO out to the left, pointing out a target.
	var nco := _man(0, Vector3(-1.5, 0, 0.6), -10.0)
	var nspec := Rig.over(Body.body("kneel"), FREE)
	nspec = Rig.over(nspec, {"add": {B.HIPS: Vector3(0, 28, 0), B.CHEST: Vector3(0, 10, 0), B.NECK: Vector3(10, -10, 0),
		B.HEAD: Vector3(8, -10, 14)}, "pole_r": Vector3(0.4, -0.6, 0.3)})
	nco.pose_spec_world(nspec, {"hand_r": nco.global_transform * Vector3(0.6, 1.55, -1.3)})
	# Carriers: two covering with rifles, one bringing boxes up.
	var p := R.poses()
	var c1 := _man(3, Vector3(1.7, 0, -0.5), 15.0)
	c1.pose_spec_world(p["prone"])
	var c2 := _man(4, Vector3(-2.4, 0, -0.2), -20.0)
	c2.pose_spec_world(p["kneel"])
	var c3 := _man(5, Vector3(1.5, 0, 2.7), -25.0)
	var walk := Body.gait(Body.WALK, BOXES)
	c3.pose_spec_world(walk["keys"][3][1])
	_boxes(c3)
	_look(Vector3(-3.6, 3.4, -4.8), Vector3(0.0, 0.3, 0.7), 44.0)
	_save(await _shot(), "mg_team.png")
	_look(Vector3(-2.9, 1.4, -3.2), Vector3(0.1, 0.5, 0.5), 42.0)
	_save(await _shot(), "mg_team_front.png")


func _carry() -> void:
	_clear()
	var order := [0, 1, 2, 3, 4, 5]
	for k in order.size():
		var i: int = order[k]
		var at := Vector3(0.35 * (k % 2) - 0.15, 0, -2.6 + 1.25 * k)
		var s := _man(i, at, 0.0)
		var carry: Dictionary = FREE.duplicate(true)
		var props: Array = []
		match ROLES[i]:
			"gunner":
				# The gun on the right shoulder, barrel forward, hand on the jacket.
				var lx := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8)), Vector3(0.17, 0.30, 0.22))
				props.append([B.CHEST, MG.gun(), lx])
				carry["hand_r"] = [B.CHEST, B.REST[B.CHEST] + lx * Vector3(0.0, -0.04, -0.3)]
				carry["pole_r"] = Vector3(0.8, -0.5, 0.2)
			"loader":
				# The folded tripod over the left shoulder.
				var lx := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-14)), Vector3(-0.17, 0.28, 0.1))
				props.append([B.CHEST, MG.tripod(true), lx])
				carry["hand_l"] = [B.CHEST, B.REST[B.CHEST] + lx * Vector3(0.0, 0.0, -0.45)]
				carry["pole_l"] = Vector3(-0.8, -0.5, 0.2)
			"carrier":
				carry = BOXES.duplicate(true)
		var walk := Body.gait(Body.WALK, carry)
		s.pose_spec_world(walk["keys"][(k * 5) % 20][1])
		for pr in props:
			var m := MeshInstance3D.new()
			m.mesh = MG.mesh(pr[1])
			s.attach(pr[0], m, pr[2])
		if ROLES[i] == "carrier":
			_boxes(s)
	_look(Vector3(5.2, 2.4, 1.8), Vector3(0, 0.8, 0.4), 44.0)
	_save(await _shot(), "mg_carry.png")
