extends Node2D
const Yard:=preload("res://scripts/core/yard.gd")
const Paint:=preload("res://scripts/core/yard_art.gd")
var world: Node2D
func _ready():add_to_group("yard_scenery");Yard.sync(world)
func _draw():
 for id: String in Yard.state().paths:
  var at:=Yard.cell(id);Paint.path(self,Vector2(at)*32,Yard.state().paths[id],Paint.mask(at,Yard.state().paths))

 for id: String in Yard.state().extensions:
  var r: Rect2i=Yard.Data.EXTENSIONS[id].rect
  for cell: Vector2i in [r.position,Vector2i(r.end.x-1,r.position.y),Vector2i(r.position.x,r.end.y-1),r.end-Vector2i.ONE]:
   if not Yard.farm_cells().has(Yard.key(cell)):draw_rect(Rect2(Vector2(cell)*32+Vector2(2,2),Vector2(5,4)),Color("a7ad8d"))
