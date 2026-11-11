class_name CombatControl
extends Node3D
## Iron Front: fighting (fighting round). It runs every squad's fighting, ours and the enemy's:
## - Shooting: a squad with a gun (rifles, red coats, archers) fires at the nearest enemy squad in range, or at the
##   one the player told it to attack, while it stands. Each man aims at one man of that squad and plays his fire
##   clip (and his reload); when the shot leaves, it hits or misses. The chance falls with range, and with the
##   target's cover: behind sandbags, walls, MG nests and gun pits much less, in woods and tall grass less, lying
##   down (pinned) less, inside a post least of all. A pinned shooter hits less, a running target is hit less.
## - Pinned: every shot at a squad (hit or not) adds to its suppression, which wears off by itself. Past 1 it is
##   pinned: it stops, its men go prone (red coats and engineers kneel), and it shoots worse. Below 0.35 it is free.
##   Medieval men, archers and zombies are never pinned.
## - Hand to hand: men within reach of an enemy man go for him and strike (bayonets, swords, spears, claws); a
##   blow kills by the kind's chance. Zombies take two hits, the brute four.
## - Enemy behaviour, each kind on its own:
##     red coats  march up in line, halt at musket range and fire a volley, then fix bayonets and charge through
##                the smoke (at once if we come close)
##     medieval   march up, then run in and fight hand to hand
##     archers    march to bow range, halt and shoot
##     zombies    straight at the nearest men; runners run, the brute charges the last 30 m
## - Posts: a rifle squad right-clicked onto a finished MG nest or gun pit mans it (its men go inside, the post's
##   own crew shows). The MG fires bursts with tracers at the nearest enemy in 220 m; the gun pit fires a shell
##   every 7 s at enemies 70-500 m away. A move order brings the squad out again.
## - Test keys: J a red coat company, K a medieval host (two foot bands and archers), L a zombie horde, all 280 m
##   north of the camera's spot, coming for the nearest of our squads.
## The fallen stay where they fell for two minutes.

const THINK := 0.25                            # seconds between brain ticks
const SUPP_DECAY := 0.3
const PIN_AT := 1.0
const FREE_AT := 0.35
const CORPSE_S := 120.0
const SPAWN_AHEAD := 280.0
const MG_RANGE := 220.0
const MG_RATE := 8.0                           # rounds a second
const MG_ACC := 0.12                           # chance a round hits a man in the open at close range
const GUN_RANGE := 500.0
const GUN_MIN := 70.0
const GUN_EVERY := 7.0

var nav: NavGrid
var data: MapData
var cam: RtsCamera
var squads: SquadControl
var build: BuildControl
var blasts: MapBlasts
var enemies: Array[Squad] = []
var fx: AirFx
var corpses: Node3D
var t := 0.0
var note := ""
var _note_t := 0.0
var _think_t := 0.0
var _pending: Array[Dictionary] = []           # shots and blows on their way: {"t", "kind", ...}
var _dead: Array = []                          # [body, time it fell]
var _posts := {}                               # BuildSite -> {"crew": Squad, "next": time}
var _seed := 500
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	fx = AirFx.make()
	fx.blasts = false
	add_child(fx)
	corpses = Node3D.new()
	corpses.name = "Fallen"
	add_child(corpses)
	rng.seed = 77


## A new map: no enemies, no bodies.
func reset(nav_grid: NavGrid, map_data: MapData) -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for c in corpses.get_children():
		c.queue_free()
	_dead.clear()
	_pending.clear()
	_posts.clear()
	nav = nav_grid
	data = map_data


func ours() -> Array[Squad]:
	return squads.squads if squads != null else ([] as Array[Squad])


func foes_of(s: Squad) -> Array[Squad]:
	return enemies if s.side == 0 else ours()


# ------------------------------------------------------------------ spawning

## Where a wave starts: `ahead` metres north of `near`, or round to the north-east or north-west if from there the
## walk in would be a long way round (a cliff or a river in between): the route must be under 1.6 times the
## straight line.
func spawn_point(near: Vector2, ahead: float) -> Vector2:
	var best := nav.nearest_open(near + Vector2(0, -ahead))
	var best_ratio := INF
	for a: float in [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05]:
		var p := nav.nearest_open(near + Vector2(0, -ahead).rotated(a))
		var ratio := route_ratio(p, near)
		if ratio < 1.6:
			return p
		if ratio < best_ratio:
			best_ratio = ratio
			best = p
	return best


## How much longer the walk from a to b is than the straight line (INF if there is no way).
func route_ratio(a: Vector2, b: Vector2) -> float:
	var route := nav.find_path(a, b)
	if route.is_empty():
		return INF
	var L := 0.0
	var prev := a
	for q in route:
		L += prev.distance_to(q)
		prev = q
	return L / maxf(a.distance_to(b), 1.0)


## A wave of one enemy kind, about `ahead` metres north of `near`. Returns its squads.
func spawn(what: String, near: Vector2, ahead := SPAWN_AHEAD) -> Array[Squad]:
	var made: Array[Squad] = []
	var c := spawn_point(near, ahead)
	var plan: Array = []                       # [kind, men, sub, title, offset]
	match what:
		"redcoats":
			plan = [["redcoats", 12, "", "Red coats 1", Vector2(-16, 0)], ["redcoats", 12, "", "Red coats 2", Vector2(16, 0)]]
		"medieval":
			plan = [["medieval", 12, "", "Host foot 1", Vector2(-18, 0)], ["medieval", 12, "", "Host foot 2", Vector2(18, 0)],
				["archers", 9, "", "Host archers", Vector2(0, -30)]]
		"zombies":
			plan = [["zombies", 14, "shambler", "Shamblers 1", Vector2(-22, 0)], ["zombies", 14, "shambler", "Shamblers 2", Vector2(22, 0)],
				["zombies", 12, "shambler", "Shamblers 3", Vector2(0, -16)], ["zombies", 8, "runner", "Runners", Vector2(0, -30)],
				["zombies", 3, "brute", "Brutes", Vector2(0, -45)]]
	for p: Array in plan:
		var e := Squad.new()
		add_child(e)
		_seed += 1
		var where := nav.nearest_open(c + (p[4] as Vector2))
		if route_ratio(where, near) > 1.6:
			where = c                          # its own spot is over a cliff or a stream: start with the rest
		e.setup(nav, where, Vector2(0, 1), _seed, p[3], p[0], p[1], p[2], _seed % 6)
		enemies.append(e)
		made.append(e)
	say("%s coming from the north" % {"redcoats": "Red coats", "medieval": "The medieval host", "zombies": "Zombies"}[what])
	return made


# ------------------------------------------------------------------ every frame

func _process(dt: float) -> void:
	if nav == null:
		return
	step(dt)


## One step of all the fighting (also called by the headless check, with the squads stepped by hand).
func step(dt: float) -> void:
	t += dt
	fx.step(dt)
	_think_t -= dt
	if _think_t <= 0.0:
		_think_t = THINK
		_brains()
		_targets()
	_melee()
	_shoot()
	_run_posts(dt)
	_resolve()
	_suppression(dt)
	_tidy()
	_note_t -= dt
	if _note_t <= 0.0:
		note = ""


# ------------------------------------------------------------------ who fights whom

func _nearest_foe(s: Squad, max_d := INF) -> Squad:
	var best: Squad = null
	var best_d := max_d
	var c := s.center()
	for f in foes_of(s):
		if f.men.is_empty():
			continue
		var d := c.distance_to(f.center())
		if d < best_d:
			best_d = d
			best = f
	return best


func _alive(s: Variant) -> bool:
	return s != null and is_instance_valid(s) and not (s as Squad).men.is_empty()


## Picks each shooting squad's target: the one it was told to attack, else the nearest foe in range.
func _targets() -> void:
	for s in ours() + enemies:
		if not s.can_fire() or s.in_post:
			s.target = null
			continue
		var rng_m := float(s.spec["range"])
		if _alive(s.attack):
			s.target = s.attack
			var d := s.center().distance_to(s.attack.center())
			if d > rng_m * 0.95 and not s.moving() and s.side == 0:
				# Close in to 80% of range along the line, then fire.
				var to := s.attack.center() + (s.center() - s.attack.center()).normalized() * rng_m * 0.8
				s.order_move(nav.nearest_open(to))
			continue
		s.attack = null
		s.target = _nearest_foe(s, rng_m)
		s.aim_at = s.target.center() if s.target != null else null


## The enemy brains, each kind its own way.
func _brains() -> void:
	for e in enemies:
		if e.men.is_empty():
			continue
		var foe := _nearest_foe(e)
		if foe == null:
			e.path.clear()
			continue
		var fc := foe.center()
		var d := e.center().distance_to(fc)
		e.aim_at = fc
		# A new route only when it has stopped, or the foe has moved well away from where it was going (re-routing
		# all the time makes a squad shuffle on the spot round obstacles).
		var gone: Variant = e.get_meta("goal_foe", null)
		var reorder := not e.moving() or gone == null or (gone as Vector2).distance_to(fc) > 15.0
		match e.kind:
			"redcoats":
				if e.mode == "charge" or d < 30.0 or e.volleys >= 1:
					e.mode = "charge"
					if e.melee_on:
						e.path.clear()
					elif reorder:
						_go(e, fc, true)
				elif d > float(e.spec["range"]) * 0.85:
					e.mode = "march"
					if reorder:
						_go(e, fc + (e.center() - fc).normalized() * float(e.spec["range"]) * 0.7, false)
				else:
					e.mode = "halt"
					if e.moving():
						e.path.clear()
						e.heading = (fc - e.at).normalized()
			"archers":
				if d > float(e.spec["range"]) * 0.9:
					if reorder:
						_go(e, fc + (e.center() - fc).normalized() * float(e.spec["range"]) * 0.75, false)
				elif e.moving():
					e.path.clear()
					e.heading = (fc - e.at).normalized()
			"medieval", "zombies":
				var run := d < 60.0 if e.kind == "medieval" else (e.sub == "runner" or (e.sub == "brute" and d < 30.0))
				if e.melee_on:
					e.path.clear()
				elif reorder or run != e.running:
					_go(e, fc, run)


func _go(e: Squad, to: Vector2, run: bool) -> void:
	e.think_t = t
	var foe := _nearest_foe(e)
	e.set_meta("goal_foe", foe.center() if foe != null else to)
	if not e.order_move(nav.nearest_open(to), run):
		e.path.clear()


# ------------------------------------------------------------------ shooting

func _shoot() -> void:
	for s in ours() + enemies:
		if not s.can_fire() or s.in_post or s.melee_on or s.moving() or not _alive(s.target):
			continue
		var rng_m := float(s.spec["range"])
		var tgt: Squad = s.target
		var fired := 0
		for i in s.men.size():
			if s.acting(i) or s.clock < float(s.md[i]["next_shot"]) or not s.has_clip(i, "fire"):
				continue
			var p := s.mpos[i]
			var j := _pick_man(tgt, p, rng_m + 10.0)
			if j < 0:
				continue
			var what := "fire_pinned" if s.pinned and s.has_clip(i, "fire_pinned") else "fire"
			var when := s.hit_moment(i, what)
			var L := s.act(i, what)
			s.md[i]["shots"] = int(s.md[i]["shots"]) + 1
			var reload := 0.0
			if int(s.md[i]["shots"]) % int(s.spec["reload_every"]) == 0 and s.has_clip(i, "reload"):
				reload = s.clip_len(s.clip_for(i, "reload_pinned" if s.pinned and s.has_clip(i, "reload_pinned") else "reload"))
			var w: Array = s.spec["wait"]
			s.md[i]["next_shot"] = s.clock + L + reload + rng.randf_range(float(w[0]), float(w[1]))
			if reload > 0.0:
				s.md[i]["reload_at"] = s.clock + L
			var flight := 1.1 if s.kind == "archers" else 0.0
			_pending.append({"t": t + when + flight, "kind": "shot", "from": s, "man": s.men[i], "to": tgt, "victim": tgt.men[j],
				"fx_t": t + when})
			fired += 1
		if fired > 0 and s.kind == "redcoats":
			# volleys fired: the musketeers' shots, on average
			var shots := 0
			var guns := 0
			for k in s.men.size():
				if s.has_clip(k, "fire"):
					guns += 1
					shots += int(s.md[k]["shots"])
			s.volleys = shots / maxi(guns, 1)
		# start the reload clips whose fire clip has ended
		for i in s.men.size():
			if s.md[i].has("reload_at") and s.clock >= float(s.md[i]["reload_at"]):
				s.md[i].erase("reload_at")
				s.act(i, "reload_pinned" if s.pinned and s.has_clip(i, "reload_pinned") else "reload")


## A man of squad tgt for a shooter at p to aim at (the nearest few, picked at random), or -1.
func _pick_man(tgt: Squad, p: Vector2, max_d: float) -> int:
	var near: Array[int] = []
	for j in tgt.men.size():
		if tgt.mpos[j].distance_to(p) <= max_d:
			near.append(j)
	if near.is_empty():
		return -1
	return near[rng.randi() % near.size()]


## How much a man at p of squad s is covered: 1 in the open, lower behind things.
func cover_at(s: Squad, p: Vector2) -> float:
	if s.in_post:
		return 0.15
	var c := 1.0
	var cell := nav.cell_of(p)
	if build != null:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var site: Variant = build.at_cell.get(cell + Vector2i(dx, dz), null)
				if site != null and (site as BuildSite).done and ((site as BuildSite).family != "" or (site as BuildSite).kind in ["mg_nest", "gun_pit"]):
					c = minf(c, 0.35)
	var i := cell.y * data.w + cell.x
	if (data.feat[i] & (MapData.F_WOOD | MapData.F_TALL | MapData.F_HEDGE)) != 0:
		c = minf(c, 0.6)
	if s.pinned:
		c *= 0.5
	return c


func hit_chance(from: Squad, to: Squad, d: float, at: Vector2) -> float:
	var r := float(from.spec["range"])
	var fall := clampf(1.0 - 0.75 * clampf((d / r - 0.25) / 0.75, 0.0, 1.0), 0.25, 1.0)
	var p := float(from.spec["acc"]) * fall * cover_at(to, at)
	if from.pinned:
		p *= 0.4
	if to.moving() and to.running:
		p *= 0.6                               # a running man is harder to hit
	return p


func _resolve() -> void:
	var keep: Array[Dictionary] = []
	for e in _pending:
		if e.has("fx_t") and t >= float(e["fx_t"]):
			_muzzle(e)
			e.erase("fx_t")
		if t < float(e["t"]):
			keep.append(e)
			continue
		match e["kind"]:
			"shot":
				var to: Squad = e["to"]
				var from: Squad = e["from"]
				if not is_instance_valid(to) or not is_instance_valid(from):
					continue
				to.supp += float(from.spec["supp"])
				var j := to.index_of(e["victim"])
				if j < 0:
					continue
				var d := from.center().distance_to(to.mpos[j])
				if rng.randf() < hit_chance(from, to, d, to.mpos[j]):
					to.supp += 0.12
					wound(to, j)
			"blow":
				var to2: Squad = e["to"]
				var from2: Squad = e["from"]
				if not is_instance_valid(to2) or not is_instance_valid(from2) or from2.index_of(e["man"]) < 0:
					continue
				var j2 := to2.index_of(e["victim"])
				var i2 := from2.index_of(e["man"])
				if j2 < 0 or to2.mpos[j2].distance_to(from2.mpos[i2]) > 2.4:
					continue
				if rng.randf() < float(from2.spec["melee"]):
					wound(to2, j2)
	_pending = keep


## The flash and smoke of a shot leaving the muzzle (arrows and bolts leave none).
func _muzzle(e: Dictionary) -> void:
	var from: Squad = e["from"]
	if not is_instance_valid(from) or from.kind == "archers":
		return
	var m: Soldier = e["man"]
	if not is_instance_valid(m) or from.index_of(m) < 0:
		return
	var fwd := -m.global_transform.basis.z
	var h := 0.45 if from.pinned and from.kind == "rifles" else (1.0 if from.pinned else 1.45)
	var at := m.global_position + Vector3(0, h, 0) + fwd * 0.9
	if from.kind == "redcoats" and blasts != null:
		var b := Blast.new()
		blasts.add_child(b)
		_seed += 1
		b.setup("musket", at, _seed, Blast.Style.FACET, fwd)
	else:
		fx.glow.add("spark", at, fwd * 6.0, 0.5)
		fx.trail(at, fwd * 1.5 + Vector3(0, 0.4, 0), 0.35)


## A man is hit: one hit fewer to go; at none he falls.
func wound(s: Squad, j: int) -> void:
	s.md[j]["hp"] = int(s.md[j]["hp"]) - 1
	if int(s.md[j]["hp"]) > 0:
		s.act(j, "hit")
		return
	var body := s.kill(j, corpses)
	_dead.append([body, t])


# ------------------------------------------------------------------ hand to hand

func _melee() -> void:
	for s in ours() + enemies:
		var reach := float(s.spec["reach"])
		var any := false
		var foes := foes_of(s)
		for i in s.men.size():
			if s.in_post or (s.side == 0 and s.moving()):
				s.md[i]["goal"] = null             # ours can walk away from a fight when ordered
				continue
			var p := s.mpos[i]
			var best: Squad = null
			var bj := -1
			var bd := reach
			for f in foes:
				if f.men.is_empty() or f.center().distance_to(p) > reach + 40.0:
					continue
				for j in f.men.size():
					var d := f.mpos[j].distance_to(p)
					if d < bd:
						bd = d
						best = f
						bj = j
			if best == null:
				s.md[i]["goal"] = null
				continue
			any = true
			var fp := best.mpos[bj]
			var away := (p - fp).normalized() if p.distance_to(fp) > 0.05 else Vector2(1, 0)
			s.md[i]["goal"] = fp + away * 1.1
			if bd <= 1.8 and not s.acting(i) and s.has_clip(i, "melee"):
				var when := s.hit_moment(i, "melee")
				s.act(i, "melee")
				_pending.append({"t": t + when, "kind": "blow", "from": s, "man": s.men[i], "to": best, "victim": best.men[bj]})
		s.melee_on = any
		if any and s.moving() and s.side == 1:
			s.path.clear()


# ------------------------------------------------------------------ pinned

func _suppression(dt: float) -> void:
	for s in ours() + enemies:
		s.supp = maxf(0.0, s.supp - SUPP_DECAY * dt)
		if String(s.spec["pin"]).is_empty() or s.in_post:
			s.supp = minf(s.supp, 0.9)
			s.pinned = false
			continue
		if not s.pinned and s.supp > PIN_AT:
			s.pinned = true
			for i in s.men.size():
				if s.has_clip(i, "pin_to") and not s.acting(i):
					s.act(i, "pin_to")
		elif s.pinned and s.supp < FREE_AT:
			s.pinned = false


# ------------------------------------------------------------------ posts

## Sends a squad to man a finished MG nest or gun pit.
func man_post(s: Squad, site: BuildSite) -> void:
	if not site.done or not (site.kind in ["mg_nest", "gun_pit"]) or not s.can_fire() or s.side != 0:
		return
	for k: BuildSite in _posts.keys():
		if (_posts[k] as Dictionary)["crew"] == s:
			_leave_post(k)
	if _posts.has(site):
		say("The %s is already manned" % BuildControl.NAMES[site.kind])
		return
	s.cancel_job()
	s.post = site
	s.order_move(site.approach(nav))


func _leave_post(site: BuildSite) -> void:
	var p: Dictionary = _posts[site]
	var s: Squad = p["crew"]
	_posts.erase(site)
	if site.node:
		BldDefences.set_crew(site.node, false)
	if is_instance_valid(s):
		s.in_post = false


func _run_posts(dt: float) -> void:
	# arrivals
	for s in ours():
		if s.post != null and not s.in_post and not s.moving():
			var site: BuildSite = s.post
			if not build.sites.has(site) or not site.done:
				s.post = null
			elif s.at.distance_to(site.approach(nav)) < 8.0:
				s.in_post = true
				_posts[site] = {"crew": s, "next": t + 1.0, "acc": 0.0}
				BldDefences.set_crew(site.node, true)
	for site: BuildSite in _posts.keys():
		var p: Dictionary = _posts[site]
		var s: Squad = p["crew"]
		if not is_instance_valid(s) or s.men.is_empty() or s.post != site or not build.sites.has(site) or not site.done:
			_leave_post(site)
			continue
		var c := site.center()
		var best: Squad = null
		var bd := MG_RANGE if site.kind == "mg_nest" else GUN_RANGE
		for e in enemies:
			if e.men.is_empty():
				continue
			var d := c.distance_to(e.center())
			if d < bd and (site.kind == "mg_nest" or d > GUN_MIN):
				bd = d
				best = e
		if best == null:
			continue
		if site.kind == "mg_nest":
			p["acc"] = float(p["acc"]) + dt * MG_RATE
			while float(p["acc"]) >= 1.0:
				p["acc"] = float(p["acc"]) - 1.0
				var j := _pick_man(best, c, MG_RANGE + 10.0)
				if j < 0:
					break
				var from := Vector3(c.x, site.y + 1.3, c.y)
				var aim := Vector3(best.mpos[j].x, nav.height(best.mpos[j]) + 1.0, best.mpos[j].y)
				fx.shoot(from, (aim - from).normalized(), Vector3.ZERO, 0.012)
				best.supp += 0.05
				var r := clampf(1.0 - 0.6 * clampf((bd / MG_RANGE - 0.3) / 0.7, 0.0, 1.0), 0.4, 1.0)
				if rng.randf() < MG_ACC * r * cover_at(best, best.mpos[j]):
					best.supp += 0.1
					wound(best, j)
		elif t >= float(p["next"]):
			p["next"] = t + GUN_EVERY
			var aim2 := best.center() + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 10.0
			shell(aim2)


## A shell bursts at p: men near it fall, and everyone round about is shaken.
func shell(p: Vector2) -> void:
	if blasts != null:
		blasts.fire(3, p.x, p.y)
	for s in ours() + enemies:
		if s.men.is_empty() or s.center().distance_to(p) > 40.0:
			continue
		var j := s.men.size() - 1
		while j >= 0:
			var d := s.mpos[j].distance_to(p)
			var kill_p := 0.8 if d < 5.0 else (0.3 if d < 12.0 else 0.0)
			if rng.randf() < kill_p * (0.4 if cover_at(s, s.mpos[j]) < 0.5 else 1.0):
				s.md[j]["hp"] = 1                  # a shell kills outright, brute or not
				wound(s, j)
			j -= 1
		if s.center().distance_to(p) < 25.0:
			s.supp += 1.2


# ------------------------------------------------------------------ tidying up

func _tidy() -> void:
	while not _dead.is_empty() and t - float(_dead[0][1]) > CORPSE_S:
		var b: Node = _dead.pop_front()[0]
		if is_instance_valid(b):
			b.queue_free()
	for e in enemies.duplicate():
		if e.men.is_empty():
			enemies.erase(e)
			e.queue_free()
	if squads != null:
		for s in squads.squads.duplicate():
			if s.men.is_empty():
				squads.squads.erase(s)
				s.queue_free()


## The enemy squad with a man near p (within 6 m), for attack orders.
func enemy_at(p: Vector2) -> Squad:
	for e in enemies:
		for q in e.mpos:
			if q.distance_to(p) < 6.0:
				return e
	return null


func say(text: String) -> void:
	note = text
	_note_t = 3.0


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or nav == null or cam == null:
		return
	var what: String = {KEY_J: "redcoats", KEY_K: "medieval", KEY_L: "zombies"}.get(k.keycode, "")
	if what.is_empty():
		return
	spawn(what, Vector2(cam.target.x, cam.target.z))
	get_viewport().set_input_as_handled()


func help() -> String:
	var n := 0
	for e in enemies:
		n += e.men.size()
	return "J red coats, K medieval host, L zombies (from the north); right click an enemy to attack, a finished MG nest or gun pit to man it   [%d enemies]%s" % [
		n, ("   " + note) if not note.is_empty() else ""]
