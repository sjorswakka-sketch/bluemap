# Fase 4 — spelgegevens en vaste IDs

Er is een eigen overdraagbaar gegevenspakket met teruglezer, brongebonden controle, vaste identiteiten en expliciete regelcontracten gebouwd; zie [de formaatafspraken](../DATA_FORMAT.md) en [het manifest](../portable/manifest.json).

- Alle 34 effectieve catalogi met 1.501 vermeldingen en 377 declaratietabellen worden getypeerd overgedragen en volledig teruggelezen, inclusief de oorspronkelijke beschikbare volgorde, bronverwijzingen en onbekende gewone velden.
- 905 registry-objectslots, waaronder tien uitgezette slots, behouden hun index; 213 expliciete resource-IDs, 15 altaarsleutels, palettes, vijf opslagbestanden en 34 save-rootvelden zijn vastgelegd zonder eindindices voor runtime-toevoegingen te verzinnen.
- Alle 33 voorwaarden en 36 acties hebben argument-, volgorde-, default-, bron- en legacycontracten; 1.065 gegevensaanroepen en 2.561 expliciete bron-/doelkoppelingen zijn gecontroleerd zonder gebruiksfouten.
- Vier vaste referentiechecksums en alle 306 scriptbronhashes verankeren de overdracht; de volledige bestaande bronbewaking controleert daarnaast 1.732 originele spelbestanden tegen Git, index en werkboom.
- Twee nieuwe echte Godot-inventarisexports in geverifieerde aparte testopslag kwamen exact overeen met de vaste referentie; de wereld blijft 37 kaarten / 49.758 tegels. [Bewijs](godot-inventory-check.json).
- De migratiesuite bevat nu 139 gerichte tests: codec, grote getallen, typed keys, indexverschuiving, ontbrekende/verborgen data, ongeldige regels, verwijzingen, manifestvervalsing, outputgrenzen en bestaande pakket-/bronchecks. Lokaal slaagden 138 controles; de Windows-host kan geen symlinkfixture maken, daarom voert Linux CI die ene controle uit.

De aparte GitHub-workflow controleert het pakket opnieuw uit de bron en publiceert een eigen gegevensartifact; de permanente pakketbronnen blijven op dezelfde migratiebranch. [Pakketcontrole](portable-data.json).

Deze fase voert de spelregels niet in Unity uit en is geen volledige export van geladen wereldtoestanden of saveconverter. De fase-1-inventaris had gewone dictionaryvelden al gesorteerd en StringName al tot String gemaakt; zulke eerdere informatie wordt niet teruggeraden. De originele bron en expliciete declaratierangorde blijven bewaard voor fase 5.

De bestaande lock_arena-actie heeft geen world-handler; dat staat nu zichtbaar als legacydiagnose in het contract en is niet ongemerkt gewijzigd. Runtime-objecten, getij-/questtoestanden en lw_-resources horen bij fase 5; veilige save-import/terugexport bij fases 9 en 25.

Unity-bouwinputs zijn ongewijzigd, dus de [gecontroleerde fase-3-preview](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase3-preview-95811f4b) blijft geldig; er is voor deze gegevensfase geen nieuwe exe gebouwd. De volledige Godot-game en persoonlijke saves zijn ongewijzigd.

Het volgende **go** start **fase 5: de volledige samengestelde wereld exporteren, inclusief relevante wijzigingen tijdens laden en spelen**.
