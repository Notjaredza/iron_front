extends SceneTree
## Iron Front air: animation videos for the user's look (Asset Builder Chat).
##   Godot --path iron_front --resolution 1280x720 --fixed-fps 30 -s res://tools/air_videos.gd [-- --only=name]
## Frames go to results/air/frames/<clip>/ as JPEG; ffmpeg makes results/air/<clip>.mp4.
## Clips per plane type (fighter, spotter, bomber): <type>_flying, <type>_weapons, <type>_takeoff, <type>_landing;
## and balloon_winch. Crash clips are played from the baked library (see air_bake.gd) by <name> from CRASHES.

const OUT := "res://results/air/"
const FPS := 30.0
const TYPES := ["fighter", "spotter", "bomber", "transport"]

var cam: Camera3D
var stage: Node3D
var sun: DirectionalLight3D
var env: Environment
var only := ""
var fx: AirFx
var cam_pos := Vector3.ZERO
var cam_at := Vector3.ZERO
var cam_init := false
var plane: Aircraft
var bal: Balloon
var fired := 0
var timers := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_world()
	var clips: Array[String] = []
	for t: String in TYPES:
		for c: String in ["flying", "weapons", "takeoff", "landing"]:
			if t == "transport" and c == "weapons":
				continue
			clips.append(t + "_" + c)
	clips.append("balloon_winch")
	var pc: GDScript = load("res://tools/air_para_clips.gd")
	for c: String in pc.CLIPS:
		clips.append(c)
	if ResourceLoader.exists("res://tools/air_crash_clips.gd"):
		var cc: GDScript = load("res://tools/air_crash_clips.gd")
		for c: String in cc.CLIPS:
			clips.append(c)
	for c in clips:
		if only != "" and not c.begins_with(only):
			continue
		await _clip(c)
	print("AIR VIDEOS DONE")
	quit()


func _world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.55, 0.88)
	sm.sky_horizon_color = Color(0.74, 0.84, 0.93)
	sm.ground_bottom_color = Color(0.35, 0.33, 0.28)
	sm.ground_horizon_color = Color(0.74, 0.82, 0.88)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.00022
	env.fog_light_color = Color(0.74, 0.82, 0.88)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.62, 0.30)
	gm.roughness = 1.0
	pm.material = gm
	ground.mesh = pm
	root.add_child(ground)
	# the field strip: mown lighter grass, a windsock, a few markers
	var strip := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(40, 900)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.58, 0.68, 0.38)
	smat.roughness = 1.0
	sp.material = smat
	strip.mesh = sp
	strip.position = Vector3(0, 0.02, -300)
	root.add_child(strip)
	var g := TrainGeo.new()
	g.cyl(Vector3(26, 0, -40), Vector3(26, 7, -40), 0.08, 6, Color(0.85, 0.85, 0.82))
	g.cyl(Vector3(26, 6.8, -40), Vector3(27.8, 6.6, -40), 0.35, 8, Color(0.95, 0.55, 0.15), 0.15)
	for k in 12:
		for sx: float in [-21.0, 21.0]:
			g.box(Vector3(sx, 0.2, -float(k) * 70.0), Vector3(0.4, 0.2, 0.4), Color(0.92, 0.92, 0.88))
	var holder := Node3D.new()
	root.add_child(holder)
	g.make(holder, "Field", AirParts.material())
	# a ground target: a row of crates and a lorry-sized block, for strafing and bombing
	var tg := TrainGeo.new()
	for k in 6:
		tg.box(Vector3(-6 + float(k) * 2.4, 0.5, -900), Vector3(0.8, 0.5, 0.6), Color(0.45, 0.38, 0.26))
	tg.box(Vector3(8, 1.2, -905), Vector3(1.0, 1.2, 3.0), Color(0.36, 0.40, 0.24))
	tg.make(holder, "Target", AirParts.material())
	cam = Camera3D.new()
	cam.far = 6000.0
	root.add_child(cam)
	cam.current = true


func _record(nm: String, secs: float, step: Callable) -> void:
	var dir := ProjectSettings.globalize_path(OUT + "frames/" + nm + "/")
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(ProjectSettings.globalize_path(OUT + "frames/.gdignore"), FileAccess.WRITE).store_string("")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	var frames := int(secs * FPS)
	var dt := 1.0 / FPS
	for i in frames:
		step.call(float(i) * dt, dt)
		fx.step(dt)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(dir + "%05d.jpg" % i, 0.9)
	var mp4 := ProjectSettings.globalize_path(OUT + nm + ".mp4")
	var out := []
	var code := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", "30", "-i", dir + "%05d.jpg",
		"-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", mp4], out, true)
	print("AIR VIDEO %s frames=%d ffmpeg=%d" % [nm, frames, code])


func _new_stage() -> void:
	if stage:
		stage.free()
	stage = Node3D.new()
	root.add_child(stage)
	fx = AirFx.make()
	stage.add_child(fx)
	cam_init = false
	fired = 0
	timers = {}
	plane = null
	bal = null


## Smoothed camera: moves towards from, looks towards at; k is the follow rate (1/s).
func _cam(from: Vector3, at: Vector3, dt: float, k := 4.0, fov := 45.0) -> void:
	if not cam_init:
		cam_pos = from
		cam_at = at
		cam_init = true
	var a := clampf(k * dt, 0.0, 1.0)
	cam_pos = cam_pos.lerp(from, a)
	cam_at = cam_at.lerp(at, clampf(a * 2.0, 0.0, 1.0))
	cam.fov = fov
	cam.transform = Transform3D(Basis(), cam_pos).looking_at(cam_at, Vector3.UP)


func _size(k: String) -> float:
	return float(AirParts.spec(k)["span_u"]) / 8.4


## Chase offset in the plane's heading frame (not banked): x right, y up, z behind.
func _chase(off: Vector3, dt: float, k := 3.0, fov := 45.0) -> void:
	var b := Basis(Vector3.UP, plane.heading)
	_cam(plane.position + b * off, plane.position, dt, k, fov)


func _clip(nm: String) -> void:
	_new_stage()
	var parts := nm.split("_")
	if nm.begins_with("para_"):
		var pc: GDScript = load("res://tools/air_para_clips.gd")
		await pc.new().play(self, nm)
		return
	if nm == "balloon_winch":
		await _balloon_winch()
		return
	if nm.begins_with("crash_") or nm.ends_with("_spin") or nm.ends_with("_wing") or nm == "balloon_burn":
		var cc: GDScript = load("res://tools/air_crash_clips.gd")
		await cc.new().play(self, nm)
		return
	var k := parts[0]
	match parts[1]:
		"flying":
			await _flying(k)
		"weapons":
			await _weapons(k)
		"takeoff":
			await _takeoff(k)
		"landing":
			await _landing(k)


func _spawn(k: String, at: Vector3, heading: float, spd: float, airborne: bool) -> Aircraft:
	plane = AirParts.make(k)
	stage.add_child(plane)
	plane.heading = heading
	plane.speed = spd
	plane.position = at
	if airborne:
		plane.on_ground = false
		plane.engine_on = true
		plane.rpm = 1300.0
		plane.throttle = 0.6
		plane.fly_pose(at, heading, 0.0, 0.0)
	else:
		plane.ground_pose(at, 0.0, heading, 0.0)
	return plane


# ------------------------------------------------------------------ flying: turns, climb, dive, surfaces moving

func _flying(k: String) -> void:
	var s := _size(k)
	_spawn(k, Vector3(0, 120, 0), 0.0, AirParts.spec(k)["cruise"], true)
	var dur := 22.0
	await _record(k + "_flying", dur, func(t: float, dt: float) -> void:
		var turn := 0.0
		var rate := 0.0
		var spd: float = plane.cruise
		if t < 2.5:
			pass
		elif t < 8.0:
			turn = 0.32
		elif t < 9.5:
			turn = 0.0
		elif t < 13.0:
			rate = 7.0
		elif t < 17.0:
			rate = -14.0
			spd = plane.cruise * 1.35
		else:
			turn = -0.38
		plane.fly(dt, turn, rate, spd)
		# close chase from behind and above, swinging round to the side half way
		var side := smoothstep(6.0, 10.0, t) - smoothstep(16.0, 19.0, t) * 0.6
		var off := Vector3(lerpf(4.0, 14.0, side), lerpf(3.2, 2.0, side), lerpf(15.0, 2.0, side)) * s
		_chase(off, dt, 3.0, 42.0))


# ------------------------------------------------------------------ weapons

func _weapons(k: String) -> void:
	match k:
		"fighter":
			await _weapons_fighter()
		"spotter":
			await _weapons_spotter()
		"bomber":
			await _weapons_bomber()


## Strafing dive on the crates, then a message bag on the field.
func _weapons_fighter() -> void:
	_spawn("fighter", Vector3(0, 110, -560), 0.0, 45.0, true)
	await _record("fighter_weapons", 20.0, func(t: float, dt: float) -> void:
		var rate := 0.0
		var spd := 45.0
		var turn := 0.0
		if t >= 2.0 and t < 7.0:
			rate = -18.0
			spd = 58.0
		elif t >= 7.0 and t < 10.0:
			rate = 14.0
		elif t >= 10.0 and t < 14.0:
			turn = 0.45
		plane.fly(dt, turn, rate, spd)
		var firing := t >= 4.0 and t < 6.6
		plane.flash([0], firing and int(t * FPS) % 2 == 0)
		if firing and int(t * FPS) % 2 == 0:
			fx.shoot(plane.muzzle(0), plane.muzzle_dir(0), plane.velocity())
		if t >= 15.0 and not timers.has("bag"):
			timers["bag"] = true
			var bag := AirParts.message_bag()
			stage.add_child(bag)
			bag.global_position = plane.to_global(Vector3(0.6, 0.4, 0.3))
			fx.drop(bag, plane.velocity() * 0.9 + Vector3(2, 0, 0), "bag")
		# a ground camera by the crates watches the dive, then follows the plane away
		if t < 7.5:
			# over the shoulder in the dive: the tracers stream down onto the crates
			_chase(Vector3(3.5, 3.0, 12.0), dt, 4.0, 50.0)
		elif t < 14.5:
			_cam(Vector3(30, 4, -935), plane.position, dt, 2.0, 50.0)
		else:
			var bag_n := stage.get_node_or_null("MessageBag")
			var at: Vector3 = bag_n.global_position if bag_n else plane.position
			_cam(at + Vector3(14, 6, 16), at, dt, 2.0, 45.0))


## Observer swings the ring round and fires rearwards; the pilot's gun fires; a message drop at the end.
func _weapons_spotter() -> void:
	_spawn("spotter", Vector3(0, 90, 0), 0.0, 40.0, true)
	await _record("spotter_weapons", 18.0, func(t: float, dt: float) -> void:
		var turn := 0.0
		if t > 12.0:
			turn = 0.25
		plane.fly(dt, turn, 0.0, 40.0)
		# the ring swings from forward round to the rear right, the gun lifts and dips while tracking
		var yaw := lerpf(0.0, 2.6, smoothstep(1.0, 4.0, t)) + sin(t * 1.3) * 0.25 * smoothstep(4.0, 5.0, t)
		yaw = lerpf(yaw, -2.4, smoothstep(8.0, 10.0, t))
		var pitch := 0.25 + sin(t * 0.9) * 0.25
		plane.aim_gunner(0, yaw, pitch)
		var ring_firing := (t > 4.5 and t < 6.5) or (t > 10.0 and t < 11.5)
		var fixed_firing := t > 7.0 and t < 8.0
		var f := int(t * FPS) % 2 == 0
		var which: Array = []
		if ring_firing and f:
			which.append(1)
			fx.shoot(plane.muzzle(1), plane.muzzle_dir(1), plane.velocity(), 0.012)
		if fixed_firing and f:
			which.append(0)
			fx.shoot(plane.muzzle(0), plane.muzzle_dir(0), plane.velocity())
		plane.flash(which, not which.is_empty())
		if t >= 13.0 and not timers.has("bag"):
			timers["bag"] = true
			var bag := AirParts.message_bag()
			stage.add_child(bag)
			bag.global_position = plane.to_global(Vector3(-0.7, 0.5, 0.9))
			fx.drop(bag, plane.velocity() * 0.9 + plane.global_transform.basis.x * -2.0, "bag")
		if t < 12.5:
			_chase(Vector3(5.5, 3.2, 6.0), dt, 4.0, 45.0)
		else:
			var bag_n := stage.get_node_or_null("MessageBag")
			var at: Vector3 = bag_n.global_position if bag_n else plane.position
			_cam(at + Vector3(12, 5, 14), at, dt, 2.5, 45.0))


## Gunners swing and fire; the bombs drop one by one and fall nose-down onto the target.
func _weapons_bomber() -> void:
	_spawn("bomber", Vector3(0, 140, -400), 0.0, 36.0, true)
	await _record("bomber_weapons", 22.0, func(t: float, dt: float) -> void:
		plane.fly(dt, 0.0, 0.0, 36.0)
		plane.aim_gunner(0, sin(t * 0.8) * 0.9, 0.15 + sin(t * 1.1) * 0.2)
		plane.aim_gunner(1, PI + sin(t * 0.6 + 1.0) * 1.2, 0.35 + sin(t * 0.9) * 0.25)
		var f := int(t * FPS) % 2 == 0
		var which: Array = []
		if t > 2.0 and t < 3.5 and f:
			which.append(0)
			fx.shoot(plane.muzzle(0), plane.muzzle_dir(0), plane.velocity(), 0.012)
		if t > 4.0 and t < 6.0 and f:
			which.append(1)
			fx.shoot(plane.muzzle(1), plane.muzzle_dir(1), plane.velocity(), 0.012)
		plane.flash(which, not which.is_empty())
		# bombs away from 7.5 s, one every 0.3 s
		var nb := plane.bombs.size()
		var due := int((t - 7.5) / 0.3) + 1 if t >= 7.5 else 0
		while fired < mini(due, nb):
			var b := plane.release_bomb(fired, stage)
			fx.drop(b, plane.velocity(), "bomb")
			fired += 1
		if t < 7.0:
			_chase(Vector3(16, 6, 10), dt, 3.0, 45.0)
		elif t < 9.0:
			_chase(Vector3(10, -5, 6), dt, 2.0, 50.0)
		else:
			# a camera off to the side of the target looks at the falling bombs, then the bursts
			var at := Vector3(0, 0, -900)
			var n := 0
			for b in plane.bombs:
				if b.visible and b.get_parent() == stage:
					at += b.global_position
					n += 1
			if n > 0:
				at = (at - Vector3(0, 0, -900)) / float(n)
			else:
				at = Vector3(0, 10, -905)
			_cam(Vector3(90, 30, -870), at, dt, 2.0, 40.0))


# ------------------------------------------------------------------ ground: engine start, taxi, take-off; landing

func _takeoff(k: String) -> void:
	var s := _size(k)
	_spawn(k, Vector3(-18, 0, 30), -PI * 0.5, 0.0, false)
	await _record(k + "_takeoff", 26.0, func(t: float, dt: float) -> void:
		if t > 0.8:
			plane.engine_on = true
		if t < 3.5:
			plane.roll_ground(dt, 0.0, 0.0)
		elif t < 10.0:
			# taxi onto the strip, swinging left to face down it (-Z)
			var steer := 0.0
			if plane.heading < -0.02:
				steer = 0.5
			plane.roll_ground(dt, 4.0, steer)
		elif t < 11.0:
			plane.roll_ground(dt, 0.0, 0.0)
		elif plane.on_ground:
			plane.roll_ground(dt, plane.stall * 1.3, 0.0, 0.0, true)
		else:
			plane.fly(dt, 0.0, 4.5, plane.cruise)
		# a ground camera beside the strip, sliding along with the take-off run
		if t < 11.0:
			_cam(plane.position + Vector3(9, 3, -12) * s, plane.position + Vector3(0, 0.8, 0), dt, 2.0, 45.0)
		else:
			_cam(Vector3(14.0 + 9.0 * s, 3, plane.position.z + 14), plane.position, dt, 1.2, 45.0))


func _landing(k: String) -> void:
	var s := _size(k)
	var st: float = AirParts.spec(k)["stall"]
	_spawn(k, Vector3(0, 32, 260), 0.0, st * 1.25, true)
	await _record(k + "_landing", 28.0, func(t: float, dt: float) -> void:
		if not plane.landed:
			plane.approach(dt, 0.0, 0.075, st * 1.08)
		else:
			plane.roll_ground(dt, 0.0, 0.0)
			if plane.speed < 0.5:
				if not timers.has("stop"):
					timers["stop"] = t
				if t - float(timers["stop"]) > 1.5:
					plane.engine_on = false
		_cam(Vector3(12.0 + 9.0 * s, 2.5, plane.position.z - 10), plane.position, dt, 1.0, 45.0))


# ------------------------------------------------------------------ balloon: winched up and down, swaying

func _balloon_winch() -> void:
	bal = Balloon.make()
	stage.add_child(bal)
	bal.position = Vector3(40, 0, -60)
	bal.rotation.y = 0.4
	bal.set_height(0.0)
	await _record("balloon_winch", 28.0, func(t: float, dt: float) -> void:
		var h := 0.0
		if t < 2.0:
			h = 0.0
		elif t < 18.0:
			h = 90.0 * smoothstep(2.0, 18.0, t)
		elif t < 22.0:
			h = 90.0
		else:
			h = 90.0 - 30.0 * smoothstep(22.0, 28.0, t)
		bal.wind(t, clampf(h / 30.0, 0.0, 1.0))
		bal.set_height(h)
		var drum := bal.drum.global_position
		var basket := bal.kite.global_position
		if t < 7.0:
			_cam(drum + bal.global_transform.basis * Vector3(6, 2.5, -5), drum, dt, 3.0, 45.0)
		else:
			var mid := (drum + basket) * 0.5 + Vector3(0, 8, 0)
			_cam(drum + bal.global_transform.basis * Vector3(70, 25, -80), mid, dt, 0.8, 50.0))
