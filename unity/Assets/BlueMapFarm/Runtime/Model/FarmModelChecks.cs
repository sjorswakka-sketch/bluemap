using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Home;
using BlueMapMigration.Inventory;
using BlueMapMigration.Professions;
using UnityEngine;
namespace BlueMapMigration.Farm
{
 /// <summary>Replays every recorded source case: each result and the complete saved state must match.</summary>
 public static class FarmModelChecks
 {
  public static int OracleCases {get;private set;} public static int OracleOperations {get;private set;}
  static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue B(bool v)=>FoundationValue.Boolean(v);static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue D(double v)=>FoundationValue.Number(v);
  static FoundationValue A(IEnumerable<FoundationValue> values)=>FoundationValue.Array(values);
  static FoundationValue O(params (string key,FoundationValue value)[] entries)=>FoundationValue.Object(entries.Select(v=>new KeyValuePair<FoundationValue,FoundationValue>(S(v.key),v.value)));
  sealed class Fixture
  {
   public FarmModel Model;public HomeModel Home;public InventoryModel Inventory;public ProfessionsModel Professions;public FoundationGameState State;
   public Vector2 Player;public bool StockNear;public int Trees;
   public readonly HashSet<string> Near=new HashSet<string>(StringComparer.Ordinal);public readonly HashSet<HomeCell> Blocked=new HashSet<HomeCell>();
  }
  static Fixture Build(FoundationWorldRepository repository,FoundationValue initial)
  {
   var f=new Fixture();f.State=new FoundationGameState(initial);f.State.InGame=true;f.Inventory=new InventoryModel(repository,f.State);f.Professions=new ProfessionsModel(repository,f.State,f.Inventory);
   f.Home=new HomeModel(repository,f.State,f.Inventory);f.Model=new FarmModel(repository,f.State,f.Inventory,f.Professions,f.Home);
   f.Model.Near=(role,unit)=>f.Near.Contains(role+"|"+unit)||(unit==""&&f.Near.Any(v=>v.StartsWith(role+"|",StringComparison.Ordinal)));
   f.Model.SpawnFits=cell=>!f.Blocked.Contains(cell);f.Model.PlayerPosition=()=>f.Player;
   // The source redraws its orchard only when a tree is planted or removed.
   f.Model.TreesChanged+=()=>f.Trees=f.Model.AppleTrees().Count;
   return f;
  }
  public static void Run(Action<string,bool> check)=>Verify(FoundationWorldRepository.LoadRequired(),check);
  public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
  {
   var asset=Resources.Load<TextAsset>("BlueMapFarmOracle");if(asset==null)throw new FormatException("Missing original farm oracle");
   var oracle=FoundationJson.ParsePlain(asset.text);
   if(oracle.Require("schema").AsString()!="bluemap.farm.source-oracle.v1"||oracle.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid farm source oracle");
   var fixtures=InventoryModelChecks.DecodeOrdered(oracle.Require("fixturesOrdered"));var ids=new List<string>();OracleCases=0;OracleOperations=0;
   foreach(var row in oracle.Require("cases").Items)
   {
    string id=row.Require("id").AsString();var f=Build(repository,InventoryModelChecks.DecodeOrdered(row.Require("initialOrdered")));var ops=InventoryModelChecks.DecodeOrdered(row.Require("operationsOrdered")).Items;var expected=row.Require("resultsExact").Items;
    for(int index=0;index<ops.Count;index++)
    {
     var resolved=A(ops[index].Items.Select(v=>v.Kind=="string"&&fixtures.TryGet(v.AsString(),out var named)?named:v));
     string failure=Difference(Execute(f,resolved),expected[index],id+".results["+index+"]");
     if(failure!=null)throw new InvalidOperationException("Original farm result differs: "+failure);OracleOperations++;
    }
    string stateFailure=Difference(f.State.Snapshot(),row.Require("expectedExact"),id+".state");if(stateFailure!=null)throw new InvalidOperationException("Original farm state differs: "+stateFailure);ids.Add(id);OracleCases++;
   }
   check("farm_model_source_equivalence",OracleCases==oracle.Require("cases").Items.Count&&ids.Distinct(StringComparer.Ordinal).Count()==ids.Count&&OracleCases>250&&OracleOperations>2500);
   var catalogs=FarmModel.Catalogs;
   check("farm_catalog_complete",FarmModel.CropIds.Count==8&&FarmModel.JobIds.Count==3&&WaterModel.Types.Entries.Count==10&&WaterModel.MapIds.Count==37&&FoundationJson.StringifyPlain(InventoryModelChecks.DecodeOrdered(oracle.Require("catalogsOrdered")))==FoundationJson.StringifyPlain(catalogs));
   // Looking at the garden never writes the save.
   var browse=Build(repository,FarmModel.NewGame);browse.Model.FarmState();browse.Home.YardState();browse.State.MapId="village";browse.Inventory.Give("hs_hoe",1,true);string before=FoundationJson.StringifyPlain(browse.State.Snapshot());
   for(int y=28;y<42;y++)for(int x=3;x<36;x++)
   {
    var cell=new HomeCell(x,y);browse.Player=new Vector2(x*32+16,y*32+16);browse.Model.CellText(cell);browse.Model.Watered(cell);browse.Model.CanopyReason(cell,browse.Model.Cells);
    foreach(string action in FarmModel.ToolModes.Concat(FarmModel.CropIds))browse.Model.WorkReason(cell,action);
   }
   browse.Model.GuideText();browse.Model.Flowers();browse.Model.SupplyReason();foreach(string crop in FarmModel.CropIds)browse.Model.BuyReason(crop,5);
   check("farm_reading_is_pure",before==FoundationJson.StringifyPlain(browse.State.Snapshot()));
   // A refused action leaves seeds, coins, crops and work in progress exactly as they were.
   var refuse=Build(repository,FarmModel.NewGame);refuse.Model.FarmState();refuse.Home.YardState();refuse.State.MapId="village";refuse.Player=new Vector2(24*32+16,34*32+16);string refuseBefore=FoundationJson.StringifyPlain(refuse.State.Snapshot());
   bool refused=!refuse.Model.Act(new HomeCell(24,34),"soil")&&!refuse.Model.TakeSupplies()&&!refuse.Model.OrchardStarter()&&!refuse.Model.Buy("apple",1)&&!refuse.Model.StartJob("wine_a",1)&&!refuse.Model.Collect("hive")&&!refuse.Model.WildGrapes()&&refuse.Model.HarvestAll()==0;
   check("farm_refusals_change_nothing",refused&&refuseBefore==FoundationJson.StringifyPlain(refuse.State.Snapshot()));
   // Time away from the game is never caught up: only an explicit active-time step grows anything.
   var idle=Build(repository,FarmModel.NewGame);idle.State.MapId="village";idle.Inventory.Give("hs_hoe",1,true);idle.Inventory.Give("hs_seed",1,true);idle.Player=new Vector2(22*32+16,29*32+16);
   bool planted=idle.Model.Act(new HomeCell(22,29),"soil")&&idle.Model.Act(new HomeCell(22,29),"grape");idle.State.PlayTime+=100000;idle.Model.Advance(0);idle.Model.Advance(-5);
   double waiting=idle.Model.EntryAt(new HomeCell(22,29)).Require("growth").AsDouble();idle.Model.Advance(30);
   check("farm_grows_on_active_time_only",planted&&waiting==0&&idle.Model.EntryAt(new HomeCell(22,29)).Require("growth").AsDouble()==30);
   // A dry crop waits without withering, and unknown later fields elsewhere in the save survive garden work.
   var keep=Build(repository,FarmModel.NewGame);var payload=FoundationJson.ParsePlain("{\"counter\":9007199254740993,\"nested\":[null,true,\"🌱\"]}");keep.State.Set("future_fields",payload);keep.State.MapId="village";
   keep.Inventory.Give("hs_hoe",1,true);keep.Inventory.Give("or_mint_seed",1,true);keep.Player=new Vector2(28*32+16,34*32+16);
   bool dry=keep.Model.Act(new HomeCell(28,34),"soil")&&keep.Model.Act(new HomeCell(28,34),"mint");keep.Model.Advance(5000);
   check("farm_dry_crop_waits_and_keeps_unrelated_fields",dry&&keep.Model.EntryAt(new HomeCell(28,34)).Require("growth").AsDouble()==0&&keep.Model.EntryAt(new HomeCell(28,34)).Require("crop").AsString()=="mint"&&ReferenceEquals(keep.State.Get("future_fields"),payload));
  }
  static HomeCell Cell(FoundationValue v)=>new HomeCell((int)v.Items[0].AsInt64(),(int)v.Items[1].AsInt64());
  static Vector2 Point(FoundationValue v)=>new Vector2((float)v.Items[0].AsDouble(),(float)v.Items[1].AsDouble());
  static FoundationValue Pair(HomeCell c)=>A(new[]{I(c.X),I(c.Y)});
  static IEnumerable<HomeCell> Rect(FoundationValue r){for(int y=(int)r.Items[1].AsInt64();y<(int)r.Items[3].AsInt64();y++)for(int x=(int)r.Items[0].AsInt64();x<(int)r.Items[2].AsInt64();x++)yield return new HomeCell(x,y);}
  static void Stand(Fixture f,HomeCell c){f.Player=new Vector2(c.X*32+16,c.Y*32+16);}
  static FoundationValue Feature(WaterFeature feature)=>O(("kind",S(feature.Kind)),("count",I(feature.Cells.Count)),("north",Pair(feature.North)),("properties",feature.Properties),("cells",A(feature.Cells.Select(Pair))),("bankRocks",feature.BankRocks));
  static FoundationValue Execute(Fixture f,FoundationValue op)
  {
   var a=op.Items;string id=a[0].AsString();var model=f.Model;var state=f.State;
   f.Inventory.SetContext(f.StockNear?"home":"",state.MapId,Vector2.zero,Vector2.zero,state.InGame);
   switch(id)
   {
    case "player":f.Player=Point(a[1]);return FoundationValue.Nil();
    case "stand":Stand(f,Cell(a[1]));return FoundationValue.Nil();
    case "near":f.Near.Clear();foreach(var pair in a[1].Items)f.Near.Add(pair.Items[0].AsString()+"|"+pair.Items[1].AsString());return I(a[1].Items.Count);
    case "stock":f.StockNear=a[1].AsBool();f.Inventory.SetContext(f.StockNear?"home":"",state.MapId,Vector2.zero,Vector2.zero,state.InGame);return S(f.Inventory.NearbyKind);
    case "blocked":f.Blocked.Clear();foreach(var cell in a[1].Items)f.Blocked.Add(Cell(cell));return I(f.Blocked.Count);
    case "map":state.MapId=a[1].AsString();return S(state.MapId);
    case "play_time":state.PlayTime=a[1].AsDouble();return D(state.PlayTime);
    case "ui":state.SetUi("migration",a[1].AsBool());return B(state.InputLocked);
    case "ended":state.Ended=a[1].AsBool();return B(state.InputLocked);
    case "transition":state.Transitioning=a[1].AsBool();return B(state.Transitioning);
    case "flag":state.SetFlag(a[1].AsString(),a[2].AsBool());return B(state.Flag(a[1].AsString()));
    case "give":f.Inventory.Give(a[1].AsString(),a[2].AsInt64(),true);return I(state.Count(a[1].AsString()));
    case "take":f.Inventory.Take(a[1].AsString(),a[2].AsInt64());return I(state.Count(a[1].AsString()));
    case "homestead":state.Set("homestead",a[1]);return FoundationValue.Nil();
    case "farm_normalize":return model.Normalize(a[1]);
    case "farm_state":return model.FarmState();
    case "farm_cell":return Pair(FarmModel.Cell(a[1].AsString()));
    case "garden":return B(FarmModel.Garden(Cell(a[1])));
    case "irrigation":return O(("wet",A(model.WetCells.Select(Pair))),("flow",A(model.WetCells.Select(c=>{var from=model.FlowFrom(c);return A(new[]{I(c.X),I(c.Y),I(from.X),I(from.Y)});}))));
    case "watered":return B(model.Watered(Cell(a[1])));
    case "crop_watered":return B(model.CropWatered(Cell(a[1]),a[2]));
    case "flowers":return I(model.Flowers());
    case "advance":model.Advance(a[1].AsDouble());return A(new[]{I(model.Honey),D(model.HoneyTime)});
    case "status":{string reason=model.WorkReason(Cell(a[1]),a[2].AsString());return O(("ok",B(reason=="")),("reason",S(reason)));}
    case "act":return B(model.Act(Cell(a[1]),a[2].AsString()));
    case "harvest_reason":return S(model.HarvestReason(a[1]));
    case "harvest_all":return I(model.HarvestAll());
    case "start_job":return B(model.StartJob(a[1].AsString(),a[2].AsInt64()));
    case "collect":return B(model.Collect(a[1].AsString()));
    case "starter":return B(model.TakeSupplies());
    case "wild_grapes":return B(model.WildGrapes());
    case "animal":model.AnimalDrop(a[1].AsString(),Point(a[2]),Point(a[3]),a[4].AsBool(),a[5].AsBool());return I(model.FarmState().Require("drops").Entries.Count);
    case "trees":return I(f.Trees);
    case "duration":return D(FarmModel.Duration(a[1]));
    case "amount":return I(FarmModel.Amount(a[1]));
    case "supply_reason":return S(model.SupplyReason());
    case "or_starter":return B(model.OrchardStarter());
    case "buy_reason":return S(model.BuyReason(a[1].AsString(),a[2].AsInt64()));
    case "buy":return B(model.Buy(a[1].AsString(),a[2].AsInt64()));
    case "canopy_reason":return S(model.CanopyReason(Cell(a[1]),a[2]));
    case "patch_reason":return S(model.PatchReason(Cell(a[1])));
    case "cell_text":return S(model.CellText(Cell(a[1])));
    case "guide_step":return I(model.GuideStep());
    case "guide_text":return S(model.GuideText());
    case "sweep_status":return A(Rect(a[2]).Select(c=>{Stand(f,c);return S(model.WorkReason(c,a[1].AsString()));}).ToArray());
    case "sweep_act":return A(Rect(a[2]).Select(c=>{Stand(f,c);return B(model.Act(c,a[1].AsString()));}).ToArray());
    case "sweep_text":return A(Rect(a[1]).Select(c=>S(model.CellText(c))).ToArray());
    case "sweep_watered":return A(Rect(a[1]).Select(c=>B(model.Watered(c))).ToArray());
    case "sweep_canopy":return A(Rect(a[1]).Select(c=>S(model.CanopyReason(c,a[2]))).ToArray());
    case "sweep_patch":return A(Rect(a[1]).Select(c=>S(model.PatchReason(c))).ToArray());
    case "sweep_flowers":return A(Rect(a[1]).Select(c=>I(model.FlowerCountAt(c,a[2]))).ToArray());
    case "sweep_cover":return A(Rect(a[1]).Select(c=>Pair(FarmModel.TreeCover(c,a[2]))).ToArray());
    case "water_describe":return A(WaterModel.Describe(a[1].AsString()).Select(Feature));
    case "water_properties":return WaterModel.Properties(a[1].AsString(),a[2].AsString());
    case "water_irrigates":return B(WaterModel.Irrigates(a[1].AsString()));
    case "water_sweep":
    {
     string map=a[1].AsString();state.MapId=map;var rows=FarmModel.Catalogs.Require("water").Require("maps").Require(map).Require("rows").Items;int step=(int)a[2].AsInt64();var found=new List<FoundationValue>();
     for(int y=8;y<rows.Count*32;y+=step)for(int x=8;x<rows[0].AsString().Length*32;x+=step)
     {
      f.Player=new Vector2(x,y);var near=WaterModel.Nearest(map,f.Player,(float)a[3].AsDouble());
      if(near.Found)found.Add(A(new[]{I(x),I(y),S(near.Kind),I(near.At.X),I(near.At.Y),D(near.Distance)}));
     }
     return A(found);
    }
    case "water_context":
    {
     string map=a[1].AsString();state.MapId=map;f.Player=Point(a[2]);var near=WaterModel.Nearest(map,f.Player);if(!near.Found)return InventoryModel.Empty();
     var spec=WaterModel.Properties(near.Kind,map);
     return O(("title",S(model.Tr(spec.Require("name").AsString()))),("detail",S(model.Tr(spec.Require("detail").AsString()))),("locked",B(false)),("rect",A(new[]{D(near.At.X*32),D(near.At.Y*32),D(32),D(32)})));
    }
    default:throw new InvalidOperationException("Unknown original farm operation: "+id);
   }
  }
  static string Difference(FoundationValue actual,FoundationValue expected,string path)
  {
   if(expected.TryGet("$f64",out var bits))
   {
    if(actual.Kind!="float"&&actual.Kind!="int")return path+": expected number, got "+actual.Kind;
    string actualBits=BitConverter.ToString(BitConverter.GetBytes(actual.AsDouble())).Replace("-","").ToLowerInvariant();return actualBits==bits.AsString()?null:path+": numeric bytes "+actualBits+" != "+bits.AsString()+" ("+actual.AsDouble().ToString("R",System.Globalization.CultureInfo.InvariantCulture)+")";
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
