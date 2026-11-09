class_name Soldier
extends Node3D
## One Iron Front rifleman: a Skeleton3D plus one skinned, flat-shaded mesh built
## by SoldierBuilder. Poses are coded: body bones by angles, the rifle placed by
## the pose, and both arms reach the rifle by two-bone IK. The figure is then set
## on the ground by its lowest point.

const B := preload("res://scripts/units/soldier_builder.gd")
const DEG := PI / 180.0
const POSE_NAMES: Array[String] = ["stand", "run", "kneel", "aim", "prone"]

var lod := 0
var look: Dictionary = {}
var skel: Skeleton3D
var geo: UnitGeo
var mesh_inst: MeshInstance3D

static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.88
		_mat.metallic_specular = 0.2
	return _mat


func setup(seed_value: int, lod_level := 0) -> Soldier:
	lod = lod_level
	look = B.look_from_seed(seed_value)
	skel = Skeleton3D.new()
	skel.name = "Skeleton"
	add_child(skel)
	for i in B.BONE_NAMES.size():
		skel.add_bone(B.BONE_NAMES[i])
	for i in B.BONE_NAMES.size():
		var par: int = B.BONE_PARENT[i]
		var off: Vector3 = B.REST[i] if par < 0 else B.REST[i] - B.REST[par]
		if par >= 0:
			skel.set_bone_parent(i, par)
		skel.set_bone_rest(i, Transform3D(Basis(), off))
		skel.set_bone_pose_position(i, off)
		skel.set_bone_pose_rotation(i, Quaternion())
	geo = B.build(look, lod)
	mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "Body"
	mesh_inst.mesh = geo.to_mesh(material())
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	mesh_inst.skin = skel.create_skin_from_rest_transforms()
	return self


func tri_count() -> int:
	return geo.tri_count()


## The pose specs. rot: bone -> Euler degrees (YXZ) in the parent's frame.
## rifle: where the rifle goes. hands: "grip" (IK to the rifle) or "free".
static func pose_spec(pose_name: String) -> Dictionary:
	match pose_name:
		"stand":
			return {
				"rot": {B.THIGH_R: Vector3(0, 0, 3), B.THIGH_L: Vector3(0, 0, -3), B.FOOT_R: Vector3(0, 0, -3),
					B.FOOT_L: Vector3(0, 0, 3), B.SPINE: Vector3(-2, 0, 0), B.CHEST: Vector3(2, 0, 0),
					B.UARM_L: Vector3(2, 0, -5), B.FARM_L: Vector3(8, 0, 0)},
				"rifle": {"mode": "order", "butt": Vector3(0.27, 0.015, -0.07)},
				"hand_r": Vector3(0, 0, -0.45), "pole_r": Vector3(0.25, -0.3, 0.45),
				"hand_l": null,
			}
		"run":
			return {
				"rot": {B.SPINE: Vector3(-12, 0, 0), B.CHEST: Vector3(-6, 0, 0), B.NECK: Vector3(8, 0, 0),
					B.HEAD: Vector3(10, 0, 0), B.THIGH_R: Vector3(42, 0, 2), B.SHIN_R: Vector3(-38, 0, 0),
					B.FOOT_R: Vector3(12, 0, 0), B.THIGH_L: Vector3(-28, 0, -2), B.SHIN_L: Vector3(-78, 0, 0),
					B.FOOT_L: Vector3(-25, 0, 0)},
				"rifle": {"mode": "chest", "dir": Vector3(-0.5, 0.75, -0.42), "up": Vector3(0.3, 0.2, -1.0),
					"grip": Vector3(0.13, -0.20, -0.21)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.45, -0.3, 0.2),
				"hand_l": B.GRIP_L, "pole_l": Vector3(-0.5, -0.4, 0.1),
			}
		"kneel":
			return {
				"rot": {B.HIPS: Vector3(0, -28, 0), B.THIGH_R: Vector3(-8, 0, 4), B.SHIN_R: Vector3(-85, 0, 0),
					B.FOOT_R: Vector3(55, 0, 0), B.THIGH_L: Vector3(82, 22, -4), B.SHIN_L: Vector3(-84, 0, 0),
					B.FOOT_L: Vector3(2, 0, 0), B.SPINE: Vector3(-9, 0, 0), B.CHEST: Vector3(-5, -8, 0),
					B.NECK: Vector3(-10, 16, 0), B.HEAD: Vector3(-8, 10, -14)},
				"rifle": {"mode": "aim", "dir": Vector3(0, -0.03, -1)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.6, 0.05, 0.1),
				"hand_l": B.GRIP_L, "pole_l": Vector3(-0.05, -0.8, 0.05),
			}
		"aim":
			return {
				"rot": {B.HIPS: Vector3(0, -25, 0), B.THIGH_R: Vector3(-4, 0, 5), B.SHIN_R: Vector3(-2, 0, 0),
					B.THIGH_L: Vector3(10, 20, -4), B.SHIN_L: Vector3(-6, 0, 0), B.SPINE: Vector3(-8, 0, 0),
					B.CHEST: Vector3(-4, -8, 0), B.NECK: Vector3(-10, 14, 0), B.HEAD: Vector3(-8, 10, -14)},
				"rifle": {"mode": "aim", "dir": Vector3(0, -0.01, -1)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.6, 0.05, 0.1),
				"hand_l": B.GRIP_L, "pole_l": Vector3(-0.05, -0.8, 0.05),
			}
		"prone":
			return {
				"root_rot": Vector3(-90, 0, 0), "root_pos": Vector3(0, 0, 0.95),
				"rot": {B.THIGH_R: Vector3(0, 0, 9), B.THIGH_L: Vector3(0, 0, -9), B.FOOT_R: Vector3(0, -15, 0),
					B.FOOT_L: Vector3(0, 15, 0), B.SPINE: Vector3(14, 0, 0), B.CHEST: Vector3(16, 0, 0),
					B.NECK: Vector3(30, 0, 0), B.HEAD: Vector3(22, 0, -6)},
				"rifle": {"mode": "aim", "dir": Vector3(0, 0.0, -1)},
				"hand_r": B.GRIP_R, "pole_r": Vector3(0.35, -0.6, 0.0),
				"hand_l": B.GRIP_L, "pole_l": Vector3(-0.3, -0.6, -0.2),
			}
	return {}


func set_pose(pose_name: String) -> void:
	var p := pose_spec(pose_name)
	var n := B.REST.size()
	var g: Array[Transform3D] = []
	g.resize(n)
	g[0] = Transform3D(Basis.from_euler(p.get("root_rot", Vector3.ZERO) * DEG), p.get("root_pos", Vector3.ZERO))
	var rot: Dictionary = p.get("rot", {})
	for i in range(1, n):
		var par: int = B.BONE_PARENT[i]
		var r: Vector3 = rot.get(i, Vector3.ZERO)
		g[i] = g[par] * Transform3D(Basis.from_euler(r * DEG), B.REST[i] - B.REST[par])
	g[B.RIFLE] = _rifle_xf(p.get("rifle", {}), g)
	if p.get("hand_r") != null:
		_arm_ik(g, B.UARM_R, B.FARM_R, B.HAND_R, g[B.RIFLE] * (p["hand_r"] as Vector3), p.get("pole_r", Vector3(0.4, -0.4, 0.2)))
	if p.get("hand_l") != null:
		_arm_ik(g, B.UARM_L, B.FARM_L, B.HAND_L, g[B.RIFLE] * (p["hand_l"] as Vector3), p.get("pole_l", Vector3(-0.4, -0.4, 0.2)))
	# Stand on the ground: the lowest vertex goes to y = 0.
	var low := INF
	for k in geo.pos.size():
		var b: int = geo.bone[k]
		low = minf(low, (g[b] * (geo.pos[k] - B.REST[b])).y)
	for i in n:
		var t := g[i]
		t.origin.y -= low
		g[i] = t
	for i in n:
		var par: int = B.BONE_PARENT[i]
		var loc: Transform3D = g[i] if par < 0 else g[par].affine_inverse() * g[i]
		skel.set_bone_pose_position(i, loc.origin)
		skel.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())


func _rifle_xf(r: Dictionary, g: Array[Transform3D]) -> Transform3D:
	var mode: String = r.get("mode", "order")
	match mode:
		"chest":
			var bas := Basis.looking_at((r["dir"] as Vector3).normalized(), r.get("up", Vector3.UP))
			var loc := Transform3D(bas, (r["grip"] as Vector3) - bas * B.GRIP_R)
			return g[B.CHEST] * loc
		"aim":
			var butt := g[B.CHEST] * Vector3(0.12, 0.215, -0.10)
			var bas := Basis.looking_at((r["dir"] as Vector3).normalized(), Vector3.UP)
			return Transform3D(bas, butt - bas * B.BUTT)
		_:
			var bas := Basis.looking_at(Vector3.UP, Vector3.FORWARD)
			var butt: Vector3 = r.get("butt", Vector3(0.27, 0.015, -0.07))
			return g[0] * Transform3D(bas, butt - bas * B.BUTT)


## Two-bone IK: the palm reaches target, the elbow bends toward shoulder + pole.
func _arm_ik(g: Array[Transform3D], ua: int, fa: int, hd: int, target: Vector3, pole: Vector3) -> void:
	var s := g[ua].origin
	var l1 := (B.REST[fa] - B.REST[ua]).length()
	var l2 := (B.REST[hd] - B.REST[fa]).length() + B.PALM
	var d := target - s
	var dist := clampf(d.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir := d.normalized()
	var ang := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var pv := pole
	pv = (pv - dir * pv.dot(dir))
	if pv.length_squared() < 1e-8:
		pv = Vector3.DOWN
	pv = pv.normalized()
	var e := s + dir * cos(ang) * l1 + pv * sin(ang) * l1
	var q1 := Quaternion((B.REST[fa] - B.REST[ua]).normalized(), (e - s).normalized())
	g[ua] = Transform3D(Basis(q1), s)
	var q2 := Quaternion((B.REST[hd] - B.REST[fa]).normalized(), (target - e).normalized())
	g[fa] = Transform3D(Basis(q2), e)
	g[hd] = Transform3D(Basis(q2), e + Basis(q2) * (B.REST[hd] - B.REST[fa]))
