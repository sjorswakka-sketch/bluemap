extends RefCounted
const Art:=preload("res://scripts/core/art.gd")
const Catalog:=preload("res://scripts/data/house_catalog.gd")
static func draw_piece(canvas: CanvasItem,entry: Dictionary,at: Vector2,scale_factor: float=1,modulate: Color=Color.WHITE):
 var kind: String=entry.kind;var info: Dictionary=Catalog.PIECES[kind];var tint: int=int(entry.get("tint",0))
 var dims: Vector2=Vector2(info.size)*32*scale_factor
 if kind=="rug":
  canvas.draw_texture_rect_region(Art.tex("house_rugs"),Rect2(at,dims),Rect2(tint*128,0,128,64),modulate);return
 var full:=Rect2(at+Vector2(dims.x/2-32*scale_factor,dims.y-64*scale_factor),Vector2.ONE*64*scale_factor)
 canvas.draw_texture_rect_region(Art.tex("house_furniture"),full,Rect2(int(info.frame)*64,tint*64,64,64),modulate)
static func icon(kind: String,tint: int=0) -> AtlasTexture:
 var texture:=AtlasTexture.new();texture.atlas=Art.tex("house_rugs" if kind=="rug" else "house_furniture")
 texture.region=Rect2(tint*128,0,128,64) if kind=="rug" else Rect2(int(Catalog.PIECES[kind].frame)*64,tint*64,64,64)
 return texture
