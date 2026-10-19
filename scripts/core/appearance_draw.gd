extends RefCounted
## Compatibility entry points shared by the world character and appearance preview.
## Every mask is original native 32px artwork; the public box remains 16*px.
const Native := preload("res://scripts/core/character_layers.gd")

static func behind(canvas: CanvasItem, origin: Vector2, px: float, row: int, clothing: Dictionary) -> void:
	Native.behind(canvas,origin,px,row,clothing)

static func front(canvas: CanvasItem, origin: Vector2, px: float, row: int, column: int, appearance: Dictionary, clothing: Dictionary) -> void:
	Native.front(canvas,origin,px,row,column,appearance,clothing)
