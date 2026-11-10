extends SceneTree
## Red coats against our troops (Building Chat 1, 2026-11-10): picture sheets of the fights, in the explosion
## test's world (BlastStage) so the musket and rifle smoke match. Needs a window:
##   Godot --path iron_front --resolution 1600x900 -s res://tools/fight_pictures.gd -- [clash duels trench dragoons]
## Writes results/units/redcoats/fight_*.png. Each tile is one moment; the men are posed by hand per moment.

const F := preload("res://scripts/units/anim/clips_fight.gd")
const M := preload("res://scripts/units/anim/clips_musket.gd")
const M2 := preload("res://scripts/units/anim/clips_redcoat2.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
const RB := preload("res://scripts/units/redcoat_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const B := preload("res://scripts/units/soldier_builder.gd")
const OUT := "res://results/units/redcoats/"
const EARTH := Color(0.42, 0.34, 0.24)
const PLANK := Color(0.50, 0.38, 0.24)
const SAND := Color(0.62, 0.55, 0.40)

var stage: BlastStage
var ui: CanvasLayer
var title: Label
var things: Array[Node] = []
var men := {}                # name -> Soldier (Redcoat for red coats)
var rc_lib: Dictionary
var our_lib: Dictionary
var gy := 0.0
var rear: Array[MeshInstance3D] = []   # the trench's back wall, hidden for the cutaway
var fx: Array = []           # this frame's flashes: [kind, man name or world point, age, dir]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	rc_lib = Redcoat.library()
	our_lib = R.library()
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
	for mode in (args if not args.is_empty() else ["clash", "duels", "trench", "dragoons"]):
		match mode:
			"clash":
				await _clash()
			"duels":
				await _duels()
			"trench":
				await _trench()
			"dragoons":
				await _dragoons()
	print("FIGHT PICTURES OK")
	quit()


# ---------------------------------------------------------------- helpers

func _clear() -> void:
	for n in things:
		if is_instance_valid(n):
			n.queue_free()
	things.clear()
	men.clear()
	stage.clear_blasts()
	stage.step(0.0)
	title.text = ""


func _keep(n: Node) -> Node:
	things.append(n)
	return n


func _rc(name: String, seed_value: int, role := "musketeer") -> Redcoat:
	var r := Redcoat.new()
	r.setup(seed_value, 0, role)
	stage.add_child(r)
	_keep(r)
	men[name] = r
	return r


func _ours(name: String, seed_value: int) -> Soldier:
	var s := Soldier.new()
	s.setup(seed_value, 0)
	stage.add_child(s)
	_keep(s)
	men[name] = s
	return s


func _is_rc(name: String) -> bool:
	return men[name] is Redcoat


## Puts a man at a spot (y above the ground), facing yaw (deg; 0 = -Z, 180 = +Z), in a pose spec.
func _put(name: String, at: Vector3, yaw: float, spec: Dictionary, ground := true) -> void:
	var m: Soldier = men[name]
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	var g := Rig.solve(spec, spec, 0.0)
	if ground:
		Rig.lift(g, Rig.ground_lift(g, m.geo))
	m.show_globals(g)
	if m is Redcoat:
		(m as Redcoat).set_props({})


## The same, playing a clip at time t (deaths, runs).
func _play(name: String, at: Vector3, yaw: float, clip: String, t: float) -> void:
	var m: Soldier = men[name]
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	var lib := rc_lib if m is Redcoat else our_lib
	m.show_clip(lib[clip], t)


## A shot from a man's muzzle, age seconds ago (musket: flash and a bank of smoke; ours: a small flash).
func _shot(name: String, age: float) -> void:
	fx.append(["shot", name, age])


func _fire_fx() -> void:
	stage.clear_blasts()
	var i := 0
	for e: Array in fx:
		var kind: String = e[0]
		var age: float = e[2]
		stage.step(-age)
		if kind == "shot":
			var m: Soldier = men[e[1]]
			var x: Transform3D = m.global_transform * m.skel.get_bone_global_pose(B.RIFLE)
			var mus := m is Redcoat
			stage.fire("musket" if mus else "pan", x * F.muzzle(mus), 31 + i, -1, -x.basis.z.normalized(), false)
		else:
			stage.fire(kind, e[1], 31 + i, -1, e[3], false)
		i += 1
	stage.step(0.0)
	fx.clear()


func _cam(at: Vector3, yaw: float, pitch: float, dist: float, fov := 42.0) -> void:
	stage.cam.fov = fov
	stage.aim(at + Vector3(0, gy, 0), yaw, pitch, dist)
	stage.step(stage.clock)
	stage.sun.directional_shadow_max_distance = 40.0


func _grab(text: String) -> Image:
	title.text = text
	_fire_fx()
	stage.sun.directional_shadow_max_distance = 40.0
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + "fight_" + name + ".png"))
	print("saved fight_", name)


func _tile(tiles: Array[Image], cols: int) -> Image:
	var w := tiles[0].get_width()
	var hh := tiles[0].get_height()
	var tw := w / 2
	var th := hh / 2
	var rows := ceili(float(tiles.size()) / cols)
	var out := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		var t := tiles[i]
		t.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(t, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	return out


func _block(c: Vector3, h: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = h * 2.0
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = c + Vector3(0, gy, 0)
	stage.add_child(mi)
	_keep(mi)
	return mi


func _clip_len(name: String, clip: String) -> float:
	var lib := rc_lib if _is_rc(name) else our_lib
	return float(lib[clip]["len"])


# ---------------------------------------------------------------- 1. the bayonet charge meets our line

func _clash() -> void:
	_clear()
	var ox: Array[float] = [-3.0, -1.5, 0.0, 1.5, 3.0]
	for i in 5:
		_ours("o%d" % i, 40 + i)
	for i in 6:
		_rc("r%d" % i, 50 + i, "grenadier" if i == 2 else "musketeer")
	_rc("off", 60, "officer")
	var rx: Array[float] = [-3.6, -1.5, 0.0, 0.8, 1.5, 3.0]
	var tiles: Array[Image] = []
	var cz := [-6.5]
	var cam := func() -> void: _cam(Vector3(0, 0.9, float(cz[0])), 1.05, -0.24, 12.5, 44.0)
	var guard_o := F.guard(false)
	var guard_r := F.guard(true)
	var dl := _clip_len("o0", "death_back")
	var dlr := _clip_len("r0", "death_back")
	# 1: the red coats come on at the run, bayonets levelled; our line fires.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, F.aim(false))
		_shot("o%d" % i, 0.04 + 0.2 * (i % 3))
	for i in 6:
		_play("r%d" % i, Vector3(rx[i], 0, -14.0 + 0.4 * (i % 2)), 180.0, "charge_run", 0.11 * i)
	_play("off", Vector3(-0.8, 0, -15.5), 180.0, "officer_charge", 0.2)
	cam.call()
	tiles.append(await _grab("1  the red coats charge; our line fires"))
	cz[0] = -4.0
	# 2: two fall to the volley; the rest keep coming.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, F.aim(false))
		if i % 2 == 0:
			_shot("o%d" % i, 0.05)
	for i in 6:
		var z := -8.0 + 0.4 * (i % 2)
		if i == 0 or i == 3:
			_play("r%d" % i, Vector3(rx[i], 0, z - 1.0), 180.0, "death_forward", 0.55 if i == 0 else 1.0)
		else:
			_play("r%d" % i, Vector3(rx[i], 0, z), 180.0, "charge_run", 0.11 * i + 0.3)
	_play("off", Vector3(-0.8, 0, -9.5), 180.0, "officer_charge", 0.5)
	cam.call()
	tiles.append(await _grab("2  two fall to the fire"))
	cz[0] = -2.0
	# 3: no time to reload: our men come on guard.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, guard_o if i != 0 else F.aim(false))
	_shot("o0", 0.06)
	for i in 6:
		if i == 0 or i == 3:
			_play("r%d" % i, Vector3(rx[i], 0, -9.0 + 0.4 * (i % 2)), 180.0, "death_forward", 3.0)
		else:
			_play("r%d" % i, Vector3(rx[i], 0, -3.4), 180.0, "charge_run", 0.11 * i + 0.1)
	_play("off", Vector3(-0.8, 0, -5.0), 180.0, "officer_charge", 0.1)
	cam.call()
	tiles.append(await _grab("3  bayonets: our men on guard"))
	cz[0] = -0.8
	# 4: the lines meet: thrust and parry.
	_put("r1", Vector3(-1.5, 0, -1.45), 180.0, F.lunge(true))
	_put("o1", Vector3(-1.5, 0, 0), 0.0, F.parry(false))
	_put("o2", Vector3(0, 0, 0), 0.0, F.lunge(false))
	_put("r2", Vector3(0, 0, -1.55), 180.0, F.parry(true))
	_put("r4", Vector3(1.5, 0, -0.75), 180.0, F.locked(true))
	_put("o3", Vector3(1.5, 0, 0), 0.0, F.locked(false))
	_put("r5", Vector3(3.0, 0, -1.45), 180.0, F.lunge(true))
	_put("o4", Vector3(3.0, 0, 0.1), 0.0, F.duck(false))
	_put("o0", Vector3(-3.0, 0, 0), 0.0, F.aim(false))
	_shot("o0", 0.02)
	_put("off", Vector3(-0.6, 0, -3.2), 180.0, M.poses("officer")["lead"])
	cam.call()
	tiles.append(await _grab("4  the lines meet"))
	# 5: butt strokes and the red coats' second thrust.
	_put("o1", Vector3(-1.5, 0, -0.1), 0.0, F.butt_strike(false))
	_put("r1", Vector3(-1.5, 0, -1.3), 180.0, F.reel(true))
	_put("r2", Vector3(0, 0, -1.5), 180.0, F.lunge(true))
	_put("o2", Vector3(0, 0, 0.1), 0.0, F.reel(false))
	_put("r4", Vector3(1.5, 0, -0.6), 180.0, F.locked(true, 1.6))
	_put("o3", Vector3(1.5, 0, 0.15), 0.0, F.reel(false))
	_put("o4", Vector3(3.0, 0, -0.3), 0.0, F.butt_strike(false))
	_put("r5", Vector3(3.0, 0, -1.35), 180.0, F.reel(true))
	cam.call()
	tiles.append(await _grab("5  butt strokes, a second thrust"))
	# 6: men go down on both sides.
	_play("r1", Vector3(-1.5, 0, -1.35), 180.0, "death_back", dlr * 0.4)
	_put("o1", Vector3(-1.5, 0, -0.2), 0.0, guard_o)
	_play("o2", Vector3(0, 0, 0.25), 0.0, "death_back", dl * 0.4)
	_put("r2", Vector3(0, 0, -1.3), 180.0, guard_r)
	_play("o3", Vector3(1.5, 0, 0.3), 0.0, "death_back", dl * 0.3)
	_put("r4", Vector3(1.5, 0, -0.5), 180.0, F.lunge(true))
	_play("r5", Vector3(3.0, 0, -1.4), 180.0, "death_forward", 0.9)
	_put("o4", Vector3(3.0, 0, -0.3), 0.0, guard_o)
	_put("off", Vector3(-0.3, 0, -2.6), 180.0, M.poses("officer")["up"])
	cam.call()
	tiles.append(await _grab("6  men go down on both sides"))
	# 7: our right gives ground; our left pushes on.
	_play("r1", Vector3(-1.5, 0, -1.35), 180.0, "death_back", dlr)
	_put("o1", Vector3(-1.4, 0, -1.6), 0.0, F.lunge(false))
	_put("off", Vector3(-1.2, 0, -2.75), 180.0, F.reel(true))
	_play("o2", Vector3(0, 0, 0.25), 0.0, "death_back", dl)
	_play("o3", Vector3(1.5, 0, 0.3), 0.0, "death_back", dl)
	_put("r2", Vector3(0.2, 0, -0.2), 180.0, F.lunge(true))
	_put("r4", Vector3(1.5, 0, 0.9), 180.0, guard_r)
	_put("o0", Vector3(-0.6, 0, 1.4), 0.0, F.parry(false))
	_put("o4", Vector3(2.6, 0, 1.4), 30.0, guard_o)
	_play("r5", Vector3(3.0, 0, -1.4), 180.0, "death_forward", 3.0)
	cam.call()
	tiles.append(await _grab("7  our right gives ground, our left pushes on"))
	# 8: the officer down; the rest face off in the smoke.
	_play("off", Vector3(-1.2, 0, -2.9), 180.0, "officer_death_back", 1.9)
	_put("o1", Vector3(-1.4, 0, -1.4), 0.0, guard_o)
	_put("r2", Vector3(0.2, 0, -0.3), 180.0, guard_r)
	_put("o0", Vector3(-0.4, 0, 1.2), 0.0, guard_o)
	_put("r4", Vector3(1.6, 0, 0.6), 180.0, F.aim(true))
	_shot("r4", 0.6)
	_put("o4", Vector3(2.6, 0, 1.6), 20.0, F.wounded(false))
	cam.call()
	tiles.append(await _grab("8  the officer falls; the fight goes on"))
	_save(_tile(tiles, 4), "clash")


# ---------------------------------------------------------------- 2. duels

func _duels() -> void:
	for d in 3:
		_clear()
		_ours("o", 70 + d)
		_rc("r", 80 + d, ["musketeer", "grenadier", "light"][d])
		var tiles: Array[Image] = []
		var gr := F.guard(true)
		var go := F.guard(false)
		var cam := func() -> void: _cam(Vector3(0, 1.0, -0.75), PI * 0.5 + 0.25, -0.12, 4.6, 40.0)
		var steps: Array = []
		var dl := _clip_len("o", "death_back")
		match d:
			0:
				# The red coat wins: thrust, parry, riposte parried, the second thrust gets home.
				steps = [["on guard", [gr, -1.6], [go, 0.0]],
					["he thrusts; a parry", [F.lunge(true), -1.55], [F.parry(false), 0.0]],
					["the riposte; parried", [F.parry(true), -1.6], [F.lunge(false), -0.05]],
					["the second thrust", [F.lunge(true), -1.35], [F.reel(false), 0.1]],
					["down", [gr, -1.2], ["death_back", 0.35, dl * 0.45]],
					["the red coat wins", [gr, -1.1], ["death_back", 0.35, dl]]]
			1:
				# Ours wins: parry, then the butt stroke.
				steps = [["on guard", [gr, -1.6], [go, 0.0]],
					["he thrusts; a parry", [F.lunge(true), -1.55], [F.parry(false), 0.0]],
					["wind up", [gr, -1.35], [F.butt_wind(false), -0.1]],
					["the butt stroke", [F.reel(true), -1.25], [F.butt_strike(false), -0.15]],
					["down", ["death_back", -1.3, 0.75], [go, -0.2]],
					["ours wins", ["death_back", -1.3, 3.0], [go, -0.2]]]
			2:
				# Locked rifles: ours is shoved down, then saved by a comrade's shot.
				steps = [["locked rifles", [F.locked(true), -0.72], [F.locked(false), 0.0]],
					["shoved", [F.locked(true, 1.8), -0.55], [F.reel(false), 0.2]],
					["down", [F.guard(true), -0.45], ["death_back", 0.4, dl * 0.5]],
					["a shot from the side", [F.reel(true), -0.35], ["death_back", 0.4, dl]],
					["the red coat falls", ["death_back", -0.5, 1.0], ["death_back", 0.4, dl]],
					["up again", ["death_back", -0.5, 3.0], [F.wounded(false), 0.6]]]
		if d == 2:
			_ours("o2", 90)
		for k in steps.size():
			var st: Array = steps[k]
			for side in 2:
				var who := "r" if side == 0 else "o"
				var e: Array = st[1 + side]
				var yaw := 180.0 if side == 0 else 0.0
				if e[0] is String:
					_play(who, Vector3(0, 0, e[1]), yaw, e[0], e[2])
				else:
					_put(who, Vector3(0, 0, e[1]), yaw, e[0])
			if d == 2:
				var o2 := men["o2"] as Soldier
				o2.visible = k >= 2
				if k >= 2:
					_put("o2", Vector3(-3.2, 0, 1.6), -58.0, F.aim(false))
					if k == 3:
						_shot("o2", 0.03)
					elif k == 4:
						_shot("o2", 0.8)
			cam.call()
			tiles.append(await _grab("%s  %d  %s" % [["duel A", "duel B", "duel C"][d], k + 1, st[0]]))
		_save(_tile(tiles, 3), "duel_" + ["a", "b", "c"][d])


# ---------------------------------------------------------------- 3. storming the trench

## The trench runs along X at z = 0: floor at ground level, 1.6 m wide; the earth on both sides 1.7 m up; a fire step
## along the front wall; sandbags on the parapet. Our men face -Z, the red coats come from -Z.
func _trench_set() -> void:
	var top := 1.7
	_block(Vector3(0, top * 0.5, -12.8), Vector3(14, top * 0.5, 12.0), EARTH)
	rear.append(_block(Vector3(0, top * 0.5, 12.8), Vector3(14, top * 0.5, 12.0), EARTH))
	_block(Vector3(0, 0.25, -0.62), Vector3(14, 0.25, 0.18), EARTH.darkened(0.15))
	for k in 28:
		_block(Vector3(-13.5 + k, top + 0.1, -0.95 - 0.12 * (k % 2)), Vector3(0.45, 0.1, 0.2), SAND.darkened(0.06 * (k % 3)))
		rear.append(_block(Vector3(-13.5 + k, 0.85, 0.79), Vector3(0.48, 0.85, 0.02), PLANK.darkened(0.08 * (k % 3))))
	for k in 10:
		_block(Vector3(-9.0 + 2.0 * k, 0.03, 0.05), Vector3(0.06, 0.03, 0.55), PLANK.darkened(0.2))


func _trench() -> void:
	_clear()
	_trench_set()
	var top := 1.7
	var ox: Array[float] = [-3.0, -1.5, 0.0, 1.5, 3.0]
	for i in 5:
		_ours("o%d" % i, 100 + i)
	for i in 7:
		_rc("r%d" % i, 110 + i, "light" if i == 6 else "musketeer")
	var rx: Array[float] = [-3.4, -2.2, -0.9, 0.3, 1.5, 2.7, 4.0]
	var step := Vector3(0, 0.5, -0.55)
	var tiles: Array[Image] = []
	var tz := [-6.0]
	var cam := func() -> void: _cam(Vector3(0.0, 1.0, float(tz[0])), 0.8, -0.5, 11.5 if float(tz[0]) < -3.0 else 9.0, 46.0)
	var dl := _clip_len("o0", "death_back")
	var aim_o := F.aim(false)
	var vk: Dictionary = rc_lib["volley_stand"]
	# 1: the red coats march up; ours fire from the step.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0) + step, 0.0, aim_o)
		_shot("o%d" % i, 0.05 + 0.25 * (i % 2))
	for i in 7:
		_play("r%d" % i, Vector3(rx[i], top, -15.0 + 0.3 * (i % 2)), 180.0, "march", 0.15 * i)
	cam.call()
	tiles.append(await _grab("1  the red coats march up; ours fire from the step"))
	# 2: they halt and give a volley; our men duck below the parapet.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0.15) + Vector3(0, 0.5, -0.5), 0.0, F.duck(false) if i % 2 == 0 else aim_o)
	for i in 7:
		_play("r%d" % i, Vector3(rx[i], top, -10.0), 180.0, "volley_stand", float(vk["len"]) - 1.3)
		_shot("r%d" % i, 0.25 + 0.04 * i)
	cam.call()
	tiles.append(await _grab("2  a volley; our men duck"))
	# 3: they charge through the smoke; some fall.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0) + step, 0.0, aim_o)
		_shot("o%d" % i, 0.05 + 0.15 * i)
	for i in 7:
		if i == 1 or i == 5:
			_play("r%d" % i, Vector3(rx[i], top, -6.5), 180.0, "death_forward", 0.7 if i == 1 else 1.4)
		else:
			_play("r%d" % i, Vector3(rx[i], top, -5.0 + 0.4 * (i % 2)), 180.0, "charge_run", 0.1 * i)
	cam.call()
	tiles.append(await _grab("3  the charge; men fall in the open"))
	tz[0] = -0.6
	# 4: at the parapet: thrusting down; ours meet them from the step.
	for i in 7:
		if i == 1 or i == 5:
			_play("r%d" % i, Vector3(rx[i], top, -6.5), 180.0, "death_forward", 3.0)
	_put("r0", Vector3(-3.2, top, -1.6), 180.0, F.lunge(true))
	_put("o0", Vector3(-3.0, 0.5, -0.45), 0.0, F.parry(false))
	_put("r2", Vector3(-1.2, top, -1.4), 180.0, F.leap(true))
	_put("o1", Vector3(-1.5, 0.5, -0.5), 0.0, F.lunge(false))
	_put("r3", Vector3(0.3, top, -1.7), 180.0, F.lunge(true))
	_put("o2", Vector3(0.0, 0.5, -0.4), 0.0, F.reel(false))
	_put("r4", Vector3(1.5, top, -1.5), 180.0, F.reel(true))
	_put("o3", Vector3(1.5, 0.5, -0.55), 0.0, aim_o)
	_shot("o3", 0.03)
	_put("r6", Vector3(3.6, top, -2.5), 180.0, F.aim(true))
	_shot("r6", 0.05)
	_put("o4", Vector3(3.0, 0.5, -0.55), 0.0, aim_o)
	cam.call()
	tiles.append(await _grab("4  at the parapet"))
	# 5: they jump in. From here our side of the trench is cut away so the fight inside shows.
	for n in rear:
		n.visible = false
	cam = func() -> void: _cam(Vector3(0.0, 0.7, -0.3), 0.42, -0.36, 8.5, 46.0)
	_put("r2", Vector3(-1.2, 0.95, -0.55), 180.0, F.leap(true), false)
	_put("r0", Vector3(-3.2, 1.0, -0.6), 180.0, F.leap(true), false)
	_play("o2", Vector3(0.0, 0, 0.1), 0.0, "death_back", dl * 0.45)
	_put("r3", Vector3(0.2, top, -1.3), 180.0, F.leap(true))
	_play("r4", Vector3(1.5, top, -1.8), 180.0, "death_back", 0.9)
	_put("o0", Vector3(-2.6, 0, 0.3), 30.0, F.guard(false))
	_put("o1", Vector3(-1.5, 0, 0.35), 0.0, F.guard(false))
	cam.call()
	tiles.append(await _grab("5  over the top and down into the trench (our side cut away)"))
	# 6: hand to hand in the trench.
	_put("r2", Vector3(-1.2, 0, -0.35), 180.0, F.lunge(true))
	_put("o1", Vector3(-1.1, 0, 0.45), 0.0, F.parry(false))
	_put("r0", Vector3(-3.1, 0, -0.3), 180.0, F.reel(true))
	_put("o0", Vector3(-2.9, 0, 0.35), 20.0, F.butt_strike(false))
	_put("r3", Vector3(0.6, 0, -0.3), 180.0, F.locked(true))
	_play("o2", Vector3(0.0, 0, 0.1), 0.0, "death_back", dl)
	_put("o3", Vector3(1.1, 0, 0.35), -30.0, F.locked(false))
	_play("r4", Vector3(1.5, top, -1.8), 180.0, "death_back", 1.9)
	_put("r6", Vector3(3.2, top, -1.4), 180.0, F.leap(true))
	_put("o4", Vector3(3.0, 0.5, -0.5), 0.0, F.lunge(false))
	cam.call()
	tiles.append(await _grab("6  hand to hand in the trench"))
	# 7: the trench changes hands, bay by bay.
	_play("r0", Vector3(-3.1, 0, -0.35), 180.0, "death_forward", 1.6)
	_put("o0", Vector3(-2.6, 0, 0.3), 70.0, F.guard(false))
	_put("r2", Vector3(-1.2, 0, 0.0), 180.0, F.butt_strike(true))
	_play("o1", Vector3(-1.1, 0, 0.4), 90.0, "death_forward", 0.9)
	_put("r3", Vector3(0.9, 0, -0.1), 180.0, F.lunge(true))
	_put("o3", Vector3(1.3, 0, 0.4), -40.0, F.reel(false))
	_play("r6", Vector3(3.2, top, -1.3), 180.0, "death_back", 1.0)
	_put("o4", Vector3(3.0, 0.5, -0.5), 0.0, F.guard(false))
	cam.call()
	tiles.append(await _grab("7  the trench changes hands, bay by bay"))
	# 8: our left bay holds; the red coats take the middle.
	_put("o0", Vector3(-2.3, 0, 0.2), 90.0, F.aim(false))
	_shot("o0", 0.04)
	_put("r2", Vector3(-1.3, 0, 0.0), 120.0, F.reel(true))
	_play("o1", Vector3(-1.1, 0, 0.4), 90.0, "death_forward", 3.0)
	_play("o3", Vector3(1.3, 0, 0.4), -40.0, "death_back", dl * 0.6)
	_put("r3", Vector3(1.0, 0, 0.0), 90.0, F.guard(true))
	_put("o4", Vector3(2.4, 0, 0.3), -90.0, F.guard(false))
	cam.call()
	tiles.append(await _grab("8  our left bay holds; the red coats hold the middle"))
	_save(_tile(tiles, 4), "trench")


# ---------------------------------------------------------------- 4. dragoons ride in

func _mount(name: String, seed_value: int) -> Horse:
	var h := Horse.new().setup(seed_value, 0, RB.FACINGS["yellow"])
	stage.add_child(h)
	_keep(h)
	var r := Redcoat.new()
	r.setup(seed_value, 0, "dragoon")
	h.att_body.add_child(r)
	r.position = Horse.seat_local() - Vector3(0, 0.86, 0)
	men[name] = r
	men[name + "_h"] = h
	return h


func _ride(name: String, at: Vector3, yaw: float, horse_pose: Dictionary, sword: String) -> void:
	var h: Horse = men[name + "_h"]
	h.position = Vector3(at.x, gy, at.z)
	h.rotation.y = deg_to_rad(yaw)
	h.show_pose(horse_pose)
	(men[name] as Redcoat).show_spec(M2.ride(sword), false)


func _dragoons() -> void:
	_clear()
	var ox: Array[float] = [-3.5, -1.8, 0.0, 1.7, 3.4]
	for i in 5:
		_ours("o%d" % i, 120 + i)
	for i in 4:
		_mount("d%d" % i, 130 + i)
	var dx: Array[float] = [-3.0, -0.9, 1.0, 3.2]
	var tiles: Array[Image] = []
	var cam := func(z: float, d: float) -> void: _cam(Vector3(0.0, 1.0, z), 1.05, -0.24, d, 46.0)
	var dl := _clip_len("o0", "death_back")
	var aim_o := F.aim(false)
	var kneel_o: Dictionary = R.poses()["kneel"]
	# 1: the troop comes on at the gallop; our men open fire.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, aim_o if i % 2 == 0 else kneel_o)
		_shot("o%d" % i, 0.05 + 0.2 * i)
	for i in 4:
		_ride("d%d" % i, Vector3(dx[i], 0, -22.0 + 0.8 * (i % 2)), 180.0, Horse.gait_pose("gallop", 0.13 * i), "carry")
	cam.call(-10.5, 21.0)
	tiles.append(await _grab("1  dragoons at the gallop; our men open fire"))
	# 2: the charge; a horse is brought down.
	for i in 5:
		_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, aim_o if i % 2 == 0 else kneel_o)
		if i != 2:
			_shot("o%d" % i, 0.05 + 0.1 * i)
	for i in 4:
		if i == 2:
			_ride("d2", Vector3(dx[2], 0, -10.0), 180.0, Horse.fall_pose(0.35), "carry")
		else:
			_ride("d%d" % i, Vector3(dx[i], 0, -11.0 + 0.8 * (i % 2)), 180.0, Horse.gait_pose("charge", 0.13 * i), "point")
	cam.call(-5.0, 15.0)
	tiles.append(await _grab("2  the charge; a horse brought down by the fire"))
	# 3: the fallen horse, its rider thrown; the rest sabres out, close.
	var d2: Redcoat = men["d2"]
	var h2: Horse = men["d2_h"]
	d2.get_parent().remove_child(d2)
	stage.add_child(d2)
	_ride("d2", Vector3(dx[2], 0, -9.4), 180.0, Horse.fall_pose(1.0), "carry")
	_play("d2", Vector3(dx[2] + 0.2, 0, -7.4), 180.0, "officer_death_forward", 1.4)
	var _hh := h2
	for i in 5:
		var spec: Dictionary = aim_o if i != 1 else F.duck(false)
		_put("o%d" % i, Vector3(ox[i], 0, 0), 0.0, spec if i % 2 == 0 or i == 1 else F.guard(false))
	_shot("o0", 0.05)
	_shot("o4", 0.1)
	for i in [0, 1, 3]:
		_ride("d%d" % i, Vector3(dx[i], 0, -3.2 + 0.4 * (i % 2)), 180.0, Horse.gait_pose("charge", 0.13 * i), "raise" if i == 1 else "point")
	cam.call(-2.0, 15.0)
	tiles.append(await _grab("3  sabres raised; our men stand or duck"))
	# 4: the cut; a man dives clear; another is ridden down.
	_ride("d0", Vector3(-3.1, 0, 0.6), 180.0, Horse.gait_pose("charge", 0.2), "point")
	_play("o0", Vector3(-4.0, 0, 0.4), 90.0, "prone_to_stand", 0.1)
	_ride("d1", Vector3(-1.2, 0, 0.3), 180.0, Horse.gait_pose("charge", 0.31), "cut")
	_put("o1", Vector3(-1.8, 0, 0.35), 0.0, F.duck(false))
	_ride("d3", Vector3(3.0, 0, 0.4), 180.0, Horse.gait_pose("charge", 0.05), "cut")
	_put("o4", Vector3(3.4, 0, 0.2), 0.0, F.reel(false))
	_put("o2", Vector3(0.0, 0, 0.3), 160.0, F.guard(false))
	_put("o3", Vector3(1.7, 0, 0.2), 0.0, F.lunge(false))
	cam.call(0.0, 14.0)
	tiles.append(await _grab("4  the cut: one ducks, one dives, one is struck"))
	# 5: through the line; men down behind them.
	_ride("d0", Vector3(-3.0, 0, 6.5), 180.0, Horse.gait_pose("gallop", 0.1), "carry")
	_ride("d1", Vector3(-0.9, 0, 6.0), 180.0, Horse.gait_pose("gallop", 0.35), "carry")
	_ride("d3", Vector3(3.1, 0, 6.8), 180.0, Horse.gait_pose("gallop", 0.5), "carry")
	_play("o4", Vector3(3.4, 0, 0.3), 0.0, "death_back", dl * 0.6)
	_put("o1", Vector3(-1.8, 0, 0.35), 180.0, F.aim(false))
	_shot("o1", 0.05)
	_put("o0", Vector3(-4.0, 0, 0.4), 180.0, kneel_o)
	_put("o3", Vector3(1.7, 0, 0.4), 180.0, F.aim(false))
	_shot("o3", 0.2)
	_put("o2", Vector3(0.0, 0, 0.3), 180.0, kneel_o)
	cam.call(4.0, 17.0)
	tiles.append(await _grab("5  through the line; our men turn and fire"))
	# 6: a dragoon's horse shot under him at the rear.
	_ride("d0", Vector3(-3.3, 0, 13.0), 160.0, Horse.gait_pose("gallop", 0.2), "carry")
	_ride("d3", Vector3(3.6, 0, 13.5), 200.0, Horse.gait_pose("gallop", 0.45), "carry")
	_ride("d1", Vector3(-0.8, 0, 9.5), 180.0, Horse.fall_pose(0.55), "carry")
	_play("o4", Vector3(3.4, 0, 0.3), 0.0, "death_back", dl)
	_shot("o1", 0.1)
	_shot("o2", 0.05)
	cam.call(6.5, 19.0)
	tiles.append(await _grab("6  another horse goes down"))
	# 7: the troop wheels about to come again.
	_ride("d0", Vector3(-4.5, 0, 17.0), 260.0, Horse.gait_pose("trot", 0.1), "carry")
	_ride("d3", Vector3(1.0, 0, 18.5), 280.0, Horse.gait_pose("trot", 0.3), "carry")
	_ride("d1", Vector3(-0.8, 0, 9.5), 180.0, Horse.fall_pose(1.0), "carry")
	for i in 4:
		if i == 4:
			continue
		_put("o%d" % i, Vector3(ox[i] * 0.7, 0, 1.0), 180.0, F.aim(false) if i % 2 == 0 else R.poses()["kneel"])
	_shot("o0", 0.4)
	cam.call(9.0, 22.0)
	tiles.append(await _grab("7  they wheel about to come again; ours form up"))
	# 8: the unhorsed dragoon on foot, sabre against bayonet.
	var d1: Redcoat = men["d1"]
	d1.get_parent().remove_child(d1)
	stage.add_child(d1)
	_put("d1", Vector3(-0.6, 0, 8.0), 0.0, M.poses("officer")["up"])
	_put("o2", Vector3(-0.6, 0, 6.9), 180.0, F.guard(false))
	_cam(Vector3(-0.6, 1.0, 7.45), 1.25, -0.12, 5.5, 40.0)
	tiles.append(await _grab("8  unhorsed: sabre against the rifle"))
	_save(_tile(tiles, 4), "dragoons")
