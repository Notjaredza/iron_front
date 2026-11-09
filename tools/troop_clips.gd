extends "res://tools/lorry_clips.gd"
## The four troop types, recorded as video frames (Question Chat, 2026-11-09).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/troop_clips.gd -- [scene ...]
## Scenes: look, moves, assault, snipers, lmg, mortar. Frames go to
## results/units/anim_frames/troop_<scene>/, ffmpeg makes results/units/anim/troop_<scene>.mp4.
## Timelines, props, wires, glows and smoke are the earlier tools'; this adds timed
## events, per-frame meshes (the LMG bipod legs) and the gun shake for bursts.

const T := preload("res://scripts/units/anim/clips_troops.gd")
const TROOP_SCENES: Array[String] = ["look", "moves", "assault", "snipers", "lmg", "mortar"]
const ROLES: Array[String] = ["assault_nco", "assault", "raider", "sniper", "spotter", "lmg_gunner", "lmg_carrier",
	"mortar_tube", "mortar_plate", "mortar_bombs"]
const ROLE_NAMES: Array[String] = ["NCO", "carbine", "club", "marksman", "spotter", "LMG gunner", "LMG carrier",
	"tube", "baseplate", "bombs"]
const GREY := Color(0.62, 0.62, 0.6)
const DUST := Color(0.72, 0.65, 0.5)

var dyns: Array = []  # {node, fn: Callable(t) -> Mesh or null}
var events: Array = []  # {t, fn, done}
var mcache := {}


func _run() -> void:
	prefix = "troop_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else TROOP_SCENES):
		await _record(sc)
	print("TROOP CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	dyns.clear()
	events.clear()


# ---------------------------------------------------------------- helpers

func cm(key: String, maker: Callable) -> Mesh:
	if not mcache.has(key):
		mcache[key] = km(maker.call())
	return mcache[key]


## A point on the held weapon (rifle frame) in the world.
func wpt(a: Dictionary, v: Vector3) -> Vector3:
	return bone_world(a, B.RIFLE) * v


func later(t: float, fn: Callable) -> void:
	events.append({"t": t, "fn": fn, "done": false})


func dyn(fn: Callable) -> void:
	var m := MeshInstance3D.new()
	stage.add_child(m)
	dyns.append({"node": m, "fn": fn})


static func ramp(t: float, t0: float, d: float) -> float:
	return Anim.ease_of(clampf((t - t0) / d, 0.0, 1.0), "smooth")


## A short flash and a puff of smoke at the muzzle for each shot time.
func shots(a: Dictionary, muzzle: Vector3, times: Array, size := 0.06, dust := false) -> void:
	var fl := func(t: float) -> Variant:
		for ts: float in times:
			if t >= ts and t < ts + 0.05:
				var x := bone_world(a, B.RIFLE)
				return Transform3D(x.basis, x * muzzle)
		return null
	glow(size, fl, 0.8)
	for ts: float in times:
		later(ts, func(t: float) -> void:
			var x := bone_world(a, B.RIFLE)
			var fwd := -x.basis.z.normalized()
			puff(x * muzzle, fwd * 0.6 + Vector3(0, 0.25, 0), 0.05, GREY, 1.2, 2.6, 0.4, t)
			if dust:
				var p := x * muzzle
				for k in 3:
					puff(Vector3(p.x, 0.06, p.z) + fwd * (0.2 + 0.15 * k), Vector3(0.3 * (k - 1), 0.3, 0) + fwd * 0.5, 0.09,
						DUST, 1.5, 2.6, 0.35, t))


## A burst: the gun shakes, flashes every third frame and smokes.
func burst(a: Dictionary, t0: float, d: float, muzzle: Vector3) -> void:
	if not a.has("shake"):
		a["shake"] = []
		var spans: Array = a["shake"]
		var fl := func(t: float) -> Variant:
			for sp: Array in spans:
				if t >= float(sp[0]) and t < float(sp[1]) and frame % 3 == 0:
					var x := bone_world(a, B.RIFLE)
					return Transform3D(x.basis, x * muzzle)
			return null
		glow(0.07, fl, 0.9)
	(a["shake"] as Array).append([t0, t0 + d])
	var k := 0.0
	while k < d:
		later(t0 + k, func(t: float) -> void:
			var x := bone_world(a, B.RIFLE)
			puff(x * muzzle, -x.basis.z.normalized() * 0.4 + Vector3(0.05, 0.3, 0), 0.05, GREY, 1.1, 2.4, 0.35, t))
		k += 0.13


func _eval_actor(a: Dictionary, t: float) -> void:
	super._eval_actor(a, t)
	for sp: Array in a.get("shake", []):
		if t >= float(sp[0]) and t < float(sp[1]):
			var s: Soldier = a["s"]
			s.position += s.global_transform.basis * Vector3(0, 0.004 * (frame % 2), 0.012 * (frame % 3))


func _effects(t: float) -> void:
	for ev: Dictionary in events:
		if not ev["done"] and t >= float(ev["t"]):
			ev["done"] = true
			(ev["fn"] as Callable).call(t)
	super._effects(t)
	for d: Dictionary in dyns:
		var m: Variant = (d["fn"] as Callable).call(t)
		(d["node"] as MeshInstance3D).visible = m != null
		if m != null:
			(d["node"] as MeshInstance3D).mesh = m


func troop(seed_value: int, role: String, pos: Vector3, yaw := 0.0) -> Dictionary:
	var a := _man(seed_value, role)
	a["pos"] = pos
	a["yaw"] = yaw
	a["role"] = role
	return a


func role_stand(role: String) -> Dictionary:
	match role:
		"assault_nco", "mortar_tube":
			return O.stand()
		"raider":
			return Rig.over(Body.body("stand"), T.carry("club"))
	return R.poses()["stand"]


func muzzle_of(role: String) -> Vector3:
	match role:
		"assault":
			return TroopKit.CARBINE_MUZZLE
		"lmg_gunner":
			return TroopKit.LMG_MUZZLE
	return Rig.MUZZLE


## The LMG's drum and bipod for a gunner. fold_fn: t -> 0 folded .. 1 down on the ground.
func lmg_kit(a: Dictionary, fold_fn: Callable) -> MeshInstance3D:
	var drum := prop(cm("drum", TroopKit.drum), [on_bone(a, B.RIFLE,
		Transform3D(Basis(), B.REST[B.RIFLE] + TroopKit.LMG_DRUM), 0.0)])
	dyn(func(t: float) -> Variant:
		var u: float = fold_fn.call(t)
		var x := bone_world(a, B.RIFLE)
		var hinge := x * TroopKit.LMG_HINGE
		var fwd := -x.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var side := Vector3(-fwd.z, 0, fwd.x)
		var feet: Array = []
		for i in 2:
			var s := 1.0 if i == 0 else -1.0
			var folded := x * (TroopKit.LMG_FOLDED[i] as Vector3)
			var down := hinge + fwd * 0.1 + side * 0.13 * s
			down.y = 0.012
			feet.append(folded.lerp(down, u))
		return km(TroopKit.bipod_legs(hinge, feet[0], feet[1])))
	return drum


func palm_xf(hand: int, b := Basis()) -> Transform3D:
	return Transform3D(b, B.REST[hand] + palm_local(hand))


# ---------------------------------------------------------------- look

func _scene_look() -> float:
	var sets: Array = []  # per lod: nodes
	var tris: Array = []
	for lod in 3:
		var nodes: Array = []
		var counts: Array = []
		for i in ROLES.size():
			var role := ROLES[i]
			var x := -4.95 + 1.1 * i
			var s := Soldier.new().setup(301 + i, lod, role)
			stage.add_child(s)
			var a := {"s": s, "segs": [], "pos": Vector3(x, 0, 0), "yaw": 0.0}
			actors.append(a)
			pose(a, 0.0, 0.0, role_stand(role), null, null)
			nodes.append(s)
			counts.append("%s %d" % [ROLE_NAMES[i], s.tri_count()])
			if role == "lmg_gunner":
				nodes.append(lmg_kit(a, func(_t: float) -> float: return 0.0))
				nodes.append(dyns.back()["node"])
			if role == "mortar_tube":
				var pm := MeshInstance3D.new()
				pm.mesh = km(TroopKit.plate(mini(lod, 1)))
				pm.position = Vector3(x + 0.1, 0, -0.75)
				stage.add_child(pm)
				var tm := MeshInstance3D.new()
				tm.mesh = km(TroopKit.tube(1.0, mini(lod, 1)))
				tm.transform = pm.transform * TroopKit.tube_xf()
				stage.add_child(tm)
				nodes.append_array([pm, tm])
			if role == "mortar_bombs":
				for k in 3:
					var bm := MeshInstance3D.new()
					bm.mesh = cm("bomb", TroopKit.bomb)
					bm.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(x - 0.1 + 0.1 * k, 0.03, -0.55))
					stage.add_child(bm)
					nodes.append(bm)
			if role == "raider":
				var gm := MeshInstance3D.new()
				gm.mesh = cm("grenade", TroopKit.grenade)
				gm.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2) * Basis(Vector3.RIGHT, 0.4), Vector3(x + 0.1, 0.035, -0.5))
				stage.add_child(gm)
				nodes.append(gm)
		sets.append(nodes)
		tris.append(counts)
	var names := ["Close", "Mid", "Far"]
	_phases = []
	var starts := [0.0, 11.0, 14.5]
	for lod in 3:
		var line1 := ", ".join((tris[lod] as Array).slice(0, 5))
		var line2 := ", ".join((tris[lod] as Array).slice(5))
		_phases.append([starts[lod], "%s looks, triangles:  %s\n%s" % [names[lod], line1, line2]])
	_camera = func(t: float) -> void:
		var lod := 0 if t < 11.0 else (1 if t < 14.5 else 2)
		for k in 3:
			for n: Node3D in sets[k]:
				n.visible = k == lod
		if lod == 0:
			cam.fov = 40.0
			if t < 5.4:
				var x := lerpf(-5.4, 5.4, ramp(t, 0.2, 5.0))
				cam.transform = Transform3D(Basis(), Vector3(x - 0.5, 1.3, -3.5)).looking_at(Vector3(x, 0.95, 0), Vector3.UP)
			else:
				var u := ramp(t, 5.4, 1.2)
				var x := lerpf(5.4, -5.4, ramp(t, 6.2, 4.6))
				var ang := lerpf(0.0, PI, u)
				var off := Vector3(-0.5 * cos(ang) + 3.5 * sin(ang) * 0.0, 1.3, -3.5 * cos(ang))
				off.x = -0.5 + 3.5 * sin(ang)
				cam.transform = Transform3D(Basis(), Vector3(x, 0, 0) + off).looking_at(Vector3(x, 0.95, 0), Vector3.UP)
		elif lod == 1:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), Vector3(0, 2.6, -9.0)).looking_at(Vector3(0, 0.9, 0), Vector3.UP)
		else:
			cam.fov = 20.0
			cam.transform = Transform3D(Basis(), Vector3(0, 5.0, -24.0)).looking_at(Vector3(0, 0.9, 0), Vector3.UP)
	return 18.0


# ---------------------------------------------------------------- moves (the rifleman's set on the new kit)

func _scene_moves() -> float:
	var lib := R.library()
	var p := R.poses()
	var who := [["assault", -2.4], ["sniper", -0.8], ["lmg_gunner", 0.8], ["mortar_bombs", 2.4]]
	var walk := Body.gait(Body.WALK, R.carry("low"))
	for i in who.size():
		var role: String = who[i][0]
		var a := troop(321 + i, role, Vector3(float(who[i][1]), 0, 4.0))
		var lmg := role == "lmg_gunner"
		if lmg:
			lmg_kit(a, func(_t: float) -> float: return 0.0)
		pose(a, 0.0, 0.0, Body.pose("ready", R.carry("low")), null, null)
		var t := move(a, 0.2, Vector3(float(who[i][1]), 0, 0.0), walk, 0.0)
		pose(a, t, 0.3, p["ready"])
		t += 0.3
		clip(a, t, lib["stand_to_kneel"])
		t += 0.7
		var muzzle := muzzle_of(role)
		if lmg:
			pose(a, t, 0.0, p["kneel"])
			burst(a, t + 0.15, 1.1, muzzle)
		else:
			clip(a, t, lib["fire_kneel"])
			shots(a, muzzle, [t])
		t += 1.45
		clip(a, t, lib["reload_kneel"])
		t += 2.9
		clip(a, t, lib["kneel_to_stand"])
		t += 0.75
		clip(a, t, lib["stand_to_prone"])
		t += 1.25
		if lmg:
			pose(a, t, 0.0, p["prone"])
			burst(a, t + 0.15, 1.1, muzzle)
		else:
			clip(a, t, lib["fire_prone"])
			shots(a, muzzle, [t], 0.06, true)
		t += 1.45
		clip(a, t, lib["prone_to_stand"])
		t += 1.3
		pose(a, t, 0.3, p["aim"])
		t += 0.35 + 0.15 * i
		clip(a, t, lib["death_back"] if i % 2 == 0 else lib["death_forward"])
	_phases = [[0.0, "Moves: carbine, scoped rifle, LMG, rifle with bomb bags (the rifleman's set)"],
		[3.5, "Kneel, fire (the LMG fires a burst), reload"], [8.7, "Up, down to prone, fire"], [13.4, "Hit and fall"]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		var z := lerpf(4.0, 0.0, ramp(t, 0.0, 3.2))
		cam.transform = Transform3D(Basis(), Vector3(-4.2, 2.3, z - 5.6)).looking_at(Vector3(0, 0.6, z), Vector3.UP)
	return 16.5


# ---------------------------------------------------------------- assault

func _scene_assault() -> float:
	var men := [["assault_nco", Vector3(0, 0, 0), "nco"], ["assault", Vector3(-1.6, 0, 0.4), "fire"],
		["assault", Vector3(1.6, 0, 0.3), "fire"], ["assault", Vector3(-3.2, 0, 0.7), "throw"],
		["assault", Vector3(3.2, 0, 0.5), "throw"], ["assault", Vector3(-4.8, 0, 1.0), "fire"],
		["raider", Vector3(-0.8, 0, 1.2), "club"], ["raider", Vector3(0.8, 0, 1.3), "club"]]
	var g_in := {"port": Body.gait(C.CROUCH, R.carry("port")), "club": Body.gait(C.CROUCH, T.carry("club")),
		"pistol": Body.gait(C.CROUCH, T.carry("pistol_low"))}
	var g_out := {"port": Body.gait(Body.RUN, R.carry("port")), "club": Body.gait(Body.RUN, T.carry("club_up")),
		"pistol": Body.gait(Body.RUN, T.carry("pistol_low"))}
	var kneel_aim: Dictionary = R.poses()["kneel"]
	var fire := R.fire("fire_kneel", kneel_aim)
	var t_rush := 7.6
	for i in men.size():
		var role: String = men[i][0]
		var at: Vector3 = men[i][1]
		var job: String = men[i][2]
		var kind := "pistol" if job == "nco" else ("club" if job == "club" else "port")
		var a := troop(341 + i, role, at + Vector3(0, 0, 7.0))
		var c0: Dictionary = T.carry("pistol_low") if kind == "pistol" else (T.carry("club") if kind == "club" else R.carry("port"))
		pose(a, 0.0, 0.0, Body.pose("run", c0), null, null)
		var ta := move(a, 0.05 * (i % 4), at, g_in[kind], 0.0)
		match job:
			"fire":
				pose(a, ta, 0.45, kneel_aim)
				var t1 := ta + 0.7 + 0.25 * (i % 3)
				clip(a, t1, fire)
				clip(a, t1 + 1.9, fire)
				pose(a, t1 + 1.9 + 1.45, 0.0, kneel_aim)
				shots(a, TroopKit.CARBINE_MUZZLE, [t1, t1 + 1.9])
			"throw":
				pose(a, ta, 0.45, kneel_aim)
				var t1 := ta + 0.8 + 0.6 * (i % 2)
				pose(a, t1, 0.45, T.throw_pose("reach"))
				pose(a, t1 + 0.55, 0.4, T.throw_pose("wind"))
				pose(a, t1 + 1.0, 0.14, T.throw_pose("release"), null, "prev", "in")
				pose(a, t1 + 1.14, 0.35, T.throw_pose("follow"), null, "prev", "out")
				pose(a, t1 + 1.9, 0.6, kneel_aim)
				_grenade(a, t1, at + Vector3(at.x * 0.3, 0, -17.0))
			"club":
				pose(a, ta, 0.5, T.club_kneel())
			"nco":
				pose(a, ta, 0.35, O.hand_signal("down", 0.0))
				pose(a, ta + 0.35, 0.3, O.hand_signal("down", 1.0))
				pose(a, ta + 0.8, 0.5, Rig.over(C._kneel_square({}), {"rifle": O.pistol("holster")}))
				pose(a, t_rush - 1.0, 0.4, O.hand_signal("follow", 0.0))
				pose(a, t_rush - 0.6, 0.25, O.hand_signal("follow", 1.0))
				pose(a, t_rush - 0.35, 0.25, O.hand_signal("follow", 0.0))
		# The rush: up and on.
		var tr := t_rush + 0.08 * (i % 3)
		pose(a, tr, 0.3, Body.pose("ready", g_out[kind]["keys"][0][1]))
		move(a, tr + 0.3, at + Vector3(0, 0, -9.0), g_out[kind], 0.0)
	_phases = [[0.0, "Assault section: NCO (pistol), five carbines, two with trench clubs; grenade bags, no packs"],
		[2.4, "Down: carbines fire, two throw grenades, the clubs wait"], [t_rush - 1.0, "The NCO waves them on: the rush"]]
	_camera = func(t: float) -> void:
		cam.fov = 48.0
		var z := lerpf(7.0, 0.0, ramp(t, 0.0, 2.6))
		z = lerpf(z, -8.0, ramp(t, t_rush + 0.2, 3.0))
		var side := lerpf(1.0, 0.0, ramp(t, 2.0, 3.0))
		cam.transform = Transform3D(Basis(), Vector3(6.5 - 2.0 * side, 2.4, z + 4.5 + 1.5 * side)).looking_at(
			Vector3(-0.5, 0.8, z - 2.5), Vector3.UP)
	return t_rush + 3.8


## A stick grenade: out of the bag, thrown on a high arc to land at target, bursting there.
func _grenade(a: Dictionary, t1: float, target: Vector3) -> void:
	var tr := t1 + 1.08
	var tf := 1.25
	var st := {}
	var fly := func(t: float) -> Transform3D:
		if not st.has("p0"):
			st["p0"] = palm_world(a, B.HAND_R)
		var p0: Vector3 = st["p0"]
		var dt := clampf(t - tr, 0.0, tf)
		var vh := Vector3(target.x - p0.x, 0, target.z - p0.z) / tf
		var vy := (0.04 - p0.y + 0.5 * 9.8 * tf * tf) / tf
		var p := p0 + vh * dt + Vector3(0, vy * dt - 0.5 * 9.8 * dt * dt, 0)
		var spin := Basis(Vector3.RIGHT, -dt * 14.0) if dt < tf else Basis(Vector3.FORWARD, PI / 2)
		return Transform3D(spin, p)
	var te := tr + tf + 1.3
	prop(cm("grenade", TroopKit.grenade), [at_world(HIDE, 0.0),
		on_bone(a, B.HAND_R, palm_xf(B.HAND_R, Basis(Vector3.RIGHT, PI)), t1 + 0.4),
		at_world(fly, tr), at_world(HIDE, te)])
	var fl := func(t: float) -> Variant:
		return Transform3D(Basis(), target + Vector3(0, 0.3, 0)) if t >= te and t < te + 0.09 else null
	glow(0.45, fl, 4.0)
	later(te, func(t: float) -> void:
		for k in 7:
			var ang := TAU * k / 7.0
			var d := Vector3(cos(ang), 0, sin(ang))
			puff(target + d * 0.2 + Vector3(0, 0.2, 0), d * 1.6 + Vector3(0, 2.2, 0), 0.3, DUST, 2.4, 1.8, 0.6, t)
		puff(target + Vector3(0, 0.5, 0), Vector3(0, 1.2, 0), 0.45, Color(0.35, 0.33, 0.3), 3.0, 1.5, 0.55, t))


# ---------------------------------------------------------------- snipers

func _scene_snipers() -> float:
	mound(Vector3(0, 0, -2.7), 1.4, 0.16)
	var lib := R.library()
	var gait := Body.gait(C.CROUCH, R.carry("low"))
	var sn := troop(361, "sniper", Vector3(-0.42, 0, 7.0))
	var sp := troop(362, "spotter", Vector3(0.42, 0, 7.4))
	for a: Dictionary in [sn, sp]:
		pose(a, 0.0, 0.0, Body.pose("run", R.carry("low")), null, null)
	var ta := move(sn, 0.0, Vector3(-0.42, 0, 0.0), gait, 0.0)
	var tb := move(sp, 0.0, Vector3(0.42, 0, 0.1), gait, 0.0)
	# The marksman: down, scope, two shots, a reload.
	pose(sn, ta, 0.25, R.poses()["ready"])
	clip(sn, ta + 0.25, lib["stand_to_prone"])
	var aim := T.sniper_aim()
	pose(sn, ta + 1.5, 0.6, aim, null, R.poses()["prone"])
	var s1 := 7.4
	var s2 := 10.2
	clip(sn, s1, R.fire("fire", aim))
	clip(sn, s2, R.fire("fire", aim))
	clip(sn, s2 + 1.6, lib["reload_prone"])
	shots(sn, Rig.MUZZLE, [s1, s2], 0.05, true)
	# The spotter: down, binoculars out of the case, glassing, pointing, glassing.
	pose(sp, tb, 0.25, R.poses()["ready"])
	clip(sp, tb + 0.25, lib["stand_to_prone"])
	var tp := tb + 1.5
	pose(sp, tp, 0.5, T.prone_free(), null, R.poses()["prone"])
	pose(sp, tp + 0.6, 0.45, Rig.over(T.prone_free(), {"hand_r": [B.HIPS, O.BINO_CASE + Vector3(0.02, 0.04, -0.03)],
		"pole_r": Vector3(0.6, -0.7, 0.2)}))
	pose(sp, tp + 1.2, 0.6, T.prone_binos(0.0))
	pose(sp, 5.4, 0.5, T.prone_binos(-8.0))
	pose(sp, 6.0, 0.45, T.prone_point(Vector3(-0.15, 0.08, -1.0)))
	pose(sp, 6.8, 0.45, T.prone_binos(-4.0))
	pose(sp, s2 + 0.6, 0.6, T.prone_binos(6.0))
	var held := Transform3D(O.BINO_HELD.basis, B.REST[B.HEAD] + O.BINO_HELD.origin)
	prop(cm("binos", K.binoculars), [at_world(HIDE, 0.0),
		on_bone(sp, B.HAND_R, palm_xf(B.HAND_R, Basis(Vector3.RIGHT, -PI / 2)), tp + 1.0),
		on_bone(sp, B.HEAD, held, tp + 1.2, 0.5),
		on_bone(sp, B.HAND_L, palm_xf(B.HAND_L, Basis(Vector3.RIGHT, -PI / 2)), 6.0, 0.4),
		on_bone(sp, B.HEAD, held, 6.8, 0.45)])
	_phases = [[0.0, "Sniper pair: hooded capes; the marksman with a scoped rifle, the spotter with binoculars"],
		[ta + 0.3, "Down behind the rise"], [5.4, "The spotter finds the mark and points it out"],
		[s1, "Shot, bolt, second shot, reload"]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		if t < 3.2:
			var z := lerpf(7.0, 0.5, ramp(t, 0.0, 2.6))
			cam.transform = Transform3D(Basis(), Vector3(3.2, 2.2, z + 3.2)).looking_at(Vector3(0, 0.5, z - 1.0), Vector3.UP)
		elif t < 9.0:
			cam.transform = Transform3D(Basis(), Vector3(-2.3, 0.75, -2.9)).looking_at(Vector3(0.05, 0.3, -0.2), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(-2.5, 0.85, 0.1)).looking_at(Vector3(0.1, 0.3, -0.8), Vector3.UP)
	return s2 + 4.8


# ---------------------------------------------------------------- LMG

func _scene_lmg() -> float:
	var lib := R.library()
	var gn := troop(371, "lmg_gunner", Vector3(0, 0, 7.0))
	var cr := troop(372, "lmg_carrier", Vector3(-0.7, 0, 7.8))
	var g_run := Body.gait(C.RUN_LOADED, R.carry("port"))
	for a: Dictionary in [gn, cr]:
		pose(a, 0.0, 0.0, Body.pose("run", R.carry("port")), null, null)
	var ta := move(gn, 0.0, Vector3(0, 0, 0), g_run, 0.0)
	var tb := move(cr, 0.0, Vector3(-0.68, 0, 0.12), g_run, 0.15)
	pose(gn, ta, 0.25, R.poses()["ready"])
	clip(gn, ta + 0.25, lib["stand_to_prone"])
	pose(cr, tb, 0.25, R.poses()["ready"])
	clip(cr, tb + 0.25, lib["stand_to_prone"])
	var prone: Dictionary = R.poses()["prone"]
	# The bipod: the left hand swings the legs down.
	var td := ta + 1.7
	var leg := func(t: float) -> float: return ramp(t, td + 0.3, 0.4)
	var drum1 := lmg_kit(gn, leg)
	var to_legs := func(_t: float) -> Dictionary: return {"hand_l": wpt(gn, TroopKit.LMG_HINGE + Vector3(0.0, -0.02, 0.06))}
	pose(gn, td - 0.2, 0.3, prone, to_legs, prone)
	pose(gn, td + 0.8, 0.35, prone)
	var muzzle := TroopKit.LMG_MUZZLE
	burst(gn, td + 1.6, 1.0, muzzle)
	burst(gn, td + 3.0, 1.3, muzzle)
	burst(gn, td + 4.9, 0.8, muzzle)
	# The carrier watches, then swaps the empty drum for a full one from his pouch.
	var watch := Rig.over(T.prone_free(), {"add": {B.NECK: Vector3(6, -10, 0)}})
	pose(cr, tb + 1.5, 0.5, watch, null, prone)
	var ts := td + 6.0
	var on_drum := func(dy: float) -> Callable:
		return func(_t: float) -> Dictionary: return {"hand_r": wpt(gn, TroopKit.LMG_DRUM + Vector3(0.0, 0.05 + dy, 0.03))}
	var reach := Rig.over(watch, {"pole_r": Vector3(0.7, -0.6, 0.2), "add": {B.CHEST: Vector3(4, -12, 0), B.NECK: Vector3(4, -14, 0)}})
	var ground := Vector3(-0.32, 0.0, -0.95)
	pose(cr, ts, 0.5, reach, on_drum.call(0.0))
	pose(cr, ts + 0.5, 0.25, reach, on_drum.call(0.14))
	pose(cr, ts + 0.75, 0.4, reach, {"hand_r": ground + Vector3(0, 0.15, 0)})
	pose(cr, ts + 1.2, 0.45, Rig.over(reach, {"hand_r": [B.HIPS, Vector3(0.2, 1.08, 0.03)], "pole_r": Vector3(0.6, -0.3, 0.4)}))
	pose(cr, ts + 1.75, 0.5, reach, on_drum.call(0.14))
	pose(cr, ts + 2.25, 0.15, reach, on_drum.call(0.0))
	pose(cr, ts + 2.45, 0.12, reach, on_drum.call(-0.02))
	pose(cr, ts + 2.6, 0.5, watch)
	var hang := palm_xf(B.HAND_R, Basis(Vector3.BACK, PI / 2))
	hang.origin += Vector3(0, -0.11, 0)
	for p: Dictionary in props:
		if p["node"] == drum1:
			p["keys"] = [p["keys"][0], on_bone(cr, B.HAND_R, hang, ts + 0.5, 0.12),
				at_world(Transform3D(Basis(Vector3.UP, 0.4), ground + Vector3(0, 0.0, 0)), ts + 1.1, 0.15)]
	prop(cm("drum", TroopKit.drum), [at_world(HIDE, 0.0), on_bone(cr, B.HAND_R, hang, ts + 1.6),
		on_bone(gn, B.RIFLE, Transform3D(Basis(), B.REST[B.RIFLE] + TroopKit.LMG_DRUM), ts + 2.25, 0.15)])
	burst(gn, ts + 3.1, 1.5, muzzle)
	_phases = [[0.0, "LMG team: the gunner and his ammunition carrier (drum pouches)"],
		[td - 0.2, "Bipod down"], [td + 1.6, "Bursts from the bipod"], [ts, "Drum empty: the carrier swaps it"],
		[ts + 3.1, "Firing again"]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		if t < td - 0.4:
			var z := lerpf(7.0, 0.3, ramp(t, 0.0, 2.4))
			cam.transform = Transform3D(Basis(), Vector3(3.0, 2.2, z + 3.0)).looking_at(Vector3(-0.3, 0.4, z - 1.0), Vector3.UP)
		elif t < ts - 0.5:
			cam.transform = Transform3D(Basis(), Vector3(1.9, 0.75, -2.6)).looking_at(Vector3(-0.2, 0.3, -0.6), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(-1.6, 1.25, -2.4)).looking_at(Vector3(-0.15, 0.3, -0.6), Vector3.UP)
	return ts + 5.2


# ---------------------------------------------------------------- mortar

func _scene_mortar() -> float:
	var walk := Body.gait(Body.WALK, R.carry("low"))
	var walk_tube := Body.gait(Body.WALK, C.carry("gun"))
	var walk_free := Body.gait(Body.WALK, C.carry("free"))
	var tm := troop(381, "mortar_tube", Vector3(-0.6, 0, 6.2))
	var pm := troop(382, "mortar_plate", Vector3(0.0, 0, 5.6))
	var bm := troop(383, "mortar_bombs", Vector3(0.5, 0, 6.6))
	pose(tm, 0.0, 0.0, Body.pose("stand", C.carry("gun")), null, null)
	pose(pm, 0.0, 0.0, Body.pose("stand", C.carry("free")), null, null)
	pose(bm, 0.0, 0.0, Body.pose("stand", R.carry("low")), null, null)
	var tp := move(pm, 0.0, Vector3(0, 0, 0.55), walk_free, 0.0)
	var tw := move(tm, 0.2, Vector3(-0.6, 0, 1.1), walk_tube, 0.0)
	var tb := move(bm, 0.4, Vector3(0.5, 0, -0.35), walk, PI / 2)
	pose(tm, tw, 0.3, Body.pose("stand", C.carry("gun")))
	pose(bm, tb, 0.4, Body.pose("stand", R.carry("low")))
	# The baseplate: off the back, held in front, set down at the origin.
	var hold := Transform3D(Basis(), Vector3(0, 0.92, 0.17))
	var t_set := tp + 0.7
	var plate_xf := func(t: float) -> Transform3D:
		return hold.interpolate_with(Transform3D(), ramp(t, t_set, 0.8))
	var edges := func(t: float) -> Dictionary:
		var x: Transform3D = plate_xf.call(t)
		return {"hand_r": x * Vector3(0.25, 0.03, 0.0), "hand_l": x * Vector3(-0.25, 0.03, 0.0)}
	prop(km(TroopKit.plate()), [on_bone(pm, B.CHEST, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.30, 0.19)), 0.0),
		at_world(plate_xf, tp, 0.5)])
	var bent := Rig.over(Body.body("stand"), {"rifle": {"mode": "back"}, "pole_r": Vector3(0.7, -0.4, 0.2), "pole_l": Vector3(-0.7, -0.4, 0.2),
		"add": {B.SPINE: Vector3(-8, 0, 0), B.NECK: Vector3(-12, 0, 0)}})
	pose(pm, tp, 0.5, bent, edges)
	pose(pm, t_set, 0.8, T.kneel_work(30.0), edges)
	pose(pm, t_set + 1.0, 0.5, Body.pose("stand", C.carry("free")))
	var t_pm := move(pm, t_set + 1.5, Vector3(1.3, 0, 1.25), walk_free, 0.0)
	pose(pm, t_pm, 0.5, T.kneel_work(4.0))
	# The tube: walked in, off the shoulder, into the socket, bipod legs out.
	var tt := move(tm, t_set + 0.9, Vector3(-0.36, 0, 0.12), walk_tube, 0.0)
	var set_xf := TroopKit.tube_xf()
	var lifted := Transform3D(set_xf.basis, set_xf.origin + Vector3(0, 0.28, 0.06))
	var shots_at: Array = []
	var tube_xf := func(t: float) -> Transform3D:
		var x := lifted.interpolate_with(set_xf, ramp(t, tt + 0.7, 0.5))
		for s: float in shots_at:
			var dt := t - s
			if dt >= 0.0 and dt < 0.3:
				x.origin -= x.basis.y * 0.04 * (1.0 - dt / 0.3)
		return x
	var open_fn := func(t: float) -> float: return ramp(t, tt + 1.3, 0.6)
	var shoulder := Transform3D(C.GUN_ON_SHOULDER.basis * Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO)
	shoulder.origin = B.REST[B.CHEST] + C.GUN_ON_SHOULDER.origin + shoulder.basis * Vector3(0, -0.38, 0)
	prop(cm("tube0", func() -> UnitGeo: return TroopKit.tube(0.0)), [on_bone(tm, B.CHEST, shoulder, 0.0), at_world(tube_xf, tt, 0.6)],
		func(t: float) -> Variant:
			var q := snappedf(float(open_fn.call(t)), 0.1)
			return cm("tube%.1f" % q, func() -> UnitGeo: return TroopKit.tube(q)))
	var on_tube := func(r: Vector3, l: Vector3) -> Callable:
		return func(t: float) -> Dictionary:
			var x: Transform3D = tube_xf.call(t)
			return {"hand_r": x * r, "hand_l": x * l}
	var lay: Callable = on_tube.call(Vector3(0.05, TroopKit.COLLAR + 0.02, 0.0), Vector3(-0.075, TroopKit.COLLAR + 0.07, -0.02))
	pose(tm, tt, 0.6, Rig.over(Body.body("stand"), {"rifle": {"mode": "back"}, "pole_r": Vector3(0.7, -0.4, 0.2),
		"pole_l": Vector3(-0.7, -0.4, 0.2)}), on_tube.call(Vector3(0.0, 0.62, 0.04), Vector3(0.0, 0.3, 0.04)))
	pose(tm, tt + 0.6, 0.6, T.kneel_work(20.0), on_tube.call(Vector3(0.0, 0.62, 0.04), Vector3(0.0, 0.3, 0.04)))
	pose(tm, tt + 1.4, 0.5, T.kneel_work(22.0, -10.0), lay)
	# Three bombs: the loader takes one from his bag, holds it over the muzzle, lets go, ducks.
	pose(bm, tt + 0.4, 0.6, T.kneel_work(8.0))
	var c0 := tt + 2.6
	var period := 3.3
	var axis := set_xf.basis.y
	for r in 3:
		var c := c0 + period * r
		var ts := c + 1.45
		shots_at.append(ts)
		var hold_b := Transform3D(set_xf.basis, TroopKit.muzzle() + axis * (TroopKit.BOMB_LEN * 0.5 + 0.06))
		var bag := Rig.over(T.kneel_work(10.0), {"hand_r": [B.CHEST, Vector3(0.03, 1.24, -0.23)],
			"hand_l": [B.CHEST, Vector3(-0.05, 1.2, -0.22)], "add": {B.NECK: Vector3(-20, 0, 0)}})
		pose(bm, c, 0.4, bag)
		var over_tube := func(_t: float) -> Dictionary:
			return {"hand_r": hold_b * Vector3(0, -0.02, -0.04), "hand_l": hold_b * Vector3(0, -0.02, 0.04)}
		pose(bm, c + 0.45, 0.55, T.kneel_work(4.0), over_tube)
		pose(bm, c + 1.05, 0.15, T.kneel_work(4.0))
		pose(bm, c + 1.2, 0.25, T.duck(T.kneel_work(10.0)))
		pose(bm, c + 2.1, 0.5, T.kneel_work(8.0))
		var slide := func(t: float) -> Transform3D:
			var d := minf(4.5 * (t - (c + 1.05)), 0.5)
			if d >= 0.5:
				return HIDE
			return Transform3D(hold_b.basis, hold_b.origin - axis * d)
		var flight := func(t: float) -> Transform3D:
			return Transform3D(set_xf.basis, TroopKit.muzzle() + axis * (0.1 + 55.0 * (t - ts)))
		prop(cm("bomb", TroopKit.bomb), [at_world(HIDE, 0.0), on_bone(bm, B.HAND_R, palm_xf(B.HAND_R), c + 0.4),
			at_world(hold_b, c + 0.6, 0.4), at_world(slide, c + 1.05), at_world(flight, ts), at_world(HIDE, ts + 0.25)])
		for a: Dictionary in [tm, pm]:
			pose(a, ts - 0.2, 0.2, T.duck(T.kneel_work(18.0 if a == tm else 4.0)))
		pose(tm, ts + 0.7, 0.5, T.kneel_work(22.0, -10.0), lay)
		pose(pm, ts + 0.7, 0.5, T.kneel_work(4.0))
		var fl := func(t: float) -> Variant:
			return Transform3D(Basis(), TroopKit.muzzle() + axis * 0.08) if t >= ts and t < ts + 0.06 else null
		glow(0.16, fl, 3.0)
		later(ts, func(t: float) -> void:
			var m := TroopKit.muzzle()
			for k in 5:
				puff(m + axis * 0.05 * k, axis * (2.6 - 0.4 * k) + Vector3(0.15 * (k - 2), 0.3, 0), 0.08 + 0.03 * k, GREY, 2.2, 2.2, 0.55, t)
			for k in 6:
				var ang := TAU * k / 6.0
				var d := Vector3(cos(ang), 0, sin(ang))
				puff(d * 0.25 + Vector3(0, 0.05, 0), d * 1.2 + Vector3(0, 0.25, 0), 0.08, DUST, 1.4, 2.4, 0.4, t))
	var t_end := c0 + period * 3 + 0.6
	_phases = [[0.0, "Mortar team: tube, baseplate and bomb carrier (bomb bags)"], [tp, "Baseplate down"],
		[tt, "Tube into the socket, bipod legs out"], [c0, "Bomb in, everyone ducks, the tube kicks"]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		if t < tp - 0.3:
			var z := lerpf(6.0, 0.6, ramp(t, 0.0, tp))
			cam.transform = Transform3D(Basis(), Vector3(3.4, 2.4, z + 3.4)).looking_at(Vector3(0, 0.6, z - 0.8), Vector3.UP)
		elif t < c0 + period:
			cam.transform = Transform3D(Basis(), Vector3(-2.5, 1.4, 1.9)).looking_at(Vector3(0.1, 0.5, -0.1), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(-3.3, 1.5, -0.3)).looking_at(Vector3(0.25, 0.5, -0.1), Vector3.UP)
	return t_end
