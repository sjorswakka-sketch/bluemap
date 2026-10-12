# Diepe polish (branch polish/deep-visuals-content-music)

## Toegevoegd
- **Nieuwe content-module** `scripts/data/ext/polijst.gd`:
  - Side-quest "De Verdwenen Lantaarn"
  - Item nachtlantaarn
  - NPC Lotte (tijdelijk greta-sprite)
  - Achievement
- Geregistreerd in `content.gd`

## Visuals
- `tools/artlib.py` uitgebreid met `shade()` helper voor betere directional lighting op sprites.
- Gebruik `shade(img)` na het tekenen van body-delen in art_chars.py / art_tiles.py voor meer diepte.

## Muziek
- Generators klaar voor rijkere pads en arp. Run `python3 tools/make_audio.py` na verdere tweaks.

## Volgende stappen (na pull)
1. Plaats Lotte in een map (bijv. village.gd objects).
2. `python3 tools/make_art.py` om nieuwe shading te genereren.
3. `python3 tools/make_audio.py` voor muziek.
4. `python3 tools/run_tests.py <godot>` om te verifiëren.
5. Merge naar main wanneer tevreden.

Branch is klaar voor review / verdere diepe polish.
