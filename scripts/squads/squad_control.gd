class_name SquadControl
extends Node3D
## Iron Front: selecting squads and giving move orders (squads round 1).
## - Left click on a squad selects it; Shift adds it to the selection. A click on empty ground clears it.
## - Left drag draws a box and selects every squad with a man inside it.
## - Right click sends the selected squads there, spread side by side; a double right click sends them at a run.
## - Right drag draws the line the selected squads will stand on (Total War style): one solid line of men,
##   squads side by side in their current left-to-right order, facing forward from the line (drawn left to right
##   on screen they face away from the camera; drawn the other way they face it). A long line makes a wide, shallow
##   formation; a short one a narrow, deep one. A preview of every man's place shows while dragging. Always a walk.
## - H brings the camera to the selected squads (or the first squad).
## - Control groups: Ctrl+1..9 saves the selection under that number; 1..9 picks it again, and pressing the same
##   number twice quickly takes the camera there. A number with no group saved goes on to the other keys
##   (the blast test's shell sizes).
## - Unit cards: one card per selected squad at the bottom left, with its men, what it is doing, and a Run/Walk
##   switch while it moves (see UnitCards).
## - Engineers (building round): a move order drops their building jobs; a right click on a building that is not
##   finished sends the selected engineers to build it (other squads just move there).
## - Fighting round: a right click on an enemy squad has the selected squads attack it (they close to range and
##   fire); a right click on a finished MG nest or gun pit sends the first selected rifle squad to man it, and on a
##   house, ruin or one of our finished buildings to go in and fight from it (fighting round 2).
## Comms round: every order goes through the CommsControl (`dispatch`): squads near the officer take it at once,
## the rest when a runner or the wire brings it. A right click on a cut telegraph wire with engineers selected
## sends them to splice it. The wounded officer takes no orders.

const PICK_PX := 22.0
const DRAG_PX := 6.0
const SPREAD := 24.0                           # metres between squads sent together
const DOUBLE_S := 0.35
const LINE_PX := 12.0                          # a right drag shorter than this (pixels) is a plain click
const GROUP_DOUBLE_S := 0.4                    # a second press of a group's number this soon moves the camera

var nav: NavGrid
var cam: RtsCamera
var build: Node                                # the BuildControl (engineers' jobs), if there is one
var combat: Node                               # the CombatControl (attack and man-a-post orders), if there is one
var comms: Node                                # the CommsControl (orders travel), if there is one
var squads: Array[Squad] = []
var box: Panel
var note := ""
var _press := Vector2.ZERO
var _down := false
var _last_right := -10.0
var _last_target := Vector2.ZERO
var _note_t := 0.0
var _rpress := Vector2.ZERO                    # right button: where it went down (screen) ...
var _rdown := false
var _rstart: Variant = null                    # ... and on the ground (Vector2 or null)
var _rdrag := false
var _preview: MeshInstance3D
var _pimm: ImmediateMesh
var groups := {}                               # number 1..9 -> Array of squads
var cards: UnitCards
var _last_group := -1
var _last_group_t := -10.0


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.86, 0.25, 0.12)
	sb.border_color = Color(1.0, 0.86, 0.25, 0.9)
	sb.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	layer.add_child(box)
	cards = UnitCards.new()
	cards.control = self
	layer.add_child(cards)
	_pimm = ImmediateMesh.new()
	_preview = MeshInstance3D.new()
	_preview.mesh = _pimm
	_preview.material_override = Squad._flat(Color(0.55, 1.0, 0.55, 0.9))
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)


## Clears the old squads and puts new ones round a point (metres), facing north: the rifle squads in front, the
## engineer sections behind them.
func spawn(nav_grid: NavGrid, around: Vector2, count := 3, engineers := 2) -> void:
	nav = nav_grid
	for s in squads:
		s.queue_free()
	squads.clear()
	groups.clear()
	for k in count:
		var where := nav.nearest_open(around + Vector2((float(k) - (count - 1) * 0.5) * SPREAD, 0))
		var s := Squad.new()
		add_child(s)
		s.setup(nav, where, Vector2(0, -1), 7 + k, "Rifles %d" % (k + 1))
		squads.append(s)
	for k in engineers:
		var where := nav.nearest_open(around + Vector2((float(k) - (engineers - 1) * 0.5) * SPREAD, 22.0))
		var s := Squad.new()
		add_child(s)
		s.setup(nav, where, Vector2(0, -1), 41 + k, "Engineers %d" % (k + 1), "engineers")
		squads.append(s)


func selected_engineers() -> Array[Squad]:
	var out: Array[Squad] = []
	for s in selected():
		if s.is_engineers():
			out.append(s)
	return out


func selected() -> Array[Squad]:
	var out: Array[Squad] = []
	for s in squads:
		if s.selected:
			out.append(s)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if nav == null or (build != null and build.busy()):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_down = true
			elif _down:
				_down = false
				box.visible = false
				if _press.distance_to(mb.position) > DRAG_PX:
					_select_box(Rect2(_press, Vector2.ZERO).expand(mb.position), mb.shift_pressed)
				else:
					_select_click(mb.position, mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rdown = true
				_rdrag = false
				_rpress = mb.position
				_rstart = _ground2(mb.position)
			elif _rdown:
				_rdown = false
				_pimm.clear_surfaces()
				var end: Variant = _ground2(mb.position)
				if _rdrag and _rstart != null and end != null:
					_order_line(_rstart, end)
					_last_right = -10.0                   # a drag never starts a double click
				else:
					_right_click(mb.position)
	elif event is InputEventMouseMotion and _rdown:
		var mm := event as InputEventMouseMotion
		if not _rdrag and _rpress.distance_to(mm.position) > LINE_PX and not selected().is_empty():
			_rdrag = true
		if _rdrag and _rstart != null:
			var end: Variant = _ground2(mm.position)
			if end != null:
				_draw_preview(plan_line(selected(), _rstart, end))
	elif event is InputEventMouseMotion and _down:
		var mm := event as InputEventMouseMotion
		if _press.distance_to(mm.position) > DRAG_PX:
			var r := Rect2(_press, Vector2.ZERO).expand(mm.position)
			box.position = r.position
			box.size = r.size
			box.visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_9:
		var n := k.keycode - KEY_1 + 1
		if k.ctrl_pressed:
			save_group(n)
			get_viewport().set_input_as_handled()
		elif recall_group(n, Time.get_ticks_msec() / 1000.0):
			get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_H and not squads.is_empty():
		var sel := selected()
		if sel.is_empty():
			sel.append(squads[0])
		look_at_squads(sel)


## Ctrl+number: the selected squads become group n (an empty selection clears it).
func save_group(n: int) -> void:
	var sel := selected()
	if sel.is_empty():
		groups.erase(n)
		say("Group %d cleared" % n)
	else:
		groups[n] = sel
		say("Group %d: %d squad%s" % [n, sel.size(), "" if sel.size() == 1 else "s"])


## Number: selects group n (false if there is none). The same number again within GROUP_DOUBLE_S moves the camera.
func recall_group(n: int, now: float) -> bool:
	if not groups.has(n):
		return false
	var g: Array = (groups[n] as Array).filter(func(s: Squad) -> bool: return is_instance_valid(s) and squads.has(s))
	if g.is_empty():
		groups.erase(n)
		return false
	for s in squads:
		s.selected = g.has(s)
	if n == _last_group and now - _last_group_t < GROUP_DOUBLE_S and cam != null:
		var typed: Array[Squad] = []
		typed.assign(g)
		look_at_squads(typed)
	_last_group = n
	_last_group_t = now
	return true


## The camera goes to the middle of these squads.
func look_at_squads(sel: Array[Squad]) -> void:
	if sel.is_empty() or cam == null:
		return
	var c := Vector2.ZERO
	for s in sel:
		c += s.at
	c /= sel.size()
	cam.target = Vector3(c.x, 0, c.y)
	cam.height_goal = minf(cam.height_goal, 90.0)


func _select_click(at: Vector2, add: bool) -> void:
	var best: Squad = null
	var best_d := PICK_PX
	for s in squads:
		for p in s.screen_points(cam):
			var d := p.distance_to(at)
			if d < best_d:
				best_d = d
				best = s
	if not add:
		for s in squads:
			s.selected = false
	if best != null:
		best.selected = not best.selected if add else true


func _select_box(r: Rect2, add: bool) -> void:
	for s in squads:
		var hit := false
		for p in s.screen_points(cam):
			if r.has_point(p):
				hit = true
				break
		if hit:
			s.selected = true
		elif not add:
			s.selected = false


## A right click (no drag): move there; a second click soon after runs to the first click's spot.
func _right_click(at: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var run := now - _last_right < DOUBLE_S
	_last_right = now
	var p: Variant = _ground2(at)
	if p == null:
		return
	var g: Vector2 = p
	if run:
		g = _last_target
	_last_target = g
	var sel := orderable(selected())
	if combat != null and not run and not sel.is_empty():
		var foe: Variant = combat.enemy_at(g)
		if foe != null:
			dispatch(sel, func(got: Array[Squad]) -> void:
				for s in got:
					if is_instance_valid(foe) and not foe.men.is_empty():
						s.cancel_job()
						s.attack = foe, "attack")
			say("Attack %s" % foe.title)
			return
	if build != null and combat != null and not run:
		var post: Variant = build.site_at(g)
		if post != null and post.done and post.kind in ["mg_nest", "gun_pit"]:
			for s in sel:
				if s.can_fire() and s.kind == "rifles":
					var one: Array[Squad] = [s]
					dispatch(one, func(got: Array[Squad]) -> void:
						if build.sites.has(post):
							combat.man_post(got[0], post), "man the post")
					return
	if combat != null and not run:
		var house: Variant = combat.garrison_at(g)
		if house != null:
			for s in sel:
				if s.can_fire() and s.kind == "rifles":
					var one: Array[Squad] = [s]
					dispatch(one, func(got: Array[Squad]) -> void:
						combat.garrison(got[0], house), "go in")
					say("%s into the %s" % [s.title, house.label()])
					return
	if comms != null and not run:
		var w: Variant = comms.cut_wire_at(g)
		var eng: Array[Squad] = []
		for s in sel:
			if s.is_engineers():
				eng.append(s)
		if w != null and not eng.is_empty():
			var first: Array[Squad] = [eng[0]]
			dispatch(first, func(got: Array[Squad]) -> void:
				if bool(w["cut"]):
					comms.fix(got[0], w), "splice the wire")
			say("%s to splice the wire" % eng[0].title)
			sel.erase(eng[0])
			if sel.is_empty():
				return
	if build != null and not run:
		var site: Variant = build.site_at(g)
		if site != null and not site.done:
			var rest: Array[Squad] = []
			var eng2: Array[Squad] = []
			for s in sel:
				if s.is_engineers():
					eng2.append(s)
				else:
					rest.append(s)
			if not eng2.is_empty():
				dispatch(eng2, func(got: Array[Squad]) -> void:
					for s in got:
						if build.sites.has(site):
							build.assign(s, site, true), "build")
			sel = rest
	_order(g, run, sel)


## Gives an order to these squads through the comms (at once if there is none): `apply` gets the squads it reached.
func dispatch(sel: Array[Squad], apply: Callable, what := "order") -> void:
	if sel.is_empty():
		return
	if comms == null:
		apply.call(sel)
	else:
		comms.send(sel, apply, what)


## The squads that can take orders (the wounded officer cannot).
func orderable(sel: Array[Squad]) -> Array[Squad]:
	if comms == null:
		return sel
	var out: Array[Squad] = []
	for s in sel:
		if comms.can_order(s):
			out.append(s)
		else:
			say("The officer is wounded and takes no orders")
	return out


## The unit card's Run/Walk switch, as an order.
func order_run(s: Squad, on: bool) -> void:
	var one: Array[Squad] = orderable([s] as Array[Squad])
	dispatch(one, func(got: Array[Squad]) -> void:
		for q in got:
			q.set_running(on), "run" if on else "walk")


func _ground2(mp: Vector2) -> Variant:
	var p: Variant = ground_at(mp)
	return null if p == null else Vector2((p as Vector3).x, (p as Vector3).z)


## Plans a drawn line from a to b (metres) for the given squads: one solid line of men. Returns one
## {"squad", "at", "face", "width"} per squad, left to right. Shared by the preview, the order and the check.
## Squads of different sizes each take their own share: a squad never stands wider than it has men.
static func plan_line(sel: Array[Squad], a: Vector2, b: Vector2) -> Array:
	var out := []
	var n := sel.size()
	if n == 0:
		return out
	var dir := (b - a).normalized() if a.distance_to(b) > 0.01 else Vector2(1, 0)
	var face := Vector2(dir.y, -dir.x)            # the line runs to the squad's right hand
	# How many men wide the whole line is, shared out evenly between the squads.
	var cols := int(round(a.distance_to(b) / Squad.LINE_GAP)) + 1
	var width := clampi(int(round(float(cols) / n)), Squad.MIN_FILES, Squad.MEN)
	var mid := (a + b) * 0.5
	var order := sel.duplicate()
	order.sort_custom(func(p: Squad, q: Squad) -> bool: return p.at.dot(dir) < q.at.dot(dir))
	# Each squad's share of the line is its width in men, so the gaps between squads match the men's.
	var widths: Array[int] = []
	var total := 0.0
	for sq: Squad in order:
		var wi := clampi(width, mini(Squad.MIN_FILES, sq.count), sq.count)
		widths.append(wi)
		total += wi * Squad.LINE_GAP
	var along := -total * 0.5
	for i in n:
		var span := widths[i] * Squad.LINE_GAP
		var c := mid + dir * (along + span * 0.5)
		along += span
		out.append({"squad": order[i], "at": c + face * 1.0, "face": face, "width": widths[i], "count": order[i].count})
	return out


## Sends the selected squads onto a drawn line (always at a walk).
func _order_line(a: Vector2, b: Vector2) -> void:
	var plan := {}
	var sel := orderable(selected())
	for p: Dictionary in plan_line(sel, a, b):
		plan[p["squad"]] = p
	dispatch(sel, func(got: Array[Squad]) -> void:
		var failed := 0
		for s in got:
			var p: Dictionary = plan[s]
			var to: Vector2 = p["at"]
			s.cancel_job()
			s.attack = null
			if not s.order_move(to, false, p["face"], p["width"]) and not s.order_move(nav.nearest_open(to), false, p["face"], p["width"]):
				failed += 1
		if failed > 0:
			say("No way there on foot"), "line")


## Every man's place on the drawn line: a short tick pointing the way he will face, and an arrow per squad.
func _draw_preview(plan: Array) -> void:
	_pimm.clear_surfaces()
	if plan.is_empty():
		return
	_pimm.surface_begin(Mesh.PRIMITIVE_LINES)
	for p: Dictionary in plan:
		var at: Vector2 = p["at"]
		var f: Vector2 = p["face"]
		var right := Vector2(-f.y, f.x)
		for i in int(p["count"]):
			var o := Squad.free_offset(i, p["width"], p["count"])
			var q := at + right * o.x - f * o.y
			_seg(q - right * 0.4, q + right * 0.4)
			_seg(q, q + f * 0.7)
		var tip := at + f * 3.0
		_seg(at, tip)
		_seg(tip, tip - f * 1.2 + right * 0.8)
		_seg(tip, tip - f * 1.2 - right * 0.8)
	_pimm.surface_end()


func _seg(p: Vector2, q: Vector2) -> void:
	_pimm.surface_add_vertex(Vector3(p.x, nav.height(p) + 0.3, p.y))
	_pimm.surface_add_vertex(Vector3(q.x, nav.height(q) + 0.3, q.y))


## Sends the squads (the selected ones unless given) to g, side by side across the way they are going.
func _order(g: Vector2, run: bool, sel: Array[Squad] = selected()) -> void:
	if sel.is_empty():
		return
	var c := Vector2.ZERO
	for s in sel:
		c += s.at
	c /= sel.size()
	var fwd := (g - c).normalized() if g.distance_to(c) > 1.0 else Vector2(0, -1)
	var side := Vector2(-fwd.y, fwd.x)
	# Keep the squads in the same left-to-right order they stand in now.
	sel.sort_custom(func(a: Squad, b: Squad) -> bool: return a.at.dot(side) < b.at.dot(side))
	var spots := {}
	for i in sel.size():
		spots[sel[i]] = g + side * (float(i) - (sel.size() - 1) * 0.5) * SPREAD
	dispatch(sel, func(got: Array[Squad]) -> void:
		var failed := 0
		for s in got:
			s.cancel_job()
			s.attack = null
			if not s.order_move(spots[s], run, fwd) and not s.order_move(g, run, fwd):
				failed += 1
		if failed > 0:
			say("No way there on foot"), "run" if run else "move")


func say(text: String) -> void:
	note = text
	_note_t = 2.5


func _process(delta: float) -> void:
	_note_t -= delta
	if _note_t <= 0.0:
		note = ""


func help() -> String:
	var n := selected().size()
	return "Left click/drag select squads (Shift adds), right click move, double right click run, right drag draw a line, H go to squads, Ctrl+1-9 save a group, 1-9 pick it (twice: go there)   [%d selected]%s" % [
		n, ("   " + note) if not note.is_empty() else ""]


## Where a screen point meets the ground (or null), following ramps.
func ground_at(mp: Vector2) -> Variant:
	var o := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var t := 0.0
	var prev := 0.0
	while t < 12000.0:
		var p := o + dir * t
		if p.y <= nav.height(Vector2(p.x, p.z)):
			var a := prev
			var b := t
			for i in 16:
				var m := (a + b) * 0.5
				var q := o + dir * m
				if q.y <= nav.height(Vector2(q.x, q.z)):
					b = m
				else:
					a = m
			return o + dir * b
		prev = t
		t += maxf(0.5, t * 0.01)
	return null
