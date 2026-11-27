using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Progression;
using UnityEngine;
namespace BlueMapMigration.Professions
{
 /// <summary>Replays every recorded source case: each result, each notice and the complete saved state must match.</summary>
 public static class ProfessionsModelChecks
 {
  public static int OracleCases {get;private set;} public static int OracleOperations {get;private set;} public static IReadOnlyList<string> CaseIds {get;private set;}=Array.Empty<string>();
  static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue B(bool v)=>FoundationValue.Boolean(v);static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue D(double v)=>FoundationValue.Number(v);
  static FoundationValue A(IEnumerable<FoundationValue> values)=>FoundationValue.Array(values);
  static FoundationValue O(params (string key,FoundationValue value)[] entries)=>FoundationValue.Object(entries.ToDictionary(v=>v.key,v=>v.value,StringComparer.Ordinal));
  sealed class Recorded : IFishingRandom
  {
   readonly IReadOnlyList<FoundationValue> draws;int next;
   public Recorded(FoundationValue values){draws=values.Items;}
   public int Used=>next;public int Count=>draws.Count;
   double Take(){if(next>=draws.Count)throw new InvalidOperationException("The source consumed fewer generator results");return draws[next++].AsDouble();}
   public double Randf()=>Take();public double Range(double from,double to)=>Take();
  }
  sealed class Fixture
  {
   public ProfessionsModel Model;public InventoryModel Inventory;public ProgressionModel Progression;public FoundationGameState State;public readonly List<string> Toasts=new List<string>();
  }
  static Fixture Build(FoundationWorldRepository repository,FoundationValue initial)
  {
   var f=new Fixture();f.State=new FoundationGameState(initial);f.State.InGame=true;f.Inventory=new InventoryModel(repository,f.State);f.Progression=new ProgressionModel(repository,f.State,f.Inventory);
   f.Model=new ProfessionsModel(repository,f.State,f.Inventory,f.Progression);f.Model.Toast+=f.Toasts.Add;return f;
  }
  public static void Run(Action<string,bool> check)=>Verify(FoundationWorldRepository.LoadRequired(),check);
  public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
  {
   var asset=Resources.Load<TextAsset>("BlueMapProfessionsOracle");if(asset==null)throw new FormatException("Missing original professions oracle");
   var oracle=FoundationJson.ParsePlain(asset.text);
   if(oracle.Require("schema").AsString()!="bluemap.professions.source-oracle.v1"||oracle.Require("personalSavesUsed").AsBool()||oracle.Require("randomBoundary").AsString()!="recorded-generator-results-are-explicit-inputs")throw new FormatException("Invalid professions source oracle");
   var ids=new List<string>();OracleCases=0;OracleOperations=0;
   foreach(var row in oracle.Require("cases").Items)
   {
    string id=row.Require("id").AsString();var f=Build(repository,InventoryModelChecks.DecodeOrdered(row.Require("initialOrdered")));var ops=InventoryModelChecks.DecodeOrdered(row.Require("operationsOrdered")).Items;var expected=row.Require("resultsExact").Items;
    for(int index=0;index<ops.Count;index++)
    {
     f.Toasts.Clear();var actual=Execute(f,ops[index],expected[index].Require("value"));
     string failure=Difference(actual,expected[index].Require("value"),id+".results["+index+"]")??Difference(A(f.Toasts.Select(S)),expected[index].Require("toasts"),id+".toasts["+index+"]");
     if(failure!=null)throw new InvalidOperationException("Original professions result differs: "+failure);OracleOperations++;
    }
    string stateFailure=Difference(f.State.Snapshot(),row.Require("expectedExact"),id+".state");if(stateFailure!=null)throw new InvalidOperationException("Original professions state differs: "+stateFailure);ids.Add(id);OracleCases++;
   }
   CaseIds=ids.AsReadOnly();check("professions_model_source_equivalence",OracleCases==oracle.Require("cases").Items.Count&&ids.Distinct(StringComparer.Ordinal).Count()==ids.Count&&OracleCases>1000);
   var catalogs=ProfessionsModel.LoadCatalog();
   check("professions_catalog_complete",catalogs.Require("skills").Entries.Count==7&&catalogs.Require("recipes").Entries.Count==oracle.Require("catalogs").Require("recipes").Entries.Count&&catalogs.Require("resources").Entries.Count==oracle.Require("catalogs").Require("resources").Entries.Count&&catalogs.Require("shops").Entries.Count==oracle.Require("catalogs").Require("shops").Entries.Count&&FoundationJson.StringifyPlain(InventoryModelChecks.DecodeOrdered(oracle.Require("catalogsOrdered")))==FoundationJson.StringifyPlain(catalogs));
   // Browsing is pure: pages, reasons and the field guide never change a save.
   var browse=Build(repository,ProfessionsModel.NewGame);var payload=FoundationJson.ParsePlain("{\"counter\":9007199254740993,\"nested\":[null,true,\"🌱\"]}");
   browse.State.Set("professions",O(("xp",O(("mining",I(40)),("future_skill",I(9007199254740993L)))),("cooldowns",O()),("future_progress",payload)));string before=FoundationJson.StringifyPlain(browse.State.Snapshot());
   foreach(string recipe in browse.Model.RecipeIds){browse.Model.CraftReason(recipe);browse.Model.RecipeText(recipe);browse.Model.IngredientStatus(recipe);}
   foreach(var resource in browse.Model.Resources.Entries){browse.Model.GatherReason(resource.Key.AsString(),"probe:"+resource.Key.AsString());browse.Model.GatherDuration(resource.Key.AsString());}
   foreach(var shop in browse.Model.Shops.Entries)browse.Model.ShopRows(shop.Key.AsString());foreach(string skill in browse.Model.SkillIds)browse.Model.Progress(skill);
   bool pure=before==FoundationJson.StringifyPlain(browse.State.Snapshot())&&browse.Toasts.Count==0;
   browse.Model.AddXp("mining",5);bool unknownKept=browse.State.Get("professions").Require("xp").Require("future_skill").AsInt64()==9007199254740993L&&ReferenceEquals(browse.State.Get("professions").Require("future_progress"),payload)&&browse.Model.Xp("mining")==45;
   check("professions_browsing_is_pure_and_keeps_unknown_fields",pure&&unknownKept);
   // A purchase or a recipe that cannot complete leaves coins and materials exactly as they were.
   var poor=Build(repository,ProfessionsModel.NewGame);poor.State.Coins=14;poor.Model.EnsureState();string poorBefore=FoundationJson.StringifyPlain(poor.State.Snapshot());bool refused=!poor.Model.Buy("tobias",0)&&!poor.Model.Buy("tobias",99)&&!poor.Model.Buy("future",0)&&!poor.Model.Craft("stone_axe")&&!poor.Model.Gather("copper","forest:copper_west");
   check("professions_refusals_change_nothing",refused&&poorBefore==FoundationJson.StringifyPlain(poor.State.Snapshot()));
   // Re-entrant listeners cannot duplicate a reward or spend materials twice.
   var loop=Build(repository,ProfessionsModel.NewGame);loop.Inventory.Give("prof_branch",4,true);loop.Inventory.Give("prof_stone",4,true);bool reentered=false;
   using(loop.State.Events.Subscribe<FoundationStateChanged>(change=>{if(change.Field=="inventory")reentered|=loop.Model.Craft("stone_axe")||loop.Model.Gather("branches","village:twigs_west");}))loop.Model.Craft("stone_axe");
   check("professions_reentrant_listeners_cannot_duplicate",!reentered&&loop.State.Count("prof_axe")==1&&loop.State.Count("prof_branch")==2&&loop.State.Count("prof_stone")==2&&loop.Model.Xp("woodcutting")==8);
  }
  /// <summary>A bag with the given counts set; used to prepare synthetic test profiles only.</summary>
  public static FoundationValue With(FoundationValue inventory,params (string item,long count)[] items){foreach(var row in items)inventory=InventoryModel.Replace(inventory,row.item,I(row.count),row.count<=0);return inventory;}
  static FoundationValue Skill(ProfessionsModel model,string skill)=>O(("xp",I(model.Xp(skill))),("level",I(model.Level(skill))));
  static FoundationValue ReelView(FishingReel reel)=>O(("zone",D(reel.ZonePos)),("velocity",D(reel.ZoneVel)),("fish",D(reel.FishPos)),("target",D(reel.FishTarget)),("progress",D(reel.Progress)),("inZone",B(reel.InZone)),("state",S(reel.State)),("elapsed",D(reel.Elapsed)),("retarget",D(reel.RetargetIn)));
  static bool Held(string pattern,int step,FishingReel reel)
  {
   switch(pattern){case "track":return reel.FishPos>reel.ZonePos;case "hold":return true;case "release":return false;case "pulse":return step%8<5;case "slow":return step%30<16;}
   return step%3==0;
  }
  static FoundationValue Session(Fixture f,bool deep,string forcedCatch,double forcedWait,FoundationValue script,FoundationValue expectedDraws)
  {
   var random=new Recorded(expectedDraws);var session=new FishingSession(f.Model,random){ForcedCatch=forcedCatch,ForcedWait=forcedWait};var frames=new List<FoundationValue>();bool holding=false;
   session.Start(deep);var rows=script.Items;
   for(int index=0;index<rows.Count;index++)
   {
    double delta=rows[index].Items[0].AsDouble();string action=rows[index].Items[1].AsString(),before=session.Phase;
    if(action=="hold")holding=true;if(action=="release")holding=false;if(action=="track")holding=session.Reel!=null&&session.Reel.FishPos>session.Reel.ZonePos;
    if(action=="press")session.Press();else if(action=="close")session.Close();else session.Tick(delta,holding);
    if(session.Phase!=before||index%30==0||index==rows.Count-1)frames.Add(O(("index",I(index)),("phase",S(session.Phase)),("time",D(session.PhaseTime)),("wait",D(session.WaitTime)),("catch",S(session.CatchId)),("outcome",S(session.Outcome)),("locked",B(f.State.InputLocked)),("reel",session.Reel==null?FoundationValue.Nil():ReelView(session.Reel))));
   }
   if(session.Active)session.Close();
   if(random.Used!=random.Count)throw new InvalidOperationException("The source consumed more generator results");
   return O(("draws",expectedDraws),("frames",A(frames)),("facing",A(new[]{D(1),D(0)})));
  }
  static FoundationValue Exact(FoundationValue value)
  {
   if(value.TryGet("$f64",out var bits)){string hex=bits.AsString();var bytes=new byte[8];for(int i=0;i<8;i++)bytes[i]=Convert.ToByte(hex.Substring(i*2,2),16);if(!BitConverter.IsLittleEndian)Array.Reverse(bytes);return D(BitConverter.ToDouble(bytes,0));}
   return value.Kind=="array"?A(value.Items.Select(Exact)):value;
  }
  static FoundationValue Execute(Fixture f,FoundationValue op,FoundationValue expected)
  {
   var a=op.Items;string id=a[0].AsString();var model=f.Model;var state=f.State;
   if(id=="skill"||id=="skill_xp"||id=="record_fish"||id=="remaining"||id=="gather_reason"||id=="gather"||id=="craft_reason"||id=="craft")model.EnsureState();
   switch(id)
   {
    case "normalize":return model.Normalize(a[1],a[2].AsDouble());
    case "prof_threshold":return I(ProfessionsModel.Threshold((int)a[1].AsInt64()));
    case "skill":return Skill(model,a[1].AsString());
    case "skill_xp":model.AddXp(a[1].AsString(),a[2].AsInt64());return Skill(model,a[1].AsString());
    case "record_fish":model.RecordFish(a[1].AsString());return I(model.Xp("fishing"));
    case "give":f.Inventory.Give(a[1].AsString(),a[2].AsInt64(),true);return I(state.Count(a[1].AsString()));
    case "clock":state.PlayTime=a[1].AsDouble();return D(state.PlayTime);
    case "remaining":return D(model.Remaining(a[1].AsString()));
    case "dynamic_limit":return D(model.CooldownLimit(a[1].AsString()));
    case "gather_reason":return S(model.GatherReason(a[1].AsString(),a[2].AsString()));
    case "gather_amount":return I(model.GatherAmount(a[1].AsString()));
    case "gather_duration":return D(model.GatherDuration(a[1].AsString()));
    case "gather_animation":return S(model.GatherAnimation(a[1].AsString()));
    case "gather_tool":return S(model.GatherTool(a[1].AsString()));
    case "gather":return B(model.Gather(a[1].AsString(),a[2].AsString()));
    case "craft_reason":return S(model.CraftReason(a[1].AsString()));
    case "craft":return B(model.Craft(a[1].AsString()));
    case "goal":return S(model.Goal);
    case "toggle_goal":model.ToggleGoal(a[1].AsString());return S(model.Goal);
    case "learn":return B(model.Learn(a[1].AsString()));
    case "recipes_for":return A(model.RecipesFor(a[1].AsString()).Select(S));
    case "source":return S(model.Source(a[1].AsString()));
    case "recipe_text":return S(model.RecipeText(a[1].AsString()));
    case "uses_text":return S(model.UsesText(a[1].AsString()));
    case "ingredient_status":return S(model.IngredientStatus(a[1].AsString()));
    case "identity":return O(("title",S(model.Title(a[1].AsString()))),("intro",S(model.Intro(a[1].AsString()))),("tab",S(model.Tab(a[1].AsString()))),("accent",S(model.AccentHtml(a[1].AsString()))));
    case "shop_rows":return A(model.ShopRows(a[1].AsString()).Select(row=>O(("text",S(row.Text)),("disabled",B(row.Owned)))));
    case "shop_buy":model.Buy(a[1].AsString(),(int)a[2].AsInt64());return O(("coins",I(state.Coins)),("count",I(state.Count(model.Shops.Require(a[1].AsString()).Require("items").Items[(int)a[2].AsInt64()].Require("item").AsString()))));
    case "fish_price":return I(model.FishPrice(a[1].AsString(),a[2].AsInt64(),a[3].AsBool()));
    case "golden_chance":return D(model.GoldenChance(a[1].AsInt64()));
    case "golden_can_bite":return B(model.GoldenCanBite);
    case "price_now":return I(model.PriceNow(a[1].AsString()));
    case "sale_value":return I(model.SaleValue());
    case "sell_fish":return I(model.SellFish());
    case "record_catch":model.RecordCatch(a[1].AsString(),a[2].AsBool());return state.Get("meer");
    case "fish_roll":{var random=new Recorded(a[5]);string fish=model.RollCatch(random.Randf,a[1].AsBool(),a[2].AsInt64(),a[3].AsBool());if(random.Used!=random.Count)throw new InvalidOperationException("The source consumed more generator results");return S(fish);}
    case "reel":
    {
     var random=new Recorded(a[6]);var reel=new FishingReel(random,model.Fishing.Require("reel"),model.FishStats(a[1].AsString()));var views=new List<FoundationValue>{ReelView(reel)};int steps=(int)a[4].AsInt64();double delta=a[5].AsDouble();string pattern=a[3].AsString();
     for(int step=0;step<steps;step++){reel.Update(delta,Held(pattern,step,reel));if(step%120==119||reel.State!="bezig")views.Add(ReelView(reel));if(reel.State!="bezig")break;}
     if(random.Used!=random.Count)throw new InvalidOperationException("The source consumed more generator results");return A(views);
    }
    case "fishing":return Session(f,a[1].AsBool(),a[3].AsString(),a[4].AsDouble(),a[5],Exact(expected.Require("draws")));
    case "rod":
    {
     // Two tries at one spot: without a rod one notice, with a rod the cast starts.
     int notices=0;bool started=false;double hintWait=0;
     for(int attempt=0;attempt<2;attempt++)
     {
      if(state.Count("fishing_rod")<=0){if(hintWait<=0){hintWait=3;notices++;f.Model.NotifyRodNeeded();}continue;}
      var session=new FishingSession(model,new Recorded(A(Array.Empty<FoundationValue>())));if(session.Start(a[1].AsBool())){started=true;session.Close();}
     }
     return O(("started",B(started)),("toastsAfterTwoTries",I(notices)));
    }
    case "context":state.MapId=a[2].AsString();state.InGame=a[4].AsBool();f.Inventory.SetContext(a[1].AsString(),a[2].AsString(),Vector2.zero,new Vector2((float)a[3].AsDouble(),0),a[4].AsBool());return S(f.Inventory.NearbyKind);
    case "equip":return B(f.Progression.Equip(a[1].AsString()));
    default:throw new InvalidOperationException("Unknown original professions operation: "+id);
   }
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
    if(actual.Kind!="object"&&actual.Kind!="dictionary")return path+": expected dictionary, got "+actual.Kind;
    if(actual.Entries.Count!=expected.Entries.Count)return path+": field count "+actual.Entries.Count+" != "+expected.Entries.Count;
    foreach(var row in expected.Entries){if(!actual.TryGet(row.Key.AsString(),out var child))return path+": missing "+row.Key.AsString();string failure=Difference(child,row.Value,path+"."+row.Key.AsString());if(failure!=null)return failure;}return null;
   }
   if(expected.Kind=="array")
   {
    if(actual.Kind!="array"||actual.Items.Count!=expected.Items.Count)return path+": array length "+(actual.Kind=="array"?actual.Items.Count.ToString():actual.Kind)+" != "+expected.Items.Count;
    for(int i=0;i<expected.Items.Count;i++){string failure=Difference(actual.Items[i],expected.Items[i],path+"["+i+"]");if(failure!=null)return failure;}return null;
   }
   if(expected.Kind=="int")return actual.Kind=="int"&&actual.AsInt64()==expected.AsInt64()?null:path+": integer differs ("+(actual.Kind=="int"?actual.AsInt64().ToString():actual.Kind)+" != "+expected.AsInt64()+")";
   if(expected.Kind=="bool")return actual.Kind=="bool"&&actual.AsBool()==expected.AsBool()?null:path+": boolean differs";
   if(expected.Kind=="string")return actual.Kind=="string"&&actual.AsString()==expected.AsString()?null:path+": text differs ("+(actual.Kind=="string"?actual.AsString():actual.Kind)+" != "+expected.AsString()+")";
   return actual.Kind=="nil"&&expected.Kind=="nil"?null:path+": scalar kind differs";
  }
 }
}
