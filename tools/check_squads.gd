extends SceneTree
## Iron Front: the squads' automatic check (headless, squads round 1). For each seed it:
## 1. Builds the walk grid and times it.
## 2. Ramps: for a sample of ramps, finds a route from well below the foot to well past the top, and checks it is
##    found, never crosses a closed cell, and never jumps in height (so it really goes up the ramp).
## 3. Long routes: random pairs of open base cells far apart; times the searches.
## 4. A squad marched up a ramp: every man ends on the top level, and no man ever jumps more than 0.5 m in a frame.
## Run:  Godot --headless --path . --script res://tools/check_squads.gd [-- --seeds=1,2 --size=1000x1500]
## Ends with "SQUAD CHECK DONE <seeds> <fails>".

var fails := 0


func _initialize() -> void:
	var seeds := [1, 2]
	var w := 1000
	var h := 1500
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.substr(8).split(","):
				seeds.append(int(s))
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			w = int(p[0]) / 4 * 4
			h = int(p[1]) / 4 * 4
	for s in seeds:
		_check(s, w, h)
	print("SQUAD CHECK DONE %d %d" % [seeds.size(), fails])
	quit()


func _ok(cond: bool, what: String) -> void:
	print("CHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func _ramp_ends(d: MapData, r: Dictionary, back: int) -> Array:
	var s: int = r["s"]
	var ec := int(floor(float(r["e"])))
	var l := int(r["a"]) + int(r["w"]) / 2
	var out := []
	for along in [ec - s * back, ec + s * (4 + back)]:
		var x: int = along if int(r["axis"]) == 0 else l
		var z: int = l if int(r["axis"]) == 0 else along
		out.append((Vector2(x, z) + Vector2(0.5, 0.5)) * MapData.CELL)
	return out


## Walks the route in 1 m steps: every point open, and the height never jumps.
func _route_ok(nav: NavGrid, a: Vector2, p: PackedVector2Array) -> bool:
	var prev := a
	var y := nav.height(a)
	for q in p:
		var n := maxi(1, int(prev.distance_to(q)))
		for k in n:
			var m := prev.lerp(q, float(k + 1) / n)
			if not nav.is_open(m):
				return false
			var ym := nav.height(m)
			if absf(ym - y) > 2.5:
				return false
			y = ym
		prev = q
	return true


func _check(seed: int, w: int, h: int) -> void:
	print("== seed %d (%dx%d)" % [seed, w, h])
	var d := MapGen.generate(seed, w, h)
	var nav := NavGrid.new().build(d)
	_ok(nav.build_ms < 8000, "walk grid built in %d ms, %d ramps, %d ramp cells" % [nav.build_ms, d.ramps.size(), nav.ramp_at.size()])
	# Ramps.
	var tried := 0
	var good := 0
	var bad_at := []
	for r: Dictionary in d.ramps:
		if tried >= 40:
			break
		var ends := _ramp_ends(d, r, 3)
		var top: Vector2 = ends[0]
		var foot: Vector2 = ends[1]
		if not nav.is_open(top) or not nav.is_open(foot):
			continue
		tried += 1
		var p := nav.find_path(foot, top)
		var ok := not p.is_empty() and _route_ok(nav, foot, p) and absf(nav.height(p[p.size() - 1]) - MapData.level_y(int(r["t"]))) < 0.1
		if ok:
			good += 1
		elif bad_at.size() < 4:
			bad_at.append(foot)
	_ok(tried > 0 and good == tried, "routes up ramps: %d of %d good %s" % [good, tried, str(bad_at)])
	# Long routes.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var found := 0
	var asked := 0
	var worst := 0
	var t_all := 0
	var broken := 0
	while asked < 12:
		var a := Vector2(rng.randf_range(0, w * 8.0), rng.randf_range(0, h * 8.0))
		var b := Vector2(rng.randf_range(0, w * 8.0), rng.randf_range(0, h * 8.0))
		if not nav.is_open(a) or not nav.is_open(b) or a.distance_to(b) < 1500.0:
			continue
		asked += 1
		var t0 := Time.get_ticks_msec()
		var p := nav.find_path(a, b)
		var ms := Time.get_ticks_msec() - t0
		worst = maxi(worst, ms)
		t_all += ms
		if not p.is_empty():
			found += 1
			if not _route_ok(nav, a, p):
				broken += 1
	_ok(found >= 10 and broken == 0, "long routes (1.5 km and more): %d of %d found, %d broken" % [found, asked, broken])
	_ok(worst < 1500, "long route search: %d ms average, %d ms worst" % [t_all / asked, worst])
	# A squad up a ramp.
	for r: Dictionary in d.ramps:
		var ends := _ramp_ends(d, r, 6)
		var top: Vector2 = ends[0]
		var foot: Vector2 = ends[1]
		if not nav.is_open(top) or not nav.is_open(foot) or nav.find_path(foot, top).is_empty():
			continue
		var sq := Squad.new()
		root.add_child(sq)
		sq.setup(nav, foot, (top - foot).normalized(), 3, "Test")
		sq.set_process(false)
		sq.order_move(top)
		var jump := 0.0
		var last: Array[float] = []
		for m in sq.men:
			last.append(m.position.y)
		var frames := 0
		while frames < 60 * 120:
			sq._step(1.0 / 60.0)
			sq._place_men(1.0 / 60.0)
			for i in sq.men.size():
				jump = maxf(jump, absf(sq.men[i].position.y - last[i]))
				last[i] = sq.men[i].position.y
			frames += 1
			if not sq.moving() and frames % 60 == 0:
				var settled := true
				for i in sq.men.size():
					if sq.mpos[i].distance_to(sq._slot(i)) > 0.1:
						settled = false
				if settled:
					break
		var on_top := 0
		var top_y := MapData.level_y(int(r["t"]))
		for m in sq.men:
			if absf(m.position.y - top_y) < 0.1:
				on_top += 1
		_ok(on_top == Squad.MEN, "squad up a ramp: %d of %d men on top after %.1f s" % [on_top, Squad.MEN, frames / 60.0])
		_ok(jump < 0.5, "squad up a ramp: biggest height step in a frame %.2f m" % jump)
		sq.free()
		break
