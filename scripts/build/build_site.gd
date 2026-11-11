class_name BuildSite
extends RefCounted
## Iron Front: one building being put up on the map, or finished (building round).
## A site covers a rectangle of 8 m cells (origin + size, after turning). Engineers build it over time:
## progress 0..1 runs through the building's stages (marked-out plot, frame and scaffold, half built, finished).
## Wall and sandbag cells are one site per cell; their pieces join up with their neighbours (BuildControl).

const CELL := MapData.CELL
const SPOT_GAP := 2.4                          # metres between work spots along an edge
const SPOT_OUT := 1.4                          # metres out from the footprint

var kind := ""                                 # a Buildings kind, or "wall" (variant: "", tower, bastion, gate)
var variant := ""
var family := ""                               # "wall" or "sandbag": pieces join up with their neighbours
var origin := Vector2i.ZERO                    # the top-left cell
var size := Vector2i.ONE                       # cells across and down, after turning
var rot := 0                                   # quarter turns
var y := 0.0                                   # ground height
var node: Building
var progress := 0.0
var work_time := 30.0                          # seconds for a full section of four to build it
var done := false
var crews: Array = []                          # the engineer squads working on it


func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in size.y:
		for x in size.x:
			out.append(origin + Vector2i(x, z))
	return out


func center() -> Vector2:
	return (Vector2(origin) + Vector2(size) * 0.5) * CELL


func has_cell(c: Vector2i) -> bool:
	return c.x >= origin.x and c.y >= origin.y and c.x < origin.x + size.x and c.y < origin.y + size.y


## The way the building's front faces (its -Z, turned).
func front() -> Vector2:
	var v := Basis(Vector3.UP, rot * PI * 0.5) * Vector3(0, 0, -1)
	return Vector2(v.x, v.z).normalized()


## The stage the building shows at a given progress.
static func stage_for(p: float) -> int:
	if p >= 1.0:
		return 3
	if p >= 0.5:
		return 2
	if p >= 0.04:
		return 1
	return 0


## Where engineers walk to before spreading to their spots: in front of the building.
func approach(nav: NavGrid) -> Vector2:
	var f := front()
	var reach := absf(f.x) * size.x * CELL * 0.5 + absf(f.y) * size.y * CELL * 0.5
	return nav.nearest_open(center() + f * (reach + 4.0))


## Work spots round the footprint, front edge first, then the sides, then the back: [spot, facing] pairs.
## Only spots where a man can stand are kept.
func spots(nav: NavGrid) -> Array:
	var mn := Vector2(origin) * CELL
	var mx := Vector2(origin + size) * CELL
	var c := (mn + mx) * 0.5
	var edges := [[Vector2(0, -1), mx.x - mn.x], [Vector2(1, 0), mx.y - mn.y], [Vector2(0, 1), mx.x - mn.x],
		[Vector2(-1, 0), mx.y - mn.y]]
	var f := front()
	edges.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).dot(f) > (b[0] as Vector2).dot(f))
	var out := []
	for e: Array in edges:
		var n: Vector2 = e[0]
		var along := Vector2(-n.y, n.x)
		var half: float = float(e[1]) * 0.5 - 0.6
		var mid := c + n * (absf(n.x) * (mx.x - mn.x) * 0.5 + absf(n.y) * (mx.y - mn.y) * 0.5 + SPOT_OUT)
		var k := 0
		while true:
			var t := float((k + 1) / 2) * SPOT_GAP * (1.0 if k % 2 == 1 else -1.0)
			if absf(t) > half:
				break
			var p := mid + along * t
			if nav.is_open(p):
				out.append([p, -n])
			k += 1
	return out
