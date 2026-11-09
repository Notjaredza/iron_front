extends "res://tools/tank_clips.gd"
## The rocket lorry, recorded as video frames (Tanks Chat, 2026-11-10).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/rocket_clips.gd -- [scene ...]
## Scenes: gallery, look, setup, load, fire, packup, wreck. Frames go to
## results/units/anim_frames/rocket_<scene>/; ffmpeg makes results/units/anim/rocket_<scene>.mp4.
## The lorry parks at the origin facing -Z, so its frame is the world frame once it stops.

const RB := preload("res://scripts/vehicles/rocket_builder.gd")
const GC := preload("res://scripts/units/anim/clips_gun.gd")
const ROCKET_SCENES: Array[String] = ["gallery", "look", "setup", "load", "fire", "packup", "wreck"]
const SET_TRAIN := 0.3
const SET_ELEV := 42.0
const LOAD_ELEV := 8.0

var rparts: Array = []  # Callable(t)
var flights: Array = []  # {t0, node, flame, p, v, burn, thrust, done, rail}
var blasts: Array = []  # {t0, node}
var rmesh: Mesh
var flame_mat: StandardMaterial3D


func _run() -> void:
	prefix = "rocket_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	rmesh = MG.mesh(RB.rocket(0))
	var args := OS.get_cmdline_user_args()
	if args.has("check"):
		var bad := _rocket_check()
		print("ROCKET CHECK ", "OK" if bad == 0 else "FAILED (%d)" % bad)
		quit(bad)
		return
	for sc in (args if not args.is_empty() else ROCKET_SCENES):
		await _record(sc)
	print("ROCKET CLIPS OK")
	quit()


## Fires a full salvo with no camera: every rocket must land 150-260 m out; triangle budgets per look.
func _rocket_check() -> int:
	var bad := 0
	_reset()
	lay_terrain(func(_x: float, _z: float) -> float: return 0.0, -200.0, 100.0, -340.0, 60.0, 20.0)
	var l := rlorry(Vector3.ZERO, 0.0, parked())
	var n: RocketLorry = l["node"]
	set_up(n)
	for k in 16:
		launch(n, k, 0.1 * k, 500 + k)
	frame = 0
	var landed := []
	for i in int(20.0 * FPS):
		frame = i
		var t := float(i) / FPS
		for f: Dictionary in flights:
			var was: bool = f["done"]
			_fly(f, t)
			if f["done"] and not was:
				landed.append(Vector2((f["p"] as Vector3).x, (f["p"] as Vector3).z).length())
	if landed.size() != 16:
		print("  only %d of 16 landed" % landed.size())
		bad += 1
	for r: float in landed:
		if r < 150.0 or r > 260.0:
			print("  rocket landed at %.0f m" % r)
			bad += 1
	landed.sort()
	if not landed.is_empty():
		print("  landings %.0f .. %.0f m" % [landed[0], landed[-1]])
	var limits := [[0, false, 11000], [1, false, 4000], [2, false, 600], [0, true, 9500]]
	for lm: Array in limits:
		var m := RocketLorry.new().setup_rack(lm[0], lm[1])
		var tc := m.tri_count()
		print("  lod %d%s: %d triangles" % [lm[0], " wreck" if lm[1] else "", tc])
		if tc > int(lm[2]):
			bad += 1
		m.free()
	return bad


func _reset() -> void:
	super._reset()
	rparts.clear()
	flights.clear()
	blasts.clear()


func _eval_props(t: float) -> void:
	if frame != tank_frame:
		for f: Callable in rparts:
			f.call(t)
	super._eval_props(t)


func _eval_actor(a: Dictionary, t: float) -> void:
	if a.has("reparent_at") and t >= float(a["reparent_at"]) and not a.get("reparented", false):
		a["reparented"] = true
		var s: Soldier = a["s"]
		s.get_parent().remove_child(s)
		stage.add_child(s)
	super._eval_actor(a, t)


# ---------------------------------------------------------------- the lorry

func rlorry(at: Vector3, yaw: float, s_fn: Callable, tail_fn: Variant = null, lod := 0, burnt := false) -> Dictionary:
	var n := RocketLorry.new().setup_rack(lod, burnt)
	stage.add_child(n)
	n.position = at
	n.rotation.y = yaw
	var d := {"node": n, "s_fn": s_fn, "curv_fn": null, "tail_fn": tail_fn, "pos": at, "yaw": yaw, "s": 0.0, "run": not burnt,
		"engine": not burnt}
	lorries.append(d)
	return d


func parked() -> Callable:
	return func(_t: float) -> float: return 0.0


## A man riding the lorry (child of its body), placed in its frame.
func crew_rider(seed_value: int, role: String, l: Dictionary, pos: Vector3, yaw: float) -> Dictionary:
	var a := _man(seed_value, role)
	var s: Soldier = a["s"]
	stage.remove_child(s)
	(l["node"] as Lorry).body.add_child(s)
	a["pos"] = pos
	a["yaw"] = yaw
	return a


## The four: the NCO beside the driver in the cab, two on the rear seat facing forward.
func crew_aboard(l: Dictionary) -> Array:
	var body: Node3D = (l["node"] as Lorry).body
	var drv := crew_rider(401, "gunner", l, LB.DRIVER, 0.0)
	var hands := func(_t: float) -> Dictionary:
		var x := body.global_transform
		return {"hand_r": x * (LB.WHEEL_HUB + Vector3(0.17, 0.02, 0.03)), "hand_l": x * (LB.WHEEL_HUB + Vector3(-0.17, 0.02, 0.03))}
	pose(drv, 0.0, 0.0, V.driver(), hands, null)
	var nco := crew_rider(402, "nco", l, Vector3(-0.45, 1.0, -1.42), 0.0)
	pose(nco, 0.0, 0.0, V.seated(-10.0), null, null)
	var a := crew_rider(403, "loader", l, Vector3(-0.38, LB.FLOOR_Y, LB.BED_REAR - 0.33), 0.0)
	pose(a, 0.0, 0.0, V.seated(20.0, 3.0), null, null)
	var b := crew_rider(404, "gunner", l, Vector3(0.38, LB.FLOOR_Y, LB.BED_REAR - 0.33), 0.0)
	pose(b, 0.0, 0.0, V.seated(-20.0, 3.0), null, null)
	return [nco, drv, a, b]


## Out of the open cab on side s (+1 right) at t: drop to the ground beside it. Returns the landing time.
func out_of_cab(a: Dictionary, s: float, t: float) -> float:
	var seat: Vector3 = a["pos"]
	shift(a, t, 0.35, V.crouch(), seat + Vector3(0.35 * s, 0.1, 0), 0.0, null, "smooth", -s * PI * 0.5)
	shift(a, t + 0.4, 0.35, V.airborne(), Vector3(1.35 * s, 0, seat.z), 0.25, null, "lin", -s * PI * 0.5)
	pose(a, t + 0.75, 0.15, V.crouch(1.0), null, "prev", "out")
	a["reparent_at"] = t + 0.9
	pose(a, t + 0.9, 0.35, C.standing("free"))
	return t + 1.25


## From the rear seat, over the open tailgate to the ground (x side). Returns the landing time.
func off_the_back(a: Dictionary, t: float) -> float:
	var sp: Vector3 = a["pos"]
	var xe := 0.3 * signf(sp.x)
	shift(a, t, 0.4, V.stooped(), Vector3(xe, LB.FLOOR_Y, 2.42), 0.0, null, "smooth", PI)
	pose(a, t + 0.45, 0.22, V.crouch())
	shift(a, t + 0.7, 0.32, V.airborne(), Vector3(xe * 2.4, 0, 3.45), 0.35, null, "lin", PI)
	pose(a, t + 1.02, 0.12, V.crouch(1.0), null, "prev", "out")
	a["reparent_at"] = t + 1.2
	pose(a, t + 1.2, 0.3, C.standing("free"))
	return t + 1.5


## Kneeling at a rear jack, hands on its crank (the man is a world actor by then).
func crank_jack(a: Dictionary, n: RocketLorry, s: float, t: float, d: float) -> float:
	var top_l := RB.JACK_R * Vector3(s, 1, 1)  # the lorry is parked at the origin by then
	var top := top_l
	var spot := Vector3(top.x + 0.55 * s, 0, top.z + 0.15)
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var t1 := move(a, t, spot, walk, s * PI * 0.5)
	var crank := func(tt: float) -> Dictionary:
		var w := tt * 6.0
		var c := n.body.global_transform * (top_l + Vector3(0.12 * s, 0.17, 0) + Vector3(0.0, 0.07 * sin(w), 0.07 * cos(w)))
		return {"hand_r": c, "hand_l": c + Vector3(0, 0.02, 0.02)}
	pose(a, t1, 0.5, GC.kneel(22.0), crank)
	pose(a, t1 + 0.5 + d, 0.4, C.standing("free"))
	return t1 + 0.9 + d


# ---------------------------------------------------------------- rockets in flight

## Fires rocket i of lorry n at t0. thrust and spread vary it a little (seeded).
func launch(n: RocketLorry, i: int, t0: float, seed_value: int, wild := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var m := MeshInstance3D.new()
	m.mesh = rmesh
	m.visible = false
	stage.add_child(m)
	var fl := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.09
	sp.height = 0.5
	sp.radial_segments = 8
	sp.rings = 4
	sp.material = _mat("rflame", Color(1.0, 0.75, 0.35), true)
	fl.mesh = sp
	fl.rotation.x = PI * 0.5
	fl.position = Vector3(0, 0, 0.3)
	m.add_child(fl)
	flights.append({"t0": t0, "node": m, "flame": fl, "n": n, "rail": i, "done": false, "started": false,
		"thrust": rng.randf_range(23.0, 25.0) * (0.7 if wild else 1.0), "burn": rng.randf_range(1.5, 1.7),
		"yaw": rng.randf_range(-0.025, 0.025) + (rng.randf_range(-1.0, 1.0) if wild else 0.0),
		"pitch": rng.randf_range(-0.02, 0.02) + (rng.randf_range(0.05, 0.4) if wild else 0.0), "seed": seed_value})


func _fly(f: Dictionary, t: float) -> void:
	var m: MeshInstance3D = f["node"]
	if f["done"] or t < float(f["t0"]):
		return
	var n: RocketLorry = f["n"]
	if not f["started"]:
		f["started"] = true
		var xf := n.rocket_xf(f["rail"])
		var dir := -xf.basis.z.normalized()
		dir = dir.rotated(Vector3.UP, f["yaw"])
		var side := dir.cross(Vector3.UP).normalized()
		dir = dir.rotated(side, f["pitch"])
		f["p"] = xf.origin + dir * RB.ROCKET_LEN * 0.5
		f["v"] = dir * 13.0
		f["dir"] = dir
		n.set_loaded(f["rail"], false)
		m.visible = true
		# The launch: flash and a gout of smoke and dust behind the rack.
		var back := -dir
		puff(xf.origin, back * 3.0, 0.3, Color(1.0, 0.8, 0.45), 0.15, 5.0, 0.9, t)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(f["seed"])
		for k in 5:
			puff(xf.origin + back * rng.randf_range(0.3, 1.5), back * rng.randf_range(2.0, 5.0) + Vector3(rng.randf_range(-1, 1),
				rng.randf_range(0.3, 1.2), rng.randf_range(-1, 1)), 0.5, Color(0.86, 0.85, 0.82), 4.5, 1.4, 0.55, t)
		var g := n.global_position + back.normalized() * 3.5
		g.y = 0.2
		for k in 3:
			puff(g + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)), Vector3(rng.randf_range(-1, 1), 1.0,
				rng.randf_range(-1, 1)), 0.7, Color(0.7, 0.62, 0.47), 3.5, 1.2, 0.5, t)
	var age := t - float(f["t0"])
	var dt := 1.0 / FPS
	var sub := 4
	for k in sub:
		var h := dt / float(sub)
		var v: Vector3 = f["v"]
		var acc := Vector3(0, -9.8, 0)
		if age < float(f["burn"]):
			acc += (f["dir"] as Vector3) * float(f["thrust"])
		v += acc * h
		f["v"] = v
		f["p"] = (f["p"] as Vector3) + v * h
	var p: Vector3 = f["p"]
	var v2: Vector3 = f["v"]
	m.global_transform = Transform3D(Basis.looking_at(v2.normalized(), Vector3.UP if absf(v2.normalized().y) < 0.99 else Vector3.BACK),
		p - v2.normalized() * RB.ROCKET_LEN * 0.5)
	var burning := age < float(f["burn"])
	(f["flame"] as Node3D).visible = burning
	(f["flame"] as Node3D).scale = Vector3.ONE * (0.8 + 0.4 * sin(t * 50.0 + float(f["rail"])))
	if burning:
		puff(p, -v2 * 0.05, 0.12, Color(1.0, 0.65, 0.25), 0.12, 3.0, 0.9, t)
		puff(p, Vector3(0, 0.3, 0), 0.22, Color(0.9, 0.9, 0.88), 3.5, 1.6, 0.45, t)
	elif frame % 3 == 0:
		puff(p, Vector3(0, 0.2, 0), 0.15, Color(0.85, 0.85, 0.83), 2.0, 1.4, 0.22, t)
	var gy := ground_h(p)
	if p.y <= gy and age > 0.3:
		f["done"] = true
		m.visible = false
		var b := Blast.new()
		b.auto = false
		stage.add_child(b)
		b.setup(1, Vector3(p.x, gy, p.z), int(f["seed"]))
		blasts.append({"t0": t, "node": b})


func _effects(t: float) -> void:
	for f: Dictionary in flights:
		_fly(f, t)
	for b: Dictionary in blasts:
		var bn: Blast = b["node"]
		bn.visible = t >= float(b["t0"])
		if bn.visible:
			bn.set_time(t - float(b["t0"]))
	super._effects(t)


## A blast at t0 (shell or cook-off), size 1..8.
func blast_at(t0: float, at: Vector3, size: int, seed_value: int) -> void:
	var b := Blast.new()
	b.auto = false
	b.visible = false
	stage.add_child(b)
	b.setup(size, at, seed_value)
	blasts.append({"t0": t0, "node": b})


# ---------------------------------------------------------------- set-up states

func set_up(n: RocketLorry, elev := SET_ELEV, loaded := 16) -> void:
	n.set_jacks(1.0)
	n.set_train(SET_TRAIN)
	n.set_elev(elev)
	n.set_all_loaded(loaded)
	n.set_tailgate(1.0)


# ---------------------------------------------------------------- gallery and look

const R_GALLERY := [[0, false], [1, false], [2, false], [0, true]]


func _wreck_pose(n: RocketLorry) -> void:
	n.set_jacks(1.0)
	n.set_train(SET_TRAIN + 0.35)
	n.set_elev(18.0)
	for i in 16:
		n.set_loaded(i, i in [0, 2, 3, 6, 9])
	n.body.transform = Transform3D(Basis(Vector3.BACK, 0.06) * Basis(Vector3.RIGHT, -0.03), Vector3(0, -0.1, 0))
	for w: Dictionary in n.wheels:
		(w["node"] as Node3D).position.y = LB.WHEEL_R - 0.06


func _scene_gallery() -> float:
	var info := []
	for i in R_GALLERY.size():
		var g: Array = R_GALLERY[i]
		var d := rlorry(Vector3(18.0 * (i - 1.5), 0, 0), 0.0, parked(), null, g[0], g[1])
		d["engine"] = false
		var n: RocketLorry = d["node"]
		if g[1]:
			d["run"] = false
			_wreck_pose(n)
		else:
			set_up(n)
		info.append(n.tri_count())
	var names := ["Rocket lorry, set up", "Rocket lorry: mid look", "Rocket lorry: far look", "Rocket lorry: wreck"]
	_phases = []
	for i in R_GALLERY.size():
		_phases.append([2.0 * i, "%s, %d triangles: front" % [names[i], info[i]]])
		_phases.append([2.0 * i + 1.0, "%s, %d triangles: back" % [names[i], info[i]]])
	print("GALLERY TRIS ", info)
	_camera = func(t: float) -> void:
		var i := clampi(int(t / 2.0), 0, R_GALLERY.size() - 1)
		var back := fmod(t, 2.0) >= 1.0
		var c := Vector3(18.0 * (i - 1.5), 0, 0.3)
		cam.fov = 40.0
		var dir := Vector3(-0.8, 0.45, -0.55) if not back else Vector3(0.7, 0.5, 0.75)
		cam.transform = Transform3D(Basis(), c + dir.normalized() * 10.0).looking_at(c + Vector3(0, 1.4, 0), Vector3.UP)
	return 2.0 * R_GALLERY.size()


func _scene_look() -> float:
	var d := rlorry(Vector3.ZERO, 0.0, parked())
	d["engine"] = false
	var n: RocketLorry = d["node"]
	n.set_all_loaded(16)
	rparts.append(func(t: float) -> void:
		var u := Anim.ease_of(clampf((t - 1.0) / 2.0, 0.0, 1.0), "smooth") - Anim.ease_of(clampf((t - 10.5) / 2.0, 0.0, 1.0), "smooth")
		n.set_jacks(u)
		n.set_train(SET_TRAIN * Anim.ease_of(clampf((t - 2.5) / 2.0, 0.0, 1.0), "smooth") * (1.0 - Anim.ease_of(clampf((t - 9.0) / 2.0, 0.0, 1.0), "smooth")))
		n.set_elev(SET_ELEV * Anim.ease_of(clampf((t - 3.5) / 2.5, 0.0, 1.0), "smooth") * (1.0 - Anim.ease_of(clampf((t - 8.0) / 2.0, 0.0, 1.0), "smooth"))))
	_phases = [[0.0, "Rocket lorry, close look: %d triangles (mid and far looks in the gallery)" % n.tri_count()],
		[1.0, "Jacks down, rack trained and raised"], [8.0, "Rack down and jacks up for travel"]]
	_camera = func(t: float) -> void:
		cam.fov = 42.0
		var a := 2.3 - t * 0.38
		cam.transform = Transform3D(Basis(), Vector3(sin(a) * 11.0, 4.0, cos(a) * 11.0)).looking_at(Vector3(0, 1.5, 0.2), Vector3.UP)
	return 13.0


# ---------------------------------------------------------------- set up

func _scene_setup() -> float:
	var stop_t := 4.0
	var tail := func(t: float) -> float: return Anim.ease_of(clampf((t - 4.4) / 0.6, 0.0, 1.0), "in")
	var l := rlorry(Vector3(0, 0, 16.0), 0.0, arrive(stop_t, 16.0, 2.2, 5.0), tail)
	var n: RocketLorry = l["node"]
	n.set_all_loaded(16)
	var crew := crew_aboard(l)
	var nco: Dictionary = crew[0]
	var drv: Dictionary = crew[1]
	var a: Dictionary = crew[2]
	var b: Dictionary = crew[3]
	l["engine"] = true
	rparts.append(func(t: float) -> void:
		l["engine"] = t < 5.0)
	# Out: the NCO and the driver from the cab, the two from the back.
	var t_n := out_of_cab(nco, -1.0, 4.4)
	var t_d := out_of_cab(drv, 1.0, 4.9)
	var t_a := off_the_back(a, 5.2)
	var t_b := off_the_back(b, 5.9)
	# The two crank the jacks down.
	var ja := crank_jack(a, n, -1.0, t_a + 0.1, 2.4)
	var jb := crank_jack(b, n, 1.0, t_b + 0.1, 2.0)
	rparts.append(func(t: float) -> void:
		n.set_tailgate(tail.call(t))
		n.set_jacks(Anim.ease_of(clampf((t - 7.8) / 2.2, 0.0, 1.0), "smooth")))
	# The NCO walks out to the side and points the line; the driver climbs up to the handwheel.
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var tn := move(nco, t_n + 0.1, Vector3(-5.5, 0, -3.0), walk, 0.0)
	var target := Vector3(-sin(SET_TRAIN), 0.15, -cos(SET_TRAIN)) * 40.0
	pose(nco, tn, 0.5, GC.nco_point(target - Vector3(-5.5, 0, -3.0)))
	pose(nco, tn + 5.0, 0.6, GC.nco_order(0.0))
	var td := move(drv, move(drv, t_d + 0.2, Vector3(1.6, 0, 3.8), walk), Vector3(0.35, 0, 3.3), walk, 0.0)
	var edge := func(_t: float) -> Dictionary:
		return {"hand_r": Vector3(0.6, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04), "hand_l": Vector3(0.1, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04)}
	pose(drv, maxf(td, 9.0), 0.35, V.climb(0, LB.STEP.y, LB.FLOOR_Y), edge)
	var tc := maxf(td, 9.0)
	shift(drv, tc + 0.4, 0.45, V.climb(1, LB.STEP.y, LB.FLOOR_Y), Vector3(0.35, LB.STEP.y, 2.95), 0.0, edge)
	shift(drv, tc + 0.9, 0.45, V.climb(2, LB.STEP.y, LB.FLOOR_Y), Vector3(0.35, LB.FLOOR_Y, 2.4), 0.0)
	shift(drv, tc + 1.4, 0.5, C.standing("free"), Vector3(-0.98, LB.FLOOR_Y, 1.15), 0.0, null, "smooth", -PI * 0.5)
	var wheel := func(tt: float) -> Dictionary:
		var w := tt * 5.0
		var c := n.turntable.global_transform * Vector3(-0.64, 0.28, 0.3)
		return {"hand_r": c + Vector3(0, 0.1 * sin(w), 0.1 * cos(w)), "hand_l": c + Vector3(0, -0.1 * sin(w), -0.1 * cos(w))}
	pose(drv, tc + 2.0, 0.5, GC.heave(18.0, 10.0), wheel)
	var t_tr := tc + 2.4
	rparts.append(func(t: float) -> void:
		n.set_train(SET_TRAIN * Anim.ease_of(clampf((t - t_tr) / 2.5, 0.0, 1.0), "smooth"))
		n.set_elev(SET_ELEV * Anim.ease_of(clampf((t - t_tr - 2.0) / 2.5, 0.0, 1.0), "smooth")))
	pose(a, ja + 0.2, 0.5, GC.kneel(8.0))
	pose(b, jb + 0.2, 0.5, GC.kneel(8.0))
	_phases = [[0.0, "Rocket lorry drives in"], [4.4, "Crew out"], [7.8, "Jacks down to the ground"],
		[t_tr, "Rack trained onto the line and raised"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		var at := n.global_position + Vector3(-0.3, 1.2, 0.8)
		cam.transform = Transform3D(Basis(), Vector3(7.0, 4.2, 8.0) + Vector3(0, 0, at.z * 0.6)).looking_at(at, Vector3.UP)
	return t_tr + 5.5


# ---------------------------------------------------------------- load

func _scene_load() -> float:
	var l := rlorry(Vector3.ZERO, 0.0, parked())
	l["engine"] = false
	var n: RocketLorry = l["node"]
	set_up(n, LOAD_ELEV, 12)
	n.ride(ground_h, 0.0)
	var box_xf := Transform3D(Basis(Vector3.UP, 0.3), RB.BOX_AT)
	var picked := {"n": 0}
	var times: Array = []
	var carr: Array = [_man(411, "loader"), _man(412, "gunner")]
	var loader := _man(413, "gunner")
	var nco := _man(414, "nco")
	nco["pos"] = Vector3(-3.5, 0, 1.5)
	nco["yaw"] = -PI * 0.6
	pose(nco, 0.0, 0.0, Rig.over(Body.body("stand"), C.carry("free")), null, null)
	for c: Dictionary in carr:
		c["pos"] = RB.BOX_AT + Vector3(0.9 if c == carr[0] else -0.2, 0, 0.9 if c == carr[0] else 1.2)
		c["yaw"] = PI * 0.75
		pose(c, 0.0, 0.0, C.standing("free"), null, null)
	loader["pos"] = Vector3(0.0, LB.FLOOR_Y, 2.2)
	loader["yaw"] = PI
	pose(loader, 0.0, 0.0, C.standing("free"), null, null)
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var carry_pose := Rig.over(Body.body("stand"), {"rifle": V.SLUNG, "hand_r": [-1, Vector3(0.24, 1.08, -0.32)],
		"hand_l": [-1, Vector3(-0.24, 1.08, -0.32)], "pole_r": Vector3(0.8, -0.3, 0.2), "pole_l": Vector3(-0.8, -0.3, 0.2)})
	var lift_pose := Rig.over(Body.body("stand"), {"rifle": V.SLUNG, "hand_r": [-1, Vector3(0.26, 1.62, -0.42)],
		"hand_l": [-1, Vector3(-0.26, 1.62, -0.42)], "pole_r": Vector3(0.8, -0.4, 0.2), "pole_l": Vector3(-0.8, -0.4, 0.2),
		"add": {B.SPINE: Vector3(4, 0, 0)}})
	var stoop_take := Rig.over(V.stooped(), {"hand_r": [-1, Vector3(0.26, 0.55, -0.45)], "hand_l": [-1, Vector3(-0.26, 0.55, -0.45)],
		"pole_r": Vector3(0.8, -0.3, 0.2), "pole_l": Vector3(-0.8, -0.3, 0.2)})
	var t := 0.8
	for k in 4:
		var c: Dictionary = carr[k % 2]
		var rail := 12 + k
		# Pick a rocket out of the box.
		var t_walk := move(c, t, RB.BOX_AT + Vector3(0.75, 0, 0.1), walk, -PI * 0.5 + 0.3)
		pose(c, t_walk, 0.45, GC.crouch(26.0))
		var t_pick := t_walk + 0.55
		pose(c, t_pick + 0.1, 0.45, carry_pose)
		var hand_spot := Vector3(-0.25 + 0.5 * (k % 2), 0, 3.55)
		var t_at := move(c, t_pick + 0.6, hand_spot, Body.gait(Body.WALK, carry_pose), PI)
		pose(c, t_at, 0.5, lift_pose)
		var t_take := t_at + 0.55
		# The loader on the bed stoops and takes it, turns, slides it onto its rail.
		var slot := n.rocket_xf(rail, -0.35).origin
		pose(loader, t_at - 0.4, 0.5, stoop_take, null, "prev", "smooth", Vector3(hand_spot.x * 0.6, LB.FLOOR_Y, 2.45), 0.0 + PI)
		pose(c, t_take + 0.3, 0.5, C.standing("free"))
		var stand_at := Vector3(slot.x, LB.FLOOR_Y, slot.z + 0.55)
		var t_rail := t_take + 1.0
		var rx := func(tt: float) -> Dictionary:
			var u := clampf((tt - t_rail) / 0.7, 0.0, 1.0)
			var x := n.rocket_xf(rail, lerpf(-0.35, RB.SEAT_Z, Anim.ease_of(u, "smooth")))
			return {"hand_r": x * Vector3(0.05, 0.02, -0.05), "hand_l": x * Vector3(-0.05, 0.02, -0.4)}
		shift(loader, t_take + 0.2, 0.75, Rig.over(Body.body("stand"), {"rifle": V.SLUNG, "pole_r": Vector3(0.8, -0.3, 0.2),
			"pole_l": Vector3(-0.8, -0.3, 0.2)}), stand_at, 0.0, rx, "smooth", 0.0)
		pose(loader, t_rail + 0.8, 0.5, C.standing("free"), null, "prev", "smooth", Vector3(0.0, LB.FLOOR_Y, 2.2), PI)
		times.append([t_pick, t_take, t_rail, t_rail + 0.7, c, rail])
		t = t_at + 0.6
	# The rockets being carried.
	for tm: Array in times:
		var c: Dictionary = tm[4]
		var rail: int = tm[5]
		var k := times.find(tm)
		var fn := func(tt: float) -> Transform3D:
			if tt < float(tm[0]) + 0.35:
				return box_xf * Transform3D(Basis(), Vector3(-0.35 + 0.14 * (5 - k), 0.1, RB.ROCKET_LEN * 0.5))
			if tt < float(tm[2]):
				var who: Dictionary = c if tt < float(tm[1]) else loader
				var pr := palm_world(who, B.HAND_R)
				var pl := palm_world(who, B.HAND_L)
				var mid := (pr + pl) * 0.5
				var ax := (pl - pr).normalized()
				if tt >= float(tm[1]):
					ax = -(n.rocket_xf(rail).basis.z).normalized()
				var bs := Basis.looking_at(ax, Vector3.UP)
				return Transform3D(bs, mid + bs.z * RB.ROCKET_LEN * 0.5)
			if tt < float(tm[3]):
				var u := clampf((tt - float(tm[2])) / 0.7, 0.0, 1.0)
				return n.rocket_xf(rail, lerpf(-0.35, RB.SEAT_Z, Anim.ease_of(u, "smooth")))
			return HIDE
		prop(rmesh, [at_world(fn, 0.0)])
	var box_mesh := func(tt: float) -> Variant:
		var gone := 0
		for tm: Array in times:
			if tt >= float(tm[0]):
				gone += 1
		var key := "box_%d" % gone
		if not cache.has(key):
			cache[key] = MG.mesh(RB.box(0, 6 - gone))
		return cache[key]
	prop(box_mesh.call(0.0), [at_world(box_xf, 0.0)], box_mesh)
	var t_done: float = times.back()[3]
	rparts.append(func(tt: float) -> void:
		var loaded := 12
		for tm: Array in times:
			if tt >= float(tm[3]):
				loaded += 1
		n.set_all_loaded(loaded)
		n.set_elev(lerpf(LOAD_ELEV, SET_ELEV, Anim.ease_of(clampf((tt - t_done - 0.8) / 2.5, 0.0, 1.0), "smooth"))))
	pose(nco, t_done + 0.5, 0.5, GC.nco_order(0.0))
	_phases = [[0.0, "Loading at a low angle: carried from the box, passed up, slid onto the rails"],
		[t_done + 0.8, "All 16 on: the rack goes up to firing angle"]]
	_camera = func(_t: float) -> void:
		cam.fov = 44.0
		cam.transform = Transform3D(Basis(), Vector3(-6.5, 4.6, 8.5)).looking_at(Vector3(-0.2, 1.4, 2.0), Vector3.UP)
	return t_done + 4.0


# ---------------------------------------------------------------- fire

func _scene_fire() -> float:
	lay_terrain(func(_x: float, _z: float) -> float: return 0.0, -160.0, 80.0, -320.0, 60.0, 10.0)
	var l := rlorry(Vector3.ZERO, 0.0, parked())
	l["engine"] = false
	var n: RocketLorry = l["node"]
	set_up(n)
	n.ride(ground_h, 0.0)
	# The crew in cover off to the side; the NCO gives the word, the firer at the box.
	var nco := _man(421, "nco")
	nco["pos"] = Vector3(-9.0, 0, 6.5)
	nco["yaw"] = -0.5
	pose(nco, 0.0, 0.0, GC.nco_order(0.0), null, null)
	pose(nco, 2.0, 0.25, GC.nco_order(1.0))
	pose(nco, 3.0, 0.6, GC.kneel(10.0))
	var firer := _man(422, "gunner")
	firer["pos"] = Vector3(-8.0, 0, 7.5)
	firer["yaw"] = -0.5
	prop(km(MG.ammo_box()), [at_world(Transform3D(Basis(Vector3.UP, -0.5), Vector3(-8.25, 0, 7.0)), 0.0)])
	pose(firer, 0.0, 0.0, GC.crouch(24.0), null, null)
	for s: Array in [[423, Vector3(-11.0, 0, 9.0), 0.4], [424, Vector3(-6.5, 0, 10.0), -0.2]]:
		var m := _man(s[0], "loader")
		m["pos"] = s[1]
		m["yaw"] = s[2]
		pose(m, 0.0, 0.0, GC.crouch(24.0), null, null)
	var t0 := 2.2
	var order := [15, 12, 3, 0, 14, 13, 2, 1, 11, 8, 7, 4, 10, 9, 6, 5]
	for k in 16:
		launch(n, order[k], t0 + 0.22 * k, 500 + k)
	var c := Vector3(-sin(SET_TRAIN), 0, -cos(SET_TRAIN)) * 230.0
	_phases = [[0.0, "Set up and loaded: the crew in cover"], [2.0, "Fire!"], [t0, "Ripple salvo: 16 rockets"],
		[7.0, "In flight"], [9.2, "Landing about 200-260 m out"]]
	_camera = func(t: float) -> void:
		var u1 := Anim.ease_of(clampf((t - 5.0) / 3.0, 0.0, 1.0), "smooth")
		var u2 := Anim.ease_of(clampf((t - 7.5) / 2.5, 0.0, 1.0), "smooth")
		var p0 := Vector3(13.0, 4.0, 9.0)
		var l0 := Vector3(-1.0, 2.5, -2.0)
		var p1 := Vector3(40.0, 40.0, 30.0)
		var l1 := c * 0.45 + Vector3(0, 25.0, 0)
		var p2 := c + Vector3(70.0, 35.0, 55.0)
		var l2 := c + Vector3(0, 4.0, 0)
		var pos := p0.lerp(p1, u1).lerp(p2, u2)
		var look := l0.lerp(l1, u1).lerp(l2, u2)
		cam.fov = lerpf(48.0, 40.0, u2)
		cam.transform = Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	return 17.0


# ---------------------------------------------------------------- pack up

func _scene_packup() -> float:
	var go := 15.0
	var tail := func(t: float) -> float: return 1.0 - Anim.ease_of(clampf((t - (go - 1.2)) / 0.6, 0.0, 1.0), "smooth")
	var l := rlorry(Vector3.ZERO, 0.0, go_from(go, 1.4, 4.5), tail)
	var n: RocketLorry = l["node"]
	set_up(n, SET_ELEV, 0)
	n.ride(ground_h, 0.0)
	l["engine"] = false
	rparts.append(func(t: float) -> void:
		l["engine"] = t > go - 1.5
		n.set_elev(SET_ELEV * (1.0 - Anim.ease_of(clampf((t - 1.0) / 2.5, 0.0, 1.0), "smooth")))
		n.set_train(SET_TRAIN * (1.0 - Anim.ease_of(clampf((t - 3.0) / 2.0, 0.0, 1.0), "smooth")))
		n.set_jacks(1.0 - Anim.ease_of(clampf((t - 5.5) / 2.2, 0.0, 1.0), "smooth")))
	var body := n.body
	# The driver on the bed at the handwheel, then down and round to the cab.
	var drv := crew_rider(431, "gunner", l, Vector3(-0.98, LB.FLOOR_Y, 1.15), -PI * 0.5)
	var wheel := func(tt: float) -> Dictionary:
		var w := tt * 5.0
		var c := n.turntable.global_transform * Vector3(-0.64, 0.28, 0.3)
		return {"hand_r": c + Vector3(0, 0.1 * sin(w), 0.1 * cos(w)), "hand_l": c + Vector3(0, -0.1 * sin(w), -0.1 * cos(w))}
	pose(drv, 0.0, 0.0, GC.heave(18.0, 10.0), wheel, null)
	shift(drv, 5.3, 0.6, V.stooped(), Vector3(0.3, LB.FLOOR_Y, 2.42), 0.0, null, "smooth", PI)
	pose(drv, 6.0, 0.22, V.crouch())
	shift(drv, 6.25, 0.32, V.airborne(), Vector3(0.75, 0, 3.45), 0.35, null, "lin", PI)
	pose(drv, 6.6, 0.15, V.crouch(1.0), null, "prev", "out")
	pose(drv, 6.8, 0.3, C.standing("free"))
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var t_dc := move(drv, move(drv, 7.1, Vector3(2.3, 0, 3.2), walk), Vector3(1.4, 0, -1.42), walk, -PI * 0.5)
	shift(drv, t_dc + 0.1, 0.5, V.crouch(), Vector3(0.85, 0.9, -1.42), 0.3, null, "smooth", 0.0)
	var hands := func(_t: float) -> Dictionary:
		var x := body.global_transform
		return {"hand_r": x * (LB.WHEEL_HUB + Vector3(0.17, 0.02, 0.03)), "hand_l": x * (LB.WHEEL_HUB + Vector3(-0.17, 0.02, 0.03))}
	shift(drv, t_dc + 0.65, 0.5, V.driver(), LB.DRIVER, 0.0, hands, "smooth", 0.0)
	# The NCO walks in and up into the cab.
	var nco := crew_rider(432, "nco", l, Vector3(-5.5, 0, -3.0), 0.3)
	pose(nco, 0.0, 0.0, GC.nco_order(0.0), null, null)
	pose(nco, 1.0, 0.4, Rig.over(Body.body("stand"), C.carry("free")))
	var t_nc := move(nco, 8.0, Vector3(-1.35, 0, -1.42), walk, PI * 0.5)
	shift(nco, t_nc + 0.1, 0.5, V.crouch(), Vector3(-0.8, 0.9, -1.42), 0.3, null, "smooth", 0.0)
	shift(nco, t_nc + 0.65, 0.5, V.seated(-10.0), Vector3(-0.45, 1.0, -1.42), 0.0, null, "smooth", 0.0)
	# The two crank the jacks up, then climb in over the tailgate to the seat.
	var edge_r := func(_t: float) -> Dictionary:
		return {"hand_r": body.global_transform * Vector3(0.6, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04),
			"hand_l": body.global_transform * Vector3(0.1, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04)}
	var men: Array = []
	for s: float in [-1.0, 1.0]:
		var m := crew_rider(433 + int(s > 0), "loader" if s < 0 else "gunner", l, Vector3(2.0 * s, 0, 4.5), PI)
		pose(m, 0.0, 0.0, GC.kneel(8.0), null, null)
		var top := RB.JACK_R * Vector3(s, 1, 1)
		var spot := Vector3(top.x + 0.55 * s, 0, top.z + 0.15)
		var t1 := move(m, 4.6 + (0.3 if s > 0 else 0.0), spot, walk, s * PI * 0.5)
		var crank := func(tt: float) -> Dictionary:
			var w := tt * 6.0
			var c := body.global_transform * (top + Vector3(0.12 * s, 0.17, 0) + Vector3(0.0, 0.07 * sin(w), 0.07 * cos(w)))
			return {"hand_r": c, "hand_l": c + Vector3(0, 0.02, 0.02)}
		pose(m, t1, 0.4, GC.kneel(22.0), crank)
		pose(m, 7.8, 0.4, C.standing("free"))
		var xq := 0.3 * s
		var t_q := move(m, 8.3 + (0.9 if s > 0 else 0.0), Vector3(xq, 0, 3.25), walk, 0.0)
		var edge := func(_t: float) -> Dictionary:
			return {"hand_r": body.global_transform * Vector3(xq + 0.24, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04),
				"hand_l": body.global_transform * Vector3(xq - 0.24, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04)}
		pose(m, t_q, 0.35, V.climb(0, LB.STEP.y, LB.FLOOR_Y), edge)
		shift(m, t_q + 0.4, 0.45, V.climb(1, LB.STEP.y, LB.FLOOR_Y), Vector3(xq, LB.STEP.y, 2.95), 0.0, edge)
		shift(m, t_q + 0.9, 0.45, V.climb(2, LB.STEP.y, LB.FLOOR_Y), Vector3(xq, LB.FLOOR_Y, 2.4), 0.0)
		shift(m, t_q + 1.4, 0.5, V.stooped(), Vector3(0.38 * s, LB.FLOOR_Y, 2.0), 0.0, null, "smooth", PI)
		shift(m, t_q + 2.0, 0.6, V.seated(10.0 * s, 3.0), Vector3(0.38 * s, LB.FLOOR_Y, LB.BED_REAR - 0.33), 0.0, null, "smooth", 0.0)
		men.append(m)
	_phases = [[0.0, "Pack up: rack down to travel"], [5.5, "Jacks up, crew aboard"], [go - 1.2, "Tailgate up, driving off"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		cam.transform = Transform3D(Basis(), Vector3(-9.5, 5.5, 9.5)).looking_at(Vector3(0.3, 1.2, 0.5), Vector3.UP)
	return go + 4.0


# ---------------------------------------------------------------- wreck

func _scene_wreck() -> float:
	var hit := 3.6
	var l := rlorry(Vector3.ZERO, 0.0, parked())
	l["engine"] = false
	var n: RocketLorry = l["node"]
	set_up(n, SET_ELEV, 16)
	n.ride(ground_h, 0.0)
	var wk := rlorry(Vector3.ZERO, 0.0, parked(), null, 0, true)
	var wn: RocketLorry = wk["node"]
	_wreck_pose(wn)
	wn.visible = false
	blast_at(1.6, Vector3(-9.0, 0, -12.0), 2, 71)
	blast_at(hit, Vector3(0.9, 0.3, 0.6), 1, 72)
	# Fire on the wreck: flames over the bed and the cab.
	var flames := [Vector3(0, 1.8, 0.8), Vector3(0.3, 1.6, -1.6), Vector3(-0.5, 1.5, 2.0), Vector3(0.6, 1.5, 1.6)]
	var fire := _wreck_fire(wn.body, flames, hit)
	# Cook-off: rockets left on the burning rack go off one by one, wild.
	var wild_t := [hit + 1.0, hit + 2.1, hit + 2.6, hit + 4.2, hit + 6.3]
	var wild_rails := [0, 2, 3, 6, 9]
	for k in wild_t.size():
		launch(wn, wild_rails[k], wild_t[k], 600 + k, true)
	# The crew near the lorry when the shell comes in: they duck at the near miss and run.
	var spots := [[441, "nco", Vector3(-4.5, 0, -1.5), Vector3(-14.0, 0, 6.0)], [442, "gunner", Vector3(-0.9, 0, 4.2), Vector3(-9.0, 0, 13.0)],
		[443, "loader", Vector3(2.4, 0, 3.4), Vector3(10.0, 0, 12.0)], [444, "gunner", Vector3(3.0, 0, -1.0), Vector3(13.0, 0, 3.0)]]
	for k in 4:
		var sp: Array = spots[k]
		var m := _man(sp[0], sp[1])
		m["pos"] = sp[2]
		m["yaw"] = 0.4 * k
		pose(m, 0.0, 0.0, C.standing("free"), null, null)
		pose(m, 1.7 + 0.08 * k, 0.25, GC.crouch(30.0))
		pose(m, 2.6, 0.4, C.standing("free"))
		pose(m, hit + 0.05, 0.2, GC.crouch(34.0))
		_run_off(m, hit + 0.4 + 0.15 * k, sp[3], false)
	_phases = [[0.0, "Set up and loaded"], [1.6, "Near miss: counter-battery fire"], [hit, "Hit"],
		[hit + 0.8, "Rockets cooking off as it burns: the crew run"], [hit + 8.5, "Burnt out: the wreck stays on the map"]]
	_camera = func(t: float) -> void:
		fire.call(t)
		var down := t >= hit + 0.05
		n.visible = not down
		wn.visible = down
		cam.fov = 48.0
		cam.transform = Transform3D(Basis(), Vector3(11.0, 5.5, 10.5)).looking_at(Vector3(-0.5, 1.4, 0.5), Vector3.UP)
	return hit + 11.5


## Flames, smoke and glow on a burning lorry body (like tank_clips.burn, without the shell flash: the Blast does that).
func _wreck_fire(body: Node3D, flames: Array, t0: float) -> Callable:
	var fire_mat := _mat("flame", Color(1.0, 0.55, 0.15), true)
	var core_mat := _mat("flame_core", Color(1.0, 0.86, 0.45), true)
	var nodes: Array = []
	for i in flames.size():
		for k in 3:
			var m := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.28 - 0.07 * k
			sp.height = (0.28 - 0.07 * k) * 2.6
			sp.radial_segments = 8
			sp.rings = 4
			sp.material = core_mat if k == 2 else fire_mat
			m.mesh = sp
			body.add_child(m)
			nodes.append({"m": m, "base": (flames[i] as Vector3) + Vector3(0, 0.2 * k, 0), "i": i, "k": k})
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 10.0
	body.add_child(light)
	light.position = Vector3(0, 2.6, 0.5)
	return func(t: float) -> void:
		var on := t >= t0 + 0.1
		light.visible = on
		for f: Dictionary in nodes:
			(f["m"] as MeshInstance3D).visible = on
		if not on:
			return
		var age := t - t0
		var strength := clampf(1.0 - (age - 8.0) / 3.0, 0.2, 1.0)
		var grow := clampf(age / 1.5, 0.2, 1.0)
		for f: Dictionary in nodes:
			var m: MeshInstance3D = f["m"]
			var i: int = f["i"]
			var fk := 0.75 + 0.25 * sin(t * (11.0 + i * 1.7) + f["k"] * 2.1) + 0.12 * sin(t * 23.0 + i)
			m.scale = Vector3(1.0, 1.4 + 0.5 * sin(t * 9.0 + i), 1.0) * fk * grow * strength
			m.position = f["base"] + Vector3(0, 0.12 * sin(t * 7.0 + i), 0)
		light.light_energy = (2.4 + 0.8 * sin(t * 17.0) + 0.5 * sin(t * 31.0)) * strength * grow
		if frame % (2 if strength > 0.6 else 5) == 0:
			var src: Vector3 = body.global_transform * (flames[frame % flames.size()] as Vector3)
			var c := Color(0.1, 0.09, 0.08) if strength > 0.6 else Color(0.3, 0.29, 0.28)
			puff(src + Vector3(0, 0.5, 0), Vector3(0.3, 1.5, 0.1), 0.45, c, 3.4, 1.0, (0.7 * strength + 0.15) * maxf(grow, 0.5), t)
