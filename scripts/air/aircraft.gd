class_name Aircraft
extends Node3D
## Iron Front: one biplane (fighter, spotter or bomber) with its moving parts (Asset Builder Chat).
## Built by AirParts.make(kind). Forward is -Z. The origin is the centre of gravity.
##
## Moving parts:
## - props: spin(dt) turns them at rpm; above BLUR_RPM the blades hide and the blur disc shows;
## - set_surfaces(roll, pitch, yaw): ailerons, elevator and rudder, each -1..1;
## - aim_gunner(i, yaw, pitch): ring i turns, its gun lifts;
## - roll_wheels(dist): wheels turn with the distance run on the ground;
## - flash(): muzzle flash on the guns that fired this frame;
## - fly_pose(...) / ground_pose(...): place the plane from a flight state or on the ground.
## Exported fire_level (0 none, 1 smoking, 2 burning) and crash_time drive the effects from baked clips.

const NEAR_END := 450.0
const BLUR_RPM := 350.0
const SURF_MAX := 0.42          # control surface throw, radians

var kind := ""
var spec: Dictionary = {}
var mass := 1000.0
var cruise := 40.0
var stall := 20.0
var groups: Dictionary = {}
var props: Array[Node3D] = []
var blurs: Array[MeshInstance3D] = []
var ailerons: Array[Node3D] = []
var aileron_side: Array[float] = []
var elevator: Node3D
var rudders: Array[Node3D] = []
var wheels: Array[Node3D] = []
var wheel_r := 0.35
var rings: Array[Node3D] = []
var ring_guns: Array[Node3D] = []
var bombs: Array[Node3D] = []
var muzzles: Array[Vector3] = []
var flashes: Array[MeshInstance3D] = []
var marks: Dictionary = {}
var far: MeshInstance3D
var sit_pitch := 0.0
var gear_low := -1.0
var gear_z := 0.0
var skid := Vector3.ZERO

var rpm := 0.0
var _prop_angle := 0.0
var _flash_t := 0.0

@export var fire_level := 0.0
@export var crash_time := -1.0

static var _flash_mat: StandardMaterial3D


func finish() -> void:
	# muzzle flashes: fixed guns at their muzzles, ring guns at the barrel ends
	for p in muzzles:
		flashes.append(_flash_at(groups["Fuselage"], p))
	for g in ring_guns:
		flashes.append(_flash_at(g, Vector3(0, 0, -0.85)))
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi == far:
			mi.visibility_range_begin = NEAR_END
			mi.visibility_range_begin_margin = 30.0
		elif not flashes.has(mi):
			mi.visibility_range_end = NEAR_END
			mi.visibility_range_end_margin = 30.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	spin(0.0)


func _flash_at(parent: Node3D, at: Vector3) -> MeshInstance3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.vertex_color_use_as_albedo = true
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var g := TrainGeo.new()
	var hot := Color(1.0, 0.85, 0.4, 0.95)
	for k in 4:
		var b := Basis(Vector3(0, 0, 1), PI * 0.25 * float(k))
		g.emit(Vector3.ZERO, b * Vector3(0.07, 0, -0.1), Vector3(0, 0, -0.42), hot)
		g.emit(Vector3.ZERO, b * Vector3(-0.07, 0, -0.1), Vector3(0, 0, -0.42), hot)
	g.lump(Vector3(0, 0, -0.08), 0.08, Color(1.0, 0.95, 0.7, 1.0))
	var mi := g.make(parent, "Flash", _flash_mat, Transform3D(Basis(), at))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


## Turns the propellers at the current rpm.
func spin(dt: float) -> void:
	_prop_angle = fmod(_prop_angle + rpm / 60.0 * TAU * dt, TAU)
	var fast := rpm > BLUR_RPM
	for i in props.size():
		var dir := 1.0 if i % 2 == 0 else -1.0
		props[i].rotation.z = _prop_angle * dir
		# at speed the blades become a faint blur; a glimpse of a blade every few frames keeps it alive
		props[i].visible = not fast or fmod(_prop_angle * 3.0, TAU) < 0.9
		blurs[i].visible = rpm > BLUR_RPM * 0.6
		blurs[i].transparency = clampf(1.0 - (rpm - BLUR_RPM * 0.6) / (BLUR_RPM * 1.5), 0.35, 1.0)


## roll_in > 0 rolls right (right wing down), pitch_in > 0 pulls the nose up, yaw_in > 0 swings the nose right.
func set_surfaces(roll_in: float, pitch_in: float, yaw_in: float) -> void:
	for i in ailerons.size():
		ailerons[i].rotation.x = -clampf(roll_in, -1.0, 1.0) * SURF_MAX * aileron_side[i]
	if elevator:
		elevator.rotation.x = -clampf(pitch_in, -1.0, 1.0) * SURF_MAX
	for r in rudders:
		r.rotation.y = clampf(yaw_in, -1.0, 1.0) * SURF_MAX


func aim_gunner(i: int, yaw: float, pitch: float) -> void:
	if i < rings.size():
		rings[i].rotation.y = yaw
		ring_guns[i].rotation.x = clampf(pitch, -0.35, 1.2)


func roll_wheels(dist: float) -> void:
	for w in wheels:
		w.rotation.x = -dist / wheel_r


## Shows the muzzle flash on the listed guns (fixed guns first, then ring guns) for one frame or so.
func flash(which: Array, on: bool) -> void:
	for i in flashes.size():
		flashes[i].visible = on and which.has(i)
		if flashes[i].visible:
			flashes[i].rotation.z = randf() * TAU
			flashes[i].scale = Vector3.ONE * randf_range(0.8, 1.3)


## World position of gun i's muzzle (fixed guns first, then ring guns).
func muzzle(i: int) -> Vector3:
	return flashes[i].global_position


## Forward direction of gun i.
func muzzle_dir(i: int) -> Vector3:
	return -flashes[i].global_transform.basis.z.normalized()


## Places the plane from a flight state: heading (radians, 0 = -Z, positive turns left), climb angle, bank (right wing down > 0).
func fly_pose(at: Vector3, heading: float, climb: float, bank: float) -> void:
	transform = Transform3D(attitude(heading, climb, bank), at)


static func attitude(heading: float, climb: float, bank: float) -> Basis:
	return Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, climb) * Basis(Vector3(0, 0, 1), -bank)


## The origin height and nose-up pitch that put the wheels (and the tail skid, tail_up 0) on ground height h.
func ground_pitch(tail_up: float) -> float:
	return sit_pitch * (1.0 - clampf(tail_up, 0.0, 1.0))


func ground_height(h: float, pitch: float) -> float:
	var axle_y := gear_low + wheel_r
	var wy := axle_y * cos(pitch) - gear_z * sin(pitch)
	var sy := skid.y * cos(pitch) - skid.z * sin(pitch)
	return h - minf(wy - wheel_r, sy)


func ground_pose(at_xz: Vector3, h: float, heading: float, tail_up: float, extra_pitch := 0.0) -> void:
	var p := ground_pitch(tail_up) + extra_pitch
	var y := ground_height(h, p)
	transform = Transform3D(attitude(heading, p, 0.0), Vector3(at_xz.x, y, at_xz.z))


## Bomb i leaves its rack: it is moved to the parent (world) keeping where it was. Returns the bomb node.
func release_bomb(i: int, world: Node3D) -> Node3D:
	var b := bombs[i]
	var xf := b.global_transform
	b.get_parent().remove_child(b)
	world.add_child(b)
	b.global_transform = xf
	return b


func tri_count(near := true) -> int:
	var n := 0
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if (mi == far) != near and mi.mesh and not flashes.has(mi) and not blurs.has(mi):
			n += mi.mesh.get_faces().size() / 3
	return n


# ------------------------------------------------------------------ flying (kinematic, for scripted moves)
# The state: heading (0 = -Z, positive turns left), climb (flight path angle), bank (right wing down > 0),
# speed (m/s). The body is pitched by climb plus an angle of attack that grows as the speed falls to the stall,
# so a slow plane flies nose-high and lands on three points.

const G := 9.81

var heading := 0.0
var climb := 0.0
var bank := 0.0
var speed := 0.0
var on_ground := true
var tail_up := 0.0
var rotate_k := 0.0          # take-off: 0..1 lifting the nose for lift-off
var landed := false          # after touching down the tail stays down
var dist_run := 0.0
var throttle := 0.0
var engine_on := false


func aoa() -> float:
	return sit_pitch * 0.85 * clampf((cruise - speed) / maxf(cruise - stall, 1.0), 0.0, 1.0)


func velocity() -> Vector3:
	return Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, climb) * Vector3(0, 0, -speed)


func _engine(dt: float) -> void:
	var want := 0.0
	if engine_on:
		want = lerpf(520.0, 1400.0, throttle)
	rpm = move_toward(rpm, want, (900.0 if engine_on else 350.0) * dt)
	spin(dt)


## Flies one step: turn rate (rad/s, positive left), climb rate (m/s), target speed.
func fly(dt: float, turn: float, climb_rate: float, target_speed: float) -> void:
	on_ground = false
	throttle = clampf(0.55 + climb_rate * 0.08 + (target_speed - speed) * 0.05, 0.2, 1.0)
	speed = move_toward(speed, target_speed, 5.0 * dt)
	var want_bank := -atan(speed * turn / G)
	want_bank = clampf(want_bank, -1.3, 1.3)
	var old_bank := bank
	bank = move_toward(bank, want_bank, 1.4 * dt)
	var turn_now := -G * tan(bank) / maxf(speed, 5.0)
	heading += turn_now * dt
	var want_climb := asin(clampf(climb_rate / maxf(speed, 5.0), -0.95, 0.95))
	var old_climb := climb
	climb = move_toward(climb, want_climb, 0.45 * dt)
	position += velocity() * dt
	var p := climb + aoa()
	transform = Transform3D(attitude(heading, p, bank), position)
	# the stick and rudder lead the motion
	var roll_rate := (bank - old_bank) / maxf(dt, 1e-4)
	set_surfaces((want_bank - bank) * 2.5 + roll_rate * 0.3, (want_climb - climb) * 4.0 + absf(bank) * 0.4,
		-turn * 0.8)
	_engine(dt)


## On the ground: roll at a target speed with a steer rate (rad/s, positive left), h = ground height.
## take_off lets it lift off at the stall speed and climb away.
func roll_ground(dt: float, target_speed: float, steer: float, h := 0.0, take_off := false) -> void:
	on_ground = true
	throttle = clampf(0.3 + (target_speed - speed) * 0.1, 0.1, 1.0)
	var acc := 4.5 if target_speed > speed else 3.0
	speed = move_toward(speed, target_speed, acc * dt)
	heading += steer * dt * clampf(speed / 4.0, 0.0, 1.0)
	climb = 0.0
	bank = 0.0
	dist_run += speed * dt
	roll_wheels(dist_run)
	if landed:
		tail_up = 0.0
	else:
		tail_up = smoothstep(stall * 0.3, stall * 0.65, speed)
	if take_off:
		rotate_k = smoothstep(stall * 0.85, stall * 1.0, speed)
	var p := lerpf(ground_pitch(tail_up), aoa(), rotate_k)
	var fwd := Basis(Vector3.UP, heading) * Vector3(0, 0, -1)
	position += fwd * speed * dt
	var y := ground_height(h, p)
	if take_off and speed >= stall * 1.02:
		on_ground = false
		climb = 0.04
		y = position.y if position.y > y else y
	transform = Transform3D(attitude(heading, p, 0.0), Vector3(position.x, y, position.z))
	set_surfaces(0.0, 0.6 if speed < stall * 0.3 else -0.3 * (1.0 - rotate_k) + 0.5 * rotate_k, -steer * 1.5)
	_engine(dt)


## Flying down to land: glides at a slope towards height h; returns true once the wheels touch.
func approach(dt: float, h: float, glide := 0.07, target_speed := -1.0) -> bool:
	var ts := target_speed if target_speed > 0.0 else stall * 1.05
	var above := position.y - ground_height(h, climb + aoa())
	var rate := -speed * glide
	if above < 4.0:
		rate = lerpf(-0.6, rate, clampf(above / 4.0, 0.0, 1.0))        # the flare
	fly(dt, 0.0, rate, ts)
	throttle = 0.15
	var p := climb + aoa()
	if position.y <= ground_height(h, p) + 0.02:
		landed = true
		on_ground = true
		position.y = ground_height(h, p)
		return true
	return false
