extends Node2D
const Water:=preload("res://scripts/core/water_features.gd")
const Art:=preload("res://scripts/core/water_art.gd")
var world: Node2D
var time:=0.0
var draw_wait:=0.0
var rest_time:=0.0
var info: PanelContainer
var caption: Label
func _ready():
 var layer:=CanvasLayer.new();layer.layer=5;add_child(layer)
 info=PanelContainer.new();info.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(info)
 var style:=StyleBoxFlat.new();style.bg_color=Color(.06,.13,.16,.87);style.border_color=Color(.48,.65,.63,.7);style.set_border_width_all(1);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=8;style.content_margin_bottom=8;info.add_theme_stylebox_override("panel",style)
 caption=Label.new();caption.add_theme_font_size_override("font_size",14);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(caption)
func _process(delta: float):
 time+=delta;draw_wait+=delta
 var context:=Water.context(world)
 info.visible=not context.is_empty() and not GameState.input_locked() and world.player.target==null
 if info.visible:
  var view:=get_viewport_rect().size
  caption.custom_minimum_size.x=minf(420,view.x-64)
  caption.text=context.title+" · "+context.detail
  info.reset_size();info.position=Vector2(view.x-info.size.x-20,view.y-info.size.y-20)
 if draw_wait>=.07:draw_wait=0;queue_redraw()
 if GameState.input_locked():return
 var near:=Water.nearest(world,76)
 if near.get("kind","")!="hot_spring" or world.player.velocity.length()>2:rest_time=0;return
 for enemy in get_tree().get_nodes_in_group("enemies"):
  if not enemy.dead and enemy.data.behavior!="animal" and enemy.position.distance_to(world.player.position)<200:rest_time=0;return
 rest_time+=delta
 if rest_time>=15:
  rest_time=0
  if GameState.hp<GameState.max_hp():GameState.heal(1);GameState.save_requested.emit()
func _draw():
 var camera: Camera2D=world.player.camera
 var extent:=get_viewport_rect().size/camera.zoom*.5+Vector2(100,100)
 var visible:=Rect2(camera.get_screen_center_position()-extent,extent*2)
 for feature: Dictionary in world.map_data.get("water_features",[]):
  var kind: String=feature.kind;var spec: Dictionary=Water.TYPES[kind]
  if kind in ["hot_spring","geyser"]:
   var center:=Vector2.ZERO
   for cell: Vector2i in feature.cells:center+=(Vector2(cell)+Vector2(.5,.5))*32
   center/=feature.cells.size()
   if not visible.has_point(center):continue
   for side in [-1,1]:
    Art.rock(self,center+Vector2(side*39-10,-35),Vector2(23,21),true)
    Art.rock(self,center+Vector2(side*41-8,7),Vector2(20,18),true)
   Art.rock(self,center+Vector2(-25,-51),Vector2(48,18),true)
   for i in 6:
    var rise:=fmod(time*10+i*9,48)
    var at:=center+Vector2(sin(time+i)*12,-rise)
    draw_circle(at,5+rise*.09,Color(.8,.89,.84,.23*(1-rise/65)))
   if kind=="geyser":
    var pulse:=fmod(time,12.0)
    if pulse<3:
     var height:=sin(pulse/3*PI)*82
     draw_rect(Rect2(center+Vector2(-5,-height),Vector2(10,height+5)),Color("aed9d4"))
     draw_rect(Rect2(center+Vector2(-2,-height),Vector2(4,height)),Color("dcece1"))
     for i in 5:draw_rect(Rect2(center+Vector2(sin(time*6+i)*14,-height+fmod(time*25+i*7,24)),Vector2(3,4)),Color("dcece1"))
  for cell: Vector2i in feature.cells:
   var at: Vector2=Vector2(cell)*32
   if not visible.has_point(at) or posmod(cell.x*3+cell.y*7,9)!=0:continue
   var color: Color=spec.color;color.a=.4
   if spec.flow>.3:
    var offset:=fmod(time*float(spec.flow)*12+cell.x*3,24)
    draw_line(at+Vector2(12,offset),at+Vector2(12,offset+6),color,1)
    draw_line(at+Vector2(10,offset+3),at+Vector2(12,offset+6),color,1)
   else:
    draw_arc(at+Vector2(16,18),5+sin(time+cell.x)*2,0,PI,8,color,1)
