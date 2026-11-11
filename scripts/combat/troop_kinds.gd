class_name TroopKinds
extends RefCounted
## Iron Front: the kinds of troops a Squad can be (fighting round), ours and the enemy's, each with its own men,
## moves and way of fighting. Every kind uses the approved models and clips as they are (read only):
##   rifles      our 12-man rifle squad: bolt rifles at range, bayonets up close; goes prone when pinned
##   engineers   our 4-man section: builds; no firing, bayonets up close; kneels when pinned
##   redcoats    a company of musketeers with an officer, drummer and ensign: halts to fire volleys, the long
##               reload, then the bayonet charge; kneels when pinned
##   medieval    the host's foot (men-at-arms, spears, heavies, levy, a banner): marches up, runs in, hand to hand
##   archers     the host's longbows and crossbows: halt at long range and shoot; never pinned
##   zombies     a horde (sub-kind shambler, runner or brute): straight at the nearest men; hand to hand only;
##               take two hits (the brute four); never pinned
## For each man there is a map from what he is doing to the clip in the kind's library:
##   walk, run, ready, fire, reload, fire_pinned, reload_pinned, pin_to, pinned, melee, hit, death (a list).
## Missing entries mean the man does not do that (a drummer does not fire).

const R := preload("res://scripts/units/anim/clips_rifle.gd")
const E := preload("res://scripts/units/anim/clips_engineer.gd")
const F := preload("res://scripts/units/anim/clips_fight.gd")
const M := preload("res://scripts/units/anim/clips_musket.gd")
const M2 := preload("res://scripts/units/anim/clips_redcoat2.gd")
const MC := preload("res://scripts/units/anim/clips_medieval.gd")
const Z := preload("res://scripts/units/anim/clips_zombie.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const Anim := preload("res://scripts/units/anim/anim.gd")

## range: metres (0 for no firing). acc: chance a shot hits a standing man in the open at close range.
## reload_every: shots before the reload clip. melee: chance a blow kills. hp: hits to kill a man.
## reach: how far (metres) a man goes for an enemy in hand to hand. pin: what happens when pinned ("" never).
## wait: extra seconds [least, most] a man takes between shots (aiming, picking a man): WW1 aimed rifle fire is a
## round every 4-6 s, not as fast as the bolt can be worked.
const SPEC := {
	"rifles": {"range": 150.0, "acc": 0.14, "wait": [2.0, 4.0], "reload_every": 5, "melee": 0.35, "hp": 1, "reach": 8.0, "pin": "prone",
		"supp": 0.07, "side": 0},
	"engineers": {"range": 0.0, "acc": 0.0, "wait": [0.0, 0.0], "reload_every": 1, "melee": 0.2, "hp": 1, "reach": 6.0, "pin": "kneel",
		"supp": 0.0, "side": 0},
	"redcoats": {"range": 90.0, "acc": 0.16, "wait": [0.1, 0.6], "reload_every": 1, "melee": 0.3, "hp": 1, "reach": 10.0, "pin": "kneel",
		"supp": 0.09, "side": 1},
	"medieval": {"range": 0.0, "acc": 0.0, "wait": [0.0, 0.0], "reload_every": 1, "melee": 0.4, "hp": 1, "reach": 14.0, "pin": "",
		"supp": 0.0, "side": 1},
	"archers": {"range": 120.0, "acc": 0.1, "wait": [0.8, 2.0], "reload_every": 1, "melee": 0.15, "hp": 1, "reach": 5.0, "pin": "",
		"supp": 0.06, "side": 1},
	"zombies": {"range": 0.0, "acc": 0.0, "wait": [0.0, 0.0], "reload_every": 1, "melee": 0.3, "hp": 2, "reach": 14.0, "pin": "",
		"supp": 0.0, "side": 1},
}

static var _libs := {}                         # kind -> AnimationLibrary
static var _clips := {}                        # kind -> {anim name: clip dictionary}


## The roles of the n men of a squad of this kind (sub: the zombie sub-kind).
static func roles(kind: String, n: int, sub := "") -> Array[String]:
	var out: Array[String] = []
	for i in n:
		match kind:
			"rifles":
				out.append("")
			"engineers":
				out.append("nco" if i == 0 else "sapper")
			"redcoats":
				out.append(["officer", "drummer", "ensign"][i] if i < 3 else "musketeer")
			"medieval":
				out.append(["captain", "banner"][i] if i < 2 else ["man_at_arms", "spearman", "spearman", "heavy", "levy", "levy"][i % 6])
			"archers":
				out.append("longbow" if i % 3 != 2 else "crossbow")
			"zombies":
				out.append(sub if not sub.is_empty() else "shambler")
	return out


static func make_man(kind: String, seed_value: int, role: String, lod := 1, lord := -1) -> Soldier:
	match kind:
		"engineers":
			return Engineer.new().setup(seed_value, lod, role)
		"redcoats":
			return Redcoat.new().setup(seed_value, lod, role)
		"medieval", "archers":
			var m := Medieval.new()
			m.lord = lord
			return m.setup(seed_value, lod, role)
		"zombies":
			return Zombie.new().setup(seed_value, lod, role)
	return Soldier.new().setup(seed_value, lod, role)


## The man's own clip names for each thing he does.
static func clip_map(kind: String, man: Soldier) -> Dictionary:
	match kind:
		"rifles":
			return {"walk": "walk", "run": "run", "ready": "ready", "fire": "fire_stand", "reload": "reload_stand",
				"fire_pinned": "fire_prone", "reload_pinned": "reload_prone", "pin_to": "stand_to_prone", "pinned": "prone",
				"melee": "lunge", "hit": "hit", "death": ["death_back", "death_forward"]}
		"engineers":
			return {"walk": "walk", "run": "run", "ready": "ready", "pinned": "eng_hold_kneel", "melee": "lunge",
				"hit": "eng_hit", "death": ["eng_death_back", "eng_death_forward"]}
		"redcoats":
			var role: String = (man as Redcoat).role
			var n := func(b: String) -> String: return M2.role_clip(role, b)
			match role:
				"officer":
					return {"walk": "officer_march", "run": "officer_charge", "ready": "officer_stand", "pinned": "officer_stand",
						"hit": "officer_hit", "death": ["officer_death_back", "officer_death_forward"]}
				"drummer":
					return {"walk": "drummer_march", "run": "drummer_march", "ready": "drummer_hold", "pinned": "drummer_hold",
						"hit": "drummer_hit", "death": ["drummer_death_back", "drummer_death_forward"]}
				"ensign":
					return {"walk": "ensign_march", "run": "ensign_charge", "ready": "ensign_hold", "pinned": "ensign_hold",
						"hit": "ensign_hit", "death": ["ensign_death_back", "ensign_death_forward"]}
			return {"walk": "march", "run": "charge_run", "ready": "hold_ready", "fire": "volley_stand", "reload": "reload",
				"fire_pinned": "volley_kneel", "reload_pinned": "reload", "pinned": "hold_kneel", "melee": "thrust",
				"hit": n.call("hit"), "death": [n.call("death_back"), n.call("death_forward")]}
		"medieval", "archers":
			var k: String = (man as Medieval).kit
			var m := {"walk": k + "_march", "run": k + "_run", "ready": k + "_hold_guard", "hit": k + "_hit",
				"death": [k + "_death_back", k + "_death_forward"]}
			match k:
				"sword":
					m["melee"] = "sword_strike"
				"spear":
					m["melee"] = "spear_thrust"
				"great":
					m["melee"] = "great_strike"
				"pole":
					m["melee"] = "pole_strike"
				"levy":
					m["melee"] = "levy_strike"
				"bow":
					m["fire"] = "bow_shot"
				"xbow":
					m["fire"] = "xbow_shoot"
					m["reload"] = "xbow_reload"
				"banner":
					m["ready"] = "banner_wave"
			return m
		"zombies":
			var zk: String = (man as Zombie).kind
			return {"walk": "z_%s_walk" % zk, "run": "z_%s_run" % zk, "ready": "z_%s_ready" % zk, "melee": "z_%s_melee" % zk,
				"hit": "z_%s_hit" % zk, "death": ["z_%s_death" % zk]}
	return {}


## The clip dictionaries of a kind (for its library, clip lengths, shot moments and the props a clip shows).
static func clips(kind: String) -> Dictionary:
	if _clips.has(kind):
		return _clips[kind]
	var out := {}
	match kind:
		"rifles":
			out = R.library().duplicate()
			out["ready"] = _hold("ready", R.poses()["ready"])
			out["prone"] = _hold("prone", R.poses()["prone"])
			out["lunge"] = _lunge()
		"engineers":
			var el := E.library()
			out = el.duplicate()
			var run := Body.gait(Body.RUN, E.carry("shovel"))
			run["props"] = {"hand": [[0.0, "shovel"]]}
			out["walk"] = el["eng_walk"]
			out["run"] = run
			out["ready"] = el["eng_hold_stand"]
			out["lunge"] = _lunge()
		"redcoats":
			out = M.library().duplicate()
		"medieval", "archers":
			out = MC.library().duplicate()
		"zombies":
			for zk: String in ["shambler", "runner", "brute"]:
				var st := Z.stand(zk)
				var walk := Z.gait_of(zk, "walk")
				var run := Z.gait_of(zk, "charge" if zk == "brute" else "")
				out["z_%s_walk" % zk] = walk
				out["z_%s_run" % zk] = run
				out["z_%s_ready" % zk] = _hold("z_%s_ready" % zk, st)
				out["z_%s_melee" % zk] = {"runner": Z.claw_swipe(), "brute": Z.smash()}.get(zk, Z.grab_bite())
				out["z_%s_hit" % zk] = Z.stumble(st)
				out["z_%s_death" % zk] = Z.brute_down(st) if zk == "brute" else Z.drop(st)
	_clips[kind] = out
	return out


## The baked library of a kind (only the clips its men use), shared by every squad of that kind.
static func library(kind: String, geo: UnitGeo) -> AnimationLibrary:
	if _libs.has(kind):
		return _libs[kind]
	var cl := clips(kind)
	var want := {}
	match kind:
		"rifles":
			for nm in ["walk", "run", "ready", "prone", "fire_stand", "fire_prone", "reload_stand", "reload_prone",
					"stand_to_prone", "lunge", "hit", "death_back", "death_forward"]:
				want[nm] = true
		"engineers":
			for nm in ["walk", "run", "ready", "eng_hold_kneel", "lunge", "eng_hit", "eng_death_back", "eng_death_forward"] + Squad.WORK_CLIPS:
				want[nm] = true
		"redcoats":
			for role: String in ["musketeer", "officer", "drummer", "ensign"]:
				for v in _role_names(kind, role):
					want[v] = true
		"medieval", "archers":
			for k: String in ["sword", "spear", "great", "pole", "levy", "bow", "xbow", "banner"]:
				for b in ["march", "run", "hold_guard", "hit", "death_back", "death_forward", "strike", "thrust", "shot",
						"shoot", "reload", "wave"]:
					var nm: String = k + "_" + b
					if cl.has(nm):
						want[nm] = true
		"zombies":
			for nm: String in cl:
				want[nm] = true
	var al := AnimationLibrary.new()
	for nm: String in want:
		if cl.has(nm):
			al.add_animation(nm, Anim.bake(cl[nm], geo))
	_libs[kind] = al
	return al


static func _role_names(kind: String, role: String) -> Array:
	var out := []
	if kind == "redcoats":
		var fake := Redcoat.new()
		fake.role = role
		var m := clip_map(kind, fake)
		fake.free()
		for k: String in m:
			if m[k] is Array:
				out.append_array(m[k])
			else:
				out.append(m[k])
	return out


static func _hold(nm: String, pose: Dictionary) -> Dictionary:
	return {"name": nm, "len": 1.0, "loop": true, "keys": [[0.0, pose], [1.0, pose]]}


## The bayonet thrust for our men (the fight poses, as the fight pictures use them).
static func _lunge() -> Dictionary:
	return {"name": "lunge", "len": 1.0, "keys": [[0.0, F.guard(false)], [0.3, F.lunge(false), "out"], [0.5, F.lunge(false)],
		[1.0, F.guard(false), "smooth"]], "events": [[0.35, "strike"]]}


## When in a clip the shot (or blow) lands: its "shot", "strike" or "thrust" event, or part way through.
static func hit_time(clip: Dictionary) -> float:
	for e: Array in clip.get("events", []):
		if e[1] in ["shot", "strike", "thrust"]:
			return float(e[0])
	return float(clip["len"]) * 0.5


## Walking speed (m/s) of a clip, as it was made.
static func speed_of(clip: Dictionary, fallback: float) -> float:
	return float(clip.get("speed", fallback))
