"""Original workshop sketches and six equipment icons; no external imagery."""
from pathlib import Path
from PIL import Image,ImageDraw
from artlib import strip,outline
from art_x_opening import audio
import math
ROOT=Path(__file__).resolve().parent.parent
def gear(kind):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im);better=kind%2==1
 if kind<2:
  d.polygon([(3,3),(8,2),(10,5),(13,7),(12,13),(5,14),(3,10)],fill='#71827d' if better else '#876844')
  d.line((3,7,12,8),fill='#e0b870',width=2);d.line((4,11,12,11),fill='#c89958',width=2)
  if better:d.rectangle((6,5,8,6),fill='#d8dfd1')
 elif kind<4:
  d.arc((2,1,13,13),180,360,fill='#cfb77c',width=1)
  d.line((3,7,5,10),fill='#cfb77c');d.line((12,7,10,10),fill='#cfb77c')
  d.ellipse((4,6,11,14),fill='#d4b276');d.ellipse((5,7,10,12),fill='#6cd3cb' if better else '#608baf');d.line((6,8,8,8),fill='#d9f5e4')
  if better:d.point((10,4),fill='#d3efe2')
 else:
  d.rectangle((4,3,12,13),fill='#ba8953' if better else '#927a4d')
  d.rectangle((3,4,5,13),fill='#4e7368');d.rectangle((11,4,13,13),fill='#4e7368')
  for y in (5,8,11):d.line((5,y,11,y),fill='#dfbc73')
  d.line((7,3,7,13),fill='#5e6a49');d.line((10,3,10,13),fill='#5e6a49')
  if better:d.rectangle((6,0,10,2),fill='#d5dfc5')
 return outline(im)
def note(kind,frame):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 d.rectangle((3,8,20,18),fill=['#79593e','#53666b','#74714f'][kind]);d.rectangle((4,7,19,16),fill='#d1bc84')
 d.line((12,8,12,16),fill='#9b824f')
 d.line((5,9,9,9),fill='#7f7047');d.line((5,12,9,12),fill='#7f7047');d.line((5,14,9,14),fill='#7f7047')
 if kind==0:d.line((14,10,18,14),fill='#577278',width=2);d.line((17,9,15,11),fill='#ad784c',width=2)
 elif kind==1:d.ellipse((14,9,18,14),outline='#468c95',width=2)
 else:
  d.rectangle((14,10,18,14),fill='#9c7c42');d.line((14,12,18,12),fill='#e1cd87')
 d.rectangle((4,19,6,22),fill='#67503a');d.rectangle((17,19,19,22),fill='#67503a')
 d.point((18 if frame else 17,4),fill='#ffe9ae')
 return outline(im)
if __name__=='__main__':
 strip([gear(i) for i in range(6)]).save(ROOT/'assets/pg_gear.png')
 strip([note(k,f) for k in range(3) for f in range(2)]).save(ROOT/'assets/pg_notes.png')
 audio('pg_pattern',.45,lambda t,r:math.sin(t*math.tau*(520 if t<.18 else 780))*.28*max(0,1-t/.45))
 audio('pg_forge',.28,lambda t,r:(math.sin(t*math.tau*340)*.4+r.uniform(-.2,.2))*math.exp(-t*15))
