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
| Linkermuis / `Spatie` / `J` | X | Zwaard |
| Rechtermuis / `F` / `L` | rechter trekker | Boog: een pijl schieten (zodra je een boog hebt) |
| `Shift` / `K` | B | Rollen (je bent even onraakbaar) |
| `Ctrl` vasthouden | linkerstick indrukken en vasthouden (L3) | Sprinten; verbruikt de groene staminabalk |
| `C` | rechterstick indrukken (R3) | Beroepen, recepten en eten/drinken |
| `E` / `Enter` | A | Praten, kisten en altaren openen, lezen, vissen bij een visplek, doorklikken; op het titelscherm en in het pauzemenu: de gekozen knop indrukken |
| `H` | Y | Helddrank drinken |
| `I` / `Tab` | Back | Menu: voorwerpen |
| `Q` | linker schouderknop | Menu: opdrachten |
| `N` | rechter schouderknop | Menu: kaart (en snel reizen) |
| `T` | | Menu: prestaties |
| `B` | | Menu: beestenboek |
| `PageUp` / `PageDown` | LB / RB | In het menu: ander tabblad |
| WASD / pijltjes | linkerstick / d-pad | Inventarisraster en menukeuzes; vasthouden herhaalt |
| Muis | rechterstick | Richten met een permanent richtkruis |
| `Enter` / `E` / klik | A | Menu: bevestigen / gebruiken |
| `Esc` | B | Menu: terug / sluiten |
| `Esc` / `P` | Start | Pauze |
| `M` | | Geluid aan/uit |
| `↑` `↓` en `E` | d-pad en A | Taal wisselen: de knop *Taal: Nederlands* / *Language: English* op het titelscherm (rechtsboven) en in het pauzemenu |
| `F11` | | Volledig scherm |
| `R` | Start | Na game over: verder vanaf je laatste opslag |

Open **Bediening** op het titelscherm of in het pauzemenu om toetsen, muisknoppen en controllerknoppen apart aan te passen. De instellingen blijven bewaard; standaardinstellingen kunnen per apparaat worden hersteld. Bezette koppelingen wisselen om, tenzij een actie daardoor onbereikbaar zou worden. De vaste menubediening blijft beschikbaar.

Het laatst bewust gebruikte apparaat is actief. De controller verbergt de muiscursor; muis of toetsenbord neemt de besturing weer over bij bewuste invoer. Stickdrift wisselt het apparaat niet. Tijdens het spelen vervangt het richtkruis de gewone cursor; in muismenu's zie je de cursor weer.

## Wat zit erin

- **Uitrustingsslots:** naast zwaard en laarzen zijn er vijf nieuwe slots voor hoofd, borst, handen, hals en ring, met tien nieuwe uitrustingsstukken. Kies ze via **I → Uitrusting**; alleen gedragen spullen geven hun bonus. Tobias verkoopt de eerste stukken, betere versies maak je via Smeden en Alchemie. Hoofdbedekking geeft meer stamina, borststukken verminderen zware klappen (tot minimaal één hartje), handschoenen verkorten de zwaardwachttijd, amuletten versnellen staminaherstel en ringen trekken buit van verder weg aan. Je keuze wordt opgeslagen en gaat mee naar Nieuw Spel+.
- **Uiterlijk en kleding:** via **I → Uiterlijk** kies je geslacht, haarstijl (30 per geslacht), haarkleur, oogstijl en oogkleur, met een live voorvertoning. Kleding heeft vijf eigen vakken (hoofd, rug, bovenlijf, onderlijf, voeten) en draag je puur voor de look óver je uitrusting — zonder bonussen. Vera de kleermaakster in Dageraadsdorp verkoopt twaalf stukken; per gedragen stuk kies je een van de twaalf verfkleuren. Je uiterlijk en kleding worden opgeslagen.
- **Kijkrichting:** je personage kijkt tijdens het lopen in de looprichting en behoudt die richting bij stilstand. Muis of rechterstick bepaalt apart waar je zwaard of pijl naartoe gaat.
- **Heldenvoortgang:** verdien XP met verslagen vijanden buiten de arena en voltooide opdrachten. Je heldenniveau en XP-balk staan in beeld; elk nieuw niveau geeft 15 munten voor je volgende aankoop, tot niveau 10. Het tabblad **Voortgang** in de inventaris toont je helden- en beroepsniveaus, uitrusting en de kosten, voorwaarden en locaties van verbeteringen. De zeven beroepen behouden hun eigen XP en recepten. Oudere opgeslagen spellen starten met 0 helden-XP en behouden hun uitrusting; Nieuw Spel+ neemt je helden-XP mee.
- **Dorpsplein:** een grotere stenen fontein staat in het midden van het plein, met bewegende waterstralen, spetters en kringen. De looproutes blijven rondom de fontein bereikbaar.
- **Oprapen en animaties:** alle losse voorwerpen worden net als munten naar de speler getrokken. Volle stapels en hartjes bij volle gezondheid blijven beschikbaar. Mijnbouw, houthakken en kruidenzoeken hebben een korte werkactie met gereedschap, voortgang, geluid en deeltjes. Lopen, schade, gevechten of menu's onderbreken die actie. Vereist gereedschap, niveau en tasruimte worden ook bij het afronden opnieuw gecontroleerd. Er zijn extra rust-, sprint-, zwaard- en drinkanimaties.
- **Ondergrond en sprinten:** op paden loop je 20% sneller dan op gras; op zand 8% langzamer. Sprinten geeft 50% extra
  loopsnelheid zolang er stamina is. Zonder uitrustingsbonus is een volle balk goed voor vijf seconden sprinten; na 0,8 seconde rust begint het
  herstel. Na uitputting moet de balk eerst tot 25% herstellen. Rollen blijft hetzelfde. Gras, pad, zand, hout, steen,
  tapijt en sneeuw hebben elk hun eigen voetstappen, alleen hoorbaar als je echt beweegt.
- **Herkenbare gebouwen:** de smederij heeft een leien dak, schoorsteen, aambeeld en zichtbaar vuur; ook winkel,
  herberg, bibliotheek, vissershuisje, arena en tempel hebben een eigen exterieur en herkenbare symbolen.
- **Zeven beroepen:** kruidenzoeken, houthakken, mijnbouw, vissen, smeden, alchemie en koken, elk met ervaring en
  niveaus. Er zijn 47 verzamelplekken en recepten voor gereedschap, eten, drankjes en uitrusting. In `C` zie je je voortgang,
  ingrediënten, benodigde niveaus en werkplekken. De gewone inventaris bladert nu door alle spullen en meerdere pagina's.

- **Zeventien gebieden:** Dageraadsdorp met smederij, winkel en herberg, het Fluisterbos, de Vergeten Ruïne, de Echo-grot,
  de Kristaltempel, het Zilvermeer met het huisje van Joris en de bibliotheek, de Arena met haar hal, het mistige
  Dauwbos met kronkelpaden, een vijver en een paddenstoelenkring, het besneeuwde IJsdal met zijn bevroren meer en
  mijnhoek, de snikhete Dorstvallei met zandsteenkloof, oase en jachtgronden, en na het einde
  De Diepte (de Kristalgangen en Het Hart van de Kaart). In donkere gebieden heb je licht van je eigen lamp en fakkels.
- **Verhaal:** een hoofdopdracht en twaalf zij-opdrachten, eenentwintig personages en gesprekken met keuzes.
- **Gevechten:** zwaard in vier niveaus (hout, ijzer, kristal en het geheime Sterrenzwaard), ontwijkrol, slijmen in drie
  kleuren, vleermuizen, boogschutter-skeletten, magiërs, slijmspuwers, kristalgolems (minibazen), de Slijmkoning met drie
  fases en de geheime baas De Vergeten Wachter.
- **Wilde dieren:** in de Dorstvallei lopen woestijnvossen en zandhazen. Ze zijn onschuldig en vluchten als je dichtbij
  komt of ze raakt; wie ze vangt (met zwaard of boog) krijgt rauw vlees en dierenvachten voor de keuken en de handel.
- **De boog:** koop hem bij Tobias (met 5 pijlen erbij) en schiet met `F` (of `L`, of de rechter trekker). Elk schot kost
  een pijl uit je pijlenkoker (maximaal 40). Een pijl doet 2 schade (bij bazen 1), vliegt over water en blijft steken in
  muren. Op het kristal van een golem ketst hij af, behalve als de golem uithaalt voor een klap. Raak doelwitten om
  poortjes te openen in het bos en de ruïne, en probeer Tessa's schietbaan in het dorp (daar leen je haar pijlen).
- **Magiërs en slijmspuwers:** de magiër (Vergeten Ruïne en Echo-grot) zweeft, houdt afstand, teleporteert elke paar
  seconden en schiet na een aanloop een trage tovervonk af. Die kun je met je zwaard stukslaan. De slijmspuwer
  (Fluisterbos) spuugt drie slijmballen tegelijk en hupt weg als je te dichtbij komt.
- **Het Zilvermeer:** een rustig gebied aan de zuidkant van het dorp. Visser Joris leent je een hengel en bij de
  visplekken (de kringetjes in het water) speel je een visspel: wachten op een beet, snel op `E` drukken en de vis
  met `E` ingedrukt in de groene zone houden. Bij de verre steiger zwemt de Gouden Karper. In de bibliotheek van Lena
  lees je op de lessenaars over de geschiedenis van Azura, en een geheim kamertje wacht op wie Lena's boeken terugbrengt.
- **De arena:** in het noordoosten van het dorp (je hebt een ijzeren zwaard nodig en Oudste Bram moet je kennen).
  Arenameester Bruno schrijft je in voor Brons (3 rondes), Zilver (5) of Goud (7, met een kristalgolem als laatste).
  De poorten sluiten, het publiek juicht en na elke ronde krijg je drie seconden rust en een hartje. Je wint munten,
  trofeeën voor de plank in de hal, een titel en een beste tijd op het scorebord. Verslagen? Dan ben je alleen je
  inschrijving kwijt.
- **Dag en nacht:** een dag duurt 8 minuten. 's Ochtends is het warm, 's avonds oranje en 's nachts blauw en donker. Dan
  branden de lantaarns in het dorp en gloeien de ramen. In de herberg kun je in een bed slapen (5 munten): je wordt beter
  en het wordt ochtend.
- **Weer:** in het dorp, het bos en bij het meer regent het af en toe, met zacht geluid van de regen.
- **Snel reizen:** een blauw altaar dat je gebruikt hebt is "ontdekt". Open de kaart (`N`), kies een ontdekt altaar met
  `↑` `↓` en druk op `E` om er meteen heen te reizen (niet tijdens een gesprek, een baasgevecht of een arenagevecht).
- **Prestaties en beestenboek:** 32 prestaties (ook een paar geheime) die je ook in een nieuw spel houdt, en een boek met
  alle vijanden die je al verslagen hebt, met hun gegevens en een grappige beschrijving.
- **Verzamelen en upgraden:** winkel, smid die zwaarden maakt, drankjes, laarzen, hartcontainers (tot 8 hartjes),
  vis, boeken, trofeeën en verborgen kisten.
- **Na het einde:** een verzegelde trap achter in de Kristaltempel breekt open zodra de Blauwe Kaart hersteld is.
  Daaronder ligt **De Diepte**: de Kristalgangen (met een sleutel, een poort en een paarse kristalgolem) en Het Hart van
  de Kaart, waar de geheime baas **De Vergeten Wachter** slaapt. Wie hem verslaat krijgt het **Sterrenzwaard**, 500 munten
  en een kist met een hartcontainer (heb je al 8 hartjes, dan zitten er drankjes en munten in).
- **Nieuw spel+:** na het einde staat er op het titelscherm een knop *Nieuw spel+*. Je begint opnieuw met je beste zwaard,
  je hartcontainers, je laarzen en 100 munten. Vijanden hebben dan de helft meer levens per voltooide ronde en laten
  meer munten vallen.
- **Opslaan:** automatisch bij het wisselen van gebied, en bij de blauwe altaren (die genezen je ook).
- **Extra's:** titelscherm met "Doorgaan", intro, kaartje, geluid en muziek per gebied (volumes in het pauzemenu),
  ondersteuning voor een controller, en een eindscherm met aftiteling.
- **Talen:** Nederlands en Engels (zie [Talen](#talen)). Wisselen kan op het titelscherm en in het pauzemenu.

## Tips voor spelers

- Begin met losse takken en vuurstenen in het dorp: verzamel met `E`. Maak via `C` een stenen bijl en pikhouweel
  (elk 2 takken + 2 stenen). Gereedschap wordt automatisch gebruikt en slijt niet.
- Hak oogstbare berkenstronken in het bos en win koper. Smelt bij Greta in de smederij koperstaven: drie staven geven
  genoeg smidservaring voor een koperen pikhouweel. Daarmee kun je vanaf mijnbouw niveau 2 ijzer winnen in de Echo-grot.
- Kruiden, slijmgel en bessen worden bij de bibliotheek drankjes; bij de herberg maak je warme gerechten van vis of
  paddenstoelen. Een bessensnack kun je overal maken. Gebruik eten en energie-elixers via `C` of selecteer ze in `I` en druk `E`.
- Grondstoffen keren na 90–180 seconden actieve speeltijd terug. Gebieden wisselen, slapen en opnieuw laden omzeilen
  die wachttijd niet. Beroepenervaring en wachttijden worden met je spel opgeslagen; oudere opgeslagen spellen blijven werken.

- Rollen met `Shift` maakt je even onraakbaar. Gebruik dat tegen de bazen.
- Slijmen laten slijmgel vallen. Greta de smid maakt er betere zwaarden van.
- Golems laten kristalscherven vallen, nodig voor het kristalzwaard.
- Praat met iedereen: veel mensen hebben een opdracht of een tip.
- Met de boog schiet je ook schuin: loop je schuin, dan vliegt je pijl schuin. Soms zit er een doelwit ergens waar je
  rechtdoor niet bij kunt.
- Een magiër teleporteert elke paar seconden. Ren op hem af zodra hij verschijnt: raak je hem voordat hij schiet, dan
  mislukt zijn spreuk. Zijn tovervonk is traag: wijk uit, rol weg of sla hem stuk met je zwaard.
- Een slijmspuwer hupt weg als je vlak bij hem komt. Zet hem klem tegen een muur of val hem aan vlak nadat hij heeft gehupt.
- Vis verkoop je aan Joris of aan Mila in de herberg. Als het dorp vol zit met vis, krijg je de helft.
- De Vergeten Wachter kondigt elke aanval aan met een rode baan of gloed. Rol door zijn scherven heen, en laat hem tegen
  een muur of pilaar knallen: dan is hij duizelig en kun je hem raken.

## Mappen

```
project.godot          Instellingen, toetsen, vertalingen en autoloads (Lang, Controls, GameState en Sound)
scenes/                title, intro, main (de wereld) en ending
scripts/core/          GameState (voortgang, opslaan, voorwaarden en acties), Sound, Lang (de taal), Controls (besturing), hulpfuncties
scripts/data/          ALLE INHOUD: items, vijanden, personages, dialoog, opdrachten, winkels, tegels, aftiteling
scripts/data/ext/      Uitbreidingen als losse modules (zie scripts/data/content.gd), bijvoorbeeld meer.gd voor het Zilvermeer
scripts/maps/          De kaarten (tekst!) en het register
scripts/entities/      Speler, vijand, personage, voorwerp, kist, poort, altaar, projectiel...
scripts/ui/            HUD, dialoogvenster, menu, winkel, pauze, titel, intro en einde
scripts/world.gd       Laadt kaarten en zet alles neer
assets/                Pixel art (PNG) en geluid (assets/audio, WAV)
translations/          De vertalingen (en.po: Engels), zie "Talen"
tools/                 Scripts die plaatjes, geluid en kaarten maken en controleren, en tools/i18n.py voor de vertalingen
tests/                 De speltests (*_test.gd) en de balans-simulaties (*_sim.gd)
export_presets.cfg     Instellingen voor de Windows-versie
.github/workflows/     Automatisch een Windows-versie bouwen
```

## Zelf aanpassen

Bijna alles wat met inhoud te maken heeft staat als leesbare tekst in `scripts/data/` en `scripts/maps/`. Schrijf tekst
gewoon in het Nederlands; heb je tekst veranderd of toegevoegd, werk dan de vertaling bij (zie [Talen](#talen)).

- **Gesprekken:** `scripts/data/dialogue.gd`. Elk gesprek bestaat uit regels, eventueel keuzes en acties
  (een voorwerp geven, een opdracht starten...). De mogelijke voorwaarden en acties staan bovenaan `scripts/core/game_state.gd`.
- **Personages:** `scripts/data/npcs.gd` (wie zegt wat, afhankelijk van je voortgang).
- **Opdrachten:** `scripts/data/quests.gd`. Voorwerpen en zwaarden: `items.gd`. Winkels: `shops.gd`.
- **Vijanden:** `scripts/data/enemies.gd` (levens, snelheid, schade, wat ze laten vallen, en een `desc` voor het
  beestenboek). Het gedrag staat in `scripts/entities/enemy.gd`; de magiër en de slijmspuwer staan in
  `scripts/data/ext/vijanden.gd`.
- **Prestaties:** `scripts/data/achievements.gd`. Elke prestatie heeft een naam, uitleg en voorwaarden in hetzelfde formaat als
  bij gesprekken. Er zijn extra voorwaarden zoals `["kills", 50]` en `["rolls", 50]` (zie `scripts/data/ext/wereld.gd`).
- **Dag, nacht en weer:** in de kaart zet je `"outdoor": true` (de kaart volgt de klok) en `"weather": "rain"` (altijd regen) of
  `"random"` (wisselt met de klok). De kleuren van de dag staan in `scripts/core/daynight.gd`. Een lantaarn is een object
  `{"type": "wereld_lantaarn", "pos": [x, y]}`, een bed `{"type": "wereld_bed", "pos": [x, y]}`.
- **De arena:** `scripts/data/arena.gd` (rangen, rondes, beloningen en records: elke ronde is een lijst `[soort vijand, aantal]`,
  dus een nieuwe vijand in de arena zetten is een regel), `scripts/data/ext/arena.gd` (gesprekken, voorwerpen en de rest van
  de uitbreiding) en `scripts/entities/arena_master.gd` (speelt de golven). De kaarten zijn `scripts/maps/arena_hall.gd` en `arena.gd`.
- **Uitbreidingen:** elke uitbreiding (boog, vijanden, Zilvermeer, wereld, Diepte, arena) is een eigen module in
  `scripts/data/ext/` die zich met één regel aanmeldt in `scripts/data/content.gd`. Daar staat ook hoe je zelf een
  uitbreiding maakt: met eigen gesprekken, voorwerpen, vijanden, kaarten, objecten, voorwaarden en acties.
- **Kaarten:** `scripts/maps/*.gd`. De kaart is gewone tekst, elk teken is een tegel (zie `scripts/data/tiles.gd`).
  Personages, vijanden, kisten en poortjes staan als lijst onder `objects`. Wijzig iets en druk op F5.
  Zet nieuwe objecten altijd achteraan de lijst: kisten en unieke voorwerpen worden in de opslag onthouden met hun plek
  in de lijst. `python3 tools/gen_maps.py` controleert alleen de oorspronkelijke acht kaarten; met `--force` maakt hij ze
  opnieuw en overschrijft hij alle handwerk.

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
| `mage.png` | 4 vakjes: rustig (2), aanloop met oplichtende handen, teleport-wolkje |
| `slime_spitter.png` | 5 vakjes: rustig (2), opblazen, spuwen, hupje |
| `arcane_orb.png` | 4 vakjes: de tovervonk van de magiër, pulserend |
| `golem.png` | 32x32: rustig (2), armen omhoog, klap |
| `king.png` | 48x48: rustig (2), ineengedoken, in de lucht |
| `npc_*.png` | 2 vakjes: rustig en een beetje bewegen |
| `items.png` | iconen, nummer = `icon` in `items.gd` (uitbreidingen hebben een eigen plaatje, zoals `items_meer.png`) |
| `chest`, `sign`, `gate`, `altar`, `torch`, `coin`, `heart`, `ui_heart`, `projectiles` | zie `tools/art_items.py` |
| `items_boog.png`, `target.png`, `npc_tessa.png` | boog-iconen (boog, pijl, vliegende pijl), doelwit (gewoon, geraakt) en Tessa, zie `tools/art_x_boog.py` |
| `guardian.png`, `golem_void.png`, `depths_*.png`, `items_diepte.png` | De Diepte: de Wachter (48x48, 8 vakjes), de paarse golem, pilaar, zegel, lamp, poort, scherf en iconen. Zie `tools/art_x_diepte.py` |
| `wereld_ui.png` | zon, lage zon, maan, drie bekers en een altaarspeldje, zie `tools/art_x_wereld.py` |
| `wereld_lantaarn.png` | 3 vakjes van 16x32: uit, aan, aan (flikkert) |
| `audio/*.wav` | geluidseffecten; `audio/music_<gebied>.wav` zijn lussen van 25 tot 45 seconden; `wereld_regen.wav` is een lus van 6 seconden |

## Testen

Zonder scherm, handig na elke wijziging:

**Windows, macOS en Linux (Python 3):**

```
python tools/run_tests.py /pad/naar/godot
```

Dit maakt een tijdelijke projectkopie en controleert een unieke opslagmap voordat de tests beginnen. Op Windows is dit
de veilige route: alleen `XDG_DATA_HOME` instellen is daar onvoldoende. Gebruik `--tests movement_test professions_test`
voor een gerichte controle en `--keep` om de testkopie en logs te bewaren. Je gewone spelopslag wordt niet gebruikt.

**Linux / de GitHub-build:**

```
sh tools/run_tests.sh /pad/naar/godot
```

Dat draait alle tests in `tests/` (`*_test.gd`):

- `smoke_test.gd` controleert eerst alle inhoud op samenhang (elk gesprek, elke kaart, elk voorwerp, elke opdracht) en
  speelt daarna de systemen na: lopen, gebieden wisselen, vechten, de baas, praten, kopen, smeden, opslaan, menu's,
  titelscherm, intro en einde.
- `playthrough_test.gd` speelt het hele verhaal uit met de echte kaarten: van Bram tot en met het einde.
- `boog_test.gd`, `vijanden_test.gd`, `meer_test.gd`, `wereld_test.gd`, `diepte_test.gd` en `arena_test.gd` testen elk een
  uitbreiding: gedrag, opdrachten van begin tot eind, opslaan en laden, en of alles op de kaarten bereikbaar is.
- `samen_test.gd` test de samenhang tussen de uitbreidingen: oude opslagen, prestaties, het beestenboek, de arena-vijanden,
  snel reizen en de tekens in teksten.
- `movement_test.gd`, `buildings_test.gd`, `professions_test.gd` en `adventure_integration_test.gd` controleren ondergrond,
  stamina, voetstappen, vrije ingangen, verzamelplekken, recepten, opslag, menubediening en een volle inventaris.
- `taal_test.gd` test de talen: de taalkeuze en de taalknoppen, het spel in het Engels (met een kleine test-vertaling) en
  of `translations/en.po` bij de code past (zie [Talen](#talen)).

De tests draaien in het Nederlands: `run_tests.sh` zet `BLUEMAP_LANG=nl`.

Alles eindigt met `ALLE TESTS GESLAAGD`, en bij een scriptfout stopt het met een foutmelding. De tests schrijven in een
eigen opslagmap (`.testdata`), dus je eigen spel blijft onaangeroerd.

Meer gereedschap:

- `tests/boss_sim.gd`: een bot speelt het baasgevecht steeds opnieuw met verschillende zwaarden. Handig om de balans te meten.
- `tests/guardian_sim.gd`: een bot vecht steeds opnieuw tegen De Vergeten Wachter. Handig om te zien of de baas eerlijk blijft.
- `tests/arena_sim.gd`: een bot speelt Brons, Zilver en Goud steeds opnieuw (`godot --headless --fixed-fps 60 --path . -s tests/arena_sim.gd`).
  Het doel is dat een redelijke speler met het passende zwaard Brons ongeveer 90%, Zilver 65% en Goud 40% van de keren haalt.
  Pas je de rondes in `scripts/data/arena.gd` aan, draai dan deze bot weer.
- `python3 tools/check_audio.py`: controleert geluiden en muzieklussen op clipping, tikjes en de juiste noten.
- `python3 tools/gen_maps.py`: controleert of alles op de oorspronkelijke acht kaarten bereikbaar is.

## Talen

Het spel is in het Nederlands geschreven en helemaal in het Engels vertaald (`translations/en.po`). Heeft een nieuwe
tekst nog geen vertaling, dan staat hij ook in het Engels gewoon in het Nederlands in beeld, en faalt de taaltest (zie
hieronder).

### De taal kiezen

Op het titelscherm (rechtsboven) en in het pauzemenu staat de knop **Taal: Nederlands** (in het Engels: **Language:
English**). Eén druk (`E`, `Enter` of A op de controller) wisselt de taal, en alles op het scherm verandert meteen mee.
De keuze wordt bewaard in `user://settings.cfg` (sectie `[taal]`, naast de instellingen van het geluid). Zonder
bewaarde keuze bepaalt de omgevingsvariabele `BLUEMAP_LANG` de taal (`nl` of `en`), en anders je computer: Nederlands
als die Nederlands is, anders Engels.

### Hoe het werkt

Het systeem is gettext met Godot's eigen `TranslationServer`. `translations/en.po` heeft voor elke tekst de Nederlandse
brontekst (`msgid`) en de Engelse vertaling (`msgstr`). Nederlands heeft geen eigen bestand: in het Nederlands, of als
een vertaling ontbreekt, blijft de brontekst staan (in `project.godot` is Nederlands de terugvaltaal). De autoload `Lang`
(`scripts/core/lang.gd`) kiest de taal en geeft het signaal `changed` als hij verandert.

Alle tekst gaat precies één keer door de vertaling, op het moment dat hij in beeld komt:

- **Tekst in de code:** `tr("Je hebt geen helddrank.")`. In een statische functie of een content-module (die de naam
  `Lang` niet mogen gebruiken) `TranslationServer.translate("...")`. Vertaal altijd eerst het sjabloon en vul het daarna
  in: `tr("Gekregen: %s") % naam`. Een getal waar een meervoud bij hoort: `tr_n("%d munt", "%d munten", n) % n`. Plak
  nooit stukken zinnen aan elkaar; schrijf liever twee hele zinnen.
- **Tekst uit de data** (gesprekken, voorwerpen, kaarten...): blijft Nederlands in `scripts/data/` en `scripts/maps/`.
  Het scherm dat hem toont doet `tr(tekst)` en vult daarna pas de `{tekens}` in (`GameState.fmt`).
- Godot vertaalt de tekst van Labels en Buttons normaal zelf; dat staat uit (anders wordt tekst dubbel vertaald). Geef
  een Label dus tekst die al vertaald is, en werk hem bij als `Lang.changed` komt.
- Uitleg voor de vertalers zet je als commentaar vlak boven de regel: `# Vertalers: ...`.

### De vertaling bijwerken na het wijzigen van tekst

```
python3 tools/i18n.py extract --godot /pad/naar/godot   # translations/en.po bijwerken
python3 tools/i18n.py check                             # wat ontbreekt er, en kloppen de plaatsaanduidingen?
```

`extract` laat Godot de echte data doorlopen (`tools/i18n_extract.gd`: gesprekken, voorwerpen, opdrachten, kaarten,
de aftiteling, alle uitbreidingen...) en zoekt in de code alle `tr(...)`, `tr_n(...)` en `TranslationServer.translate(...)`
met letterlijke tekst. Nieuwe teksten komen erbij met een lege vertaling, bestaande vertalingen blijven staan en teksten
die niet meer bestaan gaan eruit. Een veranderde Nederlandse zin is dus een nieuwe tekst die opnieuw vertaald moet worden.
In plaats van `--godot` kun je ook `GODOT=/pad/naar/godot` zetten.

### Vertalen (ook in delen)

```
python3 tools/i18n.py split --parts 7 --out vertaling/   # 7 PO-bestanden van ongeveer even veel woorden
#   ... vul in elk deel de msgstr-regels in ...
python3 tools/i18n.py merge vertaling/                    # de vertalingen terug in translations/en.po
python3 tools/i18n.py check
```

Met `split --untranslated` krijg je alleen de teksten die nog geen vertaling hebben. Bij elke tekst staat uitleg (`#.`:
wie het zegt, waar het staat) en waar hij in de scripts staat (`#:`). Regels om op te letten:

- Plaatsaanduidingen blijven staan: `{crystals}`, `%s`, `%d`, `%.1f`... De `%`-tekens moeten in dezelfde volgorde blijven
  (ze worden op volgorde ingevuld); `{tekens}` mogen overal in de zin. `check` en de test controleren dat.
- Meervouden hebben twee vormen: `msgstr[0]` voor 1, `msgstr[1]` voor alle andere aantallen.
- `msgctxt` maakt dezelfde Nederlandse tekst met een andere betekenis los, zoals `klap` (een aanval) en `,` (het
  decimaalteken: in het Engels een punt).
- Namen (Pim, Azura) mogen hetzelfde blijven; vul ze dan toch in, anders telt de tekst als ontbrekend.

### Wat controleert de test?

`tests/taal_test.gd` controleert dat `en.po` bij de code past (elke tekst erin, geen verouderde teksten), dat **elke**
tekst een Engelse vertaling heeft (een lege of fuzzy vertaling telt als ontbrekend) en dat elke vertaling dezelfde
plaatsaanduidingen heeft als de brontekst. Verander of voeg je Nederlandse tekst toe, draai dan `extract`, vertaal de
nieuwe teksten en draai `check`; anders faalt de test.

Ben je nog aan het vertalen? Met `I18N_ALLOW_MISSING=1 sh tools/run_tests.sh ...` is een ontbrekende vertaling even geen
fout (fouten in plaatsaanduidingen en teksten die niet in `en.po` staan wel).

### Een nieuwe taal toevoegen

1. `python3 tools/i18n.py extract --lang de --godot /pad/naar/godot` maakt `translations/de.po` met alle teksten. Past
   `Plural-Forms` in de kop niet bij de taal, pas hem dan aan (en draai extract opnieuw).
2. Meld het bestand aan in `project.godot` (`internationalization/locale/translations`, of in de editor: Projectinstellingen >
   Lokalisatie).
3. Zet de taal in `LANGUAGES` in `scripts/core/lang.gd`, met de tekst voor de taalknop in die taal zelf, bijvoorbeeld
   `"de": "Sprache: Deutsch"`. De knop wisselt dan Nederlands > Engels > Duits.
4. Vertaal, en controleer met `python3 tools/i18n.py check translations/de.po`.

## Een Windows-versie (.exe) maken

**Automatisch via GitHub (aanbevolen):** open het tabblad **Actions**, kies *Windows-versie bouwen* en klik op
**Run workflow**. De workflow draait eerst alle tests en maakt dan de .exe. Na een paar minuten staat er een zip bij de
run onder *Artifacts*. Wil je een downloadlink voor je community? Maak een tag, bijvoorbeeld
`git tag v0.4.0 && git push origin v0.4.0`, dan verschijnt de zip onder **Releases**.

Elke push naar `main` en ieder wijzigingsvoorstel start dezelfde tests en Windows-build automatisch. Het taalpakket is geïntegreerd; nieuwe teksten worden door de taaltest gecontroleerd.

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
