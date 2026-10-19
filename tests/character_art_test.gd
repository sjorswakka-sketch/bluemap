extends SceneTree
## Original native pixels, complete directional atlases, and shared visual anchors.
const Art:=preload("res://scripts/core/art.gd")
const Manifest:=preload("res://scripts/data/character_art.gd")
const Data:=preload("res://scripts/data/ext/uiterlijk.gd")
const Npcs:=preload("res://scripts/data/npcs.gd")
var Characters: Script
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("  ok   " if ok else "  FAIL ",label)
	if not ok:failures+=1
func cell(image: Image,x: int,y: int) -> Image:
	return image.get_region(Rect2i(x*32,y*32,32,32))
func fine_blocks(image: Image) -> int:
	var count:=0
	for y in range(0,image.get_height(),2):
		for x in range(0,image.get_width(),2):
			var color:=image.get_pixel(x,y)
			if color!=image.get_pixel(x+1,y) or color!=image.get_pixel(x,y+1) or color!=image.get_pixel(x+1,y+1):count+=1
	return count
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	Characters=load("res://scripts/core/character_draw.gd")
	check(Art.tex("player").get_size()==Vector2(48,64),"legacy player atlas and UI coordinates are retained")
	var families: Array=Manifest.NPC_SHEETS.duplicate();families.append("player")
	var required: Array=[]
	for id: String in Npcs.NPCS:
		var name: String=Npcs.NPCS[id].sheet
		if name!="npc_muis" and not required.has(name):required.append(name)
	for name: String in required:check(Characters.humanoid(name),"human family is covered: "+name)
	check(Characters.humanoid("op_gardener") and Characters.humanoid("op_courier") and not Characters.humanoid("npc_muis"),"opening people included; quest cat keeps its animal sprite")
	for name: String in families:
		var texture:=Art.detailed(Art.tex(name));var image:=texture.get_image()
		check(texture.get_size()==Vector2(96,128),"three original 32px poses in four directions: "+name)
		var valid:=true
		for row in 4:
			var first:=cell(image,1,row);var second:=cell(image,2,row)
			valid=valid and first.get_data()!=second.get_data()
			for column in 3:
				var pose:=cell(image,column,row);var bounds:=pose.get_used_rect()
				valid=valid and bounds.size.x>12 and bounds.end.y>=29 and bounds.end.y<=31 and fine_blocks(pose)>35
		check(valid,"distinct walk steps, consistent feet, detailed pixels in every direction: "+name)
	check(Art.detailed(Art.tex("wm_people")).get_size()==Vector2(512,128),"all eight regional roles retain their two-frame indices with four native directions")
	check(Art.detailed(Art.tex("arena_crowd")).get_size()==Vector2(512,32),"four crowd looks retain front/back and cheering column order")
	check(Art.detailed(Art.tex("wm_tools")).get_size()==Vector2(288,32),"nine work props have matching native detail")
	check(Manifest.HAIR.size()==90 and Manifest.CLOTHES.size()==28,"all 90 hair styles, 24 clothes and four gear masks have authored native slots")
	var hair:=Art.tex("character_hair").get_image();var clothes:=Art.tex("character_clothes").get_image()
	var valid:=hair.get_size()==Vector2i(2880,128) and clothes.get_size()==Vector2i(2688,128)
	for styles: Dictionary in [Data.HAIR_M,Data.HAIR_V]:
		var signatures: Dictionary={}
		for id: String in styles:
			valid=valid and Manifest.HAIR.has(id)
			var strips:=PackedByteArray()
			for row in 4:strips.append_array(cell(hair,Manifest.HAIR[id],row).get_data())
			var signature:=hash(strips)
			valid=valid and not signatures.has(signature);signatures[signature]=true
	for id: String in Data.ITEMS:
		valid=valid and Manifest.CLOTHES.has(id)
		for row in 4:
			for column in 3:valid=valid and cell(clothes,Manifest.CLOTHES[id]*3+column,row).get_used_rect().has_area()
	check(valid,"every selectable hairstyle remains distinct and every clothing pose has a valid source region")
	check(Characters.direction(Vector2.DOWN)==0 and Characters.direction(Vector2.UP)==1 and Characters.direction(Vector2.RIGHT)==2 and Characters.direction(Vector2.LEFT)==3 and Characters.direction(Vector2.ZERO,3)==3,"direction rows follow walking rather than aim, idle preserves a cosmetic facing")
	check(Characters.frame(0,false)==0 and Characters.frame(0,true)==1 and Characters.frame(.25,true)==2,"one idle pose and alternating leg poses stay within native atlases")
	var player: Node2D=load("res://scripts/entities/player.gd").new()
	player.time=0;player.moving=false
	check(player.body_visual_transform()==Transform2D.IDENTITY,"idle skin, clothes and carried gear share the original center")
	player.moving=true;player.sprinting=true;player.walk_time=.08
	var sprint: Transform2D=player.body_visual_transform()
	check(sprint.origin.y!=0 and sprint.get_rotation()==0,"sprint bob carries every body layer together")
	player.roll_dir=Vector2.RIGHT;player.roll_timer=player.ROLL_TIME*.75
	var roll: Transform2D=player.body_visual_transform()
	check(is_equal_approx(roll.get_rotation(),PI*.5) and roll.origin.is_equal_approx(Vector2(4,4)),"quarter-roll rotates skin, appearance and stowed gear around the same original roll anchor")
	player.roll_timer=0;player.work_active=true;player.work_elapsed=.1;player.work_facing=Vector2.UP
	check(player._direction_row()==1 and player.body_visual_transform().origin.y!=0,"work pose still faces the tool and carries clothing with its body motion")
	player.free()
	if failures==0:print("CHARACTER ART TEST OK")
	quit(0 if failures==0 else 1)
