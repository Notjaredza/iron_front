extends "res://tools/cmd_clips.gd"
## The troop lorry, recorded as video frames (Question Chat, 2026-11-09).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/lorry_clips.gd -- [scene ...]
## Scenes: look, drive, board, dismount, wreck. Frames go to
## results/units/anim_frames/lorry_<scene>/, ffmpeg makes results/units/anim/lorry_<scene>.mp4.
## Men who ride are children of the lorry body, so their places are in the lorry's frame.

const LB := preload("res://scripts/vehicles/lorry_builder.gd")
const V := preload("res://scripts/units/anim/clips_vehicle.gd")
const LORRY_SCENES: Array[String] = ["look", "drive", "board", "dismount", "wreck"]

var lorries: Array = []  # {node, s_fn, curv_fn, tail_fn, pos, yaw, s, last_frame}
var mounds: Array = []  # [Vector3 centre, radius, height]
var smoke: Array = []  # {m, mat, t0, vel, grow, life, a0}
var last_frame := -1
var mats := {}


func _run() -> void:
	prefix = "lorry_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else LORRY_SCENES):
		await _record(sc)
	print("LORRY CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	lorries.clear()
	mounds.clear()
	smoke.clear()
	last_frame = -1


# ---------------------------------------------------------------- ground

func ground_h(p: Vector3) -> float:
	var h := 0.0
	for m: Array in mounds:
		var d := Vector2(p.x - (m[0] as Vector3).x, p.z - (m[0] as Vector3).z).length()
		var r: float = m[1]
		if d < r:
			h = maxf(h, float(m[2]) * sqrt(1.0 - (d / r) * (d / r)))
	return h


func mound(at: Vector3, r: float, hgt: float) -> void:
	mounds.append([at, r, hgt])
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.0
	sp.radial_segments = 14
	sp.rings = 6
	sp.material = _mat("mound", Color(0.58, 0.52, 0.39))
	mi.mesh = sp
	mi.scale = Vector3(1, hgt / r, 1)
	mi.position = at
	stage.add_child(mi)


func _mat(key: String, c: Color, unshaded := false, alpha := false) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[key] = m
	return m


# ---------------------------------------------------------------- lorries

## s_fn(t) -> distance driven; curv_fn(s) -> path curvature (1/m, + = left); tail_fn(t) -> 0..1.
func lorry(at: Vector3, yaw: float, s_fn: Callable, curv_fn: Variant = null, tail_fn: Variant = null, lod := 0, burnt := false) -> Dictionary:
	var n := Lorry.new().setup(lod, burnt)
	stage.add_child(n)
	n.position = at
	n.rotation.y = yaw
	var d := {"node": n, "s_fn": s_fn, "curv_fn": curv_fn, "tail_fn": tail_fn, "pos": at, "yaw": yaw, "s": 0.0, "run": true,
		"engine": not burnt}
	lorries.append(d)
	return d


static func go_from(t0: float, acc: float, vmax: float) -> Callable:
	return func(t: float) -> float:
		var tau := maxf(0.0, t - t0)
		var ta := vmax / acc
		if tau < ta:
			return 0.5 * acc * tau * tau
		return 0.5 * acc * ta * ta + vmax * (tau - ta)


## Arrives at total distance at t_stop, braking at dec from speed v.
static func arrive(t_stop: float, total: float, dec: float, v: float) -> Callable:
	return func(t: float) -> float:
		var tau := maxf(0.0, t_stop - t)
		var td := v / dec
		var rem := 0.5 * dec * tau * tau if tau < td else 0.5 * dec * td * td + v * (tau - td)
		return total - rem


func _update_lorries(t: float) -> void:
	var dt := 0.0 if last_frame < 0 else 1.0 / FPS
	for d: Dictionary in lorries:
		if not d["run"]:
			continue
		var n: Lorry = d["node"]
		var s1: float = (d["s_fn"] as Callable).call(t)
		var ds: float = s1 - float(d["s"])
		var curv := 0.0
		if d["curv_fn"] != null:
			curv = (d["curv_fn"] as Callable).call(s1)
		# Integrate along the path in small steps.
		var steps := maxi(1, int(ceil(absf(ds) / 0.1)))
		for k in steps:
			var step := ds / float(steps)
			var yw: float = d["yaw"]
			d["pos"] = (d["pos"] as Vector3) + Vector3(-sin(yw), 0, -cos(yw)) * step
			d["yaw"] = yw + curv * step
		d["s"] = s1
		n.position = d["pos"]
		n.rotation.y = d["yaw"]
		n.drive(s1, atan(curv * (LB.REAR_Z - LB.FRONT_Z)))
		n.ride(ground_h, dt)
		if d["tail_fn"] != null:
			n.set_tailgate((d["tail_fn"] as Callable).call(t))
		d["speed"] = ds / dt if dt > 0.0 else 0.0


func _eval_props(t: float) -> void:
	if frame != last_frame:
		_update_lorries(t)
		last_frame = frame
	super._eval_props(t)


## A man riding (or about to ride) a lorry: a child of its body, placed in the lorry's frame.
func rider(seed_value: int, role: String, l: Dictionary, pos: Vector3, yaw: float) -> Dictionary:
	var a := _man(seed_value, role)
	var s: Soldier = a["s"]
	stage.remove_child(s)
	(l["node"] as Lorry).body.add_child(s)
	a["pos"] = pos
	a["yaw"] = yaw
	return a


## A pose blend that also carries the man from where he was to a new place (on an arc).
func shift(a: Dictionary, t0: float, d: float, spec: Dictionary, to: Vector3, arc := 0.0, hands: Variant = null,
		ease := "smooth", yaw: Variant = null) -> void:
	var from: Vector3 = a["pos"]
	pose(a, t0, d, spec, hands, "prev", ease, to, yaw)
	var sg: Dictionary = a["segs"].back()
	sg["pos_from"] = from
	sg["arc"] = arc


func _eval_actor(a: Dictionary, t: float) -> void:
	super._eval_actor(a, t)
	var seg: Dictionary = a["segs"][0]
	for sg: Dictionary in a["segs"]:
		if float(sg["t0"]) <= t:
			seg = sg
	if seg.has("pos_from"):
		var d: float = seg["d"]
		var u := 1.0 if d <= 0.0 else clampf((t - float(seg["t0"])) / d, 0.0, 1.0)
		var e := Anim.ease_of(u, "lin" if float(seg["arc"]) != 0.0 else "smooth")
		var p: Vector3 = (seg["pos_from"] as Vector3).lerp(seg["pos"], e)
		p.y += float(seg["arc"]) * 4.0 * u * (1.0 - u)
		(a["s"] as Soldier).position = p


## The driver at the wheel.
func driver(l: Dictionary) -> Dictionary:
	var a := rider(41, "", l, LB.DRIVER, 0.0)
	var body: Node3D = (l["node"] as Lorry).body
	var hands := func(_t: float) -> Dictionary:
		var x := body.global_transform
		return {"hand_r": x * (LB.WHEEL_HUB + Vector3(0.17, 0.02, 0.03)), "hand_l": x * (LB.WHEEL_HUB + Vector3(-0.17, 0.02, 0.03))}
	pose(a, 0.0, 0.0, V.driver(), hands, null)
	return a


## The squad seated (seat i), their heads turning a little now and then.
func seat_squad(l: Dictionary, until := 30.0) -> Array:
	var men: Array = []
	var seats := Lorry.seats()
	for i in 12:
		var st: Dictionary = seats[i]
		var a := rider(101 + i, "", l, st["pos"], st["yaw"])
		pose(a, 0.0, 0.0, V.seated(0.0, 4.0 * (i % 3)), null, null)
		var k := 0
		var tk := 1.0 + 0.37 * i
		while tk < until:
			pose(a, tk, 0.6, V.seated([25.0, -20.0, 0.0, 35.0][(i + k) % 4], 4.0 * (i % 3)))
			tk += 2.3 + 0.4 * ((i + k) % 3)
			k += 1
		men.append(a)
	return men


# ---------------------------------------------------------------- effects

func puff(at: Vector3, vel: Vector3, radius: float, col: Color, life: float, grow: float, alpha: float, t: float) -> void:
	var m := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = radius
	sp.height = radius * 2.0
	sp.radial_segments = 8
	sp.rings = 4
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	sp.material = mat
	m.mesh = sp
	stage.add_child(m)
	m.global_position = at
	smoke.append({"m": m, "mat": mat, "t0": t, "vel": vel, "grow": grow, "life": life, "a0": alpha})


func _effects(t: float) -> void:
	super._effects(t)
	for d: Dictionary in lorries:
		var n: Lorry = d["node"]
		if not n.visible or not d["engine"]:
			continue
		var sp: float = d.get("speed", 0.0)
		# Exhaust: a puff every few frames, more when pulling.
		if frame % (3 if sp > 0.5 else 6) == 0:
			var ex := n.body.global_transform * LB.EXHAUST
			puff(ex, n.global_transform.basis * Vector3(-0.15, 0.25, 0.5), 0.07, Color(0.45, 0.45, 0.45), 1.3, 2.5, 0.35, t)
		# Dust off the rear wheels when moving.
		if sp > 1.0 and frame % 2 == 0:
			for s: float in [1.0, -1.0]:
				var wp := n.global_transform * Vector3(LB.REAR_X * s, 0.15, LB.REAR_Z + 0.4)
				puff(wp, Vector3(0.3 * s, 0.35, 0.0) + n.global_transform.basis * Vector3(0, 0, 0.6), 0.16,
					Color(0.72, 0.65, 0.5), 1.6, 3.0, 0.22, t)
	for pf: Dictionary in smoke.duplicate():
		var age := t - float(pf["t0"])
		var m: MeshInstance3D = pf["m"]
		if age > float(pf["life"]):
			m.queue_free()
			smoke.erase(pf)
			continue
		m.position += (pf["vel"] as Vector3) / FPS
		m.scale = Vector3.ONE * (1.0 + age * float(pf["grow"]))
		(pf["mat"] as StandardMaterial3D).albedo_color.a = float(pf["a0"]) * (1.0 - age / float(pf["life"]))


# ---------------------------------------------------------------- look

func _scene_look() -> float:
	var row := [[0, false, -7.5], [1, false, -2.5], [2, false, 2.5], [0, true, 7.5]]
	var info := []
	for r: Array in row:
		var tail := func(t: float) -> float: return clampf((t - 6.0) / 0.8, 0.0, 1.0) if not r[1] else 1.0
		var still := func(_t: float) -> float: return 0.0
		var l := lorry(Vector3(r[2], 0, 0), 0.0, still, null, tail, r[0], r[1])
		l["engine"] = false
		info.append("%s %d" % ["wreck" if r[1] else ["close", "mid", "far"][r[0]], (l["node"] as Lorry).tri_count()])
	_phases = [[0.0, "Troop lorry: close, mid, far looks and the wreck (triangles: " + ", ".join(info) + ")"],
		[6.0, "Tailgate down"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		for d: Dictionary in lorries:
			(d["node"] as Node3D).rotation.y = 0.6 + t * 0.32
		cam.transform = Transform3D(Basis(), Vector3(0.0, 7.0, -15.0)).looking_at(Vector3(0, 0.8, 0), Vector3.UP)
	return 11.0


# ---------------------------------------------------------------- drive

func _scene_drive() -> float:
	var v := 4.5
	var cruise := func(t: float) -> float: return v * t
	var l := lorry(Vector3.ZERO, 0.0, cruise)
	driver(l)
	seat_squad(l)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 14:
		var z := -6.0 - 4.2 * k
		mound(Vector3((0.85 if k % 2 == 0 else -0.85) + rng.randf_range(-0.15, 0.15), 0, z), rng.randf_range(0.7, 1.1),
			rng.randf_range(0.10, 0.2))
	_phases = [[0.0, "Driving loaded: 12 men on the benches, the body riding the bumps"]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		var p: Vector3 = (lorries[0]["node"] as Node3D).position
		var side := Vector3(6.4, 5.4, 3.6) if t < 6.0 else Vector3(-5.2, 3.6, -6.8)
		cam.transform = Transform3D(Basis(), p + side).looking_at(p + Vector3(0, 1.3, 0), Vector3.UP)
	return 12.0


# ---------------------------------------------------------------- board

func _scene_board() -> float:
	var go := 18.6
	var tail := func(t: float) -> float:
		if t < 0.3:
			return 0.0
		if t < 0.9:
			return Anim.ease_of((t - 0.3) / 0.6, "in")
		if t < 17.6:
			return 1.0
		return 1.0 - Anim.ease_of(clampf((t - 17.6) / 0.7, 0.0, 1.0), "smooth")
	var bend := func(s: float) -> float: return 0.035 if s > 8.0 else 0.0
	var l := lorry(Vector3.ZERO, 0.0, go_from(go, 1.4, 4.0), bend, tail)
	driver(l)
	var body: Node3D = (l["node"] as Lorry).body
	var seats := Lorry.seats()
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var crouch := Body.gait(C.CROUCH, C.carry("free"))
	for i in 12:
		var seat_i: int = (i / 2) + (0 if i % 2 == 0 else 6)
		var st: Dictionary = seats[seat_i]
		var xq := -0.25 if i % 2 == 0 else 0.25
		var start := Vector3(-1.6 + (i % 4) * 1.05, 0, 5.4 + (i / 4) * 1.1 + 0.2 * (i % 2))
		var a := rider(101 + i, "", l, start, 0.0)
		pose(a, 0.0, 0.0, C.standing("free"), null, null, "smooth", null, 0.0)
		var t_i := 1.2 + 1.15 * i
		var q := Vector3(xq, 0, 3.25)
		var walk_t := start.distance_to(q) / float(walk["speed"])
		move(a, maxf(0.05, t_i - walk_t), q, walk, 0.0)
		var edge := func(_t: float) -> Dictionary:
			var x := body.global_transform
			return {"hand_r": x * Vector3(xq + 0.24, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04),
				"hand_l": x * Vector3(xq - 0.24, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04)}
		pose(a, t_i, 0.35, V.climb(0, LB.STEP.y, LB.FLOOR_Y), edge)
		shift(a, t_i + 0.4, 0.45, V.climb(1, LB.STEP.y, LB.FLOOR_Y), Vector3(xq, LB.STEP.y, 2.95), 0.0, edge)
		shift(a, t_i + 0.9, 0.45, V.climb(2, LB.STEP.y, LB.FLOOR_Y), Vector3(xq, LB.FLOOR_Y, 2.4), 0.0)
		pose(a, t_i + 1.4, 0.35, V.stooped())
		var front := Vector3((st["pos"] as Vector3).x * 0.35, LB.FLOOR_Y, (st["pos"] as Vector3).z)
		a["pos"] = Vector3(xq, LB.FLOOR_Y, 2.4)
		var t_m := move(a, t_i + 1.75, front, crouch)
		shift(a, t_m, 0.5, V.seated(), st["pos"], 0.0, null, "smooth", st["yaw"])
		pose(a, t_m + 2.0, 0.6, V.seated(20.0 if i % 3 == 0 else -15.0))
	_phases = [[0.0, "Tailgate down: the squad climbs in"], [17.6, "Tailgate up"], [go, "Driving off"]]
	_camera = func(_t: float) -> void:
		cam.fov = 44.0
		cam.transform = Transform3D(Basis(), Vector3(6.2, 3.8, 8.6)).looking_at(Vector3(-0.2, 1.1, 1.0), Vector3.UP)
	return 24.0


# ---------------------------------------------------------------- dismount

func _scene_dismount() -> float:
	var stop_t := 4.6
	var tail := func(t: float) -> float: return Anim.ease_of(clampf((t - 5.0) / 0.6, 0.0, 1.0), "in")
	var l := lorry(Vector3(0, 0, 18.5), 0.0, arrive(stop_t, 18.5, 2.2, 5.5), null, tail)
	driver(l)
	for k in 3:
		mound(Vector3([0.85, -0.85, 0.9][k], 0, 13.0 - 3.6 * k), 0.9, 0.14)
	var men := seat_squad(l, 5.4)
	var seats := Lorry.seats()
	var crouch := Body.gait(C.CROUCH, C.carry("free"))
	var run := Body.gait(Body.RUN, R.carry("port"))
	for j in 12:
		var side := j % 2
		var k := 5 - j / 2
		var seat_i := k + (0 if side == 0 else 6)
		var a: Dictionary = men[seat_i]
		var st: Dictionary = seats[seat_i]
		var t_j := 5.7 + 0.72 * j
		var sp: Vector3 = st["pos"]
		var inner := Vector3(sp.x * 0.35, LB.FLOOR_Y, sp.z)
		shift(a, t_j, 0.4, V.stooped(), inner, 0.0, null, "smooth", PI)
		var xe := -0.3 if side == 0 else 0.3
		var t_e := move(a, t_j + 0.45, Vector3(xe, LB.FLOOR_Y, 2.42), crouch, PI)
		pose(a, t_e, 0.22, V.crouch())
		var land := Vector3(xe * 1.8, 0, 3.45)
		shift(a, t_e + 0.25, 0.32, V.airborne(), land, 0.35, null, "lin", PI)
		pose(a, t_e + 0.57, 0.12, V.crouch(1.0), null, "prev", "out")
		pose(a, t_e + 0.75, 0.3, run["keys"][0][1])
		var ang := lerpf(-1.25, 1.25, float(j) / 11.0) + (0.08 if side == 0 else -0.08)
		var spot := Vector3(sin(ang) * (6.5 + 1.5 * (j % 3)), 0, 3.4 + cos(ang) * (6.5 + 1.5 * (j % 3)))
		a["pos"] = land
		var t_r := move(a, t_e + 1.05, spot, run, atan2(-(spot.x), -(spot.z - 3.4)))
		pose(a, t_r, 0.45, R.poses()["kneel"])
	_phases = [[0.0, "Arriving"], [5.0, "Tailgate down: the squad jumps out"], [9.0, "Spreading out, down into cover"]]
	_camera = func(_t: float) -> void:
		cam.fov = 46.0
		cam.transform = Transform3D(Basis(), Vector3(12.0, 9.0, 15.0)).looking_at(Vector3(-1.0, 0.4, 4.0), Vector3.UP)
	return 19.0


# ---------------------------------------------------------------- wreck

func _scene_wreck() -> float:
	var hit := 4.0
	var l := lorry(Vector3(0, 0, 12.0), 0.0, arrive(3.2, 12.0, 2.5, 4.5))
	var still := func(_t: float) -> float: return 0.0
	var wk := lorry(Vector3.ZERO, 0.0, still, null, null, 0, true)
	wk["run"] = false
	wk["engine"] = false
	var wn: Lorry = wk["node"]
	wn.visible = false
	wn.body.transform = Transform3D(Basis(Vector3.BACK, 0.07) * Basis(Vector3.RIGHT, -0.03), Vector3(0, -0.1, 0))
	for w: Dictionary in wn.wheels:
		(w["node"] as Node3D).position.y = LB.WHEEL_R - 0.06
	var flames := [Vector3(0.0, 1.6, -1.7), Vector3(0.0, 1.5, -2.6), Vector3(-0.5, 1.4, -0.4), Vector3(0.5, 1.45, 0.9),
		Vector3(-0.3, 1.4, 2.0), Vector3(0.85, 0.5, 1.75), Vector3(-0.85, 0.5, 1.75)]
	var fire_mat := _mat("flame", Color(1.0, 0.55, 0.15), true)
	var core_mat := _mat("flame_core", Color(1.0, 0.86, 0.45), true)
	var fl_nodes: Array = []
	for i in flames.size():
		for k in 3:
			var m := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.22 - 0.05 * k
			sp.height = (0.22 - 0.05 * k) * 2.6
			sp.radial_segments = 8
			sp.rings = 4
			sp.material = core_mat if k == 2 else fire_mat
			m.mesh = sp
			wn.body.add_child(m)
			fl_nodes.append({"m": m, "base": flames[i] + Vector3(0, 0.18 * k, 0), "i": i, "k": k})
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 9.0
	wn.body.add_child(light)
	light.position = Vector3(0, 2.0, -0.5)
	var boom := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 1.0
	bs.height = 2.0
	bs.material = _mat("boom", Color(1.0, 0.85, 0.5), true)
	boom.mesh = bs
	stage.add_child(boom)
	boom.position = Vector3(0.8, 0.6, -0.2)
	boom.visible = false
	var fired := {"done": false}
	var fx := func(t: float) -> void:
		boom.visible = t >= hit and t < hit + 0.12
		boom.scale = Vector3.ONE * (1.0 + (t - hit) * 10.0) if boom.visible else Vector3.ONE
		if t >= hit and not fired["done"]:
			fired["done"] = true
			var rng := RandomNumberGenerator.new()
			rng.seed = 9
			for k in 22:
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.6, 1.6), rng.randf_range(-1, 1))
				puff(Vector3(0.9, 0.3, -0.2), dir * rng.randf_range(2.0, 4.0), 0.3, Color(0.36, 0.3, 0.22), 1.8, 1.6, 0.8, t)
			for k in 10:
				puff(Vector3(0.6, 0.8, -0.4) + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0, 1), rng.randf_range(-0.6, 0.6)),
					Vector3(0, 1.2, 0), 0.6, Color(0.12, 0.11, 0.1), 3.0, 1.2, 0.85, t)
		var burning := t >= hit + 0.05
		(lorries[0]["node"] as Node3D).visible = not burning
		lorries[0]["engine"] = not burning
		wn.visible = burning
		if not burning:
			return
		var age := t - hit
		var strength := clampf(1.0 - (age - 6.0) / 3.0, 0.25, 1.0)
		for f: Dictionary in fl_nodes:
			var m: MeshInstance3D = f["m"]
			var i: int = f["i"]
			var fk := 0.75 + 0.25 * sin(t * (11.0 + i * 1.7) + f["k"] * 2.1) + 0.12 * sin(t * 23.0 + i)
			var big := minf(1.0, age * 2.5) * strength * (1.0 if i < 5 else 0.7)
			m.scale = Vector3(1.0, 1.4 + 0.5 * sin(t * 9.0 + i), 1.0) * fk * big
			m.position = f["base"] + Vector3(0, 0.12 * sin(t * 7.0 + i), 0)
		light.light_energy = (2.2 + 0.8 * sin(t * 17.0) + 0.5 * sin(t * 31.0)) * strength
		if frame % (2 if strength > 0.6 else 5) == 0:
			var src: Vector3 = wn.body.global_transform * (flames[frame % 5] as Vector3)
			var c := Color(0.1, 0.09, 0.08) if strength > 0.6 else Color(0.3, 0.29, 0.28)
			puff(src + Vector3(0, 0.5, 0), Vector3(0.25, 1.4, 0.1), 0.35, c, 3.2, 1.0, 0.7 * strength + 0.15, t)
	_phases = [[0.0, "Empty lorry pulls up"], [hit, "Shell hit"], [hit + 0.4, "Burning"], [hit + 7.0, "Burnt out: the wreck stays on the map"]]
	_camera = func(t: float) -> void:
		fx.call(t)
		cam.fov = 46.0
		cam.transform = Transform3D(Basis(), Vector3(11.0, 5.2, 7.5)).looking_at(Vector3(0, 2.2, 0.0), Vector3.UP)
	return 14.0
