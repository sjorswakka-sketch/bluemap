extends RefCounted
## The field guide describes real authored plants, including saved legacy nodes.
## Cache untranslated IDs/coordinates; language switches stay immediate.
const Resources:=preload("res://scripts/data/ext/beroepen.gd")
static var _places: Dictionary={}
static var _ready:=false
static func build():
 if _ready:return
 _ready=true
 var maps=load("res://scripts/maps/registry.gd")
 for id: String in maps.MAPS:
  var data: Dictionary=maps.get_map(id)
  var objects: Array=data.objects.duplicate();objects.append_array(Resources.resource_objects(id))
  for obj: Dictionary in objects:
   if obj.type!="profession_resource" or not obj.get("enabled",true):continue
   var resource: Dictionary=Resources.RESOURCES.get(obj.get("kind",""),{})
   if resource.get("skill","")!="foraging":continue
   var item: String=resource.item
   if not _places.has(item):_places[item]=[]
   if not _places[item].any(func(p):return p.map==id):
    _places[item].append({"map":id,"pos":obj.pos.duplicate()})
static func locations(item: String) -> Array:
 build();return _places.get(item,[]).duplicate(true)
static func known(item: String) -> bool:
 build();return _places.has(item)
static func source(item: String,current_map: String) -> String:
 var places:=locations(item)
 if places.is_empty():return ""
 places.sort_custom(func(a,b):return a.map==current_map and b.map!=current_map)
 var labels: Array[String]=[]
 var maps=load("res://scripts/maps/registry.gd")
 for p: Dictionary in places.slice(0,2):
  labels.append(TranslationServer.translate("%s (%d, %d)") % [TranslationServer.translate(maps.MAPS[p.map].DATA.name),int(p.pos[0])+1,int(p.pos[1])+1])
 return ", ".join(labels)
