class_name BuildControl
extends Node3D
## Iron Front: putting buildings on the map (building round).
## - Pick a building in the build menu (B shows or hides it). A see-through copy follows the mouse on the 8 m
##   grid: green where it fits, red where it does not. R turns it a quarter. Left click places it; hold Shift to
##   place more of the same. Right click or Esc stops placing.
## - Lines (walls, sandbags, wire, concertina, hedgehogs, teeth): press, drag along the ground and let go. Every
##   cell that fits is placed; walls and sandbag lines join up into corners, T's and crosses as they go.
## - A building fits on flat dry open ground, all on one level: not on cliffs, water, fords, streams, marsh,
##   ramps, woods, hedges, lone trees, rails or village houses, and not on another building or on men.
## - Placing marks out a plot and closes its cells to walkers. The selected engineers (or, if none are selected,
##   the nearest section) walk over and build it: the frame and scaffold go up, then half built, then finished.
##   More sections on one building build it faster. A section that finishes its list helps the nearest
##   building nobody is working on. Delete or X over a building that is not finished cancels it.
## - Building is free for now (supply comes later).

const LINE_KINDS := ["wall", "sandbag_line", "wire_belt", "concertina", "hedgehogs", "teeth"]
const WALL_PIECES := ["tower", "bastion", "gate"]  # single wall cells; they join the wall like any wall cell
const MAX_LINE := 40
const BLOCKED := MapData.F_STREAM | MapData.F_FORD | MapData.F_MARSH | MapData.F_WOOD | MapData.F_HEDGE | MapData.F_TREE
const FAR_AT := 350.0                          # camera height above which buildings use their far look
const AUTO_HELP := 200.0                       # metres: how far a section looks for a building to help with
const NAMES := {"hq": "HQ", "barracks": "Barracks", "depot": "Depot", "halt": "Halt", "station": "Station",
	"engine_shed": "Engine shed", "water_tower": "Water tower", "coal_stage": "Coal stage", "signal_box": "Signal box",
	"runner_post": "Runner post", "telegraph": "Telegraph", "lamp_tower": "Lamp tower", "pigeon_loft": "Pigeon loft",
	"lab_comms": "Comms lab", "lab_weapons": "Weapons lab", "lab_rail": "Rail lab", "lab_defences": "Defences lab",
	"wreck_yard": "Wreck yard", "sandbag_line": "Sandbags", "wire_belt": "Wire belt", "concertina": "Concertina",
	"hedgehogs": "Hedgehogs", "teeth": "Teeth", "mg_nest": "MG nest", "gun_pit": "Gun pit", "wall": "Wall",
	"tower": "Tower", "bastion": "Bastion", "gate": "Road gate"}
const LINE_TIME := {"wall": 14.0, "sandbag_line": 8.0, "wire_belt": 6.0, "concertina": 5.0, "hedgehogs": 5.0,
	"teeth": 8.0, "tower": 40.0, "bastion": 40.0, "gate": 24.0}

var nav: NavGrid
var data: MapData
var cam: RtsCamera
var squads: SquadControl
var view: MapView
var menu: BuildMenu
var sites: Array[BuildSite] = []
var at_cell := {}                              # Vector2i -> BuildSite
var placing := ""                              # the kind being placed, or ""
var rot := 0
var note := ""
var _note_t := 0.0
var _templates := {}                           # kind -> a Building (not in the tree) the ghosts copy
var _ghosts: Array[MeshInstance3D] = []
var _ghost_kind := ""
var _line_from: Variant = null                 # the cell a line drag started on
var _far := false
var _night := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	menu = BuildMenu.new()
	layer.add_child(menu)
	menu.picked.connect(start_placing)


func _exit_tree() -> void:
	for k: String in _templates:
		(_templates[k] as Node).free()
	_templates.clear()


## A new map: forget every building.
func reset(nav_grid: NavGrid, map_data: MapData) -> void:
	for s in sites:
		if s.node:
			s.node.queue_free()
	sites.clear()
	at_cell.clear()
	nav = nav_grid
	data = map_data
	stop_placing()


func busy() -> bool:
	return not placing.is_empty()


static func is_line(k: String) -> bool:
	return k in LINE_KINDS


static func family_of(k: String) -> String:
	if k == "wall" or k in WALL_PIECES:
		return "wall"
	if k == "sandbag_line":
		return "sandbag"
	return ""


## Footprint in cells for a kind turned rot quarter turns.
static func footprint(k: String, r := 0) -> Vector2i:
	var t := Vector2i.ONE
	if Buildings.KINDS.has(k):
		t = Buildings.KINDS[k][0]
	return Vector2i(t.y, t.x) if r % 2 == 1 else t


## A building of a kind, for the map, the ghost and the menu picture. mask: the joining arms of a wall or
## sandbag piece (0: a straight east-west piece).
static func make_building(k: String, mask := 0, variant := "") -> Building:
	var m := mask if mask != 0 else (BldWalls.E | BldWalls.W)
	if k == "wall" or k in WALL_PIECES:
		return BldWalls.make(m, variant if k == "wall" else k)
	if k == "sandbag_line":
		return BldDefences.line(m)
	return Buildings.make(k)


# ------------------------------------------------------------------ placing rules

## True if a building may stand on cell c. level: the level every cell must share (-1: any). men: cells with a
## man in them.
func cell_ok(c: Vector2i, level := -1, men := {}) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= data.w or c.y >= data.h:
		return false
	var i := c.y * data.w + c.x
	var f := data.walk[i]
	if f == 0 or f == MapData.FLAT_NONE or (level >= 0 and f != level):
		return false
	if data.busy[i] == 1 or (data.feat[i] & BLOCKED) != 0 or nav.ramp_at.has(i) or nav.open[i] == 0:
		return false
	return not at_cell.has(c) and not men.has(c)


## True if a whole footprint fits.
func fits(origin: Vector2i, size: Vector2i, men := {}) -> bool:
	if origin.x < 0 or origin.y < 0 or origin.x >= data.w or origin.y >= data.h:
		return false
	var level := data.walk[origin.y * data.w + origin.x]
	for z in size.y:
		for x in size.x:
			if not cell_ok(origin + Vector2i(x, z), level, men):
				return false
	return true


## Cells where a man stands now (no building may go there).
func men_cells() -> Dictionary:
	var out := {}
	if squads == null:
		return out
	for s in squads.squads:
		for p in s.mpos:
			out[nav.cell_of(p)] = true
	return out


## The footprint's top-left cell for a building centred on the mouse.
static func origin_at(p: Vector2, size: Vector2i) -> Vector2i:
	var m := p / MapData.CELL - Vector2(size) * 0.5
	return Vector2i(roundi(m.x), roundi(m.y))


## The cells of a straight line from a to b (along whichever way is longer), at most MAX_LINE long.
static func line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var d := b - a
	var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
	var n := mini(maxi(absi(d.x), absi(d.y)), MAX_LINE - 1)
	var out: Array[Vector2i] = []
	for k in n + 1:
		out.append(a + step * k)
		if step == Vector2i.ZERO:
			break
	return out


func site_at(p: Vector2) -> Variant:
	return at_cell.get(nav.cell_of(p), null)


# ------------------------------------------------------------------ placing

## Puts a building on the map as a marked-out plot. Returns the site, or null if it does not fit.
func place(k: String, origin: Vector2i, r := 0, men := {}) -> BuildSite:
	var size := footprint(k, r)
	if not fits(origin, size, men):
		return null
	var s := BuildSite.new()
	s.kind = "wall" if family_of(k) == "wall" else k
	s.variant = k if k in WALL_PIECES else ""
	s.family = family_of(k)
	s.origin = origin
	s.size = size
	s.rot = r if s.family.is_empty() else 0
	s.y = MapData.level_y(data.walk[origin.y * data.w + origin.x])
	if LINE_TIME.has(k):
		s.work_time = LINE_TIME[k]
	else:
		s.work_time = 20.0 + 10.0 * size.x * size.y
	sites.append(s)
	for c in s.cells():
		at_cell[c] = s
		nav.set_blocked(c, true)
	if s.family.is_empty():
		_set_node(s, make_building(k))
	else:
		_rejoin(s.family)
	_show_stage(s)
	return s


## Places a line of cells from a to b; cells that do not fit are left out. Returns the new sites.
func place_line(k: String, a: Vector2i, b: Vector2i, men := {}) -> Array[BuildSite]:
	var out: Array[BuildSite] = []
	var cells := line_cells(a, b)
	var along_z := cells.size() > 1 and cells[1].x == cells[0].x
	for c in cells:
		var s := place(k, c, 1 if along_z and family_of(k).is_empty() else 0, men)
		if s != null:
			out.append(s)
	return out


func _set_node(s: BuildSite, b: Building) -> void:
	if s.node:
		s.node.queue_free()
	s.node = b
	add_child(b)
	var c := s.center()
	b.position = Vector3(c.x, s.y, c.y)
	b.rotation.y = s.rot * PI * 0.5


## Wall and sandbag pieces: each cell's piece follows its neighbours (straight, corner, T, cross, end).
func _rejoin(fam: String) -> void:
	var cells := {}
	var chosen := {}
	for s in sites:
		if s.family == fam:
			cells[s.origin] = true
			if not s.variant.is_empty():
				chosen[s.origin] = s.variant
	var res := BldWalls.solve(cells, {}, chosen)
	for c: Vector2i in res:
		var s: BuildSite = at_cell[c]
		var mask: int = res[c][0]
		var v: String = res[c][1]
		if s.node and int(s.node.get_meta("mask", -1)) == mask and String(s.node.get_meta("variant", "")) == v:
			continue
		var b := BldWalls.make(mask, v) if fam == "wall" else BldDefences.line(mask)
		_set_node(s, b)
		_show_stage(s)


func _show_stage(s: BuildSite) -> void:
	s.node.set_stage(BuildSite.stage_for(s.progress))
	if s.node.workers:
		s.node.workers.visible = false         # the real engineers do the work
	if s.done:
		s.node.set_lights(_night)
		if _far:
			s.node.far(true)


## Cancels a building that is not finished: the plot goes and its cells open again.
func cancel(s: BuildSite) -> void:
	if s.done or not sites.has(s):
		return
	for sq in s.crews.duplicate():
		_leave(sq)
	for sq in squads.squads:
		sq.jobs.erase(s)
	sites.erase(s)
	for c in s.cells():
		at_cell.erase(c)
		nav.set_blocked(c, false)
	s.node.queue_free()
	s.node = null
	if not s.family.is_empty():
		_rejoin(s.family)


# ------------------------------------------------------------------ engineers

## Gives a site to an engineer section: now (dropping what it was doing) or at the end of its list.
func assign(sq: Squad, s: BuildSite, now := false) -> void:
	if now:
		sq.cancel_job()
		_leave(sq)
	if not sq.jobs.has(s) and sq.job != s:
		sq.jobs.append(s)


## Who builds a newly placed site: the selected engineers, or else the nearest section (idle ones first).
func _give_out(new_sites: Array[BuildSite]) -> void:
	if new_sites.is_empty() or squads == null:
		return
	var crew := squads.selected_engineers()
	if crew.is_empty():
		var best: Squad = null
		var best_d := INF
		for sq in squads.squads:
			if not sq.is_engineers():
				continue
			var d := sq.at.distance_to(new_sites[0].center()) + (0.0 if sq.job == null and sq.jobs.is_empty() else 5000.0)
			if d < best_d:
				best_d = d
				best = sq
		if best == null:
			say("No engineers to build it")
			return
		crew = [best]
	for sq in crew:
		for s in new_sites:
			assign(sq, s)


func _leave(sq: Squad) -> void:
	if sq.job != null:
		(sq.job as BuildSite).crews.erase(sq)
	sq.job = null
	sq.stop_work()


## Each frame: sections take their next job, walk over, spread to their spots and work; sites grow.
func step(dt: float) -> void:
	if squads == null:
		return
	for sq in squads.squads:
		if sq.is_engineers():
			_step_crew(sq)
	for s in sites:
		if s.done:
			continue
		var n := 0
		for sq in s.crews:
			n += (sq as Squad).men_at_work()
		if n == 0:
			continue
		var before := BuildSite.stage_for(s.progress)
		s.progress = minf(1.0, s.progress + dt * float(n) / (4.0 * s.work_time))
		if BuildSite.stage_for(s.progress) != before:
			_show_stage(s)
		for sq in s.crews:
			(sq as Squad).status = "building %s %d%%" % [NAMES.get(s.variant if not s.variant.is_empty() else s.kind, s.kind), int(s.progress * 100.0)]
		if s.progress >= 1.0:
			_finish(s)


func _step_crew(sq: Squad) -> void:
	if sq.job != null and ((sq.job as BuildSite).done or not sites.has(sq.job)):
		_leave(sq)
	if sq.job == null:
		while not sq.jobs.is_empty() and ((sq.jobs[0] as BuildSite).done or not sites.has(sq.jobs[0])):
			sq.jobs.pop_front()
		if sq.jobs.is_empty():
			return
		sq.job = sq.jobs.pop_front()
		sq.set_meta("sent", false)
	var s: BuildSite = sq.job
	if sq.working or sq.moving():
		return
	var ap := s.approach(nav)
	var far := sq.at.distance_to(ap) > 6.0
	if far and not sq.get_meta("sent", false):
		sq.set_meta("sent", true)
		if not sq.order_move(ap):
			say("%s can't reach the %s" % [sq.title, NAMES.get(s.kind, s.kind)])
			sq.job = null
			return
		sq.status = "to the %s" % NAMES.get(s.variant if not s.variant.is_empty() else s.kind, s.kind)
		return
	if far and sq.at.distance_to(ap) > 30.0:
		sq.job = null                          # could not get close: give up on this one
		return
	_start_work(sq, s)


## The section's men take their spots round the site: the NCO checks the plan, the sappers do the job's work.
func _start_work(sq: Squad, s: BuildSite) -> void:
	if not s.crews.has(sq):
		s.crews.append(sq)
	var all := s.spots(nav)
	var first := s.crews.find(sq) * sq.count
	var spots: Array[Vector2] = []
	var faces: Array[Vector2] = []
	var clips: Array[String] = []
	var work := _work_clips(s)
	for i in sq.count:
		if all.is_empty():
			break
		var pf: Array = all[(first + i) % all.size()]
		spots.append(pf[0])
		faces.append(pf[1])
		clips.append("eng_nco_check" if i == 0 and sq.count > 1 else work[i % work.size()])
	sq.start_work(spots, faces, clips)


static func _work_clips(s: BuildSite) -> Array[String]:
	match s.kind:
		"wall", "sandbag_line":
			return ["eng_shovel", "eng_pick", "eng_shovel"]
		"wire_belt", "concertina":
			return ["eng_drive", "eng_hold", "eng_drive"]
		"hedgehogs", "teeth":
			return ["eng_hammer", "eng_hammer_low", "eng_hammer"]
	return ["eng_hammer", "eng_saw", "eng_hammer_low"]


func _finish(s: BuildSite) -> void:
	s.progress = 1.0
	s.done = true
	_show_stage(s)
	for sq in s.crews.duplicate():
		var q := sq as Squad
		_leave(q)
		if q.jobs.is_empty():
			var next := _nearest_unbuilt(q.at)
			if next != null:
				q.jobs.append(next)
	s.crews.clear()


## The nearest site nobody is building, within AUTO_HELP metres.
func _nearest_unbuilt(p: Vector2) -> BuildSite:
	var best: BuildSite = null
	var best_d := AUTO_HELP
	for s in sites:
		if s.done or not s.crews.is_empty():
			continue
		var d := s.center().distance_to(p)
		if d < best_d:
			best_d = d
			best = s
	return best


# ------------------------------------------------------------------ input and the ghost

func start_placing(k: String) -> void:
	placing = k
	_line_from = null
	if k in WALL_PIECES or (family_of(k) != "" and not is_line(k)):
		rot = 0


func stop_placing() -> void:
	placing = ""
	_line_from = null
	_show_ghosts(0)


func _unhandled_input(event: InputEvent) -> void:
	if nav == null or cam == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_B:
				menu.visible = not menu.visible
				get_viewport().set_input_as_handled()
			KEY_R:
				if busy():
					rot = (rot + 1) % 4
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if busy():
					stop_placing()
					get_viewport().set_input_as_handled()
			KEY_DELETE, KEY_X:
				var p: Variant = _mouse_ground()
				if p != null:
					var s: Variant = site_at(p)
					if s != null and not s.done:
						cancel(s)
						get_viewport().set_input_as_handled()
		return
	if not busy() or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		stop_placing()
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var p: Variant = _mouse_ground()
		if p == null:
			return
		if is_line(placing):
			if mb.pressed:
				_line_from = nav.cell_of(p)
			elif _line_from != null:
				var made := place_line(placing, _line_from, nav.cell_of(p), men_cells())
				_line_from = null
				_after_place(made, mb.shift_pressed)
		elif mb.pressed:
			var size := footprint(placing, rot)
			var s := place(placing, origin_at(p, size), rot, men_cells())
			if s == null:
				say("It doesn't fit there")
				return
			var made: Array[BuildSite] = [s]
			_after_place(made, mb.shift_pressed)


func _after_place(made: Array[BuildSite], keep: bool) -> void:
	if made.is_empty():
		say("It doesn't fit there")
		return
	_give_out(made)
	if not keep:
		stop_placing()


func _mouse_ground() -> Variant:
	if squads == null:
		return null
	var p: Variant = squads.ground_at(get_viewport().get_mouse_position())
	return null if p == null else Vector2((p as Vector3).x, (p as Vector3).z)


func _template(k: String) -> Building:
	if not _templates.has(k):
		_templates[k] = make_building(k)
	return _templates[k]


func _show_ghosts(n: int) -> void:
	if placing != _ghost_kind:
		for g in _ghosts:
			g.queue_free()
		_ghosts.clear()
		_ghost_kind = placing
	while _ghosts.size() < n:
		var g := _template(placing).ghost(true)
		add_child(g)
		_ghosts.append(g)
	for i in _ghosts.size():
		_ghosts[i].visible = i < n


func _ghost_at(i: int, origin: Vector2i, size: Vector2i, r: int, ok: bool) -> void:
	var g := _ghosts[i]
	var c := (Vector2(origin) + Vector2(size) * 0.5) * MapData.CELL
	var cl := origin.clamp(Vector2i.ZERO, Vector2i(data.w - 1, data.h - 1))
	var f := data.walk[cl.y * data.w + cl.x]
	var y := nav.height(c) if f == 0 or f == MapData.FLAT_NONE else MapData.level_y(f)
	g.position = Vector3(c.x, y, c.y)
	g.rotation.y = r * PI * 0.5
	(g.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.4, 0.38) if ok else Color(1.0, 0.25, 0.2, 0.38)


func _update_ghost() -> void:
	if not busy():
		return
	var p: Variant = _mouse_ground()
	if p == null:
		_show_ghosts(0)
		return
	var men := men_cells()
	if is_line(placing):
		var a: Vector2i = _line_from if _line_from != null else nav.cell_of(p)
		var cells := line_cells(a, nav.cell_of(p))
		var along_z := cells.size() > 1 and cells[1].x == cells[0].x
		var r := 1 if along_z else 0
		_show_ghosts(cells.size())
		for i in cells.size():
			_ghost_at(i, cells[i], Vector2i.ONE, r, cell_ok(cells[i], -1, men))
	else:
		var size := footprint(placing, rot)
		var o := origin_at(p, size)
		_show_ghosts(1)
		_ghost_at(0, o, size, rot, fits(o, size, men))


# ------------------------------------------------------------------ every frame

func _process(dt: float) -> void:
	if nav == null:
		return
	_update_ghost()
	step(dt)
	var far := cam != null and cam.height > FAR_AT
	var night := view != null and view.look == MapView.Look.NIGHT
	if far != _far:
		_far = far
		for s in sites:
			if s.done:
				s.node.far(far)
				if not far:
					_show_stage(s)
	if night != _night:
		_night = night
		for s in sites:
			if s.done:
				s.node.set_lights(night)
	if not _far:
		for s in sites:
			if s.done:
				s.node.step(dt)
	_note_t -= dt
	if _note_t <= 0.0:
		note = ""


func say(text: String) -> void:
	note = text
	_note_t = 2.5


func help() -> String:
	var t := "B build menu"
	if busy():
		t = "Placing %s: %s, R turn, right click or Esc stop (Shift keeps placing)" % [NAMES.get(placing, placing),
			"drag a line" if is_line(placing) else "left click to place"]
	return t + "   Delete/X cancel a building not finished" + (("   " + note) if not note.is_empty() else "")
