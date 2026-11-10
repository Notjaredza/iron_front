class_name Zombie
extends Soldier
## One zombie (Question Chat, 2026-11-10): a dead soldier on the soldier skeleton (ZombieBuilder), so every
## pose, clip, IK hand and death works as for our own men. Adds:
##   kind       "shambler", "runner" or "brute" (the brute is the same skeleton scaled up 1.25)
##   legless    both shins gone below the knee (shot off): the stumps stay, it crawls on its arms
##   burning    0..1 how charred it is (the tool adds the flames)

const ZB := preload("res://scripts/units/zombie_builder.gd")

var kind := "shambler"
var legless := false
var _base_cols := PackedColorArray()


func setup(seed_value: int, lod_level := 0, role_name := "") -> Soldier:
	kind = "shambler" if role_name.is_empty() else role_name
	lod = lod_level
	look = ZB.look_for_kind(seed_value, kind)
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
	geo = ZB.build(look, lod)
	_base_cols = geo.col.duplicate()
	mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "Body"
	mesh_inst.mesh = geo.to_mesh(material())
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	mesh_inst.skin = skel.create_skin_from_rest_transforms()
	if kind == "brute":
		scale = Vector3.ONE * ZB.BRUTE_SCALE
	return self


## Shins shot away: the lower legs shrink to nothing at the knee.
func set_legless(on: bool) -> void:
	legless = on
	var s := Vector3.ONE * (0.02 if on else 1.0)
	skel.set_bone_pose_scale(B.SHIN_R, s)
	skel.set_bone_pose_scale(B.SHIN_L, s)


## Charred by fire, 0 (as built) to 1 (black).
func set_burnt(u: float) -> void:
	var cols := _base_cols.duplicate()
	for i in cols.size():
		cols[i] = cols[i].lerp(Color(0.08, 0.07, 0.06), clampf(u, 0.0, 1.0) * 0.85)
	geo.col = cols
	mesh_inst.mesh = geo.to_mesh(material())
