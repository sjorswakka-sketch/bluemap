extends Node2D
## Environment-only fixture. All resident decisions are original game methods.
class Player extends CharacterBody2D:
 var target:Node2D
 var sprinting:=false
 var roll_timer:=0.0
 var attack_timer:=0.0
 var bow_anim:=0.0
 var combat:Node
class Combat extends Node:
 var phase:=""
var player:Player
var map_size:=Vector2i(40,36)
var map_data:Dictionary={"objects":[],"weather":""}
var solid_cells:Dictionary={}
var entities:Node2D
var blocked_points:Array=[]
func _init():
 player=Player.new();player.combat=Combat.new();player.add_child(player.combat);add_child(player)
 entities=Node2D.new();add_child(entities)
func is_solid(at:Vector2)->bool:
 return Vector2i(floor(at.x/32),floor(at.y/32)) in solid_cells or at in blocked_points
func ring(_at:Vector2,_radius:float,_color:Color):pass
class Director extends Node2D:
 var grid:=AStarGrid2D.new()
 var supplied:=PackedVector2Array()
 func walk_path(_actor:Node2D,_goal:Vector2i)->PackedVector2Array:return supplied.duplicate()
