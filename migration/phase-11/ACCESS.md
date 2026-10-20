# Phase 11: source-faithful world access

The playable area network uses the existing 37 map IDs and the original 32-pixel tile scale. Its 162 saved-state projections and 59 original scenarios remain immutable source references. No completed fixture state is ever applied to a player profile.

## Runtime contract

`BlueMapMigration.WorldAccess.WorldAccessModel` owns source access conditions, current-state gates, free coastal route eligibility, the earned temple seal, safe arrival preparation/search, legacy world-load migrations and tide occupancy protection. `WorldAccessChecks.Verify(repository, check)` compares those decisions with the original engine.

- Portal requirements come from original `requires`/runtime `conditions`; unknown conditions reject access. Original locked messages remain available.
- Gates evaluate `block_if` against the player's state, keep their original footprints, and consume one original key only while blocked. Flags and inventory commit atomically. An open gate leaves interaction selection and collision together.
- Coastal ferries remain free and preserve HP/items. Only original route membership, map/spawn validity, the source's 64-pixel boarding distance and transition/end guards permit departure. Cancel remains available in the controller presentation.
- The temple seal requires already-earned `game_completed`, proximity below 112 pixels and the original 1.8-second breaking stage. It starts the existing `diepte` quest, advances its original first condition and sets `diepte_opened` once; it invents no quest or reward.
- Restored marsh banks/bridge, thawed paths, the library backroom, mine/forest restoration, coastal wheel crossing and tide bank select their earned source geometry. East-only heating keeps the unearned west terrain unchanged. NPC existence, gate collision and portal eligibility evaluate live state independently of captured visual variants.
- A high/falling tide waits while the player's foot occupies the previously dry bank; leaving it permits flooding. The raised return path and ferries retain their source routes.

## Arrival safety and preservation

Arrival preparation follows the original mountain wind exclusion, fountain rim escape and saved-home furniture clearance. The generic source search samples the nine original terrain foot points, checks source physics bodies, excludes every portal footprint and scans eight rings in the exact original order. Current saved furniture replaces captured fixture furniture, and current blocked gates participate even when a reference shape was initially disabled. The caller rejects a final result that does not fit.

The three original world-load migrations restore consequences already earned by completed legacy quests and normalize the original sluice state. They do not import fixture inventory, complete new quests or award rewards. All 34 save fields and unknown fields remain attached to the same protected Unity play copy; source Godot files and original imported profiles remain unchanged. No offline time advances.

## Original-engine evidence

`world-access-oracle.json` was recorded by `tools/record_migration_world_access.py` in two fresh original Godot 4.4.1 processes within a verified UUID-isolated project. Both processes agree exactly and the original source fingerprint remains unchanged. The runtime JSON copy is byte-identical.

Coverage: **162 loaded worlds, 37 maps, 59 scenarios, 593 safe arrivals, 1,062 spawn probes, 15 behavior cases, 16 original methods, eight search rings, 33 existing quest definitions and 1,584 explicit finite binary64 witnesses**. The behavioral cases include absent/present/repeated keys, bow/weapon/arena locks, valid/distant/forged ferry requests, unearned/earned seal timing, occupied/released tides and repeatable legacy migrations.

Standalone model checks use the actual immutable state/model/repository classes and frozen source documents as a supplemental fast check. The parent native Windows proof additionally traverses actual portals, renders source areas, checks controller interaction and exercises protected persistence; its result is recorded separately in the native package receipt.

## Scope

This phase ports access and world presentation. Full combat, complete quest interaction, storage, professions and production retain their existing data and are scheduled for their respective later migration phases; their locks are preserved rather than bypassed. Captured source scenarios are synthetic test states, not claims that a player completed every route through the current Unity build.
