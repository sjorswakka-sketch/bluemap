using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;

namespace BlueMapMigration.Residents
{
 public sealed class ResidentMotionState
 {
  public string Kind="npc",Id="",Role="",RouteKey="";
  public Vector2 Position,Velocity,Anchor,Goal;
  public double Time,Wait,Stuck,BubbleTime,CatPanic,CatCalm;
  public int RouteIndex,TaskIndex,VisualDirection;
  public bool Resting,Evening,CatWaiting;
  public readonly List<Vector2> Path=new List<Vector2>();
 }
 public sealed class ResidentMotionContext
 {
  public string MapId="",Weather="";
  public double DayTime;
  public bool Flowing,WaterWild,Resting,Locked,Paused,DirectorAvailable=true;
  public Vector2 PlayerPosition;
  public Func<Vector2,bool> IsSolid,RoamSafe;
  public Func<Vector2,Vector2Int,List<Vector2>> FindPath;
  // Physics is deliberately an explicit boundary: the returned position is the
  // actual collision-resolved result, never an invented Godot physics emulation.
  public Func<Vector2,Vector2,double,Vector2> ResolveMove;
  public Func<Vector2,Vector2> ResolveVelocity;
  // Original randf_range(3,7) and choices.pick_random are exogenous draws.
  // Source-oracle replay supplies their recorded outputs; production supplies RNG.
  public Func<double> DrawWaitSeconds;
  public Func<int,int> DrawChoiceIndex;
 }
 public static class ResidentMotionModel
 {
  static FoundationValue catalog;
  public static FoundationValue Catalog => catalog??(catalog=FoundationJson.ParsePlain(Resources.Load<TextAsset>("BlueMapResidentMotionCatalog").text).Require("catalog"));
  public static float Distance(Vector2 a,Vector2 b)=>PlayerMotorModel.SourceLength(a-b);
  public static Vector2 Scale(Vector2 a,double b)=>PlayerMotorModel.ScaleSource(a,b);
  public static Vector2 MoveToward(Vector2 a,Vector2 b,double step)
  {var d=b-a;float n=PlayerMotorModel.SourceLength(d),s=(float)step;return n<=s||n<.00001f?b:a+Scale(new Vector2(d.x/n,d.y/n),s);}
  public static Vector2Int Cell(Vector2 point)=>new Vector2Int((int)(point.x/32f),(int)(point.y/32f));
  public static bool Dark(double day)=>day<.12||day>.78;
  public static List<Vector2> Routes(ResidentMotionState s,ResidentMotionContext c)
  {
   if(s.Kind=="village")
   {
    if(s.Role=="gardener")return !c.Flowing||Dark(c.DayTime)?V(17.5f,11.5f):V(14.5f,15.5f,15.5f,15.5f);
    return Dark(c.DayTime)?V(7.5f,13.5f):V(7.5f,13.5f,17.5f,13.5f,c.Flowing?21.5f:23.5f,15.5f,29.5f,11.5f);
   }
   if(s.Kind=="supper")
   {
    if(c.MapId=="lake")return s.Evening?V(10.5f,9.5f):V(20.5f,13.5f,18.5f,11.5f,10.5f,9.5f);
    return s.Role=="joris"?V(17.5f,4.5f):s.Role=="bo"?V(20.5f,3.5f,20.5f,5.5f):V(17.5f,7.5f,17.5f,6.5f);
   }
   if(s.Kind=="memory")
   {
    if(s.Role=="caravan"&&!c.WaterWild)return s.Resting?V(24,14):V(24,14,25,14);
    var a=Catalog.Require("places").Require(s.Role).Require(s.Resting?"rest":"work").Items;
    return a.Select(p=>new Vector2((float)p.Items[0].AsDouble(),(float)p.Items[1].AsDouble())).ToList();
   }
   return new List<Vector2>();
  }
  static List<Vector2> V(params float[] xy){var a=new List<Vector2>();for(int i=0;i<xy.Length;i+=2)a.Add(new Vector2(xy[i],xy[i+1]));return a;}
  public static string RouteKey(ResidentMotionState s,ResidentMotionContext c)
  {
   if(s.Kind=="village")return "["+(c.Flowing?"true":"false")+", "+(Dark(c.DayTime)?"true":"false")+"]";
   return "["+string.Join(", ",Routes(s,c).Select(p=>"["+((int)p.x).ToString(System.Globalization.CultureInfo.InvariantCulture)+", "+((int)p.y).ToString(System.Globalization.CultureInfo.InvariantCulture)+"]"))+"]";
  }
  public static void Step(ResidentMotionState s,double delta,ResidentMotionContext c)
  {
   if(double.IsNaN(delta)||double.IsInfinity(delta)||delta<0)throw new ArgumentOutOfRangeException(nameof(delta));
   // Dialogue pauses the source tree. A targeted passer-by continues walking.
   if(c.Paused)return;
   if(s.Kind=="npc"||s.Kind=="coast"){Roam(s,delta,c);return;}
   s.Time+=delta;s.Velocity=Vector2.zero;
   if(s.Kind=="village")
   {
    s.BubbleTime=Math.Max(0,s.BubbleTime-delta);string key=RouteKey(s,c);
    if(key!=s.RouteKey){s.RouteKey=key;s.Path.Clear();s.RouteIndex=0;s.Wait=1;}
   }
   if(s.Kind=="supper")
   {
    if(!c.DirectorAvailable)return;
    if(c.MapId=="lake"&&s.Evening!=Dark(c.DayTime)){s.Evening=Dark(c.DayTime);s.Path.Clear();s.RouteIndex=0;s.Wait=1;}
   }
   if(s.Kind=="memory")
   {
    s.Resting=c.Resting;string key=RouteKey(s,c);
    if(key!=s.RouteKey){s.RouteKey=key;s.Path.Clear();s.RouteIndex=0;s.Wait=0;}
    if(c.Locked)return;
   }
   if(s.Wait>0){s.Wait-=delta;return;}
   if(s.Path.Count==0)
   {
    var points=Routes(s,c);int index=s.Kind=="supper"&&c.MapId!="lake"?Math.Min(s.RouteIndex,points.Count-1):s.RouteIndex%points.Count;
    if(s.Kind=="supper")s.TaskIndex=index;
    var goal=points[index];var found=c.FindPath?.Invoke(s.Position,new Vector2Int((int)goal.x,(int)goal.y));
    if(found!=null){s.Path.AddRange(found);if(s.Path.Count>0)s.Path.RemoveAt(0);}
    s.RouteIndex++;if(s.Path.Count==0)s.Wait=s.Kind=="supper"?SupperWait(s,c,points.Count):5;
    return;
   }
   Vector2 offset=s.Path[0]-s.Position;
   if(PlayerMotorModel.SourceLength(offset)<2)
   {
    s.Path.RemoveAt(0);if(s.Path.Count==0)s.Wait=s.Kind=="memory"?6:s.Kind=="supper"?SupperWait(s,c,Routes(s,c).Count):s.Role=="gardener"?5:3;
    return;
   }
   var before=s.Position;double speed=s.Kind=="village"?26:s.Kind=="memory"?25:c.MapId=="inn"?36:24;
   s.Velocity=Scale(PlayerMotorModel.NormalizeSource(offset),speed);
   s.Position=c.ResolveMove!=null?c.ResolveMove(before,s.Velocity,delta):before+Scale(s.Velocity,delta);
   if(c.ResolveVelocity!=null)s.Velocity=c.ResolveVelocity(s.Velocity);
   if(s.Kind!="village")
   {
    s.Stuck=Distance(s.Position,before)<.05?s.Stuck+delta:0;
    if(s.Stuck>(s.Kind=="memory"?.8:1)){s.Path.Clear();s.RouteIndex=Math.Max(0,s.RouteIndex-1);s.Wait=s.Kind=="memory"?.4:.2;s.Stuck=0;}
   }
  }
  static double SupperWait(ResidentMotionState s,ResidentMotionContext c,int count)=>c.MapId=="inn"&&s.RouteIndex<count?.2:8;
  static void Roam(ResidentMotionState s,double d,ResidentMotionContext c)
  {
   s.Velocity=Vector2.zero;
   if(c.Locked||s.Id=="muis_bos"||Distance(c.PlayerPosition,s.Position)<62)return;
   s.Wait=Math.Max(0,s.Wait-d);if(s.Wait>0)return;
   if(Distance(s.Goal,s.Position)<1)
   {
    double wait=c.DrawWaitSeconds==null?5:c.DrawWaitSeconds();if(wait<3||wait>7)throw new InvalidOperationException("Original roam draw outside [3,7].");s.Wait=wait;
    var choices=new List<Vector2>();foreach(var step in new[]{Vector2.left,Vector2.right,new Vector2(0,-1),new Vector2(0,1)}){var p=s.Position+Scale(step,24);if(c.RoamSafe==null||c.RoamSafe(p))choices.Add(p);}
    if(choices.Count>0){int i=c.DrawChoiceIndex==null?0:c.DrawChoiceIndex(choices.Count);if(i<0||i>=choices.Count)throw new InvalidOperationException("Original roam choice out of range.");s.Goal=choices[i];}return;
   }
   var next=MoveToward(s.Position,s.Goal,18*d);
   if(c.RoamSafe!=null&&!c.RoamSafe(next)){s.Goal=s.Position;s.Wait=2;return;}
   s.Velocity=Scale(PlayerMotorModel.NormalizeSource(s.Goal-s.Position),18);var before=s.Position;
   s.Position=c.ResolveMove!=null?c.ResolveMove(before,s.Velocity,d):before+Scale(s.Velocity,d);
   if(c.ResolveVelocity!=null)s.Velocity=c.ResolveVelocity(s.Velocity);
   if(Distance(before,s.Position)<.01){s.Goal=s.Position;s.Wait=2;}
  }
  public static void CatStep(ResidentMotionState s,double d,ResidentMotionContext c,bool loud,Vector2 playerVelocity,double attackTimer)
  {
   if(c.Paused||s.Id!="muis_bos")return;float distance=Distance(s.Position,c.PlayerPosition);
   if(distance<105&&loud){s.CatPanic=2.5;s.CatWaiting=false;s.CatCalm=0;}
   if(s.CatPanic>0){s.CatPanic=Math.Max(0,s.CatPanic-d);s.Position=CatPanicPosition(s.Position,d,c);}
   else if(s.CatWaiting){if(distance>56||PlayerMotorModel.SourceLength(playerVelocity)>5||attackTimer>0){s.CatWaiting=false;s.CatCalm=0;}else s.CatCalm=Math.Min(2,s.CatCalm+d);}
  }
  // For a session that already owns the original cat timers: call once for the
  // frame whose pre-decrement panic is positive, including its final panic step.
  public static Vector2 CatPanicPosition(Vector2 position,double delta,ResidentMotionContext c)
  {if(c.Paused)return position;var next=MoveToward(position,new Vector2(336,1008),42*delta);return (c.IsSolid==null||!c.IsSolid(next))&&Distance(next,c.PlayerPosition)>24?next:position;}
  public static int Direction(Vector2 v,int previous=0){if(PlayerMotorModel.SourceLengthSquared(v)<1)return previous;return Math.Abs(v.y)>Math.Abs(v.x)?v.y>0?0:1:v.x>0?2:3;}
  public static int CharacterFrame(double time,bool moving)=>moving?1+(int)(time*5)%2:0;
  public static int MemoryFrame(double time,bool moving)=>moving?(int)(time*5)%2:0;
  public static bool IsMoving(Vector2 velocity)=>PlayerMotorModel.SourceLength(velocity)>1;
 }
}
