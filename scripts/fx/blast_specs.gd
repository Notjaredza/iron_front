class_name BlastSpecs
extends RefCounted
## Explosion round A (Building Chat 1, 2026-11-09): what each size of blast is made of. Sizes 1 (mortar) to 8 (a bit
## bigger than Schwerer Gustav). Each size is its own shape, not the small one scaled up (EXPLOSION_STUDY.md, WW1):
##   all sizes   a faceted fireball, a fountain of earth (a tall narrow "poplar"), clods on real arcs, sparks,
##               a dark smoke ball forming as the fire dies, and a crater;
##   3 and up    a ring of dust rolling out along the ground;
##   6 and up    a rising smoke column with a cap that leans in the wind;
##   7 and up    the fire hugs the ground as a wide dome, the earth comes up as a dome, a dust skirt rolls out far.
## Most particles are sent to a sculpted spot (v0 = (target - p0) k, see fx_common): that's how the shapes are drawn.
## Round A tunes sizes 1, 4 and 8; the rest come from the same table and are tuned in round B.

const G := 9.81
const FLOATS := 20

# Per size (index 1..8): fountain height H, fire radius F, fire life FL, smoke radius S, smoke life SL, clods NC,
# biggest clod CM, throw range TR, crater radius CR and depth CD, fire blobs NF, smoke blobs NS, dust blobs ND,
# sparks NK, flash light energy, light range.
const T := {
	1: [10.0, 1.8, 0.38, 2.8, 9.0, 110, 0.48, 14.0, 1.1, 0.45, 20, 30, 40, 24, 7.0, 16.0],
	2: [14.0, 2.5, 0.44, 3.8, 11.0, 170, 0.63, 20.0, 1.6, 0.6, 26, 40, 52, 32, 9.0, 20.0],
	3: [19.0, 3.4, 0.52, 5.2, 14.0, 250, 0.82, 28.0, 2.3, 0.9, 32, 54, 70, 42, 11.0, 28.0],
	4: [28.0, 5.0, 0.7, 7.5, 18.0, 400, 1.1, 40.0, 3.4, 1.4, 46, 84, 104, 60, 15.0, 40.0],
	5: [38.0, 6.8, 0.85, 10.5, 24.0, 600, 1.5, 60.0, 5.0, 2.0, 62, 120, 140, 90, 20.0, 55.0],
	6: [56.0, 9.5, 1.1, 15.0, 36.0, 900, 2.0, 90.0, 7.5, 3.0, 90, 180, 210, 130, 26.0, 80.0],
	7: [80.0, 22.0, 1.5, 22.0, 50.0, 1300, 3.0, 150.0, 11.0, 5.0, 140, 280, 330, 200, 34.0, 130.0],
	8: [130.0, 45.0, 2.4, 40.0, 80.0, 2300, 4.2, 300.0, 18.0, 9.0, 260, 560, 660, 320, 48.0, 280.0],
}

static var rng := RandomNumberGenerator.new()


static func build(size: int, at: Vector3, seed_value: int, density := 1.0) -> Dictionary:
	size = clampi(size, 1, 8)
	rng.seed = hash(seed_value * 977 + size)
	var r: Array = (T[size] as Array).duplicate()
	for ci: int in [5, 10, 11, 12, 13]:
		r[ci] = maxi(int(float(r[ci]) * density), 4)
	var H: float = r[0]
	var F: float = r[1]
	var FL: float = r[2]
	var S: float = r[3]
	var SL: float = r[4]
	var fire := PackedFloat32Array()
	var smoke := PackedFloat32Array()
	var clods := PackedFloat32Array()
	var sparks := PackedFloat32Array()
	var top := H * 1.3
	var reach := float(r[7]) * 1.2 + 20.0
	var longest := SL
	var big := size >= 7

	# ---- fire: lumpy blobs flung out to a ball (small sizes, a little tall) or a wide low dome (7, 8)
	for i in int(r[10]):
		var d := _hemi(0.15 if big else -0.05)
		d.y *= 0.8 if big else 1.35
		var reachf := F * pow(rng.randf_range(0.25, 1.0), 0.6)
		var p0 := at + Vector3(0, F * 0.12, 0) + _ball() * F * 0.12
		var target := at + d * reachf + Vector3(0, F * (0.15 if big else 0.3), 0)
		var k := clampf(4.0 / FL, 4.0, 14.0)
		var life := FL * rng.randf_range(0.7, 1.35)
		var s1 := F * rng.randf_range(0.32, 0.55) * (0.8 if big else 1.0)
		_add(fire, p0, (target - p0) * k, rng.randf_range(0.0, 0.035), life, k, F * 0.6, s1 * 0.25, s1,
			Color(1, 1, 1, 1), rng.randf_range(-2, 2), 0.0, 1.0 - reachf / F)

	# ---- the earth fountain: brown dust blobs rising fast in a narrow column, then falling and settling
	var nd := int(r[12])
	var n_fount := nd if not big else int(nd * 0.25)
	# Jets: the earth goes up in a few ragged streams that part at the top, not one neat pillar.
	var jets: Array[Vector3] = []
	for j in 7:
		var a := deg_to_rad(rng.randf_range(2.0, 14.0))
		jets.append((_disc().normalized() * sin(a) + Vector3(0, cos(a), 0)) * rng.randf_range(0.7, 1.08))
	for i in n_fount:
		var hf := pow(rng.randf(), 0.6)
		var jet: Vector3 = jets[rng.randi() % jets.size()] if rng.randf() < 0.8 else Vector3.UP * rng.randf_range(0.4, 0.8)
		var p0 := at + Vector3(0, 0.3, 0) + _disc() * F * 0.2
		var target := at + jet * (H * hf + 1.0) + _ball() * H * 0.035 * (0.4 + hf)
		var k := 3.6 / sqrt(H / 10.0)
		var fall := 0.8 + H * 0.025
		var life := (1.4 + H * 0.08) * rng.randf_range(0.6, 1.3)
		var s1 := maxf(H * 0.06 * rng.randf_range(0.45, 1.25) * (1.25 - hf * 0.5), 0.4)
		_add(smoke, p0, (target - p0) * k, rng.randf_range(0.0, 0.06), life, k, -fall * k, s1 * 0.3, s1,
			_earth(0.0), rng.randf_range(-1, 1), 0.5, 0.45)

	# ---- a dust ring rolling out along the ground (3 and up)
	if size >= 3:
		var R := H * (0.55 if not big else 1.6)
		var n_ring := int(nd * (0.34 if not big else 0.5))
		for i in n_ring:
			var d := _disc().normalized()
			var rr := R * rng.randf_range(0.45, 1.0)
			var p0 := at + d * F * 0.3 + Vector3(0, 0.5, 0)
			var target := at + d * rr + Vector3(0, rng.randf() * R * (0.08 if not big else 0.1), 0)
			var k := (2.4 if not big else 1.1)
			var life := SL * rng.randf_range(0.1, 0.2) * (1.0 if not big else 3.0)
			var s1 := R * rng.randf_range(0.1, 0.19) * (1.0 if not big else 0.6)
			_add(smoke, p0, (target - p0) * k, rng.randf_range(0.02, 0.12), life, k, 0.0, s1 * 0.25, s1,
				_dust(), rng.randf_range(-0.5, 0.5), 0.1, 0.6)
			reach = maxf(reach, rr + s1 + 20.0)
			longest = maxf(longest, life + 0.2)

	# ---- the earth dome (7, 8): a crust of earth blobs thrown up as a dome on a wide base, then slumping back
	if big:
		var Wd := H * 0.8
		var Hd := H * 1.1
		for i in int(nd * 1.0):
			var d := _hemi(0.0)
			var crust := rng.randf_range(0.7, 1.05)
			var p0 := at + Vector3(0, 1.0, 0) + _ball() * F * 0.3
			var target := at + Vector3(d.x * Wd, d.y * Hd, d.z * Wd) * crust
			var k := 1.5
			var life := rng.randf_range(5.0, 13.0)
			var s1 := Wd * rng.randf_range(0.09, 0.17)
			_add(smoke, p0, (target - p0) * k, rng.randf_range(0.3, 0.7), life, k, -5.0 * k, s1 * 0.3, s1,
				_earth(0.06), rng.randf_range(-0.4, 0.4), 0.45, 0.35)
		top = maxf(top, Hd * 1.2)

	# ---- the smoke ball: dark blobs forming round the fire as it dies, rising slowly and drifting
	for i in int(float(r[11]) * 1.5):
		var p0 := at + Vector3(0, F * 0.6, 0) + _ball() * F * 0.6
		var off := _ball() * S * 0.8
		var target := at + Vector3(off.x, maxf(S * rng.randf_range(0.6, 1.5) + off.y, S * 0.35), off.z)
		if big:
			target = at + Vector3(off.x * 1.6, maxf(off.y + S * 0.6, S * 0.4), off.z * 1.6)
		var k := 1.4
		var life := SL * rng.randf_range(0.55, 1.05)
		var s1 := S * rng.randf_range(0.18, 0.4)
		_add(smoke, p0, (target - p0) * k, FL * rng.randf_range(0.35, 1.0), life, k, 0.6, s1 * 0.35, s1,
			_smoke_col(), rng.randf_range(-0.3, 0.3), 1.0, 1.0)

	# ---- the column and its cap (6 and up)
	if size >= 6:
		var Hc := H * 1.6
		var Rs := S * 0.7
		var Rc := S * (2.0 if size == 8 else 1.4)
		for i in int(float(r[11]) * 1.3):
			var cap := rng.randf() < 0.38
			var target: Vector3
			var k: float
			if cap:
				var d := _disc()
				var ring := 0.45 + 0.55 * sqrt(rng.randf())
				target = at + Vector3(d.x * Rc * ring, Hc * rng.randf_range(0.86, 1.08), d.z * Rc * ring)
				k = 0.32
			else:
				var hf := pow(rng.randf(), 0.8)
				var rr := Rs * (0.5 + 0.6 * hf) * sqrt(rng.randf())
				target = at + _disc().normalized() * rr + Vector3(0, Hc * hf * 0.9 + Rs * 0.3, 0)
				k = 0.5
			var p0 := at + Vector3(0, F * 0.4, 0) + _ball() * F * 0.4
			var life := SL * rng.randf_range(0.7, 1.05)
			var s1 := (Rc * rng.randf_range(0.2, 0.32)) if cap else (Rs * rng.randf_range(0.55, 0.9))
			var col := _smoke_col() if not cap else _smoke_col().lightened(0.12)
			_add(smoke, p0, (target - p0) * k, rng.randf_range(0.15, 3.5), life, k, 0.4, s1 * 0.3, s1,
				col, rng.randf_range(-0.15, 0.15), 0.8, 1.0)
		top = maxf(top, Hc * 1.25 + 80.0)
		reach = maxf(reach, Rc * 1.5 + 120.0)

	# ---- clods: two kinds, a fountain thrown up and back, and a spray thrown out
	for i in int(r[5]):
		var csz := float(r[6]) * pow(rng.randf(), 2.4) + 0.06
		var v0: Vector3
		if rng.randf() < 0.62:
			var a := deg_to_rad(rng.randf_range(2.0, 22.0 if not big else 32.0))
			var d := _disc().normalized()
			var sp := sqrt(2.0 * G * H * rng.randf_range(0.15, 1.0)) * (1.0 if not big else 1.15)
			v0 = (d * sin(a) + Vector3(0, cos(a), 0)) * sp
		else:
			var el := deg_to_rad(rng.randf_range(18.0, 58.0))
			var range_m := float(r[7]) * pow(rng.randf_range(0.12, 1.0), 0.8)
			var sp := sqrt(G * range_m / sin(2.0 * el))
			var d := _disc().normalized()
			v0 = (d * cos(el) + Vector3(0, sin(el), 0)) * sp
		var k := 0.25 / (1.0 + csz * 3.0)
		var p0 := at + _disc() * float(r[8]) * 0.5 + Vector3(0, 0.2, 0)
		var life := (32.0 if size < 6 else 75.0) + rng.randf() * 18.0
		var land := _land(p0, v0, k, at.y, life)
		var hot := 1.0 if rng.randf() < 0.22 else 0.0
		_add(clods, p0, v0, rng.randf_range(0.0, 0.07), life, k, -G, csz, csz, _clod_col(), rng.randf_range(-9, 9), land, hot)
		longest = maxf(longest, life)
	# Big blocks for 8 (and 7): car-sized lumps thrown far.
	if big:
		for i in (70 if size == 8 else 30):
			var csz := rng.randf_range(1.6, 4.5) * (1.0 if size == 8 else 0.7)
			var el := deg_to_rad(rng.randf_range(30.0, 62.0))
			var range_m := float(r[7]) * rng.randf_range(0.25, 0.85)
			var sp := sqrt(G * range_m / sin(2.0 * el))
			var d := _disc().normalized()
			var v0 := (d * cos(el) + Vector3(0, sin(el), 0)) * sp
			var p0 := at + _disc() * float(r[8]) * 0.4 + Vector3(0, 0.5, 0)
			var life := 85.0
			var land := _land(p0, v0, 0.01, at.y, life)
			_add(clods, p0, v0, rng.randf_range(0.0, 0.15), life, 0.01, -G, csz, csz, _clod_col(), rng.randf_range(-2, 2), land, 0.0)

	# ---- sparks and burning bits
	for i in int(r[13]):
		var d := _hemi(0.1)
		var sp := rng.randf_range(8.0, 28.0) * sqrt(F / 1.4) * (0.6 if big else 1.0)
		var life := rng.randf_range(0.5, 1.6) * (1.0 + float(size) * 0.25)
		var w := 0.035 * sqrt(F)
		_add(sparks, at + Vector3(0, F * 0.2, 0), d * sp, rng.randf_range(0.0, 0.08), life, 0.35, -G, w, 0.12 * sqrt(F),
			Color(1, 1, 1, 1), 0.0, 0.0, 0.0)

	return {
		"fire": fire, "smoke": smoke, "clods": clods, "sparks": sparks,
		"fire_life": FL, "fire_h": F * 0.5, "glow_r": F * 2.6, "flash": r[14], "light_range": r[15],
		"ember": float(r[14]) * 0.06, "ember_t": 4.0 + float(size) * 1.5,
		"crater_r": r[8], "crater_d": r[9], "reach": reach, "top": top, "total": longest + 0.5,
		"shake": float(size) * float(size) * 0.02 + 0.05,
		"counts": [fire.size() / FLOATS, smoke.size() / FLOATS, clods.size() / FLOATS, sparks.size() / FLOATS],
	}


## One particle: see fx_common.gdshaderinc for what each number is.
static func _add(buf: PackedFloat32Array, p0: Vector3, v0: Vector3, t0: float, life: float, k: float, ay: float,
		s0: float, s1: float, col: Color, spin: float, c3: float, c4: float) -> void:
	buf.append_array([v0.x, t0, ay, p0.x, v0.y, life, s0, p0.y, v0.z, k, s1, p0.z,
		col.r, col.g, col.b, col.a, rng.randf() * 100.0, spin, c3, c4])


## Age at which a clod thrown from p0 with v0 lands back on ground height gy (or its life if it never does).
static func _land(p0: Vector3, v0: Vector3, k: float, gy: float, life: float) -> float:
	var t := 0.05
	var prev := 0.0
	while t < life:
		if _y(p0.y, v0.y, k, t) < gy:
			var a := prev
			var b := t
			for i in 14:
				var m := (a + b) * 0.5
				if _y(p0.y, v0.y, k, m) < gy:
					b = m
				else:
					a = m
			return a
		prev = t
		t += 0.05
	return life


static func _y(y0: float, vy: float, k: float, t: float) -> float:
	if k < 0.0001:
		return y0 + vy * t - 0.5 * G * t * t
	var e := (1.0 - exp(-k * t)) / k
	return y0 + vy * e - G / k * (t - e)


static func _ball() -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length_squared() <= 1.0:
			return v
	return Vector3.ZERO


static func _hemi(min_y: float) -> Vector3:
	while true:
		var v := _ball()
		if v.length_squared() > 0.05 and v.normalized().y >= min_y:
			return v.normalized()
	return Vector3.UP


static func _disc() -> Vector3:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf())
	return Vector3(cos(a) * r, 0, sin(a) * r)


static func _earth(dark: float) -> Color:
	var v := rng.randf_range(-0.04, 0.04)
	return Color(0.42 - dark + v, 0.33 - dark + v * 0.8, 0.24 - dark + v * 0.6, 1.0)


static func _dust() -> Color:
	var v := rng.randf_range(-0.03, 0.03)
	return Color(0.45 + v, 0.39 + v, 0.30 + v, 0.45)


static func _smoke_col() -> Color:
	var v := rng.randf_range(-0.03, 0.04)
	var brown := rng.randf_range(0.0, 0.035)
	return Color(0.37 + v + brown, 0.35 + v + brown * 0.6, 0.32 + v, 1.0)


static func _clod_col() -> Color:
	var v := rng.randf_range(-0.05, 0.06)
	return Color(0.34 + v, 0.26 + v * 0.8, 0.18 + v * 0.6, 0.32)
