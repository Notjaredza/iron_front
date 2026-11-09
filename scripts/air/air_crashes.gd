class_name AirCrashes
extends RefCounted
## Iron Front air: the baked crash clips (Asset Builder Chat). Made once by tools/air_bake.gd, saved in
## assets/air/crashes.res as one AnimationLibrary. Clips:
## - <type>_spin: hit, smoking then burning, a spinning dive into the ground, broken up on impact;
## - <type>_wing: a wing breaks off (it flutters down on its own), the rest rolls over and falls, breaks up;
## - balloon_burn: the envelope catches fire, folds and falls; the two observers jump and their parachutes open.
## Plane clips key the groups (Fuselage, WingL, WingR, Tail, Gear) relative to the Aircraft root, plus .:rpm,
## .:fire_level and .:crash_time (the impact time). Place the Aircraft root where the plane was flying, facing its
## heading, at the clip's height above the ground (START_H) and play it.

const LIB_PATH := "res://assets/air/crashes.res"
const START_H := 110.0          # planes start this high (origin above the ground)
const BALLOON_H := 80.0         # the balloon basket starts this high
const PLANES := ["fighter", "spotter", "bomber", "transport"]
const KINDS := ["spin", "wing"]


static func names() -> Array[String]:
	var out: Array[String] = []
	for p: String in PLANES:
		for k: String in KINDS:
			out.append(p + "_" + k)
	out.append("balloon_burn")
	return out


static func library() -> AnimationLibrary:
	if ResourceLoader.exists(LIB_PATH):
		return load(LIB_PATH)
	return null


## Adds an AnimationPlayer to a plane or balloon with the crash library loaded. Returns it.
static func player_for(n: Node3D) -> AnimationPlayer:
	var p := AnimationPlayer.new()
	p.name = "CrashPlayer"
	n.add_child(p)
	p.root_node = NodePath("..")
	var lib := library()
	if lib:
		# only this model's own clips, so the player never looks for another model's parts
		var kind := "balloon"
		if n is Aircraft:
			kind = (n as Aircraft).kind
		var own := AnimationLibrary.new()
		for nm in lib.get_animation_list():
			if String(nm).begins_with(kind + "_"):
				own.add_animation(nm, lib.get_animation(nm))
		p.add_animation_library("", own)
	return p
