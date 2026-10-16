extends CanvasLayer
const Farm:=preload("res://scripts/core/homestead.gd")
const Identity:=preload("res://scripts/core/craft_identity.gd")
const Feedback:=preload("res://scripts/core/garden_feedback.gd")
const Style:=preload("res://scripts/core/ui_style.gd")
var world: Node2D
var source: WeakRef
var map_id:=""
var active:=false
var opened_frame:=-1
var root: Control
var panel: PanelContainer
var box: VBoxContainer
var buttons: Array[Button]=[]
var tool_grid: GridContainer
var tool_info: Label
var role_card: Control
var theme_id:="tools"
static func shortcut() -> String:
 var controls: Node=(Engine.get_main_loop() as SceneTree).root.get_node("Controls")
 if controls.controller_active and controls.binding_events("homestead","controller").is_empty():return controls.action_label("crafting")+" → "+controls.action_label("potion")
 return controls.action_label("homestead")
static func mode_name(mode: String) -> String:
 match mode:
  "soil":return TranslationServer.translate("Grond bewerken")
  "channel":return TranslationServer.translate("Kanaal graven")
  "grape":return TranslationServer.translate("Druiven planten")
  "flower":return TranslationServer.translate("Bloemen zaaien")
  "fertilize":return TranslationServer.translate("Bemesten")
  "harvest":return TranslationServer.translate("Druiven oogsten")
  "fill":return TranslationServer.translate("Grond herstellen")
 return TranslationServer.translate("Gereedschap opbergen")
static func station_name(role: String) -> String:
 match role:
  "compost":return TranslationServer.translate("Mesthoop")
  "wine":return TranslationServer.translate("Wijnvat")
  "hive":return TranslationServer.translate("Bijenkast")
  "bed":return TranslationServer.translate("Je eigen bed")
  "wild_grape":return TranslationServer.translate("Wilde bosdruiven")
  "supplies":return TranslationServer.translate("Tuinvoorraad")
 return TranslationServer.translate("Woning en tuin")
func _ready():
 layer=18;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("home_ui")
 root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(root)
 var dim:=ColorRect.new();dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.color=Color(0.03,.07,.09,.9);root.add_child(dim)
 panel=PanelContainer.new();Style.style_panel(panel);root.add_child(panel)
 box=VBoxContainer.new();box.add_theme_constant_override("separation",6);panel.add_child(box)
 Controls.device_changed.connect(device_changed);Lang.changed.connect(language_changed);root.hide()
func open(station: Node2D):
 map_id=GameState.map_id;source=weakref(station) if station!=null else null
 if GameState.input_locked():queue_free();return
 active=true;opened_frame=Engine.get_process_frames();GameState.set_ui("homestead",true);root.show();rebuild()
func valid() -> bool:
 if not active or GameState.map_id!=map_id or GameState.ended or GameState.transitioning:return false
 if source==null:return true
 var node: Node2D=source.get_ref()
 return is_instance_valid(node) and not node.is_queued_for_deletion() and world.player.position.distance_to(node.position)<=68
func button(text: String,action: Callable,disabled:=false,parent: Node=null):
 var b:=Button.new();Style.style_button(b,18);Identity.style_button(b,theme_id);b.text=text;b.custom_minimum_size=Vector2(304,44) if parent!=null else Vector2(620,36);b.disabled=disabled
 (parent if parent!=null else box).add_child(b);b.pressed.connect(action);buttons.append(b)
 return b
func message(text: String):
 var l:=Style.make_label(text,18,Color("d7dfcf"));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x=620;box.add_child(l)
func rebuild():
 for child in box.get_children():box.remove_child(child);child.queue_free()
 buttons.clear();tool_grid=null;tool_info=null;role_card=null
 var node: Node2D=source.get_ref() if source!=null else null
 var role: String=node.obj.role if node!=null else "tools"
 theme_id=role;Identity.style_panel(panel,role)
 var title:=Style.make_label(station_name(role) if role!="tools" else tr("Tuinhak · kies je werk"),26,Color("f0d39b"));box.add_child(title)
 title.modulate=Identity.accent(role).lightened(.15)
 if role!="tools":
  role_card=load("res://scripts/ui/workplace_card.gd").new();role_card.role=role;role_card.unit=node.obj.get("unit","") if node!=null else "";box.add_child(role_card)
 if role=="tools":
  message(tr("Kies je werk en houd %s vast terwijl je langs een rij loopt; herstellen werkt per druk.") % Controls.action_label("interact"))
  tool_grid=GridContainer.new();tool_grid.columns=2;tool_grid.add_theme_constant_override("h_separation",8);tool_grid.add_theme_constant_override("v_separation",6);box.add_child(tool_grid)
  for mode in ["soil","channel","grape","flower","fertilize","harvest","fill",""]:
   var item: String={"grape":"hs_seed","flower":"hs_flower_seed","fertilize":"hs_fertilizer"}.get(mode,"")
   var text: String=tr("%s · bij je: %d") % [mode_name(mode),GameState.count(item)] if item!="" else mode_name(mode)
   var b: Button=button(("✓ " if Farm.mode==mode else "")+text,choose.bind(mode),mode!="" and GameState.count("hs_hoe")==0,tool_grid)
   b.focus_entered.connect(show_tool_info.bind(mode))
  tool_info=Style.make_label("",17,Color("c9dfcb"));tool_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;tool_info.custom_minimum_size=Vector2(620,44);box.add_child(tool_info)
  button(tr("Wateroverzicht: aan") if Farm.show_water else tr("Wateroverzicht: uit"),toggle_water)
  button(tr("Tuinhulp stoppen") if GameState.flag("hs_garden_help") else tr("Tuinhulp starten · vrijwillig"),toggle_help)

 elif role in ["guide","supplies"]:
  message(tr("Dit huis en de tuin zijn van jou. Buiten: twee wijnvaten, mesthoop achter het dak en een bijenkast. Haal je gratis hak en zaden. Leid met kanaaltjes water uit de dorpsbeek naar de grond; droge gewassen wachten zonder te verdorren. Druiven groeien in 90 s, bloemen in 60 s actieve speeltijd. Menu's pauzeren de tijd."))
  button(tr("Neem hak en zaden · eenmalig gratis"),supply,GameState.flag("hs_supplies"))
  button(tr("Tuinstanden openen"),tools)
  button(tr("Oogst alle rijpe druiven in je tuin"),harvest)
  message(Feedback.guide_text())
  button(tr("Tuinhulp stoppen") if GameState.flag("hs_garden_help") else tr("Tuinhulp starten · vrijwillig"),toggle_help)
 elif role=="bed":
  message(tr("Een rustige eigen woning. Rusten vult hartjes en stamina aan en slaat hier op. Het blauwe punt voor je huis ontdekt een snelreisbestemming op de kaart."))
  button(tr("Rusten en opslaan"),rest)
 elif role=="wild_grape":
  message(tr("Verzamel drie bosdruiven. Eet ze voor één hartje, maak pitten via Beroepen of vul je wijnvat. De struik herstelt na 120 s actieve speeltijd."))
  button(tr("Pluk drie druiven"),grapes,GameState.play_time<Farm.state().wild_due or GameState.room("hs_grape")<3)
 elif role=="hive":
  message(tr("Bloemen in bereik: %d / 3 nodig. Bloeiende planten binnen vijf tegels geven bijen voedsel. Zonder bloemen pauzeert de productie. Iedere 120 s actieve speeltijd één honing; de kast bewaart maximaal acht.") % Farm.flowers())
  message(tr("Honing klaar: %d · voortgang %.0f / 120 s") % [Farm.state().honey,Farm.state().honey_time])
  button(tr("Honing uit de kast halen"),collect.bind("hive"),Farm.state().honey==0 or GameState.room("hs_honey")<Farm.state().honey)
 else:
  var id: String="compost" if role=="compost" else node.obj.unit
  var recipe: Dictionary=Farm.JOBS[id]
  message(tr("Composteren · twee dierenpoep worden drie meststof in 30 s.") if role=="compost" else tr("Wijn maken · drie druiven worden één fles in 90 s."))
  message(tr("Beschikbaar: %d · nodig per portie: %d · maximaal twintig porties tegelijk") % [load("res://scripts/core/stockroom.gd").available(recipe.input),recipe.cost])
  if load("res://scripts/core/stockroom.gd").nearby_kind()!="":message(tr("Ingrediënten uit de bereikbare huisvoorraad tellen mee."))
  if Farm.state().jobs.has(id):
   var job: Dictionary=Farm.state().jobs[id]
   message(tr("Nog %.0f s actieve speeltijd · resultaat: %d") % [maxf(0,recipe.seconds-job.time),job.batches*recipe.yield])
   button(tr("Meststof uitscheppen") if role=="compost" else tr("Wijn bottelen"),collect.bind(id),job.time<recipe.seconds or GameState.room(recipe.output)<job.batches*recipe.yield)
  else:
   var count: int=mini(20,load("res://scripts/core/stockroom.gd").available(recipe.input)/recipe.cost)
   button(tr("Meng één portie compost") if role=="compost" else tr("Vul vat voor één fles"),start.bind(id,1),count<1)
   if count>1:button((tr("Meng %d porties compost") if role=="compost" else tr("Vul vat voor %d flessen")) % count,start.bind(id,count))
 if GameState.map_id=="player_home" and role in ["bed","guide","supplies"]:button(tr("Je huis inrichten"),decorate)
 button(tr("Sluiten"),close)
 var focus: Array[Control]=[]
 for b in buttons:
  if not b.disabled:focus.append(b)
 Style.link_vertical(focus)
 if tool_grid!=null:link_tools(focus)
 device_changed(Controls.controller_active);layout()
 var selected: Button=null
 if tool_grid!=null:
  var index: int=["soil","channel","grape","flower","fertilize","harvest","fill",""].find(Farm.mode)
  if Farm.mode=="" and GameState.count("hs_hoe")>0:index=0
  if index>=0 and not buttons[index].disabled:selected=buttons[index]
 (selected if selected!=null else focus[0]).grab_focus()
func choose(value: String):
 if not valid():return
 Farm.mode=value;close()
 for n in get_tree().get_nodes_in_group("homesteads"):
  n.cooldown=.3;n.waiting_release=Input.is_action_pressed("interact");n.clear_stroke()
func tools():
 if not valid():return
 source=null;rebuild()
func supply():
 if not valid():return
 Farm.starter();rebuild()
func harvest():
 if not valid():return
 Farm.harvest_all();rebuild()
func rest():
 if not valid():return
 GameState.full_rest();GameState.save_requested.emit();close()
func grapes():
 if not valid():return
 Farm.wild_grapes();rebuild()
func start(id: String,count: int):
 if valid():Farm.start_job(id,count);rebuild()
func collect(id: String):
 if valid():Farm.collect(id);rebuild()
func layout():
 var size:=get_viewport().get_visible_rect().size;panel.size=panel.get_combined_minimum_size()
 var factor:=minf(1,minf((size.x-32)/panel.size.x,(size.y-32)/panel.size.y));panel.scale=Vector2.ONE*factor;panel.position=(size-panel.size*factor)*.5
func device_changed(_pad: bool):
 for b in buttons:b.mouse_filter=Control.MOUSE_FILTER_IGNORE if Controls.controller_active else Control.MOUSE_FILTER_STOP
func language_changed(_locale: String):
 if active:rebuild()
func _process(_delta: float):
 if active:
  if not valid():close();return
  layout()
func _unhandled_input(event: InputEvent):
 if not active or Engine.get_process_frames()<=opened_frame or not Controls.allows_event(event):return
 if event.is_action_pressed("ui_cancel") or event.is_action_pressed("homestead"):close();get_viewport().set_input_as_handled()
 elif Style.activate_focused(root,event):get_viewport().set_input_as_handled()
func close():active=false;GameState.set_ui("homestead",false);queue_free()
func _exit_tree():
 if active:GameState.set_ui("homestead",false)

func show_tool_info(value: String):
 if tool_info==null:return
 match value:
  "soil":tool_info.text=tr("Grond voor druiven en bloemen; paden en vrije doorgangen blijven beschermd.")
  "channel":tool_info.text=tr("Begin naast de beek; aangesloten kanalen vullen zich vanzelf en blijven beloopbaar.")
  "grape":tool_info.text=tr("Een blijvende druivenstok; water laat hem groeien, meststof verhoogt één oogst.")
  "flower":tool_info.text=tr("Bloemen blijven bloeien en voeden bijen binnen vijf tegels van de kast.")
  "fertilize":tool_info.text=tr("Eén meststof per stok geeft vijf in plaats van drie druiven bij de volgende oogst.")
  "harvest":tool_info.text=tr("Houd vast en loop langs rijpe druiven; de stokken blijven staan.")
  "fill":tool_info.text=tr("Herstel één tegel per druk; je krijgt het zaad terug, maar de plant verdwijnt.")
  _:tool_info.text=tr("Berg je hak op; je tuin groeit verder terwijl je op avontuur bent.")
func toggle_water():
 if not valid():return
 Farm.show_water=not Farm.show_water;rebuild()
func toggle_help():
 if not valid():return
 GameState.set_flag("hs_garden_help",not GameState.flag("hs_garden_help"));GameState.save_requested.emit();rebuild()
func link_tools(focus: Array[Control]):
 var grid_buttons: Array=tool_grid.get_children()
 for i in grid_buttons.size():
  var b: Button=grid_buttons[i]
  if b.disabled:continue
  var side: Button=grid_buttons[i+1 if i%2==0 else i-1]
  b.focus_neighbor_left=b.get_path_to(side if not side.disabled else b);b.focus_neighbor_right=b.focus_neighbor_left
  for direction in [-1,1]:
   var index: int=i+int(direction)*2
   while index>=0 and index<grid_buttons.size() and grid_buttons[index].disabled:index+=direction*2
   var other: Control=grid_buttons[index] if index>=0 and index<grid_buttons.size() else focus[focus.size()-1] if direction<0 else buttons[8]
   if direction<0:b.focus_neighbor_top=b.get_path_to(other)
   else:b.focus_neighbor_bottom=b.get_path_to(other)

func decorate():
 if not valid() or GameState.map_id!="player_home":return
 close()
 var ui: CanvasLayer=load("res://scripts/ui/house_ui.gd").new();ui.world=world;world.add_child(ui);ui.open()
