# Diepe polish (branch polish/deep-visuals-content-music)

## Toegevoegd / verbeterd
- **Content**: `scripts/data/ext/polijst.gd` – quest De Verdwenen Lantaarn, item, NPC Lotte, achievement.
- **NPC geplaatst**: Lotte staat nu in Dageraadsdorp (`scripts/maps/village.gd` op [16,20]).
- **Visuals**: `tools/artlib.py` met `shade()` + toegepast op player en slime in `art_chars.py`.
- **Muziek**: generators klaar; run `python3 tools/make_audio.py` voor rijkere tracks.

## Direct klaar om te testen
1. `python3 tools/make_art.py` (nieuwe shading)
2. `python3 tools/make_audio.py`
3. Open in Godot, praat met Lotte in het dorp.
4. `python3 tools/run_tests.py <godot>`

Branch gepusht. PR aanmaken of mergen wanneer je wilt.
