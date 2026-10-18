extends RefCounted
## Original four-level mountain; generator: tools/build_mountain_layout.py.
const DATA := {
 "name": "Dampkroon",
 "music": "forest",
 "outdoor": true,
 "weather": "snow",
 "rows": [
  "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXXzzzzzzzzzzzzzzzzzzzzzzzzXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXzzzzzzzzzzzz,,zzzzzzzzzzzzXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXzzzzzzzozzzzz,,zzzzzzoz~~ozzXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXzzzzzzzzzzzzz,,zzzzzzz~~~zzzXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXzzzzzzzzzzzzz,,zzzzzzo~~zzzzXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXzz,,,,,,,,,,,,,zzzzzzzzzzzzzXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXz,,,,,,,,,,,,,zzzozzzzzzzzXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXX,,zzzzzzzzzzzzzzzzzzzzzzXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXzfzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXzzzzzzz,,zzzzzzzzzzoz~~~zozzzzzzzzzzzzXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzzzzzz,,zzzzzzzzzzz~~~~~zzzzzzzzzzfzzzXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzPzzzz,,zzzzzzzzzzoz~~~zfzzzzzzzzzzzzzXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzzzzzz,,zzzzzzfzzzzzzzzzzzzzzzzzzzzzzzXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzzzzfz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzzzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzzzzzz,,,,,,,,,,,,,,,,,,,,,,,,,,,,,zzfXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzzzzzz,,,,,,,,,,,,,,,,,,,,,,,,,,,,,zzzXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzzzzzzzzzzzzzzzzzfzzzzzzzzzzzzzzz,,zzzXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXzzzzzzzzzfzzzzzzzzzzzzzzzzzzzzzzzzz,,PzzXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz,,zzXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz,,zXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXzzzzzzzfzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz,,zzzzzzzzXXXXXXXXXXX",
  "XXXXXXXXXXzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz,,zzzzzzzzfXXXXXXXXXX",
  "XXXXXXXXXzzzzzzzzzzzzzzzzzzzoz~~~zozzzzzzzzzzzzzzzz,,zzzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXzzoz~~ozzzzzzzzzzzzz~~~~~zzzzzzzfzzzzzzzzz,,zzzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXzzz~~~zzzzzzzzzzzzzz~~~~~zzzzzzzzzzzzzzzzz,,zzzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXzzo~~zzzzzzzfzzzzzzoz~~~zzzzzzzzzzzzzzzzzz,,zzzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXzzfzzzzzzzzzzzzzzzzzzz~zzzzzzzzzzzzzzzzzzz,,zzzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz,,zfzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXzzPzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzfzzzzzz,,zzzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXzzzzzzzzz,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,zzzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXzzzzzzzzz,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,zzzzzzzPzzXXXXXXXXX",
  "XXXXXXXXXzzzzzfzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzXXXXXXXXX",
  "XXXXXXXXXXzzzzzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzfzzzzXXXXXXXXXX",
  "XXXXXXXXXXXzzzzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzfzzzzzzzzzzzzzXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXzzfzzzzzzzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzfzzzzzzXXXXX",
  "XXXXzzzzzzzzzzzzzz,,zzzzzzzzzzzziiizzzzzzzzzzzzzzzfzzzzzzzzozzzzzzzzXXXX",
  "XXXzzzzzzzzzzzzzzz,,zzzzzzzzzzziiiiizzzzfzzzzzzzzzzzzzzzzzzzzzzzzzzzzXXX",
  "XXXzzzzzzzzzozzzzz,,zzzzzzzzzziiiiiiizzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzXXX",
  "XXXzzzzzzzzzzzzzzz,,fzzzzzzzzzziiiiizzzzzzzzzzzzzoz~~~zozzzzzzzzzzzzzXXX",
  "XXXzzzzzzzfzzzzzzz,,zzzzzzzzzzzziiizzzzzzzzzzzzzzz~~~~~zzzzzzzzfzzzzzXXX",
  "XXXzzzzzzzzzzzzzzz,,,,,,,,,,,,,,,,,,,zzzzzzzzzzzo~~~~~~~zzzzzzzzzzzzzXXX",
  "XXXzzzzzzzzzzzzzzz,,,,,,,,,,,,,,,,,,,zzzzzzfzzzzzz~~~~~zzzzzzzzzzzzzzXXX",
  "XXXzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzfz,,zzzzzzzzzzzzzz~~~zzzzzzzzzzzzzzzXXX",
  "XXXzzzzzzzzzzzzzzzzzzzzfzzzzzzzzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzPzzzzXXX",
  "XXXzzzzPzzzzzfzzzzzzzzzzzzzzzzzzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzzfzzXXX",
  "XXXfzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz,,zzzzzzzzzzzzzzzzzzzfzzzzzPzzzzzzXXX",
  "XXXzzzzzzPzzzzzzzzzzzzzzzzzzzzzzzzz,,zzzzzzzzzfzzzzzzzzzzzzzzzzzzzzzzXXX",
  "XXXXzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzXXXX",
  "XXXXXzzzzzzzzzzzzzzzzzzzzzfzzzzzzzz,,zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX,,XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
 ],
 "spawns": {
  "start": [
   35,
   59
  ],
  "from_ijsdal": [
   35,
   59
  ],
  "summit": [
   36,
   7
  ]
 },
 "mountain_stairs": [
  [
   18,
   44,
   2,
   3
  ],
  [
   51,
   27,
   2,
   3
  ],
  [
   24,
   11,
   2,
   3
  ]
 ],
 "mountain_terraces": [
  {
   "name": "Bergvoet",
   "level": 0,
   "bounds": [
    3,
    47,
    66,
    15
   ]
  },
  {
   "name": "Stoomterrassen",
   "level": 1,
   "bounds": [
    9,
    30,
    54,
    14
   ]
  },
  {
   "name": "Apenbronnen",
   "level": 2,
   "bounds": [
    16,
    14,
    40,
    13
   ]
  },
  {
   "name": "Stille top",
   "level": 3,
   "bounds": [
    22,
    3,
    28,
    8
   ]
  }
 ],
 "water_hints": [
  {
   "kind": "hot_spring",
   "at": [
    52,
    53
   ],
   "bank_rocks": [
    [
     49,
     51
    ],
    [
     55,
     51
    ],
    [
     48,
     53
    ]
   ]
  },
  {
   "kind": "hot_spring",
   "at": [
    29,
    34
   ],
   "bank_rocks": [
    [
     28,
     32
    ],
    [
     34,
     32
    ],
    [
     28,
     35
    ]
   ]
  },
  {
   "kind": "hot_spring",
   "at": [
    39,
    16
   ],
   "bank_rocks": [
    [
     36,
     15
    ],
    [
     42,
     15
    ],
    [
     36,
     17
    ]
   ]
  },
  {
   "kind": "geyser",
   "at": [
    13,
    34
   ],
   "bank_rocks": [
    [
     11,
     33
    ],
    [
     15,
     33
    ],
    [
     11,
     35
    ]
   ]
  },
  {
   "kind": "geyser",
   "at": [
    45,
    6
   ],
   "bank_rocks": [
    [
     43,
     5
    ],
    [
     47,
     5
    ],
    [
     43,
     7
    ]
   ]
  }
 ],
 "objects": [
  {
   "type": "portal",
   "pos": [
    35,
    62
   ],
   "size": [
    2,
    2
   ],
   "to": "ijsdal",
   "spawn": "from_steampeak"
  },
  {
   "type": "mountain_scenery",
   "pos": [
    0,
    0
   ]
  },
  {
   "type": "sign",
   "pos": [
    32,
    58
   ],
   "lines": [
    "Dampkroon · Bergvoet",
    "Drie brede bergtrappen voeren je over vier terrassen naar de top. De warme bronnen liggen in de beschutte kommen naast het pad."
   ]
  },
  {
   "type": "sign",
   "pos": [
    55,
    38
   ],
   "lines": [
    "Dampkroon · Stoomterrassen",
    "De geisers zijn decoratief. Rust vijftien seconden aan de warmwaterbron om één hartje te herstellen. Blijven lopen onderbreekt de rust."
   ]
  },
  {
   "type": "sign",
   "pos": [
    33,
    5
   ],
   "lines": [
    "Dampkroon · Stille top",
    "Beneden bewegen de roodkopapen tussen warme rotsen en sneeuw. Er is geen haast: hetzelfde brede pad brengt je terug naar IJsdal."
   ]
  },
  {
   "type": "savepoint",
   "pos": [
    38,
    7
   ],
   "spawn": "summit"
  },
  {
   "type": "enemy",
   "kind": "trail_macaque",
   "pos": [
    47,
    54
   ],
   "patrol_radius": 64.0,
   "trail_wildlife": true
  },
  {
   "type": "enemy",
   "kind": "trail_macaque",
   "pos": [
    56,
    55
   ],
   "patrol_radius": 64.0,
   "trail_wildlife": true
  },
  {
   "type": "enemy",
   "kind": "trail_macaque",
   "pos": [
    35,
    35
   ],
   "patrol_radius": 64.0,
   "trail_wildlife": true
  },
  {
   "type": "enemy",
   "kind": "trail_macaque",
   "pos": [
    39,
    19
   ],
   "patrol_radius": 64.0,
   "trail_wildlife": true
  },
  {
   "type": "enemy",
   "kind": "trail_macaque",
   "pos": [
    43,
    20
   ],
   "patrol_radius": 64.0,
   "trail_wildlife": true
  },
  {
   "type": "sign",
   "pos": [
    33,
    60
   ],
   "lines": [
    "Zuidelijk bergpad: IJsdal",
    "De brede weg daalt terug naar het dorpsplein van IJsdal."
   ]
  }
 ]
}
