# Bluemap Quest

Een top-down avontuur/RPG gemaakt in **Godot 4.4**. Dit is het eerste speelbare prototype.

**Het verhaal:** de blauwe kristallen van de kaart zijn verdwenen. Praat met Oudste Bram in het dorp,
steek de brug over, versla de slijmen en vind drie kristallen.

## Starten

1. Download [Godot 4.4](https://godotengine.org/download) (de gewone versie, niet .NET).
2. Open Godot, kies **Import** en selecteer `project.godot` in deze map.
3. Druk op **F5** om te spelen.

Starten vanaf de opdrachtregel kan ook: `godot --path .` (draai de eerste keer eerst
`godot --headless --path . --import`).

## Besturing

| Toets | Actie |
|---|---|
| `WASD` / pijltjes | Lopen |
| `Spatie` / `J` | Zwaard zwaaien |
| `E` / `Enter` | Praten (en dialoog doorklikken) |
| `Esc` / `P` | Pauzemenu |
| `M` | Geluid aan/uit |
| `R` | Opnieuw beginnen (na game over of winst) |

## Wat zit erin

- Lopen met botsingen tegen bomen, water en stenen muren (`TileMapLayer` met physics)
- Zwaardaanval met terugslag, slijmen die je najagen en schade doen
- Drops: munten en hartjes, blauwe kristallen om te verzamelen
- NPC met dialoog (typmachine-effect) en een opdracht die van status verandert
- HUD met levens, tellers en opdrachttekst, plus game-over- en winscherm
- Titelscherm, pauzemenu en geluid (effecten en een muzieklus, zelf gemaakt)
- Pixel art (16x16) met loopanimatie in 4 richtingen, slijmen, tovenaar, munten, hartjes en kristallen

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
scripts/art.gd       Laadt de plaatjes uit assets/
scripts/sound.gd     Autoload: geluid en muziek
scripts/title.gd     Titelscherm
scripts/pause_menu.gd  Pauzemenu
assets/              Pixel art (PNG) en geluid (assets/audio, WAV)
tools/make_art.py    Maakt alle PNG's in assets/ (Pillow nodig)
tools/make_audio.py  Maakt alle geluiden en de muziek (numpy nodig)
export_presets.cfg   Instellingen voor de Windows-versie
.github/workflows/   Automatisch een Windows-versie bouwen
tests/smoke_test.gd  Geautomatiseerde speltest (zie hieronder)
ROADMAP.md           Plan voor de volgende stappen
```

## Eigen art gebruiken

De plaatjes in `assets/` zijn zelfgemaakt met `python3 tools/make_art.py`. Je kunt ze ook gewoon
vervangen door eigen PNG's of door een gratis pack (bijvoorbeeld [Kenney](https://kenney.nl/assets), CC0).
Houd dan wel dezelfde indeling aan, de code hoeft dan niet te veranderen:

| Bestand | Indeling (elk vakje 16x16 pixels) |
|---|---|
| `tiles.png` | 1 rij: gras, boom, water, pad, steen, gras met bloemen, gras met sprietjes |
| `player.png` | 3 kolommen (stilstaan, stap, stap) x 4 rijen (onder, boven, rechts, links) |
| `slime.png` | 4 vakjes: rustig (2 frames), boos (2 frames) |
| `npc.png` | 1 vakje |
| `coin.png` | 4 vakjes (draaiende munt) |
| `crystal.png` | 2 vakjes (gewoon, glinsterend) |
| `heart.png` | 1 vakje (hartje op de grond) |
| `ui_heart.png` | 2 vakjes van 13x12: vol en leeg (hartjes in beeld) |

## Een Windows-versie (.exe) maken

**Automatisch via GitHub (aanbevolen):** open het tabblad **Actions**, kies *Windows-versie bouwen*
en klik op **Run workflow**. Na een paar minuten staat er een zip bij de run onder *Artifacts*.
Wil je een downloadlink voor je community? Maak een tag, bijvoorbeeld `git tag v0.2.0 && git push origin v0.2.0`,
dan verschijnt de zip onder **Releases**.

**Zelf in Godot:** *Project > Exporteren*, kies **Windows Desktop** en klik op *Project exporteren*.
Godot vraagt dan eenmalig om de export-templates te downloaden (Editor > Export-templates beheren).

**Vanaf de opdrachtregel:**

```
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop" build/windows/BluemapQuest.exe
```

De .exe is zonder installatie te spelen. Hij is niet digitaal ondertekend, dus Windows kan een waarschuwing
tonen ("Meer informatie" > "Toch uitvoeren"). Dat staat ook in `distribution/LEESMIJ.txt`, dat bij de zip zit.

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

Zie [ROADMAP.md](ROADMAP.md).
