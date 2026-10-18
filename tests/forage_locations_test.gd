extends "res://tests/coast_expedition_test.gd"
const Guide:=preload("res://scripts/core/forage_catalog.gd")
const Items:=preload("res://scripts/data/items.gd")
const Resources:=preload("res://scripts/data/ext/beroepen.gd")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 var plants:=0
 var products: Array=preload("res://scripts/data/ext/forest_food_species.gd").SPECIES.values().map(func(spec):return spec.item)
 for item: String in Items.ITEMS:
  if not item.begins_with("flower_") and not item.begins_with("winter_") and item not in products:continue
  plants+=1
  var places:=Guide.locations(item)
  check(not places.is_empty(),"specific collectible has an actual location "+item)
  for place: Dictionary in places:
   var data: Dictionary=Maps.get_map(place.map)
   var objects: Array=data.objects.duplicate();objects.append_array(Resources.resource_objects(place.map))
   check(objects.any(func(o):return o.type=="profession_resource" and o.pos==place.pos and Resources.RESOURCES[o.kind].item==item),"guide coordinates point to actual harvest "+item)
  check(Guide.source(item,"")!="","location hint is visible "+item)
  if places.is_empty():continue
  var first: Dictionary=places[0]
  var label: String=TranslationServer.translate(Maps.MAPS[first.map].DATA.name)
  var expected: String=TranslationServer.translate("%s (%d, %d)") % [label,int(first.pos[0])+1,int(first.pos[1])+1]
  check(Guide.source(item,first.map).begins_with(expected),"displayed gathering coordinates use the same one-based grid as quest routes "+item)
  check(Guide.locations(item)==places,"display formatting preserves zero-based source geometry "+item)
 check(plants==64,"all sixteen vegetables, flowers, fruit and nuts have precise sources")
 check(Guide.locations("ruin_key").is_empty(),"guide never invents a plant location for key items")
 var copy:=Guide.locations("prof_herb");copy.clear();check(not Guide.locations("prof_herb").is_empty(),"callers cannot corrupt source catalogue")
 print("FORAGE LOCATIONS OK" if failures==0 else "FORAGE LOCATIONS FAILED "+str(failures));quit(0 if failures==0 else 1)
