extends SceneTree
## Red jackets: a headless check that every role builds and every clip samples (Building Chat 1, 2026-11-10).
##   Godot --headless --path iron_front -s res://tools/redcoat_check.gd
func _initialize() -> void:
	var lib := Redcoat.library()
	print("clips: ", lib.size())
	for role in ["musketeer", "officer", "drummer", "ensign"]:
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
	print("REDCOAT CHECK OK")
	quit()
