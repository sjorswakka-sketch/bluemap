extends RefCounted
## Short, collision-checked errands around the original quest anchor.
const Tiles:=preload("res://scripts/data/tiles.gd")
static func safe(npc: Node2D,at: Vector2) -> bool:
 if at.distance_to(npc.roam_anchor)>46:return false
 for offset in [Vector2(-8,0),Vector2(8,0),Vector2(0,14),Vector2(0,-10)]:
  if npc.world.is_solid(at+offset):return false
 for spec: Dictionary in npc.world.map_data.objects:
  if not spec.get("enabled",true) or spec.type in ["npc","trigger","pickup","profession_resource"]:continue
  var size: Array=spec.get("size",[1,1])
  var rect:=Rect2(Vector2(spec.pos[0],spec.pos[1])*32,Vector2(size[0],size[1])*32).grow(14)
  if rect.has_point(at):return false
 if Engine.get_main_loop().root.get_node("GameState").map_id=="village" and at.y>=29*32:return false
 for other in npc.get_tree().get_nodes_in_group("npc"):
  if other!=npc and not other.is_queued_for_deletion() and other.position.distance_to(at)<26:return false
 return true
static func update(npc: CharacterBody2D,delta: float):
 npc.velocity=Vector2.ZERO
 var gs: Node=Engine.get_main_loop().root.get_node("GameState")
 if gs.input_locked() or npc.npc_id=="muis_bos":return
 var player: Node2D=npc.world.player
 if player.position.distance_to(npc.position)<62:return
 npc.roam_wait=maxf(0,npc.roam_wait-delta)
 if npc.roam_wait>0:return
 if npc.roam_goal.distance_to(npc.position)<1:
  npc.roam_wait=randf_range(3,7)
  var choices: Array[Vector2]=[]
  for step in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
   var candidate: Vector2=npc.position+step*24
   if safe(npc,candidate):choices.append(candidate)
  if not choices.is_empty():npc.roam_goal=choices.pick_random()
  return
 var next: Vector2=npc.position.move_toward(npc.roam_goal,18*delta)
 if not safe(npc,next):npc.roam_goal=npc.position;npc.roam_wait=2;return
 npc.velocity=(npc.roam_goal-npc.position).normalized()*18
 var before: Vector2=npc.position
 npc.move_and_slide()
 if before.distance_to(npc.position)<.01:npc.roam_goal=npc.position;npc.roam_wait=2
