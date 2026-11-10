extends RefCounted
## The medieval host's moves (Building Chat 1, 2026-11-10). Clip names are "<kit>_<move>"; a role's kit is kit_of(role):
##   sword   men-at-arms and the captain (sword and heater shield)
##   spear   spearmen (spear and shield)
##   xbow    crossbowmen          bow     longbowmen          banner  the banner bearer
##   great   heavy with the two-handed sword                  pole    heavy with pole-axe or halberd
##   levy    the rabble (pitchfork, flail, billhook; the pole moves, a ragged gait)
## Every kit: march, run, hit, death_back, death_forward, prone_to_stand, holds ("<kit>_hold_<pose>").
## sword: strike, thrust, block, wall_lock, wall_step     spear: thrust, block, brace (the hedge's kneel)
## xbow: shoot, reload (spanning with the cranequin)      bow: volley (high), shot (flat), stake (driving a stake)
## banner: wave              great / pole / levy: strike, sweep
## Mounted (knight, scout) poses come from ride(); the tool lays the rider on a horse.
## Props: {"hand": [[t, "main" | "alt" | "none"]], "arrow": [[t, "on" | "off"]]}; events strike, block, shot, loose.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
const M2 := preload("res://scripts/units/anim/clips_redcoat2.gd")

const KITS: Array[String] = ["sword", "spear", "xbow", "bow", "banner", "great", "pole", "levy"]
const MARCH := {"name": "march", "v": 1.25, "T": 1.08, "duty": 0.61, "hip": 0.868, "bob": 0.025, "bob_sign": 1.0, "lift": 0.07,
	"lean": 5.0, "fwd": 0.03, "hip_yaw": 8.0, "sway": 0.028, "shoulder_yaw": 3.0, "strike": 12.0, "push": 26.0, "width": 0.1}
const RUN := {"name": "run", "v": 3.4, "T": 0.68, "duty": 0.36, "hip": 0.87, "bob": 0.04, "bob_sign": -1.0, "lift": 0.17,
	"lean": 14.0, "fwd": 0.1, "hip_yaw": 10.0, "sway": 0.025, "shoulder_yaw": 5.0, "strike": 6.0, "push": 32.0, "width": 0.09}
const SHAMBLE := {"name": "march", "v": 1.3, "T": 1.0, "duty": 0.6, "hip": 0.86, "bob": 0.035, "bob_sign": 1.0, "lift": 0.07,
	"lean": 10.0, "fwd": 0.05, "hip_yaw": 11.0, "sway": 0.045, "shoulder_yaw": 7.0, "strike": 10.0, "push": 24.0, "width": 0.12}
const WALL := {"name": "wall_step", "v": 0.6, "T": 1.3, "duty": 0.7, "hip": 0.81, "bob": 0.02, "bob_sign": 1.0, "lift": 0.05,
	"lean": 12.0, "fwd": 0.07, "hip_yaw": 5.0, "sway": 0.035, "shoulder_yaw": 1.0, "strike": 8.0, "push": 16.0, "width": 0.15}

## The shield hand (rest model space, riding the chest).
const SH_CARRY := Vector3(-0.2, 1.02, -0.26)
const SH_GUARD := Vector3(-0.08, 1.16, -0.38)
const SH_WALL := Vector3(-0.02, 1.1, -0.4)
const SH_HIGH := Vector3(-0.04, 1.38, -0.4)
## The left palm in rest model space (the bow and a hand-held item riding the left hand).
const PALM_L := Vector3(-0.243, 0.805, 0.0)
const QUIVER := Vector3(0.21, 1.1, 0.12)
const POLE_L := Vector3(0, -0.015, -0.42)
const GREAT_L := Vector3(0, -0.015, 0.24)
const SPEAR_L := Vector3(0, -0.015, -0.35)


static func kit_of(role: String) -> String:
	match role:
		"man_at_arms", "captain":
			return "sword"
		"spearman":
			return "spear"
		"crossbow":
			return "xbow"
		"longbow":
			return "bow"
		"banner":
			return "banner"
		"heavy":
			return "pole"
		"levy":
			return "levy"
	return "sword"


static func has_shield(kit: String) -> bool:
	return kit in ["sword", "spear"]


static func _shield(at: Vector3) -> Dictionary:
	return {"hand_l": [B.CHEST, at], "pole_l": Vector3(-0.9, -0.5, 0.2)}


## The item in the right hand, placed in the chest frame (grip relative to the chest joint); left hand on an item
## point or free.
static func held(grip: Vector3, dir: Vector3, up := Vector3.UP, left: Variant = null, pole_r := Vector3(0.8, -0.4, 0.2),
		pole_l := Vector3(-0.8, -0.4, 0.2)) -> Dictionary:
	var out := {"rifle": {"mode": "chest", "dir": dir, "up": up, "grip": grip}, "hand_r": B.GRIP_R, "pole_r": pole_r}
	if left != null:
		out["hand_l"] = left
		out["pole_l"] = pole_l
	return out


## The bow in the left hand, placed in the chest frame; the right hand on a chest point (the string) or free.
static func bow_at(grip: Vector3, dir: Vector3, right: Variant = null) -> Dictionary:
	var out := {"rifle": {"mode": "chest", "dir": dir, "up": Vector3.UP, "grip": grip}, "hand_l": B.GRIP_R,
		"pole_l": Vector3(-0.3, -0.9, 0.2)}
	if right != null:
		out["hand_r"] = [B.CHEST, right]
		out["pole_r"] = Vector3(0.9, 0.1, 0.4)
	else:
		out["hand_r"] = null
	return out


## The second hand on the shaft of a two-handed weapon.
static func left_on(kit: String) -> Vector3:
	match kit:
		"great":
			return GREAT_L
		"spear", "banner":
			return SPEAR_L
	return POLE_L


# ---------------------------------------------------------------- carries

static func carry(kit: String, name: String) -> Dictionary:
	var L := left_on(kit)
	match kit:
		"sword":
			match name:
				"march":
					# Sword drawn, blade up against the right shoulder.
					return Rig.over(held(Vector3(0.2, -0.12, -0.22), Vector3(0.0, 0.75, 0.66), Vector3(0, 0.66, -0.75)), _shield(SH_CARRY))
				"guard":
					return Rig.over(held(Vector3(0.26, 0.02, -0.34), Vector3(-0.15, 0.62, -0.78), Vector3(0, 0, -1),
						null, Vector3(0.8, -0.6, 0.1)), _shield(SH_GUARD))
				"up":
					return Rig.over(held(Vector3(0.24, 0.3, -0.08), Vector3(0.1, 0.9, 0.4), Vector3(0, 0, -1)), _shield(SH_WALL))
				"wind":
					return Rig.over(held(Vector3(0.18, 0.6, 0.1), Vector3(0.06, -0.15, 1.0), Vector3.UP, null, Vector3(0.9, 0.2, 0.3)),
						_shield(SH_GUARD))
				"cut":
					return Rig.over(held(Vector3(0.06, 0.32, -0.55), Vector3(0.0, -0.5, -0.86), Vector3(0, 0.86, -0.5), null,
						Vector3(0.8, -0.2, 0.0)), _shield(SH_GUARD + Vector3(-0.06, -0.04, 0.08)))
				"thrust":
					return Rig.over(held(Vector3(0.16, 0.08, -0.62), Vector3(-0.04, -0.06, -1.0), Vector3.UP, null, Vector3(0.6, -0.7, 0.2)),
						_shield(SH_GUARD + Vector3(-0.08, 0, 0.1)))
				"block":
					return Rig.over(held(Vector3(0.28, 0.1, -0.25), Vector3(-0.1, 0.75, -0.65), Vector3(0, 0, -1)), _shield(SH_HIGH))
				"run":
					return Rig.over(held(Vector3(0.26, 0.0, -0.22), Vector3(0.0, 0.85, -0.5), Vector3(0, 0, -1)), _shield(SH_CARRY + Vector3(0.04, 0.06, -0.04)))
		"spear":
			match name:
				"march":
					return Rig.over(held(Vector3(0.24, -0.26, -0.1), Vector3(0.0, 1.0, 0.06), Vector3(0, 0, -1)), _shield(SH_CARRY))
				"guard", "level":
					return Rig.over(held(Vector3(0.22, -0.28, -0.12), Vector3(-0.06, 0.1, -1.0), Vector3.UP, null, Vector3(0.6, -0.6, 0.4)),
						_shield(SH_GUARD))
				"high":
					# Overarm over the front rank's shields.
					return Rig.over(held(Vector3(0.24, 0.34, -0.06), Vector3(-0.04, -0.1, -1.0), Vector3.UP, null, Vector3(0.9, 0.3, 0.3)),
						_shield(SH_GUARD))
				"thrust":
					return Rig.over(held(Vector3(0.14, -0.2, -0.56), Vector3(-0.04, 0.04, -1.0), Vector3.UP, null, Vector3(0.6, -0.6, 0.3)),
						_shield(SH_GUARD + Vector3(-0.06, 0, 0.12)))
				"brace":
					return Rig.over(held(Vector3(0.24, -0.32, 0.02), Vector3(-0.04, 0.42, -0.9), Vector3.UP, null, Vector3(0.6, -0.6, 0.4)),
						_shield(SH_WALL + Vector3(0, -0.02, 0)))
				"block":
					return Rig.over(held(Vector3(0.24, -0.26, -0.1), Vector3(-0.05, 0.2, -1.0), Vector3.UP), _shield(SH_HIGH))
				"run":
					return Rig.over(held(Vector3(0.24, -0.22, -0.16), Vector3(-0.04, 0.35, -0.94), Vector3.UP), _shield(SH_CARRY + Vector3(0.04, 0.06, -0.04)))
		"banner":
			match name:
				"march", "guard", "run":
					return held(Vector3(0.16, -0.26, -0.2), Vector3(0.0, 1.0, 0.02), Vector3(0, 0, -1), L, Vector3(0.8, -0.6, 0.0),
						Vector3(-0.6, -0.6, -0.3))
				"left":
					return held(Vector3(0.12, -0.2, -0.2), Vector3(-0.36, 0.93, 0.0), Vector3(0, 0, -1), L, Vector3(0.8, -0.6, 0.0),
						Vector3(-0.6, -0.6, -0.3))
				"right":
					return held(Vector3(0.24, -0.24, -0.2), Vector3(0.36, 0.93, 0.0), Vector3(0, 0, -1), L, Vector3(0.8, -0.6, 0.0),
						Vector3(-0.6, -0.6, -0.3))
		"great", "pole", "levy":
			match name:
				"march":
					# Shouldered: the head up and back over the right shoulder.
					return held(Vector3(0.1, -0.28, -0.3), Vector3(0.1, 0.72, 0.68), Vector3(0, 0, -1), L, Vector3(0.8, -0.5, 0.2),
						Vector3(-0.6, -0.7, -0.2))
				"guard":
					return held(Vector3(0.16, -0.26, -0.26), Vector3(-0.28, 0.62, -0.73), Vector3(0, 0.5, 0.86), L, Vector3(0.8, -0.6, 0.1),
						Vector3(-0.6, -0.7, -0.1))
				"wind":
					return held(Vector3(0.14, 0.36, 0.02), Vector3(0.05, 0.5, 0.86), Vector3(0, 0.86, -0.5), L, Vector3(0.9, 0.2, 0.3),
						Vector3(-0.9, 0.2, 0.3))
				"cut":
					return held(Vector3(0.06, -0.12, -0.46), Vector3(0.0, -0.55, -0.83), Vector3(0, 0.83, -0.55), L, Vector3(0.8, -0.3, 0.0),
						Vector3(-0.8, -0.3, 0.0))
				"side":
					return held(Vector3(0.4, -0.1, 0.14), Vector3(0.62, 0.3, 0.72), Vector3.UP, L, Vector3(0.8, -0.4, 0.4), Vector3(-0.5, -0.6, 0.3))
				"sweep":
					return held(Vector3(-0.08, -0.12, -0.5), Vector3(-0.88, 0.0, -0.46), Vector3.UP, L, Vector3(0.6, -0.6, -0.2), Vector3(-0.8, -0.4, 0.3))
				"block":
					return held(Vector3(0.2, 0.0, -0.32), Vector3(-0.96, 0.25, -0.1), Vector3(0, 0, -1), L, Vector3(0.8, -0.5, 0.0),
						Vector3(-0.8, -0.5, 0.0))
				"run":
					return held(Vector3(0.14, -0.22, -0.28), Vector3(-0.3, 0.55, -0.78), Vector3(0, 0.5, 0.86), L, Vector3(0.8, -0.6, 0.1),
						Vector3(-0.6, -0.7, -0.1))
		"xbow":
			match name:
				"march", "run":
					# At the port, across the body, the prod up by the left shoulder.
					return held(Vector3(0.12, -0.3, -0.28), Vector3(-0.45, 0.62, -0.64), Vector3(0, 0.6, 0.8), Vector3(0, -0.02, -0.26),
						Vector3(0.8, -0.5, 0.2), Vector3(-0.6, -0.7, -0.1))
				"guard", "aim":
					return {"rifle": {"mode": "aim", "dir": Vector3(0, 0.0, -1)}, "hand_r": B.GRIP_R, "hand_l": Vector3(0, -0.02, -0.24),
						"pole_r": Vector3(0.7, -0.6, 0.2), "pole_l": Vector3(-0.4, -0.9, 0.0)}
				"recoil":
					return {"rifle": {"mode": "aim", "dir": Vector3(0, 0.12, -1), "off": Vector3(0.0, 0.02, 0.05)}, "hand_r": B.GRIP_R,
						"hand_l": Vector3(0, -0.02, -0.24), "pole_r": Vector3(0.7, -0.6, 0.2), "pole_l": Vector3(-0.4, -0.9, 0.0)}
				"span":
					# Nose down on the ground in front, his foot in the stirrup; both hands at the butt winding.
					return held(Vector3(0.0, -0.62, -0.4), Vector3(0.0, -0.96, -0.28), Vector3(0, 0.28, -0.96), Vector3(0.0, 0.0, 0.26),
						Vector3(0.8, -0.2, 0.3), Vector3(-0.8, -0.2, 0.3))
		"bow":
			match name:
				"march", "run":
					return {"rifle": {"mode": "bone", "bone": B.HAND_L, "at": PALM_L, "rot": Vector3(0, 0, 0)}, "hand_r": null, "hand_l": null,
						"rot": {B.UARM_L: Vector3(-6, 0, -6), B.FARM_L: Vector3(-28, 0, 0), B.UARM_R: Vector3(2, 0, 5),
							B.FARM_R: Vector3(-10, 0, 0)}}
				"guard":
					return bow_at(Vector3(-0.3, -0.12, -0.42), Vector3(-0.5, 0.0, -0.86), Vector3(0.0, -0.1, -0.3))
	return {}


## The archer's draw: elev 0 (flat) .. 1 (the high volley); u 0 (the string at rest) .. 1 (full draw at the jaw).
static func draw(elev: float, u: float) -> Dictionary:
	var e := deg_to_rad(lerpf(8.0, 38.0, elev))
	var d := Vector3(-0.77 * cos(e), sin(e), -0.64 * cos(e)).normalized()
	var anchor := Vector3(0.03, 0.31, -0.03)
	var grip := anchor + d * 0.62
	var hand := grip.lerp(anchor, u) - d * 0.02
	var p := bow_at(grip, d, hand)
	p["pole_l"] = Vector3(-0.3, -0.9, 0.3)
	p["pole_r"] = Vector3(0.6, 0.2, 0.8)
	return p


static func _archer_body(elev: float) -> Dictionary:
	return Rig.over(Body.body("stand"), {"rot": {B.HIPS: Vector3(0, -24, 0), B.SPINE: Vector3(-2 - 8 * elev, -12, 0),
		B.CHEST: Vector3(-6 * elev, -14, 0), B.NECK: Vector3(-8 * elev, 24, 0), B.HEAD: Vector3(-14 * elev, 20, 0),
		B.THIGH_R: Vector3(-4, 0, 8), B.THIGH_L: Vector3(6, 24, -8), B.FOOT_L: Vector3(0, 20, 0)}})


static func _crouch() -> Dictionary:
	return Rig.over(Body.body("ready"), {"add": {B.SPINE: Vector3(-8, 0, 0), B.CHEST: Vector3(-3, 0, 0), B.NECK: Vector3(6, 0, 0)},
		"rot": {B.THIGH_R: Vector3(26, 0, 6), B.SHIN_R: Vector3(-40, 0, 0), B.FOOT_R: Vector3(14, 0, -4),
			B.THIGH_L: Vector3(40, 10, -6), B.SHIN_L: Vector3(-36, 0, 0), B.FOOT_L: Vector3(-4, -10, 4)}})


## Falls: the item rides the right hand (the bow the left), both arms by angles.
static func fall(kit: String) -> Dictionary:
	if kit == "bow":
		return {"rifle": {"mode": "bone", "bone": B.HAND_L, "at": PALM_L, "rot": Vector3(0, 0, 0)}, "hand_r": null, "hand_l": null}
	if kit in ["spear", "banner", "great", "pole", "levy"]:
		return {"rifle": {"mode": "hand", "rot": Vector3(-72, 0, 0)}, "hand_r": null, "hand_l": null}
	return {"rifle": {"mode": "hand", "rot": Vector3(55, 0, 0)}, "hand_r": null, "hand_l": null}


static func poses(kit: String) -> Dictionary:
	var stand := Rig.over(Body.body("stand"), carry(kit, "march"))
	var guard := Rig.over(Body.body("ready"), carry(kit, "guard"))
	var out := {"stand": stand, "guard": guard, "prone": Rig.over(Body.body("prone"), fall(kit)),
		"kneel": Rig.over(Body.body("kneel"), carry(kit, "march"))}
	match kit:
		"sword":
			out["wall"] = Rig.over(_crouch(), Rig.over(carry(kit, "up"), {"add": {B.CHEST: Vector3(0, 6, 0)}}))
			out["block"] = Rig.over(Body.body("ready"), carry(kit, "block"))
		"spear":
			out["wall"] = Rig.over(_crouch(), carry(kit, "level"))
			out["brace"] = Rig.over(Body.body("kneel"), Rig.over(carry(kit, "brace"), {"rot": {B.HIPS: Vector3(0, -10, 0),
				B.CHEST: Vector3(-6, 0, 0), B.NECK: Vector3(-4, 4, 0), B.HEAD: Vector3(-4, 4, 0)}}))
			out["high"] = Rig.over(Body.body("ready"), carry(kit, "high"))
		"xbow":
			out["aim"] = Rig.over(R.poses()["aim"], carry(kit, "aim"))
			out["kneel_aim"] = Rig.over(R.poses()["kneel"], carry(kit, "aim"))
			out["span"] = Rig.over(Body.body("stand"), Rig.over(carry(kit, "span"), {"rot": {B.SPINE: Vector3(-26, 0, 0),
				B.CHEST: Vector3(-18, 0, 0), B.NECK: Vector3(10, 0, 0), B.HEAD: Vector3(14, 0, 0),
				B.THIGH_R: Vector3(30, 0, 6), B.SHIN_R: Vector3(-40, 0, 0), B.FOOT_R: Vector3(12, 0, 0),
				B.THIGH_L: Vector3(-6, 0, -6), B.SHIN_L: Vector3(-10, 0, 0)}}))
		"bow":
			out["volley"] = Rig.over(_archer_body(1.0), draw(1.0, 1.0))
			out["shot"] = Rig.over(_archer_body(0.0), draw(0.0, 1.0))
			out["nock"] = Rig.over(_archer_body(0.5), draw(0.6, 0.05))
		"banner":
			out["guard"] = Rig.over(Body.body("stand"), carry(kit, "guard"))
		"great", "pole", "levy":
			out["block"] = Rig.over(Body.body("ready"), carry(kit, "block"))
	if kit == "levy":
		# The rabble stands slack, the weapon low.
		out["stand"] = Rig.over(out["stand"], {"add": {B.SPINE: Vector3(-4, 4, 0), B.NECK: Vector3(8, 0, 0), B.HEAD: Vector3(4, -6, 4)}})
	return out


# ---------------------------------------------------------------- clips

static func _gait(kit: String, style: Dictionary, c: Dictionary) -> Dictionary:
	var st := style.duplicate()
	st["name"] = "%s_%s" % [kit, style["name"]]
	var clip := Body.gait(st, c)
	clip["props"] = {"hand": [[0.0, "main"]], "arrow": [[0.0, "off"]]}
	return clip


static func _props(arrow := "off") -> Dictionary:
	return {"hand": [[0.0, "main"]], "arrow": [[0.0, arrow]]}


## Wind and strike: the overhead cut (sword) or the two-handed blow (great, pole, levy).
static func strike(kit: String, p: Dictionary) -> Dictionary:
	var g: Dictionary = p["guard"]
	var wind := Rig.over(Body.body("stance"), Rig.over(carry(kit, "wind"), {"add": {B.SPINE: Vector3(6, 0, 0), B.CHEST: Vector3(8, -6, 0)}}))
	var hit := Rig.over(Body.body("ready"), Rig.over(carry(kit, "cut"), {
		"rot": {B.THIGH_L: Vector3(52, 8, -4), B.SHIN_L: Vector3(-48, 0, 0), B.THIGH_R: Vector3(-18, 0, 6), B.SHIN_R: Vector3(-14, 0, 0)},
		"add": {B.SPINE: Vector3(-18, 0, 0), B.CHEST: Vector3(-10, 8, 0)}, "root_pos": Vector3(0, -0.06, -0.24)}))
	var follow := Rig.over(hit, {"add": {B.SPINE: Vector3(-6, 0, 0)}, "rifle_add": {"grip": Vector3(0, -0.1, 0.05)}})
	var L := 1.3 if kit == "sword" else 1.6
	return {"name": kit + "_strike", "len": L, "keys": [[0.0, g], [L * 0.32, wind, "smooth"], [L * 0.43, hit, "in"],
		[L * 0.56, follow, "out"], [L, g, "smooth"]], "props": _props(), "events": [[L * 0.43, "strike"]]}


## The side sweep (great, pole, levy): wound back to the right, swept across at waist height.
static func sweep(kit: String, p: Dictionary) -> Dictionary:
	var g: Dictionary = p["guard"]
	var wind := Rig.over(Body.body("ready"), Rig.over(carry(kit, "side"), {"add": {B.HIPS: Vector3(0, -24, 0), B.SPINE: Vector3(0, -12, 0),
		B.CHEST: Vector3(0, -18, 0)}}))
	var hit := Rig.over(Body.body("ready"), Rig.over(carry(kit, "sweep"), {"add": {B.HIPS: Vector3(0, 20, 0), B.SPINE: Vector3(-6, 12, 0),
		B.CHEST: Vector3(-4, 18, 0)}, "rot": {B.THIGH_L: Vector3(40, 12, -4), B.SHIN_L: Vector3(-36, 0, 0)}, "root_pos": Vector3(0, -0.04, -0.15)}))
	var follow := Rig.over(hit, {"add": {B.CHEST: Vector3(0, 12, 0), B.HIPS: Vector3(0, 8, 0)}})
	return {"name": kit + "_sweep", "len": 1.5, "keys": [[0.0, g], [0.45, wind, "smooth"], [0.64, hit, "in"], [0.82, follow, "out"],
		[1.5, g, "smooth"]], "props": _props(), "events": [[0.64, "strike"]]}


## The thrust (sword, spear): a step in, the point driven forward.
static func thrust(kit: String, p: Dictionary) -> Dictionary:
	var g: Dictionary = p["guard"]
	var back := Rig.over(g, {"add": {B.HIPS: Vector3(0, -10, 0), B.CHEST: Vector3(4, -10, 0)}, "rifle_add": {"grip": Vector3(0.04, 0.02, 0.18)}})
	var hit := Rig.over(Body.body("ready"), Rig.over(carry(kit, "thrust"), {
		"rot": {B.THIGH_L: Vector3(56, 8, -4), B.SHIN_L: Vector3(-50, 0, 0), B.THIGH_R: Vector3(-22, 0, 6), B.SHIN_R: Vector3(-10, 0, 0)},
		"add": {B.SPINE: Vector3(-14, 6, 0), B.CHEST: Vector3(-6, 12, 0), B.HIPS: Vector3(0, 10, 0)}, "root_pos": Vector3(0, -0.06, -0.32)}))
	return {"name": kit + "_thrust", "len": 1.1, "keys": [[0.0, g], [0.3, back, "smooth"], [0.44, hit, "out"], [0.58, hit],
		[1.1, g, "smooth"]], "props": _props(), "events": [[0.44, "strike"]]}


## Taking a blow on the shield (or the haft): up, the jolt, braced, down.
static func block(kit: String, p: Dictionary) -> Dictionary:
	var g: Dictionary = p["guard"]
	var up: Dictionary = p.get("block", Rig.over(Body.body("ready"), carry(kit, "block")))
	var jolt := Rig.over(up, {"add": {B.SPINE: Vector3(10, 0, 0), B.CHEST: Vector3(8, -6, 0), B.NECK: Vector3(-8, 0, 0)},
		"root_pos": Vector3(0, 0, 0.1)})
	return {"name": kit + "_block", "len": 1.1, "keys": [[0.0, g], [0.16, up, "out"], [0.26, jolt, "out"], [0.55, up, "smooth"],
		[1.1, g, "smooth"]], "props": _props(), "events": [[0.26, "block"]]}


static func wall_lock(kit: String, p: Dictionary) -> Dictionary:
	var mid := Rig.over(p["wall"], {"add": {B.CHEST: Vector3(6, 8, 0)}})
	return {"name": kit + "_wall_lock", "len": 0.9, "keys": [[0.0, p["stand"]], [0.45, mid, "smooth"], [0.65, p["wall"], "out"],
		[0.9, p["wall"]]], "props": _props(), "events": [[0.62, "lock"]]}


## Spear front rank: kneel, butt to the ground, point up at the horse's chest.
static func brace(p: Dictionary) -> Dictionary:
	var mid := Rig.over(p["guard"], {"add": {B.SPINE: Vector3(-12, 0, 0)}, "root_pos": Vector3(0, -0.2, 0)})
	return {"name": "spear_brace", "len": 1.0, "keys": [[0.0, p["guard"]], [0.4, mid, "smooth"], [0.75, p["brace"], "out"], [1.0, p["brace"]]],
		"props": _props(), "events": [[0.75, "lock"]]}


## Crossbow: aim, loose (the prod snaps, the bow kicks), lower.
static func xshoot(p: Dictionary) -> Dictionary:
	var aim: Dictionary = p["aim"]
	var rec := Rig.over(aim, Rig.over(carry("xbow", "recoil"), {"add": {B.CHEST: Vector3(4, 0, 0), B.HEAD: Vector3(4, 0, 0)}}))
	return {"name": "xbow_shoot", "len": 1.4, "keys": [[0.0, p["stand"]], [0.45, aim, "smooth"], [0.75, aim], [0.8, rec, "out"],
		[1.05, aim, "smooth"], [1.4, aim]], "props": _props(), "events": [[0.75, "shot"]]}


## Spanning: nose down, foot in the stirrup, the cranequin wound (the right hand circles), then up to the shoulder.
static func xreload(p: Dictionary) -> Dictionary:
	var sp: Dictionary = p["span"]
	var keys: Array = [[0.0, p["aim"]], [0.5, sp, "smooth"]]
	var t := 0.5
	for k in 8:
		var a := TAU * k / 4.0
		t += 0.22
		keys.append([t, Rig.over(sp, {"hand_r": Vector3(0.08 * cos(a), 0.08 * sin(a), 0.3)}), "smooth"])
	keys.append([t + 0.4, Rig.over(sp, {"add": {B.SPINE: Vector3(14, 0, 0)}}), "smooth"])
	keys.append([t + 0.9, p["aim"], "smooth"])
	return {"name": "xbow_reload", "len": t + 1.0, "keys": keys, "props": _props(), "events": [[t + 0.2, "loaded"]]}


## The longbow: reach to the quiver, nock, draw (high for the volley or flat), hold, loose, and again.
static func bow_shot(elev: float, name: String) -> Dictionary:
	var body := _archer_body(elev)
	var reach := Rig.over(Rig.over(body, draw(elev * 0.6, 0.0)), {"hand_r": [B.HIPS, QUIVER + Vector3(0, 0.05, 0)],
		"pole_r": Vector3(0.9, -0.1, 0.5), "add": {B.CHEST: Vector3(0, 8, 0)}})
	reach["rifle"] = {"mode": "chest", "dir": Vector3(-0.6, -0.15, -0.79), "up": Vector3.UP, "grip": Vector3(-0.28, -0.12, -0.38)}
	var nock := Rig.over(Rig.over(_archer_body(elev * 0.6), draw(elev * 0.6, 0.0)), {})
	var full := Rig.over(body, draw(elev, 1.0))
	var loose := Rig.over(full, {"hand_r": [B.CHEST, Vector3(0.12, 0.33, 0.12)], "add": {B.CHEST: Vector3(0, -3, 0)}})
	var L := 2.4
	return {"name": "bow_" + name, "len": L, "keys": [[0.0, reach], [0.35, reach], [0.7, nock, "smooth"], [1.35, full, "smooth"],
		[1.65, full], [1.7, loose, "out"], [2.0, loose, "smooth"], [L, reach, "smooth"]],
		"props": {"hand": [[0.0, "main"]], "arrow": [[0.0, "off"], [0.42, "on"], [1.66, "off"]]}, "events": [[1.66, "loose"]]}


## Driving an archer's stake in with a mallet... with the bow slung on the left arm; two blows with the heel of the hands.
static func stake(p: Dictionary) -> Dictionary:
	var bent := Rig.over(Body.body("stand"), {"rifle": {"mode": "bone", "bone": B.CHEST, "at": Vector3(0.0, 1.22, 0.17), "rot": Vector3(0, 90, 32)}, "rot": {B.SPINE: Vector3(-30, 0, 0), B.CHEST: Vector3(-16, 0, 0),
		B.NECK: Vector3(12, 0, 0), B.THIGH_R: Vector3(32, 0, 6), B.SHIN_R: Vector3(-48, 0, 0), B.FOOT_R: Vector3(16, 0, 0),
		B.THIGH_L: Vector3(-8, 0, -6), B.SHIN_L: Vector3(-12, 0, 0)},
		"hand_r": [-1, Vector3(0.03, 1.0, -0.5)], "hand_l": [-1, Vector3(-0.03, 1.0, -0.5)], "pole_r": Vector3(0.8, -0.3, 0.0),
		"pole_l": Vector3(-0.8, -0.3, 0.0)})
	var up := Rig.over(bent, {"hand_r": [-1, Vector3(0.03, 1.25, -0.46)], "hand_l": [-1, Vector3(-0.03, 1.25, -0.46)],
		"add": {B.SPINE: Vector3(10, 0, 0)}})
	return {"name": "bow_stake", "len": 2.0, "keys": [[0.0, p["stand"]], [0.4, bent, "smooth"], [0.7, up, "smooth"], [0.85, bent, "in"],
		[1.25, up, "smooth"], [1.4, bent, "in"], [2.0, p["stand"], "smooth"]], "props": _props(), "events": [[0.85, "drive"], [1.4, "drive"]]}


## The banner swung left and right over the line.
static func wave(p: Dictionary) -> Dictionary:
	var s: Dictionary = p["stand"]
	var lft := Rig.over(Body.body("stand"), Rig.over(carry("banner", "left"), {"add": {B.CHEST: Vector3(0, 0, 8), B.SPINE: Vector3(0, 0, 4)}}))
	var rgt := Rig.over(Body.body("stand"), Rig.over(carry("banner", "right"), {"add": {B.CHEST: Vector3(0, 0, -8), B.SPINE: Vector3(0, 0, -4)}}))
	return {"name": "banner_wave", "len": 2.4, "loop": true, "keys": [[0.0, s], [0.6, lft, "smooth"], [1.2, s, "smooth"], [1.8, rgt, "smooth"],
		[2.4, s, "smooth"]], "props": _props()}


## A ball strikes him (the plates ring), or a near miss: rocked, then on again.
static func stagger(kit: String, p: Dictionary) -> Dictionary:
	var base: Dictionary = p["stand"]
	var jolt := Rig.over(base, {"add": {B.CHEST: Vector3(18, 10, 0), B.SPINE: Vector3(10, 0, 0), B.NECK: Vector3(16, 0, 0),
		B.HEAD: Vector3(12, -12, 8)}, "root_pos": Vector3(0, 0, 0.1)})
	var back := Rig.over(base, {"add": {B.CHEST: Vector3(8, 4, 0)}, "rot": {B.THIGH_R: Vector3(-22, 0, 6), B.SHIN_R: Vector3(-18, 0, 0)},
		"root_pos": Vector3(0, -0.03, 0.28)})
	return {"name": kit + "_hit", "len": 1.1, "keys": [[0.0, base], [0.08, jolt, "out"], [0.4, back, "smooth"], [1.1, base, "smooth"]],
		"props": _props(), "events": [[0.0, "hit"]]}


static func _hold(name: String, p: Dictionary, arrow := "off") -> Dictionary:
	return {"name": name, "len": 1.0, "loop": true, "keys": [[0.0, p], [1.0, p]], "props": _props(arrow)}


static func library() -> Dictionary:
	var out := {}
	for kit: String in KITS:
		var p := poses(kit)
		var mc := carry(kit, "march")
		var list: Array = [_gait(kit, SHAMBLE if kit == "levy" else MARCH, mc), _gait(kit, RUN, carry(kit, "run")),
			_gait(kit, WALL, carry(kit, "up") if kit == "sword" else carry(kit, "guard") if kit in ["spear", "great", "pole", "levy"] else mc),
			stagger(kit, p), Body.death_back(p["stand"], fall(kit)), Body.death_forward(p["stand"], fall(kit)),
			Body.prone_to_stand(p["prone"], fall(kit), p["stand"])]
		match kit:
			"sword":
				list.append_array([strike(kit, p), thrust(kit, p), block(kit, p), wall_lock(kit, p)])
			"spear":
				list.append_array([thrust(kit, p), block(kit, p), brace(p), wall_lock(kit, p)])
			"xbow":
				list.append_array([xshoot(p), xreload(p)])
			"bow":
				list.append_array([bow_shot(1.0, "volley"), bow_shot(0.0, "shot"), stake(p)])
			"banner":
				list.append(wave(p))
			"great", "pole", "levy":
				list.append_array([strike(kit, p), sweep(kit, p), block(kit, p)])
		for c: Dictionary in list:
			var nm: String = c["name"]
			if not nm.begins_with(kit + "_"):
				c = c.duplicate()
				c["name"] = kit + "_" + nm
				c["props"] = _props()
			out[c["name"]] = c
		for pn: String in p:
			out["%s_hold_%s" % [kit, pn]] = _hold("%s_hold_%s" % [kit, pn], p[pn], "on" if pn in ["volley", "shot"] else "off")
	return out


# ---------------------------------------------------------------- mounted

## The rider's pose on the horse (legs round the barrel, the left hand on the reins with the shield):
##   lance_up   the lance upright, its butt at the right thigh      couch   levelled under the right arm for the charge
##   impact     the couched lance struck home, the body thrown back   sword carry / point / raise / cut (M2.ride)
##   javelin    the scout's javelin raised to throw                 throw   its release
static func ride(mode: String) -> Dictionary:
	if mode in ["carry", "point", "raise", "cut"]:
		return M2.ride(mode)
	var base := M2.ride("carry")
	match mode:
		"lance_up":
			return Rig.over(base, held(Vector3(0.26, -0.3, -0.12), Vector3(0.0, 1.0, -0.12), Vector3(0, 0, -1), null, Vector3(0.8, -0.6, 0.2)))
		"couch":
			return Rig.over(base, Rig.over(held(Vector3(0.22, -0.2, -0.26), Vector3(-0.13, 0.03, -1.0), Vector3.UP, null, Vector3(0.8, -0.2, 0.6)),
				{"add": {B.SPINE: Vector3(-12, 0, 0), B.CHEST: Vector3(-6, -6, 0), B.NECK: Vector3(14, 6, 0)}}))
		"impact":
			return Rig.over(base, Rig.over(held(Vector3(0.24, -0.16, -0.18), Vector3(-0.1, -0.22, -1.0), Vector3.UP, null, Vector3(0.8, -0.2, 0.6)),
				{"add": {B.SPINE: Vector3(14, 0, 0), B.CHEST: Vector3(10, 10, 0), B.NECK: Vector3(-6, 0, 0), B.HEAD: Vector3(-8, -6, 0)}}))
		"javelin":
			return Rig.over(base, Rig.over(held(Vector3(0.28, 0.36, 0.14), Vector3(0.0, 0.22, -1.0), Vector3.UP, null, Vector3(0.9, 0.2, 0.3)),
				{"add": {B.CHEST: Vector3(4, -16, 0)}}))
		"throw":
			return Rig.over(base, Rig.over(held(Vector3(0.14, 0.2, -0.5), Vector3(0.0, 0.0, -1.0), Vector3.UP, null, Vector3(0.8, -0.3, 0.2)),
				{"add": {B.SPINE: Vector3(-10, 0, 0), B.CHEST: Vector3(-6, 14, 0)}}))
	return base


## Thrown from the saddle (a ball or the impact): his model-space pose u of the way from the seat to the ground ahead.
static func unhorsed(u: float) -> Dictionary:
	var sit := M2.ride("carry")
	var air := Rig.over(Body.body("stand"), {"root_rot": Vector3(40, 0, 10), "root_pos": Vector3(0, 0.2, 0), "rifle": {"mode": "hand", "rot": Vector3(55, 0, 0)},
		"hand_r": null, "hand_l": null, "rot": {B.THIGH_R: Vector3(50, 0, 20), B.SHIN_R: Vector3(-60, 0, 0), B.THIGH_L: Vector3(30, 0, -20),
		B.SHIN_L: Vector3(-40, 0, 0), B.UARM_R: Vector3(120, 0, 50), B.UARM_L: Vector3(130, 0, -50), B.NECK: Vector3(20, 0, 0)}})
	var down := Rig.over(Body.body("prone"), {"root_rot": Vector3(90, 0, 6), "root_pos": Vector3(0, 0, -0.25), "rifle": {"mode": "hand", "rot": Vector3(55, 0, 0)},
		"hand_r": null, "hand_l": null, "rot": {B.UARM_R: Vector3(100, 0, 55), B.UARM_L: Vector3(120, 0, -60), B.HEAD: Vector3(0, -35, 8)}})
	if u < 0.5:
		return {"a": sit, "b": air, "t": u * 2.0}
	return {"a": air, "b": down, "t": (u - 0.5) * 2.0}
