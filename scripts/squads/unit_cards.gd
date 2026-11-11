class_name UnitCards
extends VBoxContainer
## Iron Front: unit cards (bottom left), one per selected squad: its name, how many men, what it is doing, and a
## Run/Walk switch that speeds up or slows down a squad on the move. Click a card's name to select only that squad.
## The switch is greyed out while the squad stands still (a halted squad has nothing to speed up).

const W := 230.0

var control: SquadControl
var _shown: Array[Squad] = []                      # the squads the cards were made for
var _cards: Array[Dictionary] = []             # {"squad", "name", "info", "run"}


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 8
	offset_bottom = -8
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_dt: float) -> void:
	if control == null:
		return
	var sel := control.selected()
	if sel != _shown:
		_rebuild(sel)
	for c in _cards:
		_fill(c)


func _rebuild(sel: Array[Squad]) -> void:
	_shown = sel.duplicate()
	for c in get_children():
		c.queue_free()
	_cards.clear()
	for s in sel:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(W, 0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.1, 0.08, 0.82)
		sb.border_color = Color(0.55, 0.5, 0.35, 0.9)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(5)
		panel.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var name_b := Button.new()
		name_b.text = s.title
		name_b.flat = true
		name_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_b.focus_mode = Control.FOCUS_NONE
		name_b.tooltip_text = "Select only this squad"
		name_b.pressed.connect(func() -> void: select_only(s))
		col.add_child(name_b)
		var info := Label.new()
		info.add_theme_font_size_override("font_size", 12)
		info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.78))
		col.add_child(info)
		var run := Button.new()
		run.toggle_mode = true
		run.focus_mode = Control.FOCUS_NONE
		run.custom_minimum_size = Vector2(62, 0)
		run.tooltip_text = "Run or walk while on the move"
		run.toggled.connect(func(on: bool) -> void: s.set_running(on))
		row.add_child(run)
		add_child(panel)
		var c := {"squad": s, "name": name_b, "info": info, "run": run}
		_cards.append(c)
		_fill(c)


func _fill(c: Dictionary) -> void:
	var s: Squad = c["squad"]
	if not is_instance_valid(s):
		return
	var doing := "standing"
	if not s.status.is_empty():
		doing = s.status
	elif s.moving():
		doing = "running" if s.running else "walking"
	(c["info"] as Label).text = "%d men   %s" % [s.men.size(), doing]
	var run: Button = c["run"]
	run.disabled = not s.moving()
	run.set_pressed_no_signal(s.moving() and s.running)
	run.text = "Run" if run.button_pressed else "Walk"


func select_only(s: Squad) -> void:
	for q in control.squads:
		q.selected = q == s


## How many cards are showing (for the check).
func count() -> int:
	return _cards.size()


## Presses a card's Run/Walk switch (for the check), as a click would.
func press_run(i: int, on: bool) -> void:
	var b: Button = _cards[i]["run"]
	if not b.disabled:
		b.button_pressed = on
