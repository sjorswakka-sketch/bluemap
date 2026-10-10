# Bluemap Quest

Een top-down avontuur/RPG gemaakt in **Godot 4.4**. Dit is het eerste speelbare prototype.

**Het verhaal:** de blauwe kristallen van de kaart zijn verdwenen. Praat met Oudste Bram in het dorp,
steek de brug over, versla de slijmen en vind drie kristallen.

## Starten

1. Download [Godot 4.4](https://godotengine.org/download) (de gewone versie, niet .NET).
2. Open Godot, kies **Import** en selecteer `project.godot` in deze map.
3. Druk op **F5** om te spelen.

## Besturing

| Toets | Actie |
|---|---|
| `WASD` / pijltjes | Lopen |
| `Spatie` / `J` | Zwaard zwaaien |
| `E` / `Enter` | Praten (en dialoog doorklikken) |
| `R` | Opnieuw beginnen (na game over of winst) |

## Wat zit erin

- Lopen met botsingen tegen bomen, water en stenen muren (`TileMapLayer` met physics)
- Zwaardaanval met terugslag, slijmen die je najagen en schade doen
- Drops: munten en hartjes, blauwe kristallen om te verzamelen
- NPC met dialoog (typmachine-effect) en een opdracht die van status verandert
- HUD met levens, tellers en opdrachttekst, plus game-over- en winscherm
- Alle graphics worden met code getekend, dus er zijn **geen losse plaatjes nodig**

## Mappen

```
project.godot        Instellingen, toetsen en autoload
scenes/main.tscn     Enige scene, de rest wordt vanuit main.gd opgebouwd
scripts/main.gd      De kaart (ASCII, aanpasbaar!) en het neerzetten van alles
scripts/game_state.gd  Autoload: levens, items, quest en signalen
scripts/player.gd    Speler
scripts/enemy.gd     Slijm
scripts/npc.gd       Oudste Bram + dialoogregels
scripts/pickup.gd    Munt, hartje, kristal
scripts/hud.gd       Interface en dialoogvenster
tests/smoke_test.gd  Geautomatiseerde speltest (zie hieronder)
```

## De kaart aanpassen

De kaart staat als tekst in `scripts/main.gd` (`MAP`). Elk teken is één tegel:

```
#  boom        ~  water       W  steen
.  gras        ,  zandpad
P  startplek   N  Bram        e  slijm
c  kristal     h  hartje      o  munt
```

Elke regel moet even lang zijn. Pas iets aan, druk op F5 en kijk wat er gebeurt.

## Testen

Zonder scherm, handig na elke wijziging:

```
godot --headless --path . -s tests/smoke_test.gd
```

De test speelt een hele sessie na: lopen, botsen, kristallen rapen, vechten, de opdracht afronden,
game over en herstarten. Hij eindigt met `SMOKE TEST OK` (exitcode 0) of laat zien wat fout ging.

## Ideeën voor later

- Echte pixel art: geef de `TileSet` een eigen PNG en vervang de `_draw()`-code door `Sprite2D`/`AnimatedSprite2D`
- Meer vijanden (boogschutter, baas), een inventaris, een tweede gebied
- Geluid en muziek
- Opslaan en laden
- Meerdere quests en meer NPC's
