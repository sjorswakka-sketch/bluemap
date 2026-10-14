extends Node2D
## Ground layer: world-space footprint stays beneath the actors, never above faces.
var enemy: WeakRef
func _process(_delta: float) -> void:
 var foe: Node2D=enemy.get_ref()
 if not is_instance_valid(foe) or foe.is_queued_for_deletion():queue_free();return
 queue_redraw()
func _draw() -> void:
 var foe: Node2D=enemy.get_ref()
 if not is_instance_valid(foe) or foe.dead:return
 preload("res://scripts/entities/habitat_enemy.gd").draw_ground(self,foe)
