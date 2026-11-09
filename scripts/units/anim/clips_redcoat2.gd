extends RefCounted
## Red coats round 2 moves (Building Chat 1, 2026-11-10): the grenadier's throw, the light infantry's skirmishing,
## the gun crew's drill (poses worked out from the gun's own points), the dragoon in the saddle.
## Same pose specs as the rest (see rig.gd).

const B := preload("res://scripts/units/soldier_builder.gd")
const RB := preload("res://scripts/units/redcoat_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const M := preload("res://scripts/units/anim/clips_musket.gd")
const DEG := PI / 180.0

## The light infantry's run: low and quick, the musket trailed.
const SKIRMISH := {"name": "light_run", "v": 3.0, "T": 0.62, "duty": 0.38, "hip": 0.8, "bob": 0.03, "bob_sign": -1.0,
	"lift": 0.18, "lean": 20.0, "fwd": 0.1, "hip_yaw": 8.0, "sway": 0.016, "shoulder_yaw": 4.0,
	"strike": 8.0, "push": 30.0, "width": 0.09}
const DRILL: Array[String] = ["sponge", "load", "ram", "prime", "aim", "fire", "recoil", "run_up"]
const CREW: Array[String] = ["gunner_sponge", "gunner_load", "gunner_vent", "gunner_aim", "gunner_fire"]


static func carry(name: String) -> Dictionary:
	match name:
		"slung":
			return {"rifle": {"mode": "back"}, "hand_r": null, "hand_l": null}
		"trail":
			# Trailed: held low in the right hand at the point of balance, level, the muzzle a little up.
			return {"rifle": {"mode": "hand", "rot": Vector3(6, 0, 0)},
				"rot": {B.UARM_R: Vector3(14, 0, 8), B.FARM_R: Vector3(16, 0, 0), B.UARM_L: Vector3(-20, 0, -8),
					B.FARM_L: Vector3(50, 0, 0)}, "hand_r": null, "hand_l": null}
	return M.carry(name)


# ---------------------------------------------------------------- grenadiers

static func grenadier_poses() -> Dictionary:
	var P := M.poses()
	var st := Rig.over(M.attention(), carry("slung"))
	var arms_down := {B.UARM_R: Vector3(4, 0, 6), B.FARM_R: Vector3(10, 0, 0), B.UARM_L: Vector3(4, 0, -6), B.FARM_L: Vector3(10, 0, 0)}
	var pouch := Rig.over(st, {"hand_r": [B.HIPS, Vector3(-0.1, 0.98, -0.16)], "pole_r": Vector3(0.3, -0.6, 0.5),
		"rot": arms_down.duplicate(), "add": {B.CHEST: Vector3(-6, 14, 0), B.NECK: Vector3(10, 0, 0)}})
	var light := Rig.over(st, {"hand_r": [B.CHEST, Vector3(-0.03, 1.33, -0.25)], "pole_r": Vector3(0.6, -0.6, 0.1),
		"hand_l": [B.CHEST, Vector3(-0.08, 1.35, -0.2)], "pole_l": Vector3(-0.6, -0.6, 0.1),
		"add": {B.NECK: Vector3(18, 0, 0), B.HEAD: Vector3(10, 0, 0)}})
	var wind := Rig.over(Rig.over(Body.body("stance"), carry("slung")), {"rot": {B.UARM_R: Vector3(0, -35, 100),
		B.FARM_R: Vector3(0, 0, 85), B.HAND_R: Vector3(-20, 0, 0), B.UARM_L: Vector3(80, 0, -12), B.FARM_L: Vector3(8, 0, 0)},
		"add": {B.SPINE: Vector3(6, 0, 0), B.CHEST: Vector3(4, -18, 0)}})
	var release := Rig.over(Rig.over(Body.body("ready"), carry("slung")), {"rot": {B.UARM_R: Vector3(158, 0, 14),
		B.FARM_R: Vector3(12, 0, 0), B.UARM_L: Vector3(20, 0, -24), B.FARM_L: Vector3(40, 0, 0)},
		"add": {B.SPINE: Vector3(-10, 0, 0), B.CHEST: Vector3(-8, 22, 0)}})
	var follow := Rig.over(Rig.over(Body.body("ready"), carry("slung")), {"rot": {B.UARM_R: Vector3(62, 0, 6),
		B.FARM_R: Vector3(18, 0, 0), B.UARM_L: Vector3(-10, 0, -20), B.FARM_L: Vector3(30, 0, 0)},
		"add": {B.SPINE: Vector3(-18, 0, 0), B.CHEST: Vector3(-6, 28, 0)}})
	var out := P.duplicate()
	out.merge({"slung": st, "pouch": pouch, "light": light, "wind": wind, "release": release, "follow": follow}, true)
	return out


## Grenadier throws a lit grenade: musket slung, grenade from the pouch, fuse lit at the match case on the belt,
## wind up, overarm throw, follow through, back. Prop "grenade": "hand" while held, "lit" once the fuse burns.
static func grenadier_throw() -> Dictionary:
	var P := grenadier_poses()
	return {"name": "grenadier_throw", "len": 3.6,
		"keys": [[0.0, P["slung"]], [0.5, P["pouch"], "smooth"], [0.75, P["pouch"]], [1.25, P["light"], "smooth"], [1.8, P["light"]],
			[2.4, P["wind"], "smooth"], [2.62, P["release"], "in"], [2.9, P["follow"], "out"], [3.6, P["slung"], "smooth"]],
		"events": [[1.55, "fuse"], [2.6, "throw"]],
		"props": {"grenade": [[0.0, "off"], [0.62, "hand"], [1.55, "lit"], [2.6, "off"]]}}


# ---------------------------------------------------------------- light infantry

static func light_poses() -> Dictionary:
	var P := M.poses()
	var crouch := Rig.over(P["kneel_ready"], {"add": {B.SPINE: Vector3(-22, 0, 0), B.CHEST: Vector3(-10, 0, 0),
		B.NECK: Vector3(14, 0, 0)}, "root_pos": Vector3(0, -0.04, 0)})
	var kick := Rig.over(P["kneel"], {"rifle_add": {"dir": Vector3(0, 0.22, 0), "off": Vector3(0, 0.02, 0.04)},
		"add": {B.CHEST: Vector3(4, 0, 0), B.SPINE: Vector3(3, 0, 0)}})
	var prone_aim := Rig.over(Body.body("prone"), {"rifle": {"mode": "aim", "dir": Vector3(0, -0.02, -1), "off": Vector3(0, 0.1, 0.02)},
		"hand_r": B.GRIP_R, "pole_r": Vector3(0.6, -0.3, 0.3), "hand_l": RB.GRIP_L, "pole_l": Vector3(-0.5, -0.4, -0.2),
		"add": {B.CHEST: Vector3(10, 0, 0), B.NECK: Vector3(10, 0, 0)}})
	var cover := Rig.over(Body.body("kneel"), {"rifle": {"mode": "order", "butt": Vector3(0.28, 0.02, -0.3)},
		"hand_r": Vector3(0, 0, -0.6), "pole_r": Vector3(0.5, -0.3, 0.4),
		"add": {B.SPINE: Vector3(-30, 0, 0), B.CHEST: Vector3(-14, 0, 0), B.NECK: Vector3(25, 0, 0)}})
	var out := P.duplicate()
	out.merge({"crouch": crouch, "kick": kick, "prone_aim": prone_aim, "cover": cover,
		"run": Rig.over(Body.body("run"), carry("trail"))}, true)
	return out


## Fire from behind cover: crouched behind it, up on one knee, aim, fire (the flash, the shot, the kick),
## down again and start to prime.
static func light_fire() -> Dictionary:
	var P := light_poses()
	return {"name": "light_fire", "len": 4.0,
		"keys": [[0.0, P["cover"]], [0.6, P["crouch"], "smooth"], [1.2, P["kneel"], "smooth"], [1.7, P["kneel"]],
			[1.78, P["kick"], "out"], [2.1, P["kneel"], "smooth"], [2.7, P["crouch"], "smooth"],
			[3.4, Rig.over(Body.body("kneel"), M.carry("prime")), "smooth"], [4.0, P["cover"], "smooth"]],
		"events": [[1.7, "pan"], [1.76, "shot"]]}


static func light_run() -> Dictionary:
	var c := Body.gait(SKIRMISH, Rig.over(carry("trail"), {"rot": {B.SPINE: Vector3(-12, 0, 0), B.NECK: Vector3(10, 0, 0)}}))
	c["name"] = "light_run"
	return c


static func light_prone_fire() -> Dictionary:
	var P := light_poses()
	var kick := Rig.over(P["prone_aim"], {"rifle_add": {"dir": Vector3(0, 0.15, 0)}, "add": {B.CHEST: Vector3(6, 0, 0)}})
	return {"name": "light_prone_fire", "len": 2.4,
		"keys": [[0.0, P["prone_aim"]], [0.8, P["prone_aim"]], [0.88, kick, "out"], [1.3, P["prone_aim"], "smooth"],
			[2.4, P["prone_aim"]]],
		"events": [[0.8, "pan"], [0.86, "shot"]]}


# ---------------------------------------------------------------- the gun crew

## Where each man stands at each step of the drill, in the gun's frame: [position, yaw deg].
## The gun points -Z; yaw 90 faces -X, -90 faces +X.
static func crew_place(role: String, step: String, recoil: float) -> Array:
	match role:
		"gunner_sponge":
			if step in ["sponge", "ram"]:
				return [Vector3(0.62, 0, -1.55), 90.0]
			if step == "run_up":
				return [Vector3(1.2, 0, recoil - 0.1), 90.0]
			return [Vector3(1.05, 0, -1.45), 90.0]
		"gunner_load":
			if step == "load":
				return [Vector3(-0.5, 0, -1.48), -80.0]
			if step == "run_up":
				return [Vector3(-1.2, 0, recoil - 0.1), -90.0]
			return [Vector3(-1.05, 0, -1.45), -90.0]
		"gunner_vent":
			if step in ["fire", "recoil", "aim"]:
				return [Vector3(1.25, 0, 0.9), 70.0]
			if step == "run_up":
				return [Vector3(1.2, 0, recoil + 0.45), 90.0]
			return [Vector3(0.52, 0, 0.5), 90.0]
		"gunner_aim":
			if step == "aim":
				return [Vector3(0.05, 0, 3.15), 0.0]
			if step in ["fire", "recoil"]:
				return [Vector3(1.1, 0, 3.4), 20.0]
			return [Vector3(0.0, 0, 2.95 + recoil), 0.0]
		"gunner_fire":
			if step == "fire":
				return [Vector3(-1.0, 0, 0.9), -95.0]
			return [Vector3(-1.25, 0, 1.15), -75.0]
	return [Vector3.ZERO, 0.0]


## A held item in "bone" mode on the root so that the item's own point `local` sits at model point `at_m`, turned so
## the item's -Z runs along `dir` (model space), its +Y toward `up`.
static func item_at(local: Vector3, at_m: Vector3, dir: Vector3, up := Vector3.UP) -> Dictionary:
	var bas := Basis.looking_at(dir.normalized(), up)
	var at := at_m - bas * local + bas * B.GRIP_R
	return {"mode": "bone", "bone": B.ROOT, "at": at, "rot": bas.get_euler() / DEG}


## A gunner's pose at one drill step. `to_model` maps gun-frame points into this man's model space; `gun` is the
## FieldCannon (for its points). Returns a pose spec with model-space hand targets.
static func crew_spec(role: String, step: String, gun: FieldCannon, to_model: Transform3D) -> Dictionary:
	var stand := M.attention()
	var ready := Body.body("ready")
	var gm := func(p: Vector3) -> Vector3: return to_model * p
	var gd := func(d: Vector3) -> Vector3: return to_model.basis * d
	var muzzle: Vector3 = gm.call(gun.muzzle_at())
	var vent: Vector3 = gm.call(gun.vent_at())
	var bore_in: Vector3 = gd.call(-gun.bore_dir())      # from the muzzle down the bore
	var arms_side := {B.UARM_R: Vector3(4, 0, 6), B.FARM_R: Vector3(12, 0, 0), B.UARM_L: Vector3(4, 0, -6), B.FARM_L: Vector3(12, 0, 0)}
	var upright := func(tool_z: float, hand_z: float) -> Dictionary:
		# A staff or linstock grounded by the right foot, upright, the right hand on it.
		return {"rifle": item_at(Vector3(0, 0, tool_z), Vector3(0.27, 0.03, -0.12), Vector3(0.0, 1.0, -0.04), Vector3(0, 0, 1)),
			"hand_r": Vector3(0, 0, hand_z), "pole_r": Vector3(0.6, -0.3, 0.4)}
	match role:
		"gunner_sponge":
			if step == "sponge" or step == "ram":
				# The staff along the bore, the sponge (or, reversed, the rammer) in the barrel; both hands on it, leaning in.
				var spec := Rig.over(ready, {"add": {B.SPINE: Vector3(-12, 0, 0), B.CHEST: Vector3(-6, 0, 0)}})
				if step == "sponge":
					var tip: Vector3 = muzzle + bore_in * 0.45
					spec["rifle"] = item_at(Vector3(0, 0, RB.STAFF_SPONGE_Z - 0.12), tip, bore_in, Vector3.UP)
					spec["hand_r"] = Vector3(0, 0, -0.38)
					spec["hand_l"] = Vector3(0, 0, -0.78)
				else:
					var tip: Vector3 = muzzle + bore_in * 0.95
					spec["rifle"] = item_at(Vector3(0, 0, RB.STAFF_RAM_Z + 0.14), tip, -bore_in, Vector3.UP)
					spec["hand_r"] = Vector3(0, 0, -0.32)
					spec["hand_l"] = Vector3(0, 0, 0.12)
				spec["pole_r"] = Vector3(0.6, -0.6, 0.2)
				spec["pole_l"] = Vector3(-0.5, -0.6, 0.1)
				return spec
			if step == "run_up":
				return Rig.over(Rig.over(Body.body("run"), upright.call(RB.STAFF_RAM_Z + 0.14, 0.15)),
					{"hand_l": [-1, gm.call(gun.wheel_top(1.0)) + Vector3(0, 0, -0.12)], "pole_l": Vector3(-0.5, -0.5, 0.2),
					"add": {B.SPINE: Vector3(-18, 0, 0)}})
			return Rig.over(Rig.over(stand, upright.call(RB.STAFF_RAM_Z + 0.14, 0.2)), {"rot": {B.UARM_L: Vector3(2, 0, -6),
				B.FARM_L: Vector3(10, 0, 0)}})
		"gunner_load":
			if step == "load":
				# Both hands at the muzzle, putting in the round (powder bag and ball, one piece).
				return Rig.over(ready, {"hand_r": [-1, muzzle + Vector3(0.05, 0.02, 0.02)], "pole_r": Vector3(0.6, -0.5, 0.3),
					"hand_l": [-1, muzzle + Vector3(-0.05, 0.03, 0.06)], "pole_l": Vector3(-0.6, -0.5, 0.3),
					"rifle": {"mode": "hand", "rot": Vector3.ZERO}, "add": {B.SPINE: Vector3(-12, 0, 0), B.NECK: Vector3(10, 0, 0)}})
			if step == "sponge":
				# The next round held ready at the waist.
				return Rig.over(stand, {"hand_r": [-1, Vector3(0.08, 1.02, -0.26)], "pole_r": Vector3(0.6, -0.5, 0.3),
					"hand_l": [-1, Vector3(-0.08, 1.04, -0.24)], "pole_l": Vector3(-0.6, -0.5, 0.3), "rifle": {"mode": "hand"}})
			if step == "run_up":
				return Rig.over(Body.body("run"), {"hand_r": [-1, gm.call(gun.wheel_top(-1.0)) + Vector3(0, 0, -0.1)],
					"pole_r": Vector3(0.5, -0.5, 0.2), "hand_l": [-1, gm.call(gun.wheel_top(-1.0)) + Vector3(0, -0.12, -0.25)],
					"pole_l": Vector3(-0.5, -0.5, 0.2), "rifle": {"mode": "hand"}, "add": {B.SPINE: Vector3(-20, 0, 0)}})
			if step in ["fire", "recoil"]:
				return Rig.over(stand, {"rot": arms_side, "rifle": {"mode": "hand"},
					"add": {B.NECK: Vector3(0, 35, 0), B.CHEST: Vector3(0, 12, 0)}})
			return Rig.over(stand, {"rot": arms_side, "rifle": {"mode": "hand"}})
		"gunner_vent":
			if step in ["sponge", "load", "ram"]:
				# "Serve the vent": the left thumb, in its leather stall, stopping the vent.
				return Rig.over(ready, {"hand_l": [-1, vent + Vector3(0, 0.03, 0)], "pole_l": Vector3(-0.4, -0.7, 0.2),
					"rot": {B.UARM_R: Vector3(4, 0, 8), B.FARM_R: Vector3(30, 0, 0)}, "rifle": {"mode": "hand"},
					"add": {B.SPINE: Vector3(-14, 0, 0), B.NECK: Vector3(14, 0, 0)}})
			if step == "prime":
				# The pricker down the vent to pierce the bag, then the priming from the horn.
				return Rig.over(ready, {"hand_r": [-1, vent + Vector3(0.0, 0.05, 0.0)], "pole_r": Vector3(0.6, -0.6, 0.0),
					"hand_l": [-1, vent + Vector3(-0.02, 0.13, 0.06)], "pole_l": Vector3(-0.5, -0.6, 0.2), "rifle": {"mode": "hand"},
					"add": {B.SPINE: Vector3(-16, 0, 0), B.NECK: Vector3(16, 0, 0)}})
			if step == "run_up":
				return Rig.over(Body.body("run"), {"hand_l": [-1, gm.call(gun.wheel_top(1.0)) + Vector3(0, 0, 0.1)],
					"pole_l": Vector3(-0.5, -0.5, 0.2), "hand_r": [-1, gm.call(gun.wheel_top(1.0)) + Vector3(0, -0.1, 0.25)],
					"pole_r": Vector3(0.5, -0.5, 0.2), "rifle": {"mode": "hand"}, "add": {B.SPINE: Vector3(-20, 0, 0)}})
			return Rig.over(stand, {"rot": arms_side, "rifle": {"mode": "hand"}, "add": {B.NECK: Vector3(0, -20, 0)}})
		"gunner_aim":
			if step == "aim":
				# The layer at the trail: the handspike in the trail's ring, levering the trail round; his eye down the gun.
				var ring: Vector3 = gm.call(gun.trail_at() + Vector3(0, 0.05, 0))
				var dir: Vector3 = gd.call(Vector3(0.0, 0.5, 1.0))
				return Rig.over(Body.body("ready"), {"rifle": item_at(Vector3(0, 0, 0.84), ring, dir, Vector3(0, 0, -1)),
					"hand_r": Vector3(0, 0, -0.38), "pole_r": Vector3(0.6, -0.6, 0.2), "hand_l": Vector3(0, 0, -0.08),
					"pole_l": Vector3(-0.6, -0.6, 0.2),
					"add": {B.SPINE: Vector3(-26, 0, 0), B.CHEST: Vector3(-10, 0, 0), B.NECK: Vector3(26, 0, 0)}})
			if step == "run_up":
				var ring: Vector3 = gm.call(gun.trail_at())
				return Rig.over(Body.body("run"), {"hand_r": [-1, ring + Vector3(0.12, 0.08, 0.05)], "pole_r": Vector3(0.6, -0.6, 0.2),
					"hand_l": [-1, ring + Vector3(-0.12, 0.08, 0.05)], "pole_l": Vector3(-0.6, -0.6, 0.2),
					"rifle": item_at(Vector3(0, 0, 0.84), Vector3(-0.25, 0.03, 0.0), Vector3(0, 1, 0), Vector3(0, 0, 1)),
					"add": {B.SPINE: Vector3(-34, 0, 0), B.NECK: Vector3(24, 0, 0)}})
			return Rig.over(stand, {"rifle": item_at(Vector3(0, 0, 0.84), Vector3(0.27, 0.03, -0.1), Vector3(0, 1, -0.04), Vector3(0, 0, 1)),
				"hand_r": Vector3(0, 0, 0.0), "pole_r": Vector3(0.6, -0.3, 0.4)})
		"gunner_fire":
			if step == "fire":
				# At arm's length, the linstock's match to the vent, the body leaning away from the wheel.
				var tip_local := Vector3(0.04, -0.055, RB.LINSTOCK_TIP_Z - 0.01)
				var dir: Vector3 = (vent - Vector3(0.12, 1.3, -0.35)).normalized()
				var spec := Rig.over(ready, {"rifle": item_at(tip_local, vent + Vector3(0, 0.02, 0), dir, Vector3(0, 1, 0)),
					"hand_r": Vector3(0, 0, 0.12), "pole_r": Vector3(0.7, -0.4, 0.2),
					"rot": {B.UARM_L: Vector3(-10, 0, -30), B.FARM_L: Vector3(10, 0, 0)},
					"add": {B.SPINE: Vector3(6, 0, 0), B.CHEST: Vector3(4, 0, 0), B.NECK: Vector3(0, 30, 0)}})
				return spec
			return Rig.over(stand, upright.call(0.3, -0.1))
	return stand


# ---------------------------------------------------------------- the dragoon

## In the saddle: thighs round the horse's barrel, heels down, the left hand on the reins at the saddle's front.
static func ride(sword: String) -> Dictionary:
	var legs := {B.THIGH_R: Vector3(62, 0, 24), B.SHIN_R: Vector3(-74, 0, -14), B.FOOT_R: Vector3(-6, 0, 0),
		B.THIGH_L: Vector3(62, 0, -24), B.SHIN_L: Vector3(-74, 0, 14), B.FOOT_L: Vector3(-6, 0, 0),
		B.SPINE: Vector3(-2, 0, 0), B.CHEST: Vector3(0, 0, 0)}
	var reins := {"hand_l": [-1, Vector3(-0.04, 1.08, -0.36)], "pole_l": Vector3(-0.5, -0.6, 0.2)}
	var spec := {"rot": legs}
	spec.merge(reins, true)
	match sword:
		"carry":
			spec = Rig.over(spec, {"rifle": {"mode": "hand", "rot": Vector3(20, 0, -8)},
				"rot": {B.UARM_R: Vector3(18, 0, 10), B.FARM_R: Vector3(62, 0, 0)}})
		"point":
			# The charge: the sword at arm's length, point forward, the body low over the neck.
			spec = Rig.over(spec, {"rifle": {"mode": "hand", "rot": Vector3(-86, 0, 0)},
				"rot": {B.UARM_R: Vector3(92, 0, 6), B.FARM_R: Vector3(4, 0, 0)},
				"add": {B.SPINE: Vector3(-16, 0, 0), B.CHEST: Vector3(-8, 0, 0), B.NECK: Vector3(18, 0, 0)}})
		"raise":
			spec = Rig.over(spec, {"rifle": {"mode": "hand", "rot": Vector3(-30, 0, 0)},
				"rot": {B.UARM_R: Vector3(168, 0, 28), B.FARM_R: Vector3(55, 0, 0)},
				"add": {B.CHEST: Vector3(4, -14, 0)}})
		"cut":
			spec = Rig.over(spec, {"rifle": {"mode": "hand", "rot": Vector3(-85, 0, 0)},
				"rot": {B.UARM_R: Vector3(55, 0, 30), B.FARM_R: Vector3(6, 0, 0)},
				"add": {B.SPINE: Vector3(-14, 0, 0), B.CHEST: Vector3(-6, 22, 0)}})
	return spec


## The rider's move for each horse step: [horse pose function name, sword].
const MOUNTED := {"walk": "carry", "trot": "carry", "gallop": "carry", "charge": "point"}


# ---------------------------------------------------------------- the library

static func poses(role: String) -> Dictionary:
	match role:
		"grenadier":
			return grenadier_poses()
		"light":
			return light_poses()
		"dragoon":
			var po := M.poses("officer")
			po.merge({"ride": ride("carry"), "ride_point": ride("point"), "ride_raise": ride("raise"), "ride_cut": ride("cut")}, true)
			return po
	if role.begins_with("gunner"):
		return {"stand": gunner_stand(role)}
	return M.poses(role)


## A gunner at ease, his tool upright by his right foot (the loader's hands free).
static func gunner_stand(role: String) -> Dictionary:
	var st := M.attention()
	var tool_z := {"gunner_sponge": RB.STAFF_RAM_Z + 0.14, "gunner_fire": 0.3, "gunner_aim": 0.84}
	if not tool_z.has(role):
		return Rig.over(st, {"rifle": {"mode": "hand"}, "rot": {B.UARM_R: Vector3(4, 0, 6), B.FARM_R: Vector3(12, 0, 0),
			B.UARM_L: Vector3(4, 0, -6), B.FARM_L: Vector3(12, 0, 0)}})
	var hz := {"gunner_sponge": 0.2, "gunner_fire": -0.1, "gunner_aim": 0.0}
	return Rig.over(st, {"rifle": item_at(Vector3(0, 0, tool_z[role]), Vector3(0.27, 0.03, -0.12), Vector3(0.0, 1.0, -0.04),
		Vector3(0, 0, 1)), "hand_r": Vector3(0, 0, hz[role]), "pole_r": Vector3(0.6, -0.3, 0.4)})


static func role_clip(role: String, base: String) -> String:
	if role in ["musketeer", "grenadier", "light"]:
		return base
	if role == "dragoon":
		return "officer_" + base
	if role.begins_with("gunner"):
		return "gunner_" + base
	return "%s_%s" % [role, base]


static func library() -> Dictionary:
	var out := {}
	for c: Dictionary in [grenadier_throw(), light_fire(), light_run(), light_prone_fire()]:
		out[c["name"]] = c
	# The gunners' deaths and get-up (their tools fall with the hand).
	var st := gunner_stand("gunner_load")
	var fall := {"rifle": {"mode": "hand", "rot": Vector3(-80, 0, 0)}, "hand_r": null, "hand_l": null}
	for c: Dictionary in [Body.death_back(st, fall), Body.death_forward(st, fall),
			Body.prone_to_stand(Rig.over(Body.body("prone"), fall), fall, st), Body.hit(st)]:
		c["name"] = "gunner_" + c["name"]
		out[c["name"]] = c
	return out
