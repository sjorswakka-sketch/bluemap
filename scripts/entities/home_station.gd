extends StaticBody2D
const Farm:=preload("res://scripts/core/homestead.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
func _ready():
 add_to_group("home_stations");collision_layer=1;collision_mask=0
 # Leave the original coin beside the heap completely visible.
 if obj.role=="compost":position.x-=12
 if obj.role not in ["fall","shelf","table"]:add_to_group("interactable")
 var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(60,36) if obj.role=="compost" else Vector2(34,48) if obj.role=="bed" else Vector2(60,22) if obj.role in ["shelf","table"] else Vector2(25,14);shape.shape=rectangle;shape.position.y=-6 if obj.role=="bed" else 5;add_child(shape)
func label() -> String:return load("res://scripts/ui/home_ui.gd").station_name(obj.role)
func interact():
 if GameState.input_locked() or world.player.position.distance_to(position)>55:return
 var ui: CanvasLayer=load("res://scripts/ui/home_ui.gd").new();ui.world=world;world.add_child(ui);ui.open(self)
func _process(delta: float):time+=delta;queue_redraw()
func _draw():
 match obj.role:
  "compost":
   draw_rect(Rect2(-31,-23,62,48),Color("5b513d"));draw_circle(Vector2(-10,-4),19,Color("695136"));draw_circle(Vector2(12,-5),20,Color("806341"))
   for x in [-20,2,20]:draw_line(Vector2(x,4),Vector2(x+3,-5),Color("baa36b"),3)
   draw_rect(Rect2(-33,13,66,7),Color("a98d61"));draw_line(Vector2(-18,-25),Vector2(-15,-31+sin(time)*3),Color("a5b8a2"),2)
  "wine":
   draw_style_box(preload("res://scripts/core/ui_style.gd").flat(Color("9b7049"),Color("4d3c31"),2),Rect2(-17,-27,34,42))
   for y in [-20,4]:draw_rect(Rect2(-17,y,34,5),Color("73828a"))
   draw_line(Vector2(0,-25),Vector2(0,13),Color("bd9360"),2);draw_circle(Vector2(11,4),3,Color("d7b778"))
  "hive":
   for y in [-22,-11,0]:draw_rect(Rect2(-18,y,36,9),Color("d6ad60"));draw_rect(Rect2(-18,y+7,36,2),Color("8e683c"))
   draw_line(Vector2(-23,-24),Vector2(0,-34),Color("624b35"),5);draw_line(Vector2(0,-34),Vector2(23,-24),Color("624b35"),5)
   draw_rect(Rect2(-7,1,14,5),Color("352f2b"))
   if Farm.flowers()>=3:
    for i in 3:
     var at:=Vector2(sin(time*1.5+i*2)*38,cos(time*2+i*2)*19-17);draw_circle(at+Vector2(0,-2),2,Color("dce4d1"));draw_line(at-Vector2(3,0),at+Vector2(3,0),Color("e6bd5d"),3);draw_line(at,at+Vector2(1,0),Color("3d392f"),3)
  "bed":
   draw_rect(Rect2(-18,-32,36,52),Color("a78258"));draw_rect(Rect2(-15,-28,30,10),Color("ede2c4"));draw_rect(Rect2(-15,-16,30,32),Color("72989a"))
  "shelf":
   draw_rect(Rect2(-32,-26,64,42),Color("795637"))
   for y in [-21,-3]:
    for i in 7:draw_rect(Rect2(-26+i*8,y,5,13),[Color("71958a"),Color("b8956e"),Color("8a7e9e")][i%3])
    draw_rect(Rect2(-29,y+13,58,3),Color("bb9762"))
  "table":
   draw_rect(Rect2(-26,8,6,12),Color("654936"));draw_rect(Rect2(20,8,6,12),Color("654936"));draw_rect(Rect2(-32,-17,64,30),Color("a57b50"));draw_rect(Rect2(-29,-14,58,24),Color("bb9565"))
   draw_rect(Rect2(-19,-10,8,13),Color("729988"));draw_circle(Vector2(13,-4),6,Color("e6d9b4"));draw_circle(Vector2(13,-4),3,Color("8f7150"))
  "fall":
   draw_colored_polygon(PackedVector2Array([Vector2(-30,9),Vector2(-27,-23),Vector2(-20,-42),Vector2(-9,-38),Vector2(-12,17)]),Color("60736a"))
   draw_colored_polygon(PackedVector2Array([Vector2(10,-38),Vector2(21,-43),Vector2(28,-25),Vector2(30,15),Vector2(12,19)]),Color("78897a"))
   draw_line(Vector2(-23,-27),Vector2(-18,-34),Color("92a189"),4);draw_line(Vector2(21,-29),Vector2(23,-15),Color("9cac95"),4)
   draw_rect(Rect2(-12,-36,24,60),Color("4b96ad"));draw_rect(Rect2(-8,-36,16,58),Color("79c3cd"))
   for i in 6:
    var y: float=-34+fmod(time*45+i*10,56);draw_line(Vector2(-7,y),Vector2(-5,y+6),Color("c8e7df"),2);draw_line(Vector2(4,y-3),Vector2(6,y+2),Color("b0dee0"),2)
   for i in 5:
    var x: float=-14+i*7;draw_circle(Vector2(x,21+sin(time*3+i)*2),3,Color("d5e6d9"))
   draw_arc(Vector2(0,21),17+sin(time*2),0,PI,12,Color("9fd5d8"),2)
  "wild_grape":
   for x in [-15,0,15]:draw_circle(Vector2(x,-9),14,Color("527856"))
   if GameState.play_time>=Farm.state().wild_due:
    for at in [Vector2(-12,-8),Vector2(4,-15),Vector2(12,-3)]:draw_circle(at,4,Color("a37abe"))
  _:
   draw_rect(Rect2(-15,-24,30,36),Color("a77e4f"));draw_rect(Rect2(-12,-21,24,26),Color("e0ce9e"));draw_line(Vector2(-8,-11),Vector2(8,-11),Color("607365"),3);draw_line(Vector2(-8,-3),Vector2(5,-3),Color("607365"),2)
 if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-49 if obj.role=="compost" else -40),time)
