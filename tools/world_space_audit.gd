extends SceneTree
## Read-only layout audit. Run in an isolated test copy; pressure is an upper
## bound based on initial positions, not a simulation of enemies or line of sight.
const Maps := preload("res://scripts/maps/registry.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
var Route: Script
func _initialize(): run.call_deferred()
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"): quit(1); return
	Route=load("res://scripts/entities/first_route.gd")
	var report: Dictionary={}
	for id: String in Maps.MAPS:
		var data:=Maps.get_map(id)
		Route.prepare(data,id)
		data.objects.append_array(load("res://scripts/data/ext/beroepen.gd").resource_objects(id))
		var floor_count:=0
		var types: Dictionary={}
		for row: String in data.rows:
			for ch in row:
				if not Tiles.is_solid_name(Tiles.CHARS.get(ch,"grass")):floor_count+=1
		for obj: Dictionary in data.objects:
			if not obj.get("enabled",true):continue
			types[obj.type]=int(types.get(obj.type,0))+1
		var entry: Dictionary={"size":[data.rows[0].length(),data.rows.size()],"walkable_tiles":floor_count,"objects":types}
		if id=="forest":
			entry["road_pressure"]={}
			for stretch in [[4,15],[16,27],[28,39],[40,48]]:
				var exposed:=0
				for x in range(stretch[0],stretch[1]+1):
					for obj: Dictionary in data.objects:
						if obj.type=="enemy" and not obj.get("trail_wildlife",false) and obj.get("enabled",true) and Vector2(obj.pos[0]-x,obj.pos[1]-17).length()*32<=140:
							exposed+=1;break
				entry.road_pressure[str(stretch)]={"samples":stretch[1]-stretch[0]+1,"near_hostile":exposed}
		report[id]=entry
	var out:=FileAccess.open("res://world_space_audit.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"));out.close()
	print("WORLD SPACE AUDIT OK");quit()
