extends RefCounted
const Art:=preload("res://scripts/core/art.gd")
const Data:=preload("res://scripts/data/yard_catalog.gd")
const Yard:=preload("res://scripts/core/yard.gd")
static func mask(at: Vector2i,paths: Dictionary) -> int:
 var out:=0;var i:=0
 for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
  if paths.has(Yard.key(at+step)) or Yard.terrain(at+step) in [",","="]:out|=(1<<i)
  i+=1
 return out
static func path(canvas: CanvasItem,at: Vector2,kind: String,bits: int,scale_factor: float=1):
 canvas.draw_texture_rect_region(Art.tex("yard_paths"),Rect2(at,Vector2.ONE*32*scale_factor),Rect2(bits*32,int(Data.PIECES[kind].frame)*32,32,32))
static func fence(canvas: CanvasItem,at: Vector2,kind: String,opened: float=0,scale_factor: float=1):
 var frame: int=Data.PIECES[kind].frame;var box:=Rect2(at+Vector2(-16,-32)*scale_factor,Vector2.ONE*64*scale_factor)
 canvas.draw_texture_rect_region(Art.tex("yard_fences"),box,Rect2(frame*64,0,64,64),Color(1,1,1,1-opened))
 if opened>0:canvas.draw_texture_rect_region(Art.tex("yard_fences"),box,Rect2((frame+2)*64,0,64,64),Color(1,1,1,opened))
static func unit(canvas: CanvasItem,at: Vector2,id: String,scale_factor: float=1,alpha: float=1):
 var role: String=Data.UNITS[id].role
 if role in ["wine","hive"]:canvas.draw_texture_rect(Art.tex("pixel_station_"+role),Rect2(at+Vector2(-24,-31)*scale_factor,Vector2(80,80)*scale_factor),false,Color(1,1,1,alpha))
 else:
  canvas.draw_rect(Rect2(at+Vector2(-28,-9)*scale_factor,Vector2(62,48)*scale_factor),Color(Color("64523b"),alpha))
  canvas.draw_circle(at+Vector2(-4,10)*scale_factor,17*scale_factor,Color(Color("806341"),alpha));canvas.draw_circle(at+Vector2(15,9)*scale_factor,18*scale_factor,Color(Color("947753"),alpha))
