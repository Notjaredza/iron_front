extends RefCounted
## The signallers' own part (Question Chat, 2026-11-09): how the drum, phone, lamp and
## flags are carried and held, and the poses for laying wire, the phone, the splice,
## the lamp and the flags. Bodies, gaits and kneeling come from clips_body.gd (and
## the kneeling reach from clips_mg.gd, shared).

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const C := preload("res://scripts/units/anim/clips_mg.gd")
const K := preload("res://scripts/units/kit_builder.gd")

## The drum on the lineman's back board (chest bone frame, before its turn).
const DRUM_ON_BACK := Vector3(0.0, -0.02, 0.29)
## Rest model points on the head.
const EAR_L := Vector3(-0.1, 1.67, -0.01)
const MOUTH := Vector3(0.0, 1.635, -0.135)
const EYE_R := Vector3(0.035, 1.71, -0.12)
const SHOULDER_R := Vector3(0.2, 1.44, 0.0)
const SHOULDER_L := Vector3(-0.2, 1.44, 0.0)
## Where the lamp sits when sighted (head frame): its sighting tube at the right eye.
const LAMP_SIGHTED := Transform3D(Basis(), Vector3(0.035, 0.12, -0.2))

## Walking with the drum: a touch heavier.
const WALK_DRUM := {"name": "walk_drum", "v": 1.25, "T": 1.0, "duty": 0.6, "hip": 0.865, "bob": 0.022, "bob_sign": 1.0,
	"lift": 0.08, "lean": 9.0, "fwd": 0.04, "hip_yaw": 7.0, "sway": 0.024, "shoulder_yaw": 3.0,
	"strike": 12.0, "push": 28.0, "width": 0.1}


static func carry(name: String) -> Dictionary:
	match name:
		"drum":
			# Hands on the shoulder straps, the line paying out behind.
			return {"rifle": {"mode": "back"}, "hand_r": [B.CHEST, Vector3(0.11, 1.33, -0.17)], "hand_l": [B.CHEST, Vector3(-0.11, 1.33, -0.17)],
				"pole_r": Vector3(0.8, -0.6, 0.0), "pole_l": Vector3(-0.8, -0.6, 0.0)}
		"phone":
			# The phone box in the right hand by its strap, the rifle slung.
			var c := C.carry("free")
			return c
		"free":
			return C.carry("free")
	return {}


static func standing(c: String) -> Dictionary:
	return Rig.over(Body.body("stand"), carry(c))


## Kneeling square with both hands on world points given later (phone, splice).
static func kneel_work(lean := 0.0) -> Dictionary:
	return Rig.over(C.kneel_reach(), {"add": {B.SPINE: Vector3(8 - lean, 0, 0), B.NECK: Vector3(-6, 0, 0)}})


## Kneeling at the phone with the handset at his left ear, right hand free for the crank.
static func on_phone(nod := 0.0) -> Dictionary:
	return Rig.over(C._kneel_square({"add": {B.SPINE: Vector3(-10, 0, 0), B.NECK: Vector3(6 + nod * 8, -10, -6), B.HEAD: Vector3(nod * 6, -8, -8)}}),
		{"hand_l": [B.HEAD, B.REST[B.HEAD] + handset_at_ear().origin], "pole_l": Vector3(-0.8, -0.4, 0.2),
		"pole_r": Vector3(0.6, -0.6, 0.3)})


## The lamp sighted at the right eye, kneeling, both hands on it.
static func lamp_aim() -> Dictionary:
	var at := B.REST[B.HEAD] + LAMP_SIGHTED.origin
	return Rig.over(C._kneel_square({"add": {B.SPINE: Vector3(-4, 0, 0), B.NECK: Vector3(0, 0, 0)}}),
		{"hand_r": [B.HEAD, at + Vector3(0.075, -0.06, 0.02)], "hand_l": [B.HEAD, at + Vector3(-0.075, -0.06, 0.0)],
		"pole_r": Vector3(0.8, -0.4, 0.0), "pole_l": Vector3(-0.8, -0.4, 0.0)})


## Semaphore: each arm straight out at an angle from straight down (degrees, out to the side).
static func flags(right_deg: float, left_deg: float) -> Dictionary:
	var dr := Vector3(sin(deg_to_rad(right_deg)), -cos(deg_to_rad(right_deg)), -0.12).normalized()
	var dl := Vector3(-sin(deg_to_rad(left_deg)), -cos(deg_to_rad(left_deg)), -0.12).normalized()
	return Rig.over(Body.body("stand"), {"rifle": {"mode": "back"},
		"hand_r": [B.CHEST, SHOULDER_R + dr * 0.64], "hand_l": [B.CHEST, SHOULDER_L + dl * 0.64],
		"pole_r": Vector3(0, -0.2, 1.0), "pole_l": Vector3(0, -0.2, 1.0),
		"add": {B.NECK: Vector3(-3, 0, 0)}})


## The handset held to the left ear (head bone frame): ear cup on the ear, mouthpiece at the mouth.
static func handset_at_ear() -> Transform3D:
	var ear := EAR_L + Vector3(-0.025, 0.0, 0.0)
	var mouth := MOUTH + Vector3(-0.035, -0.01, -0.025)
	var xa := (mouth - ear).normalized()
	var ya := (Vector3.RIGHT - xa * xa.x).normalized()
	var bas := Basis(xa, ya, xa.cross(ya))
	return Transform3D(bas, ear - bas * K.EAR - B.REST[B.HEAD])
