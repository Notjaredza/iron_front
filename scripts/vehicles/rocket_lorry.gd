class_name RocketLorry
extends Lorry
## The rocket lorry (Tanks Chat, 2026-11-10): the troop lorry without its tilt and benches,
## carrying the rocket rack from rocket_builder.gd. Everything the Lorry does (wheels, springs,
## tailgate) still works; on top:
##   set_train(rad)   the turntable (+ = to the left)
##   set_elev(deg)    the cradle
##   set_jacks(0..1)  the rear jacks down to the ground
##   set_loaded(i, on), rocket_xf(i, slide) for rail i (0..15)

const RB := preload("res://scripts/vehicles/rocket_builder.gd")

var turntable: Node3D
var cradle: Node3D
var rockets: Array = []  # MeshInstance3D per rail
var jacks: Array = []  # foot nodes
var _rack_tris := 0


func setup_rack(lod_level := 0, burnt := false) -> RocketLorry:
	setup(lod_level, burnt, false, false)
	var sg := RB.shield(lod, wreck)
	var sm := MeshInstance3D.new()
	sm.mesh = MG.mesh(sg)
	body.add_child(sm)
	turntable = Node3D.new()
	turntable.name = "Turntable"
	turntable.position = RB.TURNTABLE
	body.add_child(turntable)
	var bg := RB.base(lod, wreck)
	var bm := MeshInstance3D.new()
	bm.mesh = MG.mesh(bg)
	turntable.add_child(bm)
	cradle = Node3D.new()
	cradle.name = "Cradle"
	cradle.position = RB.TRUNNION
	turntable.add_child(cradle)
	var cg := RB.cradle(lod, wreck)
	var cm := MeshInstance3D.new()
	cm.mesh = MG.mesh(cg)
	cradle.add_child(cm)
	var rg := RB.rocket(lod, wreck)
	var rmesh := MG.mesh(rg)
	for i in 16:
		var r := MeshInstance3D.new()
		r.mesh = rmesh if lod < 2 else null
		r.position = RB.rail_point(i)
		cradle.add_child(r)
		rockets.append(r)
	var jg := RB.jack_leg(lod, wreck)
	var jm := MG.mesh(jg)
	for s: float in [1.0, -1.0]:
		var f := Node3D.new()
		f.name = "Jack"
		body.add_child(f)
		var m := MeshInstance3D.new()
		m.mesh = jm
		f.add_child(m)
		jacks.append({"node": f, "side": s})
	set_jacks(0.0)
	_rack_tris = sg.tri_count() + bg.tri_count() + cg.tri_count() + (16 * rg.tri_count() if lod < 2 else 0) + 2 * jg.tri_count()
	return self


func tri_count() -> int:
	return L.body(lod, wreck, false, false).tri_count() + L.tailgate(lod, wreck).tri_count() \
		+ 2 * L.wheel(lod, false, wreck).tri_count() + 2 * L.wheel(lod, true, wreck).tri_count() + _rack_tris


func set_train(rad: float) -> void:
	turntable.basis = Basis(Vector3.UP, rad)


func set_elev(deg: float) -> void:
	cradle.basis = Basis(Vector3.RIGHT, deg_to_rad(deg))


## 0 = up under the bed, 1 = feet on the ground (body frame; the ground is at y = 0 under it).
func set_jacks(down: float) -> void:
	for j: Dictionary in jacks:
		var top := RB.JACK_R * Vector3(float(j["side"]), 1, 1)
		var foot_y := lerpf(top.y - 0.55, 0.0, clampf(down, 0.0, 1.0))
		(j["node"] as Node3D).position = Vector3(top.x, foot_y, top.z)


func set_loaded(i: int, on: bool) -> void:
	(rockets[i] as Node3D).visible = on


func set_all_loaded(n: int) -> void:
	for i in 16:
		set_loaded(i, i < n)


## World transform of a rocket on rail i with its tail slide m forward of the rail's rear end.
func rocket_xf(i: int, slide := RB.SEAT_Z) -> Transform3D:
	return cradle.global_transform * Transform3D(Basis(), RB.rail_point(i, slide))


## World point on the cradle (cradle frame point).
func cw(p: Vector3) -> Vector3:
	return cradle.global_transform * p
