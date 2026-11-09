class_name Balloon
extends Node3D
## Iron Front: tethered observation balloon with its basket, cable and winch lorry (Asset Builder Chat).
## Children:
## - Lorry (on the ground at this node's origin): cab, bed, winch drum (Drum turns), wheels;
## - Kite (in the air, set_height): Envelope (4 segments + 3 fins, so a fire can fold it), rigging, Basket
##   with two observers (Crew0, Crew1, each can jump), parachute packs on the basket rim;
## - Cable from the drum to the basket.
## Forward is -Z; the kite faces into the wind (+Z wind blows it back a little).

const ENV := Color(0.72, 0.68, 0.54)
const ENV_DARK := Color(0.63, 0.59, 0.46)
const BASKET := Color(0.66, 0.52, 0.30)
const BASKET_DARK := Color(0.50, 0.38, 0.22)
const ROPE := Color(0.30, 0.27, 0.22)
const OLIVE := Color(0.36, 0.40, 0.24)
const OLIVE_DARK := Color(0.28, 0.31, 0.19)
const NEAR_END := 600.0

const ENV_LEN := 28.0
const ENV_R := 4.3
const HANG := 11.0                  # envelope centre to basket floor
const DRUM := Vector3(0, 2.15, 2.4) # winch drum on the lorry bed
const DRUM_R := 0.45

var height := 6.0                   # basket floor above the ground
var lorry: Node3D
var drum: Node3D
var lorry_wheels: Array[Node3D] = []
var kite: Node3D
var envelope: Node3D
var segments: Array[MeshInstance3D] = []
var fins: Array[MeshInstance3D] = []
var basket: Node3D
var crew: Array[Node3D] = []
var chutes: Array[Node3D] = []
var cable: MeshInstance3D
var rigging: MeshInstance3D
var far: MeshInstance3D
var sway := Vector3.ZERO            # small pitch / roll / yaw from the wind

@export var fire_level := 0.0
@export var crash_time := -1.0


static func make() -> Balloon:
	var b := Balloon.new()
	b.name = "Balloon"
	b._build()
	return b


func _build() -> void:
	var m := AirParts.material()
	# ---------------------------------------------------------------- lorry
	lorry = Node3D.new()
	lorry.name = "Lorry"
	add_child(lorry)
	var g := TrainGeo.new()
	g.box(Vector3(0, 0.95, 0.4), Vector3(0.95, 0.1, 3.0), OLIVE_DARK)                     # chassis
	g.box(Vector3(0, 1.45, -2.0), Vector3(0.85, 0.45, 0.55), OLIVE, Basis(), 0.12)           # bonnet
	g.box(Vector3(0, 1.2, -2.6), Vector3(0.75, 0.4, 0.04), AirParts.METAL)                   # radiator
	g.box(Vector3(0, 1.75, -0.95), Vector3(0.95, 0.75, 0.5), OLIVE)                          # cab
	g.box(Vector3(0, 2.55, -0.95), Vector3(1.0, 0.05, 0.62), OLIVE_DARK)                     # cab roof
	g.box(Vector3(0, 1.95, -1.46), Vector3(0.75, 0.25, 0.01), AirParts.GLASS)                # windscreen
	g.box(Vector3(0, 1.15, 1.6), Vector3(1.05, 0.12, 1.9), Color(0.45, 0.36, 0.24))          # bed
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(sx * 0.62, 1.7, DRUM.z), Vector3(0.08, 0.55, 0.45), OLIVE_DARK)        # drum frames
		g.box(Vector3(sx * 1.0, 1.25, -2.0), Vector3(0.12, 0.05, 0.6), OLIVE_DARK)           # mudguards
	g.box(Vector3(0, 1.55, 0.9), Vector3(0.5, 0.3, 0.4), AirParts.METAL)                     # winch engine
	g.box(Vector3(0, 1.55, 3.3), Vector3(0.6, 0.35, 0.25), OLIVE_DARK)                       # cable guide
	g.cyl(Vector3(0, 1.85, 3.25), Vector3(0, 2.3, 3.25), 0.08, 6, AirParts.METAL)           # fairlead post
	g.make(lorry, "Mesh", m)
	drum = Node3D.new()
	drum.name = "Drum"
	drum.position = Vector3(0, 1.7, DRUM.z)
	lorry.add_child(drum)
	var dg := TrainGeo.new()
	dg.cyl(Vector3(-0.52, 0, 0), Vector3(0.52, 0, 0), DRUM_R, 12, Color(0.40, 0.38, 0.34))
	dg.cyl(Vector3(-0.56, 0, 0), Vector3(-0.5, 0, 0), DRUM_R + 0.12, 12, AirParts.METAL)
	dg.cyl(Vector3(0.5, 0, 0), Vector3(0.56, 0, 0), DRUM_R + 0.12, 12, AirParts.METAL)
	for k in 6:
		var a := TAU * float(k) / 6.0
		dg.box(Vector3(0, cos(a) * DRUM_R, sin(a) * DRUM_R), Vector3(0.5, 0.015, 0.015), ROPE)   # wound cable marks
	dg.make(drum, "Mesh", m)
	for wz: float in [-2.0, 2.2]:
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.name = "Wheel%d" % lorry_wheels.size()
			w.position = Vector3(sx * 0.95, 0.5, wz)
			lorry.add_child(w)
			var wg := TrainGeo.new()
			wg.cyl(Vector3(-0.12, 0, 0), Vector3(0.12, 0, 0), 0.5, 10, AirParts.TYRE)
			wg.cyl(Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0), 0.25, 8, OLIVE_DARK)
			wg.box(Vector3(sx * 0.135, 0, 0), Vector3(0.005, 0.05, 0.45), AirParts.METAL)
			wg.make(w, "Mesh", m)
			lorry_wheels.append(w)
	# ---------------------------------------------------------------- kite: envelope, fins, rigging, basket
	kite = Node3D.new()
	kite.name = "Kite"
	add_child(kite)
	envelope = Node3D.new()
	envelope.name = "Envelope"
	envelope.position = Vector3(0, HANG, 0)
	kite.add_child(envelope)
	# radius profile along the length (z from nose -14 to tail +14), a fat nose and a long taper
	var prof := [[-14.0, 0.0], [-13.4, 0.42], [-12.0, 0.75], [-9.5, 0.95], [-6.0, 1.0], [-1.0, 0.97], [4.0, 0.85],
		[8.5, 0.62], [12.0, 0.36], [14.0, 0.0]]
	var cuts := [0, 3, 5, 7, 9]           # four segments
	for si in 4:
		var sg := TrainGeo.new()
		var rings: Array = []
		for pi in range(cuts[si], cuts[si + 1] + 1):
			var z: float = prof[pi][0]
			var r: float = float(prof[pi][1]) * ENV_R
			rings.append(_round_ring(z, maxf(r, 0.001), 14))
		for i in rings.size() - 1:
			var r0: PackedVector3Array = rings[i]
			var r1: PackedVector3Array = rings[i + 1]
			var mid := (TrainGeo._mid(r0) + TrainGeo._mid(r1)) * 0.5
			for j in r0.size():
				var j1 := (j + 1) % r0.size()
				var c := ENV if (j % 2 == 0) else ENV_DARK      # gored panels
				sg.quad_out(r0[j], r0[j1], r1[j1], r1[j], c, mid)
		if si == 0:
			# rigging band and the patch where the lines meet
			sg.box(Vector3(0, -ENV_R * 0.97, -4.0), Vector3(0.6, 0.06, 2.0), ENV_DARK)
		var seg := sg.make(envelope, "Seg%d" % si, m)
		segments.append(seg)
	# three tail lobes (Caquot style): top, lower left, lower right
	for k in 3:
		var ang := PI * 0.5 + TAU * float(k) / 3.0
		var fg := TrainGeo.new()
		var dir := Vector3(cos(ang), sin(ang), 0)
		var rings: Array = []
		var lobe := [[7.0, 0.3, 0.0], [9.0, 1.35, 2.6], [12.3, 1.2, 3.6], [14.6, 0.5, 3.2]]
		for l: Array in lobe:
			var c: Vector3 = dir * (ENV_R * 0.55 + float(l[2]) * 0.55) + Vector3(0, 0, l[0])
			rings.append(_lobe_ring(c, dir, float(l[1]), 1.0 + float(l[2]) * 0.35))
		fg.prism(rings, ENV, 3)
		var fin := fg.make(envelope, "Fin%d" % k, m)
		fins.append(fin)
	# basket: wicker with a rim, two observers, parachute packs on the outside
	basket = Node3D.new()
	basket.name = "Basket"
	kite.add_child(basket)
	var bg := TrainGeo.new()
	bg.box(Vector3(0, 0.55, 0), Vector3(0.65, 0.55, 0.65), BASKET, Basis(), 0.08)
	bg.box(Vector3(0, 1.12, 0), Vector3(0.7, 0.05, 0.7), BASKET_DARK)
	for k in 4:
		var y := 0.15 + float(k) * 0.25
		bg.box(Vector3(0, y, 0), Vector3(0.66, 0.02, 0.66), BASKET_DARK)                       # weave bands
	bg.box(Vector3(0, 1.14, 0), Vector3(0.55, 0.02, 0.55), AirParts.BLACK)                     # opening
	for sx: float in [-1.0, 1.0]:
		bg.box(Vector3(sx * 0.75, 0.85, 0.2), Vector3(0.08, 0.25, 0.18), Color(0.30, 0.32, 0.26)) # parachute packs
	bg.box(Vector3(0.0, 1.3, -0.72), Vector3(0.18, 0.12, 0.05), AirParts.METAL)               # telephone / map board
	bg.make(basket, "Mesh", m)
	for k in 2:
		var man := Node3D.new()
		man.name = "Crew%d" % k
		man.position = Vector3(-0.28 + 0.56 * float(k), 0.82, 0.0)
		man.rotation.y = 0.3 - 0.6 * float(k)
		basket.add_child(man)
		var mg := TrainGeo.new()
		AirParts.airman(mg, Vector3.ZERO)
		mg.cyl(Vector3(0.05, 0.36, -0.12), Vector3(0.05, 0.42, -0.32), 0.04, 6, AirParts.BLACK)    # field glasses
		mg.box(Vector3(0, -0.35, 0), Vector3(0.12, 0.35, 0.1), Color(0.33, 0.33, 0.26))          # legs (hidden in the basket)
		mg.make(man, "Mesh", m)
		crew.append(man)
		# the parachute, packed away (scale ~0) until the jump
		var chute := Node3D.new()
		chute.name = "Chute"
		chute.position = Vector3(0, 0.5, 0)
		chute.scale = Vector3.ONE * 0.001
		man.add_child(chute)
		var pg := TrainGeo.new()
		var cr := 2.4
		pg.dome(Vector3(0, 4.2, 0), cr, 1.3, 12, Color(0.88, 0.86, 0.78))
		var under := PackedVector3Array()
		for i in 12:
			var a := TAU * (float(i) + 0.5) / 12.0
			under.append(Vector3(cos(a) * cr, 4.2, sin(a) * cr))
		for i in 12:
			pg.tri_out(Vector3(0, 4.6, 0), under[i], under[(i + 1) % 12], Color(0.70, 0.68, 0.60), Vector3(0, 6, 0))
		for i in range(0, 12, 2):
			pg.cyl(Vector3(0, 0.1, 0), under[i], 0.01, 3, ROPE)
		pg.make(chute, "Mesh", m)
		chutes.append(chute)
	# rigging lines from the envelope belly to the basket rim; a bridle to the cable
	var rg := TrainGeo.new()
	var hoop := Vector3(0, 3.2, -1.2)
	for k in 4:
		var bx := 0.62 if k % 2 == 0 else -0.62
		var bz := 0.62 if k < 2 else -0.62
		rg.cyl(Vector3(bx, 1.15, bz), hoop + Vector3(bx * 0.4, 0, bz * 0.4), 0.012, 3, ROPE)
	rg.cyl(hoop + Vector3(-0.3, 0, 0), hoop + Vector3(0.3, 0, 0), 0.03, 4, AirParts.METAL)
	for sx: float in [-1.0, 1.0]:
		for ez: float in [-8.0, -5.0, -2.0, 1.0]:
			rg.cyl(hoop + Vector3(sx * 0.3, 0, 0), Vector3(sx * ENV_R * 0.55, HANG - ENV_R * 0.84, ez), 0.012, 3, ROPE)
	rg.cyl(Vector3(0, 0.0, 0), Vector3(0, -0.6, 0.0), 0.03, 4, ROPE)
	rigging = rg.make(kite, "Rigging", m)
	# cable: a unit-long bar scaled to length every frame
	var cg := TrainGeo.new()
	cg.cyl(Vector3.ZERO, Vector3(0, 0, -1), 0.03, 4, ROPE)
	cable = cg.make(self, "Cable", m)
	# far look
	var fg2 := TrainGeo.new()
	fg2.box(Vector3(0, HANG, -1.0), Vector3(ENV_R * 0.8, ENV_R * 0.8, ENV_LEN * 0.45), ENV)
	fg2.box(Vector3(0, 0.55, 0), Vector3(0.7, 0.6, 0.7), BASKET)
	far = fg2.make(kite, "Far", m)
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi == far:
			mi.visibility_range_begin = NEAR_END
		elif mi != cable:
			mi.visibility_range_end = NEAR_END
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	set_height(height)


static func _round_ring(z: float, r: float, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n:
		var t := TAU * (float(i) + 0.5) / float(n)
		out.append(Vector3(cos(t) * r, sin(t) * r, z))
	return out


static func _lobe_ring(c: Vector3, dir: Vector3, r: float, stretch: float) -> PackedVector3Array:
	var side := Vector3(0, 0, 1).cross(dir).normalized()
	var out := PackedVector3Array()
	for i in 8:
		var t := TAU * (float(i) + 0.5) / 8.0
		out.append(c + side * cos(t) * r * 0.55 + dir * sin(t) * r * stretch * 0.5)
	return out


## Puts the basket floor at height h above the ground (the drum turns to pay out or haul in the cable).
func set_height(h: float) -> void:
	var dh := h - height
	height = h
	drum.rotation.x += dh / DRUM_R
	# the kite streams back a little downwind (+Z) as it rises
	var back := h * 0.12
	kite.position = Vector3(0, h, DRUM.z + 1.0 + back)
	kite.rotation = Vector3(sway.x, sway.z, sway.y)
	_update_cable()


func _update_cable() -> void:
	var a := lorry.transform * Vector3(0, 2.3, 3.25)
	var b := kite.transform * Vector3(0, -0.6, 0)
	if not cable.is_inside_tree() and not is_inside_tree():
		pass
	var d := b - a
	var len_ := maxf(d.length(), 0.01)
	var fwd := -d / len_
	var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(fwd).normalized()
	var y := fwd.cross(x)
	# the bar runs from 0 to -1 along its z: point -z at b
	cable.transform = Transform3D(Basis(x, y, fwd * len_), a)


## Wind sway (call every frame): small slow pitch, roll and yaw.
func wind(t: float, strength := 1.0) -> void:
	sway = Vector3(sin(t * 0.7) * 0.04, sin(t * 0.5 + 1.0) * 0.06, sin(t * 0.33) * 0.08) * strength
	set_height(height)


func roll_lorry(dist: float) -> void:
	for w in lorry_wheels:
		w.rotation.x = -dist / 0.5


func tri_count(near := true) -> int:
	var n := 0
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if (mi == far) != near and mi.mesh:
			n += mi.mesh.get_faces().size() / 3
	return n
