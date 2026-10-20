extends SceneTree
## Run only in the recorder's verified UUID project. Fixtures never read personal files.

func _initialize() -> void:_run.call_deferred()
func _binding(event:InputEvent,category:String)->Dictionary:
	var r:={"category":category,"kind":"","code":0,"keyName":"","direction":1,"shift":false,"ctrl":false,"alt":false,"meta":false}
	if event is InputEventKey:
		r.kind="key";r.code=event.physical_keycode if event.physical_keycode else event.keycode;r.keyName=OS.get_keycode_string(r.code)
		r.shift=event.shift_pressed;r.ctrl=event.ctrl_pressed;r.alt=event.alt_pressed;r.meta=event.meta_pressed
	elif event is InputEventMouseButton:r.kind="mouse";r.code=event.button_index
	elif event is InputEventJoypadButton:r.kind="button";r.code=event.button_index
	elif event is InputEventJoypadMotion:r.kind="axis";r.code=event.axis;r.direction=signf(event.axis_value)
	return r
func _file(path:String,text:Variant)->void:
	if text==null:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	else:
		var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(text);f.close()
func _text(config:ConfigFile)->String:return config.encode_to_text()
func _run()->void:
	var output:="";var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--output" and i+1<args.size():output=args[i+1]
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-") or output=="" or FileAccess.file_exists(output):push_error("Unsafe settings export");quit(1);return
	var controls:=root.get_node("Controls");var gs:=root.get_node("GameState");gs.set_process(false)
	var fixtures:Array=[]
	fixtures.append({"id":"missing","settings":null,"controls":null,"meta":null,"ng":null})
	var full:=ConfigFile.new()
	for action:String in controls.ACTION_NAMES:
		for category:String in ["keyboard","controller"]:full.set_value(category,action,controls._defaults[action][category])
	fixtures.append({"id":"full_defaults","settings":"[taal]\nlocale=\"EN-us\"\n[audio]\nmuted=true\nmusic=0.35\nsfx=0.7\n","controls":_text(full),"meta":"[achievements]\nexplorer=false\nfirst=true\n","ng":"[ng]\ncompleted=true\nrounds=3\nweapon=\"iron\"\nhearts=2\nboots=true\nhero_xp=4321\ngear_items={}\nequipment={}\n"})
	var legacy:=ConfigFile.new();legacy.set_value("keyboard","attack",[controls._key(KEY_V)]);legacy.set_value("keyboard","bow",[controls._key(KEY_U)]);legacy.set_value("controller","attack",[controls._axis(JOY_AXIS_TRIGGER_LEFT,1.0)])
	fixtures.append({"id":"legacy_conflicts","settings":"[taal]\nlocale=\" nl-NL \"\n","controls":_text(legacy),"meta":null,"ng":null})
	var modifiers:=ConfigFile.new();var key:=InputEventKey.new();key.keycode=KEY_Q;key.shift_pressed=true;key.ctrl_pressed=true;modifiers.set_value("keyboard","attack",[key]);key=controls._key(KEY_F8);key.alt_pressed=true;key.meta_pressed=true;modifiers.set_value("keyboard","bow",[key]);modifiers.set_value("controller","technique",[controls._axis(5,0.6)])
	fixtures.append({"id":"physical_and_modifiers","settings":"[taal]\nlocale=\"en_GB\"\n[audio]\nmusic=0.0\nsfx=1.0\nmuted=false\n","controls":_text(modifiers),"meta":null,"ng":null})
	var empty:=ConfigFile.new();empty.set_value("keyboard","attack",[]);empty.set_value("controller","sprint",[]);empty.set_value("keyboard","homestead",[]);empty.set_value("controller","technique",[])
	fixtures.append({"id":"explicit_empty","settings":"","controls":_text(empty),"meta":"[achievements]\nunknown_future=17\n","ng":null})
	var invalid:=ConfigFile.new();invalid.set_value("keyboard","attack",[123]);invalid.set_value("controller","bow",[controls._key(KEY_Q)]);invalid.set_value("keyboard","technique","invalid")
	fixtures.append({"id":"invalid_arrays","settings":null,"controls":_text(invalid),"meta":null,"ng":null})
	var oversized:=ConfigFile.new();var many:Array=[]
	for i in 9:many.append(controls._key(KEY_Z))
	oversized.set_value("keyboard","attack",many);oversized.set_value("keyboard","bow",[controls._key(KEY_Q),controls._key(KEY_Q)])
	fixtures.append({"id":"oversized_and_duplicate","settings":null,"controls":_text(oversized),"meta":null,"ng":null})
	fixtures.append({"id":"unknown_multiline","settings":"; preserve this exact comment\r\n[taal]\r\nlocale=\"en\"\r\n[future]\r\nvalues={\r\n\"kind\": \"literal\",\r\n\"vector\": Vector2(1.5, -2),\r\n\"items\": [1, \"hé\\n🌱\", true, null]\r\n}\r\n","controls":"[future]\nunknown=PackedStringArray(\"keep\", \"me\")\n","meta":"[achievements]\nfuture=false\n[unrelated]\nuntouched=Color(1, 0, 0, 1)\n","ng":"[ng]\ncompleted=true\nrounds=2\nweapon=\"unknown_future\"\nhero_xp=-12\ngear_items={}\nequipment={}\n[extra]\ntext=\"keep\"\n"})
	fixtures.append({"id":"malformed","settings":"[taal]\nlocale=[\n","controls":"[keyboard]\nattack=[\n","meta":"[achievements\n","ng":"[ng]\ncompleted=[\n"})
	fixtures.append({"id":"unsupported_locale","settings":"[taal]\nlocale=\"fr_FR\"\n[audio]\nmusic=0.125\nsfx=0.875\n","controls":"","meta":null,"ng":null})
	var cases:Array=[]
	for fixture:Dictionary in fixtures:
		for pair:Array in [["settings","settings.cfg"],["controls","controls.cfg"],["meta","meta.cfg"],["ng","ng_plus.cfg"]]:_file("user://"+pair[1],fixture[pair[0]])
		controls._bindings=controls._defaults.duplicate(true);controls._load_bindings()
		var bindings:Array=[]
		for action:String in controls.ACTION_NAMES:
			var list:Array=[]
			for category:String in ["keyboard","controller"]:
				for event:InputEvent in controls.binding_events(action,category):list.append(_binding(event,category))
			bindings.append({"id":action,"bindings":list})
		gs.meta_achievements={};gs._load_meta()
		var sound:Node=load("res://scripts/core/sound.gd").new();root.add_child(sound)
		var locale:String=load("res://scripts/core/lang.gd").startup_locale()
		var docs:={};var parse_ok:={}
		for part:String in ["settings","controls","meta","ng"]:
			docs[part]=null if fixture[part]==null else ("" if fixture[part]=="" else Marshalls.raw_to_base64(fixture[part].to_utf8_buffer()))
			var cfg:=ConfigFile.new();parse_ok[part]=fixture[part]==null or cfg.parse(fixture[part])==OK
		cases.append({"id":fixture.id,"documents":docs,"parseOk":parse_ok,"locale":locale,"muted":sound.muted,"music":sound.music_volume,"sfx":sound.sfx_volume,"bindings":bindings,"achievements":gs.meta_achievements.keys(),"ng":gs.load_meta()})
		sound.free()
	var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify({"schema":"bluemap.settings-import.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"cases":cases},"",true,true)+"\n");f.close()
	print("MIGRATION SETTINGS EXPORT OK");quit(0)
