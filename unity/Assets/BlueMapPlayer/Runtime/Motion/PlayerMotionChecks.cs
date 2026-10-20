using System;
using System.Globalization;
using UnityEngine;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Player
{
    public static class PlayerMotionChecks
    {
        public static int OracleCases { get; private set; }
        public static void Verify(Action<string, bool> check)
        {
            var stamina = new PlayerStamina(); stamina.Stamina = 1;
            double factor = stamina.SprintMultiplier(.1); stamina.Advance(.1, true);
            check("player_motion_partial_last_sprint_step", factor == 1.25 && stamina.Stamina == 0 && stamina.Exhausted);
            stamina.Advance(.8, false); bool delayed = stamina.Stamina == 0; stamina.Advance(1, false);
            check("player_motion_delayed_exhaustion_recovery", delayed && stamina.Stamina == 25 && !stamina.Exhausted);
            stamina.ConfigureBonuses(30, .30); stamina.Reset(); stamina.Stamina = 120;
            stamina.ConfigureBonuses(0, 0); stamina.ClampCapacity();
            check("player_motion_equipment_reduction_never_refills", stamina.Stamina == 100 && stamina.Capacity == 100);
            stamina.Stamina = 10;
            check("player_motion_invalid_spend_restore_rejected", !stamina.Spend(Double.NaN) && !stamina.Restore(Double.PositiveInfinity) && !stamina.Spend(-1) && !stamina.Restore(0) && stamina.Stamina == 10);
            stamina.Stamina = Double.NaN; stamina.ClampCapacity();
            check("player_motion_corrupt_stamina_clamped", stamina.Stamina == 0);
            var motor = new PlayerMotorModel(); motor.AimDirection = Vector2.right;
            var frame = motor.BeginStep(1.0 / 60, new MotionInput { Direction = Vector2.left, SprintHeld = true, TileName = "grass" });
            motor.CompleteStep(frame, 0, "grass");
            check("player_motion_blocked_sprint_uses_no_energy", motor.Stamina.Stamina == 100 && !motor.Sprinting && motor.StepDistance == 0);
            check("player_motion_body_facing_independent_of_crosshair", motor.Facing == Vector2.left && motor.AimDirection == Vector2.right);
            motor.Stamina.Stamina = 17; motor.Knockback = Vector2.right; motor.TryRoll(Vector2.left);
            motor.StopForTransition();
            check("player_motion_transition_stops_without_stamina_refill", motor.Velocity == Vector2.zero && motor.Knockback == Vector2.zero && !motor.IsRolling && motor.Stamina.Stamina == 17 && motor.RollCooldown == .7);
            motor.RollTimer = .2; motor.RollCooldown = .4; motor.StepDistance = 13;
            frame = motor.BeginStep(10, new MotionInput { Direction = Vector2.right, SprintHeld = true, Paused = true }); motor.CompleteStep(frame, 0, "grass");
            check("player_motion_pause_freezes_timers_and_stamina", motor.RollTimer == .2 && motor.RollCooldown == .4 && motor.Stamina.Stamina == 17 && motor.StepDistance == 13);
            motor.StopForTransition();
            frame = motor.BeginStep(.1, new MotionInput { Direction = Vector2.right, Locked = true }); motor.CompleteStep(frame, 0, "grass");
            check("player_motion_input_lock_freezes_stamina", motor.Stamina.Stamina == 17 && !motor.Moving);
            var footsteps = new PlayerMotorModel();
            frame = footsteps.BeginStep(.1, new MotionInput { Direction = Vector2.right, TileName = "bridge" });
            string sound = footsteps.CompleteStep(frame, 45, "bridge");
            check("player_motion_footsteps_distance_remainder_single_event", sound == "wood" && footsteps.StepDistance == 1);
            bool rejected = false; try { footsteps.CompleteStep(frame, 1, "bridge"); } catch (InvalidOperationException) { rejected = true; }
            check("player_motion_frame_cannot_be_applied_twice", rejected);
            bool invalidDelta = false; try { footsteps.BeginStep(Double.NaN, new MotionInput()); } catch (ArgumentOutOfRangeException) { invalidDelta = true; }
            check("player_motion_nonfinite_delta_rejected", invalidDelta);
            motor.RollTimer = PlayerMotorModel.RollTime - PlayerMotorModel.RollSafeTime;
            bool boundary = !motor.IsRollSafe; motor.RollTimer = .3;
            check("player_motion_roll_safe_window_strict_boundary", boundary && motor.IsRollSafe);
        }
        public static void VerifyOracle(FoundationValue oracle, Action<string, bool> check)
        {
            if (oracle.Require("schema").String != "bluemap.player.motion.source-oracle.v1" ||
                oracle.Require("float64Encoding").String != "ieee754-binary64-little-endian-hex" ||
                oracle.Require("vectorEncoding").String != "ieee754-binary32-xy-little-endian-hex") throw new FormatException("Unsupported original motion oracle.");
            OracleCases = 0;
            bool staminaMatches = true;
            foreach (var row in oracle.Require("stamina").Items)
            {
                var stamina = ReadStamina(row.Require("before"));
                staminaMatches &= Same(stamina.SprintMultiplier(ReadDouble(row, "delta")), ReadDouble(row, "factor"));
                bool result = false;
                switch (row.Require("operation").String)
                {
                    case "advance": stamina.Advance(ReadDouble(row, "delta"), row.Require("sprinting").Bool); break;
                    case "reset": stamina.Reset(); break;
                    case "spend": result = stamina.Spend(ReadDouble(row, "amount")); break;
                    case "restore": result = stamina.Restore(ReadDouble(row, "amount")); break;
                    case "clamp": stamina.ClampCapacity(); break;
                    default: throw new FormatException("Unknown original stamina operation.");
                }
                bool matches = Match(stamina, row.Require("expected")) && result == row.Require("result").Bool;
                if (!matches) Debug.LogError("Original stamina case differs: " + row.Require("id").String);
                staminaMatches &= matches; OracleCases++;
            }
            check("player_motion_stamina_exact_source_oracle", staminaMatches && oracle.Require("stamina").Items.Count == 26);
            bool surfacesMatch = true;
            foreach (var row in oracle.Require("surfaces").Items)
            {
                string tile = row.Require("tile").String;
                surfacesMatch &= Same(PlayerSurface.MovementMultiplier(tile), ReadDouble(row, "multiplier")) && PlayerSurface.FootstepSurface(tile) == row.Require("footstep").String;
                OracleCases++;
            }
            check("player_motion_surfaces_exact_source_oracle", surfacesMatch && oracle.Require("surfaces").Items.Count >= 80);
            bool equipmentMatches = true;
            foreach (var row in oracle.Require("equipment").Items)
            {
                var stamina = ReadStamina(row.Require("before"));
                stamina.Advance(ReadDouble(row, "delta"), false);
                equipmentMatches &= Match(stamina, row.Require("expected")) && Same(PlayerSurface.EquipmentSpeedMultiplier(row.Require("ownsBoots").Bool, ReadDouble(row, "moveBonus")), ReadDouble(row, "speedMultiplier"));
                OracleCases++;
            }
            check("player_motion_equipment_exact_source_oracle", equipmentMatches && oracle.Require("equipment").Items.Count == 8);
            bool motionsMatch = true;
            foreach (var row in oracle.Require("motions").Items)
            {
                var motor = ReadMotor(row.Require("before"), ReadStamina(row.Require("staminaBefore")));
                var input = new MotionInput { Direction = ReadVector(row, "direction"), SprintHeld = row.Require("sprint").Bool,
                    Locked = row.Require("locked").Bool, AttackActive = row.Require("attack").Bool,
                    TileName = row.Require("tile").String, SpeedMultiplier = ReadDouble(row, "speedMultiplier") };
                var frame = motor.BeginStep(ReadDouble(row, "delta"), input);
                string footstep = motor.CompleteStep(frame, ReadDouble(row, "distance"), input.TileName);
                var expected = row.Require("expected");
                bool matches = Match(motor, expected) && Match(motor.Stamina, row.Require("staminaExpected")) &&
                    footstep == (row.Require("footsteps").Items.Count == 0 ? "" : row.Require("footsteps").Items[0].String);
                if (!matches) Debug.LogError("Original motion case differs: " + row.Require("id").String + " velocity=" + motor.Velocity + " expected=" + ReadVector(expected, "velocity") + " walk=" + motor.WalkTime.ToString("R", CultureInfo.InvariantCulture));
                motionsMatch &= matches; OracleCases++;
            }
            check("player_motion_velocity_facing_exact_source_oracle", motionsMatch && oracle.Require("motions").Items.Count == 15);
            bool rollsMatch = true;
            foreach (var row in oracle.Require("rolls").Items)
            {
                var motor = ReadMotor(row.Require("before"), new PlayerStamina());
                motor.TryRoll(ReadVector(row, "direction"));
                rollsMatch &= Match(motor, row.Require("expected")); OracleCases++;
            }
            check("player_motion_roll_exact_source_oracle", rollsMatch && oracle.Require("rolls").Items.Count == 4);
            var transition = oracle.Require("transition");
            var transitioned = ReadMotor(transition.Require("before"), ReadStamina(transition.Require("staminaBefore")));
            transitioned.StopForTransition(); OracleCases++;
            check("player_motion_transition_exact_source_oracle", Match(transitioned, transition.Require("expected")) && Match(transitioned.Stamina, transition.Require("staminaExpected")));
        }
        private static PlayerStamina ReadStamina(FoundationValue source)
        {
            var result = new PlayerStamina { Stamina = ReadDouble(source, "stamina"), RegenDelay = ReadDouble(source, "delay"), Exhausted = source.Require("exhausted").Bool };
            result.ConfigureBonuses(ReadDouble(source, "maxBonus"), ReadDouble(source, "regenBonus"));
            return result;
        }
        private static PlayerMotorModel ReadMotor(FoundationValue source, PlayerStamina stamina)
        {
            var model = new PlayerMotorModel(stamina) { Facing = ReadVector(source, "facing"), AimDirection = ReadVector(source, "aim"), RollDirection = ReadVector(source, "rollDirection"),
                Knockback = ReadVector(source, "knockback"), RollTimer = ReadDouble(source, "rollTimer"), RollCooldown = ReadDouble(source, "rollCooldown"), WalkTime = ReadDouble(source, "walkTime"), StepDistance = ReadDouble(source, "stepDistance") };
            model.RestoreTransientState(ReadVector(source, "velocity"), source.Require("moving").Bool, source.Require("sprinting").Bool);
            return model;
        }
        private static bool Match(PlayerStamina actual, FoundationValue expected) => Same(actual.Stamina, ReadDouble(expected, "stamina")) && Same(actual.RegenDelay, ReadDouble(expected, "delay")) && actual.Exhausted == expected.Require("exhausted").Bool && Same(actual.Capacity, ReadDouble(expected, "capacity")) && Same(actual.RegenRate, ReadDouble(expected, "regenRate")) && Same(actual.RecoveryThreshold, ReadDouble(expected, "threshold")) && actual.CanSprint == expected.Require("canSprint").Bool;
        private static bool Match(PlayerMotorModel actual, FoundationValue expected) => Same(actual.Facing, ReadVector(expected, "facing")) && Same(actual.AimDirection, ReadVector(expected, "aim")) && Same(actual.RollDirection, ReadVector(expected, "rollDirection")) && Same(actual.Knockback, ReadVector(expected, "knockback")) && Same(actual.Velocity, ReadVector(expected, "velocity")) && Same(actual.RollTimer, ReadDouble(expected, "rollTimer")) && Same(actual.RollCooldown, ReadDouble(expected, "rollCooldown")) && Same(actual.WalkTime, ReadDouble(expected, "walkTime")) && Same(actual.StepDistance, ReadDouble(expected, "stepDistance")) && actual.Moving == expected.Require("moving").Bool && actual.Sprinting == expected.Require("sprinting").Bool && actual.IsRollSafe == expected.Require("rollSafe").Bool;
        private static bool Same(double left, double right) => BitConverter.DoubleToInt64Bits(left) == BitConverter.DoubleToInt64Bits(right);
        private static bool Same(Vector2 left, Vector2 right) => BitConverter.SingleToInt32Bits(left.x) == BitConverter.SingleToInt32Bits(right.x) && BitConverter.SingleToInt32Bits(left.y) == BitConverter.SingleToInt32Bits(right.y);
        public static double ReadDouble(FoundationValue source, string field)
        {
            byte[] bytes = Bytes(source.Require(field).String);
            if (!BitConverter.IsLittleEndian) Array.Reverse(bytes);
            double result = BitConverter.ToDouble(bytes, 0);
            if (!PlayerStamina.Finite(result)) throw new FormatException("Nonfinite original motion value.");
            return result;
        }
        public static Vector2 ReadVector(FoundationValue source, string field)
        {
            byte[] bytes = Bytes(source.Require(field).String);
            if (!BitConverter.IsLittleEndian) { Array.Reverse(bytes, 0, 4); Array.Reverse(bytes, 4, 4); }
            var result = new Vector2(BitConverter.ToSingle(bytes, 0), BitConverter.ToSingle(bytes, 4));
            if (!PlayerStamina.Finite(result.x) || !PlayerStamina.Finite(result.y)) throw new FormatException("Nonfinite original motion vector.");
            return result;
        }
        private static byte[] Bytes(string text)
        {
            if (text.Length != 16) throw new FormatException("Original motion value requires eight bytes.");
            var bytes = new byte[8];
            for (int i = 0; i < bytes.Length; i++)
            {
                char a = text[2 * i], b = text[2 * i + 1];
                if (!((a >= '0' && a <= '9') || (a >= 'a' && a <= 'f')) || !((b >= '0' && b <= '9') || (b >= 'a' && b <= 'f'))) throw new FormatException("Noncanonical original motion bytes.");
                bytes[i] = Byte.Parse(text.Substring(i * 2, 2), NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture);
            }
            return bytes;
        }
    }
}
