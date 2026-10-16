extends CanvasLayer
const Yard:=preload("res://scripts/core/yard.gd")
const Data:=preload("res://scripts/data/yard_catalog.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
const Items:=preload("res://scripts/data/items.gd")
const Style:=preload("res://scripts/core/ui_style.gd")
var world: Node2D
var active:=false
var draft: Dictionary={}
var kind:="wine_a"
var cursor:=Vector2i(4,25)
var start:=Vector2i(-99,-99)
var reason_text:=""
var panel: PanelContainer
var list: ItemList
var detail: RichTextLabel
var view: OptionButton
var extension: OptionButton
var row_mode: CheckButton
var plan: Control
var place_button: Button
var pack_button: Button
var make_button: Button
var expand_button: Button
var status: Label
var counts: Label
var navigation: Label
var ids: Array[String]=[]
var extension_ids: Array[String]=[]
var candidate: Dictionary={}
var born:=-1
func _ready():
 layer=19;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("yard_ui")
 var shade:=ColorRect.new();shade.color=Color(.025,.05,.04,.91);shade.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(shade)
 panel=PanelContainer.new();Style.style_panel(panel);add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",7);panel.add_child(box)
 label(box,tr("Je erf · ruimte om te groeien"),25)
 var body:=HBoxContainer.new();body.add_theme_constant_override("separation",12);box.add_child(body)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=300;body.add_child(left)
 list=ItemList.new();list.custom_minimum_size=Vector2(300,170);list.add_theme_font_size_override("font_size",17);left.add_child(list)
 for id: String in Data.UNITS:ids.append(id);list.add_item(tr(Data.UNITS[id].name))
 for id: String in Data.PIECES:ids.append(id);list.add_item(tr(Data.PIECES[id].name))
 list.item_selected.connect(choose);list.item_activated.connect(func(_i):plan.grab_focus())
 row_mode=CheckButton.new();row_mode.text=tr("Rechte rij vanaf vorige plek");row_mode.add_theme_font_size_override("font_size",16);left.add_child(row_mode);row_mode.toggled.connect(func(_v):start=Vector2i(-99,-99);refresh_detail())
 make_button=button(left,tr("Maak bouwdelen"),make_parts)
 detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(300,90);detail.add_theme_font_size_override("normal_font_size",16);detail.focus_mode=Control.FOCUS_ALL;left.add_child(detail)
 extension=OptionButton.new();extension.add_theme_font_size_override("font_size",16);left.add_child(extension)
 for id: String in Data.EXTENSIONS:extension_ids.append(id);extension.add_item(tr(Data.EXTENSIONS[id].name))
 extension.item_selected.connect(func(_i):refresh_detail())
 expand_button=button(left,tr("Ontsluit bouwruimte"),expand)
 var right:=VBoxContainer.new();body.add_child(right)
 view=OptionButton.new();view.add_theme_font_size_override("font_size",16);view.custom_minimum_size.y=28
 for text: String in Data.VIEW_NAMES:view.add_item(tr(text))
 right.add_child(view);view.item_selected.connect(change_view)
 plan=load("res://scripts/ui/yard_plan.gd").new();plan.editor=self;right.add_child(plan)
 var actions:=HBoxContainer.new();right.add_child(actions)
 place_button=button(actions,tr("Bevestig plek of rij"),place);pack_button=button(actions,tr("Opbergen op deze plek"),pack)
 counts=label(right,"",15)
 status=label(box,"",16);status.custom_minimum_size=Vector2(820,32)
 var actions2:=HBoxContainer.new();actions2.add_theme_constant_override("separation",8);box.add_child(actions2)
 button(actions2,tr("Toepassen en opslaan"),apply);button(actions2,tr("Annuleren"),close);button(actions2,tr("Beginerf bekijken"),reset_draft)
 label(box,tr("Toepassen bewaart het ontwerp. Gemaakte delen en ontsloten bouwruimte blijven na annuleren beschikbaar."),14)
 navigation=label(box,"",14)
func label(parent: Node,text: String,font: int) -> Label:
 var l:=Style.make_label(text,font,Color("dae1ce"));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.y=font+10;parent.add_child(l);return l
func button(parent: Node,text: String,action: Callable) -> Button:
 var b:=Button.new();Style.style_button(b,16);b.custom_minimum_size=Vector2(0,32);b.text=text;b.pressed.connect(action)
 for state_name in ["normal","hover","pressed","focus","disabled"]:
  var skin: StyleBoxFlat=b.get_theme_stylebox(state_name).duplicate();skin.content_margin_top=4;skin.content_margin_bottom=4;skin.content_margin_left=7;skin.content_margin_right=7;b.add_theme_stylebox_override(state_name,skin)
 parent.add_child(b);return b
func open():
 if GameState.input_locked() or GameState.map_id!="village" or GameState.transitioning:queue_free();return
 draft=Yard.state().duplicate(true);active=true;born=Engine.get_process_frames();GameState.set_ui("yard",true);choose(0);list.grab_focus()
func close():
 if not active:return
 active=false;GameState.set_ui("yard",false);queue_free()
func _exit_tree():
 if active:GameState.set_ui("yard",false)
func _process(_delta: float):
 if not active:return
 if not is_instance_valid(world) or GameState.map_id!="village" or GameState.transitioning or GameState.ended:close();return
 navigation.text=tr("%s lijst · %s plattegrond · richting en bevestigen · klik/dubbelklik: kiezen/plaatsen · rechtsklik: selecteren") % [Controls.action_label("ui_prev_tab"),Controls.action_label("ui_next_tab")]
 panel.reset_size();var dims:=panel.get_combined_minimum_size();var screen:=get_viewport().get_visible_rect().size
 var factor:=maxf(.1,minf(1.0,minf((screen.x-28)/dims.x,(screen.y-28)/dims.y)));panel.scale=Vector2.ONE*factor;panel.position=(screen-dims*factor)/2
func choose(index: int):
 if not active or index<0 or index>=ids.size():return
 kind=ids[index];list.select(index);start=Vector2i(-99,-99)
 if Data.UNITS.has(kind):
  var at:=Yard.anchor(kind,draft)
  if at.x>=0:
   cursor=at;view.selected=1 if at.y<23 else 0
 row_mode.disabled=Data.UNITS.has(kind);refresh_detail()
func change_view(_index: int):
 cursor=cursor.clamp(plan.region().position,plan.region().end-Vector2i.ONE);start=Vector2i(-99,-99);refresh_detail()
func stroke_cells() -> Array[Vector2i]:
 var out: Array[Vector2i]=[cursor]
 if Data.UNITS.has(kind) or not row_mode.button_pressed or start.x<0:return out
 var delta:=cursor-start
 if delta.x!=0 and delta.y!=0:return out
 out.clear();var step:=Vector2i(signi(delta.x),signi(delta.y))
 for i in range(mini(40,absi(delta.x)+absi(delta.y))+1):out.append(start+step*i)
 return out
func proposal() -> Dictionary:
 var next:=draft.duplicate(true)
 if Data.UNITS.has(kind):next.stations[kind]=[cursor.x,cursor.y]
 else:
  var field: String="paths" if Data.PIECES[kind].get("path",false) else "fences"
  for at: Vector2i in stroke_cells():next[field][Yard.key(at)]=kind
 return next
func refresh_detail():
 if not active:return
 draft.owned=Yard.state().owned.duplicate();draft.extensions=Yard.state().extensions.duplicate()
 candidate=proposal();reason_text=Yard.layout_reason(candidate,Yard.farm_cells(),Yard.state())
 if not Data.UNITS.has(kind) and row_mode.button_pressed and start.x>=0 and cursor.x!=start.x and cursor.y!=start.y:reason_text=tr("Een rij loopt recht; kies dezelfde rij of kolom.")
 if reason_text=="":reason_text=Yard.actor_reason(candidate,world.player.position)
 var lines: Array[String]=[]
 if Data.UNITS.has(kind):
  lines=[tr(Data.UNITS[kind].name),tr(Data.UNITS[kind].desc)]
  if kind=="hive":lines.push_front(tr("Bloemen op deze plek: %d / 3") % Yard.flower_count_at(cursor,Yard.farm_cells()))
  lines.append(tr("Opgeborgen; productie blijft bewaard.") if draft.stations[kind].is_empty() else tr("Bestaande werkplek · geen nieuwe machine"))
  make_button.disabled=true;make_button.text=tr("Maak bouwdelen")
  pack_button.disabled=draft.stations[kind].is_empty()
 else:
  var info: Dictionary=Data.PIECES[kind];var group: String=info.group;var supply: Dictionary=Data.SUPPLIES[group]
  lines=[tr(info.name),tr("Delen vrij: %d · totaal: %d") % [int(draft.owned[group])-Yard.used(draft,group),int(draft.owned[group])],cost_text(supply.cost),tr(info.desc)]
  make_button.disabled=Yard.material_reason(supply.cost)!="" or int(draft.owned[group])+int(supply.amount)>int(supply.cap)
  make_button.text=tr("Maak %d bouwdelen") % int(supply.amount)
  var field: String="paths" if info.get("path",false) else "fences"
  pack_button.disabled=not draft[field].has(Yard.key(cursor))
 detail.text="\n".join(lines)
 var ext: String=extension_ids[extension.selected]
 expand_button.disabled=ext in draft.extensions or Yard.material_reason(Data.EXTENSIONS[ext].cost)!=""
 expand_button.tooltip_text=tr(Data.EXTENSIONS[ext].desc)+"\n"+cost_text(Data.EXTENSIONS[ext].cost)
 expand_button.text=tr("Bouwruimte al beschikbaar") if ext in draft.extensions else tr("Ontsluit %s") % tr(Data.EXTENSIONS[ext].name)
 status.text=reason_text if reason_text!="" else tr("Plek past. Ontwerp eerst; pas toe als je tevreden bent.")
 counts.text=tr("Paden %d/80 · hek/poort %d/40 · uitbreiding: %s") % [draft.paths.size(),draft.fences.size(),tr(Data.EXTENSIONS[ext].name)+" · "+cost_text(Data.EXTENSIONS[ext].cost)]
 place_button.disabled=reason_text!=""
 plan.queue_redraw()
func cost_text(cost: Dictionary) -> String:
 var parts: Array[String]=[]
 for id: String in cost:parts.append("%s %d/%d" % [tr(Items.info(id).name),Stock.available(id),int(cost[id])])
 return " · ".join(parts)
func place():
 if not active or reason_text!="":return
 draft=candidate.duplicate(true);start=cursor;refresh_detail();Sound.play("select",-13)
func pack():
 if not active:return
 if Data.UNITS.has(kind):draft.stations[kind]=[]
 else:
  var field: String="paths" if Data.PIECES[kind].get("path",false) else "fences"
  draft[field].erase(Yard.key(cursor))
 start=Vector2i(-99,-99);refresh_detail()
func make_parts():
 if Data.UNITS.has(kind):return
 if active and Yard.make(Data.PIECES[kind].group):refresh_detail();Sound.play("select",-11)
func expand():
 if active and Yard.expand(extension_ids[extension.selected]):refresh_detail();Sound.play("select",-11)
func pick_at(at: Vector2i):
 for id: String in Data.UNITS:
  if Yard.anchor(id,draft).x>=0 and Yard.bounds(Yard.anchor(id,draft)).has_point(at):choose(ids.find(id));return
 var key:=Yard.key(at)
 if draft.fences.has(key):choose(ids.find(draft.fences[key]))
 elif draft.paths.has(key):choose(ids.find(draft.paths[key]))
 cursor=at;refresh_detail()
func apply():
 if not active:return
 var reason:=Yard.layout_reason(draft,Yard.farm_cells(),Yard.state())
 if reason=="":reason=Yard.actor_reason(draft,world.player.position)
 if reason!="":status.text=reason;return
 if Yard.apply(draft,world):Sound.play("select",-8);close()
func reset_draft():
 draft=Yard.defaults();draft.owned=Yard.state().owned.duplicate();draft.extensions=Yard.state().extensions.duplicate();start=Vector2i(-99,-99);refresh_detail()
func _unhandled_input(event: InputEvent):
 if not active or event.is_echo() or Engine.get_process_frames()==born or not Controls.allows_event(event):return
 if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("menu"):get_viewport().set_input_as_handled();close()
 elif event.is_action_pressed("ui_prev_tab"):get_viewport().set_input_as_handled();list.grab_focus()
 elif event.is_action_pressed("ui_next_tab"):get_viewport().set_input_as_handled();plan.grab_focus()
 elif Style.activate_focused(panel,event):get_viewport().set_input_as_handled()
