class_name TrainCrashes
extends RefCounted
## Iron Front: the four train crashes, each for 3, 4 and 5-car trains, at full speed (18 m/s, 65 km/h).
##
## - tip:   too fast on a curve (radius 90 m): the train leaves the curve, rolls onto its side, the cars jackknife.
## - track: the track is torn up ahead: the engine drops into the hole and ploughs in, the cars pile up behind.
## - block: a block of tank traps and logs on the line: the front crumples and the cars concertina.
## - blast: the boiler is hit: the engine is blown apart, the rest derails, and a burning wreck is left.
##
## stage_for() builds the same scene for the baker (tools/train_bake.gd) and for anyone playing a clip:
## the track, what is on it, solid ground for the physics, and the train at its run-in start.
## The clips (crash_<kind>_<n>) live in LIB_PATH. Each starts RUN_IN seconds before the crash with the train
## running, so it can be played from the start; the Train's crash_time says when the crash begins.
## The clips are keyed in the layout's own frame; to crash somewhere else, put the Train node where that
## layout's crash point should be (crash_frame()).

const KINDS: Array[String] = ["tip", "track", "block", "blast"]
const LIB_PATH := "res://assets/trains/crashes.res"
const SPEED := 18.0
const RUN_IN := 1.0
const CRASH_D := 300.0           # path distance of the engine's front buffers when the crash begins
const CURVE_R := 90.0
const HOLE := 8.0                # length of torn-up track
const BLOCK_GAP := 2.0           # the block stands this far ahead of the engine when the crash begins

static var _lib: AnimationLibrary


static func cars_for(n: int) -> Array[String]:
	var all: Array[String] = ["engine", "tender", "van", "gunflat", "van"]
	return all.slice(0, n)


static func library() -> AnimationLibrary:
	if _lib == null:
		_lib = load(LIB_PATH)
	return _lib


static func path_for(kind: String) -> TrackPath:
	if kind == "tip":
		# straight in from +Z, the curve (turning left) begins 12 m before the crash point
		return TrackPath.straight_curve(Vector3(0, 0, CRASH_D - 12.0), Vector3(0, 0, -1), CRASH_D - 12.0, CURVE_R, 1.3, 120.0)
	return TrackPath.line(Vector3(0, 0, CRASH_D), Vector3(0, 0, -200.0))


static func crash_frame(kind: String) -> Transform3D:
	return path_for(kind).frame(CRASH_D)


## Builds the scene for one crash under parent and returns the train, at its run-in start, already added.
static func stage_for(kind: String, n: int, parent: Node3D) -> Train:
	var path := path_for(kind)
	var total := path.length()
	var broken: Array = []
	if kind == "track":
		broken = [[CRASH_D, CRASH_D + HOLE]]
	parent.add_child(TrainParts.track(path, 0.0, total, broken))
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	parent.add_child(solid)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.5
	pm.bounce = 0.05
	solid.physics_material_override = pm
	# ground, with a pit under the torn-up track
	if kind == "track":
		var c := path.point(CRASH_D + HOLE * 0.5)
		parent.add_child(TrainParts.crater(path, CRASH_D + HOLE * 0.5, HOLE + 2.0))
		var pit_half := Vector2(4.0, HOLE * 0.5 + 1.0)
		_solid_box(solid, Vector3(0, -1.6, c.z + pit_half.y + 300.0), Vector3(400, 1.0, 300.0))
		_solid_box(solid, Vector3(0, -1.6, c.z - pit_half.y - 300.0), Vector3(400, 1.0, 300.0))
		_solid_box(solid, Vector3(pit_half.x + 200.0, -1.6, c.z), Vector3(200, 1.0, pit_half.y))
		_solid_box(solid, Vector3(-pit_half.x - 200.0, -1.6, c.z), Vector3(200, 1.0, pit_half.y))
		_solid_box(solid, Vector3(0, -2.4, c.z), Vector3(pit_half.x, 0.8, pit_half.y))   # pit floor at -1.6
	else:
		_solid_box(solid, Vector3(0, -1.6, 0), Vector3(600, 1.0, 600))
	# the track bed (sleepers' top at -0.15)
	var dd := 0.0
	while dd < total:
		var skip := false
		for br: Array in broken:
			if dd + 2.0 > br[0] and dd - 2.0 < br[1]:
				skip = true
		if not skip:
			var f := path.frame(dd)
			var shape := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(3.3, 0.45, 4.1)
			shape.shape = bs
			shape.transform = Transform3D(f.basis, f.origin + Vector3(0, -0.375, 0))
			solid.add_child(shape)
		dd += 4.0
	if kind == "block":
		var f := path.frame(CRASH_D + BLOCK_GAP)
		var bl := TrainParts.blockade(f.origin + f.basis.z * -0.6, 0.0)
		parent.add_child(bl)
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(4.6, 1.5, 1.6)
		shape.shape = bs
		shape.position = f.origin + Vector3(0, 0.15, 0) + f.basis.z * -0.6
		solid.add_child(shape)
	var t := Train.make(cars_for(n), path, CRASH_D - SPEED * RUN_IN, 3 + n)
	t.crash_time = RUN_IN
	parent.add_child(t)
	return t


static func _solid_box(solid: StaticBody3D, c: Vector3, half: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = half * 2.0
	shape.shape = bs
	shape.position = c
	solid.add_child(shape)
