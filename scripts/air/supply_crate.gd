class_name SupplyCrate
extends Node3D
## Iron Front: a supply container on its own parachute (Asset Builder Chat). Kinds and their colours:
## ammo (olive crate, yellow band, yellow chute), food (tan crate, blue-grey chute), medical (pale crate with a
## plain red band, white chute). It drops like a paratrooper but faster (6.5 m/s), lands with a bump and tips,
## and the chute lies down over the downwind side.

const KINDS := {
	"ammo": [Color(0.36, 0.40, 0.24), Color(0.85, 0.70, 0.18), Color(0.86, 0.72, 0.22)],
	"food": [Color(0.62, 0.52, 0.34), Color(0.30, 0.25, 0.18), Color(0.40, 0.48, 0.60)],
	"medical": [Color(0.84, 0.82, 0.76), Color(0.70, 0.12, 0.10), Color(0.92, 0.92, 0.90)],
}
const SINK := 6.5
const CONF := 2.2

var kind := "ammo"
var box: Node3D
var rig: MeshInstance3D
var canopy: Canopy
var vel := Vector3.ZERO
var t := 0.0
var open := 0.0
var state := "aboard"
var land_t := 0.0
var wind := Vector3(1.2, 0, 0.4)
var ground_y := 0.0


static func make(kind_name: String) -> SupplyCrate:
	var c := SupplyCrate.new()
	c.kind = kind_name
	c.name = "Crate_" + kind_name
	var cols: Array = KINDS[kind_name]
	c.box = Node3D.new()
	c.box.name = "Box"
	c.add_child(c.box)
	var g := TrainGeo.new()
	g.box(Vector3(0, 0.45, 0), Vector3(0.32, 0.45, 0.32), cols[0], Basis(), 0.04)
	g.box(Vector3(0, 0.62, 0), Vector3(0.335, 0.07, 0.335), cols[1])
	g.box(Vector3(0, 0.15, 0), Vector3(0.335, 0.03, 0.335), Color(0.2, 0.2, 0.2))
	g.box(Vector3(0, 0.92, 0), Vector3(0.06, 0.03, 0.06), AirParts.METAL)
	g.make(c.box, "Mesh", AirParts.material())
	var lg := TrainGeo.new()
	for sx: float in [-1.0, 1.0]:
		lg.cyl(Vector3(sx * 0.3, 0.92, sx * 0.3), Vector3(0, CONF, 0), 0.01, 3, Color(0.25, 0.24, 0.2))
		lg.cyl(Vector3(sx * 0.3, 0.92, -sx * 0.3), Vector3(0, CONF, 0), 0.01, 3, Color(0.25, 0.24, 0.2))
	c.rig = lg.make(c.box, "Rig", AirParts.material())
	c.canopy = Canopy.make(cols[2], 2.4, 12)
	c.canopy.position = Vector3(0, CONF, 0)
	c.add_child(c.canopy)
	c.canopy.visible = false
	return c


func drop(v: Vector3) -> void:
	state = "fall"
	vel = v
	t = 0.0


func step(dt: float) -> void:
	if state == "aboard" or state == "done":
		return
	t += dt
	if state == "fall":
		if t > 0.7:
			canopy.visible = true
			open = move_toward(open, 1.0, dt / 0.8)
		var cd := lerpf(0.004, 9.81 / (SINK * SINK), open * open)
		var rel := vel - wind
		rel -= rel * rel.length() * cd * dt
		rel.y -= 9.81 * dt
		vel = rel + wind
		position += vel * dt
		canopy.shape(open)
		box.rotation = Vector3(sin(t * 1.7) * 0.12 * open, 0, sin(t * 1.3) * 0.12 * open)
		if position.y <= ground_y:
			position.y = ground_y
			state = "land"
			land_t = t
	elif state == "land":
		var s := t - land_t
		# a bump, then it tips onto its side a little; the chute lies down downwind
		box.rotation = Vector3(0, 0, lerpf(0.0, 0.32, smoothstep(0.0, 0.5, s)))
		box.position.y = absf(sin(minf(s, 0.4) / 0.4 * PI)) * 0.15
		var c := smoothstep(0.0, 1.8, s)
		var down := wind.normalized()
		canopy.rotation = Vector3(0, atan2(-down.x, -down.z), 0)
		canopy.position = Vector3(0, CONF * (1.0 - c) + 0.05, 0) + down * c * 0.4
		canopy.shape(1.0, c)
		rig.visible = c < 0.4
		if s > 2.0:
			state = "done"
