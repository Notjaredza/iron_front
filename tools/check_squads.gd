extends SceneTree
## Iron Front: the squads' automatic check (headless, squads round 1). For each seed it:
## 1. Builds the walk grid and times it.
## 2. Ramps: for a sample of ramps, finds a route from well below the foot to well past the top, and checks it is
##    found, never crosses a closed cell, and never jumps in height (so it really goes up the ramp).
## 3. Long routes: random pairs of open base cells far apart; times the searches.
## 4. A squad marched up a ramp: every man ends on the top level, and no man ever jumps more than 0.5 m in a frame.
## 5. Drawn lines (right drag): two squads sent onto a long, a medium and a short line, drawn both ways. Every man
##    ends in place, faces the right way, the front rank lies on the drawn line, and the men across the whole line
##    are evenly spaced with no gap between the squads (one solid line). Men stop within 5 cm of their place, so
##    two neighbours may be up to 10 cm out.
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
	_check_lines(nav, rng, w, h)


## Somewhere flat and open, about 80 x 80 m.
func _flat_spot(nav: NavGrid, rng: RandomNumberGenerator, w: int, h: int) -> Variant:
	for t in 4000:
		var c := Vector2(rng.randf_range(100, w * 8.0 - 100), rng.randf_range(100, h * 8.0 - 100))
		var y := nav.height(c)
		var good := true
		for gx in range(-40, 41, 4):
			for gz in range(-40, 41, 4):
				var q := c + Vector2(gx, gz)
				if not nav.is_open(q) or absf(nav.height(q) - y) > 0.01 or nav.astar.get_point_weight_scale(nav.cell_of(q)) > 1.0:
					good = false
					break
			if not good:
				break
		if good:
			return c
	return null


func _check_lines(nav: NavGrid, rng: RandomNumberGenerator, w: int, h: int) -> void:
	var c: Variant = _flat_spot(nav, rng, w, h)
	_ok(c != null, "found flat open ground for the line test")
	if c == null:
		return
	var sqs: Array[Squad] = []
	for k in 2:
		var sq := Squad.new()
		root.add_child(sq)
		sq.setup(nav, c + Vector2(-12 + 24 * k, 25), Vector2(0, -1), 11 + k, "Line %d" % k)
		sq.set_process(false)
		sqs.append(sq)
	# [line length, drawn direction, men wide each squad should be]
	var cases := [[50.6, Vector2(1, 0), 12], [24.2, Vector2(0, 1), 6], [24.2, Vector2(-1, 0), 6], [2.0, Vector2(0.6, -0.8), 3]]
	for cs in cases:
		var L: float = cs[0]
		var dir: Vector2 = (cs[1] as Vector2).normalized()
		var a: Vector2 = c - dir * L * 0.5
		var b: Vector2 = c + dir * L * 0.5
		var plan := SquadControl.plan_line(sqs, a, b)
		var face := Vector2(dir.y, -dir.x)
		for p: Dictionary in plan:
			(p["squad"] as Squad).order_move(p["at"], false, p["face"], p["width"])
		var frames := 0
		while frames < 60 * 150:
			for sq in sqs:
				sq._step(1.0 / 60.0)
				sq._place_men(1.0 / 60.0)
			frames += 1
			if frames % 60 == 0:
				var settled := true
				for sq in sqs:
					if sq.moving():
						settled = false
					for i in sq.men.size():
						if sq.mpos[i].distance_to(sq._slot(i)) > 0.1 or absf(angle_difference(sq.mface[i], Squad._yaw(face))) > 0.05:
							settled = false
				if settled:
					break
		var width: int = cs[2]
		var front: Array[float] = []                   # where each front-rank man sits along the line
		var off_line := 0.0
		var bad_face := 0
		for sq in sqs:
			for i in sq.men.size():
				if absf(angle_difference(sq.mface[i], Squad._yaw(face))) > 0.05:
					bad_face += 1
				if i < sq.files:
					front.append((sq.mpos[i] - c).dot(dir))
					off_line = maxf(off_line, absf((sq.mpos[i] - c).dot(face)))
		front.sort()
		var gap_err := 0.0
		for k in range(1, front.size()):
			gap_err = maxf(gap_err, absf(front[k] - front[k - 1] - Squad.LINE_GAP))
		var what := "line %.0f m drawn %s: " % [L, str(dir)]
		_ok(frames < 60 * 150, what + "everyone in place after %.1f s" % (frames / 60.0))
		_ok(sqs[0].files == width and sqs[1].files == width, what + "%d and %d men wide (want %d)" % [sqs[0].files, sqs[1].files, width])
		_ok(bad_face == 0, what + "%d men facing the wrong way" % bad_face)
		_ok(off_line < 0.08, what + "front rank on the drawn line (worst %.2f m off)" % off_line)
		_ok(front.size() == 2 * width and gap_err < 0.12, what + "one solid line of %d men, spacing off by %.2f m at worst" % [front.size(), gap_err])
	for sq in sqs:
		sq.free()
