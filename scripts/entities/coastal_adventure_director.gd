extends Node2D
const Adventure:=preload("res://scripts/core/coastal_adventures.gd")
var world: Node2D
var keeper: Node2D
var map_id:=""
var time:=0.0
func _ready():map_id=GameState.map_id;add_to_group("adventure_directors")
func _process(delta: float):
 time+=delta;queue_redraw()
 if is_queued_for_deletion() or GameState.map_id!=map_id:return
 if map_id!="tidal_hollow":return
 if GameState.flag("ad_keeper_done"):
  if is_instance_valid(keeper) and not keeper.is_queued_for_deletion():keeper.queue_free()
  return
 if GameState.flag("ad_duel") and not is_instance_valid(keeper):
  keeper=world.spawn_enemy("ad_keeper",Vector2(47.5,13.5)*32,"ad_keeper_defeated")
  keeper.died.connect(func():Adventure.resolve(false))

func _draw():
 if map_id!="tidal_hollow":return
 if GameState.flag("ad_wheel_done"):
  for y in range(5,27,2):
   var x:=30*32+sin(time*1.4+y)*8
   draw_line(Vector2(x-18,y*32),Vector2(x+18,y*32),Color(0.6,0.83,0.83,0.25),2)
 if GameState.flag("ad_pool"):
  for i in 10:
   var base:=Vector2((41+i)*32,10*32)
   draw_line(base,base+Vector2(sin(time+i)*4,-18-i%3*6),Color("7bb69b"),3)
