class_name Para
extends Node3D
## Iron Front: one paratrooper (Asset Builder Chat). The approved rifleman (scripts/units Soldier, read only)
## wearing a harness, a pack on his back and a reserve on his chest, under a Canopy.
## Node layout: Para (origin at his feet) -> Swing (pivot at the confluence, swings him) -> Man (the Soldier),
## Risers; Canopy rides at the confluence and does not swing.
##
## Before the jump the caller poses him (pose_spec / show_clip) and places the node. jump(vel, ...) hands him
## to step(dt), which flies the exit, the opening, the descent, the landing, the roll, gathering the chute and
## standing up with the rifle ready. Fates: "ok", "streamer" (the chute never opens properly), "burn"
## (opens, then burns), "hit" (shot while hanging: goes limp).

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const V := preload("res://scripts/units/anim/clips_vehicle.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")

const CONF := 2.55               # confluence height above his feet
const OPEN_AT := 0.9             # static line pulls the chute out this long after the exit
const OPEN_TIME := 0.75
const SINK := 5.4                # descent rate under a good canopy
const SLUNG := {"mode": "back"}

var man: Soldier
var swing_node: Node3D
var canopy: Canopy
var risers: MeshInstance3D
var bundle: MeshInstance3D
var state := "aboard"            # aboard, exit, chute, land, ready, dead
var fate := "ok"
var t := 0.0                     # time since the jump
var vel := Vector3.ZERO
var heading := 0.0               # he turns to face downwind (+X drift turns him)
var ground_y := 0.0
var open := 0.0
var burn := 0.0
var limp := 0.0
var hit_at := -1.0
var burn_at := -1.0
var land_t := -1.0
var swing := Vector2.ZERO        # swing angles (about X, about Z)
var swing_v := Vector2.ZERO
var wind := Vector3(1.2, 0, 0.4)
var _walk: Dictionary = {}


static func make(seed_value: int) -> Para:
	var p := Para.new()
	p.name = "Para%d" % seed_value
	p._build(seed_value)
	return p


func _build(seed_value: int) -> void:
	swing_node = Node3D.new()
	swing_node.name = "Swing"
	swing_node.position = Vector3(0, CONF, 0)
	add_child(swing_node)
	man = Soldier.new().setup(seed_value)
	man.name = "Man"
	man.position = Vector3(0, -CONF, 0)
	swing_node.add_child(man)
	var m := AirParts.material()
	# the kit: pack on his back, reserve on his chest, harness straps
	var kit := Node3D.new()
	var g := TrainGeo.new()
	var webbing := Color(0.55, 0.50, 0.36)
	g.box(Vector3(0, 0.02, 0.2), Vector3(0.16, 0.2, 0.07), Color(0.38, 0.38, 0.28), Basis(), 0.03)      # main pack
	g.box(Vector3(0, -0.1, -0.17), Vector3(0.13, 0.09, 0.05), Color(0.34, 0.35, 0.26), Basis(), 0.02)   # reserve
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(sx * 0.09, 0.08, -0.13), Vector3(0.025, 0.2, 0.01), webbing)                         # straps
		g.box(Vector3(sx * 0.09, 0.08, 0.14), Vector3(0.025, 0.2, 0.01), webbing)
	g.box(Vector3(0, -0.22, 0), Vector3(0.19, 0.03, 0.15), webbing)                                       # belly band
	g.make(kit, "Kit", m)
	man.attach(B.CHEST, kit, Transform3D())
	# risers from his shoulders up to the confluence
	var rg := TrainGeo.new()
	for sx: float in [-1.0, 1.0]:
		rg.cyl(Vector3(sx * 0.17, -CONF + 1.5, 0.02), Vector3(sx * 0.05, 0.0, 0), 0.012, 3, webbing)
	risers = rg.make(swing_node, "Risers", m)
	risers.visible = false
	canopy = Canopy.make(Color(0.86, 0.84, 0.76), 3.2)
	canopy.position = Vector3(0, CONF, 0)
	add_child(canopy)
	canopy.visible = false
	var bg := TrainGeo.new()
	bg.lump(Vector3.ZERO, 0.35, Color(0.80, 0.78, 0.70), Vector3(1.4, 0.5, 1.0))
	bundle = bg.make(self, "Bundle", m)
	bundle.visible = false


# ------------------------------------------------------------------ poses

func _stand() -> Dictionary:
	return Rig.over(Body.body("stand"), {"rifle": SLUNG, "hand_r": null, "hand_l": null})


static func hang(pull := 0.0) -> Dictionary:
	# both hands up on the risers, legs together and a little bent, looking down for the ground
	return {"rifle": SLUNG,
		"rot": {B.THIGH_R: Vector3(12 + pull * 10, 0, 2), B.THIGH_L: Vector3(14 + pull * 10, 0, -2), B.SHIN_R: Vector3(-18, 0, 0),
			B.SHIN_L: Vector3(-20, 0, 0), B.FOOT_R: Vector3(18, 0, 0), B.FOOT_L: Vector3(18, 0, 0),
			B.SPINE: Vector3(-2, 0, 0), B.NECK: Vector3(18, 0, 0), B.HEAD: Vector3(10, 0, 0)},
		"hand_r": [-1, Vector3(0.12, 1.98 - pull * 0.2, 0.0)], "hand_l": [-1, Vector3(-0.12, 1.98 - pull * 0.2, 0.0)],
		"pole_r": Vector3(1, 0, 0.2), "pole_l": Vector3(-1, 0, 0.2)}


static func limp_hang() -> Dictionary:
	return {"rifle": SLUNG,
		"rot": {B.THIGH_R: Vector3(4, 0, 4), B.THIGH_L: Vector3(-2, 0, -2), B.SHIN_R: Vector3(-10, 0, 0),
			B.SHIN_L: Vector3(-4, 0, 0), B.FOOT_R: Vector3(30, 0, 0), B.FOOT_L: Vector3(30, 0, 0),
			B.SPINE: Vector3(8, 0, 4), B.CHEST: Vector3(6, 0, 0), B.NECK: Vector3(45, 0, 10), B.HEAD: Vector3(20, 0, 8),
			B.UARM_R: Vector3(10, 0, 12), B.FARM_R: Vector3(10, 0, 0), B.UARM_L: Vector3(14, 0, -6), B.FARM_L: Vector3(16, 0, 0)},
		"hand_r": null, "hand_l": null}


static func roll_side() -> Dictionary:
	return Rig.over(V.crouch(0.3), {"root_rot": Vector3(-20, 0, 85), "root_pos": Vector3(0.45, 0, 0)})


static func on_back() -> Dictionary:
	return Rig.over(V.airborne(), {"root_rot": Vector3(70, 0, 20), "root_pos": Vector3(0, 0, -0.5)})


static func crumpled() -> Dictionary:
	return Rig.over(Body.body("prone"), {"rifle": SLUNG, "hand_r": null, "hand_l": null,
		"add": {B.NECK: Vector3(-30, 25, 0), B.HEAD: Vector3(-15, 10, 20)},
		"rot": {B.UARM_R: Vector3(-30, 0, 70), B.FARM_R: Vector3(20, 0, 0), B.UARM_L: Vector3(10, 0, -40), B.FARM_L: Vector3(40, 0, 0),
			B.THIGH_R: Vector3(-5, 0, 18), B.THIGH_L: Vector3(30, 0, -6), B.SHIN_L: Vector3(-60, 0, 0)}})


static func gather(reach: float) -> Dictionary:
	return Rig.over(V.stooped(), {"rot": {B.UARM_R: Vector3(-50 - reach * 30, 0, 12), B.FARM_R: Vector3(30, 0, 0),
		B.UARM_L: Vector3(-50 - reach * 30, 0, -12), B.FARM_L: Vector3(30, 0, 0)},
		"add": {B.SPINE: Vector3(-10 * reach, 0, 0)}})


## Poses him on the ground or in the plane from a spec (blend a->b at u).
func pose_blend(a: Dictionary, b: Dictionary, u: float, on_ground := true) -> void:
	man.pose_blend_world(a, b, clampf(u, 0.0, 1.0), {}, {}, on_ground)


## Walking (rifle slung) at a phase time.
func walk_pose(time: float) -> void:
	if _walk.is_empty():
		_walk = Body.gait(Body.WALK, {"rifle": SLUNG, "hand_r": null, "hand_l": null})
	man.show_clip(_walk, fmod(time, float(_walk.get("len", 1.0))))


# ------------------------------------------------------------------ the jump

## Out of the door: starting velocity (the plane's), heading he faces, the fate, when he is hit or his chute
## burns (seconds after the jump, -1 none).
func jump(v: Vector3, face: float, fate_name := "ok", hit_time := -1.0, burn_time := -1.0) -> void:
	state = "exit"
	t = 0.0
	vel = v
	heading = face
	fate = fate_name
	hit_at = hit_time
	burn_at = burn_time
	rotation = Vector3(0, heading, 0)
	man.position = Vector3(0, -CONF, 0)


func step(dt: float) -> void:
	if state == "aboard" or state == "ready" or state == "dead_done":
		return
	t += dt
	match state:
		"exit":
			# the slipstream takes the forward speed off; he falls tucked, tipping forward
			var h := Vector3(vel.x, 0, vel.z)
			h = h.move_toward(wind, 22.0 * dt)
			vel = Vector3(h.x, vel.y - 9.81 * dt, h.z)
			position += vel * dt
			var tip := lerpf(0.0, -0.9, clampf(t / OPEN_AT, 0.0, 1.0))
			swing_node.rotation = Vector3(tip, 0, 0)
			man.pose_blend_world(V.airborne(), V.airborne(), 0.0, {}, {}, false)
			if t >= OPEN_AT:
				state = "chute"
				canopy.visible = true
				risers.visible = true
				swing = Vector2(tip, 0.15)
		"chute":
			_chute(dt)
		"land":
			_land(dt)
		"dead":
			_dead(dt)


func _chute(dt: float) -> void:
	var since := t - OPEN_AT
	var target_open := 1.0
	if fate == "streamer":
		target_open = 0.12 + sin(t * 9.0) * 0.04
	open = move_toward(open, target_open, dt / OPEN_TIME)
	if burn_at >= 0.0 and t >= burn_at:
		burn = minf(1.0, burn + dt / 4.0)
	# drag: a full canopy holds him at SINK m/s; a streamer barely slows him; a burning one less and less
	var cd := lerpf(0.012, 9.81 / (SINK * SINK), open * open) * (1.0 - burn * 0.82)
	var rel := vel - wind
	rel -= rel * rel.length() * cd * dt
	rel.y -= 9.81 * dt
	vel = rel + wind
	position += vel * dt
	# the opening shock starts a swing that dies away
	var k := 2.6
	swing_v += (-swing * k * k - swing_v * 0.35) * dt
	swing += swing_v * dt
	if hit_at >= 0.0 and t >= hit_at:
		limp = minf(1.0, limp + dt * 3.0)
	swing_node.rotation = Vector3(swing.x, 0, swing.y)
	var pull := 0.5 + 0.5 * sin(t * 0.9) if limp <= 0.0 else 0.0
	if limp > 0.0:
		man.pose_blend_world(hang(0.0), limp_hang(), limp, {}, {}, false)
		risers.visible = true
	else:
		man.pose_blend_world(hang(0.0), hang(1.0), pull * 0.4, {}, {}, false)
	canopy.shape(open, 0.0, 0.0, burn)
	canopy.rotation.y = sin(t * 0.4) * 0.3
	# he turns slowly to face the drift for the landing
	if position.y <= ground_y:
		position.y = ground_y
		land_t = t
		swing_node.rotation = Vector3.ZERO
		var hard := vel.y < -8.0 or limp > 0.0
		vel = Vector3.ZERO
		state = "dead" if hard else "land"
		risers.visible = false


func _land(dt: float) -> void:
	var s := t - land_t
	# crouch on touch-down, roll onto the side, up to a kneel, gather the chute, stand ready
	var ready: Dictionary = R.poses()["ready"]
	var kneel := Rig.over(Body.body("kneel"), {"rifle": SLUNG, "hand_r": null, "hand_l": null})
	if s < 0.15:
		man.pose_blend_world(V.crouch(0.2), V.crouch(0.2), 0.0)
	elif s < 0.55:
		man.pose_blend_world(V.crouch(0.2), roll_side(), (s - 0.15) / 0.4)
	elif s < 1.0:
		man.pose_blend_world(roll_side(), on_back(), (s - 0.55) / 0.45)
	elif s < 1.9:
		man.pose_blend_world(on_back(), kneel, smoothstep(1.0, 1.9, s))
	elif s < 2.3:
		man.pose_blend_world(kneel, gather(0.0), (s - 1.9) / 0.4)
	elif s < 3.8:
		man.pose_blend_world(gather(0.0), gather(1.0), 0.5 + 0.5 * sin((s - 2.3) * 6.0))
	elif s < 4.6:
		man.pose_blend_world(gather(0.0), ready, smoothstep(3.8, 4.6, s))
	else:
		man.pose_blend_world(ready, ready, 0.0)
		state = "ready"
	# the canopy lies down downwind and is pulled in to a bundle
	var c := smoothstep(0.0, 1.6, s)
	var gth := smoothstep(2.3, 3.8, s)
	canopy.rotation.y = 0.0
	_lay_canopy(c, gth)


func _dead(dt: float) -> void:
	var s := t - land_t
	man.pose_blend_world(V.crouch(0.0) if limp <= 0.0 else limp_hang(), crumpled(), smoothstep(0.0, 0.4, s))
	_lay_canopy(smoothstep(0.0, 2.0, s), 0.0)
	if s > 2.5:
		state = "dead_done"


func _lay_canopy(c: float, gth: float) -> void:
	# the canopy drifts downwind of him and settles; gathering pulls it to his feet as a bundle
	var down := Basis(Vector3.UP, -rotation.y) * wind.normalized()
	var face := atan2(-down.x, -down.z)
	canopy.rotation = Vector3(0, face, 0)
	canopy.position = Vector3(0, CONF * (1.0 - c) + 0.05, 0) + down * (c * 0.5 * (1.0 - gth))
	canopy.shape(open, c, gth, burn)
	if gth >= 0.98:
		canopy.visible = false
		bundle.visible = true
		bundle.position = Vector3(0.9, 0.15, 0.7)


func _ready() -> void:
	if state == "aboard":
		man.pose_spec_world(_stand())
