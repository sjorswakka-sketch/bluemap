extends StaticBody2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
var body: CollisionShape2D
func _ready():
 add_to_group("coast_adventures")
 collision_layer=1;collision_mask=0
 if obj.role in ["wheel","harbor_wheel","record","pilot","entrance","rock","sluice","shelter"]:
  body=CollisionShape2D.new();var shape:=RectangleShape2D.new()
  shape.size=Vector2(14,8) if obj.role=="entrance" else Vector2(58,8) if obj.role=="shelter" else Vector2(34,10) if obj.role in ["wheel","harbor_wheel","sluice","record"] else Vector2(22,8)
  body.shape=shape;body.position=Vector2(0,8 if obj.role=="entrance" else 5 if obj.role=="shelter" else 10 if obj.role in ["record","rock"] else 17);body.disabled=body_hidden();add_child(body)
 if obj.role not in ["buoy","harbor_wheel"]:add_to_group("interactable")
func body_hidden() -> bool:
 return (obj.role=="harbor_wheel" and not GameState.flag("ad_workwater")) or (obj.role=="shelter" and not GameState.flag("ad_pilot_done"))
func label() -> String:
 match obj.role:
  "message":return tr("Aangespoeld logboek")
  "splinter":return tr("Breuksporen in het wrakhout")
  "silt":return tr("Afzetting aan de oever")
  "record":return tr("Werkboek van de haven")
  "pilot":return tr("De oude loodsenroute")
  "rock":return tr("Gespleten rots")
  "grass":return tr("Bleek zoutgras")
  "shelter":return tr("Beschutte rustplek")
  "entrance":return tr("Zijgrot · Tijholte")
  "wheel":return tr("Vastgelopen tijrad")
  "keeper_rest":return tr("Rustende Schelpenhoeder")
 return tr("Sluistafel · Schelpenhoeder")
func interact():
 if GameState.input_locked():return
 var ui: CanvasLayer=load("res://scripts/ui/coastal_adventure_ui.gd").new()
 ui.world=world;world.add_child(ui);ui.open(self)
func _process(delta: float):
 time+=delta;queue_redraw()
 if body!=null and body.disabled!=body_hidden():body.set_deferred("disabled",body_hidden())
 if obj.role=="keeper_rest":
  var hidden: bool=GameState.flag("ad_duel") or GameState.flag("ad_workwater")
  if hidden and is_in_group("interactable"):remove_from_group("interactable")
  elif not hidden and not is_in_group("interactable"):add_to_group("interactable")
func _draw():
 var role: String=obj.role
 if role=="entrance":
  DrawUtil.ellipse(self,Vector2(0,14),Vector2(9,3),Color(0,0,0,.25))
  DrawUtil.sprite(self,Art.tex("sign"),0,0)
  if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-24),time)
  return
 if role=="keeper_rest":
  if not GameState.flag("ad_duel") and not GameState.flag("ad_workwater"):
   DrawUtil.sprite(self,Art.tex("ad_keeper"),int(time*0.8)%2,0,Vector2(0,sin(time)*1.5),Vector2i(24,24),2.8)
   if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-43),time)
  return
 if role=="buoy" and not GameState.flag("ad_message_done"):return
 if role=="harbor_wheel" and not GameState.flag("ad_workwater"):return
 var frame: int={"message":0,"splinter":1,"silt":2,"record":3,"pilot":4,"rock":5,"grass":6,"shelter":7,"entrance":8,"wheel":9,"sluice":10,"buoy":11,"harbor_wheel":9}.get(role,0)
 var scale: float=2.0 if role in ["wheel","harbor_wheel"] else 1.25 if role in ["message","splinter","silt","grass","rock"] else 1.5
 if not (role=="shelter" and GameState.flag("ad_pilot_done")):DrawUtil.sprite(self,Art.tex("ad_props"),frame,0,Vector2.ZERO,Vector2i(32,32),scale)
 if role in ["wheel","harbor_wheel"]:
  var turning: bool=role=="harbor_wheel" or GameState.flag("ad_wheel_done")
  var angle: float=time*0.7 if turning else 0
  for i in 6:
   draw_line(Vector2(0,-2),Vector2.from_angle(angle+i*TAU/6)*18+Vector2(0,-2),Color("d5b97f"),3)
 if role=="shelter" and GameState.flag("ad_pilot_done"):
  draw_line(Vector2(-28,-8),Vector2(28,-8),Color("ad9972"),11)
  draw_line(Vector2(-28,-8),Vector2(-28,9),Color("5a5143"),3)
  draw_line(Vector2(28,-8),Vector2(28,9),Color("5a5143"),3)
 if role=="sluice" and GameState.flag("ad_pool"):
  for i in 5:draw_line(Vector2(24+i*5,8),Vector2(25+i*5,-10-sin(time+i)*3),Color("7bba9d"),2)
 if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-38),time)
