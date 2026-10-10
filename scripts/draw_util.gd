extends RefCounted
## Kleine tekenhulpjes zodat we geen plaatjes nodig hebben voor het prototype.


## Tekent een hartje met het midden op `center`. `size` is ongeveer de halve breedte.
static func heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 28:
		var t := TAU * float(i) / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(center + Vector2(x, y) * (size / 16.0))
	canvas.draw_colored_polygon(points, color)


## Gevulde ellips (gebruikt voor schaduwen en slijmen).
static func ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var t := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	canvas.draw_colored_polygon(points, color)
