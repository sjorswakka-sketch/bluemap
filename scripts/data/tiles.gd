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
	# De Diepte (spoor diepte): paars en diepblauw, anders dan de lichtblauwe tempel.
	"void_floor", "void_wall", "void_crystal", "rune_pad", "void_stairs",
]

## Tegels waar je niet doorheen kunt lopen.
const SOLID: Array[String] = [
	"tree", "water", "stone", "fence", "roof", "house_wall", "house_window", "rock", "bush", "dead_tree",
	"well", "crate", "cave_wall", "cave_crystal", "stalagmite", "ruin_wall", "ruin_pillar", "temple_wall",
	"wood_wall", "counter", "shelf", "bed", "void_wall", "void_crystal",
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
	# De Diepte (d = diepte, V = void, K = kristal; andere sporen gebruiken $ & @ : ! s ; l p Q J)
	"d": "void_floor", "V": "void_wall", "K": "void_crystal", "*": "rune_pad", ">": "void_stairs",
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


## Kleur van een tegel op de kaartjes (kaarttabblad en einde).
static func map_color(tile_name: String) -> Color:
	var color := Color(0.5, 0.5, 0.55)
	if tile_name.begins_with("grass"):
		color = Color(0.36, 0.66, 0.3)
	elif tile_name in ["tree", "bush", "dead_tree"]:
		color = Color(0.14, 0.4, 0.2)
	elif tile_name == "water":
		color = Color(0.25, 0.5, 0.85)
	elif tile_name in ["path", "bridge", "mat"]:
		color = Color(0.85, 0.75, 0.55)
	elif tile_name.begins_with("cave"):
		color = Color(0.42, 0.36, 0.34)
	elif tile_name.begins_with("ruin"):
		color = Color(0.55, 0.57, 0.62)
	elif tile_name.begins_with("temple") or tile_name == "carpet":
		color = Color(0.5, 0.7, 0.95)
	elif tile_name.begins_with("void") or tile_name == "rune_pad":
		color = Color(0.42, 0.3, 0.72)
	elif tile_name.begins_with("wood") or tile_name in ["counter", "shelf", "bed"]:
		color = Color(0.62, 0.45, 0.28)
	elif tile_name == "roof":
		color = Color(0.75, 0.3, 0.25)
	elif tile_name.begins_with("house"):
		color = Color(0.85, 0.8, 0.7)
	elif tile_name in ["door", "cave_mouth", "ruin_stairs", "temple_door"]:
		color = Color(1.0, 0.85, 0.4)
	elif tile_name == "stone":
		color = Color(0.5, 0.52, 0.6)
	if is_solid_name(tile_name):
		color = color.darkened(0.3)
	return color
