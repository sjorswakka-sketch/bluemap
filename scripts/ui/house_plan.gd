extends Control
const House:=preload("res://scripts/core/personal_home.gd")
const Paint:=preload("res://scripts/core/house_art.gd")
const Catalog:=preload("res://scripts/data/house_catalog.gd")
const Art:=preload("res://scripts/core/art.gd")
const ORIGIN:=Vector2(32,26)
const STEP:=34.0
var repeat_action:=""
var repeat_timer:=0.0
var editor: CanvasLayer
func _ready():
 custom_minimum_size=Vector2(404,390);focus_mode=Control.FOCUS_ALL;mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true
func _process(delta: float):
 if not has_focus() or repeat_action=="" or not Input.is_action_pressed(repeat_action):repeat_action="";return
 repeat_timer-=delta
 if repeat_timer<=0:
  move_cursor(repeat_action);repeat_timer=.12
func move_cursor(action: String):
 var step: Vector2i={"ui_left":Vector2i.LEFT,"ui_right":Vector2i.RIGHT,"ui_up":Vector2i.UP,"ui_down":Vector2i.DOWN}[action]
 editor.cursor=(editor.cursor+step).clamp(Vector2i(2,2),Vector2i(11,11));editor.refresh_detail()
func to_plan(cell: Vector2i) -> Vector2:return ORIGIN+Vector2(cell-Vector2i(2,2))*STEP
func _draw():
 if not editor.active:return
 draw_rect(Rect2(ORIGIN-Vector2(14,14),Vector2.ONE*(STEP*10+28)),Color("6d685b"))
 for x in range(10):
  draw_texture_rect_region(Art.tex("house_surfaces"),Rect2(ORIGIN+Vector2(x*STEP,-14),Vector2(STEP,14)),Rect2((4+int(editor.draft.wall))*32,0,32,16))
 for y in range(10):
  for x in range(10):
   var at:=ORIGIN+Vector2(x,y)*STEP
   draw_texture_rect_region(Art.tex("house_surfaces"),Rect2(at,Vector2.ONE*STEP),Rect2(int(editor.draft.floor)*32,0,32,32))
   var cell:=Vector2i(x+2,y+2)
   if House.reserved(cell):draw_rect(Rect2(at,Vector2.ONE*STEP),Color(.48,.76,.74,.13))
   draw_rect(Rect2(at,Vector2.ONE*STEP),Color(.12,.2,.18,.15),false,1)
 for entry: Dictionary in editor.draft.layout.values():
  if Catalog.PIECES[entry.kind].get("floor",false):Paint.draw_piece(self,entry,to_plan(House.rect(entry).position),STEP/32)
 for r: Rect2i in House.FIXED:
  var at:=to_plan(r.position)
  draw_rect(Rect2(at+Vector2(5,5),Vector2(r.size)*STEP-Vector2(10,10)),Color("9c805b"))
  draw_rect(Rect2(at+Vector2(8,8),Vector2(r.size)*STEP-Vector2(16,16)),Color("d5c29b"),false,2)
 draw_texture_rect_region(Art.tex("stock_chest"),Rect2(to_plan(Vector2i(10,5)),Vector2.ONE*STEP),Rect2(0,0,32,32))
 for id: String in editor.draft.layout:
  var entry: Dictionary=editor.draft.layout[id]
  if Catalog.PIECES[entry.kind].get("floor",false) or id==editor.editing_id:continue
  Paint.draw_piece(self,entry,to_plan(House.rect(entry).position),STEP/32)
 if editor.kind!="":
  var entry: Dictionary={"kind":editor.kind,"cell":[editor.cursor.x,editor.cursor.y],"tint":editor.tint.selected}
  var dims: Vector2=Vector2(Catalog.PIECES[editor.kind].size)*STEP
  var okay: bool=editor.placement_reason()==""
  var color:=Color("a7d3b1") if okay else Color("da9986")
  var at:=to_plan(editor.cursor)
  draw_rect(Rect2(at,dims),Color(color,.18))
  Paint.draw_piece(self,entry,at,STEP/32,Color(1,1,1,.65))
  draw_rect(Rect2(at,dims),color,false,3)
 var player_cell: Vector2=editor.world.player.position/32-Vector2(2,2)
 draw_circle(ORIGIN+player_cell*STEP,5,Color("c1e6e5"));draw_circle(ORIGIN+player_cell*STEP,7,Color("36595e"),false,2)
 if has_focus():draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color("e8d5a1"),false,2)
func _gui_input(event: InputEvent):
 if not Controls.allows_event(event) or event.is_echo():return
 if event is InputEventMouseButton and event.pressed:
  var at: Vector2i=Vector2i(((event.position-ORIGIN)/STEP).floor())+Vector2i(2,2)
  if House.ROOM.has_point(at):
   grab_focus()
   if event.button_index==MOUSE_BUTTON_RIGHT:editor.pick_at(at)
   elif event.button_index==MOUSE_BUTTON_LEFT:
    editor.cursor=at;editor.refresh_detail()
    if event.double_click:editor.place()
   accept_event()
 elif event.is_action_pressed("ui_accept"):
  editor.place();accept_event()
 else:
  var step:=Vector2i.ZERO
  if event.is_action_pressed("ui_left"):step=Vector2i.LEFT
  elif event.is_action_pressed("ui_right"):step=Vector2i.RIGHT
  elif event.is_action_pressed("ui_up"):step=Vector2i.UP
  elif event.is_action_pressed("ui_down"):step=Vector2i.DOWN
  if step!=Vector2i.ZERO:
   repeat_action="ui_left" if step==Vector2i.LEFT else "ui_right" if step==Vector2i.RIGHT else "ui_up" if step==Vector2i.UP else "ui_down"
   move_cursor(repeat_action);repeat_timer=.3;accept_event()
