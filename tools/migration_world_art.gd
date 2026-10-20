extends SceneTree
## Isolated source draw capture; no original script or real player data is changed.
const Scenarios := preload("res://tools/migration_world_scenarios.gd")
const Appearance := preload("res://scripts/data/ext/uiterlijk.gd")
const BASE_ROUTE := ["village","player_home","forest_edge","forest"]
const OMIT := ["player.gd","pixel_canopy.gd","pixel_landscape.gd","npc.gd","enemy.gd","pickup.gd","portal.gd","trigger.gd","homestead.gd","personal_house.gd","house_furniture.gd","atmosphere.gd","world_memory.gd","window_glow.gd","living_scenery.gd","first_route.gd","village_opening.gd","habitat_warning.gd"]
var output_dir := ""
var world: Node2D
var document := {"schemaVersion":1,"tilePixels":32,"alphaMode":"premultiplied","scenario":"fresh_baseline","clock":0,"gameSaveAccessed":false,"nodes":[],"sourceFiles":{},"snapshots":[],"frozenMethods":[]}
func _initialize():run.call_deferred()
func freeze(node: Node):
 node.set_process(false);node.set_physics_process(false);node.set_process_input(false);node.set_process_unhandled_input(false)
 for child in node.get_children():freeze(child)
func source(node: Node) -> String:
 var script: Script=node.get_script() as Script
 return script.resource_path if script!=null else ""
func run():
 document.sourceFiles["res://tools/migration_world_scenarios.gd"]=FileAccess.get_sha256("res://tools/migration_world_scenarios.gd")
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
 for scenario: Dictionary in Scenarios.manifest():
  for map_id: String in scenario.maps:
   if scenario.id=="fresh_baseline" and map_id in BASE_ROUTE:continue
   Scenarios.configure(scenario.id);gs.map_id=map_id;gs.spawn_name="start";gs.use_load_pos=false
   seed(Scenarios.FIXTURE_SEED+hash(scenario.id+":"+map_id))
   world=load("res://scenes/main.tscn").instantiate();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);current_scene=world;freeze(world)
   await process_frame;freeze(world)
   Scenarios.project(world);freeze(world)
   await process_frame;freeze(world)
   await process_frame;freeze(world)
   var candidates: Array=[]
   for slot in ["ground","entities"]:
    var container: Node=world.get(slot)
    for node: Node in container.get_children():
     var path:=source(node)
     if node is Node2D and not node.is_queued_for_deletion() and path!="" and path.get_file() not in OMIT and node.visible:
      candidates.append({"node":node,"address":slot+"/"+str(node.get_index())})
   var count_before: int=document.nodes.size()
   for row: Dictionary in candidates:await capture(map_id,scenario.id,row.node,row.address)
   document.snapshots.append({"mapId":map_id,"scenarioId":scenario.id,"drawNodes":document.nodes.size()-count_before})
   print("WORLD ART SNAPSHOT "+scenario.id+"/"+map_id)
   world.free();world=null;await process_frame
 var file:=FileAccess.open(output_dir.path_join("index.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(document,"  ",true)+"\n");file.close()
 print("MIGRATION WORLD ART OK ",document.nodes.size()," source draw nodes")
 quit()
func capture(map_id: String,scenario_id: String,node: Node2D,address: String):
 var path:=source(node);document.sourceFiles[path]=FileAccess.get_sha256(path)
 var original:=node
 var old_parent:=node.get_parent();var old_transform:=node.transform;var at:=node.global_position
 # The sole real-time draw call is copied into a disposable CanvasItem with
 # that explicit clock expression set to zero; original files stay untouched.
 if path.ends_with("/tide_cove.gd"):
  var code:=FileAccess.get_file_as_string(path)
  var start:=code.find("func _draw():")
  var draw_code:=code.substr(start).replace("Time.get_ticks_msec()/1000.0","0.0")
  var frozen:=GDScript.new();frozen.source_code="extends Node2D\nvar flooded := true\n"+draw_code
  if frozen.reload()!=OK:push_error("Cannot freeze original tide draw clock");quit(1);return
  node=frozen.new();node.flooded=original.flooded
  old_parent.add_child(node);node.position=original.position
  document.frozenMethods.append({"mapId":map_id,"scenarioId":scenario_id,"script":path,"method":"_draw","clockExpression":"Time.get_ticks_msec()/1000.0","clockValue":0})
 if path.ends_with("/water_scenery.gd"):world.player.camera.zoom=Vector2(.05,.05)
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
  if child is CanvasLayer:child.hide()
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
  document.nodes.append({"mapId":map_id,"scenarioId":scenario_id,"address":address,"script":path,"file":name,"position":[at.x,at.y],"offset":[used.position.x-128,used.position.y-128],"width":used.size.x,"height":used.size.y,"ground":ground,"fields":fields})
 if node==original:node.reparent(old_parent,false);node.transform=old_transform
 else:node.queue_free()
 viewport.queue_free();await process_frame
