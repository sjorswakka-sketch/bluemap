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
 "forest:ruins":([49,11],[2,1], "A"),
 "forest:cave":([48,31],[2,1], "E"),
 "cave:forest":([4,33],[2,1], "E"),
}
for key,(pos,size,char) in DOORS.items():
    id = key.split(":")[0]
    PORTALS[key] = {"pos":pos,"size":size}
    rect(id,*pos,*size,char)
# The torch belongs beside the enlarged arena gate.
EXTRAS["village"] = [{"type":"torch","old":[34,4],"pos":[35,4]}]
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

# Portals need a two-wide walkable aperture, including old one-tile cave steps.
# Existing special 3-wide temple seals remain spacious and retain their lock.
PASSABLE=set(".zfaeLUj2s6,c_rdwQJ%m:*>=9DAETnif")
for id,d in data.items():
    for o in d["objects"]:
        if o["type"]!="portal" or not o.get("enabled",True):continue
        key=id+":"+o["to"]
        p=PORTALS.setdefault(key,{"pos":o["pos"][:],"size":o.get("size",[1,1])[:]})
        p["size"][0]=max(2,p["size"][0])
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

patches={}
for id,rr in rows.items():
    changes=[[x,y,c] for y,r in enumerate(rr) for x,c in enumerate(r) if c!=original[id][y][x]]
    if changes:patches[id]=changes
report={"changed_tiles":sum(map(len,patches.values())),"maps":{id:len(p) for id,p in patches.items()},"tight_decorative_spurs":uncovered,"tight_corners":blocked_corners,"anchor_bottlenecks":anchor_bottlenecks}
(ROOT/"tools/route-repair-report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
src='''extends RefCounted
## Authored calm route repairs. Object array order and collectible keys never change.
## Regenerate with tools/build_route_repairs.py; inspect tools/route-repair-report.json.
'''
for name,value in [("CELLS",patches),("PORTALS",PORTALS),("SPAWNS",SPAWNS),("SIGNS",SIGNS),("PROPS",EXTRAS)]:
    src+="const "+name+":="+json.dumps(value,ensure_ascii=False,separators=(",",":"))+"\n"
src+='''
static func enrich(id: String,data: Dictionary) -> void:
 for entry: Array in CELLS.get(id,[]):
  var row: String=data.rows[entry[1]];row[entry[0]]=entry[2];data.rows[entry[1]]=row
 for obj: Dictionary in data.objects:
  if obj.type=="portal":
   var route: Dictionary=PORTALS.get(id+":"+str(obj.to),{})
   if not route.is_empty():obj.pos=route.pos.duplicate();obj["size"]=route.size.duplicate()
  elif obj.type=="sign":
   for sign: Dictionary in SIGNS.get(id,[]):
    if obj.pos==sign.old:obj.pos=sign.pos.duplicate();obj.lines=sign.lines.duplicate()
  for prop: Dictionary in PROPS.get(id,[]):
   if obj.type==prop.type and obj.pos==prop.old:obj.pos=prop.pos.duplicate()
 for spawn: String in SPAWNS.get(id,{}):data.spawns[spawn]=SPAWNS[id][spawn].duplicate()
'''
(ROOT/"scripts/data/route_repairs.gd").write_text(src,encoding="utf-8")
print(json.dumps(report))
