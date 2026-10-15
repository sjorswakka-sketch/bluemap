extends SceneTree
const Farm:=preload("res://scripts/core/homestead.gd")
var world: Node2D
var gs: Node
func _initialize():run.call_deferred()
func frames(n:=10):
 for i in n:await process_frame
 RenderingServer.force_draw(false)
func station(role: String) -> Node2D:
 for n in get_nodes_in_group("home_stations"):
  if not n.is_queued_for_deletion() and n.obj.role==role:return n
 return null
func field() -> Node2D:
 for n in get_nodes_in_group("homesteads"):
  if not n.is_queued_for_deletion():return n
 return null
func setup(kind: String):
 Farm.reset();gs.homestead=Farm.normalize({});gs.set_flag("hs_garden_help",false);gs.set_flag("hs_intro_harvest",false);gs.day_time=.5
 world.load_map("forest" if kind=="wild_grape" else "player_home" if kind=="bed" else "village","start",Vector2.INF if kind in ["bed","wild_grape"] else Vector2(12.5,35.5)*32);world.player.set_physics_process(false)
 world.player.facing=Vector2.UP;world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2(2,2)
 for n in get_nodes_in_group("enemies"):n.set_process(false);n.set_physics_process(false)
 if kind not in ["tools","guide","compost","wild_grape","bed"]:
  var stage:=90.0 if kind=="ripe" else 45.0 if kind in ["flow","restore","night"] else 0.0
  Farm.state().cells["12,34"]={"kind":"soil","crop":"grape","growth":stage,"fertilized":kind=="ripe"}
  if kind!="dry":
   for x in range(10,20):Farm.state().cells[str(x)+",33"]={"kind":"channel"}
   for x in [10,11,13,14]:
    Farm.state().cells[str(x)+",34"]={"kind":"soil","crop":"flower" if x==14 else "grape","growth":90.0,"fertilized":false}
  Farm.mode="harvest" if kind=="ripe" else "fill" if kind=="restore" else "channel" if kind=="flow" else "grape"
  Farm.show_water=kind=="flow";gs.set_flag("hs_garden_help",kind in ["dry","flow"]);Farm.dirty=true;Farm.irrigate()
 if kind=="night":gs.day_time=.9;Farm.mode=""
 world.player._update_target();world.fader.set_alpha(0);await frames(15)
 world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;world.hud.toast_panel.modulate.a=0;world.hud.banner.modulate.a=0
 if kind in ["tools","guide","wine","hive","compost","wild_grape","bed"]:
  var node:=station("guide" if kind=="guide" else kind) if kind!="tools" else null
  if kind=="wine":Farm.state().jobs["wine_a"]={"batches":8,"time":65.0}
  if kind=="hive":Farm.state().honey=3;Farm.state().honey_time=42.0
  if node!=null:world.player.position=node.position+Vector2(0,30)
  var ui: CanvasLayer=load("res://scripts/ui/home_ui.gd").new();ui.world=world;world.add_child(ui);ui.open(node)
 await frames(15)
func shot(name: String):
 root.get_texture().get_image().save_png("res://garden_"+name+".png")
 for ui in get_nodes_in_group("home_ui"):
  if not ui.is_queued_for_deletion():ui.close()
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 gs.give("hs_hoe",1,true);gs.give("hs_seed",8,true);gs.give("hs_flower_seed",4,true);gs.give("hs_fertilizer",3,true)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(20)
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size
   for kind in ["tools","guide","dry","flow","ripe","restore","wine","hive","compost","wild_grape","bed"]:
    await setup(kind);shot(kind+"_"+locale+str(size.x));await frames(3)
   await setup("tools")
   for ui in get_nodes_in_group("home_ui"):
    if not ui.is_queued_for_deletion():ui.close()
   await frames(3)
   var crafting: Node=world.crafting_ui
   crafting.open()
   for skill: String in crafting.Data.SKILLS:
    crafting.selected_skill=skill;crafting._populate();await frames(15);shot("profession_"+skill+"_"+locale+str(size.x))
   crafting.close();await frames(3)
 root.size=Vector2i(1152,648)
 for kind in ["ripe","night"]:
  await setup(kind);Farm.mode="";gs.set_flag("hs_garden_help",false);world.player.camera.zoom=Vector2.ONE;await frames(15);shot("quiet_"+kind)
 await setup("ripe");Farm.state().cells.clear()
 var count:=0
 for y in range(29,41):
  for x in range(4,35):
   var at:=Vector2i(x,y);var pos:=Vector2(at)*32+Vector2(16,16)
   if not Farm.garden(at) or world.map_data.rows[y][x]!="." or not world.spawn_fits(pos):continue
   Farm.state().cells[Farm.key(at)]={"kind":"channel"} if y in [30,33,36,39] else {"kind":"soil","crop":"flower" if x%6==0 else "grape","growth":90.0,"fertilized":x%4==0}
   count+=1
 Farm.dirty=true;Farm.irrigate();Farm.mode="";world.player.camera.zoom=Vector2.ONE;await frames(15);shot("large_quiet")
 Farm.mode="channel";Farm.show_water=true;await frames(15);shot("large_water")
 var samples: Array[float]=[]
 for i in 90:
  var start:=Time.get_ticks_usec();await frames(1);samples.append((Time.get_ticks_usec()-start)/1000.0)
 samples.sort()
 var report: Dictionary={"cells":count,"channels":Farm.wet.size(),"rendered_frames":samples.size(),"median_wall_ms":samples[samples.size()/2],"p95_wall_ms":samples[int(samples.size()*.95)],"note":"Native Windows OpenGL preview with forced drawing; wall time is diagnostic, not a hardware-independent frame guarantee."}
 var out:=FileAccess.open("res://garden_profile.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
 world.queue_free();world=null;await frames(10);print("GARDEN PREVIEW OK");quit()
