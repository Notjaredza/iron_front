class_name BuildMenu
extends PanelContainer
## Iron Front: the build menu (building round), a bar of building pictures along the bottom of the screen with a
## tab for each set, as in Company of Heroes or Rise of Nations. Click a picture to start placing it.
## The pictures are drawn once when the game starts, each building lit and seen from above at an angle
## (not when running headless, where the buttons keep their names only).

signal picked(kind: String)

const TABS := [
	["Core", ["hq", "barracks", "depot"]],
	["Defences", ["sandbag_line", "wire_belt", "concertina", "hedgehogs", "teeth", "mg_nest", "gun_pit"]],
	["Walls", ["wall", "tower", "bastion", "gate"]],
	["Rail", ["halt", "station", "engine_shed", "water_tower", "coal_stage", "signal_box"]],
	["Comms", ["runner_post", "telegraph", "tele_wire", "lamp_tower", "pigeon_loft"]],
	["Research", ["lab_comms", "lab_weapons", "lab_rail", "lab_defences", "wreck_yard"]],
]
const PIC := 96

var tab := 0
var pics := {}                                 # kind -> Texture2D
var _tabs: HBoxContainer
var _items: HBoxContainer
var _tab_buttons: Array[Button] = []


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.08, 0.82)
	sb.border_color = Color(0.55, 0.5, 0.35, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	add_child(col)
	_tabs = HBoxContainer.new()
	col.add_child(_tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i][0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_tab.bind(i))
		_tabs.add_child(b)
		_tab_buttons.append(b)
	_items = HBoxContainer.new()
	_items.add_theme_constant_override("separation", 4)
	col.add_child(_items)
	_show_tab(0)
	if DisplayServer.get_name() != "headless":
		_draw_pictures()


func _show_tab(i: int) -> void:
	tab = i
	for k in _tab_buttons.size():
		_tab_buttons[k].button_pressed = k == i
	for c in _items.get_children():
		c.queue_free()
	for kind: String in TABS[i][1]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(PIC + 8, PIC + 26)
		b.text = BuildControl.NAMES.get(kind, kind)
		b.icon = pics.get(kind, null)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = _tip(kind)
		b.pressed.connect(func() -> void: picked.emit(kind))
		_items.add_child(b)


static func _tip(kind: String) -> String:
	if kind == "tele_wire":
		return "Telegraph wire: click the HQ or a telegraph post, then another (up to 600 m); Shift keeps going"
	if BuildControl.is_line(kind):
		return "%s: press and drag to lay a line" % BuildControl.NAMES.get(kind, kind)
	var t := BuildControl.footprint(kind)
	return "%s: %d x %d tiles, R turns it" % [BuildControl.NAMES.get(kind, kind), t.x, t.y]


## Draws each building's picture in a small hidden view of its own, one after another.
func _draw_pictures() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(PIC * 2, PIC * 2)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(c)
	c.current = true
	for t: Array in TABS:
		for kind: String in t[1]:
			if kind == "tele_wire":
				continue                           # a tool, not a building: its button keeps its name
			var b := BuildControl.make_building(kind)
			vp.add_child(b)
			var hs := b.half_size()
			var top := b.g.top_y()
			var reach := maxf(maxf(hs.x, hs.y) * 1.5, top * 1.1)
			c.size = reach * 1.9
			var look := Vector3(0, top * 0.35, 0)
			c.position = look + Vector3(1.0, 0.85, 1.25).normalized() * 200.0
			c.look_at(look)
			c.far = 400.0
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			pics[kind] = ImageTexture.create_from_image(vp.get_texture().get_image())
			b.queue_free()
	vp.queue_free()
	_show_tab(tab)
