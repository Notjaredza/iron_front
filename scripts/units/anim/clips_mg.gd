extends RefCounted
## The heavy MG team's own part (Question Chat, 2026-11-09). Like clips_rifle.gd it
## only adds what is new: how the loads are carried, a heavier run and a crouched
## run, and the crew poses at the gun. Bodies, walking, kneeling and falls all
## come from clips_body.gd. Hands that hold the gun are given as world points by
## whoever places the gun (the gun moves, the hands follow by IK).

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const MG := preload("res://scripts/units/mg_builder.gd")

## Where loads sit on the shoulder (chest bone frame).
const GUN_ON_SHOULDER := Transform3D(Basis(Vector3.RIGHT, 0.14), Vector3(0.17, 0.30, 0.22))
const TRIPOD_ON_SHOULDER := Transform3D(Basis(Vector3.RIGHT, -0.24), Vector3(-0.17, 0.25, 0.1))

## Heavier and lower than the rifleman's run; the crouched dash used under fire.
const RUN_LOADED := {"name": "run_loaded", "v": 3.0, "T": 0.7, "duty": 0.38, "hip": 0.86, "bob": 0.03, "bob_sign": -1.0,
	"lift": 0.14, "lean": 16.0, "fwd": 0.1, "hip_yaw": 8.0, "sway": 0.03, "shoulder_yaw": 3.0,
	"strike": 6.0, "push": 30.0, "width": 0.1}
const CROUCH := {"name": "crouch_run", "v": 2.6, "T": 0.62, "duty": 0.42, "hip": 0.74, "bob": 0.025, "bob_sign": -1.0,
	"lift": 0.13, "lean": 30.0, "fwd": 0.12, "hip_yaw": 8.0, "sway": 0.02, "shoulder_yaw": 4.0,
	"strike": 6.0, "push": 30.0, "width": 0.11}


static func carry(name: String) -> Dictionary:
	match name:
		"free":
			return {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(2, 0, 5), B.FARM_R: Vector3(8, 0, 0), B.UARM_L: Vector3(2, 0, -5),
					B.FARM_L: Vector3(8, 0, 0)}}
		"boxes":
			return {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(0, 0, 14), B.FARM_R: Vector3(4, 0, -6), B.UARM_L: Vector3(0, 0, -14),
					B.FARM_L: Vector3(4, 0, 6)}}
		"gun":
			var c := carry("free")
			c["hand_r"] = [B.CHEST, B.REST[B.CHEST] + GUN_ON_SHOULDER * Vector3(0.0, -0.04, -0.3)]
			c["pole_r"] = Vector3(0.8, -0.5, 0.2)
			return c
		"tripod":
			var c := carry("free")
			c["hand_l"] = [B.CHEST, B.REST[B.CHEST] + TRIPOD_ON_SHOULDER * Vector3(0.0, 0.03, -0.45)]
			c["pole_l"] = Vector3(-0.8, -0.5, 0.2)
			return c
	return {}


## Where a box hangs from a hand (hand bone frame).
static func box_in_hand() -> Transform3D:
	var palm := (B.REST[B.HAND_R] - B.REST[B.FARM_R]).normalized() * B.PALM
	return Transform3D(Basis(), palm - MG.BOX_HANDLE - Vector3(0, 0.005, 0))


static func _kneel_square(extra: Dictionary) -> Dictionary:
	# The kneel body turned square to the front (its default is turned for aiming).
	var k := Rig.over(Body.body("kneel"), carry("free"))
	k = Rig.over(k, {"add": {B.HIPS: Vector3(0, 28, 0), B.CHEST: Vector3(0, 8, 0), B.NECK: Vector3(10, -16, 0),
		B.HEAD: Vector3(8, -10, 14)}})
	return Rig.over(k, extra)


## The gunner on the grips. traverse: the gun's turn in degrees (+ = to his left).
static func gunner(traverse: float, lean := 0.0) -> Dictionary:
	return _kneel_square({"add": {B.HIPS: Vector3(0, traverse * 0.45, 0), B.SPINE: Vector3(-14 - lean, traverse * 0.2, 0),
		B.CHEST: Vector3(-6, traverse * 0.25, 0), B.NECK: Vector3(8 + lean, 0, 0)},
		"pole_r": Vector3(0.5, -0.6, 0.2), "pole_l": Vector3(-0.5, -0.6, 0.2)})


## The loader kneeling at the right of the gun, facing it.
static func loader() -> Dictionary:
	return _kneel_square({"add": {B.SPINE: Vector3(-12, 0, 0), B.NECK: Vector3(4, 0, 0)},
		"pole_r": Vector3(0.4, -0.7, 0.3), "pole_l": Vector3(-0.3, -0.7, 0.4)})


## Kneeling low with the hands down to the ground in front (setting things down,
## opening the tripod, picking up).
static func kneel_reach() -> Dictionary:
	return _kneel_square({"add": {B.SPINE: Vector3(-26, 0, 0), B.CHEST: Vector3(-10, 0, 0), B.NECK: Vector3(18, 0, 0)},
		"pole_r": Vector3(0.6, -0.4, 0.3), "pole_l": Vector3(-0.6, -0.4, 0.3)})


static func nco_point() -> Dictionary:
	return _kneel_square({"add": {B.CHEST: Vector3(0, 6, 0)}, "pole_r": Vector3(0.4, -0.6, 0.3)})


static func standing(c: String) -> Dictionary:
	return Rig.over(Body.body("stand"), carry(c))


## The gunner hit at the gun: thrown back and down onto his left side.
static func gunner_death(from: Dictionary) -> Dictionary:
	var jerk := Rig.over(from, {"add": {B.CHEST: Vector3(24, 10, 0), B.SPINE: Vector3(10, 0, 0), B.NECK: Vector3(20, 0, 0),
		B.HEAD: Vector3(14, 10, 0)}, "hand_r": null, "hand_l": null})
	var down := Rig.over(Body.body("stand"), carry("free"))
	down = Rig.over(down, {"root_rot": Vector3(70, 0, 30), "root_pos": Vector3(-0.1, 0, 0.15),
		"rot": {B.THIGH_R: Vector3(70, 0, 6), B.SHIN_R: Vector3(-80, 0, 0), B.THIGH_L: Vector3(40, 0, -10),
			B.SHIN_L: Vector3(-60, 0, 0), B.SPINE: Vector3(8, 0, 0), B.CHEST: Vector3(6, 10, 0),
			B.NECK: Vector3(10, 0, 0), B.HEAD: Vector3(0, -40, 10), B.UARM_R: Vector3(90, 0, 40),
			B.FARM_R: Vector3(40, 0, 0), B.UARM_L: Vector3(30, 0, -30), B.FARM_L: Vector3(20, 0, 0)}})
	var settle := Rig.over(down, {"root_rot": Vector3(66, 0, 30)})
	return {"name": "gunner_death", "len": 1.6, "keys": [[0.0, from], [0.08, jerk, "out"], [0.6, down, "in"],
		[0.72, settle, "out"], [0.9, down, "smooth"], [1.6, down]]}
