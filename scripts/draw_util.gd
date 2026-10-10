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
