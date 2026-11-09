class_name Soldier
extends Node3D
## One Iron Front rifleman: a Skeleton3D plus one skinned, flat-shaded mesh built
## by SoldierBuilder. Poses and clips come from the shared animation library
## (scripts/units/anim): body bones by angles, feet and hands by two-bone IK, the
## figure set on the ground by its lowest point.

const B := preload("res://scripts/units/soldier_builder.gd")
const DEG := PI / 180.0
const Rig := preload("res://scripts/units/anim/rig.gd")
const Anim := preload("res://scripts/units/anim/anim.gd")
const R := preload("res://scripts/units/anim/clips_rifle.gd")
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


func setup(seed_value: int, lod_level := 0, role := "") -> Soldier:
	lod = lod_level
	look = B.look_from_seed(seed_value) if role.is_empty() else B.look_for_role(seed_value, role)
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


## The named poses come from the shared animation library (anim/clips_rifle.gd).
static func pose_spec(pose_name: String) -> Dictionary:
	return R.poses().get(pose_name, {})


func set_pose(pose_name: String) -> void:
	var p := pose_spec(pose_name)
	var g := Rig.solve(p, p, 0.0)
	Rig.lift(g, Rig.ground_lift(g, geo))
	Anim.apply(skel, g)


## Shows one moment of a clip (model-space pose from Anim.sample).
func show_clip(clip: Dictionary, time: float) -> void:
	Anim.apply(skel, Anim.sample(clip, time, geo))


func show_globals(g: Array[Transform3D]) -> void:
	Anim.apply(skel, g)


## Poses from a spec. world_hands: "hand_r"/"hand_l" -> a world point the palm must reach.
func pose_spec_world(spec: Dictionary, world_hands := {}) -> void:
	pose_blend_world(spec, spec, 0.0, world_hands, world_hands)


## Blends spec a into b at u, with hands on world points (ha for a, hb for b).
## Solved twice so the ground lift does not pull the hands off their marks.
## Returns the model-space pose it set.
func pose_blend_world(a: Dictionary, b: Dictionary, u: float, ha := {}, hb := {}, ground := true) -> Array[Transform3D]:
	var pa := a.duplicate()
	var pb := b.duplicate()
	var lift_y := 0.0
	var inv := global_transform.affine_inverse()
	var g: Array[Transform3D]
	for it in 2:
		for k in ha:
			pa[k] = [-1, inv * (ha[k] as Vector3) - Vector3(0, lift_y, 0)]
		for k in hb:
			pb[k] = [-1, inv * (hb[k] as Vector3) - Vector3(0, lift_y, 0)]
		g = Rig.solve(pa, pb, u)
		if not ground:
			break
		var l2 := Rig.ground_lift(g, geo)
		if it == 1 or (ha.is_empty() and hb.is_empty()):
			Rig.lift(g, l2)
			break
		lift_y = l2
	Anim.apply(skel, g)
	return g


## A spec with its world hands turned into this soldier's model space (for clips).
func spec_local(spec: Dictionary, world_hands: Dictionary, lift_y := 0.0) -> Dictionary:
	var p := spec.duplicate()
	var inv := global_transform.affine_inverse()
	for k in world_hands:
		p[k] = [-1, inv * (world_hands[k] as Vector3) - Vector3(0, lift_y, 0)]
	return p


## Hangs a prop on a bone (its frame: the bone's joint, rest-aligned axes).
func attach(bone_id: int, prop: Node3D, local: Transform3D) -> Node3D:
	var att := BoneAttachment3D.new()
	att.bone_name = B.BONE_NAMES[bone_id]
	skel.add_child(att)
	prop.transform = local
	att.add_child(prop)
	return prop
