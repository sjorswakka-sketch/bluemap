# Overdraagbare spelgegevens — versie 1

Fase 4 voegt een eigen, engine-onafhankelijk JSON-formaat, een teruglezer, ID-register, verwijzingscontrole en semantische regelcontracten toe. Het pakket is bruikbaar zonder Godot of Unity te starten. Het voert geen scripts, voorwaarden of acties uit; Unity krijgt die spelregels in de daarvoor geplande fases.

## Pakket en herkomst

Het gecontroleerde pakket staat in portable/. manifest.json noemt de vaste Godot-broncommit/tree, drie inputchecksums, de eigen generatorbronnen, scope, aantallen en ieder document met LF-bytegrootte en SHA256. De vier fase-1-referentiedocumenten zijn daarnaast onafhankelijk met vaste checksums verankerd in de bouwer; een gewijzigde beschrijving met een ongewijzigd fingerprint-label wordt dus afgekeurd. Alle 306 oorspronkelijke spelbronnen worden tegen hun vastgelegde LF-hash gecontroleerd.

- header.json bewaart alle overige inhoudsmetadata, modules en bronbestanden; contentRootOrder bewaart de oorspronkelijke volgorde van de inventarisvelden.
- catalogs/ bevat alle 34 effectieve catalogi, inclusief bronverwijzingen en alle onbekende gewone velden.
- declarations/ bevat alle 377 gedeclareerde tabellen in hun oorspronkelijke inventarisvolgorde, in opeenvolgende batches van maximaal 25.
- save-contract.json bewaart het gehele bestaande opslagcontract als data, inclusief onbekende-veldbeleid en bekende loaderafwijkingen.
- identity.json bewaart vaste IDs, bronvolgorde, kaartobjectslots, uitgezette objecten, speciale opslagfamilies, bronnen, palettes en instellingen.
- rules.json bewaart 33 voorwaarden en 36 acties met argumenten, defaults, variadische vormen, modulevolgorde, context, bron-/functiehashes en gevalideerde gebruikslocaties.
- references.json bevat 2.561 expliciete koppelingen met een ondubbelzinnig bronbereik, pad en key/value-selectie.

Alleen deze documentsoorten en veilige relatieve paden worden geaccepteerd. De lezer controleert ontbrekende/extra bestanden, dubbele paden, checksums, canonieke tekst, grootte en symlinks vóór gebruik. De schrijver controleert alle doelpaden vóór de eerste schrijfactie. LF is het overdrachtsformaat; CRLF door een Windows Git-checkout wordt alleen voor deze JSON-tekst genormaliseerd.

De manifestchecksums bewijzen integriteit ten opzichte van dat manifest; de brongebonden controle herbouwt daarnaast alles uit de vertrouwde Git-bronnen en vaste referentiehashes. Een vervalst manifest met vervalste bestanden levert daardoor geen geldig behoudsbewijs op.

## Getypeerde waarden

Het schema heet bluemap.portable.variant.v1; ieder knooppunt is een gewoon JSON-object met precies de onderstaande velden, zonder impliciete conversie.

| kind | Overige velden | Betekenis |
|---|---|---|
| nil | geen | null |
| bool | value: boolean | true of false, nooit een integer |
| int | value: decimale string | Canonieke integertekst, ook boven de veilige JSON/JavaScript-getalgrens |
| float | value: decimale string | Eindige binary64-waarde, kortste roundtriptekst van de referentiebouwer; 1.0 en -0.0 blijven onderscheiden |
| string | value: string | UTF-8, zonder vertaalslag van IDs |
| array | values: knooppuntenlijst | Volgorde blijft gelijk |
| dictionary | entries: lijst van [sleutel, waarde] | Getypeerde string-/integersleutels; geen JSON-object als impliciete dictionary |
| variant | tag: string, fields: lijst van [veldnaam, knooppunt] | Bestaande Godot-typegegevens, inclusief de oorspronkelijke $type-positie |

Voorbeeld: integer 42 wordt {"kind":"int","value":"42"}; de string 42 wordt {"kind":"string","value":"42"}. Een gewone dictionary behoudt daardoor zowel integersleutel 7 als stringsleutel 7. Dictionaries met Vector2i-sleutels gebruiken het bestaande getagde Dictionary met geordende entries; er wordt niets naar tekstsleutels gegokt.

De bekende tags omvatten Vector2/3/4 en integertegenhangers, Rect2/Rect2i, Color, Transform2D, de tien geëxporteerde Packed-arraysoorten en expliciete resourceverwijzingen. Afmetingen, componenttypen en integerbereiken worden gecontroleerd. Een GDScript-pad blijft een bronverwijzing: de lezer laadt of voert het nooit uit. Onbekende tags of schema's geven een zichtbare fout en vereisen een expliciete formaatherziening. Onbekende gewone gegevensvelden blijven behouden.

Begrenzingen: maximaal 64 niveaus, 2 miljoen knooppunten per waarde, 1 miljoen tekens per string, 128 decimalen per integer, maximaal 16 MiB per pakketdocument en 80 MiB per pakket. Dubbele JSON-sleutels, cycli, NaN/infinity, ongeldige Unicode en dubbel getypeerde dictionarysleutels worden afgekeurd. De grenzen beschermen de overdracht en zijn geen capaciteitsschatting voor de uiteindelijke game.

De fase-1-inventaris heeft StringName al tot String gemaakt en gewone dictionaryvelden alfabetisch opgeslagen; het nieuwe formaat beweert die eerdere type-/volgorde-informatie niet terug te kunnen raden. Het bewaart exact wat de referentie bevat; gedeclareerde ids-lijsten bewaren wel de oorspronkelijke tabelvolgorde. De echte exporteur in fase 5 moet de nieuwe expliciete volgorde-/typeafspraken rechtstreeks toepassen op geladen werelddata.

## Identiteit en opslag

Een identiteit bestaat uit een namespace-lijst plus een exacte ID; namen worden niet aan elkaar geplakt met een ambigu scheidingsteken. Hetzelfde item kan dus in de catalogi items en gear voorkomen. Labels en vertalingen worden nooit IDs.

De 905 registry-objectslots behouden index, type en enabled, inclusief tien uitgezette slots. type:map:index blijft een legacy-kandidaatsleutel; de eigen objecthandler bepaalt of die werkelijk wordt opgeslagen. De 213 expliciete beroepsresource-IDs overschrijven waar toepasselijk die generieke sleutel. De 15 altaren behouden altaar_<map>_<x>_<y> en hun eigen scope. Alle 377 declaratietabellen bewaren hun ids-volgorde, ook dictionaries waarvan de eerste geldige waarde als uiterlijkfallback gebruikt wordt.

De vijf opslagbestanden en 34 save-rootvelden blijven afzonderlijk beschreven. Een raw false-vlag wordt door de oude algemene loader via sleutelaanwezigheid true, terwijl de atlas alleen raw boolean true als bewijs gebruikt; beide regels staan afzonderlijk behouden. Native InputEvent-instellingen blijven referentiedata voor latere veilige conversie. Persoonlijke saves zijn niet gebruikt.

Runtime-toevoegingen, lw_-resources, veranderlijke objectlidmaatschappen en de uiteindelijke append-indices worden hier bewust niet als voltooid geregistreerd; finalRuntimeIndicesAssigned is nul. Fase 5 exporteert geladen kaarten en relevante toestanden. Save-import en terugexport blijven fases 9 en 25.

## Voorwaarden, acties en koppelingen

Contracten beschrijven exact de bestaande dispatch: basisregels eerst, daarna de eerste passende module in Content.MODULES-volgorde. Voorwaarden evalueren links naar rechts met kortsluiting; een lege voorwaardenlijst is true, maar een lege individuele voorwaarde is ongeldig. Acties lopen synchroon in volgorde zonder automatische transactie of rollback; signalen kunnen tussendoor toestand veranderen.

De context blijft bepalend: lege achievementvoorwaarden geven geen automatische prestatie, een gate met lege block_if blijft juist dicht, en een trigger zet zijn once-vlag vóór zijn acties. De bestaande lock_arena-actie wordt uitgezonden maar heeft geen handler in world; dit is expliciet als bestaande onbehandelde actie vastgelegd en niet ongemerkt veranderd.

1.065 aanroepen in de effectieve catalogi, declaratietabellen en registry-views zijn op ID, argumenten en zekere namespaceverwijzingen gecontroleerd; overlappende referentieviews tellen afzonderlijk. Onbekende/onjuiste aanroepen blokkeren overdracht. Het oorspronkelijke runtimegedrag bij onbekende regels (waarschuwing + false/no-op) is apart gedocumenteerd, niet stilzwijgend gebruikt als importstrategie.

Voor references.json duidt source.root de catalogus-entry, entry.value, registry-object of post-registry-resourcewaarde aan. Het pad gebruikt /-segmenten met ~0 voor ~ en ~1 voor /. selection=dictionary_key selecteert de laatste sleutel in plaats van de daarbij opgeslagen hoeveelheid. Valuta-operatie coins is onderscheiden van item-IDs en de losse coin-pickup. Alle 2.561 bronselecties én doelnamespaces worden getest. Algoritmisch gegenereerde vlaggen, runtime-objecten en daadwerkelijke beeld-/geluidspaden vallen onder hun latere export-/assetfase.

## Gebruiken en controleren

    python tools/build_migration_data.py --write --report <extern-rapport.json>
    python tools/build_migration_data.py --check --report <extern-rapport.json>
    python -m unittest discover -s tests/migration -p 'test_*.py' -v

--write maakt het pakket opnieuw uit de vaste referentie; --check wijzigt geen pakketbestanden en vergelijkt alle inhoud, typen, volgorde, IDs, handlerbronnen en koppelingen. De automatische GitHub-controles voeren dezelfde brongebonden check uit en bewaren ook een eigen gegevensartifact. De bestaande Unity-Windows-preview blijft de technische fase-3-proef; deze fase wijzigt geen Unity-bouwinputs en vraagt daarom geen nieuwe exe.
