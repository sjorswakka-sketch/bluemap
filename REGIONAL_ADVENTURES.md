# Regionale avonturen — fase 2, 0.12

## Audit en afbakening

De quests waren niet allemaal kopieën. De hoofdroute, lichtpuzzels en eerdere
wereldgevolgen verschilden al. De meeste resterende herhaling zat in bezorgopdrachten
en enkele extra gebieden die vooral een gevecht met een kist waren.

| Gebied | Bestaande spelvorm | Uitkomst fase 2 |
| --- | --- | --- |
| Dorp / Zilvermeer | Fontein herstellen, vissen, netten, koken en samen eten | Behouden; fase 1 vormt de sociale basis. |
| Fluisterbos / Ruïne / Echo-grot | Sporen, voorzichtig naderen, herdenken en luisteren | Behouden; deze route heeft al eigen spelregels. |
| Prismamijn / Dauwbos | Spiegels, kern, lantaarn, bosgedicht en Dauwtuin | Behouden; dit is de ontdekkingsroute. |
| IJsdal / Bergpas | Vuurkorven verdedigen; extra pas met vijanden en kist | Pas krijgt een windoversteek, blijvende klimlijn en weerkaart. |
| Kruipmoeras / Rietarchief | Sluizen en brug; extra archief met vijanden en kist | Archief krijgt reliëfs, chronologie en een tentoonstelling. |
| Dorstvallei | Twee verzamelopdrachten, jacht, oase | Sana's opdracht wordt een waterexpeditie met blijvende aftakking. Jelles jacht blijft een optionele economische bijzaak. |
| Tempel / Diepte / Arena / Resonantie | Hoofdverhaal en gevechtsproeven | Behouden; verdere gevechtsvariatie hoort bij fase 3. |

## Speelroutes

**De bron achter het zand.** Praat met Sana en haal Nours gratis waterzak bij het
blauwe waterpunt naast haar. De opening rechts van de oase in de noordelijke
zandsteenwand leidt naar de Zonnekloof. Volg de slingerende kloof; drie luifels geven
schaduw en gratis water. Elke zes seconden buiten schaduw gebruikt een slok. Met een
lege zak ga je bij de volgende hittepiek terug naar je laatste waterpunt. Geen
schade, verloren materialen of vastgelopen quest. Een optionele zuidelijke nis heeft
proviand; een zijruimte bij de bron heeft materialen. Bij de bron kies je een
drinkplaats voor wild of een rustplek voor reizigers. Sana houdt haar oorspronkelijke
beloning; vijgen worden niet meer ingenomen. De kloof koelt na voltooiing af. Beide
waterkeuzes zijn later om te zetten zonder nieuwe beloning.

**Een lijn door de storm.** Het kamp bij de ingang van de Bergpas leent klimtouw.
Slappe wimpels: zes seconden kalmte. Gele wimpels: twee seconden waarschuwing.
Sneeuwstrepen: twee seconden wind. Langdurige blootstelling op de gemarkeerde
oversteek brengt je naar de dichtstbijzijnde veilige kant. Het touw aan de oostelijke
paal heft deze hindernis blijvend op. De weerkaart ligt in het zuidoostelijke
schuilpunt en gaat terug naar het kamp. Beloning: klimhandschoenen (4% snelheid,
15 stamina, handvak). De oude gevechtsontmoeting, ertsader en kist blijven bereikbaar.

**Wat het water onthield.** De drie reliëfs tonen rietvelden, een aanlegplaats en
hoogwater. De afbeeldingen en teksten bevatten dezelfde aanwijzingen: de palen
bestaan pas na de nederzetting en verdwijnen later onder het hoge water. Aan de
leestafel kies je de chronologie. Fouten kosten niets en geven een inhoudelijke
hint. Na reconstructie kies je vluchtroutes of bewonersverhalen voor Mees' nieuwe
leesplek. Deze keuze is daar ook aanpasbaar. Beloning: archiefkompas (16 oppakbereik,
10% staminaherstel, halsvak). Het eerdere gevecht en de kist blijven bestaan.

## Techniek en behoud

- Nieuwe module, objectsoort en kaartverrijking volgen de bestaande Godot-structuur.
- Nieuwe objecten worden achteraan toegevoegd: kist- en pickup-ID's verschuiven niet.
- Bestaande quest-ID `cactusvijgen` blijft geldig. Voltooide oude saves krijgen de
  herstelde bron en standaard de drinkplaats, zonder opnieuw beloningen. Actieve
  oude saves beginnen bij voorbereiding en behouden hun materialen.
- Een oude opgeslagen positie op het gesloten onderpad in de pas verhuist lokaal
  naar vrije sneeuw. Nieuwe meubels corrigeren een overlappende oude spawn.
- Heat/wind pause with menus. Water supply and heat are forgiving encounter state;
  entering/reloading the gorge starts with a full waterskin. Milestones and choices
  use the existing saved flags.
- Alle pixel art, animaties en geluiden komen uit eigen code. Geen gedownloade assets.
- Nieuwe teksten zijn volledig Nederlands/Engels. Objectnamen en reliëfteksten zijn
  opgenomen in de bestaande extractiecontrole.

## Verificatie

`regional_test.gd` test bereikbaarheid en objectplaatsing, echte invoer voor lopen,
toetsenbord/controllerkeuzes, beide richtingen van de nieuwe doorgang, waterverbruik,
schaduw, herstel bij lege waterzak, wind en touw, aanwijzingen, fout antwoord,
beloningen, herhaalde interacties, uitrusting en save/migratie. De bestaande
woestijntest controleert de gewijzigde missie en behoud van vijgen en oude beloning.
De volledige suite en Windows-build zijn de publicatiecontrole. Visuele beelden
worden apart in de werkruimte bewaard. Controllercontrole gebruikt gesimuleerde
invoer; geen claim over fysieke controllers of alle schermformaten.
