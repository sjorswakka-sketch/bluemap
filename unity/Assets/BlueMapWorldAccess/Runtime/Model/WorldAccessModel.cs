using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using BlueMapMigration.Foundation;
namespace BlueMapMigration.WorldAccess
{
    /// <summary>Original access rules over the player's own state. Fixture progress is never applied.</summary>
    public sealed class WorldAccessModel
    {
        readonly FoundationWorldRepository repository;
        static FoundationValue reference;
        static FoundationValue Reference { get {if(reference==null){var asset=Resources.Load<TextAsset>("BlueMapWorldAccessOracle");if(asset==null)throw new FormatException("Missing world access source reference.");reference=FoundationJson.ParsePlain(asset.text);if(reference.Require("schema").AsString()!="bluemap.world-access.source-oracle.v1"||reference.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid world access source reference.");}return reference;} }
        public FoundationGameState State { get; }
        public FoundationConditionRegistry Conditions { get; }
        public string LastMessage { get; private set; }="";
        public long DirtyVersion { get; private set; }
        public bool ArenaRunActive { get; set; }
        public bool TideFlooded { get; private set; }
        public bool TideHeld { get; private set; }
        sealed class FootShape { public bool Disabled;public string Kind;public Vector2 Origin,Size;public double Radius; }
        sealed class BodyFoot { public FoundationValue Node;public bool StatefulGate;public readonly List<FootShape> Shapes=new List<FootShape>(); }
        sealed class Geometry { public readonly HashSet<long> Solids=new HashSet<long>();public readonly List<BodyFoot> Bodies=new List<BodyFoot>();public readonly List<(Vector2 min,Vector2 max)> Portals=new List<(Vector2,Vector2)>(); }
        FoundationWorldSnapshot geometrySnapshot;
        Geometry geometry;
        string tideMap="";
        readonly Dictionary<string,double> seals=new Dictionary<string,double>(StringComparer.Ordinal);
        public event Action Changed;
        public event Action SaveRequested;
        public WorldAccessModel(FoundationWorldRepository repository,FoundationGameState state)
        {
            this.repository=repository??throw new ArgumentNullException(nameof(repository));State=state??throw new ArgumentNullException(nameof(state));
            Conditions=new FoundationConditionRegistry(state);
            Conditions.Register("boog_missing",c=>Supported(c.Items.Skip(1).Any(v=>!State.Flag(v.AsString()))));
            Conditions.Register("echo_ready",c=>Supported(State.Weapon=="iron"||State.Weapon=="crystal"||State.Weapon=="star"));
            Conditions.Register("arena_open",c=>Supported(State.QuestState("main")!="none"&&(State.Weapon=="iron"||State.Weapon=="crystal"||State.Weapon=="star")));
            Conditions.Register("arena_registered",c=>Supported(new[]{"bronze","silver","gold"}.Any(rank=>State.Flag("arena_signed_"+rank))));
            Conditions.Register("arena_fight",c=>Supported(ArenaRunActive));Conditions.Register("arena_free",c=>Supported(!ArenaRunActive));
        }
        static FoundationConditionResult Supported(bool value)=>new FoundationConditionResult(FoundationRuleStatus.Supported,value);
        public static FoundationValue Get(FoundationValue value,string key,FoundationValue fallback)=>value!=null&&value.TryGet(key,out var found)?found:fallback;
        static FoundationValue Empty()=>FoundationValue.Object(new Dictionary<string,FoundationValue>());
        public static FoundationValue Replace(FoundationValue source,string key,FoundationValue value,bool remove=false)
        {
            var entries=new List<KeyValuePair<FoundationValue,FoundationValue>>();foreach(var e in source.Entries)if(e.Key.AsString()!=key)entries.Add(e);
            if(!remove)entries.Add(new KeyValuePair<FoundationValue,FoundationValue>(FoundationValue.StringValue(key),value));return FoundationValue.Object(entries);
        }
        public void MigrateSourceWorldState()
        {
            var flags=State.Get("flags");var quests=State.Get("quests");
            Action<string,bool> set=(key,value)=>flags=Replace(flags,key,FoundationValue.Boolean(value));
            Action<string> stepZero=id=>quests=Replace(quests,id,Replace(quests.Require(id),"step",FoundationValue.Integer(0)));
            if(State.Flag("lw_drained")||State.QuestState("wilgentwijgen")=="done")
            {set("lw_sluice_west",true);set("lw_sluice_east",false);set("lw_sluice_west_seen",true);set("lw_sluice_east_seen",true);}
            if(!State.Flag("lw_revision_1"))
            {
                if(State.QuestState("warmte")=="done"){set("lw_heat_west",true);set("lw_heat_east",true);set("lw_heat",true);}else if(State.QuestState("warmte")=="active")stepZero("warmte");
                if(State.QuestState("wilgentwijgen")=="done"){set("lw_drained",true);set("lw_bridge",true);set("lw_tailoring",true);}else if(State.QuestState("wilgentwijgen")=="active")stepZero("wilgentwijgen");set("lw_revision_1",true);
            }
            if(!State.Flag("ra_revision_1"))
            {if(State.QuestState("cactusvijgen")=="done"){set("ra_spring",true);set("ra_water_wild",true);}else if(State.QuestState("cactusvijgen")=="active")stepZero("cactusvijgen");set("ra_revision_1",true);}
            if(!State.Flag("rf_revision_1"))
            {if(State.QuestState("medaillon")=="done"){set("rf_relief",true);set("rf_journal",true);set("rf_memorial",true);set("rf_guard",true);}set("rf_revision_1",true);}
            if(FoundationJson.StringifyPlain(flags)==FoundationJson.StringifyPlain(State.Get("flags"))&&FoundationJson.StringifyPlain(quests)==FoundationJson.StringifyPlain(State.Get("quests")))return;
            State.CommitFields(new Dictionary<string,FoundationValue>{{"flags",flags},{"quests",quests}});DirtyVersion++;
        }
        public bool CheckAll(FoundationValue conditions)
        { if(conditions==null)return true;var result=Conditions.CheckAll(conditions);return result.Status==FoundationRuleStatus.Supported&&result.Value; }
        static FoundationValue Spec(FoundationValue fields)=>Get(fields,"obj",fields);
        public bool GateBlocked(FoundationValue fieldsOrSpec)
        { var conditions=Get(fieldsOrSpec,"block_if",Get(Spec(fieldsOrSpec),"block_if",FoundationValue.Array(Array.Empty<FoundationValue>())));return conditions.Items.Count==0||CheckAll(conditions); }
        FoundationValue RefreshAccessQuests(FoundationValue quests,FoundationValue flags,FoundationValue inventory)
        {
            var staged=new FoundationGameState(Replace(Replace(Replace(State.Snapshot(),"quests",quests),"flags",flags),"inventory",inventory));var rules=new WorldAccessModel(repository,staged);var next=quests;
            foreach(var entry in quests.Entries)
            {
                if(entry.Value.Require("state").AsString()!="active"||!Reference.Require("quests").TryGet(entry.Key.AsString(),out var info))continue;
                var steps=info.Require("steps").Items;long step=entry.Value.Require("step").AsInt64();
                while(step>=0&&step<steps.Count-1&&steps[(int)step].TryGet("advance_if",out var conditions)&&rules.CheckAll(conditions))step++;
                if(step!=entry.Value.Require("step").AsInt64()){next=Replace(next,entry.Key.AsString(),Replace(entry.Value,"step",FoundationValue.Integer(step)));staged.Set("quests",next);}
            }
            return next;
        }
        public bool OpenGate(FoundationValue fieldsOrSpec)
        {
            if(State.InputLocked||!GateBlocked(fieldsOrSpec))return false;
            var spec=Spec(fieldsOrSpec);string key=Get(fieldsOrSpec,"key_item",Get(spec,"key",FoundationValue.StringValue(""))).AsString();
            if(key==""||State.Count(key)<=0){LastMessage=Get(fieldsOrSpec,"locked_text",Get(spec,"locked_text",FoundationValue.StringValue("Het poortje zit op slot."))).AsString();return false;}
            string id=Get(fieldsOrSpec,"gate_id",Get(spec,"id",FoundationValue.StringValue(""))).AsString();if(id=="")return false;
            var inventory=Replace(State.Get("inventory"),key,FoundationValue.Integer(State.Count(key)-1),State.Count(key)==1);
            var flags=Replace(State.Get("flags"),"gate_"+id,FoundationValue.Boolean(true));
            try { State.CommitFields(new Dictionary<string,FoundationValue>{{"inventory",inventory},{"flags",flags},{"quests",RefreshAccessQuests(State.Get("quests"),flags,inventory)}}); }
            catch(FoundationLocationCommittedException error){LastMessage="De poort is geopend; een melding kon niet worden bijgewerkt: "+error.Message;DirtyVersion++;return true;}
            LastMessage="Je opent het poortje met de sleutel.";DirtyVersion++;Changed?.Invoke();SaveRequested?.Invoke();return true;
        }
        public bool NodeVisible(FoundationValue sceneNode)
        {
            var fields=Get(sceneNode,"fields",Empty());var spec=Spec(fields);string script=Get(sceneNode,"script",FoundationValue.StringValue("")).AsString();
            if(!Get(spec,"enabled",FoundationValue.Boolean(true)).AsBool()||!CheckAll(Get(spec,"if",null)))return false;
            if(!CheckAll(Get(fields,"exists_if",Get(spec,"exists_if",null))))return false;
            if(script.EndsWith("/gate.gd",StringComparison.Ordinal)||script.EndsWith("/diepte_gate.gd",StringComparison.Ordinal))return GateBlocked(fields);
            if(script.EndsWith("/diepte_seal.gd",StringComparison.Ordinal))return !State.Flag("diepte_opened");
            if(script.EndsWith("/meer_kast.gd",StringComparison.Ordinal))return !CheckAll(Get(fields,"open_if",Get(spec,"open_if",null)));
            if(script.EndsWith("/enemy.gd",StringComparison.Ordinal)||script.EndsWith("/guardian.gd",StringComparison.Ordinal))
            {string defeated=Get(fields,"unique_flag",FoundationValue.StringValue("")).AsString();if(defeated!=""&&State.Flag(defeated))return false;}
            string unique=Get(fields,"unique_key",FoundationValue.StringValue("")).AsString();
            if(script.EndsWith("/pickup.gd",StringComparison.Ordinal)&&unique!=""&&State.Flag(unique))return false;
            return true;
        }
        public static string TideState(double dayTime)
        {double phase=((dayTime*480)%96+96)%96;return phase<48?"low":phase<60?"rising":phase<84?"high":"falling";}
        public bool SyncTide(Vector2 playerPosition,bool entering=false)
        {
            bool water=TideState(State.DayTime)=="high"||TideState(State.DayTime)=="falling";
            if(entering||tideMap!="tide_cove"){tideMap="tide_cove";TideFlooded=water;TideHeld=false;return false;}
            var foot=playerPosition+new Vector2(0,8);bool occupied=foot.x>=630&&foot.x<1034&&foot.y>=790&&foot.y<874;
            TideHeld=water&&!TideFlooded&&occupied;bool changed=water!=TideFlooded&&!TideHeld;if(changed)TideFlooded=water;return changed;
        }
        public string SelectScenario(string map)
        {
            switch(map)
            {
                case "kruipmoeras":return State.Flag("lw_bridge")?"marsh_bridge":State.Flag("lw_drained")?"marsh_drained":State.Flag("lw_sluice_west")?(State.Flag("lw_sluice_east")?"sluices_both":"sluices_west"):State.Flag("lw_sluice_east")?"sluices_east":"sluices_closed";
                case "reedvault":return State.Flag("ra_archive_done")?(State.Flag("ra_exhibit_routes")?"archive_routes":"archive_stories"):State.Flag("lw_drained")?(State.Flag("lw_bridge")?"marsh_bridge":"marsh_drained"):"fresh_baseline";
                case "ijsdal":return State.Flag("lw_heat_east")?"ice_restored":State.Flag("lw_heat_west")?"ice_west":"fresh_baseline";
                case "ridgepass":return State.Flag("ra_rope")?"ridge_rope":"fresh_baseline";
                case "dauwbos":case "mistgarden":return State.Flag("lw_forest")?"forest_restored":"fresh_baseline";
                case "prismamine":case "smithy":return State.Flag("lw_mine")?"mine_restored":"fresh_baseline";
                case "depths2":return State.Flag("guardian_defeated")?(State.Flag("chest:depths2:heart")?"guardian_reward_opened":State.Count("heart_container")>=3?"guardian_full_hearts":"guardian_defeated"):State.Flag("game_completed")&&State.Flag("diepte_opened")?"guardian_alive":"fresh_baseline";
                case "temple":return State.Flag("boss_started")&&!State.Flag("boss_defeated")?"boss_gate_closed":"fresh_baseline";
                case "library":return State.Flag("meer_achterkamer")?"library_backroom":"fresh_baseline";
                case "dorstvallei":case "sunwell":return State.Flag("ra_spring")?(State.Flag("ra_water_caravan")?"desert_caravan":"desert_wild"):"fresh_baseline";
                case "tidal_hollow":return State.Flag("ad_keeper_done")?(State.Flag("ad_workwater")?"hollow_workwater":"hollow_pool"):State.Flag("ad_wheel_done")?"hollow_wheel":State.Flag("ad_duel")?"hollow_duel":"fresh_baseline";
                case "headland":return State.Flag("ad_pilot_done")?"headland_shelter":"fresh_baseline";
                case "tide_cove":return tideMap=="tide_cove"&&TideHeld?"tide_held":"tide_"+TideState(State.DayTime);
                default:return "fresh_baseline";
            }
        }
        public FoundationWorldSnapshot Project(string map)
        {
            var selected=repository.Read(map,SelectScenario(map));
            // Heating the east independently never thaws the unearned west housing strip.
            if(map=="ijsdal"&&State.Flag("lw_heat_east")&&!State.Flag("lw_heat_west"))
            {
                var baseline=repository.Read(map);var rows=selected.MapData.Require("rows").Items.ToList();var original=baseline.MapData.Require("rows").Items;
                for(int y=12;y<=13;y++){char[] row=rows[y].AsString().ToCharArray();for(int x=10;x<16;x++)row[x]=original[y].AsString()[x];rows[y]=FoundationValue.StringValue(new string(row));}
                var root=Replace(selected.Root,"mapData",Replace(selected.MapData,"rows",FoundationValue.Array(rows)));
                var cells=selected.Root.Require("terrain").Require("cells").Items.ToList();var baseCells=baseline.Root.Require("terrain").Require("cells").Items;
                for(int i=0;i<cells.Count;i++)if(cells[i].Items[0].AsInt64()>=10&&cells[i].Items[0].AsInt64()<16&&cells[i].Items[1].AsInt64()>=12&&cells[i].Items[1].AsInt64()<=13)cells[i]=baseCells[i];
                root=Replace(root,"terrain",Replace(root.Require("terrain"),"cells",FoundationValue.Array(cells)));selected=new FoundationWorldSnapshot(root,map,selected.ScenarioId);
            }
            return selected;
        }
        public IReadOnlyList<FoundationValue> BoatRoutes(FoundationValue fieldsOrSpec)
        {
            var spec=Spec(fieldsOrSpec);if(spec.TryGet("routes",out var routes))return routes.Items;
            if(spec.TryGet("to",out var to))return new[]{FoundationValue.Object(new Dictionary<string,FoundationValue>{{"to",to},{"spawn",Get(spec,"spawn",FoundationValue.StringValue("start"))}})};
            return Array.Empty<FoundationValue>();
        }
        public bool BoatEligible(string sourceMap,Vector2 sourcePosition,FoundationValue fieldsOrSpec,string targetMap,string spawn,Vector2 playerPosition)
        {
            if(State.MapId!=sourceMap||State.Transitioning||State.Ended||(playerPosition-sourcePosition).magnitude>64||!repository.MapIds.Contains(targetMap))return false;
            if(!BoatRoutes(fieldsOrSpec).Any(route=>route.Require("to").AsString()==targetMap&&Get(route,"spawn",FoundationValue.StringValue("start")).AsString()==spawn))return false;
            return repository.Read(targetMap).MapData.Require("spawns").TryGet(spawn,out _);
        }
        public bool SealBreaking(Vector2 center)=>seals.ContainsKey(State.MapId+":"+center.x+","+center.y);
        public bool TickSeal(FoundationValue fieldsOrSpec,Vector2 center,Vector2 playerPosition,double delta)
        {
            if(State.Flag("diepte_opened"))return false;string id=State.MapId+":"+center.x+","+center.y;
            if(!seals.TryGetValue(id,out double elapsed))
            {if(State.InputLocked||!State.Flag("game_completed")||(playerPosition-center).magnitude>=112)return false;seals[id]=0;LastMessage="Het zegel begint te breken.";return false;}
            elapsed+=Math.Max(0,delta);seals[id]=elapsed;if(elapsed<1.8)return false;
            var quests=State.Get("quests");if(!quests.TryGet("diepte",out _))quests=Replace(quests,"diepte",FoundationValue.Object(new Dictionary<string,FoundationValue>{{"state",FoundationValue.StringValue("active")},{"step",FoundationValue.Integer(0)}}));
            var flags=Replace(State.Get("flags"),"diepte_opened",FoundationValue.Boolean(true));quests=RefreshAccessQuests(quests,flags,State.Get("inventory"));
            State.CommitFields(new Dictionary<string,FoundationValue>{{"flags",flags},{"quests",quests}});
            DirtyVersion++;LastMessage="Het zegel is gebroken! Er is een trap naar beneden.";Changed?.Invoke();SaveRequested?.Invoke();return true;
        }
        static Vector2 Vec(FoundationValue value)=>value.Kind=="vector"?FoundationCoordinates.Vector(value):new Vector2((float)value.Items[0].AsDouble(),(float)value.Items[1].AsDouble());
        static bool Finite(Vector2 v)=>!float.IsNaN(v.x)&&!float.IsInfinity(v.x)&&!float.IsNaN(v.y)&&!float.IsInfinity(v.y);
        bool Solid(FoundationWorldSnapshot snapshot,Vector2 at,HashSet<long> cells)
        {int x=(int)Math.Floor(at.x/32),y=(int)Math.Floor(at.y/32);return x<0||y<0||x>=snapshot.Width||y>=snapshot.Height||cells.Contains(((long)x<<32)|(uint)y);}
        Geometry GeometryFor(FoundationWorldSnapshot snapshot)
        {
            if(ReferenceEquals(snapshot,geometrySnapshot))return geometry;
            var result=new Geometry();
            foreach(var cell in snapshot.Root.Require("terrain").Require("solidCells").Items)result.Solids.Add((cell.Items[0].AsInt64()<<32)|(uint)cell.Items[1].AsInt64());
            var children=new Dictionary<string,List<FoundationValue>>(StringComparer.Ordinal);
            foreach(var node in snapshot.Root.Require("scene").Items)
            {
                if(!node.TryGet("shape",out _))continue;string parent=node.Require("parent").CanonicalJson;
                if(!children.TryGetValue(parent,out var list)){list=new List<FoundationValue>();children.Add(parent,list);}list.Add(node);
            }
            foreach(var body in snapshot.Root.Require("scene").Items)
            {
                if(!body.TryGet("collision",out var collision)||(collision.Require("layer").AsInt64()&1)==0)continue;
                var parent=Get(body,"parent",FoundationValue.Nil());if(parent.Kind=="nil"||parent.Items.Count!=1||parent.Items[0].AsString()!="entities")continue;
                string script=body.Require("script").AsString();if(script.EndsWith("/player.gd",StringComparison.Ordinal))continue;
                if(snapshot.MapId=="player_home"&&(script.EndsWith("/house_furniture.gd",StringComparison.Ordinal)||(script.EndsWith("/home_station.gd",StringComparison.Ordinal)&&new[]{"bed","table","shelf"}.Contains(Get(Spec(body.Require("fields")),"role",FoundationValue.StringValue("")).AsString()))))continue;
                if(!children.TryGetValue(body.Require("address").CanonicalJson,out var shapes))continue;
                var foot=new BodyFoot{Node=body,StatefulGate=script.EndsWith("/gate.gd",StringComparison.Ordinal)||script.EndsWith("/diepte_gate.gd",StringComparison.Ordinal)};
                foreach(var child in shapes)
                {
                    var shape=child.Require("shape");var transform=child.Require("globalTransform");var parameters=shape.Require("parameters");string kind=shape.Require("class").AsString();
                    Vector2 scale=new Vector2(Vec(transform.Require("x")).magnitude,Vec(transform.Require("y")).magnitude);
                    var compiled=new FootShape{Disabled=shape.Require("disabled").AsBool(),Kind=kind,Origin=Vec(transform.Require("origin"))};
                    if(kind=="RectangleShape2D")compiled.Size=Vector2.Scale(Vec(parameters.Require("size")),scale);
                    else if(kind=="CircleShape2D")compiled.Radius=parameters.Require("radius").AsDouble()*Math.Max(scale.x,scale.y);
                    foot.Shapes.Add(compiled);
                }
                result.Bodies.Add(foot);
            }
            foreach(var spec in snapshot.MapData.Require("objects").Items)
            {if(spec.Require("type").AsString()!="portal")continue;var position=Vec(spec.Require("pos"))*32;var size=Vec(Get(spec,"size",FoundationValue.Array(new[]{FoundationValue.Integer(1),FoundationValue.Integer(1)})))*32;result.Portals.Add((position,position+size));}
            geometrySnapshot=snapshot;geometry=result;return result;
        }
        public bool SpawnFits(FoundationWorldSnapshot snapshot,Vector2 at)=>SpawnFits(snapshot,at,GeometryFor(snapshot).Solids);
        bool SpawnFits(FoundationWorldSnapshot snapshot,Vector2 at,HashSet<long> solids)
        {
            if(!Finite(at))return false;Vector2 foot=at+new Vector2(0,8);
            foreach(var offset in new[]{Vector2.zero,new Vector2(8,0),new Vector2(-8,0),new Vector2(0,8),new Vector2(0,-8),new Vector2(6,6),new Vector2(-6,6),new Vector2(6,-6),new Vector2(-6,-6)})if(Solid(snapshot,foot+offset,solids))return false;
            var compiled=GeometryFor(snapshot);
            foreach(var body in compiled.Bodies)
            {
                if(!NodeVisible(body.Node))continue;
                foreach(var shape in body.Shapes)
                {
                    if(shape.Disabled&&!body.StatefulGate)continue;
                    if(shape.Kind=="RectangleShape2D")
                    {var min=shape.Origin-shape.Size*.5f;var max=shape.Origin+shape.Size*.5f;var nearest=new Vector2(Mathf.Clamp(foot.x,min.x,max.x),Mathf.Clamp(foot.y,min.y,max.y));if((nearest-foot).magnitude<8)return false;}
                    else if(shape.Kind=="CircleShape2D"&&(shape.Origin-foot).magnitude<8+shape.Radius)return false;
                }
            }
            if(snapshot.MapId=="player_home")
            {
                var home=State.Get("personal_home");var layout=Get(home,"layout",snapshot.StateAfter.Require("personal_home").Require("layout"));
                var sizes=new Dictionary<string,Vector2>{{"bed",new Vector2(1,2)},{"table",new Vector2(2,1)},{"shelf",new Vector2(2,2)},{"lamp",new Vector2(1,2)},{"bench",new Vector2(2,1)},{"cabinet",new Vector2(2,2)}};
                foreach(var entry in layout.Entries)
                {
                    string kind=entry.Value.Require("kind").AsString();if(kind=="rug")continue;var cell=Vec(entry.Value.Require("cell"));var size=sizes.TryGetValue(kind,out var dims)?dims:Vector2.one;Vector2 min=cell*32+new Vector2(2,2),max=min+size*32-new Vector2(4,4);var nearest=new Vector2(Mathf.Clamp(foot.x,min.x,max.x),Mathf.Clamp(foot.y,min.y,max.y));if((nearest-foot).magnitude<8)return false;
                }
            }
            foreach(var portal in compiled.Portals)if(at.x>=portal.min.x&&at.x<portal.max.x&&at.y>=portal.min.y&&at.y<portal.max.y)return false;
            return true;
        }
        public Vector2 PrepareSavedPosition(FoundationWorldSnapshot snapshot,Vector2 requested)
        {
            var wanted=requested;
            if(snapshot.MapId=="ridgepass"&&wanted.x>=416&&wanted.x<512&&wanted.y>=544&&wanted.y<608)wanted=new Vector2(wanted.x<464?400:528,592);
            var foot=wanted+new Vector2(0,8);var basins=new List<(Vector2 min,Vector2 max)>();
            foreach(var spec in Get(snapshot.MapData,"fountains",FoundationValue.Array(Array.Empty<FoundationValue>())).Items)
            {var pos=Vec(spec.Require("pos"))*32-new Vector2(9,9);var size=Vec(Get(spec,"size",FoundationValue.Array(new[]{FoundationValue.Integer(2),FoundationValue.Integer(2)})))*32+new Vector2(18,18);basins.Add((pos,pos+size));}
            Func<Vector2,Vector2,Vector2,bool> inside=(at,min,max)=>at.x>=min.x&&at.x<max.x&&at.y>=min.y&&at.y<max.y;
            var candidates=new List<Vector2>();foreach(var basin in basins)if(inside(foot,basin.min,basin.max)){candidates.Add(new Vector2(basin.min.x,foot.y));candidates.Add(new Vector2(basin.max.x,foot.y));candidates.Add(new Vector2(foot.x,basin.min.y));candidates.Add(new Vector2(foot.x,basin.max.y));}
            double best=Double.PositiveInfinity;var solids=GeometryFor(snapshot).Solids;
            foreach(var at in candidates)
            {if(Solid(snapshot,at,solids)||basins.Any(b=>inside(at,b.min+Vector2.one*.1f,b.max-Vector2.one*.1f)))continue;double distance=(at-foot).magnitude;distance*=distance;if(distance<best){wanted=at-new Vector2(0,8);best=distance;}}
            if(snapshot.MapId=="player_home")
            {
                var home=State.Get("personal_home");var layout=Get(home,"layout",snapshot.StateAfter.Require("personal_home").Require("layout"));
                var sizes=new Dictionary<string,Vector2>{{"bed",new Vector2(1,2)},{"table",new Vector2(2,1)},{"shelf",new Vector2(2,2)},{"lamp",new Vector2(1,2)},{"bench",new Vector2(2,1)},{"cabinet",new Vector2(2,2)}};
                foreach(var entry in layout.Entries){string kind=entry.Value.Require("kind").AsString();if(kind=="rug")continue;var min=Vec(entry.Value.Require("cell"))*32-new Vector2(8,8);var size=(sizes.TryGetValue(kind,out var dims)?dims:Vector2.one)*32+new Vector2(16,16);if(inside(wanted,min,min+size)){wanted=new Vector2(208,336);break;}}
            }
            return wanted;
        }
        public Vector2 ResolveArrival(FoundationWorldSnapshot snapshot,Vector2 requested)
        {
            var solids=GeometryFor(snapshot).Solids;if(SpawnFits(snapshot,requested,solids))return requested;
            Vector2 start=Vec(snapshot.MapData.Require("spawns").Require("start"));int cx=Finite(requested)?(int)(requested.x/32):(int)start.x,cy=Finite(requested)?(int)(requested.y/32):(int)start.y;
            for(int radius=1;radius<=8;radius++)
            {
                var ring=Reference.Require("rings").Items[radius-1].Items;
                foreach(var sourceOffset in ring)
                {var offset=new Vector2Int((int)sourceOffset.Items[0].AsInt64(),(int)sourceOffset.Items[1].AsInt64());
                var at=new Vector2((cx+offset.x+.5f)*32,(cy+offset.y+.5f)*32);if(SpawnFits(snapshot,at,solids))return at;}
            }
            return (start+Vector2.one*.5f)*32;
        }
    }
}
