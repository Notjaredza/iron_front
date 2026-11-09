class_name FieldGun
extends Node3D
## The light field gun as a scene node (Question Chat, 2026-11-09). Built the same way as
## the Lorry: one pivot per moving part, so a crew can work it and a lorry can tow it.
##   carriage   pivots about the axle: lift(a) raises the trail end (a > 0) for towing and handling
##   cradle     elevation (degrees, + = muzzle up)
##   barrel     recoil (metres back along the cradle)
##   block      breech open 0..1
##   handwheel  turned by the layer as the elevation changes
##   wheels     roll(dl, dr) turns each wheel by the ground it covered

const G := preload("res://scripts/vehicles/field_gun_builder.gd")
const MG := preload("res://scripts/units/mg_builder.gd")

var lod := 0
var wreck := false
var carriage: Node3D
var cradle: Node3D
var barrel: Node3D
var block: Node3D
var handwheel: Node3D
var wheels: Array = []  # [right, left] MeshInstance3D on hub nodes
var spin := [0.0, 0.0]
var lift := 0.0
var elev := 0.0
var recoil := 0.0
var open := 0.0


func setup(lod_level := 0, knocked_out := false) -> FieldGun:
	lod = lod_level
	wreck = knocked_out
	carriage = Node3D.new()
	carriage.position = Vector3(0, G.WHEEL_R, 0)
	add_child(carriage)
	carriage.add_child(_mi(G.carriage(lod, wreck)))
	cradle = Node3D.new()
	cradle.position = G.TRUNNION
	carriage.add_child(cradle)
	cradle.add_child(_mi(G.cradle(lod, wreck)))
	barrel = Node3D.new()
	cradle.add_child(barrel)
	barrel.add_child(_mi(G.barrel(lod, wreck)))
	block = Node3D.new()
	block.position = G.BREECH
	barrel.add_child(block)
	block.add_child(_mi(G.block(lod, wreck)))
	handwheel = Node3D.new()
	handwheel.position = G.HANDWHEEL
	carriage.add_child(handwheel)
	if lod < 2:
		handwheel.add_child(_mi(G.handwheel(lod)))
	var wm := MG.mesh(G.wheel(lod, wreck))
	for s: float in [1.0, -1.0]:
		var hub := Node3D.new()
		hub.position = Vector3(G.TRACK * s, G.WHEEL_R, 0)
		add_child(hub)
		var m := MeshInstance3D.new()
		m.mesh = wm
		hub.add_child(m)
		wheels.append(m)
	return self


func _mi(g: UnitGeo) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = MG.mesh(g)
	return m


func tri_count() -> int:
	return G.tri_counts(lod, wreck)


func set_lift(a: float) -> void:
	lift = a
	carriage.basis = Basis(Vector3.RIGHT, -a)


func set_elev(deg: float) -> void:
	elev = deg
	cradle.basis = Basis(Vector3.RIGHT, deg_to_rad(deg))
	handwheel.basis = Basis(Vector3.RIGHT, deg_to_rad(deg) * 9.0)


func set_recoil(m: float) -> void:
	recoil = m
	barrel.position = Vector3(0, 0, m)


func set_block(o: float) -> void:
	open = o
	block.position = G.BREECH + Vector3(0, -0.17 * clampf(o, 0.0, 1.0), 0)


## Each wheel turned by the distance its rim rolled (+ = forward, toward -Z).
func roll(dr: float, dl: float) -> void:
	spin[0] += -dr / G.WHEEL_R
	spin[1] += -dl / G.WHEEL_R
	for i in 2:
		(wheels[i] as Node3D).basis = Basis(Vector3.RIGHT, float(spin[i]))


## The lift that puts the towing eye at height h above the ground.
static func lift_for(h: float) -> float:
	var v := G.LUNETTE
	var r := Vector2(v.y, v.z).length()
	return asin(clampf((h - G.WHEEL_R) / r, -1.0, 1.0)) - atan2(v.y, v.z)


## A carriage-frame point in the gun's own frame for a given lift.
static func at_lift(p: Vector3, a: float) -> Vector3:
	return Vector3(0, G.WHEEL_R, 0) + Basis(Vector3.RIGHT, -a) * p


## World points of the moving parts.
func cw(p: Vector3) -> Vector3:
	return carriage.global_transform * p


func bw(p: Vector3) -> Vector3:
	return barrel.global_transform * p


## The breech mouth as a frame (rounds go in along -Z).
func breech_xf() -> Transform3D:
	return barrel.global_transform * Transform3D(Basis(), G.BREECH + Vector3(0, 0, 0.02))


func muzzle_xf() -> Transform3D:
	return barrel.global_transform * Transform3D(Basis(), G.MUZZLE)
