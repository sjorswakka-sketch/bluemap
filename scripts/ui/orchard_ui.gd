extends CanvasLayer
const Farm:=preload("res://scripts/core/homestead.gd")
const Core:=preload("res://scripts/core/orchard.gd")
const Data:=preload("res://scripts/data/orchard_catalog.gd")
const Items:=preload("res://scripts/data/items.gd")
const Style:=preload("res://scripts/core/ui_style.gd")
var world: Node2D
var active:=false
var born:=-1
var origin_map:=""
var ids: Array[String]=["carrot","pumpkin","mint","rosemary","apple","berry","grape","flower"]
var crop_id:="carrot"
var panel: PanelContainer
var list: ItemList
var title: Label
var description: RichTextLabel
var card: Control
var info: Label
var status: Label
var coins: Label
var plant_button: Button
var buy_one: Button
var buy_five: Button
var starter_button: Button
var hint: Label
func label(parent: Node,text: String,font: int) -> Label:
 var l:=Style.make_label(text,font,Color("dfe4c8"));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.y=font+8;parent.add_child(l);return l
func button(parent: Node,text: String,action: Callable) -> Button:
 var b:=Button.new();Style.style_button(b,17);b.text=text;b.custom_minimum_size=Vector2(0,34);b.pressed.connect(action)
 for kind in ["normal","hover","pressed","disabled","focus"]:
  var skin: StyleBoxFlat=b.get_theme_stylebox(kind).duplicate();skin.content_margin_top=4;skin.content_margin_bottom=4;b.add_theme_stylebox_override(kind,skin)
 parent.add_child(b);return b
func _ready():
 layer=19;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("orchard_ui")
 var shade:=ColorRect.new();shade.color=Color(.03,.055,.035,.93);shade.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(shade)
 panel=PanelContainer.new();Style.style_panel(panel);add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",7);panel.add_child(box)
 label(box,tr("Zadenboek · gewassen en boomgaard"),26)
 var body:=HBoxContainer.new();body.add_theme_constant_override("separation",14);box.add_child(body)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=265;body.add_child(left)
 list=ItemList.new();list.custom_minimum_size=Vector2(265,240);list.add_theme_font_size_override("font_size",18);left.add_child(list)
 for id: String in ids:list.add_item(crop_name(id))
 list.item_selected.connect(choose);list.item_activated.connect(func(_i):plant_button.grab_focus())
 coins=label(left,"",17);starter_button=button(left,tr("Gratis beginpakket"),starter)
 var right:=VBoxContainer.new();right.custom_minimum_size.x=440;body.add_child(right)
 title=label(right,"",22);card=load("res://scripts/ui/orchard_card.gd").new();right.add_child(card)
 info=label(right,"",16);info.custom_minimum_size.x=440
 description=RichTextLabel.new();description.custom_minimum_size=Vector2(440,105);description.add_theme_font_size_override("normal_font_size",17);description.focus_mode=Control.FOCUS_ALL;right.add_child(description)
 status=label(box,"",16);status.custom_minimum_size=Vector2(720,36)
 var actions:=HBoxContainer.new();box.add_child(actions)
 plant_button=button(actions,tr("Kies plantstand"),plant);buy_one=button(actions,"",buy.bind(1));buy_five=button(actions,"",buy.bind(5))
 button(actions,tr("Oogststand"),harvest);button(actions,tr("Sluiten"),close)
 hint=label(box,"",14)
func crop_name(id: String) -> String:
 return tr(Data.NAMES[id]) if Data.NAMES.has(id) else tr("Druivenstok") if id=="grape" else tr("Bloemen")
func open():
 if GameState.input_locked() or GameState.ended or GameState.transitioning or GameState.map_id not in ["village","player_home"]:queue_free();return
 origin_map=GameState.map_id;active=true;born=Engine.get_process_frames();GameState.set_ui("orchard",true);choose(0);list.grab_focus()
func choose(index: int):
 if not active or index<0 or index>=ids.size():return
 crop_id=ids[index];list.select(index);refresh()
func refresh():
 if not active:return
 var data: Dictionary=Data.CROPS[crop_id];title.text=crop_name(crop_id)+( " · "+tr(Data.GROUPS[int(data.group)]) if data.has("group") else "");card.crop_id=crop_id;card.queue_redraw()
 var repeat: float=float(data.get("regrow",data.seconds))
 info.text=tr("Eerste groei %.0f s · daarna %.0f s · bij je: %d") % [data.seconds,repeat,GameState.count(data.seed)]
 info.text+="\n"+tr("Oogst %d · bemest %d · waterbereik %d tegel(s)") % [data.yield,int(data.yield)+int(data.get("bonus",0)),2 if crop_id=="apple" else 1]
 if crop_id=="flower":info.text=tr("Blijvende bloemen · 60 s groei · voedsel voor bijen")
 description.text=tr(Data.NOTES[crop_id]) if Data.NOTES.has(crop_id) else tr(Items.info(data.seed).desc)
 if Data.NAMES.has(crop_id):
  description.text+="\n"+tr("Product: %s") % tr(Items.info(data.output).name)
  if crop_id in ["carrot","pumpkin"]:description.text+=" · "+tr("Tuinstoofpot in de herberg")
  elif crop_id=="mint":description.text+=" · "+tr("Muntthee in de herberg")
  elif crop_id=="rosemary":description.text+=" · "+tr("Balsem in de bibliotheek")
 coins.text=tr("Munten: %d") % GameState.coins
 plant_button.disabled=GameState.map_id!="village" or GameState.count("hs_hoe")==0 or GameState.count(data.seed)==0
 buy_one.text=tr("Koop 1 · %d munten") % Data.PRICES[crop_id];buy_five.text=tr("Koop 5 · %d munten") % (Data.PRICES[crop_id]*5)
 buy_one.disabled=Core.buy_reason(crop_id,1)!="";buy_five.disabled=Core.buy_reason(crop_id,5)!=""
 starter_button.disabled=GameState.flag("or_starter") or Core.supply_reason()!=""
 for item: String in Data.STARTER:
  if GameState.room(item)<Data.STARTER[item]:starter_button.disabled=true
 starter_button.tooltip_text=tr("Eenmalig: twee van elke groente en kruid, één appelboompje en één bosbessenstek.")
 status.text=Core.supply_reason()
 if status.text=="":status.text=tr("Koop bij de tuingids. Groenten geven zaad terug; kruiden en fruit blijven staan.")
 hint.text=tr("%s lijst · %s plantknop · richting en bevestigen · Esc/B sluiten") % [Controls.action_label("ui_prev_tab"),Controls.action_label("ui_next_tab")]
func starter():
 if active and Core.starter():refresh();Sound.play("select",-12)
func buy(n: int):
 if active and Core.buy(crop_id,n):refresh();Sound.play("select",-12)
func set_mode(mode: String):
 if not active or GameState.map_id!="village" or GameState.count("hs_hoe")==0:return
 Farm.mode=mode;close()
 for n in get_tree().get_nodes_in_group("homesteads"):n.cooldown=.3;n.waiting_release=Input.is_action_pressed("interact");n.clear_stroke()
func plant():
 if not plant_button.disabled:set_mode(crop_id)
func harvest():set_mode("harvest")
func close():
 if not active:return
 active=false;GameState.set_ui("orchard",false);queue_free()
func _exit_tree():
 if active:GameState.set_ui("orchard",false)
func _process(_delta: float):
 if not active:return
 if not is_instance_valid(world) or GameState.map_id!=origin_map or GameState.transitioning or GameState.ended:close();return
 panel.reset_size();var dims:=panel.get_combined_minimum_size();var screen:=get_viewport().get_visible_rect().size
 var factor:=minf(1.0,minf((screen.x-28)/dims.x,(screen.y-28)/dims.y));panel.scale=Vector2.ONE*factor;panel.position=(screen-dims*factor)/2
func _unhandled_input(event: InputEvent):
 if not active or event.is_echo() or Engine.get_process_frames()==born or not Controls.allows_event(event):return
 if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("homestead"):get_viewport().set_input_as_handled();close()
 elif event.is_action_pressed("ui_prev_tab"):get_viewport().set_input_as_handled();list.grab_focus()
 elif event.is_action_pressed("ui_next_tab"):get_viewport().set_input_as_handled();plant_button.grab_focus()
 elif Style.activate_focused(panel,event):get_viewport().set_input_as_handled()
