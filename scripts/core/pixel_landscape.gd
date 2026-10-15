extends RefCounted
## Pure visual choices; tile names, collision, object slots and saves stay authoritative.
const Tiles:=preload("res://scripts/data/tiles.gd")
const VARIANTS:=8
const WATER:=["water","ce_sea","ce_shore","bog_water"]
const GRASS:=["grass","grass_tufts","grass_flowers","marsh_grass","marsh_tufts","oasis_grass","ce_grass"]
const PATH:=["path","meer_sand","ce_sand","ce_dune","dune_sand","dune_tufts","arena_sand","snow","snow_tufts"]
static func atlas(tile: String,x: int,y: int) -> Vector2i:
	return Vector2i(Tiles.index_of(tile),posmod(x*17+y*31+x*y*3,VARIANTS))
static func at(rows: Array,cell: Vector2i) -> String:
	if cell.y<0 or cell.y>=rows.size() or cell.x<0 or cell.x>=str(rows[cell.y]).length():return ""
	return Tiles.name_for(rows[cell.y][cell.x],cell.x,cell.y)
static func ground(tile: String) -> bool:
	return tile in GRASS or tile in PATH or tile in ["wood_floor","ce_boardwalk","ruin_floor","ruin_cracked","cave_floor","temple_floor","void_floor","ad_wetstone"]
static func green(tile: String) -> Color:
	return Color("668954") if tile.begins_with("marsh") else Color("7b9b69") if tile=="ce_grass" else Color("67945a") if tile=="oasis_grass" else Color("6e9c61")
static func water_row(tile: String) -> int:return WATER.find(tile)
