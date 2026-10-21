# Inventaris, buit en opslag in Unity

Fase 12 bouwt voort op de bestaande speelwereld met de oorspronkelijke inventaris, stapels, pickups, kistbeloningen en de gedeelde woning- en kustopslag. De oorspronkelijke Godot-code en persoonlijke opgeslagen spellen blijven behouden. Deze fase is in uitvoering; native verificatie en publicatie volgen na de samenhangende controles.

De tas behoudt de oorspronkelijke stapellimieten per item en heeft geen afzonderlijk maximum voor het aantal verschillende itemsoorten. De woningopslag heeft 144 plaatsen met maximaal 999 per stapel; kustopslag in de kustwerkplaats heeft 12 plaatsen met maximaal 99 materialen per stapel. De bestaande regels bepalen welke items mogen worden opgeslagen en wanneer een opslag dichtbij genoeg is om iets over te zetten. Op afstand blijft de voorraad alleen in te zien.

De bediening krijgt zoeken, categorieën, sortering en favorieten, met zowel toetsenbord en muis als controller. De controllerselectie en de rechterstick moeten de zichtbare lijst blijven volgen. Overzetten en grotere opslaghandelingen worden als één samenhangende wijziging verwerkt; een mislukte handeling mag geen items verliezen of dupliceren.

De broncontrole herhaalt oorspronkelijke Godot-methoden tweemaal met afzonderlijke tijdelijke testopslag. Een apart broncontract bindt de waargenomen item-, buit- en opslagregels aan hun Unity-kopieën en stabiele asset-ID's. Eerdere controles van beelden, speler, opgeslagen voortgang, eerste speelroute en alle gebieden blijven verplicht.

De gecontroleerde Windows-build krijgt vier nieuwe beelden van de tas, woningopslag, kustopslag en controllerbediening. De bronvergelijking, native tests, publieke download en het herstelbare bronarchief moeten dezelfde versie bevestigen voordat deze fase wordt afgerond.

De volledige gameport is nog niet afgerond: verdere gevechten, opdrachten, beroepen, landbouw en productie volgen in hun eigen fasen. Definitieve aantallen en downloadgegevens worden hier pas na succesvolle verificatie toegevoegd.
