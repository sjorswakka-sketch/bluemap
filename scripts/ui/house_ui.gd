extends CanvasLayer
const House:=preload("res://scripts/core/personal_home.gd")
const Catalog:=preload("res://scripts/data/house_catalog.gd")
const Paint:=preload("res://scripts/core/house_art.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
const Items:=preload("res://scripts/data/items.gd")
const Style:=preload("res://scripts/core/ui_style.gd")
var world: Node2D
var active:=false
var draft: Dictionary={}
var panel: PanelContainer
var list: ItemList
var detail: RichTextLabel
var plan: Control
var tint: OptionButton
var floors: OptionButton
var walls: OptionButton
var lighting: OptionButton
var placed: OptionButton
var kind:="chair"
var editing_id:=""
var cursor:=Vector2i(4,9)
var catalog_ids: Array[String]=[]
var placed_ids: Array[String]=[]
var make_button: Button
var place_button: Button
var pack_button: Button
var status: Label
var counter: Label
var footer: Label
var born:=-1
func _ready():
 layer=19;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("house_ui")
 var shade:=ColorRect.new();shade.color=Color(.025,.04,.045,.9);shade.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(shade)
 panel=PanelContainer.new();Style.style_panel(panel);add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",7);panel.add_child(box)
 var title:=Style.make_label(tr("Je huis · rustig inrichten"),26,Color("e4cca2"));box.add_child(title)
 var body:=HBoxContainer.new();body.add_theme_constant_override("separation",14);box.add_child(body)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=330;body.add_child(left)
 label(left,tr("Meubelvoorraad · kiezen of verplaatsen"),17)
 list=ItemList.new();list.custom_minimum_size=Vector2(330,170);list.fixed_icon_size=Vector2i(30,30);list.add_theme_font_size_override("font_size",17);left.add_child(list)
 list.item_selected.connect(select_kind);list.item_activated.connect(func(_i):plan.grab_focus())
 var select_row:=HBoxContainer.new();left.add_child(select_row)
 tint=option(select_row,Catalog.COLORS,choose_tint);tint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 make_button=button(left,tr("Maak extra meubel"),make_piece)
 detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(330,80);detail.add_theme_font_size_override("normal_font_size",16);detail.add_theme_color_override("default_color",Color("d2dfcf"));detail.focus_mode=Control.FOCUS_ALL;left.add_child(detail)
 label(left,tr("Vloer, wand en verlichting · vrije keuze"),16)
 floors=option(left,Catalog.FLOORS,func(i):draft.floor=i;refresh_detail())
 walls=option(left,Catalog.WALLS,func(i):draft.wall=i;refresh_detail())
 lighting=option(left,Catalog.LIGHTS,func(i):draft.light=i;refresh_detail())
 var right:=VBoxContainer.new();body.add_child(right)
 placed=option(right,[],choose_placed);placed.custom_minimum_size.x=404
 plan=load("res://scripts/ui/house_plan.gd").new();plan.editor=self;right.add_child(plan)
 var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",6);right.add_child(actions)
 place_button=button(actions,tr("Bevestig plek"),place)
 pack_button=button(actions,tr("Berg meubel op"),pack)
 counter=label(right,"",15)
 status=label(box,"",16);status.custom_minimum_size=Vector2(800,36)
 var bottom:=HBoxContainer.new();bottom.add_theme_constant_override("separation",8);box.add_child(bottom)
 button(bottom,tr("Toepassen en opslaan"),apply)
 button(bottom,tr("Annuleren"),close)
 button(bottom,tr("Beginindeling bekijken"),reset_draft)
 footer=label(box,tr("Toepassen bewaart · Annuleren verwerpt · gemaakte meubels blijven in voorraad."),14)
 var navigation:=label(box,"",14);navigation.name="Navigation"
func label(parent: Node,text: String,font: int) -> Label:
 var l:=Style.make_label(text,font,Color("d6dfce"));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(l);return l
func button(parent: Node,text: String,action: Callable) -> Button:
 var b:=Button.new();Style.style_button(b,17);b.custom_minimum_size=Vector2(0,34);b.text=text;b.pressed.connect(action)
 for state_name in ["normal","hover","pressed","focus","disabled"]:
  var skin: StyleBoxFlat=b.get_theme_stylebox(state_name).duplicate();skin.content_margin_top=4;skin.content_margin_bottom=4;skin.content_margin_left=8;skin.content_margin_right=8;b.add_theme_stylebox_override(state_name,skin)
 parent.add_child(b);return b
func option(parent: Node,names: Array,action: Callable) -> OptionButton:
 var b:=OptionButton.new();b.add_theme_font_size_override("font_size",16);b.custom_minimum_size.y=30
 for text: String in names:b.add_item(tr(text))
 b.item_selected.connect(action);parent.add_child(b);return b
func open():
 if GameState.input_locked() or GameState.map_id!="player_home" or GameState.transitioning:queue_free();return
 draft=House.state().duplicate(true);active=true;born=Engine.get_process_frames();GameState.set_ui("personal_house",true)
 floors.selected=draft.floor;walls.selected=draft.wall;lighting.selected=draft.light
 refresh_catalog();select_kind(catalog_ids.find("chair"));list.grab_focus()
func close():
 if not active:return
 active=false;GameState.set_ui("personal_house",false);queue_free()
func _exit_tree():
 if active:GameState.set_ui("personal_house",false)
func _process(_delta: float):
 if not active:return
 if not is_instance_valid(world) or GameState.map_id!="player_home" or GameState.transitioning or GameState.ended:close();return
 var navigation: Label=footer.get_parent().get_node("Navigation")
 navigation.text=tr("%s lijst · %s plattegrond · klik/dubbelklik: kiezen/plaatsen · rechtsklik: meubel") % [Controls.action_label("ui_prev_tab"),Controls.action_label("ui_next_tab")]
 panel.reset_size();var dims:=panel.get_combined_minimum_size();var view:=get_viewport().get_visible_rect().size
 var factor:=maxf(.1,minf(1.0,minf((view.x-28)/dims.x,(view.y-28)/dims.y)));panel.scale=Vector2.ONE*factor;panel.position=(view-dims*factor)/2
func refresh_catalog():
 list.clear();catalog_ids.clear()
 for id: String in Catalog.PIECES:
  catalog_ids.append(id)
  var info: Dictionary=Catalog.PIECES[id]
  list.add_item("%s · %d" % [tr(info.name),int(House.state().owned.get(id,0))],Paint.icon(id))
 var index:=catalog_ids.find(kind)
 if index>=0:list.select(index);list.ensure_current_is_visible()
 refresh_placed()
func refresh_placed():
 placed.clear();placed_ids=[""]
 placed.add_item(tr("Kies een geplaatst meubel om te verplaatsen…"))
 for id: String in draft.layout:
  placed_ids.append(id);placed.add_item(tr(Catalog.PIECES[draft.layout[id].kind].name)+" · "+str(draft.layout[id].cell))
 if editing_id in placed_ids:placed.selected=placed_ids.find(editing_id)
func select_kind(index: int):
 if index<0 or index>=catalog_ids.size():return
 kind=catalog_ids[index];list.select(index)
 editing_id=House.next_id(kind,draft.layout)
 if editing_id=="":
  for id: String in draft.layout:
   if draft.layout[id].kind==kind:editing_id=id;cursor=House.rect(draft.layout[id]).position;tint.selected=int(draft.layout[id].tint);break
 if editing_id=="":editing_id=kind+":1"
 refresh_placed();refresh_detail()
func choose_placed(index: int):
 if index<=0 or index>=placed_ids.size():return
 editing_id=placed_ids[index];var entry: Dictionary=draft.layout[editing_id];kind=entry.kind
 cursor=House.rect(entry).position;tint.selected=int(entry.tint);list.select(catalog_ids.find(kind));refresh_detail();plan.grab_focus()
func pick_at(at: Vector2i):
 for id: String in draft.layout:
  if House.rect(draft.layout[id]).has_point(at) and not Catalog.PIECES[draft.layout[id].kind].get("floor",false):
   choose_placed(placed_ids.find(id));return
func choose_tint(index: int):
 if draft.layout.has(editing_id) and draft.layout[editing_id].kind==kind:draft.layout[editing_id].tint=index
 refresh_detail()
func proposal() -> Dictionary:return House.candidate(draft.layout,editing_id,kind,cursor,tint.selected)
func placement_reason() -> String:
 if kind=="":return tr("Kies eerst een meubel.")
 var next:=proposal()
 var reason:=House.layout_reason(next,House.state().owned)
 return reason if reason!="" else House.player_reason(next,world.player.position)
func refresh_detail():
 if not active or detail==null:return
 var info: Dictionary=Catalog.PIECES[kind]
 var lines: Array[String]=[tr(info.name)+" · "+tr("%d × %d tegels") % [info.size.x,info.size.y]]
 var count:=0
 for entry: Dictionary in draft.layout.values():
  if entry.kind==kind:count+=1
 lines.append(tr("In je meubelvoorraad: %d · geplaatst: %d") % [int(House.state().owned.get(kind,0)),count])
 if not House.unlocked(kind):lines.append(tr(info.get("hint","Nog niet ontdekt.")))
 if not info.cost.is_empty():
  var parts: Array[String]=[]
  for item: String in info.cost:parts.append("%s %d/%d" % [tr(Items.info(item).name),Stock.available(item),int(info.cost[item])])
  lines.append(tr("Maken: %s") % ", ".join(parts))
  lines.append(tr("Tas en bereikbare huisvoorraad.") if Stock.nearby_kind()=="home" else tr("Alleen je tas; loop dichter naar de huiskist voor opgeslagen materiaal."))
 lines.append(tr(info.desc))
 detail.text="\n".join(lines)
 make_button.disabled=House.make_reason(kind)!=""
 make_button.text=tr("Ontvang aandenken") if kind.begins_with("trophy_") else tr("Maak extra meubel")
 make_button.tooltip_text=House.make_reason(kind)
 place_button.disabled=placement_reason()!=""
 pack_button.disabled=not draft.layout.has(editing_id) or info.get("base",false)
 var reason:=placement_reason()
 status.text=reason if reason!="" else tr("Plek past. Pijltjes of stick verplaatsen de markering; bevestig om dit ontwerp aan te passen.")
 var solid:=0
 for entry: Dictionary in draft.layout.values():
  if not Catalog.PIECES[entry.kind].get("floor",false):solid+=House.rect(entry).get_area()
 counter.text=tr("Meubels %d/12 · vrije vloer %d/100") % [draft.layout.size(),100-House.fixed_cells().size()-solid]
 plan.queue_redraw()
func place():
 if not active or placement_reason()!="":return
 draft.layout=proposal();refresh_placed();refresh_detail();Sound.play("select",-12)
func pack():
 if not active or not draft.layout.has(editing_id) or Catalog.PIECES[kind].get("base",false):return
 draft.layout.erase(editing_id);editing_id=House.next_id(kind,draft.layout);refresh_placed();refresh_detail()
func make_piece():
 if not active or not House.make(kind):return
 draft.owned=House.state().owned.duplicate();refresh_catalog();select_kind(catalog_ids.find(kind));Sound.play("select",-10)
func apply():
 if not active:return
 var reason:=House.layout_reason(draft.layout,House.state().owned)
 if reason=="":reason=House.player_reason(draft.layout,world.player.position)
 if reason!="":status.text=reason;return
 if House.apply(draft,world):Sound.play("select",-8);close()
func reset_draft():
 draft=House.defaults();draft.owned=House.state().owned.duplicate();floors.selected=0;walls.selected=0;lighting.selected=0
 refresh_catalog();select_kind(catalog_ids.find(kind));status.text=tr("Beginindeling als ontwerp. Pas toe om deze te bewaren.")
func _unhandled_input(event: InputEvent):
 if not active or event.is_echo() or Engine.get_process_frames()==born or not Controls.allows_event(event):return
 if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("menu"):
  get_viewport().set_input_as_handled();close()
 elif event.is_action_pressed("ui_prev_tab"):
  get_viewport().set_input_as_handled();list.grab_focus()
 elif event.is_action_pressed("ui_next_tab"):
  get_viewport().set_input_as_handled();plan.grab_focus()
 elif Style.activate_focused(panel,event):get_viewport().set_input_as_handled()
