extends "res://tests/coast_expedition_test.gd"
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 for c in ["R","b","G"]:check(not Tiles.is_solid_char(c),"low dry decorative vegetation walkable "+c)
 for c in [";","l","F","~","3","#","P","Y"]:check(Tiles.is_solid_char(c),"water plants and trees retain collision "+c)
 check(Tiles.footstep_surface("reed")=="grass" and Tiles.footstep_surface("snow_bush")=="snow","vegetation footsteps match dry ground")
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("kruipmoeras");p.set_physics_process(false)
 var atlas: TileSetAtlasSource=world.tile_set.get_source(0)
 for kind in ["reed","bush","snow_bush"]:
  var index:=Tiles.index_of(kind);check(index>=0,"legacy atlas retains vegetation tile "+kind)
  if index<0:continue
  check(atlas.get_tile_data(Vector2i(index,0),0).get_collision_polygons_count(0)==0,"actual tile atlas has no dry vegetation collider "+kind)
 var reeds:=0
 for y in world.map_data.rows.size():
  for x in world.map_data.rows[y].length():
   if world.map_data.rows[y][x]=="R":
    reeds+=1;check(not world.solid_cells.has(Vector2i(x,y)),"real marsh reed passes on fixed ground "+str(Vector2i(x,y)))
 check(reeds>0,"real marsh retains visible reeds")
 await enter("lake")
 var wet:=0
 for y in world.map_data.rows.size():
  for x in world.map_data.rows[y].length():
   if world.map_data.rows[y][x]==";":wet+=1;check(world.solid_cells.has(Vector2i(x,y)),"water reed remains unsafe to walk "+str(Vector2i(x,y)))
 check(wet>0,"lake retains water-based reeds")
 world.queue_free();await frames();print("VEGETATION ACCESS OK" if failures==0 else "VEGETATION ACCESS FAILED "+str(failures));quit(0 if failures==0 else 1)
