class_name FlameFx
extends Node3D
## Flamethrower fire (Question Chat, flamethrower round, 2026-11-10).
## One node holds all the fire of a scene, worked out on the CPU each step and drawn as two MultiMeshes of the
## faceted explosion blob: fire billows (flame_fire.gdshader, unshaded HDR heat colours) and black oily smoke
## (flame_smoke.gdshader, lit, glowing orange underneath near the fire).
##   jets      add_jet(fn): fn(t) -> {"from", "vel", "on"} or null. A burning stream of fuel blobs that arcs under
##             gravity, rolls into billows along the way and drips; where it lands it lights a ground fire.
##   ground    fuel that lands makes a patch: it burns hard, dies down, smoulders, and leaves a black scorch.
##             Fuel also sticks to the boxes in `solids` (walls, sandbags, wrecks) and burns on them.
##   burners   add_burner(fn, t0, t1, ...): fn(t) -> points; flames off them (burning men, roofs, wrecks).
##   fireball  fireball(at, scale): a tank of fuel bursting (the operator hit), fuel thrown all round.
##   light     a few OmniLights moved each step to the brightest fires, so the fire lights the ground and men.
## step(t, dt) once a frame. ground_fn: Callable(world point) -> ground height (empty = flat at 0).

const FireShader := preload("res://scripts/flame/flame_fire.gdshader")
const SmokeShader := preload("res://scripts/flame/flame_smoke.gdshader")
const CAP_FIRE := 3200
const CAP_SMOKE := 1800
const LIGHTS := 8
const G := 9.8
enum {JET, DRIP, LICK, EMBER}

var ground_fn: Callable
var solids: Array = []  # AABB
var wind := Vector3(1.1, 0, 0.4)
var rng := RandomNumberGenerator.new()
var now := 0.0
var fire: Array = []  # [kind, p, v, age, life, s0, s1, h0, seed, src]
var smoke: Array = []  # [p, v, age, life, s0, s1, glow0, seed, col]
var patches: Array = []  # {p, n, r, fuel, age, seed, scorch, smoulder}
var jets: Array = []  # {fn, on, last, tip}
var burners: Array = []  # {fn, t0, t1, rate, size, smoke, power}
var flashes: Array = []  # [p, t0, power, d]
var lights: Array = []
var fire_mm: MultiMesh
var smoke_mm: MultiMesh
var scorch_mat: StandardMaterial3D
var _scorch_mesh: Array = []


static func make(seed_value := 1) -> FlameFx:
	var f := FlameFx.new()
	f.rng.seed = seed_value
	f._build()
	return f


func _build() -> void:
	fire_mm = _mm(CAP_FIRE, false)
	var fm := ShaderMaterial.new()
	fm.shader = FireShader
	_mmi(fire_mm, fm)
	smoke_mm = _mm(CAP_SMOKE, true)
	var sm := ShaderMaterial.new()
	sm.shader = SmokeShader
	_mmi(smoke_mm, sm)
	scorch_mat = StandardMaterial3D.new()
	scorch_mat.albedo_color = Color(0.05, 0.042, 0.035)
	scorch_mat.roughness = 1.0
	scorch_mat.vertex_color_use_as_albedo = true
	for i in 4:
		_scorch_mesh.append(_scorch(i))
	for i in LIGHTS:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.56, 0.22)
		l.light_energy = 0.0
		l.omni_range = 9.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = i < 3
		l.visible = false
		add_child(l)
		lights.append(l)


func _mm(cap: int, colors: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = colors
	mm.mesh = FxMesh.blob()
	mm.instance_count = cap
	mm.visible_instance_count = 0
	return mm


func _mmi(mm: MultiMesh, mat: Material) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 400, 1000))
	add_child(mi)


## A ragged black disc (the scorch left by a fire), flat in its own XZ plane, radius 1.
func _scorch(k: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 77 + k
	var n := 14
	var rad: Array[float] = []
	for i in n:
		rad.append(r.randf_range(0.65, 1.15))
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0)) * rad[i]
		var p1 := Vector3(cos(a1), 0, sin(a1)) * rad[(i + 1) % n]
		for v: Array in [[Vector3.ZERO, 1.0], [p1, 0.55], [p0, 0.55]]:
			var c: float = v[1]
			st.set_color(Color(c, c, c))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	return st.commit()


func ground(p: Vector3) -> float:
	return 0.0 if ground_fn.is_null() else float(ground_fn.call(p))


# ---------------------------------------------------------------- what the scenes call

func add_jet(fn: Callable, rate := 120.0, size := 1.0) -> Dictionary:
	var j := {"fn": fn, "on": false, "rate": rate, "size": size, "tip": Vector3.ZERO, "acc": 0.0, "fired": 0.0}
	jets.append(j)
	return j


func add_burner(fn: Callable, t0: float, t1: float, rate := 10.0, size := 0.4, smoke_rate := 1.2, power := 1.0) -> void:
	burners.append({"fn": fn, "t0": t0, "t1": t1, "rate": rate, "size": size, "smoke": smoke_rate, "power": power, "acc": 0.0})


## A tank of fuel bursting: a white-hot ball, burning fuel thrown all round, a tower of smoke.
func fireball(at: Vector3, scale := 1.0) -> void:
	for i in int(110 * scale):
		var d := _rand_dir()
		d.y = absf(d.y) * 0.8 + 0.15
		var v := d.normalized() * rng.randf_range(2.0, 9.0) * sqrt(scale)
		_fire(LICK, at + d * 0.2, v, rng.randf_range(0.5, 1.4), rng.randf_range(0.15, 0.3) * scale,
			rng.randf_range(0.45, 1.0) * scale, rng.randf_range(0.72, 0.98))
	for i in int(26 * scale):
		var d := _rand_dir()
		d.y = absf(d.y) + 0.4
		_fire(JET, at, d.normalized() * rng.randf_range(3.0, 7.0) * sqrt(scale), 3.0, 0.12, 0.35, 0.95)
	for i in int(18 * scale):
		_smoke(at + _rand_dir() * 0.8 * scale + Vector3(0, 1.0, 0), Vector3(0, rng.randf_range(2.5, 5.0), 0) + _rand_dir() * 1.2,
			rng.randf_range(4.0, 6.5), 0.4 * scale, rng.randf_range(1.0, 1.8) * scale, 1.0)
	for i in 24:
		_fire(EMBER, at, _rand_dir() * rng.randf_range(3, 9) + Vector3(0, 3, 0), rng.randf_range(0.8, 1.8), 0.03, 0.03, 1.1)
	flashes.append([at, now, 9.0 * scale, 1.6])


## Splash fuel onto a point (fuel is about seconds of hard burning).
func feed(p: Vector3, n: Vector3, fuel: float) -> void:
	for pt: Dictionary in patches:
		var q: Vector3 = pt["p"]
		if (pt["n"] as Vector3).dot(n) > 0.7 and q.distance_to(p) < float(pt["r"]) * 0.8 + 0.25:
			pt["fuel"] = minf(float(pt["fuel"]) + fuel, 14.0)
			pt["r"] = minf(float(pt["r"]) + fuel * 0.02, 1.4)
			pt["p"] = q.lerp(p, 0.04)
			pt["smoulder"] = 0.0
			return
	var sc := MeshInstance3D.new()
	sc.mesh = _scorch_mesh[patches.size() % _scorch_mesh.size()]
	sc.material_override = scorch_mat
	sc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b := _basis_up(n)
	sc.transform = Transform3D(b.rotated(n, rng.randf() * TAU).scaled(Vector3.ONE * 0.05), p + n * (0.012 + 0.002 * (patches.size() % 5)))
	add_child(sc)
	patches.append({"p": p, "n": n, "r": 0.35, "fuel": fuel, "age": 0.0, "seed": rng.randf(), "scorch": sc, "smoulder": 0.0,
		"scorch_r": 0.05})


func _basis_up(n: Vector3) -> Basis:
	var y := n.normalized()
	var x := (Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).cross(y).normalized()
	return Basis(x, y, x.cross(y))


func _rand_dir() -> Vector3:
	return Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()


func _fire(kind: int, p: Vector3, v: Vector3, life: float, s0: float, s1: float, h0: float, src := -1) -> void:
	if fire.size() >= CAP_FIRE:
		return
	fire.append([kind, p, v, 0.0, life, s0, s1, h0, rng.randf() * 37.0, src])


func _smoke(p: Vector3, v: Vector3, life: float, s0: float, s1: float, glow0: float, col := Color(-1, 0, 0)) -> void:
	if smoke.size() >= CAP_SMOKE:
		return
	var c := col
	if c.r < 0.0:
		var g := rng.randf_range(0.012, 0.03)
		c = Color(g, g * 0.92, g * 0.85)
	smoke.append([p, v, 0.0, life, s0, s1, glow0, rng.randf() * 37.0, c])


## Is p inside a solid? Returns [surface point, normal] or [].
func _hit_solid(p: Vector3, prev: Vector3) -> Array:
	for bx: AABB in solids:
		if bx.has_point(p):
			var top := bx.position.y + bx.size.y
			if prev.y >= top - 0.02:
				return [Vector3(p.x, top, p.z), Vector3.UP]
			# The face it came through.
			var c := bx.get_center()
			var h := bx.size * 0.5
			var d := prev - c
			var ax := absf(d.x) / maxf(h.x, 0.01)
			var az := absf(d.z) / maxf(h.z, 0.01)
			if ax > az:
				return [Vector3(c.x + signf(d.x) * h.x, p.y, p.z), Vector3(signf(d.x), 0, 0)]
			return [Vector3(p.x, p.y, c.z + signf(d.z) * h.z), Vector3(0, 0, signf(d.z))]
	return []


# ---------------------------------------------------------------- the step

func step(t: float, dt: float) -> void:
	now = t
	_step_jets(t, dt)
	_step_patches(dt)
	_step_burners(t, dt)
	_step_fire(dt)
	_step_smoke(dt)
	_draw()
	_light(t)


func _step_jets(t: float, dt: float) -> void:
	for ji in jets.size():
		var j: Dictionary = jets[ji]
		var st: Variant = (j["fn"] as Callable).call(t)
		j["on"] = false
		if st == null:
			continue
		var from: Vector3 = st["from"]
		var vel: Vector3 = st["vel"]
		var sz: float = j["size"]
		if not bool(st.get("on", false)):
			# The pilot flame at the nozzle.
			if rng.randf() < 0.6:
				_fire(LICK, from + _rand_dir() * 0.02, Vector3(0, 0.5, 0) + vel.normalized() * 0.3, 0.25, 0.03, 0.07, 0.95)
			j["fired"] = 0.0
			continue
		j["on"] = true
		j["fired"] = float(j["fired"]) + dt
		j["acc"] = float(j["acc"]) + float(j["rate"]) * dt
		var n := int(j["acc"])
		j["acc"] = float(j["acc"]) - n
		for k in n:
			var u := (float(k) + rng.randf()) / maxf(n, 1)
			var age := u * dt
			var v := vel + _rand_dir() * vel.length() * 0.025
			_fire(JET, from + v * age, v, 2.4, 0.07 * sz, 0.62 * sz, 1.15, ji)
			fire.back()[3] = age
		# Flash at the nozzle.
		_fire(LICK, from + vel.normalized() * 0.15, vel * 0.12, 0.12, 0.1 * sz, 0.2 * sz, 1.2)


func _step_patches(dt: float) -> void:
	for pt: Dictionary in patches:
		pt["age"] = float(pt["age"]) + dt
		var fuel: float = pt["fuel"]
		var r: float = pt["r"]
		var p: Vector3 = pt["p"]
		var n: Vector3 = pt["n"]
		var b := _basis_up(n)
		var burning := fuel > 0.0
		var inten := clampf(fuel / 3.0, 0.0, 1.0) if burning else 0.0
		pt["fuel"] = fuel - dt * (0.32 if burning else 0.2)
		# The scorch spreads to the fire's size and stays.
		var want := r * 1.25
		if float(pt["scorch_r"]) < want:
			pt["scorch_r"] = minf(want, float(pt["scorch_r"]) + dt * 1.5)
			var sc: MeshInstance3D = pt["scorch"]
			sc.transform.basis = sc.transform.basis.orthonormalized().scaled(Vector3.ONE * float(pt["scorch_r"]))
		if fuel < -40.0:
			continue
		var at := func() -> Vector3:
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * r
			return p + b.x * cos(a) * rr + b.z * sin(a) * rr + n * 0.05
		if burning:
			var rate := (5.0 + 18.0 * inten) * (0.4 + r)
			pt["acc"] = float(pt.get("acc", 0.0)) + rate * dt
			while float(pt["acc"]) >= 1.0:
				pt["acc"] = float(pt["acc"]) - 1.0
				var s := rng.randf_range(0.14, 0.34) * (0.55 + inten * 0.8)
				var up := Vector3(0, rng.randf_range(0.8, 1.6), 0) + n * 0.3
				_fire(LICK, at.call(), up, rng.randf_range(0.4, 0.9) * (0.7 + inten * 0.5), s * 0.5, s * 1.3,
					rng.randf_range(0.72, 0.95) * (0.85 + 0.2 * inten))
			if rng.randf() < dt * (0.5 + 1.5 * inten) * (0.4 + r):
				_smoke(at.call() + Vector3(0, 0.9 + inten, 0), Vector3(0, rng.randf_range(2.2, 3.2), 0), rng.randf_range(3.5, 6.0),
					0.18 + 0.1 * inten, rng.randf_range(0.6, 1.1) * (0.6 + inten * 0.6), 0.8 * inten + 0.2)
			if rng.randf() < dt * 3.0 * inten:
				_fire(EMBER, at.call(), Vector3(0, rng.randf_range(2, 4), 0) + _rand_dir(), rng.randf_range(0.8, 1.6), 0.025, 0.025, 1.1)
		else:
			# Smouldering: low flickers and a thin dark smoke that thins out.
			var sm := clampf(1.0 + fuel / 40.0, 0.0, 1.0)
			if rng.randf() < dt * 5.0 * sm * (0.4 + r):
				_fire(LICK, at.call(), Vector3(0, 0.3, 0), rng.randf_range(0.25, 0.5), 0.05, rng.randf_range(0.08, 0.16), 0.6)
			if rng.randf() < dt * 1.4 * sm * (0.4 + r):
				var g := rng.randf_range(0.05, 0.09)
				_smoke(at.call() + Vector3(0, 0.2, 0), Vector3(0, rng.randf_range(0.8, 1.4), 0), rng.randf_range(3.0, 5.0), 0.12,
					rng.randf_range(0.5, 0.9), 0.15, Color(g, g * 0.95, g * 0.9))


func _step_burners(t: float, dt: float) -> void:
	for br: Dictionary in burners:
		if t < float(br["t0"]) or t > float(br["t1"]):
			continue
		var fade := clampf((float(br["t1"]) - t) / 2.5, 0.15, 1.0) * clampf((t - float(br["t0"])) / 0.6, 0.2, 1.0)
		var pts: Array = (br["fn"] as Callable).call(t)
		if pts.is_empty():
			continue
		br["acc"] = float(br["acc"]) + float(br["rate"]) * fade * dt * pts.size()
		var sz: float = br["size"]
		while float(br["acc"]) >= 1.0:
			br["acc"] = float(br["acc"]) - 1.0
			var q: Vector3 = pts[rng.randi() % pts.size()]
			var s := sz * rng.randf_range(0.6, 1.2) * (0.5 + 0.5 * fade)
			_fire(LICK, q + _rand_dir() * sz * 0.4, Vector3(0, rng.randf_range(0.6, 1.4), 0), rng.randf_range(0.4, 0.8), s * 0.5, s * 1.3,
				rng.randf_range(0.85, 1.05))
		if rng.randf() < dt * float(br["smoke"]) * fade * pts.size():
			var q: Vector3 = pts[rng.randi() % pts.size()]
			_smoke(q + Vector3(0, 0.5, 0), Vector3(0, rng.randf_range(1.8, 2.6), 0), rng.randf_range(3.0, 5.0), sz * 0.5, sz * 2.4, 0.7)


func _step_fire(dt: float) -> void:
	var keep: Array = []
	for f: Array in fire:
		var kind: int = f[0]
		var p: Vector3 = f[1]
		var v: Vector3 = f[2]
		var age: float = f[3] + dt
		f[3] = age
		if age >= float(f[4]):
			if kind == LICK and rng.randf() < 0.12 and float(f[6]) > 0.3:
				_smoke(p + Vector3(0, 0.2, 0), v * 0.3 + Vector3(0, 2.2, 0), rng.randf_range(3.5, 5.5), float(f[6]) * 0.4,
					float(f[6]) * rng.randf_range(1.2, 1.9), 0.9)
			continue
		var prev := p
		match kind:
			JET:
				v += Vector3(0, -G * 0.62, 0) * dt
				v *= 1.0 - 0.32 * dt
				# Burning fuel rolls off the stream into billows, and drips.
				if age > 0.07 and rng.randf() < dt * (10.0 + 16.0 * minf(age, 1.0)):
					var s := lerpf(float(f[5]), float(f[6]), minf(age / 0.9, 1.0))
					_fire(LICK, p + _rand_dir() * s * 0.3, v * 0.35 + Vector3(0, 1.0, 0), rng.randf_range(0.35, 0.75), s * 0.5, s * 1.4,
						rng.randf_range(0.8, 1.0))
				if age > 0.15 and rng.randf() < dt * 1.6:
					_fire(DRIP, p, v * 0.55, 2.0, 0.05, 0.09, 1.0)
			DRIP:
				v += Vector3(0, -G, 0) * dt
				if rng.randf() < dt * 6.0:
					_fire(LICK, p, Vector3(0, 0.6, 0), 0.3, 0.04, 0.12, 0.95)
			LICK:
				v += Vector3(0, 3.4, 0) * dt
				v *= 1.0 - minf(2.2 * dt, 0.5)
				v += wind * 0.6 * dt
			EMBER:
				v += Vector3(0, -2.0, 0) * dt + _rand_dir() * 6.0 * dt
				v *= 1.0 - 0.8 * dt
		p += v * dt
		f[1] = p
		f[2] = v
		if kind == JET or kind == DRIP:
			var hit := _hit_solid(p, prev)
			var gy := ground(p)
			if not hit.is_empty() or p.y <= gy:
				var at: Vector3 = hit[0] if not hit.is_empty() else Vector3(p.x, gy, p.z)
				var nn: Vector3 = hit[1] if not hit.is_empty() else Vector3.UP
				feed(at, nn, 0.16 if kind == JET else 0.1)
				if kind == JET and rng.randf() < 0.55:
					var s := float(f[6]) * rng.randf_range(0.7, 1.2)
					var sv := Vector3(v.x, 0, v.z) * 0.18 + nn * 1.5 + Vector3(0, 1.2, 0)
					_fire(LICK, at + nn * 0.15, sv, rng.randf_range(0.5, 0.9), s * 0.5, s * 1.5, rng.randf_range(0.95, 1.12))
				continue
		keep.append(f)
	fire = keep


func _step_smoke(dt: float) -> void:
	var keep: Array = []
	for s: Array in smoke:
		var age: float = s[2] + dt
		s[2] = age
		if age >= float(s[3]):
			continue
		var v: Vector3 = s[1]
		var target := wind * 1.3 + Vector3(0, 2.6 * exp(-age * 0.15), 0)
		v = v.lerp(target, minf(0.7 * dt, 1.0))
		s[1] = v
		s[0] = (s[0] as Vector3) + v * dt
		keep.append(s)
	smoke = keep


# ---------------------------------------------------------------- drawing and light

func _draw() -> void:
	var n := 0
	for f: Array in fire:
		var kind: int = f[0]
		var age: float = f[3]
		var u := age / float(f[4])
		var s0: float = f[5]
		var s1: float = f[6]
		var size: float
		var heat: float
		var spread := 0.4
		match kind:
			JET:
				size = lerpf(s0, s1, 1.0 - pow(1.0 - minf(age / 0.9, 1.0), 1.6))
				heat = float(f[7]) - age * 0.45
				spread = 0.25
			LICK:
				size = lerpf(s0, s1, 1.0 - pow(1.0 - minf(u * 2.2, 1.0), 2.0)) * (1.0 - 0.8 * smoothstep(0.6, 1.0, u))
				heat = float(f[7]) - u * 1.05
			EMBER:
				size = s0
				heat = 1.1 - u * 0.5
				spread = 0.0
			_:
				size = lerpf(s0, s1, u)
				heat = float(f[7]) - u * 0.3
		var seed: float = f[8]
		var axis := Vector3(sin(seed * 1.7), cos(seed * 2.3), sin(seed * 3.1) + 0.01).normalized()
		var b := Basis(axis, seed + age * (1.5 + fmod(seed, 2.0))).scaled(Vector3(size, size * 1.15, size) * (0.85 + 0.3 * fmod(seed * 7.0, 1.0)))
		fire_mm.set_instance_transform(n, Transform3D(b, f[1]))
		fire_mm.set_instance_custom_data(n, Color(seed, heat, spread, 0))
		n += 1
	fire_mm.visible_instance_count = n
	var m := 0
	for s: Array in smoke:
		var age: float = s[2]
		var u := age / float(s[3])
		var size := lerpf(float(s[4]), float(s[5]), 1.0 - pow(1.0 - minf(u * 1.6, 1.0), 2.0)) * (1.0 - smoothstep(0.7, 1.0, u))
		var seed: float = s[7]
		var axis := Vector3(sin(seed * 1.3), cos(seed * 2.9), sin(seed * 0.7) + 0.01).normalized()
		var b := Basis(axis, seed + age * 0.3).scaled(Vector3(size, size * 0.85, size))
		smoke_mm.set_instance_transform(m, Transform3D(b, s[0]))
		var c: Color = s[8]
		var grey := c.r + minf(age * 0.006, 0.03)
		smoke_mm.set_instance_custom_data(m, Color(seed, float(s[6]) * exp(-age * 2.6), grey, 0.5))
		m += 1
	smoke_mm.visible_instance_count = m


func _light(t: float) -> void:
	var cands: Array = []  # [power, pos]
	for ji in jets.size():
		var j: Dictionary = jets[ji]
		if bool(j["on"]):
			# Light at the middle of the stream.
			var sum := Vector3.ZERO
			var c := 0
			for f: Array in fire:
				if int(f[9]) == ji and float(f[3]) > 0.15 and float(f[3]) < 0.6:
					sum += f[1]
					c += 1
			if c > 0:
				cands.append([3.2 * float(j["size"]), sum / c + Vector3(0, 0.4, 0)])
	for pt: Dictionary in patches:
		var fuel: float = pt["fuel"]
		if fuel > 0.0:
			cands.append([clampf(fuel / 3.0, 0.15, 1.0) * (0.6 + float(pt["r"])) * 1.6, (pt["p"] as Vector3) + (pt["n"] as Vector3) * 0.7])
		elif fuel > -20.0:
			cands.append([0.12 * (1.0 + fuel / 20.0), (pt["p"] as Vector3) + Vector3(0, 0.2, 0)])
	for br: Dictionary in burners:
		if t >= float(br["t0"]) and t <= float(br["t1"]):
			var pts: Array = (br["fn"] as Callable).call(t)
			if not pts.is_empty():
				cands.append([float(br["power"]), (pts[0] as Vector3) + Vector3(0, 0.3, 0)])
	var keepf: Array = []
	for fl: Array in flashes:
		var u := (t - float(fl[1])) / float(fl[3])
		if u < 1.0:
			cands.append([float(fl[2]) * pow(1.0 - u, 2.0), (fl[0] as Vector3) + Vector3(0, 1.2, 0)])
			keepf.append(fl)
	flashes = keepf
	# Merge fires close together so one light stands for a burning area.
	cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var picked: Array = []
	for cd: Array in cands:
		var merged := false
		for pk: Array in picked:
			if (pk[1] as Vector3).distance_to(cd[1]) < 3.0:
				pk[0] = float(pk[0]) + float(cd[0]) * 0.35
				merged = true
				break
		if not merged and picked.size() < LIGHTS:
			picked.append([cd[0], cd[1]])
	for i in LIGHTS:
		var l: OmniLight3D = lights[i]
		if i >= picked.size():
			l.visible = false
			continue
		var pw := minf(float(picked[i][0]), 10.0)
		var fl := 0.82 + 0.18 * sin(t * 31.0 + i * 1.7) * sin(t * 17.0 + i)
		l.visible = true
		l.position = picked[i][1]
		l.light_energy = pw * 0.9 * fl
		l.omni_range = 5.0 + 3.0 * sqrt(pw)
