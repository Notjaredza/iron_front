class_name Buildings
extends RefCounted
## Iron Front: the building catalogue (Asset Builder Chat). Buildings.make(kind) returns a finished
## Building (see building.gd for its looks and switches). KINDS: kind -> [footprint in 8 m tiles, set].

const KINDS := {
	"hq": [Vector2i(3, 3), "core"],
	"barracks": [Vector2i(2, 3), "core"],
	"depot": [Vector2i(3, 2), "core"],
	"halt": [Vector2i(2, 1), "rail"],
	"station": [Vector2i(3, 2), "rail"],
	"engine_shed": [Vector2i(2, 3), "rail"],
	"water_tower": [Vector2i(1, 1), "rail"],
	"coal_stage": [Vector2i(2, 1), "rail"],
	"signal_box": [Vector2i(1, 1), "rail"],
}


static func make(kind: String) -> Building:
	var b := Building.new()
	b.kind = kind
	b.name = kind.capitalize().replace(" ", "")
	b.tiles = KINDS[kind][0]
	match kind:
		"hq":
			BldCore.hq(b)
		"barracks":
			BldCore.barracks(b)
		"depot":
			BldCore.depot(b)
		"halt":
			BldRail.halt(b)
		"station":
			BldRail.station(b)
		"engine_shed":
			BldRail.engine_shed(b)
		"water_tower":
			BldRail.water_tower(b)
		"coal_stage":
			BldRail.coal_stage(b)
		"signal_box":
			BldRail.signal_box(b)
	b.finish()
	return b


static func of_set(set_name: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in KINDS:
		if KINDS[k][1] == set_name:
			out.append(k)
	return out
