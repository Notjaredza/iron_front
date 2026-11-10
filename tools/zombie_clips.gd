extends "res://tools/troop_clips.gd"
## The zombies, recorded as video frames (Question Chat, 2026-11-10).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/zombie_clips.gd -- [scene ...]
## Scenes: look, moves, attacks, walls, trench, horde, deaths. Frames go to results/units/anim_frames/zombie_<scene>/,
## ffmpeg makes results/units/anim/zombie_<scene>.mp4.

const Z := preload("res://scripts/units/anim/clips_zombie.gd")
const ZB := preload("res://scripts/units/zombie_builder.gd")
const ZOMBIE_SCENES: Array[String] = ["look", "moves", "attacks", "walls", "trench", "horde", "deaths"]
const BLOOD := Color(0.30, 0.10, 0.08)
const EARTH := Color(0.50, 0.43, 0.31)
const PLANK := Color(0.40, 0.29, 0.18)
const STONE := Color(0.60, 0.58, 0.53)
const SAND := Color(0.62, 0.56, 0.40)

var ticks: Array = []  # Callable(t) every frame
var smoke_p: Puffs
var glow_p: Puffs
var bmats := {}


func _run() -> void:
	prefix = "zombie_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else ZOMBIE_SCENES):
		await _record(sc)
	print("ZOMBIE CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	ticks.clear()
	smoke_p = Puffs.make(false, 11)
	stage.add_child(smoke_p)
	glow_p = Puffs.make(true, 13)
	stage.add_child(glow_p)


func _effects(t: float) -> void:
	for f: Callable in ticks:
		f.call(t)
	super._effects(t)
	smoke_p.step(1.0 / FPS)
	glow_p.step(1.0 / FPS)


## Crawling cycles are not grounded by the walk player: put them on the ground here.
func _eval_actor(a: Dictionary, t: float) -> void:
	super._eval_actor(a, t)
	var seg: Dictionary = a["segs"][0]
	for sg: Dictionary in a["segs"]:
		if float(sg["t0"]) <= t:
			seg = sg
	if seg["type"] == "move" and (seg["gait"] as Dictionary).get("name", "") == "crawl":
		var s: Soldier = a["s"]
		var v: float = seg["gait"]["speed"]
		var dist := minf(t - float(seg["t0"]), float(seg["d"])) * v
		var g := Anim.sample(seg["gait"], dist / v + float(seg.get("phase", 0.0)))
		Rig.lift(g, Rig.ground_lift(g, s.geo))
		s.show_globals(g)


# ---------------------------------------------------------------- helpers

func zed(seed_value: int, kind: String, pos: Vector3, yaw := 0.0, lod := 0) -> Dictionary:
	var z := Zombie.new().setup(seed_value, lod, kind)
	stage.add_child(z)
	var a := {"s": z, "segs": [], "pos": pos, "yaw": yaw, "kind": kind}
	actors.append(a)
	pose(a, 0.0, 0.0, Z.stand(kind), null, null)
	return a


func zgait(a: Dictionary, style := "") -> Dictionary:
	return Z.gait_of(a["kind"], style)


static func seed_where(kind: String, key: String, val: bool, start: int) -> int:
	var s := start
	while bool(ZB.look_for_kind(s, kind).get(key, false)) != val:
		s += 1
	return s


func block(c: Vector3, h: Vector3, col: Color, b := Basis()) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = h * 2.0
	var key := col.to_html()
	if not bmats.has(key):
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.roughness = 0.95
		bmats[key] = mt
	bm.material = bmats[key]
	m.mesh = bm
	m.transform = Transform3D(b, c)
	stage.add_child(m)
	return m


## A hit: a dark spray off the bone, a little dust.
func hit_fx(a: Dictionary, bone: int, ts: float, sparks := false) -> void:
	later(ts, func(t: float) -> void:
		var p := bone_world(a, bone).origin + Vector3(0, 0.05 if bone != B.HEAD else 0.1, 0)
		if sparks:
			for k in 8:
				glow_p.add("spark", p, glow_p.jitter(3.0) + Vector3(0, 1.5, 0), 0.25)
		else:
			for k in 3:
				puff(p, Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(-0.4, 0.4)), 0.06, BLOOD, 0.8, 2.0, 0.7, t)
		puff(p, Vector3(0, 0.2, 0), 0.08, SAND, 0.9, 2.5, 0.35, t))


## Fire on a figure: flames off its bones, black smoke, the body charring.
func burn(a: Dictionary, t0: float, t1: float) -> void:
	var z: Zombie = a["s"]
	var bones: Array[int] = [B.CHEST, B.SPINE, B.HEAD, B.UARM_R, B.UARM_L, B.THIGH_R, B.THIGH_L, B.FARM_R]
	var last := [-1.0]
	ticks.append(func(t: float) -> void:
		if t < t0 or t > t1:
			return
		var fade := clampf((t1 - t) / 3.0, 0.0, 1.0)
		if frame % 2 == 0:
			for k in 2:
				var bn: int = bones[(frame + k * 3) % bones.size()]
				var p := bone_world(a, bn).origin
				glow_p.add("flame", p + glow_p.jitter(0.12), Vector3(0, 1.2, 0) + glow_p.jitter(0.3), 0.55 * maxf(fade, 0.3))
		if frame % 10 == 0:
			smoke_p.add("smoke", bone_world(a, B.CHEST).origin + Vector3(0, 0.4, 0), Vector3(0, 1.2, 0), 0.22)
		var u := clampf((t - t0) / 5.0, 0.0, 1.0)
		if absf(u - float(last[0])) > 0.08:
			last[0] = u
			z.set_burnt(u))
	var fl := func(t: float) -> Variant:
		if t < t0 or t > t1:
			return null
		return Transform3D(Basis().scaled(Vector3.ONE * (0.8 + 0.2 * sin(t * 23.0))), bone_world(a, B.CHEST).origin)
	glow(0.05, fl, 2.5)


## A rifleman on the fire step: aims, and fires at the given times (each shot plays the fire clip).
func rifleman(seed_value: int, pos: Vector3, yaw: float, times: Array) -> Dictionary:
	var a := troop(seed_value, "rifleman", pos, yaw)
	var p := R.poses()
	pose(a, 0.0, 0.0, p["aim"], null, null)
	var fire: Dictionary = R.library()["fire_stand"]
	for ts: float in times:
		clip(a, ts, fire)
	shots(a, Rig.MUZZLE, times, 0.06, false)
	return a


## Where a move from p0 at t0 at speed v toward p1 is at t (stops at p1).
static func along(p0: Vector3, p1: Vector3, v: float, t0: float, t: float) -> Vector3:
	var d := p1 - p0
	var L := d.length()
	if L < 0.001:
		return p1
	return p0 + d / L * clampf((t - t0) * v, 0.0, L)


# ---------------------------------------------------------------- look

func _scene_look() -> float:
	var picks: Array = [["shambler", seed_where("shambler", "gas_mask", true, 10)],
		["shambler", seed_where("shambler", "bare", false, 30)], ["shambler", seed_where("shambler", "bare", true, 50)],
		["runner", 61], ["runner", 77], ["brute", 90]]
	var xs: Array[float] = [-5.6, -3.4, -1.2, 1.0, 3.2, 5.8]
	var tris := {}
	for lod in 3:
		for i in picks.size():
			var kind: String = picks[i][0]
			var z0 := [0.0, -14.0, -40.0][lod] as float
			var a := zed(int(picks[i][1]), kind, Vector3(xs[i], 0, z0), PI, lod)
			# A slow sway in place: head rolling, shoulders shifting.
			var st := Z.stand(kind)
			var sw := Rig.over(st, {"add": {B.NECK: Vector3(-6, 10, -12), B.SPINE: Vector3(0, 6, -3), B.HEAD: Vector3(0, 8, -6)}})
			for k in 8:
				pose(a, 0.2 + 2.2 * k + 0.3 * i, 1.9, sw if k % 2 == 0 else st)
			var key := "%s%d" % [kind, lod]
			tris[key] = (a["s"] as Soldier).tri_count()
	var line := "close / mid / far tris: shambler %d/%d/%d, runner %d/%d/%d, brute %d/%d/%d" % [tris["shambler0"], tris["shambler1"],
		tris["shambler2"], tris["runner0"], tris["runner1"], tris["runner2"], tris["brute0"], tris["brute1"], tris["brute2"]]
	_phases = [[0.0, "Zombies: fallen soldiers back up. Shamblers (gas mask, helmet, bare), runners, the brute"],
		[5.5, line], [11.5, "Mid look (the game swaps at about 60 m)"], [15.0, "Far look"]]
	_camera = func(t: float) -> void:
		if t < 11.5:
			cam.fov = 40.0
			var x := lerpf(-6.5, 6.5, t / 11.5)
			cam.transform = Transform3D(Basis(), Vector3(x, 1.75, 4.6)).looking_at(Vector3(x * 0.85, 1.05, 0), Vector3.UP)
		elif t < 15.0:
			cam.fov = 40.0
			cam.transform = Transform3D(Basis(), Vector3(0, 3.0, -2.0)).looking_at(Vector3(0, 0.9, -14.0), Vector3.UP)
		else:
			cam.fov = 14.0
			cam.transform = Transform3D(Basis(), Vector3(0, 9.0, 12.0)).looking_at(Vector3(0, 0.9, -40.0), Vector3.UP)
	return 19.0


# ---------------------------------------------------------------- moves

func _scene_moves() -> float:
	var face_x := -PI * 0.5
	var sa := zed(seed_where("shambler", "bare", false, 30), "shambler", Vector3(-7, 0, 0), face_x)
	var t1 := move(sa, 0.5, Vector3(-1.5, 0, 0), zgait(sa), face_x)
	clip(sa, t1, Z.stumble(Z.stand("shambler")))
	move(sa, t1 + 1.0, Vector3(7, 0, 0), zgait(sa), face_x)
	var sb := zed(seed_where("shambler", "gas_mask", true, 10), "shambler", Vector3(-7, 0, -2.4), face_x)
	var t2 := move(sb, 0.2, Vector3(3.5, 0, -2.4), zgait(sb, "one"), face_x)
	pose(sb, t2, 1.4, Z.stand("shambler"), null, "prev", "smooth", null, PI * 0.5)
	move(sb, t2 + 1.5, Vector3(-3.0, 0, -2.4), zgait(sb, "one"), PI * 0.5)
	var br := zed(90, "brute", Vector3(-8, 0, -5.0), face_x)
	var t3 := move(br, 0.3, Vector3(2.0, 0, -5.0), zgait(br), face_x)
	move(br, t3, Vector3(16.0, 0, -5.0), zgait(br, "charge"), face_x)
	var cr := zed(seed_where("shambler", "bare", true, 50), "shambler", Vector3(-6.5, 0, 2.4), face_x)
	(cr["s"] as Zombie).set_legless(true)
	pose(cr, 0.0, 0.0, Z.lying(0.5), null, null)
	var crawl := Z.crawl()
	move(cr, 0.4, Vector3(5.0, 0, 2.4), crawl, face_x)
	var rn := zed(61, "runner", Vector3(-26, 0, -7.5), face_x)
	move(rn, 6.0, Vector3(30, 0, -7.5), zgait(rn), face_x)
	var rn2 := zed(77, "runner", Vector3(-6, 0, 4.6), face_x)
	move(rn2, 0.0, Vector3(-1.0, 0, 4.6), zgait(rn2, "walk"), face_x)
	move(rn2, 9.3, Vector3(36.0, 0, 4.6), zgait(rn2), face_x)
	_phases = [[0.0, "Moves: shambling (arms out, one arm dead), the brute's heavy walk, crawling on the arms"],
		[t1, "Shot: it staggers and keeps coming"], [6.0, "The runner's hunched sprint"], [t2, "Turning round"],
		[t3, "The brute's charge"], [9.3, "A runner breaks from a walk into a sprint"]]
	_camera = func(t: float) -> void:
		cam.fov = 50.0
		var x := clampf(lerpf(-4.0, 3.5, t / 20.0), -4.0, 3.5)
		cam.transform = Transform3D(Basis(), Vector3(x, 2.8, 10.5)).looking_at(Vector3(x, 0.7, -2.0), Vector3.UP)
	return 22.0


# ---------------------------------------------------------------- attacks

func _scene_attacks() -> float:
	var p := R.poses()
	var lib := R.library()
	# 1. A shambler grabs a sentry and bites.
	var x1 := -12.0
	var s1 := troop(301, "rifleman", Vector3(x1, 0, 0), 0.0)
	pose(s1, 0.0, 0.0, p["ready"], null, null)
	var z1 := zed(seed_where("shambler", "bare", false, 30), "shambler", Vector3(x1, 0, -3.4), PI)
	var ta := move(z1, 0.3, Vector3(x1, 0, -0.62), zgait(z1), PI)
	pose(s1, ta - 2.6, 0.5, p["aim"])
	clip(s1, ta - 1.6, lib["fire_stand"])
	shots(s1, Rig.MUZZLE, [ta - 1.6])
	hit_fx(z1, B.CHEST, ta - 1.55)
	clip(z1, ta, Z.grab_bite())
	var push := Rig.over(Body.body("stance"), {"rifle": {"mode": "hand", "rot": Vector3(-30, 0, 0)},
		"hand_l": [-1, Vector3(-0.2, 1.35, -0.42)], "add": {B.SPINE: Vector3(14, 0, 0), B.NECK: Vector3(20, 0, 0)}})
	pose(s1, ta + 0.25, 0.25, push)
	clip(s1, ta + 1.9, lib["death_back"])
	hit_fx(s1, B.NECK, ta + 0.85)
	hit_fx(s1, B.NECK, ta + 1.45)
	# 2. A runner sprints in and leaps on a rifleman.
	var x2 := 0.0
	var s2 := troop(302, "rifleman", Vector3(x2, 0, 0), 0.0)
	pose(s2, 0.0, 0.0, p["ready"], null, null)
	var r2 := zed(61, "runner", Vector3(x2, 0, -24), PI)
	pose(r2, 0.0, 0.0, Z.stand("runner"), null, null)
	var tb := move(r2, 8.6, Vector3(x2, 0, -4.4), zgait(r2), PI)
	pose(s2, tb - 2.0, 0.4, p["aim"])
	clip(s2, tb - 1.5, lib["fire_stand"])
	shots(s2, Rig.MUZZLE, [tb - 1.5])
	pose(r2, tb, 0.2, Z.leap_pose("crouch"))
	shift(r2, tb + 0.2, 0.5, Z.leap_pose("fly"), Vector3(x2, 0, -0.9), 0.9, null, "smooth", PI)
	clip(s2, tb + 0.62, lib["death_back"])
	shift(r2, tb + 0.7, 0.35, Z.leap_pose("land"), Vector3(x2, 0, 0.1), 0.0, null, "smooth", PI)
	clip(r2, tb + 1.2, Z.claw_swipe())
	clip(r2, tb + 2.8, Z.claw_swipe())
	# 3. The brute charges a rifleman, takes his shots and clubs him down.
	var x3 := 12.0
	var s3 := troop(303, "rifleman", Vector3(x3, 0, 0), 0.0)
	pose(s3, 0.0, 0.0, p["aim"], null, null)
	var b3 := zed(90, "brute", Vector3(x3, 0, -15), PI)
	var tc := move(b3, 16.8, Vector3(x3, 0, -1.7), zgait(b3, "charge"), PI)
	for ts: float in [tc - 3.0, tc - 1.5]:
		clip(s3, ts, lib["fire_stand"])
		hit_fx(b3, B.CHEST, ts + 0.05, true)
	shots(s3, Rig.MUZZLE, [tc - 3.0, tc - 1.5])
	clip(b3, tc, Z.smash(2))
	clip(s3, tc + 0.78, lib["death_forward"])
	later(tc + 1.95, func(t: float) -> void:
		for k in 6:
			puff(Vector3(x3, 0.1, -0.2), Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1)), 0.12, SAND, 1.4, 2.6, 0.5, t))
	_phases = [[0.0, "Attacks: a shambler takes a hit, grabs the sentry and bites"], [8.6, "A runner: sprint, crouch, leap"],
		[tb + 1.2, "Claws"], [16.8, "The brute charges: bullets spark off its plates"], [tc, "Club"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		var x := x1 if t < 8.6 else (x2 if t < 16.8 else x3)
		cam.transform = Transform3D(Basis(), Vector3(x + 5.5, 2.4, 3.8)).looking_at(Vector3(x, 1.0, -1.6), Vector3.UP)
	return tc + 4.0


# ---------------------------------------------------------------- walls and gate

func _scene_walls() -> float:
	var H := 2.4
	block(Vector3(-4.0, H * 0.5, 0), Vector3(6.0, H * 0.5, 0.25), STONE)
	block(Vector3(8.5, H * 0.5, 0), Vector3(3.5, H * 0.5, 0.25), STONE)
	for x: float in [2.0, 5.0]:
		block(Vector3(x, 1.4, 0), Vector3(0.32, 1.4, 0.32), STONE.darkened(0.12))
	for k in 18:
		block(Vector3(-9.6 + 0.65 * k, H + 0.05, 0), Vector3(0.3, 0.05, 0.28), STONE.darkened(0.08))
	# The gate: two leaves hung on the pillars, opening inward (+Z).
	var leaves: Array = []
	for s: float in [1.0, -1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(2.3 if s > 0.0 else 4.7, 0, 0)
		stage.add_child(hinge)
		for k in 5:
			var pl := block(Vector3(s * (0.15 + 0.28 * k), 1.1, 0), Vector3(0.13, 1.05, 0.05), PLANK.darkened(0.05 * (k % 2)))
			pl.reparent(hinge, false)
		for y: float in [0.5, 1.7]:
			var br := block(Vector3(s * 0.6, y, 0.07), Vector3(0.62, 0.07, 0.03), PLANK.darkened(0.2))
			br.reparent(hinge, false)
		leaves.append([hinge, s])
	# The pile against the wall: three shamblers hunched at the foot, the others climb their backs.
	var heap_x: Array[float] = [-5.2, -4.4, -3.6]
	var heapers: Array = []
	for i in 3:
		var hx: float = heap_x[i]
		var a := zed(seed_where("shambler", "bare", i % 2 == 0, 30 + 7 * i), "shambler", Vector3(hx, 0, -2.3 - 0.5 * float(i)), PI)
		var ta := move(a, 0.0, Vector3(hx, 0, -0.87), zgait(a), PI)
		pose(a, ta, 0.6, Z.heap())
		heapers.append(a)
	var climbers := [[61, "runner", -4.4, 4.2], [77, "runner", -3.6, 6.0], [seed_where("shambler", "gas_mask", true, 10), "shambler", -5.2, 8.2]]
	for c: Array in climbers:
		var cx: float = c[2]
		var tc: float = c[3]
		var g := Z.gait_of(String(c[1]))
		var v0: float = g["speed"]
		var a := zed(int(c[0]), String(c[1]), Vector3(cx, 0, -2.2 - v0 * (tc - 0.2)), PI)
		move(a, 0.2, Vector3(cx, 0, -2.2), g, PI)
		var top := func(_t: float) -> Dictionary:
			return {"hand_r": Vector3(cx + 0.22, H + 0.02, -0.18), "hand_l": Vector3(cx - 0.22, H + 0.02, -0.18)}
		shift(a, tc, 0.45, Z.stand(c[1]), Vector3(cx, 0.78, -1.15), 0.45, null, "smooth", PI)
		shift(a, tc + 0.5, 0.5, Z.wall_climb(true), Vector3(cx, 0.65, -0.62), 0.0, top, "smooth", PI)
		shift(a, tc + 1.05, 0.5, Z.wall_climb(false), Vector3(cx, 0.95, -0.55), 0.0, top, "smooth", PI)
		shift(a, tc + 1.6, 0.6, Z.over_top(), Vector3(cx, 1.55, -0.05), 0.0, null, "smooth", PI)
		shift(a, tc + 2.4, 0.55, Z.leap_pose("land"), Vector3(cx, 0, 1.0), 0.4, null, "in", PI)
		pose(a, tc + 3.0, 0.4, Z.stand(c[1]))
		move(a, tc + 3.4, Vector3(cx + 1.0, 0, 9.0), zgait(a), PI)
	# Two shamblers claw at the gate; the brute comes up and smashes it in.
	var gate_men: Array = []
	for i in 2:
		var gx: float = [2.9, 4.1][i]
		var a := zed(seed_where("shambler", "bare", i == 0, 70 + i), "shambler", Vector3(gx, 0, -4.5), PI)
		var ta := move(a, 0.0, Vector3(gx, 0, -0.78), zgait(a), PI)
		var claws := func(t: float) -> Dictionary:
			var ph := t * 3.1 + float(i)
			return {"hand_r": Vector3(gx + 0.2, 1.45 + 0.25 * sin(ph), -0.14), "hand_l": Vector3(gx - 0.2, 1.45 + 0.25 * sin(ph + PI), -0.14)}
		pose(a, ta, 0.5, Z.claw_at(), claws)
		gate_men.append([a, ta, gx])
	var br := zed(90, "brute", Vector3(3.5, 0, -12.0), PI)
	var tbr := move(br, 2.0, Vector3(3.5, 0, -2.05), zgait(br), PI)
	for gm: Array in gate_men:
		var a: Dictionary = gm[0]
		var gx: float = gm[2]
		pose(a, tbr - 1.6, 0.4, Z.stand("shambler"))
		move(a, tbr - 1.2, Vector3(gx + (-1.4 if gx < 3.5 else 1.4), 0, -1.4), zgait(a), PI)
	clip(br, tbr, Z.smash(2))
	var hit1 := tbr + 0.8
	var hit2 := tbr + 1.95
	for hx: float in [hit1, hit2]:
		later(hx, func(t: float) -> void:
			for k in 8:
				puff(Vector3(3.5 + randf_range(-0.8, 0.8), randf_range(0.5, 1.8), -0.15), Vector3(randf_range(-1, 1), 0.5, -0.8), 0.1,
					SAND, 1.2, 2.4, 0.5, t))
	updates_gate(leaves, hit1, hit2)
	# Splinters off the broken gate.
	for k in 7:
		var dir := Vector3(randf_range(-1.6, 1.6), randf_range(2.0, 4.0), randf_range(1.5, 4.0))
		var sp := Vector3(3.5 + randf_range(-0.8, 0.8), randf_range(0.6, 1.8), 0)
		var spin := randf_range(4, 10)
		var fly := func(t: float) -> Transform3D:
			if t < hit2:
				return HIDE
			var u := t - hit2
			var q := sp + dir * u + Vector3(0, -4.9 * u * u, 0)
			if q.y < 0.05:
				var tl := (dir.y + sqrt(dir.y * dir.y + 19.6 * sp.y)) / 9.8
				q = sp + dir * tl + Vector3(0, -4.9 * tl * tl, 0)
				q.y = 0.05
				return Transform3D(Basis(Vector3.UP, spin), q)
			return Transform3D(Basis(Vector3(1, 0.3, 0).normalized(), u * spin), q)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.04, randf_range(0.4, 0.9))
		bm.material = bmats[PLANK.to_html()]
		mi.mesh = bm
		stage.add_child(mi)
		props.append({"node": mi, "keys": [at_world(fly, 0.0)], "mesh_fn": null})
	move(br, tbr + 2.6, Vector3(3.5, 0, 7.0), zgait(br), PI)
	var i2 := 0
	for gm: Array in gate_men:
		var a: Dictionary = gm[0]
		move(a, tbr + 3.4 + 0.6 * i2, Vector3(3.0 + i2, 0, 8.0), zgait(a), PI)
		i2 += 1
	_phases = [[0.0, "Walls: the first ones pile up against the wall, the rest climb their backs"],
		[4.2, "Up the pile, over the top, down inside"], [tbr - 1.6, "At the gate the brute comes up"],
		[hit2, "The gate gives way"]]
	_camera = func(t: float) -> void:
		cam.fov = 48.0
		if t < 8.0:
			cam.transform = Transform3D(Basis(), Vector3(-0.5, 4.2, -9.5)).looking_at(Vector3(-3.0, 1.2, 0), Vector3.UP)
		elif t < tbr - 2.0:
			cam.transform = Transform3D(Basis(), Vector3(-1.0, 3.4, 7.5)).looking_at(Vector3(-3.8, 1.4, 0), Vector3.UP)
		elif t < tbr + 4.0:
			cam.transform = Transform3D(Basis(), Vector3(8.0, 3.0, -6.5)).looking_at(Vector3(3.5, 1.2, -0.5), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(6.0, 3.6, 10.0)).looking_at(Vector3(3.5, 1.0, 1.0), Vector3.UP)
	return tbr + 8.0


## The gate leaves: shudder on the first blow, burst inward on the second.
func updates_gate(leaves: Array, hit1: float, hit2: float) -> void:
	ticks.append(func(t: float) -> void:
		for lv: Array in leaves:
			var n: Node3D = lv[0]
			var s: float = lv[1]
			var ang := 0.0
			var u1 := t - hit1
			if u1 > 0.0 and u1 < 0.6:
				ang = 0.06 * sin(u1 * 40.0) * exp(-u1 * 6.0)
			var u2 := t - hit2
			if u2 > 0.0:
				var target := 1.7 if s > 0.0 else 1.3
				ang = target * (1.0 - exp(-u2 * 9.0)) + 0.05 * sin(u2 * 18.0) * exp(-u2 * 3.0)
			n.rotation.y = -ang * s)


# ---------------------------------------------------------------- trench and wire

func _scene_trench() -> float:
	var TOP := 1.8
	block(Vector3(0, TOP * 0.5, -21.0), Vector3(30, TOP * 0.5, 20), EARTH)
	block(Vector3(0, TOP * 0.5, 21.0), Vector3(30, TOP * 0.5, 20), EARTH)
	block(Vector3(0, 0.01, 0), Vector3(30, 0.01, 1.0), EARTH.darkened(0.25))
	for s: float in [1.0, -1.0]:
		for k in 30:
			block(Vector3(-14.5 + k, 0.85, s * 0.98), Vector3(0.48, 0.85, 0.03), PLANK.darkened(0.08 * (k % 3)))
	for k in 12:
		block(Vector3(-11 + 2.0 * k, 0.04, 0), Vector3(0.07, 0.04, 0.95), PLANK.darkened(0.2))
	# The wire belt: posts and three strands, crossed. The brute's stretch tears.
	var posts: Array[float] = []
	for k in 8:
		var px := -7.0 + 2.0 * k
		posts.append(px)
		block(Vector3(px, TOP + 0.55, -7.0), Vector3(0.04, 0.55, 0.04), PLANK.darkened(0.3))
	var tear_t := [99.0]
	for k in posts.size() - 1:
		var xa: float = posts[k]
		var xb: float = posts[k + 1]
		var torn := xa < 4.5 and xb > 4.5
		for h: float in [0.35, 0.7, 1.0]:
			wire(func(t: float) -> PackedVector3Array:
				var a := Vector3(xa, TOP + h, -7.0)
				var b := Vector3(xb, TOP + h, -7.0)
				if torn and t > float(tear_t[0]):
					var u := minf((t - float(tear_t[0])) / 0.6, 1.0)
					var mid := (a + b) * 0.5
					return PackedVector3Array([a, a.lerp(mid, 0.6) + Vector3(0, -h * u, 0.2 * u)])
				var m := (a + b) * 0.5 + Vector3(0, -0.08, 0)
				return PackedVector3Array([a, m, b]))
			if torn:
				wire(func(t: float) -> PackedVector3Array:
					if t <= float(tear_t[0]):
						return PackedVector3Array()
					var u := minf((t - float(tear_t[0])) / 0.6, 1.0)
					var a := Vector3(xa, TOP + h, -7.0)
					var b := Vector3(xb, TOP + h, -7.0)
					return PackedVector3Array([b, b.lerp((a + b) * 0.5, 0.6) + Vector3(0, -h * u, 0.2 * u)]))
	# A: a shambler caught on the wire, gets loose, falls in, gets up and claws out the far side.
	var ax := -2.0
	var A := zed(seed_where("shambler", "bare", false, 30), "shambler", Vector3(ax, TOP, -9.5), PI)
	var t1 := move(A, 0.0, Vector3(ax, TOP, -7.45), zgait(A), PI)
	var caught := func(t: float) -> Dictionary:
		var ph := t * 5.0
		return {"hand_r": Vector3(ax + 0.35, TOP + 0.7 + 0.12 * sin(ph), -7.05), "hand_l": Vector3(ax - 0.3, TOP + 0.95 + 0.12 * sin(ph + 2.0), -7.05)}
	pose(A, t1, 0.4, Rig.over(Z.claw_at(), {"add": {B.SPINE: Vector3(-10, 0, 0)}}), caught)
	pose(A, t1 + 1.5, 0.5, Rig.over(Z.claw_at(), {"add": {B.SPINE: Vector3(6, -30, 0), B.HIPS: Vector3(0, 20, 0)}}), caught)
	pose(A, t1 + 2.6, 0.5, Rig.over(Z.claw_at(), {"add": {B.SPINE: Vector3(-14, 25, 0)}}), caught)
	pose(A, t1 + 3.6, 0.4, Z.stand("shambler"))
	var t2 := move(A, t1 + 4.0, Vector3(ax, TOP, -1.25), zgait(A), PI)
	var fallen := Rig.over(Z.lying(0.3), {"root_rot": Vector3(-86, 0, 10)})
	shift(A, t2, 0.55, Rig.over(Z.leap_pose("fly"), {"root_rot": Vector3(-40, 0, 10)}), Vector3(ax, 0.3, -0.75), 0.15, null, "in", PI)
	shift(A, t2 + 0.55, 0.25, fallen, Vector3(ax, 0.0, -0.3), 0.0, null, "out", PI)
	pose(A, t2 + 1.6, 0.6, Z.leap_pose("land"))
	pose(A, t2 + 2.4, 0.6, Z.stand("shambler"))
	var t3 := move(A, t2 + 3.0, Vector3(ax, 0, 0.42), zgait(A), PI)
	var edge := func(_t: float) -> Dictionary:
		return {"hand_r": Vector3(ax + 0.24, TOP + 0.03, 1.12), "hand_l": Vector3(ax - 0.24, TOP + 0.03, 1.12)}
	pose(A, t3, 0.5, Z.wall_climb(true), edge)
	shift(A, t3 + 0.6, 0.8, Z.wall_climb(false), Vector3(ax, 0.35, 0.42), 0.0, edge, "smooth", PI)
	shift(A, t3 + 1.5, 0.8, Z.wall_climb(true), Vector3(ax, 0.75, 0.5), 0.0, edge, "smooth", PI)
	shift(A, t3 + 2.4, 0.7, Z.over_top(), Vector3(ax, TOP - 0.25, 1.15), 0.0, null, "smooth", PI)
	shift(A, t3 + 3.3, 0.8, Z.leap_pose("land"), Vector3(ax, TOP, 1.7), 0.0, null, "smooth", PI)
	pose(A, t3 + 4.2, 0.6, Z.stand("shambler"))
	move(A, t3 + 4.8, Vector3(ax, TOP, 6.0), zgait(A), PI)
	# B: another falls in further along and is stuck, clawing at the far wall.
	var bx := -5.5
	var Bz := zed(seed_where("shambler", "gas_mask", true, 10), "shambler", Vector3(bx, TOP, -5.5), PI)
	var tb := move(Bz, 3.0, Vector3(bx, TOP, -1.25), zgait(Bz, "one"), PI)
	shift(Bz, tb, 0.55, Rig.over(Z.leap_pose("fly"), {"root_rot": Vector3(-35, 0, -8)}), Vector3(bx, 0.2, -0.6), 0.1, null, "in", PI)
	shift(Bz, tb + 0.55, 0.3, Z.leap_pose("land"), Vector3(bx, 0, 0.1), 0.0, null, "out", PI)
	var wallp := func(t: float) -> Dictionary:
		var ph := t * 2.6
		return {"hand_r": Vector3(bx + 0.22, 1.25 + 0.35 * sin(ph), 0.95), "hand_l": Vector3(bx - 0.22, 1.25 + 0.35 * sin(ph + PI), 0.95)}
	pose(Bz, tb + 1.4, 0.6, Z.claw_at(), wallp, "prev", "smooth", Vector3(bx, 0, 0.45), PI)
	# The runner jumps the wire and the trench in its stride.
	var rx := 1.5
	var Rn := zed(61, "runner", Vector3(rx, TOP, -30.0), PI)
	var tr := move(Rn, 6.0, Vector3(rx, TOP, -9.0), zgait(Rn), PI)
	shift(Rn, tr, 0.5, Z.leap_pose("fly"), Vector3(rx, TOP, -5.2), 1.1, null, "smooth", PI)
	shift(Rn, tr + 0.5, 0.15, Z.leap_pose("land"), Vector3(rx, TOP, -4.8), 0.0, null, "smooth", PI)
	var tr2 := move(Rn, tr + 0.65, Vector3(rx, TOP, -1.6), zgait(Rn), PI)
	shift(Rn, tr2, 0.55, Z.leap_pose("fly"), Vector3(rx, TOP, 1.9), 1.0, null, "smooth", PI)
	shift(Rn, tr2 + 0.55, 0.2, Z.leap_pose("land"), Vector3(rx, TOP, 2.4), 0.0, null, "smooth", PI)
	move(Rn, tr2 + 0.75, Vector3(rx, TOP, 30.0), zgait(Rn), PI)
	# The brute walks through the wire, down into the trench and up the far side.
	var gx := 4.5
	var Br := zed(90, "brute", Vector3(gx, TOP, -14.0), PI)
	var tg := move(Br, 0.5, Vector3(gx, TOP, -7.0), zgait(Br), PI)
	tear_t[0] = tg - 0.2
	later(tg - 0.2, func(t: float) -> void:
		for k in 5:
			glow_p.add("spark", Vector3(gx, TOP + 0.7, -7.0), glow_p.jitter(2.5) + Vector3(0, 1.0, 0), 0.2))
	var tg2 := move(Br, tg, Vector3(gx, TOP, -1.55), zgait(Br), PI)
	var crouch := Rig.over(Body.body("kneel"), Rig.over(Z.carry("club"), {"add": {B.SPINE: Vector3(-20, 0, 0)}}))
	shift(Br, tg2, 0.9, crouch, Vector3(gx, 0, -0.45), 0.1, null, "smooth", PI)
	pose(Br, tg2 + 1.0, 0.5, Z.stand("brute"))
	var tg3 := move(Br, tg2 + 1.5, Vector3(gx, 0, 0.3), zgait(Br), PI)
	var bedge := func(_t: float) -> Dictionary:
		return {"hand_r": Vector3(gx + 0.3, TOP + 0.03, 1.15), "hand_l": Vector3(gx - 0.3, TOP + 0.03, 1.15)}
	shift(Br, tg3, 0.9, Rig.over(Z.wall_climb(true), {"rifle": {"mode": "back"}}), Vector3(gx, 0.3, 0.35), 0.0, bedge, "smooth", PI)
	shift(Br, tg3 + 1.0, 0.9, Rig.over(Z.over_top(), {"rifle": {"mode": "back"}}), Vector3(gx, TOP - 0.45, 1.2), 0.0, null, "smooth", PI)
	shift(Br, tg3 + 2.0, 0.8, Z.stand("brute"), Vector3(gx, TOP, 1.9), 0.0, null, "smooth", PI)
	move(Br, tg3 + 2.9, Vector3(gx, TOP, 8.0), zgait(Br), PI)
	_phases = [[0.0, "Trench and wire: a shambler is caught on the wire"], [6.0, "The runner jumps the wire and the trench"],
		[tg - 0.4, "The brute walks through the wire and tears it"], [t2, "Into the trench"],
		[tg2, "The brute steps down and climbs out"], [t3, "Clawing up the far side; another is stuck at the wall"]]
	_camera = func(t: float) -> void:
		cam.fov = 50.0
		if t < 11.0:
			cam.transform = Transform3D(Basis(), Vector3(10.5, 6.5, -14.5)).looking_at(Vector3(0.5, TOP, -5.5), Vector3.UP)
		elif t < t3:
			cam.transform = Transform3D(Basis(), Vector3(8.5, 4.4, 4.5)).looking_at(Vector3(0.0, 0.8, -0.5), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(-9.0, 3.8, -4.5)).looking_at(Vector3(-2.5, 1.1, 0.6), Vector3.UP)
	return t3 + 6.5


# ---------------------------------------------------------------- horde vs our line

func _scene_horde() -> float:
	var TOP := 1.5
	block(Vector3(0, TOP * 0.5, -30.0), Vector3(40, TOP * 0.5, 30), EARTH)
	block(Vector3(0, TOP * 0.5, 22.0), Vector3(40, TOP * 0.5, 20), EARTH)
	block(Vector3(0, 0.01, 1.0), Vector3(40, 0.01, 1.0), EARTH.darkened(0.25))
	block(Vector3(0, 0.15, 0.3), Vector3(40, 0.15, 0.3), EARTH.darkened(0.1))  # the fire step
	for k in 40:
		block(Vector3(-10.0 + 0.5 * k, TOP + 0.12 + 0.11 * (k % 2), -0.3), Vector3(0.24, 0.1, 0.18), SAND.darkened(0.1 * (k % 3)))
	# Our line: five rifles on the fire step, the officer behind with his pistol.
	var xs: Array[float] = [-4.0, -2.0, 0.0, 2.0, 4.0]
	var pool: Array = []  # [time, rifleman index]
	for i in xs.size():
		var t := 2.5 + 0.33 * i
		while t < 30.0:
			pool.append([t, i])
			t += 1.65
	pool.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var used := {}
	var times: Array = [[], [], [], [], []]
	var take := func(after: float, x: float) -> Array:
		var best: Array = []
		var bd := 1e9
		for p: Array in pool:
			if used.has(p) or float(p[0]) < after:
				continue
			var d := float(p[0]) - after + absf(xs[int(p[1])] - x) * 0.25
			if d < bd:
				bd = d
				best = p
		if best.is_empty():
			return [after + 0.5, 0]
		used[best] = true
		(times[int(best[1])] as Array).append(float(best[0]))
		return best
	# The horde: shamblers spread out coming on, runners later, the brute in the middle.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var edge := -0.85
	for i in 16:
		var x := rng.randf_range(-8.0, 8.0)
		var z0 := rng.randf_range(-26.0, -11.0)
		var a := zed(200 + i, "shambler", Vector3(x, TOP, z0), PI)
		var g := zgait(a, ["", "one", "limp"][i % 3])
		var v: float = g["speed"]
		var t0 := rng.randf_range(0.0, 1.5)
		var p0 := Vector3(x, TOP, z0)
		var p1 := Vector3(x + rng.randf_range(-1, 1), TOP, edge - 0.6)
		var reach := t0 + p0.distance_to(p1) / v
		var due := clampf(rng.randf_range(4.0, 26.0), 0.0, reach - 0.5)
		var kind := i % 5
		if kind == 3:
			# Legs shot away: it falls and crawls on, then a last shot.
			var sh: Array = take.call(due, x)
			var td := float(sh[0]) + 0.08
			var pd := along(p0, p1, v, t0, td)
			move(a, t0, pd, g, PI)
			hit_fx(a, B.SHIN_R, td)
			clip(a, td, Z.legs_off(Z.stand("shambler")))
			later(td + 0.1, func(_t: float) -> void: (a["s"] as Zombie).set_legless(true))
			var cr := Z.crawl()
			var pc := pd + Vector3(0, 0, 2.0)
			move(a, td + 1.2, pc, cr, PI)
			var sh2: Array = take.call(td + 1.2 + 2.0 / float(cr["speed"]) + 0.5, x)
			pose(a, float(sh2[0]) + 0.08, 0.3, Rig.over(Z.lying(0.0), {"add": {B.NECK: Vector3(-30, 0, 0)}}))
			hit_fx(a, B.HEAD, float(sh2[0]) + 0.08)
		else:
			if kind == 1:
				var s0: Array = take.call(maxf(due - 3.0, 2.0), x)
				var ts0 := float(s0[0]) + 0.08
				var pst := along(p0, p1, v, t0, ts0)
				move(a, t0, pst, g, PI)
				hit_fx(a, B.CHEST, ts0)
				clip(a, ts0, Z.stumble(Z.stand("shambler")))
				t0 = ts0 + 1.0
				p0 = pst
			var sh: Array = take.call(maxf(due, t0 + 0.5), x)
			var td := float(sh[0]) + 0.08
			move(a, t0, along(p0, p1, v, t0, td), g, PI)
			hit_fx(a, B.HEAD, td)
			clip(a, td, Z.drop(Z.stand("shambler")))
	# The brute takes three hits from three rifles and goes down.
	var br := zed(90, "brute", Vector3(0.8, TOP, -24.0), PI)
	var bg := zgait(br)
	var bh: Array = []
	for k in 3:
		bh.append(float((take.call(17.0 + 0.4 * k, 0.8) as Array)[0]) + 0.08)
	bh.sort()
	var bp := along(Vector3(0.8, TOP, -24.0), Vector3(0.8, TOP, -1.5), float(bg["speed"]), 0.0, float(bh[0]))
	move(br, 0.0, bp, bg, PI)
	clip(br, float(bh[0]), Z.brute_down(Z.stand("brute"), 3))
	for k in 3:
		hit_fx(br, B.CHEST if k < 2 else B.HEAD, float(bh[0]) + 0.9 * k, k < 2)
	# Runners: one drops at the parapet, one leaps into the trench on a rifleman and the officer shoots it.
	var r1 := zed(61, "runner", Vector3(2.4, TOP, -42.0), PI)
	var tr1 := move(r1, 8.0, Vector3(2.4, TOP, -1.3), zgait(r1), PI)
	var rk1: Array = take.call(tr1 - 0.3, 2.4)
	var tk1 := float(rk1[0]) + 0.08
	r1["segs"].pop_back()
	r1["pos"] = Vector3(2.4, TOP, -42.0)
	move(r1, 8.0, along(Vector3(2.4, TOP, -42.0), Vector3(2.4, TOP, -1.3), 4.3, 8.0, tk1), zgait(r1), PI)
	hit_fx(r1, B.HEAD, tk1)
	clip(r1, tk1, Z.drop(Z.stand("runner")))
	var r2 := zed(77, "runner", Vector3(-2.0, TOP, -45.0), PI)
	var tr2 := move(r2, 11.0, Vector3(-2.0, TOP, -1.6), zgait(r2), PI)
	pose(r2, tr2, 0.15, Z.leap_pose("crouch"))
	shift(r2, tr2 + 0.15, 0.45, Z.leap_pose("fly"), Vector3(-2.0, 0.5, 0.2), 0.6, null, "smooth", PI)
	shift(r2, tr2 + 0.6, 0.3, Z.leap_pose("land"), Vector3(-2.0, 0.0, 1.0), 0.0, null, "smooth", PI)
	clip(r2, tr2 + 0.9, Z.claw_swipe())
	var officer := troop(401, "officer", Vector3(1.0, 0, 1.55), PI * 0.5)
	pose(officer, 0.0, 0.0, O.stand(), null, null)
	pose(officer, tr2 + 0.5, 0.3, O.aim(), null, "prev", "smooth", null, atan2(3.0, 0.55))
	var ots: Array = [tr2 + 1.15, tr2 + 1.75]
	for ts: float in ots:
		pose(officer, ts, 0.06, O.aim(true), null, "prev", "out")
		pose(officer, ts + 0.12, 0.25, O.aim())
	shots(officer, Vector3(0, 0.06, -0.16) + B.REST[B.RIFLE] + B.GRIP_R - B.REST[B.RIFLE], ots, 0.05)
	hit_fx(r2, B.CHEST, ots[0] + 0.03)
	hit_fx(r2, B.HEAD, ots[1] + 0.03)
	clip(r2, ots[1] + 0.03, Z.drop(Z.stand("runner")))
	pose(officer, ots[1] + 1.0, 0.5, O.stand())
	# The riflemen fire on their times; the one the runner hits goes down.
	var men: Array = []
	for i in xs.size():
		var ts: Array = (times[i] as Array).duplicate()
		ts.sort()
		if i == 1:
			ts = ts.filter(func(v: float) -> bool: return v < tr2 - 0.2)
		var a := rifleman(311 + i, Vector3(xs[i], 0.3, 0.42), 0.0, ts)
		men.append(a)
	clip(men[1], tr2 + 0.55, R.library()["death_back"])
	_phases = [[0.0, "The horde against our line: five rifles and the officer"], [8.0, "Head shots drop them, wounds only slow them"],
		[tr2 - 1.0, "A runner reaches the trench"], [ots[0], "The officer's pistol"], [float(bh[0]), "The brute takes three rifles"]]
	_camera = func(t: float) -> void:
		cam.fov = 50.0
		if t < 9.0:
			cam.transform = Transform3D(Basis(), Vector3(1.5, 3.1, 4.8)).looking_at(Vector3(0, 1.6, -14.0), Vector3.UP)
		elif t < tr2 - 1.2:
			cam.transform = Transform3D(Basis(), Vector3(11.0, 3.2, -5.0)).looking_at(Vector3(-1.0, 1.6, -9.0), Vector3.UP)
		elif t < tr2 + 3.5:
			cam.transform = Transform3D(Basis(), Vector3(-6.5, 1.7, 1.2)).looking_at(Vector3(-1.0, 1.0, 0.5), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(2.0, 8.0, 9.0)).looking_at(Vector3(0, 1.2, -9.0), Vector3.UP)
	return maxf(float(bh[0]) + 6.5, tr2 + 9.0)


# ---------------------------------------------------------------- deaths

func _scene_deaths() -> float:
	# A: head shot, drops where it stands.
	var a := zed(seed_where("shambler", "bare", false, 30), "shambler", Vector3(-4.5, 0, -7.0), PI)
	var ta := 3.0
	move(a, 0.0, along(Vector3(-4.5, 0, -7.0), Vector3(-4.5, 0, 3.0), 0.55, 0.0, ta), zgait(a), 0.0)
	hit_fx(a, B.HEAD, ta)
	clip(a, ta, Z.drop(Z.stand("shambler")))
	# B: legs shot from under it; it falls and crawls on; the last shot.
	var b := zed(seed_where("shambler", "gas_mask", true, 10), "shambler", Vector3(-1.5, 0, -7.0), PI)
	var tb := 5.5
	move(b, 0.0, along(Vector3(-1.5, 0, -7.0), Vector3(-1.5, 0, 3.0), 0.55, 0.0, tb), zgait(b, "one"), PI)
	hit_fx(b, B.SHIN_R, tb - 0.25)
	hit_fx(b, B.SHIN_L, tb)
	clip(b, tb, Z.legs_off(Z.stand("shambler")))
	later(tb + 0.1, func(_t: float) -> void: (b["s"] as Zombie).set_legless(true))
	var cr := Z.crawl()
	var pb: Vector3 = b["pos"]
	var tc := move(b, tb + 1.3, pb + Vector3(0, 0, 3.2), cr, PI)
	var tk := minf(tc, 16.5)
	pose(b, tk, 0.3, Rig.over(Z.lying(0.0), {"add": {B.NECK: Vector3(-34, 0, 0), B.HEAD: Vector3(0, 30, 0)}}))
	hit_fx(b, B.HEAD, tk)
	# C: set on fire: it flails, goes to its knees and over, and burns on.
	var c := zed(seed_where("shambler", "bare", true, 50), "shambler", Vector3(1.5, 0, -7.0), PI)
	var tcf := 8.0
	move(c, 0.0, along(Vector3(1.5, 0, -7.0), Vector3(1.5, 0, 3.0), 0.55, 0.0, tcf), zgait(c), PI)
	var bottle := func(t: float) -> Transform3D:
		var u := (t - (tcf - 0.7)) / 0.7
		if u < 0.0 or u > 1.0:
			return HIDE
		var p0 := Vector3(5.0, 1.5, 4.0)
		var p1 := Vector3(1.5, 1.2, -7.0 + 0.55 * tcf)
		return Transform3D(Basis(Vector3.RIGHT, u * 12.0), p0.lerp(p1, u) + Vector3(0, 2.0 * u * (1.0 - u), 0))
	var bottle_geo := func() -> UnitGeo:
		var g := UnitGeo.new()
		g.loft([Vector3(0, -0.1, 0), Vector3(0, 0.06, 0), Vector3(0, 0.12, 0)], [Vector2(0.04, 0.04), Vector2(0.04, 0.04),
			Vector2(0.015, 0.015)], Vector3.RIGHT, 6, 0.0, Color(0.3, 0.45, 0.3), 0)
		g.box(Vector3(0, 0.15, 0), Vector3(0.01, 0.03, 0.01), Color(0.9, 0.85, 0.7), 0)
		return g
	prop(cm("bottle", bottle_geo), [at_world(bottle, 0.0)])
	later(tcf, func(t: float) -> void:
		for k in 20:
			glow_p.add("flame", Vector3(1.5, 1.2, -7.0 + 0.55 * tcf) + glow_p.jitter(0.4), glow_p.jitter(2.0) + Vector3(0, 2.0, 0), 1.0))
	clip(c, tcf + 0.1, Z.burning())
	burn(c, tcf, tcf + 13.0)
	# D: the brute: bullets spark off its plates, then it goes to its knees and down.
	var d := zed(90, "brute", Vector3(4.6, 0, -12.0), PI)
	var tdb := 14.0
	var bg := zgait(d)
	move(d, 6.0, along(Vector3(4.6, 0, -12.0), Vector3(4.6, 0, 3.0), float(bg["speed"]), 6.0, tdb), bg, PI)
	clip(d, tdb, Z.brute_down(Z.stand("brute"), 3))
	for k in 3:
		hit_fx(d, B.CHEST if k != 1 else B.HEAD, tdb + 0.9 * k, k == 0)
	_phases = [[0.0, "Deaths: only the head stops them for good"], [ta, "Head shot: drops on the spot"],
		[tb - 0.3, "Legs shot away: it crawls on"], [tcf - 0.7, "Fire: it burns, staggers and falls"],
		[tdb, "The brute: hits to the plates, then the head"]]
	_camera = func(t: float) -> void:
		cam.fov = 50.0
		if t < 13.5:
			cam.transform = Transform3D(Basis(), Vector3(0.5, 2.6, 7.0)).looking_at(Vector3(0, 0.9, -4.0), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(-1.0, 2.6, 4.5)).looking_at(Vector3(2.5, 0.7, -3.0), Vector3.UP)
	return 22.0
