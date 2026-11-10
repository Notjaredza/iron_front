extends RefCounted
## The siege crews' moves (Building Chat 1, 2026-11-10), for Medieval men. Every pose takes its hand spots in the man's
## model space (the tool turns the engine's handles, spokes, ropes, rails and stones into his frame), so the hands stay
## on the moving parts. The weapon is put away ("hand_item": "none").
##   work(body, hr, hl)     any body with both hands on two points (null = arm hangs free)
##   bent / crouch / haul   bodies: bent from the hips, crouched low, leaning back on a rope
##   by_height(h)           the body for hands at height h (bends lower as the spoke or stone goes down)
##   walk(style, hr, hl)    a gait clip with the hands held on points (pushing a tower, a ram, a mantlet; carrying a
##                          ladder between the rails, a fascine on the shoulder)
##   climb(u, ...)          on a ladder: feet on the rungs, hands up the rails, one limb at a time

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const Gun := preload("res://scripts/units/anim/clips_gun.gd")
const MC := preload("res://scripts/units/anim/clips_medieval.gd")

const PUSH := {"name": "push", "v": 0.7, "T": 1.1, "duty": 0.66, "hip": 0.8, "bob": 0.02, "bob_sign": 1.0, "lift": 0.06,
	"lean": 24.0, "fwd": 0.06, "hip_yaw": 5.0, "sway": 0.03, "shoulder_yaw": 1.0, "strike": 10.0, "push": 30.0, "width": 0.13}
const CARRY := {"name": "carry", "v": 1.1, "T": 1.08, "duty": 0.62, "hip": 0.86, "bob": 0.022, "bob_sign": 1.0, "lift": 0.06,
	"lean": 7.0, "fwd": 0.03, "hip_yaw": 6.0, "sway": 0.03, "shoulder_yaw": 1.0, "strike": 10.0, "push": 22.0, "width": 0.11}
const TROT := {"name": "trot", "v": 2.4, "T": 0.78, "duty": 0.45, "hip": 0.86, "bob": 0.035, "bob_sign": -1.0, "lift": 0.12,
	"lean": 12.0, "fwd": 0.07, "hip_yaw": 8.0, "sway": 0.025, "shoulder_yaw": 2.0, "strike": 8.0, "push": 28.0, "width": 0.1}


static func _hand(h: Variant) -> Variant:
	return null if h == null else [-1, h]


static func work(body: Dictionary, hr: Variant, hl: Variant, pole_r := Vector3(0.8, -0.4, 0.2), pole_l := Vector3(-0.8, -0.4, 0.2)) -> Dictionary:
	var c := {"rifle": {"mode": "hand"}, "hand_item": "none", "hand_r": _hand(hr), "hand_l": _hand(hl), "pole_r": pole_r, "pole_l": pole_l}
	var out := Rig.over(body, c)
	var rot: Dictionary = (out.get("rot", {}) as Dictionary).duplicate()
	if hr == null:
		rot[B.UARM_R] = Vector3(2, 0, 6)
		rot[B.FARM_R] = Vector3(10, 0, 0)
	if hl == null:
		rot[B.UARM_L] = Vector3(2, 0, -6)
		rot[B.FARM_L] = Vector3(10, 0, 0)
	out["rot"] = rot
	return out


static func stand() -> Dictionary:
	return Body.body("stand")


static func bent(bend: float, knees := 20.0) -> Dictionary:
	var b := Gun.heave(bend, knees)
	b.erase("rifle")
	return b


static func crouch(lean := 20.0) -> Dictionary:
	var b := Gun.crouch(lean)
	b.erase("rifle")
	return b


## Leaning back on a rope, the left foot braced forward.
static func haul(lean := 14.0, sink := 0.08) -> Dictionary:
	return {"root_rot": Vector3(lean, 0, 0), "root_pos": Vector3(0, -sink, 0.1),
		"foot_r": Vector3(0.13, B.REST[B.FOOT_R].y, 0.12), "foot_l": Vector3(-0.13, B.REST[B.FOOT_L].y, -0.38),
		"pole_kr": Vector3(0.1, 0, -1), "pole_kl": Vector3(-0.1, 0, -1),
		"rot": {B.SPINE: Vector3(-6, 0, 0), B.CHEST: Vector3(-4, 0, 0), B.NECK: Vector3(-lean * 0.4, 0, 0)}}


## The body for both hands at height h: upright with the hands high, bent from the hips and the knees as they go down.
static func by_height(h: float, reach_up := false) -> Dictionary:
	if h > 1.25:
		var b := stand()
		if reach_up or h > 1.6:
			b = Rig.over(b, {"add": {B.SPINE: Vector3(4, 0, 0), B.NECK: Vector3(-12, 0, 0)}})
		return b
	if h > 0.55:
		var k := (1.25 - h) / 0.7
		return bent(10.0 + 40.0 * k, 10.0 + 25.0 * k)
	return crouch(30.0)


## A gait clip with both hands held on points (model space), the weapon put away.
static func walk(style: Dictionary, hr: Variant, hl: Variant, pole_r := Vector3(0.8, -0.4, 0.2), pole_l := Vector3(-0.8, -0.4, 0.2),
		extra := {}) -> Dictionary:
	var carry := Rig.over({"rifle": {"mode": "hand"}, "hand_r": _hand(hr), "hand_l": _hand(hl), "pole_r": pole_r, "pole_l": pole_l}, extra)
	var c := Body.gait(style, carry)
	c["props"] = {"hand": [[0.0, "none"]]}
	return c


## Pushing (a tower's bar, a ram's frame, a mantlet's handles): hands out low in front.
static func push(hr: Vector3, hl: Vector3, v := 0.7) -> Dictionary:
	var st := PUSH.duplicate()
	st["v"] = v
	return walk(st, hr, hl, Vector3(0.7, -0.5, 0.2), Vector3(-0.7, -0.5, 0.2))


## The ladder carried between its rails at the shoulders.
static func ladder_carry(y := 1.5) -> Dictionary:
	return walk(CARRY, Vector3(0.235, y, -0.12), Vector3(-0.235, y, -0.12), Vector3(0.9, -0.5, 0.3), Vector3(-0.9, -0.5, 0.3))


## A fascine on the right shoulder (its axis along -Z), steadied by both hands; trotting.
static func fascine_carry() -> Dictionary:
	return walk(TROT, Vector3(0.36, 1.42, -0.2), Vector3(0.2, 1.5, -0.55), Vector3(0.9, -0.6, 0.0), Vector3(-0.6, -0.6, 0.3),
		{"add": {B.NECK: Vector3(0, -14, -8), B.HEAD: Vector3(0, -8, 0)}})


## On a ladder leaning toward -Z at angle ang (rad from the ground): the rungs in the man's frame are at heights
## y0 + k * rung, at z = -gap - (height above the feet) / tan(ang). u 0..1 is one climbing step (each foot up a rung).
static func climb(u: float, ang: float, rung: float, gap := 0.16) -> Dictionary:
	var ta := tan(ang)
	var zr := func(h: float) -> float: return -gap - h / ta
	# right foot steps in the first half, left in the second; the hands lead them
	var fr := rung * smoothstep(0.0, 0.5, u)
	var fl := rung * (smoothstep(0.5, 1.0, u)) + rung * 0.5
	var hr := 1.25 + rung * 0.5 + rung * smoothstep(0.0, 0.4, u)
	var hl := 1.25 + rung * smoothstep(0.5, 0.9, u)
	var lift := rung * 0.5 * u
	return {"rifle": {"mode": "hand"}, "hand_item": "none",
		"root_pos": Vector3(0, lift, 0), "root_rot": Vector3(-8, 0, 0),
		"foot_r": Vector3(0.12, B.REST[B.FOOT_R].y + fr, zr.call(fr) + 0.06),
		"foot_l": Vector3(-0.12, B.REST[B.FOOT_L].y + fl, zr.call(fl) + 0.06),
		"pole_kr": Vector3(0.2, 0.3, -1), "pole_kl": Vector3(-0.2, 0.3, -1),
		"hand_r": [-1, Vector3(0.21, hr, zr.call(hr) + 0.02)], "hand_l": [-1, Vector3(-0.21, hl, zr.call(hl) + 0.02)],
		"pole_r": Vector3(0.9, -0.6, 0.2), "pole_l": Vector3(-0.9, -0.6, 0.2),
		"rot": {B.SPINE: Vector3(-10, 0, 0), B.CHEST: Vector3(-4, 0, 0), B.NECK: Vector3(-16, 0, 0), B.HEAD: Vector3(-8, 0, 0)}}
