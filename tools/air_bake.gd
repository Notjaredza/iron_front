extends SceneTree
## Iron Front air: bakes the crash clips once (Asset Builder Chat).
##   Godot --headless --path iron_front --fixed-fps 120 -s res://tools/air_bake.gd [-- --only=name] [-- check]
## Planes: a scripted start (hit, smoke, fire, spin or wing off), then the physics engine works out the fall and
## the break-up; the balloon is scripted throughout. Every group is keyed 30 times a second into an Animation.
## Writes assets/air/crashes.res (AirCrashes.LIB_PATH). "check" plays every clip back and compares.

const HZ := 120
const KEY_EVERY := 4
const DT := 1.0 / HZ
const GROUPS := ["Fuselage", "WingL", "WingR", "Tail", "Gear"]
const SHARE := {"Fuselage": 0.5, "WingL": 0.15, "WingR": 0.15, "Tail": 0.08, "Gear": 0.07}

var only := ""
var check := false


class Rec:
	var path := ""
	var node: Node3D
	var pos: Array[Vector3] = []
	var rot: Array[Quaternion] = []
	var scl: Array[Vector3] = []
	var keyed_scale := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		if a == "check":
			check = true
	Engine.physics_ticks_per_second = HZ
	_run.call_deferred()


func _run() -> void:
	if check:
		await _check()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/air/"))
	var lib: AnimationLibrary = AirCrashes.library()
	if lib == null or only == "":
		lib = AnimationLibrary.new()
	for nm in AirCrashes.names():
		if only != "" and not nm.begins_with(only):
			continue
		var anim: Animation
		if nm == "balloon_burn":
			anim = await _bake_balloon()
		else:
			var p := nm.split("_")
			anim = await _bake_plane(p[0], p[1])
		if lib.has_animation(nm):
			lib.remove_animation(nm)
		lib.add_animation(nm, anim)
		print("BAKED %s length %.1f s tracks %d" % [nm, anim.length, anim.get_track_count()])
	var err := ResourceSaver.save(lib, AirCrashes.LIB_PATH, ResourceSaver.FLAG_COMPRESS)
	print("AIR BAKE DONE save=%d clips=%d" % [err, lib.get_animation_list().size()])
	quit()


# ------------------------------------------------------------------ helpers

func _ground(parent: Node3D) -> void:
	var g := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4000, 2, 4000)
	cs.shape = bs
	cs.position = Vector3(0, -1, 0)
	g.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.05
	g.physics_material_override = pm
	parent.add_child(g)


## The box round every mesh in a group, in the group's own space.
func _aabb(group: Node3D, skip: Array = []) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in group.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.name == "Blur" or mi.name == "Flash" or mi.name == "Far":
			continue
		var bad := false
		for s: Node in skip:
			if s.is_ancestor_of(mi):
				bad = true
		if bad:
			continue
		var xf := group.global_transform.affine_inverse() * mi.global_transform
		var b := xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _body(parent: Node3D, xf: Transform3D, box: AABB, mass: float, ldamp := 0.05, adamp := 0.3) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = maxf(mass, 5.0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.5
	pm.bounce = 0.08
	b.physics_material_override = pm
	b.continuous_cd = true
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# flat parts (wings) get a little thickness so they rest on the ground instead of sinking
	bs.size = Vector3(maxf(box.size.x, 0.25), maxf(box.size.y, 0.25), maxf(box.size.z, 0.25))
	shape.shape = bs
	shape.position = box.get_center()
	b.add_child(shape)
	b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	b.center_of_mass = box.get_center()
	b.linear_damp = ldamp
	b.angular_damp = adamp
	parent.add_child(b)
	b.global_transform = xf
	return b


func _key(recs: Array[Rec]) -> void:
	for r in recs:
		var xf := r.node.transform
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


func _value(anim: Animation, path: String, keys: Array[Vector2]) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, NodePath(path))
	anim.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	for k in keys:
		anim.track_insert_key(t, k.x, k.y)


# ------------------------------------------------------------------ planes

func _bake_plane(kind: String, mode: String) -> Animation:
	var stage := Node3D.new()
	root.add_child(stage)
	_ground(stage)
	var a := AirParts.make(kind)
	stage.add_child(a)
	a.position = Vector3(0, AirCrashes.START_H, 0)
	# the Aircraft root stays put; the groups are moved (in the root's space)
	var recs: Array[Rec] = []
	var groups: Dictionary = {}
	for gname: String in GROUPS:
		var r := Rec.new()
		r.path = gname
		r.node = a.get_node(gname)
		recs.append(r)
		groups[gname] = r.node
	var mass: float = a.mass
	var cruise: float = a.cruise
	var span: float = AirParts.spec(kind)["span_u"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + mode)
	var fire: Array[Vector2] = [Vector2(0, 0)]
	var rpm: Array[Vector2] = [Vector2(0, 1300)]
	var t := 0.0
	var step := 0
	# flight state for the scripted part (in the root's space; the root sits START_H up)
	var pos := Vector3.ZERO
	var vel := Vector3(0, 0, -cruise)
	var basis := Basis()
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var spin_rate := 0.0
	var bodies: Dictionary = {}          # group name -> RigidBody3D
	var main: RigidBody3D = null         # wing mode: everything but the lost wing, before the break-up
	var broken := false
	var impact := -1.0
	var settle := 0.0
	var t_hit := 0.8
	while true:
		# ---- scripted part / physics part
		if not broken:
			if mode == "spin":
				if t < t_hit + 0.4:
					pos += vel * DT
				else:
					# the nose drops and it winds up into a spin; the path bends down into a steep helix
					var k := smoothstep(t_hit + 0.4, t_hit + 2.0, t)
					spin_rate = lerpf(0.0, 2.3 if not AirParts.is_big(kind) else 1.2, k)
					yaw += spin_rate * DT
					pitch = lerpf(0.0, -1.15 if not AirParts.is_big(kind) else -0.9, k)
					roll = lerpf(0.0, 0.5, k) + sin(t * 3.0) * 0.05 * k
					var down := lerpf(0.0, 30.0 if not AirParts.is_big(kind) else 24.0, smoothstep(t_hit + 0.4, t_hit + 3.0, t))
					var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
					var hspeed := lerpf(cruise, 8.0, k)
					vel = fwd * hspeed + Vector3(0, -down, 0)
					pos += vel * DT
				basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3(0, 0, 1), -roll)
				var xf := Transform3D(basis, pos)
				for gname: String in GROUPS:
					(groups[gname] as Node3D).transform = xf
				# ground contact: the lowest corner of the whole plane
				if _lowest(a, xf) <= 0.15:
					_break(a, stage, groups, bodies, recs, vel, Vector3(0, spin_rate, 0), mass, rng, span)
					broken = true
					impact = t
			else:
				# wing: the right wing lets go; the rest is one body until it hits
				if t < t_hit:
					pos += vel * DT
					var xf := Transform3D(Basis(), pos)
					for gname: String in GROUPS:
						(groups[gname] as Node3D).transform = xf
				elif main == null:
					var xf := Transform3D(Basis(), pos)
					var wr: Node3D = groups["WingR"]
					var wbox := _aabb(wr)
					var wb := _body(stage, a.global_transform * xf, wbox, mass * SHARE["WingR"], 1.6, 0.25)
					wb.linear_velocity = vel + Vector3(5, 6, 3)
					wb.angular_velocity = Vector3(rng.randf_range(2, 4), rng.randf_range(-2, 2), rng.randf_range(-7, -4))
					bodies["WingR"] = wb
					var mbox := _aabb(a, [wr, a.far])
					main = _body(stage, a.global_transform * xf, mbox, mass * 0.85, 0.12, 0.15)
					main.linear_velocity = vel
					main.angular_velocity = Vector3(0.5, -0.35, -2.4) if not AirParts.is_big(kind) else Vector3(0.3, -0.2, -1.2)
				if main != null:
					var xf := a.global_transform.affine_inverse() * main.global_transform
					for gname: String in GROUPS:
						if gname != "WingR":
							(groups[gname] as Node3D).transform = xf
					var wxf := a.global_transform.affine_inverse() * (bodies["WingR"] as RigidBody3D).global_transform
					(groups["WingR"] as Node3D).transform = wxf
					if _lowest(a, xf, [groups["WingR"]]) <= 0.25:
						var v := main.linear_velocity
						var w := main.angular_velocity
						var mxf := main.global_transform
						main.queue_free()
						main = null
						for gname: String in GROUPS:
							if gname != "WingR":
								(groups[gname] as Node3D).transform = a.global_transform.affine_inverse() * mxf
						_break(a, stage, groups, bodies, recs, v, w, mass, rng, span, ["WingR"])
						broken = true
						impact = t
		if broken:
			for gname: String in bodies:
				var b: RigidBody3D = bodies[gname]
				(groups[gname] as Node3D).transform = a.global_transform.affine_inverse() * b.global_transform
		# ---- fire and engine
		if step % KEY_EVERY == 0:
			var f := 0.0
			if t >= t_hit:
				f = 1.0
			if t >= t_hit + (0.8 if mode == "spin" else 1.2):
				f = 2.0
			fire.append(Vector2(t, f))
			var r := 1300.0
			if impact >= 0.0:
				r = maxf(0.0, 1300.0 - (t - impact) * 3000.0)
			elif mode == "spin" and t > t_hit:
				r = 1500.0
			rpm.append(Vector2(t, r))
			_key(recs)
		# ---- end when the pieces have settled
		if broken:
			var moving := false
			for gname: String in bodies:
				var b: RigidBody3D = bodies[gname]
				if b.linear_velocity.length() > 0.3 or b.angular_velocity.length() > 0.3:
					moving = true
			if not moving:
				settle += DT
			if settle > 0.6 or t - impact > 7.0:
				break
		if t > 30.0:
			push_warning("crash %s %s never hit the ground" % [kind, mode])
			break
		t += DT
		step += 1
		await physics_frame
	var anim := Animation.new()
	anim.length = float(recs[0].pos.size() - 1) / 30.0
	for r in recs:
		_tracks(anim, r)
	_value(anim, ".:fire_level", fire)
	_value(anim, ".:rpm", rpm)
	_value(anim, ".:crash_time", [Vector2(0.0, impact)])
	var fus: Node3D = groups["Fuselage"]
	print("   %s %s: impact %.2f s, wreck at %s, %d bodies" % [kind, mode, impact, str(fus.position.round()), bodies.size()])
	stage.queue_free()
	await process_frame
	return anim


## The lowest point of the plane's meshes if its groups had transform xf (skipping some groups).
func _lowest(a: Aircraft, xf: Transform3D, skip: Array = []) -> float:
	var y := INF
	for gname: String in GROUPS:
		var g: Node3D = a.get_node(gname)
		if skip.has(g):
			continue
		var box := _aabb(g)
		for i in 8:
			var p := a.global_transform * (xf * box.get_endpoint(i))
			y = minf(y, p.y)
	return y


## Impact: every group becomes its own body, flung apart a little.
func _break(a: Aircraft, stage: Node3D, groups: Dictionary, bodies: Dictionary, recs: Array[Rec], vel: Vector3,
		ang: Vector3, mass: float, rng: RandomNumberGenerator, span: float, skip: Array = []) -> void:
	var fus_xf: Transform3D = a.global_transform * (groups["Fuselage"] as Node3D).transform
	for gname: String in GROUPS:
		if skip.has(gname):
			continue
		var g: Node3D = groups[gname]
		var box := _aabb(g)
		var xf: Transform3D = a.global_transform * g.transform
		var b := _body(stage, xf, box, mass * float(SHARE[gname]), 0.3, 0.6)
		var out := (xf * box.get_center() - fus_xf.origin)
		out.y = 0.0
		var kick := Vector3.ZERO
		match gname:
			"Fuselage":
				kick = Vector3(0, 1.5, 0)
			"WingL", "WingR":
				kick = out.normalized() * rng.randf_range(2.0, 4.0) + Vector3(0, rng.randf_range(2.0, 4.0), 0)
			"Tail":
				kick = Vector3(0, rng.randf_range(3.0, 5.0), 0) + out.normalized() * 2.0
			"Gear":
				kick = Vector3(rng.randf_range(-2, 2), 1.0, rng.randf_range(-2, 2))
		b.linear_velocity = vel * 0.55 + kick
		b.angular_velocity = ang * 0.5 + Vector3(rng.randf_range(-2, 2), rng.randf_range(-2, 2), rng.randf_range(-2, 2))
		bodies[gname] = b


# ------------------------------------------------------------------ balloon

func _bake_balloon() -> Animation:
	var stage := Node3D.new()
	root.add_child(stage)
	var b := Balloon.make()
	stage.add_child(b)
	var h0 := AirCrashes.BALLOON_H
	b.set_height(h0)
	var kite := b.kite
	var recs: Array[Rec] = []
	var paths := ["Kite", "Kite/Envelope", "Cable", "Kite/Basket", "Kite/Basket/Crew0", "Kite/Basket/Crew1",
		"Kite/Basket/Crew0/Chute", "Kite/Basket/Crew1/Chute"]
	for i in 4:
		paths.append("Kite/Envelope/Seg%d" % i)
	for i in 3:
		paths.append("Kite/Envelope/Fin%d" % i)
	for p: String in paths:
		var r := Rec.new()
		r.path = p
		r.node = b.get_node(p)
		r.keyed_scale = true
		recs.append(r)
	var fire: Array[Vector2] = []
	var t := 0.0
	var dt := 1.0 / 30.0
	var vy := 0.0
	var y := h0
	var x_drift := 0.0
	var crew_state := [{"jump": 1.1, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "out": false},
		{"jump": 1.7, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "out": false}]
	var landed_at := -1.0
	var env_rest := []
	for i in 4:
		env_rest.append(b.segments[i].transform)
	var crew_rest: Array[Transform3D] = [b.crew[0].transform, b.crew[1].transform]
	var crew_down := [false, false]
	while true:
		# fire spreads from the tail forward; the envelope burns and folds in the middle, then falls
		var burn := smoothstep(0.3, 4.0, t)
		fire.append(Vector2(t, 0.0 if t < 0.3 else 2.0))
		if t > 1.5:
			vy = minf(vy + 7.5 * dt, 24.0)
		y -= vy * dt
		var ground_y := 0.0
		var on_ground := y <= ground_y
		if on_ground:
			y = ground_y
			if landed_at < 0.0:
				landed_at = t
		x_drift += (1.5 if not on_ground else 0.0) * dt
		kite.position = Vector3(0, y, DRUM_Z(b) + h0 * 0.12 + x_drift)
		var fold := smoothstep(1.0, 5.0, t)
		kite.rotation = Vector3(-0.25 * fold, 0.0, 0.18 * fold) if not on_ground else Vector3(-0.1, 0.0, 0.35)
		# segments: the tail end shrinks first, the middle buckles (rear half drops, nose tips down)
		for i in 4:
			var seg: MeshInstance3D = b.segments[i]
			var rest: Transform3D = env_rest[i]
			var k := clampf(burn * 1.4 - float(3 - i) * 0.12, 0.0, 1.0)
			var s := Vector3(lerpf(1.0, 0.55, k), lerpf(1.0, 0.18, k), lerpf(1.0, 0.8, k))
			var tilt := (0.35 if i >= 2 else -0.3) * fold
			var drop := -3.0 * fold * (1.0 if i != 1 else 0.4)
			seg.transform = Transform3D(Basis(Vector3.RIGHT, tilt) * Basis.from_scale(s), rest.origin + Vector3(0, drop, 0))
		for i in 3:
			var fin: MeshInstance3D = b.fins[i]
			var k := smoothstep(0.3, 2.5, t)
			fin.transform = Transform3D(Basis(Vector3.RIGHT, 0.5 * k) * Basis.from_scale(Vector3.ONE * lerpf(1.0, 0.3, k)), Vector3(0, -2.0 * k, -1.5 * k))
		# the crew: climb on the rim, jump, fall, chute opens after 1.2 s, drift down at 5 m/s
		var basket_xf: Transform3D = b.global_transform * kite.transform * b.basket.transform
		for c in 2:
			var man: Node3D = b.crew[c]
			var st: Dictionary = crew_state[c]
			var chute: Node3D = man.get_node("Chute")
			if t < st["jump"]:
				man.transform = crew_rest[c]
				st["pos"] = basket_xf * crew_rest[c].origin
			else:
				if not st["out"]:
					st["out"] = true
					var side := -1.0 if c == 0 else 1.0
					st["vel"] = Vector3(side * 2.5, 2.0, -1.0 + float(c)) + Vector3(0, -vy, 0)
				var since: float = t - float(st["jump"])
				var v: Vector3 = st["vel"]
				var open := smoothstep(1.2, 2.0, since)
				var drag := lerpf(0.05, 2.5, open)
				v += Vector3(0, -9.81, 0) * dt - v * drag * dt
				if open > 0.5:
					v.y = maxf(v.y, -5.5)
					v.x = lerpf(v.x, 1.2, dt)
				var p: Vector3 = st["pos"] + v * dt
				if p.y <= 0.0:
					p.y = 0.0
					v = Vector3.ZERO
					crew_down[c] = true
				st["pos"] = p
				st["vel"] = v
				# the man hangs under the chute; tilt a little with the swing
				var swing := sin(since * 2.2 + float(c)) * 0.15 * open
				var world := Transform3D(Basis(Vector3(0, 0, 1), swing), p)
				man.transform = basket_xf.affine_inverse() * world
				var chute_s := 0.001 if open <= 0.0 else lerpf(0.15, 1.0, open)
				if crew_down[c]:
					chute_s = lerpf(chute.scale.x, 0.35, 0.1)
				chute.scale = Vector3.ONE * chute_s
				chute.rotation.x = 0.0 if not crew_down[c] else lerpf(chute.rotation.x, 1.4, 0.05)
		b._update_cable()
		_key(recs)
		if landed_at >= 0.0 and crew_down[0] and crew_down[1] and t > landed_at + 1.5:
			break
		if t > 40.0:
			break
		t += dt
		await process_frame
	var anim := Animation.new()
	anim.length = float(recs[0].pos.size() - 1) / 30.0
	for r in recs:
		_tracks(anim, r)
	_value(anim, ".:fire_level", fire)
	_value(anim, ".:crash_time", [Vector2(0.0, landed_at)])
	print("   balloon burn: envelope down at %.2f s, crew down at the end %.1f s" % [landed_at, t])
	stage.queue_free()
	await process_frame
	return anim


static func DRUM_Z(b: Balloon) -> float:
	return Balloon.DRUM.z + 1.0


# ------------------------------------------------------------------ check

## Plays every clip through an AnimationPlayer on a fresh model and checks the groups land where the bake put them.
func _check() -> void:
	var lib: AnimationLibrary = AirCrashes.library()
	var fails := 0
	for nm in lib.get_animation_list():
		var stage := Node3D.new()
		root.add_child(stage)
		var n: Node3D
		var probe := "Fuselage"
		if nm == "balloon_burn":
			n = Balloon.make()
			probe = "Kite"
		else:
			n = AirParts.make(String(nm).split("_")[0])
		stage.add_child(n)
		var p := AirCrashes.player_for(n)
		p.play(nm)
		var anim := lib.get_animation(nm)
		var worst := 0.0
		for tm: float in [0.0, anim.length * 0.5, anim.length]:
			p.seek(tm, true)
			for i in anim.get_track_count():
				if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
					continue
				var want := anim.position_track_interpolate(i, tm)
				var node: Node3D = n.get_node(anim.track_get_path(i))
				worst = maxf(worst, node.position.distance_to(want))
		var ok := worst < 0.001 and anim.length > 3.0
		if not ok:
			fails += 1
		print("CHECK %s %s length %.1f s, tracks %d, worst gap %.4f m" % ["ok  " if ok else "FAIL", nm, anim.length, anim.get_track_count(), worst])
		stage.queue_free()
		await process_frame
	print("AIR CHECK DONE %d fails" % fails)
