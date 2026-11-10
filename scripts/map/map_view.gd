class_name MapView
extends Node3D
## Iron Front: draws a MapData.
## - The map is split into chunks of 512 m, each one mesh with one material, so each chunk is one draw call. The
##   chunk meshes are built on worker threads.
## - The light and sky have three looks: day (bright and flat), night and fog (cool and moody, as in WW1).

enum Look { DAY, NIGHT, FOG }

var data: MapData
var mat: ShaderMaterial
var sun: DirectionalLight3D
var env: Environment
var look := Look.DAY
var chunks: Array[MeshInstance3D] = []
var details: Array[MeshInstance3D] = []   # rocks and bushes per chunk, drawn near the camera only
var woods: Array[Node3D] = []            # trees (near) and canopies (far) per chunk (map round 3)
var tree_meshes: Array[Mesh] = []
var tree_count := 0
var canopy_tris := 0
const TREE_RANGE := 700.0
const TREE_SHADOW_H := 220.0
var _tree_shadows := true
var _trees_shown := true
var scatter: GroundScatter               # grass tufts and flowers round the camera
var cam: RtsCamera
var detail_tris := 0
var tris := 0
var build_ms := 0
var _results: Array = []
var _mutex := Mutex.new()
var _fog := 0.0                       # the look's fog density close to the ground


func _ready() -> void:
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 700.0
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	set_look(Look.DAY)
	scatter = GroundScatter.new()
	scatter.mat = mat
	add_child(scatter)


func build(seed: int, w := 1000, h := 1500) -> void:
	for c in chunks + details:
		c.queue_free()
	for c in woods:
		c.queue_free()
	chunks.clear()
	details.clear()
	woods.clear()
	tree_count = 0
	canopy_tris = 0
	if tree_meshes.is_empty():
		tree_meshes = TreeKit.meshes()
	scatter.clear()
	data = MapGen.generate(seed, w, h)
	var t0 := Time.get_ticks_msec()
	var ncx := MapMesher.chunks_x(data)
	var ncz := MapMesher.chunks_z(data)
	_results.clear()
	_results.resize(ncx * ncz)
	var task := WorkerThreadPool.add_group_task(_mesh_one.bind(ncx), ncx * ncz, -1, true, "map chunks")
	WorkerThreadPool.wait_for_group_task_completion(task)
	tris = 0
	detail_tris = 0
	for i in _results.size():
		var r: Dictionary = _results[i]
		if (r["arrays"] as Array).is_empty():
			continue
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, r["arrays"])
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = mat
		mi.name = "chunk_%d" % i
		add_child(mi)
		chunks.append(mi)
		tris += int(r["tris"])
		var da: Array = r["detail"]
		if not da.is_empty():
			var dm := ArrayMesh.new()
			dm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, da)
			var di := MeshInstance3D.new()
			di.mesh = dm
			di.material_override = mat
			di.name = "detail_%d" % i
			di.visibility_range_end = 900.0
			di.visibility_range_end_margin = 100.0
			di.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(di)
			details.append(di)
			detail_tris += int(r["detail_tris"])
		_woods(r, i)
	_results.clear()
	scatter.data = data
	_outside()
	build_ms = Time.get_ticks_msec() - t0


func _mesh_one(i: int, ncx: int) -> void:
	var r := MapMesher.build(data, i % ncx, i / ncx)
	_mutex.lock()
	_results[i] = r
	_mutex.unlock()


## Low ground all round the map, below the edge skirt, so the map never ends in sky.
func _outside() -> void:
	var old := get_node_or_null("outside")
	if old != null:
		old.free()
	var sz := data.size_m()
	var pm := PlaneMesh.new()
	pm.size = Vector2(sz.x + 40000.0, sz.y + 40000.0)
	var mi := MeshInstance3D.new()
	mi.name = "outside"
	mi.mesh = pm
	mi.position = Vector3(sz.x * 0.5, MapMesher.SKIRT_Y + 0.5, sz.y * 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.34, 0.24)
	m.roughness = 1.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func set_look(l: Look) -> void:
	look = l
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	match l:
		Look.DAY:
			sun.rotation_degrees = Vector3(-52, 35, 0)
			sun.light_color = Color(1.0, 0.96, 0.88)
			sun.light_energy = 1.35
			sky.sky_top_color = Color(0.32, 0.55, 0.86)
			sky.sky_horizon_color = Color(0.70, 0.80, 0.90)
			sky.ground_horizon_color = Color(0.62, 0.70, 0.74)
			sky.ground_bottom_color = Color(0.35, 0.40, 0.36)
			sky.sky_energy_multiplier = 1.0
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 1.0
			env.fog_light_color = Color(0.74, 0.82, 0.90)
			_fog = 0.00008
			env.fog_sky_affect = 0.3
			env.tonemap_exposure = 1.05
			mat.set_shader_parameter("mood", 0.0)
			mat.set_shader_parameter("haze", 0.0)
		Look.NIGHT:
			sun.rotation_degrees = Vector3(-60, -40, 0)
			sun.light_color = Color(0.56, 0.66, 0.92)
			sun.light_energy = 0.5
			sky.sky_top_color = Color(0.02, 0.03, 0.07)
			sky.sky_horizon_color = Color(0.07, 0.09, 0.14)
			sky.ground_horizon_color = Color(0.06, 0.07, 0.10)
			sky.ground_bottom_color = Color(0.02, 0.02, 0.03)
			sky.sky_energy_multiplier = 1.0
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.22, 0.26, 0.36)
			env.ambient_light_energy = 0.9
			env.fog_light_color = Color(0.07, 0.09, 0.13)
			_fog = 0.00045
			env.fog_sky_affect = 1.0
			env.tonemap_exposure = 1.0
			mat.set_shader_parameter("mood", 1.0)
			mat.set_shader_parameter("haze", 0.0)
		Look.FOG:
			sun.rotation_degrees = Vector3(-40, 20, 0)
			sun.light_color = Color(0.86, 0.88, 0.92)
			sun.light_energy = 0.45
			sky.sky_top_color = Color(0.55, 0.59, 0.63)
			sky.sky_horizon_color = Color(0.60, 0.63, 0.66)
			sky.ground_horizon_color = Color(0.58, 0.61, 0.64)
			sky.ground_bottom_color = Color(0.45, 0.48, 0.5)
			sky.sky_energy_multiplier = 1.0
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.58, 0.62, 0.68)
			env.ambient_light_energy = 0.8
			env.fog_light_color = Color(0.60, 0.64, 0.68)
			_fog = 0.0024
			env.fog_sky_affect = 1.0
			env.tonemap_exposure = 1.0
			mat.set_shader_parameter("mood", 0.35)
			mat.set_shader_parameter("haze", 1.0)


func look_name() -> String:
	return ["day", "night", "fog"][look]


## Shadows and haze follow the camera height (as in WW1): fine shadows near, none from high up.
func follow(height: float) -> void:
	if cam != null:
		scatter.update(cam.target, height)
	sun.shadow_enabled = height < 1500.0
	# Tree shadows only from low down: from higher up they cost a lot and hardly show.
	# From higher than the tree range no tree can show, so hide them all (hidden nodes skip the culling too).
	var tv := height < TREE_RANGE
	if tv != _trees_shown:
		_trees_shown = tv
		for w: Node3D in woods:
			if w is MultiMeshInstance3D:
				w.visible = tv
	var ts := height < TREE_SHADOW_H
	if ts != _tree_shadows:
		_tree_shadows = ts
		for w: GeometryInstance3D in woods:
			if w is MultiMeshInstance3D:
				w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun.directional_shadow_max_distance = clampf(height * 1.8, 150.0, 900.0)
	# Thinner fog from high up, so the whole map stays clear; the fog look keeps more of it.
	var keep := 0.35 if look == Look.FOG else 0.06
	env.fog_density = _fog * clampf(900.0 / maxf(height, 1.0), keep, 1.0)


## Trees near the camera (one MultiMesh per tree kind per chunk) and the canopy lumps that stand in for the woods
## from far away.
func _woods(r: Dictionary, i: int) -> void:
	var lists: Array = r.get("trees", [])
	for k in lists.size():
		var l: Array = lists[k]
		if l.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tree_meshes[k]
		mm.instance_count = l.size()
		for q in l.size():
			mm.set_instance_transform(q, l[q])
		var mi := MultiMeshInstance3D.new()
		mi.name = "trees_%d_%d" % [i, k]
		mi.multimesh = mm
		mi.material_override = mat
		mi.visibility_range_end = TREE_RANGE
		mi.visibility_range_end_margin = 60.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _tree_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = _trees_shown
		add_child(mi)
		woods.append(mi)
		tree_count += l.size()
	var ca: Array = r.get("canopy", [])
	if not ca.is_empty():
		var cm := ArrayMesh.new()
		cm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ca)
		var ci := MeshInstance3D.new()
		ci.name = "canopy_%d" % i
		ci.mesh = cm
		ci.material_override = mat
		ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ci.visibility_range_begin = TREE_RANGE - 40.0
		ci.visibility_range_begin_margin = 60.0
		add_child(ci)
		woods.append(ci)
		canopy_tris += int(r.get("canopy_tris", 0))
