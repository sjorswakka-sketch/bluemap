extends SceneTree
## GPU-only reference export; invoke exclusively through the UUID-isolated wrapper.
const Manifest := preload("res://scripts/data/character_art.gd")
const AppearanceData := preload("res://scripts/data/ext/uiterlijk.gd")
const GearData := preload("res://scripts/data/ext/uitrusting.gd")
const Items := preload("res://scripts/data/items.gd")
const Art := preload("res://scripts/core/art.gd")
var output_dir := ""
var document := {"schemaVersion":1,"tilePixels":32,"textures":[],"sprites":[],"animations":[],"referenceOnly":true,"continuousDrawingRulesRetained":true}
var failure := false
const DIRECTIONS := ["down","up","right","left"]
const POSES := ["idle","step1","step2"]

func _initialize() -> void:
	_run.call_deferred()

func fail(message: String) -> void:
	failure=true; push_error(message)

func _run() -> void:
	if not OS.get_user_data_dir().replace(char(92),"/").get_file().begins_with("Bluemap-Codex-Tests-"):
		fail("Unisolated graphics export refused"); quit(1); return
	if DisplayServer.get_name()=="headless":
		fail("Graphics reference requires an actual GPU renderer"); quit(1); return
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2 or args[0]!="--output-dir":
		fail("Expected --output-dir <new directory>"); quit(1); return
	output_dir=args[1]
	if DirAccess.dir_exists_absolute(output_dir):
		fail("Never overwrite an existing reference"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	for node in root.get_children():
		node.set_process(false); node.set_physics_process(false)
	var appearances: Array=[]
	for hair: String in Manifest.HAIR:
		for row in 4:
			for column in 3:appearances.append({"id":"generated:hair:%s:%s:%s"%[hair,DIRECTIONS[row],POSES[column]],"category":"appearance","mode":"appearance","hair":hair,"row":row,"column":column})
	for item: String in AppearanceData.ITEMS:
		for row in 4:
			for column in 3:appearances.append({"id":"generated:clothes:%s:%s:%s"%[item,DIRECTIONS[row],POSES[column]],"category":"appearance","mode":"appearance","clothing":item,"row":row,"column":column})
	for item: String in GearData.ITEMS:
		for row in 4:
			for column in 3:appearances.append({"id":"generated:gear:%s:%s:%s"%[item,DIRECTIONS[row],POSES[column]],"category":"appearance","mode":"appearance","gear":item,"row":row,"column":column})
	await atlas("appearances",appearances,64,"scripts/core/character_layers.gd")
	var eyes: Array=[]
	for style: String in AppearanceData.EYES:
		for color in AppearanceData.EYE_COLORS.size():
			for row in 4:eyes.append({"id":"generated:eyes:%s:%s:%s"%[style,color,DIRECTIONS[row]],"category":"eyes","mode":"eyes","eyes":style,"eyeColor":color,"row":row})
	await atlas("eyes",eyes,32,"scripts/core/character_layers.gd")
	var effects: Array=[]
	for weapon: String in Items.WEAPONS:
		for sweep in [false,true]:
			for row in 4:
				var frames: Array=[]
				for frame in 8:
					var id: String="generated:sword:%s:%s:%s:%s"%[weapon,sweep,DIRECTIONS[row],frame]
					frames.append(id)
					effects.append({"id":id,"category":"effect","mode":"sword","weapon":weapon,"sweep":sweep,"row":row,"progress":float(frame)/8})
				document.animations.append({"id":"sample:sword:%s:%s:%s"%[weapon,sweep,DIRECTIONS[row]],"frames":frames,"fps":8.0/0.18,"loop":false,"sampled":true,"sourceFunction":"player._draw_sword"})
	await atlas("swords",effects,192,"scripts/entities/player.gd")
	effects=[]
	for kind: String in ["bow","foraging","mining","woodcutting","repair","roll"]:
		for row in 4:
			var frames: Array=[]
			for frame in 8:
				var id: String="generated:%s:%s:%s"%[kind,DIRECTIONS[row],frame]
				frames.append(id)
				effects.append({"id":id,"category":"effect","mode":kind if kind in ["bow","roll"] else "work","kind":kind,"row":row,"column":1,"progress":float(frame)/8})
			var duration:=0.25 if kind=="bow" else (0.3 if kind=="roll" else 1.0)
			document.animations.append({"id":"sample:%s:%s"%[kind,DIRECTIONS[row]],"frames":frames,"fps":8.0/duration,"loop":false,"sampled":true,"sourceFunction":"player._draw_"+kind})
	await atlas("tools",effects,128,"scripts/entities/player.gd")
	var environment: Array=[]
	var waterfall_frames: Array=[]
	for frame in 8:
		var id: String="generated:waterfall:%s"%frame
		waterfall_frames.append(id)
		environment.append({"id":id,"category":"environment","mode":"waterfall","progress":float(frame)/8})
	document.animations.append({"id":"sample:waterfall","frames":waterfall_frames,"fps":8,"loop":false,"sampled":true,"sourceFunction":"water_art.fall; continuous time is not a one-second loop"})
	for pale in [false,true]:environment.append({"id":"generated:rock:%s"%pale,"category":"environment","mode":"rock","pale":pale})
	await atlas("water",environment,128,"scripts/core/water_art.gd")
	var crops: Array=[]
	for crop: String in ["grape","flower"]:
		for stage in 4:
			for fertilized in [false,true]:
				crops.append({"id":"generated:crop:%s:%s:%s"%[crop,stage,fertilized],"category":"crop","mode":"crop","crop":crop,"growth":[0.0,0.35,0.65,1.0][stage],"fertilized":fertilized,"progress":0.0})
	await atlas("crops",crops,64,"scripts/core/garden_art.gd")
	save_image("equipment-icons",Art.tex("items_equipment").get_image(),"scripts/core/equipment_art.gd")
	save_image("light-gradient",Art.light_texture().get_image(),"scripts/core/art.gd")
	var icon:=Image.new()
	if icon.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"))!=OK:fail("SVG raster failed")
	else:save_image("icon",icon,"icon.svg")
	var file:=FileAccess.open(output_dir.path_join("index.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(document,"  ",true)+"\n"); file.close()
	print("MIGRATION GRAPHICS EXPORT OK ",document.sprites.size()," sprites; ",document.textures.size()," textures")
	quit(1 if failure else 0)

func save_image(id: String,image: Image,source: String) -> void:
	if image==null or image.is_empty():fail("Empty GPU reference: "+id); return
	if image.save_png(output_dir.path_join(id+".png"))!=OK:fail("Cannot save "+id); return
	document.textures.append({"id":"generated:"+id,"file":id+".png","width":image.get_width(),"height":image.get_height(),"sourcePath":source})

func atlas(name: String,entries: Array,size: int,source: String) -> void:
	var columns:=mini(32,2048/size)
	var capacity:=columns*columns
	for first in range(0,entries.size(),capacity):
		var page: Array=entries.slice(first,mini(entries.size(),first+capacity))
		var id: String=name+"-"+str(first/capacity)
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(columns*size,ceili(float(page.size())/columns)*size)
		viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport)
		# Deliberately load after autoloads exist: the original player references GameState.
		var canvas: Node2D=load("res://tools/migration_presentation_canvas.gd").new()
		canvas.samples=page; canvas.cell_size=size; canvas.columns=columns
		viewport.add_child(canvas)
		canvas.queue_redraw()
		await process_frame
		# A minimized hidden window may skip regular drawing. Explicitly draw the
		# active SubViewport before reading it; waiting for frame_post_draw first
		# would deadlock on that skipped frame.
		RenderingServer.force_draw(false)
		var image:=viewport.get_texture().get_image()
		save_image(id,image,source)
		for index in page.size():
			var e: Dictionary=page[index]
			document.sprites.append({"id":e.id,"textureId":"generated:"+id,"category":e.category,"x":(index%columns)*size,"y":(index/columns)*size,"width":size,"height":size,"pivotX":0.5,"pivotY":0.5,"pixelsPerUnit":32,"parameters":e})
		viewport.queue_free()
		await process_frame
