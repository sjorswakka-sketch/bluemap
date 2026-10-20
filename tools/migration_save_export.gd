extends SceneTree
## Source save methods are executed only under the UUID-isolating recorder.
const Atlas=preload("res://scripts/core/world_atlas.gd")
const Gear=preload("res://scripts/data/ext/uitrusting.gd")
const Looks=preload("res://scripts/data/ext/uiterlijk.gd")
const Home=preload("res://scripts/core/personal_home.gd")
const Yard=preload("res://scripts/core/yard.gd")
const YardData=preload("res://scripts/data/yard_catalog.gd")
const House=preload("res://scripts/data/house_catalog.gd")
const Farm=preload("res://scripts/core/homestead.gd")
const Crop=preload("res://scripts/data/orchard_catalog.gd")
const Jobs=preload("res://scripts/data/ext/beroepen.gd")
const Maps=preload("res://scripts/maps/registry.gd")
const Items=preload("res://scripts/data/items.gd")
func _initialize(): _run.call_deferred()
func _plain(v:Variant)->Variant:
 if v is Vector2 or v is Vector2i:return [v.x,v.y]
 if v is Rect2i:return [v.position.x,v.position.y,v.size.x,v.size.y]
 if v is Dictionary:
  var d:Dictionary={}
  for k:Variant in v:d[str(k)]=_plain(v[k])
  return d
 if v is Array:
  var a:Array=[]
  for x:Variant in v:a.append(_plain(x))
  return a
 return v
func _exact(v:Variant)->Variant:
 if v is float:return {"$f64":PackedFloat64Array([v]).to_byte_array().hex_encode()}
 if v is Dictionary:
  var d:Dictionary={}
  for k:Variant in v:d[str(k)]=_exact(v[k])
  return d
 if v is Array:
  var a:Array=[]
  for x:Variant in v:a.append(_exact(x))
  return a
 return v
func _snapshot(gs:Node)->Dictionary:
 var d:Dictionary={"version":1,"map":gs.map_id,"pos":[gs.load_pos.x,gs.load_pos.y]}
 for k:String in ["hp","coins","inventory","flags","quests","weapon","visited_maps","play_time","kills","meer","day_time","day_count","kills_by","rolls","potions_drunk","deaths","boss_deaths","arena_records","homestead","coastal_storage","stockroom","personal_home","yard","professions","hero_xp","equipment","appearance","clothing","ng_plus"]:d[k]=gs.get(k)
 d.talked=gs.talked.keys();d.achievements=gs.achievements.keys()
 return d
func _run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe save export");quit(1);return
 var gs:=root.get_node("GameState");gs.set_process(false);gs.meta_achievements={};gs.new_game()
 Atlas._legacy_inventory()
 var limits:Dictionary={}
 for id:String in Jobs.RESOURCE_PLACEMENTS:
  for o:Dictionary in Jobs.resource_objects(id):limits[o.id]=float(Jobs.RESOURCES[o.kind].cooldown)
 for id:String in Maps.MAPS:
  for o:Dictionary in Maps.get_map(id).objects:
   if o.type=="profession_resource" and Jobs.RESOURCES.has(o.get("kind","")):
    var key:String=str(o.get("id",""))
    if key.begins_with("trail:") or key.begins_with("winter:") or key.begins_with("forestfood:"):limits[key]=float(Jobs.RESOURCES[o.kind].cooldown)
 var solid:Array=[]
 var tiles:=preload("res://scripts/data/tiles.gd")
 for c:String in tiles.CHARS:
  if tiles.is_solid_name(tiles.CHARS[c]):solid.append(c)
 var fixed:Array=[]
 for c:Vector2i in Yard.fixed():fixed.append([c.x,c.y])
 var base:Array=[]
 for c:Vector2i in Yard.reachable(Yard.defaults()):base.append([c.x,c.y])
 var rules:Dictionary={"items":Items.ITEMS,"weapons":Items.WEAPONS,"gear":Gear.ITEMS,"gearSlots":Gear.SLOTS,"clothing":Looks.ITEMS,"clothingSlots":Looks.CLOTHING_SLOTS,"hairM":Looks.HAIR_M.keys(),"hairV":Looks.HAIR_V.keys(),"hairColorCount":Looks.HAIR_COLORS.size(),"eyes":Looks.EYES.keys(),"eyeColorCount":Looks.EYE_COLORS.size(),"dyeColorCount":Looks.DYE_COLORS.size(),"crops":Crop.CROPS,"farmJobs":Farm.JOBS,"homeDefaults":Home.defaults(),"homePieces":House.PIECES,"yardDefaults":Yard.defaults(),"yardUnits":YardData.UNITS,"yardPieces":YardData.PIECES,"yardSupplies":YardData.SUPPLIES,"yardPlots":YardData.BASE_PLOTS,"yardExtensions":YardData.EXTENSIONS,"yardRows":Maps.get_map("village").rows,"yardFixed":fixed,"yardBaseReach":base,"solidChars":solid,"skills":Jobs.SKILLS.keys(),"recipes":Jobs.RECIPES.keys(),"resourceLimits":limits,"maps":Maps.MAPS.keys(),"atlasEvidence":Atlas._evidence,"atlasNpcs":Atlas._unique_npcs,"atlasBattles":Atlas.LEGACY_BATTLES,"atlasPlaces":preload("res://scripts/core/world_memory.gd").PLACES}
 var fixtures:Array=[
  {"id":"empty_old_save","data":{}},
  {"id":"legacy_flags_presence","data":{"map":"village","flags":{"golem_ruins":false,"golem_cave":0,"boss_defeated":"","cat_found":false,"chest:forest:0":true},"hp":0}},
  {"id":"explicit_visits_no_inference","data":{"map":"lake","visited_maps":{"forest":true,"cave":false,"unknown":true,"ruins":1},"flags":{"golem_ruins":true}}},
  {"id":"negative_day_and_fractionals","data":{"map":"forest","pos":[-15.125,123.0625],"coins":17.99,"hp":99,"inventory":{"heart_container":3},"day_time":-2.25,"play_time":1234.125,"hero_xp":99999,"kills":4.99,"ng_plus":3}},
  {"id":"unknown_future_fields","data":{"version":999,"future":{"kind":"my_mod","item":[1,2.5,null]},"map":"village","inventory":{"future_item":7,"prof_log":2},"quests":{"future_quest":{"state":"active","step":2.9,"extra":"retain"}},"homestead":{"future":"retain"}}},
  {"id":"nested_invalid_types","data":{"professions":null,"homestead":[],"stockroom":"bad","yard":false,"personal_home":12,"coastal_storage":[],"equipment":[],"appearance":[],"clothing":[]}},
  {"id":"farms_and_production","data":{"play_time":1000,"homestead":{"cells":{"4,29":{"kind":"soil","crop":"apple","established":true,"growth":999,"fertilized":true},"5,29":{"kind":"channel"},"20,30":{"kind":"soil"},"6,30":{"kind":"soil","crop":"unknown"}},"jobs":{"compost":{"batches":99,"time":40},"wine_a":{"batches":0,"time":-1}},"animal_due":{"deer":99999},"drops":{"drop":{"map":"forest","pos":[123,90000]}},"wild_due":99999,"honey":999,"honey_time":200}}},
  {"id":"house_invalid_overlap","data":{"personal_home":{"floor":9,"wall":-3,"light":1,"owned":{"chair":99},"layout":{"bed":{"kind":"bed","cell":[3,3]},"table":{"kind":"table","cell":[3,3]},"shelf":{"kind":"shelf","cell":[8,2]}}}}},
  {"id":"yard_invalid_crop_overlap","data":{"homestead":{"cells":{"5,29":{"kind":"soil","crop":"grape","growth":30}}},"yard":{"extensions":["west","east","west","bogus"],"owned":{"gravel":9999},"stations":{"wine_a":[5,29]},"paths":{"5,29":"gravel","04,30":"stone","6,30":"gravel"},"fences":{"5,30":"fence_h"}}}},
  {"id":"records_talk_and_stats","data":{"meer":{"fish":3.9},"arena_records":{"bronze":95.2},"talked":["muis_bos","muis_bos"],"achievements":["future_achievement"],"rolls":5.9,"deaths":2,"day_time":3.75,"kills_by":{"bat":4.9}}},
 ]
 var gear_ids:Array=Gear.ITEMS.keys();var cloth_ids:Array=Looks.ITEMS.keys()
 var gear_inv:Dictionary={gear_ids[0]:4,gear_ids[1]:0.5,cloth_ids[0]:2,"prof_log":99,"future_item":7}
 var gear_equipped:Dictionary={Gear.ITEMS[gear_ids[0]].slot:gear_ids[0]}
 fixtures.append({"id":"gear_clothing_appearance","data":{"inventory":gear_inv,"equipment":gear_equipped,"appearance":{"gender":"v","hair":"unknown","hair_color":999,"eyes":"unknown","eye_color":-5},"clothing":{Looks.ITEMS[cloth_ids[0]].slot:{"item":cloth_ids[0],"dye":999}}}})
 var cool:Dictionary={};var n:=0
 for id:String in limits:
  cool[id]=99999;n+=1
  if n==4:break
 cool["trail:forest:invented"]=99999
 fixtures.append({"id":"profession_cooldowns","data":{"play_time":200,"professions":{"xp":{Jobs.SKILLS.keys()[0]:99999,Jobs.SKILLS.keys()[1]:-3},"goal":Jobs.RECIPES.keys()[0],"cooldowns":cool}}})
 var stores:Dictionary={};var mat:=""
 for id:String in Items.ITEMS:
  if Items.ITEMS[id].get("type","")=="material":stores[id]=1500;mat=id
  if stores.size()>=15:break
 fixtures.append({"id":"bounded_storage","data":{"stockroom":{"home":stores,"favorites":{mat:true,"unknown":true},"sort":9},"coastal_storage":stores}})
 fixtures.append({"id":"current_full_roundtrip","data":_snapshot(gs)})
 var custom:Dictionary=Home.defaults().layout.duplicate(true)
 custom.bed.cell=[3,2];custom.table.cell=[3,8]
 custom["chair:1"]={"kind":"chair","cell":[3,6],"tint":2}
 fixtures.append({"id":"house_valid_custom","data":{"personal_home":{"layout":custom,"floor":2,"wall":1,"light":2}}})
 var bogus:Dictionary=custom.duplicate(true);bogus["chair: 1"]=bogus["chair:1"];bogus.erase("chair:1")
 fixtures.append({"id":"house_invalid_identifier","data":{"personal_home":{"layout":bogus}}})
 fixtures.append({"id":"yard_valid_paths","data":{"yard":{"paths":{"4,27":"gravel","5,27":"gravel","10,26":"gravel"},"fences":{"4,28":"gate_h"}}}})
 fixtures.append({"id":"yard_all_stations_stored","data":{"yard":{"stations":{"wine_a":[],"wine_b":[],"compost":[],"hive":[]},"extensions":["west"],"paths":{"7,30":"gravel","8,30":"gravel"}}}})
 fixtures.append({"id":"raw_version_object","data":{"version":{"future":true,"kind":"mod_version"},"flags":{"new_unknown":false}}})
 fixtures.append({"id":"numeric_conversion","data":{"coins":"19 crates","kills":"12.7","rolls":true,"hp":"4","ng_plus":"2"}})
 fixtures.append({"id":"exact_day_boundary","data":{"day_time":-2.0,"pos":[-0.0,123.123456789],"play_time":0.123456789012345,"hero_xp":2250.9}})
 fixtures.append({"id":"malformed_nested_values","data":{"hero_xp":"777","appearance":{"hair_color":"4 styles","eye_color":true},"homestead":{"cells":{"05,29":{"kind":"soil","crop":"mint","established":true,"growth":65.3},"garbage":{"kind":"channel"}},"animal_due":{"future":"ignored"},"jobs":{"wine_b":{"batches":"bad","time":null}}},"personal_home":{"owned":null},"professions":{"xp":[],"cooldowns":[]},"stockroom":{"sort":"bad","favorites":{"prof_log":false}}}})
 fixtures.append({"id":"json_integer_precision_positive","inputJson":'{"map":"forest","coins":9007199254740993,"inventory":{"future_stack":9007199254740993},"quests":{"future_quest":{"state":"active","step":9007199254740993}},"pos":[16777217,-0],"ng_plus":9007199254740993,"kills":9007199254740993}'})
 fixtures.append({"id":"json_integer_precision_negative","inputJson":'{"coins":-9007199254740993,"inventory":{"future_stack":-9007199254740993},"quests":{"future_quest":{"state":"active","step":-9007199254740993}},"pos":[-16777217,-0.0],"day_time":-9007199254740993,"rolls":-9007199254740993}'})
 var cases:Array=[]
 for fixture:Dictionary in fixtures:
  gs.meta_achievements={}
  var json:String=fixture.inputJson if fixture.has("inputJson") else JSON.stringify(fixture.data)
  var f:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE);f.store_string(json);f.close()
  var ok:bool=gs.load_game()
  if not ok:push_error("Source fixture rejected: "+fixture.id);quit(1);return
  cases.append({"id":fixture.id,"inputJson":json,"expected":_exact(_snapshot(gs)),"useLoadPosition":gs.use_load_pos})
 var corrupt:Array=[]
 for text:String in ["", "[]", "null", "42", "{oops", "{\"map\":"]:
  var f:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE);f.store_string(text);f.close()
  corrupt.append({"inputJson":text,"accepted":gs.load_game()})
 var hashes:Dictionary={}
 for p:String in ["scripts/core/game_state.gd","scripts/core/world_atlas.gd","scripts/core/equipment.gd","scripts/core/appearance.gd","scripts/core/professions.gd","scripts/core/homestead.gd","scripts/core/coastal_home.gd","scripts/core/stockroom.gd","scripts/core/personal_home.gd","scripts/core/yard.gd","scripts/core/progression.gd"]:
  hashes[p]=FileAccess.get_file_as_string("res://"+p).replace("\r\n","\n").sha256_text()
 var result:Dictionary={"schema":"bluemap.persistence.save.source-oracle.v1","engineVersion":"4.4.1-stable (official)","personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","sourceHashes":hashes,"rules":_plain(rules),"cases":cases,"corrupt":corrupt}
 var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print("MIGRATION SAVE EXPORT OK");quit(0)
