"""Gedeelde hulpfuncties voor het tekenen van pixel art (gebruikt door make_art.py)."""
from PIL import Image, ImageDraw, ImageOps

T = 16


def c(hex_color, alpha=255):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


OUTLINE = c("#1a1a2e")


def blank(w=T, h=T):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), col)


def rect(img, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, col)


def hline(img, x0, x1, y, col):
    rect(img, x0, y, x1, y, col)


def vline(img, x, y0, y1, col):
    rect(img, x, y0, x, y1, col)


def fill(img, col):
    rect(img, 0, 0, img.width - 1, img.height - 1, col)


def ellipse(img, box, fill_col, edge=None):
    ImageDraw.Draw(img).ellipse(list(box), fill=fill_col, outline=edge)


def polygon(img, points, fill_col, edge=None):
    ImageDraw.Draw(img).polygon(points, fill=fill_col, outline=edge)


def line(img, p0, p1, col, width=1):
    ImageDraw.Draw(img).line([p0, p1], fill=col, width=width)


def outline(img, col=OUTLINE):
    """Zet een rand van 1 pixel om alle gevulde pixels heen."""
    out = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height and img.getpixel((nx, ny))[3] > 0:
                        out.putpixel((x, y), col)
                        break
    return out


def shade(img, light_offset=(-1, -1), highlight=None, shadow=None):
    """Eenvoudige directional shading: highlight boven-links, shadow onder-rechts."""
    if highlight is None:
        highlight = c("#ffffff", 80)
    if shadow is None:
        shadow = c("#000000", 60)
    out = img.copy()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] == 0:
                continue
            # highlight
            hx, hy = x + light_offset[0], y + light_offset[1]
            if 0 <= hx < w and 0 <= hy < h and img.getpixel((hx, hy))[3] == 0:
                put(out, x, y, _blend(img.getpixel((x, y)), highlight))
            # shadow
            sx, sy = x - light_offset[0], y - light_offset[1]
            if 0 <= sx < w and 0 <= sy < h and img.getpixel((sx, sy))[3] == 0:
                put(out, x, y, _blend(out.getpixel((x, y)), shadow))
    return out


def _blend(base, overlay):
    """Simpele alpha-blend."""
    br, bg, bb, ba = base
    or_, og, ob, oa = overlay
    a = oa / 255.0
    return (
        int(br * (1 - a) + or_ * a),
        int(bg * (1 - a) + og * a),
        int(bb * (1 - a) + ob * a),
        max(ba, oa),
    )


def from_grid(rows, palette):
    h, w = len(rows), len(rows[0])
    img = blank(w, h)
    for y, row in enumerate(rows):
        assert len(row) == w, f"rij {y} heeft lengte {len(row)}, verwacht {w}: {row}"
        for x, ch in enumerate(row):
            if ch != ".":
                put(img, x, y, palette[ch])
    return img


def strip(frames, vertical=False):
    """Plakt losse frames aan elkaar tot een spritesheet."""
    w, h = frames[0].size
    sheet = blank(w, h * len(frames)) if vertical else blank(w * len(frames), h)
    for i, f in enumerate(frames):
        sheet.paste(f, (0, i * h) if vertical else (i * w, 0))
    return sheet


def grid_sheet(rows_of_frames):
    w, h = rows_of_frames[0][0].size
    sheet = blank(w * len(rows_of_frames[0]), h * len(rows_of_frames))
    for y, row in enumerate(rows_of_frames):
        for x, f in enumerate(row):
            sheet.paste(f, (x * w, y * h))
    return sheet


def centered(img, size=T):
    out = blank(size, size)
    out.paste(img, ((size - img.width) // 2, (size - img.height) // 2), img)
    return out


def recolor(img, mapping):
    """Vervangt kleuren in een plaatje (voor varianten van dezelfde tekening)."""
    out = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            p = img.getpixel((x, y))
            if p in mapping:
                out.putpixel((x, y), mapping[p])
    return out
