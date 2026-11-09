class_name AirFx
extends Node3D
## Iron Front air effects (Asset Builder Chat): tracers, falling bombs and message bags, smoke trails and fire.
## One AirFx per scene; call step(dt) every frame. Uses Puffs (scripts/trains) for smoke, flames and dust, and the
## shared Blast (scripts/fx) for bomb bursts.

const TRACER_LEN := 7.0
const TRACER_CAP := 160
const BULLET_SPEED := 760.0

var smoke: Puffs
var glow: Puffs
var tracers: MultiMeshInstance3D
var _bullets: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var ground_h := 0.0
var blasts := true
var _seed := 1


static func make() -> AirFx:
	var f := AirFx.new()
	f.name = "AirFx"
	f.smoke = Puffs.make(false, 11)
	f.glow = Puffs.make(true, 12)
	f.add_child(f.smoke)
	f.add_child(f.glow)
	var g := TrainGeo.new()
	g.box(Vector3(0, 0, TRACER_LEN * 0.5), Vector3(0.09, 0.09, TRACER_LEN * 0.5), Color(1.0, 0.8, 0.4, 1.0))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = g.to_mesh(mat)
	mm.instance_count = TRACER_CAP
	mm.visible_instance_count = 0
	f.tracers = MultiMeshInstance3D.new()
	f.tracers.multimesh = mm
	f.tracers.top_level = true
	f.tracers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(f.tracers)
	return f


## One round from a gun: from, direction, the plane's own velocity. Every round is drawn as a tracer streak.
func shoot(from: Vector3, dir: Vector3, carrier_vel := Vector3.ZERO, spread := 0.006) -> void:
	if _bullets.size() >= TRACER_CAP:
		_bullets.pop_front()
	var d := (dir + smoke.jitter(spread)).normalized()
	_bullets.append({"pos": from, "vel": d * BULLET_SPEED + carrier_vel, "age": 0.0})
	glow.add("spark", from + d * 0.4, carrier_vel + d * 8.0, 0.6)


## A bomb or a message bag lets go: node (already in the world), its starting velocity, kind "bomb" or "bag".
func drop(node: Node3D, vel: Vector3, kind: String) -> void:
	_drops.append({"n": node, "vel": vel, "kind": kind, "age": 0.0, "done": false})


func trail(at: Vector3, vel: Vector3, level: float) -> void:
	# level 1: smoking (grey, thin); 2: burning (flames and black smoke)
	if level <= 0.0:
		return
	if level < 1.5:
		smoke.add("smoke", at + smoke.jitter(0.2), vel * 0.1 + smoke.jitter(0.4), 0.45 + 0.3 * level)
	else:
		glow.add("flame", at + glow.jitter(0.3), vel * 0.3 + glow.jitter(1.0), 1.3)
		glow.add("flame", at + glow.jitter(0.4), vel * 0.5 + glow.jitter(1.0), 1.0)
		smoke.add("burn", at + smoke.jitter(0.3), vel * 0.1 + smoke.jitter(0.5), 0.7)


func step(dt: float) -> void:
	# bullets: fly straight (a little drop), streaks along the velocity, dust and sparks on the ground
	var keep: Array[Dictionary] = []
	var mm := tracers.multimesh
	var n := 0
	for b in _bullets:
		b["age"] += dt
		var v: Vector3 = b["vel"]
		v.y -= 9.81 * dt
		b["vel"] = v
		var p: Vector3 = b["pos"] + v * dt
		b["pos"] = p
		if p.y <= ground_h:
			smoke.add("dust", Vector3(p.x, ground_h + 0.2, p.z), Vector3(0, 2.0, 0) + smoke.jitter(1.0), 0.35)
			glow.add("spark", Vector3(p.x, ground_h + 0.1, p.z), Vector3(0, 3.0, 0) + glow.jitter(2.0), 0.6)
			continue
		if b["age"] > 2.5:
			continue
		keep.append(b)
		var fwd := v.normalized()
		var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
		var basis := Basis.looking_at(fwd, up)
		mm.set_instance_transform(n, Transform3D(basis, p))
		n += 1
	_bullets = keep
	mm.visible_instance_count = n
	# bombs and message bags: fall with drag; bombs swing nose-down with the airflow, bags trail their streamer
	for d in _drops:
		if d["done"]:
			continue
		d["age"] += dt
		var node: Node3D = d["n"]
		var v: Vector3 = d["vel"]
		var k: float = 0.004 if d["kind"] == "bomb" else 0.25
		v += Vector3(0, -9.81, 0) * dt - v * v.length() * k * dt
		d["vel"] = v
		var p := node.global_position + v * dt
		if d["kind"] == "bomb":
			# the nose turns to the airflow (nose is -Z), slowly at first
			var want := Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.98 else Vector3.RIGHT)
			var cur := node.global_transform.basis.orthonormalized()
			var b := cur.slerp(want, clampf(dt * (0.8 + float(d["age"]) * 2.0), 0.0, 1.0))
			node.global_transform = Transform3D(b, p)
		else:
			node.global_position = p
			var s := node.get_node_or_null("Streamer")
			if s:
				_streamer(s, v, float(d["age"]))
		if p.y <= ground_h + (0.1 if d["kind"] == "bag" else 0.0):
			d["done"] = true
			if d["kind"] == "bomb":
				node.visible = false
				if blasts:
					_seed += 1
					var bl := Blast.new().setup(3, Vector3(p.x, ground_h, p.z), _seed)
					get_parent().add_child(bl)
				else:
					for i in 12:
						smoke.add("dust", Vector3(p.x, ground_h + 0.5, p.z), Vector3(0, 8, 0) + smoke.jitter(6.0), 1.5)
			else:
				node.global_position = Vector3(p.x, ground_h + 0.1, p.z)
				smoke.add("dust", Vector3(p.x, ground_h + 0.2, p.z), Vector3(0, 1, 0), 0.4)
	smoke.step(dt)
	glow.step(dt)


## The streamer (a chain of segments under the bag) trails upwards against the fall and flutters.
func _streamer(s: Node3D, v: Vector3, t: float) -> void:
	var back := (-v).normalized()
	if back.length() < 0.5:
		back = Vector3.UP
	var segs := s.get_children()
	var prev := s.global_position
	for i in segs.size():
		var seg: Node3D = segs[i]
		var wig := Vector3(sin(t * 14.0 + float(i) * 1.3), 0, cos(t * 11.0 + float(i) * 1.7)) * 0.25 * float(i + 1) / float(segs.size())
		var dir := (back + wig).normalized()
		var nxt := prev + dir * 0.45
		var up := Vector3.RIGHT if absf(dir.y) > 0.9 else Vector3.UP
		seg.global_transform = Transform3D(Basis.looking_at(dir, up), prev)
		prev = nxt


func busy() -> bool:
	return not _bullets.is_empty() or smoke.count() > 0 or glow.count() > 0
