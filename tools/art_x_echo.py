"""Eigen sprites voor de Prismagrotten; vier frames per vijand."""
from PIL import ImageDraw
from artlib import blank, outline, strip


def beetle(frame):
    im = blank()
    d = ImageDraw.Draw(im)
    step = frame % 2
    for y in (6, 9, 12):
        d.line([(4, y), (1, y + step), (0, y + 2)], fill="#25506b")
        d.line([(11, y), (14, y - step), (15, y + 2)], fill="#25506b")
    d.ellipse((3, 3, 12, 13), fill="#286275", outline="#183447")
    d.ellipse((4, 4, 10, 11), fill="#398fa0")
    crystal = "#ffda79" if frame == 2 else "#6ae5eb"
    d.polygon([(7, 0), (11, 6), (8, 10), (5, 6)], fill=crystal)
    d.line([(7, 1), (7, 7)], fill="#dcffff")
    d.rectangle((5, 11, 10, 14), fill="#24445c")
    d.point((5, 12), fill="#ffedaa")
    d.point((10, 12), fill="#ffedaa")
    if frame == 3:
        d.line([(4, 1), (2, 4)], fill="#abfbff")
        d.line([(12, 1), (14, 4)], fill="#abfbff")
    return outline(im)


def moth(frame):
    im = blank()
    d = ImageDraw.Draw(im)
    y = 1 if frame % 2 else 4
    wing = "#f2c48c" if frame == 2 else "#a179d8"
    d.polygon([(7, 6), (1, y), (0, 9), (4, 12), (7, 9)], fill=wing)
    d.polygon([(8, 6), (14, y), (15, 9), (11, 12), (8, 9)], fill=wing)
    d.line([(1, y + 2), (5, 9)], fill="#e5bdff", width=1)
    d.line([(14, y + 2), (10, 9)], fill="#e5bdff", width=1)
    d.rectangle((6, 5, 9, 12), fill="#415176")
    d.polygon([(7, 3), (10, 7), (8, 11), (5, 7)], fill="#b9f6fa")
    d.line([(6, 4), (4, 1)], fill="#daaaf4")
    d.line([(9, 4), (11, 1)], fill="#daaaf4")
    d.point((7, 6), fill="white")
    return outline(im)


def sheets():
    return {"crystal_beetle": strip([beetle(i) for i in range(4)]),
            "prism_moth": strip([moth(i) for i in range(4)])}
