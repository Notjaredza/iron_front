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
	var sizes := {1: "Size 1: mortar", 4: "Size 4: medium gun", 8: "Size 8: super-heavy railway gun (beyond Gustav)"}
	title.text = "%s   %s" % [sizes.get(size, "Size %d" % size), "night" if c[1] else "day"]
	return c[3]


func _tag(text: String, at: Vector2) -> void:
	var l := _label(22)
	l.text = text
	var vs := root.get_visible_rect().size
	l.position = Vector2(at.x * vs.x, at.y * vs.y)
	tags.append(l)


func _video(name: String) -> void:
	var length := _setup(name)
	var dir := ProjectSettings.globalize_path(OUT + "frames/" + name + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	var frames := int(length * FPS)
	var t0 := Time.get_ticks_msec()
	for f in frames:
		stage.step(float(f) / FPS)
		var img: Image = await _grab()
		img.save_jpg(dir + "f%04d.jpg" % f, 0.9)
	print("frames %s %d in %d ms" % [name, frames, Time.get_ticks_msec() - t0])


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
