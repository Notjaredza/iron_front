extends SceneTree
## Red jackets: a headless check that every role builds and every clip samples (Building Chat 1, 2026-11-10).
##   Godot --headless --path iron_front -s res://tools/redcoat_check.gd
func _initialize() -> void:
	var lib := Redcoat.library()
	print("clips: ", lib.size())
	for role in ["musketeer", "officer", "drummer", "ensign", "grenadier", "light", "dragoon", "gunner_sponge", "gunner_load", "gunner_vent", "gunner_aim", "gunner_fire"]:
		for lod in 3:
			var r := Redcoat.new().setup(5, lod, role)
			root.add_child(r)
			print(role, " lod", lod, " tris ", r.tri_count())
	var m := Redcoat.new().setup(5, 0, "musketeer")
	root.add_child(m)
	for n: String in lib:
		var c: Dictionary = lib[n]
		var t := 0.0
		while t <= float(c["len"]):
			m.show_clip(c, t)
			t += 0.25
		print(n, " len ", snappedf(float(c["len"]), 0.01))
	var cn := FieldCannon.new().setup(0)
	root.add_child(cn)
	cn.set_state(0.8, 4.0)
	print("cannon tris ", cn.tri_count(), " muzzle ", cn.muzzle_at(), " vent ", cn.vent_at())
	for gait in ["walk", "trot", "gallop", "charge"]:
		var h := Horse.new().setup(2, 0)
		root.add_child(h)
		h.show_pose(Horse.gait_pose(gait, 0.3))
		print("horse ", gait, " tris ", h.tri_count())
	var hf := Horse.new().setup(3, 1)
	root.add_child(hf)
	hf.show_pose(Horse.fall_pose(0.8))
	hf.show_pose(Horse.rear_pose(1.0))
	const M2 := preload("res://scripts/units/anim/clips_redcoat2.gd")
	for role: String in M2.CREW:
		var gm := Redcoat.new().setup(4, 0, role)
		root.add_child(gm)
		for step: String in M2.DRILL:
			var pl: Array = M2.crew_place(role, step, 0.0)
			var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(pl[1])), pl[0])
			gm.show_spec(M2.crew_spec(role, step, cn, xf.affine_inverse()))
	var dr := Redcoat.new().setup(4, 0, "dragoon")
	root.add_child(dr)
	for k: String in ["carry", "point", "raise", "cut"]:
		dr.show_spec(M2.ride(k), false)
	print("REDCOAT CHECK OK")
	quit()
