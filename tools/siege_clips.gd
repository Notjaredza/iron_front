extends "res://tools/lorry_clips.gd"
## The railway siege gun, recorded as video frames (Question Chat, 2026-11-10).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/siege_clips.gd -- [scene ...]
## Scenes: look, move, setup, fire, wreck. Frames go to results/units/anim_frames/siege_<scene>/,
## ffmpeg makes results/units/anim/siege_<scene>.mp4.
## The gun stands on a straight track along -Z with its centre at the origin (path distance D0), so its
## local points are world points when it is not moving.

const GC := preload("res://scripts/units/anim/clips_gun.gd")
const T := preload("res://scripts/units/anim/clips_troops.gd")
const SG := preload("res://scripts/trains/siege_gun.gd")
const SIEGE_SCENES: Array[String] = ["look", "move", "setup", "fire", "wreck"]
const D0 := 60.0
const SMOKE := Color(0.55, 0.55, 0.53)

var updates: Array = []  # Callable(t) run before props and men each frame (the gun's moving parts)
var events: Array = []  # {t, fn, done}
var smoke_p: Puffs
var glow_p: Puffs
var shake_fn: Callable
var path: TrackPath


func _run() -> void:
	prefix = "siege_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else SIEGE_SCENES):
		await _record(sc)
	print("SIEGE CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	updates.clear()
	events.clear()
	smoke_p = Puffs.make(false, 7)
	stage.add_child(smoke_p)
	glow_p = Puffs.make(true, 9)
	stage.add_child(glow_p)
	shake_fn = func(_t: float) -> Vector3: return Vector3.ZERO
	path = TrackPath.line(Vector3(0, 0, D0), Vector3(0, 0, D0 - 260.0))


# ---------------------------------------------------------------- helpers

func later(t: float, fn: Callable) -> void:
	events.append({"t": t, "fn": fn, "done": false})


static func ramp(t: float, t0: float, d: float) -> float:
	return Anim.ease_of(clampf((t - t0) / d, 0.0, 1.0), "smooth")


func _eval_props(t: float) -> void:
	for u: Callable in updates:
		u.call(t)
	super._eval_props(t)


func _effects(t: float) -> void:
	for ev: Dictionary in events:
		if not ev["done"] and t >= float(ev["t"]):
			ev["done"] = true
			(ev["fn"] as Callable).call(t)
	super._effects(t)
	smoke_p.step(1.0 / FPS)
	glow_p.step(1.0 / FPS)


func gun(wreck := false, d := D0) -> SiegeGun:
	var g := SiegeGun.new().setup(wreck)
	stage.add_child(g)
	g.place(path, d)
	return g


func lay_track() -> void:
	stage.add_child(TrainParts.track(path, 0.0, 200.0))


func man(seed_value: int, role: String, at: Vector3, yaw := 0.0) -> Dictionary:
	var a := _man(seed_value, role)
	a["pos"] = at
	a["yaw"] = yaw
	return a


func stand_free() -> Dictionary:
	return Rig.over(Body.body("stand"), C.carry("free"))


func shoot_cam(base: Transform3D, t: float) -> Transform3D:
	var s: Vector3 = shake_fn.call(t)
	return Transform3D(base.basis, base.origin + s)


## The big shot: flash, fire and smoke rolling out along the barrel, the ground dust thrown out in a ring,
## a pressure ring on the ground, the camera shaken.
func big_shot(g: SiegeGun, ts: float, scale := 1.0) -> void:
	var fl := func(t: float) -> Variant:
		if t >= ts and t < ts + 0.12:
			return Transform3D(Basis().scaled(Vector3.ONE * (1.0 + 6.0 * (t - ts))), g.muzzle())
		return null
	glow(1.6 * scale, fl, 12.0)
	later(ts, func(_t: float) -> void:
		var m := g.muzzle()
		var axis := -(g.barrel.global_transform.basis.z).normalized()
		for k in 46:
			var v := axis * randf_range(6.0, 30.0) + smoke_p.jitter(4.0)
			smoke_p.add("smoke", m + axis * randf_range(0.0, 3.0), v, randf_range(2.0, 4.0) * scale)
		for k in 18:
			glow_p.add("flame", m + axis * randf_range(0.0, 4.0), axis * randf_range(8.0, 24.0) + glow_p.jitter(2.0), 2.4 * scale)
		for k in 40:
			var ang := TAU * k / 40.0
			var d := Vector3(cos(ang), 0, sin(ang))
			smoke_p.add("dust", Vector3(d.x * 3.0, 0.3, d.z * 3.0 - 2.0), d * randf_range(9.0, 16.0) + Vector3(0, 1.0, 0), 2.6 * scale)
		for k in 12:
			smoke_p.add("smoke", m + smoke_p.jitter(1.0), smoke_p.jitter(2.0) + Vector3(0, 2.0, 0), 3.0 * scale))
	# A flat pressure ring running out over the ground.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.8, 0.7, 0.0)
	tm.material = mat
	ring.mesh = tm
	stage.add_child(ring)
	updates.append(func(t: float) -> void:
		var u := (t - ts) / 0.9
		ring.visible = u >= 0.0 and u < 1.0
		if ring.visible:
			ring.global_transform = Transform3D(Basis().scaled(Vector3(4.0 + 30.0 * u, 0.25, 4.0 + 30.0 * u)), Vector3(0, 0.15, -3.0))
			mat.albedo_color.a = 0.45 * (1.0 - u))
	var old := shake_fn
	shake_fn = func(t: float) -> Vector3:
		var s: Vector3 = old.call(t)
		var u := t - ts
		if u >= 0.0 and u < 1.2:
			var amp := 0.25 * scale * (1.0 - u / 1.2)
			s += Vector3(sin(t * 91.0), sin(t * 77.0 + 1.0), sin(t * 63.0 + 2.0)) * amp
		return s


## The body rocks back and settles on the shot.
static func rock(t: float, shots: Array) -> float:
	var r := 0.0
	for ts: float in shots:
		var u := t - ts
		if u >= 0.0 and u < 1.5:
			r += 0.012 * sin(u * 14.0) * exp(-u * 3.0)
	return r


# ---------------------------------------------------------------- look

func _scene_look() -> float:
	lay_track()
	var g := gun()
	var wr := SiegeGun.new().setup(true)
	stage.add_child(wr)
	wr.place(path, D0 - 30.0)
	wr.aim(0.12, 0.18)
	wr.set_outriggers(1.0)
	wr.body.rotation = Vector3(0.0, 0.0, 0.05)
	updates.append(func(t: float) -> void:
		g.set_outriggers(ramp(t, 2.0, 2.0))
		g.aim(0.05 * sin(maxf(t - 9.0, 0.0) * 0.8) * (1.0 if t > 9.0 else 0.0), 0.75 * ramp(t, 4.5, 3.5) - 0.75 * ramp(t, 9.5, 2.5))
		g.set_breech(ramp(t, 8.0, 0.8))
		g.set_crane(1.9 * ramp(t, 6.0, 3.0), 0.5 + 1.0 * ramp(t, 9.0, 1.0)))
	var counts := "close %d, far %d" % [g.tri_count(true), g.tri_count(false)]
	_phases = [[0.0, "Railway siege gun (about 28 cm howitzer, 20 m long, two 4-axle bogies): " + counts],
		[2.0, "Outriggers down"], [4.5, "Elevating to 43 degrees"], [6.0, "Shell crane swings to the loading tray"],
		[8.0, "Breech open"], [12.5, "Far look (the game swaps at 320 m)"], [16.0, "The wreck"]]
	_camera = func(t: float) -> void:
		if t < 12.5:
			cam.fov = 48.0
			var a := 0.9 + t * 0.2
			cam.transform = Transform3D(Basis(), Vector3(sin(a) * 19.0, 6.5, cos(a) * 19.0)).looking_at(Vector3(0, 2.4, 0), Vector3.UP)
		elif t < 16.0:
			cam.fov = 11.0
			cam.transform = Transform3D(Basis(), Vector3(150.0, 35.0, 160.0)).looking_at(Vector3(0, 3.0, 12.0), Vector3.UP)
		else:
			cam.fov = 44.0
			cam.transform = Transform3D(Basis(), Vector3(14.0, 6.0, 46.0)).looking_at(Vector3(0, 2.0, 30.0), Vector3.UP)
	return 20.0


# ---------------------------------------------------------------- move

func _scene_move() -> float:
	path = TrackPath.straight_curve(Vector3(0, 0, 60), Vector3(0, 0, -1), 45.0, 110.0, 0.55, 60.0)
	stage.add_child(TrainParts.track(path, 0.0, path.length()))
	var g := SiegeGun.new().setup(false)
	stage.add_child(g)
	var eng := TrainParts.make("engine")
	stage.add_child(eng)
	var gap := SiegeGun.REAR_Z + 0.12 - eng.front_z
	# Distance run: speed up to 4 m/s, run, slow to a stop at 70 m.
	var d_start := 20.0
	var d_stop := 98.0
	var t_go := 1.0
	var vmax := 4.0
	var acc := 0.8
	var run := d_stop - d_start
	var t_acc := vmax / acc
	var d_acc := 0.5 * acc * t_acc * t_acc
	var t_cruise := (run - 2.0 * d_acc) / vmax
	var t_end := t_go + 2.0 * t_acc + t_cruise
	var dist := func(t: float) -> float:
		var u := t - t_go
		if u <= 0.0:
			return 0.0
		if u < t_acc:
			return 0.5 * acc * u * u
		if u < t_acc + t_cruise:
			return d_acc + vmax * (u - t_acc)
		var w := minf(u - t_acc - t_cruise, t_acc)
		return d_acc + vmax * t_cruise + vmax * w - 0.5 * acc * w * w
	var last := [0.0]
	var beat := [0.0]
	updates.append(func(t: float) -> void:
		var d: float = d_start + float(dist.call(t))
		g.place(path, d)
		eng.global_transform = path.car_frame(d - gap, eng)
		var dd: float = d - float(last[0])
		eng.roll(dd)
		last[0] = d
		g.set_outriggers(ramp(t, t_end + 1.0, 2.0)))
	var chimney := func(t: float) -> void:
		var d: float = d_start + float(dist.call(t))
		var moved: float = d - float(beat[0])
		var pull := t > t_go and t < t_go + t_acc + t_cruise
		if moved > 0.9 or (pull and moved > 0.6):
			beat[0] = d
			var top := eng.global_transform * (eng.marks["chimney"] as Vector3)
			smoke_p.add("smoke", top, Vector3(0, 4.0 if pull else 2.0, 0), 0.9 if pull else 0.6)
		elif frame % 20 == 0:
			smoke_p.add("smoke", eng.global_transform * (eng.marks["chimney"] as Vector3), Vector3(0, 1.5, 0), 0.45)
		if t > t_go - 0.3 and t < t_go + 2.5 and frame % 2 == 0:
			for k: String in ["cock_l", "cock_r"]:
				var p := eng.global_transform * (eng.marks[k] as Vector3)
				smoke_p.add("steam", p, eng.global_transform.basis * Vector3(signf((eng.marks[k] as Vector3).x) * 2.0, 0.3, -1.0), 0.8)
	for f in int((t_end + 4.0) * FPS):
		later(float(f) / FPS, chimney)
	_phases = [[0.0, "Moving: one engine pushes the gun (bogies follow the curve)"], [t_end, "Stopped at the firing spot"],
		[t_end + 1.0, "Outriggers down onto the ground"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		var d: float = d_start + float(dist.call(t))
		var p := path.point(d)
		var fr := path.frame(d)
		var side := fr.basis.x
		var at := p + side * 27.0 + Vector3(0, 10.0, 0) + fr.basis.z * -4.0
		cam.transform = Transform3D(Basis(), at).looking_at(p + Vector3(0, 2.0, 0) + fr.basis.z * 3.0, Vector3.UP)
	return t_end + 4.0


# ---------------------------------------------------------------- setup

## Climbing a side ladder onto the rear platform: up the rungs, a step over onto the boards.
func climb(a: Dictionary, t0: float, s: float) -> float:
	var x := s * (1.62 + 0.38)
	var yaw := PI * 0.5 if s > 0.0 else -PI * 0.5
	var rung := func(r: float) -> Callable:
		return func(_t: float) -> Dictionary:
			var y: float = 0.35 + 0.33 * r
			return {"hand_r": Vector3(s * 1.62 - s * 0.06, y, 7.8 + 0.2 * -s), "hand_l": Vector3(s * 1.62 - s * 0.06, y, 7.8 - 0.2 * -s)}
	var up_r := Rig.over(Body.body("stand"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.6, -0.4, 0.3), "pole_l": Vector3(-0.6, -0.4, 0.3),
		"rot": {B.THIGH_R: Vector3(70, 0, 4), B.SHIN_R: Vector3(-95, 0, 0), B.FOOT_R: Vector3(20, 0, 0)}})
	var up_l := Rig.over(Body.body("stand"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.6, -0.4, 0.3), "pole_l": Vector3(-0.6, -0.4, 0.3),
		"rot": {B.THIGH_L: Vector3(70, 0, -4), B.SHIN_L: Vector3(-95, 0, 0), B.FOOT_L: Vector3(20, 0, 0)}})
	var t := t0
	for k in 7:
		var y := 0.33 * float(k + 1)
		shift(a, t, 0.38, up_r if k % 2 == 0 else up_l, Vector3(x, minf(y, SiegeGun.PLAT_Y), 7.8), 0.0, rung.call(float(k + 3)), "smooth", yaw)
		t += 0.38
	shift(a, t, 0.55, stand_free(), Vector3(s * 1.15, SiegeGun.PLAT_Y, 7.8), 0.25, null, "smooth", yaw)
	return t + 0.55


func _scene_setup() -> float:
	lay_track()
	var g := gun()
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var officer := man(401, "officer", Vector3(-9.0, 0, 2.0), -PI * 0.5)
	pose(officer, 0.0, 0.0, O.stand(), null, null)
	move(officer, 0.3, Vector3(-4.6, 0, 0.5), Body.gait(O.WALK, O.walking()), -PI * 0.5)
	pose(officer, 3.6, 0.5, O.binos(30.0), null)
	var bp := Transform3D(O.BINO_HELD.basis, B.REST[B.HEAD] + O.BINO_HELD.origin)
	prop(km(K.binoculars()), [at_world(HIDE, 0.0), on_bone(officer, B.HEAD, bp, 3.8, 0.3), at_world(HIDE, 9.0)])
	pose(officer, 9.0, 0.5, O.point_call(Vector3(-0.4, 1.6, -8.0)))
	pose(officer, 11.0, 0.5, O.stand())
	# Four men to the outriggers: each pushes his arm down from the folded position.
	var out_t := 4.0
	updates.append(func(t: float) -> void:
		g.set_outriggers(ramp(t, out_t, 3.0))
		g.aim(0.035 * ramp(t, 12.0, 2.0) - 0.035 * ramp(t, 15.0, 2.0), 0.35 * ramp(t, 11.0, 3.0) - 0.35 * ramp(t, 15.0, 3.0)))
	for i in 4:
		var p: Vector3 = SiegeGun.OUTRIG[i]
		var s := signf(p.x)
		var a := man(411 + i, "gunner", Vector3(s * 7.0, 0, p.z + 3.0), 0.0)
		pose(a, 0.0, 0.0, stand_free(), null, null)
		var spot := Vector3(s * 3.6, 0, p.z + 0.55)
		var ta := move(a, 0.2 + 0.25 * i, spot, walk, PI if p.z < 0.0 else PI)
		var arm_end := func(t: float) -> Dictionary:
			var x := g.outriggers[i].global_transform * Vector3(s * SiegeGun.OUT_LEN * 0.92, 0.1, 0)
			return {"hand_r": x + Vector3(0, 0.0, 0.15), "hand_l": x + Vector3(0, 0.0, -0.15)}
		pose(a, ta, 0.5, Rig.over(Body.body("stand"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.7, -0.3, 0.2), "pole_l": Vector3(-0.7, -0.3, 0.2),
			"rot": {B.UARM_R: Vector3(-60, 0, 0), B.UARM_L: Vector3(-60, 0, 0)}}), arm_end, "prev", "smooth", null, -PI * 0.5 * s)
		pose(a, out_t + 0.6, 2.2, GC.heave(40.0, 25.0), arm_end)
		pose(a, out_t + 3.2, 0.5, stand_free())
	# The gun crew climb the ladders onto the platform and take post.
	var posts := [[1.0, Vector3(0.45, SiegeGun.PLAT_Y, 5.0)], [-1.0, Vector3(-0.45, SiegeGun.PLAT_Y, 5.6)],
		[1.0, Vector3(0.95, SiegeGun.PLAT_Y, 7.35)], [-1.0, Vector3(-0.45, SiegeGun.PLAT_Y, 6.6)]]
	for i in posts.size():
		var s: float = posts[i][0]
		var a := man(421 + i, "gunner", Vector3(s * 9.0, 0, 9.0 + 1.5 * i), 0.0)
		pose(a, 0.0, 0.0, stand_free(), null, null)
		var ta := move(a, 1.0 + 1.6 * i, Vector3(s * 2.0, 0, 7.8), walk, PI * 0.5 * s)
		ta = climb(a, ta + 0.2, s)
		var post: Vector3 = posts[i][1]
		ta = move(a, ta, post, walk, 0.0)
		pose(a, ta, 0.4, stand_free())
	# The layer up onto the girder by the handwheel.
	var ly := man(431, "gunner", Vector3(5.0, 0, -1.0), 0.0)
	pose(ly, 0.0, 0.0, stand_free(), null, null)
	var tl := move(ly, 2.0, Vector3(1.75, 0, 2.2), walk, PI * 0.5)
	shift(ly, tl, 0.9, GC.heave(20.0, 30.0), Vector3(1.05, SiegeGun.DECK_Y, 2.2), 0.4, null, "smooth", 0.0)
	var wheel := func(t: float) -> Dictionary:
		var a := t * 3.0
		var x := g.mount.global_transform * Vector3(0.95, SiegeGun.TRUNNION_H - 0.35 + 0.18 * sin(a), 0.9 + 0.18 * cos(a))
		return {"hand_r": x, "hand_l": x + Vector3(0, -0.04, 0.05)}
	pose(ly, tl + 1.0, 0.5, Rig.over(Body.body("stand"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.7, -0.4, 0.2), "pole_l": Vector3(-0.5, -0.6, 0.3),
		"add": {B.SPINE: Vector3(-8, 0, 0), B.NECK: Vector3(-10, 0, 0)}}), wheel)
	_phases = [[0.0, "Set-up: the crew come up, the officer glasses the target"], [out_t, "Outriggers pushed down onto the ground"],
		[6.0, "The crew climb onto the loading platform"], [11.0, "The layer traverses and elevates to the officer's line"]]
	_camera = func(t: float) -> void:
		cam.fov = 48.0
		if t < 9.5:
			cam.transform = Transform3D(Basis(), Vector3(-15.0, 6.5, 14.0)).looking_at(Vector3(0, 1.5, 3.0), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(9.0, 6.0, 12.0)).looking_at(Vector3(0, 2.5, 3.0), Vector3.UP)
	return 18.0


# ---------------------------------------------------------------- fire

func _scene_fire() -> float:
	lay_track()
	var g := gun()
	var shots: Array = [22.0, 31.0]
	var elev_fn := func(t: float) -> float: return 0.72 * ramp(t, 17.0, 4.2)
	# The crane: hoist, swing, lower; the breech: open, then shut after the charge.
	var hook_drop := func(t: float) -> float:
		var d := lerpf(0.5, 4.3, ramp(t, 3.0, 1.4))
		d = lerpf(d, 1.62, ramp(t, 5.2, 2.2))
		d = lerpf(d, 1.75, ramp(t, 10.0, 0.5))
		return lerpf(d, 0.6, ramp(t, 11.0, 1.2))
	var crane_yaw := func(t: float) -> float: return 1.896 * ramp(t, 7.6, 2.3)
	updates.append(func(t: float) -> void:
		g.set_outriggers(1.0)
		g.set_crane(crane_yaw.call(t), hook_drop.call(t))
		g.set_breech(1.0 - ramp(t, 15.8, 0.6))
		g.aim(0.0, elev_fn.call(t))
		var rt := -1.0
		for s: float in shots:
			if t >= s:
				rt = t - s
		g.recoil(rt)
		g.body.rotation = Vector3(rock(t, shots), 0, 0))
	# The shell: on the trolley, on the hook, on the tray, rammed home.
	var trolley := func(t: float) -> Transform3D:
		var p := Vector3(5.5, 0, 12.0).lerp(Vector3(3.85, 0, 6.6), ramp(t, 0.0, 3.0))
		return Transform3D(Basis(Vector3.UP, 0.4 * (1.0 - ramp(t, 1.5, 1.5))), p)
	prop(km_t(SiegeGun.trolley_geo()), [at_world(trolley, 0.0)])
	var on_trolley := func(t: float) -> Transform3D:
		var x: Transform3D = trolley.call(t)
		return Transform3D(x.basis, x * Vector3(0, 0.45 + SiegeGun.SHELL_R, 0.7))
	var on_hook := func(_t: float) -> Transform3D:
		return Transform3D(Basis(), g.hook_point() + Vector3(0, -0.16, 0.7))
	var tray_z := 4.5
	var tray := Transform3D(Basis(), Vector3(0, 3.135 + SiegeGun.SHELL_R, tray_z))
	var rammed := func(t: float) -> Transform3D:
		var z := lerpf(tray_z, 2.0, ramp(t, 12.6, 1.6))
		if t > 14.3:
			return HIDE
		return Transform3D(Basis(), Vector3(0, 3.3, z) if z < 2.75 else Vector3(0, lerpf(3.275, 3.3, ramp(t, 12.6, 0.8)), z))
	prop(km_t(SiegeGun.shell_geo()), [at_world(on_trolley, 0.0), at_world(on_hook, 4.4, 0.3), at_world(tray, 12.2, 0.25), at_world(rammed, 12.6)])
	# Two men push the trolley in; one hooks the shell on.
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var push := GC.push_gait(Vector3(0.2, 0.92, -0.45), Vector3(-0.2, 0.92, -0.45), 1.6)
	for i in 2:
		var a := man(441 + i, "gunner", Vector3(5.5 + (0.45 if i == 0 else -0.45), 0, 12.0 + 1.5), 0.0)
		pose(a, 0.0, 0.0, stand_free(), null, null)
		var handle := func(t: float) -> Dictionary:
			var x: Transform3D = trolley.call(t)
			return {"hand_r": x * Vector3(0.18, 0.9, 1.3), "hand_l": x * Vector3(-0.18, 0.9, 1.3)}
		if i == 0:
			pose(a, 0.0, 0.0, GC.heave(20.0, 10.0), handle)
			shift(a, 0.0, 3.0, GC.heave(20.0, 10.0), Vector3(3.85 + 0.0, 0, 6.6 + 1.85), 0.0, handle, "smooth", 0.4 * 0.0)
			pose(a, 3.1, 0.5, stand_free())
		else:
			move(a, 0.4, Vector3(4.6, 0, 6.6), walk, PI * 0.5)
			var to_hook := func(_t: float) -> Dictionary:
				var h := g.hook_point()
				return {"hand_r": h + Vector3(0, 0.0, 0.05), "hand_l": h + Vector3(0, 0.0, -0.05)}
			pose(a, 3.6, 0.5, GC.heave(30.0, 20.0), to_hook)
			pose(a, 4.4, 0.3, GC.heave(30.0, 20.0), to_hook)
			pose(a, 4.9, 0.6, stand_free())
			move(a, 6.0, Vector3(6.5, 0, 4.0), walk, PI * 0.5)
	# The crane man winds the handle while the shell goes up and down.
	var cm := man(451, "gunner", Vector3(0.95, SiegeGun.PLAT_Y, 7.45), 0.0)
	var winding := func(t: float) -> Dictionary:
		var a := t * 5.0
		var p := SiegeGun.WINCH + Vector3(0.2 * cos(a), 0.2 * sin(a), 0)
		return {"hand_r": p + Vector3(0, 0, 0.02), "hand_l": p + Vector3(0, 0, -0.03)}
	var wind_spec := Rig.over(Body.body("stand"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.8, -0.3, 0.3), "pole_l": Vector3(-0.5, -0.6, 0.3),
		"add": {B.SPINE: Vector3(-10, 0, 0), B.NECK: Vector3(-6, 0, 0)}})
	pose(cm, 0.0, 0.0, stand_free(), null, null)
	pose(cm, 3.0, 0.5, wind_spec, winding)
	pose(cm, 7.6, 0.5, Rig.over(stand_free(), {"hand_r": [-1, Vector3(0.25, 1.35, -0.55)], "pole_r": Vector3(0.7, -0.3, 0.2)}), null)
	pose(cm, 10.0, 0.4, wind_spec, winding)
	pose(cm, 12.3, 0.5, stand_free())
	# The rammer team: three men on the left of the tray holding the long pole.
	var head_z := func(t: float) -> float:
		var z := 5.05
		z = lerpf(z, tray_z, ramp(t, 12.4, 0.2))
		z = lerpf(z, 2.0 + 0.0, ramp(t, 12.6, 1.6))
		z = lerpf(z, 5.05, ramp(t, 14.3, 1.0))
		z = lerpf(z, 4.25, ramp(t, 14.9, 0.3))
		z = lerpf(z, 2.0, ramp(t, 15.2, 1.0))
		return lerpf(z, 5.05, ramp(t, 16.3, 1.0))
	var pole := func(t: float) -> Transform3D:
		return Transform3D(Basis(), Vector3(0, 3.3, head_z.call(t)))
	prop(km_t(SiegeGun.rammer_geo()), [at_world(pole, 0.0)])
	var ram_spec := Rig.over(Body.body("ready"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.6, -0.6, 0.3), "pole_l": Vector3(-0.6, -0.6, 0.2),
		"add": {B.SPINE: Vector3(-8, 0, 0), B.HIPS: Vector3(0, 30, 0)}})
	var rammers: Array = []
	for i in 3:
		var off := 1.2 + 0.85 * i
		var a := man(461 + i, "gunner", Vector3(-0.42, SiegeGun.PLAT_Y, 5.05 + off + 0.15), 0.0)
		var on_pole := func(t: float) -> Dictionary:
			var z: float = head_z.call(t) + off
			return {"hand_r": Vector3(0.0, 3.3, z - 0.25), "hand_l": Vector3(0.0, 3.3, z + 0.15)}
		pose(a, 0.0, 0.0, ram_spec, on_pole, null)
		# Their feet follow the pole (a shuffle forward and back).
		var steps := [[12.6, 1.6, 2.0], [14.3, 1.0, 5.05], [14.9, 0.3, 4.25], [15.2, 1.0, 2.0], [16.3, 1.0, 5.05]]
		for st: Array in steps:
			var to := Vector3(-0.42, SiegeGun.PLAT_Y, float(st[2]) + off + 0.15)
			shift(a, float(st[0]), float(st[1]), ram_spec, to, 0.0, on_pole)
		rammers.append(a)
	# The charge: from the rear box to the tray.
	var ch := man(471, "gunner", Vector3(0.5, SiegeGun.PLAT_Y, 9.1), PI)
	pose(ch, 0.0, 0.0, stand_free(), null, null)
	var box := Vector3(1.05, SiegeGun.PLAT_Y + 0.52, 9.55)
	pose(ch, 10.0, 0.6, GC.heave(40.0, 20.0), {"hand_r": box + Vector3(0.12, 0.1, 0.0), "hand_l": box + Vector3(-0.12, 0.1, 0.0)}, "prev", "smooth", null, PI * 0.75)
	var carry_spec := Rig.over(stand_free(), {"hand_r": [B.CHEST, Vector3(0.12, 1.15, -0.36)], "hand_l": [B.CHEST, Vector3(-0.12, 1.15, -0.36)],
		"pole_r": Vector3(0.6, -0.5, 0.2), "pole_l": Vector3(-0.6, -0.5, 0.2)})
	pose(ch, 10.9, 0.5, carry_spec, null, "prev", "smooth", null, 0.0)
	var t_c := move(ch, 11.5, Vector3(0.45, SiegeGun.PLAT_Y, 5.3), Body.gait(Body.WALK, carry_spec), 0.0)
	var tray_charge := Transform3D(Basis(), Vector3(0, 3.135 + 0.15, 4.25))
	pose(ch, t_c, 0.5, GC.heave(25.0, 10.0), {"hand_r": tray_charge * Vector3(0.12, 0.1, -0.45), "hand_l": tray_charge * Vector3(-0.12, 0.1, -0.45)})
	pose(ch, t_c + 0.7, 0.5, stand_free())
	move(ch, t_c + 1.3, Vector3(0.6, SiegeGun.PLAT_Y, 8.4), walk, PI)
	var charge_in := func(t: float) -> Transform3D:
		if t > 16.25:
			return HIDE
		return Transform3D(Basis(), Vector3(0, lerpf(3.285, 3.3, ramp(t, 15.2, 0.5)), lerpf(4.25, 2.0, ramp(t, 15.2, 1.0))))
	var ch_hand := Transform3D(Basis(), Vector3(0, -0.12, 0.45))
	prop(km_t(SiegeGun.charge_geo()), [at_world(Transform3D(Basis(), box + Vector3(0, -0.05, 0.4)), 0.0),
		on_bone(ch, B.CHEST, Transform3D(Basis(), B.REST[B.CHEST] + Vector3(0, -0.09, -0.36 + 0.45)), 10.7, 0.25),
		at_world(tray_charge, t_c + 0.4, 0.3), at_world(charge_in, 15.2)])
	# The breech man on the left girder: shuts the breech, jumps down, takes the lanyard.
	var bm := man(481, "gunner", Vector3(-1.0, SiegeGun.DECK_Y, 2.9), -PI * 0.5)
	pose(bm, 0.0, 0.0, stand_free(), null, null)
	var lever := func(_t: float) -> Dictionary:
		var p := g.breech.global_transform * Vector3(-0.4, 0.0, 0.3)
		return {"hand_r": p + Vector3(0, 0.02, 0.03), "hand_l": p + Vector3(0, -0.02, -0.04)}
	pose(bm, 15.4, 0.4, GC.heave(20.0, 10.0), lever)
	pose(bm, 16.5, 0.4, stand_free())
	shift(bm, 16.9, 0.8, GC.heave(10.0, 35.0), Vector3(-2.3, 0, 2.9), 0.45, null, "smooth", -PI * 0.5)
	var tlan := move(bm, 17.8, Vector3(-4.2, 0, 4.0), walk, -PI * 0.65)
	var lan_spec := Rig.over(stand_free(), {"hand_r": [B.CHEST, Vector3(0.18, 1.1, -0.4)], "pole_r": Vector3(0.7, -0.4, 0.2)})
	pose(bm, tlan, 0.5, lan_spec)
	var pull := Rig.over(lan_spec, {"hand_r": [B.CHEST, Vector3(0.22, 1.05, 0.05)], "add": {B.SPINE: Vector3(10, 0, 0), B.CHEST: Vector3(6, 0, 0)}})
	for s: float in shots:
		pose(bm, s - 0.15, 0.15, pull, null, "prev", "out")
		pose(bm, s + 0.2, 0.25, GC.flinch(pull, false))
		pose(bm, s + 2.5, 0.6, lan_spec)
	wire(func(t: float) -> PackedVector3Array:
		if t < 17.8:
			return PackedVector3Array()
		var a := g.breech.global_transform * Vector3(-0.42, 0.0, 0.3)
		var b := palm_world(bm, B.HAND_R)
		var mid := a.lerp(b, 0.5) + Vector3(0, -0.25, 0)
		for s: float in shots:
			if t > s - 0.15:
				mid = a.lerp(b, 0.5) + Vector3(0, -0.05, 0)
		return PackedVector3Array([a, mid, b]))
	# The layer winds the barrel up for the shot.
	var ly := man(491, "gunner", Vector3(1.05, SiegeGun.DECK_Y, 2.2), 0.0)
	var wheel := func(t: float) -> Dictionary:
		var a := t * 4.0 if t > 17.0 and t < 21.2 else 0.0
		var x := g.mount.global_transform * Vector3(0.95, SiegeGun.TRUNNION_H - 0.35 + 0.18 * sin(a), 0.9 + 0.18 * cos(a))
		return {"hand_r": x, "hand_l": x + Vector3(0, -0.04, 0.05)}
	var lay_spec := Rig.over(Body.body("stand"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.7, -0.4, 0.2), "pole_l": Vector3(-0.5, -0.6, 0.3),
		"add": {B.SPINE: Vector3(-8, 0, 0), B.NECK: Vector3(-10, 0, 0)}})
	pose(ly, 0.0, 0.0, stand_free(), null, null)
	pose(ly, 16.6, 0.4, lay_spec, wheel)
	# Everyone on the gun crouches with their ears covered for the shot.
	for s: float in shots:
		for a: Dictionary in rammers + [cm, ch, ly]:
			pose(a, s - 1.2, 0.5, T.duck(T.kneel_work(6.0)))
			pose(a, s + 3.0, 0.7, stand_free())
	var officer := man(401, "officer", Vector3(-6.5, 0, -1.0), -PI * 0.42)
	pose(officer, 0.0, 0.0, O.stand(), null, null)
	for s: float in shots:
		pose(officer, s - 2.4, 0.4, Rig.over(GC.nco_order(0.0), {"rifle": O.pistol("holster")}))
		pose(officer, s - 0.35, 0.2, Rig.over(GC.nco_order(1.0), {"rifle": O.pistol("holster")}), null, "prev", "out")
		pose(officer, s + 0.2, 0.3, GC.flinch(Rig.over(O.stand(), {}), true))
		pose(officer, s + 2.6, 0.6, O.stand())
	for s: float in shots:
		big_shot(g, s, 1.0)
	_phases = [[0.0, "Fire: the shell comes up on its trolley"], [3.6, "Hooked on, hoisted, swung to the tray"],
		[10.0, "The charge from the rear box"], [12.6, "Rammed: shell, then charge"], [15.8, "Breech shut; lanyard out"],
		[17.0, "Elevating to 41 degrees; the crew take cover"], [shots[0] - 2.4, "Ready ... FIRE"], [27.0, "Second round, from 150 m"]]
	_camera = func(t: float) -> void:
		var x: Transform3D
		if t < 3.6:
			cam.fov = 46.0
			x = Transform3D(Basis(), Vector3(11.0, 4.5, 17.0)).looking_at(Vector3(1.5, 2.0, 5.0), Vector3.UP)
		elif t < 10.0:
			cam.fov = 46.0
			x = Transform3D(Basis(), Vector3(8.5, 4.2, 10.5)).looking_at(Vector3(1.5, 3.0, 5.2), Vector3.UP)
		elif t < 16.6:
			cam.fov = 46.0
			x = Transform3D(Basis(), Vector3(-4.2, 5.4, 10.0)).looking_at(Vector3(0, 3.0, 4.0), Vector3.UP)
		elif t < 27.0:
			cam.fov = 50.0
			x = Transform3D(Basis(), Vector3(-17.0, 4.0, 6.0)).looking_at(Vector3(0, 4.0, -2.0), Vector3.UP)
		else:
			cam.fov = 30.0
			x = Transform3D(Basis(), Vector3(-95.0, 14.0, 105.0)).looking_at(Vector3(0, 9.0, -6.0), Vector3.UP)
		cam.transform = shoot_cam(x, t)
	return 37.0


# ---------------------------------------------------------------- wreck

func _scene_wreck() -> float:
	lay_track()
	var g := gun()
	var w := gun(true)
	var hit := 2.5
	w.visible = false
	g.set_outriggers(1.0)
	g.aim(0.0, 0.55)
	w.set_outriggers(1.0)
	w.aim(0.14, 0.12)
	w.body.rotation = Vector3(0.03, 0.0, 0.07)
	w.body.position = Vector3(0.2, -0.1, 0)
	var tip := g.barrel_tip
	var tip_from := Transform3D()
	updates.append(func(t: float) -> void:
		g.visible = t < hit + 0.05
		w.visible = t >= hit + 0.05)
	# The barrel's front half thrown off, tumbling, landing ahead and left.
	var tip_mi := MeshInstance3D.new()
	tip_mi.mesh = (tip.get_child(0) as MeshInstance3D).mesh
	stage.add_child(tip_mi)
	tip_mi.visible = false
	updates.append(func(t: float) -> void:
		if t < hit:
			tip.visible = true
			tip_mi.visible = false
			return
		tip.visible = false
		tip_mi.visible = true
		if tip_from == Transform3D():
			tip_from = tip.global_transform
		var u_land := (9.0 + sqrt(81.0 + 2.0 * 9.8 * maxf(tip_from.origin.y - 0.4, 0.0))) / 9.8
		var u := minf(t - hit, u_land)
		var landed := t - hit >= u_land
		var p := tip_from.origin + Vector3(-3.0, 9.0, -2.0) * u + Vector3(0, -0.5 * 9.8 * u * u, 0)
		if landed:
			p.y = 0.4
		var spin := Basis(Vector3(1, 0, 0.3).normalized(), u * 2.4) if not landed else Basis(Vector3(0.2, 1, 0).normalized(), 0.9) * Basis(Vector3.RIGHT, 0.08)
		tip_mi.global_transform = Transform3D(tip_from.basis * spin if not landed else spin, p))
	# The hit: flash, fire, smoke and dust; then the wreck burns.
	var fl := func(t: float) -> Variant:
		return Transform3D(Basis().scaled(Vector3.ONE * (1.0 + 8.0 * (t - hit))), Vector3(0.3, 3.0, 0.5)) if t >= hit and t < hit + 0.15 else null
	glow(1.8, fl, 14.0)
	later(hit, func(_t: float) -> void:
		for k in 40:
			glow_p.add("flame", Vector3(0.3, 2.6, 0.5) + glow_p.jitter(1.5), glow_p.jitter(9.0) + Vector3(0, 7.0, 0), 2.5)
		for k in 40:
			smoke_p.add("burn", Vector3(0.3, 2.5, 0.5) + smoke_p.jitter(2.0), smoke_p.jitter(6.0) + Vector3(0, 5.0, 0), 3.0)
		for k in 30:
			var ang := TAU * k / 30.0
			smoke_p.add("dust", Vector3(cos(ang) * 2.0, 0.4, sin(ang) * 4.0), Vector3(cos(ang), 0.2, sin(ang)) * 11.0, 2.5))
	var fires := [Vector3(0.4, 3.2, 0.8), Vector3(-0.6, 2.5, 5.5), Vector3(0.5, 2.2, -4.0), Vector3(0.0, 2.6, 3.4)]
	for f in int(14.0 * FPS):
		var t := hit + 0.3 + float(f) / FPS
		if f % 2 == 0:
			later(t, func(_t: float) -> void:
				var at: Vector3 = fires[f % fires.size()]
				glow_p.add("flame", at + glow_p.jitter(0.4), Vector3(0, 2.0, 0), 1.3)
				if f % 4 == 0:
					smoke_p.add("burn", at + Vector3(0, 0.8, 0), Vector3(0, 3.0, 0), 1.6))
	# Debris chunks.
	for i in 10:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized() * randf_range(7.0, 15.0)
		var sz := Vector3(randf_range(0.15, 0.5), randf_range(0.05, 0.2), randf_range(0.2, 0.7))
		var dg := TrainGeo.new()
		dg.box(Vector3.ZERO, sz, SiegeGun.OLIVE_DARK.darkened(0.5))
		var fly := func(t: float) -> Transform3D:
			if t < hit:
				return HIDE
			var u := t - hit
			var p := Vector3(0.3, 2.6, 0.5) + dir * u + Vector3(0, -4.9 * u * u, 0)
			if p.y < sz.y:
				var u0 := (dir.y + sqrt(dir.y * dir.y + 4.0 * 4.9 * 2.6)) / 9.8
				p = Vector3(0.3, 2.6, 0.5) + dir * u0 + Vector3(0, -4.9 * u0 * u0, 0)
				p.y = sz.y
				return Transform3D(Basis(Vector3.UP, float(i)), p)
			return Transform3D(Basis(dir.normalized().cross(Vector3.UP).normalized(), u * 8.0), p)
		prop(km_t(dg), [at_world(fly, 0.0)])
	# Three of the crew near the gun are knocked down.
	var free := stand_free()
	var spots := [Vector3(-3.0, 0, 2.5), Vector3(2.8, 0, -1.5), Vector3(-2.2, 0, 7.5)]
	for i in 3:
		var a := man(501 + i, "gunner", spots[i], PI * 0.3 * float(i - 1))
		pose(a, 0.0, 0.0, stand_free(), null, null)

		clip(a, hit + 0.05 + 0.08 * i, Body.death_back(free, C.carry("free")) if i != 1 else Body.death_forward(free, C.carry("free")))
	_phases = [[0.0, "Wreck: a direct hit on the gun"], [hit, "Hit"], [hit + 2.0, "Knocked out: barrel broken off, burning"]]
	_camera = func(t: float) -> void:
		cam.fov = 48.0
		var x := Transform3D(Basis(), Vector3(-16.0, 7.0, 16.0)).looking_at(Vector3(0, 2.0, 0), Vector3.UP)
		cam.transform = shoot_cam(x, t)
	shake_fn = func(t: float) -> Vector3:
		var u := t - hit
		if u >= 0.0 and u < 1.4:
			return Vector3(sin(t * 91.0), sin(t * 77.0 + 1.0), sin(t * 63.0)) * 0.35 * (1.0 - u / 1.4)
		return Vector3.ZERO
	return hit + 11.0


func km_t(g: TrainGeo) -> Mesh:
	return g.to_mesh(TrainParts.material())
