extends Node2D
const House:=preload("res://scripts/core/personal_home.gd")
const Catalog:=preload("res://scripts/data/house_catalog.gd")
const Paint:=preload("res://scripts/core/house_art.gd")
const Art:=preload("res://scripts/core/art.gd")
var world: Node2D
func _ready():add_to_group("personal_house");House.sync(world)
func _draw():
 var data:=House.state()
 for y in range(14):
  for x in range(14):
   var floor_cell: bool=world.map_data.rows[y][x]=="w"
   var index: int=int(data.floor) if floor_cell else 4+int(data.wall)
   draw_texture_rect_region(Art.tex("house_surfaces"),Rect2(x*32,y*32,32,32),Rect2(index*32,0,32,32))
 # A single woven piece stays below actors and solid furnishings.
 for entry: Dictionary in data.layout.values():
  if Catalog.PIECES[entry.kind].get("floor",false):Paint.draw_piece(self,entry,Vector2(House.rect(entry).position)*32)
 # Restrained inner trim; doorway is left entirely clear.
 draw_line(Vector2(64,64),Vector2(384,64),Color("ddc69e"),2)
 draw_line(Vector2(64,64),Vector2(64,384),Color("b9a17c"),2);draw_line(Vector2(384,64),Vector2(384,384),Color("b9a17c"),2)
