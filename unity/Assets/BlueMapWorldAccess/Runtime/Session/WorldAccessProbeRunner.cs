using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using BlueMapMigration.Route;
using BlueMapMigration.Persistence;
using BlueMapMigration.Probe;
namespace BlueMapMigration.WorldAccess
{
    // Synthetic saves only. The original world remains the oracle for every doorway.
    public static class WorldAccessProbeRunner
    {
        [Serializable] public sealed class Result
        {
            public int schemaVersion=1;
            public bool success,gameSaveAccessed=false;
            public BuildIdentity identity;
            public int maps {get;set;}
            public int portalCases {get;set;}
            public int portalCrossings {get;set;}
            public int boatCrossings {get;set;}
            public Phase2Probe.Check[] checks;
        }
        public static Result Last {get;private set;}
        public static PersistenceCoordinator Fixture {get;private set;}
        static IEnumerable<FoundationValue> Nodes(FoundationWorldSnapshot snapshot,string kind)=>snapshot.Root.Require("scene").Items.Where(n=>n.TryGet("script",out var s)&&s.Kind=="string"&&s.AsString().EndsWith("/"+kind+".gd",StringComparison.Ordinal));
        static Vector2 Pos(FoundationValue node)=>FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin"));
        static string Spawn(FoundationWorldSnapshot snapshot)=>snapshot.Arrivals.FirstOrDefault(v=>v.Name=="start")?.Name??snapshot.Arrivals[0].Name;
        static FoundationValue Plain(string value)=>FoundationJson.ParsePlain(value);
        static void At(PlayerWorld world,Vector2 pos){world.Teleport(pos);world.Step(0,new MotionInput{Direction=Vector2.zero});}
        static void Satisfy(FoundationGameState state,FoundationValue tests)
        {
            foreach(var test in tests.Items)
            {
                string kind=test.Items[0].AsString();
                if(kind=="flag")state.SetFlag(test.Items[1].AsString(),true);
                else if(kind=="no_flag")state.SetFlag(test.Items[1].AsString(),false);
                else if(kind=="has")state.Set("inventory",WorldAccessModel.Replace(state.Get("inventory"),test.Items[1].AsString(),FoundationValue.Integer(test.Items.Count>2?test.Items[2].AsInt64():1)));
                else if(kind=="echo_ready"||kind=="arena_open"){state.Weapon="iron";state.Set("quests",WorldAccessModel.Replace(state.Get("quests"),"main",Plain("{\"state\":\"active\",\"step\":0}")));}
                else if(kind=="arena_registered")state.SetFlag("arena_signed_bronze",true);
            }
        }
        public static IEnumerator Run(BuildIdentity identity,string output,PlayerWorld world,RouteWorldController route,BlueMapMigration.Phase6.Phase6Catalog catalog)
        {
            Last=new Result{identity=identity};var checks=new List<Phase2Probe.Check>();
            void Check(string name,bool passed){checks.Add(new Phase2Probe.Check{name=name,passed=passed});if(!passed)Debug.Log("World access failed: "+name);}
            var repository=FoundationWorldRepository.LoadRequired();
            Debug.Log("World access stage: original source model");WorldAccessChecks.Verify(repository,Check);
            Check("world_access_source_oracle_complete",WorldAccessChecks.OracleSnapshots==162&&WorldAccessChecks.OracleProbes>800&&checks.All(c=>c.passed));
            Debug.Log("World access stage: art identities");WorldAccessPresentationChecks.Verify(catalog,repository,Check);
            Debug.Log("World access stage: native GPU pixels");WorldAccessPresentationChecks.VerifyGpu(catalog,Check);
            Check("world_access_original_art_preserved",FoundationJson.ParsePlain(Resources.Load<TextAsset>(RouteSourcePresentation.ResourcePath).text).Require("nodes").Items.Count==104&&checks.Where(c=>c.name.StartsWith("world_art_")).All(c=>c.passed));
            Check("world_access_all_37_maps_available",repository.MapIds.Count==37&&RouteWorldController.Maps.OrderBy(v=>v).SequenceEqual(repository.MapIds.OrderBy(v=>v)));
            route.CloseModal();Fixture?.Dispose();Fixture=new PersistenceCoordinator(repository,world.InputSource,Path.Combine(output,"world-access-profiles"));
            route.BeginNew(Fixture);var state=route.Gameplay.State;
            state.Set("future_world_access",Plain("{\"kind\":\"preserved\",\"amount\":9007199254740993}"));
            state.Coins=91;string inventory=FoundationJson.StringifyPlain(state.Get("inventory")),initialFlags=FoundationJson.StringifyPlain(state.Get("flags"));bool mapsFit=true,mapArt=true;
            Debug.Log("World access stage: live 37 maps");foreach(string map in repository.MapIds)
            {
                bool entered=route.TryTravel(map,Spawn(repository.Read(map)));if(entered){Last.maps++;mapsFit&=route.Access.SpawnFits(route.Session.Current,world.Position);mapArt&=world.RoutePresentation!=null&&world.RoutePresentation.Objects.Count>0&&world.Snapshot.MapId==map&&route.Session.State.MapId==map;}
                else {mapsFit=false;mapArt=false;Debug.Log("World native entry failed: "+map+" / "+route.Message);}
                yield return null;
            }
            Check("world_render_all_37_source_maps",Last.maps==37&&mapArt);
            Check("world_access_native_arrivals_fit",mapsFit&&Last.maps==37);
            Check("world_access_safe_arrivals",mapsFit&&Last.maps==37&&checks.Where(c=>c.name=="world_access_source_safe_arrivals"||c.name=="world_access_source_safe_spawn_search").All(c=>c.passed));
            Check("world_access_no_fixture_state_injected",state.Coins==91&&FoundationJson.StringifyPlain(state.Get("inventory"))==inventory&&FoundationJson.StringifyPlain(state.Get("flags"))==initialFlags&&state.Get("future_world_access").Require("amount").AsInt64()==9007199254740993L);
            Check("world_access_visits_record_actual_37_maps",state.Get("visited_maps").Entries.Count(e=>e.Value.AsBool())==37);
            string stableState=FoundationJson.StringifyPlain(state.Snapshot());var stableArea=route.Session.Current;string stableRevision=Fixture.Current.RevisionId;
            bool refused=!route.TryTravel("__unknown__","start")&&!route.TryTravel("forest","__unknown__");route.OpenPause();refused&=!route.TryTravel("forest",Spawn(repository.Read("forest")));route.CloseModal();
            Check("world_access_failed_travel_is_atomic",refused&&ReferenceEquals(stableArea,route.Session.Current)&&stableRevision==Fixture.Current.RevisionId&&stableState==FoundationJson.StringifyPlain(state.Snapshot()));
            bool gateChecked=false;
            foreach(string gateMap in repository.MapIds)
            {
                var sourceGate=Nodes(repository.Read(gateMap),"gate").FirstOrDefault(n=>WorldAccessModel.Get(n.Require("fields"),"key_item",FoundationValue.StringValue("")).AsString()!="");if(sourceGate==null)continue;
                route.TryTravel(gateMap,Spawn(repository.Read(gateMap)));var target=route.Targets.First(t=>t.Kind=="gate"&&t.Address==RouteSourcePresentation.Address(sourceGate));At(world,target.Position+new Vector2(-28,0));
                string key=target.Fields.Require("key_item").AsString();int Feet()=>world.GetComponentsInChildren<Collider2D>().Count(c=>c.gameObject.name.Contains("/gate.gd"));
                int beforeFeet=Feet();bool denied=!route.InteractTarget(target.Address)&&route.Access.GateBlocked(target.Fields);state.Set("inventory",WorldAccessModel.Replace(state.Get("inventory"),key,FoundationValue.Integer(2)));
                bool opened=route.InteractTarget(target.Address);int afterFeet=Feet();bool duplicate=!route.InteractTarget(target.Address);
                gateChecked=denied&&opened&&duplicate&&state.Count(key)==1&&!route.Access.GateBlocked(target.Fields)&&beforeFeet>afterFeet;break;
            }
            Check("world_access_native_gate_key_and_collision",gateChecked);
            state.SetFlag("lw_heat_east",true);state.SetFlag("lw_heat_west",false);route.TryTravel("ijsdal",Spawn(repository.Read("ijsdal")));string WestTiles(FoundationWorldSnapshot snapshot)=>String.Concat(Enumerable.Range(12,2).SelectMany(y=>Enumerable.Range(10,6).Select(x=>snapshot.MapData.Require("rows").Items[y].AsString()[x])));string beforeIce=WestTiles(route.Session.Current);state.SetFlag("lw_heat_west",true);bool thawRefreshed=route.RefreshAccessGeometry();string afterIce=WestTiles(route.Session.Current);
            Check("world_access_native_independent_heat_refresh",thawRefreshed&&beforeIce==WestTiles(repository.Read("ijsdal"))&&afterIce==WestTiles(repository.Read("ijsdal","ice_restored"))&&beforeIce!=afterIce);
            state.SetFlag("game_completed",false);state.SetFlag("diepte_opened",false);route.TryTravel("temple",Spawn(repository.Read("temple")));var seal=route.Targets.First(t=>t.Kind=="diepte_seal");var sealSpec=WorldAccessModel.Get(seal.Fields,"obj",seal.Fields);var sealSize=sealSpec.Require("size");Vector2 sealCenter=seal.Position+new Vector2(((float)sealSize.Items[0].AsDouble()-1)*16,((float)sealSize.Items[1].AsDouble()-1)*16);
            At(world,sealCenter+new Vector2(0,80));route.Tick(.02);bool unearned=!state.Flag("diepte_opened");state.SetFlag("game_completed",true);route.Tick(.01);bool breaking=route.Access.SealBreaking(sealCenter);route.OpenPause();route.Tick(1.81);bool sealOpened=state.Flag("diepte_opened")&&state.QuestState("diepte")=="active"&&state.QuestStep("diepte")==1;bool sealHidden=world.RoutePresentation.Objects.TryGetValue(seal.Address,out var plate)&&!plate.activeSelf;route.CloseModal();
            Check("world_access_native_earned_seal_opens",unearned&&breaking&&sealOpened&&sealHidden);
            Debug.Log("World access stage: live portal crossings");bool portals=true,locks=true;int lockedCases=0;
            foreach(string map in repository.MapIds)
            {
                var source=repository.Read(map);var cases=Nodes(source,"portal").ToArray();
                foreach(var original in cases)
                {
                    Last.portalCases++;route.CloseModal();state.Set("flags",Plain("{\"op_new_adventure\":true}"));state.Set("inventory",Plain("{}"));state.Set("quests",Plain("{}"));state.Weapon="wood";
                    var fields=original.Require("fields");var tests=WorldAccessModel.Get(fields,"conditions",FoundationValue.Array(Array.Empty<FoundationValue>()));
                    string target=fields.Require("target_map").AsString(),spawn=fields.Require("target_spawn").AsString();
                    if(!route.TryTravel(map,Spawn(repository.Read(map)))){portals=false;continue;}
                    var live=Nodes(world.Snapshot,"portal").FirstOrDefault(n=>n.Require("fields").Require("target_map").AsString()==target&&n.Require("fields").Require("target_spawn").AsString()==spawn);
                    if(live==null){portals=false;continue;}
                    var rect=live.Require("fields").Require("rect");var at=FoundationCoordinates.Vector(rect.Require("position"));var size=FoundationCoordinates.Vector(rect.Require("size"));var center=at+size*.5f;
                    Vector2 direction=(new Vector2(source.Width*16,source.Height*16)-center);direction=Mathf.Abs(direction.x)>Mathf.Abs(direction.y)?new Vector2(Mathf.Sign(direction.x),0):new Vector2(0,Mathf.Sign(direction.y));
                    Vector2 outside=center+Vector2.Scale(direction,size*.5f+new Vector2(4,4)),inside=center+Vector2.Scale(direction,size*.5f-new Vector2(4,4));
                    if(!route.Access.CheckAll(tests))
                    {lockedCases++;At(world,outside);route.Tick(.02);At(world,inside);route.Tick(.02);locks&=state.MapId==map&&route.Message!="";}
                    Satisfy(state,tests);route.RefreshAccessGeometry();route.TryTravel(map,Spawn(repository.Read(map)));
                    At(world,outside);route.Tick(.02);At(world,inside);route.Tick(.02);
                    bool entered=state.MapId==target&&world.Snapshot.MapId==target&&route.Access.SpawnFits(route.Session.Current,world.Position);
                    portals&=entered;if(entered)Last.portalCrossings++;else Debug.Log("World native portal failed: "+map+" -> "+target+"/"+spawn+" now="+state.MapId+" message="+route.Message);
                    yield return null;
                }
            }
            Check("world_access_native_portal_transitions",portals&&Last.portalCases==69&&Last.portalCrossings==69);
            Check("world_access_native_locked_portals_stay_closed",locks&&lockedCases>=9);
            Check("world_access_original_quest_locks",locks&&lockedCases>=9&&checks.Where(c=>c.name=="world_access_source_portal_conditions"||c.name=="world_access_source_gate_conditions").All(c=>c.passed));
            Debug.Log("World access stage: boats");bool boatPassed=true,cancelled=true,boatNavigation=true;int boatCases=0,multiChoices=0;
            void ControllerPress(string action){var frame=new InputFrame{ControllerActive=true};frame.pressed.Add(action);route.HandleFrame(frame);}
            foreach(string map in repository.MapIds)
            {
                foreach(var dock in Nodes(repository.Read(map),"coast_dock").Concat(Nodes(repository.Read(map),"tide_station").Where(n=>WorldAccessModel.Get(WorldAccessModel.Get(n.Require("fields"),"obj",n.Require("fields")),"role",FoundationValue.StringValue("")).AsString()=="routes")).ToArray())
                {
                    var fields=dock.Require("fields");var routes=route.Access.BoatRoutes(fields).ToArray();
                    foreach(var chosen in routes)
                    {
                        boatCases++;route.CloseModal();route.TryTravel(map,Spawn(repository.Read(map)));var live=route.Targets.FirstOrDefault(t=>(t.Kind=="coast_dock"||t.Kind=="tide_station")&&Vector2.Distance(t.Position,Pos(dock))<1);
                        if(live==null){boatPassed=false;continue;}At(world,live.Position+new Vector2(0,24));string before=FoundationJson.StringifyPlain(state.Snapshot());
                        bool opened=route.OpenVoyage(live.Address);ControllerPress("ui_cancel");cancelled&=opened&&route.Modal==""&&!state.Paused&&FoundationJson.StringifyPlain(state.Snapshot())==before;
                        opened=route.OpenVoyage(live.Address);int index=route.VoyageRoutes.ToList().FindIndex(v=>v.Require("to").AsString()==chosen.Require("to").AsString()&&WorldAccessModel.Get(v,"spawn",FoundationValue.StringValue("start")).AsString()==WorldAccessModel.Get(chosen,"spawn",FoundationValue.StringValue("start")).AsString());
                        long coins=state.Coins;string items=FoundationJson.StringifyPlain(state.Get("inventory"));for(int n=0;n<index;n++)ControllerPress("ui_down");boatNavigation&=opened&&route.Selection==index;if(route.VoyageRoutes.Count>1){multiChoices++;int selected=route.Selection;ControllerPress("ui_up");ControllerPress("ui_down");boatNavigation&=route.Selection==selected;}ControllerPress("ui_accept");bool sailed=route.Modal=="boat_sailing";route.Tick(2.21);
                        bool arrived=sailed&&route.Modal==""&&state.MapId==chosen.Require("to").AsString()&&state.Coins==coins&&FoundationJson.StringifyPlain(state.Get("inventory"))==items&&route.Access.SpawnFits(route.Session.Current,world.Position);
                        boatPassed&=arrived;if(arrived)Last.boatCrossings++;else Debug.Log("Boat native failed: "+map+" -> "+chosen.Require("to").AsString()+" / "+route.Message);
                        yield return null;
                    }
                }
            }
            Check("world_access_native_boats_free_and_validated",boatPassed&&boatCases>0&&Last.boatCrossings==boatCases);
            Check("world_access_native_boat_cancel_preserves_state",cancelled&&boatCases>0);
            Check("world_access_native_multidest_ferries",multiChoices==12&&boatNavigation&&boatPassed);
            Check("world_access_native_boat_controller_navigation",boatNavigation&&multiChoices==12&&boatCases>0);route.HandleFrame(new InputFrame{ControllerActive=false});
            route.CloseModal();route.TryTravel("harbor",Spawn(repository.Read("harbor")));var workshopDoor=route.Targets.FirstOrDefault(t=>t.Kind=="coastal_workstation");bool workshop=false;
            if(workshopDoor!=null)
            {
                At(world,workshopDoor.Position+new Vector2(0,28));string before=FoundationJson.StringifyPlain(state.Snapshot());bool opened=route.InteractTarget(workshopDoor.Address);ControllerPress("ui_cancel");bool cancelledDoor=opened&&route.Modal==""&&before==FoundationJson.StringifyPlain(state.Snapshot());
                opened=route.InteractTarget(workshopDoor.Address);ControllerPress("ui_accept");bool entered=opened&&state.MapId=="coast_workshop"&&world.Snapshot.MapId=="coast_workshop"&&route.Access.SpawnFits(route.Session.Current,world.Position);
                yield return null;
                var back=Nodes(world.Snapshot,"portal").FirstOrDefault(n=>n.Require("fields").Require("target_map").AsString()=="harbor");
                if(back!=null){var rect=back.Require("fields").Require("rect");var at=FoundationCoordinates.Vector(rect.Require("position"));var size=FoundationCoordinates.Vector(rect.Require("size"));At(world,at+new Vector2(size.x*.5f,size.y+4));route.Tick(.02);At(world,at+new Vector2(size.x*.5f,size.y-4));route.Tick(.02);}
                workshop=cancelledDoor&&entered&&state.MapId=="harbor"&&world.Snapshot.MapId=="harbor";
            }
            Check("world_access_native_workshop_door_and_return",workshop);
            route.CloseModal();route.TryTravel("inn",Spawn(repository.Read("inn")));Vector2 saved=world.Position;state.Coins=91;route.Save();state.Coins=1;bool reloaded=route.Reload(false);state=route.Gameplay.State;
            Check("world_access_loaded_area_retained",reloaded&&state.MapId=="inn"&&world.Snapshot.MapId=="inn"&&Vector2.Distance(world.Position,saved)<.001f&&state.Coins==91&&state.Get("future_world_access").Require("amount").AsInt64()==9007199254740993L);
            Check("world_access_no_real_saves_accessed",Fixture.Current.Snapshot.Origin=="unity"&&Fixture.Current.Snapshot.CopyOriginals().Count==0);
            Check("world_access_native_checks_ran",world.RouteMode&&route.Running&&Last.maps==37&&Last.portalCases==69&&boatCases>0);
            Debug.Log("World native access: maps="+Last.maps+" portals="+Last.portalCrossings+"/"+Last.portalCases+" boats="+Last.boatCrossings);
            Last.checks=checks.ToArray();Last.success=checks.All(c=>c.passed);File.WriteAllText(Path.Combine(output,"world-access-result.json"),JsonUtility.ToJson(Last,true));
        }
    }
}
