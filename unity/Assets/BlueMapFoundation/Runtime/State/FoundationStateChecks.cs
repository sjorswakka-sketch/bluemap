using System;
using System.Collections.Generic;

namespace BlueMapMigration.Foundation
{
    public static class FoundationStateChecks
    {
        public static void Verify(Action<string, bool> check)
        {
            if (check == null) throw new ArgumentNullException(nameof(check));
            var state = new FoundationGameState();
            check("foundation_state_all_34_save_fields", state.Fields.Count == 34 && FoundationGameState.SaveKeys.Count == 34);
            check("foundation_state_new_game_defaults", state.MapId == "village" && state.Weapon == "wood" && state.Hp == 5 && state.DayTime == .15 && state.Flag("op_new_adventure"));
            state.PlayTime = 1.0; state.DayTime = BitConverter.Int64BitsToDouble(Int64.MinValue);
            check("foundation_state_float_kind_and_negative_zero", state.Get("play_time").Kind == "float" && state.Get("day_time").Kind == "float" && state.Get("day_time").DoubleBits == 0x8000000000000000UL);
            state.PlayTime = 0; state.DayTime = .15;
            var snapshot = state.Snapshot();
            state.MapId = "forest";
            check("foundation_state_snapshot_immutable", snapshot.Require("map").AsString() == "village");
            var future = FoundationJson.Parse("{\"map\":\"future\",\"future\":{\"large\":9223372036854775807,\"data\":[1,\"a\",false]}}");
            var retained = new FoundationGameState(future).Snapshot();
            check("foundation_state_unknown_fields_lossless", retained.Require("future").CanonicalJson == future.Require("future").CanonicalJson);
            check("foundation_state_partial_source_not_filled", !new FoundationGameState(future).Fields.ContainsKey("coins"));
            bool scalarRejected = false; try { new FoundationGameState(FoundationJson.Parse("3")); } catch (FormatException) { scalarRejected = true; }
            check("foundation_state_non_dictionary_rejected", scalarRejected);
            int pauseEvents = 0; state.Events.Subscribe<FoundationPauseChanged>(_ => pauseEvents++);
            state.SetUi("inventory", true); state.SetUi("inventory", true); state.SetUi("dialogue", true); state.SetUi("inventory", false);
            check("foundation_ui_owners_independent", state.Paused && state.InputLocked && state.UiOwners.Count == 1 && pauseEvents == 1);
            state.SetUi("dialogue", false); state.SetUi("missing", false);
            check("foundation_ui_idempotent_and_resume", !state.Paused && !state.InputLocked && pauseEvents == 2);
            state.Transitioning = true;
            check("foundation_transition_locks_input_without_pause", state.InputLocked && !state.Paused);
            state.Transitioning = false; state.Ended = true;
            check("foundation_ending_locks_input", state.InputLocked);
            state.Ended = false;
            VerifyHub(check);
            VerifyClock(check);
            VerifyRules(check);
            VerifyInteractions(check);
            VerifyCommit(check);
        }
        private static void VerifyHub(Action<string, bool> check)
        {
            var hub = new FoundationEventHub(); var seen = new List<string>();
            IDisposable second = null;
            hub.Subscribe<int>(value => { seen.Add("a" + value); if (value == 1) { second.Dispose(); hub.Publish(2); } });
            second = hub.Subscribe<int>(value => seen.Add("b" + value));
            hub.Publish(1);
            check("foundation_events_reentrant_order_and_disposal", String.Join(",", seen) == "a1,a2");
            var faulty = new FoundationEventHub(); int received = 0; bool visible = false;
            faulty.Subscribe<int>(_ => throw new InvalidOperationException("expected listener failure"));
            faulty.Subscribe<int>(_ => received++);
            try { faulty.Publish(1); } catch (AggregateException error) { visible = error.InnerExceptions.Count == 1; }
            check("foundation_events_errors_visible_other_owners_called", visible && received == 1);
            var during = new FoundationEventHub(); int late = 0; bool added = false;
            during.Subscribe<int>(_ => { if (!added) { added = true; during.Subscribe<int>(v => late++); } });
            during.Publish(1); bool deferred = late == 0; during.Publish(2);
            check("foundation_events_subscribe_during_dispatch", deferred && late == 1);
            var killed = new FoundationEventHub(); int after = 0;
            killed.Subscribe<int>(_ => killed.Dispose()); killed.Subscribe<int>(_ => after++); killed.Publish(1);
            bool disposed = false; try { killed.Publish(2); } catch (ObjectDisposedException) { disposed = true; }
            check("foundation_events_hub_disposal_cancels_pending", after == 0 && disposed);
        }
        private static void VerifyClock(Action<string, bool> check)
        {
            var state = new FoundationGameState(); var clock = new FoundationClock(state);
            clock.Tick(10); check("foundation_clock_title_does_not_advance", state.PlayTime == 0 && state.DayTime == .15);
            state.InGame = true; clock.Tick(24);
            check("foundation_clock_active_time_and_day", state.PlayTime == 24 && Math.Abs(state.DayTime - .2) < 1e-15);
            state.SetUi("menu", true); double before = state.DayTime; clock.Tick(20);
            check("foundation_clock_ui_pause", state.PlayTime == 24 && state.DayTime == before);
            state.SetUi("menu", false); clock.Tick(20, true);
            check("foundation_clock_external_pause", state.PlayTime == 24);
            state.Transitioning = true; clock.Tick(1);
            check("foundation_clock_transition_alone_keeps_source_time", state.PlayTime == 25);
            state.Transitioning = false; state.Ended = true; clock.Tick(1);
            check("foundation_clock_ended_does_not_advance", state.PlayTime == 25);
            state.Ended = false; state.DayTime = .9; clock.Tick(960);
            check("foundation_clock_large_delta_source_single_day", state.DayCount == 1 && Math.Abs(state.DayTime - .9) < 1e-15);
            int achievementChecks = 0; state.Events.Subscribe<FoundationAchievementCheckRequested>(_ => achievementChecks++);
            state.SetUi("menu", true); clock.Tick(2); clock.MarkAchievementsDirty(); clock.Tick(0);
            check("foundation_clock_achievement_checks_even_when_paused", achievementChecks == 2);
            bool rejected = false; try { clock.Tick(-1); } catch (ArgumentOutOfRangeException) { rejected = true; }
            check("foundation_clock_invalid_delta_rejected", rejected && state.PlayTime == 985);
            int prior = achievementChecks; state.Coins = 5; clock.Tick(0);
            check("foundation_clock_items_mark_achievements_dirty", achievementChecks == prior + 1);
            prior = achievementChecks; state.PlayTime = 1; clock.Tick(0);
            check("foundation_clock_time_writes_do_not_mark_achievements", achievementChecks == prior);
            clock.Dispose(); bool closed = false; try { clock.Tick(0); } catch (ObjectDisposedException) { closed = true; }
            check("foundation_clock_disposal_stops_clock", closed);
        }
        private static void VerifyRules(Action<string, bool> check)
        {
            var state = new FoundationGameState(); var conditions = new FoundationConditionRegistry(state); var actions = new FoundationActionRegistry(state);
            check("foundation_conditions_empty_all_true", conditions.CheckAll(FoundationJson.Parse("[]")).Value);
            check("foundation_conditions_invalid_payload_rejected", conditions.CheckAll(FoundationJson.Parse("{} ")).Status == FoundationRuleStatus.Invalid && conditions.Check(FoundationJson.Parse("\"flag\"")).Status == FoundationRuleStatus.Invalid);
            check("foundation_conditions_unknown_is_false", conditions.Check(FoundationJson.Parse("[\"not_ported\"]")).Status == FoundationRuleStatus.Unknown && !conditions.Check(FoundationJson.Parse("[\"not_ported\"]")).Value);
            conditions.Register("custom", _ => new FoundationConditionResult(FoundationRuleStatus.Supported, true));
            check("foundation_conditions_explicit_extension_handler", conditions.Check(FoundationJson.Parse("[\"custom\"]")).Value);
            check("foundation_actions_set_clear_flag", actions.Execute(FoundationJson.Parse("[\"set_flag\",\"demo\"]")).Succeeded && state.Flag("demo") && actions.Execute(FoundationJson.Parse("[\"clear_flag\",\"demo\"]")).Succeeded && !state.Flag("demo"));
            actions.Execute(FoundationJson.Parse("[\"coins\",25]")); actions.Execute(FoundationJson.Parse("[\"coins\",-40]"));
            check("foundation_actions_coins_clamp_at_zero", state.Coins == 0);
            check("foundation_actions_inventory_requires_actual_handler", actions.Execute(FoundationJson.Parse("[\"give\",\"gel\",2]")).Status == FoundationRuleStatus.HandlerRequired && state.Count("gel") == 0);
            check("foundation_actions_malformed_payload_rejected", actions.ExecuteAll(FoundationJson.Parse("{}")).Status == FoundationRuleStatus.Invalid && actions.Execute(FoundationJson.Parse("[\"coins\",\"bad\"]")).Status == FoundationRuleStatus.Invalid);
            actions.Register("custom", _ => new FoundationActionResult(FoundationRuleStatus.Supported));
            check("foundation_actions_explicit_extension_handler", actions.Execute(FoundationJson.Parse("[\"custom\"]")).Succeeded);
            state.Coins = Int64.MaxValue;
            check("foundation_actions_overflow_preserves_state", actions.Execute(FoundationJson.Parse("[\"coins\",1]")).Status == FoundationRuleStatus.Invalid && state.Coins == Int64.MaxValue);
            state.Coins = 0;
            var batch = actions.ExecuteAll(FoundationJson.Parse("[[\"coins\",3],[\"give\",\"gel\"],[\"coins\",5]]"));
            check("foundation_actions_sequential_stop_on_unsupported", !batch.Succeeded && state.Coins == 3);
        }
        private static void VerifyInteractions(Action<string, bool> check)
        {
            var state = new FoundationGameState(); var interactions = new FoundationInteractionRegistry(state);
            var candidates = new[] { new FoundationInteractionCandidate("edge", "npc", 40, 0), new FoundationInteractionCandidate("west", "npc", -8, 0), new FoundationInteractionCandidate("east", "npc", 12, 0) };
            check("foundation_interaction_nearest_target", interactions.FindTarget(candidates, 0, 0)?.Id == "west");
            check("foundation_interaction_aim_scoring", interactions.FindTarget(candidates, 0, 0, true, 1, 0)?.Id == "east");
            check("foundation_interaction_range_strict", interactions.FindTarget(new[] { candidates[0] }, 0, 0) == null);
            check("foundation_interaction_source_float32_coordinates", interactions.FindTarget(new[] { new FoundationInteractionCandidate("rounds_to_edge", "npc", 39.9999999, 0) }, 0, 0) == null);
            check("foundation_interaction_ties_preserve_order", interactions.FindTarget(new[] { new FoundationInteractionCandidate("first", "npc", 5, 0), new FoundationInteractionCandidate("second", "npc", -5, 0) }, 0, 0)?.Id == "first");
            check("foundation_interaction_unported_requires_handler", interactions.Interact(candidates[1]).Status == FoundationRuleStatus.HandlerRequired);
            int calls = 0; interactions.Register("npc", _ => { calls++; return new FoundationActionResult(FoundationRuleStatus.Supported); });
            check("foundation_interaction_explicit_handler_executes", interactions.Interact(candidates[1]).Succeeded && calls == 1);
            state.SetUi("dialogue", true);
            check("foundation_interaction_lock_checks_again_at_use", interactions.FindTarget(candidates, 0, 0) == null && interactions.Interact(candidates[1]).Status == FoundationRuleStatus.Rejected && calls == 1);
        }
        private static void VerifyCommit(Action<string, bool> check)
        {
            var state = new FoundationGameState(); bool coherent = true; int calls = 0;
            state.Events.Subscribe<FoundationStateChanged>(_ => { calls++; coherent &= state.MapId == "forest" && state.Position.Items[0].AsDouble() == 32 && state.SpawnName == "gate" && !state.UseLoadPosition; });
            state.Events.Subscribe<FoundationStateChanged>(_ => throw new InvalidOperationException("expected post-commit failure"));
            bool committed = false;
            try { state.CommitLocation("forest", "gate", FoundationJson.Parse("[32,64]")); } catch (FoundationLocationCommittedException error) { committed = error.AlreadyCommitted && error.InnerExceptions.Count == 2; }
            check("foundation_location_commit_atomic_before_events", coherent && calls == 2 && committed);
            bool invalid = false;
            try { state.CommitLocation("other", "start", FoundationJson.Parse("[1]")); } catch (ArgumentException) { invalid = true; }
            check("foundation_location_invalid_commit_preserves_state", invalid && state.MapId == "forest" && calls == 2);
        }
        public static void VerifyOracle(FoundationValue oracle, Action<string, bool> check)
        {
            if (oracle.Require("float64Encoding").AsString() != "ieee754-binary64-little-endian-hex") throw new FormatException("Unsupported source Float64 encoding");
            bool malformedBitsRejected = true;
            foreach (var malformed in new[] { "", "000000000000000", "00000000000000000", "000000000000000g", "000000000000F03F", "000000000000f07f", "000000000000f87f" })
            {
                bool rejected = false;
                try { ReadDouble(FoundationJson.Parse("{\"value_bits_le\":\"" + malformed + "\"}"), "value"); } catch (FormatException) { rejected = true; }
                malformedBitsRejected &= rejected;
            }
            check("foundation_source_float64_oracle_strict", malformedBitsRejected && BitConverter.DoubleToInt64Bits(ReadDouble(FoundationJson.Parse("{\"value_bits_le\":\"0000000000000080\"}"), "value")) == Int64.MinValue);
            var rulesState = new FoundationGameState(oracle.Require("conditionState"));
            var conditions = new FoundationConditionRegistry(rulesState); int cases = 0;
            foreach (var entry in oracle.Require("conditions").Items)
            {
                var actual = conditions.Check(entry.Require("condition"));
                check("foundation_source_condition_" + (++cases), actual.Status == FoundationRuleStatus.Supported && actual.Value == entry.Require("expected").AsBool());
            }
            int clocks = 0;
            foreach (var entry in oracle.Require("clocks").Items)
            {
                var state = new FoundationGameState(); var before = entry.Require("before"); var expected = entry.Require("expected");
                state.PlayTime = ReadDouble(before, "play_time"); state.DayTime = ReadDouble(before, "day_time"); state.DayCount = before.Require("day_count").AsInt64();
                state.InGame = before.Require("in_game").AsBool(); state.Ended = before.Require("ended").AsBool(); state.Transitioning = before.Require("transitioning").AsBool();
                state.SetUi("oracle", before.Require("ui_open").AsBool());
                using (var clock = new FoundationClock(state)) clock.Tick(ReadDouble(entry, "delta"), before.Require("external_paused").AsBool());
                check("foundation_source_clock_" + (++clocks), BitConverter.DoubleToInt64Bits(state.PlayTime) == BitConverter.DoubleToInt64Bits(ReadDouble(expected, "play_time")) && BitConverter.DoubleToInt64Bits(state.DayTime) == BitConverter.DoubleToInt64Bits(ReadDouble(expected, "day_time")) && state.DayCount == expected.Require("day_count").AsInt64() && state.InputLocked == expected.Require("input_locked").AsBool());
            }
            int targets = 0;
            foreach (var entry in oracle.Require("targeting").Items)
            {
                var state = new FoundationGameState(); state.SetUi("oracle", entry.Require("locked").AsBool());
                var options = new List<FoundationInteractionCandidate>();
                foreach (var candidate in entry.Require("candidates").Items) options.Add(new FoundationInteractionCandidate(candidate.Require("id").AsString(), "oracle", candidate.Require("x").AsDouble(), candidate.Require("y").AsDouble()));
                var selected = new FoundationInteractionRegistry(state).FindTarget(options, 0, 0, entry.Require("aiming").AsBool(), entry.Require("aimX").AsDouble(), entry.Require("aimY").AsDouble());
                check("foundation_source_target_" + (++targets), (selected?.Id ?? "") == entry.Require("expected").AsString());
            }
            check("foundation_source_oracle_count", cases >= 20 && clocks >= 8 && targets >= 5);
        }
        private static double ReadDouble(FoundationValue container, string name)
        {
            string text = container.Require(name + "_bits_le").AsString();
            if (text.Length != 16) throw new FormatException("Source Float64 requires exactly eight little-endian bytes: " + name);
            ulong bits = 0;
            for (int index = 0; index < 8; index++)
            {
                int high = HexNibble(text[index * 2]), low = HexNibble(text[index * 2 + 1]);
                bits |= (ulong)((high << 4) | low) << (index * 8);
            }
            double value = BitConverter.Int64BitsToDouble(unchecked((long)bits));
            if (Double.IsNaN(value) || Double.IsInfinity(value)) throw new FormatException("Source Float64 must be finite: " + name);
            return value;
        }
        private static int HexNibble(char value)
        {
            if (value >= '0' && value <= '9') return value - '0';
            if (value >= 'a' && value <= 'f') return value - 'a' + 10;
            throw new FormatException("Source Float64 bytes require lowercase hexadecimal digits");
        }
    }
}
