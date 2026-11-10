extends "res://tools/map_pictures.gd"
## Iron Front map round 3: pictures of the water, fords, streams, marsh, woods and fields (window run).
## Same run loop as map_pictures.gd, other views.
## Run:  Godot --path . --resolution 1600x900 --script res://tools/nature_pictures.gd [-- --seed=N --out=prefix]


func _views(d: MapData) -> Array:
	var sz := d.size_m()
	var day := [MapView.Look.DAY]
	var dn := [MapView.Look.DAY, MapView.Look.NIGHT]
	var v: Array = [["whole", Vector3(sz.x * 0.5, 0, sz.y * 0.55), 6500.0, 0.0, dn]]
	v.append(["region", Vector3(sz.x * 0.5, 0, sz.y * 0.5), 1400.0, 0.4, day])
	v.append(["region_low", Vector3(sz.x * 0.45, 0, sz.y * 0.45), 600.0, 1.1, day])
	# A ford on the wide river and one on another river: from up, close and at eye level.
	var done_wide := false
	var done_other := false
	for f: Dictionary in d.fords:
		var p0: Vector2 = f["p0"]
		var p1: Vector2 = f["p1"]
		var mid := (p0 + p1) * 0.5
		var dir := (p1 - p0).normalized()
		var yaw := atan2(dir.x, dir.y)
		var c := Vector3(mid.x, 0, mid.y)
		if int(f["river"]) == 0 and not done_wide:
			done_wide = true
			v.append(["ford_wide", c, 140.0, yaw + 0.6, dn])
			v.append(["ford_close", c, 45.0, yaw + 0.3, day])
			v.append(["ford_eye", c - Vector3(dir.x, 0, dir.y) * (p0.distance_to(p1) * 0.5 + 20.0), 2.5, yaw, day])
		elif int(f["river"]) != 0 and not done_other:
			done_other = true
			v.append(["ford_narrow", c, 90.0, yaw + 0.8, day])
	# A stream: the middle of the longest one.
	var best_s: PackedVector2Array
	for s: PackedVector2Array in d.streams:
		if s.size() > best_s.size():
			best_s = s
	if best_s.size() > 2:
		var m := best_s[best_s.size() / 2]
		var m2 := best_s[best_s.size() / 2 + 1]
		var yaw_s := atan2(m2.x - m.x, m2.y - m.y)
		v.append(["stream", Vector3(m.x, 0, m.y), 70.0, yaw_s + 0.4, day])
		v.append(["stream_eye", Vector3(m.x, 0, m.y), 3.0, yaw_s, day])
	# Marsh, woods, fields, tall grass: the first good patch of each from the centre outwards.
	var picks := {"marsh": [MapData.F_MARSH, 90.0], "woods": [MapData.F_WOOD, 160.0], "fields": [MapData.F_FIELD, 110.0], "tall": [MapData.F_TALL, 40.0]}
	for name: String in picks:
		var flag: int = picks[name][0]
		var p := _patch(d, flag)
		if p.x >= 0.0:
			v.append([name, Vector3(p.x, 0, p.y), picks[name][1], 0.9, day])
	var wp := _patch(d, MapData.F_WOOD)
	if wp.x >= 0.0:
		v.append(["woods_edge_eye", Vector3(wp.x - 60.0, 0, wp.y - 60.0), 3.0, 0.78, day])
		v.append(["woods_night", Vector3(wp.x, 0, wp.y), 160.0, 0.9, [MapView.Look.NIGHT, MapView.Look.FOG]])
	var fp := _patch(d, MapData.F_FIELD)
	if fp.x >= 0.0:
		v.append(["fields_close", Vector3(fp.x, 0, fp.y), 22.0, 0.5, day])
	return v


## The middle of a 5x5-cell block all with the flag, nearest the map centre, in metres (or -1, -1).
func _patch(d: MapData, flag: int) -> Vector2:
	var best := INF
	var out_p := Vector2(-1, -1)
	var cen := Vector2(d.w, d.h) * 0.5
	for z in range(4, d.h - 4, 6):
		for x in range(4, d.w - 4, 6):
			if not d.has(x, z, flag):
				continue
			var dd := Vector2(x, z).distance_to(cen)
			if dd >= best:
				continue
			var full := true
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					if not d.has(x + dx, z + dz, flag):
						full = false
						break
				if not full:
					break
			if full:
				best = dd
				out_p = Vector2(x + 0.5, z + 0.5) * MapData.CELL
	return out_p
