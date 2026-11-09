extends RefCounted
## Clips: timed lists of pose specs, played by sampling (Question Chat, 2026-11-09).
## A clip is {name, len, loop, ground, speed, keys: [[time, spec, ease], ...], events}.
## ease is how the move INTO that key runs: "lin", "smooth", "out" (fast start,
## punchy), "in" (speeds up, like falling), "back" (out with a small overshoot).
## Anim.bake turns a clip into a Godot Animation for any skeleton with our bone names.

const B := preload("res://scripts/units/soldier_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")


static func ease_of(u: float, kind: String) -> float:
	match kind:
		"lin":
			return u
		"out":
			return 1.0 - pow(1.0 - u, 3.0)
		"in":
			return u * u
		"back":
			var c := 1.7
			var v := u - 1.0
			return 1.0 + (c + 1.0) * v * v * v + c * v * v
		_:
			return u * u * (3.0 - 2.0 * u)


## Model-space bone transforms of clip at time (grounded when the clip asks and geo is given).
static func sample(clip: Dictionary, time: float, geo: UnitGeo = null) -> Array[Transform3D]:
	var keys: Array = clip["keys"]
	var length: float = clip["len"]
	var t := fposmod(time, length) if clip.get("loop", false) else clampf(time, 0.0, length)
	var i := 0
	while i < keys.size() - 1 and keys[i + 1][0] <= t:
		i += 1
	var g: Array[Transform3D]
	if i >= keys.size() - 1:
		g = Rig.solve(keys[i][1], keys[i][1], 0.0)
	else:
		var t0: float = keys[i][0]
		var t1: float = keys[i + 1][0]
		var u := (t - t0) / maxf(t1 - t0, 1e-5)
		var kind: String = keys[i + 1][2] if keys[i + 1].size() > 2 else "smooth"
		g = Rig.solve(keys[i][1], keys[i + 1][1], ease_of(u, kind))
	if clip.get("ground", true) and geo != null:
		Rig.lift(g, Rig.ground_lift(g, geo))
	return g


## Bakes a clip into an Animation with rotation and position tracks on
## "<skel_path>:<bone>" at fps. Ground contact is baked in from geo.
static func bake(clip: Dictionary, geo: UnitGeo, skel_path := "Skeleton", fps := 30.0) -> Animation:
	var a := Animation.new()
	var length: float = clip["len"]
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if clip.get("loop", false) else Animation.LOOP_NONE
	var n := B.REST.size()
	var rt: Array[int] = []
	var pt: Array[int] = []
	for i in n:
		var r := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(r, NodePath("%s:%s" % [skel_path, B.BONE_NAMES[i]]))
		var p := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(p, NodePath("%s:%s" % [skel_path, B.BONE_NAMES[i]]))
		rt.append(r)
		pt.append(p)
	var frames := int(ceil(length * fps))
	for f in frames + 1:
		var t := minf(float(f) / fps, length)
		var g := sample(clip, t, geo)
		for i in n:
			var par: int = B.BONE_PARENT[i]
			var loc: Transform3D = g[i] if par < 0 else g[par].affine_inverse() * g[i]
			a.rotation_track_insert_key(rt[i], t, loc.basis.get_rotation_quaternion())
			a.position_track_insert_key(pt[i], t, loc.origin)
	return a


## Writes model-space transforms onto a Skeleton3D.
static func apply(skel: Skeleton3D, g: Array[Transform3D]) -> void:
	for i in g.size():
		var par: int = B.BONE_PARENT[i]
		var loc: Transform3D = g[i] if par < 0 else g[par].affine_inverse() * g[i]
		skel.set_bone_pose_position(i, loc.origin)
		skel.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())
