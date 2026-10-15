"""Original spacious coast region: landscapes, landmarks, residents and soft bell."""
from pathlib import Path
from PIL import Image,ImageDraw
from artlib import strip,outline
import json,math,random
import art_x_opening as sound
ROOT=Path(__file__).resolve().parent.parent
sound.ROOT=ROOT

def path(c,points,width=2):
 for a,b in zip(points,points[1:]):
  steps=max(abs(a[0]-b[0]),abs(a[1]-b[1]),1)
  for i in range(steps+1):
   x=round(a[0]+(b[0]-a[0])*i/steps);y=round(a[1]+(b[1]-a[1])*i/steps)
   for dy in range(width):
    for dx in range(width):
     xx,yy=x+dx,y+dy
     if 0<=yy<len(c) and 0<=xx<len(c[0]):c[yy][xx]='9' if c[yy][xx] in '389' else ','
def portal(pos,to,spawn,size=[2,2]):return dict(type='portal',pos=pos,to=to,spawn=spawn,size=size)
def sign(pos,*lines):return dict(type='sign',pos=pos,lines=list(lines))
def landmark(pos,frame,cells):return dict(type='region_landmark',pos=pos,frame=frame,cells=cells)
def chart(pos):return dict(type='region_chart',pos=pos)
def route(to,spawn):return dict(to=to,spawn=spawn)
def data(kind):
 w,h=(76,46) if kind!='harbor' else (74,46)
 c=[['3']*w for _ in range(h)]
 if kind=='river_mouth':
  for y in range(2,h-2):
   for x in range(2,w-2):
    bank=22+.45*y+3*math.sin(y*.18);width=3+.08*y
    shore=38+3*math.sin(x*.12)
    if y<shore and abs(x-bank)>width+1.5:c[y][x]='6' if y<shore-5 else '5'
    elif y<shore+1 and abs(x-bank)>width:c[y][x]='8' if y>shore or abs(x-bank)<width+1.5 else '4'
  for y in range(24,34):
   for x in range(46,70):
    if c[y][x]=='6' and math.sin(x*.31)+math.sin(y*.43)>1.35:c[y][x]='5'
  path(c,[(14,45),(14,32),(18,27),(20,19),(43,19),(55,18),(75,18)])
  for y in [18,19]:
   for x in range(22,41):c[y][x]='9'
  for y in [41,42]:
   for x in [12,13]:c[y][x]='9'
  # Dry fork along the western reed bank; no collecting props.
  path(c,[(14,32),(8,27),(9,15),(16,10)],1)
  for x,y in [(6,7),(7,7),(63,7),(64,8),(57,31),(58,31)]:c[y][x]='7'
  objects=[portal([13,44],'coast','from_estuary'),sign([12,42],'Zuidelijke oever: Blauwe Kust','Over de brug naar het oosten ligt Rietwenk Haven. Beide oevers blijven rustig.'),
   portal([74,18],'harbor','from_estuary'),sign([72,16],'Oostelijk pad: Rietwenk Haven','Een korte kade, twee werkplekken en de veer. De noordelijke route voert verder naar de kaap.'),
   chart([43,17])]
  name='Zilvermonding';spawns=dict(start=[14,42],from_coast=[14,42],from_harbor=[71,18])
 elif kind=='harbor':
  for y in range(2,h-2):
   for x in range(2,w-2):
    shoreline=32+3*math.sin(x*.13)
    if 27<x<59:shoreline-=6*math.sin((x-27)/32*math.pi)
    if y<shoreline-3:c[y][x]='6'
    elif y<shoreline:c[y][x]='4'
    elif y<shoreline+1:c[y][x]='8'
  path(c,[(0,18),(18,18),(29,23),(38,28),(46,28)])
  path(c,[(36,27),(38,16),(52,12),(73,14)])
  path(c,[(16,18),(20,9),(43,8),(52,12)],1)
  # Open working quay, never a ring of buildings.
  for y in range(22,30):
   for x in range(34,60):c[y][x]='4' if y>26 else '6'
  path(c,[(29,23),(39,27),(48,27),(57,24)])
  for y in range(29,33):
   for x in range(43,48):c[y][x]='9'
  for x,y in [(7,5),(8,5),(65,6),(66,6),(18,31)]:c[y][x]='7'
  objects=[portal([0,18],'river_mouth','from_harbor'),sign([3,16],'Westelijke oever: Zilvermonding','De brug bij de rivier voert naar de Blauwe Kust. Het westelijke grasveld is vrij van werkplekken.'),
   portal([72,14],'headland','from_harbor'),sign([70,12],'Oostelijk kustpad: Lichtkaap','Volg het hoge pad naar de vuurtoren. Je hebt geen uitrusting nodig en kunt altijd terug.'),
   landmark([39,24],1,[5,2]),landmark([55,21],2,[5,2]),
   dict(type='npc',id='rg_ise',pos=[40,27]),dict(type='npc',id='rg_raf',pos=[53,24]),
   dict(type='coast_dock',pos=[46,32],to='coast',spawn='from_island',talk='ce_sail_coast',side=1),
   dict(type='tide_station',pos=[45,29],role='routes',to='coast',spawn='from_island',
    routes=[route('coast','from_island'),route('gull_island','from_coast'),route('tide_cove','from_coast')]),
   chart([34,26])]
  name='Rietwenk Haven';spawns=dict(start=[44,28],from_estuary=[3,18],from_coast=[44,31],from_headland=[70,14])
 else:
  for y in range(2,h-2):
   for x in range(2,w-2):
    edge=61+5*math.sin(y*.13)
    floor=41-5*math.sin(x*.07)**2
    if x<edge-2 and y<floor-1:
     c[y][x]='6' if x<edge-6 and y<floor-5 else '5'
     if y<4 or x<4:c[y][x]='7'
    elif x<edge and y<floor+1:c[y][x]='7' if y<22 else '4'
    elif x<edge+1 and y<floor+2:c[y][x]='8'
  for y in range(7,30):
   for x in range(26,58):
    if c[y][x]=='6' and math.sin(x*.15+y*.28)>.93:c[y][x]='5'
  path(c,[(0,28),(15,28),(25,26),(37,24),(48,22),(54,21)])
  path(c,[(37,24),(39,31),(49,34)],1)
  for x,y in [(10,8),(11,8),(12,9),(30,10),(31,10),(39,7),(40,7),(21,34),(22,34)]:c[y][x]='7'
  objects=[portal([0,28],'harbor','from_headland'),sign([3,26],'Westelijk kustpad: Rietwenk Haven','Het brede hoge pad brengt je terug naar de veer. Het zuidelijke uitzicht is een rustige zijroute.'),
   landmark([54,18],0,[3,2]),chart([9,26]),
   dict(type='region_view',pos=[49,33],lines=['Vanaf deze lage rand zie je het verschil tussen de rustige riviermonding en de open zee.','Beneden trekken schuimstrepen langs de rotsen. Achter je voert het hoge pad terug naar de haven.'])]
  name='Lichtkaap';spawns=dict(start=[5,28],from_harbor=[4,28])
 return dict(name=name,music='coast',outdoor=True,weather='random',rows=[''.join(r) for r in c],spawns=spawns,objects=objects)

def building(frame):
 im=Image.new('RGBA',(128,128));d=ImageDraw.Draw(im)
 if frame==0:
  d.ellipse((43,94,86,105),fill=(28,47,48,110))
  d.polygon([(49,96),(52,39),(76,39),(80,96)],fill='#ded8b4',outline='#506768')
  d.polygon([(63,41),(76,39),(80,96),(67,98)],fill='#b8bea4')
  for y in [58,81]:d.polygon([(51,y),(77,y),(78,y+7),(51,y+7)],fill='#719294')
  d.polygon([(48,40),(49,29),(78,29),(80,40)],fill='#476b79')
  d.rectangle((53,31,75,38),fill='#e9d58c');d.line((63,31,63,38),fill='#687b78')
  d.polygon([(45,28),(62,20),(81,27),(81,30),(45,30)],fill='#486678')
  d.rectangle((61,15,63,21),fill='#c8c19b');d.line((63,15,72,17),fill='#d8e1d2',width=2)
  d.polygon([(57,99),(57,89),(61,85),(67,85),(71,90),(71,99)],fill='#4b6b73')
  d.line((45,100,83,100),fill='#bec7b1',width=3)
 elif frame==1:
  d.ellipse((15,94,113,105),fill=(23,40,45,100))
  d.rectangle((22,60,105,99),fill='#bdc6a5',outline='#425e64')
  d.rectangle((81,60,105,99),fill='#91a89a')
  for x in [30,66,91]:
   d.rectangle((x,72,x+10,84),fill='#47798a');d.line((x+5,73,x+5,83),fill='#d8d5aa')
  d.polygon([(16,61),(38,38),(91,38),(112,61)],fill='#617e85',outline='#3c555e')
  for y in [46,52,58]:d.line((26,y,101,y),fill='#8ca19a')
  d.rectangle((42,80,59,100),fill='#5d796c')
  d.rectangle((18,86,109,89),fill='#d8bf8d');d.rectangle((19,90,22,101),fill='#7b7054')
  d.rectangle((106,90,109,101),fill='#7b7054')
  # Boat emblem replaces baked language text.
  d.polygon([(54,62),(72,62),(68,68),(59,68)],fill='#ecd6a4');d.line((62,54,62,63),fill='#d9d6a9')
 else:
  d.ellipse((14,94,114,106),fill=(23,40,45,100))
  d.rectangle((20,62,106,100),fill='#7f8873')
  d.polygon([(16,63),(30,46),(91,46),(111,63)],fill='#b69c70',outline='#5c6d66')
  for x in [24,60,102]:d.rectangle((x,63,x+4,101),fill='#78684e')
  d.rectangle((34,68,89,96),fill='#344f57')
  for x in range(36,89,8):
   d.line((x,68,x+12,95),fill='#b5c0a1')
   d.line((x,95,x+12,68),fill='#879e8d')
  for x,y in [(35,94),(83,92),(92,94)]:d.ellipse((x,y,x+9,y+7),fill='#b7a079',outline='#6b7057')
 if frame in [1,2]:
  # Compact coastal sheds: keep the ground anchor and footprint, lower the roof.
  compact=Image.new('RGBA',(128,128));compact.paste(im.resize((128,102),Image.Resampling.NEAREST),(0,20));im=compact
 return outline(im)

def person(role,frame):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im);bob=frame
 skin='#b57f5d' if role=='ise' else '#d3a376'
 d.rectangle((5,11,7,14),fill='#3e535b');d.rectangle((9,11,11,14),fill='#3e535b')
 d.rectangle((4,7,12,11),fill='#778f9a' if role=='ise' else '#9a8662')
 d.rectangle((5,3-bob,11,7-bob),fill=skin)
 d.point((10,5-bob),fill='#253e4c')
 if role=='ise':
  d.rectangle((4,2-bob,12,3-bob),fill='#3f5f78');d.rectangle((5,1-bob,10,2-bob),fill='#89adba')
  d.rectangle((5,8,11,9),fill='#d3c69a')
 else:
  d.rectangle((5,2-bob,11,3-bob),fill='#585c50');d.line((4,8,8,12,12,8),fill='#657a70',width=2)
 return outline(im)
def props(frame):
 im=Image.new('RGBA',(32,24));d=ImageDraw.Draw(im)
 if frame==0: # regional chart, boat and walking route emblems
  d.rectangle((6,12,8,23),fill='#75694b');d.rectangle((23,12,25,23),fill='#75694b')
  d.polygon([(2,4),(28,2),(31,15),(4,18)],fill='#d1c49d',outline='#617f7c')
  d.line((7,9,13,6,21,9,26,6),fill='#547d8b',width=2);d.line((8,12,14,15,24,12),fill='#9b8f61')
 elif frame==1:
  for y in [10,14]:d.polygon([(3,y),(27,y),(30,y+3),(4,y+3)],fill='#baa16f',outline='#76684e')
  for x in [7,24]:d.rectangle((x,16,x+2,22),fill='#6b705b')
 elif frame==2:
  for x in [7,14,24]:
   d.line((x,22,x-2,6+(x%4)),fill='#65846c',width=2)
   d.line((x-2,6+(x%4),x-3,2+(x%4)),fill='#b7b58b',width=3)
   d.line((x,17,x+4,11),fill='#8a9d75',width=1)
 elif frame==3: # sun-worn driftwood on the quiet upper shore
  d.polygon([(3,16),(25,11),(28,14),(7,20)],fill='#aa9d76',outline='#6e795e')
  d.line((8,17,24,13),fill='#d0bf94',width=1)
 elif frame==4: # low river flowers, no collider
  for x,y in [(6,15),(13,18),(23,11),(26,18)]:
   d.line((x,y+4,x-1,y-2),fill='#6b8e6b')
   d.ellipse((x-2,y-4,x+1,y-2),fill='#c9c9b0')
   d.point((x,y-3),fill='#e2c48e')
 else: # wind-combed salt grass and flat stones
  for x,y in [(6,16),(15,20),(24,15)]:
   d.ellipse((x,y,x+5,y+2),fill='#9aa78c')
   d.line((x,y,x+4,y-6),fill='#abb884',width=1)
   d.line((x+3,y,x+7,y-4),fill='#798d66',width=1)
 return im
def main():
 for kind in ['river_mouth','harbor','headland']:
  (ROOT/'scripts/maps'/f'{kind}.gd').write_text('extends RefCounted\n## Hand-shaped by tools/art_x_coastal_region.py.\nconst DATA := '+json.dumps(data(kind),ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 strip([building(i) for i in range(3)]).save(ROOT/'assets/rg_landmarks.png')
 strip([props(i) for i in range(6)]).save(ROOT/'assets/rg_props.png')
 for role in ['ise','raf']:strip([person(role,i) for i in range(2)]).save(ROOT/'assets'/f'npc_rg_{role}.png')
 sound.audio('rg_bell',1.8,lambda t,r:(math.sin(t*math.tau*523)+.3*math.sin(t*math.tau*1390)+.18*math.sin(t*math.tau*2103))*math.exp(-t*3)*.24*min(t*80,1))
if __name__=='__main__':main()
