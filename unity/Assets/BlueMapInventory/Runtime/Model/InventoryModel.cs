using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Persistence;
using UnityEngine;

namespace BlueMapMigration.Inventory
{
    public sealed class InventoryPickup
    {
        public string Item, UniqueKey, InstanceKey;
        public Vector2 Position, Toss;
        public double Age;
        public bool Collected;
        public InventoryPickup(string item,Vector2 position,string uniqueKey="",string instanceKey="")
        { Item=item;Position=position;UniqueKey=uniqueKey;InstanceKey=instanceKey; }
    }
    /// <summary>Original bag, chest and physically local stock rules. Only explicit gameplay transactions mutate state.</summary>
    public sealed class InventoryModel
    {
        public const int HomeSlots=144, HomeCap=999, CoastSlots=12, CoastCap=99;
        public const double HomeReach=176, CoastReach=96, PickupRange=16, MagnetBase=54, MagnetSpeed=170;
        public const long NoLimit=1000000;
        static FoundationValue reference;
        static readonly System.Runtime.CompilerServices.ConditionalWeakTable<FoundationWorldRepository,LegacySaveImporter> importers=new System.Runtime.CompilerServices.ConditionalWeakTable<FoundationWorldRepository,LegacySaveImporter>();
        readonly LegacySaveImporter importer;
        readonly HashSet<string> claimedPickups=new HashSet<string>(StringComparer.Ordinal);
        bool busy;
        string contextKind="",contextMap="";
        Vector2 storePosition,playerPosition;
        bool liveContext;
        public FoundationGameState State { get; }
        public FoundationValue Oracle { get; }
        public FoundationValue Items=>Oracle.Require("catalogs").Require("items");
        public string Language { get; set; }="nl";
        public Func<string,string> Translator { get; set; }=text=>text;
        public double Stamina { get; set; }=100;
        public double StaminaCapacity { get; set; }=100;
        public string LastMessage { get; private set; }="";
        public long DirtyVersion { get; private set; }
        public event Action Changed;
        public event Action ItemsChanged;
        public event Action SaveRequested;
        public event Action<string,long> ItemObtained;
        public event Action<string> SoundRequested;
        public event Action<double> StaminaRestored;
        public string NearbyKind
        {
            get
            {
                if(!liveContext||!State.InGame||State.Ended||State.Transitioning||State.MapId!=contextMap)return "";
                if(contextKind=="home"&&(contextMap=="village"||contextMap=="player_home")&&Vector2.Distance(storePosition,playerPosition)<=HomeReach)return "home";
                if(contextKind=="coast"&&contextMap=="coast_workshop"&&Vector2.Distance(storePosition,playerPosition)<=CoastReach)return "coast";
                return "";
            }
        }
        public InventoryModel(FoundationWorldRepository repository,FoundationGameState state)
        {
            if(repository==null)throw new ArgumentNullException(nameof(repository));State=state??throw new ArgumentNullException(nameof(state));
            if(reference==null){var asset=Resources.Load<TextAsset>("BlueMapInventoryOracle");if(asset==null)throw new FormatException("Missing original inventory oracle.");reference=FoundationJson.ParsePlain(asset.text);}
            Oracle=reference;
            if(Oracle.Require("schema").AsString()!="bluemap.inventory-state.source-oracle.v1"||Oracle.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid inventory source reference.");
            // This source normalizer is immutable; all model/probe instances in one world
            // repository share its checked rules rather than reparsing the save oracle.
            importer=importers.GetValue(repository,key=>new LegacySaveImporter(key));
        }
        public void SetContext(string kind,string map,Vector2 storePosition,Vector2 playerPosition,bool live=true)
        {contextKind=kind??"";contextMap=map??"";this.storePosition=storePosition;this.playerPosition=playerPosition;liveContext=live;}
        public void ResetPickupInstances()=>claimedPickups.Clear();
        public static FoundationValue Empty()=>FoundationValue.Object(new Dictionary<string,FoundationValue>());
        public static FoundationValue Get(FoundationValue value,string key,FoundationValue fallback)=>value!=null&&value.TryGet(key,out var found)?found:fallback;
        static FoundationValue S(string value)=>FoundationValue.StringValue(value);
        static FoundationValue I(long value)=>FoundationValue.Integer(value);
        static bool Obj(FoundationValue value)=>value!=null&&(value.Kind=="object"||value.Kind=="dictionary");
        static bool Numeric(FoundationValue value)=>value!=null&&(value.Kind=="int"||value.Kind=="float");
        static long Number(FoundationValue value)=>value!=null&&value.Kind=="int"?value.AsInt64():Numeric(value)?(long)value.AsDouble():0;
        public static FoundationValue Replace(FoundationValue source,string key,FoundationValue value,bool remove=false)
        {
            var entries=new List<KeyValuePair<FoundationValue,FoundationValue>>();bool found=false;
            foreach(var entry in source.Entries)
            {if(entry.Key.AsString()==key){found=true;if(!remove)entries.Add(new KeyValuePair<FoundationValue,FoundationValue>(entry.Key,value));}else entries.Add(entry);}
            if(!found&&!remove)entries.Add(new KeyValuePair<FoundationValue,FoundationValue>(S(key),value));return FoundationValue.Object(entries);
        }
        public FoundationValue ItemInfo(string id)=>Get(Items,id,FoundationValue.Object(new Dictionary<string,FoundationValue>{{"name",S(id)},{"icon",I(0)},{"desc",S("")}}));
        public string ItemName(string id)
        {var names=Oracle.Require("catalogs").Require("names");return Get(Get(names,Language,Get(names,"nl",Empty())),id,Get(ItemInfo(id),"name",S(id))).AsString();}
        public string ItemDescription(string id)=>Get(ItemInfo(id),"desc",S("")).AsString();
        public string ItemType(string id)=>Get(ItemInfo(id),"type",S("")).AsString();
        public string ItemSheet(string id)=>Get(ItemInfo(id),"sheet",S("items")).AsString();
        public int ItemIcon(string id)=>(int)Get(ItemInfo(id),"icon",I(0)).AsInt64();
        string Tr(string text)=>Translator==null?text:Translator(text);
        string Format(string template,params object[] values)
        {
            string text=Tr(template);foreach(var value in values){int a=text.IndexOf("%s",StringComparison.Ordinal),b=text.IndexOf("%d",StringComparison.Ordinal);int index=a<0?b:b<0?a:Math.Min(a,b);if(index<0)break;text=text.Substring(0,index)+Convert.ToString(value,System.Globalization.CultureInfo.InvariantCulture)+text.Substring(index+2);}return text;
        }
        public long Room(string id)
        {long cap=Get(ItemInfo(id),"max",I(0)).AsInt64();return cap>0?Math.Max(0,cap-State.Count(id)):NoLimit;}
        public string FullText(string id)
        {var info=ItemInfo(id);return Get(info,"max",I(0)).AsInt64()==1&&State.Count(id)>0?Format("Je bezit %s al.",ItemName(id)):Tr(Get(info,"full_text",S("Je tas is vol")).AsString());}
        FoundationValue RefreshQuests(FoundationValue stagedRoot)
        {
            var state=new FoundationGameState(stagedRoot);var rules=new FoundationConditionRegistry(state);var quests=state.Get("quests");var catalogs=Oracle.Require("catalogs").Require("quests");
            foreach(var entry in quests.Entries)
            {
                if(Get(entry.Value,"state",S("none")).AsString()!="active"||!catalogs.TryGet(entry.Key.AsString(),out var info))continue;
                long step=entry.Value.Require("step").AsInt64();var steps=info.Require("steps").Items;
                while(step>=0&&step<steps.Count-1&&steps[(int)step].TryGet("advance_if",out var conditions))
                {var result=rules.CheckAll(conditions);if(result.Status!=FoundationRuleStatus.Supported||!result.Value)break;step++;}
                if(step!=entry.Value.Require("step").AsInt64()){quests=Replace(quests,entry.Key.AsString(),Replace(entry.Value,"step",I(step)));state.Set("quests",quests);}
            }
            return quests;
        }
        void Apply(Dictionary<string,FoundationValue> updates,bool save=true,bool refresh=true)
        {
            var staged=State.Snapshot();foreach(var update in updates)staged=Replace(staged,update.Key,update.Value);
            if(refresh)updates["quests"]=RefreshQuests(staged);
            State.CommitFields(updates);DirtyVersion++;ItemsChanged?.Invoke();Changed?.Invoke();if(save)SaveRequested?.Invoke();
        }
        public long Give(string id,long quantity=1,bool quiet=false)
        {
            if(busy||quantity<=0)return 0;long granted=Math.Min(quantity,Room(id));
            if(granted<=0){if(!quiet)LastMessage=FullText(id);return 0;}
            busy=true;
            try
            {
                var inventory=Replace(State.Get("inventory"),id,I(checked(State.Count(id)+granted)));
                var updates=new Dictionary<string,FoundationValue>{{"inventory",inventory}};
                if(id=="heart_container")updates["hp"]=I(Math.Min(checked(State.Hp+granted),checked(5+inventory.Require(id).AsInt64())));
                Apply(updates,false);if(!quiet){ItemObtained?.Invoke(id,granted);if(granted<quantity)LastMessage=FullText(id);}return granted;
            }
            finally{busy=false;}
        }
        public bool Take(string id,long quantity=1)
        {
            if(busy||quantity<=0)return false;busy=true;
            try
            {
                long left=State.Count(id)-quantity;var inventory=Replace(State.Get("inventory"),id,I(left),left<=0);
                Apply(new Dictionary<string,FoundationValue>{{"inventory",inventory},{"equipment",importer.NormalizeEquipment(State.Get("equipment"),inventory)},{"clothing",importer.NormalizeClothing(State.Get("clothing"),inventory)}},false);return true;
            }
            finally{busy=false;}
        }
        public long AddCoins(long amount)
        {if(busy)return State.Coins;busy=true;try{Apply(new Dictionary<string,FoundationValue>{{"coins",I(Math.Max(0,checked(State.Coins+amount)))}},false,false);return State.Coins;}finally{busy=false;}}
        void EnsureProfessionState()
        {
            var raw=State.Get("professions");if(raw.TryGet("xp",out _)&&raw.TryGet("cooldowns",out _))return;
            var normalized=importer.Import(System.Text.Encoding.UTF8.GetBytes(FoundationJson.StringifyPlain(State.Snapshot()))).State.Get("professions");
            foreach(var row in raw.Entries)if(!normalized.TryGet(row.Key.AsString(),out _))normalized=Replace(normalized,row.Key.AsString(),row.Value);
            foreach(string field in new[]{"xp","cooldowns"})
            {
                var table=Get(normalized,field,Empty());var original=Get(raw,field,Empty());
                if(Obj(original))foreach(var row in original.Entries)if(!table.TryGet(row.Key.AsString(),out _))table=Replace(table,row.Key.AsString(),row.Value);
                normalized=Replace(normalized,field,table);
            }
            State.Set("professions",normalized);
        }
        public string UseReason(string id)
        {
            if(!Oracle.Require("catalogs").Require("consumables").Items.Any(value=>value.AsString()==id)||State.Count(id)<=0)return Tr("Je hebt dit niet bij je");
            var info=ItemInfo(id);bool heals=info.TryGet("heal",out _)&&State.Hp<State.MaxHp,restores=info.TryGet("stamina",out _)&&Stamina<StaminaCapacity;
            if(!heals&&!restores)return Tr(info.TryGet("heal",out _)?"Je hartjes zijn al vol":"Je uithoudingsvermogen is al vol");return "";
        }
        public bool CanUseItem(string id)=>!busy&&UseReason(id)=="";
        public bool UseItem(string id)
        {
            if(busy||State.Ended||State.Transitioning)return false;EnsureProfessionState();string reason=UseReason(id);if(reason!=""){LastMessage=reason;return false;}
            busy=true;
            try
            {
                var info=ItemInfo(id);var inventory=Remove(State.Get("inventory"),id,1);
                var updates=new Dictionary<string,FoundationValue>{{"inventory",inventory},{"equipment",importer.NormalizeEquipment(State.Get("equipment"),inventory)},{"clothing",importer.NormalizeClothing(State.Get("clothing"),inventory)}};
                if(info.TryGet("heal",out var heal))updates["hp"]=I(Math.Min(State.MaxHp,checked(State.Hp+heal.AsInt64())));
                if(id=="potion")updates["potions_drunk"]=I(checked(State.Get("potions_drunk").AsInt64()+1));
                double restored=0;if(info.TryGet("stamina",out var energy)){restored=Math.Max(0,Math.Min(energy.AsDouble(),StaminaCapacity-Stamina));Stamina=Math.Min(StaminaCapacity,Stamina+energy.AsDouble());}
                Apply(updates,false);if(restored>0)StaminaRestored?.Invoke(restored);LastMessage=Format("Gebruikt: %s",ItemName(id));SoundRequested?.Invoke("drink");return true;
            }
            finally{busy=false;}
        }
        public bool OpenChest(string uniqueKey,FoundationValue contents)
        {
            if(busy||State.InputLocked)return false;
            if(uniqueKey!=""&&State.Flag(uniqueKey)){LastMessage=Tr("De kist is leeg.");return true;}
            var totals=new Dictionary<string,long>(StringComparer.Ordinal);foreach(var reward in contents.Items){string item=reward.Items[0].AsString();totals[item]=checked((totals.TryGetValue(item,out var n)?n:0)+reward.Items[1].AsInt64());}
            var grants=new Dictionary<string,long>(StringComparer.Ordinal);var owned=new List<string>();
            foreach(var reward in totals)
            {
                if(reward.Key=="coins")continue;var info=ItemInfo(reward.Key);
                if(Get(info,"max",I(0)).AsInt64()==1&&State.Count(reward.Key)>0){owned.Add(reward.Key);continue;}
                long space=Room(reward.Key);
                if(space<reward.Value){LastMessage=info.TryGet("chest_full_text",out var full)?Tr(full.AsString()):space==0?FullText(reward.Key):Format("Niet genoeg ruimte voor %s: %d nodig, %d vrij.",ItemName(reward.Key),reward.Value,space);SoundRequested?.Invoke("error");return false;}
                grants.Add(reward.Key,reward.Value);
            }
            busy=true;
            try
            {
                var inventory=State.Get("inventory");foreach(var grant in grants)inventory=Replace(inventory,grant.Key,I(checked(State.Count(grant.Key)+grant.Value)));
                var flags=State.Get("flags");if(uniqueKey!="")flags=Replace(flags,uniqueKey,FoundationValue.Boolean(true));
                long coins=totals.TryGetValue("coins",out var money)?money:0;
                var updates=new Dictionary<string,FoundationValue>{{"inventory",inventory},{"flags",flags},{"coins",I(Math.Max(0,checked(State.Coins+coins)))}};
                if(grants.TryGetValue("heart_container",out var hearts))updates["hp"]=I(Math.Min(checked(State.Hp+hearts),checked(5+inventory.Require("heart_container").AsInt64())));
                // The unique flag, rewards and money are visible together before any synchronous observer.
                Apply(updates,false);LastMessage=owned.Count>0?String.Join(" ",owned.Select(FullText)):coins!=0?Format(coins==1?"Gevonden: %d munt":"Gevonden: %d munten",coins):"";
                SoundRequested?.Invoke("chest");foreach(var grant in grants)ItemObtained?.Invoke(grant.Key,grant.Value);SaveRequested?.Invoke();return true;
            }
            finally{busy=false;}
        }
        public bool CollectPickup(string item,string uniqueKey="",string instanceKey="")
        {
            if(busy||State.InputLocked||(uniqueKey!=""&&State.Flag(uniqueKey))||(instanceKey!=""&&claimedPickups.Contains(instanceKey)))return false;
            if(item=="heart"&&State.Hp>=State.MaxHp)return false;
            if(item!="coin"&&item!="heart"&&Room(item)<=0){LastMessage=FullText(item);return false;}
            busy=true;
            try
            {
                var updates=new Dictionary<string,FoundationValue>();
                if(item=="coin")updates["coins"]=I(checked(State.Coins+1));
                else if(item=="heart")updates["hp"]=I(Math.Min(State.MaxHp,checked(State.Hp+1)));
                else
                {
                    updates["inventory"]=Replace(State.Get("inventory"),item,I(checked(State.Count(item)+1)));
                    if(item=="heart_container")updates["hp"]=I(Math.Min(checked(State.Hp+1),checked(State.MaxHp+1)));
                }
                if(uniqueKey!="")updates["flags"]=Replace(State.Get("flags"),uniqueKey,FoundationValue.Boolean(true));
                if(instanceKey!="")claimedPickups.Add(instanceKey);
                Apply(updates,false);if(item!="coin"&&item!="heart"&&ItemType(item)!="ammo")ItemObtained?.Invoke(item,1);
                SoundRequested?.Invoke(item=="coin"?"coin":item=="heart"?"heart":ItemType(item)=="crystal"?"crystal":ItemType(item)=="ammo"?"select":"chest");
                if(uniqueKey!="")SaveRequested?.Invoke();return true;
            }
            finally{busy=false;}
        }
        public double MagnetRange
        {
            get
            {
                double bonus=0;var gear=Oracle.Require("catalogs").Require("gear");
                foreach(var slot in State.Get("equipment").Entries)
                {string id=slot.Value.Kind=="string"?slot.Value.AsString():"";if(State.Count(id)>0&&gear.TryGet(id,out var info)&&Get(info,"slot",S("")).AsString()==slot.Key.AsString())bonus+=Math.Max(0,Get(Get(info,"bonuses",Empty()),"magnet_range",FoundationValue.Number(0)).AsDouble());}
                return MagnetBase+Math.Max(0,Math.Min(24,bonus));
            }
        }
        public void TickPickup(InventoryPickup pickup,Vector2 player,double delta)
        {
            if(pickup==null||pickup.Collected||delta<0||Double.IsNaN(delta)||Double.IsInfinity(delta))return;
            pickup.Age+=delta;if(pickup.Age<.4){pickup.Position+=pickup.Toss*(float)delta;pickup.Toss*=.9f;}
            if(State.Ended||State.InputLocked)return;
            if(pickup.Age>.25&&Vector2.Distance(player,pickup.Position)<MagnetRange)pickup.Position=Vector2.MoveTowards(pickup.Position,player,(float)(MagnetSpeed*delta));
            if(pickup.Age>.2&&Vector2.Distance(player,pickup.Position)<PickupRange)pickup.Collected=CollectPickup(pickup.Item,pickup.UniqueKey,pickup.InstanceKey);
        }
        public bool Allowed(string item)=>Items.TryGet(item,out _)&&(ItemType(item)=="material"||ItemType(item)=="use"||ItemType(item)=="ammo");
        public int Category(string item)
        {
            if(item.StartsWith("or_",StringComparison.Ordinal)&&ItemType(item)=="material")return 2;
            if(item.StartsWith("hs_",StringComparison.Ordinal)&&item!="hs_grape"&&item!="hs_wine"&&item!="hs_honey"&&item!="hs_hoe")return 2;
            switch(ItemType(item)){case "material":return 1;case "use":return 3;case "gear":case "weapon":case "cloth":case "ammo":return 4;default:return 5;}
        }
        public FoundationValue NormalizeHome(FoundationValue raw)
        {
            var home=Empty();var favorites=Empty();long order=0;
            if(Obj(raw))
            {
                var data=Get(raw,"home",Empty());if(Obj(data))foreach(var row in data.Entries)
                    if(home.Entries.Count<HomeSlots&&Allowed(row.Key.AsString())&&Numeric(row.Value)&&row.Value.AsDouble()>=1)home=Replace(home,row.Key.AsString(),I((long)Math.Min(HomeCap,row.Value.AsDouble())));
                data=Get(raw,"favorites",Empty());if(Obj(data))foreach(var row in data.Entries)
                    if(Items.TryGet(row.Key.AsString(),out _)&&row.Value.Kind=="bool"&&row.Value.AsBool())favorites=Replace(favorites,row.Key.AsString(),FoundationValue.Boolean(true));
                data=Get(raw,"sort",I(0));if(Numeric(data))order=(long)Math.Max(0,Math.Min(3,data.AsDouble()));
            }
            return FoundationValue.Object(new Dictionary<string,FoundationValue>{{"home",home},{"favorites",favorites},{"sort",I(order)}});
        }
        public FoundationValue NormalizeCoast(FoundationValue raw)
        {
            var result=Empty();if(!Obj(raw))return result;
            foreach(var row in raw.Entries)
            {
                if(result.Entries.Count>=CoastSlots)break;
                if(Items.TryGet(row.Key.AsString(),out _)&&ItemType(row.Key.AsString())=="material"&&Numeric(row.Value)&&row.Value.AsDouble()>=1)result=Replace(result,row.Key.AsString(),I((long)Math.Min(CoastCap,row.Value.AsDouble())));
            }
            return result;
        }
        FoundationValue StockState()
        {
            var raw=State.Get("stockroom");if(raw.TryGet("home",out _))return raw;
            var normalized=NormalizeHome(raw);
            // Keep extension fields in the live profile; original imported bytes remain separately archived.
            foreach(var entry in raw.Entries)if(!normalized.TryGet(entry.Key.AsString(),out _))normalized=Replace(normalized,entry.Key.AsString(),entry.Value);
            State.Set("stockroom",normalized);return normalized;
        }
        public FoundationValue Stock(string kind)=>kind=="coast"?State.Get("coastal_storage"):StockState().Require("home");
        public long StockCount(string item,string kind="home")=>Number(Get(Stock(kind),item,I(0)));
        public long StockRoom(string item,string kind)
        {
            if(!Allowed(item)||(kind=="coast"&&ItemType(item)!="material"))return 0;
            var data=Stock(kind);int slots=kind=="coast"?CoastSlots:HomeSlots,cap=kind=="coast"?CoastCap:HomeCap;
            if(!data.TryGet(item,out _)&&data.Entries.Count>=slots)return 0;return Math.Max(0,cap-StockCount(item,kind));
        }
        public long Movable(string item,bool deposit,string kind)
        {if((kind!="home"&&kind!="coast")||kind!=NearbyKind||!Allowed(item))return 0;return deposit?Math.Min(State.Count(item),StockRoom(item,kind)):Math.Min(StockCount(item,kind),Room(item));}
        static FoundationValue Remove(FoundationValue data,string item,long amount)
        {long left=Number(Get(data,item,I(0)))-amount;return Replace(data,item,I(left),left<=0);}
        Dictionary<string,FoundationValue> StockChanges(string kind,FoundationValue inventory,FoundationValue stock)
        {return kind=="coast"?new Dictionary<string,FoundationValue>{{"inventory",inventory},{"coastal_storage",stock}}:new Dictionary<string,FoundationValue>{{"inventory",inventory},{"stockroom",Replace(StockState(),"home",stock)}};}
        public bool Transfer(string item,long amount,bool deposit,string kind)
        {
            if(busy||amount<=0||amount>Movable(item,deposit,kind))return false;busy=true;
            try
            {
                var inventory=State.Get("inventory");var stock=Stock(kind);
                if(deposit){inventory=Remove(inventory,item,amount);stock=Replace(stock,item,I(checked(StockCount(item,kind)+amount)));}
                else{stock=Remove(stock,item,amount);inventory=Replace(inventory,item,I(checked(State.Count(item)+amount)));}
                Apply(StockChanges(kind,inventory,stock));LastMessage=Format("%d verplaatst.",amount);return true;
            }
            finally{busy=false;}
        }
        public long Bulk(bool existingOnly,string kind)
        {
            if(busy||kind==""||kind!=NearbyKind)return 0;busy=true;
            try
            {
                long moved=0;var inventory=State.Get("inventory");var stock=Stock(kind);
                foreach(var row in inventory.Entries)
                {
                    string item=row.Key.AsString();if(Favorite(item)||!Allowed(item))continue;
                    if(existingOnly&&StockCount(item,kind)==0)continue;if(!existingOnly&&ItemType(item)!="material")continue;
                    long capacity=!stock.TryGet(item,out _)&&stock.Entries.Count>=(kind=="coast"?CoastSlots:HomeSlots)?0:(kind=="coast"?CoastCap:HomeCap)-Number(Get(stock,item,I(0)));
                    if(kind=="coast"&&ItemType(item)!="material")capacity=0;long count=Math.Min(row.Value.AsInt64(),Math.Max(0,capacity));
                    if(count<=0)continue;inventory=Remove(inventory,item,count);stock=Replace(stock,item,I(checked(Number(Get(stock,item,I(0)))+count)));moved=checked(moved+count);
                }
                if(moved>0)Apply(StockChanges(kind,inventory,stock));LastMessage=Format("%d verplaatst. Favorieten zijn overgeslagen.",moved);return moved;
            }
            finally{busy=false;}
        }
        public long Available(string item)=>checked(State.Count(item)+(NearbyKind!=""?StockCount(item,NearbyKind):0));
        public bool Consume(FoundationValue inputs)
        {
            if(busy)return false;foreach(var row in inputs.Entries)if(row.Value.AsInt64()<=0||Available(row.Key.AsString())<row.Value.AsInt64())return false;
            string kind=NearbyKind;busy=true;
            try
            {
                var inventory=State.Get("inventory");var stock=kind!=""?Stock(kind):Empty();
                foreach(var row in inputs.Entries){string id=row.Key.AsString();long bag=Math.Min(State.Count(id),row.Value.AsInt64());inventory=Remove(inventory,id,bag);if(row.Value.AsInt64()>bag)stock=Remove(stock,id,row.Value.AsInt64()-bag);}
                var updates=kind!=""?StockChanges(kind,inventory,stock):new Dictionary<string,FoundationValue>{{"inventory",inventory}};
                updates["equipment"]=importer.NormalizeEquipment(State.Get("equipment"),inventory);updates["clothing"]=importer.NormalizeClothing(State.Get("clothing"),inventory);Apply(updates,false);return true;
            }
            finally{busy=false;}
        }
        public bool Favorite(string item)=>Get(Get(StockState(),"favorites",Empty()),item,FoundationValue.Boolean(false)).Kind=="bool"&&Get(Get(StockState(),"favorites",Empty()),item,FoundationValue.Boolean(false)).AsBool();
        public bool ToggleFavorite(string item)
        {
            if(busy||!Items.TryGet(item,out _))return false;busy=true;
            try{bool before=Favorite(item);var state=StockState();var favorites=Replace(Get(state,"favorites",Empty()),item,FoundationValue.Boolean(true),before);State.Set("stockroom",Replace(state,"favorites",favorites));DirtyVersion++;Changed?.Invoke();SaveRequested?.Invoke();return !before;}
            finally{busy=false;}
        }
        public int Sort=>(int)Get(StockState(),"sort",I(0)).AsInt64();
        public void SetSort(int order)
        {if(order<0||order>3||busy)return;State.Set("stockroom",Replace(StockState(),"sort",I(order)));DirtyVersion++;Changed?.Invoke();SaveRequested?.Invoke();}
        public IReadOnlyList<string> Ids(FoundationValue data,string query="",int filter=0,bool onlyFavorites=false)
        {
            var result=new List<string>();string needle=(query??"").Trim().ToLowerInvariant();
            foreach(var row in data.Entries)
            {
                string id=row.Key.AsString();if(Number(row.Value)<=0||!Items.TryGet(id,out _))continue;
                if(filter>0&&Category(id)!=filter)continue;if(onlyFavorites&&!Favorite(id))continue;
                if(needle.Length>0&&!ItemName(id).ToLowerInvariant().Contains(needle)&&!id.ToLowerInvariant().Contains(needle))continue;result.Add(id);
            }
            int order=Sort;if(order>0)result.Sort((a,b)=>
            {if(order==1&&Category(a)!=Category(b))return Category(a).CompareTo(Category(b));if(order==3&&Number(data.Require(a))!=Number(data.Require(b)))return Number(data.Require(b)).CompareTo(Number(data.Require(a)));int names=StringComparer.Ordinal.Compare(ItemName(a).ToLowerInvariant(),ItemName(b).ToLowerInvariant());return names==0?StringComparer.Ordinal.Compare(a,b):names;});
            return result.AsReadOnly();
        }
    }
}
