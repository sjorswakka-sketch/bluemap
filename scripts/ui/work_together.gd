extends CanvasLayer
## Two different, cancellable activities using existing crafting transactions.
const Style:=preload("res://scripts/core/ui_style.gd")
const Prof:=preload("res://scripts/core/professions.gd")
const Journal:=preload("res://scripts/core/craft_journal.gd")
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var director: Node2D
var root: Control
var panel: PanelContainer
var title: Label
var instruction: Label
var detail: Label
var preview: Control
var rail: HBoxContainer
var value_label: Label
var leaf_grid: GridContainer
var leaves: Array[Button]=[]
var left: Button
var right: Button
var primary: Button
var practice_button: Button
var back: Button
var active:=false
var stage:=0
var alignment:=-2
var pressure:=0
var selected: Array[int]=[]
var practice:=false
var working:=false
var finished:=false
var finishing:=false
var elapsed:=0.0
var time:=0.0
var opened_frame:=-1
var result:=""
func button(label: String,owner: Control,callback: Callable) -> Button:
	var b:=Button.new();Style.style_button(b,19);b.text=label;b.custom_minimum_size=Vector2(0,38)
	owner.add_child(b);b.pressed.connect(callback);return b
func _ready():
	layer=13;process_mode=Node.PROCESS_MODE_ALWAYS
	root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(root)
	var dim:=ColorRect.new();dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.color=Color(0.02,0.04,0.07,0.76);root.add_child(dim)
	panel=PanelContainer.new();Style.style_panel(panel);panel.custom_minimum_size=Vector2(740,0);root.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
	title=Style.make_label("",28,Color("edce98"));box.add_child(title)
	instruction=Style.make_label("",20);instruction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;instruction.custom_minimum_size.x=680;box.add_child(instruction)
	preview=Control.new();preview.custom_minimum_size=Vector2(0,94);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview.draw.connect(draw_preview);box.add_child(preview)
	rail=HBoxContainer.new();rail.add_theme_constant_override("separation",10);box.add_child(rail)
	left=button("◀",rail,adjust.bind(-1));left.custom_minimum_size.x=70;left.focus_mode=Control.FOCUS_NONE
	value_label=Style.make_label("",20);value_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;rail.add_child(value_label)
	right=button("▶",rail,adjust.bind(1));right.custom_minimum_size.x=70;right.focus_mode=Control.FOCUS_NONE
	for arrow in [left,right]:
		for connection in arrow.mouse_entered.get_connections():arrow.mouse_entered.disconnect(connection.callable)
	leaf_grid=GridContainer.new();leaf_grid.columns=2;leaf_grid.add_theme_constant_override("h_separation",10);leaf_grid.add_theme_constant_override("v_separation",6);box.add_child(leaf_grid)
	for i in 4:
		var b:=button("",leaf_grid,select_leaf.bind(i));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.icon=leaf_icon(i);b.add_theme_constant_override("icon_max_width",34);b.expand_icon=true;leaves.append(b)
	detail=Style.make_label("",18,Color("d5dfdf"));detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(680,80);box.add_child(detail)
	practice_button=button("",box,toggle_practice)
	primary=button("",box,act)
	back=button("",box,close)
	Controls.device_changed.connect(device_changed);Lang.changed.connect(language_changed)
	root.hide()
func leaf_icon(i: int) -> Texture2D:
	var atlas:=AtlasTexture.new();atlas.atlas=Art.tex("wt_leaves");atlas.region=Rect2(i*24,0,24,24);return atlas
func open():
	if active or not director.valid() or GameState.input_locked():return
	active=true;practice=false;opened_frame=Engine.get_process_frames();reset()
	GameState.set_ui("work_together",true);root.show();refresh();focus_start();fit()
func reset():
	stage=0;alignment=-2;pressure=0;selected.clear();working=false;finished=false;finishing=false;elapsed=0;result=""
	if director.kind=="smith":practice=GameState.flag("wt_smith_done")
func focus_start():
	if director.kind=="alchemy":leaves[0].grab_focus()
	else:primary.grab_focus()
func toggle_practice():
	if not active or working:return
	practice=not practice;reset();refresh();focus_start()
func adjust(direction: int):
	if not active or working or finished or director.kind!="smith":return
	if stage==0:alignment=clampi(alignment+direction,-3,3)
	elif stage==1:pressure=clampi(pressure+direction,0,2)
	result="";refresh();Sound.play("wt_clamp",-16)
func select_leaf(index: int):
	if not active or working or finished or stage!=0:return
	if index not in [0,3]:
		result=tr("Lena: dat blad is gekneusd of uitgedroogd. Leg het apart; kies twee hele bladeren.");Sound.play("error",-15)
	elif index in selected:selected.erase(index);result=""
	else:selected.append(index);result=""
	refresh()
	if selected.size()==2:primary.grab_focus()
func ready_to_finish() -> bool:
	if not active or working or finished:return false
	return stage==2 and alignment==0 and pressure==1 if director.kind=="smith" else stage==1 and selected.size()==2
func act():
	if not active or working or finishing:return
	if finished:reset();refresh();focus_start();return
	result=""
	if director.kind=="smith":
		if stage==0:
			if alignment!=0:result=tr("Greta: de naden sluiten nog niet aan. Schuif de losse bek naar de witte lijn.")
			else:stage=1
		elif stage==1:
			if pressure!=1:result=tr("Greta: los houdt niet; te strak klemt het proefstuk. Kies stevige druk.")
			else:begin_work()
	else:
		if not practice and Prof.craft_reason("potion")!="":result=Prof.craft_reason("potion")
		elif stage==0 and selected.size()==2:begin_work()
		elif stage==1:finish_work()
	refresh()
func begin_work():
	working=true;elapsed=0;Sound.play("wt_clamp" if director.kind=="smith" else "wt_grind",-13)
	refresh();back.grab_focus() # leaving remains possible during every animation
func finish_work():
	if finishing or not ready_to_finish():return
	finishing=true
	if director.complete():
		finished=true
		Sound.play("wt_clamp" if director.kind=="smith" else "wt_pour",-11)
	else:result=Prof.craft_reason("potion") if director.kind=="alchemy" else tr("Kom terug bij Greta's werkbank om verder te werken.")
	finishing=false;refresh()
	if finished:back.grab_focus()
func refresh():
	var smith: bool=director.kind=="smith"
	title.text=tr("Samenwerken met Greta") if smith else tr("Kruiden bereiden met Lena")
	if finished:
		instruction.text=tr("Het proefstuk is klaar. Je kunt de handelingen later opnieuw oefenen.") if practice else tr("De klem sluit nu recht. Greta blijft deze werkbank gebruiken.") if smith else tr("De kruiden zijn fijn gemengd. Lena's doseerrek staat klaar.")
	elif smith:
		instruction.text=tr("Schuif de losse bek naar de witte naad. Gebruik links/rechts of de pijlknoppen.") if stage==0 else tr("Stel de druk af: stevig houdt het proefstuk vast zonder het te pletten.")
	else:instruction.text=tr("Kies twee hele zilverkruidbladeren. De gekneusde en droge bladeren blijven opzij.") if stage==0 else tr("De pasta is klaar. Bottel pas wanneer je het drankje wilt maken.")
	rail.visible=smith and not finished;leaf_grid.visible=not smith and stage==0 and not finished
	left.disabled=working;right.disabled=working
	value_label.text=(tr("Naad: %d")%alignment) if stage==0 else [tr("Los"),tr("Stevig"),tr("Te strak")][pressure]
	var names: Array[String]=[tr("Heel blad A"),tr("Gekneusd blad"),tr("Droog blad"),tr("Heel blad B")]
	for i in leaves.size():leaves[i].text=("✓ " if i in selected else "")+names[i];leaves[i].disabled=working
	var reason:=Prof.craft_reason("potion") if not smith and not practice else ""
	if result!="":detail.text=result
	elif finished:
		if practice:detail.text=tr("Proefstuk klaar. Je tas, ervaring en beloningen zijn niet veranderd.")
		elif smith:detail.text=tr("Eerste herstel: 6 Smeden-XP en het slagbandenpatroon. Herhalen geeft geen extra ervaring; een bekend patroon wordt niet dubbel beloond.")
		else:detail.text=tr("Je hebt één drankje gebotteld met de gewone receptkosten en Alchemie-XP. De eerste bereiding leert ook Lena's richtlenspatroon.")
	elif smith:
		detail.text=tr("Greta leent haar tang en sleutel. Geen materiaalverbruik. Het eerste herstel geeft 6 Smeden-XP en het slagbandenpatroon; daarna oefen je zonder extra XP.")
	elif practice:detail.text=tr("Je gebruikt Lena's proefblaadjes en vijzel. Oefenen kost geen ingrediënten en geeft geen drankje, patroon of XP.")
	else:
		detail.text=tr("Lena leent haar vijzel. Kosten pas bij bottelen: %s. Alchemie niveau %d (nodig: %d); werkplek: bibliotheek.")%[Journal.ingredient_status("potion"),Prof.level("alchemy"),int(Prof.Data.RECIPES.potion.level)]
		if reason!="":detail.text+="\n"+reason
		else:detail.text+="\n"+tr("Een bereiding gebruikt hetzelfde recept en dezelfde ervaring als Maken.")
	practice_button.visible=not smith
	practice_button.text=tr("Eigen ingrediënten gebruiken") if practice else tr("Oefenen met Lena's proefblaadjes — geen kosten")
	practice_button.disabled=working
	primary.disabled=working or (not smith and not finished and (reason!="" or (stage==0 and selected.size()!=2)))
	primary.text=tr("Nog eens oefenen") if finished else tr("Even controleren…") if working else tr("Naad vastzetten") if smith and stage==0 else tr("Druk controleren") if smith else tr("Maal en meng") if stage==0 else tr("Proefbereiding afronden") if practice else tr("Bottel één drankje")
	back.text=tr("Sluiten — ongebruikte ingrediënten blijven in je tas")
	var navigation: Array[Control]=[]
	if leaf_grid.visible:
		for i in leaves.size():
			var b:=leaves[i];b.focus_neighbor_left=b.get_path_to(leaves[i^1]);b.focus_neighbor_right=b.focus_neighbor_left
			b.focus_neighbor_top=b.get_path_to(leaves[i-2] if i>=2 else back)
			b.focus_neighbor_bottom=b.get_path_to(leaves[i+2] if i<2 else practice_button)
			navigation.append(b)
	if practice_button.visible:navigation.append(practice_button)
	navigation.append(primary);navigation.append(back)
	# Preserve two-column leaf navigation; link only the footer vertically.
	if practice_button.visible:practice_button.focus_neighbor_top=practice_button.get_path_to(leaves[2] if leaf_grid.visible else back);practice_button.focus_neighbor_bottom=practice_button.get_path_to(primary if not primary.disabled else back)
	primary.focus_neighbor_top=primary.get_path_to(practice_button if practice_button.visible else back);primary.focus_neighbor_bottom=primary.get_path_to(back)
	back.focus_neighbor_top=back.get_path_to(primary if not primary.disabled else practice_button if practice_button.visible and not practice_button.disabled else back)
	back.focus_neighbor_bottom=back.get_path_to(leaves[0] if leaf_grid.visible else primary if not primary.disabled else back)
	for i in navigation.size():
		navigation[i].focus_previous=navigation[i].get_path_to(navigation[posmod(i-1,navigation.size())]);navigation[i].focus_next=navigation[i].get_path_to(navigation[(i+1)%navigation.size()])
	device_changed(Controls.controller_active);preview.queue_redraw()
func device_changed(pad: bool):
	for b in [left,right,primary,practice_button,back]+leaves:b.mouse_filter=Control.MOUSE_FILTER_IGNORE if pad else Control.MOUSE_FILTER_STOP
func language_changed(_language: String):
	if active:result="";refresh()
func _process(delta: float):
	if not active:return
	if not director.valid():close();return
	time+=delta;preview.queue_redraw()
	if working:
		elapsed+=delta
		if elapsed>=1.4:
			working=false
			if director.kind=="smith":stage=2;finish_work()
			else:stage=1;refresh();primary.grab_focus()
	fit()
func fit():
	panel.size=panel.get_combined_minimum_size()
	var factor:=minf(1,minf((root.size.x-32)/panel.size.x,(root.size.y-32)/panel.size.y))
	panel.scale=Vector2.ONE*maxf(0.1,factor);panel.position=(root.size-panel.size*panel.scale)/2
func draw_preview():
	var center:=Vector2(preview.size.x/2,48)
	if director.kind=="smith":
		DrawUtil.sprite(preview,Art.tex("wt_stations"),1 if stage>0 else 0,0,center,Vector2i(24,24),3)
		if not finished and stage==0:
			preview.draw_line(center+Vector2(46,-26),center+Vector2(46,25),Color("e1ebd8"),2)
			preview.draw_rect(Rect2(center+Vector2(40+alignment*9,-15),Vector2(12,28)),Color("b4c9ca"))
		if stage==1:
			for i in 3:preview.draw_rect(Rect2(center+Vector2(90+i*26,-10),Vector2(20,20)),[Color("738795"),Color("81bc92"),Color("c98570")][i],i==pressure,-1 if i==pressure else 2)
	else:
		DrawUtil.sprite(preview,Art.tex("wt_stations"),3 if working else 4 if stage>0 else 2,0,center,Vector2i(24,24),3)
		if working:
			preview.draw_line(center+Vector2(8,-35),center+Vector2(sin(time*8)*10,-3),Color("dfc399"),5)
		for i in selected.size():DrawUtil.sprite(preview,Art.tex("wt_leaves"),selected[i],0,center+Vector2(-90-i*40,8),Vector2i(24,24),1.5)
func _input(event: InputEvent):
	if not active or not Controls.allows_event(event) or event.is_echo() or Engine.get_process_frames()==opened_frame:return
	if director.kind=="smith" and not working and not finished:
		if event.is_action_pressed("ui_left"):adjust(-1);get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):adjust(1);get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent):
	if not active or not Controls.allows_event(event) or event.is_echo() or Engine.get_process_frames()==opened_frame:return
	if event.is_action_pressed("ui_cancel") or Style.shortcut(event,"pause"):
		get_viewport().set_input_as_handled();close()
	elif Style.activate_focused(panel,event):get_viewport().set_input_as_handled()
func close():
	active=false;working=false;root.hide();GameState.set_ui("work_together",false)
func _exit_tree():
	if active:GameState.set_ui("work_together",false)
