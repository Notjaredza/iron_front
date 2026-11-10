extends "res://tools/layer_clips.gd"
## The army's war zeppelin, recorded as video frames (Question Chat, 2026-11-10).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/ship_clips.gd -- [scene ...]
## Scenes: look, moor, bombard, night, shotdown. Frames go to results/units/anim_frames/ship_<scene>/,
## ffmpeg makes results/units/anim/ship_<scene>.mp4.
## The MG tool's small sand-coloured ground is hidden; each scene lays a wide countryside (fields, woods, a road).

const SHIP_SCENES: Array[String] = ["look", "moor", "bombard", "night", "shotdown"]
const SHELL_V := 320.0

var ship: Airship
var ship_fn: Callable          # t -> the ship's transform
var break_fn: Callable         # t -> the aft half's drop (radians)
var prop_rate := 14.0
var crew: Array = []           # MG gunners (index = MG)
var mg_target: Array = []      # per MG: Callable(t) -> Variant (world point or null)
var fx: AirFx
var fire_glow: Puffs
var fire_smoke: Puffs
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial


func _run() -> void:
	prefix = "ship_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	for c in root.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
			sky_mat = env.sky.sky_material as ProceduralSkyMaterial
		elif c is DirectionalLight3D:
			sun = c
		elif c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	sun.directional_shadow_max_distance = 600.0
	cam.far = 6000.0
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else SHIP_SCENES):
		await _record(sc)
	print("SHIP CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	crew.clear()
	mg_target = [null, null, null, null]
	ship_fn = func(_t: float) -> Transform3D: return Transform3D(Basis(), Vector3(0, 60, 0))
	break_fn = func(_t: float) -> float: return 0.0
	prop_rate = 14.0
	fx = AirFx.make()
	fx.blasts = false
	stage.add_child(fx)
	fire_glow = Puffs.make(true, 21)
	fire_smoke = Puffs.make(false, 22)
	stage.add_child(fire_glow)
	stage.add_child(fire_smoke)
	set_night(false)


func _effects(t: float) -> void:
	super._effects(t)
	fx.step(1.0 / FPS)
	fire_glow.step(1.0 / FPS)
	fire_smoke.step(1.0 / FPS)


func set_night(on: bool) -> void:
	if sky_mat == null:
		return
	if on:
		sky_mat.sky_top_color = Color(0.015, 0.02, 0.045)
		sky_mat.sky_horizon_color = Color(0.05, 0.06, 0.09)
		sky_mat.ground_horizon_color = Color(0.05, 0.06, 0.09)
		sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.03)
		env.ambient_light_energy = 0.12
		sun.light_energy = 0.07
		sun.light_color = Color(0.6, 0.7, 1.0)
	else:
		sky_mat.sky_top_color = Color(0.30, 0.55, 0.88)
		sky_mat.sky_horizon_color = Color(0.74, 0.84, 0.93)
		sky_mat.ground_horizon_color = Color(0.74, 0.82, 0.88)
		sky_mat.ground_bottom_color = Color(0.35, 0.33, 0.28)
		env.ambient_light_energy = 0.9
		sun.light_energy = 1.3
		sun.light_color = Color(1.0, 0.96, 0.88)


# ---------------------------------------------------------------- world

## A wide countryside: a big ground, field patches, woods and a road (one seed, the same every scene).
func landscape() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5000, 5000)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.55, 0.40)
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	ground.position = Vector3(0, -0.02, 0)
	stage.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var g := TrainGeo.new()
	var fields := [Color(0.50, 0.55, 0.33), Color(0.62, 0.58, 0.40), Color(0.45, 0.50, 0.30), Color(0.66, 0.60, 0.44), Color(0.56, 0.47, 0.34)]
	for i in 160:
		var c := Vector3(rng.randf_range(-1200, 1200), 0.01 + 0.002 * (i % 5), rng.randf_range(-1400, 1000))
		if absf(c.x) < 70.0 and absf(c.z) < 70.0:
			continue
		g.box(c, Vector3(rng.randf_range(25, 70), 0.01, rng.randf_range(25, 80)), fields[i % fields.size()], Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)))
	# Woods: clumps of round trees.
	for w in 28:
		var cc := Vector3(rng.randf_range(-1100, 1100), 0, rng.randf_range(-1300, 900))
		if cc.length() < 150.0:
			continue
		for k in 14:
			var p := cc + Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30))
			var h := rng.randf_range(7.0, 12.0)
			g.cyl(p, p + Vector3(0, h * 0.4, 0), 0.35, 5, Color(0.33, 0.24, 0.15))
			g.lump(p + Vector3(0, h * 0.62, 0), h * 0.32, Color(0.27, 0.36, 0.20).lightened(rng.randf_range(0.0, 0.15)), Vector3(1, 1.2, 1))
	# A road across the country.
	g.box(Vector3(-160, 0.03, -200), Vector3(3.5, 0.01, 1400), Color(0.62, 0.58, 0.50), Basis(Vector3.UP, 0.25))
	g.make(stage, "Country", TrainParts.material())


## An enemy battery dug in on open ground: gun pits ringed with sandbags, ammunition, a tent, a trench. Returns the
## gun pit centres; each gun is a prop that is thrown over when its pit is hit (hits: {pit index: time}).
func battery(at: Vector3, hits: Dictionary) -> Array:
	var pits: Array = []
	var g := TrainGeo.new()
	var offs := [Vector3(-14, 0, -10), Vector3(6, 0, -16), Vector3(16, 0, 4), Vector3(-6, 0, 12)]
	for o: Vector3 in offs:
		var c := at + o
		pits.append(c)
		g.cyl(c + Vector3(0, -0.2, 0), c + Vector3(0, 0.02, 0), 3.4, 12, Color(0.40, 0.34, 0.25))
		for k in 14:
			if k == 3 or k == 4:
				continue
			var a := TAU * k / 14.0
			g.lump(c + Vector3(cos(a) * 3.6, 0.35, sin(a) * 3.6), 0.55, Color(0.62, 0.56, 0.40), Vector3(1.3, 0.6, 0.9))
		for k in 3:
			g.box(c + Vector3(2.2, 0.25, -1.4 + 0.6 * k), Vector3(0.35, 0.25, 0.25), Color(0.40, 0.32, 0.18))
	# A zigzag trench and a tent behind.
	var tz := at + Vector3(-30, 0, 24)
	for k in 8:
		var a := 0.5 if k % 2 == 0 else -0.5
		g.box(tz + Vector3(9.0 * k, 0.03, 0), Vector3(4.8, 0.03, 0.9), Color(0.25, 0.20, 0.15), Basis(Vector3.UP, a))
		g.box(tz + Vector3(9.0 * k, 0.25, -1.2), Vector3(4.8, 0.25, 0.4), Color(0.52, 0.45, 0.32), Basis(Vector3.UP, a))
	var tent := at + Vector3(26, 0, 22)
	g.prism([PackedVector3Array([tent + Vector3(-2, 0, -3), tent + Vector3(2, 0, -3), tent + Vector3(0, 2.2, -3)]),
		PackedVector3Array([tent + Vector3(-2, 0, 3), tent + Vector3(2, 0, 3), tent + Vector3(0, 2.2, 3)])], Color(0.55, 0.52, 0.38))
	g.make(stage, "Battery", TrainParts.material())
	var gun := TrainGeo.new()
	for s: float in [-1.0, 1.0]:
		gun.cyl(Vector3(s * 0.8, 0.6, 0), Vector3(s * 0.65, 0.6, 0), 0.6, 10, Color(0.25, 0.20, 0.14))
	gun.box(Vector3(0, 0.75, 0), Vector3(0.6, 0.35, 0.3), Color(0.30, 0.33, 0.24))
	gun.cyl(Vector3(0, 0.9, 0), Vector3(0, 1.3, -2.4), 0.1, 8, Color(0.25, 0.27, 0.22))
	gun.box(Vector3(0, 0.4, 1.4), Vector3(0.12, 0.1, 1.3), Color(0.30, 0.33, 0.24), Basis(Vector3.RIGHT, 0.25))
	var gm := km_t(gun)
	for i in pits.size():
		var c: Vector3 = pits[i]
		var yaw := 0.4 * float(i) - 0.6
		var keys: Array = [at_world(Transform3D(Basis(Vector3.UP, yaw), c), 0.0)]
		if hits.has(i):
			var th: float = hits[i]
			var fly := func(t: float) -> Transform3D:
				var u := clampf((t - th) / 0.9, 0.0, 1.0)
				var p := c + Vector3(1.8, 0, -1.2) * u + Vector3(0, 4.0 * u * (1.0 - u), 0)
				return Transform3D(Basis(Vector3.UP, yaw + 0.8 * u) * Basis(Vector3(0, 0, 1), 1.9 * u), p + Vector3(0, 0.6 * u, 0))
			keys.append(at_world(fly, th))
		prop(gm, keys)
	return pits


# ---------------------------------------------------------------- the ship

func make_ship() -> void:
	ship = Airship.new().setup()
	stage.add_child(ship)
	updates.append(func(t: float) -> void:
		ship.transform = ship_fn.call(t)
		ship.set_break(break_fn.call(t))
		ship.set_props(t * prop_rate)
		for i in 4:
			var tg: Variant = (mg_target[i] as Callable).call(t) if mg_target[i] != null else null
			if tg != null:
				var a := ship.mg_aim_for(i, tg)
				ship.aim_mg(i, a.x, a.y)
		if frame % 7 == 0 and prop_rate > 3.0:
			for k in 2:
				smoke_p.add("smoke", ship.prop_exhaust(k), Vector3(0, 0.6, 0), 0.35))


## The four MG gunners, riding in their nests (children of the ship's halves).
func gunners() -> void:
	for i in 4:
		var ring := ship.mg_rings[i]
		var a := _man(801 + i, "gunner")
		var s: Soldier = a["s"]
		stage.remove_child(s)
		ring.get_parent().add_child(s)
		a["pos"] = gunner_spot(i, ring.rotation.y)
		a["yaw"] = ring.rotation.y
		var grips := func(_t: float) -> Dictionary:
			var gp: Array = ship.mg_grips(i)
			return {"hand_r": gp[0], "hand_l": gp[1]}
		pose(a, 0.0, 0.0, man_at_gun(), grips, null)
		crew.append(a)


func gunner_spot(i: int, yaw: float) -> Vector3:
	var ring := ship.mg_rings[i]
	var back := Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.62 if i < 2 else 0.55)
	return ring.position + back + Vector3(0, -1.3, 0)


func man_at_gun() -> Dictionary:
	return Rig.over(Body.body("stand"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.7, -0.4, 0.2), "pole_l": Vector3(-0.7, -0.4, 0.2),
		"add": {B.SPINE: Vector3(-6, 0, 0), B.NECK: Vector3(-4, 0, 0)}})


## Keeps gunner i behind his gun while it swings: a pose segment every 0.4 s from t0 to t1 following aim_yaw(t).
func follow_gun(i: int, t0: float, t1: float, aim_yaw: Callable) -> void:
	var a: Dictionary = crew[i]
	var grips := func(_t: float) -> Dictionary:
		var gp: Array = ship.mg_grips(i)
		return {"hand_r": gp[0], "hand_l": gp[1]}
	var t := t0
	while t < t1:
		var y: float = aim_yaw.call(t + 0.4)
		pose(a, t, 0.4, man_at_gun(), grips, "prev", "smooth", gunner_spot(i, y), y)
		t += 0.4


## The yaw MG i will have at time t when pointed at the world point p (worked from ship_fn, no break).
func mg_yaw_at(i: int, t: float, p: Vector3) -> float:
	var half: Transform3D = Transform3D() if i != 1 else ship.aft.transform
	var xf: Transform3D = (ship_fn.call(t) as Transform3D) * half
	var local := xf.affine_inverse() * p - ship.mg_rings[i].position
	return atan2(-local.x, -local.z)


## MG i fires bursts at a target (Callable(t) -> world point) between t0 and t1.
func mg_fire(i: int, t0: float, t1: float, target: Callable) -> void:
	mg_target[i] = func(t: float) -> Variant: return target.call(t) if t >= t0 - 1.5 and t < t1 + 1.0 else null
	follow_gun(i, t0 - 1.5, t1 + 1.0, func(t: float) -> float: return mg_yaw_at(i, t, target.call(t)))
	for f in int((t1 - t0) * FPS):
		if f % 3 != 0 or (f / 24) % 3 == 2:
			continue
		later(t0 + float(f) / FPS, func(_t: float) -> void:
			var m := ship.mg_muzzle(i)
			var d := (ship.mg_guns[i].global_transform.basis * Vector3(0, 0, -1)).normalized()
			fx.shoot(m, d, Vector3.ZERO, 0.012)
			glow_p.add("spark", m + d * 0.2, d * 4.0, 0.9))


## A cannon shot from turret i at a ground point at ts: flash, smoke, the shell streak, the burst on landing.
func cannon(i: int, ts: float, target: Vector3, scale := 1.0) -> void:
	var from := [Vector3.ZERO]
	later(ts, func(_t: float) -> void:
		from[0] = ship.muzzle(i)
		var d := ship.muzzle_dir(i)
		for k in 10:
			smoke_p.add("smoke", from[0] + d * randf_range(0.0, 2.5), d * randf_range(3.0, 10.0) + smoke_p.jitter(1.5), randf_range(1.0, 1.8))
		for k in 6:
			glow_p.add("flame", from[0] + d * randf_range(0.0, 1.5), d * randf_range(6.0, 14.0), 1.2))
	var fl := func(t: float) -> Variant:
		if t >= ts and t < ts + 0.1:
			return Transform3D(Basis().scaled(Vector3.ONE * (1.0 + 6.0 * (t - ts))), ship.muzzle(i))
		return null
	glow(0.9, fl, 6.0)
	var hit := target + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	var tf := 0.45
	var streak := TrainGeo.new()
	streak.box(Vector3(0, 0, -1.5), Vector3(0.12, 0.12, 1.5), Color(1.0, 0.75, 0.35))
	var sm := streak.to_mesh(glow_mat)
	var shell := func(t: float) -> Transform3D:
		var u := (t - ts) / tf
		if u < 0.0 or u >= 1.0 or from[0] == Vector3.ZERO:
			return HIDE
		var p: Vector3 = (from[0] as Vector3).lerp(hit, u)
		return Transform3D(Basis.looking_at(hit - (from[0] as Vector3), Vector3.UP), p)
	prop(sm, [at_world(shell, 0.0)])
	burst_at(hit, ts + tf, scale)


## Turret i follows the target given by aim(t) -> world point, swinging smoothly.
func turret_follow(i: int, aim: Callable) -> void:
	var cur := [Vector2(0.0, -0.3)]
	updates.append(func(t: float) -> void:
		var p: Variant = aim.call(t)
		if p == null:
			return
		var want := ship.turret_aim_for(i, p)
		var c: Vector2 = cur[0]
		c.x = lerp_angle(c.x, want.x, 0.12)
		c.y = lerpf(c.y, want.y, 0.12)
		cur[0] = c
		ship.aim_turret(i, c.x, c.y))


func recoils(i: int, shots: Array) -> void:
	updates.append(func(t: float) -> void:
		var rt := -1.0
		for s: float in shots:
			if t >= s:
				rt = t - s
		ship.recoil(i, rt))


static func spline(keys: Array, t: float) -> Vector3:
	var n := keys.size()
	if t <= float(keys[0][0]):
		return keys[0][1]
	if t >= float(keys[n - 1][0]):
		return keys[n - 1][1]
	var i := 0
	while i < n - 2 and t >= float(keys[i + 1][0]):
		i += 1
	var p0: Vector3 = keys[maxi(i - 1, 0)][1]
	var p1: Vector3 = keys[i][1]
	var p2: Vector3 = keys[i + 1][1]
	var p3: Vector3 = keys[mini(i + 2, n - 1)][1]
	var u := (t - float(keys[i][0])) / (float(keys[i + 1][0]) - float(keys[i][0]))
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


## An enemy fighter flying a spline path; guns fire in the given spans; smoke after smoke_t.
func fighter(keys: Array, fire: Array, smoke_t := -1.0) -> Aircraft:
	var p := AirParts.make("fighter")
	stage.add_child(p)
	p.rpm = 1500.0
	updates.append(func(t: float) -> void:
		var at := spline(keys, t)
		var v := (spline(keys, t + 0.05) - spline(keys, t - 0.05)) / 0.1
		var h := atan2(-v.x, -v.z)
		var v2 := spline(keys, t + 0.35) - spline(keys, t + 0.25)
		var v0 := spline(keys, t - 0.25) - spline(keys, t - 0.35)
		var dh := wrapf(atan2(-v2.x, -v2.z) - atan2(-v0.x, -v0.z), -PI, PI)
		p.fly_pose(at, h, asin(clampf(v.y / maxf(v.length(), 0.1), -1.0, 1.0)), clampf(-dh * 3.0, -1.2, 1.2))
		p.spin(1.0 / FPS)
		var firing := false
		for sp: Array in fire:
			if t >= float(sp[0]) and t < float(sp[1]):
				firing = true
		p.flash(range(p.flashes.size()), firing and frame % 2 == 0)
		if firing and frame % 2 == 0:
			for k in p.flashes.size():
				fx.shoot(p.muzzle(k), p.muzzle_dir(k), v, 0.01)
		if smoke_t >= 0.0 and t > smoke_t:
			fx.trail(p.global_position + p.global_transform.basis.z * 2.0, v, 1.0 if t < smoke_t + 3.0 else 2.0))
	return p


# ---------------------------------------------------------------- look

func _scene_look() -> float:
	landscape()
	make_ship()
	var c := Vector3(0, 40, 0)
	ship_fn = func(_t: float) -> Transform3D: return Transform3D(Basis(), c)
	gunners()
	# The front turret swings and dips; the searchlight wakes up; the gunners swing their MGs.
	updates.append(func(t: float) -> void:
		ship.aim_turret(0, 0.9 * sin(maxf(t - 8.0, 0.0) * 0.6), -0.2 - 0.9 * ramp(t, 8.5, 2.0))
		ship.aim_turret(1, -0.6 * ramp(t, 15.0, 1.5), -1.1 * ramp(t, 15.0, 1.5))
		ship.set_light(t > 21.0 and t < 24.0, 0.5 * sin(t), -0.5 - 0.3 * sin(t * 0.7))
		ship.set_surfaces(0.8 * sin(t * 1.3) * ramp(t, 15.0, 0.5), 0.6 * sin(t * 1.1) * ramp(t, 15.0, 0.5)))
	var top_t := func(t: float) -> Vector3: return c + Vector3(80.0 * sin(t * 0.5), 60.0, -60.0)
	mg_fire(0, 12.2, 12.8, top_t)
	var counts := "close %d tris, far %d" % [ship.tri_count(true), ship.tri_count(false)]
	_phases = [[0.0, "War zeppelin: 90 m rigid hull, control gondola, two engine pods (" + counts + ")"],
		[8.0, "Front belly turret under the gondola: turns and dips to fire down; window MGs either side"],
		[11.5, "Top MG nest: anti-air"], [15.0, "Tail MG nest, fins and rudders; the after gun tub with turret 2"],
		[18.0, "Engine pods: pusher propellers"], [21.0, "Searchlight under the gondola's nose"], [24.0, "Far look (swaps at 700 m)"]]
	_camera = func(t: float) -> void:
		if t < 8.0:
			cam.fov = 45.0
			var a := 0.6 + t * 0.2
			cam.transform = Transform3D(Basis(), c + Vector3(sin(a) * 120.0, -12.0 + t * 2.0, cos(a) * 120.0)).looking_at(c + Vector3(0, -2, 0), Vector3.UP)
		elif t < 11.5:
			cam.fov = 42.0
			cam.transform = Transform3D(Basis(), c + Vector3(12.0, -15.0, -34.0)).looking_at(c + Vector3(0, -10.0, -20.0), Vector3.UP)
		elif t < 15.0:
			cam.fov = 42.0
			cam.transform = Transform3D(Basis(), c + Vector3(14.0, 12.0, -42.0)).looking_at(c + Vector3(0, 7.0, -29.0), Vector3.UP)
		elif t < 18.0:
			cam.fov = 44.0
			cam.transform = Transform3D(Basis(), c + Vector3(-24.0, 4.0, 70.0)).looking_at(c + Vector3(0, -2.0, 36.0), Vector3.UP)
		elif t < 21.0:
			cam.fov = 40.0
			cam.transform = Transform3D(Basis(), c + Vector3(17.0, -9.0, 14.0)).looking_at(c + Vector3(7.6, -6.4, 2.5), Vector3.UP)
		elif t < 24.0:
			cam.fov = 44.0
			cam.transform = Transform3D(Basis(), c + Vector3(-14.0, -16.0, -42.0)).looking_at(c + Vector3(0, -11.0, -27.0), Vector3.UP)
		else:
			cam.fov = 7.0
			cam.transform = Transform3D(Basis(), c + Vector3(-700.0, 250.0, 500.0)).looking_at(c, Vector3.UP)
	return 27.0


# ---------------------------------------------------------------- moor

## The mooring mast: a tapering lattice tower 24 m tall, a platform, the nose cup on top.
func mast() -> Vector3:
	var g := TrainGeo.new()
	var h := 24.0
	var col := Color(0.30, 0.31, 0.29)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		var b := Vector3(cos(a), 0, sin(a))
		g.cyl(b * 4.2, b * 1.0 + Vector3(0, h, 0), 0.14, 5, col)
		g.box(b * 4.2 + Vector3(0, 0.3, 0), Vector3(0.5, 0.3, 0.5), Color(0.5, 0.5, 0.48))
	for lv in 8:
		var y0 := lv * 3.0
		var y1 := y0 + 3.0
		for k in 4:
			var a0 := PI * 0.25 + PI * 0.5 * k
			var a1 := a0 + PI * 0.5
			var w0 := lerpf(4.2, 1.0, y0 / h)
			var w1 := lerpf(4.2, 1.0, y1 / h)
			var p0 := Vector3(cos(a0) * w0, y0, sin(a0) * w0)
			var p1 := Vector3(cos(a1) * w1, y1, sin(a1) * w1)
			var p2 := Vector3(cos(a1) * w0, y0, sin(a1) * w0)
			g.cyl(p0, p1, 0.05, 4, col)
			g.cyl(p0, p2, 0.06, 4, col)
	g.box(Vector3(0, h, 0), Vector3(2.2, 0.08, 2.2), Color(0.42, 0.36, 0.26))
	for k in 4:
		var a := PI * 0.5 * k
		var d := Vector3(cos(a), 0, sin(a))
		var sd := Vector3(-d.z, 0, d.x)
		g.box(Vector3(0, h + 0.55, 0) + d * 2.15, Vector3(0.025, 0.025, 2.15), col, Basis(d, Vector3.UP, sd))
		g.box(Vector3(0, h + 0.5, 0) + d * 2.15 + sd * 2.15, Vector3(0.03, 0.5, 0.03), col)
	g.cyl(Vector3(0, h, 0), Vector3(0, h + 1.2, 0), 0.25, 8, col)
	g.cyl(Vector3(0, h + 1.2, 0), Vector3(0, h + 1.6, 0.0), 0.25, 8, col, 0.6)
	g.box(Vector3(0, h * 0.5, 1.4), Vector3(0.25, h * 0.5, 0.03), col)   # ladder
	g.make(stage, "Mast", TrainParts.material())
	return Vector3(0, h + 1.6, 0)


func _scene_moor() -> float:
	landscape()
	var cup := mast()
	make_ship()
	gunners()
	var t_haul := 14.0
	var t_dock := 26.0
	var v_slow := 1.3
	var v0 := 10.0
	var acc := (v0 - v_slow) / t_haul
	var d_pre := (v0 + v_slow) * 0.5 * t_haul
	var nose_z := func(t: float) -> float:
		var nz := v_slow * (t_dock - t_haul)
		if t < t_haul:
			return nz + d_pre - (v0 * t - 0.5 * acc * t * t)
		return maxf(nz - v_slow * (t - t_haul), 0.0)
	var nose_y := func(t: float) -> float: return lerpf(52.0, cup.y, ramp(t, 0.0, t_haul))
	ship_fn = func(t: float) -> Transform3D:
		var nz: float = nose_z.call(t)
		var pitch := -0.06 * sin(clampf(t / t_haul, 0.0, 1.0) * PI)
		var b := Basis(Vector3.RIGHT, pitch)
		var nose := Vector3(0, nose_y.call(t), nz)
		return Transform3D(b, nose - b * Vector3(0, 0, -Airship.HALF))
	updates.append(func(t: float) -> void:
		prop_rate = lerpf(14.0, 2.0, ramp(t, 12.0, 6.0)) if t < t_dock else lerpf(2.0, 0.0, ramp(t, t_dock, 2.0))
		ship.set_surfaces(0.3 * sin(t * 0.8), -0.4 * ramp(t, 3.0, 3.0) + 0.4 * ramp(t, 11.0, 3.0)))
	# Two handling lines drop from the nose; two gangs of six run out, take them up and walk the ship in.
	var t_drop := 8.0
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var run := Body.gait(Body.RUN, C.carry("free"))
	var haul := Rig.over(Body.body("stand"), {"rifle": GC.SLUNG})
	var ends: Array = []
	var gangs: Array = []
	for si in 2:
		var s := -1.0 if si == 0 else 1.0
		var end := Vector3(s * 10.0, 0.05, float(nose_z.call(t_drop + 2.0)) - 14.0)
		ends.append(end)
		var men: Array = []
		for k in 6:
			var start := Vector3(s * (16.0 + 1.0 * k), 0, 2.0 - 1.5 * k)
			var a := man(831 + si * 10 + k, "gunner", start, PI)
			pose(a, 0.0, 0.0, stand_free(), null, null)
			var spot := end + Vector3(0, -0.05, -1.4 * k - 0.8)
			var ta := move(a, t_drop + 0.6 + 0.15 * k, spot, run, PI)
			pose(a, ta, 0.4, haul, null, "prev", "smooth", null, 0.0)
			move(a, t_haul, spot + Vector3(0, 0, -v_slow * (t_dock - t_haul)), Body.gait(Body.WALK, haul), 0.0)
			pose(a, t_dock + 0.1, 0.5, stand_free(), null, "prev", "smooth", null, PI)
			men.append(a)
		gangs.append(men)
	for si in 2:
		var s := -1.0 if si == 0 else 1.0
		var end: Vector3 = ends[si]
		var men: Array = gangs[si]
		wire(func(t: float) -> PackedVector3Array:
			if t < t_drop:
				return PackedVector3Array()
			var nose := (ship_fn.call(t) as Transform3D) * Vector3(s * 0.3, -0.5, -Airship.HALF + 0.6)
			var u := clampf((t - t_drop) / 2.0, 0.0, 1.0)
			var e := nose.lerp(end, u * u)
			var pts := PackedVector3Array([nose])
			var held := t > t_drop + 4.0
			if held:
				for a: Dictionary in men:
					pts.append(palm_world(a, B.HAND_R))
				pts.append(palm_world(men[5], B.HAND_R) + Vector3(0, -1.0, -1.5))
			else:
				pts.append(nose.lerp(e, 0.5) + Vector3(s * 1.5, -3.0 * u, 0))
				pts.append(e)
			return pts)
	# The mast hand on the platform calls the nose in.
	var mh := man(851, "nco", Vector3(1.2, 24.05, 1.2), PI)
	pose(mh, 0.0, 0.0, stand_free(), null, null)
	pose(mh, 18.0, 0.5, GC.nco_order(0.0))
	for w in 4:
		pose(mh, 20.0 + 1.0 * w, 0.4, GC.nco_order(0.6))
		pose(mh, 20.5 + 1.0 * w, 0.4, GC.nco_order(0.0))
	pose(mh, t_dock + 0.2, 0.5, stand_free())
	_phases = [[0.0, "Mooring: the zeppelin comes in low and slow over the field"], [t_drop, "Handling lines dropped from the nose"],
		[t_drop + 1.0, "The ground crew run out and take up the lines"], [t_haul, "Walking her in to the mast"],
		[t_dock, "Nose in the mast cup: moored, engines stopped"]]
	_camera = func(t: float) -> void:
		var sp := (ship_fn.call(t) as Transform3D).origin
		if t < t_haul:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), Vector3(-95.0, 10.0, 50.0)).looking_at(sp.lerp(cup, 0.35) + Vector3(0, -6.0, 0), Vector3.UP)
		elif t < t_dock - 3.0:
			cam.fov = 50.0
			cam.transform = Transform3D(Basis(), Vector3(-24.0, 2.8, -26.0)).looking_at(Vector3(0, 12.0, 8.0), Vector3.UP)
		else:
			cam.fov = 44.0
			cam.transform = Transform3D(Basis(), Vector3(62.0, 34.0, -40.0)).looking_at(Vector3(0, 18.0, 30.0), Vector3.UP)
	return t_dock + 6.0


# ---------------------------------------------------------------- bombard

func _scene_bombard() -> float:
	landscape()
	var bat := Vector3(28, 0, -40)
	var shots0 := [5.0, 10.0, 15.0, 20.0, 25.0]
	var shots1 := [7.5, 12.5, 17.5, 22.5, 27.5]
	var order0 := [0, 1, 0, 2, 3]
	var order1 := [1, 3, 2, 0, 2]
	var hits := {}
	hits[1] = shots0[1] + 0.45
	hits[2] = shots1[2] + 0.45
	hits[3] = shots0[4] + 0.45
	var pits := battery(bat, hits)
	make_ship()
	gunners()
	ship_fn = func(t: float) -> Transform3D:
		return Transform3D(Basis(Vector3.UP, 0.12), Vector3(-25.0 + 0.5 * t, 115.0, 90.0 - 4.2 * t))
	var target_of := func(shots: Array, order: Array, t: float) -> Variant:
		var idx := 0
		for k in shots.size():
			if t >= float(shots[k]) + 1.0:
				idx = mini(k + 1, shots.size() - 1)
		return (pits[order[idx]] as Vector3) + Vector3(0, 0.5, 0)
	turret_follow(0, func(t: float) -> Variant: return target_of.call(shots0, order0, t))
	turret_follow(1, func(t: float) -> Variant: return target_of.call(shots1, order1, t))
	recoils(0, shots0)
	recoils(1, shots1)
	for k in shots0.size():
		cannon(0, shots0[k], pits[order0[k]], 1.3)
		cannon(1, shots1[k], pits[order1[k]], 1.3)
	# The battery burns where it was hit.
	for pi_: int in hits.keys():
		var c: Vector3 = pits[pi_]
		var th: float = hits[pi_]
		for f in int((32.0 - th) * FPS):
			if f % 3 == 0:
				later(th + 0.5 + float(f) / FPS, func(_t: float) -> void:
					glow_p.add("flame", c + glow_p.jitter(1.2) + Vector3(0, 0.3, 0), Vector3(0, 2.5, 0), 1.2)
					if f % 9 == 0:
						smoke_p.add("burn", c + Vector3(0, 1.5, 0), Vector3(0, 3.5, 0), 2.0))
	_phases = [[0.0, "Bombarding: the zeppelin cruises over an enemy battery at 115 m"],
		[shots0[0], "Front belly turret fires down"], [shots1[0], "After turret fires"],
		[11.0, "Shells landing in the gun pits"], [21.0, "Looking down past the gondola"]]
	_camera = func(t: float) -> void:
		var sp := (ship_fn.call(t) as Transform3D).origin
		if t < 11.0:
			cam.fov = 44.0
			cam.transform = Transform3D(Basis(), sp + Vector3(-75.0, -8.0, -25.0)).looking_at(sp + Vector3(0, -14.0, -5.0), Vector3.UP)
		elif t < 21.0:
			cam.fov = 36.0
			cam.transform = Transform3D(Basis(), bat + Vector3(-260.0, 20.0, 200.0)).looking_at(bat.lerp(sp, 0.45), Vector3.UP)
		else:
			cam.fov = 50.0
			cam.transform = Transform3D(Basis(), sp + Vector3(-30.0, -2.0, 40.0)).looking_at(bat.lerp(sp, 0.22), Vector3.UP)
	return 31.0


# ---------------------------------------------------------------- night

func _scene_night() -> float:
	landscape()
	set_night(true)
	var bat := Vector3(30, 0, -60)
	var shots0 := [14.0, 18.0, 22.0]
	var shots1 := [16.0, 20.0, 24.0]
	var pits := battery(bat, {0: shots1[0] + 0.45, 2: shots0[2] + 0.45})
	make_ship()
	gunners()
	ship_fn = func(t: float) -> Transform3D:
		return Transform3D(Basis(Vector3.UP, 0.1), Vector3(-20.0, 105.0, 70.0 - 3.0 * t))
	var t_found := 10.0
	var sweep := func(t: float) -> Vector2:
		return Vector2(0.75 * sin(t * 0.55) - 0.3, -0.75 - 0.25 * sin(t * 0.9))
	updates.append(func(t: float) -> void:
		var sw: Vector2 = sweep.call(t)
		var on_t := ship.light_aim_for(bat + Vector3(0, 1.0, 0))
		var u := ramp(t, t_found - 1.0, 1.5)
		ship.set_light(true, lerp_angle(sw.x, on_t.x, u), lerpf(sw.y, on_t.y, u)))
	var aim_bat := func(_t: float) -> Variant: return bat + Vector3(0, 0.5, 0)
	turret_follow(0, func(t: float) -> Variant: return aim_bat.call(t) if t > t_found else null)
	turret_follow(1, func(t: float) -> Variant: return aim_bat.call(t) if t > t_found else null)
	recoils(0, shots0)
	recoils(1, shots1)
	for k in 3:
		cannon(0, shots0[k], pits[k % pits.size()], 1.3)
		cannon(1, shots1[k], pits[(k + 1) % pits.size()] if k > 0 else pits[0], 1.3)
	for c: Vector3 in [pits[0], pits[2]]:
		for f in int(10.0 * FPS):
			if f % 3 == 0:
				later(17.0 + float(f) / FPS, func(_t: float) -> void:
					glow_p.add("flame", c + glow_p.jitter(1.2) + Vector3(0, 0.3, 0), Vector3(0, 2.5, 0), 1.3))
	# Small red and green lamps at the gondola's sides.
	for s: float in [-1.0, 1.0]:
		var col := Color(1.0, 0.2, 0.15) if s < 0.0 else Color(0.2, 1.0, 0.35)
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.25
		sp.height = 0.5
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.albedo_color = col
		sp.material = mm
		m.mesh = sp
		m.position = Vector3(s * 1.4, -8.4, -27.8)
		ship.fore.add_child(m)
	_phases = [[0.0, "Night: the searchlight sweeps the ground"], [t_found, "Found the battery: the beam holds on it"],
		[shots0[0], "Both turrets fire down the beam"]]
	_camera = func(t: float) -> void:
		var sp := (ship_fn.call(t) as Transform3D).origin
		if t < 13.0:
			cam.fov = 50.0
			cam.transform = Transform3D(Basis(), Vector3(-120.0, 12.0, -30.0)).looking_at(sp.lerp(bat, 0.5) + Vector3(0, 10.0, 0), Vector3.UP)
		else:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), bat + Vector3(-200.0, 15.0, 160.0)).looking_at(bat.lerp(sp, 0.5), Vector3.UP)
	return 27.0


# ---------------------------------------------------------------- shot down

func _scene_shotdown() -> float:
	landscape()
	make_ship()
	gunners()
	var t_fire := 16.0
	var t_fall := 19.0
	var g_eff := 1.6
	var y0 := 140.0
	var t_impact := t_fall + sqrt((y0 - 30.0) / g_eff * 2.0)
	var settle := 1.8
	var z_at := func(t: float) -> float:
		if t < t_fall:
			return 200.0 - 8.0 * t
		var u := t - t_fall
		return 200.0 - 8.0 * t_fall - 8.0 * u + 0.3 * u * u if u < 13.0 else 200.0 - 8.0 * t_fall - 8.0 * 13.0 + 0.3 * 169.0
	var pitch_at := func(t: float) -> float: return 0.38 * ramp(t, t_fall - 0.5, 5.0)
	var y_at := func(t: float) -> float:
		var u := maxf(t - t_fall, 0.0)
		return y0 - 0.5 * g_eff * u * u
	ship_fn = func(t: float) -> Transform3D:
		var tt := minf(t, t_impact)
		var p := Vector3(0, y_at.call(tt), z_at.call(tt))
		var pitch: float = pitch_at.call(tt)
		var sc := 1.0
		if t > t_impact:
			var u := ramp(t, t_impact, settle)
			p.y = lerpf(p.y, 5.0, u)
			pitch = lerpf(pitch, 0.04, u)
			sc = lerpf(1.0, 0.7, u)
		var x := Transform3D(Basis(Vector3.RIGHT, pitch) * Basis().scaled(Vector3(1.0, sc, 1.0)), p)
		return x
	break_fn = func(t: float) -> float:
		var a := 0.5 * ramp(t, t_fall, 6.0)
		if t > t_impact:
			a = lerpf(a, 0.1, ramp(t, t_impact, settle))
		return a
	# The burn: starts at the stern top, runs both ways along the hull.
	var burn := func(t: float) -> Vector2:
		if t < t_fire + 1.5:
			return Vector2(99.0, 99.0)
		var u := t - t_fire - 1.5
		return Vector2(30.0 - 7.5 * u, 30.0 + 6.0 * u)
	updates.append(func(t: float) -> void:
		var b: Vector2 = burn.call(t)
		ship.set_burn(b.x, b.y)
		prop_rate = 14.0 if t < t_fall + 2.0 else lerpf(14.0, 0.0, ramp(t, t_fall + 2.0, 3.0)))
	# Flames over the burning part of the hull (and the first flicker before it takes).
	for f in int(40.0 * FPS):
		var t := float(f) / FPS
		if t < t_fire:
			continue
		later(t, func(_t: float) -> void:
			var b: Vector2 = burn.call(t)
			var z0 := maxf(b.x, -45.0)
			var z1 := minf(b.y, 45.0)
			var n := 2 if t < t_fire + 1.5 else 7
			if t < t_fire + 1.5:
				z0 = 28.0
				z1 = 33.0
			for k in n:
				var z := randf_range(z0, z1)
				var a := randf_range(-0.2, PI + 0.2) if t < t_impact else randf_range(0.0, PI)
				var r := Airship.radius(z)
				var local := Vector3(cos(a) * r, sin(a) * r, z)
				var half := ship.half_for(z)
				var w := half.global_transform * (local + ship.off_for(z))
				fire_glow.add("flame", w, Vector3(0, 5.0, 0) + fire_glow.jitter(2.0), randf_range(2.0, 3.6))
				if k % 2 == 0:
					fire_smoke.add("burn", w + Vector3(0, 2.0, 0), Vector3(0, 6.0, 0) + fire_smoke.jitter(1.5), randf_range(3.0, 5.0)))
	# The fighter: a head-on pass from ahead, then round behind for a stern attack; the tail gunner hits it.
	var sz := func(t: float) -> float: return z_at.call(t)
	var keys := [[0.0, Vector3(140, 210, -520)], [4.0, Vector3(60, 175, float(sz.call(4.0)) - 230.0)],
		[7.0, Vector3(8, 158, float(sz.call(7.0)) - 10.0)], [9.5, Vector3(-60, 150, float(sz.call(9.5)) + 170.0)],
		[11.5, Vector3(-150, 160, float(sz.call(11.5)) + 300.0)], [13.0, Vector3(-70, 160, float(sz.call(13.0)) + 260.0)],
		[15.0, Vector3(-6, 146, float(sz.call(15.0)) + 95.0)], [16.6, Vector3(14, 150, float(sz.call(16.6)) + 5.0)],
		[19.0, Vector3(90, 135, float(sz.call(19.0)) - 140.0)], [25.0, Vector3(330, 70, float(sz.call(25.0)) - 420.0)],
		[40.0, Vector3(700, 0, -900)]]
	var plane := fighter(keys, [[5.3, 6.7], [14.0, 15.6]], 15.5)
	var at_plane := func(_t: float) -> Vector3: return plane.global_position
	mg_fire(0, 4.6, 7.4, at_plane)
	mg_fire(3, 5.0, 7.0, at_plane)
	mg_fire(1, 12.6, 16.2, at_plane)
	mg_fire(2, 15.8, 17.6, at_plane)
	# Hits on the stern: sparks where the fighter's rounds strike.
	for f in int(1.6 * FPS):
		if f % 3 == 0:
			later(14.2 + float(f) / FPS, func(_t: float) -> void:
				var z := randf_range(26.0, 38.0)
				var w := ship.aft.global_transform * (Vector3(randf_range(-2.0, 2.0), Airship.radius(z) * 0.9, z) + ship.off_for(z))
				glow_p.add("spark", w, glow_p.jitter(4.0), 0.5))
	# The crew in the nests duck when the fire takes; the tail gunner is gone with the stern.
	for i in 4:
		pose(crew[i], t_fire + 2.5, 0.5, T.duck(man_at_gun()))
	updates.append(func(t: float) -> void:
		(crew[1]["s"] as Soldier).visible = t < t_fire + 2.0)
	_phases = [[0.0, "Air fight: an enemy fighter comes in head-on"], [4.6, "Top nest and window MG open up"],
		[11.0, "He comes round for a stern attack: the tail gunner fires"], [14.0, "Incendiary rounds into the stern"],
		[t_fire, "Fire!"], [t_fall, "The hull burns through and she breaks her back"], [t_impact, "Down"]]
	_camera = func(t: float) -> void:
		var sp := (ship_fn.call(t) as Transform3D).origin
		if t < 11.0:
			cam.fov = 44.0
			cam.transform = Transform3D(Basis(), sp + Vector3(-150.0, -40.0, -40.0)).looking_at(sp + Vector3(25.0, 6.0, -60.0), Vector3.UP)
		elif t < t_fall:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), sp + Vector3(-95.0, 8.0, 95.0)).looking_at(sp + Vector3(0, 0, 20.0), Vector3.UP)
		else:
			cam.fov = 48.0
			var crash := Vector3(0, 0, z_at.call(t_impact))
			cam.transform = Transform3D(Basis(), crash + Vector3(-210.0, 14.0, 130.0)).looking_at(sp.lerp(crash, 0.25) + Vector3(0, 6.0, 0), Vector3.UP)
	return t_impact + 7.0
