extends RefCounted
## Alle tegels. De volgorde van NAMES is de volgorde in assets/tiles.png (van links naar rechts).
## Wil je een nieuwe tegel? Voeg hem toe aan NAMES, aan SOLID (als je er niet doorheen kunt),
## aan CHARS (het teken in de kaart) en teken hem in tools/make_art.py op dezelfde plek.

const NAMES: Array[String] = [
	"grass", "tree", "water", "path", "stone", "grass_flowers", "grass_tufts", "bridge", "fence",
	"roof", "house_wall", "house_window", "door", "cave_mouth", "ruin_stairs", "temple_door",
	"rock", "bush", "dead_tree", "well", "crate",
	"cave_floor", "cave_wall", "cave_crystal", "stalagmite",
	"ruin_floor", "ruin_wall", "ruin_pillar", "ruin_cracked",
	"temple_floor", "temple_wall", "temple_rune", "carpet",
	"wood_floor", "wood_wall", "counter", "shelf", "bed", "mat",
]

## Tegels waar je niet doorheen kunt lopen.
const SOLID: Array[String] = [
	"tree", "water", "stone", "fence", "roof", "house_wall", "house_window", "rock", "bush", "dead_tree",
	"well", "crate", "cave_wall", "cave_crystal", "stalagmite", "ruin_wall", "ruin_pillar", "temple_wall",
	"wood_wall", "counter", "shelf", "bed",
]

## Teken in de kaart -> tegel. Het gras (".") krijgt automatisch wat afwisseling.
const CHARS := {
	".": "grass", ",": "path", "#": "tree", "~": "water", "W": "stone", "=": "bridge", "|": "fence",
	"^": "roof", "H": "house_wall", "h": "house_window", "D": "door", "E": "cave_mouth",
	"A": "ruin_stairs", "T": "temple_door",
	"o": "rock", "b": "bush", "t": "dead_tree", "O": "well", "x": "crate",
	"c": "cave_floor", "X": "cave_wall", "y": "cave_crystal", "v": "stalagmite",
	"r": "ruin_floor", "M": "ruin_wall", "I": "ruin_pillar", "k": "ruin_cracked",
	"_": "temple_floor", "Z": "temple_wall", "u": "temple_rune", "%": "carpet",
	"w": "wood_floor", "N": "wood_wall", "C": "counter", "S": "shelf", "B": "bed", "m": "mat",
}


static func index_of(tile_name: String) -> int:
	return NAMES.find(tile_name)


static func is_solid_name(tile_name: String) -> bool:
	return tile_name in SOLID


## Tegelnaam voor een teken op positie (x, y). Gras wisselt af zodat het niet saai wordt.
static func name_for(c: String, x: int, y: int) -> String:
	var tile_name: String = CHARS.get(c, "grass")
	if tile_name == "grass":
		var h := (x * 7 + y * 13 + x * y) % 11
		if h < 1:
			return "grass_flowers"
		if h < 5:
			return "grass_tufts"
	return tile_name


static func is_solid_char(c: String) -> bool:
	return is_solid_name(CHARS.get(c, "grass"))
