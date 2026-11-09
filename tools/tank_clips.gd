extends "res://tools/lorry_clips.gd"
## The tanks, recorded as video frames (Tanks Chat, 2026-11-09).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/tank_clips.gd -- [scene ...]
## Scenes: gallery, look_heavy, look_light, drive, ramp, trench, fire_heavy, fire_light, crew,
## wreck_heavy, wreck_light. Frames go to results/units/anim_frames/tank_<scene>/; ffmpeg makes
## results/units/anim/tank_<scene>.mp4 (and the gallery stills in results/units/tanks/).
## Crew men are world-space actors: the tanks stand still while they climb in or bail out.

const TB := preload("res://scripts/vehicles/tank_builder.gd")
const TANK_SCENES: Array[String] = ["gallery", "look_heavy", "look_light", "drive", "ramp", "trench", "fire_heavy",
	"fire_light", "crew", "wreck_heavy", "wreck_light"]

var tanks: Array = []  # {node, v_fn, w_fn, pos, yaw, dl, dr, run, engine, parts, speed}
var tank_frame := -1
var terrain: Variant = null  # Callable(x, z) -> height, or null
var hidden_floor: Array = []
var shots: Array = []  # {tank, side, t, done}
var bursts: Array = []  # {tank, side, t0, t1, node}
var bits: Array = []  # {m, vel, spin, land}
var dusts: Array = []  # {t, at, done, big}
var crew_vis: Array = []  # {a, show, hide}


func _run() -> void:
	prefix = "tank_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	var args := OS.get_cmdline_user_args()
	if args == PackedStringArray(["check"]):
		quit(_check())
		return
	for sc in (args if not args.is_empty() else TANK_SCENES):
		await _record(sc)
	print("TANK CLIPS OK")
	quit()


## Headless check: every kind and look builds, rests level on flat ground, every track phase
## exists, the guns and hatches answer, and what a ride() costs.
func _check() -> int:
	var bad := 0
	_reset()
	for kind in ["heavy_male", "heavy_female", "light_gun", "light_mg"]:
		var line := []
		for lod in 3:
			for burnt in [false, true]:
				if burnt and lod > 0:
					continue
				var n := Tank.new().setup(kind, lod, burnt)
				stage.add_child(n)
				n.ride(ground_h, 0.0)
				var heave: float = n.spring["heave"]
				var pitch: float = n.spring["pitch"]
				if absf(heave) > 0.02 or absf(pitch) > 0.01:
					print("CHECK FAIL %s lod %d: not level on flat ground (heave %.3f, pitch %.3f)" % [kind, lod, heave, pitch])
					bad += 1
				for q in Tank.PHASES:
					n.drive(n._pitch() * float(q) / Tank.PHASES, -n._pitch() * float(q) / Tank.PHASES)
				for side in ([-1, 1] if n.heavy else [0]):
					var mx := n.muzzle_xf(side)
					if mx.origin.y < 0.5:
						print("CHECK FAIL %s: muzzle %d below the hull" % [kind, side])
						bad += 1
				for h: String in n.hatches:
					n.set_hatch(h, 1.0)
				line.append("%s%s %d" % [["close", "mid", "far"][lod], " wreck" if burnt else "", n.tri_count()])
				n.free()
		print("TRIS ", kind, ": ", ", ".join(line))
	# What resting on the ground costs per call (it runs every frame for a moving tank).
	mound(Vector3(0, 0, -2.0), 1.2, 0.4)
	var n2 := Tank.new().setup("heavy_male", 0)
	stage.add_child(n2)
	var t0 := Time.get_ticks_usec()
	for i in 100:
		n2.position.z = -0.05 * i
		n2.ride(ground_h, 1.0 / 30.0)
	print("RIDE heavy: %.2f ms per call" % ((Time.get_ticks_usec() - t0) / 100000.0))
	var n3 := Tank.new().setup("light_gun", 0)
	stage.add_child(n3)
	t0 = Time.get_ticks_usec()
	for i in 100:
		n3.position.z = -0.05 * i
		n3.ride(ground_h, 1.0 / 30.0)
	print("RIDE light: %.2f ms per call" % ((Time.get_ticks_usec() - t0) / 100000.0))
	print("TANK CHECK ", "OK" if bad == 0 else "FAILED %d" % bad)
	return bad


func _reset() -> void:
	super._reset()
	tanks.clear()
	tank_frame = -1
	terrain = null
	for n: Node3D in hidden_floor:
		n.visible = true
	hidden_floor.clear()
	shots.clear()
	bursts.clear()
	bits.clear()
	dusts.clear()
	crew_vis.clear()


# ---------------------------------------------------------------- ground

func ground_h(p: Vector3) -> float:
	var h := super.ground_h(p)
	if terrain != null:
		h += (terrain as Callable).call(p.x, p.z)
	return h


## Hides the flat test floor and lays a faceted ground from the terrain function instead.
func lay_terrain(fn: Callable, x0: float, x1: float, z0: float, z1: float, step := 0.3) -> void:
	terrain = fn
	for c in root.get_children():
		if c is MeshInstance3D and c.visible:
			(c as MeshInstance3D).visible = false
			hidden_floor.append(c)
	var g := UnitGeo.new()
	var nx := int(ceil((x1 - x0) / step))
	var nz := int(ceil((z1 - z0) / step))
	var hs := PackedFloat32Array()
	for j in nz + 1:
		for i in nx + 1:
			hs.append(fn.call(x0 + i * step, z0 + j * step))
	var base := Color(0.62, 0.56, 0.42)
	var dirt := Color(0.47, 0.38, 0.27)
	for j in nz:
		for i in nx:
			var p00 := Vector3(x0 + i * step, hs[j * (nx + 1) + i], z0 + j * step)
			var p10 := Vector3(x0 + (i + 1) * step, hs[j * (nx + 1) + i + 1], z0 + j * step)
			var p01 := Vector3(x0 + i * step, hs[(j + 1) * (nx + 1) + i], z0 + (j + 1) * step)
			var p11 := Vector3(x0 + (i + 1) * step, hs[(j + 1) * (nx + 1) + i + 1], z0 + (j + 1) * step)
			var slope := maxf(absf(p11.y - p00.y), absf(p10.y - p01.y)) / step
			var c := base.lerp(dirt, clampf(slope * 0.8, 0.0, 1.0))
			var hsh := absf(sin(float(i) * 12.99 + float(j) * 78.23) * 437.5)
			c = c.darkened((hsh - floorf(hsh)) * 0.05)
			TB.tri_n(g, p00, p01, p10, c, Vector3.UP)
			TB.tri_n(g, p10, p01, p11, c, Vector3.UP)
	# A flat skirt outward from every edge sample, at that sample's height.
	var sk := 120.0
	for i in nx:
		for zz: Array in [[z0, -1.0, 0], [z1, 1.0, nz]]:
			var a := Vector3(x0 + i * step, hs[int(zz[2]) * (nx + 1) + i], zz[0])
			var b := Vector3(x0 + (i + 1) * step, hs[int(zz[2]) * (nx + 1) + i + 1], zz[0])
			var o := Vector3(0, 0, float(zz[1]) * sk)
			TB.quad_n(g, a, b, Vector3(b.x, a.y, b.z) + o, a + o, base, Vector3.UP)
	for j in nz:
		for xx: Array in [[x0, -1.0, 0], [x1, 1.0, nx]]:
			var a := Vector3(xx[0], hs[j * (nx + 1) + int(xx[2])], z0 + j * step)
			var b := Vector3(xx[0], hs[(j + 1) * (nx + 1) + int(xx[2])], z0 + (j + 1) * step)
			var o := Vector3(float(xx[1]) * sk, 0, 0)
			TB.quad_n(g, a, b, Vector3(b.x, a.y, b.z) + o, a + o, base, Vector3.UP)
	for cn: Array in [[x0, z0, -1.0, -1.0], [x1, z0, 1.0, -1.0], [x0, z1, -1.0, 1.0], [x1, z1, 1.0, 1.0]]:
		var e: float = fn.call(cn[0], cn[1])
		var c0 := Vector3(cn[0], e, cn[1])
		TB.quad_n(g, c0, c0 + Vector3(float(cn[2]) * sk, 0, 0), c0 + Vector3(float(cn[2]) * sk, 0, float(cn[3]) * sk),
			c0 + Vector3(0, 0, float(cn[3]) * sk), base, Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = MG.mesh(g)
	stage.add_child(mi)


# ---------------------------------------------------------------- tanks

## v_fn(t) -> forward speed (m/s); w_fn(t) -> turn rate (rad/s, + = left). parts(t, node) sets
## the turret, guns and hatches every frame.
func tank(kind: String, at: Vector3, yaw: float, v_fn: Variant = null, w_fn: Variant = null, lod := 0, burnt := false) -> Dictionary:
	var n := Tank.new().setup(kind, lod, burnt)
	stage.add_child(n)
	n.position = at
	n.rotation.y = yaw
	var d := {"node": n, "v_fn": v_fn, "w_fn": w_fn, "pos": at, "yaw": yaw, "dl": 0.0, "dr": 0.0, "run": not burnt,
		"engine": not burnt, "parts": null, "speed": 0.0}
	if not burnt:
		n.ride(ground_h, 0.0)
	tanks.append(d)
	return d


## Piecewise-linear profile: keys [[t, value], ...] (held before the first and after the last).
static func prof(keys: Array) -> Callable:
	return func(t: float) -> float:
		if t <= float(keys[0][0]):
			return keys[0][1]
		for i in keys.size() - 1:
			var a: Array = keys[i]
			var b: Array = keys[i + 1]
			if t < float(b[0]):
				var u := (t - float(a[0])) / maxf(1e-4, float(b[0]) - float(a[0]))
				return lerpf(a[1], b[1], Anim.ease_of(u, "smooth"))
		return keys[keys.size() - 1][1]


func _update_tanks(t: float) -> void:
	var dt := 0.0 if tank_frame < 0 else 1.0 / FPS
	for d: Dictionary in tanks:
		var n: Tank = d["node"]
		if d["parts"] != null:
			(d["parts"] as Callable).call(t, n)
		if not d["run"]:
			continue
		var v: float = 0.0 if d["v_fn"] == null else (d["v_fn"] as Callable).call(t)
		var w: float = 0.0 if d["w_fn"] == null else (d["w_fn"] as Callable).call(t)
		if dt > 0.0:
			var yw: float = d["yaw"]
			d["yaw"] = yw + w * dt
			d["pos"] = (d["pos"] as Vector3) + Vector3(-sin(yw), 0, -cos(yw)) * v * dt
			d["dl"] = float(d["dl"]) + (v - w * n.track_x) * dt
			d["dr"] = float(d["dr"]) + (v + w * n.track_x) * dt
		d["speed"] = absf(v) + absf(w) * n.track_x
		n.position = d["pos"]
		n.rotation.y = d["yaw"]
		n.drive(d["dl"], d["dr"])
		var judder := 0.0
		if d["engine"]:
			judder = 0.004 * sin(t * 61.0) + 0.003 * sin(t * 37.0)
		n.ride(ground_h, dt, judder)


func _eval_props(t: float) -> void:
	if frame != tank_frame:
		_update_tanks(t)
		tank_frame = frame
	super._eval_props(t)


# ---------------------------------------------------------------- guns

## Recoil curve: back fast, held a moment, run out.
static func recoil_of(t: float, t0: float, length: float) -> float:
	var u := t - t0
	if u < 0.0 or u > 0.9:
		return 0.0
	if u < 0.05:
		return length * u / 0.05
	if u < 0.12:
		return length
	return length * (1.0 - Anim.ease_of((u - 0.12) / 0.78, "smooth"))


func shot(d: Dictionary, side: int, t0: float) -> void:
	shots.append({"tank": d, "side": side, "t": t0, "done": false})


## The recoil of every gun of tank d at t (sets the barrels).
func recoils(d: Dictionary, t: float) -> void:
	var n: Tank = d["node"]
	var by := {}
	for s: Dictionary in shots:
		if s["tank"] != d:
			continue
		var r := recoil_of(t, s["t"], 0.24 if n.heavy else 0.14)
		by[s["side"]] = maxf(float(by.get(s["side"], 0.0)), r)
	for side in [0, -1, 1]:
		n.set_recoil(side, by.get(side, 0.0))


## An MG burst from t0 to t1 (side 0 = turret MG, -1/1 = sponson MGs, 2 = the heavy's front MG).
func burst(d: Dictionary, side: int, t0: float, t1: float) -> void:
	var m := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.09
	sp.height = 0.26
	sp.radial_segments = 8
	sp.rings = 4
	sp.material = _mat("mgflash", Color(1.0, 0.82, 0.42), true)
	m.mesh = sp
	m.visible = false
	stage.add_child(m)
	bursts.append({"tank": d, "side": side, "t0": t0, "t1": t1, "node": m})


func mg_xf(n: Tank, side: int) -> Transform3D:
	if side == 2:
		return n.body.global_transform * Transform3D(Basis(), TB.H_FRONT_MG + Vector3(0, 0, -0.55))
	return n.muzzle_xf(side)


## Dust thrown up where a shot lands.
func dust_at(t: float, at: Vector3, big := true) -> void:
	dusts.append({"t": t, "at": at, "done": false, "big": big})


func _effects(t: float) -> void:
	for s: Dictionary in shots:
		if t >= float(s["t"]) and not s["done"]:
			s["done"] = true
			var d: Dictionary = s["tank"]
			var n: Tank = d["node"]
			var mx := n.muzzle_xf(s["side"])
			var fwd := -mx.basis.z.normalized()
			var rng := RandomNumberGenerator.new()
			rng.seed = int(float(s["t"]) * 100.0) + int(s["side"]) * 7
			var big := 1.0 if n.heavy else 0.7
			puff(mx.origin + fwd * 0.3, fwd * 2.5, 0.38 * big, Color(1.0, 0.8, 0.45), 0.12, 6.0, 0.95, t)
			for k in 8:
				var sd := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 0.8), rng.randf_range(-1, 1)) * 0.6
				puff(mx.origin + fwd * rng.randf_range(0.2, 1.2), fwd * rng.randf_range(1.2, 3.0) + sd, 0.22 * big,
					Color(0.82, 0.8, 0.76), 2.4, 1.6, 0.55, t)
			# The kick: the body rocks away from the gun.
			var side: int = s["side"]
			if side == 0:
				n.spring["vp"] = float(n.spring["vp"]) + 0.12
			else:
				n.spring["vr"] = float(n.spring["vr"]) + 0.08 * float(side)
			# Where it lands, about 45 m out.
			var land := mx.origin + Vector3(fwd.x, 0, fwd.z).normalized() * 45.0
			land.y = ground_h(land)
			dust_at(t + 0.35, land, true)
	for b: Dictionary in bursts:
		var on: bool = t >= float(b["t0"]) and t < float(b["t1"])
		var m: MeshInstance3D = b["node"]
		var n: Tank = (b["tank"] as Dictionary)["node"]
		m.visible = on and frame % 2 == 0
		if not on:
			continue
		var x := mg_xf(n, b["side"])
		m.global_transform = Transform3D(x.basis, x.origin - x.basis.z * 0.12)
		m.scale = Vector3.ONE * (0.8 + 0.4 * float((frame / 2) % 3) / 2.0)
		if frame % 3 == 0:
			puff(x.origin, -x.basis.z * 0.6 + Vector3(0, 0.3, 0), 0.06, Color(0.92, 0.92, 0.9), 1.0, 2.4, 0.45, t)
		if frame % 2 == 0:
			_case(x, n, b["side"])
		if frame % 5 == 0:
			var fwd := -x.basis.z
			var land := x.origin + Vector3(fwd.x, 0, fwd.z).normalized() * (38.0 + 6.0 * sin(t * 3.0)) \
				+ Vector3(-fwd.z, 0, fwd.x).normalized() * 2.5 * sin(t * 5.3)
			land.y = ground_h(land)
			dust_at(t + 0.15, land, false)
	for du: Dictionary in dusts:
		if t >= float(du["t"]) and not du["done"]:
			du["done"] = true
			var rng := RandomNumberGenerator.new()
			rng.seed = int(float(du["t"]) * 1000.0)
			var nb := 10 if du["big"] else 2
			for k in nb:
				var dir := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(1.0, 2.0), rng.randf_range(-0.6, 0.6))
				puff(du["at"] as Vector3, dir * (2.5 if du["big"] else 1.2), 0.45 if du["big"] else 0.18, Color(0.55, 0.47, 0.35),
					2.2 if du["big"] else 0.9, 1.4, 0.75, t)
	for bt: Dictionary in bits.duplicate():
		var m: MeshInstance3D = bt["m"]
		if bt["land"]:
			continue
		var v: Vector3 = bt["vel"]
		v.y -= 9.8 / FPS
		bt["vel"] = v
		m.position += v / FPS
		m.rotate(bt["spin"], 14.0 / FPS)
		var gy := ground_h(m.position)
		if m.position.y < gy + 0.01:
			m.position.y = gy + 0.01
			bt["land"] = true
	# Exhaust and dust off the tanks.
	for d: Dictionary in tanks:
		var n: Tank = d["node"]
		if not n.visible or not d["engine"]:
			continue
		var sp: float = d.get("speed", 0.0)
		var ex := n.bw(TB.H_EXHAUST if n.heavy else TB.L_EXHAUST)
		var hot: float = d.get("rev", 0.0)
		if frame % (2 if sp > 0.3 or hot > 0.0 else 5) == 0:
			var c := Color(0.32, 0.31, 0.3) if hot > 0.0 else Color(0.45, 0.45, 0.44)
			puff(ex, Vector3(0.1, 0.55, 0.25) + n.global_transform.basis * Vector3(0, 0, 0.3), 0.09 if n.heavy else 0.06, c,
				1.6, 2.6, 0.4 + 0.3 * hot, t)
		if sp > 0.6 and frame % 3 == 0:
			for s: float in [1.0, -1.0]:
				var rz := 3.0 if n.heavy else 1.6
				var wp := n.global_transform * Vector3(n.track_x * s, 0.1, rz)
				wp.y = ground_h(wp) + 0.12
				puff(wp, Vector3(0.25 * s, 0.4, 0.0) + n.global_transform.basis * Vector3(0, 0, 0.5), 0.2 if n.heavy else 0.13,
					Color(0.68, 0.6, 0.46), 1.6, 2.4, 0.25, t)
	super._effects(t)


## A spent case thrown out of a gun mount.
func _case(x: Transform3D, n: Tank, side: int) -> void:
	if bits.size() > 160:
		var old: Dictionary = bits.pop_front()
		(old["m"] as MeshInstance3D).queue_free()
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 0.06)
	bm.material = _mat("case", Color(0.75, 0.6, 0.3))
	m.mesh = bm
	stage.add_child(m)
	var back := x.basis.z.normalized()
	var out := n.global_transform.basis.x * (1.0 if side >= 0 else -1.0)
	m.global_position = x.origin + back * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = frame * 13 + side
	bits.append({"m": m, "vel": out * rng.randf_range(0.8, 1.6) + Vector3(0, rng.randf_range(0.5, 1.2), 0) + back * 0.3,
		"spin": Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), "land": false})


# ---------------------------------------------------------------- fire on a wreck

## Flames, smoke and light on a burnt-out tank from t0 (points in its body frame).
func burn(wn: Tank, flames: Array, t0: float, hit_at: Vector3, light_at: Vector3) -> Callable:
	var fire_mat := _mat("flame", Color(1.0, 0.55, 0.15), true)
	var core_mat := _mat("flame_core", Color(1.0, 0.86, 0.45), true)
	var fl_nodes: Array = []
	for i in flames.size():
		for k in 3:
			var m := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.3 - 0.07 * k
			sp.height = (0.3 - 0.07 * k) * 2.6
			sp.radial_segments = 8
			sp.rings = 4
			sp.material = core_mat if k == 2 else fire_mat
			m.mesh = sp
			wn.body.add_child(m)
			fl_nodes.append({"m": m, "base": (flames[i] as Vector3) + Vector3(0, 0.22 * k, 0), "i": i, "k": k})
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 11.0
	wn.body.add_child(light)
	light.position = light_at
	var boom := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 1.0
	bs.height = 2.0
	bs.material = _mat("boom", Color(1.0, 0.85, 0.5), true)
	boom.mesh = bs
	stage.add_child(boom)
	boom.position = hit_at
	boom.visible = false
	var fired := {"done": false}
	return func(t: float) -> void:
		boom.visible = t >= t0 and t < t0 + 0.12
		boom.scale = Vector3.ONE * (1.0 + (t - t0) * 10.0) if boom.visible else Vector3.ONE
		if t >= t0 and not fired["done"]:
			fired["done"] = true
			var rng := RandomNumberGenerator.new()
			rng.seed = 9
			for k in 24:
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.6, 1.6), rng.randf_range(-1, 1))
				puff(hit_at, dir * rng.randf_range(2.0, 4.5), 0.32, Color(0.36, 0.3, 0.22), 1.8, 1.6, 0.85, t)
			for k in 10:
				puff(hit_at + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0, 1), rng.randf_range(-0.6, 0.6)),
					Vector3(0, 1.2, 0), 0.6, Color(0.12, 0.11, 0.1), 3.0, 1.2, 0.85, t)
		var on := t >= t0 + 0.05
		light.visible = on
		for f: Dictionary in fl_nodes:
			(f["m"] as MeshInstance3D).visible = on
		if not on:
			return
		var age := t - t0
		# Starts small, grows over two seconds, dies down to a smoulder after eight.
		var strength := clampf(1.0 - (age - 8.0) / 3.0, 0.2, 1.0)
		var grow := clampf(age / 2.5, 0.15, 1.0)
		for f: Dictionary in fl_nodes:
			var m: MeshInstance3D = f["m"]
			var i: int = f["i"]
			var fk := 0.75 + 0.25 * sin(t * (11.0 + i * 1.7) + f["k"] * 2.1) + 0.12 * sin(t * 23.0 + i)
			m.scale = Vector3(1.0, 1.4 + 0.5 * sin(t * 9.0 + i), 1.0) * fk * grow * strength * (1.0 if i < 3 else 0.75)
			m.position = f["base"] + Vector3(0, 0.12 * sin(t * 7.0 + i), 0)
		light.light_energy = (2.4 + 0.8 * sin(t * 17.0) + 0.5 * sin(t * 31.0)) * strength * grow
		if frame % (2 if strength > 0.6 else 5) == 0:
			var src: Vector3 = wn.body.global_transform * (flames[frame % flames.size()] as Vector3)
			var c := Color(0.1, 0.09, 0.08) if strength > 0.6 else Color(0.3, 0.29, 0.28)
			puff(src + Vector3(0, 0.5, 0), Vector3(0.3, 1.5, 0.1), 0.45, c, 3.4, 1.0, (0.7 * strength + 0.15) * maxf(grow, 0.5), t)


# ---------------------------------------------------------------- crew

func crew_man(seed_value: int, at: Vector3, yaw: float) -> Dictionary:
	var a := _man(seed_value, "gunner")
	a["pos"] = at
	a["yaw"] = yaw
	return a


func show_between(a: Dictionary, t_show: float, t_hide := INF) -> void:
	crew_vis.append({"a": a, "show": t_show, "hide": t_hide})


func _eval_actor(a: Dictionary, t: float) -> void:
	super._eval_actor(a, t)
	for cv: Dictionary in crew_vis:
		if cv["a"] == a:
			(a["s"] as Soldier).visible = t >= float(cv["show"]) and t < float(cv["hide"])


static func yaw_to(f: Vector3) -> float:
	return atan2(-f.x, -f.z)


## The heavy's sponson door on side s, in world space: {c_floor, c_ground, out, along}.
func door_frame(n: Tank, s: int) -> Dictionary:
	var h := n.bw(TB.H_DOOR_HINGE * Vector3(s, 1, 1))
	var e := n.bw(TB.H_DOOR_END * Vector3(s, 1, 1))
	var along := (e - h)
	along.y = 0.0
	along = along.normalized()
	var out := Vector3(along.z, 0, -along.x)
	var hint := n.global_transform.basis * Vector3(s * 0.6, 0, 1.0)
	if out.dot(hint) < 0.0:
		out = -out
	var c := (h + e) * 0.5
	c.y = n.bw(Vector3(0, TB.H_SPON_FLOOR, 0)).y
	var cg := c
	cg.y = ground_h(c)
	return {"c_floor": c, "c_ground": cg, "out": out, "along": along}


## A man climbs in through a sponson door from where he stands, then is hidden. Returns the time he is in.
func climb_in_door(a: Dictionary, n: Tank, s: int, t0: float) -> float:
	var df := door_frame(n, s)
	var out: Vector3 = df["out"]
	var cg: Vector3 = df["c_ground"]
	var cf: Vector3 = df["c_floor"]
	var al: Vector3 = df["along"]
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var t := move(a, t0, cg + out * 0.55, walk, yaw_to(-out))
	pose(a, t, 0.3, C.standing("free"), null, "prev", "smooth", null, yaw_to(-out))
	var jambs := func(_t: float) -> Dictionary:
		return {"hand_r": cf + al * 0.22 + Vector3(0, 0.55, 0) - out * 0.02, "hand_l": cf - al * 0.22 + Vector3(0, 0.55, 0) - out * 0.02}
	pose(a, t + 0.3, 0.4, V.climb(1, 0.0, TB.H_SPON_FLOOR), jambs)
	shift(a, t + 0.75, 0.45, V.climb(2, 0.0, TB.H_SPON_FLOOR), cf + out * 0.05, 0.0, jambs)
	shift(a, t + 1.25, 0.45, V.stooped(), cf - out * 0.55, 0.0)
	show_between(a, -1.0, t + 1.6)
	return t + 1.6


## A man bails out of a sponson door (appearing in it at t0), lands, runs to spot and drops.
func bail_door(a: Dictionary, n: Tank, s: int, t0: float, spot: Vector3, prone := false) -> void:
	var df := door_frame(n, s)
	var out: Vector3 = df["out"]
	var cf: Vector3 = df["c_floor"]
	var cg: Vector3 = df["c_ground"]
	a["pos"] = cf - out * 0.35
	a["yaw"] = yaw_to(out)
	pose(a, 0.0, 0.0, V.crouch(), null, null, "smooth", cf - out * 0.35, yaw_to(out))
	show_between(a, t0)
	shift(a, t0, 0.3, V.crouch(), cf + out * 0.02, 0.0, null, "smooth", yaw_to(out))
	shift(a, t0 + 0.32, 0.3, V.airborne(), cg + out * 0.9, 0.25, null, "lin", yaw_to(out))
	pose(a, t0 + 0.62, 0.12, V.crouch(1.0), null, "prev", "out")
	_run_off(a, t0 + 0.8, spot, prone)


func _run_off(a: Dictionary, t0: float, spot: Vector3, prone: bool) -> void:
	var run := Body.gait(Body.RUN, C.carry("free"))
	pose(a, t0, 0.25, run["keys"][0][1])
	var d: Vector3 = spot - (a["pos"] as Vector3)
	var t1 := move(a, t0 + 0.25, spot, run)
	if prone:
		pose(a, t1, 0.6, Body.pose("prone", C.carry("free")))
	else:
		pose(a, t1, 0.45, Body.pose("kneel", C.carry("free")), null, "prev", "smooth", null, yaw_to(-d))


# ---------------------------------------------------------------- gallery (stills)

const GALLERY := [["heavy_male", 0, false], ["heavy_female", 0, false], ["heavy_male", 1, false], ["heavy_male", 2, false],
	["heavy_male", 0, true], ["light_gun", 0, false], ["light_mg", 0, false], ["light_gun", 1, false], ["light_gun", 2, false],
	["light_gun", 0, true]]


func _gallery_wreck_pose(d: Dictionary) -> void:
	var n: Tank = d["node"]
	if n.heavy:
		n.body.transform = Transform3D(Basis(Vector3.BACK, -0.04) * Basis(Vector3.RIGHT, 0.02), Vector3(0, -0.12, 0))
		n.set_sponson(-1, 0.5, -14.0)
		n.set_sponson(1, -0.2, 6.0)
		n.set_hatch("roof", 1.0)
		n.set_hatch("door_l", 0.8)
		n.set_hatch("door_r", 1.0)
		n._tail(ground_h)
		n.tail.rotation.z = 0.12
	else:
		n.body.transform = Transform3D(Basis(Vector3.BACK, 0.05) * Basis(Vector3.RIGHT, -0.03), Vector3(0, -0.08, 0))
		n.set_turret(0.7)
		n.set_elev(-9.0)
		n.set_hatch("cupola", 1.0)
		n.set_hatch("driver", 1.0)


func _scene_gallery() -> float:
	var info := []
	for i in GALLERY.size():
		var g: Array = GALLERY[i]
		var d := tank(g[0], Vector3(18.0 * (i - 4.5), 0, 0), 0.0, null, null, g[1], g[2])
		d["engine"] = false
		d["run"] = false
		if g[2]:
			_gallery_wreck_pose(d)
		info.append((d["node"] as Tank).tri_count())
	var names := ["Heavy tank (gun)", "Heavy tank (MG)", "Heavy tank: mid look", "Heavy tank: far look", "Heavy tank: wreck",
		"Light tank (gun)", "Light tank (MG)", "Light tank: mid look", "Light tank: far look", "Light tank: wreck"]
	_phases = []
	for i in GALLERY.size():
		_phases.append([2.0 * i, "%s, %d triangles: front" % [names[i], info[i]]])
		_phases.append([2.0 * i + 1.0, "%s, %d triangles: back" % [names[i], info[i]]])
	print("GALLERY TRIS ", info)
	_camera = func(t: float) -> void:
		var i := clampi(int(t / 2.0), 0, GALLERY.size() - 1)
		var back := fmod(t, 2.0) >= 1.0
		var heavy := TB.is_heavy(GALLERY[i][0])
		var c := Vector3(18.0 * (i - 4.5), 0, 0)
		var dist := 13.5 if heavy else 7.5
		var far_lod: int = GALLERY[i][1]
		cam.fov = 40.0
		var dir := Vector3(-0.75, 0.42, -0.62) if not back else Vector3(0.7, 0.45, 0.68)
		cam.transform = Transform3D(Basis(), c + dir.normalized() * dist).looking_at(c + Vector3(0, 1.2 if heavy else 0.8, 0), Vector3.UP)
		if far_lod > 0:
			cam.fov = 40.0
	return 2.0 * GALLERY.size()


# ---------------------------------------------------------------- looks

func _look(kinds: Array, gap: float, cam_at: Vector3, look_y: float, label: String, hatch_names: Array) -> float:
	var info := []
	for i in kinds.size():
		var r: Array = kinds[i]
		var x := (float(i) - (kinds.size() - 1) * 0.5) * gap
		var d := tank(r[0], Vector3(x, 0, 0), 0.0, null, null, r[1], r[2])
		d["engine"] = false
		d["run"] = false
		if r[2]:
			_gallery_wreck_pose(d)
		else:
			var hn: Array = hatch_names
			d["parts"] = func(t: float, n: Tank) -> void:
				var o := clampf((t - 7.0) / 0.8, 0.0, 1.0) - clampf((t - 10.0) / 0.8, 0.0, 1.0)
				for h: String in hn:
					n.set_hatch(h, o)
				if not n.heavy:
					n.set_turret(sin(clampf((t - 3.0) / 3.0, 0.0, 1.0) * PI) * 1.2)
		info.append("%s %d" % [r[3], (d["node"] as Tank).tri_count()])
	_phases = [[0.0, label + " (triangles: " + ", ".join(info) + ")"], [7.0, "Hatches and doors open"], [10.0, label]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		for d: Dictionary in tanks:
			(d["node"] as Node3D).rotation.y = 0.6 + t * 0.3
		cam.transform = Transform3D(Basis(), cam_at).looking_at(Vector3(0, look_y, 0), Vector3.UP)
	return 12.0


func _scene_look_heavy() -> float:
	return _look([["heavy_male", 0, false, "gun close"], ["heavy_female", 0, false, "MG close"], ["heavy_male", 1, false, "mid"],
		["heavy_male", 2, false, "far"]], 11.5, Vector3(0, 8.0, -27.0), 1.0, "Heavy tank: gun and MG versions, mid and far looks",
		["roof", "door_l", "door_r"])


func _scene_look_light() -> float:
	return _look([["light_gun", 0, false, "gun close"], ["light_mg", 0, false, "MG close"], ["light_gun", 1, false, "mid"],
		["light_gun", 2, false, "far"], ["light_gun", 0, true, "wreck"]], 6.0, Vector3(0, 8.0, -18.5), 0.6,
		"Light tank: gun and MG versions, mid and far looks, the wreck", ["cupola", "driver"])


# ---------------------------------------------------------------- drive

func _scene_drive() -> float:
	var hv := prof([[0.0, 0.0], [1.5, 1.6], [10.0, 1.6], [11.5, 0.0]])
	var hw := prof([[0.0, 0.0], [11.5, 0.0], [12.3, 0.32], [16.2, 0.32], [17.0, 0.0]])
	var lv := prof([[0.0, 0.0], [1.0, 2.5], [9.0, 2.5], [10.0, 0.0]])
	var lw := prof([[0.0, 0.0], [10.0, 0.0], [10.6, -0.55], [13.3, -0.55], [13.9, 0.0]])
	var h := tank("heavy_male", Vector3(-3.5, 0, 0), 0.0, hv, hw)
	var l := tank("light_gun", Vector3(4.0, 0, 2.0), 0.0, lv, lw)
	h["parts"] = func(t: float, n: Tank) -> void: recoils(h, t)
	l["parts"] = func(t: float, n: Tank) -> void: n.set_turret(0.35 * sin(t * 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 9:
		mound(Vector3(-3.5 + (1.3 if k % 2 == 0 else -1.2), 0, -4.0 - 2.3 * k), rng.randf_range(0.9, 1.3), rng.randf_range(0.2, 0.38))
	for k in 9:
		mound(Vector3(4.0 + (0.7 if k % 2 == 0 else -0.6), 0, -3.0 - 2.6 * k), rng.randf_range(0.5, 0.8), rng.randf_range(0.12, 0.24))
	_phases = [[0.0, "Driving over rough ground: tracks run, the hull pitches and rocks"], [10.0, "Turning on the spot: one track forward, one back"]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		var hp: Vector3 = (h["node"] as Node3D).position
		var lp: Vector3 = (l["node"] as Node3D).position
		var mid := (hp + lp) * 0.5
		var off := Vector3(14.0, 6.5, -6.0) if t < 10.0 else Vector3(9.0, 9.0, 9.0)
		cam.transform = Transform3D(Basis(), mid + off).looking_at(mid + Vector3(0, 1.0, 0), Vector3.UP)
	return 17.5


# ---------------------------------------------------------------- ramp

static func ramp_h(x: float, z: float) -> float:
	# A 3 m terrace ahead (z < -14) with a ramp down to the base level (z > -4) between
	# x = -9 and 9; outside the ramp the terrace ends in a cliff at z = -14.
	var on_ramp := absf(x) < 9.0
	var r := clampf((-4.0 - z) / 10.0, 0.0, 1.0)
	var ramp := 3.0 * r
	var cliff := 3.0 if z < -14.0 else 0.0
	if not on_ramp:
		var edge := clampf((absf(x) - 9.0) / 0.6, 0.0, 1.0)
		return lerpf(ramp, cliff, edge)
	return ramp


func _scene_ramp() -> float:
	lay_terrain(ramp_h, -24.0, 24.0, -40.0, 14.0, 0.4)
	var hv := prof([[0.0, 0.0], [1.5, 1.5], [17.0, 1.5], [18.0, 0.0]])
	var lv := prof([[0.0, 0.0], [1.0, 2.0], [14.0, 2.0], [15.0, 0.0]])
	var h := tank("heavy_female", Vector3(-3.5, 0, 6.0), 0.0, hv)
	var l := tank("light_mg", Vector3(4.0, 0, 4.0), 0.0, lv)
	_phases = [[0.0, "Up a ramp onto a terrace (no cliffs: like trucks, ramps only)"], [12.0, "Over the top"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		var hp: Vector3 = (h["node"] as Node3D).position
		var at := Vector3(0, 1.5, hp.z - 2.0)
		cam.transform = Transform3D(Basis(), Vector3(20.0, 7.5, hp.z + 4.0)).looking_at(at, Vector3.UP)
	return 19.0


# ---------------------------------------------------------------- trench

static func trench_h(x: float, z: float) -> float:
	# A trench across the field at z = -10: 3.6 m wide in the heavy's lane (x < 1), 1.5 m in the
	# light's lane, about 1.9 m deep, with an earth parapet on each lip.
	var wide := 1.0 - clampf((x - 0.0) / 2.0, 0.0, 1.0)
	var half := lerpf(0.75, 1.8, wide)
	var dz := absf(z + 10.0)
	var depth := 1.9 if dz < half - 0.25 else (1.9 * (half - dz) / 0.25 if dz < half else 0.0)
	var par := 0.0
	var pd := dz - (half + 0.75)
	if absf(pd) < 0.9:
		par = 0.5 * (1.0 - (pd / 0.9) * (pd / 0.9))
	return par - maxf(depth, 0.0)


func _scene_trench() -> float:
	lay_terrain(trench_h, -20.0, 20.0, -34.0, 16.0, 0.2)
	var hv := prof([[0.0, 0.0], [1.2, 1.3]])
	var lv := prof([[0.0, 0.0], [9.0, 0.0], [9.8, 2.0]])
	var h := tank("heavy_male", Vector3(-3.0, 0, 1.0), 0.0, hv)
	var l := tank("light_gun", Vector3(3.5, 0, 9.0), 0.0, lv)
	_phases = [[0.0, "Crossing a 3.6 m trench: up the parapet, nose down, climbing out"], [13.0, "The light tank takes a 1.5 m one"]]
	_camera = func(t: float) -> void:
		cam.fov = 42.0
		var hz: float = (h["node"] as Node3D).position.z
		var lz: float = (l["node"] as Node3D).position.z
		var u := Anim.ease_of(clampf((t - 11.5) / 2.0, 0.0, 1.0), "smooth")
		var z := lerpf(clampf(hz, -12.0, 0.0), clampf(lz, -12.0, 0.0), u)
		var x := lerpf(-3.0, 3.5, u)
		cam.transform = Transform3D(Basis(), Vector3(x + 15.0 - 5.0 * u, 3.6, z + 3.0)).looking_at(Vector3(x, 0.4, z - 1.5), Vector3.UP)
	return 21.0


# ---------------------------------------------------------------- fire

func _scene_fire_heavy() -> float:
	var m := tank("heavy_male", Vector3(-6.5, 0, 0), 0.0)
	var f := tank("heavy_female", Vector3(6.5, 0, 0), 0.0)
	var ms := [[2.0, -1], [3.6, 1], [5.6, -1], [7.0, 1], [9.4, -1], [10.4, 1]]
	for s: Array in ms:
		shot(m, s[1], s[0])
	burst(m, 2, 6.0, 8.2)
	for b: Array in [[2.2, 4.0, -1], [2.6, 4.6, 1], [6.0, 8.4, -1], [6.4, 8.0, 1], [9.6, 11.4, -1], [9.8, 11.6, 1]]:
		burst(f, b[2], b[0], b[1])
	burst(f, 2, 4.8, 6.0)
	var trav := func(t: float, side: int) -> float:
		return 0.15 + 0.45 * (0.5 - 0.5 * cos(t * 0.7 + (0.0 if side < 0 else 1.3)))
	m["parts"] = func(t: float, n: Tank) -> void:
		n.set_sponson(-1, trav.call(t, -1), 2.0)
		n.set_sponson(1, trav.call(t, 1), 2.0)
		recoils(m, t)
	f["parts"] = func(t: float, n: Tank) -> void:
		n.set_sponson(-1, trav.call(t + 1.0, -1) + 0.1 * sin(t * 6.0), 0.0)
		n.set_sponson(1, trav.call(t + 1.0, 1) + 0.1 * sin(t * 5.3), 0.0)
	_phases = [[0.0, "Heavy tank, gun version: sponson guns traverse and fire"], [6.0, "MG version: sponson MGs and the front MG"]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		var u := 0.0 if t < 6.0 else 1.0
		var at := Vector3(-6.5, 1.3, -0.5).lerp(Vector3(6.5, 1.3, -0.5), u)
		var off := Vector3(-8.5, 4.2, -9.5).lerp(Vector3(8.5, 4.2, -9.5), u)
		cam.transform = Transform3D(Basis(), at + off).looking_at(at, Vector3.UP)
	return 13.0


func _scene_fire_light() -> float:
	var g := tank("light_gun", Vector3(-3.0, 0, 0), 0.0)
	var mgt := tank("light_mg", Vector3(3.0, 0, 0), 0.0)
	var gyaw := prof([[0.0, 0.0], [1.5, 0.0], [3.0, 0.6], [6.0, 0.6], [7.5, -0.5], [12.0, -0.5]])
	var gel := prof([[0.0, 0.0], [1.5, 0.0], [3.0, 6.0], [6.0, 6.0], [7.5, 2.0]])
	for t0 in [3.6, 4.8, 8.2, 9.4, 10.6]:
		shot(g, 0, t0)
	g["parts"] = func(t: float, n: Tank) -> void:
		n.set_turret(gyaw.call(t))
		n.set_elev(gel.call(t))
		recoils(g, t)
	var myaw := func(t: float) -> float: return 0.35 * sin(t * 0.55) - 0.1
	for b: Array in [[2.0, 3.6], [4.4, 6.2], [7.0, 8.0], [8.6, 10.8]]:
		burst(mgt, 0, b[0], b[1])
	mgt["parts"] = func(t: float, n: Tank) -> void:
		n.set_turret(myaw.call(t) + (0.04 * sin(t * 9.0) if fmod(t, 2.4) < 1.6 else 0.0))
		n.set_elev(2.0 + 1.0 * sin(t * 1.3))
	_phases = [[0.0, "Light tanks: the turret turns and the gun lays"], [3.6, "Firing: recoil, flash, smoke; the MG sweeps"]]
	_camera = func(t: float) -> void:
		cam.fov = 44.0
		cam.transform = Transform3D(Basis(), Vector3(6.5, 3.4, -8.5)).looking_at(Vector3(-0.5, 1.1, -0.5), Vector3.UP)
	return 12.0


# ---------------------------------------------------------------- crew in

func _scene_crew() -> float:
	var go := 15.5
	var hv := prof([[0.0, 0.0], [go, 0.0], [go + 1.5, 1.4]])
	var lv := prof([[0.0, 0.0], [go + 0.5, 0.0], [go + 1.5, 2.2]])
	var h := tank("heavy_female", Vector3(-3.0, 0, 0), 0.0, hv)
	var l := tank("light_gun", Vector3(6.0, 0, -1.0), 0.0, lv)
	var hn: Tank = h["node"]
	var ln: Tank = l["node"]
	h["engine"] = false
	l["engine"] = false
	var door_t := {-1: 12.0, 1: 12.4}
	h["parts"] = func(t: float, n: Tank) -> void:
		var o := clampf((t - 0.5) / 0.6, 0.0, 1.0)
		n.set_hatch("door_l", o - clampf((t - door_t[-1]) / 0.6, 0.0, 1.0))
		n.set_hatch("door_r", o - clampf((t - door_t[1]) / 0.6, 0.0, 1.0))
		h["engine"] = t >= 13.0
		h["rev"] = 1.0 if t > 13.0 and t < 14.2 else 0.0
	# Eight men, four to each door.
	for i in 8:
		var s := -1 if i % 2 == 0 else 1
		var k := i / 2
		var df := door_frame(hn, s)
		var start: Vector3 = (df["c_ground"] as Vector3) + (df["out"] as Vector3) * (3.0 + 1.1 * k) + Vector3(0.4 * s, 0, 0.6 * k)
		var a := crew_man(301 + i, start, yaw_to(-(df["out"] as Vector3)))
		pose(a, 0.0, 0.0, C.standing("free"), null, null)
		climb_in_door(a, hn, s, 1.0 + 2.3 * k)
	# The light tank's two: the driver in at the front hatch, the commander up the back and into the turret.
	var dpos := ln.bw(Vector3(0, 0, -2.75))
	dpos.y = 0.0
	var drv := crew_man(321, dpos + Vector3(-1.5, 0, -2.5), 0.0)
	pose(drv, 0.0, 0.0, C.standing("free"), null, null)
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var fwd := -ln.global_transform.basis.z
	var t1 := move(drv, 1.5, dpos, walk, yaw_to(-fwd))
	var nose := func(_t: float) -> Dictionary:
		return {"hand_r": ln.bw(Vector3(0.25, 1.0, -1.98)), "hand_l": ln.bw(Vector3(-0.25, 1.0, -1.98))}
	pose(drv, t1, 0.4, V.climb(0, 0.62, 0.95), nose)
	shift(drv, t1 + 0.45, 0.45, V.climb(1, 0.62, 0.95), ln.bw(Vector3(0, 0.62, -2.3)), 0.0, nose)
	shift(drv, t1 + 0.95, 0.5, V.climb(2, 0.62, 0.95), ln.bw(Vector3(0, 0.95, -1.95)), 0.0)
	shift(drv, t1 + 1.5, 0.5, V.stooped(), ln.bw(Vector3(0, 1.15, -1.75)), 0.0)
	shift(drv, t1 + 2.1, 0.9, C.standing("free"), ln.bw(Vector3(0, -0.4, -1.5)), 0.0)
	show_between(drv, -1.0, t1 + 3.0)
	var cmd := crew_man(322, ln.bw(Vector3(1.8, 0, 4.6)) * Vector3(1, 0, 1), PI)
	pose(cmd, 0.0, 0.0, C.standing("free"), null, null)
	var back := ln.bw(Vector3(0, 0, 3.55)) * Vector3(1, 0, 1)
	var t2 := move(cmd, 2.5, back, walk, yaw_to(fwd))
	var deck := func(_t: float) -> Dictionary:
		return {"hand_r": ln.bw(Vector3(-0.3, 1.25, 1.95)), "hand_l": ln.bw(Vector3(0.3, 1.25, 1.95))}
	pose(cmd, t2, 0.4, V.climb(0, 0.45, 1.2), deck)
	shift(cmd, t2 + 0.45, 0.45, V.climb(1, 0.45, 1.2), ln.bw(Vector3(0, 0.45, 2.95)), 0.0, deck)
	shift(cmd, t2 + 0.95, 0.5, V.climb(2, 0.45, 1.2), ln.bw(Vector3(0, 1.2, 1.9)), 0.0)
	shift(cmd, t2 + 1.5, 0.5, V.stooped(), ln.bw(Vector3(0, 1.4, 0.75)), 0.0, null, "smooth", yaw_to(fwd))
	shift(cmd, t2 + 2.1, 0.5, C.standing("free"), ln.bw(Vector3(0, 2.2, -0.45)), 0.25)
	shift(cmd, t2 + 2.7, 1.1, C.standing("free"), ln.bw(Vector3(0, 0.75, -0.45)), 0.0)
	show_between(cmd, -1.0, t2 + 3.9)
	l["parts"] = func(t: float, n: Tank) -> void:
		n.set_hatch("driver", clampf((t - 1.0) / 0.6, 0.0, 1.0) - clampf((t - (t1 + 3.1)) / 0.5, 0.0, 1.0))
		n.set_hatch("cupola", clampf((t - 1.0) / 0.6, 0.0, 1.0) - clampf((t - (t2 + 4.0)) / 0.5, 0.0, 1.0))
		l["engine"] = t >= 13.6
		l["rev"] = 1.0 if t > 13.6 and t < 14.6 else 0.0
	_phases = [[0.0, "Crew in: eight through the heavy's sponson doors, two through the light tank's hatches"],
		[12.0, "Doors shut, engines start"], [go, "Moving off"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		cam.transform = Transform3D(Basis(), Vector3(9.5, 5.0, 10.5)).looking_at(Vector3(1.2, 0.9, -0.5), Vector3.UP)
	return 21.0


# ---------------------------------------------------------------- wrecks

func _scene_wreck_heavy() -> float:
	var hit := 3.0
	var hv := prof([[0.0, 1.3], [2.2, 1.3], [2.9, 0.0]])
	var live := tank("heavy_male", Vector3(0, 0, 3.6), 0.0, hv)
	live["parts"] = func(t: float, n: Tank) -> void:
		n.set_sponson(-1, 0.3, 0.0)
		n.set_sponson(1, 0.3, 0.0)
	var wk := tank("heavy_male", Vector3.ZERO, 0.0, null, null, 0, true)
	var wn: Tank = wk["node"]
	_gallery_wreck_pose(wk)
	wn.visible = false
	wk["parts"] = func(t: float, n: Tank) -> void:
		var u := t - hit
		n.set_hatch("door_l", clampf((u - 0.8) / 0.4, 0.0, 1.0) * 0.85)
		n.set_hatch("door_r", clampf((u - 0.6) / 0.4, 0.0, 1.0))
		n.set_hatch("roof", clampf((u - 1.6) / 0.4, 0.0, 1.0))
	var fx := burn(wn, [Vector3(0, 2.5, 1.2), Vector3(0, 2.6, -2.6), Vector3(-1.9, 1.95, 0.0), Vector3(0.4, 2.4, 2.6),
		Vector3(-1.4, 1.2, -0.6)], hit, Vector3(-2.0, 1.2, -0.6), Vector3(0, 3.0, 0.0))
	# Six bail out: three from each door, the commander from the roof hatch; one stays inside.
	var spots := [Vector3(-7.5, 0, 4.0), Vector3(-6.0, 0, 7.5), Vector3(-9.0, 0, 1.0), Vector3(7.0, 0, 5.5), Vector3(8.5, 0, 2.0),
		Vector3(6.0, 0, 8.5)]
	var starts := [hit + 1.2, hit + 2.0, hit + 2.9, hit + 1.0, hit + 1.8, hit + 2.7]
	for i in 6:
		var s := -1 if i < 3 else 1
		var a := crew_man(331 + i, Vector3.ZERO, 0.0)
		bail_door(a, wn, s, starts[i], spots[i], i % 3 == 1)
	var c := crew_man(340, wn.bw(Vector3(0, TB.H_ROOF - 1.7, TB.H_ROOF_HATCH.z - 0.36)), PI)
	pose(c, 0.0, 0.0, C.standing("free"), null, null)
	show_between(c, hit + 1.9)
	var tr := hit + 2.0
	shift(c, tr, 0.6, C.standing("free"), wn.bw(Vector3(0, TB.H_ROOF - 0.85, TB.H_ROOF_HATCH.z - 0.36)), 0.0)
	shift(c, tr + 0.7, 0.55, V.crouch(), wn.bw(Vector3(0.55, TB.H_ROOF, 0.3)), 0.35, null, "smooth", PI * 0.5 + PI)
	shift(c, tr + 1.35, 0.35, V.airborne(), wn.bw(Vector3(2.0, 1.95, 0.0)), 0.3, null, "lin")
	pose(c, tr + 1.7, 0.15, V.crouch(1.0), null, "prev", "out")
	shift(c, tr + 1.95, 0.35, V.airborne(), Vector3(wn.bw(Vector3(3.0, 0, 0.2)).x, 0.0, wn.bw(Vector3(3.0, 0, 0.2)).z), 0.35, null, "lin")
	pose(c, tr + 2.3, 0.15, V.crouch(1.0), null, "prev", "out")
	_run_off(c, tr + 2.5, Vector3(9.5, 0, -2.0), true)
	_phases = [[0.0, "Heavy tank stops"], [hit, "Hit in the side"], [hit + 0.4, "Burning: the crew bail out of the doors and the roof"],
		[hit + 9.0, "Burnt out: the wreck stays on the map"]]
	_camera = func(t: float) -> void:
		fx.call(t)
		var down := t >= hit + 0.05
		(live["node"] as Node3D).visible = not down
		live["engine"] = not down
		wn.visible = down
		cam.fov = 48.0
		cam.transform = Transform3D(Basis(), Vector3(-15.0, 6.0, 7.0 - 0.2 * t)).looking_at(Vector3(0, 1.2, 1.5), Vector3.UP)
	return 16.0


func _scene_wreck_light() -> float:
	var hit := 2.8
	var lv := prof([[0.0, 2.0], [2.0, 2.0], [2.7, 0.0]])
	var live := tank("light_gun", Vector3(0, 0, 4.0), 0.0, lv)
	var wk := tank("light_gun", Vector3.ZERO, 0.0, null, null, 0, true)
	var wn: Tank = wk["node"]
	_gallery_wreck_pose(wk)
	wn.set_hatch("cupola", 0.0)
	wn.set_hatch("driver", 0.0)
	wn.visible = false
	wk["parts"] = func(t: float, n: Tank) -> void:
		var u := t - hit
		n.set_hatch("driver", clampf((u - 0.7) / 0.35, 0.0, 1.0))
		n.set_hatch("cupola", clampf((u - 1.1) / 0.35, 0.0, 1.0))
	var fx := burn(wn, [Vector3(0, 1.6, 1.1), Vector3(0.2, 2.1, -0.45), Vector3(-0.3, 1.5, 0.3)], hit, Vector3(0.9, 1.0, -0.6),
		Vector3(0, 2.0, 0.3))
	# The driver out of the front hatch, the commander out of the cupola.
	var d := crew_man(351, wn.bw(Vector3(0, -0.2, -1.55)), 0.0)
	pose(d, 0.0, 0.0, C.standing("free"), null, null)
	show_between(d, hit + 0.8)
	var td := hit + 0.9
	shift(d, td, 0.5, C.standing("free"), wn.bw(Vector3(0, 0.55, -1.55)), 0.0)
	shift(d, td + 0.55, 0.45, V.crouch(), wn.bw(Vector3(0, 1.05, -1.85)), 0.25)
	var land := wn.bw(Vector3(-1.2, 0, -2.6))
	land.y = 0.0
	shift(d, td + 1.05, 0.35, V.airborne(), land, 0.3, null, "lin", yaw_to(land - wn.bw(Vector3(0, 0, -1.85))))
	pose(d, td + 1.4, 0.15, V.crouch(1.0), null, "prev", "out")
	_run_off(d, td + 1.6, Vector3(-6.0, 0, -3.0), false)
	var c := crew_man(352, wn.bw(Vector3(0, 0.3, -0.45)), PI)
	pose(c, 0.0, 0.0, C.standing("free"), null, null)
	show_between(c, hit + 1.2)
	var tc := hit + 1.3
	shift(c, tc, 0.55, C.standing("free"), wn.bw(Vector3(0, 1.3, -0.45)), 0.0)
	shift(c, tc + 0.6, 0.5, V.crouch(), wn.bw(Vector3(0.1, 1.48, 0.7)), 0.3, null, "smooth", PI)
	var land2 := wn.bw(Vector3(1.4, 0, 1.6))
	land2.y = 0.0
	shift(c, tc + 1.15, 0.35, V.airborne(), land2, 0.3, null, "lin")
	pose(c, tc + 1.5, 0.15, V.crouch(1.0), null, "prev", "out")
	_run_off(c, tc + 1.7, Vector3(5.0, 0, -5.0), true)
	_phases = [[0.0, "Light tank stops"], [hit, "Hit"], [hit + 0.4, "Burning: the crew get out of the hatches"],
		[hit + 8.5, "Burnt out: the wreck stays on the map"]]
	_camera = func(t: float) -> void:
		fx.call(t)
		var down := t >= hit + 0.05
		(live["node"] as Node3D).visible = not down
		live["engine"] = not down
		wn.visible = down
		cam.fov = 46.0
		cam.transform = Transform3D(Basis(), Vector3(8.0 - 0.15 * t, 5.0, 9.0)).looking_at(Vector3(0, 0.9, 0.0), Vector3.UP)
	return 14.0
