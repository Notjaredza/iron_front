extends RefCounted
## The four troop types' own part (Question Chat, 2026-11-09). Everything else they do
## (walk, run, kneel, prone, fire, reload, deaths) is the rifleman's set from
## clips_body.gd and clips_rifle.gd, since every new weapon keeps the rifle's grips.
## New here: the trench club carries, the grenade throw, the spotter's binoculars and
## pointing lying down, the LMG burst and bipod, and the mortar crew's places.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
const C := preload("res://scripts/units/anim/clips_mg.gd")
const O := preload("res://scripts/units/anim/clips_officer.gd")

const BAG_R := Vector3(0.19, 1.07, -0.03)  # the right grenade bag's mouth (rest model space, hips)
const ARMS_FREE := {B.UARM_R: Vector3(2, 0, 5), B.FARM_R: Vector3(8, 0, 0), B.UARM_L: Vector3(2, 0, -5), B.FARM_L: Vector3(8, 0, 0)}


static func carry(name: String) -> Dictionary:
	match name:
		"club":
			# Club in the right fist, head up and forward, swinging with the stride.
			return {"rifle": {"mode": "hand", "rot": Vector3(55, 0, 0)}, "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(-10, 0, 8), B.FARM_R: Vector3(-55, 0, 0), B.UARM_L: Vector3(2, 0, -5), B.FARM_L: Vector3(8, 0, 0)}}
		"club_up":
			# Raised over the right shoulder, ready to strike.
			return {"rifle": {"mode": "hand", "rot": Vector3(80, 0, 0), "after_ik": true},
				"hand_r": [B.CHEST, Vector3(0.27, 1.62, 0.02)], "pole_r": Vector3(0.9, -0.2, 0.2), "hand_l": null,
				"rot": {B.UARM_L: Vector3(-30, 0, -10), B.FARM_L: Vector3(-50, 0, 0)}}
		"slung":
			return {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null, "rot": ARMS_FREE}
		"pistol_low":
			return {"rifle": O.pistol("low"), "hand_r": null, "hand_l": null,
				"rot": {B.UARM_R: Vector3(-14, 0, 8), B.FARM_R: Vector3(-40, 0, 0), B.UARM_L: Vector3(2, 0, -5), B.FARM_L: Vector3(8, 0, 0)}}
	return {}


# ---------------------------------------------------------------- the grenade throw

## The throw, standing: reach into the bag, wind up behind the head with the left arm
## pointing, release high in front, follow through. Carbine slung meanwhile.
static func throw_pose(stage_name: String) -> Dictionary:
	var base := Rig.over(Body.body("ready"), carry("slung"))
	match stage_name:
		"reach":
			return Rig.over(base, {"hand_r": [B.HIPS, BAG_R + Vector3(0.0, 0.03, 0.0)], "pole_r": Vector3(0.8, -0.2, 0.3),
				"add": {B.SPINE: Vector3(-6, -14, 0), B.CHEST: Vector3(0, -10, 0), B.NECK: Vector3(-16, 0, 0)}})
		"wind":
			return Rig.over(Body.body("stance"), {"rifle": {"mode": "back"},
				"hand_r": [B.CHEST, Vector3(0.30, 1.80, 0.36)], "pole_r": Vector3(0.9, -0.3, 0.3),
				"hand_l": [B.CHEST, Vector3(-0.18, 1.6, -0.55)], "pole_l": Vector3(-0.8, -0.3, 0.0),
				"add": {B.SPINE: Vector3(8, -10, 0), B.CHEST: Vector3(6, -12, 0), B.NECK: Vector3(-6, 20, 0)}})
		"release":
			return Rig.over(Body.body("stance"), {"rifle": {"mode": "back"},
				"hand_r": [B.CHEST, Vector3(0.12, 1.90, -0.42)], "pole_r": Vector3(0.9, 0.2, 0.3),
				"hand_l": [B.HIPS, Vector3(-0.22, 1.05, 0.05)], "pole_l": Vector3(-0.8, -0.4, 0.3),
				"add": {B.HIPS: Vector3(0, 28, 0), B.SPINE: Vector3(-10, 10, 0), B.CHEST: Vector3(-8, 14, 0), B.NECK: Vector3(0, -12, 0)}})
		"follow":
			return Rig.over(Body.body("ready"), {"rifle": {"mode": "back"},
				"hand_r": [B.CHEST, Vector3(-0.05, 1.12, -0.40)], "pole_r": Vector3(0.7, -0.4, 0.2), "hand_l": null,
				"rot": {B.UARM_L: Vector3(2, 0, -8), B.FARM_L: Vector3(10, 0, 0)},
				"add": {B.HIPS: Vector3(0, 18, 0), B.SPINE: Vector3(-22, 6, 0), B.CHEST: Vector3(-8, 4, 0), B.NECK: Vector3(18, 0, 0)}})
	return base


## Kneeling with the club ready (raiders waiting for the rush).
static func club_kneel() -> Dictionary:
	return Rig.over(C._kneel_square({}), Rig.over(carry("club_up"), {"hand_r": [B.CHEST, Vector3(0.27, 1.5, 0.0)]}))


# ---------------------------------------------------------------- the sniper pair

static func prone_free() -> Dictionary:
	return Rig.over(Body.body("prone"), {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null})


## The spotter glassing lying down: elbows on the ground, the binoculars at the eyes.
static func prone_binos(yaw := 0.0) -> Dictionary:
	var at := B.REST[B.HEAD] + O.BINO_HELD.origin
	return Rig.over(prone_free(), {"hand_r": [B.HEAD, at + Vector3(0.045, -0.01, -0.07)],
		"hand_l": [B.HEAD, at + Vector3(-0.045, -0.01, -0.07)],
		"pole_r": Vector3(0.5, -0.9, 0.0), "pole_l": Vector3(-0.5, -0.9, 0.0),
		"add": {B.CHEST: Vector3(6, yaw * 0.3, 0), B.NECK: Vector3(10, yaw * 0.4, 0), B.HEAD: Vector3(4, yaw * 0.3, 0)}})


## The spotter pointing out the target with his right hand, the binoculars lowered in the left.
## target_dir is in the man's lying frame: -Z ahead, +Y up, +X to his right.
static func prone_point(target_dir: Vector3) -> Dictionary:
	# Lying down the chest's rest +Y runs ahead and its rest -Z points at the ground, so the
	# point is given on the chest bone: ahead -> +Y, up -> +Z.
	var d := target_dir.normalized()
	var sh := Vector3(0.2, 1.44, 0.0)
	var at := sh + Vector3(d.x, -d.z, d.y) * 0.6
	return Rig.over(prone_free(), {"hand_r": [B.CHEST, at], "pole_r": Vector3(0.6, -0.6, 0.0),
		"hand_l": [B.CHEST, Vector3(-0.1, 1.42, -0.32)], "pole_l": Vector3(-0.5, -0.9, 0.0),
		"add": {B.CHEST: Vector3(8, 6, 0), B.NECK: Vector3(10, -8, 0)}})


## The marksman's prone aim, the head down a little more to the scope.
static func sniper_aim() -> Dictionary:
	return Rig.over(R.poses()["prone"], {"add": {B.NECK: Vector3(-4, 0, 0), B.HEAD: Vector3(-6, 0, -4)},
		"rifle_add": {"off": Vector3(0, -0.03, 0)}})


# ---------------------------------------------------------------- mortar crew

## Kneeling square with the hands on given world points (the caller passes them).
static func kneel_work(lean := 14.0, turn := 0.0) -> Dictionary:
	return C._kneel_square({"add": {B.SPINE: Vector3(-lean, turn * 0.5, 0), B.CHEST: Vector3(-lean * 0.4, turn * 0.5, 0),
		B.NECK: Vector3(lean * 0.5, 0, 0)}, "rifle": {"mode": "back"},
		"pole_r": Vector3(0.6, -0.5, 0.3), "pole_l": Vector3(-0.6, -0.5, 0.3)})


## Ducked at the shot: head down and away, hands over the ears.
static func duck(base: Dictionary) -> Dictionary:
	return Rig.over(base, {"add": {B.SPINE: Vector3(-10, 0, 0), B.NECK: Vector3(-14, 22, 0), B.HEAD: Vector3(-6, 14, 8)},
		"hand_r": [B.HEAD, Vector3(0.1, 1.64, 0.0)], "hand_l": [B.HEAD, Vector3(-0.1, 1.64, 0.0)],
		"pole_r": Vector3(0.8, 0.0, 0.3), "pole_l": Vector3(-0.8, 0.0, 0.3)})
