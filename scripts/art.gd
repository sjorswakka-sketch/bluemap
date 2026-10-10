extends RefCounted
## Laadt de pixel art uit assets/ (gemaakt met tools/make_art.py, maar je mag ze vervangen).

static var _cache := {}


static func tex(art_name: String) -> Texture2D:
	if _cache.has(art_name):
		return _cache[art_name]
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
