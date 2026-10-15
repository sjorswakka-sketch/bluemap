"""Original coastal adventure art, wetstone cave, creatures and synthesized cues.
No downloaded assets. Deterministic generation; existing 78 atlas cells are preserved.
"""
from pathlib import Path
from PIL import Image, ImageDraw
from artlib import strip, outline
import math, json
import art_x_opening as sound
ROOT=Path(__file__).resolve().parent.parent
NAMES=['ad_wetstone','ad_seawall']
def tile(name):
 im=Image.new('RGBA',(16,16),'#405c61' if name==NAMES[0] else '#243c47');d=ImageDraw.Draw(im)
 if name==NAMES[0]:
  d.polygon([(0,0),(8,0),(6,6),(0,9)],fill='#435b60')
  d.line([(8,0),(6,6),(10,11),(9,15)],fill='#364d53')
  d.line([(0,9),(6,6)],fill='#384e54')
  for x,y in [(2,2),(12,13)]:d.point((x,y),fill='#4d6669')
 else:
  for y in [0,6,12]:
   d.line((0,y,15,y),fill='#597273')
   for x in range((y//6%2)*6,16,9):d.line((x,y,x,y+5),fill='#162e3b')
 return im
def creature(kind,frame):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 if kind=='wisp':
  yy=frame%2
  for x in [7,11,15,18]:d.line((x,13,x+(-1 if frame%2 else 1),20+yy),fill='#74c9c4',width=2)
  d.ellipse((4,3+yy,20,16+yy),fill='#67b9c0',outline='#c7f0d8',width=2)
  d.ellipse((7,6+yy,17,12+yy),fill='#b4e8d7')
  for x in [9,15]:d.point((x,10+yy),fill='#24465c')
  if frame>=2:d.arc((2,1,22,21),5,305,fill='#e8e2a1',width=1)
 else:
  keeper=kind=='keeper';shell='#8574a4' if keeper else '#a97b59';light='#d6c0aa' if keeper else '#e4b985'
  for x in [4,8,15,19]:
   d.line((12,13,x,19+frame%2),fill='#8eafb0',width=2)
  d.ellipse((5,7,19,17),fill=shell,outline=light,width=2)
  for x in [3,19]:
   y=4 if frame==2 else 10 if frame==3 else 7
   d.ellipse((x-2,y,x+3,y+6),fill=light);d.line((x,y,x+1,y+2),fill='#384857',width=1)
  for x in [9,15]:d.rectangle((x,5,x+1,8),fill='#dce6b4');d.point((x,5),fill='#273947')
  if keeper:d.polygon([(8,9),(12,3),(16,9)],fill='#e5d39b')
 return outline(im)
def prop(frame):
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
 wood='#86664d';light='#d1b681';ink='#375660'
 if frame in [0,3]:
  d.rectangle((7,11,25,23),fill=wood);d.polygon([(9,8),(17,10),(24,7),(24,21),(17,24),(9,21)],fill='#e4d3a5')
  d.line((17,10,17,24),fill=wood)
  for y in [12,16,19]:d.line((11,y,15,y),fill=ink);d.line((19,y,22,y-1),fill=ink)
 elif frame==1:
  d.polygon([(4,22),(10,13),(17,16),(28,9),(23,21),(13,26)],fill=wood)
  for x,y in [(10,19),(18,20),(22,16)]:d.rectangle((x,y,x+1,y+1),fill='#eee5bd')
 elif frame==2:
  d.ellipse((5,19,26,27),fill='#4c625b')
  for x in [8,12,19,24]:d.line((x,24,x-3,13),fill='#9caa7d')
 elif frame in [4,8]:
  d.rectangle((14,12,17,29),fill=wood);d.rectangle((5,9,27,17),fill=light)
  d.line((9,13,23,13),fill=ink,width=2)
  if frame==8:d.ellipse((11,10,19,17),fill=ink)
 elif frame==5:
  d.polygon([(4,24),(7,15),(14,12),(17,22),(20,13),(27,17),(29,26)],fill='#8b9a93')
  d.line((16,14,18,26),fill='#3c535e',width=2)
 elif frame==6:
  for x in range(7,27,3):d.line((16,28,x,12+(x%4)),fill='#d4d6a0',width=2)
 elif frame==7:
  for y in [22,25,28]:d.line((6,y,25,y-3),fill=light,width=2)
 elif frame==9:
  d.rectangle((4,24,28,28),fill='#456973')
  d.rectangle((5,6,8,29),fill=wood);d.rectangle((24,6,27,29),fill=wood)
  d.ellipse((7,5,26,24),fill='#4d635b',outline=light,width=2);d.ellipse((14,12,19,17),fill=wood)
 elif frame==10:
  d.rectangle((4,13,27,26),fill=wood);d.rectangle((3,10,28,17),fill='#aab7a5')
  for x in [9,22]:d.line((x,12,x,5),fill=ink,width=2);d.ellipse((x-2,2,x+2,6),fill=light)
 else:
  d.ellipse((3,25,29,30),fill='#74a7af');d.polygon([(7,24),(12,14),(21,14),(25,24)],fill='#cc976c')
  d.rectangle((15,4,17,18),fill=wood);d.polygon([(17,3),(27,7),(17,10)],fill='#f0d597')
 return outline(im)
def cave():
 w,h=64,40;c=[['1']*w for _ in range(h)]
 def rect(x,y,ww,hh,ch):
  for yy in range(y,y+hh):
   for xx in range(x,x+ww):c[yy][xx]=ch
 rect(2,25,60,9,'0');rect(7,4,18,23,'0');rect(37,4,20,23,'0')
 rect(24,13,14,4,'0');rect(28,4,4,30,'3')
 rect(41,6,10,4,'3');rect(9,6,3,3,'3')
 for x,y in [(7,4),(8,4),(7,5),(24,4),(24,5),(37,4),(38,4),(37,5),(55,4),(56,4),(56,5),(7,24),(56,24)]:c[y][x]='1'
 # A long, permanently safe crossing; repair adds only the short northern bridge.
 rect(28,28,4,3,'9')
 rect(0,29,3,2,'9')
 objects=[
  dict(type='portal',pos=[0,29],size=[2,2],to='river_mouth',spawn='from_hollow'),
  dict(type='sign',pos=[4,27],lines=['Tijholte · terug naar Zilvermonding','De brede zuidelijke gang en lange brug blijven veilig. Noordelijke zijpoelen zijn optioneel: amberkleurige schaarwaaiers en lichtkringen met een open sector.']),
  dict(type='coast_adventure',role='wheel',pos=[12,27]),
  dict(type='coast_adventure',role='sluice',pos=[40,26]),
  dict(type='coast_adventure',role='keeper_rest',pos=[47,13]),
  dict(type='enemy',kind='ad_crab',pos=[14,12],flag='ad_crab_defeated'),
  dict(type='enemy',kind='ad_wisp',pos=[19,15],flag='ad_wisp_defeated'),
  dict(type='sign',pos=[32,27],lines=['Zuidelijke omweg: altijd open','Na herstel van het tijrad kun je ook over de korte brug in het midden. De poelen boven de gang horen bij de dieren; je hoeft daar niet langs.'])]
 data=dict(name='Tijholte',music='coast',outdoor=False,dark=0.12,rows=[''.join(r) for r in c],spawns=dict(start=[4,30]),objects=objects)
 (ROOT/'scripts/maps/tidal_hollow.gd').write_text('extends RefCounted\n## Hand-shaped optional pools and permanent safe southern route.\nconst DATA := '+json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
 for k in ['crab','wisp','keeper']:strip([creature(k,i) for i in range(4)]).save(ROOT/'assets'/('ad_'+k+'.png'))
 strip([prop(i) for i in range(12)]).save(ROOT/'assets/ad_props.png')
 atlas=Image.open(ROOT/'assets/tiles.png').convert('RGBA');legacy=atlas.crop((0,0,78*16,16))
 joined=Image.new('RGBA',(80*16,16));joined.paste(legacy,(0,0))
 for i,n in enumerate(NAMES):joined.paste(tile(n),((78+i)*16,0))
 joined.save(ROOT/'assets/tiles.png')
 sound.ROOT=ROOT
 sound.audio('ad_work',0.45,lambda t,r:math.exp(-t*10)*(0.3*math.sin(t*2100)+0.12*(r.random()*2-1)))
 sound.audio('ad_warn',0.4,lambda t,r:math.sin(math.pi*t/.4)*.24*math.sin(2*math.pi*(300*t+130*t*t)))
 sound.audio('ad_swipe',0.24,lambda t,r:math.sin(math.pi*t/.24)*.33*(r.random()*2-1))
 sound.audio('ad_pulse',0.7,lambda t,r:math.sin(math.pi*t/.7)*.23*math.sin(2*math.pi*(360*t-90*t*t)))
 sound.audio('ad_water',0.8,lambda t,r:math.exp(-t*4)*(.22*(r.random()*2-1)+.18*math.sin(2*math.pi*(410*t+80*t*t))))
 cave()
if __name__=='__main__':main()
