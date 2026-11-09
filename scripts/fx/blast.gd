class_name Blast
extends Node3D
## Explosion round A (Building Chat 1, 2026-11-09): one explosion. Its particles are made once, when it starts,
## by BlastSpecs (each size its own shape); after that the GPU moves them (shaders/fx_*.gdshader) and this node
## only sets the time and the light. Time can be set by hand (set_time) so videos are exactly repeatable.
## Four draw layers: fire, smoke and dust, earth clods, sparks. Plus one light for the flash and the fire's glow.

enum Style { FACET, SOFT }

const SMOKE_FACET := preload("res://shaders/fx_smoke_facet.gdshader")
const SMOKE_SOFT := preload("res://shaders/fx_smoke_soft.gdshader")
const FIRE := preload("res://shaders/fx_fire.gdshader")
const CLOD := preload("res://shaders/fx_clod.gdshader")
const SPARK := preload("res://shaders/fx_spark.gdshader")
const FLOATS := 20                         # per particle: 12 transform, 4 colour, 4 custom
const FX_LAYER := 1 << 9                   # render layer 10: blast particles (flare shadows skip them)

static var _mats := {}
static var night := false
static var wind := Vector2(2.6, 0.9)

var size := 1
var style := Style.FACET
var t := 0.0
var auto := true                           # advance with the frame clock (false: the caller sets the time)
var spec: Dictionary
var layers: Array[MultiMeshInstance3D] = []
var light: OmniLight3D
var origin := Vector3.ZERO
var density := 1.0                        # 0.4..1: fewer particles when many blasts are live
var kind := ""                             # round B: "grenade", "mine_at", "flare_light"... ("" = a shell of a size)
var head: MeshInstance3D                  # a flare's burning head


static func material(mat_name: String) -> ShaderMaterial:
	var key := mat_name
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	match mat_name:
		"fire": m.shader = FIRE
		"facet": m.shader = SMOKE_FACET
		"soft": m.shader = SMOKE_SOFT
		"clod": m.shader = CLOD
		"spark": m.shader = SPARK
	_mats[key] = m
	return m


## Day or night for every blast (the smoke's fire glow and the hot clods are stronger at night).
static func set_night(on: bool) -> void:
	night = on
	for k: String in ["facet", "soft", "clod"]:
		material(k).set_shader_parameter("night", 1.0 if on else 0.0)


static func set_wind(w: Vector2) -> void:
	wind = w
	for k: String in ["facet", "soft"]:
		material(k).set_shader_parameter("wind", w)


## A shell blast of a size 1-8, or (round B) one of BlastKinds.KINDS by name: grenade, mines, flares, bullet hits...
## nrm: the surface's outward normal (bullet hits on metal plates).
func setup(what: Variant, at: Vector3, seed_value: int, style_value := Style.FACET, nrm := Vector3.UP) -> Blast:
	style = style_value
	origin = at
	if what is String:
		kind = what
		size = 0
		spec = BlastKinds.build(kind, at, seed_value, density, nrm)
	else:
		size = int(what)
		spec = BlastSpecs.build(size, at, seed_value, density)
	_layer(spec["fire"], FxMesh.blob(), material("fire"), false)
	_layer(spec["smoke"], FxMesh.blob() if style == Style.FACET else FxMesh.quad(),
		material("facet" if style == Style.FACET else "soft"), style == Style.FACET and not spec.has("flare"))
	_layer(spec["clods"], FxMesh.clod(), material("clod"), true)
	_layer(spec["sparks"], FxMesh.spark(), material("spark"), false)
	if float(spec["flash"]) > 0.0 or spec.has("flare"):
		light = OmniLight3D.new()
		light.position = at + Vector3(0, float(spec["fire_h"]), 0)
		light.light_color = Color(1.0, 0.72, 0.42)
		light.omni_range = float(spec["light_range"])
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.light_energy = 0.0
		add_child(light)
	if spec.has("flare"):
		var f: Dictionary = spec["flare"]
		head = MeshInstance3D.new()
		head.mesh = FxMesh.blob()
		head.scale = Vector3.ONE * float(f["head"])
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c: Color = f["col"]
		hm.albedo_color = Color(c.r * 6.0, c.g * 6.0, c.b * 6.0)
		head.material_override = hm
		add_child(head)
		light.light_color = c
		light.omni_attenuation = 0.5
		# The light flare throws real moving shadows (one light, the WW1 picture of a night attack).
		light.shadow_enabled = bool(f["light"])
		light.shadow_caster_mask = 0xFFFFF & ~FX_LAYER
	set_time(0.0)
	return self


func _layer(buf: PackedFloat32Array, mesh: Mesh, mat: ShaderMaterial, shadows: bool) -> void:
	var n := buf.size() / FLOATS
	if n == 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.buffer = buf
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.layers = FX_LAYER                     # only the fx layer (cameras and the sun see every layer), so the flare light can leave it out of its shadows
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r: float = spec["reach"]
	mi.custom_aabb = AABB(origin - Vector3(r, 5.0, r), Vector3(r * 2.0, float(spec["top"]) + 10.0, r * 2.0))
	mi.set_instance_shader_parameter("blast_p", origin)
	if mat == material("facet") or mat == material("soft"):
		mi.set_instance_shader_parameter("glow_r", float(spec["glow_r"]))
		mi.set_instance_shader_parameter("fire_h", float(spec["fire_h"]))
	add_child(mi)
	layers.append(mi)


func set_time(time: float) -> void:
	t = time
	for mi in layers:
		mi.set_instance_shader_parameter("t_now", t)
	var glow := fire_glow(t - float(spec.get("t_flash", 0.0)))
	for mi in layers:
		if mi.material_override == material("facet") or mi.material_override == material("soft"):
			mi.set_instance_shader_parameter("fire_glow", glow)
	if light == null:
		return
	if head != null:
		_flare_time(t)
		return
	# The flash (a few frames, very bright), then the fire's glow, then the embers. (A tunnel mine flashes late.)
	var tf := t - float(spec.get("t_flash", 0.0))
	var fl: float = spec["flash"]
	var e := 0.0
	if tf >= 0.0:
		e = fl * exp(-tf / 0.045) + fl * 0.22 * fire_glow(tf) + float(spec["ember"]) * clampf(1.0 - tf / float(spec["ember_t"]), 0.0, 1.0) * (1.0 if tf > 0.3 else 0.0)
	light.light_energy = e * (1.6 if night else 1.0)
	light.visible = e > 0.01


## A flare: the head and its light ride the path, burn with a flicker, and go out.
func _flare_time(time: float) -> void:
	var f: Dictionary = spec["flare"]
	var p := BlastKinds.flare_pos(f, time)
	head.position = p
	light.position = p
	var end_t: float = float(f["rise"]) + float(f["burn"])
	var burning := time < end_t
	head.visible = burning and time > 0.02
	var on := clampf(time / 0.4, 0.0, 1.0) * clampf((end_t - time) / 1.2, 0.0, 1.0)
	var flick := 1.0 + 0.1 * sin(time * 31.0) * sin(time * 7.3) + 0.05 * sin(time * 53.0)
	var e := float(f["energy"]) * on * flick
	if time < float(f["rise"]):
		e *= 0.35                                    # it burns brighter once it has burst at the top
	light.light_energy = e
	light.visible = e > 0.01


## How strongly the fire lights its own smoke at time t (0..1).
func fire_glow(time: float) -> float:
	var fl: float = spec["fire_life"]
	return clampf(minf(time / 0.06, 1.0) * (1.0 - time / (fl * 1.6)), 0.0, 1.0)


func done() -> bool:
	return t > float(spec["total"])


func _process(delta: float) -> void:
	if auto:
		set_time(t + delta)
		if done():
			queue_free()
