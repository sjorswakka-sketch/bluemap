using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Probe;
using UnityEngine;

namespace BlueMapMigration.Foundation
{
    [Serializable] public sealed class FoundationProof
    {
        public int schemaVersion = 1;
        public bool success;
        public Phase2Probe.Check[] checks;
        public bool gameSaveAccessed = false;
        public BuildIdentity identity;
    }

    public static class FoundationProbeRunner
    {
        public static FoundationProof Run(BuildIdentity identity)
        {
            var checks = new List<Phase2Probe.Check>();
            Action<string, bool> check = (name, passed) =>
            {
                if (checks.Any(value => value.name == name)) throw new InvalidOperationException("Duplicate foundation check: " + name);
                checks.Add(new Phase2Probe.Check { name = name, passed = passed });
            };
            RunGroup("world", FoundationWorldChecks.Verify, check);
            RunGroup("state", FoundationStateChecks.Verify, check);
            RunGroup("session", FoundationSessionChecks.Verify, check);
            try
            {
                var oracle = Resources.Load<TextAsset>("BlueMapFoundation/state-oracle");
                check("foundation_original_godot_oracle_available", oracle != null);
                if (oracle != null) FoundationStateChecks.VerifyOracle(FoundationJson.Parse(oracle.text), check);
            }
            catch (Exception error) { check("foundation_oracle_execution", false); Debug.LogWarning("Foundation oracle failed: " + error); }
            return new FoundationProof { identity = identity, checks = checks.ToArray(), success = checks.Count >= 10 && checks.All(value => value.passed) };
        }
        private static void RunGroup(string name, Action<Action<string, bool>> verify, Action<string, bool> check)
        {
            bool ran = false;
            try { verify(check); ran = true; }
            catch (Exception error) { Debug.LogWarning("Foundation " + name + " check failed: " + error); }
            check("foundation_" + name + "_checks_ran", ran);
        }
    }
}
