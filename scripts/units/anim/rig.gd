extends RefCounted
## The shared pose solver for every unit built on the soldier skeleton
## (Question Chat, animation round 1, 2026-11-09).
##
## A pose "spec" is a Dictionary:
##   rot       bone -> Euler degrees (YXZ) in the parent's frame (missing = rest)
##   root_rot  Euler degrees for the whole body (prone, falls), root_pos its shift
##   foot_r / foot_l    ankle targets in model space (two-bone leg IK), fpitch_r / fpitch_l
##                      foot pitch in degrees (+ = toe down), pole_kr / pole_kl knee poles
##   rifle     where the held item goes: {mode: aim | chest | order | hand, ...}
##   hand_r / hand_l    null = arm by angles, Vector3 = a point in the item's frame,
##                      [bone, Vector3] = a point given in rest model space that rides
##                      on that bone (bone -1 = model space). pole_r / pole_l elbow poles.
## Two specs blend at a weight; IK runs after the blend, so hands and feet stay on
## their targets all the way through a move. Any unit with the same bone names can
## play what this solves (baked to an Animation by Anim.bake).

const B := preload("res://scripts/units/soldier_builder.gd")
const DEG := PI / 180.0
const AIM_POINT := Vector3(0.12, 0.215, -0.10)  # chest-local spot the butt sits in
const MUZZLE := Vector3(0, 0.03, -0.84)  # rifle frame
const BOLT := Vector3(0.052, 0.044, -0.02)  # bolt knob, rifle frame
const LEGS := [[B.THIGH_R, B.SHIN_R, B.FOOT_R, "foot_r", "fpitch_r", "pole_kr", 1.0],
	[B.THIGH_L, B.SHIN_L, B.FOOT_L, "foot_l", "fpitch_l", "pole_kl", -1.0]]


static func q_of(v: Vector3) -> Quaternion:
	return Basis.from_euler(v * DEG).get_rotation_quaternion()


## Copy of base with changes laid over it. "rot" merges bone by bone;
## "add" (bone -> degrees) is added on top of the merged rot.
static func over(base: Dictionary, changes: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in changes:
		if k == "rot":
			var r: Dictionary = out.get("rot", {}).duplicate()
			for bn in changes["rot"]:
				r[bn] = changes["rot"][bn]
			out["rot"] = r
		elif k == "add":
			var r2: Dictionary = out.get("rot", {}).duplicate()
			for bn in changes["add"]:
				r2[bn] = r2.get(bn, Vector3.ZERO) + changes["add"][bn]
			out["rot"] = r2
		elif k == "rifle_add":
			var rf: Dictionary = out.get("rifle", {}).duplicate()
			for rk in changes["rifle_add"]:
				var v: Variant = changes["rifle_add"][rk]
				rf[rk] = (rf.get(rk, Vector3.ZERO if v is Vector3 else 0.0)) + v
			out["rifle"] = rf
		else:
			out[k] = changes[k]
	return out


## Solves the blend of a and b at weight t. Returns model-space bone transforms
## (not yet put on the ground).
static func solve(a: Dictionary, b: Dictionary, t: float) -> Array[Transform3D]:
	var n := B.REST.size()
	var g: Array[Transform3D] = []
	g.resize(n)
	var ra: Dictionary = a.get("rot", {})
	var rb: Dictionary = b.get("rot", {})
	var rq := q_of(a.get("root_rot", Vector3.ZERO)).slerp(q_of(b.get("root_rot", Vector3.ZERO)), t)
	var rp: Vector3 = (a.get("root_pos", Vector3.ZERO) as Vector3).lerp(b.get("root_pos", Vector3.ZERO), t)
	g[0] = Transform3D(Basis(rq), rp)
	for i in range(1, n):
		var par: int = B.BONE_PARENT[i]
		var q := q_of(ra.get(i, Vector3.ZERO)).slerp(q_of(rb.get(i, Vector3.ZERO)), t)
		g[i] = g[par] * Transform3D(Basis(q), B.REST[i] - B.REST[par])
	# Legs: IK to the ankle targets, the foot flat (with its pitch) under the root.
	for L in LEGS:
		var ta: Variant = a.get(L[3])
		var tb: Variant = b.get(L[3])
		if ta == null and tb == null:
			continue
		var fk_pos: Vector3 = g[L[2]].origin
		var fk_q: Quaternion = g[L[2]].basis.get_rotation_quaternion()
		var pa: Vector3 = ta if ta != null else fk_pos
		var pb: Vector3 = tb if tb != null else fk_pos
		var flat := g[0].basis.get_rotation_quaternion()
		var qa := flat * Quaternion(Vector3.RIGHT, -float(a.get(L[4], 0.0)) * DEG) if ta != null else fk_q
		var qb := flat * Quaternion(Vector3.RIGHT, -float(b.get(L[4], 0.0)) * DEG) if tb != null else fk_q
		var s: float = L[6]
		var pole_d: Vector3 = g[0].basis * Vector3(0.12 * s, 0, -1)
		var pole: Vector3 = (a.get(L[5], pole_d) as Vector3).lerp(b.get(L[5], pole_d), t)
		ik(g, L[0], L[1], L[2], pa.lerp(pb, t), pole, 0.0)
		g[L[2]] = Transform3D(Basis(qa.slerp(qb, t)), g[L[2]].origin)
	# The held item.
	var xa := item_xf(a.get("rifle", {}), g)
	var xb := item_xf(b.get("rifle", {}), g)
	g[B.RIFLE] = xa.interpolate_with(xb, t)
	# Arms.
	for arm in [[B.UARM_R, B.FARM_R, B.HAND_R, "hand_r", "pole_r", Vector3(0.4, -0.4, 0.2)],
			[B.UARM_L, B.FARM_L, B.HAND_L, "hand_l", "pole_l", Vector3(-0.4, -0.4, 0.2)]]:
		var ha: Variant = a.get(arm[3])
		var hb: Variant = b.get(arm[3])
		if ha == null and hb == null:
			continue
		var fk_hand: Vector3 = palm_of(g, arm[1], arm[2])
		var wa: Vector3 = target_of(ha, g) if ha != null else fk_hand
		var wb: Vector3 = target_of(hb, g) if hb != null else fk_hand
		var pole: Vector3 = (a.get(arm[4], arm[5]) as Vector3).lerp(b.get(arm[4], arm[5]), t)
		ik(g, arm[0], arm[1], arm[2], wa.lerp(wb, t), pole, B.PALM)
	return g


## Where a hand target spec sits in model space.
static func target_of(h: Variant, g: Array[Transform3D]) -> Vector3:
	if h is Vector3:
		return g[B.RIFLE] * (h as Vector3)
	var bn: int = h[0]
	var p: Vector3 = h[1]
	if bn < 0:
		return p
	return g[bn] * (p - B.REST[bn])


static func palm_of(g: Array[Transform3D], fa: int, hd: int) -> Vector3:
	var d := (B.REST[hd] - B.REST[fa]).normalized()
	return g[hd] * (d * B.PALM)


## Where the held item goes for one spec, given the body.
static func item_xf(r: Dictionary, g: Array[Transform3D]) -> Transform3D:
	var mode: String = r.get("mode", "order")
	var roll: float = r.get("roll", 0.0) * DEG
	match mode:
		"chest":
			var bas := Basis.looking_at((r["dir"] as Vector3).normalized(), r.get("up", Vector3.UP))
			bas = bas * Basis(Vector3.BACK, roll)
			var loc := Transform3D(bas, (r["grip"] as Vector3) - bas * B.GRIP_R)
			return g[B.CHEST] * loc
		"aim":
			var butt := g[B.CHEST] * (AIM_POINT + (r.get("off", Vector3.ZERO) as Vector3))
			var d: Vector3 = r.get("dir", Vector3.FORWARD)
			var bas := Basis.looking_at(d.normalized(), Vector3.UP) * Basis(Vector3.BACK, roll)
			return Transform3D(bas, butt - bas * B.BUTT)
		"hand":
			# Held by the right hand: GRIP_R in the palm, turned by "rot" in the hand's frame.
			var bas := Basis.from_euler((r.get("rot", Vector3.ZERO) as Vector3) * DEG)
			var palm := (B.REST[B.HAND_R] - B.REST[B.FARM_R]).normalized() * B.PALM
			return g[B.HAND_R] * Transform3D(bas, palm - bas * B.GRIP_R)
		_:
			var bas := Basis.looking_at(Vector3.UP, Vector3.FORWARD)
			var butt: Vector3 = r.get("butt", Vector3(0.27, 0.015, -0.07))
			return g[0] * Transform3D(bas, butt - bas * B.BUTT)


## Two-bone IK: the end (plus extra along the last bone) reaches target, the middle
## joint bends toward the pole direction.
static func ik(g: Array[Transform3D], ua: int, fa: int, hd: int, target: Vector3, pole: Vector3, extra: float) -> void:
	var s := g[ua].origin
	var l1 := (B.REST[fa] - B.REST[ua]).length()
	var l2 := (B.REST[hd] - B.REST[fa]).length() + extra
	var d := target - s
	var dist := clampf(d.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir := d.normalized()
	var ang := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var pv := pole - dir * pole.dot(dir)
	if pv.length_squared() < 1e-8:
		pv = Vector3.DOWN
	pv = pv.normalized()
	var e := s + dir * cos(ang) * l1 + pv * sin(ang) * l1
	var q1 := Quaternion((B.REST[fa] - B.REST[ua]).normalized(), (e - s).normalized())
	g[ua] = Transform3D(Basis(q1), s)
	var q2 := Quaternion((B.REST[hd] - B.REST[fa]).normalized(), (target - e).normalized())
	g[fa] = Transform3D(Basis(q2), e)
	g[hd] = Transform3D(Basis(q2), e + Basis(q2) * (B.REST[hd] - B.REST[fa]))


## How far the body must rise so its lowest vertex touches y = 0.
static func ground_lift(g: Array[Transform3D], geo: UnitGeo) -> float:
	var low := INF
	for k in geo.pos.size():
		var b: int = geo.bone[k]
		low = minf(low, (g[b] * (geo.pos[k] - B.REST[b])).y)
	return -low


static func lift(g: Array[Transform3D], dy: float) -> void:
	for i in g.size():
		var t := g[i]
		t.origin.y += dy
		g[i] = t


## Blends two finished poses (for cross-fades between clips).
static func blend_globals(ga: Array[Transform3D], gb: Array[Transform3D], t: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.resize(ga.size())
	for i in ga.size():
		out[i] = ga[i].interpolate_with(gb[i], t)
	return out
