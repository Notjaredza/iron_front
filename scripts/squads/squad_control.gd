class_name SquadControl
extends Node3D
## Iron Front: selecting squads and giving move orders (squads round 1).
## - Left click on a squad selects it; Shift adds it to the selection. A click on empty ground clears it.
## - Left drag draws a box and selects every squad with a man inside it.
## - Right click sends the selected squads there, spread side by side; a double right click sends them at a run.
## - H brings the camera to the selected squads (or the first squad).
## Orders are instant for now: the comms network (step 3) will delay them later.

const PICK_PX := 22.0
const DRAG_PX := 6.0
const SPREAD := 24.0                           # metres between squads sent together
const DOUBLE_S := 0.35

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
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var now := Time.get_ticks_msec() / 1000.0
			var run := now - _last_right < DOUBLE_S
			_last_right = now
			var p: Variant = ground_at(mb.position)
			if p != null:
				var g := Vector2((p as Vector3).x, (p as Vector3).z)
				if run:
					g = _last_target                      # the double click runs to the first click's spot
				_last_target = g
				_order(g, run)
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
		if not sel[i].order_move(to, run) and not sel[i].order_move(g, run):
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
	return "Left click/drag select squads (Shift adds), right click move, double right click run, H go to squads   [%d selected]%s" % [
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
