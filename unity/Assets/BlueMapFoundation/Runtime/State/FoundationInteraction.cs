using System;
using System.Collections.Generic;

namespace BlueMapMigration.Foundation
{
    public readonly struct FoundationInteractionCandidate
    {
        public readonly string Id, Handler;
        public readonly double X, Y;
        public readonly bool Enabled;
        public FoundationInteractionCandidate(string id, string handler, double x, double y, bool enabled = true)
        { Id = id; Handler = handler; X = x; Y = y; Enabled = enabled; }
    }
    public sealed class FoundationInteractionRegistry
    {
        public const double Range = 40.0;
        private readonly Dictionary<string, Func<FoundationInteractionCandidate, FoundationActionResult>> handlers = new Dictionary<string, Func<FoundationInteractionCandidate, FoundationActionResult>>(StringComparer.Ordinal);
        private readonly FoundationGameState state;
        public FoundationInteractionRegistry(FoundationGameState state) { this.state = state ?? throw new ArgumentNullException(nameof(state)); }
        public void Register(string name, Func<FoundationInteractionCandidate, FoundationActionResult> callback)
        {
            if (String.IsNullOrEmpty(name) || callback == null) throw new ArgumentException("A named interaction handler is required");
            if (handlers.ContainsKey(name)) throw new InvalidOperationException("Interaction already registered: " + name);
            handlers.Add(name, callback);
        }
        public FoundationInteractionCandidate? FindTarget(IEnumerable<FoundationInteractionCandidate> candidates, double playerX, double playerY, bool aiming = false, double aimX = 0, double aimY = 0)
        {
            if (state.InputLocked) return null;
            FoundationInteractionCandidate? target = null;
            double best = Double.PositiveInfinity;
            foreach (var candidate in candidates)
            {
                if (!candidate.Enabled) continue;
                // Godot Vector2 is Float32 even though script scalar scores are Float64.
                float dx = (float)candidate.X - (float)playerX, dy = (float)candidate.Y - (float)playerY;
                float squared = dx * dx + dy * dy;
                float distance = (float)Math.Sqrt(squared);
                if (distance >= Range) continue;
                // aim_direction is already normalized by the source controller; zero displacement has zero direction.
                float directionX = distance == 0 ? 0 : dx / distance, directionY = distance == 0 ? 0 : dy / distance;
                float dot = (float)aimX * directionX + (float)aimY * directionY;
                double score = distance + (aiming ? (1.0 - dot) * 16.0 : 0);
                if (score < best) { best = score; target = candidate; }
            }
            return target;
        }
        public FoundationActionResult Interact(FoundationInteractionCandidate candidate)
        {
            if (state.InputLocked || !candidate.Enabled) return new FoundationActionResult(FoundationRuleStatus.Rejected, "Interaction is currently locked");
            return handlers.TryGetValue(candidate.Handler, out var handler) ? handler(candidate)
                : new FoundationActionResult(FoundationRuleStatus.HandlerRequired, "Interaction requires its real gameplay handler: " + candidate.Handler);
        }
    }
}
