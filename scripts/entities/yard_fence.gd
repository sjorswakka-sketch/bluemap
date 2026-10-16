extends StaticBody2D
const Art:=preload("res://scripts/core/yard_art.gd")
var world: Node2D
var cell:=Vector2i.ZERO
var kind:=""
var opened:=false
var openness:=0.0
var shape: CollisionShape2D
func _ready():
 add_to_group("yard_fences");position=Vector2(cell)*32+Vector2(16,16);collision_layer=1;collision_mask=0
 shape=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();var vertical:=kind.ends_with("_v")
 rectangle.size=Vector2(6,28) if vertical else Vector2(28,6);shape.position=Vector2(8,0) if vertical else Vector2(0,8);shape.shape=rectangle;add_child(shape)
 if kind.begins_with("gate") and world.player.position.distance_to(position)<64:opened=true;openness=1;shape.disabled=true
func _physics_process(_delta: float):
 if is_queued_for_deletion() or not kind.begins_with("gate"):return
 var distance: float=world.player.position.distance_to(position)
 var next: bool=distance<64 if not opened else distance<82
 if next!=opened:
  opened=next;shape.set_deferred("disabled",opened);Sound.play("yard_gate",-20)
func _process(delta: float):
 if kind.begins_with("gate"):
  openness=move_toward(openness,1.0 if opened else 0.0,delta*5);queue_redraw()
func _draw():Art.fence(self,Vector2(-16,-16),kind,openness)
