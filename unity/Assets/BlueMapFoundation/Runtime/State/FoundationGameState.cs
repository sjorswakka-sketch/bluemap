using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;

namespace BlueMapMigration.Foundation
{
    /// <summary>Scene-independent raw source state. No save file is read, normalized, or written here.</summary>
    public sealed class FoundationGameState
    {
        public static readonly IReadOnlyList<string> SaveKeys = Array.AsReadOnly(new[] {
            "version", "map", "pos", "hp", "coins", "inventory", "flags", "quests", "weapon", "visited_maps",
            "play_time", "kills", "meer", "day_time", "day_count", "kills_by", "rolls", "potions_drunk", "deaths",
            "boss_deaths", "talked", "achievements", "arena_records", "homestead", "coastal_storage", "stockroom",
            "personal_home", "yard", "professions", "hero_xp", "equipment", "appearance", "clothing", "ng_plus"
        });
        private readonly Dictionary<string, FoundationValue> fields = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
        private readonly HashSet<string> uiOwners = new HashSet<string>(StringComparer.Ordinal);
        private readonly ReadOnlyDictionary<string, FoundationValue> view;
        public FoundationEventHub Events { get; }
        public IReadOnlyDictionary<string, FoundationValue> Fields => view;
        public IReadOnlyCollection<string> UiOwners => new List<string>(uiOwners).AsReadOnly();
        public bool InGame { get; set; }
        public bool Ended { get; set; }
        public bool Transitioning { get; set; }
        public string SpawnName { get; set; } = "start";
        public bool UseLoadPosition { get; set; }
        public bool Paused => uiOwners.Count != 0;
        public bool InputLocked => Ended || Transitioning || Paused;
        public FoundationGameState(FoundationValue saveRoot = null, FoundationEventHub events = null)
        {
            Events = events ?? new FoundationEventHub();
            view = new ReadOnlyDictionary<string, FoundationValue>(fields);
            var defaults = FoundationJson.Parse("{\"version\":1,\"map\":\"village\",\"pos\":[0,0],\"hp\":5,\"coins\":0,\"inventory\":{},\"flags\":{\"op_new_adventure\":true},\"quests\":{},\"weapon\":\"wood\",\"visited_maps\":{},\"play_time\":0.0,\"kills\":0,\"meer\":{},\"day_time\":0.15,\"day_count\":0,\"kills_by\":{},\"rolls\":0,\"potions_drunk\":0,\"deaths\":0,\"boss_deaths\":0,\"talked\":[],\"achievements\":[],\"arena_records\":{},\"homestead\":{},\"coastal_storage\":{},\"stockroom\":{},\"personal_home\":{},\"yard\":{},\"professions\":{},\"hero_xp\":0,\"equipment\":{},\"appearance\":{\"gender\":\"m\",\"hair\":\"m_kort\",\"hair_color\":2,\"eyes\":\"rond\",\"eye_color\":0},\"clothing\":{},\"ng_plus\":0}");
            // Present saves are kept exactly, including unknown future keys; defaults are only for a new state.
            var source = saveRoot ?? defaults;
            if (source.Kind != "object" && source.Kind != "dictionary") throw new FormatException("Source state must be a dictionary");
            foreach (var entry in source.Entries)
            {
                var key = entry.Key.AsString();
                if (fields.ContainsKey(key)) throw new FormatException("Duplicate state field: " + key);
                fields.Add(key, entry.Value);
            }
        }
        public FoundationValue Get(string key)
        {
            if (!fields.TryGetValue(key, out var value)) throw new KeyNotFoundException("Missing source state field: " + key);
            return value;
        }
        public void Set(string key, FoundationValue value)
        {
            if (String.IsNullOrEmpty(key)) throw new ArgumentException("State field is required", nameof(key));
            if (value == null) throw new ArgumentNullException(nameof(value));
            fields[key] = value; Events.Publish(new FoundationStateChanged(key));
        }
        internal static FoundationValue Text(string text) => FoundationValue.StringValue(text);
        internal static FoundationValue Integer(long number) => FoundationValue.Integer(number);
        internal static FoundationValue Number(double number)
        {
            if (Double.IsNaN(number) || Double.IsInfinity(number)) throw new ArgumentOutOfRangeException(nameof(number));
            return FoundationValue.Number(number);
        }
        internal static string Quote(string value)
        {
            if (value == null) throw new ArgumentNullException(nameof(value));
            var result = new System.Text.StringBuilder("\"");
            foreach (char c in value)
            {
                switch (c)
                {
                    case '"': result.Append("\\\""); break;
                    case '\\': result.Append("\\\\"); break;
                    case '\b': result.Append("\\b"); break;
                    case '\f': result.Append("\\f"); break;
                    case '\n': result.Append("\\n"); break;
                    case '\r': result.Append("\\r"); break;
                    case '\t': result.Append("\\t"); break;
                    default: if (c < 32) result.Append("\\u" + ((int)c).ToString("x4")); else result.Append(c); break;
                }
            }
            return result.Append('"').ToString();
        }
        public string MapId { get => Get("map").AsString(); set => Set("map", Text(value)); }
        public string Weapon { get => Get("weapon").AsString(); set => Set("weapon", Text(value)); }
        public FoundationValue Position { get => Get("pos"); set => Set("pos", value); }
        public long Hp { get => Get("hp").AsInt64(); set => Set("hp", Integer(value)); }
        public long Coins { get => Get("coins").AsInt64(); set => Set("coins", Integer(value)); }
        public double PlayTime { get => Get("play_time").AsDouble(); set => Set("play_time", Number(value)); }
        public double DayTime { get => Get("day_time").AsDouble(); set => Set("day_time", Number(value)); }
        public long DayCount { get => Get("day_count").AsInt64(); set => Set("day_count", Integer(value)); }
        public long Count(string item) => Get("inventory").TryGet(item, out var value) ? value.AsInt64() : 0;
        public bool Flag(string flag) => Get("flags").TryGet(flag, out var value) && value.AsBool();
        public string QuestState(string quest) => Get("quests").TryGet(quest, out var value) ? value.Require("state").AsString() : "none";
        public long QuestStep(string quest) => Get("quests").TryGet(quest, out var value) ? value.Require("step").AsInt64() : -1;
        public long MaxHp => checked(5 + Count("heart_container"));
        public long CrystalCount => (Count("crystal_bos") > 0 ? 1 : 0) + (Count("crystal_ruine") > 0 ? 1 : 0) + (Count("crystal_grot") > 0 ? 1 : 0);
        public void SetUi(string owner, bool open)
        {
            if (owner == null) throw new ArgumentNullException(nameof(owner));
            bool before = Paused;
            if (open) uiOwners.Add(owner); else uiOwners.Remove(owner);
            if (before != Paused) Events.Publish(new FoundationPauseChanged(Paused));
        }
        public void SetFlag(string flag, bool value)
        {
            var entries = new List<KeyValuePair<FoundationValue, FoundationValue>>();
            foreach (var entry in Get("flags").Entries) if (entry.Key.AsString() != flag) entries.Add(entry);
            if (value) entries.Add(new KeyValuePair<FoundationValue, FoundationValue>(Text(flag), FoundationJson.Parse("true")));
            Set("flags", FoundationValue.Dictionary(entries));
        }
        /// <summary>Publish one coherent gameplay transaction, including flags and all rewards, before any listener runs.</summary>
        public void CommitFields(IDictionary<string, FoundationValue> updates)
        {
            if (updates == null) throw new ArgumentNullException(nameof(updates));
            var prepared = new List<KeyValuePair<string, FoundationValue>>();
            foreach (var update in updates)
            {
                if (String.IsNullOrEmpty(update.Key) || update.Value == null) throw new ArgumentException("A gameplay transaction requires named nonnull values.", nameof(updates));
                prepared.Add(update);
            }
            foreach (var update in prepared) fields[update.Key] = update.Value;
            var failures = new List<Exception>();
            foreach (var update in prepared)
                try { Events.Publish(new FoundationStateChanged(update.Key)); } catch (Exception error) { failures.Add(error); }
            if (failures.Count != 0) throw new FoundationLocationCommittedException(failures);
        }
        /// <summary>Commit validated area data together before any synchronous listener can observe it.</summary>
        public void CommitLocation(string mapId, string spawn, FoundationValue position)
        {
            if (String.IsNullOrEmpty(mapId) || String.IsNullOrEmpty(spawn)) throw new ArgumentException("Map and spawn are required");
            if (position == null || position.Items.Count != 2) throw new ArgumentException("A two-coordinate position is required");
            foreach (var coordinate in position.Items)
            {
                double number = coordinate.AsDouble();
                if (Double.IsNaN(number) || Double.IsInfinity(number)) throw new ArgumentException("Location coordinates must be finite");
            }
            var mapValue = Text(mapId);
            fields["map"] = mapValue; fields["pos"] = position;
            SpawnName = spawn; UseLoadPosition = false;
            var failures = new List<Exception>();
            foreach (var field in new[] { "map", "pos" })
                try { Events.Publish(new FoundationStateChanged(field)); } catch (Exception error) { failures.Add(error); }
            if (failures.Count != 0) throw new FoundationLocationCommittedException(failures);
        }
        public FoundationValue Snapshot()
        {
            var entries = new List<KeyValuePair<FoundationValue, FoundationValue>>();
            foreach (var entry in fields) entries.Add(new KeyValuePair<FoundationValue, FoundationValue>(Text(entry.Key), entry.Value));
            return FoundationValue.Dictionary(entries);
        }
    }

    /// <summary>_process source policy, including the source's single day-count increment on a very large delta.</summary>
    public sealed class FoundationClock : IDisposable
    {
        public const double DayLength = 480.0;
        public const double Start = 0.15;
        public const double AchievementInterval = 2.0;
        private readonly FoundationGameState state;
        private double achievementTimer = AchievementInterval;
        private bool achievementsDirty;
        private readonly IDisposable changes;
        private bool disposed;
        public FoundationClock(FoundationGameState state)
        {
            this.state = state ?? throw new ArgumentNullException(nameof(state));
            changes = state.Events.Subscribe<FoundationStateChanged>(change =>
            {
                if (change.Field == "inventory" || change.Field == "quests" || change.Field == "flags" || change.Field == "coins" || change.Field == "weapon")
                    achievementsDirty = true;
            });
        }
        public void MarkAchievementsDirty() { achievementsDirty = true; }
        public void Tick(double delta, bool externalPaused = false)
        {
            if (disposed) throw new ObjectDisposedException(nameof(FoundationClock));
            if (delta < 0 || Double.IsNaN(delta) || Double.IsInfinity(delta)) throw new ArgumentOutOfRangeException(nameof(delta));
            if (state.InGame && !state.Ended && !state.Paused && !externalPaused)
            {
                state.PlayTime += delta;
                // Homestead subscribes when its actual system is ported; this signal is not a fabricated growth result.
                state.Events.Publish(new FoundationActiveTimeAdvanced(delta));
                double time = state.DayTime + delta / DayLength;
                if (time >= 1.0) { time = WrapTime(time); state.DayCount = checked(state.DayCount + 1); }
                state.DayTime = time;
            }
            if (state.InGame)
            {
                achievementTimer -= delta;
                if (achievementsDirty || achievementTimer <= 0)
                {
                    achievementsDirty = false; achievementTimer = AchievementInterval;
                    state.Events.Publish(new FoundationAchievementCheckRequested());
                }
            }
        }
        public static double WrapTime(double value) { double remainder = value % 1.0; if (remainder < 0) remainder += 1.0; return remainder + 0.0; }
        public void Dispose() { if (disposed) return; disposed = true; changes.Dispose(); }
    }
    public sealed class FoundationLocationCommittedException : AggregateException
    {
        public bool AlreadyCommitted => true;
        public FoundationLocationCommittedException(IEnumerable<Exception> errors)
            : base("Location committed; one or more post-commit listeners failed", errors) { }
    }
}
