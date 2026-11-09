extends RefCounted
## Iron Front buildings: the extra stills (walls, gates, defences, the base overview) for bld_pictures.gd.

const SHOTS: Array[String] = ["walls_pieces", "walls_base_day", "walls_base_night", "walls_rail_gate", "walls_cliff",
	"walls_stages", "defences_line", "defences_crews", "defences_belt_night", "base_overview_day", "base_overview_night", "build_site"]

var m: Object


func shot(main: Object, nm: String) -> void:
	m = main
	match nm:
		"walls_pieces":
			var row := [[BldWalls.N | BldWalls.S, ""], [BldWalls.N | BldWalls.E, ""], [BldWalls.N | BldWalls.E | BldWalls.S, ""],
				[15, ""], [BldWalls.S, ""], [BldWalls.N | BldWalls.S, "gate"], [BldWalls.N | BldWalls.S, "rail_gate"],
				[BldWalls.N | BldWalls.S, "tower"], [BldWalls.N | BldWalls.E, "bastion"]]
			for i in row.size():
				var w := BldWalls.make(row[i][0], row[i][1])
				m.stage.add_child(w)
				w.position = Vector3((float(i) - 4.0) * 12.0, 0, 0)
				if row[i][1] == "gate":
					BldWalls.set_gate(w, 0.7)
				if row[i][1] == "rail_gate":
					BldWalls.set_rail_gate(w, 0.6)
			m.look(Vector3(-8, 26, -58), Vector3(0, 2, 0), 55)
		"walls_base_day", "walls_base_night":
			var night: bool = nm.ends_with("night")
			if night:
				m.night()
			var cells := _base(Vector3.ZERO, night)
			_train(Vector3(36 + 8, 0, 8), PI * 0.5)
			m.run(cells, 1.0)
			m.look(Vector3(-34, 34, -40), Vector3(22, 0, 18), 50)
		"walls_rail_gate":
			for k in 2:
				var x := float(k) * 44.0 - 22.0
				var walls := {}
				for c in range(-2, 3):
					walls[Vector2i(c, 0)] = true
				var sol := BldWalls.solve(walls, {Vector2i(0, 0): BldWalls.N | BldWalls.S})
				var list := _place(sol, Vector3(x, 0, 0))
				for b: Building in list:
					if b.get_meta("variant") == "rail_gate":
						BldWalls.set_rail_gate(b, float(k))
				_rails(Vector3(x, 0, -40), Vector3(x, 0, -4))
				_rails(Vector3(x, 0, 4), Vector3(x, 0, 40))
			_train(Vector3(22, 0, -6), 0.0)
			m.look(Vector3(-6, 13, -46), Vector3(0, 3, 0), 58)
		"walls_cliff":
			var plateau := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(60, 8, 60)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.45, 0.58, 0.30)
			bm.material = mat
			plateau.mesh = bm
			plateau.position = Vector3(-34, 4, 0)
			m.stage.add_child(plateau)
			var face := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.6, 8.2, 60)
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = Color(0.40, 0.33, 0.24)
			fm.material = fmat
			face.mesh = fm
			face.position = Vector3(-4.2, 4, 0)
			m.stage.add_child(face)
			var walls := {}
			for z in range(-3, 4):
				walls[Vector2i(0, z)] = true
			var sol := BldWalls.solve(walls, {}, {Vector2i(0, 0): "tower"})
			for c: Vector2i in sol:
				var w := BldWalls.make(sol[c][0], sol[c][1], 8.0)
				m.stage.add_child(w)
				w.position = Vector3(-5.6, 8.0, float(c.y) * 8.0)
			m.look(Vector3(28, 14, -36), Vector3(-8, 6, 0), 50)
		"walls_stages":
			var list: Array = []
			for i in 7:
				var w := BldWalls.make(BldWalls.N | BldWalls.S, "tower" if i % 2 == 0 else "")
				m.stage.add_child(w)
				w.position = Vector3((3.0 - float(i)) * 10.0, 0, 0)
				list.append(w)
			await m.process_frame
			for i in 4:
				(list[i] as Building).set_stage(i)
			(list[4] as Building).set_damage(1)
			(list[5] as Building).collapse(0.45)
			(list[6] as Building).set_damage(2)
			m.run(list, 2.0)
			m.look(Vector3(0, 20, -52), Vector3(0, 2, 0), 55)
		"build_site":
			var list: Array = []
			for k in 2:
				var b := Buildings.make(["barracks", "station"][k])
				m.stage.add_child(b)
				b.position = Vector3(-11.0 + float(k) * 26.0, 0, 0)
				list.append(b)
			await m.process_frame
			(list[0] as Building).set_stage(1)
			(list[1] as Building).set_stage(2)
			m.run(list, 1.0)
			m.look(Vector3(-12, 13, -32), Vector3(4, 1, -2), 50)
		"defences_line":
			var list := _front(Vector3.ZERO, false)
			m.run(list, 1.0)
			m.look(Vector3(-30, 30, -58), Vector3(24, 0, -14), 50)
		"defences_belt_night":
			m.night()
			var list := _front(Vector3.ZERO, true)
			m.run(list, 1.0)
			m.look(Vector3(-30, 30, -58), Vector3(24, 0, -14), 50)
		"defences_crews":
			var list: Array = []
			for k in 4:
				var kind := "mg_nest" if k < 2 else "gun_pit"
				var b := Buildings.make(kind)
				m.stage.add_child(b)
				b.position = Vector3([-15.0, -5.0, 6.0, 24.0][k], 0, 0)
				if k % 2 == 1:
					BldDefences.set_crew(b, false)
				list.append(b)
			await m.process_frame
			m.run(list, 1.0)
			m.look(Vector3(-6, 22, -26), Vector3(4, 0, 0), 50)
		"base_overview_day", "base_overview_night":
			var night: bool = nm.ends_with("night")
			if night:
				m.night()
			var list := _base(Vector3.ZERO, night)
			list.append_array(_front(Vector3.ZERO, night))
			for e: Array in [["barracks", Vector3(34, 0, 30), PI * 0.5], ["lamp_tower", Vector3(-8, 0, 6), 0.0],
					["telegraph", Vector3(-8, 0, 18), 0.0], ["pigeon_loft", Vector3(-8, 0, 30), 0.0],
					["wreck_yard", Vector3(-30, 0, 22), 0.0], ["lab_comms", Vector3(-30, 0, 46), 0.0],
					["station", Vector3(72, 0, 10.6), 0.0], ["water_tower", Vector3(92, 0, 13.2), 0.0],
					["signal_box", Vector3(58, 0, 13.1), 0.0], ["coal_stage", Vector3(100, 0, 18.6), PI],
					["lab_weapons", Vector3(14, 0, 56), 0.0], ["lab_rail", Vector3(64, 0, 34), PI]]:
				var b := Buildings.make(e[0])
				m.stage.add_child(b)
				b.position = e[1]
				b.rotation.y = e[2]
				b.set_lights(night)
				list.append(b)
			_train(Vector3(78, 0, 16), PI * 0.5)
			await m.process_frame
			m.run(list, 1.5)
			m.look(Vector3(-58, 70, -86), Vector3(26, 0, 14), 52)


## A walled compound: 7 x 6 cells, a tower and a bastion on two corners, towers half way, a road gate on
## the south side, a track crossing the east side (so the rail gate is placed by itself), and a spur wall
## inside making a T.
func _base(at: Vector3, night: bool) -> Array:
	var walls := {}
	for x in range(0, 7):
		walls[Vector2i(x, 0)] = true
		walls[Vector2i(x, 5)] = true
	for z in range(0, 6):
		walls[Vector2i(0, z)] = true
		walls[Vector2i(6, z)] = true
	for z in range(1, 3):
		walls[Vector2i(3, z)] = true
	var chosen := {Vector2i(0, 0): "bastion", Vector2i(6, 5): "bastion", Vector2i(6, 0): "tower", Vector2i(0, 5): "tower",
		Vector2i(3, 0): "tower", Vector2i(3, 5): "gate"}
	var tracks := {Vector2i(6, 2): BldWalls.E | BldWalls.W}
	var sol := BldWalls.solve(walls, tracks, chosen)
	var list := _place(sol, at)
	for b: Building in list:
		b.set_lights(night)
		if b.get_meta("variant") == "rail_gate":
			BldWalls.set_rail_gate(b, 1.0)
		if b.get_meta("variant") == "gate":
			BldWalls.set_gate(b, 0.0)
	_rails(at + Vector3(10, 0, 16), at + Vector3(44, 0, 16))
	_rails(at + Vector3(52, 0, 16), at + Vector3(100, 0, 16))
	# a few buildings inside
	var hq := Buildings.make("hq")
	m.stage.add_child(hq)
	hq.position = at + Vector3(14, 0, 28)
	hq.set_lights(night)
	list.append(hq)
	var dep := Buildings.make("depot")
	m.stage.add_child(dep)
	dep.position = at + Vector3(36, 0, 10)
	dep.rotation.y = PI
	dep.set_lights(night)
	list.append(dep)
	return list


func _place(sol: Dictionary, at: Vector3) -> Array:
	var list: Array = []
	for c: Vector2i in sol:
		var v: String = sol[c][1]
		var w := BldWalls.make(sol[c][0], "" if v == "blocked" else v)
		m.stage.add_child(w)
		w.position = at + Vector3(float(c.x) * 8.0, 0, float(c.y) * 8.0)
		list.append(w)
	return list


func _rails(a: Vector3, b: Vector3) -> void:
	var g := BGeo.new()
	BldParts.track(g, a, b)
	var tg := TrainGeo.new()
	g.replay(tg, "full")
	var holder := Node3D.new()
	m.stage.add_child(holder)
	tg.make(holder, "Rails", BldParts.material())


func _train(at: Vector3, yaw: float) -> void:
	var z := 0.0
	for k: String in ["engine", "tender", "van"]:
		var car := TrainParts.make(k)
		m.stage.add_child(car)
		car.rotation.y = yaw
		var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
		car.position = at + Vector3(0, 0.37, 0) + fwd * (z + car.length() * 0.5)
		z += car.length() + 0.6


## A front line north of the base: a sandbag line dragged along with bent ends, two MG nests in it, a gun
## pit behind the west end, and a belt of wire, coils, hedgehogs and teeth out in front.
func _front(at: Vector3, night: bool) -> Array:
	var list: Array = []
	var cells := {}
	for x in range(-1, 8):
		cells[Vector2i(x, -2)] = true
	cells[Vector2i(-1, -1)] = true
	cells[Vector2i(7, -1)] = true
	var sol := BldWalls.solve(cells)
	for c: Vector2i in sol:
		if c == Vector2i(1, -2) or c == Vector2i(5, -2):
			continue
		var b := BldDefences.line(sol[c][0])
		m.stage.add_child(b)
		b.position = at + Vector3(float(c.x) * 8.0, 0, float(c.y) * 8.0)
		list.append(b)
	for x: int in [1, 5]:
		var nest := Buildings.make("mg_nest")
		m.stage.add_child(nest)
		nest.position = at + Vector3(float(x) * 8.0, 0, -16.0)
		list.append(nest)
	var pit := Buildings.make("gun_pit")
	m.stage.add_child(pit)
	pit.position = at + Vector3(-16, 0, -4)
	list.append(pit)
	for x in range(-1, 8):
		var kinds := ["wire_belt", "concertina"]
		var k1: String = kinds[x & 1]
		for row in 2:
			var kind := k1 if row == 0 else ("teeth" if x % 3 != 0 else "hedgehogs")
			var b := Buildings.make(kind)
			m.stage.add_child(b)
			b.position = at + Vector3(float(x) * 8.0, 0, -28.0 - float(row) * 8.0)
			list.append(b)
	for b: Building in list:
		b.set_lights(night)
	return list
