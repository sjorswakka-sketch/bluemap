extends SceneTree
## Real loaded-world reference export. ONLY run via record_migration_world.py.
## No gameplay script is replaced; processing is frozen after normal _ready.
const Scenarios := preload("res://tools/migration_world_scenarios.gd")
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Beroepen := preload("res://scripts/data/ext/beroepen.gd")
const Farm := preload("res://scripts/core/homestead.gd")
var failures: Array[String] = []
var output_dir := ""
var selected := ""
var addresses: Dictionary = {}
var world: Node2D
var gs: Node
var ui_sources: Dictionary = {}
var handles: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child: Node in node.get_children():_freeze(child)

func script_path(value: Object) -> String:
	var script: Script = value.get_script() as Script
	return script.resource_path if script != null else ""

func address_nodes(node: Node, address: Array, ui := false) -> void:
	var is_ui: bool = ui or node is Control or node is CanvasLayer
	addresses[node] = ["ui"] + address if is_ui else address
	if is_ui and script_path(node) != "":ui_sources[script_path(node)] = true
	for child: Node in node.get_children():
		if not child.is_queued_for_deletion():address_nodes(child, address + [child.get_index()], is_ui)

func wire(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_NIL:return {"kind":"nil"}
		TYPE_BOOL:return {"kind":"bool","value":value}
		TYPE_INT:return {"kind":"int","value":str(value)}
		TYPE_FLOAT:
			require(is_finite(value), "Non-finite exported world value")
			return {"kind":"float","value":JSON.stringify(value,"",true,true)}
		TYPE_STRING:return {"kind":"string","value":value}
		TYPE_STRING_NAME:return {"kind":"string_name","value":str(value)}
		TYPE_NODE_PATH:return {"kind":"node_path","value":str(value)}
		TYPE_ARRAY:
			var items: Array = []
			for child: Variant in value:items.append(wire(child))
			return {"kind":"array","type":"Array","values":items}
		TYPE_DICTIONARY:
			var pairs: Array = []
			for key: Variant in value:pairs.append([wire(key),wire(value[key])])
			return {"kind":"dictionary","entries":pairs}
		TYPE_VECTOR2,TYPE_VECTOR2I:return {"kind":"vector","type":type_string(typeof(value)),"values":[wire(value.x),wire(value.y)]}
		TYPE_VECTOR3,TYPE_VECTOR3I:return {"kind":"vector","type":type_string(typeof(value)),"values":[wire(value.x),wire(value.y),wire(value.z)]}
		TYPE_VECTOR4,TYPE_VECTOR4I:return {"kind":"vector","type":type_string(typeof(value)),"values":[wire(value.x),wire(value.y),wire(value.z),wire(value.w)]}
		TYPE_RECT2,TYPE_RECT2I:return {"kind":"rect","type":type_string(typeof(value)),"position":wire(value.position),"size":wire(value.size)}
		TYPE_COLOR:return {"kind":"color","rgba":[wire(value.r),wire(value.g),wire(value.b),wire(value.a)]}
		TYPE_TRANSFORM2D:return {"kind":"transform2d","x":wire(value.x),"y":wire(value.y),"origin":wire(value.origin)}
		TYPE_OBJECT:
			if not is_instance_valid(value):return {"kind":"nil"}
			if value is Node:
				if value == world:return {"kind":"node_ref","address":["world"]}
				if addresses.has(value):return {"kind":"node_ref","address":addresses[value]}
				if value.get_parent() == root:return {"kind":"node_ref","address":["autoload",str(value.name)]}
				return {"kind":"node_ref","address":["outside",value.get_class(),script_path(value)]}
			if value is Resource:return {"kind":"resource_ref","class":value.get_class(),"path":value.resource_path}
			return runtime_handle(value.get_class(), "Runtime object; behavior and initialization retained in source, not a persistent world value")
		TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID:
			return runtime_handle(type_string(typeof(value)), "Runtime callback/engine handle; never executed or rehydrated by the data reader")
		TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY,TYPE_PACKED_STRING_ARRAY,TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_VECTOR4_ARRAY,TYPE_PACKED_COLOR_ARRAY:
			var items: Array = []
			for child: Variant in value:items.append(wire(child))
			return {"kind":"array","type":type_string(typeof(value)),"values":items}
	require(false, "Unsupported world value type: " + type_string(typeof(value)))
	return {"kind":"nil"}

func runtime_handle(type: String, reason: String) -> Dictionary:
	handles[type] = true
	return {"kind":"runtime_handle","type":type,"reason":reason}

func fields(node: Object) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[str(property.name)] = node.get(property.name)
	return result

func shape_parameters(shape: Shape2D) -> Dictionary:
	if shape is CircleShape2D:return {"radius":shape.radius}
	if shape is RectangleShape2D:return {"size":shape.size}
	if shape is CapsuleShape2D:return {"radius":shape.radius,"height":shape.height}
	if shape is SegmentShape2D:return {"a":shape.a,"b":shape.b}
	if shape is ConvexPolygonShape2D:return {"points":shape.points}
	if shape is ConcavePolygonShape2D:return {"segments":shape.segments}
	if shape is WorldBoundaryShape2D:return {"normal":shape.normal,"distance":shape.distance}
	if shape is SeparationRayShape2D:return {"length":shape.length,"slide_on_slope":shape.slide_on_slope}
	require(false,"Uncaptured collision shape: " + shape.get_class())
	return {}

func capture_node(node: Node, result: Array) -> void:
	if node.is_queued_for_deletion() or node is CanvasLayer or node is Control:return
	var address: Array = addresses[node]
	var parent: Variant = address.slice(0,-1) if address.size() > 1 else null
	var groups: Array = []
	for group: StringName in node.get_groups():
		if not str(group).begins_with("_"):groups.append(str(group))
	groups.sort()
	var record: Dictionary = {"address":address,"parent":parent,"class":node.get_class(),"script":script_path(node),"groups":groups,"fields":wire(fields(node)),"omissions":[]}
	if node is Node2D:
		record.localTransform = wire(node.transform)
		record.globalTransform = wire(node.global_transform)
		record.visible = node.visible
		record.native = wire({"z_index":node.z_index,"z_as_relative":node.z_as_relative,"y_sort_enabled":node.y_sort_enabled,"modulate":node.modulate,"self_modulate":node.self_modulate})
	else:
		record.localTransform = wire(Transform2D.IDENTITY)
		record.globalTransform = wire(Transform2D.IDENTITY)
		record.visible = true
	if node is CollisionObject2D:record.collision = {"layer":node.collision_layer,"mask":node.collision_mask}
	if node is CollisionShape2D and node.shape != null:
		record.shape = {"class":node.shape.get_class(),"disabled":node.disabled,"parameters":wire(shape_parameters(node.shape)),"oneWay":node.one_way_collision,"oneWayMargin":node.one_way_collision_margin}
	if node is CollisionPolygon2D:
		record.shape = {"class":"CollisionPolygon2D","disabled":node.disabled,"parameters":wire({"polygon":node.polygon,"build_mode":node.build_mode}),"oneWay":node.one_way_collision,"oneWayMargin":node.one_way_collision_margin}
	if node is Sprite2D:
		record.sprite = wire({"texture":node.texture,"hframes":node.hframes,"vframes":node.vframes,"frame":node.frame,"offset":node.offset,"centered":node.centered,"region_enabled":node.region_enabled,"region_rect":node.region_rect,"flip_h":node.flip_h,"flip_v":node.flip_v})
	if node is Light2D:
		var lighting := {}
		for property: Dictionary in node.get_property_list():
			if str(property.name) in ["enabled","color","energy","texture","texture_scale","height","shadow_enabled","range_z_min","range_z_max","range_layer_min","range_layer_max"]:lighting[str(property.name)] = node.get(property.name)
		record.light = wire(lighting)
	result.append(record)
	for child: Node in node.get_children():capture_node(child,result)

func state() -> Dictionary:
	var result := {}
	for name: String in ["hp","coins","inventory","flags","quests","weapon","map_id","spawn_name","visited_maps","play_time","kills","hero_xp","meer","professions","homestead","yard","personal_home","stockroom","coastal_storage","equipment","appearance","clothing","day_time","day_count","kills_by","rolls","potions_drunk","deaths","boss_deaths","talked","achievements","arena_records","ng_plus"]:
		result[name] = gs.get(name)
	return result

func tile_set_data() -> Dictionary:
	var sources: Array = []
	var tileset: TileSet = world.tile_set
	for source_index in tileset.get_source_count():
		var source_id: int = tileset.get_source_id(source_index)
		var source: TileSetAtlasSource = tileset.get_source(source_id) as TileSetAtlasSource
		require(source != null,"Unknown native tile source")
		if source == null:continue
		var entries: Array = []
		for index in source.get_tiles_count():
			var coordinate: Vector2i = source.get_tile_id(index)
			var tile: TileData = source.get_tile_data(coordinate,0)
			var layers: Array = []
			for layer in tileset.get_physics_layers_count():
				var polygons: Array = []
				for polygon in tile.get_collision_polygons_count(layer):
					polygons.append({"points":tile.get_collision_polygon_points(layer,polygon),"one_way":tile.is_collision_polygon_one_way(layer,polygon),"one_way_margin":tile.get_collision_polygon_one_way_margin(layer,polygon)})
				layers.append({"layer":layer,"collision_layer":tileset.get_physics_layer_collision_layer(layer),"collision_mask":tileset.get_physics_layer_collision_mask(layer),"polygons":polygons})
			entries.append({"atlas":coordinate,"alternative":0,"layers":layers})
		sources.append({"id":source_id,"texture":source.texture,"region_size":source.texture_region_size,"tiles":entries})
	return {"tile_size":tileset.tile_size,"physics_layers":tileset.get_physics_layers_count(),"sources":sources}

func snapshot(scenario: Dictionary, before: Dictionary, calls: Array) -> Dictionary:
	addresses.clear()
	address_nodes(world.entities,["entities"])
	address_nodes(world.ground,["ground"])
	address_nodes(world.atmosphere,["atmosphere"])
	var scene: Array = []
	capture_node(world.entities,scene)
	capture_node(world.ground,scene)
	capture_node(world.atmosphere,scene)
	var slots: Array = []
	var registry_count: int = Maps.get_map(gs.map_id).objects.size()
	for index in world.map_data.objects.size():
		var obj: Dictionary = world.map_data.objects[index]
		slots.append({"index":index,"registryIndex":index if index < registry_count else null,"appendOrder":index-registry_count if index >= registry_count else null,"type":obj.type,"legacySlotKey":"%s:%s:%d" % [obj.type,gs.map_id,index],"enabled":obj.get("enabled",true),"conditionsPassed":gs.check_all(obj.get("if",[]))})
	var cells: Array = []
	var solids: Array = []
	for y in world.map_size.y:
		for x in world.map_size.x:
			var coordinate := Vector2i(x,y)
			var atlas: Vector2i = world.tile_layer.get_cell_atlas_coords(coordinate)
			cells.append([x,y,world.tile_layer.get_cell_source_id(coordinate),atlas.x,atlas.y,world.tile_layer.get_cell_alternative_tile(coordinate)])
			if world.solid_cells.has(coordinate):solids.append([x,y])
	var arrivals: Array = []
	for name: String in world.map_data.spawns:
		var at: Vector2 = world._tile_center(world.map_data.spawns[name])
		if gs.map_id == "village" and name == "start" and gs.play_time < 1 and preload("res://scripts/core/opening.gd").enabled():at += Vector2(0,48)
		var resolved: Vector2 = world._safe_fountain_spawn(preload("res://scripts/core/regional_adventures.gd").safe_position(gs.map_id,at))
		if gs.map_id == "player_home":
			var house: Script = preload("res://scripts/core/personal_home.gd")
			if house.player_reason(house.state().layout,resolved) != "":resolved = Vector2(6.5,10.5)*32
		resolved = world.safe_spawn_position(resolved)
		arrivals.append({"name":name,"nominal":wire(at),"resolved":wire(resolved),"fits":world.spawn_fits(resolved)})
	var environment: Dictionary = {"darkness":world.darkness,"canvas_color":world.canvas_mod.color,"atmosphere":fields(world.atmosphere),"player_position":world.player.position,"camera":{"zoom":world.player.camera.zoom,"offset":world.player.camera.offset,"limits":[world.player.camera.limit_left,world.player.camera.limit_top,world.player.camera.limit_right,world.player.camera.limit_bottom]}}
	var derived: Dictionary = {"irrigation_wet":Farm.wet,"irrigation_flow":Farm.flow,"natural_water_sources":Farm.sources,"pollen_flowers":Farm.flowers() if gs.map_id=="village" else 0}
	return {"schema":"bluemap.migration.world-snapshot.v1","scenarioId":scenario.id,"mapId":gs.map_id,"stage":"loaded_projection","units":{"tilePixels":32,"yAxis":"down"},"mapData":wire(world.map_data),"stateBefore":wire(before),"stateAfter":wire(state()),"slots":slots,"terrain":{"width":world.map_size.x,"height":world.map_size.y,"cells":cells,"solidCells":solids},"scene":scene,"environment":wire(environment),"derived":wire(derived),"arrivals":arrivals,"tileSet":wire({"shared":"tile-set.json"}),"projectionCalls":calls}

func write_json(path: String, data: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var text := JSON.stringify(data,"",true,true)+"\n"
	var file := FileAccess.open(path,FileAccess.WRITE)
	require(file != null,"Cannot write export output")
	if file != null:file.store_string(text);file.close()
	return {"path":path.trim_prefix(output_dir+"/"),"sha256":text.sha256_text(),"bytes":text.to_utf8_buffer().size()}

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index] == "--output-dir" and index+1 < arguments.size():output_dir=arguments[index+1].replace("\\","/")
		if arguments[index] == "--scenario" and index+1 < arguments.size():selected=arguments[index+1]
	require(OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"),"Unverified isolated user directory")
	require(output_dir != "","Output directory is required")
	if not failures.is_empty():quit(1);return
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	gs = root.get_node("GameState")
	gs.set_process(false)
	var descriptors: Array = Scenarios.manifest()
	if selected != "":descriptors=descriptors.filter(func(row: Dictionary) -> bool:return row.id==selected)
	require(not descriptors.is_empty(),"No export scenarios selected")
	var records: Array = []
	var shared: Array = []
	for scenario: Dictionary in descriptors:
		for map_id: String in scenario.maps:
			Scenarios.configure(scenario.id)
			gs.map_id=map_id;gs.spawn_name="start";gs.use_load_pos=false
			seed(Scenarios.FIXTURE_SEED+hash(scenario.id+":"+map_id))
			var before := state().duplicate(true)
			world=load("res://scenes/main.tscn").instantiate()
			world.process_mode=Node.PROCESS_MODE_DISABLED
			root.add_child(world)
			current_scene=world
			_freeze(world)
			await process_frame
			_freeze(world)
			var calls: Array = Scenarios.project(world)
			_freeze(world)
			await process_frame
			_freeze(world)
			await process_frame
			_freeze(world)
			if shared.is_empty():shared.append(write_json(output_dir+"/tile-set.json",wire(tile_set_data())))
			var record := write_json(output_dir+"/snapshots/"+scenario.id+"/"+map_id+".json",snapshot(scenario,before,calls))
			record.scenarioId=scenario.id;record.mapId=map_id
			records.append(record)
			print("WORLD SNAPSHOT "+scenario.id+"/"+map_id)
			addresses.clear()
			world.free()
			world=null
			await process_frame
	var ui_list: Array = ui_sources.keys();ui_list.sort()
	var handle_list: Array = handles.keys();handle_list.sort()
	var exporter_sources := {}
	for path: String in ["res://tools/migration_world_export.gd","res://tools/migration_world_scenarios.gd"]:exporter_sources[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	write_json(output_dir+"/index.json",{"schema":"bluemap.migration.world-index.v1","valueEncoding":"bluemap.world.variant.v2","baselineCommit":"a8a988be27835dec979d2523a3a85a34385eac54","baselineTree":"73ba02ea4db0a1c920360b6570f5209ccb970143","exporterSources":exporter_sources,"scenarios":descriptors,"snapshots":records,"shared":shared,"units":{"tilePixels":32,"yAxis":"down"},"scope":"Actual world.load_map plus explicit frozen-clock projections; not a Unity runtime or every combinatorial gameplay state","excludedUiSources":ui_list,"runtimeHandleTypes":handle_list,"failures":failures})
	print("MIGRATION WORLD EXPORT OK" if failures.is_empty() else "MIGRATION WORLD EXPORT FAILED")
	quit(0 if failures.is_empty() else 1)
