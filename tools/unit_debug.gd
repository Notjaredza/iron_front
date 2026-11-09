extends SceneTree
## Prints where the rifle butt, shoulders and hands end up in each pose (headless check).

const B := preload("res://scripts/units/soldier_builder.gd")


func _initialize() -> void:
	for p in Soldier.POSE_NAMES:
		var s := Soldier.new().setup(1, 0)
		root.add_child(s)
		s.set_pose(p)
		var sk := s.skel
		var g := func(i: int) -> Vector3: return sk.get_bone_global_pose(i).origin
		var rifle: Transform3D = sk.get_bone_global_pose(B.RIFLE)
		print("%s: butt %s  shoulderR %s  handR %s  gripR %s  handL %s  gripL %s" % [p,
			rifle * B.BUTT, g.call(B.UARM_R), g.call(B.HAND_R), rifle * B.GRIP_R, g.call(B.HAND_L), rifle * B.GRIP_L])
		s.free()
	quit()
