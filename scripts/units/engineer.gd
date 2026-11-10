class_name Engineer
extends Soldier
## One man of the engineer section (Building Chat 1, 2026-11-10), built by EngineerBuilder on the soldier skeleton.
## Roles: "nco" (directs, checks the plan, joins heavy lifts) and "sapper". Every pose, clip, IK hand, death and
## blast throw works as for our other troops.
## Props:
##   tool   one of EngineerBuilder.TOOLS on the item bone (right hand), or none
##   plan   the NCO's board in the left hand
## A clip may carry "props": {"hand": [[time, tool | "none"], ...], "plan": [[time, "on" | "off"], ...]}.

const EB := preload("res://scripts/units/engineer_builder.gd")
const E := preload("res://scripts/units/anim/clips_engineer.gd")

var role := "sapper"
var tools := {}
var plan_mesh: MeshInstance3D

static var _lib: Dictionary = {}
static var _meshes := {}


func setup(seed_value: int, lod_level := 0, role_name := "") -> Soldier:
	role = "sapper" if role_name.is_empty() else role_name
	lod = lod_level
	look = EB.look_for_role(seed_value, role)
	skel = Skeleton3D.new()
	skel.name = "Skeleton"
	add_child(skel)
	for i in B.BONE_NAMES.size():
		skel.add_bone(B.BONE_NAMES[i])
	for i in B.BONE_NAMES.size():
		var par: int = B.BONE_PARENT[i]
		var off: Vector3 = B.REST[i] if par < 0 else B.REST[i] - B.REST[par]
		if par >= 0:
			skel.set_bone_parent(i, par)
		skel.set_bone_rest(i, Transform3D(Basis(), off))
		skel.set_bone_pose_position(i, off)
		skel.set_bone_pose_rotation(i, Quaternion())
	geo = EB.build(look, lod)
	mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "Body"
	mesh_inst.mesh = geo.to_mesh(material())
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	mesh_inst.skin = skel.create_skin_from_rest_transforms()
	var li := mini(lod, 2)
	var att := BoneAttachment3D.new()
	att.bone_name = B.BONE_NAMES[B.RIFLE]
	skel.add_child(att)
	for t: String in EB.TOOL_L.keys() + ["hammer"]:
		if tools.has(t):
			continue
		var m := _prop("%s%d" % [t, li], func() -> UnitGeo: return EB.tool(t, li))
		att.add_child(m)
		tools[t] = m
	plan_mesh = _prop("plan%d" % li, func() -> UnitGeo: return EB.plan(li))
	add_child(plan_mesh)
	skel.skeleton_updated.connect(_place_plan)
	set_props({})
	return self


## The plan at the left palm, its face tipped up and back toward his eyes, squared to the chest (so it reads the same
## whatever way the hand bone rolled).
func _place_plan() -> void:
	if not plan_mesh.visible:
		return
	var ch := skel.get_bone_global_pose(B.CHEST).basis.orthonormalized()
	var hl := skel.get_bone_global_pose(B.HAND_L)
	var palm := hl * ((B.REST[B.HAND_L] - B.REST[B.FARM_L]).normalized() * B.PALM)
	var y := (ch.y * 0.55 + ch.z * 0.85).normalized()
	var x := (ch.x - y * ch.x.dot(y)).normalized()
	plan_mesh.transform = Transform3D(Basis(x, y, x.cross(y)), palm)


func _prop(key: String, maker: Callable) -> MeshInstance3D:
	if not _meshes.has(key):
		_meshes[key] = (maker.call() as UnitGeo).to_mesh(material())
	var m := MeshInstance3D.new()
	m.mesh = _meshes[key]
	return m


static func library() -> Dictionary:
	if _lib.is_empty():
		_lib = E.library()
	return _lib


func clip_lib() -> Dictionary:
	return library()


func clip_name(base: String) -> String:
	return "eng_" + base


func set_pose(pose_name: String) -> void:
	var ps := E.poses()
	show_spec(ps.get(pose_name, ps["stand"]))


func show_spec(p: Dictionary, ground := true) -> void:
	var g := Rig.solve(p, p, 0.0)
	if ground:
		Rig.lift(g, Rig.ground_lift(g, geo))
	Anim.apply(skel, g)
	set_props({"hand": [p.get("hand_item", "none"), 0.0], "plan": [p.get("plan", "off"), 0.0]})


func show_clip(clip: Dictionary, time: float) -> void:
	super.show_clip(clip, time)
	set_props(prop_state(clip, time))


static func prop_state(clip: Dictionary, time: float) -> Dictionary:
	var out := {}
	var tracks: Dictionary = clip.get("props", {})
	var length: float = clip["len"]
	var t := fposmod(time, length) if clip.get("loop", false) else clampf(time, 0.0, length)
	for name: String in tracks:
		var keys: Array = tracks[name]
		var i := 0
		while i < keys.size() - 1 and float(keys[i + 1][0]) <= t:
			i += 1
		out[name] = [keys[i][1], 0.0]
	return out


func set_props(state: Dictionary) -> void:
	var h: String = (state.get("hand", ["none", 0.0]) as Array)[0]
	for t: String in tools:
		(tools[t] as Node3D).visible = t == h
	plan_mesh.visible = (state.get("plan", ["off", 0.0]) as Array)[0] == "on"
	_place_plan()
