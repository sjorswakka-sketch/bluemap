# Woning, tuin en productie — 0.26.0-preview

## Schaal en plaatsing

De bestaande wereld gebruikt tiles van 32 × 32 spelpixels (16 × 16 pixelart op dubbele schaal). Het ongebruikte huis linksonder in Dageraadsdorp houdt daarom zijn bestaande gevel van ongeveer 6 × 4 tiles, in plaats van een grotere gevel over naburige objecten te leggen. De eigen binnenkaart is 14 × 14 tiles, met een vrije woonruimte van ongeveer 10 × 10, een bed, kleed, tafel, boekenkast en tuinvoorraad. Achter het huis staat een zichtbare mesthoop van ongeveer 2 × 2 tiles. De bestaande objecten en hun opslagsleutels blijven behouden.

De dorpskaart groeit van 40 × 28 naar 40 × 44 tiles. De ruime tuin ligt onder de bebouwing. De oude uitgang naar het Zilvermeer blijft exact op dezelfde plaats. De nieuwe beek heeft twee brede bruggen; landbouw is optioneel en voegt geen vijanden of verplichte opdrachten toe.

## Beginnen en bedienen

- Loop door de deur van het huis linksonder. Het bed herstelt hartjes en stamina en slaat je positie op.
- Neem eenmalig gratis de tuinhak, acht druivenpitten en vier bloemenzaden bij het tuinbord voor de woning of de voorraad binnen.
- Raak het blauwe rustpunt voor het huis aan om de woning als normale snelreisbestemming te ontdekken.
- **U**, of **R3 → Y** via Beroepen, opent de tuinstanden. De directe sneltoets is opnieuw in te stellen via Bediening; de tuin blijft ook via de zichtbare knop in Beroepen bereikbaar. Bestaande eigen toetsinstellingen blijven behouden; als U al bezet is, wordt een vrije alternatieve binding gezocht.
- Kies grond bewerken, kanaal graven, druiven planten, bloemen zaaien, bemesten, oogsten of grond herstellen. **E / A vasthouden en lopen** bewerkt opeenvolgende tiles vóór de looprichting, onafhankelijk van het vizier.
- Bestaande personages en werkplekken houden voorrang bij de eerste interactie. Sluiten kan met B/Escape of de tuinstandbinding.
- Rennen is direct beschikbaar via de bestaande sprintbediening: standaard **Ctrl / L3 vasthouden**.
- Het tuinbord kan alle rijpe druiven tegelijk oogsten. Productie accepteert maximaal twintig porties per vat of mesthoop.

De hak bewerkt alleen gewone grasgrond in de eigen tuin (x4–34, y29–40), met uitzondering van de beek, bruggen, het pad en bezette objectplaatsen. Originele routes, muren en andere gebieden blijven beschermd. De twee wijnvaten, mesthoop en bijenkast hebben vaste plaatsen in deze eerste uitvoering.

## Samenhang en tijden

| Onderdeel | Invoer en resultaat | Actieve speeltijd |
| --- | --- | --- |
| Wilde bosdruiven | Drie druiven per pluk; herstel van de struik | 120 s |
| Druivenstok | Eén pit planten, daarna drie druiven per oogst; de stok blijft staan | 90 s met water |
| Meststof | Eén per stok geeft bij de volgende oogst vijf in plaats van drie druiven | Geen extra wachttijd |
| Dierenmest | Bestaande levende wilde dieren laten verzamelbare poep achter, met opgeslagen cooldown | 90 s per dier |
| Compost | Twee dierenpoep worden drie meststof | 30 s per batch |
| Wijn | Drie druiven worden één fles wijn | 90 s per batch |
| Bloemen | Eén zaad groeit tot een blijvend bloeiende plant | 60 s met water |
| Honing | Minstens drie bloeiende bloemen binnen vijf tiles; één honing per cyclus, maximaal acht bewaard | 120 s |

De bestaande wilde dieren zijn onder andere in de Dorstvallei en het Kruipmoeras te vinden. Poep gebruikt dezelfde magnetische oppaklogica als andere buit; dieren hoeven niet gedood te worden. Drie natuurlijke bloemplekken bij de kast bieden een begin. Bebouw je die plekken, dan tellen ze niet langer als bloemen; zelfgekweekte bloeiende bloemen kunnen ze vervangen.

Druiven herstellen één hartje via het bestaande etenmenu. Wijn herstelt 40 stamina; honing herstelt één hartje en 25 stamina. Via Beroepen maak je twee druivenpitten uit één druif en twee bloemenzaden uit één bestaand kruid. Oogsten en productie sluiten aan op bestaande beroeps-XP.

## Water en kanalen

Een bronpoel en geanimeerde waterval voeden een zichtbare dorpsbeek langs de tuin. De rustige Bosrand krijgt een extra poeltje en een waterval bij het bestaande water. De bos- en dorpskaarten zijn afzonderlijke gebieden: de aansluiting vertelt een landschappelijk verhaal, geen simulatie van hoogtes of waterstroming tussen kaarten.

Graaf vanaf een tegel naast natuurlijk water. Kanalen zijn 16 pixels breed, gecentreerd in een tile van 32 pixels. Aangesloten kanalen vullen zich langs vier richtingen; uitbreidingen krijgen meteen water. Water bereikt direct aangrenzende landbouwgrond. Parallelle kanalen met twee rijen gewassen ertussen kunnen grote velden bedienen. Een verbroken toevoer laat de betreffende tak droogvallen; opnieuw aansluiten herstelt de irrigatie. Ook drooggevallen kanalen blijven bestaan.

De kanaaltjes hebben geen botsingsvlak: je loopt en rent er gewoon overheen. Een automatische springanimatie is nog niet toegevoegd. Gewasgroei, rijping, diercooldowns en honing worden opgeslagen; menu's pauzeren de tijd en afgesloten speeltijd levert geen offline opbrengst op. Droge planten verdorren niet. Fertilizer is een bonus, geen verplichte onderhoudsronde.

## Uitbreiden en controle

Gewassen en productierecepten staan in tabellen in scripts/core/homestead.gd. De eerste uitvoering beperkt zich tot druiven, bloemen, compost, wijn en honing. Alle nieuwe voorwerpiconen, werkplek-tekeningen, wateranimaties en het zachte werkgeluid zijn zelf gemaakt. tools/art_x_homestead.py genereert de acht iconen en het geluid reproduceerbaar.

De integratietest tests/homestead_test.gd gebruikt echte invoer, beweging, magnetische buit, de voorraad, werkplekken en opslaan/laden voor de complete keten. tools/run_tests.py gebruikt uitsluitend een gecontroleerde, aparte save-map. tools/preview_homestead.py maakt eigen beelden van dag/nacht, landschap en vijf panelen in Nederlands/Engels op drie vensterformaten. Controllerinvoer is geautomatiseerd gecontroleerd; een fysieke controller is niet met de hand getest.
