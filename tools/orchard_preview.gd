extends SceneTree
const Farm:=preload("res://scripts/core/homestead.gd")
const Orchard:=preload("res://scripts/core/orchard.gd")
var world: Node2D
var gs: Node
func _initialize():run.call_deferred()
func frames(n:=10):
 for i in n:await process_frame;await physics_frame
 RenderingServer.force_draw(false)
func shot(id: String):root.get_texture().get_image().save_png("res://orchard_"+id+".png")
func clean():
 world.fader.set_alpha(0);world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;world.hud.toast_panel.modulate.a=0;world.hud.banner.modulate.a=0
func camera(at: Vector2,zoom: float):
 world.player.position=at*32;world.player.camera.position=Vector2.ZERO;world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE*zoom
 await frames(12);clean();await frames()
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames();DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames()
 world.load_map("village","from_home");world.player.set_physics_process(false);root.size=Vector2i(1152,648);await frames()
 await camera(Vector2(19.5,31),.85);shot("empty_meadows")
 var cells: Dictionary=Farm.state().cells
 for x in range(11,20):cells[str(x)+",34"]={"kind":"channel"}
 for y in range(29,40):cells["26,"+str(y)]={"kind":"channel"}
 for at in [Vector2i(9,34),Vector2i(28,34),Vector2i(28,38)]:cells[Farm.key(at)]={"kind":"soil","crop":"apple","growth":240.0,"fertilized":false}
 var kinds:=["carrot","pumpkin","mint","rosemary","berry"]
 for i in kinds.size():
  for y in [33,35]:
   if y==33 and i>=2:continue
   cells[str(12+i)+","+str(y)]={"kind":"soil","crop":kinds[i],"growth":Farm.CROPS[kinds[i]].seconds,"fertilized":false}
 Orchard.sync(world);Farm.dirty=true
 await camera(Vector2(19.5,31),.85);shot("spacious_overview")
 await camera(Vector2(12.5,35.0),1.8);shot("ripe_vegetables_and_herbs")
 await camera(Vector2(28.5,36.0),1.7);shot("small_orchard")
 await camera(Vector2(28.5,33.5),1.8);shot("canopy_reveals_player")
 for stage in range(4):
  var ratio: float=[0.0,.3,.7,1.0][stage]
  for id: String in cells:
   var e: Dictionary=cells[id]
   if e.has("crop"):e.growth=Farm.CROPS[e.crop].seconds*ratio
  await camera(Vector2(12.5,35),1.8);shot("growth_"+str(stage))
 cells["28,34"].established=true;cells["28,34"].growth=0
 await camera(Vector2(28.5,36),1.7);shot("mature_after_harvest")
 for id: String in cells:
  if cells[id].has("crop"):cells[id].growth=Farm.Crops.duration(cells[id])
 gs.give("hs_hoe",1,true);gs.give("or_apple_seed",1,true);gs.give("or_carrot_seed",2,true);gs.coins=60
 world.player.position=Vector2(6.5,24)*32
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;await frames()
   var ui: Node=load("res://scripts/ui/orchard_ui.gd").new();ui.world=world;world.add_child(ui);ui.open();await frames(10);shot("seed_book_"+locale+str(size.x))
   ui.choose(4);await frames(8);shot("apple_book_"+locale+str(size.x))
   ui.choose(3);await frames(8);shot("herb_book_"+locale+str(size.x));ui.close();await frames()
   var tools: Node=load("res://scripts/ui/home_ui.gd").new();tools.world=world;world.add_child(tools);tools.open(null);await frames(10);shot("tools_"+locale+str(size.x));tools.close();await frames()
 world.queue_free();world=null;await frames();print("ORCHARD PREVIEW OK");quit()
