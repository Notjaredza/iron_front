extends SceneTree
## Red coats round 2 pictures (Building Chat 1, 2026-11-10), in the explosion test's world (BlastStage) so the
## cannon's smoke is the same faceted billows. Needs a window:
##   Godot --path iron_front --resolution 1600x900 -s res://tools/redcoat2_pictures.gd -- [mode ...]
## Modes: look, drill, sheets, horse, cavalry. Writes results/units/redcoats/r2_*.png.

const M2 := preload("res://scripts/units/anim/clips_redcoat2.gd")
const RB := preload("res://scripts/units/redcoat_builder.gd")
const Rig := preload("res://scripts/units/anim/rig.gd")
const B := preload("res://scripts/units/soldier_builder.gd")
const OUT := "res://results/units/redcoats/"
const NEW_ROLES: Array[String] = ["grenadier", "light", "dragoon", "gunner_sponge", "gunner_fire"]

var stage: BlastStage
var ui: CanvasLayer
var title: Label
var things: Array[Node] = []
var lib: Dictionary
var gy := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lib = Redcoat.library()
	stage = BlastStage.new()
	stage.manual = true
	root.add_child(stage)
	ui = CanvasLayer.new()
	root.add_child(ui)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 7)
	title.position = Vector2(24, 16)
	ui.add_child(title)
	await process_frame
	gy = stage.ground.height(0, 0)
	var args := OS.get_cmdline_user_args()
	for mode in (args if not args.is_empty() else ["look", "drill", "sheets", "horse", "cavalry"]):
		match mode:
			"look":
				await _look_set()
			"drill":
				await _drill()
			"sheets":
				for c in ["grenadier_throw", "light_fire", "light_run", "light_prone_fire"]:
					await _sheet(c)
			"horse":
				await _horse_set()
			"cavalry":
				await _cavalry()
	print("REDCOAT2 PICTURES OK")
	quit()


# ---------------------------------------------------------------- helpers

func _clear() -> void:
	for n in things:
		if is_instance_valid(n):
			n.queue_free()
	things.clear()
	stage.clear_blasts()
	stage.step(0.0)
	title.text = ""


func _keep(n: Node) -> Node:
	things.append(n)
	return n


func _man(role: String, seed_value: int, at: Vector3, yaw_deg: float, pose := "stand", lod := 0) -> Redcoat:
	var r := Redcoat.new()
	r.setup(seed_value, lod, role)
	stage.add_child(r)
	r.position = Vector3(at.x, gy + at.y, at.z)
	r.rotation.y = deg_to_rad(yaw_deg)
	r.set_pose(pose)
	r.set_time(1.3)
	_keep(r)
	return r


## Looks at `at` from yaw (0 = from behind, PI = from the front), pitch (negative = from above), distance.
func _cam(at: Vector3, yaw: float, pitch: float, dist: float, fov := 40.0) -> void:
	stage.cam.fov = fov
	stage.aim(at + Vector3(0, gy, 0), yaw, pitch, dist)
	stage.step(stage.clock)
	stage.sun.directional_shadow_max_distance = 30.0


func _grab() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + "r2_" + name + ".png"))
	print("saved r2_", name)


func _tile(tiles: Array[Image], cols: int) -> Image:
	var w := tiles[0].get_width()
	var hh := tiles[0].get_height()
	var tw := w / 2
	var th := hh / 2
	var rows := ceili(float(tiles.size()) / cols)
	var out := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		var t := tiles[i]
		t.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(t, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	return out


# ---------------------------------------------------------------- the new men

func _look_set() -> void:
	_clear()
	for i in NEW_ROLES.size():
		_man(NEW_ROLES[i], 3 + i, Vector3(-2.6 + 1.3 * i, 0, 0), 0.0)
	for v: Array in [["front", PI, -0.08, 7.4], ["three_quarter", PI - 0.75, -0.12, 7.6], ["back", 0.0, -0.1, 7.4]]:
		_cam(Vector3(0, 1.15, 0), v[1], v[2], v[3], 38.0)
		_save(await _grab(), "look_" + v[0])
	# Hats and kit close up: the mitre, the light cap, the helmet; the grenadier's pouch and match case, the gunners' tools.
	_clear()
	_man("grenadier", 3, Vector3.ZERO, 0.0)
	_man("light", 4, Vector3(3, 0, 0), 0.0)
	_man("dragoon", 5, Vector3(6, 0, 0), 0.0)
	var tiles: Array[Image] = []
	for x: float in [0.0, 3.0, 6.0]:
		_cam(Vector3(x, 1.75, 0), PI - 0.5, -0.1, 1.3, 34.0)
		tiles.append(await _grab())
	_cam(Vector3(0, 1.1, 0), PI + 0.6, -0.15, 1.9, 36.0)
	tiles.append(await _grab())
	_save(_tile(tiles, 2), "closeups")
	# Close, mid and far meshes.
	_clear()
	var tris := ""
	for lod in 3:
		var parts: Array[String] = []
		for i in 3:
			var r := _man(["grenadier", "light", "gunner_sponge"][i], 3 + i, Vector3(-3.6 + 0.9 * i + 3.4 * lod, 0, 0), 0.0, "stand", lod)
			parts.append("%d" % r.tri_count())
		tris += "lod %d: %s   " % [lod, " / ".join(parts)]
	title.text = "close / mid / far: grenadier / light / gunner  " + tris
	_cam(Vector3(0.2, 1.0, 0), PI, -0.08, 9.0, 44.0)
	_save(await _grab(), "lods")


# ---------------------------------------------------------------- the gun drill

func _drill() -> void:
	var tiles: Array[Image] = []
	var names := {"sponge": "1  sponge out the bore", "load": "2  load (bag and ball)", "ram": "3  ram home",
		"prime": "4  prick and prime", "aim": "5  lay the gun", "fire": "6  fire!", "recoil": "7  the recoil",
		"run_up": "8  run up again"}
	for step: String in M2.DRILL:
		_clear()
		var gun := FieldCannon.new().setup(0)
		stage.add_child(gun)
		gun.position = Vector3(0, gy, 0)
		_keep(gun)
		var rec := 0.0
		if step == "recoil":
			rec = 1.25
		elif step == "run_up":
			rec = 0.6
		gun.set_state(rec, 3.0 if step in ["aim", "fire", "recoil"] else 0.0)
		for i in M2.CREW.size():
			var role: String = M2.CREW[i]
			var pl: Array = M2.crew_place(role, step, rec)
			var man := _man(role, 11 + i, pl[0], pl[1])
			var to_model := Transform3D(Basis(Vector3.UP, deg_to_rad(pl[1])), pl[0]).affine_inverse()
			var spec := M2.crew_spec(role, step, gun, to_model)
			man.show_spec(spec)
			if role == "gunner_load":
				man.grenade.visible = step in ["sponge", "load"]
		var t_show := 0.0
		if step == "fire" or step == "recoil":
			var mz := gun.global_transform * gun.muzzle_at(0.0 if step == "fire" else -1.25)
			stage.fire("cannon", mz, 7, -1, gun.global_transform.basis * gun.bore_dir(), false)
			stage.fire("pan", gun.global_transform * gun.vent_at(), 8, -1, Vector3.UP, false)
			t_show = 0.09 if step == "fire" else 1.1
		stage.step(t_show)
		title.text = names[step]
		_cam(Vector3(0.0, 0.8, 0.5), PI - 0.95, -0.3, 6.3, 44.0)
		tiles.append(await _grab())
	_save(_tile(tiles, 4), "drill")
	# The gun on its own, from both sides.
	_clear()
	var g2 := FieldCannon.new().setup(0)
	stage.add_child(g2)
	g2.position = Vector3(0, gy, 0)
	_keep(g2)
	g2.set_state(0.0, 4.0)
	var t2: Array[Image] = []
	for v: Array in [[PI - 0.7, -0.2, 4.6], [0.9, -0.25, 4.6], [PI * 0.5, -0.08, 4.4], [PI - 0.2, -0.45, 2.4]]:
		_cam(Vector3(0, 0.8, 0.5 if v[2] > 3.0 else -0.6), v[0], v[1], v[2], 42.0)
		t2.append(await _grab())
	title.text = "6-pounder: %d triangles" % g2.tri_count()
	_save(_tile(t2, 2), "cannon")


# ---------------------------------------------------------------- move sheets

func _sheet(clip_name: String, frames := 10) -> void:
	_clear()
	var role := "grenadier" if clip_name.begins_with("grenadier") else "light"
	var c: Dictionary = lib[clip_name]
	var man := _man(role, 4, Vector3.ZERO, 0.0)
	var tiles: Array[Image] = []
	var fired := false
	var tf := 0.0
	for i in frames:
		var t := float(c["len"]) * float(i) / float(frames - 1)
		man.show_clip(c, t)
		man.set_time(t)
		if not fired:
			for e: Array in c.get("events", []):
				if e[1] == "shot" and t >= float(e[0]):
					var x: Transform3D = man.global_transform * man.skel.get_bone_global_pose(B_RIFLE())
					stage.fire("musket", x * RB.MUZZLE, 5, -1, -x.basis.z.normalized(), false)
					tf = float(e[0])
					fired = true
		if fired:
			stage.step(t - tf)
		title.text = "%s  %.1f s" % [clip_name.replace("_", " "), t]
		var side := 2.4 if clip_name != "light_run" else 2.0
		_cam(Vector3(0, 0.9 if clip_name != "light_prone_fire" else 0.4, -0.2 if clip_name != "light_prone_fire" else -1.2), PI - side * 0.5, -0.12, 3.6 if clip_name != "light_prone_fire" else 5.0, 40.0)
		tiles.append(await _grab())
	_save(_tile(tiles, 5), "sheet_" + clip_name)


static func B_RIFLE() -> int:
	return preload("res://scripts/units/soldier_builder.gd").RIFLE


# ---------------------------------------------------------------- the horse

func _mounted(seed_value: int, at: Vector3, yaw_deg: float, sword: String) -> Array:
	var h := Horse.new().setup(seed_value, 0, RB.FACINGS["yellow"])
	stage.add_child(h)
	h.position = Vector3(at.x, gy, at.z)
	h.rotation.y = deg_to_rad(yaw_deg)
	_keep(h)
	var r := Redcoat.new()
	r.setup(seed_value, 0, "dragoon")
	h.att_body.add_child(r)
	r.position = Horse.seat_local() - Vector3(0, 0.86, 0)
	r.show_spec(M2.ride(sword), false)
	return [h, r]


func _horse_set() -> void:
	# The horse alone, four sides; then each gait as a sheet with its rider.
	_clear()
	var hs: Array[Horse] = []
	var coats := ["bay", "black", "chestnut"]
	for i in 3:
		var h := Horse.new().setup(i, 0, RB.FACINGS["yellow"])
		stage.add_child(h)
		h.position = Vector3(-2.6 + 2.6 * i, gy, 0)
		_keep(h)
		h.show_pose(Horse.stand_pose())
	var t0: Array[Image] = []
	for v: Array in [[PI * 0.5, -0.08], [PI - 0.6, -0.15], [0.6, -0.15], [PI, -0.1]]:
		_cam(Vector3(0, 1.1, 0), v[0], v[1], 9.0, 42.0)
		t0.append(await _grab())
	title.text = ""
	_save(_tile(t0, 2), "horses")
	for gait: String in ["walk", "trot", "gallop", "charge"]:
		_clear()
		var mr := _mounted(1, Vector3.ZERO, 0.0, M2.MOUNTED[gait])
		var h: Horse = mr[0]
		var tiles: Array[Image] = []
		var T: float = Horse.GAITS[gait]["T"]
		for i in 8:
			var t := T * float(i) / 8.0
			h.show_pose(Horse.gait_pose(gait, t))
			title.text = "%s  %d/8" % [gait, i + 1]
			_cam(Vector3(0, 1.2, 0), PI * 0.5 + 0.25, -0.06, 5.4, 42.0)
			tiles.append(await _grab())
		_save(_tile(tiles, 4), "sheet_horse_" + gait)
	# The sabre: carry, raise, cut, point; then rearing and the fall.
	_clear()
	var mr2 := _mounted(2, Vector3.ZERO, 0.0, "carry")
	var h2: Horse = mr2[0]
	var r2: Redcoat = mr2[1]
	h2.show_pose(Horse.gait_pose("trot", 0.1))
	var t3: Array[Image] = []
	for k: String in ["carry", "raise", "cut", "point"]:
		r2.show_spec(M2.ride(k), false)
		title.text = "sabre: " + k
		_cam(Vector3(0, 1.7, 0), PI - 0.7, -0.1, 4.0, 40.0)
		t3.append(await _grab())
	_save(_tile(t3, 2), "sabre")
	var t4: Array[Image] = []
	r2.show_spec(M2.ride("raise"), false)
	for u: float in [0.0, 0.5, 1.0, 1.5]:
		h2.show_pose(Horse.rear_pose(u))
		r2.show_spec(Rig.over(M2.ride("raise"), {"add": {B.SPINE: Vector3(-34.0 * sin(PI * u * 0.5), 0, 0)}}), false)
		title.text = "rearing"
		_cam(Vector3(0, 1.4, 0), PI * 0.5 + 0.3, -0.06, 6.0, 42.0)
		t4.append(await _grab())
	# The fall: the horse goes down on its side, the rider thrown forward.
	r2.get_parent().remove_child(r2)
	stage.add_child(r2)
	_keep(r2)
	var df: Dictionary = lib["officer_death_forward"]
	for u: float in [0.0, 0.3, 0.6, 1.0]:
		h2.show_pose(Horse.fall_pose(u))
		var seat := h2.global_transform * Vector3(0, 1.61, 0.02)
		var land := Vector3(0, gy, -1.9)
		var p := seat.lerp(land, u) + Vector3(0, 0.7 * sin(PI * u) - 0.86 * (1.0 - u), 0)
		r2.position = p
		r2.rotation = Vector3(-0.6 * sin(PI * u), 0, 0)
		if u < 0.05:
			r2.show_spec(M2.ride("carry"), false)
		else:
			r2.show_clip(df, float(df["len"]) * minf(u * 1.2, 1.0))
			if u >= 1.0:
				r2.position = Vector3(0, gy, -1.9)
				r2.rotation = Vector3.ZERO
		title.text = "the fall"
		_cam(Vector3(0, 0.9, -0.6), PI * 0.5 + 0.3, -0.12, 6.4, 42.0)
		t4.append(await _grab())
	_save(_tile(t4, 4), "rear_fall")
	# The rider close up (the helmet, the saddle cloth, the stirrup, the reins).
	_clear()
	var mr3 := _mounted(3, Vector3.ZERO, 0.0, "carry")
	(mr3[0] as Horse).show_pose(Horse.stand_pose())
	var t5: Array[Image] = []
	for v: Array in [[PI - 0.5, -0.1, 2.6], [0.7, -0.2, 2.6]]:
		_cam(Vector3(0, 1.75, 0), v[0], v[1], v[2], 40.0)
		t5.append(await _grab())
	title.text = "horse %d tris, dragoon %d tris" % [(mr3[0] as Horse).tri_count(), (mr3[1] as Redcoat).tri_count()]
	_save(_tile(t5, 2), "dragoon_close")


func _cavalry() -> void:
	# A troop of dragoons charging, sabres at the point, the ground thrown up behind.
	_clear()
	for i in 5:
		var mr := _mounted(10 + i, Vector3(-4.0 + 2.0 * i, 0, 0.6 * (i % 2) - 0.3 * absf(i - 2)), 0.0, "point")
		(mr[0] as Horse).show_pose(Horse.gait_pose("charge", 0.11 * i))
	_cam(Vector3(0, 1.4, 0), PI - 0.45, -0.1, 11.0, 44.0)
	title.text = "dragoons: the charge"
	_save(await _grab(), "cavalry_charge")
	_cam(Vector3(0, 1.4, 0), PI * 0.5 + 0.15, -0.05, 12.0, 42.0)
	_save(await _grab(), "cavalry_side")
