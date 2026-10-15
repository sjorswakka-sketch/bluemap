extends Node2D
const Farm:=preload("res://scripts/core/homestead.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var time:=0.0
var cooldown:=.3
var dropped: Dictionary={}
var hint: CanvasLayer
var label: Label
func _ready():
 add_to_group("homesteads")
 if GameState.map_id=="village":
  hint=CanvasLayer.new();hint.layer=11;add_child(hint)
  label=Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.position=Vector2(300,310);label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_outline_color",Color("142431"));label.add_theme_constant_override("outline_size",5);hint.add_child(label)
func aim_cell() -> Vector2i:
 var d: Vector2=world.player.facing
 var step:=Vector2i(signf(d.x),0) if absf(d.x)>absf(d.y) else Vector2i(0,signf(d.y))
 return Vector2i(world.player.position/32)+step
func _input(event: InputEvent):
 if is_queued_for_deletion() or not Controls.allows_event(event) or event.is_echo() or GameState.input_locked():return
 if event.is_action_pressed("homestead"):
  var ui: CanvasLayer=load("res://scripts/ui/home_ui.gd").new();ui.world=world;world.add_child(ui);ui.open(null);get_viewport().set_input_as_handled()
 elif event.is_action_pressed("interact") and GameState.map_id=="village" and Farm.mode!="" and Farm.garden(aim_cell()) and world.player.target==null:
  work();get_viewport().set_input_as_handled()
func work():
 if cooldown>0 or world.player.roll_timer>0 or world.player.combat.busy() or world.player.knockback.length()>5:return
 cooldown=.14
 if Farm.act(aim_cell(),Farm.mode,world):
  world.player.start_work_animation("foraging",.12,Vector2(aim_cell())*32+Vector2(16,16));Sound.play("hs_soil",-17)
func _process(delta: float):
 if is_queued_for_deletion():return
 time+=delta;cooldown=maxf(0,cooldown-delta)
 for id: String in Farm.state().drops:
  var e: Dictionary=Farm.state().drops[id]
  if e.map==GameState.map_id and not dropped.has(id) and not GameState.flag("hs_drop:"+id):
   dropped[id]=true;world.spawn_pickup("hs_manure",Vector2(e.pos[0],e.pos[1]),"hs_drop:"+id)
 if label!=null:
  label.visible=Farm.mode!="" and Farm.garden(Vector2i(world.player.position/32)) and not GameState.input_locked()
  label.position=Vector2(20,get_viewport_rect().size.y-80);label.size=Vector2(get_viewport_rect().size.x-40,64)
  label.text=tr("Tuin: %s · %s vasthouden + lopen · %s standen") % [load("res://scripts/ui/home_ui.gd").mode_name(Farm.mode),Controls.action_label("interact"),load("res://scripts/ui/home_ui.gd").shortcut()]
  if label.visible:
   var e: Dictionary=Farm.state().cells.get(Farm.key(aim_cell()),{})
   if e.has("crop"):label.text+="\n"+tr("%s · groei %.0f / %.0f s") % [tr("Water aangesloten") if Farm.watered(aim_cell()) else tr("Droog: sluit een kanaal aan"),float(e.growth),float(Farm.CROPS[e.crop].seconds)]
   if Input.is_action_pressed("interact"):work()
 queue_redraw()
func _draw():
 if GameState.map_id=="player_home":
  draw_rect(Rect2(4*32,6*32,160,64),Color("567a7a"));draw_rect(Rect2(4*32+5,6*32+5,150,54),Color("789591"),false,3)
  for x in range(4*32+5,9*32,9):draw_line(Vector2(x,6*32-3),Vector2(x,6*32),Color("c5b88e"),2);draw_line(Vector2(x,8*32),Vector2(x,8*32+3),Color("c5b88e"),2)
  return
 if GameState.map_id!="village":return
 var cells: Dictionary=Farm.state().cells;Farm.irrigate()
 for id: String in cells:
  var at:=Farm.cell(id);var pos:=Vector2(at)*32;var e: Dictionary=cells[id]
  if e.kind=="channel":
   var water: bool=Farm.wet.has(at);var color:=Color("3d91b2") if water else Color("59483b")
   draw_rect(Rect2(pos+Vector2(7,7),Vector2(18,18)),Color("302f2b"));draw_rect(Rect2(pos+Vector2(8,8),Vector2(16,16)),color)
   for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    if cells.get(Farm.key(at+step),{}).get("kind","")=="channel" or Farm.sources.has(at+step):
     draw_line(pos+Vector2(16,16),pos+Vector2(16,16)+Vector2(step)*17,Color("302f2b"),18);draw_line(pos+Vector2(16,16),pos+Vector2(16,16)+Vector2(step)*17,color,16)
   if water:draw_line(pos+Vector2(10,13+sin(time*2+at.x)*2),pos+Vector2(20,13+sin(time*2+at.x)*2),Color("a4dbe0"),2)
  else:
   draw_rect(Rect2(pos+Vector2(2,2),Vector2(28,28)),Color("574636") if Farm.watered(at) else Color("8d6d48"))
   for y in [8,16,24]:draw_line(pos+Vector2(5,y),pos+Vector2(27,y),Color("3c392e"),2)
   if e.has("crop"):
    var mature: bool=e.growth>=Farm.CROPS[e.crop].seconds
    var height: float=8+e.growth/Farm.CROPS[e.crop].seconds*14
    draw_line(pos+Vector2(16,25),pos+Vector2(16,25-height),Color("76a567"),3)
    for x in [10,21]:draw_circle(pos+Vector2(x,17),4,Color("90ae6d"))
    if mature:
     if e.crop=="grape":
      for offset in [Vector2(10,14),Vector2(18,14),Vector2(14,20)]:draw_circle(pos+offset,4,Color("b18ccd"))
     else:
      for offset in [Vector2(10,10),Vector2(20,12)]:draw_circle(pos+offset,5,Color("ebd5a2"));draw_circle(pos+offset,2,Color("d49e65"))
    if e.get("fertilized",false):draw_circle(pos+Vector2(25,26),2,Color("edcb76"))
 for at: Vector2i in Farm.FLOWERS:
  if not cells.has(Farm.key(at)):
   var pos:=Vector2(at)*32
   for offset in [Vector2(9,12),Vector2(20,23)]:draw_line(pos+offset,pos+offset+Vector2(0,6),Color("669455"),2);draw_circle(pos+offset,4,Color("e4b5c5"));draw_circle(pos+offset,1.5,Color("f3dc85"))
 if Farm.mode!="" and Farm.garden(aim_cell()) and not GameState.input_locked():draw_rect(Rect2(Vector2(aim_cell())*32+Vector2.ONE,Vector2(30,30)),Color("f6db87"),false,2)
 # A distinct plaque identifies the reused lower-left facade.
 draw_style_box(preload("res://scripts/core/ui_style.gd").flat(Color("4b6470"),Color("d8c793"),1),Rect2(6*32,20*32+2,64,19))
 draw_string(ThemeDB.fallback_font,Vector2(6*32+8,20*32+16),tr("Thuis"),HORIZONTAL_ALIGNMENT_LEFT,50,13,Color("f2e0b6"))
