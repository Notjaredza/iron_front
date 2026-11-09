extends SceneTree
## Animation round 1 pictures and videos (Question Chat, 2026-11-09).
## Run with a window (needs the GPU):
##   Godot --path iron_front --resolution 1280x720 -s res://tools/anim_clips.gd -- sheets [clip ...]
##   Godot --path iron_front --resolution 1280x720 -s res://tools/anim_clips.gd -- video [group ...]
## sheets: results/units/anim/sheet_<clip>.png (8 moments, side and front views).
## video: JPEG frames in results/units/anim_frames/<group>/ at 30 fps; ffmpeg makes the mp4s.
## Also "-- check": headless bake of every clip into an AnimationLibrary, played back
## on a fresh soldier through an AnimationPlayer and compared with the solver.

const Anim := preload("res://scripts/units/anim/anim.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
const B := preload("res://scripts/units/soldier_builder.gd")
const OUT := "res://results/units/anim/"
const FRAMES := "res://results/units/anim_frames/"
const FPS := 30.0
const GROUPS: Array[String] = ["walk_run", "fire_reload", "pose_changes", "hit_death"]

var lib: Dictionary
var stage: Node3D
var cam: Camera3D
var ui: CanvasLayer
var title: Label
var flash_mat: StandardMaterial3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	lib = R.library()
	var args := OS.get_cmdline_user_args()
	var mode := "sheets" if args.is_empty() else args[0]
	var names: Array = args.slice(1)
	if mode == "check":
		_check()
		quit()
		return
	_setup_world()
	if mode == "sheets":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		for n in (names if not names.is_empty() else lib.keys()):
			await _sheet(n)
	else:
		for gname in (names if not names.is_empty() else GROUPS):
			await _video(gname)
	print("ANIM CLIPS OK")
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
	# Small marks every metre along the walk path so sliding feet would show.
	var mk := StandardMaterial3D.new()
	mk.albedo_color = Color(0.48, 0.44, 0.33)
	for i in 61:
		for row in [-0.6, 0.6]:
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 0.01, 0.05)
			bm.material = mk
			m.mesh = bm
			m.position = Vector3(row, 0.005, 2.0 - float(i))
			root.add_child(m)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	stage = Node3D.new()
	root.add_child(stage)
	ui = CanvasLayer.new()
	root.add_child(ui)
	title = _label(26)
	title.position = Vector2(24, 18)
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.78, 0.35)


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	ui.add_child(l)
	return l


func _clear() -> void:
	for c in stage.get_children():
		c.free()
	for c in ui.get_children():
		if c != title:
			c.free()
	title.text = ""


func _man(seed_value: int, at: Vector3, yaw_deg: float) -> Soldier:
	var s := Soldier.new().setup(seed_value, 0)
	s.position = at
	s.rotation.y = deg_to_rad(yaw_deg)
	stage.add_child(s)
	return s


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


# ---------------------------------------------------------------- sheets

func _sheet(clip_name: String) -> void:
	_clear()
	var clip: Dictionary = lib[clip_name]
	var s := _man(1, Vector3.ZERO, 0.0)
	var length: float = clip["len"]
	var parts: Array[Image] = []
	var w := root.get_texture().get_width()
	var h := root.get_texture().get_height()
	var low: bool = clip_name.contains("prone") or clip_name.contains("death")
	for view in 2:
		for i in 8:
			var t := length * float(i) / 7.0 if not clip.get("loop", false) else length * float(i) / 8.0
			s.show_clip(clip, t)
			var at := Vector3(0, 0.45 if low else 0.9, -0.4 if low else 0.0)
			var from := Vector3(4.6, 1.0, -0.4) if view == 0 else Vector3(-2.2, 1.3, -4.2)
			_look(from, at, 34.0 if low else 30.0)
			var img: Image = await _grab()
			parts.append(img.get_region(Rect2i(w / 2 - 170, 0, 340, h)))
	var pw := parts[0].get_width()
	var ph := parts[0].get_height()
	var out := Image.create(pw * 8, ph * 2, false, Image.FORMAT_RGB8)
	for i in parts.size():
		out.blit_rect(parts[i], Rect2i(0, 0, pw, ph), Vector2i((i % 8) * pw, (i / 8) * ph))
	out.save_png(ProjectSettings.globalize_path(OUT + "sheet_%s.png" % clip_name))
	print("saved sheet ", clip_name)


# ---------------------------------------------------------------- videos

## A timeline: a list of [clip name or "hold:<pose>", duration or -1, speed].
func _seq_globals(s: Soldier, seq: Array, t: float, fade := 0.0) -> Array[Transform3D]:
	var start := 0.0
	var prev: Variant = null
	for i in seq.size():
		var item: Array = seq[i]
		var clip := _item_clip(item)
		var speed: float = item[2] if item.size() > 2 else 1.0
		var dur: float = item[1] if float(item[1]) > 0.0 else float(clip["len"]) / speed
		if t < start + dur or i == seq.size() - 1:
			var lt := (t - start) * speed
			var g := Anim.sample(clip, lt, s.geo)
			if fade > 0.0 and prev != null and t - start < fade:
				var pg := Anim.sample(prev[0], prev[1], s.geo)
				return Rig.blend_globals(pg, g, (t - start) / fade)
			return g
		prev = [clip, (dur) * speed]
		start += dur
	return []


func _item_clip(item: Array) -> Dictionary:
	var n: String = item[0]
	if n.begins_with("hold:"):
		var p := Soldier.pose_spec(n.substr(5))
		return {"name": n, "len": 1.0, "keys": [[0.0, p]]}
	return lib[n]


func _seq_len(seq: Array) -> float:
	var total := 0.0
	for item: Array in seq:
		var clip := _item_clip(item)
		var speed: float = item[2] if item.size() > 2 else 1.0
		total += float(item[1]) if float(item[1]) > 0.0 else float(clip["len"]) / speed
	return total


## The shot times of a timeline (for muzzle flashes).
func _seq_events(seq: Array, kind: String) -> Array[float]:
	var out: Array[float] = []
	var start := 0.0
	for item: Array in seq:
		var clip := _item_clip(item)
		var speed: float = item[2] if item.size() > 2 else 1.0
		var dur: float = item[1] if float(item[1]) > 0.0 else float(clip["len"]) / speed
		for e: Array in clip.get("events", []):
			if e[1] == kind:
				out.append(start + float(e[0]) / speed)
		start += dur
	return out


func _flash() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.09
	sp.height = 0.26
	sp.material = flash_mat
	m.mesh = sp
	m.visible = false
	stage.add_child(m)
	return m


func _video(gname: String) -> void:
	_clear()
	var dir := ProjectSettings.globalize_path(FRAMES + gname + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	FileAccess.open(ProjectSettings.globalize_path(FRAMES + ".gdignore"), FileAccess.WRITE).store_string("")
	var men: Array[Soldier] = []
	var seqs: Array = []
	var tags: Array[Label] = []
	var fade := 0.0
	var length := 0.0
	var moving := false
	var phases: Array = []  # [start time, title]
	match gname:
		"walk_run":
			men.append(_man(1, Vector3(0, 0, 2.0), 0.0))
			seqs.append([["walk", 4.0], ["run", 3.84], ["walk", 2.5]])
			fade = 0.25
			moving = true
			phases = [[0.0, "Walk  (1.35 m/s)"], [4.0, "Run  (3.7 m/s)"], [7.84, "Walk"]]
		"fire_reload":
			var plan := [["fire_stand", -1], ["fire_stand", -1], ["reload_stand", -1], ["fire_stand", -1]]
			men.append(_man(1, Vector3(-1.4, 0, 0), 0.0))
			men.append(_man(4, Vector3(0.0, 0, 0), 0.0))
			men.append(_man(6, Vector3(1.4, 0, -0.6), 0.0))
			seqs.append(plan)
			seqs.append(plan.map(func(x: Array) -> Array: return [x[0].replace("stand", "kneel"), x[1]]))
			seqs.append(plan.map(func(x: Array) -> Array: return [x[0].replace("stand", "prone"), x[1]]))
			for i in 3:
				var l := _label(20)
				l.text = ["Standing", "Kneeling", "Prone"][i]
				tags.append(l)
			phases = [[0.0, "Fire (bolt worked)"], [2.9, "Reload (stripper clip)"], [5.8, "Fire"]]
		"pose_changes":
			var plan := [["hold:ready", 0.6], ["stand_to_kneel", -1], ["hold:kneel", 0.5], ["kneel_to_stand", -1],
				["hold:ready", 0.5], ["stand_to_prone", -1], ["hold:prone", 0.6], ["prone_to_stand", -1], ["hold:ready", 0.6]]
			men.append(_man(1, Vector3(-0.9, 0, 0), 0.0))
			men.append(_man(3, Vector3(2.3, 0, 0.6), 90.0))
			seqs.append(plan)
			seqs.append(plan)
			var st := 0.0
			for item: Array in plan:
				var nm: String = item[0]
				if not nm.begins_with("hold"):
					phases.append([st, nm.replace("_", " ").capitalize()])
				st += float(item[1]) if float(item[1]) > 0.0 else float(lib[nm]["len"])
			phases.push_front([0.0, "Ready"])
		"hit_death":
			men.append(_man(1, Vector3(-1.6, 0, 0), 0.0))
			men.append(_man(4, Vector3(0.0, 0, 0), 0.0))
			men.append(_man(6, Vector3(1.6, 0, -0.6), 0.0))
			for sp in [1.0, 0.5]:
				pass
			seqs.append([["hold:aim", 0.4], ["hit", -1], ["hold:aim", 0.6], ["hit", -1], ["hold:aim", 0.9],
				["hold:aim", 0.4], ["hit", -1, 0.5], ["hold:aim", 0.6], ["hit", -1, 0.5], ["hold:aim", 0.3]])
			seqs.append([["hold:aim", 0.6], ["death_back", -1], ["hold:aim", 0.4], ["death_back", -1, 0.5], ["hold:aim", 0.2]])
			seqs.append([["hold:aim", 0.9], ["death_forward", -1], ["hold:aim", 0.2], ["death_forward", -1, 0.5], ["hold:aim", 0.1]])
			for i in 3:
				var l := _label(20)
				l.text = ["Hit (flinch)", "Death: thrown back", "Death: crumples"][i]
				tags.append(l)
			phases = [[0.0, "Hit and death"], [3.6, "Same again at half speed"]]
	for sq in seqs:
		length = maxf(length, _seq_len(sq))
	if gname == "hit_death":
		phases = [[0.0, "Hit and death"], [_seq_len(seqs[1].slice(0, 3)), "Same again at half speed"]]
	var flashes: Array[MeshInstance3D] = []
	var shots: Array = []
	for i in men.size():
		flashes.append(_flash())
		shots.append(_seq_events(seqs[i], "shot"))
	var frames := int(length * FPS)
	var walked := 0.0
	var start_z := men[0].position.z
	var speed_at := func(t: float) -> float:
		var seq: Array = seqs[0]
		var st := 0.0
		for item: Array in seq:
			var d := float(item[1])
			if t < st + d:
				return float(lib[item[0]].get("speed", 0.0))
			st += d
		return 0.0
	for f in frames:
		var t := float(f) / FPS
		for i in men.size():
			var g := _seq_globals(men[i], seqs[i], t, fade)
			men[i].show_globals(g)
			var lit := false
			for st: float in shots[i]:
				if t >= st and t < st + 0.067:
					lit = true
			flashes[i].visible = lit
			if lit:
				var muzzle: Transform3D = men[i].global_transform * g[B.RIFLE]
				flashes[i].global_position = muzzle * (Rig.MUZZLE + Vector3(0, 0, -0.1))
				flashes[i].global_basis = muzzle.basis
		if moving:
			walked += speed_at.call(t) / FPS
			men[0].position.z = start_z - walked
			var p := men[0].position
			_look(p + Vector3(4.2, 1.5, -2.2), p + Vector3(0, 0.85, -0.4), 34.0)
		elif gname == "pose_changes":
			_look(Vector3(2.6, 1.9, -5.6), Vector3(0.7, 0.5, 0.0), 38.0)
		else:
			if gname == "hit_death":
				_look(Vector3(3.0, 2.4, -7.2), Vector3(0, 0.5, -0.4), 38.0)
			else:
				_look(Vector3(2.6, 1.6, -5.4), Vector3(0, 0.75, 0.0), 36.0)
		for i in tags.size():
			var sp := cam.unproject_position(men[i].global_position + Vector3(0, 2.15, 0))
			tags[i].position = sp - Vector2(tags[i].size.x * 0.5, 0)
		for ph: Array in phases:
			if t >= float(ph[0]):
				title.text = ph[1]
		var img: Image = await _grab()
		img.save_jpg(dir + "f%04d.jpg" % f, 0.92)
	print("frames ", gname, " ", frames)


# ---------------------------------------------------------------- check

## Bakes every clip, plays it on a fresh soldier through an AnimationPlayer and
## checks the bones land where the solver puts them.
func _check() -> void:
	var s := Soldier.new().setup(2, 0)
	root.add_child(s)
	var al := AnimationLibrary.new()
	for n in lib:
		al.add_animation(n, Anim.bake(lib[n], s.geo))
	var ap := AnimationPlayer.new()
	s.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("rifleman", al)
	var worst := 0.0
	for n in lib:
		var clip: Dictionary = lib[n]
		for k in 5:
			var t := roundf(float(clip["len"]) * (float(k) + 0.37) / 5.0 * 30.0) / 30.0
			ap.play("rifleman/" + n)
			ap.seek(t, true)
			var g := Anim.sample(clip, t, s.geo)
			for i in B.REST.size():
				var d := s.skel.get_bone_global_pose(i).origin.distance_to(g[i].origin)
				worst = maxf(worst, d)
	print("ANIM CHECK clips=%d worst_bone_gap=%.4f m" % [lib.size(), worst])
	print("ANIM CHECK ", "OK" if worst < 0.03 else "FAIL")
