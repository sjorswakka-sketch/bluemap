extends RefCounted
## Original small workshop with reserved furniture spots and a clear exit.
const DATA := {
  "name": "Rafs havenwerkplaats",
  "music": "coast",
  "outdoor": false,
  "dark": 0.0,
  "rows": [
    "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNN",
    "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwmmmmmmmmwwwwwwwwwNN",
    "NNwwwwwwwwwmmmmmmmmwwwwwwwwwNN",
    "NNwwwwwwwwwmmmmmmmmwwwwwwwwwNN",
    "NNwwwwwwwwwmmmmmmmmwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwwwwwwwwwwwwwwwNN",
    "NNwwwwwwwwwwwwmmwwwwwwwwwwwwNN",
    "NNNNNNNNNNNNNNmmNNNNNNNNNNNNNN",
    "NNNNNNNNNNNNNNmmNNNNNNNNNNNNNN"
  ],
  "spawns": {
    "start": [
      14,
      18
    ],
    "altar": [
      23,
      17
    ]
  },
  "objects": [
    {
      "type": "portal",
      "pos": [
        14,
        21
      ],
      "size": [
        2,
        1
      ],
      "to": "harbor",
      "spawn": "from_workshop"
    },
    {
      "type": "sign",
      "pos": [
        16,
        19
      ],
      "lines": [
        "Rafs havenwerkplaats · terug naar Rietwenk Haven",
        "Gratis materiaalkist en vaste meubelplekken. Raf deelt het lijnpatroon; Greta en Lena helpen met hun bestaande werkplekken. Geen huur of onderhoud."
      ]
    },
    {
      "type": "savepoint",
      "pos": [
        23,
        15
      ],
      "spawn": "altar"
    },
    {
      "type": "cw_station",
      "role": "bench",
      "pos": [
        9,
        8
      ]
    },
    {
      "type": "cw_station",
      "role": "storage",
      "pos": [
        22,
        8
      ]
    },
    {
      "type": "cw_station",
      "role": "layout",
      "pos": [
        8,
        14
      ]
    },
    {
      "type": "cw_station",
      "role": "shelf",
      "pos": [
        7,
        5
      ]
    },
    {
      "type": "cw_station",
      "role": "lamp",
      "pos": [
        22,
        5
      ]
    },
    {
      "type": "cw_station",
      "role": "window",
      "pos": [
        10,
        2
      ]
    },
    {
      "type": "cw_station",
      "role": "window",
      "pos": [
        21,
        2
      ]
    },
    {
      "type": "cw_station",
      "role": "practice",
      "pos": [
        22,
        12
      ]
    }
  ]
}
