"""Vier frames per nieuwe rol. Bouwt alleen deze drie sheets."""
from pathlib import Path
from PIL import ImageDraw
from artlib import blank, outline, strip

def warden(frame):
    im=blank();d=ImageDraw.Draw(im);step=frame%2
    d.rectangle((4,6,11,12),fill='#344b68');d.rectangle((4,3,11,7),fill='#7898af')
    d.rectangle((5,5,10,6),fill='#223047');d.point((6,5),fill='#72f1ff');d.point((9,5),fill='#72f1ff')
    d.polygon([(3,7),(8,8),(7,13),(4,15),(2,12)],fill='#83bdcc',outline='#264557')
    d.line((5,8,5,12),fill='#d5faff');d.rectangle((9,12+step,11,14+step),fill='#263447')
    d.line((13,4,13,12),fill='#dceafa');d.line((11,10,15,10),fill='#dab879')
    return outline(im)
def stalker(frame):
    im=blank();d=ImageDraw.Draw(im);step=frame%2
    d.polygon([(1,7),(4,5),(10,6),(13,9),(11,12),(4,12)],fill='#697d9c')
    d.polygon([(10,5),(11,1),(13,4),(15,4),(15,9),(11,10)],fill='#9caed0')
    d.rectangle((3,11,5,13+step),fill='#445570');d.rectangle((9,11,11,14-step),fill='#445570')
    d.line((2,8,0,4),fill='#b5cde0',width=2)
    d.point((13,5),fill='#ffcc73' if frame==2 else '#65f4d1')
    return outline(im)
def singer(frame):
    im=blank();d=ImageDraw.Draw(im);s=frame%2
    d.polygon([(8,5),(3,13),(12,13)],fill='#598c72');d.ellipse((5,3,10,8),fill='#abc6ad')
    d.polygon([(3,4),(6,0),(11,1),(13,5)],fill='#315f4c');d.point((6,5),fill='#fff2ac');d.point((9,5),fill='#fff2ac')
    d.line((12,6,12,14),fill='#947d45');d.line((5,8,12,6+s),fill='#e3cd7c',width=2)
    if frame==2:d.arc((0,0,15,12),190,340,fill='#8df4a8')
    return outline(im)
def sheets():
    return {name:strip([fn(i) for i in range(4)]) for name,fn in [('lw_warden',warden),('lw_stalker',stalker),('lw_singer',singer)]}
if __name__=='__main__':
    for name,im in sheets().items():im.save(Path(__file__).resolve().parent.parent/'assets'/(name+'.png'))
