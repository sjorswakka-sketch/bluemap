"""Reproduce the hand-designed quiet village/forest transition, using our tiles."""
from pathlib import Path

WIDTH, HEIGHT = 44, 24
grid = [['#'] * WIDTH for _ in range(HEIGHT)]

def rect(x, y, w, h, char):
    for cy in range(y, y+h):
        for cx in range(x, x+w):
            grid[cy][cx] = char

# A broad meadow opens towards the village; trees close gradually towards the forest.
rect(2, 3, 23, 18, '.')
rect(25, 5, 8, 17, '.')
rect(33, 7, 9, 8, '.')
for x, y, w, h in [(5,3,5,2),(17,3,6,2),(2,18,4,3),(12,19,4,2),
                    (24,5,3,3),(27,6,4,2),(36,7,3,2),(38,13,4,2)]:
    rect(x,y,w,h,'#')
# A shallow pond is scenery off the route, not another collection activity.
rect(28,16,8,4,'~')
rect(30,15,4,1,'~')
rect(30,20,4,1,'~')
for x,y in [(5,6),(12,5),(20,6),(8,18),(19,19),(25,18),(36,16),(32,5)]:grid[y][x]='b'
for x,y in [(6,17),(21,18),(27,14),(37,13)]:grid[y][x]='o'
# A short visible bend, two tiles wide all the way. No mandatory detour around the pond.
for x in range(0,14):rect(x,13,1,2,',')
for x in range(12,21):rect(x,12,1,2,',')
for x in range(19,30):rect(x,11,1,2,',')
for x in range(28,WIDTH):rect(x,10,1,2,',')

rows='\n'.join('\t\t"'+''.join(row)+'",' for row in grid)
text='''extends RefCounted
## Quiet meadow-to-forest transition. Reproduce with tools/design_forest_edge.py.
## No encounters, residents, loot, resources or compulsory side activities.
const DATA := {
    "name": "Bosrand", "music": "forest", "outdoor": true, "weather": "random",
    "rows": [
ROWS
    ],
    "spawns": {"start":[3,13], "from_village":[3,13], "from_forest":[40,10]},
    "objects": [
        {"type":"portal", "pos":[0,13], "size":[2,2], "to":"village", "spawn":"from_forest"},
        {"type":"portal", "pos":[42,10], "size":[2,2], "to":"forest", "spawn":"from_village"},
        {"type":"sign", "pos":[3,11], "lines":["Westelijk pad: Dageraadsdorp."]},
        {"type":"sign", "pos":[40,8], "lines":["Oostelijk pad: Fluisterbos."]},
    ],
}
'''.replace('ROWS',rows)
dest=Path(__file__).resolve().parent.parent/'scripts/maps/forest_edge.gd'
dest.write_text(text,encoding='utf8')
print(dest)
