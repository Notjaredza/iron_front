class_name Garrison
extends RefCounted
## Iron Front: a building a squad can go into and fight from (fighting round 2), as in Company of Heroes: a village
## house or ruin on the map, or one of our own finished buildings (HQ, barracks, depot, station...). The men are out
## of sight inside; they fire from it with heavy cover and see a little further from its height.

const HOLDS := ["hq", "barracks", "depot", "station", "halt", "engine_shed", "signal_box", "runner_post"]

var kind := "house"                            # "house", "ruin" or a Buildings kind
var at := Vector2.ZERO                         # middle (metres)
var half := Vector2(4, 4)                      # half its size, before turning
var rot := 0.0
var y := 0.0                                   # ground height
var site: BuildSite                            # for our own buildings
var crew: Squad


## The village houses and ruins on a map.
static func from_map(d: MapData) -> Array[Garrison]:
	var out: Array[Garrison] = []
	for pl: Dictionary in d.places:
		for h: Dictionary in pl["houses"]:
			if not h["kind"] in ["house", "ruin"]:
				continue
			var g := Garrison.new()
			g.kind = h["kind"]
			var p: Vector3 = h["pos"]
			g.at = Vector2(p.x, p.z)
			g.half = (h["size"] as Vector2) * 0.5
			g.rot = float(h["rot"])
			g.y = d.ground_y(g.at)
			out.append(g)
	return out


static func of_site(s: BuildSite) -> Garrison:
	var g := Garrison.new()
	g.kind = s.kind
	g.site = s
	g.at = s.center()
	g.half = Vector2(s.size) * MapData.CELL * 0.5
	g.y = s.y
	return g


## True if p is inside it (or within `pad` metres of its walls).
func covers(p: Vector2, pad := 1.5) -> bool:
	var q := (p - at).rotated(-rot)
	return absf(q.x) <= half.x + pad and absf(q.y) <= half.y + pad


## The spot outside it where the squad gathers before going in.
func door(nav: NavGrid) -> Vector2:
	var out := Vector2(0, half.y + 3.0).rotated(rot)
	return nav.nearest_open(at + out)


## How often a man inside is hit, compared with one in the open: a ruin's broken walls cover less.
func cover() -> float:
	return 0.4 if kind == "ruin" else 0.25


func label() -> String:
	if site != null:
		return BuildControl.NAMES.get(kind, kind)
	return kind
