extends RefCounted
## A field gun crew's poses (Question Chat, 2026-11-09): the layer and the breech man on
## the axle seats, the loader and ammunition numbers kneeling behind, the NCO giving the
## order to fire, everyone flinching at the shot, men lifting the trail and pushing the
## wheels. Hands mostly go on world points the caller gives (the gun's moving parts, a round).

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const C := preload("res://scripts/units/anim/clips_mg.gd")
const V := preload("res://scripts/units/anim/clips_vehicle.gd")

const SLUNG := {"mode": "back"}
const EAR_R := Vector3(0.1, 1.64, 0.0)  # rest model space, rides on the head
const EAR_L := Vector3(-0.1, 1.64, 0.0)
## Seat height above the man's feet for the axle seats (the seated pose sits 0.45 up).
const SIT_H := 0.45


## On an axle seat, leaning in to the sight (layer) or turned to the breech (breech man).
static func layer(peer := 0.0) -> Dictionary:
	return Rig.over(V.seated(), {"add": {B.SPINE: Vector3(-16 - 6 * peer, -8, 0), B.CHEST: Vector3(-8, -6, 0),
		B.NECK: Vector3(10 + 6 * peer, -10, 0), B.HEAD: Vector3(4, -6, 0)},
		"pole_r": Vector3(0.6, -0.5, 0.2), "pole_l": Vector3(-0.7, -0.3, 0.1)})


static func breech_man(turn := 1.0) -> Dictionary:
	return Rig.over(V.seated(), {"add": {B.SPINE: Vector3(-10, 12 * turn, 0), B.CHEST: Vector3(-6, 14 * turn, 0),
		B.NECK: Vector3(8, 14 * turn, 0), B.HEAD: Vector3(4, 8 * turn, 0)},
		"pole_r": Vector3(0.5, -0.6, 0.3), "pole_l": Vector3(-0.6, -0.5, 0.0)})


## Kneeling square, leaning forward by lean degrees (loader, ammunition numbers).
static func kneel(lean := 10.0, turn := 0.0) -> Dictionary:
	return C._kneel_square({"add": {B.SPINE: Vector3(-lean, turn * 0.5, 0), B.CHEST: Vector3(-lean * 0.4, turn * 0.5, 0),
		B.NECK: Vector3(lean * 0.6, 0, 0)}, "rifle": SLUNG,
		"pole_r": Vector3(0.6, -0.5, 0.3), "pole_l": Vector3(-0.6, -0.5, 0.3)})


## Crouched on both feet, bent to a low job (the ammunition box, the trail).
static func crouch(lean := 20.0) -> Dictionary:
	return Rig.over(V.crouch(), {"add": {B.SPINE: Vector3(-lean * 0.5 + 12, 0, 0), B.NECK: Vector3(-6, 0, 0)},
		"pole_r": Vector3(0.6, -0.4, 0.3), "pole_l": Vector3(-0.6, -0.4, 0.3)})


## Standing bent from the hips with both hands low (lifting the trail, gripping a wheel).
static func heave(bend := 30.0, knees := 20.0) -> Dictionary:
	return Rig.over(Body.body("stand"), {"rifle": SLUNG,
		"rot": {B.THIGH_R: Vector3(knees + bend * 0.4, 0, 6), B.THIGH_L: Vector3(knees + bend * 0.4, 0, -6),
			B.SHIN_R: Vector3(-knees * 1.6, 0, 0), B.SHIN_L: Vector3(-knees * 1.6, 0, 0),
			B.FOOT_R: Vector3(knees * 0.6, 0, -3), B.FOOT_L: Vector3(knees * 0.6, 0, 3),
			B.SPINE: Vector3(-bend * 0.6, 0, 0), B.CHEST: Vector3(-bend * 0.3, 0, 0), B.NECK: Vector3(bend * 0.6, 0, 0)},
		"pole_r": Vector3(0.7, -0.3, 0.2), "pole_l": Vector3(-0.7, -0.3, 0.2)})


## The NCO: right arm up ("ready"), then swept down to fire. beat 0 up, 1 down.
static func nco_order(beat := 0.0) -> Dictionary:
	var up := Vector3(0.24, 2.06, -0.02)
	var down := Vector3(0.3, 1.18, -0.5)
	return Rig.over(Body.body("stand"), {"rifle": SLUNG, "hand_r": [B.CHEST, up.lerp(down, beat)], "hand_l": null,
		"pole_r": Vector3(0.8, lerpf(0.0, -0.5, beat), 0.3),
		"add": {B.SPINE: Vector3(-6 * beat, 0, 0), B.NECK: Vector3(-4, -20, 0), B.HEAD: Vector3(0, -10, 0)},
		"rot": {B.UARM_L: Vector3(2, 0, -6), B.FARM_L: Vector3(10, 0, 0)}})


## Pointing the line with the right arm (target in model space), standing.
static func nco_point(target: Vector3) -> Dictionary:
	var sh := Vector3(0.2, 1.44, 0)
	var d := (target - sh).normalized()
	return Rig.over(Body.body("stand"), {"rifle": SLUNG, "hand_r": [-1, sh + d * 0.62], "hand_l": null,
		"pole_r": Vector3(0.5, -0.8, 0.0), "add": {B.CHEST: Vector3(0, atan2(-d.x, -d.z) / Rig.DEG * 0.3, 0)}})


## The shot: head turned away and ducked; free hands to the ears.
static func flinch(base: Dictionary, ears := true) -> Dictionary:
	var o := Rig.over(base, {"add": {B.NECK: Vector3(-10, 25, 0), B.HEAD: Vector3(-6, 15, 8), B.SPINE: Vector3(-4, 0, 0)}})
	if ears:
		o = Rig.over(o, {"hand_r": [B.HEAD, EAR_R], "hand_l": [B.HEAD, EAR_L],
			"pole_r": Vector3(0.8, 0.0, 0.3), "pole_l": Vector3(-0.8, 0.0, 0.3)})
	return o


## A pushing walk: bent forward, hands held out low in front (model space) on a wheel or trail.
static func push_gait(hand_r: Vector3, hand_l: Vector3, v := 0.8) -> Dictionary:
	var style := C.CROUCH.duplicate()
	style["name"] = "push"
	style["v"] = v
	style["T"] = 1.05
	style["lean"] = 22.0
	style["hip"] = 0.8
	var carry := {"rifle": SLUNG, "hand_r": [-1, hand_r], "hand_l": [-1, hand_l],
		"pole_r": Vector3(0.7, -0.4, 0.2), "pole_l": Vector3(-0.7, -0.4, 0.2)}
	return Body.gait(style, carry)
