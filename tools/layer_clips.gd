extends "res://tools/siege_clips.gd"
## The track-laying train, recorded as video frames (Question Chat, 2026-11-10).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/layer_clips.gd -- [scene ...]
## Scenes: look, straight, curve, shelled. Frames go to results/units/anim_frames/layer_<scene>/,
## ffmpeg makes results/units/anim/layer_<scene>.mp4.
## The track runs at rail-top height Y0 (the old line's ballast sits on the ground, the new panels on a graded
## earth bed). One laying cycle is CYCLE seconds: pick a panel off the first flat, carry it out along the boom,
## lower it onto the bed, the crew guide it down and bolt the joint, then the train creeps 10 m onto it.

const LAYER_SCENES: Array[String] = ["look", "straight", "curve", "shelled"]
const Y0 := 0.3
const CYCLE := 16.0
const HIGH := 5.75

var cars: Array = []           # [TrainCar, centre distance behind the crane's centre]
var crane: LayerCar
var flat1: LayerCar
var eng: TrainCar
var dist_fn: Callable          # t -> the crane's centre distance along the path
var spread_fn: Callable        # t -> the spreader's frame (crane car frame)
var hang_fn: Callable          # t -> the panel on the hooks (world) or null
var rope_car: Array = []       # [LayerCar] whose ropes are drawn


func _run() -> void:
	prefix = "layer_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else LAYER_SCENES):
		await _record(sc)
	print("LAYER CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	cars.clear()
	rope_car.clear()
	dist_fn = func(_t: float) -> float: return 0.0
	spread_fn = func(_t: float) -> Transform3D: return Transform3D(Basis(), Vector3(0, HIGH, LayerCar.PARK_Z))
	hang_fn = func(_t: float) -> Variant: return null


# ---------------------------------------------------------------- the train

func straight_path() -> TrackPath:
	return TrackPath.line(Vector3(0, Y0, 90), Vector3(0, Y0, -110))


func make_train(stack1 := 6, stack2 := 6) -> void:
	crane = LayerCar.build("crane")
	flat1 = LayerCar.build("flat", false, stack1)
	var flat2 := LayerCar.build("flat", false, stack2)
	var coach := LayerCar.build("coach")
	eng = TrainParts.make("engine")
	var tender := TrainParts.make("tender")
	var list: Array[TrainCar] = [crane, flat1, flat2, coach, eng, tender]
	var off := 0.0
	for i in list.size():
		var cc := list[i]
		if i > 0:
			var prev := list[i - 1]
			off += prev.rear_z - cc.front_z + 0.02
		stage.add_child(cc)
		cars.append([cc, off])
	rope_car = [crane]
	var last := [-1.0]
	var beat := [0.0]
	updates.append(func(t: float) -> void:
		var d: float = dist_fn.call(t)
		var dd: float = 0.0 if float(last[0]) < 0.0 else d - float(last[0])
		last[0] = d
		for e: Array in cars:
			var cc: TrainCar = e[0]
			cc.global_transform = path.car_frame(d - float(e[1]), cc)
			cc.roll(dd)
		var sp: Transform3D = spread_fn.call(t)
		crane.set_trolley(sp.origin.z)
		crane.set_spreader(sp)
		# Engine smoke: beats while pushing, a lazy wisp when standing.
		var moved: float = d - float(beat[0])
		var top := eng.global_transform * (eng.marks["chimney"] as Vector3)
		if moved > 0.7:
			beat[0] = d
			smoke_p.add("smoke", top, Vector3(0, 3.5, 0), 0.8)
		elif frame % 18 == 0:
			beat[0] = d
			smoke_p.add("smoke", top, Vector3(0, 1.4, 0), 0.45)
		# The winch boiler on the crane car: a thin steady smoke, steam from the valve while hoisting.
		if frame % 12 == 0:
			smoke_p.add("smoke", crane.global_transform * (crane.marks["chimney"] as Vector3), Vector3(0, 1.6, 0), 0.32))


## The four ropes, trolley to spreader, and the four chains, spreader hooks to the panel's rails (or hanging).
func rigging() -> void:
	for r in 4:
		wire(func(_t: float) -> PackedVector3Array:
			var lc: LayerCar = rope_car[0]
			var rp: Array = lc.ropes()
			return PackedVector3Array([rp[r][0], rp[r][1]]))
	for h in 4:
		var s := -1.0 if h < 2 else 1.0
		var z := -3.2 if h % 2 == 0 else 3.2
		wire(func(t: float) -> PackedVector3Array:
			var lc: LayerCar = rope_car[0]
			var hk: Vector3 = lc.hooks()[h]
			var pw: Variant = hang_fn.call(t)
			if pw == null:
				return PackedVector3Array([hk, hk + Vector3(0, -0.45, 0)])
			var end: Vector3 = (pw as Transform3D) * Vector3(s * 0.7175, 0.01, z)
			return PackedVector3Array([hk, end]))


static func key_xf(keys: Array, t: float) -> Transform3D:
	if t <= float(keys[0][0]):
		return keys[0][1]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t < float(b[0]):
			var u := Anim.ease_of(clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0), "smooth")
			var xa: Transform3D = a[1]
			var xb: Transform3D = b[1]
			return Transform3D(xa.basis.slerp(xb.basis, u).orthonormalized(), xa.origin.lerp(xb.origin, u))
	return keys[keys.size() - 1][1]


static func hi(x: Transform3D) -> Transform3D:
	return Transform3D(x.basis, Vector3(x.origin.x, HIGH, x.origin.z))


static func yaw_of(f: Vector3) -> float:
	return atan2(-f.x, -f.z)


## A point beside the path: d along, s side (-1 left, +1 right), off metres out, on the ground.
func side(d: float, s: float, off: float) -> Vector3:
	var f := path.frame(d)
	var p := f.origin + f.basis.x * s * off
	p.y = 0.0
	return p


func crane_d0(e0: float) -> float:
	return e0 + LayerCar.CR_FRONT - 0.2


## Lays n panels from the track end e0, the first cycle starting at t0. freeze (if >= 0) stops the machine there
## (the train, the trolley and the hanging panel hold still). Returns the cycle start times.
func lay_run(e0: float, n: int, t0: float, freeze := -1.0) -> Array[float]:
	var dc0 := crane_d0(e0)
	var starts: Array[float] = []
	for k in n:
		starts.append(t0 + CYCLE * k)
	var fz := func(t: float) -> float: return minf(t, freeze) if freeze >= 0.0 else t
	dist_fn = func(t: float) -> float:
		var tt: float = fz.call(t)
		var d := dc0
		for k in n:
			d += LayerCar.PANEL_LEN * ramp(tt, starts[k] + 12.0, 4.0)
		return d
	var keys: Array = []
	var flat_off: float = cars[1][1]
	var laid: Array[Transform3D] = []
	for k in n:
		var dc := dc0 + LayerCar.PANEL_LEN * k
		var fc := path.car_frame(dc, crane)
		var ff := path.car_frame(dc - flat_off, flat1)
		var idx := flat1.stack.size() - 1 - k
		var pick := LayerCar.spreader_for(fc.affine_inverse() * ff * flat1.stack_xf(idx))
		var lay_w := LayerCar.panel_xf(path, e0 + LayerCar.PANEL_LEN * k)
		laid.append(lay_w)
		var drop := LayerCar.spreader_for(fc.affine_inverse() * lay_w)
		var s0 := starts[k]
		keys.append_array([[s0, hi(pick)], [s0 + 1.0, pick], [s0 + 1.4, pick], [s0 + 2.6, hi(pick)], [s0 + 6.0, hi(drop)],
			[s0 + 8.0, drop], [s0 + 8.4, drop], [s0 + 9.4, hi(drop)], [s0 + 12.0, hi(drop)]])
	keys.append([starts[n - 1] + 16.0, Transform3D(Basis(), Vector3(0, HIGH, LayerCar.PARK_Z))])
	spread_fn = func(t: float) -> Transform3D: return key_xf(keys, fz.call(t))
	hang_fn = func(t: float) -> Variant:
		var tt: float = fz.call(t)
		for k in n:
			var u := tt - starts[k]
			if u >= 1.2 and u < 8.0:
				return crane.global_transform * LayerCar.hang_from(spread_fn.call(t))
		return null
	var total := flat1.stack.size()
	updates.append(func(t: float) -> void:
		var tt: float = fz.call(t)
		var used := 0
		for k in n:
			if tt - starts[k] >= 1.2:
				used += 1
		flat1.set_stack(total - used))
	var pmesh := km_t(LayerCar.panel_geo())
	for k in n:
		var s0 := starts[k]
		var lw := laid[k]
		var pan := func(t: float) -> Transform3D:
			var u: float = fz.call(t) - s0
			if u < 1.2:
				return HIDE
			if u < 8.0:
				return crane.global_transform * LayerCar.hang_from(spread_fn.call(t))
			return lw
		prop(pmesh, [at_world(pan, 0.0)])
	return starts


## The laying gang: two guides at the panel's far end, two joint men with spanners, the foreman.
func gang(e0: float, starts: Array[float]) -> void:
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var n := starts.size()
	var guides: Array = []
	var joints: Array = []
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var g := man(601 + i, "gunner", side(e0 + 8.6, s, 2.4), yaw_of(-path.frame(e0).basis.x * s))
		pose(g, 0.0, 0.0, stand_free(), null, null)
		guides.append(g)
		var j := man(611 + i, "gunner", side(e0 - 0.6, s, 2.6), yaw_of(-path.frame(e0).basis.x * s))
		pose(j, 0.0, 0.0, stand_free(), null, null)
		joints.append(j)
	var fm := man(621, "nco", side(e0 + 4.0, -1.0, 4.6), yaw_of(path.frame(e0).basis.x * 0.6 - path.frame(e0).basis.z))
	pose(fm, 0.0, 0.0, stand_free(), null, null)
	var spanner := TrainGeo.new()
	spanner.box(Vector3(0, -0.02, -0.1), Vector3(0.012, 0.006, 0.15), TrainParts.STEEL)
	spanner.box(Vector3(0, -0.02, -0.27), Vector3(0.03, 0.008, 0.03), TrainParts.STEEL)
	var sp_mesh := km_t(spanner)
	var reach := Rig.over(Body.body("stand"), {"rifle": GC.SLUNG, "pole_r": Vector3(0.7, -0.3, 0.3), "pole_l": Vector3(-0.7, -0.3, 0.3),
		"add": {B.SPINE: Vector3(-6, 0, 0), B.NECK: Vector3(-12, 0, 0)}})
	for k in n:
		var s0: float = starts[k]
		var ek := e0 + LayerCar.PANEL_LEN * k
		var fr := path.frame(ek)
		var pan := LayerCar.panel_xf(path, ek)
		# Guides: step in as the panel comes down, hands on the sleeper ends, steady it, step back, walk on.
		for i in 2:
			var s := -1.0 if i == 0 else 1.0
			var g: Dictionary = guides[i]
			var face := yaw_of(-path.frame(ek + 8.6).basis.x * s)
			var on_panel := func(t: float) -> Dictionary:
				var pw: Variant = hang_fn.call(t)
				var x: Transform3D = pan if pw == null else pw
				return {"hand_r": x * Vector3(s * 1.22, -0.1, -4.25 + 0.35 * s), "hand_l": x * Vector3(s * 1.22, -0.1, -4.25 - 0.35 * s)}
			shift(g, s0 + 6.4, 0.6, stand_free(), side(ek + 8.6, s, 1.95), 0.0, null, "smooth", face)
			pose(g, s0 + 7.0, 0.5, reach, on_panel)
			pose(g, s0 + 7.6, 0.6, GC.heave(20.0, 25.0), on_panel)
			pose(g, s0 + 8.5, 0.4, stand_free())
			shift(g, s0 + 8.9, 0.6, stand_free(), side(ek + 8.6, s, 2.4), 0.0, null, "smooth", face)
			if k < n - 1:
				move(g, s0 + 12.4, side(ek + 18.6, s, 2.4), walk, yaw_of(-path.frame(ek + 18.6).basis.x * s))
		# Joint men: in to the joint once the panel is down, kneel, bolt the fishplates, out of the way, walk on.
		for i in 2:
			var s := -1.0 if i == 0 else 1.0
			var j: Dictionary = joints[i]
			var out := fr.basis.x * s
			var bolt := fr.origin + out * 0.78 + Vector3(0, -0.075, 0)
			var rail := fr.origin + out * 0.7175 + fr.basis.z * 0.35 + Vector3(0, 0.0, 0)
			var tk := move(j, s0 + 8.3, side(ek, s, 1.35), walk, yaw_of(-out))
			pose(j, tk, 0.5, T.kneel_work(18.0))
			var turn := func(t: float) -> Dictionary:
				var w := t * 7.0
				return {"hand_r": bolt + out * 0.06 + Vector3(0, 0.09 * sin(w), 0) + fr.basis.z * 0.09 * cos(w), "hand_l": rail}
			pose(j, tk + 0.5, 0.4, T.kneel_work(22.0), turn)
			var t_up := s0 + 11.4
			pose(j, t_up, 0.4, stand_free())
			shift(j, t_up + 0.4, 0.5, stand_free(), side(ek - 0.4, s, 2.6), 0.0, null, "smooth", yaw_of(-out))
			if k < n - 1:
				move(j, s0 + 12.6, side(ek + 9.4, s, 2.6), walk, yaw_of(-path.frame(ek + 10.0).basis.x * s))
			var rest := Transform3D(Basis(), B.REST[B.HAND_R] + palm_local(B.HAND_R))
			prop(sp_mesh, [at_world(HIDE, 0.0), on_bone(j, B.HAND_R, rest, tk + 0.4), at_world(HIDE, t_up + 0.2)])
		# Foreman: "lower away", watches the joint, then waves the train on and walks ahead with it.
		pose(fm, s0 + 5.4, 0.4, GC.nco_order(0.0))
		pose(fm, s0 + 8.2, 0.5, stand_free())
		for w in 3:
			pose(fm, s0 + 11.6 + 0.6 * w, 0.3, GC.nco_order(0.0))
			pose(fm, s0 + 11.9 + 0.6 * w, 0.3, GC.nco_order(0.55))
		pose(fm, s0 + 13.6, 0.4, stand_free())
		if k < n - 1:
			move(fm, s0 + 13.9, side(ek + 14.0, -1.0, 4.6), walk, yaw_of(path.frame(ek + 10.0).basis.x * 0.6 - path.frame(ek + 10.0).basis.z))


func lay_bed(e0: float, e1: float) -> void:
	stage.add_child(TrainParts.track(path, 0.0, e0))
	stage.add_child(LayerCar.bed(path, e0, e1))


# ---------------------------------------------------------------- look

func _scene_look() -> float:
	path = straight_path()
	var e0 := 100.0
	lay_bed(e0, 150.0)
	make_train()
	rigging()
	var dc := crane_d0(e0)
	dist_fn = func(_t: float) -> float: return dc
	var park := Transform3D(Basis(), Vector3(0, HIGH, LayerCar.PARK_Z))
	var front := Transform3D(Basis(), Vector3(0, HIGH, LayerCar.REACH_Z))
	var low := Transform3D(Basis(), Vector3(0, 1.4, LayerCar.REACH_Z))
	var keys := [[1.0, park], [4.5, front], [6.0, low], [7.0, low], [8.5, front], [11.5, park]]
	spread_fn = func(t: float) -> Transform3D: return key_xf(keys, t)
	# The wreck, on its own short siding off to the right.
	var side_path := TrackPath.line(Vector3(24, Y0, 40), Vector3(24, Y0, -10))
	stage.add_child(TrainParts.track(side_path, 0.0, 50.0))
	var wr := LayerCar.build("crane", true)
	stage.add_child(wr)
	wr.global_transform = side_path.car_frame(25.0, wr)
	wr.set_tip(0.47)
	wr.set_trolley(9.0)
	wr.set_spreader(Transform3D(Basis(Vector3(0, 0, 1), 0.5), Vector3(0.6, 2.4, 9.0)))
	updates.append(func(t: float) -> void: wr.visible = t >= 24.0)
	var counts := "crane car close %d / far %d tris, flat %d / %d, coach %d / %d" % [crane.tri_count(true), crane.tri_count(false),
		flat1.tri_count(true), flat1.tri_count(false), (cars[3][0] as LayerCar).tri_count(true), (cars[3][0] as LayerCar).tri_count(false)]
	var zc := path.point(dc).z
	var coach_z := path.point(dc - float(cars[3][1])).z
	var mid_z := path.point(dc - float(cars[5][1]) * 0.5).z
	_phases = [[0.0, "Track-laying train: crane car, two panel flats, crew coach, engine pushing"],
		[1.0, "The trolley runs out along the boom and lowers the spreader"], [9.0, "Panel flats: ready-made 10 m track panels on battens"],
		[13.0, "Crew coach: bunks, stove, tool rack"], [16.0, "The whole train (" + counts + ")"],
		[20.0, "Far look (the game swaps at 320 m)"], [24.0, "The wreck: boom snapped and folded down, burnt out"]]
	_camera = func(t: float) -> void:
		if t < 9.0:
			cam.fov = 48.0
			var a := -0.9 + t * 0.16
			cam.transform = Transform3D(Basis(), Vector3(sin(a) * 26.0, 9.0, zc + cos(a) * -26.0 * -1.0 - 4.0)).looking_at(Vector3(0, 4.0, zc - 2.0), Vector3.UP)
		elif t < 13.0:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), Vector3(8.0, 5.0, zc + 21.0 - (t - 9.0) * 0.5)).looking_at(Vector3(0, 2.4, zc + 13.6), Vector3.UP)
		elif t < 16.0:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), Vector3(7.0, 3.6, coach_z - 8.0)).looking_at(Vector3(0, 2.2, coach_z), Vector3.UP)
		elif t < 20.0:
			cam.fov = 50.0
			cam.transform = Transform3D(Basis(), Vector3(-52.0, 12.0, mid_z - 8.0)).looking_at(Vector3(0, 3.0, mid_z), Vector3.UP)
		elif t < 24.0:
			cam.fov = 9.0
			cam.transform = Transform3D(Basis(), Vector3(-260.0, 120.0, mid_z - 260.0)).looking_at(Vector3(0, 3.0, mid_z), Vector3.UP)
		else:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), Vector3(36.0, 7.5, 4.0)).looking_at(Vector3(24, 2.5, 15.0), Vector3.UP)
	# The wreck smoulders.
	for f in int(8.0 * FPS):
		if f % 5 == 0:
			later(20.0 + float(f) / FPS, func(_t: float) -> void:
				smoke_p.add("burn", wr.global_transform * Vector3(0, 3.6, 0.5) + smoke_p.jitter(0.6), Vector3(0, 2.2, 0), 1.0))
	return 28.0


# ---------------------------------------------------------------- straight

func _scene_straight() -> float:
	path = straight_path()
	var e0 := 100.0
	lay_bed(e0, 160.0)
	make_train()
	rigging()
	var starts := lay_run(e0, 3, 1.0)
	gang(e0, starts)
	var t_end := starts[2] + 17.0
	_phases = [[0.0, "Laying track: panels off the flat, out along the boom, down onto the bed"],
		[starts[0] + 1.0, "Panel 1: picked off the stack"], [starts[0] + 6.0, "Lowered; the guides steady it onto the rail ends"],
		[starts[0] + 8.8, "Joint men bolt the fishplates"], [starts[0] + 11.6, "Foreman waves the train on: it creeps 10 m onto the new panel"],
		[starts[1], "Panel 2"], [starts[2], "Panel 3 (the first flat's stack is half gone)"]]
	_camera = func(t: float) -> void:
		var d: float = dist_fn.call(t)
		var zc := path.point(d).z
		if t < starts[1]:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), Vector3(-25.0, 9.5, zc - 24.0)).looking_at(Vector3(0, 2.6, zc - 6.0), Vector3.UP)
		elif t < starts[2]:
			cam.fov = 50.0
			var ej := path.point(e0 + 10.0).z
			cam.transform = Transform3D(Basis(), Vector3(-6.5, 2.0, ej - 11.5)).looking_at(Vector3(0.6, 1.4, ej - 1.0), Vector3.UP)
		else:
			cam.fov = 44.0
			cam.transform = Transform3D(Basis(), Vector3(28.0, 30.0, zc - 2.0)).looking_at(Vector3(0, 1.0, zc - 8.0), Vector3.UP)
	return t_end


# ---------------------------------------------------------------- curve

func _scene_curve() -> float:
	path = TrackPath.straight_curve(Vector3(0, Y0, 90), Vector3(0, 0, -1), 92.0, 110.0, 0.75, 40.0)
	var e0 := 92.0
	lay_bed(e0, 160.0)
	make_train()
	rigging()
	var starts := lay_run(e0, 3, 1.0)
	gang(e0, starts)
	var t_end := starts[2] + 17.0
	_phases = [[0.0, "Laying round a bend (110 m radius): the bed is pegged out ahead"],
		[starts[0] + 2.6, "The spreader swings to line the panel up with the curve"],
		[starts[1], "Each 10 m panel is a straight chord of the curve"], [starts[2], "Third panel: the train follows round"]]
	_camera = func(t: float) -> void:
		var d: float = dist_fn.call(t)
		var focus := path.point(d + 10.0)
		if t < starts[1] + 4.0:
			cam.fov = 46.0
			var a := 0.4 + t * 0.012
			cam.transform = Transform3D(Basis(), focus + Vector3(cos(a) * 30.0, 26.0, -sin(a) * 30.0 + 6.0)).looking_at(focus + Vector3(0, 1.0, 0), Vector3.UP)
		elif t < starts[2] + 4.0:
			cam.fov = 48.0
			var f := path.frame(d + 14.0)
			cam.transform = Transform3D(Basis(), f.origin + f.basis.x * 11.0 + f.basis.z * 4.0 + Vector3(0, 6.5, 0)).looking_at(f.origin + Vector3(0, 2.0, 0) + f.basis.z * 6.0, Vector3.UP)
		else:
			cam.fov = 40.0
			cam.transform = Transform3D(Basis(), focus + Vector3(-24.0, 26.0, 20.0)).looking_at(focus + Vector3(-2.0, 1.0, 4.0), Vector3.UP)
	return t_end


# ---------------------------------------------------------------- shelled

## A shell burst on open ground (or on the train): flash, an earth fountain, smoke, the camera shaken.
func burst_at(at: Vector3, ts: float, scale := 1.0) -> void:
	var fl := func(t: float) -> Variant:
		if t >= ts and t < ts + 0.12:
			return Transform3D(Basis().scaled(Vector3.ONE * (1.0 + 7.0 * (t - ts))), at + Vector3(0, 0.6, 0))
		return null
	glow(1.4 * scale, fl, 12.0)
	later(ts, func(_t: float) -> void:
		for k in 34:
			var v := Vector3(randf_range(-3.0, 3.0), randf_range(9.0, 20.0), randf_range(-3.0, 3.0)) * scale
			smoke_p.add("dust", at + smoke_p.jitter(0.8), v, randf_range(1.2, 2.4) * scale)
		for k in 24:
			var ang := TAU * k / 24.0
			smoke_p.add("dust", at + Vector3(0, 0.3, 0), Vector3(cos(ang), 0.15, sin(ang)) * randf_range(7.0, 12.0) * scale, 1.8 * scale)
		for k in 16:
			smoke_p.add("smoke", at + smoke_p.jitter(1.2) + Vector3(0, 1.0, 0), smoke_p.jitter(2.0) + Vector3(0, 3.0, 0), 2.6 * scale)
		for k in 12:
			glow_p.add("flame", at + glow_p.jitter(0.6) + Vector3(0, 0.5, 0), glow_p.jitter(5.0) + Vector3(0, 6.0, 0), 1.4 * scale))
	var old := shake_fn
	shake_fn = func(t: float) -> Vector3:
		var s: Vector3 = old.call(t)
		var u := t - ts
		if u >= 0.0 and u < 1.2:
			s += Vector3(sin(t * 91.0), sin(t * 77.0 + 1.0), sin(t * 63.0 + 2.0)) * 0.3 * scale * (1.0 - u / 1.2)
		return s


func _scene_shelled() -> float:
	path = straight_path()
	var e0 := 100.0
	lay_bed(e0, 160.0)
	make_train()
	rigging()
	var near := 2.4
	var hit := 6.4
	# Work stops when the first shell lands: the panel hangs out over the bed.
	lay_run(e0, 1, -3.4, near + 0.8)
	var walk := Body.gait(Body.WALK, C.carry("free"))
	var run := Body.gait(Body.RUN, C.carry("free"))
	var fr := path.frame(e0)
	var crew: Array = []
	var spots := [[side(e0 + 8.6, -1.0, 2.4), -1.0], [side(e0 + 8.6, 1.0, 2.4), 1.0], [side(e0 - 0.6, -1.0, 2.6), -1.0],
		[side(e0 - 0.6, 1.0, 2.6), 1.0], [side(e0 - 18.0, 1.0, 2.6), 1.0], [side(e0 - 21.0, -1.0, 2.6), -1.0]]
	for i in spots.size():
		var s: float = spots[i][1]
		var a := man(701 + i, "gunner", spots[i][0], yaw_of(-fr.basis.x * s))
		pose(a, 0.0, 0.0, stand_free(), null, null)
		crew.append(a)
	var fm := man(721, "nco", side(e0 + 4.0, -1.0, 4.6), yaw_of(fr.basis.x * 0.6 - fr.basis.z))
	pose(fm, 0.0, 0.0, GC.nco_order(0.0), null, null)
	# The near miss, right of the bed ahead: everyone flinches, the gang go flat, the two by the flats run for the coach.
	var miss := side(e0 + 4.0, 1.0, 13.0)
	burst_at(miss, near, 1.0)
	for i in crew.size():
		var a: Dictionary = crew[i]
		pose(a, near + 0.05, 0.25, GC.flinch(stand_free(), true))
		if i < 4:
			var s: float = spots[i][1]
			var p: Vector3 = spots[i][0]
			var away := (p - miss)
			away.y = 0.0
			pose(a, near + 0.6, 0.7, T.prone_free(), null, "prev", "smooth", null, yaw_of(away.normalized()))
		else:
			move(a, near + 0.7, side(e0 - 40.0, spots[i][1], 2.6), run, yaw_of(fr.basis.z))
	pose(fm, near + 0.05, 0.25, GC.flinch(stand_free(), true))
	pose(fm, near + 0.9, 0.4, GC.nco_point(Vector3(-2.0, 1.0, 3.0)))
	pose(fm, near + 2.6, 0.5, T.duck(GC.crouch(20.0)))
	# The hit on the crane car's front tower: the healthy car swaps for the wreck, the boom tip folds down, the
	# hanging panel drops onto the bed, the foreman is knocked over, the winch house burns.
	var wr := LayerCar.build("crane", true)
	stage.add_child(wr)
	wr.visible = false
	var at_hit := [Transform3D(), Transform3D()]
	updates.append(func(t: float) -> void:
		if t < hit:
			return
		if at_hit[0] == Transform3D():
			at_hit[0] = crane.global_transform
			var pw: Variant = hang_fn.call(hit - 0.01)
			at_hit[1] = pw if pw != null else Transform3D()
		crane.visible = false
		wr.visible = true
		wr.global_transform = at_hit[0]
		var u := clampf((t - hit) / 1.15, 0.0, 1.0)
		var bounce := 0.03 * sin(clampf(t - hit - 1.15, 0.0, 1.0) * 9.0) * exp(-(t - hit - 1.15) * 4.0) if t > hit + 1.15 else 0.0
		wr.set_tip(0.475 * u * u + bounce)
		wr.set_trolley(9.0)
		wr.set_spreader(Transform3D(Basis(Vector3(0, 0, 1), 0.5 * u), Vector3(0.5 * u, lerpf(HIGH, 2.3, u * u), 9.0)))
		rope_car[0] = wr)
	var panel_fall := func(t: float) -> Variant:
		if t < hit:
			return null
		var from: Transform3D = at_hit[1]
		var land := from
		land.origin.y = Y0 - 0.16
		var tumble := Basis(from.basis.x, 0.07) * Basis(Vector3.UP, 0.18)
		var tf := sqrt(2.0 * maxf(from.origin.y - land.origin.y, 0.1) / 9.8)
		var u := clampf((t - hit) / tf, 0.0, 1.0)
		var b := from.basis.slerp((tumble * from.basis).orthonormalized(), u)
		return Transform3D(b, from.origin.lerp(land.origin, u * u) + from.basis.x * 0.5 * u)
	var fall_xf := func(t: float) -> Transform3D:
		var x: Variant = panel_fall.call(t)
		return HIDE if x == null else x
	prop(km_t(LayerCar.panel_geo()), [at_world(HIDE, 0.0), at_world(fall_xf, hit)])
	# The working panel prop from lay_run is hidden from the hit (the falling copy takes over).
	var old_hang := hang_fn
	hang_fn = func(t: float) -> Variant:
		if t >= hit:
			return null
		return old_hang.call(t)
	for p: Dictionary in props:
		if p.has("keys") and (p["keys"] as Array).size() == 1:
			(p["keys"] as Array).append(at_world(HIDE, hit))
	var tower := path.car_frame(crane_d0(e0), crane) * Vector3(0.6, 5.0, -LayerCar.TOWER_Z)
	burst_at(tower, hit, 1.3)
	later(hit, func(_t: float) -> void:
		for k in 30:
			glow_p.add("spark", tower + glow_p.jitter(0.5), glow_p.jitter(12.0) + Vector3(0, 6.0, 0), 0.25))
	var tip_land := path.car_frame(crane_d0(e0), crane) * Vector3(0, 0.3, LayerCar.BOOM_F + 1.5)
	later(hit + 1.1, func(_t: float) -> void:
		for k in 26:
			smoke_p.add("dust", tip_land + smoke_p.jitter(1.5), smoke_p.jitter(4.0) + Vector3(0, 1.5, 0), 1.6))
	clip(fm, hit + 0.08, Body.death_back(GC.crouch(20.0), C.carry("free")))
	var fires := [Vector3(0.3, 3.6, -1.5), Vector3(-0.6, 3.4, 1.0), Vector3(0.6, 5.2, -4.2)]
	for f in int(9.0 * FPS):
		var t := hit + 0.4 + float(f) / FPS
		if f % 2 == 0:
			later(t, func(_t: float) -> void:
				var at: Vector3 = wr.global_transform * (fires[f % fires.size()] as Vector3)
				glow_p.add("flame", at + glow_p.jitter(0.4), Vector3(0, 2.2, 0), 1.2)
				if f % 4 == 0:
					smoke_p.add("burn", at + Vector3(0, 0.8, 0), Vector3(0, 3.2, 0), 1.5))
	# The gang get up after the hit and drag the foreman clear.
	for i in 2:
		var a: Dictionary = crew[i + 2]
		var s: float = spots[i + 2][1]
		pose(a, hit + 2.6, 0.7, stand_free())
		var at := side(e0 + 4.0 + 0.8 * s, -1.0, 4.6 - 0.9 * s)
		var ta := move(a, hit + 3.4, at, run, yaw_of(fr.basis.x))
		pose(a, ta, 0.5, GC.heave(40.0, 30.0))
	_phases = [[0.0, "Shelled while laying: the panel is out on the boom"], [near, "Near miss: work stops, the gang hit the dirt"],
		[hit, "Direct hit on the crane car"], [hit + 1.2, "The boom snaps and folds down, the panel drops"],
		[hit + 3.0, "Knocked out: the winch house burns, the gang go for the foreman"]]
	_camera = func(t: float) -> void:
		var zc := path.point(crane_d0(e0)).z
		var x: Transform3D
		if t < hit + 3.0:
			cam.fov = 50.0
			x = Transform3D(Basis(), Vector3(-26.0, 8.0, zc - 20.0)).looking_at(Vector3(2.0, 2.8, zc - 5.0), Vector3.UP)
		else:
			cam.fov = 46.0
			x = Transform3D(Basis(), Vector3(-15.0, 5.0, zc - 17.0)).looking_at(Vector3(-1.0, 2.0, zc - 6.0), Vector3.UP)
		cam.transform = shoot_cam(x, t)
	return hit + 9.5
