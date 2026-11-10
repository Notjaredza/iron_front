class_name Medieval
extends Soldier
## One man of the medieval host (Building Chat 1, 2026-11-10), built by MedievalBuilder on the soldier skeleton, so every
## pose, clip, IK hand, death and blast throw works as for our own troops. Roles: see MedievalBuilder.
## Props:
##   main     the role's weapon on the item bone (the bow too: the bow kit's carries put the item bone in the left hand)
##   alt      the knight's sword (drawn after the lance)
##   shield   the heater shield at the left palm, squared to the chest, placed after every skeleton update
##   arrow    the nocked arrow, from the right palm to the bow's grip; the string follows the right hand while it is on
## A clip may carry "props": {"hand": [[t, "main" | "alt" | "none"]], "arrow": [[t, "on" | "off"]]}.

const MB := preload("res://scripts/units/medieval_builder.gd")
const MC := preload("res://scripts/units/anim/clips_medieval.gd")

var role := "man_at_arms"
var kit := "sword"
var main: MeshInstance3D
var alt: MeshInstance3D
var shield: MeshInstance3D
var arrow: MeshInstance3D
var strings: Array[MeshInstance3D] = []
var lord := -1  # set before setup to put him in a lord's livery

static var _lib: Dictionary = {}
static var _meshes := {}
static var _string_mesh: BoxMesh


func setup(seed_value: int, lod_level := 0, role_name := "") -> Soldier:
	role = "man_at_arms" if role_name.is_empty() else role_name
	kit = MC.kit_of(role)
	lod = lod_level
	look = MB.look_for_role(seed_value, role, lord)
	if look["weapon"] == "greatsword":
		kit = "great"
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
	geo = MB.build(look, lod)
	mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "Body"
	mesh_inst.mesh = geo.to_mesh(material())
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	mesh_inst.skin = skel.create_skin_from_rest_transforms()
	var li := mini(lod, 2)
	var a: Dictionary = look["arms"]
	var wk: String = look["weapon"]
	var att := BoneAttachment3D.new()
	att.bone_name = B.BONE_NAMES[B.RIFLE]
	skel.add_child(att)
	var akey := "%s_%s" % [a["field"].to_html(), a["second"].to_html()]
	main = _prop("w_%s%d_%s" % [wk, li, akey if wk in ["lance", "banner"] else ""], func() -> UnitGeo: return MB.weapon(wk, li, a))
	att.add_child(main)
	if role in ["knight"]:
		alt = _prop("w_sword%d" % li, func() -> UnitGeo: return MB.weapon("sword", li))
		att.add_child(alt)
	if look.get("shield", false):
		var small: bool = look.get("small_shield", false)
		shield = _prop("shield%d_%s_%s_%s%s" % [li, akey, a["div"], a["charge"], "s" if small else ""],
			func() -> UnitGeo: return MB.shield(a, li, small))
		add_child(shield)
	if kit == "bow":
		arrow = _prop("arrow", func() -> UnitGeo: return MB.arrow())
		add_child(arrow)
		if _string_mesh == null:
			_string_mesh = BoxMesh.new()
			_string_mesh.size = Vector3(0.006, 0.006, 1.0)
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.85, 0.82, 0.72)
			_string_mesh.material = sm
		for i in 2:
			var s := MeshInstance3D.new()
			s.mesh = _string_mesh
			add_child(s)
			strings.append(s)
	skel.skeleton_updated.connect(_place)
	set_props({})
	return self


func _prop(key: String, maker: Callable) -> MeshInstance3D:
	if not _meshes.has(key):
		_meshes[key] = (maker.call() as UnitGeo).to_mesh(material())
	var m := MeshInstance3D.new()
	m.mesh = _meshes[key]
	return m


func tri_count() -> int:
	return geo.tri_count()


func _palm(fa: int, hd: int) -> Vector3:
	return skel.get_bone_global_pose(hd) * ((B.REST[hd] - B.REST[fa]).normalized() * B.PALM)


func _place() -> void:
	if shield != null:
		_place_shield()
	if kit == "bow":
		_place_bow()


## The shield at the left palm, squared to the chest but held more upright; down on the ground beside him in a fall.
func _place_shield() -> void:
	var cb := skel.get_bone_global_pose(B.CHEST).basis.orthonormalized()
	var palm := _palm(B.FARM_L, B.HAND_L)
	var rup := skel.get_bone_global_pose(B.ROOT).basis.orthonormalized().y
	var up := cb.y.lerp(rup, 0.6).normalized()
	var fwd := -cb.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var bas := Basis.looking_at(fwd, up) * Basis(Vector3.UP, 0.25)
	var k := clampf((0.75 - rup.y) / 0.5, 0.0, 1.0)
	var side := -cb.x
	side.y = 0.0
	if side.length_squared() > 1e-4:
		palm += side.normalized() * 0.45 * k
	var xf := Transform3D(bas, palm)
	var low := INF
	for c: Vector3 in [Vector3(-MB.SHIELD_W, MB.SHIELD_TOP, -0.06), Vector3(MB.SHIELD_W, MB.SHIELD_TOP, -0.06),
			Vector3(0, MB.SHIELD_BOT, -0.06)]:
		low = minf(low, (xf * c).y)
	if get_parent() != null and not (get_parent() is BoneAttachment3D):
		# Lying down it comes to rest on the earth; never through it.
		if low < 0.015:
			xf.origin.y += 0.015 - low
		elif k > 0.0:
			xf.origin.y -= (low - 0.015) * k
	shield.transform = xf


## The arrow nocked at the right palm, pointing through the bow's grip; the string tip to nock to tip.
func _place_bow() -> void:
	var bx := skel.get_bone_global_pose(B.RIFLE)
	var tips := MB.bow_tips()
	var t0 := bx * tips[0]
	var t1 := bx * tips[1]
	var nock := (t0 + t1) * 0.5
	if arrow.visible:
		var rp := _palm(B.FARM_R, B.HAND_R)
		var gp := bx * B.GRIP_R
		var d := gp - rp
		if d.length() > 0.05:
			nock = rp
			var bas := Basis.looking_at(d.normalized(), bx.basis.y)
			arrow.transform = Transform3D(bas, rp)
	for i in 2:
		var a := t0 if i == 0 else t1
		var mid := (a + nock) * 0.5
		var L := maxf((nock - a).length(), 0.001)
		var up := Vector3.UP if absf((nock - a).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		strings[i].transform = Transform3D(Basis.looking_at((nock - a) / L, up).scaled_local(Vector3(1, 1, L)), mid)


static func library() -> Dictionary:
	if _lib.is_empty():
		_lib = MC.library()
	return _lib


func clip_lib() -> Dictionary:
	return library()


func clip_name(base: String) -> String:
	return "%s_%s" % [kit, base]


func set_pose(pose_name: String) -> void:
	var ps := MC.poses(kit)
	show_spec(ps.get(pose_name, ps["stand"]))


func show_spec(p: Dictionary, ground := true) -> void:
	var g := Rig.solve(p, p, 0.0)
	if ground:
		Rig.lift(g, Rig.ground_lift(g, geo))
	Anim.apply(skel, g)
	set_props({"hand": [p.get("hand_item", "main"), 0.0], "arrow": [p.get("arrow", "off"), 0.0]})


## Two specs blended at u (the mounted moves).
func show_blend(a: Dictionary, b: Dictionary, u: float, ground := true) -> void:
	var g := Rig.solve(a, b, u)
	if ground:
		Rig.lift(g, Rig.ground_lift(g, geo))
	Anim.apply(skel, g)


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
	var h: String = (state.get("hand", ["main", 0.0]) as Array)[0]
	main.visible = h == "main"
	if alt != null:
		alt.visible = h == "alt"
	if arrow != null:
		arrow.visible = (state.get("arrow", ["off", 0.0]) as Array)[0] == "on"
	_place()


## A horse in the knight's barding (the caparison and chanfron skinned to the horse's own bones).
static func barded_horse(seed_value: int, a: Dictionary, lod_level := 0) -> Horse:
	var h := Horse.new().setup(seed_value, lod_level, a["second"])
	var key := "bard%d_%s_%s_%s_%s" % [mini(lod_level, 2), a["field"].to_html(), a["second"].to_html(), a["div"], a["charge"]]
	if not _meshes.has(key):
		_meshes[key] = MB.barding(a, lod_level).to_mesh(material())
	var m := MeshInstance3D.new()
	m.mesh = _meshes[key]
	h.skel.add_child(m)
	m.skeleton = NodePath("..")
	m.skin = h.skel.create_skin_from_rest_transforms()
	return h
