extends "res://tools/medieval_pictures.gd"
## The medieval host's siege equipment (Building Chat 1, 2026-11-10): the look sheet, the crews at work, the engines'
## actions and the siege against our walls, gate and trenches. Pictures only. Needs a window:
##   Godot --path iron_front --resolution 1600x900 -s res://tools/siege_pictures.gd -- [look crews actions siege]
## SIEGE_ONLY=<row part> limits the crew and action sheets (writes siege_debug.png). Writes results/units/medieval/siege_*.png.

const SB := preload("res://scripts/units/siege_builder.gd")
const CS := preload("res://scripts/units/anim/clips_siege.gd")
const Anim := preload("res://scripts/units/anim/anim.gd")
const SOUT := "res://results/units/medieval/"
const WALL_Z := -1.3        # the wall's outer face (the host comes from -Z)
const WALK_Y := 3.4         # our wall walk
const PARA_Y := 4.2         # the parapet's top

var engs := {}
var props: Array[Node] = []


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOUT))
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
	for mode in (args if not args.is_empty() else ["look", "crews", "actions", "siege"]):
		match mode:
			"look":
				await _slook()
			"crews":
				await _crews()
			"actions":
				await _actions()
			"siege":
				await _siege()
	print("SIEGE PICTURES OK")
	quit()


# ---------------------------------------------------------------- helpers

func _sclear() -> void:
	_clear()
	engs.clear()
	props.clear()
	rear.clear()


func _eng(name: String, kind: String, at: Vector3, yaw: float, lod := 0, lord := 0, seed_value := 1) -> SiegeEngine:
	var e := SiegeEngine.new().setup(kind, lod, lord, seed_value)
	stage.add_child(e)
	_keep(e)
	e.position = Vector3(at.x, gy + at.y, at.z)
	e.rotation.y = deg_to_rad(yaw)
	engs[name] = e
	return e


## An engine point (engine space) in stage space.
func _ep(name: String, p: Vector3) -> Vector3:
	return (engs[name] as Node3D).transform * p


func _crewman(name: String, seed_value: int, role := "levy", lord := 0) -> Medieval:
	var m := _med(name, seed_value, role, lord)
	if m.shield != null:
		m.shield.visible = false
	return m


## A man at a spot (y above the ground), facing yaw, in a body with both hands on stage-space points (null: free).
func _hold(name: String, at: Vector3, yaw: float, body: Dictionary, wr: Variant, wl: Variant, ground := true,
		pole_r := Vector3(0.8, -0.4, 0.2), pole_l := Vector3(-0.8, -0.4, 0.2)) -> void:
	var m: Medieval = men[name]
	m.visible = true
	m.position = Vector3(at.x, gy + at.y, at.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	var inv := m.transform.affine_inverse()
	var hr: Variant = null if wr == null else inv * (wr as Vector3)
	var hl: Variant = null if wl == null else inv * (wl as Vector3)
	_show(m, CS.work(body, hr, hl, pole_r, pole_l), ground)


## Shows a spec, lifting the man onto the ground but keeping his hands on their points.
func _show(m: Medieval, spec: Dictionary, ground := true) -> void:
	var g := Rig.solve(spec, spec, 0.0)
	if ground:
		var dy := Rig.ground_lift(g, m.geo)
		if absf(dy) > 0.001:
			var s2 := spec.duplicate(true)
			for k: String in ["hand_r", "hand_l"]:
				var h: Variant = s2.get(k)
				if h is Array and int(h[0]) < 0:
					s2[k] = [-1, (h[1] as Vector3) - Vector3(0, dy, 0)]
			g = Rig.solve(s2, s2, 0.0)
			Rig.lift(g, dy)
	Anim.apply(m.skel, g)
	m.set_props({"hand": [spec.get("hand_item", "main"), 0.0]})


## A man walking a gait clip with his hands on points in his own frame; he moves along his facing by speed * t.
func _walkman(name: String, at: Vector3, yaw: float, clip: Dictionary, t: float) -> void:
	var m: Medieval = men[name]
	m.visible = true
	var fwd := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(yaw))
	var p := at + fwd * float(clip.get("speed", 0.0)) * t
	m.position = Vector3(p.x, gy + p.y, p.z)
	m.rotation = Vector3(0, deg_to_rad(yaw), 0)
	m.show_clip(clip, t)


## Where a point in a man's own frame sits on the stage.
func _mp(name: String, p: Vector3) -> Vector3:
	return (men[name] as Node3D).transform * p


func _prop(g: UnitGeo, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh(Soldier.material())
	mi.transform = xf
	stage.add_child(mi)
	_keep(mi)
	props.append(mi)
	return mi


## A ladder from its foot (stage space, on the ground) along dir, the hooks over toward hook_side.
func _ladder(foot: Vector3, dir: Vector3, flip := true) -> MeshInstance3D:
	var x := Vector3(-1, 0, 0) if flip else Vector3(1, 0, 0)
	var y := dir.normalized()
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return _prop(SB.ladder(0)["body"], Transform3D(Basis(x, y, z), foot))


func _ladder_xf(foot: Vector3, dir: Vector3) -> Transform3D:
	var x := Vector3(-1, 0, 0)
	var y := dir.normalized()
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Transform3D(Basis(x, y, z), foot)


## A streak behind a flying shot.
func _trail(a: Vector3, b: Vector3, w := 0.12, col := Color(0.8, 0.76, 0.66, 0.3)) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	mi.mesh = bm
	var d := b - a
	mi.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP).scaled_local(Vector3(w, w, d.length())), (a + b) * 0.5)
	stage.add_child(mi)
	_keep(mi)


## A point on a lobbed shot's path from a to b (apex h above the higher end), t 0..1.
static func lob(a: Vector3, b: Vector3, h: float, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3(0, 4.0 * h * t * (1.0 - t), 0)


func _ssave(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(SOUT + "siege_" + name + ".png"))
	print("saved siege_", name)


## Our wall along X at z 0 (cells of 8 m), a gate at x 0.
func _walls(gate := true, damaged := -99) -> Array:
	var out := []
	for i in 5:
		var x := -16.0 + 8.0 * i
		var v := "gate" if (gate and i == 2) else ""
		var w := BldWalls.make(BldWalls.E | BldWalls.W, v)
		stage.add_child(w)
		_keep(w)
		w.position = Vector3(x, gy, 0)
		if i == damaged:
			w.set_damage(1)
		out.append(w)
	return out


func _stone_at(p: Vector3, r := 0.24) -> MeshInstance3D:
	return _prop(SB.stone(0, r), Transform3D(Basis(), p))


func _bolt_at(p: Vector3, dir: Vector3) -> MeshInstance3D:
	return _prop(SB.bolt(), Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), p))


# ---------------------------------------------------------------- look

func _slook() -> void:
	_sclear()
	var tiles: Array[Image] = []
	var tris := {}
	# 1 the trebuchet
	var t := _eng("t", "trebuchet", Vector3.ZERO, 0.0)
	t.set_state({"swing": 0.0, "loaded": true})
	tris["trebuchet"] = t.tri_count()
	_cam(Vector3(0, 3.6, 1.6), -2.2, -0.12, 17.0, 42.0)
	tiles.append(await _grab("counterweight trebuchet, cocked: the sling in its trough, the windlass behind"))
	t.set_state({"swing": 0.72, "loaded": false})
	_cam(Vector3(0, 4.4, 1.0), -1.57, -0.04, 18.0, 42.0)
	tiles.append(await _grab("the trebuchet's arm thrown: the box drops, the sling whips over"))
	t.queue_free()
	# 2 the mangonel and the ballista
	var mg := _eng("m", "mangonel", Vector3(-2.2, 0, 0), 0.0)
	tris["mangonel"] = mg.tri_count()
	var ba := _eng("b", "ballista", Vector3(2.2, 0, 0.6), -15.0)
	ba.set_state({"draw": 1.0, "pitch": 0.06})
	tris["ballista"] = ba.tri_count()
	_cam(Vector3(0, 0.9, 0.4), -0.8, -0.22, 8.0, 42.0)
	tiles.append(await _grab("torsion mangonel (the twisted skein, the cup) and the ballista, drawn"))
	mg.queue_free()
	ba.queue_free()
	# 3 the tower, front and back
	var tw := _eng("tw", "tower", Vector3.ZERO, 0.0, 0, 2, 3)
	tris["tower"] = tw.tri_count()
	_cam(Vector3(0, 4.2, 0), PI - 0.55, -0.1, 16.0, 42.0)
	tiles.append(await _grab("siege tower: wet hides, the lord's arms, the bridge raised"))
	tw.set_state({"bridge": 1.0})
	_cam(Vector3(0, 3.6, 0), 0.6, -0.12, 15.0, 42.0)
	tiles.append(await _grab("from behind: the push bar, the ladders between floors; bridge down"))
	tw.queue_free()
	# 4 the ram
	var rm := _eng("r", "ram", Vector3.ZERO, 0.0, 0, 4)
	rm.set_state({"swing": 0.3})
	tris["ram"] = rm.tri_count()
	_cam(Vector3(0, 1.3, -1.0), PI - 0.75, -0.12, 10.0, 42.0)
	tiles.append(await _grab("roofed battering ram: hides on the roof, the log hung on ropes, the iron head"))
	rm.queue_free()
	# 5 the approach kit: ladders, mantlets in six lords' arms, fascines
	for l in 3:
		_eng("mt%d" % l, "mantlet", Vector3(-3.0 + 2.6 * l, 0, 0), 0.0, 0, l)
	_ladder(Vector3(4.2, 0.02, 1.2), Vector3(0, 0.05, -1), false)
	_ladder(Vector3(5.0, 0.0, 2.6), Vector3(0, 0.95, -0.3), false)
	for k in 4:
		var f := _eng("f%d" % k, "fascine", Vector3(-0.6 + 0.1 * k, 0.3 + (0.52 if k == 3 else 0.0), -2.4 - (0.62 * k if k < 3 else 0.62)), 0.0, 0, 0, k + 1)
		f.rotation.y = 0.05 * k
	tris["mantlet"] = (engs["mt0"] as SiegeEngine).tri_count()
	tris["fascine"] = (engs["f0"] as SiegeEngine).tri_count()
	tris["ladder"] = SB.ladder(0)["body"].tri_count()
	_cam(Vector3(0.6, 1.0, 0.8), PI - 0.45, -0.22, 11.5, 42.0)
	tiles.append(await _grab("wheeled mantlets in the lords' arms, scaling ladders, fascines"))
	_sclear()
	for l in 3:
		_eng("mt%d" % l, "mantlet", Vector3(-3.0 + 2.6 * l, 0, 0), 0.0, 0, l + 3)
	_cam(Vector3(0.0, 1.0, 0.4), 0.5, -0.12, 8.5, 42.0)
	tiles.append(await _grab("more lords' mantlets; behind: the handles and the loophole"))
	_sclear()
	# 6 close / mid / far
	var lt := []
	for lod in 3:
		var e := _eng("lt%d" % lod, "tower", Vector3(-5.0 + 5.0 * lod, 0, 0), 0.0, lod, 1, 3)
		var e2 := _eng("lr%d" % lod, "ram", Vector3(-5.0 + 5.0 * lod, 0, 6.5), 0.0, lod, 1)
		var e3 := _eng("lm%d" % lod, "mangonel", Vector3(-5.0 + 5.0 * lod, 0, 11.5), 0.0, lod)
		lt.append("%d/%d/%d" % [e.tri_count(), e2.tri_count(), e3.tri_count()])
	var lods := {}
	for k: String in ["trebuchet", "mangonel", "ballista", "tower", "ram", "ladder", "mantlet", "fascine"]:
		var a := []
		for lod in 3:
			var e: SiegeEngine
			if k == "ladder":
				a.append(SB.ladder(lod)["body"].tri_count())
				continue
			e = SiegeEngine.new().setup(k, lod, 0, 1)
			a.append(e.tri_count())
			e.free()
		lods[k] = a
	print("tris close/mid/far ", lods)
	_cam(Vector3(0, 1.8, 5.5), PI - 1.05, -0.38, 24.0, 42.0)
	tiles.append(await _grab("close / mid / far: tower, ram, mangonel (tris %s)" % ", ".join(lt)))
	set_meta("lods", lods)
	_ssave(_tile(tiles, 3), "look")


# ---------------------------------------------------------------- crews

## One crew row: n frames of a job (f(u) sets the scene for u in 0..1), the camera from cam(u).
func _crew_row(label: String, n: int, f: Callable, cam: Callable) -> Image:
	var tiles: Array[Image] = []
	for k in n:
		var u := k / float(n - 1)
		f.call(u)
		cam.call(u)
		tiles.append(await _grab("%s  %d" % [label, k + 1]))
	return _row(tiles, n)


func _rows(only: String, list: Array) -> Array:
	var out := []
	for r: Array in list:
		if only.is_empty() or String(r[0]).contains(only):
			out.append(r)
	return out


func _crews() -> void:
	var only := OS.get_environment("SIEGE_ONLY")
	var sheets := {"engines": [], "assault": []}
	if not only.is_empty():
		sheets = {"debug": []}
	var list: Array = [
		["treb_winch", "engines"], ["treb_load", "engines"], ["treb_loose", "engines"],
		["mang_crank", "engines"], ["mang_load", "engines"], ["ballista_crew", "engines"],
		["tower_push", "assault"], ["ram_crew", "assault"], ["ladder_carry", "assault"],
		["ladder_raise", "assault"], ["ladder_climb", "assault"], ["kit_crew", "assault"]]
	for r: Array in _rows(only, list):
		_sclear()
		var img: Image = await call("_c_" + String(r[0]))
		(sheets["debug" if not only.is_empty() else String(r[1])] as Array).append(img)
	for k: String in sheets:
		if not (sheets[k] as Array).is_empty():
			_ssave(_stack(sheets[k]), "crews_" + k)


# The trebuchet: two men at the spoke wheels winding the arm down.
func _c_treb_winch() -> Image:
	var t := _eng("t", "trebuchet", Vector3.ZERO, 0.0)
	for s in 2:
		_crewman("w%d" % s, 20 + s, "levy", s)
	var f := func(u: float) -> void:
		var w := u * PI * 0.5
		t.set_state({"swing": lerpf(0.3, 0.06, u), "winch": w, "cock": true, "loaded": false})
		for s in 2:
			var sd := 1.0 if s == 0 else -1.0
			var sp := _ep("t", t.spoke(sd, 0))
			var inner := _ep("t", t.spoke(sd, 0).lerp(SB.T_WINCH + Vector3(sd * SB.T_SPOKE_X, 0, 0), 0.25))
			var h := sp.y - gy
			_hold("w%d" % s, Vector3(sd * 1.78, 0, SB.T_WINCH.z + 0.35), 90.0 * sd, CS.by_height(h, true),
				sp if sd > 0.0 else inner, inner if sd > 0.0 else sp)
	return await _crew_row("trebuchet: winding the arm down at the spoke wheels", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.3, SB.T_WINCH.z), -1.0, -0.12, 6.0, 42.0))


# The trebuchet: carrying a shot from the heap to the pouch and setting it in.
func _c_treb_load() -> Image:
	var t := _eng("t", "trebuchet", Vector3.ZERO, 0.0)
	t.set_state({"swing": 0.0, "loaded": false})
	_crewman("l", 31, "levy", 1)
	_crewman("h", 32, "levy", 2)
	var st := _stone_at(Vector3.ZERO)
	var pouch: Vector3 = (t.parts["pouch"] as Node3D).position
	var f := func(u: float) -> void:
		# 0..0.35 lift from the heap, 0.35..0.75 carry, 0.75..1 set it in the pouch
		var heap := Vector3(-1.75, 0.3, 4.1)
		var dest := pouch + Vector3(0, 0.22, 0)
		var at: Vector3
		var sp: Vector3
		var yaw := 90.0
		if u < 0.35:
			var k := u / 0.35
			at = Vector3(-1.2, 0, 4.1)
			sp = heap.lerp(Vector3(-1.55, 1.0, 4.1), smoothstep(0.0, 1.0, k))
		elif u < 0.75:
			var k := (u - 0.35) / 0.4
			at = Vector3(-1.2, 0, 4.1).lerp(Vector3(-0.15, 0, pouch.z + 0.6), k)
			yaw = lerpf(90.0, 180.0 + 0.0, k) - 180.0
			yaw = 90.0 - 90.0 * k
			sp = at + Vector3(0, 1.0, -0.38).rotated(Vector3.UP, deg_to_rad(yaw))
		else:
			var k := (u - 0.75) / 0.25
			at = Vector3(-0.15, 0, pouch.z + 0.6)
			yaw = 0.0
			sp = (at + Vector3(0, 1.0, -0.38)).lerp(dest + Vector3(-0.15, 0, 0), smoothstep(0.0, 1.0, k)) + Vector3(0.15 * k, 0, 0)
		st.position = Vector3(sp.x, gy + sp.y, sp.z)
		var side := Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(yaw)) * 0.24
		var hb := CS.by_height(sp.y - 0.0)
		_hold("l", at, yaw, hb, st.position + side, st.position - side)
		# his mate stands at the trough, holding the sling's ropes open
		var ropes := _ep("t", pouch + Vector3(0, 0.15, 0.55))
		_hold("h", Vector3(0.7, 0, pouch.z + 0.8), -60.0, CS.bent(40.0, 25.0), ropes + Vector3(0.05, 0, 0), ropes - Vector3(0.05, 0, 0))
	return await _crew_row("trebuchet: a shot from the heap to the pouch", 6, f,
		func(u: float) -> void: _cam(Vector3(-0.6, 0.8, 3.3), -2.0, -0.22, 6.5, 42.0))


# The trebuchet: the master pulls the pin; the arm whips over and the shot flies.
func _c_treb_loose() -> Image:
	var t := _eng("t", "trebuchet", Vector3.ZERO, 0.0)
	_crewman("p", 41, "crossbow", 3)
	_crewman("c1", 42, "levy", 3)
	_crewman("c2", 43, "levy", 4)
	var st := _stone_at(Vector3.ZERO)
	st.visible = false
	var us: Array[float] = [0.0, 0.08, 0.3, 0.5, RELEASE_U, 0.9]
	var f := func(u: float) -> void:
		var i := int(round(u * 5.0))
		var su: float = us[i]
		var hand := _ep("t", Vector3(1.9, 1.05, 5.9))
		if i == 1:
			hand = _ep("t", Vector3(2.2, 1.2, 6.2))
		t.set_state({"swing": su, "loaded": true, "lanyard_to": t.to_local(hand)})
		var body := CS.stand() if i == 0 else CS.haul(16.0, 0.1)
		_hold("p", Vector3(2.35, 0, 6.15), -110.0, body, hand + Vector3(0.04, 0, 0), hand - Vector3(0.04, 0, 0.0))
		var duck := CS.crouch(10.0) if i >= 2 else CS.stand()
		_hold("c1", Vector3(-2.2, 0, 5.2), 120.0, duck, null, null)
		_hold("c2", Vector3(-2.0, 0, 6.6), 150.0, duck if i >= 3 else CS.bent(20.0), null, null)
		st.visible = false
		if su >= RELEASE_U:
			# the shot leaves at the release, along the pouch's swing
			var e := SiegeEngine.new().setup("trebuchet", 0)
			e.set_state({"swing": RELEASE_U})
			var p0 := (t.transform * (e.parts["pouch"] as Node3D).position)
			e.set_state({"swing": RELEASE_U - 0.03})
			var p1 := (t.transform * (e.parts["pouch"] as Node3D).position)
			e.free()
			var v := (p0 - p1).normalized()
			var p := p0 + v * (0.0 if i == 4 else 7.0) + Vector3(0, -0.6 if i == 5 else 0.0, 0)
			st.position = p
			st.visible = true
			_trail(p - v * 3.0, p, 0.16)
	return await _crew_row("trebuchet: the pin pulled, the arm whips over, the shot flies", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 4.6, 0.5), -1.45, -0.02, 21.0, 42.0))


const RELEASE_U := 0.62


# The mangonel: two men at the windlass spokes winding the arm back.
func _c_mang_crank() -> Image:
	var m := _eng("m", "mangonel", Vector3.ZERO, 0.0)
	for s in 2:
		_crewman("w%d" % s, 50 + s, "levy", s + 2)
	var f := func(u: float) -> void:
		var w := u * PI * 0.5
		m.set_state({"throw": lerpf(0.35, 0.0, u), "winch": w, "cock": true, "loaded": false})
		for s in 2:
			var sd := 1.0 if s == 0 else -1.0
			var sp := _ep("m", m.spoke(sd, 0))
			var inner := _ep("m", m.spoke(sd, 0).lerp(SB.M_WINCH + Vector3(sd * SB.M_SPOKE_X, 0, 0), 0.3))
			_hold("w%d" % s, Vector3(sd * 1.42, 0, SB.M_WINCH.z + 0.2), 90.0 * sd, CS.by_height(sp.y - gy),
				sp if sd > 0.0 else inner, inner if sd > 0.0 else sp)
	return await _crew_row("mangonel: winding the arm back against the skein", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 0.9, 1.0), -0.85, -0.2, 6.0, 42.0))


# The mangonel: the stone lifted into the cup, the pin knocked out, the arm hits the stop beam.
func _c_mang_load() -> Image:
	var m := _eng("m", "mangonel", Vector3.ZERO, 0.0)
	_crewman("l", 61, "levy", 2)
	_crewman("p", 62, "spearman", 2)
	var st := _stone_at(Vector3.ZERO, 0.2)
	var f := func(u: float) -> void:
		var i := int(round(u * 5.0))
		var cup := _ep("m", m.at_part("arm", Vector3(0, 0.3, SB.M_ARM)))
		if i <= 1:
			m.set_state({"throw": 0.0, "loaded": i == 1})
			cup = _ep("m", m.at_part("arm", Vector3(0, 0.3, SB.M_ARM)))
			var sp := Vector3(0.9, 0.6, 3.1) if i == 0 else Vector3(0.45, 0.95, 2.95)
			st.visible = i == 0
			st.position = Vector3(sp.x, gy + sp.y, sp.z)
			var side := Vector3(0, 0, 0.21)
			var hp := st.position if i == 0 else cup
			_hold("l", Vector3(1.25, 0, 2.95), 90.0, CS.by_height(hp.y - gy), hp - side, hp + side)
		else:
			st.visible = false
			var tu := [0.0, 0.0, 0.0, 0.45, 0.8, 1.0][i] as float
			m.set_state({"throw": tu, "loaded": true, "lanyard_to": m.to_local(_ep("m", Vector3(-1.6, 1.0, 3.3)))})
			if tu > 0.05:
				m.state.erase("lanyard_to")
				m.set_state({})
			_hold("l", Vector3(1.5, 0, 3.4), 140.0, CS.crouch(10.0) if i > 2 else CS.stand(), null, null)
		var lh := _ep("m", Vector3(-1.6, 1.0, 3.3))
		if i >= 3:
			lh = _ep("m", Vector3(-1.95, 1.1, 3.7))
		_hold("p", Vector3(-2.0, 0, 3.5), -120.0, CS.haul(14.0) if i >= 3 else CS.stand(), lh + Vector3(0.04, 0, 0), lh - Vector3(0.04, 0, 0))
		if i >= 4:
			var cp := _ep("m", m.at_part("arm", Vector3(0, 0.3, SB.M_ARM)))
			var p := cp + Vector3(0, 1.4 + 2.0 * float(i - 4), -2.5 - 3.5 * float(i - 4))
			st.visible = true
			st.position = p
			_trail(p + Vector3(0, -0.8, 1.6), p, 0.12)
	return await _crew_row("mangonel: the stone into the cup, the pin knocked out, the arm on the stop beam", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.4, 0.6), -1.25, -0.08, 9.5, 42.0))


# The ballista: two men crank the slider back, the loader sets the bolt, the aimer lays it on, loose.
func _c_ballista_crew() -> Image:
	var b := _eng("b", "ballista", Vector3.ZERO, 0.0)
	for s in 2:
		_crewman("w%d" % s, 70 + s, "levy", s)
	_crewman("a", 72, "crossbow", 1)
	_crewman("l", 73, "levy", 1)
	var bolt := _bolt_at(Vector3.ZERO, Vector3.FORWARD)
	bolt.visible = false
	var f := func(u: float) -> void:
		var i := int(round(u * 5.0))
		var draw := [0.0, 0.5, 1.0, 1.0, 1.0, 0.0][i] as float
		b.set_state({"draw": draw, "winch": draw * TAU * 1.5, "loaded": i >= 3 and i < 5, "pitch": 0.08 if i >= 4 else 0.0,
			"yaw": 0.12 if i >= 4 else 0.0})
		for s in 2:
			var sd := 1.0 if s == 0 else -1.0
			var hp := _ep("b", b.crank(sd))
			if i < 3:
				_hold("w%d" % s, Vector3(sd * 0.95, 0, 1.25), 90.0 * sd, CS.by_height(hp.y - gy), hp + Vector3(0, 0, 0.03), hp - Vector3(0, 0, 0.03))
			else:
				_hold("w%d" % s, Vector3(sd * 1.3, 0, 1.6), 90.0 * sd + sd * 30.0, CS.stand(), null, null)
		# the loader with the bolt (frame 3 setting it in the groove)
		if i <= 2:
			var lx := Transform3D(Basis(Vector3.UP, deg_to_rad(60.0)), Vector3(-1.2, gy, -0.4))
			var a := lx * Vector3(0.2, 1.0, -0.3)
			var c := lx * Vector3(-0.15, 1.05, -0.5)
			_hold("l", Vector3(-1.2, 0, -0.4), 60.0, CS.stand(), a, c)
			bolt.visible = true
			bolt.transform = Transform3D(Basis.looking_at((c - a).normalized(), Vector3.UP), (a + c) * 0.5)
		elif i == 3:
			bolt.visible = false
			var mid := _ep("b", b.at_part("bolt", Vector3(0, 0.14, -0.2)))
			var rear := _ep("b", b.at_part("bolt", Vector3(0, 0.14, 0.15)))
			_hold("l", Vector3(-0.75, 0, 0.0), 75.0, CS.bent(25.0, 10.0), rear, mid)
		else:
			bolt.visible = i == 5
			_hold("l", Vector3(-1.4, 0, 0.3), 50.0, CS.stand(), null, null)
			if i == 5:
				var p := _ep("b", Vector3(-0.3, 1.5, -6.0))
				bolt.transform = Transform3D(Basis.looking_at(Vector3(-0.12, 0.08, -1).normalized(), Vector3.UP), p)
				_trail(p + Vector3(0.35, -0.24, 3.0), p, 0.05)
		# the aimer behind the tail, sighting along the stock
		var tr := _ep("b", b.tiller(1.0))
		var tl := _ep("b", b.tiller(-1.0))
		if i >= 3:
			_hold("a", Vector3(0.0, 0, 2.0), 0.0, CS.bent(30.0, 30.0), tr, tl)
		else:
			_hold("a", Vector3(1.4, 0, 2.2), -30.0, CS.stand(), null, null)
	return await _crew_row("ballista: cranked back, the bolt set, laid on the target, loosed", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.0, 0.6), -0.6, -0.22, 4.6, 42.0))


# The tower: men behind the push bar, heaving it on.
func _c_tower_push() -> Image:
	var tw := _eng("tw", "tower", Vector3.ZERO, 0.0, 0, 2, 3)
	var n := 5
	for i in n:
		_crewman("p%d" % i, 80 + i, "levy" if i % 2 == 0 else "spearman", i % 3)
	var clip := CS.push(Vector3(0.18, 1.0, -0.5), Vector3(-0.18, 1.0, -0.5), 0.45)
	var f := func(u: float) -> void:
		var t := u * float(clip["len"]) * 1.5
		var dz := -0.45 * t
		tw.position = Vector3(0, gy, dz)
		for i in n:
			var x := -1.2 + 0.6 * i
			_walkman("p%d" % i, Vector3(x, 0, SB.TW_HALF.z + 1.42 + 0.55 + dz), 0.0, clip, t + 0.21 * i)
			var m: Medieval = men["p%d" % i]
			m.position.z = gy * 0.0 + SB.TW_HALF.z + 1.42 + 0.55 + dz
	return await _crew_row("siege tower: pushed on from behind", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.6, 2.6 - 0.45 * u * 1.6), 0.45, -0.12, 9.0, 42.0))


# The ram: rolled up by the men under the roof, then swung.
func _c_ram_crew() -> Image:
	var r := _eng("r", "ram", Vector3.ZERO, 0.0, 0, 4)
	for i in 6:
		_crewman("m%d" % i, 90 + i, "man_at_arms" if i < 2 else "levy", 4)
	# pushing on the posts (at x +-1.2), the near hand on the post, the other on the eave beam's brace
	var push_r := CS.push(Vector3(0.22, 1.1, -0.42), Vector3(0.1, 1.3, -0.45), 0.5)
	var push_l := CS.push(Vector3(-0.1, 1.3, -0.45), Vector3(-0.22, 1.1, -0.42), 0.5)
	var f := func(u: float) -> void:
		var i := int(round(u * 5.0))
		if i < 2:
			var t := 0.4 * i
			r.set_state({"swing": 0.0})
			r.position.z = -0.5 * t
			for k in 6:
				var sd := -1.0 if k % 2 == 0 else 1.0
				var z := [-2.8, 0.0, 2.8][k / 2] as float + 0.5 - 0.5 * t
				_walkman("m%d" % k, Vector3(sd * 1.0, 0, z), 0.0, push_r if sd > 0.0 else push_l, t + 0.3 * k)
				(men["m%d" % k] as Node3D).position.z = z
		else:
			var th := [0.0, 0.0, -0.45, -0.2, 0.25, 0.42][i] as float
			r.set_state({"swing": th})
			var lean := -th * 30.0
			for k in 6:
				var sd := -1.0 if k % 2 == 0 else 1.0
				var row := k / 2
				var h := _ep("r", r.handle(row, sd))
				var h2 := h + Vector3(0, 0, 0.22)
				var body := CS.bent(18.0 + lean, 22.0)
				_hold("m%d" % k, Vector3(sd * 0.68, 0, SB.R_HANDLES[row] + 0.45), 0.0, body,
					h if sd < 0.0 else h2, h2 if sd < 0.0 else h)
	return await _crew_row("battering ram: rolled up under the roof, then swung on its ropes", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.1, -1.4), -2.35, -0.06, 7.0, 46.0))


# Ladders: carried between the rails by three men.
func _c_ladder_carry() -> Image:
	var lad := _ladder(Vector3.ZERO, Vector3(0, 0, -1))
	for i in 3:
		_crewman("c%d" % i, 100 + i, "levy" if i != 1 else "man_at_arms", i)
	var clip := CS.ladder_carry(1.48)
	var f := func(u: float) -> void:
		var t := u * float(clip["len"]) * 1.6
		var dz := -float(clip["speed"]) * t
		for i in 3:
			_walkman("c%d" % i, Vector3(0, 0, -0.6 - 1.6 * i), 0.0, clip, t)
		lad.transform = _ladder_xf(Vector3(0, gy + 1.5, 0.3 + dz), Vector3(0, 0, -1))
	return await _crew_row("scaling ladder: carried between the rails", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.2, -2.2 - 1.1 * u * 1.6), -0.95, -0.12, 8.0, 42.0))


# Ladders: walked up against the wall (a block for the wall), one man bracing the foot.
func _c_ladder_raise() -> Image:
	_block(Vector3(0, PARA_Y * 0.5, 1.0), Vector3(3.0, PARA_Y * 0.5, 2.3), Color(0.55, 0.53, 0.5))
	var lad := _ladder(Vector3.ZERO, Vector3.UP)
	_crewman("f", 110, "levy", 0)
	_crewman("a", 111, "levy", 1)
	_crewman("b", 112, "man_at_arms", 1)
	var foot := Vector3(0, 0, WALL_Z - 1.31)
	var end := deg_to_rad(107.3)
	var f := func(u: float) -> void:
		var ph := end * smoothstep(0.0, 1.0, u)
		var dir := Vector3(0, sin(ph), -cos(ph))
		lad.transform = _ladder_xf(Vector3(foot.x, gy, foot.z), dir)
		var rp := func(s: float, side: float) -> Vector3: return lad.transform * SiegeEngine.rail(side, s)
		# the foot man, kneeling against the foot, hands on the rails
		_hold("f", Vector3(0, 0, foot.z + 0.55), 180.0, CS.crouch(10.0), rp.call(0.55, -1.0), rp.call(0.55, 1.0))
		# the two walking it up, hands overhead on the rails
		for k in 2:
			var nm := "a" if k == 0 else "b"
			var reach := 1.95 - 0.35 * k
			var s := clampf(reach / maxf(sin(ph), 0.05), 1.3, 4.6 - 1.0 * k)
			if ph > PI * 0.5:
				s = 1.4 + 0.2 * k
			var p := foot + dir * s
			var at := Vector3(p.x + (0.0), 0, p.z - 0.25)
			if ph > PI * 0.5:
				at = Vector3(0.6 * (1 - 2 * k), 0, foot.z - 0.55)
			var hb := CS.by_height(rp.call(s, 1.0).y - gy, true)
			_hold(nm, at + Vector3(0.0, 0, 0), 180.0, hb, rp.call(s, -1.0), rp.call(s, 1.0), true,
				Vector3(0.8, -0.2, 0.3), Vector3(-0.8, -0.2, 0.3))
	return await _crew_row("scaling ladder: walked up, the foot braced, over onto the wall", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.8, -4.0), -1.4, -0.06, 10.0, 42.0))


# Ladders: climbed, one rung at a time.
func _c_ladder_climb() -> Image:
	_block(Vector3(0, PARA_Y * 0.5, 1.0), Vector3(3.0, PARA_Y * 0.5, 2.3), Color(0.55, 0.53, 0.5))
	var ang := deg_to_rad(72.7)
	var foot := Vector3(0, 0, WALL_Z - 4.4 * cos(ang))
	var dir := Vector3(0, sin(ang), cos(ang))
	var lad := _ladder(Vector3(foot.x, gy, foot.z), dir)
	lad.transform = _ladder_xf(Vector3(foot.x, gy, foot.z), dir)
	_crewman("c0", 120, "man_at_arms", 2)
	_crewman("c1", 121, "levy", 2)
	var f := func(u: float) -> void:
		for k in 2:
			var rung := 2 + 5 * (1 - k)
			var along := 0.3 + SB.L_RUNG * rung
			var y0 := along * sin(ang)
			var z0 := foot.z + along * cos(ang) - 0.16
			var m: Medieval = men["c%d" % k]
			m.visible = true
			var uu := fposmod(u + 0.5 * k, 1.0)
			m.position = Vector3(0, gy + y0, z0)
			m.rotation = Vector3(0, PI, 0)
			_show(m, CS.climb(uu, ang, SB.L_RUNG * sin(ang)), false)
	return await _crew_row("scaling ladder: climbed, hand over hand", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 2.4, foot.z), -1.35, 0.0, 7.0, 42.0))


# Mantlets pushed on, fascines carried and thrown down.
func _c_kit_crew() -> Image:
	var mt := _eng("mt", "mantlet", Vector3.ZERO, 0.0, 0, 3)
	_crewman("p", 130, "levy", 3)
	_crewman("x", 131, "crossbow", 3)
	_crewman("f", 132, "levy", 5)
	var fas := _eng("fa", "fascine", Vector3.ZERO, 0.0, 0, 0, 2)
	var push := CS.push(Vector3(0.42, 0.8, -0.38), Vector3(-0.42, 0.8, -0.38), 0.6)
	var carry := CS.fascine_carry()
	var f := func(u: float) -> void:
		var i := int(round(u * 5.0))
		mt.visible = i < 2
		men["p"].visible = i < 2
		men["x"].visible = i < 2
		fas.visible = true
		men["f"].visible = i >= 2
		if i < 2:
			fas.visible = false
			var t := 0.5 * i
			mt.position = Vector3(0, gy, -0.6 * t)
			_walkman("p", Vector3(0, 0, 1.4 + 0.38 - 0.6 * t), 0.0, push, t)
			(men["p"] as Node3D).position.z = 1.4 + 0.38 - 0.6 * t
			_mplay("x", Vector3(0.9, 0, 1.0 - 0.6 * t), 0.0, "xbow_march", t)
		elif i < 4:
			var t := 0.3 * (i - 2)
			_walkman("f", Vector3(0, 0, 0.6), 0.0, carry, t)
			var sh := _mp("f", Vector3(0.3, 1.5, -0.25))
			var fb := (men["f"] as Node3D).global_transform.basis
			fas.transform = Transform3D(Basis(fb.z * -1.0, Vector3.UP, fb.x).orthonormalized(), sh)
			fas.position = sh
		else:
			# heaved up and thrown down in front of him
			var k := i - 4
			var p := Vector3(0, 0, 0.0)
			var fp := Vector3(0, 2.0, -0.45) if k == 0 else Vector3(0, 0.7, -1.4)
			_hold("f", p, 0.0, CS.stand() if k == 0 else CS.bent(45.0, 20.0),
				Vector3(0.25, gy + fp.y - 0.25, fp.z) if k == 0 else null, Vector3(-0.25, gy + fp.y - 0.25, fp.z) if k == 0 else null)
			fas.transform = Transform3D(Basis(), Vector3(0, gy + fp.y, fp.z))
	return await _crew_row("mantlet pushed on, crossbow behind; a fascine run up and thrown down", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.0, 0.4), -0.9, -0.14, 6.5, 42.0))


# ---------------------------------------------------------------- the engines' actions

func _actions() -> void:
	var only := OS.get_environment("SIEGE_ONLY")
	var rows: Array = []
	for nm: String in ["treb_swing", "mang_throw", "ballista_shot", "tower_bridge", "ram_swing"]:
		if only.is_empty() or nm.contains(only):
			_sclear()
			rows.append(await call("_a_" + nm))
	if not rows.is_empty():
		_ssave(_stack(rows), "actions" if only.is_empty() else "debug")


func _a_treb_swing() -> Image:
	var t := _eng("t", "trebuchet", Vector3.ZERO, 0.0)
	var st := _stone_at(Vector3.ZERO)
	st.visible = false
	var us: Array[float] = [0.0, 0.25, 0.45, 0.58, 0.66, 0.85]
	var f := func(u: float) -> void:
		var su: float = us[int(round(u * 5.0))]
		t.set_state({"swing": su, "loaded": true})
		st.visible = su >= RELEASE_U
		if st.visible:
			var p: Vector3 = t.transform * (t.parts["pouch"] as Node3D).position
			st.position = p + Vector3(0, 2.5 * (su - RELEASE_U) * 10.0, -3.0 * (su - RELEASE_U) * 10.0)
	return await _crew_row("trebuchet: the arm's throw", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 6.5, -1.5), -PI * 0.5, 0.0, 27.0, 42.0))


func _a_mang_throw() -> Image:
	var m := _eng("m", "mangonel", Vector3.ZERO, 0.0)
	var us: Array[float] = [0.0, 0.3, 0.55, 0.75, 0.9, 1.0]
	var f := func(u: float) -> void:
		m.set_state({"throw": us[int(round(u * 5.0))], "loaded": true})
	return await _crew_row("mangonel: the skein throws the arm onto the stop beam", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.3, 0.3), -PI * 0.5, -0.02, 7.5, 42.0))


func _a_ballista_shot() -> Image:
	var b := _eng("b", "ballista", Vector3.ZERO, 0.0)
	var bolt := _bolt_at(Vector3.ZERO, Vector3.FORWARD)
	bolt.visible = false
	var f := func(u: float) -> void:
		var i := int(round(u * 5.0))
		var draw := [0.0, 0.4, 0.8, 1.0, 0.0, 0.0][i] as float
		b.set_state({"draw": draw, "loaded": i >= 1 and i <= 3, "winch": draw * TAU})
		bolt.visible = i >= 4
		if bolt.visible:
			var p := _ep("b", Vector3(0, 1.36, -1.6 - 2.5 * (i - 4)))
			bolt.transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), p)
	return await _crew_row("ballista: drawn back by the slider, loosed", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.1, -0.6), -0.7, -0.35, 4.2, 42.0))


func _a_tower_bridge() -> Image:
	var tw := _eng("tw", "tower", Vector3.ZERO, 0.0, 0, 2, 3)
	var f := func(u: float) -> void:
		tw.set_state({"bridge": smoothstep(0.0, 1.0, u)})
	return await _crew_row("siege tower: the bridge let down on its chains", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 4.6, -1.0), -PI * 0.5 - 0.35, -0.04, 13.0, 42.0))


func _a_ram_swing() -> Image:
	var r := _eng("r", "ram", Vector3.ZERO, 0.0, 0, 4)
	var ths: Array[float] = [0.0, -0.25, -0.45, -0.1, 0.25, 0.42]
	var f := func(u: float) -> void:
		r.set_state({"swing": ths[int(round(u * 5.0))]})
	return await _crew_row("battering ram: the log drawn back and swung on its ropes", 6, f,
		func(u: float) -> void: _cam(Vector3(0, 1.1, -1.4), -PI * 0.5 - 0.5, 0.0, 9.0, 46.0))


# ---------------------------------------------------------------- the siege

func _siege() -> void:
	var only := OS.get_environment("SIEGE_ONLY")
	var tiles: Array[Image] = []
	for nm: String in ["lines", "trebuchet", "strike", "trench", "bolt", "ram", "tower", "ladders", "fascines"]:
		if only.is_empty() or nm.contains(only):
			_sclear()
			tiles.append(await call("_s_" + nm))
	if not tiles.is_empty():
		_ssave(_tile(tiles, 3), "siege" if only.is_empty() else "debug")


## Our riflemen on the wall walk at xs (facing the host), firing or ducking.
func _defenders(xs: Array, seed0: int, fire := true) -> void:
	var aim := F.aim(false)
	for i in xs.size():
		var nm := "o%d" % i
		_ours(nm, seed0 + i)
		_put(nm, Vector3(float(xs[i]), WALK_Y, -0.62), 0.0, aim if (fire or i % 2 == 0) else F.duck(false))
		if fire and i % 2 == 0:
			_shot(nm, 0.04 + 0.1 * i)


func _s_lines() -> Image:
	_walls()
	_defenders([-9.0, -6.5, -3.4, 3.4, 6.0, 9.5], 500)
	var tb := _eng("t", "trebuchet", Vector3(-14.0, 0, -52.0), 168.0)
	tb.set_state({"swing": 0.0})
	var mg := _eng("m", "mangonel", Vector3(9.0, 0, -36.0), 185.0)
	mg.set_state({"throw": 0.0})
	var ba := _eng("b", "ballista", Vector3(-3.0, 0, -28.0), 180.0)
	ba.set_state({"draw": 1.0, "pitch": 0.05})
	var tw := _eng("tw", "tower", Vector3(-9.5, 0, -16.0), 180.0, 0, 2, 3)
	tw.set_state({"bridge": 0.0})
	var rm := _eng("r", "ram", Vector3(0.0, 0, -14.0), 180.0, 0, 4)
	for i in 4:
		_eng("mt%d" % i, "mantlet", Vector3(3.5 + 2.8 * i, 0, -15.0 - 0.6 * (i % 2)), 180.0, 0, i)
		_crewman("x%d" % i, 520 + i, "crossbow", i)
		_mplay("x%d" % i, Vector3(3.5 + 2.8 * i + 0.5, 0, -16.6 - 0.6 * (i % 2)), 180.0, "xbow_reload" if i % 2 == 0 else "xbow_shoot", 0.6)
	for i in 4:
		_crewman("tp%d" % i, 540 + i, "levy", 2)
		_walkman("tp%d" % i, Vector3(-10.7 + 0.8 * i, 0, -19.3), 180.0, CS.push(Vector3(0.18, 1.0, -0.5), Vector3(-0.18, 1.0, -0.5), 0.45), 0.25 * i)
		(men["tp%d" % i] as Node3D).position.z = -19.3
	var lad := _ladder(Vector3.ZERO, Vector3(0, 0, 1))
	lad.transform = _ladder_xf(Vector3(14.0, gy + 1.5, -21.0), Vector3(0, 0, 1))
	var clip := CS.ladder_carry(1.48)
	for i in 3:
		_crewman("lc%d" % i, 560 + i, "levy", 5)
		_walkman("lc%d" % i, Vector3(14.0, 0, -19.6 - 1.6 * i), 180.0, clip, 0.2)
		(men["lc%d" % i] as Node3D).position.z = -19.6 - 1.6 * i
	_cam(Vector3(-1.0, 2.0, -18.0), PI - 0.5, -0.2, 40.0, 46.0)
	stage.sun.directional_shadow_max_distance = 80.0
	return await _grab("1  the siege lines before our wall: trebuchet, mangonel, ballista, mantlets, tower, ram, ladders")


func _s_trebuchet() -> Image:
	_walls()
	var tb := _eng("t", "trebuchet", Vector3(0, 0, -38.0), 180.0)
	tb.set_state({"swing": 0.72, "loaded": false})
	for i in 3:
		_crewman("c%d" % i, 600 + i, "levy", 3)
	_hold("c0", Vector3(2.3, 0, -44.2), 70.0, CS.haul(16.0), _ep("t", Vector3(2.2, 1.2, 6.2)), _ep("t", Vector3(2.15, 1.2, 6.2)))
	_hold("c1", Vector3(-2.2, 0, -43.2), -60.0, CS.crouch(10.0), null, null)
	_hold("c2", Vector3(-1.9, 0, -45.0), -30.0, CS.stand(), null, null)
	var a := Vector3(0, gy + 9.0, -40.0)
	var b := Vector3(0.3, gy + PARA_Y, -1.2)
	var p := lob(a, b, 7.0, 0.45)
	_stone_at(p)
	_trail(lob(a, b, 7.0, 0.36), p, 0.18)
	_trail(lob(a, b, 7.0, 0.26), lob(a, b, 7.0, 0.36), 0.12, Color(0.8, 0.76, 0.66, 0.15))
	_cam(Vector3(0, 5.0, -30.0), PI + 0.55, -0.1, 22.0, 46.0)
	return await _grab("2  the trebuchet looses: the arm thrown over, the shot climbing toward the wall")


func _s_strike() -> Image:
	_walls(true)
	_defenders([-11.5, -10.0, -5.5, -4.0, 4.0, 5.5], 620, false)
	var hit := Vector3(-8.0, gy + 3.9, WALL_Z - 0.1)
	fx.append(["hit_dirt", hit, 0.25, Vector3(0, 0.3, -1).normalized()])
	fx.append(["hit_dirt", Vector3(-8.0, gy + 3.6, WALL_Z - 0.2), 0.3, Vector3(0, 0, -1)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 9:
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.0), rng.randf_range(-1.0, 0.1))
		var g := UnitGeo.new()
		g.box(Vector3.ZERO, Vector3(0.12, 0.08, 0.1) * rng.randf_range(0.6, 1.4), Color(0.6, 0.6, 0.58), 0)
		_prop(g, Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * 3.0), hit + d * rng.randf_range(0.8, 2.6)))
	_stone_at(Vector3(-7.4, gy + 0.25, WALL_Z - 1.6), 0.24)
	_cam(Vector3(-7.6, 3.2, -1.6), PI - 0.45, -0.1, 10.0, 44.0)
	return await _grab("3  a stone strikes the wall: the parapet broken, our men down behind it")


func _s_trench() -> Image:
	_trench_set()
	var top := 1.7
	var ox: Array[float] = [-3.0, -1.5, 0.0, 1.5, 3.0]
	for i in 5:
		_ours("o%d" % i, 640 + i)
		var spec := F.duck(false) if i != 3 else F.aim(false)
		_put("o%d" % i, Vector3(ox[i], 0.5, -0.5), 0.0, spec)
	fx.append(["hit_dirt", Vector3(-1.2, gy + 0.1, 0.2), 0.12, Vector3.UP])
	fx.append(["hit_dirt", Vector3(2.4, gy + top, -1.4), 0.4, Vector3(0, 1, -0.3).normalized()])
	var a := Vector3(4.0, gy + top + 1.0, -30.0)
	var b := Vector3(2.6, gy + top, -1.0)
	var p := lob(a, b, 6.0, 0.9)
	_stone_at(p, 0.2)
	_trail(lob(a, b, 6.0, 0.7), p, 0.12)
	var mg := _eng("m", "mangonel", Vector3(5.0, top, -24.0), 190.0)
	mg.set_state({"throw": 1.0, "loaded": false})
	for r: MeshInstance3D in rear:
		r.visible = false
	_cam(Vector3(0.6, 0.8, -0.6), PI - 0.55, -0.5, 10.5, 46.0)
	return await _grab("4  mangonel stones fall on our trench; the men keep their heads down")


func _s_bolt() -> Image:
	_walls()
	_defenders([-12.8, -11.6, -6.0], 660)
	_ours("hit", 670)
	_play("hit", Vector3(-10.2, WALK_Y, -0.5), 0.0, "death_back", 0.42)
	var m: Soldier = men["hit"]
	var chest := m.global_transform * m.skel.get_bone_global_pose(B.CHEST)
	_bolt_at(chest.origin + chest.basis.z * -0.05 + Vector3(0, 0.05, -0.35), Vector3(0.05, -0.08, 1))
	_bolt_at(Vector3(-13.6, gy + 4.0, WALL_Z - 0.42), Vector3(0.1, -0.15, 1))
	_bolt_at(Vector3(-7.2, gy + 3.7, WALL_Z - 0.42), Vector3(-0.08, -0.1, 1))
	var ba := _eng("b", "ballista", Vector3(-11.0, 0, -24.0), 182.0)
	ba.set_state({"draw": 0.0, "loaded": false, "pitch": 0.1})
	_cam(Vector3(-10.2, 3.9, -0.8), PI - 0.5, -0.32, 7.5, 44.0)
	return await _grab("5  a ballista bolt: through our man on the wall walk, others stuck in the parapet")


func _s_ram() -> Image:
	var ws := _walls()
	BldWalls.set_gate(ws[2], 0.06)
	var rm := _eng("r", "ram", Vector3(0, 0, -4.9), 180.0, 0, 4)
	rm.set_state({"swing": 0.42})
	for k in 6:
		_crewman("m%d" % k, 680 + k, "man_at_arms" if k < 2 else "levy", 4)
		var sd := -1.0 if k % 2 == 0 else 1.0
		var row := k / 2
		var h := _ep("r", rm.handle(row, sd))
		var h2 := h + rm.transform.basis * Vector3(0, 0, 0.22)
		_hold("m%d" % k, rm.transform * Vector3(sd * 0.68, 0, SB.R_HANDLES[row] + 0.45) - Vector3(0, gy, 0), 180.0, CS.bent(6.0, 22.0),
			h2 if sd < 0.0 else h, h if sd < 0.0 else h2)
	fx.append(["hit_dirt", Vector3(0, gy + 1.2, -0.3), 0.15, Vector3(0, 0.3, -1).normalized()])
	for i in 3:
		_ours("o%d" % i, 690 + i)
		_put("o%d" % i, Vector3(-1.2 + 1.2 * i, 3.8, -0.75), 0.0, F.aim(false))
		_shot("o%d" % i, 0.05 + 0.1 * i)
	_cam(Vector3(0, 1.6, -3.0), PI - 0.85, -0.14, 11.0, 44.0)
	return await _grab("6  the ram at our gate: the leaves bow in under the iron head; our men fire down on the roof")


func _s_tower() -> Image:
	_walls()
	var tw := _eng("tw", "tower", Vector3(-8.0, 0, -5.32), 180.0, 0, 2, 3)
	tw.set_state({"bridge_angle": 0.255})
	# men-at-arms come across the bridge; our men meet them on the walk
	var rush := ["r0", "r1", "r2"]
	for i in 3:
		_med(rush[i], 700 + i, "man_at_arms" if i != 1 else "heavy", 2, 0, "" if i != 1 else "poleaxe")
	_mplay("r0", Vector3(-8.3, PARA_Y, WALL_Z + 0.16), 180.0, "sword_strike", 0.35)
	_mplay("r1", Vector3(-7.4, 4.55, -2.6), 180.0, "pole_strike", 0.2)
	_mplay("r2", Vector3(-8.6, 4.7, -3.4), 180.0, "run", 0.2)
	_ours("o0", 710)
	_put("o0", Vector3(-8.2, WALK_Y, 0.2), 0.0, F.lunge(false))
	_ours("o1", 711)
	_play("o1", Vector3(-7.0, WALK_Y, 0.1), 0.0, "death_back", 0.5)
	_ours("o2", 712)
	_put("o2", Vector3(-10.0, WALK_Y, -0.3), 0.0, F.aim(false))
	_shot("o2", 0.05)
	_cam(Vector3(-8.0, 4.3, -2.0), PI - 1.5, -0.12, 12.0, 44.0)
	return await _grab("7  the tower docks: the bridge drops on the parapet and the host comes across")


func _s_ladders() -> Image:
	_walls()
	var ang := deg_to_rad(72.7)
	var dir := Vector3(0, sin(ang), cos(ang))
	var xs: Array[float] = [-10.0, -6.5, -3.0]
	var n := 0
	for li in 3:
		var foot := Vector3(xs[li], gy, WALL_Z - 4.4 * cos(ang))
		var lad := _ladder(foot, dir)
		lad.transform = _ladder_xf(foot, dir)
		for k in 2:
			var nm := "c%d" % n
			n += 1
			_crewman(nm, 720 + n, "man_at_arms" if k == 0 else "levy", li)
			var rung := 1 + 4 * k + li if k == 1 else 9 - li
			var along := 0.3 + SB.L_RUNG * rung
			var m: Medieval = men[nm]
			m.visible = true
			m.position = Vector3(xs[li], gy + along * sin(ang), foot.z + along * cos(ang) - 0.16)
			m.rotation = Vector3(0, PI, 0)
			_show(m, CS.climb(0.25 * (li + k), ang, SB.L_RUNG * sin(ang)), false)
	_defenders([-9.0, -7.5, -4.6, -1.8], 740)
	# one comes off his ladder
	_med("fall", 760, "levy", 1)
	_mplay("fall", Vector3(-7.4, 0, -3.4), 180.0, "death_back", 1.0)
	_cam(Vector3(-6.5, 2.6, -2.6), PI - 0.85, -0.04, 13.5, 46.0)
	return await _grab("8  ladders up the wall: the host climbs while our men fire down")


func _s_fascines() -> Image:
	_trench_set()
	var top := 1.7
	for r: MeshInstance3D in rear:
		r.visible = false
	# fascines already down in the trench
	for k in 7:
		var fa := _eng("fd%d" % k, "fascine", Vector3(-1.6 + 0.9 * (k % 4), 0.32 + 0.5 * float(k / 4), -0.2 + 0.25 * float(k % 2)), 90.0 + 8.0 * float(k % 3), 0, 0, k + 3)

	# a carrier at the lip throwing one down, another running in, a mantlet with crossbowmen behind
	_crewman("f0", 780, "levy", 1)
	var f0 := _eng("f0", "fascine", Vector3.ZERO, 0.0, 0, 0, 11)
	_hold("f0", Vector3(0.5, top, -1.6), 180.0, CS.bent(40.0, 20.0), Vector3(0.75, gy + top + 0.6, -0.85), Vector3(0.25, gy + top + 0.6, -0.85))
	f0.transform = Transform3D(Basis(), Vector3(0.5, gy + top + 0.55, -0.6))
	_crewman("f1", 781, "levy", 2)
	_walkman("f1", Vector3(-2.2, top, -5.0), 180.0, CS.fascine_carry(), 0.3)
	var f1 := _eng("f1", "fascine", Vector3.ZERO, 0.0, 0, 0, 12)
	var sh := _mp("f1", Vector3(0.3, 1.5, -0.25))
	var fb := (men["f1"] as Node3D).global_transform.basis
	f1.transform = Transform3D(Basis(-fb.z, Vector3.UP, fb.x).orthonormalized(), sh)
	var mt := _eng("mt", "mantlet", Vector3(2.8, top, -6.5), 175.0, 0, 1)

	_crewman("x0", 782, "crossbow", 1)
	_mplay("x0", Vector3(2.4, top, -7.9), 180.0, "xbow_reload", 0.9)
	_crewman("x1", 783, "crossbow", 1)
	_mplay("x1", Vector3(4.2, top, -7.3), 200.0, "xbow_shoot", 0.25)
	fx.append(["hit_dirt", Vector3(2.6, gy + top + 1.2, -5.9), 0.1, Vector3(0, 0.2, 1).normalized()])
	_bolt_at(Vector3(3.3, gy + top + 1.4, -5.75), Vector3(0, -0.1, -1))
	_stuck(Vector3(0.0, top, 1.6), 0, 0.1, 1)
	# our men pulled back from the trench line, firing at the mantlet
	for i in 3:
		_ours("o%d" % i, 790 + i)
		_put("o%d" % i, Vector3(-2.5 + 2.2 * i, top, 3.2), 0.0, F.aim(false))
		_shot("o%d" % i, 0.05 + 0.1 * i)
	_cam(Vector3(0.6, 1.6, -2.0), 1.05, -0.34, 13.0, 46.0)
	return await _grab("9  under the mantlets' cover, fascines thrown down to fill our trench")
