class_name Redcoat
extends Soldier
## One red jacket (Building Chat 1, 2026-11-10): the musket-era enemy on the soldier skeleton (RedcoatBuilder).
## It is a Soldier, so poses, clips, IK hands, deaths and blast throws all work the same. It adds the props that
## move on their own in the reload (the rammer and the cartridge), the colour's waving cloth (ensign), and its own
## clip library (anim/clips_musket.gd). A clip may carry "props": {name: [[time, mode, value], ...]}:
##   rammer     "stock" s (stowed under the barrel, drawn out s metres), "hand" (in the right fist),
##              "barrel" d (in the barrel, its head d metres down from the muzzle)
##   cartridge  "off" or "hand"

const RB := preload("res://scripts/units/redcoat_builder.gd")
const M := preload("res://scripts/units/anim/clips_musket.gd")

var role := "musketeer"
var rammer: MeshInstance3D
var cartridge: MeshInstance3D
var flag: MeshInstance3D
var _att_item: BoneAttachment3D
var _att_hand: BoneAttachment3D
var wind := 1.0

static var _flag_mat: ShaderMaterial
static var _lib: Dictionary = {}
static var _meshes := {}


func setup(seed_value: int, lod_level := 0, role_name := "") -> Soldier:
	role = "musketeer" if role_name.is_empty() else role_name
	lod = lod_level
	look = RB.look_for_role(seed_value, role)
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
	geo = RB.build(look, lod)
	mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "Body"
	mesh_inst.mesh = geo.to_mesh(material())
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	mesh_inst.skin = skel.create_skin_from_rest_transforms()
	_att_item = BoneAttachment3D.new()
	_att_item.bone_name = B.BONE_NAMES[B.RIFLE]
	skel.add_child(_att_item)
	if role == "musketeer" and lod == 0:
		_att_hand = BoneAttachment3D.new()
		_att_hand.bone_name = B.BONE_NAMES[B.HAND_R]
		skel.add_child(_att_hand)
		rammer = _prop("rammer", RB.rammer)
		_att_item.add_child(rammer)
		cartridge = _prop("cartridge", RB.cartridge)
		_att_hand.add_child(cartridge)
		cartridge.transform = Transform3D(Basis(Vector3.RIGHT, 0.4), palm_local() + Vector3(0, -0.01, -0.03))
		cartridge.visible = false
		set_props({})
	if role == "ensign":
		flag = MeshInstance3D.new()
		var key := "flag%d" % mini(lod, 1)
		if not _meshes.has(key):
			_meshes[key] = RB.flag_mesh(look.get("facing", "buff"), 26 if lod == 0 else 10, 22 if lod == 0 else 8)
		flag.mesh = _meshes[key]
		flag.material_override = flag_material()
		flag.position = RB.FLAG_AT
		_att_item.add_child(flag)
	return self


static func flag_material() -> ShaderMaterial:
	if _flag_mat == null:
		_flag_mat = ShaderMaterial.new()
		_flag_mat.shader = load("res://shaders/flag_wave.gdshader")
	return _flag_mat


static func library() -> Dictionary:
	if _lib.is_empty():
		_lib = M.library()
	return _lib


## The clip set for a role (the drummer, officer and ensign have their own; deaths are everyone's).
func clip_lib() -> Dictionary:
	return library()


func _prop(key: String, maker: Callable) -> MeshInstance3D:
	if not _meshes.has(key):
		_meshes[key] = (maker.call() as UnitGeo).to_mesh(material())
	var m := MeshInstance3D.new()
	m.mesh = _meshes[key]
	return m


## The right palm in the hand bone's frame.
static func palm_local() -> Vector3:
	return (B.REST[B.HAND_R] - B.REST[B.FARM_R]).normalized() * B.PALM


## Moves the waving cloth on to time t (frame-exact in clips).
func set_time(t: float) -> void:
	if flag != null:
		flag.set_instance_shader_parameter("t_wave", t + float(look.get("build", 1.0)) * 7.0)
		flag.set_instance_shader_parameter("wind", wind)


func show_clip(clip: Dictionary, time: float) -> void:
	super.show_clip(clip, time)
	set_props(prop_state(clip, time))


## The props' modes at time t of a clip: {name: [mode, value]}.
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
		var mode: String = keys[i][1]
		var v: float = float(keys[i][2]) if keys[i].size() > 2 else 0.0
		if i < keys.size() - 1 and keys[i + 1][1] == mode and keys[i + 1].size() > 2:
			var u := (t - float(keys[i][0])) / maxf(float(keys[i + 1][0]) - float(keys[i][0]), 1e-5)
			v = lerpf(v, float(keys[i + 1][2]), clampf(u, 0.0, 1.0))
		out[name] = [mode, v]
	return out


func set_props(state: Dictionary) -> void:
	if rammer == null:
		return
	var rs: Array = state.get("rammer", ["stock", 0.0])
	rammer.transform = M.rammer_xf(rs[0], rs[1])
	var cs: Array = state.get("cartridge", ["off", 0.0])
	cartridge.visible = cs[0] == "hand"


## The role's own name for a shared clip (deaths, get up), as BlastThrow plays them.
func clip_name(base: String) -> String:
	return M.role_clip(role, base)


func set_pose(pose_name: String) -> void:
	var ps := M.poses(role)
	var p: Dictionary = ps.get(pose_name, ps["stand"])
	var g := Rig.solve(p, p, 0.0)
	Rig.lift(g, Rig.ground_lift(g, geo))
	Anim.apply(skel, g)
