extends Control
const Farm:=preload("res://scripts/core/homestead.gd")
const Art:=preload("res://scripts/core/art.gd")
const Paint:=preload("res://scripts/core/orchard_art.gd")
var crop_id:="carrot"
func _ready():custom_minimum_size=Vector2(420,130);mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw():
 draw_rect(Rect2(Vector2.ZERO,size),Color("294238"));draw_rect(Rect2(Vector2(1,1),size-Vector2(2,2)),Color("78917a"),false,1)
 var font:=ThemeDB.fallback_font
 for i in range(4):
  var at:=Vector2(18+i*100,35);var e: Dictionary={"crop":crop_id,"growth":[0,.3,.7,1.0][i]*Farm.CROPS[crop_id].seconds}
  draw_line(at+Vector2(0,59),at+Vector2(83,59),Color("537257"),1)
  if crop_id=="apple":Paint.tree(self,at+Vector2(41,43),e,0,1,.95)
  elif Farm.Crops.NAMES.has(crop_id):Paint.crop(self,at+Vector2(10,-2),e,0,1.8)
  else:
   draw_set_transform(at+Vector2(10,-2),0,Vector2.ONE*1.8)
   load("res://scripts/core/garden_art.gd").crop(self,Vector2.ZERO,e,Farm.CROPS[crop_id].seconds,0)
   draw_set_transform(Vector2.ZERO)
  draw_string(font,at+Vector2(3,78),tr("Fase %d") % (i+1),HORIZONTAL_ALIGNMENT_LEFT,90,14,Color("d8dfbc"))
 draw_string(font,Vector2(17,23),tr("Groei op actieve speeltijd · droogte pauzeert veilig"),HORIZONTAL_ALIGNMENT_LEFT,400,14,Color("d8dfbc"))
