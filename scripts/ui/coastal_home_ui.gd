extends CanvasLayer
const Style:=preload("res://scripts/core/ui_style.gd")
const Home:=preload("res://scripts/core/coastal_home.gd")
const Prof:=preload("res://scripts/core/professions.gd")
const Items:=preload("res://scripts/data/items.gd")
var world: Node2D
var source: WeakRef
var map_id:=""
var active:=false
var page:=""
var deposit:=true
var index:=0
var selected:=""
var crossing:=false
var elapsed:=0.0
var landing:=Vector2.ZERO
var opened_frame:=-1
var root: Control
var panel: PanelContainer
var title: Label
var detail: Label
var preview: Control
var options: VBoxContainer
var buttons: Array[Button]=[]
func _ready():
 layer=16;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("coastal_home_ui")
 root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(root)
 var dim:=ColorRect.new();dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.color=Color(0.02,0.06,0.1,.84);root.add_child(dim)
 panel=PanelContainer.new();Style.style_panel(panel);root.add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
 title=Style.make_label("",25,Color("efd29c"));box.add_child(title)
 detail=Style.make_label("",18,Color("d4e4df"));detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(650,80);box.add_child(detail)
 preview=Control.new();preview.custom_minimum_size=Vector2(650,90);preview.draw.connect(draw_crossing);box.add_child(preview)
 options=VBoxContainer.new();options.add_theme_constant_override("separation",5);box.add_child(options)
 Controls.device_changed.connect(device_changed);Lang.changed.connect(language_changed);Controls.bindings_changed.connect(bindings_changed);root.hide()
func valid() -> bool:
 var n: Node2D=source.get_ref() if source!=null else null
 return is_instance_valid(n) and not n.is_queued_for_deletion() and n.world==world and GameState.map_id==map_id and not GameState.transitioning and not GameState.ended and world.player.position.distance_to(n.position)<=64
func open(n: Node2D):
 source=weakref(n);map_id=GameState.map_id
 if GameState.input_locked() or not valid():queue_free();return
 page="layout" if n.obj.role in ["layout","lamp","shelf"] else n.obj.role
 active=true;opened_frame=Engine.get_process_frames();GameState.set_ui("coastal_home",true);root.show();rebuild()
func button(text: String,action: Callable,id: String,disabled:=false,container: Node=null,width:=650.0) -> Button:
 var b:=Button.new();Style.style_button(b,18);b.text=text;b.custom_minimum_size=Vector2(width,38);b.disabled=disabled;b.set_meta("action",id)
 (options if container==null else container).add_child(b);b.pressed.connect(action);buttons.append(b);return b
func row() -> HBoxContainer:
 var h:=HBoxContainer.new();h.add_theme_constant_override("separation",6);options.add_child(h);return h
func rebuild(focus_id:=""):
 for child in options.get_children():options.remove_child(child);child.queue_free()
 buttons.clear();preview.visible=page=="line";title.text="";detail.text=""
 match page:
  "door":
   title.text=tr("Rafs havenwerkplaats")
   detail.text=tr("Een gratis terugkeerplek in de bestaande nettenloods. Binnen staan een materiaalkist, werkbank, inrichttafel en rustaltaar. Geen huur, onderhoud of nieuwe bewoners. Raf deelt het oeverlijnpatroon als je hem op de kade spreekt.")
   button(tr("Ga de werkplaats in"),enter_workshop,"enter")
  "bench":
   title.text=tr("Werkbank · zeven bestaande beroepen")
   detail.text=tr("Raf helpt met lijn en houtwerk. Greta smeedt ankerbanden; Lena maakt waaierbanden en een lamp. Zoutblad en Joris' baars gaan naar Mila's keuken. De vier kustplekken leveren per oogst genoeg voor de eerste plannen; je hoeft geen dagelijkse ronde te doen.")
   button(tr("Oeverlijn · bekijk echte kosten"),recipe.bind("cw_hook"),"hook")
   button(tr("Wandrek · bekijk echte kosten"),recipe.bind("cw_shelf"),"shelf")
   button(tr("Gearkeuzes en bestaande werkplekken"),show_page.bind("gear"),"gear")
   button(tr("Werkplaats inrichten"),show_page.bind("layout"),"layout")
  "gear":
   title.text=tr("Twee keuzes voor hetzelfde handvak")
   detail.text=tr("Ankerbanden: pantser en een korte frontale wacht met tegenstoot. Waaierbanden: sneller verzamelen en een brede boogwaaier. Bezit geeft geen bonus; draag één paar via Uitrusting. Oude handschoenen en alle gewone aanvallen blijven bruikbaar.")
   button(tr("Ankerbanden · smeden bij Greta"),recipe.bind("cw_anchor"),"anchor")
   button(tr("Waaierbanden · alchemie bij Lena"),recipe.bind("cw_fan"),"fan")
   button(tr("Zeeagaatlamp · alchemie bij Lena"),recipe.bind("cw_lamp"),"lamp")
   button(tr("Kustbouillon · koken bij Mila"),recipe.bind("cw_broth"),"broth")
  "storage":build_storage()
  "layout":
   title.text=tr("Vaste meubelplekken")
   detail.text=tr("Het wandrek en de lamp hebben ieder een vaste sokkel buiten de looproute. Plaatsen, weghalen en licht wisselen kosten niets en verbruiken geen meubel. Je materiaalkist blijft altijd bruikbaar, ook zonder meubels.")
   button(tr("Wandrek opbergen") if GameState.flag("cw_shelf_placed") else tr("Wandrek plaatsen"),furnish.bind("shelf",0 if GameState.flag("cw_shelf_placed") else 1),"shelf",GameState.count("cw_shelf")==0)
   var h:=row()
   button(tr("Lamp uit"),furnish.bind("lamp",0),"off",GameState.count("cw_lamp")==0,h,212)
   button(tr("Warm licht"),furnish.bind("lamp",1),"warm",GameState.count("cw_lamp")==0,h,212)
   button(tr("Zeelicht"),furnish.bind("lamp",2),"sea",GameState.count("cw_lamp")==0,h,212)
   button(tr("Wandrekrecept · werkbank"),recipe.bind("cw_shelf"),"shelf_recipe")
   button(tr("Lamprecept · Lena"),recipe.bind("cw_lamp"),"lamp_recipe")
  "line":
   title.text=tr("Herbruikbare oeverlijn")
   detail.text=tr("Nodig: Rafs oeverlijn, gemaakt in de havenwerkplaats. De lijn wordt niet verbruikt en werkt aan beide palen. Zonder lijn neem je de hoge rivierbrug. De korte oversteek is af te breken; er verdwijnen geen spullen of stamina.")
   button(tr("Steek over · lijn blijft bij je"),start_crossing,"cross",GameState.count("cw_hook")==0 or crossing)
  "practice":
   title.text=tr("Kuststijlen · vrije proefopstelling")
   detail.text=tr("Draag je eigen banden. Houd %s vast en gebruik %s voor de ankerwacht, of %s voor de boogwaaier. Na een tijdige frontale blokkade: druk gewoon op zwaard voor de tegenstoot. De poppen doen geen schade en geven geen buit of XP. Tijdens de proef leen je pijlen; een eigen boog blijft nodig.") % [Controls.action_label("technique"),Controls.action_label("attack"),Controls.action_label("bow")]
   button(tr("Start vrije proef · leenpijlen, geen XP"),start_practice,"practice")
 button(tr("Annuleren") if crossing else tr("Sluiten"),close,"close")
 var focusable: Array[Control]=[];var focus: Button
 for b in buttons:
  if crossing and b.get_meta("action")!="close":b.disabled=true
  if not b.disabled:
   focusable.append(b)
   if b.get_meta("action")==focus_id:focus=b
 Style.link_vertical(focusable);device_changed(Controls.controller_active);layout()
 if focus==null and not focusable.is_empty():focus=focusable[0] as Button
 if focus!=null:focus.grab_focus()
func build_storage():
 title.text=tr("Materiaalkist · %d/%d soorten") % [GameState.coastal_storage.size(),Home.SLOTS]
 detail.text=tr("Alleen materialen, maximaal 99 per soort. Binnen bereik gebruiken recepten eerst je tas en daarna deze kist. Zoek en sorteer via Voorraad in je tasmenu.")
 var h:=row()
 var into:=button(tr("Tas → kist"),direction.bind(true),"deposit",false,h,322);into.modulate=Color("eed19a") if deposit else Color("9fb9bc")
 var out:=button(tr("Kist → tas"),direction.bind(false),"withdraw",false,h,322);out.modulate=Color("9fb9bc") if deposit else Color("eed19a")
 var list: Array[String]=[]
 var stock: Dictionary=GameState.inventory if deposit else GameState.coastal_storage
 for item: String in Items.ITEMS:
  if Home.allowed(item) and int(stock.get(item,0))>0:list.append(item)
 index=clampi(index,0,maxi(0,(list.size()-1)/4))
 if selected not in list:selected=list[index*4] if not list.is_empty() else ""
 for item: String in list.slice(index*4,index*4+4):
  var label: String=("%s  " % ("●" if item==selected else "○"))+tr(Items.info(item).name)+tr(" · tas %d · kist %d") % [GameState.count(item),Home.count(item)]
  button(label,pick.bind(item),"item_"+item)
 if list.is_empty():button(tr("Hier zijn geen materialen"),func():pass,"empty",true)
 var pages:=row()
 button(tr("Vorige"),turn.bind(-1),"previous",index==0,pages,322);button(tr("Volgende"),turn.bind(1),"next",(index+1)*4>=list.size(),pages,322)
 var amount: int=Home.movable(selected,deposit)
 var moves:=row()
 button(tr("Verplaats 1"),move.bind(1),"move1",amount<1,moves,212)
 button(tr("Verplaats 5"),move.bind(5),"move5",amount<5,moves,212)
 button(tr("Verplaats %d") % amount,move.bind(amount),"moveall",amount<1,moves,212)
func show_page(value: String):page=value;rebuild()
func direction(value: bool):deposit=value;index=0;selected="";rebuild("deposit" if value else "withdraw")
func pick(item: String):selected=item;rebuild("item_"+item)
func turn(amount: int):index+=amount;selected="";rebuild("previous" if amount<0 else "next")
func move(amount: int):
 if not valid() or page!="storage":return
 if Home.transfer(selected,amount,deposit):Sound.play("cw_stow",-10)
 rebuild("move1")
func furnish(kind: String,mode: int):
 if not valid() or page!="layout":return
 if Home.set_furniture(kind,mode):Sound.play("cw_thread",-12)
 rebuild("shelf" if kind=="shelf" else "off" if mode==0 else "warm" if mode==1 else "sea")
func recipe(id: String):
 if not valid():return
 close()
 world.crafting_ui.selected_skill="";world.crafting_ui.selected_entry=id;world.crafting_ui.supplies=false
 world.crafting_ui.open.call_deferred(id)
func enter_workshop():
 if not valid() or page!="door":return
 close();world.travel("coast_workshop","start")
func start_practice():
 if not valid() or GameState.map_id!="coast_workshop":return
 for n in get_tree().get_nodes_in_group("coastal_practice"):
  if not n.is_queued_for_deletion():n.start();close();return
 var practice: Node2D=load("res://scripts/entities/coastal_practice.gd").new();practice.world=world;world.ground.add_child(practice);practice.start();close()
func start_crossing():
 if not valid() or page!="line" or GameState.map_id!="river_mouth" or GameState.count("cw_hook")==0 or crossing:return
 var node: Node2D=source.get_ref();landing=Vector2(node.obj.landing[0],node.obj.landing[1])*32+Vector2(16,44)
 if not world.spawn_fits(landing):GameState.toast.emit(tr("De landingsplek is bezet. De hoge brug blijft open."));return
 crossing=true;elapsed=0;world.player.start_work_animation("foraging",1.2,node.position);Sound.play("cw_thread",-8);rebuild("close")
func _process(delta: float):
 if not active:return
 if not valid():close();return
 if crossing:
  if Input.get_vector("move_left","move_right","move_up","move_down").length()>.2 or GameState.count("cw_hook")==0:close();return
  elapsed+=delta;world.player.work_elapsed=elapsed;world.player.queue_redraw();preview.queue_redraw()
  if elapsed>=1.2:
   if world.spawn_fits(landing):
    world.player.position=landing;world.player.velocity=Vector2.ZERO;world.player.knockback=Vector2.ZERO;world.player.camera.reset_smoothing();world.player.invuln=maxf(world.player.invuln,1.25)
    close();GameState.save_requested.emit();return
   close();return
 layout()
func draw_crossing():
 if page!="line":return
 preview.draw_rect(Rect2(Vector2.ZERO,preview.size),Color("285461"))
 preview.draw_line(Vector2(70,64),Vector2(580,64),Color("dbc597"),2)
 for x in [70,580]:preview.draw_circle(Vector2(x,65),20,Color("859b7d"))
 var progress: float=clampf(elapsed/1.2,0,1) if crossing else 0
 var pos:=Vector2(70+progress*510,45-sin(progress*PI)*16)
 preview.draw_circle(pos,8,Color("d7e6ce"));preview.draw_line(pos,Vector2(pos.x,62),Color("e6d5ac"),2)
func layout():
 panel.size=panel.get_combined_minimum_size()
 var size:=get_viewport().get_visible_rect().size
 var factor:=minf(1,minf((size.x-32)/panel.size.x,(size.y-32)/panel.size.y))
 panel.scale=Vector2.ONE*factor;panel.position=(size-panel.size*factor)*.5
func device_changed(_pad: bool):
 for b in buttons:b.mouse_filter=Control.MOUSE_FILTER_IGNORE if Controls.controller_active else Control.MOUSE_FILTER_STOP
func language_changed(_locale: String):
 if active:rebuild()
func bindings_changed():
 if active and page=="practice":rebuild()
func _unhandled_input(event: InputEvent):
 if not active or Engine.get_process_frames()<=opened_frame or not Controls.allows_event(event):return
 if event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
 elif Style.activate_focused(root,event):get_viewport().set_input_as_handled()
func close():
 if not active:return
 active=false
 if crossing and is_instance_valid(world.player):world.player.cancel_work_animation()
 crossing=false;GameState.set_ui("coastal_home",false);root.hide();queue_free()
func _exit_tree():
 if active:GameState.set_ui("coastal_home",false)
 if crossing and is_instance_valid(world.player):world.player.cancel_work_animation()
