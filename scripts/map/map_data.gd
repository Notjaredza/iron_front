class_name MapData
extends RefCounted
## Iron Front: the stepped map's data (made by MapGen, drawn by MapMesher and MapView).
##
## The ground lives on the 8 m grid. There are W x H cells, and the level is stored on the cell CORNERS:
## (W + 1) x (H + 1) values in `field`.
## - Levels: 0 is water (its bed is one step down), 1 is the base, and 2 and 3 are the plateaus.
## - A cell whose four corners agree is flat. A cell whose corners differ holds a cliff edge, drawn with marching
##   squares through the edge midpoints, so edges run square along the grid or cut across at 45 degrees.
##
## The rough shape is made on a coarse grid of 4 x 4 cell blocks (32 m), in `coarse`, then chamfered into `field`.

const CELL := 8.0
const BLOCK := 4                               # cells per coarse block
const LEVEL_Y := [-5.0, 0.0, 8.0, 16.0]        # ground height of each level (water bed, base, plateau 2, plateau 3)
const WATER_Y := -2.2
const FLAT_NONE := 255                         # walk value of a cell that holds a cliff edge
const F_STREAM := 1                            # a small stream (walkable, slow)
const F_FORD := 2                              # a ford across a river (walkable, slow), banks included
const F_MARSH := 4                             # boggy ground with pools and reeds (walkable, slow)
const F_WOOD := 8                              # woods
const F_FIELD := 16                            # a crop field (see crop)
const F_TALL := 32                             # tall grass
const F_HEDGE := 64                            # a hedgerow runs through this cell
const F_TREE := 128                            # a lone tree stands here

var seed := 0
var w := 1000                                  # cells across (8 km)
var h := 1500                                  # cells down (12 km)
var cw := 250                                  # coarse blocks across
var ch := 375
var coarse := PackedByteArray()                # cw * ch levels 0..3
var field := PackedByteArray()                 # (w + 1) * (h + 1) corner levels 0..3
var walk := PackedByteArray()                  # w * h: the level of a flat cell, or FLAT_NONE
var busy := PackedByteArray()                  # w * h: 1 where ground detail must keep off (rails, houses, ramps)
## Nature (map round 3), one byte of flags per cell (see the F_ constants), the crop of a field cell, and the
## distance of a water cell from the bank in cells (1 at the bank, up to 7).
var feat := PackedByteArray()
var crop := PackedByteArray()                  # 0 none, 1 wheat, 2 green crop, 3 ploughed, 4 hay
var wdepth := PackedByteArray()
## Fords: {"p0", "p1": Vector2 (metres, the two bank tops on the centre line), "dir": Vector2 (p0 to p1, unit),
## "w": float (metres wide), "river": int}.
var fords: Array = []
## Streams: Array of PackedVector2Array (metres), drawn from feat F_STREAM; kept for later (flow direction).
var streams: Array = []
## Ramps: {"t": upper level, "axis": 0 for x or 1 for z, "s": +1/-1 (direction from high to low), "e": float (the
## cliff line, in cells along the axis), "a": int (the first lateral cell), "w": int (cells wide)}.
var ramps: Array = []
## Old rail lines: {"pts": PackedVector2Array (metres, x/z), "sections": Array of {"from", "to" (metres along), "broken"}}.
var rails: Array = []
## Settlements: {"kind": "village" | "ruin", "pos": Vector2 (metres), "level": int, "station": bool,
## "houses": Array of {"pos": Vector3, "size": Vector2, "rot": float, "kind": "house" | "ruin" | "station" | "platform"}}.
var places: Array = []
var gen_ms := 0
var notes: Array[String] = []


func size_m() -> Vector2:
	return Vector2(w * CELL, h * CELL)


func has(x: int, z: int, flag: int) -> bool:
	return x >= 0 and z >= 0 and x < w and z < h and (feat[z * w + x] & flag) != 0


## Walkable for an army without bridges: dry flat ground, streams, marsh and fords (deep water is not).
func can_walk(x: int, z: int) -> bool:
	var i := z * w + x
	if walk[i] == 0:
		return (feat[i] & F_FORD) != 0
	return true


func corner(x: int, z: int) -> int:
	return field[z * (w + 1) + x]


func cell_flat(x: int, z: int) -> int:
	return walk[z * w + x]


static func level_y(level: int) -> float:
	return LEVEL_Y[clampi(level, 0, 3)]


## Ground height at a point (metres), for the camera and placing things: the level under the nearest corner for
## cliff cells (good enough to follow the ground; ramps are not counted).
func ground_y(p: Vector2) -> float:
	var x := clampi(int(p.x / CELL), 0, w - 1)
	var z := clampi(int(p.y / CELL), 0, h - 1)
	var f := walk[z * w + x]
	if f != FLAT_NONE:
		return WATER_Y if f == 0 else level_y(f)
	var cx := clampi(roundi(p.x / CELL), 0, w)
	var cz := clampi(roundi(p.y / CELL), 0, h)
	var l := field[cz * (w + 1) + cx]
	return WATER_Y if l == 0 else level_y(l)
