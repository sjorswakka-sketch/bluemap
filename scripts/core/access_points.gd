extends RefCounted
## Context at real doorways; closed decorative homes never promise an entrance.
const Maps:=preload("res://scripts/maps/registry.gd")
const RANGE:=72.0
static func prepare(data: Dictionary):
 var entrances: Array[Rect2]=[]
 for obj: Dictionary in data.objects:
  if obj.type!="portal" and not obj.get("travel_link",false):continue
  if not obj.get("enabled",true):continue
  var size: Array=obj.get("size",[1,1])
  entrances.append(Rect2(Vector2(obj.pos[0],obj.pos[1])*32,Vector2(size[0],size[1])*32))
 data["access_closed_doors"]=[]
 for y in data.rows.size():
  for x in data.rows[y].length():
   if data.rows[y][x]!="D":continue
   var cell:=Rect2(x*32,y*32,32,32)
   if entrances.any(func(r):return r.intersects(cell)):continue
   data.access_closed_doors.append(Vector2i(x,y))
static func closest(rect: Rect2,at: Vector2) -> Vector2:
 return Vector2(clampf(at.x,rect.position.x,rect.end.x),clampf(at.y,rect.position.y,rect.end.y))
static func visible(world: Node,goal: Vector2,locked: bool,allow_fence:=false) -> bool:
 var player: Node2D=world.player
 var query:=PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,8),goal+Vector2(0,8),1,[player.get_rid()])
 var hit: Dictionary=world.get_world_2d().direct_space_state.intersect_ray(query)
 if hit.is_empty():return true
 if allow_fence:
  var sample: Vector2=hit.position-hit.normal
  var cell:=Vector2i(sample/32)
  if cell.y>=0 and cell.y<world.map_data.rows.size() and cell.x>=0 and cell.x<world.map_size.x and world.map_data.rows[cell.y][cell.x]=="|":return true
 var script: Script=hit.collider.get_script()
 return locked and script!=null and (script.resource_path.ends_with("gate.gd") or script.resource_path.ends_with("diepte_seal.gd"))
static func nearby(world: Node) -> Dictionary:
 var player: Node2D=world.player
 if player.target!=null and is_instance_valid(player.target):return {}
 var best: Dictionary={};var distance:=RANGE
 for portal in world.get_tree().get_nodes_in_group("access_portals"):
  if portal.is_queued_for_deletion() or portal.world!=world or not Maps.MAPS.has(portal.target_map):continue
  var at:=closest(portal.rect,player.global_position);var delta:=at-player.global_position
  if delta.length()>distance or (delta.length()>1 and player.facing.dot(delta.normalized())<.2):continue
  var locked: bool=not portal.available()
  if not visible(world,portal.rect.get_center(),locked):continue
  distance=delta.length()
  var title: String=TranslationServer.translate("Naar %s") % TranslationServer.translate(Maps.MAPS[portal.target_map].DATA.name)
  var detail: String=TranslationServer.translate(portal.locked_text) if locked and portal.locked_text!="" else TranslationServer.translate("De doorgang is nog gesloten.") if locked else TranslationServer.translate("Loop door de doorgang.")
  best={"title":title,"detail":detail,"locked":locked,"rect":portal.rect}
 for cell: Vector2i in world.map_data.get("access_closed_doors",[]):
  var rect:=Rect2(Vector2(cell)*32,Vector2(32,32));var delta:=closest(rect,player.global_position)-player.global_position
  if delta.length()>distance or (delta.length()>1 and player.facing.dot(delta.normalized())<.2) or not visible(world,rect.get_center(),false,true):continue
  distance=delta.length();best={"title":TranslationServer.translate("Deze woning is gesloten."),"detail":"","locked":true,"rect":rect}
 return best
