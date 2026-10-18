extends Node2D
## Snow-capped basalt strata and real two-tile stair treads, aligned to collision.
const Art:=preload("res://scripts/core/art.gd")
var world: Node2D
var obj: Dictionary
var key: String
func _ready():
 # These are ground decorations; scenery never covers the player or resources.
 place_on_ground.call_deferred()
func place_on_ground():
 if is_queued_for_deletion() or not is_instance_valid(world):return
 reparent(world.ground,false);position=Vector2.ZERO
 queue_redraw()
func _draw():
 var texture:=Art.tex("mountain_cliffs")
 for y in world.map_data.rows.size():
  for x in world.map_data.rows[y].length():
   if world.map_data.rows[y][x]!="X":continue
   var at:=Vector2(x*32,y*32)
   # The unwalkable mountain mass stays calm. Only exposed terrace faces carry
   # the detailed rock atlas, rather than tiling a bright pattern over the map.
   draw_rect(Rect2(at,Vector2(32,32)),Color("405666"))
   var face:=false;var cap:=false
   for depth in range(1,4):
    if y>=depth and world.map_data.rows[y-depth][x] in ["z","f",",","i"]:
     face=true;cap=depth==1;break
   if face:
    var variant:=0 if cap else 1+posmod(x*3+y*7,2)
    draw_texture_rect_region(texture,Rect2(at,Vector2(32,32)),Rect2(variant*32,0,32,32))
   elif posmod(x*17+y*31+x*y,23)==0:
    var shift:=float(posmod(x*7+y*3,9))
    draw_line(at+Vector2(5+shift,3),at+Vector2(12+shift,15),Color("4c6271"),1)
    draw_line(at+Vector2(12+shift,15),at+Vector2(9+shift,27),Color("354d5e"),1)
   if x>0 and world.map_data.rows[y][x-1] in ["z","f",",","i"]:draw_line(at,at+Vector2(0,32),Color("78959e"),2)
   if x<world.map_data.rows[y].length()-1 and world.map_data.rows[y][x+1] in ["z","f",",","i"]:draw_line(at+Vector2(31,0),at+Vector2(31,32),Color("78959e"),2)
 for stairs: Array in world.map_data.get("mountain_stairs",[]):
  var area:=Rect2(stairs[0]*32,stairs[1]*32,stairs[2]*32,stairs[3]*32)
  draw_rect(area,Color("72848a"))
  for y in range(int(area.position.y),int(area.end.y),8):
   draw_rect(Rect2(area.position.x,y,area.size.x,3),Color("c6d2cd"))
   draw_rect(Rect2(area.position.x,y+5,area.size.x,3),Color("455c6a"))
  draw_line(area.position,area.position+Vector2(0,area.size.y),Color("e8ede1"),2)
  draw_line(area.position+Vector2(area.size.x-1,0),area.end-Vector2(1,0),Color("e8ede1"),2)
