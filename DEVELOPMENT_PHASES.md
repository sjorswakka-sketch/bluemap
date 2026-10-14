# Levendige wereld — ontwikkelafspraak

Elke fase levert een speelbare, geteste versie op de branch
`claude/affectionate-mendel-vc1idx`. De gebruiker zegt **go** voor de volgende fase.
Binnen die fase worden ontwerp, eigen assets, implementatie, tests en publicatie zelfstandig
afgemaakt. Een go start alleen de eerstvolgende fase; latere fases worden niet stilzwijgend gestart.
Bij nieuw werk eerst de actuele remote en lokale wijzigingen controleren.

## 1. Dorp en Zilvermeer verbinden — afgerond in 0.11

- Een plek aan tafel: maaltijdmand ophalen met hengel, koken en één portie delen.
- Optioneel nettenpuzzeltje met reservevangst, zonder verplichte grind.
- Joris vist, verzorgt netten en verplaatst zijn vangst; 's avonds blijft hij aanspreekbaar.
- Twee maaltijden met verschillende hartjes/stamina-effecten, drie bereidingsstappen,
  eigen pixel art en geluiden. Annuleren verbruikt geen ingrediënten.
- Eetkamer met botsende meubels en vrije routes; Joris, Bo en Nelle schuiven aan.
- Reacties op Muis, de herstelde fontein en Wilfreds gedenksteen.
- Blijvende tafel, twee recepten, savecompatibiliteit en NL/EN-teksten.
- Acceptatie: route echt doorlopen, bediening met toetsenbord/controller, geen dubbele
  beloningen, koken opnieuw mogelijk wanneer alle porties zijn opgegeten, visuele review.

## 2. Iedere streek een eigen avontuur — afgerond in 0.12

Begin met een audit van de huidige quests en reeds gebouwde wereldgevolgen. Werk de
resterende streken uit rond verschillende spelvormen: ontdekken/omgevingspuzzels,
voorbereiden/expedities en bewoners/herstel/keuzes. Geen kopie van de eerste route.
Maak bestaande grotten herkenbaar en geef uitbreiding een functie in die streek.
Acceptatie: iedere aangepakte streek heeft eigen doelen, herkenningspunten, uitdagingen
en een reden om terug te keren. Bestaande kristal- en hoofdverhaalroutes blijven werken.

Opgeleverd: Zonnekloof met voorbereiding, water en schuilplaatsen; Bergpas met
windritme en een blijvende klimlijn; Rietarchief met beeldonderzoek en een aanpasbare
tentoonstelling. Eigen ingangen, rotswanden, meubels, reliëfs, gerei en geluiden.
De regionale audit staat in REGIONAL_ADVENTURES.md. Sana behoudt haar oude quest-ID;
afgeronde saves krijgen de wereldgevolgen zonder opnieuw XP of spullen te ontvangen.

## 3. Gevechten met meer mogelijkheden — afgerond in 0.13

Wapens krijgen verschillende mogelijkheden en afwegingen. Vijanden reageren op afstand,
geluid, dekking en medestanders. Ontmoetingen combineren dit zonder onleesbare drukte.
Werk animaties, waarschuwingen, raakreacties, stamina en controllerbediening samen uit.
Acceptatie: aanvallen zijn leesbaar en ontwijkbaar, meerdere speelstijlen zijn bruikbaar.

Opgeleverd: drie zwaardtechnieken met verschillende aanloop, bereik, hoek en
staminakosten; voorbereid precisieschot; eigen keiram en doornschutter met vaste
waarschuwingsbanen, dekking, geluidsgevoeligheid en herstelmomenten. Schildwachters
schermen kwetsbare bondgenoten af. Bestaande ontmoetingen variëren zonder extra
drukte; een vrijwillig oefenerf leert de rollen afzonderlijk en gecombineerd.
Eigen pixel-art, animaties en geluiden, NL/EN-hints, aanpasbare V/LT-modifier en
veilige migratie van oude eigen bindings. Details: COMBAT_VARIETY.md.

## 4. Beroepen en uitrusting verbinden — afgerond in 0.14

Materialen, vindplaatsen, ontdekte recepten en beloningen vormen begrijpelijke vooruitgang.
Uitrusting ondersteunt verschillende speelstijlen. Vergelijken, upgraden en vereisten
worden duidelijker. Beperk nutteloze buit en verplicht herhalen van verzamelwerk.
Acceptatie: de speler begrijpt waarvoor hij verzamelt en voelt het voordeel van een vondst.

Opgeleverd: drie te ontdekken werkpatronen en drie gearketens met elk een regionale
verbetering. Techniekstamina, boogvoorbereiding en verzameltijd ondersteunen eigen
speelstijlen. Een opgeslagen materiaaldoel, echte vindplaatsen, gereedschapseisen,
alle gearbonussen en vergelijking van de gedragen set maken keuzes duidelijker.
Paginering houdt gearlijsten vrij van overlap; lokale scrollcoördinaten houden gekozen
recepten zichtbaar wanneer het menu schaalt. Streekerts en hout hebben nieuwe toepassingen;
acht regionale gerechten en elixers zijn nu ook bruikbaar via het menu. Details: CRAFT_PROGRESSION.md.

## 5. De wereld onthoudt je vooruitgang — afgerond in 0.15

Verbind regionale gevolgen aan bewoners, routes, bezoeken en nieuwe ontmoetingen.
Eerder herstelde plekken krijgen blijvend gebruik. Dag, avond en weer ondersteunen dit
zonder tijdsloten die het avontuur blokkeren. Hergebruik de bestaande opgeslagen flags.
Acceptatie: terugkeer toont betekenisvolle veranderingen, ook na opslaan en laden.

Opgeleverd: acht aanspreekbare bewoners met eigen art, werkzaamheden en fysieke
routes in zeven herstelde gebieden. Dag, avond, regen en hitte veranderen activiteiten;
geen gesprek of route is aan een tijdslot gebonden. Bronkeuzes verplaatsen Ravi,
de tentoonstelling en herstel elders veranderen gesprekken. Het reizigersboek in
de herberg wijst op nieuwe ontmoetingen en onthoudt eerdere gesprekken.
Bestaande flags sturen herstel, nieuwe ontmoetingflags gebruiken hetzelfde savebestand.
Details en geteste grenzen: WORLD_MEMORY.md.

## 6. Het avontuur als geheel — wacht op go

Beoordeel de volledige reis vanuit nieuwe én bestaande saves: moeilijkheid, rust,
afwisseling, beloningen, reisafstanden en doelduidelijkheid. Verbeter de samenhang.
Acceptatie: geen doodlopende opdrachten, onredelijke sprongen in moeilijkheid,
visuele blokkades of bedieningsproblemen in de geteste routes.

## Vast bij iedere fase

Eigen gemaakte assets, actuele NL/EN-teksten, bestaande saves behouden, relevante
integratietests plus de verplichte suite, visuele controle en succesvolle Windows-build.
Noteer wat daadwerkelijk is getest en welke beperkingen er zijn; geen claims over
alle resoluties of fysieke controllers zonder die te testen.
Bewaar de historische ROADMAP.md; dit document stuurt de nieuwe ontwikkelronde.
