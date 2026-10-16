extends StaticBody2D
const House:=preload("res://scripts/core/personal_home.gd")
const Catalog:=preload("res://scripts/data/house_catalog.gd")
const Paint:=preload("res://scripts/core/house_art.gd")
const Art:=preload("res://scripts/core/art.gd")
var world: Node2D
var entry: Dictionary={}
var lamp: PointLight2D
var time:=0.0
func _ready():
 add_to_group("house_furniture");collision_layer=1;collision_mask=0;position=House.world_position(entry)
 var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new()
 rectangle.size=Vector2(Catalog.PIECES[entry.kind].size)*32-Vector2(4,4);shape.shape=rectangle
 shape.position=Vector2(0,16-Vector2(Catalog.PIECES[entry.kind].size).y*16);add_child(shape)
 if entry.kind=="lamp":
  lamp=PointLight2D.new();lamp.texture=Art.light_texture();lamp.position=Vector2(0,-30);lamp.texture_scale=1.8;lamp.energy=.23;add_child(lamp)
func _process(delta: float):
 if lamp!=null:
  time+=delta;lamp.enabled=House.state().light<2;lamp.color=Color("efd39a") if House.state().light==0 else Color("9dd0d0");lamp.energy=.22+sin(time*.9)*.012;queue_redraw()
func _draw():
 var dims: Vector2=Vector2(Catalog.PIECES[entry.kind].size)*32
 Paint.draw_piece(self,entry,Vector2(-dims.x/2,16-dims.y))
 if entry.kind=="lamp" and House.state().light<2:
  draw_circle(Vector2(0,-31),2,Color("f0dbad") if House.state().light==0 else Color("b0dcda"))
