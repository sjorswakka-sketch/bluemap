extends CanvasLayer
const Style:=preload("res://scripts/core/ui_style.gd")
const Adventure:=preload("res://scripts/core/coastal_adventures.gd")
var world: Node2D
var source: WeakRef
var map_id:=""
var active:=false
var repairing:=false
var elapsed:=0.0
var opened_frame:=-1
var root: Control
var panel: PanelContainer
var title: Label
var detail: Label
var progress: ProgressBar
var options: VBoxContainer
var buttons: Array[Button]=[]
func _ready():
 layer=16;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("adventure_ui")
 root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(root)
 var dim:=ColorRect.new();dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.color=Color(0.02,0.06,0.1,0.83);root.add_child(dim)
 panel=PanelContainer.new();Style.style_panel(panel);root.add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
 title=Style.make_label("",25,Color("efd29b"));box.add_child(title)
 detail=Style.make_label("",18,Color("d0e2dc"));detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(620,112);box.add_child(detail)
 progress=ProgressBar.new();progress.max_value=1.8;progress.custom_minimum_size=Vector2(620,20);progress.show_percentage=false;box.add_child(progress)
 options=VBoxContainer.new();options.add_theme_constant_override("separation",7);box.add_child(options)
 Controls.device_changed.connect(device_changed);Lang.changed.connect(language_changed);root.hide()
func valid_source() -> bool:
 var node: Node2D=source.get_ref() if source!=null else null
 return is_instance_valid(node) and not node.is_queued_for_deletion() and node.world==world and GameState.map_id==map_id and not GameState.transitioning and not GameState.ended and world.player.position.distance_to(node.position)<=64
func open(node: Node2D):
 source=weakref(node);map_id=GameState.map_id
 if GameState.input_locked() or not valid_source():queue_free();return
 active=true;opened_frame=Engine.get_process_frames();GameState.set_ui("adventure",true);root.show();rebuild()
func add_option(text: String,action: Callable,disabled:=false):
 var b:=Button.new();Style.style_button(b,18);b.text=text;b.custom_minimum_size=Vector2(620,43);b.disabled=disabled;options.add_child(b);b.pressed.connect(action);buttons.append(b)
func begin(id: String):
 if not GameState.quests.has(id):GameState.start_quest(id)
func record(flag: String):
 if not valid_source():return
 GameState.set_flag(flag);Adventure.sync();GameState.save_requested.emit();rebuild()
func rebuild():
 for child in options.get_children():options.remove_child(child);child.queue_free()
 buttons.clear();progress.visible=repairing
 var node: Node2D=source.get_ref() if source!=null else null
 if node==null:return
 title.text=node.label();detail.text=""
 match node.obj.role:
  "message":
   begin("ad_message");Adventure.sync()
   detail.text=tr("Een los logboek: ‘Niet langs de buitenbank. Het hout brak terwijl het water terugliep.’ De afzender ontbreekt. Vergelijk het wrakhout aan het zuidelijke eilandstrand met de afzetting aan de oostelijke rivieroever. Het werkboek op de havenkade wacht op je conclusie.")
  "splinter":
   detail.text=tr("De breuk is scherp en schoon; er zit wit schelpgruis tussen de vezels. Dit hout heeft tegen een harde buitenbank geschuurd, niet lang op een modderige rivierbodem gelegen.")
   add_option(tr("Noteer het schelpgruis"),record.bind("ad_splinter"),GameState.flag("ad_splinter"))
  "silt":
   detail.text=tr("De rivieroever draagt fijn donker slib en afgerond riet. Het lichte schelpgruis van het wrakhout ontbreekt hier. De rivier heeft het hout aangevoerd, maar de breuk ontstond ergens anders.")
   add_option(tr("Noteer het donkere slib"),record.bind("ad_silt"),GameState.flag("ad_silt"))
  "record":
   detail.text=tr("Het havenboek kan een waarschuwing bij de juiste vaarroute plaatsen. Vergelijk beide waarnemingen voordat je een conclusie trekt. Een vergissing kost niets.")
   if GameState.flag("ad_message_done"):detail.text=tr("De buitenbank staat gemarkeerd. Bij het einde van de werkkade dobbert de nieuwe waarschuwingsboei.")
   else:
    add_option(tr("De buitenbank brak het hout; markeer die route"),deduce.bind(true),not Adventure.evidence() or not GameState.quests.has("ad_message"))
    add_option(tr("Het hout brak op de modderige rivieroever"),deduce.bind(false),not Adventure.evidence() or not GameState.quests.has("ad_message"))
  "pilot":
   detail.text=tr("De loodsen volgden herkenbare vormen, zonder klok of verzamelopdracht. Begin bij de lage gespleten rots in het noordwestelijke grasland, boven het hoge havenpad. Lees daar het oude richtteken.")
   add_option(tr("Volg de oude loodsenroute"),start_pilot,GameState.quests.has("ad_pilot"))
  "rock":
   detail.text=tr("In de spleet wijst een oude kerf naar het oosten: zoek de bleke zoutgraspol voorbij het midden van de kaap, ten noorden van het vuurtorenpad.")
   add_option(tr("Lees het richtteken"),trail.bind(0),GameState.quest_state("ad_pilot")!="active" or GameState.quest_step("ad_pilot")!=0)
  "grass":
   detail.text=tr("Tussen het bleke gras ligt een loodsensteen met een lage golf erin. Volg de kaap naar de bank aan de zuidoostelijke afslag; daar liggen de oude schermlatten klaar.")
   add_option(tr("Volg de lage golf naar de rustplek"),trail.bind(1),GameState.quest_state("ad_pilot")!="active" or GameState.quest_step("ad_pilot")!=1)
  "shelter":
   detail.text=tr("Een bank boven zee. De oude schermlatten liggen hier al: zet ze langs de windzijde terug. Geen spullen nodig; het uitzicht en de route blijven open.")
   add_option(tr("Zet het lage windscherm terug"),shelter,GameState.quest_state("ad_pilot")!="active" or GameState.quest_step("ad_pilot")!=2)
   if GameState.flag("ad_pilot_done"):detail.text=tr("Het lage windscherm staat weer. Neem gerust de tijd; de hoge terugweg naar de haven blijft vrij.")
  "entrance":
   detail.text=tr("Tijholte · optionele zijgrot. Volg de korte noordelijke afslag naar de ingang. Binnen blijft de brede zuidelijke gang veilig; de noordelijke poelen bevatten krabben en lichtkringen. Je kunt altijd omkeren.")
   add_option(tr("Onderzoek het tijrad in de zijgrot"),start_wheel,GameState.quests.has("ad_wheel"))
  "wheel":
   begin("ad_wheel")
   if GameState.quest_state("ad_wheel")=="active":GameState.set_quest_step("ad_wheel",1)
   detail.text=tr("Een losgeraakte pen houdt het rad tegen. Het passende gereedschap ligt hier. Maak de pen vrij en stel het rad af; dat duurt even. Annuleer met Terug of een looptoets. Je verliest niets. De zuidelijke omweg blijft open.")
   if GameState.flag("ad_wheel_done"):detail.text=tr("Het rad draait. De korte brug over de middelste watergeul is droog; de brede zuidelijke route blijft ook open.")
   add_option(tr("Maak het rad vrij · gereedschap ligt hier"),start_repair,GameState.flag("ad_wheel_done"))
  "keeper_rest":
   detail.text=tr("De hoeder rust aan de rand van zijn poel. Hij valt je niet zomaar aan. Bij de sluistafel in de zuidelijke gang kun je na herstel van het tijrad kiezen hoe het water stroomt.")
  "sluice":
   detail.text=tr("Het herstelde rad kan het water verdelen. Geef de hoeder zijn rustige poel, of voed het havenrad en neem vrijwillig zijn krachtproef aan. De keuze blijft zichtbaar. De beloning voor het verhaal is gelijk; terugtrekken uit de proef blijft mogelijk.")
   if GameState.flag("ad_keeper_done"):
    detail.text=tr("Het riet groeit rond de rustige poel. De hoeder heeft zich teruggetrokken.") if GameState.flag("ad_pool") else tr("Het havenrad draait. De Schelpenhoeder heeft je krachtproef aanvaard; de doorgang blijft vrij.")
   elif not GameState.flag("ad_wheel_done"):detail.text=tr("Herstel eerst het tijrad in de veilige zuidelijke gang. De hoeder wacht; de terugweg blijft vrij.")
   else:
    begin("ad_keeper")
    add_option(tr("Geef de poel rust · vreedzame afloop"),choose.bind(true))
    add_option(tr("Voed het havenrad · vrijwillige krachtproef"),choose.bind(false),GameState.flag("ad_duel"))
 add_option(tr("Annuleren") if repairing else tr("Sluiten"),close)
 if repairing:
  for b in buttons:
   if b!=buttons.back():b.disabled=true
 var focusable: Array[Control]=[]
 for b in buttons:
  if not b.disabled:focusable.append(b)
 Style.link_vertical(focusable);device_changed(Controls.controller_active);layout();focusable[0].grab_focus()
func deduce(correct: bool):
 if not valid_source() or not Adventure.evidence() or not GameState.quests.has("ad_message"):return
 if correct:Adventure.finish("ad_message");Sound.play("ad_water",-7);rebuild()
 else:detail.text=tr("Het slib verklaart de breuk niet. Schelpgruis in schoon gebroken hout wijst naar de harde buitenbank. Vergelijk je aantekeningen en probeer gerust opnieuw.")
func start_pilot():
 if not valid_source():return
 begin("ad_pilot");GameState.save_requested.emit();rebuild()
func trail(step: int):
 if not valid_source() or GameState.quest_state("ad_pilot")!="active" or GameState.quest_step("ad_pilot")!=step:return
 GameState.set_quest_step("ad_pilot",step+1);GameState.save_requested.emit();rebuild()
func shelter():
 if not valid_source() or GameState.quest_step("ad_pilot")!=2:return
 Adventure.finish("ad_pilot");Sound.play("ad_work",-7);rebuild()
func start_wheel():begin("ad_wheel");GameState.save_requested.emit();rebuild()
func start_repair():
 if not valid_source() or GameState.flag("ad_wheel_done"):return
 repairing=true;elapsed=0;world.player.start_work_animation("repair",1.8,(source.get_ref() as Node2D).position);Sound.play("ad_work",-8);rebuild()
 for b in buttons:
  if b!=buttons.back():b.disabled=true
func choose(peace: bool):
 if not valid_source() or not GameState.flag("ad_wheel_done") or GameState.flag("ad_keeper_done"):return
 if peace:Adventure.resolve(true);Sound.play("ad_water",-6);close()
 else:GameState.set_flag("ad_duel");GameState.save_requested.emit();close()
func language_changed(_locale: String):
 if active:rebuild()
func device_changed(_pad: bool):
 for b in buttons:b.mouse_filter=Control.MOUSE_FILTER_IGNORE if Controls.controller_active else Control.MOUSE_FILTER_STOP
func layout():
 var viewport:=get_viewport().get_visible_rect().size
 panel.size=panel.get_combined_minimum_size()
 var factor:=minf(1.0,minf((viewport.x-32)/panel.size.x,(viewport.y-32)/panel.size.y))
 panel.scale=Vector2.ONE*factor;panel.position=(viewport-panel.size*factor)*0.5
func _process(delta: float):
 if not active:return
 if not valid_source():close();return
 if repairing:
  if Input.get_vector("move_left","move_right","move_up","move_down").length()>0.2:close();return
  elapsed+=delta;progress.value=elapsed
  world.player.work_elapsed=elapsed;world.player.queue_redraw()
  if elapsed>=1.8:
   repairing=false;world.player.cancel_work_animation();Adventure.finish("ad_wheel");Sound.play("ad_water",-7)
   var position: Vector2=world.player.position
   close();world.load_map("tidal_hollow","start",position);GameState.save_requested.emit();return
 layout()
func _unhandled_input(event: InputEvent):
 if not active or Engine.get_process_frames()<=opened_frame or not Controls.allows_event(event):return
 if event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
 elif Style.activate_focused(root,event):get_viewport().set_input_as_handled()
func close():
 if not active:return
 active=false;repairing=false
 if is_instance_valid(world.player):world.player.cancel_work_animation()
 GameState.set_ui("adventure",false);root.hide();queue_free()
func _exit_tree():
 if active:GameState.set_ui("adventure",false)
 if repairing and is_instance_valid(world.player):world.player.cancel_work_animation()
