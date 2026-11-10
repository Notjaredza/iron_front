class_name EngineerBuilder
extends RefCounted
## The engineer section (Building Chat 1, 2026-11-10): an NCO and three sappers on the rifleman's body, in our
## troops' look. No packs; rifles slung on the back; sleeves rolled, leather gloves, a tool frog with a hatchet and a
## cutter pouch on the belt, a pick-and-shovel badge (the white castle patch) on the left arm. The NCO keeps his
## stripes and map case and carries the plan.
## Tools and props are built in their own frames:
##   tools (pick, shovel, mallet, saw, hammer, cutters, bar, plank, coil) in the item bone's frame: grip at
##     SoldierBuilder.GRIP_R, the shaft along -Z, "up" +Y (the pick's point, the shovel's face, the saw's back)
##   plan  the NCO's board, in the left hand's frame
## TOOL_L gives where the left hand holds each two-handed tool (item frame).

const B := preload("res://scripts/units/soldier_builder.gd")
const STEEL := Color(0.23, 0.24, 0.23)
const STEEL_DARK := Color(0.14, 0.14, 0.15)
const EDGE := Color(0.55, 0.55, 0.52)
const ASH := Color(0.62, 0.48, 0.30)  # pale handle wood
const PLANK := Color(0.58, 0.45, 0.29)
const PAPER := Color(0.86, 0.84, 0.74)
const INK := Color(0.25, 0.32, 0.50)
const WIRE := Color(0.30, 0.29, 0.27)
const PATCH := Color(0.88, 0.86, 0.80)
const BAG := Color(0.52, 0.47, 0.32)
const TOOLS: Array[String] = ["pick", "shovel", "mallet", "saw", "hammer", "cutters", "bar", "plank", "coil", "panel"]
const PICK_LEN := 0.86
const SHOVEL_LEN := 1.02
const MALLET_LEN := 0.78
const BAR_LEN := 0.92
const PLANK_LEN := 2.2
const TOOL_L := {
	"pick": Vector3(0, -0.015, -0.16), "shovel": Vector3(0, -0.015, -0.46), "mallet": Vector3(0, -0.015, -0.14),
	"saw": Vector3(0, 0.03, -0.5), "bar": Vector3(0, -0.015, -0.3), "cutters": Vector3(0, -0.015, -0.02),
	"plank": Vector3(0, -0.04, -0.62), "coil": Vector3(0, 0.0, -0.5), "hammer": Vector3(0, -0.015, -0.1),
	"panel": Vector3(0, 0.0, -0.5)}


static func look_for_role(seed_value: int, role: String) -> Dictionary:
	var lk := B.look_from_seed(seed_value)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 977 + 31
	lk.merge({"role": role, "rifle": false, "pistol": false, "pack": false, "roll": 0, "shovel": false,
		"gloves": role != "nco", "canteen": [-1, 0][r.randi() % 2], "rolled": role != "nco",
		"net": r.randf() < 0.5}, true)
	if role == "nco":
		lk.merge({"stripes": true, "map_case": true, "holster": false}, true)
	return lk


static func build(look: Dictionary, lod: int) -> UnitGeo:
	var g := B.build(look, lod)
	var w: float = look.get("build", 1.0)
	var X := Vector3.RIGHT
	if lod >= 2:
		# Far: the slung rifle's line across the back, the tool frog.
		g.box(Vector3(0.0, 1.3, 0.17 * w), Vector3(0.02, 0.32, 0.02), B.WOOD_DARK, B.CHEST, Basis(Vector3.BACK, 0.5))
		return g
	var d0 := lod == 0
	var wl := lerpf(1.0, w, 0.6)
	# Rolled sleeves: a thick cuff above the elbow, bare forearm skin over the tunic below it.
	if look.get("rolled", false):
		var skin: Color = look.get("skin", B.SKINS[1])
		for s: float in [1.0, -1.0]:
			var fa := B.bone_side(s, B.FARM_R, B.FARM_L)
			g.loft([Vector3(0.226 * s, 1.15, 0.0), Vector3(0.228 * s, 1.1, 0.0)],
				[Vector2(0.066, 0.07) * wl, Vector2(0.066, 0.07) * wl], X, 6 if d0 else 4, 0.0, B.OLIVE_DARK, fa)
			g.loft([Vector3(0.229 * s, 1.1, 0.0), Vector3(0.24 * s, 0.89, 0.0)],
				[Vector2(0.06, 0.064) * wl, Vector2(0.054, 0.058) * wl], X, 6 if d0 else 4, 0.0, skin, fa, null, 0)
	# Webbing belt kit: a hatchet in its frog on the right hip, a cutter pouch and a nail bag on the left.
	g.box(Vector3(0.2 * w, 0.93, 0.07), Vector3(0.02, 0.08, 0.03), B.LEATHER, B.HIPS, Basis(Vector3.FORWARD, 0.12), 0.2 if d0 else 0.0)
	if d0:
		g.loft([Vector3(0.21 * w, 0.99, 0.07), Vector3(0.215 * w, 1.13, 0.08)], [Vector2(0.012, 0.012), Vector2(0.012, 0.012)],
			X, 4, 0.0, ASH, B.HIPS)
		g.box(Vector3(0.215 * w, 1.13, 0.05), Vector3(0.008, 0.025, 0.045), STEEL, B.HIPS)
	g.box(Vector3(-0.19 * w, 0.95, -0.06), Vector3(0.03, 0.07, 0.035), BAG, B.HIPS, Basis(), 0.2 if d0 else 0.0)
	if d0:
		g.box(Vector3(-0.19 * w, 1.025, -0.06), Vector3(0.033, 0.01, 0.038), B.KHAKI_DARK, B.HIPS)
		for k in 2:
			g.box(Vector3(-0.19 * w + 0.012 * (k * 2 - 1), 1.05, -0.06), Vector3(0.006, 0.02, 0.006), STEEL_DARK, B.HIPS)
	# The sapper's badge: a white castle-and-spade patch on the left upper arm.
	if d0:
		g.box(Vector3(-0.282 * wl, 1.33, 0.0), Vector3(0.004, 0.03, 0.026), PATCH, B.UARM_L)
		g.box(Vector3(-0.285 * wl, 1.338, 0.0), Vector3(0.003, 0.012, 0.006), B.OLIVE_DARK, B.UARM_L)
	# The rifle slung across the back, muzzle up behind the left shoulder (on the chest bone).
	var rg := UnitGeo.new()
	B._build_rifle(rg, lod)
	var bas := Basis.looking_at(Vector3(-0.5, 0.85, 0.06).normalized(), Vector3(0, 0, 1))
	var xf := Transform3D(bas, B.REST[B.CHEST] + Vector3(0.08, -0.2, 0.24) - bas * B.GRIP_R)
	for i in rg.pos.size():
		g.pos.append(xf * (rg.pos[i] - B.REST[B.RIFLE]))
		g.nrm.append(bas * rg.nrm[i])
		g.col.append(rg.col[i])
		g.bone.append(B.CHEST)
	if d0:
		# The sling over the right shoulder to the left hip.
		g.loft([Vector3(0.12, 1.5, -0.02), Vector3(0.02, 1.32, -0.15 * w), Vector3(-0.16, 1.05, -0.12 * w)],
			[Vector2(0.014, 0.004), Vector2(0.014, 0.004), Vector2(0.014, 0.004)], X, 4, 0.0, B.LEATHER, B.CHEST, null, 0)
	return g


# ---------------------------------------------------------------- tools (item frame)

static func tool(kind: String, lod := 0) -> UnitGeo:
	var g := UnitGeo.new()
	var X := Vector3.RIGHT
	var n := 6 if lod == 0 else 4
	var y := -0.015
	var far := lod >= 2
	match kind:
		"pick":
			g.loft([Vector3(0, y, 0.14), Vector3(0, y, -PICK_LEN + 0.06)], [Vector2(0.016, 0.02), Vector2(0.022, 0.028)],
				X, n, 0.0, ASH, 0)
			var hz := -PICK_LEN + 0.04
			g.box(Vector3(0, y, hz), Vector3(0.03, 0.04, 0.035), STEEL, 0)
			# The point (+Y, curved a little toward the hands) and the chisel blade (-Y).
			g.loft([Vector3(0, y + 0.03, hz), Vector3(0, y + 0.17, hz + 0.02), Vector3(0, y + 0.3, hz + 0.07)],
				[Vector2(0.018, 0.02), Vector2(0.013, 0.014), Vector2(0.0, 0.0)], X, 4, 0.0, STEEL, 0)
			g.loft([Vector3(0, y - 0.03, hz), Vector3(0, y - 0.16, hz + 0.02), Vector3(0, y - 0.25, hz + 0.06)],
				[Vector2(0.018, 0.02), Vector2(0.03, 0.01), Vector2(0.034, 0.004)], X, 4, 0.0, STEEL, 0)
			if lod == 0:
				g.box(Vector3(0, y - 0.25, hz + 0.06), Vector3(0.035, 0.006, 0.006), EDGE, 0)
		"shovel":
			# The D handle at the grip, the ash shaft, the steel blade (face toward +Y).
			g.loft([Vector3(0, y, 0.09), Vector3(0, y, -SHOVEL_LEN + 0.3)], [Vector2(0.016, 0.016), Vector2(0.018, 0.018)],
				X, n, 0.0, ASH, 0)
			if not far:
				g.box(Vector3(0, y, 0.09), Vector3(0.055, 0.012, 0.012), B.WOOD_DARK, 0)
				for s: float in [1.0, -1.0]:
					g.loft([Vector3(0.05 * s, y, 0.085), Vector3(0.016 * s, y, 0.0)], [Vector2(0.01, 0.01), Vector2(0.01, 0.01)],
						Vector3.UP, 4, 0.0, B.WOOD_DARK, 0)
			g.loft([Vector3(0, y, -SHOVEL_LEN + 0.32), Vector3(0, y, -SHOVEL_LEN + 0.24)], [Vector2(0.024, 0.024), Vector2(0.03, 0.02)],
				X, 4, 0.0, STEEL_DARK, 0)
			g.loft([Vector3(0, y + 0.012, -SHOVEL_LEN + 0.25), Vector3(0, y, -SHOVEL_LEN + 0.1), Vector3(0, y - 0.01, -SHOVEL_LEN)],
				[Vector2(0.11, 0.008), Vector2(0.12, 0.006), Vector2(0.09, 0.005)], X, 4, 0.0, STEEL, 0)
			if lod == 0:
				g.box(Vector3(0, y - 0.01, -SHOVEL_LEN + 0.005), Vector3(0.09, 0.006, 0.006), EDGE, 0)
		"mallet":
			# The maul for driving pickets: a long haft and a heavy iron-ringed head across +-Y.
			g.loft([Vector3(0, y, 0.12), Vector3(0, y, -MALLET_LEN + 0.06)], [Vector2(0.017, 0.017), Vector2(0.02, 0.02)],
				X, n, 0.0, ASH, 0)
			var mz := -MALLET_LEN + 0.03
			g.loft([Vector3(0, y - 0.12, mz), Vector3(0, y + 0.12, mz)], [Vector2(0.07, 0.07), Vector2(0.07, 0.07)],
				Vector3.RIGHT, 8 if lod == 0 else 4, 0.0, B.WOOD, 0)
			if lod == 0:
				for s: float in [1.0, -1.0]:
					g.loft([Vector3(0, y + 0.1 * s, mz), Vector3(0, y + 0.12 * s, mz)], [Vector2(0.074, 0.074), Vector2(0.074, 0.074)],
						Vector3.RIGHT, 8, 0.0, STEEL_DARK, 0, null, 0)
		"hammer":
			g.loft([Vector3(0, y, 0.1), Vector3(0, y, -0.26)], [Vector2(0.013, 0.016), Vector2(0.012, 0.014)], X, 4, 0.0, ASH, 0)
			g.box(Vector3(0, y + 0.015, -0.27), Vector3(0.016, 0.05, 0.018), STEEL, 0)
			if lod == 0:
				g.loft([Vector3(0, y - 0.035, -0.27), Vector3(0, y - 0.075, -0.25)], [Vector2(0.01, 0.014), Vector2(0.004, 0.012)],
					X, 4, 0.0, STEEL, 0)
		"saw":
			# A hand saw: the closed wooden handle at the grip, the blade along -Z, teeth down (-Y).
			g.box(Vector3(0, y, 0.03), Vector3(0.012, 0.06, 0.06), B.WOOD, 0)
			g.loft([Vector3(0, y + 0.04, -0.04), Vector3(0, y - 0.0, -0.62)], [Vector2(0.002, 0.065), Vector2(0.002, 0.035)],
				X, 4, 0.0, EDGE if lod == 0 else STEEL, 0)
		"cutters":
			# Long-handled wire cutters: two handles from the grips, the jaws ahead.
			for s: float in [1.0, -1.0]:
				g.loft([Vector3(0.02 * s, y, 0.1), Vector3(0.008 * s, y, -0.28)], [Vector2(0.01, 0.012), Vector2(0.01, 0.012)],
					Vector3.UP, 4, 0.0, B.WOOD_DARK if lod == 0 else STEEL, 0)
			g.loft([Vector3(0, y, -0.28), Vector3(0, y, -0.4)], [Vector2(0.018, 0.012), Vector2(0.008, 0.006)], X, 4, 0.0, STEEL, 0)
		"bar":
			# A crowbar: straight iron, the claw end bent over (+Y).
			g.loft([Vector3(0, y, 0.1), Vector3(0, y, -BAR_LEN + 0.08)], [Vector2(0.013, 0.013), Vector2(0.013, 0.013)],
				X, 6 if lod == 0 else 4, 0.0, STEEL, 0)
			g.loft([Vector3(0, y, -BAR_LEN + 0.08), Vector3(0, y + 0.04, -BAR_LEN), Vector3(0, y + 0.09, -BAR_LEN + 0.02)],
				[Vector2(0.013, 0.013), Vector2(0.015, 0.008), Vector2(0.018, 0.003)], X, 4, 0.0, STEEL, 0)
		"plank":
			# A plank on the shoulder (held near its middle).
			g.box(Vector3(0, y - 0.06, -0.3), Vector3(0.11, 0.014, PLANK_LEN * 0.5), PLANK, 0)
		"panel":
			# A steel panel off the wreck, held by its top edge (the edge along -Z, the sheet hanging toward -Y... set
			# by the carry), its rivet line along the edge.
			g.box(Vector3(0, -0.22, -0.25), Vector3(0.005, 0.24, 0.36), Color(0.36, 0.38, 0.30), 0)
			if lod == 0:
				for k in 6:
					g.box(Vector3(0.007, -0.03, -0.55 + 0.12 * k), Vector3(0.004, 0.008, 0.008), STEEL_DARK, 0)
		"coil":
			# The barbed-wire coil on a carrying stake (the stake across, the coil round it).
			g.loft([Vector3(0, 0.0, 0.08), Vector3(0, 0.0, -0.58)], [Vector2(0.014, 0.014), Vector2(0.014, 0.014)], X, 4, 0.0, B.WOOD_DARK, 0)
			var rings := 3 if lod == 0 else 1
			for k in rings:
				var z := -0.2 - 0.05 * k
				var pts: Array = []
				var sz: Array = []
				var seg := 12 if lod == 0 else 6
				for j in seg + 1:
					var a := TAU * j / float(seg)
					pts.append(Vector3(cos(a) * 0.22, sin(a) * 0.22, z + 0.02 * sin(a * 3.0)))
					sz.append(Vector2(0.012, 0.012))
				g.loft(pts, sz, Vector3.BACK, 4, 0.0, WIRE, 0, null, 0)
	return g


## The NCO's plan: a board with the drawing clipped on. Engineer places it at the left palm, tipped toward his eyes.
static func plan(lod := 0) -> UnitGeo:
	# Its frame: the left palm at the origin, the board flat in XZ (face +Y), held by its left edge, reaching to +X.
	var g := UnitGeo.new()
	var c := Vector3(0.13, 0.01, -0.02)
	g.box(c, Vector3(0.15, 0.006, 0.11), B.WOOD_DARK, 0)
	g.box(c + Vector3(0, 0.008, 0), Vector3(0.14, 0.003, 0.1), PAPER, 0)
	if lod == 0:
		for k in 4:
			g.box(c + Vector3(-0.06 + 0.04 * k, 0.012, 0.02 * (k % 2)), Vector3(0.002, 0.001, 0.07), INK, 0)
		g.box(c + Vector3(0, 0.012, 0.03), Vector3(0.11, 0.001, 0.002), INK, 0)
		g.box(c + Vector3(0, 0.014, -0.1), Vector3(0.05, 0.004, 0.012), STEEL, 0)  # the clip
	return g
