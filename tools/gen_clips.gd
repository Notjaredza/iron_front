extends "res://tools/mg_clips.gd"
## The General's moves, recorded as video frames (Asset Builder Chat, 2026-11-10).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/gen_clips.gd -- [scene ...]
## Scenes: inspect, speech, powers, wounded, car. Frames go to results/units/anim_frames/gen_<scene>/.
## The world, timelines and prop keys are the MG tool's; this adds the General, his guards,
## carried / riding positions and the flare.

const G := preload("res://scripts/units/general/clips_general.gd")
const O := preload("res://scripts/units/anim/clips_officer.gd")
const S := preload("res://scripts/units/anim/clips_signal.gd")
const GEN_SCENES: Array[String] = ["inspect", "speech", "powers", "wounded", "car"]

var glows: Array = []  # {node, fn: Callable(t) -> Variant (Vector3 or null)}
var glow_mat: StandardMaterial3D


func _run() -> void:
	prefix = "gen_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.35, 0.25)
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else GEN_SCENES):
		await _record(sc)
	print("GEN CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	glows.clear()
	flash.visible = false


func _gen() -> Dictionary:
	var s := GeneralKit.general(0)
	stage.add_child(s)
	var a := {"s": s, "segs": [], "pos": Vector3.ZERO, "yaw": 0.0}
	actors.append(a)
	return a


func _guard(seed_value: int, at: Vector3, yaw := 0.0) -> Dictionary:
	var s := GeneralKit.guard(seed_value)
	stage.add_child(s)
	var a := {"s": s, "segs": [], "pos": at, "yaw": yaw}
	actors.append(a)
	return a


## Actors with a "pos_fn" [t0, Callable(t) -> Vector3] ride on it from t0 (carried, in the car).
## Actors with a "lying" t0 are posed lying (not grounded) from then on.
func _eval_actor(a: Dictionary, t: float) -> void:
	super._eval_actor(a, t)
	if a.has("pos_fn") and t >= float(a["pos_fn"][0]):
		var s: Soldier = a["s"]
		s.position = (a["pos_fn"][1] as Callable).call(t)


func _look(from: Vector3, at: Vector3, fov := 40.0) -> void:
	cam.fov = fov
	cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.UP)


func _effects(t: float) -> void:
	super._effects(t)
	for g: Dictionary in glows:
		var p: Variant = (g["fn"] as Callable).call(t)
		var n: Node3D = g["node"]
		n.visible = p != null
		if p != null:
			n.position = p


func _glow(fn: Callable, r: float, light := 0.0) -> void:
	var m := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.0
	sp.material = glow_mat
	m.mesh = sp
	stage.add_child(m)
	if light > 0.0:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.4, 0.3)
		l.light_energy = light
		l.omni_range = 30.0
		m.add_child(l)
	glows.append({"node": m, "fn": fn})


func _bone_world(a: Dictionary, bone: int, local := Vector3.ZERO) -> Vector3:
	var s: Soldier = a["s"]
	return s.global_transform * (s.skel.get_bone_global_pose(bone) * local)


# ---------------------------------------------------------------- scenes

## The parade walk with the escort, then he stops and inspects, and takes a salute.
func _scene_inspect() -> float:
	var g := _gen()
	g["pos"] = Vector3(0, 0, 4.0)
	var offs := [Vector3(-1.7, 0, -1.6), Vector3(1.7, 0, -1.6), Vector3(-1.7, 0, 1.7), Vector3(1.7, 0, 1.7)]
	var guards: Array = []
	for i in 4:
		guards.append(_guard(400 + i, g["pos"] + offs[i]))
	var t_stop := move(g, 0.0, Vector3(0, 0, -2.0), G.gait())
	for i in 4:
		var gd: Dictionary = guards[i]
		move(gd, 0.0, Vector3(0, 0, -2.0) + offs[i], G.guard_gait_port(), null, 0.5 * float(i % 2))
		pose(gd, t_stop, 0.5, G.guard_stand(), null, null)
	pose(g, t_stop, 0.6, G.inspect(0.0), null, null)
	pose(g, t_stop + 1.0, 0.9, G.inspect(35.0, 6.0))
	pose(g, t_stop + 2.4, 1.2, G.inspect(-35.0, 6.0))
	pose(g, t_stop + 4.0, 0.6, G.stand())
	pose(g, t_stop + 4.8, 0.45, G.salute())
	pose(g, t_stop + 6.6, 0.5, G.stand())
	_phases = [[0.0, "The General: parade walk, the escort at port arms"], [t_stop, "Inspecting: hands behind the back"],
		[t_stop + 4.8, "Taking the salute"]]
	_camera = func(t: float) -> void:
		var z := maxf(4.0 - t * 1.1, -2.0)
		_look(Vector3(6.2, 2.4, z - 0.6), Vector3(0, 1.1, z), 44)
	return t_stop + 7.6


## The speech at the podium: fists on the lectern, pounding, pointing, the sweep, the raised fist.
func _scene_speech() -> float:
	prop(GeneralKit.podium().to_mesh(Soldier.material()), [[0.0, 0.0, "world", Transform3D()]])
	var g := _gen()
	var at := Vector3(0, 0.5, 0)
	pose(g, 0.0, 0.0, G.speech_fists(), null, null, "smooth", at)
	pose(g, 1.2, 0.35, G.speech_pound(0.0))
	for k in 3:
		pose(g, 1.7 + 0.6 * float(k), 0.18, G.speech_pound(1.0), null, "prev", "in")
		pose(g, 1.88 + 0.6 * float(k), 0.4, G.speech_pound(0.0))
	pose(g, 3.8, 0.5, G.speech_point(-25.0))
	pose(g, 4.9, 0.9, G.speech_point(25.0, 0.1))
	pose(g, 6.2, 0.4, G.rally_sweep(0.0))
	pose(g, 6.7, 1.3, G.rally_sweep(1.0))
	pose(g, 8.2, 0.45, G.rally_fist(0.3))
	pose(g, 8.65, 0.3, G.rally_fist(1.0))
	pose(g, 10.2, 0.6, G.speech_fists())
	for i in 2:
		var gd := _guard(410 + i, Vector3(-1.1 + 2.2 * float(i), 0.5, 0.6))
		pose(gd, 0.0, 0.0, G.guard_stand(), null, null)
	_phases = [[0.0, "The speech: fists on the lectern"], [1.2, "Pounding the lectern"], [3.8, "Pointing out over the crowd"],
		[6.2, "The arm sweep"], [8.2, "The raised fist"]]
	_camera = func(t: float) -> void:
		var a := lerpf(-0.35, 0.25, t / 11.0)
		_look(Vector3(sin(a) * 5.0, 1.9, -cos(a) * 5.0), Vector3(0, 1.75, 0.2), 38)
	return 11.2


## The powers: rally aura, call in fire (flare, then barking at the signaller), no retreat.
func _scene_powers() -> float:
	var g := _gen()
	pose(g, 0.0, 0.0, G.stand(), null, null)
	# Rally aura.
	pose(g, 0.6, 0.4, G.rally_sweep(0.0))
	pose(g, 1.0, 1.2, G.rally_sweep(1.0))
	pose(g, 2.4, 0.45, G.rally_fist(1.0))
	pose(g, 3.6, 0.5, G.stand())
	# Flare: up, fire, the flare climbs and hangs.
	pose(g, 4.3, 0.6, G.flare_up(1.0))
	pose(g, 6.9, 0.6, G.stand())
	var keys: Array = [[0.0, 0.0, "world", Transform3D(Basis(), Vector3(0, -20, 0))],
		[4.3, 0.0, "bone", [g, B.HAND_R, Transform3D(Basis(), Vector3(0, -0.07, -0.01))]],
		[7.0, 0.0, "world", Transform3D(Basis(), Vector3(0, -20, 0))]]
	prop(GeneralKit.flare_pistol().to_mesh(Soldier.material()), keys)
	var t_fire := 5.1
	var start := Vector3(0.3, 2.1, -0.5)
	_glow(func(t: float) -> Variant:
		if t < t_fire or t > 6.9:
			return null
		var u := t - t_fire
		return start + Vector3(-0.4 * u, 8.0 * u - 2.5 * u * u, -2.0 * u),  0.2, 8.0)
	for k in 6:
		var lag := 0.05 * float(k + 1)
		_glow(func(t: float) -> Variant:
			var u := t - t_fire - lag
			if u < 0.0 or t > 6.9:
				return null
			return start + Vector3(-0.4 * u, 8.0 * u - 2.5 * u * u, -2.0 * u), 0.13 - 0.017 * float(k))
	# Bark at the signaller.
	var sg := _man(42, "signaller")
	sg["pos"] = Vector3(-1.8, 0, -1.4)
	sg["yaw"] = PI * 0.5
	pose(sg, 0.0, 0.0, S.on_phone(), null, null)
	pose(sg, 8.9, 0.3, S.on_phone(1.0))
	pose(sg, 9.3, 0.3, S.on_phone(0.0))
	pose(g, 7.6, 0.5, G.bark(Vector3(-4.0, 1.2, -3.0)), null, "prev", "smooth", null, 0.5)
	pose(g, 8.6, 0.4, G.bark_stick(0.0))
	pose(g, 9.0, 0.2, G.bark_stick(1.0), null, "prev", "in")
	pose(g, 9.2, 0.35, G.bark_stick(0.0))
	pose(g, 9.55, 0.2, G.bark_stick(1.0), null, "prev", "in")
	pose(g, 10.3, 0.5, G.stand(), null, "prev", "smooth", null, 0.0)
	# No retreat.
	pose(g, 11.0, 0.6, G.no_retreat())
	pose(g, 13.2, 0.5, G.stand())
	_phases = [[0.0, "Rally aura: the sweep and the raised fist"], [4.3, "Call in fire: the flare"],
		[7.6, "Call in fire: barking the order at the nearest signaller"], [11.0, "No retreat: planted, the stick at the ground he holds"]]
	_camera = func(t: float) -> void:
		if t < 4.3:
			_look(Vector3(1.4, 1.6, -3.6), Vector3(0, 1.3, 0), 40)
		elif t < 7.4:
			_look(Vector3(4.0, 1.4, -8.5), Vector3(-0.6, 4.2, -2.5), 60)
		elif t < 10.8:
			_look(Vector3(1.6, 1.8, -4.2), Vector3(-0.9, 1.0, -0.6), 44)
		else:
			_look(Vector3(-1.4, 1.5, -3.4), Vector3(0, 1.1, 0), 40)
	return 14.0


## Wounded: hit, down, two guards lift him and carry him off to the HQ sick bay.
func _scene_wounded() -> float:
	var g := _gen()
	pose(g, 0.0, 0.0, G.inspect(), null, null)
	pose(g, 1.0, 0.22, G.hurt(), null, "prev", "out")
	pose(g, 1.5, 0.8, G.lying(), null, "prev", "in")
	var front := _guard(420, Vector3(-1.4, 0, -1.0))
	var rear := _guard(421, Vector3(1.4, 0, 0.6))
	for gd: Dictionary in [front, rear]:
		pose(gd, 0.0, 0.0, G.guard_stand(), null, null)
	var t_a := move(front, 1.8, Vector3(0, 0, -1.25), G.guard_gait_port(), 0.0)
	move(rear, 1.8, Vector3(0, 0, 1.05), G.guard_gait_port(), 0.0)
	var t_s := t_a + 0.2
	# Stoop to him, hands on his legs (front) and under his shoulders (rear).
	var legs := func(_t: float) -> Dictionary:
		return {"hand_r": _bone_world(g, B.SHIN_R, Vector3(0, -0.05, 0)), "hand_l": _bone_world(g, B.SHIN_L, Vector3(0, -0.05, 0))}
	var arms := func(_t: float) -> Dictionary:
		return {"hand_r": _bone_world(g, B.UARM_R, Vector3(0, -0.05, 0)), "hand_l": _bone_world(g, B.UARM_L, Vector3(0, -0.05, 0))}
	pose(front, t_s, 0.6, G.guard_stoop(), legs)
	pose(rear, t_s, 0.6, G.guard_stoop(), arms)
	var t_l := t_s + 1.0
	pose(front, t_l, 0.9, G.guard_carry(1.0), null)
	pose(rear, t_l, 0.9, G.guard_carry(-1.0), null)
	var t_w := t_l + 1.1
	var dist := 6.0
	var t_e := move(front, t_w, Vector3(0, 0, -1.25 - dist), G.guard_gait_carry(1.0))
	move(rear, t_w, Vector3(0, 0, 1.05 - dist), G.guard_gait_carry(-1.0), null, 0.5)
	var v := dist / (t_e - t_w)
	g["pos_fn"] = [t_l, func(t: float) -> Vector3:
		var up := Anim.ease_of(clampf((t - t_l) / 0.9, 0.0, 1.0), "smooth") * 0.62
		var z := -maxf(t - t_w, 0.0) * v
		return Vector3(0, up + 0.012 * sin(t * 11.0) * float(t > t_w), z)]
	_phases = [[0.0, "Wounded"], [1.8, "Two guards come for him"], [t_l, "Lift"], [t_w, "Carried off to the HQ sick bay (he recovers there, like the officer)"]]
	_camera = func(t: float) -> void:
		var z := -maxf(t - t_w, 0.0) * v
		_look(Vector3(4.2, 2.2, z - 2.2), Vector3(0, 0.8, z - 0.2), 42)
	return t_e + 0.6


## The staff car: driving in with him standing in the back, waving; it stops, he salutes.
func _scene_car() -> float:
	var stop_z := 0.0
	var t_stop := 4.0
	var car_z := func(t: float) -> float:
		# 3 m/s, braking to a stop at t_stop.
		var u := clampf(t / t_stop, 0.0, 1.0)
		return stop_z + 6.0 * (1.0 - u) * (1.0 - u)
	prop(GeneralKit.car().to_mesh(Soldier.material()), [[0.0, 0.0, "world", func(t: float) -> Transform3D:
		return Transform3D(Basis(), Vector3(0, 0, car_z.call(t)))]])
	var g := _gen()
	var sa := GeneralKit.CAR_STAND_AT
	var rail := Vector3(-0.5, 1.4 - sa.y, 0.3 - sa.z)
	pose(g, 0.0, 0.0, G.car_stand(0.0, rail), null, null)
	for k in 3:
		pose(g, 0.4 + 1.0 * float(k), 0.5, G.car_stand(1.0, rail))
		pose(g, 0.9 + 1.0 * float(k), 0.5, G.car_stand(0.0, rail))
	pose(g, t_stop + 0.3, 0.45, Rig.over(G.salute(), {"hand_l": [-1, rail], "pole_l": Vector3(-0.8, -0.4, 0.2)}))
	pose(g, t_stop + 2.4, 0.5, G.car_stand(0.0, rail))
	g["pos_fn"] = [0.0, func(t: float) -> Vector3:
		return sa + Vector3(0, 0, car_z.call(t))]
	# Two guards at the side of the road, presenting.
	for i in 2:
		var gd := _guard(430 + i, Vector3(-2.0, 0, -1.0 + 1.6 * float(i)), -PI * 0.5)
		pose(gd, 0.0, 0.0, G.guard_stand(), null, null)
	_phases = [[0.0, "The staff car: standing in the back, waving"], [t_stop + 0.3, "Taking the salute from the car"]]
	_camera = func(t: float) -> void:
		var z: float = car_z.call(t)
		_look(Vector3(6.0, 2.4, -5.8), Vector3(0, 1.2, 0.4 + z * 0.35), 44)
	return t_stop + 3.2
