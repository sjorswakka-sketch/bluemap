"""Original 32-pixel landscape and selective sprite material pass (no external art).
Run directly to rebuild only this visual pack; make_art.py also includes it.
World footprints, legacy atlases, silhouettes and animation layouts are retained.
"""
from pathlib import Path
import math, random, re
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parent.parent
INK="#263c3c"
def canvas(color):return Image.new("RGBA",(32,32),color)
def terrain(kind,v):
 r=random.Random(7100+v*173+sum(map(ord,kind))*11)
 grass=kind in ("grass","grass_tufts","grass_flowers","oasis_grass","marsh_grass","marsh_tufts","ce_grass")
 snow=kind in ("snow","snow_tufts")
 sand=kind in ("path","meer_sand","arena_sand","dune_sand","dune_tufts","ce_sand","ce_dune")
 water=kind in ("water","bog_water","ce_sea","ce_shore","ice")
 if kind=="mud":
  im=canvas("#797555");d=ImageDraw.Draw(im)
  for j in range(12):
   x,y=r.randrange(32),r.randrange(32)
   d.line((x,y,min(31,x+2+j%3),y),fill="#6b6d50" if j%3 else "#94906b")
  for x,y in [(5+(v*3)%11,12),(18+(v*2)%9,25)]:
   d.line((x,y,x+4,y),fill="#a4aa84");d.line((x+1,y+1,x+5,y+1),fill="#858969")
  return im
 if grass:
  base="#668954" if kind.startswith("marsh") else "#7b9b69" if kind=="ce_grass" else "#67945a" if kind=="oasis_grass" else "#6e9c61"
  im=canvas(base);d=ImageDraw.Draw(im)
  palette=["#527f50","#628f56","#81aa68","#91b875"] if not kind.startswith("marsh") else ["#536f48","#5e7e4f","#7c975d","#8ba46a"]
  # Sparse linked clusters, leaving broad calm mid-tone areas.
  for j in range(15):
   x,y=r.randrange(32),r.randrange(32);col=palette[j%len(palette)]
   d.line((x,y,x+r.randrange(1,4),y),fill=col)
   if j%4==0:d.point((x+1,y-1),fill=col)
  if kind in ("grass_tufts","marsh_tufts","ce_grass","oasis_grass"):
   for x,y in [(6+v%4,13),(23,25)]:
    d.line((x-2,y-3,x,y,x+2,y-4),fill=palette[0]);d.point((x-2,y-4),fill=palette[2])
  if kind=="grass_flowers":
   # Small flowers, not a full carpet of bright crosses.
   for x,y,col in [(7,10,"#e9deaf"),(23,25,"#d7bac2")]:
    d.line((x,y+1,x-1,y+4),fill=palette[0]);d.rectangle((x-1,y-1,x+1,y+1),fill=col);d.point((x,y),fill="#d4b465")
  return im
 if snow:
  im=canvas("#c7d9dc");d=ImageDraw.Draw(im)
  for j in range(9):
   x,y=r.randrange(32),r.randrange(32);d.line((x,y,x+4,y),fill="#b7cdd4" if j%2 else "#e1e8df")
  if kind=="snow_tufts":
   for x,y in [(8,12),(24,25)]:
    d.line((x-2,y-3,x,y+1,x+2,y-4),fill="#7a9b98");d.line((x-2,y-3,x,y-2),fill="#f0eee2")
  return im
 if sand:
  base="#c9b084" if kind=="path" else "#d5bd88" if kind in ("dune_sand","dune_tufts","arena_sand") else "#c8c29b"
  im=canvas(base);d=ImageDraw.Draw(im)
  for j in range(20):
   x,y=r.randrange(32),r.randrange(32);d.line((x,y,x+(1 if j%4 else 2),y),fill="#e1cda0" if j%2 else "#b79e76")
  if kind in ("dune_sand","dune_tufts","ce_dune"):
   for y in (8,23):
    for x in range(0,32,2):
     yy=y+round(math.sin((x+v*3)*.16)*2);d.point((x,yy),fill="#bda778");d.point((x,yy-1),fill="#e7d2a0")
  if kind=="dune_tufts":
   for x,y in [(7,14),(25,28)]:d.line((x-2,y-4,x,y,x+2,y-5),fill="#9d9160")
  return im
 if water:
  base={"water":"#397f91","bog_water":"#4a7468","ce_sea":"#346b85","ce_shore":"#528e98","ice":"#91bdc9"}[kind]
  im=canvas(base);d=ImageDraw.Draw(im)
  for j in range(3):
   x,y=(v*7+j*13)%30,(j*11+v*3)%32
   col="#45899a" if kind=="water" else "#407a90" if kind=="ce_sea" else "#6b9f9c" if kind=="ce_shore" else "#578171" if kind=="bog_water" else "#b5d6d9"
   d.line((x,y,min(31,x+5),y),fill=col)
  return im
 return None

def tree(kind,v):
 basekind="snow" if kind=="pine" else "marsh_grass" if kind=="willow" else "grass"
 im=terrain(basekind,v);d=ImageDraw.Draw(im)
 # One readable crown inside the original solid 32x32 footprint.
 d.ellipse((3,22,31,31),fill="#4c764d" if kind!="pine" else "#9ebcc5")
 d.polygon([(13,16),(20,16),(21,29),(24,30),(11,30),(14,27)],fill="#514b35")
 d.rectangle((14,18,16,28),fill="#93734a");d.line((18,20,19,29),fill="#3a4031")
 if kind=="dead_tree":
  for a,b in [((16,24),(16,4)),((16,14),(7,6)),((16,19),(27,9)),((12,10),(12,5))]:
   d.line((*a,*b),fill="#514a37",width=3);d.line((a[0]-1,a[1],b[0]-1,b[1]),fill="#967851")
  return im
 if kind=="pine":
  for top,bottom,w in [(1,14,9),(6,21,12),(13,27,14)]:
   d.polygon([(16,top),(16-w,bottom),(16+w,bottom)],fill="#315d58")
   d.polygon([(16,top),(16-w+1,bottom-3),(16,bottom-6)],fill="#538076")
   d.polygon([(16,top),(16-w+3,bottom-6),(16+w-3,bottom-6)],fill="#dce5dc")
   d.line((16-w+3,bottom-5,16,bottom-7),fill="#a9c6cb")
 elif kind=="willow":
  d.ellipse((2,2,30,24),fill="#416b50");d.ellipse((4,2,26,18),fill="#628653")
  for j in range(10):
   x=3+j*3;y=8+(j*7)%7;d.line((x,y,x-1,min(28,y+8+(j*3)%9)),fill=["#7b9b61","#4f7a51","#92aa70"][j%3],width=2)
 else:
  shapes=[((3,5,28,25),"#305f46"),((1,8,15,23),"#3c774b"),((14,5,30,22),"#396d48"),((5,1,24,18),"#4c8850"),((5,2,19,13),"#679e5a"),((9,0,23,9),"#6ca15c")]
  for box,col in shapes:d.ellipse(box,fill=col)
  for j in range(12):
   x,y=rnd=(4+(j*7+v*3)%24,4+(j*5+v)%17)
   if im.getpixel((x,y))[:3] in [(48,95,70),(60,119,75),(76,136,80),(103,158,90),(108,161,92),(57,109,72)]:
    d.line((x,y,x+2,y),fill="#80ae68" if j%3 else "#346648")
  d.line((8,7,12,5),fill="#9cc079",width=1)
 return im

def mineral_floor(kind,v):
 r=random.Random(900+v*73)
 palette=("#625b62","#766d71","#4c4852","#8e827b") if kind=="cave_floor" else ("#42445f","#575774","#30364d","#78728d")
 im=canvas(palette[0]);d=ImageDraw.Draw(im)
 if kind=="void_floor":
  d.polygon([(0,6),(6,0),(25,0),(31,6),(31,25),(25,31),(6,31),(0,25)],outline=palette[2])
  d.line((1,6,6,1,24,1),fill=palette[1]);d.line((2,26,6,30,25,30,30,25),fill=palette[2])
 for j in range(14):
  x,y=r.randrange(32),r.randrange(32)
  if j<3:
   d.line((x,y,x+2,y-1,x+5,y-1),fill=palette[2])
   d.line((x,y+1,x+2,y),fill=palette[1])
  else:d.line((x,y,x+1,y),fill=palette[1] if j%2 else palette[3])
 return im

def cliff(kind,v):
 im=canvas("#687064" if kind=="cave_wall" else "#9a9576");d=ImageDraw.Draw(im)
 palettes=("#3e4447","#6d736d","#929184","#515b57") if kind=="cave_wall" else ("#666e62","#a8a187","#c9c19a","#81846d")
 for j in range(4):
  y=j*8;offset=(v*5+j*11)%10
  d.polygon([(0,y+2),(9+offset,y),(24,y+1),(31,y-1),(31,y+7),(19,y+9),(3,y+7),(0,y+9)],fill=palettes[j%2],outline=palettes[0])
  d.line((2,y+3,11+offset,y+1,23,y+2),fill=palettes[2])
  d.line((18,y+5,24,y+4),fill=palettes[3])
 return im

def masonry(kind,v):
 if kind in ("cave_floor","void_floor"):return mineral_floor(kind,v)
 if kind in ("cave_wall","ce_cliff"):return cliff(kind,v)
 r=random.Random(200+v);wood=kind in ("wood_floor","wood_wall","counter","shelf","crate","bridge","ce_boardwalk")
 if wood:
  im=canvas("#96764f" if kind in ("wood_floor","ce_boardwalk","bridge") else "#6c503b");d=ImageDraw.Draw(im)
  for y in range(0,32,8):
   d.line((0,y,31,y),fill="#513f34");d.line((0,y+1,31,y+1),fill="#b59462")
   joint=(v*11+y*3)%32;d.line((joint,y+1,joint,y+6),fill="#65503b")
   d.line((4,y+5,14,y+5),fill="#886947");d.point((joint+2,y+3),fill="#483d34")
  if kind in ("wood_wall","shelf","counter"):
   for x in [0,28]:d.rectangle((x,0,x+3,31),fill="#473e34");d.line((x,0,x,31),fill="#9a7b53")
  if kind=="crate":
   for a,b in [((3,4),(27,28)),((27,4),(3,28))]:d.line((*a,*b),fill="#c09a62",width=3)
   d.rectangle((1,2,30,30),outline="#443c32",width=2)
  return im
 wall=kind in ("stone","cave_wall","ruin_wall","ruin_pillar","temple_wall","void_wall","arena_wall","arena_tribune","sandstone","ce_cliff","ad_seawall","cave_crystal","void_crystal","stalagmite")
 palette=("#7f8c8d","#b3b9ae","#536369") if kind in ("stone","temple_wall","temple_floor","temple_rune") else ("#74675d","#a39880","#493f42") if kind.startswith("cave") or kind=="stalagmite" else ("#667b72","#95a18a","#3f5250") if kind.startswith("ruin") else ("#544f70","#89809d","#35364f") if kind.startswith("void") or kind=="rune_pad" else ("#a08c68","#c8b389","#655d50") if kind in ("sandstone","ce_cliff","arena_wall","arena_tribune") else ("#6c8587","#a2b6af","#415a65")
 im=canvas(palette[0]);d=ImageDraw.Draw(im)
 step=10 if wall else 16
 for y in range(-step,32,step):
  offset=(y//step%2)*12
  for x in range(-24+offset,32,24):
   col=palette[0]
   d.rectangle((x,y,x+22,y+step-2),fill=col)
   d.line((x,y,x+22,y),fill=palette[1]);d.line((x,y,x,y+step-2),fill=palette[1])
   d.line((x,y+step-1,x+23,y+step-1),fill=palette[2]);d.line((x+23,y,x+23,y+step-1),fill=palette[2])
   if wall:
    d.line((x+4,y+step-3,x+9,y+step-3),fill=palette[2])
 for j in range(7):
  x,y=r.randrange(32),r.randrange(32)
  if j%2==0:d.point((x,y),fill=palette[1])
 if kind in ("cave_crystal","void_crystal","temple_rune","rune_pad"):
  col="#9bcdd0" if kind=="cave_crystal" else "#bbace0"
  d.polygon([(16,3),(24,11),(21,25),(11,27),(7,14)],fill="#465c85",outline="#2d3855")
  d.polygon([(16,3),(16,23),(8,14)],fill=col);d.polygon([(17,5),(23,11),(17,22)],fill="#77a5c0")
  d.line((15,6,11,14),fill="#dfedda",width=2)
 return im

def nature_prop(kind,v):
 im=terrain("grass",v);d=ImageDraw.Draw(im)
 if kind=="rock":
  d.ellipse((3,23,31,31),fill="#50754c")
  d.polygon([(3,22),(6,12),(12,7),(23,8),(28,16),(29,26),(22,30),(8,29)],fill="#525f64",outline="#354c4e")
  d.polygon([(5,21),(8,13),(14,9),(22,10),(25,17),(18,21),(10,23)],fill="#a6b4ac")
  d.polygon([(10,23),(18,21),(25,17),(27,25),(21,28),(9,27)],fill="#7b8d8b")
  d.line((8,15,14,10,20,10),fill="#d1d6be",width=1);d.line((15,13,14,18,17,20),fill="#748a85")
  d.point((23,24),fill="#596c6c")
 elif kind=="bush":
  d.ellipse((2,20,31,31),fill="#50754c")
  for box,col in [((1,12,27,28),"#315d43"),((12,9,31,27),"#42734b"),((2,6,23,22),"#5c8d52"),((6,7,18,15),"#82a55d")]:d.ellipse(box,fill=col)
  for x,y in [(9,19),(22,15),(19,25)]:
   d.rectangle((x,y,x+2,y+2),fill="#b46a63");d.point((x,y),fill="#e3a17d")
  for x,y in [(5,17),(13,11),(26,20)]:d.line((x,y,x+2,y),fill="#8aac61")
 return im

def architecture(kind,v):
 im=canvas("#d9cfaa");d=ImageDraw.Draw(im)
 if kind=="roof":
  im=canvas("#a55f4e");d=ImageDraw.Draw(im)
  for y in range(-4,32,8):
   for x in range(-12+(y//8%2)*8,32,16):
    d.polygon([(x,y),(x+15,y),(x+14,y+6),(x+10,y+8),(x+1,y+7)],fill="#b56e55",outline="#794b43")
    d.line((x+2,y+1,x+13,y+1),fill="#d18b65");d.line((x+3,y+3,x+3,y+5),fill="#bd795b")
  return im
 for j in range(10):
  x,y=(j*13+v*3)%32,(j*7+v)%32;d.line((x,y,x+2,y),fill="#cec29e")
 for x in [0,29]:
  d.rectangle((x,0,x+2,31),fill="#665341");d.line((x,1,x,30),fill="#998060")
 d.rectangle((0,29,31,31),fill="#655342");d.line((0,29,31,29),fill="#9d8461")
 if kind=="house_window":
  d.rectangle((6,5,25,25),fill="#5c4d3e");d.rectangle((8,7,23,22),fill="#527d88")
  d.polygon([(8,7),(22,7),(8,18)],fill="#9bbdb8");d.line((9,8,14,8),fill="#dfdec2")
  d.line((15,7,15,23),fill="#6b5740",width=2);d.line((8,14,23,14),fill="#6b5740",width=2)
  for x in [3,26]:d.rectangle((x,6,x+2,23),fill="#71816a");d.line((x,10,x+2,10),fill="#a3a47c")
  d.rectangle((5,24,26,26),fill="#9c8055");d.line((5,24,26,24),fill="#d3b984")
 if kind=="door":
  d.rectangle((5,1,26,31),fill="#4b463b");d.rectangle((7,3,24,30),fill="#886342")
  for x in [8,13,18,23]:d.line((x,4,x,29),fill="#624e38")
  d.line((8,4,22,4),fill="#b18c57");d.rectangle((8,10,23,11),fill="#514b40");d.rectangle((8,25,23,26),fill="#514b40")
  d.rectangle((20,17,22,19),fill="#e2bd6a");d.point((20,17),fill="#f0d790")
  d.rectangle((4,30,27,31),fill="#9ba39a")
 return im

def canopy(kind,v):
 im=Image.new("RGBA",(48,64));d=ImageDraw.Draw(im);r=random.Random(430+v)
 if kind=="pine":
  for top,bottom,w in [(0,25,10),(11,37,16),(25,51,21)]:
   d.polygon([(24,top),(24-w,bottom-4),(24-w+5,bottom),(24+w-4,bottom),(24+w,bottom-4)],fill="#294e49",outline="#263f3d")
   d.polygon([(24,top+2),(24-w+2,bottom-5),(24,bottom-10)],fill="#4d7766")
   d.polygon([(24,top+2),(24-w+5,bottom-10),(24+w-5,bottom-10)],fill="#d3e0d8")
   d.line((24-w+5,bottom-9,24,bottom-12),fill="#9dbbc0")
 elif kind=="willow":
  d.ellipse((2,4,46,43),fill="#355640");d.ellipse((4,2,40,35),fill="#61834f")
  for j in range(14):
   x=4+j*3;y=14+(j*7)%11
   d.line((x,y,x-2,min(57,y+15+(j*3)%14)),fill=["#54774b","#7b985a","#a0ae6e"][j%3],width=2)
  d.ellipse((9,6,25,16),fill="#8fa667")
 else:
  # Irregular interlocking leaf masses. All highlight clusters follow one light direction.
  d.ellipse((5,12,44,53),fill="#294d3d")
  clusters=[((0,21,24,47),"#386d46"),((23,17,47,46),"#315f42"),((4,8,39,40),"#477b49"),((7,1,32,29),"#5b8c50"),((23,4,43,30),"#4c7f4b"),((4,16,25,34),"#639451"),((10,2,29,19),"#78a25b")]
  for box,col in clusters:d.ellipse(box,fill=col)
  for j in range(52):
   x,y=r.randrange(3,45),r.randrange(3,47)
   p=im.getpixel((x,y))
   if p[3] and sum(p[:3])>180:
    col=["#91b46a","#396542","#668e4f","#a4c078"][j%4]
    if j%4==0 and y>23:col="#416b43"
    d.line((x,y,min(x+2,46),y),fill=col)
    if j%3==0:d.point((x+1,y-1),fill=col)
 return im

def station(role):
 im=Image.new("RGBA",(80,80));d=ImageDraw.Draw(im)
 if role=="wine":
  d.ellipse((19,59,64,74),fill="#263d35")
  d.polygon([(24,16),(30,10),(51,10),(59,17),(62,29),(62,55),(58,66),(29,66),(22,56),(21,30)],fill="#785237",outline="#3f3e33")
  for x in (26,32,39,47,54):
   d.line((x,18,x-2,57),fill="#4d4032")
   d.line((x+1,19,x,56),fill="#b78d53")
  d.ellipse((24,9,58,24),fill="#ab8651",outline="#4b4335",width=2)
  d.ellipse((28,12,54,21),fill="#c0a16b",outline="#8a6e44")
  for y in (25,53):
   d.rectangle((22,y,61,y+5),fill="#526265");d.line((23,y,60,y),fill="#9caaa0");d.line((24,y+5,59,y+5),fill="#34464c")
   for x in (27,53):d.point((x,y+2),fill="#c2c8ac")
  d.rectangle((49,45,55,49),fill="#d0b975");d.rectangle((52,47,55,54),fill="#8b8155");d.point((50,45),fill="#ede1af")
 elif role=="hive":
  d.ellipse((9,62,72,76),fill="#496a47")
  for x in (21,56):d.rectangle((x,56,x+5,71),fill="#624f38")
  for y in (22,35,48):
   d.rectangle((17,y,63,y+11),fill="#a97c43",outline="#5e4d34")
   d.line((18,y+1,61,y+1),fill="#debd76");d.line((20,y+3,61,y+3),fill="#cda462")
   d.line((22,y+8,32,y+8),fill="#88653e")
  d.polygon([(10,23),(39,9),(69,23),(64,27),(39,15),(15,27)],fill="#5b5140",outline="#39483c")
  d.line((13,22,39,10,67,22),fill="#b4a46b",width=2)
  d.rectangle((28,53,49,58),fill="#374334");d.rectangle((21,59,60,62),fill="#c4a46b")
  for x in (20,58):
   for y in (25,38,51):d.point((x,y),fill="#eee0a0")
 return im

def enhance(im):
 # Selective native pixel material detail; preserve every silhouette pixel and frame boundary.
 out=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
 src=im.load();dst=out.load()
 for y in range(im.height):
  for x in range(im.width):
   p=src[x,y]
   if p[3]<240:continue
   l=max(p[:3]);lo=min(p[:3])
   if l<58 or l-lo<8:continue # keep ink, eyes, metallic edges intact
   # Subpixel edge lights only at exposed top-left surfaces, never a bevel on every pixel.
   above=src[x,y-1] if y else (0,0,0,0)
   left=src[x-1,y] if x else (0,0,0,0)
   below=src[x,y+1] if y+1<im.height else (0,0,0,0)
   if above[3]==0 or (sum(above[:3])<sum(p[:3])-75 and left==p):
    dst[x*2,y*2]=tuple(min(255,c+14) for c in p[:3])+(p[3],)
    dst[x*2+1,y*2]=tuple(min(255,c+9) for c in p[:3])+(p[3],)
   if below[3]==0:dst[x*2+1,y*2+1]=tuple(max(0,c-12) for c in p[:3])+(p[3],)
 return out

def slime_sheet(hue):
 colors={"green":("#274f49","#4b8d63","#84bd7b","#b5d891"),"blue":("#294b65","#4687b0","#7ab9ce","#c6e1dc"),"red":("#663e4c","#ad5c61","#d18a70","#ead39b")}[hue]
 sheet=Image.new("RGBA",(128,32))
 for f in range(4):
  im=Image.new("RGBA",(32,32));d=ImageDraw.Draw(im);up=f%2;angry=f>=2
  d.polygon([(3,26),(2,22),(4,15-up),(9,9-up),(15,6-up),(22,8-up),(27,14-up),(30,23),(28,28),(22,30),(8,29)],fill=colors[0])
  d.polygon([(4,24),(4,18),(9,11-up),(16,8-up),(23,11-up),(27,18),(28,25),(24,28),(9,27)],fill=colors[1])
  d.polygon([(7,17),(10,12-up),(16,10-up),(22,12-up),(24,17),(22,20),(12,19)],fill=colors[2])
  d.line((10,12-up,14,10-up,18,10-up),fill=colors[3],width=2);d.rectangle((9,14-up,11,16-up),fill="#e4e8c1")
  d.line((8,26,14,27,23,27),fill=colors[2])
  for x in (13,22):
   d.rectangle((x,18,x+2,21),fill="#263b3e");d.point((x,18),fill="#e9dfb3")
   if angry:d.line((x-1,16,x+3,18),fill=colors[0],width=2)
  d.line((16,23,19,23),fill=colors[0])
  sheet.paste(im,(f*32,0))
 return sheet

def sheets():
 # Read the committed legacy atlas, never regenerate gameplay maps or sound.
 names=re.findall(r'"([^"]+)"',(ROOT/'scripts/data/tiles.gd').read_text(encoding='utf8').split('const NAMES:')[1].split('const SOLID:')[0])
 old=Image.open(ROOT/'assets/tiles.png').convert('RGBA')
 landscape=Image.new('RGBA',(len(names)*32,8*32))
 stone={"stone","cave_floor","cave_wall","cave_crystal","stalagmite","ruin_floor","ruin_wall","ruin_pillar","ruin_cracked","temple_floor","temple_wall","temple_rune","void_floor","void_wall","void_crystal","rune_pad","arena_wall","arena_tribune","sandstone","ce_cliff","ad_wetstone","ad_seawall","wood_floor","wood_wall","counter","shelf","crate","bridge","ce_boardwalk"}
 stone-= {"shelf","counter","ruin_pillar","stalagmite","ruin_cracked","rune_pad","temple_rune","arena_tribune"}
 for v in range(8):
  for i,n in enumerate(names):
   im=terrain(n,v)
   if n in ("tree","pine","willow","dead_tree"):
    im=tree(n,v)
    if n!="dead_tree":
     im=terrain("snow" if n=="pine" else "marsh_grass" if n=="willow" else "grass",v)
     d=ImageDraw.Draw(im);d.ellipse((5,22,30,31),fill="#4d724b" if n!="pine" else "#a4bec4");d.polygon([(13,13),(19,13),(20,27),(24,30),(10,30),(14,26)],fill="#554d38");d.line((14,15,15,27),fill="#a18353",width=2);d.line((18,17,19,28),fill="#3d4535")
   elif n in ("rock","bush"):im=nature_prop(n,v)
   elif n in ("roof","house_wall","house_window","door"):im=architecture(n,v)
   elif n in stone:im=masonry(n,v)
   if im is None:
    legacy=old.crop((i*16,0,i*16+16,16))
    remap={"#5ca84a":"#6e9c61","#468f3c":"#628f56","#7cc65a":"#81aa68","#e4edf7":"#c7d9dc","#c3d4e8":"#b7cdd4","#fbfdff":"#e1e8df","#3c82d6":"#397f91","#8cc4f7":"#6fb3b9","#2f6cb8":"#346e82","#ecdaa4":"#c8c29b","#d6bf80":"#b79e76","#f8edc6":"#e1cda0","#ecd193":"#d5bd88","#d4ac66":"#bda778","#f9e7b8":"#e7d2a0"}
    remap.update({"#5a6b34":"#668954","#48562a":"#536f48","#75854a":"#7c975d","#3d4f38":"#4a7468","#2e3d2c":"#3c615b","#57704c":"#578171","#67b34e":"#67945a","#4a8a3a":"#527f50","#9ad67e":"#91b875"})
    rgb=lambda h:tuple(bytes.fromhex(h[1:]))+(255,)
    colors={rgb(a):rgb(b) for a,b in remap.items()}
    legacy.putdata([colors.get(legacy.getpixel((x,y)),legacy.getpixel((x,y))) for y in range(16) for x in range(16)])
    im=enhance(legacy)
   landscape.paste(im,(i*32,v*32))
 out={"pixel_landscape":landscape}
 crowns=Image.new("RGBA",(48*8,64*3))
 for row,kind in enumerate(("tree","pine","willow")):
  for v in range(8):crowns.paste(canopy(kind,v),(v*48,row*64))
 out["pixel_canopies"]=crowns
 for role in ("wine","hive"):out["pixel_station_"+role]=station(role)
 # Four frame wave sheet; calm highlights, no full screen overlay or shader blur.
 waves=Image.new('RGBA',(128,128))
 for row,kind in enumerate(("water","ce_sea","ce_shore","bog_water")):
  for f in range(4):
   im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
   for j in range(2):
    x=(j*17+f*2)%27;y=6+j*15
    col=("#6fb3b9" if row==0 else "#5b98aa" if row==1 else "#a3cbc1" if row==2 else "#82a28c")
    d.line((x,y,min(31,x+3+f%2),y),fill=col);d.point((x+1,y+1),fill=col)
   waves.paste(im,(f*32,row*32))
 out["pixel_water"]=waves
 actors=["player","slime","slime_blue","slime_red","slime_spitter","bat","skeleton","golem","golem_void","guardian","king","mage","waterslang","moerasvors","woestijnvos","zandhaas","crystal_beetle","prism_moth","hb_moth","hb_root","ad_crab","ad_keeper","ad_wisp","rf_bird","rf_bramble","rf_listener","lw_warden","lw_stalker","lw_singer","cv_ram","cv_slinger","op_courier","op_gardener"]
 actors += [p.stem for p in sorted((ROOT/'assets').glob('npc_*.png'))]
 for name in actors:
  path=ROOT/'assets'/(name+'.png')
  if path.exists():out["pixel_"+name]=enhance(Image.open(path).convert('RGBA'))
 for name,hue in [("slime","green"),("slime_blue","blue"),("slime_red","red")]:out["pixel_"+name]=slime_sheet(hue)
 from art_characters_native import sheets as native_characters
 out.update(native_characters())
 return out
if __name__=='__main__':
 for name,im in sheets().items():
  im.save(ROOT/'assets'/(name+'.png'))
  print(name,im.size)
