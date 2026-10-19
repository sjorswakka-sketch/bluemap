extends "res://tools/storage_preview.gd"
## Native character proof. The wrapper verifies a disposable UUID save folder first.
const Npcs:=preload("res://scripts/data/npcs.gd")
const Memory:=preload("res://scripts/core/world_memory.gd")
const Appearance:=preload("res://scripts/core/appearance.gd")
const Equipment:=preload("res://scripts/core/equipment.gd")
var Player: Variant
var Npc: Variant
var MemoryActor: Variant
var VillageActor: Variant
var LivingResident: Variant
const DIRS:=[Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]
const DIR_LABELS:=["Zuid","Noord","Oost","West"]

class ContactStage extends Node2D:
 var heading:=""
 var labels: Array=[]
 func _draw():
  draw_rect(Rect2(0,0,1152,648),Color("162b31"))
  draw_string(ThemeDB.fallback_font,Vector2(24,40),heading,HORIZONTAL_ALIGNMENT_LEFT,1104,27,Color("f0e0b3"))
  draw_string(ThemeDB.fallback_font,Vector2(24,68),"Echte spelactoren · 2× beeldschaal · voetpunt en bestaande lichaamsgrootte behouden",HORIZONTAL_ALIGNMENT_LEFT,1104,15,Color("a0bdb9"))
  for i in labels.size():
   var at:=Vector2(12+(i%6)*192,88+(i/6)*120)
   draw_rect(Rect2(at,Vector2(184,116)),Color("344e4b"))
   draw_line(at+Vector2(15,88),at+Vector2(169,88),Color("6c8977"),1)
   var label: String=labels[i]
   var font:=ThemeDB.fallback_font
   while font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x>173 and label.length()>2:label=label.left(label.length()-2)+"…"
   draw_string(font,at+Vector2(5,109),label,HORIZONTAL_ALIGNMENT_LEFT,174,13,Color("eee3c4"))

var gallery: CanvasLayer
var stage: ContactStage
var counts: Dictionary={}

func shot(id: String):
 root.get_texture().get_image().save_png("res://actor_"+id+".png")

func prop(node: Object,key: String,value: Variant):
 for entry: Dictionary in node.get_property_list():
  if entry.name==key:node.set(key,value);return

func stop_actor(node: Node2D,clock: float,direction: Vector2,moving_now: bool):
 node.set_process(false);node.set_physics_process(false)
 prop(node,"t",clock);prop(node,"time",clock);prop(node,"walk_time",clock)
 prop(node,"facing",direction);prop(node,"visual_facing",direction);prop(node,"art_facing",direction);prop(node,"visual_direction",DIRS.find(direction))
 prop(node,"velocity",direction*25 if moving_now else Vector2.ZERO)
 node.queue_redraw()

func build_actor(spec: Dictionary) -> Node2D:
 var node: Node2D
 match spec.type:
  "player":
   node=Player.new();node.world=world
  "npc":
   node=Npc.new();node.world=world;node.setup(spec.id)
  "memory":
   node=MemoryActor.new();node.world=world;node.role=spec.id
  "village":
   node=VillageActor.new();node.world=world;node.role=spec.id
  _:
   node=LivingResident.new();node.sheet=spec.id
 stage.add_child(node)
 if spec.type=="player":
  node.camera.enabled=false
  for child in node.get_children():
   if child is CanvasItem:child.hide()
 var direction: Vector2=spec.get("direction",Vector2.DOWN)
 var clock: float=spec.get("clock",.18)
 stop_actor(node,clock,direction,spec.get("moving",false))
 if spec.type=="player":
  node.moving=spec.get("moving",false);node.sprinting=spec.get("action","")=="sprint"
  node.roll_dir=direction;node.aim_direction=direction;node.attack_direction=direction;node.bow_direction=direction;node.work_facing=direction
  match spec.get("action",""):
   "roll":node.roll_timer=.16
   "sword":node.attack_timer=.09
   "bow":node.bow_anim=.16
   "mining","foraging":
    node.work_active=true;node.work_kind=spec.action;node.work_elapsed=.16;node.work_duration=1
  node.invuln=0
 return node

func page_image(id: String,title: String,specs: Array):
 for n in stage.get_children():n.queue_free()
 await frames(4)
 stage.heading=title;stage.labels=[]
 for i in specs.size():
  var spec: Dictionary=specs[i]
  var actor:=build_actor(spec)
  actor.position=Vector2(104+(i%6)*192,133+(i/6)*120)
  actor.scale=Vector2(2,2)
  stage.labels.append(spec.label)
 stage.queue_redraw()
 await frames(8);shot(id);counts[id]=specs.size()

func paged(id: String,title: String,specs: Array):
 var index:=0
 for offset in range(0,specs.size(),24):
  await page_image(id+"_"+str(index),title+" · "+str(index+1),specs.slice(offset,mini(offset+24,specs.size())));index+=1

func player_specs(action: String="") -> Array:
 var result: Array=[]
 for direction in 4:
  for frame in 3:
   result.append({"type":"player","label":DIR_LABELS[direction]+" · "+(action if action!="" else "pose")+" "+str(frame),"direction":DIRS[direction],"moving":frame>0,"clock":.0 if frame==0 else .02 if frame==1 else .14,"action":action})
 return result

func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
 Player=load("res://scripts/entities/player.gd");Npc=load("res://scripts/entities/npc.gd");MemoryActor=load("res://scripts/entities/memory_actor.gd");VillageActor=load("res://scripts/entities/village_actor.gd");LivingResident=load("res://scripts/entities/living_resident.gd")
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15)
 for n in world.get_children():
  if n is CanvasItem:n.hide()
  elif n is CanvasLayer:n.visible=false
 world.player.target=null
 gallery=CanvasLayer.new();gallery.layer=30;root.add_child(gallery);stage=ContactStage.new();gallery.add_child(stage)
 await page_image("player_default","Speler · standaard · stil en twee loopposes",player_specs())
 gs.appearance=Appearance.normalize_appearance({"gender":"v","hair":"v_lang","hair_color":4,"eyes":"rond","eye_color":2})
 await page_image("player_alternate","Speler · ander uiterlijk · vier richtingen",player_specs())
 gs.appearance=Appearance.DEFAULT.duplicate()
 for slot: String in Appearance.SLOTS:
  for item: String in Appearance.Data.ITEMS:
   if Appearance.clothing_slot_of(item)==slot:
    gs.give(item,1,true);gs.clothing[slot]={"item":item,"dye":(Appearance.SLOTS.keys().find(slot)+2)%Appearance.Data.DYE_COLORS.size()};break
 await page_image("player_clothing","Speler · kleding, kapsel en richtinglagen",player_specs())
 gs.clothing.clear()
 for slot: String in Equipment.SLOTS:
  for item: String in Equipment.Data.ITEMS:
   if Equipment.slot_of(item)==slot:
    gs.give(item,1,true);gs.equipment[slot]=item;break
 gs.give("bow",1,true);gs.weapon="crystal"
 await page_image("player_equipment","Speler · gedragen uitrusting en boog",player_specs())
 var actions: Array=[]
 for action in ["sprint","roll","sword","bow","foraging","mining"]:
  for direction in 4:actions.append({"type":"player","label":action+" · "+DIR_LABELS[direction],"direction":DIRS[direction],"moving":action=="sprint","clock":.14,"action":action})
 await page_image("player_actions","Speler · beweging, gevecht en gereedschap",actions)
 var npcs: Array=[]
 for id: String in Npcs.NPCS:npcs.append({"type":"npc","id":id,"label":Npcs.info(id).name})
 await paged("npcs","Alle bestaande NPCs · eigen silhouet en kleding",npcs)
 var directions: Array=[]
 for id in ["greta","bram","pim","meer_lena","rg_raf","mees"]:
  if not Npcs.NPCS.has(id):continue
  for direction in 4:directions.append({"type":"npc","id":id,"label":Npcs.info(id).name+" · "+DIR_LABELS[direction],"moving":true,"direction":DIRS[direction],"clock":.14})
 await paged("npc_directions","NPCs · looprichting en bewegingspose",directions)
 var residents: Array=[]
 for role: String in Memory.PLACES:residents.append({"type":"memory","id":role,"label":Memory.name_for(role)})
 for role in ["gardener","courier"]:residents.append({"type":"village","id":role,"label":"Dorpsroutine · "+role})
 for sheet in ["npc_fenna","npc_elke"]:residents.append({"type":"living","id":sheet,"label":"Teruggekeerde bewoner · "+sheet})
 await page_image("residents","Bewoners · werkrollen en dorpsroutines",residents)
 gallery.queue_free();await frames(8)
 for n in world.get_children():
  if n is CanvasItem:n.show()
  elif n is CanvasLayer:n.visible=true
 await enter("village",Vector2(13.5,16.5),2.2);shot("village_scale")
 await enter("lake",Vector2(30.5,8.5),2.2);shot("lake_scale")
 await enter("harbor",Vector2(54.5,26.5),2.2);shot("harbor_scale")
 await enter("arena",Vector2(13,10),1.0);shot("arena_scale")
 await enter("player_home",Vector2(10.5,6.5),2.0)
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for window_size in [Vector2i(960,540),Vector2i(1152,648)]:
   root.size=window_size;world.menu_ui.open(7);await frames(10);shot("appearance_"+locale+str(window_size.x));world.menu_ui.close();await frames(3)
 var evidence:=FileAccess.open("res://actor-preview.json",FileAccess.WRITE);evidence.store_string(JSON.stringify({"shots":counts,"npc_ids":Npcs.NPCS.keys(),"memory_roles":Memory.PLACES.keys()}));evidence.close()
 world.queue_free();world=null;await frames(8);print("ACTOR PREVIEW OK");quit()
