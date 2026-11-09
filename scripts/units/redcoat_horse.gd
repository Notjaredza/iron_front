class_name Horse
extends Node3D
## Red coats round 2: a cavalry horse, its own skeleton and gaits (Building Chat 1, 2026-11-10).
## Faces -Z like the men; withers about 1.55 m. Gaits are worked out by phase (FK): walk (four beats), trot
## (diagonal pairs), gallop (four beats with a moment in the air), charge (a flat-out gallop, the head low), and
## a fall onto its side. The saddle cloth is in the regiment's facing colour. The rider sits on saddle_xf().

const DEG := PI / 180.0
enum { ROOT, BODY, NECK, HEAD, TAIL, FR_UP, FR_LO, FR_PAS, FL_UP, FL_LO, FL_PAS, HR_UP, HR_LO, HR_PAS, HL_UP, HL_LO, HL_PAS }
const NAMES: Array[String] = ["root", "body", "neck", "head", "tail", "fr_up", "fr_lo", "fr_pas", "fl_up", "fl_lo", "fl_pas",
	"hr_up", "hr_lo", "hr_pas", "hl_up", "hl_lo", "hl_pas"]
const PARENT: Array[int] = [-1, 0, 1, 2, 1, 1, 5, 6, 1, 8, 9, 1, 11, 12, 1, 14, 15]
const REST: Array[Vector3] = [Vector3.ZERO, Vector3(0, 1.28, 0), Vector3(0, 1.42, -0.66), Vector3(0, 1.92, -1.02),
	Vector3(0, 1.42, 0.8),
	Vector3(0.16, 1.1, -0.55), Vector3(0.16, 0.56, -0.57), Vector3(0.16, 0.2, -0.57),
	Vector3(-0.16, 1.1, -0.55), Vector3(-0.16, 0.56, -0.57), Vector3(-0.16, 0.2, -0.57),
	Vector3(0.17, 1.18, 0.58), Vector3(0.17, 0.6, 0.76), Vector3(0.17, 0.2, 0.7),
	Vector3(-0.17, 1.18, 0.58), Vector3(-0.17, 0.6, 0.76), Vector3(-0.17, 0.2, 0.7)]
## Legs: [upper, lower, pastern, side (+1 right), front?]
const LEGS := [[FR_UP, FR_LO, FR_PAS, 1.0, true], [FL_UP, FL_LO, FL_PAS, -1.0, true],
	[HR_UP, HR_LO, HR_PAS, 1.0, false], [HL_UP, HL_LO, HL_PAS, -1.0, false]]
const COATS := {"bay": [Color(0.40, 0.22, 0.11), Color(0.07, 0.06, 0.06)], "black": [Color(0.09, 0.08, 0.08), Color(0.05, 0.05, 0.05)],
	"chestnut": [Color(0.55, 0.29, 0.12), Color(0.48, 0.24, 0.10)], "grey": [Color(0.70, 0.70, 0.68), Color(0.35, 0.35, 0.36)]}
const LEATHER := Color(0.30, 0.18, 0.10)
const LEATHER_BLK := Color(0.07, 0.065, 0.06)
const STEEL := Color(0.62, 0.64, 0.66)
const HOOF := Color(0.13, 0.12, 0.11)
## Gaits: speed m/s, cycle s, stance share, leg phases [FR, FL, HR, HL], swing and flex sizes, body pitch and bob.
const GAITS := {
	"walk": {"v": 1.6, "T": 1.1, "duty": 0.62, "ph": [0.25, 0.75, 0.0, 0.5], "fwd": 22.0, "back": 20.0, "flex": 55.0,
		"bob": 0.025, "pitch": 1.5, "neck": 6.0, "head_low": 0.0},
	"trot": {"v": 3.6, "T": 0.72, "duty": 0.46, "ph": [0.0, 0.5, 0.5, 0.0], "fwd": 26.0, "back": 22.0, "flex": 85.0,
		"bob": 0.05, "pitch": 1.5, "neck": 3.0, "head_low": 0.0},
	"gallop": {"v": 8.5, "T": 0.6, "duty": 0.34, "ph": [0.6, 0.48, 0.12, 0.0], "fwd": 38.0, "back": 34.0, "flex": 100.0,
		"bob": 0.09, "pitch": 6.0, "neck": 10.0, "head_low": 8.0},
	"charge": {"v": 11.0, "T": 0.52, "duty": 0.3, "ph": [0.6, 0.48, 0.12, 0.0], "fwd": 44.0, "back": 40.0, "flex": 110.0,
		"bob": 0.11, "pitch": 8.0, "neck": 12.0, "head_low": 22.0},
}

var skel: Skeleton3D
var mesh_inst: MeshInstance3D
var geo: UnitGeo
var coat := "bay"
var cloth := Color(0.75, 0.66, 0.42)
var att_body: BoneAttachment3D
static var _meshes := {}


func setup(seed_value: int, lod := 0, facing := Color(0.75, 0.66, 0.42)) -> Horse:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 977 + 13
	coat = ["bay", "bay", "black", "chestnut", "bay", "black"][r.randi() % 6]
	cloth = facing
	skel = Skeleton3D.new()
	add_child(skel)
	for i in NAMES.size():
		skel.add_bone(NAMES[i])
	for i in NAMES.size():
		var off: Vector3 = REST[i] if PARENT[i] < 0 else REST[i] - REST[PARENT[i]]
		if PARENT[i] >= 0:
			skel.set_bone_parent(i, PARENT[i])
		skel.set_bone_rest(i, Transform3D(Basis(), off))
		skel.set_bone_pose_position(i, off)
	var key := "%s_%d_%s" % [coat, lod, facing.to_html()]
	if not _meshes.has(key):
		var g := build(coat, facing, lod)
		_meshes[key] = [g.to_mesh(Soldier.material()), g.tri_count()]
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = _meshes[key][0]
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	mesh_inst.skin = skel.create_skin_from_rest_transforms()
	att_body = BoneAttachment3D.new()
	att_body.bone_name = NAMES[BODY]
	skel.add_child(att_body)
	return self


func tri_count() -> int:
	for k in _meshes:
		if _meshes[k][0] == mesh_inst.mesh:
			return _meshes[k][1]
	return 0


## Where the rider's seat is, in the body bone's frame (put the rider under att_body with this).
static func seat_local() -> Vector3:
	return Vector3(0, 0.33, 0.02)


# ---------------------------------------------------------------- poses

## A gait's pose at time t: {bone: Euler deg}, plus "root_pos" and "root_rot".
static func gait_pose(gait: String, t: float) -> Dictionary:
	var p: Dictionary = GAITS[gait]
	var T: float = p["T"]
	var u := fposmod(t / T, 1.0)
	var rot := {}
	var duty: float = p["duty"]
	for i in 4:
		var L: Array = LEGS[i]
		var ph := fposmod(u - float(p["ph"][i]), 1.0)
		var fwd: float = p["fwd"]
		var back: float = p["back"]
		var up_a := 0.0
		var flex := 0.0
		if ph < duty:
			# Stance: the hoof planted, the leg sweeping from forward to back.
			up_a = lerpf(fwd, -back, ph / duty)
		else:
			var s := (ph - duty) / (1.0 - duty)
			up_a = lerpf(-back, fwd, 0.5 - 0.5 * cos(PI * s))
			flex = float(p["flex"]) * sin(PI * pow(s, 0.8))
		var front: bool = L[4]
		if front:
			# Front: the knee folds the hoof up behind, the pastern folds more.
			rot[L[0]] = Vector3(up_a * 0.8, 0, 0)
			rot[L[1]] = Vector3(-flex * 0.9, 0, 0)
			rot[L[2]] = Vector3(-flex * 0.5, 0, 0)
		else:
			# Hind: the hip swings the thigh, the hock folds the cannon forward, the fetlock flips back.
			rot[L[0]] = Vector3(up_a * 0.75 + flex * 0.25, 0, 0)
			rot[L[1]] = Vector3(flex * 0.55, 0, 0)
			rot[L[2]] = Vector3(-flex * 0.6, 0, 0)
	var bob: float = p["bob"]
	var pitch: float = p["pitch"]
	var a := TAU * u * (2.0 if gait in ["walk", "trot"] else 1.0)
	rot[NECK] = Vector3(-float(p["head_low"]) + float(p["neck"]) * sin(a + 0.6), 0, 0)
	rot[HEAD] = Vector3(float(p["head_low"]) * 0.5 - float(p["neck"]) * 0.4 * sin(a + 0.6), 0, 0)
	rot[TAIL] = Vector3(25.0 + 6.0 * sin(a) + (25.0 if gait in ["gallop", "charge"] else 0.0), 0, 0)
	rot[BODY] = Vector3(pitch * sin(a), 0, 0)
	return {"rot": rot, "root_pos": Vector3(0, bob * sin(a + 1.0), 0)}


static func stand_pose() -> Dictionary:
	return {"rot": {NECK: Vector3(4, 0, 0), HEAD: Vector3(-2, 0, 0), TAIL: Vector3(18, 0, 0)}, "root_pos": Vector3.ZERO}


## Rearing at the halt (the charge's end, or a shell close by): u 0..1 up, 1..2 down.
static func rear_pose(u: float) -> Dictionary:
	var k := sin(PI * clampf(u, 0.0, 2.0) * 0.5)
	return {"rot": {NECK: Vector3(-20.0 * k, 0, 0), HEAD: Vector3(-10.0 * k, 0, 0),
		FR_UP: Vector3(60.0 * k, 0, 0), FR_LO: Vector3(-95.0 * k, 0, 0), FR_PAS: Vector3(-30.0 * k, 0, 0),
		FL_UP: Vector3(48.0 * k, 0, 0), FL_LO: Vector3(-100.0 * k, 0, 0), FL_PAS: Vector3(-30.0 * k, 0, 0),
		HR_UP: Vector3(-30.0 * k, 0, 0), HR_LO: Vector3(12.0 * k, 0, 0), HL_UP: Vector3(-34.0 * k, 0, 0), HL_LO: Vector3(10.0 * k, 0, 0),
		TAIL: Vector3(10, 0, 0)}, "pivot_hind": 38.0 * k}


## Falling onto its left side, legs folding and then thrashing a little: u 0..1.
static func fall_pose(u: float) -> Dictionary:
	var k := smoothstep(0.0, 1.0, u)
	var drop := smoothstep(0.0, 0.7, u)
	var kick := sin(u * 18.0) * 10.0 * smoothstep(0.6, 1.0, u)
	var rot := {BODY: Vector3(10.0 * sin(PI * minf(u * 1.6, 1.0)), 0, 0), NECK: Vector3(-20.0 * drop, 0, -15.0 * k),
		HEAD: Vector3(25.0 * drop, 0, 0), TAIL: Vector3(8, 0, 0),
		FR_UP: Vector3(50.0 * drop + kick, 0, 0), FR_LO: Vector3(-110.0 * drop, 0, 0), FR_PAS: Vector3(-40.0 * drop, 0, 0),
		FL_UP: Vector3(30.0 * drop, 0, 0), FL_LO: Vector3(-80.0 * drop, 0, 0),
		HR_UP: Vector3(-30.0 * drop - kick, 0, 0), HR_LO: Vector3(40.0 * drop, 0, 0),
		HL_UP: Vector3(20.0 * drop, 0, 0), HL_LO: Vector3(30.0 * drop, 0, 0)}
	return {"rot": rot, "root_rot": Vector3(0, 0, 82.0 * k), "root_pos": Vector3(0.0, 0, 0), "fall": k}


## Bone transforms (model space) for a pose; the lowest hoof is put on the ground unless the pose says otherwise.
static func solve(p: Dictionary) -> Array[Transform3D]:
	var g: Array[Transform3D] = []
	g.resize(NAMES.size())
	var rot: Dictionary = p.get("rot", {})
	g[0] = Transform3D(Basis.from_euler((p.get("root_rot", Vector3.ZERO) as Vector3) * DEG), p.get("root_pos", Vector3.ZERO))
	if p.has("pivot_hind"):
		# Rearing turns the whole horse about the hind hooves (+ = the front up).
		var piv := Vector3(0, 0, 0.7)
		var rb := Basis.from_euler(Vector3(float(p["pivot_hind"]), 0, 0) * DEG)
		g[0] = Transform3D(rb, piv - rb * piv)
	for i in range(1, NAMES.size()):
		var q := Basis.from_euler((rot.get(i, Vector3.ZERO) as Vector3) * DEG)
		g[i] = g[PARENT[i]] * Transform3D(q, REST[i] - REST[PARENT[i]])
	# Ground: the lowest hoof (or, falling, the lowest of the body's side) on y = 0.
	var low := INF
	for L: Array in LEGS:
		low = minf(low, (g[L[2]] * Vector3(0, -0.2, -0.05)).y)
	if p.has("fall"):
		var side := (g[BODY] * Vector3(0.33, 0, 0)).y
		var side2 := (g[BODY] * Vector3(-0.33, 0, 0)).y
		low = lerpf(low, minf(side, side2), float(p["fall"]))
	for i in g.size():
		g[i].origin.y -= low
	return g


func show_pose(p: Dictionary) -> void:
	var g := solve(p)
	for i in NAMES.size():
		var loc := g[i] if PARENT[i] < 0 else g[PARENT[i]].affine_inverse() * g[i]
		skel.set_bone_pose_position(i, loc.origin)
		skel.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())


# ---------------------------------------------------------------- the mesh

static func build(coat_name: String, facing: Color, lod: int) -> UnitGeo:
	var g := UnitGeo.new()
	var d0 := lod == 0
	var sides := 8 if d0 else 5
	var ch := 0.3 if d0 else 0.0
	var X := Vector3.RIGHT
	var cc: Array = COATS[coat_name]
	var hide: Color = cc[0]
	var points: Color = cc[1]
	# The barrel: chest to rump, the withers and croup higher, the belly round.
	g.loft([Vector3(0, 1.22, -0.86), Vector3(0, 1.27, -0.66), Vector3(0, 1.25, -0.2), Vector3(0, 1.27, 0.35), Vector3(0, 1.3, 0.72),
		Vector3(0, 1.28, 0.9)],
		[Vector2(0.15, 0.19), Vector2(0.24, 0.3), Vector2(0.28, 0.32), Vector2(0.27, 0.31), Vector2(0.25, 0.27), Vector2(0.12, 0.14)],
		X, 10 if d0 else 6, 0.0, hide, BODY)
	# The neck, up and forward from the withers; the mane along its crest.
	g.loft([Vector3(0, 1.36, -0.62), Vector3(0, 1.6, -0.84), Vector3(0, 1.9, -1.0)],
		[Vector2(0.14, 0.27), Vector2(0.11, 0.2), Vector2(0.075, 0.11)], X, sides, ch, hide, NECK)
	g.loft([Vector3(0, 1.62, -0.6), Vector3(0, 1.84, -0.86), Vector3(0, 2.0, -1.0)],
		[Vector2(0.025, 0.05), Vector2(0.03, 0.05), Vector2(0.025, 0.035)], X, 4, 0.0, points, NECK)
	# The head: poll to muzzle, the cheek wide, the nose long; ears, eyes, nostrils.
	g.loft([Vector3(0, 1.98, -1.0), Vector3(0, 1.9, -1.1), Vector3(0, 1.72, -1.3), Vector3(0, 1.58, -1.44)],
		[Vector2(0.065, 0.07), Vector2(0.09, 0.11), Vector2(0.065, 0.085), Vector2(0.06, 0.07)], X, sides, ch, hide, HEAD)
	g.box(Vector3(0, 1.57, -1.43), Vector3(0.062, 0.055, 0.04), points.lerp(hide, 0.4).darkened(0.25), HEAD)
	for s: float in [1.0, -1.0]:
		g.loft([Vector3(0.045 * s, 2.0, -1.02), Vector3(0.06 * s, 2.12, -1.0)], [Vector2(0.025, 0.018), Vector2(0.006, 0.006)],
			X, 4, 0.0, hide.darkened(0.15), HEAD)
		if d0:
			g.box(Vector3(0.085 * s, 1.88, -1.13), Vector3(0.008, 0.016, 0.02), Color(0.05, 0.04, 0.04), HEAD)
	# The tail: the dock then the long hair.
	g.loft([Vector3(0, 1.42, 0.86), Vector3(0, 1.3, 0.98), Vector3(0, 0.95, 1.03), Vector3(0, 0.7, 1.0)],
		[Vector2(0.05, 0.05), Vector2(0.07, 0.07), Vector2(0.08, 0.06), Vector2(0.03, 0.03)], X, 5, 0.0, points, TAIL)
	# Legs.
	for L: Array in LEGS:
		var s: float = L[3]
		var front: bool = L[4]
		var up: int = L[0]
		var lo: int = L[1]
		var pa: int = L[2]
		var j0: Vector3 = REST[up]
		var j1: Vector3 = REST[lo]
		var j2: Vector3 = REST[pa]
		var ls := 6 if d0 else 4
		if front:
			# Forearm, muscled at the top; the knee; the cannon; fetlock, pastern, hoof.
			g.loft([j0 + Vector3(0, 0.12, 0.02), j0 + Vector3(0, -0.12, 0), j1 + Vector3(0, 0.04, 0)],
				[Vector2(0.09, 0.16), Vector2(0.075, 0.11), Vector2(0.05, 0.06)], X, ls, 0.0, hide, up)
		else:
			# Thigh and gaskin down to the hock.
			g.loft([j0 + Vector3(0, 0.16, -0.08), j0 + Vector3(0, -0.12, 0.06), j1 + Vector3(0, 0.06, 0)],
				[Vector2(0.1, 0.24), Vector2(0.075, 0.15), Vector2(0.045, 0.07)], X, ls, 0.0, hide, up)
		var low_col := points if coat_name == "bay" or coat_name == "black" else hide
		g.loft([j1 + Vector3(0, 0.04, 0), j2 + Vector3(0, 0.02, 0)], [Vector2(0.042, 0.055), Vector2(0.036, 0.045)],
			X, 4, 0.0, low_col, lo)
		g.loft([j2 + Vector3(0, 0.02, 0), j2 + Vector3(0, -0.12, -0.03), j2 + Vector3(0, -0.17, -0.04)],
			[Vector2(0.04, 0.05), Vector2(0.035, 0.04), Vector2(0.045, 0.05)], X, 4, 0.0, low_col, pa)
		g.loft([j2 + Vector3(0, -0.15, -0.045), j2 + Vector3(0, -0.2, -0.05)], [Vector2(0.048, 0.055), Vector2(0.052, 0.06)],
			X, 4, 0.0, HOOF, pa, null, 1)
	# Tack: the saddle cloth (shabraque) in the facing colour, laced; the saddle; holsters; rolled cloak; stirrups.
	var cloth_c := Vector3(0, 1.52, 0.05)
	for s: float in [1.0, -1.0]:
		var top0 := Vector3(0.22 * s, 1.56, -0.3)
		var top1 := Vector3(0.22 * s, 1.58, 0.42)
		var bot0 := Vector3(0.36 * s, 1.06, -0.36)
		var bot1 := Vector3(0.36 * s, 1.04, 0.55)
		var a := [top0, top1, bot1, bot0] if s > 0 else [top1, top0, bot0, bot1]
		g.emit(a[0], a[1], a[2], facing, BODY)
		g.emit(a[0], a[2], a[3], facing, BODY)
		if d0:
			var lace := Color(0.92, 0.9, 0.84)
			var e0 := bot0 + (top0 - bot0) * 0.07
			var e1 := bot1 + (top1 - bot1) * 0.07
			var b := [e0, e1, bot1 + Vector3(0.004 * s, 0, 0), bot0 + Vector3(0.004 * s, 0, 0)] if s > 0 else [e1, e0, bot0 + Vector3(0.004 * s, 0, 0), bot1 + Vector3(0.004 * s, 0, 0)]
			g.emit(b[0], b[1], b[2], lace, BODY)
			g.emit(b[0], b[2], b[3], lace, BODY)
		# Stirrup leathers and irons.
		g.loft([Vector3(0.2 * s, 1.52, -0.05), Vector3(0.26 * s, 0.9, -0.06)], [Vector2(0.006, 0.02), Vector2(0.006, 0.02)],
			X, 4, 0.0, LEATHER, BODY, null, 0)
		g.box(Vector3(0.27 * s, 0.86, -0.06), Vector3(0.008, 0.04, 0.05), STEEL, BODY)
		# Holster pipes at the saddle's front.
		g.loft([Vector3(0.12 * s, 1.6, -0.36), Vector3(0.2 * s, 1.42, -0.48)], [Vector2(0.04, 0.04), Vector2(0.03, 0.03)],
			X, 4, 0.0, LEATHER_BLK, BODY, null, 1)
	g.loft([cloth_c + Vector3(0, 0.07, -0.32), cloth_c + Vector3(0, 0.03, -0.12), cloth_c + Vector3(0, 0.05, 0.2), cloth_c + Vector3(0, 0.13, 0.3)],
		[Vector2(0.15, 0.06), Vector2(0.17, 0.04), Vector2(0.17, 0.04), Vector2(0.14, 0.06)], X, 4, 0.0, LEATHER, BODY)
	g.loft([Vector3(-0.2, 1.66, 0.42), Vector3(0.2, 1.66, 0.42)], [Vector2(0.06, 0.06), Vector2(0.06, 0.06)], Vector3.UP, 6, 0.0,
		Color(0.55, 0.12, 0.10), BODY)
	# Girth, breast strap, the bridle and reins (the reins from the bit to the saddle's front).
	g.loft([Vector3(0, 1.0, -0.2), Vector3(0, 1.0, -0.12)], [Vector2(0.3, 0.3), Vector2(0.3, 0.3)], X, sides, ch, LEATHER, BODY, null, 0)
	g.loft([Vector3(0, 1.2, -0.84), Vector3(0, 1.2, -0.78)], [Vector2(0.24, 0.2), Vector2(0.25, 0.22)], X, sides, ch, LEATHER_BLK,
		BODY, null, 0)
	g.loft([Vector3(0, 1.92, -1.1), Vector3(0, 1.88, -1.12)], [Vector2(0.1, 0.12), Vector2(0.1, 0.12)], X, 6, 0.0, LEATHER_BLK, HEAD, null, 0)
	g.loft([Vector3(0, 1.66, -1.36), Vector3(0, 1.64, -1.38)], [Vector2(0.07, 0.085), Vector2(0.07, 0.085)], X, 6, 0.0, LEATHER_BLK, HEAD,
		null, 0)
	for s: float in [1.0, -1.0]:
		g.box(Vector3(0.07 * s, 1.6, -1.4), Vector3(0.01, 0.02, 0.02), STEEL, HEAD)
		g.loft([Vector3(0.075 * s, 1.6, -1.38), Vector3(0.12 * s, 1.55, -0.85), Vector3(0.11 * s, 1.62, -0.45)],
			[Vector2(0.005, 0.012), Vector2(0.005, 0.012), Vector2(0.005, 0.012)], X, 4, 0.0, LEATHER_BLK, NECK, null, 0)
	return g
