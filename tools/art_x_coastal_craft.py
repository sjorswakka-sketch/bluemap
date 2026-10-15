"""Original quiet harbor workshop, coastal materials, furniture and soft cues."""
from pathlib import Path
from PIL import Image,ImageDraw
from artlib import strip,outline
import math,json
import art_x_opening as sound
ROOT=Path(__file__).resolve().parent.parent
def item(i):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 if i==0:
  for y in [7,11]:d.line((2,y,13,y-4),fill='#b69567',width=3);d.line((4,y-1,12,y-4),fill='#e0c898')
 elif i==1:
  for x in [4,7,10,13]:d.line((x,13,x-2,2+x%3),fill='#b8c78e',width=2)
  d.line((2,10,14,10),fill='#a67c53',width=2)
 elif i==2:
  d.polygon([(2,8),(6,2),(12,3),(14,10),(8,14),(3,12)],fill='#63b6bf',outline='#b4e5da');d.line((6,3,5,10,9,12),fill='#d1ead9')
 elif i==3:
  d.line((8,14,8,6),fill='#66876e',width=2)
  for x,y in [(4,6),(11,3),(12,9)]:d.ellipse((x-3,y-2,x+2,y+2),fill='#a7c4a5')
 elif i==4:
  d.arc((2,7,11,14),0,330,fill='#d5bd91',width=2);d.line((8,2,8,8),fill='#acc1c9',width=2);d.arc((5,1,11,7),-5,160,fill='#acc1c9',width=2)
 elif i in [5,6]:
  for x in [3,10]:
   d.rectangle((x,5,x+3,12),fill='#658b9f' if i==5 else '#b99e6a');d.line((x,8,x+3,8),fill='#d5d3aa',width=2)
  if i==5:d.line((8,1,8,7),fill='#bad8d5',width=2);d.arc((4,2,12,8),0,180,fill='#bad8d5',width=2)
  else:
   for x in [3,8,13]:d.line((8,2,x,6),fill='#8ed4cd')
 elif i==7:
  for y in [5,10]:d.rectangle((2,y,14,y+2),fill='#bc9a6b')
  for x in [3,12]:d.line((x,4,x,14),fill='#76553e',width=2)
 elif i==8:
  d.rectangle((4,4,12,12),fill='#dfc38b');d.polygon([(5,5),(11,5),(12,10),(8,12),(4,10)],fill='#80cbc9');d.rectangle((6,1,10,3),fill='#82735d')
 else:
  d.ellipse((2,7,14,13),fill='#bd9b6b');d.rectangle((3,5,13,9),fill='#d9c093');d.ellipse((4,4,12,8),fill='#699a83')
  for x in [5,9]:d.line((x,2,x+1,0),fill='#c4d9bc')
 return outline(im)
def resource(i):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 if i==0:
  for y in [8,12]:d.polygon([(1,y),(11,y-4),(15,y-1),(5,y+3)],fill='#a58b69');d.line((4,y,12,y-2),fill='#dec8a0')
 elif i==1:
  for x in [2,5,8,11,14]:d.line((8,15,x,3+x%3),fill='#b5be7c',width=2);d.ellipse((x-1,1+x%3,x+1,4+x%3),fill='#dad4a0')
 elif i==2:
  d.polygon([(1,13),(3,7),(10,4),(15,9),(13,15)],fill='#516f75')
  for x,y in [(4,8),(9,6),(11,11)]:d.polygon([(x,y+3),(x,y),(x+3,y-2),(x+3,y+2)],fill='#8ad3ce',outline='#d3efe1')
 else:
  for x,y in [(5,9),(10,7),(8,13),(13,12)]:d.ellipse((x-3,y-2,x+2,y+1),fill='#a9c6a3');d.line((x,y,x+1,15),fill='#6e9577')
 return outline(im)
def prop(i):
 im=Image.new('RGBA',(64,48));d=ImageDraw.Draw(im);dark='#604d3d';wood='#ab8b61';light='#d5b982'
 if i in [0,2]:
  for x in [14,45]:d.rectangle((x,27,x+4,41),fill=dark)
  d.rectangle((9,19,54,31),fill=wood);d.rectangle((8,17,55,22),fill=light)
  if i==0:
   d.arc((24,11,44,24),0,310,fill='#c4c49e',width=2);d.rectangle((15,11,21,18),fill='#597a85');d.line((40,10,48,17),fill='#a4c5c5',width=3)
  else:
   d.rectangle((18,10,43,19),fill='#e2d3a4');d.line((21,13,39,16),fill='#73958d')
 elif i==1:
  d.rectangle((14,20,49,38),fill=wood,outline=dark,width=2);d.rectangle((12,15,51,23),fill=light,outline=dark,width=2)
  for x in [19,43]:d.rectangle((x,16,x+2,37),fill='#9caaa1')
  d.rectangle((29,22,34,29),fill='#65848a')
 elif i==9:
  d.rectangle((13,36,51,41),fill=wood)
  for x in [15,47]:d.rectangle((x,33,x+2,39),fill=dark)
 elif i==3:
  for x in [14,47]:d.rectangle((x,15,x+3,40),fill=dark)
  for y in [18,29,39]:d.rectangle((13,y,51,y+2),fill=wood)
  if i==3:
   for x in [19,27,37,44]:d.rectangle((x,23,x+4,28),fill='#83aaa0' if x%2 else '#c9b184')
   d.line((18,34,41,34),fill=light,width=2)
 elif i in [4,10,11]:
  d.rectangle((25,29,38,38),fill=wood);d.rectangle((29,24,34,30),fill=dark)
  if i!=10:
   d.rectangle((24,12,39,25),fill='#cfba87');d.rectangle((27,14,36,23),fill='#4e7279' if i==11 else '#9ed9cd');d.rectangle((28,8,35,12),fill=dark)
 elif i==5:
  d.rectangle((10,1,53,34),fill=dark);d.rectangle((13,3,50,30),fill='#71a4ad')
  for x in [14,34]:d.rectangle((x,5,x+16,15),fill='#b4c9b4')
  d.line((32,3,32,30),fill=wood,width=3);d.line((12,17,51,17),fill=wood,width=3);d.rectangle((7,32,56,35),fill=light)
 elif i==6:
  d.rectangle((12,16,52,35),fill='#b19b72');d.rectangle((14,18,50,33),outline='#d3c395',width=2)
  d.line((32,29,32,19),fill='#567c83',width=2);d.polygon([(28,22),(32,16),(36,22)],fill='#567c83')
 elif i==12:
  d.rectangle((16,1,48,46),fill=dark);d.rectangle((19,3,45,44),fill=wood)
  d.rectangle((23,7,42,43),fill='#273f48');d.line((24,8,24,41),fill='#c6b07e',width=2);d.rectangle((33,18,40,27),fill='#648e91');d.point((38,33),fill=light)
 elif i==7:
  d.rectangle((29,14,34,41),fill=dark);d.ellipse((20,8,42,19),fill=wood);d.line((25,13,38,13),fill=light,width=2);d.arc((15,24,45,40),0,330,fill='#d1bf9b',width=2)
 else:
  d.rectangle((18,19,46,34),fill=wood,outline=dark,width=2);d.rectangle((17,32,47,36),fill=light)
  d.line((24,29,36,15),fill='#9ebbb9',width=3);d.arc((30,12,44,30),-80,80,fill='#d7c496',width=2)
 return outline(im)
def workshop():
 w,h=30,22;c=[['N']*w for _ in range(h)]
 for y in range(2,20):
  for x in range(2,28):c[y][x]='w'
 for y in range(19,22):
  for x in [14,15]:c[y][x]='m'
 for y in range(13,17):
  for x in range(11,19):c[y][x]='m'
 objects=[dict(type='portal',pos=[14,21],size=[2,1],to='harbor',spawn='from_workshop'),
 dict(type='sign',pos=[16,19],lines=['Rafs havenwerkplaats · terug naar Rietwenk Haven','Gratis materiaalkist en vaste meubelplekken. Raf deelt het lijnpatroon; Greta en Lena helpen met hun bestaande werkplekken. Geen huur of onderhoud.']),
 dict(type='savepoint',pos=[23,15],spawn='altar')]
 for role,pos in [('bench',[9,8]),('storage',[22,8]),('layout',[8,14]),('shelf',[7,5]),('lamp',[22,5]),('window',[10,2]),('window',[21,2]),('practice',[22,12])]:
  objects.append(dict(type='cw_station',role=role,pos=pos))
 data=dict(name='Rafs havenwerkplaats',music='coast',outdoor=False,dark=0.0,rows=[''.join(r) for r in c],spawns=dict(start=[14,18],altar=[23,17]),objects=objects)
 (ROOT/'scripts/maps/coast_workshop.gd').write_text('extends RefCounted\n## Original small workshop with reserved furniture spots and a clear exit.\nconst DATA := '+json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def main():
 strip([item(i) for i in range(10)]).save(ROOT/'assets/cw_items.png')
 strip([resource(i) for i in range(4)]).save(ROOT/'assets/cw_resources.png')
 strip([prop(i) for i in range(13)]).save(ROOT/'assets/cw_props.png')
 sound.ROOT=ROOT
 sound.audio('cw_thread',.6,lambda t,r:math.exp(-t*5)*(.16*(r.random()*2-1)+.2*math.sin(2*math.pi*(430*t+55*t*t))))
 sound.audio('cw_stow',.22,lambda t,r:math.exp(-t*18)*(.4*math.sin(1300*t)+.15*(r.random()*2-1)))
 sound.audio('cw_guard',.3,lambda t,r:math.exp(-t*14)*(.3*math.sin(2800*t)+.2*math.sin(4200*t)))
 sound.audio('cw_fan',.28,lambda t,r:math.sin(math.pi*t/.28)*.25*(r.random()*2-1))
 workshop()
if __name__=='__main__':main()
