extends SceneTree
## Lets the original game load saves written back by Unity; runs only under the UUID-isolating recorder.
func _initialize(): _run.call_deferred()
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
func _store(gs:Node,text:String)->void:
 var f:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE);f.store_string(text);f.close()
func _run():
 var out:="";var source:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
  if args[i]=="--cases" and i+1<args.size():source=args[i+1]
 if out=="" or source=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe return export");quit(1);return
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
 if not parsed is Array or parsed.is_empty():push_error("Return cases missing");quit(1);return
 var gs:=root.get_node("GameState");gs.set_process(false)
 var rows:Array=[]
 for c:Dictionary in parsed:
  # The original game loads the old save and writes it again in its own way...
  gs.meta_achievements={};gs.new_game();_store(gs,c.inputJson)
  if not gs.load_game():push_error("Source fixture rejected: "+c.id);quit(1);return
  if not gs.save_game(gs.load_pos):push_error("Source save failed: "+c.id);quit(1);return
  gs.meta_achievements={}
  if not gs.load_game():push_error("Own save rejected: "+c.id);quit(1);return
  var own:Dictionary=_exact(_snapshot(gs))
  # ...and then loads what Unity wrote for the same progress.
  gs.meta_achievements={};gs.new_game();_store(gs,c.exportJson)
  var accepted:bool=gs.load_game()
  rows.append({"id":c.id,"sha256":str(c.exportJson).sha256_text(),"godotAccepted":accepted,"afterOwnSave":own,"expected":_exact(_snapshot(gs)),"useLoadPosition":gs.use_load_pos})
 var hashes:Dictionary={}
 for p:String in ["scripts/core/game_state.gd","scripts/core/world_atlas.gd","scripts/core/equipment.gd","scripts/core/appearance.gd","scripts/core/professions.gd","scripts/core/homestead.gd","scripts/core/coastal_home.gd","scripts/core/stockroom.gd","scripts/core/personal_home.gd","scripts/core/yard.gd","scripts/core/progression.gd"]:
  hashes[p]=FileAccess.get_file_as_string("res://"+p).replace("\r\n","\n").sha256_text()
 var result:Dictionary={"schema":"bluemap.persistence.export.source-oracle.v1","engineVersion":"4.4.1-stable (official)","personalSavesUsed":false,"float64Encoding":"ieee754-binary64-little-endian-hex","sourceHashes":hashes,"cases":rows}
 var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print("MIGRATION RETURN EXPORT OK");quit(0)
