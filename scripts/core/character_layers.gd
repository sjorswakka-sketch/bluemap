extends RefCounted
## All tint masks are authored on a native 32px grid, in the legacy 16px canvas box.
const Manifest := preload("res://scripts/data/character_art.gd")
const Data := preload("res://scripts/data/ext/uiterlijk.gd")
const Art := preload("res://scripts/core/art.gd")
static func mask(canvas: CanvasItem,origin: Vector2,px: float,sheet: String,index: int,row: int,column: int,tint: Color,animated := true) -> void:
	var source := Rect2((index*3+column)*32 if animated else index*32,row*32,32,32)
	canvas.draw_texture_rect_region(Art.tex(sheet),Rect2(origin,Vector2(16,16)*px),source,tint.lightened(.12))
static func garment(canvas: CanvasItem,origin: Vector2,px: float,row: int,column: int,item: String,color: Color) -> void:
	if Manifest.CLOTHES.has(item):mask(canvas,origin,px,"character_clothes",Manifest.CLOTHES[item],row,column,color)
static func dye(entry: Dictionary) -> Color:
	return Data.DYE_COLORS[clampi(int(entry.get("dye",0)),0,Data.DYE_COLORS.size()-1)].color
static func behind(canvas: CanvasItem,origin: Vector2,px: float,row: int,clothing: Dictionary) -> void:
	var entry: Dictionary=clothing.get("back",{})
	if entry.get("item","") in ["cloth_cape","cloth_cloak","cloth_backpack"]:
		garment(canvas,origin,px,row,0,entry.item,dye(entry))
static func front(canvas: CanvasItem,origin: Vector2,px: float,row: int,column: int,appearance: Dictionary,clothing: Dictionary) -> void:
	var equipment := preload("res://scripts/core/equipment.gd")
	for slots: Array in [["chest","top","gear_chest"],["hands","","gear_gloves"],["feet","feet","gear_boots"]]:
		var equipped: String=equipment.equipped(slots[0])
		if equipped!="" and (slots[1]=="" or clothing.get(slots[1],{}).get("item","")==""):
			garment(canvas,origin,px,row,column,slots[2],gear_color(equipped))
	for slot: String in ["back","top","bottom","feet"]:
		var entry: Dictionary=clothing.get(slot,{})
		var item: String=entry.get("item","")
		if item!="" and (slot!="back" or item in ["cloth_scarf","cloth_backpack"]):garment(canvas,origin,px,row,column,item,dye(entry))
	var hair_id: String=appearance.get("hair","m_kort")
	if Manifest.HAIR.has(hair_id):
		var color: Color=Data.HAIR_COLORS[clampi(int(appearance.get("hair_color",2)),0,Data.HAIR_COLORS.size()-1)].color
		mask(canvas,origin,px,"character_hair",Manifest.HAIR[hair_id],row,0,color,false)
	eyes(canvas,origin,px,row,appearance)
	var head: String=equipment.equipped("head")
	var hat: Dictionary=clothing.get("hat",{})
	if head!="" and hat.get("item","")=="":garment(canvas,origin,px,row,column,"gear_helmet",gear_color(head))
	if hat.get("item","")!="":garment(canvas,origin,px,row,column,hat.item,dye(hat))
static func gear_color(item: String) -> Color:
	if "crystal" in item or "focus" in item:return Color("91c4ca")
	if "iron" in item or "plate" in item:return Color("a9bbc3")
	if "copper" in item:return Color("ca9b69")
	if "cap" in item or "scout" in item:return Color("87957a")
	return Color("ac8a63")
static func point(canvas: CanvasItem,origin: Vector2,unit: float,at: Vector2,color: Color,size := Vector2.ONE) -> void:
	canvas.draw_rect(Rect2(origin+at*unit,size*unit),color)
static func eyes(canvas: CanvasItem,origin: Vector2,px: float,row: int,appearance: Dictionary) -> void:
	if row==1:return
	var unit:=px*.5
	var color: Color=Data.EYE_COLORS[clampi(int(appearance.get("eye_color",0)),0,Data.EYE_COLORS.size()-1)].color
	var style: String=appearance.get("eyes","rond")
	var centers: Array=[Vector2(12,11),Vector2(19,11)] if row==0 else [Vector2(21 if row==2 else 10,9)]
	for i in centers.size():
		var at: Vector2=centers[i]
		var dark:=Color("57463d");var light:=Color("f7edcf")
		point(canvas,origin,unit,at-Vector2(0,1),dark,Vector2(2,1))
		if style=="dicht" or (style=="knipoog" and i==1):
			point(canvas,origin,unit,at,dark,Vector2(2,1))
			point(canvas,origin,unit,at+Vector2(1,1),dark)
			continue
		point(canvas,origin,unit,at,color,Vector2(1,2))
		match style:
			"stip":point(canvas,origin,unit,at,Color("26363e"))
			"groot":
				point(canvas,origin,unit,at,color,Vector2(2,3));point(canvas,origin,unit,at,light)
			"wimpers":
				point(canvas,origin,unit,at-Vector2(1,1),dark);point(canvas,origin,unit,at-Vector2(0,2),dark)
			"slaperig":point(canvas,origin,unit,at,dark,Vector2(2,1))
			"boos":
				point(canvas,origin,unit,at-Vector2(1,2),dark);point(canvas,origin,unit,at+Vector2(1,-1),dark)
			"sterretjes":
				point(canvas,origin,unit,at-Vector2(1,0),light,Vector2(3,1));point(canvas,origin,unit,at-Vector2(0,1),light,Vector2(1,3));point(canvas,origin,unit,at,color)
			"vonkel":point(canvas,origin,unit,at+Vector2(1,1),light)
			"vriendelijk":
				point(canvas,origin,unit,at-Vector2(1,1),dark);point(canvas,origin,unit,at-Vector2(0,2),dark,Vector2(2,1))
			"smal":point(canvas,origin,unit,at,color.darkened(.3),Vector2(2,1))
			"ovaal":point(canvas,origin,unit,at,color,Vector2(1,3));point(canvas,origin,unit,at,light)
			"wijs":point(canvas,origin,unit,at-Vector2(1,3),Color("aaa397"),Vector2(3,1))
			"straler":point(canvas,origin,unit,at,light);point(canvas,origin,unit,at+Vector2(1,2),light)
			"dromerig":point(canvas,origin,unit,at-Vector2(0,1),color,Vector2(2,1));point(canvas,origin,unit,at+Vector2(0,1),light)
