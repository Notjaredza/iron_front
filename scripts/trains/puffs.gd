class_name Puffs
extends MultiMeshInstance3D
## Iron Front: low-poly puffs in world space (chimney smoke, steam, dust, flames, burning smoke), drawn as one
## MultiMesh. Each puff is a faceted lump that grows, drifts, rises and fades.

const CAP := 600

var wind := Vector3(0.6, 0.0, 0.3)
var _p: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
static var _lump: Mesh
static var _mat_lit: StandardMaterial3D
static var _mat_glow: StandardMaterial3D

## Each kind: [colour start, colour end, life min, life max, size start, size end, rise, drag, glow]
const KINDS := {
	"smoke": [Color(0.30, 0.30, 0.32, 0.9), Color(0.62, 0.62, 0.64, 0.0), 2.6, 4.2, 0.55, 3.4, 1.6, 0.9, false],
	"steam": [Color(0.97, 0.97, 0.97, 0.85), Color(1.0, 1.0, 1.0, 0.0), 0.7, 1.3, 0.25, 1.3, 0.9, 2.2, false],
	"dust": [Color(0.55, 0.47, 0.36, 0.8), Color(0.62, 0.56, 0.47, 0.0), 1.4, 2.6, 0.5, 2.6, 0.35, 1.8, false],
	"flame": [Color(1.0, 0.82, 0.30, 1.0), Color(0.95, 0.28, 0.06, 0.0), 0.35, 0.7, 0.55, 0.15, 3.2, 1.0, true],
	"burn": [Color(0.12, 0.11, 0.11, 0.9), Color(0.30, 0.29, 0.29, 0.0), 3.0, 5.0, 0.8, 4.5, 2.6, 0.7, false],
	"spark": [Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.4, 0.1, 0.0), 0.3, 0.6, 0.12, 0.05, 0.0, 0.3, true],
}

var glow := false


static func make(glowing: bool, seed_value: int) -> Puffs:
	var p := Puffs.new()
	p.glow = glowing
	p._rng.seed = seed_value
	p.top_level = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _lump == null:
		var g := TrainGeo.new()
		g.lump(Vector3.ZERO, 0.5, Color.WHITE)
		_lump = g.to_mesh(null)
		_mat_lit = StandardMaterial3D.new()
		_mat_lit.vertex_color_use_as_albedo = true
		_mat_lit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_lit.roughness = 1.0
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.vertex_color_use_as_albedo = true
		_mat_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _lump
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	p.multimesh = mm
	p.material_override = _mat_glow if glowing else _mat_lit
	return p


## Adds one puff of a kind at a world point with a starting velocity; size scales it.
func add(kind: String, at: Vector3, vel: Vector3, size := 1.0) -> void:
	if _p.size() >= CAP:
		_p.pop_front()
	var k: Array = KINDS[kind]
	_p.append({"k": k, "pos": at, "vel": vel, "age": 0.0, "life": _rng.randf_range(k[2], k[3]),
		"s": size * _rng.randf_range(0.8, 1.2), "spin": Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0))})


func jitter(r: float) -> Vector3:
	return Vector3(_rng.randf_range(-r, r), _rng.randf_range(-r, r), _rng.randf_range(-r, r))


func clear() -> void:
	_p.clear()
	multimesh.visible_instance_count = 0


func step(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for p in _p:
		p["age"] += dt
		if p["age"] < p["life"]:
			keep.append(p)
	_p = keep
	var mm := multimesh
	var n := 0
	for p in _p:
		var k: Array = p["k"]
		var drag: float = k[7]
		var v: Vector3 = p["vel"]
		v = v.lerp(wind + Vector3(0, k[6], 0), clampf(drag * dt, 0.0, 1.0))
		p["vel"] = v
		p["pos"] += v * dt
		var t: float = p["age"] / p["life"]
		var sz: float = lerpf(k[4], k[5], sqrt(t)) * p["s"]
		var c: Color = (k[0] as Color).lerp(k[1], t)
		# fade in over the first tenth
		c.a *= clampf(t * 10.0, 0.0, 1.0)
		var b: Basis = (p["spin"] as Basis).scaled(Vector3(sz, sz * 0.85, sz))
		mm.set_instance_transform(n, Transform3D(b, p["pos"]))
		mm.set_instance_color(n, c)
		n += 1
	mm.visible_instance_count = n


func count() -> int:
	return _p.size()
