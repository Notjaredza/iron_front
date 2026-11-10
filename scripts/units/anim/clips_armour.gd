extends RefCounted
## The armoured trench troops' moves (Building Chat 1, 2026-11-10). Clip names are "<role>_<move>" (role shield or club).
##   walk         the heavy walk (short steps, a rolling gait under the weight)
##   wall_lock    the shield man brings his shield up into the wall, club raised behind it
##   wall_step    the wall's step-and-drag advance, crouched behind the shields (club men follow the same step)
##   strike       a club blow over the top of the shields from the wall
##   rush         breaking from the wall into the heavy run
##   smash / swing  (club) the overhead blow and the side swing; bash / block (shield) the shield punch and taking a hit
##   pistol       club to the belt, pistol drawn, three shots (over the shield for the shield man)
##   hit, death_back, death_forward, prone_to_stand   the shared ones in the armour's carry
## Holds ("<role>_hold_<pose>") keep one pose. Clip "props": {"hand": [[t, "club" | "pistol"]]}; events: strike, bash,
## block, shot.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const T := preload("res://scripts/units/anim/clips_troops.gd")
const O := preload("res://scripts/units/anim/clips_officer.gd")

const HEAVY := {"name": "walk", "v": 1.0, "T": 1.2, "duty": 0.62, "hip": 0.865, "bob": 0.03, "bob_sign": 1.0, "lift": 0.06,
	"lean": 7.0, "fwd": 0.03, "hip_yaw": 9.0, "sway": 0.035, "shoulder_yaw": 2.0, "strike": 10.0, "push": 22.0, "width": 0.11}
const WALL := {"name": "wall_step", "v": 0.55, "T": 1.4, "duty": 0.72, "hip": 0.8, "bob": 0.025, "bob_sign": 1.0, "lift": 0.05,
	"lean": 14.0, "fwd": 0.08, "hip_yaw": 5.0, "sway": 0.04, "shoulder_yaw": 1.0, "strike": 8.0, "push": 16.0, "width": 0.15}
const RUSH := {"name": "rush", "v": 3.1, "T": 0.72, "duty": 0.38, "hip": 0.86, "bob": 0.04, "bob_sign": -1.0, "lift": 0.16,
	"lean": 16.0, "fwd": 0.1, "hip_yaw": 10.0, "sway": 0.03, "shoulder_yaw": 4.0, "strike": 6.0, "push": 30.0, "width": 0.1}

## Where the shield hand goes (rest model space, riding the chest).
const SH_CARRY := Vector3(-0.17, 1.03, -0.3)
const SH_WALL := Vector3(-0.02, 1.13, -0.4)
const SH_HIGH := Vector3(-0.04, 1.36, -0.4)
const SH_BASH := Vector3(0.0, 1.17, -0.66)
const HOLSTER := Vector3(0.215, 1.0, -0.05)


static func _shield(at: Vector3) -> Dictionary:
	return {"hand_l": [B.CHEST, at], "pole_l": Vector3(-0.9, -0.5, 0.2)}


## The club held by the right hand, placed in the chest frame (grip relative to the chest joint).
static func club(grip: Vector3, dir: Vector3, up := Vector3.UP, pole := Vector3(0.8, -0.3, 0.2)) -> Dictionary:
	return {"rifle": {"mode": "chest", "dir": dir, "up": up, "grip": grip}, "hand_r": B.GRIP_R, "pole_r": pole}


static func club_low() -> Dictionary:
	return T.carry("club")


static func club_up() -> Dictionary:
	return club(Vector3(0.24, 0.3, -0.04), Vector3(0.12, 0.92, 0.36), Vector3(0, 0, -1))


static func club_wind() -> Dictionary:
	return club(Vector3(0.18, 0.6, 0.12), Vector3(0.08, -0.25, 1.0), Vector3.UP, Vector3(0.9, 0.2, 0.3))


static func club_hit_high() -> Dictionary:
	return club(Vector3(0.08, 0.42, -0.55), Vector3(0.0, -0.6, -0.8), Vector3(0, 0.8, -0.6), Vector3(0.8, -0.2, 0.0))


static func club_hit_low() -> Dictionary:
	return club(Vector3(0.05, 0.1, -0.52), Vector3(-0.05, -0.72, -0.7), Vector3(0, 0.7, -0.72), Vector3(0.8, -0.3, 0.0))


## Fall carry: the club hangs in the right hand, both arms by angles.
static func fall() -> Dictionary:
	return {"rifle": {"mode": "hand", "rot": Vector3(55, 0, 0)}, "hand_r": null, "hand_l": null}


static func _crouch() -> Dictionary:
	return Rig.over(Body.body("ready"), {"add": {B.SPINE: Vector3(-8, 0, 0), B.CHEST: Vector3(-3, 0, 0), B.NECK: Vector3(6, 0, 0)},
		"rot": {B.THIGH_R: Vector3(26, 0, 6), B.SHIN_R: Vector3(-40, 0, 0), B.FOOT_R: Vector3(14, 0, -4),
			B.THIGH_L: Vector3(40, 10, -6), B.SHIN_L: Vector3(-36, 0, 0), B.FOOT_L: Vector3(-4, -10, 4)}})


## The named poses for a role.
static func poses(role: String) -> Dictionary:
	var stand := Rig.over(Body.body("stand"), club_low())
	if role == "shield":
		stand = Rig.over(stand, _shield(SH_CARRY))
	var wall := Rig.over(Rig.over(_crouch(), club_up()), _shield(SH_WALL)) if role == "shield" \
		else Rig.over(_crouch(), Rig.over(club_up(), {"hand_l": [B.CHEST, Vector3(-0.2, 1.2, -0.3)], "pole_l": Vector3(-0.8, -0.6, 0.0)}))
	var guard := wall if role == "shield" else Rig.over(Body.body("ready"), Rig.over(club_up(),
		{"hand_l": [B.CHEST, Vector3(-0.16, 1.4, -0.32)], "pole_l": Vector3(-0.8, -0.6, 0.0)}))
	var pistol_aim := Rig.over(wall if role == "shield" else Body.body("stand"), {"rifle": O.pistol("hand"),
		"hand_r": [B.CHEST, Vector3(0.1, 1.6, -0.55) if role == "shield" else Vector3(0.1, 1.47, -0.6)],
		"pole_r": Vector3(0.6, -0.4, 0.1), "hand_item": "pistol"})
	if role != "shield":
		pistol_aim = Rig.over(pistol_aim, {"hand_l": [B.HIPS, Vector3(-0.22, 1.05, 0.0)], "pole_l": Vector3(-0.7, 0.1, 0.4),
			"add": {B.HIPS: Vector3(0, 14, 0), B.CHEST: Vector3(2, -8, 0)}})
	return {"stand": stand, "aim": stand, "wall": wall, "guard": guard, "pistol": pistol_aim,
		"kneel": Rig.over(Body.body("kneel"), stand), "prone": Rig.over(Body.body("prone"), fall())}


static func _hold(name: String, p: Dictionary, hand := "club") -> Dictionary:
	return {"name": name, "len": 1.0, "loop": true, "keys": [[0.0, p], [1.0, p]], "props": {"hand": [[0.0, hand]]}}


static func _gait(role: String, style: Dictionary, carry: Dictionary) -> Dictionary:
	var st := style.duplicate()
	st["name"] = "%s_%s" % [role, style["name"]]
	var c := Body.gait(st, carry)
	c["props"] = {"hand": [[0.0, "club"]]}
	return c


## Shield up into the wall.
static func wall_lock(role: String, p: Dictionary) -> Dictionary:
	var mid := Rig.over(p["wall"], {"add": {B.CHEST: Vector3(6, 8, 0)}})
	return {"name": role + "_wall_lock", "len": 0.9, "keys": [[0.0, p["stand"]], [0.45, mid, "smooth"], [0.65, p["wall"], "out"],
		[0.9, p["wall"]]], "props": {"hand": [[0.0, "club"]]}, "events": [[0.62, "lock"]]}


## A club blow over the top of the shields from the wall (the shield man's own, or a club man's behind him).
static func strike(role: String, p: Dictionary) -> Dictionary:
	var base: Dictionary = p["wall"]
	var wind := Rig.over(base, Rig.over(club_wind(), {"add": {B.CHEST: Vector3(8, -14, 0), B.SPINE: Vector3(4, 0, 0)}}))
	var hit := Rig.over(base, Rig.over(club_hit_high(), {"add": {B.CHEST: Vector3(-10, 16, 0), B.SPINE: Vector3(-8, 4, 0)},
		"root_pos": Vector3(0, -0.02, -0.1)}))
	var follow := Rig.over(hit, {"add": {B.CHEST: Vector3(-4, 4, 0)}, "rifle_add": {"dir": Vector3(0, -0.2, 0)}})
	return {"name": role + "_strike", "len": 1.25, "keys": [[0.0, base], [0.38, wind, "smooth"], [0.52, hit, "in"],
		[0.66, follow, "out"], [1.25, base, "smooth"]], "props": {"hand": [[0.0, "club"]]}, "events": [[0.52, "strike"]]}


## The club man's overhead smash, stepping in.
static func smash(p: Dictionary) -> Dictionary:
	var g: Dictionary = p["guard"]
	var free_l := {"hand_l": [B.CHEST, Vector3(-0.22, 1.25, -0.25)], "pole_l": Vector3(-0.8, -0.6, 0.0)}
	var wind := Rig.over(Body.body("stance"), Rig.over(Rig.over(club_wind(), free_l), {"add": {B.SPINE: Vector3(6, 0, 0), B.CHEST: Vector3(8, 0, 0)}}))
	var hit := Rig.over(Body.body("ready"), Rig.over(Rig.over(club_hit_low(), free_l), {
		"rot": {B.THIGH_L: Vector3(55, 8, -4), B.SHIN_L: Vector3(-50, 0, 0), B.THIGH_R: Vector3(-20, 0, 6), B.SHIN_R: Vector3(-14, 0, 0)},
		"add": {B.SPINE: Vector3(-20, 0, 0), B.CHEST: Vector3(-10, 4, 0)}, "root_pos": Vector3(0, -0.07, -0.25)}))
	var follow := Rig.over(hit, {"add": {B.SPINE: Vector3(-6, 0, 0)}, "rifle_add": {"grip": Vector3(0, -0.12, 0.06)}})
	return {"name": "club_smash", "len": 1.4, "keys": [[0.0, g], [0.42, wind, "smooth"], [0.56, hit, "in"], [0.72, follow, "out"],
		[1.4, g, "smooth"]], "props": {"hand": [[0.0, "club"]]}, "events": [[0.56, "strike"]]}


## The side swing: wound back to the right, swept across at head height.
static func swing(p: Dictionary) -> Dictionary:
	var g: Dictionary = p["guard"]
	var wind := Rig.over(Body.body("ready"), Rig.over(club(Vector3(0.42, 0.22, 0.14), Vector3(0.55, 0.35, 0.76), Vector3.UP,
		Vector3(0.8, -0.4, 0.4)), {"hand_l": [B.CHEST, Vector3(-0.1, 1.38, -0.4)], "pole_l": Vector3(-0.8, -0.4, 0.0),
		"add": {B.HIPS: Vector3(0, -22, 0), B.SPINE: Vector3(0, -12, 0), B.CHEST: Vector3(0, -16, 0)}}))
	var hit := Rig.over(Body.body("ready"), Rig.over(club(Vector3(-0.05, 0.26, -0.55), Vector3(-0.9, 0.08, -0.42), Vector3.UP,
		Vector3(0.6, -0.6, -0.2)), {"hand_l": [B.CHEST, Vector3(-0.3, 1.2, 0.0)], "pole_l": Vector3(-0.8, -0.4, 0.3),
		"add": {B.HIPS: Vector3(0, 18, 0), B.SPINE: Vector3(-6, 12, 0), B.CHEST: Vector3(-4, 18, 0)},
		"rot": {B.THIGH_L: Vector3(40, 12, -4), B.SHIN_L: Vector3(-36, 0, 0)}, "root_pos": Vector3(0, -0.04, -0.15)}))
	var follow := Rig.over(hit, {"rifle": {"mode": "chest", "dir": Vector3(-0.7, -0.2, 0.68), "up": Vector3.UP,
		"grip": Vector3(-0.32, 0.12, -0.3)}, "add": {B.CHEST: Vector3(0, 10, 0)}})
	return {"name": "club_swing", "len": 1.3, "keys": [[0.0, g], [0.36, wind, "smooth"], [0.5, hit, "in"], [0.66, follow, "out"],
		[1.3, g, "smooth"]], "props": {"hand": [[0.0, "club"]]}, "events": [[0.5, "strike"]]}


## The shield punch: coil, then drive the shield forward off the back foot.
static func bash(p: Dictionary) -> Dictionary:
	var w: Dictionary = p["wall"]
	var coil := Rig.over(w, Rig.over(_shield(SH_WALL + Vector3(-0.04, 0.0, 0.14)), {"add": {B.HIPS: Vector3(0, -14, 0),
		B.CHEST: Vector3(4, -10, 0)}}))
	var hit := Rig.over(w, Rig.over(_shield(SH_BASH), {"add": {B.HIPS: Vector3(0, 12, 0), B.SPINE: Vector3(-12, 6, 0),
		B.CHEST: Vector3(-6, 8, 0)}, "rot": {B.THIGH_L: Vector3(58, 10, -4), B.SHIN_L: Vector3(-52, 0, 0),
		B.THIGH_R: Vector3(-22, 0, 6), B.SHIN_R: Vector3(-10, 0, 0)}, "root_pos": Vector3(0, -0.06, -0.3)}))
	return {"name": "shield_bash", "len": 1.2, "keys": [[0.0, w], [0.3, coil, "smooth"], [0.44, hit, "out"], [0.6, hit],
		[1.2, w, "smooth"]], "props": {"hand": [[0.0, "club"]]}, "events": [[0.44, "bash"]]}


## Taking a blow (a bayonet, a sabre) on the raised shield: up, the jolt back, braced, down again.
static func block(p: Dictionary) -> Dictionary:
	var w: Dictionary = p["wall"]
	var up := Rig.over(w, Rig.over(_shield(SH_HIGH), {"add": {B.NECK: Vector3(-10, 0, 0)}}))
	var jolt := Rig.over(up, Rig.over(_shield(SH_HIGH + Vector3(0.02, 0.03, 0.12)), {"add": {B.SPINE: Vector3(10, 0, 0),
		B.CHEST: Vector3(8, -6, 0), B.NECK: Vector3(-8, 0, 0)}, "root_pos": Vector3(0, 0.0, 0.08)}))
	return {"name": "shield_block", "len": 1.1, "keys": [[0.0, w], [0.16, up, "out"], [0.26, jolt, "out"], [0.55, up, "smooth"],
		[1.1, w, "smooth"]], "props": {"hand": [[0.0, "club"]]}, "events": [[0.26, "block"]]}


## Club to the belt, pistol out, three shots.
static func pistol(role: String, p: Dictionary) -> Dictionary:
	var base: Dictionary = p["wall"] if role == "shield" else p["guard"]
	var aim: Dictionary = p["pistol"]
	var reach := Rig.over(base, {"hand_r": [B.HIPS, HOLSTER + Vector3(0, 0.04, 0)], "pole_r": Vector3(0.8, -0.2, 0.3),
		"rifle": {"mode": "hand", "rot": Vector3(-35, 0, 0), "after_ik": true}, "add": {B.CHEST: Vector3(0, 0, 4)}})
	var rec := Rig.over(aim, {"rifle": O.pistol("recoil"), "add": {B.CHEST: Vector3(3, 0, 0)}})
	var keys: Array = [[0.0, base], [0.32, reach, "smooth"], [0.7, aim, "smooth"]]
	var ev: Array = []
	for k in 3:
		var ts := 0.95 + 0.6 * k
		keys.append([ts, aim])
		keys.append([ts + 0.06, rec, "out"])
		keys.append([ts + 0.3, aim, "smooth"])
		ev.append([ts, "shot"])
	keys.append([2.8, aim])
	return {"name": role + "_pistol", "len": 2.8, "keys": keys, "props": {"hand": [[0.0, "club"], [0.3, "pistol"]]}, "events": ev}


## Hit in the armour (a ball rings off the plates): rocked back a step, the head snapped, then he comes on again.
static func stagger(role: String, p: Dictionary) -> Dictionary:
	var base: Dictionary = p["wall"] if role == "shield" else p["stand"]
	var jolt := Rig.over(base, {"add": {B.CHEST: Vector3(20, 10, 0), B.SPINE: Vector3(10, 0, 0), B.NECK: Vector3(18, 0, 0),
		B.HEAD: Vector3(14, -12, 8)}, "root_pos": Vector3(0, 0.0, 0.12)})
	var back := Rig.over(base, {"add": {B.CHEST: Vector3(10, 4, 0), B.SPINE: Vector3(6, 0, 0)},
		"rot": {B.THIGH_R: Vector3(-24, 0, 6), B.SHIN_R: Vector3(-20, 0, 0), B.THIGH_L: Vector3(14, 6, -4)},
		"root_pos": Vector3(0, -0.04, 0.32)})
	return {"name": "hit", "len": 1.2, "keys": [[0.0, base], [0.08, jolt, "out"], [0.42, back, "smooth"], [1.2, base, "smooth"]],
		"events": [[0.0, "hit"]]}


static func role_clip(role: String, base: String) -> String:
	return "%s_%s" % [role, base]


static func library() -> Dictionary:
	var out := {}
	for role: String in ["shield", "club"]:
		var p := poses(role)
		var walk_carry: Dictionary = club_low() if role == "club" else Rig.over(club_low(), _shield(SH_CARRY))
		var wall_carry: Dictionary = Rig.over(club_up(), _shield(SH_WALL)) if role == "shield" else Rig.over(club_up(),
			{"hand_l": [B.CHEST, Vector3(-0.2, 1.2, -0.3)], "pole_l": Vector3(-0.8, -0.6, 0.0)})
		var rush_carry: Dictionary = Rig.over(club_up(), _shield(SH_WALL + Vector3(0, 0.03, 0.04))) if role == "shield" \
			else Rig.over(club_up(), {"hand_l": null, "rot": {B.UARM_L: Vector3(-30, 0, -14), B.FARM_L: Vector3(-60, 0, 0)}})
		var fall_c := fall()
		var list: Array = [
			_gait(role, HEAVY, walk_carry), _gait(role, WALL, wall_carry), _gait(role, RUSH, rush_carry),
			wall_lock(role, p), strike(role, p), pistol(role, p),
			stagger(role, p), Body.death_back(p["stand"], fall_c), Body.death_forward(p["stand"], fall_c),
			Body.prone_to_stand(p["prone"], fall_c, p["stand"])]
		if role == "club":
			list.append_array([smash(p), swing(p)])
		else:
			list.append_array([bash(p), block(p)])
		for c: Dictionary in list:
			var nm: String = c["name"]
			if not nm.begins_with(role + "_"):
				c = c.duplicate()
				c["name"] = role + "_" + nm
				c["props"] = {"hand": [[0.0, "club"]]}
			out[c["name"]] = c
		for pn: String in ["stand", "wall", "guard", "pistol"]:
			out["%s_hold_%s" % [role, pn]] = _hold("%s_hold_%s" % [role, pn], p[pn], "pistol" if pn == "pistol" else "club")
	return out
