extends RefCounted
## Original pixel geometry: layered stone lips, moss, a moving curtain and spray.
static func rock(canvas: CanvasItem,at: Vector2,size: Vector2,pale:=false):
 var dark:=Color("586663") if not pale else Color("8d8e7a")
 var mid:=Color("7b8880") if not pale else Color("b1aa8f")
 canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,7),at+Vector2(5,2),at+Vector2(size.x-9,0),at+Vector2(size.x-2,4),at+Vector2(size.x,11),at+Vector2(size.x-4,size.y-2),at+Vector2(size.x-12,size.y),at+Vector2(3,size.y-3)]),dark)
 canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(5,3),at+Vector2(size.x-9,2),at+Vector2(size.x-3,6),at+Vector2(size.x-7,11),at+Vector2(4,9)]),mid)
 canvas.draw_rect(Rect2(at+Vector2(7,5),Vector2(maxf(3,size.x-18),2)),Color("a0ac91") if not pale else Color("c8bd9f"))
 canvas.draw_line(at+Vector2(size.x-8,12),at+Vector2(size.x-10,size.y-4),dark.darkened(.16),1)
 canvas.draw_rect(Rect2(at+Vector2(4,size.y-7),Vector2(3,2)),mid.darkened(.12))
static func fall(canvas: CanvasItem,time: float):
 for e in [[-46,-23,24,39],[-35,-46,25,28],[12,-47,26,29],[26,-25,23,40],[-23,-56,47,13]]:
  rock(canvas,Vector2(e[0],e[1]),Vector2(e[2],e[3]))
 for at in [Vector2(-38,-17),Vector2(30,-13),Vector2(-25,-37),Vector2(20,-41)]:
  canvas.draw_rect(Rect2(at,Vector2(11,4)),Color("78946d"));canvas.draw_rect(Rect2(at+Vector2(3,4),Vector2(5,4)),Color("5c7c60"))
 canvas.draw_rect(Rect2(-13,-43,26,67),Color("428799"));canvas.draw_rect(Rect2(-9,-43,18,66),Color("7fc6cf"));canvas.draw_rect(Rect2(-3,-43,5,63),Color("addbda"))
 for i in 9:
  var y:=floorf(-41+fmod(time*58+i*8,62))
  canvas.draw_rect(Rect2(Vector2(-8+(i%3)*7,y),Vector2(2,7)),Color("d9eddf"))
 for i in 7:
  var at:=Vector2(-20+i*7,22+roundf(sin(time*4+i)*2))
  canvas.draw_rect(Rect2(at,Vector2(5,3)),Color("d9ede2"))
 canvas.draw_arc(Vector2(0,23),22+sin(time*2)*2,0,PI,14,Color("b4ded8"),2)
