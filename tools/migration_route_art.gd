extends SceneTree
## Isolated source draw capture; no original script or real player data is changed.
const Appearance := preload("res://scripts/data/ext/uiterlijk.gd")
const MAPS := ["village","player_home","forest_edge","forest"]
const OMIT := ["player.gd","pixel_canopy.gd","pixel_landscape.gd","npc.gd","enemy.gd","pickup.gd","portal.gd","trigger.gd","homestead.gd","personal_house.gd","house_furniture.gd","atmosphere.gd","world_memory.gd","water_scenery.gd","window_glow.gd","living_scenery.gd","first_route.gd","village_opening.gd","habitat_warning.gd"]
var output_dir := ""
var world: Node2D
var document := {"schemaVersion":1,"tilePixels":32,"alphaMode":"premultiplied","scenario":"fresh_baseline","clock":0,"gameSaveAccessed":false,"nodes":[],"sourceFiles":{}}
func _initialize():run.call_deferred()
func freeze(node: Node):
 node.set_process(false);node.set_physics_process(false);node.set_process_input(false);node.set_process_unhandled_input(false)
 for child in node.get_children():freeze(child)
func source(node: Node) -> String:
 var script: Script=node.get_script() as Script
 return script.resource_path if script!=null else ""
func run():
 if not OS.get_user_data_dir().replace(char(92),"/").get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unisolated route art refused");quit(1);return
 if DisplayServer.get_name()=="headless":push_error("Route art needs GPU renderer");quit(1);return
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0]!="--output-dir":push_error("Expected new --output-dir");quit(1);return
 output_dir=args[1]
 if DirAccess.dir_exists_absolute(output_dir):push_error("Never overwrite a route art export");quit(1);return
 DirAccess.make_dir_recursive_absolute(output_dir)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
 var gs: Node=root.get_node("GameState")
 for node in root.get_children():freeze(node)
 gs.new_game();gs.in_game=true;gs.set_process(false)
 document.palettes={"hair":[],"dye":[]}
 for entry: Dictionary in Appearance.HAIR_COLORS:document.palettes.hair.append([entry.color.r,entry.color.g,entry.color.b,entry.color.a])
 for entry: Dictionary in Appearance.DYE_COLORS:document.palettes.dye.append([entry.color.r,entry.color.g,entry.color.b,entry.color.a])
 for path: String in ["res://scripts/data/ext/uiterlijk.gd","res://scripts/core/character_layers.gd"]:document.sourceFiles[path]=FileAccess.get_sha256(path)
 for map_id in MAPS:
  seed(1001);gs.new_game();gs.in_game=true;gs.map_id=map_id;gs.spawn_name="start";gs.use_load_pos=false
  world=load("res://scenes/main.tscn").instantiate();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);current_scene=world;freeze(world)
  await process_frame;freeze(world)
  await process_frame;freeze(world)
  var candidates: Array=[]
  for slot in ["ground","entities"]:
   var container: Node=world.get(slot)
   for node: Node in container.get_children():
    var path:=source(node)
    if node is Node2D and not node.is_queued_for_deletion() and path!="" and path.get_file() not in OMIT and node.visible:
     candidates.append({"node":node,"address":slot+"/"+str(node.get_index())})
  for row: Dictionary in candidates:await capture(map_id,row.node,row.address)
  world.free();world=null;await process_frame
 var file:=FileAccess.open(output_dir.path_join("index.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(document,"  ",true)+"\n");file.close()
 print("MIGRATION ROUTE ART OK ",document.nodes.size()," source draw nodes")
 quit()
func capture(map_id: String,node: Node2D,address: String):
 var path:=source(node);document.sourceFiles[path]=FileAccess.get_sha256(path)
 var old_parent:=node.get_parent();var old_transform:=node.transform;var at:=node.global_position
 for property: Dictionary in node.get_property_list():
  if property.name in ["time","t","clock","animation_frame"]:node.set(property.name,0)
 var ground:=address.begins_with("ground/")
 var size:=Vector2i(world.map_size)*32+Vector2i(256,256) if ground else Vector2i(256,256)
 var viewport:=SubViewport.new();viewport.size=size;viewport.transparent_bg=true;viewport.world_2d=World2D.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
 root.add_child(viewport)
 node.reparent(viewport,false);node.position=Vector2(128,128);node.z_index=0;node.show()
 for child in node.get_children():
  if child is Light2D:child.enabled=false
 node.queue_redraw();await process_frame;RenderingServer.force_draw(false)
 var image:=viewport.get_texture().get_image();var used:=image.get_used_rect()
 if used.size.x>0 and used.size.y>0:
  used=used.grow(2).intersection(Rect2i(Vector2i.ZERO,size))
  var crop:=image.get_region(used)
  var bytes:=crop.save_png_to_buffer();var digest:=bytes.hex_encode().sha256_text()
  var name: String="node-"+digest.substr(0,20)+".png"
  if not FileAccess.file_exists(output_dir.path_join(name)):
   var file:=FileAccess.open(output_dir.path_join(name),FileAccess.WRITE);file.store_buffer(bytes);file.close()
  var fields: Dictionary={}
  for property: Dictionary in node.get_property_list():
   if property.name in ["obj","kind","key","unique_key"]:fields[property.name]=node.get(property.name)
  document.nodes.append({"mapId":map_id,"address":address,"script":path,"file":name,"position":[at.x,at.y],"offset":[used.position.x-128,used.position.y-128],"width":used.size.x,"height":used.size.y,"ground":ground,"fields":fields})
 node.reparent(old_parent,false);node.transform=old_transform
 viewport.queue_free();await process_frame
