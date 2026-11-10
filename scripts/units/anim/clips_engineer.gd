extends RefCounted
## The engineer section's moves (Building Chat 1, 2026-11-10). Clip names are "eng_<move>".
##   walk, walk_plank, walk_coil, walk_panel   walking with the shovel on the shoulder, a plank, the wire coil, a panel
##   pick, shovel        digging: the pick swing (up, down into the ground, lever) and the shovel (scoop, lift, throw
##                       forward onto the parapet)
##   saw, hammer, hammer_low   building: sawing a plank on the trestle, nailing high and low on the plank wall
##   drive, hold         wire: the mallet driving a picket, the mate kneeling to hold it straight
##   cut                 cutting the wire off the coil and twisting it round the picket
##   prise               stripping a wreck: the bar in the seam, heaved down to spring the panel
##   lift                two men (or the NCO and a sapper) lifting a sleeper end from the ground to the waist
##   spike               the spike maul driving a rail spike
##   nco_check           the NCO reads the plan, looks up, points at the work, reads again
##   hit, death_back, death_forward, prone_to_stand   the shared ones, tools dropped
## Work spots (model space, the man facing -Z): the pick and shovel strike the ground at about z -0.7; a picket
## top is at PICKET_TOP; the wreck seam at SEAM; a sleeper end is held at z -0.3.
## Clip "props": {"hand": [[t, tool]], "plan": [[t, "on"]]}; events: strike, throw, cut, heave, spike.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const EB := preload("res://scripts/units/engineer_builder.gd")

const ARMS_FREE := {B.UARM_R: Vector3(2, 0, 5), B.FARM_R: Vector3(8, 0, 0), B.UARM_L: Vector3(2, 0, -5), B.FARM_L: Vector3(8, 0, 0)}
const PICKET_TOP := Vector3(0.0, 1.15, -0.62)
const SEAM := Vector3(0.05, 0.62, -0.62)
const WORK := {"name": "walk", "v": 1.25, "T": 1.04, "duty": 0.6, "hip": 0.87, "bob": 0.022, "bob_sign": 1.0, "lift": 0.07,
	"lean": 6.0, "fwd": 0.03, "hip_yaw": 7.0, "sway": 0.025, "shoulder_yaw": 2.0, "strike": 12.0, "push": 26.0, "width": 0.1}
const LADEN := {"name": "walk", "v": 1.0, "T": 1.15, "duty": 0.62, "hip": 0.86, "bob": 0.028, "bob_sign": 1.0, "lift": 0.06,
	"lean": 8.0, "fwd": 0.03, "hip_yaw": 6.0, "sway": 0.03, "shoulder_yaw": 1.0, "strike": 10.0, "push": 22.0, "width": 0.11}


static func hands_free() -> Dictionary:
	return {"rifle": {"mode": "hand", "rot": Vector3(0, 0, 0)}, "hand_r": null, "hand_l": null, "rot": ARMS_FREE}


## A two-handed tool placed in the chest frame (grip relative to the chest joint): right hand on the grip, left hand
## where the tool's TOOL_L says.
static func tool(kind: String, grip: Vector3, dir: Vector3, up := Vector3.UP, pole_r := Vector3(0.8, -0.4, 0.2),
		pole_l := Vector3(-0.8, -0.4, 0.2)) -> Dictionary:
	var out := {"rifle": {"mode": "chest", "dir": dir, "up": up, "grip": grip}, "hand_r": B.GRIP_R, "pole_r": pole_r,
		"hand_item": kind}
	if EB.TOOL_L.has(kind) and kind != "hammer":
		out["hand_l"] = EB.TOOL_L[kind]
		out["pole_l"] = pole_l
	return out


## The same with the left hand on a model-space point (holding a nail, the plank, the picket).
static func tool_one(kind: String, grip: Vector3, dir: Vector3, up: Vector3, left: Variant, pole_r := Vector3(0.8, -0.4, 0.2)) -> Dictionary:
	var out := tool(kind, grip, dir, up, pole_r)
	out.erase("hand_l")
	if left == null:
		out["hand_l"] = null
		out["rot"] = {B.UARM_L: Vector3(2, 0, -8), B.FARM_L: Vector3(-20, 0, 0)}
	else:
		out["hand_l"] = [-1, left]
		out["pole_l"] = Vector3(-0.8, -0.5, 0.2)
	return out


static func _bent(spine: float, chest := 0.0, wide := true) -> Dictionary:
	var p := Rig.over(Body.body("ready"), {"add": {B.SPINE: Vector3(-spine, 0, 0), B.CHEST: Vector3(-chest, 0, 0),
		B.NECK: Vector3(spine * 0.45, 0, 0)}})
	if wide:
		p = Rig.over(p, {"rot": {B.THIGH_R: Vector3(18, -6, 10), B.SHIN_R: Vector3(-22, 0, 0), B.FOOT_R: Vector3(4, 6, -10),
			B.THIGH_L: Vector3(30, 8, -8), B.SHIN_L: Vector3(-26, 0, 0), B.FOOT_L: Vector3(-4, -8, 8)}})
	return p


static func _kneel(lean := 14.0) -> Dictionary:
	return Rig.over(Body.body("kneel"), {"add": {B.HIPS: Vector3(0, 28, 0), B.SPINE: Vector3(-lean, 0, 0), B.CHEST: Vector3(-lean * 0.3, 8, 0),
		B.NECK: Vector3(lean * 0.4, -16, 0), B.HEAD: Vector3(8, -10, 14)}})


static func _with(body: Dictionary, carry: Dictionary) -> Dictionary:
	return Rig.over(body, carry)


static func poses() -> Dictionary:
	var stand := _with(Body.body("stand"), hands_free())
	return {
		"stand": stand,
		"shovel_rest": _with(Body.body("stand"), Rig.over(tool("shovel", Vector3(0.2, -0.12, -0.18), Vector3(0.05, -0.97, -0.2),
			Vector3(0, 0.2, -0.98)), {"hand_l": [B.CHEST, Vector3(0.1, 1.15, -0.26)], "pole_l": Vector3(-0.6, -0.5, 0.3)})),
		"plan": nco_read(),
		"point": nco_point(),
		"kneel": _with(_kneel(), hands_free()),
		"prone": _with(Body.body("prone"), hands_free()),
	}


# ---------------------------------------------------------------- carries for walking

static func carry(name: String) -> Dictionary:
	match name:
		"shovel":
			# On the right shoulder, the blade behind, the hand on the shaft in front.
			return Rig.over(tool("shovel", Vector3(0.2, 0.22, -0.2), Vector3(0.08, 0.42, 0.9), Vector3(0, 0.9, -0.42),
				Vector3(0.8, -0.6, 0.0)), {"hand_l": null, "rot": {B.UARM_L: Vector3(2, 0, -5), B.FARM_L: Vector3(8, 0, 0)}})
		"plank":
			return Rig.over(tool("plank", Vector3(0.2, 0.33, -0.08), Vector3(0.04, 0.0, -1.0), Vector3.UP, Vector3(0.8, -0.7, 0.2)),
				{"hand_l": null, "rot": {B.UARM_L: Vector3(2, 0, -5), B.FARM_L: Vector3(8, 0, 0)}})
		"coil":
			return tool("coil", Vector3(0.24, -0.14, -0.34), Vector3(-1.0, 0.0, 0.0), Vector3.UP, Vector3(0.8, -0.6, 0.2),
				Vector3(-0.8, -0.6, 0.2))
		"panel":
			return tool("panel", Vector3(0.24, -0.06, -0.3), Vector3(-1.0, 0.0, 0.0), Vector3.UP, Vector3(0.8, -0.6, 0.2),
				Vector3(-0.8, -0.6, 0.2))
	return hands_free()


static func _gait(name: String, style: Dictionary, c: Dictionary, item: String) -> Dictionary:
	var st := style.duplicate()
	st["name"] = name
	var clip := Body.gait(st, c)
	clip["props"] = {"hand": [[0.0, item]]}
	return clip


# ---------------------------------------------------------------- digging

static func pick() -> Dictionary:
	var body := _bent(14.0)
	var up := Rig.over(body, Rig.over(tool("pick", Vector3(0.16, 0.42, 0.06), Vector3(0.0, 0.6, 0.8), Vector3(0, 0.8, -0.6),
		Vector3(0.9, -0.2, 0.3), Vector3(-0.9, -0.2, 0.3)), {"add": {B.SPINE: Vector3(16, 0, 0), B.CHEST: Vector3(6, 0, 0),
		B.NECK: Vector3(-8, 0, 0)}}))
	var over := Rig.over(body, Rig.over(tool("pick", Vector3(0.1, 0.38, -0.3), Vector3(0.0, 0.3, -0.95), Vector3(0, 0.95, 0.3)),
		{"add": {B.SPINE: Vector3(2, 0, 0)}}))
	var hit := Rig.over(body, Rig.over(tool("pick", Vector3(0.06, -0.24, -0.44), Vector3(0.0, -0.62, -0.78), Vector3(0, 0.78, -0.62),
		Vector3(0.8, -0.3, 0.2), Vector3(-0.8, -0.3, 0.2)), {"add": {B.SPINE: Vector3(-22, 0, 0), B.CHEST: Vector3(-8, 0, 0)},
		"root_pos": Vector3(0, -0.05, 0)}))
	var lever := Rig.over(hit, Rig.over(tool("pick", Vector3(0.06, -0.14, -0.3), Vector3(0.0, -0.82, -0.57), Vector3(0, 0.57, -0.82)),
		{"add": {B.SPINE: Vector3(-18, 0, 0)}}))
	return {"name": "eng_pick", "len": 1.5, "loop": true, "keys": [[0.0, up], [0.42, over, "in"], [0.56, hit, "in"],
		[0.8, hit], [1.0, lever, "smooth"], [1.5, up, "smooth"]], "props": {"hand": [[0.0, "pick"]]}, "events": [[0.56, "strike"]]}


static func shovel() -> Dictionary:
	var body := _bent(10.0)
	var scoop := Rig.over(body, Rig.over(tool("shovel", Vector3(0.18, -0.04, -0.24), Vector3(0.0, -0.6, -0.8), Vector3(0, 0.8, -0.6),
		Vector3(0.9, -0.1, 0.4), Vector3(-0.7, -0.6, 0.1)), {"add": {B.SPINE: Vector3(-26, 0, 0), B.CHEST: Vector3(-6, 0, 0)},
		"root_pos": Vector3(0, -0.06, 0)}))
	var push := Rig.over(scoop, Rig.over(tool("shovel", Vector3(0.16, -0.1, -0.36), Vector3(0.0, -0.5, -0.86), Vector3(0, 0.86, -0.5),
		Vector3(0.9, -0.1, 0.4), Vector3(-0.7, -0.6, 0.1)), {"root_pos": Vector3(0, -0.08, -0.05)}))
	var lift := Rig.over(body, Rig.over(tool("shovel", Vector3(0.22, -0.2, 0.08), Vector3(-0.05, -0.12, -0.99), Vector3(0, 0.99, -0.12),
		Vector3(0.9, -0.2, 0.4), Vector3(-0.6, -0.7, 0.0)), {"add": {B.SPINE: Vector3(-6, 0, 0), B.HIPS: Vector3(0, -10, 0)}}))
	var throw := Rig.over(Body.body("stance"), Rig.over(tool("shovel", Vector3(0.12, 0.02, -0.34), Vector3(0.05, 0.2, -0.98),
		Vector3(0, 0.98, 0.2), Vector3(0.9, -0.3, 0.3), Vector3(-0.7, -0.7, 0.0)), {"add": {B.HIPS: Vector3(0, 20, 0),
		B.SPINE: Vector3(4, 6, 0), B.CHEST: Vector3(6, 6, 0), B.NECK: Vector3(-6, -10, 0)}}))
	return {"name": "eng_shovel", "len": 1.9, "loop": true, "keys": [[0.0, scoop], [0.3, push, "smooth"], [0.8, lift, "smooth"],
		[1.08, throw, "in"], [1.3, throw], [1.9, scoop, "smooth"]], "props": {"hand": [[0.0, "shovel"]]}, "events": [[1.08, "throw"]]}


# ---------------------------------------------------------------- building

static func saw() -> Dictionary:
	# Bent over the trestle, left hand flat on the plank, the saw stroking along the cut.
	var body := Rig.over(_bent(26.0, 6.0), {"add": {B.HIPS: Vector3(0, -12, 0), B.CHEST: Vector3(0, 6, 0)}})
	var left := Vector3(-0.2, 0.66, -0.52)
	var d := Vector3(0.0, -0.62, -0.78)
	var a := Rig.over(body, tool_one("saw", Vector3(0.16, -0.04, -0.36), d, Vector3(0, 0.78, -0.62), left, Vector3(0.9, 0.2, 0.4)))
	var b := Rig.over(body, tool_one("saw", Vector3(0.16, -0.04, -0.36) + d * 0.22, d, Vector3(0, 0.78, -0.62), left,
		Vector3(0.9, 0.2, 0.4)))
	return {"name": "eng_saw", "len": 0.9, "loop": true, "keys": [[0.0, a], [0.45, b, "smooth"], [0.9, a, "smooth"]],
		"props": {"hand": [[0.0, "saw"]]}}


## Nailing a plank on the wall at height h (model y), the left hand holding the nail.
static func hammer(h := 1.05) -> Dictionary:
	var low := h < 0.7
	var body := _kneel(18.0) if low else Rig.over(Body.body("stand"), {"add": {B.SPINE: Vector3(-4, 0, 0)}})
	var nail := Vector3(-0.06, h, -0.5)
	var up := Rig.over(body, tool_one("hammer", Vector3(0.24, 0.36 - (0.5 if low else 0.0), -0.12), Vector3(0.0, 0.95, 0.3),
		Vector3(0, -0.3, 0.95), nail, Vector3(0.8, -0.5, 0.2)))
	var hit_grip := Vector3(0.12, h - 1.24 + 0.02 + (0.24 if low else 0.0), -0.3)
	var hit := Rig.over(body, tool_one("hammer", hit_grip, Vector3(-0.1, 0.0, -1.0), Vector3(0, 1, 0), nail, Vector3(0.8, -0.6, 0.2)))
	return {"name": "eng_hammer_low" if low else "eng_hammer", "len": 0.7, "loop": true,
		"keys": [[0.0, up], [0.26, hit, "in"], [0.4, hit], [0.7, up, "smooth"]], "props": {"hand": [[0.0, "hammer"]]},
		"events": [[0.26, "strike"]]}


# ---------------------------------------------------------------- wire

static func drive() -> Dictionary:
	var body := _bent(6.0)
	var up := Rig.over(body, Rig.over(tool("mallet", Vector3(0.1, 0.5, 0.0), Vector3(0.0, 0.85, 0.5), Vector3(0, 0.5, -0.85),
		Vector3(0.9, -0.2, 0.3), Vector3(-0.9, -0.2, 0.3)), {"add": {B.SPINE: Vector3(10, 0, 0), B.NECK: Vector3(-6, 0, 0)}}))
	var hit := Rig.over(body, Rig.over(tool("mallet", Vector3(0.06, 0.06, -0.22), Vector3(0.0, -0.12, -0.99),
		Vector3(0, 0.99, -0.12)), {"add": {B.SPINE: Vector3(-4, 0, 0)}}))
	return {"name": "eng_drive", "len": 1.2, "loop": true, "keys": [[0.0, up], [0.5, hit, "in"], [0.66, hit], [1.2, up, "smooth"]],
		"props": {"hand": [[0.0, "mallet"]]}, "events": [[0.5, "strike"]]}


## The mate kneeling at the picket, both hands round it below the top, head turned away from the blows.
static func hold() -> Dictionary:
	var k := Rig.over(_kneel(10.0), {"hand_r": [-1, Vector3(0.0, 0.48, -0.5)], "hand_l": [-1, Vector3(-0.02, 0.4, -0.5)],
		"pole_r": Vector3(0.7, -0.5, 0.2), "pole_l": Vector3(-0.7, -0.5, 0.2), "rifle": {"mode": "hand"},
		"add": {B.NECK: Vector3(0, 0, 0), B.HEAD: Vector3(-6, 30, 0)}})
	var flinch := Rig.over(k, {"add": {B.NECK: Vector3(-10, 10, 0), B.CHEST: Vector3(4, 0, 0)}})
	return {"name": "eng_hold", "len": 1.2, "loop": true, "keys": [[0.0, k], [0.5, k], [0.56, flinch, "out"], [0.9, k, "smooth"],
		[1.2, k]], "props": {"hand": [[0.0, "none"]]}}


static func cut() -> Dictionary:
	var body := _bent(24.0, 6.0)
	var a := Rig.over(body, tool("cutters", Vector3(0.1, -0.12, -0.42), Vector3(0.0, -0.5, -0.86), Vector3(0, 0.86, -0.5)))
	var b := Rig.over(body, tool("cutters", Vector3(0.08, -0.16, -0.46), Vector3(0.0, -0.55, -0.83), Vector3(0, 0.83, -0.55)))
	var twist := Rig.over(body, Rig.over(tool("cutters", Vector3(0.12, -0.1, -0.42), Vector3(0.3, -0.5, -0.8), Vector3(0, 0.85, -0.5)),
		{"add": {B.CHEST: Vector3(0, -10, 0)}}))
	return {"name": "eng_cut", "len": 1.4, "loop": true, "keys": [[0.0, a], [0.3, b, "in"], [0.45, b], [0.8, twist, "smooth"],
		[1.1, twist], [1.4, a, "smooth"]], "props": {"hand": [[0.0, "cutters"]]}, "events": [[0.3, "cut"]]}


# ---------------------------------------------------------------- the wreck

static func prise() -> Dictionary:
	var body := _bent(16.0)
	var seat := Rig.over(body, tool("bar", Vector3(0.16, 0.0, -0.08), Vector3(-0.05, -0.32, -0.95), Vector3(0, 0.95, -0.32),
		Vector3(0.9, -0.3, 0.3), Vector3(-0.9, -0.3, 0.3)))
	var heave := Rig.over(Rig.over(_bent(30.0), {"root_pos": Vector3(0, -0.12, 0.02)}), tool("bar", Vector3(0.14, -0.4, -0.2),
		Vector3(-0.05, 0.12, -0.99), Vector3(0, 0.99, 0.12), Vector3(0.9, 0.2, 0.3), Vector3(-0.9, 0.2, 0.3)))
	return {"name": "eng_prise", "len": 1.8, "loop": true, "keys": [[0.0, seat], [0.7, heave, "smooth"], [1.0, heave],
		[1.8, seat, "smooth"]], "props": {"hand": [[0.0, "bar"]]}, "events": [[0.9, "heave"]]}


# ---------------------------------------------------------------- the track

## A sleeper end lifted from the ground to the waist, both hands under it (the end at z -0.3).
static func lift() -> Dictionary:
	var low := Rig.over(Rig.over(Body.body("kneel"), {"rot": {B.HIPS: Vector3(0, 0, 0), B.THIGH_R: Vector3(70, -10, 12),
		B.SHIN_R: Vector3(-110, 0, 0), B.FOOT_R: Vector3(30, 0, 0), B.THIGH_L: Vector3(70, 10, -12), B.SHIN_L: Vector3(-110, 0, 0),
		B.FOOT_L: Vector3(30, 0, 0), B.SPINE: Vector3(-24, 0, 0), B.CHEST: Vector3(-8, 0, 0), B.NECK: Vector3(14, 0, 0),
		B.HEAD: Vector3(0, 0, 0)}}), {"rifle": {"mode": "hand"},
		"hand_r": [-1, Vector3(0.11, 0.1, -0.34)], "hand_l": [-1, Vector3(-0.11, 0.1, -0.34)],
		"pole_r": Vector3(0.9, -0.2, 0.0), "pole_l": Vector3(-0.9, -0.2, 0.0)})
	var high := Rig.over(Rig.over(Body.body("stand"), {"add": {B.SPINE: Vector3(8, 0, 0), B.CHEST: Vector3(2, 0, 0)}}),
		{"rifle": {"mode": "hand"}, "hand_r": [-1, Vector3(0.11, 0.8, -0.3)], "hand_l": [-1, Vector3(-0.11, 0.8, -0.3)],
		"pole_r": Vector3(0.9, -0.4, 0.2), "pole_l": Vector3(-0.9, -0.4, 0.2)})
	return {"name": "eng_lift", "len": 1.6, "keys": [[0.0, low], [0.3, low], [1.2, high, "smooth"], [1.6, high]],
		"props": {"hand": [[0.0, "none"]]}, "events": [[0.3, "lift"]]}


static func spike() -> Dictionary:
	var body := _bent(10.0)
	var up := Rig.over(body, Rig.over(tool("mallet", Vector3(0.12, 0.48, 0.06), Vector3(0.0, 0.7, 0.72), Vector3(0, 0.72, -0.7),
		Vector3(0.9, -0.2, 0.3), Vector3(-0.9, -0.2, 0.3)), {"add": {B.SPINE: Vector3(12, 0, 0)}}))
	var hit := Rig.over(body, Rig.over(tool("mallet", Vector3(0.06, -0.3, -0.36), Vector3(0.0, -0.6, -0.8), Vector3(0, 0.8, -0.6)),
		{"add": {B.SPINE: Vector3(-28, 0, 0), B.CHEST: Vector3(-8, 0, 0)}, "root_pos": Vector3(0, -0.06, 0)}))
	return {"name": "eng_spike", "len": 1.3, "loop": true, "keys": [[0.0, up], [0.55, hit, "in"], [0.72, hit], [1.3, up, "smooth"]],
		"props": {"hand": [[0.0, "mallet"]]}, "events": [[0.55, "spike"]]}


# ---------------------------------------------------------------- the NCO

static func nco_read() -> Dictionary:
	return Rig.over(Body.body("stand"), {"rifle": {"mode": "hand"}, "hand_l": [B.CHEST, Vector3(-0.08, 1.12, -0.34)],
		"pole_l": Vector3(-0.8, -0.6, 0.0), "hand_r": [B.CHEST, Vector3(0.06, 1.1, -0.32)], "pole_r": Vector3(0.8, -0.6, 0.0),
		"add": {B.NECK: Vector3(22, 0, 0), B.HEAD: Vector3(14, 0, 0)}, "plan": "on"})


static func nco_point() -> Dictionary:
	return Rig.over(Body.body("stand"), {"rifle": {"mode": "hand"}, "hand_l": [B.CHEST, Vector3(-0.12, 1.08, -0.3)],
		"pole_l": Vector3(-0.8, -0.6, 0.0), "hand_r": [B.CHEST, Vector3(0.42, 1.42, -0.55)], "pole_r": Vector3(0.6, -0.6, 0.3),
		"add": {B.NECK: Vector3(-2, -20, 0), B.HEAD: Vector3(0, -12, 0), B.CHEST: Vector3(0, -10, 0)}, "plan": "on"})


static func nco_check() -> Dictionary:
	var read := nco_read()
	var look := Rig.over(read, {"add": {B.NECK: Vector3(-26, -14, 0), B.HEAD: Vector3(-12, -8, 0)}})
	var point := nco_point()
	return {"name": "eng_nco_check", "len": 4.0, "loop": true, "keys": [[0.0, read], [1.0, read], [1.4, look, "smooth"],
		[1.9, point, "smooth"], [2.8, point], [3.3, read, "smooth"], [4.0, read]],
		"props": {"hand": [[0.0, "none"]], "plan": [[0.0, "on"]]}}


# ---------------------------------------------------------------- the library

static func _hold(name: String, p: Dictionary, item := "none") -> Dictionary:
	return {"name": name, "len": 1.0, "loop": true, "keys": [[0.0, p], [1.0, p]], "props": {"hand": [[0.0, item]],
		"plan": [[0.0, p.get("plan", "off")]]}}


static func library() -> Dictionary:
	var out := {}
	var p := poses()
	var fall := hands_free()
	var list: Array = [
		_gait("eng_walk", WORK, carry("shovel"), "shovel"), _gait("eng_walk_plank", LADEN, carry("plank"), "plank"),
		_gait("eng_walk_coil", LADEN, carry("coil"), "coil"), _gait("eng_walk_panel", LADEN, carry("panel"), "panel"),
		pick(), shovel(), saw(), hammer(1.05), hammer(0.5), drive(), hold(), cut(), prise(), lift(), spike(), nco_check()]
	for c: Dictionary in list:
		out[c["name"]] = c
	for c: Dictionary in [Body.hit(p["stand"]), Body.death_back(p["stand"], fall), Body.death_forward(p["stand"], fall),
			Body.prone_to_stand(p["prone"], fall, p["stand"])]:
		var d := c.duplicate()
		d["name"] = "eng_" + String(c["name"])
		d["props"] = {"hand": [[0.0, "none"]]}
		out[d["name"]] = d
	for pn: String in ["stand", "plan", "point", "kneel"]:
		out["eng_hold_" + pn] = _hold("eng_hold_" + pn, p[pn])
	return out
