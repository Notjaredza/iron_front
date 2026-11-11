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
##     red coats  march up in line, halt at about 60 m and fire a volley, then fix bayonets and charge through
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
## Fighting round 2:
## - Ammo: each man carries his rounds (rifles 50); out of them he only fights hand to hand. Ours fill up again near
##   a finished depot or HQ (within 35 m). MG nests (1200 rounds) and gun pits (30 shells) refill if a finished
##   depot is within 200 m. The enemy's do not refill.
## - Wounded: about a third of our men who would have died are wounded instead. They lie a while, then get up and
##   walk to the nearest finished HQ or barracks (the aid posts), recover there, and top up a squad of their kind
##   that comes within 40 m of it.
## - Garrisons: right click a village house or ruin, or one of our finished HQ, barracks, depot, station and so on,
##   and a rifle squad goes inside and fires from it with heavy cover (a ruin's broken walls cover less).
## - Line of sight: higher ground between two squads, or thick woods, blocks seeing and shooting. Higher up a squad
##   sees and shoots further (15% for each level above, and from inside a building).
## - Fog of war: enemies are hidden until one of ours sees them (260 m by day, less at night and in fog; finished
##   buildings see 150 m round them). A firing enemy gives himself away within 400 m.
## Comms round: squads near the officer hit more and are pinned less (CommsControl.STEADY, CALM); when the officer
## himself is hit CommsControl decides (wounded first, then dead); shells cut telegraph wire; a wave whose last man
## falls counts as beaten off.

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
const RESUPPLY_R := 35.0                       # metres from a finished depot or HQ for a squad to fill up
const RESUPPLY_RATE := 8.0                     # rounds a man gets a second
const POST_SUPPLY_R := 200.0
const MG_AMMO := 1200
const GUN_AMMO := 30
const AID_R := 40.0
const DOWN_S := 12.0                           # a wounded man lies this long before he gets up
const HEAL_S := 40.0                           # and recovers this long at the aid post
const SIGHT := 260.0
const BUILD_SIGHT := 150.0
const REVEAL_S := 4.0
const REVEAL_R := 400.0
const AID_KINDS := ["hq", "barracks"]

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
var view: MapView                              # for day, night and fog
var garrisons: Array[Garrison] = []            # the map's houses and ruins
var _site_garrisons := {}                      # BuildSite -> Garrison (our own buildings)
var seen := {}                                 # enemy Squad -> true while one of ours can see it
var _fired := {}                               # enemy Squad -> when it last fired
var wounded: Array[Dictionary] = []            # {"body", "kind", "t", "state" ("down", "walk"), "path", "aid"}
var aid := {}                                  # BuildSite -> Array of [kind, time he is fit again]
var _sight_t := 0.0
var stats := {"shots": [0, 0], "hits": [0, 0], "blows": [0, 0], "kills": [0, 0], "wounded": 0, "dead": [0, 0]}   # by the side that did it ("dead": by the side that fell)
var comms: Node                                # the CommsControl (the officer, wire), if there is one
var _waves := {}                               # wave number -> enemy squads still standing
var _wave_n := 0


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
	for w in wounded:
		if is_instance_valid(w["body"]):
			(w["body"] as Node).queue_free()
	wounded.clear()
	aid.clear()
	seen.clear()
	_fired.clear()
	_site_garrisons.clear()
	_waves.clear()
	set_meta("waves_beaten", 0)
	stats["dead"] = [0, 0]
	nav = nav_grid
	data = map_data
	garrisons = Garrison.from_map(map_data)


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
	_wave_n += 1
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
		e.set_meta("wave", _wave_n)
		_waves[_wave_n] = int(_waves.get(_wave_n, 0)) + 1
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
	_sight_t -= dt
	if _sight_t <= 0.0:
		_sight_t = 0.5
		_fog()
	_melee()
	_shoot()
	_run_posts(dt)
	_resolve()
	_suppression(dt)
	_resupply(dt)
	_run_wounded(dt)
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
		if not s.can_fire() or (s.in_post and not s.post is Garrison):
			s.target = null
			continue
		var rng_m := float(s.spec["range"])
		if _alive(s.attack):
			s.target = s.attack if can_shoot(s, s.attack) else null
			var d := s.center().distance_to(s.attack.center())
			if s.target == null and not s.moving() and s.side == 0 and not s.in_post and d <= rng_m * 0.95:
				s.order_move(nav.nearest_open(s.attack.center() + (s.center() - s.attack.center()).normalized() * rng_m * 0.5))
			if d > rng_m * 0.95 and not s.moving() and s.side == 0 and not s.in_post:
				# Close in to 80% of range along the line, then fire.
				var to := s.attack.center() + (s.center() - s.attack.center()).normalized() * rng_m * 0.8
				s.order_move(nav.nearest_open(to))
			continue
		s.attack = null
		s.target = null
		var best_d := INF
		for f in foes_of(s):
			if f.men.is_empty():
				continue
			var d2 := s.center().distance_to(f.center())
			if d2 < best_d and can_shoot(s, f):
				best_d = d2
				s.target = f
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
		var gone: Variant = e.get_meta("goal_foe") if e.has_meta("goal_foe") else null
		var reorder := not e.moving() or gone == null or (gone as Vector2).distance_to(fc) > 15.0
		match e.kind:
			"redcoats":
				if e.mode == "charge" or d < 30.0 or e.volleys >= 1:
					e.mode = "charge"
					if e.melee_on:
						e.path.clear()
					elif reorder:
						_go(e, fc, true)
				elif d > float(e.spec["range"]) * 0.7:
					e.mode = "march"                   # close to about 60 m before the volley
					if reorder:
						_go(e, fc + (e.center() - fc).normalized() * float(e.spec["range"]) * 0.6, false)
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
		if not s.can_fire() or (s.in_post and not s.post is Garrison) or s.melee_on or s.moving() or not _alive(s.target):
			continue
		var rng_m := eff_range(s, s.target)
		var uses_ammo := int(s.spec.get("ammo", 0)) > 0
		var tgt: Squad = s.target
		var fired := 0
		for i in s.men.size():
			if s.acting(i) or s.clock < float(s.md[i]["next_shot"]) or not s.has_clip(i, "fire"):
				continue
			if uses_ammo and int(s.md[i].get("ammo", 0)) <= 0:
				continue
			var p := s.mpos[i]
			var j := _pick_man(tgt, p, rng_m + 10.0)
			if j < 0:
				continue
			var what := "fire_pinned" if s.pinned and s.has_clip(i, "fire_pinned") else "fire"
			var when := s.hit_moment(i, what)
			var L := s.act(i, what)
			s.md[i]["shots"] = int(s.md[i]["shots"]) + 1
			if uses_ammo:
				s.md[i]["ammo"] = int(s.md[i]["ammo"]) - 1
			if s.side == 1:
				_fired[s] = t
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
		return (s.post as Garrison).cover() if s.post is Garrison else 0.15
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
	if comms != null and from.side == 0 and comms.near_officer(from):
		p *= CommsControl.STEADY               # steadier fire near the officer
	return p


## Suppression taken near the officer is less.
func _calm(s: Squad) -> float:
	return CommsControl.CALM if comms != null and comms.near_officer(s) else 1.0


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
				to.supp += float(from.spec["supp"]) * _calm(to)
				var j := to.index_of(e["victim"])
				if j < 0:
					continue
				var d := from.center().distance_to(to.mpos[j])
				stats["shots"][from.side] += 1
				if rng.randf() < hit_chance(from, to, d, to.mpos[j]) * float(from.spec["range"]) / maxf(eff_range(from, to), 1.0):
					to.supp += 0.12 * _calm(to)
					stats["hits"][from.side] += 1
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
				stats["blows"][from2.side] += 1
				if rng.randf() < float(from2.spec["melee"]):
					stats["kills"][from2.side] += 1
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
	if from.in_post and from.post is Garrison:
		var g: Garrison = from.post
		var to: Squad = e["to"]
		var aim := to.center() if is_instance_valid(to) else g.at
		var dir2 := (aim - g.at).normalized()
		var at2 := Vector3(g.at.x, g.y + 2.6, g.at.y) + Vector3(dir2.x, 0, dir2.y) * (maxf(g.half.x, g.half.y) + 0.3) \
			+ Vector3(-dir2.y, 0, dir2.x) * rng.randf_range(-g.half.x, g.half.x)
		fx.glow.add("spark", at2, Vector3(dir2.x, 0, dir2.y) * 6.0, 0.5)
		fx.trail(at2, Vector3(dir2.x, 0.3, dir2.y) * 1.5, 0.35)
		return
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


## A man is hit: one hit fewer to go; at none he falls, dead or (ours, by the kind's chance) wounded.
func wound(s: Squad, j: int) -> void:
	s.md[j]["hp"] = int(s.md[j]["hp"]) - 1
	if int(s.md[j]["hp"]) > 0:
		s.act(j, "hit")
		return
	if comms != null and String(s.md[j].get("role", "")) == "officer" and s.kind == "officer":
		if not comms.officer_hit(s, j):
			return                             # wounded, not dead: the guards carry him back
	stats["dead"][s.side] += 1
	var hurt := rng.randf() < float(s.spec.get("wound", 0.0))
	var body := s.kill(j, corpses)
	if hurt:
		stats["wounded"] += 1
		wounded.append({"body": body, "kind": s.kind, "t": t, "state": "down", "path": PackedVector2Array(), "aid": null})
	else:
		_dead.append([body, t])


# ------------------------------------------------------------------ hand to hand

func _melee() -> void:
	for s in ours() + enemies:
		var reach := float(s.spec["reach"])
		var any := false
		var foes := foes_of(s)
		for i in s.men.size():
			if (s.in_post and not s.post is Garrison) or (s.side == 0 and s.moving()):
				s.md[i]["goal"] = null             # ours can walk away from a fight when ordered
				continue
			var hold := s.in_post                  # in a garrison: fight at the door, do not run out
			var p := s.mpos[i]
			var best: Squad = null
			var bj := -1
			var bd := 2.5 if hold else reach
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
			s.md[i]["goal"] = null if hold else fp + away * 1.1
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

## Sends a squad into a building it can fight from: a house, ruin or one of ours (see garrison_at).
func garrison(s: Squad, g: Garrison) -> void:
	if not s.can_fire() or s.side != 0:
		return
	if g.crew != null and is_instance_valid(g.crew) and g.crew != s and g.crew.post == g:
		say("The %s is already held" % g.label())
		return
	s.cancel_job()
	s.post = g
	s.order_move(g.door(nav))


## The building at p a squad can garrison, or null: a village house or ruin, or one of our finished buildings.
func garrison_at(p: Vector2) -> Garrison:
	for g in garrisons:
		if g.covers(p):
			return g
	if build != null:
		var site: Variant = build.site_at(p)
		if site != null and (site as BuildSite).done and (site as BuildSite).kind in Garrison.HOLDS:
			if not _site_garrisons.has(site):
				_site_garrisons[site] = Garrison.of_site(site)
			return _site_garrisons[site]
	return null


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
	var s: Variant = p["crew"]
	site.set_meta("ammo", p["ammo"])                # the post keeps what is left for the next crew
	_posts.erase(site)
	if site.node:
		BldDefences.set_crew(site.node, false)
	if is_instance_valid(s):
		(s as Squad).in_post = false


func _run_posts(dt: float) -> void:
	# garrisons: arrivals and leavings
	for s in ours():
		if s.post is Garrison:
			var g: Garrison = s.post
			if not s.in_post and not s.moving() and s.at.distance_to(g.door(nav)) < 8.0:
				s.in_post = true
				g.crew = s
		elif s.in_post and s.post == null:
			s.in_post = false
	for g in garrisons + _site_garrisons.values():
		if g.crew != null and (not is_instance_valid(g.crew) or g.crew.post != g or g.crew.men.is_empty()):
			if is_instance_valid(g.crew) and g.crew.post == null:
				g.crew.in_post = false
			g.crew = null
	# arrivals
	for s in ours():
		if s.post is BuildSite and not s.in_post and not s.moving():
			var site: BuildSite = s.post
			if not build.sites.has(site) or not site.done:
				s.post = null
			elif s.at.distance_to(site.approach(nav)) < 8.0:
				s.in_post = true
				_posts[site] = {"crew": s, "next": t + 1.0, "acc": 0.0, "ammo": float(site.get_meta("ammo", MG_AMMO if site.kind == "mg_nest" else GUN_AMMO))}
				BldDefences.set_crew(site.node, true)
	for site: BuildSite in _posts.keys():
		var p: Dictionary = _posts[site]
		var s: Variant = p["crew"]
		if not is_instance_valid(s) or (s as Squad).men.is_empty() or s.post != site or not build.sites.has(site) or not site.done:
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
		# a finished depot near the post keeps it supplied
		var most := float(MG_AMMO if site.kind == "mg_nest" else GUN_AMMO)
		if float(p["ammo"]) < most and _near_kind(c, ["depot"], POST_SUPPLY_R) != null:
			p["ammo"] = minf(most, float(p["ammo"]) + dt * (40.0 if site.kind == "mg_nest" else 0.25))
		if best == null:
			continue
		if site.kind == "mg_nest":
			p["acc"] = float(p["acc"]) + dt * MG_RATE
			while float(p["acc"]) >= 1.0 and float(p["ammo"]) >= 1.0:
				p["acc"] = float(p["acc"]) - 1.0
				p["ammo"] = float(p["ammo"]) - 1.0
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
		elif t >= float(p["next"]) and float(p["ammo"]) >= 1.0:
			p["next"] = t + GUN_EVERY
			p["ammo"] = float(p["ammo"]) - 1.0
			var aim2 := best.center() + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 10.0
			shell(aim2)


## A shell bursts at p: men near it fall, and everyone round about is shaken.
func shell(p: Vector2) -> void:
	if blasts != null:
		blasts.fire(3, p.x, p.y)
	if comms != null:
		comms.blast_at(p)
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


# ------------------------------------------------------------------ ammo, the wounded, sight

## The nearest finished building of one of these kinds within r of p, or null.
func _near_kind(p: Vector2, kinds: Array, r: float) -> BuildSite:
	if build == null:
		return null
	var best: BuildSite = null
	var bd := r
	for site in build.sites:
		if site.done and site.kind in kinds:
			var d := site.center().distance_to(p)
			if d < bd:
				bd = d
				best = site
	return best


## Rounds left in a post (MG nest or gun pit), or -1 if it is not manned.
func post_ammo(site: BuildSite) -> float:
	return float((_posts[site] as Dictionary)["ammo"]) if _posts.has(site) else -1.0


## Our squads near a finished depot or HQ fill their pouches.
func _resupply(dt: float) -> void:
	for s in ours():
		var most := int(s.spec.get("ammo", 0))
		if most <= 0 or s.ammo_frac() >= 1.0 or _near_kind(s.center(), ["depot", "hq"], RESUPPLY_R) == null:
			continue
		var acc := float(s.get_meta("supply_acc", 0.0)) + dt * RESUPPLY_RATE
		var whole := int(acc)
		s.set_meta("supply_acc", acc - whole)
		for d in s.md:
			d["ammo"] = mini(most, int(d.get("ammo", 0)) + whole)


## The wounded: down a while, then up and walking to the nearest aid post, then healing; the healed top up squads.
func _run_wounded(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for w in wounded:
		var body: Soldier = w["body"]
		if not is_instance_valid(body):
			continue
		if w["state"] == "down":
			if t - float(w["t"]) < DOWN_S:
				keep.append(w)
				continue
			var p := Vector2(body.global_position.x, body.global_position.z)
			var post := _near_kind(p, AID_KINDS, INF)
			if post == null:
				w["t"] = t - DOWN_S + 5.0          # no aid post yet: look again in 5 s
				keep.append(w)
				continue
			var route := nav.find_path(p, post.approach(nav))
			if route.is_empty():
				w["t"] = t - DOWN_S + 5.0
				keep.append(w)
				continue
			w["state"] = "walk"
			w["path"] = route
			w["aid"] = post
			var ap := body.get_child(body.get_child_count() - 1) as AnimationPlayer
			for c in body.get_children():
				if c is AnimationPlayer:
					ap = c
			if ap and ap.has_animation("walk"):
				ap.play("walk", 0.5)
				ap.speed_scale = 0.75
			keep.append(w)
		elif w["state"] == "walk":
			var route: PackedVector2Array = w["path"]
			var p2 := Vector2(body.global_position.x, body.global_position.z)
			var left := 1.0 * dt
			while left > 0.0 and not route.is_empty():
				var d := p2.distance_to(route[0])
				if d <= left:
					p2 = route[0]
					left -= d
					route.remove_at(0)
				else:
					var dir := (route[0] - p2) / d
					p2 += dir * left
					body.rotation.y = atan2(-dir.x, -dir.y)
					left = 0.0
			w["path"] = route
			body.global_position = Vector3(p2.x, nav.height(p2), p2.y)
			if route.is_empty():
				var post2: BuildSite = w["aid"]
				if build.sites.has(post2):
					if not aid.has(post2):
						aid[post2] = []
					(aid[post2] as Array).append([w["kind"], t + HEAL_S])
				body.queue_free()
			else:
				keep.append(w)
	wounded = keep
	# the healed join a squad of their kind near the aid post
	for post: BuildSite in aid.keys():
		if not build.sites.has(post) or not post.done:
			aid.erase(post)
			continue
		var list: Array = aid[post]
		var i := 0
		while i < list.size():
			var e: Array = list[i]
			if t < float(e[1]):
				i += 1
				continue
			var joined := false
			for s in ours():
				if s.kind == e[0] and s.men.size() < s.full and not s.in_post and s.center().distance_to(post.center()) < AID_R:
					s.add_man(post.approach(nav))
					joined = true
					break
			if joined:
				list.remove_at(i)
			else:
				i += 1


func healed_waiting() -> int:
	var n := 0
	for post in aid:
		n += (aid[post] as Array).size()
	return n


## Eye height of a squad above sea level (ground, plus a man's height, or a building's).
func eye(s: Squad) -> float:
	var y := nav.height(s.center())
	if s.in_post and s.post is Garrison:
		return (s.post as Garrison).y + 3.0
	return y + (0.5 if s.pinned else 1.6)


## A squad's range against another: 15% further for each level it stands above, and from inside a building.
func eff_range(s: Squad, to: Squad) -> float:
	var r := float(s.spec["range"])
	var up := clampf((eye(s) - eye(to)) / 8.0, 0.0, 2.0)
	r *= 1.0 + 0.15 * up
	if s.in_post and s.post is Garrison:
		r *= 1.15
	return r


## True if nothing stands in the way between two eyes: no higher ground on the line, no thick woods.
func clear_sight(a: Vector2, ya: float, b: Vector2, yb: float) -> bool:
	var dist := a.distance_to(b)
	var n := int(dist / 6.0)
	var woods := 0
	var last := Vector2i(-1, -1)
	for k in range(1, n):
		var u := float(k) / float(n)
		var p := a.lerp(b, u)
		if p.distance_to(a) < 10.0 or p.distance_to(b) < 10.0:
			continue
		if data.ground_y(p) > lerpf(ya, yb, u) - 0.3:
			return false
		var c := nav.cell_of(p)
		if c != last and (data.feat[c.y * data.w + c.x] & MapData.F_WOOD) != 0:
			woods += 1
			last = c
			if woods > 3:
				return false
	return true


## True if s can fire on f: in range, in sight, and (for ours) the enemy has been seen.
func can_shoot(s: Squad, f: Squad) -> bool:
	if f.men.is_empty():
		return false
	if s.side == 0 and not seen.has(f):
		return false
	var d := s.center().distance_to(f.center())
	if d > eff_range(s, f):
		return false
	return clear_sight(s.center(), eye(s), f.center(), eye(f))


## How far our squads see now (day, night, fog).
func sight_range() -> float:
	if view == null:
		return SIGHT
	match view.look:
		MapView.Look.NIGHT:
			return SIGHT * 0.5
		MapView.Look.FOG:
			return SIGHT * 0.35
	return SIGHT


## Fog of war: which enemy squads one of ours can see; the rest are hidden.
func _fog() -> void:
	var sr := sight_range()
	seen.clear()
	for e in enemies:
		if e.men.is_empty():
			continue
		var ec := e.center()
		var spotted := false
		if _fired.has(e) and t - float(_fired[e]) < REVEAL_S:
			for s in ours():
				if s.center().distance_to(ec) < REVEAL_R:
					spotted = true
					break
		if not spotted:
			for s in ours():
				if s.men.is_empty():
					continue
				var d := s.center().distance_to(ec)
				var r := sr * (1.0 + 0.15 * clampf((eye(s) - eye(e)) / 8.0, 0.0, 2.0))
				if d < r and clear_sight(s.center(), eye(s), ec, eye(e) + 0.4):
					spotted = true
					break
		if not spotted and build != null:
			for site in build.sites:
				if site.done and site.center().distance_to(ec) < BUILD_SIGHT:
					spotted = true
					break
		if spotted:
			seen[e] = true
		e.visible = spotted


# ------------------------------------------------------------------ tidying up

func _tidy() -> void:
	while not _dead.is_empty() and t - float(_dead[0][1]) > CORPSE_S:
		var b: Node = _dead.pop_front()[0]
		if is_instance_valid(b):
			b.queue_free()
	for e in enemies.duplicate():
		if e.men.is_empty():
			var wn := int(e.get_meta("wave", 0))
			if _waves.has(wn):
				_waves[wn] = int(_waves[wn]) - 1
				if int(_waves[wn]) <= 0:
					_waves.erase(wn)
					set_meta("waves_beaten", int(get_meta("waves_beaten", 0)) + 1)
			enemies.erase(e)
			seen.erase(e)
			_fired.erase(e)
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
	var walking := 0
	for w in wounded:
		walking += 1
	return "J red coats, K medieval host, L zombies (from the north); right click an enemy to attack, an MG nest, gun pit or house to go in   [%d enemies, %d seen]   wounded: %d on the way, %d at aid posts%s" % [
		n, seen.size(), walking, healed_waiting(), ("   " + note) if not note.is_empty() else ""]
