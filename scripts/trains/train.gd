class_name Train
extends Node3D
## Iron Front: a train of cars on a TrackPath.
##
## Running: the engine pulls with a tractive force towards target_speed, all cars brake together. Each car runs
## its own distance along the line, and the gaps between cars follow coupling slack and buffer springs, so the
## train bunches up when it brakes and stretches when it starts. Cars are placed on the line from their two
## support points, the wheels and rods turn with the distance run, the buffers squash, and the chimney puffs on
## each exhaust beat (four per driving wheel turn), harder when pulling.
##
## Crashing: crash(name) plays a baked crash Animation from TrainCrashes (made by CrashBaker). The Animation
## moves the cars (and, for the blast, the engine's parts); this script keeps the wheels, couplings, smoke, dust
## and fire going from what the cars actually do.

const SLACK := 0.16              # coupling slack (m): free play before the chain pulls tight
const BUFFER_TRAVEL := 0.12
const K_BUFFER := 2.2e6          # N/m
const K_CHAIN := 9.0e6
const SUBSTEPS := 8

@export var fire_level := 0.0    # driven by the crash Animations: 0 none .. 1 fully ablaze
@export var crash_time := -1.0   # time in the crash clip when the crash starts (cars leave the rails)

var path: TrackPath
var cars: Array[TrainCar] = []
var d: Array[float] = []         # car centre distance along the path
var v: Array[float] = []
var target_speed := 0.0
var max_force := 160000.0        # N at the rails
var brake_decel := 1.4           # m/s2 with all cars braking
var effort := 0.0                # 0..1 how hard the engine is pulling (smoke)
var smoke: Puffs
var fire: Puffs
var links: Array[MeshInstance3D] = []
var player: AnimationPlayer
var crashing := false
var crash_cars := 0              # how many cars the crash clip moves

var _beat_d := 0.0
var _idle_t := 0.0
var _whistle_t := 0.0
var _clip_t := 0.0
var _prev_xf: Array[Transform3D] = []
var _rng := RandomNumberGenerator.new()


## Builds a train of the given car kinds (front first) with its front buffer face at distance front_d.
static func make(kinds: Array, on: TrackPath, front_d: float, seed_value := 1) -> Train:
	var t := Train.new()
	t.name = "Train"
	t.path = on
	t._rng.seed = seed_value
	var at := front_d
	for k: String in kinds:
		var c := TrainParts.make(k)
		c.name = "Car%d" % t.cars.size()
		t.add_child(c)
		var dc := at + c.front_z
		t.cars.append(c)
		t.d.append(dc)
		t.v.append(0.0)
		at = dc - c.rear_z
	for i in range(1, t.cars.size()):
		var l := MeshInstance3D.new()
		l.name = "Link%d" % i
		var g := TrainGeo.new()
		g.box(Vector3(0, 0, 0), Vector3(0.05, 0.05, 0.5), TrainParts.BLACK)
		l.mesh = g.to_mesh(TrainParts.material())
		t.add_child(l)
		t.links.append(l)
	t.smoke = Puffs.make(false, seed_value)
	t.smoke.name = "Smoke"
	t.add_child(t.smoke)
	t.fire = Puffs.make(true, seed_value + 7)
	t.fire.name = "Fire"
	t.add_child(t.fire)
	t.player = AnimationPlayer.new()
	t.player.name = "Player"
	t.add_child(t.player)
	t.place()
	return t


func speed() -> float:
	return v[0] if not v.is_empty() else 0.0


func whistle(seconds: float) -> void:
	_whistle_t = seconds


## Places every car on the line from its distance (running mode).
func place() -> void:
	for i in cars.size():
		cars[i].transform = path.car_frame(d[i], cars[i])
	if is_inside_tree():
		_update_links()


func _ready() -> void:
	place()


func _process(dt: float) -> void:
	if crashing:
		_crash_step(dt)
	else:
		_run_step(dt)
	_effects(dt)
	smoke.step(dt)
	fire.step(dt)


# ------------------------------------------------------------------ running

func _run_step(dt: float) -> void:
	var n := cars.size()
	var before := d.duplicate()
	var h := dt / float(SUBSTEPS)
	var braking := target_speed < v[0] - 0.3
	effort = 0.0
	for _s in SUBSTEPS:
		var f: Array[float] = []
		f.resize(n)
		for i in n:
			f[i] = 0.0
		# engine pull
		var want := (target_speed - v[0]) * 60000.0
		var pull := clampf(want, 0.0, max_force)
		f[0] += pull
		effort = maxf(effort, pull / max_force)
		# brakes: like WW1 goods trains, only the engine and tender brake, so the unbraked wagons run in
		# against them and the buffers squash. Together they stop the whole train at brake_decel.
		var total := 0.0
		var braked := 0.0
		for i in n:
			total += cars[i].mass
			if i < 2:
				braked += cars[i].mass
		for i in n:
			if (braking or target_speed <= 0.01) and i < 2:
				var bf := brake_decel * total * cars[i].mass / braked
				if absf(v[i]) > 0.02:
					f[i] -= signf(v[i]) * bf
			# rolling resistance
			f[i] -= v[i] * 40.0 * (cars[i].mass / 1000.0) * 0.05
		# couplings and buffers between car i-1 (ahead) and car i
		for i in range(1, n):
			var gap := _gap(i)
			var rel := v[i - 1] - v[i]   # gap opening speed
			var m := minf(cars[i].mass, cars[i - 1].mass)
			var force := 0.0
			if gap < 0.0:
				force = -K_BUFFER * gap - 2.0 * 0.4 * sqrt(K_BUFFER * m) * rel
				force = maxf(force, 0.0)
				force = -force                # pushes them apart: ahead car forward, this car back
			elif gap > SLACK:
				force = K_CHAIN * (gap - SLACK) + 2.0 * 0.4 * sqrt(K_CHAIN * m) * rel
				force = maxf(force, 0.0)      # pulls them together: ahead car back, this car forward
			f[i - 1] -= force
			f[i] += force
		for i in n:
			var nv := v[i] + f[i] / cars[i].mass * h
			if target_speed <= 0.01 and absf(v[i]) <= 0.02 and absf(f[i]) / cars[i].mass < brake_decel:
				nv = 0.0
			v[i] = nv
			d[i] += v[i] * h
	for i in n:
		cars[i].transform = path.car_frame(d[i], cars[i])
		cars[i].roll(d[i] - float(before[i]))
	for i in range(n):
		var front_c := 0.0
		var rear_c := 0.0
		if i > 0:
			front_c = maxf(-_gap(i), 0.0) * 0.5
		if i < n - 1:
			rear_c = maxf(-_gap(i + 1), 0.0) * 0.5
		cars[i].set_buffers(front_c, rear_c)
	_update_links()
	# chimney beats
	var eng := cars[0]
	if not eng.drivers.is_empty():
		var beat := TAU * eng.wheel_r[eng.drivers[0]] / 4.0
		_beat_d += absf(d[0] - float(before[0]))
		while _beat_d >= beat:
			_beat_d -= beat
			_chuff(eng)


## The gap between car i-1's back buffers and car i's front buffers (negative = buffers squashed).
func _gap(i: int) -> float:
	var rear_face := d[i - 1] - cars[i - 1].rear_z
	var front_face := d[i] - cars[i].front_z
	return rear_face - front_face


func _chuff(eng: TrainCar) -> void:
	var at := eng.to_global(eng.marks["chimney"])
	var fwd := -eng.global_basis.z
	var up := 2.5 + 6.0 * effort
	var sz := 0.6 + 0.9 * effort
	smoke.add("smoke", at, Vector3(0, up, 0) + fwd * v[0] * 0.3 + smoke.jitter(0.4), sz)
	# open cylinder cocks while starting
	if v[0] < 3.0 and effort > 0.3:
		for side: String in ["cock_l", "cock_r"]:
			var p := eng.to_global(eng.marks[side])
			var out := eng.global_basis.x * (1.0 if side == "cock_r" else -1.0)
			smoke.add("steam", p, out * 3.5 + Vector3(0, 0.6, 0) + smoke.jitter(0.5), 1.0)


func _update_links() -> void:
	for i in range(1, cars.size()):
		var a := cars[i - 1].to_global(cars[i - 1].hook_rear())
		var b := cars[i].to_global(cars[i].hook_front())
		var l := links[i - 1]
		var gap := a.distance_to(b)
		if gap > 1.5:
			l.visible = false          # broken coupling
			continue
		l.visible = true
		var mid := (a + b) * 0.5 + Vector3(0, -0.06 * clampf(1.0 - gap * 2.0, 0.0, 1.0), 0)
		var dir := (b - a)
		if dir.length() < 0.01:
			dir = cars[i].global_basis.z
		l.global_transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), mid).scaled_local(
			Vector3(1, 1, maxf(gap + 0.24, 0.3)))


# ------------------------------------------------------------------ effects

func _effects(dt: float) -> void:
	var eng := cars[0]
	var blown := crashing and fire_level > 0.0 and _is_blast()
	# idle wisp
	_idle_t += dt
	if not blown and _idle_t > 0.5 and absf(speed()) < 0.5 and not crashing:
		_idle_t = 0.0
		smoke.add("smoke", eng.to_global(eng.marks["chimney"]), Vector3(0, 1.6, 0) + smoke.jitter(0.2), 0.45)
	if _whistle_t > 0.0 and not blown:
		_whistle_t -= dt
		smoke.add("steam", eng.to_global(eng.marks["whistle"]), Vector3(0, 4.5, 0) + smoke.jitter(0.4), 0.8)
	if fire_level > 0.01:
		# the engine wreck and tender burn hardest, the first wagon catches, the rest only smoulder
		for i in mini(cars.size(), 3):
			var c := cars[i]
			var heat: float = fire_level * [1.0, 0.8, 0.45][i]
			var at := c.to_global(c.marks["fire"])
			if _rng.randf() < heat * 0.9:
				fire.add("flame", at + fire.jitter(0.9), Vector3(0, 2.0, 0) + fire.jitter(0.6), 0.8 + heat)
			if _rng.randf() < heat * 0.25:
				smoke.add("burn", at + Vector3(0, 1.0, 0) + smoke.jitter(0.6), Vector3(0, 3.0, 0) + smoke.jitter(0.5), 0.6 + heat * 0.6)


func _is_blast() -> bool:
	return player.current_animation.begins_with("blast")


# ------------------------------------------------------------------ crashes

## Plays a baked crash clip from the library. The train root is put where the clip's start was baked: the
## caller moves the Train node so the crash happens where it should.
func crash(clip: String) -> void:
	crashing = true
	_prev_xf.clear()
	for i in cars.size():
		_prev_xf.append(cars[i].global_transform)
		v[i] = TrainCrashes.SPEED
	player.play(clip)
	_clip_t = 0.0


func _crash_step(dt: float) -> void:
	_clip_t += dt
	for i in cars.size():
		var c := cars[i]
		var xf := c.global_transform
		var prev: Transform3D = _prev_xf[i]
		var moved := xf.origin - prev.origin
		var spd := moved.length() / maxf(dt, 1e-4)
		var upright := xf.basis.y.dot(Vector3.UP)
		# wheels: turn with the run while the car still sits on its wheels
		if upright > 0.85:
			c.roll(moved.dot(-xf.basis.z))
		# dust where a car slides off the line
		var off_line := xf.origin.y < to_global(Vector3.ZERO).y - 0.08 or upright < 0.97
		if off_line and spd > 1.5 and _rng.randf() < clampf(spd / 10.0, 0.0, 1.0):
			var base := xf.origin + xf.basis.x * _rng.randf_range(-1.2, 1.2) + xf.basis.z * _rng.randf_range(-2.5, 2.5)
			smoke.add("dust", Vector3(base.x, to_global(Vector3.ZERO).y - 0.3, base.z), Vector3(0, 1.2, 0) + smoke.jitter(1.2) - moved.normalized() * 1.5, 1.0 + spd * 0.08)
		_prev_xf[i] = xf
	_update_links()
	# the engine keeps puffing slowly if it is not blown up
	if not _is_blast() and _clip_t < crash_time:
		var eng := cars[0]
		var beat := TAU * eng.wheel_r[eng.drivers[0]] / 4.0
		_beat_d += TrainCrashes.SPEED * dt
		while _beat_d >= beat:
			_beat_d -= beat
			effort = 0.6
			_chuff(eng)
