extends "res://tools/fight_pictures.gd"
## The medieval host (Building Chat 1, 2026-11-10): the look sheets, the move sheets, the formations, the knights and
## the fights against our riflemen and armoured troops, in the explosion test's world (BlastStage). Needs a window:
##   Godot --path iron_front --resolution 1600x900 -s res://tools/medieval_pictures.gd -- [look moves formations knights fights]
## MED_ONLY=<clip part> limits the move sheets (writes med_debug.png). Writes results/units/medieval/med_*.png.

const MB := preload("res://scripts/units/medieval_builder.gd")
const MC := preload("res://scripts/units/anim/clips_medieval.gd")
const AR := preload("res://scripts/units/anim/clips_armour.gd")
const MOUT := "res://results/units/medieval/"
const FOOT: Array[String] = ["man_at_arms", "spearman", "crossbow", "longbow", "captain", "banner", "heavy", "levy"]

var md_lib: Dictionary
var ar_lib: Dictionary
var loose: Array[Node] = []  # arrows in the air or the ground, cleared between stills


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOUT))
	rc_lib = Redcoat.library()
	our_lib = R.library()
	md_lib = Medieval.library()
	ar_lib = Armoured.library()
	stage = BlastStage.new()
	stage.manual = true
	root.add_child(stage)
	ui = CanvasLayer.new()
	root.add_child(ui)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 7)
	title.position = Vector2(24, 16)
	ui.add_child(title)
	await process_frame
	gy = stage.ground.height(0, 0)
	var args := OS.get_cmdline_user_args()
	for mode in (args if not args.is_empty() else ["look", "moves", "formations", "knights", "fights"]):
		match mode:
			"look":
				await _look()
			"close":
				await _close()
			"moves":
				await _moves()
			"formations":
				await _formations()
			"knights":
				await _knights()
			"fights":
				await _fights()
	print("MEDIEVAL PICTURES OK")
	quit()


# ---------------------------------------------------------------- helpers

func _med(name: String, seed_value: int, role: String, lord := -1, lod := 0, weapon := "") -> Medieval:
	var m := Medieval.new()
	m.lord = lord
	if not weapon.is_empty():
		# Pick the heavy's or levy's weapon by seed: try seeds until it matches (keeps the look seeded).
		var s := seed_value
		while MB.look_for_role(s, role, lord)["weapon"] != weapon and s < seed_value + 400:
			s += 1
		seed_value = s
	m.setup(seed_value, lod, role)
	stage.add_child(m)
	_keep(m)
	men[name] = m
	return m


func _arm(name: String, seed_value: int, role: String) -> Armoured:
	var a := Armoured.new()
	a.setup(seed_value, 0, role)
	stage.add_child(a)
	_keep(a)
	men[name] = a
	return a


## A medieval man in a pose (a name from his kit's poses, or a spec).
func _mput(name: String, at: Vector3, yaw: float, spec: Variant) -> void:
	var m: Medieval = men[name]
	var p: Dictionary = MC.poses(m.kit).get(spec, MC.poses(m.kit)["stand"]) if spec is String else spec
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	m.show_spec(p)


## Plays a clip on any man (a medieval clip name without its kit: "strike" -> "<kit>_strike").
func _mplay(name: String, at: Vector3, yaw: float, clip: String, t: float) -> void:
	var m: Soldier = men[name]
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	if m is Medieval:
		var c := clip if md_lib.has(clip) else (m as Medieval).clip_name(clip)
		m.show_clip(md_lib[c], t)
	elif m is Armoured:
		m.show_clip(ar_lib[clip if ar_lib.has(clip) else (m as Armoured).clip_name(clip)], t)
	else:
		_play(name, at, yaw, clip, t)


func _mlen(name: String, clip: String) -> float:
	var m: Soldier = men[name]
	if m is Medieval:
		return float(md_lib[clip if md_lib.has(clip) else (m as Medieval).clip_name(clip)]["len"])
	if m is Armoured:
		return float(ar_lib[clip if ar_lib.has(clip) else (m as Armoured).clip_name(clip)]["len"])
	return _clip_len(name, clip)


func _hide(names: Array) -> void:
	for n: String in names:
		(men[n] as Node3D).visible = false


func _msave(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(MOUT + "med_" + name + ".png"))
	print("saved med_", name)


## A knight (or scout) on his horse.
func _mount_k(name: String, seed_value: int, role := "knight", lod := 0) -> Horse:
	var r := Medieval.new()
	r.setup(seed_value, lod, role)
	var h: Horse
	if role == "knight":
		h = Medieval.barded_horse(seed_value, r.look["arms"], lod)
	else:
		h = Horse.new().setup(seed_value, lod, (r.look["arms"] as Dictionary)["field"])
	stage.add_child(h)
	_keep(h)
	h.att_body.add_child(r)
	r.position = Horse.seat_local() - Vector3(0, 0.86, 0)
	men[name] = r
	men[name + "_h"] = h
	return h


func _kride(name: String, at: Vector3, yaw: float, horse_pose: Dictionary, mode: String, hand := "main") -> void:
	var h: Horse = men[name + "_h"]
	h.visible = true
	h.position = Vector3(at.x, gy + at.y, at.z)
	h.rotation.y = deg_to_rad(yaw)
	h.show_pose(horse_pose)
	var r: Medieval = men[name]
	r.show_spec(Rig.over(MC.ride(mode), {"hand_item": hand}), false)


func _flight(from: Vector3, dir: Vector3, n: int, spread: float, seed_value: int, bolt := false) -> void:
	# A flight of arrows in the air (prop arrows, pointing along their path).
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := MB.arrow(bolt).to_mesh(Soldier.material())
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var p := from + Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.3, spread * 0.3), rng.randf_range(-spread, spread))
		var d := (dir + Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))).normalized()
		mi.transform = Transform3D(Basis.looking_at(d, Vector3.UP), p + Vector3(0, gy, 0))
		stage.add_child(mi)
		_keep(mi)
		loose.append(mi)


func _stuck(at: Vector3, n: int, spread: float, seed_value: int) -> void:
	# Arrows stuck in the ground, tilted the way they fell.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := MB.arrow().to_mesh(Soldier.material())
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var p := at + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		var d := Vector3(rng.randf_range(-0.2, 0.2), -0.85, rng.randf_range(0.2, 0.5)).normalized()
		mi.transform = Transform3D(Basis.looking_at(d, Vector3.UP), p + Vector3(0, gy + stage.ground.height(p.x, p.z) - gy, 0) - d * 0.62)
		stage.add_child(mi)
		_keep(mi)
		loose.append(mi)


func _geo_prop(g: UnitGeo, at: Vector3, yaw: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh(Soldier.material())
	mi.position = at + Vector3(0, gy, 0)
	mi.rotation.y = deg_to_rad(yaw)
	stage.add_child(mi)
	_keep(mi)
	return mi


# ---------------------------------------------------------------- look

func _look() -> void:
	_clear()
	var tiles: Array[Image] = []
	var names: Array[String] = []
	for i in FOOT.size():
		var nm := "f%d" % i
		_med(nm, 3 + i * 7, FOOT[i], i % MB.LORDS)
		names.append(nm)
	var xs := func(i: int) -> float: return -3.15 + 0.9 * i
	for i in names.size():
		_mput(names[i], Vector3(xs.call(i), 0, 0), 0.0, "stand")
	_cam(Vector3(0.0, 1.0, 0), PI - 0.3, -0.06, 8.0, 40.0)
	tiles.append(await _grab("man-at-arms, spearman, crossbow, longbow, captain, banner, heavy, levy"))
	_cam(Vector3(0.0, 1.0, 0), 0.4, -0.08, 8.0, 40.0)
	tiles.append(await _grab("from behind: pavise, quiver, banner"))
	for i in names.size():
		_mput(names[i], Vector3(xs.call(i), 0, 0), 0.0, "guard")
	_cam(Vector3(0.0, 1.0, 0), PI - 0.55, -0.1, 8.0, 40.0)
	tiles.append(await _grab("on guard"))
	_hide(names)
	# The six lords' arms: a man-at-arms of each.
	for l in MB.LORDS:
		_med("l%d" % l, 40 + l, "man_at_arms", l)
		_mput("l%d" % l, Vector3(-2.5 + 1.0 * l, 0, 0), 0.0, "guard")
	_cam(Vector3(0.0, 1.0, 0), PI - 0.25, -0.05, 6.8, 40.0)
	tiles.append(await _grab("six lords' arms on the shields and surcoats"))
	for l in MB.LORDS:
		(men["l%d" % l] as Node3D).visible = false
	# Heavies and levies, every weapon.
	var hw: Array = [["heavy", "greatsword"], ["heavy", "poleaxe"], ["heavy", "halberd"], ["levy", "pitchfork"], ["levy", "flail"],
		["levy", "billhook"]]
	for i in hw.size():
		_med("h%d" % i, 60 + i * 5, hw[i][0], i, 0, hw[i][1])
		_mput("h%d" % i, Vector3(-2.5 + 1.0 * i, 0, 0), 0.0, "guard")
	_cam(Vector3(0.0, 1.0, 0), PI - 0.4, -0.06, 6.8, 40.0)
	tiles.append(await _grab("heavies: greatsword, pole-axe, halberd; levy: pitchfork, flail, billhook"))
	for i in hw.size():
		(men["h%d" % i] as Node3D).visible = false
	# Far looks: close / mid / far.
	for lod in 3:
		_med("d%d" % lod, 5, "man_at_arms", 1, lod)
		_mput("d%d" % lod, Vector3(-2.0 + 1.4 * lod, 0, 0), 0.0, "stand")
		_med("e%d" % lod, 9, "heavy", 2, lod)
		_mput("e%d" % lod, Vector3(-1.4 + 1.4 * lod, 0, 0.3), 0.0, "stand")
	var tri := []
	for lod in 3:
		tri.append("%d / %d" % [(men["d%d" % lod] as Medieval).tri_count(), (men["e%d" % lod] as Medieval).tri_count()])
	print("tris ", tri)
	_cam(Vector3(0.0, 1.0, 0.2), PI - 0.45, -0.1, 6.5, 40.0)
	tiles.append(await _grab("close / mid / far (triangles: %s)" % ", ".join(tri)))
	_msave(_tile(tiles, 3), "look")


func _close() -> void:
	_clear()
	var tiles: Array[Image] = []
	var picks: Array = [["man_at_arms", 3], ["captain", 31], ["heavy", 45], ["crossbow", 17], ["longbow", 24], ["levy", 52]]
	for i in picks.size():
		_med("c", picks[i][1], picks[i][0], i % MB.LORDS)
		_mput("c", Vector3.ZERO, 0.0, "stand")
		_cam(Vector3(0, 1.15, 0), PI - 0.45, -0.04, 3.3, 40.0)
		tiles.append(await _grab(picks[i][0]))
		(men["c"] as Node3D).queue_free()
		men.erase("c")
	_msave(_tile(tiles, 3), "close")


# ---------------------------------------------------------------- moves

func _moves() -> void:
	var only := OS.get_environment("MED_ONLY")
	var rows: Array = [
		["sword_march", "man_at_arms", 6], ["sword_run", "man_at_arms", 6], ["sword_strike", "man_at_arms", 6],
		["sword_thrust", "man_at_arms", 6], ["sword_block", "man_at_arms", 6], ["sword_wall_lock", "man_at_arms", 4],
		["sword_wall_step", "man_at_arms", 6],
		["spear_march", "spearman", 6], ["spear_thrust", "spearman", 6], ["spear_brace", "spearman", 4], ["spear_block", "spearman", 6],
		["xbow_march", "crossbow", 6], ["xbow_shoot", "crossbow", 6], ["xbow_reload", "crossbow", 6],
		["bow_march", "longbow", 6], ["bow_volley", "longbow", 6], ["bow_shot", "longbow", 6], ["bow_stake", "longbow", 6],
		["banner_march", "banner", 6], ["banner_wave", "banner", 6],
		["pole_march", "heavy", 6], ["pole_strike", "heavy", 6], ["pole_sweep", "heavy", 6], ["great_strike", "heavy", 6],
		["levy_march", "levy", 6], ["levy_run", "levy", 6], ["levy_strike", "levy", 6], ["levy_sweep", "levy", 6],
		["sword_hit", "man_at_arms", 4], ["sword_death_back", "man_at_arms", 6], ["pole_death_forward", "heavy", 6],
		["bow_death_back", "longbow", 6], ["spear_prone_to_stand", "spearman", 6]]
	var sheets := {"foot": [], "missile": [], "heavy": [], "falls": []}
	if not only.is_empty():
		sheets = {"debug": []}
	for row: Array in rows:
		var clip: String = row[0]
		if not only.is_empty() and not clip.contains(only):
			continue
		_clear()
		var role: String = row[1]
		var n: int = row[2]
		var wk := ""
		if clip.begins_with("great"):
			wk = "greatsword"
		elif clip.begins_with("pole"):
			wk = "halberd"
		_med("m", 6, role, 2, 0, wk)
		var c: Dictionary = md_lib[clip]
		var L := float(c["len"])
		var tiles: Array[Image] = []
		var falls := clip.contains("death") or clip.contains("prone") or clip.contains("hit")
		for k in n:
			var t := L * k / float(n - 1 if not c.get("loop", false) else n)
			var dz := -float(c.get("speed", 0.0)) * t
			_mplay("m", Vector3(0, 0, dz), 0.0, clip, t)
			var at := Vector3(0, 1.0, dz - 0.2)
			if falls:
				at = Vector3(0, 0.6, dz - 0.4)
			_cam(at, PI - 1.15, -0.45 if falls else -0.1, 3.9 if falls else 3.7, 40.0)
			tiles.append(await _grab("%s  %.2f s" % [clip, t]))
		var key := "debug" if not only.is_empty() else "falls" if falls else "missile" if (clip.begins_with("xbow") or clip.begins_with("bow")) \
			else "heavy" if (clip.begins_with("pole") or clip.begins_with("great") or clip.begins_with("levy")) else "foot"
		(sheets[key] as Array).append(_row(tiles, 6))
	for key: String in sheets:
		if not (sheets[key] as Array).is_empty():
			_msave(_stack(sheets[key]), "moves_" + key)


func _row(tiles: Array[Image], cols: int) -> Image:
	var tw := tiles[0].get_width() / 3
	var th := tiles[0].get_height() / 3
	var out := Image.create(tw * cols, th, false, Image.FORMAT_RGB8)
	out.fill(Color(0.12, 0.12, 0.12))
	for i in tiles.size():
		var t := tiles[i]
		t.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(t, Rect2i(0, 0, tw, th), Vector2i(i * tw, 0))
	return out


func _stack(rows: Array) -> Image:
	var w := (rows[0] as Image).get_width()
	var h := 0
	for r: Image in rows:
		h += r.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	var y := 0
	for r: Image in rows:
		out.blit_rect(r, Rect2i(0, 0, r.get_width(), r.get_height()), Vector2i(0, y))
		y += r.get_height()
	return out


# ---------------------------------------------------------------- formations

func _formations() -> void:
	_clear()
	var tiles: Array[Image] = []
	# The shield wall: two ranks of men-at-arms, the front locked, the second with swords up behind.
	var wall: Array[String] = []
	for i in 7:
		var nm := "w%d" % i
		_med(nm, 100 + i, "man_at_arms", i % 3)
		_mput(nm, Vector3(-2.1 + 0.62 * i, 0, 0), 0.0, "wall")
		wall.append(nm)
	for i in 6:
		var nm := "v%d" % i
		_med(nm, 120 + i, "man_at_arms", i % 3)
		_mput(nm, Vector3(-1.8 + 0.62 * i, 0, 0.75), 0.0, MC.poses("sword")["block"])
		wall.append(nm)
	_med("cap", 7, "captain", 0)
	_mput("cap", Vector3(0.3, 0, 1.7), 0.0, "guard")
	_med("ban", 8, "banner", 0)
	_mput("ban", Vector3(-0.6, 0, 1.75), 0.0, "stand")
	wall.append_array(["cap", "ban"])
	_cam(Vector3(0.0, 1.0, 0.5), PI - 0.45, -0.12, 7.5, 42.0)
	tiles.append(await _grab("the shield wall: front rank locked, second rank behind, captain and banner"))
	_cam(Vector3(0.0, 1.0, 0.5), 0.55, -0.3, 7.5, 42.0)
	tiles.append(await _grab("the shield wall from behind"))
	_hide(wall)
	# The spear hedge: the front rank kneels braced, the second levels over them, the third high overarm.
	var hedge: Array[String] = []
	for i in 7:
		var a := "s%d" % i
		_med(a, 200 + i, "spearman", 3 + i % 2)
		_mput(a, Vector3(-2.1 + 0.62 * i, 0, 0), 0.0, "brace")
		var b := "t%d" % i
		_med(b, 220 + i, "spearman", 3 + i % 2)
		_mput(b, Vector3(-1.85 + 0.62 * i, 0, 0.8), 0.0, "guard")
		var c := "u%d" % i
		_med(c, 240 + i, "spearman", 3 + i % 2)
		_mput(c, Vector3(-2.1 + 0.62 * i, 0, 1.6), 0.0, "high")
		hedge.append_array([a, b, c])
	_cam(Vector3(0.0, 0.9, 0.6), PI - 0.5, -0.1, 7.5, 42.0)
	tiles.append(await _grab("the spear hedge: braced, levelled, overarm"))
	_cam(Vector3(0.0, 0.7, -0.6), PI - 1.35, -0.05, 5.2, 42.0)
	tiles.append(await _grab("the hedge from the side: what a horse runs onto"))
	_hide(hedge)
	# The archer line behind its stakes; crossbows at their pavises.
	var line: Array[String] = []
	for i in 7:
		var nm := "a%d" % i
		_med(nm, 300 + i, "longbow", 5)
		_mplay(nm, Vector3(-2.4 + 0.8 * i, 0, 0.0 + 0.25 * (i % 2)), 0.0, "bow_volley", 1.5 + 0.05 * i)
		line.append(nm)
		_geo_prop(MB.stake(1.25, 0.75), Vector3(-2.2 + 0.8 * i, 0, -1.2 - 0.2 * (i % 2)), 0.0)
		_geo_prop(MB.stake(1.1, 0.7), Vector3(-2.6 + 0.8 * i, 0, -1.4 + 0.1 * (i % 2)), 10.0)
	for i in 4:
		var nm := "x%d" % i
		_med(nm, 320 + i, "crossbow", 2)
		_mput(nm, Vector3(3.6 + 0.9 * i, 0, -0.2), 0.0, "kneel_aim" if i % 2 == 0 else "span")
		_geo_prop(MB.pavise((men[nm] as Medieval).look["arms"]), Vector3(3.6 + 0.9 * i, 0, -0.9), 0.0)
		line.append(nm)
	_flight(Vector3(-1.0, 4.5, -5.0), Vector3(0, 0.55, -0.83), 18, 1.6, 7)
	_cam(Vector3(0.6, 1.0, -0.4), PI - 0.42, -0.12, 9.0, 42.0)
	tiles.append(await _grab("the archers loose over their stakes; crossbows at their pavises"))
	_cam(Vector3(0.6, 1.2, -0.4), 0.35, -0.2, 8.5, 42.0)
	tiles.append(await _grab("the volley in the air, from behind the line"))
	_msave(_tile(tiles, 2), "formations")


# ---------------------------------------------------------------- knights

func _knights() -> void:
	_clear()
	var tiles: Array[Image] = []
	_mount_k("k0", 3)
	_mount_k("k1", 8)
	_mount_k("sc", 5, "scout")
	_kride("k0", Vector3(-1.3, 0, 0), 0.0, Horse.stand_pose(), "lance_up")
	_kride("k1", Vector3(1.3, 0, 0.3), 0.0, Horse.gait_pose("walk", 0.3), "lance_up")
	_kride("sc", Vector3(3.6, 0, 0.5), 0.0, Horse.gait_pose("trot", 0.2), "javelin")
	_cam(Vector3(1.0, 1.4, 0), PI - 0.85, -0.08, 8.5, 42.0)
	tiles.append(await _grab("knights on barded horses, lances up; a light horse scout"))
	_cam(Vector3(1.0, 1.4, 0), PI + 1.1, -0.08, 8.5, 42.0)
	tiles.append(await _grab("the other side"))
	_kride("k0", Vector3(0, 0, 0), 0.0, Horse.gait_pose("charge", 0.15), "couch")
	_hide(["k1", "k1_h", "sc", "sc_h"])
	_cam(Vector3(0, 1.6, -0.5), PI - 0.6, -0.06, 5.0, 42.0)
	tiles.append(await _grab("the charge: lance couched at the gallop"))
	_kride("k0", Vector3(0, 0, 0), 0.0, Horse.gait_pose("charge", 0.45), "impact")
	_cam(Vector3(0, 1.6, -0.5), PI - 1.3, -0.06, 5.0, 42.0)
	tiles.append(await _grab("impact: the lance strikes home, the rider thrown back"))
	_kride("k0", Vector3(0, 0, 0), 0.0, Horse.gait_pose("trot", 0.1), "raise", "alt")
	_cam(Vector3(0, 1.6, -0.5), PI - 0.7, -0.06, 5.0, 42.0)
	tiles.append(await _grab("sword drawn from the saddle"))
	_kride("k0", Vector3(0, 0, 0), 0.0, Horse.gait_pose("trot", 0.4), "cut", "alt")
	_cam(Vector3(0, 1.6, -0.5), PI - 1.6, -0.06, 5.0, 42.0)
	tiles.append(await _grab("the cut from the saddle"))
	_msave(_tile(tiles, 3), "knights")


# ---------------------------------------------------------------- fights against our troops

func _fights() -> void:
	_clear()
	var tiles: Array[Image] = []
	var aim_o := F.aim(false)
	var kneel_o: Dictionary = R.poses()["kneel"]
	var ox: Array[float] = [-3.0, -1.5, 0.0, 1.5, 3.0]
	for i in 5:
		_ours("o%d" % i, 400 + i)
	# 1: the host comes on: the shield wall and banners at the march, our line fires; a man-at-arms is hit.
	var host: Array[String] = []
	for i in 9:
		var nm := "h%d" % i
		var role := "man_at_arms" if i != 4 else "banner"
		_med(nm, 410 + i, role, i % 3)
		host.append(nm)
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, aim_o if i % 2 == 0 else kneel_o)
		_shot("o%d" % i, 0.05 + 0.15 * i)
	for i in 9:
		var at := Vector3(-3.2 + 0.8 * i, 0, -10.0 + 0.2 * (i % 2))
		if i == 6:
			_mplay("h%d" % i, at, 180.0, "sword_death_back", 0.5)
		else:
			_mplay("h%d" % i, at, 180.0, "march", 0.13 * i)
	_cam(Vector3(0.0, 1.0, -5.0), 1.15, -0.16, 11.5, 44.0)
	tiles.append(await _grab("1  the host comes on behind its banner; our line opens fire"))
	# 2: a volley of arrows drops on our line; men duck, one is hit.
	_hide(host)
	for i in 5:
		var spec: Dictionary = F.duck(false) if i != 2 else {}
		if i == 2:
			_mplay("o2", Vector3(ox[2], 0, 0), 0.0, "death_forward", 0.9)
		else:
			_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, spec if i % 2 == 1 else kneel_o)
	_flight(Vector3(0.0, 4.5, -3.0), Vector3(0, -0.6, 0.8), 26, 3.2, 11)
	_stuck(Vector3(0.0, 0, -0.3), 22, 3.5, 12)
	for i in 6:
		var nm := "b%d" % i
		_med(nm, 430 + i, "longbow", 5)
		_mplay(nm, Vector3(-2.5 + 1.0 * i, 0, -26.0), 180.0, "bow_volley", 1.75 + 0.03 * i)
	_cam(Vector3(0.0, 1.2, -1.5), 0.9, -0.12, 9.0, 46.0)
	tiles.append(await _grab("2  the arrow storm: our men take cover, one is struck"))
	_clear_arrows()
	for i in 6:
		(men["b%d" % i] as Node3D).visible = false
	# 3: knights charge our line, lances couched; the fire brings a horse down.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, aim_o if i % 2 == 0 else kneel_o)
		_shot("o%d" % i, 0.05 + 0.12 * i)
	for i in 4:
		_mount_k("k%d" % i, 450 + i)
	var kx: Array[float] = [-3.0, -1.0, 1.1, 3.1]
	for i in 4:
		if i == 2:
			_kride("k2", Vector3(kx[2], 0, -9.0), 180.0, Horse.fall_pose(0.4), "impact")
		else:
			_kride("k%d" % i, Vector3(kx[i], 0, -9.5 - 0.6 * (i % 2)), 180.0, Horse.gait_pose("charge", 0.17 * i), "couch")
	_cam(Vector3(0.0, 1.3, -4.8), 1.0, -0.14, 11.0, 44.0)
	tiles.append(await _grab("3  knights charge, lances couched; a horse brought down"))
	for i in 4:
		_hide(["k%d" % i, "k%d_h" % i])
	# 4: the melee: men-at-arms and a heavy against our bayonets.
	_med("m0", 470, "man_at_arms", 1)
	_med("m1", 471, "heavy", 2, 0, "halberd")
	_med("m2", 472, "man_at_arms", 0)
	_med("m3", 473, "levy", 3, 0, "pitchfork")
	_mplay("m0", Vector3(-2.4, 0, -0.9), 180.0, "sword_strike", 0.6)
	_put("o0", Vector3(-2.5, 0, 0.3), 0.0, F.parry(false))
	_mplay("m1", Vector3(-0.6, 0, -1.2), 180.0, "pole_strike", 0.75)
	_mplay("o1", Vector3(-0.6, 0, 0.6), 0.0, "death_back", 0.45)
	_mplay("m2", Vector3(1.2, 0, -0.8), 180.0, "sword_block", 0.3)
	_put("o3", Vector3(1.25, 0, 0.35), 0.0, F.lunge(false))
	_mplay("m3", Vector3(3.0, 0, -1.4), 180.0, "levy_death_back", 0.5)
	_put("o4", Vector3(3.0, 0, 0.2), 0.0, aim_o)
	_shot("o4", 0.05)
	_hide(["o2"])
	_cam(Vector3(0.3, 1.1, -0.4), 0.62, -0.14, 7.6, 44.0)
	tiles.append(await _grab("4  the melee: sword on a parried bayonet, a halberd blow, a lunge on a shield"))
	_hide(["m0", "m1", "m2", "m3", "o0", "o1", "o3", "o4"])
	# 5: our armoured wall meets the levy rabble.
	for i in 4:
		_arm("a%d" % i, 480 + i, "shield")
		_mplay("a%d" % i, Vector3(-1.8 + 1.2 * i, 0, 0), 0.0, "shield_bash" if i % 2 == 0 else "shield_block", 0.45)
	_arm("ac", 485, "club")
	_mplay("ac", Vector3(0.0, 0, 1.1), 0.0, "club_smash", 0.62)
	var lv: Array = ["pitchfork", "flail", "billhook", "pitchfork", "billhook", "flail"]
	for i in 6:
		var nm := "l%d" % i
		_med(nm, 490 + i, "levy", i % 6, 0, lv[i])
		var at := Vector3(-2.2 + 0.9 * i, 0, -1.2 - 0.4 * (i % 2))
		match i:
			1:
				_mplay(nm, at, 180.0, "levy_death_back", 0.7)
			4:
				_mplay(nm, at + Vector3(0, 0, -0.2), 180.0, "levy_hit", 0.1)
			_:
				_mplay(nm, at, 180.0, "levy_strike" if i % 2 == 0 else "levy_sweep", 0.55 + 0.1 * i)
	_cam(Vector3(0.0, 1.0, -0.6), 2.35, -0.16, 7.6, 44.0)
	tiles.append(await _grab("5  our armoured shield wall against the levy: bash, block, the club over the top"))
	# 6: plate against plate: a heavy's pole-axe on our shield man; a greatsword against the club man.
	for i in 6:
		(men["l%d" % i] as Node3D).visible = false
	_hide(["a0", "a3", "ac"])
	_med("p0", 500, "heavy", 0, 0, "poleaxe")
	_med("p1", 501, "heavy", 4, 0, "greatsword")
	_med("p2", 502, "captain", 2)
	_mplay("p0", Vector3(-0.6, 0, -1.1), 180.0, "pole_strike", 0.68)
	_mplay("a1", Vector3(-0.6, 0, 0.1), 0.0, "shield_block", 0.28)
	_mplay("p1", Vector3(1.0, 0, -1.0), 180.0, "great_sweep", 0.62)
	_arm("c2", 503, "club")
	_mplay("c2", Vector3(1.1, 0, 0.1), 0.0, "club_swing", 0.5)
	_hide(["a2"])
	_mplay("p2", Vector3(0.2, 0, -2.6), 180.0, "sword_hold_guard", 0.0)
	_cam(Vector3(0.2, 1.1, -0.6), 1.35, -0.1, 6.0, 44.0)
	tiles.append(await _grab("6  plate on plate: a pole-axe on our shield, greatsword against club"))
	_msave(_tile(tiles, 3), "fights")


func _clear_arrows() -> void:
	for n in loose:
		if is_instance_valid(n):
			n.queue_free()
	loose.clear()
