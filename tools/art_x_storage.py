"""Original 32px quiet home chests, deterministic Pillow drawing, no external assets."""
from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parent.parent
im=Image.new('RGBA',(64,32));d=ImageDraw.Draw(im)
for frame in range(2):
 x=frame*32
 def r(box,c):d.rectangle(tuple(v+x if i%2==0 else v for i,v in enumerate(box)),fill=c)
 r((3,25,28,28),'#1a282a99')
 r((3,8,28,24),'#253937');r((4,9,27,23),'#795738')
 r((5,10,26,12),'#c89d63');r((5,14,26,17),'#a77948');r((5,19,26,22),'#8a603c')
 for px in (7,23):
  r((px,9,px+2,23),'#386c67');r((px,9,px,22),'#76b8a5')
 r((3,7,28,9),'#e4c28b');r((3,13,28,14),'#233d3b')
 r((14,12,17,17),'#e4c28b');r((15,14,16,15),'#344b46')
 if frame==1:
  r((5,2,26,6),'#304a46');r((6,2,25,3),'#c49d6b')
  r((11,8,20,10),'#e7d4a2')
 else:
  r((11,4,20,6),'#3b6f67');r((13,3,18,3),'#a8d2b4')
im.save(root/'assets/stock_chest.png')
print('stock_chest.png')
