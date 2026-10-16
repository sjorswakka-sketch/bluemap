# Gewassen en boomgaard — fase 5, 0.32.0-preview

Via **U → Zaden en boomgaard**, of via de tuingids en huisvoorraad, open je het
zaadboek. Het toont echte groeibeelden, benodigde ruimte, waterbereik, opbrengst,
zaadvoorraad en toepassingen. Kies een plantstand en gebruik de bestaande hak,
E/A vasthouden en rijbediening. De eerste acht tuinstanden blijven op hun plek.
Alle rijpe gewassen zijn ook vanuit de bestaande tuingids in één keer te oogsten.

## Zes nieuwe teelten
| Teelt | Eerste groei | Volgende oogst | Oogst / bemest | Gedrag |
| --- | ---: | ---: | ---: | --- |
| Wortels | 70 s | opnieuw planten | 3 / 4 | Oogst geeft één zakje zaad terug |
| Pompoen | 140 s | opnieuw planten | 2 / 3 | Oogst geeft één zakje zaad terug |
| Tuinmunt | 85 s | 65 s | 2 / 3 | Blijvend kruid; volgroeide bloei voedt bijen |
| Rozemarijn | 110 s | 80 s | 2 / 3 | Blijvend kruid; volgroeide bloei voedt bijen |
| Appelboom | 240 s | 150 s | 4 / 6 | Blijvende boom; volwassen kroon na iedere pluk behouden |
| Bosbessenstruik | 130 s | 95 s | 3 / 4 | Lage blijvende struik; dezelfde bosbessen als de wilde planten |

Tijden zijn actieve speeltijd. Menu's pauzeren; droogte pauzeert zonder schade.
Geen seizoensdeadline, bederf of verplichte dagelijkse verzorging. Meststof
verbetert één oogst. De bestaande druiven, bloemen, wijn en compost behouden
hun regels. Ongeplukte bloeiende kruiden tellen mee voor de bestaande bijenkast
op zijn actuele positie; na plukken moeten de kruiden eerst opnieuw bloeien.

## Zaadvoorziening en producten
Bij de bestaande tuingids of de voorraad binnen krijg je een apart eenmalig
beginpakket: twee zaden/stekken van elke groente en kruid, één appelboompje en
één bosbessenstek. Ook oudere saves kunnen dit pakket ophalen. Je oorspronkelijke
gratis hakpakket blijft afzonderlijk bestaan. Extra zaden koop je per één of vijf,
alleen bij die echte voorraadplek. Vanuit het veld kun je wel je plantstand kiezen.

Wortels en appels zijn direct eetbaar via de bestaande voedselbediening. Bosbessen
passen in bestaande recepten. Drie gerichte recepten gebruiken bestaande werkplekken:
tuinstoofpot en honing-muntthee bij de herbergkeuken, rozemarijnbalsem bij Lena's
alchemietafel. De eigen gewassen worden zo verbonden met kruidenzoeken, koken,
alchemie, honing en bestaande voorraad; er komen nog geen nieuwe productiemachines.
Inventaris en recepten noemen de concrete tuin- en zaadbron. Nieuwe recepten sluiten
aan achter de bestaande lijst, zodat de oorspronkelijke startersbijl geselecteerd blijft.

## Ruimte en zichtbaarheid
De 36 kaarten en hun oorspronkelijke objectvolgorde, afmetingen en aankomstpunten
blijven gelijk. Er worden standaard geen velden, bomen, winkels of NPC's toegevoegd.
Je kiest zelf waar je plant binnen de bestaande tuin. Nieuwe teelten houden ook
de zichtbare ruimte rond oorspronkelijke productieplekken vrij; oude druiventeelt blijft compatibel.

Een appelboom heeft drie bij drie tegels vrije kroonruimte nodig, buiten bestaande
routes, gewassen, kanalen en erfwerk. Maximaal twaalf appelbomen; kronen overlappen
elkaar niet. Aangesloten water tot twee tegels van de stam voedt de wortels, zodat
kanalen buiten de kroon kunnen blijven. Alleen de stam botst met de speler; de
kroon wordt zacht doorzichtig als je erachter staat. Erfplaatsing bewaakt dezelfde
boomruimte. Bewust verwijderen met Grond herstellen geeft het boompje terug
en verwijdert stam en kroonruimte; de groeivoortgang gaat daarbij verloren.

Nieuwe pixel art: vijf lage planten met vier groeistadia, een appelboom met aparte
stam/kroon en volwassen hergroei, veertien inventarisiconen op beide bestaande
resoluties en eigen oogstkleuren en klank. Alle assets komen uit tools/art_x_orchard.py.

## Controle en vervolg
Twee nieuwe integratiesuites controleren teelt, echte irrigatie op één/twee tegels,
bemesting, zaadteruggave, hergroei, bijen, recepten, lokale inkoop, herhaalde signalen,
native U/muis/controller, menuformaten, mapwissel, save/load, boomstam en verwijderen.
De volledige bestaande suite blijft verplicht; previews tonen NL/EN op drie maten
en alle groeistadia in een open voorbeeldtuin. Tests gebruiken UUID-testsaves.

De volgende gewone go begint fase 6: productie en verwerking met verdere bestaande
en nieuwe producten, werkplekken en zichtbare wachtrijen.
