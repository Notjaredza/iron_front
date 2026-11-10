extends RefCounted
## Red coats against our troops: the hand-to-hand moves both sides share (Building Chat 1, 2026-11-10).
## Every spec works for the musket (red coats) and our rifle: the left hand goes to that weapon's fore-end grip.
## Guard, lunge (the thrust), parry, the butt stroke (wind and strike), locked rifles (pushing), duck, leap down,
## and the knocked-down / wounded poses. Falls use the shared death clips.

const B := preload("res://scripts/units/soldier_builder.gd")
const RB := preload("res://scripts/units/redcoat_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const M := preload("res://scripts/units/anim/clips_musket.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")


static func _gl(musket: bool) -> Vector3:
	return RB.GRIP_L if musket else B.GRIP_L


static func _arms(musket: bool) -> Dictionary:
	return {"hand_r": B.GRIP_R, "pole_r": Vector3(0.6, -0.6, 0.4), "hand_l": _gl(musket), "pole_l": Vector3(-0.5, -0.8, 0.0)}


## On guard: feet apart, knees bent, the point (or muzzle) at the other man's chest.
static func guard(musket: bool) -> Dictionary:
	var s := Rig.over(Body.body("ready"), {"rifle": {"mode": "chest", "dir": Vector3(0.0, 0.32, -1.0), "up": Vector3(0, 1, 0),
		"grip": Vector3(0.2, -0.33, -0.05)}})
	return Rig.over(s, _arms(musket))


## The thrust at full stretch: a long step on the left foot, the weapon driven forward and up.
static func lunge(musket: bool) -> Dictionary:
	return Rig.over(guard(musket), {"rifle_add": {"grip": Vector3(-0.03, 0.14, -0.42), "dir": Vector3(0, 0.1, 0)},
		"rot": {B.THIGH_L: Vector3(60, 8, -4), B.SHIN_L: Vector3(-60, 0, 0), B.FOOT_L: Vector3(-4, -8, 4),
			B.THIGH_R: Vector3(-24, 0, 6), B.SHIN_R: Vector3(-10, 0, 0), B.FOOT_R: Vector3(18, 0, 0)},
		"add": {B.SPINE: Vector3(-10, 0, 0), B.CHEST: Vector3(-4, 10, 0)}, "root_pos": Vector3(0, -0.08, -0.25)})


## The parry: the weapon held across the body, high, beating the other's point aside to the left.
static func parry(musket: bool) -> Dictionary:
	var s := Rig.over(Body.body("ready"), {"rifle": {"mode": "chest", "dir": Vector3(-0.8, 0.55, -0.35), "up": Vector3(0.3, 0.5, 0.8),
		"grip": Vector3(0.2, -0.12, -0.36)}, "add": {B.CHEST: Vector3(0, 18, 0), B.SPINE: Vector3(4, 0, 0)}})
	return Rig.over(s, _arms(musket))


## The butt stroke: wound back (the muzzle down at the right side), then the butt swung up into the other's head.
static func butt_wind(musket: bool) -> Dictionary:
	var s := Rig.over(Body.body("ready"), {"rifle": {"mode": "chest", "dir": Vector3(0.25, -0.9, -0.3), "up": Vector3(0, 0, 1),
		"grip": Vector3(0.24, -0.26, -0.12)}, "add": {B.CHEST: Vector3(0, -12, 0)}})
	return Rig.over(s, _arms(musket))


static func butt_strike(musket: bool) -> Dictionary:
	var s := Rig.over(Body.body("ready"), {"rifle": {"mode": "chest", "dir": Vector3(0.05, -0.78, 0.62), "up": Vector3(0, 0.62, 0.78),
		"grip": Vector3(0.06, 0.16, -0.4)}, "add": {B.CHEST: Vector3(-6, 26, 0), B.SPINE: Vector3(-12, 0, 0)},
		"rot": {B.THIGH_L: Vector3(40, 6, -4), B.SHIN_L: Vector3(-40, 0, 0), B.THIGH_R: Vector3(-16, 0, 6)},
		"root_pos": Vector3(0, -0.04, -0.18)})
	return Rig.over(s, {"hand_r": B.GRIP_R, "pole_r": Vector3(0.6, -0.3, 0.3), "hand_l": _gl(musket), "pole_l": Vector3(-0.4, -0.9, 0.2)})


## Locked: both hold their weapons crosswise at chest height and shove, leaning in.
static func locked(musket: bool, push := 1.0) -> Dictionary:
	var s := Rig.over(Body.body("ready"), {"rifle": {"mode": "chest", "dir": Vector3(-1.0, 0.18, -0.1), "up": Vector3(0, 1, 0),
		"grip": Vector3(0.24, -0.08, -0.36)}, "add": {B.SPINE: Vector3(-14 * push, 0, 0), B.CHEST: Vector3(-6, 0, 0)},
		"rot": {B.THIGH_R: Vector3(-30, 0, 6), B.SHIN_R: Vector3(-10, 0, 0), B.THIGH_L: Vector3(40, 8, -4), B.SHIN_L: Vector3(-36, 0, 0)}})
	return Rig.over(s, {"hand_r": B.GRIP_R, "pole_r": Vector3(0.6, -0.6, 0.2), "hand_l": Vector3(0, -0.02, -0.42) if musket else Vector3(0, -0.02, -0.36),
		"pole_l": Vector3(-0.6, -0.6, 0.2)})


## Ducking under a cut or a volley: down on the knees, the head tucked, the weapon held low.
static func duck(musket: bool) -> Dictionary:
	var s := Rig.over(Body.body("kneel"), {"rifle": {"mode": "chest", "dir": Vector3(-0.3, 0.6, -0.6), "up": Vector3(0, 0.5, 0.8),
		"grip": Vector3(0.18, -0.3, -0.18)}, "add": {B.SPINE: Vector3(-30, 0, 0), B.CHEST: Vector3(-16, 0, 0), B.NECK: Vector3(-10, 0, 0)}})
	return Rig.over(s, _arms(musket))


## Leaping down into a trench: knees up, the weapon held high, the body pitched forward.
static func leap(musket: bool) -> Dictionary:
	var s := Rig.over(guard(musket), {"rot": {B.THIGH_R: Vector3(70, 0, 8), B.SHIN_R: Vector3(-90, 0, 0), B.THIGH_L: Vector3(30, 0, -8),
		B.SHIN_L: Vector3(-60, 0, 0), B.FOOT_R: Vector3(-20, 0, 0), B.FOOT_L: Vector3(-10, 0, 0)},
		"rifle_add": {"grip": Vector3(0, 0.25, 0.05), "dir": Vector3(0, 0.3, 0)}, "add": {B.SPINE: Vector3(-12, 0, 0)}})
	return s


## Hit and staggering back (the moment before a fall or a recovery).
static func reel(musket: bool) -> Dictionary:
	return Rig.over(guard(musket), {"add": {B.CHEST: Vector3(22, -12, 0), B.SPINE: Vector3(12, 0, 0), B.NECK: Vector3(20, 0, 0),
		B.HEAD: Vector3(16, 10, 8)}, "rifle_add": {"dir": Vector3(0.3, 0.5, 0), "grip": Vector3(0.08, 0.05, 0.12)},
		"rot": {B.THIGH_R: Vector3(-8, 0, 8), B.THIGH_L: Vector3(-26, 0, -6), B.SHIN_L: Vector3(-30, 0, 0)},
		"hand_l": null, "root_pos": Vector3(0, -0.04, 0.2)})


## Wounded and down on one knee, the left hand to the chest, the weapon grounded.
static func wounded(musket: bool) -> Dictionary:
	var s := Rig.over(Body.body("kneel"), {"rifle": {"mode": "order", "butt": Vector3(0.3, 0.02, -0.32)},
		"hand_r": Vector3(0, 0, -0.55), "pole_r": Vector3(0.5, -0.3, 0.4), "hand_l": [B.CHEST, Vector3(-0.02, 1.28, -0.16)],
		"pole_l": Vector3(-0.6, -0.6, 0.0), "add": {B.SPINE: Vector3(-24, 0, 0), B.NECK: Vector3(-12, 0, 0), B.HEAD: Vector3(-10, 0, 0)}})
	var _m := musket
	return s


## Firing from the shoulder: the red coats' present or our aim.
static func aim(musket: bool) -> Dictionary:
	return M.poses()["aim"] if musket else R.poses()["aim"]


## The weapon's muzzle in its own frame (where the flash goes).
static func muzzle(musket: bool) -> Vector3:
	return RB.MUZZLE if musket else Rig.MUZZLE
