using System;
using System.Collections.Generic;

namespace BlueMapMigration.Foundation
{
    /// <summary>Main-thread event ownership; nested publications are queued, not recursively dispatched.</summary>
    public sealed class FoundationEventHub : IDisposable
    {
        private interface ISubscription { bool Alive { get; } void Invoke(object value); }
        private sealed class Subscription<T> : ISubscription, IDisposable
        {
            private Action<T> action;
            public Subscription(Action<T> action) { this.action = action; }
            public bool Alive => action != null;
            public void Invoke(object value) { var callback = action; if (callback != null) callback((T)value); }
            public void Dispose() { action = null; }
        }
        private readonly Dictionary<Type, List<ISubscription>> listeners = new Dictionary<Type, List<ISubscription>>();
        private readonly Queue<KeyValuePair<Type, object>> pending = new Queue<KeyValuePair<Type, object>>();
        private bool dispatching, disposed;
        public IDisposable Subscribe<T>(Action<T> callback)
        {
            if (disposed) throw new ObjectDisposedException(nameof(FoundationEventHub));
            if (callback == null) throw new ArgumentNullException(nameof(callback));
            if (!listeners.TryGetValue(typeof(T), out var list)) listeners.Add(typeof(T), list = new List<ISubscription>());
            list.RemoveAll(item => !item.Alive);
            var subscription = new Subscription<T>(callback); list.Add(subscription); return subscription;
        }
        public void Publish<T>(T value)
        {
            if (disposed) throw new ObjectDisposedException(nameof(FoundationEventHub));
            pending.Enqueue(new KeyValuePair<Type, object>(typeof(T), value));
            if (dispatching) return;
            dispatching = true;
            var failures = new List<Exception>();
            try
            {
                while (!disposed && pending.Count != 0)
                {
                    var entry = pending.Dequeue();
                    if (!listeners.TryGetValue(entry.Key, out var list)) continue;
                    // Disposed subscriptions are skipped even if disposal occurs in a preceding callback.
                    foreach (var listener in list.ToArray())
                        if (!disposed && listener.Alive)
                            try { listener.Invoke(entry.Value); } catch (Exception error) { failures.Add(error); }
                    list.RemoveAll(item => !item.Alive);
                }
            }
            finally { dispatching = false; if (disposed) pending.Clear(); }
            // Other owners still receive their notification; failures remain visible to the caller.
            if (failures.Count != 0) throw new AggregateException("Foundation event listener failed", failures);
        }
        public void Dispose()
        {
            if (disposed) return;
            disposed = true; pending.Clear(); listeners.Clear();
        }
    }

    public readonly struct FoundationStateChanged
    {
        public readonly string Field;
        public FoundationStateChanged(string field) { Field = field; }
    }
    public readonly struct FoundationPauseChanged
    {
        public readonly bool Paused;
        public FoundationPauseChanged(bool paused) { Paused = paused; }
    }
    public readonly struct FoundationActiveTimeAdvanced
    {
        public readonly double Seconds;
        public FoundationActiveTimeAdvanced(double seconds) { Seconds = seconds; }
    }
    public readonly struct FoundationAchievementCheckRequested { }
}
