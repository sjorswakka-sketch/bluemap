using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlueMapMigration.Combat;
using BlueMapMigration.Farm;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using BlueMapMigration.Route;
using BlueMapMigration.Story;
using UnityEngine;

namespace BlueMapMigration.Areas
{
    /// <summary>Native proof of the special areas and challenges on a fresh test profile and the real route controller.</summary>
    public static class AreasProbeRunner
    {
        [Serializable]
        public sealed class Result
        {
            public int schemaVersion = 1;
            public BuildIdentity identity;
            public bool success;
            public bool gameSaveAccessed = false;
            public Phase2Probe.Check[] checks = Array.Empty<Phase2Probe.Check>();
        }

        public static Result Last { get; private set; }
        public static PersistenceCoordinator Fixture { get; private set; }

        public static IEnumerator Run(BuildIdentity identity, string output, PlayerWorld world,
            RouteWorldController route, Phase6Catalog catalog)
        {
            Last = new Result { identity = identity };
            var checks = new List<Phase2Probe.Check>();
            void Check(string name, bool passed)
            {
                if (checks.Any(row => row.name == name))
                    throw new InvalidOperationException("Duplicate areas proof " + name);
                checks.Add(new Phase2Probe.Check { name = name, passed = passed });
                Last.checks = checks.ToArray();
                if (!passed) Debug.Log("Areas native check failed: " + name);
            }

            var repository = FoundationWorldRepository.LoadRequired();
            string root = PersistencePaths.Checked(Path.Combine(output, "areas-profiles"));
            if (Directory.Exists(root)) throw new IOException("Fresh areas profile required");
            route.CloseModal();
            Fixture = new PersistenceCoordinator(repository, world.InputSource, root);
            if (!route.BeginNew(Fixture)) throw new IOException(Fixture.Status);
            route.CombatSimulationEnabled = false;
            route.ResidentsSimulationEnabled = false;
            Check("areas_native_shared_state_and_profile", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && route.Encounter != null && route.Combat != null && route.Story != null);

            var live = RunLiveEpisodes(output, repository, world, route, Check);
            while (live.MoveNext()) yield return live.Current;

            Check("areas_no_personal_saves_used", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && PersistencePaths.Within(PersistencePaths.Checked(output), root)
                && !PersistencePaths.Within(PersistencePaths.UnityDefault, root)
                && !PersistencePaths.Within(PersistencePaths.LegacyDefault, root));
            route.CloseModal();
            route.Save();
            Last.success = checks.Count > 5 && checks.All(row => row.passed);
            Last.checks = checks.ToArray();
            File.WriteAllText(Path.Combine(output, "areas-result.json"), JsonUtility.ToJson(Last, true));
            Debug.Log("Areas native proof: " + checks.Count + " checks");
        }

        /// <summary>A bag with the given counts set; used to prepare synthetic test profiles only.</summary>
        static FoundationValue With(FoundationValue inventory, params (string item, long count)[] items)
        { foreach (var row in items) inventory = InventoryModel.Replace(inventory, row.item, FoundationValue.Integer(row.count), row.count <= 0); return inventory; }

        static IEnumerator RunLiveEpisodes(string output, FoundationWorldRepository repository,
            PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var state = route.Gameplay.State;
            bool Travel(string map)
            {
                route.CloseModal();
                var source = repository.Read(map);
                string spawn = source.Arrivals.FirstOrDefault(row => row.Name == "start")?.Name ?? source.Arrivals[0].Name;
                if (!route.TryTravel(map, spawn)) { Debug.Log("Areas detail travel failed: " + map + " " + route.Message); return false; }
                state = route.Gameplay.State; route.Combat.ResetTransient(); route.Tick(0); return true;
            }
            void Stand(Vector2 position)
            { world.Teleport(position); world.Step(0, new MotionInput()); world.FocusCameraOnPlayer(); route.Tick(0); }
            string Kind(RouteTarget t) => StoryModel.G(StoryModel.G(t.Fields, "obj", t.Fields), "kind", StoryModel.S("")).AsString();
            string Id(RouteTarget t) => StoryModel.G(StoryModel.G(t.Fields, "obj", t.Fields), "id", StoryModel.S("")).AsString();
            string Role(RouteTarget t) => StoryModel.G(StoryModel.G(t.Fields, "obj", t.Fields), "role", StoryModel.S("")).AsString();
            RouteTarget Find(Func<RouteTarget, bool> match) => route.Targets.FirstOrDefault(match);
            // Look on the expected map first, then on every map, so a moved object is still found.
            RouteTarget Seek(Func<RouteTarget, bool> match, params string[] maps)
            {
                foreach (string map in maps.Concat(WaterModel.MapIds).Distinct())
                {
                    if (state.MapId != map && !Travel(map)) continue;
                    var found = Find(match); if (found != null) return found;
                }
                return null;
            }
            bool Reach(RouteTarget target)
            { if (target == null) return false; route.CloseModal(); Stand(target.Position + new Vector2(0, 34)); route.Tick(0); return route.InteractTarget(target.Address); }
            void Ticks(double seconds, double step = .1) { for (double t = 0; t < seconds - 1e-9; t += step) route.Tick(step); }
            void Flags(params (string id, bool value)[] rows) { foreach (var row in rows) state.SetFlag(row.id, row.value); route.Tick(0); }
            void Kill(Func<EncounterActor, bool> which) { foreach (var actor in route.Encounter.Actors) if (!actor.Dead && which(actor)) { actor.Dead = true; actor.Active = false; } }
            void Detail(string name, params (string key, object value)[] parts)
                => Debug.Log("Areas detail " + name + ": " + String.Join(" ", parts.Select(part => part.key + "=" + part.value)));
            int captures = 0;
            void Capture(string name)
            {
                string path = Path.Combine(output, "screenshot-areas-" + name + ".png");
                if (File.Exists(path)) throw new IOException("Fresh areas capture required");
                var image = ScreenCapture.CaptureScreenshotAsTexture();
                try
                {
                    if (image.width != 1152 || image.height != 648) throw new InvalidOperationException("Areas viewport differs");
                    File.WriteAllBytes(path, image.EncodeToPNG()); captures++;
                }
                finally { UnityEngine.Object.Destroy(image); }
            }
            bool Is(RouteTarget t, string script, string kind) => t.Kind == script && Kind(t) == kind;

            // --- Marsh sluices: west open and east closed lowers the water ---
            var west = Seek(t => Is(t, "living_object", "sluice") && Id(t) == "lw_sluice_west", "kruipmoeras");
            Flags(("lw_drained", false), ("lw_sluice_west", false), ("lw_sluice_east", true), ("lw_sluice_west_seen", false), ("lw_sluice_east_seen", false));
            RouteTarget Sluice(string id) => Find(t => Is(t, "living_object", "sluice") && Id(t) == id);
            var east = Sluice("lw_sluice_east");
            bool opened = Reach(west) && state.Flag("lw_sluice_west") && state.Flag("lw_sluice_west_seen") && !state.Flag("lw_drained") && state.QuestState("wilgentwijgen") == "active";
            route.Tick(0); route.Tick(0); bool label = Sluice("lw_sluice_west") != null && Sluice("lw_sluice_west").Label.Contains(route.Translate("open"));
            bool drained = Reach(Sluice("lw_sluice_east")) && !state.Flag("lw_sluice_east") && state.Flag("lw_drained"); route.Tick(0); route.Tick(0);
            // Once the water is safe, using a sluice again changes nothing.
            if (Sluice("lw_sluice_east") != null) Reach(Sluice("lw_sluice_east")); if (Sluice("lw_sluice_west") != null) Reach(Sluice("lw_sluice_west"));
            bool settled = !state.Flag("lw_sluice_east") && state.Flag("lw_sluice_west") && state.Flag("lw_drained");
            if (!(opened && label && drained && settled)) Detail("sluices", ("west", west != null), ("east", east != null), ("opened", opened), ("label", label), ("drained", drained), ("settled", settled), ("map", state.MapId), ("label", Sluice("lw_sluice_west")?.Label), ("eastNow", Sluice("lw_sluice_east") != null));
            check("areas_native_sluices_drain_the_marsh", opened && label && drained && settled);
            route.Tick(0); yield return new WaitForEndOfFrame(); Capture("marsh");

            // --- The winch needs the lowered water, then a repair kit ---
            var winch = Find(t => Is(t, "living_object", "bridge"));
            state.Set("inventory", With(state.Get("inventory"), ("lw_bridge_kit", 1)));
            bool winchTalk = Reach(winch) && route.Gameplay.DialogueOpen; route.CloseModal();
            bool repaired = route.ChooseAreaAction("bridge_kit") && state.Flag("lw_bridge") && state.Count("lw_bridge_kit") == 0;
            if (!(winchTalk && repaired)) Detail("winch", ("found", winch != null), ("talk", winchTalk), ("repaired", repaired));
            check("areas_native_winch_repairs_the_bridge", winchTalk && repaired);

            // --- Prism mirrors, the core and the grounding powder ---
            var mirrorB = Seek(t => Is(t, "living_object", "mirror") && Id(t) == "lw_mirror_b", "prismamine");
            foreach (string mirror in new[] { "lw_mirror_a", "lw_mirror_b", "lw_mirror_c" }) for (int i = 1; i < 4; i++) state.SetFlag(mirror + "_turn_" + i, false);
            Flags(("lw_mine", false), ("lw_beams", false));
            var mirrorC = Find(t => Is(t, "living_object", "mirror") && Id(t) == "lw_mirror_c"); var core = Find(t => Is(t, "living_object", "core"));
            bool turned = Reach(mirrorB) && route.MirrorDirection("lw_mirror_b") == 1 && !route.BeamsReady() && Reach(mirrorC) && Reach(mirrorC) && route.MirrorDirection("lw_mirror_c") == 2 && route.BeamsReady() && state.Flag("lw_beams");
            state.Set("inventory", With(state.Get("inventory"), ("lw_powder", 1)));
            bool coreTalk = Reach(core) && route.Gameplay.DialogueOpen; route.CloseModal();
            bool stable = route.ChooseAreaAction("core_powder") && state.Flag("lw_mine") && state.Count("lw_lens") == 1 && state.Count("lw_powder") == 0;
            if (!(turned && coreTalk && stable)) Detail("prism", ("b", mirrorB != null), ("c", mirrorC != null), ("core", core != null), ("turned", turned), ("talk", coreTalk), ("stable", stable));
            check("areas_native_mirrors_core_and_powder", turned && coreTalk && stable);

            // --- A brazier is fuelled, defended for twenty seconds and keeps the house warm ---
            var brazier = Seek(t => Is(t, "living_object", "brazier"), "ijsdal");
            string heat = brazier == null ? "" : Id(brazier);
            Flags((heat, false), (heat + "_fuel", false));
            state.Set("inventory", With(state.Get("inventory"), ("prof_branch", 3)));
            bool brazierTalk = Reach(brazier) && route.Gameplay.DialogueOpen; route.CloseModal();
            bool lit = route.ChooseAreaAction("heat_wood") && state.Flag(heat + "_fuel") && state.Count("prof_branch") == 0 && route.AreaActive(brazier);
            Ticks(2.3);
            bool attacked = route.AreaFoes(brazier) == 2;
            Kill(actor => actor.Kind.StartsWith("lw_", StringComparison.Ordinal)); Ticks(20.5, .25);
            bool warm = state.Flag(heat) && !route.AreaActive(brazier) && state.QuestState("warmte") != "none";
            if (!(brazierTalk && lit && attacked && warm)) Detail("brazier", ("found", brazier != null), ("talk", brazierTalk), ("lit", lit), ("attacked", attacked), ("warm", warm), ("foes", route.AreaFoes(brazier)), ("id", heat));
            check("areas_native_brazier_is_fuelled_and_defended", brazierTalk && lit && attacked && warm);

            // --- The hot spring restores one heart while you stand still ---
            if (state.MapId != "ijsdal") Travel("ijsdal");
            var spring = WaterModel.Describe("ijsdal").FirstOrDefault(feature => feature.Kind == "hot_spring");
            bool healed = false;
            if (spring != null)
            {
                Stand(spring.Center + new Vector2(0, 60)); Kill(actor => Vector2.Distance(actor.Position, world.Position) < 260);
                state.Hp = state.MaxHp - 2; long before = state.Hp; Ticks(14.5, .25); bool waited = state.Hp == before; Ticks(1, .25);
                healed = waited && state.Hp == before + 1 && route.HotSpringRest < 1;
                if (!healed) Detail("spring", ("hp", state.Hp), ("before", before), ("rest", route.HotSpringRest), ("near", WaterModel.Nearest("ijsdal", world.Position, 76).Kind));
                state.Hp = state.MaxHp;
            }
            check("areas_native_hot_spring_restores_a_heart", healed);

            // --- The desert: waterskin, heat, shelter and the spring choice ---
            var nour = Seek(t => Is(t, "regional_object", "water"), "dorstvallei");
            Flags(("ra_spring", false), ("ra_prepared", false), ("ra_water_wild", false), ("ra_water_caravan", false));
            bool prepared = Reach(nour) && state.Count("ra_waterskin") == 1 && state.Flag("ra_prepared") && state.QuestState("cactusvijgen") != "none"; route.CloseModal();
            var well = Seek(t => Is(t, "regional_object", "spring"), "sunwell");
            Stand(new Vector2(20.5f, 12.5f) * 32); Ticks(6.2);
            bool sip = route.RegionWater == 2 && route.RegionStatus.Contains("2/3");
            Ticks(12.4); bool dry = route.RegionWater == 0; var hot = world.Position; Ticks(6.2);
            bool rescued = route.RegionWater == 3 && Vector2.Distance(world.Position, hot) > 64;
            bool springTalk = Reach(well) && route.Gameplay.DialogueOpen; route.CloseModal();
            bool flowing = route.ChooseRegional("wild") && state.Flag("ra_spring") && state.Flag("ra_water_wild") && !state.Flag("ra_water_caravan");
            route.Tick(.1); bool cool = route.RegionStatus == route.Translate("De bron stroomt — de kloof is koel");
            if (!(prepared && sip && dry && rescued && springTalk && flowing && cool)) Detail("desert", ("nour", nour != null), ("well", well != null), ("prepared", prepared), ("sip", sip), ("dry", dry), ("rescued", rescued), ("talk", springTalk), ("flowing", flowing), ("cool", cool), ("water", route.RegionWater), ("status", route.RegionStatus));
            check("areas_native_desert_water_heat_and_spring", prepared && sip && dry && rescued && springTalk && flowing && cool);

            // --- The windy pass: a gust pushes you back until the rope is fixed ---
            var camp = Seek(t => Is(t, "regional_object", "camp"), "ridgepass");
            Flags(("ra_rope", false), ("ra_rope_kit", false), ("ra_chart", false), ("ra_ridge_done", false));
            var anchor = Find(t => Is(t, "regional_object", "anchor")); var chart = Find(t => Is(t, "regional_object", "chart"));
            var pass = new Vector2(14.5f, 6f) * 32; Stand(pass);
            while (route.WindPhase != 2) route.Tick(.1);
            Stand(pass); Ticks(.8);
            bool gust = Vector2.Distance(world.Position, pass) > 64;
            bool noKit = Reach(anchor) && !state.Flag("ra_rope"); route.CloseModal();
            bool kit = Reach(camp) && state.Flag("ra_rope_kit"); route.CloseModal();
            bool roped = Reach(anchor) && state.Flag("ra_rope");
            Stand(pass); while (route.WindPhase != 2) route.Tick(.1); Stand(pass); Ticks(.8);
            bool safe = Vector2.Distance(world.Position, pass) < 1;
            bool charted = Reach(chart) && state.Flag("ra_chart"); route.CloseModal();
            bool reward = Reach(camp) && state.Flag("ra_ridge_done") && state.Count("gear_ra_grip") == 1; route.CloseModal();
            if (!(gust && noKit && kit && roped && safe && charted && reward)) Detail("ridge", ("camp", camp != null), ("anchor", anchor != null), ("chart", chart != null), ("gust", gust), ("noKit", noKit), ("kit", kit), ("roped", roped), ("safe", safe), ("charted", charted), ("reward", reward));
            check("areas_native_windy_pass_rope_and_chart", gust && noKit && kit && roped && safe && charted && reward);

            // --- The reed archive: three reliefs and their order ---
            var desk = Seek(t => Is(t, "regional_object", "desk"), "reedvault");
            Flags(("ra_archive_done", false), ("ra_folio_reed", false), ("ra_folio_port", false), ("ra_folio_flood", false), ("ra_exhibit_routes", false));
            bool early = Reach(desk) && route.Gameplay.DialogueOpen; route.CloseModal();
            bool read = true; foreach (var folio in route.Targets.Where(t => Is(t, "regional_object", "folio")).ToArray()) { read &= Reach(folio) && state.Flag(Id(folio)); route.CloseModal(); }
            bool order = Reach(desk) && route.Gameplay.DialogueOpen; route.CloseModal();
            bool wrong = route.ChooseRegional("wrong") && !state.Flag("ra_archive_done");
            bool right = route.ChooseRegional("correct") && state.Flag("ra_archive_done") && state.Flag("ra_exhibit_routes") && state.Count("gear_ra_compass") == 1;
            bool stories = route.ChooseRegional("stories") && !state.Flag("ra_exhibit_routes");
            if (!(early && read && order && wrong && right && stories)) Detail("archive", ("desk", desk != null), ("early", early), ("read", read), ("order", order), ("wrong", wrong), ("right", right), ("stories", stories));
            check("areas_native_reed_archive_order", early && read && order && wrong && right && stories);

            // --- The resonance trial: three waves and a permanent reward ---
            var trial = Seek(t => t.Kind == "echo_trial", "resonance");
            Flags(("echo_trial_won", false)); long coins = state.Coins;
            Stand(new Vector2(16.5f, 14.5f) * 32);
            bool begun = trial != null && route.InteractTarget(trial.Address) || Reach(trial);
            begun &= route.EchoTrialActive; Stand(new Vector2(16.5f, 14.5f) * 32);
            int waves = 0, guard = 0;
            while (route.EchoTrialActive && guard++ < 600)
            {
                route.Tick(.1); int wave = route.EchoWave; if (wave > waves) waves = wave;
                Kill(actor => actor.Kind == "crystal_beetle" || actor.Kind == "prism_moth");
            }
            bool won = waves == 3 && !route.EchoTrialActive && state.Flag("echo_trial_won") && state.Count("gear_crystal_amulet") == 1 && state.Coins == coins + 120;
            bool again = Reach(trial) && !route.EchoTrialActive && route.Gameplay.DialogueOpen; route.CloseModal();
            if (!(begun && won && again)) Detail("echo", ("found", trial != null), ("begun", begun), ("waves", waves), ("won", won), ("again", again), ("coins", state.Coins - coins));
            check("areas_native_resonance_trial_three_waves", begun && won && again);

            // --- The arena: sign up, win bronze, give up, be defeated without a game over ---
            foreach (string rank in new[] { "bronze", "silver", "gold" }) { state.SetFlag("arena_signed_" + rank, false); state.SetFlag("arena_" + rank + "_done", false); }
            state.Set("coins", FoundationValue.Integer(100)); state.Set("arena_records", InventoryModel.Empty());
            bool locked = !route.ArenaRegister("silver") && state.Coins == 100;
            bool signed = route.ArenaRegister("bronze") && state.Coins == 90 && route.ArenaRegistered() == "bronze" && !route.ArenaRegister("bronze");
            bool refund = route.ArenaCancel() && state.Coins == 100 && route.ArenaRegistered() == "" && route.ArenaRegister("bronze");
            Travel("arena"); route.Tick(0);
            bool intro = route.ArenaPhase == "intro" && route.Access.ArenaRunActive && route.ArenaBannerTitle != "";
            bool shot = false; int rounds = 0; guard = 0;
            while (route.ArenaPhase != "done" && route.ArenaPhase != "idle" && guard++ < 1500)
            {
                route.Tick(.1); rounds = Math.Max(rounds, route.ArenaRound + 1);
                if (!shot && route.ArenaPhase == "fight" && route.ArenaFoesLeft > 0 && route.Encounter.Actors.Any(a => !a.Dead && a.Active))
                { shot = true; Stand(new Vector2(12.5f, 12.5f) * 32); yield return new WaitForEndOfFrame(); Capture("arena"); }
                Kill(actor => actor.Active);
            }
            bool champion = route.ArenaPhase == "done" && rounds == 3 && !route.Access.ArenaRunActive && state.Flag("arena_bronze_done") && state.Count("arena_trophy_bronze") == 1
                && state.Coins == 140 && route.ArenaBest("bronze") > 0 && route.ArenaUnlocked("silver") && route.ArenaRegistered() == "";
            double best = route.ArenaBest("bronze");
            Travel("arena_hall"); bool silver = route.ArenaRegister("silver") && state.Coins == 115;
            Travel("arena"); route.Tick(0); Ticks(3.4);
            bool fighting = route.ArenaPhase == "fight" && route.ArenaStatus != "";
            bool quit = route.ArenaForfeit() && route.ArenaPhase == "defeat"; Ticks(2.4);
            bool hall = state.MapId == "arena_hall" && state.Flag("arena_just_quit") && !route.Access.ArenaRunActive && route.ArenaRegistered() == "" && !state.Transitioning;
            route.ArenaRegister("bronze"); Travel("arena"); route.Tick(0); Ticks(3.4);
            state.Hp = 0; bool caught = route.Combat.DefeatHandler != null && route.Combat.DefeatHandler() && !state.Ended; Ticks(2.4);
            bool revived = state.MapId == "arena_hall" && state.Hp == state.MaxHp && state.Flag("arena_just_lost") && !state.Ended && route.ArenaBest("bronze") == best;
            var board = Find(t => t.Kind == "arena_board" && StoryModel.G(StoryModel.G(t.Fields, "obj", t.Fields), "board", StoryModel.S("")).AsString() == "scores");
            bool scores = Reach(board) && route.Gameplay.DialogueOpen; route.CloseModal();
            if (!(locked && signed && refund && intro && champion && silver && fighting && quit && hall && caught && revived && scores))
                Detail("arena", ("locked", locked), ("signed", signed), ("refund", refund), ("intro", intro), ("champion", champion), ("rounds", rounds), ("phase", route.ArenaPhase), ("coins", state.Coins), ("silver", silver), ("fighting", fighting), ("quit", quit), ("hall", hall), ("caught", caught), ("revived", revived), ("scores", scores), ("map", state.MapId));
            check("areas_native_arena_win_forfeit_and_defeat", locked && signed && refund && intro && champion && silver && fighting && quit && hall && caught && revived && scores);

            // --- Coastal adventures: the log, the pilot route, the tide wheel and the keeper ---
            foreach (string flag in new[] { "ad_splinter", "ad_silt", "ad_message_done", "ad_pilot_done", "ad_wheel_done", "ad_keeper_done", "ad_pool", "ad_workwater", "ad_duel" }) state.SetFlag(flag, false);
            var log = Seek(t => t.Kind == "coastal_adventure" && Role(t) == "message", "coast", "gull_island", "harbor");
            bool logRead = Reach(log) && route.Modal == "garden_menu" && state.QuestState("ad_message") == "active"; route.CloseModal();
            var splinter = Seek(t => t.Kind == "coastal_adventure" && Role(t) == "splinter", "gull_island", "coast");
            bool noted = Reach(splinter) && route.GardenMenu.Choose("record:ad_splinter") && state.Flag("ad_splinter") && !route.GardenMenu.Enabled("record:ad_splinter"); route.CloseModal();
            var silt = Seek(t => t.Kind == "coastal_adventure" && Role(t) == "silt", "river_mouth", "coast");
            noted &= Reach(silt) && route.GardenMenu.Choose("record:ad_silt") && state.Flag("ad_silt") && state.QuestStep("ad_message") == 1; route.CloseModal();
            var record = Seek(t => t.Kind == "coastal_adventure" && Role(t) == "record", "harbor");
            bool mistake = Reach(record) && route.GardenMenu.Choose("deduce:no") && !state.Flag("ad_message_done") && route.Modal == "garden_menu";
            bool marked = route.GardenMenu.Choose("deduce:yes") && state.Flag("ad_message_done") && state.QuestState("ad_message") == "done";
            yield return new WaitForEndOfFrame(); bool menuFits = route.GardenMenu.LayoutFits && route.GardenMenu.BodyFits; Capture("coast"); route.CloseModal();
            if (!(logRead && noted && mistake && marked && menuFits)) Detail("message", ("log", log != null), ("splinter", splinter != null), ("silt", silt != null), ("record", record != null), ("read", logRead), ("noted", noted), ("mistake", mistake), ("marked", marked), ("fits", menuFits));
            check("areas_native_coast_log_evidence_and_deduction", logRead && noted && mistake && marked && menuFits);

            var wheel = Seek(t => t.Kind == "coastal_adventure" && Role(t) == "wheel", "tidal_hollow");
            bool wheelMenu = Reach(wheel) && route.GardenMenu.Enabled("repair");
            bool working = route.GardenMenu.Choose("repair") && route.CoastWorking && route.Modal == ""; Ticks(1.9);
            bool turning = !route.CoastWorking && state.Flag("ad_wheel_done") && state.QuestState("ad_wheel") == "done" && state.MapId == "tidal_hollow";
            var table = Find(t => t.Kind == "coastal_adventure" && Role(t) == "sluice");
            bool duel = Reach(table) && route.GardenMenu.Choose("choose:duel") && state.Flag("ad_duel"); Ticks(.3);
            bool keeper = route.CoastKeeperPresent;
            bool peace = Reach(table) && route.GardenMenu.Choose("choose:peace") && state.Flag("ad_pool") && state.Flag("ad_keeper_done") && !state.Flag("ad_duel"); Ticks(.3);
            bool calm = !route.CoastKeeperPresent && state.QuestState("ad_keeper") == "done";
            if (!(wheelMenu && working && turning && duel && keeper && peace && calm)) Detail("wheel", ("wheel", wheel != null), ("table", table != null), ("menu", wheelMenu), ("working", working), ("turning", turning), ("duel", duel), ("keeper", keeper), ("peace", peace), ("calm", calm), ("map", state.MapId));
            check("areas_native_tide_wheel_and_shell_keeper", wheelMenu && working && turning && duel && keeper && peace && calm);

            // --- Raf's workshop: furniture and the reusable shore line ---
            var layout = Seek(t => t.Kind == "coastal_workstation" && (Role(t) == "layout" || Role(t) == "shelf" || Role(t) == "lamp"), "coast_workshop");
            state.Set("inventory", With(state.Get("inventory"), ("cw_shelf", 1), ("cw_lamp", 1), ("cw_hook", 1)));
            Flags(("cw_shelf_placed", false), ("cw_lamp_on", false), ("cw_lamp_sea", false));
            bool furnished = Reach(layout) && route.GardenMenu.Choose("shelf") && state.Flag("cw_shelf_placed") && route.GardenMenu.Choose("lamp:2") && state.Flag("cw_lamp_on") && state.Flag("cw_lamp_sea")
                && route.GardenMenu.Choose("lamp:0") && !state.Flag("cw_lamp_on") && !state.Flag("cw_lamp_sea"); route.CloseModal();
            var line = Seek(t => t.Kind == "coastal_workstation" && Role(t) == "line", "river_mouth");
            var shore = world.Position;
            bool crossing = Reach(line) && route.GardenMenu.Choose("cross") && route.CoastWorking; shore = world.Position; Ticks(1.3);
            bool landed = !route.CoastWorking && Vector2.Distance(world.Position, shore) > 64 && state.Count("cw_hook") == 1;
            if (!(furnished && crossing && landed)) Detail("workshop", ("layout", layout != null), ("line", line != null), ("furnished", furnished), ("crossing", crossing), ("landed", landed), ("moved", Vector2.Distance(world.Position, shore)));
            check("areas_native_workshop_furniture_and_shore_line", furnished && crossing && landed);

            // --- Bow targets and Tessa's shooting range ---
            Travel("village"); route.Tick(0);
            Flags(("boog_range_won", false)); route.Story.StartQuest("boog_schietbaan"); route.Tick(0);
            var boards = route.BowTargets.Where(t => t.RangeId != "").ToArray();
            bool ready = boards.Length == 3 && route.StartRange() && route.RangeLendsArrows && !route.StartRange(); Ticks(3.2);
            bool running = route.RangeState == "run" && route.RangeStatus != "";
            foreach (var target in boards) { route.Encounter.SpawnArrow(new CombatArrow { Position = target.Center, Direction = new Vector2(1, 0), LaunchDistance = 0 }); route.Tick(.05); }
            route.Tick(.05);
            bool rangeWon = route.RangeState == "won" && route.RangeHits == 3 && !route.RangeLendsArrows && (state.Flag("boog_range_won") || state.QuestState("boog_schietbaan") != "active");
            Travel("forest"); route.Tick(0);
            var forest = route.BowTargets.Where(t => t.Sets != "").ToArray(); foreach (var target in forest) state.SetFlag(target.Sets, false);
            foreach (var target in forest) { route.Encounter.SpawnArrow(new CombatArrow { Position = target.Center, Direction = new Vector2(1, 0), LaunchDistance = 0 }); route.Tick(.05); }
            bool doors = forest.Length == 2 && forest.All(t => state.Flag(t.Sets));
            if (!(ready && running && rangeWon && doors)) Detail("bow", ("boards", boards.Length), ("ready", ready), ("running", running), ("won", rangeWon), ("state", route.RangeState), ("hits", route.RangeHits), ("forest", forest.Length), ("doors", doors));
            check("areas_native_bow_targets_and_shooting_range", ready && running && rangeWon && doors);

            // --- Services asked for in a conversation: ferry destinations and the coast overview ---
            Travel("harbor"); route.Tick(0);
            bool ferry = route.OpenNearestVoyage() && route.Modal == "boat" && route.VoyageRoutes.Count > 0; route.CloseModal();
            bool atlas = route.OpenCoastAtlas() && route.Modal == "garden_menu" && route.GardenMenu.Body.Contains(route.Translate("Je bent hier: %s.").Split('%')[0]);
            route.Tick(0); bool stays = route.Modal == "garden_menu";
            yield return new WaitForEndOfFrame(); bool atlasFits = route.GardenMenu.LayoutFits && route.GardenMenu.BodyFits; route.CloseModal();
            if (!(ferry && atlas && stays && atlasFits)) Detail("services", ("ferry", ferry), ("atlas", atlas), ("stays", stays), ("fits", atlasFits));
            check("areas_native_ferry_and_coast_overview", ferry && atlas && stays && atlasFits);

            // --- A profile reload keeps every choice ---
            bool reloaded = route.Save() && route.Reload(false); route.Tick(0); state = route.Gameplay.State;
            bool kept = reloaded && state.Flag("lw_drained") && state.Flag("lw_bridge") && state.Flag("lw_mine") && state.Flag("ra_spring") && state.Flag("ra_rope") && state.Flag("ra_archive_done")
                && state.Flag("echo_trial_won") && state.Flag("arena_bronze_done") && route.ArenaBest("bronze") == best && state.Flag("ad_pool") && state.Flag("ad_message_done") && !route.Access.ArenaRunActive;
            if (!kept) Detail("reload", ("reloaded", reloaded), ("best", route.ArenaBest("bronze")), ("was", best));
            check("areas_native_reload_keeps_choices", kept);
            check("areas_native_three_rendered_captures", captures == 3);
        }
    }
}
