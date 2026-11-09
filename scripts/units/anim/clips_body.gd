extends RefCounted
## The shared body library (Question Chat, animation round 1, 2026-11-09).
## Body poses and cycles that every unit on the soldier skeleton uses. They know
## nothing about what the hands hold: each takes "carry" specs (from an item file,
## such as clips_rifle.gd) laid over the body. A new unit type reuses all of this
## and only brings its own carries, a style (stride, lean, speed) and its own extras.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")


## Body-only poses.
static func body(name: String) -> Dictionary:
	match name:
		"stand":
			return {"rot": {B.THIGH_R: Vector3(0, 0, 3), B.THIGH_L: Vector3(0, 0, -3), B.FOOT_R: Vector3(0, 0, -3),
				B.FOOT_L: Vector3(0, 0, 3), B.SPINE: Vector3(-2, 0, 0), B.CHEST: Vector3(2, 0, 0),
				B.UARM_L: Vector3(2, 0, -5), B.FARM_L: Vector3(8, 0, 0)}}
		"ready":
			return {"rot": {B.THIGH_R: Vector3(10, 0, 4), B.SHIN_R: Vector3(-16, 0, 0), B.FOOT_R: Vector3(6, 0, -4),
				B.THIGH_L: Vector3(16, 8, -4), B.SHIN_L: Vector3(-14, 0, 0), B.FOOT_L: Vector3(-2, -8, 4),
				B.SPINE: Vector3(-7, 0, 0), B.CHEST: Vector3(-3, 0, 0), B.NECK: Vector3(6, 0, 0), B.HEAD: Vector3(4, 0, 0)}}
		"stance":
			return {"rot": {B.HIPS: Vector3(0, -25, 0), B.THIGH_R: Vector3(-4, 0, 5), B.SHIN_R: Vector3(-2, 0, 0),
				B.THIGH_L: Vector3(10, 20, -4), B.SHIN_L: Vector3(-6, 0, 0), B.SPINE: Vector3(-8, 0, 0),
				B.CHEST: Vector3(-4, -8, 0), B.NECK: Vector3(-10, 14, 0), B.HEAD: Vector3(-8, 10, -14)}}
		"kneel":
			return {"rot": {B.HIPS: Vector3(0, -28, 0), B.THIGH_R: Vector3(-8, 0, 4), B.SHIN_R: Vector3(-85, 0, 0),
				B.FOOT_R: Vector3(55, 0, 0), B.THIGH_L: Vector3(82, 22, -4), B.SHIN_L: Vector3(-84, 0, 0),
				B.FOOT_L: Vector3(2, 0, 0), B.SPINE: Vector3(-9, 0, 0), B.CHEST: Vector3(-5, -8, 0),
				B.NECK: Vector3(-10, 16, 0), B.HEAD: Vector3(-8, 10, -14)}}
		"prone":
			return {"root_rot": Vector3(-90, 0, 0), "root_pos": Vector3(0, 0, 0.95),
				"rot": {B.THIGH_R: Vector3(0, 0, 9), B.THIGH_L: Vector3(0, 0, -9), B.FOOT_R: Vector3(0, -15, 0),
				B.FOOT_L: Vector3(0, 15, 0), B.SPINE: Vector3(14, 0, 0), B.CHEST: Vector3(16, 0, 0),
				B.NECK: Vector3(30, 0, 0), B.HEAD: Vector3(22, 0, -6)}}
		"run":
			return {"rot": {B.SPINE: Vector3(-12, 0, 0), B.CHEST: Vector3(-6, 0, 0), B.NECK: Vector3(8, 0, 0),
				B.HEAD: Vector3(10, 0, 0), B.THIGH_R: Vector3(42, 0, 2), B.SHIN_R: Vector3(-38, 0, 0),
				B.FOOT_R: Vector3(12, 0, 0), B.THIGH_L: Vector3(-28, 0, -2), B.SHIN_L: Vector3(-78, 0, 0),
				B.FOOT_L: Vector3(-25, 0, 0)}}
	return {}


static func pose(body_name: String, carry: Dictionary) -> Dictionary:
	return Rig.over(body(body_name), carry)


# ---------------------------------------------------------------- walking and running

## Gait styles. A unit type changes these numbers to walk its own way
## (an officer upright and slower, MG carriers heavy and short-stepped).
const WALK := {"name": "walk", "v": 1.35, "T": 1.0, "duty": 0.6, "hip": 0.87, "bob": 0.022, "bob_sign": 1.0,
	"lift": 0.08, "lean": 5.0, "fwd": 0.03, "hip_yaw": 7.0, "sway": 0.022, "shoulder_yaw": 3.0,
	"strike": 14.0, "push": 28.0, "width": 0.095}
const RUN := {"name": "run", "v": 3.7, "T": 0.64, "duty": 0.34, "hip": 0.88, "bob": 0.035, "bob_sign": -1.0,
	"lift": 0.2, "lean": 14.0, "fwd": 0.11, "hip_yaw": 10.0, "sway": 0.018, "shoulder_yaw": 5.0,
	"strike": 6.0, "push": 34.0, "width": 0.085}


static func _foot_raise(pitch: float) -> float:
	# Toe down lifts the ankle around the toe; toe up lifts it around the heel.
	if pitch > 0.0:
		return 0.165 * sin(pitch * Rig.DEG)
	return 0.08 * sin(-pitch * Rig.DEG)


## An in-place walk or run cycle: the feet follow paths by leg IK, so they stay
## planted while the unit moves at "v" metres a second.
static func gait(p: Dictionary, carry: Dictionary, samples := 20) -> Dictionary:
	var T: float = p["T"]
	var duty: float = p["duty"]
	var L: float = float(p["v"]) * duty * T
	var keys: Array = []
	for k in samples:
		var ph := float(k) / float(samples)
		var spec := carry.duplicate(true)
		var rot := {}
		for side in [[1.0, "foot_r", "fpitch_r"], [-1.0, "foot_l", "fpitch_l"]]:
			var s: float = side[0]
			var fp := fposmod(ph + (0.0 if s > 0.0 else 0.5), 1.0)
			var z: float
			var y: float
			var pitch: float
			if fp < duty:
				var u := fp / duty
				z = -L * 0.5 + L * u
				if u < 0.15:
					pitch = -float(p["strike"]) * (1.0 - u / 0.15)
				elif u > 0.7:
					pitch = float(p["push"]) * (u - 0.7) / 0.3
				else:
					pitch = 0.0
				y = 0.09 + _foot_raise(pitch)
			else:
				var u := (fp - duty) / (1.0 - duty)
				var e := u * u * (3.0 - 2.0 * u)
				z = L * 0.5 - L * e
				pitch = lerpf(float(p["push"]), -float(p["strike"]), e)
				y = 0.09 + _foot_raise(pitch) + float(p["lift"]) * sin(PI * pow(u, 0.75))
			spec[side[1]] = Vector3(float(p["width"]) * s, y, z + float(p["fwd"]))
			spec[side[2]] = pitch
		var c1 := cos(TAU * ph)
		var mid := ph - duty * 0.5
		var hip_y: float = float(p["hip"]) + float(p["bob_sign"]) * float(p["bob"]) * cos(2.0 * TAU * mid)
		spec["root_pos"] = Vector3(float(p["sway"]) * cos(TAU * mid), hip_y - 0.95, 0)
		var lean: float = p["lean"]
		var hy: float = float(p["hip_yaw"]) * c1
		var sy: float = float(p["shoulder_yaw"]) * c1
		rot[B.HIPS] = Vector3(-lean * 0.35, hy, 0)
		rot[B.SPINE] = Vector3(-lean * 0.4, -hy * 0.6, 0)
		rot[B.CHEST] = Vector3(-lean * 0.25, -hy * 0.4 - sy, 0)
		rot[B.NECK] = Vector3(lean * 0.55, sy * 0.6, 0)
		rot[B.HEAD] = Vector3(lean * 0.45, sy * 0.4, 0)
		var cr: Dictionary = carry.get("rot", {})
		for bn in cr:
			rot[bn] = rot.get(bn, Vector3.ZERO) + cr[bn]
		spec["rot"] = rot
		keys.append([ph * T, spec, "lin"])
	keys.append([T, keys[0][1], "lin"])
	return {"name": p["name"], "len": T, "loop": true, "ground": false, "speed": p["v"], "keys": keys}


# ---------------------------------------------------------------- getting down and up

static func stand_to_kneel(ready: Dictionary, kneel: Dictionary) -> Dictionary:
	return {"name": "stand_to_kneel", "len": 0.7, "keys": [[0.0, ready], [0.38, kneel, "out"], [0.7, kneel]]}


static func kneel_to_stand(kneel: Dictionary, ready: Dictionary) -> Dictionary:
	return {"name": "kneel_to_stand", "len": 0.75, "keys": [[0.0, kneel], [0.12, kneel], [0.55, ready, "smooth"], [0.75, ready]]}


## Drops to the left hand and a knee, then flat. carry_drop holds the item while
## going down (port arms in one hand), prone is the finished pose.
static func stand_to_prone(ready: Dictionary, carry_drop: Dictionary, prone: Dictionary) -> Dictionary:
	var knee := Rig.over(Rig.over(body("kneel"), carry_drop), {
		"add": {B.SPINE: Vector3(-22, 0, 0), B.CHEST: Vector3(-12, 8, 0), B.HIPS: Vector3(0, 28, 0),
			B.NECK: Vector3(12, -16, 0), B.HEAD: Vector3(8, -10, 14)},
		"hand_l": [-1, Vector3(-0.22, 0.0, -0.62)], "pole_l": Vector3(-0.6, 0.2, 0.3)})
	var low := Rig.over(Rig.over(body("prone"), carry_drop), {
		"root_rot": Vector3(-62, 0, 0), "root_pos": Vector3(0, 0, 0.55),
		"rot": {B.THIGH_R: Vector3(40, 0, 8), B.SHIN_R: Vector3(-70, 0, 0), B.THIGH_L: Vector3(20, 0, -8),
			B.SHIN_L: Vector3(-40, 0, 0), B.SPINE: Vector3(8, 0, 0), B.CHEST: Vector3(6, 0, 0),
			B.NECK: Vector3(28, 0, 0), B.HEAD: Vector3(18, 0, 0)},
		"hand_l": [-1, Vector3(-0.25, 0.0, -1.05)], "pole_l": Vector3(-0.7, 0.2, 0.4)})
	return {"name": "stand_to_prone", "len": 1.25, "keys": [[0.0, ready], [0.3, knee, "out"], [0.6, low, "smooth"],
		[0.95, prone, "out"], [1.25, prone]]}


static func prone_to_stand(prone: Dictionary, carry_drop: Dictionary, ready: Dictionary) -> Dictionary:
	var push := Rig.over(Rig.over(body("prone"), carry_drop), {
		"root_rot": Vector3(-55, 0, 0), "root_pos": Vector3(0, 0, 0.6),
		"rot": {B.THIGH_R: Vector3(70, 0, 8), B.SHIN_R: Vector3(-100, 0, 0), B.THIGH_L: Vector3(10, 0, -8),
			B.SHIN_L: Vector3(-30, 0, 0), B.SPINE: Vector3(4, 0, 0), B.CHEST: Vector3(4, 0, 0),
			B.NECK: Vector3(30, 0, 0), B.HEAD: Vector3(15, 0, 0)},
		"hand_l": [-1, Vector3(-0.25, 0.0, -0.95)], "pole_l": Vector3(-0.7, 0.2, 0.4)})
	var crouch := Rig.over(Rig.over(body("kneel"), carry_drop), {
		"add": {B.SPINE: Vector3(-18, 0, 0), B.HIPS: Vector3(0, 28, 0), B.CHEST: Vector3(0, 8, 0),
			B.NECK: Vector3(10, -16, 0), B.HEAD: Vector3(8, -10, 14)},
		"hand_l": [-1, Vector3(-0.22, 0.0, -0.55)], "pole_l": Vector3(-0.6, 0.2, 0.3)})
	return {"name": "prone_to_stand", "len": 1.3, "keys": [[0.0, prone], [0.3, push, "out"], [0.65, crouch, "smooth"],
		[1.05, ready, "smooth"], [1.3, ready]]}


# ---------------------------------------------------------------- hit and death

## A flinch from a near miss or a light wound, back into the pose it started in.
static func hit(from: Dictionary) -> Dictionary:
	var jerk := Rig.over(from, {"add": {B.CHEST: Vector3(14, 6, 0), B.SPINE: Vector3(6, 0, 0),
		B.NECK: Vector3(12, 0, 0), B.HEAD: Vector3(10, -8, 6)},
		"rifle_add": {"dir": Vector3(0, 0.32, 0), "off": Vector3(0.02, -0.04, 0.08), "roll": 18.0}})
	var back := Rig.over(from, {"add": {B.CHEST: Vector3(-4, -2, 0), B.HEAD: Vector3(-3, 0, 0)}})
	return {"name": "hit", "len": 0.75, "keys": [[0.0, from], [0.07, jerk, "out"], [0.3, back, "smooth"],
		[0.55, from, "smooth"], [0.75, from]], "events": [[0.0, "hit"]]}


## Shot in the chest, thrown back onto his back. carry_fall holds the item in one hand.
static func death_back(from: Dictionary, carry_fall: Dictionary) -> Dictionary:
	var jerk := Rig.over(from, {"add": {B.CHEST: Vector3(22, 8, 0), B.SPINE: Vector3(10, 0, 0),
		B.NECK: Vector3(18, 0, 0), B.HEAD: Vector3(14, -10, 8)},
		"rifle_add": {"dir": Vector3(0, 0.25, 0), "off": Vector3(0.03, -0.05, 0.1), "roll": 25.0}})
	var buckle := Rig.over(Rig.over(body("stand"), carry_fall), {
		"root_rot": Vector3(18, 0, 4),
		"rot": {B.THIGH_R: Vector3(30, 0, 6), B.SHIN_R: Vector3(-55, 0, 0), B.THIGH_L: Vector3(22, 0, -8),
			B.SHIN_L: Vector3(-40, 0, 0), B.SPINE: Vector3(14, 0, 0), B.CHEST: Vector3(16, 10, 0),
			B.NECK: Vector3(25, 0, 0), B.HEAD: Vector3(25, 0, 10),
			B.UARM_R: Vector3(40, 0, 25), B.FARM_R: Vector3(30, 0, 0), B.UARM_L: Vector3(60, 0, -40),
			B.FARM_L: Vector3(25, 0, 0)}})
	var down := Rig.over(Rig.over(body("stand"), carry_fall), {
		"root_rot": Vector3(90, 0, 6), "root_pos": Vector3(0, 0, -0.25),
		"rot": {B.THIGH_R: Vector3(14, 0, 10), B.SHIN_R: Vector3(-22, 0, 0), B.FOOT_R: Vector3(-20, 0, 0),
			B.THIGH_L: Vector3(4, 0, -12), B.SHIN_L: Vector3(-6, 0, 0), B.FOOT_L: Vector3(-30, 0, 0),
			B.SPINE: Vector3(6, 0, 0), B.CHEST: Vector3(4, 8, 0), B.NECK: Vector3(8, 0, 0), B.HEAD: Vector3(0, -35, 8),
			B.UARM_R: Vector3(100, 0, 55), B.FARM_R: Vector3(40, 0, 0), B.UARM_L: Vector3(120, 0, -60),
			B.FARM_L: Vector3(30, 0, 0)}})
	var settle := Rig.over(down, {"root_rot": Vector3(86, 0, 6), "add": {B.HEAD: Vector3(6, 0, 0),
		B.THIGH_R: Vector3(4, 0, 0)}})
	return {"name": "death_back", "len": 1.9, "keys": [[0.0, from], [0.08, jerk, "out"], [0.38, buckle, "smooth"],
		[0.82, down, "in"], [0.96, settle, "out"], [1.12, down, "smooth"], [1.9, down]], "events": [[0.0, "hit"]]}


## Hit and crumples: knees, then face down.
static func death_forward(from: Dictionary, carry_fall: Dictionary) -> Dictionary:
	var jerk := Rig.over(from, {"add": {B.SPINE: Vector3(-18, 0, 0), B.CHEST: Vector3(-14, -6, 0),
		B.NECK: Vector3(-12, 0, 0), B.HEAD: Vector3(-10, 6, 0)},
		"rifle_add": {"dir": Vector3(0, -0.4, 0), "roll": -20.0}})
	var knees := Rig.over(Rig.over(body("stand"), carry_fall), {
		"rot": {B.THIGH_R: Vector3(8, 0, 6), B.SHIN_R: Vector3(-95, 0, 0), B.FOOT_R: Vector3(40, 0, 0),
			B.THIGH_L: Vector3(2, 0, -6), B.SHIN_L: Vector3(-92, 0, 0), B.FOOT_L: Vector3(40, 0, 0),
			B.SPINE: Vector3(-28, 0, 0), B.CHEST: Vector3(-18, -8, 0), B.NECK: Vector3(-20, 0, 0),
			B.HEAD: Vector3(-15, 10, 0), B.UARM_R: Vector3(25, 0, 10), B.FARM_R: Vector3(35, 0, 0),
			B.UARM_L: Vector3(10, 0, -8), B.FARM_L: Vector3(20, 0, 0)}})
	var down := Rig.over(Rig.over(body("stand"), carry_fall), {
		"root_rot": Vector3(-88, 0, -4), "root_pos": Vector3(0, 0, 0.55),
		"rot": {B.THIGH_R: Vector3(4, 0, 10), B.SHIN_R: Vector3(-15, 0, 0), B.FOOT_R: Vector3(40, 0, 0),
			B.THIGH_L: Vector3(2, 0, -8), B.SHIN_L: Vector3(-8, 0, 0), B.FOOT_L: Vector3(45, 0, 0),
			B.SPINE: Vector3(4, 0, 0), B.CHEST: Vector3(2, 0, 0), B.NECK: Vector3(10, 0, 0), B.HEAD: Vector3(5, 70, 0),
			B.UARM_R: Vector3(168, 0, 25), B.FARM_R: Vector3(10, 0, 0), B.UARM_L: Vector3(-10, 0, -22),
			B.FARM_L: Vector3(10, 0, 0)}})
	var settle := Rig.over(down, {"root_rot": Vector3(-84, 0, -4)})
	return {"name": "death_forward", "len": 2.1, "keys": [[0.0, from], [0.1, jerk, "out"], [0.5, knees, "in"],
		[1.0, down, "in"], [1.12, settle, "out"], [1.3, down, "smooth"], [2.1, down]], "events": [[0.0, "hit"]]}
