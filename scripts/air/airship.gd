class_name Airship
extends Node3D
## Iron Front: the army's war zeppelin (Question Chat, 2026-11-10), in the air round's low-poly style.
## A rigid hull 90 m long (16-sided, framed), the control gondola under the nose, two engine pods, cruciform fins.
## Forward is -Z; the origin is the hull's centre line at its middle.
##
## Weapons: two belly cannon turrets (0 under the gondola, 1 in an armoured tub under the after hull), each turning
## and dipping to fire down (aim_turret, recoil). Four anti-air MGs (aim_mg): 0 the top nest, 1 the tail nest,
## 2 and 3 the gondola's left and right windows. A searchlight under the gondola's nose (set_light) with a beam
## and a real spot light for night work.
##
## The hull is built bay by bay: each bay has its fabric skin and, inside it, its frame (girder ring and
## longitudinals) plus a charred frame. set_burn(front_z, back_z) burns the skin away between the two z values
## (the charred frame shows). The hull is two halves: fore and aft hinge at the keel at BREAK_Z, so the burning
## ship can break its back (set_break). Props turn with set_props(angle).

const HALF := 45.0
const R := 7.0
const SIDES := 16
const BREAK_Z := 8.0
const NEAR_END := 700.0
const STATIONS := [-45.0, -44.2, -42.5, -39.5, -35.0, -30.0, -24.0, -18.0, -12.0, -6.0, 0.0, 4.0, 8.0, 14.0, 20.0, 26.0,
	31.0, 35.5, 39.5, 42.5, 44.5, 45.0]
const GONDOLA_Z := -21.0
const G_TOP := -8.2
const G_BOT := -10.8
const TURRETS := [Vector3(0, -10.85, -19.0), Vector3(0, -9.15, 16.0)]
const BARREL := 3.2
const MGS := [Vector3(0, 6.85, -29.0), Vector3(0, -0.45, 45.35), Vector3(-1.32, -9.35, -17.2), Vector3(1.32, -9.35, -17.2)]
const PODS := [Vector3(-7.6, -6.4, 1.0), Vector3(7.6, -6.4, 1.0)]
const LIGHT := Vector3(0, -11.0, -27.6)
const BEAM_LEN := 260.0

const HULL_TOP := Color(0.50, 0.52, 0.43)
const HULL_LOW := Color(0.70, 0.69, 0.60)
const BAND := Color(0.36, 0.38, 0.30)
const FRAME := Color(0.55, 0.55, 0.52)
const CHAR := Color(0.10, 0.09, 0.085)
const ARMOUR := Color(0.33, 0.36, 0.25)

var fore: Node3D
var aft: Node3D
var skins: Array[MeshInstance3D] = []
var frames: Array[MeshInstance3D] = []
var charred: Array[MeshInstance3D] = []
var bay_z: Array[Vector2] = []
var turrets: Array[Node3D] = []
var cradles: Array[Node3D] = []
var barrels: Array[Node3D] = []
var mg_rings: Array[Node3D] = []
var mg_guns: Array[Node3D] = []
var props: Array[Node3D] = []
var rudders: Array[Node3D] = []
var elevators: Array[Node3D] = []
var light_yoke: Node3D
var light_head: Node3D
var lens: MeshInstance3D
var beam: MeshInstance3D
var spot: SpotLight3D
var far: MeshInstance3D
var _mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D


func setup() -> Airship:
	_mat = AirParts.material()
	fore = Node3D.new()
	fore.name = "Fore"
	add_child(fore)
	aft = Node3D.new()
	aft.name = "Aft"
	aft.position = Vector3(0, -R, BREAK_Z)
	add_child(aft)
	_build_hull()
	_build_fins()
	_build_gondola()
	_build_pods()
	_build_turrets()
	_build_mgs()
	_build_light()
	_build_far()
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi == far or mi == beam:
			continue
		mi.visibility_range_end = NEAR_END
	set_burn(99.0, 99.0)
	set_light(false)
	return self


static func radius(z: float) -> float:
	if z < -20.0:
		var u := (z + 20.0) / 25.0
		return R * sqrt(maxf(0.0, 1.0 - u * u))
	if z <= 12.0:
		return R
	var v := clampf((z - 12.0) / 33.0, 0.0, 1.0)
	return maxf(R * pow(maxf(0.0, 1.0 - pow(v, 1.8)), 0.6), 0.35)


static func ring(z: float, k := 1.0) -> PackedVector3Array:
	var r := radius(z) * k
	var out := PackedVector3Array()
	for i in SIDES:
		var a := TAU * (float(i) + 0.5) / float(SIDES)
		out.append(Vector3(cos(a) * r, sin(a) * r, z))
	return out


## The node a hull point belongs to and its offset there.
func half_for(z: float) -> Node3D:
	return fore if z < BREAK_Z else aft


func off_for(z: float) -> Vector3:
	return Vector3.ZERO if z < BREAK_Z else -aft.position


# ---------------------------------------------------------------- hull

func _build_hull() -> void:
	for b in STATIONS.size() - 1:
		var z0: float = STATIONS[b]
		var z1: float = STATIONS[b + 1]
		var zm := (z0 + z1) * 0.5
		var parent := half_for(zm)
		var o := off_for(zm)
		var r0 := ring(z0)
		var r1 := ring(z1)
		var g := TrainGeo.new()
		var mid := Vector3(0, 0, zm)
		for i in SIDES:
			var j := (i + 1) % SIDES
			var a := TAU * (float(i) + 1.0) / float(SIDES)
			var col := HULL_TOP.lerp(HULL_LOW, clampf(0.5 - sin(a) * 0.9, 0.0, 1.0))
			if i % 2 == 1:
				col = col.darkened(0.05)
			if absf(zm + 9.0) < 2.5:
				col = BAND
			g.quad_out(r0[i] + o, r0[j] + o, r1[j] + o, r1[i] + o, col, mid + o)
		# A darker seam band at the start station (the girder ring under the fabric).
		if radius(z0) > 1.0:
			var ra := ring(z0, 1.006)
			var rb := ring(z0 + 0.18, 1.006)
			for i in SIDES:
				var j := (i + 1) % SIDES
				g.quad_out(ra[i] + o, ra[j] + o, rb[j] + o, rb[i] + o, HULL_TOP.darkened(0.18), mid + o)
		if b == 0:
			for i in SIDES:
				g.tri_out(Vector3(0, 0, z0) + o, r1[i] + o, r1[(i + 1) % SIDES] + o, HULL_TOP.darkened(0.1), Vector3(0, 0, z1) + o)
		if b == STATIONS.size() - 2:
			for i in SIDES:
				g.tri_out(Vector3(0, 0, z1 + 0.2) + o, r1[i] + o, r1[(i + 1) % SIDES] + o, HULL_TOP, Vector3(0, 0, z0) + o)
		skins.append(g.make(parent, "Skin%d" % b, _mat))
		bay_z.append(Vector2(z0, z1))
		for burnt in 2:
			var fg := TrainGeo.new()
			var col2 := CHAR if burnt == 1 else FRAME
			var q0 := ring(z0, 0.985)
			var q1 := ring(z1, 0.985)
			for i in SIDES:
				var j := (i + 1) % SIDES
				if radius(z0) > 0.8:
					fg.cyl(q0[i] + o, q0[j] + o, 0.09, 4, col2)
				if radius(z0) > 0.3 or radius(z1) > 0.3:
					fg.cyl(q0[i] + o, q1[i] + o, 0.06, 4, col2)
				# Wire bracing across each panel (every other one).
				if i % 2 == 0 and radius(z0) > 2.0:
					fg.cyl(q0[i] + o, q1[j] + o, 0.025, 3, col2)
			# Gas cell remains inside: a few hanging rags on the charred frame.
			if burnt == 1 and radius(zm) > 3.0:
				for k in 3:
					var a2 := TAU * float(b * 3 + k) / 9.0
					var p := Vector3(cos(a2) * radius(zm) * 0.8, sin(a2) * radius(zm) * 0.8, zm) + o
					fg.box(p, Vector3(0.4, 0.9, 0.05), Color(0.2, 0.18, 0.15), Basis(Vector3.UP, a2))
			var mi := fg.make(parent, ("Char%d" if burnt == 1 else "Frame%d") % b, _mat)
			if burnt == 1:
				charred.append(mi)
			else:
				frames.append(mi)
	# The keel walkway along the bottom, visible once the skin is gone.
	for e in 2:
		var g := TrainGeo.new()
		var za := -36.0 if e == 0 else BREAK_Z
		var zb := BREAK_Z if e == 0 else 38.0
		var o := Vector3.ZERO if e == 0 else -aft.position
		var n := int((zb - za) / 1.5)
		for k in n:
			var z := za + 1.5 * k
			var y := -radius(z) * 0.93
			g.box(Vector3(0, y + 0.1, z + 0.75) + o, Vector3(0.45, 0.04, 0.75), FRAME.darkened(0.2))
		g.make(fore if e == 0 else aft, "Keel", _mat)


## The skin is burnt away between z0 and z1 (outside that it is whole).
func set_burn(z0: float, z1: float) -> void:
	for b in skins.size():
		var bz := bay_z[b]
		var gone := bz.y > z0 and bz.x < z1
		skins[b].visible = not gone
		frames[b].visible = not gone
		charred[b].visible = gone


## The aft half dropped about the keel hinge by a radians (tail down).
func set_break(a: float) -> void:
	aft.rotation = Vector3(-a, 0, 0)


# ---------------------------------------------------------------- fins

func _build_fins() -> void:
	var o := -aft.position
	for k in 4:
		var a := PI * 0.5 * k
		var dir := Vector3(cos(a), sin(a), 0)
		var side := Vector3(-dir.y, dir.x, 0)
		var g := TrainGeo.new()
		var p0 := dir * radius(30.0) + Vector3(0, 0, 30.0)
		var p1 := dir * (radius(40.5) + 5.5) + Vector3(0, 0, 40.5)
		var p2 := dir * (radius(43.0) + 5.5) + Vector3(0, 0, 43.0)
		var p3 := dir * radius(43.0) + Vector3(0, 0, 43.0)
		var th := side * 0.12
		g.prism([PackedVector3Array([p0 - th + o, p1 - th + o, p2 - th + o, p3 - th + o]),
			PackedVector3Array([p0 + th + o, p1 + th + o, p2 + th + o, p3 + th + o])], HULL_TOP)
		g.box((p1 + p2) * 0.5 + o + dir * 0.02, Vector3(0.14, 0.14, 1.3), HULL_TOP.darkened(0.15), Basis(side, dir, Vector3(0, 0, 1)))
		g.make(aft, "Fin%d" % k, _mat)
		var hinge := Node3D.new()
		hinge.position = dir * (radius(43.0) + 0.3) + Vector3(0, 0, 43.0) + o
		hinge.basis = Basis(side, dir, Vector3(0, 0, 1)).orthonormalized()
		aft.add_child(hinge)
		var sg := TrainGeo.new()
		sg.box(Vector3(0, 2.7, 1.2), Vector3(0.1, 2.5, 1.2), HULL_LOW.darkened(0.1))
		sg.make(hinge, "Surface", _mat)
		if k % 2 == 1:
			rudders.append(hinge)
		else:
			elevators.append(hinge)


func set_surfaces(rudder: float, elevator: float) -> void:
	for h in rudders:
		h.get_child(0).rotation = Vector3(0, clampf(rudder, -1.0, 1.0) * 0.4, 0)
	for h in elevators:
		h.get_child(0).rotation = Vector3(0, clampf(elevator, -1.0, 1.0) * 0.4, 0)


# ---------------------------------------------------------------- gondola, pods

func _build_gondola() -> void:
	var g := TrainGeo.new()
	var z0 := GONDOLA_Z - 7.0
	var z1 := GONDOLA_Z + 7.0
	var hw := 1.3
	# The car: a box with a rounded, glazed nose and a tapered tail.
	var outline := PackedVector2Array([Vector2(-hw, G_TOP), Vector2(hw, G_TOP), Vector2(hw, G_BOT + 0.35), Vector2(hw - 0.35, G_BOT),
		Vector2(-hw + 0.35, G_BOT), Vector2(-hw, G_BOT + 0.35)])
	g.extrude(outline, Vector3(0, 0, z0 + 1.2), Vector3(0, 0, z1 - 1.5), AirParts.TOP)
	g.prism([_shape(outline, z0 + 1.2, 1.0), _shape(outline, z0 + 0.4, 0.8), _shape(outline, z0, 0.5)], AirParts.TOP, 2)
	g.prism([_shape(outline, z1 - 1.5, 1.0), _shape(outline, z1, 0.45)], AirParts.TOP, 2)
	for s: float in [-1.0, 1.0]:
		for k in 9:
			var z := z0 + 1.7 + 1.2 * k
			if absf(z - (MGS[2] as Vector3).z) < 0.7:
				g.box(Vector3(s * (hw + 0.005), -9.3, z), Vector3(0.006, 0.36, 0.5), AirParts.BLACK)   # open MG window
				continue
			g.box(Vector3(s * (hw + 0.005), -9.25, z), Vector3(0.006, 0.3, 0.42), AirParts.GLASS)
		g.box(Vector3(s * (hw + 0.01), G_BOT + 0.45, (z0 + z1) * 0.5), Vector3(0.006, 0.05, 6.5), AirParts.TOP_DARK)
	g.box(Vector3(0, -9.3, z0 + 0.15), Vector3(0.55, 0.3, 0.01), AirParts.GLASS)
	# Bumper bags under the car, struts and cables up to the hull.
	for z: float in [z0 + 2.0, z1 - 2.5]:
		g.lump(Vector3(0, G_BOT - 0.25, z), 0.42, AirParts.CREAM, Vector3(1.4, 0.8, 1.0))
	for z: float in [z0 + 1.5, GONDOLA_Z, z1 - 2.0]:
		for s: float in [-1.0, 1.0]:
			g.cyl(Vector3(s * 0.9, G_TOP, z), Vector3(s * 1.6, -radius(z) * 0.98, z), 0.07, 5, AirParts.METAL)
	g.box(Vector3(0, G_TOP + 0.1, GONDOLA_Z), Vector3(0.3, 0.12, 6.5), AirParts.METAL)
	g.make(fore, "Gondola", _mat)
	# The after gun tub: an armoured box under the hull holding turret 1, a ladder up into the keel.
	var t := TrainGeo.new()
	var tz: float = (TURRETS[1] as Vector3).z
	var ty := -radius(tz)
	t.box(Vector3(0, ty - 0.95, tz), Vector3(1.1, 0.9, 1.7), ARMOUR, Basis(), 0.25)
	for s: float in [-1.0, 1.0]:
		t.box(Vector3(s * 1.105, ty - 0.8, tz), Vector3(0.006, 0.18, 0.45), AirParts.BLACK)
		t.cyl(Vector3(s * 0.7, ty - 0.1, tz - 1.2), Vector3(s * 1.1, ty + 0.25, tz - 1.6), 0.06, 4, AirParts.METAL)
		t.cyl(Vector3(s * 0.7, ty - 0.1, tz + 1.2), Vector3(s * 1.1, ty + 0.25, tz + 1.6), 0.06, 4, AirParts.METAL)
	t.make(aft, "GunTub", _mat, Transform3D(Basis(), -aft.position))


static func _shape(o: PackedVector2Array, z: float, k: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var cy := (G_TOP + G_BOT) * 0.5
	for p in o:
		out.append(Vector3(p.x * k, cy + (p.y - cy) * k, z))
	return out


func _build_pods() -> void:
	for p: Vector3 in PODS:
		var s := signf(p.x)
		var g := TrainGeo.new()
		g.box(p, Vector3(0.75, 0.8, 2.0), AirParts.TOP, Basis(), 0.3)
		g.box(p + Vector3(0, 0, -2.05), Vector3(0.6, 0.62, 0.06), AirParts.METAL)       # radiator
		for k in 5:
			g.box(p + Vector3(-0.5 + 0.25 * k, 0, -2.1), Vector3(0.02, 0.58, 0.01), AirParts.BLACK)
		g.cyl(p + Vector3(0, 0, 2.0), p + Vector3(0, 0, 2.5), 0.32, 8, AirParts.COWL, 0.15)
		g.box(p + Vector3(0, -0.3, 0.6), Vector3(0.006, 0.2, 0.3) + Vector3(0.76, 0, 0), AirParts.GLASS)
		for z: float in [-1.4, 1.2]:
			g.cyl(p + Vector3(-s * 0.4, 0.6, z), Vector3(s * radius(p.z + z) * 0.6, -radius(p.z + z) * 0.75, p.z + z), 0.07, 5, AirParts.METAL)
			g.cyl(p + Vector3(-s * 0.2, 0.75, z), Vector3(s * radius(p.z + z) * 0.35, -radius(p.z + z) * 0.92, p.z + z), 0.05, 5, AirParts.METAL)
		# Exhaust stack.
		g.cyl(p + Vector3(s * 0.75, 0.3, -0.5), p + Vector3(s * 0.85, 0.9, 0.4), 0.08, 5, AirParts.BLACK)
		g.make(fore, "Pod", _mat)
		var pr := Node3D.new()
		pr.position = p + Vector3(0, 0, 2.6)
		fore.add_child(pr)
		var pg := TrainGeo.new()
		for k in 4:
			var b := Basis(Vector3(0, 0, 1), PI * 0.5 * k)
			pg.box(b * Vector3(0, 1.05, 0), Vector3(0.14, 1.0, 0.04), AirParts.WOOD, b * Basis(Vector3.UP, 0.25))
		pg.cyl(Vector3(0, 0, -0.1), Vector3(0, 0, 0.2), 0.14, 8, AirParts.METAL)
		pg.make(pr, "Prop", _mat)
		props.append(pr)


func set_props(angle: float) -> void:
	for i in props.size():
		props[i].rotation = Vector3(0, 0, angle * (1.0 if i == 0 else -1.0))


func prop_exhaust(i: int) -> Vector3:
	var p: Vector3 = PODS[i]
	return fore.global_transform * (p + Vector3(signf(p.x) * 0.85, 0.95, 0.4))


# ---------------------------------------------------------------- turrets

func _build_turrets() -> void:
	for i in 2:
		var parent := fore if i == 0 else aft
		var o := Vector3.ZERO if i == 0 else -aft.position
		var base := Node3D.new()
		base.name = "Turret%d" % i
		base.position = (TURRETS[i] as Vector3) + o
		parent.add_child(base)
		var g := TrainGeo.new()
		# An armoured drum hanging under the car, open in a slot for the barrel.
		g.cyl(Vector3(0, 0.05, 0), Vector3(0, -0.15, 0), 1.15, 14, ARMOUR.darkened(0.15))
		g.cyl(Vector3(0, -0.15, 0), Vector3(0, -1.0, 0), 1.05, 14, ARMOUR)
		g.cyl(Vector3(0, -1.0, 0), Vector3(0, -1.3, 0), 1.05, 14, ARMOUR, 0.6)
		g.box(Vector3(0, -0.62, -1.04), Vector3(0.24, 0.42, 0.04), AirParts.BLACK)
		for k in 8:
			var a := TAU * k / 8.0
			g.box(Vector3(cos(a) * 1.06, -0.2, sin(a) * 1.06), Vector3(0.04, 0.03, 0.04), AirParts.METAL)
		g.box(Vector3(0.62, -0.4, 0.55), Vector3(0.12, 0.1, 0.12), AirParts.BLACK)   # sight hood
		g.make(base, "Drum", _mat)
		turrets.append(base)
		var cr := Node3D.new()
		cr.name = "Cradle"
		cr.position = Vector3(0, -0.62, 0)
		base.add_child(cr)
		cradles.append(cr)
		var bar := Node3D.new()
		bar.name = "Barrel"
		cr.add_child(bar)
		var bg := TrainGeo.new()
		bg.cyl(Vector3(0, 0, 0.3), Vector3(0, 0, -1.0), 0.17, 10, AirParts.METAL)
		bg.cyl(Vector3(0, 0, -1.0), Vector3(0, 0, -BARREL), 0.1, 10, AirParts.METAL, 0.09)
		bg.cyl(Vector3(0, 0, -BARREL + 0.25), Vector3(0, 0, -BARREL), 0.12, 10, AirParts.BLACK)
		bg.cyl(Vector3(0, 0.2, -0.2), Vector3(0, 0.2, -1.4), 0.06, 6, AirParts.TOP_DARK)
		bg.make(bar, "Gun", _mat)
		barrels.append(bar)
		aim_turret(i, 0.0, -0.3)


## Turret i: yaw (radians, 0 = forward, + = left) and pitch (radians, 0 level, negative points down).
func aim_turret(i: int, yaw: float, pitch: float) -> void:
	turrets[i].rotation = Vector3(0, yaw, 0)
	cradles[i].rotation = Vector3(clampf(pitch, -1.45, 0.05), 0, 0)


## Barrel recoil t seconds after the shot.
func recoil(i: int, t: float) -> void:
	var back := 0.0
	if t >= 0.0 and t < 0.06:
		back = t / 0.06
	elif t >= 0.06 and t < 0.9:
		var u := (t - 0.06) / 0.84
		back = 1.0 - u * u * (3.0 - 2.0 * u)
	barrels[i].position = Vector3(0, 0, 0.55 * back)


func muzzle(i: int) -> Vector3:
	return barrels[i].global_transform * Vector3(0, 0, -BARREL)


func muzzle_dir(i: int) -> Vector3:
	return -barrels[i].global_transform.basis.z.normalized()


## The yaw and pitch that point turret i at a world point.
func turret_aim_for(i: int, target: Vector3) -> Vector2:
	var local := (turrets[i].get_parent() as Node3D).global_transform.affine_inverse() * target - turrets[i].position
	var yaw := atan2(-local.x, -local.z)
	var flat := Vector2(local.x, local.z).length()
	return Vector2(yaw, atan2(local.y + 0.62, flat))


# ---------------------------------------------------------------- MGs

func _build_mgs() -> void:
	for i in 4:
		var p: Vector3 = MGS[i]
		var parent := fore if p.z < BREAK_Z else aft
		var o := Vector3.ZERO if p.z < BREAK_Z else -aft.position
		var g := TrainGeo.new()
		match i:
			0:
				# The top nest: a ring hatch with a low armoured screen.
				g.cyl(p + Vector3(0, -0.3, 0), p + Vector3(0, 0.05, 0), 1.0, 12, AirParts.METAL)
				for k in 7:
					var a := PI * 0.15 + PI * 0.7 * k / 6.0
					g.box(p + Vector3(cos(a) * 0.95, 0.35, -sin(a) * 0.95), Vector3(0.2, 0.3, 0.03), ARMOUR, Basis(Vector3.UP, a - PI * 0.5))
				g.box(p + Vector3(0, -0.2, 2.0), Vector3(0.3, 0.06, 1.2), AirParts.METAL)   # catwalk to the hatch
			1:
				# The tail nest: a little open cockpit at the stern.
				g.cyl(Vector3(0, 0, 44.2), Vector3(0, 0, 45.6), 0.95, 10, AirParts.TOP)
				g.cyl(p + Vector3(0, -0.15, 0), p + Vector3(0, 0.05, 0), 0.9, 10, AirParts.METAL)
			_:
				pass
		if g.tri_count() > 0:
			g.make(parent, "Nest%d" % i, _mat, Transform3D(Basis(), o))
		var rg := Node3D.new()
		rg.name = "MG%d" % i
		rg.position = p + o + Vector3(0, 0.95 if i < 2 else 0.0, 0)
		parent.add_child(rg)
		mg_rings.append(rg)
		var gun := Node3D.new()
		rg.add_child(gun)
		var gg := TrainGeo.new()
		gg.box(Vector3(0, 0, -0.05), Vector3(0.07, 0.1, 0.32), AirParts.BLACK)
		gg.cyl(Vector3(0, 0.02, -0.3), Vector3(0, 0.02, -1.05), 0.055, 8, AirParts.METAL)
		gg.cyl(Vector3(0, 0.02, -1.05), Vector3(0, 0.02, -1.15), 0.03, 6, AirParts.BLACK)
		gg.box(Vector3(0.12, -0.12, -0.15), Vector3(0.05, 0.1, 0.1), AirParts.TOP_DARK)   # ammunition drum box
		gg.box(Vector3(0, -0.1, 0.3), Vector3(0.025, 0.06, 0.05), AirParts.BLACK)         # spade grips
		if i < 2:
			gg.cyl(Vector3(0, -0.1, 0), Vector3(0, -0.95, 0), 0.04, 6, AirParts.METAL)   # pintle post
		gg.make(gun, "Gun", _mat)
		mg_guns.append(gun)
		var face := 0.0 if i == 0 else (PI if i == 1 else (PI * 0.5 if i == 2 else -PI * 0.5))
		aim_mg(i, face, 0.1)


func aim_mg(i: int, yaw: float, pitch: float) -> void:
	mg_rings[i].rotation = Vector3(0, yaw, 0)
	mg_guns[i].rotation = Vector3(clampf(pitch, -1.0, 1.3), 0, 0)


func mg_muzzle(i: int) -> Vector3:
	return mg_guns[i].global_transform * Vector3(0, 0.02, -1.15)


func mg_grips(i: int) -> Array:
	var x := mg_guns[i].global_transform
	return [x * Vector3(0.06, -0.1, 0.36), x * Vector3(-0.06, -0.1, 0.36)]


## Yaw and pitch (in the ring's parent frame) that point MG i at a world point.
func mg_aim_for(i: int, target: Vector3) -> Vector2:
	var local := (mg_rings[i].get_parent() as Node3D).global_transform.affine_inverse() * target - mg_rings[i].position
	return Vector2(atan2(-local.x, -local.z), atan2(local.y, Vector2(local.x, local.z).length()))


# ---------------------------------------------------------------- searchlight

func _build_light() -> void:
	light_yoke = Node3D.new()
	light_yoke.name = "Searchlight"
	light_yoke.position = LIGHT
	fore.add_child(light_yoke)
	var g := TrainGeo.new()
	g.box(Vector3(0, 0.3, 0), Vector3(0.12, 0.25, 0.12), AirParts.METAL)
	g.box(Vector3(0, 0.05, 0), Vector3(0.62, 0.05, 0.08), AirParts.METAL)
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 0.6, -0.25, 0), Vector3(0.04, 0.3, 0.06), AirParts.METAL)
	g.make(light_yoke, "Yoke", _mat)
	light_head = Node3D.new()
	light_head.position = Vector3(0, -0.45, 0)
	light_yoke.add_child(light_head)
	var hg := TrainGeo.new()
	hg.cyl(Vector3(0, 0, 0.45), Vector3(0, 0, -0.4), 0.5, 14, AirParts.TOP_DARK)
	hg.cyl(Vector3(0, 0, -0.4), Vector3(0, 0, -0.45), 0.53, 14, AirParts.METAL)
	hg.cyl(Vector3(0, 0, 0.45), Vector3(0, 0, 0.55), 0.3, 10, AirParts.METAL)
	hg.make(light_head, "Drum", _mat)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.vertex_color_use_as_albedo = true
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lg := TrainGeo.new()
	lg.cyl(Vector3(0, 0, -0.44), Vector3(0, 0, -0.47), 0.45, 14, Color.WHITE)
	lens = lg.make(light_head, "Lens", _glow_mat)
	# The beam: a long faint cone of light (additive), and the real spot light.
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 13.0
	cm.height = BEAM_LEN
	cm.radial_segments = 20
	cm.cap_top = false
	cm.cap_bottom = false
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(0.55, 0.52, 0.42, 0.028)
	cm.material = bm
	beam = MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = cm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.47 - BEAM_LEN * 0.5))
	light_head.add_child(beam)
	spot = SpotLight3D.new()
	spot.position = Vector3(0, 0, -0.5)
	spot.spot_range = 420.0
	spot.spot_angle = 3.2
	spot.spot_attenuation = 0.4
	spot.light_energy = 60.0
	spot.light_color = Color(1.0, 0.96, 0.85)
	spot.shadow_enabled = false
	light_head.add_child(spot)


## The searchlight: on/off, yaw (+ left) and pitch (negative down) under the gondola.
func set_light(on: bool, yaw := 0.0, pitch := -0.6) -> void:
	light_yoke.rotation = Vector3(0, yaw, 0)
	light_head.rotation = Vector3(clampf(pitch, -1.5, 0.2), 0, 0)
	beam.visible = on
	spot.visible = on
	var c := Color(1.0, 0.97, 0.85) if on else Color(0.3, 0.32, 0.33)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	lens.material_override = m


func light_point() -> Vector3:
	return light_head.global_transform * Vector3(0, 0, -0.5)


func light_aim_for(target: Vector3) -> Vector2:
	var local := fore.global_transform.affine_inverse() * target - (LIGHT + Vector3(0, -0.45, 0))
	return Vector2(atan2(-local.x, -local.z), atan2(local.y, Vector2(local.x, local.z).length()))


# ---------------------------------------------------------------- far look

func _build_far() -> void:
	var g := TrainGeo.new()
	var zs := [-45.0, -38.0, -28.0, -12.0, 12.0, 30.0, 40.0, 45.0]
	for b in zs.size() - 1:
		var r0 := PackedVector3Array()
		var r1 := PackedVector3Array()
		for i in 8:
			var a := TAU * (float(i) + 0.5) / 8.0
			r0.append(Vector3(cos(a) * radius(zs[b]), sin(a) * radius(zs[b]), zs[b]))
			r1.append(Vector3(cos(a) * radius(zs[b + 1]), sin(a) * radius(zs[b + 1]), zs[b + 1]))
		g.prism([r0, r1], HULL_TOP.lerp(HULL_LOW, 0.4), 0)
	g.box(Vector3(0, (G_TOP + G_BOT) * 0.5, GONDOLA_Z), Vector3(1.3, 1.3, 7.0), AirParts.TOP)
	for k in 4:
		var a := PI * 0.5 * k
		var dir := Vector3(cos(a), sin(a), 0)
		g.box(dir * 4.5 + Vector3(0, 0, 40.0), Vector3(0.15, 0.15, 3.0) + Vector3(absf(dir.x), absf(dir.y), 0) * 3.5, HULL_TOP)
	far = g.make(self, "Far", _mat)
	far.visibility_range_begin = NEAR_END


func tri_count(near := true) -> int:
	var n := 0
	for ch in find_children("*", "MeshInstance3D", true, false):
		var mi := ch as MeshInstance3D
		if mi == beam or mi.mesh == null:
			continue
		if (mi == far) == near:
			continue
		if near and charred.has(mi):
			continue
		for s in mi.mesh.get_surface_count():
			n += mi.mesh.surface_get_array_len(s) / 3
	return n
