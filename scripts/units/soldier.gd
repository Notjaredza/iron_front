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
