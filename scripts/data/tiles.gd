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
	# Zilvermeer (spoor meer)
	"meer_sand", "meer_reeds", "meer_lelie", "meer_paal", "meer_bibvloer", "meer_tapijt",
	# De Diepte (spoor diepte): paars en diepblauw, anders dan de lichtblauwe tempel.
	"void_floor", "void_wall", "void_crystal", "rune_pad", "void_stairs",
	# De arena (spoor arena)
	"arena_sand", "arena_wall", "arena_tribune", "arena_gate", "arena_arch",
]

## Tegels waar je niet doorheen kunt lopen.
const SOLID: Array[String] = [
	"tree", "water", "stone", "fence", "roof", "house_wall", "house_window", "rock", "bush", "dead_tree",
	"well", "crate", "cave_wall", "cave_crystal", "stalagmite", "ruin_wall", "ruin_pillar", "temple_wall",
	"wood_wall", "counter", "shelf", "bed",
	"meer_reeds", "meer_lelie", "meer_paal",
	"void_wall", "void_crystal",
	"arena_wall", "arena_tribune", "arena_gate",
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
	# Zilvermeer
	"s": "meer_sand", ";": "meer_reeds", "l": "meer_lelie", "p": "meer_paal", "Q": "meer_bibvloer", "J": "meer_tapijt",
	# De Diepte (d = diepte, V = void, K = kristal)
	"d": "void_floor", "V": "void_wall", "K": "void_crystal", "*": "rune_pad", ">": "void_stairs",
	# De arena
	":": "arena_sand", "+": "arena_wall", "-": "arena_tribune", "!": "arena_gate", "n": "arena_arch",
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


## Ondergrond bij de voeten; buiten een kaart hebben we geen loopgeluid.
static func name_at(rows: Array, foot_position: Vector2, tile_size := 32.0) -> String:
	var cell := Vector2i(floori(foot_position.x / tile_size), floori(foot_position.y / tile_size))
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0:
		return ""
	var row: String = rows[cell.y]
	if cell.x >= row.length():
		return ""
	return name_for(row[cell.x], cell.x, cell.y)


## Het gewone gras houdt zijn oorspronkelijke snelheid; een pad loont, zand is wat zwaarder.
static func movement_multiplier(tile_name: String) -> float:
	if tile_name == "path":
		return 1.2
	if tile_name in ["meer_sand", "arena_sand"]:
		return 0.92
	return 1.0


static func footstep_surface(tile_name: String) -> String:
	if tile_name == "" or is_solid_name(tile_name):
		return ""
	if tile_name.begins_with("grass"):
		return "grass"
	if tile_name == "path":
		return "path"
	if tile_name in ["meer_sand", "arena_sand"]:
		return "sand"
	if tile_name in ["bridge", "wood_floor", "meer_bibvloer", "door"]:
		return "wood"
	if tile_name in ["carpet", "mat", "meer_tapijt"]:
		return "cloth"
	return "stone"


## Kleur van een tegel op de kaartjes (kaarttabblad en einde).
static func map_color(tile_name: String) -> Color:
	var color := Color(0.5, 0.5, 0.55)
	if tile_name.begins_with("meer_"):
		color = _meer_color(tile_name)
	elif tile_name.begins_with("grass"):
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
	elif tile_name == "arena_sand":
		color = Color(0.86, 0.72, 0.46)
	elif tile_name.begins_with("arena"):
		color = Color(0.76, 0.66, 0.52)
	if is_solid_name(tile_name):
		color = color.darkened(0.3)
	return color


## Kleuren van de tegels van het Zilvermeer op het kaartje.
static func _meer_color(tile_name: String) -> Color:
	match tile_name:
		"meer_sand":
			return Color(0.93, 0.85, 0.6)
		"meer_reeds":
			return Color(0.35, 0.6, 0.4)
		"meer_lelie":
			return Color(0.3, 0.6, 0.6)
		"meer_paal":
			return Color(0.5, 0.35, 0.2)
		"meer_tapijt":
			return Color(0.2, 0.45, 0.38)
	return Color(0.62, 0.45, 0.28) # de bibliotheekvloer
