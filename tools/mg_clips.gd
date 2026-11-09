extends SceneTree
## Heavy MG team moves, recorded as video frames (Question Chat, 2026-11-09).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/mg_clips.gd -- [scene ...]
## Scenes: march, setup, fire, swap. Frames go to results/units/anim_frames/mg_<scene>/,
## ffmpeg makes results/units/anim/mg_<scene>.mp4.
## Each man runs a timeline of segments (pose blends with hands on world points,
## walks along a line with the shared gait, or a clip); props (gun, tripod, boxes)
## run their own timeline (on a bone or in the world, blended when they change hands).

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Anim := preload("res://scripts/units/anim/anim.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
const C := preload("res://scripts/units/anim/clips_mg.gd")
const MG := preload("res://scripts/units/mg_builder.gd")
const FRAMES := "res://results/units/anim_frames/"
const FPS := 30.0
const SCENES: Array[String] = ["march", "setup", "fire", "swap"]

## Places around the gun (its pin at the origin, firing toward -Z).
const G_SLOT := Vector3(0.0, 0, 0.80)
const L_SLOT := Vector3(0.55, 0, 0.30)
const NCO_SLOT := Vector3(-1.7, 0, 0.6)
const FEED_BOX := Vector3(0.66, 0, -0.18)

var stage: Node3D
var cam: Camera3D
var ui: CanvasLayer
var title: Label
var actors: Array = []  # {s, segs}
var props: Array = []  # {node, keys, mesh_fn, last}
var fire_spans: Array = []  # [t0, t1]
var trav_fn: Callable
var belt_fn: Callable  # t -> [from, to] or []
var belt_node: MeshInstance3D
var flash: MeshInstance3D
var puffs: Array = []
var now := 0.0
var prefix := "mg_"  # frame folder and video name prefix (subclasses change it)
var frame := 0
var gun_node: MeshInstance3D
var tri_cache := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_setup_world()
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else SCENES):
		await _record(sc)
	print("MG CLIPS OK")
	quit()


# ---------------------------------------------------------------- world

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
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.66, 0.60, 0.45)
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	root.add_child(ground)
	var mk := StandardMaterial3D.new()
	mk.albedo_color = Color(0.50, 0.46, 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 220:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.15, 0.5), 0.01, rng.randf_range(0.04, 0.08))
		bm.material = mk
		m.mesh = bm
		m.position = Vector3(rng.randf_range(-9, 9), 0.005, rng.randf_range(-30, 9))
		m.rotation.y = rng.randf() * TAU
		root.add_child(m)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	stage = Node3D.new()
	root.add_child(stage)
	ui = CanvasLayer.new()
	root.add_child(ui)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(24, 18)
	ui.add_child(title)


func _reset() -> void:
	for c in stage.get_children():
		c.free()
	actors.clear()
	props.clear()
	fire_spans.clear()
	puffs.clear()
	trav_fn = func(_t: float) -> float: return 0.0
	belt_fn = func(_t: float) -> Array: return []
	belt_node = MeshInstance3D.new()
	stage.add_child(belt_node)
	flash = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.1
	sp.height = 0.3
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.8, 0.4)
	sp.material = fm
	flash.mesh = sp
	stage.add_child(flash)
	gun_node = null


# ---------------------------------------------------------------- the gun

func firing(t: float) -> bool:
	for s: Array in fire_spans:
		if t >= s[0] and t < s[1]:
			return true
	return false


func fire_time(t: float) -> float:
	for s: Array in fire_spans:
		if t >= s[0] and t < s[1]:
			return t - float(s[0])
	return -1.0


## The gun on its tripod at time t (turned by the traverse, shaking while it fires).
func gun_xf(t: float) -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(trav_fn.call(t)))
	var p := Vector3(0, MG.PIN_H, 0)
	if firing(t):
		var k := frame % 3
		p += b * Vector3(0, 0.003 * k, 0.012 * k)
	return Transform3D(b, p)


func grips(t: float) -> Dictionary:
	var x := gun_xf(t)
	return {"hand_r": x * MG.GRIP_R, "hand_l": x * MG.GRIP_L}


# ---------------------------------------------------------------- actors

func _man(seed_value: int, role: String) -> Dictionary:
	var s := Soldier.new().setup(seed_value, 0, role)
	stage.add_child(s)
	var a := {"s": s, "segs": [], "pos": Vector3.ZERO, "yaw": 0.0}
	actors.append(a)
	return a


## Holds or blends to spec over d seconds. hands: Callable(t) -> {hand: world point}.
## from: the spec it blends out of ("prev" = where the last segment ended).
func pose(a: Dictionary, t0: float, d: float, spec: Dictionary, hands: Variant = null, from: Variant = "prev",
		ease := "smooth", at: Variant = null, yaw: Variant = null) -> void:
	var seg := {"type": "pose", "t0": t0, "d": d, "spec": spec, "hands": hands, "ease": ease}
	var prev: Variant = a["segs"].back() if not a["segs"].is_empty() else null
	if from is String and from == "prev":
		if prev != null:
			seg["from"] = prev["end_spec"]
			seg["from_hands"] = prev["end_hands"]
	elif from != null:
		seg["from"] = from
	seg["pos"] = at if at != null else a["pos"]
	seg["yaw"] = yaw if yaw != null else a["yaw"]
	seg["yaw_from"] = prev["end_yaw"] if prev != null else seg["yaw"]
	seg["end_yaw"] = seg["yaw"]
	a["pos"] = seg["pos"]
	a["yaw"] = seg["yaw"]
	seg["end_spec"] = spec
	seg["end_hands"] = hands
	a["segs"].append(seg)


## Walks (or runs) in a straight line with gait clip g. Returns the arrival time.
func move(a: Dictionary, t0: float, to: Vector3, g: Dictionary, face: Variant = null, phase := 0.0) -> float:
	var from: Vector3 = a["pos"]
	var d := to - from
	var v: float = g["speed"]
	var dur := d.length() / v
	var yaw := atan2(-d.x, -d.z) if d.length() > 0.01 else float(a["yaw"])
	var seg := {"type": "move", "t0": t0, "d": dur, "from": from, "to": to, "gait": g, "yaw": yaw, "end_yaw": yaw, "phase": phase}
	var end_t := fposmod(dur, float(g["len"]))
	var keys: Array = g["keys"]
	var ki := clampi(int(round(end_t / float(g["len"]) * (keys.size() - 1))), 0, keys.size() - 1)
	seg["end_spec"] = keys[ki][1]
	seg["end_hands"] = null
	a["segs"].append(seg)
	a["pos"] = to
	a["yaw"] = yaw if face == null else face
	if face != null:
		seg["face_after"] = face
	return t0 + dur


func clip(a: Dictionary, t0: float, c: Dictionary) -> void:
	var seg := {"type": "clip", "t0": t0, "d": c["len"], "clip": c, "pos": a["pos"], "yaw": a["yaw"], "end_yaw": a["yaw"]}
	seg["end_spec"] = c["keys"].back()[1]
	seg["end_hands"] = null
	a["segs"].append(seg)


func _hands_at(h: Variant, t: float) -> Dictionary:
	if h == null:
		return {}
	if h is Callable:
		return (h as Callable).call(t)
	return h


func _eval_actor(a: Dictionary, t: float) -> void:
	var segs: Array = a["segs"]
	var seg: Dictionary = segs[0]
	for sg: Dictionary in segs:
		if float(sg["t0"]) <= t:
			seg = sg
	var s: Soldier = a["s"]
	var lt := t - float(seg["t0"])
	match seg["type"]:
		"move":
			var v: float = seg["gait"]["speed"]
			var dist := minf(lt, float(seg["d"])) * v
			var dir: Vector3 = (seg["to"] - seg["from"]).normalized()
			s.position = seg["from"] + dir * dist
			s.rotation.y = seg["yaw"]
			s.show_globals(Anim.sample(seg["gait"], dist / v + float(seg.get("phase", 0.0))))
		"clip":
			s.position = seg["pos"]
			s.rotation.y = seg["yaw"]
			s.show_clip(seg["clip"], lt)
		_:
			s.position = seg["pos"]
			var d0: float = seg["d"]
			var u0 := 1.0 if d0 <= 0.0 else clampf(lt / d0, 0.0, 1.0)
			s.rotation.y = lerp_angle(float(seg.get("yaw_from", seg["yaw"])), float(seg["yaw"]), Anim.ease_of(u0, "smooth"))
			var d: float = seg["d"]
			var u := 1.0 if d <= 0.0 else clampf(lt / d, 0.0, 1.0)
			var hb := _hands_at(seg["hands"], t)
			if seg.has("from"):
				var ha := _hands_at(seg.get("from_hands"), t)
				s.pose_blend_world(seg["from"], seg["spec"], Anim.ease_of(u, seg["ease"]), ha, hb)
			else:
				s.pose_blend_world(seg["spec"], seg["spec"], 0.0, hb, hb)


# ---------------------------------------------------------------- props

## keys: [time, blend seconds, "bone", [actor, bone, local]] or [time, blend, "world", xf or Callable(t)].
func prop(mesh: Mesh, keys: Array, mesh_fn: Variant = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	stage.add_child(m)
	props.append({"node": m, "keys": keys, "mesh_fn": mesh_fn})
	return m


func _prop_xf(k: Array, t: float) -> Transform3D:
	if k[2] == "bone":
		var a: Dictionary = k[3][0]
		var s: Soldier = a["s"]
		return s.global_transform * s.skel.get_bone_global_pose(k[3][1]) * (k[3][2] as Transform3D)
	var w: Variant = k[3]
	if w is Callable:
		return (w as Callable).call(t)
	return w


func _eval_props(t: float) -> void:
	for p: Dictionary in props:
		var keys: Array = p["keys"]
		var i := 0
		for j in keys.size():
			if float(keys[j][0]) <= t:
				i = j
		var x := _prop_xf(keys[i], t)
		var bl: float = keys[i][1]
		if i > 0 and bl > 0.0 and t < float(keys[i][0]) + bl:
			var u := Anim.ease_of(clampf((t - float(keys[i][0])) / bl, 0.0, 1.0), "smooth")
			var x0 := _prop_xf(keys[i - 1], float(keys[i][0]))
			x = x0.interpolate_with(x, u)
		(p["node"] as Node3D).global_transform = x
		if p["mesh_fn"] != null:
			var mm: Variant = (p["mesh_fn"] as Callable).call(t)
			if mm != null:
				(p["node"] as MeshInstance3D).mesh = mm


func tripod_mesh(open: float) -> Mesh:
	var q := snappedf(clampf(open, 0.0, 1.0), 0.05)
	if not tri_cache.has(q):
		tri_cache[q] = MG.mesh(MG.tripod_at(q))
	return tri_cache[q]


# ---------------------------------------------------------------- effects

func _effects(t: float) -> void:
	var f := firing(t)
	var gx := gun_xf(t)
	flash.visible = f and frame % 3 == 0
	if flash.visible:
		flash.global_transform = Transform3D(gx.basis, gx * (MG.MUZZLE + Vector3(0, 0, -0.1)))
	var ft := fire_time(t)
	if ft > 1.2 and frame % 5 == 0:
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.06
		sp.height = 0.12
		sp.radial_segments = 8
		sp.rings = 4
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.95, 0.95, 0.95, 0.5)
		sp.material = mat
		m.mesh = sp
		stage.add_child(m)
		m.global_position = gx * Vector3(0, 0.09, -0.6)
		puffs.append({"m": m, "mat": mat, "t0": t})
	for pf: Dictionary in puffs.duplicate():
		var age := t - float(pf["t0"])
		var m: MeshInstance3D = pf["m"]
		if age > 1.3:
			m.queue_free()
			puffs.erase(pf)
			continue
		m.position += Vector3(0.05, 0.35, 0.03) / FPS
		m.scale = Vector3.ONE * (1.0 + age * 2.2)
		(pf["mat"] as StandardMaterial3D).albedo_color.a = 0.5 * (1.0 - age / 1.3)
	var bp: Array = belt_fn.call(t)
	belt_node.visible = not bp.is_empty()
	if belt_node.visible:
		belt_node.mesh = MG.mesh(MG.belt(MG.sag(bp[0], bp[1], 0.06 + 0.04 * (bp[0] as Vector3).distance_to(bp[1]))))


# ---------------------------------------------------------------- recording

func _record(sc: String) -> void:
	_reset()
	var length: float = call("_scene_" + sc)
	var phases: Array = _phases
	var dir := ProjectSettings.globalize_path(FRAMES + prefix + sc + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	FileAccess.open(ProjectSettings.globalize_path(FRAMES + ".gdignore"), FileAccess.WRITE).store_string("")
	var n := int(length * FPS)
	for f in n:
		frame = f
		var t := float(f) / FPS
		now = t
		_eval_props(t)
		for a in actors:
			_eval_actor(a, t)
		_eval_props(t)
		_effects(t)
		_camera.call(t)
		for ph: Array in phases:
			if t >= float(ph[0]):
				title.text = ph[1]
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(dir + "f%04d.jpg" % f, 0.92)
	print("frames ", prefix, sc, " ", n)


var _phases: Array = []
var _camera: Callable


# ---------------------------------------------------------------- scenes

## Six men with their loads: a loose group walking, then running.
func _scene_march() -> float:
	var roles := ["nco", "gunner", "loader", "carrier", "carrier", "carrier"]
	var seeds := [11, 2, 7, 4, 9, 13]
	var offs := [Vector3(-0.3, 0, -1.4), Vector3(0.5, 0, 0.0), Vector3(-0.7, 0, 0.6), Vector3(0.9, 0, 1.5),
		Vector3(-0.2, 0, 2.3), Vector3(0.6, 0, 3.2)]
	var carries := ["free", "gun", "tripod", "boxes", "boxes", "boxes"]
	var walk_d := 1.35 * 4.0
	for i in 6:
		var a := _man(seeds[i], roles[i])
		var c := C.carry(carries[i])
		var walk := Body.gait(Body.WALK, c)
		var run := Body.gait(C.RUN_LOADED, c)
		a["pos"] = offs[i] + Vector3(0, 0, 8)
		# A small start delay each, so the steps are not in time.
		var t1 := move(a, 0.0, a["pos"] + Vector3(0, 0, -walk_d), walk, null, 0.23 * i)
		move(a, t1, a["pos"] + Vector3(0, 0, -3.0 * 4.5), run, null, 0.17 * i)
		_loads(a, carries[i])
	_phases = [[0.0, "Gun team: walking with the loads"], [4.0, "Running (loaded, 3 m/s)"]]
	_camera = func(t: float) -> void:
		var z := 8.0 - (1.35 * minf(t, 4.0) + 3.0 * maxf(t - 4.0, 0.0))
		cam.fov = 40.0
		cam.transform = Transform3D(Basis(), Vector3(4.6, 3.6, z - 4.0)).looking_at(Vector3(0, 0.6, z + 1.0), Vector3.UP)
	# Shift each man's timeline by a little so the group breathes.
	for i in actors.size():
		for sg: Dictionary in actors[i]["segs"]:
			sg["t0"] = float(sg["t0"]) + 0.0
	return 8.4


func _loads(a: Dictionary, c: String) -> void:
	match c:
		"gun":
			prop(MG.mesh(MG.gun()), [[0.0, 0.0, "bone", [a, B.CHEST, C.GUN_ON_SHOULDER]]])
		"tripod":
			prop(MG.mesh(MG.tripod_at(0.0)), [[0.0, 0.0, "bone", [a, B.CHEST, C.TRIPOD_ON_SHOULDER]]])
		"boxes":
			for hb in [B.HAND_R, B.HAND_L]:
				prop(MG.mesh(MG.ammo_box()), [[0.0, 0.0, "bone", [a, hb, C.box_in_hand()]]])


## Arrive, set the gun up, fire a burst, pack up and move off.
func _scene_setup() -> float:
	var walk_box := Body.gait(Body.WALK, C.carry("boxes"))
	trav_fn = func(t: float) -> float: return 14.0 * sin((t - 8.0) * 1.3) if t > 8.0 and t < 11.0 else 0.0
	fire_spans = [[8.2, 10.8]]
	# Loader: tripod in, set it down, open it, then to his place at the feed.
	var ld := _man(7, "loader")
	ld["pos"] = Vector3(0.3, 0, 5.0)
	var walk_tri := Body.gait(Body.WALK, C.carry("tripod"))
	var t_ld := move(ld, 0.0, Vector3(0.12, 0, 0.78), walk_tri, 0.0)
	var top_at := func(t: float) -> Vector3:
		var o := _tri_open(t)
		return Vector3(0, lerpf(0.06, MG.PIN_H - 0.04, o), lerpf(0.1, 0.0, o))
	var reach := func(t: float) -> Dictionary:
		var p: Vector3 = top_at.call(t)
		return {"hand_r": p + Vector3(0.09, 0, 0.05), "hand_l": p + Vector3(-0.09, 0, 0.05)}
	pose(ld, t_ld, 0.5, C.kneel_reach(), reach)
	pose(ld, 3.6, 0.0, C.kneel_reach(), reach)
	var crouch_ld := Body.gait(C.CROUCH, C.carry("free"))
	ld["pos"] = Vector3(0.12, 0, 0.78)
	var t_l2 := move(ld, 5.0, L_SLOT, crouch_ld, PI / 2)
	var box_top := FEED_BOX + Vector3(0, 0.2, 0)
	var feed := func(t: float) -> Dictionary:
		var gx := gun_xf(t)
		var wob := 0.02 * sin(t * 30.0) if firing(t) else 0.0
		return {"hand_l": gx * MG.FEED + Vector3(0.06, -0.03 + wob, 0), "hand_r": box_top + Vector3(0.0, 0.05, 0.0)}
	pose(ld, t_l2, 0.45, C.loader(), {"hand_r": box_top, "hand_l": box_top + Vector3(0, 0.02, 0.1)})
	pose(ld, 6.6, 0.5, C.loader(), feed)
	# Pack up: belt out, tripod folded, onto the shoulder.
	pose(ld, 11.2, 0.4, C.loader(), {"hand_r": box_top, "hand_l": box_top + Vector3(0, 0.02, 0.1)})
	ld["pos"] = L_SLOT
	var t_l3 := move(ld, 11.8, Vector3(0.12, 0, 0.78), crouch_ld, 0.0)
	pose(ld, t_l3, 0.4, C.kneel_reach(), reach)
	pose(ld, 13.6, 0.5, C.standing("tripod"))
	ld["pos"] = Vector3(0.12, 0, 0.78)
	move(ld, 14.4, Vector3(0.4, 0, 6.0), walk_tri)
	prop(MG.mesh(MG.tripod_at(0.0)), [[0.0, 0.0, "bone", [ld, B.CHEST, C.TRIPOD_ON_SHOULDER]],
		[t_ld, 0.45, "world", Transform3D(Basis(), Vector3(0, 0, 0.1))],
		[3.0, 0.0, "world", Transform3D()],
		[t_l3 + 0.6, 0.0, "world", Transform3D(Basis(), Vector3(0, 0, 0.1))],
		[13.7, 0.4, "bone", [ld, B.CHEST, C.TRIPOD_ON_SHOULDER]]],
		func(t: float) -> Mesh: return tripod_mesh(_tri_open(t)))
	# Gunner: gun in on the shoulder, lifts it onto the tripod, onto the grips.
	var gn := _man(2, "gunner")
	gn["pos"] = Vector3(-0.6, 0, 6.0)
	var walk_gun := Body.gait(Body.WALK, C.carry("gun"))
	var t_g := move(gn, 0.4, Vector3(-0.05, 0, 1.25), walk_gun, 0.0)
	pose(gn, t_g, 0.3, C.standing("gun"))
	var lifted := func(t: float) -> Dictionary:
		var gx: Transform3D = gun_node.global_transform
		return {"hand_r": gx * MG.GRIP_R, "hand_l": gx * MG.CARRY}
	var lift_spec := Rig.over(C.standing("free"), {"add": {B.SPINE: Vector3(-14, 0, 0), B.CHEST: Vector3(-8, 0, 0)},
		"pole_r": Vector3(0.6, -0.6, 0.2), "pole_l": Vector3(-0.6, -0.6, 0.2)})
	pose(gn, 4.6, 0.6, lift_spec, lifted)
	pose(gn, 5.4, 0.6, C.gunner(0.0), grips, "prev", "smooth", G_SLOT)
	pose(gn, 6.2, 0.0, C.gunner(0.0), func(t: float) -> Dictionary: return grips(t))
	var gtr := func(t: float) -> Dictionary: return grips(t)
	pose(gn, 7.0, 0.0, C.gunner(0.0), gtr)
	# During fire the body follows the traverse.
	for k in 30:
		var tk := 8.0 + 0.1 * k
		pose(gn, tk, 0.1, C.gunner(trav_fn.call(tk + 0.1), 3.0), gtr, "prev", "lin")
	pose(gn, 11.0, 0.2, C.gunner(0.0), gtr)
	pose(gn, 12.2, 0.5, lift_spec, lifted, "prev", "smooth", Vector3(-0.05, 0, 1.25))
	pose(gn, 13.0, 0.5, C.standing("gun"))
	move(gn, 14.2, Vector3(-0.3, 0, 6.5), walk_gun)
	gun_node = prop(MG.mesh(MG.gun()), [[0.0, 0.0, "bone", [gn, B.CHEST, C.GUN_ON_SHOULDER]],
		[4.6, 0.6, "world", Transform3D(Basis(), Vector3(0, MG.PIN_H + 0.3, 0.25))],
		[5.3, 0.4, "world", func(t: float) -> Transform3D: return gun_xf(t)],
		[12.2, 0.5, "world", Transform3D(Basis(), Vector3(0, MG.PIN_H + 0.3, 0.25))],
		[12.9, 0.5, "bone", [gn, B.CHEST, C.GUN_ON_SHOULDER]]])
	# Carrier: boxes up to the feed, then out to cover.
	var cr := _man(4, "carrier")
	cr["pos"] = Vector3(1.6, 0, 6.5)
	var t_c := move(cr, 0.6, Vector3(1.1, 0, 0.1), walk_box, PI / 2)
	var put := func(t: float) -> Dictionary:
		return {"hand_r": FEED_BOX + Vector3(0, 0.215, 0.05), "hand_l": FEED_BOX + Vector3(0.12, 0.215, 0.45)}
	pose(cr, t_c, 0.6, C.kneel_reach(), put)
	pose(cr, t_c + 0.9, 0.4, R.poses()["kneel"], null)
	cr["pos"] = Vector3(1.1, 0, 0.1)
	var t_c2 := move(cr, t_c + 1.4, Vector3(2.2, 0, -0.6), Body.gait(C.CROUCH, R.carry("port")), 0.3)
	pose(cr, t_c2, 0.4, R.poses()["kneel"])
	pose(cr, 12.0, 0.5, C.kneel_reach(), put)
	pose(cr, 12.9, 0.5, C.standing("boxes"), null, "prev", "smooth", Vector3(1.1, 0, 0.1), PI / 2)
	cr["pos"] = Vector3(1.1, 0, 0.1)
	move(cr, 13.6, Vector3(1.5, 0, 6.5), walk_box)
	for k in 2:
		var hb: int = [B.HAND_R, B.HAND_L][k]
		var spot: Vector3 = [FEED_BOX + Vector3(0, 0, 0.05), FEED_BOX + Vector3(0.12, 0, 0.45)][k]
		var bx := Transform3D(Basis(Vector3.UP, PI / 2), spot)
		var open := k == 0
		var pm := prop(MG.mesh(MG.ammo_box()), [[0.0, 0.0, "bone", [cr, hb, C.box_in_hand()]],
			[t_c + 0.45, 0.15, "world", bx], [12.4, 0.1, "bone", [cr, hb, C.box_in_hand()]]],
			(func(t: float) -> Variant: return MG.mesh(MG.ammo_box(t > 6.2 and t < 11.4))) if open else null)
		pm.name = "box%d" % k
	# NCO: walks up, kneels, points the gun onto the target.
	var nc := _man(11, "nco")
	nc["pos"] = Vector3(-1.4, 0, 5.0)
	var t_n := move(nc, 0.0, NCO_SLOT, Body.gait(Body.WALK, C.carry("free")), -0.2)
	pose(nc, t_n, 0.5, C.nco_point())
	var point := func(t: float) -> Dictionary:
		return {"hand_r": nc["s"].global_transform * Vector3(0.6, 1.55, -1.3)}
	pose(nc, 7.2, 0.35, C.nco_point(), point, "prev", "out")
	pose(nc, 8.6, 0.5, C.nco_point())
	pose(nc, 13.0, 0.5, C.standing("free"))
	nc["pos"] = NCO_SLOT
	move(nc, 13.8, Vector3(-1.2, 0, 6.5), Body.gait(Body.WALK, C.carry("free")))
	belt_fn = func(t: float) -> Array:
		if t < 6.4 or t > 11.6:
			return []
		var gx := gun_xf(t)
		return [gx * MG.FEED + Vector3(0.03, -0.02, 0), FEED_BOX + Vector3(0, 0.2, 0)]
	_phases = [[0.0, "Moving in"], [2.4, "Tripod down and open"], [4.6, "Gun onto the tripod"], [6.3, "Belt in"],
		[8.0, "Firing (sweeping)"], [11.0, "Pack up"], [14.0, "Moving off"]]
	_camera = func(_t: float) -> void:
		cam.fov = 42.0
		cam.transform = Transform3D(Basis(), Vector3(-3.0, 2.1, -2.9)).looking_at(Vector3(0.2, 0.5, 1.3), Vector3.UP)
	return 16.0


func _tri_open(t: float) -> float:
	if t < 3.0:
		return 0.0
	if t < 4.2:
		return Anim.ease_of((t - 3.0) / 1.2, "smooth")
	if t < 12.6:
		return 1.0
	if t < 13.6:
		return 1.0 - Anim.ease_of((t - 12.6) / 1.0, "smooth")
	return 0.0


## The team set up: gunner, loader, NCO, two covering. Returns them.
func _set_team(fire_trav: Callable) -> Dictionary:
	trav_fn = fire_trav
	prop(tripod_mesh(1.0), [[0.0, 0.0, "world", Transform3D()]])
	gun_node = prop(MG.mesh(MG.gun()), [[0.0, 0.0, "world", func(t: float) -> Transform3D: return gun_xf(t)]])
	prop(MG.mesh(MG.ammo_box(true)), [[0.0, 0.0, "world", Transform3D(Basis(Vector3.UP, PI / 2), FEED_BOX)]])
	prop(MG.mesh(MG.ammo_box()), [[0.0, 0.0, "world", Transform3D(Basis(Vector3.UP, PI / 2 + 0.2), FEED_BOX + Vector3(0.18, 0, 0.42))]])
	var gn := _man(2, "gunner")
	var ld := _man(7, "loader")
	ld["pos"] = L_SLOT
	ld["yaw"] = PI / 2
	var nc := _man(11, "nco")
	nc["pos"] = NCO_SLOT
	nc["yaw"] = -0.2
	pose(nc, 0.0, 0.0, C.nco_point())
	var c1 := _man(4, "carrier")
	c1["pos"] = Vector3(2.0, 0, -0.7)
	c1["yaw"] = 0.25
	pose(c1, 0.0, 0.0, R.poses()["prone"])
	return {"gn": gn, "ld": ld, "nc": nc, "c1": c1}


## Firing, the belt runs out, the loader changes it, the gunner cocks, firing again.
func _scene_fire() -> float:
	fire_spans = [[0.3, 3.4], [6.4, 9.6]]
	var team := _set_team(func(t: float) -> float: return 16.0 * sin(t * 1.25))
	var gn: Dictionary = team["gn"]
	gn["pos"] = G_SLOT
	var gtr := func(t: float) -> Dictionary: return grips(t)
	for k in 100:
		var tk := 0.1 * k
		pose(gn, tk, 0.1, C.gunner(trav_fn.call(tk + 0.1), 3.0), gtr, "prev" if k > 0 else null, "lin")
	# Cocking: the right hand to the side handle, back twice.
	var cock := func(t: float) -> Dictionary:
		var gx := gun_xf(t)
		var back := 0.1 * absf(sin((t - 5.6) * TAU * 1.2)) if t > 5.6 and t < 6.3 else 0.0
		return {"hand_r": gx * Vector3(0.09, 0.0, 0.12 + back), "hand_l": gx * MG.GRIP_L}
	# Replace the segments in the cocking window with the cocking hand.
	var keep: Array = []
	for sg: Dictionary in gn["segs"]:
		if float(sg["t0"]) < 5.4 or float(sg["t0"]) >= 6.4:
			keep.append(sg)
	gn["segs"] = keep
	var cs := {"type": "pose", "t0": 5.4, "d": 0.2, "spec": C.gunner(trav_fn.call(5.6)), "hands": cock, "ease": "smooth",
		"pos": G_SLOT, "yaw": 0.0, "end_spec": C.gunner(trav_fn.call(5.6)), "end_hands": cock}
	cs["from"] = C.gunner(trav_fn.call(5.4), 3.0)
	cs["from_hands"] = gtr
	var at := 0
	for i in gn["segs"].size():
		if float(gn["segs"][i]["t0"]) < 5.4:
			at = i + 1
	gn["segs"].insert(at, cs)
	# Loader: feeding, then the belt change.
	var ld: Dictionary = team["ld"]
	var box_top := FEED_BOX + Vector3(0, 0.2, 0)
	var new_box := FEED_BOX + Vector3(0.18, 0.2, 0.42)
	var feed := func(t: float) -> Dictionary:
		var gx := gun_xf(t)
		var wob := 0.02 * sin(t * 30.0) if firing(t) else 0.0
		return {"hand_l": gx * MG.FEED + Vector3(0.06, -0.03 + wob, 0), "hand_r": box_top + Vector3(0, 0.05, 0)}
	pose(ld, 0.0, 0.0, C.loader(), feed)
	pose(ld, 3.5, 0.35, C.loader(), func(t: float) -> Dictionary:
		var gx := gun_xf(t)
		return {"hand_l": gx * MG.FEED + Vector3(0.1, 0.05, 0), "hand_r": gx * MG.FEED + Vector3(0.12, -0.02, 0.05)})
	pose(ld, 3.95, 0.45, C.kneel_reach(), {"hand_r": new_box + Vector3(0, 0.03, 0), "hand_l": new_box + Vector3(-0.05, 0.03, -0.08)})
	pose(ld, 4.6, 0.5, C.loader(), func(t: float) -> Dictionary:
		var gx := gun_xf(t)
		return {"hand_r": gx * MG.FEED + Vector3(0.08, -0.02, 0.0), "hand_l": gx * MG.FEED + Vector3(-0.02, 0.06, 0.02)})
	pose(ld, 5.2, 0.25, C.loader(), func(t: float) -> Dictionary:
		var gx := gun_xf(t)
		return {"hand_r": gx * MG.FEED + Vector3(0.0, 0.0, 0.0), "hand_l": gx * MG.FEED + Vector3(-0.02, 0.06, 0.02)})
	pose(ld, 6.0, 0.4, C.loader(), func(t: float) -> Dictionary:
		var gx := gun_xf(t)
		var wob := 0.02 * sin(t * 30.0) if firing(t) else 0.0
		return {"hand_l": gx * MG.FEED + Vector3(0.06, -0.03 + wob, 0), "hand_r": new_box + Vector3(0, 0.05, 0)})
	belt_fn = func(t: float) -> Array:
		var gx := gun_xf(t)
		var f := gx * MG.FEED + Vector3(0.03, -0.02, 0)
		if t < 3.6:
			return [f, box_top]
		if t < 3.9:
			return [ld["s"].global_transform * ld["s"].skel.get_bone_global_pose(B.HAND_R) * Vector3(0, -0.06, 0), box_top]
		if t < 4.4:
			return []
		if t < 5.3:
			return [ld["s"].global_transform * ld["s"].skel.get_bone_global_pose(B.HAND_R) * Vector3(0, -0.06, 0), new_box]
		return [f, new_box]
	_phases = [[0.0, "Firing: sweeping, belt feeding"], [1.6, "Firing: steam off the jacket"], [3.4, "Belt out: belt change"],
		[5.4, "Gunner cocks the gun"], [6.4, "Firing again"]]
	_camera = func(_t: float) -> void:
		cam.fov = 38.0
		cam.transform = Transform3D(Basis(), Vector3(-1.1, 1.9, -2.7)).looking_at(Vector3(0.2, 0.45, 0.5), Vector3.UP)
	return 9.8


## An ammo run under fire, then the gunner is hit and a carrier takes the gun.
func _scene_swap() -> float:
	fire_spans = [[0.0, 4.0], [6.6, 9.8]]
	var team := _set_team(func(t: float) -> float: return 12.0 * sin(t * 1.1))
	var gn: Dictionary = team["gn"]
	gn["pos"] = G_SLOT
	var gtr := func(t: float) -> Dictionary: return grips(t)
	for k in 40:
		var tk := 0.1 * k
		pose(gn, tk, 0.1, C.gunner(trav_fn.call(tk + 0.1), 3.0), gtr, "prev" if k > 0 else null, "lin")
	var g_from := gn["s"].spec_local(C.gunner(trav_fn.call(4.0), 3.0), {}) as Dictionary
	gn["s"].position = G_SLOT
	var hands_now := grips(4.0)
	var inv: Transform3D = Transform3D(Basis(), G_SLOT).affine_inverse()
	for k in hands_now:
		g_from[k] = [-1, inv * (hands_now[k] as Vector3)]
	var lift0 := Rig.ground_lift(Rig.solve(g_from, g_from, 0.0), gn["s"].geo)
	for k in hands_now:
		g_from[k] = [-1, inv * (hands_now[k] as Vector3) - Vector3(0, lift0, 0)]
	clip(gn, 4.0, C.gunner_death(g_from))
	var ld: Dictionary = team["ld"]
	var box_top := FEED_BOX + Vector3(0, 0.2, 0)
	pose(ld, 0.0, 0.0, C.loader(), func(t: float) -> Dictionary:
		var gx := gun_xf(t)
		var wob := 0.02 * sin(t * 30.0) if firing(t) else 0.0
		return {"hand_l": gx * MG.FEED + Vector3(0.06, -0.03 + wob, 0), "hand_r": box_top + Vector3(0, 0.05, 0)})
	belt_fn = func(t: float) -> Array:
		return [gun_xf(t) * MG.FEED + Vector3(0.03, -0.02, 0), box_top]
	# Ammo run: crouched dash in with two boxes, down beside the loader, back out.
	var ar := _man(9, "carrier")
	ar["pos"] = Vector3(2.6, 0, 6.5)
	var dash_box := Body.gait(C.CROUCH, C.carry("boxes"))
	var t_a := move(ar, 0.2, Vector3(1.25, 0, 0.75), dash_box, PI / 2)
	var drop_r := Vector3(1.0, 0, 0.55)
	var drop_l := Vector3(1.05, 0, 0.95)
	pose(ar, t_a, 0.45, C.kneel_reach(), {"hand_r": drop_r + Vector3(0, 0.215, 0), "hand_l": drop_l + Vector3(0, 0.215, 0)})
	pose(ar, t_a + 0.7, 0.3, C.kneel_reach())
	ar["pos"] = Vector3(1.25, 0, 0.75)
	var t_a2 := move(ar, t_a + 1.0, Vector3(2.8, 0, 2.2), Body.gait(C.CROUCH, C.carry("free")), 0.2)
	pose(ar, t_a2, 0.4, R.poses()["kneel"])
	for k in 2:
		var hb: int = [B.HAND_R, B.HAND_L][k]
		var spot: Vector3 = [drop_r, drop_l][k]
		prop(MG.mesh(MG.ammo_box()), [[0.0, 0.0, "bone", [ar, hb, C.box_in_hand()]],
			[t_a + 0.4, 0.1, "world", Transform3D(Basis(Vector3.UP, PI / 2), spot)]])
	# The new gunner: from cover on the left, a dash to the gun, onto the grips.
	var ng := _man(13, "carrier")
	ng["pos"] = Vector3(-2.4, 0, 0.3)
	ng["yaw"] = -0.3
	pose(ng, 0.0, 0.0, R.poses()["kneel"])
	var t_n := move(ng, 4.7, Vector3(-0.15, 0, 1.0), Body.gait(C.CROUCH, R.carry("port")), 0.0)
	pose(ng, t_n, 0.5, C.gunner(0.0), gtr, "prev", "smooth", G_SLOT)
	pose(ng, t_n + 0.5, 0.0, C.gunner(0.0), gtr)
	for k in 32:
		var tk := 6.6 + 0.1 * k
		pose(ng, tk, 0.1, C.gunner(trav_fn.call(tk + 0.1), 3.0), gtr, "prev", "lin")
	_phases = [[0.0, "Ammo run under fire"], [4.0, "Gunner hit"], [4.7, "A carrier takes over the gun"], [6.6, "Firing again"]]
	_camera = func(_t: float) -> void:
		cam.fov = 44.0
		cam.transform = Transform3D(Basis(), Vector3(-3.2, 2.9, -3.4)).looking_at(Vector3(0.3, 0.4, 1.4), Vector3.UP)
	return 9.8
