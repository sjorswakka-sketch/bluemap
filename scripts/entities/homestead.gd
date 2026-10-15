extends Node2D
const Farm:=preload("res://scripts/core/homestead.gd")
const Feedback:=preload("res://scripts/core/garden_feedback.gd")
const GardenArt:=preload("res://scripts/core/garden_art.gd")
const Style:=preload("res://scripts/core/ui_style.gd")
var world: Node2D
var time:=0.0
var cooldown:=.3
var dropped: Dictionary={}
var hint: CanvasLayer
var panel: PanelContainer
var label: Label
var waiting_release:=false
var stroke: Dictionary={}
var last_cell:=Vector2i(-100,-100)
var stroke_mode:=""
var effects: Array[Dictionary]=[]
func _ready():
 add_to_group("homesteads")
 Controls.device_changed.connect(device_changed)
 if GameState.map_id=="village":
  hint=CanvasLayer.new();hint.layer=11;add_child(hint)
  panel=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_theme_stylebox_override("panel",Style.flat(Color(.035,.075,.085,.92),Color("82a8a3"),1));hint.add_child(panel)
  label=Style.make_label("",16,Color("e2e7d4"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(label);panel.hide()
func _notification(what: int):
 if what==NOTIFICATION_PAUSED:
  waiting_release=Input.is_action_pressed("interact");clear_stroke()
  if is_instance_valid(panel):panel.hide()
 elif what==NOTIFICATION_UNPAUSED and Input.is_action_pressed("interact"):
  waiting_release=true;clear_stroke()
func aim_cell() -> Vector2i:
 var d: Vector2=world.player.facing
 var step:=Vector2i(signf(d.x),0) if absf(d.x)>absf(d.y) else Vector2i(0,signf(d.y))
 return Vector2i((world.player.position/32).floor())+step
func device_changed(_pad: bool):
 waiting_release=Input.is_action_pressed("interact");clear_stroke()
func clear_stroke():
 stroke.clear();last_cell=Vector2i(-100,-100);stroke_mode=""
func _input(event: InputEvent):
 if is_queued_for_deletion() or not Controls.allows_event(event) or event.is_echo():return
 if event.is_action_released("interact"):
  clear_stroke();waiting_release=false
 if GameState.input_locked():
  if event.is_action_pressed("interact"):waiting_release=true;clear_stroke()
  return
 if event.is_action_pressed("homestead"):
  var ui: CanvasLayer=load("res://scripts/ui/home_ui.gd").new();ui.world=world;world.add_child(ui);ui.open(null);get_viewport().set_input_as_handled()
 elif event.is_action_pressed("interact") and GameState.map_id=="village" and Farm.mode!="" and Farm.garden(aim_cell()) and world.player.target==null:
  clear_stroke();waiting_release=false;work();get_viewport().set_input_as_handled()
func work():
 if cooldown>0 or waiting_release or GameState.input_locked() or world.player.target!=null or world.player.roll_timer>0 or world.player.combat.busy() or world.player.knockback.length()>5:return
 if Farm.mode=="" or not Farm.garden(aim_cell()):return
 if stroke_mode!=Farm.mode:clear_stroke();stroke_mode=Farm.mode
 # Restoration is deliberately one tile per press; holding cannot erase a planted row.
 if Farm.mode=="fill" and not stroke.is_empty():return
 cooldown=.1
 var at:=aim_cell();var candidates: Array[Vector2i]=[]
 var delta:=at-last_cell
 # Fill short cardinal gaps during running/long frames; never edit along a teleport.
 if last_cell.x!=-100 and (delta.x==0 or delta.y==0) and absi(delta.x)+absi(delta.y)<=3:
  var direction:=Vector2i(signi(delta.x),signi(delta.y))
  for i in range(1,absi(delta.x)+absi(delta.y)):candidates.append(last_cell+direction*i)
 candidates.append(at);last_cell=at
 var done:=0;var picked:=false;var filled_water:=false
 for cell: Vector2i in candidates:
  if stroke.has(cell):continue
  if Farm.act(cell,Farm.mode,world):
   stroke[cell]=true;done+=1;Farm.irrigate();picked=picked or Farm.mode=="harvest";filled_water=filled_water or (Farm.mode=="channel" and Farm.wet.has(cell))
   effects.append({"cell":cell,"left":.24,"harvest":Farm.mode=="harvest"})
 if done>0:
  world.player.start_work_animation("foraging",.12,Vector2(at)*32+Vector2(16,16))
  Sound.play("garden_pick" if picked else "garden_water" if filled_water else "hs_soil",-18)
func update_hint():
 if panel==null:return
 var at:=aim_cell()
 var near: bool=Farm.garden(Vector2i((world.player.position/32).floor())) or Farm.garden(at)
 var active: bool=Farm.mode!="" or GameState.flag("hs_garden_help")
 panel.visible=active and near and not GameState.input_locked() and world.player.target==null and world.hud.toast_time<=0 and world.hud.toast_queue.is_empty() and world.hud.banner_time<=0
 if not panel.visible:return
 var palette: Script=load("res://scripts/ui/home_ui.gd")
 label.text=tr("%s · %s gebruiken · %s standen") % [palette.mode_name(Farm.mode),Controls.action_label("interact"),palette.shortcut()]
 if Farm.mode=="":label.text=tr("Tuinhulp · %s opent de tuinstanden") % palette.shortcut()
 if Farm.mode!="":
  var result:=Farm.work_status(at,Farm.mode,world)
  label.text+="\n"+Feedback.cell_text(at)
  if not result.ok:label.text+="\n"+result.reason
  elif Farm.mode=="fill":label.text+="\n"+tr("Eén tegel per druk · een plant wordt vervangen door zijn zaad.")
  elif Farm.mode=="channel":
   var connected:=false
   for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    if Farm.sources.has(at+direction) or Farm.wet.has(at+direction):connected=true
   label.text+="\n"+(tr("Dit kanaal krijgt meteen water · houd vast en loop verder.") if connected else tr("Dit kanaal blijft droog tot het met water is verbonden."))
  else:label.text+="\n"+tr("Houd vast en loop langs een rij.")
 if GameState.flag("hs_garden_help"):label.text+="\n"+Feedback.guide_text()
 var view:=get_viewport_rect().size
 label.custom_minimum_size=Vector2(minf(720,view.x-64),0);panel.size=panel.get_combined_minimum_size()
 panel.position=Vector2((view.x-panel.size.x)*.5,view.y-32-panel.size.y)
 var actor_screen: Vector2=world.player.get_global_transform_with_canvas().origin
 var actor_bounds:=Rect2(actor_screen-Vector2(40,40),Vector2(80,80))
 if panel.get_global_rect().intersects(actor_bounds):panel.position.y=maxf(280,actor_bounds.position.y-panel.size.y-16)
func _process(delta: float):
 if is_queued_for_deletion():return
 time+=delta;cooldown=maxf(0,cooldown-delta)
 for id: String in Farm.state().drops:
  var e: Dictionary=Farm.state().drops[id]
  if e.map==GameState.map_id and not dropped.has(id) and not GameState.flag("hs_drop:"+id):
   dropped[id]=true;world.spawn_pickup("hs_manure",Vector2(e.pos[0],e.pos[1]),"hs_drop:"+id)
 for e: Dictionary in effects:e.left-=delta
 effects=effects.filter(func(e):return e.left>0)
 if not Input.is_action_pressed("interact"):clear_stroke();waiting_release=false
 elif GameState.input_locked():waiting_release=true;clear_stroke()
 elif not waiting_release:work()
 Farm.irrigate();update_hint();queue_redraw()
func _draw():
 if GameState.map_id=="player_home":
  draw_rect(Rect2(4*32,6*32,160,64),Color("567a7a"));draw_rect(Rect2(4*32+5,6*32+5,150,54),Color("789591"),false,3)
  for x in range(4*32+5,9*32,9):draw_line(Vector2(x,6*32-3),Vector2(x,6*32),Color("c5b88e"),2);draw_line(Vector2(x,8*32),Vector2(x,8*32+3),Color("c5b88e"),2)
  return
 if GameState.map_id!="village":return
 GardenArt.field(self,Farm,time)
 for e: Dictionary in effects:GardenArt.work_effect(self,e)
 if Farm.mode!="" and Farm.garden(aim_cell()) and not GameState.input_locked() and world.player.target==null:GardenArt.preview(self,Farm,aim_cell(),world)
 draw_style_box(Style.flat(Color("4b6470"),Color("d8c793"),1),Rect2(6*32,20*32+2,64,19))
 draw_string(ThemeDB.fallback_font,Vector2(6*32+8,20*32+16),tr("Thuis"),HORIZONTAL_ALIGNMENT_LEFT,50,13,Color("f2e0b6"))
