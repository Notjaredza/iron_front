class_name Tank
extends Node3D
## A tank as a scene node (Tanks Chat, 2026-11-09), built on the Lorry pattern: a body pivot
## that rides the ground, moving parts under it, and per-frame calls.
##   drive(dl, dr)        each track's distance (m); the links scroll, the wheels turn
##   ride(ground_fn, dt)  rests the tank on the ground under its tracks (and tail skid), a
##                        stiff spring on top so it lurches and rocks a little
##   set_turret / set_elev / set_sponson / set_recoil / set_hatch
## Kinds: heavy_male, heavy_female, light_gun, light_mg (see tank_builder.gd).

const T := preload("res://scripts/vehicles/tank_builder.gd")
const MG := preload("res://scripts/units/mg_builder.gd")
const PHASES := 8  # track meshes per link pitch

static var _cache := {}

var kind := "heavy_male"
var lod := 0
var wreck := false
var heavy := true
var body: Node3D
var tracks: Array = []  # {node, side}
var wheels: Array = []  # {node, side, r}
var turret: Node3D
var gun: Node3D  # elevation pivot (light) / sponson guns are in spon
var barrel: Node3D
var spon := {}  # side -> {node, barrel}
var hatches := {}  # name -> {node, axis, sign, max}
var tail: Node3D
var tail_wheels: Array = []
var dist := [0.0, 0.0]  # left, right
var spring := {"heave": 0.0, "pitch": 0.0, "roll": 0.0, "vh": 0.0, "vp": 0.0, "vr": 0.0}
var contact := PackedVector2Array()
var track_x := 1.35
var com := Vector3.ZERO
var stiff := 12.0
var damp := 0.55
var _tris := 0


static func _mesh(key: String, fn: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = MG.mesh(fn.call())
	return _cache[key]


func _mi(parent: Node3D, m: Mesh, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, at: Vector3, nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = at
	parent.add_child(n)
	return n


func setup(tank_kind := "heavy_male", lod_level := 0, burnt := false) -> Tank:
	kind = tank_kind
	lod = lod_level
	wreck = burnt
	heavy = T.is_heavy(kind)
	track_x = T.H_TRACK_X if heavy else T.L_TRACK_X
	com = T.H_COM if heavy else T.L_COM
	stiff = 13.0 if heavy else 10.0
	damp = 0.6 if heavy else 0.45
	contact = T.contact(kind)
	var k := "%s_%d_%s" % [kind, lod, wreck]
	body = _pivot(self, Vector3.ZERO, "Body")
	var hg := T.hull(kind, lod, wreck)
	_tris = hg.tri_count()
	_mi(body, MG.mesh(hg))
	for side in [-1, 1]:
		var n := _pivot(body, Vector3(side * track_x, 0, 0), "Track")
		var mi := _mi(n, _track_mesh(0.0, side < 0 and wreck))
		tracks.append({"node": mi, "side": side})
		_tris += T.track(kind, lod, 0.0, wreck, side < 0 and wreck).tri_count()
	for st: Array in (T.wheel_stations(kind) if lod < 2 else []):
		var wg := T.wheel_geo(st, lod, wreck)
		var wm := _mesh("w_%s_%s_%s" % [k, st[2], st[1]], func() -> UnitGeo: return wg)
		for side in [-1, 1]:
			var c: Vector2 = st[0]
			var n := _pivot(body, Vector3(side * track_x, c.y, c.x), "Wheel")
			_mi(n, wm)
			wheels.append({"node": n, "side": side, "r": st[1]})
			_tris += wg.tri_count()
	if heavy:
		for side in [-1, 1]:
			var piv := T.H_SPON_GUN * Vector3(side, 1, 1)
			var n := _pivot(body, piv, "Sponson")
			var mg := T.sponson_mount(kind, lod, wreck)
			_mi(n, MG.mesh(mg))
			var b := _pivot(n, Vector3.ZERO, "Barrel")
			var bg := T.sponson_barrel(kind, lod, wreck)
			_mi(b, MG.mesh(bg))
			spon[side] = {"node": n, "barrel": b}
			_tris += mg.tri_count() + bg.tri_count()
		var rh := _pivot(body, T.H_ROOF_HATCH, "RoofHatch")
		var rg := T.roof_hatch(lod, wreck)
		_mi(rh, MG.mesh(rg))
		hatches["roof"] = {"node": rh, "axis": Vector3.RIGHT, "sign": 1.0, "max": 1.9}
		_tris += rg.tri_count()
		for side in [-1, 1]:
			var hinge := T.H_DOOR_HINGE * Vector3(side, 1, 1)
			var dn := _pivot(body, hinge, "Door")
			var dg := T.door(lod, wreck, side)
			_mi(dn, MG.mesh(dg))
			# Swing it outward (away from the hull side): pick the sign that moves its middle out.
			var mid := (T.H_DOOR_END - T.H_DOOR_HINGE) * Vector3(side, 1, 1) * 0.5
			var moved := Basis(Vector3.UP, 0.2) * mid - mid
			var sg := 1.0 if moved.dot(Vector3(side, 0, 0)) > 0.0 else -1.0
			hatches["door_r" if side > 0 else "door_l"] = {"node": dn, "axis": Vector3.UP, "sign": sg, "max": 1.75}
			_tris += dg.tri_count()
		tail = _pivot(self, T.H_TAIL_PIVOT, "Tail")
		var tg := T.tail(lod, wreck)
		_mi(tail, MG.mesh(tg))
		var tw := T.spoke_wheel(T.H_TAIL_R, 0.12, 8, lod, wreck)
		var twm := MG.mesh(tw)
		for side in [-1, 1]:
			var n := _pivot(tail, Vector3(side * T.H_TAIL_X, -0.05, T.H_TAIL_LEN), "TailWheel")
			_mi(n, twm)
			tail_wheels.append(n)
		_tris += tg.tri_count() + 2 * tw.tri_count()
	else:
		turret = _pivot(body, T.L_TURRET, "Turret")
		var tg := T.turret(kind, lod, wreck)
		_mi(turret, MG.mesh(tg))
		gun = _pivot(turret, T.L_GUN, "Gun")
		var mg := T.light_mantlet(kind, lod, wreck)
		_mi(gun, MG.mesh(mg))
		barrel = _pivot(gun, Vector3.ZERO, "Barrel")
		var bg := T.light_barrel(kind, lod, wreck)
		_mi(barrel, MG.mesh(bg))
		var lid := _pivot(turret, T.L_HATCH, "Lid")
		var lg := T.cupola_lid(lod, wreck) if lod < 2 else UnitGeo.new()
		if lod < 2:
			_mi(lid, MG.mesh(lg))
		hatches["cupola"] = {"node": lid, "axis": Vector3.RIGHT, "sign": 1.0, "max": 1.8}
		var dh := _pivot(body, T.L_DRIVER_HINGE, "DriverHatch")
		var dg := T.driver_hatch(lod, wreck)
		_mi(dh, MG.mesh(dg))
		# Lift the lower edge up and forward.
		var mid := Basis(Vector3.RIGHT, -0.62) * Vector3(0, 0, -0.3)
		var moved := Basis(Vector3.RIGHT, 0.2) * mid - mid
		hatches["driver"] = {"node": dh, "axis": Vector3.RIGHT, "sign": 1.0 if moved.y > 0.0 else -1.0, "max": 1.5}
		_tris += tg.tri_count() + mg.tri_count() + bg.tri_count() + lg.tri_count() + dg.tri_count()
	return self


func tri_count() -> int:
	return _tris


func _track_mesh(off: float, broken: bool) -> Mesh:
	var q := int(round(fposmod(off, 1.0) * PHASES)) % PHASES
	if wreck:
		q = 0
	var key := "t_%s_%d_%s_%s_%d" % [kind, lod, wreck, broken, q]
	var kk := kind
	var ll := lod
	var ww := wreck
	return _mesh(key, func() -> UnitGeo: return T.track(kk, ll, float(q) / PHASES, ww, broken))


## Each track's total distance (left, right), forward positive.
func drive(dl: float, dr: float) -> void:
	dist = [dl, dr]
	var pitch: float = _pitch()
	for t: Dictionary in tracks:
		var d: float = dl if int(t["side"]) < 0 else dr
		(t["node"] as MeshInstance3D).mesh = _track_mesh(d / pitch, int(t["side"]) < 0 and wreck)
	for w: Dictionary in wheels:
		var d: float = dl if int(w["side"]) < 0 else dr
		(w["node"] as Node3D).basis = Basis(Vector3.RIGHT, -d / float(w["r"]))


## The link pitch used at this lod (the track mesh repeats every pitch).
func _pitch() -> float:
	var o := T.track_outline(kind)
	var lens := T._lengths(o)
	var per := lens[lens.size() - 1]
	var p0: float = (T.H_PITCH if heavy else T.L_PITCH) * (1.0 if lod == 0 else 2.0)
	return per / float(maxi(8, int(round(per / p0))))


## Where the tank rests on one track line (x in tank frame): [heave, pitch].
func _rest(ground_fn: Callable, x: float) -> Array:
	var gx := global_transform
	var prof := PackedFloat32Array()
	var z0 := -6.5
	for i in 131:
		prof.append(ground_fn.call(gx * Vector3(x, 0, z0 + 0.1 * i)))
	# Coarse pass over -0.6..0.6 rad, then a fine pass round the best.
	var best := [0.0, 0.0]
	var best_y := INF
	for pass_i in 2:
		var p0: float = -0.6 if pass_i == 0 else float(best[1]) - 0.05
		var step: float = 0.05 if pass_i == 0 else 0.01
		var count: int = 25 if pass_i == 0 else 11
		for ci in count:
			var p := p0 + step * ci
			var c := cos(p)
			var s := sin(p)
			var h := -INF
			for q in contact:
				var yr := q.y * c - q.x * s
				var zr := q.y * s + q.x * c
				var f := clampf((zr - z0) / 0.1, 0.0, 129.999)
				var i := int(f)
				var gy := lerpf(prof[i], prof[i + 1], f - float(i))
				h = maxf(h, gy - yr)
			var cy := h + com.y * c - com.z * s
			if cy < best_y - 1e-5:
				best_y = cy
				best = [h, p]
	return best


## Rests the tank on the ground (ground_fn: world Vector3 -> height). dt = seconds since the
## last call (0 = snap). shake = engine judder (m).
func ride(ground_fn: Callable, dt: float, shake := 0.0) -> void:
	var l := _rest(ground_fn, -track_x)
	var r := _rest(ground_fn, track_x)
	var target := {"heave": (float(l[0]) + float(r[0])) * 0.5, "pitch": (float(l[1]) + float(r[1])) * 0.5,
		"roll": atan2(float(l[0]) - float(r[0]), track_x * 2.0)}
	for k in ["heave", "pitch", "roll"]:
		var vk: String = {"heave": "vh", "pitch": "vp", "roll": "vr"}[k]
		if dt <= 0.0:
			spring[k] = target[k]
			spring[vk] = 0.0
			continue
		var a: float = stiff * stiff * (float(target[k]) - float(spring[k])) - 2.0 * damp * stiff * float(spring[vk])
		spring[vk] = float(spring[vk]) + a * dt
		spring[k] = float(spring[k]) + float(spring[vk]) * dt
	var b := Basis(Vector3.RIGHT, float(spring["pitch"])) * Basis(Vector3.BACK, -float(spring["roll"]))
	body.transform = Transform3D(b, Vector3(0, float(spring["heave"]) + shake, 0))
	if tail != null:
		_tail(ground_fn)


## The steering tail trails on the ground behind on its pivot.
func _tail(ground_fn: Callable) -> void:
	var piv := body.transform * T.H_TAIL_PIVOT
	tail.position = piv
	var a := 0.3
	for it in 3:
		var az := piv.z + T.H_TAIL_LEN * cos(a)
		var gy: float = ground_fn.call(global_transform * Vector3(0, 0, az))
		a = asin(clampf((piv.y - (gy + T.H_TAIL_R) - 0.05 * cos(a)) / T.H_TAIL_LEN, -0.9, 0.9))
	tail.basis = Basis(Vector3.RIGHT, a)
	var d := (float(dist[0]) + float(dist[1])) * 0.5
	for w: Node3D in tail_wheels:
		w.basis = Basis(Vector3.RIGHT, -d / T.H_TAIL_R)


func set_turret(yaw: float) -> void:
	if turret != null:
		turret.basis = Basis(Vector3.UP, yaw)


func set_elev(deg: float) -> void:
	if gun != null:
		gun.basis = Basis(Vector3.RIGHT, deg_to_rad(deg))


## Sponson gun on side (-1 left, 1 right) turned out by out_rad (+ = outward), elevated by deg.
func set_sponson(side: int, out_rad: float, deg := 0.0) -> void:
	if spon.has(side):
		(spon[side]["node"] as Node3D).basis = Basis(Vector3.UP, -float(side) * out_rad) * Basis(Vector3.RIGHT, deg_to_rad(deg))


## Recoil (m back) of the main gun (side 0) or a sponson gun.
func set_recoil(side: int, m: float) -> void:
	var b: Node3D = barrel if side == 0 else (spon[side]["barrel"] as Node3D if spon.has(side) else null)
	if b != null:
		b.position = Vector3(0, 0, m)


func set_hatch(nm: String, open: float) -> void:
	if not hatches.has(nm):
		return
	var h: Dictionary = hatches[nm]
	var base := Basis()
	(h["node"] as Node3D).basis = Basis(h["axis"], float(h["sign"]) * float(h["max"]) * clampf(open, 0.0, 1.0)) * base


## World transform at a gun's muzzle (side 0 = the turret gun, -1/1 = sponson guns).
func muzzle_xf(side: int) -> Transform3D:
	if side == 0:
		return barrel.global_transform * Transform3D(Basis(), T.light_muzzle(kind))
	return (spon[side]["barrel"] as Node3D).global_transform * Transform3D(Basis(), T.sponson_muzzle(kind))


## World point of a body-frame point.
func bw(p: Vector3) -> Vector3:
	return body.global_transform * p
