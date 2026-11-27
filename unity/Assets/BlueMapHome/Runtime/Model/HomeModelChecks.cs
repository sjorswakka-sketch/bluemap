using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using UnityEngine;
namespace BlueMapMigration.Home
{
 /// <summary>Replays every recorded source case: each result and the complete saved state must match.</summary>
 public static class HomeModelChecks
 {
  public static int OracleCases {get;private set;} public static int OracleOperations {get;private set;}
  static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue B(bool v)=>FoundationValue.Boolean(v);static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue D(double v)=>FoundationValue.Number(v);
  static FoundationValue A(IEnumerable<FoundationValue> values)=>FoundationValue.Array(values);
  static FoundationValue O(params (string key,FoundationValue value)[] entries)=>FoundationValue.Object(entries.ToDictionary(v=>v.key,v=>v.value,StringComparer.Ordinal));
  sealed class Fixture{public HomeModel Model;public InventoryModel Inventory;public FoundationGameState State;}
  static Fixture Build(FoundationWorldRepository repository,FoundationValue initial)
  {var f=new Fixture();f.State=new FoundationGameState(initial);f.State.InGame=true;f.Inventory=new InventoryModel(repository,f.State);f.Model=new HomeModel(repository,f.State,f.Inventory);return f;}
  public static void Run(Action<string,bool> check)=>Verify(FoundationWorldRepository.LoadRequired(),check);
  public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
  {
   var asset=Resources.Load<TextAsset>("BlueMapHomeOracle");if(asset==null)throw new FormatException("Missing original home oracle");
   var oracle=FoundationJson.ParsePlain(asset.text);
   if(oracle.Require("schema").AsString()!="bluemap.home.source-oracle.v1"||oracle.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid home source oracle");
   var fixtures=InventoryModelChecks.DecodeOrdered(oracle.Require("fixturesOrdered"));var ids=new List<string>();OracleCases=0;OracleOperations=0;
   foreach(var row in oracle.Require("cases").Items)
   {
    string id=row.Require("id").AsString();var f=Build(repository,InventoryModelChecks.DecodeOrdered(row.Require("initialOrdered")));var ops=InventoryModelChecks.DecodeOrdered(row.Require("operationsOrdered")).Items;var expected=row.Require("resultsExact").Items;
    for(int index=0;index<ops.Count;index++)
    {
     var resolved=A(ops[index].Items.Select(v=>v.Kind=="string"&&fixtures.TryGet(v.AsString(),out var named)?named:v));
     string failure=Difference(Execute(f,resolved),expected[index],id+".results["+index+"]");
     if(failure!=null)throw new InvalidOperationException("Original home result differs: "+failure);OracleOperations++;
    }
    string stateFailure=Difference(f.State.Snapshot(),row.Require("expectedExact"),id+".state");if(stateFailure!=null)throw new InvalidOperationException("Original home state differs: "+stateFailure);ids.Add(id);OracleCases++;
   }
   check("home_model_source_equivalence",OracleCases==oracle.Require("cases").Items.Count&&ids.Distinct(StringComparer.Ordinal).Count()==ids.Count&&OracleCases>200&&OracleOperations>20000);
   var catalogs=HomeModel.LoadCatalog();
   check("home_catalog_complete",catalogs.Require("house").Require("pieces").Entries.Count==13&&catalogs.Require("yard").Require("units").Entries.Count==4&&catalogs.Require("yard").Require("pieces").Entries.Count==7&&FoundationJson.StringifyPlain(InventoryModelChecks.DecodeOrdered(oracle.Require("catalogsOrdered")))==FoundationJson.StringifyPlain(catalogs));
   // Designing is pure: every reason and preview leaves the save untouched.
   var browse=Build(repository,HomeModel.NewGame);browse.Model.HouseState();browse.Model.YardState();string before=FoundationJson.StringifyPlain(browse.State.Snapshot());
   var layout=browse.Model.HouseView.Require("layout");var owned=browse.Model.HouseView.Require("owned");
   foreach(string kind in browse.Model.PieceIds){browse.Model.MakePieceReason(kind);browse.Model.PieceUnlocked(kind);browse.Model.HouseLayoutReason(HomeModel.HouseCandidate(layout,browse.Model.IsBase(kind)?kind:kind+":1",kind,new HomeCell(5,9),1),owned);}
   var yard=browse.Model.YardView;foreach(var plot in browse.Model.Plots())foreach(var cell in plot.Cells())browse.Model.PlaceReason(cell,yard,browse.Model.FarmCells,true);
   browse.Model.YardLayoutReason(yard,browse.Model.FarmCells,yard);browse.Model.ActorReason(yard,new Vector2(240,720));browse.Model.HouseDraftReason(browse.Model.HouseView,new Vector2(208,336));
   check("home_designing_is_pure",before==FoundationJson.StringifyPlain(browse.State.Snapshot()));
   // A refused design or purchase leaves materials, pieces and the saved layout exactly as they were.
   var refuse=Build(repository,HomeModel.NewGame);refuse.Model.HouseState();refuse.Model.YardState();refuse.State.MapId="player_home";string refuseBefore=FoundationJson.StringifyPlain(refuse.State.Snapshot());
   var blocked=HomeModel.HouseCandidate(refuse.Model.HouseView.Require("layout"),"chair:1","chair",new HomeCell(6,8),0);
   bool refused=!refuse.Model.MakePiece("cabinet")&&!refuse.Model.ApplyHouse(InventoryModel.Replace(refuse.Model.HouseView,"layout",blocked),new Vector2(208,336))&&!refuse.Model.MakeParts("fence")&&!refuse.Model.Expand("west")&&!refuse.Model.ApplyYard(refuse.Model.YardView,new Vector2(240,720));
   check("home_refusals_change_nothing",refused&&refuseBefore==FoundationJson.StringifyPlain(refuse.State.Snapshot()));
   // Unknown later fields elsewhere in the save survive a design change.
   var keep=Build(repository,HomeModel.NewGame);var payload=FoundationJson.ParsePlain("{\"counter\":9007199254740993,\"nested\":[null,true,\"🌱\"]}");keep.State.Set("future_fields",payload);keep.State.MapId="player_home";
   var moved=HomeModel.HouseCandidate(keep.Model.HouseState().Require("layout"),"table","table",new HomeCell(3,9),2);
   bool applied=keep.Model.ApplyHouse(InventoryModel.Replace(keep.Model.HouseView,"layout",moved),new Vector2(208,208));
   check("home_apply_keeps_unrelated_fields",applied&&ReferenceEquals(keep.State.Get("future_fields"),payload)&&keep.Model.HouseView.Require("layout").Require("table").Require("cell").Items[1].AsInt64()==9);
  }
  static HomeCell Cell(FoundationValue v)=>new HomeCell((int)v.Items[0].AsInt64(),(int)v.Items[1].AsInt64());
  static Vector2 Point(FoundationValue v)=>new Vector2((float)v.Items[0].AsDouble(),(float)v.Items[1].AsDouble());
  static FoundationValue Execute(Fixture f,FoundationValue op)
  {
   var a=op.Items;string id=a[0].AsString();var model=f.Model;var state=f.State;
   switch(id)
   {
    case "house_defaults":return model.HouseDefaults();
    case "house_normalize":return model.NormalizeHouse(a[1]);
    case "house_state":return model.HouseState();
    case "house_layout_reason":return S(model.HouseLayoutReason(a[1],a[2]));
    case "house_place":return S(model.HouseLayoutReason(HomeModel.HouseCandidate(a[1],a[2].AsString(),a[3].AsString(),Cell(a[4]),a[5].AsInt64()),a[6]));
    case "house_next_id":return S(model.NextPieceId(a[1].AsString(),a[2]));
    case "house_unlocked":return B(model.PieceUnlocked(a[1].AsString()));
    case "house_make_reason":return S(model.MakePieceReason(a[1].AsString()));
    case "house_make":return B(model.MakePiece(a[1].AsString()));
    case "house_player_reason":return S(model.HousePlayerReason(a[1],Point(a[2])));
    case "house_world_position":{var p=model.WorldPosition(a[1]);return A(new[]{D(p.x),D(p.y)});}
    case "house_apply":return B(model.ApplyHouse(a[1],Point(a[2])));
    case "yard_defaults":return model.YardDefaults();
    case "yard_normalize":return model.NormalizeYard(a[1],a[2]);
    case "yard_state":return model.YardState();
    case "yard_place_reason":return S(model.PlaceReason(Cell(a[1]),a[2],a[3],a[4].AsBool()));
    case "yard_used":return I(model.Used(a[1],a[2].AsString()));
    case "yard_layout_reason":return S(model.YardLayoutReason(a[1],a[2],a[3]));
    case "yard_station":return S(model.YardLayoutReason(InventoryModel.Replace(a[1],"stations",InventoryModel.Replace(a[1].Require("stations"),a[2].AsString(),a[3])),a[4],a[5]));
    case "yard_piece":{string field=model.IsPath(a[2].AsString())?"paths":"fences";return S(model.YardLayoutReason(InventoryModel.Replace(a[1],field,InventoryModel.Replace(a[1].Require(field),Cell(a[3]).Key,a[2])),a[4],a[5]));}
    case "yard_reach":return I(model.Reachable(a[1]).Count);
    case "yard_blocks_work":return B(model.BlocksWork(Cell(a[1])));
    case "yard_surface":return S(model.Surface(Cell(a[1])));
    case "yard_material_reason":return S(model.MaterialReason(a[1]));
    case "yard_make":return B(model.MakeParts(a[1].AsString()));
    case "yard_expand":return B(model.Expand(a[1].AsString()));
    case "yard_actor_reason":return S(model.ActorReason(a[1],Point(a[2])));
    case "yard_schema_ok":return B(model.SchemaOk(a[1]));
    case "yard_apply":return B(model.ApplyYard(a[1],Point(a[2])));
    case "transition":state.Transitioning=a[1].AsBool();return B(state.Transitioning);
    case "context":state.MapId=a[2].AsString();state.InGame=a[4].AsBool();f.Inventory.SetContext(a[1].AsString(),a[2].AsString(),Vector2.zero,new Vector2((float)a[3].AsDouble(),0),a[4].AsBool());return S(f.Inventory.NearbyKind);
    default:throw new InvalidOperationException("Unknown original home operation: "+id);
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
