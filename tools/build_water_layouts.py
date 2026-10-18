"""Author deterministic natural-water contours without closing existing routes.
Input is tools/map-water-source.json exported from the fully composed maps.
Keeps old objects, doors, bridges, fishing banks and save/spawn cells intact.
"""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent.parent
maps=json.loads((ROOT/'tools/map-water-source.json').read_text(encoding='utf8'))
WET=set('~F38');SOLID=set('#~W|^Hh obtOxyXvMI NZCSB;lpVG PgqFRY3781'.replace(' ',''))
STEP=[(-1,0),(1,0),(0,-1),(0,1)]
changes={};features={};report={}
def neighbors(p):return [(p[0]+dx,p[1]+dy) for dx,dy in STEP]
def inside(rows,p):return 0<=p[1]<len(rows) and 0<=p[0]<len(rows[p[1]])
def wet(rows,p):return inside(rows,p) and rows[p[1]][p[0]] in WET
def comps(rows):
 unseen={(x,y) for y,row in enumerate(rows) for x,c in enumerate(row) if c in WET};result=[]
 while unseen:
  first=min(unseen,key=lambda p:(p[1],p[0]));seen={first};q=[first];body=[]
  for p in q:
   if wet(rows,p):body.append(p);unseen.discard(p)
   for n in neighbors(p):
    if n in seen or not inside(rows,n):continue
    if wet(rows,n) or rows[n[1]][n[0]] in '=9':seen.add(n);q.append(n)
  result.append(body)
 return result
def protected(data,p,margin=1):
 x,y=p
 if x<2 or y<2 or y>=len(data['rows'])-2 or x>=len(data['rows'][y])-2:return True
 for o in data['objects']:
  if not o.get('enabled',True) or o.get('trail_wildlife') or str(o.get('id','')).startswith('trail:'):continue
  if o['type']=='trigger':continue
  ox,oy=o['pos'];sx,sy=o.get('size',[1,1]);m=margin+1 if o['type'] in ['portal','npc','chest','gate'] else margin
  if ox-m<=x<ox+sx+m and oy-m<=y<oy+sy+m:return True
 for sx,sy in data['spawns'].values():
  if abs(sx-x)+abs(sy-y)<=2:return True
 if p[0]<35 and data is maps.get('village') and y>=29:return True
 return False
def safe_remove(rows,p):
 # Removing a bank square must not disconnect its walkable neighbors.
 near=[n for n in neighbors(p) if inside(rows,n) and rows[n[1]][n[0]] not in SOLID]
 if len(near)<2:return True
 seen={near[0]};q=[near[0]]
 for a in q:
  for b in neighbors(a):
   if b!=p and inside(rows,b) and b not in seen and rows[b[1]][b[0]] not in SOLID:seen.add(b);q.append(b)
 return all(n in seen for n in near)
for id,data in maps.items():
 original=data['rows'];rows=[list(r) for r in original];extra=[]
 # Springs belong to the snowy fault line and the hot sandstone cleft.
 for kind,center in ([('hot_spring',(33,4))] if id=='ijsdal' else [('geyser',(31,5))] if id=='sunwell' else [('pool',(23,10))] if id=='ridgepass' else []):
  cx,cy=center;cells=[(cx+dx,cy+dy) for dy in [-1,0,1] for dx in [-1,0,1] if (dx,dy) not in [(-1,-1),(1,1)]]
  if any(protected(data,p,1) or not inside(rows,p) or rows[p[1]][p[0]] in ',=9DTHh^' for p in cells):raise SystemExit('Unsafe authored spring '+id)
  for x,y in cells:rows[y][x]='~'
  extra.append({'kind':kind,'at':[cx,cy],'cells':[list(p) for p in cells]})
 if id=='forest_edge':
  for x,y in [(30,13),(31,13),(32,13),(31,14)]:rows[y][x]='~'
  for x,y in [(29,13),(33,13),(29,14),(30,14),(32,14),(33,14)]:rows[y][x]='o'
 if id=='village':
  for x,y in [(36,19),(37,19),(35,20),(36,20),(37,20),(36,21)]:rows[y][x]='~'
  for x,y in [(34,19),(35,19),(34,20),(35,21)]:rows[y][x]='o'
 for body in comps(rows):
  target=max(7,len(body));target+=1 if target%2==0 else 0
  # The ice lake remains traversable ice, salt water remains salt water.
  value=rows[body[0][1]][body[0][0]]
  while len(body)<target:
   options={n for p in body for n in neighbors(p) if inside(rows,n) and not wet(rows,n)}
   options=[p for p in options if not protected(data,p) and rows[p[1]][p[0]] in '.#obzfaeULj2~F3i045678crk_d' and not any(wet(rows,n) and n not in body for n in neighbors(p))]
   # Prefer extending existing rock/tree banks: this never removes walking room.
   options.sort(key=lambda p:(rows[p[1]][p[0]] not in SOLID, -sum(n in body for n in neighbors(p)),p[1],p[0]))
   p=next((p for p in options if rows[p[1]][p[0]] in SOLID or safe_remove(rows,p)),None)
   if p is None:raise SystemExit('No safe odd contour '+id+' '+str((len(body),body[0]))+' '+str([(p,rows[p[1]][p[0]],protected(data,p)) for p in {n for b in body for n in neighbors(b) if inside(rows,n) and not wet(rows,n)}][:25]))
   rows[p[1]][p[0]]=value;body.append(p)
 delta=[[x,y,c] for y,row in enumerate(rows) for x,c in enumerate(row) if c!=original[y][x]]
 if delta:changes[id]=delta
 features[id]=extra
 bodies=comps(rows)
 if any(len(b)<7 or len(b)%2==0 for b in bodies):raise SystemExit('Invalid water contour '+id)
 report[id]={'changes':len(delta),'bodies':[len(b) for b in bodies]}
states={}
for state in [1,2,3]:
 data=maps['kruipmoeras'];rows=[list(r) for r in data['rows']]
 for x,y,c in changes.get('kruipmoeras',[]):rows[y][x]=c
 if state&1:
  for y in range(16,20):
   for x in range(27,34):
    if rows[y][x] in 'FRj':rows[y][x]='2'
  for y in [14,15]:
   for x in [31,32,33]:
    if rows[y][x] in 'FRj':rows[y][x]='2'
 if state&2:
  for y in [16,17]:
   for x in range(16,23):rows[y][x]='='
 original=[row[:] for row in rows]
 for tiny in comps(rows):
  if len(tiny)<7:
   for x,y in tiny:rows[y][x]='2'
 for body in comps(rows):
  if len(body)<7:
   for x,y in body:rows[y][x]='2'
  elif len(body)%2==0:
   options=[p for p in body if not protected(data,p,0)]
   options.sort(key=lambda p:(not any(inside(rows,n) and rows[n[1]][n[0]]=='2' for n in neighbors(p)),-p[0],p[1]))
   for x,y in options:
    c=rows[y][x];rows[y][x]='2';sizes=[len(b) for b in comps(rows)]
    if all(n>=7 and n%2 for n in sizes):break
    rows[y][x]=c
   else:raise SystemExit('No safe drained-bank contour '+str(state))
 states[str(state)]=[[x,y,c] for y,row in enumerate(rows) for x,c in enumerate(row) if c!=original[y][x]]
 report['marsh_state_'+str(state)]={'changes':len(states[str(state)]),'bodies':[len(b) for b in comps(rows)]}
(ROOT/'scripts/data/water_layouts.gd').write_text('extends RefCounted\n## Authored odd water contours; generated by tools/build_water_layouts.py.\nconst CHANGES:='+json.dumps(changes,separators=(',',':'),ensure_ascii=False)+'\nconst FEATURES:='+json.dumps(features,separators=(',',':'),ensure_ascii=False)+'\nconst STATE_CHANGES:='+json.dumps(states,separators=(',',':'))+'\n',encoding='utf8')
(ROOT/'tools/water-layout-report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report,indent=2))
