extends "res://tools/mg_clips.gd"
## Officer and signaller moves, recorded as video frames (Question Chat, 2026-11-09).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/cmd_clips.gd -- [scene ...]
## Scenes: kit, orders, field, lay, repair, lamp. Frames go to
## results/units/anim_frames/cmd_<scene>/, ffmpeg makes results/units/anim/cmd_<scene>.mp4.
## The world, the timelines (pose / move / clip segments) and the prop keys are the MG
## tool's; this file adds the scenes and their effects (wire, lamp, pistol flashes).

const O := preload("res://scripts/units/anim/clips_officer.gd")
const S := preload("res://scripts/units/anim/clips_signal.gd")
const K := preload("res://scripts/units/kit_builder.gd")
const CMD_SCENES: Array[String] = ["kit", "orders", "field", "lay", "repair", "lamp"]
const HIDE := Transform3D(Basis(), Vector3(0, -20, 0))

var wires: Array = []  # {node, fn: Callable(t) -> PackedVector3Array}
var glows: Array = []  # {node, fn: Callable(t) -> Variant (Transform3D or null)}
var glow_mat: StandardMaterial3D
var cache := {}


func _run() -> void:
	prefix = "cmd_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.93, 0.7)
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else CMD_SCENES):
		await _record(sc)
	print("CMD CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	wires.clear()
	glows.clear()
	cache.clear()
	flash.visible = false


# ---------------------------------------------------------------- helpers

func km(g: UnitGeo) -> Mesh:
	return MG.mesh(g)


func bone_world(a: Dictionary, bone: int) -> Transform3D:
	var s: Soldier = a["s"]
	return s.global_transform * s.skel.get_bone_global_pose(bone)


static func palm_local(hand: int) -> Vector3:
	var fa := B.FARM_R if hand == B.HAND_R else B.FARM_L
	return (B.REST[hand] - B.REST[fa]).normalized() * B.PALM


func palm_world(a: Dictionary, hand: int) -> Vector3:
	return bone_world(a, hand) * palm_local(hand)


## A bone key for a prop placed at a rest model transform (rides on the bone).
static func on_bone(a: Dictionary, bone: int, rest_xf: Transform3D, t: float, blend := 0.0) -> Array:
	return [t, blend, "bone", [a, bone, Transform3D(rest_xf.basis, rest_xf.origin - B.REST[bone])]]


static func at_world(xf: Variant, t: float, blend := 0.0) -> Array:
	return [t, blend, "world", xf]


func wire(fn: Callable) -> void:
	var m := MeshInstance3D.new()
	stage.add_child(m)
	wires.append({"node": m, "fn": fn})


func glow(radius: float, fn: Callable, light := 0.0) -> void:
	var m := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = radius
	sp.height = radius * 2.0
	sp.material = glow_mat
	m.mesh = sp
	stage.add_child(m)
	if light > 0.0:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.85, 0.55)
		l.light_energy = light
		l.omni_range = 3.0
		m.add_child(l)
	glows.append({"node": m, "fn": fn})


func _effects(t: float) -> void:
	for w: Dictionary in wires:
		var pts: PackedVector3Array = (w["fn"] as Callable).call(t)
		(w["node"] as MeshInstance3D).visible = pts.size() >= 2
		if pts.size() >= 2:
			(w["node"] as MeshInstance3D).mesh = km(K.wire(pts))
	for gl: Dictionary in glows:
		var x: Variant = (gl["fn"] as Callable).call(t)
		(gl["node"] as Node3D).visible = x != null
		if x != null:
			(gl["node"] as Node3D).global_transform = x


func _soldier_at(seed_value: int, role: String, pos: Vector3, yaw: float) -> Dictionary:
	var a := _man(seed_value, role)
	a["pos"] = pos
	a["yaw"] = yaw
	return a


# ---------------------------------------------------------------- kit (the models)

## The three men turning slowly, the kit laid out in front.
func _scene_kit() -> float:
	var men := [[_soldier_at(21, "officer", Vector3(-1.1, 0, 0), 0.0), O.stand()],
		[_soldier_at(23, "lineman", Vector3(0.0, 0, 0), 0.0), S.standing("drum")],
		[_soldier_at(25, "signaller", Vector3(1.1, 0, 0), 0.0), S.standing("free")]]
	for m: Array in men:
		var a: Dictionary = m[0]
		for k in 41:
			var tk := 0.25 * k
			pose(a, tk, 0.25, m[1], null, "prev" if k > 0 else null, "lin", null, sin(tk * 0.45) * 1.4)
	var ln: Dictionary = men[1][0]
	prop(km(K.reel()), [on_bone(ln, B.CHEST, Transform3D(Basis(), B.REST[B.CHEST] + S.DRUM_ON_BACK), 0.0)])
	var y0 := 0.0
	var lay := [[km(K.phone(1.0)), Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.9, y0, -1.3))],
		[km(K.handset()), Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.9, 0.16, -1.33))],
		[km(K.lamp()), Transform3D(Basis(Vector3.UP, -0.5), Vector3(0.35, 0.145, -1.25))],
		[km(K.flag()), Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(-0.2, 0.012, -1.0))],
		[km(K.flag()), Transform3D(Basis(Vector3.RIGHT, -PI / 2) * Basis(Vector3.UP, PI), Vector3(-0.15, 0.03, -1.15))],
		[km(K.map_sheet()), Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.9, 0.003, -1.25))],
		[km(K.binoculars()), Transform3D(Basis(Vector3.UP, -0.4), Vector3(-1.35, 0.03, -1.0))],
		[km(K.whistle()), Transform3D(Basis(Vector3.UP, 1.2), Vector3(-1.45, 0.013, -1.35))]]
	for it: Array in lay:
		prop(it[0], [at_world(it[1], 0.0)])
	var crank_xf: Transform3D = lay[0][1] * Transform3D(Basis(), K.CRANK_AXLE)
	prop(km(K.crank()), [at_world(crank_xf, 0.0)])
	wire(func(_t: float) -> PackedVector3Array:
		return MG.sag(Vector3(0.6, 0.008, -1.6), Vector3(-0.6, 0.008, -1.7), -0.0, 6))
	_phases = [[0.0, "Officer, lineman (wire drum), signaller (phone, lamp, flags)"]]
	_camera = func(_t: float) -> void:
		cam.fov = 40.0
		cam.transform = Transform3D(Basis(), Vector3(0.2, 2.0, -4.4)).looking_at(Vector3(0.0, 0.85, -0.3), Vector3.UP)
	return 10.0


# ---------------------------------------------------------------- the officer: orders

func _scene_orders() -> float:
	var of := _soldier_at(21, "officer", Vector3.ZERO, 0.0)
	pose(of, 0.0, 0.0, O.stand(), null, null)
	pose(of, 1.0, 0.4, O.whistle_up(), null, "prev", "smooth")
	pose(of, 2.4, 0.35, O.wave_on(), null, "prev", "out")
	pose(of, 3.6, 0.5, O.stand())
	var target := Vector3(-7.0, 0.5, -24.0)
	pose(of, 4.4, 0.4, O.point_call(target), null, "prev", "out")
	pose(of, 5.9, 0.4, O.point_call(target, false))
	pose(of, 6.5, 0.35, O.hand_signal("halt"), null, "prev", "out")
	pose(of, 7.7, 0.3, O.hand_signal("down", 0.0))
	for k in 4:
		pose(of, 8.1 + 0.36 * k, 0.3, O.hand_signal("down", float((k + 1) % 2)), null, "prev", "out")
	pose(of, 9.8, 0.3, O.hand_signal("follow", 0.0))
	for k in 4:
		pose(of, 10.2 + 0.36 * k, 0.3, O.hand_signal("follow", float((k + 1) % 2)), null, "prev", "out")
	pose(of, 11.8, 0.4, O.stand())
	move(of, 12.3, Vector3(0, 0, -5.0), Body.gait(O.WALK, O.walking()))
	prop(km(K.whistle()), [at_world(HIDE, 0.0),
		on_bone(of, B.HEAD, Transform3D(Basis(Vector3.UP, PI), O.MOUTH + Vector3(0.012, -0.004, -0.004)), 1.25),
		at_world(HIDE, 3.4)])
	# Riflemen kneeling ahead: on the whistle they get up and go.
	var run := Body.gait(Body.RUN, R.carry("port"))
	for i in 4:
		var a := _soldier_at(31 + i, "", Vector3(-1.8 + 1.2 * i, 0, -2.6 - 0.3 * (i % 2)), 0.0)
		pose(a, 0.0, 0.0, R.poses()["kneel"], null, null)
		var tg := 2.7 + 0.13 * i
		pose(a, tg, 0.35, run["keys"][0][1])
		move(a, tg + 0.35, a["pos"] + Vector3(0.3 * (i - 1.5), 0, -22.0), run)
	_phases = [[0.0, "Officer: whistle"], [2.4, "Wave on: the men go"], [4.4, "Pointing out the objective, calling"],
		[6.5, "Hand signal: halt"], [7.7, "Hand signal: down"], [9.8, "Hand signal: follow me"], [12.0, "Moving off"]]
	_camera = func(t: float) -> void:
		cam.fov = 42.0
		var z := minf(0.0, -(t - 12.3) * 1.3) if t > 12.3 else 0.0
		cam.transform = Transform3D(Basis(), Vector3(4.6, 2.2, 1.0 + z)).looking_at(Vector3(-0.5, 0.95, -1.3 + z), Vector3.UP)
	return 15.0


# ---------------------------------------------------------------- the officer: map, binoculars, pistol

func _scene_field() -> float:
	var of := _soldier_at(21, "officer", Vector3.ZERO, 0.0)
	pose(of, 0.0, 0.0, O.stand(), null, null)
	# Map out of the case, read, a look up at the ground, back in.
	pose(of, 0.5, 0.45, O.reach_map_case())
	pose(of, 1.1, 0.6, O.read_map())
	pose(of, 3.4, 0.6, O.map_check(-35.0))
	pose(of, 4.9, 0.5, O.read_map())
	pose(of, 5.7, 0.45, O.reach_map_case())
	pose(of, 6.3, 0.4, O.stand())
	var map_in_hand := Transform3D(Basis(Vector3.RIGHT, PI / 2), B.REST[B.HAND_R] + palm_local(B.HAND_R) + Vector3(0, -0.02, -0.02))
	var map_read := Transform3D(O.MAP_HELD.basis, B.REST[B.CHEST] + O.MAP_HELD.origin)
	prop(km(K.map_sheet()), [at_world(HIDE, 0.0), on_bone(of, B.HAND_R, map_in_hand, 0.9),
		on_bone(of, B.CHEST, map_read, 1.15, 0.5), on_bone(of, B.HAND_R, map_in_hand, 5.75, 0.3), at_world(HIDE, 6.15)])
	# Binoculars out, glassing left and right, away.
	pose(of, 6.8, 0.4, O.reach_binos())
	pose(of, 7.3, 0.55, O.binos(0.0))
	pose(of, 8.2, 1.3, O.binos(-28.0))
	pose(of, 9.8, 1.6, O.binos(24.0, -2.0))
	pose(of, 11.6, 0.6, O.binos(0.0))
	pose(of, 12.4, 0.45, O.reach_binos())
	pose(of, 13.0, 0.35, O.stand())
	var bino_hand := Transform3D(Basis(), B.REST[B.HAND_R] + palm_local(B.HAND_R) + Vector3(-0.04, 0.0, -0.03))
	var bino_eyes := Transform3D(O.BINO_HELD.basis, B.REST[B.HEAD] + O.BINO_HELD.origin)
	prop(km(K.binoculars()), [at_world(HIDE, 0.0), on_bone(of, B.HAND_R, bino_hand, 7.1),
		on_bone(of, B.HEAD, bino_eyes, 7.35, 0.4), on_bone(of, B.HAND_R, bino_hand, 12.5, 0.3), at_world(HIDE, 12.95)])
	# Pistol: draw, three shots, reload, holster.
	pose(of, 13.5, 0.35, O.draw_reach())
	pose(of, 13.95, 0.4, O.aim(), null, "prev", "out")
	var shots := [14.8, 15.4, 15.9]
	for st: float in shots:
		pose(of, st, 0.05, O.aim(true), null, "prev", "out")
		pose(of, st + 0.06, 0.2, O.aim())
	pose(of, 16.5, 0.4, O.pistol_up(null))
	pose(of, 17.1, 0.35, O.pistol_up([B.HIPS, O.MAG_POUCH + Vector3(0, 0.03, -0.02)]))
	var under_grip: Array = [B.HAND_R, B.REST[B.HAND_R] + palm_local(B.HAND_R) + Vector3(0.0, -0.03, 0.09)]
	pose(of, 17.55, 0.4, O.pistol_up(under_grip))
	pose(of, 18.2, 0.4, O.aim(), null, "prev", "smooth")
	pose(of, 19.0, 0.4, O.draw_reach())
	pose(of, 19.6, 0.4, O.stand())
	# The muzzle flash on each shot.
	var muzzle := B.GRIP_R + Vector3(0, 0.055, -0.17)
	var flash_at := func(t: float) -> Variant:
		for st: float in shots:
			if t >= st and t < st + 0.07:
				return Transform3D(Basis(), bone_world(of, B.RIFLE) * muzzle)
		return null
	glow(0.035, flash_at, 1.5)
	# The magazines: the empty one drops out, the new one comes from the pouch.
	var mag_in := Transform3D(Basis(), B.REST[B.RIFLE] + B.GRIP_R + Vector3(0, -0.055, 0.02))
	var drop_t := 16.95
	var falling := func(t: float) -> Transform3D:
		if not cache.has("mag0"):
			cache["mag0"] = bone_world(of, B.RIFLE) * Transform3D(Basis(), mag_in.origin - B.REST[B.RIFLE])
		var x0: Transform3D = cache["mag0"]
		var dt := t - drop_t
		var y := maxf(0.02, x0.origin.y - 4.9 * dt * dt)
		return Transform3D(x0.basis.rotated(Vector3.RIGHT, minf(dt * 3.0, 1.3)), Vector3(x0.origin.x, y, x0.origin.z - 0.1 * dt))
	prop(km(K.magazine()), [on_bone(of, B.RIFLE, mag_in, 0.0), at_world(falling, drop_t)])
	var mag_hand := Transform3D(Basis(), B.REST[B.HAND_L] + palm_local(B.HAND_L) + Vector3(0, 0.03, 0))
	prop(km(K.magazine()), [at_world(HIDE, 0.0), on_bone(of, B.HAND_L, mag_hand, 17.35), on_bone(of, B.RIFLE, mag_in, 17.9, 0.08)])
	_phases = [[0.0, "Officer: map out"], [1.1, "Reading the map"], [3.4, "Checking the ground"], [6.8, "Binoculars"],
		[8.2, "Glassing the front"], [13.5, "Pistol: draw and fire"], [16.5, "Reload"], [18.9, "Holster"]]
	_camera = func(_t: float) -> void:
		cam.fov = 38.0
		cam.transform = Transform3D(Basis(), Vector3(2.0, 1.8, -2.6)).looking_at(Vector3(0.0, 1.2, -0.1), Vector3.UP)
	return 20.4


# ---------------------------------------------------------------- signallers: laying wire, the phone

func _scene_lay() -> float:
	var start := Vector3(-0.5, 0, 4.0)
	var stop := Vector3(-0.6, 0, -4.5)
	var ln := _soldier_at(23, "lineman", start, 0.0)
	var t_l := move(ln, 0.0, stop, Body.gait(S.WALK_DRUM, S.carry("drum")), -PI / 2)
	var phone_at := Transform3D(Basis(Vector3.UP, 0.0), Vector3(0.05, 0, -4.5))
	var term := phone_at * K.TERMINAL
	pose(ln, t_l, 0.5, S.kneel_work(), null)
	pose(ln, 8.7, 0.4, S.kneel_work(), func(t: float) -> Dictionary: return {"hand_r": term + Vector3(-0.03, 0.02, -0.03)})
	pose(ln, 9.6, 0.4, Rig.over(C._kneel_square({}), {"hand_r": null, "hand_l": null}))
	# The drum turns while he walks (the line pays out).
	var walked := func(t: float) -> float: return clampf(t, 0.0, t_l) * 1.25
	var reel_xf := func(t: float) -> Transform3D:
		var ang: float = walked.call(t) / 0.1
		return bone_world(ln, B.CHEST) * Transform3D(Basis(Vector3.RIGHT, ang), S.DRUM_ON_BACK)
	prop(km(K.reel()), [at_world(reel_xf, 0.0)])
	# The signaller beside him with the phone, then down at it: lid, line, crank, talk.
	var sg := _soldier_at(25, "signaller", Vector3(0.7, 0, 4.4), 0.0)
	var kneel_at := Vector3(0.12, 0, -3.9)
	var t_s := move(sg, 0.0, kneel_at, Body.gait(Body.WALK, S.carry("phone")), 0.0)
	var put := func(_t: float) -> Dictionary:
		return {"hand_r": phone_at * Vector3(0.0, 0.16, 0.02), "hand_l": phone_at * Vector3(-0.12, 0.12, 0.0)}
	pose(sg, t_s, 0.6, S.kneel_work(), put)
	var catch_pt := func(t: float) -> Vector3:
		var o := clampf((t - 8.6) / 0.6, 0.0, 1.0)
		return phone_at * (K.LID_HINGE + Basis(Vector3.RIGHT, -1.9 * o) * Vector3(0, 0.014, -0.18))
	pose(sg, 8.2, 0.35, S.kneel_work(), func(t: float) -> Dictionary:
		return {"hand_r": catch_pt.call(t) + Vector3(0, 0.02, -0.02), "hand_l": phone_at * Vector3(-0.12, 0.12, 0.0)})
	var hs_rest := phone_at * Transform3D(Basis(), K.HANDSET_REST)
	pose(sg, 9.6, 0.35, S.kneel_work(), func(_t: float) -> Dictionary:
		return {"hand_l": hs_rest.origin + Vector3(0, 0.02, 0), "hand_r": phone_at * Vector3(0.1, 0.1, 0.05)})
	pose(sg, 10.1, 0.5, S.on_phone(), func(_t: float) -> Dictionary: return {"hand_r": phone_at * Vector3(0.1, 0.1, 0.05)})
	var crank_ang := func(t: float) -> float: return clampf(t - 10.8, 0.0, 1.4) * TAU * 2.0
	var crank_xf := func(t: float) -> Transform3D:
		return phone_at * Transform3D(Basis(Vector3.RIGHT, crank_ang.call(t)), K.CRANK_AXLE)
	var on_crank := func(t: float) -> Dictionary:
		return {"hand_r": (crank_xf.call(t) as Transform3D) * Vector3(0.07, 0.0, 0.06)}
	pose(sg, 10.6, 0.3, S.on_phone(), on_crank)
	pose(sg, 12.3, 0.4, S.on_phone(), func(_t: float) -> Dictionary: return {"hand_r": phone_at * Vector3(0.1, 0.1, 0.05)})
	for k in 4:
		pose(sg, 12.9 + 0.55 * k, 0.4, S.on_phone(float((k + 1) % 2)), null, "prev", "smooth")
	pose(sg, 15.2, 0.4, S.on_phone(0.0))
	var phone_hand := Transform3D(Basis(Vector3.UP, PI / 2), B.REST[B.HAND_R] + palm_local(B.HAND_R) + Vector3(0, -0.165, 0))
	prop(km(K.phone()), [on_bone(sg, B.HAND_R, phone_hand, 0.0), at_world(phone_at, t_s + 0.3, 0.3)],
		func(t: float) -> Variant:
			var o := snappedf(clampf((t - 8.6) / 0.6, 0.0, 1.0), 0.1)
			var key := "phone%.1f" % o
			if not cache.has(key):
				cache[key] = km(K.phone(o))
			return cache[key])
	prop(km(K.crank()), [at_world(crank_xf, 0.0)])
	# Handset: in the box under the lid, then to the ear.
	prop(km(K.handset()), [at_world(HIDE, 0.0), at_world(hs_rest, 9.2), on_bone(sg, B.HEAD,
		Transform3D(S.handset_at_ear().basis, S.handset_at_ear().origin + B.REST[B.HEAD]), 9.95, 0.5)])
	# The line: from the end left at the start, along the ground behind him, up to the drum.
	var path := PackedVector3Array([start + Vector3(0.0, 0.008, 0.6)])
	wire(func(t: float) -> PackedVector3Array:
		var pts := PackedVector3Array(path)
		var reel_bottom := bone_world(ln, B.CHEST) * (S.DRUM_ON_BACK + Vector3(0, -0.09, 0.0))
		var heel: Vector3 = (ln["s"] as Soldier).global_transform * Vector3(0, 0.008, 0.35)
		heel.y = 0.008
		if t < t_l and heel.distance_to(path[path.size() - 1]) > 0.25:
			path.append(heel)
			pts.append(heel)
		elif t >= t_l:
			pts.append(heel)
		if t < 8.9:
			pts.append(reel_bottom if t < 8.7 else palm_world(ln, B.HAND_R))
		elif t < 9.4:
			pts.append(palm_world(ln, B.HAND_R))
		else:
			pts.append(term + Vector3(0, -0.06, -0.02))
			pts.append(term)
		return pts)
	# The handset cord.
	wire(func(t: float) -> PackedVector3Array:
		if t < 9.2:
			return PackedVector3Array()
		return MG.sag(phone_at * K.CORD_OUT, bone_world(sg, B.HEAD) * (S.handset_at_ear() * K.MOUTH), 0.12, 6))
	_phases = [[0.0, "Lineman laying wire off the drum"], [7.6, "Phone down"], [8.2, "Lid open, line clipped on"],
		[9.6, "Handset up"], [10.8, "Cranking (ringing the far end)"], [12.6, "Talking"]]
	_camera = func(t: float) -> void:
		cam.fov = 42.0
		var z: float = (ln["s"] as Soldier).position.z
		var a := Transform3D(Basis(), Vector3(-4.2, 2.6, z + 1.2)).looking_at(Vector3(0.0, 0.7, z - 1.0), Vector3.UP)
		var b := Transform3D(Basis(), Vector3(1.7, 1.55, -6.3)).looking_at(Vector3(-0.15, 0.45, -4.2), Vector3.UP)
		cam.transform = a.interpolate_with(b, Anim.ease_of(clampf((t - 6.6) / 1.4, 0.0, 1.0), "smooth"))
	return 16.0


# ---------------------------------------------------------------- signallers: repairing a cut line

func _scene_repair() -> float:
	var end_a := Vector3(0.0, 0.008, 0.25)
	var end_b := Vector3(0.18, 0.008, -0.32)
	var join := Vector3(0.06, 0.008, -0.02)
	# A shell scar where the line was cut.
	var scar := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.7
	cy.bottom_radius = 0.75
	cy.height = 0.02
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.32, 0.28, 0.22)
	cy.material = sm
	scar.mesh = cy
	scar.position = Vector3(-0.5, 0.0, -0.4)
	stage.add_child(scar)
	var ln := _soldier_at(23, "lineman", Vector3(0.5, 0, 5.0), 0.0)
	var t_w := move(ln, 0.0, Vector3(0.5, 0, 0.0), Body.gait(Body.WALK, S.carry("drum")), PI / 2)
	pose(ln, t_w, 0.5, S.kneel_work())
	var grab := 4.6
	pose(ln, grab - 0.3, 0.35, S.kneel_work(), func(_t: float) -> Dictionary:
		return {"hand_r": end_a + Vector3(0.0, 0.03, 0.0)})
	pose(ln, 4.9, 0.35, S.kneel_work(), func(_t: float) -> Dictionary:
		return {"hand_r": Vector3(0.18, 0.25, 0.1), "hand_l": end_b + Vector3(0.0, 0.03, 0.0)})
	var mid := Vector3(0.14, 0.42, -0.02)
	var twist := func(t: float) -> Dictionary:
		var u := clampf(t - 5.8, 0.0, 1.6) * TAU * 1.6
		return {"hand_r": mid + Vector3(0.0, 0.03 * cos(u), 0.04 + 0.03 * sin(u)),
			"hand_l": mid + Vector3(0.0, -0.03 * cos(u), -0.04 - 0.03 * sin(u))}
	pose(ln, 5.4, 0.4, S.kneel_work(-6.0), twist)
	pose(ln, 7.6, 0.45, S.kneel_work(), func(_t: float) -> Dictionary:
		return {"hand_r": join + Vector3(0.0, 0.03, 0.03), "hand_l": join + Vector3(0.0, 0.03, -0.05)})
	pose(ln, 8.3, 0.4, Rig.over(C._kneel_square({}), {"hand_r": null, "hand_l": null}))
	pose(ln, 10.0, 0.5, S.standing("drum"))
	ln["pos"] = Vector3(0.5, 0, 0.0)
	move(ln, 10.8, Vector3(0.6, 0, 6.0), Body.gait(Body.WALK, S.carry("drum")))
	prop(km(K.reel(0.6)), [on_bone(ln, B.CHEST, Transform3D(Basis(), B.REST[B.CHEST] + S.DRUM_ON_BACK), 0.0)])
	var end_r := func(t: float) -> Vector3:
		if t < grab:
			return end_a
		if t < 7.9:
			return palm_world(ln, B.HAND_R)
		return join
	var end_l := func(t: float) -> Vector3:
		if t < 5.1:
			return end_b
		if t < 7.9:
			return palm_world(ln, B.HAND_L)
		return join
	wire(func(t: float) -> PackedVector3Array:
		var e: Vector3 = end_r.call(t)
		var near := Vector3(0.0, 0.008, 1.0)
		return PackedVector3Array([Vector3(0.0, 0.008, 8.0), Vector3(0.0, 0.008, 2.6), near, near.lerp(e, 0.5) + Vector3(0, 0.0, 0), e]))
	wire(func(t: float) -> PackedVector3Array:
		var e: Vector3 = end_l.call(t)
		var near := Vector3(0.25, 0.008, -1.0)
		return PackedVector3Array([e, near.lerp(e, 0.5), near, Vector3(0.1, 0.008, -8.0)]))
	# The signaller at the phone on the line behind him: listening, then the call goes through.
	var sg := _soldier_at(25, "signaller", Vector3(-0.85, 0, 3.0), PI / 2)
	var phone_at := Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-1.4, 0, 2.95))
	var rest_hand := phone_at * Vector3(0.1, 0.1, 0.05)
	var rest_r := {"hand_r": rest_hand}
	pose(sg, 0.0, 0.0, S.on_phone(), rest_r, null)
	var crank_ang := func(t: float) -> float: return clampf(t - 8.8, 0.0, 1.2) * TAU * 2.0
	var crank_xf := func(t: float) -> Transform3D:
		return phone_at * Transform3D(Basis(Vector3.RIGHT, crank_ang.call(t)), K.CRANK_AXLE)
	pose(sg, 8.6, 0.3, S.on_phone(), func(t: float) -> Dictionary:
		return {"hand_r": (crank_xf.call(t) as Transform3D) * Vector3(0.07, 0.0, 0.06)})
	pose(sg, 10.1, 0.4, S.on_phone(), func(_t: float) -> Dictionary: return {"hand_r": rest_hand})
	for k in 4:
		pose(sg, 10.6 + 0.5 * k, 0.4, S.on_phone(float((k + 1) % 2)), func(_t: float) -> Dictionary: return {"hand_r": rest_hand})
	prop(km(K.phone(1.0)), [at_world(phone_at, 0.0)])
	prop(km(K.crank()), [at_world(crank_xf, 0.0)])
	prop(km(K.handset()), [on_bone(sg, B.HEAD, Transform3D(S.handset_at_ear().basis, S.handset_at_ear().origin + B.REST[B.HEAD]), 0.0)])
	wire(func(_t: float) -> PackedVector3Array:
		return MG.sag(phone_at * K.CORD_OUT, bone_world(sg, B.HEAD) * (S.handset_at_ear() * K.MOUTH), 0.12, 6))
	wire(func(_t: float) -> PackedVector3Array:
		return PackedVector3Array([phone_at * K.TERMINAL, phone_at * K.TERMINAL + Vector3(0, -0.11, 0), Vector3(0.0, 0.008, 2.95)]))
	_phases = [[0.0, "Line cut by a shell: the lineman walks the wire"], [4.3, "Picking up the ends"], [5.4, "Splicing"],
		[7.6, "Laid back down"], [8.6, "Test call: the line is through"], [10.8, "Back to the drum"]]
	_camera = func(_t: float) -> void:
		cam.fov = 46.0
		cam.transform = Transform3D(Basis(), Vector3(2.6, 1.9, -1.9)).looking_at(Vector3(-0.2, 0.35, 0.9), Vector3.UP)
	return 13.0


# ---------------------------------------------------------------- signallers: lamp and flags

## Morse for "IRON FRONT" style traffic: dots and dashes from t0 (seconds of light on).
static func morse_on(t: float, t0: float) -> bool:
	var seq := ".. .-. --- -. ..-. .-. --- -. -"
	var x := t0
	for ch in seq:
		var d := 0.0
		match ch:
			".":
				d = 0.16
			"-":
				d = 0.48
			" ":
				x += 0.3
				continue
		if t >= x and t < x + d:
			return true
		x += d + 0.14
	return false


func _scene_lamp() -> float:
	var sg := _soldier_at(25, "signaller", Vector3(0.7, 0, 0.0), 0.0)
	pose(sg, 0.0, 0.0, S.lamp_aim(), null, null)
	pose(sg, 7.4, 0.6, Rig.over(C._kneel_square({}), {"hand_r": null, "hand_l": null}))
	var lamp_xf := Transform3D(S.LAMP_SIGHTED.basis, S.LAMP_SIGHTED.origin + B.REST[B.HEAD])
	var lamp_low := Transform3D(Basis(), B.REST[B.HAND_R] + palm_local(B.HAND_R))
	prop(km(K.lamp()), [on_bone(sg, B.HEAD, lamp_xf, 0.0), on_bone(sg, B.HAND_R, lamp_low, 7.4, 0.6)])
	var lamp_on := func(t: float) -> Variant:
		if t < 7.3 and morse_on(t, 0.6):
			return bone_world(sg, B.HEAD) * Transform3D(Basis(), lamp_xf.origin - B.REST[B.HEAD] + K.LENS + Vector3(0, 0, -0.03))
		return null
	glow(0.05, lamp_on, 2.5)
	var ln := _soldier_at(23, "lineman", Vector3(-0.9, 0, 0.4), 0.0)
	var seq := [[20.0, 20.0], [45.0, 0.0], [90.0, 0.0], [135.0, 0.0], [0.0, 45.0], [0.0, 90.0], [90.0, 90.0],
		[45.0, 135.0], [180.0, 0.0], [135.0, 45.0], [20.0, 20.0]]
	pose(ln, 0.0, 0.0, S.flags(20.0, 20.0), null, null)
	for k in seq.size():
		var p: Array = seq[k]
		pose(ln, 7.6 + 0.7 * k, 0.28, S.flags(p[0], p[1]), null, "prev", "out")
	# Flags in the hands: the pole runs on along the arm.
	for hb in [B.HAND_R, B.HAND_L]:
		var pl := palm_local(hb)
		var bas := Basis(Vector3.BACK, PI) * Basis(Vector3.UP, 0.0 if hb == B.HAND_R else PI)
		prop(km(K.flag()), [on_bone(ln, hb, Transform3D(bas, B.REST[hb] + pl), 0.0)])
	_phases = [[0.0, "Signal lamp: Morse"], [7.4, "Flags: semaphore"]]
	_camera = func(_t: float) -> void:
		cam.fov = 44.0
		cam.transform = Transform3D(Basis(), Vector3(-1.4, 1.7, -3.6)).looking_at(Vector3(0.0, 1.0, 0.2), Vector3.UP)
	return 15.6
