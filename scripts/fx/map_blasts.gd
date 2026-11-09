class_name MapBlasts
extends Node3D
## Explosion round B (Building Chat 1, 2026-11-09): blasts and lasting craters on the real Iron Front map.
## Test keys in the map scene (main.gd):
##   F fire the chosen blast at the mouse pointer      1-8 choose a shell size    9 / 0 cycle the other kinds
##   G a barrage of 16 shells (sizes 1-4) round the pointer    V a light flare there    C clear the craters
## Craters only on flat ground (not on cliffs, ramps or water); the blast itself goes off anywhere.

var view: MapView
var cam: Camera3D
var craters: MapCraters
var chosen: Variant = 3
var seed_n := 100
var _night := false
var _kind_i := 0
var auto_craters := true               # tools that set the clock themselves cut craters with try_crater
const OTHER := ["grenade", "mine_ap", "mine_at", "tunnel", "demo", "hit_dirt", "flare_red", "flare_green", "flare_white"]


func _ready() -> void:
	craters = MapCraters.new()
	add_child(craters)


func _process(_delta: float) -> void:
	if view == null:
		return
	var n := view.look != MapView.Look.DAY
	if n != _night:
		_night = n
		Blast.set_night(n)


func ground_y(x: float, z: float) -> float:
	return view.data.ground_y(Vector2(x, z))


## Sets off a blast (a size 1-8 or a kind name) on the ground at (x, z); its crater is cut once the earth hides it.
func fire(what: Variant, x: float, z: float, seed_value := -1) -> Blast:
	if view == null or view.data == null:
		return null
	if seed_value < 0:
		seed_n += 1
		seed_value = seed_n
	var at := Vector3(x, ground_y(x, z), z)
	var live := 0
	for c in get_children():
		if c is Blast:
			for k: int in (c as Blast).spec["counts"]:
				live += k
	var b := Blast.new()
	b.density = clampf(1.0 - float(live - 5000) / 14000.0, 0.4, 1.0)
	add_child(b)
	b.setup(what, at, seed_value)
	var r: float = b.spec["crater_r"]
	if r > 0.0 and auto_craters:
		_crater_later(at, r, float(b.spec["crater_d"]), float(b.spec.get("crater_t", 0.05)), seed_value)
	return b


func _crater_later(at: Vector3, r: float, d: float, wait: float, seed_value: int) -> void:
	await get_tree().create_timer(wait).timeout
	try_crater(at, r, d, seed_value)


## Cuts a crater if the ground there is flat (not cliffs, ramps or water).
func try_crater(at: Vector3, r: float, d: float, seed_value: int) -> void:
	# Only on flat ground: every point round the rim at the same height, and not water.
	for i in 10:
		var a := TAU * float(i) / 10.0
		var y := ground_y(at.x + cos(a) * r * 2.2, at.z + sin(a) * r * 2.2)
		if absf(y - at.y) > 0.05 or at.y <= MapData.WATER_Y + 0.01:
			return
	craters.add(at, r, d, seed_value)


## Where the mouse pointer meets the ground (or null).
func pointer() -> Variant:
	if cam == null:
		return null
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var t := 0.0
	var prev := 0.0
	while t < 6000.0:
		var p := o + dir * t
		if p.y <= ground_y(p.x, p.z):
			var a := prev
			var b := t
			for i in 16:
				var m := (a + b) * 0.5
				var q := o + dir * m
				if q.y <= ground_y(q.x, q.z):
					b = m
				else:
					a = m
			return o + dir * b
		prev = t
		t += maxf(1.0, t * 0.01)
	return null


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_8:
		chosen = k.keycode - KEY_1 + 1
	elif k.keycode == KEY_9 or k.keycode == KEY_0:
		_kind_i = (_kind_i + (1 if k.keycode == KEY_0 else OTHER.size() - 1)) % OTHER.size()
		chosen = OTHER[_kind_i]
	elif k.keycode == KEY_C:
		craters.clear()
	elif k.keycode in [KEY_F, KEY_G, KEY_V]:
		var p: Variant = pointer()
		if p == null:
			return
		var at: Vector3 = p
		if k.keycode == KEY_F:
			fire(chosen, at.x, at.z)
		elif k.keycode == KEY_V:
			fire("flare_light", at.x, at.z)
		else:
			for i in 16:
				_later([1, 2, 3, 4][i % 4], at.x + randf_range(-45, 45), at.z + randf_range(-45, 45), float(i) * 0.22)


func _later(what: Variant, x: float, z: float, wait: float) -> void:
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	fire(what, x, z)


func help() -> String:
	return "F fire %s at the pointer (1-8 shell size, 9/0 other kinds), G barrage, V light flare, C clear craters (%d)" % [
		("size %d" % chosen) if chosen is int else String(chosen), craters.count()]
