extends RefCounted
## Final authored access repair: run after forage generation to keep its saved IDs and slots.
const Forest := preload("res://scripts/maps/forest.gd")
const ROAD_AREAS := [Rect2i(8,21,6,2),Rect2i(8,23,2,7),Rect2i(8,28,6,2),Rect2i(12,25,2,5)]

static func cell(data: Dictionary, x: int, y: int, value: String) -> void:
 var row: String = data.rows[y]
 row[x] = value
 data.rows[y] = row

static func enrich(id: String, data: Dictionary) -> void:
 if id == "watchyard":
  for obj: Dictionary in data.objects:
   if obj.type == "portal" and obj.to == "forest":obj.pos=[13,20];obj["size"]=[2,2]
  return
 if id != "forest":return
 # Remove the obsolete west-edge spur, restoring only cells it originally replaced.
 for y in range(20,29):
  for x in range(2,7):cell(data,x,y,Forest.DATA.rows[y][x])
 # The original x12/13 road now bends around the little south-facing entrance.
 for y in range(23,26):
  for x in [12,13]:cell(data,x,y,".")
 for area: Rect2i in ROAD_AREAS:
  for y in range(area.position.y,area.end.y):
   for x in range(area.position.x,area.end.x):cell(data,x,y,",")
 # Three short sides frame just the transition; the south stays fully two tiles open.
 for x in range(11,15):cell(data,x,24,"|")
 for y in [25,26]:
  for x in [11,14]:cell(data,x,y,"|")
 data.spawns["from_watchyard"]=[12,28]
 for obj: Dictionary in data.objects:
  if obj.type == "portal" and obj.to == "watchyard":obj.pos=[12,25];obj["size"]=[2,2]
  elif obj.type == "combat_post" and obj.get("kind","") == "entrance":
   obj.pos=[15,26]
   obj["entry_pos"]=[12,25]
   obj["entry_size"]=[2,2]
   obj["entry_direction"]=[0,-1]
  elif obj.type == "sign" and obj.pos == [2,26]:obj.pos=[10,25]
  elif obj.type == "enemy" and obj.pos == [14,29]:obj.pos=[19,29]
  elif obj.type == "enemy" and obj.pos == [12,28]:obj.pos=[19,32]
  # Keep the existing nut patch clear of the new east gatepost, with the same regrowth ID.
  elif obj.get("id","") == "forestfood:forest:chestnut":obj.pos=[15,21]
