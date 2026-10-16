extends RefCounted
## Crop rules and spatial footprints shared by simulation, art and yard validation.
const CROPS:={
 "grape":{"seed":"hs_seed","seconds":90.0,"output":"hs_grape","yield":3,"bonus":2},
 "flower":{"seed":"hs_flower_seed","seconds":60.0,"output":"hs_flower_seed","yield":1,"bees":true},
 "carrot":{"seed":"or_carrot_seed","seconds":70.0,"output":"or_carrot","yield":3,"bonus":1,"annual":true,"frame":0,"group":0},
 "pumpkin":{"seed":"or_pumpkin_seed","seconds":140.0,"output":"or_pumpkin","yield":2,"bonus":1,"annual":true,"frame":1,"group":0},
 "mint":{"seed":"or_mint_seed","seconds":85.0,"regrow":65.0,"output":"or_mint","yield":2,"bonus":1,"bees":true,"frame":2,"group":1},
 "rosemary":{"seed":"or_rosemary_seed","seconds":110.0,"regrow":80.0,"output":"or_rosemary","yield":2,"bonus":1,"bees":true,"frame":3,"group":1},
 "apple":{"seed":"or_apple_seed","seconds":240.0,"regrow":150.0,"output":"or_apple","yield":4,"bonus":2,"tree":true,"group":2},
 "berry":{"seed":"or_berry_seed","seconds":130.0,"regrow":95.0,"output":"prof_berry","yield":3,"bonus":1,"frame":4,"group":2}
}
const NAMES:={"carrot":"Wortels","pumpkin":"Pompoen","mint":"Tuinmunt","rosemary":"Rozemarijn","apple":"Appelboom","berry":"Bosbessenstruik"}
const NOTES:={
 "carrot":"Snelle groente voor onderweg. Eén tegel; oogsten geeft wortels en één zakje zaad terug.",
 "pumpkin":"Langzamer rijpende pompoen voor stoofpot. Eén tegel; zaad komt met de oogst terug.",
 "mint":"Blijvend kruid voor muntthee. Laat bloeiende munt staan als voedsel voor bijen.",
 "rosemary":"Blijvend kruid voor balsem bij de alchemietafel. Bloeiende rozemarijn voedt ook bijen.",
 "apple":"Een blijvende fruitboom met vrije kroonruimte van drie bij drie tegels. Water bereikt de wortels binnen twee tegels; pluk daarna opnieuw zonder herplanten.",
 "berry":"Een lage struik op één tegel. Bosbessen groeien opnieuw aan en passen in de bestaande bessensnack en energie-elixer."
}
const PRICES:={"grape":3,"flower":3,"carrot":4,"pumpkin":5,"mint":6,"rosemary":6,"apple":16,"berry":10}
const STARTER:={"or_carrot_seed":2,"or_pumpkin_seed":2,"or_mint_seed":2,"or_rosemary_seed":2,"or_apple_seed":1,"or_berry_seed":1}
const GROUPS:=["Groenten","Kruiden","Fruit en struiken"]
static func tree_cover(at: Vector2i,cells: Dictionary) -> Vector2i:
 for id: String in cells:
  if cells[id].get("crop","")!="apple":continue
  var pair:=id.split(",")
  if pair.size()!=2:continue
  var center:=Vector2i(int(pair[0]),int(pair[1]))
  if Rect2i(center-Vector2i.ONE,Vector2i(3,3)).has_point(at):return center
 return Vector2i(-99,-99)
static func duration(entry: Dictionary) -> float:
 var info: Dictionary=CROPS[entry.crop]
 return float(info.get("regrow",info.seconds)) if entry.get("established",false) else float(info.seconds)
static func amount(entry: Dictionary) -> int:
 var info: Dictionary=CROPS[entry.crop]
 return int(info.yield)+(int(info.get("bonus",0)) if entry.get("fertilized",false) else 0)
