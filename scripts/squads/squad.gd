class_name Squad
extends Node3D
## Iron Front: a squad on the map: a 12-man rifle squad, or a 4-man engineer section (NCO and three sappers) that
## builds (squads round 1: select and move; no fighting yet; building round: engineers).
## - The squad has one route. Its lead point walks the route, and drops a trail of breadcrumbs behind it.
## - On the move the men walk two abreast in a column down the trail, so they follow it round cliffs and up ramps.
## - When the squad stops they form ranks `files` men wide (two ranks of six unless a drawn line says otherwise),
##   facing the way the order said (or the way they were going).
## - Each man plays the shared walk, run or ready clip (baked once per kind from the animation library).
## - Work (engineers): BuildControl gives the squad work spots; once halted each man walks to his spot, faces the
##   work and plays his work clip (hammer, saw, shovel, maul...). men_at_work() says how many are working.

const R := preload("res://scripts/units/anim/clips_rifle.gd")
const E := preload("res://scripts/units/anim/clips_engineer.gd")
const Body := preload("res://scripts/units/anim/clips_body.gd")
const Anim := preload("res://scripts/units/anim/anim.gd")
const MEN := 12
const WALK_V := 1.35                           # the walk clip's speed (m/s)
const RUN_V := 3.7
const COL_GAP := 2.2                           # metres between ranks of the column
const COL_SIDE := 0.9                          # half the gap between the two files
const LINE_GAP := 2.2                          # metres between men in a halted rank
const LINE_DEPTH := 2.5
const CRUMB := 0.5                             # trail spacing (m)
const MIN_FILES := 3                           # narrowest line: 3 men wide, 4 ranks deep

static var _libs: Dictionary = {}              # kind -> AnimationLibrary
static var _eng_clips: Dictionary = {}         # engineer clip name -> clip (for the tool each clip holds)
## The clips an engineer can work with (baked into the engineers' library).
const WORK_CLIPS := ["eng_hammer", "eng_hammer_low", "eng_saw", "eng_shovel", "eng_pick", "eng_drive", "eng_hold",
	"eng_nco_check"]

var nav: NavGrid
var title := "Rifles"
var kind := "rifles"                           # "rifles" or "engineers"
var count := MEN                               # men in the squad
var status := ""                               # a word for the banner (engineers: what they are building)
var jobs: Array = []                           # engineers: build sites to do, in order (BuildControl owns them)
var job: Variant = null                        # engineers: the site being built now
var working := false                           # at the site: men go to work_spots and play work_clip
var work_spots: Array[Vector2] = []
var work_face: Array[Vector2] = []
var work_clip: Array[String] = []
var _at_work: Array[bool] = []
var men: Array[Soldier] = []
var players: Array[AnimationPlayer] = []
var rings: Array[MeshInstance3D] = []
var at := Vector2.ZERO                         # the lead point (metres, x/z)
var heading := Vector2(0, -1)                  # the way the squad faces
var files := 6                                 # men in each rank when halted
var face_goal := Vector2.ZERO                  # the way to face on arrival (zero: the way they were going)
var path := PackedVector2Array()
var running := false
var selected := false
var trail: Array[Vector2] = []                 # newest first
var mpos: Array[Vector2] = []                  # each man's place
var mface: Array[float] = []
var banner: Label3D
var line_mesh: MeshInstance3D
var _imm: ImmediateMesh
var _clip: Array[String] = []


## The walk, run and ready clips (and the engineers' work clips), baked once per kind and shared by every squad.
static func library(geo: UnitGeo, of_kind := "rifles") -> AnimationLibrary:
	if _libs.has(of_kind):
		return _libs[of_kind]
	var al := AnimationLibrary.new()
	if of_kind == "engineers":
		var el := E.library()
		_eng_clips = el.duplicate()
		var run := Body.gait(Body.RUN, E.carry("shovel"))
		run["props"] = {"hand": [[0.0, "shovel"]]}
		_eng_clips["walk"] = el["eng_walk"]
		_eng_clips["run"] = run
		_eng_clips["ready"] = el["eng_hold_stand"]
		for nm: String in ["walk", "run", "ready"]:
			al.add_animation(nm, Anim.bake(_eng_clips[nm], geo))
		for nm: String in WORK_CLIPS:
			al.add_animation(nm, Anim.bake(el[nm], geo))
	else:
		var lib := R.library()
		al.add_animation("walk", Anim.bake(lib["walk"], geo))
		al.add_animation("run", Anim.bake(lib["run"], geo))
		var ready_pose: Dictionary = R.poses()["ready"]
		al.add_animation("ready", Anim.bake({"name": "ready", "len": 1.0, "loop": true, "keys": [[0.0, ready_pose], [1.0, ready_pose]]}, geo))
	_libs[of_kind] = al
	return al


func setup(nav_grid: NavGrid, where: Vector2, face: Vector2, seed_value: int, name_text: String, of_kind := "rifles") -> Squad:
	nav = nav_grid
	title = name_text
	kind = of_kind
	count = 4 if kind == "engineers" else MEN
	files = count if kind == "engineers" else 6
	at = nav.nearest_open(where)
	heading = face.normalized()
	for i in count:
		var s: Soldier
		if kind == "engineers":
			s = Engineer.new()
			add_child(s)
			s.setup(seed_value * 100 + i, 1, "nco" if i == 0 else "sapper")
		else:
			s = Soldier.new()
			add_child(s)
			s.setup(seed_value * 100 + i, 1)
		var ap := AnimationPlayer.new()
		s.add_child(ap)
		ap.add_animation_library("", library(s.geo, kind))
		ap.play("ready")
		ap.seek(randf() * 0.9, true)
		men.append(s)
		players.append(ap)
		_clip.append("ready")
		_at_work.append(false)
		_props(i, "ready")
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.55
		tm.rings = 16
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = _flat(Color(1.0, 0.86, 0.25))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale = Vector3(1, 0.15, 1)
		ring.visible = false
		add_child(ring)
		rings.append(ring)
		mpos.append(_slot_free(i))
		mface.append(_yaw(heading))
	banner = Label3D.new()
	banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner.fixed_size = true
	banner.pixel_size = 0.0012
	banner.font_size = 28
	banner.outline_size = 8
	banner.no_depth_test = true
	add_child(banner)
	_imm = ImmediateMesh.new()
	line_mesh = MeshInstance3D.new()
	line_mesh.mesh = _imm
	line_mesh.material_override = _flat(Color(1.0, 0.86, 0.25, 0.8))
	line_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line_mesh)
	_place_men(0.0)
	return self


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	return m


static func _yaw(dir: Vector2) -> float:
	# The soldier faces -Z.
	return atan2(-dir.x, -dir.y)


## Sends the squad to a point (metres). Returns false if it cannot get there.
## face: the way to face on arrival (zero keeps the way they were going). width: men per rank (0 keeps it).
func order_move(to: Vector2, run := false, face := Vector2.ZERO, width := 0) -> bool:
	var p := nav.find_path(at, to)
	if p.is_empty():
		return false
	face_goal = face.normalized() if face.length() > 0.001 else Vector2.ZERO
	if width > 0:
		files = clampi(width, mini(MIN_FILES, count), count)
	if at.distance_to(to) < 0.3:
		_arrive()                                  # already there: just turn and re-form
		return true
	if path.is_empty():
		trail.clear()                              # setting off from a halt: fall in behind the new route
		trail.push_front(at)
	path = p
	running = run
	return true


func moving() -> bool:
	return not path.is_empty()


## The unit card's run/walk switch: speeds up or slows down a squad that is on the move.
func set_running(on: bool) -> void:
	if moving():
		running = on


func men_left() -> int:
	return men.size()


func _process(delta: float) -> void:
	_step(delta)
	_place_men(delta)


## Moves the lead point along the route and lays the trail (also called by the headless check).
func _step(delta: float) -> void:
	if path.is_empty():
		return
	var v := (RUN_V if running else WALK_V) * _slow(at)
	var left := v * delta
	while left > 0.0 and not path.is_empty():
		var to := path[0]
		var d := at.distance_to(to)
		if d < 0.001:
			path.remove_at(0)
			continue
		var dir := (to - at) / d
		heading = dir
		var s := minf(left, d)
		at += dir * s
		left -= s
		if d <= s + 0.001:
			path.remove_at(0)
			if path.is_empty():
				_arrive()
		if trail.is_empty() or trail[0].distance_to(at) >= CRUMB:
			trail.push_front(at)
	var keep := int((count / 2 + 2) * COL_GAP / CRUMB) + 4
	if trail.size() > keep:
		trail.resize(keep)


func _arrive() -> void:
	path.clear()
	if face_goal != Vector2.ZERO:
		heading = face_goal


## Halted ranks for a squad of n men `width` wide: [ranks, men in the last rank].
static func ranks_for(width: int, n := MEN) -> Vector2i:
	var r := ceili(float(n) / width)
	return Vector2i(r, n - (r - 1) * width)


## Where man i stands when halted, relative to the lead point: x across (right +), y back (+). Static so the
## drag preview can draw the same places before the order is given.
static func free_offset(i: int, width: int, n := MEN) -> Vector2:
	var rf := ranks_for(width, n)
	var rank := i / width
	var file := i % width
	var in_rank := width if rank < rf.x - 1 else rf.y   # the last rank may be short: keep it centred
	return Vector2((float(file) - (in_rank - 1) * 0.5) * LINE_GAP, float(rank) * LINE_DEPTH + 1.0)


func _slow(p: Vector2) -> float:
	return 1.0 / nav.astar.get_point_weight_scale(nav.cell_of(p))


## Where man i should be: in the column on the trail while moving, at his work spot when working, in ranks when halted.
func _slot(i: int) -> Vector2:
	if not moving() and working and i < work_spots.size():
		return work_spots[i]
	if moving():
		var rank := i / 2
		var side := -COL_SIDE if i % 2 == 0 else COL_SIDE
		var back := float(rank) * COL_GAP + 0.8
		var k := int(back / CRUMB)
		var p := at
		var dir := heading
		if k < trail.size():
			p = trail[k]
			var nxt: Vector2 = trail[maxi(k - 2, 0)]
			if nxt.distance_to(p) > 0.01:
				dir = (nxt - p).normalized()
		else:
			return mpos[i]                         # the column has not reached him yet: wait, then fall in
		var q := p + Vector2(-dir.y, dir.x) * side
		return q if _same_ground(q, p) else p
	return _slot_free(i)


func _slot_free(i: int) -> Vector2:
	var o := free_offset(i, files, count)
	var right := Vector2(-heading.y, heading.x)
	var q := at + right * o.x - heading * o.y
	return q if _same_ground(q, at) else at - heading * float(i) * 0.6


## Engineers: stop work and drop every job (a move order from the player does this).
func cancel_job() -> void:
	jobs.clear()
	job = null
	stop_work()


func stop_work() -> void:
	working = false
	work_spots.clear()
	work_face.clear()
	work_clip.clear()
	status = ""


## Starts work: one spot, facing and clip per man (fewer spots than men: the rest wait in ranks).
func start_work(spots: Array[Vector2], faces: Array[Vector2], clips: Array[String]) -> void:
	working = true
	work_spots = spots
	work_face = faces
	work_clip = clips


## How many men are at their spot and working.
func men_at_work() -> int:
	var n := 0
	for i in _at_work.size():
		if _at_work[i]:
			n += 1
	return n


func is_engineers() -> bool:
	return kind == "engineers"


## The tool in an engineer's hand follows the clip he plays.
func _props(i: int, clip: String) -> void:
	if kind != "engineers" or not _eng_clips.has(clip):
		return
	(men[i] as Engineer).set_props(Engineer.prop_state(_eng_clips[clip], 0.0))


func _same_ground(q: Vector2, p: Vector2) -> bool:
	return nav.is_open(q) and absf(nav.height(q) - nav.height(p)) < 1.2


func _place_men(delta: float) -> void:
	var base_v := (RUN_V if running else WALK_V)
	for i in men.size():
		var goal := _slot(i)
		var d := mpos[i].distance_to(goal)
		var v := 0.0
		var at_spot := working and not moving() and i < work_spots.size() and d <= 0.3
		_at_work[i] = at_spot
		if at_spot:
			mface[i] = lerp_angle(mface[i], _yaw(work_face[i]), 1.0 - exp(-delta * 6.0)) if delta > 0.0 else _yaw(work_face[i])
		if d > 0.05 and delta > 0.0:
			# Men behind their place hurry a little; men close to it ease in.
			var want := base_v * _slow(mpos[i]) * clampf(d / 1.5, 0.3, 1.35)
			if d > 25.0:
				want = RUN_V                           # far out of place: run to catch up
			var s := minf(want * delta, d)
			var dir := (goal - mpos[i]) / d
			mpos[i] += dir * s
			v = s / delta
			if not at_spot:
				mface[i] = lerp_angle(mface[i], _yaw(dir), 1.0 - exp(-delta * 8.0))
		elif not moving() and not at_spot:
			mface[i] = lerp_angle(mface[i], _yaw(heading), 1.0 - exp(-delta * 4.0))
		var p := mpos[i]
		var y := nav.height(p)
		men[i].position = Vector3(p.x, y, p.y)
		men[i].rotation.y = mface[i]
		rings[i].position = Vector3(p.x, y + 0.06, p.y)
		rings[i].visible = selected
		if delta > 0.0:
			var clip := "ready"
			if v > 2.4:
				clip = "run"
			elif v > 0.25:
				clip = "walk"
			elif at_spot and i < work_clip.size():
				clip = work_clip[i]
			if clip != _clip[i]:
				_clip[i] = clip
				players[i].play(clip, 0.25)
				_props(i, clip)
			players[i].speed_scale = clampf(v / (RUN_V if clip == "run" else WALK_V), 0.5, 1.6) if clip in ["walk", "run"] else 1.0
	banner.position = Vector3(at.x, nav.height(at) + 4.0, at.y)
	banner.text = "%s  %d%s%s" % [title, men.size(), ("  >>" if running else "  >") if moving() else "", ("  " + status) if not status.is_empty() else ""]
	banner.modulate = Color(1.0, 0.9, 0.35) if selected else Color(0.85, 0.95, 1.0)
	_draw_route()


func _draw_route() -> void:
	_imm.clear_surfaces()
	if not selected or path.is_empty():
		return
	_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	var a := at
	for b in path:
		var n := maxi(1, int(a.distance_to(b) / 8.0))
		for k in n:
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			_imm.surface_add_vertex(Vector3(p0.x, nav.height(p0) + 0.4, p0.y))
			_imm.surface_add_vertex(Vector3(p1.x, nav.height(p1) + 0.4, p1.y))
		a = b
	# A cross at the end of the route.
	var e := path[path.size() - 1]
	var ey := nav.height(e) + 0.4
	for o in [Vector2(2, 2), Vector2(2, -2)]:
		_imm.surface_add_vertex(Vector3(e.x - o.x, ey, e.y - o.y))
		_imm.surface_add_vertex(Vector3(e.x + o.x, ey, e.y + o.y))
	_imm.surface_end()


## Screen points of the men (for clicking and box selection).
func screen_points(cam: Camera3D) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for m in men:
		var p := m.global_position + Vector3(0, 1.0, 0)
		if not cam.is_position_behind(p):
			out.append(cam.unproject_position(p))
	if not cam.is_position_behind(banner.global_position):
		out.append(cam.unproject_position(banner.global_position))
	return out
