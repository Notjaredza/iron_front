extends "res://tools/redcoat_clips.gd"
## Armoured trench troops, short videos (Building Chat 1, 2026-11-10), in the explosion test's world (BlastStage) like
## the red coats' videos, so musket smoke and blasts match and blasts throw the men. Needs a window:
##   Godot --path iron_front --resolution 1280x720 -s res://tools/armour_clips.gd -- [scene ...]
## Scenes: wall, rush, strikes, pistol, battle. JPEG frames go to results/units/armour_frames/<scene>/ at 30 fps;
## ffmpeg makes results/units/armour/<scene>.mp4.

const AR := preload("res://scripts/units/anim/clips_armour.gd")
const AFRAMES := "res://results/units/armour_frames/"
const AOUT := "res://results/units/armour/"
const ASCENES: Array[String] = ["wall", "rush", "strikes", "pistol", "battle"]

var ar_lib: Dictionary


func _run() -> void:
	lib = Redcoat.library()
	ar_lib = Armoured.library()
	stage = BlastStage.new()
	stage.manual = true
	root.add_child(stage)
	ui = CanvasLayer.new()
	root.add_child(ui)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(20, 14)
	ui.add_child(title)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AOUT))
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else ASCENES):
		await _arecord(sc)
	print("ARMOUR CLIPS OK")
	quit()


## An armoured man. segs: [[t0, clip name]] from this man's own set (names without the role, e.g. "wall_step").
func _aman(role: String, seed_value: int, at: Vector3, yaw_deg: float, segs: Array, weapon := "", thrown := true) -> Dictionary:
	var m := Armoured.new()
	m.weapon_override = weapon
	m.setup(seed_value, 0, role)
	stage.add_child(m)
	at.y = stage.ground.height(at.x, at.z)
	m.position = at
	m.rotation.y = deg_to_rad(yaw_deg)
	if thrown:
		m.set_meta("pose", "wall" if role == "shield" else "guard")
		stage.men.append(m)
	var full: Array = []
	for s: Array in segs:
		full.append([s[0], "%s_%s" % [role, s[1]]])
	var a := {"man": m, "segs": full, "pos0": at, "yaw": deg_to_rad(yaw_deg), "fired": {}, "lib": ar_lib}
	actors.append(a)
	return a


func _alib(a: Dictionary) -> Dictionary:
	return a.get("lib", lib)


func _walked(a: Dictionary, t: float) -> float:
	var segs: Array = a["segs"]
	var L := _alib(a)
	var d := 0.0
	for i in segs.size():
		var t0: float = segs[i][0]
		var t1: float = segs[i + 1][0] if i < segs.size() - 1 else INF
		if t <= t0:
			break
		var c: Dictionary = L[segs[i][1]]
		d += float(c.get("speed", 0.0)) * (minf(t, t1) - t0)
	return d


func _eval(a: Dictionary, t: float) -> void:
	if not a.has("lib"):
		super._eval(a, t)
		return
	var man: Armoured = a["man"]
	for th in stage.throws:
		if th.man == man:
			return
	if man.get_meta("thrown_done", false):
		return
	var L := _alib(a)
	var i := _seg_at(a, t)
	var segs: Array = a["segs"]
	var c: Dictionary = L[segs[i][1]]
	var lt := _local(a, i, t)
	var fwd := Basis(Vector3.UP, float(a["yaw"])) * Vector3(0, 0, -1)
	var p: Vector3 = a["pos0"] + fwd * _walked(a, t)
	p.y = stage.ground.height(p.x, p.z)
	man.position = p
	var g := Anim.sample(c, lt, man.geo)
	if i > 0 and lt < FADE:
		var pc: Dictionary = L[segs[i - 1][1]]
		var pl := float(segs[i][0]) - float(segs[i - 1][0])
		var gp := Anim.sample(pc, pl if pc.get("loop", false) else minf(pl, float(pc["len"])), man.geo)
		g = Rig.blend_globals(gp, g, smoothstep(0.0, 1.0, lt / FADE))
	man.show_globals(g)
	man.set_props(Armoured.prop_state(c, lt))
	for e: Array in c.get("events", []):
		var key := "%d:%s:%.2f" % [i, e[1], float(e[0])]
		if a["fired"].has(key) or lt < float(e[0]):
			continue
		a["fired"][key] = true
		if e[1] == "shot":
			var x := man.skel.global_transform * man.skel.get_bone_global_pose(B.RIFLE)
			stage.fire("pan", x * Vector3(0, 0.06, -0.16), randi(), -1, -x.basis.z.normalized(), false)


func _arecord(sc: String) -> void:
	_reset()
	seed(91)
	var length: float = call("_scene_" + sc)
	var dir := ProjectSettings.globalize_path(AFRAMES + sc + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(ProjectSettings.globalize_path(AFRAMES + ".gdignore"), FileAccess.WRITE).store_string("")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	var frames := int(length * FPS)
	var t0 := Time.get_ticks_msec()
	for f in frames:
		var t := float(f) / FPS
		for bl: Array in blasts:
			if float(bl[0]) <= t and not bl.has("done"):
				bl.append("done")
				stage.fire(bl[1], bl[2], bl[3])
		for a: Dictionary in actors:
			_eval(a, t)
		var cm: Array = cam_fn.call(t)
		stage.aim(cm[0], cm[1], cm[2], cm[3])
		stage.step(t)
		stage.sun.directional_shadow_max_distance = shadow
		for th in stage.throws:
			th.man.set_meta("thrown_done", true)
		var txt := ""
		for ph: Array in phases:
			if float(ph[0]) <= t:
				txt = ph[1]
		title.text = txt
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(dir + "f%04d.jpg" % f, 0.9)
	var mp4 := ProjectSettings.globalize_path(AOUT + sc + ".mp4")
	var out := []
	var code := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", "30", "-i", dir + "f%04d.jpg",
		"-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", mp4], out, true)
	print("frames %s %d in %d ms, ffmpeg %d" % [sc, frames, Time.get_ticks_msec() - t0, code])


func _alen(role: String, n: String) -> float:
	return float(ar_lib["%s_%s" % [role, n]]["len"])


# ---------------------------------------------------------------- scenes

const WX: Array[float] = [-2.4, -1.2, 0.0, 1.2, 2.4]


## The wall: shields come up and lock, the step-and-drag advance, the club men behind strike over the top.
func _scene_wall() -> float:
	var t_go := 0.4 + _alen("shield", "wall_lock")
	for i in 5:
		_aman("shield", 10 + i, Vector3(WX[i], 0, 0), 0.0, [[0.0, "hold_stand"], [0.4 + 0.05 * i, "wall_lock"],
			[t_go, "wall_step"], [t_go + 6.0, "hold_wall"]])
	var cx: Array[float] = [-1.8, 0.0, 1.8]
	var wpn: Array[String] = ["club", "mace", "spade"]
	for i in 3:
		var segs: Array = [[0.0, "hold_stand"], [0.5, "hold_wall"], [t_go, "wall_step"], [t_go + 6.0, "hold_wall"]]
		for k in 3:
			segs.append([t_go + 6.2 + 1.3 * k + 0.25 * i, "strike"])
		segs.append([t_go + 6.2 + 3.9 + 0.5, "hold_wall"])
		_aman("club", 20 + i, Vector3(cx[i], 0, 1.15), 0.0, segs, wpn[i])
	phases = [[0.0, "Armoured troops: shields up, lock the wall"], [t_go, "The wall advances: step and drag"],
		[t_go + 6.1, "Club men strike over the shields"]]
	shadow = 40.0
	var v := 0.55
	cam_fn = func(t: float) -> Array:
		var z := -v * clampf(t - t_go, 0.0, 6.0)
		return [Vector3(0.0, 1.0, z - 0.6), 2.5 + 0.012 * t, -0.14, 9.0 - 0.15 * t]
	return t_go + 6.2 + 4.6


## The wall breaks: two steps, then the rush, and the blows at the end.
func _scene_rush() -> float:
	var t_r := 2.4
	var run := 2.6
	for i in 5:
		var segs: Array = [[0.0, "wall_step"], [t_r + 0.06 * i, "rush"], [t_r + run + 0.06 * i, "bash" if i % 2 == 0 else "strike"],
			[t_r + run + 1.3 + 0.06 * i, "hold_wall"]]
		_aman("shield", 30 + i, Vector3(WX[i], 0, 0), 0.0, segs)
	var cx: Array[float] = [-1.8, 0.0, 1.8]
	var wpn: Array[String] = ["mace", "club", "spade"]
	for i in 3:
		_aman("club", 40 + i, Vector3(cx[i], 0, 1.15), 0.0, [[0.0, "wall_step"], [t_r + 0.1, "rush"],
			[t_r + run + 0.1, "smash" if i != 1 else "swing"], [t_r + run + 1.5, "hold_guard"]], wpn[i])
	phases = [[0.0, "The wall advances"], [t_r, "Break: the rush!"], [t_r + run, "Into them: shield bash, club blows"]]
	shadow = 50.0
	cam_fn = func(t: float) -> Array:
		var z := -0.55 * minf(t, t_r) - 3.1 * clampf(t - t_r, 0.0, run)
		return [Vector3(0.0, 1.0, z - 1.2), 2.5, -0.12, 10.0]
	return t_r + run + 2.2


## The blows side by side: overhead smash, side swing, shield bash, block.
func _scene_strikes() -> float:
	var who: Array = [["club", "smash", "mace"], ["club", "swing", "club"], ["shield", "bash", ""], ["shield", "block", ""]]
	for i in 4:
		var w: Array = who[i]
		var hold: String = "hold_guard" if w[0] == "club" else "hold_wall"
		var L := _alen(w[0], w[1])
		_aman(w[0], 50 + i, Vector3(-2.7 + 1.8 * i, 0, 0), 0.0, [[0.0, hold], [0.6, w[1]], [0.6 + L + 0.3, hold],
			[0.6 + L + 0.9, w[1]], [0.6 + 2.0 * L + 1.2, hold]], w[2])
	phases = [[0.0, "Overhead smash (mace) / side swing (club) / shield bash / taking a blow on the shield"]]
	shadow = 40.0
	cam_fn = func(t: float) -> Array:
		return [Vector3(0.0, 1.0, -0.3), PI + 0.3 - 0.02 * t, -0.08, 6.2]
	return 6.2


## Club to the belt, pistol out: over the shield, and the club man's.
func _scene_pistol() -> float:
	_aman("shield", 60, Vector3(-0.8, 0, 0), 0.0, [[0.0, "hold_wall"], [0.6, "pistol"], [0.6 + _alen("shield", "pistol"), "hold_pistol"]])
	_aman("club", 61, Vector3(0.8, 0, 0.3), 0.0, [[0.0, "hold_guard"], [0.9, "pistol"], [0.9 + _alen("club", "pistol"), "hold_pistol"]], "spade")
	phases = [[0.0, "Pistols: over the shield; the club man's sidearm"]]
	shadow = 30.0
	cam_fn = func(t: float) -> Array:
		return [Vector3(0.0, 1.25, -0.2), PI - 0.9 + 0.03 * t, -0.06, 4.6]
	return 4.6


## Against the red coats: a volley rattles off the shields, a cannon shell throws one of ours, the wall closes,
## the red coats charge into it; blocks, blows over the top, the bash; most of the red coats fall, two of ours too.
func _scene_battle() -> float:
	var t_lock := 0.3
	var t_step := t_lock + _alen("shield", "wall_lock")
	var walk := 7.0
	var t_meet := t_step + walk
	# Ours.
	for i in 5:
		var segs: Array = [[0.0, "hold_stand"], [t_lock, "wall_lock"], [t_step, "wall_step"], [t_meet, "hold_wall"]]
		match i:
			0:
				segs = [[0.0, "hold_stand"], [t_lock, "wall_lock"], [t_step, "wall_step"]]  # thrown by the shell
			1:
				segs.append_array([[t_meet + 0.5, "block"], [t_meet + 1.7, "bash"], [t_meet + 3.0, "hold_wall"]])
			2:
				segs.append_array([[t_meet + 0.4, "block"], [t_meet + 1.6, "hold_wall"], [t_meet + 2.4, "pistol"],
					[t_meet + 2.4 + _alen("shield", "pistol"), "hold_pistol"]])
			3:
				segs.append_array([[t_meet + 0.6, "block"], [t_meet + 1.8, "death_forward"]])
			4:
				segs.append_array([[t_meet + 0.5, "bash"], [t_meet + 1.8, "hold_wall"]])
		_aman("shield", 70 + i, Vector3(WX[i], 0, 0), 0.0, segs, "", i == 0)
	var cx: Array[float] = [-1.8, 0.0, 1.8]
	var wpn: Array[String] = ["mace", "club", "spade"]
	for i in 3:
		var segs: Array = [[0.0, "hold_wall"], [t_step, "wall_step"], [t_meet, "hold_wall"], [t_meet + 0.7 + 0.2 * i, "strike"],
			[t_meet + 2.0 + 0.2 * i, "strike"], [t_meet + 3.3 + 0.2 * i, "hold_wall"]]
		_aman("club", 80 + i, Vector3(cx[i], 0, 1.15), 0.0, segs, wpn[i], false)
	# The red coats: a volley at 30 m, then they charge to meet the wall.
	var wall_z := -0.55 * walk
	var rz := wall_z - 12.0
	var vs := _len("volley_stand")
	var ch: Dictionary = lib["charge_run"]
	var cv := float(ch.get("speed", 3.0))
	var t_run := t_meet - 10.8 / cv
	for i in 7:
		var x := -3.0 + 1.0 * i
		var segs: Array = [[0.0, "hold_shoulder"], [0.6, "volley_stand"], [0.6 + vs, "hold_ready"], [t_run - 0.7, "to_charge"],
			[t_run, "charge_run"], [t_meet, "thrust"]]
		var fall_at := t_meet + 0.6 + 0.35 * i
		match i:
			0, 2, 5:
				segs.append([fall_at, "death_back"])
			3:
				segs.append([t_meet + 1.9, "death_forward"])
			_:
				segs.append([t_meet + 1.4, "hold_charge"])
				segs.append([t_meet + 3.6, "death_back"])
		_man("musketeer", 90 + i, Vector3(x, 0, rz), 180.0, segs)
	blasts = [[2.6, 1, Vector3(WX[0] - 1.6, 0, -0.55 * (2.6 - t_step) - 1.0), 17]]
	phases = [[0.0, "Armoured troops against a red coat line"], [0.6, "The red coats fire a volley into the wall"],
		[2.5, "A cannon shell: one of ours is thrown"], [t_run - 0.7, "Charge bayonets!"],
		[t_meet, "Bayonets on the shields; blows over the top"], [t_meet + 2.4, "Shield bash, a pistol over the shield"]]
	shadow = 70.0
	cam_fn = func(t: float) -> Array:
		var z := -0.55 * clampf(t - t_step, 0.0, walk)
		if t < t_meet - 1.0:
			return [Vector3(0.0, 1.0, z - 5.0), -1.62, -0.16, 16.0 - 0.35 * t]
		return [Vector3(0.0, 1.0, wall_z - 0.8), -1.55 + 0.03 * (t - t_meet), -0.14, 8.5]
	return t_meet + 5.0
