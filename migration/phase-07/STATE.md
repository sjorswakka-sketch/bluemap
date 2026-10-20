# Scene-independent state and rules

The original `scripts/core/game_state.gd`, `daynight.gd`, and player script remain unchanged. This phase supplies explicit, independently owned C# foundations under `BlueMapMigration.Foundation`; it does not claim that the later inventory, quest, farming, combat, save, or UI ports are finished.

## State ownership

`FoundationGameState` holds all 34 source save keys and retains unknown future keys and nested typed values. Immutable snapshots share immutable values; subsequent state mutations do not alter earlier snapshots. A provided source dictionary is preserved rather than repaired or silently filled with new-game defaults. Typed access reports missing or invalid fields. `Snapshot()` is an in-memory data operation, not a save exporter; no personal file is read or written.

The keys are `version`, `map`, `pos`, `hp`, `coins`, `inventory`, `flags`, `quests`, `weapon`, `visited_maps`, `play_time`, `kills`, `meer`, `day_time`, `day_count`, `kills_by`, `rolls`, `potions_drunk`, `deaths`, `boss_deaths`, `talked`, `achievements`, `arena_records`, `homestead`, `coastal_storage`, `stockroom`, `personal_home`, `yard`, `professions`, `hero_xp`, `equipment`, `appearance`, `clothing`, and `ng_plus`.

`InGame`, `Ended`, `Transitioning`, `SpawnName`, `UseLoadPosition`, and UI owners are transient. UI-owner names are a set, matching the source dictionary: opening the same menu twice is idempotent; closing one owner does not close another. Pausing is exactly “at least one UI owner.” Input is locked when ended, transitioning, or paused. `CommitLocation` validates before changing map, position, spawn and load-position policy together. Notifications observe the committed location; listener failures remain visible as `FoundationLocationCommittedException.AlreadyCommitted`.

## Time and events

`FoundationClock.Tick` advances active play time and the 480-second day only while in game, not ended, and not paused. Transitioning alone does not pause time in the original, so the foundation preserves that distinction. A large delta that crosses several days increments the source day counter only once, deliberately preserving the existing `_process` behavior. The world tint, weather, and sleeping rules remain the responsibility of their later systems.

Achievement-check requests continue on their two-second interval while a menu pauses play, as the source autoload uses `PROCESS_MODE_ALWAYS`. Inventory, quest, flag, coin and weapon state changes mark that request dirty; clock writes do not. Homestead receives an active-time notification when its real owner is installed; the foundation does not invent crop-growth results. The clock owns and disposes its subscriptions.

`FoundationEventHub` has typed subscriptions with explicit disposal, queued nested publication, stable callback ordering, and safe removal during dispatch. Subscribers added during a callback begin on the next publication. Disposal stops pending callbacks. One failing listener does not prevent other owners from receiving the event; failures are aggregated and returned to the publisher. This is a main-thread service, not a cross-thread transport.

## Conditions, actions and interaction

All 11 source base conditions are implemented: `flag`, `no_flag`, `quest`, `step`, `has`, `lacks`, `coins`, `map`, `weapon`, `crystals`, and `hurt`. Crystal count counts distinct crystal kinds with a positive count; maximum HP is `5 + heart_container`. `step` also requires an active quest. Empty condition lists are true; malformed containers, unknown conditions and absent extension handlers never become implicit success.

The state-only actions `set_flag`, `clear_flag`, and `coins` actually modify state and publish change events. Coins clamp to zero. Integer overflow is rejected without mutation. Every other action, including inventory grants, quest rewards, audiovisual requests and saves, requires an explicitly registered real owner. A batch retains source sequential execution and stops at an unsupported action; it does not pretend to be a transaction. Quest auto-advance, achievement awards, and item-cap reconciliation are later gameplay owners, not fabricated phase-7 behavior.

Interaction selection follows `player.gd::_update_target`: a strict distance below 40 source pixels, nearest distance without aiming, or distance plus `(1 - aim_direction.dot(direction)) * 16` while aiming; equal scores retain source group order. Vector positions, lengths and dot products retain Godot's Float32 calculations before scalar scoring. A new lock check happens at actual interaction time. NPC dialogue, chests, gates, farming and other entity handlers must register explicitly; the registry cannot silently claim they ran.

## Executable evidence

`FoundationStateChecks.Verify` exercises ownership, unknown-state preservation, Float64 kind/negative zero, pause sets, event reentrancy/disposal/error isolation, day-boundary policy, malformed and unsupported rules, coin overflow, strict interaction range/aim/ties, and atomic location notification failure.

`record_migration_foundation_state.py GODOT --check --evidence-dir OUTSIDE_REPO` starts the pinned original Godot 4.4.1 twice in a verified UUID project and compares the original method results to `state-oracle.json`: 26 condition cases, 9 active/pause/end/transition/day-boundary cases, and 6 original player-targeting cases. `FoundationStateChecks.VerifyOracle` runs those same inputs against C# in the native Windows probe. The wrapper records protected source hashes and verifies source invariance. Public evidence is `receipt.json` and `state-oracle.json`; raw process logs and disposable engine folders are diagnostic only. Personal saves are never used.

All 45 clock input and output Float64 values also carry exact original `PackedFloat64Array.to_byte_array()` bytes as 16 lowercase little-endian hexadecimal digits (`*_bits_le`). These bytes are authoritative for native inputs and bit comparisons; the JSON decimal fields remain human-readable annotations because the original JSON writer can round a computed value. The recorder verifies the endian representation, finite values and strict byte format; C# rejects missing, malformed or non-finite byte values. For the large-delta case, the original day result is `0.8999999999999999` (`ccccccccccccec3f`) even though its JSON decimal annotation is `0.9`. This transport correction adds no gameplay tolerance and changes no clock arithmetic.
