extends "res://tools/fight_pictures.gd"
## The engineer section (Building Chat 1, 2026-11-10): the look sheet, the moves sheet and one sheet per job, each job
## shown in six moments as the work grows. In the explosion test's world (BlastStage). Needs a window:
##   Godot --path iron_front --resolution 1600x900 -s res://tools/engineer_pictures.gd -- [look moves dig build wire wreck track]
## Writes results/units/engineers/eng_*.png.

const E := preload("res://scripts/units/anim/clips_engineer.gd")
const EB := preload("res://scripts/units/engineer_builder.gd")
const W := preload("res://scripts/units/engineer_works.gd")
const EOUT := "res://results/units/engineers/"

var e_lib: Dictionary


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EOUT))
	rc_lib = Redcoat.library()
	our_lib = R.library()
	e_lib = Engineer.library()
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
	for mode in (args if not args.is_empty() else ["look", "moves", "dig", "build", "wire", "wreck", "track"]):
		match mode:
			"look":
				await _look()
			"moves":
				await _moves()
			"dig":
				await _dig()
			"build":
				await _build()
			"wire":
				await _wire()
			"wreck":
				await _wreck()
			"track":
				await _track()
	print("ENGINEER PICTURES OK")
	quit()


# ---------------------------------------------------------------- helpers

func _eng(name: String, seed_value: int, role := "sapper", lod := 0) -> Engineer:
	var e := Engineer.new()
	e.setup(seed_value, lod, role)
	stage.add_child(e)
	_keep(e)
	men[name] = e
	return e


func _epose(name: String, at: Vector3, yaw: float, spec: Variant) -> void:
	var m: Engineer = men[name]
	var p: Dictionary = E.poses()[spec] if spec is String else spec
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	m.show_spec(p)


func _eplay(name: String, at: Vector3, yaw: float, clip: String, t: float) -> void:
	var m: Engineer = men[name]
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	m.show_clip(e_lib[clip], t)


## A clip's moment by fraction of its length.
func _eat(name: String, at: Vector3, yaw: float, clip: String, u: float) -> void:
	_eplay(name, at, yaw, clip, float(e_lib[clip]["len"]) * u)


func _hide(names: Array) -> void:
	for n: String in names:
		(men[n] as Node3D).visible = false


func _work(g: UnitGeo, at: Vector3, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not g.pos.is_empty():
		mi.mesh = g.to_mesh(Soldier.material())
	mi.position = at + Vector3(0, gy, 0)
	mi.rotation = Vector3(0, deg_to_rad(yaw), 0)
	stage.add_child(mi)
	_keep(mi)
	return mi


func _drop(nodes: Array) -> void:
	for n: Node in nodes:
		if is_instance_valid(n):
			things.erase(n)
			n.queue_free()


func _esave(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(EOUT + "eng_" + name + ".png"))
	print("saved eng_", name)


## World position of a man's right palm.
func _palm(name: String, right := true) -> Vector3:
	var m: Soldier = men[name]
	var fa := B.FARM_R if right else B.FARM_L
	var hd := B.HAND_R if right else B.HAND_L
	var hx := m.skel.get_bone_global_pose(hd)
	var d := (B.REST[hd] - B.REST[fa]).normalized()
	return m.global_transform * (hx * (d * B.PALM))


# ---------------------------------------------------------------- look

func _look() -> void:
	_clear()
	var tiles: Array[Image] = []
	_eng("n", 1, "nco")
	for i in 3:
		_eng("s%d" % i, 2 + i)
	var names: Array[String] = ["n", "s0", "s1", "s2"]
	var xs: Array[float] = [-1.5, -0.5, 0.5, 1.5]
	for i in 4:
		_epose(names[i], Vector3(xs[i], 0, 0), 0.0, "plan" if i == 0 else "stand")
	_cam(Vector3(0.0, 1.0, 0), PI - 0.5, -0.1, 5.4)
	tiles.append(await _grab("the section: the NCO with the plan, three sappers (rifles slung)"))
	_cam(Vector3(0.0, 1.0, 0), 0.55, -0.12, 5.4)
	tiles.append(await _grab("from behind"))
	# Each with his tools: shovel on the shoulder, plank, coil, the pick.
	_eat("n", Vector3(-1.5, 0, 0), 0.0, "eng_nco_check", 0.55)
	_eat("s0", Vector3(-0.5, 0, 0), 0.0, "eng_walk", 0.1)
	_eat("s1", Vector3(0.6, 0, 0), 0.0, "eng_walk_coil", 0.1)
	_eat("s2", Vector3(1.7, 0, 0), 0.0, "eng_walk_plank", 0.1)
	_cam(Vector3(0.0, 1.0, 0), PI - 0.6, -0.1, 5.6)
	tiles.append(await _grab("carrying: shovel, wire coil, plank; the NCO points"))
	_hide(names)
	_epose("n", Vector3(-0.35, 0, 0), 0.0, "plan")
	_epose("s1", Vector3(0.4, 0, 0), 0.0, "stand")
	_cam(Vector3(0.05, 1.4, 0), PI - 0.45, -0.06, 2.4, 40.0)
	tiles.append(await _grab("close: rolled sleeves, gloves, hatchet frog, sapper's patch, the plan"))
	_hide(names)
	# The kit laid out on the ground.
	var kit: Array[String] = ["pick", "shovel", "mallet", "saw", "hammer", "cutters", "bar", "coil"]
	for i in kit.size():
		var g := EB.tool(kit[i], 0)
		var mi := _work(g, Vector3(-1.4 + 0.4 * i, 0.04, 0.3), 0.0)
		mi.rotation = Vector3(PI * 0.5 if kit[i] == "coil" else 0.0, 0.0, PI * 0.5)
		mi.position.y += 0.02 if kit[i] != "coil" else 0.2
	_work(EB.plan(0), Vector3(1.8, 0.0, 0.3))
	_work(W.plank_stack(0.6), Vector3(0.2, 0, -0.9))
	_cam(Vector3(0.2, 0.1, 0.0), PI, -0.75, 3.6, 42.0)
	tiles.append(await _grab("the kit: pick, shovel, maul, saw, hammer, cutters, bar, wire coil; the plan; planks"))
	_clear()
	for lod in 3:
		_eng("ln%d" % lod, 1, "nco", lod)
		_epose("ln%d" % lod, Vector3(-2.2 + 1.5 * lod, 0, 0), 0.0, "plan")
		_eng("ls%d" % lod, 3, "sapper", lod)
		_eat("ls%d" % lod, Vector3(-1.5 + 1.5 * lod, 0, 0.4), 0.0, "eng_walk", 0.1)
	var tri := []
	for lod in 3:
		tri.append("%d / %d" % [(men["ln%d" % lod] as Engineer).tri_count(), (men["ls%d" % lod] as Engineer).tri_count()])
	print("tris ", tri)
	_cam(Vector3(0.0, 1.0, 0.2), PI - 0.5, -0.12, 6.5)
	tiles.append(await _grab("close / mid / far (triangles, NCO / sapper: %s)" % ", ".join(tri)))
	_esave(_tile(tiles, 3), "look")


# ---------------------------------------------------------------- moves

func _moves() -> void:
	var rows: Array = [["eng_walk", 6], ["eng_walk_plank", 6], ["eng_walk_coil", 6], ["eng_walk_panel", 6],
		["eng_pick", 6], ["eng_shovel", 6], ["eng_saw", 4], ["eng_hammer", 4], ["eng_hammer_low", 4], ["eng_drive", 5],
		["eng_hold", 3], ["eng_cut", 6], ["eng_prise", 5], ["eng_lift", 5], ["eng_spike", 5], ["eng_nco_check", 6],
		["eng_death_back", 5], ["eng_death_forward", 5]]
	var out: Array = []
	var only := OS.get_environment("ENG_ONLY")
	for row: Array in rows:
		if not only.is_empty() and not (row[0] as String) in only.split(","):
			continue
		_clear()
		var clip: String = row[0]
		var n: int = row[1]
		_eng("m", 1 if clip.contains("nco") else 4, "nco" if clip.contains("nco") else "sapper")
		var c: Dictionary = e_lib[clip]
		var L := float(c["len"])
		var tiles: Array[Image] = []
		for k in n:
			var t := L * k / float(n if c.get("loop", false) else n - 1)
			var dz := -float(c.get("speed", 0.0)) * t
			_eplay("m", Vector3(0, 0, dz), 0.0, clip, t)
			var low := clip.contains("death") or clip.contains("hold") or clip.contains("lift") or clip.contains("cut")
			_cam(Vector3(0, 0.6 if low else 0.95, dz - 0.25), PI - 1.15, -0.3 if low else -0.12, 3.6, 40.0)
			tiles.append(await _grab("%s  %.2f s" % [clip, t]))
		out.append(_row(tiles, 6))
	_esave(_stack(out), "moves" if only.is_empty() else "debug")


func _row(tiles: Array[Image], cols: int) -> Image:
	var tw := tiles[0].get_width() / 3
	var th := tiles[0].get_height() / 3
	var img := Image.create(tw * cols, th, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.12, 0.12))
	for i in tiles.size():
		var t := tiles[i]
		t.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(t, Rect2i(0, 0, tw, th), Vector2i(i * tw, 0))
	return img


func _stack(rows: Array) -> Image:
	var w := (rows[0] as Image).get_width()
	var h := 0
	for r: Image in rows:
		h += r.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var y := 0
	for r: Image in rows:
		img.blit_rect(r, Rect2i(0, 0, r.get_width(), r.get_height()), Vector2i(0, y))
		y += r.get_height()
	return img


# ---------------------------------------------------------------- 1. dig a trench

const TOP := 1.3     # the ground slab's top (the pit is cut into it)
const PIT_X := 2.0   # half length
const PIT_Z := 0.6   # half width


func _slab(depth: float) -> Array:
	var made: Array = []
	made.append(_block(Vector3(0, TOP * 0.5, -PIT_Z - 7.0), Vector3(10, TOP * 0.5, 7.0), EARTH))
	made.append(_block(Vector3(0, TOP * 0.5, PIT_Z + 7.0), Vector3(10, TOP * 0.5, 7.0), EARTH))
	for s: float in [1.0, -1.0]:
		made.append(_block(Vector3(s * (PIT_X + 4.0), TOP * 0.5, 0), Vector3(4.0, TOP * 0.5, PIT_Z), EARTH))
	var fl := TOP - depth
	if fl > 0.01:
		made.append(_block(Vector3(0, fl * 0.5, 0), Vector3(PIT_X, fl * 0.5, PIT_Z), W.EARTH_FRESH))
	return made


func _dig() -> void:
	_clear()
	_eng("n", 1, "nco")
	_eng("a", 2)
	_eng("b", 3)
	_eng("c", 4)
	var tiles: Array[Image] = []
	var labels: Array[String] = ["marked out: the tape and pegs, the NCO reads the plan; first picks go in",
		"knee deep: picking the face, shovelling forward onto the parapet", "waist deep",
		"chest deep: the spoil heap becomes the parapet", "nearly there: the NCO checks the depth",
		"done: full depth, duckboards down, parapet up"]
	for k in 6:
		var p := k / 5.0
		var depth := TOP * p
		var made := _slab(depth)
		var fy := TOP - depth  # the floor
		made.append(_work(W.spoil(p, PIT_X * 2.0 + 0.6), Vector3(0, TOP, -PIT_Z - 0.05)))
		if k == 0:
			made.append(_work(W.trench_tape(PIT_X * 2.0, PIT_Z * 2.0), Vector3(0, TOP, 0)))
		if k == 5:
			made.append(_work(W.duckboards(PIT_X * 2.0 - 0.2), Vector3(0, fy, 0)))
		var ph: float = [0.1, 0.4, 0.6, 0.35, 0.55, 0.0][k]
		if k < 5:
			_eat("a", Vector3(-1.2, fy, 0.05), -90.0, "eng_pick", ph)
			_eat("b", Vector3(0.5, fy, 0.25), 0.0, "eng_shovel", fposmod(ph + 0.3, 1.0))
			_eat("c", Vector3(1.4, fy, 0.25), 0.0, "eng_shovel", fposmod(ph + 0.75, 1.0))
		else:
			_epose("a", Vector3(-1.0, fy + 0.08, 0.1), 20.0, "shovel_rest")
			_epose("b", Vector3(0.3, fy + 0.08, 0.1), -10.0, "stand")
			_epose("c", Vector3(1.3, fy + 0.08, 0.15), 30.0, "shovel_rest")
		if k == 4:
			_eat("n", Vector3(-PIT_X - 0.5, TOP, 0.5), -100.0, "eng_nco_check", 0.6)
		else:
			_eat("n", Vector3(-PIT_X - 0.6, TOP, 0.9), -110.0, "eng_nco_check", [0.1, 0.55, 0.2, 0.6, 0.6, 0.15][k])
		_cam(Vector3(-0.3, TOP - 0.3, 0), 1.05, -0.5, 6.6)
		tiles.append(await _grab("%d  %s" % [k + 1, labels[k]]))
		_drop(made)
	_esave(_tile(tiles, 3), "dig")


# ---------------------------------------------------------------- 2. build a plank wall

func _build() -> void:
	_clear()
	_eng("n", 1, "nco")
	_eng("a", 2)
	_eng("b", 3)
	_eng("c", 4)
	var tiles: Array[Image] = []
	var labels: Array[String] = ["posts in; planks stacked; the first cut", "the first planks nailed on, low",
		"sawing to length, carrying, nailing", "halfway", "nailing the high rows", "done: the plank wall up, the stack used"]
	for k in 6:
		var p := k / 5.0
		var made: Array = []
		made.append(_work(W.plank_wall(p), Vector3(0, 0, 0), 180.0))
		made.append(_work(W.plank_stack(p), Vector3(-3.6, 0, 1.6), 90.0))
		made.append(_work(W.trestle(fposmod(0.3 + 0.37 * k, 1.0)), Vector3(2.8, 0, 0.9)))
		var n := int(round(p * W.WALL_PLANKS))
		var h := 0.1 + 0.2 * maxi(n - 1, 0)
		if k < 5:
			var clip := "eng_hammer_low" if h < 0.7 else "eng_hammer"
			_eat("a", Vector3(-0.5, 0, 0.52), 0.0, clip, [0.0, 0.35, 0.5, 0.2, 0.36][k])
			_eat("b", Vector3(2.8 + 0.85 + 0.16, 0, 0.9 - 0.55), 180.0, "eng_saw", [0.1, 0.5, 0.0, 0.5, 0.25][k])
			var cx := lerpf(-3.0, -1.2, [0.0, 0.5, 0.9, 0.3, 0.7][k])
			_eat("c", Vector3(cx, 0, 1.2), -90.0, "eng_walk_plank", 0.2 * k)
		else:
			_epose("a", Vector3(-0.6, 0, 1.0), 10.0, "stand")
			_epose("b", Vector3(0.9, 0, 1.3), -15.0, "stand")
			_epose("c", Vector3(-1.6, 0, 1.4), 20.0, "stand")
		_eat("n", Vector3(-1.4, 0, 2.8), 15.0, "eng_nco_check", [0.1, 0.55, 0.2, 0.7, 0.55, 0.0][k])
		_cam(Vector3(0.6, 0.8, 0.6), 0.45, -0.26, 8.6)
		tiles.append(await _grab("%d  %s" % [k + 1, labels[k]]))
		_drop(made)
	_esave(_tile(tiles, 3), "build")


# ---------------------------------------------------------------- 3. barbed wire

func _wire() -> void:
	_clear()
	_eng("n", 1, "nco")
	_eng("a", 2)
	_eng("b", 3)
	_eng("c", 4)
	var tiles: Array[Image] = []
	var labels: Array[String] = ["the first picket: the maul drives it, the mate holds it", "the coil paid out to the next picket",
		"cut, and tied off on the picket", "two bays strung", "four bays", "done: five bays of wire, two strands and diagonals"]
	var ps: Array[float] = [0.08, 0.3, 0.38, 0.5, 0.82, 1.0]
	for k in 6:
		var p := ps[k]
		var made: Array = [_work(W.wire(p), Vector3(-6.0, 0, 0))]
		var done := p * 5.0
		var full := int(floor(done))
		var part := done - full
		var xc := -6.0 + W.PICKET_GAP * full
		if k < 5:
			_eat("a", Vector3(xc, 0, 0.62), 0.0, "eng_drive", [0.0, 0.5, 0.2, 0.5, 0.0][k])
			_eat("b", Vector3(xc - 0.5, 0, -0.05), -90.0, "eng_hold", 0.2)
			var reach := clampf((part - 0.5) * 2.0, 0.0, 1.0)
			var cx := xc - W.PICKET_GAP + W.PICKET_GAP * reach if full > 0 else xc - 1.2
			if k == 0:
				_eat("c", Vector3(xc - 1.6, 0, -0.5), -60.0, "eng_walk_coil", 0.0)
			elif k % 2 == 0:
				_eat("c", Vector3(xc - W.PICKET_GAP + 0.5, 0, 0.55), 0.0, "eng_cut", [0.0, 0.3, 0.3, 0.8, 0.3][k])
			else:
				_eat("c", Vector3(cx - 0.6, 0, -0.3), -90.0, "eng_walk_coil", 0.3)
		else:
			_epose("a", Vector3(4.5, 0, 0.9), 170.0, "stand")
			_epose("b", Vector3(3.6, 0, 1.0), 200.0, "stand")
			_epose("c", Vector3(2.5, 0, 1.1), 190.0, "stand")
		_eat("n", Vector3(xc - 2.0, 0, 1.8), -20.0, "eng_nco_check", [0.1, 0.55, 0.2, 0.6, 0.55, 0.6][k])
		_cam(Vector3(xc - 1.4 if k < 5 else 0.0, 0.7, 0.0), PI - 0.75, -0.3, 8.5 if k < 5 else 12.5)
		tiles.append(await _grab("%d  %s" % [k + 1, labels[k]]))
		_drop(made)
	_esave(_tile(tiles, 3), "wire")


# ---------------------------------------------------------------- 4. strip a wreck

func _wreck() -> void:
	_clear()
	_eng("n", 1, "nco")
	_eng("a", 2)
	_eng("b", 3)
	_eng("c", 4)
	var tiles: Array[Image] = []
	var labels: Array[String] = ["the wreck: the NCO marks what to take", "the bar in the seam: the first panel springs",
		"panels carried to the pile", "half the side off: the ribs show", "the last panels", "stripped: the panels stacked for use"]
	var s := W.hull_size() * 0.5
	var order := [4, 3, 5, 1, 0, 2]
	for k in 6:
		var p := k / 5.0
		var gone := int(round(p * 6.0))
		var made: Array = [_work(W.wreck(p), Vector3(0, 0, 0)), _work(W.panel_pile(p), Vector3(3.4, 0, 2.6), 10.0)]
		if k < 5:
			var nxt: int = order[mini(gone, 5)]
			var cx := -s.x + s.x / 3.0 + 2.0 * s.x / 3.0 * (nxt % 3)
			_eat("a", Vector3(cx, 0, s.z + 0.62), 0.0, "eng_prise", [0.0, 0.42, 0.2, 0.5, 0.45][k])
			_eat("b", Vector3(lerpf(0.5, 2.6, [0.3, 0.6, 0.4, 0.8, 0.5][k]), 0, 2.2), -70.0, "eng_walk_panel", 0.25 * k)
			_eat("c", Vector3(cx + 0.9, 0, s.z + 0.7), -20.0, "eng_hold_stand" if k == 0 else "eng_prise", [0.0, 0.0, 0.6, 0.1, 0.8][k])
		else:
			_epose("a", Vector3(1.5, 0, 2.0), 150.0, "stand")
			_epose("b", Vector3(2.4, 0, 3.4), 200.0, "stand")
			_epose("c", Vector3(0.6, 0, 2.3), 170.0, "stand")
		_eat("n", Vector3(-2.2, 0, 2.2), 140.0, "eng_nco_check", [0.6, 0.2, 0.55, 0.1, 0.6, 0.0][k])
		_cam(Vector3(0.5, 0.9, 1.0), 0.25, -0.24, 7.6)
		tiles.append(await _grab("%d  %s" % [k + 1, labels[k]]))
		_drop(made)
	_esave(_tile(tiles, 3), "wreck")


# ---------------------------------------------------------------- 5. track repair

func _track() -> void:
	_clear()
	_eng("n", 1, "nco")
	_eng("a", 2)
	_eng("b", 3)
	_eng("c", 4)
	var tiles: Array[Image] = []
	var labels: Array[String] = ["the split sleeper: spikes drawn with the bar", "the bay cleared, the ballast dug out",
		"the new sleeper lifted: the NCO joins the heavy lift", "carried in and set under the rails",
		"spiked home with the maul", "done: the track mended"]
	var stages: Array[String] = ["broken", "out", "out", "new", "new", "spiked"]
	var gz := W.GAUGE * 0.5
	for k in 6:
		var made: Array = [_work(W.track(stages[k]), Vector3(0, 0, 0))]
		_hide(["n", "a", "b", "c"])
		match k:
			0:
				_eat("a", Vector3(0.0, 0.06, gz + 0.68), 0.0, "eng_prise", 0.4)
				_eat("b", Vector3(0.3, 0.06, -gz - 0.68), 180.0, "eng_prise", 0.0)
				_eat("n", Vector3(1.4, 0, -2.6), 160.0, "eng_nco_check", 0.55)
				_epose("c", Vector3(-1.6, 0, 2.4), 160.0, "shovel_rest")
			1:
				_eat("a", Vector3(0.0, 0.06, 0.4), -90.0, "eng_shovel", 0.0)
				_eat("b", Vector3(0.1, 0.06, -0.6), 90.0, "eng_shovel", 0.55)
				_eat("n", Vector3(1.4, 0, -2.6), 160.0, "eng_nco_check", 0.1)
				_epose("c", Vector3(-1.4, 0, 2.6), 170.0, "stand")
			2, 3:
				# The sleeper across the line of the men, its ends in their hands; they face each other along Z.
				var zc := -3.2 if k == 2 else 0.0
				var u := 0.6 if k == 2 else 0.0
				_eplay("n", Vector3(0, 0.0 if k == 2 else 0.06, zc + 1.5), 180.0, "eng_lift", float(e_lib["eng_lift"]["len"]) * u)
				_eplay("a", Vector3(0, 0.0 if k == 2 else 0.06, zc - 1.5), 0.0, "eng_lift", float(e_lib["eng_lift"]["len"]) * u)
				var y := (_palm("n").y + _palm("a").y) * 0.5 - gy - 0.16
				if k == 2:
					made.append(_work(W.sleeper(W.TIMBER_NEW.darkened(0.15)), Vector3(0, y, zc), 90.0))
				_epose("b", Vector3(-2.6, 0, 1.4), 140.0, "shovel_rest")
				_epose("c", Vector3(-3.0, 0, -1.2), 120.0, "stand")
			4:
				_eat("a", Vector3(0.0, 0.06, gz + 0.62), 0.0, "eng_spike", 0.45)
				_eat("b", Vector3(0.0, 0.06, -gz - 0.62), 180.0, "eng_spike", 0.05)
				_eat("n", Vector3(1.4, 0, -2.6), 160.0, "eng_nco_check", 0.6)
				_epose("c", Vector3(-1.4, 0, 2.6), 170.0, "shovel_rest")
			5:
				_epose("a", Vector3(-0.8, 0, 2.2), 170.0, "stand")
				_epose("b", Vector3(0.8, 0, 2.3), 190.0, "shovel_rest")
				_eat("n", Vector3(0.0, 0, 1.9), 180.0, "eng_nco_check", 0.0)
				_epose("c", Vector3(1.8, 0, 2.6), 200.0, "stand")
		_cam(Vector3(0, 0.6, 0.6 if k != 2 else -1.4), 1.35 if k == 3 else 0.6, -0.36, 7.2 if k != 2 else 8.4)
		tiles.append(await _grab("%d  %s" % [k + 1, labels[k]]))
		_drop(made)
	_esave(_tile(tiles, 3), "track")
