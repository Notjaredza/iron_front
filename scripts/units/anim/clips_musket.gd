extends RefCounted
## The red jackets' moves (Building Chat 1, 2026-11-10), on the shared body library (clips_body.gd) and the pose
## solver (rig.gd), like clips_rifle.gd. The user asked for: march and volley, the long reload, the bayonet charge,
## deaths and blast throws.
##   musketeer  march (shouldered), make ready, present, fire (kneeling front rank and standing rear rank), the
##              long reload (about 17 s: half cock, open the pan, bite the cartridge, prime, shut the pan, cast
##              about, pour, draw the rammer, ram, return it, make ready), charge bayonets, the charge run,
##              the thrust, hit, deaths, going down and getting up (blast throws)
##   officer    sword at the shoulder, march, raise the sword and cut down for "fire", lead the charge, wave on
##   drummer    the march beat while marching, the long roll standing
##   ensign     the colour carried high, march, charge
## Events: "cock", "pan" (the flash in the pan), "shot" (the muzzle blast, 0.06 s after the pan), "bite", "hit",
## "beat_r"/"beat_l" (a drum stroke), "roll" (the long roll's start).

const B := preload("res://scripts/units/soldier_builder.gd")
const RB := preload("res://scripts/units/redcoat_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")

## The march: ordinary step, upright, long-striding and slower than the rifleman's walk.
const MARCH := {"name": "march", "v": 1.15, "T": 1.1, "duty": 0.6, "hip": 0.875, "bob": 0.018, "bob_sign": 1.0,
	"lift": 0.07, "lean": 1.0, "fwd": 0.02, "hip_yaw": 6.0, "sway": 0.02, "shoulder_yaw": 2.0,
	"strike": 14.0, "push": 26.0, "width": 0.095}
const CHARGE := {"name": "charge_run", "v": 3.4, "T": 0.66, "duty": 0.36, "hip": 0.86, "bob": 0.035, "bob_sign": -1.0,
	"lift": 0.18, "lean": 16.0, "fwd": 0.12, "hip_yaw": 9.0, "sway": 0.018, "shoulder_yaw": 4.0,
	"strike": 6.0, "push": 32.0, "width": 0.09}

const POLE_AIM_R := Vector3(0.6, 0.05, 0.1)
const POLE_AIM_L := Vector3(-0.05, -0.8, 0.05)
const BOX := Vector3(0.13, 1.03, 0.16)         # the cartridge box's flap, rest model space, rides on the hips
const MOUTH := Vector3(0.025, 1.635, -0.13)     # rides on the head
const COCK := Vector3(0.03, 0.07, -0.01)        # the cock's top, item frame
const FRIZZEN := Vector3(0.03, 0.065, -0.085)


# ---------------------------------------------------------------- the rammer

## Where the rammer sits in the item frame (bone-local): see Redcoat.
##   "stock" s   stowed under the barrel, drawn s metres out toward the muzzle (0..1.03)
##   "flip" u    swinging round about the hand (gz 0.5 from its head) from fully drawn to head-down in the muzzle
##   "barrel" d  head down the barrel d metres from the muzzle, the rest sticking out
static func rammer_xf(mode: String, v: float) -> Transform3D:
	match mode:
		"barrel":
			return Transform3D(Basis(Vector3.RIGHT, PI), RB.MUZZLE + Vector3(0, 0, v))
		"flip":
			var u := v
			var g0 := RB.RAMROD_TIP + Vector3(0, 0, -1.03 + 0.5)
			var g1 := RB.MUZZLE + Vector3(0, 0, -0.5)
			var gp := g0.lerp(g1, u) + Vector3(0, -0.16 * sin(PI * u), 0)
			var r := Basis(Vector3.RIGHT, PI * u)
			return Transform3D(r, gp - r * Vector3(0, 0, 0.5))
	return Transform3D(Basis(), RB.RAMROD_TIP + Vector3(0, 0, -v))


## A point on the rammer gz metres from its head, in the item frame (a hand target).
static func rp(mode: String, v: float, gz: float) -> Vector3:
	return rammer_xf(mode, v) * Vector3(0, 0, gz)


# ---------------------------------------------------------------- carries

static func carry(name: String) -> Dictionary:
	match name:
		"order":
			# Ordered arms: the butt on the ground by the right foot, the right hand round the barrel.
			return {"rifle": {"mode": "order", "butt": Vector3(0.25, 0.015, -0.08)},
				"hand_r": Vector3(0, 0.0, -0.52), "pole_r": Vector3(0.25, -0.3, 0.45), "hand_l": null}
		"shoulder":
			# Shouldered: upright against the left shoulder, the butt in the left palm, the lock turned out.
			return {"rifle": {"mode": "chest", "dir": Vector3(-0.06, 1.0, 0.14), "up": Vector3(0, 0, -1),
				"grip": Vector3(-0.235, -0.13, -0.075)},
				"hand_l": Vector3(0, -0.045, 0.31), "pole_l": Vector3(-0.5, -0.3, 0.4), "hand_r": null}
		"poise":
			# Make ready: upright in front of the right side, the lock at the breast, the thumb on the cock.
			return {"rifle": {"mode": "chest", "dir": Vector3(0.0, 1.0, -0.12), "up": Vector3(0, 0, 1),
				"grip": Vector3(0.1, -0.24, -0.27)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.7, -0.4, 0.3),
				"hand_l": Vector3(0, -0.012, -0.24), "pole_l": Vector3(-0.6, -0.5, 0.1)}
		"present":
			return {"rifle": {"mode": "aim", "dir": Vector3(0, -0.035, -1)},
				"hand_r": B.GRIP_R, "pole_r": POLE_AIM_R, "hand_l": RB.GRIP_L, "pole_l": POLE_AIM_L}
		"prime":
			# Brought down to the right side, nearly level, the lock at the waist, the muzzle up a little.
			return {"rifle": {"mode": "chest", "dir": Vector3(-0.28, 0.33, -1.0), "up": Vector3(0.1, 1, 0),
				"grip": Vector3(0.14, -0.33, -0.12)},
				"hand_l": Vector3(0, -0.012, -0.22), "pole_l": Vector3(-0.6, -0.6, 0.0), "hand_r": null}
		"load":
			# Cast about: upright before him, the butt on the ground between his feet, the muzzle at his chin.
			return {"rifle": {"mode": "bone", "bone": B.ROOT, "at": Vector3(-0.04, 0.29, -0.33), "rot": Vector3(96, 0, 0)},
				"hand_l": Vector3(0, -0.012, -0.62), "pole_l": Vector3(-0.6, -0.4, 0.2), "hand_r": null}
		"charge":
			# Charge bayonets: level at the waist, the bayonet forward at a man's chest.
			return {"rifle": {"mode": "chest", "dir": Vector3(0.0, 0.42, -1.0), "up": Vector3(0, 1, 0),
				"grip": Vector3(0.2, -0.36, -0.02)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.6, -0.6, 0.4),
				"hand_l": RB.GRIP_L, "pole_l": Vector3(-0.4, -0.8, 0.0)}
		"one_hand":
			return {"rifle": {"mode": "chest", "dir": Vector3(-0.3, 0.2, -1.0), "up": Vector3(0, 1, 0),
				"grip": Vector3(0.17, -0.24, -0.2)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.7, -0.4, 0.3), "hand_l": null}
		"fall":
			return {"rifle": {"mode": "hand", "rot": Vector3(-90, 0, 0)}, "hand_r": null, "hand_l": null}
		# ---- the officer's sword.
		"sword_carry":
			# Sword carried: the hilt at the right hip, the blade upright against the shoulder.
			return {"rifle": {"mode": "hand", "rot": Vector3(20, 0, -8)},
				"rot": {B.UARM_R: Vector3(18, 0, 10), B.FARM_R: Vector3(62, 0, 0), B.HAND_R: Vector3(0, 0, 0),
					B.UARM_L: Vector3(2, 0, -6), B.FARM_L: Vector3(12, 0, 0)}, "hand_r": null, "hand_l": null}
		"sword_up":
			# Raised high and forward ("make ready ... present!").
			return {"rifle": {"mode": "hand", "rot": Vector3(-70, 0, 0)},
				"rot": {B.UARM_R: Vector3(150, 0, 18), B.FARM_R: Vector3(20, 0, 0),
					B.UARM_L: Vector3(2, 0, -6), B.FARM_L: Vector3(12, 0, 0)}, "hand_r": null, "hand_l": null}
		"sword_down":
			# Cut down to point at the enemy ("fire!").
			return {"rifle": {"mode": "hand", "rot": Vector3(-80, 0, 0)},
				"rot": {B.UARM_R: Vector3(70, 0, 12), B.FARM_R: Vector3(10, 0, 0),
					B.UARM_L: Vector3(2, 0, -6), B.FARM_L: Vector3(12, 0, 0)}, "hand_r": null, "hand_l": null}
		"sword_lead":
			# Leading the charge: the sword pointed forward and up, the left arm out.
			return {"rifle": {"mode": "hand", "rot": Vector3(-75, 0, 0)},
				"rot": {B.UARM_R: Vector3(115, 0, 14), B.FARM_R: Vector3(15, 0, 0),
					B.UARM_L: Vector3(25, 0, -30), B.FARM_L: Vector3(30, 0, 0)}, "hand_r": null, "hand_l": null}
		# ---- the drummer: the sticks over the batter head.
		"drum":
			return {"rifle": {"mode": "hand", "rot": Vector3(-62, -20, 0), "after_ik": true},
				"hand_r": [B.HIPS, Vector3(0.06, 1.02, -0.30)], "pole_r": Vector3(0.6, -0.3, 0.3),
				"hand_l": [B.HIPS, Vector3(-0.27, 1.0, -0.20)], "pole_l": Vector3(-0.6, -0.3, 0.3)}
		# ---- the ensign: the colour held high, its butt in the belt's socket.
		"colour":
			return {"rifle": {"mode": "bone", "bone": B.HIPS, "at": Vector3(0.12, 1.39, -0.19), "rot": Vector3(84, 0, 0)},
				"hand_r": Vector3(0, -0.02, 0.27), "pole_r": Vector3(0.7, -0.6, 0.2),
				"hand_l": Vector3(-0.02, 0, -0.06), "pole_l": Vector3(-0.7, -0.6, 0.0)}
		"colour_fall":
			return {"rifle": {"mode": "hand", "rot": Vector3(-60, 0, 0)}, "hand_r": null, "hand_l": null}
	return {}


## Standing straight (the line stands at attention, not the rifleman's easy stance).
static func attention() -> Dictionary:
	return {"rot": {B.THIGH_R: Vector3(0, 0, 2), B.THIGH_L: Vector3(0, 0, -2), B.FOOT_R: Vector3(0, 8, -2),
		B.FOOT_L: Vector3(0, -8, 2), B.SPINE: Vector3(1, 0, 0), B.CHEST: Vector3(-2, 0, 0), B.NECK: Vector3(-2, 0, 0)}}


## Half-faced to the right, feet apart, as for priming and making ready.
static func half_face() -> Dictionary:
	return {"rot": {B.HIPS: Vector3(0, -18, 0), B.THIGH_R: Vector3(-2, 0, 6), B.THIGH_L: Vector3(6, 14, -4),
		B.SHIN_L: Vector3(-4, 0, 0), B.SPINE: Vector3(-3, 0, 0), B.CHEST: Vector3(-2, 6, 0), B.NECK: Vector3(0, 12, 0)}}


static func poses(role := "musketeer") -> Dictionary:
	match role:
		"officer":
			return {"stand": Rig.over(attention(), carry("sword_carry")), "ready": Rig.over(attention(), carry("sword_carry")),
				"aim": Rig.over(attention(), carry("sword_carry")), "up": Rig.over(Body.body("stance"), carry("sword_up")),
				"down": Rig.over(Body.body("stance"), carry("sword_down")), "lead": Rig.over(Body.body("run"), carry("sword_lead"))}
		"drummer":
			return {"stand": Rig.over(attention(), carry("drum")), "ready": Rig.over(attention(), carry("drum")),
				"aim": Rig.over(attention(), carry("drum"))}
		"ensign":
			return {"stand": Rig.over(attention(), carry("colour")), "ready": Rig.over(attention(), carry("colour")),
				"aim": Rig.over(attention(), carry("colour"))}
	return {
		"stand": Rig.over(attention(), carry("order")),
		"shoulder": Rig.over(attention(), carry("shoulder")),
		"ready": Rig.over(half_face(), carry("poise")),
		"aim": Rig.over(Body.body("stance"), carry("present")),
		"kneel": Rig.over(Body.body("kneel"), carry("present")),
		"kneel_ready": Rig.over(Body.body("kneel"), carry("poise")),
		"prime": Rig.over(half_face(), carry("prime")),
		"load": Rig.over(attention(), carry("load")),
		"charge": Rig.over(Rig.over(Body.body("ready"), carry("charge")), {"add": {B.SPINE: Vector3(-6, 0, 0)}}),
		"prone": Rig.over(Body.body("prone"), carry("one_hand")),
	}


# ---------------------------------------------------------------- the musketeer

## A gait with the right arm swinging (the left holds the shouldered musket).
static func _swing(clip: Dictionary, amp: float, side := 1.0) -> Dictionary:
	var T: float = clip["len"]
	for key: Array in clip["keys"]:
		var ph := float(key[0]) / T
		var spec: Dictionary = key[1]
		var rot: Dictionary = spec["rot"]
		var sw := -amp * cos(TAU * ph)
		if side > 0.0:
			rot[B.UARM_R] = Vector3(sw, 0, 6)
			rot[B.FARM_R] = Vector3(14 + maxf(sw, 0.0) * 0.5, 0, 0)
		else:
			rot[B.UARM_L] = Vector3(-sw, 0, -6)
			rot[B.FARM_L] = Vector3(14 + maxf(-sw, 0.0) * 0.5, 0, 0)
	return clip


static func march() -> Dictionary:
	return _swing(Body.gait(MARCH, carry("shoulder")), 22.0)


## Make ready (shoulder to poise, cock) and present, then fire: the flash in the pan, the shot, the kick.
## kneel: the front rank kneels as it makes ready. Ends on the present, fired.
static func volley(kneel: bool) -> Dictionary:
	var P := poses()
	var sh: Dictionary = P["shoulder"]
	var ready: Dictionary = P["kneel_ready"] if kneel else P["ready"]
	var aim: Dictionary = P["kneel"] if kneel else P["aim"]
	var cock := Rig.over(ready, {"hand_r": COCK, "pole_r": Vector3(0.7, 0.0, 0.3)})
	var cocked := Rig.over(ready, {"hand_r": B.GRIP_R})
	var kick := Rig.over(aim, {"add": {B.CHEST: Vector3(8, 3, 0), B.NECK: Vector3(5, 0, 0), B.HEAD: Vector3(6, 0, 0),
		B.SPINE: Vector3(3, 0, 0)}, "rifle_add": {"dir": Vector3(0, 0.2, 0), "off": Vector3(0, 0.015, 0.06)}})
	var settle := Rig.over(aim, {"add": {B.CHEST: Vector3(-1.5, 0, 0)}})
	var t_fire := 3.0
	return {"name": "volley_kneel" if kneel else "volley_stand", "len": t_fire + 1.4,
		"keys": [[0.0, sh], [0.75, ready, "smooth"], [0.95, cock, "smooth"], [1.15, cocked, "out"], [1.6, cocked],
			[2.25, aim, "smooth"], [t_fire, aim], [t_fire + 0.06, aim], [t_fire + 0.11, kick, "out"],
			[t_fire + 0.45, settle, "smooth"], [t_fire + 0.9, aim, "smooth"], [t_fire + 1.4, aim]],
		"events": [[1.05, "cock"], [t_fire, "pan"], [t_fire + 0.06, "shot"]]}


## The long reload, from the present (fired) to make ready again (about 17 s).
static func _now(keys: Array) -> float:
	return float(keys.back()[0])


static func reload() -> Dictionary:
	var P := poses()
	var aim: Dictionary = P["aim"]
	var prime: Dictionary = P["prime"]
	var load: Dictionary = P["load"]
	var ready: Dictionary = P["ready"]
	var look_down := {"add": {B.NECK: Vector3(-14, -6, 0), B.HEAD: Vector3(-10, -6, 0)}}
	var pr := func(h: Variant, pole := Vector3(0.7, -0.3, 0.3)) -> Dictionary:
		return Rig.over(Rig.over(prime, look_down), {"hand_r": h, "pole_r": pole})
	var ld := func(h: Variant, extra := {}, pole := Vector3(0.6, -0.2, 0.4)) -> Dictionary:
		var s := Rig.over(load, {"hand_r": h, "pole_r": pole})
		if not extra.is_empty():
			s = Rig.over(s, extra)
		return s
	var up_look := {"add": {B.NECK: Vector3(8, 0, 0), B.HEAD: Vector3(6, 0, 0)}}
	var ram_look := {"add": {B.NECK: Vector3(-6, 0, 0), B.HEAD: Vector3(-4, 0, 0)}}
	var keys: Array = [[0.0, aim]]
	var props := {"rammer": [[0.0, "stock", 0.0]], "cartridge": [[0.0, "off"]]}
	var ev: Array = []
	var add := func(dt: float, spec: Dictionary, e := "smooth") -> void:
		keys.append([float(keys.back()[0]) + dt, spec, e])
	# Half cock and open the pan, at the right side.
	add.call(0.75, pr.call(B.GRIP_R))
	add.call(0.35, pr.call(COCK + Vector3(0.0, 0.02, 0.02)))
	add.call(0.25, pr.call(COCK), "out")
	add.call(0.3, pr.call(FRIZZEN + Vector3(0.0, 0.01, -0.01)))
	add.call(0.2, pr.call(FRIZZEN + Vector3(0.0, 0.03, 0.03)), "out")
	ev.append([_now(keys), "pan_open"])
	# A cartridge from the box, bitten open.
	add.call(0.55, pr.call([B.HIPS, BOX], Vector3(0.9, -0.1, 0.6)))
	add.call(0.3, pr.call([B.HIPS, BOX + Vector3(0, -0.04, 0)], Vector3(0.9, -0.1, 0.6)))
	props["cartridge"].append([_now(keys), "hand"])
	add.call(0.65, pr.call([B.HEAD, MOUTH], Vector3(0.8, -0.6, 0.0)))
	add.call(0.25, Rig.over(pr.call([B.HEAD, MOUTH], Vector3(0.8, -0.6, 0.0)), {"add": {B.HEAD: Vector3(-8, 10, 0)}}), "out")
	ev.append([_now(keys), "bite"])
	add.call(0.25, pr.call([B.HEAD, MOUTH + Vector3(0.05, -0.05, -0.02)], Vector3(0.8, -0.6, 0.0)))
	# Prime the pan, shut it.
	add.call(0.55, pr.call(RB.PAN + Vector3(0.01, 0.07, 0.0)))
	for k in 3:
		add.call(0.18, pr.call(RB.PAN + Vector3(0.01, 0.05, 0.01)), "out")
		add.call(0.18, pr.call(RB.PAN + Vector3(0.01, 0.07, -0.01)))
	add.call(0.35, pr.call(FRIZZEN + Vector3(0.0, 0.03, 0.03)))
	add.call(0.2, pr.call(FRIZZEN + Vector3(0.0, 0.0, -0.02)), "out")
	ev.append([_now(keys), "pan_shut"])
	# Cast about to the load, pour the powder and the ball down the barrel, the paper after them.
	add.call(0.9, ld.call(RB.MUZZLE + Vector3(0.06, -0.12, -0.12), up_look))
	add.call(0.4, ld.call(RB.MUZZLE + Vector3(0.02, -0.05, -0.08), up_look), "out")
	for k in 2:
		add.call(0.2, ld.call(RB.MUZZLE + Vector3(0.02, -0.04, -0.05), up_look), "out")
		add.call(0.2, ld.call(RB.MUZZLE + Vector3(0.02, -0.05, -0.09), up_look))
	props["cartridge"].append([_now(keys), "off"])
	# Draw the rammer: by the head, half out, a new grip, all the way out.
	add.call(0.45, ld.call(RB.RAMROD_TIP + Vector3(0.0, -0.03, 0.02), ram_look))
	props["rammer"].append([_now(keys), "stock", 0.0])
	add.call(0.5, ld.call(rp("stock", 0.45, 0.0), up_look, Vector3(0.6, 0.0, 0.4)), "lin")
	props["rammer"].append([_now(keys), "stock", 0.45])
	add.call(0.3, ld.call(rp("stock", 0.45, 0.5), ram_look))
	add.call(0.55, ld.call(rp("stock", 1.03, 0.5), up_look, Vector3(0.6, 0.0, 0.4)), "lin")
	props["rammer"].append([_now(keys) - 0.55, "stock", 0.45])
	props["rammer"].append([_now(keys), "stock", 1.03])
	# Turn it round over the muzzle and start it down.
	for k in 4:
		var u := float(k + 1) / 4.0
		add.call(0.16, ld.call(rp("flip", u, 0.5), up_look, Vector3(0.6, 0.0, 0.4)), "lin")
	props["rammer"].append([_now(keys) - 0.64, "flip", 0.0])
	props["rammer"].append([_now(keys), "flip", 1.0])
	props["rammer"].append([_now(keys) + 0.001, "barrel", 0.0])
	# Ram it home in three strokes, two taps on the ball.
	var d := 0.0
	for stroke: Array in [[0.0, 0.45, 0.5], [0.45, 0.70, 0.3], [0.70, 0.95, 0.3]]:
		var d0: float = stroke[0]
		var d1: float = stroke[1]
		var h: float = stroke[2]
		add.call(0.28, ld.call(rp("barrel", d0, d0 + h), ram_look))
		props["rammer"].append([_now(keys), "barrel", d0])
		add.call(0.42, ld.call(rp("barrel", d1, d0 + h), ram_look), "in")
		props["rammer"].append([_now(keys), "barrel", d1])
		d = d1
	for k in 2:
		add.call(0.18, ld.call(rp("barrel", 0.84, 0.84 + 0.18), ram_look), "out")
		props["rammer"].append([_now(keys), "barrel", 0.84])
		add.call(0.16, ld.call(rp("barrel", 0.96, 0.84 + 0.18), ram_look), "in")
		props["rammer"].append([_now(keys), "barrel", 0.96])
	ev.append([_now(keys), "rammed"])
	# Draw it out, turn it, back into its pipes.
	add.call(0.25, ld.call(rp("barrel", 0.96, 1.03), ram_look))
	props["rammer"].append([_now(keys), "barrel", 0.96])
	add.call(0.5, ld.call(rp("barrel", 0.5, 1.03), up_look, Vector3(0.6, 0.0, 0.4)), "lin")
	props["rammer"].append([_now(keys), "barrel", 0.5])
	add.call(0.25, ld.call(rp("barrel", 0.5, 0.5 + 0.06), ram_look))
	add.call(0.45, ld.call(rp("barrel", 0.0, 0.5 + 0.0), up_look, Vector3(0.6, 0.0, 0.4)), "lin")
	props["rammer"].append([_now(keys) - 0.45, "barrel", 0.5])
	props["rammer"].append([_now(keys), "barrel", 0.0])
	props["rammer"].append([_now(keys) + 0.001, "flip", 1.0])
	for k in 4:
		var u := 1.0 - float(k + 1) / 4.0
		add.call(0.16, ld.call(rp("flip", u, 0.5), up_look, Vector3(0.6, 0.0, 0.4)), "lin")
	props["rammer"].append([_now(keys), "flip", 0.0])
	props["rammer"].append([_now(keys) + 0.001, "stock", 1.03])
	add.call(0.5, ld.call(rp("stock", 0.45, 0.5), ram_look), "lin")
	props["rammer"].append([_now(keys), "stock", 0.45])
	add.call(0.25, ld.call(rp("stock", 0.45, 0.0), ram_look))
	add.call(0.4, ld.call(rp("stock", 0.0, 0.0), ram_look), "lin")
	props["rammer"].append([_now(keys) - 0.4, "stock", 0.45])
	props["rammer"].append([_now(keys), "stock", 0.0])
	ev.append([_now(keys), "rammer_home"])
	# Up to make ready.
	add.call(0.9, ready)
	add.call(0.5, ready)
	return {"name": "reload", "len": _now(keys), "keys": keys, "props": props, "events": ev}


static func to_charge() -> Dictionary:
	var P := poses()
	return {"name": "to_charge", "len": 0.7, "keys": [[0.0, P["ready"]], [0.5, P["charge"], "out"], [0.7, P["charge"]]],
		"events": [[0.1, "charge"]]}


static func charge_run() -> Dictionary:
	return Body.gait(CHARGE, Rig.over(carry("charge"), {"rot": {B.SPINE: Vector3(-4, 0, 0)}}))


## The thrust: a lunge on the left foot, the bayonet driven forward and up, pulled back to the charge.
static func thrust() -> Dictionary:
	var P := poses()
	var c: Dictionary = P["charge"]
	var back := Rig.over(c, {"rifle_add": {"grip": Vector3(0.02, 0.0, 0.16)}, "add": {B.CHEST: Vector3(0, -12, 0)}})
	var lunge := Rig.over(c, {"rifle_add": {"grip": Vector3(-0.03, 0.12, -0.42), "dir": Vector3(0, 0.12, 0)},
		"rot": {B.THIGH_L: Vector3(60, 8, -4), B.SHIN_L: Vector3(-60, 0, 0), B.FOOT_L: Vector3(-4, -8, 4),
			B.THIGH_R: Vector3(-24, 0, 6), B.SHIN_R: Vector3(-10, 0, 0), B.FOOT_R: Vector3(18, 0, 0)},
		"add": {B.SPINE: Vector3(-10, 0, 0), B.CHEST: Vector3(-4, 10, 0)}, "root_pos": Vector3(0, -0.08, -0.25)})
	return {"name": "thrust", "len": 1.4, "keys": [[0.0, c], [0.3, back, "smooth"], [0.48, lunge, "out"], [0.68, lunge],
		[1.05, c, "smooth"], [1.4, c]], "events": [[0.45, "thrust"]]}


# ---------------------------------------------------------------- officer, drummer, ensign

static func officer_clips() -> Array:
	var P := poses("officer")
	var st: Dictionary = P["stand"]
	var m := _swing(Body.gait(MARCH, carry("sword_carry")), 18.0, -1.0)
	m["name"] = "officer_march"
	var up: Dictionary = P["up"]
	var dn: Dictionary = P["down"]
	var order := {"name": "officer_fire", "len": 4.4, "keys": [[0.0, st], [0.7, up, "smooth"], [2.95, up],
		[3.0, Rig.over(up, {"add": {B.UARM_R: Vector3(8, 0, 0)}}), "smooth"], [3.12, dn, "out"], [3.6, dn], [4.4, dn]],
		"events": [[0.5, "make_ready"], [2.9, "fire_word"]]}
	var lead := Body.gait(CHARGE, carry("sword_lead"))
	lead["name"] = "officer_charge"
	var wave_a: Dictionary = up
	var wave_b := Rig.over(dn, {"add": {B.CHEST: Vector3(-4, -12, 0)}})
	var wave := {"name": "officer_wave", "len": 2.2, "keys": [[0.0, st], [0.4, wave_a, "smooth"], [0.8, wave_b, "smooth"],
		[1.2, wave_a, "smooth"], [1.6, wave_b, "smooth"], [2.2, st, "smooth"]]}
	return [m, order, lead, wave]


## The drummer: sticks rise and strike in turn. In the march, two strokes a step.
static func _beat(clip: Dictionary, strokes_per_len: float, flam := 0.0) -> Dictionary:
	var T: float = clip["len"]
	for key: Array in clip["keys"]:
		var ph := float(key[0]) / T
		var spec: Dictionary = key[1]
		var a := ph * strokes_per_len
		var lr := 0.5 + 0.5 * sin(TAU * a * 0.5 + flam)
		var lift_r := 0.11 * maxf(sin(TAU * a * 0.5), 0.0)
		var lift_l := 0.11 * maxf(-sin(TAU * a * 0.5), 0.0)
		var hr: Array = carry("drum")["hand_r"]
		var hl: Array = carry("drum")["hand_l"]
		spec["hand_r"] = [hr[0], (hr[1] as Vector3) + Vector3(0.01, lift_r, 0.04 * lift_r / 0.11)]
		spec["hand_l"] = [hl[0], (hl[1] as Vector3) + Vector3(-0.01, lift_l, 0.03 * lift_l / 0.11)]
		spec["pole_r"] = Vector3(0.6, -0.3, 0.3)
		spec["pole_l"] = Vector3(-0.6, -0.3, 0.3)
		spec["rifle"] = carry("drum")["rifle"]
		var r: Dictionary = spec.get("rot", {})
		r[B.HAND_R] = Vector3(-30.0 * lift_r / 0.11, 0, 0)
		spec["rot"] = r
		var _u := lr
	return clip


static func drummer_clips() -> Array:
	var m := Body.gait(MARCH, carry("drum"), 40)
	m["name"] = "drummer_march"
	m = _beat(m, 4.0)
	m["events"] = [[0.0, "beat_r"], [0.275, "beat_l"], [0.55, "beat_r"], [0.825, "beat_l"]]
	var st: Dictionary = poses("drummer")["stand"]
	var keys: Array = []
	for k in 41:
		keys.append([0.6 * float(k) / 40.0, st.duplicate(true), "lin"])
	var roll := _beat({"name": "drummer_roll", "len": 0.6, "loop": true, "keys": keys}, 12.0)
	roll["events"] = [[0.0, "roll"]]
	return [m, roll]


static func ensign_clips() -> Array:
	var m := Body.gait(MARCH, carry("colour"))
	m["name"] = "ensign_march"
	var c := Body.gait(CHARGE, carry("colour"))
	c["name"] = "ensign_charge"
	return [m, c]


# ---------------------------------------------------------------- the library

static func library() -> Dictionary:
	var p := poses()
	var out := {}
	var ma := march()
	var list: Array = [ma, volley(false), volley(true), reload(), to_charge(), charge_run(), thrust(),
		Body.kneel_to_stand(p["kneel"], p["ready"]), Body.stand_to_kneel(p["ready"], p["kneel"]),
		Body.stand_to_prone(p["ready"], carry("one_hand"), p["prone"]),
		Body.prone_to_stand(p["prone"], carry("one_hand"), p["ready"]),
		Body.hit(p["aim"]),
		Body.death_back(p["aim"], carry("fall")), Body.death_forward(p["aim"], carry("fall"))]
	list.append_array(officer_clips())
	list.append_array(drummer_clips())
	list.append_array(ensign_clips())
	for c: Dictionary in list:
		out[c["name"]] = c
	# Held poses (for timelines and videos): one key, looped.
	var hold := func(n: String, s: Dictionary) -> void:
		out[n] = {"name": n, "len": 1.0, "loop": true, "keys": [[0.0, s], [1.0, s]]}
	for k: String in ["stand", "shoulder", "ready", "aim", "kneel", "charge", "load", "prime"]:
		hold.call("hold_" + k, p[k])
	var po := poses("officer")
	hold.call("officer_stand", po["stand"])
	hold.call("officer_hold_up", po["up"])
	hold.call("drummer_hold", poses("drummer")["stand"])
	hold.call("ensign_hold", poses("ensign")["stand"])
	# The officer's, drummer's and ensign's deaths keep what they hold.
	for role: String in ["officer", "drummer", "ensign"]:
		var st: Dictionary = poses(role)["stand"]
		var fall := carry("colour_fall") if role == "ensign" else carry("fall")
		if role == "drummer":
			fall = {"rifle": {"mode": "hand", "rot": Vector3(-62, -20, 0)}, "hand_r": null, "hand_l": null}
		for c: Dictionary in [Body.death_back(st, fall), Body.death_forward(st, fall),
				Body.prone_to_stand(Rig.over(Body.body("prone"), fall), fall, st), Body.hit(st)]:
			c["name"] = "%s_%s" % [role, c["name"]]
			out[c["name"]] = c
	return out


## The clip names a role plays for the shared moves (blast throws and deaths look these up).
static func role_clip(role: String, base: String) -> String:
	return base if role == "musketeer" else "%s_%s" % [role, base]
