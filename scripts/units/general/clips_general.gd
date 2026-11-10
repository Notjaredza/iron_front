extends RefCounted
## The General's poses and gait (Asset Builder Chat, 2026-11-10). Built on the officer's clips (read only).
## Spec format as in anim/rig.gd. The stick is in his left hand (GeneralKit), the pistol stays holstered.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const O := preload("res://scripts/units/anim/clips_officer.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")

## A stiff parade walk: a longer, slower step, almost no bob, no shoulder swing.
const WALK := {"name": "general_walk", "v": 1.1, "T": 1.2, "duty": 0.6, "hip": 0.88, "bob": 0.008, "bob_sign": 1.0,
	"lift": 0.07, "lean": 0.0, "fwd": 0.01, "hip_yaw": 4.0, "sway": 0.012, "shoulder_yaw": 0.0,
	"strike": 16.0, "push": 22.0, "width": 0.1}

const BEHIND_R := Vector3(0.05, 0.98, 0.17)   # hands clasped at the small of the back (hips frame)
const BEHIND_L := Vector3(-0.04, 0.99, 0.18)
const BROW := Vector3(0.075, 1.75, -0.13)      # the salute (head frame)
const PODIUM_FIST := Vector3(0.14, 1.16, -0.42)  # model space, on the lectern top


## Standing: chest out, chin up, heels together.
static func stand() -> Dictionary:
	return Rig.over(O.stand(), {"add": {B.CHEST: Vector3(6, 0, 0), B.SPINE: Vector3(-2, 0, 0), B.NECK: Vector3(-5, 0, 0),
		B.HEAD: Vector3(-3, 0, 0)}, "foot_r": Vector3(0.07, 0.09, 0.0), "foot_l": Vector3(-0.07, 0.09, 0.0)})


static func _stiff(extra: Dictionary) -> Dictionary:
	return Rig.over(stand(), extra)


## Inspecting: hands behind the back, the stick across the small of the back; head turned (yaw degrees).
static func inspect(look_yaw := 0.0, nod := 0.0) -> Dictionary:
	return O.hands(stand(), [B.HIPS, BEHIND_R], [B.HIPS, BEHIND_L],
		{"pole_r": Vector3(0.7, -0.1, 0.6), "pole_l": Vector3(-0.7, -0.1, 0.6),
		"add": {B.CHEST: Vector3(6, look_yaw * 0.2, 0), B.NECK: Vector3(-5 + nod, look_yaw * 0.4, 0), B.HEAD: Vector3(-3 + nod, look_yaw * 0.4, 0)}})


## The parade walk's carry: hands behind the back.
static func walking() -> Dictionary:
	return {"rifle": O.pistol("holster"), "hand_r": [B.HIPS, BEHIND_R], "hand_l": [B.HIPS, BEHIND_L],
		"pole_r": Vector3(0.7, -0.1, 0.6), "pole_l": Vector3(-0.7, -0.1, 0.6),
		"add": {B.CHEST: Vector3(6, 0, 0), B.NECK: Vector3(-5, 0, 0)}}


static func gait() -> Dictionary:
	return Body.gait(WALK, walking())


## Taking a salute: right hand at the cap's brow, elbow out, the stick at his side.
static func salute() -> Dictionary:
	return O.hands(stand(), [B.HEAD, BROW], null, {"pole_r": Vector3(0.9, 0.1, -0.2)})


# ---------------------------------------------------------------- the speech (at the podium)

## Both fists on the lectern, leaning in.
static func speech_fists() -> Dictionary:
	return O.hands(stand(), [-1, PODIUM_FIST], [-1, PODIUM_FIST * Vector3(-1, 1, 1)],
		{"add": {B.SPINE: Vector3(-6, 0, 0), B.CHEST: Vector3(-2, 0, 0), B.NECK: Vector3(4, 0, 0)},
		"pole_r": Vector3(0.7, -0.3, 0.2), "pole_l": Vector3(-0.7, -0.3, 0.2)})


## Pounding the lectern with the right fist (beat 0 raised, 1 down), left hand gripping the edge.
static func speech_pound(beat: float) -> Dictionary:
	var f := PODIUM_FIST + Vector3(0, lerpf(0.22, 0.0, beat), lerpf(0.05, 0.0, beat))
	return O.hands(stand(), [-1, f], [-1, PODIUM_FIST * Vector3(-1, 1, 1)],
		{"add": {B.SPINE: Vector3(-4 - 4 * beat, 0, 0), B.NECK: Vector3(2 + 4 * beat, 0, 0)},
		"pole_r": Vector3(0.8, -0.2, 0.2), "pole_l": Vector3(-0.7, -0.3, 0.2)})


## Pointing out over the crowd (yaw degrees), left fist on the lectern.
static func speech_point(yaw_deg := 0.0, high := 0.0) -> Dictionary:
	var d := Vector3(-sin(deg_to_rad(yaw_deg)), 0.15 + high, -cos(deg_to_rad(yaw_deg))).normalized()
	return O.hands(stand(), [-1, O.SHOULDER_R + d * 0.64], [-1, PODIUM_FIST * Vector3(-1, 1, 1)],
		{"pole_r": Vector3(0.6, -0.8, 0.0), "pole_l": Vector3(-0.7, -0.3, 0.2),
		"add": {B.CHEST: Vector3(4, yaw_deg * 0.3, 0), B.NECK: Vector3(-6, yaw_deg * 0.2, 0)}})


# ---------------------------------------------------------------- powers

## Rally aura: the right arm sweeps across at shoulder height (u 0 left, 1 right), palm open.
static func rally_sweep(u: float) -> Dictionary:
	var a := deg_to_rad(lerpf(35.0, -70.0, u))
	var d := Vector3(-sin(a), 0.25, -cos(a)).normalized()
	return O.hands(stand(), [-1, O.SHOULDER_R + d * 0.63], null,
		{"pole_r": Vector3(0.5, -0.9, 0.2), "add": {B.CHEST: Vector3(2, rad_to_deg(a) * 0.25, 0), B.NECK: Vector3(-8, rad_to_deg(a) * 0.2, 0)}})


## Rally aura: the fist thrust up over the head, chin up, shouting.
static func rally_fist(up := 1.0) -> Dictionary:
	return O.hands(stand(), [B.CHEST, Vector3(0.2, lerpf(1.6, 2.04, up), lerpf(-0.3, -0.12, up))], null,
		{"pole_r": Vector3(0.9, 0.0, 0.2), "add": {B.CHEST: Vector3(-2, 0, 0), B.NECK: Vector3(-12 * up, 0, 0), B.HEAD: Vector3(-6 * up, 0, 0)}})


## Call in fire (flare): the flare pistol up over the head pointing at the sky (pitch toward the target).
static func flare_up(lean := 1.0) -> Dictionary:
	return O.hands(stand(), [B.CHEST, Vector3(0.24, lerpf(1.45, 1.92, lean), lerpf(-0.35, -0.36, lean))], null,
		{"pole_r": Vector3(0.9, -0.3, 0.1), "add": {B.CHEST: Vector3(-4 * lean, -6, 0), B.NECK: Vector3(-16 * lean, 0, 0),
			B.HEAD: Vector3(-8 * lean, 0, 0)}})


## Call in fire (bark): pointing at the target, the left hand cupped at the mouth (shouting at the signaller).
static func bark(target: Vector3) -> Dictionary:
	return Rig.over(O.point_call(target, true), {"add": {B.CHEST: Vector3(6, 0, 0), B.NECK: Vector3(-4, 0, 0)}})


## Bark, the stick jabbing at the map/target (beat 0 back, 1 jab) - left arm, right hand on the hip.
static func bark_stick(beat: float) -> Dictionary:
	return O.hands(stand(), [B.HIPS, Vector3(0.2, 1.04, 0.02)], [B.CHEST, Vector3(-0.2, lerpf(1.12, 1.07, beat), lerpf(-0.3, -0.5, beat))],
		{"pole_r": Vector3(0.8, 0.0, -0.2), "pole_l": Vector3(-0.8, -0.4, 0.2),
		"add": {B.SPINE: Vector3(-3 * beat, 0, 0), B.CHEST: Vector3(4, 8, 0), B.NECK: Vector3(-2, -6, 0)}})


## No retreat: feet planted wide, the stick pointed straight forward and down at the ground he holds.
static func no_retreat() -> Dictionary:
	return O.hands(Rig.over(stand(), {"foot_r": Vector3(0.17, 0.09, 0.08), "foot_l": Vector3(-0.17, 0.09, -0.12),
		"root_pos": Vector3(0, -0.02, 0)}),
		[B.HIPS, Vector3(0.21, 1.03, 0.0)], [B.CHEST, Vector3(-0.17, 1.05, -0.4)],
		{"pole_r": Vector3(0.8, 0.0, -0.2), "pole_l": Vector3(-0.8, -0.5, 0.1),
		"add": {B.CHEST: Vector3(8, 10, 0), B.NECK: Vector3(-8, -8, 0), B.HEAD: Vector3(-2, 0, 0)}, "rot": {B.HAND_L: Vector3(-80, 0, 0)}})


# ---------------------------------------------------------------- wounded and carried

## Hit: a jolt back, a hand to the chest.
static func hurt() -> Dictionary:
	return O.hands(Rig.over(Body.body("stand"), {"rifle": O.pistol("holster")}), [B.CHEST, Vector3(0.05, 1.28, -0.17)], null,
		{"add": {B.SPINE: Vector3(12, 0, 0), B.CHEST: Vector3(10, 10, 0), B.NECK: Vector3(-10, 0, 0)}, "pole_r": Vector3(0.6, -0.6, 0.0)})


## Lying hurt on his back (the carried pose): legs a little bent, arms in.
static func lying() -> Dictionary:
	return {"rifle": O.pistol("holster"), "hand_r": [B.CHEST, Vector3(0.06, 1.25, -0.16)], "hand_l": null,
		"root_rot": Vector3(88, 0, 0), "root_pos": Vector3(0, 0.13, -0.95),
		"rot": {B.THIGH_R: Vector3(-25, 0, 3), B.SHIN_R: Vector3(35, 0, 0), B.THIGH_L: Vector3(-12, 0, -3), B.SHIN_L: Vector3(20, 0, 0),
			B.UARM_L: Vector3(10, 0, -18), B.FARM_L: Vector3(20, 0, 0), B.NECK: Vector3(-10, 0, 0), B.HEAD: Vector3(14, 25, 0)},
		"pole_r": Vector3(0.6, -0.6, 0.0)}


# ---------------------------------------------------------------- in the car

## Standing up in the back of the car, left hand on the rail, right hand raised to the crowd (wave 0..1).
static func car_stand(wave: float, rail: Vector3) -> Dictionary:
	var hr := Vector3(0.3, 1.86, -0.1).lerp(Vector3(0.36, 1.92, -0.26), wave)
	return O.hands(stand(), [B.CHEST, hr], [-1, rail], {"pole_r": Vector3(0.9, 0.1, 0.1), "pole_l": Vector3(-0.8, -0.4, 0.2)})


# ---------------------------------------------------------------- the guards

## Guard carries: "port" (rifle across the chest) while walking, "order" at rest, "present" for the salute.
static func guard_stand() -> Dictionary:
	return Rig.over(R.poses()["stand"], {"add": {B.CHEST: Vector3(4, 0, 0), B.NECK: Vector3(-3, 0, 0)}})


static func guard_port() -> Dictionary:
	return Body.pose("stand", R.carry("port"))


## Carrying the General: the rifle slung on the back, both hands on him (points set by the tool).
## side 1 = the front man (legs, hands behind him), -1 = the rear man (shoulders, hands in front).
static func guard_carry(side: float) -> Dictionary:
	var z := 0.2 if side > 0.0 else -0.3
	return {"rifle": {"mode": "back"}, "hand_r": [-1, Vector3(0.17, 0.93, z)], "hand_l": [-1, Vector3(-0.17, 0.93, z)],
		"pole_r": Vector3(0.7, -0.4, 0.0), "pole_l": Vector3(-0.7, -0.4, 0.0),
		"add": {B.SPINE: Vector3(-4, 0, 0)}}


## Stooping to lift him (hands set by the tool as world points).
static func guard_stoop() -> Dictionary:
	return Rig.over(Body.body("ready"), {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null,
		"pole_r": Vector3(0.7, -0.4, 0.0), "pole_l": Vector3(-0.7, -0.4, 0.0),
		"add": {B.SPINE: Vector3(-30, 0, 0), B.CHEST: Vector3(-10, 0, 0), B.NECK: Vector3(20, 0, 0)}})


## The escort's walk, at the General's pace.
const GUARD_WALK := {"name": "guard_walk", "v": 1.1, "T": 1.05, "duty": 0.6, "hip": 0.87, "bob": 0.02, "bob_sign": 1.0,
	"lift": 0.08, "lean": 1.0, "fwd": 0.02, "hip_yaw": 6.0, "sway": 0.02, "shoulder_yaw": 3.0,
	"strike": 14.0, "push": 24.0, "width": 0.095}


static func guard_gait_port() -> Dictionary:
	return Body.gait(GUARD_WALK, R.carry("port"))


static func guard_gait_carry(side: float) -> Dictionary:
	var p := GUARD_WALK.duplicate()
	p["name"] = "guard_carry"
	p["v"] = 0.9
	p["lift"] = 0.06
	return Body.gait(p, guard_carry(side))
