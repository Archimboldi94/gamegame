class_name ExploreDressing
extends RefCounted
## Landmark and prop placements for the Qingyadu explore scenes.
## Ground tiles stay on the battle diamond set; these sprites sit on top.

const PATH := "res://data/wuxia/explore_dressing.json"

const TEXTURES := {
	"inn": "res://assets/tiles/props/prop_inn.png",
	"shrine": "res://assets/tiles/props/prop_shrine.png",
	"house": "res://assets/tiles/props/prop_house.png",
	"house_b": "res://assets/tiles/props/prop_house_b.png",
	"ferry": "res://assets/tiles/props/prop_ferry.png",
	"crate": "res://assets/tiles/props/prop_crate.png",
	"bamboo": "res://assets/tiles/props/prop_bamboo.png",
	"tree": "res://assets/tiles/deco_tree.png",
	"lantern": "res://assets/tiles/props/prop_lantern.png",
	"post": "res://assets/tiles/props/prop_post.png",
	"counter": "res://assets/tiles/props/prop_counter.png",
	"shelf": "res://assets/tiles/props/prop_shelf.png",
	"rack": "res://assets/tiles/props/prop_rack.png",
	"table": "res://assets/tiles/props/prop_table.png",
}

## Forest fillers drawn with their tile. Landmarks are drawn afterwards so roofs stay readable.
const GROUND_DECO := ["bamboo", "tree"]


static func props(area: String) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var rows: Array = data.get(area, [])
	return rows


static func count_kind(area: String, kind: String) -> int:
	var n := 0
	for prop in props(area):
		if String(prop.get("kind", "")) == kind:
			n += 1
	return n
