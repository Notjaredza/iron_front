class_name Lorry
extends Node3D
## The troop lorry as a scene node (Question Chat, 2026-11-09): the sprung body (cab, bed,
## tilt), four wheel stations that turn and steer and follow the ground, the tailgate. The
## squad rides as children of `body` at the seats below. Other vehicles can copy this
## shape: a body pivot, wheel stations, moving parts, seats.
##
## Per frame: drive(dist, steer) turns the wheels; ride(ground_fn, dt) puts each wheel on the
## ground and lets the body follow on soft springs; set_tailgate(open 0..1).

const L := preload("res://scripts/vehicles/lorry_builder.gd")
const MG := preload("res://scripts/units/mg_builder.gd")

## The twelve seats (body frame): position on the bed floor under the man's hips, and his yaw.
## Left bench first (front to back) facing in (+X), then the right bench facing in (-X).
static var SEATS: Array = []

var lod := 0
var wreck := false
var body: Node3D
var tailgate: Node3D
var wheels: Array = []  # {node, pos, front, side}
var spring := {"heave": 0.0, "pitch": 0.0, "roll": 0.0, "vh": 0.0, "vp": 0.0, "vr": 0.0}
var spin := 0.0


static func seats() -> Array:
	if SEATS.is_empty():
		for side in [-1, 1]:
			for k in 6:
				var z := -0.82 + 0.6 * k
				SEATS.append({"pos": Vector3(L.BENCH_X * side, L.FLOOR_Y, z), "yaw": -PI / 2 if side < 0 else PI / 2})
	return SEATS


func setup(lod_level := 0, burnt := false, tilt := true, benches := true) -> Lorry:
	lod = lod_level
	wreck = burnt
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var bm := MeshInstance3D.new()
	bm.mesh = MG.mesh(L.body(lod, wreck, tilt, benches))
	body.add_child(bm)
	tailgate = Node3D.new()
	tailgate.position = L.TAILGATE_HINGE
	body.add_child(tailgate)
	var tm := MeshInstance3D.new()
	tm.mesh = MG.mesh(L.tailgate(lod, wreck))
	tailgate.add_child(tm)
	var front := MG.mesh(L.wheel(lod, false, wreck))
	var rear := MG.mesh(L.wheel(lod, true, wreck))
	for st in [[L.FRONT_X, L.FRONT_Z, true], [-L.FRONT_X, L.FRONT_Z, true], [L.REAR_X, L.REAR_Z, false], [-L.REAR_X, L.REAR_Z, false]]:
		var n := Node3D.new()
		var pos := Vector3(st[0], L.WHEEL_R, st[1])
		n.position = pos
		add_child(n)
		var m := MeshInstance3D.new()
		m.mesh = front if st[2] else rear
		n.add_child(m)
		wheels.append({"node": n, "mesh": m, "pos": pos, "front": st[2], "side": signf(st[0])})
	return self


func tri_count() -> int:
	return L.body(lod, wreck).tri_count() + L.tailgate(lod, wreck).tri_count() + 2 * L.wheel(lod, false, wreck).tri_count() \
		+ 2 * L.wheel(lod, true, wreck).tri_count()


## Wheels turned by the distance driven; the front pair steered (radians, + = left).
func drive(dist: float, steer := 0.0) -> void:
	spin = -dist / L.WHEEL_R
	for w: Dictionary in wheels:
		var b := Basis(Vector3.UP, steer) if w["front"] else Basis()
		var m: MeshInstance3D = w["mesh"]
		(w["node"] as Node3D).basis = b
		m.basis = Basis(Vector3.RIGHT, spin)


## Puts each wheel on the ground (ground_fn: world Vector3 -> height) and lets the body
## follow on springs. dt = seconds since the last call (0 = snap to rest).
func ride(ground_fn: Callable, dt: float, shake := 0.0) -> void:
	var h := []
	for w: Dictionary in wheels:
		var wp: Vector3 = global_transform * Vector3((w["pos"] as Vector3).x, 0, (w["pos"] as Vector3).z)
		var gy: float = ground_fn.call(wp)
		(w["node"] as Node3D).position.y = L.WHEEL_R + gy
		h.append(gy)
	var front: float = (h[0] + h[1]) * 0.5
	var rear: float = (h[2] + h[3]) * 0.5
	var left: float = (h[1] + h[3]) * 0.5
	var right: float = (h[0] + h[2]) * 0.5
	var target := {"heave": (front + rear) * 0.5, "pitch": atan2(front - rear, L.REAR_Z - L.FRONT_Z),
		"roll": atan2(left - right, L.FRONT_X * 2.0)}
	for k in ["heave", "pitch", "roll"]:
		var vk: String = {"heave": "vh", "pitch": "vp", "roll": "vr"}[k]
		if dt <= 0.0:
			spring[k] = target[k]
			spring[vk] = 0.0
			continue
		# A soft, under-damped spring: the body lags the wheels and rocks a little after a bump.
		var w0 := 9.0
		var zeta := 0.45
		var a: float = w0 * w0 * (float(target[k]) - float(spring[k])) - 2.0 * zeta * w0 * float(spring[vk])
		spring[vk] = float(spring[vk]) + a * dt
		spring[k] = float(spring[k]) + float(spring[vk]) * dt
	var b := Basis(Vector3.RIGHT, float(spring["pitch"])) * Basis(Vector3.BACK, -float(spring["roll"]))
	body.transform = Transform3D(b, Vector3(0, float(spring["heave"]) + shake, 0))


func set_tailgate(open: float) -> void:
	tailgate.basis = Basis(Vector3.RIGHT, PI * 0.97 * clampf(open, 0.0, 1.0))
