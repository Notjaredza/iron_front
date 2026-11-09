class_name SiegeGun
extends Node3D
## Iron Front: our railway siege gun (Question Chat, 2026-11-10). A heavy howitzer of about 28 cm on a 20 m
## girder carriage over two four-axle bogies, our own design in the trains' low-poly style. One normal engine
## can push it. Forward is -Z; the origin sits on the track centre at rail-top height (like a TrainCar).
##
## Moving parts: bogies swivel and their wheels turn (place(), roll()); four outriggers swing down to the
## ground (set_outriggers()); the top carriage traverses a few degrees and the cradle elevates (aim()); the
## barrel recoils (recoil()); the breech block drops open (set_breech()); the shell crane on the rear platform
## swings and lowers its hook (set_crane()). wreck = true builds the knocked-out look (charred, barrel broken).

const BOGIE_Z := 6.5
const AXLES := [-2.1, -0.7, 0.7, 2.1]
const WHEEL_R := 0.46
const GAUGE_X := 0.72
const BUF_Y := 1.05
const FRONT_Z := -10.0
const REAR_Z := 10.0
const DECK_Y := 1.9            # front walkway and girder top
const PLAT_Y := 2.35           # rear loading platform
const MOUNT := Vector3(0, 2.0, 0.6)
const TRUNNION_H := 1.3        # trunnion above the mount (3.3 m above the rails)
const BREECH_Z := 2.0          # barrel frame: breech face
const MUZZLE_Z := -10.0        # barrel frame: muzzle
const RECOIL := 1.2
const LOAD_ELEV := 0.0
const CRANE_POST := Vector3(0.95, PLAT_Y, 6.6)
const CRANE_TOP := 2.85        # post height above the platform
const JIB := 2.9
const OUTRIG := [Vector3(1.3, 1.25, -4.2), Vector3(-1.3, 1.25, -4.2), Vector3(1.3, 1.25, 4.6), Vector3(-1.3, 1.25, 4.6)]
const OUT_LEN := 2.65
const SHELL_LEN := 1.4
const SHELL_R := 0.14
const NEAR_END := 320.0

const OLIVE := Color(0.36, 0.40, 0.24)
const OLIVE_DARK := Color(0.28, 0.32, 0.19)
const OLIVE_LIGHT := Color(0.43, 0.47, 0.30)
const BLACK := Color(0.09, 0.09, 0.10)
const STEEL := Color(0.40, 0.40, 0.42)
const STEEL_DARK := Color(0.22, 0.22, 0.23)
const WHEEL := Color(0.13, 0.13, 0.14)
const WOOD := Color(0.47, 0.31, 0.18)
const BRASS := Color(0.66, 0.52, 0.28)
const BORE := Color(0.03, 0.03, 0.03)
const RUST := Color(0.40, 0.24, 0.15)
const CLOTH := Color(0.70, 0.64, 0.46)

var wreck := false
var body: Node3D
var mount: Node3D
var cradle: Node3D
var barrel: Node3D
var breech: Node3D
var jib: Node3D
var hook: Node3D
var bogies: Array[Node3D] = []
var wheels: Array[Node3D] = []
var outriggers: Array[Node3D] = []
var far: MeshInstance3D
var barrel_tip: Node3D         # the front half of the barrel (thrown off in the wreck scene)
var _roll := 0.0
var _mat: StandardMaterial3D


func setup(is_wreck := false) -> SiegeGun:
	wreck = is_wreck
	_mat = TrainParts.material()
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_build_body()
	_build_bogies()
	_build_outriggers()
	_build_gun()
	_build_crane()
	_build_far()
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == far:
			mi.visibility_range_begin = NEAR_END
		else:
			mi.visibility_range_end = NEAR_END
	aim(0.0, 0.0)
	set_outriggers(0.0)
	set_crane(0.0, 0.5)
	return self


func c(col: Color) -> Color:
	if not wreck:
		return col
	return col.lerp(Color(0.07, 0.065, 0.06), 0.72)


# ---------------------------------------------------------------- body

func _build_body() -> void:
	var g := TrainGeo.new()
	# Two deep side girders with a fish belly between the bogies, joined by cross members; the middle is
	# open between them (the barrel's well).
	for s: float in [-1.0, 1.0]:
		var x := s * 0.92
		var outline := PackedVector2Array([Vector2(-0.38, 0), Vector2(0.38, 0), Vector2(0.38, 1), Vector2(-0.38, 1)])
		var zs := [FRONT_Z + 0.2, -8.6, -4.6, 4.6, 8.6, REAR_Z - 0.2]
		var bot := [1.2, 1.2, 0.62, 0.62, 1.2, 1.2]
		for i in zs.size() - 1:
			var z0: float = zs[i]
			var z1: float = zs[i + 1]
			var r0 := PackedVector3Array([Vector3(x - 0.38, bot[i], z0), Vector3(x + 0.38, bot[i], z0), Vector3(x + 0.38, DECK_Y, z0), Vector3(x - 0.38, DECK_Y, z0)])
			var r1 := PackedVector3Array([Vector3(x - 0.38, bot[i + 1], z1), Vector3(x + 0.38, bot[i + 1], z1), Vector3(x + 0.38, DECK_Y, z1), Vector3(x - 0.38, DECK_Y, z1)])
			g.prism([r0, r1], c(OLIVE), 0)
		# Top flange, rivet strip and stiffeners.
		g.box(Vector3(x, DECK_Y + 0.03, 0), Vector3(0.44, 0.03, REAR_Z - 0.2), c(OLIVE_DARK))
		for k in 13:
			var z := -9.0 + 1.5 * k
			g.box(Vector3(x + s * 0.39, 1.45, z), Vector3(0.02, 0.38, 0.05), c(OLIVE_DARK))
	for z: float in [-9.4, -6.5, -3.6, 5.0, 6.5, 9.4]:
		g.box(Vector3(0, 1.55, z), Vector3(0.55, 0.3, 0.12), c(OLIVE_DARK))
	g.box(Vector3(0, 0.9, -0.2), Vector3(0.55, 0.12, 0.6), c(OLIVE_DARK))
	# Headstocks and buffers at the ends.
	for e: float in [-1.0, 1.0]:
		var z := e * (REAR_Z - 0.12)
		g.box(Vector3(0, 1.1, z), Vector3(1.35, 0.32, 0.12), c(OLIVE_DARK))
		for s: float in [-1.0, 1.0]:
			g.cyl(Vector3(s * 0.88, BUF_Y, z), Vector3(s * 0.88, BUF_Y, e * REAR_Z), 0.11, 8, c(BLACK))
			g.cyl(Vector3(s * 0.88, BUF_Y, e * REAR_Z), Vector3(s * 0.88, BUF_Y, e * (REAR_Z + 0.06)), 0.2, 10, c(STEEL))
		g.box(Vector3(0, BUF_Y, e * (REAR_Z + 0.04)), Vector3(0.06, 0.08, 0.1), c(BLACK))
	# Front walkway (chequer plate) and the rear loading platform on posts, railings, ladders.
	g.box(Vector3(0, DECK_Y + 0.07, -5.3), Vector3(1.35, 0.03, 4.4), c(STEEL_DARK))
	g.box(Vector3(0, PLAT_Y, 7.1), Vector3(1.55, 0.05, 2.75), c(WOOD))
	for k in 9:
		g.box(Vector3(0, PLAT_Y + 0.051, 4.6 + 0.6 * k), Vector3(1.5, 0.004, 0.02), c(WOOD).darkened(0.25))
	for s: float in [-1.0, 1.0]:
		for z: float in [4.6, 7.0, 9.6]:
			g.box(Vector3(s * 1.2, (DECK_Y + PLAT_Y) * 0.5, z), Vector3(0.06, (PLAT_Y - DECK_Y) * 0.5, 0.06), c(OLIVE_DARK))
		# Railing along the platform sides (open at the ladders).
		for z: float in [4.5, 5.5, 6.5, 8.9, 9.8]:
			g.box(Vector3(s * 1.52, PLAT_Y + 0.5, z), Vector3(0.025, 0.5, 0.025), c(STEEL_DARK))
		g.box(Vector3(s * 1.52, PLAT_Y + 0.98, 5.5), Vector3(0.02, 0.02, 1.0), c(STEEL_DARK))
		g.box(Vector3(s * 1.52, PLAT_Y + 0.98, 9.35), Vector3(0.02, 0.02, 0.45), c(STEEL_DARK))
		# Ladder at the platform's side gap (z 7.2 to 8.4).
		for r: float in [7.45, 8.15]:
			g.box(Vector3(s * 1.62, PLAT_Y * 0.5 + 0.2, r), Vector3(0.025, PLAT_Y * 0.5 + 0.2, 0.025), c(STEEL_DARK))
		for k in 7:
			g.box(Vector3(s * 1.62, 0.35 + 0.33 * k, 7.8), Vector3(0.02, 0.02, 0.35), c(STEEL_DARK))
		# Front walkway rails.
		for z: float in [-9.5, -7.0, -4.5, -2.0]:
			g.box(Vector3(s * 1.3, DECK_Y + 0.5, z), Vector3(0.025, 0.5, 0.025), c(STEEL_DARK))
		g.box(Vector3(s * 1.3, DECK_Y + 0.98, -5.75), Vector3(0.02, 0.02, 3.75), c(STEEL_DARK))
		# Tool boxes and a shell rack on the platform's rear corners.
		g.box(Vector3(s * 1.05, PLAT_Y + 0.25, 9.55), Vector3(0.38, 0.25, 0.32), c(OLIVE_DARK))
	# Rear rail and the loading tray behind the breech (on two brackets).
	g.box(Vector3(0, PLAT_Y + 0.98, 9.95), Vector3(1.5, 0.02, 0.02), c(STEEL_DARK))
	g.box(Vector3(0, 3.1, 3.8), Vector3(0.24, 0.035, 0.8), c(STEEL))
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 0.2, 3.17, 3.8), Vector3(0.02, 0.06, 0.8), c(STEEL))
		g.box(Vector3(s * 0.2, (PLAT_Y + 3.1) * 0.5, 4.5), Vector3(0.04, (3.1 - PLAT_Y) * 0.5, 0.04), c(STEEL_DARK))
	g.make(body, "Hull", _mat)


func _build_bogies() -> void:
	for e: float in [-1.0, 1.0]:
		var b := Node3D.new()
		b.name = "Bogie%s" % ("F" if e < 0.0 else "R")
		b.position = Vector3(0, 0, e * BOGIE_Z)
		add_child(b)
		var g := TrainGeo.new()
		for s: float in [-1.0, 1.0]:
			g.box(Vector3(s * 1.0, 0.72, 0), Vector3(0.06, 0.22, 2.75), c(BLACK))
			for z: float in AXLES:
				g.box(Vector3(s * 1.0, 0.5, z), Vector3(0.1, 0.1, 0.14), c(STEEL))
				g.box(Vector3(s * 1.0, 0.86, z), Vector3(0.07, 0.04, 0.5), c(BLACK))
		g.box(Vector3(0, 1.0, 0), Vector3(1.0, 0.12, 0.4), c(BLACK))
		g.cyl(Vector3(0, 1.0, 0), Vector3(0, 1.22, 0), 0.4, 10, c(STEEL_DARK))
		g.make(b, "Frame", _mat)
		bogies.append(b)
		for z: float in AXLES:
			var w := Node3D.new()
			w.position = Vector3(0, WHEEL_R, z)
			b.add_child(w)
			var wg := TrainGeo.new()
			wg.cyl(Vector3(-GAUGE_X + 0.06, 0, 0), Vector3(GAUGE_X - 0.06, 0, 0), 0.08, 6, c(STEEL))
			for s: float in [-1.0, 1.0]:
				var x0 := s * (GAUGE_X - 0.06)
				var x1 := s * (GAUGE_X + 0.06)
				wg.cyl(Vector3(x0 - s * 0.03, 0, 0), Vector3(x0, 0, 0), WHEEL_R + 0.035, 12, c(STEEL))
				wg.cyl(Vector3(x0, 0, 0), Vector3(x1, 0, 0), WHEEL_R, 12, c(WHEEL))
				wg.box(Vector3(x1 + s * 0.012, 0, 0), Vector3(0.012, 0.035, WHEEL_R * 0.86), c(STEEL_DARK))
			wg.make(w, "Wheel", _mat)
			wheels.append(w)


func _build_outriggers() -> void:
	for i in 4:
		var p: Vector3 = OUTRIG[i]
		var s := signf(p.x)
		var n := Node3D.new()
		n.name = "Outrigger%d" % i
		n.position = p
		body.add_child(n)
		var g := TrainGeo.new()
		# Built pointing outward along +X (or -X), swung by rotation about Z.
		g.box(Vector3(s * OUT_LEN * 0.5, 0, 0), Vector3(OUT_LEN * 0.5, 0.11, 0.13), c(OLIVE_DARK))
		g.box(Vector3(s * OUT_LEN * 0.5, 0.12, 0), Vector3(OUT_LEN * 0.45, 0.02, 0.15), c(OLIVE))
		g.cyl(Vector3(s * OUT_LEN, 0.0, 0), Vector3(s * OUT_LEN, -0.25, 0), 0.07, 6, c(STEEL))
		g.box(Vector3(s * OUT_LEN, -0.27, 0), Vector3(0.3, 0.03, 0.3), c(STEEL_DARK))
		g.cyl(Vector3(0, 0, -0.16), Vector3(0, 0, 0.16), 0.13, 8, c(STEEL_DARK))
		g.make(n, "Arm", _mat)
		outriggers.append(n)


func _build_gun() -> void:
	mount = Node3D.new()
	mount.name = "Mount"
	mount.position = MOUNT
	body.add_child(mount)
	var g := TrainGeo.new()
	# The top carriage: a low ring on the girders and two tall cheeks carrying the trunnions.
	g.cyl(Vector3(0, -0.1, 0), Vector3(0, 0.18, 0), 0.85, 14, c(OLIVE_DARK))
	for s: float in [-1.0, 1.0]:
		var outline := PackedVector2Array([Vector2(-1.6, 0.15), Vector2(1.4, 0.15), Vector2(0.55, TRUNNION_H + 0.45), Vector2(-0.5, TRUNNION_H + 0.45)])
		var b := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
		g.extrude(outline, Vector3(s * 0.5, 0, 0), Vector3(s * 0.66, 0, 0), c(OLIVE), b)
		g.cyl(Vector3(s * 0.66, TRUNNION_H, 0), Vector3(s * 0.78, TRUNNION_H, 0), 0.2, 10, c(STEEL_DARK))
		# Elevating arc (toothed quadrant) on the right cheek, its handwheel; a seat on the left.
		if s > 0.0:
			g.cyl(Vector3(0.8, TRUNNION_H - 0.35, 0.9), Vector3(0.92, TRUNNION_H - 0.35, 0.9), 0.22, 10, c(STEEL))
			g.box(Vector3(0.86, TRUNNION_H - 0.35, 0.9), Vector3(0.03, 0.2, 0.03), c(STEEL_DARK))
		else:
			g.box(Vector3(-0.9, 0.7, 0.8), Vector3(0.18, 0.04, 0.16), c(WOOD))
			g.box(Vector3(-0.78, TRUNNION_H + 0.15, 0.3), Vector3(0.06, 0.08, 0.14), c(BLACK))  # sight
	g.make(mount, "Carriage", _mat)
	cradle = Node3D.new()
	cradle.name = "Cradle"
	cradle.position = Vector3(0, TRUNNION_H, 0)
	mount.add_child(cradle)
	var cg := TrainGeo.new()
	# Sleeve round the barrel with recoil cylinders above and below.
	var sl := PackedVector2Array([Vector2(-0.48, -0.4), Vector2(0.48, -0.4), Vector2(0.55, 0.0), Vector2(0.48, 0.4), Vector2(-0.48, 0.4), Vector2(-0.55, 0.0)])
	cg.extrude(sl, Vector3(0, 0, 1.3), Vector3(0, 0, -2.6), c(OLIVE_DARK), Basis())
	for y: float in [0.52, -0.52]:
		cg.cyl(Vector3(0, y, 1.0), Vector3(0, y, -2.8), 0.14, 8, c(OLIVE))
	cg.box(Vector3(0.62, 0, 0.0), Vector3(0.08, 0.3, 0.3), c(STEEL_DARK))
	cg.make(cradle, "Sleeve", _mat)
	barrel = Node3D.new()
	barrel.name = "Barrel"
	cradle.add_child(barrel)
	var bg := TrainGeo.new()
	bg.cyl(Vector3(0, 0, BREECH_Z), Vector3(0, 0, 0.6), 0.44, 14, c(OLIVE_DARK))
	bg.cyl(Vector3(0, 0, 0.6), Vector3(0, 0, -3.0), 0.38, 14, c(OLIVE), 0.33)
	bg.cyl(Vector3(0, 0, -3.0), Vector3(0, 0, -4.6), 0.33, 14, c(OLIVE), 0.3)
	bg.box(Vector3(0, -0.5, 0.2), Vector3(0.1, 0.1, 1.2), c(STEEL_DARK))   # recoil lug
	bg.make(barrel, "Breech", _mat)
	# The front half is its own node so it can be broken off.
	barrel_tip = Node3D.new()
	barrel_tip.name = "Tip"
	barrel_tip.position = Vector3(0, 0, -4.6)
	barrel.add_child(barrel_tip)
	var tg := TrainGeo.new()
	var tip_len := -(MUZZLE_Z + 4.6)
	if wreck:
		tip_len = 1.2   # what is left on the cradle: a torn stub
	tg.cyl(Vector3(0, 0, 0), Vector3(0, 0, -tip_len), 0.3, 14, c(OLIVE), 0.26 if not wreck else 0.29)
	if not wreck:
		tg.cyl(Vector3(0, 0, -tip_len + 0.5), Vector3(0, 0, -tip_len), 0.3, 14, c(OLIVE_DARK))
		tg.cyl(Vector3(0, 0, -tip_len - 0.002), Vector3(0, 0, -tip_len - 0.003), 0.18, 12, BORE)
	else:
		for k in 7:
			var a := TAU * k / 7.0
			tg.box(Vector3(cos(a) * 0.27, sin(a) * 0.27, -tip_len - 0.1 * (k % 3)), Vector3(0.07, 0.07, 0.15), c(RUST))
	tg.make(barrel_tip, "Tube", _mat)
	breech = Node3D.new()
	breech.name = "BreechBlock"
	breech.position = Vector3(0, 0, BREECH_Z)
	barrel.add_child(breech)
	var kg := TrainGeo.new()
	kg.box(Vector3(0, 0, 0.12), Vector3(0.36, 0.36, 0.12), c(STEEL_DARK), Basis(), 0.2)
	kg.box(Vector3(-0.38, 0.0, 0.18), Vector3(0.05, 0.05, 0.2), c(STEEL))
	kg.make(breech, "Block", _mat)


func _build_crane() -> void:
	var g := TrainGeo.new()
	g.cyl(CRANE_POST, CRANE_POST + Vector3(0, CRANE_TOP, 0), 0.1, 8, c(OLIVE_DARK))
	g.box(CRANE_POST + Vector3(0, 0.05, 0), Vector3(0.22, 0.05, 0.22), c(STEEL_DARK))
	# The hand winch on the post (the crane man turns its handle from behind).
	g.cyl(CRANE_POST + Vector3(0, 1.0, 0.08), CRANE_POST + Vector3(0, 1.0, 0.34), 0.13, 10, c(STEEL_DARK))
	g.cyl(CRANE_POST + Vector3(0, 1.0, 0.34), CRANE_POST + Vector3(0, 1.0, 0.42), 0.03, 6, c(STEEL))
	g.make(body, "CranePost", _mat)
	jib = Node3D.new()
	jib.name = "Jib"
	jib.position = CRANE_POST + Vector3(0, CRANE_TOP, 0)
	body.add_child(jib)
	var jg := TrainGeo.new()
	# Jib along +X from the post top, a brace back down to the post, a hand winch on the post.
	jg.box(Vector3(JIB * 0.5, 0, 0), Vector3(JIB * 0.5, 0.07, 0.06), c(OLIVE_DARK))
	jg.cyl(Vector3(0, -0.9, 0), Vector3(JIB * 0.55, -0.04, 0), 0.04, 6, c(OLIVE_DARK))
	jg.cyl(Vector3(JIB, -0.08, 0), Vector3(JIB, 0.08, 0), 0.08, 8, c(STEEL))
	jg.make(jib, "Arm", _mat)
	hook = Node3D.new()
	hook.name = "Hook"
	jib.add_child(hook)
	var hg := TrainGeo.new()
	hg.box(Vector3(0, 0, 0), Vector3(0.05, 0.08, 0.04), c(STEEL_DARK))
	hg.box(Vector3(0, -0.12, 0), Vector3(0.2, 0.015, 0.015), c(STEEL))   # spreader bar for the shell tongs
	hg.make(hook, "Hook", _mat)


func _build_far() -> void:
	var g := TrainGeo.new()
	g.box(Vector3(0, 1.45, 0), Vector3(1.3, 0.45, 9.9), c(OLIVE))
	g.box(Vector3(0, 2.35, 7.1), Vector3(1.5, 0.05, 2.7), c(WOOD))
	for e: float in [-1.0, 1.0]:
		g.box(Vector3(0, 0.6, e * BOGIE_Z), Vector3(1.05, 0.45, 2.5), c(BLACK))
	g.box(Vector3(0, 2.9, 0.6), Vector3(0.65, 0.9, 1.2), c(OLIVE_DARK))
	far = g.make(self, "Far", _mat)
	far.mesh = far.mesh
	# The far barrel follows the real one (a simple box on the cradle).
	var bg := TrainGeo.new()
	bg.box(Vector3(0, 0, -4.0), Vector3(0.32, 0.32, 6.0 if not wreck else 3.0), c(OLIVE))
	var fb := bg.make(cradle, "FarBarrel", _mat)
	fb.visibility_range_begin = NEAR_END


# ---------------------------------------------------------------- moving parts

## Puts the gun on a path with its centre d along it: the body on the line between the bogie pivots, each
## bogie turned to its own spot on the line, the wheels turned by the distance run.
func place(path: TrackPath, d: float) -> void:
	var pf := path.point(d + BOGIE_Z)
	var pr := path.point(d - BOGIE_Z)
	var fwd := (pf - pr).normalized()
	var z := -fwd
	var x := Vector3.UP.cross(z).normalized()
	global_transform = Transform3D(Basis(x, Vector3.UP, z), (pf + pr) * 0.5)
	for i in 2:
		var dd := d + (BOGIE_Z if i == 0 else -BOGIE_Z)
		var bf := path.frame(dd)
		var local := global_transform.basis.inverse() * bf.basis
		bogies[i].basis = local.orthonormalized()
	roll(d - _roll)
	_roll = d


func roll(dist: float) -> void:
	for w in wheels:
		w.rotation.x -= dist / WHEEL_R


## Outriggers: 0 folded up against the girders, 1 down on the ground.
func set_outriggers(t: float) -> void:
	var e := t * t * (3.0 - 2.0 * t)
	var down := -asin(((OUTRIG[0] as Vector3).y - 0.3) / OUT_LEN)
	for i in 4:
		var s := signf((OUTRIG[i] as Vector3).x)
		var a := lerpf(PI * 0.5, down, e)
		outriggers[i].rotation = Vector3(0, 0, a * s)


## Traverse (radians, + = left) and elevation (radians, + = muzzle up).
func aim(yaw: float, elev: float) -> void:
	mount.rotation = Vector3(0, yaw, 0)
	cradle.rotation = Vector3(elev, 0, 0)


## Barrel recoil at time t after the shot: fast back, slow run out (t < 0: at rest).
func recoil(t: float) -> void:
	var back := 0.0
	if t >= 0.0 and t < 0.08:
		back = t / 0.08
	elif t >= 0.08 and t < 2.2:
		var u := (t - 0.08) / 2.12
		back = 1.0 - u * u * (3.0 - 2.0 * u)
	barrel.position.z = RECOIL * back


## The breech block: 0 shut, 1 dropped open below the bore.
func set_breech(t: float) -> void:
	var e := t * t * (3.0 - 2.0 * t)
	breech.position = Vector3(0, -0.62 * e, BREECH_Z + 0.06 * e)


## The crane: yaw (radians, 0 = jib out to the right over the ground, + turns the jib toward the front) and
## the hook's drop below the jib tip (metres).
func set_crane(yaw: float, drop: float) -> void:
	jib.rotation = Vector3(0, yaw, 0)
	hook.position = Vector3(JIB, -drop, 0)


const WINCH := Vector3(0.95, PLAT_Y + 1.0, 7.02)  # the winch handle's centre (turns about Z, radius 0.2)


## World points.
func muzzle() -> Vector3:
	return barrel.global_transform * Vector3(0, 0, MUZZLE_Z)


func breech_point() -> Vector3:
	return barrel.global_transform * Vector3(0, 0, BREECH_Z + 0.25)


func hook_point() -> Vector3:
	return hook.global_transform * Vector3(0, -0.14, 0)


func jib_tip() -> Vector3:
	return jib.global_transform * Vector3(JIB, 0, 0)


func tri_count(near := true) -> int:
	var n := 0
	for ch in find_children("*", "MeshInstance3D", true, false):
		var mi := ch as MeshInstance3D
		var is_far := mi == far or mi.name == "FarBarrel"
		if is_far == near or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			n += mi.mesh.surface_get_array_len(s) / 3
	return n


## Loose pieces for the crew to handle (built in their own frames).
static func shell_geo() -> TrainGeo:
	# Origin at the base, nose toward -Z.
	var g := TrainGeo.new()
	g.cyl(Vector3(0, 0, 0), Vector3(0, 0, -0.95), SHELL_R, 12, OLIVE_LIGHT)
	g.cyl(Vector3(0, 0, -0.1), Vector3(0, 0, -0.2), SHELL_R + 0.012, 12, BRASS)
	g.cyl(Vector3(0, 0, -0.95), Vector3(0, 0, -SHELL_LEN), SHELL_R, 12, Color(0.55, 0.20, 0.12), 0.03)
	g.box(Vector3(0, SHELL_R + 0.02, -0.55), Vector3(0.02, 0.03, 0.03), STEEL)   # lifting eye
	return g


static func charge_geo() -> TrainGeo:
	# A silk bag charge, origin at its rear, toward -Z.
	var g := TrainGeo.new()
	g.cyl(Vector3(0, 0, 0), Vector3(0, 0, -0.9), 0.15, 10, CLOTH)
	for z: float in [-0.25, -0.65]:
		g.cyl(Vector3(0, 0, z), Vector3(0, 0, z - 0.03), 0.155, 10, Color(0.5, 0.42, 0.3))
	return g


static func rammer_geo() -> TrainGeo:
	# The rammer pole: head at the origin, the staff back along +Z.
	var g := TrainGeo.new()
	g.cyl(Vector3(0, 0, 0), Vector3(0, 0, 0.12), 0.16, 10, WOOD)
	g.cyl(Vector3(0, 0, 0.12), Vector3(0, 0, 4.0), 0.035, 6, WOOD)
	return g


static func trolley_geo() -> TrainGeo:
	# The shell trolley: two small wheels, a cradle, a T handle. Origin at ground centre, cradle top at 0.45.
	var g := TrainGeo.new()
	g.box(Vector3(0, 0.38, 0), Vector3(0.25, 0.04, 0.75), OLIVE_DARK)
	for s: float in [-1.0, 1.0]:
		g.cyl(Vector3(s * 0.3, 0.18, 0), Vector3(s * 0.36, 0.18, 0), 0.18, 10, BLACK)
		g.box(Vector3(s * 0.2, 0.42, 0), Vector3(0.02, 0.05, 0.7), STEEL)
	g.cyl(Vector3(0, 0.38, 0.75), Vector3(0, 0.9, 1.3), 0.02, 6, STEEL)
	g.cyl(Vector3(-0.2, 0.9, 1.3), Vector3(0.2, 0.9, 1.3), 0.02, 6, STEEL)
	g.cyl(Vector3(0, 0.18, -0.3), Vector3(0, 0.18, 0.3), 0.03, 6, STEEL)
	return g
