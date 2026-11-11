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
## Orders are instant for now: the comms network (step 3) will delay them later.

const PICK_PX := 22.0
const DRAG_PX := 6.0
const SPREAD := 24.0                           # metres between squads sent together
const DOUBLE_S := 0.35
const LINE_PX := 12.0                          # a right drag shorter than this (pixels) is a plain click

var nav: NavGrid
var cam: RtsCamera
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
	_pimm = ImmediateMesh.new()
	_preview = MeshInstance3D.new()
	_preview.mesh = _pimm
	_preview.material_override = Squad._flat(Color(0.55, 1.0, 0.55, 0.9))
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)


## Clears the old squads and puts new ones round a point (metres), facing north.
func spawn(nav_grid: NavGrid, around: Vector2, count := 3) -> void:
	nav = nav_grid
	for s in squads:
		s.queue_free()
	squads.clear()
	for k in count:
		var where := nav.nearest_open(around + Vector2((float(k) - (count - 1) * 0.5) * SPREAD, 0))
		var s := Squad.new()
		add_child(s)
		s.setup(nav, where, Vector2(0, -1), 7 + k, "Rifles %d" % (k + 1))
		squads.append(s)


func selected() -> Array[Squad]:
	var out: Array[Squad] = []
	for s in squads:
		if s.selected:
			out.append(s)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if nav == null:
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
	if k.keycode == KEY_H and not squads.is_empty():
		var sel := selected()
		if sel.is_empty():
			sel = [squads[0]]
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
	_order(g, run)


func _ground2(mp: Vector2) -> Variant:
	var p: Variant = ground_at(mp)
	return null if p == null else Vector2((p as Vector3).x, (p as Vector3).z)


## Plans a drawn line from a to b (metres) for the given squads: one solid line of men. Returns one
## {"squad", "at", "face", "width"} per squad, left to right. Shared by the preview, the order and the check.
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
	var span := width * Squad.LINE_GAP          # each squad's share of the line, so the gaps match the men's
	var mid := (a + b) * 0.5
	var order := sel.duplicate()
	order.sort_custom(func(p: Squad, q: Squad) -> bool: return p.at.dot(dir) < q.at.dot(dir))
	for i in n:
		var c := mid + dir * (float(i) - (n - 1) * 0.5) * span
		out.append({"squad": order[i], "at": c + face * 1.0, "face": face, "width": width})
	return out


## Sends the selected squads onto a drawn line (always at a walk).
func _order_line(a: Vector2, b: Vector2) -> void:
	var failed := 0
	for p: Dictionary in plan_line(selected(), a, b):
		var s: Squad = p["squad"]
		var to: Vector2 = p["at"]
		if not s.order_move(to, false, p["face"], p["width"]) and not s.order_move(nav.nearest_open(to), false, p["face"], p["width"]):
			failed += 1
	if failed > 0:
		say("No way there on foot")


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
		for i in Squad.MEN:
			var o := Squad.free_offset(i, p["width"])
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


## Sends the selected squads to g, side by side across the way they are going.
func _order(g: Vector2, run: bool) -> void:
	var sel := selected()
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
	var failed := 0
	for i in sel.size():
		var to := g + side * (float(i) - (sel.size() - 1) * 0.5) * SPREAD
		if not sel[i].order_move(to, run, fwd) and not sel[i].order_move(g, run, fwd):
			failed += 1
	if failed > 0:
		say("No way there on foot")


func say(text: String) -> void:
	note = text
	_note_t = 2.5


func _process(delta: float) -> void:
	_note_t -= delta
	if _note_t <= 0.0:
		note = ""


func help() -> String:
	var n := selected().size()
	return "Left click/drag select squads (Shift adds), right click move, double right click run, right drag draw a line, H go to squads   [%d selected]%s" % [
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
