using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using UnityEngine;
namespace BlueMapMigration.Residents
{
 public static class ResidentMotionChecks
 {
  public static int OracleCases{get;private set;}
  public static IReadOnlyList<string> CaseIds{get;private set;}=Array.Empty<string>();
  static FoundationValue S(string s)=>FoundationValue.StringValue(s);
  static FoundationValue I(int i)=>FoundationValue.Integer(i);
  static FoundationValue B(bool b)=>FoundationValue.Boolean(b);
  static FoundationValue A(IEnumerable<FoundationValue> a)=>FoundationValue.Array(a);
  static FoundationValue O(params (string,FoundationValue)[] pairs)=>FoundationValue.Object(pairs.ToDictionary(p=>p.Item1,p=>p.Item2));
  static byte[] Bytes(string s){var a=new byte[s.Length/2];for(int i=0;i<a.Length;i++)a[i]=Convert.ToByte(s.Substring(i*2,2),16);return a;}
  static string Hex(byte[] b)=>BitConverter.ToString(b).Replace("-","").ToLowerInvariant();
  public static double D(FoundationValue v)=>v.Kind=="object"||v.Kind=="dictionary"?BitConverter.ToDouble(Bytes(v.Require("$f64").AsString()),0):v.AsDouble();
  public static Vector2 V(FoundationValue v){var b=Bytes(v.Require("$v2").AsString());return new Vector2(BitConverter.ToSingle(b,0),BitConverter.ToSingle(b,4));}
  static Vector2Int C(FoundationValue v)=>new Vector2Int((int)v.Items[0].AsInt64(),(int)v.Items[1].AsInt64());
  public static FoundationValue F(double d)=>O(("$f64",S(Hex(BitConverter.GetBytes(d)))));
  public static FoundationValue P(Vector2 p)=>O(("$v2",S(Hex(BitConverter.GetBytes(p.x).Concat(BitConverter.GetBytes(p.y)).ToArray()))));
  static List<Vector2> Path(FoundationValue v)=>v.Items.Select(V).ToList();
  static ResidentFootGrid Grid(FoundationValue i)=>new ResidentFootGrid((int)i.Require("width").AsInt64(),(int)i.Require("height").AsInt64(),i.Require("solid").Items.Select(C));
  public static void Verify(Action<string,bool> check)
  {
   var data=FoundationJson.ParsePlain(Resources.Load<TextAsset>("BlueMapResidentMotionOracle").text);OracleCases=0;var ids=new List<string>();
   foreach(var row in data.Require("cases").Items)
   {
    string id=row.Require("id").AsString();var i=row.Require("inputs");FoundationValue result;
    switch(row.Require("kind").AsString())
    {
     case "route":{var s=new ResidentMotionState{Kind=i.Require("actorKind").AsString(),Role=i.Require("role").AsString(),Resting=i.Require("rest").AsBool(),Evening=i.Require("rest").AsBool()};var c=Context(i);result=A(ResidentMotionModel.Routes(s,c).Select(p=>s.Kind=="memory"?A(new[]{I((int)p.x),I((int)p.y)}):P(p)));break;}
     case "path":result=A(Grid(i).FindPath(C(i.Require("start")),C(i.Require("goal"))).Select(P));break;
     case "spawn":result=P(Grid(i).SafeSpawn(C(i.Require("at")),V(i.Require("player")),Path(i.Require("others"))));break;
     case "safe":
     {
      var objects=i.Require("objects").Items.Select(v=>new ResidentRoamObstacle{Type=v.Require("type").AsString(),Enabled=v.Require("enabled").AsBool(),PositionTiles=new Vector2((float)v.Require("pos").Items[0].AsDouble(),(float)v.Require("pos").Items[1].AsDouble()),SizeTiles=new Vector2((float)v.Require("size").Items[0].AsDouble(),(float)v.Require("size").Items[1].AsDouble())}).ToArray();var blocked=Path(i.Require("blockedPoints"));
      result=B(ResidentPassability.RoamSafe(V(i.Require("at")),V(i.Require("anchor")),i.Require("map").AsString(),p=>blocked.Contains(p),objects,Path(i.Require("others"))));break;
     }
     case "pose":{var velocity=V(i.Require("velocity"));result=O(("direction",I(ResidentMotionModel.Direction(velocity,(int)i.Require("previous").AsInt64()))),("frame",I(ResidentMotionModel.CharacterFrame(D(i.Require("time")),ResidentMotionModel.IsMoving(velocity)))));break;}
     case "occupancy":{var g=Grid(i);result=A((i.Require("actorKind").AsString()=="memory"?g.MemoryPath(V(i.Require("actor")),C(i.Require("goal")),Path(i.Require("others")),V(i.Require("player"))):g.SupperPath(V(i.Require("actor")),C(i.Require("goal")),Path(i.Require("others")),V(i.Require("player")))).Select(P));break;}
     case "step":
     {
      string kind=i.Require("actorKind").AsString();var s=Restore(row.Require("before"),kind);s.Role=i.Require("role").AsString();s.Id=i.Require("id").AsString();var c=Context(i);c.Locked=i.Require("locked").AsBool();c.PlayerPosition=V(i.Require("player"));c.ResolveMove=(p,v,d)=>V(i.Require("resolved"));c.ResolveVelocity=v=>V(i.Require("resolvedVelocity"));c.DrawWaitSeconds=()=>D(i.Require("drawWait"));c.DrawChoiceIndex=count=>(int)i.Require("drawChoice").AsInt64();var blocked=Path(i.Require("blockedPoints"));c.RoamSafe=p=>ResidentPassability.RoamSafe(p,s.Anchor,c.MapId,q=>blocked.Contains(q),null,null);c.FindPath=(p,g)=>kind=="village"?new ResidentFootGrid(40,36).FindPath(ResidentMotionModel.Cell(p),g):Path(i.Require("supplied"));
      ResidentMotionModel.Step(s,D(i.Require("delta")),c);result=Snapshot(s);break;
     }
     default:throw new InvalidOperationException("Unknown resident source family");
    }
    string difference=Difference(result,row.Require("expected"),id);if(difference!=null)throw new InvalidOperationException("Original resident motion differs: "+difference);ids.Add(id);OracleCases++;
   }
   CaseIds=ids.AsReadOnly();check("residents_motion_source_equivalence",OracleCases>=500&&ids.Distinct(StringComparer.Ordinal).Count()==OracleCases);
   var paused=new ResidentMotionState{Kind="memory",Position=new Vector2(112,112),Wait=1,Time=3,RouteKey="unchanged"};paused.Path.Add(new Vector2(144,112));var before=FoundationJson.StringifyPlain(Snapshot(paused));ResidentMotionModel.Step(paused,.25,new ResidentMotionContext{Paused=true});bool preserved=before==FoundationJson.StringifyPlain(Snapshot(paused));
   var grid=new ResidentFootGrid(12,12);var actor=new Vector2(112,112);var goal=new Vector2Int(6,4);bool occupied=grid.MemoryPath(actor,goal,null,ResidentFootGrid.Center(goal)).Count==0;bool cleared=grid.MemoryPath(actor,goal,null,new Vector2(300,300)).Count>0;bool supper=grid.SupperPath(actor,goal,null,ResidentFootGrid.Center(goal)).Count>0;
   var roam=new ResidentMotionState{Kind="npc",Position=actor,Anchor=actor,Goal=new Vector2(136,112),Wait=0};ResidentMotionModel.Step(roam,.2,new ResidentMotionContext{PlayerPosition=new Vector2(1000,1000),RoamSafe=p=>true,ResolveMove=(p,v,d)=>p});bool blockedMove=roam.Wait==2&&roam.Goal==actor;
   check("residents_motion_boundaries_and_pause",preserved&&occupied&&cleared&&supper&&blockedMove&&!ResidentMotionModel.Dark(.12)&&!ResidentMotionModel.Dark(.78)&&ResidentMotionModel.Dark(.7800000000000001));
  }
  static ResidentMotionContext Context(FoundationValue i)=>new ResidentMotionContext{MapId=i.Require("map").AsString(),DayTime=D(i.Require("day")),Flowing=i.Require("flow").AsBool(),WaterWild=i.Require("water").AsBool(),Resting=i.Require("rest").AsBool()};
  public static ResidentMotionState Restore(FoundationValue b,string kind)
  {
   var s=new ResidentMotionState{Kind=kind,Position=V(b.Require("position")),Velocity=V(b.Require("velocity")),Wait=D(b.Require("wait"))};
   if(kind=="npc"){s.Anchor=V(b.Require("anchor"));s.Goal=V(b.Require("goal"));return s;}
   s.Time=D(b.Require("time"));s.RouteIndex=(int)b.Require("index").AsInt64();s.Path.AddRange(Path(b.Require("path")));
   if(kind=="village"){s.BubbleTime=D(b.Require("bubble"));s.RouteKey=b.Require("key").AsString();}
   if(kind=="memory"){s.Stuck=D(b.Require("stuck"));s.Resting=b.Require("rest").AsBool();s.RouteKey=b.Require("key").AsString();}
   if(kind=="supper"){s.Stuck=D(b.Require("stuck"));s.TaskIndex=(int)b.Require("task").AsInt64();s.Evening=b.Require("evening").AsBool();}return s;
  }
  public static FoundationValue Snapshot(ResidentMotionState s)
  {
   var pairs=new List<(string,FoundationValue)>{("position",P(s.Position)),("velocity",P(s.Velocity)),("wait",F(s.Wait))};
   if(s.Kind=="npc"){pairs.Add(("anchor",P(s.Anchor)));pairs.Add(("goal",P(s.Goal)));}
   else
   {
    pairs.Add(("time",F(s.Time)));pairs.Add(("path",A(s.Path.Select(P))));pairs.Add(("index",I(s.RouteIndex)));
    if(s.Kind=="village"){pairs.Add(("bubble",F(s.BubbleTime)));pairs.Add(("key",S(s.RouteKey)));}
    if(s.Kind=="memory"){pairs.Add(("stuck",F(s.Stuck)));pairs.Add(("rest",B(s.Resting)));pairs.Add(("key",S(s.RouteKey)));}
    if(s.Kind=="supper"){pairs.Add(("stuck",F(s.Stuck)));pairs.Add(("evening",B(s.Evening)));pairs.Add(("task",I(s.TaskIndex)));}
   }return O(pairs.ToArray());
  }
  static string Difference(FoundationValue a,FoundationValue b,string at)
  {
   bool objectA=a.Kind=="object"||a.Kind=="dictionary",objectB=b.Kind=="object"||b.Kind=="dictionary";
   if(a.Kind!=b.Kind&&!(objectA&&objectB))return at+" type "+a.Kind+" != "+b.Kind;
   if(objectA)
   {if(a.Entries.Count!=b.Entries.Count)return at+" property count";foreach(var p in b.Entries){string key=p.Key.AsString();if(!a.TryGet(key,out var v))return at+" missing "+key;var d=Difference(v,p.Value,at+"."+key);if(d!=null)return d;}return null;}
   if(a.Kind=="array"){if(a.Items.Count!=b.Items.Count)return at+" length "+a.Items.Count+" != "+b.Items.Count;for(int i=0;i<a.Items.Count;i++){var d=Difference(a.Items[i],b.Items[i],at+"["+i+"]");if(d!=null)return d;}return null;}
   return FoundationJson.StringifyPlain(a)==FoundationJson.StringifyPlain(b)?null:at+" "+FoundationJson.StringifyPlain(a)+" != "+FoundationJson.StringifyPlain(b);
  }
 }
}
