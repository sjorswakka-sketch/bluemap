# Phase 8 movement and stamina

The movement implementation ports `scripts/core/movement.gd`, the motion stages of `scripts/entities/player.gd`, and the original terrain speed/footstep rules. The original Godot files, maps and player saves are unchanged.

## Units and execution

`PlayerMotorModel` uses original pixels with positive Y downward. `MotionInput.Direction` is the already processed input vector, including the original circular deadzone; it is not normalized again for velocity. Body facing normalizes that vector and remains independent of aim. Unity conversion is performed only by the physics adapter, at 32 source pixels per Unity unit. The source foot circle is radius 7 at `(0,8)` pixels.

Call `BeginStep(delta,input)` once, perform actual collision movement with `MotionFrame.VelocityPixels`, then call `CompleteStep(frame,actualDistancePixels,tileAfter)`. The second stage uses actual resolved movement, so running into an obstacle neither drains stamina nor emits steps. A frame cannot be resolved twice or by another model. Physics pauses retain all transient state; input locks suppress walking and stamina updates. `StopForTransition()` stops velocity, knockback and the committed roll while retaining stamina, recovery delay, facing, roll cooldown and the footstep remainder, matching the original method.

## Preserved rules

- Base walking speed is 110 pixels/second. Sprinting is available immediately at 1.5 times ordinary speed.
- Base stamina is 100; sprint drain is 20/second, regeneration 25/second after a 0.8-second delay, and exhaustion clears at 25 percent of the current capacity. A nearly empty bar supplies only its remaining fraction of a sprint step.
- Equipment capacity and regeneration bonuses are injected from the existing normalized resolver. Changing equipment clamps capacity without refilling it. Boots retain their separate 1.18 multiplier, multiplied by `1 + move_speed`.
- Path and yard boards are 1.2 times ordinary speed; mud is 0.88, existing sand types 0.92, and snow 0.95. Other terrain keeps its original speed. All 80 named original tiles, yard boards, outside-map and unknown-future terrain are covered.
- Rolls use 235 pixels/second for 0.3 seconds, a 0.7-second cooldown, and the original strict 0.24-second safety window. A neutral movement stick rolls in the current body-facing direction. The original roll does not consume stamina; this remains unchanged.
- Footsteps occur after 22 pixels of actual walking, with the original remainder and maximum one sound per physics step. Terrain chooses grass/path/sand/wood/cloth/snow/stone; solid or outside-map ground produces no footstep. Volume and randomized pitch are applied by the sound adapter.
- Direction tests use exact zero components, rather than Unity's approximate `Vector2` equality; very small but valid analog input therefore survives.

## Original-engine proof

`tools/record_migration_player_motion.py GODOT --check --evidence-dir NEW_DIRECTORY` creates an isolated project and verifies its exact UUID user-data directory before reading any game methods. It imports with Godot 4.4.1, then records two separate 60-fps engine processes and requires byte-identical canonical output. No personal save is opened. A frame limit ensures a failed script cannot hang indefinitely.

The oracle contains 137 cases: 26 stamina operations, 83 terrain/footstep cases, 8 real equipment combinations, 15 original physics calls, 4 original roll calls and 1 original doorway stop. The equipment combinations include boots, positive/negative speed bonuses, stamina/regen caps, owned-but-unequipped items and invalid unowned selections. Cases cover diagonal/analog input, partial final sprint, exhaustion, input lock, knockback, roll safety boundaries and aiming opposite the walking direction.

Every expected scalar uses original IEEE-754 Float64 bytes, and every vector uses original Float32 XY bytes. Decimal strings or tolerance comparisons are not substitutes. Each vector multiplication retains the original operator order and Float32 storage. Original source hashes normalize only text line endings so Windows and Linux checkouts share the same source identity; the separate before/after source fingerprint remains byte-exact.

The physics oracle calls the original `CharacterBody2D` code with no world colliders and passes its measured actual distance to the C# post-collision stage. Only terrain lookup and unrelated aim/target/shake presentation reads are substituted by an explicit fixture adapter. It does not claim Godot and Box2D collision solvers are identical; the Unity walking preview separately verifies actual circle casts, stopping, wall sliding and blocked sprinting.

`PlayerMotionChecks.Verify` exercises 14 runtime checks, and `VerifyOracle` adds 6 aggregate checks over the original cases. Eight Python tests guard source identities, oracle coverage, byte encodings and the exact Resources copy. Combat damage, attack execution, tool actions and persistent gameplay are later migration phases; their original source/data is retained and no successful placeholder is substituted here.
