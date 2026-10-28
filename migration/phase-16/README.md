# Fase 16 — levendige bewoners

Status: implementatie en bronvergelijkingen gereed; de volledige Windows-proef, beeldcontrole, publicatie en definitieve CI-controle zijn nog in uitvoering.

Deze fase neemt bestaande bewoners en gebeurtenissen over naar Unity: begrensd rondlopen, werk- en rustplaatsen, ontmoetingen en het reizigersboek, de dorpsopening en de gezamenlijke maaltijd bij Mila. De wereld krijgt geen extra locaties of dichtheid; de oorspronkelijke 37 kaarten, 49.758 tegels en 1.732 Godot-bestanden blijven behouden.

## Uitvoering

- Gewone NPC's en kustbewoners wandelen binnen hun oorspronkelijke marge; hun zichtbare lichaam, voetbotsing en aanspreekpunt bewegen samen.
- Nelle en Bo volgen hun oorspronkelijke dag- en avondroutes; herstelde gebieden krijgen hun bestaande geheugenbewoners met passende werktuigen en rustgedrag.
- Ontmoetingen worden opgeslagen en zijn terug te lezen in het reizigersboek.
- De optionele maaltijd bevat de hengelvereiste, onderbreekbaar binnenhalen van de mand, drie geordende netsteken, twee recepten, drie kookstappen en drie avondgasten.
- De bestaande voorwaarden, ingrediënten, opbrengsten, eenmalige beloningen en minimale vis-/kookervaring blijven leidend; het volledige beroepen- en handelsysteem volgt in fase 17.
- Menu's en gesprekken pauzeren de bewoners; een interne kaartverversing bewaart hun lopende route en de bestaande gevechtsobjecten.
- Geautomatiseerde speltests zetten het geluid vóór de eerste spelinitialisatie uit; gewone geluidsvoorkeuren en persoonlijke saves worden niet aangepast.

## Bronbewijs

Twee verse, stille Godot-processen leggen ieder de oorspronkelijke scripts vast. De productiecode vergelijkt 611 bewegingsgevallen en 239 sociale gevallen exact; de sociale opname bevat 24.910 Float64-getuigen, geordende effecten en echte dialoogvertakkingen. Willekeurige keuzes en de door Godot opgeloste botsingsuitkomst zijn expliciete broninvoer: de Unity-fysica wordt niet voorgesteld als een bitexacte vervanging van Godot.

Kleine afzonderlijke spelcatalogi voorkomen dat gewone gameplay de grote controle-opnames hoeft te laden. Het broncontract controleert de opname, oorspronkelijke scripts, runtimecode, `.meta`-identiteiten, kaartcensus en het voorafgaande verhaalcontract.

## Nog te bevestigen in deze fase

De native Windows-proef moet alle bestaande controles en de nieuwe bewonerscontroles afronden, vier nieuwe spelbeelden en keukenlay-outs tonen, een volledig gecontroleerd pakket produceren en de echte GitHub-download opnieuw controleren. Fase 17 start pas na een volgend go.
