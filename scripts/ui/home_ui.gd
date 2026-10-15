extends CanvasLayer
const Farm:=preload("res://scripts/core/homestead.gd")
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
func button(text: String,action: Callable,disabled:=false):
 var b:=Button.new();Style.style_button(b,18);b.text=text;b.custom_minimum_size=Vector2(620,36);b.disabled=disabled;box.add_child(b);b.pressed.connect(action);buttons.append(b)
func message(text: String):
 var l:=Style.make_label(text,18,Color("d7dfcf"));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x=620;box.add_child(l)
func rebuild():
 for child in box.get_children():box.remove_child(child);child.queue_free()
 buttons.clear()
 var node: Node2D=source.get_ref() if source!=null else null
 var role: String=node.obj.role if node!=null else "tools"
 var title:=Style.make_label(station_name(role) if role!="tools" else tr("Tuinhak · kies je werk"),26,Color("f0d39b"));box.add_child(title)
 if role=="tools":
  message(tr("Bewerk gewone grond in je eigen tuin onder het dorp. Houd %s vast en loop langs een rij. Kanalen liggen midden in de tegel en zijn beloopbaar. %s opent deze standen. Rennen: %s vasthouden.") % [Controls.action_label("interact"),shortcut(),Controls.action_label("sprint")])
  for mode in ["soil","channel","grape","flower","fertilize","harvest","fill",""]:
   var item: String={"grape":"hs_seed","flower":"hs_flower_seed","fertilize":"hs_fertilizer"}.get(mode,"")
   button(tr("%s · bij je: %d") % [mode_name(mode),GameState.count(item)] if item!="" else mode_name(mode),choose.bind(mode),mode!="" and GameState.count("hs_hoe")==0)
 elif role in ["guide","supplies"]:
  message(tr("Dit huis en de tuin zijn van jou. Buiten: twee wijnvaten, mesthoop achter het dak en een bijenkast. Haal je gratis hak en zaden. Leid met kanaaltjes water uit de dorpsbeek naar de grond; droge gewassen wachten zonder te verdorren. Druiven groeien in 90 s, bloemen in 60 s actieve speeltijd. Menu's pauzeren de tijd."))
  button(tr("Neem hak en zaden · eenmalig gratis"),supply,GameState.flag("hs_supplies"))
  button(tr("Tuinstanden openen"),tools)
  button(tr("Oogst alle rijpe druiven in je tuin"),harvest)
 elif role=="bed":
  message(tr("Een rustige eigen woning. Rusten vult hartjes en stamina aan en slaat hier op. Het blauwe punt voor je huis ontdekt een snelreisbestemming op de kaart."))
  button(tr("Rusten en opslaan"),rest)
 elif role=="wild_grape":
  message(tr("Verzamel drie bosdruiven. Eet ze voor één hartje, maak pitten via Beroepen of vul je wijnvat. De struik herstelt na 120 s actieve speeltijd."))
  button(tr("Pluk drie druiven"),grapes,GameState.play_time<Farm.state().wild_due or GameState.room("hs_grape")<3)
 elif role=="hive":
  message(tr("Bloemen in bereik: %d / 3 nodig. Bloeiende planten binnen vijf tegels geven bijen voedsel. Zonder bloemen pauzeert de productie. Iedere 120 s actieve speeltijd één honing; de kast bewaart maximaal acht.") % Farm.flowers())
  message(tr("Honing klaar: %d · voortgang %.0f / 120 s") % [Farm.state().honey,Farm.state().honey_time])
  button(tr("Verzamel honing"),collect.bind("hive"),Farm.state().honey==0 or GameState.room("hs_honey")<Farm.state().honey)
 else:
  var id: String="compost" if role=="compost" else node.obj.unit
  var recipe: Dictionary=Farm.JOBS[id]
  message(tr("Mest: 2 dierenpoep → 3 meststof in 30 s. Wijn: 3 druiven → 1 fles in 90 s. Een batch van maximaal twintig porties loopt terwijl je op avontuur bent. Haal het resultaat op zodra er ruimte in je tas is."))
  if Farm.state().jobs.has(id):
   var job: Dictionary=Farm.state().jobs[id]
   message(tr("In productie: %d porties · %.0f / %.0f s") % [job.batches,job.time,recipe.seconds])
   button(tr("Haal het resultaat op"),collect.bind(id),job.time<recipe.seconds or GameState.room(recipe.output)<job.batches*recipe.yield)
  else:
   var count: int=mini(20,GameState.count(recipe.input)/recipe.cost)
   button(tr("Start één portie"),start.bind(id,1),count<1)
   button(tr("Start %d porties") % count,start.bind(id,count),count<1)
 button(tr("Sluiten"),close)
 var focus: Array[Control]=[]
 for b in buttons:
  if not b.disabled:focus.append(b)
 Style.link_vertical(focus);device_changed(Controls.controller_active);layout();focus[0].grab_focus()
func choose(value: String):
 if not valid():return
 Farm.mode=value;close()
 for n in get_tree().get_nodes_in_group("homesteads"):n.cooldown=.3
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
