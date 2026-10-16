extends Control
const Yard:=preload("res://scripts/core/yard.gd")
const Data:=preload("res://scripts/data/yard_catalog.gd")
const Paint:=preload("res://scripts/core/yard_art.gd")
const Art:=preload("res://scripts/core/art.gd")
const STEP:=15.0
var editor: CanvasLayer
var repeat_action:=""
var repeat_timer:=0.0
func _ready():
 custom_minimum_size=Vector2(528,320);focus_mode=Control.FOCUS_ALL;mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true
func region() -> Rect2i:return Data.VIEWS[editor.view.selected]
func origin() -> Vector2:return (size-Vector2(region().size)*STEP)/2
func to_plan(at: Vector2i) -> Vector2:return origin()+Vector2(at-region().position)*STEP
func _process(delta: float):
 if not has_focus() or repeat_action=="" or not Input.is_action_pressed(repeat_action):repeat_action="";return
 repeat_timer-=delta
 if repeat_timer<=0:move_cursor(repeat_action);repeat_timer=.13
func move_cursor(action: String):
 var step: Vector2i={"ui_left":Vector2i.LEFT,"ui_right":Vector2i.RIGHT,"ui_up":Vector2i.UP,"ui_down":Vector2i.DOWN}[action]
 editor.cursor=(editor.cursor+step).clamp(region().position,region().end-Vector2i.ONE);editor.refresh_detail()
func _draw():
 if not editor.active:return
 draw_rect(Rect2(Vector2.ZERO,size),Color("253c3b"))
 var farm: Dictionary=Yard.farm_cells();var font:=ThemeDB.fallback_font
 for y in range(region().position.y,region().end.y):
  for x in range(region().position.x,region().end.x):
   var cell:=Vector2i(x,y);var at:=to_plan(cell);var tile:=Yard.terrain(cell)
   var color:=Color("749362") if tile=="." else Color("bba174") if tile=="," else Color("8c8068") if tile=="=" else Color("548c9b") if tile=="~" else Color("465d49")
   draw_rect(Rect2(at,Vector2.ONE*STEP),color)
   if Yard.on_plot(cell) and not Yard.owned_cell(cell,editor.draft.extensions):draw_rect(Rect2(at,Vector2.ONE*STEP),Color(.09,.18,.2,.36))
   if Yard.reserved(cell):draw_rect(Rect2(at,Vector2.ONE*STEP),Color(.7,.86,.8,.2))
   if farm.has(Yard.key(cell)):
    var e: Dictionary=farm[Yard.key(cell)]
    draw_rect(Rect2(at+Vector2(2,2),Vector2.ONE*(STEP-4)),Color("9b7852") if e.kind=="soil" else Color("7cb5bd"))
    if e.has("crop"):draw_circle(at+Vector2.ONE*STEP*.5,3,Color("c9a3c2") if e.crop=="grape" else Color("e5c9a1"))
 for e: Dictionary in Yard.map_data().objects:
  var cell:=Vector2i(e.pos[0],e.pos[1])
  if not region().has_point(cell) or Yard.unit_of(e)!="":continue
  if e.type in ["portal","savepoint","stock_chest","home_station"]:
   draw_rect(Rect2(to_plan(cell)+Vector2(3,3),Vector2.ONE*(STEP-6)),Color("e1d1a2"))
 for id: String in editor.draft.paths:
  var at:=Yard.cell(id)
  if region().has_point(at):Paint.path(self,to_plan(at),editor.draft.paths[id],Paint.mask(at,editor.draft.paths),STEP/32)
 for id: String in editor.draft.fences:
  var at:=Yard.cell(id)
  if region().has_point(at):Paint.fence(self,to_plan(at),editor.draft.fences[id],0,STEP/32)
 for id: String in Data.UNITS:
  var at:=Yard.anchor(id,editor.draft)
  if at.x>=0 and region().has_point(at):Paint.unit(self,to_plan(at),id,STEP/32)
 for id: String in Data.EXTENSIONS:
  var r: Rect2i=Data.EXTENSIONS[id].rect.intersection(region())
  if r.get_area()>0:draw_rect(Rect2(to_plan(r.position),Vector2(r.size)*STEP),Color("d7c695") if id in editor.draft.extensions else Color("6f9d9c"),false,1)
 var okay: bool=editor.reason_text==""
 var color:=Color("dfcf9c") if okay else Color("e6a18c")
 if Data.UNITS.has(editor.kind):
  var r:=Yard.bounds(editor.cursor);draw_rect(Rect2(to_plan(r.position),Vector2(r.size)*STEP),Color(color,.18))
  Paint.unit(self,to_plan(editor.cursor),editor.kind,STEP/32,.6)
  draw_rect(Rect2(to_plan(r.position),Vector2(r.size)*STEP),color,false,2)
 else:
  for at: Vector2i in editor.stroke_cells():
   if region().has_point(at):draw_rect(Rect2(to_plan(at),Vector2.ONE*STEP),Color(color,.35));draw_rect(Rect2(to_plan(at),Vector2.ONE*STEP),color,false,1)
 var player_cell:=Vector2i((editor.world.player.position/32).floor())
 if region().has_point(player_cell):draw_circle(to_plan(player_cell)+Vector2.ONE*STEP*.5,3,Color("e1f1dc"))
 if has_focus():draw_rect(Rect2(Vector2(1,1),size-Vector2(2,2)),Color("e2ca93"),false,2)
func _gui_input(event: InputEvent):
 if not Controls.allows_event(event) or event.is_echo():return
 if event is InputEventMouseButton and event.pressed:
  var at:=Vector2i(((event.position-origin())/STEP).floor())+region().position
  if region().has_point(at):
   editor.cursor=at;grab_focus()
   if event.button_index==MOUSE_BUTTON_RIGHT:editor.pick_at(at)
   else:
    editor.refresh_detail()
    if event.double_click:editor.place()
   accept_event()
 elif event.is_action_pressed("ui_accept"):editor.place();accept_event()
 else:
  for action in ["ui_left","ui_right","ui_up","ui_down"]:
   if event.is_action_pressed(action):
    repeat_action=action;repeat_timer=.3;move_cursor(action);accept_event();return
