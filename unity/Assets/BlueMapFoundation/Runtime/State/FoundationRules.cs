using System;
using System.Collections.Generic;

namespace BlueMapMigration.Foundation
{
    public enum FoundationRuleStatus { Supported, Unknown, Invalid, HandlerRequired, Rejected }
    public readonly struct FoundationConditionResult
    {
        public readonly FoundationRuleStatus Status;
        public readonly bool Value;
        public readonly string Diagnostic;
        public FoundationConditionResult(FoundationRuleStatus status, bool value, string diagnostic = "")
        { Status = status; Value = value; Diagnostic = diagnostic; }
    }
    public readonly struct FoundationActionResult
    {
        public readonly FoundationRuleStatus Status;
        public readonly string Diagnostic;
        public bool Succeeded => Status == FoundationRuleStatus.Supported;
        public FoundationActionResult(FoundationRuleStatus status, string diagnostic = "") { Status = status; Diagnostic = diagnostic; }
    }
    public sealed class FoundationConditionRegistry
    {
        private readonly Dictionary<string, Func<FoundationValue, FoundationConditionResult>> handlers = new Dictionary<string, Func<FoundationValue, FoundationConditionResult>>(StringComparer.Ordinal);
        private readonly FoundationGameState state;
        public FoundationConditionRegistry(FoundationGameState state) { this.state = state ?? throw new ArgumentNullException(nameof(state)); }
        private static readonly HashSet<string> CoreNames = new HashSet<string> { "flag", "no_flag", "quest", "step", "has", "lacks", "coins", "map", "weapon", "crystals", "hurt" };
        public void Register(string name, Func<FoundationValue, FoundationConditionResult> handler)
        {
            if (String.IsNullOrEmpty(name) || handler == null) throw new ArgumentException("A named condition handler is required");
            if (CoreNames.Contains(name) || handlers.ContainsKey(name)) throw new InvalidOperationException("Condition already registered: " + name);
            handlers.Add(name, handler);
        }
        public FoundationConditionResult Check(FoundationValue condition)
        {
            if (condition == null || condition.Kind != "array") return new FoundationConditionResult(FoundationRuleStatus.Invalid, false, "Condition must be an array");
            try
            {
                var args = condition.Items;
                if (args.Count == 0) return new FoundationConditionResult(FoundationRuleStatus.Invalid, false, "Empty condition");
                string name = args[0].AsString();
                bool result;
                switch (name)
                {
                    case "flag": result = state.Flag(args[1].AsString()); break;
                    case "no_flag": result = !state.Flag(args[1].AsString()); break;
                    case "quest": result = state.QuestState(args[1].AsString()) == args[2].AsString(); break;
                    case "step": result = state.QuestState(args[1].AsString()) == "active" && state.QuestStep(args[1].AsString()) == args[2].AsInt64(); break;
                    case "has": result = state.Count(args[1].AsString()) >= (args.Count > 2 ? args[2].AsInt64() : 1); break;
                    case "lacks": result = state.Count(args[1].AsString()) < (args.Count > 2 ? args[2].AsInt64() : 1); break;
                    case "coins": result = state.Coins >= args[1].AsInt64(); break;
                    case "map": result = state.MapId == args[1].AsString(); break;
                    case "weapon": result = state.Weapon == args[1].AsString(); break;
                    case "crystals": result = state.CrystalCount >= args[1].AsInt64(); break;
                    case "hurt": result = state.Hp < state.MaxHp; break;
                    default:
                        return handlers.TryGetValue(name, out var handler) ? handler(condition)
                            : new FoundationConditionResult(FoundationRuleStatus.Unknown, false, "Condition requires its original module handler: " + name);
                }
                return new FoundationConditionResult(FoundationRuleStatus.Supported, result);
            }
            catch (Exception error) when (error is ArgumentException || error is InvalidOperationException || error is FormatException || error is IndexOutOfRangeException || error is KeyNotFoundException || error is OverflowException)
            { return new FoundationConditionResult(FoundationRuleStatus.Invalid, false, error.Message); }
        }
        public FoundationConditionResult CheckAll(FoundationValue conditions)
        {
            if (conditions == null || conditions.Kind != "array") return new FoundationConditionResult(FoundationRuleStatus.Invalid, false, "Conditions must be an array");
            try
            {
                foreach (var condition in conditions.Items)
                {
                    var result = Check(condition);
                    if (result.Status != FoundationRuleStatus.Supported || !result.Value) return result;
                }
                return new FoundationConditionResult(FoundationRuleStatus.Supported, true);
            }
            catch (InvalidOperationException error) { return new FoundationConditionResult(FoundationRuleStatus.Invalid, false, error.Message); }
        }
    }
    /// <summary>Only state-only actions are executable. Quest, reward, save and audiovisual actions require real owners.</summary>
    public sealed class FoundationActionRegistry
    {
        private readonly FoundationGameState state;
        private readonly Dictionary<string, Func<FoundationValue, FoundationActionResult>> handlers = new Dictionary<string, Func<FoundationValue, FoundationActionResult>>(StringComparer.Ordinal);
        public FoundationActionRegistry(FoundationGameState state) { this.state = state ?? throw new ArgumentNullException(nameof(state)); }
        public void Register(string name, Func<FoundationValue, FoundationActionResult> handler)
        {
            if (String.IsNullOrEmpty(name) || handler == null) throw new ArgumentException("A named action handler is required");
            if (name == "set_flag" || name == "clear_flag" || name == "coins" || handlers.ContainsKey(name)) throw new InvalidOperationException("Action already registered: " + name);
            handlers.Add(name, handler);
        }
        public FoundationActionResult Execute(FoundationValue action)
        {
            if (action == null || action.Kind != "array") return new FoundationActionResult(FoundationRuleStatus.Invalid, "Action must be an array");
            string name;
            try
            {
                var args = action.Items;
                if (args.Count == 0) return new FoundationActionResult(FoundationRuleStatus.Invalid, "Empty action");
                name = args[0].AsString();
                // Parse and validate before mutation. Domain-side notifications remain explicit state events.
                if (name == "set_flag" || name == "clear_flag")
                {
                    var flag = args[1].AsString();
                    state.SetFlag(flag, name == "set_flag");
                    return new FoundationActionResult(FoundationRuleStatus.Supported);
                }
                if (name == "coins")
                {
                    long coins = Math.Max(0, checked(state.Coins + args[1].AsInt64()));
                    state.Coins = coins; return new FoundationActionResult(FoundationRuleStatus.Supported);
                }
            }
            catch (Exception error) when (error is ArgumentException || error is InvalidOperationException || error is FormatException || error is IndexOutOfRangeException || error is KeyNotFoundException || error is OverflowException)
            { return new FoundationActionResult(FoundationRuleStatus.Invalid, error.Message); }
            // Invoke external owners outside input-validation catches: implementation failures are never masked as malformed input.
            return handlers.TryGetValue(name, out var handler) ? handler(action)
                : new FoundationActionResult(FoundationRuleStatus.HandlerRequired, "Action has not been ported; a real handler is required: " + name);
        }
        public FoundationActionResult ExecuteAll(FoundationValue actions)
        {
            if (actions == null || actions.Kind != "array") return new FoundationActionResult(FoundationRuleStatus.Invalid, "Actions must be an array");
            // Source run_all is sequential, not transactional. Stop on unsupported actions rather than silently continuing.
            foreach (var action in actions.Items)
            {
                var result = Execute(action);
                if (!result.Succeeded) return result;
            }
            return new FoundationActionResult(FoundationRuleStatus.Supported);
        }
    }
}
