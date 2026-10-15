class_name ExploreIso
extends RefCounted
## Map continuous explore design-space (TILE px) onto battle IsoView diamonds.

const TW := IsoView.TW
const TH := IsoView.TH
const HS := IsoView.HS

## Blueprint char -> battle terrain art key (top_<art>_N.png).
const CHAR_ART := {
	".": "grass", ",": "grassdirt", "=": "stone", "~": "water",
	"#": "forest", "H": "wall", "m": "mud",
}


static func world_to_iso(p: Vector2) -> Vector2:
	var fx := p.x / ExplorationRules.TILE
	var fy := p.y / ExplorationRules.TILE
	return Vector2((fx - fy) * TW * 0.5, (fx + fy) * TH * 0.5)


static func cell_to_iso(cell: Vector2i, height := 0) -> Vector2:
	return Vector2((cell.x - cell.y) * TW * 0.5, (cell.x + cell.y) * TH * 0.5 - height * HS)


static func art_for(ch: String) -> String:
	return String(CHAR_ART.get(ch, "grass"))


static func height_for(ch: String) -> int:
	match ch:
		"H", "#":
			return 1
		"~":
			return 0
		_:
			return 0


static func iso_bounds(cols: int, rows: int) -> Rect2:
	var points: Array[Vector2] = [
		cell_to_iso(Vector2i(0, 0)),
		cell_to_iso(Vector2i(cols, 0)),
		cell_to_iso(Vector2i(0, rows)),
		cell_to_iso(Vector2i(cols, rows)),
	]
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	# Pad for tile diamond extents and props.
	return Rect2(lo - Vector2(TW, TH), hi - lo + Vector2(TW * 2, TH * 2 + HS * 2))
