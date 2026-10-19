extends "res://scripts/entities/player.gd"
## Reference renderer: calls the frozen game's actual drawing functions.
## No gameplay _ready, input, physics, save or world callbacks run here.
const NativeLayers := preload("res://scripts/core/character_layers.gd")
const WaterReference := preload("res://scripts/core/water_art.gd")
const GardenReference := preload("res://scripts/core/garden_art.gd")
const AppearanceData := preload("res://scripts/data/ext/uiterlijk.gd")
const GearData := preload("res://scripts/data/ext/uitrusting.gd")
var samples: Array = []
var cell_size := 64
var columns := 32

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)

func _draw() -> void:
	var dirs := [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]
	for index in samples.size():
		var e: Dictionary = samples[index]
		var center := Vector2((index%columns)*cell_size+cell_size/2,(index/columns)*cell_size+cell_size/2)
		var row: int = e.get("row",0)
		var column: int = e.get("column",0)
		facing=dirs[row]; attack_direction=facing; bow_direction=facing; work_facing=facing; roll_dir=facing
		var progress: float = e.get("progress",0.0)
		GameState.appearance={"gender":"m","hair":e.get("hair","m_kort"),"hair_color":2,"eyes":e.get("eyes","rond"),"eye_color":e.get("eyeColor",0)}
		GameState.clothing={}; GameState.equipment={}; GameState.inventory={}; GameState.weapon=""
		if e.has("clothing"):
			var item: String=e.clothing
			GameState.clothing[AppearanceData.ITEMS[item].slot]={"item":item,"dye":0}
		if e.has("gear"):
			var item: String=e.gear
			GameState.equipment[GearData.ITEMS[item].slot]=item
			GameState.inventory[item]=1
		draw_set_transform(center)
		match e.mode:
			"appearance", "roll":
				if e.mode=="roll":
					roll_timer=ROLL_TIME*(1.0-progress)
					var transform:=body_visual_transform()
					transform.origin+=center
					draw_set_transform_matrix(transform)
				AppearanceDraw.behind(self,Vector2(-16,-16),2.0,row,GameState.clothing)
				DrawUtil.sprite(self,Art.tex("player"),column,row,Vector2.ZERO,Vector2i(16,16),2.0)
				AppearanceDraw.front(self,Vector2(-16,-16),2.0,row,column,GameState.appearance,GameState.clothing)
				super._draw_equipped_gear()
				roll_timer=0.0
			"eyes": NativeLayers.eyes(self,Vector2(-16,-16),2.0,row,GameState.appearance)
			"sword":
				GameState.weapon=e.weapon
				attack_timer=ATTACK_TIME*(1.0-progress)
				combo_sweep=e.sweep
				super._draw_sword()
			"bow":
				bow_anim=BOW_ANIM_TIME*(1.0-progress)
				super._draw_bow()
			"work":
				work_kind=e.kind; work_elapsed=progress; work_duration=1.0
				super._draw_work()
			"waterfall": WaterReference.fall(self,progress)
			"rock": WaterReference.rock(self,Vector2(-24,-20),Vector2(48,40),e.pale)
			"crop": GardenReference.crop(self,Vector2(-16,-16),{"crop":e.crop,"growth":e.growth,"fertilized":e.fertilized},1.0,progress)
	draw_set_transform_matrix(Transform2D.IDENTITY)
