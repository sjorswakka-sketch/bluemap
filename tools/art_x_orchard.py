"""Original 32px crop stages, 64px orchard tree layers and product icons."""
from pathlib import Path
from PIL import Image,ImageDraw
import math,random,struct,wave
root=Path(__file__).resolve().parent.parent/'assets'
ink='#344c3d';stem='#658654';leaf='#83a65f';lit='#bbcb82';soil='#776044'
def oval(d,b,c,outline=None):d.ellipse(b,fill=c,outline=outline)
sheet=Image.new('RGBA',(128,160))
for row in range(5):
 for stage in range(4):
  im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im);rnd=random.Random(row*17+stage)
  if row==0:
   for x,y in [(9,23),(21,25),(17,16)]:
    if stage==3:
     d.polygon([(x-4,y-3),(x+4,y-3),(x+2,y+3),(x,y+6),(x-2,y+3)],fill='#bd733e')
     d.line((x-3,y-2,x+2,y-2),fill='#ebb16c',width=2)
    for dx in [-3,0,3]:
     d.line((x,y-3,x+dx*(1 if stage else .6),y-7-stage*2),fill=ink,width=2)
     d.line((x,y-4,x+dx,y-8-stage*2),fill=leaf,width=1)
     if stage>=1:d.point((x+dx,y-8-stage*2),fill=lit)
  elif row==1:
   d.line([(7,26),(10,22),(18,24),(24,19)],fill=stem,width=2)
   for x,y in [(9,20),(23,18),(15,25)]:
    if stage>=1:
     d.polygon([(x-4,y),(x,y-4),(x+4,y),(x+1,y+3)],fill=ink)
     d.polygon([(x-3,y),(x,y-3),(x+3,y),(x,y+2)],fill=leaf)
   if stage>=2:
    oval(d,(8,14,24,28),'#c18c45' if stage==3 else '#819055',ink)
    for x in [12,16,20]:d.arc((x-4,15,x+4,27),-100,100,fill='#e4b267' if stage==3 else '#9ba36a')
    d.line((16,14,17,11),fill=stem,width=2)
    if stage==3:d.line((10,19,11,17),fill='#f0c680',width=2)
  elif row in [2,3]:
   for i in range(1+stage):
    x=6+i*6;y=27;h=7+stage*3-(i%2)*3
    d.line((x,y,x+1,y-h),fill=ink,width=3 if row==3 else 2)
    for k in range(2+stage):
     cy=y-3-k*3
     if row==2:
      oval(d,(x-4,cy-2,x,cy+1),leaf,ink);oval(d,(x+2,cy-3,x+6,cy),leaf,ink)
      d.point((x-2,cy-1),fill=lit)
     else:
      d.line((x-4,cy-2,x+5,cy-4),fill='#93aa8b',width=2);d.point((x-3,cy-2),fill='#ced2a6')
    if stage==3:
     for dy in [-3,0,3]:oval(d,(x-1,y-h+dy-2,x+3,y-h+dy),'#d9b9ca' if row==2 else '#a2a9d2')
  else:
   if stage==0:
    d.line((16,27,16,20),fill=stem,width=2);oval(d,(11,17,16,21),leaf);oval(d,(16,19,22,23),leaf)
   else:
    d.line((16,28,15,16),fill='#7a6545',width=3)
    for x,y in [(9,20),(15,14),(23,20),(14,24)]:
     oval(d,(x-6,y-5,x+5,y+5),ink);oval(d,(x-5,y-5,x+4,y+3),'#71965c');d.line((x-3,y-3,x,y-4),fill='#a3bb79')
    if stage>=2:
     for x,y in [(8,19),(15,13),(24,19),(17,24)]:
      oval(d,(x-2,y-2,x+2,y+2),'#687e9a' if stage==2 else '#6676ad',ink);d.point((x-1,y-1),fill='#a5b5d3')
  sheet.alpha_composite(im,(stage*32,row*32))
sheet.save(root/'orchard_crops.png')
canopies=Image.new('RGBA',(320,64));trunks=Image.new('RGBA',(256,64))
for stage in range(5):
 tr=Image.new('RGBA',(64,64));d=ImageDraw.Draw(tr);rnd=random.Random(201+stage)
 if stage==0:
  d.line((32,53,32,41),fill=ink,width=3)
  oval(d,(23,35,33,43),leaf,ink);oval(d,(32,39,42,46),leaf,ink)
 else:
  d.polygon([(28,54),(29,29),(34,27),(36,54),(39,56),(25,56)],fill='#594c39')
  d.line((31,52,32,31),fill='#b29966',width=2)
  d.line((32,42,23,32),fill='#7d6545',width=3);d.line((33,38,42,30),fill='#7d6545',width=3)
 trunks.alpha_composite(tr,(stage*64,0))
 im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
 if stage:
  if stage==1:clusters=[(27,25,13),(39,31,11),(21,33,10)]
  else:clusters=[(19,26,15),(32,18,16),(46,27,14),(32,34,17)]
  for x,y,r in clusters:
   oval(d,(x-r,y-r,x+r,y+r),ink);oval(d,(x-r+1,y-r,x+r-1,y+r-3),'#5c8355')
   oval(d,(x-r+3,y-r+1,x+r-4,y+4),'#81a15e')
   for i in range(10):
    px=x+rnd.randrange(-r+4,max(1,r-3));py=y+rnd.randrange(-r+3,max(1,r-3))
    d.line((px,py,px+2,py-1),fill='#b4c77e' if i%3==0 else '#98b16c')
  if stage in (2,3):
   for x,y in [(15,22),(27,13),(43,20),(25,34),(45,34)]:
    if stage==2:
     for dx,dy in [(-2,0),(2,0),(0,-2),(0,2)]:d.rectangle((x+dx-1,y+dy-1,x+dx+1,y+dy+1),fill='#e3c8b3')
     d.point((x,y),fill='#bd9c63')
    else:
     oval(d,(x-3,y-2,x+3,y+4),'#704f3b');oval(d,(x-2,y-2,x+3,y+3),'#c57d58');d.point((x-1,y-1),fill='#f0be7d');d.line((x+1,y-3,x+3,y-5),fill='#4f6e42')
 canopies.alpha_composite(im,(stage*64,0))
canopies.save(root/'orchard_canopies.png');trunks.save(root/'orchard_trunks.png')
items=Image.new('RGBA',(14*32,32))
for i in range(14):
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
 if i<6:
  if i<2:
   d.polygon([(7,10),(25,10),(26,27),(6,27)],fill='#a18c66',outline='#514b3b');d.rectangle((8,7,24,11),fill='#cebc92')
   color='#e4a162' if i==0 else '#daa04f';oval(d,(12,15,19,22),color,ink);d.line((15,15,15,12),fill=stem,width=2)
  elif i<4:
   d.polygon([(9,24),(22,24),(20,29),(11,29)],fill='#ad7751',outline='#5d4c3b')
   d.line((16,25,16,9),fill=stem,width=2)
   for y in [12,17,22]:oval(d,(9,y-3,15,y+1),leaf,ink);oval(d,(17,y-5,23,y-1),'#91ad7d',ink)
  elif i==4:
   d.polygon([(10,24),(23,24),(21,30),(12,30)],fill='#a97b51',outline='#5e503b');d.line((16,25,16,10),fill='#886746',width=3)
   for x,y in [(12,10),(19,13),(15,6)]:oval(d,(x-5,y-3,x+5,y+4),leaf,ink)
  else:
   d.line((16,28,17,12),fill=stem,width=2)
   for x,y in [(12,12),(21,16),(12,21)]:oval(d,(x-4,y-3,x+4,y+3),leaf,ink)
   for x,y in [(10,13),(22,16)]:oval(d,(x,y,x+3,y+3),'#8298bd',ink)
 elif i==6:
  d.polygon([(8,12),(22,15),(12,28)],fill='#b9703d',outline=ink);d.line((10,14,18,16),fill='#e7aa65',width=2)
  for x,y in [(10,5),(17,4),(23,8)]:d.line((15,13,x,y),fill=leaf,width=3)
 elif i==7:
  oval(d,(4,11,28,28),'#bc7d36',ink)
  for x in [9,16,23]:d.arc((x-4,12,x+4,27),-100,100,fill='#e8b66a')
  d.line((16,11,18,5),fill=stem,width=3)
 elif i in [8,9]:
  for x,y in [(11,12),(20,16),(13,24)]:
   d.line((x,y+4,x+3,y-5),fill=ink,width=2)
   if i==8:oval(d,(x-4,y-4,x+4,y+2),leaf,ink);d.line((x-2,y,x+2,y-2),fill=lit)
   else:
    for j in range(4):d.line((x-3,y-j*2,x+5,y-3-j*2),fill='#9aaf8c',width=2)
 elif i==10:
  oval(d,(6,10,26,28),'#704b36');oval(d,(7,10,25,27),'#c68158');d.line((10,14,11,12),fill='#f1c47e',width=2)
  d.line((16,11,18,5),fill=ink,width=2);oval(d,(18,4,25,8),leaf,ink)
 elif i in [11,12]:
  d.polygon([(5,16),(27,16),(24,27),(8,27)],fill='#a67e56',outline=ink)
  oval(d,(5,12,27,20),'#d1bd91',ink);oval(d,(7,14,25,18),'#ad814a' if i==11 else '#96a572')
  if i==11:
   d.rectangle((10,15,14,17),fill='#dda25e');d.rectangle((18,15,22,17),fill='#e3b469')
  else:d.arc((23,17,31,24),-90,90,fill='#c3ae83',width=2)
  for x in [11,19]:d.line((x,8,x+1,4),fill='#bdcbb6',width=1)
 else:
  d.rounded_rectangle((7,11,25,28),radius=3,fill='#71917b',outline=ink);d.rectangle((6,8,26,12),fill='#c3af83')
  d.rectangle((11,16,21,24),fill='#d9cfa9');d.line((15,23,17,16),fill=stem,width=2)
  for y in [18,21]:d.line((13,y,20,y-2),fill='#6f8c69')
 items.alpha_composite(im,(i*32,0))
items.save(root/'pixel_items_orchard.png')
items.resize((14*16,16),Image.Resampling.NEAREST).save(root/'items_orchard.png')
rate=22050;rng=random.Random(920);samples=[]
for n in range(int(rate*.11)):
 t=n/rate;v=(math.sin(math.tau*(630*t-800*t*t))*.5+rng.uniform(-1,1)*.18)*math.exp(-t*36)*.1
 samples.append(struct.pack('<h',round(v*32767)))
with wave.open(str(root/'audio/orchard_pick.wav'),'wb') as w:
 w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(samples))
print('original orchard stages, layered apple tree, fourteen items and harvest cue')
