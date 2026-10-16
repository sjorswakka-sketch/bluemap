extends RefCounted
const Art:=preload("res://scripts/core/art.gd")
const Data:=preload("res://scripts/data/orchard_catalog.gd")
static func stage(e: Dictionary) -> int:
 var ratio:=clampf(float(e.get("growth",0))/Data.duration(e),0,1)
 var frame:=0 if ratio<.2 else 1 if ratio<.55 else 2 if ratio<1 else 3
 if e.crop=="apple" and e.get("established",false):return 4 if ratio<.55 else frame
 if e.get("established",false):return maxi(1,frame)
 return frame
static func crop(canvas: CanvasItem,pos: Vector2,e: Dictionary,time: float,scale_factor:=1.0):
 var info: Dictionary=Data.CROPS[e.crop]
 if e.crop=="apple":return
 var sway:=roundf(sin(time*1.3+pos.x*.04))
 var at:=pos+Vector2(sway,0)*scale_factor
 canvas.draw_texture_rect_region(Art.tex("orchard_crops"),Rect2(at,Vector2.ONE*32*scale_factor),Rect2(stage(e)*32,int(info.frame)*32,32,32))
 if e.get("fertilized",false):canvas.draw_rect(Rect2(pos+Vector2(26,27)*scale_factor,Vector2.ONE*2*scale_factor),Color("e2c484"))
static func tree(canvas: CanvasItem,pos: Vector2,e: Dictionary,time: float,alpha:=1.0,scale_factor:=1.0):
 var frame:=stage(e);var box:=Rect2(pos+Vector2(-32,-48)*scale_factor,Vector2.ONE*64*scale_factor)
 canvas.draw_texture_rect_region(Art.tex("orchard_trunks"),box,Rect2(frame*64,0,64,64))
 var sway:=roundf(sin(time*.9+pos.x*.03)) if frame>0 else 0.0
 canvas.draw_texture_rect_region(Art.tex("orchard_canopies"),Rect2(box.position+Vector2(sway,0)*scale_factor,box.size),Rect2(frame*64,0,64,64),Color(1,1,1,alpha))
 if e.get("fertilized",false):canvas.draw_rect(Rect2(pos+Vector2(8,12)*scale_factor,Vector2.ONE*3*scale_factor),Color("e2c484"))
static func effect_color(crop_id: String) -> Color:
 return {"carrot":Color("e4ab67"),"pumpkin":Color("dfa65b"),"mint":Color("a7c789"),"rosemary":Color("adb5d6"),"apple":Color("e4b27a"),"berry":Color("9faed3")}.get(crop_id,Color("d9b9e2"))
