class_name Building
extends Node3D
## Iron Front: one building as a scene node (Asset Builder Chat). Made by Buildings.make(kind).
## The footprint is centred on the origin, ground at y = 0, the front faces -Z. Size in 8 m tiles.
##
## Looks:
##   set_stage(s)     construction: 0 marked-out plot, 1 frame and scaffold, 2 half built, 3 finished
##   set_damage(d)    0 intact, 1 damaged (holes in the roof, scorched, fire and smoke), 2 ruined shell
##   collapse(u)      0..1: the four corners of the building fall outward and sink (call with the shared
##                    Blast at u = 0); at 1 it is the ruin
##   set_lights(on)   every window, lamp and searchlight on one switch (for the power system later)
##   far(on)          the cheap far look for the zoomed-out map
##   ghost(ok)        a see-through copy for placing: green where it fits, red where it is blocked
## step(dt, fx) runs the life: chimney smoke, flags, doors, signal arms, shutters, pigeons, sparks.
## marks: named points (door, entry, truck, rail, crew...) in the building frame; mark_world(name).

const TILE := 8.0

var kind := ""
var tiles := Vector2i.ONE
var g := BGeo.new()
var stage := 3
var damage := 0
var lights_on := false
var marks: Dictionary = {}
var life: Array[Dictionary] = []
var t := 0.0

var body: MeshInstance3D
var glow: MeshInstance3D
var parts: Node3D              # moving parts and props (only shown when finished and not ruined)
var lamps: Node3D              # light nodes and beam cones
var _looks: Dictionary = {}    # name -> Node3D, made on first use
var _glow_mat: StandardMaterial3D
var _beam_mat: StandardMaterial3D
var _chunks: Array[Node3D] = []
var _fire: Array[Vector3] = []


func _init() -> void:
	_glow_mat = BldParts.glow_material().duplicate()
	parts = Node3D.new()
	parts.name = "Parts"
	add_child(parts)
	lamps = Node3D.new()
	lamps.name = "Lamps"
	add_child(lamps)


func half_size() -> Vector2:
	return Vector2(tiles) * TILE * 0.5


## Called by Buildings.make after the builder has recorded the ops.
func finish() -> void:
	var tg := TrainGeo.new()
	g.replay(tg, "full")
	body = tg.make(self, "Body", BldParts.material())
	var gg := TrainGeo.new()
	g.replay(gg, "glow")
	glow = gg.make(self, "Glow", _glow_mat)
	# fire points for the damaged look: a few spots on the roofline
	var hs := half_size()
	var top := g.top_y()
	for k in 3:
		var u := BGeo._h(k, kind.hash())
		var v := BGeo._h(k + 9, kind.hash())
		_fire.append(Vector3((u - 0.5) * hs.x * 1.2, top * 0.8, (v - 0.5) * hs.y * 1.2))
	set_lights(false)


func tri_count() -> int:
	return (body.mesh as ArrayMesh).get_faces().size() / 3 + (glow.mesh as ArrayMesh).get_faces().size() / 3


func far_tris() -> int:
	return (_look("far").get_child(0) as MeshInstance3D).mesh.get_faces().size() / 3


func mark_world(nm: String) -> Vector3:
	return to_global(marks[nm] as Vector3)


# ------------------------------------------------------------------ parts and lights (used by the builders)

func part(nm: String, at := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = at
	parts.add_child(n)
	return n


func part_mesh(nm: String, at: Vector3, geo: TrainGeo, glowing := false) -> Node3D:
	var n := part(nm, at)
	geo.make(n, "Mesh", BldParts.material() if not glowing else _glow_mat)
	return n


## A warm lamp: an omni light (and its bulb is a glow op the builder adds).
func lamp(at: Vector3, col := Color(1.0, 0.78, 0.45), rng := 9.0, energy := 1.6) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	l.shadow_enabled = false
	lamps.add_child(l)
	return l


## A searchlight on a turning head: returns the head node (turn it about Y, tilt the child "Tilt" about X).
## The light points along the head's -Z.
func searchlight(at: Vector3, nm := "Search") -> Node3D:
	var head := part(nm, at)
	var tilt := Node3D.new()
	tilt.name = "Tilt"
	tilt.rotation.x = -0.25
	head.add_child(tilt)
	var sg := TrainGeo.new()
	sg.cyl(Vector3(0, 0, 0.35), Vector3(0, 0, -0.3), 0.42, 10, BldParts.METAL, 0.5)
	sg.box(Vector3(0, -0.5, 0.05), Vector3(0.08, 0.3, 0.08), BldParts.METAL)
	sg.make(tilt, "Mesh", BldParts.material())
	var lens := TrainGeo.new()
	lens.cyl(Vector3(0, 0, -0.29), Vector3(0, 0, -0.33), 0.44, 10, Color(1.0, 0.95, 0.8))
	lens.make(tilt, "Lens", _glow_mat)
	var s := SpotLight3D.new()
	s.name = "Light"
	s.light_color = Color(1.0, 0.95, 0.82)
	s.spot_range = 160.0
	s.spot_angle = 7.0
	s.light_energy = 14.0
	s.position = Vector3(0, 0, -0.4)
	tilt.add_child(s)
	# the visible beam: a long faint cone
	var bg := TrainGeo.new()
	bg.cyl(Vector3(0, 0, -0.4), Vector3(0, 0, -30.0), 0.42, 10, Color(1.0, 0.95, 0.8, 0.07), 3.6, 0)
	bg.cyl(Vector3(0, 0, -30.0), Vector3(0, 0, -60.0), 3.6, 10, Color(1.0, 0.95, 0.8, 0.03), 6.8, 0)
	if _beam_mat == null:
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.vertex_color_use_as_albedo = true
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_beam_mat.albedo_color = Color(1, 1, 1, 0.12)
	var beam := bg.make(tilt, "Beam", _beam_mat)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	life.append({"type": "search", "node": head, "phase": float(life.size()) * 1.7})
	return head


# ------------------------------------------------------------------ switches

func set_lights(on: bool) -> void:
	lights_on = on
	if _glow_mat:
		_glow_mat.emission_enabled = on
		_glow_mat.emission_energy_multiplier = 2.2 if on else 0.0
	if lamps:
		lamps.visible = on and damage < 2
	for n in _search_nodes():
		var tilt: Node3D = n.get_node("Tilt")
		(tilt.get_node("Light") as Light3D).visible = on
		(tilt.get_node("Beam") as Node3D).visible = on


func _search_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for l in life:
		if l["type"] == "search":
			out.append(l["node"])
	return out


func set_stage(s: int) -> void:
	stage = clampi(s, 0, 3)
	_refresh()


func set_damage(d: int) -> void:
	damage = clampi(d, 0, 2)
	_refresh()


func _refresh() -> void:
	for k: String in _looks:
		(_looks[k] as Node3D).visible = false
	for c in _chunks:
		c.visible = false
	var done := stage == 3
	body.visible = done and damage == 0
	glow.visible = done and damage == 0
	parts.visible = done and damage < 2
	lamps.visible = done and damage < 2 and lights_on
	if not done:
		match stage:
			0:
				_look("plot").visible = true
			1:
				_look("frame").visible = true
				_look("scaffold").visible = true
			2:
				_look("half").visible = true
				_look("scaffold").visible = true
	if stage in [1, 2] and workers == null:
		_make_workers()
	if workers:
		workers.visible = stage in [1, 2]
	elif damage == 1:
		_look("damaged").visible = true
	elif damage == 2:
		_look("ruin").visible = true


func far(on: bool) -> void:
	_look("far").visible = on
	if on:
		body.visible = false
		glow.visible = false
		parts.visible = false
		lamps.visible = false
	else:
		_refresh()


func ghost(ok: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Ghost"
	mi.mesh = body.mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.3, 1.0, 0.4, 0.38) if ok else Color(1.0, 0.25, 0.2, 0.38)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a tile outline on the ground under it
	var og := TrainGeo.new()
	var hs := half_size()
	for s: float in [-1.0, 1.0]:
		og.box(Vector3(0, 0.05, s * hs.y), Vector3(hs.x, 0.04, 0.12), Color.WHITE)
		og.box(Vector3(s * hs.x, 0.05, 0), Vector3(0.12, 0.04, hs.y), Color.WHITE)
	var om := og.make(mi, "Outline", m)
	om.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------ the other looks

func _look(nm: String) -> Node3D:
	if _looks.has(nm):
		return _looks[nm]
	var n := Node3D.new()
	n.name = "Look_" + nm
	add_child(n)
	_looks[nm] = n
	var tg := TrainGeo.new()
	var hs := half_size()
	match nm:
		"plot":
			BldParts.plot(tg, hs)
		"frame":
			g.replay(tg, "half")   # foundations come from tier 0; the frame is drawn over it
			tg = TrainGeo.new()
			_frame(tg)
		"scaffold":
			BldParts.scaffold(tg, g.core_rect(), g.top_y())
		"half":
			g.replay(tg, "half")
		"damaged":
			g.replay(tg, "damaged", -1, kind.hash())
		"ruin":
			g.replay(tg, "ruin", -1, kind.hash())
			BldParts.rubble(tg, hs, kind.hash())
		"far":
			g.replay(tg, "far")
		"ground":
			g.replay(tg, "ground")
	tg.make(n, "Mesh", BldParts.material())
	return n


## The frame stage: the foundations, then a timber skeleton where the walls will be.
func _frame(tg: TrainGeo) -> void:
	for i in g.ops.size():
		var o: Dictionary = g.ops[i]
		if int(o["tier"]) == 0:
			BGeo._emit(tg, o, o["col"], false)
		elif int(o["tier"]) == 1 and o["t"] == "box" and (o["h"] as Vector3).y > 0.9 and o["tag"] != "glow":
			var c: Vector3 = o["c"]
			var h: Vector3 = o["h"]
			var b: Basis = o["b"]
			var top := c.y + h.y * 0.8
			var bot := c.y - h.y
			var wood := BldParts.TIMBER_NEW
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var p := c + b * Vector3(sx * h.x, 0, sz * h.z)
					tg.cyl(Vector3(p.x, bot, p.z), Vector3(p.x, top, p.z), 0.1, 4, wood)
			# top plates along the long sides, and mid studs on long walls
			var long_x := h.x > h.z
			var n_st := int(maxf(h.x, h.z) / 1.4)
			for s: float in [-1.0, 1.0]:
				var a := c + b * (Vector3(-h.x, 0, s * h.z) if long_x else Vector3(s * h.x, 0, -h.z))
				var e := c + b * (Vector3(h.x, 0, s * h.z) if long_x else Vector3(s * h.x, 0, h.z))
				tg.cyl(Vector3(a.x, top, a.z), Vector3(e.x, top, e.z), 0.08, 4, wood)
				for k in n_st:
					var u := (float(k) + 0.5) / float(n_st)
					var p := a.lerp(e, u)
					if k % 2 == 0:
						tg.cyl(Vector3(p.x, bot, p.z), Vector3(p.x, top, p.z), 0.07, 4, wood)


## The fall: u 0..1. The four corner chunks tip outward about their outer bottom edge and sink.
func collapse(u: float) -> void:
	if _chunks.is_empty():
		for q in 4:
			var tg := TrainGeo.new()
			g.replay(tg, "chunk", q, kind.hash())
			var sx := 1.0 if q & 1 else -1.0
			var sz := 1.0 if q & 2 else -1.0
			var hs := half_size()
			var pivot := Vector3(sx * hs.x * 0.8, 0, sz * hs.y * 0.8)
			var holder := Node3D.new()
			holder.name = "Chunk%d" % q
			holder.position = pivot
			add_child(holder)
			tg.make(holder, "Mesh", BldParts.material(), Transform3D(Basis(), -pivot))
			_chunks.append(holder)
	for k: String in _looks:
		(_looks[k] as Node3D).visible = false
	body.visible = false
	glow.visible = false
	parts.visible = false
	lamps.visible = false
	var ruin := _look("ruin")
	ruin.visible = u > 0.55
	_look("ground").visible = u <= 0.55
	for q in 4:
		var c := _chunks[q]
		c.visible = u < 0.98
		var sx := 1.0 if q & 1 else -1.0
		var sz := 1.0 if q & 2 else -1.0
		var k := clampf((u - 0.05 * float(q)) / 0.75, 0.0, 1.0)
		var fall := k * k
		var axis := Vector3(sz, 0, -sx).normalized()
		c.transform.basis = Basis(axis, fall * (0.9 + 0.15 * float(q)))
		c.position.y = -fall * g.top_y() * 0.8
		c.scale = Vector3.ONE * lerpf(1.0, 0.85, fall)


# ------------------------------------------------------------------ life

func step(dt: float, fx: AirFx = null) -> void:
	t += dt
	if damage == 1 and fx and stage == 3:
		for p in _fire:
			if randf() < 0.5:
				fx.trail(to_global(p), Vector3.ZERO, 2.0)
	if stage < 3 or damage >= 2:
		return
	for l in life:
		match l["type"]:
			"smoke":
				if fx and randf() < dt * 6.0:
					fx.trail(to_global(l["at"]), Vector3(0.6, 1.2, 0.2), 1.0)
			"wave":
				var n: Node3D = l["node"]
				var base: Vector3 = l.get("base", Vector3.ZERO)
				n.rotation = base + (l["axis"] as Vector3) * sin(t * float(l["f"]) + float(l.get("p", 0.0))) * float(l["amp"])
			"spin":
				var n2: Node3D = l["node"]
				n2.rotation.y = t * float(l["f"])
			"orbit":
				var n3: Node3D = l["node"]
				var a := t * float(l["f"]) + float(l.get("p", 0.0))
				var c: Vector3 = l["c"]
				n3.position = c + Vector3(cos(a) * float(l["r"]), sin(a * 2.3) * 0.6, sin(a) * float(l["r"]))
				n3.rotation.y = -a
			"flicker":
				var lt: Light3D = l["light"]
				lt.light_energy = float(l["e"]) * (0.4 + 0.6 * absf(sin(t * 23.0 + sin(t * 7.0) * 3.0)))
				if fx and randf() < dt * 10.0:
					fx.trail(to_global(l["at"]), Vector3(0, 0.5, 0), 1.0)
			"search":
				var h: Node3D = l["node"]
				h.rotation.y = sin(t * 0.25 + float(l["phase"])) * 1.2 + float(l.get("base", 0.0))
			"call":
				(l["fn"] as Callable).call(t, dt)


# ------------------------------------------------------------------ men at the building (approved troops, read only)

var _men: Array[Dictionary] = []


## A soldier standing at a point of the building (building frame), facing yaw, posed by spec once in the tree.
## hands: optional {"hand_r": local point, "hand_l": local point} turned to world points at pose time, or a
## Callable returning world points (called once the building is in the tree). role picks the troop's kit.
func add_man(at: Vector3, yaw: float, spec: Dictionary, seed_value := 1, hands: Variant = {}, role := "") -> Soldier:
	var s := Soldier.new().setup(seed_value, 0, role)
	s.position = at
	s.rotation.y = yaw
	parts.add_child(s)
	_men.append({"s": s, "spec": spec, "hands": hands})
	if is_inside_tree():
		_pose_man(_men[-1])
	return s


## The builders shown while the building goes up (stages 1 and 2): one kneels hammering at the wall foot,
## one carries a plank along the front, one stands at the stack of timber. Riflemen stand in for the
## engineers (the engineer round is paused); made the first time a building is shown under construction.
var workers: Node3D


func _make_workers() -> void:
	workers = Node3D.new()
	workers.name = "Workers"
	add_child(workers)
	var r := g.core_rect()
	var front := r[1] - r[3] - 0.7
	var hammer_at := Vector3(r[0] - r[2] * 0.4, 0, front)
	var nail := Vector3(r[0] - r[2] * 0.4, 0.55, r[1] - r[3] - 0.05)
	var hm := _add_worker(hammer_at, PI, _CM.kneel_reach(), 301, func() -> Dictionary:
		var p := to_global(nail + Vector3(0, 0.12 * absf(sin(t * 7.0)), 0))
		return {"hand_r": p, "hand_l": to_global(nail + Vector3(-0.25, -0.05, 0))})
	life.append({"type": "call", "fn": func(_tt: float, _dt: float) -> void:
		if workers.visible and is_inside_tree():
			_pose_man(hm)})
	# the plank carrier and the plank
	var c_at := Vector3(r[0] + r[2] * 0.3, 0, front - 1.4)
	var pg := TrainGeo.new()
	pg.box(Vector3.ZERO, Vector3(0.12, 0.04, 1.6), BldParts.TIMBER_NEW)
	var plank := Node3D.new()
	plank.position = c_at + Vector3(0.0, 1.05, -0.45)
	plank.rotation.y = 1.2
	workers.add_child(plank)
	pg.make(plank, "Mesh", BldParts.material())
	_add_worker(c_at, PI * 0.5 + 1.2, _CM.standing("free"), 302, func() -> Dictionary:
		return {"hand_r": plank.to_global(Vector3(0.1, 0, -0.35)), "hand_l": plank.to_global(Vector3(-0.1, 0, 0.35))})
	# a stack of timber with a man at it
	var st := Vector3(r[0] + r[2] + 2.2, 0, r[1] - r[3] + 1.0)
	var sg := TrainGeo.new()
	for k in 4:
		sg.box(st + Vector3(0, 0.1 + float(k) * 0.16, 0), Vector3(0.7, 0.08, 1.8), BldParts.TIMBER_NEW.darkened(0.06 * float(k)))
	sg.make(workers, "Stack", BldParts.material())
	_add_worker(st + Vector3(-1.1, 0, -0.4), -PI * 0.5, _CM.standing("free"), 303)


func _add_worker(at: Vector3, yaw: float, spec: Dictionary, seed_value: int, hands: Variant = {}) -> Dictionary:
	var s := Soldier.new().setup(seed_value, 0, "loader")
	s.position = at
	s.rotation.y = yaw
	workers.add_child(s)
	var m := {"s": s, "spec": spec, "hands": hands}
	_men.append(m)
	if is_inside_tree():
		_pose_man(m)
	return m


const _CM := preload("res://scripts/units/anim/clips_mg.gd")


func _ready() -> void:
	for m in _men:
		_pose_man(m)


func _pose_man(m: Dictionary) -> void:
	var wh := {}
	if m["hands"] is Callable:
		wh = (m["hands"] as Callable).call()
	else:
		var hands: Dictionary = m["hands"]
		for k: String in hands:
			wh[k] = to_global(hands[k] as Vector3)
	(m["s"] as Soldier).pose_spec_world(m["spec"], wh)
