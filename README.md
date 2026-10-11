# Bluemap Quest

Een top-down fantasy-avontuur gemaakt in **Godot 4.4**, met pixel art, verhaal, gevechten, baasgevechten,
opslaan en een einde. Gemaakt voor de WTP-community.

**Het verhaal:** de Blauwe Kaart van Azura is gebarsten en de drie kaartkristallen zijn het land in gevlogen.
Praat met Oudste Bram in Dageraadsdorp, zoek de kristallen in het Fluisterbos, de Vergeten Ruïne en de
Echo-grot, en stop de Slijmkoning in de Kristaltempel.

## Spelen

**Windows:** download de zip van de laatste *Windows-versie bouwen* of *Release* (zie hieronder), pak hem uit en
dubbelklik op `BluemapQuest.exe`. Installeren is niet nodig.

**Vanuit Godot:**
1. Download [Godot 4.4](https://godotengine.org/download) (de gewone versie, niet .NET).
2. Open Godot, kies **Import** en selecteer `project.godot` in deze map.
3. Druk op **F5**.

## Besturing

| Toets | Controller | Actie |
|---|---|---|
| `WASD` / pijltjes | linkerstick / d-pad | Lopen |
| `Spatie` / `J` | X | Zwaard |
| `Shift` / `K` | B | Rollen (je bent even onraakbaar) |
| `E` / `Enter` | A | Praten, kisten en altaren openen, doorklikken |
| `H` | Y | Helddrank drinken |
| `I` / `Tab` | Back | Menu: voorwerpen |
| `Q` | linker schouderknop | Menu: opdrachten |
| `N` | rechter schouderknop | Menu: kaart (en snel reizen) |
| `T` | | Menu: prestaties |
| `B` | | Menu: beestenboek |
| `←` `→` | d-pad, linker en rechter schouderknop | In het menu: ander tabblad |
| `↑` `↓` | d-pad | In het menu: kiezen en bladeren (ook door lange lijsten) |
| `Esc` / `P` | Start | Pauze |
| `M` | | Geluid aan/uit |
| `F11` | | Volledig scherm |
| `R` | Start | Na game over: verder vanaf je laatste opslag |

## Wat zit erin

- **Acht gebieden:** Dageraadsdorp, drie gebouwen (smederij, winkel, herberg), het Fluisterbos,
  de Vergeten Ruïne, de Echo-grot en de Kristaltempel. In de donkere gebieden heb je licht van je eigen lamp en fakkels.
- **Verhaal:** een hoofdopdracht en drie zij-opdrachten, tien personages en gesprekken met keuzes.
- **Gevechten:** zwaard in drie niveaus (hout, ijzer, kristal), ontwijkrol, slijmen in drie kleuren, vleermuizen,
  boogschutter-skeletten, twee kristalgolems (minibazen) en de Slijmkoning met drie fases.
- **Verzamelen en upgraden:** winkel, smid die zwaarden maakt, drankjes, laarzen, hartcontainers en verborgen kisten.
- **Dag en nacht:** een dag duurt 8 minuten. 's Ochtends is het warm, 's avonds oranje en 's nachts blauw en donker. Dan branden de
  lantaarns in het dorp en gloeien de ramen. In de herberg kun je in een bed slapen (5 munten): je wordt beter en het wordt ochtend.
- **Weer:** in het dorp en het bos regent het af en toe, met zacht geluid van de regen.
- **Snel reizen:** een blauw altaar dat je gebruikt hebt is "ontdekt". Open de kaart (`N`), kies een ontdekt altaar met `↑` `↓`
  en druk op `E` om er meteen heen te reizen (niet tijdens een gesprek of een baasgevecht).
- **Prestaties en beestenboek:** ruim twintig prestaties (ook een paar geheime) die je ook in een nieuw spel houdt, en een boek
  met alle vijanden die je al verslagen hebt, met hun gegevens en een grappige beschrijving.
- **Opslaan:** automatisch bij het wisselen van gebied, en bij de blauwe altaren (die genezen je ook).
- **Extra's:** titelscherm met "Doorgaan", intro, kaartje, geluid en muziek per gebied (volumes in het pauzemenu),
  ondersteuning voor een controller, en een eindscherm met aftiteling.

## Tips voor spelers

- Rollen met `Shift` maakt je even onraakbaar. Gebruik dat tegen de baas.
- Slijmen laten slijmgel vallen. Greta de smid maakt er betere zwaarden van.
- Golems laten kristalscherven vallen, nodig voor het kristalzwaard.
- Praat met iedereen: veel mensen hebben een opdracht of een tip.

## Mappen

```
project.godot          Instellingen, toetsen en autoloads (GameState en Sound)
scenes/                title, intro, main (de wereld) en ending
scripts/core/          GameState (voortgang, opslaan, voorwaarden en acties), Sound, hulpfuncties
scripts/data/          ALLE INHOUD: items, vijanden, personages, dialoog, opdrachten, winkels, tegels, aftiteling
scripts/maps/          De kaarten (tekst!) en het register
scripts/entities/      Speler, vijand, personage, voorwerp, kist, poort, altaar, projectiel...
scripts/ui/            HUD, dialoogvenster, menu, winkel, pauze, titel, intro en einde
scripts/world.gd       Laadt kaarten en zet alles neer
assets/                Pixel art (PNG) en geluid (assets/audio, WAV)
tools/                 Scripts die plaatjes, geluid en kaarten maken en controleren
tests/                 De speltest en de baas-simulatie
export_presets.cfg     Instellingen voor de Windows-versie
.github/workflows/     Automatisch een Windows-versie bouwen
```

## Zelf aanpassen

Bijna alles wat met inhoud te maken heeft staat als leesbare tekst in `scripts/data/` en `scripts/maps/`.

- **Gesprekken:** `scripts/data/dialogue.gd`. Elk gesprek bestaat uit regels, eventueel keuzes en acties
  (een voorwerp geven, een opdracht starten...). De mogelijke voorwaarden en acties staan bovenaan `scripts/core/game_state.gd`.
- **Personages:** `scripts/data/npcs.gd` (wie zegt wat, afhankelijk van je voortgang).
- **Opdrachten:** `scripts/data/quests.gd`. Voorwerpen en zwaarden: `items.gd`. Winkels: `shops.gd`.
- **Vijanden:** `scripts/data/enemies.gd` (levens, snelheid, schade, wat ze laten vallen, en een `desc` voor het beestenboek).
- **Prestaties:** `scripts/data/achievements.gd`. Elke prestatie heeft een naam, uitleg en voorwaarden in hetzelfde formaat als
  bij gesprekken. Er zijn extra voorwaarden zoals `["kills", 50]` en `["rolls", 50]` (zie `scripts/data/ext/wereld.gd`).
- **Dag, nacht en weer:** in de kaart zet je `"outdoor": true` (de kaart volgt de klok) en `"weather": "rain"` (altijd regen) of
  `"random"` (wisselt met de klok). De kleuren van de dag staan in `scripts/core/daynight.gd`. Een lantaarn is een object
  `{"type": "wereld_lantaarn", "pos": [x, y]}`, een bed `{"type": "wereld_bed", "pos": [x, y]}`.
- **Kaarten:** `scripts/maps/*.gd`. De kaart is gewone tekst, elk teken is een tegel (zie `scripts/data/tiles.gd`).
  Personages, vijanden, kisten en poortjes staan als lijst onder `objects`. Wijzig iets en druk op F5.
  `python3 tools/gen_maps.py` maakt de kaarten opnieuw vanaf een startpunt, maar overschrijft dan je eigen wijzigingen.

### Eigen art en geluid

De plaatjes in `assets/` zijn zelf gemaakt met `python3 tools/make_art.py` en de geluiden met
`python3 tools/make_audio.py`. Je kunt ze ook gewoon vervangen door eigen bestanden of een gratis pack
(bijvoorbeeld [Kenney](https://kenney.nl/assets), CC0), zolang je dezelfde indeling aanhoudt:

| Bestand | Indeling (16x16 pixels per vakje, tenzij anders vermeld) |
|---|---|
| `tiles.png` | 1 rij, volgorde van `NAMES` in `scripts/data/tiles.gd` |
| `player.png` | 3 kolommen (stil, stap, stap) x 4 rijen (onder, boven, rechts, links) |
| `slime*.png` | 4 vakjes: rustig (2), boos (2) |
| `bat.png` | 3 vakjes: vleugels omhoog, omlaag, duikvlucht |
| `skeleton.png` | 4 kolommen (stil, stap, stap, boog) x 4 rijen (onder, boven, rechts, links) |
| `golem.png` | 32x32: rustig (2), armen omhoog, klap |
| `king.png` | 48x48: rustig (2), ineengedoken, in de lucht |
| `npc_*.png` | 2 vakjes: rustig en een beetje bewegen |
| `items.png` | iconen, nummer = `icon` in `items.gd` |
| `chest`, `sign`, `gate`, `altar`, `torch`, `coin`, `heart`, `ui_heart`, `projectiles` | zie `tools/art_items.py` |
| `wereld_ui.png` | zon, lage zon, maan, drie bekers en een altaarspeldje, zie `tools/art_x_wereld.py` |
| `wereld_lantaarn.png` | 3 vakjes van 16x32: uit, aan, aan (flikkert) |
| `audio/*.wav` | geluidseffecten; `audio/music_<gebied>.wav` zijn lussen van 25 tot 45 seconden; `wereld_regen.wav` is een lus van 6 seconden |

## Testen

Zonder scherm, handig na elke wijziging:

```
sh tools/run_tests.sh /pad/naar/godot
```

Dat draait alle tests in `tests/`. `tests/smoke_test.gd` controleert eerst alle inhoud op samenhang (elk gesprek, elke kaart, elk
voorwerp, elke opdracht) en speelt daarna de systemen na: lopen, gebieden wisselen, vechten, de baas, praten, kopen,
smeden, opslaan, menu's, titelscherm, intro en einde. `tests/playthrough_test.gd` speelt het hele spel uit met de echte
kaarten: van Bram tot en met het einde. Alles eindigt met `ALLE TESTS GESLAAGD`, en bij een scriptfout stopt het
met een foutmelding. `tests/wereld_test.gd` controleert dag en nacht, weer, slapen, snel reizen, prestaties, het beestenboek en het menu.

Meer gereedschap:

- `tests/boss_sim.gd`: een bot speelt het baasgevecht steeds opnieuw met verschillende zwaarden. Handig om de balans te meten.
- `python3 tools/check_audio.py`: controleert geluiden en muzieklussen op clipping, tikjes en de juiste noten.
- `python3 tools/gen_maps.py`: controleert tijdens het maken of alles op de kaarten bereikbaar is.

## Een Windows-versie (.exe) maken

**Automatisch via GitHub (aanbevolen):** open het tabblad **Actions**, kies *Windows-versie bouwen* en klik op
**Run workflow**. De workflow draait eerst alle tests en maakt dan de .exe. Na een paar minuten staat er een zip bij de
run onder *Artifacts*. Wil je een downloadlink voor je community? Maak een tag, bijvoorbeeld
`git tag v0.3.0 && git push origin v0.3.0`, dan verschijnt de zip onder **Releases**.

**Zelf in Godot:** *Project > Exporteren*, kies **Windows Desktop** en klik op *Project exporteren*.
Godot vraagt dan eenmalig om de export-templates (Editor > Export-templates beheren).

**Vanaf de opdrachtregel:**

```
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop" build/windows/BluemapQuest.exe
```

De .exe is zonder installatie te spelen. Hij is niet digitaal ondertekend, dus Windows kan een waarschuwing tonen
("Meer informatie" > "Toch uitvoeren"). Dat staat ook in `distribution/LEESMIJ.txt`, dat bij de zip zit.

## Licentie en dank

Alle pixel art, muziek, geluiden, verhaal en code in dit project zijn zelf gemaakt voor dit spel.
Het spel draait op de [Godot Engine](https://godotengine.org) (MIT-licentie).
