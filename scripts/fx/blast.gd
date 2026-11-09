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


static func material(kind: String) -> ShaderMaterial:
	var key := kind
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	match kind:
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


func setup(size_value: int, at: Vector3, seed_value: int, style_value := Style.FACET) -> Blast:
	size = size_value
	style = style_value
	origin = at
	spec = BlastSpecs.build(size, at, seed_value, density)
	_layer(spec["fire"], FxMesh.blob(), material("fire"), false)
	_layer(spec["smoke"], FxMesh.blob() if style == Style.FACET else FxMesh.quad(),
		material("facet" if style == Style.FACET else "soft"), style == Style.FACET)
	_layer(spec["clods"], FxMesh.clod(), material("clod"), true)
	_layer(spec["sparks"], FxMesh.spark(), material("spark"), false)
	light = OmniLight3D.new()
	light.position = at + Vector3(0, float(spec["fire_h"]), 0)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = float(spec["light_range"])
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.light_energy = 0.0
	add_child(light)
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
	var glow := fire_glow(t)
	for mi in layers:
		if mi.material_override == material("facet") or mi.material_override == material("soft"):
			mi.set_instance_shader_parameter("fire_glow", glow)
	# The flash (a few frames, very bright), then the fire's glow, then the embers.
	var fl: float = spec["flash"]
	var e := fl * exp(-t / 0.045) + fl * 0.22 * glow + float(spec["ember"]) * clampf(1.0 - t / float(spec["ember_t"]), 0.0, 1.0) * (1.0 if t > 0.3 else 0.0)
	light.light_energy = e * (1.6 if night else 1.0)
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
