extends SceneTree
const Maps:=preload("res://scripts/maps/registry.gd")
const Tiles:=preload("res://scripts/data/tiles.gd")
const Visual:=preload("res://scripts/core/pixel_landscape.gd")
const Art:=preload("res://scripts/core/art.gd")
var world: Node2D
var gs: Node
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	print("  ok   " if ok else "  FAIL ",message)
	if not ok:failures+=1
func frames(n:=6):
	for i in n:await process_frame
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12)
	var atlas: TileSetAtlasSource=world.tile_set.get_source(0)
	check(atlas.texture.get_size()==Vector2(Tiles.NAMES.size()*32,256),"all 80 terrain identities have eight native 32px variants")
	for index in Tiles.NAMES.size():
		var valid:=true
		for variant in 8:
			var data:=atlas.get_tile_data(Vector2i(index,variant),0)
			valid=valid and (data.get_collision_polygons_count(0)==1)==Tiles.is_solid_name(Tiles.NAMES[index])
			if Tiles.is_solid_name(Tiles.NAMES[index]):
				var polygon:=data.get_collision_polygon_points(0,0)
				valid=valid and polygon[0]==Vector2(-16,-16) and polygon[2]==Vector2(16,16)
		check(valid,"all variants retain physical footprint: "+Tiles.NAMES[index])
	var texture:=Art.tex("player");var detail:=Art.detailed(texture)
	check(texture.get_size()==Vector2(48,64) and detail.get_size()==Vector2(96,128),"legacy UI and appearance coordinates keep their original atlas size")
	check(Art.detailed(Art.tex("items"))==Art.tex("items"),"legacy item atlases do not change size or frame indices")
	for map: String in Maps.MAPS:
		world.load_map(map,"start");world.player.set_physics_process(false);await frames()
		var landscape: Node2D=world.landscape
		var trees:=0;var waters:=0;var variants_ok:=true
		for y in world.map_size.y:
			for x in world.map_size.x:
				var name:=Visual.at(world.map_data.rows,Vector2i(x,y))
				if name in ["tree","pine","willow"]:trees+=1
				if name in Visual.WATER:waters+=1
				var coords: Vector2i=world.tile_layer.get_cell_atlas_coords(Vector2i(x,y))
				variants_ok=variants_ok and coords.x==Tiles.index_of(name) and coords.y>=0 and coords.y<8
		check(variants_ok and world.tile_layer.scale==Vector2.ONE,"terrain material and grid coordinates stay aligned: "+map)
		check(landscape.canopies.size()==trees and landscape.water.size()==waters,"one crown per real tree and waves only on actual water: "+map)
		var rebuilds: int=landscape.rebuilds;await frames(12)
		check(landscape.rebuilds==rebuilds,"static shore/shadow textures are cached between frames: "+map)
	world.load_map("forest","start");await frames()
	var layer: Node2D=world.landscape
	var tree: Vector2i=layer.canopies.keys()[0]
	var crown: Node2D=layer.canopies[tree]
	layer.reveal_at(crown.position+Vector2(0,-25))
	check(crown.modulate.a<.6,"canopy reveals an actor behind its leaves")
	world.player.position=Vector2(40000,40000);layer.reveal_player()
	check(crown.modulate.a==1,"canopy opacity is restored when the actor leaves")
	world.load_map("tide_cove","start");await frames()
	var tide: Node=get_first_node_in_group("tide_cove")
	world.player.position=Vector2(16,6)*32
	gs.day_time=.0;tide.sync();await frames()
	var before: int=world.landscape.rebuilds
	gs.day_time=.15;tide.sync();await frames()
	check(world.landscape.rebuilds>before,"changing tide rebuilds shore and wave caches")
	gs.set_flag("meer_achterkamer",true);world.load_map("library","start");await frames(12)
	var consistent:=true
	for node in world.entities.get_children():
		if node.get_script()==load("res://scripts/entities/meer_kast.gd"):
			for cell: Vector2i in node.cells:consistent=consistent and Visual.at(world.map_data.rows,cell)=="meer_bibvloer" and not world.solid_cells.has(cell)
	check(consistent,"opened secret bookcase updates art and physical floor together")
	world.queue_free();world=null;await frames()
	if failures==0:print("VISUAL UPGRADE TEST OK")
	quit(0 if failures==0 else 1)
