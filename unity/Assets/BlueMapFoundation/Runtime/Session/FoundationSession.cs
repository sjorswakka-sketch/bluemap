using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using UnityEngine;

namespace BlueMapMigration.Foundation
{
    public readonly struct FoundationAreaEntered
    {
        public readonly FoundationWorldSnapshot Snapshot;
        public readonly string Spawn;
        public readonly Vector2 GodotPosition;
        public FoundationAreaEntered(FoundationWorldSnapshot snapshot, string spawn, Vector2 position)
        { Snapshot = snapshot; Spawn = spawn; GodotPosition = position; }
    }

    // Own subscriptions/resources for one area, even if an individual owner fails to release.
    public sealed class FoundationAreaScope : IDisposable
    {
        private readonly List<IDisposable> owned = new List<IDisposable>();
        public bool Disposed { get; private set; }
        public T Own<T>(T item) where T : IDisposable
        {
            if (Disposed) throw new ObjectDisposedException(nameof(FoundationAreaScope));
            if (item == null) throw new ArgumentNullException(nameof(item));
            owned.Add(item); return item;
        }
        public void Dispose()
        {
            if (Disposed) return;
            Disposed = true; var errors = new List<Exception>();
            for (int i = owned.Count - 1; i >= 0; i--)
                try { owned[i].Dispose(); } catch (Exception error) { errors.Add(error); }
            owned.Clear();
            if (errors.Count > 0) throw new AggregateException("Area owners failed to release", errors);
        }
    }

    // Foundation only: validate and commit existing area snapshots; rendering, movement,
    // quest consequences and save normalization remain their planned system ports.
    public sealed class FoundationSession : IDisposable
    {
        public FoundationWorldRepository Repository { get; }
        public FoundationGameState State { get; }
        public FoundationClock Clock { get; }
        public FoundationAreaScope Area { get; private set; }
        public FoundationWorldSnapshot Current { get; private set; }
        public string LastDiagnostic { get; private set; }
        private bool disposed;

        public FoundationSession(FoundationWorldRepository repository, FoundationGameState state)
        {
            Repository = repository ?? throw new ArgumentNullException(nameof(repository));
            State = state ?? throw new ArgumentNullException(nameof(state));
            Clock = new FoundationClock(state);
            Area = new FoundationAreaScope();
        }

        public bool TryEnter(string mapId, string spawn, string scenarioId = "fresh_baseline")
        {
            if (disposed) throw new ObjectDisposedException(nameof(FoundationSession));
            LastDiagnostic = null;
            if (State.InputLocked) { LastDiagnostic = "Area entry is locked by the current state."; return false; }
            FoundationWorldSnapshot prepared; FoundationArrival arrival;
            try
            {
                prepared = Repository.Read(mapId, scenarioId);
                arrival = prepared.Arrivals.FirstOrDefault(value => value.Name == spawn);
                if (arrival == null) throw new ArgumentException("Unknown arrival: " + spawn);
                if (!float.IsFinite(arrival.Resolved.x) || !float.IsFinite(arrival.Resolved.y))
                    throw new FormatException("Arrival has a non-finite source position.");
            }
            catch (Exception error) when (error is ArgumentException || error is FormatException || error is KeyNotFoundException || error is InvalidOperationException)
            { LastDiagnostic = error.Message; return false; }

            // Everything capable of failing validation has happened before the commit.
            // Notification failures are explicitly reported as POST-COMMIT diagnostics;
            // they never pretend that a valid committed location was rolled back.
            State.Transitioning = true;
            var errors = new List<Exception>();
            try
            {
                Repository.Load(mapId, scenarioId);
                Current = prepared;
                var old = Area; Area = new FoundationAreaScope();
                try { old.Dispose(); } catch (Exception error) { errors.Add(error); }
                State.InGame = true;
                string position = "[" + arrival.Resolved.x.ToString("R", CultureInfo.InvariantCulture) + ","
                    + arrival.Resolved.y.ToString("R", CultureInfo.InvariantCulture) + "]";
                try { State.CommitLocation(mapId, spawn, FoundationJson.Parse(position)); }
                catch (Exception error) { errors.Add(error); }
                try { State.Events.Publish(new FoundationAreaEntered(prepared, spawn, arrival.Resolved)); }
                catch (Exception error) { errors.Add(error); }
            }
            finally { State.Transitioning = false; }
            if (errors.Count > 0) LastDiagnostic = "Area committed; notification/cleanup errors: " + String.Join(" | ", errors.Select(error => error.Message));
            return true;
        }

        public void Dispose()
        {
            if (disposed) return; disposed = true;
            try { Area.Dispose(); } finally { Clock.Dispose(); }
        }
    }

    public static class FoundationSessionChecks
    {
        public static void Verify(Action<string, bool> check)
        {
            var repository = FoundationWorldRepository.LoadRequired();
            using (var events = new FoundationEventHub())
            {
                var state = new FoundationGameState(null, events);
                using (var session = new FoundationSession(repository, state))
                {
                    var village = repository.Read("village");
                    string spawn = village.Arrivals[0].Name;
                    int transitions = 0; bool lockedDuringEvent = false;
                    using (events.Subscribe<FoundationAreaEntered>(value => { transitions++; lockedDuringEvent = state.InputLocked; }))
                    {
                        check("session_initial_area_commits", session.TryEnter("village", spawn) && session.Current.MapId == state.MapId && state.InGame);
                        check("session_transition_notification_once_and_locked", transitions == 1 && lockedDuringEvent && !state.Transitioning);
                        state.Set("coins", FoundationJson.Parse("71"));
                        var before = session.Current; var position = state.Position;
                        check("session_missing_map_does_not_commit", !session.TryEnter("__missing__", spawn) && ReferenceEquals(before, session.Current) && ReferenceEquals(before, repository.Current) && ReferenceEquals(position, state.Position) && state.MapId == "village" && transitions == 1);
                        check("session_missing_arrival_does_not_commit", !session.TryEnter("village", "__missing__") && ReferenceEquals(before, repository.Current) && ReferenceEquals(position, state.Position) && transitions == 1);
                        state.SetUi("stockroom", true); double time = state.PlayTime;
                        session.Clock.Tick(1);
                        check("session_paused_load_and_time_blocked", !session.TryEnter("village", spawn) && state.PlayTime == time && ReferenceEquals(before, session.Current));
                        state.SetUi("stockroom", false);
                        int staleCalls = 0;
                        session.Area.Own(events.Subscribe<FoundationActiveTimeAdvanced>(value => staleCalls++));
                        var previousArea = session.Area;
                        string other = repository.MapIds.First(value => value != "village");
                        string otherSpawn = repository.Read(other).Arrivals[0].Name;
                        check("session_other_area_commits", session.TryEnter(other, otherSpawn) && state.MapId == other && transitions == 2);
                        session.Clock.Tick(.125);
                        check("session_old_area_subscriptions_released", previousArea.Disposed && staleCalls == 0);
                        check("session_state_survives_transition", state.Get("coins").AsInt64() == 71 && state.PlayTime == time + .125);
                        using (events.Subscribe<FoundationAreaEntered>(value => { throw new InvalidOperationException("injected owner failure"); }))
                        {
                            check("session_post_commit_failure_is_explicit", session.TryEnter("village", spawn) && state.MapId == "village" && session.Current.MapId == "village" && session.LastDiagnostic != null && session.LastDiagnostic.StartsWith("Area committed;", StringComparison.Ordinal) && !state.Transitioning);
                        }
                    }
                }
            }
            var scope = new FoundationAreaScope(); scope.Dispose();
            bool rejected = false; using (var hub = new FoundationEventHub()) { var sub = hub.Subscribe<int>(value => { }); try { scope.Own(sub); } catch (ObjectDisposedException) { rejected = true; } finally { sub.Dispose(); } }
            check("session_disposed_area_rejects_new_owners", rejected);
        }
    }
}
