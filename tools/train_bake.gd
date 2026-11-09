extends SceneTree
## Iron Front trains: works out the crashes with the physics engine once and bakes them into Animations
## (Asset Builder Chat). Run headless at a fixed 120 frames a second (one physics step a frame):
##   Godot --headless --path iron_front --fixed-fps 120 -s res://tools/train_bake.gd [-- tip_5 ...]
## Writes assets/trains/crashes.res: an AnimationLibrary with crash_<kind>_<n> for kinds tip, track, block, blast
## and n = 3, 4, 5. Also: -- check plays every clip back through an AnimationPlayer and compares it with the bake.

const HZ := 120
const KEY_EVERY := 4             # one key every 4 physics steps = 30 keys a second
const MAX_AFTER := 9.0           # longest a crash may run after it starts

var only: Array[String] = []
var check := false
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "check":
			check = true
		else:
			only.append(a)
	Engine.physics_ticks_per_second = HZ
	_run.call_deferred()


func _run() -> void:
	if check:
		await _check()
		quit()
		return
	var lib: AnimationLibrary
	if ResourceLoader.exists(TrainCrashes.LIB_PATH) and not only.is_empty():
		lib = load(TrainCrashes.LIB_PATH)
	else:
		lib = AnimationLibrary.new()
	for kind in TrainCrashes.KINDS:
		for n in [3, 4, 5]:
			var nm := "%s_%d" % [kind, n]
			if not only.is_empty() and not only.has(nm):
				continue
			var anim := await _bake(kind, n)
			if lib.has_animation(nm):
				lib.remove_animation(nm)
			lib.add_animation(nm, anim)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/trains"))
	var err := ResourceSaver.save(lib, TrainCrashes.LIB_PATH, ResourceSaver.FLAG_COMPRESS)
	print("TRAIN BAKE saved %s err=%d clips=%d" % [TrainCrashes.LIB_PATH, err, lib.get_animation_list().size()])
	print("TRAIN BAKE DONE")
	quit()


# ------------------------------------------------------------------ one crash

class Rec:
	var path: String             # node path relative to the Train
	var node: Node3D
	var local_to: Node3D         # keys are this node's transform relative to local_to
	var pos: Array[Vector3] = []
	var rot: Array[Quaternion] = []
	var scl: Array[Vector3] = []
	var keyed_scale := false


func _bake(kind: String, n: int) -> Animation:
	rng.seed = hash(kind) + n * 101
	var stage := Node3D.new()
	root.add_child(stage)
	var t := TrainCrashes.stage_for(kind, n, stage)
	t.target_speed = TrainCrashes.SPEED
	for i in t.v.size():
		t.v[i] = TrainCrashes.SPEED
	# steady running: stretch the couplings to their pulled length first
	for i in range(1, t.cars.size()):
		t.d[i] = t.d[i - 1] - t.cars[i - 1].rear_z + t.cars[i].front_z - 0.17
	t.place()
	var recs: Array[Rec] = []
	for i in t.cars.size():
		recs.append(_rec("Car%d" % i, t.cars[i], t))
	var eng := t.cars[0]
	var pieces: Array[Node3D] = []
	if kind == "blast":
		for p in eng.body.get_children():
			pieces.append(p)
		for w in eng.wheels:
			pieces.append(w)
		for s: int in eng.rods:
			for k: String in ["coupling", "conn", "cross", "piston"]:
				pieces.append(eng.rods[s][k])
		for b in eng.buffers.slice(0, 2):
			pieces.append(b)
		for p in pieces:
			recs.append(_rec(String(t.get_path_to(p)), p, eng))
	if kind == "block":
		for nm: String in ["Body/FrontBeam", "Body/Smokebox", "Body/Chimney", "Body/Cylinders", "BufferFL", "BufferFR"]:
			var p: Node3D = eng.get_node(nm)
			var r := _rec("Car0/" + nm, p, eng)
			r.keyed_scale = true
			recs.append(r)
	var fire_keys: Array[Vector2] = [Vector2(0, 0)]

	# run in on the rails
	var step := 0
	var run_steps := int(TrainCrashes.RUN_IN * HZ)
	while step < run_steps:
		await process_frame
		step += 1
		if step % KEY_EVERY == 0:
			_key_all(recs)
	t.set_process(false)

	# leave the rails: every car becomes a rigid body
	var bodies: Array[RigidBody3D] = []
	var piece_bodies := {}
	for i in t.cars.size():
		var c := t.cars[i]
		var xf := c.global_transform
		var fwd := -xf.basis.z
		var b := _body(stage, xf, c.col_box, c.mass, c.com_y)
		b.linear_velocity = fwd * TrainCrashes.SPEED
		if kind == "tip":
			# on the curve the cars are turning: keep the turn rate, and the outward roll begins
			b.angular_velocity = Vector3(0, TrainCrashes.SPEED / TrainCrashes.CURVE_R, 0)
		bodies.append(b)
	for i in range(1, bodies.size()):
		var a := t.cars[i - 1].to_global(t.cars[i - 1].hook_rear())
		var bpt := t.cars[i].to_global(t.cars[i].hook_front())
		_pin(stage, bodies[i - 1], bodies[i], (a + bpt) * 0.5)
	var joints := stage.find_children("Pin*", "PinJoint3D", false, false)
	match kind:
		"tip":
			for i in bodies.size():
				var b := bodies[i]
				var c := t.cars[i]
				var fwd := -c.global_basis.z
				var out := c.global_basis.x
				b.linear_velocity += out * 1.5 / (1.0 + float(i) * 0.4)
				if i > 0:
					b.angular_velocity += Vector3(0, 0.6 if i % 2 else -0.45, 0)
		"track":
			bodies[0].angular_velocity += Vector3(0, 0.3, 0)
			bodies[0].angular_velocity += t.cars[0].global_basis.x * -0.7
			for i in range(1, bodies.size()):
				bodies[i].linear_velocity += t.cars[i].global_basis.x * (1.0 if i % 2 else -0.9)
				bodies[i].angular_velocity += Vector3(0, 0.3 if i % 2 else -0.35, 0)
		"block":
			for i in range(1, bodies.size()):
				bodies[i].linear_velocity += t.cars[i].global_basis.x * (1.3 if i % 2 else -1.2)
				bodies[i].angular_velocity += Vector3(0, 0.35 if i % 2 else -0.4, 0)
			if bodies.size() > 1:
				# the tender rides up over the engine's back
				bodies[1].linear_velocity += Vector3(0, 2.2, 0)
				bodies[1].angular_velocity += t.cars[1].global_basis.x * 0.9
		"blast":
			var centre := eng.to_global(eng.marks["blast"])
			var frame_b := bodies[0]
			frame_b.linear_velocity = -eng.global_basis.z * TrainCrashes.SPEED * 0.75 + Vector3(0, 3.5, 0)
			frame_b.angular_velocity = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.8, 0.8), rng.randf_range(-1.2, 1.2))
			frame_b.mass = 26000.0
			var shp: CollisionShape3D = frame_b.get_child(0)
			(shp.shape as BoxShape3D).size = Vector3(2.4, 1.6, 9.0)
			shp.position = Vector3(0, 0.8, -0.2)
			for p in pieces:
				var mi := p.get_node_or_null("Mesh") as MeshInstance3D
				if p is MeshInstance3D:
					mi = p
				var box := mi.mesh.get_aabb() if mi and mi.mesh else AABB(Vector3(-0.2, -0.2, -0.2), Vector3(0.4, 0.4, 0.4))
				if p is MeshInstance3D:
					pass
				var m := clampf(box.size.x * box.size.y * box.size.z * 900.0, 150.0, 9000.0)
				var pb := _body(stage, p.global_transform, box, m, -999.0)
				var at := p.global_transform * box.get_center()
				var dir := (at - centre)
				dir.y = absf(dir.y) + 0.6
				dir = dir.normalized()
				var push := rng.randf_range(9.0, 20.0)
				pb.linear_velocity = -eng.global_basis.z * TrainCrashes.SPEED * 0.6 + dir * push + Vector3(0, rng.randf_range(4.0, 11.0), 0)
				pb.angular_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))
				pb.add_collision_exception_with(frame_b)
				piece_bodies[p] = pb
			# the blast breaks the engine-tender coupling and throws the tender
			for j in joints:
				var pj := j as PinJoint3D
				if pj.get_node(pj.node_a) == frame_b or pj.get_node(pj.node_b) == frame_b:
					pj.queue_free()
			if bodies.size() > 1:
				bodies[1].linear_velocity += t.cars[1].global_basis.x * 4.5 + Vector3(0, 3.0, 0)
				bodies[1].angular_velocity += -t.cars[1].global_basis.z * 1.4 + Vector3(0, 0.5, 0)
			for i in range(2, bodies.size()):
				bodies[i].linear_velocity += t.cars[i].global_basis.x * (0.6 if i % 2 else -0.6)
			fire_keys.append(Vector2(TrainCrashes.RUN_IN, 0.0))
			fire_keys.append(Vector2(TrainCrashes.RUN_IN + 0.15, 1.0))

	# simulate
	var t0 := step
	var hit_t := -1.0
	var crumple := 0.0
	var still := 0
	var max_steps := run_steps + int(MAX_AFTER * HZ)
	while step < max_steps:
		await physics_frame
		step += 1
		for i in bodies.size():
			t.cars[i].global_transform = bodies[i].global_transform
		for p: Node3D in piece_bodies:
			(p as Node3D).global_transform = (piece_bodies[p] as RigidBody3D).global_transform
		# couplings part when cars fold too far or pull apart
		for j in stage.find_children("Pin*", "PinJoint3D", false, false):
			var pj := j as PinJoint3D
			var a := pj.get_node(pj.node_a) as RigidBody3D
			var b := pj.get_node(pj.node_b) as RigidBody3D
			if a == null or b == null:
				continue
			var ang := rad_to_deg(acos(clampf(a.global_basis.z.dot(b.global_basis.z), -1.0, 1.0)))
			if ang > 75.0:
				pj.queue_free()
		if kind == "tip":
			# the wheels are held by the rails while the body keeps going: each car rolls over the outer rail in
			# turn, from the engine back. The last car is left nearly upright, dragged off the line.
			var since := float(step) / HZ - TrainCrashes.RUN_IN
			for i in bodies.size():
				var bi := bodies[i]
				var start_t := 0.1 + float(i) * 0.3
				var want := 100.0 if i < 2 else (75.0 if i < bodies.size() - 1 else 25.0)
				var tilt := rad_to_deg(acos(clampf(bi.global_basis.y.dot(Vector3.UP), -1.0, 1.0)))
				if since > start_t and since < start_t + 1.0 and tilt < want:
					var f := -bi.global_basis.z
					var w := bi.angular_velocity
					bi.angular_velocity = w + f * (2.6 - w.dot(f)) * 0.35
		if kind == "block":
			var sp := bodies[0].linear_velocity.length()
			if hit_t < 0.0 and sp < TrainCrashes.SPEED * 0.6:
				hit_t = float(step) / HZ
				# the cars behind run into a dead stop: they fold left and right and ride up on each other
				for i in range(1, bodies.size()):
					var c := t.cars[i]
					var side := 1.0 if i % 2 else -1.0
					var k := 1.0 / (1.0 + float(i - 1) * 0.25)
					bodies[i].linear_velocity += c.global_basis.x * side * 3.2 * k + Vector3(0, 1.6 * k, 0)
					bodies[i].angular_velocity += Vector3(0, side * 0.9 * k, 0) + c.global_basis.x * 0.7 * k
				# the engine is stopped dead against the block (no bounce back off the traps)
				bodies[0].freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				bodies[0].freeze = true
				var cb := t.cars[0].global_basis
				var flat := Basis(Vector3(cb.x.x, 0, cb.x.z).normalized(), Vector3.UP, Vector3(cb.z.x, 0, cb.z.z).normalized())
				bodies[0].global_transform = Transform3D(flat * Basis(Vector3.RIGHT, -0.05),
					bodies[0].global_position + Vector3(0, -0.12, 0))
			if hit_t >= 0.0:
				crumple = clampf((float(step) / HZ - hit_t) / 0.18, 0.0, 1.0)
				var e := 1.0 - pow(1.0 - crumple, 2.0)
				eng.get_node("Body/FrontBeam").position = Vector3(0, -0.12 * e, 0.85 * e)
				eng.get_node("Body/FrontBeam").rotation = Vector3(0.10 * e, 0.06 * e, 0.05 * e)
				eng.get_node("Body/Smokebox").position = Vector3(0, -0.25 * e, 0.55 * e)
				eng.get_node("Body/Smokebox").rotation = Vector3(0.12 * e, 0, -0.05 * e)
				var smb: Node3D = eng.get_node("Body/Smokebox")
				smb.scale = Vector3(1.0 + 0.06 * e, 1.0 - 0.1 * e, 1.0 - 0.25 * e)
				eng.get_node("Body/Chimney").position = Vector3(0.3 * e, -0.55 * e, 0.75 * e)
				eng.get_node("Body/Chimney").rotation = Vector3(-0.45 * e, 0, 0.35 * e)
				eng.get_node("Body/Cylinders").position = Vector3(0, -0.05 * e, 0.4 * e)
				for nm: String in ["BufferFL", "BufferFR"]:
					var bn: Node3D = eng.get_node(nm)
					bn.position.z = eng.front_z + 0.75 * e
		if (step - t0) % KEY_EVERY == 0:
			_key_all(recs)
		# settled?
		var moving := false
		for b in bodies:
			if b.freeze:
				continue
			if b.linear_velocity.length() > 0.15 or b.angular_velocity.length() > 0.15:
				moving = true
		for p: Node3D in piece_bodies:
			var pb: RigidBody3D = piece_bodies[p]
			if pb.linear_velocity.length() > 0.3:
				moving = true
		still = 0 if moving else still + 1
		if still > HZ and float(step - t0) / HZ > 2.5:
			break
	var length := float(recs[0].pos.size()) / 30.0
	if kind == "blast":
		fire_keys.append(Vector2(length, 1.0))
	var anim := Animation.new()
	anim.length = length
	for r in recs:
		_tracks(anim, r)
	var ft := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ft, NodePath(".:fire_level"))
	anim.value_track_set_update_mode(ft, Animation.UPDATE_CONTINUOUS)
	for k in fire_keys:
		anim.track_insert_key(ft, k.x, k.y)
	var ct := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ct, NodePath(".:crash_time"))
	anim.track_insert_key(ct, 0.0, TrainCrashes.RUN_IN)
	var settle := float(step - t0) / HZ
	var e0 := t.cars[0].global_position
	print("TRAIN BAKE %s_%d length %.1f s, settled %.1f s after the crash, engine ends at (%.1f, %.1f, %.1f) tilt %.0f deg%s" % [
		kind, n, length, settle, e0.x, e0.y, e0.z,
		rad_to_deg(acos(clampf(t.cars[0].global_basis.y.dot(Vector3.UP), -1, 1))),
		(", hit at %.2f s" % hit_t) if hit_t >= 0.0 else ""])
	var tilts := ""
	for c in t.cars:
		tilts += "%.0f " % rad_to_deg(acos(clampf(c.global_basis.y.dot(Vector3.UP), -1, 1)))
	print("   car tilts (deg): ", tilts)
	stage.queue_free()
	await process_frame
	return anim


func _rec(p: String, node: Node3D, local_to: Node3D) -> Rec:
	var r := Rec.new()
	r.path = p
	r.node = node
	r.local_to = local_to
	return r


func _key_all(recs: Array[Rec]) -> void:
	for r in recs:
		var xf := r.node.transform
		if r.local_to != r.node.get_parent():
			xf = r.local_to.global_transform.affine_inverse() * r.node.global_transform
		r.pos.append(xf.origin)
		r.rot.append(xf.basis.orthonormalized().get_rotation_quaternion())
		r.scl.append(xf.basis.get_scale())


func _tracks(anim: Animation, r: Rec) -> void:
	var pt := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pt, NodePath(r.path))
	var rt := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rt, NodePath(r.path))
	var st := -1
	if r.keyed_scale:
		st = anim.add_track(Animation.TYPE_SCALE_3D)
		anim.track_set_path(st, NodePath(r.path))
	for i in r.pos.size():
		var tm := float(i) / 30.0
		anim.position_track_insert_key(pt, tm, r.pos[i])
		anim.rotation_track_insert_key(rt, tm, r.rot[i])
		if st >= 0:
			anim.scale_track_insert_key(st, tm, r.scl[i])


func _body(parent: Node3D, xf: Transform3D, box: AABB, mass: float, com_y: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = "Body%d" % parent.get_child_count()
	b.mass = mass
	var pm := PhysicsMaterial.new()
	pm.friction = 0.45
	pm.bounce = 0.05
	b.physics_material_override = pm
	b.continuous_cd = true
	b.can_sleep = true
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(maxf(box.size.x, 0.1), maxf(box.size.y, 0.1), maxf(box.size.z, 0.1))
	shape.shape = bs
	shape.position = box.get_center()
	b.add_child(shape)
	b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	b.center_of_mass = Vector3(0, com_y, box.get_center().z) if com_y > -100.0 else box.get_center()
	b.linear_damp = 0.05
	b.angular_damp = 0.4
	parent.add_child(b)
	b.global_transform = xf
	return b


func _pin(parent: Node3D, a: RigidBody3D, b: RigidBody3D, at: Vector3) -> void:
	var j := PinJoint3D.new()
	j.name = "Pin%d" % parent.get_child_count()
	parent.add_child(j)
	j.global_position = at
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


# ------------------------------------------------------------------ check

## Plays every clip through an AnimationPlayer on a fresh train and checks the cars land where the bake put them.
func _check() -> void:
	var lib: AnimationLibrary = load(TrainCrashes.LIB_PATH)
	var fails := 0
	for nm in lib.get_animation_list():
		var parts := String(nm).split("_")
		var stage := Node3D.new()
		root.add_child(stage)
		var t := TrainCrashes.stage_for(parts[0], int(parts[1]), stage)
		t.set_process(false)
		t.player.add_animation_library("", lib)
		t.player.play(nm)
		var anim := lib.get_animation(nm)
		var worst := 0.0
		for tm: float in [0.0, TrainCrashes.RUN_IN, anim.length * 0.5, anim.length]:
			t.player.seek(tm, true)
			for i in t.cars.size():
				var tr := anim.find_track(NodePath("Car%d" % i), Animation.TYPE_POSITION_3D)
				var want := anim.position_track_interpolate(tr, tm)
				worst = maxf(worst, t.cars[i].position.distance_to(want))
		var ok := worst < 0.001 and anim.length > TrainCrashes.RUN_IN + 1.5
		if not ok:
			fails += 1
		print("CHECK %s %s length %.1f s, tracks %d, worst gap %.4f m" % ["ok  " if ok else "FAIL", nm, anim.length, anim.get_track_count(), worst])
		stage.queue_free()
		await process_frame
	print("TRAIN CHECK DONE %d fails" % fails)
