extends "res://tools/lorry_clips.gd"
## The light field gun and its crew of six, recorded as video frames (Question Chat, 2026-11-09).
##   Godot --path iron_front --resolution 1280x720 -s res://tools/gun_clips.gd -- [scene ...]
## Scenes: look, unhitch, fire, aim, push, hitch, portee, wreck. Frames go to
## results/units/anim_frames/gun_<scene>/, ffmpeg makes results/units/anim/gun_<scene>.mp4.
## The lorry (towing, carrying), the timelines and the effects come from the lorry tool.

const GB := preload("res://scripts/vehicles/field_gun_builder.gd")
const GC := preload("res://scripts/units/anim/clips_gun.gd")
const GUN_SCENES: Array[String] = ["look", "unhitch", "fire", "aim", "push", "hitch", "portee", "wreck"]
const BOX_AT := Vector3(1.25, 0, 1.75)  # ammunition box beside the trail (gun frame)

var guns: Array = []  # {node, mode, ...}
var flashes: Array = []  # {t, gun}


func _run() -> void:
	prefix = "gun_"
	_setup_world()
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	var args := OS.get_cmdline_user_args()
	for sc in (args if not args.is_empty() else GUN_SCENES):
		await _record(sc)
	print("GUN CLIPS OK")
	quit()


func _reset() -> void:
	super._reset()
	guns.clear()
	flashes.clear()


# ---------------------------------------------------------------- the gun

## A gun on the stage. Every fn is Callable(t) or null (null = keep):
##   pos / yaw (in the parent's frame), lift (rad), elev (deg), recoil (m), block (0..1)
func fgun(at: Vector3, yaw: float, lod := 0, wreck := false) -> Dictionary:
	var n := FieldGun.new().setup(lod, wreck)
	stage.add_child(n)
	n.position = at
	n.rotation.y = yaw
	var d := {"node": n, "mode": "free", "pos": null, "yaw": null, "lift": null, "elev": null, "recoil": null, "block": null,
		"hubs": []}
	guns.append(d)
	return d


## The gun hooked behind lorry l: its eye on the tow hook, trailing like a trailer.
func tow(d: Dictionary, l: Dictionary) -> void:
	d["mode"] = "tow"
	d["lorry"] = l
	var n: FieldGun = d["node"]
	var lb: Node3D = (l["node"] as Lorry).body
	var h := lb.global_transform * LB.HOOK
	var lift := FieldGun.lift_for(h.y)
	var eye := FieldGun.at_lift(GB.LUNETTE, lift)
	var dir := ((l["node"] as Node3D).global_transform.basis * Vector3.BACK).normalized()
	n.global_position = Vector3(h.x, 0, h.z) + dir * eye.z
	n.rotation.y = atan2(-dir.x, -dir.z)
	n.set_lift(lift)


func untow(d: Dictionary) -> void:
	d["mode"] = "free"


func _update_lorries(t: float) -> void:
	super._update_lorries(t)
	for d: Dictionary in guns:
		_update_gun(d, t)


func _update_gun(d: Dictionary, t: float) -> void:
	var n: FieldGun = d["node"]
	if d["mode"] == "tow":
		var lb: Node3D = ((d["lorry"] as Dictionary)["node"] as Lorry).body
		var h := lb.global_transform * LB.HOOK
		var lift := FieldGun.lift_for(h.y)
		var eye := FieldGun.at_lift(GB.LUNETTE, lift)
		var p := n.global_position
		var dir := Vector3(h.x - p.x, 0, h.z - p.z).normalized()
		n.global_position = Vector3(h.x, 0, h.z) - dir * eye.z
		n.rotation.y = atan2(dir.x, dir.z)
		n.set_lift(lift)
	else:
		if d["pos"] != null:
			n.position = (d["pos"] as Callable).call(t)
		if d["yaw"] != null:
			n.rotation.y = (d["yaw"] as Callable).call(t)
		if d["lift"] != null:
			n.set_lift((d["lift"] as Callable).call(t))
	if d.has("extra"):
		(d["extra"] as Callable).call(t)
	if d["elev"] != null:
		n.set_elev((d["elev"] as Callable).call(t))
	if d["recoil"] != null:
		n.set_recoil((d["recoil"] as Callable).call(t))
	if d["block"] != null:
		n.set_block((d["block"] as Callable).call(t))
	# Wheels roll by how far each hub moved along the gun's facing.
	var fwd := -n.global_transform.basis.z.normalized()
	var hubs: Array = []
	for s: float in [1.0, -1.0]:
		hubs.append(n.global_transform * Vector3(GB.TRACK * s, GB.WHEEL_R, 0))
	if not (d["hubs"] as Array).is_empty() and last_frame >= 0:
		var dr: float = ((hubs[0] as Vector3) - (d["hubs"][0] as Vector3)).dot(fwd)
		var dl: float = ((hubs[1] as Vector3) - (d["hubs"][1] as Vector3)).dot(fwd)
		n.roll(dr, dl)
	d["hubs"] = hubs


## Recoil curve for a shot at t0: back fast, held, then run out on the buffer.
static func recoil_at(t: float, shots: Array) -> float:
	var r := 0.0
	for t0: float in shots:
		var u := t - t0
		if u < 0.0 or u > 1.4:
			continue
		if u < 0.06:
			r = maxf(r, GB.RECOIL * u / 0.06)
		elif u < 0.2:
			r = maxf(r, GB.RECOIL)
		else:
			r = maxf(r, GB.RECOIL * (1.0 - Anim.ease_of((u - 0.2) / 1.2, "smooth")))
	return r


## The carriage hop at a shot (lift in radians: the wheels jump, the spade digs).
static func hop_at(t: float, shots: Array) -> float:
	var a := 0.0
	for t0: float in shots:
		var u := t - t0
		if u >= 0.0 and u < 0.5:
			a += 0.035 * sin(PI * u / 0.5) * (1.0 - u / 0.5)
	return a


## A shot: flash, muzzle smoke, dust thrown up in front, the light.
func shot(d: Dictionary, t0: float) -> void:
	flashes.append({"t": t0, "gun": d, "done": false})


func _effects(t: float) -> void:
	for f: Dictionary in flashes:
		var u: float = t - float(f["t"])
		if u >= 0.0 and not f["done"]:
			f["done"] = true
			var n: FieldGun = (f["gun"] as Dictionary)["node"]
			var mx := n.muzzle_xf()
			var fwd := -mx.basis.z.normalized()
			var rng := RandomNumberGenerator.new()
			rng.seed = int(float(f["t"]) * 100.0)
			puff(mx.origin + fwd * 0.4, fwd * 3.0, 0.45, Color(1.0, 0.8, 0.45), 0.12, 6.0, 0.95, t)
			for k in 10:
				var sd := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 0.8), rng.randf_range(-1, 1)) * 0.8
				puff(mx.origin + fwd * rng.randf_range(0.2, 1.4), fwd * rng.randf_range(1.5, 4.0) + sd, 0.25,
					Color(0.82, 0.8, 0.76), 2.6, 1.6, 0.6, t)
			for k in 8:
				var g := n.global_transform * Vector3(rng.randf_range(-1.2, 1.2), 0.1, rng.randf_range(-3.5, -1.5))
				puff(g, Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.6, 1.5), 0) + fwd * 1.0, 0.3,
					Color(0.72, 0.65, 0.5), 2.0, 1.8, 0.45, t)
	super._effects(t)


# ---------------------------------------------------------------- crew helpers

## A man placed in a gun's frame (world), standing.
func gunner_man(seed_value: int, d: Dictionary, local: Vector3, yaw_local: float) -> Dictionary:
	var n: FieldGun = d["node"]
	var a := _man(seed_value, "")
	a["pos"] = n.global_transform * local
	a["yaw"] = n.rotation.y + yaw_local
	return a


## World point of a gun-frame point (at time of evaluation).
func gpt(d: Dictionary, local: Vector3) -> Vector3:
	return (d["node"] as Node3D).global_transform * local


# ---------------------------------------------------------------- look

func _scene_look() -> float:
	var row := [[0, false, -4.5], [1, false, -1.5], [2, false, 1.5], [0, true, 4.5]]
	var info := []
	var shots: Array = [7.0]
	for r: Array in row:
		var d := fgun(Vector3(r[2], 0, 0), 0.0, r[0], r[1])
		info.append("%s %d" % ["wreck" if r[1] else ["close", "mid", "far"][r[0]], (d["node"] as FieldGun).tri_count()])
		if not r[1]:
			d["elev"] = func(t: float) -> float: return 16.0 * Anim.ease_of(clampf((t - 3.0) / 2.0, 0.0, 1.0), "smooth") \
				- 16.0 * Anim.ease_of(clampf((t - 9.0) / 1.5, 0.0, 1.0), "smooth")
			d["recoil"] = func(t: float) -> float: return recoil_at(t, shots)
			d["block"] = func(t: float) -> float: return clampf((t - 8.4) / 0.3, 0.0, 1.0) * (1.0 - clampf((t - 10.0) / 0.3, 0.0, 1.0))
		else:
			(d["node"] as FieldGun).set_lift(-0.06)
			(d["node"] as FieldGun).set_elev(-3.0)
	_phases = [[0.0, "Light field gun: close, mid, far looks and the wreck (triangles: " + ", ".join(info) + ")"],
		[3.0, "Elevating"], [7.0, "Recoil"], [8.4, "Breech open"]]
	_camera = func(t: float) -> void:
		cam.fov = 40.0
		for d: Dictionary in guns:
			(d["node"] as Node3D).rotation.y = 2.4 + t * 0.25
		cam.transform = Transform3D(Basis(), Vector3(0.0, 4.2, -10.5)).looking_at(Vector3(0, 0.6, 0), Vector3.UP)
	return 12.0


# ---------------------------------------------------------------- close (a check view, not for the report)

func _scene_close() -> float:
	var d := fgun(Vector3.ZERO, 0.0, 0, false)
	_phases = [[0.0, "Close look"]]
	_camera = func(t: float) -> void:
		cam.fov = 40.0
		var a := t * 0.9 + 0.6
		cam.transform = Transform3D(Basis(), Vector3(sin(a) * 5.5, 2.2, cos(a) * 5.5)).looking_at(Vector3(0, 0.6, 0.6), Vector3.UP)
	return 7.0



# ---------------------------------------------------------------- shared crew pieces

## Hands under a round (prop node): right under the case, left under the shell.
func on_round(rn: Node3D, lift := 0.05) -> Callable:
	return func(_t: float) -> Dictionary:
		var x := rn.global_transform
		return {"hand_r": x * Vector3(0.0, -lift, -0.06), "hand_l": x * Vector3(0.0, -lift, -0.38)}


## The layer's hands: right on the handwheel handle, left on the sight.
func layer_hands(d: Dictionary) -> Callable:
	var n: FieldGun = d["node"]
	return func(_t: float) -> Dictionary:
		return {"hand_r": n.handwheel.global_transform * Vector3(-0.06, 0.1, 0.0),
			"hand_l": n.cradle.global_transform * Vector3(-0.27, 0.27, 0.06)}


func lever_hands(d: Dictionary) -> Callable:
	var n: FieldGun = d["node"]
	return func(_t: float) -> Dictionary:
		return {"hand_l": n.barrel.global_transform * Vector3(0.2, GB.BORE_Y - 0.1, 0.55),
			"hand_r": n.carriage.global_transform * Vector3(0.5, 0.12, 0.25)}


## The man on an axle seat (s = 1 right, -1 left), placed in the gun's frame.
func seat_man(seed_value: int, d: Dictionary, s: float) -> Dictionary:
	var sp: Vector3 = GB.SEAT_R if s > 0.0 else GB.SEAT_L
	return gunner_man(seed_value, d, Vector3(sp.x, GB.WHEEL_R + sp.y - GC.SIT_H, sp.z + 0.02), 0.0)


static func ramp_fn(t: float, t0: float, d: float) -> float:
	return Anim.ease_of(clampf((t - t0) / d, 0.0, 1.0), "smooth")


## A spent case thrown out of the breech at t0, landing behind at `land` (gun frame).
func eject(d: Dictionary, t0: float, land: Vector3, spin_dir := 1.0) -> void:
	var n: FieldGun = d["node"]
	var case_mesh := km(GB.round_mesh(false))
	var fly := func(t: float) -> Transform3D:
		var u := clampf((t - t0) / 0.55, 0.0, 1.0)
		var a := n.breech_xf()
		var gx := n.global_transform
		var b := gx * Transform3D(Basis(Vector3.UP, PI * 0.5 * spin_dir), land + Vector3(0, 0.045, 0))
		var p := a.origin.lerp(b.origin, u)
		p.y += 0.5 * 4.0 * u * (1.0 - u)
		var rot := a.basis.slerp(b.basis, u) * Basis(Vector3.RIGHT, TAU * 1.5 * u * spin_dir)
		if u >= 1.0:
			rot = b.basis
		return Transform3D(rot.orthonormalized(), p)
	prop(case_mesh, [at_world(HIDE, 0.0), at_world(fly, t0)])


# ---------------------------------------------------------------- fire

func _scene_fire() -> float:
	var d := fgun(Vector3.ZERO, 0.0)
	var n: FieldGun = d["node"]
	var loads: Array = [1.4, 5.7, 10.0]
	var fires: Array = []
	for L: float in loads:
		fires.append(L + 3.5)
	var elevs: Array = [6.0, 7.5, 6.8]
	d["elev"] = func(t: float) -> float:
		var e: float = elevs[0]
		for k in range(1, elevs.size()):
			e = lerpf(e, float(elevs[k]), ramp_fn(t, float(fires[k - 1]) + 1.2, 1.4))
		return e
	d["recoil"] = func(t: float) -> float: return recoil_at(t, fires)
	d["pos"] = func(t: float) -> Vector3:
		var h := hop_at(t, fires)
		return Vector3(0, h * 1.2, h * 1.5)
	d["block"] = func(t: float) -> float:
		var o := 1.0
		for k in loads.size():
			var L: float = loads[k]
			var F: float = fires[k]
			if t >= L + 2.8:
				o = 1.0 - ramp_fn(t, L + 2.8, 0.3)
			if t >= F + 1.5:
				o = ramp_fn(t, F + 1.5, 0.25)
		return o
	for F: float in fires:
		shot(d, F)
	_update_gun(d, 0.0)
	# The ammunition box (4 rounds) and the crew.
	var box_xf := n.global_transform * Transform3D(Basis(), BOX_AT)
	var box_meshes: Array = []
	for k in 5:
		box_meshes.append(km(GB.ammo_box(1.0, k)))
	var box_fn := func(t: float) -> Variant:
		var left := 4
		for L: float in loads:
			if t >= L + 0.05:
				left -= 1
		return box_meshes[left]
	prop(box_meshes[4], [at_world(box_xf, 0.0)], box_fn)
	var layer := seat_man(201, d, -1.0)
	var breech := seat_man(202, d, 1.0)
	var loader := gunner_man(203, d, Vector3(0.58, 0, 1.45), 0.45)
	var am := [gunner_man(204, d, Vector3(1.3, 0, 2.35), 0.55), gunner_man(205, d, Vector3(1.75, 0, 1.4), 1.25)]
	var nco := gunner_man(206, d, Vector3(-1.55, 0, 0.7), -0.25)
	var spare := gunner_man(207, d, Vector3(-0.75, 0, 2.6), 0.2)
	var lh := layer_hands(d)
	var bh := lever_hands(d)
	var nco_rest := GC.nco_order(1.0).merged({"hand_r": null}, true)
	pose(layer, 0.0, 0.0, GC.layer(), lh, null)
	pose(breech, 0.0, 0.0, GC.breech_man(), bh, null)
	pose(loader, 0.0, 0.0, GC.kneel(8.0), null, null)
	for a: Dictionary in am:
		pose(a, 0.0, 0.0, GC.kneel(8.0), null, null)
	pose(nco, 0.0, 0.0, nco_rest, null, null)
	pose(spare, 0.0, 0.0, GC.kneel(5.0), null, null)
	var hold := [Vector3(1.12, 0.86, 2.0), Vector3(1.42, 0.86, 1.52)]
	var handoff := Vector3(0.95, 0.82, 1.68)
	for k in loads.size():
		var L: float = loads[k]
		var F: float = fires[k]
		var a: Dictionary = am[k % 2]
		# The round: out of the box, held, handed over, swung to the breech, pushed in.
		var slot := box_xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.26, 0.13, -0.11 + 0.075 * k))
		var gb := n.global_transform.basis
		var out_fn := func(_t: float) -> Transform3D: return n.breech_xf() * Transform3D(Basis(), Vector3(0, 0, 0.62))
		var in_fn := func(_t: float) -> Transform3D: return n.breech_xf() * Transform3D(Basis(), Vector3(0, 0, -0.02))
		var rn := prop(km(GB.round_mesh()), [at_world(slot, 0.0), at_world(Transform3D(gb, gpt(d, hold[k % 2])), L, 0.6),
			at_world(Transform3D(gb, gpt(d, handoff)), L + 0.9, 0.5),
			at_world(Transform3D(gb * Basis(Vector3.UP, 0.2), gpt(d, Vector3(0.72, 0.8, 1.42))), L + 1.5, 0.4),
			at_world(out_fn, L + 1.9, 0.5), at_world(in_fn, L + 2.4, 0.35), at_world(HIDE, F)])
		var rh := on_round(rn)
		# Ammunition number: reach into the box, lift, hand over, sit back; flinch at the shot.
		pose(a, L - 0.45, 0.45, GC.kneel(32.0), rh)
		pose(a, L, 0.6, GC.kneel(6.0), rh)
		pose(a, L + 0.9, 0.5, GC.kneel(22.0, -10.0 if k % 2 == 0 else 10.0), rh)
		pose(a, L + 1.6, 0.5, GC.kneel(8.0))
		# Loader: takes it, turns to the breech, pushes it home, sits back.
		pose(loader, L + 1.15, 0.35, GC.kneel(18.0, -25.0), rh)
		pose(loader, L + 1.5, 0.4, GC.kneel(10.0, -5.0), rh)
		pose(loader, L + 1.9, 0.5, GC.kneel(22.0, 25.0), rh)
		pose(loader, L + 2.4, 0.35, GC.kneel(34.0, 25.0), rh)
		pose(loader, L + 2.8, 0.4, GC.kneel(8.0))
		# Breech man closes the block, lets go for the shot, opens it after the run-out.
		pose(breech, L + 2.75, 0.3, GC.breech_man(1.2), bh)
		pose(breech, F - 0.45, 0.3, GC.breech_man(0.2), null)
		pose(breech, F - 0.05, 0.2, GC.flinch(GC.breech_man(-0.4)))
		pose(breech, F + 0.9, 0.5, GC.breech_man(1.0), bh)
		# NCO: arm up when the round goes in, swept down on "Fire!".
		pose(nco, L + 2.4, 0.4, GC.nco_order(0.0))
		pose(nco, F - 0.18, 0.18, GC.nco_order(1.0), null, "prev", "in")
		pose(nco, F + 0.9, 0.6, nco_rest)
		# The shot: everyone not holding anything flinches.
		pose(layer, F - 0.05, 0.12, GC.flinch(GC.layer(-1.0), false), lh, "prev", "out")
		pose(layer, F + 0.5, 0.5, GC.layer(), lh)
		for m: Dictionary in [loader, spare, am[0], am[1]]:
			pose(m, F - 0.08, 0.18, GC.flinch(GC.kneel(14.0)), null, "prev", "out")
			pose(m, F + 0.7, 0.45, GC.kneel(8.0))
		eject(d, F + 1.55, Vector3(0.15 + 0.1 * k, 0.0, 2.2 + 0.3 * k), 1.0 if k % 2 == 0 else -1.0)
	_phases = [[0.0, "In action: crew of six"], [loads[0], "Round out of the box, handed to the loader"],
		[loads[0] + 2.4, "Rammed home, breech closed, ready"], [fires[0], "Fire!"], [fires[0] + 1.4, "Breech open, case out"],
		[loads[1], "Next round"], [fires[1], "Fire!"], [loads[2], "Next round"], [fires[2], "Fire!"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		var front: bool = t > float(fires[1]) - 1.2 and t < float(fires[1]) + 2.5
		if front:
			cam.transform = Transform3D(Basis(), Vector3(3.2, 1.5, -4.2)).looking_at(Vector3(0.0, 0.8, 0.4), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), Vector3(-2.9 - 0.02 * t, 2.7, 4.3)).looking_at(Vector3(0.35, 0.65, 0.9), Vector3.UP)
	return 18.0



# ---------------------------------------------------------------- more crew helpers

## World point of a carriage-frame point for gun d at its current pose.
func cpt(d: Dictionary, local: Vector3) -> Vector3:
	return (d["node"] as FieldGun).cw(local)


## Hands on the trail handles (side s: 1 = the man on the right of the trail).
func trail_hands(d: Dictionary, s: float) -> Callable:
	return func(_t: float) -> Dictionary:
		var h := GB.HANDLE_R if s > 0.0 else GB.HANDLE_L
		var inner := Vector3(0.1 * s, -0.27, 2.3)
		if s > 0.0:
			return {"hand_r": cpt(d, h + Vector3(0.03, 0, 0)), "hand_l": cpt(d, inner)}
		return {"hand_l": cpt(d, h - Vector3(0.03, 0, 0)), "hand_r": cpt(d, inner)}


## Where a trail man stands for lift a (gun frame), beside the trail end.
static func trail_spot(s: float, a: float) -> Vector3:
	var h := FieldGun.at_lift(GB.HANDLE_R, a)
	return Vector3(0.62 * s, 0, h.z + 0.25)


## A crew settled in action around gun d (layer and breech man seated, the others kneeling).
## Returns {layer, breech, loader, am0, am1, nco}.
func crew_in_action(d: Dictionary, seed0 := 201) -> Dictionary:
	var c := {"layer": seat_man(seed0, d, -1.0), "breech": seat_man(seed0 + 1, d, 1.0),
		"loader": gunner_man(seed0 + 2, d, Vector3(0.58, 0, 1.45), 0.45),
		"am0": gunner_man(seed0 + 3, d, Vector3(1.3, 0, 2.35), 0.55), "am1": gunner_man(seed0 + 4, d, Vector3(1.75, 0, 1.4), 1.25),
		"nco": gunner_man(seed0 + 5, d, Vector3(-1.55, 0, 0.7), -0.25)}
	pose(c["layer"], 0.0, 0.0, GC.layer(), layer_hands(d), null)
	pose(c["breech"], 0.0, 0.0, GC.breech_man(), lever_hands(d), null)
	for k: String in ["loader", "am0", "am1"]:
		pose(c[k], 0.0, 0.0, GC.kneel(8.0), null, null)
	pose(c["nco"], 0.0, 0.0, GC.nco_order(1.0).merged({"hand_r": null}, true), null, null)
	return c


# ---------------------------------------------------------------- aim

func _scene_aim() -> float:
	var d := fgun(Vector3.ZERO, 0.0)
	var n: FieldGun = d["node"]
	var heaves: Array = [4.6, 6.2, 7.8]
	var step := deg_to_rad(6.0)
	d["elev"] = func(t: float) -> float:
		return 3.0 + 11.0 * ramp_fn(t, 1.6, 2.4) - 4.0 * ramp_fn(t, 10.0, 1.4)
	d["yaw"] = func(t: float) -> float:
		var y := 0.0
		for h: float in heaves:
			y += step * ramp_fn(t, h + 0.45, 0.8)
		return y
	d["lift"] = func(t: float) -> float:
		var a := 0.0
		for h: float in heaves:
			a = maxf(a, 0.05 * clampf((t - h - 0.25) / 0.2, 0.0, 1.0) * (1.0 - clampf((t - h - 1.25) / 0.2, 0.0, 1.0)))
		return a
	_update_gun(d, 0.0)
	var box_xf := n.global_transform * Transform3D(Basis(), BOX_AT)
	prop(km(GB.ammo_box(0.0, 4)), [at_world(box_xf, 0.0)])
	var c := crew_in_action(d)
	var nco: Dictionary = c["nco"]
	# The NCO points out the new line: half left and further off.
	pose(nco, 0.9, 0.5, GC.nco_point(Vector3(-5.0, 1.8, -8.0)))
	pose(nco, 4.2, 0.6, GC.nco_order(1.0).merged({"hand_r": null}, true))
	pose(nco, 9.6, 0.5, GC.nco_point(Vector3(-6.5, 2.2, -7.0)))
	pose(nco, 11.2, 0.6, GC.nco_order(1.0).merged({"hand_r": null}, true))
	# The layer winds the handwheel, peering into the sight.
	pose(c["layer"], 1.4, 0.3, GC.layer(1.0), layer_hands(d))
	pose(c["layer"], 4.2, 0.4, GC.layer(0.0), layer_hands(d))
	pose(c["layer"], 9.8, 0.3, GC.layer(1.0), layer_hands(d))
	pose(c["layer"], 11.6, 0.4, GC.layer(0.0), layer_hands(d))
	# Two men shift the trail with the handspike: in the socket, heave, the trail swings right.
	var spiker: Dictionary = c["loader"]
	var helper: Dictionary = c["am0"]
	var spike_xf := func(_t: float) -> Transform3D:
		var x := n.carriage.global_transform
		return Transform3D(x.basis * Basis(Vector3.RIGHT, -0.55) * Basis(Vector3.UP, -0.5), x * GB.SPIKE_SOCKET)
	var spike_rest := n.global_transform * Transform3D(Basis(Vector3.UP, 1.2), Vector3(1.0, 0.03, 2.9))
	prop(km(GB.handspike()), [at_world(spike_rest, 0.0), at_world(spike_xf, 3.8, 0.5)])
	var spike_hands := func(_t: float) -> Dictionary:
		var x := spike_xf.call(0.0) as Transform3D
		return {"hand_r": x * Vector3(0.03, 0, 1.25), "hand_l": x * Vector3(-0.03, 0, 0.95)}
	var spot_of := func(local: Vector3, k: int) -> Vector3:
		return Basis(Vector3.UP, step * float(k)) * local
	var sp_local := Vector3(-0.95, 0, 3.95)
	var hp_local := Vector3(-0.7, 0, 2.55)
	pose(spiker, 3.0, 0.5, GC.kneel(8.0), null, "prev", "smooth", null, 0.45)
	var t_w := move(spiker, 3.1, spot_of.call(sp_local, 0), Body.gait(Body.WALK, C.carry("free")), -0.785)
	pose(spiker, maxf(t_w, 3.9), 0.4, GC.heave(30.0, 18.0), spike_hands, "prev", "smooth", null, -0.785)
	var t_h := move(helper, 3.4, spot_of.call(hp_local, 0), Body.gait(Body.WALK, C.carry("free")), 0.0)
	pose(helper, t_h, 0.4, GC.heave(40.0, 25.0), trail_hands(d, -1.0), "prev", "smooth", null, -PI * 0.5)
	for k in heaves.size():
		var h: float = heaves[k]
		pose(spiker, h + 0.25, 0.25, GC.heave(18.0, 26.0), spike_hands)
		shift(spiker, h + 0.45, 0.8, GC.heave(24.0, 22.0), spot_of.call(sp_local, k + 1), 0.0, spike_hands, "smooth",
			-0.785 + step * (k + 1))
		pose(helper, h + 0.25, 0.25, GC.heave(46.0, 30.0), trail_hands(d, -1.0))
		shift(helper, h + 0.45, 0.8, GC.heave(40.0, 25.0), spot_of.call(hp_local, k + 1), 0.0, trail_hands(d, -1.0), "smooth",
			-PI * 0.5 + step * (k + 1))
	pose(spiker, 9.5, 0.5, Rig.over(Body.body("stand"), C.carry("free")))
	pose(helper, 9.5, 0.5, Rig.over(Body.body("stand"), C.carry("free")))
	_phases = [[0.0, "Aiming: crew in action"], [0.9, "NCO gives the new line"], [1.6, "Layer winds the elevation up"],
		[3.8, "Handspike in the trail"], [heaves[0], "Heave: the trail goes over, the gun turns left"],
		[9.6, "Fine correction"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		cam.transform = Transform3D(Basis(), Vector3(-3.4, 3.3, 5.6)).looking_at(Vector3(0.2, 0.5, 1.2), Vector3.UP)
	return 12.5


# ---------------------------------------------------------------- push (manhandling)

func _scene_push() -> float:
	var start := Vector3(0, 0, 2.0)
	var d := fgun(start, 0.0)
	var n: FieldGun = d["node"]
	var lift_up := 0.26
	var v := 0.8
	var t_go := 1.8
	var dist := 3.6
	var t_stop := t_go + dist / v
	var turn := deg_to_rad(28.0)
	var t_turn := t_stop + 0.3
	var turn_d := 2.4
	d["lift"] = func(t: float) -> float: return lift_up * ramp_fn(t, 0.9, 0.7) * (1.0 - ramp_fn(t, t_turn + turn_d + 0.3, 0.6))
	d["pos"] = func(t: float) -> Vector3: return start + Vector3(0, 0, -v * clampf(t - t_go, 0.0, dist / v))
	d["yaw"] = func(t: float) -> float: return turn * ramp_fn(t, t_turn, turn_d)
	_update_gun(d, 0.0)
	var end := start + Vector3(0, 0, -dist)
	var men: Array = []
	# Two at the trail, one behind each wheel, one carrying the ammunition box, the NCO alongside.
	var trail_r := trail_spot(1.0, lift_up)
	var trail_l := trail_spot(-1.0, lift_up)
	var wheel_r := Vector3(0.95, 0, 1.0)
	var wheel_l := Vector3(-0.95, 0, 1.0)
	var spots := [trail_r, trail_l, wheel_r, wheel_l, Vector3(1.35, 0, 1.9)]
	var grips := [
		[FieldGun.at_lift(GB.HANDLE_R + Vector3(0.03, 0, 0), lift_up), FieldGun.at_lift(Vector3(0.1, -0.27, 2.3), lift_up)],
		[FieldGun.at_lift(Vector3(-0.1, -0.27, 2.3), lift_up), FieldGun.at_lift(GB.HANDLE_L - Vector3(0.03, 0, 0), lift_up)],
		[Vector3(0.82, 1.06, 0.42), Vector3(0.7, 0.86, 0.56)], [Vector3(-0.7, 0.86, 0.56), Vector3(-0.82, 1.06, 0.42)],
		[Vector3(1.65, 0.8, 1.45), Vector3(1.05, 0.8, 1.45)]]
	var box_mesh := km(GB.ammo_box(0.0, 4))
	for i in 5:
		var sp: Vector3 = spots[i]
		var a := gunner_man(211 + i, d, sp, 0.0)
		var g: Array = grips[i]
		var hr: Vector3 = g[0]
		var hl: Vector3 = g[1]
		var gait := GC.push_gait(hr - sp, hl - sp, v)
		var fixed := func(_t: float) -> Dictionary: return {"hand_r": gpt(d, hr), "hand_l": gpt(d, hl)}
		if i < 2:
			var s := 1.0 if i == 0 else -1.0
			pose(a, 0.0, 0.0, Rig.over(Body.body("stand"), C.carry("free")), null, null)
			pose(a, 0.4, 0.5, GC.heave(48.0, 30.0), trail_hands(d, s))
			pose(a, 0.9, 0.7, GC.heave(30.0, 18.0), trail_hands(d, s))
		elif i < 4:
			pose(a, 0.0, 0.0, Rig.over(Body.body("stand"), C.carry("free")), null, null)
			pose(a, 0.8, 0.6, GC.heave(38.0, 22.0), fixed)
		else:
			pose(a, 0.0, 0.0, GC.heave(50.0, 34.0), fixed, null)
			pose(a, 0.9, 0.6, GC.heave(22.0, 18.0), fixed)
			var box := prop(box_mesh, [at_world(n.global_transform * Transform3D(Basis(), Vector3(1.35, 0.0, 1.45)), 0.0)])
			var box_fn := func(_t: float) -> Transform3D:
				return Transform3D(n.global_transform.basis, gpt(d, Vector3(1.35, 0.72 * ramp_fn(_t, 0.9, 0.6), 1.45)))
			props.back()["keys"] = [at_world(box_fn, 0.0)]
		move(a, t_go, sp + Vector3(0, 0, -dist) + start, gait, 0.0)
		a["pos"] = n.global_transform * sp + Vector3(0, 0, -dist)
		men.append(a)
	# The turn: everyone swings round the axle with the gun.
	for i in 5:
		var a: Dictionary = men[i]
		var sp: Vector3 = spots[i]
		var rot := Basis(Vector3.UP, turn)
		var to := end + rot * sp
		var hands: Callable
		if i < 2:
			hands = trail_hands(d, 1.0 if i == 0 else -1.0)
		else:
			var g: Array = grips[i]
			var hr: Vector3 = g[0]
			var hl: Vector3 = g[1]
			hands = func(_t: float) -> Dictionary: return {"hand_r": gpt(d, hr), "hand_l": gpt(d, hl)}
		a["pos"] = end + sp
		pose(a, t_stop, 0.3, GC.heave(30.0 if i < 2 else 34.0, 20.0), hands, "prev", "smooth", end + sp, 0.0)
		shift(a, t_turn, turn_d, GC.heave(30.0 if i < 2 else 34.0, 20.0), to, 0.0, hands, "smooth", turn)
		if i < 4:
			pose(a, t_turn + turn_d + 0.4, 0.6, GC.heave(44.0, 30.0) if i < 2 else Rig.over(Body.body("stand"), C.carry("free")),
				hands if i < 2 else null)
			if i < 2:
				pose(a, t_turn + turn_d + 1.2, 0.6, Rig.over(Body.body("stand"), C.carry("free")))
	var nco := gunner_man(219, d, Vector3(-1.9, 0, 0.0), 0.0)
	pose(nco, 0.0, 0.0, GC.nco_point(Vector3(0.0, 1.0, -6.0)), null, null)
	move(nco, t_go, start + Vector3(-1.9, 0, -dist), Body.gait(O.WALK, O.walking()), 0.0)
	nco["pos"] = start + Vector3(-1.9, 0, -dist)
	pose(nco, t_stop, 0.5, GC.nco_point(Vector3(-4.0, 1.0, -3.0)), null, "prev", "smooth", null, 0.0)
	pose(nco, t_turn + turn_d + 0.5, 0.6, GC.nco_order(1.0).merged({"hand_r": null}, true))
	_phases = [[0.0, "Manhandling: grip the trail and the wheels"], [0.9, "Trail up"], [t_go, "Push"],
		[t_turn, "Swing the trail round"], [t_turn + turn_d + 0.3, "Trail down"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		cam.transform = Transform3D(Basis(), Vector3(5.2, 3.6, 3.6 - 0.2 * t)).looking_at(Vector3(0, 0.6, 1.2 - 0.25 * minf(t, 8.0)),
			Vector3.UP)
	return t_turn + turn_d + 2.6


# ---------------------------------------------------------------- wreck

func _scene_wreck() -> float:
	var hit := 2.5
	var d := fgun(Vector3.ZERO, 0.0)
	var wk := fgun(Vector3.ZERO, 0.0, 0, true)
	var wn: FieldGun = wk["node"]
	wn.visible = false
	wn.set_lift(-0.05)
	wn.set_elev(-4.0)
	wn.rotation = Vector3(0, 0.12, 0.16)
	wn.position = Vector3(0.05, -0.06, 0.1)
	(wn.wheels[0] as Node3D).get_parent().position = Vector3(GB.TRACK + 0.35, 0.08, 0.3)
	(wn.wheels[0] as Node3D).get_parent().rotation = Vector3(0, 0.4, PI * 0.5)
	var box_xf := (d["node"] as Node3D).global_transform * Transform3D(Basis(), BOX_AT)
	prop(km(GB.ammo_box(1.0, 2)), [at_world(box_xf, 0.0)])
	var boom := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.8
	bs.height = 1.6
	bs.material = _mat("boom", Color(1.0, 0.85, 0.5), true)
	boom.mesh = bs
	stage.add_child(boom)
	boom.position = Vector3(0.9, 0.5, -0.6)
	var fired := {"done": false}
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 6.0
	stage.add_child(light)
	light.position = Vector3(0.3, 1.0, 0.3)
	var flames := [Vector3(0.0, 0.85, 0.1), Vector3(0.3, 0.4, 1.0), Vector3(1.25, 0.25, 1.75)]
	var fx := func(t: float) -> void:
		boom.visible = t >= hit and t < hit + 0.12
		boom.scale = Vector3.ONE * (1.0 + (t - hit) * 10.0) if boom.visible else Vector3.ONE
		var down := t >= hit + 0.05
		(d["node"] as Node3D).visible = not down
		wn.visible = down
		light.visible = down
		if t >= hit and not fired["done"]:
			fired["done"] = true
			var rng := RandomNumberGenerator.new()
			rng.seed = 21
			for k in 24:
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.7, 1.8), rng.randf_range(-1, 1))
				puff(Vector3(0.9, 0.2, -0.6), dir * rng.randf_range(2.0, 4.5), 0.28, Color(0.36, 0.3, 0.22), 1.8, 1.6, 0.85, t)
		if not down:
			return
		var age := t - hit
		var strength := clampf(1.0 - (age - 4.0) / 3.0, 0.2, 1.0)
		light.light_energy = (1.6 + 0.6 * sin(t * 17.0)) * strength
		if frame % 3 == 0:
			var src: Vector3 = flames[frame % 3]
			puff(src + Vector3(0, 0.3, 0), Vector3(0.2, 1.1, 0.05), 0.28, Color(0.12, 0.11, 0.1) if strength > 0.5 else Color(0.3, 0.29, 0.28),
				2.8, 1.0, 0.6 * strength + 0.15, t)
		if frame % 2 == 0 and strength > 0.4:
			puff(flames[(frame / 2) % 3] + Vector3(0, 0.1, 0), Vector3(0, 0.9, 0), 0.12, Color(1.0, 0.55, 0.15), 0.4, 1.5, 0.9, t)
	_phases = [[0.0, "Gun in action, crew under cover"], [hit, "Direct hit"], [hit + 0.4, "Knocked out: a wheel off, the shield torn"],
		[hit + 6.0, "The wreck stays on the map"]]
	_camera = func(t: float) -> void:
		fx.call(t)
		cam.fov = 44.0
		cam.transform = Transform3D(Basis(), Vector3(4.6 - 0.05 * t, 2.6, -3.8)).looking_at(Vector3(0, 0.6, 0.4), Vector3.UP)
	return 11.0



# ---------------------------------------------------------------- lorry crew helpers

## Six gunners seated at the back of lorry l (seats 3-5 left, 9-11 right). Returns them.
func ride_crew(l: Dictionary, until: float) -> Array:
	var seats := Lorry.seats()
	var men: Array = []
	for i in 6:
		var seat_i: int = [5, 11, 4, 10, 3, 9][i]
		var st: Dictionary = seats[seat_i]
		var a := rider(221 + i, "", l, st["pos"], st["yaw"])
		pose(a, 0.0, 0.0, V.seated(0.0, 4.0 * (i % 3)), null, null)
		var tk := 0.8 + 0.5 * i
		var k := 0
		while tk < until - 0.8:
			pose(a, tk, 0.6, V.seated([25.0, -20.0, 0.0, 35.0][(i + k) % 4], 4.0 * (i % 3)))
			tk += 2.3 + 0.4 * ((i + k) % 3)
			k += 1
		a["seat"] = seat_i
		men.append(a)
	return men


## Man a (riding lorry l, seated) gets out over the tailgate at t: to the edge, drop, land.
## Returns the landing time; a["pos"] is then the landing spot in world space.
func jump_out(a: Dictionary, l: Dictionary, t: float, side: float) -> float:
	var st: Dictionary = Lorry.seats()[a["seat"]]
	var sp: Vector3 = st["pos"]
	var crouch := Body.gait(C.CROUCH, C.carry("free"))
	shift(a, t, 0.4, V.stooped(), Vector3(sp.x * 0.35, LB.FLOOR_Y, sp.z), 0.0, null, "smooth", PI)
	var xe := 0.32 * side
	var t_e := move(a, t + 0.45, Vector3(xe, LB.FLOOR_Y, 2.42), crouch, PI)
	pose(a, t_e, 0.22, V.crouch())
	# The landing spot in the lorry frame; the lorry is stopped, so world = its transform.
	var land_l := Vector3(xe * 2.2, 0, 3.45)
	shift(a, t_e + 0.25, 0.32, V.airborne(), land_l, 0.35, null, "lin", PI)
	pose(a, t_e + 0.57, 0.12, V.crouch(1.0), null, "prev", "out")
	# Re-parent to the stage at the landing (a world-space actor from here).
	var s: Soldier = a["s"]
	var lnode: Lorry = l["node"]
	var land_w := lnode.body.global_transform * land_l
	var t_land := t_e + 0.75
	a["reparent_at"] = t_land
	a["world_pos"] = land_w
	a["world_yaw"] = lnode.rotation.y + PI
	# From the landing on, every segment is in world space.
	pose(a, t_land, 0.3, Rig.over(Body.body("stand"), C.carry("free")), null, "prev", "smooth", land_w, lnode.rotation.y + PI)
	return t_land


## Actors marked reparent_at move from the lorry body to the stage at that time; actors
## given a "pinned" transform ride the lorry body at that spot (only the pose plays).
func _eval_actor(a: Dictionary, t: float) -> void:
	if a.has("reparent_at") and t >= float(a["reparent_at"]) and not a.get("reparented", false):
		a["reparented"] = true
		var s: Soldier = a["s"]
		s.get_parent().remove_child(s)
		stage.add_child(s)
	super._eval_actor(a, t)
	if a.has("pinned"):
		(a["s"] as Soldier).transform = a["pinned"]


# ---------------------------------------------------------------- unhitch and into action

func _scene_unhitch() -> float:
	var stop_t := 4.0
	var go := 8.4
	var tail := func(t: float) -> float: return Anim.ease_of(clampf((t - 4.4) / 0.6, 0.0, 1.0), "in")
	var drive_fn := func(t: float) -> float:
		if t < go:
			return (arrive(stop_t, 16.0, 2.2, 5.0) as Callable).call(t)
		return 16.0 + (go_from(go, 1.4, 4.0) as Callable).call(t)
	var l := lorry(Vector3(0, 0, 9.5), 0.0, drive_fn, null, tail)
	driver(l)
	var d := fgun(Vector3(0, 0, 14.0), PI)
	tow(d, l)
	var n: FieldGun = d["node"]
	var men := ride_crew(l, 5.0)
	# Where the gun ends up: unhooked, then swung round 180 degrees about its axle.
	var lorry_end := Vector3(0, 0, 9.5 - 16.0)
	var hook_end := lorry_end + LB.HOOK
	var eye0 := FieldGun.at_lift(GB.LUNETTE, FieldGun.lift_for(LB.HOOK.y))
	var axle := Vector3(0, 0, hook_end.z + eye0.z)
	var lift_carry := 0.3
	var t_unhook := 7.6
	var t_swing := 9.4
	var v_sw := 1.15
	var n_seg := 8
	var r_arc := trail_spot(1.0, lift_carry).length()
	var seg_len := 2.0 * r_arc * sin(PI / float(n_seg) * 0.5)
	var seg_t := seg_len / v_sw
	var t_down := t_swing + seg_t * n_seg + 0.2
	var lift0 := FieldGun.lift_for(LB.HOOK.y)
	d["lift"] = func(t: float) -> float:
		return lerpf(lift0, lift_carry, ramp_fn(t, t_unhook, 0.6)) * (1.0 - ramp_fn(t, t_down, 0.7))
	d["yaw"] = func(t: float) -> float:
		return PI - PI * clampf((t - t_swing) / (seg_t * n_seg), 0.0, 1.0)
	d["pos"] = func(_t: float) -> Vector3: return axle
	var unhooked := {"done": false}
	var trail_men: Array = [men[0], men[1]]
	var others: Array = [men[2], men[3], men[4], men[5]]
	for j in 6:
		var a: Dictionary = men[j]
		var side := 1.0 if j % 2 == 0 else -1.0
		jump_out(a, l, 4.9 + 0.62 * j, side)
	# Trail men: to the handles (the gun still faces back along the road), lift off the hook, swing.
	for i in 2:
		var a: Dictionary = trail_men[i]
		var s := 1.0 if i == 0 else -1.0
		var t_land: float = a["reparent_at"]
		a["pos"] = a["world_pos"]
		a["yaw"] = a["world_yaw"]
		# Gun yaw PI: its frame is turned round, so its right (+s) is world -X.
		var spot0 := axle + Basis(Vector3.UP, PI) * trail_spot(s, lift0)
		var walk := Body.gait(Body.WALK, C.carry("free"))
		var t_w := move(a, t_land + 0.3, spot0, walk)
		pose(a, maxf(t_w, 6.9), 0.5, GC.heave(46.0, 30.0), trail_hands(d, s), "prev", "smooth", null, PI)
		pose(a, t_unhook, 0.6, GC.heave(30.0, 18.0), trail_hands(d, s))
		var hr := FieldGun.at_lift(GB.HANDLE_R + Vector3(0.03, 0, 0), lift_carry) if s > 0.0 else FieldGun.at_lift(Vector3(-0.1, -0.27, 2.3), lift_carry)
		var hl := FieldGun.at_lift(Vector3(0.1, -0.27, 2.3), lift_carry) if s > 0.0 else FieldGun.at_lift(GB.HANDLE_L - Vector3(0.03, 0, 0), lift_carry)
		var sp := trail_spot(s, lift_carry)
		# Walking sideways round the axle: the man faces along the trail end's path (gun frame),
		# so his hands keep the same place relative to him all the way round.
		var vel := Vector3(-sp.z, 0, sp.x)
		var dl := atan2(-vel.x, -vel.z)
		var inv := Basis(Vector3.UP, -dl)
		var gait := GC.push_gait(inv * (hr - sp), inv * (hl - sp), v_sw)
		a["pos"] = axle + Basis(Vector3.UP, PI) * sp
		pose(a, t_swing - 0.45, 0.45, GC.heave(30.0, 18.0), trail_hands(d, s), "prev", "smooth", null, PI + dl)
		var tt := t_swing
		for k in n_seg:
			var yaw_k := PI - PI * float(k + 1) / float(n_seg)
			var to := axle + Basis(Vector3.UP, yaw_k) * sp
			move(a, tt, to, gait, yaw_k + dl)
			tt += seg_t
		a["pos"] = axle + sp
		a["yaw"] = 0.0
		pose(a, t_down - 0.05, 0.6, GC.heave(46.0, 30.0), trail_hands(d, s), "prev", "smooth", axle + sp, 0.0)
		pose(a, t_down + 0.9, 0.5, Rig.over(Body.body("stand"), C.carry("free")))
	# The rest walk wide round the swing to their places in action.
	var places := [["seat", -1.0], ["seat", 1.0], ["kneel", Vector3(0.58, 0, 1.45), 0.45], ["nco", Vector3(-1.55, 0, 0.7), -0.25]]
	for i in 4:
		var a: Dictionary = others[i]
		var t_land: float = a["reparent_at"]
		a["pos"] = a["world_pos"]
		a["yaw"] = a["world_yaw"]
		var pl: Array = places[i]
		var wait := axle + Vector3(-2.7 - 0.3 * (i % 2), 0, -1.6 + 0.95 * i)
		var walk := Body.gait(Body.WALK, C.carry("free"))
		var t_w := move(a, t_land + 0.4, wait, walk)
		pose(a, t_w, 0.5, Rig.over(Body.body("stand"), C.carry("free")), null, "prev", "smooth", null, PI * 0.15)
		var t_go := t_down + 0.2 + 0.25 * i
		match pl[0]:
			"seat":
				var sp: Vector3 = GB.SEAT_R if float(pl[1]) > 0.0 else GB.SEAT_L
				var front := axle + Vector3(sp.x * 1.6, 0, sp.z + 0.7)
				var t_a := move(a, t_go, front, walk)
				var seat_at := axle + Vector3(sp.x, GB.WHEEL_R + sp.y - GC.SIT_H, sp.z + 0.02)
				shift(a, t_a, 0.7, GC.layer() if float(pl[1]) < 0.0 else GC.breech_man(), seat_at, 0.0,
					layer_hands(d) if float(pl[1]) < 0.0 else lever_hands(d), "smooth", 0.0)
			"kneel":
				var t_a := move(a, t_go, axle + (pl[1] as Vector3), walk)
				pose(a, t_a, 0.6, GC.kneel(8.0), null, "prev", "smooth", null, float(pl[2]))
			_:
				var t_a := move(a, t_go, axle + (pl[1] as Vector3), walk)
				pose(a, t_a, 0.5, GC.nco_point(Vector3(0, 1.5, -8.0)), null, "prev", "smooth", null, float(pl[2]))
	var unhook_fx := func(t: float) -> void:
		if t >= t_unhook and not unhooked["done"]:
			unhooked["done"] = true
			untow(d)
	_phases = [[0.0, "Towing: the gun on the hook, crew in the back"], [4.4, "Tailgate down, crew out"],
		[6.9, "Trail off the hook"], [go, "Lorry away"], [t_swing, "Swing the gun round to face the front"],
		[t_down, "Trail down: into action"]]
	_camera = func(t: float) -> void:
		unhook_fx.call(t)
		cam.fov = 48.0
		if t < 4.0:
			var p: Vector3 = (l["node"] as Node3D).position
			cam.transform = Transform3D(Basis(), p + Vector3(6.5, 4.5, 9.0)).looking_at(p + Vector3(0, 0.8, 3.5), Vector3.UP)
		else:
			var p2 := lorry_end + Vector3(6.5, 4.5, 9.0)
			cam.transform = Transform3D(Basis(), p2.lerp(axle + Vector3(6.0, 5.0, 6.5), ramp_fn(t, 8.0, 3.0))).looking_at(
				(lorry_end + Vector3(0, 0.8, 3.5)).lerp(axle + Vector3(0, 0.5, 0.6), ramp_fn(t, 8.0, 3.0)), Vector3.UP)
	return t_down + 3.2


# ---------------------------------------------------------------- hitch (limber up)

func _scene_hitch() -> float:
	var d := fgun(Vector3.ZERO, 0.0)
	var n: FieldGun = d["node"]
	# The lorry backs up to the trail: it faces away from the gun (yaw PI), its hook toward the trail.
	var lift_hook := FieldGun.lift_for(LB.HOOK.y)
	var eye := FieldGun.at_lift(GB.LUNETTE, lift_hook)
	var hook_z := eye.z
	var lorry_end_z := hook_z + LB.HOOK.z
	var back := 7.0
	var t_back := 1.0
	var t_stop := 6.2
	var t_on := 7.4
	var go := 20.5
	var rev := func(t: float) -> float:
		if t < go:
			return -back * ramp_fn(t, t_back, t_stop - t_back)
		return -back + (go_from(go, 1.2, 3.5) as Callable).call(t)
	var tail := func(t: float) -> float:
		if t < 7.6:
			return 0.0
		if t < 8.2:
			return Anim.ease_of((t - 7.6) / 0.6, "in")
		if t < 19.4:
			return 1.0
		return 1.0 - ramp_fn(t, 19.4, 0.7)
	var l := lorry(Vector3(0, 0, lorry_end_z + back), PI, rev, null, tail)
	driver(l)
	var lifted := FieldGun.lift_for(LB.HOOK.y + 0.16)
	d["lift"] = func(t: float) -> float:
		return lerpf(0.0, lifted, ramp_fn(t, 4.6, 0.7)) + (lift_hook - lifted) * ramp_fn(t, t_on - 0.5, 0.45)
	_update_gun(d, 0.0)
	var c := crew_in_action(d, 231)
	var hooked := {"done": false}
	# Two men on the trail lift it to the hook.
	var trail_men: Array = [c["loader"], c["am0"]]
	for i in 2:
		var a: Dictionary = trail_men[i]
		var s := 1.0 if i == 0 else -1.0
		var spot := trail_spot(s, lift_hook)
		var walk := Body.gait(Body.WALK, C.carry("free"))
		var t_w := move(a, 2.2 + 0.3 * i, spot, walk)
		pose(a, maxf(t_w, 4.0), 0.5, GC.heave(46.0, 30.0), trail_hands(d, s), "prev", "smooth", null, 0.0)
		pose(a, 4.6, 0.7, GC.heave(30.0, 16.0), trail_hands(d, s))
		pose(a, t_on - 0.5, 0.45, GC.heave(36.0, 22.0), trail_hands(d, s))
		pose(a, t_on + 0.2, 0.5, Rig.over(Body.body("stand"), C.carry("free")))
	# Everyone else stands up from their places.
	var seated: Array = [c["layer"], c["breech"]]
	for i in 2:
		var a: Dictionary = seated[i]
		var stand_at := (a["pos"] as Vector3) * Vector3(1.9, 0, 1) + Vector3(0, 0, 0.45)
		shift(a, 1.2 + 0.3 * i, 0.8, Rig.over(Body.body("stand"), C.carry("free")), stand_at, 0.0, null, "smooth", 0.0)
	pose(c["am1"], 1.5, 0.6, Rig.over(Body.body("stand"), C.carry("free")))
	pose(c["nco"], 3.0, 0.5, GC.nco_point(Vector3(0.0, 1.0, 6.0)), null, "prev", "smooth", null, PI)
	pose(c["nco"], t_stop, 0.5, GC.nco_order(0.0), null, "prev", "smooth", null, PI)
	pose(c["nco"], t_on, 0.4, GC.nco_order(1.0).merged({"hand_r": null}, true))
	# All six climb in over the tailgate, either side of the trail, and sit down.
	var order: Array = [c["loader"], c["am0"], c["layer"], c["breech"], c["am1"], c["nco"]]
	var seats := Lorry.seats()
	var lnode: Lorry = l["node"]
	var walk2 := Body.gait(Body.WALK, C.carry("free"))
	var crouch := Body.gait(C.CROUCH, C.carry("free"))
	for i in 6:
		var a: Dictionary = order[i]
		var seat_i: int = [5, 11, 4, 10, 3, 9][i]
		var st: Dictionary = seats[seat_i]
		var xq := -0.42 if i % 2 == 0 else 0.42
		var t_i := 8.8 + 1.25 * i
		# Lorry frame (yaw PI at the end spot) to world.
		var lx := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, lorry_end_z))
		var q: Vector3 = lx * Vector3(xq, 0, 3.3)
		var t_w := move(a, t_i - (a["pos"] as Vector3).distance_to(q) / float(walk2["speed"]) - 0.1, q, walk2)
		# Into the lorry body's frame: the climb as in the boarding scene.
		var body: Node3D = lnode.body
		var edge := func(_t: float) -> Dictionary:
			var x := body.global_transform
			return {"hand_r": x * Vector3(xq + 0.24, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04),
				"hand_l": x * Vector3(xq - 0.24, LB.FLOOR_Y + 0.03, LB.BED_REAR - 0.04)}
		pose(a, t_i, 0.35, V.climb(0, LB.STEP.y, LB.FLOOR_Y), edge, "prev", "smooth", null, PI)
		shift(a, t_i + 0.4, 0.45, V.climb(1, LB.STEP.y, LB.FLOOR_Y), lx * Vector3(xq, LB.STEP.y, 2.95), 0.0, edge, "smooth", PI)
		shift(a, t_i + 0.9, 0.45, V.climb(2, LB.STEP.y, LB.FLOOR_Y), lx * Vector3(xq, LB.FLOOR_Y, 2.4), 0.0, null, "smooth", PI)
		var sp: Vector3 = st["pos"]
		pose(a, t_i + 1.4, 0.35, V.stooped(), null, "prev", "smooth", lx * Vector3(xq, LB.FLOOR_Y, 2.4), PI)
		var t_m := move(a, t_i + 1.75, lx * Vector3(sp.x * 0.35, LB.FLOOR_Y, sp.z), crouch)
		shift(a, t_m, 0.5, V.seated(), lx * sp, 0.0, null, "smooth", float(st["yaw"]) + PI)
	var hook_fx := func(t: float) -> void:
		if t >= t_on and not hooked["done"]:
			hooked["done"] = true
			tow(d, l)
		if t >= go - 0.05 and not d.has("riders_moved"):
			d["riders_moved"] = true
			# The crew is seated: hand them to the lorry body so they ride the springs.
			for a: Dictionary in order:
				var s: Soldier = a["s"]
				var keep := s.global_transform
				stage.remove_child(s)
				lnode.body.add_child(s)
				s.global_transform = keep
				a["pinned"] = s.transform
	_phases = [[0.0, "Out of action: the lorry backs up"], [4.6, "Trail lifted to the hook"], [t_on, "Hooked on"],
		[8.4, "Crew climb in"], [go, "Away, towing"]]
	_camera = func(t: float) -> void:
		hook_fx.call(t)
		cam.fov = 48.0
		var p := Vector3(7.5, 5.0, 2.5)
		if t > go:
			var lp: Vector3 = lnode.position
			cam.transform = Transform3D(Basis(), p.lerp(lp + Vector3(7.5, 5.0, -6.0), ramp_fn(t, go, 3.0))).looking_at(
				Vector3(0, 0.8, lorry_end_z * 0.6).lerp(lp + Vector3(0, 0.8, -2.5), ramp_fn(t, go, 3.0)), Vector3.UP)
		else:
			cam.transform = Transform3D(Basis(), p).looking_at(Vector3(0, 0.8, lorry_end_z * 0.6), Vector3.UP)
	return go + 5.0



# ---------------------------------------------------------------- portee (carried in the bed)

const RAMP_LEN := 3.2
const PARK_Z := 0.95  # where the axle sits on the bed (lorry frame)


## Axle height over the lorry-frame z on the way in: ground, ramp, bed floor.
static func portee_axle_h(z: float) -> float:
	var foot := LB.BED_REAR + sqrt(RAMP_LEN * RAMP_LEN - LB.FLOOR_Y * LB.FLOOR_Y)
	var slope := LB.FLOOR_Y / (foot - LB.BED_REAR)
	var on_ramp := LB.FLOOR_Y * (foot - z) / (foot - LB.BED_REAR) + GB.WHEEL_R * sqrt(1.0 + slope * slope)
	return clampf(on_ramp, GB.WHEEL_R, LB.FLOOR_Y + GB.WHEEL_R)


func _scene_portee() -> float:
	var go := 17.0
	var still := func(t: float) -> float: return 0.0 if t < go else (go_from(go, 1.2, 3.5) as Callable).call(t)
	var tail := func(_t: float) -> float: return 1.0
	var l := lorry(Vector3.ZERO, 0.0, still, null, tail, 0, false)
	# Swap in the cargo body: no tilt, no benches.
	var lnode: Lorry = l["node"]
	lnode.queue_free()
	stage.remove_child(lnode)
	lnode = Lorry.new().setup(0, false, false, false)
	stage.add_child(lnode)
	l["node"] = lnode
	driver(l)
	var body := lnode.body
	var foot := LB.BED_REAR + sqrt(RAMP_LEN * RAMP_LEN - LB.FLOOR_Y * LB.FLOOR_Y)
	var ramp_pitch := asin(LB.FLOOR_Y / RAMP_LEN)
	for s: float in [1.0, -1.0]:
		var rm := MeshInstance3D.new()
		rm.mesh = km(GB.ramp(RAMP_LEN))
		rm.transform = Transform3D(Basis(Vector3.RIGHT, ramp_pitch), Vector3(GB.TRACK * s, 0.0, foot))
		stage.add_child(rm)
		rm.set_meta("ramp", true)
	# The gun rides in the lorry body's frame: start on the ground behind, end on the bed.
	var d := fgun(Vector3.ZERO, 0.0)
	var n: FieldGun = d["node"]
	stage.remove_child(n)
	body.add_child(n)
	var z0 := foot + 1.6
	var t_pull := 2.6
	var t_in := 12.4
	# A steady pull (the men pushing the trail walk at the same pace).
	var path_z := func(t: float) -> float:
		return lerpf(z0, PARK_Z, clampf((t - t_pull) / (t_in - t_pull), 0.0, 1.0))
	var pitch_at := func(z: float) -> float:
		return atan((portee_axle_h(z - 0.3) - portee_axle_h(z + 0.3)) / 0.6)
	# The trail end is held at waist height on the ground, higher as the gun climbs (clear of the tailboard).
	var trail_h_at := func(z: float) -> float:
		return lerpf(0.82, 1.32, clampf((portee_axle_h(z) - GB.WHEEL_R) / LB.FLOOR_Y, 0.0, 1.0))
	d["pos"] = func(t: float) -> Vector3:
		var z: float = path_z.call(t)
		var a: float = pitch_at.call(z)
		var axle := Vector3(0, portee_axle_h(z), z)
		return axle - Basis(Vector3.RIGHT, a) * Vector3(0, GB.WHEEL_R, 0)
	d["yaw"] = null
	d["lift"] = func(t: float) -> float:
		# The trail men hold the trail end at waist height; on the bed it rests on the tailboard.
		var z: float = path_z.call(t)
		var a: float = pitch_at.call(z)
		var axle_y := portee_axle_h(z)
		var want := lerpf(0.22, float(trail_h_at.call(z)), ramp_fn(t, 1.2, 0.8))
		var lw := FieldGun.lift_for(want - axle_y + GB.WHEEL_R) + a
		var rest := FieldGun.lift_for(LB.FLOOR_Y + 0.12 - axle_y + GB.WHEEL_R)
		return lerpf(lw, rest, ramp_fn(t, t_in + 0.4, 0.8))
	var pitch_fn := func(t: float) -> float: return pitch_at.call(path_z.call(t))
	# Pitch the whole gun on the ramp (its node turns about X).
	var base_update := func(t: float) -> void:
		n.rotation = Vector3(pitch_fn.call(t), 0, 0)
	d["extra"] = base_update
	_update_gun(d, 0.0)
	base_update.call(0.0)
	# Two men in the bed haul on ropes to the axle; two lift and push the trail; the NCO directs.
	var haulers: Array = []
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var a := rider(241 + i, "", l, Vector3(0.62 * s, LB.FLOOR_Y, -0.75), PI)
		pose(a, 0.0, 0.0, GC.heave(10.0, 12.0), null, null)
		haulers.append(a)
		var k := 0
		var tk := t_pull - 0.4
		while tk < t_in:
			var reach := k % 2 == 0
			var hands_m := [Vector3(0.12, 1.15, -0.55), Vector3(0.05, 1.0, -0.62)] if reach else [Vector3(0.12, 1.05, -0.18), Vector3(-0.02, 1.15, -0.32)]
			var spec := GC.heave(28.0 if reach else -6.0, 22.0 if reach else 26.0)
			spec = Rig.over(spec, {"hand_r": [-1, hands_m[0]], "hand_l": [-1, hands_m[1]]})
			pose(a, tk, 0.45 if reach else 0.55, spec, null)
			tk += 0.45 if reach else 0.6
			k += 1
		pose(a, t_in + 0.2, 0.6, Rig.over(Body.body("stand"), C.carry("free")))
		var rope_on := func(t: float) -> PackedVector3Array:
			if t > t_in + 0.2:
				return PackedVector3Array()
			var sl: Soldier = a["s"]
			var hp := sl.global_transform * sl.skel.get_bone_global_pose(B.HAND_R) * Vector3(0, -0.05, 0)
			var tie := n.global_transform * Vector3(GB.TRACK * 0.8 * s, GB.WHEEL_R, -0.05)
			return PackedVector3Array([hp, hp.lerp(tie, 0.5) + Vector3(0, -0.04, 0), tie])
		wire(rope_on)
	var trail_men: Array = []
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var start := Vector3(0.62 * s, 0, z0 + 2.72)
		var a := _man(243 + i, "")
		a["pos"] = body.global_transform * start
		a["yaw"] = 0.0
		pose(a, 0.0, 0.0, Rig.over(Body.body("stand"), C.carry("free")), null, null)
		pose(a, 0.6, 0.6, GC.heave(44.0, 30.0), trail_hands(d, s))
		pose(a, 1.2, 0.8, GC.heave(24.0, 14.0), trail_hands(d, s))
		# Walk in step with the trail end, hands on it (four stretches, the hands a little higher each).
		var v := (z0 - PARK_Z) / (t_in - t_pull)
		var tk := t_pull
		for k in 4:
			var t_mid := t_pull + (t_in - t_pull) * (float(k) + 0.5) / 4.0
			var hh: float = trail_h_at.call(path_z.call(t_mid))
			var hr := Vector3(-0.33 * s, hh, -0.27) if s > 0.0 else Vector3(0.5, hh + 0.04, -0.47)
			var hl := Vector3(-0.5, hh + 0.04, -0.47) if s > 0.0 else Vector3(0.33, hh, -0.27)
			var gait := GC.push_gait(hr, hl, v)
			var to := (a["pos"] as Vector3) + Vector3(0, 0, -(z0 - PARK_Z) / 4.0)
			tk = move(a, tk, to, gait, 0.0)
		pose(a, t_in, 0.5, GC.heave(20.0, 10.0), trail_hands(d, s))
		pose(a, t_in + 1.2, 0.5, Rig.over(Body.body("stand"), C.carry("free")))
		var away := (a["pos"] as Vector3) + Vector3(2.2 * s, 0, 1.4)
		move(a, t_in + 1.8, away, Body.gait(Body.WALK, C.carry("free")))
		trail_men.append(a)
	var nco := _man(245, "")
	nco["pos"] = body.global_transform * Vector3(-2.4, 0, z0 - 0.4)
	nco["yaw"] = -PI * 0.5
	pose(nco, 0.0, 0.0, GC.nco_point(Vector3(0, 1.0, -5.0)), null, null)
	pose(nco, t_in + 0.6, 0.6, GC.nco_order(1.0).merged({"hand_r": null}, true))
	_phases = [[0.0, "Portee: ramps down from the bed, tilt and benches off"], [t_pull, "Haul and push: up the ramps"],
		[t_in, "Aboard: the trail rests over the tailboard"], [go, "Away with the gun in the bed"]]
	_camera = func(t: float) -> void:
		cam.fov = 46.0
		var p: Vector3 = lnode.position
		var at := Vector3(7.6, 4.4, 9.5)
		cam.transform = Transform3D(Basis(), at.lerp(p + Vector3(6.5, 4.8, 2.0), ramp_fn(t, go, 3.0))).looking_at(
			Vector3(0, 1.0, 3.6).lerp(p + Vector3(0, 1.2, -1.0), ramp_fn(t, go, 3.0)), Vector3.UP)
	return go + 4.5
