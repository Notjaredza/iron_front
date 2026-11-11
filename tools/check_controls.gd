extends SceneTree
## Iron Front: the unit controls check (headless). On a generated map it:
## 1. Unit cards: one card per selected squad, and they follow the selection; the Run/Walk switch is off while a
##    squad stands; on the move it speeds the squad up to a run and back down to a walk.
## 2. Control groups: Ctrl+number saves the selection, the number picks it again, the same number twice moves the
##    camera; a number with no group is passed on (not used up); Ctrl+number with nothing selected clears it.
## Run:  Godot --headless --path . --script res://tools/check_controls.gd
## Ends with "CONTROLS CHECK DONE <fails>".

const DT := 1.0 / 30.0
var fails := 0


func _ok(cond: bool, what: String) -> void:
	print("CHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _key(n: int, ctrl := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = KEY_1 + n - 1
	k.pressed = true
	k.ctrl_pressed = ctrl
	return k


func _run() -> void:
	var d := MapGen.generate(1, 1000, 1500)
	var nav := NavGrid.new().build(d)
	var cam := RtsCamera.new()
	root.add_child(cam)
	cam.data = d
	cam.enabled = false
	var sc := SquadControl.new()
	root.add_child(sc)
	sc.cam = cam
	var sz := d.size_m()
	sc.spawn(nav, Vector2(sz.x * 0.5, sz.y * 0.5))
	for s in sc.squads:
		s.set_process(false)
	await process_frame
	var cards := sc.cards

	# 1. Cards follow the selection.
	sc.squads[0].selected = true
	sc.squads[3].selected = true
	await process_frame
	_ok(cards.count() == 2, "two squads selected: %d cards" % cards.count())
	sc.squads[3].selected = false
	await process_frame
	_ok(cards.count() == 1, "one deselected: %d card" % cards.count())
	var s: Squad = sc.squads[0]
	cards.press_run(0, true)
	_ok(not s.running, "the switch does nothing while the squad stands")
	var goal := nav.nearest_open(s.at + Vector2(0, -300))
	_ok(s.order_move(goal), "the squad is sent 300 m away at a walk")
	await process_frame
	cards.press_run(0, true)
	var t0 := s.at
	for i in 90:
		s._step(DT)
	var v_run := s.at.distance_to(t0) / 3.0
	cards.press_run(0, false)
	t0 = s.at
	for i in 90:
		s._step(DT)
	var v_walk := s.at.distance_to(t0) / 3.0
	_ok(v_run > 3.0 and v_walk < 1.6, "Run on the card: %.1f m/s; Walk again: %.1f m/s" % [v_run, v_walk])

	# 2. Control groups.
	for q in sc.squads:
		q.selected = false
	sc.squads[1].selected = true
	sc.squads[2].selected = true
	root.push_input(_key(2, true))
	await process_frame
	_ok(sc.groups.has(2) and (sc.groups[2] as Array).size() == 2, "Ctrl+2 saves the two selected squads")
	for q in sc.squads:
		q.selected = false
	sc.squads[4].selected = true
	root.push_input(_key(2))
	await process_frame
	var sel := sc.selected()
	_ok(sel.size() == 2 and sel.has(sc.squads[1]) and sel.has(sc.squads[2]), "2 picks them again (and drops the others)")
	cam.target = Vector3.ZERO
	root.push_input(_key(2))
	await process_frame
	var mid := (sc.squads[1].at + sc.squads[2].at) * 0.5
	_ok(Vector2(cam.target.x, cam.target.z).distance_to(mid) < 1.0, "2 again quickly takes the camera to them")
	_ok(not sc.recall_group(5, 0.0), "5 has no group: the key is passed on")
	for q in sc.squads:
		q.selected = false
	root.push_input(_key(2, true))
	await process_frame
	_ok(not sc.groups.has(2), "Ctrl+2 with nothing selected clears the group")
	print("CONTROLS CHECK DONE %d" % fails)
	quit()
