class_name Canopy
extends Node3D
## Iron Front: a parachute canopy and its rigging lines (Asset Builder Chat). The origin is where the lines
## meet (the confluence over the man or the crate); the canopy rides LEN above it.
## shape(open, collapse, gather, burn):
## - open 0..1: 0 is a long thin streamer pulled out of the bag, 1 is fully blossomed;
## - collapse 0..1: on the ground, the canopy lies down downwind (-Z of this node) and goes flat;
## - gather 0..1: being pulled in, it shrinks to a bundle;
## - burn 0..1: the cloth burns away (shrinks and goes dark).

const LEN := 4.6

var dome: MeshInstance3D
var lines: MeshInstance3D
var r := 3.0
var _mat: StandardMaterial3D


static func make(color: Color, radius := 3.0, gores := 14) -> Canopy:
	var c := Canopy.new()
	c.name = "Canopy"
	c.r = radius
	var g := TrainGeo.new()
	# a gored dome: alternate panels a shade darker, a skirt, the vent at the top
	var rings: Array = []
	var prof := [[1.0, 0.0], [0.97, 0.35], [0.84, 0.75], [0.6, 1.05], [0.3, 1.22], [0.08, 1.28]]
	for p: Array in prof:
		var ring := PackedVector3Array()
		for i in gores:
			var a := TAU * (float(i) + 0.5) / float(gores)
			ring.append(Vector3(cos(a) * radius * float(p[0]), LEN + float(p[1]) * radius * 0.55, sin(a) * radius * float(p[0])))
		rings.append(ring)
	var dark := color.darkened(0.12)
	for k in rings.size() - 1:
		var r0: PackedVector3Array = rings[k]
		var r1: PackedVector3Array = rings[k + 1]
		for i in gores:
			var i1 := (i + 1) % gores
			var col := color if i % 2 == 0 else dark
			# outside faces up and out, inside faces in: both sides drawn so it reads from below too
			var ref := Vector3(0, LEN - radius, 0)
			g.quad_out(r0[i], r0[i1], r1[i1], r1[i], col, ref)
			g.quad_out(r0[i], r1[i], r1[i1], r0[i1], col.darkened(0.06), Vector3(0, LEN + radius * 3.0, 0))
	c._mat = AirParts.material().duplicate()
	c.dome = g.make(c, "Dome", c._mat)
	var lg := TrainGeo.new()
	var r0: PackedVector3Array = rings[0]
	for i in range(0, gores, 2):
		lg.cyl(Vector3.ZERO, r0[i], 0.008, 3, Color(0.25, 0.24, 0.2))
	c.lines = lg.make(c, "Lines", AirParts.material())
	c.lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.shape(0.0)
	return c


func shape(open: float, collapse := 0.0, gather := 0.0, burn := 0.0) -> void:
	open = clampf(open, 0.0, 1.0)
	var w := lerpf(0.07, 1.0, open * open * (3.0 - 2.0 * open))
	var h := lerpf(1.35, 1.0, open)
	var b := Basis.from_scale(Vector3(w, h, w))
	var off := Vector3.ZERO
	if collapse > 0.0:
		var c := clampf(collapse, 0.0, 1.0)
		# first half: the dome tips over downwind (-Z); second half: it slumps into a long flat cloth lying
		# downwind of the confluence, the vent at the far end
		var tip := Basis(Vector3.RIGHT, -1.2 * smoothstep(0.0, 0.5, c)) * Basis.from_scale(Vector3(w, h, w))
		var flat := Basis(Vector3(0.4 * w, 0, 0), Vector3(0, 0.04, -1.0), Vector3(0, 0.05, 0.6))
		var u := smoothstep(0.5, 1.0, c)
		b = Basis(tip.x.lerp(flat.x, u), tip.y.lerp(flat.y, u), tip.z.lerp(flat.z, u))
		off = Vector3(0, -0.18, 1.6) * u
	var gs := lerpf(1.0, 0.1, clampf(gather, 0.0, 1.0))
	var bs := lerpf(1.0, 0.25, clampf(burn, 0.0, 1.0))
	var fb := b.scaled(Vector3.ONE * gs * bs) if gather > 0.0 or burn > 0.0 else b
	dome.transform = Transform3D(fb, off * gs * bs)
	lines.transform.basis = fb
	lines.visible = gather < 0.6 and collapse < 0.5
	_mat.albedo_color = Color.WHITE.lerp(Color(0.12, 0.1, 0.09), clampf(burn * 1.4, 0.0, 1.0))
