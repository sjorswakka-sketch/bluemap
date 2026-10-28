# Opslag en identiteit — behoudscontract fase 1

Dit document bewaart de fase-1-broninventarisatie van **Bluemap Quest 0.34.0-preview**, commit `a8a988be27835dec979d2523a3a85a34385eac54`. De brontabellen en toenmalige acceptatie-eisen hieronder blijven de historische referentie; ze beschrijven geen latere wijzigingen aan de oorspronkelijke Godot-game.

**Actuele migratiestatus:** veilige import en afzonderlijke Unity-profielen zijn in [fase 9](phase-09/README.md) gebouwd en bewezen; de huidige [fase 16](phase-16/README.md) behoudt alle 34 opslagvelden, onbekende toekomstige velden, originele bronbytes, uitrusting/uiterlijk, unieke beloningen en verhaalvoortgang. Alle tests gebruiken eigen synthetische profielen. Persoonlijke bestanden worden alleen na expliciete keuze op een veilige kopie geïmporteerd. Omgekeerde export van nieuw gemaakte Unity-voortgang naar Godot is nog niet bewezen en blijft fase 25.

De machineleesbare tegenhanger is [reference/save-contract.json](reference/save-contract.json). Daarin staan alle 34 hoofdvelden, geneste structuren, bronnen, migraties, ID-regels en controleprofielen. De bronverwijzingen zijn relatief aan de repository en horen bij bovenstaande commit.

## Wat moet behouden blijven

De actuele bron gebruikt vijf bestanden onder Godots `user://`: `savegame.json`, `meta.cfg`, `ng_plus.cfg`, `controls.cfg` en `settings.cfg`. Het project heet exact `Bluemap Quest` en configureert geen aangepaste gebruikersmap; op Windows is de verwachte standaardlocatie `%APPDATA%/Godot/app_userdata/Bluemap Quest/`. Die map is voor deze inventarisatie niet benaderd. Een toekomstige tool moet de werkelijke map expliciet vaststellen en daarna uitsluitend op kopieën werken.

Bewaar bij iedere toekomstige import de oorspronkelijke bestanden ongewijzigd, met hun hashes. Houd ruwe brongegevens apart van een genormaliseerde interpretatie. De huidige normalizers verwijderen bewust onbekende of ongeldige waarden; dat mag geen stilzwijgend verlies in het behoudsarchief worden. Onbekende velden moeten als brondata beschikbaar blijven, ook wanneer de speelbare import ze nog niet ondersteunt.

Vier categorieën zijn verschillend:

- **Huidig avontuur:** inventaris, quests, kaart, woning, landbouw, wereldflags en bezoeken.
- **Blijvende metadata:** achievements over meerdere avonturen en het beste bezit/ronde voor Nieuw spel+.
- **Voorkeuren:** taal, audio en de afzonderlijke toetsenbord-/controllerprofielen.
- **Tijdelijke of afgeleide toestand:** bijvoorbeeld NPC-posities, stamina, menu-selectie en weersfase; de huidige game slaat die niet zelfstandig op.

## Alle velden van savegame.json

`GameState.save_game()` schrijft 34 velden; `load_game()` leest ze in een vaste volgorde. De huidige `SAVE_VERSION` is `1`, maar de loader gebruikt het versienummer niet om migraties te selecteren. In onderstaande tabel is de default die bij **ontbreken tijdens laden** wordt gebruikt; die is soms anders dan de lege runtime-dictionary direct na `new_game()`.

Bron: `scripts/core/game_state.gd:688–796`.

| Veld | Vorm / ontbrekende default | Betekenis en actuele laadregel |
|---|---|---|
| `version` | integer; schrijver zet `1` | Wordt momenteel niet gelezen of gevalideerd. |
| `map` | string; `village` | Stabiele kaart-ID; loader zelf heeft geen whitelistcheck. |
| `pos` | `[x,y]`; `[0,0]` | Wereldpixels, 32 pixels per tile, positieve y naar beneden; wordt `load_pos`, met veilige aankomstcorrectie bij kaartopbouw. |
| `hp` | integer; `5` | Na bezit laden begrensd tot `1..5+heart_container-aantal`. |
| `coins` | integer; `0` | Integercast; geen expliciete niet-negatieve laadclamp. |
| `inventory` | item-ID → aantal; `{}` | Gearbezit maximaal één geldig exemplaar; overige aantallen integercast zonder algemene whitelist/cap in deze loader. |
| `flags` | flag-ID → waarde; `{}` | Aanwezige sleutels worden momenteel allemaal `true`, ook bij raw `false`; zie legacygedrag hieronder. |
| `quests` | quest-ID → `{state,step}`; `{}` | State gekopieerd, step integercast; geen algemene ID- of stapvalidatie. Afwezige quest betekent `none`, stap `-1`. |
| `weapon` | zwaard-ID; `wood` | Rechtstreeks gekopieerd; de gewone save-loader heeft geen fallback voor een onbekend zwaard. |
| `visited_maps` | kaart-ID → bool; ontbrekend: bewijsafleiding | Alleen bekende IDs met raw bool `true`; geldige huidige kaart erbij; ontbreken verschilt van aanwezig maar leeg. |
| `play_time` | actieve seconden; `0.0` | Floatcast; referentie voor absolute verzameldeadlines en dierlijke drops. |
| `kills` | integer; `0` | Totaal; onafhankelijk van `kills_by`. |
| `meer` | stat-ID → integer; `{}` | Onder andere `verkocht`, `gevangen`, `pech`; onbekende counters niet wegfilteren uit brondata. |
| `day_time` | dagfractie; `0.15` | Floatcast, `fposmod(t,1)`; een dag duurt 480 actieve seconden. |
| `day_count` | integer; `0` | Dagnummer; bepaalt samen met dagfractie het weer. |
| `kills_by` | vijandsoort → integer; `{}` | Bij volledig ontbreken worden enkele oude bossflags omgezet naar tellingen. |
| `rolls` | integer; `0` | Achievementteller. |
| `potions_drunk` | integer; `0` | Achievementteller. |
| `deaths` | integer; `0` | Wordt bij overlijden ook direct in de bestaande save bijgewerkt. |
| `boss_deaths` | integer; `0` | Overlijden tijdens begonnen maar niet verslagen Slijmkoning; dezelfde directe savepatch. |
| `talked` | NPC-ID-array; `[]` | Runtime is een set; oude katflag vult alleen bij ontbrekend veld `muis_bos` aan. |
| `achievements` | achievement-ID-array; `[]` | Verenigd met blijvende metadata; nieuw gevonden IDs worden naar `meta.cfg` geschreven. |
| `arena_records` | rang-ID → beste seconden; `{}` | Dictionary vereist; getallen floatcast, geen expliciete finite/positieve laadcheck. |
| `homestead` | landbouw-/productietoestand; genormaliseerde lege staat | Gewassen, kanalen, productie, honing, dierlijke timers en drops. |
| `coastal_storage` | materiaal-ID → aantal; `{}` | Kustvoorraad, maximaal 12 materiaalsoorten, maximaal 99 per soort. |
| `stockroom` | `{home,favorites,sort}` | Gedeelde huisvoorraad, favorieten en sorteervoorkeur. |
| `personal_home` | `{owned,layout,floor,wall,light}` | Meubelbezit, plaatsing en woningstijl; defaults uit de catalogus. |
| `yard` | `{stations,paths,fences,owned,extensions}` | Productieplaatsing, erftegels, hekjes, bouwvoorraad en uitbreidingen. |
| `professions` | `{xp,cooldowns,goal?}` | Beroeps-XP, exacte grondstofdeadlines en eventueel gevolgd recept. |
| `hero_xp` | integer; `0` | Finiet numeriek, begrensd tot `0..2250`; laden kent geen levelbeloning toe. |
| `equipment` | slot → item-ID; `{}` | Geldig bezit én juiste slot vereist; bewust leeg blijft leeg. |
| `appearance` | uiterlijkdictionary | Default `m`, `m_kort`, haarkleur `2`, ogen `rond`, oogkleur `0`. |
| `clothing` | kledingvak → `{item,dye}`; `{}` | Cosmetische kleding/kleuren; afzonderlijk van uitrustingsbonussen. |
| `ng_plus` | integer; `0` | Ronde van dit avontuur; niet hetzelfde als de hoogste ronde in `ng_plus.cfg`. |

Een geldige JSON-root is niet voldoende bewijs van een geldige save: de huidige loader controleert niet ieder genest type en iedere grens. Een toekomstige converter moet ongeldige input veilig melden zonder de originelen te veranderen. Fase 1 introduceert geen strengere spelregels en repareert geen bronbugs.

## Geneste toestand en normalisatie

### Bezit, uitrusting en uiterlijk

`Equipment.normalize_owned()` bewaart bekende gear-IDs met een finiete numerieke hoeveelheid van minstens één als precies één. De vijf uitrustingsvakken zijn `head`, `chest`, `hands`, `neck`, `ring`. Een selectie blijft alleen bestaan als het item bij dat vak hoort en daadwerkelijk wordt bezeten. Lege selecties mogen niet automatisch worden opgevuld; bezit alleen geeft geen gearbonus. Bron: `scripts/core/equipment.gd:14–41`.

Uiterlijk bevat `gender`, `hair`, `hair_color`, `eyes`, `eye_color`. Alleen exact `v` kiest vrouw, anders `m`. Ongeldig haar valt terug op de derde stijl van de betreffende geordende catalogus. Ogen vallen terug op `rond`; kleurindexen worden naar de catalogusgrenzen begrensd. Kledingvakken zijn `hat`, `back`, `top`, `bottom`, `feet`; ieder gedragen item moet bezeten zijn en het juiste vak gebruiken. `dye` is een begrensde palette-index. Catalogusvolgorde is daarom betekenisvol. Bron: `scripts/core/appearance.gd:10–72`, `scripts/data/ext/uiterlijk.gd`.

### Beroepen en grondstoffen

`professions.xp` bevat geregistreerde skill-IDs met gehele waarden `0..1350`. `cooldowns` bevat **absolute deadlines op actieve `play_time`**, geen resterende seconden en geen echte datums. Verlopen entries worden verwijderd; geldige toekomstige deadlines worden begrensd op huidige speeltijd plus de eigen grondstofwachttijd. Bekende oorspronkelijke plaatsingen en de exacte verrijkte object-IDs voor `trail:`, `winter:` en `forestfood:` worden gecontroleerd. Een prefix alleen is onvoldoende. `goal` blijft alleen bestaan als geldige recept-ID. Bron: `scripts/core/professions.gd:31–75`.

Let op de bestaande asymmetrie: herstelbare werelddecoratie maakt ook grondstoffen met expliciete IDs zoals `lw_mine_iron`, `lw_mine_copper`, `lw_shore_mint`, `lw_revealed_flower`. Deze runtimefamilie wordt niet op dezelfde wijze door bovenstaande cooldownnormalizer geïnventariseerd. Bewaar ruwe waarden en leg dit gedrag vast; fase 1 verandert het niet.

### Landbouw, irrigatie, dieren en productie

`homestead` heeft zeven leden:

| Lid | Betekenis / laadnormalisatie |
|---|---|
| `cells` | Tilekey `x,y` → `kind: soil/channel`; bekende grondgewassen kunnen `crop`, `growth`, `fertilized`, `established` hebben. |
| `jobs` | `compost`, `wine_a`, `wine_b` → `{batches,time}`. Batches `1..20`; tijd `0..receptduur`. |
| `animal_due` | Dieridentiteit → absolute speeltijddeadline, maximaal `play_time+90`. |
| `drops` | Drop-ID → `{map,pos:[wereldpixel-x,y]}`; posities `0..10000`. |
| `wild_due` | Wilde druiven: absolute deadline, maximaal `play_time+120`. |
| `honey` | Opgeslagen honing, integer `0..8`. |
| `honey_time` | Verstreken productieseconden `0..120`. |

Het landbouwvlak is `Rect2i(4,29,31,12)`, zonder kolommen 20/21. Gewas-IDs zijn `grape`, `flower`, `carrot`, `pumpkin`, `mint`, `rosemary`, `apple`, `berry`. Growth wordt begrensd op de actuele groeiduur; `established` geldt alleen voor hergroeiers. Bemesting beïnvloedt de opbrengst en wordt na de oogst verbruikt. Appelbomen hebben andere wortel-/kroonruimte dan een enkele gewastegel. Bron: `scripts/core/homestead.gd:16–50`, `scripts/data/orchard_catalog.gd`.

Compost gebruikt twee mest voor drie fertilizer in 30 seconden; ieder wijnvat gebruikt drie druiven voor één wijn in 90 seconden. Het lopende werk hoort bij de **vaste productie-eenheid-ID**, niet bij zijn huidige tilepositie; verplaatsen mag tijd of output niet dupliceren/verwijderen. `animal_due` en `drops` bewaren maximaal 128 entries per veld, met string-ID maximaal 140 tekens; de runtime maakt maximaal 64 gelijktijdige drops. Bron: `scripts/core/homestead.gd:6,35–50,162–197`.

De waternetwerken `wet` en `flow` worden opnieuw berekend uit de opgeslagen kanalen en vaste bronnen. De game slaat geen aparte met-water-gevuld-vlag per kanaal op. Gewassen groeien alleen wanneer de watercheck slaagt. Honing heeft minstens drie bloeiende planten nabij de bijenkast nodig, maakt één eenheid per 120 actieve seconden en stopt bij acht. Een opgeborgen hive pauzeert productie zonder honing te wissen.

### Voorraad, woning en erf

`stockroom.home` bewaart maximaal 144 bekende materiaal-/verbruiks-/munitiesoorten met finiet aantal `1..999`; permanente gear gaat daar niet in. `favorites` bewaart bekende item-IDs met `value == true`; `sort` is `0..3`. Kustvoorraad heeft een apart maximum van 12 materiaalsoorten en 99 stuks. De iteratievolgorde is relevant wanneer een beschadigde input meer soorten bevat dan de limiet. Bronnen: `scripts/core/stockroom.gd:4–26`, `scripts/core/coastal_home.gd:3–18`.

`personal_home.owned` bewaart meubelbezit; starterbezit kan bij normalisatie niet afnemen. `layout` bewaart stabiele meubel-ID, soort, tilepositie en tint. De basismeubels `bed`, `table`, `shelf` blijven verplicht; optionele IDs zijn `kind:<nummer>`. Maximaal twaalf meubels en 26 vaste/collidercellen; doorgangen, servicepunten en alle vrije vloer blijven verbonden. Bij een ongeldige volledige indeling wordt de standaardindeling gebruikt, met behoud van genormaliseerd bezit en stijl. `floor/wall` zijn `0..3`, `light` is `0..2`, tint is `0..2`. Bron: `scripts/core/personal_home.gd:6–91`, catalogus `scripts/data/house_catalog.gd`.

`yard.stations` heeft `wine_a`, `wine_b`, `compost`, `hive`; `[]` betekent bewust opgeborgen. Standaardposities zijn respectievelijk `[4,25]`, `[12,25]`, `[7,15]`, `[15,32]`. `paths` en `fences` zijn canonical `x,y` → onderdeel-ID, met maxima 80/40; `owned` bewaart gemaakte bouwdelen en `extensions` bekende unieke IDs `west/east`. Normalisatie valideert eerst landbouw en daarna erf, slaat onveilige gewijzigde stations op en repareert optionele delen zonder gewassen of jobs te verwijderen. Bij ongeldige eindconnectiviteit worden paden/hekjes gewist, niet de landbouw. Bron: `scripts/core/yard.gd:17–21,139–172`, `scripts/data/yard_catalog.gd`.

## Legacygedrag en exacte laadvolgorde

De volgorde is onderdeel van het contract: eerst `new_game()`, dan gewone velden, normalisatie met de reeds geladen speeltijd, genormaliseerde landbouw vóór erf, inventaris vóór gedragen selectie, daarna flags/quests, de oude-save-aanvullingen, raw bezoekbewijs en ten slotte HP. Pas bij `world.load_map()` volgen de wereldmigraties en geometrieopbouw. Een converter die alles tegelijk deserializeert kan zo andere uitkomsten geven.

| Situatie | Bestaand gedrag |
|---|---|
| `kills_by` ontbreekt | `golem_ruins`/`golem_cave` leveren ieder één golem; `boss_defeated` één king. Totaal `kills` blijft apart. |
| `talked` ontbreekt + `cat_found` | Voeg `muis_bos` toe; dit is geen raw atlasbewijs. |
| `visited_maps` ontbreekt | Leid alleen exact aantoonbare bezoeken af uit raw gegevens. |
| `visited_maps` aanwezig maar leeg/ongeldig | Geen verdere bewijsafleiding; geldige huidige kaart wordt wel toegevoegd. |
| `lw_revision_1` ontbreekt | Oude afgeronde `warmte`/`wilgentwijgen` krijgen hun wereldgevolg; actieve stappen worden naar nul gezet; revisieflag gezet. |
| Afgeronde drooglegging | Iedere kaartload brengt west/east-sluizen naar west open/east dicht en markeert beide gezien. |
| `ra_revision_1` ontbreekt | Afgeronde `cactusvijgen` krijgt bron/wildkeuze; actieve stap naar nul; revisieflag gezet. |
| `rf_revision_1` ontbreekt | Afgeronde `medaillon` krijgt relief/journal/memorial/guard, zonder opnieuw beloning; revisieflag gezet. |
| Oude positie in afgesloten Bergpasomloop | Verplaats naar een bereikbare kant; verdere normale aankomstveiligheid controleert terrain/colliders. |

Bronnen: `game_state.gd:324–335`, `world.gd:158–204`, `living_world.gd:8–29`, `regional_adventures.gd:7–14,35–39`, `first_route.gd:5–10`.

**Gedocumenteerde bronbug, geen fase-1-fix:** `load_game()` loopt door de keys van raw `flags` en zet ze allemaal op `true`, ook bij opgeslagen `false`. Daartegenover gebruikt de atlas voor oude bezoeken alleen **raw bool-true**. Ook `meta.cfg` behandelt iedere aanwezige achievement-key als behaald, ongeacht de opgeslagen waarde. Deze afwijkende interpretaties moeten afzonderlijk zichtbaar blijven in bronbewijs en testverwachtingen. Stilzwijgend alle drie vervangen door één normale booleanparser verandert bestaand gedrag.

## Stabiele object- en contentidentiteit

`world.gd:466–559` loopt door de volledige objectarray en maakt de key:

```text
<type>:<map_id>:<nulgebaseerde objectindex>
```

De index is de index vóór filtering op `enabled` of `if`. Een uitgeschakeld slot bestaat dus nog steeds. Ook de **type-string** is deel van de identiteit. Kisten en unieke pickups gebruiken deze key rechtstreeks; uitbreidingsobjecten krijgen hem als `key` mee. Unity-scene-instance-IDs, GUIDs of opnieuw genummerde zichtbare lijsten zijn geen vervanging. Bewaar een expliciete `legacy_key` met type, kaart en oorspronkelijke slotindex.

De uiteindelijke objectarray bestaat uit basisdata, de geordende registry-verrijkingen, first-route-/toegangspuntvoorbereiding en de achteraan toegevoegde oorspronkelijke beroepsgrondstoffen. De registry bevat negentien `enrich`-aanroepen plus de conditionele moerasvoorbereiding en het toegevoegde herbergboek. Een alfabetisch gesorteerde export of een export van alleen `DATA.objects` mist inhoud en kan IDs veranderen. Bron: `scripts/maps/registry.gd:23–46`, `scripts/world.gd:158–174`.

Aanvullende namespaces:

| Soort | Identiteit |
|---|---|
| Altaar | `altaar_<map>_<tile-x>_<tile-y>`; afzonderlijke ontdekking door gebruik, geen gewone bezoekflag. |
| Oorspronkelijke grondstof | Expliciete `<map>:<plaatsingsnaam>` uit `RESOURCE_PLACEMENTS`. |
| Padgrondstof | `trail:<map>:<tile-x>:<tile-y>`. |
| Wintergrondstof | `winter:<map>:<geplande-soort>`. |
| Bosvoedsel | `forestfood:<map>:<soort>`. |
| Dynamische herstelgrondstof | Expliciete `lw_*`-ID, niet afgeleid uit objectarray. |
| Dierlijke timer | `<map>:<diersoort>:<home-tile-x>,<home-tile-y>`, onafhankelijk van rondlooppositie. |
| Mestdrop | Dieridentiteit plus `:<int(play_time*1000)>`; oppakflag `hs_drop:<drop-ID>`. |
| Landbouw-/erfcel | Lokale `x,y`-tilekey; geen wereldpixels. |
| Meubel | Basis-ID exact soort; optioneel `kind:<positief nummer>`. |
| Gevolgde quest | `jr_focus_<quest-ID>` in flags; gevolgd recept is los daarvan `professions.goal`. |
| Overige spelinhoud | Exacte quest-, NPC-, dialoog-, item-, recept-, vijand-, gate- en trigger-once-IDs en alle aangepaste flagnames. |

Vertaalde namen zijn nooit IDs. Bewaar waar relevant ook dictionaryvolgorde: de laatst gestarte actieve quest kan de zichtbare tracker bepalen en begrensde voorraadnormalisatie verwerkt entries in bronvolgorde. Geordende dialoogvoorwaarden, acties en queststappen mogen niet als ongesorteerde sets worden behandeld.

## Klokken en dynamische kaartstaat

De actieve tijdvoorwaarde is exact `in_game && !ended && !SceneTree.paused`. Een open menu/dialoog pauzeert via `ui_owners`; `transitioning` alleen pauzeert de klokken niet. Slapen zet alleen `day_time` naar `0.08`, en verhoogt de dag alleen als de vorige dagfractie later was; het maakt geen landbouw of grondstofwachttijd af. Er is geen offline inhaalsimulatie.

Getij wordt afgeleid van `fposmod(day_time*480,96)`: laag `[0,48)`, opkomend `[48,60)`, hoog `[60,84)`, aflopend `[84,96)`. Hoog/aflopend maakt de zandbank nat. De live omschakeling wacht als de speler erop staat; na laden wordt een veilige positie bepaald. Deze tijdelijke bezettingsuitstelstatus wordt niet apart opgeslagen. Weer is deterministisch uit klimaat, dagnummer en zes vakken van tachtig seconden; de integerhash moet bij een port dezelfde uitkomst houden. Bronnen: `game_state.gd:103–115,299–303`, `daynight.gd`, `tides.gd`, `entities/tide_cove.gd:17–41`.

Er wordt geen complete tilemapdump opgeslagen. De game reconstrueert dezelfde 37 kaarten met hun statische verrijkingen, flags, klok, woning-/erfdata en runtimegevolgen. Minimaal te bewaren varianten:

- Vier combinaties van `lw_drained`/`lw_bridge`, onafhankelijke sluizen en hun zichtbare waterverandering; visplek, oever, brugdek en colliders moeten samen kloppen.
- Vier getijfasen, bezette/vrije zandbank en veilige aankomst; hoge route en veer blijven bruikbaar.
- `lw_mine`, `lw_forest`, `lw_heat_west`, `lw_heat_east`: grondstoffen, mist, paden, verlichting en bijbehorende collider-/minimapverandering.
- Tijholte vóór/na `ad_wheel_done`, vredige/duel-/afgeronde keeperkeuze, verslagen bazen en unieke beloningen.
- Questgates open/dicht, verwijderde of verborgen NPCs, disabled slots en eenmalige triggers.
- Persoonlijk huis, opgeslagen/verplaatste stations, erfuitbreidingen en poortjes, natte/droge kanalen, hergroei, bemesting, lopende/rijpe/opgehaalde productie en honing.
- Dag-/weergedrag, rondlopende NPCs en dynamische herberg-/herstelbewoners, met behoud van hun ankeridentiteit.

De atlas groepeert alle 37 plekken in negentien streken. Binnenlocatie en streek zijn verschillend: een bewezen bezoek aan een kamer mag niet stilzwijgend bezoek aan alle omliggende locaties betekenen. Oude onbekende geschiedenis blijft **onbevestigd**; alleen raw bewijs van werkelijk gebruik, unieke pickup/kist, een unieke statische NPC of expliciete ontmoeting/bossituatie mag kaartbezoek afleiden. Gear, metadata en unlocks bewijzen geen reisroute. Bron: `scripts/core/world_atlas.gd:38–107`.

## De vier nevenbestanden

Alle vier gebruiken Godot `ConfigFile`, zonder eigen versienummer.

| Bestand | Sectie(s) / data | Defaults en behoudsregel |
|---|---|---|
| `meta.cfg` | `[achievements]`, iedere key een achievement-ID | Geen bestand/sectie → leeg. Iedere aanwezige key geldt als behaald, zonder ID-whitelist. Verenigd met save-achievements; nieuw spel wist metadata niet. |
| `ng_plus.cfg` | `[ng] completed,rounds,weapon,hearts,boots,hero_xp,gear_items,equipment` | Defaults `false,0,wood,0,false,0,{}, {}`. XP/gear/selection normaliseren; rounds/hearts alleen cast, onbekend zwaard → wood. |
| `controls.cfg` | `[keyboard]`, `[controller]`; 22 actie-IDs | Geordende arrays van native `InputEvent`-varianten; afwezig gebruikt defaults, leeg betekent ongebonden. |
| `settings.cfg` | `[taal] locale`; `[audio] muted,music,sfx` | Taal: geldige opgeslagen keuze, anders `BLUEMAP_LANG`, anders OS-keuze nl/en. Audio: false/1.0/1.0. |

Bronnen: `game_state.gd:361–372,827–905`, `input_manager.gd:343–396`, `lang.gd:45–63,93–105`, `sound.gd:64–70,131–167`.

NG+ bewaart completed, hoogste afgeronde ronde, sterkste zwaard op schade, maximum hartcontainers/XP, laarzenbezit en verenigd gearbezit. De laatste bewuste gedragen selectie, ook leeg, blijft bestaan. Een NG+-start reset het gewone avontuur, geeft deze bezittingen en 100 munten, zet de ronde en herstelt HP/stamina. Dat is een andere operatie dan een save laden.

Controlwaarden zijn **geen gewone knopnamen of JSON**: `InputEventKey` bewaart onder andere Godots fysieke toetscode, muis/joypad bewaren button-index en joypadbeweging de as plus richting. Profielen behouden maximaal acht alternatieven per actie en hun volgorde. Bij één ongeldige member wordt de betreffende override genegeerd. Afwezige `technique` kiest een vrije V/G/Z of LT/RT/R3; afwezige `homestead` kiest U/O/Z voor keyboard en blijft voor controller leeg. Aanwezig maar ongeldig verschilt van afwezig en expliciet leeg. Vaste `ui_*`/`aim_*` acties worden niet uit dit bestand overschreven. Een toekomstige portable export gebruikt stabiele actie-IDs en expliciete apparaat-/toets-/knop-/asgegevens; Godotcodes mogen niet rechtstreeks als Unitycodes worden geïnterpreteerd. Voer nooit willekeurige `Object(...)`-tekst uit.

Taal ondersteunt `nl/en`; bijvoorbeeld `EN_us` normaliseert naar `en`. Ontbrekende taalkeuze blijft anders dan expliciet Nederlands. Taal en audio delen hetzelfde bestand: beide schrijvers laden eerst de bestaande inhoud zodat een taalwijziging de audio niet wist en omgekeerd. Audioload doet geen expliciete clamp, de UI-setters wel (`0..1`); volumes zijn lineair, niet opgeslagen decibels. Fullscreen/windowgrootte worden hier niet bewaard.

De huidige metadata-schrijvers maken nieuwe ConfigFiles en nemen onbekende secties niet automatisch over; het bronarchief moet ze desondanks bewaren. Settings-schrijvers nemen bestaande andere secties juist wel over.

## Wat bewust niet in de save zit

Stamina blijft tijdens kaartwissels in één `Movement`-object bestaan, maar `stamina`, `regen_delay` en `exhausted` worden niet geschreven; laden, nieuw spel en volledig rusten resetten ze. Vul stamina bij een port daarom niet ineens bij op iedere deurpassage. Verder zijn vijand-HP/-posities, gewone gevallen buit, huidige NPC-loopposities, animatiefases, spelerbeweging, aanval-/rolstatus, crosshair, camera, particles, open dialoog, menutab/scroll/selectie, atlasfocus, actieve controllerinstantie en muziekpositie tijdelijk. Heldenlevel, max-HP, uitrustingsbonussen, weer, getij, waternetwerk en routepaden zijn afgeleid.

Ook de UI-eigenaren, overgangstatus, achievementmeldingsqueue, save-eigenaarschap, actieve arena-run en defeat-handler zijn runtimegegevens. De bestaande game belooft dus geen hervatting van een midden-in-een-aanval- of midden-in-een-menu-moment; fase 1 verzint daar geen nieuwe compatibiliteitsbelofte bij.

## Oorspronkelijke acceptatie-eisen en latere bewijsvoering

De twaalf scenario-ID's `SC01` t/m `SC12` staan machineleesbaar in het JSON-contract. Ze omvatten een synthetische volledige save, oudere saves met ontbrekende versus lege velden, falseflaggedrag, stabiele geopende objecten, gear/NG+, landbouw/productie, alle grondstof-ID-families, alle kaarten/dynamische profielen, metadata, invoerinstellingen, onderbroken/idempotente import en ongeldige/toekomstige data.

Vergelijk een **geïsoleerd door de oude game geladen en opgebouwde referentietoestand** met het toekomstige resultaat; alleen raw JSON-gelijkheid mist huidige normalisatie en de migraties bij kaartopbouw. Vergelijk bovendien de ruwe bronbestanden byte voor byte vóór/na de operatie. Tijdens import worden geen questbeloningen, levelmunten, dubbele drops of autosaves naar de oude map uitgevoerd. Controleer ook echte bediening en bereikbaarheid; gelijke tileaantallen bewijzen geen gelijk spel.

Voor terugkeer zijn er twee afzonderlijke garanties: de ongewijzigde Godot-release met de oude backup bewaart het oude avontuur; behoud van **later in Unity gemaakte voortgang** vereist een bewezen omgekeerde export naar het Godot-contract. Zolang die ontbreekt, is die tweede garantie niet gegeven. Nieuwe Unityvelden zonder Godotrepresentatie moeten expliciet als beperking worden gemeld en ruwe gegevens blijven behouden.

## Uitgevoerde fase-1-controle

Alleen statische broncontrole: de hoofdveldset is automatisch met `save_game()` vergeleken en bevat exact 34 velden, zonder ontbrekende of extra; het contract noemt de 22 configureerbare actie-IDs en alle vijf bestanden. JSON moet gewoon parseerbaar blijven. Er zijn voor dit register geen echte saves gebruikt, geen Godot-/Unity-processen gestart en geen runtimebestanden gewijzigd. Dit beschrijft uitsluitend wat in fase 1 was uitgevoerd. Het latere import-/profielbewijs staat bij fase 9 en de voortgangsuitbreiding bij fase 13; de rondreis via omgekeerde export blijft fase 25.

Fase 16 bewaart bovendien bewonersontmoetingen, wereldherinneringen en de maaltijdvoortgang zonder dubbele beloningen na laden. Automatische proeven gebruiken uitsluitend eigen opslag en starten zonder hoorbaar geluid.
