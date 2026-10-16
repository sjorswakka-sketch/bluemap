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
 if GameState.map_id=="player_home" and obj.role in ["bed","table","shelf"]:refresh_home()
 if GameState.map_id=="village" and load("res://scripts/core/yard.gd").unit_of(obj)!="":refresh_yard()
func label() -> String:return load("res://scripts/ui/home_ui.gd").station_name(obj.role)
func interact():
 if not is_visible_in_tree() or GameState.input_locked() or world.player.position.distance_to(position)>55:return
 var ui: CanvasLayer=load("res://scripts/ui/home_ui.gd").new();ui.world=world;world.add_child(ui);ui.open(self)
func _process(delta: float):time+=delta;queue_redraw()
func refresh_home():
 var house: Script=load("res://scripts/core/personal_home.gd")
 var entry: Dictionary=house.state().layout[obj.role]
 position=house.world_position(entry)
 for child in get_children():
  if child is CollisionShape2D:
   child.shape.size=Vector2(house.Catalog.PIECES[entry.kind].size)*32-Vector2(4,4)
   child.position=Vector2(0,16-Vector2(house.Catalog.PIECES[entry.kind].size).y*16)
 queue_redraw()
func _draw():
 if GameState.map_id=="player_home" and obj.role in ["bed","table","shelf"]:
  var entry: Dictionary=load("res://scripts/core/personal_home.gd").state().layout[obj.role]
  var dims: Vector2=Vector2(load("res://scripts/data/house_catalog.gd").PIECES[entry.kind].size)*32
  load("res://scripts/core/house_art.gd").draw_piece(self,entry,Vector2(-dims.x/2,16-dims.y))
  if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-dims.y-2),time)
  return
 match obj.role:
  "compost":
   draw_rect(Rect2(-31,-23,62,48),Color("5b513d"));draw_circle(Vector2(-10,-4),19,Color("695136"));draw_circle(Vector2(12,-5),20,Color("806341"))
   for x in [-20,2,20]:draw_line(Vector2(x,4),Vector2(x+3,-5),Color("baa36b"),3)
   draw_rect(Rect2(-33,13,66,7),Color("a98d61"));draw_line(Vector2(-18,-25),Vector2(-15,-31+sin(time)*3),Color("a5b8a2"),2)
  "wine":
   draw_texture(preload("res://scripts/core/art.gd").tex("pixel_station_wine"),Vector2(-40,-47))
  "hive":
   draw_texture(preload("res://scripts/core/art.gd").tex("pixel_station_hive"),Vector2(-40,-47))
   _bees()
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
 # Small physical status marks replace floating notifications at working stations.
 if obj.role in ["compost","wine","hive"]:
  var id: String="compost" if obj.role=="compost" else "hive" if obj.role=="hive" else obj.unit
  var progress:=-1.0
  if id=="hive":
   if Farm.state().honey>0:progress=1.0
   elif Farm.flowers()>=3:progress=float(Farm.state().honey_time)/120
  elif Farm.state().jobs.has(id):progress=float(Farm.state().jobs[id].time)/Farm.JOBS[id].seconds
  if progress>=0:
   var y:=17.0 if id!="compost" else 24.0
   draw_rect(Rect2(-13,y,26,4),Color("354944"));draw_rect(Rect2(-12,y+1,24*minf(progress,1),2),Color("b5cf9a") if progress>=1 else Color("d3b579"))
   if progress>=1:draw_line(Vector2(7,y-7),Vector2(10,y-4),Color("dbe9b3"),2);draw_line(Vector2(10,y-4),Vector2(15,y-10),Color("dbe9b3"),2)
 if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-49 if obj.role=="compost" else -40),time)

func _bees():
 if Farm.flowers()<3:return
 for i in 3:
  var at:=(Vector2(sin(time*1.5+i*2)*35,cos(time*2+i*2)*17-17)).round()
  draw_rect(Rect2(at+Vector2(-1,-3),Vector2(3,2)),Color("dce4d1"))
  draw_rect(Rect2(at+Vector2(-3,0),Vector2(6,2)),Color("d6b66a"))
  draw_rect(Rect2(at,Vector2(1,2)),Color("384236"))

func refresh_yard():
 var yard: Script=load("res://scripts/core/yard.gd");var id: String=yard.unit_of(obj);var at: Vector2i=yard.anchor(id)
 visible=at.x>=0;collision_layer=1 if visible else 0
 for child in get_children():
  if child is CollisionShape2D:child.disabled=not visible
 if visible:
  position=Vector2(at)*32+Vector2(16,16)
  if id=="compost":position.x-=12
  if not is_in_group("interactable"):add_to_group("interactable")
 elif is_in_group("interactable"):remove_from_group("interactable")
 queue_redraw()
