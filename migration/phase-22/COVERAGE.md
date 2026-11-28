# Fase 22 — de 86 oorspronkelijke testsuites naast de Unity-port

Dit is een **leeswijzer per onderwerp**. Voor elke Godot-testsuite staat hier in welke migratiefase het onderwerp
van die suite is overgezet en hoe die fase is bewezen. Het is geen bewering dat elke afzonderlijke Godot-controle
opnieuw in Unity is uitgevoerd: de 86 suites zelf blijven ongewijzigd bij de Godot-bron en slagen daar.

- **Godot-opname nagespeeld**: de fase speelt opgenomen gedrag van de echte Godot 4.4.1 exact na in het Unity-model.
- **rechtstreeks overgezet**: de fase is uit de op hash bewaakte bron overgezet en alleen in de Windows-speler gecontroleerd.

| Suite | Fase(s) | Bewijs |
|---|---|---|
| `smoke_test` | [4](../phase-04/README.md), [5](../phase-05/README.md), [7](../phase-07/README.md) | Godot-opname nagespeeld |
| `playthrough_test` | [15](../phase-15/README.md), [22](../phase-22/README.md) | deels opname, deels rechtstreeks |
| `access_points_test` | [11](../phase-11/README.md) | Godot-opname nagespeeld |
| `access_storage_life_test` | [11](../phase-11/README.md), [12](../phase-12/README.md) | Godot-opname nagespeeld |
| `adventure_integration_test` | [15](../phase-15/README.md) | Godot-opname nagespeeld |
| `aim_animation_test` | [8](../phase-08/README.md), [14](../phase-14/README.md) | Godot-opname nagespeeld |
| `arena_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `audio_release_test` | [6](../phase-06/README.md) | Godot-opname nagespeeld |
| `boog_test` | [14](../phase-14/README.md), [20](../phase-20/README.md) | deels opname, deels rechtstreeks |
| `buildings_test` | [6](../phase-06/README.md), [10](../phase-10/README.md) | Godot-opname nagespeeld |
| `character_art_test` | [6](../phase-06/README.md), [13](../phase-13/README.md) | Godot-opname nagespeeld |
| `chest_loot_test` | [12](../phase-12/README.md) | Godot-opname nagespeeld |
| `coast_expedition_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `coast_roundtrip_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `coastal_adventures_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `coastal_combat_test` | [14](../phase-14/README.md), [20](../phase-20/README.md) | deels opname, deels rechtstreeks |
| `coastal_home_test` | [12](../phase-12/README.md), [20](../phase-20/README.md) | deels opname, deels rechtstreeks |
| `coastal_region_test` | [11](../phase-11/README.md), [20](../phase-20/README.md) | deels opname, deels rechtstreeks |
| `coastal_style_prototype_test` | [6](../phase-06/README.md) | Godot-opname nagespeeld |
| `coastal_styles_test` | [6](../phase-06/README.md) | Godot-opname nagespeeld |
| `combat_variety_test` | [14](../phase-14/README.md) | Godot-opname nagespeeld |
| `controls_test` | [8](../phase-08/README.md) | Godot-opname nagespeeld |
| `craft_progression_test` | [17](../phase-17/README.md) | Godot-opname nagespeeld |
| `dagritme_test` | [16](../phase-16/README.md), [21](../phase-21/README.md) | deels opname, deels rechtstreeks |
| `dauwbos_alchemie_test` | [17](../phase-17/README.md) | Godot-opname nagespeeld |
| `dauwbos_route_test` | [11](../phase-11/README.md) | Godot-opname nagespeeld |
| `diepte_test` | [11](../phase-11/README.md), [20](../phase-20/README.md) | deels opname, deels rechtstreeks |
| `doorgangen_test` | [11](../phase-11/README.md) | Godot-opname nagespeeld |
| `dorst_test` | [11](../phase-11/README.md), [14](../phase-14/README.md), [20](../phase-20/README.md) | deels opname, deels rechtstreeks |
| `echo_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `entry_width_test` | [5](../phase-05/README.md), [11](../phase-11/README.md) | Godot-opname nagespeeld |
| `equipment_test` | [13](../phase-13/README.md) | Godot-opname nagespeeld |
| `equipment_ui_test` | [13](../phase-13/README.md) | Godot-opname nagespeeld |
| `first_route_test` | [10](../phase-10/README.md), [16](../phase-16/README.md) | Godot-opname nagespeeld |
| `flower_species_test` | [19](../phase-19/README.md) | Godot-opname nagespeeld |
| `forage_locations_test` | [17](../phase-17/README.md) | Godot-opname nagespeeld |
| `forest_food_species_test` | [19](../phase-19/README.md) | Godot-opname nagespeeld |
| `fountain_test` | [5](../phase-05/README.md), [15](../phase-15/README.md) | Godot-opname nagespeeld |
| `garden_phase1_test` | [19](../phase-19/README.md) | Godot-opname nagespeeld |
| `gebieden_route_test` | [11](../phase-11/README.md) | Godot-opname nagespeeld |
| `habitat_test` | [14](../phase-14/README.md) | Godot-opname nagespeeld |
| `homestead_test` | [18](../phase-18/README.md), [19](../phase-19/README.md) | Godot-opname nagespeeld |
| `ijsdal_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `kruipmoeras_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `lake_supper_test` | [16](../phase-16/README.md) | Godot-opname nagespeeld |
| `living_combat_test` | [14](../phase-14/README.md) | Godot-opname nagespeeld |
| `living_world_test` | [16](../phase-16/README.md) | Godot-opname nagespeeld |
| `loot_resource_test` | [12](../phase-12/README.md) | Godot-opname nagespeeld |
| `meer_test` | [11](../phase-11/README.md), [17](../phase-17/README.md) | Godot-opname nagespeeld |
| `menu_polis_test` | [21](../phase-21/README.md) | rechtstreeks overgezet, controles in de speler |
| `mountain_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `movement_test` | [8](../phase-08/README.md) | Godot-opname nagespeeld |
| `notifications_waterworks_test` | [12](../phase-12/README.md), [20](../phase-20/README.md) | deels opname, deels rechtstreeks |
| `opening_test` | [16](../phase-16/README.md) | Godot-opname nagespeeld |
| `orchard_test` | [19](../phase-19/README.md) | Godot-opname nagespeeld |
| `orchard_ui_test` | [19](../phase-19/README.md) | Godot-opname nagespeeld |
| `personal_home_test` | [18](../phase-18/README.md) | Godot-opname nagespeeld |
| `personal_home_ui_test` | [18](../phase-18/README.md) | Godot-opname nagespeeld |
| `polish_regression_test` | [10](../phase-10/README.md), [21](../phase-21/README.md) | deels opname, deels rechtstreeks |
| `professions_test` | [17](../phase-17/README.md) | Godot-opname nagespeeld |
| `progression_test` | [13](../phase-13/README.md) | Godot-opname nagespeeld |
| `progression_ui_test` | [13](../phase-13/README.md) | Godot-opname nagespeeld |
| `regional_test` | [20](../phase-20/README.md) | rechtstreeks overgezet, controles in de speler |
| `release_ui_test` | [21](../phase-21/README.md), [22](../phase-22/README.md) | rechtstreeks overgezet, controles in de speler |
| `route_width_test` | [5](../phase-05/README.md), [11](../phase-11/README.md) | Godot-opname nagespeeld |
| `samen_test` | [14](../phase-14/README.md), [20](../phase-20/README.md), [21](../phase-21/README.md) | deels opname, deels rechtstreeks |
| `stock_ui_test` | [12](../phase-12/README.md) | Godot-opname nagespeeld |
| `stockroom_test` | [12](../phase-12/README.md) | Godot-opname nagespeeld |
| `taal_test` | [6](../phase-06/README.md), [21](../phase-21/README.md) | deels opname, deels rechtstreeks |
| `tides_test` | [11](../phase-11/README.md), [20](../phase-20/README.md) | deels opname, deels rechtstreeks |
| `ui_navigation_test` | [12](../phase-12/README.md), [13](../phase-13/README.md), [21](../phase-21/README.md) | deels opname, deels rechtstreeks |
| `uiterlijk_test` | [13](../phase-13/README.md) | Godot-opname nagespeeld |
| `vegetation_access_test` | [11](../phase-11/README.md) | Godot-opname nagespeeld |
| `vijanden_test` | [14](../phase-14/README.md) | Godot-opname nagespeeld |
| `visual_upgrade_test` | [6](../phase-06/README.md) | Godot-opname nagespeeld |
| `water_features_test` | [19](../phase-19/README.md) | Godot-opname nagespeeld |
| `wereld_test` | [21](../phase-21/README.md) | rechtstreeks overgezet, controles in de speler |
| `whole_adventure_test` | [15](../phase-15/README.md), [22](../phase-22/README.md) | deels opname, deels rechtstreeks |
| `winter_greens_test` | [19](../phase-19/README.md) | Godot-opname nagespeeld |
| `work_together_test` | [16](../phase-16/README.md) | Godot-opname nagespeeld |
| `workplace_ui_test` | [17](../phase-17/README.md) | Godot-opname nagespeeld |
| `world_atlas_test` | [21](../phase-21/README.md) | rechtstreeks overgezet, controles in de speler |
| `world_memory_test` | [16](../phase-16/README.md) | Godot-opname nagespeeld |
| `world_space_test` | [5](../phase-05/README.md) | Godot-opname nagespeeld |
| `yard_test` | [18](../phase-18/README.md) | Godot-opname nagespeeld |
| `yard_ui_test` | [18](../phase-18/README.md) | Godot-opname nagespeeld |

Totaal: 86 suites; 58 op een Godot-opname, 13 rechtstreeks, 15 gemengd.
