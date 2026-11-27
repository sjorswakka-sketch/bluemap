using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Home;
using BlueMapMigration.Inventory;
using UnityEngine;
namespace BlueMapMigration.Farm
{
 /// <summary>One connected body of water on a map, with its original type.</summary>
 public sealed class WaterFeature
 {
  public string Kind;public HomeCell North;public IReadOnlyList<HomeCell> Cells;public FoundationValue Properties;public FoundationValue BankRocks;
  public Vector2 Center{get{float x=0,y=0;foreach(var cell in Cells){x+=(cell.X+.5f)*32;y+=(cell.Y+.5f)*32;}return new Vector2(x/Cells.Count,y/Cells.Count);}}
 }
 /// <summary>The nearest water tile to the player.</summary>
 public readonly struct WaterNear
 {
  public readonly string Kind;public readonly HomeCell At;public readonly float Distance;
  public WaterNear(string kind,HomeCell at,float distance){Kind=kind;At=at;Distance=distance;}
  public bool Found=>Kind!=null;
 }
 /// <summary>The original water types: which water is fresh, which irrigates a garden and how it is described.</summary>
 public static class WaterModel
 {
  static readonly Dictionary<string,IReadOnlyList<WaterFeature>> features=new Dictionary<string,IReadOnlyList<WaterFeature>>(StringComparer.Ordinal);
  static readonly Dictionary<string,Dictionary<HomeCell,string>> cells=new Dictionary<string,Dictionary<HomeCell,string>>(StringComparer.Ordinal);
  static FoundationValue Water=>FarmModel.Catalogs.Require("water");
  public static FoundationValue Types=>Water.Require("types");
  public static IReadOnlyList<string> MapIds=>Water.Require("maps").Entries.Select(v=>v.Key.AsString()).ToArray();
  public static bool Irrigates(string kind)=>kind!=null&&Types.TryGet(kind,out var spec)&&spec.TryGet("irrigates",out var value)&&value.Kind=="bool"&&value.AsBool();
  /// <summary>A river turns brackish where it meets the sea.</summary>
  public static FoundationValue Properties(string kind,string mapId)
  {
   var spec=Types.Require(kind);if(kind!="river"||mapId!="river_mouth")return spec;
   spec=InventoryModel.Replace(spec,"fresh",FoundationValue.Boolean(false));spec=InventoryModel.Replace(spec,"irrigates",FoundationValue.Boolean(false));
   return InventoryModel.Replace(spec,"detail",Water.Require("estuaryDetail"));
  }
  static bool Wet(char c)=>c=='~'||c=='F'||c=='3'||c=='8';
  static string BaseKind(string mapId,int count)
  {
   if(mapId=="village")return "canal";if(mapId=="river_mouth")return "river";
   if(Water.Require("seaMaps").Items.Any(v=>v.AsString()==mapId))return "sea";
   if(mapId=="lake")return "lake";if(mapId=="kruipmoeras")return "marsh";if(mapId=="forest")return "stream";
   return mapId=="forest_edge"&&count<12?"puddle":"pool";
  }
  /// <summary>Connected water on a map; a bridge joins the water on both sides into one body.</summary>
  public static IReadOnlyList<WaterFeature> Describe(string mapId)
  {
   if(mapId==null)return Array.Empty<WaterFeature>();if(features.TryGetValue(mapId,out var known))return known;
   var result=new List<WaterFeature>();var kinds=new Dictionary<HomeCell,string>();
   if(Water.Require("maps").TryGet(mapId,out var map))
   {
    var rows=map.Require("rows").Items.Select(v=>v.AsString()).ToArray();var hints=map.Require("hints").Items;
    char At(HomeCell p)=>rows[p.Y][p.X];bool Inside(HomeCell p)=>p.Y>=0&&p.Y<rows.Length&&p.X>=0&&p.X<rows[p.Y].Length;
    var order=new List<HomeCell>();for(int y=0;y<rows.Length;y++)for(int x=0;x<rows[y].Length;x++)if(Wet(rows[y][x]))order.Add(new HomeCell(x,y));
    var unseen=new HashSet<HomeCell>(order);int cursor=0;
    while(unseen.Count>0)
    {
     while(!unseen.Contains(order[cursor]))cursor++;var first=order[cursor];var queue=new List<HomeCell>{first};var seen=new HashSet<HomeCell>{first};var body=new List<HomeCell>();
     for(int head=0;head<queue.Count;head++)
     {
      var at=queue[head];if(Wet(At(at))){body.Add(at);unseen.Remove(at);}
      foreach(var step in new[]{(-1,0),(1,0),(0,-1),(0,1)})
      {
       var next=at.Offset(step.Item1,step.Item2);if(seen.Contains(next)||!Inside(next))continue;char c=At(next);
       if(Wet(c)||c=='='||c=='9'){seen.Add(next);queue.Add(next);}
      }
     }
     string kind=BaseKind(mapId,body.Count);FoundationValue rocks=FoundationValue.Array(Array.Empty<FoundationValue>());var inBody=new HashSet<HomeCell>(body);
     foreach(var hint in hints)
     {
      var at=hint.Require("at").Items;if(!inBody.Contains(new HomeCell((int)at[0].AsInt64(),(int)at[1].AsInt64())))continue;
      kind=hint.Require("kind").AsString();rocks=InventoryModel.Get(hint,"bank_rocks",FoundationValue.Array(Array.Empty<FoundationValue>()));
     }
     var north=body[0];foreach(var at in body){if(at.Y<north.Y||(at.Y==north.Y&&at.X<north.X))north=at;kinds[at]=kind;}
     result.Add(new WaterFeature{Kind=kind,North=north,Cells=body.ToArray(),Properties=Properties(kind,mapId),BankRocks=rocks});
    }
   }
   features[mapId]=result;cells[mapId]=kinds;return result;
  }
  public static string KindAt(string mapId,HomeCell at){Describe(mapId);return mapId!=null&&cells.TryGetValue(mapId,out var kinds)&&kinds.TryGetValue(at,out var kind)?kind:null;}
  /// <summary>The closest water tile within range, searched in the five-by-five tiles around the player.</summary>
  public static WaterNear Nearest(string mapId,Vector2 player,float range=56f)
  {
   Describe(mapId);if(mapId==null||!cells.TryGetValue(mapId,out var kinds)||kinds.Count==0)return default;
   int ox=(int)(player.x/32f),oy=(int)(player.y/32f);string best=null;HomeCell bestAt=default;float distance=range;
   for(int y=oy-2;y<=oy+2;y++)for(int x=ox-2;x<=ox+2;x++)
   {
    var cell=new HomeCell(x,y);if(!kinds.TryGetValue(cell,out var kind))continue;
    float here=Vector2.Distance(player,new Vector2((x+.5f)*32,(y+.5f)*32));if(here<distance){distance=here;best=kind;bestAt=cell;}
   }
   return best==null?default:new WaterNear(best,bestAt,distance);
  }
 }
}
