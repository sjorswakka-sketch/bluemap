extends RefCounted
## Kleine tekenhulpjes.


## Tekent vakje (`col`, `row`) uit een spritesheet, met het midden op `center`.
## Elk vakje is `cell` pixels groot en wordt `scale` keer vergroot (pixel art: 16x16 -> 32x32).
static func sprite(canvas: CanvasItem, texture: Texture2D, col: int, row: int,
		center := Vector2.ZERO, cell := Vector2i(16, 16), scale := 2.0, tint := Color.WHITE) -> void:
	var size := Vector2(cell) * scale
	var source := Rect2(Vector2(col * cell.x, row * cell.y), Vector2(cell))
	canvas.draw_texture_rect_region(texture, Rect2(center - size / 2.0, size), source, tint)


## Gevulde ellips (gebruikt voor schaduwen).
static func ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var t := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	canvas.draw_colored_polygon(points, color)


## Het "E"-bolletje boven iets waar je mee kunt praten of dat je kunt openen.
static func prompt(canvas: CanvasItem, offset: Vector2, time: float, label := "E") -> void:
	var bob := sin(time * 5.0) * 2.0
	canvas.draw_rect(Rect2(offset.x - 9, offset.y - 8 + bob, 18, 16), Color(0, 0, 0, 0.75))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(offset.x - 4, offset.y + 4 + bob), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## Naam boven een personage.
static func name_tag(canvas: CanvasItem, offset: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	canvas.draw_string_outline(font, offset + Vector2(-width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0, 0, 0, 0.9))
	canvas.draw_string(font, offset + Vector2(-width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1))
