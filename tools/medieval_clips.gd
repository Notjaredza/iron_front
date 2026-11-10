extends "res://tools/armour_clips.gd"
## The medieval host, short videos (Building Chat 1, 2026-11-10), in the explosion test's world (BlastStage) like the
## red coats' and armoured troops' videos, so smoke and blasts match and blasts throw the men. Needs a window:
##   Godot --path iron_front --resolution 1280x720 -s res://tools/medieval_clips.gd -- [scene ...]
## Scenes: host, volley, charge, melee, battle. JPEG frames go to results/units/medieval_frames/<scene>/ at 30 fps;
## ffmpeg makes results/units/medieval/med_<scene>.mp4.
## Arrows and bolts fly as real props: loosed from the bow at its angle, falling under gravity, stuck where they land.

const MB := preload("res://scripts/units/medieval_builder.gd")
const MC := preload("res://scripts/units/anim/clips_medieval.gd")
const F := preload("res://scripts/units/anim/clips_fight.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
const MFRAMES := "res://results/units/medieval_frames/"
const MOUT := "res://results/units/medieval/"
const MSCENES: Array[String] = ["host", "volley", "charge", "melee", "battle"]
const GRAV := 9.8

var md_lib: Dictionary
var our_lib: Dictionary
var shafts: Array = []        # {mi, p0, v, t0, stuck}
var arrow_mesh: Mesh
var bolt_mesh: Mesh
var range_m := 40.0           # how far this scene's arrows carry


func _run() -> void:
	lib = Redcoat.library()
	ar_lib = Armoured.library()
	md_lib = Medieval.library()
	our_lib = R.library().duplicate()
	var holds := {"hold_aim": F.aim(false), "hold_kneel": R.poses()["kneel"], "hold_guard": F.guard(false), "hold_duck": F.duck(false),
		"hold_parry": F.parry(false)}
	for k: String in holds:
		our_lib[k] = {"name": k, "len": 1.0, "loop": true, "keys": [[0.0, holds[k]], [1.0, holds[k]]]}
	our_lib["lunge"] = {"name": "lunge", "len": 1.0, "keys": [[0.0, F.guard(false)], [0.3, F.lunge(false), "out"], [0.5, F.lunge(false)],
		[1.0, F.guard(false), "smooth"]], "events": []}
	arrow_mesh = MB.arrow().to_mesh(Soldier.material())
	bolt_mesh = MB.arrow(true).to_mesh(Soldier.material())
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOUT))
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else MSCENES):
		await _mrecord(sc)
	print("MEDIEVAL CLIPS OK")
	quit()


func _reset() -> void:
	for a: Dictionary in actors:
		if a.has("horse") and is_instance_valid(a["horse"]):
			(a["horse"] as Node).queue_free()
	super._reset()
	for s: Dictionary in shafts:
		if is_instance_valid(s["mi"]):
			(s["mi"] as Node).queue_free()
	shafts.clear()


# ---------------------------------------------------------------- actors

## A medieval man. segs: [[t0, move]] with moves named without the kit ("march", "strike"; "hold_guard").
func _mman(role: String, seed_value: int, at: Vector3, yaw_deg: float, segs: Array, lord := -1, weapon := "", thrown := true) -> Dictionary:
	var m := Medieval.new()
	m.lord = lord
	if not weapon.is_empty():
		var s := seed_value
		while MB.look_for_role(s, role, lord)["weapon"] != weapon and s < seed_value + 400:
			s += 1
		seed_value = s
	m.setup(seed_value, 0, role)
	stage.add_child(m)
	at.y = stage.ground.height(at.x, at.z)
	m.position = at
	m.rotation.y = deg_to_rad(yaw_deg)
	if thrown:
		m.set_meta("pose", "stand")
		stage.men.append(m)
	var full: Array = []
	for s: Array in segs:
		var n: String = s[1]
		full.append([s[0], n if md_lib.has(n) else m.clip_name(n)])
	var a := {"man": m, "segs": full, "pos0": at, "yaw": deg_to_rad(yaw_deg), "fired": {}, "lib": md_lib, "kind": "med"}
	actors.append(a)
	return a


## One of our riflemen (clips from the rifle set plus holds: hold_aim, hold_kneel, hold_guard, hold_duck, hold_parry, lunge).
func _oman(seed_value: int, at: Vector3, yaw_deg: float, segs: Array, thrown := true) -> Dictionary:
	var s := Soldier.new()
	s.setup(seed_value, 0)
	stage.add_child(s)
	at.y = stage.ground.height(at.x, at.z)
	s.position = at
	s.rotation.y = deg_to_rad(yaw_deg)
	if thrown:
		s.set_meta("pose", "aim")
		stage.men.append(s)
	var a := {"man": s, "segs": segs, "pos0": at, "yaw": deg_to_rad(yaw_deg), "fired": {}, "lib": our_lib, "kind": "ours"}
	actors.append(a)
	return a


## A knight (or scout) on his horse. path(t) -> [pos, yaw_deg, horse pose, rider mode, hand]; off_at: thrown from the
## saddle at that time (then he falls ahead of the horse over fall_len seconds).
func _kman(seed_value: int, path: Callable, role := "knight", off_at := INF) -> Dictionary:
	var r := Medieval.new()
	r.setup(seed_value, 0, role)
	var h: Horse
	if role == "knight":
		h = Medieval.barded_horse(seed_value, r.look["arms"], 0)
	else:
		h = Horse.new().setup(seed_value, 0, (r.look["arms"] as Dictionary)["field"])
	stage.add_child(h)
	h.att_body.add_child(r)
	r.position = Horse.seat_local() - Vector3(0, 0.86, 0)
	var a := {"man": r, "horse": h, "path": path, "kind": "ride", "off_at": off_at, "segs": [[0.0, ""]], "fired": {}}
	actors.append(a)
	return a


func _eval(a: Dictionary, t: float) -> void:
	match a.get("kind", ""):
		"ride":
			_eval_ride(a, t)
			return
		"med", "ours":
			pass
		"prop":
			return
		_:
			super._eval(a, t)
			return
	var man: Soldier = a["man"]
	for th in stage.throws:
		if th.man == man:
			return
	if man.get_meta("thrown_done", false):
		return
	var L: Dictionary = a["lib"]
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
	if man is Medieval:
		(man as Medieval).set_props(Medieval.prop_state(c, lt))
	for e: Array in c.get("events", []):
		var key := "%d:%s:%.2f" % [i, e[1], float(e[0])]
		if a["fired"].has(key) or lt < float(e[0]):
			continue
		a["fired"][key] = true
		var x := man.skel.global_transform * man.skel.get_bone_global_pose(B.RIFLE)
		if a["kind"] == "ours" and e[1] == "shot":
			stage.fire("pan", x * F.muzzle(false), randi(), -1, -x.basis.z.normalized(), false)
		elif e[1] == "loose":
			_loose(man as Medieval, t)
		elif e[1] == "shot" and man is Medieval:
			_shaft(x * Vector3(0, 0.03, -0.3), -x.basis.z.normalized() * 55.0, t, true)


func _eval_ride(a: Dictionary, t: float) -> void:
	var h: Horse = a["horse"]
	var r: Medieval = a["man"]
	var st: Array = (a["path"] as Callable).call(t)
	h.position = st[0] + Vector3(0, stage.ground.height(st[0].x, st[0].z), 0)
	h.rotation.y = deg_to_rad(st[1])
	h.show_pose(st[2])
	var off: float = a["off_at"]
	if t < off:
		r.show_spec(Rig.over(MC.ride(st[3]), {"hand_item": st[4]}), false)
		return
	if r.get_parent() != stage:
		var gx := r.global_transform
		r.get_parent().remove_child(r)
		stage.add_child(r)
		a["start"] = gx.origin
		a["fwd"] = -gx.basis.z.normalized()
		a["yaw_r"] = gx.basis.get_euler().y
	var u := clampf((t - off) / 0.9, 0.0, 1.0)
	var fwd: Vector3 = a["fwd"]
	fwd.y = 0.0
	fwd = fwd.normalized()
	var p0: Vector3 = a["start"]
	var land := p0 + fwd * 2.2
	var p := p0.lerp(land, u)
	p.y = lerpf(p0.y, stage.ground.height(land.x, land.z), u * u)
	r.position = p
	r.rotation = Vector3(0, a["yaw_r"], 0)
	var bl: Dictionary = MC.unhorsed(u)
	r.show_blend(bl["a"], bl["b"], bl["t"], false)
	if u >= 1.0:
		r.position.y = stage.ground.height(p.x, p.z)
		r.show_blend(bl["a"], bl["b"], bl["t"], true)


# ---------------------------------------------------------------- arrows

## Three shafts per bowman (a volley reads as a cloud), loosed along the nocked arrow, carrying range_m.
func _loose(m: Medieval, t: float) -> void:
	var d := -m.arrow.global_transform.basis.z.normalized() if m.arrow != null else Vector3(0, 0.6, -0.8)
	var e := asin(clampf(d.y, 0.05, 0.95))
	var v := sqrt(range_m * GRAV / maxf(sin(2.0 * e), 0.2))
	var p0 := m.arrow.global_position if m.arrow != null else m.global_position + Vector3(0, 1.5, 0)
	for k in 3:
		var j := Vector3(randf_range(-0.04, 0.04), randf_range(-0.03, 0.03), randf_range(-0.04, 0.04))
		_shaft(p0 + j * 4.0, (d + j).normalized() * v * randf_range(0.95, 1.05), t, false)


func _shaft(p0: Vector3, v: Vector3, t: float, bolt: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = bolt_mesh if bolt else arrow_mesh
	mi.scale = Vector3.ONE * 1.8
	stage.add_child(mi)
	shafts.append({"mi": mi, "p0": p0, "v": v, "t0": t, "stuck": false})
	_fly(shafts[-1], t)


func _fly(s: Dictionary, t: float) -> void:
	if s["stuck"]:
		return
	var dt := t - float(s["t0"])
	var v: Vector3 = s["v"]
	var p: Vector3 = s["p0"] + v * dt + Vector3(0, -0.5 * GRAV * dt * dt, 0)
	var vel := v + Vector3(0, -GRAV * dt, 0)
	var mi: MeshInstance3D = s["mi"]
	var gy := stage.ground.height(p.x, p.z)
	if p.y < gy + 0.25 and vel.y < 0.0:
		# Stuck in the earth, a third of the shaft buried.
		p.y = gy + 0.25
		s["stuck"] = true
	var up := Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(vel.normalized(), up).scaled(Vector3.ONE * 1.8), p - vel.normalized() * 1.3)


func _tick(t: float) -> void:
	for s: Dictionary in shafts:
		_fly(s, t)


# ---------------------------------------------------------------- recording

func _mrecord(sc: String) -> void:
	_reset()
	seed(91)
	range_m = 40.0
	var length: float = call("_mscene_" + sc)
	var dir := ProjectSettings.globalize_path(MFRAMES + sc + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(ProjectSettings.globalize_path(MFRAMES + ".gdignore"), FileAccess.WRITE).store_string("")
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
		_tick(t)
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
	var mp4 := ProjectSettings.globalize_path(MOUT + "med_" + sc + ".mp4")
	var out := []
	var code := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", "30", "-i", dir + "f%04d.jpg",
		"-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", mp4], out, true)
	print("frames %s %d in %d ms, ffmpeg %d" % [sc, frames, Time.get_ticks_msec() - t0, code])


func _ml(kit: String, n: String) -> float:
	return float(md_lib["%s_%s" % [kit, n]]["len"])


# ---------------------------------------------------------------- scenes

## The host forms and comes on: men-at-arms lock the wall, the banner waves, spears behind, the captain; the advance.
func _mscene_host() -> float:
	var t_lock := 2.2
	var t_step := t_lock + _ml("sword", "wall_lock")
	for i in 7:
		_mman("man_at_arms", 10 + i, Vector3(-2.1 + 0.7 * i, 0, 0), 0.0, [[0.0, "march"], [t_lock + 0.04 * i, "wall_lock"],
			[t_step, "wall_step"]], i % 3)
	for i in 6:
		_mman("spearman", 20 + i, Vector3(-1.75 + 0.7 * i, 0, 0.9), 0.0, [[0.0, "march"], [t_lock + 0.3, "hold_guard"],
			[t_step, "wall_step"]], 3 + i % 2)
	_mman("banner", 30, Vector3(-0.35, 0, 1.9), 0.0, [[0.0, "march"], [t_lock, "wave"], [t_step + 2.4, "wall_step"]], 0)
	_mman("captain", 31, Vector3(0.8, 0, 2.0), 0.0, [[0.0, "march"], [t_lock + 0.2, "hold_guard"], [t_step, "wall_step"]], 0)
	for i in 5:
		_mman("levy", 40 + i, Vector3(-1.9 + 0.95 * i, 0, 3.2), 0.0, [[0.0, "march"], [t_lock + 0.4, "hold_stand"], [t_step, "wall_step"]], i)
	phases = [[0.0, "The medieval host on the march: men-at-arms, spears, banner, captain, levy"],
		[t_lock, "Halt: shields lock into the wall, the banner swings"], [t_step, "The wall comes on, step and drag"]]
	shadow = 40.0
	cam_fn = func(t: float) -> Array:
		var z := -1.25 * minf(t, t_lock) - 0.6 * clampf(t - t_step, 0.0, 9.0)
		return [Vector3(0.0, 1.0, z + 0.4), PI - 0.55 + 0.03 * t, -0.13, 11.0 - 0.15 * t]
	return t_step + 7.0


## The arrow storm: longbows loose two high volleys over their stakes; crossbows shoot and span at their pavises.
func _mscene_volley() -> float:
	range_m = 55.0
	var vl := _ml("bow", "volley")
	for i in 8:
		var x := -3.5 + 0.9 * i
		var z := 0.3 * (i % 2)
		_mman("longbow", 50 + i, Vector3(x, 0, z), 0.0, [[0.0, "hold_stand"], [0.5 + 0.06 * i, "volley"], [0.5 + vl + 0.1 + 0.06 * i, "volley"],
			[0.5 + 2.0 * vl + 0.3 + 0.06 * i, "hold_stand"]], 5)
		var sg := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = MB.stake(1.25, 0.75).to_mesh(Soldier.material())
		mi.position = Vector3(x + 0.2, stage.ground.height(x, z - 1.2), z - 1.2)
		stage.add_child(mi)
		actors.append({"man": mi, "segs": [[0.0, ""]], "kind": "prop"})
		var m2 := MeshInstance3D.new()
		m2.mesh = MB.stake(1.1, 0.68).to_mesh(Soldier.material())
		m2.position = Vector3(x - 0.25, stage.ground.height(x, z - 1.4), z - 1.4)
		m2.rotation.y = 0.2
		stage.add_child(m2)
		actors.append({"man": m2, "segs": [[0.0, ""]], "kind": "prop"})
		sg.free()
	var xl := _ml("xbow", "shoot")
	var xr := _ml("xbow", "reload")
	for i in 4:
		var x := 5.4 + 1.0 * i
		_mman("crossbow", 70 + i, Vector3(x, 0, 0.2), 0.0, [[0.0, "hold_stand"], [0.3 + 0.4 * i, "shoot"], [0.3 + 0.4 * i + xl, "reload"],
			[0.3 + 0.4 * i + xl + xr, "shoot"], [0.3 + 0.4 * i + 2.0 * xl + xr, "hold_aim"]], 2)
		var pv := MeshInstance3D.new()
		pv.mesh = MB.pavise(MB.lord_arms(2)).to_mesh(Soldier.material())
		pv.position = Vector3(x - 0.15, stage.ground.height(x, -0.6), -0.6)
		stage.add_child(pv)
		actors.append({"man": pv, "segs": [[0.0, ""]], "kind": "prop"})
	phases = [[0.0, "Longbows behind their stakes, crossbows at their pavises"], [0.5, "Nock, draw, loose: the volley goes up"],
		[0.5 + vl, "The second volley; the crossbows span with the cranequin and shoot again"]]
	shadow = 50.0
	cam_fn = func(t: float) -> Array:
		if t < 2.0:
			return [Vector3(1.0, 1.2, -0.5), PI - 0.75 + 0.05 * t, -0.1, 11.0]
		var u := smoothstep(0.0, 1.0, clampf((t - 2.0) / 1.5, 0.0, 1.0))
		return [Vector3(lerpf(1.0, 0.0, u), lerpf(1.2, 2.2, u), lerpf(-0.5, -9.0, u)), lerpf(PI - 0.65, 0.4, u), lerpf(-0.1, -0.2, u), lerpf(11.0, 15.0, u)]
	return 0.5 + 2.0 * vl + 1.6


## The knights' charge on our line: walk, gallop, lances couched; our fire brings a horse down and throws its rider;
## the rest strike home and draw swords.
func _mscene_charge() -> float:
	var t_gal := 1.6
	var t_couch := 3.4
	var t_hit := 5.6
	var vg := 8.5
	var vc := 11.0
	var kx: Array[float] = [-3.2, -1.1, 1.1, 3.2]
	var z0 := -55.0
	for i in 4:
		var x := kx[i]
		var phase := 0.17 * i
		var fall_t := 4.3 if i == 1 else INF
		var path := func(t: float) -> Array:
			var z := z0 + 1.6 * minf(t, t_gal) + vg * clampf(t - t_gal, 0.0, t_couch - t_gal) + vc * clampf(t - t_couch, 0.0, t_hit - t_couch) \
				+ 3.6 * clampf(t - t_hit, 0.0, 4.0)
			if t >= fall_t:
				var zf := z0 + 1.6 * t_gal + vg * (t_couch - t_gal) + vc * (fall_t - t_couch)
				return [Vector3(x, 0, zf + 3.0 * clampf(t - fall_t, 0.0, 0.6)), 180.0, Horse.fall_pose(clampf((t - fall_t) / 1.1, 0.0, 1.0)), "impact", "main"]
			var hp: Dictionary
			if t < t_gal:
				hp = Horse.gait_pose("walk", t / 1.1 + phase)
			elif t < t_hit:
				hp = Horse.gait_pose("gallop" if t < t_couch else "charge", t / (0.6 if t < t_couch else 0.52) + phase)
			else:
				hp = Horse.gait_pose("trot", t / 0.72 + phase)
			var mode := "lance_up" if t < t_couch - 0.4 else "couch" if t < t_hit else "impact" if t < t_hit + 0.6 else "raise" if t < t_hit + 1.6 \
				else "cut" if fmod(t - t_hit, 1.2) < 0.5 else "raise"
			return [Vector3(x, 0, z), 180.0, hp, mode, "main" if t < t_hit + 0.6 else "alt"]
		_kman(80 + i, path, "knight", fall_t + 0.15 if i == 1 else INF)
	# Our line: fire, then the survivors brace, duck or are ridden down.
	var line_z := z0 + 1.6 * t_gal + vg * (t_couch - t_gal) + vc * (t_hit - t_couch) + 1.2
	var ox: Array[float] = [-3.0, -1.6, 0.0, 1.5, 3.0]
	var fs := float(our_lib["fire_stand"]["len"])
	for i in 5:
		var segs: Array = [[0.0, "hold_aim"], [1.0 + 0.3 * i, "fire_stand"], [1.0 + 0.3 * i + fs, "fire_stand"],
			[1.0 + 0.3 * i + 2.0 * fs, "fire_stand"]]
		match i:
			0:
				segs.append([t_hit - 0.4, "hold_duck"])
			2:
				segs.append([t_hit + 0.05, "death_back"])
			3:
				segs.append([t_hit - 0.2, "hold_parry"])
				segs.append([t_hit + 1.4, "death_forward"])
			_:
				segs.append([t_hit - 0.3, "hold_guard"])
				segs.append([t_hit + 1.0, "lunge"])
				segs.append([t_hit + 2.0, "hold_guard"])
		_oman(100 + i, Vector3(ox[i], 0, line_z), 180.0 + 180.0, segs, false)
	phases = [[0.0, "Knights on barded horses, lances up"], [t_gal, "The gallop; our line opens fire"],
		[t_couch - 0.4, "Lances couched: the charge"], [4.3, "A horse brought down, its rider thrown"],
		[t_hit, "Impact! Swords out from the saddle"]]
	shadow = 70.0
	cam_fn = func(t: float) -> Array:
		if t < t_couch:
			var z := z0 + 1.6 * minf(t, t_gal) + vg * clampf(t - t_gal, 0.0, t_couch - t_gal)
			return [Vector3(0.0, 1.5, z + 1.0), PI - 0.9 - 0.05 * t, -0.08, 13.0]
		return [Vector3(0.0, 1.3, line_z - 3.0 + 2.4 * clampf(t - t_hit, 0.0, 3.0)), 1.05 + 0.04 * (t - t_couch), -0.12, 15.0 - 0.6 * clampf(t - t_couch, 0.0, 4.0)]
	return t_hit + 3.6


## The melee: men-at-arms, a heavy and the levy come at our riflemen and armoured shield men; blows, blocks, falls.
func _mscene_melee() -> float:
	var t_meet := 3.0
	var mv := float(md_lib["sword_run"].get("speed", 3.4))
	var gap := mv * t_meet
	var mz := -1.2 - gap
	# Ours.
	_aman("shield", 120, Vector3(-2.4, 0, 0), 0.0, [[0.0, "hold_wall"], [t_meet - 0.1, "block"], [t_meet + 1.2, "bash"],
		[t_meet + 2.4, "hold_wall"], [t_meet + 3.0, "block"], [t_meet + 4.2, "hold_wall"]], "", false)
	_aman("club", 121, Vector3(-1.5, 0, 0.9), 0.0, [[0.0, "hold_guard"], [t_meet + 0.5, "smash"], [t_meet + 2.0, "hold_guard"],
		[t_meet + 3.2, "swing"], [t_meet + 4.6, "hold_guard"]], "mace", false)
	_oman(122, Vector3(0.0, 0, 0.0), 0.0, [[0.0, "hold_aim"], [0.4, "fire_stand"], [t_meet - 0.6, "hold_guard"], [t_meet + 0.2, "hold_parry"],
		[t_meet + 1.2, "lunge"], [t_meet + 2.2, "hold_guard"], [t_meet + 3.1, "death_back"]], false)
	_oman(123, Vector3(1.4, 0, 0.1), 0.0, [[0.0, "hold_aim"], [0.9, "fire_stand"], [t_meet - 0.3, "hold_guard"], [t_meet + 0.4, "lunge"],
		[t_meet + 1.4, "hold_guard"], [t_meet + 2.5, "lunge"], [t_meet + 3.5, "hold_guard"]], false)
	_oman(124, Vector3(2.8, 0, 0.2), 0.0, [[0.0, "hold_kneel"], [0.7, "fire_kneel"], [t_meet + 0.6, "death_forward"]], false)
	# Theirs: they run in and fall to.
	_mman("man_at_arms", 130, Vector3(-2.4, 0, mz), 180.0, [[0.0, "run"], [t_meet - 0.25, "strike"], [t_meet + 1.2, "hold_guard"],
		[t_meet + 1.25, "death_back"]], 1)
	_mman("heavy", 131, Vector3(-1.2, 0, mz - 0.5), 180.0, [[0.0, "run"], [t_meet - 0.1, "hold_guard"], [t_meet + 0.3, "strike"],
		[t_meet + 1.9, "sweep"], [t_meet + 3.4, "hold_guard"]], 2, "poleaxe")
	_mman("man_at_arms", 132, Vector3(0.1, 0, mz), 180.0, [[0.0, "run"], [t_meet - 0.2, "block"], [t_meet + 0.9, "thrust"],
		[t_meet + 2.0, "strike"], [t_meet + 3.3, "hold_guard"]], 0)
	_mman("levy", 133, Vector3(1.4, 0, mz - 0.3), 180.0, [[0.0, "run"], [t_meet, "strike"], [t_meet + 1.6, "hit"], [t_meet + 2.6, "death_forward"]],
		3, "pitchfork")
	_mman("levy", 134, Vector3(2.7, 0, mz + 0.2), 180.0, [[0.0, "run"], [t_meet + 0.1, "sweep"], [t_meet + 1.6, "strike"],
		[t_meet + 3.2, "hold_guard"]], 4, "flail")
	_mman("levy", 135, Vector3(0.8, 0, mz - 1.6), 180.0, [[0.0, "run"], [t_meet + 0.4, "hold_guard"], [t_meet + 1.4, "sweep"],
		[t_meet + 2.9, "strike"], [t_meet + 4.4, "hold_guard"]], 5, "billhook")
	phases = [[0.0, "Men-at-arms, a heavy and the levy rush our line"], [t_meet - 0.2, "The clash: sword, pole-axe and pitchfork against bayonet, shield and mace"]]
	shadow = 40.0
	cam_fn = func(t: float) -> Array:
		return [Vector3(0.2, 1.0, -0.9 - 1.5 * clampf(1.0 - t / t_meet, 0.0, 1.0)), 1.15 - 0.03 * t, -0.14, 9.5 - 0.2 * minf(t, 6.0)]
	return t_meet + 5.0


## The battle: the host comes on under our shell fire; blasts throw men-at-arms and levy; arrows answer; they press on.
func _mscene_battle() -> float:
	range_m = 38.0
	var walk := 8.0
	for i in 8:
		_mman("man_at_arms" if i != 3 else "banner", 140 + i, Vector3(-3.2 + 0.85 * i, 0, -24.0), 180.0, [[0.0, "march"],
			[walk, "hold_guard"]], i % 3)
	for i in 7:
		_mman("levy", 150 + i, Vector3(-2.9 + 0.9 * i, 0, -25.4), 180.0, [[0.0, "march"], [walk, "hold_guard"]], i % 6)
	for i in 3:
		_mman("heavy", 160 + i, Vector3(-1.6 + 1.6 * i, 0, -26.6), 180.0, [[0.0, "march"], [walk, "hold_guard"]], i)
	var vl := _ml("bow", "volley")
	for i in 6:
		_mman("longbow", 170 + i, Vector3(-2.6 + 1.0 * i, 0, -38.0), 180.0, [[0.0, "hold_stand"], [2.4 + 0.08 * i, "volley"],
			[2.4 + vl + 0.3 + 0.08 * i, "volley"], [2.4 + 2.0 * vl + 0.6, "hold_stand"]], 5, "", false)
	var ox: Array[float] = [-3.0, -1.5, 0.0, 1.5, 3.0]
	var fs := float(our_lib["fire_kneel"]["len"])
	for i in 5:
		var segs: Array = [[0.0, "hold_kneel"]]
		for k in 3:
			segs.append([0.6 + 0.25 * i + fs * k, "fire_kneel"])
		segs.append([0.6 + 0.25 * i + fs * 3.0, "hold_kneel"])
		if i == 1:
			segs.append([4.6, "death_forward"])
		_oman(180 + i, Vector3(ox[i], 0, 0.0), 0.0, segs, false)
	var mv := float(md_lib["sword_march"].get("speed", 1.25))
	blasts = [[1.3, 1, Vector3(-2.0, 0, -24.0 + mv * 1.3 + 0.4), 21], [3.0, 1, Vector3(1.6, 0, -25.6 + mv * 3.0), 22],
		[5.2, 2, Vector3(-0.4, 0, -24.4 + mv * 5.2 - 0.3), 23], [6.6, 1, Vector3(2.8, 0, -24.2 + mv * 6.6), 24]]
	phases = [[0.0, "The host comes on under our fire"], [1.3, "Shells land in the ranks: men are thrown"],
		[2.4, "Their archers answer: the arrow storm falls on our line"], [5.2, "Another shell; they close up and come on"]]
	shadow = 80.0
	cam_fn = func(t: float) -> Array:
		var z := -24.0 + mv * minf(t, walk)
		return [Vector3(0.0, 1.0, lerpf(z, 0.0, 0.35)), 1.3 + 0.02 * t, -0.2, 30.0 - 0.4 * t]
	return walk + 2.0
