extends CanvasLayer
## Altijd hetzelfde mikpunt voor muis en controller, boven de wereld en onder menu's.

var player: Node2D
var canvas: Control


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_crosshair)
	add_child(canvas)


func _process(_delta: float) -> void:
	visible = is_instance_valid(player) and GameState.in_game and not GameState.input_locked()
	if visible:
		canvas.queue_redraw()


func _draw_crosshair() -> void:
	if not is_instance_valid(player):
		return
	var point: Vector2 = player.get_global_transform_with_canvas() * player.to_local(player.aim_position)
	point = point.clamp(Vector2(10, 10), canvas.get_viewport_rect().size - Vector2(10, 10))
	var tint := Color(0.85, 0.96, 1.0, 0.95)
	canvas.draw_circle(point, 2.0, Color(0.02, 0.04, 0.08, 0.9))
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		canvas.draw_line(point + direction * 4.0, point + direction * 10.0, Color(0.02, 0.04, 0.08, 0.95), 4.0)
		canvas.draw_line(point + direction * 5.0, point + direction * 9.0, tint, 2.0)
	if is_instance_valid(player.target):
		var target_point: Vector2 = player.get_global_transform_with_canvas() * player.to_local(player.target.global_position + Vector2(0, 5))
		canvas.draw_arc(target_point, 14.0, 0, TAU, 24, Color(1.0, 0.87, 0.4, 0.75), 2.0)
