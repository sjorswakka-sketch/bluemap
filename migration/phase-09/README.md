# Fase 9 — je opslag veilig meenemen

Deze fase voegt een expliciete kopie-import van bestaande Godot-opslag toe aan de Unity-proef. De oorspronkelijke game blijft beschikbaar. De Windows-proef bevat nog niet de volledige gameplay: die wordt vanaf fase 10 verder aangesloten.

## In de proef

Pagina 9 toont een rustig importpaneel met een bronmap, bestaande Unity-profielen, herstel en instellingen voor taal en geluid. Importeren begint uitsluitend met **Kopie importeren**. Het vooraf ingevulde pad is een suggestie; alleen het tonen ervan opent geen persoonlijke Godot-bestanden. De profielenlijst leest uitsluitend de aparte Unity-opslag.

De speler kan een profiel openen, een vorige bewaarkopie herstellen, Nederlands of Engels kiezen, geluid dempen en muziek/effecten aanpassen. **Bediening aanpassen** opent de bestaande bindingslijst; F9 blijft daarvoor beschikbaar op de importpagina. Toetsenbord, muis en controller volgen dezelfde keuze van het actieve apparaat. D-pad of linkerstick verplaatst de focus, A gebruikt een knop en de rechterstick schuift door de profielenlijst. **Loopproef** brengt de speler terug naar de bewegingsproef.

De vaste teksten en knoppen van dit importpaneel wisselen direct tussen Nederlands en Engels. De algemene opslagstatus en enkele technische foutmeldingen blijven in deze proef nog Nederlands; de volledige menuvertaling volgt bij de latere menuconversie.

Zonder geopend profiel worden voorkeuren tijdelijk toegepast. Met een geopend profiel maakt iedere opgeslagen voorkeur of gewijzigde binding een nieuwe bewaarkopie. De bewegingsproef vervangt het geïmporteerde avontuur niet: rondlopen in de technische proef kan geen oorspronkelijke voortgang, bezittingen of opdrachten overschrijven.

## Afzonderlijke bestanden en bewaarkopieën

De standaard Unity-map is `%LOCALAPPDATA%\BlueMapQuestUnity\Profiles`; de voorgestelde Godot-bronmap is `%APPDATA%\Godot\app_userdata\Bluemap Quest`. Wie een andere Godot-map gebruikt, kan die zelf invullen. Bron en doel moeten afzonderlijke mappen zijn.

De import leest uitsluitend de vijf bekende bestanden wanneer ze aanwezig zijn: `savegame.json`, `settings.cfg`, `controls.cfg`, `meta.cfg` en `ng_plus.cfg`. Er wordt geen mapinhoud verzameld. Alle aangetroffen bronbestanden gaan byte voor byte mee in het Unity-profiel, ook onbekende velden, opmerkingen, oude schrijfwijzen en beschadigde instellingen. De leesbare speltoestand en de bruikbare voorkeuren worden daarnaast apart opgeslagen.

Een bewaarkopie wordt volledig geschreven en teruggelezen voordat de actieve verwijzing verandert. Inhoud, lengtes en hashes worden gecontroleerd. De actieve verwijzing wordt vervolgens atomair vervangen; de oude verwijzing en eerdere bewaarkopieën blijven behouden. Een gelijktijdig gewijzigde opslag, fout tijdens schrijven of afgekeurde import mag de bestaande actieve toestand niet vervangen. Herhaald importeren van exact dezelfde bron reset geen reeds gewijzigde Unity-voorkeuren.

**Vorige versie herstellen** kiest een eerdere geldige kopie van het geopende profiel. Als een beschadigde actieve verwijzing het openen verhindert, kan de speler het profiel selecteren en **Profiel herstellen** gebruiken. Herstel controleert de gekozen kopie voordat de verwijzing wordt aangepast; beschadigde bestanden worden daarbij behouden. Bestandslimieten, beperkte profielnamen en controles op gekoppelde mappen en ongeldige archiefpaden begrenzen de import en opslag.

## Wat wordt overgenomen

De projectie herstelt alle 34 huidige opslagvelden volgens de bestaande laadregels: onder meer locatie, voortgang, inventaris, uitrusting, uiterlijk, beroepen, landbouw, productie, woning, erf en voorraad. Oude opslagversies worden aangevuld waar de oorspronkelijke game dat ook doet. Voorwerpen, uiterlijk en indelingen gebruiken de bestaande catalogi en grenzen. Onbekende toekomstige inhoud blijft in de bronkopie beschikbaar.

Instellingen omvatten taal, audio, fysieke toetsen, modifiers, muisknoppen, controllerknoppen en assen. Expliciet lege of dubbele oude bindingslijsten worden behouden. Nieuwe tuin- en techniektoetsen nemen geen reeds gebruikte oude binding over. Vaste menu- en richtbediening blijft bereikbaar. Globale prestaties en Nieuw spel+ worden zonder nieuwe beloningen of ontgrendelingen overgenomen. Beschadigde voorkeuren krijgen een melding en veilige defaults; een onbruikbare spelopslag wordt geweigerd in plaats van gedeeltelijk geladen.

Zie [de opslagregels en compatibiliteit](SAVES.md) en [instellingen, bediening en ConfigFile](SETTINGS.md) voor de precieze keuzes en grenzen.

## Controle en grens van deze fase

De oorspronkelijke Godot 4.4.1-methoden zijn uitgevoerd in twee verse processen onder een gecontroleerd tijdelijk UUID-testprofiel. De opslagreferentie bevat **24 geldige gevallen en 6 te weigeren corrupte bestanden**; de instellingenreferentie bevat **10 gevallen**. Daaronder vallen oude en nieuwe velden, onbekende gegevens, indelingen, grensgetallen, oude toetsconflicten, modifiers, lege en dubbele bindingslijsten, ontbrekende bestanden en kapotte ConfigFile-tekst. De oorspronkelijke spelbestanden blijven tijdens deze proeven ongewijzigd.

Deze tests gebruiken uitsluitend zelfgemaakte voorbeelden. Er zijn geen persoonlijke saves of instellingen geopend voor ontwikkeling, screenshots of automatische verificatie. De C#-controles vergelijken de referenties en testen daarnaast echte invoergebeurtenissen, schrijven, herstel, integriteit en foutpaden in een aparte testopslag.

**Native Windows-uitvoering en publicatie zijn geslaagd.** De echte speler slaagt voor 33 algemene controles, 119 spelbasiscontroles, 69 spelercontroles en 115 import-/opslagcontroles. Er zijn geen bouwfouten of bouwwaarschuwingen. De aanvullende bestaande Godot-regressie slaagt voor 14 suites met 1.961 controles. De lokale Python-suite heeft 438 tests, waarvan 2 Windows-symlinkgevallen zonder benodigde OS-rechten zijn overgeslagen; deze blijven actief in Linux CI.

Deze fase bewaart en controleert het avontuur, maar zet nog geen volledige quest-, gevechts-, productie- of landbouwlus in Unity aan. Een import heeft geen offline opbrengst of nieuwe beloningen. Het volledig speelbaar aansluiten van de behouden toestand volgt vanaf fase 10; de eerdere Godot-versie blijft daarvoor de referentie.

## Windows-download en herkomst

[Download de fase 9-proef](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase9-preview-343f8564). Broncommit: `343f856435542015ea4d6fb952361ff63d2c9cd9`; invoerfingerprint: `fa72f4701a2ad702599277d4725112ba0459f243699965fa0f383fbeb18d8f07`. Windows-ZIP: 69,685,755 bytes, 151 bestanden, SHA256 `149ae870d14926dd60ddefed94c96da246e32e4decd978a476c5076e6b778e75`. De receipt bindt de native rapporten en 15 screenshots aan deze bouw. Alleen eigen testgegevens en toegestane rapporten zijn gepubliceerd; ruwe logs en testprofielen blijven privé. Een fysieke controller is niet met de hand getest.
