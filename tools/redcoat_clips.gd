extends SceneTree
## Red jackets round 1 videos (Building Chat 1, 2026-11-10), in the explosion test's world (BlastStage), so the
## musket smoke is the same faceted billows and blasts throw the men. Needs a window:
##   Godot --path iron_front --resolution 1280x720 -s res://tools/redcoat_clips.gd -- [scene ...]
## Scenes: march, volley, reload, charge, deaths. JPEG frames go to results/units/redcoat_frames/<scene>/ at 30 fps;
## ffmpeg makes results/units/redcoats/<scene>.mp4.

const M := preload("res://scripts/units/anim/clips_musket.gd")
const RB := preload("res://scripts/units/redcoat_builder.gd")
const Anim := preload("res://scripts/units/anim/anim.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const B := preload("res://scripts/units/soldier_builder.gd")
const FRAMES := "res://results/units/redcoat_frames/"
const FPS := 30.0
const FADE := 0.22
const SCENES: Array[String] = ["march", "volley", "reload", "charge", "deaths"]

var stage: BlastStage
var ui: CanvasLayer
var title: Label
var lib: Dictionary
var actors: Array = []        # {man, segs: [[t0, clip name]], pos0, yaw, fired: {}}
var phases: Array = []        # [t, text]
var cam_fn: Callable          # t -> [target, yaw, pitch, dist]
var blasts: Array = []        # [t, what, at, seed]
var shadow := 40.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	lib = Redcoat.library()
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
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else SCENES):
		await _record(sc)
	print("REDCOAT CLIPS OK")
	quit()


func _reset() -> void:
	stage.clear_blasts()
	stage.ground.clear()
	stage.clear_men()
	for a: Dictionary in actors:
		if is_instance_valid(a["man"]):
			(a["man"] as Node).queue_free()
	actors.clear()
	phases.clear()
	blasts.clear()
	stage.set_night(false)
	stage.step(0.0)


func _man(role: String, seed_value: int, at: Vector3, yaw_deg: float, segs: Array, thrown := false) -> Dictionary:
	var r := Redcoat.new()
	r.setup(seed_value, 0, role)
	stage.add_child(r)
	at.y = stage.ground.height(at.x, at.z)
	r.position = at
	r.rotation.y = deg_to_rad(yaw_deg)
	if thrown:
		r.set_meta("pose", "stand")
		stage.men.append(r)
	var a := {"man": r, "segs": segs, "pos0": at, "yaw": deg_to_rad(yaw_deg), "fired": {}}
	actors.append(a)
	return a


## The clip a role plays for a shared move.
func cn(role: String, base: String) -> String:
	return M.role_clip(role, base) if lib.has(M.role_clip(role, base)) else base


func _seg_at(a: Dictionary, t: float) -> int:
	var segs: Array = a["segs"]
	var i := 0
	while i < segs.size() - 1 and float(segs[i + 1][0]) <= t:
		i += 1
	return i


## Distance walked by time t (gait clips move at their speed).
func _walked(a: Dictionary, t: float) -> float:
	var segs: Array = a["segs"]
	var d := 0.0
	for i in segs.size():
		var t0: float = segs[i][0]
		var t1: float = segs[i + 1][0] if i < segs.size() - 1 else INF
		if t <= t0:
			break
		var c: Dictionary = lib[segs[i][1]]
		d += float(c.get("speed", 0.0)) * (minf(t, t1) - t0)
	return d


func _local(a: Dictionary, i: int, t: float) -> float:
	return t - float(a["segs"][i][0])


func _eval(a: Dictionary, t: float) -> void:
	var man: Redcoat = a["man"]
	for th in stage.throws:
		if th.man == man:
			return
	if man.get_meta("thrown_done", false):
		return
	var i := _seg_at(a, t)
	var segs: Array = a["segs"]
	var c: Dictionary = lib[segs[i][1]]
	var lt := _local(a, i, t)
	var fwd := Basis(Vector3.UP, float(a["yaw"])) * Vector3(0, 0, -1)
	var p: Vector3 = a["pos0"] + fwd * _walked(a, t)
	p.y = stage.ground.height(p.x, p.z)
	man.position = p
	var g := Anim.sample(c, lt, man.geo)
	if i > 0 and lt < FADE:
		var pc: Dictionary = lib[segs[i - 1][1]]
		var pl := float(segs[i][0]) - float(segs[i - 1][0])
		var gp := Anim.sample(pc, pl if pc.get("loop", false) else minf(pl, float(pc["len"])), man.geo)
		g = Rig.blend_globals(gp, g, smoothstep(0.0, 1.0, lt / FADE))
	man.show_globals(g)
	man.set_props(Redcoat.prop_state(c, lt))
	man.set_time(t)
	# Events: the pan flash and the shot.
	for e: Array in c.get("events", []):
		var key := "%d:%s:%.2f" % [i, e[1], float(e[0])]
		if a["fired"].has(key) or lt < float(e[0]):
			continue
		a["fired"][key] = true
		var x := man.skel.global_transform * man.skel.get_bone_global_pose(B.RIFLE)
		match e[1]:
			"pan":
				stage.fire("pan", x * RB.PAN, randi(), -1, Vector3.UP, false)
			"shot":
				stage.fire("musket", x * RB.MUZZLE, randi(), -1, -x.basis.z.normalized(), false)


func _record(sc: String) -> void:
	_reset()
	seed(77)
	var length: float = call("_scene_" + sc)
	var dir := ProjectSettings.globalize_path(FRAMES + sc + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(ProjectSettings.globalize_path(FRAMES + ".gdignore"), FileAccess.WRITE).store_string("")
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
	print("frames %s %d in %d ms" % [sc, frames, Time.get_ticks_msec() - t0])


func _len(n: String) -> float:
	return float(lib[n]["len"])


# ---------------------------------------------------------------- scenes

## A company marching at the camera: two ranks of shouldered muskets, the officer on the right, the ensign and the
## drummer behind the middle beating the step.
func _scene_march() -> float:
	for rank in 2:
		for i in 6:
			_man("musketeer", 10 + rank * 10 + i, Vector3(-2.75 + 1.1 * i, 0, 1.2 * rank), 0.0, [[0.0, "march"]])
	_man("officer", 3, Vector3(4.2, 0, -0.6), 0.0, [[0.0, "officer_march"]])
	_man("ensign", 4, Vector3(-0.2, 0, 3.0), 0.0, [[0.0, "ensign_march"]])
	_man("drummer", 5, Vector3(1.2, 0, 3.0), 0.0, [[0.0, "drummer_march"]])
	phases = [[0.0, "Red jackets: the march (shouldered arms, the drum beating the step)"]]
	shadow = 60.0
	cam_fn = func(t: float) -> Array:
		var z := -1.15 * t
		return [Vector3(0.6, 1.2, z - 1.0), PI - 0.5 + t * 0.05, -0.08, 9.5 - t * 0.15]
	return 11.0


## Two ranks: make ready, the front rank kneeling, present, the officer's sword falls: FIRE. Then the long reload.
func _scene_volley() -> float:
	var t_rear := 4.6
	for rank in 2:
		for i in 6:
			var segs: Array
			if rank == 0:
				segs = [[0.0, "volley_kneel"], [_len("volley_kneel"), "kneel_to_stand"],
					[_len("volley_kneel") + _len("kneel_to_stand"), "reload"]]
			else:
				segs = [[0.0, "march"], [0.001, "volley_stand"], [_len("volley_stand"), "reload"]]
				segs = [[0.0, "hold_shoulder"], [t_rear - 0.0, "volley_stand"], [t_rear + _len("volley_stand"), "reload"]]
			_man("musketeer", 30 + rank * 10 + i, Vector3(-2.75 + 1.1 * i, 0, 1.15 * rank), 0.0, segs)
	_man("officer", 3, Vector3(4.3, 0, 0.4), -20.0, [[0.0, "officer_fire"], [4.4, "officer_stand"],
		[t_rear + 0.05, "officer_fire"]])
	_man("drummer", 5, Vector3(1.0, 0, 3.4), 0.0, [[0.0, "drummer_roll"], [2.4, "drummer_hold"]])
	_man("ensign", 4, Vector3(-0.4, 0, 3.4), 0.0, [[0.0, "ensign_hold"]])
	phases = [[0.0, "Front rank: make ready (kneeling) ... present"], [2.9, "FIRE!"],
		[t_rear - 0.2, "Rear rank: make ready ... present"], [t_rear + 3.0, "FIRE!"], [t_rear + 4.5, "Load! (both ranks)"]]
	shadow = 50.0
	cam_fn = func(t: float) -> Array:
		return [Vector3(0.3, 1.0, 0.3), -1.95 + t * 0.012, -0.1, 8.5]
	return 28.0


## One musketeer close: fire, then the whole reload from the side (half cock, open the pan, bite, prime, shut,
## cast about, pour, draw the rammer, ram, return it, make ready), and present again.
func _scene_reload() -> float:
	var r := _len("reload")
	_man("musketeer", 7, Vector3.ZERO, 0.0, [[0.0, "hold_shoulder"], [0.6, "volley_stand"], [0.6 + _len("volley_stand"), "reload"],
		[0.6 + _len("volley_stand") + r, "hold_ready"]])
	var t1 := 0.6 + _len("volley_stand")
	var lib_r: Dictionary = lib["reload"]
	phases = [[0.0, "Make ready, present, fire"]]
	var names := {"pan_open": "Half cock, open the pan", "bite": "Bite the cartridge", "pan_shut": "Prime, shut the pan",
		"rammed": "Cast about, pour, draw the rammer, ram it home", "rammer_home": "Return the rammer"}
	phases.append([t1, "Load: half cock, open the pan"])
	for e: Array in lib_r["events"]:
		match e[1]:
			"bite":
				phases.append([t1 + float(e[0]) - 0.9, "Handle the cartridge, bite it open"])
			"pan_shut":
				phases.append([t1 + float(e[0]) - 1.6, "Prime the pan, shut it"])
				phases.append([t1 + float(e[0]) + 0.1, "Cast about, pour the powder and ball"])
			"rammed":
				phases.append([t1 + float(e[0]) - 4.6, "Draw the rammer, ram the ball home"])
			"rammer_home":
				phases.append([t1 + float(e[0]) - 3.0, "Draw the rammer out, return it"])
				phases.append([t1 + float(e[0]), "Make ready  (about 18 s a round)"])
	phases.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	shadow = 20.0
	cam_fn = func(t: float) -> Array:
		var yaw := 2.1 if t < t1 + 6.5 else 2.6
		return [Vector3(0.05, 1.2, -0.25), yaw, -0.05, 2.5]
	return t1 + r + 1.5


## Charge bayonets, the charge, the thrust at the end; the officer leads, the colour behind.
func _scene_charge() -> float:
	var run := 3.6
	for rank in 2:
		for i in 6:
			_man("musketeer", 50 + rank * 10 + i, Vector3(-2.75 + 1.1 * i, 0, 1.15 * rank), 0.0,
				[[0.0, "hold_ready"], [0.5 + 0.03 * i, "to_charge"], [1.2 + 0.03 * i, "charge_run"],
				[1.2 + run + 0.05 * i, "thrust"], [1.2 + run + 1.4 + 0.05 * i, "hold_charge"]])
	_man("officer", 3, Vector3(0.6, 0, -1.6), 0.0, [[0.0, "officer_wave"], [1.2, "officer_charge"], [1.2 + run, "officer_hold_up"]])
	_man("ensign", 4, Vector3(-0.4, 0, 3.0), 0.0, [[0.0, "ensign_hold"], [1.2, "ensign_charge"], [1.2 + run, "ensign_hold"]])
	phases = [[0.0, "Charge bayonets!"], [1.2, "The charge"], [1.2 + run, "The thrust"]]
	shadow = 60.0
	cam_fn = func(t: float) -> Array:
		var z := -3.4 * clampf(t - 1.2, 0.0, run)
		return [Vector3(0.0, 1.0, z - 1.5), PI - 0.95, -0.08, 7.0]
	return 1.2 + run + 2.4


## Hit and killed: two men shot (falling back and forward), then a field gun shell lands by the line and throws men.
func _scene_deaths() -> float:
	for i in 6:
		var segs: Array = [[0.0, "hold_aim"]]
		if i == 1:
			segs.append([0.8, "death_back"])
		elif i == 4:
			segs.append([1.4, "death_forward"])
		elif i == 2:
			segs.append([1.0, "hit"])
			segs.append([1.75, "hold_aim"])
		_man("musketeer", 70 + i, Vector3(-2.75 + 1.1 * i, 0, 0), 0.0, segs, i != 1 and i != 4)
	_man("officer", 3, Vector3(4.2, 0, 0.3), 0.0, [[0.0, "officer_hold_up"]], true)
	_man("drummer", 5, Vector3(0.5, 0, 2.6), 0.0, [[0.0, "drummer_roll"]], true)
	_man("ensign", 4, Vector3(-1.2, 0, 2.6), 0.0, [[0.0, "ensign_hold"]], true)
	blasts = [[3.4, 2, Vector3(-0.2, 0, 4.6), 11]]
	phases = [[0.0, "Shot: falling back, falling forward, a flesh wound"], [3.3, "A field gun shell lands behind the line"]]
	shadow = 60.0
	cam_fn = func(t: float) -> Array:
		return [Vector3(0.0, 1.0, 1.2), -2.6, -0.14, 10.0 + 0.3 * t]
	return 11.0
