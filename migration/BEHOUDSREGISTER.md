# Behoudsregister — Unity-migratie

Referentie: **0.34.0-preview**, commit `a8a988be27835dec979d2523a3a85a34385eac54`, boom `73ba02ea4db0a1c920360b6570f5209ccb970143`, Godot **4.4.1 stable**; 32 pixels per wereldtegel, basisvenster 1152×648.

Alle 1.734 bestanden uit die Git-boom zijn met grootte, Git-ID en SHA256 geregistreerd in [source-manifest.json](reference/source-manifest.json), inclusief 244 PNG-bestanden, 138 WAV-bestanden, het SVG-icoon, importinstellingen, 88 Python-hulpmiddelen, 416 GDScript-bestanden, Godot-UIDs, vier scenes, kaartdata, teksten en historische ontwerpdocumenten; er zijn geen eigen fontbestanden in deze bronboom, dus de huidige Godot-fontweergave moet later visueel worden vergeleken.

Het register omvat de complete bewaarde bron, ook code die niet door een catalogus-export wordt aangeroepen; een latere Unity-implementatie mag daardoor geen verborgen spelregels uit runtimecode overslaan.

## Overdrachtsafspraken per systeem

Fase 4 heeft de overdraagbare catalogi, identiteiten en regelcontracten bewezen tegen de vaste referentie; zie [DATA_FORMAT.md](DATA_FORMAT.md) en [fase 4](phase-04/README.md). Fase 5 voegt de werkelijk door Godot geladen wereld toe: [37 kaarten en 162 opnamen](phase-05/README.md), inclusief native botsingen, 59 profielen, uiteindelijke slots en runtime-identiteiten. De daadwerkelijke regels en geladen wereldtoestanden zijn daarmee nog niet in Unity uitgevoerd.

Fase 7 voegt de [uitgevoerde C#-spelbasis](phase-07/README.md) toe: de 221 gegevensdocumenten en alle 162 opnamen laden native met bronhashcontrole; de 34 opslagvelden blijven als ruwe, zelfstandige toestand behouden. Coördinaten, native botsingsparen, basisvoorwaarden, interactiedoelkeuze, klok, gebeurteniseigenaars en atomaire gebiedswissels hebben eigen uitvoeringsbewijs. Gameplay-acties zonder geporteerde eigenaar geven een expliciete ontbrekende-handleruitkomst. Dit vervangt de latere systeemports en saveconversie niet.

Alle onderstaande systemen zijn **als Godot-referentie bewaard**, nog niet als volledige gameplay in Unity gebouwd; de 86 oorspronkelijke suites blijven behouden en nieuwe Unity-tests moeten dezelfde bedoelde gedragsafspraken controleren.

| Onderdeel | Oorspronkelijke bron | Bestaande controles / latere fase |
|---|---|---|
| Samengestelde inhoud en vaste IDs | scripts/data/content.gd, scripts/data/ext/, scripts/data/items.gd, quests.gd, dialogue.gd, npcs.gd, enemies.gd, shops.gd | smoke_test, playthrough_test; fases 4–5 |
| Kaarten, ruimte en routes | scripts/data/*_maps.gd, route_repairs.gd, training_yard_layout.gd; kaartloader en runtimepatches | route_width_test, world_space_test, entry_width_test, doorgangen_test; fases 5, 11 |
| Toegang, sloten en veilig aankomen | scripts/core/access_points.gd | access_points_test, access_storage_life_test; fase 11 |
| Beweging, richting, rennen, stamina en richten | scripts/core/movement.gd, input_manager.gd, scripts/ui/crosshair.gd; speler en vijandruntime | movement_test, controls_test, aim_animation_test; fases 8, 14 |
| Buit, kisten, opslag, meldingen | scripts/core/stockroom.gd, scripts/ui/stock_ui.gd, item_receipts.gd | chest_loot_test, loot_resource_test, stockroom_test, stock_ui_test; fase 12 |
| XP, wapens, uitrusting en uiterlijk | scripts/core/progression.gd, equipment.gd, appearance.gd, character_layers.gd; scripts/data/ext/uitrusting.gd | progression_test, equipment_test, uiterlijk_test, character_art_test; fase 13 |
| Quests, gesprekken en gevolgen | scripts/data/quests.gd, dialogue.gd, ext/; scripts/core/game_state.gd en wereldruntime | playthrough_test, adventure_integration_test, whole_adventure_test; fase 15 |
| Levendige bewoners en herinneringen | scripts/core/npc_roam.gd, living_world.gd, world_memory.gd, opening.gd, first_route.gd, lake_supper.gd | living_world_test, world_memory_test, opening_test, lake_supper_test; fase 16 |
| Zeven beroepen, recepten en economie | scripts/core/professions.gd, craft_identity.gd, craft_journal.gd; scripts/data/ext/beroepen.gd | professions_test, craft_progression_test, workplace_ui_test; fase 17 |
| Woning, inrichting en uitbreidbaar erf | scripts/core/homestead.gd, personal_home.gd, yard.gd; house_catalog.gd, yard_catalog.gd | homestead_test, personal_home_test, yard_test en hun UI-suites; fase 18 |
| Gewassen, soorten, boomgaard, mest | scripts/core/orchard.gd, homestead.gd, forage_catalog.gd; orchard_catalog.gd, flower_species.gd, forest_food_species.gd, winter_greens.gd | garden_phase1_test, orchard_test, flower_species_test, forest_food_species_test, winter_greens_test; fase 19 |
| Water, kanalen, moerassluizen | scripts/core/water_features.gd, marsh_waterworks.gd, water_art.gd; water_layouts.gd | water_features_test, notifications_waterworks_test, vegetation_access_test; fase 20 |
| Wijn, compost, honing en productie | scripts/core/homestead.gd, yard.gd, stockroom.gd | homestead_test, garden_phase1_test, yard_test; fase 21 |
| Regionale avonturen, kust, getijden, arena, gebergte | scripts/core/coastal_*.gd, regional_adventures.gd, tides.gd; scripts/data/ext/ en samengestelde kaarten | coastal_*, coast_*, tides_test, mountain_test, arena_test, diepte_test, kruipmoeras_test; fase 22 |
| Eigen beelden en animatielagen | assets/, scripts/core/character_draw.gd, appearance_draw.gd, art.gd, *_art.gd, pixel_landscape.gd; tools/art*.py, make_art.py | character_art_test, visual_upgrade_test, buildings_test; fases 6, 23 |
| Eigen audio en sfeer | assets/audio/, scripts/core/sound.gd, daynight.gd; tools/audio*.py, make_audio.py | audio_release_test, dagritme_test; fases 6, 23 |
| Wereldatlas, UI, controllerfocus en scrollen | scripts/core/world_atlas.gd, scripts/ui/, scripts/core/ui_style.gd, input_manager.gd | world_atlas_test, ui_navigation_test, stock_ui_test, taal_test; fase 24 |
| NL/EN en alle teksten | scripts/core/lang.gd, translations/, tools/i18n.py, bronstrings in alle scripts | taal_test, tools/i18n.py check; 3.187 Engelse vertalingen op de referentie; fases 6, 24 |
| Saves, prestaties, NG+ en instellingen | scripts/core/game_state.gd, input_manager.gd, lang.gd, sound.gd; [save-contract.json](reference/save-contract.json) | zie [SAVE_COMPATIBILITY.md](SAVE_COMPATIBILITY.md); fases 9, 25 |
| Hele spel, einde en release | project.godot, export_presets.cfg, .github/workflows/build-windows.yml, distribution/LEESMIJ.txt | 86 suites, CRC/PE/x64-pakketcheck; fases 25, 27–28 |

De volledige namen en checksums van alle tests staan in het bronregister, met de geslaagde baseline in [godot-test-baseline.json](reference/godot-test-baseline.json); bovenstaande tabel is een leeswijzer en claimt geen volledige dekking door één geselecteerde test.

## Uitvoeringsbewijs fase 12

[Voorwerpen, buit en opslag](phase-12/README.md) zijn in Unity uitgevoerd en vergeleken: 304 oorspronkelijke gedragsgevallen, alle 226 items en 162 geladen wereldtoestanden; 44 native inventariscontroles voor beloningen, opslag, bediening, herstel en behoud bij herladen. Het [broncontract](phase-12/source-contracts.json) bindt alle sleutels en regels aan de ongewijzigde Godot-referentie. Dit bewijst de inventarisfase; de volledige uitrustingsbediening volgt in fase 13.

## Uitvoeringsbewijs fase 13

[Ervaring, uitrusting en uiterlijk](phase-13/README.md) zijn in Unity uitgevoerd en vergeleken: 442 oorspronkelijke gedragsgevallen, 24 uitrustingsstukken, 90 haarstijlen en 24 kledingstukken; 32 native voortgangscontroles. Het [broncontract](phase-13/source-contracts.json) bewaakt exacte waarden, dictionaryvolgorde, oorspronkelijke upgrades, zichtbare lagen en behoud bij herladen. Gevechten volgen in fase 14.

## Data die later extra aandacht vereist

- Alle 37 werkelijk geladen kaarten en relevante synthetische quest-/wereldtoestanden zijn in fase 5 geëxporteerd; [dekkingsregister](world-coverage.json), [gerichte gevolgen](phase-05/world-witnesses.json) en [uiteindelijke identiteiten](phase-05/runtime-identities.json) bewaken deze referentie. Bewegende frames, combinaties en daadwerkelijke Unity-uitvoering blijven latere fases.
- Objectvolgorde, uitgeschakelde objectslots, indices, oude opslagflags, tilevarianten, voorwaarden en acties blijven herkenbaar; hernummeren mag bestaande voortgang niet verschuiven.
- Alle vijf opslagbestanden blijven afzonderlijk behouden; native Godot-inputevents vragen een expliciete omzetting, en bekende historische loaderafwijkingen worden nu gedocumenteerd zonder ze stilzwijgend te veranderen.
- Echte persoonlijke saves zijn in deze fase niet geopend, gekopieerd of gepubliceerd; veilige import en terugexport moeten nog in fases 9 en 25 worden bewezen.
- Productie en groei volgen bestaande actieve speeltijd; offline groei of andere nieuwe balansregels horen niet automatisch bij de port.
- De wereld behoudt dezelfde kaartoppervlakken, routes en lege ruimte; fase 1 wijzigt geen spelinhoud, terrein, graphics of regels.

## Herhalen en vergelijken

Voer `python tools/freeze_godot_reference.py --check` uit voor alle oorspronkelijke Git-blobs; dit werkt ook na latere commits omdat het de vaste referentieboom leest, zonder het spel of een save te openen.

Het inhoudshulpmiddel `tools/record_migration_inventory.py` gebruikt een tijdelijke projectkopie en gecontroleerde unieke testopslag; zie de eigen helptekst voor export/check-opties.

Het bestaande `tools/run_tests.py` voert Godot-tests eveneens in aparte opslag uit; gebruik het nooit met een handmatig geopende echte spelersave.

## Fase 14 — gevechten, monsters en wilde dieren

De oorspronkelijke wapens, aanvallen, projectielen, vijand- en dierengedragingen, schade en beloningen zijn native uitgevoerd en met beide originele bronoracles vergeleken. 212 spelergevallen en 208 ontmoetingsgevallen behouden exacte getallen, volgorde en alle 34 opslagvelden. Dezelfde 37 kaarten en ruime plaatsingen blijven bestaan; verdere quests en beroepssystemen volgen hun eigen fases. Alle 1.732 originele bestanden en eerdere bewijzen blijven behouden. Zie [fase 14](phase-14/README.md) en [de bewezen Windows-release](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase14-preview-cf27358f).

## Fase 15 — gesprekken, quests en gevolgen

De oorspronkelijke dialogen, NPC-regels, questvoorwaarden, keuzes en gevolgen zijn native uitgevoerd en met 1265 originele brongevallen vergeleken. Exacte getallen, woordenboek- en signaalvolgorde en alle 34 opslagvelden blijven behouden. Dezelfde 37 kaarten, ruime plaatsingen en alle eerdere controles blijven bestaan. Zie [fase 15](phase-15/README.md) en [de bewezen Windows-release](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase15-preview-3a961f2a).
