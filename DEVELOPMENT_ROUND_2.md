# Ruimte, rust en betekenis — tweede ontwikkelronde

Plan van 14 oktober 2026. Basis: 0.16.0-preview, commit
`efe71193c68ae279b99969c94eed50141c2bb00c` op
`claude/affectionate-mendel-vc1idx`. Alle zes fases uit DEVELOPMENT_PHASES.md
zijn afgerond. Op verzoek aangepast: de kleine wereld eerst meer ademruimte
geven; daarna bestaande plekken verdiepen. Fase 1 is uitgevoerd in 0.17 en
fase 2 in 0.18 en fase 3 in 0.19. Overige fases wachten op een volgend go.

## Beste volgende stap

De game heeft nu eigen streekavonturen, zeven beroepen, verschillende
gevechtsmogelijkheden, gearketens, bewegende bewoners en een duidelijke reisroute.
De nieuwe bewoners gebruiken herstelde plekken, maar hun werkzaamheden zijn
vooral sfeer en gesprekken. Meer interactie kan dat verbeteren, maar nieuwe
ontmoetingen op al drukke routes zouden de kleine wereld overvol maken.
De volgende stap is daarom ruimte en reisritme beoordelen en gericht verbeteren.

Begin bij dorp, Fluisterbos en Zilvermeer: vrije overgangen, rustige stukken
en optionele zijpaden. Breid gericht uit waar een overgang ontbreekt. Wandelruimte,
natuur, uitzicht en geluid hebben waarde zonder een opdracht of beloning.
De twee voorgestelde nieuwe ontmoetingen uit het vorige plan vervallen.

## Ruimte blijft leidend in alle fases

- Hoofdroutes houden rustige stukken; geen telkens terugkerende gebeurtenisgenerator.
- Verdiep bestaande bewoners op hun huidige werkplekken. Introduceer geen nieuwe
  NPC-groep om dezelfde functie opnieuw te vervullen.
- Nieuwe vijanden vervangen een deel van bestaande vijanden; de opgeschoonde
  eerste route wordt niet weer voller gemaakt.
- Nieuwe avonturen krijgen herkenbare, optionele zijpaden buiten de hoofdroute.
- Uitbreiding krijgt een landschappelijke functie en een korte, leesbare route;
  vermijd lange verplichte omwegen en lege extra reistijd.
- Controleer iedere fase tegen de rustigere basis uit fase 1, inclusief druk
  door waarschuwingen, iconen, geluid en UI. Content vervalt als de plek geen ruimte heeft.

## Werkwijze bij go

- Eén **go** start alleen de eerstvolgende niet afgeronde fase.
- Binnen die fase worden ontwerp, eigen art/audio, implementatie, controle,
  documentatie en push zelfstandig afgemaakt. Routinekeuzes vragen geen nieuw go.
- Eerst actuele remote en lokale wijzigingen vergelijken. Werk van Claude
  behouden en eventuele conflicten oplossen voordat de fase wordt gepubliceerd.
- Elke fase levert een speelbare versie op de Claude-branch. Na controles en
  succesvolle Windows-CI volgen een korte samenvatting, getest bereik en download.
- Werkelijke bevindingen mogen het ontwerp verfijnen. Een wezenlijk andere
  richting of extra fase wordt eerst als gewijzigd plan voorgelegd.
- Dit plan krijgt per fase status en bewijs. Na fase 6 volgt eerst een nieuwe
  beoordeling; een los go begint dan geen onaangekondigde ontwikkelronde.

## 1. De wereld krijgt ademruimte — uitgevoerd in 0.17

Audit bestaande kaartoppervlakken, activiteiten, vijandplaatsing en belangrijke
looproutes. Onderscheid rustige plekken van gevechtsroutes; totale objectaantallen
zijn slechts een signaal, geen bewijs dat iedere kaart te druk is.

Verbeter de drukste overgang van het dorp naar het Fluisterbos. Ontwerprichting:
een korte rustige bosrand, een minder dicht bezette westelijke bosroute en vrije
aankomst- en rustplekken. Behoud de rustige inrichting van het Zilvermeer.
Voeg geen ontmoetingen, quests, beloningskisten of extra bewoners toe.
Bewaar opslag-ID's, oude posities en de bereikbaarheid van bestaande doelen.

**Klaar wanneer:** de geteste eerste route meer aaneengesloten ademruimte heeft,
gevechten verderop behouden blijven en er geen nieuwe verplichte activiteit is.
Controleer echt lopen, heen/terug-portals, routeaanwijzingen, oude saves, rustplekken,
dag/nacht/weer en de visuele overgang. Documenteer metingen en grenzen.

Opgeleverd: korte Bosrand met weide, boszoom, vijver en wegwijzers; 11,2 s
gemeten padwandeling. Acht van de 26 bosvijandplekken uitgedund, eerste hinderlaag
opzij, oefeningang verder op zijn zijpad, dubbel aankomstbord weg en Elke naast
de dorpsstraat. Gewoon rondzwerven blijft bij de beginplek; gewone slijmen
keren terug als ze te ver worden weggelokt. Het meer behoudt zijn indeling.
Bestaande objectslots en opgeslagen posities blijven bruikbaar; doelen volgen
de nieuwe verbinding. Geen nieuwe quests, bewoners of beloningen.
Details en controle: [WORLD_SPACE.md](WORLD_SPACE.md).

## 2. Bewoners laten je meewerken — uitgevoerd in 0.18

Hooguit twee korte activiteiten bij bestaande werkplekken, gekozen na beoordeling
van fase 1: een reparatie met Greta en een kruiden- of keukenhandeling met
Lena, Tess of Edda. Elke activiteit heeft een andere handeling en feedback. Beroepsniveau en
gereedschap krijgen een begrijpelijke rol; ontbrekende eisen worden vooraf
getoond, zonder al verbruikte ingrediënten bij annuleren.

Gebruik de bestaande zeven beroepen en recepten. Een eerste samenwerking
kan een bruikbaar patroon of werkoptie openen. Vermijd dagelijkse afvinklijsten,
een nieuw valuta- of reputatiesysteem en onbeperkt XP door dezelfde klik.

**Klaar wanneer:** de gekozen activiteiten werken met beide invoermethoden,
de speler het resultaat fysiek ziet en de beloning begrijpt. Kosten, afbreken,
herhalen, save/load en bestaande craftregels zijn gecontroleerd.

Opgeleverd: Greta's werkbankklem afstellen en Lena's kruiden sorteren/mengen,
via hun bestaande gesprekken en binnenruimtes. Eerste klemherstel blijft zichtbaar
en geeft eenmaal 6 Smeden-XP en het bestaande slagbandenpatroon. Lena gebruikt
het gewone drankje-recept, met kosten pas bij bottelen; haar eerste echte
bereiding leert het bestaande richtlenspatroon en verandert haar doseerrek.
Gratis oefenen geeft geen extra buit/XP. Kleine props op vaste toonbanken,
geen nieuwe NPC's, opdrachten, colliders of buitenroute-activiteiten.
Oudere/latere saves, invoer, annuleren en meldingen worden gecontroleerd.
Details: [WORK_TOGETHER.md](WORK_TOGETHER.md). Fase 3 volgt hieronder.

## 3. Monsters horen bij hun omgeving — uitgevoerd in 0.19

Twee nieuwe vijanden met eigen gedrag en assets. Ontwerprichting:
een wortelwaker die aangekondigde grondstroken beheerst, en een schemermot
die op licht reageert en kan worden weggeleid. Licht blijft bruikbaar voor
normaal verkennen; ontwijken en vechten blijven alternatieven.

Plaats ze in geschikte bestaande gebieden en vervang enkele generieke vijanden.
De totale vijanddruk op de eerste route mag niet hoger worden dan na fase 1. Territorium, reactie op
omgeving en herstel na een aanval maken ontmoetingen leesbaar. De bestaande
technieken, boog en rol moeten aantoonbaar verschillende kansen bieden.

**Klaar wanneer:** beide vijanden om een andere aanpak vragen, waarschuwingen
met echte schadegebieden overeenkomen en muren, rustige haltes en aankomstpunten
veilig blijven. Controleer solo én samen met bestaande vijanden.

Opgeleverd: twee stationaire Wortelwakers op bestaande slijmplekken in het bos
en twee door fakkels afleidbare Schemermotten op bestaande vleermuisplekken van
de oostelijke grot. Vaste grondwaarschuwingen, lange herstelmomenten, dekking,
territorium en veilige aankomst-/altaarzones. Technieken openen bast; gewone
pijlen werken tijdens herstel. Eigen animaties en geluiden, bestaande opslag.
De achttien bosplekken, uitgedunde plekken en stille luisterroute behouden.
Geen nieuwe vijandplekken, quests, doorgangen of markers.
Details: [HABITAT_ENCOUNTERS.md](HABITAT_ENCOUNTERS.md).

## 4. Twee optionele grotuitstapjes — volgende fase

Ontwerp twee compacte zijruimtes bij bestaande gebieden, elk met eigen
silhouetten, geluiden en spelvorm. Ontwerprichting: een verlaten mijnkamer
waar dekking en aangekondigd vallend gesteente de route bepalen; een watergrot
bij het moeras waar waterhoogte meerdere veilige routes opent.

Controleer eerst de ruimte voor hun ingangen en routefunctie. Bouw alleen
wat daar daadwerkelijk past; een tweede ruimte mag vervallen bij overlap.
Eén krijgt een korte eindontmoeting die het terrein gebruikt.
De andere draait om onderzoek en een omgevingspuzzel. Gebruik de nieuwe
vijandmechanieken waar ze passen. Geen gekopieerde klankschalen of spiegelvolgorde.
Beloningen ondersteunen een speelstijl of openen een handige optie; de hoofdroute
blijft zonder deze uitstapjes af te maken.

**Klaar wanneer:** de gebouwde uitstapjes een eigen ritme hebben, een begrijpelijke
ingang en uitgang bieden, geen speler kunnen opsluiten en hun beloning slechts
eenmaal geven. Grotlicht, gevechtsruimte en waarschuwingen zijn visueel gecontroleerd.

## 5. Je hulp reist verder

Twee concrete verbindingen tussen bestaande bewoners en gebieden:
Tess/Ada met kruiden voor Edda's keuken, en Wout/Cas met een verlichte posthalte.
Laat bestaande herstelkeuzes bepalen welke samenwerking beschikbaar is.
De speler helpt met een kleine lokale actie; resultaat verandert een werkplek,
beschikbare activiteit of herkenbare routevoorziening in het andere gebied.

NPC's tonen hun werk en verwijzen naar het echte resultaat. Geen lange
verplichte escortes of volledige economische simulatie. Reeds voltooide
hoofdstappen blijven voltooid; nieuwe hulp is optioneel en oude saves krijgen
geen fictieve extra afrondingsbeloningen.

**Klaar wanneer:** beide verbindingen een speelbaar en zichtbaar gevolg aan
beide uiteinden hebben. Verschillende volgordes van herstel, bestaande keuzes,
terugkeer en save/load leveren consistente situaties op.

## 6. De wereld laten ademen

Loop de reis opnieuw door vanuit een nieuw spel en representatieve gevorderde
saves. Beoordeel hoe vaak ontmoetingen optreden, hoeveel rustige wandelruimte
overblijft, reisafstanden, uitleg, beloningen, materiaalgebruik en gevechtsdruk.
Pas frequentie en plaatsing aan op bevindingen. Verbind de nieuwe uitstapjes
aan bestaande route- en voorbereidingsuitleg waar dat nodig is.

Controleer dag/avond/weer, y-sortering, voetbotsingen, licht, geluid, drukke
werkplekken en UI. Meet prestaties bij de drukste geteste scènes en voorkom
onnodige verwerking van niet actieve ontmoetingen. Noteer werkelijk aangetroffen
problemen en bewijs van herstel; geen nieuwe content toevoegen om de fase te vullen.

**Klaar wanneer:** een geteste nieuwe-spelroute en gevorderde terugkeerroute
geen doodlopende nieuwe stappen, dubbele beloningen of zichtbare blokkades
hebben; regressiesuite en Windows-build slagen. Beperkingen blijven expliciet.

## Vast kwaliteitsniveau

Eigen gemaakte en reproduceerbare art, animaties en geluiden; NL/EN bijgewerkt.
Nieuwe bediening sluit aan op bestaande toetsinstellingen, controllerfocus en
wisselen van invoermethode. Tests gebruiken geïsoleerde saves, nooit het echte
spelersbestand. Test de relevante toestanden en de verplichte regressiesuite.

Visueel controleren op minimaal 1152×648, 960×540 en 1600×900: geen tekst buiten
panelen, begraven waarschuwingen, gestapelde voeten of geblokkeerde doorgangen
in de geteste scènes. Bestaande saves en bestaande quests blijven bruikbaar.
Geen claims over fysieke controllers of alle resoluties zonder die te testen.

Publiceer op `claude/affectionate-mendel-vc1idx`, zonder force-push. Behoud de
historische ROADMAP.md en DEVELOPMENT_PHASES.md. Dit aangepaste plan is bij
de eerste uitvoeringsfase opgenomen in de repository.
