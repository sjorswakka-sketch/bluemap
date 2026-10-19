"""Original native 32px character drawing. No source sprite is resized or traced.
Legacy atlases remain untouched; detailed world art and tintable layers are separate.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
import json,re
ROOT=Path(__file__).resolve().parent.parent
INK='#28363e';SKIN='#edbd90';HAIR='#72503a';BLUE='#477da2'
def mix(c,k):
 c=tuple(bytes.fromhex(c.lstrip('#')));return tuple(max(0,min(255,round(v*k))) for v in c)+(255,)
def blank():return Image.new('RGBA',(32,32))
def poly(d,p,c):d.polygon(p,fill=c)
def stitch(d,x,y,c):d.line((x,y,x+2,y),fill=c);d.point((x,y+1),fill=c)
def head(im,row,skin=SKIN):
 d=ImageDraw.Draw(im);dark=mix(skin,.73);light=mix(skin,1.12)
 if row<2:
  poly(d,[(10,2),(21,2),(24,5),(24,11),(21,15),(18,16),(13,16),(9,13),(7,10),(7,6)],INK)
  poly(d,[(10,3),(20,3),(23,6),(23,11),(20,14),(13,14),(9,11),(8,7)],skin)
  poly(d,[(20,5),(23,7),(23,11),(20,14),(14,14),(14,13),(20,12)],dark)
  d.line((10,5,11,4,18,4),fill=light);d.line((9,7,9,10),fill=light)
  if row==0:d.point((15,11),fill=dark);d.line((14,13,17,13),fill=mix(skin,.65))
 else:
  poly(d,[(10,2),(20,2),(23,5),(23,8),(26,10),(24,12),(22,12),(21,15),(12,15),(8,12),(7,6)],INK)
  poly(d,[(10,3),(20,3),(22,6),(22,9),(24,10),(22,11),(20,14),(12,14),(9,11),(8,6)],skin)
  d.line((11,4,18,4),fill=light);d.rectangle((9,9,11,11),fill=dark);d.point((10,9),fill=light)
  d.line((19,13,21,13),fill=mix(skin,.65))
 return im

def legs(d,row,step,pants='#414e60',boots='#604c36',mask=False):
 dark=mix(pants,.65);light=mix(pants,1.2);sole=mix(boots,.55)
 spans=[(10,14),(18,22)] if row<2 else ([(11,15),(16,21)] if step==0 else [(9,13),(18,23)] if step==1 else [(13,17),(14,19)])
 for i,(a,b) in enumerate(spans):
  lift=1 if step==i+1 else 0
  d.rectangle((a,24,b,29-lift),fill=INK if not mask else dark)
  d.rectangle((a+1,24,b-1,27-lift),fill=pants if i else dark)
  d.line((a+1,24,a+1,26-lift),fill=light)
  d.rectangle((a-1,28-lift,b,30-lift),fill=sole);d.rectangle((a,28-lift,b,29-lift),fill=boots)
  d.point((a,28-lift),fill=mix(boots,1.35))

def torso(d,row,step,coat=BLUE,skin=SKIN,wide=False,pattern=0):
 side=2 if row==2 else 0;lo=8+side;hi=23-side
 shade=mix(coat,.68);light=mix(coat,1.27)
 poly(d,[(lo+2,16),(hi-2,16),(hi,18),(hi+2,22),(hi,24),(lo,24),(lo-2,22),(lo,18)],INK)
 poly(d,[(lo+2,17),(hi-2,17),(hi,19),(hi,23),(lo,23),(lo,19)],coat)
 poly(d,[(hi-2,18),(hi,19),(hi,23),(hi-3,23)],shade)
 d.line((lo+2,18,lo+2,21),fill=light);d.line((lo+3,17,14,17),fill=light)
 if row<2:
  d.rectangle((14,16,17,18),fill=mix(skin,.8));d.line((13,17,15,19,17,18),fill='#d4d6be' if row==0 else shade)
  for x in (lo-2,hi+1):
   offset=(1 if step==1 else -1 if step==2 else 0)*(1 if x==lo-2 else -1)
   d.rectangle((x,19+offset,x+2,22+offset),fill=shade if x>16 else coat)
   d.rectangle((x,22+offset,x+2,24+offset),fill=mix(skin,.85));d.point((x,22+offset),fill=skin)
 else:
  d.rectangle((18,19,21,23),fill=shade);d.rectangle((18,23,20,25),fill=skin);d.point((18,23),fill=mix(skin,1.1))
 d.rectangle((lo,24,hi,25),fill='#5c4835');d.line((lo,24,hi,24),fill='#a18552')
 if row!=1:d.rectangle((15 if row==0 else 19,24,16 if row==0 else 20,25),fill='#d8be78')
 if pattern%3==1:
  for y in [19,21]:d.line((lo+3,y,hi-3,y),fill=light)
 elif pattern%3==2:
  d.line((15,19,15,22),fill=shade);d.point((16,20),fill='#d8c498');d.point((16,22),fill='#d8c498')
 d.line((11+side,22,13+side,23),fill=shade)

def hair(im,row,style,color=HAIR,mask=False):
 d=ImageDraw.Draw(im);shade=mix(color,.60);light=mix(color,1.28);length=style.get('len',1)
 if style.get('bald'):return
 if length==0:
  d.line((10,3,20,3,22,5),fill=shade);return
 poly(d,[(8,5),(10,2),(20,1),(23,4),(24,8),(22,8),(20,6),(14,7),(10,8),(8,7)],shade)
 poly(d,[(9,5),(11,3),(19,2),(22,4),(22,6),(18,5),(15,6),(10,7)],color)
 d.line((11,4,14,3,18,3),fill=light);d.point((10,5),fill=light);d.line((19,4,21,5),fill=light)
 if row==1:
  poly(d,[(8,6),(23,6),(23,11 if length<3 else 20),(20,14 if length<3 else 23),(11,14 if length<3 else 22),(8,11 if length<3 else 19)],color)
  for x in [10,14,18,21]:d.line((x,7,x-1,12 if length<3 else 20),fill=shade)
  d.line((10,7,11,11),fill=light)
 elif row==0:
  if length>=2:
   for x in [8,22]:d.line((x,7,x,14 if length<3 else 23),fill=shade,width=2);d.line((x,8,x,12 if length<3 else 20),fill=color)
  bangs=style.get('bangs',0)
  if bangs==3:
   poly(d,[(10,6),(15,5),(14,9),(11,11),(9,9)],color);poly(d,[(16,5),(21,6),(23,10),(20,11),(17,8)],color)
  elif bangs:poly(d,[(10,6),(21,5),(20 if bangs!=2 else 15,9),(17 if bangs!=2 else 12,10),(14,8),(11,9)],color)
 else:
  d.rectangle((8,6,13,12 if length<2 else 15),fill=shade);d.line((9,7,10,11),fill=light)
  if length>=3:poly(d,[(8,10),(13,11),(14,21),(10,23),(7,19)],shade);d.line((9,12,10,20),fill=color)
  if style.get('bangs'):poly(d,[(14,5),(22,6),(20,10),(18,8)],color)
 if style.get('top')==1:poly(d,[(11,3),(14,0),(20,1),(21,3)],color);d.line((14,1,18,1),fill=light)
 if style.get('top')==2:d.rectangle((15,0,18,6),fill=color);d.line((15,0,16,0),fill=light)
 if style.get('top')==3:d.line((16,3,15,6),fill=shade)
 if style.get('curl'):
  for x,y in [(8,5),(11,2),(15,1),(20,2),(23,5)]:d.rectangle((x,y,x+2,y+2),fill=color);d.point((x,y),fill=light)
 if style.get('vol'):d.rectangle((6,6,8,10),fill=shade);d.rectangle((23,5,25,10),fill=color)
 if style.get('spiky'):
  for x,y in [(8,2),(13,0),(19,0),(23,3)]:poly(d,[(x,y+4),(x,y),(x+3,y+3)],color)
 if style.get('bun'):d.ellipse((5 if row==2 else 12,1,10 if row==2 else 19,6),fill=shade);d.line((7 if row==2 else 14,2,9 if row==2 else 17,2),fill=light)
 if style.get('tail'):
  x=6 if row==2 else 16 if row==1 else 23
  for y in range(12,25,3):
   offset=(1 if (y//3)%2 else -1) if style.get('tail')==2 else 0
   d.rectangle((x+offset,y,x+2+offset,y+3),fill=color);d.point((x+2+offset,y+2),fill=shade)
  d.line((x,24,x+2,24),fill=light)
 if style.get('sidetail'):d.line((24,8,24,20),fill=color,width=2);d.point((24,9),fill=light)

# Palettes and signature clothing follow the original authored character descriptions.
NPCS={
'bram':('#73548d','#d4d4cf','wizard'), 'greta':('#a45d4e','#aa653f','apron'), 'tobias':('#688f66','#765238','vest'),
'mila':('#e2dbcb','#cfb47a','apron'), 'pim':('#6485a5','#805334','child'), 'hein':('#7d8fa8','#6b5038','guard'),
'anja':('#9072ac','#513e49','dress'), 'joost':('#ba8b5d','#afb1ac','straw'), 'wilfred':('#90b6bd','#ced9d0','guard'),
' tessa':('#678d64','#a56842','archer'), 'bruno':('#986c4a','#51463c','bruno'), 'lotte':('#92714f','#ad764b','apron'),
'kasper':('#826299','#9e7a56','vest'), 'elke':('#779264','#728455','apron'), 'willem':('#79688f','#c5c5c7','beard'),
'mira':('#adc7d3','#9eb6ca','hood'), 'tomas':('#8d7b64','#d0c5ab','beard'), 'noor':('#aa8056','#6b4c3a','vest'),
'fenna':('#617e9d','#b77548','fur'), 'roos':('#8d7251','#914e3d','fur'), 'olav':('#748c7c','#b7b8bd','beard'),
'jelle':('#aa9166','#725039','fur'), 'sana':('#6baba0','#70503c','hood'), 'nour':('#b97e5d','#564533','turban'),
'vera':('#976da1','#62506c','dress'), 'meer_joris':('#c2a450','#ccc9bd','cap'), 'meer_lena':('#688c77','#845137','glasses'),
'meer_sanne':('#699a94','#be824c','dress'), 'stien':('#9c785b','#6e523b','hood'), 'mees':('#7c966c','#987146','straw'),
'wouda':('#536d57','#8f9b6a','hood'), 'rg_ise':('#778f9a','#6b4c34','sailor'), 'rg_raf':('#9a8662','#585c50','cap'),
'op_courier':('#a37a60','#674b37','courier'), 'op_gardener':('#688963','#8e6845','straw')}
NPCS={name.strip():spec for name,spec in NPCS.items()}

MEMORY=[('#66899a','#79563e','miner'),('#628e5b','#89533d','archer'),('#bb7c57','#d3b593','apron'),('#657db0','#7c5941','glasses'),('#977b4d','#6e7960','cap'),('#bb9560','#e7d6ac','turban'),('#9076a9','#573f49','dress'),('#59938b','#49716a','courier')]
def costume(im,row,role,coat,color,seed=0):
 d=ImageDraw.Draw(im);paper='#dacaa3';metal='#b3c8ca';shade=mix(coat,.65)
 if role in ['apron','miner']:
  poly(d,[(12,18),(20,18),(23,27),(9,27)],'#bfa880' if role=='apron' else '#7b7869');d.line((13,19,13,24),fill='#e1c99c');d.rectangle((13,23,19,25),fill='#8d795e')
 if role in ['vest','courier']:
  d.line((10,17,19,25),fill=paper,width=2);d.line((11,18,19,25),fill='#77634b');d.rectangle((20,22,25,27),fill='#7a5c3e');d.line((21,23,24,23),fill='#b69a62')
 if role in ['dress','wizard','witch','hood']:
  poly(d,[(11,22),(21,22),(24,29),(8,29)],coat);d.line((11,24,10,28),fill=mix(coat,1.27));d.line((19,23,21,28),fill=shade);d.line((10,29,23,29),fill=shade)
 if role in ['guard','fur']:
  d.rectangle((9,17,13,19),fill=metal if role=='guard' else paper);d.rectangle((19,17,23,19),fill=mix(metal,.7) if role=='guard' else '#aa9a7a');d.line((10,17,13,17),fill='#e0ddbf')
 if row==1:
  if role in ['courier','archer','miner']:d.rectangle((11,18,21,26),fill='#8b7351');d.line((12,19,19,19),fill='#c8ad79');d.rectangle((14,23,17,24),fill='#594e3d')
 if role in ['wizard','witch']:
  poly(d,[(6,7),(11,4),(14,0),(19,2),(23,6),(26,7),(25,9),(6,9)],coat);d.line((10,6,16,2,20,5),fill=mix(coat,1.32));d.point((16,5),fill=paper)
 if role in ['cap','sailor','miner','straw','fur','guard','turban','hood']:
  hat=paper if role in ['straw','turban'] else metal if role in ['guard','miner'] else coat
  poly(d,[(8,5),(10,2),(21,2),(24,5),(25,7),(7,7)],mix(hat,.67));poly(d,[(9,5),(11,3),(20,3),(23,5),(23,6),(9,6)],hat)
  d.line((8,7,25,7),fill=mix(hat,1.2))
  if role=='straw':
   d.line((5,8,27,8),fill='#c9ae72');
   for x in range(9,24,3):d.point((x,4),fill='#927447')
  if role=='miner':d.rectangle((15,3,18,5),fill='#e9cf86');d.point((16,3),fill='#fff2b4')
  if role=='hood':d.line((8,7,8,13),fill=hat,width=2);d.line((23,7,23,13),fill=mix(hat,.7),width=2)
  if role=='turban':d.line((11,3,22,5),fill='#eee2bc');d.line((9,5,21,6),fill='#a48a63');d.line((9,9,9,19),fill=hat,width=2)
 if row!=1 and role in ['beard','wizard']:
  poly(d,[(11,12),(15,14),(20,12),(20,17),(16,20),(12,17)],color);d.line((12,14,14,17),fill=mix(color,1.2));d.point((17,17),fill=mix(color,.7))
 if row!=1 and role=='glasses':
  for x in [10,18]:d.rectangle((x,10,x+4,13),outline='#5b5c59')
  d.line((14,11,18,11),fill=paper)
 if role=='archer':d.line((23,17,26,24),fill='#b79e6b');d.point((25,18),fill='#ded4b2')
 if role=='sailor':
  for y in [19,21]:d.line((11,y,21,y),fill=paper)
 # Individual embroidered accent; different arrangements do not just recolor the same sprite.
 stitch(d,10+seed%3,20+seed%2,mix(coat,1.35))

def identity_details(im,row,step,name,coat,color,skin):
 d=ImageDraw.Draw(im);front=row!=1;paper='#ded3b4';gold='#d0b56e'
 def hat(shade,wide=False):
  poly(d,[(9,5),(11,2),(20,2),(23,5),(23,7),(8,7)],mix(shade,.65));poly(d,[(10,4),(12,3),(20,3),(22,5),(21,6),(10,6)],shade)
  d.line((5 if wide else 7,8,27 if wide else 25,8),fill=mix(shade,1.2));d.line((10,6,22,6),fill=mix(shade,.68))
 def book():
  d.rectangle((21,21,27,27),fill='#885649',outline=INK);d.line((22,26,26,26),fill=paper);d.point((24,23),fill=gold)
 def herbs():
  for x,y in [(25,20),(28,18),(27,22)]:d.line((25,26,x,y),fill='#6a7849');d.line((x-1,y,x+1,y),fill='#94b077');d.point((x,y-1),fill='#b6c78d')
 def staff(crystal=False):
  d.line((28,10,28,30),fill='#594c39',width=2);d.line((28,11,28,28),fill='#b89b70')
  if crystal:poly(d,[(28,5),(30,8),(28,12),(26,8)],'#8cbcc6');d.point((28,7),fill='#d9e5cf')
 def fur():
  d.line((10,17,21,17),fill=paper,width=2)
  for x in [10,13,18,21]:d.point((x,19),fill='#ab9d7f')
 if name=='bram':staff(True)
 if name=='greta':
  if front:d.line((10,6,22,6),fill='#b96a53',width=2);d.rectangle((12,19,20,26),fill='#775b42');d.line((13,20,13,25),fill='#b28b60')
 if name in ['tobias','kasper','noor']:
  shade={'tobias':'#8e714e','kasper':'#765c8b','noor':'#8c7155'}[name];hat(shade,True)
  if name!='noor':d.line((23,4,26,1),fill='#a0b879' if name=='tobias' else '#c07976',width=2);d.point((26,1),fill='#d3c58f')
 if name=='mila':
  if front:d.line((9,4,22,4),fill='#b76666',width=2);poly(d,[(14,3),(16,4),(18,3),(18,6),(16,5),(14,6)],'#ebd8c0');d.rectangle((12,20,20,26),fill='#e4dfcf');d.line((13,22,19,22),fill='#b8b5aa')
 if name=='pim':
  hat('#ad655d');
  for y in [19,22]:d.line((11,y,21,y),fill='#dddccd')
 if name=='hein':
  d.line((15,1,18,1),fill='#b76e60',width=2);d.line((28,4,28,29),fill='#9a7e55');poly(d,[(28,1),(30,6),(26,6)],'#c7d5cc')
 if name=='anja':
  d.line((10,23,22,23),fill=gold,width=2)
  if front:d.line((23,10,23,23),fill=color,width=2);d.point((23,14),fill='#bf746a')
 if name=='joost':
  if front:
   for x in [12,19]:d.line((x,18,x,26),fill='#597b99',width=2)
   d.line((12,23,20,23),fill='#94a9b5');d.line((12,13,20,13),fill='#c4c4b8',width=2)
 if name=='tessa':
  hat(coat);d.line((23,4,26,1),fill='#b56e61',width=2);d.line((25,16,27,25),fill='#b69c6c',width=2);d.point((25,15),fill=paper)
 if name=='bruno':
  d.line((9,6,23,6),fill='#b7685b',width=2);d.line((23,7,24,11),fill='#8a5148')
  for x in [7,23]:d.rectangle((x,17,x+2,19),fill=gold);d.point((x,17),fill='#e2ca88')
  if front:d.line((12,13,20,13),fill='#544536',width=2);d.point((14,14),fill='#544536');d.point((18,14),fill='#544536')
 if name=='lotte':
  d.rectangle((25,21,29,27),fill=INK);d.rectangle((26,22,28,25),fill='#d1b866');d.point((26,22),fill='#ecdaa0');d.arc((25,18,29,23),180,360,fill='#b8a06e')
 if name=='elke':
  d.rectangle((24,23,29,27),fill='#9b7d54');herbs()
  if front:d.line((21,3,23,5),fill='#cc8398');d.line((21,5,23,3),fill='#cc8398');d.point((22,4),fill=gold)
 if name in ['willem','meer_lena']:book()
 if name=='willem':poly(d,[(10,23),(21,23),(24,29),(8,29)],coat);d.line((12,24,11,28),fill=mix(coat,1.25))
 if name=='mira':
  for x,y in [(12,21),(18,24),(14,27)]:d.point((x,y),fill='#e5e9d7');d.point((x,y-1),fill='#b5d5d6')
 if name=='tomas':staff()
 if name=='fenna':
  hat(coat);d.ellipse((14,0,18,3),fill=paper);fur();herbs()
 if name=='roos':
  fur();d.line((10,27,22,27),fill=paper);d.line((24,15,27,23),fill='#ad9266',width=2);d.point((24,14),fill=paper)
  if front:d.line((23,9,23,22),fill=color,width=2)
 if name=='olav':
  fur();d.line((11,18,22,18),fill='#af6b64',width=2);d.rectangle((25,20,28,28),fill=paper);d.point((26,20),fill='#a98b5f')
 if name=='jelle':
  hat('#b49a6c',True);poly(d,[(6,16),(9,16),(9,25),(7,28),(5,24)],'#b18458');d.point((7,18),fill='#765c42');d.point((6,23),fill='#765c42')
 if name=='sana':
  d.line((9,5,23,5),fill=gold);d.line((11,24,21,24),fill=gold);d.ellipse((24,22,29,28),fill='#a3815c');d.point((26,23),fill='#92bfbe')
 if name=='nour':staff(True);d.line((10,23,22,23),fill=gold);d.point((21,4),fill='#be7876')
 if name=='vera':
  d.line((12,17,12,23),fill=gold);d.line((20,17,19,22),fill=gold);d.rectangle((24,22,28,24),fill='#b96e78');d.point((26,21),fill='#cad2cc')
 if name=='meer_joris':
  hat('#60768c')
  if front:d.line((11,13,21,13),fill='#dad9cd',width=2);d.point((11,14),fill='#dad9cd');d.point((21,14),fill='#dad9cd');d.line((12,18,20,18),fill='#e2ca83')
 if name=='meer_sanne':
  hat('#c3aa70',True);d.line((10,6,22,6),fill='#b66e66');d.line((8,10,8,17),fill=color,width=2);d.line((24,10,24,17),fill=color,width=2)
  for x,y in [(12,20),(17,23),(19,27)]:d.point((x,y),fill=paper)
  if row<2:d.rectangle((9,28-int(step==1),14,30-int(step==1)),fill=mix(skin,.8));d.line((10,28-int(step==1),13,28-int(step==1)),fill=skin)
 if name=='stien':
  hat('#8094a0');d.line((8,7,8,15),fill='#8094a0',width=2);d.line((23,7,23,15),fill='#627783',width=2);staff();d.rectangle((26,27,30,30),fill='#aababc')
 if name=='mees':
  d.rectangle((24,23,29,27),fill='#a98b5d')
  for x in [25,27,29]:d.line((x,18-(x%3),x,24),fill='#89956d');d.point((x,18-(x%3)),fill=paper)
 if name=='wouda':staff();herbs()
 if name=='rg_raf':
  d.line((10,18,16,23,22,18),fill='#6f897f',width=2)
 if name=='op_courier':
  d.rectangle((7,21,24,25),fill='#9e7b50');d.line((8,22,23,22),fill='#d1ad75')
  for x in [10,15,20]:d.ellipse((x,18,x+3,23),fill='#d9bf87');d.line((x+1,19,x+1,21),fill='#f0d9a0')

def person(row,step,spec=None,seed=0,identity=''):
 coat,color,role=spec or (BLUE,HAIR,'player')
 skin={'bruno':'#dfab80','meer_joris':'#ddb18c','rg_ise':'#b57f5d','rg_raf':'#d3a376'}.get(identity,SKIN)
 if identity.startswith('memory_'):skin=['#e2b98d','#bc875f','#f0caa0','#af795b','#ceaa7f','#9b694e','#d9a889','#e2bd98'][seed]
 im=blank();d=ImageDraw.Draw(im);legs(d,row,step);torso(d,row,step,coat,skin,pattern=seed)
 head(im,row,skin)
 if spec:
  if identity!='bruno':hair(im,row,{'len':2 if role in ['dress','archer','witch'] else 1,'tail':1 if role=='archer' else 0,'bun':role in ['apron','glasses'],'top':seed%4 if role=='child' else 0},color)
  # Eyes remain facial features, never painted on the back of a head.
  d=ImageDraw.Draw(im)
  if row==0:
   for x in [12,19]:d.point((x,11),fill=INK);d.point((x,10),fill='#f4dfbc')
  elif row==2:d.point((21,9),fill=INK);d.point((21,8),fill='#f3debe')
  costume(im,row,role,coat,color,seed)
  identity_details(im,row,step,identity,coat,color,skin)
 if row==3:im=ImageOps.mirror(person(2,step,spec,seed,identity))
 return im

def hair_styles():
 text=(ROOT/'scripts/data/ext/uiterlijk.gd').read_text(encoding='utf8');out={}
 for section in ['HAIR_M','HAIR_V']:
  part=text.split('const '+section+' := {')[1].split('\n}')[0]
  for k,v in re.findall(r'"([^"\n]+)": (\{[^\n]+\})',part):out[k]=json.loads(v.rstrip(','))
 return out

def clothing(im,row,step,name):
 d=ImageDraw.Draw(im);base='#b9b9b9';dark='#777777';light='#ffffff';ink='#454545';side=row>=2
 if name in ['cloth_cape','cloth_cloak']:
  if row==0:
   poly(d,[(7,16),(10,16),(9,25),(6,26)],base);poly(d,[(23,16),(25,17),(26,26),(23,25)],dark)
  elif row==1:
   poly(d,[(9,15),(22,15),(26,28),(22,30),(8,29),(6,27)],dark);poly(d,[(10,16),(20,16),(23,27),(9,27)],base);d.line((11,18,10,25),fill=light);d.line((17,18,19,27),fill=dark)
  else:poly(d,[(7,15),(12,16),(13,27),(8,29),(5,27)],dark);d.line((8,17,7,25),fill=base)
  if name=='cloth_cloak':poly(d,[(8,6),(11,2),(20,2),(24,6),(23,13),(21,9),(11,8),(9,13)],base)
 elif name=='cloth_backpack':
  if row==1:d.rectangle((10,17,22,27),fill=ink);d.rectangle((11,18,21,26),fill=base);d.rectangle((11,18,21,21),fill=light);d.rectangle((15,22,17,24),fill=dark)
  elif side:d.rectangle((6,18,11,26),fill=dark);d.line((7,19,10,19),fill=base)
  else:d.line((11,17,12,23),fill=base);d.line((21,17,20,23),fill=dark)
 elif name=='cloth_scarf':
  d.line((11,16,20,17),fill=base,width=2);d.line((12,17,21,18),fill=dark);poly(d,[(19,18),(22,18),(21,24),(18,24)],base);d.line((19,19,19,22),fill=light)
 elif name.startswith('cloth_') and name.split('_',1)[1] in ['tunic','blouse','shirt','sweater','vest','dress'] or name=='gear_chest':
  poly(d,[(9,17),(22,17),(25,20),(24,23),(8,23),(6,20)],ink);poly(d,[(10,18),(21,18),(23,20),(23,23),(9,23),(8,20)],base)
  d.line((10,18,12,18),fill=light);d.line((21,19,22,22),fill=dark);d.line((11,22,14,23),fill=dark)
  if name in ['cloth_blouse','cloth_shirt']:poly(d,[(13,17),(16,19),(19,17)],light);d.point((16,21),fill=ink)
  if name=='cloth_vest':d.rectangle((15,18,17,23),fill=dark);d.line((13,18,14,21),fill=light)
  if name=='cloth_sweater':
   for x in range(10,22,3):d.line((x,19,x,22),fill=dark)
  if name=='gear_chest':d.line((10,20,22,20),fill=light);d.rectangle((11,21,20,23),fill=dark)
  if name=='cloth_dress':poly(d,[(10,22),(21,22),(25,29),(7,29)],base);d.line((12,24,10,28),fill=light);d.line((19,23,22,29),fill=dark)
 elif name in ['cloth_trousers','cloth_shorts','cloth_overalls','cloth_skirt']:
  if name=='cloth_skirt':poly(d,[(10,24),(22,24),(24,29),(8,29)],base);d.line((11,25,10,28),fill=light);d.line((20,25,22,29),fill=dark)
  else:
   spans=[(10,14),(18,22)] if row<2 else ([(11,15),(16,21)] if step==0 else [(9,13),(18,23)] if step==1 else [(13,17),(14,19)])
   for i,(a,b) in enumerate(spans):
    lift=int(step==i+1);d.rectangle((a,25,b,26 if name=='cloth_shorts' else 28-lift),fill=dark if i==0 else base);d.line((a+1,25,a+1,26-lift),fill=light)
    if name=='cloth_overalls':d.point((a+2,26),fill=light)
  if name=='cloth_overalls':
   d.rectangle((12,20,20,25),fill=base);d.line((12,18,12,22),fill=light);d.line((20,18,20,22),fill=dark);d.point((13,21),fill=light)
 elif name in ['cloth_shoes','cloth_slippers','cloth_boots','cloth_sandals','gear_boots']:
  spans=[(10,14),(18,22)] if row<2 else ([(11,15),(16,21)] if step==0 else [(9,13),(18,23)] if step==1 else [(13,17),(14,19)])
  for i,(a,b) in enumerate(spans):
   lift=int(step==i+1);top=26 if name in ['cloth_boots','gear_boots'] else 28
   d.rectangle((a-1,top-lift,b,30-lift),fill=dark);d.rectangle((a,top-lift,b,29-lift),fill=base);d.line((a,top-lift,b-1,top-lift),fill=light)
   if name=='cloth_sandals':d.rectangle((a,28-lift,b,28-lift),fill=(0,0,0,0));d.point((a+1,28-lift),fill=base)
 elif name=='gear_gloves':
  hands=[(6,1),(24,-1)] if row<2 else [(18,0)]
  for x,sign in hands:
   offset=(1 if step==1 else -1 if step==2 else 0)*sign
   d.rectangle((x,22+offset,x+2,24+offset),fill=base);d.line((x,22+offset,x+2,22+offset),fill=light);d.point((x+2,24+offset),fill=dark)
 else:
  if name=='cloth_headband':d.line((8,7,23,7),fill=base,width=2);d.point((22,6),fill=light);return
  if name in ['cloth_straw_hat','cloth_felt_hat']:
   poly(d,[(9,5),(10,1),(20,1),(23,5)],base);d.line((5,7,27,7),fill=dark,width=2);d.line((7,6,25,6),fill=light)
   for x in range(11,22,3):d.point((x,3),fill=dark)
  elif name=='cloth_beret':poly(d,[(7,4),(10,1),(20,0),(24,3),(22,6),(9,6)],base);d.line((10,2,18,1),fill=light);d.point((20,0),fill=dark)
  elif name=='cloth_nightcap':poly(d,[(8,6),(10,2),(21,2),(25,9),(27,11),(24,12),(20,6)],base);d.ellipse((24,10,28,14),fill=light);d.line((9,6,20,6),fill=dark)
  elif name=='gear_helmet':poly(d,[(7,6),(10,1),(21,1),(25,6),(23,12),(21,11),(21,7),(10,7),(10,12),(8,12)],dark);poly(d,[(9,5),(11,2),(20,2),(23,5),(21,6),(9,6)],base);d.line((11,3,19,3),fill=light);d.line((16,2,16,6),fill=light)
  else:poly(d,[(8,6),(9,3),(12,1),(20,1),(23,4),(24,7)],base);d.line((8,7,23,7),fill=dark,width=2);d.ellipse((14,0,18,3),fill=light)
 if row==3:im.paste(ImageOps.mirror(im),(0,0))

def sheets():
 out={};manifest={'npcs':{},'hair':{},'clothes':{}}
 def sheet(spec,seed=0,identity=''):
  s=Image.new('RGBA',(96,128))
  for row in range(4):
   for step in range(3):s.paste(person(row,step,spec,seed,identity),(step*32,row*32))
  return s
 out['pixel_player']=sheet(None)
 for index,(name,spec) in enumerate(NPCS.items()):
  name=name if name.startswith('op_') else 'npc_'+name;out['pixel_'+name]=sheet(spec,index,name.removeprefix('npc_'));manifest['npcs'][name]=index
 memory=Image.new('RGBA',(8*64,128))
 for k,spec in enumerate(MEMORY):
  for row in range(4):
   for step in range(2):memory.paste(person(row,step+1,spec,k,'memory_'+str(k)),(k*64+step*32,row*32))
 out['pixel_wm_people']=memory
 # Preserve the arena's four-look × front/back × seated/cheer column order.
 crowd=Image.new('RGBA',(512,32))
 for look,spec in enumerate([NPCS['tobias'],NPCS['anja'],NPCS['joost'],NPCS['mila']]):
  for back in range(2):
   for cheer in range(2):
    im=person(back,0,spec,look);d=ImageDraw.Draw(im)
    if cheer:
     coat=spec[0];skin=['#edbd90','#d1a17b','#c3906b','#e6c5a1'][look]
     for x in [5,25]:
      d.line((x,20,x-1 if x<16 else x+1,11),fill=INK,width=4);d.line((x,19,x,13),fill=coat,width=2);d.rectangle((x-1,9,x+1,12),fill=skin)
    crowd.paste(im,((look*4+back*2+cheer)*32,0))
 out['pixel_arena_crowd']=crowd
 styles=hair_styles();hairs=Image.new('RGBA',(len(styles)*32,128))
 for index,(name,style) in enumerate(styles.items()):
  manifest['hair'][name]=index
  for row in range(4):
   im=blank();hair(im,2 if row==3 else row,style,'#cccccc')
   if row==3:im=ImageOps.mirror(im)
   hairs.paste(im,(index*32,row*32))
 out['character_hair']=hairs
 text=(ROOT/'scripts/data/ext/uiterlijk.gd').read_text(encoding='utf8');names=re.findall(r'^\s*"(cloth_[^"]+)": \{',text,re.M)
 names+=['gear_chest','gear_helmet','gear_boots','gear_gloves']
 layers=Image.new('RGBA',(len(names)*96,128))
 for index,name in enumerate(names):
  manifest['clothes'][name]=index
  for row in range(4):
   for step in range(3):
    im=blank();clothing(im,row,step,name);layers.paste(im,(index*96+step*32,row*32))
 out['character_clothes']=layers
 # A detailed material pass for tiny held work props, independently drawn at native resolution.
 tools=Image.new('RGBA',(9*32,32))
 for k in range(9):
  im=blank();d=ImageDraw.Draw(im)
  if k==0:d.line((6,27,24,7),fill='#624d35',width=4);d.line((6,26,23,7),fill='#c3a16a',width=2);poly(d,[(12,4),(24,5),(29,13),(25,12),(22,9),(13,8)],'#78969f');d.line((13,5,23,6,27,10),fill='#d4dfd4')
  elif k in [1,5]:
   d.rounded_rectangle((7,12,24,27),radius=3,fill='#597a87' if k==1 else '#ad8059',outline=INK);d.line((9,13,20,13),fill='#b5c5b1');d.arc((0,6,14,22),80,280,fill='#8daaa3',width=2);poly(d,[(23,15),(30,11),(30,17),(24,22)],'#8ca9aa')
  elif k in [2,8]:
   d.ellipse((4,12,28,28),fill='#526775');d.ellipse((5,10,27,20),fill='#d1ba82',outline=INK);d.line((14,3,19,15),fill='#e0c695',width=3)
   if k==8:
    for x in [10,15,20]:d.rectangle((x,13,x+2,15),fill='#5e8155')
  elif k==3:d.arc((9,2,23,18),180,360,fill='#b2a070',width=2);d.rectangle((8,13,25,28),fill='#405f6e',outline=INK);d.rectangle((11,15,22,25),fill='#f0d38d');d.line((12,16,12,23),fill='#fff0b7')
  elif k==4:
   d.rectangle((3,14,27,26),fill='#a88e5e',outline=INK);d.line((2,12,28,12),fill='#d3bd83',width=2)
   for x in [7,14,21]:d.line((x,15,x,25),fill='#6f593d')
  else:
   poly(d,[(3,9),(15,7),(29,9),(29,27),(16,25),(3,27)],'#dac79e',);d.line((16,9,16,25),fill='#a99164')
   for y in [13,18,22]:d.line((6,y,12,y),fill='#9c8763');d.line((20,y,26,y),fill='#9c8763')
  tools.paste(im,(k*32,0))
 out['pixel_wm_tools']=tools
 (ROOT/'scripts/data/character_art.gd').write_text('extends RefCounted\n## Generated by tools/art_characters_native.py. Native cells are always 32px.\nconst NPC_SHEETS := '+json.dumps(list(manifest['npcs']))+'\nconst HAIR := '+json.dumps(manifest['hair'])+'\nconst CLOTHES := '+json.dumps(manifest['clothes'])+'\n',encoding='utf8')
 return out
if __name__=='__main__':
 result=sheets()
 for name,im in result.items():im.save(ROOT/'assets'/(name+'.png'));print(name,im.size)
 # Readable original-art evidence, intentionally separate from game textures.
 contact=Image.new('RGBA',(768,((len(NPCS)+7)//8)*116+160),'#526759');d=ImageDraw.Draw(contact)
 for index,name in enumerate(NPCS):
  key=name if name.startswith('op_') else 'npc_'+name;frame=result['pixel_'+key].crop((0,0,32,32)).resize((64,64),Image.Resampling.NEAREST);x=(index%8)*96;y=(index//8)*116
  contact.alpha_composite(frame,(x+16,y+12));d.text((x+3,y+80),name[:14],fill='#e2dac1')
 contact.alpha_composite(result['pixel_player'].resize((192,256),Image.Resampling.NEAREST).crop((0,0,192,128)),(16,contact.height-140))
 (ROOT/'validation').mkdir(exist_ok=True);contact.convert('RGB').save(ROOT/'validation/character-native-review.png')
