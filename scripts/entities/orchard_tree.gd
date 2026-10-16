extends StaticBody2D
const Farm:=preload("res://scripts/core/homestead.gd")
const Paint:=preload("res://scripts/core/orchard_art.gd")
var world: Node2D
var cell:=Vector2i.ZERO
var time:=0.0
var canopy_alpha:=1.0
func _ready():
 add_to_group("orchard_trees");position=Vector2(cell)*32+Vector2(16,16);collision_layer=1;collision_mask=0
 var collider:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(10,8);collider.shape=rectangle;collider.position=Vector2(0,9);add_child(collider)
func _process(delta: float):
 if is_queued_for_deletion():return
 time+=delta
 var near:=Rect2(Vector2(-34,-50),Vector2(68,54)).has_point(world.player.position-position)
 canopy_alpha=move_toward(canopy_alpha,.42 if near else 1.0,delta*3)
 queue_redraw()
func _draw():
 var e: Dictionary=Farm.state().cells.get(Farm.key(cell),{})
 if e.get("crop","")!="apple":return
 draw_ellipse_shadow()
 Paint.tree(self,Vector2.ZERO,e,time,canopy_alpha)
func draw_ellipse_shadow():
 draw_set_transform(Vector2(0,10),0,Vector2(1,.35));draw_circle(Vector2.ZERO,15,Color(.15,.23,.18,.22));draw_set_transform(Vector2.ZERO)
