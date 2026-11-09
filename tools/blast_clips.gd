extends SceneTree
## Explosion round A: pictures and videos of the blasts (Building Chat 1, 2026-11-09). Needs a window (the GPU).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/blast_clips.gd -- stills <size> [night]
##       results/fx/stills_s<size>.png: the same blast at set moments, faceted on top, soft below
##   Godot --path iron_front --resolution 1280x720 -s res://tools/blast_clips.gd -- video [clip ...]
##       JPEG frames in results/fx/frames/<clip>/ at 30 fps; ffmpeg makes results/fx/<clip>.mp4
## The clock is set frame by frame, so a clip is the same every time it is made.

const OUT := "res://results/fx/"
const FPS := 30.0
const CLIPS := {
	# name: [size, night, side by side (both styles) or one style, length s, camera target, yaw, pitch, distance, spacing]
	# The user chose the faceted style from the stills (2026-11-09), so the clips show only that.
	"s1_day": [1, false, Blast.Style.FACET, 9.0, Vector3(0, 4, 0), 0.35, -0.12, 30.0, 0.0],
	"s1_night": [1, true, Blast.Style.FACET, 9.0, Vector3(0, 4, 0), 0.35, -0.12, 30.0, 0.0],
	"s4_day": [4, false, Blast.Style.FACET, 15.0, Vector3(0, 12, 0), 0.35, -0.08, 70.0, 0.0],
	"s4_night": [4, true, Blast.Style.FACET, 15.0, Vector3(0, 12, 0), 0.35, -0.08, 70.0, 0.0],
	"s8_day": [8, false, Blast.Style.FACET, 24.0, Vector3(0, 140, 0), 0.0, -0.05, 620.0, 0.0],
	"s8_night": [8, true, Blast.Style.FACET, 18.0, Vector3(0, 140, 0), 0.0, -0.05, 620.0, 0.0],
	# Round B: the sizes between.
	"s2_day": [2, false, Blast.Style.FACET, 10.0, Vector3(0, 5, 0), 0.35, -0.12, 36.0, 0.0],
	"s3_day": [3, false, Blast.Style.FACET, 12.0, Vector3(0, 8, 0), 0.35, -0.1, 46.0, 0.0],
	"s5_day": [5, false, Blast.Style.FACET, 16.0, Vector3(0, 18, 0), 0.3, -0.08, 95.0, 0.0],
	"s6_day": [6, false, Blast.Style.FACET, 20.0, Vector3(0, 45, 0), 0.2, -0.06, 200.0, 0.0],
	"s7_day": [7, false, Blast.Style.FACET, 22.0, Vector3(0, 75, 0), 0.1, -0.05, 360.0, 0.0],
}

var stage: BlastStage
var ui: CanvasLayer
var title: Label
var tags: Array[Label] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "video" if args.is_empty() else args[0]
	stage = BlastStage.new()
	stage.manual = true
	root.add_child(stage)
	ui = CanvasLayer.new()
	root.add_child(ui)
	title = _label(24)
	title.position = Vector2(20, 14)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	if mode == "stills":
		await _stills(int(args[1]) if args.size() > 1 else 4, args.has("night"))
	elif mode == "ladder":
		var sizes: Array = []
		for a in args.slice(1):
			if a != "night":
				sizes.append(int(a) if a.is_valid_int() else a)
		await _ladder(sizes, args.has("night"))
	else:
		var names: Array = args.slice(1)
		for n in (names if not names.is_empty() else CLIPS.keys()):
			await _video(n)
	print("BLAST CLIPS OK")
	quit()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	ui.add_child(l)
	return l


func _reset(night: bool) -> void:
	stage.clear_blasts()
	stage.ground.clear()
	stage.clear_men()
	for l in tags:
		l.free()
	tags.clear()
	stage.set_night(night)
	stage.step(0.0)


func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## Sets up a clip's blasts and camera. Returns its length.
func _setup(name: String) -> float:
	var c: Array = CLIPS[name]
	var size: int = c[0]
	_reset(c[1])
	var both: bool = int(c[2]) < 0
	var sp: float = c[8]
	stage.aim(c[4], c[5], c[6], c[7])
	if both:
		stage.fire(size, Vector3(-sp, 0, 0), 7, Blast.Style.FACET)
		stage.fire(size, Vector3(sp, 0, 0), 7, Blast.Style.SOFT)
		_tag("Faceted billows", Vector2(0.27, 0.86))
		_tag("Soft puffs", Vector2(0.67, 0.86))
		# Riflemen for scale, between the camera and the blasts.
		stage.place_squad(Vector3(-sp * 0.6, 0, float(c[7]) * 0.45), Vector3(0, 0, 0), 3)
	else:
		stage.fire(size, Vector3.ZERO, 7, c[2])
		if size <= 4:
			# Riflemen for scale, off to one side between the camera and the blast.
			var cam_dir := Vector3(sin(float(c[5])), 0, cos(float(c[5])))
			var side := Vector3(cam_dir.z, 0, -cam_dir.x)
			stage.place_squad(cam_dir * float(c[7]) * 0.35 - side * float(c[7]) * 0.18, Vector3.ZERO, 3)
	var sizes := {1: "Size 1: mortar", 2: "Size 2: light field gun", 3: "Size 3: field howitzer", 4: "Size 4: medium gun",
		5: "Size 5: heavy howitzer", 6: "Size 6: siege mortar", 7: "Size 7: heavy railway gun",
		8: "Size 8: super-heavy railway gun (beyond Gustav)"}
	title.text = "%s   %s" % [sizes.get(size, "Size %d" % size), "night" if c[1] else "day"]
	return c[3]


func _tag(text: String, at: Vector2) -> void:
	var l := _label(22)
	l.text = text
	var vs := root.get_visible_rect().size
	l.position = Vector2(at.x * vs.x, at.y * vs.y)
	tags.append(l)


func _video(name: String) -> void:
	var events: Array = []
	var length := _setup_events(name, events) if EVENT_CLIPS.has(name) else _setup(name)
	var dir := ProjectSettings.globalize_path(OUT + "frames/" + name + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	var frames := int(length * FPS)
	var t0 := Time.get_ticks_msec()
	for f in frames:
		stage.step(float(f) / FPS)
		while not events.is_empty() and float(events[0][0]) <= float(f) / FPS:
			_event(events.pop_front())
		var still: Array = []
		for p: Array in _pending:
			if float(p[0]) <= float(f) / FPS:
				_event([p[0], p[1], p[2]])
			else:
				still.append(p)
		_pending = still
		var img: Image = await _grab()
		img.save_jpg(dir + "f%04d.jpg" % f, 0.9)
	print("frames %s %d in %d ms" % [name, frames, Time.get_ticks_msec() - t0])


## Camera for each size: [look-at height, distance] (round B: every size).
const AIM := {1: [4.0, 22.0], 2: [5.0, 28.0], 3: [8.0, 38.0], 4: [12.0, 55.0], 5: [18.0, 85.0], 6: [32.0, 150.0],
	7: [70.0, 330.0], 8: [140.0, 620.0]}


static func times_for(size: Variant) -> Array:
	if size is String:
		return KIND_TIMES.get(size, [0.05, 0.3, 1.0, 3.0, 8.0])
	if size >= 7:
		return [0.3, 1.5, 4.0, 10.0, 25.0]
	if size >= 5:
		return [0.15, 0.8, 2.5, 6.0, 15.0]
	return [0.08, 0.35, 0.9, 2.5, 8.0]


## Several sizes, one row each, faceted, at set moments: results/fx/ladder_<sizes>[_night].png
func _ladder(sizes: Array, night: bool) -> void:
	var parts: Array[Image] = []
	var vs := root.get_visible_rect().size
	for size in sizes:
		_reset(night)
		title.text = ""
		var a: Array = AIM.get(size, KIND_AIM.get(size, [4.0, 30.0]))
		stage.aim(Vector3(0, a[0], 0), 0.0, -0.08, a[1])
		if size is String and String(size) == "hit_metal":
			stage.fire(size, Vector3(0, 0.6, 0), 7, Blast.Style.FACET, Vector3(0, 0.3, 1).normalized(), false)
		else:
			stage.fire(size, Vector3.ZERO, 7, Blast.Style.FACET)
		for t: float in times_for(size):
			stage.step(t)
			var img: Image = await _grab()
			img.resize(int(vs.x / 2.0), int(vs.y / 2.0))
			parts.append(img)
	var pw := parts[0].get_width()
	var ph := parts[0].get_height()
	var out := Image.create(pw * 5, ph * sizes.size(), false, Image.FORMAT_RGB8)
	for i in parts.size():
		out.blit_rect(parts[i], Rect2i(0, 0, pw, ph), Vector2i((i % 5) * pw, (i / 5) * ph))
	var path := OUT + "ladder_%s%s.png" % ["_".join(sizes.map(func(s): return str(s))), "_night" if night else ""]
	out.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


## The same blast at set moments: faceted on top, soft below, in one sheet.
func _stills(size: int, night: bool) -> void:
	var times := [0.08, 0.35, 0.9, 2.5, 8.0]
	if size >= 7:
		times = [0.3, 1.5, 4.0, 10.0, 25.0]
	var aimc: Dictionary = {1: [Vector3(0, 4, 0), 22.0], 4: [Vector3(0, 12, 0), 55.0], 8: [Vector3(0, 140, 0), 620.0]}
	var a: Array = aimc.get(size, [Vector3(0, 8.0 * size, 0), 30.0 * size * size])
	var parts: Array[Image] = []
	var vs := root.get_visible_rect().size
	for st in [Blast.Style.FACET, Blast.Style.SOFT]:
		_reset(night)
		title.text = ""
		stage.aim(a[0], 0.0, -0.08, a[1])
		stage.fire(size, Vector3.ZERO, 7, st)
		for t: float in times:
			stage.step(t)
			var img: Image = await _grab()
			img.resize(int(vs.x / 2.0), int(vs.y / 2.0))
			parts.append(img)
	var pw := parts[0].get_width()
	var ph := parts[0].get_height()
	var out := Image.create(pw * times.size(), ph * 2, false, Image.FORMAT_RGB8)
	for i in parts.size():
		out.blit_rect(parts[i], Rect2i(0, 0, pw, ph), Vector2i((i % times.size()) * pw, (i / times.size()) * ph))
	var path := OUT + "stills_s%d%s.png" % [size, "_night" if night else ""]
	out.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


## Round B kinds: camera [look-at height, distance] and the five moments shown.
const KIND_AIM := {"grenade": [1.5, 12.0], "mine_ap": [1.2, 12.0], "mine_at": [9.0, 50.0], "tunnel": [22.0, 170.0],
	"demo": [4.0, 40.0], "hit_dirt": [0.4, 3.5], "hit_metal": [0.6, 3.5], "flare_light": [55.0, 190.0],
	"flare_red": [35.0, 130.0], "flare_green": [35.0, 130.0], "flare_white": [35.0, 130.0]}
const KIND_TIMES := {"grenade": [0.03, 0.12, 0.4, 1.2, 4.0], "mine_ap": [0.03, 0.12, 0.4, 1.2, 4.0],
	"mine_at": [0.1, 0.5, 1.5, 4.0, 10.0], "tunnel": [0.4, 0.95, 1.5, 3.5, 12.0], "demo": [0.04, 0.3, 1.0, 3.0, 8.0],
	"hit_dirt": [0.02, 0.08, 0.2, 0.5, 1.0], "hit_metal": [0.01, 0.04, 0.1, 0.2, 0.4],
	"flare_light": [1.0, 3.5, 10.0, 20.0, 31.0], "flare_red": [0.6, 2.0, 4.0, 7.0, 9.5],
	"flare_green": [0.6, 2.0, 4.0, 7.0, 9.5], "flare_white": [0.6, 2.0, 4.0, 7.0, 9.5]}


# ---- round B: clips made of timed events.
# name: title, night, length, camera [target, yaw, pitch, distance], squad [at, facing] or [], van position or null,
# events [[time, what, at]] (what "hit_metal" lands on the van's side).
const EVENT_CLIPS := {
	"thrown_men": ["A shell in a squad: facing it, men go over backwards; backs to it, they pitch forwards",
		false, 11.0, [Vector3(0, 1.2, 0), 1.25, -0.16, 22.0], [Vector3(0, 0, 0), Vector3(0, 0, -20)], null,
		[[0.4, 1, Vector3(0.4, 0, 0.2)]]],
	"grenade": ["Grenade", false, 6.0, [Vector3(0, 1.2, 0), 0.4, -0.14, 13.0], [Vector3(6, 0, 4), Vector3(0, 0, 0)], null,
		[[0.3, "grenade", Vector3(0, 0, 0)]]],
	"mines": ["Anti-person mine, then anti-tank mine", false, 13.0, [Vector3(0, 7, 0), 0.3, -0.1, 48.0], [], null,
		[[0.3, "mine_ap", Vector3(-9, 0, 4)], [3.0, "mine_at", Vector3(8, 0, -4)]]],
	"tunnel": ["Tunnel mine under a trench", false, 16.0, [Vector3(0, 22, 0), 0.3, -0.06, 175.0], [], null,
		[[0.5, "tunnel", Vector3(0, 0, 0)]]],
	"demolition": ["Demolition charge", false, 10.0, [Vector3(0, 4, 0), 0.5, -0.1, 42.0], [], null,
		[[0.3, "demo", Vector3(0, 0, 0)]]],
	"bullets": ["Bullets: a machine-gun burst in the dirt, then on a goods van", false, 5.0,
		[Vector3(3, 1.4, 4), 1.1, -0.18, 15.0], [], Vector3(6, 0, 0),
		[[0.3, "burst", Vector3(-4, 0, 7)], [2.2, "hit_metal", Vector3.ZERO]]],
	"flares_night": ["Flares: a parachute light flare, then red and green signals", true, 22.0,
		[Vector3(0, 45, 0), 0.3, -0.04, 210.0], [Vector3(0, 0, 40), Vector3(0, 0, -40)], null,
		[[0.3, "flare_light", Vector3(0, 0, 0)], [6.0, "flare_red", Vector3(-40, 0, 20)], [9.0, "flare_green", Vector3(40, 0, 10)]]],
	"thrown_men_night": ["Men caught by a shell at night (size 2)", true, 11.0, [Vector3(0, 1.2, 0), 1.25, -0.16, 24.0],
		[Vector3(0, 0, 0), Vector3(0, 0, -20)], null, [[0.4, 2, Vector3(0.4, 0, 0.2)]]],
}


func _setup_events(name: String, events: Array) -> float:
	var c: Array = EVENT_CLIPS[name]
	_reset(c[1])
	if stage.van != null:
		stage.van.queue_free()
		stage.van = null
	var cam: Array = c[3]
	stage.aim(cam[0], cam[1], cam[2], cam[3])
	var sq: Array = c[4]
	if not sq.is_empty():
		stage.place_squad(sq[0], sq[1], 3)
	if c[5] != null:
		stage.place_van(c[5])
	events.append_array((c[6] as Array).duplicate(true))
	title.text = "%s   %s" % [c[0], "night" if c[1] else "day"]
	return c[2]


var _ev_rng := RandomNumberGenerator.new()


func _event(e: Array) -> void:
	var what: Variant = e[1]
	var at: Vector3 = e[2]
	_ev_rng.seed = int(float(e[0]) * 1000.0)
	if what is String and what == "burst":
		# A machine-gun burst walking across the dirt: 14 strikes over a second (each fires when its moment comes).
		for i in 14:
			_pending.append([stage.clock + float(i) * 0.07, "hit_dirt", at + Vector3(float(i) * 0.75 + _ev_rng.randf_range(-0.4, 0.4), 0, _ev_rng.randf_range(-0.5, 0.5))])
		return
	if what is String and what == "hit_metal":
		for i in 10:
			_pending.append([stage.clock + float(i) * 0.09, "van", Vector3.ZERO])
		return
	if what is String and what == "van":
		stage.fire("hit_metal", stage.van_side_point(_ev_rng), 300 + int(stage.clock * 100.0), -1, Vector3(1, 0.15, 0).normalized(), false)
		return
	stage.fire(what, at, 7 + int(float(e[0]) * 10.0))


var _pending: Array = []
