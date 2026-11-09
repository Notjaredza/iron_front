class_name TrainCar
extends Node3D
## Iron Front: one car of a train (engine, tender or wagon). Forward is -Z. The origin sits on the track centre at
## rail-top height, so y = 0 is the rail top. Built by TrainParts; moved by Train.
##
## Moving parts (all plain nodes, so Animations can key them):
## - wheelsets turn with the distance run (roll());
## - on the engine, the coupling rods, connecting rods, crossheads and piston rods follow the driving wheels;
## - buffer heads slide in when the gap to the next car closes (set_buffers());
## - van doors slide (set_doors()); the gun mount turns, the cradle lifts, the barrel recoils (aim(), recoil()).

const NEAR_END := 320.0          # near look drawn up to this distance; the far look from there on

var kind := ""
var front_z := -3.0              # buffer face at the front (negative)
var rear_z := 3.0                # buffer face at the back
var pivot_f := -2.0              # where the car sits on the track: front and rear support points (z)
var pivot_r := 2.0
var mass := 20000.0
var col_box := AABB(Vector3(-1.3, 0.0, -3.0), Vector3(2.6, 3.6, 6.0))   # crash collision box (car local)
var com_y := 1.5                 # centre of mass height for crashes

var body: Node3D                 # every static part, as separate MeshInstances (so a blast can throw them)
var far: MeshInstance3D
var wheels: Array[Node3D] = []
var wheel_r: Array[float] = []
var drivers: Array[int] = []     # indices into wheels that carry the rods (engine)
var rods := {}                   # side (+1 / -1) -> {"coupling", "conn", "cross", "piston"}
var crank := 0.3
var conn_len := 2.6
var cyl_y := 0.72
var buffers: Array[Node3D] = []  # front left, front right, rear left, rear right
var doors: Array[Node3D] = []
var door_open_z := -1.65
var gun_mount: Node3D
var gun_cradle: Node3D
var gun_barrel: Node3D
var marks := {}                  # name -> Vector3 (car local): chimney, whistle, cock_l, cock_r, fire, ...

var _wheel_angle := 0.0


func hook_front() -> Vector3:
	return Vector3(0, 1.05, front_z + 0.08)


func hook_rear() -> Vector3:
	return Vector3(0, 1.05, rear_z - 0.08)


func length() -> float:
	return rear_z - front_z


## Turns the wheels by the distance run forward (metres; negative runs backward), and moves the rods.
func roll(dist: float) -> void:
	_wheel_angle += dist
	for i in wheels.size():
		wheels[i].rotation = Vector3(-_wheel_angle / wheel_r[i], 0, 0)
	if drivers.is_empty():
		return
	var r: float = wheel_r[drivers[0]]
	var a := -_wheel_angle / r
	var mid: Node3D = wheels[drivers[drivers.size() / 2]]
	for side: int in rods.keys():
		var set_: Dictionary = rods[side]
		var phase := a + (0.0 if side > 0 else PI * 0.5)
		var off := Basis(Vector3.RIGHT, phase) * Vector3(0, 0, crank)
		var pin := mid.position + off
		var c: Node3D = set_["coupling"]
		c.position = Vector3(c.position.x, mid.position.y + off.y, mid.position.z + off.z)
		# the crosshead slides on the cylinder line, in front of the driving pin
		var dy := pin.y - cyl_y
		var cz := pin.z - sqrt(maxf(conn_len * conn_len - dy * dy, 0.01))
		var cross: Node3D = set_["cross"]
		cross.position = Vector3(cross.position.x, cyl_y, cz)
		var conn: Node3D = set_["conn"]
		conn.position = Vector3(conn.position.x, cyl_y, cz)
		conn.rotation = Vector3(-atan2(dy, pin.z - cz), 0, 0)
		var piston: Node3D = set_["piston"]
		piston.position = Vector3(piston.position.x, cyl_y, cz)


## Buffer heads pushed in by c metres (0 = free, up to about 0.12) at each end.
func set_buffers(front_c: float, rear_c: float) -> void:
	if buffers.size() < 4:
		return
	for i in 2:
		buffers[i].position.z = front_z + clampf(front_c, 0.0, 0.14)
		buffers[i + 2].position.z = rear_z - clampf(rear_c, 0.0, 0.14)


## Doors open by t (0 shut .. 1 fully open).
func set_doors(t: float) -> void:
	var e := t * t * (3.0 - 2.0 * t)
	for d in doors:
		d.position.z = lerpf(0.0, door_open_z, e)


## Gun: turn (yaw, radians, 0 = straight ahead) and lift (pitch, radians).
func aim(yaw: float, pitch: float) -> void:
	if gun_mount == null:
		return
	gun_mount.rotation = Vector3(0, yaw, 0)
	gun_cradle.rotation = Vector3(pitch, 0, 0)


## Barrel recoil at time t after firing (seconds): fast back, slow run out.
func recoil(t: float) -> void:
	if gun_barrel == null:
		return
	var back := 0.0
	if t >= 0.0 and t < 0.06:
		back = t / 0.06
	elif t >= 0.06 and t < 1.0:
		var u := (t - 0.06) / 0.94
		back = 1.0 - u * u * (3.0 - 2.0 * u)
	gun_barrel.position.z = 0.55 * back


## Splits near and far looks by distance.
func finish_lod() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == far:
			mi.visibility_range_begin = NEAR_END
			mi.visibility_range_begin_margin = 20.0
		else:
			mi.visibility_range_end = NEAR_END
			mi.visibility_range_end_margin = 20.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func tri_count(near := true) -> int:
	var n := 0
	for c in find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if (mi == far) == near or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			n += mi.mesh.surface_get_array_len(s) / 3
	return n
