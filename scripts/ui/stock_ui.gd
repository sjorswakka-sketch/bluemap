extends CanvasLayer
## Native focusable stock ledger; no world construction or remote material access.
const Stock:=preload("res://scripts/core/stockroom.gd")
const Items:=preload("res://scripts/data/items.gd")
const Style:=preload("res://scripts/core/ui_style.gd")
const Journal:=preload("res://scripts/core/craft_journal.gd")
signal closed
var world: Node2D
var active:=false
var kind:="home"
var map_id:=""
var panel: PanelContainer
var box: VBoxContainer
var search: LineEdit
var categories: OptionButton
var ordering: OptionButton
var favorites: CheckButton
var bag: ItemList
var chest: ItemList
var detail: Label
var status: Label
var hint: Label
var bag_title: Label
var chest_title: Label
var message: Label
var keyboard: VBoxContainer
var bag_ids: Array[String]=[]
var chest_ids: Array[String]=[]
var selected:=""
var deposit:=true
var transfer_buttons: Array[Button]=[]
var bulk_buttons: Array[Button]=[]
var star: Button
var last_near:=""
var born:=0
func _ready():
 layer=17;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("stock_ui")
 var shade:=ColorRect.new();shade.color=Color(0.025,0.045,0.05,.86);shade.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(shade)
 panel=PanelContainer.new();add_child(panel)
 var skin:=StyleBoxFlat.new();skin.bg_color=Color("182d2b");skin.border_color=Color("96b8a1")
 skin.set_border_width_all(2);skin.content_margin_left=22;skin.content_margin_right=22;skin.content_margin_top=18;skin.content_margin_bottom=18
 panel.add_theme_stylebox_override("panel",skin)
 box=VBoxContainer.new();box.add_theme_constant_override("separation",10);panel.add_child(box)
 var head:=HBoxContainer.new();box.add_child(head)
 var title:=Style.make_label(tr("Voorraad & opslag"),27,Color("e7d4a2"));title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
 button(head,tr("Sluiten"),close)
 hint=label(box,"",15,Color("b9d4c5"))
 var filters:=HBoxContainer.new();filters.add_theme_constant_override("separation",8);box.add_child(filters)
 search=LineEdit.new();search.placeholder_text=tr("Zoek een voorwerp…");search.custom_minimum_size=Vector2(245,38);search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(search)
 search.text_changed.connect(func(_v):refresh())
 button(filters,tr("Letters"),toggle_keyboard)
 categories=OptionButton.new();filters.add_child(categories)
 for name in [tr("Alles"),tr("Grondstoffen"),tr("Landbouw"),tr("Eten & drinken"),tr("Gereedschap & uitrusting"),tr("Verhaal & sleutels")]:categories.add_item(name)
 categories.item_selected.connect(func(_i):refresh())
 ordering=OptionButton.new();filters.add_child(ordering)
 for name in [tr("Volgorde: gevonden"),tr("Volgorde: categorie"),tr("Volgorde: naam"),tr("Volgorde: aantal")]:ordering.add_item(name)
 ordering.selected=Stock.state().sort
 ordering.item_selected.connect(func(i):Stock.state().sort=i;GameState.save_requested.emit();refresh())
 favorites=CheckButton.new();favorites.text=tr("Favorieten");filters.add_child(favorites);favorites.toggled.connect(func(_v):refresh())
 keyboard=VBoxContainer.new();keyboard.visible=false;box.add_child(keyboard)
 var letters:=GridContainer.new();letters.columns=13;keyboard.add_child(letters)
 for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
  var key:=button(letters,letter,write_letter.bind(letter));key.custom_minimum_size=Vector2(60,36)
 var edits:=HBoxContainer.new();keyboard.add_child(edits)
 button(edits,tr("Spatie"),write_letter.bind(" "))
 button(edits,tr("Wis letter"),erase_letter)
 button(edits,tr("Wis zoekveld"),clear_search)
 button(edits,tr("Klaar"),toggle_keyboard)
 var panes:=HBoxContainer.new();panes.add_theme_constant_override("separation",16);box.add_child(panes)
 for side in range(2):
  var col:=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panes.add_child(col)
  var title_label:=label(col,"",18,Color("e7d4a2"))
  var list:=ItemList.new();list.custom_minimum_size=Vector2(460,205);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.fixed_icon_size=Vector2i(24,24);list.add_theme_font_size_override("font_size",18);col.add_child(list)
  list.item_selected.connect(select_item.bind(side==0));list.item_activated.connect(func(_i):move(1))
  if side==0:bag=list;bag_title=title_label
  else:chest=list;chest_title=title_label
 detail=label(box,"",17,Color("eff0d6"));detail.custom_minimum_size=Vector2(940,82)
 var actions:=HBoxContainer.new();box.add_child(actions)
 for n in [1,10,0]:transfer_buttons.append(button(actions,tr("Verplaats 1") if n==1 else tr("Verplaats 10") if n==10 else tr("Verplaats hele stapel"),move.bind(n)))
 star=button(actions,tr("Favoriet"),toggle_favorite)
 var bulk:=HBoxContainer.new();box.add_child(bulk)
 bulk_buttons.append(button(bulk,tr("Bestaande stapels aanvullen"),bulk_move.bind(true)))
 bulk_buttons.append(button(bulk,tr("Grondstoffen opbergen"),bulk_move.bind(false)))
 status=label(box,"",15,Color("b9d4c5"))
 message=label(box,tr("Favorieten blijven bij bulkacties bij je; een gekozen recept mag ze wel gebruiken."),15,Color("d2c5a6"))
 refresh()
func label(parent: Node,text: String,font: int,color: Color) -> Label:
 var value:=Style.make_label(text,font,color);value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(value);return value
func button(parent: Node,text: String,action: Callable) -> Button:
 var b:=Button.new();b.text=text;b.custom_minimum_size.y=36;b.add_theme_font_size_override("font_size",16);b.pressed.connect(action);parent.add_child(b);return b
func open(store: String="home"):
 if GameState.input_locked():queue_free();return
 kind=store;map_id=GameState.map_id;active=true;born=Engine.get_process_frames();GameState.set_ui("stockroom",true)
 refresh();bag.grab_focus()
func close():
 if not active:return
 active=false;GameState.set_ui("stockroom",false);closed.emit();queue_free()
func _process(_delta: float):
 if not active:return
 if not is_instance_valid(world) or GameState.map_id!=map_id or GameState.transitioning or GameState.ended:close();return
 var near:=Stock.nearby_kind()
 if near!=last_near:refresh()
 panel.reset_size()
 var size:=panel.get_combined_minimum_size();var view:=get_viewport().get_visible_rect().size
 var scale_factor:=maxf(.1,minf(1.0,minf((view.x-32)/size.x,(view.y-32)/size.y)))
 panel.scale=Vector2.ONE*scale_factor;panel.position=(view-size*scale_factor)/2
func refresh():
 if bag==null:return
 last_near=Stock.nearby_kind()
 bag_ids=Stock.ids(GameState.inventory,search.text,categories.selected,favorites.button_pressed)
 chest_ids=Stock.ids(Stock.stock(kind),search.text,categories.selected,favorites.button_pressed)
 bag.clear();chest.clear()
 for id in bag_ids:bag.add_item(("%s%s  ×%d" % ["★ " if Stock.favorite(id) else "",tr(Items.info(id).name),GameState.count(id)]),Items.icon_tex(id))
 for id in chest_ids:chest.add_item(("%s%s  ×%d" % ["★ " if Stock.favorite(id) else "",tr(Items.info(id).name),Stock.count(id,kind)]),Items.icon_tex(id))
 bag_title.text=tr("Bij je · %d soorten") % bag_ids.size()
 chest_title.text=(tr("Huisvoorraad · %d/48 soorten · 999 per stapel") if kind=="home" else tr("Havenkist · %d/12 soorten · 99 per stapel")) % Stock.stock(kind).size()
 hint.text=tr("Binnen bereik: recepten en wijnvaten gebruiken eerst je tas, daarna deze kist.") if last_near==kind else tr("Je bekijkt de voorraad op afstand. Verplaatsen en maken uit deze kist kan alleen ter plaatse.")
 for b in bulk_buttons:b.disabled=last_near!=kind
 var ids: Array[String]=bag_ids if deposit else chest_ids
 if not ids.has(selected):selected=""
 if selected!="":
  (bag if deposit else chest).select(ids.find(selected))
  (bag if deposit else chest).ensure_current_is_visible()
 update_detail()
func select_item(index: int,from_bag: bool):
 deposit=from_bag
 var ids: Array[String]=bag_ids if deposit else chest_ids
 if index<0 or index>=ids.size():return
 selected=ids[index];(bag if deposit else chest).select(index);(chest if deposit else bag).deselect_all();update_detail()
func update_detail():
 var n:=Stock.movable(selected,deposit,kind) if selected!="" else 0
 for i in range(transfer_buttons.size()):transfer_buttons[i].disabled=n<([1,10,1][i])
 star.disabled=selected==""
 star.text=tr("Favoriet verwijderen") if selected!="" and Stock.favorite(selected) else tr("Favoriet bewaren")
 if selected=="":
  detail.text=tr("Kies links wat je wilt opbergen, of rechts wat je wilt meenemen. Zoek en filter beide lijsten tegelijk.")
  status.text=tr("Selectie bevestigen: 1 verplaatsen · Tab of richtingstoetsen: navigeren · terug: sluiten")
  return
 detail.text="%s\n%s\n%s" % [tr(Items.info(selected).name),tr(Items.info(selected).get("desc","")),Journal.uses_text(selected)]
 status.text=(tr("Opbergen → kist · bij je %d · opgeslagen %d · nu verplaatsbaar %d") if deposit else tr("Meenemen → tas · bij je %d · opgeslagen %d · nu verplaatsbaar %d")) % [GameState.count(selected),Stock.count(selected,kind),n]
 if not Stock.allowed(selected):status.text=tr("Dit voorwerp blijft bij je: uitrusting, gereedschap en verhaalvoorwerpen worden niet opgeslagen.")
func move(amount: int):
 if not active or GameState.map_id!=map_id:return
 var n:=Stock.movable(selected,deposit,kind)
 if amount==0:amount=n
 if Stock.transfer(selected,amount,deposit,kind):
  message.text=tr("%d verplaatst.") % amount;Sound.play("select",-10);refresh()
func bulk_move(existing: bool):
 if not active or GameState.map_id!=map_id:return
 var n:=Stock.bulk(existing,kind)
 if n>0:Sound.play("select",-10)
 message.text=tr("%d verplaatst. Favorieten zijn overgeslagen.") % n;refresh()
func toggle_favorite():
 if selected=="":return
 Stock.toggle_favorite(selected);refresh()
func toggle_keyboard():
 keyboard.visible=not keyboard.visible
 detail.visible=not keyboard.visible
 if keyboard.visible:keyboard.get_child(0).get_child(0).grab_focus()
 else:bag.grab_focus()
func write_letter(letter: String):search.text+=letter;refresh()
func erase_letter():search.text=search.text.left(-1);refresh()
func clear_search():search.text="";refresh()
func _unhandled_input(event: InputEvent):
 if not active or Engine.get_process_frames()==born or not Controls.allows_event(event):return
 if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("menu"):
  get_viewport().set_input_as_handled()
  if keyboard.visible:toggle_keyboard()
  else:close()

func _exit_tree():
 if active:GameState.set_ui("stockroom",false)
