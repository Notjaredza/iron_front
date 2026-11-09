extends SceneTree
## Iron Front buildings: stills for the user's look (Asset Builder Chat).
##   Godot --path iron_front --resolution 1600x900 -s res://tools/bld_pictures.gd [-- --only=prefix]
## Per building: <kind>_day, <kind>_night, <kind>_stages (plot, frame, half, finished, damaged,
## collapsing, ruin in a row). Per set: set_<name>_far_ghost. Extra shots come from the set files' SHOTS.

const OUT := "res://results/buildings/"

var cam: Camera3D
var stage: Node3D
var sun: DirectionalLight3D
var env: Environment
var ground: MeshInstance3D
var only := ""
var fx: AirFx
var tris := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_world()
	var shots: Array[String] = []
	for k: String in Buildings.KINDS:
		for s in ["day", "night", "stages"]:
			shots.append(k + "_" + s)
	var sets := {}
	for k: String in Buildings.KINDS:
		sets[Buildings.KINDS[k][1]] = true
	for s: String in sets:
		shots.append("set_%s_far_ghost" % s)
	for s: String in Extra.SHOTS:
		shots.append(s)
	for s in shots:
		if only != "" and not s.begins_with(only):
			continue
		await _shot(s)
	print("BLD PICTURES DONE")
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
	env.ssao_radius = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	root.add_child(sun)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.58, 0.30)
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
	fx = AirFx.make()
	stage.add_child(fx)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	env.ambient_light_energy = 0.9
	env.background_energy_multiplier = 1.0
	ground.visible = true


func night() -> void:
	sun.light_energy = 0.12
	sun.light_color = Color(0.55, 0.65, 1.0)
	env.ambient_light_energy = 0.22
	env.background_energy_multiplier = 0.12


func look(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


## Steps the buildings' life and the effects for secs (smoke builds up, flags move).
func run(list: Array, secs: float) -> void:
	var n := int(secs * 30.0)
	for i in n:
		for b: Building in list:
			b.step(1.0 / 30.0, fx)
		fx.step(1.0 / 30.0)


func add(kind: String, at := Vector3.ZERO, yaw := 0.0) -> Building:
	var b := Buildings.make(kind)
	stage.add_child(b)
	b.position = at
	b.rotation.y = yaw
	return b


func _shot(nm: String) -> void:
	_clear()
	if nm.begins_with("set_"):
		var sname := nm.substr(4).replace("_far_ghost", "")
		var kinds := Buildings.of_set(sname)
		var x := 0.0
		var w := 0.0
		for k in kinds:
			w += float(Buildings.KINDS[k][0].x) * 8.0 + 6.0
		x = -w * 0.5
		for k in kinds:
			var sz: Vector2i = Buildings.KINDS[k][0]
			var cx := x + float(sz.x) * 4.0
			var fb := add(k, Vector3(cx, 0, -14))
			fb.far(true)
			var gb := add(k, Vector3(cx, 0, 16))
			gb.body.visible = false
			gb.glow.visible = false
			gb.parts.visible = false
			gb.add_child(gb.ghost(k != kinds[-1]))
			print("BLD TRIS %s near=%d far=%d" % [k, fb.tri_count(), fb.far_tris()])
			x += float(sz.x) * 8.0 + 6.0
		look(Vector3(0, w * 0.55, w * 0.75), Vector3(0, 0, 2), 50)
	elif (nm.ends_with("_day") or nm.ends_with("_night")) and Buildings.KINDS.has(nm.substr(0, nm.rfind("_"))):
		var k := nm.substr(0, nm.rfind("_"))
		var b := add(k)
		var sz := float(maxi(b.tiles.x, b.tiles.y)) * 8.0
		if nm.ends_with("_night"):
			night()
			b.set_lights(true)
		await process_frame
		run([b], 2.5)
		look(Vector3(-sz * 0.95, sz * 0.62, -sz * 1.05), Vector3(0, sz * 0.12, 0), 50)
	elif nm.ends_with("_stages") and Buildings.KINDS.has(nm.substr(0, nm.rfind("_"))):
		var k := nm.substr(0, nm.rfind("_"))
		var sz: Vector2i = Buildings.KINDS[k][0]
		var step := float(sz.x) * 8.0 + 8.0
		var list: Array = []
		for i in 7:
			var b := add(k, Vector3((3.0 - float(i)) * step, 0, 0))
			list.append(b)
		await process_frame
		for i in 4:
			(list[i] as Building).set_stage(i)
		(list[4] as Building).set_damage(1)
		(list[5] as Building).collapse(0.45)
		(list[6] as Building).set_damage(2)
		run(list, 2.0)
		var w := step * 7.0
		look(Vector3(0, w * 0.32, -w * 0.62), Vector3(0, 0, 0), 46)
	else:
		await Extra.new().shot(self, nm)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + nm + ".png"))
	print("BLD PICTURE ", nm)


## Extra shots (walls, gates, defences, the overview) live in tools/bld_extra.gd.
const Extra := preload("res://tools/bld_extra.gd")
