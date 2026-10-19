#!/usr/bin/env python3
"""Author repeatable road/door repairs from the pre-route map survey.

The release reads only the resulting sparse patches. This is not a per-frame
terrain guess: old collectible slots and quest gates are retained.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools/map-water-source.json"
NATURAL = set(".zfaeLUj2s456i,")
THINNABLE = set("#bGPtR")
STRUCTURE = set("WHh^NZMCISBx|+!-VXZyKvquo7")
PORTALS = {}
SPAWNS = {}
SIGNS = {}
EXTRAS = {}
# This is an authored policy, not a rule inferred from a room's tiles. Public
# buildings/open country retain broad approaches; dungeon mouths stay narrow.
ENTRY_PAIRS = {
    "dungeon": [
        ("forest","ruins"),("forest","cave"),("cave","prismamine"),
        ("prismamine","resonance"),("kruipmoeras","reedvault"),
        ("river_mouth","tidal_hollow"),("village","temple"),
        ("temple","depths1"),("depths1","depths2"),
    ],
    "building": [
        ("village","smithy"),("village","shop"),("village","inn"),
        ("village","player_home"),("village","arena_hall"),
        ("arena_hall","arena"),("lake","fisher_hut"),("lake","library"),
        ("harbor","coast_workshop"),
    ],
    "open_area": [
        ("forest","forest_edge"),("forest","watchyard"),("forest","dauwbos"),
        ("dauwbos","ijsdal"),("dauwbos","dorstvallei"),("dauwbos","mistgarden"),
        ("dorstvallei","sunwell"),("ijsdal","ridgepass"),("ijsdal","steampeak"),
        ("forest_edge","village"),("village","lake"),("lake","coast"),
        ("lake","kruipmoeras"),("coast","river_mouth"),("river_mouth","harbor"),
        ("harbor","headland"),("gull_island","tide_cove"),
    ],
}
ENTRY_CLASSES = {}
for kind, pairs in ENTRY_PAIRS.items():
    for a,b in pairs:
        for key in [a+":"+b,b+":"+a]:
            if key in ENTRY_CLASSES:raise RuntimeError("Duplicate entrance classification: "+key)
            ENTRY_CLASSES[key]=kind
ENTRY_WIDTHS={key:1 if kind=="dungeon" else 2 for key,kind in ENTRY_CLASSES.items()}
MOUTHS = {}
SEALS = {"temple":[{"pos":[11,0],"size":[1,2]}]}
data = json.loads(SOURCE.read_text(encoding="utf-8"))
rows = {id: [list(r) for r in d["rows"]] for id, d in data.items()}
water_source=(ROOT / "scripts/data/water_layouts.gd").read_text(encoding="utf-8")
water_changes=json.loads(water_source.split("const CHANGES:=",1)[1].split("\n",1)[0])
for water_id,entries in water_changes.items():
    for wx,wy,wc in entries:rows[water_id][wy][wx]=wc
original = {id: [r[:] for r in rr] for id, rr in rows.items()}


def put(id, x, y, c):
    rows[id][y][x] = c


def rect(id, x, y, w, h, c=","):
    for yy in range(y, y+h):
        for xx in range(x, x+w):
            put(id, xx, yy, c)


# Four water-covered squares have four bridge squares, never dirt over water.
rect("forest", 24, 17, 2, 2, "=")
# Main north/south marsh crossings match the two-wide mud approaches.
rect("kruipmoeras",23,11,2,4,"=")
rect("kruipmoeras",23,18,2,3,"=")
rect("kruipmoeras",23,10,2,1,"2")
rect("kruipmoeras",23,21,2,1,"2")
# The southern canal crossing previously reached only its first water column.
rect("village", 20, 41, 2, 2, "=")
rect("village",20,31,2,2,"=")
rect("village",20,37,2,2,"=")
rect("village", 22, 37, 2, 1, ",")
# Preserve the first, existing northbound route. Its destination is now north.
rect("forest", 10, 0, 2, 17)
PORTALS["forest:dauwbos"] = {"pos":[10,0], "size":[2,2]}
SPAWNS["forest"] = {"from_dauwbos":[10,3]}
SIGNS["forest"] = [{"old":[5,12],"pos":[13,3],"lines":["Noordelijk pad: Dauwbos","Mistig en stil. Mira bewaakt de dauw."]}]
# The matching return is on the south of Dew Woods, away from its north pass.
rect("dauwbos",24,21,2,16)
PORTALS["dauwbos:forest"] = {"pos":[24,35],"size":[2,2]}
SPAWNS["dauwbos"] = {"from_forest":[24,32]}
SIGNS["dauwbos"] = [{"old":[4,19],"pos":[22,33],"lines":["Zuidelijk pad: Fluisterbos","Waar de mist dunner wordt, beginnen de vertrouwde bomen."]}]
for y in range(18,23):
    if rows["dauwbos"][y][2] == ",":put("dauwbos",2,y,".")
# The eastern road is a real continuous road from the library forecourt.
rect("lake",32,8,12,2)
# Straighten the north approach into the existing two-wide main pier.
for y in range(0,14):
    if y not in [8,9] and rows["lake"][y][22] == ",":put("lake",22,y,".")
rect("lake",20,0,2,14)
PORTALS["lake:village"] = {"pos":[20,0],"size":[2,2]}
# village lake exit must sit exactly on its 18/19 approach.
PORTALS["village:lake"] = {"pos":[18,42],"size":[2,2]}

PORTALS["river_mouth:coast"]={"pos":[14,44],"size":[2,2]}
# These two trails run east/west on two terrain rows. Their triggers must cover
# both rows as well: two x-columns alone would leave the south lane inactive.
PORTALS["dauwbos:mistgarden"]={"pos":[43,30],"size":[2,2]}
PORTALS["ijsdal:ridgepass"]={"pos":[43,3],"size":[2,2]}

# Explicit door expansions retain each original object's index and lock.
# Buildings receive two matching door tiles; no side opening around a gate.
DOORS = {
 "village:smithy":([6,11],[2,1], "D"),
 "village:shop":([13,11],[2,1], "D"),
 "village:inn":([30,10],[2,1], "D"),
 "village:arena_hall":([33,4],[2,1], "n"),
 "village:player_home":([7,21],[2,1], "D"),
 "lake:fisher_hut":([8,6],[2,1], "D"),
 "lake:library":([32,6],[2,1], "D"),
}
for key,(pos,size,char) in DOORS.items():
    id = key.split(":")[0]
    PORTALS[key] = {"pos":pos,"size":size}
    rect(id,*pos,*size,char)
# The torch belongs beside the enlarged arena gate.
EXTRAS["village"] = [
    {"type":"torch","old":[34,4],"pos":[35,4]},
    # Keep both lanes of each public doorway clear of the lamp's real foot body.
    # Move the existing object, never append another lamp or renumber save keys.
    {"type":"wereld_lantaarn","old":[7,12],"pos":[8,12]},
    {"type":"wereld_lantaarn","old":[14,12],"pos":[15,12]},
    {"type":"wereld_lantaarn","old":[31,11],"pos":[32,11]},
]
# Short two-wide front steps connect actual doors to the established streets.
for id,x,y,w,h in [
 ("village",6,12,2,2),("village",13,12,2,2),
 ("village",30,11,2,3),("village",33,5,2,2),
 ("lake",8,7,2,2),("lake",32,7,2,2),
 ("forest",48,32,2,3)]:
    rect(id,x,y,w,h)

# Remove isolated dirt pixels rather than extending paving into a crop or pool.
put("dorstvallei",7,7,"a")
put("dorstvallei",12,15,"L")
put("dorstvallei",15,15,"L")
put("dorstvallei",43,26,",")
# A generated road had cut through a decorative IJsdal house. Restore the facade
# and put its broad bypass beside the house, leaving the door visible.
put("ijsdal",17,15,"^");put("ijsdal",18,15,"^")
put("ijsdal",17,16,"H");put("ijsdal",17,17,"H")
rect("ijsdal",20,15,2,8)
rect("ijsdal",17,21,5,2)
EXTRAS["forest"]=[{"type":"chest","old":[10,4],"pos":[8,4]}]
EXTRAS["dauwbos"]=[{"type":"sign","old":[42,31],"pos":[46,31]}]
EXTRAS["ijsdal"]=[{"type":"sign","old":[41,4],"pos":[39,4]}]

# Every existing terrain road square must belong to a 2x2 road shoulder.
# Sparse additions favor open ground, never reclaim water or remove masonry.
# Squares containing a portal/door/bridge also count as continuous road width.
ROAD = set(",=9DAETn")
uncovered = {}
protected_by_map = {}
for id,d in data.items():
    rr=rows[id]; h=len(rr); w=len(rr[0])
    protected = set()
    for o in d["objects"]:
        if not o.get("enabled",True):continue
        if o["type"] in ["profession_resource","npc","chest","savepoint","home_station","sign","torch","living_object","regional_object","combat_post","supper_object"]:
            if o.get("id","").startswith("trail:"):continue
            protected.add(tuple(o["pos"]))
    # A static authored contour must not overwrite the next water-enrichment pass.
    if id=="forest_edge":
        protected.update([(29,13),(30,13),(31,13),(32,13),(33,13),(29,14),(30,14),(31,14),(32,14),(33,14)])
    if id=="ijsdal":
        protected.update([(33,3),(34,3),(32,4),(33,4),(34,4),(32,5),(33,5)])
    if id=="ridgepass":
        protected.update([(23,9),(24,9),(22,10),(23,10),(24,10),(22,11),(23,11)])
    protected_by_map[id]=protected
    seeds=[(x,y) for y,r in enumerate(rr) for x,c in enumerate(r) if c==","]
    missing=[]
    for x,y in seeds:
        candidates=[]
        for dx,dy in [(0,0),(-1,0),(0,-1),(-1,-1)]:
            cells=[(xx,yy) for yy in [y+dy,y+dy+1] for xx in [x+dx,x+dx+1]]
            if any(not(0<=xx<w and 0<=yy<h) for xx,yy in cells):continue
            if all(rr[yy][xx] in ROAD for xx,yy in cells):
                candidates=[(-1,[])];break
            cost=0;add=[];valid=True
            for xx,yy in cells:
                c=rr[yy][xx]
                if c in ROAD:continue
                if (xx,yy) in protected or c not in NATURAL | THINNABLE:
                    valid=False;break
                # Never grow road out along a map's border unless that exit already exists.
                if xx in [0,w-1] or yy in [0,h-1]:
                    valid=False;break
                cost += 1 if c in NATURAL else 12
                add.append((xx,yy))
            if valid:candidates.append((cost,add))
        if candidates:
            _,add=min(candidates,key=lambda item:item[0])
            for xx,yy in add:rr[yy][xx]=","
        else:missing.append([x,y])
    if missing:uncovered[id]=missing

# Apply the explicit pair classification. No portal may silently fall back to a
# broad dungeon mouth or a narrow ordinary doorway.
PASSABLE=set(".zfaeLUj2s6,c_rdwQJ%m:*>=9DAETnif")
for id,d in data.items():
    for o in d["objects"]:
        if o["type"]!="portal" or not o.get("enabled",True):continue
        key=id+":"+o["to"]
        p=PORTALS.setdefault(key,{"pos":o["pos"][:],"size":o.get("size",[1,1])[:]})
        if key not in ENTRY_WIDTHS:raise RuntimeError("Unclassified entrance: "+key)
        p["size"][0]=ENTRY_WIDTHS[key]
        w=len(rows[id][0]);h=len(rows[id])
        p["pos"][0]=min(p["pos"][0],w-p["size"][0])
        p["pos"][1]=min(p["pos"][1],h-p["size"][1])
        for yy in range(p["pos"][1],p["pos"][1]+p["size"][1]):
            for xx in range(p["pos"][0],p["pos"][0]+p["size"][0]):
                if rows[id][yy][xx] in PASSABLE:continue
                if rows[id][yy][xx] in "~F38":raise RuntimeError("Portal must align with its existing pier: "+key+str([xx,yy]))
                # Preserve each type of indoor floor and outdoor regional substrate.
                floor="," if id in ["village","forest","forest_edge","dauwbos","ijsdal","lake"] else "c" if id in ["cave","prismamine"] else "r" if id=="ruins" else "d" if id.startswith("depths") else "a" if id=="sunwell" else "U" if id=="kruipmoeras" else "."
                put(id,xx,yy,floor)

# A pair of diagonally touching 2x2 blocks still pinches to one tile at the
# bend. Fill the cheaper of the two joining shoulders, retaining water/props.
blocked_corners = {}
for id,rr in rows.items():
    h=len(rr);w=len(rr[0]);protected=protected_by_map[id]
    def anchor(x,y):
        return 0<=x<w-1 and 0<=y<h-1 and all(rr[yy][xx] in ROAD for yy in [y,y+1] for xx in [x,x+1])
    for turn in range(20):
        repaired=0
        for y in range(h-2):
            for x in range(w-2):
                for dx,dy in [(1,1),(1,-1)]:
                    bx=x+dx;by=y+dy
                    if not anchor(x,y) or not anchor(bx,by) or anchor(bx,y) or anchor(x,by):continue
                    candidates=[]
                    for ax,ay in [(bx,y),(x,by)]:
                        cells=[(xx,yy) for yy in [ay,ay+1] for xx in [ax,ax+1] if rr[yy][xx] not in ROAD]
                        if any((xx,yy) in protected or rr[yy][xx] not in NATURAL|THINNABLE or xx in [0,w-1] or yy in [0,h-1] for xx,yy in cells):continue
                        cost=sum(1 if rr[yy][xx] in NATURAL else 12 for xx,yy in cells)
                        candidates.append((cost,cells))
                    if candidates:
                        _,cells=min(candidates,key=lambda c:c[0])
                        for xx,yy in cells:rr[yy][xx]=","
                        repaired+=1
        if not repaired:break
    for y in range(h-2):
        for x in range(w-2):
            for dx,dy in [(1,1),(1,-1)]:
                if anchor(x,y) and anchor(x+dx,y+dy) and not anchor(x+dx,y) and not anchor(x,y+dy):
                    blocked_corners.setdefault(id,[]).append([x,y,dx,dy])

# Require the 2x2 path anchors themselves to connect by cardinal steps.
# This closes the less obvious (2,1) offsets as well as diagonal corners.
# Search only the immediate shoulder of an existing road; never cut a new
# shortcut through the world or reclaim water to satisfy a geometric test.
import heapq
anchor_bottlenecks={}
for id,rr in rows.items():
    h=len(rr);w=len(rr[0]);protected=protected_by_map[id]
    def components(points):
        pending=set(points);result=[]
        while pending:
            seed=pending.pop();group={seed};stack=[seed]
            while stack:
                x,y=stack.pop()
                for q in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                    if q in pending:pending.remove(q);group.add(q);stack.append(q)
            result.append(group)
        return result
    for iteration in range(100):
        surface={(x,y) for y,r in enumerate(rr) for x,c in enumerate(r) if c in ROAD}
        road_groups=components(surface);changed=False
        for road in road_groups:
            anchors={(x,y) for x,y in road if x<w-1 and y<h-1 and all((xx,yy) in road for yy in [y,y+1] for xx in [x,x+1])}
            groups=components(anchors)
            if len(groups)<2:continue
            start=max(groups,key=len);goals=anchors-start
            candidates={}
            for x,y in road:
                for ax,ay in [(x,y),(x-1,y),(x,y-1),(x-1,y-1)]:
                    if not(0<=ax<w-1 and 0<=ay<h-1) or (ax,ay) in candidates:continue
                    add=[(xx,yy) for yy in [ay,ay+1] for xx in [ax,ax+1] if rr[yy][xx] not in ROAD]
                    if any((xx,yy) in protected or rr[yy][xx] not in NATURAL|THINNABLE or xx in [0,w-1] or yy in [0,h-1] for xx,yy in add):continue
                    candidates[(ax,ay)]=(sum(1 if rr[yy][xx] in NATURAL else 12 for xx,yy in add),add)
            queue=[(0,p) for p in start];heapq.heapify(queue);cost={p:0 for p in start};before={};finish=None
            while queue:
                distance,p=heapq.heappop(queue)
                if distance!=cost[p]:continue
                if p in goals:finish=p;break
                x,y=p
                for q in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                    if q not in candidates:continue
                    nd=distance+candidates[q][0]+.01
                    if nd<cost.get(q,1e9):cost[q]=nd;before[q]=p;heapq.heappush(queue,(nd,q))
            if finish is None:
                anchor_bottlenecks.setdefault(id,[]).append([list(min(g)) for g in groups])
                continue
            path=[finish]
            while path[-1] not in start:path.append(before[path[-1]])
            for p in path:
                for xx,yy in candidates.get(p,(0,[]))[1]:rr[yy][xx]=","
            changed=True
            break
        if not changed:break

# Shape the actual mouths after road widening. The main approach remains two
# wide; only its final arch/stair opening narrows. Each jamb is real solid
# terrain, so an adjacent former doorway pixel cannot bypass a progression lock.
def mouth(key,pos,size,face,char,wall,jambs,back,approach):
    id=key.split(":")[0]
    PORTALS[key]={"pos":pos,"size":size}
    for x,y in jambs+back:put(id,x,y,wall)
    rect(id,*pos,*size,char)
    MOUTHS[key]={"pos":pos,"size":size,"face":face,"jambs":jambs,
                 "back":back,"approach":approach,"floor":char}

mouth("forest:ruins",[49,11],[1,1],"south","A","W",
      [[48,11],[50,11]],[[48,10],[49,10],[50,10]],[49,12])
mouth("forest:cave",[48,31],[1,1],"south","E","o",
      [[47,31],[49,31]],[[47,30],[48,30],[49,30]],[48,32])
mouth("cave:forest",[4,33],[1,1],"north","E","X",
      [[3,33],[5,33]],[[3,34],[4,34],[5,34]],[4,32])
mouth("cave:prismamine",[4,7],[1,1],"south","E","X",
      [[3,7],[5,7]],[[3,6],[4,6],[5,6]],[4,8])
mouth("prismamine:cave",[3,25],[1,1],"north","E","X",
      [[2,25],[4,25]],[[2,26],[3,26],[4,26]],[3,24])
mouth("prismamine:resonance",[36,5],[1,1],"west","E","X",
      [[36,4],[36,6]],[[37,4],[37,5],[37,6]],[35,5])
mouth("resonance:prismamine",[15,21],[1,1],"north","E","X",
      [[13,21],[14,21],[16,21],[17,21],[18,21]],[[15,22]],[15,20])
mouth("ruins:forest",[3,30],[1,1],"north","A","M",
      [[2,30],[4,30]],[[2,31],[3,31],[4,31]],[3,29])
# The archive island already owns a recessed one-tile stair drawing. Retain its
# open landing and unique sun-disk pickup rather than build a wall across it.
PORTALS["kruipmoeras:reedvault"]={"pos":[24,17],"size":[1,1]}
MOUTHS["kruipmoeras:reedvault"]={"pos":[24,17],"size":[1,1],"face":"south",
    "jambs":[],"back":[],"approach":[24,18],"floor":"U","recessed":True}
mouth("reedvault:kruipmoeras",[2,14],[1,1],"east","A","M",
      [[2,13],[2,15]],[[1,13],[1,14],[1,15]],[3,14])
mouth("river_mouth:tidal_hollow",[16,9],[1,1],"south","E","7",
      [[15,9],[17,9]],[[15,8],[16,8],[17,8]],[16,10])
# A short sea-wall tunnel opens onto the existing dry wetstone landing. Remove
# the decorative boardwalk over stone instead of leaving a broken half-deck;
# the real central boardwalk crossing over sea water is entirely unchanged.
rect("tidal_hollow",0,29,3,2,"0")
mouth("tidal_hollow:river_mouth",[0,29],[1,1],"east","0","1",
      [[0,28],[0,30]],[[1,30]],[2,29])
mouth("village:temple",[19,6],[1,1],"south","T","Z",
      [[18,6],[20,6]],[[19,5]],[19,7])
mouth("temple:village",[11,21],[1,1],"north","T","Z",
      [[10,21],[12,21]],[],[11,20])
mouth("temple:depths1",[11,0],[1,2],"south",">","Z",
      [[10,0],[10,1],[12,0],[12,1]],[],[11,2])
mouth("depths1:temple",[6,28],[1,1],"north",">","V",
      [[5,28],[7,28]],[],[6,27])
mouth("depths1:depths2",[22,1],[1,2],"south",">","V",
      [[21,1],[21,2],[23,1],[23,2]],[[22,0]],[22,3])
mouth("depths2:depths1",[13,22],[1,1],"north",">","V",
      [[12,22],[14,22]],[],[13,21])

# Steampeak is authored after the frozen survey; the other exceptional entrance
# is the harbour workshop's interaction door. Both are ordinary broad entries.
PORTALS["ijsdal:steampeak"]={"pos":[24,0],"size":[2,2]}
PORTALS["steampeak:ijsdal"]={"pos":[35,62],"size":[2,2]}
PORTALS["harbor:coast_workshop"]={"pos":[55,22],"size":[2,1]}

patches={}
for id,rr in rows.items():
    changes=[[x,y,c] for y,r in enumerate(rr) for x,c in enumerate(r) if c!=original[id][y][x]]
    if changes:patches[id]=changes
report={"changed_tiles":sum(map(len,patches.values())),"maps":{id:len(p) for id,p in patches.items()},"entry_pairs":ENTRY_PAIRS,"narrow_mouths":len(MOUTHS),"tight_decorative_spurs":uncovered,"tight_corners":blocked_corners,"anchor_bottlenecks":anchor_bottlenecks}
(ROOT/"tools/route-repair-report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
src='''extends RefCounted
## Authored calm route repairs. Object array order and collectible keys never change.
## Regenerate with tools/build_route_repairs.py; inspect tools/route-repair-report.json.
'''
for name,value in [("CELLS",patches),("PORTALS",PORTALS),("ENTRY_CLASSES",ENTRY_CLASSES),("ENTRY_WIDTHS",ENTRY_WIDTHS),("MOUTHS",MOUTHS),("SEALS",SEALS),("SPAWNS",SPAWNS),("SIGNS",SIGNS),("PROPS",EXTRAS)]:
    src+="const "+name+":="+json.dumps(value,ensure_ascii=False,separators=(",",":"))+"\n"
src+='''
static func enrich(id: String,data: Dictionary) -> void:
 for entry: Array in CELLS.get(id,[]):
  var row: String=data.rows[entry[1]];row[entry[0]]=entry[2];data.rows[entry[1]]=row
 for obj: Dictionary in data.objects:
  if obj.type=="portal" or obj.get("travel_link",false):
   var route: Dictionary=PORTALS.get(id+":"+str(obj.to),{})
   if not route.is_empty():obj.pos=route.pos.duplicate();obj["size"]=route.size.duplicate()
  elif obj.type=="sign":
   for sign: Dictionary in SIGNS.get(id,[]):
    if obj.pos==sign.old:obj.pos=sign.pos.duplicate();obj.lines=sign.lines.duplicate()
  elif obj.type=="diepte_seal":
   for seal: Dictionary in SEALS.get(id,[]):
    if obj.pos==seal.pos:obj["size"]=seal.size.duplicate()
  for prop: Dictionary in PROPS.get(id,[]):
   if obj.type==prop.type and obj.pos==prop.old:obj.pos=prop.pos.duplicate()
 for spawn: String in SPAWNS.get(id,{}):data.spawns[spawn]=SPAWNS[id][spawn].duplicate()
'''
(ROOT/"scripts/data/route_repairs.gd").write_text(src,encoding="utf-8")
print(json.dumps(report))
