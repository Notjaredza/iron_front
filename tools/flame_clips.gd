extends "res://tools/zombie_clips.gd"
## The flamethrowers, recorded as video frames (Question Chat, flamethrower round, 2026-11-10).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/flame_clips.gd -- [scene ...]
## Scenes:
##   trench  clearing a trench: the man-pack team and the flame tank burn out a red jacket trench; one operator is
##           shot and his tanks burst.
##   wall    against zombies at a wall: the heavy trench flamer and two man-pack flamers on our wall burn the horde;
##           the flame wagon is pushed out through the rail gate and adds its fire.
##   test    a short look at the jet, ground fire, burning man and fireball (for checking only).
##   kit     one still of the kit: operators, assistant, heavy flamer, flame tank, flame wagon (for checking only).
## Frames go to results/units/anim_frames/flame_<scene>/, ffmpeg makes results/units/anim/flame_<scene>.mp4.

const FK := preload("res://scripts/flame/flamer_kit.gd")
const M := preload("res://scripts/units/anim/clips_musket.gd")
const RB := preload("res://scripts/units/redcoat_builder.gd")
const FLAME_SCENES: Array[String] = ["trench", "wall"]
const LANCE_O := Vector3(0.17, 1.0, -0.22)   # the lance's rear grip, actor frame
const CARRY := Vector2(-0.22, 0.1)          # carried: nozzle down and a little in
const TANKS_XF := Transform3D(Basis(), Vector3(0, 0.06, 0.13))  # on the chest bone
const JET_V := 17.0
const HEAVY_V := 21.0
const TANK_V := 22.0
const G_EFF := 9.8 * 0.62 * 1.1

var fx: FlameFx
var levels: Array = []  # [Rect2 (x, z), height]; the last one that holds wins
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var lance_mesh: Mesh
var tanks_mesh: Mesh
var can_mesh: Mesh
var mlib: Dictionary
var watch: Array = []  # actors that catch fire when the fire reaches them: {a, react, lit}


func _run() -> void:
	prefix = "flame_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	for c in root.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D:
			sun = c
	sky_mat = env.sky.sky_material
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	cam.far = 400.0
	lance_mesh = FK.mesh(FK.lance())
	tanks_mesh = FK.mesh(FK.back_tanks())
	can_mesh = FK.mesh(FK.spare_can())
	mlib = M.library()
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else FLAME_SCENES):
		await _record(sc)
	print("FLAME CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	levels.clear()
	watch.clear()
	fx = FlameFx.make(7)
	fx.ground_fn = gh
	stage.add_child(fx)


func _effects(t: float) -> void:
	super._effects(t)
	if frame % 2 == 0:
		_catch(t)
	fx.step(t, 1.0 / FPS)


func gh(p: Vector3) -> float:
	var h := 0.0
	for lv: Array in levels:
		if (lv[0] as Rect2).has_point(Vector2(p.x, p.z)):
			h = lv[1]
	return h


## Day (overcast afternoon) or dusk (low red sun, dark sky: the fire lights everything).
func mood(dusk: bool) -> void:
	if dusk:
		sky_mat.sky_top_color = Color(0.10, 0.12, 0.2)
		sky_mat.sky_horizon_color = Color(0.55, 0.36, 0.26)
		sky_mat.ground_horizon_color = Color(0.35, 0.27, 0.22)
		sky_mat.ground_bottom_color = Color(0.12, 0.1, 0.09)
		env.ambient_light_energy = 0.45
		sun.light_energy = 0.6
		sun.light_color = Color(1.0, 0.62, 0.42)
		sun.rotation_degrees = Vector3(-12, 140, 0)
		env.fog_enabled = true
		env.fog_light_color = Color(0.28, 0.24, 0.24)
		env.fog_density = 0.006
	else:
		sky_mat.sky_top_color = Color(0.42, 0.5, 0.6)
		sky_mat.sky_horizon_color = Color(0.72, 0.74, 0.74)
		sky_mat.ground_horizon_color = Color(0.7, 0.72, 0.72)
		sky_mat.ground_bottom_color = Color(0.35, 0.33, 0.28)
		env.ambient_light_energy = 0.7
		sun.light_energy = 0.95
		sun.light_color = Color(1.0, 0.94, 0.85)
		sun.rotation_degrees = Vector3(-38, -35, 0)
		env.fog_enabled = true
		env.fog_light_color = Color(0.66, 0.68, 0.7)
		env.fog_density = 0.004


# ---------------------------------------------------------------- aiming

## The low launch angle that lands a jet at (dx along the ground, dy up) for launch speed v (gravity as the fuel
## falls, a little extra for the drag).
static func pitch_for(dx: float, dy: float, v: float) -> float:
	var v2 := v * v
	var disc := v2 * v2 - G_EFF * (G_EFF * dx * dx + 2.0 * dy * v2)
	if disc < 0.0:
		return 0.7
	return atan((v2 - sqrt(disc)) / (G_EFF * maxf(dx, 0.1)))


## Pitch and yaw (in frame xf, -Z forward) from a launch point to a target.
static func aim_in(xf: Transform3D, from_local: Vector3, target: Vector3, v: float) -> Vector2:
	var tl := xf.affine_inverse() * target - from_local
	var dx := Vector2(tl.x, tl.z).length()
	return Vector2(pitch_for(dx, tl.y, v), atan2(-tl.x, -tl.z))


static func lance_local(aim: Vector2) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, aim.y) * Basis(Vector3.RIGHT, aim.x), LANCE_O)


func lance_world(a: Dictionary, t: float) -> Transform3D:
	var s: Soldier = a["s"]
	var root_xf := Transform3D(Basis(Vector3.UP, s.rotation.y), s.position)
	return root_xf * lance_local((a["aim_fn"] as Callable).call(t))


## The lance held in both hands (body pose plus the hands on the grips, actor frame).
static func hold(body_name: String, aim: Vector2) -> Dictionary:
	var L := lance_local(aim)
	return Rig.over(Body.body(body_name), {"rifle": {"mode": "back"}, "hand_r": [-1, L * FK.LANCE_REAR],
		"hand_l": [-1, L * FK.LANCE_FRONT], "pole_r": Vector3(0.7, -0.6, 0.3), "pole_l": Vector3(-0.8, -0.5, 0.0)})


static func in_spans(spans: Array, t: float) -> bool:
	for sp: Array in spans:
		if t >= float(sp[0]) and t < float(sp[1]):
			return true
	return false


# ---------------------------------------------------------------- the men

## A man-pack operator: tanks on his back, the lance in both hands, the hose between. Returns the actor; set
## a["fire"] (spans), a["shots"] (aim windows [t0, t1, target_fn(t) -> Vector3, at, yaw]).
func operator(seed_value: int, pos: Vector3, yaw: float) -> Dictionary:
	var a := troop(seed_value, "gunner", pos, yaw)
	a["fire"] = []
	a["windows"] = []
	a["dead"] = INF
	a["aim_fn"] = func(t: float) -> Vector2:
		for w: Array in a["windows"]:
			var t0: float = w[0]
			var t1: float = w[1]
			if t >= t0 - 0.01 and t <= t1 + 0.6:
				var xf := Transform3D(Basis(Vector3.UP, float(w[4])), w[3])
				var tgt: Vector3 = (w[2] as Callable).call(clampf(t, t0, t1))
				var want := aim_in(xf, LANCE_O + Vector3(0, 0.25, -0.9), tgt, JET_V)
				want.y = clampf(want.y, -0.7, 0.7)
				var u := ramp(t, t0, 0.45) * (1.0 - ramp(t, t1 + 0.1, 0.45))
				return CARRY.lerp(want, u)
		return CARRY
	prop(tanks_mesh, [[0.0, 0.0, "bone", [a, B.CHEST, TANKS_XF]]])
	a["tanks_prop"] = props.back()
	prop(lance_mesh, [[0.0, 0.0, "world", func(t: float) -> Transform3D: return lance_world(a, t)]])
	a["lance_prop"] = props.back()
	dyn(func(t: float) -> Variant:
		var s: Soldier = a["s"]
		if not s.visible or t > float(a["dead"]) + 0.2:
			return null
		var tk := s.global_transform * s.skel.get_bone_global_pose(B.CHEST) * TANKS_XF
		var p0 := tk * FK.TANKS_HOSE
		var p1 := lance_world(a, t) * Vector3(0, -0.08, 0.2)
		var pts := PackedVector3Array()
		for k in 7:
			var u := float(k) / 6.0
			pts.append(p0.lerp(p1, u) + Vector3(0, -0.22 * sin(u * PI), 0))
		return km(K.wire(pts, 0.016)))
	fx.add_jet(func(t: float) -> Variant:
		if t >= float(a["dead"]):
			return null
		var x := lance_world(a, t)
		return {"from": x * FK.LANCE_NOZZLE, "vel": -x.basis.z.normalized() * JET_V, "on": in_spans(a["fire"], t)}, 120.0, 0.85)
	return a


## The hold pose for walking (both hands on the lance) as a gait.
func lance_gait(run := false) -> Dictionary:
	var L := lance_local(CARRY)
	var carry := {"rifle": {"mode": "back"}, "hand_r": [-1, L * FK.LANCE_REAR], "hand_l": [-1, L * FK.LANCE_FRONT],
		"pole_r": Vector3(0.7, -0.6, 0.3), "pole_l": Vector3(-0.8, -0.5, 0.0)}
	return Body.gait(Body.RUN if run else Body.WALK, carry)


## The operator stops and fires: a firing pose from t0 to t1 aimed by target_fn, the jet on in the spans.
func flame_burst(a: Dictionary, t0: float, t1: float, target_fn: Callable, spans: Array, body_name := "ready") -> void:
	var at: Vector3 = a["pos"]
	var yaw: float = a["yaw"]
	a["windows"].append([t0, t1, target_fn, at, yaw])
	a["fire"].append_array(spans)
	var hands := func(t: float) -> Dictionary:
		var x := lance_world(a, t)
		return {"hand_r": x * FK.LANCE_REAR, "hand_l": x * FK.LANCE_FRONT}
	pose(a, t0, 0.45, hold(body_name, CARRY), hands)


## A man with the spare fuel bottle on his back and his rifle.
func assistant(seed_value: int, pos: Vector3, yaw: float) -> Dictionary:
	var a := troop(seed_value, "rifleman", pos, yaw)
	prop(can_mesh, [[0.0, 0.0, "bone", [a, B.CHEST, TANKS_XF]]])
	return a


## Chars a figure (soldier, red jacket or zombie) over d seconds from t0.
func char_fig(a: Dictionary, t0: float, d := 5.0) -> void:
	var s: Soldier = a["s"]
	var base: PackedColorArray = s.geo.col.duplicate()
	var last := [-1.0]
	ticks.append(func(t: float) -> void:
		if t < t0:
			return
		var u := clampf((t - t0) / d, 0.0, 1.0)
		if u - float(last[0]) < 0.07 and u < 1.0:
			return
		if float(last[0]) >= 1.0:
			return
		last[0] = u
		if s is Zombie:
			(s as Zombie).set_burnt(u)
			return
		var cols := base.duplicate()
		for i in cols.size():
			cols[i] = cols[i].lerp(Color(0.07, 0.06, 0.05), u * 0.88)
		s.geo.col = cols
		s.mesh_inst.mesh = s.geo.to_mesh(s.material()))


## Sets a figure alight from t0 (flames off its bones, black smoke, charring).
func alight(a: Dictionary, t0: float, dur := 8.0, size := 0.3) -> void:
	var bones: Array[int] = [B.CHEST, B.SPINE, B.HEAD, B.UARM_R, B.UARM_L, B.THIGH_R, B.THIGH_L, B.FARM_R, B.FARM_L, B.SHIN_R]
	fx.add_burner(func(_t: float) -> Array:
		var out: Array = []
		for bn in bones:
			out.append(bone_world(a, bn).origin)
		return out, t0, t0 + dur, 4.5, size, 0.5, 1.1)
	char_fig(a, t0 + 0.2)


## A clip after a short blend into its first key.
func to_clip(a: Dictionary, t: float, c: Dictionary, blend := 0.25) -> void:
	pose(a, t, blend, c["keys"][0][1])
	clip(a, t + blend, c)


## Drops every planned segment after t (so a figure can react to the fire).
func cut_after(a: Dictionary, t: float) -> void:
	var segs: Array = a["segs"]
	while segs.size() > 1 and float(segs.back()["t0"]) > t:
		segs.pop_back()
	var s: Soldier = a["s"]
	a["pos"] = s.position
	a["yaw"] = s.rotation.y


## Watch a figure: when the fire reaches it (a billow or the jet close to its body, or it stands in a burning
## patch), it catches light and reacts: "walk" (a zombie walks on burning, then falls), "fall", "flee:<x>"
## (runs along the trench to x, then falls), "back" (falls back dead).
func watch_fire(a: Dictionary, react: String, from_t := 0.0) -> void:
	watch.append({"a": a, "react": react, "lit": -1.0, "from": from_t})


func _catch(t: float) -> void:
	for w: Dictionary in watch:
		if float(w["lit"]) >= 0.0 or t < float(w["from"]):
			continue
		var a: Dictionary = w["a"]
		var c := bone_world(a, B.CHEST).origin
		var hit := false
		for f: Array in fx.fire:
			var k: int = f[0]
			if k == FlameFx.EMBER:
				continue
			if (f[1] as Vector3).distance_squared_to(c) < pow(0.45 + float(f[6]) * 0.5, 2.0) and float(f[7]) - float(f[3]) * 0.5 > 0.7:
				hit = true
				break
		if not hit:
			for pt: Dictionary in fx.patches:
				if float(pt["fuel"]) > 0.6:
					var q: Vector3 = pt["p"]
					var feet := c - Vector3(0, 1.2, 0)
					var near := Vector2(q.x - c.x, q.z - c.z).length() < float(pt["r"]) + 0.15 and absf(q.y - feet.y) < 0.6
					if near or q.distance_to(c) < float(pt["r"]) + 0.45:
						hit = true
						break
		if not hit:
			# Fire spreads from a burning figure to one pressed against it.
			for w2: Dictionary in watch:
				var lt: float = w2["lit"]
				if lt >= 0.0 and t - lt > 0.8 and t - lt < 7.0:
					if bone_world(w2["a"], B.CHEST).origin.distance_to(c) < 0.75:
						hit = true
						break
		if hit:
			w["lit"] = t
			_react(w, t)


func _react(w: Dictionary, t: float) -> void:
	var a: Dictionary = w["a"]
	var react: String = w["react"]
	alight(a, t, 9.0 if react == "walk" else 8.0)
	if react == "none":
		return
	cut_after(a, t)
	var burning := Z.burning()
	if react == "walk":
		var g: Dictionary = zgait(a)
		var s: Soldier = a["s"]
		var fwd := Vector3(-sin(s.rotation.y), 0, -cos(s.rotation.y))
		var segs: Array = a["segs"]
		var cur: Dictionary = segs.back()
		if cur["type"] == "move" and t < float(cur["t0"]) + float(cur["d"]):
			var to := s.position + fwd * float(g["speed"]) * randf_range(1.5, 3.0)
			to.y = 0.0
			to.z = minf(to.z, float(a.get("zmax", INF)))
			a["pos"] = Vector3(s.position.x, 0.0, s.position.z)
			var ta := move(a, t, to, g, s.rotation.y)
			to_clip(a, ta, burning)
		else:
			to_clip(a, t + 0.1, burning)
	elif react.begins_with("flee:"):
		var x := float(react.substr(5))
		var s: Soldier = a["s"]
		var to := Vector3(x, s.position.y, s.position.z)
		pose(a, t, 0.2, M.poses()["ready"])
		var ta := move(a, t + 0.2, to, Body.gait(Body.RUN, M.carry("shoulder")))
		to_clip(a, ta, burning)
	elif react == "back":
		var src: Dictionary = mlib["death_back"]
		to_clip(a, t + 0.05, src, 0.15)
	else:
		to_clip(a, t + 0.05, burning, 0.2)


# ---------------------------------------------------------------- the red jackets

func coat(seed_value: int, pos: Vector3, yaw: float) -> Dictionary:
	var s := Redcoat.new().setup(seed_value, 0, "musketeer")
	stage.add_child(s)
	var a := {"s": s, "segs": [], "pos": pos, "yaw": yaw}
	actors.append(a)
	pose(a, 0.0, 0.0, M.poses()["aim"], null, null)
	return a


## Musket shots: a flash in the pan and at the muzzle, a big puff of white powder smoke.
func musket(a: Dictionary, times: Array) -> void:
	var fl := func(t: float) -> Variant:
		for ts: float in times:
			if t >= ts and t < ts + 0.07:
				return Transform3D(Basis(), bone_world(a, B.RIFLE) * RB.MUZZLE)
		return null
	glow(0.09, fl, 1.6)
	for ts: float in times:
		later(ts, func(tt: float) -> void:
			var x := bone_world(a, B.RIFLE)
			var fwd := -x.basis.z.normalized()
			for k in 3:
				puff(x * RB.MUZZLE + fwd * 0.2 * k, fwd * (1.4 - 0.3 * k) + Vector3(0, 0.2, 0), 0.12, Color(0.86, 0.86, 0.84), 2.4,
					3.0, 0.65, tt))


# ---------------------------------------------------------------- the flame tank

## The light tank with its gun swapped for a flame projector and fuel drums on the deck. Drives from p0 to p1
## (dist_fn(t) metres along), turret on target_fn(t) (null = straight ahead), the jet on in spans.
func flame_tank(p0: Vector3, p1: Vector3, dist_fn: Callable, target_fn: Callable, spans: Array) -> Tank:
	var tk := Tank.new().setup("light_gun", 0, false)
	stage.add_child(tk)
	tk.barrel.visible = false
	FK.tank_projector().make(tk.gun, "Projector", TrainParts.material())
	FK.tank_fuel().make(tk.body, "Fuel", TrainParts.material())
	var dir := (p1 - p0).normalized()
	var yaw := atan2(-dir.x, -dir.z)
	var last := [-1.0, 0.0, 0.0]  # dist, turret yaw, elev
	ticks.append(func(t: float) -> void:
		var d: float = dist_fn.call(t)
		var moving := d - float(last[0]) > 0.001 and float(last[0]) >= 0.0
		tk.position = p0 + dir * d
		tk.rotation.y = yaw
		tk.drive(d, d)
		tk.ride(gh, 0.0 if float(last[0]) < 0.0 else 1.0 / FPS, 0.012 if moving else 0.004)
		last[0] = d
		var tgt: Variant = target_fn.call(t)
		var want := Vector2(0.0, 0.0)
		if tgt != null:
			var tx := tk.turret.global_transform
			var g := tk.gun.position
			var tl := tx.affine_inverse() * (tgt as Vector3) - g
			var dx := Vector2(tl.x, tl.z).length() - 1.2
			want = Vector2(atan2(-tl.x, -tl.z) + float(last[1]), pitch_for(dx, tl.y + 0.1, TANK_V))
		# The turret turns at about 40 degrees a second, the gun at 20.
		last[1] = move_toward(float(last[1]), want.x, deg_to_rad(40.0) / FPS)
		last[2] = move_toward(float(last[2]), rad_to_deg(want.y), 20.0 / FPS)
		tk.set_turret(float(last[1]))
		tk.set_elev(float(last[2]))
		if frame % (4 if moving else 9) == 0:
			smoke_p.add("smoke", tk.global_transform * (Tank.T.L_EXHAUST + Vector3(0, 0.15, 0)), Vector3(0, 1.0, 0.3), 0.3 if moving else 0.18))
	fx.add_jet(func(t: float) -> Variant:
		var x := tk.gun.global_transform
		return {"from": x * FK.TANK_NOZZLE, "vel": -x.basis.z.normalized() * TANK_V, "on": in_spans(spans, t)}, 170.0, 1.25)
	return tk


# ---------------------------------------------------------------- test

func _scene_test() -> float:
	mood(true)
	block(Vector3(0, 0.6, -10), Vector3(3, 0.6, 0.5), SAND)
	fx.solids.append(AABB(Vector3(-3, 0, -10.5), Vector3(6, 1.2, 1.0)))
	var op := operator(5, Vector3(0, 0, 0), 0.0)
	pose(op, 0.0, 0.0, hold("ready", CARRY), null, null)
	flame_burst(op, 0.5, 5.0, func(t: float) -> Vector3: return Vector3(-3.0 + 1.4 * (t - 0.5), 0, -9.0), [[1.0, 4.5]])
	var z := zed(30, "shambler", Vector3(2.0, 0, -6.0), PI)
	pose(z, 0.0, 0.0, Z.stand("shambler"))
	alight(z, 2.0)
	to_clip(z, 2.0, Z.burning())
	later(5.5, func(_t: float) -> void: fx.fireball(Vector3(-2, 0.8, -4), 1.0))
	_phases = [[0.0, "Test: jet, ground fire, burning man, fireball"]]
	_camera = func(t: float) -> void:
		cam.fov = 50.0
		cam.transform = Transform3D(Basis(), Vector3(7.5 - t * 0.2, 3.2, 3.0)).looking_at(Vector3(-0.5, 0.8, -5.5), Vector3.UP)
	return 14.0


func _scene_kit() -> float:
	mood(false)
	var op := operator(5, Vector3(0, 0, 0), 0.5)
	pose(op, 0.0, 0.0, hold("ready", CARRY), null, null)
	var op2 := operator(7, Vector3(-1.6, 0, 0.8), 0.5)
	op2["windows"].append([0.0, 9.0, func(_t: float) -> Vector3: return Vector3(-8, 0, -9), Vector3(-1.6, 0, 0.8), 0.5])
	var hands := func(t: float) -> Dictionary:
		var x := lance_world(op2, t)
		return {"hand_r": x * FK.LANCE_REAR, "hand_l": x * FK.LANCE_FRONT}
	pose(op2, 0.0, 0.0, hold("ready", CARRY), hands, null)
	var asst := assistant(23, Vector3(1.4, 0, 0.4), 0.5)
	pose(asst, 0.0, 0.0, R.poses()["stand"], null, null)
	var w := operator(9, Vector3(-3.4, 0, 1.6), 0.5)
	move(w, 0.0, Vector3(-3.4, 0, -20), lance_gait())
	FK.heavy_stand().make(stage, "Stand", TrainParts.material(), Transform3D(Basis(), Vector3(3.5, 0, 0)))
	FK.heavy_gun().make(stage, "Gun", TrainParts.material(), Transform3D(Basis(Vector3.UP, 0.4), Vector3(3.5, FK.HEAVY_PIVOT_H, 0)))
	FK.heavy_tank().make(stage, "Tank", TrainParts.material(), Transform3D(Basis(), Vector3(5.4, 0, 1.2)))
	FK.heavy_pump().make(stage, "Pump", TrainParts.material(), Transform3D(Basis(), Vector3(4.6, 0, 2.0)))
	flame_tank(Vector3(-7, 0, -3), Vector3(-7, 0, -4), func(_t: float) -> float: return 0.0, func(_t: float) -> Variant: return null, [])
	var wg := FK.wagon()
	stage.add_child(wg)
	wg.global_transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(10, 0, -4))
	wg.aim(0.6, 0.1)
	_phases = [[0.0, "Kit"]]
	_camera = func(_t: float) -> void:
		cam.fov = 50.0
		cam.transform = Transform3D(Basis(), Vector3(1.0, 3.5, 9.0)).looking_at(Vector3(1.0, 0.8, -1.0), Vector3.UP)
	return 1.0


# ---------------------------------------------------------------- clearing a trench

func _scene_trench() -> float:
	mood(false)
	fx.wind = Vector3(1.0, 0, -0.9)
	var TOP := 1.6
	var ZF := -12.6   # the trench's front wall (our side)
	var ZB := -14.4   # its back wall
	var ZS := -13.2   # the fire step's edge
	var STEPH := 0.8  # the fire step's height
	levels = [[Rect2(-110, -130, 220, 220), TOP], [Rect2(-60, ZB, 120, ZF - ZB), 0.0], [Rect2(-60, ZS, 120, ZF - ZS), STEPH]]
	var span_x := 45.0
	block(Vector3(0, TOP * 0.5, (ZF + 90.0) * 0.5), Vector3(110.0, TOP * 0.5, (90.0 - ZF) * 0.5), EARTH)
	block(Vector3(0, TOP * 0.5, (ZB - 130.0) * 0.5), Vector3(110.0, TOP * 0.5, (ZB + 130.0) * 0.5), EARTH)
	block(Vector3(0, STEPH * 0.5, (ZS + ZF) * 0.5), Vector3(span_x, STEPH * 0.5, (ZF - ZS) * 0.5), EARTH.darkened(0.08))
	block(Vector3(0, 0.012, (ZB + ZS) * 0.5), Vector3(span_x, 0.012, (ZS - ZB) * 0.5), EARTH.darkened(0.25))
	# Revetment planks on both walls, duckboards on the floor.
	for k in 70:
		var x := -span_x * 0.5 + 0.65 * k
		block(Vector3(x, STEPH + (TOP - STEPH) * 0.5, ZF - 0.03), Vector3(0.3, (TOP - STEPH) * 0.5, 0.03), PLANK.darkened(0.06 * (k % 3)))
		block(Vector3(x, TOP * 0.5, ZB + 0.03), Vector3(0.3, TOP * 0.5, 0.03), PLANK.darkened(0.05 * ((k + 1) % 3)))
		if k % 2 == 0:
			block(Vector3(x, 0.04, (ZB + ZS) * 0.5), Vector3(0.12, 0.02, 0.38), PLANK.lightened(0.05))
	# Sandbags along the front lip, posts and a tangle of wire out in front.
	for k in 165:
		var x := -span_x * 0.5 + 0.42 * floorf(k / 3.0) + (0.2 if k % 2 == 0 else 0.0)
		var row := k % 3
		block(Vector3(x, TOP + 0.08 + 0.15 * row, ZF + 0.22 - 0.06 * row), Vector3(0.21, 0.08, 0.16), SAND.darkened(0.04 * (int(k / 3.0) % 3)),
			Basis(Vector3.UP, 0.05 * ((k * 7) % 5 - 2)))
	fx.solids.append(AABB(Vector3(-span_x, TOP, ZF), Vector3(span_x * 2.0, 0.42, 0.4)))
	fx.solids.append(AABB(Vector3(-span_x, 0.0, ZB - 20.0), Vector3(span_x * 2.0, TOP, 20.0)))
	fx.solids.append(AABB(Vector3(-span_x, STEPH, ZF), Vector3(span_x * 2.0, TOP - STEPH, 3.0)))
	for k in 12:
		var x := -12.0 + 2.2 * k
		block(Vector3(x, TOP + 0.5, ZF + 4.5), Vector3(0.05, 0.5, 0.05), PLANK.darkened(0.2))
	for k in 11:
		var x := -11.0 + 2.2 * k
		wire(func(_t: float) -> PackedVector3Array:
			var pts := PackedVector3Array()
			for j in 9:
				var a := float(j) / 8.0 * TAU * 1.5
				pts.append(Vector3(x - 1.1 + 2.2 * float(j) / 8.0, TOP + 0.45 + 0.35 * sin(a), ZF + 4.5 + 0.35 * cos(a)))
			return pts)
	# The defenders on the fire step.
	var xs: Array[float] = [-8.0, -6.5, -4.8, -3.0, -1.2, 2.0, 3.5, 4.8, 6.2, 7.5, 9.0]
	var reacts: Array[String] = ["fall", "flee:-14", "back", "flee:0.3", "fall", "fall", "back", "flee:11", "fall", "fall", "flee:15"]
	var shooter: Dictionary
	for i in xs.size():
		var a := coat(40 + i * 3, Vector3(xs[i], STEPH, ZS + 0.3), PI + randf_range(-0.12, 0.12))
		clip(a, 0.3 + randf_range(0.0, 0.15), mlib["volley_stand"])
		var t_shot := 0.3 + 3.06
		var times: Array = [t_shot + randf_range(0.0, 0.15)]
		if i % 3 == 1:
			times.append(randf_range(6.0, 8.0))
		if xs[i] == 7.5:
			shooter = a
			times.append(13.6)
		musket(a, times)
		watch_fire(a, reacts[i], 15.0 if xs[i] > 5.5 else 0.0)
	# The flame tank comes up on the left, the team on the right under its cover.
	var tank_p0 := Vector3(-5.0, 0, 13.0)
	var tank_p1 := Vector3(-5.0, 0, -4.5)
	var stop := tank_p0.distance_to(tank_p1)
	var tank_target := func(t: float) -> Variant:
		if t < 7.0:
			return null
		if t < 13.0:
			return Vector3(lerpf(-9.5, -1.0, ramp(t, 8.0, 4.6)), STEPH + 1.2, ZS + 0.2)
		if t < 23.0:
			return Vector3(lerpf(-1.0, 10.0, ramp(t, 15.8, 5.6)), STEPH + 1.2, ZS + 0.2)
		return null
	flame_tank(tank_p0, tank_p1, func(t: float) -> float: return minf(maxf(t, 0.0) * 2.3, stop),
		tank_target, [[8.1, 12.6], [16.2, 21.2]])
	var op := operator(21, Vector3(3.2, TOP, 9.0), 0.0)
	var asst := assistant(23, Vector3(4.6, TOP, 9.6), 0.0)
	pose(op, 0.0, 0.0, hold("stand", CARRY), null, null)
	pose(asst, 0.0, 0.0, R.poses()["stand"], null, null)
	var ta := move(op, 3.6, Vector3(3.2, TOP, -3.0), lance_gait(true))
	var tb := move(asst, 3.75, Vector3(4.7, TOP, -2.5), Body.gait(Body.RUN, R.carry("port")))
	var trench_mid := ZS + 0.2
	flame_burst(op, ta, 13.3, func(t: float) -> Vector3:
		if t < 11.0:
			return Vector3(lerpf(0.8, 3.6, ramp(t, ta + 0.6, 2.2)), STEPH + 1.2, trench_mid)
		return Vector3(lerpf(3.6, 5.4, ramp(t, 11.2, 1.6)), STEPH + 1.2, trench_mid), [[ta + 0.6, ta + 2.7], [11.3, 12.9]])
	pose(asst, tb, 0.5, R.poses()["kneel"])
	var kfire: Dictionary = R.library()["fire_kneel"] if R.library().has("fire_kneel") else R.library()["fire_stand"]
	for ts: float in [9.6, 11.6]:
		clip(asst, ts, kfire)
	shots(asst, Rig.MUZZLE, [9.6, 11.6], 0.06, false)
	# The shot that hits the operator's tanks: they burst.
	var t_hit := 13.7
	hit_fx(op, B.CHEST, t_hit, true)
	op["dead"] = t_hit + 0.15
	later(t_hit + 0.15, func(_t: float) -> void:
		var s: Soldier = op["s"]
		fx.fireball(s.global_transform * s.skel.get_bone_global_pose(B.CHEST) * TANKS_XF * Vector3(0, -0.1, 0.12), 0.9))
	alight(op, t_hit + 0.15, 9.0, 0.34)
	to_clip(op, t_hit + 0.2, Z.burning(), 0.15)
	op["tanks_prop"]["keys"].append([t_hit + 0.15, 0.0, "world", HIDE])
	op["lance_prop"]["keys"].append([t_hit + 0.4, 0.0, "world", func(_t: float) -> Transform3D:
		var s: Soldier = op["s"]
		return Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.FORWARD, 1.5), s.position + Vector3(0.5, 0.03, 0.4))])
	# The assistant is thrown flat, crawls clear, and kneels to fire again.
	pose(asst, t_hit + 0.2, 0.35, T.prone_free())
	shift(asst, t_hit + 1.6, 1.5, T.prone_free(), Vector3(5.9, TOP, -1.2), 0.0)
	pose(asst, 18.4, 0.6, R.poses()["kneel"])
	for ts: float in [19.6, 21.6]:
		clip(asst, ts, kfire)
	shots(asst, Rig.MUZZLE, [19.6, 21.6], 0.06, false)
	_phases = [[0.0, "Clearing a trench: the flame tank and a man-pack team go in"],
		[8.0, "The tank burns out the left of the trench, the team the right"],
		[t_hit - 0.4, "A red jacket hits the operator: his tanks burst"],
		[16.0, "The tank turns and finishes the job"], [23.0, "Burnt out"]]
	_camera = func(t: float) -> void:
		cam.fov = 50.0
		if t < 7.6:
			cam.transform = Transform3D(Basis(), Vector3(12.0, 6.5, 16.0 - t * 0.4)).looking_at(Vector3(-1.0, 1.4, -7.0), Vector3.UP)
		elif t < 11.2:
			cam.transform = Transform3D(Basis(), Vector3(-15.5, 3.2, -1.5)).looking_at(Vector3(-4.0, 1.0, -10.5), Vector3.UP)
		elif t < 16.2:
			cam.fov = 46.0
			cam.transform = Transform3D(Basis(), Vector3(10.0, 2.9, 2.0)).looking_at(Vector3(3.6, 1.7, -6.5), Vector3.UP)
		elif t < 22.6:
			cam.transform = Transform3D(Basis(), Vector3(5.0, 4.6, -26.0)).looking_at(Vector3(1.0, 1.0, -9.0), Vector3.UP)
		else:
			var u := (t - 22.6) / 9.0
			cam.fov = 48.0
			cam.transform = Transform3D(Basis(), Vector3(lerpf(-9.0, -2.0, u), lerpf(6.0, 8.5, u), lerpf(3.5, 5.0, u))).looking_at(Vector3(0.5, 0.4, -13.0), Vector3.UP)
	return 31.6


# ---------------------------------------------------------------- against zombies at a wall

func _scene_wall() -> float:
	mood(true)
	fx.wind = Vector3(-0.8, 0, -1.0)
	var H := 2.4
	var STEP := 1.85
	var GX0 := 9.6   # the rail gate's opening
	var GX1 := 13.4
	var RX := 11.5   # the line runs out through it
	block(Vector3((-16.0 + GX0) * 0.5, H * 0.5, 0), Vector3((GX0 + 16.0) * 0.5, H * 0.5, 0.25), STONE)
	block(Vector3((GX1 + 24.0) * 0.5, H * 0.5, 0), Vector3((24.0 - GX1) * 0.5, H * 0.5, 0.25), STONE)
	for x: float in [GX0 - 0.3, GX1 + 0.3]:
		block(Vector3(x, 1.6, 0), Vector3(0.38, 1.6, 0.38), STONE.darkened(0.12))
	for k in 60:
		var x := -15.7 + 0.65 * k
		if x > GX0 - 0.6 and x < GX1 + 0.6:
			continue
		block(Vector3(x, H + 0.05, 0), Vector3(0.3, 0.05, 0.28), STONE.darkened(0.08))
	# The fire step behind the wall: earth faced with planks, a ladder at the end.
	block(Vector3(1.5, STEP * 0.5, 1.65), Vector3(7.5, STEP * 0.5, 1.4), EARTH)
	for k in 23:
		block(Vector3(-5.8 + 0.65 * k, STEP * 0.5, 3.07), Vector3(0.3, STEP * 0.5, 0.03), PLANK.darkened(0.05 * (k % 3)))
		block(Vector3(-5.8 + 0.65 * k, STEP + 0.02, 1.65), Vector3(0.3, 0.02, 1.38), PLANK.lightened(0.03 * (k % 2)))
	levels = [[Rect2(-6.0, 0.25, 15.0, 2.8), STEP], [Rect2(-16.0, -0.25, 40.0, 0.5), H]]
	fx.solids.append(AABB(Vector3(-16.0, 0, -0.25), Vector3(GX0 + 16.0, H, 0.5)))
	fx.solids.append(AABB(Vector3(GX1, 0, -0.25), Vector3(24.0 - GX1, H, 0.5)))
	# The line: track out through the gate, the engine pushing the flame wagon.
	var path := TrackPath.line(Vector3(RX, 0, 60.0), Vector3(RX, 0, -60.0))
	stage.add_child(TrainParts.track(path, 0.0, 120.0))
	var wagon := FK.wagon()
	var eng := TrainParts.make("engine")
	var tender := TrainParts.make("tender")
	var train: Array = []
	var off := 0.0
	var list: Array[TrainCar] = [wagon, eng, tender]
	for i in list.size():
		if i > 0:
			off += list[i - 1].rear_z - list[i].front_z + 0.02
		stage.add_child(list[i])
		train.append([list[i], off])
	var d_fn := func(t: float) -> float:
		var d0 := 46.0
		if t < 14.0:
			return d0
		var u := t - 14.0
		var v := 2.6
		var acc := 0.7
		var ta := v / acc
		var d := 0.5 * acc * u * u if u < ta else 0.5 * acc * ta * ta + v * (u - ta)
		return d0 + minf(d, 62.0)
	var last := [-1.0]
	ticks.append(func(t: float) -> void:
		var d: float = d_fn.call(t)
		var dd: float = 0.0 if float(last[0]) < 0.0 else d - float(last[0])
		last[0] = d
		for e: Array in train:
			var cc: TrainCar = e[0]
			cc.global_transform = path.car_frame(d - float(e[1]), cc)
			cc.roll(dd)
		var top := eng.global_transform * (eng.marks["chimney"] as Vector3)
		if dd > 0.02 and frame % 5 == 0:
			smoke_p.add("smoke", top, Vector3(0, 3.0, 0.4), 0.7)
		elif frame % 16 == 0:
			smoke_p.add("smoke", top, Vector3(0, 1.3, 0.2), 0.4))
	var wag_target := func(t: float) -> Variant:
		if t < 20.5:
			return null
		if t < 26.0:
			return Vector3(lerpf(9.0, 6.0, ramp(t, 21.5, 4.0)), 0.2, lerpf(-2.5, -5.0, ramp(t, 21.5, 4.0)))
		var wz := wagon.global_position.z
		return Vector3(lerpf(5.0, 1.0, ramp(t, 26.0, 7.0)), 0.2, wz + lerpf(1.0, 4.0, ramp(t, 26.0, 7.0)))
	var wl := [0.0, 0.0]
	ticks.append(func(t: float) -> void:
		var tgt: Variant = wag_target.call(t)
		var want := Vector2.ZERO
		if tgt != null:
			var mx := wagon.gun_mount.global_transform
			var tl := mx.affine_inverse() * (tgt as Vector3)
			var cp := wagon.gun_cradle.position
			var dx := Vector2(tl.x, tl.z).length() - 1.5
			want = Vector2(atan2(-tl.x, -tl.z), pitch_for(dx, tl.y - cp.y, TANK_V))
		wl[0] = move_toward(float(wl[0]), want.x, deg_to_rad(35.0) / FPS)
		wl[1] = move_toward(float(wl[1]), want.y, deg_to_rad(18.0) / FPS)
		wagon.aim(float(wl[0]), float(wl[1])))
	fx.add_jet(func(t: float) -> Variant:
		var x := wagon.gun_barrel.global_transform
		return {"from": x * FK.WAGON_NOZZLE, "vel": -x.basis.z.normalized() * TANK_V, "on": in_spans([[22.2, 25.4], [26.2, 33.2]], t)},
		190.0, 1.35)
	# The heavy trench flamer on the step: tank, pump, stand and projector, a crew of four.
	var hx := 0.2
	var hz := 0.85
	var piv := Vector3(hx, STEP + FK.HEAVY_PIVOT_H, hz)
	var parts := Node3D.new()
	stage.add_child(parts)
	FK.heavy_stand().make(parts, "Stand", TrainParts.material(), Transform3D(Basis(), Vector3(hx, STEP, hz)))
	FK.heavy_tank().make(parts, "Tank", TrainParts.material(), Transform3D(Basis(), Vector3(hx + 1.9, STEP, 1.9)))
	FK.heavy_pump().make(parts, "Pump", TrainParts.material(), Transform3D(Basis(), Vector3(hx + 0.9, STEP, 2.3)))
	var gun := Node3D.new()
	stage.add_child(gun)
	FK.heavy_gun().make(gun, "Gun", TrainParts.material())
	var handle := Node3D.new()
	stage.add_child(handle)
	handle.position = Vector3(hx + 0.9, STEP + 0.62, 2.3)
	FK.pump_handle().make(handle, "Handle", TrainParts.material())
	var h_target := func(t: float) -> Vector3:
		if t < 12.5:
			return Vector3(lerpf(-6.0, 6.5, ramp(t, 6.4, 5.0)), 0.2, -9.0 - 1.5 * sin(t * 1.3))
		if t < 20.0:
			return Vector3(lerpf(6.5, -6.0, ramp(t, 13.4, 5.2)), 0.2, -12.5 + 1.0 * sin(t * 1.1))
		return Vector3(lerpf(-5.0, 5.0, ramp(t, 27.0, 4.5)), 0.2, -16.0)
	var h_spans := [[6.4, 11.6], [13.4, 18.8], [27.0, 31.6]]
	var hl := [0.0, -0.1]
	var h_xf := func() -> Transform3D:
		return Transform3D(Basis(Vector3.UP, float(hl[0])) * Basis(Vector3.RIGHT, float(hl[1])), piv)
	ticks.append(func(t: float) -> void:
		var want := aim_in(Transform3D(Basis(), piv), Vector3(0, 0, -1.2), h_target.call(t), HEAVY_V)
		var aiming := in_spans(h_spans, t + 0.6) or in_spans(h_spans, t)
		if not aiming:
			want = Vector2(-0.05, float(hl[0]))
		hl[0] = move_toward(float(hl[0]), clampf(want.y, -0.9, 0.9), deg_to_rad(30.0) / FPS)
		hl[1] = move_toward(float(hl[1]), clampf(want.x, -0.24, 0.5), deg_to_rad(20.0) / FPS)
		gun.global_transform = h_xf.call()
		handle.rotation.z = 0.35 * sin(t * 4.2) if t > 5.0 else 0.2)
	fx.add_jet(func(t: float) -> Variant:
		var x: Transform3D = h_xf.call()
		return {"from": x * FK.HEAVY_NOZZLE, "vel": -x.basis.z.normalized() * HEAVY_V, "on": in_spans(h_spans, t)}, 170.0, 1.2)
	# Crew: the gunner on the spade handles, the pump man, the valve man at the tank, the loader with a rifle.
	var gunner := troop(31, "gunner", Vector3(hx, STEP, hz + 1.05), 0.0)
	var gh_hands := func(_t: float) -> Dictionary:
		var x: Transform3D = h_xf.call()
		return {"hand_r": x * Vector3(0.3, -0.06, 0.77), "hand_l": x * Vector3(-0.3, -0.06, 0.77)}
	pose(gunner, 0.0, 0.0, Rig.over(Body.body("ready"), {"rifle": {"mode": "back"}, "pole_r": Vector3(0.8, -0.5, 0.2),
		"pole_l": Vector3(-0.8, -0.5, 0.2)}), gh_hands, null)
	var pumper := troop(33, "loader", Vector3(hx + 0.9, STEP, 2.95), 0.0)
	var pump_hands := func(_t: float) -> Dictionary:
		var p := handle.global_transform * Vector3(0.55, 0, 0)
		return {"hand_r": p + Vector3(0, 0.02, 0.05), "hand_l": p + Vector3(0, 0.02, -0.05)}
	pose(pumper, 0.0, 0.0, Rig.over(T.kneel_work(18.0, 30.0), {"rifle": {"mode": "back"}}), pump_hands, null, "smooth", null, -0.6)
	var valve := troop(35, "loader", Vector3(hx + 2.1, STEP, 2.75), 0.0)
	pose(valve, 0.0, 0.0, Rig.over(T.kneel_work(10.0, 0.0), {"rifle": {"mode": "back"}}), {"hand_r": Vector3(hx + 1.95, STEP + 0.8, 1.95),
		"hand_l": Vector3(hx + 1.75, STEP + 0.8, 2.0)}, null)
	var loader := rifleman(37, Vector3(hx + 2.6, STEP, 1.0), -0.15, [9.0, 14.5, 21.0])
	loader["role"] = "rifleman"
	# Two man-pack flamers on the step: one at the west end (the climbers come over there), one east.
	var fw := operator(41, Vector3(-4.6, STEP, 0.55), 0.25)
	pose(fw, 0.0, 0.0, hold("ready", CARRY), null, null)
	flame_burst(fw, 7.5, 10.9, func(t: float) -> Vector3:
		return Vector3(lerpf(-7.0, -2.5, ramp(t, 8.0, 2.8)), 0.2, -4.6), [[8.0, 10.8]])
	fw["yaw"] = 1.15
	flame_burst(fw, 11.3, 15.0, func(t: float) -> Vector3:
		return Vector3(lerpf(-8.4, -9.8, ramp(t, 12.1, 2.2)), H + 0.5, -0.3), [[12.1, 14.6]])
	var fe := operator(43, Vector3(5.2, STEP, 0.55), -0.1)
	pose(fe, 0.0, 0.0, hold("ready", CARRY), null, null)
	flame_burst(fe, 8.5, 21.0, func(t: float) -> Vector3:
		if t < 13.0:
			return Vector3(lerpf(3.0, 8.0, ramp(t, 9.0, 3.0)), 0.2, -4.6)
		return Vector3(lerpf(7.0, 9.0, ramp(t, 17.8, 2.4)), 0.2, lerpf(-6.0, -4.4, ramp(t, 17.8, 2.4))),
		[[9.0, 11.8], [14.0, 15.6], [17.8, 20.4]])
	var r2 := rifleman(45, Vector3(7.8, STEP, 1.0), -0.2, [7.0, 11.0, 16.0])
	r2["role"] = "rifleman"
	# The horde. Climbers come up a heap at the west end, the rest come on to the wall foot and claw at it;
	# some make for the rail gate.
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var heap_x: Array[float] = [-10.2, -9.4, -8.6]
	for i in 3:
		var hxp: float = heap_x[i]
		var a := zed(seed_where("shambler", "bare", i % 2 == 0, 30 + 7 * i), "shambler", Vector3(hxp, 0, -5.0 - 0.6 * float(i)), PI)
		var t_at := move(a, 0.0, Vector3(hxp, 0, -0.87), zgait(a), PI)
		pose(a, t_at, 0.6, Z.heap())
		watch_fire(a, "fall")
	var climbers := [[61, "runner", -9.4, 10.6], [77, "runner", -8.6, 12.0]]
	for c: Array in climbers:
		var cx: float = c[2]
		var tc: float = c[3]
		var g := Z.gait_of(String(c[1]))
		var v0: float = g["speed"]
		var a := zed(int(c[0]), String(c[1]), Vector3(cx, 0, -2.2 - v0 * (tc - 0.2)), PI)
		move(a, 0.2, Vector3(cx, 0, -2.2), g, PI)
		var top := func(_t: float) -> Dictionary:
			return {"hand_r": Vector3(cx + 0.22, H + 0.02, -0.18), "hand_l": Vector3(cx - 0.22, H + 0.02, -0.18)}
		shift(a, tc, 0.45, Z.stand(c[1]), Vector3(cx, 0.78, -1.15), 0.45, null, "smooth", PI)
		shift(a, tc + 0.5, 0.5, Z.wall_climb(true), Vector3(cx, 0.65, -0.62), 0.0, top, "smooth", PI)
		shift(a, tc + 1.05, 0.5, Z.wall_climb(false), Vector3(cx, 0.95, -0.55), 0.0, top, "smooth", PI)
		shift(a, tc + 1.6, 0.6, Z.over_top(), Vector3(cx, 1.55, -0.05), 0.0, null, "smooth", PI)
		shift(a, tc + 2.4, 0.55, Z.leap_pose("land"), Vector3(cx, 0, 1.0), 0.4, null, "in", PI)
		alight(a, tc + 1.75)
		to_clip(a, tc + 3.0, Z.burning())
	for i in 30:
		var kind := "runner" if i % 5 == 1 else "shambler"
		var gate := i % 6 == 4
		var tx := rng.randf_range(-7.0, 8.8) if not gate else (GX0 - 0.1 if i % 12 == 4 else GX1 + 0.1)
		var start := Vector3(tx + rng.randf_range(-4.0, 4.0), 0, -12.0 - float(i) * 0.9 - rng.randf_range(0.0, 4.0))
		var a := zed(100 + i * 5, kind, start, PI)
		var g := zgait(a)
		var foot := Vector3(tx, 0, -0.87 if not gate else -1.2 - rng.randf_range(0.0, 1.5))
		var t0 := rng.randf_range(0.0, 2.0)
		var t_at := move(a, t0, foot, g, PI)
		var gx := tx
		var ph := rng.randf() * 3.0
		var claws := func(t: float) -> Dictionary:
			return {"hand_r": Vector3(gx + 0.2, 1.45 + 0.25 * sin(t * 3.1 + ph), -0.14), "hand_l": Vector3(gx - 0.2, 1.45 + 0.25 * sin(t * 3.1 + ph + PI), -0.14)}
		if not gate:
			pose(a, t_at, 0.5, Z.claw_at(), claws)
			a["zmax"] = -0.9
		else:
			pose(a, t_at, 0.5, Z.stand(kind))
		watch_fire(a, "walk")
	var br := zed(90, "brute", Vector3(RX - 1.5, 0, -30.0), PI)
	move(br, 3.0, Vector3(RX - 2.2, 0, -2.0), zgait(br), PI)
	watch_fire(br, "walk")
	later(36.8, func(_t: float) -> void:
		var n := 0
		for w: Dictionary in watch:
			if float(w["lit"]) >= 0.0:
				n += 1
		print("wall: %d of %d caught fire" % [n, watch.size()]))
	_phases = [[0.0, "Against zombies at a wall: the horde comes on at dusk"],
		[6.4, "The heavy trench flamer opens up, the man-packs burn the wall foot"],
		[11.5, "Climbers at the west end: burnt as they come over"],
		[14.0, "The flame wagon is pushed out through the rail gate"], [27.0, "The field burns"]]
	_camera = func(t: float) -> void:
		cam.fov = 50.0
		if t < 6.2:
			cam.transform = Transform3D(Basis(), Vector3(-3.0 + t * 0.3, 7.5, 9.5)).looking_at(Vector3(0.0, 1.0, -10.0), Vector3.UP)
		elif t < 11.4:
			cam.transform = Transform3D(Basis(), Vector3(-17.0 + (t - 6.2) * 0.4, 5.0, -4.0)).looking_at(Vector3(1.0, 1.4, -5.5), Vector3.UP)
		elif t < 15.5:
			cam.fov = 44.0
			cam.transform = Transform3D(Basis(), Vector3(-6.5, 4.4, 6.5)).looking_at(Vector3(-8.6, 2.2, -1.0), Vector3.UP)
		elif t < 21.0:
			cam.transform = Transform3D(Basis(), Vector3(RX + 9.0, 3.6, 12.0 - (t - 15.5) * 1.2)).looking_at(Vector3(RX, 1.8, 2.0 - (t - 15.5) * 1.6), Vector3.UP)
		elif t < 28.0:
			cam.transform = Transform3D(Basis(), Vector3(RX + 10.0, 4.5, -18.0)).looking_at(Vector3(RX - 2.0, 1.4, -4.0 - (t - 21.0) * 0.8), Vector3.UP)
		else:
			var u := (t - 28.0) / 9.0
			cam.transform = Transform3D(Basis(), Vector3(lerpf(-2.0, 4.0, u), lerpf(9.0, 12.0, u), lerpf(10.0, 12.0, u))).looking_at(Vector3(2.0, 0.5, -9.0), Vector3.UP)
	return 37.0
