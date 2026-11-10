class_name Armoured
extends Soldier
## One heavy armoured trench trooper (Building Chat 1, 2026-11-10), built by ArmourBuilder on the soldier skeleton.
## It is a Soldier, so poses, clips, IK hands, deaths and blast throws all work the same.
## Props:
##   shield   (shield role) the tall slit shield, held at the left palm and squared to the chest; it is placed after
##            every skeleton update, so any pose, clip or blast throw carries it along
##   club     the club / mace / spade on the item bone (in the right hand)
##   pistol   on the item bone, shown instead of the club when drawn
##   belt     the club hung at the left hip while the pistol is out
## A clip may carry "props": {"hand": [[time, "club" | "pistol" | "none"], ...]}.

const AB := preload("res://scripts/units/armour_builder.gd")
const A := preload("res://scripts/units/anim/clips_armour.gd")

var role := "shield"
var shield: MeshInstance3D
var club: MeshInstance3D
var pistol: MeshInstance3D
var belt: MeshInstance3D
var weapon_override := ""  # set before setup to pick the club man's weapon
var shield_turn := 0.0  # degrees about the chest's up (the outer edge back)

static var _lib: Dictionary = {}
static var _meshes := {}


func setup(seed_value: int, lod_level := 0, role_name := "") -> Soldier:
	role = "shield" if role_name.is_empty() else role_name
	lod = lod_level
	look = AB.look_for_role(seed_value, role)
	if not weapon_override.is_empty():
		look["weapon"] = weapon_override
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
	geo = AB.build(look, lod)
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
	club = _prop("w_%s%d" % [look["weapon"], li], func() -> UnitGeo: return AB.weapon(look["weapon"], li))
	att.add_child(club)
	pistol = _prop("pistol%d" % li, func() -> UnitGeo: return AB.pistol(li))
	att.add_child(pistol)
	var hips := BoneAttachment3D.new()
	hips.bone_name = B.BONE_NAMES[B.HIPS]
	skel.add_child(hips)
	belt = _prop("w_%s%d" % [look["weapon"], li], func() -> UnitGeo: return AB.weapon(look["weapon"], li))
	# Hung head down at the left hip (the hips bone's frame: its joint, rest axes).
	belt.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.UP, 0.15),
		Vector3(-0.235, 0.12, -0.03) - Basis(Vector3.RIGHT, -PI * 0.5) * B.GRIP_R)
	hips.add_child(belt)
	if role == "shield":
		shield = _prop("shield%d" % li, func() -> UnitGeo: return AB.shield(li))
		add_child(shield)
		skel.skeleton_updated.connect(_place_shield)
	set_props({})
	return self


func _prop(key: String, maker: Callable) -> MeshInstance3D:
	if not _meshes.has(key):
		_meshes[key] = (maker.call() as UnitGeo).to_mesh(material())
	var m := MeshInstance3D.new()
	m.mesh = _meshes[key]
	return m


func tri_count() -> int:
	var n := geo.tri_count()
	return n


## The shield at the left palm, squared to the chest (turned by shield_turn).
func _place_shield() -> void:
	if shield == null:
		return
	var ch := skel.get_bone_global_pose(B.CHEST)
	var hl := skel.get_bone_global_pose(B.HAND_L)
	var palm := hl * ((B.REST[B.HAND_L] - B.REST[B.FARM_L]).normalized() * B.PALM)
	# Squared to the chest, but held more upright than the chest leans (towards the root's up, so it still falls
	# with the body).
	var cb := ch.basis.orthonormalized()
	var rup := skel.get_bone_global_pose(B.ROOT).basis.orthonormalized().y
	var up := cb.y.lerp(rup, 0.6).normalized()
	var fwd := -cb.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var bas := Basis.looking_at(fwd, up) * Basis(Vector3.UP, deg_to_rad(shield_turn))
	# Going down, the shield slides out to his left so it lies beside him, not under him.
	var k := clampf((0.75 - rup.y) / 0.5, 0.0, 1.0)
	var side := -cb.x
	side.y = 0.0
	if side.length_squared() > 1e-4:
		palm += side.normalized() * 0.55 * k
	var xf := Transform3D(bas, palm)
	# Never through the ground (model y = 0 is the ground): lying down, it rests on the earth beside him.
	var low := INF
	for c: Vector3 in [Vector3(-0.25, AB.SHIELD_BOT, -0.1), Vector3(0.4, AB.SHIELD_BOT, -0.1),
			Vector3(-0.25, AB.SHIELD_TOP, -0.1), Vector3(0.4, AB.SHIELD_TOP, -0.1)]:
		low = minf(low, (xf * c).y)
	if low < 0.015:
		xf.origin.y += 0.015 - low
	shield.transform = xf


static func library() -> Dictionary:
	if _lib.is_empty():
		_lib = A.library()
	return _lib


func clip_lib() -> Dictionary:
	return library()


## The role's own clip for a shared move (deaths, get up), as BlastThrow plays them.
func clip_name(base: String) -> String:
	return A.role_clip(role, base)


func set_pose(pose_name: String) -> void:
	var ps := A.poses(role)
	show_spec(ps.get(pose_name, ps["stand"]))


func show_spec(p: Dictionary, ground := true) -> void:
	var g := Rig.solve(p, p, 0.0)
	if ground:
		Rig.lift(g, Rig.ground_lift(g, geo))
	Anim.apply(skel, g)
	set_props({"hand": [p.get("hand_item", "club"), 0.0]})


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
	var h: String = (state.get("hand", ["club", 0.0]) as Array)[0]
	club.visible = h == "club"
	pistol.visible = h == "pistol"
	belt.visible = h != "club"
