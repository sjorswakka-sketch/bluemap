"""Original quiet paths, fences and gate frames; deterministic pixels and soft wood cue."""
from pathlib import Path
from PIL import Image,ImageDraw
import math,struct,wave,random
root=Path(__file__).resolve().parent.parent/'assets'
paths=Image.new('RGBA',(16*32,3*32))
for style in range(3):
 for mask in range(16):
  im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
  colors=[('#8e917d','#b7b299','#d0c5a6'),('#687b78','#9cab9c','#c4c7b0'),('#6f5943','#aa8c60','#d5b77f')][style]
  shape=Image.new('1',(32,32));m=ImageDraw.Draw(shape)
  m.polygon([(7,4),(24,4),(27,7),(27,24),(24,27),(7,27),(4,24),(4,7)],fill=1)
  for bit,box in [(1,(4,0,27,7)),(2,(24,4,31,27)),(4,(4,24,27,31)),(8,(0,4,7,27))]:
   if mask&bit:m.rectangle(box,fill=1)
  rng_tile=random.Random(8249+mask*71)
  for y in range(32):
   for x in range(32):
    if not shape.getpixel((x,y)):continue
    c=colors[1]
    if style==0:
     noise=rng_tile.random();c=colors[2] if noise<.15 else colors[0] if noise<.32 else colors[1]
    elif style==1:c=colors[0] if y%8==0 or (x+(y//8%2)*8)%16==0 else colors[2] if y%8==1 else colors[1]
    else:c=colors[0] if y%7==0 else colors[2] if y%7==1 else colors[1]
    im.putpixel((x,y),tuple(int(c[i:i+2],16) for i in (1,3,5))+(255,))
  paths.alpha_composite(im,(mask*32,style*32))
paths.save(root/'yard_paths.png')
sheet=Image.new('RGBA',(6*64,64))
for frame in range(6):
 im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
 def r(box,c):d.rectangle(box,fill=c)
 wood='#a48658';light='#ddc291';dark='#514836';metal='#69877c'
 if frame%2==0:
  for x in (16,45):r((x,35,x+3,62),dark);r((x+1,35,x+2,59),wood);r((x,34,x+3,36),light)
  if frame in (0,2):
   for y in (43,53):r((16,y,48,y+3),dark);r((16,y,48,y+1),wood);r((17,y,47,y),light)
   if frame==2:r((20,40,23,59),wood);r((40,40,43,59),wood);r((43,48,47,50),metal)
  else:
   r((17,38,22,51),wood);r((18,38,19,50),light);r((18,48,22,49),metal)
 else:
  for y in (32,59):r((43,y,47,min(y+4,63)),dark);r((44,y,46,min(y+2,63)),wood)
  if frame in (1,3):
   for x in (38,44):r((x,32,x+2,63),dark);r((x,32,x+1,63),wood)
   if frame==3:r((37,39,46,42),wood);r((37,53,46,56),wood);r((36,53,38,55),metal)
  else:r((31,34,45,38),wood);r((32,34,43,35),light)
 sheet.alpha_composite(im,(frame*64,0))
sheet.save(root/'yard_fences.png')
rate=22050;seconds=.075;rng=random.Random(741);samples=[]
for i in range(int(rate*seconds)):
 t=i/rate;v=(math.sin(2*math.pi*260*t)*.5+rng.uniform(-1,1)*.25)*math.exp(-t*58)*.13
 samples.append(struct.pack('<h',round(v*32767)))
with wave.open(str(root/'audio/yard_gate.wav'),'wb') as w:
 w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(samples))
print('yard_paths.png, yard_fences.png, yard_gate.wav')
