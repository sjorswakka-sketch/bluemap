# De wereld onthoudt je vooruitgang — 0.15

Herstelde plekken hadden zichtbare gevolgen, maar teruggekeerde bewoners waren
deels stilstaande kopieën van bestaande quest-NPC's. Nu gebruiken eigen bewoners
die plekken, met gesprekken die huidige keuzes en vooruitgang elders volgen.

| Plek en bestaande herstelvlag | Bewoner en dagelijkse activiteit |
| --- | --- |
| Prismamijn — `lw_mine` | Ivo sorteert erts, loopt langs de rustige lichtkring en controleert zijn pikhouweel. |
| Dauwtuin — `lw_forest` | Tess verzorgt planten; bij regen en in de avond sorteert ze zaden. |
| IJsdal west — `lw_heat_west` | Edda werkt aan wintersoep en blijft bij het warme huis. |
| IJsdal oost — `lw_heat_east` | Wout controleert lampen en vertelt over de open pas. |
| Kruipmoeras — `lw_bridge` | Ada vervoert veenmanden op de oever, naast de brug zodat de oversteek vrij blijft. |
| Dorstvallei — `ra_spring` | Ravi vult kruiken; de wild/caravankeuze bepaalt zijn halte. |
| Rietarchief — `ra_archive_done` | Fien leest beelden en maakt aantekeningen; Mees' tentoonstellingskeuze klinkt in haar verhalen door. |
| Bergpas — `ra_rope` | Cas bindt postbundels en gebruikt het kamp bij de blijvend veilige klimlijn. |

De bewoners herkennen een terugkeer. Verbindingen noemen concreet Greta's
werkplaats, de moerasbrug, Mees' tentoonstelling, de bergpost en Joris' verbeterde
werkpak. Het reizigersboek in de herberg geeft beschikbare ontmoetingen en laat
zien wie je al hebt gesproken. Het boek deelt informatie, geen nieuwe opdrachten.

## Gedrag en opslag

- Herstel gebruikt bestaande vlaggen. De bestaande migratie van afgeronde oude
  quests geldt ook voor de nieuwe bewoners. Ontmoetingen bewaren alleen
  `wm_met_<role>` in het bestaande `flags`-woordenboek. Geen nieuw saveformaat.
- Herhalen geeft geen items of XP. Dag/avond en het bestaande deterministische
  regenweer veranderen routes en werk; gesprekken, planten en doorgangen blijven
  beschikbaar. Hitte laat Ravi overdag rusten. Hij reageert ook zonder kaartreload
  op een gewijzigde bronkeuze.
- AStar-routes blokkeren bestaande vaste objecten, tegelbotsingen, portals,
  bewoners en de speler. Elk pad bouwt het raster opnieuw zonder oude reserveringen.
  De bewoners hebben voetbotsingen en y-sortering. Alleen een echt menu/gesprek
  stopt het werk; het vizier op een bewoner richten doet dat niet.
- De stilstaande Fenna/Roos-kopieën en Stien-kopie op de brug zijn vervangen.
  De echte quest-NPC's, kaartobjecten, kist-ID's en quests blijven aanwezig.
- Acht eigen 2-frame personages, negen gerei-iconen, een 2-frame boek en
  een zelf gesynthetiseerd paginageluid komen uit `tools/art_x_memory.py`.
  Geen externe art of audio. NL/EN-teksten zijn bijgewerkt.

## Controle

`world_memory_test` controleert verschijnen na herstel, bereikbaarheid van alle
werk- en rustplekken vanaf de kaartingang, fysiek wandelen, niet stapelen met
quest-NPC's, beide bedieningstypen, werkpauze bij een gesprek, regen/avond/hitte,
bron- en tentoonstellingskeuzes, herhaalde refresh, het reizigersboek, oude
afgeronde quests en echt opslaan/laden/nieuw spel. Een regressiecontrole voorkomt
blijvende reserveringen nadat de speler een bestemming heeft verlaten.

Daarnaast draaien de volledige bestaande testset en de Windows-export in CI.
Beelden van alle bewoners, IJsdal vóór/na herstel, avond, beide bronkeuzes en het
Nederlandse/Engelse boek zijn gecontroleerd op 1152×648. Controllerinput is
gesimuleerd; een fysieke controller en alle mogelijke resoluties zijn niet getest.
