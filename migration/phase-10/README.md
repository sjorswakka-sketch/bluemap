# Eerste speelbare Unity-route

Fase 10 sluit de bestaande basis aan op één doorlopende route: **dorp ↔ woning** en **dorp ↔ bosrand ↔ bos**, inclusief de terugweg; de volledige game is nog niet overgezet.

De oorspronkelijke opdracht van Pim en Muis vormt de eerste speellus: praten, de opdracht aannemen, Muis benaderen, rustig haar vertrouwen winnen, terugkeren en de oorspronkelijke beloning ontvangen. Daarnaast worden verzamelen met gereedschapseisen en afkoeltijden, voorwerpen, kisten, inventaris, opdrachten, thuis rusten, bewaren en opnieuw laden aangesloten.

De route gebruikt dezelfde kaartmaten, paden, doorgangen, gebouwen en objectplaatsingen. Oorspronkelijke tekenfuncties zijn in twee afzonderlijke Godot-uitvoeringen vastgelegd: **104 objecten, 47 gedeelde texturen en vier kaarten**. Terreintegels, personages en interacties blijven afzonderlijke Unity-objecten. Opgeslagen meubels, haar, ogen, kleding en uitrustingslagen bouwen voort op de bestaande grafische catalogi. De wereld krijgt geen extra gebouwen of willekeurig toegevoegde versiering.

## Voortgang en bediening

**Nieuw avontuur** maakt een eigen Unity-profiel; spelen met een geïmporteerd profiel maakt eerst een afzonderlijke speelkopie. Het importprofiel, de oorspronkelijke Godot-bestanden en eerdere bewaarkopieën blijven behouden. De afzonderlijke technische loopproef blijft gescheiden van de opgeslagen speelroute.

| Bediening | Toetsenbord | Controller |
|---|---|---|
| Bewegen / richten | WASD of pijlen / muis | Linkerstick / rechterstick |
| Rennen / rollen | Ctrl / Shift of K | L3 / B |
| Gebruiken en praten | E of Enter | A |
| Inventaris / opdrachten | I of Tab / Q | Select / LB |
| Pauzemenu | Esc of P | Start |
| Bewaren / bediening | F5 / F9 | Via het pauzemenu |

De proef start bij **Avontuur en opslag**. Het pauzemenu biedt bewaren, opnieuw laden en terugkeren naar profielen. Gebiedsovergangen werken tijdens het spelen via de bestaande doorgangen.

## Controle en grenzen

De oorspronkelijke Godot-methoden zijn tweemaal uitgevoerd onder gecontroleerde tijdelijke UUID-testopslag. De referentie bevat **26 spelscenario's en vier uitrustings-/verzameltijdgevallen**, met exacte binaire getallen naast de leesbare JSON-waarden. Daaronder vallen dialoogkeuzes, questbeloningen, Muis' rust en schrik, gereedschappen, afkoeltijden, gedeeltelijk volle stapels, unieke kistinhoud, pickups en rusten zonder tijdsprong. Zie [de spelregels en bronvergelijking](ROUTE.md) en [het broncontract](source-contracts.json).

De beelduitvoer wordt gecontroleerd op oorspronkelijke scripts, kaartadressen, plaatsingen, PNG- en RGBA-hashes. De Unity-controles moeten daarnaast de native uitvoering, echte controllergebeurtenissen, veilige speelkopieën, herstel, bewaren, laden, interacties en oorspronkelijke pixels bevestigen.

**Native Windows-verificatie en publicatie zijn geslaagd.** De echte geïdentificeerde speler slaagt voor 35 algemene controles, 119 spelbasiscontroles, 69 spelercontroles, 115 opslag-/importcontroles en 73 routecontroles; er zijn geen bouwfouten of bouwwaarschuwingen. De oorspronkelijke Godot-regressie slaagt voor 14 suites en 1,961 controles. De lokale Python-suite bevat 472 tests en 2 overgeslagen Windows-symlinkgevallen; deze blijven actief in Linux CI.

Deze fase bewijst de eerste route als geheel. De overige gebieden volgen in fase 11; volledige gevechten, thuisopslag, alle opdrachten, beroepen, landbouw, productie, uitgebreide bewonersroutines en sfeer komen in hun eigen vervolgfases. Hun oorspronkelijke spelgegevens en Godot-bron blijven beschikbaar. Testen, screenshots en publicatie gebruiken uitsluitend zelfgemaakte profielen; persoonlijke bestanden zijn niet geopend. Een fysieke controller is nog niet met de hand getest.

## Windows-download en herkomst

[Download de fase 10-proef](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase10-preview-712b2e02). Broncommit: `712b2e02d0bb5c284bd2b5002d5af77b45ed8c5b`; invoerfingerprint: `94916976ae9ed4f409cd4a8ab768108a69b7f937865617c094b745eac36a9761`. Windows-ZIP: 69,823,776 bytes, 152 bestanden, SHA256 `d87514416dbacb4b89e0ac2195fc14f3d059e597ed0323a5a6e9a9c3f19f5cf8`. De receipt bindt alle native rapporten en 21 screenshots aan deze bouw. Het pakket is lokaal gebouwd; GitHub controleert de bron, oorspronkelijke Godot-regels en publieke download. De migratiebranch blijft gescheiden van de oorspronkelijke Claude-branch.
