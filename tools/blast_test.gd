extends SceneTree
## Explosion round A: the live blast test (Building Chat 1, 2026-11-09).
##   Godot --path iron_front -s res://tools/blast_test.gd
## Keys: 1-8 fire that size where the camera looks (sizes 1, 4 and 8 are the tuned ones in round A),
## B faceted or soft smoke, V both styles side by side, X a salvo, N day/night, C clear craters, H hide the help,
## K camera shake on/off. Mouse: right button drag to turn, wheel to zoom; WASD move, Q/E turn.

var stage: BlastStage
var hud: Label
var seed_n := 1
var help := true


func _initialize() -> void:
	stage = BlastStage.new()
	root.add_child(stage)
	stage.place_squad.call_deferred(Vector3(-28, 0, 22), Vector3.ZERO, 3)   # after the stage's _ready
	var input := InputNode.new()
	input.test = self
	root.add_child(input)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	hud = Label.new()
	hud.position = Vector2(14, 10)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(hud)
	if OS.get_cmdline_user_args().has("bench"):
		_bench.call_deferred()


## -- bench: fixed scenes, faceted style, each timed: average FPS, the worst whole second and the slowest frame.
func _bench() -> void:
	help = false
	await create_timer(1.0).timeout
	var scenes: Array = [
		["size 1, 30 m", 1, 30.0, 6.0, "one"],
		["size 4, 70 m", 4, 70.0, 8.0, "one"],
		["salvo of 7 (sizes 1-4), 90 m", 0, 90.0, 8.0, "salvo"],
		["barrage: 24 shells (sizes 1-4) over 6 s, 110 m", 0, 110.0, 10.0, "barrage"],
		["size 8, 620 m", 8, 620.0, 16.0, "one"],
		["size 8, 250 m (inside the dust)", 8, 250.0, 12.0, "one"],
		["size 8 and a size-4 barrage, 620 m", 8, 620.0, 12.0, "both"],
	]
	for night in [false, true]:
		stage.set_night(night)
		for sc: Array in scenes:
			stage.clear_blasts()
			stage.ground.clear()
			stage.target = Vector3(0, 4.0 if int(sc[1]) < 8 else 120.0, 0)
			stage.dist = sc[2]
			stage.yaw = 0.5
			stage.pitch = -0.12 if int(sc[1]) < 8 else -0.05
			await process_frame
			match String(sc[4]):
				"one":
					stage.fire(sc[1], Vector3.ZERO, 5)
				"salvo":
					key(KEY_X)
				"barrage", "both":
					if String(sc[4]) == "both":
						stage.fire(8, Vector3(0, 0, -150), 5)
					for i in 24:
						_later(stage.fire.bind([1, 2, 3, 4][i % 4], Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), 50 + i), float(i) * 0.25)
			var frames: Array[float] = []
			var t0 := Time.get_ticks_usec()
			var last := t0
			while float(Time.get_ticks_usec() - t0) / 1e6 < float(sc[3]):
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append(float(now - last) / 1e6)
				last = now
			var total := 0.0
			for f in frames:
				total += f
			var worst_sec := 1e9
			var acc := 0.0
			var cnt := 0
			for f in frames:
				acc += f
				cnt += 1
				if acc >= 1.0:
					worst_sec = minf(worst_sec, float(cnt) / acc)
					acc = 0.0
					cnt = 0
			print("BENCH %s %s: avg %.1f fps, worst second %.1f, slowest frame %.1f ms" % [
				"night" if night else "day", sc[0], float(frames.size()) / total, worst_sec, frames.max() * 1000.0])
	print("BENCH DONE")
	quit()


func _process(_delta: float) -> bool:
	if hud != null:
		var live := 0
		for e: Array in stage.blasts:
			for c: int in (e[0] as Blast).spec["counts"]:
				live += c
		hud.text = "Iron Front blast test   %d FPS   smoke: %s   %s   blasts %d (%d particles)" % [
			Engine.get_frames_per_second(), ["faceted", "soft"][stage.style], "night" if stage.is_night else "day",
			stage.blasts.size(), live]
		if help:
			hud.text += "\n1-8 fire a size where you look (1, 4, 8 tuned)   B faceted/soft   V both side by side   X salvo\nN day/night   C clear craters   K shake   H hide this   right drag turn, wheel zoom, WASD move"
	return false


func key(k: int) -> void:
	seed_n += 1
	if k >= KEY_1 and k <= KEY_8:
		var size := k - KEY_1 + 1
		var r := 4.0 + float(size) * 3.0
		var at := stage.target + Vector3(randf_range(-r, r), 0, randf_range(-r, r)) * 0.3
		stage.fire(size, at, seed_n)
		if size >= 6 and stage.dist < 300.0:
			stage.dist = 300.0 + float(size - 6) * 250.0
	elif k == KEY_B:
		stage.style = Blast.Style.SOFT if stage.style == Blast.Style.FACET else Blast.Style.FACET
	elif k == KEY_V:
		var size := 4
		var side := Vector3(cos(stage.yaw), 0, -sin(stage.yaw)) * 22.0
		stage.fire(size, stage.target - side, seed_n, Blast.Style.FACET)
		stage.fire(size, stage.target + side, seed_n, Blast.Style.SOFT)
	elif k == KEY_X:
		var side := Vector3(cos(stage.yaw), 0, -sin(stage.yaw))
		for i in 7:
			var s: int = [1, 2, 1, 3, 4, 2, 1][i]
			var at := stage.target + side * (float(i) - 3.0) * 9.0 + Vector3(randf_range(-3, 3), 0, randf_range(-6, 6))
			_later(stage.fire.bind(s, at, seed_n * 13 + i), float(i) * 0.09)
	elif k == KEY_N:
		stage.set_night(not stage.is_night)
	elif k == KEY_C:
		stage.ground.clear()
	elif k == KEY_K:
		stage.shake_on = not stage.shake_on
	elif k == KEY_H:
		help = not help


func _later(c: Callable, sec: float) -> void:
	if sec <= 0.0:
		c.call()
		return
	await create_timer(sec).timeout
	c.call()


class InputNode:
	extends Node
	var test
	var drag := false

	func _unhandled_input(event: InputEvent) -> void:
		var st: BlastStage = test.stage
		if event is InputEventKey and event.pressed and not event.echo:
			test.key(event.keycode)
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				drag = event.pressed
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				st.dist = maxf(st.dist * 0.88, 6.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				st.dist = minf(st.dist * 1.14, 2500.0)
		elif event is InputEventMouseMotion and drag:
			st.yaw -= event.relative.x * 0.006
			st.pitch = clampf(st.pitch - event.relative.y * 0.004, -1.45, 0.25)

	func _process(delta: float) -> void:
		var st: BlastStage = test.stage
		var mv := Vector3.ZERO
		if Input.is_key_pressed(KEY_W): mv.z -= 1
		if Input.is_key_pressed(KEY_S): mv.z += 1
		if Input.is_key_pressed(KEY_A): mv.x -= 1
		if Input.is_key_pressed(KEY_D): mv.x += 1
		if Input.is_key_pressed(KEY_Q): st.yaw += delta * 1.2
		if Input.is_key_pressed(KEY_E): st.yaw -= delta * 1.2
		if mv != Vector3.ZERO:
			st.target += mv.rotated(Vector3.UP, st.yaw) * delta * maxf(st.dist, 20.0) * 0.8
