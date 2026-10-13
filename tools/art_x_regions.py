"""Original regional landmarks, expedition equipment and sounds; no external assets."""
from pathlib import Path
from PIL import Image, ImageDraw
from artlib import strip, outline
from art_x_opening import audio
import math
ROOT=Path(__file__).resolve().parent.parent

def entrance(style):
 im=Image.new('RGBA',(48,40));d=ImageDraw.Draw(im)
 base=['#ad784d','#71939f','#637c6a'][style];light=['#e3ba7f','#d1e7eb','#9eac79'][style]
 d.polygon([(0,36),(3,17),(11,6),(22,1),(35,5),(44,18),(47,36)],fill=base)
 for x,y in [(5,20),(11,11),(19,5),(30,7),(37,16),(39,27),(4,30)]:
  d.polygon([(x,y),(x+6,y-1),(x+7,y+5),(x-1,y+4)],fill=light)
 d.polygon([(13,37),(13,23),(16,17),(24,13),(31,18),(34,25),(34,37)],fill='#253b40')
 d.polygon([(15,37),(17,26),(30,25),(33,37)],fill=['#806446','#8aabb6','#50786b'][style])
 if style==0:
  d.rectangle((18,8,28,10),fill='#4e96ad');d.polygon([(20,10),(24,6),(27,10)],fill='#9edcea')
 elif style==1:
  d.line((5,9,5,28),fill='#614f41',width=2);d.polygon([(6,9),(15,11),(6,15)],fill='#de9967')
  for x,y in [(10,5),(26,1),(38,8)]:d.rectangle((x,y,x+8,y+2),fill='#eff6e6')
 else:
  for x in [5,40]:
   d.line((x,11,x-2,32),fill='#c0b16b',width=2);d.ellipse((x-2,7,x+1,15),fill='#8d724b')
  d.rectangle((18,7,29,11),fill='#d4bb8b');d.line((20,9,27,9),fill='#698b8e')
 return im

def shelter():
 im=Image.new('RGBA',(40,24));d=ImageDraw.Draw(im)
 for x in (3,36):d.rectangle((x,9,x+1,23),fill='#8a6745')
 d.polygon([(2,10),(9,1),(31,1),(38,10),(29,14),(10,14)],fill='#428399')
 for x in range(7,36,7):d.line((x,3,x-2,11),fill='#85b9c2',width=2)
 d.line((2,10,10,14,29,14,38,10),fill='#c7d6af')
 return im

def objects(i):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 if i in (0,1):
  d.rectangle((4,17,20,22),fill='#817461');d.ellipse((4,14,20,20),fill='#d0b68a');d.ellipse((6,15,18,18),fill='#5a9dad')
  d.rectangle((6,5,9,16),fill='#6c7e7c');d.line((8,7,15,7,15,11),fill='#c0c7a6',width=2)
  if i==1:
   d.polygon([(2,13),(3,4),(11,0),(20,5),(23,13)],fill='#d1ac75');d.ellipse((9,6,16,12),fill='#567f87')
 elif i==2:
  d.polygon([(1,20),(9,3),(22,20)],fill='#b97950');d.polygon([(9,3),(13,20),(22,20)],fill='#d4a26c');d.polygon([(5,20),(9,11),(11,20)],fill='#344a53')
  d.line((20,2,20,22),fill='#7c6752',width=2)
 elif i==3:
  d.rectangle((10,3,14,23),fill='#8c7961');d.rectangle((9,3,15,6),fill='#d1d8bc')
  for y in (12,15,18):d.line((8,y,17,y-2),fill='#d6bc82',width=2)
 elif i==4:
  d.polygon([(2,5),(19,3),(22,18),(4,21)],fill='#d9c395')
  d.line((7,17,9,11,14,14,18,7),fill='#628993',width=2);d.line((5,7,14,6),fill='#8c7450')
 elif i==5:
  d.rectangle((1,3,22,21),fill='#647e74');d.rectangle((3,1,20,19),fill='#abaf8c')
 else:
  d.rectangle((3,14,5,23),fill='#685444');d.rectangle((19,14,21,23),fill='#685444')
  d.rectangle((1,8,22,17),fill='#997c52');d.rectangle((3,5,20,14),fill='#decda3')
  d.line((12,6,12,14),fill='#7e7d68');d.line((5,8,9,8),fill='#688a93');d.line((15,11,19,10),fill='#688a93')
 return im

def relief(i):
 im=Image.new('RGBA',(20,14));d=ImageDraw.Draw(im)
 d.rectangle((0,0,19,13),fill='#d5c292');d.line((1,11,18,11),fill='#7a9e9b',width=2)
 if i==0:
  for x in [3,7,12,16]:d.line((x,10,x-1,4),fill='#647f5d');d.line((x-1,4,x+1,2),fill='#93734d')
 else:
  for x in [3,10]:
   d.rectangle((x,4,x+5,8),fill='#a27c50');d.polygon([(x-1,4),(x+2,1),(x+6,4)],fill='#756d55')
  for x in [4,9,15]:d.line((x,7,x,12),fill='#765c45')
  if i==2:
   for y in [7,9,11]:d.line((1,y,18,y),fill='#668f9a')
 return im

def item(i):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 if i==0:
  d.ellipse((3,5,13,14),fill='#a27d4d');d.rectangle((6,2,10,6),fill='#b6c7b9');d.line((4,5,2,11),fill='#7f6645');d.line((7,8,10,8),fill='#5eb4c8',width=2)
 elif i==1:
  for x,y in [(2,4),(8,2)]:
   d.rectangle((x,y,x+3,y+8),fill='#957953');d.rectangle((x+3,y+4,x+5,y+7),fill='#b39b77');d.line((x,y+8,x+3,y+8),fill='#53636a')
 else:
  d.ellipse((2,2,14,14),fill='#bda166');d.ellipse((4,4,12,12),fill='#435e6a');d.polygon([(8,3),(10,9),(7,8),(6,12)],fill='#8ed3d5');d.point((8,8),fill='#ece0b6')
 return outline(im)

def cliff(i):
 im=Image.new('RGBA',(16,16),'#bc8c5b');d=ImageDraw.Draw(im)
 for y in [3,9,14]:
  d.line((0,y,5+i,y-1,15,y),fill='#cda16b')
 for x,y in [(2,6),(10,12),(13,2),(5,13)]:d.point(((x+i*3)%16,y),fill='#af804f')
 return im

def shelf():
 im=Image.new('RGBA',(28,32));d=ImageDraw.Draw(im)
 d.rectangle((1,1,26,30),fill='#485e58');d.rectangle((3,2,24,29),fill='#9c8e65')
 for y in [3,13,23]:
  d.rectangle((4,y,23,y+7),fill='#384e4d')
  for i,x in enumerate([5,9,13,18,21]):
   d.rectangle((x,y+1,x+2,y+6),fill=['#bba57c','#6c9690','#a37555'][i%3]);d.point((x+1,y+3),fill='#dccfa0')
  d.line((3,y+8,24,y+8),fill='#d1bf91')
 return im

def hatch():
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 d.rounded_rectangle((0,1,15,15),radius=2,fill='#789184')
 d.rectangle((3,3,12,14),fill='#263f46')
 for y in [5,8,11]:
  d.line((4,y,11,y),fill='#b4b89a');d.line((4,y+1,11,y+1),fill='#587e7b')
 d.line((1,2,1,12),fill='#b5bc8b');d.line((14,4,14,14),fill='#56776b')
 return im

if __name__=='__main__':
 for name,frames in [('entrances',[entrance(i) for i in range(3)]),('shelter',[shelter()]),('objects',[objects(i) for i in range(7)]),('reliefs',[relief(i) for i in range(3)]),('items',[item(i) for i in range(3)]),('cliff',[cliff(i) for i in range(3)]),('shelf',[shelf()])]:strip(frames).save(ROOT/'assets'/('ra_'+name+'.png'))
 hatch().save(ROOT/'assets/ra_hatch.png')
 audio('ra_water',0.65,lambda t,r:0.22*math.sin(math.tau*(420*t+180*t*t))*math.exp(-t*6)+r.uniform(-.12,.12)*math.sin(math.pi*t/.65))
 audio('ra_rope',0.7,lambda t,r:(r.uniform(-.2,.2)+.15*math.sin(math.tau*160*t))*math.sin(math.pi*t/.7)**2)
 audio('ra_pages',0.7,lambda t,r:r.uniform(-.22,.22)*max(0,math.sin(t*math.tau*4))*math.sin(math.pi*t/.7))
