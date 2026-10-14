extends Node2D
## The floor marker matches the committed destination and actual impact radius.
var king: WeakRef
func _ready() -> void:add_to_group("king_warnings")
func _process(_delta: float) -> void:
	var enemy: Variant=king.get_ref() if king!=null else null
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():queue_free();return
	visible=enemy.active and not enemy.dead and enemy.state in ["crouch","hop"]
	if visible:global_position=enemy.hop_to;queue_redraw()
func _draw() -> void:
	var enemy: Variant=king.get_ref() if king!=null else null
	if not is_instance_valid(enemy):return
	var radius: float=enemy.king_shock()
	var duration: float=enemy.king_charge_time() if enemy.state=="crouch" else enemy.king_hop_time()
	var progress: float=clampf(enemy.state_time/duration,0,1)
	draw_circle(Vector2.ZERO,radius,Color(1,0.55,0.22,0.10))
	draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(1,0.72,0.35,0.9),2)
	draw_arc(Vector2.ZERO,radius*(1-progress),0,TAU,48,Color(1,0.86,0.5,0.5),1)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(direction*(radius-5),direction*(radius+4),Color(1,0.85,0.55),2)
	draw_line(Vector2(-5,0),Vector2(5,0),Color(1,0.8,0.4),1)
	draw_line(Vector2(0,-5),Vector2(0,5),Color(1,0.8,0.4),1)
