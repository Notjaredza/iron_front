extends Node3D
## Iron Front: the map test scene (step 1). It builds a map from a seed and lets you fly over it.
## Keys: WASD move, wheel zoom, Q/E turn (or hold the middle mouse button), T day/night/fog, N a new map.
## Squads (step 2, round 1): three rifle squads start near the middle; select them and right-click to move.
## Command-line options after `--`: --seed=N, and --size=WxH in cells (for small test maps).

var view: MapView
var cam: RtsCamera
var hud: Label
var seed := 1
var map_w := 1000
var map_h := 1500
var ready_map := false                 # tools wait for this
var blasts: MapBlasts                  # explosions round B: blasts and craters on the map (F, G, V, 1-9)
var nav: NavGrid                       # squads round 1: where troops can walk
var squads: SquadControl


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			map_w = int(p[0]) / 4 * 4
			map_h = int(p[1]) / 4 * 4
	view = MapView.new()
	add_child(view)
	cam = RtsCamera.new()
	add_child(cam)
	cam.current = true
	view.cam = cam
	blasts = MapBlasts.new()
	add_child(blasts)
	blasts.view = view
	blasts.cam = cam
	squads = SquadControl.new()
	add_child(squads)
	squads.cam = cam
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)
	hud.text = "Building the map (seed %d)..." % seed
	await get_tree().process_frame
	await get_tree().process_frame
	new_map(seed)
	ready_map = true


func new_map(s: int) -> void:
	seed = s
	if blasts != null:
		blasts.craters.clear()
	view.build(seed, map_w, map_h)
	cam.data = view.data
	var sz := view.data.size_m()
	cam.target = Vector3(sz.x * 0.5, 0, sz.y * 0.5)
	nav = NavGrid.new().build(view.data)
	squads.spawn(nav, Vector2(sz.x * 0.5, sz.y * 0.5))
	var first := squads.squads[0].at
	cam.target = Vector3(first.x, 0, first.y)
	cam.height = 120.0
	cam.height_goal = 120.0
	cam.place()
	for n in view.data.notes:
		print("MAP ", n)
	print("MAP seed %d: %d chunks, %d triangles (+%d in rocks and bushes), meshes built in %d ms" % [seed, view.chunks.size(), view.tris, view.detail_tris, view.build_ms])
	print("NAV built in %d ms, %d ramp cells" % [nav.build_ms, nav.ramp_at.size()])


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_T:
		view.set_look((view.look + 1) % 3)
	elif k.keycode == KEY_N:
		hud.text = "Building the map (seed %d)..." % (seed + 1)
		await get_tree().process_frame
		await get_tree().process_frame
		new_map(seed + 1)


func _process(_delta: float) -> void:
	if not ready_map:
		return
	view.follow(cam.height)
	hud.text = "Iron Front map test   seed %d   %s   %d FPS   height %d m\nWASD move, wheel zoom, Q/E turn, T day/night/fog, N new map\n%s\n%s" % [
		seed, view.look_name(), Engine.get_frames_per_second(), int(cam.height), blasts.help(), squads.help()]
