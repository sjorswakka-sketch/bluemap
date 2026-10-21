using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using UnityEngine;

namespace BlueMapMigration.Inventory
{
    public static class InventoryModelChecks
    {
        public static int OracleCases { get; private set; }
        public static int LoadedSnapshots { get; private set; }
        public static int ObservedChests { get; private set; }
        public static int ObservedPickups { get; private set; }
        public static IReadOnlyList<string> CaseIds { get; private set; }=Array.Empty<string>();
        static FoundationValue I(long value)=>FoundationValue.Integer(value);
        static FoundationValue B(bool value)=>FoundationValue.Boolean(value);
        static FoundationValue S(string value)=>FoundationValue.StringValue(value);
        static FoundationValue Obj(params (string key,FoundationValue value)[] entries)=>FoundationValue.Object(entries.ToDictionary(row=>row.key,row=>row.value,StringComparer.Ordinal));
        public static void Run(Action<string,bool> check)=>Verify(FoundationWorldRepository.LoadRequired(),check);
        public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
        {
            var empty=new InventoryModel(repository,new FoundationGameState());var oracle=empty.Oracle;var ids=new List<string>();OracleCases=0;
            foreach(var row in oracle.Require("cases").Items)
            {
                string id=row.Require("id").AsString();var initial=DecodeOrdered(row.Require("initialOrdered"));var model=new InventoryModel(repository,new FoundationGameState(initial));model.State.InGame=true;
                var operations=DecodeOrdered(row.Require("operationsOrdered")).Items;
                for(int i=0;i<operations.Count;i++)
                {
                    var result=Execute(model,operations[i]);string resultFailure=Difference(result,row.Require("resultsExact").Items[i],id+".results["+i+"]");
                    if(resultFailure!=null)throw new InvalidOperationException("Original inventory result differs: "+resultFailure);
                }
                string stateFailure=Difference(model.State.Snapshot(),row.Require("expectedExact"),id+".state");
                if(stateFailure!=null)throw new InvalidOperationException("Original inventory state differs: "+stateFailure);
                ids.Add(id);OracleCases++;
            }
            CaseIds=ids.AsReadOnly();LoadedSnapshots=oracle.Require("loadedSceneLoot").Items.Count;ObservedChests=0;ObservedPickups=0;
            var maps=new HashSet<string>(StringComparer.Ordinal);var chestKeys=new HashSet<string>(StringComparer.Ordinal);
            foreach(var row in oracle.Require("loadedSceneLoot").Items)
            {
                maps.Add(row.Require("map").AsString());
                foreach(var chest in row.Require("chests").Items)
                {
                    var model=Fresh(repository,oracle);string key=chest.Require("uniqueKey").AsString();
                    if(!model.OpenChest(key,chest.Require("contents")))throw new InvalidOperationException("Source chest contents cannot be claimed: "+key);
                    string after=FoundationJson.StringifyPlain(model.State.Snapshot());
                    if(key!=""&&(!model.OpenChest(key,chest.Require("contents"))||after!=FoundationJson.StringifyPlain(model.State.Snapshot())))throw new InvalidOperationException("Original chest can be claimed twice: "+key);
                    chestKeys.Add(key);ObservedChests++;
                }
                foreach(var pickup in row.Require("pickups").Items)
                {
                    var model=Fresh(repository,oracle);model.State.Hp=2;string key=pickup.Require("uniqueKey").AsString(),item=pickup.Require("item").AsString();
                    if(!model.CollectPickup(item,key,"original-instance"))throw new InvalidOperationException("Source pickup cannot be claimed: "+item);
                    if(model.CollectPickup(item,key,"original-instance"))throw new InvalidOperationException("Original pickup instance can be claimed twice: "+item);
                    ObservedPickups++;
                }
            }
            check("inventory_model_source_equivalence",OracleCases==oracle.Require("cases").Items.Count&&ids.Distinct(StringComparer.Ordinal).Count()==ids.Count&&LoadedSnapshots==162&&maps.Count==37&&ObservedChests>0&&ObservedPickups>0);
            var atomic=Fresh(repository,oracle);bool coherent=false,reentry=false;
            var loot=FoundationJson.ParsePlain("[[\"gear_bronze_helm\",1],[\"prof_branch\",3],[\"coins\",11]]");
            using(atomic.State.Events.Subscribe<FoundationStateChanged>(change=>
            {
                if(change.Field!="flags")return;coherent=atomic.State.Flag("chest:inventory:atomic")&&atomic.State.Coins==11&&atomic.State.Count("prof_branch")==3&&atomic.State.Count("gear_bronze_helm")==1;
                reentry=atomic.OpenChest("chest:inventory:atomic",loot);
            }))atomic.OpenChest("chest:inventory:atomic",loot);
            bool repeat=atomic.OpenChest("chest:inventory:atomic",loot);
            var pickupAtomic=Fresh(repository,oracle);bool pickupReentry=false;
            using(pickupAtomic.State.Events.Subscribe<FoundationStateChanged>(change=>{if(change.Field=="inventory")pickupReentry=pickupAtomic.CollectPickup("crystal_bos","pickup:inventory:atomic","instance");}))pickupAtomic.CollectPickup("crystal_bos","pickup:inventory:atomic","instance");
            var unknown=Fresh(repository,oracle);var payload=FoundationJson.ParsePlain("{\"kind\":\"future_mod\",\"value\":9007199254740993,\"nested\":[null,true,\"🌱\"]}");unknown.State.Set("future_fields",payload);unknown.State.Set("inventory",FoundationJson.ParsePlain("{\"future_stack\":9007199254740993,\"prof_branch\":5}"));
            unknown.State.Set("stockroom",FoundationJson.ParsePlain("{\"home\":{\"future_stock\":9007199254740993},\"favorites\":{},\"sort\":0,\"future_setting\":{\"kind\":\"keep\"}}"));unknown.State.MapId="player_home";unknown.SetContext("home","player_home",Vector2.zero,Vector2.zero);bool stored=unknown.Transfer("prof_branch",3,true,"home");
            bool extensionSafe=ReferenceEquals(unknown.State.Get("future_fields"),payload)&&unknown.State.Count("future_stack")==9007199254740993L&&unknown.Stock("home").Require("future_stock").AsInt64()==9007199254740993L&&unknown.State.Get("stockroom").Require("future_setting").Require("kind").AsString()=="keep";
            var failed=Fresh(repository,oracle);failed.State.Set("inventory",FoundationJson.ParsePlain("{\"arrow\":25}"));string before=FoundationJson.StringifyPlain(failed.State.Snapshot());bool rejected=!failed.OpenChest("chest:inventory:overflow",FoundationJson.ParsePlain("[[\"arrow\",10],[\"coins\",9],[\"arrow\",10]]"));bool noLoss=before==FoundationJson.StringifyPlain(failed.State.Snapshot());
            var stock=Fresh(repository,oracle);stock.State.MapId="player_home";stock.SetContext("home","player_home",Vector2.zero,Vector2.zero);stock.Give("prof_branch",9,true);stock.State.SetUi("inventory-panel",true);bool modalMove=stock.Transfer("prof_branch",3,true,"home");stock.SetContext("home","player_home",Vector2.zero,new Vector2(177,0));bool remoteBlocked=!stock.Transfer("prof_branch",1,true,"home");stock.State.SetUi("inventory-panel",false);
            var fault=Fresh(repository,oracle);bool committedFault=false;
            using(fault.State.Events.Subscribe<FoundationStateChanged>(change=>{if(change.Field=="flags")throw new InvalidOperationException("Injected observer fault");}))
                try{fault.OpenChest("chest:inventory:observer",loot);}catch(FoundationLocationCommittedException error){committedFault=error.AlreadyCommitted;}
            bool safeRepeat=fault.OpenChest("chest:inventory:observer",loot)&&fault.State.Coins==11&&fault.State.Count("gear_bronze_helm")==1;
            check("inventory_model_atomic_and_unique_rewards",coherent&&!reentry&&repeat&&atomic.State.Coins==11&&!pickupReentry&&pickupAtomic.State.Count("crystal_bos")==1&&stored&&extensionSafe&&rejected&&noLoss&&modalMove&&remoteBlocked&&committedFault&&safeRepeat&&chestKeys.Count>=33);
        }
        static InventoryModel Fresh(FoundationWorldRepository repository,FoundationValue oracle)
        {var model=new InventoryModel(repository,new FoundationGameState(oracle.Require("newGame")));model.State.InGame=true;return model;}
        static FoundationValue Execute(InventoryModel model,FoundationValue operation)
        {
            var a=operation.Items;string id=a[0].AsString();
            switch(id)
            {
                case "room":return I(model.Room(a[1].AsString()));
                case "give":model.Give(a[1].AsString(),a[2].AsInt64(),true);return I(model.State.Count(a[1].AsString()));
                case "take":model.Take(a[1].AsString(),a[2].AsInt64());return I(model.State.Count(a[1].AsString()));
                case "coins":return I(model.AddCoins(a[1].AsInt64()));
                case "stamina":model.Stamina=a[1].AsDouble();return FoundationValue.Number(model.Stamina);
                case "use":return Obj(("used",B(model.UseItem(a[1].AsString()))),("stamina",FoundationValue.Number(model.Stamina)));
                case "full_text":return S(model.FullText(a[1].AsString()));
                case "normalize_home":return model.NormalizeHome(a[1]);
                case "normalize_coast":return model.NormalizeCoast(a[1]);
                case "stock_room":return I(model.StockRoom(a[1].AsString(),a[2].AsString()));
                case "stock_movable":return I(model.Movable(a[1].AsString(),a[2].AsBool(),a[3].AsString()));
                case "stock_transfer":return B(model.Transfer(a[1].AsString(),a[2].AsInt64(),a[3].AsBool(),a[4].AsString()));
                case "stock_bulk":return I(model.Bulk(a[1].AsBool(),a[2].AsString()));
                case "stock_consume":return B(model.Consume(a[1]));
                case "stock_available":return I(model.Available(a[1].AsString()));
                case "favorite":return B(model.ToggleFavorite(a[1].AsString()));
                case "sort":model.SetSort((int)a[1].AsInt64());return I(model.Sort);
                case "ids":return FoundationValue.Array(model.Ids(a[1],a[2].AsString(),(int)a[3].AsInt64(),a[4].AsBool()).Select(S));
                case "context":model.State.MapId=a[2].AsString();model.State.InGame=a[4].AsBool();model.SetContext(a[1].AsString(),a[2].AsString(),Vector2.zero,new Vector2((float)a[3].AsDouble(),0),a[4].AsBool());return S(model.NearbyKind);
                case "chest":return B(model.OpenChest(a[1].AsString(),a[2]));
                case "pickup":return B(model.CollectPickup(a[1].AsString(),a[2].AsString()));
                case "magnet":
                    var pickup=new InventoryPickup(a[1].AsString(),new Vector2((float)a[2].AsDouble(),0)){Age=a[3].AsDouble()};model.TickPickup(pickup,Vector2.zero,a[4].AsDouble());return Obj(("position",FoundationValue.Array(new[]{FoundationValue.Number(pickup.Position.x),FoundationValue.Number(pickup.Position.y)})),("age",FoundationValue.Number(pickup.Age)),("collected",B(pickup.Collected)),("range",FoundationValue.Number(model.MagnetRange)));
                case "language":model.Language=a[1].AsString();return S(model.Language);
                default:throw new InvalidOperationException("Unsupported original inventory operation: "+id);
            }
        }
        public static FoundationValue DecodeOrdered(FoundationValue value)
        {
            if(value.TryGet("$f64",out var number))return FoundationValue.Number(BitConverter.Int64BitsToDouble(unchecked((long)Convert.ToUInt64(String.Join("",Enumerable.Range(0,8).Reverse().Select(i=>number.AsString().Substring(i*2,2))),16))));
            if(value.TryGet("$dict",out var pairs))return FoundationValue.Object(pairs.Items.Select(pair=>new KeyValuePair<FoundationValue,FoundationValue>(pair.Items[0],DecodeOrdered(pair.Items[1]))));
            if(value.Kind=="array")return FoundationValue.Array(value.Items.Select(DecodeOrdered));return value;
        }
        static string Difference(FoundationValue actual,FoundationValue expected,string path)
        {
            if(expected.TryGet("$f64",out var bits))
            {
                if(actual.Kind!="float"&&actual.Kind!="int")return path+": expected number, got "+actual.Kind;
                string actualBits=BitConverter.ToString(BitConverter.GetBytes(actual.AsDouble())).Replace("-","").ToLowerInvariant();return actualBits==bits.AsString()?null:path+": numeric bytes "+actualBits+" != "+bits.AsString();
            }
            if(expected.Kind=="object"||expected.Kind=="dictionary")
            {
                if(actual.Kind!="object"&&actual.Kind!="dictionary")return path+": expected dictionary";
                if(actual.Entries.Count!=expected.Entries.Count)return path+": field count "+actual.Entries.Count+" != "+expected.Entries.Count;
                foreach(var row in expected.Entries){if(!actual.TryGet(row.Key.AsString(),out var child))return path+": missing "+row.Key.AsString();string failure=Difference(child,row.Value,path+"."+row.Key.AsString());if(failure!=null)return failure;}return null;
            }
            if(expected.Kind=="array")
            {
                if(actual.Kind!="array"||actual.Items.Count!=expected.Items.Count)return path+": array length differs";
                for(int i=0;i<expected.Items.Count;i++){string failure=Difference(actual.Items[i],expected.Items[i],path+"["+i+"]");if(failure!=null)return failure;}return null;
            }
            if(expected.Kind=="int")return actual.Kind=="int"&&actual.AsInt64()==expected.AsInt64()?null:path+": integer differs";
            if(expected.Kind=="bool")return actual.Kind=="bool"&&actual.AsBool()==expected.AsBool()?null:path+": boolean differs";
            if(expected.Kind=="string")return actual.Kind=="string"&&actual.AsString()==expected.AsString()?null:path+": text differs ("+(actual.Kind=="string"?actual.AsString():actual.Kind)+")";
            return actual.Kind=="nil"&&expected.Kind=="nil"?null:path+": scalar kind differs";
        }
    }
}
