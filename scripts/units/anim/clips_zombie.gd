extends RefCounted
## The zombies' own part (Question Chat, 2026-11-10). They are built on the soldier skeleton, so the body
## library (clips_body.gd) runs them; this gives them their styles and their own moves:
##   gaits     SHAMBLE (slow, swaying, head lolling), ZRUN (hunched sprint), BRUTE (heavy, wide, slow),
##             CHARGE (the brute's run), crawl() (on the arms, legs dragging or gone)
##   carries   reach (both arms out), reach_one (one out, one dead), claw (runner), club (brute)
##   attacks   grab_bite, claw_swipe, smash (brute), leap poses (runner)
##   climbing  wall and trench poses (the tool puts the hands on the edges)
##   deaths    drop (head shot), stumble (shot, keeps going), burning, brute_down, legs_off
## Limbs: + X swings a hanging arm or a leg forward; - X on the spine bends forward.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")

const SHAMBLE := {"name": "shamble", "v": 0.55, "T": 1.75, "duty": 0.7, "hip": 0.85, "bob": 0.03, "bob_sign": 1.0,
	"lift": 0.035, "lean": 14.0, "fwd": 0.02, "hip_yaw": 12.0, "sway": 0.06, "shoulder_yaw": 9.0,
	"strike": 3.0, "push": 10.0, "width": 0.13}
const ZRUN := {"name": "zrun", "v": 4.3, "T": 0.6, "duty": 0.33, "hip": 0.83, "bob": 0.05, "bob_sign": -1.0,
	"lift": 0.22, "lean": 28.0, "fwd": 0.16, "hip_yaw": 12.0, "sway": 0.03, "shoulder_yaw": 9.0,
	"strike": 6.0, "push": 34.0, "width": 0.1}
const BRUTE := {"name": "brute_walk", "v": 0.8, "T": 1.5, "duty": 0.64, "hip": 0.86, "bob": 0.035, "bob_sign": 1.0,
	"lift": 0.07, "lean": 8.0, "fwd": 0.03, "hip_yaw": 9.0, "sway": 0.05, "shoulder_yaw": 7.0,
	"strike": 10.0, "push": 20.0, "width": 0.15}
const CHARGE := {"name": "brute_charge", "v": 2.6, "T": 0.8, "duty": 0.38, "hip": 0.85, "bob": 0.05, "bob_sign": -1.0,
	"lift": 0.16, "lean": 22.0, "fwd": 0.12, "hip_yaw": 10.0, "sway": 0.03, "shoulder_yaw": 6.0,
	"strike": 6.0, "push": 30.0, "width": 0.13}
const BRUTE_SCALE := 1.25


## What the arms do while walking.
static func carry(name: String) -> Dictionary:
	match name:
		"reach":
			return {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(72, 0, 8), B.FARM_R: Vector3(12, 0, 0), B.UARM_L: Vector3(64, 0, -10),
					B.FARM_L: Vector3(20, 0, 0), B.NECK: Vector3(6, 0, 14), B.HEAD: Vector3(4, 8, 12)}}
		"reach_one":
			return {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(70, -6, 6), B.FARM_R: Vector3(18, 0, 0), B.UARM_L: Vector3(-6, 0, -14),
					B.FARM_L: Vector3(4, 0, 0), B.NECK: Vector3(-8, 0, -18), B.HEAD: Vector3(-4, -6, -14)}}
		"limp":
			return {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(4, 0, 4), B.FARM_R: Vector3(6, 0, 0), B.UARM_L: Vector3(-4, 0, -6),
					B.FARM_L: Vector3(2, 0, 0), B.NECK: Vector3(-24, 0, 10), B.HEAD: Vector3(-10, 10, 14)}}
		"claw":
			# The runner: arms out low and forward, fingers first, head thrust out.
			return {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(48, 0, 22), B.FARM_R: Vector3(40, 0, 0), B.UARM_L: Vector3(52, 0, -22),
					B.FARM_L: Vector3(36, 0, 0), B.NECK: Vector3(18, 0, 0), B.HEAD: Vector3(12, 0, 0)}}
		"club":
			# The brute's club in the right fist, hanging and dragging forward; the left arm swinging.
			return {"rifle": {"mode": "hand", "rot": Vector3(-35, 0, 0)}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(6, 0, 12), B.FARM_R: Vector3(18, 0, 0), B.UARM_L: Vector3(14, 0, -16),
					B.FARM_L: Vector3(22, 0, 0), B.NECK: Vector3(12, 0, 0), B.HEAD: Vector3(4, 0, 0)}}
		"club_up":
			return {"rifle": {"mode": "hand", "rot": Vector3(70, 0, 0)}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(40, 0, 20), B.FARM_R: Vector3(50, 0, 0), B.UARM_L: Vector3(30, 0, -20),
					B.FARM_L: Vector3(30, 0, 0)}}
	return {}


static func gait_of(kind: String, style := "") -> Dictionary:
	var g: Dictionary
	match kind:
		"runner":
			g = Body.gait(ZRUN, carry("claw")) if style != "walk" else Body.gait(SHAMBLE, carry("claw"))
		"brute":
			g = Body.gait(CHARGE if style == "charge" else BRUTE, Rig.over(carry("club"),
				{"add": {B.SPINE: Vector3(-6, 0, 0), B.CHEST: Vector3(-4, 0, 0)}}))
			g["speed"] = float(g["speed"]) * BRUTE_SCALE
		_:
			g = Body.gait(SHAMBLE, carry("reach" if style != "one" else "reach_one") if style != "limp" else carry("limp"))
	return g


static func stand(kind: String) -> Dictionary:
	match kind:
		"runner":
			return Rig.over(Body.body("ready"), Rig.over(carry("claw"), {"add": {B.SPINE: Vector3(-14, 0, 0), B.CHEST: Vector3(-8, 0, 0)}}))
		"brute":
			return Rig.over(Body.body("stand"), Rig.over(carry("club"), {"add": {B.SPINE: Vector3(-6, 0, 0), B.CHEST: Vector3(-6, 0, 0)},
				"rot": {B.THIGH_R: Vector3(4, 0, 8), B.THIGH_L: Vector3(-2, 0, -8)}}))
	return Rig.over(Body.body("stand"), Rig.over(carry("reach"), {"add": {B.SPINE: Vector3(-8, 0, 4), B.CHEST: Vector3(-4, 0, 3)}}))


# ---------------------------------------------------------------- crawling

## Crawling on the arms with the body flat and the legs trailing: one hand reaches while the other,
## planted, drags the body up to it. In place; the unit moves at "speed".
static func crawl(samples := 24) -> Dictionary:
	var T := 2.4
	var reach := 0.62
	var near := -0.32
	var v := reach / (T * 0.5)
	var keys: Array = []
	for k in samples:
		var ph := float(k) / float(samples)
		var spec := Rig.over(Body.body("prone"), {"rifle": {"mode": "back"}, "root_rot": Vector3(-80, 0, 0),
			"root_pos": Vector3(0, 0, 0.92)})
		var rot: Dictionary = spec["rot"].duplicate()
		var hands := {}
		for side in [[1.0, "hand_r", "pole_r"], [-1.0, "hand_l", "pole_l"]]:
			var s: float = side[0]
			var hp := fposmod(ph + (0.0 if s > 0.0 else 0.5), 1.0)
			var z: float
			var y := 0.03
			if hp < 0.5:
				# Planted: the hand stays on the ground while the body slides past it.
				z = near - reach + reach * (hp / 0.5) - 0.0
				z = lerpf(near - reach, near, hp / 0.5)
			else:
				var u := (hp - 0.5) / 0.5
				z = lerpf(near, near - reach, u * u * (3.0 - 2.0 * u))
				y += 0.12 * sin(PI * u)
			hands[side[1]] = [-1, Vector3(0.24 * s, y, z - 0.55)]
			spec[side[2]] = Vector3(0.9 * s, 0.6, 0.2)
		var c := cos(TAU * ph)
		rot[B.HIPS] = Vector3(0, 6 * c, 4 * c)
		rot[B.SPINE] = Vector3(10, -6 * c, -4 * c)
		rot[B.CHEST] = Vector3(14, -6 * c, -3 * c)
		rot[B.NECK] = Vector3(36, 8 * c, 0)
		rot[B.HEAD] = Vector3(18, 6 * c, 0)
		rot[B.THIGH_R] = Vector3(-4, 0, 10 + 4 * c)
		rot[B.THIGH_L] = Vector3(-4, 0, -10 + 4 * c)
		spec["rot"] = rot
		for h in hands:
			spec[h] = hands[h]
		keys.append([ph * T, spec, "lin"])
	keys.append([T, keys[0][1], "lin"])
	return {"name": "crawl", "len": T, "loop": true, "ground": false, "speed": v, "keys": keys}


## Lying face down, the arms reaching (the start and end of a crawl, the last twitch).
static func lying(reach := 1.0) -> Dictionary:
	return Rig.over(Body.body("prone"), {"rifle": {"mode": "back"}, "root_rot": Vector3(-84, 0, 0),
		"root_pos": Vector3(0, 0, 0.92), "hand_r": [-1, Vector3(0.24, 0.03, -0.9 - 0.25 * reach)],
		"hand_l": [-1, Vector3(-0.24, 0.03, -0.75)], "pole_r": Vector3(0.9, 0.6, 0.2), "pole_l": Vector3(-0.9, 0.6, 0.2),
		"add": {B.NECK: Vector3(10, 0, 0)}})


# ---------------------------------------------------------------- attacks

## Grab and bite: lunge, hands on the victim's shoulders (model space, the victim 0.6 m ahead), pull in, bite.
static func grab_bite() -> Dictionary:
	var base := Rig.over(Body.body("ready"), {"rifle": {"mode": "back"}})
	var lunge := Rig.over(base, {"hand_r": [-1, Vector3(0.2, 1.42, -0.62)], "hand_l": [-1, Vector3(-0.2, 1.42, -0.62)],
		"pole_r": Vector3(0.8, -0.3, 0.3), "pole_l": Vector3(-0.8, -0.3, 0.3),
		"add": {B.SPINE: Vector3(-14, 0, 0), B.CHEST: Vector3(-6, 0, 0), B.NECK: Vector3(14, 0, 0)}})
	var pull := Rig.over(lunge, {"hand_r": [-1, Vector3(0.16, 1.38, -0.42)], "hand_l": [-1, Vector3(-0.16, 1.38, -0.42)]})
	var bite := Rig.over(pull, {"add": {B.SPINE: Vector3(-10, 0, 0), B.CHEST: Vector3(-8, 12, 0), B.NECK: Vector3(-28, 10, 0),
		B.HEAD: Vector3(-14, 16, 10)}})
	var shake := Rig.over(bite, {"add": {B.NECK: Vector3(0, -22, 0), B.HEAD: Vector3(6, -18, -10)}})
	return {"name": "grab_bite", "len": 2.4, "ground": true, "keys": [[0.0, base], [0.25, lunge, "out"], [0.5, pull, "smooth"],
		[0.8, bite, "out"], [1.1, shake, "smooth"], [1.4, bite, "smooth"], [1.7, shake, "smooth"], [2.0, bite, "smooth"],
		[2.4, pull, "smooth"]]}


## Two claw swipes, right then left, from high behind the shoulder down across the front.
static func claw_swipe() -> Dictionary:
	var base := Rig.over(Body.body("stance"), {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null})
	var up_r := Rig.over(base, {"hand_r": [-1, Vector3(0.36, 1.9, 0.08)], "pole_r": Vector3(0.9, 0.0, 0.3),
		"hand_l": [-1, Vector3(-0.3, 1.2, -0.35)], "add": {B.SPINE: Vector3(4, 14, 0), B.CHEST: Vector3(4, 10, 0)}})
	var down_r := Rig.over(base, {"hand_r": [-1, Vector3(-0.2, 0.95, -0.55)], "pole_r": Vector3(0.6, -0.2, 0.3),
		"hand_l": [-1, Vector3(-0.32, 1.5, 0.0)], "pole_l": Vector3(-0.9, 0.0, 0.3),
		"add": {B.SPINE: Vector3(-18, -18, 0), B.CHEST: Vector3(-8, -12, 0), B.NECK: Vector3(10, 0, 0)}})
	var up_l := Rig.over(base, {"hand_l": [-1, Vector3(-0.36, 1.9, 0.08)], "pole_l": Vector3(-0.9, 0.0, 0.3),
		"hand_r": [-1, Vector3(0.1, 1.0, -0.4)], "add": {B.SPINE: Vector3(2, -10, 0), B.CHEST: Vector3(2, -10, 0)}})
	var down_l := Rig.over(base, {"hand_l": [-1, Vector3(0.22, 0.95, -0.55)], "pole_l": Vector3(-0.6, -0.2, 0.3),
		"hand_r": [-1, Vector3(0.3, 1.3, -0.1)],
		"add": {B.SPINE: Vector3(-18, 16, 0), B.CHEST: Vector3(-8, 12, 0), B.NECK: Vector3(10, 0, 0)}})
	return {"name": "claw_swipe", "len": 1.6, "ground": true, "keys": [[0.0, base], [0.3, up_r, "smooth"], [0.5, down_r, "out"],
		[0.85, up_l, "smooth"], [1.05, down_l, "out"], [1.6, base, "smooth"]]}


## The brute's club: raised high in both hands' reach, brought down in front.
static func smash(times := 1) -> Dictionary:
	var base := Rig.over(Body.body("stance"), carry("club"))
	var up := Rig.over(Body.body("stance"), {"rifle": {"mode": "hand", "rot": Vector3(100, 0, 0), "after_ik": true},
		"hand_r": [-1, Vector3(0.22, 2.08, 0.12)], "pole_r": Vector3(0.9, 0.2, 0.2),
		"hand_l": [-1, Vector3(-0.15, 1.85, -0.2)], "pole_l": Vector3(-0.9, 0.0, 0.2),
		"add": {B.SPINE: Vector3(12, 0, 0), B.CHEST: Vector3(8, 0, 0), B.NECK: Vector3(-6, 0, 0)}})
	var down := Rig.over(Body.body("ready"), {"rifle": {"mode": "hand", "rot": Vector3(-20, 0, 0), "after_ik": true},
		"hand_r": [-1, Vector3(0.12, 0.85, -0.7)], "pole_r": Vector3(0.9, -0.2, 0.2),
		"hand_l": [-1, Vector3(-0.2, 1.0, -0.45)], "pole_l": Vector3(-0.9, -0.2, 0.2),
		"add": {B.SPINE: Vector3(-30, 0, 0), B.CHEST: Vector3(-14, 0, 0), B.NECK: Vector3(20, 0, 0)}})
	var keys: Array = [[0.0, base]]
	var t := 0.0
	for k in times:
		keys.append([t + 0.55, up, "smooth"])
		keys.append([t + 0.8, down, "in"])
		keys.append([t + 1.15, down, "smooth"])
		t += 1.15
	keys.append([t + 0.5, base, "smooth"])
	return {"name": "smash", "len": t + 0.5, "ground": true, "keys": keys}


## Runner's leap: crouch to spring, then stretched out flying (the tool moves him along an arc).
static func leap_pose(stage_name: String) -> Dictionary:
	match stage_name:
		"crouch":
			return Rig.over(Body.body("kneel"), Rig.over(carry("claw"), {"rot": {B.HIPS: Vector3(0, 0, 0),
				B.THIGH_R: Vector3(70, 0, 6), B.SHIN_R: Vector3(-110, 0, 0), B.FOOT_R: Vector3(40, 0, 0),
				B.THIGH_L: Vector3(80, 0, -6), B.SHIN_L: Vector3(-115, 0, 0), B.FOOT_L: Vector3(40, 0, 0),
				B.SPINE: Vector3(-30, 0, 0), B.CHEST: Vector3(-14, 0, 0), B.NECK: Vector3(30, 0, 0)}}))
		"fly":
			return Rig.over(Body.body("stand"), {"rifle": {"mode": "back"}, "root_rot": Vector3(-55, 0, 0),
				"rot": {B.UARM_R: Vector3(165, 0, 14), B.FARM_R: Vector3(10, 0, 0), B.UARM_L: Vector3(160, 0, -14),
					B.FARM_L: Vector3(10, 0, 0), B.THIGH_R: Vector3(-20, 0, 6), B.SHIN_R: Vector3(-40, 0, 0),
					B.THIGH_L: Vector3(30, 0, -6), B.SHIN_L: Vector3(-70, 0, 0), B.NECK: Vector3(40, 0, 0),
					B.HEAD: Vector3(10, 0, 0)}})
		"land":
			return Rig.over(Body.body("kneel"), Rig.over(carry("claw"), {"add": {B.SPINE: Vector3(-24, 0, 0),
				B.NECK: Vector3(26, 0, 0)}}))
	return {}


# ---------------------------------------------------------------- climbing

## On a wall face (wall ahead, -Z): the hands on the given world points (the tool passes the top edge),
## one knee up, the toes against the wall.
static func wall_climb(knee_r := true) -> Dictionary:
	var up := 72.0
	var r := {B.THIGH_R: Vector3(up if knee_r else 12, 0, 6), B.SHIN_R: Vector3(-100 if knee_r else -20, 0, 0),
		B.FOOT_R: Vector3(20, 0, 0), B.THIGH_L: Vector3(12 if knee_r else up, 0, -6),
		B.SHIN_L: Vector3(-20 if knee_r else -100, 0, 0), B.FOOT_L: Vector3(20, 0, 0),
		B.SPINE: Vector3(4, 0, 0), B.CHEST: Vector3(4, 0, 0), B.NECK: Vector3(20, 0, 0), B.HEAD: Vector3(10, 0, 0)}
	return {"rifle": {"mode": "back"}, "rot": r, "pole_r": Vector3(0.8, 0.0, 0.4), "pole_l": Vector3(-0.8, 0.0, 0.4)}


## Belly over the top of a wall or a trench edge, legs hanging (the tool puts him on the edge).
static func over_top() -> Dictionary:
	return Rig.over(Body.body("stand"), {"rifle": {"mode": "back"}, "root_rot": Vector3(-70, 0, 0),
		"rot": {B.THIGH_R: Vector3(-60, 0, 6), B.SHIN_R: Vector3(-30, 0, 0), B.THIGH_L: Vector3(-40, 0, -6),
			B.SHIN_L: Vector3(-60, 0, 0), B.SPINE: Vector3(-20, 0, 0), B.CHEST: Vector3(-10, 0, 0),
			B.UARM_R: Vector3(120, 0, 20), B.FARM_R: Vector3(30, 0, 0), B.UARM_L: Vector3(110, 0, -20),
			B.FARM_L: Vector3(40, 0, 0), B.NECK: Vector3(40, 0, 0)}})


## Hunched on all fours pressed to a wall base: the backs the others climb.
static func heap() -> Dictionary:
	return Rig.over(Body.body("kneel"), {"rifle": {"mode": "back"},
		"rot": {B.HIPS: Vector3(0, 0, 0), B.THIGH_R: Vector3(85, 0, 8), B.SHIN_R: Vector3(-95, 0, 0), B.FOOT_R: Vector3(50, 0, 0),
			B.THIGH_L: Vector3(85, 0, -8), B.SHIN_L: Vector3(-95, 0, 0), B.FOOT_L: Vector3(50, 0, 0),
			B.SPINE: Vector3(-50, 0, 0), B.CHEST: Vector3(-24, 0, 0), B.NECK: Vector3(30, 0, 0), B.HEAD: Vector3(10, 20, 0)},
		"hand_r": [-1, Vector3(0.24, 1.15, -0.62)], "hand_l": [-1, Vector3(-0.24, 1.25, -0.62)],
		"pole_r": Vector3(0.9, 0.0, 0.3), "pole_l": Vector3(-0.9, 0.0, 0.3)})


## Clawing at a gate or a wall, hands on the surface (the tool gives them world points).
static func claw_at() -> Dictionary:
	return Rig.over(Body.body("stance"), {"rifle": {"mode": "back"}, "pole_r": Vector3(0.9, -0.2, 0.3),
		"pole_l": Vector3(-0.9, -0.2, 0.3), "add": {B.SPINE: Vector3(-6, 25, 0), B.NECK: Vector3(14, -20, 0)}})


# ---------------------------------------------------------------- hits and deaths

## Shot but it keeps coming: a jerk back and a stagger, then the walk again.
static func stumble(from: Dictionary) -> Dictionary:
	var jerk := Rig.over(from, {"add": {B.CHEST: Vector3(20, 10, 0), B.SPINE: Vector3(10, 0, 4), B.NECK: Vector3(20, 0, 0),
		B.HEAD: Vector3(16, -14, 10), B.THIGH_R: Vector3(-10, 0, 4)}})
	var lurch := Rig.over(from, {"add": {B.CHEST: Vector3(-12, -6, 0), B.SPINE: Vector3(-10, 0, -4), B.NECK: Vector3(-14, 0, 0)}})
	return {"name": "stumble", "len": 1.0, "ground": true, "keys": [[0.0, from], [0.08, jerk, "out"], [0.45, lurch, "smooth"],
		[1.0, from, "smooth"]]}


## Head shot: the head snaps back and it drops on the spot, knees first, then face down.
static func drop(from: Dictionary) -> Dictionary:
	var snap := Rig.over(from, {"add": {B.NECK: Vector3(34, 0, 0), B.HEAD: Vector3(26, 12, 10), B.CHEST: Vector3(8, 0, 0)}})
	var knees := Rig.over(Body.body("stand"), {"rifle": {"mode": "back"},
		"rot": {B.THIGH_R: Vector3(30, 0, 6), B.SHIN_R: Vector3(-120, 0, 0), B.FOOT_R: Vector3(50, 0, 0),
			B.THIGH_L: Vector3(26, 0, -6), B.SHIN_L: Vector3(-118, 0, 0), B.FOOT_L: Vector3(50, 0, 0),
			B.SPINE: Vector3(-10, 0, 6), B.CHEST: Vector3(-8, 0, 0), B.NECK: Vector3(30, 0, 14), B.HEAD: Vector3(20, 0, 10),
			B.UARM_R: Vector3(4, 0, 14), B.UARM_L: Vector3(4, 0, -14)}})
	var down := Rig.over(Body.body("stand"), {"rifle": {"mode": "back"}, "root_rot": Vector3(-88, 0, 6),
		"root_pos": Vector3(0, 0, 0.6),
		"rot": {B.THIGH_R: Vector3(6, 0, 10), B.SHIN_R: Vector3(-20, 0, 0), B.FOOT_R: Vector3(40, 0, 0),
			B.THIGH_L: Vector3(2, 0, -6), B.SHIN_L: Vector3(-14, 0, 0), B.FOOT_L: Vector3(45, 0, 0),
			B.NECK: Vector3(8, 0, 0), B.HEAD: Vector3(4, -70, 0), B.UARM_R: Vector3(20, 0, 20), B.FARM_R: Vector3(10, 0, 0),
			B.UARM_L: Vector3(150, 0, -30), B.FARM_L: Vector3(20, 0, 0)}})
	return {"name": "drop", "len": 1.5, "ground": true, "keys": [[0.0, from], [0.06, snap, "out"], [0.42, knees, "in"],
		[0.85, down, "in"], [0.98, Rig.over(down, {"root_rot": Vector3(-84, 0, 6)}), "out"], [1.12, down, "smooth"], [1.5, down]]}


## Legs shot from under it: it pitches forward onto its hands and lies there (the tool then makes it crawl).
static func legs_off(from: Dictionary) -> Dictionary:
	var buckle := Rig.over(from, {"rot": {B.THIGH_R: Vector3(-10, 0, 10), B.SHIN_R: Vector3(-40, 0, 0),
		B.THIGH_L: Vector3(20, 0, -10), B.SHIN_L: Vector3(-60, 0, 0)}, "add": {B.SPINE: Vector3(-20, 0, 0)}})
	var fall := Rig.over(lying(0.2), {"root_rot": Vector3(-50, 0, 0), "root_pos": Vector3(0, 0, 0.5)})
	return {"name": "legs_off", "len": 1.2, "ground": true, "keys": [[0.0, from], [0.12, buckle, "out"], [0.55, fall, "in"],
		[0.75, lying(0.0), "in"], [0.9, Rig.over(lying(0.0), {"root_rot": Vector3(-80, 0, 0)}), "out"], [1.2, lying(0.3), "smooth"]]}


## On fire: arms flailing over the head, staggering, then down on its knees and over on its face.
static func burning() -> Dictionary:
	var a := Rig.over(Body.body("stance"), {"rifle": {"mode": "back"}, "hand_r": [-1, Vector3(0.3, 1.95, -0.1)],
		"hand_l": [-1, Vector3(-0.35, 1.6, -0.35)], "pole_r": Vector3(0.9, 0.0, 0.3), "pole_l": Vector3(-0.9, 0.0, 0.3),
		"add": {B.SPINE: Vector3(8, 16, 6), B.NECK: Vector3(26, 0, 10), B.HEAD: Vector3(10, 10, 0)}})
	var b := Rig.over(Body.body("stance"), {"rifle": {"mode": "back"}, "hand_l": [-1, Vector3(-0.3, 1.95, -0.1)],
		"hand_r": [-1, Vector3(0.35, 1.5, -0.4)], "pole_r": Vector3(0.9, 0.0, 0.3), "pole_l": Vector3(-0.9, 0.0, 0.3),
		"add": {B.SPINE: Vector3(-6, -18, -6), B.NECK: Vector3(20, 0, -14), B.HEAD: Vector3(6, -10, 0)}})
	var kneel := Rig.over(Body.body("stand"), {"rifle": {"mode": "back"},
		"rot": {B.THIGH_R: Vector3(20, 0, 6), B.SHIN_R: Vector3(-110, 0, 0), B.FOOT_R: Vector3(50, 0, 0),
			B.THIGH_L: Vector3(14, 0, -6), B.SHIN_L: Vector3(-108, 0, 0), B.FOOT_L: Vector3(50, 0, 0),
			B.SPINE: Vector3(-20, 0, 0), B.NECK: Vector3(-30, 0, 0), B.UARM_R: Vector3(60, 0, 30), B.FARM_R: Vector3(90, 0, 0),
			B.UARM_L: Vector3(60, 0, -30), B.FARM_L: Vector3(90, 0, 0)}})
	var down: Dictionary = drop(kneel)["keys"][3][1]
	return {"name": "burning", "len": 4.6, "ground": true, "keys": [[0.0, a], [0.35, b, "smooth"], [0.7, a, "smooth"],
		[1.05, b, "smooth"], [1.4, a, "smooth"], [1.8, b, "smooth"], [2.3, kneel, "in"], [2.9, kneel, "smooth"],
		[3.5, down, "in"], [3.7, Rig.over(down, {"root_rot": Vector3(-84, 0, 6)}), "out"], [4.6, down, "smooth"]]}


## The brute takes hits: a flinch each time, then slowly to its knees, the club dropping, and over on its face.
static func brute_down(from: Dictionary, hits := 3) -> Dictionary:
	var keys: Array = [[0.0, from]]
	var t := 0.0
	for k in hits:
		var j := Rig.over(from, {"add": {B.CHEST: Vector3(14, 8 * (1 - 2 * (k % 2)), 0), B.SPINE: Vector3(6, 0, 0),
			B.NECK: Vector3(14, 0, 0), B.HEAD: Vector3(10, 0, 0)}})
		keys.append([t + 0.08, j, "out"])
		keys.append([t + 0.6, from, "smooth"])
		t += 0.9
	var kneel := Rig.over(Body.body("stand"), {"rifle": {"mode": "hand", "rot": Vector3(-60, 0, 0)},
		"rot": {B.THIGH_R: Vector3(10, 0, 8), B.SHIN_R: Vector3(-100, 0, 0), B.FOOT_R: Vector3(50, 0, 0),
			B.THIGH_L: Vector3(70, 0, -8), B.SHIN_L: Vector3(-80, 0, 0), B.FOOT_L: Vector3(0, 0, 0),
			B.SPINE: Vector3(-14, 0, 0), B.CHEST: Vector3(-8, 0, 0), B.NECK: Vector3(-16, 0, 0),
			B.UARM_R: Vector3(10, 0, 18), B.FARM_R: Vector3(10, 0, 0), B.UARM_L: Vector3(40, 0, -8), B.FARM_L: Vector3(30, 0, 0)}})
	# The club let go: it lies on the ground beside the right hip, along the body (it must not prop the body up).
	var down: Dictionary = Rig.over(drop(kneel)["keys"][3][1], {"rifle": {"mode": "bone", "bone": B.HIPS, "at": Vector3(0.42, 0.98, 0.02),
		"rot": Vector3(90, 0, 0)}})
	keys.append([t + 0.8, kneel, "in"])
	keys.append([t + 1.6, kneel, "smooth"])
	keys.append([t + 2.2, down, "in"])
	keys.append([t + 2.35, Rig.over(down, {"root_rot": Vector3(-84, 0, 6)}), "out"])
	keys.append([t + 3.0, down, "smooth"])
	return {"name": "brute_down", "len": t + 3.0, "ground": true, "keys": keys, "drop_club": t + 0.5}
