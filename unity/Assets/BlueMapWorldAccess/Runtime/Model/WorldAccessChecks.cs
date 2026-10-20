using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using BlueMapMigration.Foundation;
namespace BlueMapMigration.WorldAccess
{
    public static class WorldAccessChecks
    {
        public static int OracleSnapshots { get; private set; }
        public static int OracleProbes { get; private set; }
        static Vector2 Vec(FoundationValue value)=>new Vector2((float)value.Items[0].AsDouble(),(float)value.Items[1].AsDouble());
        static bool Equal(FoundationValue a,FoundationValue b)
        {
            if((a.Kind=="int"||a.Kind=="float")&&(b.Kind=="int"||b.Kind=="float"))return a.AsDouble()==b.AsDouble();
            if((a.Kind=="object"||a.Kind=="dictionary")&&(b.Kind=="object"||b.Kind=="dictionary"))return a.Entries.Count==b.Entries.Count&&a.Entries.All(e=>b.TryGet(e.Key.AsString(),out var x)&&Equal(e.Value,x));
            if(a.Kind=="array"&&b.Kind=="array")return a.Items.Count==b.Items.Count&&a.Items.Select((x,i)=>Equal(x,b.Items[i])).All(x=>x);
            if(a.Kind=="bool"&&b.Kind=="bool")return a.AsBool()==b.AsBool();
            if(a.Kind=="string"&&b.Kind=="string")return a.AsString()==b.AsString();
            return a.Kind=="nil"&&b.Kind=="nil";
        }
        static FoundationValue DecodeExact(FoundationValue value)
        {
            if(value.TryGet("$f64",out var bits)){byte[] bytes=Enumerable.Range(0,8).Select(i=>Convert.ToByte(bits.AsString().Substring(i*2,2),16)).ToArray();if(!BitConverter.IsLittleEndian)Array.Reverse(bytes);return FoundationValue.Number(BitConverter.ToDouble(bytes,0));}
            if(value.Kind=="array")return FoundationValue.Array(value.Items.Select(DecodeExact));
            if(value.Kind=="object"||value.Kind=="dictionary")return FoundationValue.Object(value.Entries.ToDictionary(e=>e.Key.AsString(),e=>DecodeExact(e.Value)));return value;
        }
        static FoundationValue Snapshot(FoundationGameState state)=>FoundationValue.Object(state.Fields.ToDictionary(e=>e.Key,e=>e.Value));
        public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
        {
            var text=Resources.Load<TextAsset>("BlueMapWorldAccessOracle");if(text==null)throw new FormatException("Missing original world access oracle.");
            var oracle=FoundationJson.ParsePlain(text.text);
            check("world_access_model_checks_ran",oracle.Require("schema").AsString()=="bluemap.world-access.source-oracle.v1"&&!oracle.Require("personalSavesUsed").AsBool());
            bool portals=true,gates=true,arrivals=true,probes=true,boats=true,unchanged=true;OracleSnapshots=0;OracleProbes=0;var maps=new HashSet<string>();var scenarios=new HashSet<string>();
            foreach(var row in oracle.Require("snapshots").Items)
            {
                string map=row.Require("map").AsString(),scenario=row.Require("scenario").AsString();maps.Add(map);scenarios.Add(scenario);
                var state=new FoundationGameState(DecodeExact(WorldAccessModel.Get(row,"stateExact",row.Require("state"))));var model=new WorldAccessModel(repository,state);var snapshot=repository.Read(map,scenario);string before=FoundationJson.StringifyPlain(Snapshot(state));
                foreach(var portal in row.Require("portals").Items)portals&=model.CheckAll(portal.Require("requires"))==portal.Require("available").AsBool();
                foreach(var gate in row.Require("gates").Items)gates&=model.GateBlocked(gate)==gate.Require("blocked").AsBool();
                foreach(var arrival in row.Require("arrivals").Items)
                {
                    Vector2 actual=model.ResolveArrival(snapshot,Vec(arrival.Require("prepared")));bool valid=actual==Vec(arrival.Require("resolved"))&&model.SpawnFits(snapshot,actual)==arrival.Require("fits").AsBool()&&model.PrepareSavedPosition(snapshot,Vec(arrival.Require("nominal")))==Vec(arrival.Require("prepared"));
                    if(!valid)Debug.LogError("Arrival source difference "+scenario+"/"+map+"/"+arrival.Require("name").AsString()+" got="+actual+" expected="+Vec(arrival.Require("resolved")));arrivals&=valid;
                }
                foreach(var probe in row.Require("probes").Items)
                {
                    Vector2 wanted=Vec(probe.Require("requested")),actual=model.ResolveArrival(snapshot,wanted);bool valid=actual==Vec(probe.Require("resolved"))&&model.SpawnFits(snapshot,wanted)==probe.Require("fits").AsBool();
                    if(!valid)Debug.LogError("Spawn source difference "+scenario+"/"+map+" wanted="+wanted+" got="+actual+" expected="+Vec(probe.Require("resolved"))+" fits="+model.SpawnFits(snapshot,wanted)+" expectedFits="+probe.Require("fits").AsBool());probes&=valid;OracleProbes++;
                }
                foreach(var boat in row.Require("boats").Items)
                {
                    var spec=boat.Require("spec");foreach(var route in model.BoatRoutes(spec))boats&=repository.MapIds.Contains(route.Require("to").AsString())&&repository.Read(route.Require("to").AsString()).MapData.Require("spawns").TryGet(route.Require("spawn").AsString(),out _);
                }
                unchanged&=before==FoundationJson.StringifyPlain(Snapshot(state));OracleSnapshots++;
            }
            check("world_access_source_all_162_snapshots",OracleSnapshots==162&&maps.Count==37&&scenarios.Count==59);
            check("world_access_source_portal_conditions",portals);check("world_access_source_gate_conditions",gates);check("world_access_source_safe_arrivals",arrivals);check("world_access_source_safe_spawn_search",probes&&OracleProbes>800);
            check("world_access_source_boat_routes",boats);check("world_access_no_fixture_progress_applied",unchanged);
            foreach(var row in oracle.Require("cases").Items)
            {
                var state=new FoundationGameState(DecodeExact(WorldAccessModel.Get(row,"initialExact",row.Require("initial"))));var model=new WorldAccessModel(repository,state);var op=DecodeExact(WorldAccessModel.Get(row,"operationExact",row.Require("operation")));string kind=op.Require("kind").AsString();FoundationValue actual;
                switch(kind)
                {
                    case "migrations":model.MigrateSourceWorldState();actual=FoundationValue.Boolean(true);break;
                    case "gate":actual=FoundationValue.Boolean(model.OpenGate(op.Require("fields")));break;
                    case "gate_visibility":actual=FoundationValue.Boolean(model.GateBlocked(op.Require("fields")));break;
                    case "conditions":actual=FoundationValue.Array(op.Require("conditions").Items.Select(c=>FoundationValue.Boolean(model.Conditions.Check(c).Value)));break;
                    case "seal":
                        var states=new List<FoundationValue>();bool breaking=false;
                        foreach(var delta in op.Require("deltas").Items){model.TickSeal(FoundationJson.ParsePlain("{}"),Vec(op.Require("center")),Vec(op.Require("playerPosition")),delta.AsDouble());breaking=model.SealBreaking(Vec(op.Require("center")));states.Add(FoundationValue.Array(new[]{FoundationValue.Boolean(breaking),FoundationValue.Boolean(state.Flag("diepte_opened"))}));}
                        actual=states.Count==1?states[0]:FoundationValue.Array(states);break;
                    case "tide":
                        model.SyncTide(Vec(op.Require("positions").Items[0]),true);state.DayTime=op.Require("dayTime").AsDouble();var tideStates=new List<FoundationValue>();
                        foreach(var position in op.Require("positions").Items){var at=Vec(position);state.Position=position;model.SyncTide(at);tideStates.Add(FoundationValue.Array(new[]{FoundationValue.Boolean(model.TideFlooded),FoundationValue.Boolean(model.TideHeld)}));}
                        actual=FoundationValue.Array(tideStates);break;
                    case "boat":actual=FoundationValue.Boolean(model.BoatEligible(op.Require("sourceMap").AsString(),Vec(op.Require("sourcePosition")),op.Require("spec"),op.Require("to").AsString(),op.Require("spawn").AsString(),Vec(op.Require("playerPosition"))));break;
                    default:throw new FormatException("Unhandled original access witness "+kind);
                }
                bool valid=Equal(actual,DecodeExact(WorldAccessModel.Get(row,"resultExact",row.Require("result"))))&&Equal(Snapshot(state),DecodeExact(WorldAccessModel.Get(row,"expectedExact",row.Require("expected"))));check("world_access_source_case_"+row.Require("id").AsString(),valid);
            }
            var own=new FoundationGameState(oracle.Require("snapshots").Items[0].Require("state"));own.Set("future_world",FoundationJson.ParsePlain("{\"locks\":{\"future_gate\":true},\"unknown\":[3,4,5]}"));var projection=new WorldAccessModel(repository,own);
            string original=FoundationJson.StringifyPlain(Snapshot(own));foreach(string map in repository.MapIds)projection.Project(map);
            check("world_access_unknown_fields_retained",original==FoundationJson.StringifyPlain(Snapshot(own))&&own.Get("future_world").Require("locks").Require("future_gate").AsBool());
            own.MapId="forest";own.Set("flags",FoundationJson.ParsePlain("{}"));own.Set("inventory",FoundationJson.ParsePlain("{\"ruin_key\":2}"));var gateFields=FoundationJson.ParsePlain("{\"gate_id\":\"ruin\",\"key_item\":\"ruin_key\",\"block_if\":[[\"no_flag\",\"gate_ruin\"]]}");bool coherent=false;
            using(own.Events.Subscribe<FoundationStateChanged>(e=>{if(e.Field=="inventory")coherent=own.Flag("gate_ruin")&&own.Count("ruin_key")==1;}))projection.OpenGate(gateFields);
            bool duplicate=projection.OpenGate(gateFields);check("world_access_gate_transaction_idempotent",coherent&&!duplicate&&own.Count("ruin_key")==1&&!projection.GateBlocked(gateFields));
            own.MapId="tide_cove";own.DayTime=20.0/480;projection.SyncTide(new Vector2(816,816),true);own.DayTime=70.0/480;bool blockedChange=projection.SyncTide(new Vector2(816,816));bool held=projection.TideHeld&&!projection.TideFlooded;bool released=projection.SyncTide(new Vector2(1040,816));
            check("world_access_tide_occupied_bank_safe",!blockedChange&&held&&released&&projection.TideFlooded&&!projection.TideHeld);
            own.MapId="temple";own.Set("flags",FoundationJson.ParsePlain("{}"));var center=new Vector2(368,32);projection.TickSeal(FoundationJson.ParsePlain("{}"),center,center,10);bool locked=!own.Flag("diepte_opened");own.SetFlag("game_completed",true);projection.TickSeal(FoundationJson.ParsePlain("{}"),center,center,2);bool delayed=!own.Flag("diepte_opened");projection.TickSeal(FoundationJson.ParsePlain("{}"),center,center,1.79);bool notEarly=!own.Flag("diepte_opened");bool opened=projection.TickSeal(FoundationJson.ParsePlain("{}"),center,center,.02);long dirty=projection.DirtyVersion;projection.TickSeal(FoundationJson.ParsePlain("{}"),center,center,20);
            check("world_access_seal_earned_timing",locked&&delayed&&notEarly&&opened&&own.Flag("diepte_opened")&&own.QuestState("diepte")=="active"&&dirty==projection.DirtyVersion);
            own.MapId="ijsdal";own.Set("flags",FoundationJson.ParsePlain("{\"lw_heat_east\":true}"));var east=projection.Project("ijsdal");var baseline=repository.Read("ijsdal");bool westKept=true;for(int y=12;y<=13;y++)for(int x=10;x<16;x++)westKept&=east.MapData.Require("rows").Items[y].AsString()[x]==baseline.MapData.Require("rows").Items[y].AsString()[x];
            check("world_access_independent_earned_restoration",westKept&&east.MapData.Require("rows").Items[3].AsString()[40]==','&&!own.Flag("lw_heat_west")&&!own.Flag("lw_heat"));
            var unknown=projection.Conditions.Check(FoundationJson.ParsePlain("[\"future_unknown_access_rule\"]"));check("world_access_unknown_conditions_fail_closed",unknown.Status==FoundationRuleStatus.Unknown&&!unknown.Value);
        }
    }
}
