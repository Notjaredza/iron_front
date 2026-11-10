extends SceneTree
## Iron Front: the General, stills for the user's look (Asset Builder Chat, 2026-11-10).
##   Godot --path iron_front --resolution 1600x900 -s res://tools/gen_pictures.gd [-- --only=prefix]
## Shots go to results/general/.

const OUT := "res://results/general/"
const B := preload("res://scripts/units/soldier_builder.gd")
const G := preload("res://scripts/units/general/clips_general.gd")
const SHOTS: Array[String] = ["gen_turn", "gen_face", "gen_lods", "gen_poses_a", "gen_poses_b", "gen_guards",
	"gen_guard_close", "gen_podium", "gen_car", "gen_escort"]

var cam: Camera3D
var stage: Node3D
var sun: DirectionalLight3D
var env: Environment
var only := ""
var flare_mesh: Mesh


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_world()
	flare_mesh = GeneralKit.flare_pistol().to_mesh(Soldier.material())
	for s in SHOTS:
		if only != "" and not s.begins_with(only):
			continue
		await _shot(s)
	print("GEN PICTURES DONE")
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
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.58, 0.30)
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	root.add_child(ground)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true


func look(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


func general(at: Vector3, yaw: float, spec: Dictionary, lod := 0) -> Soldier:
	var s := GeneralKit.general(lod)
	stage.add_child(s)
	s.position = at
	s.rotation.y = yaw
	s.pose_spec_world(spec)
	return s


func guard(seed_value: int, at: Vector3, yaw: float, spec: Dictionary) -> Soldier:
	var s := GeneralKit.guard(seed_value)
	stage.add_child(s)
	s.position = at
	s.rotation.y = yaw
	s.pose_spec_world(spec)
	return s


func flare_in_hand(s: Soldier) -> void:
	var m := MeshInstance3D.new()
	m.mesh = flare_mesh
	stage.add_child(m)
	m.global_transform = s.global_transform * s.skel.get_bone_global_pose(B.HAND_R) * Transform3D(Basis(), Vector3(0, -0.07, -0.01))


func mesh_node(m: Mesh, xf: Transform3D) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = m
	stage.add_child(n)
	n.global_transform = xf
	return n


func _shot(nm: String) -> void:
	if stage:
		stage.free()
	stage = Node3D.new()
	root.add_child(stage)
	var tris := ""
	match nm:
		"gen_turn":
			for i in 4:
				var s := general(Vector3(-2.4 + 1.6 * float(i), 0, 0), [0.0, -PI * 0.25, -PI * 0.5, PI][i], G.stand())
				if i == 0:
					tris = "near %d tris" % s.tri_count()
			look(Vector3(0, 1.3, -6.0), Vector3(0, 1.0, 0), 34)
		"gen_face":
			general(Vector3.ZERO, -0.35, G.stand())
			look(Vector3(0.12, 1.72, -0.9), Vector3(0, 1.62, 0), 30)
		"gen_lods":
			for i in 3:
				var s := general(Vector3(-1.2 + 1.2 * float(i), 0, 0), -0.4, G.stand(), i)
				tris += "lod%d %d  " % [i, s.tri_count()]
			look(Vector3(0, 1.3, -5.0), Vector3(0, 1.0, 0), 34)
		"gen_poses_a":
			var list := [G.inspect(20.0), G.salute(), G.speech_point(-20.0), G.rally_sweep(0.3), G.rally_fist(1.0), G.flare_up(1.0)]
			for i in list.size():
				var s := general(Vector3(-3.5 + 1.4 * float(i), 0, 0), -0.25, list[i])
				if i == 5:
					flare_in_hand(s)
			look(Vector3(0, 1.4, -7.6), Vector3(0, 1.1, 0), 40)
		"gen_poses_b":
			var list := [G.bark(Vector3(-3, 1.2, -6)), G.bark_stick(1.0), G.no_retreat(), G.hurt(), G.speech_pound(0.0), G.lying()]
			for i in list.size():
				general(Vector3(-3.5 + 1.4 * float(i), 0, 0), -0.25, list[i])
			look(Vector3(0, 1.4, -7.6), Vector3(0, 1.0, 0), 40)
		"gen_guards":
			general(Vector3.ZERO, 0.0, G.inspect())
			for i in 4:
				var p: Vector3 = [Vector3(-1.4, 0, 0.4), Vector3(1.4, 0, 0.4), Vector3(-1.0, 0, 1.6), Vector3(1.0, 0, 1.6)][i]
				guard(300 + i, p, 0.0, G.guard_stand() if i < 2 else G.guard_port())
			look(Vector3(1.8, 1.7, -5.2), Vector3(0, 1.0, 0.6), 36)
		"gen_guard_close":
			var s := guard(301, Vector3(-0.45, 0, 0), -0.3, G.guard_stand())
			guard(302, Vector3(0.45, 0, 0), -0.2, G.guard_port())
			tris = "guard %d tris" % s.tri_count()
			look(Vector3(0.0, 1.35, -2.6), Vector3(0, 1.05, 0), 36)
		"gen_podium":
			var pod := GeneralKit.podium().to_mesh(Soldier.material())
			var px := Transform3D(Basis(), Vector3(0, 0, 0))
			mesh_node(pod, px)
			general(Vector3(0, 0.5, 0.0), 0.0, G.speech_point(-15.0))
			for i in 2:
				guard(310 + i, Vector3(-1.1 + 2.2 * float(i), 0.5, 0.6), 0.0, G.guard_stand())
			look(Vector3(2.6, 1.9, -6.2), Vector3(0, 1.8, 0.4), 40)
		"gen_car":
			var car := GeneralKit.car().to_mesh(Soldier.material())
			mesh_node(car, Transform3D())
			var stand_at := GeneralKit.CAR_STAND_AT
			general(stand_at, 0.0, G.car_stand(1.0, Vector3(-0.5, 1.4 - stand_at.y, 0.3 - stand_at.z)))
			look(Vector3(4.2, 2.4, -4.4), Vector3(0, 1.2, 0.3), 40)
		"gen_escort":
			general(Vector3.ZERO, 0.0, G.walking())
			for i in 4:
				var p: Vector3 = [Vector3(-1.2, 0, -1.2), Vector3(1.2, 0, -1.2), Vector3(-1.2, 0, 1.4), Vector3(1.2, 0, 1.4)][i]
				guard(320 + i, p, 0.0, G.guard_port())
			look(Vector3(5.0, 3.2, -6.0), Vector3(0, 0.9, 0.0), 38)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + nm + ".png"))
	print(nm, " ", tris)
