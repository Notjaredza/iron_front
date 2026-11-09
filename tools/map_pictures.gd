extends SceneTree
## Iron Front: pictures of the map test (window run). It builds the map and puts the camera at:
## - the whole map;
## - cliffs and a ramp;
## - a village with a station;
## - a broken rail line;
## - a river;
## - eye level at a ramp.
## It takes these by day, and the cliffs, village and whole map at night and in fog too.
## Run:  Godot --path . --resolution 1600x900 --script res://tools/map_pictures.gd [-- --seed=N --out=prefix]
## Writes results/<prefix>_<view>_<look>.png and ends with "MAP PICTURES DONE n".

var main: Node3D
var out := "map"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	while not main.ready_map:
		await process_frame
	var cam: RtsCamera = main.cam
	var view: MapView = main.view
	var d := view.data
	cam.enabled = false
	var views := _views(d)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://results"))
	var n := 0
	for v: Array in views:
		for look: int in v[4]:
			view.set_look(look)
			cam.target = v[1]
			cam.height = v[2]
			cam.height_goal = v[2]
			cam.yaw = v[3]
			for f in 3:
				cam.place()
				view.follow(cam.height)
				await process_frame
			for f in 20:
				await process_frame
			var img := root.get_viewport().get_texture().get_image()
			var path := "res://results/%s_%s_%s.png" % [out, v[0], view.look_name()]
			img.save_png(ProjectSettings.globalize_path(path))
			n += 1
	print("MAP PICTURES DONE %d" % n)
	quit()


## [name, target, height, yaw, looks]
func _views(d: MapData) -> Array:
	var sz := d.size_m()
	var all := [MapView.Look.DAY, MapView.Look.NIGHT, MapView.Look.FOG]
	var day := [MapView.Look.DAY]
	var out_v: Array = [["whole", Vector3(sz.x * 0.5, 0, sz.y * 0.55), 6500.0, 0.0, all]]
	out_v.append(["region", Vector3(sz.x * 0.5, 0, sz.y * 0.5), 1400.0, 0.4, day])
	# A wide ramp seen from below it, looking up the ramp.
	for r in d.ramps:
		if int(r["w"]) >= 3 and int(r["t"]) == 2:
			var p := _ramp_point(r)
			var up := -Vector3(r["s"], 0, 0) if int(r["axis"]) == 0 else -Vector3(0, 0, r["s"])
			var yaw := atan2(up.x, up.z)
			out_v.append(["cliffs", p, 160.0, yaw, all])
			out_v.append(["ramp_eye", p - up * 30.0, 2.0, yaw, day])
			break
	for p in d.places:
		if p["station"]:
			var c: Vector2 = p["pos"]
			out_v.append(["village", Vector3(c.x, 0, c.y), 120.0, 0.6, all])
			break
	for p in d.places:
		if p["kind"] == "ruin":
			var c: Vector2 = p["pos"]
			out_v.append(["ruins", Vector3(c.x, 0, c.y), 90.0, 2.2, day])
			break
	for rl in d.rails:
		for s in rl["sections"]:
			if s["broken"] and float(s["to"]) - float(s["from"]) > 300.0:
				var pts: PackedVector2Array = rl["pts"]
				var q := _point_at(pts, (float(s["from"]) + float(s["to"])) * 0.5)
				out_v.append(["broken_rail", Vector3(q.x, 0, q.y), 70.0, 1.0, day])
				break
		if out_v[out_v.size() - 1][0] == "broken_rail":
			break
	# A river: the water cell nearest the map centre.
	var best := INF
	var wp := Vector3.ZERO
	for z in range(0, d.h, 4):
		for x in range(0, d.w, 4):
			if d.walk[z * d.w + x] == 0:
				var p := Vector2(x, z) * MapData.CELL
				var dd := p.distance_to(sz * 0.5)
				if dd < best:
					best = dd
					wp = Vector3(p.x, 0, p.y)
	if best < INF:
		out_v.append(["water", wp, 260.0, 0.8, day])
	return out_v


func _ramp_point(r: Dictionary) -> Vector3:
	var along: float = float(r["e"]) + 2.0 * int(r["s"])
	var across: float = int(r["a"]) + int(r["w"]) * 0.5
	var c := MapData.CELL
	return Vector3(along * c, 0, across * c) if int(r["axis"]) == 0 else Vector3(across * c, 0, along * c)


func _point_at(pts: PackedVector2Array, s: float) -> Vector2:
	var acc := 0.0
	for k in range(1, pts.size()):
		var l := pts[k].distance_to(pts[k - 1])
		if acc + l >= s:
			return pts[k - 1].lerp(pts[k], (s - acc) / l)
		acc += l
	return pts[pts.size() - 1]
