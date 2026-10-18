#!/usr/bin/env python3
"""Reproduce the authored four-terrace Dampkroon map, including all safe routes."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
grid=[list('X'*72) for _ in range(64)]
def rect(x,y,w,h,char):
    for yy in range(y,y+h):
        for xx in range(x,x+w):grid[yy][xx]=char
def terrain(x,y,w,h):
    rect(x,y,w,h,'z')
    # Small wind-combed patches, never solid or busy.
    for yy in range(y,y+h):
        for xx in range(x,x+w):
            if (xx*17+yy*11)%53==0:grid[yy][xx]='f'
for bounds in [(3,47,66,15),(9,30,54,14),(16,14,40,13),(22,3,28,8)]:
    terrain(*bounds)
    # Clip the corners into natural shelves instead of four perfect rectangles.
    x,y,w,h=bounds
    for dy in range(2):
        for dx in range(2-dy):
            grid[y+dy][x+dx]='X';grid[y+dy][x+w-1-dx]='X'
            grid[y+h-1-dy][x+dx]='X';grid[y+h-1-dy][x+w-1-dx]='X'
# The entry and winding ascent are exactly two tiles wide, including turns.
for bounds in [(35,53,2,11),(18,53,19,2),(18,39,2,16),(18,39,35,2),(51,21,2,20),(24,21,29,2),(24,8,2,15),(24,8,13,2),(35,4,2,6)]:rect(*bounds,',')
stairs=[[18,44,2,3],[51,27,2,3],[24,11,2,3]]
hints=[]
def basin(x,y,rows,kind,rocks):
    cells=[]
    for dy,row in enumerate(rows):
        for dx,c in enumerate(row):
            if c=='~':grid[y+dy][x+dx]='~';cells.append([x+dx,y+dy])
    assert len(cells)>=7 and len(cells)%2
    for xx,yy in rocks:grid[yy][xx]='o'
    hints.append({'kind':kind,'at':cells[len(cells)//2],'bank_rocks':rocks})
basin(49,51,['..~~~..','.~~~~~.','~~~~~~~','.~~~~~.','..~~~..'],'hot_spring',[[49,51],[55,51],[48,53]]) #23
basin(29,32,['.~~~.','~~~~~','~~~~~','.~~~.','..~..'],'hot_spring',[[28,32],[34,32],[28,35]]) #17
basin(37,15,['.~~~.','~~~~~','.~~~.'],'hot_spring',[[36,15],[42,15],[36,17]]) #11
basin(12,33,['.~~','~~~','~~.'],'geyser',[[11,33],[15,33],[11,35]])
basin(44,5,['.~~','~~~','~~.'],'geyser',[[43,5],[47,5],[43,7]])
# Frosted rock gardens frame the lower approach, well away from the path.
for x,y,c in [(7,57,'P'),(9,59,'P'),(62,58,'P'),(64,56,'P'),(12,50,'o'),(59,48,'o'),(11,38,'P'),(60,40,'P'),(19,17,'P'),(53,24,'P'),(29,5,'o'),(40,9,'o')]:grid[y][x]=c
# A small frozen runoff bowl is clearly different from the steaming water.
for y,row in enumerate(['..iii..','.iiiii.','iiiiiii','.iiiii.','..iii..']):
    for x,c in enumerate(row):
        if c=='i':grid[48+y][30+x]='i'
objects=[
    {'type':'portal','pos':[35,62],'size':[2,2],'to':'ijsdal','spawn':'from_steampeak'},
    {'type':'mountain_scenery','pos':[0,0]},
    {'type':'sign','pos':[32,58],'lines':['Dampkroon · Bergvoet','Drie brede bergtrappen voeren je over vier terrassen naar de top. De warme bronnen liggen in de beschutte kommen naast het pad.']},
    {'type':'sign','pos':[55,38],'lines':['Dampkroon · Stoomterrassen','De geisers zijn decoratief. Rust vijftien seconden aan de warmwaterbron om één hartje te herstellen. Blijven lopen onderbreekt de rust.']},
    {'type':'sign','pos':[33,5],'lines':['Dampkroon · Stille top','Beneden bewegen de roodkopapen tussen warme rotsen en sneeuw. Er is geen haast: hetzelfde brede pad brengt je terug naar IJsdal.']},
    {'type':'savepoint','pos':[38,7],'spawn':'summit'},
]
for p in [[47,54],[56,55],[35,35],[39,19],[43,20]]:
    objects.append({'type':'enemy','kind':'trail_macaque','pos':p,'patrol_radius':64.0,'trail_wildlife':True})
objects.append({'type':'sign','pos':[33,60],'lines':['Zuidelijk bergpad: IJsdal','De brede weg daalt terug naar het dorpsplein van IJsdal.']})

data={
 'name':'Dampkroon','music':'forest','outdoor':True,'weather':'snow',
 'rows':[''.join(row) for row in grid],
 'spawns':{'start':[35,59],'from_ijsdal':[35,59],'summit':[36,7]},
 'mountain_stairs':stairs,
 'mountain_terraces':[{'name':'Bergvoet','level':0,'bounds':[3,47,66,15]},{'name':'Stoomterrassen','level':1,'bounds':[9,30,54,14]},{'name':'Apenbronnen','level':2,'bounds':[16,14,40,13]},{'name':'Stille top','level':3,'bounds':[22,3,28,8]}],
 'water_hints':hints,'objects':objects,
}
(ROOT/'scripts/maps/steampeak.gd').write_text('extends RefCounted\n## Original four-level mountain; generator: tools/build_mountain_layout.py.\nconst DATA := '+json.dumps(data,ensure_ascii=False,indent=1).replace('true','true')+'\n',encoding='utf8')
print('Mountain layout written:',len(grid[0]),'x',len(grid),'; five geothermal basins; four terraces')
