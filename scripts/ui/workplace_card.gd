extends Control
## Original small diagrams: ingredients, a real workplace and its output.
const Farm:=preload("res://scripts/core/homestead.gd")
const Identity:=preload("res://scripts/core/craft_identity.gd")
const Art:=preload("res://scripts/core/draw_util.gd")
const Items:=preload("res://scripts/data/items.gd")
var role:=""
var unit:=""
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(620,82)
func _draw():
 var center:=size*.5;var color:=Identity.accent(role)
 if role in ["wine","compost"]:
  var left: String="hs_grape" if role=="wine" else "hs_manure";var right: String="hs_wine" if role=="wine" else "hs_fertilizer"
  var a:=center+Vector2(-150,0);var b:=center+Vector2(150,0)
  draw_texture_rect(Items.icon_tex(left),Rect2(a-Vector2(22,22),Vector2(44,44)),false)
  draw_texture_rect(Items.icon_tex(right),Rect2(b-Vector2(22,22),Vector2(44,44)),false)
  for sign in [-1,1]:
   var at:=center+Vector2(sign*78,0);draw_line(at-Vector2(20,0),at+Vector2(20,0),color,2);draw_line(at+Vector2(20,0),at+Vector2(13,-6),color,2);draw_line(at+Vector2(20,0),at+Vector2(13,6),color,2)
  if role=="wine":
   draw_style_box(preload("res://scripts/core/ui_style.gd").flat(Color("8d6549"),Color("b79a72"),2),Rect2(center-Vector2(25,30),Vector2(50,60)))
   for y in [-20,15]:draw_rect(Rect2(center+Vector2(-26,y),Vector2(52,6)),Color("85969b"))
   draw_circle(center+Vector2(12,8),4,Color("e3c47f"))
  else:
   for x in [-17,0,18]:draw_circle(center+Vector2(x,7-abs(x)*.35),18,Color("826a43").lightened(x*.003))
   for x in [-16,0,17]:draw_line(center+Vector2(x,1),center+Vector2(x+5,9),Color("c9ae70"),3)
   draw_rect(Rect2(center+Vector2(-37,19),Vector2(74,7)),Color("b69665"))
 elif role=="hive":
  for i in 6:
   var at:=center+Vector2(cos(i*TAU/6)*110,sin(i*TAU/6)*24)
   for offset in [Vector2(-4,0),Vector2(4,0),Vector2(0,-4),Vector2(0,4)]:draw_circle(at+offset,3,Color("e4c8a4"))
   draw_circle(at,2,Color("e2b854"))
  for y in [-19,-7,5]:draw_rect(Rect2(center+Vector2(-22,y),Vector2(44,10)),color)
  draw_line(center+Vector2(-28,-24),center+Vector2(0,-34),Color("9d7c4d"),5);draw_line(center+Vector2(0,-34),center+Vector2(28,-24),Color("9d7c4d"),5)
  draw_rect(Rect2(center+Vector2(-7,7),Vector2(14,5)),Color("34362a"))
 elif role in ["guide","supplies"]:
  var step: int=preload("res://scripts/core/garden_feedback.gd").guide_step()
  for i in 4:
   var at:=Vector2(center.x-150+i*100,center.y)
   if i<3:draw_line(at+Vector2(22,0),at+Vector2(78,0),color.darkened(.5),2)
   draw_circle(at,22,Color(color,.25 if i<step else .08));draw_arc(at,22,0,TAU,32,color if i<=step else color.darkened(.55),2)
   if i==0:draw_rect(Rect2(at-Vector2(10,7),Vector2(20,14)),Color("a2865b"))
   elif i==1:draw_colored_polygon(PackedVector2Array([at+Vector2(0,-13),at+Vector2(-9,4),at+Vector2(0,12),at+Vector2(9,4)]),Color("86c2cc"))
   else:draw_texture_rect(Items.icon_tex("hs_seed" if i==2 else "hs_grape"),Rect2(at-Vector2(14,14),Vector2(28,28)),false)
 elif role=="wild_grape":
  for x in [-22,0,22]:draw_circle(center+Vector2(x,-4),20,Color("638b61"))
  if GameState.play_time>=Farm.state().wild_due:
   for x in [-19,2,23]:draw_texture_rect(Items.icon_tex("hs_grape"),Rect2(center+Vector2(x-13,-14),Vector2(26,26)),false)
 elif role=="bed":
  draw_rect(Rect2(center-Vector2(42,24),Vector2(84,52)),Color("ac875c"));draw_rect(Rect2(center+Vector2(-36,-19),Vector2(72,12)),Color("e9e0c4"));draw_rect(Rect2(center+Vector2(-36,-3),Vector2(72,25)),color)
