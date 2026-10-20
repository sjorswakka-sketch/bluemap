extends SceneTree
## ONLY run through record_migration_player_input.py, never the live player project.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ""
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index+1 < args.size():output=args[index+1]
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-") or output == "":
		push_error("Unverified isolated input export");quit(1);return
	var controls := root.get_node("Controls")
	var defaults: Array = []
	var names: Array = controls.ACTION_NAMES.keys()
	names.append_array(["ui_left","ui_right","ui_up","ui_down","ui_accept","ui_cancel","ui_prev_tab","ui_next_tab","ui_focus_next","ui_focus_prev","aim_left","aim_right","aim_up","aim_down"])
	for action: String in names:
		var bindings: Array = []
		for category: String in ["keyboard","controller"]:
			for event: InputEvent in controls.binding_events(action,category):
				var row := {"category":category,"kind":"","code":0,"keyName":"","direction":1,"shift":false,"ctrl":false,"alt":false,"meta":false}
				if event is InputEventKey:
					row.kind="key";row.code=event.physical_keycode if event.physical_keycode else event.keycode
					row.keyName=OS.get_keycode_string(row.code)
					row.shift=event.shift_pressed;row.ctrl=event.ctrl_pressed;row.alt=event.alt_pressed;row.meta=event.meta_pressed
				elif event is InputEventMouseButton:row.kind="mouse";row.code=event.button_index
				elif event is InputEventJoypadButton:row.kind="button";row.code=event.button_index
				elif event is InputEventJoypadMotion:row.kind="axis";row.code=event.axis;row.direction=signf(event.axis_value)
				else:
					push_error("Unhandled source input event");quit(1);return
				bindings.append(row)
		defaults.append({"id":action,"label":controls.ACTION_NAMES.get(action,action),"rebindable":controls.ACTION_NAMES.has(action),"deadzone":InputMap.action_get_deadzone(action),"bindings":bindings})
	var vectors: Array=[]
	for raw: Vector2 in [Vector2.ZERO,Vector2(0.1,0),Vector2(0.2,0),Vector2(0.5,0),Vector2(1,1),Vector2(0.3,-0.4),Vector2(-0.24,0),Vector2(-0.5,0.5)]:
		for deadzone: float in [0.2,controls.AIM_DEADZONE]:
			Input.action_press("move_left",maxf(-raw.x,0));Input.action_press("move_right",maxf(raw.x,0))
			Input.action_press("move_up",maxf(-raw.y,0));Input.action_press("move_down",maxf(raw.y,0))
			var expected:=Input.get_vector("move_left","move_right","move_up","move_down",deadzone)
			vectors.append({"raw":[raw.x,raw.y],"deadzone":deadzone,"expected":[expected.x,expected.y]})
	for action: String in ["move_left","move_right","move_up","move_down"]:Input.action_release(action)
	var result := {"schema":"bluemap.player-input.v1","engineVersion":Engine.get_version_info().string,"switchDeadzone":controls.SWITCH_DEADZONE,"aimDeadzone":controls.AIM_DEADZONE,"mouseSwitchPixels":3.0,"defaults":defaults,"vectors":vectors,"personalSavesUsed":false}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:push_error("Cannot write input oracle");quit(1);return
	file.store_string(JSON.stringify(result,"",true,true)+"\n");file.close()
	print("MIGRATION PLAYER INPUT EXPORT OK");quit(0)
