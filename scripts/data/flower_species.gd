extends RefCounted
## Replace only existing wildflower verges. Same index, ID and regrowth;
## an occluded patch moves only to its nearest safe open verge.
## player-grown flowers, quest herbs and every other collectible remain untouched.
const Placement:=preload("res://scripts/core/forage_placement.gd")
const Legacy:=preload("res://scripts/data/ext/beroepen.gd")
const Data:=preload("res://scripts/data/ext/flower_species.gd")
const REGION_SPECIES:={
 "village":"daisy",
 "forest":"bluebell",
 "forest_edge":"foxglove",
 "steampeak":"edelweiss",
 "river_mouth":"sea_aster",
 "harbor":"hollyhock",
 "headland":"thrift",
 "tide_cove":"sea_lavender",
 "coast":"horned_poppy",
 "gull_island":"sea_campion",
 "lake":"yellow_iris",
 "dauwbos":"forget_me_not",
 "ijsdal":"snowdrop",
 "dorstvallei":"desert_marigold",
 "kruipmoeras":"loosestrife",
 "ridgepass":"alpine_aster",
}
static func kind_for(id: String,data: Dictionary) -> String:
 if REGION_SPECIES.has(id):return "flower_"+str(REGION_SPECIES[id])
 # Future route patches can still use the generic seed kind without showing
 # a nameless flower; current maps all have explicit regional assignments.
 if data.get("weather","")=="snow":return "flower_snowdrop"
 return "flower_daisy"
static func enrich(id: String,data: Dictionary):
 for obj: Dictionary in data.objects:
  if obj.type=="profession_resource" and obj.get("kind","")=="trail_flowers":
   obj.kind=kind_for(id,data)
   obj["wild_category"]="flower"
   if data.has("rows"):
    # The old east verge is now the two-wide road plus the map-edge canopy.
    # Keep this saved patch on the nearest open north verge of the same street.
    if id=="village" and obj.get("id","")=="trail:village:37:9" and not Placement.canopy_clear(data,Vector2i(obj.pos[0],obj.pos[1])):
     if Placement.safe(data,Vector2i(28,12),obj,id,Legacy.resource_objects(id)):obj.pos=[28,12]
    Placement.relocate(data,obj,id,Legacy.resource_objects(id))
