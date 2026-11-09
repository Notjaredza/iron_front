class_name BlastThrow
extends RefCounted
## Explosion round B (Building Chat 1, 2026-11-09): a man caught by a blast. The user's call: "tumble, most get up".
##   inside the kill ring   thrown, tumbling, and stays down (lying on his back or face)
##   inside the throw ring  thrown and tumbling, lands face down, lies stunned a moment, gets up
##   inside the knock ring  knocked flat where he stands, lies a moment, gets up
## The rings come from the blast's crater size, so every size and kind (grenade, mines, shells) has its own.
## The poses are the riflemen's own clips (death_back, death_forward, stand_to_prone, prone_to_stand); the tumble
## is the whole figure turning about its middle. Set by time (step), so videos repeat exactly.

const R := preload("res://scripts/units/anim/clips_rifle.gd")
const Anim := preload("res://scripts/units/anim/anim.gd")
const SB := preload("res://scripts/units/soldier_builder.gd")
const G := 9.81
const MID := 0.9                       # the turning point, about the hips

enum Fate { KILLED, THROWN, KNOCKED }

static var _lib: Dictionary = {}

var man: Soldier
var fate := Fate.THROWN
var t_start := 0.0                     # blast clock time the blast wave reaches him
var end_pose := "aim"
var height: Callable                   # (x, z) -> ground height
var c0 := Vector3.ZERO                 # his middle at the start
var v := Vector3.ZERO
var yaw := 0.0
var axis := Vector3.RIGHT
var turns := 0.0                       # tumble angle over the flight (radians)
var t_fly := 0.0                       # flight time (0: knocked, no flight)
var t_lie := 2.0
var death := "death_back"
var land_p := Vector3.ZERO
var slide := Vector3.ZERO
var facing := true                     # facing the blast: lands on his back (else on his face)
var _anchored := false
var _off := Vector3.ZERO


static func lib() -> Dictionary:
	if _lib.is_empty():
		_lib = R.library()
	return _lib


## Returns the throw for this man, or null if the blast is too far away to move him.
static func make(m: Soldier, spec: Dictionary, at: Vector3, clock: float, rng: RandomNumberGenerator,
		ground: Callable, pose_after: String) -> BlastThrow:
	var cr: float = spec["crater_r"]
	if cr <= 0.0:
		return null
	var rk := cr * 2.0 + 1.0
	var rt := cr * 4.0 + 2.5
	var rn := cr * 7.0 + 4.0
	var to := m.global_position - at
	to.y = 0.0
	var d := to.length()
	if d > rn:
		return null
	var th := BlastThrow.new()
	th.man = m
	th.height = ground
	th.end_pose = pose_after
	th.t_start = clock + d / 340.0 + float(spec.get("t_flash", 0.0)) + 0.02
	var away := to.normalized() if d > 0.01 else Vector3(1, 0, 0)
	# The user's call (2026-11-09): which way he falls depends on which way he faces. Facing the blast (his front
	# half towards it) he goes over backwards and lands on his back; with his back to it he is pitched forwards onto
	# his face. He is squared up to the blast either way (models look down -Z).
	var fwd := -m.global_transform.basis.z
	th.facing = Vector2(fwd.x, fwd.z).dot(Vector2(-away.x, -away.z)) >= 0.0
	th.yaw = atan2(away.x, away.z) if th.facing else atan2(-away.x, -away.z)
	th.death = "death_back" if th.facing else "death_forward"
	th.axis = Vector3.UP.cross(away).normalized()
	th.c0 = m.global_position + Vector3(0, MID, 0)
	th.t_lie = rng.randf_range(1.6, 4.0)
	if d < rt:
		var f := clampf(1.0 - d / rt, 0.0, 1.0)
		th.fate = Fate.KILLED if (d < rk or rng.randf() < 0.2 * f) else Fate.THROWN
		var speed := (3.5 + 11.0 * pow(f, 1.2)) * clampf(sqrt(cr / 1.1), 1.0, 2.4)
		var el := deg_to_rad(rng.randf_range(32.0, 62.0))
		th.v = (away * cos(el) + Vector3(0, sin(el), 0)) * speed
		# Flight time to come back down to the ground (flat ground is near enough for this).
		th.t_fly = maxf(2.0 * th.v.y / G, 0.35)
		th.turns = roundf(th.t_fly * 1.4) * TAU + rng.randf_range(-0.3, 0.3)
		th.slide = Vector3(th.v.x, 0, th.v.z) * 0.12
	else:
		th.fate = Fate.KNOCKED
		th.t_fly = 0.0
	return th


## Moves him to blast-clock time c. Returns false once he is finished (standing again, or lying dead for good).
## After the flight (or the knock): he falls (death_back on his back, death_forward on his face), lies a moment, and
## if he lives gets up with prone_to_stand. A man on his back first rolls over onto his front (the whole figure
## turned about its long axis), then gets up facing the other way. The hips stay put when the clips change.
func step(c: float) -> bool:
	var a := c - t_start
	if a < 0.0:
		return true
	var L := lib()
	var b := Basis(Vector3.UP, yaw)
	var down: Dictionary = L[death]
	if t_fly > 0.0 and a < t_fly:
		# In the air: ballistic, tumbling about his middle, body buckled the way he will land.
		var u := a / t_fly
		var mid := c0 + v * a - Vector3(0, 0.5 * G * a * a, 0)
		var bb := Basis(axis, turns * (1.0 - pow(1.0 - u, 1.6))) * b
		man.global_transform = Transform3D(bb, mid - bb * Vector3(0, MID, 0))
		_show(death, minf(0.3 + a * 0.4, 0.6))
		return true
	var s := a - t_fly                           # time since landing (or since the knock)
	var base := c0 + Vector3(v.x, 0, v.z) * t_fly
	if t_fly > 0.0:
		base += slide * (1.0 - exp(-s * 5.0))
	base.y = height.call(base.x, base.z)
	var dl: float = down["len"]
	var from := 0.55 if t_fly > 0.0 else 0.0
	var sp := 2.2 if t_fly > 0.0 else 1.4
	var t_down := (dl - from) / sp
	if fate == Fate.KILLED or s < t_down + t_lie:
		man.global_transform = Transform3D(b, base)
		_show(death, minf(from + s * sp, dl))
		return not (fate == Fate.KILLED and s > t_down + 3.0)
	var s2 := s - t_down - t_lie
	var lying: Array[Transform3D] = _lying(dl)
	var roll_t := 0.7 if facing else 0.0
	var long_axis := b * Vector3(0, 0, 1)
	if s2 < roll_t:
		var u := smoothstep(0.0, 1.0, s2 / roll_t)
		var hips := Transform3D(b, base) * lying[SB.HIPS].origin
		var R := Basis(long_axis, PI * u)
		var o := hips + R * (base - hips) + Vector3(0, 0.3 * sin(PI * u), 0)
		man.global_transform = Transform3D(R * b, o)
		_show(death, dl)
		return true
	var b2 := Basis(Vector3.UP, yaw + (PI if facing else 0.0))
	var up: Dictionary = L["prone_to_stand"]
	var su := s2 - roll_t
	if not _anchored:
		# Keep the hips where they lay when the get-up clip takes over.
		var lay_b := Basis(long_axis, PI) * b if facing else b
		var before := Transform3D(lay_b, base) * lying[SB.HIPS].origin
		var after := Transform3D(b2, base) * Anim.sample(up, 0.0, man.geo)[SB.HIPS].origin
		_off = Vector3(before.x - after.x, 0, before.z - after.z)
		_anchored = true
	man.global_transform = Transform3D(b2, base + _off)
	if su >= float(up["len"]):
		man.set_pose(end_pose)
		return false
	_show("prone_to_stand", su)
	return true


var _key := ""
var _lie: Array[Transform3D] = []


## Shows a clip at a time, solving the pose only when it changes (30 steps a second at most): a man lying still
## costs nothing, so a field of fallen men is free.
func _show(clip: String, t: float) -> void:
	var key := "%s%d" % [clip, roundi(t * 30.0)]
	if key == _key:
		return
	_key = key
	man.show_globals(Anim.sample(lib()[clip], t, man.geo))


func _lying(dl: float) -> Array[Transform3D]:
	if _lie.is_empty():
		_lie = Anim.sample(lib()[death], dl, man.geo)
	return _lie
