extends StaticBody2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
var lamp: PointLight2D
func _ready():
 if obj.role=="door":
  var tiles: Array=obj.get("size",[1,1])
  position+=Vector2(tiles[0]-1,tiles[1]-1)*16
 add_to_group("coastal_workstations");collision_layer=1;collision_mask=0
 if obj.role!="window":add_to_group("interactable")
 if obj.role in ["bench","storage","layout","lamp","shelf","line"]:
  var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new()
  rect.size=Vector2(50,10) if obj.role in ["bench","layout","shelf"] else Vector2(26,10)
  shape.shape=rect;shape.position=Vector2(0,12);add_child(shape)
 if obj.role=="lamp":
  lamp=PointLight2D.new();lamp.texture=Art.light_texture();lamp.position=Vector2(0,-18);lamp.texture_scale=1.8;add_child(lamp)
func label() -> String:
 match obj.role:
  "door":return tr("Rafs havenwerkplaats")
  "bench":return tr("Werkbank en kustpatronen")
  "storage":return tr("Materiaalkist")
  "layout","shelf","lamp":return tr("Werkplaats inrichten")
  "line":return tr("Oeverlijn · korte rivierroute")
  "practice":return tr("Proefopstelling · kuststijlen")
 return ""
func interact():
 if GameState.input_locked() or position.distance_to(world.player.position)>40:return
 var ui: CanvasLayer=load("res://scripts/ui/coastal_home_ui.gd").new();ui.world=world;world.add_child(ui);ui.open(self)
func _process(delta: float):
 time+=delta;queue_redraw()
 if lamp!=null:
  lamp.enabled=GameState.count("cw_lamp")>0 and GameState.flag("cw_lamp_on")
  lamp.color=Color("83d8dd") if GameState.flag("cw_lamp_sea") else Color("efd29e");lamp.energy=.32
func _draw():
 var frame: int={"bench":0,"storage":1,"layout":2,"shelf":3,"lamp":4,"window":5,"door":6,"line":7,"practice":8}.get(obj.role,0)
 if obj.role=="shelf" and not (GameState.count("cw_shelf")>0 and GameState.flag("cw_shelf_placed")):frame=9
 if obj.role=="lamp":
  if GameState.count("cw_lamp")==0:frame=10
  elif not GameState.flag("cw_lamp_on"):frame=11
 if obj.role=="door":DrawUtil.sprite(self,Art.tex("cw_entry"),0,0,Vector2(0,-16),Vector2i(32,32),2.0)
 else:DrawUtil.sprite(self,Art.tex("cw_props"),frame,0,Vector2(0,-10),Vector2i(64,48),1.25)
 if obj.role=="bench":
  draw_line(Vector2(5,-14),Vector2(20+sin(time*1.1)*3,-10),Color("cbb88c"),1.5)
 if obj.role=="line":draw_line(Vector2(0,-14),Vector2(15*sin(time*.7),-16),Color("c5baa1"),1)
 if obj.role!="window" and world.player.target==self:DrawUtil.prompt(self,Vector2(0,-65 if obj.role=="door" else -45),time)
