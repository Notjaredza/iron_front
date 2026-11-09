extends RefCounted
## Riding in vehicles (Question Chat, 2026-11-09): sitting on a bench, the driver at the
## wheel, and the stages of climbing up into a lorry bed and jumping down from it. Any
## vehicle with a floor, benches and a step can use these (the numbers are model space,
## before the figure is set on its floor).

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const C := preload("res://scripts/units/anim/clips_mg.gd")

const SLUNG := {"mode": "back"}


## Sitting on a bench, rifle slung, hands on the knees. look turns the head (degrees).
static func seated(look := 0.0, slump := 0.0) -> Dictionary:
	return {"rifle": SLUNG,
		"rot": {B.THIGH_R: Vector3(86, 0, 5), B.THIGH_L: Vector3(86, 0, -5), B.SHIN_R: Vector3(-82, 0, 0),
			B.SHIN_L: Vector3(-82, 0, 0), B.FOOT_R: Vector3(-2, 0, 0), B.FOOT_L: Vector3(-2, 0, 0),
			B.SPINE: Vector3(2 - slump, 0, 0), B.CHEST: Vector3(-2 - slump * 0.5, 0, 0), B.NECK: Vector3(4 + slump * 0.6, look * 0.5, 0),
			B.HEAD: Vector3(slump * 0.3, look * 0.5, 0)},
		"hand_r": [-1, Vector3(0.14, 0.99, -0.34)], "hand_l": [-1, Vector3(-0.14, 0.99, -0.34)],
		"pole_r": Vector3(0.7, -0.3, 0.3), "pole_l": Vector3(-0.7, -0.3, 0.3)}


## The driver: seated upright, hands given as world points on the wheel by the caller.
static func driver() -> Dictionary:
	return Rig.over(seated(), {"add": {B.SPINE: Vector3(-4, 0, 0), B.NECK: Vector3(-4, 0, 0)},
		"pole_r": Vector3(0.6, -0.6, 0.1), "pole_l": Vector3(-0.6, -0.6, 0.1)})


## Climbing in over the tailgate (the man faces the lorry). Hands go on world points
## (the bed's rear corners) given by the caller; feet are set here.
##   0 at the step: right foot up on the step iron, reaching up
##   1 up on the step: left knee onto the bed floor
##   2 kneeling on the floor edge, about to stand up
static func climb(stage: int, step_h: float, floor_h: float) -> Dictionary:
	var base := Rig.over(Body.body("stand"), {"rifle": SLUNG, "pole_r": Vector3(0.7, -0.4, 0.2), "pole_l": Vector3(-0.7, -0.4, 0.2)})
	match stage:
		0:
			return Rig.over(base, {"foot_r": Vector3(0.1, step_h + 0.09, -0.32), "fpitch_r": 0.0,
				"foot_l": Vector3(-0.1, 0.09, 0.05), "fpitch_l": 10.0, "pole_kr": Vector3(0.1, 0, -1),
				"add": {B.SPINE: Vector3(-12, 0, 0), B.CHEST: Vector3(-6, 0, 0), B.NECK: Vector3(10, 0, 0)}})
		1:
			var up := floor_h - step_h
			return Rig.over(base, {"foot_r": Vector3(0.1, 0.09, -0.06), "fpitch_r": 0.0,
				"foot_l": Vector3(-0.1, up + 0.12, -0.42), "fpitch_l": 40.0, "pole_kl": Vector3(-0.1, 0, -1),
				"add": {B.SPINE: Vector3(-24, 0, 0), B.CHEST: Vector3(-10, 0, 0), B.NECK: Vector3(18, 0, 0)}})
		_:
			return Rig.over(C._kneel_square({"add": {B.SPINE: Vector3(-16, 0, 0), B.NECK: Vector3(12, 0, 0)}}),
				{"rifle": SLUNG, "hand_r": null, "hand_l": null})


## Bent over under the tilt, moving along the bed or about to jump.
static func stooped() -> Dictionary:
	return Rig.over(Body.body("ready"), {"rifle": SLUNG, "hand_r": null, "hand_l": null,
		"add": {B.SPINE: Vector3(-16, 0, 0), B.CHEST: Vector3(-10, 0, 0), B.NECK: Vector3(22, 0, 0), B.HEAD: Vector3(8, 0, 0)},
		"rot": {B.UARM_R: Vector3(10, 0, 10), B.FARM_R: Vector3(30, 0, 0), B.UARM_L: Vector3(10, 0, -10), B.FARM_L: Vector3(30, 0, 0)}})


## Crouched at the edge, about to drop (and the same crouch landing).
static func crouch(arms_out := 0.0) -> Dictionary:
	return {"rifle": SLUNG, "hand_r": null, "hand_l": null,
		"rot": {B.THIGH_R: Vector3(70, 0, 8), B.THIGH_L: Vector3(70, 0, -8), B.SHIN_R: Vector3(-110, 0, 0),
			B.SHIN_L: Vector3(-110, 0, 0), B.FOOT_R: Vector3(40, 0, 0), B.FOOT_L: Vector3(40, 0, 0),
			B.SPINE: Vector3(-26, 0, 0), B.CHEST: Vector3(-10, 0, 0), B.NECK: Vector3(26, 0, 0),
			B.UARM_R: Vector3(-30 * arms_out, 0, 20 + 30 * arms_out), B.FARM_R: Vector3(30, 0, 0),
			B.UARM_L: Vector3(-30 * arms_out, 0, -20 - 30 * arms_out), B.FARM_L: Vector3(30, 0, 0)}}


## In the air: legs tucked, arms out.
static func airborne() -> Dictionary:
	return {"rifle": SLUNG, "hand_r": null, "hand_l": null,
		"rot": {B.THIGH_R: Vector3(40, 0, 8), B.THIGH_L: Vector3(30, 0, -8), B.SHIN_R: Vector3(-60, 0, 0),
			B.SHIN_L: Vector3(-50, 0, 0), B.FOOT_R: Vector3(20, 0, 0), B.FOOT_L: Vector3(20, 0, 0),
			B.SPINE: Vector3(-12, 0, 0), B.NECK: Vector3(14, 0, 0),
			B.UARM_R: Vector3(-20, 0, 45), B.FARM_R: Vector3(25, 0, 0), B.UARM_L: Vector3(-20, 0, -45), B.FARM_L: Vector3(25, 0, 0)}}
