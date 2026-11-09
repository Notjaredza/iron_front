class_name BlastStage
extends Node3D
## Explosion round A (Building Chat 1, 2026-11-09): the blast test's world. Sky, sun and mood as the map's day and
## night (map_view.gd), a faceted field where craters stay, a squad of riflemen for scale, an orbit camera with
## shake, and blasts. The live test (tools/blast_test.gd) and the video tool (tools/blast_clips.gd) both use it.
## In the live test the clock runs by itself; the video tool sets it frame by frame (step), so clips repeat exactly.

var env: Environment
var sun: DirectionalLight3D
var sky: ProceduralSkyMaterial
var ground: FxGround
var cam: Camera3D
var men: Array[Soldier] = []
var blasts: Array = []                    # [Blast, start clock]
var craters: Array = []                   # round B: craters still to cut [clock, point, radius, depth]
var throws: Array[BlastThrow] = []        # round B: men caught by blasts
var throw_rng := RandomNumberGenerator.new()
var clock := 0.0
var manual := false                       # true: the video tool moves the clock
var is_night := false
var style := Blast.Style.FACET
# The orbit camera.
var target := Vector3(0, 2, 0)
var yaw := 0.6
var pitch := -0.22
var dist := 70.0
var shake_on := true


func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	sky = ProceduralSkyMaterial.new()
	env.sky.sky_material = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL      # as the map (map_view.gd)
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)
	ground = FxGround.new()
	add_child(ground)
	cam = Camera3D.new()
	cam.far = 30000.0
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	set_night(false)
	Blast.set_wind(Vector2(2.6, 0.9))
	BlastThrow.lib()                      # build the riflemen's clips now, not on the first throw


func set_night(on: bool) -> void:
	is_night = on
	Blast.set_night(on)
	if not on:
		sun.rotation_degrees = Vector3(-52, 35, 0)
		sun.light_color = Color(1.0, 0.96, 0.88)
		sun.light_energy = 1.35
		sky.sky_top_color = Color(0.32, 0.55, 0.86)
		sky.sky_horizon_color = Color(0.70, 0.80, 0.90)
		sky.ground_horizon_color = Color(0.62, 0.70, 0.74)
		sky.ground_bottom_color = Color(0.35, 0.40, 0.36)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 1.0
		env.fog_light_color = Color(0.74, 0.82, 0.90)
		env.fog_density = 0.00008
		env.fog_sky_affect = 0.3
		env.tonemap_exposure = 1.05
	else:
		sun.rotation_degrees = Vector3(-60, -40, 0)
		sun.light_color = Color(0.56, 0.66, 0.92)
		sun.light_energy = 0.5
		sky.sky_top_color = Color(0.02, 0.03, 0.07)
		sky.sky_horizon_color = Color(0.07, 0.09, 0.14)
		sky.ground_horizon_color = Color(0.06, 0.07, 0.10)
		sky.ground_bottom_color = Color(0.02, 0.02, 0.03)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.22, 0.26, 0.36)
		env.ambient_light_energy = 0.9
		env.fog_light_color = Color(0.07, 0.09, 0.13)
		env.fog_density = 0.00045
		env.fog_sky_affect = 1.0
		env.tonemap_exposure = 1.0


## A squad of riflemen in mixed poses round a point, facing towards look_at.
func place_squad(at: Vector3, look_at: Vector3, seed_value := 1) -> void:
	var poses: Array[String] = ["aim", "kneel", "prone", "stand", "aim", "kneel", "prone", "aim", "stand", "kneel", "aim", "prone"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 12:
		var s := Soldier.new().setup(seed_value * 31 + i, 0)
		var off := Vector3(float(i % 4) * 2.6 - 3.9 + rng.randf_range(-0.6, 0.6), 0, float(i / 4) * 2.4 - 2.4 + rng.randf_range(-0.5, 0.5))
		var to := (look_at - at)
		var yaw_s := atan2(to.x, to.z)
		off = off.rotated(Vector3.UP, yaw_s)
		s.position = at + off
		s.position.y = ground.height(s.position.x, s.position.z)
		s.rotation.y = yaw_s + PI + rng.randf_range(-0.25, 0.25)
		add_child(s)
		s.set_pose(poses[i])
		s.set_meta("pose", poses[i])
		men.append(s)


## Round B: a goods van to shoot at (bullet hits on metal). Returns the point on its side facing +X and that normal.
var van: Node3D


func place_van(at: Vector3) -> void:
	if van != null:
		van.queue_free()
	van = TrainParts.make("van")
	van.position = at
	add_child(van)


## A random point on the van's +X side (sparks fly out along +X).
func van_side_point(rng: RandomNumberGenerator) -> Vector3:
	return van.position + Vector3(1.42, rng.randf_range(1.3, 3.0), rng.randf_range(-3.0, 3.0))


func clear_men() -> void:
	for s in men:
		s.queue_free()
	men.clear()


## Sets off a blast at a ground point: a size 1-8, or a kind by name (BlastKinds.KINDS). Its crater is cut a moment
## later (the earth hides it); men near it are thrown. on_ground false: at is used as given (a hit on a wagon side).
func fire(what: Variant, at: Vector3, seed_value: int, st := -1, nrm := Vector3.UP, on_ground := true) -> Blast:
	if on_ground:
		at.y = ground.height(at.x, at.z)
	var b := Blast.new()
	b.auto = false
	add_child(b)
	# Under a heavy barrage new blasts are drawn with fewer particles (the shapes stay; the WW1 trick).
	var live := 0
	for e: Array in blasts:
		for c: int in (e[0] as Blast).spec["counts"]:
			live += c
	b.density = clampf(1.0 - float(live - 5000) / 14000.0, 0.4, 1.0)
	b.setup(what, at, seed_value, style if st < 0 else st, nrm)
	blasts.append([b, clock])
	if on_ground and float(b.spec["crater_r"]) > 0.0:
		craters.append([clock + float(b.spec.get("crater_t", 0.05)), at, float(b.spec["crater_r"]), float(b.spec["crater_d"])])
	throw_rng.seed = seed_value * 7 + 3
	for m in men:
		var busy := false
		for th in throws:
			busy = busy or th.man == m
		if busy or not is_instance_valid(m):
			continue
		var th := BlastThrow.make(m, b.spec, at, clock, throw_rng, ground.height, m.get_meta("pose", "aim"))
		if th != null:
			throws.append(th)
	return b


func clear_blasts() -> void:
	for e: Array in blasts:
		(e[0] as Blast).queue_free()
	blasts.clear()
	craters.clear()
	throws.clear()


func _process(delta: float) -> void:
	if not manual:
		step(clock + delta)


## Moves the clock to time c: every blast to its own age, the camera with its shake.
func step(c: float) -> void:
	clock = c
	var keep: Array = []
	for e: Array in blasts:
		var b: Blast = e[0]
		b.set_time(clock - float(e[1]))
		if b.done():
			b.queue_free()
		else:
			keep.append(e)
	blasts = keep
	var later: Array = []
	for cr: Array in craters:
		if clock >= float(cr[0]):
			# The test field's grid is 1.5 m, too coarse for a grenade's pit: small ones only scorch it.
			ground.crater(cr[1], cr[2], cr[3] if float(cr[2]) >= 1.2 else 0.0)
		else:
			later.append(cr)
	craters = later
	var going: Array[BlastThrow] = []
	for th in throws:
		if is_instance_valid(th.man) and th.step(clock):
			going.append(th)
	throws = going
	_place_cam()


func _place_cam() -> void:
	var dir := Vector3(cos(pitch) * sin(yaw), -sin(pitch), cos(pitch) * cos(yaw))
	var from := target + dir * dist
	var sh := Vector3.ZERO
	var rot := 0.0
	if shake_on:
		for e: Array in blasts:
			var b: Blast = e[0]
			var dd := from.distance_to(b.origin)
			var age := clock - float(e[1]) - dd / 340.0
			if age < 0.0:
				continue
			var amp := float(b.spec["shake"]) * exp(-age * 3.2) * clampf(60.0 / maxf(dd, 1.0), 0.0, 4.0)
			var ph := clock * 37.0 + float(e[1]) * 13.0
			sh += Vector3(sin(ph) + 0.5 * sin(ph * 2.3), sin(ph * 1.3 + 1.0), sin(ph * 0.9 + 2.0)) * amp
			rot += sin(ph * 1.7) * amp * 0.01
	sun.directional_shadow_max_distance = clampf(dist * 2.2, 150.0, 1400.0)
	cam.look_at_from_position(from + sh, target + sh * 0.6, Vector3.UP)
	cam.rotate_object_local(Vector3.FORWARD, rot)


## Points the camera (for the video tool): from a direction (yaw, pitch) at a distance.
func aim(at: Vector3, yaw_v: float, pitch_v: float, dist_v: float) -> void:
	target = at
	yaw = yaw_v
	pitch = pitch_v
	dist = dist_v
	_place_cam()
