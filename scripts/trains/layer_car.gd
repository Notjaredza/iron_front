class_name LayerCar
extends TrainCar
## Iron Front: the track-laying train's own cars (Question Chat, 2026-11-10), in the trains' low-poly style.
## The train runs: crane car (front), two panel flats, the crew coach, then an engine and tender pushing.
## Forward is -Z; the origin is on the track centre at rail-top height, like every TrainCar.
##
## The crane car carries a long gantry boom on two portal towers. A trolley runs along the boom top from over
## the first flat (where it picks a ready-made 10 m track panel off the stack) to 12 m ahead of the buffers
## (where it lowers the panel onto the graded bed). The spreader beam hangs from the trolley on four ropes; the
## clip tool places it (set_spreader) so it can swing a little sideways on curves. The panel flats carry stacks
## of panels on timber battens (stack nodes, hidden one by one as they are used). wreck = true builds the
## knocked-out crane car: charred, the boom's front half (boom_tip) able to fold down to the ground.

const PANEL_LEN := 10.0
const PANEL_H := 0.28          # rail top to sleeper bottom
const LAYER_H := 0.36          # one stacked panel plus its battens
const CR_FRONT := -7.2
const CR_REAR := 7.2
const CR_AXLES := [-5.6, -4.3, 4.3, 5.6]
const CR_DECK := 1.25
const TOWER_Z := 4.2
const LEG_X := 1.62
const GIRDER_X := 0.8
const BOOM_BOT := 6.2
const BOOM_TOP := 6.9
const BOOM_F := -17.5
const BOOM_R := 16.0
const PORTAL_Y := 7.85
const KING := Vector3(0, 10.6, 0)
const PARK_Z := 13.6           # the trolley over the first flat's stack (straight track)
const REACH_Z := -12.4         # the trolley over a panel being laid
const HINGE := Vector3(0, 6.55, -4.2)
const FL_FRONT := -6.3
const FL_DECK := 1.15
const CO_FRONT := -6.0

const OLIVE := Color(0.36, 0.40, 0.24)
const OLIVE_DARK := Color(0.28, 0.32, 0.19)
const OLIVE_LIGHT := Color(0.43, 0.47, 0.30)
const STEEL_DARK := Color(0.22, 0.22, 0.23)
const EARTH := Color(0.56, 0.47, 0.34)
const EARTH_DARK := Color(0.53, 0.445, 0.32)
const PEG := Color(0.88, 0.86, 0.80)
const FLAG := Color(0.75, 0.16, 0.12)

var wreck := false
var trolley: Node3D
var spreader: Node3D
var boom_tip: Node3D
var stack: Array[Node3D] = []
var far_tip: MeshInstance3D
var _mat: StandardMaterial3D


static func build(kind_name: String, wreck_look := false, panels := 6) -> LayerCar:
	var car := LayerCar.new()
	car.kind = kind_name
	car.name = kind_name.capitalize()
	car.wreck = wreck_look
	car._mat = TrainParts.material()
	car.body = Node3D.new()
	car.body.name = "Body"
	car.add_child(car.body)
	match kind_name:
		"crane":
			car._crane()
		"flat":
			car._flat(panels)
		"coach":
			car._coach()
	car.finish_lod()
	if car.far_tip != null:
		car.far_tip.visibility_range_begin = NEAR_END
		car.far_tip.visibility_range_end = 0.0
	return car


func c(col: Color) -> Color:
	if not wreck:
		return col
	return col.lerp(Color(0.07, 0.065, 0.06), 0.72)


# ---------------------------------------------------------------- the track panel and the bed

## One ready-made panel: 14 sleepers with the two rails already spiked on, fishplates at both ends.
## Origin at the rail-top centre, the panel along z from -5 to +5.
static func panel_geo(charred := false) -> TrainGeo:
	var g := TrainGeo.new()
	var ch := charred
	for i in 14:
		var z := -PANEL_LEN * 0.5 + 0.357 + 0.714 * i
		var sc := TrainParts.SLEEPER if i % 3 else TrainParts.SLEEPER.darkened(0.12)
		g.box(Vector3(0, -0.21, z), Vector3(1.3, 0.07, 0.13), _dk(sc, ch))
		for s: float in [-1.0, 1.0]:
			g.box(Vector3(s * 0.7175, -0.145, z), Vector3(0.09, 0.006, 0.1), _dk(TrainParts.STEEL.darkened(0.3), ch))
	for s: float in [-1.0, 1.0]:
		var x := s * 0.7175
		g.box(Vector3(x, -0.08, 0), Vector3(0.012, 0.06, PANEL_LEN * 0.5), _dk(TrainParts.RAIL, ch))
		g.box(Vector3(x, -0.018, 0), Vector3(0.035, 0.018, PANEL_LEN * 0.5), _dk(TrainParts.RAIL.lightened(0.15), ch))
		g.box(Vector3(x, -0.135, 0), Vector3(0.065, 0.008, PANEL_LEN * 0.5), _dk(TrainParts.RAIL, ch))
		for e: float in [-1.0, 1.0]:
			for side: float in [-1.0, 1.0]:
				g.box(Vector3(x + side * 0.03, -0.075, e * (PANEL_LEN * 0.5 - 0.2)), Vector3(0.008, 0.035, 0.2), _dk(TrainParts.STEEL.darkened(0.25), ch))
	return g


## The two timber battens a stacked panel lies on (in the panel's frame).
static func battens_geo(g: TrainGeo) -> void:
	for z: float in [-3.2, 0.0, 3.2]:
		g.box(Vector3(0, -PANEL_H - 0.04, z), Vector3(1.25, 0.04, 0.07), TrainParts.WOOD_LIGHT)


## Where a panel laid from d0 to d0 + 10 along the path sits (a straight chord; on our curves it is within a few
## centimetres of the line).
static func panel_xf(path: TrackPath, d0: float) -> Transform3D:
	var a := path.point(d0)
	var b := path.point(d0 + PANEL_LEN)
	var z := -(b - a).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), (a + b) * 0.5)


## The graded bed the panels go down on: a low earth strip with sloped shoulders, survey pegs every 10 m at the
## panel joints and a red flag at the end of the planned route.
static func bed(path: TrackPath, d0: float, d1: float) -> MeshInstance3D:
	var g := TrainGeo.new()
	var step := 1.0
	var d := d0
	while d < d1 - 0.01:
		var seg := minf(step, d1 - d)
		var fa := path.frame(d)
		var fb := path.frame(d + seg)
		var top := -PANEL_H - 0.005
		var ring := func(f: Transform3D) -> PackedVector3Array:
			var o := f.origin
			var y0 := -o.y + 0.002
			return PackedVector3Array([o + f.basis.x * 2.2 + Vector3(0, top, 0), o - f.basis.x * 2.2 + Vector3(0, top, 0),
				o - f.basis.x * 3.1 + Vector3(0, y0, 0), o + f.basis.x * 3.1 + Vector3(0, y0, 0)])
		g.prism([ring.call(fa), ring.call(fb)], EARTH if int(d) % 4 < 2 else EARTH_DARK, 0)
		d += seg
	var dp := d0
	while dp <= d1 + 0.01:
		var f := path.frame(dp)
		for s: float in [-1.0, 1.0]:
			var base := f.origin + f.basis.x * s * 2.7
			base.y = 0.0
			g.box(base + Vector3(0, 0.2, 0), Vector3(0.025, 0.2, 0.025), TrainParts.WOOD_LIGHT)
			g.box(base + Vector3(0, 0.42, 0), Vector3(0.03, 0.03, 0.03), PEG)
		dp += PANEL_LEN
	var fe := path.frame(d1)
	var fbase := fe.origin + fe.basis.x * 2.9
	fbase.y = 0.0
	g.cyl(fbase, fbase + Vector3(0, 1.6, 0), 0.02, 5, TrainParts.WOOD_LIGHT)
	g.box(fbase + Vector3(0, 1.45, 0) + fe.basis.z * -0.22, Vector3(0.005, 0.13, 0.2), FLAG, fe.basis)
	var mi := MeshInstance3D.new()
	mi.name = "Bed"
	mi.mesh = g.to_mesh(TrainParts.material())
	return mi


# ---------------------------------------------------------------- crane car

func _crane() -> void:
	front_z = CR_FRONT
	rear_z = CR_REAR
	pivot_f = -4.95
	pivot_r = 4.95
	mass = 60000.0
	col_box = AABB(Vector3(-1.8, 0.0, CR_FRONT), Vector3(3.6, 8.0, CR_REAR - CR_FRONT))
	com_y = 3.0
	for z: float in CR_AXLES:
		TrainParts._wheelset(self, z, 0.46, false)
	var g := TrainGeo.new()
	_frame(g, 6.82, CR_AXLES, CR_DECK)
	g.box(Vector3(0, CR_DECK + 0.02, 0), Vector3(1.38, 0.05, 6.82), c(OLIVE_DARK))
	for s: float in [-1.0, 1.0]:
		for k in 14:
			g.box(Vector3(s * 1.39, CR_DECK - 0.1, -6.5 + k * 1.0), Vector3(0.012, 0.012, 0.012), c(TrainParts.BLACK))
	# The winch house between the towers: steam boiler and hoist engine inside, a chimney through the roof.
	var cab := PackedVector2Array()
	cab.append(Vector2(-1.25, CR_DECK + 0.05))
	cab.append(Vector2(1.25, CR_DECK + 0.05))
	cab.append(Vector2(1.25, 3.2))
	cab.append(Vector2(0.6, 3.45))
	cab.append(Vector2(-0.6, 3.45))
	cab.append(Vector2(-1.25, 3.2))
	g.extrude(cab, Vector3(0, 0, -3.1), Vector3(0, 0, 2.9), c(OLIVE))
	for s: float in [-1.0, 1.0]:
		for z: float in [-2.2, -0.9, 1.6]:
			g.box(Vector3(s * 1.255, 2.55, z), Vector3(0.006, 0.32, 0.4), c(TrainParts.GLASS))
			g.box(Vector3(s * 1.262, 2.55, z), Vector3(0.006, 0.36, 0.03), c(OLIVE_DARK))
		g.box(Vector3(s * 1.258, 2.05, 0.35), Vector3(0.008, 0.78, 0.42), c(OLIVE_DARK))   # door
		g.box(Vector3(s * 1.27, 2.0, 0.65), Vector3(0.02, 0.05, 0.03), c(TrainParts.STEEL))
		g.box(Vector3(s * 1.27, 1.05, 0.35), Vector3(0.05, 0.03, 0.3), c(TrainParts.STEEL))  # step
	g.box(Vector3(0, 3.47, -0.1), Vector3(0.62, 0.02, 3.02), c(TrainParts.ROOF))
	g.cyl(Vector3(0.6, 3.3, 1.8), Vector3(0.6, 4.3, 1.8), 0.17, 10, c(TrainParts.BLACK))
	g.cyl(Vector3(0.6, 4.3, 1.8), Vector3(0.6, 4.36, 1.8), 0.22, 10, c(TrainParts.BLACK))
	g.cyl(Vector3(-0.5, 3.4, 2.1), Vector3(-0.5, 3.75, 2.1), 0.07, 6, c(TrainParts.BRASS))   # whistle / safety valve
	# Front deck: two rope drums (the hoist ropes run up to the trolley), a lamp, the front rail.
	for x: float in [-0.55, 0.55]:
		g.cyl(Vector3(x - 0.35, 1.75, -5.4), Vector3(x + 0.35, 1.75, -5.4), 0.32, 12, c(TrainParts.BLACK))
		g.cyl(Vector3(x - 0.25, 1.75, -5.4), Vector3(x + 0.25, 1.75, -5.4), 0.34, 12, c(STEEL_DARK))
	g.box(Vector3(0, 1.45, -5.4), Vector3(1.0, 0.15, 0.3), c(OLIVE_DARK))
	g.box(Vector3(0, 1.75, -6.75), Vector3(0.14, 0.18, 0.1), c(TrainParts.BLACK))
	g.box(Vector3(0, 1.75, -6.86), Vector3(0.09, 0.09, 0.01), TrainParts.LAMP)
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 1.3, CR_DECK + 0.5, -6.7), Vector3(0.025, 0.5, 0.025), c(TrainParts.STEEL))
		g.box(Vector3(s * 1.3, CR_DECK + 0.5, 6.7), Vector3(0.025, 0.5, 0.025), c(TrainParts.STEEL))
	g.box(Vector3(0, CR_DECK + 0.98, -6.7), Vector3(1.3, 0.02, 0.02), c(TrainParts.STEEL))
	# Rear deck: the water tank and coal box for the winch boiler.
	g.box(Vector3(0, 1.95, 5.5), Vector3(1.15, 0.65, 1.1), c(OLIVE_DARK), Basis(), 0.12)
	g.cyl(Vector3(0.6, 2.6, 5.2), Vector3(0.6, 2.7, 5.2), 0.18, 8, c(TrainParts.BLACK))
	# The two portal towers: legs on brackets out past the deck edge (the panel passes between them), knee braces,
	# a top beam above the trolley's path, brackets in to the boom girders.
	for e: float in [-1.0, 1.0]:
		var z := e * TOWER_Z
		for s: float in [-1.0, 1.0]:
			var x := s * LEG_X
			g.box(Vector3(s * 1.5, CR_DECK - 0.05, z), Vector3(0.2, 0.08, 0.25), c(OLIVE_DARK))
			g.box(Vector3(x, (CR_DECK + PORTAL_Y) * 0.5, z), Vector3(0.1, (PORTAL_Y - CR_DECK) * 0.5, 0.16), c(OLIVE), Basis(), 0.03)
			g.box(Vector3(s * (GIRDER_X + LEG_X) * 0.5, BOOM_BOT - 0.12, z), Vector3((LEG_X - GIRDER_X) * 0.5, 0.1, 0.12), c(OLIVE_DARK))
			# Knee braces fore and aft in the leg's plane.
			for f: float in [-1.0, 1.0]:
				var p0 := Vector3(x, CR_DECK + 0.6, z + f * 1.3)
				var p1 := Vector3(x, CR_DECK + 2.4, z)
				g.cyl(p0, p1, 0.05, 6, c(OLIVE_DARK))
			g.box(Vector3(x, CR_DECK + 0.62, z), Vector3(0.06, 0.06, 1.35), c(OLIVE_DARK))
		g.box(Vector3(0, PORTAL_Y + 0.08, z), Vector3(LEG_X + 0.12, 0.12, 0.18), c(OLIVE_DARK))
		for s: float in [-1.0, 1.0]:
			g.cyl(Vector3(s * LEG_X, PORTAL_Y - 0.6, z), Vector3(s * 0.7, PORTAL_Y, z), 0.04, 6, c(OLIVE_DARK))
	# The king post over the middle and its stays to both ends of the boom (the front pair goes with the tip).
	for e: float in [-1.0, 1.0]:
		for s: float in [-1.0, 1.0]:
			g.cyl(Vector3(s * LEG_X, PORTAL_Y + 0.15, e * TOWER_Z), KING, 0.06, 6, c(OLIVE_DARK))
	g.box(KING + Vector3(0, 0.05, 0), Vector3(0.18, 0.12, 0.18), c(STEEL_DARK))
	for s: float in [-1.0, 1.0]:
		g.cyl(KING, Vector3(s * GIRDER_X, BOOM_TOP, BOOM_R - 0.3), 0.025, 4, c(TrainParts.STEEL))
	# The rear part of the boom (over the cab and the first flat).
	_boom(g, HINGE.z, BOOM_R, false)
	g.make(body, "Hull", _mat)
	# The front part of the boom, its own node about the hinge at the front tower.
	boom_tip = Node3D.new()
	boom_tip.name = "BoomTip"
	boom_tip.position = HINGE
	add_child(boom_tip)
	var tg := TrainGeo.new()
	_boom(tg, BOOM_F, HINGE.z, true)
	for s: float in [-1.0, 1.0]:
		var a := Vector3(s * GIRDER_X, BOOM_TOP, BOOM_F + 0.3) - HINGE
		var k := KING - HINGE
		if wreck:
			# The snapped stay hangs from the tip.
			tg.cyl(a, a + Vector3(0.1, -1.8, 1.2), 0.025, 4, c(TrainParts.STEEL))
		else:
			tg.cyl(k, a, 0.025, 4, c(TrainParts.STEEL))
	# The boom-end lamp and a buffer stop for the trolley.
	tg.box(Vector3(0, BOOM_BOT - 0.15, BOOM_F + 0.15) - HINGE, Vector3(0.12, 0.14, 0.1), c(TrainParts.BLACK))
	tg.box(Vector3(0, BOOM_BOT - 0.15, BOOM_F + 0.04) - HINGE, Vector3(0.08, 0.08, 0.01), TrainParts.LAMP if not wreck else c(TrainParts.GLASS))
	tg.make(boom_tip, "Boom", _mat)
	# The trolley on the girder tops and the spreader beam below it.
	trolley = Node3D.new()
	trolley.name = "Trolley"
	add_child(trolley)
	var hg := TrainGeo.new()
	hg.box(Vector3(0, 0.2, 0), Vector3(1.0, 0.1, 0.75), c(OLIVE_DARK))
	for s: float in [-1.0, 1.0]:
		for f: float in [-1.0, 1.0]:
			hg.cyl(Vector3(s * GIRDER_X - 0.06, 0.12, f * 0.5), Vector3(s * GIRDER_X + 0.06, 0.12, f * 0.5), 0.12, 8, c(TrainParts.BLACK))
	hg.cyl(Vector3(-0.55, 0.42, 0), Vector3(0.55, 0.42, 0), 0.2, 10, c(STEEL_DARK))
	hg.box(Vector3(0, 0.42, 0), Vector3(0.6, 0.06, 0.24), c(OLIVE_DARK))
	for s: float in [-1.0, 1.0]:
		for f: float in [-1.0, 1.0]:
			hg.cyl(Vector3(s * 0.3 - 0.04, 0.0, f * 0.5), Vector3(s * 0.3 + 0.04, 0.0, f * 0.5), 0.09, 8, c(TrainParts.STEEL))
	hg.make(trolley, "Trolley", _mat)
	spreader = Node3D.new()
	spreader.name = "Spreader"
	add_child(spreader)
	var sg := TrainGeo.new()
	sg.box(Vector3.ZERO, Vector3(0.08, 0.12, 3.5), c(OLIVE_DARK))
	for z: float in [-3.2, 3.2]:
		sg.box(Vector3(0, -0.06, z), Vector3(0.85, 0.05, 0.06), c(OLIVE_DARK))
		for s: float in [-1.0, 1.0]:
			sg.box(Vector3(s * 0.72, -0.16, z), Vector3(0.03, 0.06, 0.03), c(TrainParts.STEEL))
	for z: float in [-0.5, 0.5]:
		sg.box(Vector3(0, 0.15, z), Vector3(0.12, 0.04, 0.04), c(TrainParts.STEEL))
	sg.make(spreader, "Beam", _mat)
	set_trolley(PARK_Z)
	set_spreader(Transform3D(Basis(), Vector3(0, 5.6, PARK_Z)))
	marks["chimney"] = Vector3(0.6, 4.4, 1.8)
	marks["valve"] = Vector3(-0.5, 3.8, 2.1)
	marks["lamp"] = Vector3(0, BOOM_BOT - 0.15, BOOM_F)
	_crane_far()


## A lattice box girder pair along the boom from z0 to z1 (in the hull's frame, or the tip's when local).
func _boom(g: TrainGeo, z0: float, z1: float, local: bool) -> void:
	var o := HINGE if local else Vector3.ZERO
	for s: float in [-1.0, 1.0]:
		var x := s * GIRDER_X
		g.box(Vector3(x, BOOM_TOP - 0.06, (z0 + z1) * 0.5) - o, Vector3(0.12, 0.06, (z1 - z0) * 0.5), c(OLIVE))
		g.box(Vector3(x, BOOM_BOT + 0.06, (z0 + z1) * 0.5) - o, Vector3(0.12, 0.06, (z1 - z0) * 0.5), c(OLIVE))
		g.box(Vector3(x, BOOM_TOP + 0.015, (z0 + z1) * 0.5) - o, Vector3(0.04, 0.015, (z1 - z0) * 0.5), c(STEEL_DARK))
		var bays := maxi(1, int(round((z1 - z0) / 1.4)))
		var bl := (z1 - z0) / float(bays)
		for i in bays + 1:
			var z := z0 + bl * i
			g.box(Vector3(x, (BOOM_TOP + BOOM_BOT) * 0.5, z) - o, Vector3(0.05, (BOOM_TOP - BOOM_BOT) * 0.5 - 0.1, 0.05), c(OLIVE_DARK))
			if i < bays:
				var up := (i % 2 == 0)
				var a := Vector3(x, BOOM_BOT + 0.1 if up else BOOM_TOP - 0.1, z)
				var b := Vector3(x, BOOM_TOP - 0.1 if up else BOOM_BOT + 0.1, z + bl)
				g.cyl(a - o, b - o, 0.035, 4, c(OLIVE_DARK))
	# Cross ties under the girders (clear of the ropes in the middle: they sit at the bottom chord).
	var n := maxi(1, int((z1 - z0) / 3.0))
	for i in n + 1:
		var z := lerpf(z0 + 0.2, z1 - 0.2, float(i) / float(n))
		for s: float in [-1.0, 1.0]:
			g.box(Vector3(s * 0.62, BOOM_BOT + 0.04, z) - o, Vector3(0.18, 0.04, 0.05), c(OLIVE_DARK))


func _crane_far() -> void:
	var fg := TrainGeo.new()
	fg.box(Vector3(0, 0.7, 0), Vector3(1.1, 0.55, 6.8), c(TrainParts.BLACK))
	fg.box(Vector3(0, 2.35, -0.1), Vector3(1.25, 1.1, 3.0), c(OLIVE))
	for e: float in [-1.0, 1.0]:
		for s: float in [-1.0, 1.0]:
			fg.box(Vector3(s * LEG_X, 4.55, e * TOWER_Z), Vector3(0.1, 3.3, 0.15), c(OLIVE))
		fg.box(Vector3(0, PORTAL_Y + 0.08, e * TOWER_Z), Vector3(1.7, 0.12, 0.18), c(OLIVE_DARK))
	fg.box(Vector3(0, 6.55, (BOOM_R + HINGE.z) * 0.5), Vector3(0.95, 0.35, (BOOM_R - HINGE.z) * 0.5), c(OLIVE))
	far = fg.make(self, "Far", _mat)
	var tg := TrainGeo.new()
	tg.box(Vector3(0, 0, (BOOM_F - HINGE.z) * 0.5), Vector3(0.95, 0.35, (HINGE.z - BOOM_F) * 0.5), c(OLIVE))
	far_tip = tg.make(boom_tip, "FarTip", _mat)


## The trolley's place along the boom (car z).
func set_trolley(z: float) -> void:
	trolley.position = Vector3(0, BOOM_TOP, z)


## The spreader's place (car frame).
func set_spreader(xf: Transform3D) -> void:
	spreader.transform = xf


## Boom tip folded down by a radians (the wreck).
func set_tip(a: float) -> void:
	boom_tip.rotation = Vector3(-a, 0, 0)


## The four hoist ropes, trolley sheave to spreader eye (world points).
func ropes() -> Array:
	var out := []
	for s: float in [-1.0, 1.0]:
		for f: float in [-1.0, 1.0]:
			var a := trolley.global_transform * Vector3(s * 0.3, -0.02, f * 0.5)
			var b := spreader.global_transform * Vector3(s * 0.1, 0.17, f * 0.5)
			out.append([a, b])
	return out


## The four chain hooks under the spreader (world points).
func hooks() -> Array:
	var out := []
	for s: float in [-1.0, 1.0]:
		for z: float in [-3.2, 3.2]:
			out.append(spreader.global_transform * Vector3(s * 0.72, -0.2, z))
	return out


## Where a panel hanging from the spreader sits (car frame), and back.
const HANG := 0.95


static func hang_from(sp: Transform3D) -> Transform3D:
	return sp * Transform3D(Basis(), Vector3(0, -HANG, 0))


static func spreader_for(panel: Transform3D) -> Transform3D:
	return panel * Transform3D(Basis(), Vector3(0, HANG, 0))


# ---------------------------------------------------------------- panel flat

func _flat(panels: int) -> void:
	front_z = FL_FRONT
	rear_z = -FL_FRONT
	pivot_f = -4.3
	pivot_r = 4.3
	mass = 14000.0 + 3800.0 * panels
	col_box = AABB(Vector3(-1.4, 0.0, FL_FRONT), Vector3(2.8, 1.5 + LAYER_H * panels, -2.0 * FL_FRONT))
	com_y = 1.4
	for z: float in [-4.3, 4.3]:
		TrainParts._wheelset(self, z, 0.46, false)
	var g := TrainGeo.new()
	_frame(g, -FL_FRONT - 0.38, [-4.3, 4.3], FL_DECK)
	g.box(Vector3(0, FL_DECK + 0.0, 0), Vector3(1.32, 0.05, -FL_FRONT - 0.42), c(TrainParts.WOOD))
	for k in 12:
		g.box(Vector3(0, FL_DECK + 0.052, -5.5 + k * 1.0), Vector3(1.31, 0.003, 0.012), c(TrainParts.WOOD_DARK))
	# Stakes along the sides keep the stack from sliding; chain lashings over the top.
	for s: float in [-1.0, 1.0]:
		for z: float in [-5.4, -2.7, 0.0, 2.7, 5.4]:
			g.box(Vector3(s * 1.36, FL_DECK + 0.75, z), Vector3(0.05, 0.75, 0.06), c(TrainParts.WOOD_DARK))
			g.box(Vector3(s * 1.36, FL_DECK - 0.1, z), Vector3(0.07, 0.08, 0.08), c(TrainParts.BLACK))
	g.make(body, "Deck", _mat)
	var top := FL_DECK + 0.05
	for i in panels:
		var n := Node3D.new()
		n.name = "Panel%d" % i
		n.position = Vector3(0, top + 0.08 + PANEL_H + LAYER_H * i, 0)
		body.add_child(n)
		var pg := panel_geo(wreck)
		battens_geo(pg)
		pg.make(n, "Panel", _mat)
		stack.append(n)
	var fg := TrainGeo.new()
	fg.box(Vector3(0, 0.7, 0), Vector3(1.0, 0.5, -FL_FRONT - 0.4), c(TrainParts.BLACK))
	if panels > 0:
		fg.box(Vector3(0, top + LAYER_H * panels * 0.5, 0), Vector3(1.3, LAYER_H * panels * 0.5, 5.0), c(TrainParts.SLEEPER))
	far = fg.make(self, "Far", _mat)


## The stacked panel i's frame on this flat (car frame).
func stack_xf(i: int) -> Transform3D:
	return Transform3D(Basis(), Vector3(0, FL_DECK + 0.05 + 0.08 + PANEL_H + LAYER_H * i, 0))


## Shows only the bottom n panels of the stack.
func set_stack(n: int) -> void:
	for i in stack.size():
		stack[i].visible = i < n


# ---------------------------------------------------------------- crew coach

func _coach() -> void:
	front_z = CO_FRONT
	rear_z = -CO_FRONT
	pivot_f = -3.6
	pivot_r = 3.6
	mass = 22000.0
	col_box = AABB(Vector3(-1.45, 0.0, CO_FRONT), Vector3(2.9, 3.8, -2.0 * CO_FRONT))
	com_y = 1.8
	for z: float in [-3.6, 3.6]:
		TrainParts._wheelset(self, z, 0.48, false)
	var g := TrainGeo.new()
	_frame(g, -CO_FRONT - 0.38, [-3.6, 3.6], 1.1)
	g.box(Vector3(0, 1.12, 0), Vector3(1.38, 0.04, -CO_FRONT - 0.42), c(TrainParts.WOOD_DARK))
	# The body: planked sides, a row of windows, doors onto end platforms.
	var bz := 4.8
	g.box(Vector3(0, 2.2, 0), Vector3(1.3, 1.04, bz), c(TrainParts.BODY))
	for s: float in [-1.0, 1.0]:
		for k in 6:
			var z := -4.0 + k * 1.6
			g.box(Vector3(s * 1.303, 2.55, z), Vector3(0.006, 0.3, 0.42), c(TrainParts.GLASS))
			g.box(Vector3(s * 1.31, 2.55, z), Vector3(0.006, 0.33, 0.025), c(TrainParts.BODY_LIGHT))
		g.box(Vector3(s * 1.305, 1.95, 0), Vector3(0.006, 0.03, bz), c(TrainParts.BODY_LIGHT))
		g.box(Vector3(s * 1.305, 2.95, 0), Vector3(0.006, 0.03, bz), c(TrainParts.BODY_LIGHT))
		# Tool lockers under the floor and a rack of shovels and bars along one side.
		for z: float in [-1.6, 1.6]:
			g.box(Vector3(s * 1.05, 0.85, z), Vector3(0.25, 0.22, 0.9), c(TrainParts.WOOD_DARK))
		if s > 0.0:
			for k in 7:
				var z := -2.1 + k * 0.7
				g.cyl(Vector3(1.36, 1.35, z), Vector3(1.36, 2.6, z + 0.02), 0.022, 4, c(TrainParts.WOOD_LIGHT))
				if k % 2 == 0:
					g.box(Vector3(1.37, 1.28, z), Vector3(0.015, 0.12, 0.09), c(TrainParts.STEEL))
			g.box(Vector3(1.34, 2.5, 0.0), Vector3(0.03, 0.03, 2.5), c(TrainParts.BLACK))
	for e: float in [-1.0, 1.0]:
		g.box(Vector3(0, 2.0, e * bz), Vector3(0.38, 0.85, 0.02), c(TrainParts.WOOD_DARK))     # end door
		# End platform with a railing and steps down on both sides.
		g.box(Vector3(0, 1.13, e * (bz + 0.55)), Vector3(1.3, 0.04, 0.5), c(TrainParts.WOOD_DARK))
		for s: float in [-1.0, 1.0]:
			g.box(Vector3(s * 1.28, 1.6, e * (bz + 0.95)), Vector3(0.025, 0.45, 0.025), c(TrainParts.STEEL))
			g.box(Vector3(s * 1.28, 2.05, e * (bz + 0.55)), Vector3(0.02, 0.02, 0.42), c(TrainParts.STEEL))
			g.box(Vector3(s * 1.36, 0.72, e * (bz + 0.55)), Vector3(0.1, 0.025, 0.25), c(TrainParts.STEEL))
			g.box(Vector3(s * 1.36, 0.36, e * (bz + 0.55)), Vector3(0.1, 0.025, 0.25), c(TrainParts.STEEL))
		g.box(Vector3(0, 2.05, e * (bz + 0.95)), Vector3(0.9, 0.02, 0.02), c(TrainParts.STEEL))
	var roof := PackedVector2Array()
	var arc := 7
	for i in arc:
		var t := float(i) / float(arc - 1)
		roof.append(Vector2(lerpf(-1.42, 1.42, t), 3.26 + 0.32 * (1.0 - pow(2.0 * t - 1.0, 2.0)) + 0.06))
	for i in arc:
		var t := 1.0 - float(i) / float(arc - 1)
		roof.append(Vector2(lerpf(-1.42, 1.42, t), 3.26 + 0.32 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
	roof.reverse()
	g.extrude(roof, Vector3(0, 0, -bz - 1.0), Vector3(0, 0, bz + 1.0), c(TrainParts.ROOF))
	g.cyl(Vector3(-0.5, 3.5, 2.6), Vector3(-0.5, 4.1, 2.6), 0.07, 6, c(TrainParts.BLACK))   # stove pipe
	g.box(Vector3(-0.5, 4.13, 2.6), Vector3(0.12, 0.03, 0.12), c(TrainParts.BLACK))
	g.make(body, "Body", _mat)
	marks["stove"] = Vector3(-0.5, 4.2, 2.6)
	marks["step_fl"] = Vector3(-1.75, 0, -(bz + 0.55))
	marks["step_fr"] = Vector3(1.75, 0, -(bz + 0.55))
	marks["door_f"] = Vector3(0, 1.15, -(bz + 0.55))
	var fg := TrainGeo.new()
	fg.box(Vector3(0, 0.65, 0), Vector3(1.0, 0.45, -CO_FRONT - 0.4), c(TrainParts.BLACK))
	fg.box(Vector3(0, 2.2, 0), Vector3(1.3, 1.05, bz), c(TrainParts.BODY))
	fg.box(Vector3(0, 3.4, 0), Vector3(1.42, 0.18, bz + 1.0), c(TrainParts.ROOF))
	far = fg.make(self, "Far", _mat)


# ---------------------------------------------------------------- shared

func _frame(g: TrainGeo, beam: float, axles: Array, deck_y: float) -> void:
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 1.26, deck_y - 0.16, 0), Vector3(0.05, 0.15, beam), c(TrainParts.BLACK))
		for z: float in axles:
			g.box(Vector3(s * 0.98, 0.62, z), Vector3(0.04, 0.3, 0.42), c(TrainParts.BLACK))
			g.box(Vector3(s * 0.98, 0.52, z), Vector3(0.09, 0.1, 0.13), c(TrainParts.STEEL))
			g.box(Vector3(s * 0.98, 0.78, z), Vector3(0.06, 0.04, 0.55), c(TrainParts.BLACK))
	for e: float in [-1.0, 1.0]:
		g.box(Vector3(0, TrainParts.BUF_Y, e * beam), Vector3(1.3, 0.19, 0.07), c(TrainParts.WOOD_DARK))
	TrainParts._buffers(self, g, -beam, beam)


func tri_count(near := true) -> int:
	var n := 0
	for ch in find_children("*", "MeshInstance3D", true, false):
		var mi := ch as MeshInstance3D
		var is_far := mi == far or mi.name == "FarTip"
		if is_far == near or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			n += mi.mesh.surface_get_array_len(s) / 3
	return n


static func _dk(col: Color, charred: bool) -> Color:
	return col.lerp(Color(0.07, 0.065, 0.06), 0.6) if charred else col
