extends Node2D
## Zichtbare wereldgevolgen zonder kaartreload: collisions, minimap en geluid blijven gelijklopen.
const Tiles := preload("res://scripts/data/tiles.gd")
const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const ResourceNode := preload("res://scripts/entities/resource_node.gd")
const Fishing := preload("res://scripts/entities/meer_visplek.gd")
const Resident := preload("res://scripts/entities/living_resident.gd")
var world: Node2D
var signature := ""
var time := 0.0
var addons: Array[Node2D] = []
var fog := 1.0
var terrain_changed := false

func state_signature() -> String:
	return str([GameState.flag("lw_mine"), GameState.flag("lw_forest"), GameState.flag("lw_heat_west"), GameState.flag("lw_heat_east"), GameState.flag("lw_drained"), GameState.flag("lw_bridge")])

func _process(delta: float) -> void:
	time += delta
	if signature != state_signature(): refresh()
	fog = move_toward(fog, 0.0 if GameState.flag("lw_forest") else 1.0, delta * 0.3)
	queue_redraw()

func tile(x: int, y: int, symbol: String) -> void:
	terrain_changed = true
	var row: String = world.map_data["rows"][y]
	world.map_data["rows"][y] = row.substr(0,x) + symbol + row.substr(x+1)
	var cell := Vector2i(x,y)
	var name := Tiles.name_for(symbol,x,y)
	world.tile_layer.set_cell(cell,0,preload("res://scripts/core/pixel_landscape.gd").atlas(name,x,y))
	if Tiles.is_solid_name(name): world.solid_cells[cell] = true
	else: world.solid_cells.erase(cell)

func resource(kind: String, id: String, at: Vector2i) -> void:
	var node := ResourceNode.new()
	node.world = world
	node.obj = {"type":"profession_resource", "kind":kind,"id":id}
	node.key = id
	node.position = Vector2(at)*32+Vector2(16,16)
	world.entities.add_child(node)
	addons.append(node)

func resident(sheet: String, at: Vector2) -> void:
	var node := Resident.new()
	node.sheet = sheet
	node.position = at * 32
	world.entities.add_child(node)
	addons.append(node)

func refresh() -> void:
	terrain_changed = false
	signature = state_signature()
	for node in addons:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	addons.clear()
	match GameState.map_id:
		"prismamine":
			if GameState.flag("lw_mine"):
				resource("iron","lw_mine_iron",Vector2i(27,5))
				resource("copper","lw_mine_copper",Vector2i(34,9))
		"kruipmoeras":
			var changes:=preload("res://scripts/core/marsh_waterworks.gd").changes(world.map_data.rows,GameState.flag("lw_drained"),GameState.flag("lw_bridge"))
			for cell: Vector2i in changes:tile(cell.x,cell.y,changes[cell])
			if GameState.flag("lw_drained"):
				resource("watermunt","lw_shore_mint",Vector2i(30,17))
				var spot := Fishing.new()
				spot.world = world
				spot.obj = {"type":"meer_visplek"}
				spot.key = "lw_marsh_fishing"
				spot.position = Vector2(29.5,15.5)*32
				world.entities.add_child(spot)
				addons.append(spot)
		"dauwbos":
			if GameState.flag("lw_forest"):
				resource("dauwklauw","lw_revealed_flower",Vector2i(39,32))
				for y in [30,31]:
					for x in range(39,45):tile(x,y,",")
		"ijsdal":
			if GameState.flag("lw_heat_west"):
				for y in [12,13]:
					for x in range(10,16):tile(x,y,",")
			if GameState.flag("lw_heat_east"):
				for y in range(3,16):
					for x in [40,41]:tile(x,y,",")
				for y in [3,4]:
					for x in range(40,45):tile(x,y,",")
				for y in [14,15]:
					for x in range(34,42):tile(x,y,",")
	if terrain_changed:
		preload("res://scripts/core/water_features.gd").describe(GameState.map_id,world.map_data)
		if is_instance_valid(world.landscape):world.landscape.refresh()

func _draw() -> void:
	match GameState.map_id:
		"dauwbos":
			if fog > 0:
				for i in 14:
					var at := Vector2(6+(i*11)%38,7+(i*7)%24)*32
					at += Vector2(sin(time*0.15+i)*22,cos(time*0.11+i)*10)
					DrawUtil.ellipse(self,at,Vector2(110,30),Color(0.6,0.8,0.8,0.075*fog))
			if GameState.flag("lw_forest"):
				for i in 12:
					var at := Vector2(38+(i%5),28+(i%3))*32+Vector2(16,16)
					draw_circle(at+Vector2(sin(time+i)*4,-12),2,Color(0.8,1,0.6,0.65))
		"ijsdal":
			for entry in [["lw_heat_west",12,"npc_fenna"],["lw_heat_east",36,"npc_roos"]]:
				if GameState.flag(entry[0]):
					var windows: Array = [9.0,12.0] if entry[0] == "lw_heat_west" else [35.0,38.0]
					for x in windows:
						for pane in [Rect2(8,8,6,6), Rect2(16,8,8,6), Rect2(8,16,6,8), Rect2(16,16,8,8)]:
							draw_rect(Rect2(Vector2(x,9)*32 + pane.position, pane.size),Color(1,0.7,0.3,0.75))
		"kruipmoeras":
			if GameState.flag("lw_drained"):
				for i in 5:
					var at := Vector2(28+i,15.7)*32
					draw_line(at+Vector2(sin(time+i)*3,0),at+Vector2(16,0),Color(0.5,0.8,0.85,0.6),1)
