"""Original tiny homestead inventory art and quiet work cue. Reproducible, no downloads."""
from PIL import Image,ImageDraw
from pathlib import Path
import math,random,wave,struct
root=Path(__file__).resolve().parent.parent
im=Image.new('RGBA',(128,16));d=ImageDraw.Draw(im)
for i in range(8):
 x=i*16
 if i==0:d.line((x+4,14,x+11,3),fill='#bb965c',width=2);d.line((x+7,2,x+13,5),fill='#a3b7bd',width=3)
 elif i in [1,2]:
  d.ellipse((x+2,7,x+14,14),fill='#775338' if i==1 else '#a28751');d.ellipse((x+5,4,x+11,11),fill='#87613e');d.point((x+7,5),fill='#d6c185')
 elif i in [3,4]:
  for a,b in [(4,7),(9,5),(7,12)]:d.ellipse((x+a,b,x+a+3,b+3),fill='#b2a178' if i==3 else '#e8bd8c')
 elif i==5:
  d.line((x+8,2,x+8,5),fill='#769762',width=2)
  for a,b in [(4,5),(9,5),(6,9)]:d.ellipse((x+a,b,x+a+4,b+4),fill='#ac87c4',outline='#5d4d71')
 elif i==6:d.rectangle((x+6,2,x+9,5),fill='#c2ad7d');d.rounded_rectangle((x+4,5,x+11,14),radius=2,fill='#86638c');d.rectangle((x+5,8,x+10,11),fill='#e4d4ae')
 else:d.rounded_rectangle((x+3,4,x+13,14),radius=2,fill='#dba34c');d.rectangle((x+3,2,x+13,5),fill='#a38c66');d.line((x+6,7,x+10,7),fill='#f2d47c',width=2)
im.save(root/'assets/items_home.png')
rng=random.Random(2601);rate=22050
samples=[int(1800*(rng.random()*2-1)*math.sin(math.pi*i/(rate*.12))**2) for i in range(int(rate*.12))]
with wave.open(str(root/'assets/audio/hs_soil.wav'),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(struct.pack('<'+'h'*len(samples),*samples))
