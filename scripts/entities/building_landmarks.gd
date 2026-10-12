extends Node2D
## Kleine architectuur in dezelfde 2-wereldpixel-rastermaat als de tegelplaatjes.
## Hang deze node onder world.ground: hij verdwijnt bij kaartwissels en blijft achter de acteurs.
## Alleen versiering en licht; geen botsingen, interacties of opslaggegevens.

const Buildings := preload("res://scripts/data/buildings.gd")
const Art := preload("res://scripts/core/art.gd")
const INK := Color("252c3e")
const WOOD := Color("674631")
const GOLD := Color("e5bd69")
const PAPER := Color("f2e3b4")
const METAL := Color("afc2cb")

var world: Node
var buildings: Array = []
var clock := 0.0
var redraw_elapsed := 0.0
var forge_light: PointLight2D
var _door := Rect2()


func setup(map_id: String, owning_world: Node = null) -> void:
	world = owning_world
	buildings = Buildings.for_map(map_id)


func _ready() -> void:
	name = "BuildingLandmarks"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for building: Dictionary in buildings:
		if building["id"] == "smithy":
			forge_light = PointLight2D.new()
			forge_light.texture = Art.light_texture()
			forge_light.color = Color("ffae53")
			forge_light.texture_scale = 0.8
			forge_light.position = Buildings.world_rect(building).position + Vector2(158, 102)
			add_child(forge_light)
	set_process(is_instance_valid(forge_light))


func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(forge_light):
		var night: float = world.light_need() if is_instance_valid(world) else 0.0
		forge_light.energy = 0.35 + night * 0.35 + sin(clock * 7.0) * 0.035
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0 / 12.0:
		redraw_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	for building: Dictionary in buildings:
		var rect := Buildings.world_rect(building)
		_door = Buildings.local_door(building)
		draw_set_transform(rect.position)
		match building["id"]:
			"smithy": _smithy(rect.size.x)
			"shop": _shop(rect.size.x)
			"inn": _inn(rect.size.x)
			"fisher_hut": _fisher(rect.size.x)
			"library": _library(rect.size.x)
			"arena_hall": _arena(rect.size.x)
			"temple": _temple(rect.size.x)
	draw_set_transform(Vector2.ZERO)


## Alle decorstukken respecteren de echte deur; deze bewaking geldt ook voor latere toevoegingen.
func _r(x: float, y: float, w: float, h: float, color: Color) -> void:
	var rect := Rect2(x, y, w, h)
	if not rect.intersects(_door):
		draw_rect(rect, color)


func _poly(points: Array, color: Color) -> void:
	var vertices := PackedVector2Array()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		vertices.append(point)
		bounds = bounds.expand(point)
	if not bounds.intersects(_door):
		draw_colored_polygon(vertices, color)


func _roof(width: float, color: Color) -> void:
	_r(0, 0, width, 64, INK)
	_r(2, 2, width - 4, 56, color)
	for row in 7:
		var y := 4 + row * 8
		_r(2, y, width - 4, 2, color.lightened(0.15))
		_r(2, y + 6, width - 4, 2, color.darkened(0.28))
		for x in range(4 + (row % 2) * 12, int(width - 2), 24):
			_r(x, y + 2, 2, 4, color.darkened(0.22))
	_r(0, 58, width, 6, color.darkened(0.45))
	_r(2, 58, width - 4, 2, color.lightened(0.22))


func _plaque(pos: Vector2, icon: String, color: Color) -> void:
	_r(pos.x + 8, pos.y - 6, 4, 8, INK)
	_r(pos.x + 34, pos.y - 6, 4, 8, INK)
	_r(pos.x, pos.y, 46, 32, INK)
	_r(pos.x + 2, pos.y + 2, 42, 28, GOLD)
	_r(pos.x + 4, pos.y + 4, 38, 24, color)
	var p := pos + Vector2(8, 8)
	match icon:
		"anvil": _anvil(p, METAL)
		"mug":
			_r(p.x + 6, p.y, 16, 20, GOLD)
			_r(p.x + 22, p.y + 4, 8, 12, GOLD)
			_r(p.x + 24, p.y + 6, 4, 8, color)
			_r(p.x + 4, p.y - 2, 20, 6, PAPER)
			_r(p.x + 10, p.y + 6, 2, 10, PAPER)
		"book": _book(p, 30, 20)
		"fish": _fish(p + Vector2(2, 2), METAL)


func _anvil(p: Vector2, color: Color) -> void:
	_poly([p, p + Vector2(30, 0), p + Vector2(24, 8), p + Vector2(14, 8), p + Vector2(14, 14), p + Vector2(22, 16), p + Vector2(22, 20), p + Vector2(2, 20), p + Vector2(2, 16), p + Vector2(8, 14), p + Vector2(8, 8), p + Vector2(2, 8)], color)
	_r(p.x + 2, p.y, 26, 2, PAPER)
	_r(p.x + 8, p.y + 8, 6, 6, color.darkened(0.3))


func _book(p: Vector2, width: float, height: float) -> void:
	_poly([p + Vector2(0, 2), p + Vector2(width / 2, 4), p + Vector2(width, 0), p + Vector2(width, height - 2), p + Vector2(width / 2, height), p + Vector2(0, height - 2)], PAPER)
	_r(p.x + width / 2 - 1, p.y + 4, 2, height - 4, GOLD.darkened(0.2))
	for row in 3:
		_r(p.x + 4, p.y + 6 + row * 4, width / 2 - 8, 2, Color("bca77f"))
		_r(p.x + width / 2 + 4, p.y + 4 + row * 4, width / 2 - 8, 2, Color("bca77f"))


func _fish(p: Vector2, color: Color) -> void:
	_poly([p + Vector2(0, 8), p + Vector2(8, 2), p + Vector2(20, 2), p + Vector2(26, 6), p + Vector2(32, 0), p + Vector2(32, 16), p + Vector2(26, 10), p + Vector2(20, 14), p + Vector2(8, 14)], color)
	_r(p.x + 6, p.y + 6, 2, 2, INK)
	_r(p.x + 12, p.y + 4, 8, 2, PAPER)


func _smithy(width: float) -> void:
	_roof(width, Color("596578"))
	# Een hoge gemetselde schoorsteen en zacht opstijgende, blokkerige rook.
	for i in 3:
		var phase := fposmod(clock * 8.0 + i * 16.0, 48.0)
		var drift := floorf(sin(phase / 12.0 + i) * 3.0) * 2.0
		_r(width - 48 + drift, -18 - floorf(phase / 2.0) * 2.0, 12 + i * 4, 8 + i * 2, Color(0.66, 0.7, 0.73, (1.0 - phase / 48.0) * 0.55))
	_r(width - 54, -18, 36, 72, INK)
	_r(width - 50, -14, 28, 66, Color("79746f"))
	for row in 8:
		_r(width - 50, -10 + row * 8, 28, 2, Color("47494f"))
		_r(width - 42 + (row % 2) * 10, -8 + row * 8, 2, 6, Color("47494f"))
	_r(width - 58, -20, 44, 8, INK)
	_r(width - 56, -20, 40, 2, METAL)
	_plaque(Vector2(58, 60), "anvil", Color("384153"))
	# Forge-opening in de bestaande massieve rechtergevel, ver van de deur.
	_r(width - 58, 72, 50, 56, INK)
	_r(width - 56, 74, 46, 6, Color("92918a"))
	_r(width - 56, 80, 8, 40, Color("75736f"))
	_r(width - 18, 80, 8, 40, Color("62646a"))
	_r(width - 46, 84, 26, 36, Color("582c2c"))
	_r(width - 44, 104, 22, 14, Color("df633a"))
	for i in 4:
		var rise := 8 + int((sin(clock * 5.0 + i * 2.0) + 1.0) * 4.0)
		_r(width - 44 + i * 6, 114 - rise, 4, rise, Color("ffb34d"))
	_r(width - 46, 118, 28, 4, Color("f6d787"))
	_r(width - 58, 124, 50, 4, METAL.darkened(0.4))
	# Een tweede, echte aambeeldvorm naast de werkplaats maakt het beroep direct leesbaar.
	_r(12, 104, 32, 24, WOOD)
	_anvil(Vector2(12, 90), METAL)


func _shop(width: float) -> void:
	_roof(width, Color("487d64"))
	# Een brede groen-crème luifel; de doorgang eronder blijft helemaal vrij.
	_r(0, 58, width, 30, INK)
	for i in 12:
		var shade := PAPER if i % 2 == 0 else Color("54a77d")
		_r(2 + i * 16, 60, 14, 20, shade)
		_r(2 + i * 16, 80, 14, 6 + (i % 2) * 2, shade.darkened(0.18))
	_r(0, 56, width, 4, WOOD)
	# Kratten met appels en voorraad staan tegen de gevel, niet op de looproute.
	for x in [8, 124, 158]:
		_r(x, 102, 28, 26, WOOD.darkened(0.2))
		_r(x + 2, 104, 24, 6, Color("ad8050"))
		_r(x + 2, 114, 24, 4, Color("bc955f"))
		_r(x + 2, 122, 24, 4, Color("bc955f"))
		for j in 3:
			_r(x + 3 + j * 8, 96 + (j % 2) * 2, 6, 8, Color("db7653") if x == 8 else Color("89ac59"))
	# Een gouden munt boven de ingang, onafhankelijk van de gekozen taal.
	_r(74, 32, 24, 22, INK)
	_r(76, 30, 20, 24, GOLD)
	_r(80, 34, 12, 16, Color("bb8b37"))
	_r(84, 34, 4, 16, PAPER)


func _inn(width: float) -> void:
	_roof(width, Color("9f4b47"))
	# Dakkapel met verlicht slaapkamervenster en een goudkleurige nok.
	_r(92, 18, 62, 42, WOOD.darkened(0.25))
	_poly([Vector2(84, 22), Vector2(122, -6), Vector2(162, 22)], INK)
	_poly([Vector2(90, 20), Vector2(122, 0), Vector2(156, 20)], Color("c27a60"))
	_r(104, 28, 36, 30, PAPER)
	_r(108, 32, 28, 24, Color("c4a870"))
	_r(120, 32, 4, 24, WOOD)
	_r(108, 42, 28, 4, WOOD)
	_r(0, 0, width, 4, GOLD.darkened(0.15))
	_plaque(Vector2(132, 78), "mug", Color("763e49"))
	# Stevige bier-/watervaten onder de linker ramen.
	for x in [10, 42]:
		_r(x + 2, 100, 26, 28, WOOD)
		_r(x, 104, 30, 20, Color("a97944"))
		_r(x, 106, 30, 4, METAL.darkened(0.35))
		_r(x, 120, 30, 4, METAL.darkened(0.35))
		_r(x + 10, 110, 2, 10, GOLD.darkened(0.3))


func _fisher(width: float) -> void:
	_roof(width, Color("54858a"))
	# Rietbundels langs de nok en een hengel die boven het dak uitsteekt.
	for x in range(4, int(width - 2), 8):
		_r(x, 2, 4, 12 + (x % 3) * 2, Color("b1b383"))
	_r(width - 26, -18, 4, 76, WOOD)
	_r(width - 62, -18, 42, 4, WOOD)
	_r(width - 60, -14, 2, 30, PAPER)
	_fish(Vector2(width - 76, 14), METAL)
	_plaque(Vector2(56, 60), "fish", Color("315e69"))
	# Gedroogd net en touwen op de muur rechts; de deur en de stoep blijven vrij.
	_r(120, 78, 62, 44, WOOD)
	_r(124, 80, 54, 38, Color("3c5b60"))
	for x in range(124, 180, 8):
		_r(x, 80, 2, 38, Color("b9b899"))
	for y in range(80, 120, 8):
		_r(124, y, 54, 2, Color("b9b899"))
	for x in [14, 22, 30]:
		_r(x, 106 - (x % 3) * 2, 6, 18, GOLD.darkened(0.2))
	_r(12, 124, 28, 4, WOOD)


func _library(width: float) -> void:
	_roof(width, Color("605486"))
	# Een brede klassieke gevelpunt en boekreliëf; duidelijk anders dan de woonhuizen.
	_poly([Vector2(92, 44), Vector2(144, 2), Vector2(196, 44)], INK)
	_poly([Vector2(100, 40), Vector2(144, 8), Vector2(188, 40)], Color("9e93b3"))
	_r(100, 42, 88, 16, PAPER)
	_book(Vector2(128, 22), 32, 24)
	for x in [2, int(width - 18)]:
		_r(x, 66, 16, 62, Color("c6b991"))
		_r(x + 2, 70, 4, 54, PAPER)
		_r(x - 2, 64, 20, 6, GOLD)
		_r(x - 2, 122, 20, 6, GOLD)
	_plaque(Vector2(180, 84), "book", Color("554469"))
	# Gekleurde boekruggen in een gevelkast.
	_r(26, 98, 54, 30, WOOD)
	for i in 6:
		var color: Color = [Color("a95560"), Color("5594ad"), Color("86a969")][i % 3]
		_r(30 + i * 8, 102 + (i % 2) * 4, 6, 20 - (i % 2) * 4, color)
		_r(30 + i * 8, 106 + (i % 2) * 4, 6, 2, PAPER)
	_r(26, 124, 54, 4, GOLD.darkened(0.3))


func _banner(x: float, y: float, color: Color) -> void:
	_r(x, y, 26, 4, GOLD)
	_poly([Vector2(x + 2, y + 4), Vector2(x + 24, y + 4), Vector2(x + 24, y + 38), Vector2(x + 13, y + 46), Vector2(x + 2, y + 38)], color)
	_r(x + 5, y + 6, 2, 30, color.lightened(0.24))
	_r(x + 12, y + 10, 4, 24, PAPER)
	_r(x + 7, y + 26, 14, 4, GOLD)
	_r(x + 12, y + 34, 4, 4, GOLD)


func _arena(width: float) -> void:
	# Kantelen en kleine wachttorens vormen een echt toernooigebouw.
	for x in [0, int(width - 38)]:
		_r(x, -12, 38, 74, INK)
		_r(x + 2, -10, 34, 68, Color("b19a77"))
		for y in range(0, 56, 10):
			_r(x + 2, y, 34, 2, Color("806a53"))
		_r(x + 12, 10, 12, 24, INK)
		_r(x + 16, 12, 4, 20, Color("777d83"))
		for tooth in 3:
			_r(x + tooth * 14, -18, 10, 10, Color("d9c5a0"))
	_r(38, 0, width - 76, 6, PAPER)
	for x in range(42, int(width - 40), 20):
		_r(x, -8, 12, 10, Color("d9c5a0"))
	_banner(48, 20, Color("91495d"))
	_banner(width - 74, 20, Color("435f97"))
	# Gekruiste zwaarden boven de bestaande toegang.
	_poly([Vector2(90, 22), Vector2(96, 18), Vector2(126, 48), Vector2(120, 52)], METAL)
	_poly([Vector2(126, 22), Vector2(120, 18), Vector2(90, 48), Vector2(96, 52)], PAPER)
	_r(88, 46, 14, 4, GOLD)
	_r(116, 46, 14, 4, GOLD)


func _crystal(p: Vector2, width: float, height: float) -> void:
	_poly([p + Vector2(width / 2, 0), p + Vector2(width, height * 0.35), p + Vector2(width * 0.8, height * 0.8), p + Vector2(width / 2, height), p + Vector2(0, height * 0.7), p + Vector2(0, height * 0.3)], Color("69cce6"))
	_poly([p + Vector2(width / 2, 0), p + Vector2(width / 2, height), p + Vector2(0, height * 0.7), p + Vector2(0, height * 0.3)], Color("adeef2"))
	_r(p.x + width / 2, p.y + height * 0.2, 2, height * 0.6, Color("e0ffff"))


func _temple(width: float) -> void:
	# Een trapsgewijs heiligdom, met dezelfde oude toegang op de onderste rij.
	_r(8, 6, width - 16, 16, Color("aacce2"))
	_r(16, 24, width - 32, 10, Color("365d91"))
	_r(32, 38, width - 64, 8, Color("abcde4"))
	for x in [18, int(width - 46)]:
		_r(x, 54, 28, 136, Color("315487"))
		_r(x + 4, 54, 8, 132, Color("a2c6e6"))
		_r(x - 4, 48, 36, 10, Color("c9e2ef"))
		_r(x - 4, 180, 36, 12, Color("7aadd8"))
		_crystal(Vector2(x - 4, 8), 36, 42)
	# De Blauwe Kaart als fonkelend reliëf: drie kristallen rond de grote spits.
	_r(width / 2 - 62, 76, 124, 70, Color("345588"))
	_r(width / 2 - 58, 80, 116, 62, Color("497cab"))
	_crystal(Vector2(width / 2 - 22, 28), 44, 84)
	_crystal(Vector2(width / 2 - 52, 82), 26, 42)
	_crystal(Vector2(width / 2 + 26, 82), 26, 42)
	_r(width / 2 - 50, 146, 100, 10, Color("bddded"))
	# De stenen deurposten staan naast de doorgang van twee tegels.
	_r(_door.position.x - 10, 156, 8, 36, Color("bad7e8"))
	_r(_door.end.x + 2, 156, 8, 36, Color("bad7e8"))
