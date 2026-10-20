using System;

namespace BlueMapMigration.Player
{
    // Direct port of scripts/core/movement.gd. Values remain binary64, including partial final sprint steps.
    public sealed class PlayerStamina
    {
        public const double MaxStamina = 100, SprintFactor = 1.5, DrainPerSecond = 20,
            RegenPerSecond = 25, RegenDelaySeconds = .8, RecoveryPercent = 25;
        public double Stamina { get; set; } = MaxStamina;
        public double RegenDelay { get; set; }
        public bool Exhausted { get; set; }
        private double maxBonus, regenBonus;
        public double Capacity => MaxStamina + maxBonus;
        public double RegenRate => RegenPerSecond * (1 + regenBonus);
        public double RecoveryThreshold => Capacity * RecoveryPercent / MaxStamina;
        public bool CanSprint => !Exhausted && Stamina > .001;
        // Inject the existing equipment resolver's already normalized bonuses; changing equipment never refills energy.
        public void ConfigureBonuses(double staminaMax, double staminaRegen)
        {
            if (!Finite(staminaMax) || !Finite(staminaRegen) || staminaMax < 0 || staminaMax > 30 || staminaRegen < 0 || staminaRegen > .30)
                throw new ArgumentOutOfRangeException(nameof(staminaMax));
            maxBonus = staminaMax; regenBonus = staminaRegen;
        }
        public void Reset() { Stamina = Capacity; RegenDelay = 0; Exhausted = false; }
        public void ClampCapacity()
        {
            Stamina = Finite(Stamina) ? Math.Max(0, Math.Min(Stamina, Capacity)) : 0;
            if (Exhausted && Stamina >= RecoveryThreshold) Exhausted = false;
        }
        public bool Restore(double amount)
        {
            if (!Finite(amount) || amount <= 0 || Stamina >= Capacity) return false;
            Stamina = Math.Min(Stamina + amount, Capacity);
            if (Stamina >= RecoveryThreshold) Exhausted = false;
            return true;
        }
        public double SprintMultiplier(double delta)
        {
            if (delta <= 0 || !CanSprint) return 1;
            double fraction = Math.Min(Stamina / (DrainPerSecond * delta), 1);
            return 1 + (SprintFactor - 1) * fraction;
        }
        public void Advance(double delta, bool sprinting)
        {
            ClampCapacity();
            if (delta <= 0) return;
            if (sprinting && CanSprint)
            {
                Stamina = Math.Max(Stamina - DrainPerSecond * delta, 0);
                RegenDelay = RegenDelaySeconds;
                if (Stamina <= .001) { Stamina = 0; Exhausted = true; }
                return;
            }
            double recoveryTime = Math.Max(delta - RegenDelay, 0);
            RegenDelay = Math.Max(RegenDelay - delta, 0);
            Stamina = Math.Min(Stamina + RegenRate * recoveryTime, Capacity);
            if (Exhausted && Stamina >= RecoveryThreshold) Exhausted = false;
        }
        public bool Spend(double amount)
        {
            if (!Finite(amount) || amount <= 0 || Exhausted || Stamina < amount) return false;
            Stamina -= amount; RegenDelay = RegenDelaySeconds;
            if (Stamina <= .001) { Stamina = 0; Exhausted = true; }
            return true;
        }
        internal static bool Finite(double value) => !Double.IsNaN(value) && !Double.IsInfinity(value);
    }
}
