extends RefCounted
## The rifle's own part (Question Chat, animation round 1, 2026-11-09): how a
## bolt-action rifle is held (the "carries"), and the moves only a rifle has:
## fire with the bolt worked, and the stripper-clip reload. With clips_body.gd this
## makes the rifleman's whole set. Another weapon brings its own file like this one.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")

const POLE_AIM_R := Vector3(0.6, 0.05, 0.1)
const POLE_AIM_L := Vector3(-0.05, -0.8, 0.05)

## Rifle points beyond the grips (rifle frame).
const BOLT_UP := Vector3(0.036, 0.086, -0.02)
const BOLT_BACK := Vector3(0.036, 0.086, 0.075)
const CLIP_TOP := Vector3(0.0, 0.115, -0.07)
const CLIP_DOWN := Vector3(0.0, 0.07, -0.07)
const POUCH_R := Vector3(0.10, 1.03, -0.165)  # rest model space, rides on the hips


static func carry(name: String) -> Dictionary:
	match name:
		"order":
			return {"rifle": {"mode": "order", "butt": Vector3(0.27, 0.015, -0.07)},
				"hand_r": Vector3(0, 0, -0.45), "pole_r": Vector3(0.25, -0.3, 0.45), "hand_l": null}
		"low":
			return {"rifle": {"mode": "chest", "dir": Vector3(-0.12, -0.42, -1.0), "up": Vector3(0.25, 1.0, 0.0),
				"grip": Vector3(0.15, -0.27, -0.2)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.7, -0.4, 0.3),
				"hand_l": B.GRIP_L, "pole_l": Vector3(-0.7, -0.5, 0.0)}
		"port":
			return {"rifle": {"mode": "chest", "dir": Vector3(-0.5, 0.75, -0.42), "up": Vector3(0.3, 0.2, -1.0),
				"grip": Vector3(0.13, -0.20, -0.21)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.45, -0.3, 0.2),
				"hand_l": B.GRIP_L, "pole_l": Vector3(-0.5, -0.4, 0.1)}
		"one_hand":
			# Going down or getting up: the rifle in the right hand, the left hand free.
			return {"rifle": {"mode": "chest", "dir": Vector3(-0.3, 0.2, -1.0), "up": Vector3(0, 1, 0),
				"grip": Vector3(0.17, -0.24, -0.2)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.7, -0.4, 0.3), "hand_l": null}
		"aim":
			return {"rifle": {"mode": "aim", "dir": Vector3(0, -0.01, -1)},
				"hand_r": B.GRIP_R, "pole_r": POLE_AIM_R, "hand_l": B.GRIP_L, "pole_l": POLE_AIM_L}
		"aim_prone":
			return {"rifle": {"mode": "aim", "dir": Vector3(0, 0.0, -1)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.35, -0.6, 0.0),
				"hand_l": B.GRIP_L, "pole_l": Vector3(-0.3, -0.6, -0.2)}
		"fall":
			# Dying: the right hand keeps hold of the rifle, the left lets go.
			return {"rifle": {"mode": "hand", "rot": Vector3(-90, 0, 0)}, "hand_r": null, "hand_l": null}
	return {}


## The rifleman's named poses (the pictures and the clips start from these).
static func poses() -> Dictionary:
	return {
		"stand": Body.pose("stand", carry("order")),
		"ready": Body.pose("ready", carry("low")),
		"run": Body.pose("run", carry("port")),
		"aim": Body.pose("stance", carry("aim")),
		"kneel": Body.pose("kneel", carry("aim")),
		"prone": Body.pose("prone", carry("aim_prone")),
	}


## One shot and the bolt worked, back on aim. Works from any aimed pose.
static func fire(name: String, aim: Dictionary) -> Dictionary:
	var kick := Rig.over(aim, {"add": {B.CHEST: Vector3(6, 2, 0), B.NECK: Vector3(4, 0, 0), B.HEAD: Vector3(4, 0, 0)},
		"rifle_add": {"dir": Vector3(0, 0.14, 0), "off": Vector3(0, 0.01, 0.045)}})
	var settle := Rig.over(aim, {"add": {B.CHEST: Vector3(-1, 0, 0)}})
	var cant := {"rifle_add": {"dir": Vector3(0, -0.04, 0), "roll": -8.0}}
	var grab := Rig.over(Rig.over(aim, cant), {"hand_r": Rig.BOLT})
	var up := Rig.over(Rig.over(aim, cant), {"hand_r": BOLT_UP})
	var back := Rig.over(Rig.over(aim, cant), {"hand_r": BOLT_BACK, "add": {B.HEAD: Vector3(0, 0, 0)}})
	return {"name": name, "len": 1.45, "keys": [[0.0, aim], [0.05, kick, "out"], [0.24, settle, "smooth"],
		[0.38, grab, "smooth"], [0.47, up, "out"], [0.58, back, "out"], [0.70, up, "out"], [0.79, grab, "out"],
		[0.98, aim, "smooth"], [1.45, aim]], "events": [[0.0, "shot"]]}


## Stripper-clip reload: rifle down and canted, bolt open, clip from the pouch,
## thumb it in, bolt shut, back on aim.
static func reload(name: String, aim: Dictionary, prone := false) -> Dictionary:
	var lower := {"rifle_add": {"dir": Vector3(0.05, 0.08 if not prone else -0.12, 0),
		"off": Vector3(0.03, -0.30, 0.07) if not prone else Vector3(0.0, -0.03, -0.1), "roll": -28.0}}
	var low := Rig.over(aim, lower)
	var low_spec := Rig.over(low, {"add": {B.NECK: Vector3(-12, -6, 0), B.HEAD: Vector3(-8, -6, 8)}})
	var at := func(h: Variant) -> Dictionary: return Rig.over(low_spec, {"hand_r": h})
	var pouch: Array = [B.HIPS, POUCH_R] if not prone else [B.CHEST, Vector3(0.12, 1.30, -0.16)]
	return {"name": name, "len": 2.9, "keys": [[0.0, aim], [0.28, low_spec, "smooth"],
		[0.45, at.call(Rig.BOLT), "smooth"], [0.55, at.call(BOLT_UP), "out"], [0.68, at.call(BOLT_BACK), "out"],
		[1.0, Rig.over(low_spec, {"hand_r": pouch, "pole_r": Vector3(0.8, -0.2, 0.2)}), "smooth"],
		[1.12, Rig.over(low_spec, {"hand_r": pouch, "pole_r": Vector3(0.8, -0.2, 0.2)}), "smooth"],
		[1.42, at.call(CLIP_TOP), "smooth"], [1.6, at.call(CLIP_DOWN), "out"], [1.72, at.call(CLIP_TOP + Vector3(0, -0.02, 0)), "smooth"],
		[1.86, at.call(CLIP_DOWN), "out"], [2.06, at.call(BOLT_BACK), "smooth"], [2.18, at.call(BOLT_UP), "out"],
		[2.27, at.call(Rig.BOLT), "out"], [2.42, at.call(B.GRIP_R), "smooth"], [2.72, aim, "smooth"], [2.9, aim]]}


## Every round 1 clip for the rifleman.
static func library() -> Dictionary:
	var p := poses()
	var out := {}
	for c: Dictionary in [
			Body.gait(Body.WALK, carry("low")),
			Body.gait(Body.RUN, carry("port")),
			fire("fire_stand", p["aim"]), fire("fire_kneel", p["kneel"]), fire("fire_prone", p["prone"]),
			reload("reload_stand", p["aim"]), reload("reload_kneel", p["kneel"]), reload("reload_prone", p["prone"], true),
			Body.stand_to_kneel(p["ready"], p["kneel"]), Body.kneel_to_stand(p["kneel"], p["ready"]),
			Body.stand_to_prone(p["ready"], carry("one_hand"), p["prone"]),
			Body.prone_to_stand(p["prone"], carry("one_hand"), p["ready"]),
			Body.hit(p["aim"]),
			Body.death_back(p["aim"], carry("fall")), Body.death_forward(p["aim"], carry("fall"))]:
		out[c["name"]] = c
	return out
