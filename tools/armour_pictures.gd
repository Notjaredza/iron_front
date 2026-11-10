extends "res://tools/fight_pictures.gd"
## Armoured trench troops (Building Chat 1, 2026-11-10): the look sheet, the move sheets and stills against the red
## coats, in the explosion test's world (BlastStage). Needs a window:
##   Godot --path iron_front --resolution 1600x900 -s res://tools/armour_pictures.gd -- [look moves]  (the battle stills come from the battle video, armour_clips.gd)
## Writes results/units/armour/armour_*.png.

const AR := preload("res://scripts/units/anim/clips_armour.gd")
const AOUT := "res://results/units/armour/"

var ar_lib: Dictionary


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AOUT))
	rc_lib = Redcoat.library()
	our_lib = R.library()
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
	for mode in (args if not args.is_empty() else ["look", "moves"]):
		match mode:
			"look":
				await _look()
			"moves":
				await _moves()
	print("ARMOUR PICTURES OK")
	quit()


func _arm(name: String, seed_value: int, role: String, lod := 0) -> Armoured:
	var a := Armoured.new()
	a.setup(seed_value, lod, role)
	stage.add_child(a)
	_keep(a)
	men[name] = a
	return a


## An armoured man in a pose spec (or a named pose) at a spot.
func _aput(name: String, at: Vector3, yaw: float, spec: Variant) -> void:
	var m: Armoured = men[name]
	var p: Dictionary = AR.poses(m.role)[spec] if spec is String else spec
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	m.show_spec(p)


func _aplay(name: String, at: Vector3, yaw: float, clip: String, t: float) -> void:
	var m: Soldier = men[name]
	if not (m is Armoured):
		_play(name, at, yaw, clip, t)
		return
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	m.show_clip(ar_lib[clip], t)


func _asave(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(AOUT + "armour_" + name + ".png"))
	print("saved armour_", name)


func _alen(clip: String) -> float:
	return float(ar_lib[clip]["len"])


# ---------------------------------------------------------------- look

func _look() -> void:
	_clear()
	var tiles: Array[Image] = []
	_arm("s", 1, "shield")
	for i in 3:
		_arm_with("c%d" % i, 2 + i, AB_WEAPONS[i])
	var xs: Array[float] = [-1.5, -0.4, 0.6, 1.6]
	var names: Array[String] = ["s", "c0", "c1", "c2"]
	for i in 4:
		_aput(names[i], Vector3(xs[i], 0, 0), 0.0, "stand")
	_cam(Vector3(0.05, 1.0, 0), PI - 0.55, -0.1, 5.6)
	tiles.append(await _grab("shield man; club men with club, mace, spade"))
	_cam(Vector3(0.05, 1.0, 0), 0.6, -0.12, 5.6)
	tiles.append(await _grab("from behind"))
	for i in 4:
		_aput(names[i], Vector3(xs[i], 0, 0), 0.0, "wall" if i == 0 else "guard")
	_cam(Vector3(0.05, 1.0, 0), PI - 0.35, -0.08, 5.2)
	tiles.append(await _grab("shield up; clubs raised"))
	for i in 4:
		(men[names[i]] as Node3D).visible = false
	_aput("s", Vector3(-0.3, 0, 0), 0.0, "stand")
	_aput("c1", Vector3(0.45, 0, 0), 0.0, "stand")
	_cam(Vector3(0.1, 1.45, 0), PI - 0.4, -0.04, 2.3, 40.0)
	tiles.append(await _grab("close: the visor, the plates, the shield's slit"))
	(men["s"] as Node3D).visible = false
	(men["c1"] as Node3D).visible = false
	for lod in 3:
		_arm("ls%d" % lod, 1, "shield", lod)
		_aput("ls%d" % lod, Vector3(-2.2 + 1.5 * lod, 0, 0), 0.0, "stand")
		_arm_with("lc%d" % lod, 3, "mace", lod)
		_aput("lc%d" % lod, Vector3(-1.5 + 1.5 * lod, 0, 0.4), 0.0, "stand")
	_cam(Vector3(0.0, 1.0, 0.2), PI - 0.5, -0.12, 6.5)
	var tri := []
	for lod in 3:
		tri.append("%d / %d" % [(men["ls%d" % lod] as Armoured).tri_count(), (men["lc%d" % lod] as Armoured).tri_count()])
	tiles.append(await _grab("close / mid / far (triangles, shield man / club man: %s)" % ", ".join(tri)))
	print("tris ", tri)
	for lod in 3:
		(men["ls%d" % lod] as Node3D).visible = false
		(men["lc%d" % lod] as Node3D).visible = false
	for i in 5:
		_arm("w%d" % i, 11 + i, "shield")
		_aput("w%d" % i, Vector3(-2.6 + 0.66 * i, 0, 0), 0.0, "wall")
	for i in 3:
		_arm_with("wc%d" % i, 21 + i, AB_WEAPONS[i])
		_aput("wc%d" % i, Vector3(-2.0 + 0.66 * i * 1.0 + 0.33, 0, 0.9), 0.0, "wall")
	_cam(Vector3(-1.3, 1.0, 0.3), PI - 0.3, -0.1, 6.5)
	tiles.append(await _grab("the shield wall, club men behind"))
	_asave(_tile(tiles, 3), "look")


const AB_WEAPONS: Array[String] = ["club", "mace", "spade"]


func _arm_with(name: String, seed_value: int, weapon: String, lod := 0) -> Armoured:
	var a := Armoured.new()
	a.weapon_override = weapon
	a.setup(seed_value, lod, "club")
	stage.add_child(a)
	_keep(a)
	men[name] = a
	return a


# ---------------------------------------------------------------- moves

func _moves() -> void:
	var rows: Array = [
		["shield_walk", "shield", 6], ["shield_wall_lock", "shield", 4], ["shield_wall_step", "shield", 6],
		["shield_strike", "shield", 6], ["shield_bash", "shield", 6], ["shield_block", "shield", 6],
		["shield_rush", "shield", 6], ["shield_pistol", "shield", 6],
		["club_walk", "club", 6], ["club_smash", "club", 6], ["club_swing", "club", 6], ["club_rush", "club", 6],
		["club_pistol", "club", 6], ["shield_hit", "shield", 4], ["shield_death_back", "shield", 6],
		["club_death_forward", "club", 6], ["shield_prone_to_stand", "shield", 6]]
	var sheets := {"shield": [], "club": [], "falls": []}
	for row: Array in rows:
		_clear()
		var clip: String = row[0]
		var role: String = row[1]
		var n: int = row[2]
		if role == "club":
			_arm_with("m", 7, "mace")
		else:
			_arm("m", 6, "shield")
		var c: Dictionary = ar_lib[clip]
		var L := float(c["len"])
		var tiles: Array[Image] = []
		for k in n:
			var t := L * k / float(n - 1 if not c.get("loop", false) else n)
			var dz := -float(c.get("speed", 0.0)) * t
			_aplay("m", Vector3(0, 0, dz), 0.0, clip, t)
			var at := Vector3(0, 0.95, dz - 0.2)
			if clip.contains("death") or clip.contains("prone"):
				at = Vector3(0, 0.6, dz - 0.4)
			var low_cam := clip.contains("death") or clip.contains("prone")
			_cam(at, PI - 1.15, -0.5 if low_cam else -0.1, 3.8 if low_cam else 3.4, 40.0)
			tiles.append(await _grab("%s  %.2f s" % [clip, t]))
		var key := "falls" if (clip.contains("death") or clip.contains("hit") or clip.contains("prone")) else role
		(sheets[key] as Array).append(_row(tiles, 6))
	for key: String in sheets:
		_asave(_stack(sheets[key]), "moves_" + key)


## One row of tiles at a third of the size, padded to cols.
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


