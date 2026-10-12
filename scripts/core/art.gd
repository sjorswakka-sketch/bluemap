extends RefCounted
## Laadt de pixel art uit assets/ (gemaakt met tools/make_art.py, maar je mag ze vervangen).

static var _cache := {}


static func tex(art_name: String) -> Texture2D:
	if _cache.has(art_name):
		return _cache[art_name]
	if art_name == "items_equipment":
		var equipment_texture := preload("res://scripts/core/equipment_art.gd").texture()
		_cache[art_name] = equipment_texture
		return equipment_texture
	var path := "res://assets/%s.png" % art_name
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	if texture == null:
		# Projecten die nog niet door Godot zijn geïmporteerd: lees het bestand gewoon rechtstreeks.
		var img := Image.load_from_file(path)
		if img != null:
			texture = ImageTexture.create_from_image(img)
	if texture == null:
		push_error("Kan %s niet laden. Draai 'python3 tools/make_art.py' of open het project in de Godot-editor." % path)
		texture = ImageTexture.create_from_image(Image.create_empty(16, 16, false, Image.FORMAT_RGBA8))
	_cache[art_name] = texture
	return texture


## Zachte ronde lichtvlek voor fakkels en het licht van de speler (in donkere gebieden).
static func light_texture() -> Texture2D:
	if _cache.has("_light"):
		return _cache["_light"]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_cache["_light"] = texture
	return texture
