class_name CommsControl
extends Node3D
## Iron Front: the officer and the first comms (comms round, design step 3).
## - The officer (you) walks the field with two guards. He is a squad like any other (select him, move him), but he
##   does not fire; his guards do. Squads within 150 m of him take orders at once, shoot steadier (a quarter more
##   hits) and are harder to pin (a third less suppression).
## - Every other order has to be carried. The game finds the quickest way, from these legs:
##     runner           from the officer (or a post) to the squad on foot, at a run; he can be shot on the way,
##                      and then another is sent
##     runner post      a finished runner post (or the HQ) keeps fresh runners: from there they run a third faster,
##                      and a runner reaching one hands the order to a fresh man
##     telegraph wire   between finished telegraph posts and the HQ, laid with the build menu's "Telegraph wire"
##                      (Comms tab): the officer hands an order in at a wired point within 150 m of him, it goes
##                      down the wire in a few seconds, and a runner takes it from the wired point nearest the squad
##   Until an order arrives the squad goes on with its last one; its card and banner say "order coming" and when
##   it should arrive, then "order in". If a newer order gets there first, an older one arriving late is dropped.
## - Wire is cut by shells bursting near it and by enemies fighting or walking across it. A cut wire shows red; a
##   right click on the break with engineers selected sends them to splice it (10 s of work).
## - Reports come back the same way, from the squad to the officer: enemy in sight, under fire, men lost, out of
##   ammo, a squad wiped out. They show at the top right when they arrive, with how late they are, and a mark
##   on the map where it happened.
## - The officer: hit once, he is wounded; his guards carry him to the nearest finished HQ or barracks (or, with no
##   aid post or no one to carry him, he lies where he fell) and he recovers in 60 s (90 s where he lies). Hit again
##   while wounded, he dies, and the run is over: time held, waves beaten off and enemies killed show, N starts a
##   new map.
## - O shows the comms map: the officer's 150 m reach, the wires (cut ones red), each runner's way and each
##   order travelling the wire as a pulse.
## Recruitment round:
## - Linemen (recruited at the HQ) lay the wire: a wire drawn with the Telegraph wire tool is planned, and the
##   nearest free linemen walk to its first end and then out along it to the other, the poles going up behind
##   them (only where they walk near its line: a long way round leaves a gap until they are back on it); it works
##   once they get there. Free linemen also walk out to mend cuts.
## - The officer's powers (his unit card's buttons, or Z and U):
##     Rally            squads within 150 m stop being pinned and shake off the fire at once (every 90 s)
##     Hold the line    for 30 s squads within 150 m fire faster and cannot be pinned (every 120 s)
## Lamps, pigeons, dogs and dispatch riders come later.

const NEAR := 150.0                            # instant orders, and the officer's steadying, within this
const RUNNER_V := 3.7                          # a runner's pace (m/s): the rifles' run clip
const POST_V := 4.9                            # a fresh runner from a runner post or the HQ
const ROUTE_F := 1.15                          # a runner's way is about this much longer than the straight line
const HAND_IN := 2.0                           # seconds to hand an order in or over
const WIRE_S := 4.0                            # seconds to send a message down the wire (plus its length / WIRE_V)
const WIRE_V := 2000.0
const WIRE_MAX := 600.0                        # the longest wire between two points (m)
const REACH_RUNNER := 6.0                      # a runner within this of the squad has delivered
const POLE_GAP := 30.0
const FIX_S := 10.0
const HEAL_S := 60.0
const HEAL_ALONE_S := 90.0
const AID_R := 40.0
const REPORT_MEN := 3                          # a squad reports when it has lost this many men since its last report
const UNDER_FIRE_GAP := 60.0
const STEADY := 1.25                           # hit chance near the officer
const CALM := 0.67                             # suppression near the officer
const RALLY_EVERY := 90.0
const HOLD_S := 30.0
const HOLD_EVERY := 120.0
const LINEMEN_MEND_R := 700.0
const LAY_NEAR := 25.0                         # linemen lay wire only where they walk within this of its line
const WIRE_POINTS := ["hq", "telegraph"]
const RUNNER_POINTS := ["hq", "runner_post"]

var nav: NavGrid
var data: MapData
var cam: RtsCamera
var squads: SquadControl
var build: BuildControl
var combat: CombatControl
var officer: Squad
var t := 0.0
var wires: Array[Dictionary] = []              # {"a", "b": BuildSite, "cut": bool, "cut_at": Vector2, "fixer": Squad}
var messages: Array[Dictionary] = []           # orders and reports on their way (see send / report)
var reports: Array[Dictionary] = []            # arrived: {"text", "t", "late"}
var overlay := false
var run_over := false
var wounded := false                           # the officer
var heal_t := 0.0
var wiring := false                            # laying wire (from the build menu)
var _wire_from: BuildSite = null
var _seq := 0
var _seed := 900
var _runners: Node3D
var _wire_mesh: MeshInstance3D
var _wire_imm: ImmediateMesh
var _poles: MultiMeshInstance3D
var _over_mesh: MeshInstance3D
var _over_imm: ImmediateMesh
var _marks: Array[Dictionary] = []             # {"node": Label3D, "t"}
var _wires_dirty := true
var _seen_done := {}                           # enemy Squad -> true once reported
var _last := {}                                # our Squad -> {"men", "fire_t", "ammo"}
var _danger_t := 0.0
var _ui: CanvasLayer
var _report_box: Label
var _over_box: PanelContainer
var _over_text: Label
var _wire_ghost: MeshInstance3D
var _wire_gimm: ImmediateMesh
var _ow := 1.0                                 # how wide the comms map's bands are (grows with the camera height)
var note := ""
var _note_t := 0.0
var rng := RandomNumberGenerator.new()
var rally_at := -999.0                         # when the officer last rallied
var hold_at := -999.0                          # when "hold the line" was last called
var stats := {"runners_sent": 0, "runners_lost": 0, "orders": 0, "instant": 0, "reports": 0}


func _ready() -> void:
	rng.seed = 31
	_runners = Node3D.new()
	_runners.name = "Runners"
	add_child(_runners)
	_wire_imm = ImmediateMesh.new()
	_wire_mesh = _line_node(_wire_imm, Color(0.12, 0.1, 0.08), false)
	_over_imm = ImmediateMesh.new()
	_over_mesh = _line_node(_over_imm, Color(1, 1, 1), true)
	_wire_gimm = ImmediateMesh.new()
	_wire_ghost = _line_node(_wire_gimm, Color(0.4, 1.0, 0.5), true)
	_poles = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pole := BoxMesh.new()
	pole.size = Vector3(0.16, 5.0, 0.16)
	mm.mesh = pole
	_poles.multimesh = mm
	_poles.material_override = Squad._flat(Color(0.33, 0.24, 0.15))
	(_poles.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	add_child(_poles)
	_ui = CanvasLayer.new()
	add_child(_ui)
	_report_box = Label.new()
	_report_box.anchor_left = 1.0
	_report_box.anchor_right = 1.0
	_report_box.offset_left = -470
	_report_box.offset_right = -12
	_report_box.offset_top = 10
	_report_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_report_box.add_theme_font_size_override("font_size", 14)
	_report_box.add_theme_color_override("font_outline_color", Color.BLACK)
	_report_box.add_theme_constant_override("outline_size", 5)
	_report_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_report_box)
	_over_box = PanelContainer.new()
	_over_box.anchor_left = 0.5
	_over_box.anchor_right = 0.5
	_over_box.anchor_top = 0.35
	_over_box.anchor_bottom = 0.35
	_over_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.9)
	sb.border_color = Color(0.7, 0.2, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	_over_box.add_theme_stylebox_override("panel", sb)
	_over_text = Label.new()
	_over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_text.add_theme_font_size_override("font_size", 22)
	_over_box.add_child(_over_text)
	_over_box.visible = false
	_ui.add_child(_over_box)


func _line_node(imm: ImmediateMesh, c: Color, on_top: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = imm
	var mat := Squad._flat(c)
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = on_top
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


## A new map: no wires, no messages; the officer comes with the new squads (see spawn_officer).
func reset(nav_grid: NavGrid, map_data: MapData) -> void:
	nav = nav_grid
	data = map_data
	for m in messages:
		_drop_runner(m)
	messages.clear()
	reports.clear()
	wires.clear()
	_wires_dirty = true
	for k in _marks:
		(k["node"] as Node).queue_free()
	_marks.clear()
	_seen_done.clear()
	_last.clear()
	officer = null
	run_over = false
	wounded = false
	heal_t = 0.0
	t = 0.0
	rally_at = -999.0
	hold_at = -999.0
	wiring = false
	_wire_from = null
	_over_box.visible = false
	for k: String in stats:
		stats[k] = 0


## Puts the officer and his two guards at `where` (they join the player's squads).
func spawn_officer(where: Vector2, face := Vector2(0, -1)) -> Squad:
	var s := Squad.new()
	squads.add_child(s)
	s.setup(nav, nav.nearest_open(where), face, 3, "Officer", "officer", 3)
	squads.squads.append(s)
	officer = s
	return s


func has_officer() -> bool:
	return officer != null and is_instance_valid(officer) and officer.officer_index() >= 0


## Where the officer is (or null when there is none).
func officer_at() -> Variant:
	if not has_officer():
		return null
	return officer.mpos[officer.officer_index()]


## Squads this close to the officer take orders at once and fight steadier.
func near_officer(s: Squad) -> bool:
	var o: Variant = officer_at()
	return o != null and s.side == 0 and s.center().distance_to(o) <= NEAR


# ------------------------------------------------------------------ orders

## Sends an order to these squads. `apply` is called with the squads still alive when it arrives (at once for
## those near the officer, and with no officer at all, as before this round). `what` is a few words for the card.
func send(sel: Array[Squad], apply: Callable, what := "order") -> void:
	if sel.is_empty():
		return
	stats["orders"] += 1
	var now: Array[Squad] = []
	var far: Array[Squad] = []
	for s in sel:
		if not is_instance_valid(s):
			continue
		_seq += 1
		s.set_meta("order_seq", _seq)
		if run_over:
			continue
		if not has_officer() or s == officer or near_officer(s):
			now.append(s)
		else:
			far.append(s)
	if not now.is_empty():
		stats["instant"] += 1
		for s in now:
			s.set_meta("order_in", _seq)
			s.remove_meta("order_eta")
		apply.call(now)
	# Squads close together share one runner.
	while not far.is_empty():
		var lead := far.pop_front() as Squad
		var group: Array[Squad] = [lead]
		for s in far.duplicate():
			if s.center().distance_to(lead.center()) < 60.0:
				group.append(s)
				far.erase(s)
		var seqs := {}
		for s in group:
			seqs[s] = int(s.get_meta("order_seq"))
		var m := {"kind": "order", "to": group, "apply": apply, "what": what, "seqs": seqs, "src": officer_at(),
			"sent": t}
		_plan(m)
		messages.append(m)
		for s in group:
			s.set_meta("order_eta", float(m["eta"]))


## A report from squad s to the officer: at once if he is near, else carried back.
func report(s: Squad, text: String, where: Vector2) -> void:
	stats["reports"] += 1
	var o: Variant = officer_at()
	if o == null or run_over or where.distance_to(o) <= NEAR:
		_arrived_report(text, where, t)
		return
	var m := {"kind": "report", "text": text, "where": where, "src": where, "sent": t, "from": s}
	_plan(m)
	messages.append(m)


# ------------------------------------------------------------------ the network

## The points on the network: finished HQs, telegraph posts and runner posts.
func points() -> Array[BuildSite]:
	var out: Array[BuildSite] = []
	if build == null:
		return out
	for site in build.sites:
		if site.done and (site.kind in WIRE_POINTS or site.kind in RUNNER_POINTS):
			out.append(site)
	return out


func live(w: Dictionary) -> bool:
	return float(w.get("laid", 1.0)) >= 1.0 and not bool(w["cut"]) and (w["a"] as BuildSite).done and (w["b"] as BuildSite).done \
		and build.sites.has(w["a"]) and build.sites.has(w["b"])


## The wired points joined to p by live wire, with the wire hops between them: point -> [path of points].
func wired_from(p: BuildSite) -> Dictionary:
	var out := {p: [p]}
	var todo: Array[BuildSite] = [p]
	while not todo.is_empty():
		var a: BuildSite = todo.pop_front()
		for w in wires:
			if not live(w):
				continue
			var b: BuildSite = null
			if w["a"] == a:
				b = w["b"]
			elif w["b"] == a:
				b = w["a"]
			if b != null and not out.has(b):
				out[b] = (out[a] as Array) + [b]
				todo.append(b)
	return out


func is_wired(p: BuildSite) -> bool:
	return wired_from(p).size() > 1


static func _wire_len(path: Array) -> float:
	var L := 0.0
	for i in range(1, path.size()):
		L += (path[i - 1] as BuildSite).center().distance_to((path[i] as BuildSite).center())
	return L


func _runner_v(from: Variant) -> float:
	return POST_V if from is BuildSite and (from as BuildSite).kind in RUNNER_POINTS else RUNNER_V


## Where a message is going now: the squads (orders) or the officer (reports).
func _goal(m: Dictionary) -> Variant:
	if m["kind"] == "order":
		for s: Squad in m["to"]:
			if is_instance_valid(s) and not s.men.is_empty():
				return s.center()
		return null
	return officer_at()


## Plans the quickest way for a message from its source: a list of legs, each {"type": "run" or "wire", "from",
## "to" (a BuildSite, or null for the goal), "path" (wire: the points), "dur"}. Sets m["legs"], m["leg"], m["eta"].
func _plan(m: Dictionary, from: Variant = null) -> void:
	var src: Vector2 = m["src"] if from == null else (from as BuildSite).center() if from is BuildSite else from
	var goal: Variant = _goal(m)
	m["legs"] = []
	m["leg"] = 0
	m["leg_t"] = t
	_drop_runner(m)
	if goal == null:
		m["eta"] = t
		return
	var g: Vector2 = goal
	var pts := points()
	var off: Variant = officer_at()
	# Dijkstra over: 0 the source, 1 the goal, 2.. the points.
	var n := pts.size() + 2
	var pos: Array[Vector2] = [src, g]
	for p in pts:
		pos.append(p.center())
	var cost: Array[float] = []
	var prev: Array[int] = []
	var how: Array = []
	for i in n:
		cost.append(INF)
		prev.append(-1)
		how.append(null)
	cost[0] = 0.0
	var done: Array[bool] = []
	done.resize(n)
	var comp := {}                             # point index -> its wired set
	for i in pts.size():
		comp[i + 2] = wired_from(pts[i])
	while true:
		var u := -1
		for i in n:
			if not done[i] and cost[i] < INF and (u < 0 or cost[i] < cost[u]):
				u = i
		if u < 0 or u == 1:
			break
		done[u] = true
		var from_obj: Variant = pts[u - 2] if u >= 2 else (from if from is BuildSite else null)
		for v in n:
			if v == u or done[v] or v == 0:
				continue
			var c := INF
			var leg := {}
			var d := pos[u].distance_to(pos[v])
			# Handing in: the officer gives an order to a point near him; a point near him passes him a report.
			if m["kind"] == "order" and u == 0 and from == null and v >= 2 and d <= NEAR:
				c = HAND_IN
				leg = {"type": "hand"}
			elif m["kind"] == "report" and v == 1 and u >= 2 and off != null and d <= NEAR:
				c = HAND_IN
				leg = {"type": "hand"}
			# Down the wire.
			if u >= 2 and v >= 2 and (comp[u] as Dictionary).has(pts[v - 2]):
				var path: Array = (comp[u] as Dictionary)[pts[v - 2]]
				var cw := WIRE_S + _wire_len(path) / WIRE_V
				if cw < c:
					c = cw
					leg = {"type": "wire", "path": path}
			# On foot (from a runner post: a fresh, faster man; a telegraph post's own orderly otherwise).
			var cr := HAND_IN + d * ROUTE_F / _runner_v(from_obj)
			if cr < c and (v == 1 or (v >= 2 and pts[v - 2].kind in RUNNER_POINTS) or (v >= 2 and pts[v - 2].kind in WIRE_POINTS)):
				c = cr
				leg = {"type": "run"}
			if c < INF and cost[u] + c < cost[v]:
				cost[v] = cost[u] + c
				prev[v] = u
				how[v] = leg
	if cost[1] == INF:
		m["legs"] = [{"type": "run", "from": src, "to": null, "dur": src.distance_to(g) * ROUTE_F / RUNNER_V}]
		m["eta"] = t + float(m["legs"][0]["dur"])
		return
	var chain: Array[int] = []
	var k := 1
	while k != 0 and k >= 0:
		chain.push_front(k)
		k = prev[k]
	var legs := []
	var at_i := 0
	for v in chain:
		var leg: Dictionary = (how[v] as Dictionary).duplicate()
		leg["from"] = pts[at_i - 2] if at_i >= 2 else src
		leg["to"] = pts[v - 2] if v >= 2 else null
		leg["dur"] = cost[v] - cost[at_i]
		legs.append(leg)
		at_i = v
	m["legs"] = legs
	m["eta"] = t + cost[1]


# ------------------------------------------------------------------ every frame

func _process(dt: float) -> void:
	if nav == null:
		return
	step(dt)


## One step of the comms (also called by the headless check).
func step(dt: float) -> void:
	t += dt
	_run_messages(dt)
	_danger_t -= dt
	if _danger_t <= 0.0:
		_danger_t = 0.5
		_runner_danger()
		_wire_danger()
		_watch_reports()
	_run_fixers(dt)
	_run_linemen()
	_run_officer(dt)
	_show_tags()
	if _wires_dirty:
		_build_wire_mesh()
	_draw_overlay()
	_update_ui()
	for k in _marks.duplicate():
		if t - float(k["t"]) > 25.0:
			(k["node"] as Node).queue_free()
			_marks.erase(k)
	_note_t -= dt
	if _note_t <= 0.0:
		note = ""


func _run_messages(dt: float) -> void:
	for m in messages.duplicate():
		if m["kind"] == "order":
			var alive: Array[Squad] = []
			for s: Squad in m["to"]:
				if is_instance_valid(s) and not s.men.is_empty():
					alive.append(s)
			m["to"] = alive
			if alive.is_empty():
				_finish(m)
				continue
		var legs: Array = m["legs"]
		if int(m["leg"]) >= legs.size():
			_deliver(m)
			continue
		var leg: Dictionary = legs[int(m["leg"])]
		match leg["type"]:
			"hand", "wire":
				if t - float(m["leg_t"]) >= float(leg["dur"]):
					_next_leg(m)
			"run":
				if not _step_runner(m, leg, dt):
					continue
				_next_leg(m)


func _next_leg(m: Dictionary) -> void:
	_drop_runner(m)
	m["leg"] = int(m["leg"]) + 1
	m["leg_t"] = t
	# A wire cut while the message was on its way there: find another way from here.
	var legs: Array = m["legs"]
	if int(m["leg"]) < legs.size() and legs[int(m["leg"])]["type"] == "wire":
		var path: Array = legs[int(m["leg"])]["path"]
		if not wired_from(path[0]).has(path[path.size() - 1]):
			var at: Variant = path[0]
			_plan(m, at)
			m["legs"].insert(0, {"type": "hand", "from": at, "to": at, "dur": 0.0})


func _deliver(m: Dictionary) -> void:
	_finish(m)
	if m["kind"] == "report":
		_arrived_report(m["text"], m["where"], float(m["sent"]))
		return
	var take: Array[Squad] = []
	for s: Squad in m["to"]:
		var my := int((m["seqs"] as Dictionary).get(s, 0))
		if my >= int(s.get_meta("order_seq", 0)) and my > int(s.get_meta("order_in", 0)):
			take.append(s)
			s.set_meta("order_in", my)
			s.set_meta("order_got", t)
			s.remove_meta("order_eta")
	if not take.is_empty():
		(m["apply"] as Callable).call(take)


func _finish(m: Dictionary) -> void:
	_drop_runner(m)
	messages.erase(m)


# ------------------------------------------------------------------ runners

## Moves a message's runner along; true when he has got there.
func _step_runner(m: Dictionary, leg: Dictionary, dt: float) -> bool:
	var dest: Variant = (leg["to"] as BuildSite).center() if leg["to"] != null else _goal(m)
	if dest == null:
		return true
	if not m.has("runner"):
		var from: Variant = leg["from"]
		var start: Vector2 = (from as BuildSite).approach(nav) if from is BuildSite else from
		m["runner"] = _make_runner(start)
		m["rv"] = _runner_v(from)
		m["rpath"] = PackedVector2Array()
		m["repath"] = 0.0
		stats["runners_sent"] += 1
	var r: Dictionary = m["runner"]
	var p: Vector2 = r["at"]
	var goal: Vector2 = dest
	if leg["to"] != null:
		goal = (leg["to"] as BuildSite).approach(nav)
	if p.distance_to(goal) <= REACH_RUNNER or (leg["to"] != null and p.distance_to(dest) <= 18.0):
		return true
	m["repath"] = float(m["repath"]) - dt
	if float(m["repath"]) <= 0.0 or (m["rpath"] as PackedVector2Array).is_empty():
		m["repath"] = 3.0
		m["rpath"] = nav.find_path(p, nav.nearest_open(goal))
		if (m["rpath"] as PackedVector2Array).is_empty():
			m["rpath"] = PackedVector2Array([goal])
	var left := float(m["rv"]) * dt / nav.astar.get_point_weight_scale(nav.cell_of(p))
	var rp: PackedVector2Array = m["rpath"]
	var dir := Vector2.ZERO
	while left > 0.0 and not rp.is_empty():
		var d := p.distance_to(rp[0])
		if d < 0.01:
			rp.remove_at(0)
			continue
		dir = (rp[0] - p) / d
		var s := minf(left, d)
		p += dir * s
		left -= s
		if s >= d - 0.001:
			rp.remove_at(0)
	m["rpath"] = rp
	r["at"] = p
	var man: Soldier = r["man"]
	if is_instance_valid(man):
		man.position = Vector3(p.x, nav.height(p), p.y)
		if dir != Vector2.ZERO:
			man.rotation.y = lerp_angle(man.rotation.y, atan2(-dir.x, -dir.y), 1.0 - exp(-dt * 10.0))
		(r["ap"] as AnimationPlayer).speed_scale = float(m["rv"]) / RUNNER_V
		var tag: Label3D = r["tag"]
		tag.position = man.position + Vector3(0, 3.0, 0)
		tag.visible = overlay or (cam != null and cam.height > 160.0)
	return false


func _make_runner(at: Vector2) -> Dictionary:
	_seed += 1
	var man := Soldier.new().setup(_seed, 1, "signaller")
	_runners.add_child(man)
	var ap := AnimationPlayer.new()
	man.add_child(ap)
	ap.add_animation_library("", TroopKinds.library("rifles", man.geo))
	ap.play("run")
	ap.seek(rng.randf() * 0.5, true)
	man.position = Vector3(at.x, nav.height(at), at.y)
	var tag := Label3D.new()
	tag.text = "runner"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.fixed_size = true
	tag.pixel_size = 0.001
	tag.font_size = 24
	tag.outline_size = 6
	tag.no_depth_test = true
	tag.modulate = Color(0.75, 0.95, 1.0)
	_runners.add_child(tag)
	return {"man": man, "ap": ap, "tag": tag, "at": at}


func _drop_runner(m: Dictionary) -> void:
	if not m.has("runner"):
		return
	var r: Dictionary = m["runner"]
	if is_instance_valid(r["man"]):
		(r["man"] as Node).queue_free()
	if is_instance_valid(r["tag"]):
		(r["tag"] as Node).queue_free()
	m.erase("runner")


## Enemies in range and in sight may shoot a runner; one within reach of a hand-to-hand enemy is cut down.
## A runner who falls lies where he fell, and the message is sent again from where it started.
func _runner_danger() -> void:
	if combat == null:
		return
	for m in messages.duplicate():
		if not m.has("runner"):
			continue
		var r: Dictionary = m["runner"]
		var p: Vector2 = r["at"]
		var dead := false
		for e in combat.enemies:
			if e.men.is_empty() or e.center().distance_to(p) > 200.0:
				continue
			var near := INF
			for q in e.mpos:
				near = minf(near, q.distance_to(p))
			if near < 3.0 and float(e.spec["melee"]) > 0.0:
				dead = rng.randf() < 0.6
			elif e.can_fire() and near <= float(e.spec["range"]) and combat.clear_sight(e.center(), nav.height(e.center()) + 1.6, p, nav.height(p) + 1.2):
				dead = rng.randf() < float(e.spec["acc"]) * 0.6 * 0.6
			if dead:
				break
		if dead:
			_runner_falls(m)


func _runner_falls(m: Dictionary) -> void:
	var r: Dictionary = m["runner"]
	var man: Soldier = r["man"]
	if is_instance_valid(man):
		(r["ap"] as AnimationPlayer).play("death_forward", 0.1)
		(r["ap"] as AnimationPlayer).speed_scale = 1.0
		if combat != null:
			man.reparent(combat.corpses, true)
			combat._dead.append([man, combat.t])
		r["man"] = null
	stats["runners_lost"] += 1
	var who := "the officer"
	if m["kind"] == "order" and not (m["to"] as Array).is_empty():
		who = (m["to"][0] as Squad).title
	say("Runner to %s shot; another is sent" % who)
	m["src"] = officer_at() if m["kind"] == "order" and officer_at() != null else m["src"]
	_plan(m)
	if m["kind"] == "order":
		for s: Squad in m["to"]:
			s.set_meta("order_eta", float(m["eta"]))


# ------------------------------------------------------------------ wire

## Lays a wire between two wired points (HQ or telegraph post, finished or not). It works once both ends are
## finished. Returns false (and says why) if it cannot.
func lay_wire(a: BuildSite, b: BuildSite, at_once := true) -> bool:
	if a == b or a == null or b == null:
		return false
	if not (a.kind in WIRE_POINTS and b.kind in WIRE_POINTS):
		say("Wire runs between telegraph posts and the HQ")
		return false
	if a.center().distance_to(b.center()) > WIRE_MAX:
		say("Too far for one wire (%d m, most %d m)" % [int(a.center().distance_to(b.center())), int(WIRE_MAX)])
		return false
	for w in wires:
		if (w["a"] == a and w["b"] == b) or (w["a"] == b and w["b"] == a):
			say("Already wired")
			return false
	wires.append({"a": a, "b": b, "cut": false, "cut_at": Vector2.ZERO, "fixer": null, "laid": 1.0 if at_once else 0.0,
		"crew": null, "stage": ""})
	_wires_dirty = true
	return true


## Cuts the wire nearest to p if it passes within r metres. Returns true if one was cut.
func cut_near(p: Vector2, r: float) -> bool:
	var any := false
	for w in wires:
		if bool(w["cut"]) or float(w.get("laid", 1.0)) < 1.0:
			continue
		var q := Geometry2D.get_closest_point_to_segment(p, (w["a"] as BuildSite).center(), (w["b"] as BuildSite).center())
		if q.distance_to(p) <= r:
			w["cut"] = true
			w["cut_at"] = q
			any = true
			_wires_dirty = true
			var mid := q
			_mark(mid, "WIRE CUT", Color(1.0, 0.4, 0.3))
	if any:
		say("A telegraph wire is cut")
	return any


## A shell or a blast at p (CombatControl calls this).
func blast_at(p: Vector2) -> void:
	cut_near(p, 7.0)


## Enemies fighting or walking over a wire cut it now and then.
func _wire_danger() -> void:
	if combat == null or wires.is_empty():
		return
	for e in combat.enemies:
		if e.men.is_empty():
			continue
		var c := e.center()
		for w in wires:
			if bool(w["cut"]):
				continue
			var q := Geometry2D.get_closest_point_to_segment(c, (w["a"] as BuildSite).center(), (w["b"] as BuildSite).center())
			if q.distance_to(c) < 10.0 and rng.randf() < (0.25 if e.melee_on else 0.08):
				cut_near(q, 1.0)


## The cut wire with a break near p (within r), or null.
func cut_wire_at(p: Vector2, r := 12.0) -> Variant:
	for w in wires:
		if bool(w["cut"]) and (w["cut_at"] as Vector2).distance_to(p) <= r:
			return w
	return null


## Sends an engineer section to splice a cut wire (an order like any other: it may take time to get there).
func fix(sq: Squad, w: Dictionary) -> void:
	sq.cancel_job()
	w["fixer"] = sq
	sq.set_meta("fix", w)
	sq.set_meta("fix_t", 0.0)
	sq.status = "to the cut wire"
	sq.order_move(nav.nearest_open(w["cut_at"]))


func _run_fixers(dt: float) -> void:
	for w in wires:
		var sq: Variant = w["fixer"]
		if sq == null:
			continue
		if not is_instance_valid(sq) or (sq as Squad).men.is_empty() or _meta(sq, "fix") != w:
			w["fixer"] = null
			continue
		var s: Squad = sq
		var at: Vector2 = w["cut_at"]
		if s.moving():
			continue
		if s.at.distance_to(at) > 14.0:
			if s.status == "to the cut wire":
				s.status = ""
				s.remove_meta("fix")
				w["fixer"] = null                # could not get there
			continue
		if not s.working:
			var spots: Array[Vector2] = []
			var faces: Array[Vector2] = []
			var clips: Array[String] = []
			for i in s.count:
				var a := TAU * float(i) / maxf(s.count, 1)
				var q := nav.nearest_open(at + Vector2(cos(a), sin(a)) * 1.6)
				spots.append(q)
				faces.append((at - q).normalized() if at.distance_to(q) > 0.1 else Vector2(0, -1))
				clips.append(("eng_hammer_low" if i % 2 == 0 else "eng_hold") if s.is_engineers() else "kneel_work")
			s.start_work(spots, faces, clips)
		var ft := float(s.get_meta("fix_t", 0.0)) + dt * float(maxi(s.men_at_work(), 0)) / 4.0
		s.set_meta("fix_t", ft)
		s.status = "splicing wire %d%%" % int(clampf(ft / FIX_S, 0.0, 1.0) * 100.0)
		if ft >= FIX_S:
			w["cut"] = false
			w["fixer"] = null
			s.remove_meta("fix")
			s.stop_work()
			_wires_dirty = true
			say("Wire mended by %s" % s.title)


## Where a wire meets a building: its "wire_out" mark if it has one, else the top of its middle.
func _wire_end(site: BuildSite) -> Vector3:
	if site.node != null and site.node.marks.has("wire_out") and site.done:
		return site.node.mark_world("wire_out")
	var c := site.center()
	return Vector3(c.x, site.y + 5.0, c.y)


func _build_wire_mesh() -> void:
	_wires_dirty = false
	_wire_imm.clear_surfaces()
	var xfs: Array[Transform3D] = []
	var lines := []
	for w in wires:
		var a: BuildSite = w["a"]
		var b: BuildSite = w["b"]
		var pa := _wire_end(a)
		var pb := _wire_end(b)
		var A := Vector2(pa.x, pa.z)
		var B := Vector2(pb.x, pb.z)
		var n := maxi(1, int(A.distance_to(B) / POLE_GAP))
		var tops: Array[Vector3] = [pa]
		var laid := float(w.get("laid", 1.0))
		if laid < 1.0:
			# Being laid: the poles and wire as far as the linemen have got.
			var upto := int(laid * n)
			for k in range(1, upto + 1):
				var q := A.lerp(B, float(k) / n)
				xfs.append(Transform3D(Basis(), Vector3(q.x, nav.height(q) + 2.5, q.y)))
				tops.append(Vector3(q.x, nav.height(q) + 4.8, q.y))
			if tops.size() > 1:
				lines.append([tops, -1, false])
			continue
		for k in range(1, n):
			var q := A.lerp(B, float(k) / n)
			var y := nav.height(q)
			xfs.append(Transform3D(Basis(), Vector3(q.x, y + 2.5, q.y)))
			tops.append(Vector3(q.x, y + 4.8, q.y))
		tops.append(pb)
		var cut_i := -1
		if bool(w["cut"]):
			var u := A.distance_to(w["cut_at"]) / maxf(A.distance_to(B), 1.0)
			cut_i = int(u * n)
		lines.append([tops, cut_i, bool(w["cut"])])
	var mm := _poles.multimesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	if lines.is_empty():
		return
	_wire_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for L: Array in lines:
		var tops: Array[Vector3] = L[0]
		for k in range(tops.size() - 1):
			if k == int(L[1]):
				continue                        # the break: this span hangs down
			var a3: Vector3 = tops[k]
			var b3: Vector3 = tops[k + 1]
			for j in 4:                         # a little sag between poles
				var u0 := float(j) / 4.0
				var u1 := float(j + 1) / 4.0
				var p0 := a3.lerp(b3, u0) - Vector3(0, sin(u0 * PI) * 0.5, 0)
				var p1 := a3.lerp(b3, u1) - Vector3(0, sin(u1 * PI) * 0.5, 0)
				_wire_imm.surface_set_color(Color(0.12, 0.1, 0.08))
				_wire_imm.surface_add_vertex(p0)
				_wire_imm.surface_set_color(Color(0.12, 0.1, 0.08))
				_wire_imm.surface_add_vertex(p1)
		if int(L[1]) >= 0 and int(L[1]) < tops.size() - 1:
			var a4: Vector3 = tops[int(L[1])]
			var b4: Vector3 = tops[int(L[1]) + 1]
			for e: Array in [[a4, a4.lerp(b4, 0.3)], [b4, b4.lerp(a4, 0.3)]]:
				var top: Vector3 = e[0]
				var hang: Vector3 = e[1]
				hang.y = nav.height(Vector2(hang.x, hang.z)) + 0.2
				_wire_imm.surface_set_color(Color(0.12, 0.1, 0.08))
				_wire_imm.surface_add_vertex(top)
				_wire_imm.surface_set_color(Color(0.12, 0.1, 0.08))
				_wire_imm.surface_add_vertex(hang)
	_wire_imm.surface_end()


# ------------------------------------------------------------------ laying wire (build menu)

func start_wiring() -> void:
	wiring = true
	_wire_from = null
	say("Telegraph wire: click the HQ or a telegraph post, then another (Shift keeps going); right click stops")


func stop_wiring() -> void:
	wiring = false
	_wire_from = null
	_wire_gimm.clear_surfaces()


## The HQ or telegraph post (placed, finished or not) at p, or null.
func wire_point_at(p: Vector2) -> BuildSite:
	if build == null:
		return null
	var s: Variant = build.site_at(p)
	if s != null and (s as BuildSite).kind in WIRE_POINTS:
		return s
	return null


func _unhandled_input(event: InputEvent) -> void:
	if nav == null or squads == null or cam == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_O:
			overlay = not overlay
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_Z:
			rally()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_U:
			hold()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ESCAPE and wiring:
			stop_wiring()
			get_viewport().set_input_as_handled()
		return
	if not wiring or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		stop_wiring()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var g: Variant = squads._ground2(mb.position)
	if g == null:
		return
	var p := wire_point_at(g)
	if p == null:
		say("Click the HQ or a telegraph post")
		return
	if _wire_from == null:
		_wire_from = p
		return
	if lay_wire(_wire_from, p, false):
		say("Wire planned (%d m): %s" % [int(_wire_from.center().distance_to(p.center())),
			"linemen will lay it" if not _linemen().is_empty() else "recruit linemen at the HQ to lay it"])
		if mb.shift_pressed:
			_wire_from = p
		else:
			stop_wiring()


func _draw_wire_ghost() -> void:
	_wire_gimm.clear_surfaces()
	if not wiring or _wire_from == null or squads == null:
		return
	var g: Variant = squads._ground2(get_viewport().get_mouse_position())
	if g == null:
		return
	var a := _wire_from.center()
	var b: Vector2 = g
	var to := wire_point_at(b)
	var ok := to != null and to != _wire_from and a.distance_to(to.center()) <= WIRE_MAX
	if to != null:
		b = to.center()
	var col := Color(0.4, 1.0, 0.5) if ok else Color(1.0, 0.35, 0.3)
	_wire_gimm.surface_begin(Mesh.PRIMITIVE_LINES)
	var n := maxi(1, int(a.distance_to(b) / 8.0))
	for k in n:
		var p0 := a.lerp(b, float(k) / n)
		var p1 := a.lerp(b, float(k + 1) / n)
		_wire_gimm.surface_set_color(col)
		_wire_gimm.surface_add_vertex(Vector3(p0.x, nav.height(p0) + 5.0, p0.y))
		_wire_gimm.surface_set_color(col)
		_wire_gimm.surface_add_vertex(Vector3(p1.x, nav.height(p1) + 5.0, p1.y))
	_wire_gimm.surface_end()


# ------------------------------------------------------------------ reports

func _watch_reports() -> void:
	if combat == null:
		return
	# Enemy in sight: the first time each enemy band is seen, by the nearest of ours.
	for e: Squad in combat.seen:
		if not is_instance_valid(e) or _seen_done.has(e):
			continue
		_seen_done[e] = true
		var by := _nearest_ours(e.center())
		if by == null:
			continue
		var d := by.center().distance_to(e.center())
		report(by, "%s: enemy in sight, %s, %d m %s" % [by.title, e.title, int(d), _dir_word(e.center() - by.center())], e.center())
	for s in squads.squads:
		if s.side != 0 or s == officer:
			continue
		var L: Dictionary = _last.get(s, {"men": s.men.size(), "fire_t": -999.0, "ammo": false})
		if s.supp > 0.4 and t - float(L["fire_t"]) > UNDER_FIRE_GAP:
			L["fire_t"] = t
			report(s, "%s: under fire" % s.title, s.center())
		if int(L["men"]) - s.men.size() >= REPORT_MEN:
			report(s, "%s: lost %d men, %d left" % [s.title, int(L["men"]) - s.men.size(), s.men.size()], s.center())
			L["men"] = s.men.size()
		if s.out_of_ammo() and not bool(L["ammo"]):
			L["ammo"] = true
			report(s, "%s: out of ammo" % s.title, s.center())
		elif not s.out_of_ammo():
			L["ammo"] = false
		L["at"] = s.center()
		_last[s] = L
	for s in _last.keys():
		if not is_instance_valid(s) or (s as Squad).men.is_empty():
			var L2: Dictionary = _last[s]
			_last.erase(s)
			if L2.has("at"):
				report(null, "%s: wiped out" % L2.get("title", "A squad"), L2["at"])
	for s in squads.squads:
		if _last.has(s):
			_last[s]["title"] = s.title


func _nearest_ours(p: Vector2) -> Squad:
	var best: Squad = null
	var bd := INF
	for s in squads.squads:
		if s.men.is_empty():
			continue
		var d := s.center().distance_to(p)
		if d < bd:
			bd = d
			best = s
	return best


static func _dir_word(v: Vector2) -> String:
	var a := fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)
	return ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"][int((a + 22.5) / 45.0) % 8]


func _arrived_report(text: String, where: Vector2, sent: float) -> void:
	reports.push_front({"text": text, "t": t, "late": t - sent, "where": where})
	if reports.size() > 6:
		reports.resize(6)
	_mark(where, "!", Color(1.0, 0.85, 0.3))


func _mark(where: Vector2, text: String, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0016
	l.font_size = 30
	l.outline_size = 8
	l.no_depth_test = true
	l.modulate = c
	l.position = Vector3(where.x, (nav.height(where) if nav != null else 0.0) + 7.0, where.y)
	add_child(l)
	_marks.append({"node": l, "t": t})


# ------------------------------------------------------------------ the officer

## CombatControl calls this when the officer himself is hit (instead of the usual fall). Returns true if he died.
func officer_hit(s: Squad, j: int) -> bool:
	if not wounded:
		wounded = true
		heal_t = 0.0
		s.md[j]["hp"] = 1
		s.act(j, "hit")
		s.cancel_job()
		s.attack = null
		var aid := _aid_post(s.center())
		var k := s.carriers()
		if aid != null and k.x >= 0:
			s.carried = true
			s.lying = false
			s.order_move(aid.approach(nav))
			s.status = "WOUNDED, carried to the %s" % BuildControl.NAMES.get(aid.kind, aid.kind)
		else:
			s.carried = false
			s.lying = true
			s.path.clear()
			s.status = "WOUNDED, lying where he fell"
		say("The officer is wounded!")
		_arrived_report("The officer is wounded", s.center(), t)
		return false
	# Hit again while wounded: he dies, and the run is over.
	s.carried = false
	s.lying = false
	s.path.clear()
	s.status = "the officer has fallen"
	run_over = true
	_over_text.text = "The officer is dead. The run is over.\n\nHeld for %s   Enemies killed %d   Waves beaten off %d\n\nN starts a new map" % [
		_clock(t), killed(), waves_beaten()]
	_over_box.visible = true
	return true


func killed() -> int:
	return int(combat.stats.get("dead", [0, 0])[1]) if combat != null else 0


func waves_beaten() -> int:
	return int(combat.get_meta("waves_beaten", 0)) if combat != null else 0


static func _clock(s: float) -> String:
	var m := int(s) / 60
	return "%d:%02d" % [m / 60, m % 60] if m >= 60 else "%d min %02d s" % [m, int(s) % 60]


func _aid_post(p: Vector2) -> BuildSite:
	if build == null:
		return null
	var best: BuildSite = null
	var bd := INF
	for site in build.sites:
		if site.done and site.kind in ["hq", "barracks"]:
			var d := site.center().distance_to(p)
			if d < bd:
				bd = d
				best = site
	return best


func _run_officer(dt: float) -> void:
	if not has_officer() or not wounded:
		return
	var s := officer
	if s.carried and s.carriers().x < 0:
		s.carried = false                       # no one left to carry him: he lies where he is
		s.lying = true
		s.path.clear()
		s.status = "WOUNDED, lying where he fell"
	var aid := _aid_post(s.center())
	var at_aid := aid != null and aid.center().distance_to(s.center()) <= AID_R
	if s.carried and not s.moving():
		if at_aid:
			s.carried = false
			s.lying = true
			s.status = "WOUNDED, at the %s" % BuildControl.NAMES.get(aid.kind, aid.kind)
		elif aid != null:
			s.order_move(aid.approach(nav))
	if s.lying:
		heal_t += dt
		var need := HEAL_S if at_aid else HEAL_ALONE_S
		s.status = "WOUNDED, recovering %d%%" % int(clampf(heal_t / need, 0.0, 1.0) * 100.0)
		if heal_t >= need:
			wounded = false
			s.lying = false
			s.carried = false
			s.status = ""
			var j := s.officer_index()
			s.md[j]["hp"] = 1
			_arrived_report("The officer is back on his feet", s.center(), t)


# ------------------------------------------------------------------ the officer's powers

## Seconds until Rally can be used again (0: ready).
func rally_wait() -> float:
	return maxf(0.0, rally_at + RALLY_EVERY - t)


func hold_wait() -> float:
	return maxf(0.0, hold_at + HOLD_EVERY - t)


## True while "hold the line" lasts.
func hold_on() -> bool:
	return t - hold_at < HOLD_S and has_officer() and not wounded


func _power_ok(wait: float) -> bool:
	if not has_officer() or run_over:
		return false
	if wounded:
		say("The officer is wounded")
		return false
	if wait > 0.0:
		say("Not ready yet (%d s)" % int(ceil(wait)))
		return false
	return true


## Rally: squads within 150 m of the officer shake off the fire and stop being pinned. Returns how many.
func rally() -> int:
	if not _power_ok(rally_wait()):
		return 0
	rally_at = t
	var n := 0
	for s in squads.squads:
		if s != officer and s.side == 0 and near_officer(s):
			s.supp = 0.0
			s.pinned = false
			n += 1
	officer.act(officer.officer_index(), "rally")
	say("Rally! (%d squad%s)" % [n, "" if n == 1 else "s"])
	return n


## Hold the line: for 30 s squads near the officer fire faster and cannot be pinned; he plants his feet.
func hold() -> bool:
	if not _power_ok(hold_wait()):
		return false
	hold_at = t
	var j := officer.officer_index()
	officer.act(j, "hold")
	officer.md[j]["act_until"] = officer.clock + HOLD_S
	officer.path.clear()
	say("Hold the line! (30 s)")
	return true


# ------------------------------------------------------------------ linemen

func _linemen() -> Array[Squad]:
	var out: Array[Squad] = []
	for s in squads.squads:
		if s.kind == "linemen" and not s.men.is_empty():
			out.append(s)
	return out


## A lineman section with nothing to do: no wire job, not mending, not on the move, no order in the last 10 s.
func _free(s: Squad) -> bool:
	return not s.has_meta("wire_job") and not s.has_meta("fix") and not s.moving() \
		and t - float(s.get_meta("order_got", -999.0)) > 10.0


## Linemen take planned wires (walk to the first end, then out along it) and mend cuts when free.
func _run_linemen() -> void:
	var crews := _linemen()
	for w in wires:
		if float(w.get("laid", 1.0)) >= 1.0:
			continue
		var a: BuildSite = w["a"]
		var b: BuildSite = w["b"]
		if not build.sites.has(a) or not build.sites.has(b):
			continue
		var sq: Variant = w["crew"]
		if sq != null and (not is_instance_valid(sq) or (sq as Squad).men.is_empty() or _meta(sq, "wire_job") != w):
			w["crew"] = null
			sq = null
		if sq == null:
			var best: Squad = null
			var bd := INF
			for c in crews:
				if _free(c) and c.center().distance_to(a.center()) < bd:
					bd = c.center().distance_to(a.center())
					best = c
			if best == null:
				continue
			w["crew"] = best
			best.set_meta("wire_job", w)
			w["stage"] = "to_start"
			best.status = "to lay wire"
			best.order_move(_wire_side(a, b))
			continue
		var s: Squad = sq
		var A := a.center()
		var B := b.center()
		match String(w["stage"]):
			"to_start":
				if not s.moving():
					if s.center().distance_to(A) < 40.0:
						w["stage"] = "laying"
						s.order_move(_wire_side(b, a))
					else:
						s.order_move(_wire_side(a, b))
			"laying":
				var L := maxf(A.distance_to(B), 1.0)
				var u := clampf((s.center() - A).dot((B - A) / L) / L, 0.0, 1.0)
				var off_line := Geometry2D.get_closest_point_to_segment(s.center(), A, B).distance_to(s.center())
				if u > float(w["laid"]) + 0.01 and off_line < LAY_NEAR:
					w["laid"] = minf(u, 0.99)
					_wires_dirty = true
				s.status = "laying wire %d%%" % int(float(w["laid"]) * 100.0)
				if not s.moving():
					if s.center().distance_to(B) < 40.0:
						w["laid"] = 1.0
						w["crew"] = null
						s.remove_meta("wire_job")
						s.status = ""
						_wires_dirty = true
						say("Wire laid by %s" % s.title)
					else:
						s.order_move(_wire_side(b, a))
	# Free linemen mend the nearest cut nobody is mending.
	for c in crews:
		if not _free(c):
			continue
		var best: Variant = null
		var bd := LINEMEN_MEND_R
		for w in wires:
			if bool(w["cut"]) and w["fixer"] == null:
				var d := c.center().distance_to(w["cut_at"])
				if d < bd:
					bd = d
					best = w
		if best != null:
			fix(c, best)


## A squad's note (null when it has none: get_meta with a null default would complain).
static func _meta(o: Object, key: String) -> Variant:
	return o.get_meta(key) if o.has_meta(key) else null


## Where linemen stand at one end of a wire: just outside the building on the side facing the other end (not its
## front door, which may face away and send them the long way round).
func _wire_side(at: BuildSite, other: BuildSite) -> Vector2:
	var dir := (other.center() - at.center()).normalized()
	var reach := maxf(at.size.x, at.size.y) * MapData.CELL * 0.5 + 6.0
	return nav.nearest_open(at.center() + dir * reach)


## Orders to the officer's own squad while he is wounded are refused.
func can_order(s: Squad) -> bool:
	return not (s == officer and wounded)


# ------------------------------------------------------------------ showing it

func _show_tags() -> void:
	for s in squads.squads:
		if s.side != 0:
			continue
		var tag := ""
		if s.has_meta("order_eta"):
			tag = "order coming (%d s)" % maxi(0, int(ceil(float(s.get_meta("order_eta")) - t)))
		elif s.has_meta("order_got") and t - float(s.get_meta("order_got")) < 4.0:
			tag = "order in"
		s.comms_tag = tag


## The words a unit card shows for the squad's orders ("" when nothing is on its way).
func card_note(s: Squad) -> String:
	return s.comms_tag


func _draw_overlay() -> void:
	_draw_wire_ghost()
	_over_imm.clear_surfaces()
	if not overlay:
		return
	var up := 100.0
	if cam != null:
		var cp := cam.global_position
		up = cp.y - nav.height(Vector2(cp.x, cp.z))
	_ow = clampf(up * 0.01, 0.3, 6.0)
	_over_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var o: Variant = officer_at()
	if o != null:
		_circle(o, NEAR, Color(1.0, 0.9, 0.35))
	for w in wires:
		var a := (w["a"] as BuildSite).center()
		var b := (w["b"] as BuildSite).center()
		var col := Color(0.35, 0.9, 1.0) if live(w) else (Color(1.0, 0.3, 0.25) if bool(w["cut"]) else Color(0.6, 0.6, 0.6))
		if float(w.get("laid", 1.0)) < 1.0:
			col = Color(0.75, 0.75, 0.75)       # planned: grey until the linemen finish it
		_path3([a, b], col, 6.0)
		if bool(w["cut"]):
			var c: Vector2 = w["cut_at"]
			var k := _ow * 4.0
			_path3([c + Vector2(-k, -k), c + Vector2(k, k)], Color(1, 0.2, 0.15), 6.5)
			_path3([c + Vector2(-k, k), c + Vector2(k, -k)], Color(1, 0.2, 0.15), 6.5)
	for p in points():
		_circle(p.center(), maxf(12.0, _ow * 6.0), Color(0.35, 0.9, 1.0) if p.kind in WIRE_POINTS else Color(0.8, 1.0, 0.6))
	for m in messages:
		var legs: Array = m["legs"]
		var li := int(m["leg"])
		if li >= legs.size():
			continue
		var leg: Dictionary = legs[li]
		var col2 := Color(1.0, 0.95, 0.5) if m["kind"] == "order" else Color(1.0, 0.6, 0.3)
		if leg["type"] == "wire":
			var path: Array = leg["path"]
			var u := clampf((t - float(m["leg_t"])) / maxf(float(leg["dur"]), 0.01), 0.0, 1.0)
			var pts: Array[Vector2] = []
			for q: BuildSite in path:
				pts.append(q.center())
			var at := _along(pts, u)
			_circle(at, maxf(6.0, _ow * 4.0), col2)
			_circle(at, maxf(3.0, _ow * 2.0), col2)
		elif leg["type"] == "run" and m.has("runner"):
			var rp: PackedVector2Array = m["rpath"]
			var pts2: Array[Vector2] = [m["runner"]["at"]]
			for q in rp:
				pts2.append(q)
			_path3(pts2, col2, 1.0)
			_circle(m["runner"]["at"], maxf(3.0, _ow * 3.0), col2)
	_over_imm.surface_end()


func _along(pts: Array[Vector2], u: float) -> Vector2:
	var L := 0.0
	for i in range(1, pts.size()):
		L += pts[i - 1].distance_to(pts[i])
	var want := L * u
	for i in range(1, pts.size()):
		var d := pts[i - 1].distance_to(pts[i])
		if want <= d:
			return pts[i - 1].lerp(pts[i], want / maxf(d, 0.01))
		want -= d
	return pts[pts.size() - 1]


func _circle(c: Vector2, r: float, col: Color) -> void:
	var n := clampi(int(r / 4.0), 16, 96)
	for k in n:
		_seg(Vector2.from_angle(TAU * k / n) * r + c, Vector2.from_angle(TAU * (k + 1) / n) * r + c, col, 1.0)


func _path3(pts: Array, col: Color, up: float) -> void:
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var n := maxi(1, int(a.distance_to(b) / 8.0))
		for k in n:
			_seg(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, up)


## One stretch of the comms map: a flat band _ow metres wide, a little above the ground.
func _seg(a: Vector2, b: Vector2, col: Color, up: float) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var s := Vector2(-d.y, d.x).normalized() * _ow * 0.5
	var ya := nav.height(a) + up
	var yb := nav.height(b) + up
	var q := [Vector3(a.x - s.x, ya, a.y - s.y), Vector3(a.x + s.x, ya, a.y + s.y), Vector3(b.x + s.x, yb, b.y + s.y),
		Vector3(b.x - s.x, yb, b.y - s.y)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		_over_imm.surface_set_color(col)
		_over_imm.surface_add_vertex(q[i])


func _update_ui() -> void:
	var lines: Array[String] = []
	for r in reports:
		var age := t - float(r["t"])
		if age > 90.0:
			continue
		var late := float(r["late"])
		lines.append("%s%s" % [r["text"], ("   (%d s late)" % int(late)) if late >= 1.0 else ""])
	_report_box.text = "\n".join(lines)


func say(text: String) -> void:
	note = text
	_note_t = 3.0


func help() -> String:
	var on_way := 0
	for m in messages:
		if m["kind"] == "order":
			on_way += 1
	var wired := 0
	for w in wires:
		if live(w):
			wired += 1
	return "O comms map   Comms tab: runner post, telegraph, Telegraph wire   [%d order%s on the way, %d wire%s working%s]%s" % [
		on_way, "" if on_way == 1 else "s", wired, "" if wired == 1 else "s",
		", officer WOUNDED" if wounded else "", ("   " + note) if not note.is_empty() else ""]
