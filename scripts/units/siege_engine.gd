class_name SiegeEngine
extends Node3D
## One siege engine of the medieval host (Building Chat 1, 2026-11-10). The geometry is SiegeBuilder's; this hangs the
## moving parts on pivots and sets them from a state. Faces -Z. Crews take their hand spots from point() (engine
## space), so the parts and the men move together.
## States (set_state; missing keys keep their last value):
##   trebuchet  swing 0 cocked .. 1 follow-through (the stone leaves at RELEASE), winch (rad), loaded, cock (rope to the drum)
##   mangonel   throw 0 cocked .. 1 on the stop beam, winch, loaded, cock
##   ballista   yaw, pitch (rad), draw 0 .. 1, winch, loaded
##   tower      bridge 0 up .. 1 down (or bridge_angle, rad below flat)
##   ram        swing (rad, + toward the front)

const SB := preload("res://scripts/units/siege_builder.gd")
const RELEASE := 0.62
const T_COCK := 0.64
const T_END := -2.35
const T_REL := -1.95
const M_COCK := 0.08
const M_STOP := -1.72

var kind := "trebuchet"
var lod := 0
var arms: Dictionary
var parts := {}
var ropes := {}
var state := {}

static var _meshes := {}
static var _rope_mesh: BoxMesh
static var _chain_mesh: BoxMesh


func setup(kind_name: String, lod_level := 0, lord := 0, seed_value := 1) -> SiegeEngine:
	kind = kind_name
	lod = lod_level
	arms = SB.MB.lord_arms(lord)
	var key := "%s%d_%d_%d" % [kind, lod, lord, seed_value if kind == "fascine" else 0]
	if not _meshes.has(key):
		var geos: Dictionary
		match kind:
			"trebuchet":
				geos = SB.trebuchet(lod)
			"mangonel":
				geos = SB.mangonel(lod)
			"ballista":
				geos = SB.ballista(lod)
			"tower":
				geos = SB.tower(lod, arms, 3 + lord)
			"ram":
				geos = SB.ram(lod, arms, 5 + lord)
			"ladder":
				geos = SB.ladder(lod)
			"mantlet":
				geos = SB.mantlet(lod, arms)
			_:
				geos = SB.fascine(lod, seed_value)
		var ms := {}
		var tris := 0
		for p: String in geos:
			ms[p] = (geos[p] as UnitGeo).to_mesh(Soldier.material())
			tris += (geos[p] as UnitGeo).tri_count()
		ms["_tris"] = tris
		_meshes[key] = ms
	var m: Dictionary = _meshes[key]
	set_meta("tris", m["_tris"])
	match kind:
		"trebuchet":
			_part("frame", m, self, Vector3.ZERO)
			_part("arm", m, self, SB.T_AXLE)
			_part("cw", m, parts["arm"], Vector3(0, 0, -SB.T_SHORT))
			_part("winch", m, self, SB.T_WINCH)
			_part("pouch", m, self, Vector3.ZERO)
			_part("stone", m, parts["pouch"], Vector3(0, 0.2, 0))
			for r: String in ["sling_l", "sling_r", "cock", "lanyard"]:
				_rope(r)
			set_state({"swing": 0.0, "winch": 0.0, "loaded": true, "cock": false})
		"mangonel":
			_part("frame", m, self, Vector3.ZERO)
			_part("arm", m, self, SB.M_SKEIN)
			_part("winch", m, self, SB.M_WINCH)
			_part("stone", m, parts["arm"], Vector3(0, 0.3, SB.M_ARM))
			for r: String in ["cock", "lanyard"]:
				_rope(r)
			set_state({"throw": 0.0, "winch": 0.0, "loaded": true, "cock": false})
		"ballista":
			_part("frame", m, self, Vector3.ZERO)
			_part("mount", m, self, SB.BA_MOUNT)
			_part("cradle", m, parts["mount"], SB.BA_CRADLE)
			_part("arm_l", m, parts["cradle"], Vector3(-SB.BA_SKEIN_X, 0, SB.BA_SKEIN_Z))
			_part("arm_r", m, parts["cradle"], Vector3(SB.BA_SKEIN_X, 0, SB.BA_SKEIN_Z))
			_part("slider", m, parts["cradle"], Vector3.ZERO)
			_part("bolt", m, parts["slider"], Vector3.ZERO)
			_part("winch", m, parts["cradle"], SB.BA_WINCH)
			for r: String in ["string_l", "string_r", "haul"]:
				_rope(r)
			set_state({"yaw": 0.0, "pitch": 0.0, "draw": 0.0, "winch": 0.0, "loaded": true})
		"tower":
			_part("body", m, self, Vector3.ZERO)
			_part("bridge", m, self, Vector3(0, SB.TW_FLOORS[2], -SB.TW_HALF.z - 0.02))
			for r: String in ["chain_l", "chain_r"]:
				_rope(r, true)
			set_state({"bridge": 0.0})
		"ram":
			_part("body", m, self, Vector3.ZERO)
			_part("ram", m, self, Vector3.ZERO)
			for i in 4:
				_rope("hang%d" % i)
			set_state({"swing": 0.0})
		_:
			_part("body", m, self, Vector3.ZERO)
	return self


func tri_count() -> int:
	return int(get_meta("tris", 0))


func _part(name_: String, m: Dictionary, parent: Node3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = m[name_]
	mi.position = at
	parent.add_child(mi)
	parts[name_] = mi


func _rope(name_: String, chain := false) -> void:
	if _rope_mesh == null:
		_rope_mesh = BoxMesh.new()
		_rope_mesh.size = Vector3(1, 1, 1)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = SB.ROPE
		sm.roughness = 0.95
		_rope_mesh.material = sm
		_chain_mesh = BoxMesh.new()
		_chain_mesh.size = Vector3(1, 1, 1)
		var cm := StandardMaterial3D.new()
		cm.albedo_color = SB.IRON
		cm.metallic = 0.4
		cm.roughness = 0.6
		_chain_mesh.material = cm
	var mi := MeshInstance3D.new()
	mi.mesh = _chain_mesh if chain else _rope_mesh
	mi.visible = false
	add_child(mi)
	ropes[name_] = mi


## A rope (or chain) from a to b in engine space.
func line(name_: String, a: Vector3, b: Vector3, w := 0.025) -> void:
	var mi: MeshInstance3D = ropes[name_]
	var d := b - a
	var L := d.length()
	if L < 0.01:
		mi.visible = false
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d / L, up).scaled_local(Vector3(w, w, L)), (a + b) * 0.5)
	mi.visible = true


## Where a part's local point sits in engine space.
func at_part(name_: String, p: Vector3) -> Vector3:
	var n: Node3D = parts[name_]
	var xf := Transform3D()
	while n != self:
		xf = n.transform * xf
		n = n.get_parent()
	return xf * p


## Easing for the throwing arms: slow off the catch, fast through the release.
static func arm_ease(u: float) -> float:
	return 1.0 - cos(clampf(u, 0.0, 1.0) * PI * 0.5) if u < 0.7 else lerpf(1.0 - cos(0.7 * PI * 0.5), 1.0, sin((u - 0.7) / 0.3 * PI * 0.5))


func set_state(s: Dictionary) -> void:
	for k: String in s:
		state[k] = s[k]
	match kind:
		"trebuchet":
			_trebuchet()
		"mangonel":
			_mangonel()
		"ballista":
			_ballista()
		"tower":
			# closed: stood up against the front (+90 deg); open: flat; bridge_angle droops it below flat onto a parapet
			var r := -float(state["bridge_angle"]) if s.has("bridge_angle") else lerpf(PI * 0.5, 0.0, float(state["bridge"]))
			if not s.has("bridge_angle"):
				state.erase("bridge_angle")
			(parts["bridge"] as Node3D).rotation.x = r
			for s2: float in [-1.0, 1.0]:
				line("chain_l" if s2 < 0.0 else "chain_r", Vector3(s2 * 1.55, SB.TW_FLOORS[3] - 0.1, -SB.TW_HALF.z),
					at_part("bridge", Vector3(s2 * 1.25, 0.05, -SB.TW_BRIDGE + 0.15)), 0.03)
		"ram":
			var th: float = state["swing"]
			var r: Node3D = parts["ram"]
			r.position = Vector3(0, SB.R_PIVOT_Y - SB.R_HANG * cos(th), -SB.R_HANG * sin(th))
			var i := 0
			for pz: float in SB.R_PIVOT_Z:
				for sx: float in [-1.0, 1.0]:
					line("hang%d" % i, Vector3(sx * 0.18, SB.R_PIVOT_Y + 0.02, pz), r.position + Vector3(sx * 0.2, 0.12, pz), 0.03)
					i += 1


func tip() -> Vector3:
	return at_part("arm", Vector3(0, 0.3, SB.T_LONG + 0.25)) if kind == "trebuchet" else at_part("arm", Vector3(0, 0.3, SB.M_ARM))


func _trebuchet() -> void:
	var u: float = state["swing"]
	var e := arm_ease(u)
	# slow off the catch, the arm just past upright at the release, then the follow-through
	var a := lerpf(T_COCK, T_REL, pow(clampf(u / RELEASE, 0.0, 1.0), 1.5)) if u < RELEASE \
		else lerpf(T_REL, T_END, sin(clampf((u - RELEASE) / (1.0 - RELEASE), 0.0, 1.0) * PI * 0.5))
	var arm: Node3D = parts["arm"]
	arm.rotation.x = a
	# the box hangs plumb, swinging a little behind the pin as the arm whips
	(parts["cw"] as Node3D).rotation.x = -a + 0.25 * sin(e * PI) * (1.0 - e * 0.5)
	(parts["winch"] as Node3D).rotation.x = float(state["winch"])
	var t := at_part("arm", Vector3(0, 0, SB.T_LONG))
	# the sling: lies in the trough cocked, trails the arm, swings out straight at the release, then over the top
	var rest := Vector3(0, 0.22, t.z - SB.T_SLING)
	var th_arm := atan2(-sin(a), cos(a))
	var t0 := Vector3(0, 0.0, SB.T_LONG).rotated(Vector3.RIGHT, T_COCK) + SB.T_AXLE
	var d0 := (Vector3(0, 0.22, t0.z - SB.T_SLING) - t0)
	var g0 := atan2(d0.y, d0.z) - atan2(-sin(T_COCK), cos(T_COCK))
	g0 = wrapf(g0, -TAU, 0.0)
	var gam := g0 * (1.0 - smoothstep(0.0, RELEASE, u)) if u < RELEASE else 0.9 * (u - RELEASE) / (1.0 - RELEASE)
	var th := th_arm + gam
	var dir := Vector3(0, sin(th), cos(th))
	var pouch := t + dir * SB.T_SLING
	if u <= 0.001:
		pouch = rest
	elif pouch.y < 0.22:
		# still dragging along the trough
		var dz := sqrt(maxf(SB.T_SLING * SB.T_SLING - (t.y - 0.22) * (t.y - 0.22), 0.0))
		pouch = Vector3(0, 0.22, t.z - dz)
	var p: Node3D = parts["pouch"]
	var pd := (pouch - t).normalized()
	p.transform = Transform3D(Basis.looking_at(pd, Vector3.UP if absf(pd.y) < 0.95 else Vector3.BACK), pouch)
	(parts["stone"] as Node3D).visible = bool(state["loaded"]) and u < RELEASE
	var side := p.transform.basis.x
	line("sling_l", t - Vector3(0.04, 0, 0), pouch - side * 0.18 - pd * 0.28, 0.018)
	line("sling_r", t + Vector3(0.04, 0, 0), pouch + side * 0.18 - pd * 0.28, 0.018)
	if state.get("cock", false):
		var c: Vector3 = SB.T_WINCH + Vector3(0, 0.2, 0)
		line("cock", c, t, 0.03)
	else:
		(ropes["cock"] as Node3D).visible = false
	if state.has("lanyard_to") and u < 0.05:
		line("lanyard", t + Vector3(0.0, -0.1, 0.1), state["lanyard_to"], 0.015)
	else:
		(ropes["lanyard"] as Node3D).visible = false


func _mangonel() -> void:
	var u: float = state["throw"]
	var e := pow(clampf(u, 0.0, 1.0), 1.7)
	var a := lerpf(M_COCK, M_STOP, e)
	(parts["arm"] as Node3D).rotation.x = a
	(parts["winch"] as Node3D).rotation.x = float(state["winch"])
	(parts["stone"] as Node3D).visible = bool(state["loaded"]) and u < 0.92
	if state.get("cock", false):
		line("cock", SB.M_WINCH + Vector3(0, 0.12, 0), at_part("arm", Vector3(0, 0, SB.M_ARM - 0.35)), 0.025)
	else:
		(ropes["cock"] as Node3D).visible = false
	if state.has("lanyard_to") and u < 0.05:
		line("lanyard", at_part("arm", Vector3(0, -0.05, SB.M_ARM - 0.5)), state["lanyard_to"], 0.015)
	else:
		(ropes["lanyard"] as Node3D).visible = false


func _ballista() -> void:
	(parts["mount"] as Node3D).rotation.y = float(state["yaw"])
	(parts["cradle"] as Node3D).rotation.x = float(state["pitch"])
	var d: float = state["draw"]
	var sl: Node3D = parts["slider"]
	sl.position = Vector3(0, 0, lerpf(-0.55, 0.62, d))
	var ang := lerpf(0.22, -0.62, d)
	(parts["arm_r"] as Node3D).rotation.y = ang
	(parts["arm_l"] as Node3D).rotation.y = -ang
	(parts["winch"] as Node3D).rotation.x = float(state["winch"])
	(parts["bolt"] as Node3D).visible = bool(state["loaded"])
	var claw := at_part("slider", Vector3(0, 0.12, 0.27))
	line("string_l", at_part("arm_l", Vector3(-SB.BA_ARM, 0, 0)), claw, 0.012)
	line("string_r", at_part("arm_r", Vector3(SB.BA_ARM, 0, 0)), claw, 0.012)
	line("haul", at_part("slider", Vector3(0, 0.1, 0.3)), at_part("winch", Vector3(0, 0.04, 0)), 0.012)


# ---------------------------------------------------------------- crew spots (engine space)

## The end of spoke k on the windlass wheel on side s (-1 left, 1 right).
func spoke(s: float, k: int) -> Vector3:
	var c: Vector3 = SB.T_WINCH if kind == "trebuchet" else SB.M_WINCH
	var x: float = SB.T_SPOKE_X if kind == "trebuchet" else SB.M_SPOKE_X
	var r: float = SB.T_SPOKE_R if kind == "trebuchet" else SB.M_SPOKE_R
	var ph := float(state["winch"]) + k * PI * 0.5
	return c + Vector3(s * x, r * cos(ph), r * sin(ph))


## The ballista's crank handle on side s.
func crank(s: float) -> Vector3:
	return at_part("winch", Vector3(s * 0.36, SB.BA_CRANK, 0))


func tiller(s: float) -> Vector3:
	return at_part("cradle", Vector3(s * 0.19, -0.04, 1.32))


## The ram's rope handle (row i, side s).
func handle(i: int, s: float) -> Vector3:
	return (parts["ram"] as Node3D).position + Vector3(s * 0.28, -0.1, SB.R_HANDLES[i])


## A point on a ladder's rail (s side, at distance along it), in its own frame.
static func rail(s: float, along: float) -> Vector3:
	return Vector3(s * SB.L_HALF * (1.0 - 0.18 * along / SB.L_LEN), along, 0)
