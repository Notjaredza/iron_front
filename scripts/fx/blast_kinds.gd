class_name BlastKinds
extends RefCounted
## Explosion round B (Building Chat 1, 2026-11-09): blasts that are not shells. Same particles and look as the shell
## sizes (BlastSpecs), each its own shape:
##   grenade     a sharp flash, a grey-brown puff, a short spray of dirt and fast fragments
##   mine_ap     anti-person mine: a small sharp pop and a low ring of dirt thrown out flat
##   mine_at     anti-tank mine: a tall narrow jet of earth with black smoke climbing it
##   tunnel      a tunnel mine under a trench: the ground heaves up as a dome for a second, then bursts
##   demo        demolition charge (bridges, rails): a hard white flash, pale cordite smoke, wood and iron flung out
##   hit_dirt    a bullet in the dirt: a little puff and specks
##   hit_metal   a bullet on metal: a spray of sparks off the plate (nrm: the plate's outward normal)
##   flare_light a parachute light flare: up on a smoke trail, then hangs and drifts down, lighting the ground
##   flare_red / flare_green / flare_white   signal flares: up, then a short bright fall
## Returns the same dictionary as BlastSpecs.build, plus "t_flash" (when the flash comes), "crater_t" (when the
## crater is cut) and, for flares, "flare" (the path; Blast moves a bright head and the light along it).

const S := preload("res://scripts/fx/blast_specs.gd")
const G := 9.81
const KINDS: Array[String] = ["grenade", "mine_ap", "mine_at", "tunnel", "demo", "hit_dirt", "hit_metal",
	"flare_light", "flare_red", "flare_green", "flare_white"]


static func build(kind: String, at: Vector3, seed_value: int, density := 1.0, nrm := Vector3.UP) -> Dictionary:
	var rng := S.rng
	rng.seed = hash(seed_value * 977 + kind.hash())
	var b := {"fire": PackedFloat32Array(), "smoke": PackedFloat32Array(), "clods": PackedFloat32Array(),
		"sparks": PackedFloat32Array(), "fire_life": 0.3, "fire_h": 0.5, "glow_r": 2.0, "flash": 0.0,
		"light_range": 10.0, "ember": 0.0, "ember_t": 1.0, "crater_r": 0.0, "crater_d": 0.0, "reach": 20.0,
		"top": 10.0, "total": 3.0, "shake": 0.0, "t_flash": 0.0, "crater_t": 0.05}
	var n := func(x: float) -> int: return maxi(int(x * density), 2)
	match kind:
		"grenade":
			_fire(b, at, n.call(8), 0.9, 0.16, 0.0)
			_jet(b, at, n.call(16), 4.5, 0.0, 9.0, 0.5)
			_puff(b, at, n.call(16), 1.7, 6.0, 0.08, Color(0.5, 0.47, 0.42), 1.0)
			_clods(b, at, n.call(45), 0.16, 9.0, 4.5, 0.0, 0.1)
			_sparks(b, at + Vector3(0, 0.3, 0), n.call(36), 22.0, 0.35, 0.03, 0.18, nrm, 0.0)
			b.merge({"flash": 6.0, "light_range": 12.0, "fire_h": 0.5, "glow_r": 2.4, "fire_life": 0.16,
				"crater_r": 0.75, "crater_d": 0.25, "shake": 0.06, "ember": 0.2, "ember_t": 1.5}, true)
		"mine_ap":
			_fire(b, at, n.call(6), 0.7, 0.12, 0.0)
			# The ring: dirt thrown out low and flat, not up.
			for i in n.call(26):
				var d := S._disc().normalized()
				var p0 := at + Vector3(0, 0.2, 0)
				var target := at + d * rng.randf_range(1.6, 3.8) + Vector3(0, rng.randf_range(0.1, 0.5), 0)
				var s1 := rng.randf_range(0.22, 0.42)
				S._add(b["smoke"], p0, (target - p0) * 3.6, rng.randf_range(0.0, 0.05), rng.randf_range(0.7, 1.5), 3.6,
					0.0, s1 * 0.3, s1, S._dust(), rng.randf_range(-1, 1), 0.1, 0.5)
			_jet(b, at, n.call(10), 3.0, 0.0, 12.0, 0.4)
			_puff(b, at, n.call(10), 1.3, 5.0, 0.06, Color(0.46, 0.43, 0.38), 1.0)
			_clods(b, at, n.call(55), 0.14, 11.0, 2.0, 0.0, 0.05)
			_sparks(b, at + Vector3(0, 0.2, 0), n.call(20), 18.0, 0.3, 0.025, 0.14, nrm, 0.25)
			b.merge({"flash": 4.5, "light_range": 9.0, "fire_h": 0.3, "glow_r": 1.8, "fire_life": 0.12,
				"crater_r": 0.9, "crater_d": 0.35, "shake": 0.05}, true)
		"mine_at":
			_fire(b, at, n.call(14), 2.4, 0.32, 0.0)
			_jet(b, at, n.call(110), 24.0, 0.0, 4.0, 1.0)            # one tight jet, tall
			# Black smoke climbing the jet.
			for i in n.call(44):
				var hf := pow(rng.randf(), 0.7)
				var p0 := at + Vector3(0, 1.0, 0) + S._ball() * 1.2
				var target := at + S._disc() * (1.0 + hf * 2.5) + Vector3(0, 2.0 + hf * 15.0, 0)
				var s1 := rng.randf_range(1.2, 2.6) * (0.7 + hf * 0.5)
				var v := rng.randf_range(-0.02, 0.03)
				S._add(b["smoke"], p0, (target - p0) * 1.1, rng.randf_range(0.1, 0.8), rng.randf_range(10.0, 16.0), 1.1,
					0.5, s1 * 0.3, s1, Color(0.16 + v, 0.15 + v, 0.14 + v), rng.randf_range(-0.3, 0.3), 0.6, 1.0)
			_clods(b, at, n.call(240), 0.6, 26.0, 18.0, 0.18, 0.15)
			_sparks(b, at + Vector3(0, 0.6, 0), n.call(40), 26.0, 0.9, 0.06, 0.3, nrm, 0.4)
			b.merge({"flash": 12.0, "light_range": 30.0, "fire_h": 1.4, "glow_r": 6.0, "fire_life": 0.32,
				"crater_r": 2.6, "crater_d": 1.2, "shake": 0.35, "ember": 0.6, "ember_t": 4.0, "top": 40.0,
				"reach": 50.0, "total": 40.0}, true)
		"tunnel":
			var burst := 1.05
			# The heave: the ground swells into a dome of earth for a second before it breaks.
			for i in n.call(130):
				var d := S._hemi(0.0)
				var p0 := at + Vector3(d.x * 16.0, 0.4, d.z * 16.0) * rng.randf_range(0.2, 1.0)
				var target := at + Vector3(d.x * 20.0, d.y * 14.0 + 1.0, d.z * 20.0) * rng.randf_range(0.8, 1.05)
				var s1 := rng.randf_range(2.4, 4.2)
				S._add(b["smoke"], p0, (target - p0) * 1.4, rng.randf_range(0.0, 0.15), burst + rng.randf_range(0.2, 0.6),
					1.4, 0.0, s1 * 0.6, s1, S._earth(0.03), rng.randf_range(-0.1, 0.1), 0.2, 0.2)
			# The burst: the dome tears open, a wide fan of earth jets, a lingering brown cloud.
			for i in n.call(260):
				var a := deg_to_rad(rng.randf_range(0.0, 30.0))
				var d := S._disc().normalized()
				var hf := pow(rng.randf(), 0.6)
				var p0 := at + Vector3(0, 4.0, 0) + S._disc() * 8.0
				var target := at + (d * sin(a) + Vector3(0, cos(a), 0)) * (85.0 * hf + 6.0) + S._ball() * 5.0
				var k := 2.2
				var s1 := rng.randf_range(2.2, 5.0) * (1.2 - hf * 0.4)
				S._add(b["smoke"], p0, (target - p0) * k, burst + rng.randf_range(0.0, 0.2), rng.randf_range(5.0, 11.0), k,
					-1.6 * k, s1 * 0.4, s1, S._earth(0.0), rng.randf_range(-0.6, 0.6), 0.45, 0.4)
			for i in n.call(150):
				var p0 := at + Vector3(0, 6.0, 0) + S._ball() * 10.0
				var off := S._ball() * 26.0
				var target := at + Vector3(off.x * 1.4, maxf(off.y + 22.0, 8.0), off.z * 1.4)
				var s1 := rng.randf_range(4.0, 8.0)
				var c := S._earth(-0.06)
				S._add(b["smoke"], p0, (target - p0) * 0.7, burst + rng.randf_range(0.3, 2.5), rng.randf_range(22.0, 40.0),
					0.7, 0.3, s1 * 0.3, s1, Color(c.r, c.g, c.b, 1.0), rng.randf_range(-0.2, 0.2), 0.7, 1.0)
			var fb: PackedFloat32Array = b["fire"]
			for i in n.call(30):
				var d := S._hemi(0.2)
				var p0 := at + Vector3(0, 3.0, 0)
				var target := at + d * rng.randf_range(4.0, 10.0) + Vector3(0, 6.0, 0)
				var s1 := rng.randf_range(2.0, 3.6)
				S._add(fb, p0, (target - p0) * 6.0, burst + rng.randf_range(0.0, 0.05), rng.randf_range(0.3, 0.6), 6.0,
					1.0, s1 * 0.3, s1, Color(1, 1, 1, 1), rng.randf_range(-2, 2), 0.0, rng.randf())
			_clods(b, at, n.call(900), 1.6, 60.0, 110.0, 0.0, 0.0, burst)
			for i in n.call(40):
				var csz := rng.randf_range(1.2, 3.2)
				var el := deg_to_rad(rng.randf_range(35.0, 70.0))
				var sp := sqrt(G * rng.randf_range(20.0, 70.0) / sin(2.0 * el))
				var v0 := (S._disc().normalized() * cos(el) + Vector3(0, sin(el), 0)) * sp
				var p0 := at + S._disc() * 8.0 + Vector3(0, 2.0, 0)
				var land := S._land(p0, v0, 0.01, at.y, 80.0)
				S._add(b["clods"], p0, v0, burst + rng.randf_range(0.0, 0.2), 80.0, 0.01, -G, csz, csz, S._clod_col(),
					rng.randf_range(-2, 2), land, 0.0)
			b.merge({"flash": 16.0, "light_range": 60.0, "fire_h": 6.0, "glow_r": 16.0, "fire_life": 0.6,
				"crater_r": 13.0, "crater_d": 6.0, "shake": 3.0, "t_flash": burst, "crater_t": burst + 0.6,
				"ember": 1.0, "ember_t": 3.0, "top": 120.0, "reach": 160.0, "total": 82.0}, true)
		"demo":
			_fire(b, at + Vector3(0, 0.5, 0), n.call(22), 3.4, 0.24, 0.0)
			# Cordite: pale, quick, a little yellow.
			for i in n.call(50):
				var p0 := at + Vector3(0, 1.2, 0) + S._ball() * 1.5
				var off := S._ball() * 5.5
				var target := at + Vector3(off.x, maxf(off.y + 4.5, 1.5), off.z)
				var s1 := rng.randf_range(1.4, 2.8)
				var v := rng.randf_range(-0.04, 0.03)
				S._add(b["smoke"], p0, (target - p0) * 2.6, rng.randf_range(0.04, 0.25), rng.randf_range(10.0, 18.0), 2.6,
					0.35, s1 * 0.3, s1, Color(0.6 + v, 0.58 + v, 0.52 + v), rng.randf_range(-0.4, 0.4), 0.3, 1.0)
			# Debris: wood (sleepers, planks) and iron (rail, plate), thrown flat and far; few go up.
			for i in n.call(260):
				var wood := rng.randf() < 0.6
				var csz := rng.randf_range(0.12, 0.7) * (1.0 if wood else 0.8)
				var el := deg_to_rad(rng.randf_range(8.0, 55.0))
				var sp := sqrt(G * rng.randf_range(6.0, 60.0) / sin(2.0 * el))
				var v0 := (S._disc().normalized() * cos(el) + Vector3(0, sin(el), 0)) * sp
				var p0 := at + Vector3(0, 0.8, 0) + S._ball() * 0.8
				var k := 0.05
				var land := S._land(p0, v0, k, at.y, 40.0)
				var v := rng.randf_range(-0.05, 0.05)
				var col := Color(0.46 + v, 0.33 + v, 0.20 + v, 0.0) if wood else Color(0.34 + v, 0.34 + v, 0.36 + v, 0.0)
				S._add(b["clods"], p0, v0, rng.randf_range(0.0, 0.05), 40.0, k, -G, csz, csz, col, rng.randf_range(-14, 14),
					land, 1.0 if rng.randf() < 0.12 else 0.0)
			_sparks(b, at + Vector3(0, 0.8, 0), n.call(140), 34.0, 1.2, 0.05, 0.28, nrm, 0.1)
			b.merge({"flash": 22.0, "light_range": 34.0, "fire_h": 1.4, "glow_r": 7.0, "fire_life": 0.24,
				"crater_r": 2.2, "crater_d": 0.25, "shake": 0.5, "ember": 0.4, "ember_t": 3.0, "top": 30.0,
				"reach": 80.0, "total": 41.0}, true)
		"hit_dirt":
			for i in n.call(7):
				var p0 := at + Vector3(0, 0.05, 0)
				var target := at + S._disc() * 0.3 + Vector3(0, rng.randf_range(0.3, 1.1), 0)
				var s1 := rng.randf_range(0.07, 0.16)
				S._add(b["smoke"], p0, (target - p0) * 7.0, rng.randf_range(0.0, 0.04), rng.randf_range(0.7, 1.4), 7.0,
					-0.6, s1 * 0.4, s1, S._dust(), rng.randf_range(-2, 2), 0.1, 0.3)
			_clods(b, at, n.call(7), 0.05, 2.5, 1.2, 0.0, 0.0)
			b.merge({"total": 4.0, "reach": 4.0, "top": 3.0}, true)
		"hit_metal":
			_sparks(b, at, n.call(16), 14.0, 0.25, 0.02, 0.12, nrm, 0.0, 0.25)
			_fire(b, at, 2, 0.22, 0.05, 0.0)
			b.merge({"flash": 1.6, "light_range": 4.0, "fire_h": 0.0, "glow_r": 0.6, "fire_life": 0.05,
				"total": 2.0, "reach": 6.0, "top": 6.0}, true)
		"musket", "pan", "cannon":
			_musket(b, kind, at, nrm, density)
		_:
			if kind.begins_with("flare"):
				_flare(b, kind, at, rng)
	var counts := []
	for k: String in ["fire", "smoke", "clods", "sparks"]:
		counts.append((b[k] as PackedFloat32Array).size() / S.FLOATS)
	b["counts"] = counts
	return b


## A small fireball (at ground level).
static func _fire(b: Dictionary, at: Vector3, count: int, F: float, FL: float, t0: float) -> void:
	var rng := S.rng
	for i in count:
		var d := S._hemi(-0.05)
		var reachf := F * pow(rng.randf_range(0.25, 1.0), 0.6)
		var p0 := at + Vector3(0, F * 0.12, 0)
		var target := at + d * reachf + Vector3(0, F * 0.3, 0)
		var k := clampf(4.0 / FL, 4.0, 18.0)
		var s1 := F * rng.randf_range(0.32, 0.55)
		S._add(b["fire"], p0, (target - p0) * k, t0 + rng.randf_range(0.0, 0.02), FL * rng.randf_range(0.7, 1.35), k,
			F * 0.6, s1 * 0.25, s1, Color(1, 1, 1, 1), rng.randf_range(-2, 2), 0.0, 1.0 - reachf / F)


## Earth thrown up in a jet: height H, spread (degrees off upright), size of the blobs.
static func _jet(b: Dictionary, at: Vector3, count: int, H: float, t0: float, spread: float, blob: float) -> void:
	var rng := S.rng
	for i in count:
		var hf := pow(rng.randf(), 0.6)
		var a := deg_to_rad(rng.randf_range(0.0, spread))
		var jet := S._disc().normalized() * sin(a) + Vector3(0, cos(a), 0)
		var p0 := at + Vector3(0, 0.2, 0)
		var target := at + jet * (H * hf + 0.4) + S._ball() * H * 0.03
		var k := 3.6 / sqrt(maxf(H, 2.0) / 10.0)
		var s1 := maxf(H * 0.06 * rng.randf_range(0.5, 1.2) * (1.25 - hf * 0.5), blob * 0.4)
		S._add(b["smoke"], p0, (target - p0) * k, t0 + rng.randf_range(0.0, 0.05), (0.9 + H * 0.08) * rng.randf_range(0.6, 1.3),
			k, -(0.8 + H * 0.025) * k, s1 * 0.3, s1, S._earth(0.0), rng.randf_range(-1, 1), 0.5, 0.45)


## A smoke puff of radius R lasting about L seconds.
static func _puff(b: Dictionary, at: Vector3, count: int, R: float, L: float, t0: float, col: Color, rise: float) -> void:
	var rng := S.rng
	for i in count:
		var p0 := at + Vector3(0, R * 0.4, 0) + S._ball() * R * 0.4
		var off := S._ball() * R
		var target := at + Vector3(off.x, maxf(off.y + R * rise, R * 0.3), off.z)
		var s1 := R * rng.randf_range(0.35, 0.6)
		var v := rng.randf_range(-0.03, 0.03)
		S._add(b["smoke"], p0, (target - p0) * 2.4, t0 + rng.randf_range(0.0, 0.1), L * rng.randf_range(0.6, 1.1), 2.4,
			0.3, s1 * 0.3, s1, Color(col.r + v, col.g + v, col.b + v, 1.0), rng.randf_range(-0.5, 0.5), 0.8, 1.0)


## Clods: biggest size CM, fountain height H, spray range TR, share hot, share of turf-topped.
static func _clods(b: Dictionary, at: Vector3, count: int, CM: float, H: float, TR: float, hot: float, _turf: float,
		t0 := 0.0) -> void:
	var rng := S.rng
	for i in count:
		var csz := CM * pow(rng.randf(), 2.0) + 0.03
		var v0: Vector3
		if rng.randf() < 0.6:
			var a := deg_to_rad(rng.randf_range(2.0, 26.0))
			v0 = (S._disc().normalized() * sin(a) + Vector3(0, cos(a), 0)) * sqrt(2.0 * G * H * rng.randf_range(0.15, 1.0))
		else:
			var el := deg_to_rad(rng.randf_range(15.0, 55.0))
			var sp := sqrt(G * maxf(TR * pow(rng.randf_range(0.12, 1.0), 0.8), 0.3) / sin(2.0 * el))
			v0 = (S._disc().normalized() * cos(el) + Vector3(0, sin(el), 0)) * sp
		var k := 0.25 / (1.0 + csz * 3.0)
		var p0 := at + S._disc() * 0.3 + Vector3(0, 0.15, 0)
		var life := 30.0 + rng.randf() * 15.0
		var land := S._land(p0, v0, k, at.y, life)
		S._add(b["clods"], p0, v0, t0 + rng.randf_range(0.0, 0.06), life, k, -G, csz, csz, S._clod_col(),
			rng.randf_range(-9, 9), land, 1.0 if rng.randf() < hot else 0.0)


## Sparks round a normal (UP for the ground). up_bias > 0 keeps them off the surface.
static func _sparks(b: Dictionary, at: Vector3, count: int, speed: float, life: float, w: float, l: float, nrm: Vector3,
		up_bias: float, cone := 1.0) -> void:
	var rng := S.rng
	var nn := nrm.normalized()
	for i in count:
		var d := S._ball().normalized()
		d = (d * cone + nn * (1.0 - cone * 0.5 + up_bias)).normalized()
		if d.dot(nn) < 0.0:
			d = d - nn * 2.0 * d.dot(nn)
		S._add(b["sparks"], at, d * speed * rng.randf_range(0.4, 1.0), rng.randf_range(0.0, 0.03),
			life * rng.randf_range(0.5, 1.4), 0.35, -G, w, l, Color(1, 1, 1, 1), 0.0, 0.0, 0.0)


## Flares: the path is worked out here and again each frame by flare_pos (Blast moves the head and light on it).
static func _flare(b: Dictionary, kind: String, at: Vector3, rng: RandomNumberGenerator) -> void:
	var light := kind == "flare_light"
	var col: Color = {"flare_light": Color(1.0, 0.93, 0.78), "flare_red": Color(1.0, 0.16, 0.08),
		"flare_green": Color(0.25, 1.0, 0.3), "flare_white": Color(1.0, 0.97, 0.9)}.get(kind, Color.WHITE)
	var f := {
		"at": at, "apex_h": 110.0 if light else rng.randf_range(62.0, 75.0),
		"rise": 3.0 if light else 2.2,
		"burn": 30.0 if light else 7.5,
		"fall": 2.4 if light else 7.0,                       # m/s once it has burst (parachute or not)
		"drift": Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * (6.0 if light else 14.0),
		"sway": 1.6 if light else 0.0,
		"col": col, "light": light, "range": 240.0 if light else 70.0, "energy": 16.0 if light else 4.0,
		"head": 0.9 if light else 0.6,
	}
	b["flare"] = f
	var end_t: float = float(f["rise"]) + float(f["burn"])
	# The trail: a puff every little while along the path; the rise trail thicker, the hanging trail thin.
	var t := 0.05
	while t < end_t:
		var p := flare_pos(f, t)
		var rising := t < float(f["rise"])
		var s1 := rng.randf_range(0.3, 0.5) * (1.3 if rising else (0.9 if light else 0.7))
		var v := rng.randf_range(-0.03, 0.03)
		var c := Color(0.8 + v, 0.79 + v, 0.76 + v, 1.0)
		if not light:
			c = c.lerp(col, 0.12)
		S._add(b["smoke"], p, Vector3(0, 0.5, 0), t, rng.randf_range(7.0, 12.0) * (1.0 if rising else 0.8), 1.0, 0.25,
			s1 * 0.35, s1 * (2.4 if rising else (3.2 if light else 2.2)), c, rng.randf_range(-0.3, 0.3), 0.6, 1.0)
		t += 0.035 if rising else (0.09 if light else 0.05)
	# A little launch flash and sparks off the head while it rises.
	_fire(b, at + Vector3(0, 0.3, 0), 3, 0.5, 0.1, 0.0)
	b.merge({"flash": 2.0, "light_range": float(f["range"]), "fire_h": 0.0, "glow_r": 0.1, "fire_life": 0.001,
		"crater_r": 0.0, "top": float(f["apex_h"]) + 40.0, "reach": 120.0, "total": end_t + 12.0, "shake": 0.0,
		"ember": 0.0}, true)


## Where a flare's head is at time t (and whether it is still burning: w = 1 burning, 0 out).
static func flare_pos(f: Dictionary, t: float) -> Vector3:
	var at: Vector3 = f["at"]
	var rise: float = f["rise"]
	var H: float = f["apex_h"]
	var dr: Vector3 = f["drift"]
	if t < rise:
		var u := t / rise
		return at + dr * 0.25 * u + Vector3(0, H * (1.0 - (1.0 - u) * (1.0 - u)), 0)
	var s := t - rise
	var sway: float = f["sway"]
	var p := at + dr * 0.25 + Vector3(0, H, 0) + dr * s * 0.1 - Vector3(0, float(f["fall"]) * s, 0)
	p += Vector3(sin(s * 1.3), 0, cos(s * 1.1)) * sway
	p.y = maxf(p.y, at.y + 0.3)
	return p


## Red jackets (2026-11-10): black powder. "musket": the shot, nrm along the barrel: a tongue of flame, then a thick
## bank of white smoke driven out a few metres, slowing, swelling, hanging for many seconds and drifting off; a
## volley of a whole line makes one wall of it. "pan": the flash in the pan, a small puff jumping up by the lock.
static func _musket(b: Dictionary, kind: String, at: Vector3, nrm: Vector3, density: float) -> void:
	var rng := S.rng
	var d := nrm.normalized()
	var n := func(x: float) -> int: return maxi(int(x * density), 2)
	var smoke_col := func() -> Color:
		var v := rng.randf_range(-0.04, 0.03)
		return Color(0.80 + v, 0.80 + v, 0.78 + v, 1.0)
	if kind == "pan":
		for i in 3:
			var target := at + Vector3(0, rng.randf_range(0.08, 0.18), 0) + S._ball() * 0.05
			S._add(b["fire"], at, (target - at) * 14.0, 0.0, 0.06, 14.0, 0.0, 0.02, rng.randf_range(0.04, 0.07),
				Color(1, 1, 1, 1), 0.0, 0.0, 0.6)
		for i in n.call(7):
			var target := at + Vector3(0, rng.randf_range(0.2, 0.55), 0) + S._ball() * 0.12
			var s1 := rng.randf_range(0.06, 0.13)
			S._add(b["smoke"], at, (target - at) * 5.0, rng.randf_range(0.0, 0.03), rng.randf_range(2.0, 3.5), 5.0, 0.12,
				s1 * 0.3, s1, smoke_col.call(), rng.randf_range(-1, 1), 0.8, 1.0)
		b.merge({"flash": 1.2, "light_range": 3.0, "fire_h": 0.1, "glow_r": 0.3, "fire_life": 0.06, "total": 4.0,
			"reach": 3.0, "top": 2.0}, true)
		return
	# The flame: a short hot tongue out of the muzzle (the cannon: about three times the reach and size).
	var sc := 2.6 if kind == "cannon" else 1.0
	for i in n.call(7.0 * sc):
		var reach := rng.randf_range(0.25, 0.9) * sc
		var target := at + d * reach + S._ball() * 0.12 * sc
		var s1 := rng.randf_range(0.09, 0.2) * (1.2 - reach / sc * 0.5) * sc
		S._add(b["fire"], at, (target - at) * 16.0, rng.randf_range(0.0, 0.01), rng.randf_range(0.05, 0.1), 16.0, 0.0,
			s1 * 0.3, s1, Color(1, 1, 1, 1), rng.randf_range(-2, 2), 0.0, 1.0 - reach / sc)
	# The bank of smoke: thrown out along the barrel (the furthest blobs the biggest), then hanging and rising slowly.
	for i in n.call(44.0 * sc):
		var f := pow(rng.randf(), 0.7)
		var target := at + (d * (0.3 + 3.2 * f) + S._ball() * (0.15 + 0.45 * f) + Vector3(0, 0.15 * f, 0)) * sc
		var k := rng.randf_range(2.6, 3.6)
		var s1 := rng.randf_range(0.14, 0.3) * (0.5 + 1.3 * f) * sqrt(sc)
		S._add(b["smoke"], at + d * 0.05, (target - at) * k, rng.randf_range(0.0, 0.06), rng.randf_range(7.0, 12.0), k, 0.05,
			s1 * 0.25, s1, smoke_col.call(), rng.randf_range(-0.4, 0.4), 0.8, 1.0)
	b.merge({"flash": 3.0 * sc, "light_range": 7.0 * sc, "fire_h": 0.2, "glow_r": 0.8, "fire_life": 0.08, "total": 13.0,
		"reach": 8.0, "top": 4.0, "crater_r": 0.0}, true)
