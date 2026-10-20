# Eerste speelbare route: bestaande verhalen en beloningen

De route verbindt Dageraadsdorp, de eigen woning, de bestaande bosrand en het Fluisterbos. De kaartschaal blijft 32 bronpixels per tegel; plaatsen, doorgangen, opgeslagen objectvlaggen en oorspronkelijke IDs blijven bestaan. Deze fase voegt geen extra nederzettingen, opdrachten of drukke decoratie toe.

## Bestaande kleine verhaallus

Pim kan de speler vragen naar Muis te zoeken; weigeren en later terugkomen blijven mogelijk. Het oorspronkelijke gesprek verwijst naar de pootafdrukken in het zuiden van het bos. Bij Muis praat de speler eerst en blijft vervolgens twee seconden rustig staan. Rennen binnen 105 bronpixels veroorzaakt 2,5 seconden schrik; te ver weg lopen (meer dan 56 pixels) of een snelheid boven 5 onderbreekt het vertrouwen. De renderer en controller verzorgen positie en animatie; het model bewaakt de oorspronkelijke toestand en de beloning.

Na het vinden wordt `cat_found` gezet en gaat de bestaande opdracht `kat` naar stap 1. Terug bij Pim levert het originele gesprek één hartcontainer op, zet `cat_home` en rondt dezelfde opdracht af. De bestaande questbeloning is 40 helden-XP; een overschreden heldenlevel levert volgens de originele drempels 15 munten per niveau. De hartcontainerlimiet blijft drie. Afgeronde verhalen geven bij opnieuw praten geen tweede beloning.

Ook Brams bestaande openingsgesprek en de oorspronkelijke keuze voor de hoofdopdracht kunnen worden gelezen. De hoofdopdracht wordt hierdoor behouden; de overige kerkers en volledige gevechtslus volgen in latere migratiefasen. Gesprekken voeren hun acties pas uit nadat de bijbehorende tekst is gelezen. Sluiten vóór het lezen kent geen ongelezen beloning toe.

## Voorwerpen, verzamelen en uitrusting

De route gebruikt de bestaande losse voorwerpen, kisten en beroepsgrondstoffen. Kisten tellen herhaalde stapels eerst op, controleren alle ruimte vóór uitbetaling en behandelen al bezeten unieke uitrusting als bezit. De andere spullen en munten blijven dan gewoon beschikbaar. De actuele pijlenlimiet is 40. Volle hartjes en volle stapels blijven liggen. Een kristal met een unieke opgeslagen sleutel kan slechts eenmaal worden meegenomen.

Verzamelen behoudt de oorspronkelijke grondstofsoort, hoeveelheid, beroep, XP, gereedschapseis en hersteltijd. De controller verzorgt de korte onderbreekbare werkhandeling; het model herhaalt de controle bij het daadwerkelijk ontvangen van de spullen. Hersteltijd gebruikt uitsluitend opgeslagen actieve speeltijd; rusten, herladen en tijd buiten het spel leveren niets extra op. Een beter gedragen werkpak verkort de werkduur; alleen bezitten geeft geen gedragen bonus. Negatieve snelheidsbonussen blijven geldig.

Rusten vult volgens `GameState.full_rest` de gezondheid en bewegingsenergie aan en vraagt opslag aan. Het slaat geen tijd over. Het oorspronkelijke maximum is vijf plus het aantal hartcontainers; heldenlevels veranderen dit niet.

## Samenhangende toestand en veilige grenzen

Het model werkt rechtstreeks met dezelfde `FoundationGameState` als de route en de aparte Unity-opslag. Alle 34 bekende opslagvelden en onbekende toekomstige velden blijven aanwezig. Alleen de betrokken voortgang verandert; een geïmporteerde inventaris, woning, landbouw of beroepsvoortgang wordt niet opnieuw als nieuw spel aangemaakt. Nieuwe avonturen gebruiken juist het volledige oorspronkelijke `new_game`-resultaat, inclusief de vrijwillige openingsvlag.

Kist- en dialoogbeloningen worden als samenhangende transactie vastgelegd vóór meldingen, zodat een luisteraar geen half bijgewerkte beloning ziet. Een terugkerende melding kan daardoor geen tweede hartcontainer of muntbeloning veroorzaken. Een nog niet overgezette spelactie wordt expliciet gemeld voordat die actie wordt toegepast. Het model doet zelf geen bestandstoegang; opslag en herstel blijven bij de apart gecontroleerde Unity-profielen.

## Broncontrole

`tools/record_migration_route.py` voert de originele Godot 4.4.1-methoden tweemaal uit in verse processen met een geverifieerd UUID-testprofiel. Er worden uitsluitend zelfgemaakte voorbeelden gebruikt; persoonlijke opslag wordt niet gelezen. De oorspronkelijke bestanden worden voor en na afloop vergeleken.

De bevroren referentie bevat 26 spelgevallen: gesprekken accepteren, weigeren en sluiten; Muis kalmeren en verstoren; eenmalige questbeloningen en een heldenlevel; normale kisten, unieke uitrusting en te grote samengestelde stapels; gereedschap, beroepsniveau, actieve hersteltijd en XP-limiet; rusten; munten, volle hartjes, genezing, volle pijlen en een uniek kristal. Vier aanvullende gevallen vergelijken echte gedragen uitrusting, alleen bezeten uitrusting en negatieve snelheid. Getallen die binaire precisie vereisen hebben een apart little-endian IEEE754-getuige.

De native C#-controles voeren hetzelfde geval uit tegen het Unity-model en vergelijken alle 34 resulterende velden en exacte getallen. Aanvullende gevallen controleren onbekende velden, pauze, atomair bijgewerkte beloningen, terugkerende interactie en een fout tijdens een melding. De algemene fasecontrole rapporteert apart de echte kaartovergangen, invoer, presentatie en bewaren/herladen.
