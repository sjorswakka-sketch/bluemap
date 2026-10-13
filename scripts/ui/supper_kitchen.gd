extends CanvasLayer
## A short, cancellable preparation: ingredients commit only when plating finishes.
const Supper := preload("res://scripts/core/lake_supper.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
const Items := preload("res://scripts/data/items.gd")
const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
var root: Control
var panel: PanelContainer
var box: VBoxContainer
var detail: Label
var progress: ProgressBar
var action_button: Button
var back: Button
var choices: Array[Button]=[]
var source: WeakRef
var active := false
var dish := ""
var stage := 0
var working := false
var elapsed := 0.0
var opened_frame := -1
var result := ""
var preview: Control
var time := 0.0

func _ready() -> void:
	layer=12
	process_mode=Node.PROCESS_MODE_ALWAYS
	root=Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim:=ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color=Color(0.02,0.04,0.07,0.8)
	root.add_child(dim)
	panel=PanelContainer.new()
	UiStyle.style_panel(panel)
	panel.custom_minimum_size=Vector2(740,460)
	root.add_child(panel)
	box=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	box.add_child(UiStyle.make_label(tr("Koken met Mila"),30,Color("edce98")))
	var subtitle:=UiStyle.make_label(tr("Kies je gerecht. Snijden → roeren → opscheppen."),20)
	box.add_child(subtitle)
	preview=Control.new()
	preview.custom_minimum_size=Vector2(0,72)
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(draw_preparation)
	box.add_child(preview)
	for id: String in Supper.DISHES:
		var button:=Button.new()
		UiStyle.style_button(button,22)
		button.text=tr(Items.info(id).name)
		button.icon=Items.icon_tex(id)
		button.pressed.connect(select_dish.bind(id))
		box.add_child(button)
		choices.append(button)
	detail=UiStyle.make_label("",20)
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size=Vector2(680,92)
	box.add_child(detail)
	progress=ProgressBar.new()
	progress.custom_minimum_size=Vector2(0,18)
	progress.max_value=3
	progress.show_percentage=false
	box.add_child(progress)
	action_button=Button.new()
	UiStyle.style_button(action_button,22)
	action_button.pressed.connect(prepare_step)
	box.add_child(action_button)
	back=Button.new()
	UiStyle.style_button(back,20)
	back.text=tr("Sluiten — ongebruikte ingrediënten blijven in je tas")
	back.pressed.connect(close)
	box.add_child(back)
	root.hide()

func open(stove: Node2D) -> void:
	if active or GameState.input_locked(): return
	source=weakref(stove)
	active=true
	stage=0
	working=false
	dish=""
	result=""
	opened_frame=Engine.get_process_frames()
	root.show()
	GameState.set_ui("supper_kitchen",true)
	refresh()
	choices[0].grab_focus()

func select_dish(id: String) -> void:
	if working: return
	dish=id
	stage=0
	result=""
	refresh()
	if not action_button.disabled: action_button.grab_focus()

func refresh() -> void:
	for i in choices.size():
		choices[i].disabled=working
		choices[i].modulate=Color("ffe4ac") if dish==Supper.DISHES[i] else Color.WHITE
	progress.value=stage
	action_button.text=tr("Kies eerst een gerecht") if dish=="" else [tr("Snijden"),tr("Roeren"),tr("Opscheppen")][mini(stage,2)]
	var reason:=Supper.cook_reason(dish) if dish!="" else ""
	action_button.disabled=dish=="" or reason!="" or working
	if result!="":
		detail.text=result
	elif dish=="":
		detail.text=tr("Stoof geeft meer hartjes; bouillon meer uithoudingsvermogen. De eerste mand is goed voor twee porties. Eén voor de dorpstafel, één voor onderweg.")
	else:
		var ingredients: Array[String]=[]
		for item: String in Supper.inputs(dish): ingredients.append("%s ×%d" % [Supper.Professions.item_name(item),Supper.inputs(dish)[item]])
		detail.text=tr(Items.info(dish).desc)+"\n"+", ".join(ingredients)+("\n"+reason if reason!="" else "")
	var controls: Array[Control]=[]
	for button in choices: controls.append(button)
	controls.append(action_button)
	controls.append(back)
	UiStyle.link_vertical(controls)

func prepare_step() -> void:
	if not active or working or dish=="" or Supper.cook_reason(dish)!="": return
	working=true
	elapsed=0
	Sound.play(["ls_chop","ls_simmer","ls_serve"][stage],-10)
	refresh()
	back.grab_focus() # cancellation stays available during preparation

func _process(delta: float) -> void:
	if not active: return
	time+=delta
	preview.queue_redraw()
	var stove: Variant=source.get_ref() if source!=null else null
	if not is_instance_valid(stove) or not stove.is_inside_tree() or stove.is_queued_for_deletion() or GameState.map_id!="inn" or stove.position.distance_to(stove.world.player.position)>66:
		close()
		return
	if working:
		elapsed+=delta
		progress.value=stage+minf(elapsed/0.9,1)
		if elapsed>=0.9:
			working=false
			stage+=1
			if stage==3:
				if Supper.cook(dish):
					result=tr("Klaar! Deel één portie aan de dorpstafel of neem je gerecht mee. Je ingrediënten zijn verwerkt.")
				else: result=Supper.cook_reason(dish)
				dish=""
				stage=0
			refresh()
			if dish!="" and not action_button.disabled: action_button.grab_focus()
			else: back.grab_focus()
	panel.size=panel.get_combined_minimum_size()
	var factor:=minf(1,minf((root.size.x-24)/panel.size.x,(root.size.y-24)/panel.size.y))
	panel.scale=Vector2.ONE*maxf(0.1,factor)
	panel.position=(root.size-panel.size*panel.scale)/2

func draw_preparation() -> void:
	var center:=Vector2(preview.size.x/2,36)
	DrawUtil.sprite(preview,Art.tex("ls_stove"),int(time*3)%2,0,center,Vector2i(24,24),2.5)
	DrawUtil.sprite(preview,Art.tex("ls_items"),2 if dish=="ls_broth" else 1,0,center+Vector2(100,12),Vector2i(16,16),2.5)
	preview.draw_rect(Rect2(center+Vector2(-130,10),Vector2(56,16)),Color("b18b5b"))
	for i in 3: preview.draw_circle(center+Vector2(-121+i*14,14),4,Color("8dae72"))
	if working and stage==0:
		var lift: float=absf(sin(time*12))*14
		preview.draw_line(center+Vector2(-111,-lift),center+Vector2(-95,-lift),Color("dae3d9"),5)
	elif working and stage==1:
		preview.draw_line(center+Vector2(10,-32),center+Vector2(sin(time*7)*8,-12),Color("dfbd87"),3)
	if dish!="":
		for i in 3:
			var rise:=fmod(time*15+i*9,28)
			preview.draw_circle(center+Vector2(-8+i*8,-18-rise),2,Color(0.9,0.9,0.8,(1-rise/28)*0.5))

func _unhandled_input(event: InputEvent) -> void:
	if not active or not Controls.allows_event(event) or event.is_echo() or Engine.get_process_frames()==opened_frame: return
	if event.is_action_pressed("ui_cancel") or UiStyle.shortcut(event,"pause"):
		get_viewport().set_input_as_handled()
		close()
	elif UiStyle.activate_focused(panel,event): get_viewport().set_input_as_handled()

func close() -> void:
	active=false
	working=false
	root.hide()
	GameState.set_ui("supper_kitchen",false)

func _exit_tree() -> void:
	if active: GameState.set_ui("supper_kitchen",false)
