extends RefCounted
## The officer's own part (Question Chat, 2026-11-09): his pistol carries, an upright
## walk, and the poses for whistle, wave on, map, binoculars, pointing and hand
## signals. Bodies, walking and kneeling come from clips_body.gd. Hand targets are
## [bone, rest point] so they ride on the body (the whistle stays at the mouth).

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")

## Rest model points.
const MOUTH := Vector3(0.0, 1.635, -0.135)
const EYES := Vector3(0.0, 1.71, -0.125)
const HOLSTER := Vector3(0.168, 1.05, -0.065)  # the pistol's grip when holstered
const MAG_POUCH := Vector3(-0.07, 1.02, -0.15)
const MAP_CASE := Vector3(-0.18, 0.95, -0.05)
const BINO_CASE := Vector3(-0.085, 1.0, -0.17)
const SHOULDER_R := Vector3(0.2, 1.44, 0.0)
const SHOULDER_L := Vector3(-0.2, 1.44, 0.0)
## Where the map sits while read (chest bone frame), and where the binoculars sit (head frame).
const MAP_HELD := Transform3D(Basis(Vector3.RIGHT, 0.75), Vector3(0.0, -0.06, -0.33))
const BINO_HELD := Transform3D(Basis(), Vector3(0.0, 0.14, -0.14))

## Upright, unhurried: a longer, slower step and a straight back.
const WALK := {"name": "officer_walk", "v": 1.3, "T": 1.08, "duty": 0.6, "hip": 0.875, "bob": 0.018, "bob_sign": 1.0,
	"lift": 0.08, "lean": 1.0, "fwd": 0.02, "hip_yaw": 6.0, "sway": 0.02, "shoulder_yaw": 2.0,
	"strike": 14.0, "push": 26.0, "width": 0.095}

const POLE_R := Vector3(0.5, -0.6, 0.3)
const POLE_L := Vector3(-0.5, -0.6, 0.3)


static func pistol(name: String) -> Dictionary:
	match name:
		"holster":
			return {"mode": "bone", "bone": B.HIPS, "at": HOLSTER, "rot": Vector3(-90, 0, 0)}
		"hand":
			return {"mode": "hand", "rot": Vector3(-114, 0, 0), "after_ik": true}
		"recoil":
			return {"mode": "hand", "rot": Vector3(-98, 0, 0), "after_ik": true}
		"low":
			return {"mode": "hand", "rot": Vector3(-35, 0, 0), "after_ik": true}
	return {}


## The officer standing: chest up, arms easy, pistol holstered.
static func stand() -> Dictionary:
	return Rig.over(Body.body("stand"), {"rifle": pistol("holster"), "hand_r": null, "hand_l": null,
		"add": {B.CHEST: Vector3(3, 0, 0), B.NECK: Vector3(-2, 0, 0)},
		"rot": {B.UARM_R: Vector3(2, 0, 6), B.FARM_R: Vector3(10, 0, 0), B.UARM_L: Vector3(2, 0, -6), B.FARM_L: Vector3(10, 0, 0)}})


static func walking() -> Dictionary:
	return {"rifle": pistol("holster"), "hand_r": null, "hand_l": null,
		"rot": {B.UARM_R: Vector3(4, 0, 6), B.FARM_R: Vector3(12, 0, 0), B.UARM_L: Vector3(4, 0, -6), B.FARM_L: Vector3(12, 0, 0)}}


static func hands(base: Dictionary, r: Variant, l: Variant, extra := {}) -> Dictionary:
	var o := Rig.over(base, {"hand_r": r, "hand_l": l, "pole_r": POLE_R, "pole_l": POLE_L})
	return Rig.over(o, extra)


# ---------------------------------------------------------------- whistle and wave on

## The whistle at the lips (right hand), the left arm raised behind ready to sweep.
static func whistle_up() -> Dictionary:
	return hands(stand(), [B.HEAD, MOUTH + Vector3(0.03, -0.01, -0.06)], [B.CHEST, Vector3(-0.32, 1.98, 0.12)],
		{"add": {B.CHEST: Vector3(6, 0, 0), B.NECK: Vector3(4, 0, 0)}, "pole_r": Vector3(0.7, -0.3, -0.1),
		"pole_l": Vector3(-0.8, 0.2, 0.4)})


## The sweep: the left arm thrown forward and down toward the enemy, the body leaning in.
static func wave_on() -> Dictionary:
	return hands(stand(), [B.HEAD, MOUTH + Vector3(0.03, -0.01, -0.06)], [B.CHEST, Vector3(-0.16, 1.5, -0.66)],
		{"add": {B.SPINE: Vector3(-8, 0, 0), B.CHEST: Vector3(-6, -6, 0), B.NECK: Vector3(6, 0, 0)},
		"pole_r": Vector3(0.7, -0.3, -0.1), "pole_l": Vector3(-0.5, -0.5, 0.2)})


# ---------------------------------------------------------------- map and binoculars

static func reach_map_case() -> Dictionary:
	return hands(stand(), [B.HIPS, MAP_CASE + Vector3(0.0, 0.05, -0.04)], null,
		{"add": {B.SPINE: Vector3(-6, -10, 0), B.CHEST: Vector3(-4, -8, 0), B.NECK: Vector3(-10, -10, 0)},
		"pole_r": Vector3(0.3, -0.6, -0.3)})


## Reading the map held in both hands at the chest, head down.
static func read_map() -> Dictionary:
	var r := B.REST[B.CHEST] + MAP_HELD * Vector3(0.2, 0.0, 0.1)
	var l := B.REST[B.CHEST] + MAP_HELD * Vector3(-0.2, 0.0, 0.1)
	return hands(stand(), [B.CHEST, r], [B.CHEST, l],
		{"add": {B.NECK: Vector3(-22, 0, 0), B.HEAD: Vector3(-14, 0, 0), B.SPINE: Vector3(-4, 0, 0)}})


## Map in the left hand, the right finger on it, then looking up toward a spot.
static func map_check(look_yaw: float) -> Dictionary:
	var l := B.REST[B.CHEST] + MAP_HELD * Vector3(-0.2, 0.0, 0.1)
	var r := B.REST[B.CHEST] + MAP_HELD * Vector3(0.05, 0.03, -0.04)
	return hands(stand(), [B.CHEST, r], [B.CHEST, l],
		{"add": {B.NECK: Vector3(-2, look_yaw * 0.5, 0), B.HEAD: Vector3(0, look_yaw * 0.5, 0)}})


static func reach_binos() -> Dictionary:
	return hands(stand(), [B.HIPS, BINO_CASE + Vector3(0.03, 0.04, -0.03)], [B.HIPS, BINO_CASE + Vector3(-0.03, 0.04, -0.03)],
		{"add": {B.NECK: Vector3(-24, 0, 0), B.SPINE: Vector3(-5, 0, 0)}})


## Glassing the front: elbows up, the binoculars at the eyes. yaw turns the upper body.
static func binos(yaw: float, pitch := 0.0) -> Dictionary:
	var at := B.REST[B.HEAD] + BINO_HELD.origin
	return hands(stand(), [B.HEAD, at + Vector3(0.045, -0.01, -0.07)], [B.HEAD, at + Vector3(-0.045, -0.01, -0.07)],
		{"add": {B.SPINE: Vector3(0, yaw * 0.25, 0), B.CHEST: Vector3(2, yaw * 0.35, 0), B.NECK: Vector3(pitch, yaw * 0.2, 0),
			B.HEAD: Vector3(pitch * 0.5, yaw * 0.2, 0)},
		"pole_r": Vector3(0.9, -0.1, 0.0), "pole_l": Vector3(-0.9, -0.1, 0.0)})


# ---------------------------------------------------------------- pistol

static func draw_reach() -> Dictionary:
	return Rig.over(hands(stand(), [B.HIPS, HOLSTER + Vector3(0.0, 0.02, 0.0)], null), {"rifle": pistol("holster"),
		"pole_r": Vector3(0.7, -0.2, 0.4)})


## Aimed one-handed, the left hand on the hip; a little bladed to the target.
static func aim(recoil := false) -> Dictionary:
	var at := Vector3(0.1, 1.47, -0.6) + (Vector3(0, 0.045, 0.03) if recoil else Vector3.ZERO)
	var o := hands(Body.body("stand"), [B.CHEST, at], [B.HIPS, Vector3(-0.2, 1.05, 0.0)],
		{"rifle": pistol("recoil" if recoil else "hand"), "pole_r": Vector3(0.6, -0.4, 0.1), "pole_l": Vector3(-0.7, 0.1, 0.4),
		"add": {B.HIPS: Vector3(0, 14, 0), B.SPINE: Vector3(0, -4, 0), B.CHEST: Vector3(2 + (2.0 if recoil else 0.0), -8, 0),
			B.NECK: Vector3(-2, -2, 0), B.HEAD: Vector3(4, 0, 0)}})
	return o


## Pistol held up in front of the chest, muzzle up, the left hand free (reloading).
static func pistol_up(left: Variant) -> Dictionary:
	return Rig.over(hands(stand(), [B.CHEST, Vector3(0.08, 1.2, -0.32)], left,
		{"add": {B.NECK: Vector3(-20, 0, 0), B.HEAD: Vector3(-8, 0, 0)}, "pole_l": Vector3(-0.5, -0.6, 0.2)}),
		{"rifle": pistol("low")})


# ---------------------------------------------------------------- pointing and signals

## Pointing at a model point (far away), the left hand cupped at the mouth calling.
static func point_call(target: Vector3, calling := true) -> Dictionary:
	var d := (target - SHOULDER_R).normalized()
	var hl: Variant = [B.HEAD, MOUTH + Vector3(-0.05, 0.0, -0.05)] if calling else null
	return hands(stand(), [-1, SHOULDER_R + d * 0.62], hl,
		{"pole_r": Vector3(0.5, -0.8, 0.0), "pole_l": Vector3(-0.8, -0.2, 0.0),
		"add": {B.CHEST: Vector3(0, atan2(-d.x, -d.z) / Rig.DEG * 0.3, 0)}})


static func hand_signal(name: String, beat := 0.0) -> Dictionary:
	match name:
		"halt":
			# Right arm straight up, fist closed.
			return hands(stand(), [B.CHEST, Vector3(0.24, 2.06, -0.02)], null, {"pole_r": Vector3(0.8, 0.0, 0.3)})
		"down":
			# Arm out in front, palm pushed down (beat 0 high, 1 low).
			return hands(stand(), [B.CHEST, Vector3(0.28, lerpf(1.36, 1.08, beat), -0.48)], null,
				{"pole_r": Vector3(0.8, -0.3, 0.2), "add": {B.SPINE: Vector3(-4 * beat, 0, 0)}})
		"follow":
			# Arm up and pumped forward over the head (beat 0 up, 1 forward).
			return hands(stand(), [B.CHEST, Vector3(0.2, lerpf(2.0, 1.75, beat), lerpf(-0.08, -0.42, beat))], null,
				{"pole_r": Vector3(0.8, 0.0, 0.2), "add": {B.CHEST: Vector3(-3 * beat, 0, 0)}})
	return stand()
