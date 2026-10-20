# Alle gebieden en toegangspunten in Unity

Fase 11 breidt de eerste speelroute uit naar **alle 37 bestaande gebieden en interieurs**, met de oorspronkelijke paden, bruggen, ingangen, aankomstpunten, terugroutes en questsloten. De volledige gameport is nog niet afgerond.

De wereld houdt dezelfde kaartmaten en plaatsingen: de bestaande referentie bevat 49.758 tegels. Er worden geen nieuwe gebouwen, gebieden of losse decoraties toegevoegd. Oorspronkelijke tekenfuncties en benoemde wereldtoestanden bouwen voort op de 162 eerder vastgelegde wereldopnamen; de beelden van de eerste route blijven als afzonderlijke referentie behouden.

## Reizen en voortgang

Gebiedsovergangen gebruiken de bestaande doorgangen. Questvoorwaarden en vereiste sleutels blijven van toepassing. De aankomst moet vrij en binnen het juiste gebied zijn; een onbruikbare of onbekende bestemming mag de actieve voortgang niet vervangen. Bij bewaren en opnieuw laden blijven locatie, bezochte gebieden en alle overige behouden opslagvelden onderdeel van hetzelfde afzonderlijke Unity-speelprofiel.

De oorspronkelijke Godot-opslag en het importprofiel blijven behouden. Een geïmporteerd avontuur gebruikt een afzonderlijke speelkopie. De eerste route met Pim en Muis, inventaris, verzamelen, pickups, kisten, rusten en bewaren blijft beschikbaar naast het uitgebreidere reizen.

| Bediening | Toetsenbord | Controller |
|---|---|---|
| Bewegen / richten | WASD of pijlen / muis | Linkerstick / rechterstick |
| Rennen / rollen | Ctrl / Shift of K | L3 / B |
| Gebruiken en praten | E of Enter | A |
| Inventaris / opdrachten | I of Tab / Q | Select / LB |
| Pauzemenu | Esc of P | Start |
| Bewaren / bediening | F5 / F9 | Via het pauzemenu |

## Controles en grenzen

De controles koppelen de oorspronkelijke kaartgegevens, toegangspunten, voorwaarden, kaartadressen en grafische plaatsingen aan de nieuwe Unity-uitvoering. De bronvergelijking gebruikt uitsluitend zelfgemaakte testprofielen onder gecontroleerde tijdelijke UUID-opslag. De bestaande Godot-bron, opgeslagen referenties en eerdere Unity-controles blijven beschikbaar.

Naast de eerdere routebeelden worden acht voorbeelden vastgelegd: Zilvermeer, moeras, Prismamijn, warmwaterberg, haven, bibliotheek, Rietarchief en herberg. Beeld-, bron- en opslagcontroles moeten dezelfde geïdentificeerde Windows-build bevestigen.

**Native Windows-verificatie en publicatie zijn geslaagd.** De echte geïdentificeerde speler slaagt voor 36 algemene controles, 119 spelbasiscontroles, 69 spelercontroles, 115 opslag-/importcontroles, 73 routecontroles en 57 wereld-/toegangscontroles; er zijn geen bouwfouten of bouwwaarschuwingen. De oorspronkelijke Godot-regressie slaagt voor 14 suites en 1,961 controles. De lokale Python-suite bevat 526 tests en 2 overgeslagen Windows-symlinkgevallen; deze blijven actief in Linux CI.

Deze fase sluit gebieden en toegangspunten aan. Volledige gevechten, alle buit- en opslagfuncties, overige gesprekken en opdrachten, uitgebreide bewonersroutines, beroepen, landbouw, productie en bijzondere puzzels worden in hun eigen vervolgfases speelbaar gemaakt. Hun oorspronkelijke spelgegevens en Godot-bron blijven behouden. Een fysieke controller is nog niet met de hand getest.

De nieuwe bronvergelijking omvat 162 oorspronkelijke wereldtoestanden, 15 toegangsscenario's, 593 aankomsten en 1062 botsingsproeven. Naast de ongewijzigde eerste route zijn 3726 oorspronkelijke tekenobjecten uit 158 extra opnamen vastgelegd in 318 native texturen. De twee oorspronkelijke Godot-uitvoeringen gebruiken afzonderlijke tijdelijke testopslag.

De Windows- en Linux-bronproeven gebruiken alle 1584 exacte binaire getalwaarden als referentie. De vergelijking controleert bij de bijbehorende decimale weergaven uitsluitend de twee aantoonbare oorspronkelijke afrondingswijzen; andere verschillen worden afgekeurd. Achttien extra regressietests bewaken onder meer beschadigde getallen, gewijzigde bits, ontbrekende velden en ongeldige afrondingen. De oorspronkelijke wereldgegevens en de geteste spelbuild blijven gelijk.

## Windows-download en herkomst

[Download de fase 11-proef](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase11-preview-0e7d75f8). Broncommit: `0e7d75f8a8c16da4f6a1d3663cea161a4ee57625`; invoerfingerprint: `4f9a2fdd06481c9d62b3d64ea345648062180991b5c12dbda5d0e338af9d425c`. Windows-ZIP: 70,753,879 bytes, 153 bestanden, SHA256 `0998a662bb69602ad34a16bd97f58ba56d44e22d492f1450f9c9aa4851f322ad`. De receipt bindt alle native rapporten en 29 screenshots aan dezelfde bouw. Het pakket is lokaal gebouwd; GitHub controleert bron, oorspronkelijke Godot-regels en de publieke download. De migratiebranch blijft gescheiden van de oorspronkelijke Claude-branch.
