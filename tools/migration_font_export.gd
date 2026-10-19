extends SceneTree
## Extract the actual embedded game font. ONLY run through record_migration_font.py.
## No game scene, save operation, or font substitution is used.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ""
	var input := ""
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output-dir" and index+1 < args.size():output=args[index+1]
		if args[index] == "--codepoints" and index+1 < args.size():input=args[index+1]
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-") or output=="" or input=="":
		push_error("Unverified isolated font export arguments");quit(1);return
	var font := ThemeDB.fallback_font as FontFile
	if font==null:
		push_error("Godot fallback is not an extractable FontFile");quit(1);return
	var bytes := font.get_data()
	if bytes.is_empty() or FileAccess.file_exists(output+"/DefaultFont.woff2"):
		push_error("Font data missing or output already exists");quit(1);return
	var codepoints: Variant=JSON.parse_string(FileAccess.get_file_as_string(input))
	if not codepoints is Array:
		push_error("Codepoint array missing");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var file:=FileAccess.open(output+"/DefaultFont.woff2",FileAccess.WRITE)
	if file==null:
		push_error("Cannot write extracted font");quit(1);return
	file.store_buffer(bytes);file.close()
	var glyphs: Array=[]
	var missing: Array=[]
	for value: Variant in codepoints:
		var codepoint:=int(value)
		var sizes: Array=[]
		for size in [10,12,13,14,16,18,20,22,24,28,32,40,48]:
			var advance:=font.get_char_size(codepoint,size)
			sizes.append({"size":size,"advance":[advance.x,advance.y],"ascent":font.get_ascent(size),"descent":font.get_descent(size),"height":font.get_height(size)})
		var supported:=font.has_char(codepoint)
		if not supported and codepoint not in [9,10,13]:missing.append(codepoint)
		glyphs.append({"codepoint":codepoint,"hasChar":supported,"sizes":sizes})
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes)
	var report: Dictionary={"schema":"bluemap.migration.font-extraction.v1","engineVersion":Engine.get_version_info().string,"class":font.get_class(),"family":font.get_font_name(),"style":font.get_font_style_name(),"bytes":bytes.size(),"sha256":digest.finish().hex_encode(),"glyphs":glyphs,"missingPrimaryGlyphs":missing,"antialiasing":font.antialiasing,"hinting":font.hinting,"subpixelPositioning":font.subpixel_positioning,"generateMipmaps":font.generate_mipmaps,"personalSavesUsed":false,"fontSubstituted":false}
	var json_file:=FileAccess.open(output+"/metrics.json",FileAccess.WRITE)
	json_file.store_string(JSON.stringify(report,"",true,true)+"\n");json_file.close()
	print("MIGRATION FONT EXPORT OK")
	quit(0)
