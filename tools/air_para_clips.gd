extends RefCounted
## Iron Front air: the paratrooper clips for air_videos.gd (Asset Builder Chat).
##   para_loading  men walk up to the transport on the strip, climb the ladder, the door shuts, engines start
##   para_drop     the stick jumps one after another, chutes open, they drift down and land
##   para_landing  close up: one man lands, rolls, gathers his chute and stands ready (two more beside him)
##   para_supply   ammo, food and medical crates pushed out on their coloured chutes, landing
##   para_shot     hit by flak mid-drop: men bail out early, a streamer, a burning chute, a man hit in his
##                 harness, then the transport goes into its baked spin crash

const CLIPS := ["para_loading", "para_drop", "para_landing", "para_supply", "para_shot"]
const V := preload("res://scripts/units/anim/clips_vehicle.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")

var m: Object
var a: Aircraft
var men: Array[Para] = []
var crates: Array[SupplyCrate] = []
var gone: Array[bool] = []
var player: AnimationPlayer
var crash_from := -1.0
var hit_done := false
var last := Vector3.ZERO


func play(main: Object, nm: String) -> void:
	m = main
	match nm:
		"para_loading":
			await _loading()
		"para_drop":
			await _drop()
		"para_landing":
			await _landing()
		"para_supply":
			await _supply()
		"para_shot":
			await _shot()


static func face(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _out() -> Vector3:
	# out of the door: the transport's left side
	return Basis(Vector3.UP, a.heading) * Vector3(-1, 0, 0)


func _spawn_flying(h: float, z: float, spd: float) -> void:
	a = AirParts.make("transport")
	m.stage.add_child(a)
	a.heading = 0.0
	a.speed = spd
	a.position = Vector3(0, h, z)
	a.on_ground = false
	a.engine_on = true
	a.rpm = 1300.0
	a.throttle = 0.6
	a.fly_pose(a.position, 0.0, 0.0, 0.0)


func _man(seed_value: int) -> Para:
	var p := Para.make(seed_value)
	m.stage.add_child(p)
	men.append(p)
	gone.append(false)
	return p


## A man waiting in the doorway: crouched on the sill, facing out, riding with the plane.
func _in_door(p: Para) -> void:
	p.visible = true
	p.position = a.mark_world("door_sill")
	p.rotation = Vector3(0, face(_out()), 0)
	p.pose_blend(V.crouch(0.3), V.crouch(0.3), 0.0, false)


func _jump(p: Para, fate := "ok", hit_t := -1.0, burn_t := -1.0) -> void:
	p.jump(a.velocity() + _out() * 1.8, face(_out()), fate, hit_t, burn_t)


func _burn_fx(dt: float) -> void:
	for p in men:
		if p.burn > 0.0 and p.burn < 0.97 and p.canopy.visible:
			var at := p.canopy.global_position + Vector3(0, Canopy.LEN * (1.0 - p.burn * 0.6), 0)
			m.fx.trail(at, p.vel, 2.0)


# ------------------------------------------------------------------ loading on the ground

func _loading() -> void:
	a = AirParts.make("transport")
	m.stage.add_child(a)
	a.ground_pose(Vector3(0, 0, 0), 0.0, 0.0, 0.0)
	a.set_door(1.0)
	var n := 6
	var foot := a.mark_world("ladder_foot")
	foot.y = 0.0
	var start := foot + Vector3(-6, 0, 5)
	for i in n:
		var p := _man(200 + i)
		p.position = start + Vector3(-0.9, 0, 1.2) * float(i)
	var walk_v: float = Body.WALK["v"]
	await m._record("para_loading", 30.0, func(t: float, dt: float) -> void:
		var all_in := true
		for i in n:
			var p := men[i]
			if gone[i]:
				continue
			all_in = false
			# men set off one after another, about 1.6 s apart; each walks to the ladder foot, climbs, steps in
			var go := 1.0 + float(i) * 1.6
			var line_start := start + Vector3(-0.9, 0, 1.2) * float(i)
			var walk_len := line_start.distance_to(foot)
			var walk_t := walk_len / walk_v
			var s := t - go
			if s < 0.0:
				p.man.pose_spec_world(p._stand())
				p.rotation.y = face(foot - line_start)
			elif s < walk_t:
				p.position = line_start.lerp(foot, s / walk_t)
				p.rotation.y = face(foot - line_start)
				p.walk_pose(s)
			elif s < walk_t + 1.6:
				var c := (s - walk_t) / 1.6
				var sill := a.mark_world("door_sill")
				p.position = foot.lerp(sill, smoothstep(0.0, 1.0, c))
				p.rotation.y = face(Basis(Vector3.UP, a.heading) * Vector3(1, 0, 0))
				var stg := 0 if fmod(c * 3.0, 1.0) < 0.5 else 1
				p.pose_blend(V.climb(stg, 0.42, 0.84), V.climb(stg, 0.42, 0.84), 0.0)
			elif s < walk_t + 2.2:
				var c := (s - walk_t - 1.6) / 0.6
				p.position = a.mark_world("door_sill").lerp(a.mark_world("door_in") + Vector3(0, 0, 0), c)
				p.pose_blend(V.stooped(), V.stooped(), 0.0)
			else:
				p.visible = false
				gone[i] = true
		if all_in:
			if not timers_has("shut"):
				timers_set("shut", t)
			var since := t - float(m.timers["shut"])
			a.ladder.visible = since < 0.6
			a.set_door(1.0 - smoothstep(0.6, 1.8, since))
			if since > 2.5:
				a.engine_on = true
			a.roll_ground(dt, 0.0, 0.0)
		# a ground camera off the door, turning a little with the line of men
		var door := a.mark_world("door_sill")
		m._cam(door + Vector3(-15.5, 1.9, -1.5), door + Vector3(-3, -0.7, 2.2), dt, 2.0, 45.0))


func timers_has(k: String) -> bool:
	return m.timers.has(k)


func timers_set(k: String, v: float) -> void:
	m.timers[k] = v


# ------------------------------------------------------------------ the drop

func _drop() -> void:
	var h := 75.0
	_spawn_flying(h, 230.0, 30.0)
	var n := 8
	for i in n:
		var p := _man(300 + i)
		p.visible = false
	await m._record("para_drop", 30.0, func(t: float, dt: float) -> void:
		a.fly(dt, 0.0, 0.0, 30.0)
		a.set_door(smoothstep(0.3, 1.2, t))
		_stick(t, dt, 2.0, 0.8, [])
		_burn_fx(dt)
		# beside the plane watching the door, then out to the side of the stick as it comes down
		if t < 9.0:
			var b := Basis(Vector3.UP, a.heading)
			var door := a.mark_world("door_sill")
			m._cam(door + b * Vector3(-14, -3.5, 16), door + b * Vector3(-4, -4, -2), dt, 3.0, 50.0)
		else:
			var mid := Vector3.ZERO
			var k := 0
			for p in men:
				if p.state != "aboard":
					mid += p.position
					k += 1
			mid = mid / maxf(1.0, float(k)) if k > 0 else Vector3(0, 40, 0)
			var near := smoothstep(14.0, 22.0, t)
			m._cam(Vector3(lerpf(-70.0, -32.0, near), lerpf(8.0, 3.5, near), mid.z + lerpf(40.0, 16.0, near)), mid + Vector3(0, 2, 0), dt, 0.8, 45.0))


## Men come to the door every gap seconds from first; each crouches 0.45 s then goes. fates: per-man
## [fate, hit_t, burn_t] (missing means "ok").
func _stick(t: float, dt: float, first: float, gap: float, fates: Array) -> void:
	for i in men.size():
		var p := men[i]
		var at := first + float(i) * gap
		if p.state == "aboard":
			if t >= at - 0.45 and t < at:
				_in_door(p)
			elif t >= at:
				p.visible = true
				p.position = a.mark_world("door_sill")
				var f: Array = fates[i] if i < fates.size() else ["ok", -1.0, -1.0]
				_jump(p, f[0], f[1], f[2])
		p.step(dt)


# ------------------------------------------------------------------ landing close up

func _landing() -> void:
	var offs := [Vector3(0, 22, 0), Vector3(-7, 26.5, -5), Vector3(8, 30, 4)]
	for i in 3:
		var p := _man(400 + i)
		p.position = offs[i]
		p.jump(Vector3(0, -5.4, 0), -0.9)
		p.state = "chute"
		p.open = 1.0
		p.t = Para.OPEN_AT + 2.0
		p.canopy.visible = true
		p.risers.visible = true
		p.swing = Vector2(0.12, -0.08 * float(i + 1))
	await m._record("para_landing", 11.0, func(t: float, dt: float) -> void:
		for p in men:
			p.step(dt)
		var p0 := men[0]
		var at := p0.position + Vector3(0, 1.2, 0)
		if p0.state == "chute":
			at = p0.position + Vector3(0, 1.0, 0)
			m._cam(Vector3(7, 1.6, 8.5), at, dt, 3.0, 45.0)
		else:
			m._cam(Vector3(5.5, 1.3, 6.5), p0.position + Vector3(0.6, 0.6, -0.5), dt, 1.5, 45.0))


# ------------------------------------------------------------------ supply drop

func _supply() -> void:
	_spawn_flying(70.0, 200.0, 30.0)
	var kinds := ["ammo", "food", "medical", "ammo", "medical"]
	for i in kinds.size():
		var c := SupplyCrate.make(kinds[i])
		m.stage.add_child(c)
		c.visible = false
		crates.append(c)
	await m._record("para_supply", 24.0, func(t: float, dt: float) -> void:
		a.fly(dt, 0.0, 0.0, 30.0)
		a.set_door(smoothstep(0.3, 1.2, t))
		for i in crates.size():
			var c := crates[i]
			var at := 2.5 + float(i) * 1.1
			if c.state == "aboard":
				if t >= at - 0.4:
					c.visible = true
					c.position = a.mark_world("door_sill") + _out() * 0.35
					c.rotation.y = a.heading
				if t >= at:
					c.drop(a.velocity() + _out() * 1.5)
			c.step(dt)
		if t < 7.0:
			var b := Basis(Vector3.UP, a.heading)
			var door := a.mark_world("door_sill")
			m._cam(door + b * Vector3(-13, -3, 15), door + b * Vector3(-3, -4, -3), dt, 3.0, 50.0)
		else:
			var mid := Vector3.ZERO
			for c in crates:
				mid += c.position
			mid /= float(crates.size())
			m._cam(Vector3(-55, 6, mid.z + 30), mid + Vector3(0, 2, 0), dt, 0.8, 45.0))


# ------------------------------------------------------------------ shot during the drop

func _shot() -> void:
	_spawn_flying(AirCrashes.START_H, 260.0, 30.0)
	var n := 8
	for i in n:
		var p := _man(500 + i)
		p.visible = false
	# fates: the first two go cleanly; then the plane is hit and the rest bail out fast and early
	var fates := [["ok", -1.0, -1.0], ["ok", -1.0, -1.0], ["streamer", -1.0, -1.0], ["ok", -1.0, 2.6],
		["hit", 6.0, -1.0], ["ok", -1.0, -1.0], ["streamer", -1.0, -1.0], ["ok", -1.0, -1.0]]
	var flak_at := [3.6, 4.3, 4.9, 5.6, 6.4]
	var mg := Vector3(-55, 1.0, 120)
	await m._record("para_shot", 34.0, func(t: float, dt: float) -> void:
		if crash_from < 0.0:
			a.fly(dt, 0.0, 0.0, 30.0)
			a.set_door(smoothstep(0.3, 1.0, t))
			# flak bursts around the plane; the left engine is hit at 5.6 s and starts burning
			for f: float in flak_at:
				if t >= f and t - dt < f:
					var b := Basis(Vector3.UP, a.heading)
					var burst := a.position + b * Vector3(randf_range(-14, 10), randf_range(-6, 8), randf_range(-12, 6))
					for k in 6:
						m.fx.trail(burst + Vector3(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), Vector3.ZERO, 2.0)
			if t > 5.6:
				var wl: Node3D = a.get_node("WingL")
				var eng := a.to_global(wl.transform * Vector3(-4.2, 0.55, -2.4))
				m.fx.trail(eng, a.velocity(), 2.0 if t > 6.5 else 1.0)
			if t >= 10.5:
				_start_crash()
		else:
			_crash_step(t, dt)
		# the stick: two clean exits, then the rest go fast (0.45 s apart) once the plane is hit
		for i in men.size():
			var p := men[i]
			var at := 2.0 + float(i) * 0.8 if i < 2 else 5.9 + float(i - 2) * 0.45
			if p.state == "aboard" and crash_from < 0.0:
				if t >= at - 0.35 and t < at:
					_in_door(p)
				elif t >= at:
					p.visible = true
					p.position = a.mark_world("door_sill")
					_jump(p, fates[i][0], fates[i][1], fates[i][2])
			p.step(dt)
		_burn_fx(dt)
		# a machine gun on the ground fires up at the hanging men; the burst finds man 4
		var target := men[4]
		var jt: float = 5.9 + 2.0 * 0.45
		if t > jt + 4.0 and t < jt + 6.5 and int(t * 30.0) % 3 == 0 and target.state == "chute":
			var aim := target.position + Vector3(0, 1.2, 0) - mg
			m.fx.shoot(mg, aim.normalized(), Vector3.ZERO, 0.02)
		# camera: chase beside the plane through the hits and the bail-out, then pull back to watch the plane
		# go down beyond the chutes
		var b2 := Basis(Vector3.UP, a.heading)
		if crash_from < 0.0:
			var door := a.mark_world("door_sill")
			m._cam(door + b2 * Vector3(-18, -4, 20), door + b2 * Vector3(-4, -5, -4), dt, 3.0, 50.0)
		else:
			var mid := Vector3.ZERO
			var k := 0
			for p in men:
				if p.state == "chute" or p.state == "exit":
					mid += p.position
					k += 1
			var plane_at := _fus()
			var look := plane_at if k == 0 else (mid / float(k)).lerp(plane_at, 0.45)
			m._cam(Vector3(-110, 25, look.z + 70), look, dt, 0.7, 50.0))


func _fus() -> Vector3:
	return a.to_global((a.get_node("Fuselage") as Node3D).position)


## Hands the plane over to the baked spin crash from where it is, level at START_H.
func _start_crash() -> void:
	crash_from = 0.0
	a.transform = Transform3D(Basis(Vector3.UP, a.heading), Vector3(a.position.x, AirCrashes.START_H, a.position.z))
	player = AirCrashes.player_for(a)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("transport_spin")
	player.advance(0.0)
	last = _fus()


func _crash_step(t: float, dt: float) -> void:
	player.advance(dt)
	a.spin(dt)
	var p := _fus()
	var vel := (p - last) / dt
	last = p
	var crash_t: float = a.crash_time
	var after := crash_t >= 0.0 and player.current_animation_position >= crash_t
	if after and not hit_done:
		hit_done = true
		var bl := Blast.new().setup(3, Vector3(p.x, 0.0, p.z), 11)
		m.stage.add_child(bl)
	var wl: Node3D = a.get_node("WingL")
	var eng := a.to_global(wl.transform * Vector3(-4.2, 0.55, -2.4))
	if after:
		if int(t * 30.0) % 2 == 0:
			m.fx.trail(Vector3(p.x, 1.0, p.z), Vector3.ZERO, 2.0)
	else:
		m.fx.trail(eng, vel, 2.0)
		m.fx.trail(eng - vel * dt * 0.5, vel, 2.0)
