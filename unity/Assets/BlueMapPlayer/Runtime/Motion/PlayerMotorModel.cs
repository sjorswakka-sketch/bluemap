using System;
using System.Collections.Generic;
using UnityEngine;

namespace BlueMapMigration.Player
{
    // Coordinates are original Godot pixels, +Y down. Convert only at the Unity physics boundary.
    public sealed class MotionInput
    {
        public Vector2 Direction;
        public bool SprintHeld, Locked, Paused, AttackActive, BowActive, CombatBusy;
        public string TileName = "";
        public double SpeedMultiplier = 1, CombatMovementFactor = 1;
    }
    public sealed class MotionFrame
    {
        public Vector2 VelocityPixels { get; internal set; }
        public double Delta { get; internal set; }
        public bool Rolling { get; internal set; }
        public bool Moving { get; internal set; }
        public bool Locked { get; internal set; }
        public bool Paused { get; internal set; }
        internal PlayerMotorModel Owner;
        internal bool Pushed, WantsSprint, Completed;
    }
    public sealed class PlayerMotorModel
    {
        public const double Speed = 110, RollSpeed = 235, RollTime = .3, RollCooldownSeconds = .7,
            RollSafeTime = .24, StepDistancePixels = 22;
        public readonly PlayerStamina Stamina;
        public Vector2 Facing { get; set; } = Vector2.up; // Godot DOWN (0,+1).
        public Vector2 AimDirection { get; set; } = Vector2.up;
        public Vector2 Knockback { get; set; }
        public Vector2 Velocity { get; private set; }
        public Vector2 RollDirection { get; set; } = Vector2.up;
        public double RollTimer { get; set; }
        public double RollCooldown { get; set; }
        public double WalkTime { get; set; }
        public double StepDistance { get; set; }
        public bool Moving { get; private set; }
        public bool Sprinting { get; private set; }
        public bool IsRolling => RollTimer > 0;
        public bool IsRollSafe => RollTimer > RollTime - RollSafeTime;
        private MotionFrame pending;
        public PlayerMotorModel(PlayerStamina stamina = null) { Stamina = stamina ?? new PlayerStamina(); }
        // Transient state import is used by source-oracle replay and future character lifecycle adapters.
        public void RestoreTransientState(Vector2 velocity, bool moving, bool sprinting)
        { Velocity = velocity; Moving = moving; Sprinting = sprinting; }
        public bool TryRoll(Vector2 sourceDirection, bool inputLocked = false)
        {
            if (inputLocked || RollCooldown > 0 || RollTimer > 0) return false;
            RollDirection = HasSourceInput(sourceDirection) ? NormalizeSource(sourceDirection) : Facing;
            Facing = RollDirection; RollTimer = RollTime; RollCooldown = RollCooldownSeconds;
            return true;
        }
        public void StopForTransition()
        {
            Velocity = Vector2.zero; Knockback = Vector2.zero; RollTimer = 0;
            Sprinting = false; Moving = false; pending = null;
        }
        public MotionFrame BeginStep(double delta, MotionInput input)
        {
            if (input == null) throw new ArgumentNullException(nameof(input));
            if (!PlayerStamina.Finite(delta) || delta < 0) throw new ArgumentOutOfRangeException(nameof(delta));
            if (pending != null) throw new InvalidOperationException("Complete the preceding motion frame before beginning another.");
            if (!PlayerStamina.Finite(input.SpeedMultiplier) || input.SpeedMultiplier < 0 ||
                !PlayerStamina.Finite(input.CombatMovementFactor) || input.CombatMovementFactor < 0)
                throw new ArgumentOutOfRangeException(nameof(input));
            var frame = new MotionFrame { Owner = this, Delta = delta, Locked = input.Locked, Paused = input.Paused };
            pending = frame;
            if (input.Paused) { frame.VelocityPixels = Vector2.zero; return frame; }
            Vector2 direction = input.Locked ? Vector2.zero : input.Direction;
            frame.Moving = Moving = HasSourceInput(direction);
            frame.Rolling = RollTimer > 0;
            frame.Pushed = SourceLengthSquared(Knockback) > 1;
            frame.WantsSprint = Moving && !input.Locked && !frame.Rolling && !frame.Pushed &&
                !input.AttackActive && !input.BowActive && input.SprintHeld && Stamina.CanSprint && !input.CombatBusy;
            double runMultiplier = frame.WantsSprint ? Stamina.SprintMultiplier(delta) : 1;
            if (frame.Rolling) Velocity = ScaleSource(RollDirection, RollSpeed);
            else
            {
                if (Moving) Facing = NormalizeSource(direction);
                // Match each original Vector2 (Float32) multiplication, preserving operator order.
                Velocity = ScaleSource(ScaleSource(ScaleSource(ScaleSource(direction, Speed), input.SpeedMultiplier),
                    PlayerSurface.MovementMultiplier(input.TileName)), runMultiplier) + Knockback;
            }
            Knockback = MoveTowardSource(Knockback, Vector2.zero, 900 * delta);
            Velocity = ScaleSource(Velocity, input.CombatMovementFactor);
            frame.VelocityPixels = Velocity;
            return frame;
        }
        // Call after actual collision resolution; blocked running must not consume stamina or produce footsteps.
        public string CompleteStep(MotionFrame frame, double actualDistancePixels, string tileAfter)
        {
            if (frame == null || frame.Owner != this || frame != pending || frame.Completed)
                throw new InvalidOperationException("Motion frame does not belong to this pending step.");
            if (!PlayerStamina.Finite(actualDistancePixels) || actualDistancePixels < 0)
                throw new ArgumentOutOfRangeException(nameof(actualDistancePixels));
            pending = null; frame.Completed = true;
            if (frame.Paused) return "";
            bool walking = frame.Moving && !frame.Locked && !frame.Rolling && !frame.Pushed && actualDistancePixels > 4 * frame.Delta;
            Sprinting = frame.WantsSprint && walking;
            if (!frame.Locked) Stamina.Advance(frame.Delta, Sprinting);
            if (walking) WalkTime += actualDistancePixels / Speed;
            string surface = PlayerSurface.FootstepSurface(tileAfter);
            string footstep = "";
            if (!walking || surface == "") StepDistance = 0;
            else
            {
                StepDistance += actualDistancePixels;
                if (StepDistance >= StepDistancePixels) { StepDistance %= StepDistancePixels; footstep = surface; }
            }
            RollTimer = Math.Max(RollTimer - frame.Delta, 0);
            RollCooldown = Math.Max(RollCooldown - frame.Delta, 0);
            return footstep;
        }
        public static Vector2 ScaleSource(Vector2 value, double factor)
        { float scalar = (float)factor; return new Vector2(value.x * scalar, value.y * scalar); }
        // Mono can retain a Float32 multiplication at higher intermediate precision.
        // Godot's real_t products each round to Float32 before their sum; materialize those exact bits.
        public static float SourceLengthSquared(Vector2 value)
        {
            float xSquared = RoundSource(value.x * value.x);
            float ySquared = RoundSource(value.y * value.y);
            return RoundSource(xSquared + ySquared);
        }
        private static float RoundSource(float value) => BitConverter.Int32BitsToSingle(BitConverter.SingleToInt32Bits(value));
        public static bool HasSourceInput(Vector2 value) => value.x != 0 || value.y != 0;
        public static float SourceLength(Vector2 value) => (float)Math.Sqrt(SourceLengthSquared(value));
        public static Vector2 NormalizeSource(Vector2 value)
        {
            float length = SourceLength(value);
            return length == 0 ? Vector2.zero : new Vector2(value.x / length, value.y / length);
        }
        private static Vector2 MoveTowardSource(Vector2 from, Vector2 to, double amount)
        {
            Vector2 difference = to - from; float length = SourceLength(difference); float step = (float)amount;
            return length <= step || length < .00001f ? to : from + new Vector2(difference.x / length, difference.y / length) * step;
        }
    }
    public static class PlayerSurface
    {
        private static readonly HashSet<string> Solid = new HashSet<string>(StringComparer.Ordinal)
        { "tree","water","stone","fence","roof","house_wall","house_window","rock","dead_tree","well","crate","cave_wall","cave_crystal","stalagmite","ruin_wall","ruin_pillar","temple_wall","wood_wall","counter","shelf","bed","meer_reeds","meer_lelie","meer_paal","void_wall","void_crystal","arena_wall","arena_tribune","arena_gate","pine","cactus","sandstone","bog_water","willow","ce_sea","ce_shore","ce_cliff","ad_seawall" };
        public static double MovementMultiplier(string tile)
        {
            switch (tile)
            {
                case "path": case "yard_boards": return 1.2;
                case "mud": return .88;
                case "ce_sand": case "ce_dune": case "meer_sand": case "arena_sand": case "dune_sand": case "dune_tufts": return .92;
                case "snow": case "snow_tufts": return .95;
                default: return 1;
            }
        }
        public static string FootstepSurface(string tile)
        {
            tile = tile ?? "";
            switch (tile)
            {
                case "yard_boards": case "ce_boardwalk": return "wood";
                case "ce_sand": case "ce_dune": return "sand";
                case "ce_grass": return "grass";
            }
            if (tile == "" || Solid.Contains(tile)) return "";
            if (tile.StartsWith("grass", StringComparison.Ordinal) || tile == "bush" || tile == "reed") return "grass";
            switch (tile)
            {
                case "path": return "path";
                case "meer_sand": case "arena_sand": case "dune_sand": case "dune_tufts": case "mud": return "sand";
                case "bridge": case "wood_floor": case "meer_bibvloer": case "door": return "wood";
                case "carpet": case "mat": case "meer_tapijt": return "cloth";
                case "snow": case "snow_tufts": case "snow_bush": return "snow";
                case "marsh_grass": case "marsh_tufts": return "grass";
                default: return "stone";
            }
        }
        public static double EquipmentSpeedMultiplier(bool ownsBoots, double normalizedMoveBonus)
        { return (ownsBoots ? 1.18 : 1) * (1 + normalizedMoveBonus); }
    }
}
