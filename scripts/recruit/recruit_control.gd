class_name RecruitControl
extends Node3D
## Iron Front: recruiting and supply (recruitment round).
## - Supply: one number, as the design says (the real economy comes later). A run starts with START supply. It
##   comes in slowly by itself (BASE a second), and faster from finished buildings: the HQ, each depot and each
##   station or halt (INCOME). Placing a building costs its price (BUILD_COST, per piece for lines) and a
##   building cancelled before it is finished gives it all back; one taken down gives back half. Recruiting
##   costs the unit's price when it is queued, and all of it back if it is taken off the queue.
## - Click a finished barracks or HQ to select it: a panel at the bottom right shows what it trains (UNITS), the
##   queue (up to 5) and the training bar. Click a unit to queue it; click a queued one to take it off. The
##   barracks trains rifles, assault sections, LMG teams, sniper pairs and mortar crews; the HQ engineers and
##   linemen. One at a time, each takes its training time.
## - With a building selected, a right click on the ground sets its rally point (a flag): new squads walk there.
##   Esc or a click elsewhere lets the building go.
## - The supply line shows at the top of the screen.

const START := 900.0
const BASE := 0.5                               # supply a second, always
const INCOME := {"hq": 1.0, "depot": 1.5, "station": 1.0, "halt": 0.5}
const QUEUE_MAX := 5
const BUILD_COST := {"hq": 300, "barracks": 200, "depot": 150, "halt": 80, "station": 200, "engine_shed": 150,
	"water_tower": 60, "coal_stage": 60, "signal_box": 60, "runner_post": 40, "telegraph": 60, "lamp_tower": 60,
	"pigeon_loft": 60, "lab_comms": 200, "lab_weapons": 200, "lab_rail": 200, "lab_defences": 200, "wreck_yard": 150,
	"sandbag_line": 5, "wire_belt": 4, "concertina": 4, "hedgehogs": 6, "teeth": 8, "mg_nest": 50, "gun_pit": 80,
	"wall": 12, "tower": 40, "bastion": 40, "gate": 25, "tele_wire": 0}
## kind -> [name, cost, seconds, men, title]
const UNITS := {"rifles": ["Rifle squad", 100, 45.0, 12, "Rifles"], "assault": ["Assault section", 140, 50.0, 8, "Assault"],
	"lmg": ["LMG team", 120, 40.0, 4, "LMG team"], "snipers": ["Sniper pair", 90, 35.0, 2, "Snipers"],
	"mortar": ["Mortar crew", 150, 55.0, 3, "Mortar"], "engineers": ["Engineer section", 60, 30.0, 4, "Engineers"],
	"linemen": ["Linemen", 40, 25.0, 2, "Linemen"]}
const TRAINS := {"barracks": ["rifles", "assault", "lmg", "snipers", "mortar"], "hq": ["engineers", "linemen"]}

var nav: NavGrid
var cam: RtsCamera
var squads: SquadControl
var build: BuildControl
var supply := START
var picked: BuildSite = null                   # the selected barracks or HQ
var queues := {}                               # BuildSite -> Array of {"kind", "left"}
var rally := {}                                # BuildSite -> Vector2
var made := {}                                 # kind -> how many have been recruited (for the titles)
var note := ""
var _note_t := 0.0
var _seed := 3000
var _ui: CanvasLayer
var _top: Label
var _panel: PanelContainer
var _title: Label
var _buttons: VBoxContainer
var _queue_box: VBoxContainer
var _flag: Node3D
var _ring: MeshInstance3D
var _ring_imm: ImmediateMesh


func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_top = Label.new()
	_top.anchor_left = 0.5
	_top.anchor_right = 0.5
	_top.offset_left = -200
	_top.offset_right = 200
	_top.offset_top = 4
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_theme_font_size_override("font_size", 18)
	_top.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_top.add_theme_color_override("font_outline_color", Color.BLACK)
	_top.add_theme_constant_override("outline_size", 5)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_top)
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -8
	_panel.offset_bottom = -8
	_panel.custom_minimum_size = Vector2(250, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.08, 0.86)
	sb.border_color = Color(0.55, 0.5, 0.35, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	_panel.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	col.add_child(_title)
	_buttons = VBoxContainer.new()
	col.add_child(_buttons)
	var ql := Label.new()
	ql.text = "Training (click to cancel):"
	ql.add_theme_font_size_override("font_size", 12)
	ql.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	col.add_child(ql)
	_queue_box = VBoxContainer.new()
	col.add_child(_queue_box)
	var hint := Label.new()
	hint.text = "Right click the ground: rally point"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.62))
	col.add_child(hint)
	_panel.visible = false
	_ui.add_child(_panel)
	_flag = Node3D.new()
	var pole := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, 4.0, 0.12)
	pole.mesh = pm
	pole.position.y = 2.0
	pole.material_override = Squad._flat(Color(0.9, 0.85, 0.7))
	_flag.add_child(pole)
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.4, 0.8, 0.04)
	cloth.mesh = cm
	cloth.position = Vector3(0.75, 3.5, 0)
	cloth.material_override = Squad._flat(Color(1.0, 0.8, 0.2))
	_flag.add_child(cloth)
	_flag.visible = false
	add_child(_flag)
	_ring_imm = ImmediateMesh.new()
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_imm
	_ring.material_override = Squad._flat(Color(1.0, 0.86, 0.25))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


## A new map: supply back to the start, no queues.
func reset(nav_grid: NavGrid) -> void:
	nav = nav_grid
	supply = START
	queues.clear()
	rally.clear()
	made.clear()
	select_site(null)


# ------------------------------------------------------------------ supply

static func build_cost(kind: String) -> int:
	return int(BUILD_COST.get(kind, 100))


static func unit_cost(kind: String) -> int:
	return int(UNITS[kind][1])


func can_pay(n: float) -> bool:
	return supply >= n - 0.001


## Takes n supply if there is enough (true), else says so (false).
func pay(n: float) -> bool:
	if not can_pay(n):
		say("Not enough supply (need %d, have %d)" % [int(ceil(n)), int(supply)])
		return false
	supply -= n
	return true


func refund(n: float) -> void:
	supply += n


## Supply a second now.
func income() -> float:
	var r := BASE
	if build != null:
		for s in build.sites:
			if s.done:
				r += float(INCOME.get(s.kind, 0.0))
	return r


# ------------------------------------------------------------------ recruiting

## Queues a unit at a finished barracks or HQ (paying for it now). Returns false (and says why) if it cannot.
func recruit(site: BuildSite, kind: String) -> bool:
	if site == null or not site.done or not TRAINS.has(site.kind) or not (kind in TRAINS[site.kind]):
		return false
	var q: Array = queues.get(site, [])
	if q.size() >= QUEUE_MAX:
		say("The queue is full")
		return false
	if not pay(unit_cost(kind)):
		return false
	q.append({"kind": kind, "left": float(UNITS[kind][2])})
	queues[site] = q
	_refresh()
	return true


## Takes the i-th unit off a building's queue and gives its supply back.
func unqueue(site: BuildSite, i: int) -> void:
	var q: Array = queues.get(site, [])
	if i < 0 or i >= q.size():
		return
	refund(unit_cost(q[i]["kind"]))
	q.remove_at(i)
	_refresh()


func set_rally(site: BuildSite, p: Vector2) -> void:
	rally[site] = p
	say("Rally point set")


## A trained unit comes out: a new squad by the building's door, walking to the rally point if there is one.
func _turn_out(site: BuildSite, kind: String) -> Squad:
	made[kind] = int(made.get(kind, _count_kind(kind))) + 1
	var s := Squad.new()
	squads.add_child(s)
	_seed += 1
	var door := site.approach(nav)
	s.setup(nav, door, site.front(), _seed, "%s %d" % [UNITS[kind][4], made[kind]], kind, int(UNITS[kind][3]))
	squads.squads.append(s)
	if rally.has(site):
		s.order_move(nav.nearest_open(rally[site]))
	say("%s ready" % s.title)
	return s


func _count_kind(kind: String) -> int:
	var n := 0
	for s in squads.squads:
		if s.kind == kind:
			n += 1
	return n


# ------------------------------------------------------------------ every frame

func _process(dt: float) -> void:
	if nav == null:
		return
	step(dt)


## One step: supply comes in, training goes on (also called by the headless check).
func step(dt: float) -> void:
	supply += income() * dt
	for site: BuildSite in queues.keys():
		var q: Array = queues[site]
		if build != null and (not build.sites.has(site) or not site.done):
			for e in q:
				refund(unit_cost(e["kind"]))   # the building is gone or being taken down: money back
			queues.erase(site)
			continue
		if q.is_empty():
			continue
		q[0]["left"] = float(q[0]["left"]) - dt
		if float(q[0]["left"]) <= 0.0:
			var e: Dictionary = q.pop_front()
			_turn_out(site, e["kind"])
			_refresh()
	if picked != null and (build == null or not build.sites.has(picked) or not picked.done):
		select_site(null)
	_show()
	_note_t -= dt
	if _note_t <= 0.0:
		note = ""


# ------------------------------------------------------------------ picking a building

func select_site(site: BuildSite) -> void:
	picked = site
	if site != null and squads != null:
		for s in squads.squads:
			s.selected = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if nav == null or squads == null or cam == null or build == null:
		return
	if build.busy() or (squads.comms != null and squads.comms.wiring):
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE and picked != null:
			select_site(null)
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	var g: Variant = squads._ground2(mb.position)
	if mb.button_index == MOUSE_BUTTON_RIGHT and picked != null:
		if g != null:
			set_rally(picked, g)
		get_viewport().set_input_as_handled()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT or g == null:
		return
	var site: Variant = build.site_at(g)
	if site != null and (site as BuildSite).done and TRAINS.has((site as BuildSite).kind) and not _squad_under(mb.position):
		select_site(site)
		get_viewport().set_input_as_handled()
	elif picked != null:
		select_site(null)


func _squad_under(at: Vector2) -> bool:
	for s in squads.squads:
		for p in s.screen_points(cam):
			if p.distance_to(at) < SquadControl.PICK_PX:
				return true
	return false


# ------------------------------------------------------------------ showing it

func _refresh() -> void:
	_panel.visible = picked != null
	for c in _buttons.get_children():
		c.queue_free()
	for c in _queue_box.get_children():
		c.queue_free()
	if picked == null:
		return
	_title.text = BuildControl.NAMES.get(picked.kind, picked.kind)
	for kind: String in TRAINS[picked.kind]:
		var b := Button.new()
		var u: Array = UNITS[kind]
		b.text = "%s   %d supply, %d s" % [u[0], u[1], int(u[2])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = "%d men" % int(u[3])
		var site := picked
		b.pressed.connect(func() -> void: recruit(site, kind))
		b.set_meta("kind", kind)
		_buttons.add_child(b)
	var q: Array = queues.get(picked, [])
	for i in q.size():
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.add_theme_font_size_override("font_size", 12)
		var site2 := picked
		var idx := i
		row.pressed.connect(func() -> void: unqueue(site2, idx))
		row.set_meta("i", i)
		_queue_box.add_child(row)


func _show() -> void:
	_top.text = "Supply %d   (+%.1f a second)%s" % [int(supply), income(), ("   " + note) if not note.is_empty() else ""]
	_ring_imm.clear_surfaces()
	_flag.visible = false
	if picked == null:
		return
	for b in _buttons.get_children():
		if b is Button and b.has_meta("kind"):
			(b as Button).disabled = not can_pay(unit_cost(b.get_meta("kind")))
	var q: Array = queues.get(picked, [])
	for row in _queue_box.get_children():
		if row is Button and row.has_meta("i") and int(row.get_meta("i")) < q.size():
			var e: Dictionary = q[int(row.get_meta("i"))]
			var total := float(UNITS[e["kind"]][2])
			var bar := int(10.0 * (1.0 - float(e["left"]) / total)) if int(row.get_meta("i")) == 0 else 0
			(row as Button).text = "%s  [%s%s]  %s" % [UNITS[e["kind"]][0], "#".repeat(bar), ".".repeat(10 - bar),
				("%d s" % int(ceil(float(e["left"])))) if int(row.get_meta("i")) == 0 else "waiting"]
	if rally.has(picked):
		var r: Vector2 = rally[picked]
		_flag.position = Vector3(r.x, nav.height(r), r.y)
		_flag.visible = true
	var c := picked.center()
	var rad := maxf(picked.size.x, picked.size.y) * MapData.CELL * 0.75
	_ring_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in 48:
		var a := c + Vector2.from_angle(TAU * k / 48.0) * rad
		var b := c + Vector2.from_angle(TAU * (k + 1) / 48.0) * rad
		_ring_imm.surface_add_vertex(Vector3(a.x, picked.y + 0.3, a.y))
		_ring_imm.surface_add_vertex(Vector3(b.x, picked.y + 0.3, b.y))
	_ring_imm.surface_end()


func say(text: String) -> void:
	note = text
	_note_t = 3.0


func help() -> String:
	return "Click a finished barracks or HQ to recruit; with it selected, right click sets its rally point"
