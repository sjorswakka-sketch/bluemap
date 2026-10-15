extends RefCounted
## Original low-profile field art: all crops stay inside their tile.
static func field(canvas: Node2D,farm: Script,time: float):
 var cells: Dictionary=farm.state().cells;farm.irrigate()
 for id: String in cells:
  var at: Vector2i=farm.cell(id);var pos:=Vector2(at)*32;var e: Dictionary=cells[id]
  if e.kind=="channel":
   var water: bool=farm.wet.has(at);var color:=Color("3d91b2") if water else Color("59483b")
   canvas.draw_rect(Rect2(pos+Vector2(7,7),Vector2(18,18)),Color("302f2b"));canvas.draw_rect(Rect2(pos+Vector2(8,8),Vector2(16,16)),color)
   for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    if cells.get(farm.key(at+step),{}).get("kind","")=="channel" or farm.sources.has(at+step):
     canvas.draw_line(pos+Vector2(16,16),pos+Vector2(16,16)+Vector2(step)*17,Color("302f2b"),18);canvas.draw_line(pos+Vector2(16,16),pos+Vector2(16,16)+Vector2(step)*17,color,16)
   if water:
    var upstream: Vector2i=farm.flow.get(at,at)
    var direction:=Vector2(at-upstream)
    var center:=pos+Vector2(16,16)+direction*(fmod(time*9+at.x+at.y,12)-6)
    canvas.draw_line(center-direction*2,center+direction*2,Color("a4dbe0"),2)
   if farm.show_water and farm.mode!="":canvas.draw_rect(Rect2(pos+Vector2(4,4),Vector2(24,24)),Color("8ac7d6") if water else Color("d4b379"),false,1)
  else:
   var watered: bool=farm.watered(at)
   canvas.draw_rect(Rect2(pos+Vector2(2,2),Vector2(28,28)),Color("574636") if watered else Color("8d6d48"))
   for y in [8,16,24]:canvas.draw_line(pos+Vector2(5,y),pos+Vector2(27,y),Color("3c392e"),2)
   if e.has("crop"):crop(canvas,pos,e,float(farm.CROPS[e.crop].seconds),time)
   if farm.show_water and farm.mode!="":
    canvas.draw_rect(Rect2(pos+Vector2(2,2),Vector2(28,28)),Color("78b8cb") if watered else Color("d6ac73"),false,1)
 for at: Vector2i in farm.FLOWERS:
  if not cells.has(farm.key(at)):
   var pos:=Vector2(at)*32
   for offset in [Vector2(9,12),Vector2(20,23)]:canvas.draw_line(pos+offset,pos+offset+Vector2(0,6),Color("669455"),2);canvas.draw_circle(pos+offset,4,Color("e4b5c5"));canvas.draw_circle(pos+offset,1.5,Color("f3dc85"))
static func crop(canvas: Node2D,pos: Vector2,e: Dictionary,seconds: float,time: float):
 var ratio: float=clampf(float(e.growth)/seconds,0,1);var grown:=ratio>=.35;var ripe:=ratio>=1
 var sway:=roundf(sin(time*1.4+pos.x*.07)*(.7 if grown else .3))
 if e.crop=="grape":
  if grown:
   for x in [6,25]:canvas.draw_line(pos+Vector2(x,27),pos+Vector2(x,5),Color("a38b60"),2)
   for y in [9,18]:canvas.draw_line(pos+Vector2(6,y),pos+Vector2(25,y),Color("927d58"),1)
  var height:=5+floorf(ratio*18)
  canvas.draw_line(pos+Vector2(16,27),pos+Vector2(16+sway,27-height),Color("729858"),2)
  for i in (3 if grown else 1):
   var leaf:=pos+Vector2(11 if i%2==0 else 21,23-i*6)+Vector2(sway,0)
   canvas.draw_line(leaf-Vector2(3,0),leaf+Vector2(3,0),Color("81a35e"),4);canvas.draw_line(leaf-Vector2(1,2),leaf+Vector2(1,2),Color("9ebd74"),2)
  if ratio>=.65:
   for offset in [Vector2(10,13),Vector2(21,19)]:
    for berry in [Vector2(-2,0),Vector2(2,0),Vector2(0,4)]:canvas.draw_rect(Rect2(pos+offset+berry+Vector2(sway,0),Vector2(3,3)),Color("bc90d0") if ripe else Color("86a06a"))
    if ripe:canvas.draw_rect(Rect2(pos+offset+Vector2(sway,0),Vector2(2,2)),Color("e1b8e7"))
 else:
  for i in (3 if grown else 1):
   var base:=pos+Vector2(8+i*8,27);var head:=base+Vector2(sway,-5-ratio*(12+i%2*4))
   canvas.draw_line(base,head,Color("719c60"),2)
   canvas.draw_line(base+Vector2(-3,-3),base+Vector2(3,-3),Color("91b174"),2)
   if ratio>=.65:
    for offset in [Vector2(-3,0),Vector2(3,0),Vector2(0,-3),Vector2(0,3)]:canvas.draw_rect(Rect2(head+offset-Vector2.ONE,Vector2(3,3)),Color("f0d2ad") if ripe else Color("a3b477"))
    canvas.draw_rect(Rect2(head-Vector2.ONE,Vector2(3,3)),Color("d4a365"))
 if e.get("fertilized",false):canvas.draw_rect(Rect2(pos+Vector2(25,26),Vector2(3,3)),Color("edcb76"))
static func preview(canvas: Node2D,farm: Script,at: Vector2i,world: Node):
 var result: Dictionary=farm.work_status(at,farm.mode,world)
 var pos:=Vector2(at)*32
 var color:=Color("b6d9ad") if result.ok else Color("e1b776")
 canvas.draw_rect(Rect2(pos+Vector2.ONE,Vector2(30,30)),Color(color,.10))
 for corner in [Vector2(2,2),Vector2(30,2),Vector2(2,30),Vector2(30,30)]:
  var dx: float=5 if corner.x<16 else -5;var dy: float=5 if corner.y<16 else -5
  canvas.draw_line(pos+corner,pos+corner+Vector2(dx,0),color,2);canvas.draw_line(pos+corner,pos+corner+Vector2(0,dy),color,2)
 if farm.mode=="channel" and result.ok:
  var connected:=false
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   if farm.sources.has(at+step) or farm.wet.has(at+step):connected=true
  canvas.draw_rect(Rect2(pos+Vector2(8,8),Vector2(16,16)),Color("7dbfd1",.45) if connected else Color("c4a675",.45))
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   if farm.sources.has(at+step) or farm.wet.has(at+step):canvas.draw_line(pos+Vector2(16,16),pos+Vector2(16,16)+Vector2(step)*16,Color("b3e1e1"),2)
static func work_effect(canvas: Node2D,e: Dictionary):
 var progress: float=1-float(e.left)/.24
 var center:=Vector2(e.cell)*32+Vector2(16,18)
 var color:=Color("d9b9e2",1-progress) if e.harvest else Color("c3a57a",1-progress)
 for i in 3:canvas.draw_rect(Rect2(center+Vector2((i-1)*progress*12,-sin(progress*PI)*8+i%2*4),Vector2(2,2)),color)
