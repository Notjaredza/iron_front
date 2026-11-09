extends RefCounted
## Iron Front air: films the baked crash clips for air_videos.gd (Asset Builder Chat). Each clip is played
## through an AnimationPlayer from assets/air/crashes.res, exactly as the game would play it, with the smoke,
## fire and impact effects driven from the clip's fire_level, rpm and crash_time tracks.

const CLIPS := ["fighter_spin", "fighter_wing", "spotter_spin", "spotter_wing", "bomber_spin", "bomber_wing", "balloon_burn"]

var m: Object
var player: AnimationPlayer
var a: Aircraft
var b: Balloon
var last := Vector3.ZERO
var hit_done := false
var size := 1.0
var t_anim := 0.0


func play(main: Object, nm: String) -> void:
	m = main
	if nm == "balloon_burn":
		await _balloon()
		return
	var kind := nm.split("_")[0]
	size = float(AirParts.spec(kind)["span_u"]) / 8.4
	a = AirParts.make(kind)
	m.stage.add_child(a)
	a.position = Vector3(0, AirCrashes.START_H, -200)
	player = AirCrashes.player_for(a)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(nm)
	player.advance(0.0)
	last = _fus()
	var len := player.current_animation_length + 2.0
	await m._record(nm, len, _plane_step)


func _fus() -> Vector3:
	return a.to_global((a.get_node("Fuselage") as Node3D).position)


func _engines() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if a.marks.has("exhaust0"):
		for i in 2:
			var g: Node3D = a.get_node("WingL" if i == 0 else "WingR")
			out.append(a.to_global(g.transform * (a.marks["exhaust%d" % i] as Vector3)))
	else:
		var f: Node3D = a.get_node("Fuselage")
		var nose: float = float(AirParts.spec(a.kind)["fus"][0][0]) + 0.6
		out.append(a.to_global(f.transform * Vector3(0, 0.3, nose)))
	return out


func _plane_step(t: float, dt: float) -> void:
	player.advance(dt)
	a.spin(dt)
	var p := _fus()
	var vel := (p - last) / dt
	last = p
	var crash_t: float = a.crash_time
	var after := crash_t >= 0.0 and player.current_animation_position >= crash_t
	if after and not hit_done:
		hit_done = true
		var bl := Blast.new().setup(2 if a.kind != "bomber" else 3, Vector3(p.x, 0.0, p.z), 7)
		m.stage.add_child(bl)
	if a.fire_level > 0.0:
		var engines := _engines()
		for e in engines:
			if after:
				# a burning wreck: flames low, black smoke rising
				if int(t * 30.0) % 2 == 0:
					m.fx.trail(e, Vector3.ZERO, 2.0)
			else:
				m.fx.trail(e, vel, a.fire_level)
				m.fx.trail(e - vel * dt * 0.5, vel, a.fire_level)
	# camera: a chase that does not spin with the plane, then a slow turn round the wreck
	if not after:
		m._cam(p + Vector3(22, 9, 26) * size, p, dt, 3.0, 45.0)
	else:
		var since := player.current_animation_position - crash_t
		var ang := 0.7 + since * 0.12
		var r := 30.0 * size
		m._cam(p + Vector3(sin(ang) * r, 9.0 * size, cos(ang) * r), p, dt, 1.0, 45.0)


func _balloon() -> void:
	b = Balloon.make()
	m.stage.add_child(b)
	b.position = Vector3(30, 0, -150)
	b.rotation.y = 0.5
	b.set_height(AirCrashes.BALLOON_H)
	player = AirCrashes.player_for(b)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("balloon_burn")
	player.advance(0.0)
	await m._record("balloon_burn", player.current_animation_length + 2.0, _balloon_step)


func _balloon_step(t: float, dt: float) -> void:
	player.advance(dt)
	var crash_t: float = b.crash_time
	var pos := player.current_animation_position
	var down := crash_t >= 0.0 and pos >= crash_t
	if b.fire_level > 0.0:
		# flames all along the burning envelope (from the tail forward), heavy black smoke
		var burn := smoothstep(0.3, 4.0, pos)
		for i in 4:
			var seg: Node3D = b.segments[i]
			if burn * 4.0 < float(3 - i):
				continue
			var c := seg.to_global(Vector3(0, 0, [-11.0, -4.0, 3.0, 9.0][i]))
			var n := 2 if not down else 1
			for k in n:
				m.fx.glow.add("flame", c + m.fx.glow.jitter(2.5), Vector3(0, 4, 0) + m.fx.glow.jitter(2.0), 3.0)
			if int(t * 30.0) % 4 == 0 and i % 2 == 0:
				if not down or int(t * 30.0) % 3 == 0:
					m.fx.smoke.add("burn", c + m.fx.smoke.jitter(2.0), Vector3(1.5, 3, 0), 1.2)
	var kite := b.kite.global_position
	if pos < 6.0:
		m._cam(kite + Vector3(55, 10, 45), kite + Vector3(0, 8, 0), dt, 1.5, 50.0)
	else:
		# follow the second man down under his chute, the wreck burning beyond
		var man: Node3D = b.crew[1]
		var mp := man.global_position
		m._cam(mp + Vector3(18, 6, 22), mp.lerp(kite, 0.25), dt, 1.2, 50.0)
