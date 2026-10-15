"""Alle tegels (16x16). De volgorde komt uit scripts/data/tiles.gd (NAMES)."""
import glob
import importlib
import os
import random
import re
import sys

from artlib import *  # noqa: F401,F403

GRASS, GRASS_D, GRASS_L = c("#5ca84a"), c("#468f3c"), c("#7cc65a")


def fill_noise(img, base, dark, light, seed, amount=14):
    fill(img, base)
    rnd = random.Random(seed)
    for _ in range(amount):
        put(img, rnd.randrange(16), rnd.randrange(16), light if rnd.random() < 0.5 else dark)


def grass_tile(variant=0):
    img = blank()
    fill(img, GRASS)
    rnd = random.Random(100 + variant)
    for _ in range(8):
        put(img, rnd.randrange(16), rnd.randrange(16), GRASS_L if rnd.random() < 0.5 else GRASS_D)
    for _ in range(5 if variant == 2 else 3):
        x, y = rnd.randrange(2, 14), rnd.randrange(3, 15)
        put(img, x, y, GRASS_D)
        put(img, x - 1, y - 1, GRASS_D)
        put(img, x + 1, y - 1, GRASS_D)
    if variant == 1:  # bloemetjes
        for petal, (x, y) in zip(["#ffffff", "#ff8fb0", "#ffffff"], [(3, 4), (11, 9), (6, 13)]):
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                put(img, x + dx, y + dy, c(petal))
            put(img, x, y, c("#ffd83a"))
    return img


def tree_tile():
    img = grass_tile(0)
    rect(img, 6, 11, 9, 15, c("#6b4423"))
    rect(img, 9, 11, 9, 15, c("#4a2c12"))
    ellipse(img, (1, 0, 14, 12), c("#2f7d3f"), c("#1b4d2a"))
    for x, y in [(4, 2), (5, 2), (3, 3), (4, 3), (6, 1), (7, 1), (4, 4)]:
        put(img, x, y, c("#52b05e"))
    for x, y in [(10, 8), (11, 7), (9, 9), (8, 10), (11, 9), (6, 9), (7, 10)]:
        put(img, x, y, c("#256a35"))
    for x, y in [(8, 4), (9, 3)]:
        put(img, x, y, c("#3d9a4d"))
    return img


def water_tile():
    img = blank()
    fill(img, c("#3c82d6"))
    for x, y in [(2, 3), (3, 3), (4, 3), (9, 7), (10, 7), (11, 7), (4, 12), (5, 12), (6, 12)]:
        put(img, x, y, c("#8cc4f7"))
    for x, y in [(8, 3), (9, 3), (1, 8), (2, 8), (11, 13), (12, 13)]:
        put(img, x, y, c("#2f6cb8"))
    return img


def path_tile():
    img = blank()
    fill(img, c("#d9bb8a"))
    rnd = random.Random(7)
    for _ in range(14):
        put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice([c("#c19e6c"), c("#ead0a5")]))
    for x, y in [(3, 4), (4, 4), (11, 10), (12, 10), (12, 11), (6, 13)]:
        put(img, x, y, c("#a98556"))
    return img


def stone_tile():
    img = blank()
    fill(img, c("#8f95aa"))
    mortar, light = c("#5d637a"), c("#aab0c4")
    for row, y in enumerate((0, 4, 8, 12)):
        hline(img, 0, 15, y + 3, mortar)
        hline(img, 0, 15, y, light)
        for x in ((3, 11) if row % 2 else (7, 15)):
            vline(img, x, y, y + 2, mortar)
    return img


def bridge_tile():
    img = water_tile()
    for i, y in enumerate((1, 5, 9, 13)):
        col = c("#b07a40") if i % 2 == 0 else c("#9a6a36")
        rect(img, 0, y, 15, y + 2, col)
        hline(img, 0, 15, y, c("#c99a60"))
        hline(img, 0, 15, y + 3, c("#5a3a1c")) if y + 3 < 16 else None
    for y in (2, 6, 10, 14):
        put(img, 1, y, c("#3a2410"))
        put(img, 14, y, c("#3a2410"))
    return img


def fence_tile():
    img = grass_tile(0)
    for x in (1, 7, 13):
        rect(img, x, 3, x + 1, 14, c("#8a5a2c"))
        vline(img, x, 3, 14, c("#b07a40"))
        rect(img, x, 2, x + 1, 2, c("#6a4220"))
    for y in (5, 10):
        hline(img, 0, 15, y, c("#a86f36"))
        hline(img, 0, 15, y + 1, c("#6a4220"))
    return img


def roof_tile():
    img = blank()
    fill(img, c("#b5493a"))
    for row, y in enumerate((0, 4, 8, 12)):
        for x in range(-4 + (4 if row % 2 else 0), 16, 8):
            ellipse(img, (x, y - 1, x + 7, y + 5), c("#c9604a"), c("#8a2f26"))
    hline(img, 0, 15, 15, c("#7a281f"))
    return img


def house_wall_tile():
    img = blank()
    fill_noise(img, c("#e8dcc0"), c("#d6c9a8"), c("#f4ecd6"), 3, 10)
    rect(img, 0, 0, 1, 15, c("#7a5230"))
    rect(img, 14, 0, 15, 15, c("#7a5230"))
    hline(img, 0, 15, 0, c("#5a3a1c"))
    hline(img, 0, 15, 15, c("#5a3a1c"))
    return img


def house_window_tile():
    img = house_wall_tile()
    rect(img, 3, 3, 12, 12, c("#5a3a1c"))
    rect(img, 4, 4, 11, 11, c("#8ac4f0"))
    rect(img, 4, 4, 6, 6, c("#cfeaff"))
    hline(img, 4, 11, 7, c("#5a3a1c"))
    vline(img, 7, 4, 11, c("#5a3a1c"))
    hline(img, 2, 13, 13, c("#8a5a2c"))
    return img


def door_tile():
    img = house_wall_tile()
    rect(img, 3, 1, 12, 15, c("#4a2c12"))
    rect(img, 4, 2, 11, 15, c("#7a4a24"))
    for x in (6, 8, 10):
        vline(img, x, 2, 15, c("#5a3a1c"))
    rect(img, 4, 2, 11, 3, c("#9a6334"))
    put(img, 10, 9, c("#ffd83a"))
    put(img, 10, 10, c("#c98f12"))
    rect(img, 2, 14, 13, 15, c("#8f95aa"))
    hline(img, 2, 13, 14, c("#aab0c4"))
    return img


def cave_mouth_tile():
    img = cave_wall_tile()
    polygon(img, [(1, 15), (1, 8), (4, 3), (8, 1), (12, 3), (15, 8), (15, 15)], c("#0d0a14"))
    for x, y in [(2, 9), (3, 6), (5, 4), (8, 2), (11, 4), (13, 6), (14, 9)]:
        put(img, x, y, c("#6a5a64"))
    rect(img, 4, 12, 11, 15, c("#17121f"))
    return img


def ruin_stairs_tile():
    img = ruin_floor_tile()
    for i, y in enumerate(range(2, 15, 3)):
        shade = 175 - i * 28
        rect(img, 2, y, 13, y + 2, c("#%02x%02x%02x" % (shade, shade, shade - 8)))
        hline(img, 2, 13, y, c("#c8c8bc") if i < 2 else c("#7a7a72"))
    rect(img, 2, 13, 13, 15, c("#101018"))
    return img


def temple_door_tile():
    img = temple_wall_tile()
    rect(img, 2, 1, 13, 15, c("#e0b84a"))
    rect(img, 3, 2, 12, 15, c("#2f5fb0"))
    rect(img, 3, 2, 7, 15, c("#3b74cf"))
    vline(img, 7, 2, 15, c("#e0b84a"))
    vline(img, 8, 2, 15, c("#e0b84a"))
    polygon(img, [(7, 5), (9, 8), (7, 11), (5, 8)], c("#9ee8ff"))
    put(img, 7, 8, c("#ffffff"))
    return img


def rock_tile():
    img = grass_tile(0)
    ellipse(img, (2, 4, 13, 14), c("#8a8e9c"), c("#4a4e5c"))
    for x, y in [(4, 6), (5, 6), (4, 7)]:
        put(img, x, y, c("#b8bcc8"))
    for x, y in [(10, 11), (11, 10), (9, 12)]:
        put(img, x, y, c("#666a78"))
    return img


def bush_tile():
    img = grass_tile(0)
    ellipse(img, (1, 4, 14, 14), c("#2f8a42"), c("#1b5230"))
    for x, y in [(4, 6), (5, 6), (7, 5), (9, 7), (6, 9)]:
        put(img, x, y, c("#52b860"))
    for x, y in [(5, 8), (10, 9), (8, 11)]:
        put(img, x, y, c("#e8334a"))
    return img


def dead_tree_tile():
    img = grass_tile(0)
    rect(img, 7, 6, 8, 15, c("#5a4030"))
    vline(img, 8, 6, 15, c("#3a281c"))
    for p0, p1 in [((7, 8), (2, 3)), ((8, 7), (13, 2)), ((7, 10), (3, 9)), ((8, 9), (13, 8)), ((8, 5), (8, 1))]:
        line(img, p0, p1, c("#5a4030"))
    return img


def well_tile():
    img = grass_tile(0)
    ellipse(img, (1, 3, 14, 14), c("#8f95aa"), c("#4a4e5c"))
    ellipse(img, (4, 6, 11, 11), c("#2a64b8"), c("#1a3a70"))
    for x, y in [(5, 7), (6, 7)]:
        put(img, x, y, c("#8cc4f7"))
    for x in (2, 13):
        put(img, x, 8, c("#aab0c4"))
    return img


def crate_tile():
    img = wood_floor_tile()
    rect(img, 2, 3, 13, 14, c("#a8743c"))
    for p0, p1 in [((2, 3), (13, 14)), ((13, 3), (2, 14))]:
        line(img, p0, p1, c("#7a4e24"))
    rect(img, 2, 3, 13, 4, c("#c99a60"))
    hline(img, 2, 13, 14, c("#5a3a1c"))
    vline(img, 2, 3, 14, c("#5a3a1c"))
    vline(img, 13, 3, 14, c("#5a3a1c"))
    return img


def cave_floor_tile():
    img = blank()
    fill_noise(img, c("#4a4048"), c("#3a3238"), c("#5c505a"), 21, 16)
    for x, y in [(3, 3), (4, 3), (11, 9), (12, 9), (6, 13), (13, 4)]:
        put(img, x, y, c("#6a5e68"))
    return img


def cave_wall_tile():
    img = blank()
    fill(img, c("#2c262e"))
    rnd = random.Random(5)
    for _ in range(5):
        x, y = rnd.randrange(1, 12), rnd.randrange(1, 12)
        rect(img, x, y, x + 3, y + 2, c("#3d3540"))
        hline(img, x, x + 3, y, c("#51474f"))
    hline(img, 0, 15, 15, c("#1c181f"))
    return img


def cave_crystal_tile():
    img = cave_wall_tile()
    for pts in ([(4, 14), (6, 5), (9, 14)], [(8, 14), (11, 3), (14, 14)], [(1, 12), (2, 7), (4, 12)]):
        polygon(img, pts, c("#4cc3ff"), c("#1f88d6"))
        put(img, pts[1][0], pts[1][1] + 2, c("#d8f6ff"))
    return img


def stalagmite_tile():
    img = cave_floor_tile()
    polygon(img, [(3, 14), (8, 1), (13, 14)], c("#7a6e76"), c("#3a3238"))
    polygon(img, [(8, 1), (13, 14), (9, 14)], c("#5a4e58"))
    put(img, 7, 5, c("#a89ca6"))
    return img


def ruin_floor_tile():
    img = blank()
    fill_noise(img, c("#9a9a8e"), c("#868678"), c("#aeaea0"), 9, 12)
    hline(img, 0, 15, 7, c("#6c6c60"))
    vline(img, 7, 0, 7, c("#6c6c60"))
    vline(img, 12, 8, 15, c("#6c6c60"))
    put(img, 2, 12, c("#5f8a4a"))
    put(img, 3, 12, c("#5f8a4a"))
    put(img, 13, 3, c("#5f8a4a"))
    return img


def ruin_wall_tile():
    img = blank()
    fill(img, c("#7d7f72"))
    mortar = c("#55574c")
    for row, y in enumerate((0, 5, 10)):
        hline(img, 0, 15, y + 4, mortar)
        hline(img, 0, 15, y, c("#98998b"))
        for x in ((4, 12) if row % 2 else (8, 15)):
            vline(img, x, y, y + 3, mortar)
    for x, y in [(1, 2), (2, 2), (2, 3), (10, 7), (11, 7), (6, 12), (7, 12), (7, 13)]:
        put(img, x, y, c("#4f7a45"))
    hline(img, 0, 15, 15, c("#3d3e36"))
    return img


def ruin_pillar_tile():
    img = ruin_floor_tile()
    ellipse(img, (3, 9, 13, 15), c("#5a5a50"))
    rect(img, 4, 2, 11, 12, c("#b4b4a6"))
    rect(img, 4, 2, 6, 12, c("#d0d0c2"))
    rect(img, 10, 2, 11, 12, c("#8a8a7c"))
    rect(img, 3, 1, 12, 3, c("#c4c4b6"))
    rect(img, 3, 11, 12, 13, c("#a4a496"))
    hline(img, 3, 12, 1, c("#e0e0d2"))
    hline(img, 3, 12, 13, c("#6a6a5e"))
    return img


def ruin_cracked_tile():
    img = ruin_floor_tile()
    for p0, p1 in [((2, 1), (6, 7)), ((6, 7), (5, 13)), ((6, 7), (12, 10)), ((12, 10), (14, 15))]:
        line(img, p0, p1, c("#3d3d34"))
    return img


def temple_floor_tile():
    img = blank()
    fill_noise(img, c("#8aa8d4"), c("#7a98c4"), c("#9ab8e0"), 31, 8)
    hline(img, 0, 15, 0, c("#6a88b8"))
    vline(img, 0, 0, 15, c("#6a88b8"))
    for x, y in [(4, 5), (5, 6), (6, 7), (10, 11), (11, 12)]:
        put(img, x, y, c("#7a9acc"))
    return img


def temple_wall_tile():
    img = blank()
    fill(img, c("#6a98d4"))
    for row, y in enumerate((0, 8)):
        hline(img, 0, 15, y + 7, c("#3f68a8"))
        hline(img, 0, 15, y, c("#9cc4f4"))
        for x in ((4, 12) if row % 2 else (8, 15)):
            vline(img, x, y, y + 6, c("#3f68a8"))
    for x, y in [(2, 3), (10, 11), (13, 4), (5, 13)]:
        put(img, x, y, c("#d8ecff"))
    hline(img, 0, 15, 15, c("#2c4c80"))
    return img


def temple_rune_tile():
    img = temple_floor_tile()
    ellipse(img, (2, 2, 13, 13), None, c("#4cc3ff"))
    ellipse(img, (5, 5, 10, 10), None, c("#9ee8ff"))
    for p in [(8, 1), (8, 14), (1, 8), (14, 8)]:
        put(img, p[0], p[1], c("#4cc3ff"))
    put(img, 7, 7, c("#ffffff"))
    put(img, 8, 8, c("#ffffff"))
    return img


def carpet_tile():
    img = blank()
    fill(img, c("#a83a4a"))
    for y in range(0, 16, 4):
        for x in range(0, 16, 4):
            put(img, x + 1, y + 1, c("#c85a68"))
            put(img, x + 3, y + 3, c("#8a2a38"))
    hline(img, 0, 15, 0, c("#e0b84a"))
    hline(img, 0, 15, 15, c("#e0b84a"))
    return img


def wood_floor_tile():
    img = blank()
    fill(img, c("#b88a55"))
    for y in (3, 7, 11, 15):
        hline(img, 0, 15, y, c("#8f6638"))
    for x, y in [(4, 0), (11, 4), (6, 8), (13, 12), (2, 12)]:
        vline(img, x, y, y + 2, c("#8f6638"))
    for x, y in [(2, 1), (9, 5), (5, 9), (12, 13)]:
        put(img, x, y, c("#cfa06a"))
    return img


def wood_wall_tile():
    img = blank()
    fill(img, c("#6a4528"))
    for x in (0, 4, 8, 12):
        vline(img, x, 0, 15, c("#4a2e18"))
        vline(img, x + 1, 0, 15, c("#7e5434"))
    hline(img, 0, 15, 15, c("#3a2410"))
    return img


def counter_tile():
    img = wood_floor_tile()
    rect(img, 0, 3, 15, 13, c("#c89860"))
    rect(img, 0, 3, 15, 5, c("#e0b878"))
    rect(img, 0, 11, 15, 13, c("#8a5a2c"))
    hline(img, 0, 15, 14, c("#4a2e18"))
    hline(img, 0, 15, 3, c("#f0d0a0"))
    return img


def shelf_tile():
    img = wood_wall_tile()
    for y in (4, 10):
        rect(img, 1, y + 3, 14, y + 4, c("#b07a40"))
    colors = ["#e8334a", "#4cc3ff", "#5fd36b", "#ffd83a", "#b48cff"]
    for i, x in enumerate((2, 5, 8, 11)):
        rect(img, x, 1, x + 1, 3, c(colors[i % 5]))
        rect(img, x, 7, x + 1, 9, c(colors[(i + 2) % 5]))
    rect(img, 3, 13, 12, 14, c("#c8a060"))
    return img


def bed_tile():
    img = wood_floor_tile()
    rect(img, 1, 1, 14, 14, c("#7a4e28"))
    rect(img, 2, 2, 13, 13, c("#e8e8f0"))
    rect(img, 3, 3, 12, 6, c("#ffffff"))
    rect(img, 2, 7, 13, 13, c("#4a78c8"))
    hline(img, 2, 13, 7, c("#8ab0f0"))
    hline(img, 2, 13, 13, c("#2f5aa0"))
    return img


def mat_tile():
    img = wood_floor_tile()
    rect(img, 3, 4, 12, 11, c("#7a3a2a"))
    for y in (5, 8, 10):
        hline(img, 3, 12, y, c("#a8584a"))
    return img


# --- arena (zandkleurige steen, zie scripts/data/tiles.gd) -------------------------------------------

ARENA_STONE, ARENA_LIGHT, ARENA_MORTAR = c("#c4ab85"), c("#dcc8a2"), c("#8c7656")


def arena_sand_tile():
    img = blank()
    fill_noise(img, c("#dcb97a"), c("#c8a262"), c("#ecd2a0"), 41, 16)
    for x, y in [(2, 5), (3, 5), (4, 5), (9, 11), (10, 11), (11, 11), (12, 11)]:  # geharkte strepen
        put(img, x, y, c("#c19a5a"))
    for x, y in [(6, 2), (13, 7), (3, 13)]:  # steentjes
        put(img, x, y, c("#a58552"))
        put(img, x + 1, y, c("#b8965f"))
    return img


def arena_wall_tile():
    img = blank()
    fill(img, ARENA_STONE)
    shade = c("#a48d68")
    for row, y in enumerate((0, 5, 10)):
        hline(img, 0, 15, y + 4, ARENA_MORTAR)
        hline(img, 0, 15, y, ARENA_LIGHT)
        for x in ((4, 12) if row % 2 else (8, 15)):
            vline(img, x, y, y + 3, ARENA_MORTAR)
        for x in ((3, 11) if row % 2 else (7, 14)):
            vline(img, x, y + 1, y + 3, shade)
    for x, y in [(2, 2), (10, 7), (5, 12), (13, 13)]:
        put(img, x, y, c("#b39c76"))
    hline(img, 0, 15, 15, c("#5e4b34"))
    return img


def arena_tribune_tile():
    img = blank()
    fill(img, c("#9c8662"))
    for y0 in (0, 8):  # twee banken per tegel: zitvlak en rug
        rect(img, 0, y0, 15, y0 + 3, c("#cdb78f"))
        hline(img, 0, 15, y0, c("#e0cfab"))
        rect(img, 0, y0 + 4, 15, y0 + 7, c("#8a7452"))
        hline(img, 0, 15, y0 + 7, c("#6a5640"))
        vline(img, 7, y0 + 1, y0 + 3, c("#a89472"))
    for x, y in [(3, 5), (11, 13), (13, 5)]:
        put(img, x, y, c("#a08a66"))
    return img


def arena_gate_tile():
    img = arena_wall_tile()
    dark = c("#15101c")
    ellipse(img, (2, 1, 13, 11), dark)  # boog met een diepe donkere opening
    rect(img, 2, 6, 13, 15, dark)
    for x, y in [(2, 5), (3, 3), (4, 2), (5, 1), (6, 0), (9, 0), (10, 1), (11, 2), (12, 3), (13, 5)]:  # lichte stenen langs de boog
        put(img, x, y, c("#e2d0ac"))
    rect(img, 2, 14, 13, 15, c("#2a2230"))
    iron, iron_l, iron_d = c("#5a5f6e"), c("#9aa0b4"), c("#2f3340")
    for x in (4, 7, 10):  # het hek hangt half omhoog: puntjes onderaan
        vline(img, x, 2, 12, iron)
        vline(img, x + 1, 2, 12, iron_d)
        put(img, x, 2, iron_l)
        put(img, x, 13, iron_l)
        put(img, x, 14, iron)
    hline(img, 3, 12, 5, iron_d)
    hline(img, 3, 12, 9, iron_d)
    hline(img, 3, 12, 6, iron)
    hline(img, 3, 12, 10, iron)
    return img


def arena_arch_tile():
    img = arena_wall_tile()
    rect(img, 0, 0, 1, 15, c("#a48d68"))  # zijpilaren
    rect(img, 14, 0, 15, 15, c("#a48d68"))
    vline(img, 1, 0, 15, ARENA_MORTAR)
    vline(img, 14, 0, 15, ARENA_MORTAR)
    rect(img, 2, 0, 13, 2, ARENA_LIGHT)  # latei met sluitsteen
    hline(img, 2, 13, 2, ARENA_MORTAR)
    rect(img, 7, 0, 8, 2, c("#e8d8b6"))
    put(img, 7, 1, c("#e0b84a"))
    put(img, 8, 1, c("#c98f12"))
    for y, shade in [(3, "#1c1622"), (4, "#1c1622"), (5, "#1c1622"), (6, "#241c2a"), (7, "#241c2a"), (8, "#241c2a"),
                     (9, "#2e2434"), (10, "#2e2434"), (11, "#2e2434"), (12, "#3a2f3c"), (13, "#8a6f48"), (14, "#a88a58"),
                     (15, "#b89a64")]:
        hline(img, 2, 13, y, c(shade))
    for x, y in [(2, 3), (13, 3)]:  # afgeronde hoeken
        put(img, x, y, ARENA_STONE)
    return img


PAINTERS = {
    "grass": lambda: grass_tile(0), "tree": tree_tile, "water": water_tile, "path": path_tile,
    "stone": stone_tile, "grass_flowers": lambda: grass_tile(1), "grass_tufts": lambda: grass_tile(2),
    "bridge": bridge_tile, "fence": fence_tile, "roof": roof_tile, "house_wall": house_wall_tile,
    "house_window": house_window_tile, "door": door_tile, "cave_mouth": cave_mouth_tile,
    "ruin_stairs": ruin_stairs_tile, "temple_door": temple_door_tile, "rock": rock_tile, "bush": bush_tile,
    "dead_tree": dead_tree_tile, "well": well_tile, "crate": crate_tile, "cave_floor": cave_floor_tile,
    "cave_wall": cave_wall_tile, "cave_crystal": cave_crystal_tile, "stalagmite": stalagmite_tile,
    "ruin_floor": ruin_floor_tile, "ruin_wall": ruin_wall_tile, "ruin_pillar": ruin_pillar_tile,
    "ruin_cracked": ruin_cracked_tile, "temple_floor": temple_floor_tile, "temple_wall": temple_wall_tile,
    "temple_rune": temple_rune_tile, "carpet": carpet_tile, "wood_floor": wood_floor_tile,
    "wood_wall": wood_wall_tile, "counter": counter_tile, "shelf": shelf_tile, "bed": bed_tile, "mat": mat_tile,
    # arena
    "arena_sand": arena_sand_tile, "arena_wall": arena_wall_tile, "arena_tribune": arena_tribune_tile,
    "arena_gate": arena_gate_tile, "arena_arch": arena_arch_tile,
}


# Uitbreidingen met eigen tegels: tools/art_x_<naam>.py met een functie tile_painters(art_tiles) -> {tegelnaam: tekening}.
for _path in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_x_*.py"))):
    _extension = importlib.import_module(os.path.basename(_path)[:-3])
    if hasattr(_extension, "tile_painters"):
        PAINTERS.update(_extension.tile_painters(sys.modules[__name__]))


# --- De Diepte (spoor diepte): paars en diepblauw, met gloeiende kristallen -----------------------------------

VOID_BASE, VOID_DARK, VOID_LIGHT = c("#2b2754"), c("#211e47"), c("#3a3470")
VOID_STAR = c("#9a8cf0")
CRYSTAL_MAIN, CRYSTAL_DARK, CRYSTAL_LIGHT, CRYSTAL_EDGE = c("#b46bff"), c("#7f3fd6"), c("#ecd4ff"), c("#2a0f5e")


def void_floor_tile():
    img = blank()
    fill_noise(img, VOID_BASE, VOID_DARK, VOID_LIGHT, 41, 12)
    hline(img, 0, 15, 0, c("#3f3880"))
    vline(img, 0, 0, 15, c("#3f3880"))
    hline(img, 1, 15, 15, c("#1a1738"))
    vline(img, 15, 1, 15, c("#1a1738"))
    for x, y in [(4, 5), (5, 6), (11, 10), (12, 11)]:
        put(img, x, y, c("#342e6a"))
    for x, y in [(10, 4), (3, 12)]:  # een paar sterrenstofjes
        put(img, x, y, VOID_STAR)
    return img


def void_wall_tile():
    img = blank()
    fill(img, c("#1c1840"))
    for row, y in enumerate((0, 8)):
        hline(img, 0, 15, y + 7, c("#0d0a22"))
        hline(img, 0, 15, y, c("#40388a"))
        for x in ((4, 12) if row % 2 else (8, 15)):
            vline(img, x, y, y + 6, c("#0d0a22"))
    for x, y in [(2, 3), (10, 11), (13, 4), (5, 13)]:
        put(img, x, y, c("#6a5cc8"))
    for x, y in [(3, 5), (11, 12)]:
        put(img, x, y, c("#2c2562"))
    hline(img, 0, 15, 15, c("#090719"))
    return img


def void_crystal_tile():
    img = void_floor_tile()
    ellipse(img, (2, 11, 13, 15), c("#1a1738"))  # schaduw op de grond
    for pts in ([(2, 14), (4, 6), (7, 14)], [(6, 14), (9, 1), (13, 14)], [(11, 14), (13, 7), (15, 13)]):
        polygon(img, pts, CRYSTAL_MAIN, CRYSTAL_EDGE)
    polygon(img, [(9, 1), (13, 14), (9, 14)], CRYSTAL_DARK)
    polygon(img, [(4, 6), (7, 14), (4, 14)], CRYSTAL_DARK)
    for x, y in [(9, 4), (9, 5), (8, 6), (4, 8), (13, 9)]:
        put(img, x, y, CRYSTAL_LIGHT)
    put(img, 8, 2, c("#ffffff"))
    for x, y in [(1, 8), (14, 4), (0, 12)]:  # glinsteringen in de lucht
        put(img, x, y, c("#a8e8ff"))
    return img


def rune_pad_tile():
    img = void_floor_tile()
    ellipse(img, (2, 2, 13, 13), None, c("#6a58d8"))
    ellipse(img, (3, 3, 12, 12), None, c("#2e2868"))
    # een ster in de cirkel
    star = [(8, 3), (9, 7), (13, 8), (9, 9), (8, 13), (7, 9), (3, 8), (7, 7)]
    polygon(img, star, c("#8c7cf0"))
    polygon(img, [(8, 5), (9, 7), (11, 8), (9, 9), (8, 11), (7, 9), (5, 8), (7, 7)], c("#cfc4ff"))
    put(img, 7, 7, c("#ffffff"))
    put(img, 8, 8, c("#ffffff"))
    for p in [(8, 1), (8, 14), (1, 8), (14, 8)]:
        put(img, p[0], p[1], c("#6a58d8"))
    return img


def void_stairs_tile():
    """Een trap die omlaag gaat: boven donker (diep), onder licht. Loopt van rand tot rand, zodat twee tegels naast elkaar één brede trap zijn."""
    img = blank()
    fill(img, c("#0a0820"))
    shades = ["#0e0b26", "#15113a", "#1d1850", "#292266", "#382f84", "#4a3f9e"]
    for i, y in enumerate(range(1, 16, 3)):
        tread, riser = c(shades[i]), c(shades[max(i - 1, 0)])
        rect(img, 0, y, 15, y + 1, tread)
        hline(img, 0, 15, y, c(shades[min(i + 1, 5)]))
        hline(img, 0, 15, y + 2, c("#07051a"))
    for x, y in [(3, 1), (12, 1), (7, 4)]:  # paars schijnsel uit de diepte
        put(img, x, y, c("#7a50d8"))
    return img


PAINTERS.update({
    "void_floor": void_floor_tile, "void_wall": void_wall_tile, "void_crystal": void_crystal_tile,
    "rune_pad": rune_pad_tile, "void_stairs": void_stairs_tile,
})


def tile_names(root):
    """Leest de volgorde van de tegels uit scripts/data/tiles.gd, zodat spel en plaatje gelijk blijven."""
    text = open(os.path.join(root, "scripts", "data", "tiles.gd"), encoding="utf-8").read()
    block = re.search(r"const NAMES: Array\[String\] = \[(.*?)\n\]", text, re.S).group(1)
    return re.findall(r'"([a-z_]+)"', block)


def tiles_sheet(root):
    from art_x_coast import NAMES as coast_names, tile as coast_tile
    PAINTERS.update({n: (lambda name=n: coast_tile(name)) for n in coast_names})
    from art_x_adventures import NAMES as adventure_names, tile as adventure_tile
    PAINTERS.update({n: (lambda name=n: adventure_tile(name)) for n in adventure_names})
    names = tile_names(root)
    missing = [n for n in names if n not in PAINTERS]
    assert not missing, f"geen tekening voor tegels: {missing}"
    return strip([PAINTERS[n]() for n in names])
