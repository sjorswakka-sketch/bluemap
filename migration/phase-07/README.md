# Fase 7 — technische spelbasis

De afzonderlijke Unity-versie krijgt een zelfstandige C#-basis voor gebieden, speltoestand, gebeurtenissen, voorwaarden, interacties en actieve speeltijd. De oorspronkelijke Godot-game, alle bronbestanden, 37 kaarten en 49.758 tegels blijven behouden; er komt geen extra bebouwing of dichtheid bij.

## Wat deze fase verbindt

- Alle 221 documenten uit de bestaande data- en wereldexport blijven verliesvrij beschikbaar: 37 basisgebieden, 59 benoemde scenario's en 162 wereldopnamen. De 335.783.962 oorspronkelijke LF-bronbytes zijn als 6.864.062 gzipbytes verpakt; elk document wordt bij laden begrensd uitgepakt en op oorspronkelijke SHA256 gecontroleerd.
- De eigen decoder bewaart int64, doublebits, negatieve nul, getypte vectoren, rechthoeken, transformaties en geordende dictionarysleutels. Bronwaarden en onbekende spelvelden blijven bewaard; onbekende enginewaardetypes en beschadigde documenten worden zichtbaar geweigerd.
- Gebieden worden eerst volledig voorbereid en gevalideerd. Een onbekend gebied of aankomstpunt vervangt de huidige locatie niet. Bij een geldige wissel blijven speltoestand en speeltijd bestaan en worden de abonnementen van het vorige gebied opgeruimd.
- De 34 oorspronkelijke opslagvelden bestaan als zelfstandige toestand in geheugen. Deze fase importeert, normaliseert of schrijft geen persoonlijke savebestanden.
- De elf basisvoorwaarden uit GameState.check werken in C#; uitbreidingen gebruiken expliciet geregistreerde handlers. De eenvoudige vlag- en muntacties werken. Inventaris, quests, beloningen, save-acties en andere nog niet geporteerde systemen melden dat hun echte handler ontbreekt.
- Interactiedoelen volgen de oorspronkelijke afstandsgrens van 40 pixels, volgorde bij gelijke score en richtingsweging. Dit is de doel- en dispatchbasis; de complete interacties met NPCs, opslag, productie en gevechten volgen met die systemen.
- Eén adapter rekent 32 bronpixels per tegel en de neerwaartse Y-as om naar Unity. Diezelfde omzetting geldt voor aankomsten, tegelmiddens, rechthoeken, pivots, transformaties en botsingsvormen. Oorspronkelijke botsingsbits blijven apart behouden.
- Native botsingen gebruiken expliciete paarregels: Godot laat een paar botsen als ten minste één bronmasker het andere lichaam ziet. Een gelijke Unity include/exclude-prioriteit drukt die regel niet correct uit; de adapter stelt de paarfilters zelf in en wijzigt geen globale projectmatrix.
- De klok bewaart de 480 seconden per dag, actieve speeltijd, afzonderlijke pauze-eigenaren en de oorspronkelijke regels tijdens overgangen en het einde. Er is geen offline-inhaalgroei toegevoegd.

Zie [gebiedsformaat en botsingen](WORLD.md) en [toestand, gebeurtenissen en klok](STATE.md) voor de grenzen van de afzonderlijke onderdelen.

## Bewijs en herhaling

Twee verse oorspronkelijke Godot-processen leveren [dezelfde 26 voorwaarden, negen klokgevallen en zes doelkeuzes](state-oracle.json). De Unity-proef vergelijkt die resultaten met de echte C#-uitvoering; klokwaarden worden op doublebits vergeleken.

```text
python tools/build_migration_foundation.py --check --report <extern-rapport.json>
python tools/record_migration_foundation_state.py <Godot-4.4.1-executable> --check --evidence-dir <nieuwe-lege-externe-map>
python -m unittest discover -s tests/migration -p 'test_*.py' -v
python tools/check_migration.py --check --output <extern-bronrapport.json>
python tools/build_unity_probe.py --editor <Unity-6000.3.26f1/Unity.exe> --output <nieuwe-lege-externe-map>
```

De bouw gebruikt uitsluitend gecommitteerde invoer in een tijdelijke Unity-kopie. De daadwerkelijke Windows-speler controleert de spelbasis, alle 221 bronbestanden, alle 162 opnamen, de oorspronkelijke presentatie en native botsingscontacten. Het pakket krijgt apart herkomstgebonden FOUNDATION-CHECKS.json-bewijs; ontbrekende of mislukte deelcontroles worden geweigerd.

## Zichtbare proef en grens

De preview behoudt de zes presentatiepagina's uit fase 6 en voegt pagina 7 toe: oorspronkelijke terreintegels rond een bestaand aankomstpunt, wisselen tussen de 37 gebieden en de pauzeerbare speeltijd. Objecten en terrein worden niet opnieuw geplaatst of verzonnen. Dit is een terrein- en spelbasiscontrole; de volledige wereldweergave en doorlopende gameplay volgen in de volgende fases.

Toetsen 1–6 kiezen de presentatiepagina's, 7 opent de spelbasis, links/rechts wisselt gebied, P pauzeert en Escape sluit. Volledige spelerbeweging, camera, controllerbediening, veilige save-import en de eerste speelbare route volgen in fases 8–10. De oorspronkelijke volledige game blijft downloadbaar via het vaste Godot-herstelpunt.

## Vastgelegde uitslag

[Het uitvoeringsrapport](verification.json), [alle 119 deelcontroles](native-foundation.json) en [het onafhankelijke bronpakketbewijs](package-source-verification.json) horen bij Windows-bron 66dcb26858ed06455d9252220d2eaacfc8b10d25. De bouw heeft nul fouten en waarschuwingen en doorstaat alle 31 runtimecontroles in 181 frames. De complete Python-set telt 355 tests: lokaal 353 geslaagd en twee Windows-symlinkfixtures overgeslagen; GitHub voert de Linux-set en de oorspronkelijke wereld-/oracleherhalingen opnieuw uit. De drie relevante oorspronkelijke Godot-suites slagen eveneens.

De decimalen van de oorspronkelijke JSON-schrijver konden één berekende klokwaarde afronden. De oracle bewaart daarom ook alle 45 oorspronkelijke Float64-bytewaarden; inputs en uitkomsten worden exact op die bytes vergeleken. Declaratie- en regelmetadata met een gewone kind-sleutel krijgen uitsluitend binnen hun twee gecontroleerde documentschema's een gewone JSON-context; de overige typed transport blijft strikt. Deze correcties wijzigen geen oorspronkelijke spelregels of inhoud.
