# Opslag, dorpsroutes en rustige natuur — 0.32.1-preview

Deze extra ronde verbruikt geen planfase: productie en verwerking blijft fase 6.

- Alleen de kist binnen op [10,5] gebruikt de bestaande gedeelde huisvoorraad; de oude buitenkist blijft als uitgeschakeld objectslot aanwezig, zodat opgeslagen IDs intact blijven. Voor werk buiten neem je materialen mee; de inhoud wordt niet op afstand verbruikt.
- Controllerselectie houdt de gekozen rij zichtbaar. De rechterstick loopt met herhaling door beide lijsten; links/rechts kiest een lijst. Focus, omschrijving en daadwerkelijk verplaatst voorwerp blijven gelijklopen. Toetsenbord en muis blijven native werken.
- De twee tegels brede zuidweg loopt van het plein langs de voormalige kaartgrens door naar het Zilvermeer. Overloopbare irrigatiekanalen mogen onder het nieuwe pad door; bestaande bewerkte grond blijft bruikbaar. Oude boomwanden en de afgebroken toegang zijn opgeruimd; de werkende beek, oostelijke bruggen, landbouw en tuin blijven beschikbaar.
- Willem staat zichtbaar op [25,12]. Gewone quest-NPCs wandelen rustig binnen 46 pixels van hun anker, stoppen bij een naderende speler en botsen werkelijk met terrein en objecten. De bestaande visser-, bezorg- en tuinroutines en de speciale kattenopdracht blijven behouden.
- Iedere natuurlijke buitenregio en grot heeft rustig wild: zelfgetekende veldhazen, bosvossen, nachtvlinders en strandlopers vullen bestaande woestijn- en moerasdieren aan. Dorpen, haven en bebouwde delen worden vrijgehouden. Gewone dieren geven mest via het bestaande systeem; vlinders en vogels niet.
- Optionele, niet-blokkerende bermplekjes liggen verspreid langs gebiedsverbindingen: kruiden, bloemen, noten, zaden, wortels, fruit en grotzwammen. Ze gebruiken de bestaande werkanimatie, voorraadvrije ruimte, Foraging-XP en opgeslagen hergroeitimer. Geen verplichte quota of dagelijkse onderhoudsplicht.
- Tien waterklassen: rivier, plas, beek, meer, zee, moeras, kanaal, geiser, warmwaterbron en poel. Zoet, zout, brak, stroming en irrigatiegeschiktheid zijn afzonderlijke eigenschappen. De monding is brak; zee, veenwater en mineraalbronnen voeden geen landbouw.
- Natuurlijke vloeibare wateroppervlakken hebben een oneven aantal watertegels, minimaal zeven. Bruggen verbinden hydrologisch dezelfde waterpartij maar tellen zelf niet als water. De bestaande bevroren ijsvlakken en door spelers gegraven halve-tegel-kanalen worden niet automatisch vervormd.
- Ook na droogleggen en brugherstel blijven de moeraspartijen groot genoeg en oneven; losse waterrestjes worden modder. Hoog- en laagwater houden hun bestaande veilige oversteekregels.
- Watervallen liggen aan de bovenkant van hun bassin, met echte bovenbron, rotsranden, mos, watergordijn en spatten. De Bosrand-waterval is van de zuidelijke uitstroom naar de noordelijke bron verplaatst.
- Een kleine geiser ligt in de hete zandsteenbreuk van de Zonnekloof; een warme kwelbron ligt buiten de bebouwing in IJsdal. De geiser heeft een ongevaarlijke uitbarstingscyclus van twaalf seconden; vijftien seconden stil rusten bij de warme bron herstelt één hartje buiten gevecht.
- Nieuwe fauna staat uitsluitend op bereikbare grond buiten het overstromende getijdenpad. De kaartlegenda verdeelt lange labels over twee rijen, zodat ook de haven alle categorieën toont.
- Bescheiden oeverinformatie staat onderaan aan de zijkant; doorgangsmeldingen behouden hun eigen middenpositie.

Eigen pixel art is reproduceerbaar met tools/art_trail_life.py; watercontouren met tools/build_water_layouts.py en de meegeleverde kaartinventaris. Er worden geen externe art-assets toegevoegd.

Validatie: de bestaande volledige speltests plus access_storage_life_test en water_features_test, een aparte savesandbox en native beelden op drie vensterformaten in NL/EN. Definitieve test- en buildresultaten staan in de overdracht bij deze versie.
