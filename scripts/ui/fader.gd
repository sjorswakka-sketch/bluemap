extends CanvasLayer
## Een zwart scherm voor zachte overgangen tussen kaarten.

var rect: ColorRect
var tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func set_alpha(alpha: float) -> void:
	rect.color.a = alpha


func fade_out(duration: float) -> void:
	await _fade(1.0, duration)


func fade_in(duration: float) -> void:
	await _fade(0.0, duration)


func _fade(target: float, duration: float) -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", target, duration)
	await tween.finished
