extends SceneTree
## Read-only reference inventory; run only through record_migration_inventory.py.
## Registry snapshots deliberately do NOT claim world.load_map/runtime-state parity.
var failures: Array[String]=[]
var declarations: Array=[]
var source_files: Array=[]
var catalogs: Dictionary={}
var production_scripts: Array[String]=[]
var output_dir:=""
var content: Script
var maps: Script
var tiles: Script
var professions: Script
var source_cache: Dictionary={}

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func script(path: String) -> Script:
	return load(path) as Script

func files_under(directory: String) -> Array[String]:
	var result: Array[String]=[]
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):result.append(directory.path_join(name))
	for name in DirAccess.get_directories_at(directory):result.append_array(files_under(directory.path_join(name)))
	result.sort()
	return result

func source(path: String) -> String:
	if not source_cache.has(path):source_cache[path]=FileAccess.get_file_as_string(path)
	return source_cache[path]

func location(path: String,constant: String) -> Dictionary:
	var lines: PackedStringArray=source(path).split("\n")
	var pattern:=RegEx.new()
	pattern.compile("^const[ \\t]+"+constant+"\\b")
	for i in lines.size():
		if pattern.search(lines[i])!=null:return {"path":path,"constant":constant,"line":i+1}
	return {}

func encoded(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING,TYPE_STRING_NAME:return value
		TYPE_FLOAT:
			require(is_finite(value),"Non-finite catalog number")
			return value
		TYPE_ARRAY:
			var result: Array=[]
			for item in value:result.append(encoded(item))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary={}
			for key in value:
				if not (key is String or key is StringName):
					var pairs: Array=[]
					for other in value:pairs.append([encoded(other),encoded(value[other])])
					return {"$type":"Dictionary","entries":pairs}
			for key in value:result[str(key)]=encoded(value[key])
			return result
		TYPE_VECTOR2,TYPE_VECTOR2I:return {"$type":type_string(typeof(value)),"value":[value.x,value.y]}
		TYPE_VECTOR3,TYPE_VECTOR3I:return {"$type":type_string(typeof(value)),"value":[value.x,value.y,value.z]}
		TYPE_VECTOR4,TYPE_VECTOR4I:return {"$type":type_string(typeof(value)),"value":[value.x,value.y,value.z,value.w]}
		TYPE_RECT2,TYPE_RECT2I:return {"$type":type_string(typeof(value)),"position":encoded(value.position),"size":encoded(value.size)}
		TYPE_COLOR:return {"$type":"Color","rgba":[value.r,value.g,value.b,value.a]}
		TYPE_TRANSFORM2D:return {"$type":"Transform2D","x":encoded(value.x),"y":encoded(value.y),"origin":encoded(value.origin)}
		TYPE_OBJECT:
			if value is Resource:return {"$type":value.get_class(),"path":value.resource_path}
		TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY,TYPE_PACKED_STRING_ARRAY,TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_COLOR_ARRAY,TYPE_PACKED_VECTOR4_ARRAY:
			var result: Array=[]
			for item in value:result.append(encoded(item))
			return {"$type":type_string(typeof(value)),"values":result}
	require(false,"Unsupported catalog type: "+type_string(typeof(value)))
	return null

func collect_declarations() -> void:
	production_scripts=files_under("res://scripts")
	for path: String in production_scripts:
		var loaded:=script(path)
		require(loaded!=null,"Cannot inspect "+path)
		if loaded==null:continue
		source_files.append({"path":path,"sha256":source(path).replace("\r\n","\n").sha256_text()})
		var constants: Dictionary=loaded.get_script_constant_map()
		var names: Array[String]=[]
		for key in constants:names.append(str(key))
		names.sort()
		for name: String in names:
			var value: Variant=constants[name]
			if not (value is Dictionary or value is Array or typeof(value)>=TYPE_PACKED_BYTE_ARRAY):continue
			var at:=location(path,name)
			if at.is_empty():continue # inherited constants belong to their actual declaring script
			var ids: Array=[]
			if value is Dictionary:
				for id in value:ids.append(encoded(id))
			else:
				for i in value.size():ids.append({"index":i,"value":encoded(value[i])})
			declarations.append({"source":at,"kind":"dictionary" if value is Dictionary else "ordered_array","ids":ids,"value":encoded(value)})

func origins(id: Variant,names: Array,only_paths: Array=[]) -> Array:
	var result: Array=[]
	for declaration: Dictionary in declarations:
		var at: Dictionary=declaration.source
		if at.constant not in names:continue
		if not only_paths.is_empty() and at.path not in only_paths:continue
		if declaration.kind=="dictionary":
			if id not in declaration.ids:continue
		else:
			var found:=false
			for entry: Dictionary in declaration.ids:
				if entry.value==id:found=true;break
			if not found:continue
		var ref: Dictionary=at.duplicate()
		ref["role"]="override" if "OVERRIDES" in at.constant else "definition_or_reference"
		result.append(ref)
	return result

func catalog(name: String,values: Dictionary,names: Array,only_paths: Array=[]) -> void:
	var entries: Array=[]
	var ids: Array=values.keys();ids.sort()
	for id: String in ids:
		var refs:=origins(id,names,only_paths)
		require(not refs.is_empty(),"No source for "+name+":"+id)
		entries.append({"id":id,"sources":refs,"value":encoded(values[id])})
	catalogs[name]={"count":entries.size(),"entries":entries}

func sequence_catalog(name: String,values: Array,names: Array,only_paths: Array=[]) -> void:
	var values_by_id: Dictionary={}
	for id: String in values:values_by_id[id]={"source_index":values.find(id)}
	catalog(name,values_by_id,names,only_paths)

func function_text(path: String,function: String) -> String:
	var text:=source(path)
	var start:=text.find("func "+function+"(")
	if start<0:start=text.find("static func "+function+"(")
	if start<0:return ""
	var end:=text.find("\nfunc ",start+5)
	var static_end:=text.find("\nstatic func ",start+5)
	if end<0 or (static_end>=0 and static_end<end):end=static_end
	return text.substr(start) if end<0 else text.substr(start,end-start)

func match_ids(path: String,function: String) -> Dictionary:
	var ids: Dictionary={}
	var quoted:=RegEx.new();quoted.compile('"([^"\\n]+)"')
	var case_indent:=-1
	for line: String in function_text(path,function).split("\n"):
		var trimmed:=line.strip_edges()
		if trimmed.begins_with("match "):case_indent=line.find("match ")+1
		if case_indent<0 or line.length()-line.lstrip("\t ").length()!=case_indent:continue
		if not trimmed.begins_with('"') or not trimmed.ends_with(":"):continue
		for found: RegExMatch in quoted.search_all(line):ids[found.get_string(1)]={"path":path,"function":function}
	return ids

func enum_catalog(name: String,base: Dictionary,extension_name: String) -> void:
	var all_ids:=base.duplicate(true)
	for id: String in content.appended(extension_name,[]):all_ids[id]={}
	var entries: Array=[]
	var names: Array=all_ids.keys();names.sort()
	for id: String in names:
		var refs:=origins(id,[extension_name])
		if base.has(id):refs.push_front(base[id])
		require(not refs.is_empty(),"No source for "+name+":"+id)
		entries.append({"id":id,"sources":refs})
	catalogs[name]={"count":entries.size(),"entries":entries}

func collect_catalogs() -> void:
	for spec: Array in [["items","items","ITEMS"],["weapons","items","WEAPONS"],["quests","quests","QUESTS"],["talks","dialogue","TALKS"],["enemies","enemies","ENEMIES"],["npcs","npcs","NPCS"],["shops","shops","SHOPS"],["achievements","achievements","ACHIEVEMENTS"]]:
		var loaded:=script("res://scripts/data/"+spec[1]+".gd")
		catalog(spec[0],loaded.get(spec[2]),["BASE_"+spec[2],spec[2],"ITEM_OVERRIDES"] if spec[2]=="ITEMS" else ["BASE_"+spec[2],spec[2]])
	var jobs:=script("res://scripts/data/ext/beroepen.gd")
	catalog("recipes",jobs.RECIPES,["RECIPES"])
	catalog("professions",jobs.SKILLS,["SKILLS"])
	catalog("resources",jobs.RESOURCES,["BASE_RESOURCES","RESOURCES","RESOURCE_OVERRIDES"])
	var gear_path:="res://scripts/data/ext/uitrusting.gd";var gear:=script(gear_path)
	catalog("gear",gear.ITEMS,["ITEMS"],[gear_path]);catalog("gear_slots",gear.SLOTS,["SLOTS"],[gear_path])
	var look_path:="res://scripts/data/ext/uiterlijk.gd";var look:=script(look_path)
	for spec: Array in [["clothes","ITEMS"],["clothing_slots","CLOTHING_SLOTS"],["hair_m","HAIR_M"],["hair_v","HAIR_V"],["eye_styles","EYES"],["genders","GENDERS"]]:catalog(spec[0],look.get(spec[1]),[spec[1]],[look_path])
	for name: String in ["HAIR_COLORS","EYE_COLORS","DYE_COLORS"]:
		var rows: Array=look.get(name);var entries: Array=[]
		for i in rows.size():entries.append({"id":str(i),"source_index":i,"sources":[location(look_path,name)],"value":encoded(rows[i])})
		catalogs[name.to_lower()]={"count":entries.size(),"identity":"ordered_palette_index","entries":entries}
	sequence_catalog("consumables",professions.CONSUMABLES,["BASE_CONSUMABLES","ITEMS","ITEM_OVERRIDES"])
	catalog("map_markers",content.map_markers(),["MAP_MARKERS"])
	catalog("maps",maps.MAPS,["BASE_MAPS","MAPS"])
	sequence_catalog("tile_types",tiles.NAMES,["NAMES"],["res://scripts/data/tiles.gd"])
	sequence_catalog("solid_tile_types",tiles.SOLID,["SOLID"],["res://scripts/data/tiles.gd"])
	var sounds: Node=root.get_node("Sound")
	sequence_catalog("sounds",sounds.SOUNDS,["BASE_SOUNDS","SOUNDS"])
	sequence_catalog("music_tracks",sounds.TRACKS,["BASE_TRACKS","TRACKS"])
	var specials:=match_ids("res://scripts/entities/pickup.gd","_collect")
	var special_rows: Array=[]
	for id: String in specials:special_rows.append({"id":id,"sources":[specials[id]]})
	catalogs["special_pickups"]={"count":special_rows.size(),"entries":special_rows}
	var builtins:=match_ids("res://scripts/world.gd","_spawn_objects")
	var extra: Dictionary=content.merged("OBJECTS",{})
	var entries: Array=[];var all_types: Array=builtins.keys()
	for id: String in extra:
		if id not in all_types:all_types.append(id)
	all_types.sort()
	for id: String in all_types:
		var refs:=origins(id,["OBJECTS"])
		if builtins.has(id):refs.push_front(builtins[id])
		entries.append({"id":id,"sources":refs,"extension_script":extra.get(id,"")})
	catalogs["object_types"]={"count":entries.size(),"entries":entries}
	enum_catalog("conditions",match_ids("res://scripts/core/game_state.gd","check"),"CONDITIONS")
	enum_catalog("actions",match_ids("res://scripts/core/game_state.gd","run"),"ACTIONS")
	var formats: Dictionary={};var tokens:=RegEx.new();tokens.compile('\\{([a-z_]+)\\}')
	for found: RegExMatch in tokens.search_all(function_text("res://scripts/core/game_state.gd","fmt")):formats[found.get_string(1)]={"path":"res://scripts/core/game_state.gd","function":"fmt"}
	enum_catalog("formats",formats,"FORMATS")

func map_inventory() -> Dictionary:
	var result: Array=[];var total_tiles:=0;var total_slots:=0;var total_legacy:=0
	var ids: Array=maps.MAPS.keys();ids.sort()
	var snapshots: Dictionary={}
	for id: String in ids:snapshots[id]=maps.get_map(id)
	for id: String in ids:
		var data: Dictionary=snapshots[id]
		var again: Dictionary=maps.get_map(id)
		require(JSON.stringify(encoded(data),"",true,true)==JSON.stringify(encoded(again),"",true,true),"Registry snapshot is not deterministic: "+id)
		var rows: Array=data.rows;var width: int=rows[0].length();var terrain: Dictionary={}
		for y in rows.size():
			require(rows[y].length()==width,"Non-rectangular map: "+id)
			for x in width:
				var name: String=tiles.name_for(rows[y][x],x,y)
				require(name in tiles.NAMES,"Unknown tile in "+id)
				terrain[name]=int(terrain.get(name,0))+1
		var slots: Array=[]
		for index in data.objects.size():
			var obj: Dictionary=data.objects[index]
			var kind: String=obj.get("type","")
			require(kind!="","Missing object type in "+id)
			slots.append({"index":index,"type":kind,"enabled":obj.get("enabled",true),"authored_id":obj.get("id",null),"legacy_slot_key":"%s:%s:%d"%[kind,id,index],"save_key_note":"slot formula from world._spawn_objects; actual persistence depends on object handler","source":{"path":"res://scripts/maps/registry.gd","function":"get_map","object_index":index,"base_map":maps.MAPS[id].resource_path},"composition_source":"res://scripts/maps/registry.gd:get_map"})
		var legacy: Array=[]
		for obj: Dictionary in script("res://scripts/data/ext/beroepen.gd").resource_objects(id):
			script("res://scripts/data/forest_food_species.gd").decorate(id,obj)
			legacy.append({"id":obj.id,"source":{"path":"res://scripts/data/ext/beroepen.gd","constant":"RESOURCE_PLACEMENTS","map":id},"value":encoded(obj)})
		var portals: Array=[]
		for index in data.objects.size():
			var obj: Dictionary=data.objects[index]
			if obj.type!="portal":continue
			require(maps.MAPS.has(obj.to),"Unknown portal target: "+id+" -> "+str(obj.to))
			var destination: Dictionary=snapshots.get(obj.to,{"spawns":{}})
			require(destination.spawns.has(obj.get("spawn","start")),"Unknown destination spawn from "+id)
			portals.append({"slot":index,"to":obj.to,"spawn":obj.get("spawn","start"),"pos":obj.pos,"size":obj.get("size",[1,1]),"requires":encoded(obj.get("requires",[])),"enabled":obj.get("enabled",true)})
		total_tiles+=width*rows.size();total_slots+=slots.size();total_legacy+=legacy.size()
		result.append({"id":id,"name":data.name,"width":width,"height":rows.size(),"tile_count":width*rows.size(),"base_source":maps.MAPS[id].resource_path,"registry_snapshot":encoded(data),"terrain_counts":terrain,"object_slots":slots,"portal_edges":portals,"post_registry_legacy_resources":legacy})
	return {"schema":"bluemap.migration.maps-inventory.v1","scope":"registry_get_map_baseline_only","not_phase5_runtime_export":true,"limitations":["Registry composition only: not a running world.load_map export.","Legacy profession nodes are recorded separately because world.load_map appends them after registry composition.","Slot keys are registry-index keys; preserve slots and verify their final runtime indices during phase5.","Quest flags, getijden, dynamically spawned actors, collision state and later landscape/home changes are not exhaustively simulated."],"map_count":result.size(),"tile_count":total_tiles,"registry_object_slots":total_slots,"legacy_resource_count":total_legacy,"maps":result}

func save(name: String,value: Dictionary) -> void:
	var file:=FileAccess.open(output_dir.path_join(name),FileAccess.WRITE)
	require(file!=null,"Cannot write inventory "+name)
	if file!=null:file.store_string(JSON.stringify(value,"\t",true,true)+"\n")

func _run() -> void:
	require(OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"),"Inventory must run in a verified UUID copy")
	var args:=OS.get_cmdline_user_args()
	if args.size()==2 and args[0]=="--output-dir":output_dir=args[1]
	require(output_dir.is_absolute_path(),"Expected absolute --output-dir")
	if not failures.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var gs: Node=root.get_node("GameState");gs.new_game();gs.in_game=false;gs.set_process(false)
	content=script("res://scripts/data/content.gd");maps=script("res://scripts/maps/registry.gd");tiles=script("res://scripts/data/tiles.gd");professions=script("res://scripts/core/professions.gd")
	collect_declarations();collect_catalogs()
	var module_rows: Array=[]
	for i in content.MODULES.size():module_rows.append({"index":i,"path":content.MODULES[i].resource_path})
	var map_rows:=map_inventory()
	var result: Dictionary={"schema":"bluemap.migration.content-inventory.v1","scope":"read_only_effective_catalogs_and_declared_constant_tables","baseline_state":"new_game, in_game=false, no loaded gameplay scene","source_version":ProjectSettings.get_setting("application/config/version"),"source_file_hash_mode":"UTF-8 source text with CRLF normalized to LF","source_files":source_files,"modules":module_rows,"catalogs":catalogs,"declarations":declarations,"failures":failures}
	save("content-inventory.json",result);save("maps-inventory.json",map_rows)
	print("INVENTORY_COUNTS="+JSON.stringify({"catalogs":catalogs.size(),"declarations":declarations.size(),"maps":map_rows.map_count,"tiles":map_rows.tile_count,"slots":map_rows.registry_object_slots,"legacy_resources":map_rows.legacy_resource_count}))
	if failures.is_empty():print("MIGRATION INVENTORY OK")
	quit(0 if failures.is_empty() else 1)
