"""Original coastal tiles, boat, shore props, hand-shaped maps and synthesized audio."""
from pathlib import Path
from PIL import Image, ImageDraw
from artlib import strip,outline
import math,random,re
import art_x_opening as sound
ROOT=Path(__file__).resolve().parent.parent
sound.ROOT=ROOT
NAMES=['ce_sea','ce_sand','ce_dune','ce_grass','ce_cliff','ce_shore','ce_boardwalk']
def tile(name):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 base={'ce_sea':'#397c92','ce_shore':'#4c94a0','ce_sand':'#d6c6a0','ce_dune':'#c4b58a','ce_grass':'#7e936d','ce_cliff':'#6b7b79','ce_boardwalk':'#997b52'}[name]
 d.rectangle((0,0,15,15),fill=base)
 rng=random.Random(NAMES.index(name)+41)
 if name in ['ce_sea','ce_shore']:
  for y in [3,11]:d.line((2+(y%3),y,8+(y%4),y),fill='#4b92a4' if name=='ce_sea' else '#6aa9ad')
 elif name=='ce_cliff':
  d.polygon([(0,10),(4,4),(9,2),(15,7),(15,15),(0,15)],fill='#526965')
  d.line((1,9,5,4,10,3,14,7),fill='#a4af98',width=2);d.line((5,7,5,14),fill='#425955')
 elif name=='ce_boardwalk':
  for y in [1,5,9,13]:
   d.line((0,y,15,y),fill='#624f39');d.line((0,y+1,15,y+1),fill='#c4a777')
  for x,y in [(2,3),(13,7),(2,11),(13,15)]:d.point((x,y),fill='#52626a')
 else:
  colors={'ce_sand':['#c6b690','#e2d5b4'],'ce_dune':['#a89e73','#dbcca0'],'ce_grass':['#6a805d','#9dac7a']}
  for i in range(12):d.point((rng.randrange(16),rng.randrange(16)),fill=colors[name][i%2])
  if name=='ce_dune':
   for x in [4,11]:d.line((x,12,x-1,8),fill='#7f9466');d.line((x,11,x+2,7),fill='#a1ae76')
 return im
def boat(frame):
 im=Image.new('RGBA',(48,32));d=ImageDraw.Draw(im)
 d.ellipse((4,20,45,27),fill=(18,52,62,100))
 d.polygon([(3,17),(42,14),(46,18),(36,26),(13,27),(5,23)],fill='#6f573e')
 d.polygon([(4,16),(41,13),(43,16),(35,22),(13,23)],fill='#bd9563')
 d.line((10,20,34,18),fill='#e4c991',width=2)
 d.line((23,3,23,21),fill='#c1b58b',width=2)
 d.polygon([(25,3),(36,7+(frame%2)),(26,12),(25,12)],fill='#d2e1cf')
 d.line((26,4,26,10),fill='#7d9c94');d.rectangle((13,17,17,20),fill='#496e78')
 d.line((7,24,36,24),fill='#3c4d4e')
 return outline(im)
def prop(frame):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 if frame==0:
  d.rectangle((10,8,13,20),fill='#5b6b66');d.ellipse((8,6,15,10),fill='#b5b394')
  d.arc((3,12,20,20),0,330,fill='#ded1a5',width=2)
 else:
  d.ellipse((3,12,21,20),fill='#768980');d.arc((3,10,21,20),180,360,fill='#bdc8ab',width=2)
  d.line((8,15,12,13,17,15),fill='#d9d0a3');d.point((12,17),fill='#d9d0a3')
 return outline(im)
def map_data(island=False):
 w,h=(48,36) if island else (58,36)
 cells=[['3']*w for _ in range(h)]
 for y in range(2,h-2):
  for x in range(2,w-2):
   if island:
    inside=((x-26)/16)**2+((y-19)/12)**2<1
    if inside:
     edge=((x-26)/14)**2+((y-19)/10)**2
     cells[y][x]='4' if edge>1 else ('6' if y<21 and x>16 else '5')
   else:
    right=37+round(3*math.sin(y*0.24))
    if x<=right:
     cells[y][x]='4' if x>right-5 or y>29 else ('5' if x>24 else '6')
 # Solid outer bluffs keep the west approach scenic, with a broad safe connection.
 if not island:
  for y in range(2,32):
   for x in [2,3]:
    if y not in range(15,21):cells[y][x]='7'
  for y in [16,17,18]:
   for x in range(0,15):cells[y][x]='9'
  for x in range(14,35):
   y=17+round(3*math.sin((x-14)/20*math.pi))
   for dy in [0,1]:cells[y+dy][x]=','
  for y in [22,23]:
   for x in range(33,45):cells[y][x]='9'
  # A few isolated cliff groups, away from arrival and the central walking line.
  for x,y in [(17,5),(19,6),(14,28),(15,28),(31,9),(32,9)]:
   cells[y][x]='7'
  spawns={'start':[5,17],'from_lake':[5,17],'from_island':[40,23]}
  objects=[{'type':'portal','pos':[0,17],'size':[2,2],'to':'lake','spawn':'from_coast'},
   {'type':'coast_dock','pos':[42,23],'to':'gull_island','spawn':'from_coast','talk':'ce_sail_island'},
   {'type':'sign','pos':[4,15],'lines':['Westelijk pad: Zilvermeer','West: Zilvermeer. Oost: strand en veer naar Meeuweneiland.']}]
  name='Blauwe Kust'
 else:
  for y in [22,23]:
   for x in range(6,17):cells[y][x]='9'
  for x,y in [(23,8),(24,8),(25,8),(26,9),(18,12),(19,12),(34,25),(35,25)]:
   cells[y][x]='7'
  # Two broad routes rejoin: beach below, grassy ridge above.
  for x in range(14,34):
   y=20-round(math.sin((x-14)/20*math.pi)*6)
   for dy in [0,1]:cells[y+dy][x]=','
  spawns={'start':[13,23],'from_coast':[13,23]}
  objects=[{'type':'coast_dock','pos':[8,23],'to':'coast','spawn':'from_island','talk':'ce_sail_coast'},
   {'type':'coast_note','pos':[32,14]}]
  name='Meeuweneiland'
 # Shore tiles remain water-solid; their waves face nearby sand instead of a repeating stripe.
 out=[row[:] for row in cells]
 for y in range(1,h-1):
  for x in range(1,w-1):
   if cells[y][x]=='3' and any(cells[y+dy][x+dx] in ['4','5','6'] for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]):out[y][x]='8'
 return {'name':name,'music':'coast','outdoor':True,'weather':'random','rows':[''.join(row) for row in out],'spawns':spawns,'objects':objects}
def save_map(id,data):
 import json
 text='extends RefCounted\n## Hand-shaped coastline generated by tools/art_x_coast.py.\nconst DATA := '+json.dumps(data,ensure_ascii=False,indent=2).replace('true','true')+'\n'
 (ROOT/'scripts/maps'/f'{id}.gd').write_text(text,encoding='utf8')
if __name__=='__main__':
 old=Image.open(ROOT/'assets/tiles.png').convert('RGBA')
 base=old.crop((0,0,71*16,16))
 atlas=Image.new('RGBA',((71+len(NAMES))*16,16));atlas.paste(base,(0,0));atlas.paste(strip([tile(n) for n in NAMES]),(71*16,0))
 atlas.save(ROOT/'assets/tiles.png')
 strip([boat(i) for i in range(2)]).save(ROOT/'assets/ce_boat.png')
 strip([prop(i) for i in range(2)]).save(ROOT/'assets/ce_props.png')
 save_map('coast',map_data());save_map('gull_island',map_data(True))
 sound.audio('ce_rope',0.35,lambda t,r:r.uniform(-1,1)*0.15*math.sin(math.pi*t/0.35))
 sound.audio('ce_water',0.65,lambda t,r:r.uniform(-1,1)*0.16*math.sin(math.pi*t/0.65)+math.sin(math.tau*180*t)*math.exp(-t*10)*0.08)
 notes=[220,261.63,329.63,293.66,220,196,261.63,246.94]
 def music(t,r):
  beat=int(t/4)%len(notes);u=t%4;freq=notes[beat]
  envelope=math.exp(-u*1.1)*min(1,u*12)
  melody=(math.sin(math.tau*freq*t)+0.25*math.sin(math.tau*freq*2*t))*envelope*0.12
  ocean=r.uniform(-1,1)*0.035*(0.6+0.4*math.sin(math.tau*t/8))
  return melody+ocean
 sound.audio('music_coast',32,music)
